local locatorWindow = nil
local listPanel = nil
local searchEdit = nil
local loadingIcon = nil
local cachedItems = {}
local searchEvent = nil
local loadingEvent = nil

local pendingLocate = nil
local locatorArrow = nil
local arrowRemoveEvent = nil
local arrowAnimEvent = nil

local SEARCH_DEBOUNCE_MS = 2000
local LOCATE_WINDOW_MS = 2500

function init()
  connect(g_game, {
    onGameEnd = onGameEnd,
    onReceiveItemLocator = onReceiveItemLocator,
  })
  connect(Container, { onOpen = onLocatorContainerOpen })
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onGameEnd,
    onReceiveItemLocator = onReceiveItemLocator,
  })
  disconnect(Container, { onOpen = onLocatorContainerOpen })
  clearArrow()
  destroyWindow()
end

function onGameEnd()
  destroyWindow()
end

function destroyWindow()
  if searchEvent then
    searchEvent:cancel()
    searchEvent = nil
  end
  stopLoading()
  clearArrow()
  pendingLocate = nil
  if locatorWindow then
    g_uistates.remove(locatorWindow)
    locatorWindow:destroy()
    locatorWindow = nil
    listPanel = nil
    searchEdit = nil
    loadingIcon = nil
  end
  cachedItems = {}
end

function clearArrow()
  if arrowRemoveEvent then
    arrowRemoveEvent:cancel()
    arrowRemoveEvent = nil
  end
  if arrowAnimEvent then
    arrowAnimEvent:cancel()
    arrowAnimEvent = nil
  end
  if locatorArrow then
    if not locatorArrow:isDestroyed() then
      locatorArrow:destroy()
    end
    locatorArrow = nil
  end
end

function pointArrowAt(slotWidget)
  clearArrow()

  local rect = slotWidget:getRect()
  if not rect or rect.width == 0 then return end

  local arrow = g_ui.createWidget('ItemLocatorPointer', rootWidget)
  arrow:breakAnchors()
  local baseX = rect.x + math.floor(rect.width / 2 - arrow:getWidth() / 2)
  local baseY = rect.y - arrow:getHeight() - 2
  arrow:setPosition({ x = baseX, y = baseY })
  arrow:setOpacity(0)
  arrow:raise()
  locatorArrow = arrow

  arrow:applyTransition('opacity', 1, '150ms ease-out')

  local up = true
  local function bob()
    if not locatorArrow or locatorArrow:isDestroyed() then return end
    locatorArrow:applyTransition('y', up and (baseY - 16) or baseY, '350ms out-back')
    up = not up
  end
  bob()
  arrowAnimEvent = cycleEvent(bob, 380)

  arrowRemoveEvent = scheduleEvent(function()
    arrowRemoveEvent = nil
    if arrowAnimEvent then
      arrowAnimEvent:cancel()
      arrowAnimEvent = nil
    end
    local a = locatorArrow
    locatorArrow = nil
    if a and not a:isDestroyed() then
      a:applyTransition('opacity', 0, '350ms ease-out')
      scheduleEvent(function()
        if a and not a:isDestroyed() then a:destroy() end
      end, 380)
    end
  end, 4500)
end

function onLocatorContainerOpen(container)
  if not pendingLocate then return end
  if (g_clock.millis() - pendingLocate.time) > LOCATE_WINDOW_MS then
    pendingLocate = nil
    return
  end

  local clientId = pendingLocate.clientId
  scheduleEvent(function()
    if not pendingLocate or pendingLocate.clientId ~= clientId then return end
    local panel = container.itemsPanel
    if not panel or panel:isDestroyed() then return end

    for _, child in ipairs(panel:getChildren()) do
      local it = child.getItem and child:getItem()
      if it and it:getId() == clientId then
        pendingLocate = nil
        pointArrowAt(child)
        return
      end
    end
  end, 60)
end

function startLoading()
  if not loadingIcon then return end
  loadingIcon:show()
  if not loadingEvent then
    loadingEvent = cycleEvent(function()
      if loadingIcon then
        loadingIcon:setRotation((loadingIcon:getRotation() + 30) % 360)
      end
    end, 60)
  end
end

function stopLoading()
  if loadingEvent then
    loadingEvent:cancel()
    loadingEvent = nil
  end
  if loadingIcon then
    loadingIcon:setRotation(0)
    loadingIcon:hide()
  end
end

function show()
  if not g_game.isOnline() then return end

  if not locatorWindow then
    locatorWindow = g_ui.loadUI('itemlocator', modules.game_interface.getRootPanel())
    listPanel = locatorWindow:getChildById('itemList')
    searchEdit = locatorWindow:getChildById('searchEdit')
    loadingIcon = locatorWindow:getChildById('loadingIcon')
    searchEdit.onTextChange = function() onSearchTextChange() end
  end

  cachedItems = {}
  if searchEdit then
    searchEdit:setText('')
  end
  if listPanel then
    listPanel:destroyChildren()
  end

  locatorWindow:show()
  locatorWindow:raise()
  locatorWindow:focus()
  g_uistates.push(locatorWindow)
  scheduleEvent(function()
    if searchEdit and not searchEdit:isDestroyed() then
      searchEdit:focus()
    end
  end, 50)
end

function hide()
  if locatorWindow then
    g_uistates.remove(locatorWindow)
    locatorWindow:hide()
  end
end

function toggle()
  if locatorWindow and locatorWindow:isVisible() then
    hide()
  else
    show()
  end
end

function onSearchTextChange()
  if searchEvent then
    searchEvent:cancel()
    searchEvent = nil
  end

  local query = searchEdit:getText()
  if query == nil or query == '' then
    stopLoading()
    cachedItems = {}
    if listPanel then listPanel:destroyChildren() end
    return
  end

  startLoading()
  cachedItems = {}
  if listPanel then listPanel:destroyChildren() end

  searchEvent = scheduleEvent(function()
    searchEvent = nil
    g_game.requestItemLocatorSearch(query)
  end, SEARCH_DEBOUNCE_MS)
end

function onReceiveItemLocator(items)
  stopLoading()
  cachedItems = {}
  for _, it in ipairs(items) do
    cachedItems[#cachedItems + 1] = {
      clientId = tonumber(it[1]),
      count = tonumber(it[2]),
      name = it[3],
    }
  end
  rebuildList()
end

function rebuildList()
  if not listPanel then return end
  listPanel:destroyChildren()
  for i, item in ipairs(cachedItems) do
    buildRow(item, i - 1)
  end
end

function buildRow(item, index)
  local row = g_ui.createWidget('ItemLocatorRow', listPanel)

  local icon = row:getChildById('icon')
  if icon then
    icon:setItemId(item.clientId)
  end

  local nameLabel = row:getChildById('name')
  if nameLabel then
    nameLabel:setText(item.name)
  end

  local countLabel = row:getChildById('count')
  if countLabel then
    countLabel:setText(item.count .. 'x')
  end

  row.snapshotIndex = index
  row.onClick = function()
    pendingLocate = { clientId = item.clientId, time = g_clock.millis() }
    g_game.requestItemLocatorOpen(index)
  end
end
