local currentProfileIndex = 1
local profilesDirty = {} -- profilesDirty[index] = true if profile has unsaved changes
local confirmBox = nil
local renameWindow = nil
local MAX_PROFILES = 10
local hotkeyState = nil
local hotkeyStateIndex = nil

function init()
  hotkeyManager = g_ui.loadUI("hotkey_manager", g_ui.getRootWidget())
  hotkeyManager:hide()
  g_keyboard.bindKeyDown('Ctrl+K', toggle)

  -- Load profile names
  local savedNames = g_settings.getNode('hotkeyProfileNames') or {}
  for i = 1, MAX_PROFILES do
    local name = savedNames[tostring(i)] or ("Profile " .. i)
    hotkeyManager.profileSelector:addOption(name, i)
  end

  -- Init first profile
  currentProfileIndex = 1
  hotkeyProfile = HotkeyProfiles:new(getProfileSettingsKey(currentProfileIndex))
  initProfile(hotkeyProfile)

  hotkeyManager.saveProfile.onClick = saveProfileSettings
  hotkeyManager.resetProfile.onClick = resetProfileSettings
  hotkeyManager.renameProfile.onClick = onRenameClicked

  hotkeyManager.profileSelector.onOptionChange = onProfileSelectorChanged
  hotkeyManager.closeButton.onClick = onCloseClicked
  hotkeyManager.onEscape = onCloseClicked

  hotkeyManager.hotkeyProfile.onOptionChange = loadHotkeyProfile
  hotkeyManager.hotkeyProfile:addOption("Chat Off", "chatDisabled")
  hotkeyManager.hotkeyProfile:addOption("Chat On", "chatEnabled")

  hotkeyManager.actionProfile.onOptionChange = loadActionsProfile
  hotkeyManager.actionProfile:addOption("Movements", "movementProfile")
  hotkeyManager.actionProfile:addOption("Pokemon", "pokemonProfile")
  hotkeyManager.actionProfile:addOption("Pokébar", "pokebarProfile")
  hotkeyManager.actionProfile:addOption("Action Bar", "actionProfile")
  hotkeyManager.actionProfile:addOption("Player Actions", "playerActionsProfile")
  hotkeyManager.actionProfile:addOption("Top Menu", "topMenuProfile")
  hotkeyManager.actionProfile:addOption("General Windows", "generalWindowsProfile")
  hotkeyManager.actionProfile:addOption("Others", "othersProfile")

  hotkeyWindow = g_ui.loadUI('hotkey', g_ui.getRootWidget())
  hotkeyWindow:hide()

  connect(g_game, { onGameStart = bindAllHotkeys })
  bindAllHotkeys()
end

function getProfileSettingsKey(index)
  return "hotkeyProfile_" .. index
end

function terminate()
  -- Don't auto-save hotkey config on shutdown: it would silently override an
  -- intentional Discard. Explicit save flows (Save button, doSaveProfile,
  -- resetProfileSettings) already persist when the user wants it.
  saveProfileNames()

  disconnect(g_game, { onGameStart = bindAllHotkeys })

  unbindAllHotkeys()

  releaseHotkeyState()
  closeRenameWindow()

  if confirmBox then
    confirmBox:destroy()
    confirmBox = nil
  end

  hotkeyManager:destroy()
end

function toggle()
  if hotkeyManager:isVisible() then
    onCloseClicked()
  else
    hotkeyManager:show()
    hotkeyManager:raise()
    hotkeyManager:focus()
    setupHotkeyState()
  end
end

function show(actionProfile, actionName)
  hotkeyManager:show()
  hotkeyManager:raise()
  hotkeyManager:focus()
  setupHotkeyState()

  hotkeyManager.actionProfile:setCurrentOptionByData(actionProfile)

  if actionName then
    local actionWidget = hotkeyManager.actionsPanel[actionName]
    actionWidget:focus()
    local index = hotkeyManager.actionsPanel:getChildIndex(actionWidget)
    hotkeyManager.actionsPanel:moveChildToIndex(actionWidget, index)
    hotkeyManager.actionsPanel:ensureChildVisible(actionWidget)
  end
end

function markDirty()
  profilesDirty[currentProfileIndex] = true
end

function isCurrentDirty()
  return profilesDirty[currentProfileIndex] == true
end

