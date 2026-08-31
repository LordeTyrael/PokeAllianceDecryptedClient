linkedTasks = {}

local linkedTasksWindow
local linkedTasksButton
local taskPanels = {}
local currentTasks = {}
local highestUnlockedTaskId = 0
local activeTaskId = 0

modules.client_hotkeys.registerHotkeyCallback("LINKED_TASKS",
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
    linkedTasksButton = modules.client_topmenu.addMiddleGameToggleButton('linkedTasksButton',
        tr('Linked Tasks') .. ' (Ctrl+L)', '/images/ui/topbuttons/icons/links', toggle)
    linkedTasksButton:setOn(false)

    connect(g_game, {
        onGameEnd = onGameEnd,
        onLinkedTasks = onReceiveLinkedTasks,
        onLinkedTaskTrackerUpdateCount = onTrackerUpdateCount
    })
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onLinkedTasks = onReceiveLinkedTasks,
        onLinkedTaskTrackerUpdateCount = onTrackerUpdateCount
    })

    if linkedTasksButton then
        linkedTasksButton:destroy()
        linkedTasksButton = nil
    end

    hide()
end

function onGameStart()
    -- Request tasks when game starts
    scheduleEvent(function()
        g_game.openLinkedTasks()
    end, 1000)
end

function onGameEnd()
    hide()
end

function show()
    if not g_game.isOnline() then
        return
    end

    if linkedTasksWindow then
        linkedTasksWindow:destroy()
        linkedTasksWindow = nil
    end

    linkedTasksWindow = g_ui.loadUI('linkedtasks', modules.game_interface.getRootPanel())

    if linkedTasksButton then
        linkedTasksButton:setOn(true)
    end

    -- Request tasks from server
    g_game.openLinkedTasks()
end

function hide()
    if cancelConfirmBox then
        cancelConfirmBox:destroy()
        cancelConfirmBox = nil
    end

    if linkedTasksWindow then
        linkedTasksWindow:destroy()
        linkedTasksWindow = nil
    end

    if linkedTasksButton then
        linkedTasksButton:setOn(false)
    end

    taskPanels = {}
    currentTasks = {}
end

function toggle()
    if linkedTasksWindow and linkedTasksWindow:isVisible() then
        hide()
    else
        show()
    end
end

function onReceiveLinkedTasks(tasks, highestUnlocked, activeTask)
    if not tasks then
        return
    end

    currentTasks = tasks
    highestUnlockedTaskId = highestUnlocked or 0
    activeTaskId = activeTask or 0

    if linkedTasksWindow then
        refreshTaskList()
    end
end

function refreshTaskList()
    if not linkedTasksWindow then
        return
    end

    local taskList = linkedTasksWindow:getChildById('taskList')
    if not taskList then
        return
    end

    taskList:destroyChildren()
    taskPanels = {}

    -- Sort: active first, then favorited, then rest (by original order)
    local sorted = {}
    for i, task in ipairs(currentTasks) do
        table.insert(sorted, {index = i, task = task})
    end
    table.sort(sorted, function(a, b)
        local taskA = a.task
        local taskB = b.task
        -- Active first
        if taskA.isActive and not taskB.isActive then return true end
        if not taskA.isActive and taskB.isActive then return false end
        -- Then favorited
        if taskA.isFavorited and not taskB.isFavorited then return true end
        if not taskA.isFavorited and taskB.isFavorited then return false end
        -- Then by original order
        return a.index < b.index
    end)

    for _, entry in ipairs(sorted) do
        local taskPanel = createTaskPanel(entry.task)
        taskList:addChild(taskPanel)
        taskPanels[entry.task.id] = taskPanel
    end
end

