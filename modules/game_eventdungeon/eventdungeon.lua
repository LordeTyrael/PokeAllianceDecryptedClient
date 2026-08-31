local dungeon
local selectedDifficulty = nil
local dungeonType = nil

local DIFFICULTY_IDS = { easy = 1, medium = 2, hard = 3 }
local DIFFICULTY_NAMES = {}
for name, id in pairs(DIFFICULTY_IDS) do DIFFICULTY_NAMES[id] = name end

local dungeonDifficultyData = nil
local timerWindow
local timerUpdateEvent

function init()
    connect(g_game, {
        onGameStart = registerDungeonEvent,
        onGameEnd = hideDungeonWindow,
        onWalk = hideMainWindow,
        onAutoWalk = hideMainWindow,
        onOpenEventDungeonInterface = onOpenEventDungeonInterface,
        onEventDungeonShowTimer = onEventDungeonShowTimer,
        onEventDungeonHideTimer = hideTimer,
    })
end

function terminate()
    disconnect(g_game, {
        onGameStart = registerDungeonEvent,
        onGameEnd = hideDungeonWindow,
        onWalk = hideMainWindow,
        onAutoWalk = hideMainWindow,
        onOpenEventDungeonInterface = onOpenEventDungeonInterface,
        onEventDungeonShowTimer = onEventDungeonShowTimer,
        onEventDungeonHideTimer = hideTimer,
    })
end

function registerDungeonEvent()
    if dungeon then
        dungeon:destroy()
        dungeon = nil
    end
end

function hideDungeonWindow()
    hideMainWindow()
    hideTimer()
end

function hideMainWindow()
    if dungeon then
        dungeon:destroy()
        dungeon = nil
    end
end

function onEventDungeonShowTimer(remainingMs)
    if not remainingMs or remainingMs <= 0 then
        return
    end

    local timeSeconds = remainingMs/1000

    timerWindow = g_ui.displayUI("eventtime", modules.game_interface.getRootPanel())
    timerWindow:setPosition(g_settings.getPoint("timerWindow-pos") or { x = 100, y = 100})
    timerWindow.onDragLeave = onTimerDragLeave
    timerWindow:show()
    timerWindow.timeBackground.dungeonTimer.endTime = os.time() + timeSeconds

    timerWindow.timeBackground.dungeonTimer:setText(formatHMS(timeSeconds))

    timerUpdateEvent = cycleEvent(function()
        if not timerWindow then return end
        local endTime = timerWindow.timeBackground.dungeonTimer.endTime or 0
        if endTime <= 0 then
            hideTimer()
            return
        end

        local remainingTime = endTime - os.time()
        if remainingTime < 0 then
            hideTimer()
            return
        end

        timerWindow.timeBackground.dungeonTimer:setText(formatHMS(remainingTime))
    end, 1000)
end

function onTimerDragLeave()
    if not timerWindow then return end
    g_settings.set("timerWindow-pos", timerWindow:getPosition())
    return true
end

function hideTimer()
    if timerUpdateEvent then
        removeEvent(timerUpdateEvent)
    end

    if timerWindow then
        timerWindow:destroy()
        timerWindow = nil
    end
end

function onOpenEventDungeonInterface(dungeonTypeId, name, image, description, weeklyDone, difficulties)
    local difficultyData = {}
    for _, diff in ipairs(difficulties or {}) do
        local diffName = DIFFICULTY_NAMES[diff.difficulty]
        if diffName then
            local reqItems = {}
            for _, it in ipairs(diff.requiredItems or {}) do
                table.insert(reqItems, { clientId = it.clientId, count = it.count, name = it.description })
            end
            local rewardItems = {}
            for _, it in ipairs(diff.rewards or {}) do
                table.insert(rewardItems, { clientId = it.clientId, count = it.minCount, name = it.name })
            end
            difficultyData[diffName] = {
                requiredLevel = diff.requiredLevel,
                playerNumber  = diff.maxPlayers,
                requiredItems = reqItems,
                rewardItems   = rewardItems,
            }
        end
    end

    showDungeon({
        dungeonType    = dungeonTypeId,
        name           = name,
        image          = image,
        description    = description,
        weeklyDone     = weeklyDone,
        difficultyData = difficultyData,
    })
end