function clearDirty()
  profilesDirty[currentProfileIndex] = false
end

function saveProfileNames()
  local names = {}
  local options = hotkeyManager.profileSelector.options
  for i = 1, MAX_PROFILES do
    if options[i] then
      names[tostring(i)] = options[i].text
    end
  end
  g_settings.setNode('hotkeyProfileNames', names)
end

function onRenameClicked()
  if renameWindow then return end

  local currentName = hotkeyManager.profileSelector:getCurrentOption().text

  renameWindow = g_ui.loadUI('hotkey_rename', g_ui.getRootWidget())
  renameWindow.nameEdit:setText(currentName)
  renameWindow.nameEdit:focus()

  g_uistates.push(renameWindow)

  renameWindow.confirmButton.onClick = function()
    local newName = renameWindow.nameEdit:getText()
    if newName and newName ~= "" then
      hotkeyManager.profileSelector:updateCurrentOption(newName)
    end
    closeRenameWindow()
  end

  renameWindow.cancelButton.onClick = function()
    closeRenameWindow()
  end

  renameWindow.onKeyDown = function(self, keyCode, keyboardModifiers)
    local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers)
    if keyCombo == "Return" or keyCombo == "Enter" then
      renameWindow.confirmButton.onClick()
      return true
    elseif keyCombo == "Escape" then
      closeRenameWindow()
      return true
    end
    return false
  end

  renameWindow:show()
  renameWindow:raise()
  renameWindow.nameEdit:focus()
  renameWindow.nameEdit:setCursorPos(-1)
end

function closeRenameWindow()
  if renameWindow then
    g_uistates.remove(renameWindow)
    renameWindow:destroy()
    renameWindow = nil
  end
end

function setupHotkeyState()
  if not hotkeyState then
    hotkeyState = UIState.create()
    hotkeyStateIndex = hotkeyState:new(function(released)
      if released then
        if hotkeyManager and not hotkeyManager:isDestroyed() then
          g_uistates.remove(hotkeyManager)
        end
      else
        if hotkeyManager and not hotkeyManager:isDestroyed() then
          g_uistates.push(hotkeyManager)
        end
      end
    end)
    hotkeyState:gotoState(0)
  end
  hotkeyState:gotoState(hotkeyStateIndex)
end

function releaseHotkeyState()
  if hotkeyState and hotkeyStateIndex then
    hotkeyState:gotoState(0)
  end
end

function onCloseClicked()
  if isCurrentDirty() then
    askSaveBeforeAction(function()
      saveProfileNames()
      releaseHotkeyState()
      hotkeyManager:hide()
    end)
  else
    saveProfileNames()
    releaseHotkeyState()
    hotkeyManager:hide()
  end
end

function doSaveProfile()
  saveHotkeysConfig(hotkeyProfile)
  saveProfileNames()
  clearDirty()
end

function discardChanges()
  unbindAllHotkeys()
  hotkeyProfile = HotkeyProfiles:new(getProfileSettingsKey(currentProfileIndex))
  initProfile(hotkeyProfile)
  bindAllHotkeys()
  clearDirty()

  if hotkeyManager and hotkeyManager.actionProfile then
    local currentOption = hotkeyManager.actionProfile:getCurrentOption()
    if currentOption then
      loadActionsProfile(hotkeyManager.actionProfile, currentOption, currentOption.data)
    end
  end
end

function askSaveBeforeAction(callback)
  if confirmBox then
    confirmBox:destroy()
    confirmBox = nil
  end

  confirmBox = displayAllianceBox(tr('Save Changes'), tr('You have unsaved changes. Do you want to save before continuing?'), {
    anchor = AnchorHorizontalCenter,
    { text = tr('Save'), callback = function()
      doSaveProfile()
      confirmBox:destroy()
      confirmBox = nil
      if callback then callback() end
    end },
    { text = tr('Discard'), callback = function()
      discardChanges()
      confirmBox:destroy()
      confirmBox = nil
      if callback then callback() end
    end },
    { text = tr('Cancel'), callback = function()
      confirmBox:destroy()
      confirmBox = nil
    end }
  })
end

function switchToProfile(newIndex)
  unbindAllHotkeys()

  currentProfileIndex = newIndex
  hotkeyProfile = HotkeyProfiles:new(getProfileSettingsKey(newIndex))
  initProfile(hotkeyProfile)

  bindAllHotkeys()

  hotkeyManager.actionProfile:setCurrentIndex(1)
