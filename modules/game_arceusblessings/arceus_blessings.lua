local mainArceusWindow = nil
local selectedRegionName = nil
local selectedHazardLevel = nil
local currentHazardLevel = nil

local HazardInfoColors = {
    buffs = '#3f944f',
    debuffs = '#a73733',
    rewards = '#7f8fa4'
}

local function resetSelectionState()
    selectedRegionName = nil
    selectedHazardLevel = nil
    currentHazardLevel = nil
end

local function setInfoList(parent, entries, color)
    if not parent then
        return
    end

    parent:destroyChildren()
    for _, text in ipairs(entries or {}) do
        local label = g_ui.createWidget('HazardInfoLabel', parent)
        label:setText(text)
        if color then
            label:setColor(color)
        end
    end
end

local function updateHazardInformation(level)
    if not mainArceusWindow or not mainArceusWindow.informationPanel then
        return
    end

    local infoPanel = mainArceusWindow.informationPanel

    if not level then
        infoPanel.hazardLevel:setText(tr("Level --"))
        setInfoList(infoPanel.buffLabels, {tr("Select a hazard level to preview bonuses.")}, HazardInfoColors.buffs)
        setInfoList(infoPanel.debuffLabels, {}, HazardInfoColors.debuffs)
        setInfoList(infoPanel.rewardLabels, {}, HazardInfoColors.rewards)
        return
    end

    infoPanel.hazardLevel:setText(tr("Level %d", level))

    local buffs = {
        tr("+%d%% experience gain", level * 5),
        tr("+%.1f%% additional loot", level * 0.5)
    }

    local debuffs = {
        tr("-%d%% outgoing damage", level * 3),
        tr("+%d%% incoming damage", level * 5),
        tr("-%d%% critical chance", level),
        tr("+%d%% chance to suffer critical hits", level)
    }

    local hazardEvasionBonus = math.max(0, level - 4)
    if hazardEvasionBonus > 0 then
        table.insert(debuffs, tr("Wild evasion floor: %d%%", hazardEvasionBonus))
        table.insert(debuffs, tr("Wild accuracy floor: %d%%", hazardEvasionBonus))
    end

    local rewards = {}

    if level >= 5 then
        table.insert(rewards, tr("Can drop Sealed Legend"))
    else
        table.insert(rewards, tr("Unlock Sealed Legend at level 5"))
    end

    if level >= 10 then
        table.insert(rewards, tr("Can drop Sealed Mythic"))
    else
        table.insert(rewards, tr("Unlock Sealed Mythic at level 10"))
    end

    setInfoList(infoPanel.buffLabels, buffs, HazardInfoColors.buffs)
    setInfoList(infoPanel.debuffLabels, debuffs, HazardInfoColors.debuffs)
    setInfoList(infoPanel.rewardLabels, rewards, HazardInfoColors.rewards)
end

local function refreshHazardHighlight()
    if not mainArceusWindow or not mainArceusWindow.hazardPanel then
        return
    end

    local hazardPanel = mainArceusWindow.hazardPanel
    for i = 1, hazardPanel:getChildCount() do
        local levelButton = hazardPanel:getChildByIndex(i)
        if levelButton.level == currentHazardLevel then
            levelButton:setImageSource("images/button_selected")
        else
            levelButton:setImageSource("images/button_background")
        end
    end
end

local function applyServerHazardLevel(level)
    currentHazardLevel = level
    refreshHazardHighlight()
    selectedHazardLevel = level
    updateHazardInformation(level)
end

local function onHazardLevelClicked(level)
    if level == nil then
        return
    end

    selectedHazardLevel = level
    updateHazardInformation(level)
end

local function confirmHazardSelection()
    local desiredLevel = selectedHazardLevel or currentHazardLevel
    if not selectedRegionName or desiredLevel == nil then
        return
    end

    selectHazardLevel(desiredLevel, selectedRegionName)
end

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onWalk = closeWindow,
        onAutoWalk = closeWindow,
        onArceusBlessingsOpen = onArceusBlessingsOpen,
        onArceusBlessingsUpdate = onArceusBlessingsUpdate
    })
    
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onWalk = closeWindow,
        onAutoWalk = closeWindow,
        onArceusBlessingsOpen = onArceusBlessingsOpen,
        onArceusBlessingsUpdate = onArceusBlessingsUpdate
    })
    
end

function showMainWindow()
    if mainArceusWindow then
        mainArceusWindow:destroy()
    end

    resetSelectionState()
    mainArceusWindow = g_ui.loadUI("arceus_blessings", modules.game_interface.getRootPanel())
    if mainArceusWindow then
        updateHazardInformation(nil)
        if mainArceusWindow.selectButton then
            mainArceusWindow.selectButton.onClick = confirmHazardSelection
        end
    end
    addEvent(function() g_effects.fadeIn(mainArceusWindow) end)
end

function onGameStart()
end

function onGameEnd()
    if mainArceusWindow then
        mainArceusWindow:destroy()
        mainArceusWindow = nil
    end
    resetSelectionState()
end

function onArceusBlessingsOpen(image, regionName, itemId, maxLevel, currentLevel)
    showMainWindow()
    if mainArceusWindow then
        selectedRegionName = regionName
        mainArceusWindow.arceusImage.region_name:setText(regionName.." Region")

        local hazardPanel = mainArceusWindow.hazardPanel
        if hazardPanel then
            hazardPanel:destroyChildren()
            for level = 0, maxLevel do
                local levelButton = g_ui.createWidget('HazardLabel', hazardPanel)
                levelButton:setId("hazardLevel_"..level)
                levelButton:setText(tr("Level %s", tostring(level)))
                levelButton.level = level
                levelButton:setImageSource("images/button_background")

                levelButton.onClick = function()
                    onHazardLevelClicked(level)
                end
            end
        end

        applyServerHazardLevel(currentLevel)
    end
end

function onArceusBlessingsUpdate(regionName, currentLevel)
    if mainArceusWindow and selectedRegionName == regionName then
        applyServerHazardLevel(currentLevel)
    end
end

function closeWindow()
    if mainArceusWindow then
        if mainArceusWindow and mainArceusWindow:isVisible() then
            addEvent(function()
                if mainArceusWindow then
                    g_effects.fadeOut(mainArceusWindow)
                    scheduleEvent(function()
                        if mainArceusWindow then
                            mainArceusWindow:destroy()
                            mainArceusWindow = nil
                        end
                    end, 250)
                end
            end)
        end
    end
end

function selectHazardLevel(level, regionName)
    local msg = OutputMessage.create()
    msg:addU16(280) -- GameServerArceusBlessings
    msg:addString(regionName)
    msg:addU8(level)
    g_game.getProtocolGame():send(msg)
end