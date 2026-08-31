local marketWindow = nil
local Market = {}
local marketState = nil
local marketStateIndex = nil
local timeUpdateEvent = nil
local currentMarketView = "buy"
buyItemsCurrentPage = 1
buyItemsMaxPage = 1
sellItemsCurrentPage = 1
sellItemsMaxPage = 1
local currentSearchText = ""
local searchTimeout = nil
local createSearchText = ""
local createSearchTimeout = nil
local currentOrder = 1
local currentCategory = 1
local lastSortColumn = "time"
local marketItemsCache = nil
local marketItemsLoaded = false
local defaultOrderByView = {
    buy = 1,
    sell = 11,
    myitems = 1
}
local customOrderByView = {
    buy = nil,
    sell = nil,
    myitems = nil
}
local customColumnByView = {
    buy = nil,
    sell = nil,
    myitems = nil
}
Market.categories = {
    {key = "All", id = 1, image = "new_images/categories/all"},
    {key = "Diamonds", id = 2, image = "new_images/categories/diamonds"},
    {key = "Pokémon", id = 3, image = "new_images/categories/pokemon"},
    {key = "Poké Balls", id = 4, image = "new_images/categories/pokeballs"},
    {key = "Stones", id = 5, image = "new_images/categories/stones"},
    {key = "Helds", id = 6, image = "new_images/categories/helds"},
    {key = "Orbs", id = 7, image = "new_images/categories/orbs"},
    {key = "Creature Items", id = 8, image = "new_images/categories/creature_items"},
    {key = "General Items", id = 9, image = "new_images/categories/general_items"},
    {key = "Utilities", id = 10, image = "new_images/categories/utilities"},
    {key = "Addons", id = 11, image = "new_images/categories/addons"},
    {key = "Consumable", id = 12, image = "new_images/categories/consumable"},
    {key = "Foods", id = 13, image = "new_images/categories/foods"},
    {key = "Furnitures", id = 14, image = "new_images/categories/furnitures"}
}
Market.category = {}
Market.categoryByKey = {}
Market.categoryById = {}
Market.categoryLocalizedToKey = {}
for _, cat in ipairs(Market.categories) do
    cat.name = tr(cat.key)
    Market.category[cat.name] = cat.id
    Market.categoryByKey[cat.key] = cat.id
    Market.categoryById[cat.id] = cat
    Market.categoryLocalizedToKey[cat.name] = cat.key
end
local function resolveCategoryKey(category)
    if not category then
        return "All"
    end
    if Market.categoryByKey[category] then
        return category
    end
    if Market.categoryLocalizedToKey[category] then
        return Market.categoryLocalizedToKey[category]
    end
    return category
end
function isCurrentView(view)
    return currentMarketView == view
end
function getDefaultOrderForView(view)
    return defaultOrderByView[view] or 2
end
function updateOrderForView(newView)
    if customOrderByView[newView] and customColumnByView[newView] then
        currentOrder = customOrderByView[newView]
        lastSortColumn = customColumnByView[newView]
    else
        currentOrder = getDefaultOrderForView(newView)
        lastSortColumn = "time"
    end
end
function updateButtonVisibility()
    if not marketWindow then
        return
    end
    local buyButton = marketWindow:getChildById("buyButton")
    local sellNowButton = marketWindow:getChildById("sellNowButton")
    local selectItemButton = marketWindow:getChildById("selectItemButton")
    local createRequestButton = marketWindow:getChildById("createRequestButton")
    local categoryBackground = marketWindow:getChildById("categoryBackground")
    local categoryArea = marketWindow:getChildById("categoryArea")
    local categoryLabel = marketWindow:getChildById("categoryLabel")
    local sellItemsBackground = marketWindow:getChildById("sellItemsBackground")
    local buyRequestsBackground = marketWindow:getChildById("buyRequestsBackground")
    local buyRequestsLabel = marketWindow:getChildById("requestsLabel")
    local geralLabel = marketWindow:getChildById("geralLabel")
    local sellDropWindow = marketWindow:getChildById("sellDropWindow")
    local isMyItems = isCurrentView("myitems")
    local isSellView = isCurrentView("sell")
    if buyButton then
        buyButton:setVisible(not isMyItems and not isSellView)
    end
    if sellNowButton then
        sellNowButton:setVisible(not isMyItems and isSellView)
    end
    if selectItemButton then
        selectItemButton:setVisible(not isMyItems and not isSellView)
    end
    if createRequestButton then
        createRequestButton:setVisible(not isMyItems and isSellView)
    end
    if categoryBackground then
        categoryBackground:setVisible(not isMyItems)
    end
    if categoryArea then
        categoryArea:setVisible(not isMyItems)
    end
    if categoryLabel then
        categoryLabel:setVisible(not isMyItems)
    end
    if sellItemsBackground then
        sellItemsBackground:setVisible(isMyItems)
    end
    if buyRequestsLabel then
        buyRequestsLabel:setVisible(isMyItems)
    end
    if buyRequestsBackground then
        buyRequestsBackground:setVisible(isMyItems)
    end
    if sellDropWindow then
        sellDropWindow:setVisible(false)
    end
    if geralLabel then
        if isMyItems then
            geralLabel:setText(tr("My Items"))
            geralLabel:setVisible(true)
        else
            geralLabel:setVisible(false)
        end
    end
    local searchPanel = marketWindow and marketWindow:recursiveGetChildById("searchPanel")
    if searchPanel then
        searchPanel:setVisible(not isMyItems)
    end
    -- Slider de tolerância do alerta de preço: só faz sentido na aba de compra
    -- (as cores/estatísticas existem só na listagem de itens à venda).
    local priceAlertPanel = marketWindow and marketWindow:recursiveGetChildById("priceAlertPanel")
    if priceAlertPanel then
        priceAlertPanel:setVisible(not isMyItems and not isSellView)
    end
end
function Market.onSearchTextChanged(text)
    if not marketWindow then return end
    if searchTimeout then
        removeEvent(searchTimeout)
        searchTimeout = nil
    end
    searchTimeout = scheduleEvent(function()
        Market.performSearch(text)
    end, 500)
end
function Market.performSearch(text)
    if not marketWindow then
        return
    end
    if not text then
        local searchEdit = marketWindow:recursiveGetChildById("searchEdit")
        if searchEdit then
            text = searchEdit:getText() or ""
        else
            text = ""
        end
    end
    currentSearchText = text or ""
    if currentMarketView == "buy" then
        buyItemsCurrentPage = 1
    elseif currentMarketView == "sell" then
        sellItemsCurrentPage = 1
    end
    if currentMarketView == "sell" then
        if g_game.sendMarketBrowseRequests then
            g_game.sendMarketBrowseRequests(currentCategory, 1, currentOrder, currentSearchText)
        end
    else
        g_game.sendMarketBrowseItems(currentCategory, 1, currentOrder, currentSearchText)
    end
end
function Market.clearSearch()
    if not marketWindow then return end
    local searchEdit = marketWindow:recursiveGetChildById("searchEdit")
    if searchEdit then
        searchEdit:setText("")
    end
    currentSearchText = ""
    Market.performSearch()
end
function Market.getCurrentSearchText()
    return currentSearchText
end
function Market.recalculateItemNumbers()
    if not marketWindow then return end
    local panel = marketWindow.categoryBackground.itemArea
    if not panel then return end
    local children = panel:getChildren()
    local serverPage = buyItemsCurrentPage
    if currentMarketView == "sell" then
        serverPage = sellItemsCurrentPage
    end
    for index, widget in ipairs(children) do
        if widget.itemNumber then
            local globalIndex = (serverPage - 1) * 20 + index
            widget.itemNumber:setText("#"..globalIndex)
            widget.globalIndex = globalIndex
        end
    end
end
function Market.refreshCurrentView()
    local targetPage = buyItemsCurrentPage
    local targetMaxPage = buyItemsMaxPage
    if currentMarketView == "sell" then
        targetPage = sellItemsCurrentPage
        targetMaxPage = sellItemsMaxPage
    end
    if targetPage > targetMaxPage and targetMaxPage > 0 then
        targetPage = targetMaxPage
    end
    if targetPage < 1 then
        targetPage = 1
    end
    if currentMarketView == "sell" then
        if g_game.sendMarketBrowseRequests then
            g_game.sendMarketBrowseRequests(currentCategory, targetPage, currentOrder, currentSearchText)
        end
    else
        g_game.sendMarketBrowseItems(currentCategory, targetPage, currentOrder, currentSearchText)
    end
