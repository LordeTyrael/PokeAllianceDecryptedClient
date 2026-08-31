-- @docclass
UIMiniWindow = extends(UIWindow, "UIMiniWindow")

function UIMiniWindow.create()
  local miniwindow = UIMiniWindow.internalCreate()
  miniwindow.UIMiniWindowContainer = true
  return miniwindow
end

function UIMiniWindow:open(dontSave)
  self:setVisible(true)

  if not dontSave then
    self:setSettings({closed = false})
  end

  signalcall(self.onOpen, self)
end

function UIMiniWindow:close(dontSave)
  if not self:isExplicitlyVisible() then return end
  if self.forceOpen then return end
  self:setVisible(false)

  if not dontSave then
    self:setSettings({closed = true})
  end

  signalcall(self.onClose, self)
end

function UIMiniWindow:minimize(dontSave)
  self:setOn(true)
  local background = self:getChildById('miniwindowBackground')
  if background then
    background:hide()
  end
  self:getChildById('contentsPanel'):hide()
  local scrollBar = self:getChildById('miniwindowScrollBar')
  if scrollBar then
    scrollBar:hide()
  end
  local resizeBorder = self:getChildById('bottomResizeBorder')
  if resizeBorder then
    resizeBorder:hide()
  end
  if self.minimizeButton then
    self.minimizeButton:setOn(true)
  end
  self.maximizedHeight = self:getHeight()
  self:setHeight(self.minimizedHeight)

  if not dontSave then
    -- persist maximizedHeight too: it is a runtime-only field lost on relog, so without it the window reopens minimized and maximizes to the wrong (default) height
    self:setSettings({minimized = true, height = self.maximizedHeight})
  end

  signalcall(self.onMinimize, self)
end

function UIMiniWindow:maximize(dontSave)
  self:setOn(false)
  local background = self:getChildById('miniwindowBackground')
  if background then
    background:show()
  end
  self:getChildById('contentsPanel'):show()
  local scrollBar = self:getChildById('miniwindowScrollBar')
  if scrollBar then
    scrollBar:show()
  end
  local resizeBorder = self:getChildById('bottomResizeBorder')
  if resizeBorder then
    resizeBorder:show()
  end
  if self.minimizeButton then
    self.minimizeButton:setOn(false)
  end
  self:setHeight(self:getSettings('height') or self.maximizedHeight)

  if not dontSave then
    self:setSettings({minimized = false})
  end

  local parent = self:getParent()
  if parent and parent:getClassName() == 'UIMiniWindowContainer' then
    parent:fitAll(self)
  end

  signalcall(self.onMaximize, self)
end

function UIMiniWindow:lock(dontSave)
  local lockButton = self:getChildById('lockButton')
  if lockButton then
    lockButton:setOn(true)
  end
  self:setDraggable(false)
  if not dontsave then
    self:setSettings({locked = true})
  end

  signalcall(self.onLockChange, self)
end

function UIMiniWindow:unlock(dontSave)
  local lockButton = self:getChildById('lockButton')
  if lockButton then
    lockButton:setOn(false)
  end
  self:setDraggable(true)
  if not dontsave then
    self:setSettings({locked = false})
  end
  signalcall(self.onLockChange, self)
end

function UIMiniWindow:setupButtons()
  local closeButton = self:getChildById('closeButton')
  if closeButton then
    closeButton.onClick =
      function()
        self:close()
      end
    if self.forceOpen then
        if self.closeButton then
          self.closeButton:hide()
        end
    end
  end

  if(self.minimizeButton) then
    self.minimizeButton.onClick =
      function()
        if self:isOn() then
          self:maximize()
        else
          self:minimize()
        end
      end
  end
  
  local lockButton = self:getChildById('lockButton')
  if lockButton then
    lockButton.onClick = 
      function ()
        if self:isDraggable() then
          self:lock()
        else
          self:unlock()
        end
      end
  end

  local miniwindowTopBar = self:getChildById('miniwindowTopBar')
  if miniwindowTopBar then
    miniwindowTopBar.onDoubleClick =
      function()
        if self:isOn() then
          self:maximize()
        else
          self:minimize()
        end
      end
  end
  local bottomResizeBorder = self:getChildById('bottomResizeBorder')
  if bottomResizeBorder then
    bottomResizeBorder.onDoubleClick = function()
      local resizeBorder = self:getChildById('bottomResizeBorder')
      self:setHeight(resizeBorder:getMinimum())
    end
  end

  self:wireOptionsButton()
