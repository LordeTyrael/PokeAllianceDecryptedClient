DockableWindow = {}

local function getTopBar(window)
  return window and (window:getChildById('miniwindowTopBar') or window:getChildById('hudTopBar'))
end

function DockableWindow.isLiveContainer(container)
  return container ~= nil and not container:isDestroyed()
    and container:getClassName() == 'UIMiniWindowContainer'
    and modules.game_interface.isSidePanel(container)
end

function DockableWindow.isTitleBarHit(window, pos)
  local topBar = getTopBar(window)
  if not topBar or not topBar:containsPoint(pos) then return false end

  local child = window:recursiveGetChildByPos(pos, false)
  return child == nil or child == window or child == topBar or child:isPhantom()
end

function DockableWindow.dock(window)
  if not window then return end
  if window.dockAdapter then
    return window.dockAdapter.dock(window)
  end
  local origin = window.dockOrigin
  if not DockableWindow.isLiveContainer(origin) then
    origin = modules.game_interface.getRightPanel()
  end
  window:dockTo(origin)
end

function DockableWindow.undock(window)
  if not window then return end
  if window.dockAdapter then
    return window.dockAdapter.undock(window)
  end
  if window:isDocked() then
    window.dockOrigin = window:getParent()
    window:setSettings({dockOriginId = window.dockOrigin:getId()})
  end
  window:undockTo(modules.game_interface.getFloatLayer())
end

function DockableWindow.addOption(menu, window)
  if not menu or not window then return end
  if window.dockAdapter then
    if window.dockAdapter.isFloating(window) then
      menu:addOption(tr('Dock window'), function() DockableWindow.dock(window) end)
    else
      menu:addOption(tr('Undock window'), function() DockableWindow.undock(window) end)
    end
    return
  end
  if window:isFloating() then
    menu:addOption(tr('Dock window'), function() DockableWindow.dock(window) end)
  else
    menu:addOption(tr('Undock window'), function() DockableWindow.undock(window) end)
  end
end

function DockableWindow.showMenu(window, pos)
  if not window then return false end
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  if window.buildDockMenu then
    window.buildDockMenu(menu, window)
    if menu:getChildCount() > 0 then
      menu:addSeparator()
    end
  end
  DockableWindow.addOption(menu, window)
  menu:display(pos)
  return true
end

function DockableWindow.register(window, options)
  if not window or window.dockable == false then return end
  options = options or {}
  window.buildDockMenu = options.buildMenu

  local button = options.optionsButton or window:recursiveGetChildById('optionsButton')
  if not button then return end

  button.onClick = function()
    local pos = button:getPosition()
    pos.y = pos.y + button:getHeight()
    DockableWindow.showMenu(window, pos)
  end
  return button
end
