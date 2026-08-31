local preyWindow = nil
local preyableCreatures = nil
local maxPreyWidgets = 6
local selectingPreyID = 0
local choicesWindow = nil
local confirmWindow = nil
local preyInfo = {}
local preyTopButton = nil
local preyWidgets = {}         -- cached PreyWidget[1..3]
local choiceWidgets = {}       -- cached ChoiceCreature widgets (indexed array)
local choiceCreaturesBuilt = nil  -- the creature list that was used to build choiceWidgets
local choiceBuildGen = 0       -- generation counter to cancel stale chunked builds
local CHUNK_SIZE = 10          -- widgets to create per frame tick

local preyBuffIds = {
    experience = 1,
    attack     = 2,
    catch      = 3,
    loot       = 4,
    dodge      = 5,
}

local preyBuffImages = {
    [1] = {description = "+30% Experience", imageSource = "images/prey_xp"},
    [2] = {description = "+30% Attack", imageSource = "images/prey_damage"},
    [3] = {description = "+30% Catch Chance (Don't work on Shinies)", imageSource = "images/prey_catch"},
    [4] = {description = "+25% Loot", imageSource = "images/prey_loot"},
    [5] = {description = "+5% Dodge Change", imageSource = "images/prey_dodge"}
}

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onPreyableCreatures = onPreyableCreatures,
        onPreySlots = onPreySlots
    })
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onPreyableCreatures = onPreyableCreatures,
        onPreySlots = onPreySlots
    })
end

function show()
    if not preyWindow then
        preyWindow = g_ui.loadUI('prey', modules.game_interface.getRootPanel())
        preyWindow.onEscape = hidePreyWindow
        -- Create the 3 prey slot widgets once
        for i = 1, maxPreyWidgets do
            local widget = g_ui.createWidget('PreyWidget', preyWindow.preysPanel)
            widget.preySlot = i
            preyWidgets[i] = widget
        end
    end

    preyWindow:show()
    -- g_uistates is the keyboard grab stack: the window on top receives keys no matter what has
    -- focus, which is what makes onEscape fire reliably (same reason Options and Hotkeys close).
    g_uistates.push(preyWindow)

    -- Update existing widgets with current prey info (no destroy/recreate)
    for i = 1, maxPreyWidgets do
        local widget = preyWidgets[i]
        if not widget then break end

        -- Reset to default state
        widget.pokemonImage:setImageSource("images/none_pokemon")
        widget.pokemonName:setText("")
        widget.pokemonName:setVisible(false)
        widget.buffIcon:setVisible(false)
        widget.progressBackground:setVisible(false)
        widget.confirmButton:setVisible(true)
        widget.closeButton:setVisible(false)
        widget.lockButton:setVisible(false)
        widget.progressBackground.progress:setImageSource("images/collect")
        widget.progressBackground.progressText:setText("0/0")

        if preyInfo[i] then
            local number = preyInfo[i].monsterName:len() > 0 and g_pokemonCyclopedia.getDexNumber(preyInfo[i].monsterName:lower()) or nil
            if number then
                widget.pokemonImage:setImageSource('/images/pokemons/' .. number)
            end
            local imageSource = preyBuffImages[preyInfo[i].buffType]
            if imageSource then
                widget.buffIcon:setImageSource(imageSource.imageSource)
                widget.buffIcon:setTooltip(imageSource.description)
            end

            if preyInfo[i].monsterName:len() > 0 then
                widget.pokemonName:setText(preyInfo[i].monsterName)
                widget.pokemonName:setVisible(true)
                widget.buffIcon:setVisible(true)
                widget.progressBackground:setVisible(true)
                widget.confirmButton:setVisible(false)
                widget.closeButton:setVisible(true)
                widget.lockButton:setVisible(true)
                widget.lockButton.isLocked = preyInfo[i].locked
                lockPrey(widget.lockButton)
                local total = preyInfo[i].total
                if total > 0 then
                    local kills = preyInfo[i].kills
                    local progressPercent = math.max(1, math.round(kills/total))
                    if progressPercent == 100 and kills < total then
                        progressPercent = 99
                    end
                    local clippedHeight = math.ceil(80 * (progressPercent / 100))
                    local rect = { x = 0, y = 80 - clippedHeight, width = 26, height = clippedHeight }
                    widget.progressBackground.progress:setImageClip(rect)
                    widget.progressBackground.progress:setImageRect(rect)
                    local text = string.format("%d/%d", kills, total)
                    if progressPercent == 100 then
                        widget.progressBackground.progress:setImageSource("images/completed")
                        text = "Completed"
                    end
                    widget.progressBackground.progressText:setText(text)
                end
            end
        end
    end
    if not preyableCreatures then
        g_game.sendRequestPreyablePokemon()
    end

    local cardCount = modules.game_playeractionbar.getPlayerItemCount(47864)
    preyWindow.buttonsPanel.preyCardCount:setText(string.format("%dx", cardCount))
    modules.game_walking.disableClientWalk()
end