end

function onProfileSelectorChanged(widget, option, data)
  local newIndex = data

  if newIndex == currentProfileIndex then
    return
  end

  if isCurrentDirty() then
    askSaveBeforeAction(function()
      switchToProfile(newIndex)
    end)
  else
    switchToProfile(newIndex)
  end
end

function saveProfileSettings()
  if confirmBox then confirmBox:destroy() confirmBox = nil end
  confirmBox = displayAllianceBox(tr('Save Profile'), tr('Are you sure you want to save this profile?'), {
    anchor = AnchorHorizontalCenter,
    { text = tr('Yes'), callback = function()
      saveHotkeysConfig(hotkeyProfile)
      saveProfileNames()
      clearDirty()
      confirmBox:destroy()
      confirmBox = nil
    end },
    { text = tr('No'), callback = function()
      confirmBox:destroy()
      confirmBox = nil
    end }
  })
end

function resetProfileSettings()
  if confirmBox then confirmBox:destroy() confirmBox = nil end
  confirmBox = displayAllianceBox(tr('Reset Profile'), tr('Are you sure you want to reset this profile to default?'), {
    anchor = AnchorHorizontalCenter,
    { text = tr('Yes'), callback = function()
      unbindAllHotkeys()
      local config = g_settings.getNode('hotkeysConfigSettings') or {}
      config[hotkeyProfile.name] = nil
      g_settings.setNode('hotkeysConfigSettings', config)
      initProfile(hotkeyProfile)
      bindAllHotkeys()
      clearDirty()
      hotkeyManager.actionProfile:setCurrentIndex(1)
      confirmBox:destroy()
      confirmBox = nil
    end },
    { text = tr('No'), callback = function()
      confirmBox:destroy()
      confirmBox = nil
    end }
  })
end

function loadHotkeyProfile(widget, option, data)
  hotkeyManager.actionProfile:setCurrentIndex(1)
end

function loadActionsProfile(widget, option, actionProfileName)
  if actionProfileName == "movementProfile" then
    local orderedActions = {
      "WALK_NORTH", "WALK_EAST", "WALK_SOUTH", "WALK_WEST",
      "WALK_NORTH_WEST", "WALK_NORTH_EAST", "WALK_SOUTH_EAST", "WALK_SOUTH_WEST",
      "TURN_NORTH", "TURN_EAST", "TURN_SOUTH", "TURN_WEST",
      "TURN_POKEMON_NORTH", "TURN_POKEMON_EAST", "TURN_POKEMON_SOUTH", "TURN_POKEMON_WEST",
      "FLY_UP", "FLY_DOWN"
    }

    createActionWidgets(orderedActions)
  elseif actionProfileName == "pokemonProfile" then
    local orderedActions = {
      "ACTION_1", "ACTION_2", "ACTION_3", "ACTION_4", "ACTION_5",
      "ACTION_6", "ACTION_7", "ACTION_8", "ACTION_9", "ACTION_10",
      "ACTION_11", "ACTION_12", "OFFENSIVE_MODE", "BALANCED_MODE", "DEFENSIVE_MODE"
    }

    createActionWidgets(orderedActions)

  elseif actionProfileName == "pokebarProfile" then
    local orderedActions = {"POKEBAR_1", "POKEBAR_2", "POKEBAR_3", "POKEBAR_4", "POKEBAR_5", "POKEBAR_6", "POKEBAR_CYCLE"}
    createActionWidgets(orderedActions)
  elseif actionProfileName == "actionProfile" then
    local orderedActions = {"ACTION_BAR_ORDER", "ACTION_BAR_ORDER_SELF", "ACTION_BAR_DEX", "ACTION_BAR_AUTOCOMBO"}

    for i = 1, 50 do
      table.insert(orderedActions, "ACTION_BAR_" .. i)
    end

    createActionWidgets(orderedActions)
  elseif actionProfileName == "playerActionsProfile" then
    local orderedActions = { "FISHING_ROD", "WALK", "POKESTOP", "GATHER", "OUTFIT_ANIMATION", "OUTFIT_TAUNT", "OUTFIT_IDLE", "MEMORY_1", "MEMORY_2", "MEMORY_3", "MEMORY_4", "MEMORY_5", "MEMORY_6" }
    createActionWidgets(orderedActions)
  elseif actionProfileName == "topMenuProfile" then
    local orderedActions = {
      "LOGOUT", "SETTINGS", "POKEBAG",
      "PLAYERBAG", "MINIMAP", "FULLMAP", "VIPLIST", "BATTLELIST"
    }

    createActionWidgets(orderedActions)
  elseif actionProfileName == "generalWindowsProfile" then
    local orderedActions = { "ACHIEVEMENTS", "BROKES", "TALENTS", "MEDALS", "POKELOG", "GAME_SHOP", "LINKED_TASKS", "GUILD", "TRAINER", "REPORT_RULE_VIOLATION" }

    createActionWidgets(orderedActions)
  elseif actionProfileName == "othersProfile" then
    local orderedActions = { "SWITCH_TARGET", "SWITCH_TARGET_BACKWARD", "NEXT_CHAT", "CLOSE_CHAT", "AUTO_LOOT" }

    createActionWidgets(orderedActions)
  end
