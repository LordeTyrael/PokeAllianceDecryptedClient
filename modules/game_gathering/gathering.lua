-- Gathering (cliente) — UI do sistema de coleta em veias (servidor: data/modules/gathering).
--
-- Fora da coleta: balão "Press F to Collect" ancorado na veia adjacente (cardinal aceso, diagonal/ocupado
-- esmaecido). Pressionar F = g_game.use(veia) (mesmo 0x82 do clique direito; o servidor valida, vira o
-- jogador e trava o giro via busyState).
-- Durante a coleta (dirigida pelo opcode 1573):
--   * barra NATIVA sobre o JOGADOR (creature:setProgressBar) = tempo de CADA coleta (auto-anima);
--   * barra de RECURSO sobre a VEIA (o mesmo widget do balão, em modo barra) = cargas restantes / máximo;
--   * painel HUD no canto direito-central = cargas (número) + tempo estimado de término.
--
-- ARQUITETURA: o balão/barra-da-veia é EVENT-DRIVEN — recomputa em onPositionChange/onWalkFinish (andar/
-- teleporte), onGameStart e no parse dos subtypes 1/3 (cargas/ocupação mudaram). A direção do jogador NÃO
-- entra na lógica, então girar não precisa de gatilho. O único tick periódico é o countdown do ETA do HUD,
-- e só existe DURANTE a coleta (cycleEvent de 1s). A barra do jogador auto-anima na engine.
--
-- IDs aqui são CLIENT ids (item:getId() no cliente). 15910/15911 = clientIds das veias 16666/16667.

local GATHERABLE = { [15910] = true, [15911] = true }

local SEND_THROTTLE_MS = 300
local HUD_TICK_MS      = 1000

local OPCODE = 1573
local ST_NODE_STATE, ST_STARTED, ST_TICK, ST_STOPPED = 1, 2, 3, 4


local NEIGHBORS = {
  { dx = 0,  dy = -1, cardinal = true },
  { dx = 1,  dy = 0,  cardinal = true },
  { dx = 0,  dy = 1,  cardinal = true },
  { dx = -1, dy = 0,  cardinal = true },
  { dx = 1,  dy = -1, cardinal = false },
  { dx = 1,  dy = 1,  cardinal = false },
  { dx = -1, dy = 1,  cardinal = false },
  { dx = -1, dy = -1, cardinal = false },
}

local promptWidget           -- widget do tile (balão OU barra de recurso; efêmero)
local promptPos              -- {x,y,z} onde o widget está ancorado
local targetVein             -- Item da veia alvo (para o g_game.use)
local hudWidget              -- painel HUD (canto direito-central do mapa)
local hudTimer               -- cycleEvent do ETA — só existe durante a coleta
local nextSendAt = 0
local gatherKey = "F"

local nodeStates = {}        -- ["x:y:z"] = { charges, max }
local channel = nil          -- canal do PRÓPRIO jogador: { key, pos, interval, tickStart, yieldPerTick, charges, max }

local updateProximity, updateHud  -- forward decls

-- ---------------------------------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------------------------------
local function posKey(pos)
  return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

local function gatherableAt(pos)
  local tile = g_map.getTile(pos)
  if not tile then return nil end
  local items = tile:getItems()
  if not items then return nil end
  for _, it in ipairs(items) do
    if GATHERABLE[it:getId()] then
      return it
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------------------------------
-- Barra sobre o JOGADOR — nativa (creature:setProgressBar). Auto-anima de 0..100 ao longo de duration;
-- basta chamar uma vez por ciclo. GOTCHA: só é desenhada se a opção "creature bars" estiver ligada
-- (creature.cpp:316, drawFlags & DrawBars). O painel HUD é o feedback garantido.
-- ---------------------------------------------------------------------------------------------------
local function startPlayerBar(durationMs)
  local player = g_game.getLocalPlayer()
  if player then player:setProgressBar(durationMs, true, true) end
end

local function clearPlayerBar()
  local player = g_game.getLocalPlayer()
  if player then player:setProgressBar(0, false, false) end
end

-- ---------------------------------------------------------------------------------------------------
-- Painel HUD
-- ---------------------------------------------------------------------------------------------------
local function ensureHud()
  if hudWidget and not hudWidget:isDestroyed() then return hudWidget end
  local map = modules.game_interface.getMapPanel()
  if not map then return nil end
  hudWidget = g_ui.createWidget('GatherHud', map)
  if not hudWidget then return nil end
  return hudWidget
end

local function destroyHud()
  if hudWidget and not hudWidget:isDestroyed() then hudWidget:destroy() end
  hudWidget = nil
end

local function etaText()
  local c = channel
  if not c or not c.charges or not c.yieldPerTick or c.yieldPerTick <= 0 then return "-" end
  local collectsLeft = math.ceil(c.charges / c.yieldPerTick)
  local etaMs = collectsLeft * c.interval - (g_clock.millis() - c.tickStart)
  if etaMs < 0 then etaMs = 0 end
  local secs = math.ceil(etaMs / 1000)
  if secs >= 60 then
    return string.format("%dm %02ds", math.floor(secs / 60), secs % 60)
  end
  return secs .. "s"
