local mainWindow
local dailiesTopButton
local TasksInfos = {}
local totalDailyTypes = 2
local confirmWindow
local selectWindow
local selectConfirmWindow
local shopWindow
local shopConfirmWindow
local dailyShopItems = {}
local shopPoints = 0

local taskTitles = {
    [1] = "Daily Kill",
    [2] = "Daily Catch"
}

local displacementConfig = {
    ["Celebi"] = {
        x = -5
    },
    ["Houndoom"] = {
        x = 5,
        y = 3
    }
}

local function applyTaskToWidget(task)
    if not mainWindow or not task then
        return
    end
    local widgetType = task.taskType
    local widget = mainWindow.tasksPanel:getChildById(widgetType)
    local pokemon = task.pokemons and task.pokemons[1]
    if not pokemon or not widget then
        return
    end

    widget.refreshDiamond:setVisible(true)
    widget.refreshOnlinePoints:setVisible(true)
    widget.refreshCash:setVisible(true)
    widget.button:hide()

    local outfit = {type = pokemon.lookType}
    widget.outfit:setOutfit(outfit)
    widget.outfit:setMarginBottom(0)
    widget.outfit:setMarginLeft(0)
    local outfitConfig = displacementConfig[pokemon.name]
    if outfitConfig then
        if outfitConfig.x then
            widget.outfit:setMarginLeft(outfitConfig.x)
        end
        if outfitConfig.y then
            widget.outfit:setMarginTop(outfitConfig.y)
        end
    end

    local leftCount = math.max(0, task.totalRequired - task.totalCompleted)
    if leftCount > 0 then
        local text
        if widgetType == 1 then
            text = tr("Need to defeat more %d %s.", leftCount, pokemon.name)
        else
            text = tr("Need to capture more %d %s.", leftCount, pokemon.name)
        end
        widget.completeDaily:setVisible(false)
        widget:setTooltip(text)
        widget.description:setText(text)
    else
        widget.completeDaily:setVisible(true)
        widget:setTooltip("")
        widget.description:setText("")
    end
end

local function buildTaskWidgets()
    if not mainWindow then
        return
    end

    mainWindow.tasksPanel:destroyChildren()
    for i = 1, totalDailyTypes do
        local widget = g_ui.createWidget("MissionWidget", mainWindow.tasksPanel)
        widget:setId(i)
        widget.taskTitle:setText(tr(taskTitles[i] or ""))
    end
end

local function onPlayerDailyTasks(tasks)
    if not mainWindow then
        return
    end
    TasksInfos = tasks or {}

    buildTaskWidgets()

    for _, task in ipairs(TasksInfos) do
        applyTaskToWidget(task)
    end
end

local function onPlayerDailyTask(task)
    if not mainWindow or not task then
        return
    end

    for index, existing in ipairs(TasksInfos) do
        if existing.taskType == task.taskType then
            table.remove(TasksInfos, index)
            break
        end
    end
    table.insert(TasksInfos, task)

    applyTaskToWidget(task)
end

local function onPlayerDailyTaskProgress(taskType, totalCompleted)
    if not mainWindow then
        return
    end

    local task = nil
    for _, t in ipairs(TasksInfos) do
        if t.taskType == taskType then
            t.totalCompleted = totalCompleted
            task = t
            break
        end
    end

    if task then
        applyTaskToWidget(task)
    end
end

local function onPlayerDailyShopItems(items)
    dailyShopItems = items or {}
end

local function onGameStart()
    if not mainWindow then
        return
    end
    mainWindow:hide()
    hideSelectDaily()
end

local function onGameEnd()
    if not mainWindow then return end
    mainWindow:hide()
    hideSelectDaily()
    dailiesTopButton:setOn(false)
    loaded = false

    if shopWindow then
        shopWindow:destroy()
        shopWindow = nil
        modules.game_walking.enableClientWalk()
    end
end

local function connecting(gameEvent)
    if gameEvent then
        connect(g_game, {
            onGameEnd = onGameEnd,
            onGameStart = onGameStart,
            onPlayerDailyTasks = onPlayerDailyTasks,
            onPlayerDailyTask = onPlayerDailyTask,
            onPlayerDailyTaskProgress = onPlayerDailyTaskProgress,
            onPlayerDailyShopItems = onPlayerDailyShopItems
        })
        connect(LocalPlayer, {
            onDailyPointsChange = onDailyPointsChange
        })
    end
    return true
end

local function disconnecting(gameEvent)
    if gameEvent then
        disconnect(g_game, {
            onGameEnd = onGameEnd,
            onGameStart = onGameStart,
            onPlayerDailyTasks = onPlayerDailyTasks,
            onPlayerDailyTask = onPlayerDailyTask,
            onPlayerDailyTaskProgress = onPlayerDailyTaskProgress,
            onPlayerDailyShopItems = onPlayerDailyShopItems
        })
        disconnect(LocalPlayer, {
            onDailyPointsChange = onDailyPointsChange
        })
    end
    return true
end

function init()
    connecting(true)
    mainWindow = g_ui.loadUI('dailies', modules.game_interface.getRootPanel())
    selectWindow = g_ui.loadUI('selectdaily', mainWindow)
    buildTaskWidgets()
    dailiesTopButton = modules.client_topmenu.addMiddleGameToggleButton('dailiesTopButton', tr('Dailies') .. '', '/images/ui/topbuttons/icons/daily', toggle)
    mainWindow:hide()
end

function terminate()
    disconnecting(true)
end

function toggle()
    if dailiesTopButton:isOn() then
        close()
    else
        mainWindow:focus()
        mainWindow:show()
        dailiesTopButton:setOn(true)
    end
end