end
-- ── Price alert vs 30-day trade history ─────────────────────────────────────
-- "above" is highlighted in red; "normal" (within tolerance) is white.
-- Average 0 / no history = "none": the color is NOT touched (keeps the style
-- default) and no purchase warning is shown.
-- Tolerance is user-adjustable via the slider next to the search field and
-- persisted across sessions. Percent: 100 = only prices more than 100% above
-- the 30-day average (i.e. over 2x the average) are flagged red.
local PRICE_ALERT_TOLERANCE_DEFAULT = 100
-- getString: missing key -> "" -> nil -> default (getNumber would return 0,
-- which is a valid tolerance and can't be told apart from "unset").
local priceAlertTolerancePct = tonumber(g_settings.getString("market.priceAlertTolerance")) or PRICE_ALERT_TOLERANCE_DEFAULT
local PRICE_ALERT_COLORS = {
    above = "#ff5555",
    normal = "#ffffff"
    -- "none" intentionally absent: no setColor call
}

function Market.getPriceAlertLevel(itemInfo)
    local avg = itemInfo.avg30 or 0
    if avg == 0 or not itemInfo.count30 or itemInfo.count30 == 0 then
        return "none"
    end
    if (itemInfo.price or 0) > avg * (1 + priceAlertTolerancePct / 100) then
        return "above"
    end
    return "normal"
end

-- Recolore as linhas visíveis quando a tolerância muda (sem re-solicitar a lista).
-- Linhas "none" nunca receberam setColor e continuam intocadas.
function Market.refreshPriceAlertColors()
    if not marketWindow then
        return
    end
    local categoryBackground = marketWindow:getChildById("categoryBackground")
    local itemArea = categoryBackground and categoryBackground:getChildById("itemArea")
    if not itemArea then
        return
    end
    for _, child in pairs(itemArea:getChildren()) do
        if child.itemData and child.price then
            local alertColor = PRICE_ALERT_COLORS[Market.getPriceAlertLevel(child.itemData)]
            if alertColor then
                child.price:setColor(alertColor)
            end
        end
    end
end

function Market.setupPriceAlertSlider()
    if not marketWindow then
        return
    end
    local panel = marketWindow:recursiveGetChildById("priceAlertPanel")
    if not panel then
        return
    end
    local slider = panel:getChildById("priceAlertSlider")
    local valueLabel = panel:getChildById("priceAlertValue")
    if not slider or not valueLabel then
        return
    end

    slider:setMinimum(0)
    slider:setMaximum(300)
    slider:setStep(10)
    slider:setValue(priceAlertTolerancePct)
    valueLabel:setText("+" .. priceAlertTolerancePct .. "%")
    slider.onValueChange = function(self, v)
        v = math.floor(v / 10 + 0.5) * 10 -- snap em passos de 10%
        valueLabel:setText("+" .. v .. "%")
        if v == priceAlertTolerancePct then
            return
        end
        priceAlertTolerancePct = v
        -- Persistência: fica só em memória até o fechamento — o terminate() do
        -- cliente salva o config.otml (ConfigManager::terminate).
        g_settings.set("market.priceAlertTolerance", v)
        Market.refreshPriceAlertColors()
    end
end

function Market.getPriceStatsTooltip(itemInfo)
    if not itemInfo.count30 or itemInfo.count30 == 0 then
        return tr("No trades registered in the last 30 days.")
    end
    local text = string.format("Last 30 days: Avg $%s (Min $%s / Max $%s, %d trades)",
        comma_value2(itemInfo.avg30), comma_value2(itemInfo.min30), comma_value2(itemInfo.max30), itemInfo.count30)
    if itemInfo.count7 and itemInfo.count7 > 0 then
        text = text .. string.format("\nLast 7 days: Avg $%s (Min $%s / Max $%s, %d trades)",
            comma_value2(itemInfo.avg7), comma_value2(itemInfo.min7), comma_value2(itemInfo.max7), itemInfo.count7)
    end
    return text
end

Market.order = {
    TIME_DESC = 1,
    TIME_ASC = 2,
    ITEM_DESC = 3,
    ITEM_ASC = 4,
    NAME_DESC = 5,
    NAME_ASC = 6,
    SELLER_DESC = 7,
    SELLER_ASC = 8,
    AMOUNT_DESC = 9,
    AMOUNT_ASC = 10,
    PRICE_DESC = 11,
    PRICE_ASC = 12
}
local function toggleSort(columnType)
    local orderMap = {
        item = {Market.order.ITEM_DESC, Market.order.ITEM_ASC},
        name = {Market.order.NAME_DESC, Market.order.NAME_ASC},
        seller = {Market.order.SELLER_DESC, Market.order.SELLER_ASC},
        count = {Market.order.AMOUNT_DESC, Market.order.AMOUNT_ASC},
        price = {Market.order.PRICE_DESC, Market.order.PRICE_ASC},
        time = {Market.order.TIME_DESC, Market.order.TIME_ASC}
    }
    local orders = orderMap[columnType]
    if not orders then return end
    local descOrder = orders[1]
    local ascOrder = orders[2]
    local isSameColumn = (lastSortColumn == columnType)
    if isSameColumn then
        if currentOrder == descOrder then
            currentOrder = ascOrder
        else
            currentOrder = descOrder
        end
    else
        currentOrder = descOrder
    end
    lastSortColumn = columnType
    customOrderByView[currentMarketView] = currentOrder
    customColumnByView[currentMarketView] = columnType
    if currentMarketView == "buy" then
        buyItemsCurrentPage = 1
    elseif currentMarketView == "sell" then
        sellItemsCurrentPage = 1
    end
    if currentMarketView == "sell" then
        if g_game.sendMarketBrowseRequests then
            g_game.sendMarketBrowseRequests(currentCategory, 1, currentOrder, currentSearchText)
        end
    else
        g_game.sendMarketBrowseItems(currentCategory, 1, currentOrder, currentSearchText)
    end
end
function stopTimeUpdateEvent()
    if timeUpdateEvent then
        removeEvent(timeUpdateEvent)
        timeUpdateEvent = nil
    end
end
function updateMarketItemsTime()
    if not marketWindow then
        stopTimeUpdateEvent()
        return
    end
    local currentTime = g_clock.millis() / 1000
    local hasValidItems = false
    local function updatePanelTime(panel)
        if not panel then
            return
        end
        for _, child in pairs(panel:getChildren()) do
            if child.timeLeft and child.timeEndMark then
                local remainingTime = child.timeEndMark - currentTime
                if remainingTime > 0 then
                    hasValidItems = true
                    local timeText = string.format(
                        "%02d:%02d:%02d",
                        math.floor(remainingTime / (60 * 60)),
                        math.floor((remainingTime / 60) % 60),
                        math.floor(remainingTime % 60)
                    )
                    child.time:setText(timeText)
                else
                    child.time:setText(tr("Expired"))
                end
            end
        end
    end
    if isCurrentView("myitems") then
        local sellPanel = marketWindow.sellItemsBackground and marketWindow.sellItemsBackground.sellItemArea
        local buyPanel = marketWindow.buyRequestsBackground and marketWindow.buyRequestsBackground.buyRequestsArea
        updatePanelTime(sellPanel)
        updatePanelTime(buyPanel)
    else
        local panel = marketWindow.categoryBackground.itemArea
        updatePanelTime(panel)
    end
    if not hasValidItems then
        stopTimeUpdateEvent()
    else
        timeUpdateEvent = scheduleEvent(updateMarketItemsTime, 1000)
    end
end
function startTimeUpdateEvent()
    stopTimeUpdateEvent()
    timeUpdateEvent = scheduleEvent(updateMarketItemsTime, 1000)
end
function onGameStart()
    ProtocolGame.registerOpcode(0x117, parseMarketProtocol)
end
function onGameEnd()
    hideGameMarket()
    ProtocolGame.unregisterOpcode(0x117)
    marketItemsCache = nil
    marketItemsLoaded = false
end
local dragHintEvent = nil
function pollDragSellHint()
    dragHintEvent = scheduleEvent(pollDragSellHint, 150)
    if not marketWindow or not marketWindow:isVisible() or currentMarketView ~= "buy" then
        return
    end
    local hint = marketWindow:getChildById("dragSellHint")
    if not hint then
        return
    end
    local dragging = g_ui.getDraggingWidget()
    hint:setVisible(dragging ~= nil and isItemWidget(dragging))
end
function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onWalk = hideGameMarket,
        onAutoWalk = hideGameMarket
    })
    connect(LocalPlayer, {
        onBankBalanceChange = onBankBalanceChange
    })
    dragHintEvent = scheduleEvent(pollDragSellHint, 150)
end
function terminate()
    stopTimeUpdateEvent()
    if dragHintEvent then
        removeEvent(dragHintEvent)
        dragHintEvent = nil
    end
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onWalk = hideGameMarket,
        onAutoWalk = hideGameMarket
    })
    disconnect(LocalPlayer, {
        onBankBalanceChange = onBankBalanceChange
    })
    if marketState then
        marketState:release()
        marketState = nil
        marketStateIndex = nil
    end
end
function parseMarketProtocol(opcode, msg)
    local type = msg:getU8()
    if type == 1 then
        receiveMarketBuyItems(msg)
    elseif type == 9 then
        receiveMarketBrowseRequests(msg)
    elseif type == 11 then
        receiveMarketHistoric(msg)
    elseif type == 12 then
        receiveMarketSellItems(msg)
    elseif type == 15 then
        receiveMarketMyItems(msg)
    elseif type == 19 then
        receiveItemToSell(msg)
    elseif type == 20 then
        receiveMarketItemPurchased(msg)
    elseif type == 21 then
        receiveMarketItemUpdate(msg)
    elseif type == 23 then
        Market.onMarketCloseCreateRequest()
    elseif type == 24 then
        receiveMarketCreateOfferItems(msg)
    end
end
function receiveMarketBuyItems(msg)
    local category = msg:getU8()
    local page = msg:getU16()
    local maxPage = msg:getU16()
    local order = msg:getU8()
    local searchString = msg:getString()
    local itemCount = msg:getU16()
    local items = { }

    -- On first market open, request create-offer items from server
    if not marketItemsLoaded then
        Market.loadMarketItems()
    end
    for i = 1, itemCount do
        local itemInfo = {}
        itemInfo.itemCode = msg:getString()
        itemInfo.itemId = msg:getU16()
        itemInfo.clientId = msg:getU16()
        itemInfo.count = msg:getU16()
        itemInfo.price = msg:getU64()
        itemInfo.item_name = msg:getString()
        itemInfo.seller_name = msg:getString()
        itemInfo.description = msg:getString()
        itemInfo.image = msg:getString()
        itemInfo.pokeballType = msg:getString()
        itemInfo.timeleft = msg:getU32()
        itemInfo.anonymous = msg:getU8() == 1 or false
        local offerSize = msg:getU16()
        -- Price statistics (7d/30d) appended by the server; count30 == 0 means no history.
        itemInfo.avg7 = msg:getU64()
        itemInfo.min7 = msg:getU64()
        itemInfo.max7 = msg:getU64()
        itemInfo.count7 = msg:getU32()
        itemInfo.avg30 = msg:getU64()
        itemInfo.min30 = msg:getU64()
        itemInfo.max30 = msg:getU64()
        itemInfo.count30 = msg:getU32()
        table.insert(items, itemInfo)
    end
    local buffer = {
        page = page,
        category = category,
        max_page = maxPage,
        search_string = searchString,
        market_items = items
    }
    renderBuyItems(buffer)
end
function receiveMarketCreateOfferItems(msg)
    local categoryCount = msg:getU16()
    local newCache = {}

    -- Build a reverse lookup: categoryId -> categoryKey
    local idToKey = {}
    for _, cat in ipairs(Market.categories) do
        idToKey[cat.id] = cat.key
    end

    for c = 1, categoryCount do
        local categoryName = msg:getString()
        local categoryId = msg:getU8()
        local itemCount = msg:getU16()

        local key = idToKey[categoryId] or categoryName
        if not newCache[key] then
            newCache[key] = {}
        end

        for i = 1, itemCount do
            local item = {}
            item.clientId = msg:getU16()
            item.id = msg:getU16()
            item.name = msg:getString()
            table.insert(newCache[key], item)
        end
    end

    marketItemsCache = newCache
    marketItemsLoaded = true

    -- If the create request window is currently open, refresh it
    if marketWindow then
        local createRequestWindow = marketWindow:getChildById("createRequestWindow")
        if createRequestWindow and createRequestWindow:isVisible() then
            local categoryComboBox = createRequestWindow:getChildById("categoryComboBox")
            if categoryComboBox then
                local currentOption = categoryComboBox:getCurrentOption()
                if currentOption then
                    Market.loadRequestItems(currentOption.text or currentOption)
                end
            end
        end
    end
end
function receiveMarketBrowseRequests(msg)
    local category = msg:getU8()
    local page = msg:getU16()
    local maxPage = msg:getU16()
    local order = msg:getU8()
    local searchString = msg:getString()
    local requestsCount = msg:getU16()    
    local requests = {}
    for i = 1, requestsCount do
        local request = {}
        request.requestId = msg:getU64()
        request.playerName = msg:getString()
        request.clientId = msg:getU16()
        request.maxPrice = msg:getU64()
        request.remainingCount = msg:getU16()
        request.itemName = msg:getString()
        request.timeLeft = msg:getU32()
        request.anonymous = msg:getU8() == 1
        request.description = "Buy Request"
        request.pokeballType = ""
        table.insert(requests, request)
    end
    local buffer = {
        category = category,
        page = page,
        max_page = maxPage,
        order = order,
        search_string = searchString,
        market_requests = requests
    }
    renderBrowseRequests(buffer)
end
function receiveMarketHistoric(msg)
    local size = msg:getU16()
    local historicData = {}
    for i = 1, size do
        local entry = {}
        entry.type = msg:getU8()
        entry.itemName = msg:getString()
        entry.itemCount = msg:getU32()
        entry.price = msg:getU64()
        entry.time = msg:getU64()
        entry.isBuyer = msg:getU8() == 1
        table.insert(historicData, entry)
    end
    showHistoricWindow(historicData)
end
function receiveMarketSellItems(msg)
    local sellItemsCount = msg:getU16()
    local sellItems = {}
    for i = 1, sellItemsCount do
        local itemInfo = {}
        itemInfo.code = msg:getString()
        itemInfo.itemId = msg:getU16()
        itemInfo.clientId = msg:getU16()
        itemInfo.count = msg:getU16()
        itemInfo.price = msg:getU64()
        itemInfo.item_name = msg:getString()
        itemInfo.description = msg:getString()
        itemInfo.image = msg:getString()
        itemInfo.pokeballType = msg:getString()
        itemInfo.timeleft = msg:getU32()
        itemInfo.anonymous = msg:getU8() == 1 or false
        itemInfo.offerSize = msg:getU16()
        itemInfo.type = "sell"
        table.insert(sellItems, itemInfo)
    end
    local buyRequestsCount = msg:getU16()
    local buyRequests = {}
    for i = 1, buyRequestsCount do
        local requestInfo = {}
        requestInfo.code = msg:getString()
        requestInfo.itemId = msg:getU16()
        requestInfo.clientId = msg:getU16()
        requestInfo.count = msg:getU16()
        requestInfo.maxPrice = msg:getU64()
        requestInfo.item_name = msg:getString()
        requestInfo.description = msg:getString()
        requestInfo.image = msg:getString()
        requestInfo.pokeballType = msg:getString()
        requestInfo.timeleft = msg:getU32()
        requestInfo.status = msg:getString()
        requestInfo.filledCount = msg:getU16()
        requestInfo.offerSize = msg:getU16()
        requestInfo.type = "buy_request"
        table.insert(buyRequests, requestInfo)
    end
    local buffer = {
        category = currentCategory or 1,
        search_string = "",
        market_requests = buyRequests,
    }
    renderBrowseRequests(buffer)
