function init()
  inventoryButton = modules.client_topmenu.addMiddleGameToggleButton('inventoryButton', tr('Inventory') .. ' (Ctrl+I)', '/images/ui/topbuttons/icons/inventory', toggle)
  inventoryButton:setWidth(29)
end

modules.client_hotkeys.registerHotkeyCallback("PLAYERBAG",
  function(actionName, action, keyInfo, chatState, keyType)
    if inventoryButton and keyType == "primaryKey" and chatState == "chatDisabled" then
      inventoryButton:setTooltip(tr("Inventory (%s)", keyInfo.key))
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

function terminate()
  inventoryButton:destroy()
end

function toggle()
  g_game.open(g_game.getLocalPlayer():getInventoryItem(3))
end

function getInventoryButton()
  return inventoryButton
end
