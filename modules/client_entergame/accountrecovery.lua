AccountRecovery = {}

local recoveryWindow
local loadBox

function AccountRecovery.init()
  recoveryWindow = g_ui.displayUI('accountrecovery')
  AccountRecovery.hide()
end

function AccountRecovery.terminate()
  recoveryWindow:destroy()
  recoveryWindow = nil
  loadBox = nil
end

function AccountRecovery.show()
  recoveryWindow:show()
  recoveryWindow:raise()
  recoveryWindow:focus()
  recoveryWindow:getChildById('identifierTextEdit'):focus()
end

function AccountRecovery.hide()
  recoveryWindow:hide()
end

function AccountRecovery.doOpenEnterGameWindow()
  AccountRecovery.hide()
  EnterGame.show()
end

local function onHTTPResult(data, err)
  if loadBox then
    loadBox:destroy()
    loadBox = nil
  end

  if err or not data or data.errorCode then
    local message = data and data.errorMessage or err
    local errorBox = displayAllianceErrorBox(tr('Account Recovery Error'), message)
    connect(errorBox, { onOk = AccountRecovery.show })
    return
  end

  local infoBox = displayAllianceInfoBox(tr('Account Recovery'), data.message)
  infoBox.onOk = {
    function()
      AccountRecovery.hide()
      EnterGame.show()
    end
  }
end

function AccountRecovery.doSendRecovery()
  local identifier = recoveryWindow:getChildById('identifierTextEdit'):getText()
  AccountRecovery.hide()

  loadBox = displayAllianceCancelBox(tr('Please wait'), tr('Connecting to recovery server...'))
  connect(loadBox, { onCancel = function(msgbox)
                                  loadBox = nil
                                  AccountRecovery.show()
                                end})

  HTTP.postJSON("https://pokealliance.com/client/recovery", { Name = identifier }, onHTTPResult)
end