function showDungeon(dungeonData)
    hideMainWindow()
    dungeon = g_ui.loadUI("eventdungeon", modules.game_interface.getRootPanel())
    
    dungeonType = dungeonData.dungeonType
    
    if dungeonData.name then
        dungeon.dungeonName:setText(dungeonData.name)
    end

    if dungeonData.description then
        dungeon.dungeonDescription.dungeonDescriptionText:setText(dungeonData.description)
    end

    if dungeonData.image then
        dungeon.dungeonInfo.image:setImageSource("images/" .. dungeonData.image)
    end

    if dungeonData.difficultyData then
        dungeonDifficultyData = dungeonData.difficultyData
        local params = dungeonDifficultyData["easy"]
        if params then
            local dungeonPanel = dungeon.dungeonInfo
            if params.requiredLevel then
                dungeonPanel.requiredLevelValue:setText(params.requiredLevel)
            end

            if params.playerNumber then
                dungeonPanel.playerNumberValue:setText(params.playerNumber)
            end

            local requirementPanel = dungeon.dungeonInfo.requirementPanel
            if not params.requiredItems then
                params.requiredItems = {}
            end
            for i = 1, 5 do
                local requirement = g_ui.createWidget('InfoCompleteBase', requirementPanel)
                requirement:setId("requirement_"..i)
                if params.requiredItems[i] then
                    local itemId = params.requiredItems[i].clientId or 0
                    local count = params.requiredItems[i].count or 1
                    if itemId > 0 then
                        requirement.completedOption:setItemId(itemId)
                        requirement.completedOption:setItemCount(count)
                        if params.requiredItems[i].name then
                            requirement:setTooltip(params.requiredItems[i].name)
                        end
                    end
                end
            end

            local rewardPanel = dungeon.dungeonInfo.rewardPanel
            if not params.rewardItems then
                params.rewardItems = {}
            end
            for i = 1, 16 do
                local reward = g_ui.createWidget('InfoCompleteBase', rewardPanel)
                reward:setId("reward_"..i)
                if params.rewardItems[i] then
                    local itemId = params.rewardItems[i].clientId or 0
                    local count = params.rewardItems[i].count or 1
                    if itemId > 0 then
                        reward.completedOption:setItemId(itemId)
                        reward.completedOption:setItemCount(count)
                        if params.rewardItems[i].name then
                            reward:setTooltip(params.rewardItems[i].name)
                        end
                    end
                end
            end
        end
    end

    local completedPanel = dungeon.weeklyCompletedPanel.weeklyCompleted
    local playerCompleted = dungeonData.weeklyDone or 0
    for i = 1, 3 do
        local difficulty = g_ui.createWidget('CompletedWeeklyWidget', completedPanel)
        local imageSource = i <= playerCompleted and "images/completed" or "/images/newui/close"
        difficulty.completedOption:setImageSource(imageSource)
    end

    selectedDifficulty = dungeon.difficultyPanel.easy
end

function handleStartDungeon(data)
    if not data or data.success then
        hideMainWindow()
        return
    end

    errorBox = displayErrorBox(tr("Error"), data.errors[1])
end

function selectDifficulty(widget)
    if not widget then
        return
    end

    local parent = widget:getParent()
    if not parent then
        return
    end

    local childrens = parent:getChildren()
    for _, child in pairs(childrens) do
        local selectedWidget = child == widget and true or false
        local imageSource = "difficulty_off"
        if selectedWidget then
            imageSource = "difficulty_on"
            if dungeon then
                local params = dungeonDifficultyData[child:getId()]
                if params then
                    local dungeonPanel = dungeon.dungeonInfo
                    if params.requiredLevel then
                        dungeonPanel.requiredLevelValue:setText(params.requiredLevel)
                    end

                    local requirementPanel = dungeon.dungeonInfo.requirementPanel
                    for i = 1, 5 do
                        local requirement = requirementPanel:getChildById('requirement_'..i)
                        if requirement then
                            if params.requiredItems[i] then
                                local itemId = params.requiredItems[i].clientId or 0
                                local count = params.requiredItems[i].count or 1
                                if itemId > 0 then
                                    requirement.completedOption:setItemId(itemId)
                                    requirement.completedOption:setItemCount(count)
                                    if params.requiredItems[i].name then
                                        requirement:setTooltip(params.requiredItems[i].name)
                                    end
                                end
                            else
                                requirement.completedOption:setItemId(0)
                                requirement:setTooltip("")
                            end
                        end
                    end
        
                    local rewardPanel = dungeon.dungeonInfo.rewardPanel
                    for i = 1, 16 do
                        local reward = rewardPanel:getChildById('reward_'..i)
                        if reward then
                            if params.rewardItems[i] then
                                local itemId = params.rewardItems[i].clientId or 0
                                local count = params.rewardItems[i].count or 1
                                if itemId > 0 then
                                    reward.completedOption:setItemId(itemId)
                                    reward.completedOption:setItemCount(count)
                                    if params.rewardItems[i].name then
                                        reward:setTooltip(params.rewardItems[i].name)
                                    end
                                end
                            else
                                reward.completedOption:setItemId(0)
                                reward:setTooltip("")
                            end
                        end
                    end
                end
            end
        end
        child:setImageSource("images/"..imageSource)
    end

    selectedDifficulty = widget
end

function sendStartDungeon()
    if not selectedDifficulty or not dungeonType then
        return
    end

    local difficultyId = DIFFICULTY_IDS[selectedDifficulty:getId()] or 1
    g_game.startEventDungeon(dungeonType, difficultyId)

    hideMainWindow()
end