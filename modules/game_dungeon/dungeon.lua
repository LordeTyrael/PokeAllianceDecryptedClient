local dungeon
local currentFamilyId
local currentDifficulties = {}

-- Opcode
local DUNGEON_DIFFICULTY = {
    EASY = 1,
    MEDIUM = 2,
    HARD = 3
}

function init()
    connect(g_game, {
        onGameStart = hide,
        onGameEnd = hide,
        onWalk = hide,
        onAutoWalk = hide,
        onOpenDungeonInterface = onOpenDungeonInterface
    })
end

function terminate()
    disconnect(g_game, {
        onGameStart = hide,
        onGameEnd = hide,
        onWalk = hide,
        onAutoWalk = hide,
        onOpenDungeonInterface = onOpenDungeonInterface
    })

    if dungeon then
        dungeon:destroy()
        dungeon = nil
    end
end

function hide()
    if dungeon then
        dungeon:destroy()
        dungeon = nil
    end
    currentFamilyId = nil
    currentDifficulties = {}
end

function onOpenDungeonInterface(familyId, familyName, exitPos, difficulties)
    if dungeon then
        if dungeon:isVisible() then
            return
        end
        -- Destroy existing invisible window
        dungeon:destroy()
        dungeon = nil
    end
    
    -- Create dungeon window
    dungeon = g_ui.loadUI("dungeon", modules.game_interface.getRootPanel())
    
    currentFamilyId = familyId
    currentDifficulties = difficulties
    
    dungeon.dungeonName:setText(familyName)
    
    -- Create difficulty buttons dynamically
    local buttonContainer = dungeon.PanelDifficult.DifficultyButtons
    buttonContainer:destroyChildren()
    
    for i, diffInfo in ipairs(difficulties) do
        local button = g_ui.createWidget('DifficultyButton', buttonContainer)
        button:setId('difficultyButton' .. i)
        button:setText(diffInfo.name)
        button.onClick = function()
            selectDifficulty(diffInfo.difficulty)
        end
    end
    
    -- Show first difficulty by default
    if #difficulties > 0 then
        showDifficulty(difficulties[1])
    end
end

function selectDifficulty(difficulty)
    -- Update button states
    local buttonContainer = dungeon.PanelDifficult.DifficultyButtons
    for i, diffInfo in ipairs(currentDifficulties) do
        local button = buttonContainer:getChildById('difficultyButton' .. i)
        if button then
            button:setOn(diffInfo.difficulty == difficulty)
        end
    end
    
    -- Find and display selected difficulty
    for _, diffInfo in ipairs(currentDifficulties) do
        if diffInfo.difficulty == difficulty then
            showDifficulty(diffInfo)
            break
        end
    end
end

function showDifficulty(difficultyInfo)
    -- Update button states based on current difficulty
    local buttonContainer = dungeon.PanelDifficult.DifficultyButtons
    for i, diff in ipairs(currentDifficulties) do
        local button = buttonContainer:getChildById('difficultyButton' .. i)
        if button then
            button:setOn(diff.difficulty == difficultyInfo.difficulty)
        end
    end
    
    -- Painel start dungeon
    dungeon.dungeonImage:setImageSource("dungeons/" .. difficultyInfo.image)
    dungeon.buttonStart.onClick = function()
        startDungeon(difficultyInfo.difficulty)
    end

    dungeon.PanelDifficult.LabelLevelMinimo:setText(tr("Minimum Level: ") .. difficultyInfo.requiredLevel)
    if difficultyInfo.maxPlayers == 1 then
        dungeon.PanelDifficult.LabelPlayers:setText(tr("%d Player", difficultyInfo.maxPlayers))
    else
        dungeon.PanelDifficult.LabelPlayers:setText(tr("%d Players", difficultyInfo.maxPlayers))
    end

    -- Painel Requerimentos
    dungeon.PanelRequerimentos.RequerimentoList:destroyChildren()
    for _, required in ipairs(difficultyInfo.requiredItems) do
        local itemWidget = g_ui.createWidget("Item", dungeon.PanelRequerimentos.RequerimentoList)
        itemWidget:setVirtual(true)
        itemWidget:setItemId(required.clientId)
        itemWidget:setItemCount(required.count)
        itemWidget:setTooltip(required.count .. "x " .. required.description)
    end

    -- Painel Rewards
    dungeon.PanelRecompense.RewardList:destroyChildren()
    for _, reward in ipairs(difficultyInfo.rewards) do
        local itemWidget = g_ui.createWidget("Item", dungeon.PanelRecompense.RewardList)
        itemWidget:setVirtual(true)
        itemWidget:setItemId(reward.clientId)
        itemWidget:setTTF("poppins", "semibold", 12)
        itemWidget:setTextAlign(AlignBottomCenter)
        itemWidget:setTooltip(tr("%s. Count: %d-%d", reward.name, reward.minCount, reward.maxCount))
    end
end

function startDungeon(difficulty)
    if not currentFamilyId then
        return
    end
    
    g_game.startDungeon(currentFamilyId, difficulty)
    hide()
end