end

function UIMiniWindow:setup(ignoreSettings)
  self.dockable = true
  local closeButton = self:getChildById('closeButton')
  if closeButton then
    closeButton.onClick =
      function()
        self:close()
      end
  end
  if self.forceOpen then
      if self.closeButton then
        self.closeButton:hide()
      end
  end

  if(self.minimizeButton) then
    self.minimizeButton.onClick =
      function()
        if self:isOn() then
          self:maximize()
        else
          self:minimize()
        end
      end
  end
  
  local lockButton = self:getChildById('lockButton')
  if lockButton then
    lockButton.onClick = 
      function ()
        if self:isDraggable() then
          self:lock()
        else
          self:unlock()
        end
      end
  end

  local miniwindowTopBar = self:getChildById('miniwindowTopBar')
  if miniwindowTopBar then
    miniwindowTopBar.onDoubleClick =
      function()
        if self:isOn() then
          self:maximize()
        else
          self:minimize()
        end
      end
  end

  local bottomResizeBorder = self:getChildById('bottomResizeBorder')
  if bottomResizeBorder then
      bottomResizeBorder.onDoubleClick = function()
      local resizeBorder = self:getChildById('bottomResizeBorder')
      self:setHeight(resizeBorder:getMinimum())
    end
  end

  if ignoreSettings then
    return true
  end

  local oldParent = self:getParent()
  local bornDocked = oldParent ~= nil and oldParent:getClassName() == 'UIMiniWindowContainer'
  local restoredDocked = false

  local settings = g_settings.getNode(self:getSettingsNode())

  if settings then
    local selfSettings = settings[self:getId()]
    if selfSettings then
      if selfSettings.dockOriginId then
        local origin = rootWidget:recursiveGetChildById(selfSettings.dockOriginId)
        if origin and origin:getClassName() == 'UIMiniWindowContainer' then
          self.dockOrigin = origin
        end
      end

      -- Altura ANTES de docar: o UIMiniWindowContainer:fitAll soma a altura dos filhos no momento da
      -- insercao e fecha os que nao couberem. Restaurando depois, varias janelas salvas pequenas
      -- entram na altura cheia, a soma estoura a coluna e as ultimas sao fechadas antes de nunca
      -- chegarem a encolher. minimize/isResizeable so mexem nos proprios filhos, nao no pai.
      if selfSettings.minimized then
        self:minimize(true)
      else
        if selfSettings.height and self:isResizeable() then
          self:setHeight(selfSettings.height)
        elseif selfSettings.height and not self:isResizeable() then
          self:eraseSettings({height = true})
        end
      end

      if selfSettings.parentId then
        local parent = rootWidget:recursiveGetChildById(selfSettings.parentId)
        if parent then
          if parent:getClassName() == 'UIMiniWindowContainer' then
            self.dockOrigin = parent
          end
          if parent:getClassName() == 'UIMiniWindowContainer' and selfSettings.index and parent:isOn() then
            self.miniIndex = selfSettings.index
            parent:scheduleInsert(self, selfSettings.index)
            restoredDocked = true
          elseif selfSettings.position then
            self:setParent(parent, true)
            self:setPosition(topoint(selfSettings.position))
          elseif parent:getClassName() == 'UIMiniWindowContainer' then
            self:setParent(parent, true)
            restoredDocked = true
          end
        end
      end

      -- Quem disparava o fitAll no restore era o setHeight acima, via onHeightChange -> fitOnParent,
      -- e ele passa self como noRemoveChild: a janela recem-restaurada fica protegida e as outras e'
      -- que cedem. Com a altura aplicada antes de docar aquele fitOnParent no-opa (o pai ainda nao e'
      -- um container), entao a passagem protegida tem de ser refeita aqui -- senao sobra so o
      -- order() agendado no fim, que protege apenas o ultimo filho.
      self:fitOnParent()

      if selfSettings.closed and not self.forceOpen and not self.containerWindow then
        self:close(true)
      end

      if selfSettings.locked then
        self:lock(true)
      end
    else 
      if not self.forceOpen and self.autoOpen ~= nil and (self.autoOpen == 0 or self.autoOpen == false) and not self.containerWindow then
        self:close(true)
      end
    end
  end

  local newParent = self:getParent()

  self.miniLoaded = true

  if self.save then
    if oldParent and oldParent:getClassName() == 'UIMiniWindowContainer' and not self.containerWindow then
      addEvent(function() oldParent:order() end)
    end
    if newParent and newParent:getClassName() == 'UIMiniWindowContainer' and newParent ~= oldParent then
      addEvent(function() newParent:order() end)
    end
  end

  -- unflagged windows float only where they were created outside a column and no dock was restored;
  -- a parked window stays dockable, and a float-layer one keeps floating however it was placed
  local savedFloating = self:getSettings('floating')
  if savedFloating ~= nil then
    self.floating = savedFloating == true
  elseif self.floating == nil then
    self.floating = not bornDocked and not restoredDocked
  else
    self.floating = self.floating == true
  end

  self:fitOnParent()
  self:wireOptionsButton()
