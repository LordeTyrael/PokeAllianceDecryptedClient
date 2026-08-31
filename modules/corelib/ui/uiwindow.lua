-- @docclass
UIWindow = extends(UIWidget, "UIWindow")

function UIWindow.create()
  local window = UIWindow.internalCreate()
  window:setTextAlign(AlignTopCenter)
  window:setDraggable(true)  
  window:setAutoFocusPolicy(AutoFocusFirst)
  return window
end

function UIWindow:onKeyDown(keyCode, keyboardModifiers)
  if keyboardModifiers == KeyboardNoModifier then
    if keyCode == KeyEnter and self.onEnter then
      signalcall(self.onEnter, self)
      return true
    elseif keyCode == KeyEscape and self.onEscape then
      signalcall(self.onEscape, self)
      return true
    end
  end
end

function UIWindow:onFocusChange(focused)
  if focused then self:raise() end
end

-- Modal dialog: a click anywhere outside dismisses it (the click is swallowed, it never
-- reaches the window behind), and while it is open g_uistates holds the keyboard so the
-- player can't walk or fire hotkeys. closeFunc defaults to destroying the window.
function UIWindow:setupModal(closeFunc)
  self.modalCloseFunc = closeFunc
  self.onEscape = function(window) window:closeModal() end
  g_uistates.push(self)
  self:grabMouse()

  connect(self, {
    onMousePress = function(window, mousePos)
      if window:containsPoint(mousePos) then
        return false
      end
      window:closeModal()
      return true
    end,
    onDestroy = function(window)
      g_uistates.remove(window)
      window:ungrabMouse()
    end
  })
end

function UIWindow:closeModal()
  if self.modalCloseFunc then
    self.modalCloseFunc(self)
  else
    self:destroy()
  end
end

function UIWindow:onDragEnter(mousePos)
  if self.static then
    return false
  end
  self:breakAnchors()
  self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
  return true
end

function UIWindow:onDragLeave(droppedWidget, mousePos)
  -- TODO: auto detect and reconnect anchors
end

function UIWindow:onDragMove(mousePos, mouseMoved)
  if self.static then
    return
  end
  local pos = { x = mousePos.x - self.movingReference.x, y = mousePos.y - self.movingReference.y }
  self:setPosition(pos)
  self:bindRectToParent()
end
