BUY = 1
SELL = 2
CURRENCY = 'dollars'
CURRENCY_DECIMAL = false
WEIGHT_UNIT = ''
LAST_INVENTORY = 10

npcWindow = nil
itemsPanel = nil
radioTabs = nil
searchText = nil
moneyLabel = nil
buyTab = nil
sellTab = nil
initialized = false
local quickSellWindow = nil
local quickSellPinned = {}
local quickSellExcluded = {}
local tradeConfirmWindow = nil

showAllItems = nil
showAllItemsLabel = nil
sellAllButton = nil
playerFreeCapacity = 0
playerMoney = 0
tradeItems = {}
playerItems = {}

cancelNextRelease = nil

function init()
  npcWindow = g_ui.displayUI('npctrade')
  npcWindow:setVisible(false)

  itemsPanel = npcWindow:recursiveGetChildById('itemsPanel')
  searchText = npcWindow:recursiveGetChildById('searchText')
  moneyLabel = npcWindow:recursiveGetChildById('money')

  showAllItems = npcWindow:recursiveGetChildById('showAllItems')
  showAllItemsLabel = npcWindow:recursiveGetChildById('showAllItemsLabel')
  sellAllButton = npcWindow:recursiveGetChildById('sellAllButton')
  buyTab = npcWindow:getChildById('buyTab')
  sellTab = npcWindow:getChildById('sellTab')

  radioTabs = UIRadioGroup.create()
  radioTabs:addWidget(buyTab)
  radioTabs:addWidget(sellTab)
  radioTabs:selectWidget(buyTab)
  radioTabs.onSelectionChange = onTradeTypeChange

  cancelNextRelease = false

  if g_game.isOnline() then
    playerFreeCapacity = g_game.getLocalPlayer():getFreeCapacity()
  end

  connect(g_game, { onGameEnd = hide,
                    onOpenNpcTrade = onOpenNpcTrade,
                    onCloseNpcTrade = onCloseNpcTrade,
                    onPlayerGoods = onPlayerGoods } )

  connect(LocalPlayer, { onFreeCapacityChange = onFreeCapacityChange,
                         onInventoryChange = onInventoryChange } )

  initialized = true
end

function terminate()
  initialized = false
  npcWindow:destroy()

  disconnect(g_game, {  onGameEnd = hide,
                        onOpenNpcTrade = onOpenNpcTrade,
                        onCloseNpcTrade = onCloseNpcTrade,
                        onPlayerGoods = onPlayerGoods } )

  disconnect(LocalPlayer, { onFreeCapacityChange = onFreeCapacityChange,
                            onInventoryChange = onInventoryChange } )
end

function show()
  if g_game.isOnline() then
    if #tradeItems[BUY] > 0 then
      radioTabs:selectWidget(buyTab)
    else
      radioTabs:selectWidget(sellTab)
    end

    npcWindow:show()
    npcWindow:raise()
    npcWindow:focus()

    g_uistates.push(npcWindow)
  end
end

function hide()
  if npcWindow then
    g_uistates.remove(npcWindow)
  end

  closeTradeConfirm()
  npcWindow:hide()

  local layout = itemsPanel:getLayout()
  layout:disableUpdates()

  searchText:clearText()
  itemsPanel:destroyChildren()

  closeQuickSell()

  layout:enableUpdates()
  layout:update()
end

function onTradeTypeChange(radioTabs, selected, deselected)
  selected:setOn(true)
  deselected:setOn(false)

  local currentTradeType = getCurrentTradeType()
  showAllItems:setVisible(currentTradeType == SELL)
  if showAllItemsLabel then showAllItemsLabel:setVisible(currentTradeType == SELL) end
  sellAllButton:setVisible(currentTradeType == SELL)

  refreshTradeItems()
  refreshPlayerGoods()
end

function onSearchTextChange()
  refreshPlayerGoods()
end