end
function receiveMarketMyItems(msg)    
    local sellItems = {}
    local buyRequests = {}
    local sellItemsCount = msg:getU16()    
    for i = 1, sellItemsCount do
        local itemInfo = {}
        itemInfo.code = msg:getString()
        itemInfo.itemId = msg:getU16()
        itemInfo.clientId = msg:getU16()
        itemInfo.count = msg:getU16()
        itemInfo.price = msg:getU64()
        itemInfo.item_name = msg:getString()
        itemInfo.description = msg:getString()
        itemInfo.image = msg:getString()
        itemInfo.pokeballType = msg:getString()
        itemInfo.timeleft = msg:getU32()
        itemInfo.anonymous = msg:getU8() == 1 or false
        itemInfo.offerSize = msg:getU16()
        itemInfo.type = "sell"
        table.insert(sellItems, itemInfo)
    end
    local buyRequestsCount = msg:getU16()
    for i = 1, buyRequestsCount do
        local requestInfo = {}
        requestInfo.code = msg:getString()
        requestInfo.itemId = msg:getU16()
        requestInfo.clientId = msg:getU16()
        requestInfo.count = msg:getU16()
        requestInfo.maxPrice = msg:getU64()
        requestInfo.item_name = msg:getString()
        requestInfo.description = msg:getString()
        requestInfo.image = msg:getString()
        requestInfo.pokeballType = msg:getString()
        requestInfo.timeleft = msg:getU32()
        requestInfo.status = msg:getString()
        requestInfo.filledCount = msg:getU16()
        requestInfo.offerSize = msg:getU16()
        requestInfo.type = "buy_request"
        table.insert(buyRequests, requestInfo)
    end
    local buffer = {
        first = true,
        sell_items = sellItems,
        buy_requests = buyRequests,
    }
    renderMyItems(buffer)
end
function receiveMarketItemPurchased(msg)
    local itemCode = msg:getString()
    local itemName = msg:getString()
    local itemImage = msg:getString()
    local count = msg:getU16()
    local totalPrice = msg:getU64()
    local remainingCount = msg:getU16()
    local completelySold = msg:getU8() == 1
    if currentMarketView == "myitems" then
        scheduleEvent(function()
            getSellItems()
        end, 1000)
    else
        scheduleEvent(function()
            Market.refreshCurrentView()
        end, 500)
    end
end
function receiveMarketItemUpdate(msg)
    local itemCode = msg:getString()
    local newCount = msg:getU16()
    local newPrice = msg:getU64()
    local isCompletelyRemoved = msg:getU8() == 1
    local function updateWidgetInPanel(panel)
        if not panel then
            return false
        end
        local itemFound = false
        for _, child in pairs(panel:getChildren()) do
            if child.itemData and child.itemData.itemCode == itemCode then
                if isCompletelyRemoved then
                    child:destroy()
                    itemFound = true
                else
                    child.itemData.count = newCount
                    child.itemData.price = newPrice
                    child.count:setText(newCount)
                    child.price:setText("$"..formatNumberValue(newPrice))
                    -- Recompute the price alert: an edited price can cross the 30d average.
                    local alertColor = PRICE_ALERT_COLORS[Market.getPriceAlertLevel(child.itemData)]
                    if alertColor then
                        child.price:setColor(alertColor)
                    end
                end
                return true
            end
        end
        return itemFound
    end
    local function recalculateItemNumbers(panel)
        if not panel then
            return
        end
        local children = panel:getChildren()
        for index, widget in ipairs(children) do
            if widget.itemNumber then
                local newGlobalIndex = index
                if panel == marketWindow.categoryBackground.itemArea then
                    local serverPage = buyItemsCurrentPage or 1
                    newGlobalIndex = (serverPage - 1) * 20 + index
                end
                widget.itemNumber:setText("#"..newGlobalIndex)
                widget.globalIndex = newGlobalIndex
            end
        end
    end
    if not marketWindow then
        return
    end
    local updated = false
    local panelWithRemovedItem = nil
    if marketWindow.categoryBackground and marketWindow.categoryBackground.itemArea then
        local wasUpdated = updateWidgetInPanel(marketWindow.categoryBackground.itemArea)
        if wasUpdated and isCompletelyRemoved then
            panelWithRemovedItem = marketWindow.categoryBackground.itemArea
        end
        updated = wasUpdated or updated
    end
    if marketWindow.sellItemsBackground and marketWindow.sellItemsBackground.sellItemArea then
        local wasUpdated = updateWidgetInPanel(marketWindow.sellItemsBackground.sellItemArea)
        if wasUpdated and isCompletelyRemoved then
            panelWithRemovedItem = marketWindow.sellItemsBackground.sellItemArea
        end
        updated = wasUpdated or updated
    end
    if marketWindow.buyRequestsBackground and marketWindow.buyRequestsBackground.buyRequestsArea then
        local wasUpdated = updateWidgetInPanel(marketWindow.buyRequestsBackground.buyRequestsArea)
        if wasUpdated and isCompletelyRemoved then
            panelWithRemovedItem = marketWindow.buyRequestsBackground.buyRequestsArea
        end
        updated = wasUpdated or updated
    end
    if panelWithRemovedItem then
        scheduleEvent(function()
            recalculateItemNumbers(panelWithRemovedItem)
        end, 10)
    end
end
function setupMarketState()
    if not marketWindow then return end
    if not marketState then
        marketState = UIState.create()
        marketStateIndex = marketState:new(function(released)
            if released then
                if marketWindow and not marketWindow:isDestroyed() then
                    g_uistates.remove(marketWindow)
                end
            else
                if marketWindow and not marketWindow:isDestroyed() then
                    g_uistates.push(marketWindow)
                end
            end
        end)
        marketState:gotoState(0)
    end
    marketState:gotoState(marketStateIndex)
end

function hideGameMarket()
    stopTimeUpdateEvent()
    -- Sem isto a acao pendente sobrevive ao fechamento do market presa numa closure. Hoje ela nao
    -- teria como disparar (a janela volta invisivel e so showCancelOfferConfirm a repovoa), mas e
    -- um gatilho armado esperando alguem chamar confirmCancelOffer por outro caminho.
    closeCancelOfferConfirm()
    if marketState and marketStateIndex then
        marketState:gotoState(0)
    end
    if marketWindow then
        marketWindow:destroy()
        marketWindow = nil
        currentSearchText = ""
    end
end
function onBankBalanceChange(localPlayer, value)
    if not marketWindow then
        return
    end
    marketWindow.balanceBar.balanceLabel:setText(comma_value2(value))
end
function updateBalance()
    local player = g_game.getLocalPlayer()
    if player then
        onBankBalanceChange(player, player:getBankBalance())
    end
end
function getSellItems()
    currentMarketView = "myitems"
    updateOrderForView("myitems")
    g_game.sendMarketViewMyItems()
end
function getMyRequests()
    currentMarketView = "myitems"
    updateOrderForView("myitems")
    g_game.sendMarketViewMyItems()
end
-- Confirmacao antes de remover. O botao de cancelar e um X de 24px dentro da propria linha da
-- oferta (newmarket.otui:311), colado no resto da lista: um clique errado derrubava a oferta sem
-- nenhuma volta. No caso de venda o item retorna para a bag, mas o tempo de anuncio ja corrido
-- some junto.
--
-- Usa o cancelOfferConfirmWindow do proprio newmarket.otui, no mesmo molde do buyConfirmWindow e
-- do sellNowConfirmWindow, em vez do displayGeneralBox do corelib -- que traz o estilo MainWindow
-- antigo e destoa do resto da janela.
--
-- A acao fica pendurada aqui e nao no widget do botao: o `Remove` do otui e um @onClick fixo, sem
-- parametro, entao quem sabe o que remover e este estado.
local pendingCancelAction = nil

function closeCancelOfferConfirm()
    pendingCancelAction = nil
    if not marketWindow then
        return
    end
    local window = marketWindow:getChildById('cancelOfferConfirmWindow')
    if window then
        window:setVisible(false)
    end
end

function confirmCancelOffer()
    local action = pendingCancelAction
    closeCancelOfferConfirm()
    if action then
        action()
    end
end

local function showCancelOfferConfirm(row, message, onConfirm)
    if not marketWindow then
        return
    end
    local window = marketWindow:getChildById('cancelOfferConfirmWindow')
    if not window then
        -- Sem a janela, remover direto seria pior do que nao remover: o jogador perderia a oferta
        -- sem ter visto confirmacao nenhuma.
        return
    end

    local icon = window:recursiveGetChildById('cancelOfferItem')
    if icon then
        icon:setItemId(row.clientId or 0)
        if row.pokeballType then
            icon:setPokeballName(row.pokeballType)
        end
    end

    local nameLabel = window:recursiveGetChildById('cancelOfferItemName')
    if nameLabel then
        nameLabel:setText(row.itemName or '')
    end

    local messageLabel = window:recursiveGetChildById('cancelOfferMessage')
    if messageLabel then
        messageLabel:setText(message)
    end

    pendingCancelAction = onConfirm
    window:setVisible(true)
    window:raise()
    window:focus()
end

function cancelSellItem(widget)
    if not widget then
        return
    end
    -- Os valores sao copiados para locais ANTES da confirmacao: o `widget` e uma linha da lista, e
    -- o getMyRequests() de qualquer outra acao destroi e recria essas linhas. A closure guardando o
    -- widget leria um widget morto quando o jogador finalmente clicasse em Yes.
    local row = {
        itemName = widget.itemName,
        clientId = widget.clientId,
        pokeballType = widget.pokeballType
    }
    if widget.itemCode then
        local itemCode = widget.itemCode
        showCancelOfferConfirm(row, tr('This sell offer will be removed and the item returns to you.'),
            function()
                g_game.sendMarketCancelItem(itemCode)
                scheduleEvent(getMyRequests, 500)
            end)
    elseif widget.requestId then
        local requestId = widget.requestId
        showCancelOfferConfirm(row, tr('This buy request will be removed from the market.'),
            function()
                g_game.sendMarketCancelRequest(requestId)
                scheduleEvent(getMyRequests, 500)
            end)
    end
end
function cancelRequest(widget)
    if not widget or not widget.requestId then
        return
    end
    local requestId = widget.requestId
    local row = {
        itemName = widget.itemName,
        clientId = widget.clientId,
        pokeballType = widget.pokeballType
    }
    showCancelOfferConfirm(row, tr('This buy request will be removed from the market.'),
        function()
            g_game.sendMarketCancelRequest(requestId)
            scheduleEvent(getMyRequests, 500)
        end)