end

-- wired here, not through DockableWindow.register, because windows whose module runs
-- setup() at load time can reach this before gamelib has defined DockableWindow
function UIMiniWindow:wireOptionsButton()
  local button = self:recursiveGetChildById('optionsButton')
  if not button then return end

  button.onClick = function()
    if not DockableWindow then return end
    local pos = button:getPosition()
    pos.y = pos.y + button:getHeight()
    DockableWindow.showMenu(self, pos)
  end
end

function UIMiniWindow:onVisibilityChange(visible)
  self:fitOnParent()
end

function UIMiniWindow:onDragEnter(mousePos)
  local parent = self:getParent()
  if not parent then return false end

  if parent:getClassName() == 'UIMiniWindowContainer' then
    self.dockOrigin = parent
    self:setSettings({dockOriginId = parent:getId()})
    local containerParent = parent:getParent():getParent()
    parent:removeChild(self)
    containerParent:addChild(self)
    parent:saveChildren()
  end

  local oldPos = self:getPosition()
  self.movingReference = { x = mousePos.x - oldPos.x, y = mousePos.y - oldPos.y }
  self:setPosition(oldPos)
  self.free = true
  return true
end

function UIMiniWindow:onDragLeave(droppedWidget, mousePos)
  if self.movedWidget then
    self.setMovedChildMargin(self.movedOldMargin or 0)
    self.movedWidget = nil
    self.setMovedChildMargin = nil
    self.movedOldMargin = nil
    self.movedIndex = nil
  end

  UIWindow:onDragLeave(self, droppedWidget, mousePos)
  self:saveParent(self:getParent())
end

