local dialogWindow
local npcID = nil

local dungeonDifficultyData = nil
local timerWindow
local timerUpdateEvent

function init()
    connect(g_game, {
        onGameStart = hideMainWindow,
        onGameEnd = hideMainWindow,
        onWalk = hideMainWindow,
        onAutoWalk = hideMainWindow,
        onNPCDialogReceived = onNPCDialogReceived,
        onNPCDialogClose = hideMainWindow,
    })
end

function terminate()
    disconnect(g_game, {
        onGameStart = hideMainWindow,
        onGameEnd = hideMainWindow,
        onWalk = hideMainWindow,
        onAutoWalk = hideMainWindow,
        onNPCDialogReceived = onNPCDialogReceived,
        onNPCDialogClose = hideMainWindow,
    })
end

function hideMainWindow()
    if dialogWindow then
        dialogWindow:destroy()
        dialogWindow = nil
    end
end

function onNPCDialogReceived(data)
    hideMainWindow()

    npcID = data.npcId
    local npcMessage = data.npcMessage
    local options = data.options
    local tasks = data.tasks

    local npc = g_map.getCreatureById(npcID)
    if not npc then
        return
    end

    local npcOutfit = npc:getOutfit()

    -- cria a UI
    dialogWindow = g_ui.loadUI("npcdialog", modules.game_interface.getRootPanel())
    dialogWindow.titleBackground.npcOutfit:setOutfit(npcOutfit)
    dialogWindow.titleBackground.npcName:setText(npc:getName())

    local msgBg      = dialogWindow.messageBackground
    local msgLabel   = msgBg.npcMessage
    local optsPanel  = msgBg.optionsPanel
    local tasksPanel = msgBg.tasksPanel

    msgLabel:setText(npcMessage)

    -- popula botões de opção
    for optionId, optionText in ipairs(options) do
        local btn = g_ui.createWidget("OptionWidget", optsPanel)
        btn:setId(optionId)
        btn.optionText:setText(optionText)
        local h = btn.optionText:getHeight()
        btn:setHeight(h)
        btn.optionButton:setHeight(h + 8)
        btn.onClick = sendTalkWithNPC
    end

    -- 1) Ajusta altura do texto (mínimo 50)
    local textH = math.max(50, msgLabel:getHeight())

    -- 2) Ajusta altura do painel de opções
    local spacing  = 10
    local optsH    = 0
    if #options > 0 then
        for _, btn in ipairs(optsPanel:getChildren()) do
            optsH = optsH + btn:getHeight()
        end
        optsH = optsH + ((#options - 1) * spacing) + 15
    end
    optsPanel:setHeight(optsH)

    -- 3) Ajusta altura do painel de tarefas
    local taskSpacing = 0
    local tasksH      = 0
    if #tasks > 0 then
        for _, task in ipairs(tasks) do
            local t = g_ui.createWidget("DialogCreature", tasksPanel)
            if task.type == "kill" then
                t.creature:setOutfit({ type = task.lookType })
                t:setTooltip(task.pokemon)
                t.count:setText(task.count)
            else -- deliver
                t:setText(tr("Deliver %dx %s", task.count, task.itemName))
            end
            tasksH = tasksH + t:getHeight()
        end
        tasksH = 64
    end
    tasksPanel:setHeight(tasksH)

    -- 4) Redimensiona o fundo somando texto + opções + tarefas + margens
    local totalH = textH + optsH + tasksH + 40  -- 40 de padding fixo
    msgBg:setHeight(totalH)
    dialogWindow:setHeight(totalH + 60)

    return
end

function sendTalkWithNPC(widget)
    if not widget then
        return
    end

    local optionId = tonumber(widget:getId())
    if not optionId then
        return
    end

    if npcID == nil then
        return
    end

    g_game.sendTalkWithNPC(npcID, optionId, "")
end