end
function renderBuyItems(info)
    if not marketWindow then
        marketWindow = g_ui.loadUI("newmarket", modules.game_interface.getRootPanel())
        for _, categoryData in ipairs(Market.categories) do
            local categoryWidget = g_ui.createWidget("MarketCategoryButton", marketWindow.categoryArea)
            categoryWidget.name:setText(categoryData.name)
            categoryWidget.icon:setImageSource(categoryData.image)
            categoryWidget.marketId = categoryData.id
            categoryWidget.onClick = function()
                requestMarketCategory(categoryData.id, categoryWidget)
            end
        end
        configureMainButtons()
        setupMarketState()
        Market.setupPriceAlertSlider()
        updateBalance()
    end
    currentMarketView = "buy"
    updateOrderForView("buy")
    local titlePanel = marketWindow.categoryBackground.titlePanelBackground
    if titlePanel then
        local sellerNameHeader = titlePanel:getChildById("seller_name")
        if sellerNameHeader then
            sellerNameHeader:setText(tr("Seller"))
        end
    end
    updateButtonVisibility()
    local categoryLabel = marketWindow:getChildById("categoryLabel")
    if categoryLabel then
        categoryLabel:setVisible(true)
        categoryLabel:setText(tr("Categories"))
    end
    configureMainButtons()
        local sellNowButton = marketWindow:getChildById("sellNowButton")
        if sellNowButton then
            sellNowButton.onClick = function()
                Market.onSellNowButtonClick()
            end
        end
        local selectItemButton = marketWindow:getChildById("selectItemButton")
        if selectItemButton then
            selectItemButton.onClick = Market.onSelectItemButtonClick
        end
        local sellDropWindow = marketWindow:getChildById("sellDropWindow")
        if sellDropWindow then
            local sellDropArea = sellDropWindow:getChildById("sellDropArea")
            if sellDropArea then
                sellDropArea.onDrop = Market.onReceiveItemToSell
            else
            end
        else
        end
        local titlePanel = marketWindow.categoryBackground.titlePanelBackground
        if titlePanel then
            local itemImageHeader = titlePanel:getChildById("item_image")
            if itemImageHeader then
                itemImageHeader.item:setPhantom(true)
                itemImageHeader:setPhantom(false)
                itemImageHeader:setCursor("pointer")
                itemImageHeader.onClick = function() toggleSort("item") end
            end
            local itemNameHeader = titlePanel:getChildById("item_name")
            if itemNameHeader then
                itemNameHeader:setPhantom(false)
                itemNameHeader:setCursor("pointer")
                itemNameHeader.onClick = function() toggleSort("name") end
            end
            local sellerNameHeader = titlePanel:getChildById("seller_name")
            if sellerNameHeader then
                sellerNameHeader:setPhantom(false)
                sellerNameHeader:setCursor("pointer")
                sellerNameHeader.onClick = function() toggleSort("seller") end
            end
            local countHeader = titlePanel:getChildById("count")
            if countHeader then
                countHeader:setPhantom(false)
                countHeader:setCursor("pointer")
                countHeader.onClick = function() toggleSort("count") end
            end
            local priceHeader = titlePanel:getChildById("price")
            if priceHeader then
                priceHeader:setPhantom(false)
                priceHeader:setCursor("pointer")
                priceHeader.onClick = function() toggleSort("price") end
            end
            local timeHeader = titlePanel:getChildById("time")
            if timeHeader then
                timeHeader:setPhantom(false)
                timeHeader:setCursor("pointer")
                timeHeader.onClick = function() toggleSort("time") end
            end
        end
    currentCategory = info.category or 1
    buyItemsCurrentPage = info.page or 1
    buyItemsMaxPage = info.max_page or 1
    local panel = marketWindow.categoryBackground.itemArea
    local layout = panel:getLayout()
    layout:disableUpdates()
    panel:destroyChildren()
    local currentTime = g_clock.millis() / 1000
    for index, itemConfig in ipairs(info.market_items) do
        local categoryWidget = g_ui.createWidget("MarketItemPanel", panel)
        categoryWidget.itemData = itemConfig
        local serverPage = info.page or buyItemsCurrentPage
        local globalIndex = (serverPage - 1) * 20 + index
        categoryWidget.itemNumber:setText("#"..globalIndex)
        categoryWidget.globalIndex = globalIndex
        categoryWidget.item_name:setText(itemConfig.item_name)
        categoryWidget.seller_name:setText(itemConfig.seller_name)
        categoryWidget.count:setText(itemConfig.count)
        categoryWidget.item_image:setText("")
        categoryWidget.item_image.item:setItemId(itemConfig.clientId)
        categoryWidget.item_image.item:setTooltip(itemConfig.description)
        categoryWidget.item_image.item:setPokeballName(itemConfig.pokeballType)
        categoryWidget.price:setText("$"..formatNumberValue(itemConfig.price))
        local alertColor = PRICE_ALERT_COLORS[Market.getPriceAlertLevel(itemConfig)]
        if alertColor then
            categoryWidget.price:setColor(alertColor)
        end
        -- Tooltip com o histórico de preços. Tem que ir no filho `background`: é ele
        -- (não-phantom, cobrindo a linha) que recebe o hover — onHoverChange não propaga
        -- pra ancestrais e o módulo de tooltip só lê o widget exato sob o cursor. Os
        -- labels (price etc.) são phantom e deixam o hover cair no background.
        local statsTooltip = Market.getPriceStatsTooltip(itemConfig)
        if categoryWidget.background then
            categoryWidget.background:setTooltip(statsTooltip)
        end
        categoryWidget:setTooltip(statsTooltip)
        categoryWidget.timeLeft = itemConfig.timeleft
        categoryWidget.timeEndMark = currentTime + itemConfig.timeleft
        local timeText = itemConfig.timeleft <= 0 and "Expired" or
                string.format(
                    "%02d:%02d:%02d",
                    math.floor(itemConfig.timeleft / (60 * 60)),
                    math.floor((itemConfig.timeleft / 60) % 60),
                    math.floor(itemConfig.timeleft % 60)
                )
        categoryWidget.time:setText(timeText)
        local imageBackground = index % 2 == 1 and "background_2" or "background_3"
        local imageSource = "/images/newui/"..imageBackground
        local newSource = index == 1 and imageSource .."_selected" or imageSource
        categoryWidget.background:setImageSource(newSource)
        categoryWidget.onFocusChange = function(widget, focused)
            if focused then
                widget.background:setImageSource(imageSource.."_selected")
            else
                widget.background:setImageSource(imageSource)
            end
        end
    end
    layout:enableUpdates()
    layout:update()
    startTimeUpdateEvent()
    Market.updatePaginationControls()
end
function renderMyItems(info)
    if not marketWindow then
        return
    end
    currentMarketView = "myitems"
    updateOrderForView("myitems")
    updateButtonVisibility()
    setupMyItemsHeaders()
    stopTimeUpdateEvent()
    local sellPanel = marketWindow.sellItemsBackground.sellItemArea
    local sellLayout = sellPanel:getLayout()
    sellLayout:disableUpdates()
    sellPanel:destroyChildren()
    local buyPanel = marketWindow.buyRequestsBackground.buyRequestsArea
    local buyLayout = buyPanel:getLayout()
    buyLayout:disableUpdates()
    buyPanel:destroyChildren()
    local currentTime = g_clock.millis() / 1000
    if info.sell_items then
        for index, sellItem in ipairs(info.sell_items) do
            local sellWidget = g_ui.createWidget("MyItemsPanel", sellPanel)
            sellWidget.itemNumber:setText("#"..index)
            sellWidget.item_name:setText(sellItem.item_name)
            sellWidget.count:setText(sellItem.count)
            sellWidget.item_image:setText("")
            sellWidget.item_image.item:setItemId(sellItem.clientId)
            sellWidget.item_image.item:setTooltip(sellItem.description)
            sellWidget.item_image.item:setPokeballName(sellItem.pokeballType)
            sellWidget.price:setText("$"..formatNumberValue(sellItem.price))
            sellWidget.itemCode = sellItem.code
            sellWidget.itemName = sellItem.item_name
            sellWidget.clientId = sellItem.clientId
            sellWidget.pokeballType = sellItem.pokeballType
            sellWidget.timeLeft = sellItem.timeleft
            sellWidget.timeEndMark = currentTime + sellItem.timeleft
            local timeText = sellItem.timeleft <= 0 and "Expired" or
                    string.format(
                        "%02d:%02d:%02d",
                        math.floor(sellItem.timeleft / (60 * 60)),
                        math.floor((sellItem.timeleft / 60) % 60),
                        math.floor(sellItem.timeleft % 60)
                    )
            sellWidget.time:setText(timeText)
            local cancelButton = sellWidget.actions.cancelButton
            if cancelButton then
                cancelButton:setVisible(true)
                cancelButton.onClick = function()
                    cancelSellItem(sellWidget)
                end
            end
            local imageBackground = index % 2 == 1 and "background_2" or "background_3"
            local imageSource = "/images/newui/"..imageBackground
            local newSource = index == 1 and imageSource .."_selected" or imageSource
            sellWidget.background:setImageSource(newSource)
            sellWidget.onFocusChange = function(widget, focused)
                if focused then
                    widget.background:setImageSource(imageSource.."_selected")
                else
                    widget.background:setImageSource(imageSource)
                end
            end
        end
    end
    if info.buy_requests then
        for index, buyRequest in ipairs(info.buy_requests) do
            local requestWidget = g_ui.createWidget("MyItemsPanel", buyPanel)
            requestWidget.itemNumber:setText("#"..index)
            requestWidget.item_image:setText("")
            requestWidget.item_image.item:setItemId(buyRequest.clientId)
            requestWidget.item_image.item:setTooltip(buyRequest.description)
            requestWidget.item_name:setText(buyRequest.item_name)
            requestWidget.count:setText(buyRequest.count)
            requestWidget.item_image:setText("")
            requestWidget.item_image.item:setPokeballName(buyRequest.pokeballType)
            requestWidget.price:setText("$"..formatNumberValue(buyRequest.maxPrice))
            requestWidget.requestId = tonumber(buyRequest.code)
            requestWidget.itemName = buyRequest.item_name
            requestWidget.clientId = buyRequest.clientId
            requestWidget.pokeballType = buyRequest.pokeballType
            requestWidget.timeLeft = buyRequest.timeleft
            requestWidget.timeEndMark = currentTime + buyRequest.timeleft
            local timeText = buyRequest.timeleft <= 0 and "Expired" or
                    string.format(
                        "%02d:%02d:%02d",
                        math.floor(buyRequest.timeleft / (60 * 60)),
                        math.floor((buyRequest.timeleft / 60) % 60),
                        math.floor(buyRequest.timeleft % 60)
                    )
            requestWidget.time:setText(timeText)
            local cancelButton = requestWidget.actions.cancelButton
            if cancelButton then
                cancelButton:setVisible(true)
                cancelButton.onClick = function()
                    cancelRequest(requestWidget)
                end
            end
            local imageBackground = index % 2 == 1 and "background_2" or "background_3"
            local imageSource = "/images/newui/"..imageBackground
            local newSource = index == 1 and imageSource .."_selected" or imageSource
            requestWidget.background:setImageSource(newSource)
            requestWidget.onFocusChange = function(widget, focused)
                if focused then
                    widget.background:setImageSource(imageSource.."_selected")
                else
                    widget.background:setImageSource(imageSource)
                end
            end
        end
    end
    sellLayout:enableUpdates()
    sellLayout:update()
    buyLayout:enableUpdates() 
    buyLayout:update()
    startTimeUpdateEvent()
    Market.updatePaginationControls()