end

updateHud = function()
  if not channel or not hudWidget or hudWidget:isDestroyed() then return end
  local charges = hudWidget:getChildById('charges')
  local eta = hudWidget:getChildById('eta')
  if charges then charges:setText("Charges: " .. (channel.charges or "-")) end
  if eta then eta:setText("ETA: " .. etaText()) end
end

local function showHud()
  local hud = ensureHud()
  if hud then
    hud:setVisible(true)
    updateHud()
  end
end

local function hideHud()
  if hudWidget and not hudWidget:isDestroyed() then hudWidget:setVisible(false) end
end

local function startHudTimer()
  if hudTimer then return end
  hudTimer = cycleEvent(updateHud, HUD_TICK_MS)
end

local function stopHudTimer()
  if hudTimer then removeEvent(hudTimer) hudTimer = nil end
end

-- ---------------------------------------------------------------------------------------------------
-- Widget do tile (balão / barra de recurso). setIgnoreDrawIntersect é OBRIGATÓRIO (o container é forçado
-- ao tamanho do tile todo frame; os filhos, ancorados ACIMA do tile, seriam descartados sem ele).
-- ---------------------------------------------------------------------------------------------------
local function ensureWidget()
  if promptWidget and not promptWidget:isDestroyed() then return promptWidget end
  promptWidget = g_ui.createWidget('GatherPrompt')
  if not promptWidget then return nil end
  promptWidget:setId('gatherPrompt')
  promptWidget:setPhantom(true)
  promptWidget:setFocusable(false)
  promptWidget:setIgnoreDrawIntersect(true)
  -- O container da barra (resbg) TAMBÉM precisa de ignoreDrawIntersect, senão o resfill (filho aninhado)
  -- é pulado no drawChildren: o Tile passa o rect do tile como visibleRect, a barra fica acima, a
  -- interseção é vazia, e só o widget-raiz (GatherPrompt) tem o flag. Cada nível aninhado precisa dele.
  local resbg = promptWidget:getChildById('resbg')
  if resbg then resbg:setIgnoreDrawIntersect(true) end
  return promptWidget
end

local function clearPrompt()
  if promptPos then
    local tile = g_map.getTile(promptPos)
    if tile then
      local w = tile:getWidget()
      if w and not w:isDestroyed() and w:getId() == 'gatherPrompt' then
        tile:removeWidget()  -- já destrói
        promptWidget = nil
      end
    end
  end
  if promptWidget and not promptWidget:isDestroyed() then
    promptWidget:destroy()
  end
  promptWidget = nil
  promptPos = nil
  targetVein = nil
end

-- Ancora o widget no tile de pos (com clobber guard vs outros módulos). Retorna o widget ou nil.
local function attachWidgetAt(pos)
  local tile = g_map.getTile(pos)
  if not tile then
    clearPrompt()
    return nil
  end
  if promptPos and posKey(promptPos) ~= posKey(pos) then
    clearPrompt()
  end
  local cur = tile:getWidget()
  if cur and not cur:isDestroyed() and cur:getId() ~= 'gatherPrompt' then
    clearPrompt()  -- outro módulo (ex.: game_markablespells) é dono do slot
    return nil
  end
  local w = ensureWidget()
  if not w then return nil end
  if tile:getWidget() ~= w then
    tile:setWidget(w)
  end
  promptPos = { x = pos.x, y = pos.y, z = pos.z }
  return w
end

-- Modo balão: "Press F to Collect" (aceso/esmaecido).
local function showLabel(pos, vein, dim)
  local w = attachWidgetAt(pos)
  if not w then return end
  targetVein = vein
  w:setOpacity(dim and 0.4 or 1.0)
  local label = w:getChildById('label')
  local resbg = w:getChildById('resbg')
  if label then
    label:setVisible(true)
    label:setText("Press " .. gatherKey .. " to Collect")
  end
  if resbg then resbg:setVisible(false) end
end

-- Modo barra de recurso: cargas restantes / máximo (durante a coleta). Estrutura de imagens do jogo
-- (progressbar_background/fill) com setWidth no fill — padrão game_incense, sem clipping (que não sobrevive
-- ao tile). Mantém targetVein para que apertar F de novo faça toggle-off.
local function showResourceBar(pos, vein, pct)
  local w = attachWidgetAt(pos)
  if not w then return end
  targetVein = vein
  w:setOpacity(1.0)
  local label = w:getChildById('label')
  local resbg = w:getChildById('resbg')
  if label then label:setVisible(false) end
  if resbg then
    resbg:setVisible(true)
    local resfill = resbg:getChildById('resfill')
    if resfill then
      local ratio = math.max(0, math.min(100, pct)) / 100
      -- -2 = 1px de borda de cada lado (o resfill começa em margin-left 1); o resbg aparece como borda
      resfill:setWidth(math.floor(math.max(0, resbg:getWidth() - 2) * ratio))
    end
  end
end

