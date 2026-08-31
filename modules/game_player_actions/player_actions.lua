local FISHING_ROD_SLOT = 2  -- inventory slot que segura a vara de pesca

modules.client_hotkeys.registerHotkeyCallback("FISHING_ROD",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        toggleFishing()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

modules.client_hotkeys.registerHotkeyCallback("WALK",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        g_game.talk("!walk")
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

modules.client_hotkeys.registerHotkeyCallback("POKESTOP",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        g_game.talk("!pokestop")
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

for i = 1, 6 do
  modules.client_hotkeys.registerHotkeyCallback("MEMORY_" .. i,
    function(actionName, action, keyInfo, chatState, keyType)
      local slot = i
      local callback = function()
        local chatModeEnabled = not modules.game_chat.consoleToggleChat
        local wantChat = (chatState == "chatEnabled")
        if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
          g_game.dittoMemoryCopySlot(slot)
        end
      end
      return { callback = callback, widget = modules.game_interface.getRootPanel() }
    end)
end

function init()
end

function terminate()
end

local function startChooseItem(releaseCallback)
  if g_ui.isMouseGrabbed() then return end
  if not releaseCallback then
    error("No mouse release callback parameter set.")
  end

  local mouseGrabberWidget = g_ui.createWidget('UIWidget')
  mouseGrabberWidget:setVisible(false)
  mouseGrabberWidget:setFocusable(false)

  connect(mouseGrabberWidget, {
    onMouseRelease = releaseCallback
  })

  mouseGrabberWidget:grabMouse()
  g_mouse.pushCursor('target')
end

local function onClickWithMouse(self, mousePosition, mouseButton)
  local item = nil
  if mouseButton == MouseLeftButton then
    local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
    if clickedWidget then
      if clickedWidget:getClassName() == 'UIGameMap' then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
          local thing = tile:getTopMoveThing()
          if thing and thing:isItem() then
            item = thing
          else
            item = tile:getTopCreature()
          end
        end
      elseif clickedWidget:getClassName() == 'UICreatureButton' then
        item = clickedWidget:getCreature()
      end
    end
  end

  if item then
    local player = g_game.getLocalPlayer()
    local rod = player and player:getInventoryItem(FISHING_ROD_SLOT)
    if rod then
      g_game.useInventoryItemWith(rod:getId(), item)
    end
  end

  g_mouse.popCursor('target')
  self:ungrabMouse()
  return true
end

function toggleFishing()
  startChooseItem(onClickWithMouse)
end