end
function renderBrowseRequests(info)
    if not marketWindow then
        marketWindow = g_ui.loadUI("newmarket", modules.game_interface.getRootPanel())
        for _, categoryData in ipairs(Market.categories) do
            local categoryWidget = g_ui.createWidget("MarketCategoryButton", marketWindow.categoryArea)
            categoryWidget.name:setText(categoryData.name)
            categoryWidget.icon:setImageSource(categoryData.image)
            categoryWidget.marketId = categoryData.id
            categoryWidget.onClick = function()
                requestMarketCategory(categoryData.id, categoryWidget)
            end
        end
        configureMainButtons()
        setupMarketState()
        updateBalance()
    end
    currentMarketView = "sell"
    updateOrderForView("sell")
    local titlePanel = marketWindow.categoryBackground.titlePanelBackground
    if titlePanel then
        local sellerNameHeader = titlePanel:getChildById("seller_name")
        if sellerNameHeader then
            sellerNameHeader:setText(tr("Buyer"))
        end
    end
    local sellNowButton = marketWindow:getChildById("sellNowButton")
    if sellNowButton and not sellNowButton.onClick then
        sellNowButton.onClick = function()
        end
    end
    local selectItemButton = marketWindow:getChildById("selectItemButton")
    if selectItemButton and not selectItemButton.onClick then
        selectItemButton.onClick = Market.onSelectItemButtonClick
    end
    local sellDropWindow = marketWindow:getChildById("sellDropWindow")
    if sellDropWindow then
        local sellDropArea = sellDropWindow:getChildById("sellDropArea")
        if sellDropArea and not sellDropArea.onDrop then
            sellDropArea.onDrop = Market.onReceiveItemToSell
        end
    end
    configureMainButtons()
    updateButtonVisibility()
    local categoryLabel = marketWindow:getChildById("categoryLabel")
    if categoryLabel then
        categoryLabel:setVisible(true)
        categoryLabel:setText(tr("Categories"))
    end
    currentCategory = info.category or currentCategory or 1
    sellItemsMaxPage = math.max(info.max_page or sellItemsMaxPage or 1, 1)
    sellItemsCurrentPage = info.page or sellItemsCurrentPage or 1
    if sellItemsCurrentPage > sellItemsMaxPage then
        sellItemsCurrentPage = sellItemsMaxPage
    elseif sellItemsCurrentPage < 1 then
        sellItemsCurrentPage = 1
    end
    local panel = marketWindow.categoryBackground.itemArea
    local layout = panel:getLayout()
    layout:disableUpdates()
    panel:destroyChildren()
    local currentTime = g_clock.millis() / 1000
    local requests = info.market_requests or {}
    local serverPage = info.page or sellItemsCurrentPage
    for i, request in ipairs(requests) do
        if not request then break end
        local requestWidget = g_ui.createWidget("MarketItemPanel", panel)
        local globalIndex = (serverPage - 1) * 20 + i
        requestWidget.itemNumber:setText("#"..globalIndex)
        requestWidget.item_name:setText(request.itemName)
        requestWidget.seller_name:setText(request.playerName)
        requestWidget.count:setText(request.remainingCount)
        requestWidget.item_image:setText("")
        requestWidget.item_image.item:setItemId(request.clientId)
        requestWidget.item_image.item:setTooltip(request.description)
        requestWidget.item_image.item:setPokeballName(request.pokeballType or "")
        requestWidget.price:setText("$"..formatNumberValue(request.maxPrice))
        requestWidget.itemData = {
            requestId = request.requestId,
            itemName = request.itemName,
            playerName = request.playerName,
            clientId = request.clientId,
            remainingCount = request.remainingCount,
            maxPrice = request.maxPrice,
            timeLeft = request.timeLeft,
            anonymous = request.anonymous,
            pokeballType = request.pokeballType or ""
        }
        requestWidget.timeLeft = request.timeLeft
        requestWidget.timeEndMark = currentTime + request.timeLeft
        local timeText = request.timeLeft <= 0 and "Expired" or
                string.format(
                    "%02d:%02d:%02d",
                    math.floor(request.timeLeft / (60 * 60)),
                    math.floor((request.timeLeft / 60) % 60),
                    math.floor(request.timeLeft % 60)
                )
        requestWidget.time:setText(timeText)
        local imageBackground = i % 2 == 1 and "background_2" or "background_3"
        local imageSource = "/images/newui/"..imageBackground
        local newSource = i == 1 and imageSource .."_selected" or imageSource
        requestWidget.background:setImageSource(newSource)
        requestWidget.onFocusChange = function(widget, focused)
            if focused then
                widget.background:setImageSource(imageSource.."_selected")
            else
                widget.background:setImageSource(imageSource)
            end
        end
    end
    layout:enableUpdates()
    layout:update()
    startTimeUpdateEvent()
    Market.updatePaginationControls()
end
function requestMarketCategory(id, widget)
    if widget then
        id = widget.marketId and widget.marketId or id
    end
    if not id then
        return
    end
    currentCategory = id
    if currentMarketView == "sell" then
        if g_game.sendMarketBrowseRequests then
            g_game.sendMarketBrowseRequests(id, 1, currentOrder, currentSearchText)
        else
        end
    else
        g_game.sendMarketBrowseItems(id, 1, currentOrder, currentSearchText)
    end
end
function Market.switchToSellView()
    currentMarketView = "sell"
    updateOrderForView("sell")
    updateButtonVisibility()
    if g_game.sendMarketBrowseRequests then
        g_game.sendMarketBrowseRequests(1, 1, currentOrder, currentSearchText)
    end
end
function configureMainButtons()
    if not marketWindow then
        return
    end
    local buyButton = marketWindow:getChildById("buy_button")
    if buyButton and not buyButton.onClick then
        buyButton.onClick = function()
            currentMarketView = "buy"
            updateOrderForView("buy")
            updateButtonVisibility()
            requestMarketCategory(1)
        end
    end
    local sellButton = marketWindow:getChildById("sell_button")
    if sellButton and not sellButton.onClick then
        sellButton.onClick = function()
            Market.switchToSellView()
        end
    end
    local itemsButton = marketWindow:getChildById("items_button")
    if itemsButton and not itemsButton.onClick then
        itemsButton.onClick = function()
            currentMarketView = "myitems"
            updateOrderForView("myitems")
            updateButtonVisibility()
            getMyRequests()
        end
    end
end
function Market.validateSellItem(y, z)
    if not g_game.isOnline() then
        return
    end
    g_game.sendMarketValidateSellItem(y, z)
end
function Market.onMarketValidateSellItemResponse(msg)
    local success = msg:getU8()
    if success == 1 then
        local itemName = msg:getString()
        local image = msg:getString()
        local count = msg:getU16()
        local clientId = msg:getU16()
        local pokeballType = msg:getString()
        local description = msg:getString()
        local color = msg:getString()
        local originalY = msg:getU16()
        local originalZ = msg:getU8()
        Market.fillSellPanel(itemName, image, count, pokeballType, clientId, description, originalY, originalZ)
    else
        local errorMessage = msg:getString()
        displayAllianceInfoBox(tr("Market Error"), errorMessage)
    end
end
function Market.fillSellPanel(itemName, image, count, pokeballType, clientId, description, originalY, originalZ)
    if not marketWindow then
        return
    end
    Market.resetSellPanel()
    Market.openSellConfig(itemName, image, count, pokeballType, clientId, description, originalY, originalZ)
end
function Market.openSellConfig(itemName, image, count, pokeballType, clientId, description, originalY, originalZ)
    if not marketWindow then
        return
    end
    local sellConfigPanel = marketWindow:getChildById("sellConfigPanel")
    if sellConfigPanel then
        sellConfigPanel:setVisible(true)
        local configItem = sellConfigPanel:getChildById("configSelectedItem")
        if configItem then
            configItem:setItemId(clientId)
            configItem:setItemCount(count)
            configItem:setPokeballName(pokeballType)
        end
        local configItemName = sellConfigPanel:getChildById("configItemName")
        if configItemName then
            configItemName:setText(itemName)
        end
        local quantityEdit = sellConfigPanel:getChildById("quantityEdit")
        local quantityScrollBar = sellConfigPanel:getChildById("quantityScrollBar")
        if quantityEdit then
            Market.bindQuantitySlider(quantityEdit, quantityScrollBar, Market.effectiveMaxQuantity(count), 1, Market.updateSellTotal)
            quantityEdit:focus()
        end
        local maxQuantityLabel = sellConfigPanel:getChildById("maxQuantityLabel")
        if maxQuantityLabel then
            maxQuantityLabel:setText(tr("Max: %s", Market.effectiveMaxQuantity(count)))
        end
        local priceEdit = sellConfigPanel:getChildById("priceEdit")
        if priceEdit then
            priceEdit:setText("0")
        end
        local anonymousCheckBox = sellConfigPanel:getChildById("anonymousCheckBox")
        if anonymousCheckBox then
            -- restore before wiring the handler, so restoring does not re-save
            anonymousCheckBox:setChecked(g_settings.getBoolean("marketSellAnonymous"))
            anonymousCheckBox.onCheckChange = function(_, checked)
                g_settings.set("marketSellAnonymous", checked)
                g_settings.save()
            end
        end
        Market.updateSellTotal()
        sellConfigPanel.itemData = {
            name = itemName,
            image = image,
            count = count,
            pokeballType = pokeballType,
            clientId = clientId,
            description = description,
            originalY = originalY,
            originalZ = originalZ
        }
        if priceEdit then
            priceEdit.onTextChange = function(widget)
                Market.validatePriceInput(widget)
                Market.updateSellTotal()
            end
        end
        Market.attachQuantityShortcuts(quantityEdit)
    end
end
function Market.updateSellTotal()
    if not marketWindow then
        return
    end
    local sellConfigPanel = marketWindow:getChildById("sellConfigPanel")
    if not sellConfigPanel then
        return
    end
    local quantityEdit = sellConfigPanel:getChildById("quantityEdit")
    local priceEdit = sellConfigPanel:getChildById("priceEdit")
    local totalPriceLabel = sellConfigPanel:getChildById("totalPriceLabel")
    if quantityEdit and priceEdit and totalPriceLabel then
        local quantity = quantityEdit:getValue() or 1
        local price = tonumber(priceEdit:getText()) or 0
        local total = quantity * price
        totalPriceLabel:setText(tr("Total: $%s", comma_value2(total)))
    end
end
function Market.confirmSell()
    if not marketWindow then
        return
    end
    local sellConfigPanel = marketWindow:getChildById("sellConfigPanel")
    if not sellConfigPanel or not sellConfigPanel.itemData then
        return
    end
    local quantityEdit = sellConfigPanel:getChildById("quantityEdit")
    local priceEdit = sellConfigPanel:getChildById("priceEdit")
    local anonymousCheckBox = sellConfigPanel:getChildById("anonymousCheckBox")
    if not quantityEdit or not priceEdit then
        return
    end
    local quantity = quantityEdit:getValue() or 1
    local price = tonumber(priceEdit:getText()) or 0
    local anonymous = anonymousCheckBox and anonymousCheckBox:isChecked() or false
    local itemData = sellConfigPanel.itemData
    if quantity <= 0 then
        displayAllianceInfoBox(tr("Market Error"), tr("Please enter a valid quantity greater than zero."))
        return
    end
    if quantity > itemData.count then
        displayAllianceInfoBox(tr("Insufficient Quantity"), tr("You cannot sell more than %d.", itemData.count))
        return
    end
    if price <= 0 then
        displayAllianceInfoBox(tr("Invalid Price"), tr("Please enter a valid price greater than zero."))
        return
    end
    g_game.sendMarketCreateItem(quantity, price, anonymous)
    Market.closeSellConfig()
end
function Market.onSelectItemButtonClick()
    if not marketWindow then
        return
    end
    local sellDropWindow = marketWindow:getChildById("sellDropWindow")
    if sellDropWindow then
        sellDropWindow:setVisible(true)
    end
end
function Market.onReceiveItemToSell(marketWidget, draggedWidget, mousePos)
    if not draggedWidget then
        return false
    end
    if not isItemWidget(draggedWidget) then
        return false
    end
    local item = draggedWidget:getItem()
    if not item then
        return false
    end
    local position = item:getPosition()
    if not position then
        return false
    end
    local y = position.y or 0
    local z = position.z or 0
    Market.validateSellItem(y, z)
    return true