function close()
    mainWindow:hide()
    if confirmWindow then
        confirmWindow:destroy()
    end
    hideSelectDaily()
    dailiesTopButton:setOn(false)
end

function buyDailyItemShop(index, itemConfig)
    if not shopWindow or shopConfirmWindow then
        return
    end

    local price = tonumber(itemConfig.price) or 0
    if price <= 0 then
        return
    end

    local affordable = math.floor(shopPoints / price)
    shopConfirmWindow = ShopConfirm.show({
        title = tr("Confirm Buy"),
        itemId = itemConfig.itemId,
        itemCount = itemConfig.count,
        tooltip = itemConfig.description,
        priceIcon = "/game_dailies/images/daily_coin",
        unitPrice = price,
        maxAmount = math.min(10000, math.max(1, affordable)),
        onConfirm = function(amount)
            shopConfirmWindow = nil
            g_game.sendBuyDailyShopItem(index, itemConfig.itemId, amount)
        end,
        onClose = function()
            shopConfirmWindow = nil
        end,
    })
end

function confirmChangeDaily(widget, type)
    if confirmWindow then
        return
    end

    local typeTable = {
        [1] = "1 Diamond",
        [2] = "50 Online Points",
        [3] = "200k"
    }

    local text = typeTable[type]
    if not text then
        return
    end

    local sendWidget = widget:getParent()
    if not sendWidget then
        sendWidget = widget
    end

    confirmWindow = displayGeneralBox(tr('Confirm'), tr("Are you sure you want to refresh your Daily for "..text.."?"), {
        {
            text = tr('Yes'),
            callback = confirmChoice
        },
        {
            text = tr('No'),
            callback = confirmWindowCleanup
        },
        anchor = AnchorHorizontalCenter
    }, confirmChoice, confirmWindowCleanup)
    confirmWindow.currencyType = type
    confirmWindow.choiceType = sendWidget:getId()
end

function confirmWindowCleanup()
    if confirmWindow then
        confirmWindow:destroy()
        confirmWindow = nil
    end
end

function confirmChoice(index)
    local currencyType = confirmWindow.currencyType
    local choiceType = confirmWindow.choiceType

    g_game.refreshDaily(currencyType, choiceType)
    confirmWindowCleanup()
end

function openDailySelect(widget)
    if not selectWindow or not widget then
        return
    end
    selectWindow:show()
    selectWindow.type = widget:getParent():getId()
end

function hideSelectDaily()
    if not selectWindow then
        return
    end
    selectWindow:hide()
end

function confirmSelectDificulty(widget, difficulty)
    if selectConfirmWindow then
        return
    end

    local typeTable = {
        [1] = "Easy",
        [2] = "Medium",
        [3] = "Hard"
    }

    local text = typeTable[difficulty]
    if not text then
        return
    end

    local sendWidget = widget:getParent()
    if not sendWidget then
        sendWidget = widget
    end

    selectConfirmWindow = displayGeneralBox(tr('Confirm'), tr("Are you sure you want to choose the "..text.." difficulty?"), {
        {
            text = tr('Yes'),
            callback = confirmSelectChoice
        },
        {
            text = tr('No'),
            callback = selectConfirmWindowCleanup
        },
        anchor = AnchorHorizontalCenter
    }, confirmSelectChoice, selectConfirmWindowCleanup)
    selectConfirmWindow.choiceType = sendWidget.type
    selectConfirmWindow.difficulty = difficulty
end

function selectConfirmWindowCleanup()
    if selectConfirmWindow then
        selectConfirmWindow:destroy()
        selectConfirmWindow = nil
    end
    hideSelectDaily()
end

function confirmSelectChoice()
    local choiceType = selectConfirmWindow.choiceType
    local difficulty = selectConfirmWindow.difficulty

    g_game.selectDaily(choiceType, difficulty)
    selectConfirmWindowCleanup()
end

function collectDailyReward(widget)
    local type = widget:getParent():getId()
    g_game.completeDaily(type)
end

function onDailyPointsChange(localplayer, points)
    mainWindow.playerPoints:setText(points)
    shopPoints = points
    if shopWindow and shopWindow:isVisible() then
        shopWindow.coinCount:setText(comma_value2(shopPoints))
    end
end

function closeDailyShopWindow()
    if not shopWindow then
        return
    end

    if shopConfirmWindow then
        shopConfirmWindow:destroy()
        shopConfirmWindow = nil
    end

    shopWindow:destroy()
    shopWindow = nil
    modules.game_walking.enableClientWalk()
end

function openDailyShopWindow()
    if not shopWindow then
        shopWindow = g_ui.loadUI("daily_shop", modules.game_interface.getRootPanel())
    end

    shopWindow:show()
    local layout = shopWindow.shopPanel:getLayout()
    layout:disableUpdates()
    shopWindow.shopPanel:destroyChildren()
    for index, itemConfig in ipairs(dailyShopItems) do
        local itemWidget = g_ui.createWidget('DailyShopItem', shopWindow.shopPanel)
        itemWidget.shopIndex = index
        itemWidget.item:setItemId(itemConfig.itemId)
        itemWidget.item:setItemCount(itemConfig.count)
        itemWidget:setTooltip(itemConfig.description)
        itemWidget.name:setText(itemConfig.count > 1 and tr("%dx %s", itemConfig.count, itemConfig.name) or itemConfig.name)
        itemWidget.price:setText(comma_value2(itemConfig.price))
        itemWidget.buyWidget.onClick = function() buyDailyItemShop(index, itemConfig) end
    end

    shopWindow.coinCount:setText(comma_value2(shopPoints))
    layout:enableUpdates()
    layout:update()
    shopWindow:raise()

    modules.game_walking.disableClientWalk()
end