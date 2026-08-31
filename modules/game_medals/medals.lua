local MAX_SLOTS = 10
local MAX_PRESETS = 5
local medalWindow = nil
local playerMedals = {}
local equippedMedals = {}
local medalStats = {}
local medalItemCounts = {}
local currentPreset = 1  -- Preset ativo (enviado pelo servidor)
local searchText = ""
local hideLocked = false

local typeToString = {
    [1]  = "Damage Boost",
    [2]  = "Defense Boost",
    [3]  = "HP Boost",
    [4]  = "Pokemon Speed",
    [5]  = "Character Speed",
    [6]  = "Critical Chance",
    [7]  = "Critical Damage",
    [8]  = "Precision",
    [9]  = "Evasion",
    [10] = "Shiny Fishing",
    [11] = "Shiny Headbutt",
    [12] = "Loot Boost",
    [13] = "Catch",
    [14] = "Shiny Catch",
    [15] = "Shiny Charm",
    [16] = "Critical Resistance",
    [17] = "Life Leech",
    [18] = "Fly Speed",
    [19] = "Surf Speed",
    [20] = "Ride Speed",
}

local typeIsPercent = {
    [1]  = true, [2]  = true, [3]  = true,
    [6]  = true, [7]  = true, [8]  = true, [9]  = true,
    [10] = true, [11] = true, [12] = true, [13] = true,
    [14] = true, [15] = true, [16] = true, [17] = true,
}

local medalLevelToString = {
    [1] = { name = "Bronze",     color = "#CD7F32" },
    [2] = { name = "Silver",     color = "#C0C0C0" },
    [3] = { name = "Gold",       color = "#FFD700" },
    [4] = { name = "Diamond",    color = "#B9F2FF" },
    [5] = { name = "Emerald",    color = "#50C878" },
    [6] = { name = "Orichalcum", color = "#CD7F32" },
}

local function fitTooltipWidth(tooltip)
    local maxWidth = 0
    for _, label in ipairs({ tooltip.pokemonName, tooltip.level, tooltip.experience,
                             tooltip.buff, tooltip.debuff, tooltip.itemCount }) do
        local w = label:getTextSize().width
        if w > maxWidth then maxWidth = w end
    end
    local target = maxWidth + 24
    if target > tooltip:getWidth() then
        tooltip:setWidth(target)
    end
end

modules.client_hotkeys.registerHotkeyCallback("MEDALS",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        openPokemonMedals()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onMedalList = onMedalList,
        onMedalEquipped = onMedalEquipped,
        onMedalStats = onMedalStats,
        onMedalUpdate = onMedalUpdate,
        onMedalPreset = onMedalPreset,
        onMedalItemCounts = onMedalItemCounts,
        onMedalResponse = onMedalResponse,
    })
    connect(g_client, {
        onTrainerClose = hideMedalWindow
    })
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onMedalList = onMedalList,
        onMedalEquipped = onMedalEquipped,
        onMedalStats = onMedalStats,
        onMedalUpdate = onMedalUpdate,
        onMedalPreset = onMedalPreset,
        onMedalItemCounts = onMedalItemCounts,
        onMedalResponse = onMedalResponse,
    })
    disconnect(g_client, {
        onTrainerClose = hideMedalWindow
    })

end

function show()

end

function onGameStart()
end

function onGameEnd()
    playerMedals = {}
    equippedMedals = {}
    medalStats = {}
    medalItemCounts = {}
    currentPreset = 1
    drawned = false
    hideMedalWindow()
end

function hideMedalWindow()
    if medalWindow then
        g_effects.fadeOut(medalWindow)
        scheduleEvent(function()
            if medalWindow then
                g_uistates.remove(medalWindow)
                medalWindow:destroy()
                medalWindow = nil
            end
        end, 500)
    end
end

function onMedalList(medals)
    playerMedals = {}
    equippedMedals = {}

    for _, data in ipairs(medals) do
        playerMedals[data.id] = {
            id = data.id,
            level = data.level,
            experience = data.experience,
            requiredExperience = data.requiredExperience,
            clientId = data.clientId,
            buff = data.buff,
            debuff = data.debuff
        }
    end
end

function onMedalEquipped(equipped)
    for _, slot in ipairs(equipped) do
        local luaSlot = slot.slotIndex + 1

        if slot.id ~= 0 then
            local med = playerMedals[slot.id]
            if med then
                equippedMedals[luaSlot] = med
            else
                equippedMedals[luaSlot] = {
                    id                 = slot.id,
                    level              = slot.level,
                    experience         = slot.experience,
                    requiredExperience = slot.requiredExperience,
                    clientId           = slot.clientId
                }
            end
        else
            equippedMedals[luaSlot] = nil
        end
    end
    if medalWindow and medalWindow:isVisible() then
        updateEquippedMedals()
    end
