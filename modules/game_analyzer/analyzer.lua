local analyzerWindow = nil
local playerExperience = nil
local analyzerTopButton = nil
-- Session clock: sessionBegin is the wall-clock start (export metadata), sessionElapsed the
-- accumulated running seconds, sessionResumedAt the start of the current running segment (nil while paused).
local sessionBegin = os.time()
local sessionElapsed = 0
local sessionResumedAt = os.time()
local sessionStarted = false
local totalExperience = 0

local function startSessionClock()
    sessionBegin = os.time()
    sessionElapsed = 0
    sessionResumedAt = nil
    if not g_game.isAnalyzerPaused() then
        sessionResumedAt = os.time()
    end
end

-- Detail window state
local detailsWindow = nil
local currentTab = 'loot'
local currentPage = 1
local ENTRIES_PER_PAGE = 8
local GMT_OFFSET = -3 * 3600
local detailDrops = {}
local detailPage = 1
local DETAIL_PER_PAGE = 50
local pendingDetailsRedraw = nil
local detailsDirty = false
-- Sort state: 'none', 'asc', 'desc'
local damageSortField = 'none'
local damageSortOrder = 'none'
local resetConfirmWindow = nil

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onAnalyzerInfoChange = onAnalyzerInfoChange,
        onAnalyzerCreatureLooktype = onAnalyzerCreatureLooktype
    })
    connect(LocalPlayer, {
        onExperienceChange = onExperienceChange
    })

    analyzerWindow = g_ui.loadUI('analyzer', modules.game_interface.getRightPanel())
    analyzerWindow:setup()
    DockableWindow.register(analyzerWindow, {buildMenu = function(menu) buildExportMenu(menu) end})

    startSessionClock()
    updatePauseButton()

    local restoredOpen = analyzerWindow:isExplicitlyVisible()
    analyzerTopButton = modules.client_topmenu.addMiddleGameToggleButton('analyzerTopButton', tr('Analyzer') .. '', '/images/ui/topbuttons/icons/analyzer', toggle)
    analyzerTopButton:setOn(restoredOpen)
    if restoredOpen then
        syncAnalyzerTime()
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onAnalyzerInfoChange = onAnalyzerInfoChange,
        onAnalyzerCreatureLooktype = onAnalyzerCreatureLooktype
    })
    disconnect(LocalPlayer, {
        onExperienceChange = onExperienceChange
    })
    if pendingDetailsRedraw then
        removeEvent(pendingDetailsRedraw)
        pendingDetailsRedraw = nil
    end
    detailsDirty = false
    if detailsWindow then
        detailsWindow:destroy()
        detailsWindow = nil
    end
    closeResetConfirm()
    if analyzerWindow then
        if analyzerWindow.event then
            removeEvent(analyzerWindow.event)
            analyzerWindow.event = nil
        end
        analyzerWindow:destroy()
        analyzerWindow = nil
    end
end

function toggle()
    if analyzerTopButton:isOn() then
        onAnalyzerClose()
    else
        openAnalyzer()
    end
end

function openAnalyzer()
    if analyzerWindow then
        analyzerWindow:open()
        analyzerTopButton:setOn(true)
        syncAnalyzerTime()
        drawAnalyzerInfo()
        updatePauseButton()
    end
end

function getSessionSeconds()
    local running = sessionResumedAt and math.max(0, os.time() - sessionResumedAt) or 0
    return sessionElapsed + running
end

function toggleAnalyzerPause()
    setAnalyzerPaused(not g_game.isAnalyzerPaused())
end

function setAnalyzerPaused(paused)
    if paused == g_game.isAnalyzerPaused() then return end

    if paused then
        sessionElapsed = getSessionSeconds()
        sessionResumedAt = nil
    else
        sessionResumedAt = os.time()
    end

    g_game.setAnalyzerPaused(paused)
    updatePauseButton()
    syncAnalyzerTime()
end

function updatePauseButton()
    if not analyzerWindow then return end

    local paused = g_game.isAnalyzerPaused()
    local button = analyzerWindow.controls.pauseInfo
    button:setIcon(paused and '@fa solid 14 f04b' or '@fa solid 14 f04c')
    button:setIconColor(paused and '#3fcc59' or '#f5c542')
    button:setTooltip(paused and tr('Resume Analyzer') or tr('Pause Analyzer'))
    analyzerWindow.session.value:setColor(paused and '#f5c542' or '#ffffff')
