local lootList = nil
local defaultWidth
local defaultHeight

-- the fade-out timers outlive their icon whenever the list is cleared early (logout, terminate),
-- so they have to be cancellable or they fire on an already destroyed widget
local pendingFades = {}

local function cancelPendingFades()
  for event in pairs(pendingFades) do
    removeEvent(event)
  end
  pendingFades = {}
end

modules.client_hotkeys.registerHotkeyCallback("AUTO_LOOT",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        autoloot()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

function hide()
  lootList:hide()
end

function show()
  lootList:show()
end

function reset()
  cancelPendingFades()
  lootList:destroyChildren()
end

local function reallocateIcons()
  local last = nil
  for k, v in pairs(lootList:getChildren()) do
    v:breakAnchors()

    if last then
      v:addAnchor(AnchorLeft, last:getId(), AnchorRight)
    else
      v:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    end
    last = v
  end
end

local function resize()
  if (lootList:getChildCount() == 0) then
    lootList:resize(defaultWidth, defaultHeight)
    return
  end

  local width = lootList:getPaddingLeft() + lootList:getPaddingRight()
  for k, v in pairs(lootList:getChildren()) do
    width = width + v:getWidth()
  end

  lootList:resize(width, defaultHeight)
end

function onLootAdd(itemId, count)
  local icon = g_ui.createWidget('LootItem', lootList)
  icon:setItemId(itemId)

  resize()
  reallocateIcons()

  local label = g_ui.createWidget('CountLabel', icon)
  label:setId(icon:getId() .. 'label')
  label:setText(count)
  label:addAnchor(AnchorRight, 'parent', AnchorRight)
  label:addAnchor(AnchorBottom, 'parent', AnchorBottom)

  local fadeEvent
  local finishFunc = function()
    pendingFades[fadeEvent] = nil
    icon:destroy()
    resize()
    reallocateIcons()
  end
  g_effects.fadeOut(icon, 5000)
  fadeEvent = scheduleEvent(finishFunc, 5010)
  pendingFades[fadeEvent] = true
end

function updateLootList(classic)
  if not lootList then
    return
  end
  local defaultMarginTop = 42
  if not classic then
    defaultMarginTop = 142
  end
  lootList:setMarginTop(defaultMarginTop)
end

local function onAutoLoot(items)
  for _, entry in ipairs(items) do
    onLootAdd(entry[1], entry[2])
  end
end

function onOnline()
  reset()
  show()
end

function onOffline()
  hide()
  reset()
end

function init()
  connect(g_game, {
    onGameStart = onOnline,
    onGameEnd = onOffline,
    onAutoLoot = onAutoLoot
  })

  lootList = g_ui.loadUI('autoloot', modules.game_interface.getRootPanel())
  defaultWidth = lootList:getWidth()
  defaultHeight = lootList:getHeight()

  if g_game.isOnline() then
    onOnline()
  end
end

function terminate()
  disconnect(g_game, {
    onGameStart = onOnline,
    onGameEnd = onOffline,
    onAutoLoot = onAutoLoot
  })

  cancelPendingFades()
  lootList:destroy()
end

function autoloot()
  g_game.requestAutoLoot()
end