end
-- Janelas que, abertas, SEQUESTRAM a tela do market: sao overlays centralizados que cobrem o
-- conteudo, mas o @onDrop mora na janela RAIZ (newmarket.otui:372). Sem este guard, um item solto
-- em cima do historico caia no fluxo de venda por baixo da janela que o jogador esta olhando.
--
-- As duas do proprio fluxo de venda (sellDropWindow, sellConfigPanel) ficam DE FORA de proposito:
-- elas sao o destino do arrasto, e soltar outro item com elas abertas e troca de item, nao engano.
local DROP_BLOCKING_WINDOWS = {
    'historicWindow',
    'buyConfirmWindow',
    'sellNowConfirmWindow',
    'createRequestWindow',
    'cancelOfferConfirmWindow'
}

-- Views em que soltar item para vender nao faz sentido. "myitems" (Minhas Transacoes) lista as
-- ofertas que o jogador JA tem no ar -- arrastar ali sugere mexer numa oferta existente, e o que
-- acontecia era abrir o fluxo de criar outra.
--
-- "buy" continua ACEITANDO de proposito: o comentario original do onMarketWindowDrop diz que a
-- config de venda e overlay justamente para vender sem sair da view em que se esta navegando.
local DROP_BLOCKING_VIEWS = {
    myitems = true
}

local function isDropBlocked()
    if not marketWindow then
        return false
    end
    if DROP_BLOCKING_VIEWS[currentMarketView] then
        return true
    end
    for _, windowId in ipairs(DROP_BLOCKING_WINDOWS) do
        local window = marketWindow:getChildById(windowId)
        if window and window:isVisible() then
            return true
        end
    end
    return false
end

function Market.onMarketWindowDrop(widget, draggedWidget, mousePos)
    if not isItemWidget(draggedWidget) then
        return false
    end
    if isDropBlocked() then
        return false
    end
    -- the sell config is an overlay on the window, so selling never has to leave the current view
    return Market.onReceiveItemToSell(widget, draggedWidget, mousePos)
end
function resetSellPanel()
    Market.resetSellPanel()
end
function Market.resetSellPanel()
    if not marketWindow then
        return
    end
    local sellDropWindow = marketWindow:getChildById("sellDropWindow")
    if sellDropWindow then
        sellDropWindow:setVisible(false)
    end
    local sellConfigPanel = marketWindow:getChildById("sellConfigPanel")
    if sellConfigPanel then
        sellConfigPanel:setVisible(false)
    end
end
function Market.closeSellDrop()
    if not marketWindow then
        return
    end
    local sellDropWindow = marketWindow:getChildById("sellDropWindow")
    if sellDropWindow then
        sellDropWindow:setVisible(false)
    end
end
function Market.closeSellConfig()
    if not marketWindow then
        return
    end
    local sellConfigPanel = marketWindow:getChildById("sellConfigPanel")
    if sellConfigPanel then
        sellConfigPanel:setVisible(false)
    end
end
function Market.onCreateRequestButtonClick()
    if not marketWindow then
        return
    end
    local createRequestWindow = marketWindow:getChildById("createRequestWindow")
    if createRequestWindow then
        createRequestWindow:setVisible(true)
        local createSearchPanel = createRequestWindow:getChildById("createSearchPanel")
        if createSearchPanel then
            createSearchPanel:setVisible(true)
        end
        local createSearchEdit = createRequestWindow:recursiveGetChildById("createSearchEdit")
        if createSearchEdit then
            createSearchEdit:setText("")
        end
        createSearchText = ""
        Market.loadRequestCategories()
        Market.clearRequestSelection()
        local quantityEdit = createRequestWindow:getChildById("requestQuantityEdit")
        local quantityScrollBar = createRequestWindow:getChildById("requestQuantityScrollBar")
        local priceEdit = createRequestWindow:getChildById("requestPriceEdit")
        if quantityEdit then
            Market.bindQuantitySlider(quantityEdit, quantityScrollBar, 10000, 1)
            Market.attachQuantityShortcuts(quantityEdit)
        end
        if priceEdit and not priceEdit.onTextChange then
            priceEdit.onTextChange = function(widget)
                Market.validatePriceInput(widget)
            end
        end
    end
end
function Market.loadRequestCategories()
    if not marketWindow then
        return
    end
    local createRequestWindow = marketWindow:getChildById("createRequestWindow")
    if not createRequestWindow then
        return
    end
    local categoryComboBox = createRequestWindow:getChildById("categoryComboBox")
    if categoryComboBox then
        categoryComboBox:clearOptions()
        local defaultCategoryName = nil
        for _, categoryData in ipairs(Market.categories) do
            categoryComboBox:addOption(categoryData.name)
            if not defaultCategoryName and categoryData.id ~= 1 then
                defaultCategoryName = categoryData.name
            end
        end
        defaultCategoryName = defaultCategoryName or (Market.categories[1] and Market.categories[1].name)
        categoryComboBox.onOptionChange = Market.onRequestCategoryChange
        if defaultCategoryName then
            categoryComboBox:setCurrentOption(defaultCategoryName, true)
            Market.onRequestCategoryChange(categoryComboBox, defaultCategoryName)
        end
    end
end
function Market.onRequestCategoryChange(comboBox, option)
    if not option then
        return
    end
    Market.loadRequestItems(option)
end
function Market.loadRequestItems(category, searchText)
    if not marketWindow then
        return
    end
    local createRequestWindow = marketWindow:getChildById("createRequestWindow")
    if not createRequestWindow then
        return
    end
    local itemListPanel = createRequestWindow:getChildById("itemListPanel")
    if itemListPanel then
        local layout = itemListPanel:getLayout()
        layout:disableUpdates()
        itemListPanel:destroyChildren()
        local items = Market.getItemsByCategory(category)
        local filteredItems = {}
        local search = (searchText or createSearchText or ""):lower():trim()
        if search == "" then
            filteredItems = items
        else
            for _, item in ipairs(items) do
                local itemName = item.name and item.name:lower() or ""
                if itemName:find(search, 1, true) then
                    table.insert(filteredItems, item)
                end
            end
        end
        for _, item in ipairs(filteredItems) do
            local itemWidget = g_ui.createWidget("RequestItemWidget", itemListPanel)
            if itemWidget then
                itemWidget:setId(item.id)
                itemWidget:getChildById("itemIcon"):setItemId(item.clientId)
                itemWidget:setTooltip(item.name)
                itemWidget.itemData = item
            end
        end
        layout:enableUpdates()
        layout:update()
    end
end
function Market.loadMarketItems()
    if marketItemsLoaded and marketItemsCache then
        return marketItemsCache
    end
    marketItemsCache = {}
    -- Request items from server instead of loading locally
    g_game.sendMarketRequestCreateOfferItems()
    return marketItemsCache
end
function Market.getItemsByCategory(category)
    local categories = Market.loadMarketItems()
    local key = resolveCategoryKey(category)
    local cachedItems = categories and categories[key]
    if not cachedItems then
        return {}
    end
    local items = {}
    for _, item in ipairs(cachedItems) do
        table.insert(items, {
            clientId = item.clientId,
            name = item.name,
            id = item.id
        })
    end
    return items
end

function Market.onCreateSearchTextChanged(text)
    if not marketWindow then return end
    if createSearchTimeout then
        removeEvent(createSearchTimeout)
        createSearchTimeout = nil
    end
    createSearchText = text or ""
    createSearchTimeout = scheduleEvent(function()
        Market.performCreateSearch()
    end, 500)
end

function Market.performCreateSearch()
    if not marketWindow then
        return
    end
    local createRequestWindow = marketWindow:getChildById("createRequestWindow")
    if not createRequestWindow then
        return
    end
    local categoryComboBox = createRequestWindow:getChildById("categoryComboBox")
    if categoryComboBox then
        local currentCategory = categoryComboBox:getCurrentOption()
        if currentCategory then
            if type(currentCategory) == "table" then
                currentCategory = currentCategory.text or currentCategory[1] or "All"
            end
            Market.loadRequestItems(tostring(currentCategory), createSearchText)
        end
    end
end
function Market.goToFirstPage()
    if currentMarketView == "buy" then
        Market.goToFirstBuyItemsPage()
    elseif currentMarketView == "sell" then
        Market.goToFirstSellItemsPage()
    end
end
function Market.goToPrevPage()
    if currentMarketView == "buy" then
        Market.goToPrevBuyItemsPage()
    elseif currentMarketView == "sell" then
        Market.goToPrevSellItemsPage()
    end
end
function Market.goToNextPage()
    if currentMarketView == "buy" then
        Market.goToNextBuyItemsPage()
    elseif currentMarketView == "sell" then
        Market.goToNextSellItemsPage()
    end
end
function Market.goToLastPage()
    if currentMarketView == "buy" then
        Market.goToLastBuyItemsPage()
    elseif currentMarketView == "sell" then
        Market.goToLastSellItemsPage()
    end
end
function Market.goToFirstBuyItemsPage()
    Market.goToBuyItemsPage(1)
end
function Market.goToPrevBuyItemsPage()
    if buyItemsCurrentPage > 1 then
        Market.goToBuyItemsPage(buyItemsCurrentPage - 1)
    end
end
function Market.goToNextBuyItemsPage()
    if buyItemsCurrentPage < buyItemsMaxPage then
        Market.goToBuyItemsPage(buyItemsCurrentPage + 1)
    end
end
function Market.goToLastBuyItemsPage()
    Market.goToBuyItemsPage(buyItemsMaxPage)
end
function Market.goToBuyItemsPage(page)
    if page >= 1 and page <= buyItemsMaxPage then
        if currentCategory and currentOrder then
            g_game.sendMarketBrowseItems(currentCategory, page, currentOrder, currentSearchText)
        end
    end
end
function Market.goToFirstSellItemsPage()
    Market.goToSellItemsPage(1)
end
function Market.goToPrevSellItemsPage()
    if sellItemsCurrentPage > 1 then
        Market.goToSellItemsPage(sellItemsCurrentPage - 1)
    end
end
function Market.goToNextSellItemsPage()
    if sellItemsCurrentPage < sellItemsMaxPage then
        Market.goToSellItemsPage(sellItemsCurrentPage + 1)
    end
end
function Market.goToLastSellItemsPage()
    Market.goToSellItemsPage(sellItemsMaxPage)
end
function Market.goToSellItemsPage(page)
    if page >= 1 and page <= sellItemsMaxPage then
        if currentCategory and currentOrder then
            g_game.sendMarketBrowseRequests(currentCategory, page, currentOrder, currentSearchText)
        end
    end
end
-- As setas vêm do estilo AlliancePagination, que não declara @onClick: ligar aqui evita
-- depender de um override OTUI, que falha calado. Idempotente porque a janela é criada
-- em mais de um ponto.
local function wirePagination(panel)
    if not panel or panel.paginationWired then
        return
    end
    panel.paginationWired = true
    panel:getChildById("firstPage").onClick = Market.goToFirstPage
    panel:getChildById("prevPage").onClick = Market.goToPrevPage
    panel:getChildById("nextPage").onClick = Market.goToNextPage
    panel:getChildById("lastPage").onClick = Market.goToLastPage
end