function onGameStart()
    preyTopButton = modules.client_topmenu.addMiddleGameToggleButton('preyTopButton', tr('Prey') .. '', '/images/ui/topbuttons/icons/prey', toggle)
end

function closeConfirmWindow()
    if confirmWindow then
        confirmWindow:destroy()
        confirmWindow = nil
    end
end

-- Full cleanup: destroy all windows and caches (called on game end)
local function destroyAllWindows()
    choiceBuildGen = choiceBuildGen + 1  -- cancel any in-flight chunked build

    if preyWindow then
        preyWindow:destroy()
        preyWindow = nil
    end
    preyWidgets = {}

    if choicesWindow then
        choicesWindow:destroy()
        choicesWindow = nil
    end
    choiceWidgets = {}
    choiceCreaturesBuilt = nil

    closeConfirmWindow()
end

function toggle()
    if not preyTopButton then
        return
    end
    
    if not preyWindow then
        show()
        return
    end
    
    if preyWindow:isVisible() then
        hidePreyWindow()
    else
        show()
    end
end

function onGameEnd()
    destroyAllWindows()
    preyableCreatures = nil
    selectingPreyID = 0
    preyInfo = {}

    if preyTopButton then
        preyTopButton:destroy()
        preyTopButton = nil
    end
end

function hidePreyWindow()
    if preyWindow then
        g_uistates.remove(preyWindow)
        preyWindow:hide()
    end

    hideChoiceWindow()
    modules.game_walking.enableClientWalk()
end

function hideChoiceWindow()
    choiceBuildGen = choiceBuildGen + 1  -- cancel any in-flight chunked build

    if choicesWindow then
        g_uistates.remove(choicesWindow)
        choicesWindow:hide()
    end

    closeConfirmWindow()

    selectingPreyID = 0
end

local function isChoicesVisible()
    return choicesWindow and choicesWindow:isVisible()
end

function removePrey(widget)
    if not widget or isChoicesVisible() then
        return
    end

    local parent = widget:getParent()
    if not parent then
        return
    end

    local selectPreyID = parent.preySlot or 0
    local config = preyInfo[selectPreyID]
    if not config then
        return
    end

    confirmWindow = g_ui.loadUI('confirmRemovePrey', modules.game_interface.getRootPanel())
    confirmWindow:setupModal(closeConfirmWindow)

    local number = g_pokemonCyclopedia.getDexNumber(config.monsterName:lower())
    local numberSource = (number ~= "" and number) and '/images/pokemons/'..number or nil
    confirmWindow.pokemonImage:setImageSource(numberSource)

    local imageConfig = preyBuffImages[config.buffType]
    local imageSource = imageConfig and imageConfig.imageSource or nil
    confirmWindow.buffWidget:setImageSource(imageSource)

    confirmWindow.name = config.monsterName
    confirmWindow.preySlot = selectPreyID

    confirmWindow.confirmDescription:setColoredText({"You are sure to remove\n", "#FFFFFF", config.monsterName, "#279cf4", "\nto Prey Slot " .. selectPreyID .. "?", "#FFFFFF",})
end

function lockPrey(widget)
    if not widget or isChoicesVisible() then
        return
    end

    local parent = widget:getParent()
    if not parent then
        return
    end

    local selectPreyID = parent.preySlot or 0
    local config = preyInfo[selectPreyID]
    if not config then
        return
    end
    local y = widget.isLocked and 0 or 15
    local clip = { x = 0, y = y, width = 13, height = 15 }
    widget:setImageClip(clip)
end

function sendChangeLockPrey(widget)
    if not widget or isChoicesVisible() then
        return
    end

    local parent = widget:getParent()
    if not parent then
        return
    end

    local selectPreyID = parent.preySlot or 0
    local locked = not widget.isLocked
    widget.isLocked = locked
    g_game.sendChangeLockPrey(selectPreyID, locked)
end

function confirmRemovePrey()
    if not confirmWindow then
        return
    end

    local pokemonName, preySlot = confirmWindow.name, confirmWindow.preySlot
    if not pokemonName or not preySlot then
        return
    end

    closeConfirmWindow()

    g_game.sendRemovePrey(preySlot, pokemonName)
end

function selectPrey(widget)
    if not widget or isChoicesVisible() then
        return
    end

    local parent = widget:getParent()
    if not parent then
        return
    end

    selectingPreyID = parent.preySlot or 0
    showChoicesID()
end

