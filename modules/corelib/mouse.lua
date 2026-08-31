-- @docclass
function g_mouse.bindAutoPress(widget, callback, delay, button)
  local button = button or MouseLeftButton
  connect(widget, { onMousePress = function(widget, mousePos, mouseButton)
    if mouseButton ~= button then
      return false
    end
    local startTime = g_clock.millis()
    callback(widget, mousePos, mouseButton, 0)
    periodicalEvent(function()
      callback(widget, g_window.getMousePosition(), mouseButton, g_clock.millis() - startTime)
    end, function()
      return g_mouse.isPressed(mouseButton)
    end, 30, delay)
    return true
  end })
end

function g_mouse.bindPressMove(widget, callback)
  connect(widget, { onMouseMove = function(widget, mousePos, mouseMoved)
    if widget:isPressed() then
      callback(mousePos, mouseMoved)
      return true
    end
  end })
end

function g_mouse.bindPress(widget, callback, button)
  widget[button] = function(widget, mousePos, mouseButton)
    if not button or button == mouseButton then
      callback(mousePos, mouseButton)
      return true
    end
    return false
  end

  connect(widget, { onMousePress = widget[button] })
end

function g_mouse.unbindPress(widget, button)
  if widget[button] then
    disconnect(widget, { onMousePress = widget[button] })
    widget[button] = nil
  end
end