function Market.updatePaginationControls()
    if not marketWindow then
        return
    end
    local buyPaginationPanel = marketWindow.buyPaginationPanel
    local sellPaginationPanel = marketWindow.sellPaginationPanel
    wirePagination(buyPaginationPanel)
    wirePagination(sellPaginationPanel)
    if currentMarketView == "myitems" then
        if buyPaginationPanel then buyPaginationPanel:setVisible(false) end
        if sellPaginationPanel then sellPaginationPanel:setVisible(false) end
        return
    end
    local currentPage, maxPage
    local activePaginationPanel
    if currentMarketView == "buy" then
        if buyPaginationPanel then 
            buyPaginationPanel:setVisible(true)
        else
        end
        if sellPaginationPanel then sellPaginationPanel:setVisible(false) end
        currentPage = buyItemsCurrentPage
        maxPage = buyItemsMaxPage
        activePaginationPanel = buyPaginationPanel
    elseif currentMarketView == "sell" then
        if buyPaginationPanel then buyPaginationPanel:setVisible(false) end
        if sellPaginationPanel then sellPaginationPanel:setVisible(true) end
        currentPage = sellItemsCurrentPage
        maxPage = sellItemsMaxPage
        activePaginationPanel = sellPaginationPanel
    else
        if buyPaginationPanel then buyPaginationPanel:setVisible(false) end
        if sellPaginationPanel then sellPaginationPanel:setVisible(false) end
        return
    end
    if not activePaginationPanel then
        return
    end
    -- AlliancePagination dá os mesmos ids aos dois painéis, então não há caminho por view
    local pageInfo = activePaginationPanel:getChildById("pageLabel")
    local firstBtn = activePaginationPanel:getChildById("firstPage")
    local prevBtn = activePaginationPanel:getChildById("prevPage")
    local nextBtn = activePaginationPanel:getChildById("nextPage")
    local lastBtn = activePaginationPanel:getChildById("lastPage")
    if pageInfo then
        pageInfo:setText(currentPage .. "/" .. maxPage)
    end
    if firstBtn then
        firstBtn:setEnabled(currentPage > 1)
    end
    if prevBtn then
        prevBtn:setEnabled(currentPage > 1)
    end
    if nextBtn then
        nextBtn:setEnabled(currentPage < maxPage)
    end
    if lastBtn then
        lastBtn:setEnabled(currentPage < maxPage)
    end
end
function Market.clearRequestSelection()
    if not marketWindow then
        return
    end
    local createRequestWindow = marketWindow:getChildById("createRequestWindow")
    if createRequestWindow then
        local quantityEdit = createRequestWindow:getChildById("requestQuantityEdit")
        local priceEdit = createRequestWindow:getChildById("requestPriceEdit")
        if quantityEdit then quantityEdit:setValue(1) end
        if priceEdit then priceEdit:setText("0") end
    end
end
function Market.confirmCreateRequest()
    if not marketWindow then
        return
    end
    local createRequestWindow = marketWindow:getChildById("createRequestWindow")
    local child = createRequestWindow and createRequestWindow.itemListPanel and createRequestWindow.itemListPanel:getFocusedChild()
    if not child or not child.itemData then
        displayAllianceInfoBox(tr("No Item Selected"), tr("Please select an item to create a buy request."))
        return
    end
    local quantityEdit = createRequestWindow:getChildById("requestQuantityEdit")
    local priceEdit = createRequestWindow:getChildById("requestPriceEdit")
    if not quantityEdit or not priceEdit then
        return
    end
    local quantity = quantityEdit:getValue() or 1
    local maxPrice = tonumber(priceEdit:getText()) or 0
    local selectedItem = child.itemData
    if quantity <= 0 then
        displayAllianceInfoBox(tr("Invalid Quantity"), tr("Please enter a valid quantity greater than zero."))
        return
    end
    if maxPrice <= 0 then
        displayAllianceInfoBox(tr("Invalid Price"), tr("Please enter a valid maximum price greater than zero gold."))
        return
    end
    g_game.sendMarketCreateRequest(selectedItem.id, maxPrice, quantity, false)
end
function Market.onBuyNowButtonClick()
    if not marketWindow then
        return
    end
    local selectedMarketItem = Market.getSelectedMarketItem()
    if not selectedMarketItem then
        displayAllianceInfoBox(tr("No Item Selected"), tr("Please select an item from the market to purchase."))
        return
    end
    local buyConfirmWindow = marketWindow:getChildById("buyConfirmWindow")
    if buyConfirmWindow then
        buyConfirmWindow:setVisible(true)
        Market.setupBuyConfirmWindow(selectedMarketItem)
    end
end
function Market.setupBuyConfirmWindow(itemData)
    if not marketWindow then
        return
    end
    local buyConfirmWindow = marketWindow:getChildById("buyConfirmWindow")
    if not buyConfirmWindow then
        return
    end
    buyConfirmWindow.itemData = itemData
    local buyConfirmItem = buyConfirmWindow:getChildById("buyConfirmItem")
    if buyConfirmItem and itemData.clientId then
        buyConfirmItem:setItemId(itemData.clientId)
        buyConfirmItem:setItemCount(itemData.count or 1)
        buyConfirmItem:setPokeballName(itemData.pokeballType)
    end
    local buyConfirmItemName = buyConfirmWindow:getChildById("buyConfirmItemName")
    if buyConfirmItemName then
        buyConfirmItemName:setText(itemData.item_name or tr("Unknown Item"))
    end
    local buyConfirmQuantityEdit = buyConfirmWindow:getChildById("buyConfirmQuantityEdit")
    local buyConfirmQuantityScrollBar = buyConfirmWindow:getChildById("buyConfirmQuantityScrollBar")
    if buyConfirmQuantityEdit then
        Market.bindQuantitySlider(buyConfirmQuantityEdit, buyConfirmQuantityScrollBar, Market.effectiveMaxQuantity(itemData.count), 1, Market.updateBuyTotal)
        Market.attachQuantityShortcuts(buyConfirmQuantityEdit)
    end
    local alertLevel = Market.getPriceAlertLevel(itemData)
    local buyConfirmPriceValue = buyConfirmWindow:getChildById("buyConfirmPriceValue")
    if buyConfirmPriceValue then
        buyConfirmPriceValue:setText("$"..comma_value2(itemData.price or 0))
        buyConfirmPriceValue:setColor(alertLevel == "above" and "#ff5555" or "#00ff00")
        buyConfirmPriceValue:setTooltip(Market.getPriceStatsTooltip(itemData))
    end
    -- Alerta de preço: só quando há média real e o preço está acima dela; média 0 /
    -- sem histórico é neutro (não alerta). Compra continua permitida.
    local buyConfirmPriceAlert = buyConfirmWindow:getChildById("buyConfirmPriceAlert")
    if buyConfirmPriceAlert then
        if alertLevel == "above" then
            local pctAbove = math.floor(((itemData.price / itemData.avg30) - 1) * 100)
            buyConfirmPriceAlert:setText(tr("Warning: price %d%% above the 30-day average of $%s (min $%s / max $%s).",
                pctAbove, comma_value2(itemData.avg30), comma_value2(itemData.min30), comma_value2(itemData.max30)))
            buyConfirmPriceAlert:setVisible(true)
        else
            buyConfirmPriceAlert:setVisible(false)
        end
    end
    Market.updateBuyTotal()
end
function Market.updateBuyTotal()
    if not marketWindow then
        return
    end
    local buyConfirmWindow = marketWindow:getChildById("buyConfirmWindow")
    if not buyConfirmWindow or not buyConfirmWindow.itemData then
        return
    end
    local buyConfirmQuantityEdit = buyConfirmWindow:getChildById("buyConfirmQuantityEdit")
    local buyConfirmTotalLabel = buyConfirmWindow:getChildById("buyConfirmTotalLabel")
    if buyConfirmQuantityEdit and buyConfirmTotalLabel then
        local quantity = buyConfirmQuantityEdit:getValue() or 1
        local pricePerUnit = buyConfirmWindow.itemData.price or 0
        local total = quantity * pricePerUnit
        buyConfirmTotalLabel:setText(tr("Total: $%s", comma_value2(total)))
    end
end
function Market.getSelectedMarketItem()
    if not marketWindow then
        return nil
    end
    local categoryBackground = marketWindow:getChildById("categoryBackground")
    if not categoryBackground then
        return nil
    end
    local itemArea = categoryBackground:getChildById("itemArea")
    if not itemArea then
        return nil
    end
    local focusedChild = itemArea:getFocusedChild()
    if not focusedChild then
        return nil
    end
    if focusedChild.itemData then
        return focusedChild.itemData
    end
    return nil
end
function Market.closeBuyConfirm()
    if not marketWindow then
        return
    end
    local buyConfirmWindow = marketWindow:getChildById("buyConfirmWindow")
    if buyConfirmWindow then
        buyConfirmWindow:setVisible(false)
        buyConfirmWindow.itemData = nil
    end
end
function Market.confirmBuyNow()
    if not marketWindow then
        return
    end
    local buyConfirmWindow = marketWindow:getChildById("buyConfirmWindow")
    if not buyConfirmWindow or not buyConfirmWindow.itemData then
        return
    end
    local buyConfirmQuantityEdit = buyConfirmWindow:getChildById("buyConfirmQuantityEdit")
    if not buyConfirmQuantityEdit then
        return
    end
    local quantity = buyConfirmQuantityEdit:getValue() or 1
    local itemData = buyConfirmWindow.itemData
    if quantity <= 0 then
        displayAllianceInfoBox(tr("Invalid Quantity"), tr("Please enter a valid quantity greater than zero."))
        return
    end
    if quantity > itemData.count then
        displayAllianceInfoBox(tr("Insufficient Stock"), tr("Only %d units available for purchase.", itemData.count))
        return
    end
    if not itemData.itemCode then
        return
    end
    g_game.sendMarketBuyItem(itemData.itemCode, quantity)
    Market.closeBuyConfirm()
end
function receiveItemToSell(msg)
    Market.onMarketValidateSellItemResponse(msg)
end
function Market.onSellNowButtonClick()
    if not marketWindow then
        return
    end
    local selectedRequest = Market.getSelectedRequest()
    if not selectedRequest then
        displayAllianceInfoBox(tr("No Request Selected"), tr("Please select a buy request to fulfill."))
        return
    end
    local sellNowConfirmWindow = marketWindow:getChildById("sellNowConfirmWindow")
    if sellNowConfirmWindow then
        sellNowConfirmWindow:setVisible(true)
        Market.setupSellNowConfirmWindow(selectedRequest)
    end
end
function Market.getSelectedRequest()
    if not marketWindow then
        return nil
    end
    local categoryBackground = marketWindow:getChildById("categoryBackground")
    if not categoryBackground then
        return nil
    end
    local itemArea = categoryBackground:getChildById("itemArea")
    if not itemArea then
        return nil
    end
    local focusedChild = itemArea:getFocusedChild()
    if not focusedChild then
        return nil
    end
    if focusedChild.itemData then
        return focusedChild.itemData
    end
    return nil
end
function Market.setupSellNowConfirmWindow(requestData)
    if not marketWindow then
        return
    end
    local sellNowConfirmWindow = marketWindow:recursiveGetChildById("sellNowConfirmWindow")
    if not sellNowConfirmWindow then
        return
    end
    sellNowConfirmWindow.requestData = requestData
    local sellNowConfirmItem = sellNowConfirmWindow:recursiveGetChildById("sellNowConfirmItem")
    if sellNowConfirmItem and requestData.clientId then
        sellNowConfirmItem:setItemId(requestData.clientId)
    end
    local sellNowConfirmItemName = sellNowConfirmWindow:recursiveGetChildById("sellNowConfirmItemName")
    if sellNowConfirmItemName then
        sellNowConfirmItemName:setText(requestData.itemName or tr("Unknown Item"))
    end
    local sellNowConfirmQuantityEdit = sellNowConfirmWindow:recursiveGetChildById("sellNowConfirmQuantityEdit")
    local sellNowConfirmQuantityScrollBar = sellNowConfirmWindow:recursiveGetChildById("sellNowConfirmQuantityScrollBar")
    if sellNowConfirmQuantityEdit then
        local maxV = Market.effectiveMaxQuantity(requestData.remainingCount)
        Market.bindQuantitySlider(sellNowConfirmQuantityEdit, sellNowConfirmQuantityScrollBar, maxV, maxV, Market.updateSellNowTotal)
        Market.attachQuantityShortcuts(sellNowConfirmQuantityEdit)
    end
    local sellNowConfirmPriceValue = sellNowConfirmWindow:recursiveGetChildById("sellNowConfirmPriceValue")
    if sellNowConfirmPriceValue then
        sellNowConfirmPriceValue:setText("$"..comma_value2(requestData.maxPrice or 0))
    end
    Market.updateSellNowTotal()