local function findTarget()
  local player = g_game.getLocalPlayer()
  if not player then return nil end
  local pp = player:getPosition()
  if not pp then return nil end
  for _, n in ipairs(NEIGHBORS) do
    local npos = { x = pp.x + n.dx, y = pp.y + n.dy, z = pp.z }
    local vein = gatherableAt(npos)
    if vein then
      return { pos = npos, vein = vein, cardinal = n.cardinal }
    end
  end
  return nil
end

local function isDimmed(target)
  -- cardinal = aceso; diagonal = esmaecido. É puramente geométrico (o cliente decide sozinho); não há
  -- "lado ocupado por outro" — um slot é um tile e só um jogador o ocupa.
  return not target.cardinal
end

-- Recomputa o widget do tile. Durante a coleta mostra a barra de recurso na veia do canal; fora,
-- mostra o balão "Press F" na veia adjacente. Event-driven (movimento + parse dos subtypes 1/3).
updateProximity = function()
  if channel ~= nil and channel.pos then
    local pct = 100  -- fallback cheio até o max/charges chegarem (subtype 1), para a barra sempre aparecer
    if channel.max and channel.max > 0 and channel.charges then
      pct = math.max(0, math.min(100, channel.charges / channel.max * 100))
    end
    showResourceBar(channel.pos, gatherableAt(channel.pos), pct)
    return
  end
  local target = findTarget()
  if not target then
    clearPrompt()
  else
    showLabel(target.pos, target.vein, isDimmed(target))
  end
end

-- ---------------------------------------------------------------------------------------------------
-- Hotkey
-- ---------------------------------------------------------------------------------------------------
local function doGather()
  if not targetVein then return end
  local now = g_clock.millis()
  if now < nextSendAt then return end
  nextSendAt = now + SEND_THROTTLE_MS
  g_game.use(targetVein)
end

modules.client_hotkeys.registerHotkeyCallback("GATHER",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if not ((wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled)) then
        return
      end
      doGather()
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end,
  function(actionName, action, keyInfo, chatState, keyType)
    if keyType == "primaryKey" and chatState == "chatDisabled" then
      gatherKey = (keyInfo and keyInfo.key ~= "" and keyInfo.key) or "?"
    end
  end)

-- ---------------------------------------------------------------------------------------------------
-- Protocolo (opcode 1573)
-- ---------------------------------------------------------------------------------------------------
local function parseGathering(protocol, msg)
  local subtype = msg:getU8()

  if subtype == ST_NODE_STATE then
    local x, y, z = msg:getU16(), msg:getU16(), msg:getU8()  -- Position (addPosition = u16,u16,u8)
    local charges = msg:getU32()
    local maxCharges = msg:getU32()
    local key = x .. ":" .. y .. ":" .. z
    nodeStates[key] = { charges = charges, max = maxCharges }
    if channel and channel.key == key then
      channel.charges = charges
      channel.max = maxCharges
      updateHud()
    end
    updateProximity()  -- cargas mudaram -> atualiza a barra de recurso

  elseif subtype == ST_STARTED then
    local x, y, z = msg:getU16(), msg:getU16(), msg:getU8()  -- Position
    local interval = msg:getU32()
    local yield = msg:getU16()
    local key = x .. ":" .. y .. ":" .. z
    local st = nodeStates[key]
    channel = {
      key = key,
      pos = { x = x, y = y, z = z },
      interval = math.max(1, interval),
      tickStart = g_clock.millis(),
      yieldPerTick = yield,
      charges = st and st.charges or nil,
      max = st and st.max or nil,
    }
    startPlayerBar(channel.interval)
    showHud()
    startHudTimer()
    updateProximity()  -- troca o balão pela barra de recurso na veia

  elseif subtype == ST_TICK then
    local nextInterval = msg:getU32()
    local _amount = msg:getU16()
    local chargesLeft = msg:getU32()
    if channel then
      channel.interval = math.max(1, nextInterval)
      channel.tickStart = g_clock.millis()
      channel.charges = chargesLeft
      startPlayerBar(channel.interval)
      updateHud()
      updateProximity()  -- atualiza a barra de recurso na veia
    end

  elseif subtype == ST_STOPPED then
    local _reason = msg:getU8()
    channel = nil
    clearPlayerBar()
    stopHudTimer()
    hideHud()
    updateProximity()  -- volta o balão de proximidade
  end
end

-- ---------------------------------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------------------------------
local function onGameEnd()
  stopHudTimer()
  clearPrompt()
  clearPlayerBar()
  destroyHud()
  nodeStates = {}
  channel = nil
end

function init()
  g_ui.importStyle('gathering')
  ProtocolGame.registerOpcode(OPCODE, parseGathering)
  connect(g_game, { onGameStart = updateProximity, onGameEnd = onGameEnd })
  connect(LocalPlayer, { onPositionChange = updateProximity, onWalkFinish = updateProximity })
end

function terminate()
  disconnect(LocalPlayer, { onPositionChange = updateProximity, onWalkFinish = updateProximity })
  disconnect(g_game, { onGameStart = updateProximity, onGameEnd = onGameEnd })
  ProtocolGame.unregisterOpcode(OPCODE)
  stopHudTimer()
  clearPrompt()
  clearPlayerBar()
  destroyHud()
  nodeStates = {}
  channel = nil
end