end

function onAnalyzerClose()
    if analyzerWindow then
        analyzerWindow:close()
    end
    if analyzerTopButton then
        analyzerTopButton:setOn(false)
    end
    if analyzerWindow and analyzerWindow.event then
        removeEvent(analyzerWindow.event)
        analyzerWindow.event = nil
    end
end

function onAnalyzerInfoChange(type, value, name)
    drawAnalyzerInfo()
    scheduleDetailsRedraw()

    -- Request looktype for new damage creatures
    if type == 1 and name and name ~= '' then
        g_game.requestAnalyzerCreatureLooktype(name)
    end
end

function onAnalyzerCreatureLooktype(name, lookType)
    scheduleDetailsRedraw()
end

function scheduleDetailsRedraw()
    detailsDirty = true
    if pendingDetailsRedraw then return end
    pendingDetailsRedraw = scheduleEvent(function()
        pendingDetailsRedraw = nil
        if detailsDirty then
            detailsDirty = false
            drawDetailsContent()
        end
    end, 200)
end

function syncAnalyzerTime()
    if analyzerWindow then
        if analyzerWindow.event then
            removeEvent(analyzerWindow.event)
            analyzerWindow.event = nil
        end

        local passedTime = getSessionSeconds()
        analyzerWindow.session.value:setText(string.format(
                    "%02d:%02d:%02d",
                    math.floor(passedTime / (60 * 60)),
                    math.floor((passedTime / 60) % 60),
                    math.floor(passedTime % 60)
                ))

        if sessionResumedAt then
            analyzerWindow.event = scheduleEvent(syncAnalyzerTime, 1000)
        end
    end
end

function drawAnalyzerInfo()
    local analyzerInfo = g_game.getAnalyzerInfo()
    if analyzerWindow and analyzerInfo then
        local layout = analyzerWindow:getLayout()
        layout:disableUpdates()

        setAbbreviatedNumber(analyzerWindow.totalExperience.value, totalExperience)
        setAbbreviatedNumber(analyzerWindow.loot.value, analyzerInfo.loot, "$")
        setAbbreviatedNumber(analyzerWindow.spent.value, analyzerInfo.spent, "$")
        setAbbreviatedNumber(analyzerWindow.totalDamage.value, analyzerInfo.totalDamage)
        local profit = analyzerInfo.loot - analyzerInfo.spent
        local displayProfit = math.abs(profit) -- Exibe sempre o valor positivo
        setAbbreviatedNumber(analyzerWindow.balance.value, displayProfit, "$")
        local color = "#3fcc59"
        if profit < 0 then
            color = "#c92626"
        end
        
        analyzerWindow.balance.value:setColor(color)

        layout:enableUpdates()
        layout:update()
    end
end

function closeResetConfirm()
    if resetConfirmWindow then
        resetConfirmWindow:destroy()
        resetConfirmWindow = nil
    end
end

function confirmResetAnalyzerInfo()
    closeResetConfirm()

    local confirm = function()
        closeResetConfirm()
        resetAnalyzerInfo()
    end

    resetConfirmWindow = displayAllianceBox(tr('Reset Analyzer'),
        tr('Are you sure you want to reset the analyzer? All session data will be lost.'), {
            { text = tr('Yes'), callback = confirm },
            { text = tr('No'),  callback = closeResetConfirm },
            anchor = AnchorHorizontalCenter
        }, confirm, closeResetConfirm)
end

function resetAnalyzerInfo()
    local player = g_game.getLocalPlayer()
    sessionStarted = true
    startSessionClock()
    playerExperience = player and player:getExperience() or nil
    totalExperience = 0
    currentPage = 1
    g_game.resetAnalyzerInfo()
    drawAnalyzerInfo()
    drawDetailsContent()
    syncAnalyzerTime()
end

function onGameStart()
    if not sessionStarted then
        sessionStarted = true
        startSessionClock()
    end

    -- Re-anchor: the next character's absolute experience is unrelated to this one's.
    playerExperience = nil
end

function onGameEnd()
    closeDetails()
end

