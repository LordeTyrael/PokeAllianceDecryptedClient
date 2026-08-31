-- @docclass
UIAllianceSpinBox = extends(UITextEdit, "UIAllianceSpinBox")

function UIAllianceSpinBox.create()
  local spinbox = UIAllianceSpinBox.internalCreate()
  spinbox:setFocusable(false)
  spinbox:setValidCharacters('0123456789')
  spinbox.displayButtons = true
  spinbox.minimum = 0
  spinbox.maximum = 1
  spinbox.value = 0
  spinbox.step = 1
  spinbox.mouseScroll = true
  spinbox:setValue(1)
  return spinbox
end

function UIAllianceSpinBox:onSetup()
  local upButton = self:getStepButton('up')
  local downButton = self:getStepButton('down')
  if upButton then
    g_mouse.bindAutoPress(upButton, function() self:up() end, 300)
  end
  if downButton then
    g_mouse.bindAutoPress(downButton, function() self:down() end, 300)
  end
end

-- the steppers live inside the field (AllianceSpinBox) or beside it (AllianceAmountSpinner row)
function UIAllianceSpinBox:getStepButton(id)
  local button = self:getChildById(id)
  if button then
    return button
  end
  local parent = self:getParent()
  return parent and parent:getChildById(id)
end

function UIAllianceSpinBox:onMouseWheel(mousePos, direction)
  if not self.mouseScroll or self.disableScroll then
    return false
  end
  if direction == MouseWheelUp then
    self:up()
  elseif direction == MouseWheelDown then
    self:down()
  end
  return true
end

function UIAllianceSpinBox:onKeyPress(keyCode, keyboardModifiers, autoRepeatTicks)
  if keyboardModifiers ~= KeyboardNoModifier and keyboardModifiers ~= KeyboardShiftModifier then
    return false
  end

  if keyCode == KeyUp then
    self:up()
  elseif keyCode == KeyDown then
    self:down()
  elseif keyCode == KeyPageUp then
    self:setValue(self.value + self.step * 10)
  elseif keyCode == KeyPageDown then
    self:setValue(self.value - self.step * 10)
  else
    return false
  end
  return true
end

function UIAllianceSpinBox:onTextChange(text, oldText)
  if text:len() == 0 then
    self:setValue(self.minimum, true)
    return
  end

  local number = tonumber(text)
  if not number then
    self:setText(oldText)
    return
  end

  if number > self.maximum then
    self:setText(self.maximum)
    return
  end

  -- below-minimum text stays while typing; the value is clamped and the text
  -- normalizes on focus loss
  self:setValue(number, true)
end

function UIAllianceSpinBox:onValueChange(value)
  -- nothing to do
end

function UIAllianceSpinBox:onFocusChange(focused)
  if focused then
    -- key events walk down the focus chain and stop at the first unfocused link, so every
    -- container between the keyboard receiver and this field has to be focused too
    local parent = self:getParent()
    while parent and parent:isFocusable() and not parent:isFocused() do
      parent:focus()
      parent = parent:getParent()
    end
    self:selectAll()
  elseif self:getText() ~= tostring(self.value) then
    self:setText(self.value)
  end
end

function UIAllianceSpinBox:onStyleApply(styleName, styleNode)
  for name, value in pairs(styleNode) do
    if name == 'maximum' then
      self.maximum = value
      addEvent(function() self:setMaximum(value) end)
    elseif name == 'minimum' then
      self.minimum = value
      addEvent(function() self:setMinimum(value) end)
    elseif name == 'mouse-scroll' then
      addEvent(function() self:setMouseScroll(value) end)
    elseif name == 'buttons' then
      addEvent(function()
        if value then
          self:showButtons()
        else
          self:hideButtons()
        end
      end)
    end
  end
end

function UIAllianceSpinBox:showButtons()
  self:getChildById('up'):show()
  self:getChildById('down'):show()
  self.displayButtons = true
end

function UIAllianceSpinBox:hideButtons()
  self:getChildById('up'):hide()
  self:getChildById('down'):hide()
  self.displayButtons = false
end

function UIAllianceSpinBox:up()
  self:setValue(self.value + self:effectiveStep())
end

function UIAllianceSpinBox:down()
  self:setValue(self.value - self:effectiveStep())
end

function UIAllianceSpinBox:effectiveStep()
  return g_keyboard.isShiftPressed() and self.step * 10 or self.step
end

function UIAllianceSpinBox:setValue(value, fromTextEdit)
  if type(value) == "string" then
    value = tonumber(value)
  end
  value = value or 0
  value = math.max(math.min(self.maximum, value), self.minimum)

  if not fromTextEdit and self:getText() ~= tostring(value) then
    self:setText(tostring(value))
  end

  local changed = value ~= self.value
  self.value = value
  self:updateButtons()

  if changed then
    signalcall(self.onValueChange, self, value)
  end
end

function UIAllianceSpinBox:updateButtons()
  local upButton = self:getStepButton('up')
  local downButton = self:getStepButton('down')
  if upButton then
    upButton:setEnabled(self.maximum ~= self.minimum and self.value ~= self.maximum)
  end
  if downButton then
    downButton:setEnabled(self.maximum ~= self.minimum and self.value ~= self.minimum)
  end
end

function UIAllianceSpinBox:getValue()
  return self.value
end

function UIAllianceSpinBox:setMinimum(minimum)
  minimum = minimum or -9223372036854775808
  self.minimum = minimum
  if self.minimum > self.maximum then
    self.maximum = self.minimum
  end
  if self.value < minimum then
    self:setValue(minimum)
  else
    self:updateButtons()
  end
end

function UIAllianceSpinBox:getMinimum()
  return self.minimum
end

function UIAllianceSpinBox:setMaximum(maximum)
  maximum = maximum or 9223372036854775807
  self.maximum = maximum
  if self.value > maximum then
    self:setValue(maximum)
  else
    self:updateButtons()
  end
end

function UIAllianceSpinBox:getMaximum()
  return self.maximum
end

function UIAllianceSpinBox:setStep(step)
  self.step = step or 1
end

function UIAllianceSpinBox:setMouseScroll(mouseScroll)
  self.mouseScroll = mouseScroll
end

function UIAllianceSpinBox:getMouseScroll()
  return self.mouseScroll
end