end

function createActionWidgets(orderedActions)
  hotkeyManager.actionsPanel:destroyChildren()

  local chatState = hotkeyManager.hotkeyProfile:getCurrentOption().data
  local actionProfileName = hotkeyManager.actionProfile:getCurrentOption().data

  local actionProfile = hotkeyProfile:getActionProfile(actionProfileName)

  for _, actionName in ipairs(orderedActions) do
    local actionInfo = actionProfile:getAction(actionName)

    if actionInfo then
      local actionWidget = g_ui.createWidget("ActionWidget", hotkeyManager.actionsPanel)
      actionWidget:setId(actionName)
      actionWidget.actionName:setText(actionInfo.description)

      local actionKeys = actionInfo:getKeys(chatState)

      actionWidget.primaryKey:setText(actionKeys.primaryKey.key)
      actionWidget.primaryKey.onClick = assignHotkey

      actionWidget.secondaryKey:setText(actionKeys.secondaryKey.key)
      actionWidget.secondaryKey.onClick = assignHotkey

      actionWidget.tertiaryKey:setText(actionKeys.tertiaryKey.key)
      actionWidget.tertiaryKey.onClick = assignHotkey
    end
  end
end

function assignHotkey(actionWidget)
  local chatState = hotkeyManager.hotkeyProfile:getCurrentOption().data
  local actionProfileName = hotkeyManager.actionProfile:getCurrentOption().data

  local actionProfile = hotkeyProfile:getActionProfile(actionProfileName)

  local actionName = actionWidget:getParent():getId()
  local actionInfo = actionProfile:getAction(actionName)

  local actionKeys = actionInfo:getKeys(chatState)

  local keyConfig = actionKeys[actionWidget:getId()]

  hotkeyWindow.base_name.base_text:setText('Edit Hotkey -')
  hotkeyWindow.base_name.base_action_name:setText(actionInfo.description)
  hotkeyWindow.desc:setText('Click "Ok" to assign the hotkey. Click "Clear" to remove the hotkey from "' .. actionInfo.description .. '".')
  hotkeyWindow.display:setText(keyConfig.key)
  hotkeyWindow.warning:setText("")

  local canEditKeyType = not actionInfo.lockKeyType
                         and (actionProfileName == "actionProfile" or actionInfo.editableKeyType)
  if not canEditKeyType then
    hotkeyWindow.keyBindType:disable()
    hotkeyWindow.keyBindType:hide()
    hotkeyWindow.keyBindLabel:hide()
  else
    hotkeyWindow.keyBindType:enable()
    hotkeyWindow.keyBindType:show()
    hotkeyWindow.keyBindLabel:show()
    hotkeyWindow.keyBindType:setCurrentOptionByData(keyConfig.config)
  end
  --[[if not keyConfig.config then
    hotkeyWindow.keyBindType:disable()
  else
    hotkeyWindow.buttonOk:enable()
  end]]

  hotkeyWindow.buttonClear.onClick = function()
    hotkeyWindow.display:setText("")
    hotkeyWindow.warning:setText("")
    hotkeyWindow.buttonOk:enable()
  end

  hotkeyWindow.buttonClose.onClick = function()
    hotkeyWindow.display:setText("")
    hotkeyWindow.warning:setText("")
    hotkeyWindow.buttonOk:enable()
    g_uistates.remove(hotkeyWindow)
    hotkeyWindow:hide()
  end

  hotkeyWindow.onKeyDown = function(hotkeyWindow, keyCode, keyboardModifiers)
    if keyCode == KeyEscape then
      hotkeyWindow.buttonClose:onClick()
      return true
    end

    local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers)
    local existingProfile = isKeyAlreadyBound(hotkeyProfile, keyCombo, chatState)

    if existingProfile and keyCombo ~= keyConfig.key then
      hotkeyWindow.warning:setText("The key " .. keyCombo .. " is already being used for " .. existingProfile.action.description .. ". Do you want to overwrite it?")
    else
      hotkeyWindow.warning:setText("")
    end

    hotkeyWindow.display:setText(keyCombo)
    return true
  end

  hotkeyWindow.buttonOk.onClick = function()
    local keyCombo = hotkeyWindow.display:getText()

    HotkeyRegistry:unbindAction(actionProfile, actionName, actionInfo)

    -- Only resolve a conflict if the key actually changed: isKeyAlreadyBound
    -- matches by value and cannot tell the edited action apart from another
    -- holder of the same key, so without this a no-op Ok wipes the other one.
    if keyCombo ~= "" and keyCombo ~= keyConfig.key then
      local existingProfile = isKeyAlreadyBound(hotkeyProfile, keyCombo, chatState)

      if existingProfile then
        local oldActionProfile = hotkeyProfile.actionProfiles[existingProfile.actionProfileName]
        -- unbindAction removes ALL chatStates/keyTypes for the conflicting action.
        -- We only want to clear the one keyConfig that conflicts, so after clearing
        -- it we must rebind the action to restore the remaining (non-conflicting) keys.
        HotkeyRegistry:unbindAction(oldActionProfile, existingProfile.actionName, existingProfile.action)

        existingProfile.keyConfig.key = ""

        local oldActionWidget = hotkeyManager.actionsPanel:getChildById(existingProfile.actionName)
        if oldActionWidget then
          oldActionWidget[existingProfile.keyConfig.name]:setText("")
        end

        HotkeyRegistry:bindAction(oldActionProfile, existingProfile.actionName, existingProfile.action)
      end
    end

    keyConfig.key = keyCombo
    if canEditKeyType then
      keyConfig.config = hotkeyWindow.keyBindType:getCurrentOption().data
    end
    -- Locked / non-editable actions keep their existing default bind type: the
    -- selector is hidden, so reading it would return its first option and clobber
    -- the per-category default (interface = KeyDown, actions = KeyPress).

    actionWidget:setText(keyConfig.key)
    HotkeyRegistry:bindAction(actionProfile, actionName, actionInfo)

    markDirty()
    g_uistates.remove(hotkeyWindow)
    hotkeyWindow:hide()
  end


  hotkeyWindow:show()
  hotkeyWindow:raise()
  hotkeyWindow:focus()
  g_uistates.push(hotkeyWindow)