function onExperienceChange(localPlayer, value)
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    if not playerExperience or playerExperience == -1 or g_game.isAnalyzerPaused() then
        playerExperience = value
        return
    end

    totalExperience = totalExperience + (value - playerExperience)
    playerExperience = value
    drawAnalyzerInfo()
end

-- ==========================================
-- Detail Window (More Infos)
-- ==========================================

function showDetails()
    if detailsWindow then
        detailsWindow:show()
        detailsWindow:raise()
        return
    end

    detailsWindow = g_ui.loadUI("analyzer_details", modules.game_interface.getRootPanel())
    detailsWindow:show()
    addEvent(function()
        if detailsWindow then
            g_effects.fadeIn(detailsWindow)
        end
    end)

    currentTab = 'loot'
    currentPage = 1
    updateTabButtons()
    drawDetailsContent()
end

function closeDetails()
    closeResetConfirm()
    if pendingDetailsRedraw then
        removeEvent(pendingDetailsRedraw)
        pendingDetailsRedraw = nil
    end
    detailsDirty = false
    if detailsWindow then
        detailsWindow:destroy()
        detailsWindow = nil
    end
end

function switchTab(tab)
    if currentTab == tab then return end
    currentTab = tab
    currentPage = 1
    updateTabButtons()
    drawDetailsContent()
end

function toggleDamageSort(field)
    if damageSortField == field then
        if damageSortOrder == 'asc' then
            damageSortOrder = 'desc'
        elseif damageSortOrder == 'desc' then
            damageSortField = 'none'
            damageSortOrder = 'none'
        else
            damageSortOrder = 'asc'
        end
    else
        damageSortField = field
        damageSortOrder = 'asc'
    end
    currentPage = 1
    updateSortHeaders()
    drawDetailsContent()
end

function updateSortHeaders()
    if not detailsWindow then return end
    local header = detailsWindow.contentArea.damageHeaderRow

    header.col1:setText(tr("Count"))
    header.col2:setText(tr("Pokemon"))
    header.col3:setText(tr("Total Damage"))

    local iconUp = '@fa solid 12 f0d8'
    local iconDown = '@fa solid 12 f0d7'

    header.col1Icon:setVisible(damageSortField == 'count')
    header.col2Icon:setVisible(damageSortField == 'name')
    header.col3Icon:setVisible(damageSortField == 'damage')

    if damageSortField == 'count' then
        header.col1Icon:setIcon(damageSortOrder == 'asc' and iconUp or iconDown)
    elseif damageSortField == 'name' then
        header.col2Icon:setIcon(damageSortOrder == 'asc' and iconUp or iconDown)
    elseif damageSortField == 'damage' then
        header.col3Icon:setIcon(damageSortOrder == 'asc' and iconUp or iconDown)
    end
end

function updateTabButtons()
    if not detailsWindow then return end
    detailsWindow.sidebar.tabLoot:setOn(currentTab == 'loot')
    detailsWindow.sidebar.tabDamage:setOn(currentTab == 'damage')

    local isLoot = (currentTab == 'loot')

    -- Loot grid elements
    detailsWindow.contentArea.lootGrid:setVisible(isLoot)
    detailsWindow.contentArea.lootGridScrollBar:setVisible(isLoot)
    detailsWindow.contentArea.lootDetailPanel:setVisible(false)

    -- Damage list elements
    detailsWindow.contentArea.damageHeaderRow:setVisible(not isLoot)
    detailsWindow.contentArea.entryList:setVisible(not isLoot)
    detailsWindow.contentArea.entriesScrollBar:setVisible(not isLoot)

    -- Pagination only for damage
    detailsWindow.bottomBar.pagination:setVisible(not isLoot)

    if not isLoot then
        updateSortHeaders()
    end
end

function getPageCount(totalEntries)
    if totalEntries == 0 then return 1 end
    return math.ceil(totalEntries / ENTRIES_PER_PAGE)
end

