-- Guild Boss HUD — notificação flutuante (topo-esquerdo do mapa) enquanto o guild boss está ABERTO.
-- Duas fontes de dados:
--   onGuildFullInfo   → broadcasts (open/join/logout/defeat) e ao abrir a janela da guilda; traz data.bosses.
--   onGuildActiveBoss → packet LEVE enviado no login quando o boss já está aberto (só o bloco do boss, com o
--                       lookType embutido; num login fresco ainda não há data.bosses).
-- game_guild é sandboxed, então NÃO dá para chamar joinGuildBoss()/storageGuildInfo daqui — usamos
-- g_game.sendGuildJoinBoss() e a table crua do evento.

local hud
local countdownEvent
local pulseEvent
local dismissedKey = nil          -- abertura já fechada (× ou Entrar); a próxima abertura volta a aparecer
local dismissedEndTime = 0        -- endTime da abertura fechada — desempata reabertura (instanceId é RECICLADO)
local currentKey = nil            -- chave da abertura atualmente exibida
local endTime = 0                  -- os.time() do fechamento (closeTime é DURAÇÃO restante, não epoch)
local totalSeconds = 1800          -- denominador da barra; 30 min é a duração do guild boss

-- ---------------------------------------------------------------------------------------------------
local function stopCountdown()
  if countdownEvent then removeEvent(countdownEvent) countdownEvent = nil end
end

local function stopPulse()
  if pulseEvent then removeEvent(pulseEvent) pulseEvent = nil end
end

local function hide()
  if hud then hud:hide() end
  stopCountdown()
  stopPulse()
end

-- lookType do boss ativo, buscado na lista de bosses (config) por nome.
local function findLookType(data, bossName)
  if not data.bosses then return 0 end
  for _, cfg in ipairs(data.bosses) do
    if cfg.bossName == bossName then return cfg.lookType or 0 end
  end
  return 0
end

local function tick()
  if not hud or not hud:isVisible() then return end
  local left = endTime - os.time()
  if left <= 0 then
    hide()
    return
  end
  hud:getChildById('timerLabel'):setText("fecha em " .. formatMS(left))
  hud:getChildById('timerBar'):setPercent(math.max(0, math.min(100, left / totalSeconds * 100)))
end

-- ponto dourado pulsante (cycleEvent alternando opacidade — g_effects.startBlink tem bug de onClick).
local function startPulse()
  stopPulse()
  local on = true
  pulseEvent = cycleEvent(function()
    local dot = hud and hud:getChildById('pulseDot')
    if dot then dot:setOpacity(on and 1.0 or 0.3) end
    on = not on
  end, 550)
end

-- ---------------------------------------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------------------------------------
-- Identidade de uma ABERTURA de boss. instanceId é RECICLADO (fechar Marowak inst.1 e abrir Jynx inst.1 dá o
-- mesmo número), então a chave junta nome+instância — e o endTime desempata reaberturas do MESMO boss.
local function bossKey(boss)
  return (boss.bossName or "") .. ":" .. (boss.instanceId or 0)
end

-- Renderiza o HUD a partir de um bloco activeBoss (compartilhado pelos dois eventos). O lookType vem separado
-- porque cada fonte o resolve diferente: FULL_INFO via findLookType(data.bosses); ACTIVE_BOSS já traz embutido.
local function showBoss(boss, lookType)
  local closeTime = boss.closeTime or 0
  endTime = os.time() + closeTime           -- absoluto (instante do fecho); estável entre broadcasts da abertura
  totalSeconds = math.max(closeTime, 1800)  -- se o boss abriu há pouco, closeTime ~= duração total
  currentKey = bossKey(boss)

  -- Já fechado (× ou Entrar) NESTA abertura? Só suprime se a chave BATE E o endTime é ~o mesmo: uma reabertura
  -- do mesmo boss traz timer novo (~minutos à frente) e portanto NÃO é suprimida. (instanceId sozinho não serve.)
  if currentKey == dismissedKey and math.abs(endTime - dismissedEndTime) <= 10 then
    hide()
    return
  end

  hud:getChildById('bossName'):setText(boss.bossName or "-")
  if lookType and lookType > 0 then
    hud:getChildById('bossPhoto'):setOutfit({ type = lookType })
  end
  hud:getChildById('participants'):setText(
    string.format("%d/%d na luta", boss.participants or 0, boss.maxParticipants or 0))

  hud:show()          -- mostrar ANTES do tick() de priming, senão o guard isVisible() corta e o timer fica em --:--
  stopCountdown()
  tick()
  countdownEvent = cycleEvent(tick, 1000)
  startPulse()
end

-- FULL_INFO: chega em broadcasts (open/join/logout/defeat) e ao abrir a janela da guilda; traz data.bosses.
local function onFullInfo(data)
  if not hud then return end
  local boss = data and data.activeBoss
  if not (boss and boss.openned) then
    hide()          -- sem boss aberto
    return
  end
  showBoss(boss, findLookType(data, boss.bossName))
end

-- ACTIVE_BOSS: packet leve enviado no login quando o boss já está aberto. O arg é o bloco activeBoss "cru"
-- (não vem dentro de data.activeBoss) e já carrega o lookType — num login fresco não há data.bosses.
local function onActiveBoss(boss)
  if not hud then return end
  if not (boss and boss.openned) then
    hide()
    return
  end
  showBoss(boss, boss.lookType or 0)
end

-- O servidor manda S2C.CLOSE (-> onGuildClose) SÓ quando o join do guild boss é ACEITO (joinGuildBoss, depois dos
-- guards de level/premium/HWID). Então isto fecha o HUD por QUALQUER caminho de entrar (botão Entrar do HUD OU o
-- "Join" da janela da guild) e só se o join deu certo — se for recusado, não vem CLOSE e o HUD continua aberto.
local function onBossJoined()
  dismissedKey, dismissedEndTime = currentKey, endTime  -- marca a abertura como fechada (o broadcast do join não reabre)
  hide()
end

local function onEnter()
  g_game.sendGuildJoinBoss()  -- entra direto; quem fecha o HUD é o onGuildClose quando o servidor aceita o join
end

local function onDismiss()
  dismissedKey, dismissedEndTime = currentKey, endTime  -- não reaparece até abrir/reabrir outro boss
  hide()
end

local function onGameEnd()
  hide()
end

-- ---------------------------------------------------------------------------------------------------
function init()
  g_ui.loadUI('guildbosshud')  -- só registra o estilo; o createWidget abaixo instancia no mapPanel
  hud = g_ui.createWidget('guildBossHud', modules.game_interface.getMapPanel())
  hud:hide()
  hud:breakAnchors()
  hud:addAnchor(AnchorTop, 'parent', AnchorTop)
  hud:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  hud:setMarginTop(30)
  hud:setMarginLeft(30)

  hud:getChildById('closeBtn').onClick = onDismiss
  hud:getChildById('enterBtn').onClick = onEnter

  connect(g_game, { onGuildFullInfo = onFullInfo, onGuildActiveBoss = onActiveBoss, onGuildClose = onBossJoined, onGameEnd = onGameEnd })
end

function terminate()
  disconnect(g_game, { onGuildFullInfo = onFullInfo, onGuildActiveBoss = onActiveBoss, onGuildClose = onBossJoined, onGameEnd = onGameEnd })
  stopCountdown()
  stopPulse()
  if hud then hud:destroy() hud = nil end
end
