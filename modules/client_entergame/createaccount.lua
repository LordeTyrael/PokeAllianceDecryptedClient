CreateAccount = { }

local createAccountWindow

function CreateAccount.init()
  createAccountWindow = g_ui.displayUI('createaccount')
  CreateAccount.hide()
end

function CreateAccount.terminate()
  createAccountWindow:destroy()
  createAccountWindow = nil
end

function CreateAccount.show()
  createAccountWindow:show()
  createAccountWindow:raise()
  createAccountWindow:focus()
  createAccountWindow:getChildById('accountNameTextEdit'):focus()
end

function CreateAccount.doOpenEnterGameWindow()
  CreateAccount.hide()
  EnterGame.show()
end

local function onHTTPResult(data, err)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  if data.errorCode then  
    local errorBox = displayAllianceErrorBox(tr('Create Account Error'), data.errorMessage)
    connect(errorBox, { onOk = CreateAccount.show })
    return
  end

  createAccountSuccessWindow = displayAllianceInfoBox(tr('Create Account'), data.message)
  createAccountSuccessWindow.onOk = {
    function()
      createAccountSuccessWindow = nil
      CreateAccount.hide()
      EnterGame.show()
    end
  }
  
end

function CreateAccount.doCreateAccount()
  local createAccountName = createAccountWindow:getChildById('accountNameTextEdit'):getText()
  local createEmail = createAccountWindow:getChildById('emailTextEdit'):getText()
  local createPassword = createAccountWindow:getChildById('passwordTextEdit'):getText()
  local createPasswordConfirmation = createAccountWindow:getChildById('passwordConfirmationTextEdit'):getText()
  local referralCode = createAccountWindow.referralCodeTextEdit:getText()
  local host = g_game.getServerHost()
  local port = g_game.getCreateAccountPort()
  clientVersion = g_game.getProtocolVersion()

  if createPassword ~= createPasswordConfirmation then
    displayAllianceErrorBox(tr('Create Account Error'), tr('The passwords do not match.'))
    return
  end
  CreateAccount.hide()

  if g_game.isOnline() then
    local errorBox = displayAllianceErrorBox(tr('Create Account Error'), tr('Cannot create account while already in game.'))
    connect(errorBox, { onOk = CreateAccount.show() })
    return
  end

  loadBox = displayAllianceCancelBox(tr('Please wait'), tr('Connecting to create account server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  CreateAccount.show()
                                end})

  local data = {
    Name = createAccountName,
    Email = createEmail,
    Password = createPassword,
  }

  HTTP.postJSON(Services.clientServices.."/create-account", data, onHTTPResult)
end

function CreateAccount.hide()
  createAccountWindow:hide()
end