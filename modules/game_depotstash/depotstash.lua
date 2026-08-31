local stashWindow = nil
local quickLoot = nil
local withdrawWindow = nil
local receivedItems = nil

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onOpenDepotStash = onOpenDepotStash,
        onUpdateDepotStashItem = onUpdateDepotStashItem,
    })
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onOpenDepotStash = onOpenDepotStash,
        onUpdateDepotStashItem = onUpdateDepotStashItem,
    })

    destroyStashWindow()
end

function destroyStashWindow()
    closeWithdrawWindow()
    if stashWindow then
        g_uistates.remove(stashWindow)
        stashWindow:destroy()
        stashWindow = nil
    end
    receivedItems = nil
end

function onOpenDepotStash(items)
    if not g_game.isOnline() then
        return
    end

    receivedItems = {}
    for _, item in ipairs(items) do
        local id, name, count = item[1], item[2], item[3]
        table.insert(receivedItems, {
            id = id,
            name = name,
            count = count,
            nameLower = name:lower()
        })
    end

    if not stashWindow then
        stashWindow = g_ui.loadUI('depotstash', modules.game_interface.getRootPanel())
        g_uistates.push(stashWindow)
    end

    createStashWidgets(receivedItems)
    stashWindow.searchItemEdit:focus()
end

function createStashWidgets(items)
    local panel = stashWindow.stashPanel
    local flow = panel:getLayout()
    flow:disableUpdates()

    panel:destroyChildren()

    for _, item in ipairs(items) do
        local widget = g_ui.createWidget('DepotStashItem', panel)
        widget.stashItem.itemId = item.id
        widget.stashItem:setItemId(item.id)
        widget.stashItem:setItemCount(item.count)
        widget:setTooltip(item.name)
    end

    flow:enableUpdates()
    flow:update()
end

function closeWithdrawWindow()
    if not withdrawWindow then
        return
    end
    withdrawWindow:destroy()
    withdrawWindow = nil
end

function withdrawItem(widget)
    if withdrawWindow then
        return
    end

    if not stashWindow or not widget or not widget.stashItem then
        return
    end

    local itemId = widget.stashItem:getItemId()
    local count = widget.stashItem:getItemCount()

    withdrawWindow = g_ui.createWidget("DepotStashCountWindow", rootWidget)
    local itembox = withdrawWindow:getChildById("item")
    local spinbox = withdrawWindow.countSpinner.field
    itembox:setItemId(itemId)
    itembox:setItemCount(count)
    spinbox:setMinimum(1)
    spinbox:setMaximum(count)
    spinbox:setValue(count)
    withdrawWindow:setupModal(closeWithdrawWindow)
    spinbox:focus()

    local okButton = withdrawWindow:getChildById("buttonOk")
    local sendWithdraw = function()
        g_game.requestWithdrawDepotStash(itemId, spinbox:getValue())
        closeWithdrawWindow()
    end
    local cancelButton = withdrawWindow:getChildById("buttonCancel")
    local cancelFunc = closeWithdrawWindow

    spinbox.onValueChange = function(self, value)
        itembox:setItemCount(value)
    end
    itembox:setItemCount(spinbox:getValue())
    withdrawWindow.onEnter = sendWithdraw
    withdrawWindow.onEscape = cancelFunc

    okButton.onClick = sendWithdraw
    cancelButton.onClick = cancelFunc
    withdrawWindow:getChildById("closeBtn").onClick = cancelFunc
end

function changeQuickCollect(widget)
    if not stashWindow or not widget then
        return
    end

    local parent = widget:getParent()
    if not parent then
        return
    end

    local selected = not widget.selected or false
    if selected then
        widget:setImageSource("images/selected_icon")
    else
        widget:setImageSource("images/selected_button_off")
    end

    widget.selected = selected
end


function onGameEnd()
    destroyStashWindow()
end

function onUpdateDepotStashItem(itemId, itemName, newCount)
    if not stashWindow or not stashWindow.stashPanel then
        return
    end

    local panel = stashWindow.stashPanel
    local children = panel:getChildren()

    for _, child in ipairs(children) do
        if child.stashItem and child.stashItem.itemId == itemId then
            if newCount <= 0 then
                child:destroy()
            else
                child.stashItem:setItemCount(newCount)
                child:setTooltip(itemName)
            end
            break
        end
    end

    local found = false
    for i, item in ipairs(receivedItems) do
        if item.id == itemId then
            found = true
            if newCount <= 0 then
                table.remove(receivedItems, i)
            else
                item.count = newCount
                item.name = itemName
                item.nameLower = itemName:lower()
            end
            break
        end
    end

    if not found and newCount > 0 then
        table.insert(receivedItems, {
            id = itemId,
            name = itemName,
            nameLower = itemName:lower(),
            count = newCount
        })

        local widget = g_ui.createWidget('DepotStashItem', panel)
        widget.stashItem.itemId = itemId
        widget.stashItem:setItemId(itemId)
        widget.stashItem:setItemCount(newCount)
        widget:setTooltip(itemName)
    end
end

function onCollectItem(widget)
    if not stashWindow or not widget or not widget.stashItem then
        return
    end

    if widget.stashItem:getClassName() ~= "UIItem" then
        return
    end

    local quickLoot = stashWindow.quickCollectStash and stashWindow.quickCollectStash.selected or false
    if not quickLoot then
        withdrawItem(widget)
        return
    end
    local itemId = widget.stashItem:getItemId() or 0
    local count = widget.stashItem:getItemCount() or 0
    if itemId == 0 or count == 0 then
        print("invalid itemId or count")
        return
    end
    g_game.requestWithdrawDepotStash(itemId, count)
end

function onSearchTextChange(text)
    if not stashWindow or not stashWindow.stashPanel then
        return
    end

    local lowerText = text:lower():trim()
    if lowerText == "" then
        createStashWidgets(receivedItems)
        return
    end

    local filteredItems = {}
    for _, item in ipairs(receivedItems) do
        if item.nameLower:find(lowerText, 1, true) then
            table.insert(filteredItems, item)
        end
    end

    createStashWidgets(filteredItems)
end