function createTaskPanel(task)
    local panel = g_ui.createWidget('TaskPanel', nil)
    
    -- Task Name
    local nameLabel = panel:getChildById('taskName')
    if nameLabel then
        nameLabel:setText(task.name)
    end

    -- Task Description
    local descLabel = panel:getChildById('taskDescription')
    if descLabel then
        descLabel:setText(task.description)
    end

    -- Monster Name
    local monsterOutfit = panel:getChildById('outfit')
    if monsterOutfit then
        monsterOutfit:setOutfit({type = task.monsterLookType})
    end

    -- Progress
    local progressLabel = panel:recursiveGetChildById('taskProgress')
    if progressLabel then
        local remaining = (task.requiredCount or 0) - (task.currentCount or 0)
        if remaining < 0 then remaining = 0 end
        local progressText = tostring(remaining)
        if not task.isActive then
            progressText = string.format('%d', task.requiredCount)
        end
        progressLabel:setText(progressText)
        
        -- Color based on completion
        if task.isActive and remaining == 0 then
            progressLabel:setColor('#00ff00') -- Green if active and completed
        else
            progressLabel:setColor('#ffffff')
        end
    end

    -- Status
    if task.isActive then
        panel:setImageSource("/images/newui/background")
    end

    -- Chest with rewards tooltip
    local chest = panel:getChildById('chest')
    if chest then
        local reward = task.reward
        local rewardsTooltip = g_ui.createWidget('RewardsTooltip', modules.game_interface.getRootPanel())
        local rewardsPanel = rewardsTooltip:getChildById('rewards')
        
        -- Add experience as item
        if reward.experience and reward.experience > 0 then
            local itemWidget = g_ui.createWidget('ItemSlot', rewardsPanel)
            itemWidget:setItemId(29839) -- EXP item
            itemWidget:setItemCount(reward.experience)
        end
        
        -- Add money as item (if you have a money item id)
        if reward.money and reward.money > 0 then
            local itemWidget = g_ui.createWidget('ItemSlot', rewardsPanel)
            itemWidget:setItemId(3031) -- Gold coin item (you can change this)
            itemWidget:setItemCount(reward.money)
        end
        
        -- Add reward items
        if reward.items and #reward.items > 0 then
            for _, rewardItem in ipairs(reward.items) do
                local itemWidget = g_ui.createWidget('ItemSlot', rewardsPanel)
                itemWidget:setItemId(rewardItem.id)
                itemWidget:setItemCount(rewardItem.count or 1)
            end
        end
        
        -- Adjust rewards panel height based on item count
        local totalRewards = 0
        if reward.experience and reward.experience > 0 then totalRewards = totalRewards + 1 end
        if reward.money and reward.money > 0 then totalRewards = totalRewards + 1 end
        if reward.items then totalRewards = totalRewards + #reward.items end
        
        if totalRewards > 4 then
            local itemsPerRow = 4
            local rows = math.ceil(totalRewards / itemsPerRow)
            local itemHeight = 36
            local spacing = 2
            local newPanelHeight = (itemHeight * rows) + (spacing * (rows - 1))
            rewardsPanel:setHeight(newPanelHeight)
        end
        
        chest:setTooltip(rewardsTooltip)
        chest:show()
    end

    -- Start Button
    local startButton = panel:getChildById('startButton')
    local cancelButton = panel:getChildById('cancelButton')

    if startButton and cancelButton then
        if task.isActive then
            -- Active task: show cancel, hide start
            startButton:setVisible(false)
            cancelButton:setVisible(true)
            cancelButton.onClick = function()
                showCancelConfirmation(task)
            end
        elseif task.currentCount >= task.requiredCount and (task.currentCount > 0) then
            -- Completed task ready to claim
            startButton:setText('Claim')
            startButton:setEnabled(activeTaskId == 0)
            startButton:setOpacity(activeTaskId == 0 and 1.0 or 0.4)
            cancelButton:setVisible(false)
            startButton.onClick = function()
                g_game.startLinkedTask(task.id)
            end
        else
            -- Normal task: disable if another is active
            startButton:setText('Start')
            startButton:setEnabled(activeTaskId == 0)
            startButton:setOpacity(activeTaskId == 0 and 1.0 or 0.4)
            cancelButton:setVisible(false)
            startButton.onClick = function()
                g_game.startLinkedTask(task.id)
            end
        end
    end

    -- Favorite Button
    local favoriteButton = panel:getChildById('favoriteButton')
    if favoriteButton then
        favoriteButton:setImageSource(task.isFavorited and '/images/modules/selected_star' or '/images/modules/empty_star')
        favoriteButton.onClick = function()
            task.isFavorited = not task.isFavorited
            favoriteButton:setImageSource(task.isFavorited and '/images/modules/selected_star' or '/images/modules/empty_star')
            g_game.toggleLinkedTaskFavorite(task.id)
        end
    end

    return panel
end

local cancelConfirmBox = nil

function showCancelConfirmation(task)
    if cancelConfirmBox then
        cancelConfirmBox:destroy()
        cancelConfirmBox = nil
    end

    cancelConfirmBox = displayAllianceBox(
        tr('Cancel Task'),
        tr('Are you sure you want to cancel "%s"?\nAll progress will be lost!', task.name),
        {
            anchor = AnchorHorizontalCenter,
            { text = tr('Yes, Cancel'), callback = function()
                g_game.cancelLinkedTask(task.id)
                cancelConfirmBox:destroy()
                cancelConfirmBox = nil
            end },
            { text = tr('No'), callback = function()
                cancelConfirmBox:destroy()
                cancelConfirmBox = nil
            end }
        }
    )
end

function onTrackerUpdateCount(currentCount, requiredCount)
    if activeTaskId == 0 then return end

    -- Update local task data
    for _, task in ipairs(currentTasks) do
        if task.id == activeTaskId then
            task.currentCount = currentCount
            break
        end
    end

    local remaining = (requiredCount or 0) - (currentCount or 0)
    if remaining < 0 then remaining = 0 end

    if remaining == 0 then
        -- Task completed: deactivate and re-sort to original position
        for _, task in ipairs(currentTasks) do
            if task.id == activeTaskId then
                task.isActive = false
                break
            end
        end
        activeTaskId = 0
        refreshTaskList()
        return
    end

    local panel = taskPanels[activeTaskId]
    if not panel then return end

    local progressLabel = panel:recursiveGetChildById('taskProgress')
    if not progressLabel then return end

    progressLabel:setText(tostring(remaining))
end
