local partyCreatures = {}
local minimapDungeons = {}
local minimapHouses = {}
local waypointsPositions = {}
local currentTimeIcon = nil

local minimapWidget = nil
local waypointWindow
local searchCoordsWindow = nil
minimapButton = nil
minimapWindow = nil
fullmapView = false
local loaded = false
oldZoom = nil
oldPos = nil
-- extended 118 removido: os textos de cidade migraram para o protocolo custom 1583 (onMinimapTexts).
-- O 118 colidia com ExtendedOPCodes.CODE_GMTOOLS, e como só um handler pode registrar cada extended
-- opcode, era este que ficava com ele — deixando o relay de input do /watch sem receptor no cliente.

local function updateHelpTooltip(fullMapKey)
  local helpLabel = minimapWindow and minimapWindow:recursiveGetChildById('helpLabel')
  if not helpLabel then return end
  local tooltip = tr('Hold left mouse button to navigate\nScroll mouse middle button to zoom\nRight mouse button to create map marks')
  if fullMapKey and fullMapKey ~= '' then
    tooltip = tooltip .. '\n' .. tr('Press %s to open the full map (Esc to close)', fullMapKey)
  end
  helpLabel:setTooltip(tooltip)
end

local function fullMapAssign(actionName, action, keyInfo, chatState, keyType)
  if keyType and (keyType ~= "primaryKey" or chatState ~= "chatDisabled") then return end
  updateHelpTooltip(keyInfo and keyInfo.key)
end

