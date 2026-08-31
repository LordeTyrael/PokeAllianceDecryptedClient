local changeHeldWindow = nil
local changeHeldPanel = nil
local quantityWindow = nil
local selectedOption = nil
local cachedOptions = {}
local tierCycleEvent = nil
local tierCycleCards = {}  -- list of { tierWidgets = {icon, ...}, tiers = {tierClientId, ...}, currentIndex = N }

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = close,
        onAutoWalk = close,
        onHeldExchange = onHeldExchange
    })
end

function stopTierCycle()
    if tierCycleEvent then
        tierCycleEvent:cancel()
        tierCycleEvent = nil
    end
    tierCycleCards = {}
end

local function cycleTierItems()
    for _, entry in ipairs(tierCycleCards) do
        if #entry.tiers > 1 then
            entry.currentIndex = (entry.currentIndex % #entry.tiers) + 1
            local tierClientId = entry.tiers[entry.currentIndex]
            for _, iconWidget in ipairs(entry.tierWidgets) do
                if iconWidget and not iconWidget:isDestroyed() then
                    iconWidget:setItemId(tierClientId)
                end
            end
        end
    end
end

function startTierCycle()
    -- Only cancel the event, don't clear tierCycleCards (they were just populated)
    if tierCycleEvent then
        tierCycleEvent:cancel()
        tierCycleEvent = nil
    end
    if #tierCycleCards > 0 then
        tierCycleEvent = cycleEvent(cycleTierItems, 1000)
    end
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = close,
        onAutoWalk = close,
        onHeldExchange = onHeldExchange
    })
    close()
    cachedOptions = {}
end

function onGameEnd()
    close()
end

function close()
    closeQuantityWindow()
    stopTierCycle()
    if changeHeldWindow then
        g_uistates.remove(changeHeldWindow)
        changeHeldWindow:destroy()
        changeHeldWindow = nil
        changeHeldPanel = nil
    end
end

local function populateBottomBar(options)
    local bottomPanel = changeHeldWindow:recursiveGetChildById("bottomItemsPanel")
    if not bottomPanel then return end
    bottomPanel:destroyChildren()

    -- Collect unique items by clientId
    local itemMap = {}
    local itemOrder = {}
    for _, option in ipairs(options) do
        local cid = option.clientId
        if not itemMap[cid] then
            itemMap[cid] = { clientId = cid }
            table.insert(itemOrder, cid)
        end
    end

    for _, cid in ipairs(itemOrder) do
        local info = itemMap[cid]
        local player = g_game.getLocalPlayer()
        local playerCount = player and player:getItemCount(info.clientId) or 0
        local w = g_ui.createWidget("HeldBottomItem", bottomPanel)
        local icon = w:recursiveGetChildById("icon")
        if icon then
            icon:setItemId(info.clientId)
        end
        local countLabel = w:recursiveGetChildById("countLabel")
        if countLabel then
            countLabel:setText(playerCount.."x")
        end
    end
end

