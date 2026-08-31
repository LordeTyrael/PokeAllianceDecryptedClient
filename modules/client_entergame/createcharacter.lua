CreateCharacter = {}
local config = {
  ["Male"] = 0,
  ["Female"] = 1.
}
local createCharacterWindow
local loadBox
local selectedGender = 'Male'
local creationWorldInfo = {}
local noCharactersMode = false

function CreateCharacter.setNoCharactersMode(value)
  noCharactersMode = value
end

local function onWorldChange(comboBox, text, data)
  local info = creationWorldInfo[data]
  if not info then return end
  comboBox:setText(info.name)
  local preRegistration = info.preRegistration == true
  local tagChip = comboBox:getChildById('tagChip')
  tagChip:setText(tr('PRE-REGISTRATION'))
  tagChip:setVisible(preRegistration)
  -- a world still in pre-registration has no server up, so it gets no online dot
  comboBox:getChildById('onlineDot'):setVisible(not preRegistration)
  comboBox:setTooltip(info.launchAt and tr('Launch at %s', info.launchAt) or nil)
end

local function onError(protocol, message, errorCode)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  local errorBox = displayAllianceErrorBox(tr('Create Character Error'), message)
  connect(errorBox, { onOk = CreateCharacter.show })
end

local function onSuccess(message)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  createCharacterSuccessWindow = displayAllianceInfoBox(tr('Create Character'), message)
  createCharacterSuccessWindow.onOk = {
    function()
      createCharacterSuccessWindow = nil
      CreateCharacter.hide()
      EnterGame.doLoginAgain()
    end
  }
end

function CreateCharacter.init()
  createCharacterWindow = g_ui.displayUI('createcharacter')
  CreateCharacter.hide()
end

function CreateCharacter.terminate()
  createCharacterWindow:destroy()
  createCharacterWindow = nil
  loadBox = nil
end

function CreateCharacter.selectGender(gender)
  selectedGender = gender
  createCharacterWindow:getChildById('maleSegment'):setOn(gender == 'Male')
  createCharacterWindow:getChildById('femaleSegment'):setOn(gender == 'Female')
end

function CreateCharacter.show()
  createCharacterWindow:show()
  CreateCharacter.selectGender(selectedGender)
  local comboBox = createCharacterWindow.worlds
  if comboBox then
    -- show() also runs on the way back from a failed creation (name already taken), so the world
    -- the player picked is carried over instead of snapping back to the default. Read before
    -- clear(), which resets currentIndex.
    local currentOption = comboBox:getCurrentOption()
    local keepWorldId = currentOption and currentOption.data
    comboBox.onOptionChange = onWorldChange
    comboBox:clear()
    creationWorldInfo = {}
    local worlds = modules.client_entergame.getCreationWorlds()
    local defaultWorldId
    if worlds then
      for _, worldConfig in pairs(worlds) do
        creationWorldInfo[worldConfig.id] = worldConfig
        local optionText = worldConfig.name
        if worldConfig.preRegistration then
          optionText = worldConfig.name .. '  ·  ' .. tr('PRE-REGISTRATION')
        end
        comboBox:addOption(optionText, worldConfig.id)
        if worldConfig.default then
          defaultWorldId = worldConfig.id
        end
      end
    end
    if keepWorldId and creationWorldInfo[keepWorldId] then
      comboBox:setCurrentOptionByData(keepWorldId)
    elseif defaultWorldId then
      comboBox:setCurrentOptionByData(defaultWorldId)
    end
    if comboBox:getOptionsCount() == 0 then
      comboBox:setText(tr('No worlds available'))
      comboBox:setEnabled(false)
      comboBox:getChildById('tagChip'):setVisible(false)
    else
      comboBox:setEnabled(true)
    end
  end
  createCharacterWindow:raise()
  createCharacterWindow:focus()
  createCharacterWindow:getChildById('characterNameTextEdit'):focus()
end

function CreateCharacter.doOpenCharacterList()
  CreateCharacter.hide()
  if noCharactersMode then
    -- Reached creation because the account has no characters; backing out here
    -- means "cancel": log the account out and return to the enter-game screen.
    noCharactersMode = false
    CharacterList.logoutToEnterGame()
  else
    CharacterList.show()
  end
end

local function onHTTPResult(data, err)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  if data.errorCode then  
    local errorBox = displayAllianceErrorBox(tr('Create Character Error'), data.errorMessage)
    connect(errorBox, { onOk = CreateCharacter.show })
    return
  end

  local createCharacterSuccessWindow = displayAllianceInfoBox(tr('Create Character'), data.message)
  createCharacterSuccessWindow.onOk = {
    function()
      createCharacterSuccessWindow = nil
      CreateCharacter.hide()
      EnterGame.doLoginAgain()
    end
  }
  
end