function showChoicesID()
    if not preyableCreatures then return end

    -- If window+widgets already exist and creature list hasn't changed, just show
    if choicesWindow and choiceCreaturesBuilt == preyableCreatures and #choiceWidgets > 0 then
        choicesWindow.searchItemEdit:setText("")
        -- Make all widgets visible (reset any search filter)
        local panel = choicesWindow.preysPanel
        for _, w in ipairs(choiceWidgets) do
            w:setVisibleBatched(true)
        end
        panel:finishBatchVisibility()
        choicesWindow.loadingLabel:setVisible(false)
        choicesWindow:show()
        -- on top of preyWindow in the grab stack, or its search field never sees the keyboard
        g_uistates.push(choicesWindow)
        return
    end

    -- Destroy old choices if creature list changed
    if choicesWindow then
        choicesWindow:destroy()
        choicesWindow = nil
        choiceWidgets = {}
    end

    -- Increment generation to cancel any in-flight chunked build
    choiceBuildGen = choiceBuildGen + 1

    -- Create window, show loading indicator immediately
    choicesWindow = g_ui.loadUI('choices', modules.game_interface.getRootPanel())
    choicesWindow.loadingLabel:setVisible(true)
    choicesWindow.searchItemEdit:setEnabled(false)
    choicesWindow:show()
    g_uistates.push(choicesWindow)

    -- Start chunked creation across frames
    local panel = choicesWindow.preysPanel
    local layout = panel:getLayout()
    layout:disableUpdates()
    panel:beginBatchAdd()

    local creatures = preyableCreatures
    local total = #creatures
    local startIndex = 1
    local gen = choiceBuildGen  -- capture current generation

    local function buildNextChunk()
        -- Abort if generation changed (window closed/creature list changed)
        if gen ~= choiceBuildGen then return end
        if not choicesWindow then return end

        local endIndex = math.min(startIndex + CHUNK_SIZE - 1, total)

        for i = startIndex, endIndex do
            local name = creatures[i]
            local widget = g_ui.createWidget('ChoiceCreature', panel)
            widget.name = name
            widget._nameLower = name:lower()
            widget.onClick = function()
                confirmWindow = g_ui.loadUI('confirmWindow', modules.game_interface.getRootPanel())
                confirmWindow:setupModal(closeConfirmWindow)
                confirmWindow.name = name
                confirmWindow.preySlot = selectingPreyID
                local number = g_pokemonCyclopedia.getDexNumber(name:lower())
                if number ~= "" then
                    confirmWindow.pokemonImage:setImageSource('/images/pokemons/' .. number)
                else
                    confirmWindow.pokemonImage:setImageSource(nil)
                end
                confirmWindow.confirmDescription:setColoredText({"You are sure select\n", "#FFFFFF",name, "#279cf4", "\nto Prey Slot " .. selectingPreyID .. "?", "#FFFFFF",})
            end
            local number = g_pokemonCyclopedia.getDexNumber(name:lower())
            if number ~= "" then
                widget:setImageSourceAsync('/images/pokemons/' .. number)
            else
                widget:setImageSource(nil)
            end
            widget:setTooltip(name)
            choiceWidgets[#choiceWidgets + 1] = widget
        end

        startIndex = endIndex + 1
        if startIndex <= total then
            -- More to create — schedule next chunk on next frame
            scheduleEvent(buildNextChunk, 0)
        else
            -- All done — finalize
            panel:endBatchAdd()
            layout:enableUpdates()
            layout:update()
            choiceCreaturesBuilt = creatures
            if choicesWindow then
                choicesWindow.loadingLabel:setVisible(false)
                choicesWindow.searchItemEdit:setEnabled(true)
            end
        end
    end
    -- Kick off the first chunk immediately (via event so the window renders first)
    scheduleEvent(buildNextChunk, 0)
end

function onPreyableCreatures(creatures)
    preyableCreatures = creatures
    for _, name in ipairs(creatures) do
        local number = g_pokemonCyclopedia.getDexNumber(name:lower())
        if number ~= "" then
            g_textures.preloadAsync('/images/pokemons/' .. number)
        end
    end
end

function onPreySlots(slots)
    preyInfo = slots
    if preyWindow and preyWindow:isVisible() then
        show()
    end
end

function onPreyCardUpdate(newCount)
    if not preyWindow or not preyWindow:isVisible() then
        return
    end

    preyWindow.buttonsPanel.preyCardCount:setText(string.format("%dx", newCount))
end

function onSearchTextChange(text)
    if not choicesWindow or not choicesWindow.preysPanel then
        return
    end

    -- Don't search while still loading (widgets not fully built yet)
    if not choiceCreaturesBuilt or choiceCreaturesBuilt ~= preyableCreatures then
        return
    end

    local lowerText = text:lower():trim()
    local panel = choicesWindow.preysPanel

    -- Use visibility toggling instead of destroy/recreate
    for _, widget in ipairs(choiceWidgets) do
        if lowerText == "" then
            widget:setVisibleBatched(true)
        else
            local match = widget._nameLower and widget._nameLower:find(lowerText, 1, true) ~= nil
            widget:setVisibleBatched(match)
        end
    end
    panel:finishBatchVisibility()
end

function confirmSelectPrey()
    if not confirmWindow then
        return
    end

    local pokemonName, preySlot = confirmWindow.name, confirmWindow.preySlot
    if not pokemonName or not preySlot then
        return
    end

    local selectBonusWidget = confirmWindow.bonusPanel:getFocusedChild()
    if not selectBonusWidget then
        return
    end

    local buffName = selectBonusWidget:getId()
    local buffId = preyBuffIds[buffName]
    if not buffId then
        return
    end

    hideChoiceWindow()
    g_game.sendSelectPrey(preySlot, pokemonName, buffId)
end