modules.client_hotkeys.registerHotkeyCallback("MINIMAP",
  function(actionName, action, keyInfo, chatState, keyType)
    if minimapButton and keyType == "primaryKey" and chatState == "chatDisabled" then
      minimapButton:setTooltip(string.format("Minimap (%s)", keyInfo.key))
    end
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        toggle()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

modules.client_hotkeys.registerHotkeyCallback("FULLMAP",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        toggleFullMap()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end, fullMapAssign)

function init()
  g_ui.loadUI('searchcoords')
  minimapWindow = g_ui.loadUI('minimap', modules.game_interface.getRightPanel())
  minimapWindow:setContentMinimumHeight(165)
  ProtocolGame.registerOpcode(199, onPartyUpdatePosition)

  if not minimapWindow.forceOpen then
    minimapButton = modules.client_topmenu.addMiddleGameToggleButton('minimapButton',
      tr('Minimap') .. ' (Ctrl+M)', '/images/ui/topbuttons/icons/minimap', toggle)
    minimapButton:setOn(true)
  end

  minimapWidget = minimapWindow:recursiveGetChildById('minimap')

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyPress('Alt+Left', function() minimapWidget:move(1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Right', function() minimapWidget:move(-1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Up', function() minimapWidget:move(0,1) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Down', function() minimapWidget:move(0,-1) end, gameRootPanel)
  g_keyboard.bindKeyDown('Escape', function()
    if fullmapView then
      toggleFullMap()
      return true
    end
  end, gameRootPanel)

  minimapWindow:setup()

  minimapWindow.onMinimize = onMinimapMinimize
  minimapWindow.onMaximize = onMinimapMaximize

  if minimapWindow:isOn() then
    setMinimapOverlaysVisible(false)
  end

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onReceiveWaypoints = onReceiveWaypoints,
    onMinimapMarks = onMinimapMarks,
    onEmptyHouses = onEmptyHouses,
    onEmptyHouseUpdate = onEmptyHouseUpdate,
    onWorldClockUpdate = onClockUpdate,
    -- protocolo custom 1583 (parseMinimapTexts em C++); substituiu o extended 118
    onMinimapTexts = onMinimapTexts
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  connect(Creature, {
    onPokemonPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  if fullmapView then
    toggleFullMap()
  end

  if g_game.isOnline() then
    saveMap()
  end
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onReceiveWaypoints = onReceiveWaypoints,
    onMinimapMarks = onMinimapMarks,
    onEmptyHouses = onEmptyHouses,
    onEmptyHouseUpdate = onEmptyHouseUpdate,
    onWorldClockUpdate = onClockUpdate,
    onMinimapTexts = onMinimapTexts
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  disconnect(Creature, {
    onPokemonPositionChange = updateCameraPosition
  })

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyPress('Alt+Left', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Right', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Up', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Down', gameRootPanel)
  g_keyboard.unbindKeyDown('Escape', gameRootPanel)

  ProtocolGame.unregisterOpcode(199)

  closeSearchCoords()

  minimapWindow:destroy()
  if minimapButton then
    minimapButton:destroy()
  end
end

function toggle()
  if not minimapButton then return end
  if minimapButton:isOn() then
    minimapWindow:close()
    minimapButton:setOn(false)
  else
    minimapWindow:open()
    minimapButton:setOn(true)
  end
end

function onMiniWindowClose()
  if minimapButton then
    minimapButton:setOn(false)
  end
end

function setMinimapOverlaysVisible(visible)
  if not minimapWindow then return end
  local ids = {'minimapCoordsPanel', 'minimapTimePanel', 'minimapButtonBarBg', 'minimapButtonBar'}
  for _, id in ipairs(ids) do
    local w = minimapWindow:getChildById(id)
    if w then w:setVisible(visible) end
  end
end

function onMinimapMinimize()
  setMinimapOverlaysVisible(false)
end

function onMinimapMaximize()
  setMinimapOverlaysVisible(true)
end

function onClockUpdate(intensity, color, minutes)
  local hours = math.floor(minutes / 60)
  minutes = minutes % 60
  local gameTime = string.format("%02d:%02d", hours, minutes)

  local icon = (hours >= 6 and hours < 18) and "day" or "night"
  currentTimeIcon = "/modules/game_minimap/images/" .. icon

  if minimapWindow then
    local mmTime = minimapWindow:recursiveGetChildById('minimapTime')
    if mmTime then
      mmTime:setText(gameTime)
    end
    local mmIcon = minimapWindow:recursiveGetChildById('minimapTimeIcon')
    if mmIcon then
      mmIcon:setImageSource("/modules/game_minimap/images/" .. icon)
    end
  end
  if minimapWidget then
    local fmTime = minimapWidget:recursiveGetChildById('fullmapTime')
    if fmTime then
      fmTime:setText(gameTime)
    end
    local fmIcon = minimapWidget:recursiveGetChildById('fullmapTimeIcon')
    if fmIcon then
      fmIcon:setImageSource("/modules/game_minimap/images/" .. icon)
    end
  end
end

function online()
  loadMap()
  updateCameraPosition()
end

function offline()
  if fullmapView then
    toggleFullMap()
  end

  for creatureId, _ in pairs(partyCreatures) do
    removeCreatureWidget(creatureId)
  end

  minimapWidget:deleteAllAlternativesWidgets()
  partyCreatures = {}
  minimapDungeons = {}
  minimapHouses = {}
  for index, config in pairs(waypointsPositions) do
      config.widget:destroy()
      config.widget = nil
  end
  waypointsPositions = {}
  saveMap()

  destroyWaypointWindow()
end

-- onMinimapTexts: protocolo custom 1583 (parseMinimapTexts em C++), migrado do extended 118.
-- Das 6 branches do handler antigo, apenas "add-text" era alimentada: os senders de add-icon,
-- remove-icon, remove-text, add-creature e remove-creature tinham ZERO callers no servidor, e o
-- add-image na verdade chega pelo opcode 1511 (dungeonSystem/portals.lua), não por este.
-- Cidades clicaveis no minimapa (protocolo custom 1587, parseCityList em C++).
-- Clicar pede confirmacao e manda o ID de volta pelo 1588; QUEM decide se o teleporte acontece e o
-- servidor, que revalida tudo pelo teleportSystem (o mesmo caminho da talkaction "h <cidade>").
-- O campo unlocked so pinta a cor -- nunca e tratado como autorizacao.
local CITY_COLOR_UNLOCKED = "#ffffff"
local CITY_COLOR_LOCKED   = "#9098a4"
-- Icone em vermelho, independente do texto. O tom apagado no travado mantem a distincao
-- destravado/travado tambem no pino, e nao so na cor do nome.
local CITY_ICON_UNLOCKED  = "#e04c4c"
local CITY_ICON_LOCKED    = "#8a3a3a"
local cityMarkers = {}

-- Uma confirmacao por vez: clicar em outra cidade com a caixa aberta trocaria de pergunta e deixaria
-- a anterior orfa na tela.
local cityConfirmBox = nil

function closeCityConfirm()
  if cityConfirmBox then
    cityConfirmBox:destroy()
    cityConfirmBox = nil
  end
end

-- Removal goes through the minimap, which is the real owner: addAlternativeWidget also files these
-- in its `alternatives` list, and destroying them from here left that list holding dead widgets -
-- the minimap then destroyed them again (deleteAllAlternativesWidgets / onDestroy), hence the
-- "destroy two times" warnings. The reverse order is handled inside removeAlternativeWidget, which
-- is idempotent (gamelib/ui/uiminimap.lua destroyIfAlive).
local function clearCityMarkers()
  closeCityConfirm()
  for _, widget in ipairs(cityMarkers) do
    if minimapWidget and not minimapWidget:isDestroyed() then
      minimapWidget:removeAlternativeWidget(widget)
    elseif not widget:isDestroyed() then
      widget:destroy()
    end
  end
  cityMarkers = {}
end

function onMinimapTexts(entries)
  clearCityMarkers()
  for _, entry in ipairs(entries) do
    -- cityId 0 = so rotulo (cidade que nao esta em TELEPORT_PLACES). Com id, o mesmo rotulo vira
    -- CityMarker: ganha icone e passa a teleportar no clique. Texto e posicoes continuam vindo do
    -- servidor pelo 1583, exatamente como antes.
    local clickable = entry.cityId and entry.cityId > 0
    for _, pos in ipairs(entry.positions) do
      local widget = g_ui.createWidget(clickable and "CityMarker" or "CityName")

      if clickable then
        local color = entry.unlocked and CITY_COLOR_UNLOCKED or CITY_COLOR_LOCKED
        local label = widget:getChildById("label")
        label:setText(entry.text)
        label:setColor(color)
        widget:getChildById("icon"):setIconColor(entry.unlocked and CITY_ICON_UNLOCKED or CITY_ICON_LOCKED)
        -- O container nasce com 12px (so o icone). Sem esticar ate o fim do nome, clicar no NOME
        -- cai fora do widget e o UIMinimap trata como clique no mapa.
        widget:setWidth(12 + 3 + label:getWidth())
        -- O icone nao preenche os cantos do quadrado; sem isto o pixel-test perde hover e clique.
        widget:setPixelTesting(false)
        widget:setClipTransparency(false)
        widget:setTooltip(entry.text)
        widget.cityId = entry.cityId
        widget.cityName = entry.text
        widget.cityUnlocked = entry.unlocked and true or false

        widget.onMouseRelease = function(self, mousePos, button)
          if button ~= MouseLeftButton then
            return false
          end
          -- displayAllianceBox NAO se fecha sozinha: addButton so liga o onClick ao callback. Quem
          -- chama guarda a janela e destroi -- mesmo padrao do game_guild.
          local cityId, cityName = self.cityId, self.cityName
          closeCityConfirm()

          -- The colour already told the player it is locked; clicking has to say so too, instead of
          -- offering a teleport the server will refuse.
          if not self.cityUnlocked then
            cityConfirmBox = displayAllianceBox(tr("Teleport"),
              tr("You have not unlocked %s yet.", cityName), {
                { text = tr("Ok"), callback = closeCityConfirm },
                anchor = AnchorHorizontalCenter
              }, closeCityConfirm, closeCityConfirm)
            return true
          end

          cityConfirmBox = displayAllianceBox(tr("Teleport"),
            tr("Do you really want to teleport to %s?", cityName), {
              { text = tr("Yes"), callback = function()
                  g_game.sendCityTeleport(cityId)
                  closeCityConfirm()
                end },
              { text = tr("No"),  callback = closeCityConfirm },
              anchor = AnchorHorizontalCenter
            }, closeCityConfirm, closeCityConfirm)
          -- Engole o release: sem o true, o release sobe e o personagem sai andando.
          return true
        end

        cityMarkers[#cityMarkers + 1] = widget
      else
        widget:setText(entry.text)
        -- color/font nunca vieram do servidor: seguem nil e os fallbacks valem
        widget:setColor(entry.color or "#ffffff")
        if entry.font then
          widget:setFont(entry.font)
        end
      end

      widget.maxZoom = -1
      if entry.maxZoom then
        widget.maxZoom = entry.maxZoom
      end

      if entry.minZoom then
        widget.minZoom = entry.minZoom
      end

      -- Nome de cidade sempre por cima dos icones (marcas, casas, portais).
      widget.alwaysOnTop = true
      minimapWidget:addAlternativeWidget(widget, pos)
    end
  end
end

local function buildPortalTooltip(name, bosses)
  local rootPanel = modules.game_interface.getRootPanel()
  local tooltip = g_ui.createWidget('PortalBossTooltip', rootPanel)
  tooltip:setPhantom(true)
  tooltip:setFocusable(false)
  tooltip:hide()
  tooltip:getChildById('title'):setText(name)

  local bossList = tooltip:getChildById('bossList')
  for _, boss in ipairs(bosses) do
    local entry = g_ui.createWidget('PortalBossEntry', bossList)
    entry:getChildById('creature'):setOutfit({ type = boss.lookType })
    entry:getChildById('bossName'):setText(boss.name)
  end

  local count = #bosses
  if count > 0 then
    local rows = math.ceil(count / 3)
    bossList:setHeight(rows * 112 + (rows - 1) * 4)
  end
  return tooltip
end

function onMinimapMarks(action, portals)
  if action == 1 then -- add-image
    for _, portalData in ipairs(portals) do
      local position = portalData.position
      local name     = portalData.name
      local image    = portalData.image
      local bosses   = portalData.bosses or {}

      if not minimapDungeons[name] then
        minimapDungeons[name] = {}
        local widget = g_ui.createWidget('MinimapFlag')
        widget:setImageSource("/images/game/dungeons/" .. image)
        widget.maxZoom = 0
        widget.minZoom = 3
        widget:resize(32, 32)
        widget.name = name
        -- Os icones sao imagens circulares com cantos transparentes; sem isso
        -- o pixel-test ignora a hover nos cantos do quadrado 32x32.
        widget:setPixelTesting(false)
        widget:setClipTransparency(false)

        if #bosses > 0 then
          widget:setTooltip(buildPortalTooltip(name, bosses))
        else
          widget:setTooltip(name)
        end

        minimapWidget:addAlternativeWidget(widget, position)
        minimapDungeons[name].widget = widget
        -- icons registered after the legend was read (login, new dungeon) must honour it too
        widget.zoneHidden = not isLegendLayerEnabled('dungeons')
        widget:setVisible(not widget.zoneHidden)
      end
    end
  end
end

-- Casas sem dono enviadas pelo servidor no login (g_game.onEmptyHouses).
-- Renderiza um icone de casa (Font Awesome, verde) sobre a posicao de
-- entrada da casa; so aparece no minimap full, igual aos icones de dungeon.
-- Cria e registra o icone de uma casa sem dono (indexado por houseId).
-- Renderiza sempre no andar 7 (superficie), independente do z de entrada,
-- para o icone aparecer na vista padrao do mapa.
local function addHouseFlag(id, name, x, y)
  if minimapHouses[id] then
    return
  end
  local widget = g_ui.createWidget('MinimapHouseFlag')
  -- Visivel em qualquer zoom (inclusive zoom-out total): maxZoom = menor
  -- zoom possivel e minZoom = maior, cobrindo todo o range do minimap.
  widget.maxZoom = minimapWidget:getMinZoom()
  widget.minZoom = minimapWidget:getMaxZoom()
  widget.name = name
  -- O icone nao preenche os cantos do quadrado; sem isto o pixel-test
  -- ignora o hover (necessario para o tooltip com o nome da casa).
  widget:setPixelTesting(false)
  widget:setClipTransparency(false)
  widget:setTooltip(name)

  minimapWidget:addAlternativeWidget(widget, { x = x, y = y, z = 7 })
  minimapHouses[id] = { widget = widget }
  widget.zoneHidden = not isLegendLayerEnabled('houses')
  widget:setVisible(not widget.zoneHidden)
end

local function removeHouseFlag(id)
  local data = minimapHouses[id]
  if data and data.widget then
    minimapWidget:removeAlternativeWidget(data.widget)
  end
  minimapHouses[id] = nil
end

-- Sincronizacao completa (enviada no login): substitui toda a lista.
function onEmptyHouses(houses)
  for id, _ in pairs(minimapHouses) do
    removeHouseFlag(id)
  end
  minimapHouses = {}

  for _, house in ipairs(houses) do
    addHouseFlag(house.id, house.name, house.x, house.y)
  end

  -- Se o minimap full ja estiver aberto, insere os novos icones na hora.
  if fullmapView then
    minimapWidget:setAlternativeWidgetsVisible(true)
  end
end

-- Atualizacao incremental de UMA casa (broadcast ao trocar de dono).
-- added == true: casa ficou sem dono -> cria o icone.
-- added == false: casa ganhou dono -> remove o icone.
function onEmptyHouseUpdate(added, id, name, x, y, z)
  if added then
    addHouseFlag(id, name, x, y)
    if fullmapView then
      minimapWidget:setAlternativeWidgetsVisible(true)
    end
  else
    removeHouseFlag(id)
  end
end

function loadMap()
  local clientVersion = g_game.getClientVersion()

  g_minimap.clean()
  loaded = false

  local minimapFile = '/minimap.otmm'
  local dataMinimapFile = '/data' .. minimapFile
  local versionedMinimapFile = '/minimap' .. clientVersion .. '.otmm'
  if g_resources.fileExists(dataMinimapFile) then
    loaded = g_minimap.loadOtmm(dataMinimapFile)
  end
  if not loaded and g_resources.fileExists(versionedMinimapFile) then
    loaded = g_minimap.loadOtmm(versionedMinimapFile)
  end
  if not loaded and g_resources.fileExists(minimapFile) then
    loaded = g_minimap.loadOtmm(minimapFile)
  end
  if not loaded then
    print("Minimap couldn't be loaded, file missing?")
  end

  g_minimap.loadImage("/images/minimap.png", { x = 31, y = 25, z = 7 }, 0.5)
  minimapWidget:load()
end

function saveMap()
  local clientVersion = g_game.getClientVersion()
  local minimapFile = '/minimap' .. clientVersion .. '.otmm'
  g_minimap.saveOtmm(minimapFile)
  minimapWidget:save()
end

function updateCameraPosition()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition(true)
  if not pos then return end
  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(pos)
    end
    minimapWidget:setCrossPosition(pos)
  end

  updateCoordsLabel(pos)

  if partyCreatures then
    local playerPosition = pos
    for creatureID, creatureInfo in pairs(partyCreatures) do
      if creatureInfo.widget then
        local oldConfigDiffZ = partyCreatures[creatureID].floorDiffZ
        partyCreatures[creatureID].floorDiffZ = playerPosition.z - creatureInfo.originalPos.z
        if oldConfigDiffZ ~= partyCreatures[creatureID].floorDiffZ then
          creatureInfo.pos.z = pos.z
          minimapWidget:centerInPosition(creatureInfo.widget, creatureInfo.pos)
          local imageSource = partyCreatures[creatureID].floorDiffZ == 0 and "" or nil
          if not imageSource then
            imageSource = partyCreatures[creatureID].floorDiffZ > 0 and "/images/game/minimap/flag14" or "/images/game/minimap/flag15"
          end
          creatureInfo.widget.floorIcon:setImageSource(imageSource)
        end
      end
    end
  end
end

function updateCoordsLabel(pos)
  if not pos then return end
  local coordsText = string.format('%d, %d, %d', pos.x, pos.y, pos.z)
  if minimapWindow then
    local label = minimapWindow:recursiveGetChildById('minimapCoords')
    if label then
      label:setText(coordsText)
    end
  end
  if minimapWidget then
    local label = minimapWidget:recursiveGetChildById('fullmapCoords')
    if label then
      label:setText(coordsText)
    end
  end
end

function getMinimapWidget()
  return minimapWidget
end

function showFullMap()
  if not fullmapView then
    toggleFullMap()
  end
end

-- Legend layers: which icon collections are drawn over the full map. Kept per layer in g_settings
-- and saved right away, since settings only flush on a clean exit.
local LEGEND_LAYERS = {
  houses = 'minimap-show-houses',
  dungeons = 'minimap-show-dungeons',
  instances = 'minimap-show-instances'
}

local function legendCollection(layer)
  if layer == 'houses' then return minimapHouses end
  if layer == 'dungeons' then return minimapDungeons end
  -- Os marcadores de instancia sao criados e destruidos pelo game_instanceentry, que carrega
  -- depois deste modulo: a colecao e pedida na hora em vez de mantida aqui.
  if layer == 'instances' then
    local instanceEntry = modules.game_instanceentry
    return instanceEntry and instanceEntry.getDoorMarkers() or nil
  end
  return nil
end

function isLegendLayerEnabled(layer)
  local key = LEGEND_LAYERS[layer]
  if not key then return true end
  return g_settings.getBoolean(key, true)
end

function applyLegendLayer(layer)
  local collection = legendCollection(layer)
  if not collection then return end
  local enabled = isLegendLayerEnabled(layer)
  for _, entry in pairs(collection) do
    if entry and entry.widget and not entry.widget:isDestroyed() then
      -- zoneHidden, not just setVisible: UIMinimap:onZoomChange re-evaluates every marker and would
      -- undo a plain hide on the next zoom or reopen. zoneHidden is the opt-out it honours.
      entry.widget.zoneHidden = not enabled
      entry.widget:setVisible(enabled)
    end
  end
end

function setLegendLayer(layer, enabled)
  local key = LEGEND_LAYERS[layer]
  if not key then return end
  g_settings.set(key, enabled)
  g_settings.save()
  applyLegendLayer(layer)
end

-- Rows are named after the layer they drive, so the SwitchBox handler can pass its own row id
local LEGEND_ROWS = {
  { layer = 'houses', text = 'Show House Icons', icon = '/images/game/minimap/house' },
  { layer = 'dungeons', text = 'Show Dungeon Icons', icon = '/images/game/minimap/dungeon' },
  { layer = 'instances', text = 'Show Instance Hunts', icon = '/images/game/minimap/instance' },
}
local LEGEND_ROW_HEIGHT = 26
local LEGEND_HEADER_HEIGHT = 30
local LEGEND_COLLAPSED_KEY = 'minimap-legend-collapsed'

local LEGEND_SWITCH_ON  = '/images/general_ui/icons/base_slider_selected'
local LEGEND_SWITCH_OFF = '/images/general_ui/icons/base_slider'

-- Overriding the SwitchBox @onCheckChange also takes over the slider visual it used to drive, so
-- the artwork has to be driven here. setChecked with the value already in place does not re-fire.
local function setLegendSwitch(check, checked)
  if not check then return end
  check:setChecked(checked)
  local slider = check:getChildById('sliderButton')
  if slider then slider:setMarginLeft(checked and 20 or 2) end
  check:setImageSource(checked and LEGEND_SWITCH_ON or LEGEND_SWITCH_OFF)
end

function onLegendToggle(layer, enabled)
  if not LEGEND_LAYERS[layer] then return end
  if minimapWidget then
    local row = minimapWidget:recursiveGetChildById(layer)
    if row then setLegendSwitch(row:getChildById('check'), enabled) end
  end
  setLegendLayer(layer, enabled)
end

function isLegendCollapsed()
  return g_settings.getBoolean(LEGEND_COLLAPSED_KEY, false)
end

function applyLegendCollapsed()
  if not minimapWidget then return end
  local panel = minimapWidget:recursiveGetChildById('fullmapLegendPanel')
  local rows = minimapWidget:recursiveGetChildById('fullmapLegendRows')
  local arrow = minimapWidget:recursiveGetChildById('fullmapLegendCollapse')
  if not panel or not rows then return end

  local collapsed = isLegendCollapsed()
  rows:setVisible(not collapsed)
  panel:setHeight(collapsed and LEGEND_HEADER_HEIGHT
    or (LEGEND_HEADER_HEIGHT + #LEGEND_ROWS * LEGEND_ROW_HEIGHT + 6))
  if arrow then arrow:setIcon(collapsed and '@fa solid 12 f078' or '@fa solid 12 f077') end
end

function toggleLegendCollapsed()
  g_settings.set(LEGEND_COLLAPSED_KEY, not isLegendCollapsed())
  g_settings.save()
  applyLegendCollapsed()
end

function refreshLegend()
  if not minimapWidget then return end
  for _, row in ipairs(LEGEND_ROWS) do
    local widget = minimapWidget:recursiveGetChildById(row.layer)
    if widget then
      local label = widget:getChildById('name')
      if label then label:setText(tr(row.text)) end
      local pin = widget:getChildById('pin')
      if pin and g_resources.fileExists(row.icon .. '.png') then pin:setImageSource(row.icon) end
      setLegendSwitch(widget:getChildById('check'), isLegendLayerEnabled(row.layer))
    end
    applyLegendLayer(row.layer)
  end
  applyLegendCollapsed()
end

function setFullmapOverlaysVisible(visible)
  if not minimapWidget then return end
  local ids = {'fullmapLegendPanel', 'fullmapTimePanel', 'fullmapCoordsPanel', 'fullmapButtonBarBg', 'fullmapButtonBar', 'fullmapCloseButton'}
  for _, id in ipairs(ids) do
    local w = minimapWidget:getChildById(id)
    if w then w:setVisible(visible) end
  end
  -- Sync values when showing
  if visible then
    refreshLegend()
    local srcCoords = minimapWindow and minimapWindow:recursiveGetChildById('minimapCoords')
    local fmCoords = minimapWidget:recursiveGetChildById('fullmapCoords')
    if srcCoords and fmCoords then fmCoords:setText(srcCoords:getText()) end
    local srcTime = minimapWindow and minimapWindow:recursiveGetChildById('minimapTime')
    local fmTime = minimapWidget:recursiveGetChildById('fullmapTime')
    if srcTime and fmTime then fmTime:setText(srcTime:getText()) end
    local fmIcon = minimapWidget:recursiveGetChildById('fullmapTimeIcon')
    if fmIcon and currentTimeIcon then fmIcon:setImageSource(currentTimeIcon) end
  end
end

function toggleFullMap()
  if not fullmapView then
    fullmapView = true
    minimapWindow:hide()
    minimapWidget:setParent(modules.game_interface.getRootPanel())
    minimapWidget:setSize({width = 1400, height = 800})
    minimapWidget:setPadding(-32)
    minimapWidget:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    minimapWidget:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    minimapWidget:setAlternativeWidgetsVisible(true)
    minimapWidget:setOpacity(0.9)
    setFullmapOverlaysVisible(true)
  else
    fullmapView = false
    setFullmapOverlaysVisible(false)
    minimapWidget:setParent(minimapWindow:getChildById('contentsPanel'))
    minimapWidget:fill('parent')
    minimapWidget:setPadding(0)
    minimapWindow:setMarginTop(0)
    minimapWindow:setMarginLeft(0)
    minimapWindow:setMarginRight(0)
    minimapWindow:setMarginBottom(0)
    minimapWindow:show()
    minimapWidget:setAlternativeWidgetsVisible(false)

    if modules.game_pokedex then
      modules.game_pokedex.cleanLocationWidgets()
    end
  end

  --local zoom = oldZoom or 0
  --local pos = oldPos or minimapWidget:getCameraPosition()
  local zoom = oldZoom or 0
  local pos = minimapWidget:getCameraPosition()
  pos.z = 7
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()
  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end

function onPartyUpdatePosition(protocol, msg)
  local type = msg:getU8()
  local creatureID = msg:getU32()
  if type == 0 then
    removeCreatureWidget(creatureID)
    return
  end

  local position = {
    x = msg:getU16(),
    y = msg:getU16(),
    z = msg:getU8()
  }

  local direction = msg:getU8()

  local completeInformation = msg:getU8()
  local player = g_game.getLocalPlayer()
  local config = partyCreatures[creatureID]
  if not config then
    partyCreatures[creatureID] = {}
    config = partyCreatures[creatureID]
  end

  config.originalPos = {x = position.x, y = position.y, z = position.z}
  config.direction = direction

  local needUpdateFloor = false
  if player then
    local playerPosition = player:getPosition()
    local oldConfigDiffZ = config.floorDiffZ
    config.floorDiffZ = playerPosition.z - position.z

    if oldConfigDiffZ ~= config.floorDiffZ then
      needUpdateFloor = true
    end
    position.z = playerPosition.z
  end

  config.pos = position
  if completeInformation ~= 0 then
    config.name = msg:getString()
    config.outfit = {
      type = msg:getU16(),
      head = msg:getU8(),
      body = msg:getU8(),
      legs = msg:getU8(),
      feet = msg:getU8()
    }
  end
  
  local newWidget = nil
  if config and config.widget then
    newWidget = config.widget
  end

  if not newWidget then
    newWidget = g_ui.createWidget('CreatureParty')
    if config.outfit then
      newWidget:setOutfit(config.outfit)
    end
    minimapWidget:insertChild(1, newWidget)
  end

  if completeInformation ~= 0 then
    newWidget:setTooltip(config.name)
    partyCreatures[creatureID].widget = newWidget
  end

  newWidget:setDirection(config.direction)

  if needUpdateFloor and config.floorDiffZ then
    local imageSource = config.floorDiffZ == 0 and "" or nil
    if not imageSource then
      imageSource = config.floorDiffZ > 0 and "/images/game/minimap/flag14" or "/images/game/minimap/flag15"
    end
    newWidget.floorIcon:setImageSource(imageSource)
  end
  minimapWidget:centerInPosition(newWidget, position)
end

function removeCreatureWidget(creatureId)
  if partyCreatures[creatureId] and partyCreatures[creatureId].widget then
    partyCreatures[creatureId].widget:destroy()
    partyCreatures[creatureId].widget = nil
  end
end

function removeWaypointCreatureWidget(creatureId)
  if partyCreatures[creatureId] and partyCreatures[creatureId].widget then
    partyCreatures[creatureId].widget:destroy()
    partyCreatures[creatureId].widget = nil
  end
end

function getCreaturesWidgets()
  return partyCreatures
end

function onReceiveWaypoints(waypoints)
  for _, config in ipairs(waypoints) do
    if waypointsPositions[config.name] then
      waypointsPositions[config.name].widget:destroy()
      waypointsPositions[config.name] = nil
    end
    if not waypointsPositions[config.name] then
      waypointsPositions[config.name] = config
      local widget = g_ui.createWidget("WaypointCreature")
      widget.background.creature:setOutfit({type = config.lookType})
      widget.maxZoom = 0
      if config.minZoom ~= nil then
        widget.minZoom = config.minZoom
      end

      widget:setTooltip(config.name)
      widget.name = config.name

      waypointsPositions[config.name].widget = widget
      minimapWidget:insertChild(1, widget)
      minimapWidget:centerInPosition(widget, config.position)
      widget:setCursor("pointer")
      widget:setImageColor("#383838")
      widget.onMouseRelease = function(self)
        if waypointWindow then return end
        waypointWindow = g_ui.loadUI('waypoint', modules.game_interface.getRootPanel())
        if config.unlocked then
          waypointWindow.title:setText(self.name)
          waypointWindow.description:setColoredText({
            "Do you really want to teleport to the ", "#FFFFFF",
            self.name, "#279cf4",
            " Pillar? This process will cost you 1 Energy Foil.", "#FFFFFF"
          })
          waypointWindow.pillarId = config.id
          return
        end

        waypointWindow.title:setText(self.name)
        waypointWindow.description:setText(string.format("First you need to go to the %s pillar to be able to release the teleport.", self.name))
      end
    end
  end
end

function destroyWaypointWindow()
  if not waypointWindow then
    return
  end

  waypointWindow:destroy()
  waypointWindow = nil
end  

function confirmWaypointWindow()
  if not waypointWindow then
    return
  end

  local id = waypointWindow.pillarId or 0
  local numberId = tonumber(id)
  if numberId and numberId > 0 then
    g_game.sendWaypointTeleport(numberId)
  end
  destroyWaypointWindow()
end

-- Minimap bar button wrappers
function minimapFloorUp()
  if minimapWidget then minimapWidget:floorUp(1) end
end

function minimapFloorDown()
  if minimapWidget then minimapWidget:floorDown(1) end
end

function minimapReset()
  if minimapWidget then minimapWidget:reset() end
end

function minimapZoomIn()
  if minimapWidget then minimapWidget:zoomIn() end
end

function minimapZoomOut()
  if minimapWidget then minimapWidget:zoomOut() end
end

-- Search coordinates
function openSearchCoords()
  if searchCoordsWindow then return end
  searchCoordsWindow = g_ui.createWidget('SearchCoordsWindow', modules.game_interface.getRootPanel())
  g_uistates.push(searchCoordsWindow)
  local input = searchCoordsWindow:getChildById('coordsInput')
  if input then
    input:focus()
  end
end

function closeSearchCoords()
  if not searchCoordsWindow then return end
  g_uistates.remove(searchCoordsWindow)
  searchCoordsWindow:destroy()
  searchCoordsWindow = nil
end

function onSearchCoordsTextChange(widget)
  if not searchCoordsWindow then return end
  local text = widget:getText()
  local label = searchCoordsWindow:getChildById('validationLabel')
  local x, y, z = text:match('(%d+)%s*,%s*(%d+)%s*,%s*(%d+)')
  if x and y and z then
    label:setText('Coordenada valida: ' .. x .. ', ' .. y .. ', ' .. z)
    label:setColor('#00ff00')
    label:setVisible(true)
  else
    label:setText('Formato: x, y, z')
    label:setColor('#ff6666')
    label:setVisible(text ~= '')
  end
end

function confirmSearchCoords()
  if not searchCoordsWindow then return end
  local text = searchCoordsWindow:getChildById('coordsInput'):getText()
  local x, y, z = text:match('(%d+)%s*,%s*(%d+)%s*,%s*(%d+)')
  if not x then return end

  x, y, z = tonumber(x), tonumber(y), tonumber(z)
  local pos = {x = x, y = y, z = z}

  if minimapWidget then
    minimapWidget:setCameraPosition(pos)
  end

  local createFlag = searchCoordsWindow:recursiveGetChildById('createFlag')
  if createFlag and createFlag:isChecked() then
    minimapWidget:addFlag(pos, 2, '')
  end

  closeSearchCoords()
end