function itemPopup(self, mousePosition, mouseButton)
  if cancelNextRelease then
    cancelNextRelease = false
    return false
  end

  local item = self.tradeItem
  if not item then
    return false
  end

  if mouseButton == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Look'), function() return g_game.inspectNpcTrade(item.ptr) end)
    menu:display(mousePosition)
    return true
  elseif ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton)
    or (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
    cancelNextRelease = true
    g_game.inspectNpcTrade(item.ptr)
    return true
  end
  return false
end

function onShowAllItemsChange()
  refreshPlayerGoods()
end

function setCurrency(currency, decimal)
  CURRENCY = currency
  CURRENCY_DECIMAL = decimal
end

-- Derived from the selected tab, never from a button caption: comparing displayed text against
-- tr('Buy') tied the whole trade mode to the active locale, and the sell side never came up.
function getCurrentTradeType()
  if radioTabs and radioTabs:getSelectedWidget() == sellTab then
    return SELL
  end
  return BUY
end

function getSellQuantity(item)
  if not item or not playerItems[item:getId()] then return 0 end
  return playerItems[item:getId()]
end

function canTradeItem(item)
  if getCurrentTradeType() == BUY then
    return (playerFreeCapacity >= item.weight) and playerMoney >= item.price
  else
    return getSellQuantity(item.ptr) > 0
  end
end

function getMaxTradeAmount(item)
  if getCurrentTradeType() == BUY then
    local capacityMaxCount = item.ptr:isStackable() and 10000 or 1
    local priceMaxCount = item.price > 0 and math.floor(playerMoney / item.price) or 0
    return math.max(0, math.min(getMaxAmount(), priceMaxCount, capacityMaxCount))
  end
  return math.max(0, math.min(getMaxAmount(), getSellQuantity(item.ptr)))
end

function closeTradeConfirm()
  if tradeConfirmWindow then
    tradeConfirmWindow:destroy()
    tradeConfirmWindow = nil
  end
end

function openTradeConfirm(item)
  if tradeConfirmWindow or not item then
    return
  end

  local maxAmount = getMaxTradeAmount(item)
  if maxAmount <= 0 then
    return
  end

  local isBuy = getCurrentTradeType() == BUY
  tradeConfirmWindow = ShopConfirm.show({
    title = isBuy and tr('Confirm Buy Item') or tr('Confirm Sell Item'),
    itemId = item.ptr:getId(),
    tooltip = item.name,
    priceGlyph = '@fa solid 14 f155',
    unitPrice = item.price,
    formatPrice = formatAmount,
    maxAmount = maxAmount,
    amount = isBuy and 1 or maxAmount,
    confirmText = isBuy and tr('Buy') or tr('Sell'),
    onConfirm = function(amount)
      tradeConfirmWindow = nil
      if isBuy then
        g_game.buyItem(item.ptr, amount, false, false)
      else
        g_game.sellItem(item.ptr, amount, false)
      end
    end,
    onClose = function()
      tradeConfirmWindow = nil
    end,
  })
end

function refreshTradeItems()
  local layout = itemsPanel:getLayout()
  layout:disableUpdates()

  closeTradeConfirm()
  searchText:clearText()
  itemsPanel:destroyChildren()

  local isBuy = getCurrentTradeType() == BUY
  for _, item in pairs(tradeItems[getCurrentTradeType()]) do
    local card = g_ui.createWidget('NPCItemBox', itemsPanel)
    card.tradeItem = item
    card.name:setText(item.name)
    card.price:setText(formatAmount(item.price))
    card.item:setItem(item.ptr)
    card.buyWidget:setText(isBuy and tr('Buy') or tr('Sell'))
    card.buyWidget.onClick = function() openTradeConfirm(item) end
    card.onMouseRelease = itemPopup
  end

  layout:enableUpdates()
  layout:update()
end

function refreshPlayerGoods()
  if not initialized then return end

  checkSellAllTooltip()

  moneyLabel:setText(formatAmount(playerMoney))

  local currentTradeType = getCurrentTradeType()
  local searchFilter = searchText:getText():lower()

  local items = itemsPanel:getChildCount()
  for i=1,items do
    local itemWidget = itemsPanel:getChildByIndex(i)
    local item = itemWidget.tradeItem

    local canTrade = canTradeItem(item)
    itemWidget:setOn(canTrade)
    itemWidget:setEnabled(canTrade)

    local searchCondition = (searchFilter == '') or (searchFilter ~= '' and string.find(item.name:lower(), searchFilter) ~= nil)
    local showAllItemsCondition = (currentTradeType == BUY) or (showAllItems:isChecked()) or (currentTradeType == SELL and not showAllItems:isChecked() and canTrade)
    itemWidget:setVisible(searchCondition and showAllItemsCondition)
  end
end

function onOpenNpcTrade(items)
  tradeItems[BUY] = {}
  tradeItems[SELL] = {}
  for key,item in pairs(items) do
    if item[4] > 0 then
      local newItem = {}
      newItem.ptr = item[1]
      newItem.name = item[2]
      newItem.weight = item[3] / 100
      newItem.price = item[4]
      table.insert(tradeItems[BUY], newItem)
    end
    
    if item[5] > 0 then
      local newItem = {}
      newItem.ptr = item[1]
      newItem.name = item[2]
      newItem.weight = item[3] / 100
      newItem.price = item[5]
      table.insert(tradeItems[SELL], newItem)
    end
  end

  refreshTradeItems()
  addEvent(show) -- player goods has not been parsed yet
end

function closeNpcTrade()
  g_game.closeNpcTrade()
  addEvent(hide)
end

function onCloseNpcTrade()
  addEvent(hide)
end

function onPlayerGoods(money, items)
  playerMoney = money

  playerItems = {}
  for key,item in pairs(items) do
    local id = item[1]:getId()
    if not playerItems[id] then
      playerItems[id] = item[2]
    else
      playerItems[id] = playerItems[id] + item[2]
    end
  end

  refreshPlayerGoods()
end

function onFreeCapacityChange(localPlayer, freeCapacity, oldFreeCapacity)
  playerFreeCapacity = freeCapacity

  if npcWindow:isVisible() then
    refreshPlayerGoods()
  end
end

function onInventoryChange(inventory, item, oldItem)
  refreshPlayerGoods()
end

function getTradeItemData(id, type)
  if table.empty(tradeItems[type]) then
    return false
  end

  if type then
    for key,item in pairs(tradeItems[type]) do
      if item.ptr and item.ptr:getId() == id then
        return item
      end
    end
  else
    for _,items in pairs(tradeItems) do
      for key,item in pairs(items) do
        if item.ptr and item.ptr:getId() == id then
          return item
        end
      end
    end
  end
  return false
end

function checkSellAllTooltip()
  sellAllButton:setEnabled(true)
  sellAllButton:removeTooltip()

  local total = 0
  local info = ''
  local first = true

  for key, amount in pairs(playerItems) do
    local data = getTradeItemData(key, SELL)
    if data then
      amount = getSellQuantity(data.ptr)
      if amount > 0 then
        info = info..(not first and "\n" or "")..
               formatMoney(amount, ".").." "..
               data.name.." ("..
               formatCurrency(data.price*amount)..")"

        total = total+(data.price*amount)
        if first then first = false end
      end
    end
  end
  if info ~= '' then
    info = info.."\n"..tr('Total')..": "..formatCurrency(total)
    sellAllButton:setTooltip(info)
  else
    sellAllButton:setEnabled(false)
  end
end

function formatAmount(amount)
  if CURRENCY_DECIMAL then
    amount = amount / 10000.0
  end
  return formatMoney(amount, ".")
end

function formatCurrency(amount)
  return "$" .. formatAmount(amount)
end

function getMaxAmount()
    return 10000
end

local function loadQuickSellPinned()
    quickSellPinned = {}
    -- setList/getList round-trips a flat string list to disk (setNode silently drops a
    -- sequential array). getList yields strings, so tonumber back to the numeric item id.
    for _, idStr in ipairs(g_settings.getList('QuickSellPinned')) do
        local n = tonumber(idStr)
        if n then quickSellPinned[n] = true end
    end
end

local function saveQuickSellPinned()
    local list = {}
    for id in pairs(quickSellPinned) do
        table.insert(list, tostring(id))
    end
    g_settings.setList('QuickSellPinned', list)
    g_settings.save()
end

-- right-click: permanent, persisted blacklist
function togglePinned(itemId)
    if quickSellPinned[itemId] then
        quickSellPinned[itemId] = nil
    else
        quickSellPinned[itemId] = true
        quickSellExcluded[itemId] = nil -- a permanent pin supersedes a session exclusion
    end
    saveQuickSellPinned()
    refreshQuickSell()
end

-- left-click: session-only exclusion (not persisted, not a permanent pin)
function toggleExcluded(itemId)
    if quickSellPinned[itemId] then return end -- already permanently pinned
    quickSellExcluded[itemId] = (not quickSellExcluded[itemId]) or nil
    refreshQuickSell()
end

function setupQuickSellItem(widget, itemId)
    widget.onMouseRelease = function(self, pos, button)
        if button == MouseRightButton then
            togglePinned(itemId)
            return true
        elseif button == MouseLeftButton then
            toggleExcluded(itemId)
            return true
        end
        return false
    end
end

function refreshQuickSell()
    if not quickSellWindow then return end
    local sellPanel = quickSellWindow:getChildById('sellPanel')
    local pinnedPanel = quickSellWindow:getChildById('pinnedPanel')

    local sellFlow = sellPanel:getLayout()
    sellFlow:disableUpdates()
    sellPanel:destroyChildren()
    local pinFlow = pinnedPanel:getLayout()
    pinFlow:disableUpdates()
    pinnedPanel:destroyChildren()

    local total = 0
    for _, entry in ipairs(tradeItems[SELL]) do
        local id = entry.ptr:getId()
        local amount = getSellQuantity(entry.ptr)
        if amount > 0 then
            local blocked = quickSellPinned[id] or quickSellExcluded[id]
            local widget = g_ui.createWidget('QuickSellItem', blocked and pinnedPanel or sellPanel)
            widget:setItemId(id)
            widget:setItemCount(amount)
            widget:setVirtual(true)
            widget:setTooltip(entry.name .. "\n" .. formatCurrency(entry.price * amount))
            setupQuickSellItem(widget, id)
            if quickSellPinned[id] then
                g_ui.createWidget('QuickSellPinIcon', widget)
            end
            if not blocked then
                total = total + entry.price * amount
            end
        end
    end

    sellFlow:enableUpdates()
    sellFlow:update()
    pinFlow:enableUpdates()
    pinFlow:update()

    quickSellWindow:getChildById('confirmLabel'):setText(
        tr('Are you sure you want to sell all these items for %s?', formatCurrency(total)))
    quickSellWindow:getChildById('sellButton'):setEnabled(total > 0)
    quickSellWindow:getChildById('pinnedLabel'):setVisible(pinnedPanel:getChildCount() > 0)
end

function closeQuickSell()
    if not quickSellWindow then return end
    g_uistates.remove(quickSellWindow)
    quickSellWindow:destroy()
    quickSellWindow = nil
end

function quickSellConfirm()
    local exceptions = {}
    for id in pairs(quickSellPinned) do
        table.insert(exceptions, id)
    end
    for id in pairs(quickSellExcluded) do
        if not quickSellPinned[id] then
            table.insert(exceptions, id)
        end
    end
    sellAll(exceptions)
    closeQuickSell()
end

function sellAllConfirm()
    if quickSellWindow then return end
    loadQuickSellPinned()
    quickSellExcluded = {} -- session exclusions start fresh each time the window opens
    quickSellWindow = g_ui.displayUI('quicksellwindow')
    refreshQuickSell()
    quickSellWindow:raise()
    quickSellWindow:focus()
    g_uistates.push(quickSellWindow)
end

function sellAll(exceptions)
  exceptions = exceptions or {}
  local queue = {}
  for _,entry in ipairs(tradeItems[SELL]) do
    local id = entry.ptr:getId()
    if not table.find(exceptions, id) then
      local sellQuantity = getSellQuantity(entry.ptr)
      while sellQuantity > 0 do
        local maxAmount = math.min(sellQuantity, getMaxAmount())
        table.insert(queue, {entry.ptr, maxAmount, false})
        sellQuantity = sellQuantity - maxAmount
      end
    end
  end
  for _, entry in ipairs(queue) do
    g_game.sellItem(entry[1], entry[2], entry[3])
  end
end
