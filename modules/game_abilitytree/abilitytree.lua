local talentImages = {
    ["offensivebug"] = {img = "bug.png", type = "bug"},
    ["defensivebug"] = {img = "bug.png", type = "bug"},
    ["offensivedark"] = {img = "dark.png", type = "dark"},
    ["defensivedark"] = {img = "dark.png", type = "dark"},
    ["offensivedragon"] = {img = "dragon.png", type = "dragon"},
    ["defensivedragon"] = {img = "dragon.png", type = "dragon"},
    ["offensiveelectric"] = {img = "electric.png", type = "electric"},
    ["defensiveelectric"] = {img = "electric.png", type = "electric"},
    ["offensivefairy"] = {img = "fairy.png", type = "fairy"},
    ["defensivefairy"] = {img = "fairy.png", type = "fairy"},
    ["offensivefighting"] = {img = "fighting.png", type = "fighting"},
    ["defensivefighting"] = {img = "fighting.png", type = "fighting"},
    ["offensivefire"] = {img = "fire.png", type = "fire"},
    ["defensivefire"] = {img = "fire.png", type = "fire"},
    ["offensiveflying"] = {img = "flying.png", type = "flying"},
    ["defensiveflying"] = {img = "flying.png", type = "flying"},
    ["offensiveghost"] = {img = "ghost.png", type = "ghost"},
    ["defensiveghost"] = {img = "ghost.png", type = "ghost"},
    ["offensivegrass"] = {img = "grass.png", type = "grass"},
    ["defensivegrass"] = {img = "grass.png", type = "grass"},
    ["offensiveground"] = {img = "ground.png", type = "ground"},
    ["defensiveground"] = {img = "ground.png", type = "ground"},
    ["offensiveice"] = {img = "ice.png", type = "ice"},
    ["defensiveice"] = {img = "ice.png", type = "ice"},
    ["offensivenormal"] = {img = "normal.png", type = "normal"},
    ["defensivenormal"] = {img = "normal.png", type = "normal"},
    ["offensivepoison"] = {img = "poison.png", type = "poison"},
    ["defensivepoison"] = {img = "poison.png", type = "poison"},
    ["offensivepsychic"] = {img = "psychic.png", type = "psychic"},
    ["defensivepsychic"] = {img = "psychic.png", type = "psychic"},
    ["offensiverock"] = {img = "rock.png", type = "rock"},
    ["defensiverock"] = {img = "rock.png", type = "rock"},
    ["offensivesteel"] = {img = "steel.png", type = "steel"},
    ["defensivesteel"] = {img = "steel.png", type = "steel"},
    ["offensivewater"] = {img = "water.png", type = "water"},
    ["defensivewater"] = {img = "water.png", type = "water"},
    ["speed"] = {img = "speed.png", type = "character"},
    ["maxhitpoints"] = {img = "health.png", type = "character"},
    ["criticalchance"] = {img = "critical.png", type = "character"},
    ["criticaldamage"] = {img = "critical.png", type = "character"},
    ["snowspeed"] = {img = "snow.png", type = "pokemon"},
    ["sandspeed"] = {img = "sand.png", type = "pokemon"},
    ["underwaterspeed"] = {img = "underwater.png", type = "pokemon"},
    ["cooldown"] = {img = "cooldown.png", type = "character"},
}

local abilityOpcode = 11
local mainWindow
local mainWidget
local sacrificeResultWindow
local sacrificeHideEvent
local sacrificeConfirmBox
local abilityTreeInfo = nil
local windowFilter = "character"

local function closeSacrificeConfirm()
    if sacrificeConfirmBox then
        sacrificeConfirmBox:destroy()
        sacrificeConfirmBox = nil
    end
end

local function confirmSacrifice(talentId, recipeIndex, itemName, required)
    closeSacrificeConfirm()

    local accept = function()
        closeSacrificeConfirm()
        g_game.sendGameAbilityTree(talentId, recipeIndex)
    end

    local message = tr('Sacrifice %dx %s?', required, itemName) .. '\n' ..
                    tr('This cannot be undone.')

    sacrificeConfirmBox = displayAllianceBox(tr('Confirm Sacrifice'), message, {
        { text = tr('Confirm'), callback = accept },
        { text = tr('Cancel'), callback = closeSacrificeConfirm },
        anchor = AnchorHorizontalCenter
    }, accept)
    sacrificeConfirmBox:setupModal(closeSacrificeConfirm)