function CreateCharacter.doCreateCharacter()
  characterName = createCharacterWindow:getChildById('characterNameTextEdit'):getText()
  CreateCharacter.hide()
  local host = g_game.getServerHost()
  local port = g_game.getCreateCharacterPort()
  local clientVersion = g_game.getProtocolVersion()
  local characterSex = selectedGender
  local world = createCharacterWindow:getChildById('worlds'):getCurrentOption()

  local characterSexId = config[characterSex]
  if not characterSexId then
    characterSexId = 0
  end
  CreateAccount.hide()

  if g_game.isOnline() then
    local errorBox = displayAllianceErrorBox(tr('Create Character Error'), tr('Cannot create character while already in game.'))
    connect(errorBox, { onOk = CreateCharacter.show() })
    return
  end

  if not world or not world.data then
    local errorBox = displayAllianceErrorBox(tr('Create Character Error'), tr('No world available for character creation.'))
    connect(errorBox, { onOk = CreateCharacter.show })
    return
  end

  loadBox = displayAllianceCancelBox(tr('Please wait'), tr('Connecting to create characterServer'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  CreateCharacter.show()
                                end})

  local data = {
    AccountName = G.account,
    Password = G.password,
    Name = characterName,
    World = world.data,
    Sex = characterSexId,
  }
  HTTP.postJSON(Services.clientServices.."/create-player", data, onHTTPResult)
end

function CreateCharacter.doCloseChangePassword()
  local widget = ChangePassword.getWidget()
  if widget then
    widget:hide()
    CharacterList.show()
  end
end

function CreateCharacter.doCloseChangeEmail()
  local widget = ChangeEmail.getWidget()
  if widget then
    widget:hide()
    CharacterList.show()
  end
end

local function onPasswordHTTPResult(data, err)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  if data.errorCode then  
    local errorBox = displayAllianceErrorBox(tr('Change Password Error'), data.errorMessage)
    connect(errorBox, { onOk = CharacterList.showChangePassword })
    return
  end

  local createCharacterSuccessWindow = displayAllianceInfoBox(tr('Change Password'), data.message)
  createCharacterSuccessWindow.onOk = {
    function()
      createCharacterSuccessWindow = nil
      CreateCharacter.hide()
      EnterGame.doLoginAgain()
    end
  }
  
end

function CreateCharacter.doChangePassword()
  local widget = ChangePassword.getWidget()
  if not widget then
    local errorBox = displayAllianceErrorBox(tr('Create Character Error'), tr('Error, please reopen Client.'))
    connect(errorBox, { onOk = CreateCharacter.show() })
    return
  end

  ChangePassword.hideChangePasswordWindow()
  if g_game.isOnline() then
    local errorBox = displayAllianceErrorBox(tr('Create Character Error'), tr('Cannot change password while already in game.'))
    connect(errorBox, { onOk = CreateCharacter.show() })
    return
  end

  loadBox = displayAllianceCancelBox(tr('Please wait'), tr('Connecting to GameServer'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  CharacterList.show()
                                end})
  local password = widget.passwordTextEdit:getText()
  local newPassword = widget.newPasswordEdit:getText()
  local confirmPassword = widget.confirmPasswordTextEdit:getText()

  local data = {
    name = G.account,
    password = password,
    newpassword = newPassword,
    newpassword_confirm = confirmPassword,
  }

  HTTP.postJSON(Services.clientServices.."/change-password", data, onPasswordHTTPResult)
end

local function onEmailHTTPResult(data, err)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  if data.errorCode then  
    local errorBox = displayAllianceErrorBox(tr('Change Email Error'), data.errorMessage)
    connect(errorBox, { onOk = CharacterList.showChangeEmail })
    return
  end

  local createCharacterSuccessWindow = displayAllianceInfoBox(tr('Change Email'), data.message)
  createCharacterSuccessWindow.onOk = {
    function()
      createCharacterSuccessWindow = nil
      CreateCharacter.hide()
      EnterGame.doLoginAgain()
    end
  }
  
end

function CreateCharacter.doChangeEmail()
  local widget = ChangeEmail.getWidget()
  if not widget then
    local errorBox = displayAllianceErrorBox(tr('Change Email Error'), tr('Error, please reopen Client.'))
    connect(errorBox, { onOk = CreateCharacter.show() })
    return
  end

  ChangeEmail.hideChangeEmailWindow()
  if g_game.isOnline() then
    local errorBox = displayAllianceErrorBox(tr('Change Email Error'), tr('Cannot change email while already in game.'))
    connect(errorBox, { onOk = CreateCharacter.show() })
    return
  end

  loadBox = displayAllianceCancelBox(tr('Please wait'), tr('Connecting to GameServer'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  CharacterList.show()
                                end})

  local password = widget.passwordTextEdit:getText() or ""
  local newEmail = widget.newEmailEdit:getText() or ""
  local confirmNewEmail = widget.confirmEmailTextEdit:getText() or ""
  local recoveryKey = widget.recoveryKeyTextEdit:getText() or ""
  local data = {
    name = G.account,
    password = password,
    newemail = newEmail,
    newemail_confirm = confirmNewEmail,
    recovery_key = recoveryKey
  }

  HTTP.postJSON(Services.clientServices.."/change-email", data, onEmailHTTPResult)
end

function CreateCharacter.hide(showCharacterList)
  if not createCharacterWindow then return end
  showCharacterList = showCharacterList or false

  createCharacterWindow:hide()

  if showCharacterList and CharacterList then
    CharacterList.show()
  end
end