function drawDetailsContent()
    if not detailsWindow then return end

    local analyzerInfo = g_game.getAnalyzerInfo()
    if not analyzerInfo then return end

    if currentTab == 'loot' then
        local lootGrid = detailsWindow.contentArea.lootGrid
        local layout = lootGrid:getLayout()
        layout:disableUpdates()
        local children = lootGrid:getChildren()
        for _, child in ipairs(children) do
            child:destroy()
        end
        drawLootEntries(analyzerInfo, lootGrid)
        layout:enableUpdates()
        layout:update()
    else
        local entryList = detailsWindow.contentArea.entryList
        local layout = entryList:getLayout()
        layout:disableUpdates()
        local children = entryList:getChildren()
        for _, child in ipairs(children) do
            child:destroy()
        end
        drawDamageEntries(analyzerInfo, entryList)
        layout:enableUpdates()
        layout:update()
    end
end

function groupLootEntries(entries)
    local groups = {}
    local groupOrder = {}

    for _, entry in ipairs(entries or {}) do
        local key = tostring(entry.itemClientId or 0)
        if not groups[key] then
            groups[key] = {
                itemClientId = entry.itemClientId,
                itemName = entry.itemName,
                count = 0,
                drops = {}
            }
            table.insert(groupOrder, key)
        end
        groups[key].count = groups[key].count + 1
        table.insert(groups[key].drops, entry)
    end

    return groups, groupOrder
end

function drawLootEntries(analyzerInfo, lootGrid)
    local groups, groupOrder = groupLootEntries(analyzerInfo.lootEntries)

    for _, key in ipairs(groupOrder) do
        local group = groups[key]
        local widget = g_ui.createWidget('AnalyzerLootItemWidget', lootGrid)
        if group.itemClientId and group.itemClientId > 0 then
            widget.itemIcon:setItemId(group.itemClientId)
        end
        if group.count > 1 then
            widget.itemCount:setText(tostring(group.count))
        else
            widget.itemCount:setText("")
        end
        widget:setTooltip(group.itemName .. " (x" .. group.count .. ")")

        local itemKey = key
        widget.onClick = function()
            showLootItemDetail(itemKey, groups)
        end
    end
end