end
function Market.updateSellNowTotal()
    if not marketWindow then
        return
    end
    local sellNowConfirmWindow = marketWindow:recursiveGetChildById("sellNowConfirmWindow")
    if not sellNowConfirmWindow or not sellNowConfirmWindow.requestData then
        return
    end
    local sellNowConfirmQuantityEdit = sellNowConfirmWindow:recursiveGetChildById("sellNowConfirmQuantityEdit")
    local sellNowConfirmTotalLabel = sellNowConfirmWindow:recursiveGetChildById("sellNowConfirmTotalLabel")
    if sellNowConfirmQuantityEdit and sellNowConfirmTotalLabel then
        local quantity = sellNowConfirmQuantityEdit:getValue() or 1
        local pricePerUnit = sellNowConfirmWindow.requestData.maxPrice or 0
        local totalPrice = pricePerUnit * quantity
        sellNowConfirmTotalLabel:setText(tr("Total: $%s", comma_value2(totalPrice)))
    end
end
function Market.closeSellNowConfirm()
    if not marketWindow then
        return
    end
    local sellNowConfirmWindow = marketWindow:recursiveGetChildById("sellNowConfirmWindow")
    if sellNowConfirmWindow then
        sellNowConfirmWindow:setVisible(false)
        sellNowConfirmWindow.requestData = nil
    end
end
function Market.confirmSellNow()
    if not marketWindow then
        return
    end
    local sellNowConfirmWindow = marketWindow:recursiveGetChildById("sellNowConfirmWindow")
    if not sellNowConfirmWindow then
        return
    end
    if not sellNowConfirmWindow.requestData then
        return
    end
    local sellNowConfirmQuantityEdit = sellNowConfirmWindow:recursiveGetChildById("sellNowConfirmQuantityEdit")
    if not sellNowConfirmQuantityEdit then
        return
    end
    local quantity = sellNowConfirmQuantityEdit:getValue() or 1
    local requestData = sellNowConfirmWindow.requestData
    if quantity <= 0 then
        displayAllianceInfoBox(tr("Invalid Quantity"), tr("Please enter a valid quantity greater than zero."))
        return
    end
    if quantity > requestData.remainingCount then
        displayAllianceInfoBox(tr("Exceeds Request"), tr("Maximum quantity available: %d", requestData.remainingCount))
        return
    end
    if not requestData.requestId then
        displayAllianceInfoBox(tr("Invalid Request"), tr("Request ID not found."))
        return
    end
    g_game.sendMarketRespondRequest(requestData.requestId, requestData.clientId, quantity)
    Market.closeSellNowConfirm()
    scheduleEvent(function()
        if currentMarketView == "sell" then
            requestMarketCategory(currentCategory)
        end
    end, 1000)
end
function setupMyItemsHeaders()
    if not marketWindow then
        return
    end
    local sellTitlePanel = marketWindow.sellItemsBackground.sellTitlePanelBackground
    if sellTitlePanel then
        sellTitlePanel.itemNumber:setText("#")
        sellTitlePanel.item_image:setText(tr("Item"))
        sellTitlePanel.item_name:setText(tr("Name"))
        sellTitlePanel.count:setText(tr("Count"))
        sellTitlePanel.price:setText(tr("Price"))
        sellTitlePanel.time:setText(tr("Time"))
        sellTitlePanel.actions.actionsLabel:setVisible(true)
        sellTitlePanel.actions.cancelButton:setVisible(false)
    end
    local requestsTitlePanel = marketWindow.buyRequestsBackground.requestsTitlePanelBackground
    if requestsTitlePanel then
        requestsTitlePanel.itemNumber:setText("#")
        requestsTitlePanel.item_image:setText(tr("Item"))
        requestsTitlePanel.item_name:setText(tr("Name"))
        requestsTitlePanel.count:setText(tr("Count"))
        requestsTitlePanel.price:setText(tr("Price"))
        requestsTitlePanel.time:setText(tr("Time"))
        requestsTitlePanel.actions.actionsLabel:setVisible(true)
        requestsTitlePanel.actions.cancelButton:setVisible(false)
    end
end
function Market.closeCreateRequest()
    if marketWindow then
        local createRequestWindow = marketWindow:getChildById("createRequestWindow")
        if createRequestWindow then
            createRequestWindow:setVisible(false)
        end
    end
end
local function formatHistoricTime(timestamp)
    if timestamp <= 0 then
        return "N/A"
    end
    local dateTable = os.date("*t", timestamp)
    if dateTable then
        return string.format("%02d/%02d/%04d %02d:%02d", 
            dateTable.day, dateTable.month, dateTable.year,
            dateTable.hour, dateTable.min)
    end
    return tr("Invalid date")
end
local function formatPrice(price)
    if price >= 1000000000 then
        return string.format("%.1fB", price / 1000000000)
    elseif price >= 1000000 then
        return string.format("%.1fM", price / 1000000)
    elseif price >= 1000 then
        return string.format("%.1fK", price / 1000)
    else
        return tostring(price)
    end
end
function Market.showHistoricWindow(historicData)
    if not marketWindow then
        return
    end
    local historicWindow = marketWindow:getChildById("historicWindow")
    if not historicWindow then
        return
    end
    local historicListPanel = historicWindow:recursiveGetChildById("historicListPanel")
    if not historicListPanel then
        return
    end
    historicListPanel:destroyChildren()
    if #historicData == 0 then
        local emptyLabel = g_ui.createWidget("PoppinsSemibold14", historicListPanel)
        emptyLabel:setText(tr("No transactions found in your history."))
        emptyLabel:setTextAlign(AlignCenter)
        emptyLabel:setHeight(40)
        emptyLabel:setMarginTop(20)
    else
        for i, entry in ipairs(historicData) do
            local entryWidget = g_ui.createWidget("HistoricLabel", historicListPanel)            
            local transactionType = entry.isBuyer and "bought" or "sold"
            local priceFormatted = formatPrice(entry.price)
            local timeFormatted = formatHistoricTime(entry.time)
            local entryText = string.format(
                "%s - You have %s %d %s by $%s each.",
                timeFormatted, transactionType, entry.itemCount, entry.itemName, priceFormatted
            )
            entryWidget:setText(entryText)
            if i % 2 == 0 then
                entryWidget:setBackgroundColor("#00000033")
            else
                entryWidget:setBackgroundColor("#00000053")
            end
        end
    end
    historicWindow:setVisible(true)
    historicWindow:raise()
    historicWindow:focus()
end
function Market.closeHistoric()
    if marketWindow then
        local historicWindow = marketWindow:getChildById("historicWindow")
        if historicWindow then
            historicWindow:setVisible(false)
        end
    end
end
function Market.onMarketCloseCreateRequest()
    Market.closeCreateRequest()
end
function Market.validateNumericInput(widget, allowDecimal, maxValue)
    if not widget then return end
    local text = widget:getText()
    local filteredText = ""
    for i = 1, #text do
        local char = text:sub(i, i)
        if char:match("%d") or (allowDecimal and char == "." and not filteredText:find("%.")) then
            filteredText = filteredText .. char
        end
    end
    if filteredText ~= "" and filteredText ~= "0" then
        filteredText = filteredText:gsub("^0+", "")
        if filteredText == "" then
            filteredText = "0"
        end
    end
    if maxValue and filteredText ~= "" and tonumber(filteredText) then
        if tonumber(filteredText) > maxValue then
            filteredText = tostring(maxValue)
        end
    end
    if text ~= filteredText then
        widget:setText(filteredText)
    end
end
function Market.validatePriceInput(widget)
    Market.validateNumericInput(widget, false, 99999999999999)
end
function Market.effectiveMaxQuantity(maxSource)
    return math.min(tonumber(maxSource) or 1, 10000)
end
function Market.attachQuantityShortcuts(spin)
    if not spin or spin.quantityShortcutsBound then return end
    spin.quantityShortcutsBound = true
    g_keyboard.bindKeyPress('Up', function() spin:setValue(spin:getValue() + 1); return true end, spin)
    g_keyboard.bindKeyPress('Down', function() spin:setValue(spin:getValue() - 1); return true end, spin)
    g_keyboard.bindKeyPress('Shift+Up', function() spin:setValue(spin:getMaximum()); return true end, spin)
    g_keyboard.bindKeyPress('Shift+Right', function() spin:setValue(spin:getMaximum()); return true end, spin)
    g_keyboard.bindKeyPress('Shift+Down', function() spin:setValue(spin:getMinimum()); return true end, spin)
    g_keyboard.bindKeyPress('Shift+Left', function() spin:setValue(spin:getMinimum()); return true end, spin)
end
function Market.bindQuantitySlider(spin, scrollBar, maxValue, value, onChange)
    value = math.min(math.max(value or 1, 1), maxValue)
    if spin then
        spin:setMinimum(1)
        spin:setMaximum(maxValue)
        spin:setStep(1)
        spin:hideButtons()
        spin:setValue(value)
    end
    if scrollBar then
        scrollBar:setMinimum(1)
        scrollBar:setMaximum(maxValue)
        scrollBar:setValue(value)
        scrollBar.onValueChange = function(self, v)
            if spin then spin:setValue(v) end
            if onChange then onChange() end
        end
    end
    if spin then
        spin.onValueChange = function(self, v)
            if scrollBar then scrollBar:setValue(v) end
            if onChange then onChange() end
        end
    end
end
function Market.onSellMaxClicked()
    if not marketWindow then return end
    local sellConfigPanel = marketWindow:getChildById("sellConfigPanel")
    if not sellConfigPanel then return end
    local spin = sellConfigPanel:getChildById("quantityEdit")
    if spin then spin:setValue(spin:getMaximum()) end
    Market.updateSellTotal()
end

onSellMaxClicked = Market.onSellMaxClicked
closeSellDrop = Market.closeSellDrop
closeSellConfig = Market.closeSellConfig  
confirmSell = Market.confirmSell
onReceiveItemToSell = Market.onReceiveItemToSell
onMarketWindowDrop = Market.onMarketWindowDrop
onSelectItemButtonClick = Market.onSelectItemButtonClick
onCreateRequestButtonClick = Market.onCreateRequestButtonClick
closeCreateRequest = Market.closeCreateRequest
confirmCreateRequest = Market.confirmCreateRequest
onMarketCloseCreateRequest = Market.onMarketCloseCreateRequest
onBuyNowButtonClick = Market.onBuyNowButtonClick
closeBuyConfirm = Market.closeBuyConfirm
confirmBuyNow = Market.confirmBuyNow
onSellNowButtonClick = Market.onSellNowButtonClick
closeSellNowConfirm = Market.closeSellNowConfirm
confirmSellNow = Market.confirmSellNow
showHistoricWindow = Market.showHistoricWindow
closeHistoric = Market.closeHistoric
goToFirstPage = Market.goToFirstPage
goToPrevPage = Market.goToPrevPage
goToNextPage = Market.goToNextPage
goToLastPage = Market.goToLastPage
onSearchTextChanged = Market.onSearchTextChanged
performSearch = Market.performSearch
clearSearch = Market.clearSearch
getCurrentSearchText = Market.getCurrentSearchText
refreshCurrentView = Market.refreshCurrentView
recalculateItemNumbers = Market.recalculateItemNumbers
onCreateSearchTextChanged = Market.onCreateSearchTextChanged
performCreateSearch = Market.performCreateSearch