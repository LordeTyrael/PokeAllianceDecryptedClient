---@diagnostic disable: undefined-global
local meritWindow = nil
local meritConnected = false

function showMeritWindow()
  if not meritWindow then
    meritWindow = g_ui.displayUI('merit')
  end
  if not meritConnected then
    connect(g_game, { onMeritData = onMeritData })
    meritConnected = true
  end
  meritWindow:show()
  meritWindow:raise()
  meritWindow:focus()
  g_uistates.push(meritWindow)
end

function hideMeritWindow()
  if meritConnected then
    disconnect(g_game, { onMeritData = onMeritData })
    meritConnected = false
  end
  if meritWindow then
    g_uistates.remove(meritWindow)
    meritWindow:destroy()
    meritWindow = nil
  end
end

function onMeritData(entries)
  if not meritWindow then return end

  local scroll = meritWindow:getChildById('meritScroll')
  local emptyLabel = meritWindow:getChildById('emptyLabel')
  local scrollBar = meritWindow:getChildById('meritScrollBar')

  scroll:destroyChildren()

  if not entries or #entries == 0 then
    emptyLabel:show()
    scroll:hide()
    scrollBar:hide()
    return
  end

  emptyLabel:hide()
  scroll:show()
  scrollBar:show()

  table.sort(entries, function(a, b) return (a.count or 0) > (b.count or 0) end)

  for i, entry in ipairs(entries) do
    if i > 1 then
      g_ui.createWidget('AllianceSeparator', scroll)
    end
    local row = g_ui.createWidget('MeritEntry', scroll)
    row:getChildById('itemIcon'):setItemId(entry.itemId)
    row:getChildById('itemName'):setText(entry.name or ('Item ' .. tostring(entry.itemId)))

    local count = entry.count or 0
    local required = entry.required or 0
    local countLabel = row:recursiveGetChildById('countLabel')
    local progressBg = row:recursiveGetChildById('progressBarBackground')
    local progressFill = row:recursiveGetChildById('progressBarFill')

    countLabel:setText(tostring(count) .. ' / ' .. tostring(required))

    local percent = 0
    if required > 0 then
      percent = math.max(1, math.min(100, math.floor((count / required) * 100)))
    end

    if progressBg and progressFill then
      local barWidth = math.floor(progressBg:getWidth() * percent / 100)
      progressFill:setWidth(barWidth)
    end

    row:setTooltip(entry.name or '')
  end
end