end

function onMedalStats(stats)
    medalStats = {}
    for _, stat in ipairs(stats) do
        medalStats[stat.type] = stat.value
    end
    if medalWindow and medalWindow:isVisible() then
        updateMedalStats()
    end
end

function onMedalUpdate(data)
    playerMedals[data.id] = {
        id = data.id,
        level = data.level,
        experience = data.experience,
        requiredExperience = data.requiredExperience,
        clientId = data.clientId,
        buff = data.buff,
        debuff = data.debuff
    }

    local medalData = playerMedals[data.id]
    for index, config in ipairs(equippedMedals) do
        if config.id == data.id then
            equippedMedals[index] = medalData
        end
    end

    -- Update UI if open
    if medalWindow and medalWindow:isVisible() then
        updateEquippedMedals()
        local widget = medalWindow.medalsPanel:getChildById("pokemon"..data.id)
        if widget then
            widget.pokemonItem:setItemId(medalData.clientId)
            widget.onHoverChange = function(self, hovered)
                if not hovered and self.tooltipWindow then
                    self.tooltipWindow:destroy()
                    self.tooltipWindow = nil
                    return
                end

                if self.tooltipWindow then
                    self.tooltipWindow:destroy()
                    self.tooltipWindow = nil
                end
                local name = g_pokemonCyclopedia.getNameByNumber(data.id)
                local tooltip = g_ui.createWidget('MedalTooltip', medalWindow)
                local lvlInfo = medalLevelToString[medalData.level] or {name="Locked", color="#FFFFFF"}
                tooltip.pokemonName:setText(name)
                tooltip.pokemonName:setColor(lvlInfo.color)
                tooltip.level:setText(tr("Level: %s (%d)", tr(lvlInfo.name), medalData.level))
                tooltip.level:setColor(lvlInfo.color)
                tooltip.experience:setText(tr("XP: %d / %d", medalData.experience, medalData.requiredExperience))
                local height = tooltip:getHeight()
                if not setBuffLine(tooltip.buff, medalData.buff.type, medalData.buff.value) then
                    height = height - 25
                end
                if not setBuffLine(tooltip.debuff, medalData.debuff.type, medalData.debuff.value) then
                    height = height - 25
                end

                -- Show medal item count in tooltip
                local itemInfo = medalItemCounts[data.id]
                if itemInfo then
                    local stashCount = itemInfo.stashCount or 0
                    local inventoryCount = g_game.getLocalPlayer():getItemCount(itemInfo.clientId)
                    local totalCount = stashCount + inventoryCount
                    tooltip.itemCount:setText(tr("Items: %d", totalCount))
                else
                    tooltip.itemCount:setText("")
                    height = height - 25
                end

                local pos = widget:getPosition()
                local windowSize = widget:getSize()

                if lvlInfo.name == "Locked" then
                    height = 75
                end
                if height ~= tooltip:getHeight() then
                    tooltip:setHeight(height)
                end

                fitTooltipWidth(tooltip)

                pos.x = pos.x + windowSize.width

                tooltip:setPosition(pos)
                self.tooltipWindow = tooltip
            end
            widget:setOpacity(medalData.level == 0 and 0.5 or 1.0)
        end
        applyMedalFilters()
    end
end

function onMedalPreset(presetId)
    currentPreset = presetId
    updateCurrentPresetLabel()
    updatePresetButtons()
end

function onMedalItemCounts(itemCounts)
    medalItemCounts = {}
    for _, info in ipairs(itemCounts) do
        medalItemCounts[info.pokemonId] = {
            clientId = info.clientId,
            stashCount = info.stashCount
        }
    end

    if medalWindow and medalWindow:isVisible() and medalWindow.medalsPanel then
        for _, child in pairs(medalWindow.medalsPanel:getChildren()) do
            local id = child.pokemonId
            local itemInfo = medalItemCounts[id]
            if itemInfo then
                local stashCount = itemInfo.stashCount or 0
                local inventoryCount = g_game.getLocalPlayer():getItemCount(itemInfo.clientId)
                local totalCount = stashCount + inventoryCount
                if totalCount > 0 then
                    child.pokemonItem:setItemCount(totalCount, 100)
                else
                    child.pokemonItem:setItemCount(1)
                end
            else
                child.pokemonItem:setItemCount(1)
            end
        end
    end
end

function onMedalResponse(message)
    modules.game_textmessage.displayFailureMessage(message)
end