local function buildCard(option)
    local card = g_ui.createWidget("HeldExchangeCard", changeHeldPanel)

    -- Compute tier range for title
    local minTier, maxTier = nil, nil
    for _, tier in ipairs(option.tiers or {}) do
        local t = tier.itemTier or 0
        if t > 0 then
            if not minTier or t < minTier then minTier = t end
            if not maxTier or t > maxTier then maxTier = t end
        end
    end

    local cardTitle = card:recursiveGetChildById("cardTitle")
    if cardTitle then
        local titleText = option.itemName
        if minTier and maxTier then
            titleText = titleText .. "\n(Tier " .. minTier .. "-" .. maxTier .. ")"
        end
        cardTitle:setText(titleText)
    end

    local exchangeRow = card:recursiveGetChildById("exchangeRow")
    if exchangeRow then
        -- Input item
        local inputItem = g_ui.createWidget("HeldExchangeItemIcon", exchangeRow)
        local inputIcon = inputItem:recursiveGetChildById("icon")
        if inputIcon then
            inputIcon:setItemId(option.clientId)
            inputIcon:setItemCount(option.requiredCount)
        end

        -- Arrow
        g_ui.createWidget("HeldArrowIcon", exchangeRow)

        -- Collect unique tier clientIds
        local tierClientIds = {}
        local seenTier = {}
        for _, tier in ipairs(option.tiers or {}) do
            if tier.tierClientId and tier.tierClientId > 0 and not seenTier[tier.tierClientId] then
                seenTier[tier.tierClientId] = true
                table.insert(tierClientIds, tier.tierClientId)
            end
        end

        -- Create a single output widget that cycles between possible tier items
        local firstTierClientId = tierClientIds[1] or option.clientId
        local tierItem = g_ui.createWidget("HeldExchangeItemIcon", exchangeRow)
        local tierIcon = tierItem:recursiveGetChildById("icon")
        if tierIcon then
            tierIcon:setItemId(firstTierClientId)
            tierIcon:setItemCount(1)
        end

        -- Register for cycling if multiple unique tiers exist
        if #tierClientIds > 1 and tierIcon then
            table.insert(tierCycleCards, {
                tierWidgets = { tierIcon },
                tiers = tierClientIds,
                currentIndex = 1
            })
        end
    end

    local exchangeButton = card:recursiveGetChildById("exchangeButton")
    if exchangeButton then
        exchangeButton.onClick = function()
            openQuantityWindow(option)
        end
    end

    return card
end

function applyFilters()
    if not changeHeldPanel or not changeHeldWindow then return end

    stopTierCycle()
    changeHeldPanel:destroyChildren()

    local searchEdit = changeHeldWindow:getChildById("searchEdit")
    local searchText = ""
    if searchEdit then
        searchText = searchEdit:getText():lower()
    end

    for _, option in ipairs(cachedOptions) do
        local matchesSearch = searchText == "" or option.itemName:lower():find(searchText, 1, true)
        if matchesSearch then
            buildCard(option)
        end
    end

    startTierCycle()
end

function onHeldExchange(options)
    -- Destroy previous window if it exists
    close()

    cachedOptions = options

    changeHeldWindow = g_ui.loadUI('changeheld', modules.game_interface.getRootPanel())
    changeHeldPanel = changeHeldWindow:getChildById("changeHeldPanel")

    local searchEdit = changeHeldWindow:getChildById("searchEdit")
    if searchEdit then
        searchEdit.onTextChange = function() applyFilters() end
    end

    populateBottomBar(options)
    applyFilters()

    changeHeldWindow:show()
    changeHeldWindow:raise()
    changeHeldWindow:focus()
    g_uistates.push(changeHeldWindow)
end

function openQuantityWindow(option)
    closeQuantityWindow()

    local player = g_game.getLocalPlayer()
    local playerCount = player and player:getItemCount(option.clientId) or 0

    local maxExchanges = math.min(100, math.max(1, math.floor(playerCount / math.max(1, option.requiredCount))))

    selectedOption = option

    quantityWindow = g_ui.loadUI('quantitywindow', modules.game_interface.getRootPanel())
    if not quantityWindow then
        return
    end

    quantityWindow:getChildById("quantityTitle"):setText(option.itemName)
    local item = quantityWindow:getChildById("quantityItem")
    item:setItemId(option.clientId)
    item:setItemCount(option.requiredCount)

    local spinbox = quantityWindow.quantitySpinner.field

    spinbox.onValueChange = function(self, value)
        item:setItemCount(option.requiredCount * value)
    end
    spinbox:setMinimum(1)
    spinbox:setMaximum(maxExchanges)
    spinbox:setValue(1)
    spinbox:focus()

    quantityWindow:show()
    quantityWindow:raise()
    quantityWindow:focus()
    g_uistates.push(quantityWindow)
end

function closeQuantityWindow()
    if quantityWindow then
        g_uistates.remove(quantityWindow)
        quantityWindow:destroy()
        quantityWindow = nil
    end
    selectedOption = nil
end

function confirmExchange()
    if not quantityWindow or not selectedOption then
        return
    end

    local amount = quantityWindow.quantitySpinner.field:getValue()

    g_game.heldExchange(selectedOption.index, amount)
    closeQuantityWindow()
end