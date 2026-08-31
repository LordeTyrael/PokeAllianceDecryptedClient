DefaultActions = {}
DefaultAssignCallbacks = {}
DefaultBindModes = {}

function registerHotkeyCallback(actionName, callbackFactory, assignCallback, bindMode)
  if not actionName or type(callbackFactory) ~= "function" then
    return
  end
  DefaultActions[actionName] = callbackFactory
  if assignCallback then
    DefaultAssignCallbacks[actionName] = assignCallback
  end
  if bindMode then
    DefaultBindModes[actionName] = bindMode
  end
end