function showLootItemDetail(itemKey, groups)
    if not detailsWindow then return end

    local group = groups[itemKey]
    if not group then return end

    detailPage = 1

    -- Store drops in reverse order (newest first)
    detailDrops = {}
    for i = #group.drops, 1, -1 do
        table.insert(detailDrops, group.drops[i])
    end

    local panel = detailsWindow.contentArea.lootDetailPanel
    panel:setVisible(true)

    -- Fixed panel height
    local maxVisible = math.min(#detailDrops, DETAIL_PER_PAGE)
    local panelHeight = 30 + math.min(maxVisible, 8) * 23 + 30
    panel:setHeight(panelHeight)

    -- Set header info
    if group.itemClientId and group.itemClientId > 0 then
        panel.detailHeader.detailIcon:setItemId(group.itemClientId)
    end
    panel.detailHeader.detailName:setText(group.itemName .. "  x" .. group.count)

    drawDetailPage()
end

function drawDetailPage()
    if not detailsWindow then return end

    local panel = detailsWindow.contentArea.lootDetailPanel
    local detailList = panel.detailList
    local layout = detailList:getLayout()
    layout:disableUpdates()

    local children = detailList:getChildren()
    for _, child in ipairs(children) do
        child:destroy()
    end

    local totalDrops = #detailDrops
    local totalPages = math.max(1, math.ceil(totalDrops / DETAIL_PER_PAGE))
    if detailPage > totalPages then detailPage = totalPages end
    if detailPage < 1 then detailPage = 1 end

    local startIdx = ((detailPage - 1) * DETAIL_PER_PAGE) + 1
    local endIdx = math.min(totalDrops, startIdx + DETAIL_PER_PAGE - 1)

    for i = startIdx, endIdx do
        local drop = detailDrops[i]
        if drop then
            local row = g_ui.createWidget('AnalyzerLootDetailRow', detailList)
            local ts = drop.timestamp or 0
            if ts > 0 then
                local adjusted = ts + GMT_OFFSET
                row.dropTime:setText(os.date("!%H:%M:%S", adjusted))
            else
                row.dropTime:setText("00:00:00")
            end
        end
    end

    layout:enableUpdates()
    layout:update()

    -- Update pagination label
    panel.detailPagination.detailPageLabel:setText(detailPage .. " / " .. totalPages)
    panel.detailPagination:setVisible(totalPages > 1)
end

function detailGoToPage(direction)
    if direction == 'prev' then
        detailPage = math.max(1, detailPage - 1)
    elseif direction == 'next' then
        local totalPages = math.max(1, math.ceil(#detailDrops / DETAIL_PER_PAGE))
        detailPage = math.min(totalPages, detailPage + 1)
    end
    drawDetailPage()
end

function closeLootDetail()
    if not detailsWindow then return end
    detailsWindow.contentArea.lootDetailPanel:setVisible(false)
    detailDrops = {}
    detailPage = 1
end

function drawDamageEntries(analyzerInfo, entryList)
    local entries = analyzerInfo.damageEntries or {}

    -- Copy entries for sorting, preserve original index
    local sorted = {}
    for i, e in ipairs(entries) do
        sorted[i] = { entry = e, origIndex = i }
    end

    if damageSortField == 'name' then
        if damageSortOrder == 'asc' then
            table.sort(sorted, function(a, b) return (a.entry.creatureName or ""):lower() < (b.entry.creatureName or ""):lower() end)
        elseif damageSortOrder == 'desc' then
            table.sort(sorted, function(a, b) return (a.entry.creatureName or ""):lower() > (b.entry.creatureName or ""):lower() end)
        end
    elseif damageSortField == 'damage' then
        if damageSortOrder == 'asc' then
            table.sort(sorted, function(a, b) return (a.entry.totalDamage or 0) < (b.entry.totalDamage or 0) end)
        elseif damageSortOrder == 'desc' then
            table.sort(sorted, function(a, b) return (a.entry.totalDamage or 0) > (b.entry.totalDamage or 0) end)
        end
    elseif damageSortField == 'count' then
        if damageSortOrder == 'asc' then
            table.sort(sorted, function(a, b) return (a.entry.creatureCount or 0) < (b.entry.creatureCount or 0) end)
        elseif damageSortOrder == 'desc' then
            table.sort(sorted, function(a, b) return (a.entry.creatureCount or 0) > (b.entry.creatureCount or 0) end)
        end
    else
        -- Default: restore original insertion order
        table.sort(sorted, function(a, b) return a.origIndex < b.origIndex end)
    end

    local totalEntries = #sorted
    local totalPages = getPageCount(totalEntries)

    if currentPage > totalPages then currentPage = totalPages end
    if currentPage < 1 then currentPage = 1 end

    updatePagination(totalPages)

    local startIdx = ((currentPage - 1) * ENTRIES_PER_PAGE) + 1
    local endIdx = math.min(totalEntries, startIdx + ENTRIES_PER_PAGE - 1)

    local lookTypes = analyzerInfo.creatureLookTypes or {}

    for i = startIdx, endIdx do
        local item = sorted[i]
        if item then
            local entry = item.entry
            local row = g_ui.createWidget('AnalyzerDamageRow', entryList)
            row.creatureName:setText(entry.creatureName or "")
            setAbbreviatedNumber(row.damageValue, entry.totalDamage or 0)

            local count = entry.creatureCount or 0
            if count > 0 then
                row.creatureCount:setText("x" .. count)
            end

            local lookType = lookTypes[entry.creatureName]
            if lookType and lookType > 0 then
                row.creatureOutfit:setOutfit({ type = lookType })
            end
        end
    end
end

function updatePagination(totalPages)
    if not detailsWindow then return end
    local pageLabel = detailsWindow.bottomBar.pagination.pageLabel
    pageLabel:setText(tr("Page: %d/%d", currentPage, totalPages))
end

function goToPage(direction)
    local analyzerInfo = g_game.getAnalyzerInfo()
    if not analyzerInfo then return end

    local totalEntries = 0
    if currentTab == 'loot' then
        return -- loot tab has no pagination
    else
        totalEntries = #(analyzerInfo.damageEntries or {})
    end
    local totalPages = getPageCount(totalEntries)

    if direction == 'first' then
        currentPage = 1
    elseif direction == 'prev' then
        currentPage = math.max(1, currentPage - 1)
    elseif direction == 'next' then
        currentPage = math.min(totalPages, currentPage + 1)
    elseif direction == 'last' then
        currentPage = totalPages
    end

    drawDetailsContent()
end

-- ==========================================
-- Export (JSON / CSV / clipboard)
-- ==========================================

local EXPORT_DIR = '/exports'

local function formatDuration(seconds)
    return string.format("%02d:%02d:%02d",
        math.floor(seconds / 3600),
        math.floor((seconds % 3600) / 60),
        math.floor(seconds % 60))
end

local function perHour(total, seconds)
    return math.floor(total * 3600 / math.max(1, seconds) + 0.5)
end

local function roundDiv(total, count)
    return math.floor(total / math.max(1, count) + 0.5)
end

function collectExportData()
    local analyzerInfo = g_game.getAnalyzerInfo()
    if not analyzerInfo then return nil end

    local now = os.time()
    local durationSeconds = getSessionSeconds()

    local loot = analyzerInfo.loot or 0
    local spent = analyzerInfo.spent or 0
    local totalDamage = analyzerInfo.totalDamage or 0
    local balance = loot - spent
    local xp = totalExperience or 0

    local groups, groupOrder = groupLootEntries(analyzerInfo.lootEntries)
    local lootItems = {}
    local itemizedValueSum = 0
    local totalItemsDropped = 0
    for _, key in ipairs(groupOrder) do
        local group = groups[key]
        local totalValue, minValue, maxValue = 0, nil, nil
        for _, drop in ipairs(group.drops) do
            local v = drop.value or 0
            totalValue = totalValue + v
            if not minValue or v < minValue then minValue = v end
            if not maxValue or v > maxValue then maxValue = v end
        end
        itemizedValueSum = itemizedValueSum + totalValue
        totalItemsDropped = totalItemsDropped + group.count
        table.insert(lootItems, {
            itemClientId = group.itemClientId or 0,
            itemName = group.itemName or "",
            count = group.count,
            totalValue = totalValue,
            avgValue = roundDiv(totalValue, group.count),
            minValue = minValue or 0,
            maxValue = maxValue or 0
        })
    end

    local lookTypes = analyzerInfo.creatureLookTypes or {}
    local damageCreatures = {}
    local totalCreaturesKilled = 0
    for _, entry in ipairs(analyzerInfo.damageEntries or {}) do
        local kills = entry.creatureCount or 0
        local dmg = entry.totalDamage or 0
        totalCreaturesKilled = totalCreaturesKilled + kills
        table.insert(damageCreatures, {
            creatureName = entry.creatureName or "",
            kills = kills,
            totalDamage = dmg,
            damagePerKill = roundDiv(dmg, kills),
            lookType = lookTypes[entry.creatureName] or 0
        })
    end

    return {
        meta = {
            character = g_game.getCharacterName() or "",
            sessionStart = sessionBegin or now,
            exportedAt = now,
            durationSeconds = durationSeconds,
            duration = formatDuration(durationSeconds)
        },
        summary = {
            totalExperience = xp,
            loot = loot,
            spent = spent,
            balance = balance,
            totalDamage = totalDamage
        },
        rates = {
            xpPerHour = perHour(xp, durationSeconds),
            lootPerHour = perHour(loot, durationSeconds),
            spentPerHour = perHour(spent, durationSeconds),
            balancePerHour = perHour(balance, durationSeconds),
            damagePerHour = perHour(totalDamage, durationSeconds)
        },
        loot = {
            totalLootGp = loot,
            itemizedValueSum = itemizedValueSum,
            uniqueItemTypes = #lootItems,
            totalItemsDropped = totalItemsDropped,
            items = lootItems
        },
        damage = {
            totalDamage = totalDamage,
            uniqueCreatureTypes = #damageCreatures,
            totalCreaturesKilled = totalCreaturesKilled,
            creatures = damageCreatures
        }
    }
end

local function csvCell(v)
    local s = tostring(v)
    if s:find('[",\n\r]') then
        s = '"' .. s:gsub('"', '""') .. '"'
    end
    return s
end

function buildExportCsv(data)
    local lines = {}

    lines[#lines + 1] = "# Summary"
    lines[#lines + 1] = "metric,value"
    lines[#lines + 1] = "character," .. csvCell(data.meta.character)
    lines[#lines + 1] = "sessionStart," .. data.meta.sessionStart
    lines[#lines + 1] = "exportedAt," .. data.meta.exportedAt
    lines[#lines + 1] = "duration," .. data.meta.duration
    lines[#lines + 1] = "durationSeconds," .. data.meta.durationSeconds
    lines[#lines + 1] = "totalXP," .. data.summary.totalExperience
    lines[#lines + 1] = "loot," .. data.summary.loot
    lines[#lines + 1] = "spent," .. data.summary.spent
    lines[#lines + 1] = "balance," .. data.summary.balance
    lines[#lines + 1] = "totalDamage," .. data.summary.totalDamage
    lines[#lines + 1] = "xpPerHour," .. data.rates.xpPerHour
    lines[#lines + 1] = "lootPerHour," .. data.rates.lootPerHour
    lines[#lines + 1] = "spentPerHour," .. data.rates.spentPerHour
    lines[#lines + 1] = "balancePerHour," .. data.rates.balancePerHour
    lines[#lines + 1] = "damagePerHour," .. data.rates.damagePerHour

    lines[#lines + 1] = ""
    lines[#lines + 1] = "# Loot"
    lines[#lines + 1] = "itemClientId,itemName,count,totalValue,avgValue,minValue,maxValue"
    for _, it in ipairs(data.loot.items) do
        lines[#lines + 1] = table.concat({
            it.itemClientId, csvCell(it.itemName), it.count,
            it.totalValue, it.avgValue, it.minValue, it.maxValue
        }, ",")
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "# Damage"
    lines[#lines + 1] = "creatureName,kills,totalDamage,damagePerKill,lookType"
    for _, c in ipairs(data.damage.creatures) do
        lines[#lines + 1] = table.concat({
            csvCell(c.creatureName), c.kills, c.totalDamage, c.damagePerKill, c.lookType
        }, ",")
    end

    return table.concat(lines, "\n")
end

local function sanitizeName(name)
    local s = tostring(name or ''):gsub('[^%w%-_]', '_')
    return s
end

local function writeExport(contents, ext)
    if not g_resources.directoryExists(EXPORT_DIR) then
        g_resources.makeDir(EXPORT_DIR)
    end
    local char = sanitizeName(g_game.getCharacterName())
    if char == '' then char = 'session' end
    local filename = string.format('HuntAnalyzer_%s_%s.%s', char, os.date('%Y-%m-%d_%H%M%S'), ext)
    local path = EXPORT_DIR .. '/' .. filename
    if not g_resources.writeFileContents(path, contents) then
        return nil
    end
    return path
end

local function notInGame()
    modules.game_textmessage.displayFailureMessage(tr('You must be in game to export'))
end

function exportJson()
    local data = collectExportData()
    if not data then return notInGame() end
    local ok, result = pcall(json.encode, data, 2)
    if not ok then
        return modules.game_textmessage.displayFailureMessage(tr('Export failed: %s', tostring(result)))
    end
    local path = writeExport(result, 'json')
    if not path then
        return modules.game_textmessage.displayFailureMessage(tr('Could not write export file'))
    end
    modules.game_textmessage.displayStatusMessage(tr('Session exported to %s', path))
end

function exportCsv()
    local data = collectExportData()
    if not data then return notInGame() end
    local ok, result = pcall(buildExportCsv, data)
    if not ok then
        return modules.game_textmessage.displayFailureMessage(tr('Export failed: %s', tostring(result)))
    end
    local path = writeExport(result, 'csv')
    if not path then
        return modules.game_textmessage.displayFailureMessage(tr('Could not write export file'))
    end
    modules.game_textmessage.displayStatusMessage(tr('Session exported to %s', path))
end

function copyJson()
    local data = collectExportData()
    if not data then return notInGame() end
    local ok, result = pcall(json.encode, data, 2)
    if not ok then
        return modules.game_textmessage.displayFailureMessage(tr('Export failed: %s', tostring(result)))
    end
    g_window.setClipboardText(result)
    modules.game_textmessage.displayStatusMessage(tr('Session JSON copied to clipboard'))
end

function buildExportMenu(menu)
    menu:addOption(tr('Export as JSON'), function() exportJson() end)
    menu:addOption(tr('Export as CSV'), function() exportCsv() end)
    menu:addOption(tr('Copy JSON to clipboard'), function() copyJson() end)
end