end

-- Conflict detection is intentionally per-chatState: the same key can legitimately
-- map to different actions in chatEnabled vs chatDisabled (callbacks gate themselves
-- via isChatStateCorrect), so we don't flag cross-state collisions as conflicts.
function isKeyAlreadyBound(hotkeyProfile, keyCombo, chatState)
  for actionProfileName, actionProfile in pairs(hotkeyProfile.actionProfiles) do
    for actionName, action in pairs(actionProfile.actions) do
      local actionKeys = action:getKeys(chatState)

      if tostring(actionKeys.primaryKey.key) == keyCombo then
        return {actionProfileName = actionProfileName, actionName = actionName, action = action, keyConfig = actionKeys.primaryKey}
      elseif tostring(actionKeys.secondaryKey.key) == keyCombo then
        return {actionProfileName = actionProfileName, actionName = actionName, action = action, keyConfig = actionKeys.secondaryKey}
      elseif tostring(actionKeys.tertiaryKey.key) == keyCombo then
        return {actionProfileName = actionProfileName, actionName = actionName, action = action, keyConfig = actionKeys.tertiaryKey}
      end
    end
  end

  return false
end

function bindAllHotkeys()
  HotkeyRegistry:bindAll(hotkeyProfile)
end

function unbindAllHotkeys()
  HotkeyRegistry:unbindAll()
end