end

local function onGameStart()
    if not mainWindow then
        return
    end
    mainWindow:hide()
end

local function onGameEnd()
    if not mainWindow then return end
    closeSacrificeConfirm()
    g_uistates.remove(mainWindow)
    mainWindow:hide()
    mainWindow.abilityPanel:destroyChildren()
    loaded = false
end

local function connecting(gameEvent)
    if gameEvent then
        connect(g_game, {
            onGameEnd = onGameEnd,
            onGameStart = onGameStart,
            onAbilityTree = openAbilityTree,
            onSacrificeResult = onSacrificeResult
        })
        connect(g_client, {
            onTrainerClose = close
        })

    end
    return true
end

local function disconnecting(gameEvent)
    if gameEvent then
        disconnect(g_game, {
            onGameEnd = onGameEnd,
            onGameStart = onGameStart,
            onAbilityTree = openAbilityTree,
            onSacrificeResult = onSacrificeResult
        })
        disconnect(g_client, {
            onTrainerClose = close,
        })
    end
    return true
end

modules.client_hotkeys.registerHotkeyCallback("TALENTS",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        toggle()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

function init()
    connecting(true)
    mainWindow = g_ui.loadUI('abilitytree', modules.game_interface.getRootPanel())
    mainWindow:hide()
    sacrificeResultWindow = g_ui.loadUI('sacrificeresult', modules.game_interface.getRootPanel())
    sacrificeResultWindow:hide()
end

function terminate()
    disconnecting(true)
    if sacrificeResultWindow then
        sacrificeResultWindow:destroy()
        sacrificeResultWindow = nil
    end
end

function toggle()
    if not loaded or not mainWindow then
        return
    end

    if mainWindow:isVisible() then
        close()
    else
        mainWindow:show()
        mainWindow:raise()
        g_effects.fadeIn(mainWindow)
        g_uistates.push(mainWindow)

    end
end

function close()
    closeSacrificeConfirm()
    g_effects.fadeOut(mainWindow)
    scheduleEvent(function()
        if mainWindow then
            mainWindow:hide()
            g_uistates.remove(mainWindow)
        end
    end, 500)
end

function onSacrificeResult(success, itemId, count, have, talentName)
    if not sacrificeResultWindow then return end

    -- Cancel any pending hide event
    if sacrificeHideEvent then
        removeEvent(sacrificeHideEvent)
        sacrificeHideEvent = nil
    end

    -- Title
    local titleLabel = sacrificeResultWindow:getChildById('resultTitle')
    if success then
        titleLabel:setText(tr("Sacrifice Successful!"))
    else
        titleLabel:setText(tr("Sacrifice Failed"))
    end

    -- Item icon
    sacrificeResultWindow.itemContainer.item:setItemId(itemId)
    sacrificeResultWindow.itemContainer.item:setItemCount(math.min(count, 100))

    -- Talent name
    sacrificeResultWindow.talentName:setText(talentName)

    -- Count label
    if success then
        sacrificeResultWindow.countLabel:setText("")
    else
        sacrificeResultWindow.countLabel:setText(have .. " / " .. count)
    end

    -- Show with fade in
    sacrificeResultWindow:show()
    sacrificeResultWindow:raise()
    g_effects.fadeIn(sacrificeResultWindow)
    g_uistates.push(sacrificeResultWindow)

    -- Auto-hide after 3 seconds
    sacrificeHideEvent = scheduleEvent(function()
        if sacrificeResultWindow then
            g_effects.fadeOut(sacrificeResultWindow)
            scheduleEvent(function()
                if sacrificeResultWindow then
                    g_uistates.remove(sacrificeResultWindow)
                    sacrificeResultWindow:hide()
                end
            end, 500)
        end
        sacrificeHideEvent = nil
    end, 3000)
end

function openAbilityTree(info, update)
    if update and abilityTreeInfo then
        -- Incremental update: merge received talents into existing list
        local updatedById = {}
        for _, talent in ipairs(info) do
            updatedById[talent.id] = talent
        end

        for i, existing in ipairs(abilityTreeInfo) do
            if updatedById[existing.id] then
                abilityTreeInfo[i] = updatedById[existing.id]
            end
        end

        local applyFilter = windowFilter or "character"
        applyFilters(applyFilter)
        loaded = true
        return
    end

    -- Full load: sort incomplete before completed
    local completedTalents = {}
    local incompleteTalents = {}

    for _, talent in ipairs(info) do
        local type = talent.talentType
        local targetTable = talent.unlocked and completedTalents or incompleteTalents

        if not targetTable[type] then
            targetTable[type] = {}
        end
        table.insert(targetTable[type], talent)
    end

    local sortedTalents = {}
    for type, group in pairs(incompleteTalents) do
        for _, talent in ipairs(group) do
            table.insert(sortedTalents, talent)
        end
    end

    for type, group in pairs(completedTalents) do
        for _, talent in ipairs(group) do
            table.insert(sortedTalents, talent)
        end
    end

    abilityTreeInfo = sortedTalents
    local applyFilter = windowFilter or "character"
    applyFilters(applyFilter)
    loaded = true
end


local function selectTab(filter)
    local active
    for _, button in ipairs(mainWindow.filterPanel:getChildren()) do
        local isActive = button:getId() == filter
        button:setChecked(isActive)
        if isActive then
            active = button
        end
    end
    return active
end

local function updateHeader(filter, total, unlocked)
    local header = mainWindow.header
    local button = selectTab(filter)

    header.headerIcon:setImageSource("images/mainimages/" .. filter)
    header.headerTitle:setText(button and button:getText() or "")
    header.headerCount:setText(tr('%d / %d unlocked', unlocked, total))
    header.headerProgress:setPercent(total > 0 and (unlocked * 100 / total) or 0)
end

function applyFilters(filter)
    if not abilityTreeInfo then
        return
    end
    windowFilter = filter
    mainWindow.abilityPanel:destroyChildren()

    local total, unlocked = 0, 0
    for _, config in ipairs(abilityTreeInfo) do
        local talentConfig = talentImages[config.talentType:lower()]
        if talentConfig and talentConfig.type == filter then
            total = total + 1
            if config.unlocked then
                unlocked = unlocked + 1
            end

            local widget = g_ui.createWidget("AbilityItemWidget", mainWindow.abilityPanel)
            widget.desc:setText(config.description)
            widget.mainImage:setImageSource("images/mainimages/" .. talentConfig.img)

            if config.unlocked then
                widget:setImageSource("images/completelabel")
            end

            local recipeItems = 0
            for recipeIndex, recipeConfig in ipairs(config.required_items) do
                local recipeItem = g_ui.createWidget("AbilityItem", widget.recipe)
                recipeItem:setItemId(recipeConfig.item_id)

                local have = g_game.getLocalPlayer():getItemCount(recipeConfig.item_id) +
                             (recipeConfig.depotStashCount or 0)
                local req = recipeConfig.count
                recipeItem:setItemCount(req)
                recipeItem:setTooltip(have .. "/" .. req .. " " .. recipeConfig.itemName)
                recipeItem:setImageColor(have >= req and '#00FF00' or '#FF0000')

                if recipeConfig.sacrificed then
                    recipeItem:setIcon('images/done')
                else
                    recipeItem.onClick = function()
                        confirmSacrifice(config.id, recipeIndex, recipeConfig.itemName, req)
                    end
                end
                recipeItems = recipeItems + 1
            end

            local columns = math.min(recipeItems, 5)
            local rows = math.max(math.ceil(recipeItems / 5), 1)
            widget.recipe:setWidth(columns * 32 + math.max(columns - 1, 0) * 3)
            widget.recipe:setHeight(rows * 32 + (rows - 1) * 3)
        end
    end

    updateHeader(filter, total, unlocked)
end