function formatBuffValue(tType, val)
  return formatSigned(val, typeIsPercent[tType])
end

function setBuffLine(label, tType, tValue)
  if not tType or tType == 0 or not tValue or tValue == 0 then
    label:setText("")
    return false
  end

  local name = typeToString[tType] and tr(typeToString[tType]) or tr("Type %s", tType)
  label:setText(string.format("%s %s", name, formatBuffValue(tType, tValue)))

  if tValue > 0 then
    label:setColor("#00ff18")
  elseif tValue < 0 then
    label:setColor("#ff0000")
  else
    label:setColor("#FFFFFF")
  end
  return true
end

function openPokemonMedals()
    if medalWindow then
        hideMedalWindow()
        return
    end

    g_game.sendRequestMedalItemCounts()

    medalWindow = g_ui.loadUI('medals', modules.game_interface.getRootPanel())
    searchText = ""
    local medalsPanel = medalWindow.medalsPanel
    if not medalsPanel then return end
    local layout = medalsPanel:getLayout()
    layout:disableUpdates()

    medalsPanel:show()
    medalsPanel:destroyChildren()

    local sortedIds = {}
    for id in pairs(playerMedals) do
        table.insert(sortedIds, id)
    end
    table.sort(sortedIds)

    for _, id in ipairs(sortedIds) do
        local data = playerMedals[id]
        if not data then goto continue_all end

        local w = g_ui.createWidget('MedalWidget', medalsPanel)
        w.pokemonId = id
        w:setId("pokemon"..id)

        local name = g_pokemonCyclopedia.getNameByNumber(id)
        w.pokemonItem:setItemId(data.clientId)
        w.onHoverChange = function(self, hovered)
            if not hovered and self.tooltipWindow then
                self.tooltipWindow:destroy()
                self.tooltipWindow = nil
                return
            end

            if self.tooltipWindow then
                self.tooltipWindow:destroy()
                self.tooltipWindow = nil
            end

            local tooltip = g_ui.createWidget('MedalTooltip', medalWindow)
            local lvlInfo = medalLevelToString[data.level] or {name="Locked", color="#FFFFFF"}
            tooltip.pokemonName:setText(name)
            tooltip.pokemonName:setColor(lvlInfo.color)
            tooltip.level:setText(tr("Level: %s (%d)", tr(lvlInfo.name), data.level))
            tooltip.level:setColor(lvlInfo.color)
            tooltip.experience:setText(tr("XP: %d / %d", data.experience, data.requiredExperience))
            local height = tooltip:getHeight()
            if not setBuffLine(tooltip.buff, data.buff.type, data.buff.value) then
                height = height - 25
            end
            if not setBuffLine(tooltip.debuff, data.debuff.type, data.debuff.value) then
                height = height - 25
            end

            -- Show medal item count in tooltip
            local itemInfo = medalItemCounts[id]
            if itemInfo then
                local stashCount = itemInfo.stashCount or 0
                local inventoryCount = g_game.getLocalPlayer():getItemCount(itemInfo.clientId)
                local totalCount = stashCount + inventoryCount
                tooltip.itemCount:setText(tr("Items: %d", totalCount))
            else
                tooltip.itemCount:setText("")
                height = height - 25
            end

            local pos = w:getPosition()
            local windowSize = w:getSize()

            if lvlInfo.name == "Locked" then
                height = 75
            end
            if height ~= tooltip:getHeight() then
                tooltip:setHeight(height)
            end

            fitTooltipWidth(tooltip)

            pos.x = pos.x + windowSize.width
            
            tooltip:setPosition(pos)
            self.tooltipWindow = tooltip
        end
        --w:setTooltip(buildTooltip(id, data))
        w:setOpacity(data.level == 0 and 0.5 or 1.0)

        -- Show medal item count (stash + inventory)
        local itemInfo = medalItemCounts[id]
        if itemInfo then
            local stashCount = itemInfo.stashCount or 0
            local inventoryCount = g_game.getLocalPlayer():getItemCount(itemInfo.clientId)
            local totalCount = stashCount + inventoryCount
            if totalCount > 0 then
                w.pokemonItem:setItemCount(totalCount, 100)
            end
        end

        w.onClick = function() equipMedal(id) end

        ::continue_all::
    end
    layout:enableUpdates()
    layout:update()
    local hideLockedSwitch = medalWindow:recursiveGetChildById("hideLocked")
    if hideLockedSwitch then
        hideLockedSwitch:setChecked(hideLocked)
    end
    applyMedalFilters()
    updateEquippedMedals()
    updateMedalStats()
    updatePresetButtons()
    updateCurrentPresetLabel()
    g_effects.fadeIn(medalWindow)
    g_uistates.push(medalWindow)