function UIMiniWindow:onDragMove(mousePos, mouseMoved)
  if self.floating then
    return UIWindow.onDragMove(self, mousePos, mouseMoved)
  end
  local oldMousePosY = mousePos.y - mouseMoved.y
  local children = rootWidget:recursiveGetChildrenByMarginPos(mousePos)
  local overAnyWidget = false
  for i=1,#children do
    local child = children[i]
    if child:getParent():getClassName() == 'UIMiniWindowContainer' then
      overAnyWidget = true

      local childCenterY = child:getY() + child:getHeight() / 2
      if child == self.movedWidget and mousePos.y < childCenterY and oldMousePosY < childCenterY then
        break
      end

      if self.movedWidget then
        self.setMovedChildMargin(self.movedOldMargin or 0)
        self.setMovedChildMargin = nil
      end

      if mousePos.y < childCenterY then
        self.movedOldMargin = child:getMarginTop()
        self.setMovedChildMargin = function(v) child:setMarginTop(v) end
        self.movedIndex = 0
      else
        self.movedOldMargin = child:getMarginBottom()
        self.setMovedChildMargin = function(v) child:setMarginBottom(v) end
        self.movedIndex = 1
      end

      self.movedWidget = child
      self.setMovedChildMargin(self:getHeight())
      break
    end
  end

  if not overAnyWidget and self.movedWidget then
    self.setMovedChildMargin(self.movedOldMargin or 0)
    self.movedWidget = nil
  end

  return UIWindow.onDragMove(self, mousePos, mouseMoved)
end

function UIMiniWindow:onMousePress()
  local parent = self:getParent()
  if not parent then return false end
  if parent:getClassName() ~= 'UIMiniWindowContainer' then
    self:raise()
    return true
  end
end

function UIMiniWindow:onFocusChange(focused)
  if not focused then return end
  local parent = self:getParent()
  if parent and parent:getClassName() ~= 'UIMiniWindowContainer' then
    self:raise()
  end
end

function UIMiniWindow:onHeightChange(height)
  -- persist only a genuine user resize (UIResizeBorder sets userResizing); auto-fit and
  -- fitAll's cramped-dock shrink must not save their height or bags reopen collapsed
  if not self:isOn() and self.userResizing then
    self:setSettings({height = height})
  end
  self:fitOnParent()
end

-- every g_settings node holding mini window placement; a migration that rewrites parentId or index
-- has to cover all of them
UIMiniWindow.SETTINGS_NODES = { default = 'MiniWindows', containers = 'ContainerWindows' }

-- windows whose ids are minted at runtime must not share MiniWindows, whose key space is fixed
-- by the source tree; they set self.settingsNode to keep their own
function UIMiniWindow:getSettingsNode()
  return self.settingsNode or UIMiniWindow.SETTINGS_NODES.default
end

function UIMiniWindow:getSettings(name)
  if not self.save then return nil end
  local settings = g_settings.getNode(self:getSettingsNode())
  if settings then
    local selfSettings = settings[self:getId()]
    if selfSettings then
      return selfSettings[name]
    end
  end
  return nil
end

function UIMiniWindow:setSettings(data)
  if not self.save then return end

  local node = self:getSettingsNode()
  local settings = g_settings.getNode(node)
  if not settings then
    settings = {}
  end

  local id = self:getId()
  if not settings[id] then
    settings[id] = {}
  end

  for key,value in pairs(data) do
    settings[id][key] = value
  end

  g_settings.setNode(node, settings)
end

function UIMiniWindow:eraseSettings(data)
  if not self.save then return end

  local node = self:getSettingsNode()
  local settings = g_settings.getNode(node)
  local id = self:getId()
  if not settings or not settings[id] then return end

  for key in pairs(data) do
    settings[id][key] = nil
  end

  g_settings.setNode(node, settings)
end

function UIMiniWindow:clearSettings()
  if not self.save then return end

  local node = self:getSettingsNode()
  local settings = g_settings.getNode(node)
  local id = self:getId()
  if not settings or settings[id] == nil then return end

  settings[id] = nil

  g_settings.setNode(node, settings)
end

function UIMiniWindow:saveParent(parent)
  local parent = self:getParent()
  if parent then
    if parent:getClassName() == 'UIMiniWindowContainer' then
      parent:saveChildren()
    else
      self:saveParentPosition(parent:getId(), self:getPosition())
    end
  end
end

function UIMiniWindow:saveParentPosition(parentId, position)
  local selfSettings = {}
  selfSettings.parentId = parentId
  selfSettings.position = pointtostring(position)
  selfSettings.floating = self.floating == true
  self:setSettings(selfSettings)
