if not UIWindow then dofile 'uiwindow' end

-- @docclass
AllianceMessageBox = extends(UIWindow, "AllianceMessageBox")

-- messagebox cannot be created from otui files
AllianceMessageBox.create = nil

function AllianceMessageBox.display(title, message, buttons, onEnterCallback, onEscapeCallback, parent)
  local messageBox = AllianceMessageBox.internalCreate()
  local createParent = parent and parent or rootWidget
  createParent:addChild(messageBox)

  messageBox:setStyle('AllianceMessageBoxWindow')
  
  local titleLabel = g_ui.createWidget('AllianceTitle', messageBox)
  titleLabel:setText(title)

  local messageLabel = g_ui.createWidget('AllianceLabel', messageBox)
  messageLabel:setText(message)

  local buttonsWidth = 0
  local buttonsHeight = 0

  local anchor = AnchorRight
  if buttons.anchor then anchor = buttons.anchor end

  local buttonHolder = g_ui.createWidget('AllianceBoxButtonHolder', messageBox)
  buttonHolder:setId('buttonHolder')
  buttonHolder:addAnchor(anchor, 'parent', anchor)

  for i=1,#buttons do
    local button = messageBox:addButton(buttons[i].text, buttons[i].callback)
    if i == 1 then
      button:setMarginLeft(0)
      button:addAnchor(AnchorBottom, 'parent', AnchorBottom)
      button:addAnchor(AnchorLeft, 'parent', AnchorLeft)
      buttonsHeight = button:getHeight()
    else
      button:addAnchor(AnchorBottom, 'prev', AnchorBottom)
      button:addAnchor(AnchorLeft, 'prev', AnchorRight)
    end
    buttonsWidth = buttonsWidth + button:getWidth() + button:getMarginLeft()
  end

  buttonHolder:setWidth(buttonsWidth)
  buttonHolder:setHeight(buttonsHeight)

  if onEnterCallback then connect(messageBox, { onEnter = onEnterCallback }) end
  if onEscapeCallback then connect(messageBox, { onEscape = onEscapeCallback }) end

  local minWidth = math.max(messageLabel:getWidth() + 40, buttonHolder:getWidth() + 40)
  if titleLabel then
    minWidth = math.max(minWidth, titleLabel:getTextSize().width + 40)
  end
  
  messageBox:setWidth(minWidth)
  messageBox:setHeight(messageLabel:getHeight() + messageBox:getPaddingTop() + messageBox:getPaddingBottom() + buttonHolder:getHeight() + buttonHolder:getMarginTop() + 80)
  return messageBox
end

function displayAllianceInfoBox(title, message)
  local messageBox
  local defaultCallback = function() messageBox:ok() end
  messageBox = AllianceMessageBox.display(title, message, {{text='Ok', callback=defaultCallback}, anchor = AnchorHorizontalCenter}, defaultCallback, defaultCallback)
  return messageBox
end

function displayAllianceErrorBox(title, message)
  local messageBox
  local defaultCallback = function() messageBox:ok() end
  messageBox = AllianceMessageBox.display(title, message, {{text='Ok', callback=defaultCallback}, anchor = AnchorHorizontalCenter}, defaultCallback, defaultCallback)
  return messageBox
end

function displayAllianceCancelBox(title, message)
  local messageBox
  local defaultCallback = function() messageBox:cancel() end
  messageBox = AllianceMessageBox.display(title, message, {{text='Cancel', callback=defaultCallback}, anchor = AnchorHorizontalCenter}, defaultCallback, defaultCallback)
  return messageBox
end

function displayAllianceBox(title, message, buttons, onEnterCallback, onEscapeCallback, parent)
  return AllianceMessageBox.display(title, message, buttons, onEnterCallback, onEscapeCallback, parent)
end

function AllianceMessageBox:addButton(text, callback)
  local buttonHolder = self:getChildById('buttonHolder')
  local button = g_ui.createWidget('AllianceStraightBlueButton', buttonHolder)
  button:setMarginLeft(25)
  button:setText(text)
  connect(button, { onClick = callback })
  return button
end

function AllianceMessageBox:ok()
  signalcall(self.onOk, self)
  self.onOk = nil
  self:destroy()
end

function AllianceMessageBox:cancel()
  signalcall(self.onCancel, self)
  self.onCancel = nil
  self:destroy()
end
