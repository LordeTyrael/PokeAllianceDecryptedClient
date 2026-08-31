local stashWindow = nil
local stashLoaded = false
local stashTopButton
local withdrawWindow = nil

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onLootStashList = onLootStashList,
        onLootStashUpdate = onLootStashUpdate
    })

    stashTopButton = modules.client_topmenu.addMiddleGameToggleButton('stashTopButton', tr('Hunt Stash'), '/images/ui/topbuttons/icons/lootstash', toggle)

    stashWindow = g_ui.loadUI('lootstash', modules.game_interface.getFloatLayer())
    stashWindow:setPosition({x = 250, y = 50})
    stashWindow.onMinimize = onMinimize
    stashWindow.onMaximize = onMaximize
    stashWindow:setup()
    DockableWindow.register(stashWindow)
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onLootStashList = onLootStashList,
        onLootStashUpdate = onLootStashUpdate
    })

    if withdrawWindow then
        withdrawWindow:destroy()
        withdrawWindow = nil
    end
    if stashWindow then
        stashWindow:destroy()
        stashWindow = nil
    end
    if stashTopButton then
        stashTopButton:destroy()
        stashTopButton = nil
    end
end

function onMinimize()
    local buttonsPanel = stashWindow:getChildById('buttonsPanel')
    if buttonsPanel then buttonsPanel:hide() end
end

function onMaximize()
    local buttonsPanel = stashWindow:getChildById('buttonsPanel')
    if buttonsPanel then buttonsPanel:show() end
end

function requestOpenStash()
    if not stashLoaded then
        g_game.requestStash()
        return
    end
    show()
end

function requestWithdrawLootStash()
    g_game.requestWithdrawLootStash()
end

function requestStashLootToDepot()
    g_game.requestStashLootToDepot()
end

function show()
    if not stashWindow then return end
    drawStashItems()
    stashWindow:open()
    stashTopButton:setOn(true)
end

function hide()
    if not stashWindow then return end
    stashWindow:close()
    stashTopButton:setOn(false)
end

function onMiniWindowClose()
    if stashTopButton then
        stashTopButton:setOn(false)
    end
end

function toggle()
    if stashWindow and stashWindow:isVisible() then
        hide()
    else
        requestOpenStash()
    end
end

function onGameStart()
    -- the MiniWindow keeps its own open/closed state (&save); if it was left open,
    -- re-fetch and repopulate it on relog since the item list is per-session
    if stashWindow and stashWindow:isExplicitlyVisible() then
        scheduleEvent(function()
            if g_game.isOnline() then requestOpenStash() end
        end)
    end
end

function onGameEnd()
    stashLoaded = false
    -- don't close() here: it would flip the window's persisted state to "closed" and
    -- lose it across relog. Just clear the per-session items and leave the window's
    -- open/closed state as the player left it (onGameStart reopens it if it was open).
    if stashWindow then
        local panel = stashWindow.contentsPanel
        if panel then panel:destroyChildren() end
    end
    if withdrawWindow then
        withdrawWindow:destroy()
        withdrawWindow = nil
    end
end

function setupStashItem(widget, itemName)
    widget:setChangeCursorImage(true)
    widget:setCursor('pointer')
    widget.onClick = function(self)
        withdrawItem(self, itemName)
    end
end

function drawStashItems()
    if not stashWindow then return end
    local panel = stashWindow.contentsPanel
    if not panel then return end
    local player = g_game.getLocalPlayer()
    if not player then return end

    local flow = panel:getLayout()
    flow:disableUpdates()
    panel:destroyChildren()

    for _, entry in ipairs(player:getLootStash()) do
        local widget = g_ui.createWidget('UIItem', panel)
        widget.itemId = entry.itemId
        widget:setItemId(entry.itemId)
        widget:setItemCount(entry.count)
        widget:setVirtual(true)
        widget:setTooltip(entry.itemName)
        setupStashItem(widget, entry.itemName)
    end

    flow:enableUpdates()
    flow:update()
end

function withdrawItem(widget, itemName)
    if withdrawWindow then
        return
    end
    if not widget then
        return
    end

    local clientId = widget.itemId
    local maxCount = widget:getItemCount()
    if not clientId or not maxCount or maxCount <= 0 then
        return
    end

    withdrawWindow = g_ui.createWidget("DepotStashCountWindow", rootWidget)
    local titleText = itemName and itemName:match("^[^\r\n]*")
    withdrawWindow:getChildById("title"):setText((titleText and titleText ~= "") and titleText or tr("Withdraw"))

    local itembox = withdrawWindow:getChildById("item")
    local spinbox = withdrawWindow.countSpinner.field

    itembox:setItemId(clientId)
    itembox:setItemCount(maxCount)

    spinbox:setMinimum(1)
    spinbox:setMaximum(maxCount)
    spinbox:setValue(maxCount)

    spinbox.onValueChange = function(self, value)
        itembox:setItemCount(value)
    end
    itembox:setItemCount(spinbox:getValue())

    local function closeWithdraw()
        if withdrawWindow then
            withdrawWindow:destroy()
            withdrawWindow = nil
        end
    end

    local function confirmWithdraw()
        local amount = spinbox:getValue()
        if amount and amount > 0 then
            g_game.requestWithdrawLootStashItem(clientId, amount)
        end
        closeWithdraw()
    end

    withdrawWindow:setupModal(closeWithdraw)
    spinbox:focus()

    withdrawWindow:getChildById("buttonOk").onClick = confirmWithdraw
    withdrawWindow:getChildById("buttonCancel").onClick = closeWithdraw
    withdrawWindow:getChildById("closeBtn").onClick = closeWithdraw
    withdrawWindow.onEnter = confirmWithdraw
    withdrawWindow.onEscape = closeWithdraw
end

-- opcode GameServerLootStash (257) is parsed in C++ (protocolgameparse), which stores
-- the items in the LocalPlayer and dispatches here via g_game fields.
function onLootStashList()
    stashLoaded = true
    show()
end

-- the item is already updated in the LocalPlayer (C++); this only does the surgical
-- widget update while the window is visible
function onLootStashUpdate(clientId, itemName, cnt)
    if not stashWindow or not stashWindow:isVisible() then
        return
    end

    local panel = stashWindow.contentsPanel
    for _, widget in ipairs(panel:getChildren()) do
        if widget.itemId == clientId then
            if cnt > 0 then
                widget:setItemCount(cnt)
                widget:setTooltip(itemName)
            else
                widget:destroy()
            end
            return
        end
    end

    if cnt > 0 then
        local widget = g_ui.createWidget('UIItem', panel)
        widget.itemId = clientId
        widget:setItemId(clientId)
        widget:setItemCount(cnt)
        widget:setVirtual(true)
        widget:setTooltip(itemName)
        setupStashItem(widget, itemName)
    end
end
