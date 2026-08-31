local UP_EFFECT_ID = 807
local DOWN_EFFECT_ID = 808
local BUTTON_SIZE = 32
local TILE_GAP = 1

local FLY_DIR_UP = 0
local FLY_DIR_DOWN = 1

local FLY_KEYPRESS_DELAY_MS = 200
local nextFlyAt = 0

local upButton, downButton
local optionEnabled = true
local flying = false

local function gameMap()
  return modules.game_interface.gameMapPanel
end

local function tileSize()
  local map = gameMap()
  if not map then return 32, 32 end
  local dim = map:getVisibleDimension()
  if not dim or dim.width == 0 or dim.height == 0 then return 32, 32 end
  return map:getWidth() / dim.width, map:getHeight() / dim.height
end

local function reposition()
  if not upButton or not downButton then return end
  local map = gameMap()
  if not map then return end

  local _, tileH = tileSize()
  local offset = math.floor(tileH * TILE_GAP + BUTTON_SIZE * 2)

  for _, btn in ipairs({upButton, downButton}) do
    btn:breakAnchors()
    btn:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    btn:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
  end

  upButton:setMarginTop(-offset)
  downButton:setMarginTop(offset)
end

local function destroyButtons()
  if upButton then upButton:destroy() upButton = nil end
  if downButton then downButton:destroy() downButton = nil end
end

local function createButtons()
  destroyButtons()
  local map = gameMap()
  if not map then return end

  upButton = g_ui.createWidget('FlyControlButton', map)
  upButton:setId('flyUpButton')
  upButton.effect:setEffectId(UP_EFFECT_ID)
  upButton.onMouseRelease = function() g_game.flyAction(FLY_DIR_UP) return true end
  upButton:setTooltip('Fly Up')

  downButton = g_ui.createWidget('FlyControlButton', map)
  downButton:setId('flyDownButton')
  downButton.effect:setEffectId(DOWN_EFFECT_ID)
  downButton.onMouseRelease = function() g_game.flyAction(FLY_DIR_DOWN) return true end
  downButton:setTooltip('Fly Down')

  reposition()
end

function show()
  if not optionEnabled then return end
  if not upButton then createButtons() end
  if upButton then upButton:show() end
  if downButton then downButton:show() end
  reposition()
end

function hide()
  if upButton then upButton:hide() end
  if downButton then downButton:hide() end
end

function toggle(state)
  if state == nil then
    if upButton and upButton:isVisible() then hide() else show() end
  elseif state then
    show()
  else
    hide()
  end
end

function setEnabled(enabled)
  optionEnabled = enabled and true or false
  if optionEnabled then
    if flying then show() end
  else
    hide()
  end
end

local function onFlyControlsChange(state)
  flying = state and true or false
  toggle(flying)
end

local function onMapResize()
  reposition()
end

local function makeFlyHandler(dir)
  return function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if not ((wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled)) then
        return
      end
      local now = g_clock.millis()
      if now < nextFlyAt then return end
      nextFlyAt = now + FLY_KEYPRESS_DELAY_MS
      g_game.flyAction(dir)
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end
end

modules.client_hotkeys.registerHotkeyCallback("FLY_UP", makeFlyHandler(FLY_DIR_UP))
modules.client_hotkeys.registerHotkeyCallback("FLY_DOWN", makeFlyHandler(FLY_DIR_DOWN))

function init()
  g_ui.importStyle('flycontrols')
  -- Sync with the current option value (options.lua may have loaded before us).
  if modules.client_options and modules.client_options.getOption then
    local saved = modules.client_options.getOption('showFlyButtons')
    if saved ~= nil then optionEnabled = saved and true or false end
  end
  connect(g_game, {
    onFlyControlsChange = onFlyControlsChange,
    onGameEnd = hide,
  })
  local map = gameMap()
  if map then
    connect(map, { onGeometryChange = onMapResize, onVisibleDimensionChange = onMapResize })
  end
end

function terminate()
  disconnect(g_game, {
    onFlyControlsChange = onFlyControlsChange,
    onGameEnd = hide,
  })
  local map = gameMap()
  if map then
    disconnect(map, { onGeometryChange = onMapResize, onVisibleDimensionChange = onMapResize })
  end
  destroyButtons()
end