end

function UIMiniWindow:saveParentIndex(parentId, index)
  local selfSettings = {}
  selfSettings.parentId = parentId
  selfSettings.index = index
  selfSettings.floating = false
  self:setSettings(selfSettings)
  self.miniIndex = index
end

function UIMiniWindow:disableResize()
  self:getChildById('bottomResizeBorder'):disable()
end

function UIMiniWindow:enableResize()
  self:getChildById('bottomResizeBorder'):enable()
end

function UIMiniWindow:fitOnParent()
  local parent = self:getParent()
  if self:isVisible() and parent and parent:getClassName() == 'UIMiniWindowContainer' then
    parent:fitAll(self)
  end
end

function UIMiniWindow:setParent(parent, dontsave)
  UIWidget.setParent(self, parent)
  if not dontsave then
    self:saveParent(parent)
  end
  self:fitOnParent()
end

-- an instance-level onMouseRelease assignment replaces this method entirely; such handlers
-- must call DockableWindow.showMenu themselves (see modules/game_containers/containers.lua)
function UIMiniWindow:onMouseRelease(mousePos, mouseButton)
  if mouseButton ~= MouseRightButton then return false end
  if not DockableWindow or not DockableWindow.isTitleBarHit(self, mousePos) then return false end

  return DockableWindow.showMenu(self, mousePos)
end

function UIMiniWindow:isDocked()
  local parent = self:getParent()
  return parent ~= nil and parent:getClassName() == 'UIMiniWindowContainer'
end

function UIMiniWindow:isFloating()
  return self.floating == true
end

function UIMiniWindow:dockTo(container)
  if not container then return false end
  self.floating = false
  self:setSettings({floating = false})
  if self:getParent() == container then return true end
  self:setParent(container)
  return true
end

function UIMiniWindow:undockTo(floatLayer, position)
  if not floatLayer then return false end
  local oldParent = self:getParent()
  local screenPos = position or self:getPosition()
  self.floating = true
  self:setParent(floatLayer, true)
  if oldParent and oldParent:getClassName() == 'UIMiniWindowContainer' then
    oldParent:saveChildren()
  end
  if screenPos then self:setPosition(screenPos) end
  self:raise()
  self:saveParent(floatLayer)
  self:setSettings({floating = true})
  return true
end

function UIMiniWindow:setHeight(height)
  UIWidget.setHeight(self, height)
  signalcall(self.onHeightChange, self, height)
end

function UIMiniWindow:setContentHeight(height)
  local contentsPanel = self:getChildById('contentsPanel')
  local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()

  local resizeBorder = self:getChildById('bottomResizeBorder')
  resizeBorder:setParentSize(minHeight + height)
end

function UIMiniWindow:getContentHeight()
  local resizeBorder = self:getChildById('bottomResizeBorder')
  return resizeBorder:getParentSize()
end

function UIMiniWindow:setContentMinimumHeight(height)
  local contentsPanel = self:getChildById('contentsPanel')
  local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()

  local resizeBorder = self:getChildById('bottomResizeBorder')
  resizeBorder:setMinimum(minHeight + height)
end

function UIMiniWindow:setContentMaximumHeight(height)
  local contentsPanel = self:getChildById('contentsPanel')
  local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()

  local resizeBorder = self:getChildById('bottomResizeBorder')
  resizeBorder:setMaximum(minHeight + height)
end

function UIMiniWindow:getMinimumHeight()
  local resizeBorder = self:getChildById('bottomResizeBorder')
  return resizeBorder:getMinimum()
end

function UIMiniWindow:getMaximumHeight()
  local resizeBorder = self:getChildById('bottomResizeBorder')
  return resizeBorder:getMaximum()
end

function UIMiniWindow:isResizeable()
  local resizeBorder = self:getChildById('bottomResizeBorder')
  if not resizeBorder then
    return false
  end
  
  return resizeBorder:isExplicitlyVisible() and resizeBorder:isEnabled()
end