end

function updateEquippedMedals()
    if not medalWindow then return end
    for i = 1, MAX_SLOTS do
        local slotWidget = medalWindow:getChildById("medal"..i)
        if not slotWidget then break end

        local data = equippedMedals[i]
        if data then
            local name = g_pokemonCyclopedia.getNameByNumber(data.id)
            slotWidget.slotId = i
            slotWidget.pokemonItem:setItemId(data.clientId)
            slotWidget:setTooltip(tr("Equipped: %s\nLevel: %d\nXP: %d / %d", name, data.level, data.experience, data.requiredExperience))
            slotWidget:setOpacity(data.level == 0 and 0.5 or 1.0)
        else
            slotWidget.pokemonItem:setItemId(0)
            slotWidget:setTooltip("") 
            slotWidget:setOpacity(1.0)
            slotWidget.slotId = 0
        end
    end
end

function updateMedalStats()
    if not medalWindow then return end
    local textPanel = medalWindow.attributeArea
    if not textPanel then return end

    local layout = textPanel:getLayout()
    layout:disableUpdates()

    -- limpa filhos
    textPanel:destroyChildren()

    local statsList = {}
    for statType, statValue in pairs(medalStats) do
        local rawName = typeToString[statType]
        local num = tonumber(statValue)
        if rawName and num and num ~= 0 then
            statsList[#statsList+1] = { type = statType, name = tr(rawName), value = num }
        end
    end

    table.sort(statsList, function(a, b)
        return a.value > b.value
    end)

    for _, entry in ipairs(statsList) do
        local widget = g_ui.createWidget('AttributeLabel', textPanel)
        widget.attributeName:setText(entry.name)
        widget.attributeValue:setText(formatBuffValue(entry.type, entry.value))
        if entry.value > 0 then
            widget.attributeValue:setColor("#00ff18")
        else
            widget.attributeValue:setColor("#ff0000")
        end
    end

    layout:enableUpdates()
    layout:update()
end

function equipMedal(pokemonId)
    if not pokemonId or not medalWindow then
        return
    end

    g_game.sendEquipMedal(pokemonId)
end

function deequipMedal(widget)
    if not widget or not widget.slotId then
        return
    end

    if widget.slotId > 0 then
        g_game.sendDeequipMedal(widget.slotId)
    end
end

local function matchesType(name, text)
    if not name then return false end
    if name:lower():find(text, 1, true) then return true end
    return tr(name):lower():find(text, 1, true) ~= nil
end

local function matchesSearch(id, data)
    if searchText == "" then return true end

    local name = g_pokemonCyclopedia.getNameByNumber(id)
    if name and name:lower():find(searchText, 1, true) then return true end

    if data then
        local buffName = typeToString[(data.buff and data.buff.type) or 0]
        local debuffName = typeToString[(data.debuff and data.debuff.type) or 0]
        return matchesType(buffName, searchText) or matchesType(debuffName, searchText)
    end

    return false
end

function applyMedalFilters()
    if not medalWindow or not medalWindow.medalsPanel then return end

    for _, child in pairs(medalWindow.medalsPanel:getChildren()) do
        local id = child.pokemonId
        local data = playerMedals[id]
        local locked = not data or data.level == 0
        child:setVisible(not (hideLocked and locked) and matchesSearch(id, data))
    end
end

function onSearchTextChange(text)
    searchText = text:lower():trim()
    applyMedalFilters()
end

function onHideLockedChange(checked)
    hideLocked = checked
    applyMedalFilters()
end

-- ========== PRESET FUNCTIONS ==========

function changePreset(presetId)
    if not presetId or presetId < 1 or presetId > MAX_PRESETS then
        return
    end
    
    -- Envia para o servidor trocar o preset ativo
    g_game.sendChangeCurrentPreset(presetId)
end

function updateCurrentPresetLabel()
    if not medalWindow then return end
    
    local label = medalWindow:recursiveGetChildById("currentPresetLabel")
    if label then
        label:setText(tr("Current Preset: ") .. currentPreset)
    end
end

function updatePresetButtons()
    if not medalWindow then return end
    
    for i = 1, MAX_PRESETS do
        local presetBtn = medalWindow:recursiveGetChildById("preset" .. i)
        if presetBtn then
            -- Destaca o preset ativo
            if i == currentPreset then
                presetBtn:setOpacity(1.0)
                presetBtn:setColor("#FFD700")  -- Dourado para ativo
            else
                presetBtn:setOpacity(1.0)
                presetBtn:setColor("#FFFFFF")  -- Branco para outros
            end
        end
    end
end

