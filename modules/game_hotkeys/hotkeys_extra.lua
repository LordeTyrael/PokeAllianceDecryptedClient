extraHotkeys = {}

function addExtraHotkey(name, description, callback)
    table.insert(
        extraHotkeys,
        {
            name = name:lower(),
            description = tr(description),
            callback = callback
        }
    )
end

function setupExtraHotkeys(combobox)
    addExtraHotkey("none", "None", nil)
    addExtraHotkey(
        "cancelAttack",
        "Stop attacking",
        function(repeated)
            if not repeated then
                g_game.attack(nil)
            end
        end
    )
    addExtraHotkey(
        "attackNext",
        "Attack next target from battle list",
        function(repeated)
            if repeated or not modules.game_battle then
                return
            end
            local battlePanel = modules.game_battle.battlePanel
            local attackedCreature = g_game.getAttackingCreature()
            local nextChild = nil
            local breakNext = false
            for i, child in ipairs(battlePanel:getChildren()) do
                if not child.creature or not child:isOn() then
                    break
                end
                if child.creature:getType() ~= CreatureTypeSummonOwn then
                  nextChild = child
                end
                if breakNext then
                    break
                end
                if child.creature == attackedCreature then
                    breakNext = true
                    nextChild = battlePanel:getFirstChild()
                end
            end
            if not breakNext or nextChild.creature:getType() == CreatureTypeSummonOwn then
                nextChild = battlePanel:getChildByIndex(2)
            end
            if nextChild and nextChild.creature ~= attackedCreature then
                g_game.attack(nextChild.creature)
            end
        end
    )

    addExtraHotkey(
        "attackPrevious",
        "Attack previous target from battle list",
        function(repeated)
            if repeated or not modules.game_battle then
                return
            end
            local battlePanel = modules.game_battle.battlePanel
            local attackedCreature = g_game.getAttackingCreature()
            local prevChild = nil
            for i, child in ipairs(battlePanel:getChildren()) do
                if not child.creature or not child:isOn() then
                    break
                end
                if child.creature == attackedCreature then
                    break
                end
                prevChild = child
            end
            if prevChild and prevChild.creature ~= attackedCreature then
                g_game.attack(prevChild.creature)
            end
        end
    )

    addExtraHotkey(
        "toogleWsad",
        "Enable/disable wsad walking",
        function(repeated)
            if repeated or not modules.game_chat then
                return
            end
            if not modules.game_chat.consoleToggleChat then
                modules.game_chat.disableChat(true)
            else
                modules.game_chat.enableChat(true)
            end
        end
    )
    
    addExtraHotkey(
        "openAutoCombo",
        "Open Auto Combo Window",
        function(repeated)
            if repeated then
                return
            end
            if modules.game_autocombo then
                modules.game_autocombo.showMainWindow()
            end
        end
    )

    for index, actionDetails in ipairs(extraHotkeys) do
        combobox:addOption(actionDetails.description)
    end
end

function executeExtraHotkey(action, repeated)
    action = action:lower()
    for index, actionDetails in ipairs(extraHotkeys) do
        if actionDetails.name == action and actionDetails.callback then
            actionDetails.callback(repeated)
        end
    end
end

function translateActionToActionComboboxIndex(action)
    action = action:lower()
    for index, actionDetails in ipairs(extraHotkeys) do
        if actionDetails.name == action then
            return index
        end
    end
    return 1
end

function translateActionComboboxIndexToAction(index)
    if index > 1 and index <= #extraHotkeys then
        return extraHotkeys[index].name
    end
    return nil
end

function getActionDescription(action)
    action = action:lower()
    for index, actionDetails in ipairs(extraHotkeys) do
        if actionDetails.name == action then
            return actionDetails.description
        end
    end
    return "invalid action"
end
