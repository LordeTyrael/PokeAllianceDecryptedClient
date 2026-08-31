local incenseWindow = nil
local incensePanel = nil
local quantityWindow = nil
local selectedOption = nil

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = close,
        onAutoWalk = close,
        onPlayerIncense = onPlayerIncense
    })
    incenseWindow = g_ui.loadUI('incense', modules.game_interface.getRootPanel())
    incensePanel = incenseWindow:getChildById("incensePanel")
    incenseWindow:hide()
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = close,
        onAutoWalk = close,
        onPlayerIncense = onPlayerIncense
    })
    if incenseWindow then
        incenseWindow:destroy()
        incenseWindow = nil
    end
    closeQuantityWindow()
end

function onGameEnd()
    close()
end

function close()
    if incenseWindow then
        incenseWindow:hide()
    end
    closeQuantityWindow()
end

function onPlayerIncense(options)
    if not incensePanel then
        return
    end

    incensePanel:destroyChildren()

    for _, itemInfo in ipairs(options) do
        local widget = g_ui.createWidget("IncenseItem", incensePanel)

        local itemWidget = widget:recursiveGetChildById("item")
        if itemWidget then
            itemWidget:setItemId(itemInfo.clientId)
        end

        local itemName = widget:recursiveGetChildById("itemName")
        if itemName then itemName:setText(itemInfo.itemName) end

        local progress = widget:recursiveGetChildById("progress")
        if progress then
            progress:setText(itemInfo.playerIncenses .. "/" .. itemInfo.requiredCount)
        end

        local progressBg = widget:recursiveGetChildById("progressBarBackground")
        local progressFill = widget:recursiveGetChildById("progressBarFill")
        if progressBg and progressFill then
            local percent = 0
            if itemInfo.requiredCount > 0 then
                percent = math.min(1, itemInfo.playerIncenses / itemInfo.requiredCount)
            end
            local barWidth = math.floor(progressBg:getWidth() * percent)
            progressFill:setWidth(barWidth)
        end

        local selectButton = widget:recursiveGetChildById("selectButton")
        if selectButton then
            if itemInfo.playerIncenses < itemInfo.requiredCount then
                selectButton:setEnabled(false)
                selectButton:setOpacity(0.5)
            end
            selectButton.onClick = function()
                openQuantityWindow(itemInfo)
            end
        end
    end

    incenseWindow:show()
    incenseWindow:raise()
    incenseWindow:focus()
end

function openQuantityWindow(option)
    closeQuantityWindow()

    local maxClaims = math.min(10000, math.max(1, math.floor(option.playerIncenses / math.max(1, option.requiredCount))))

    selectedOption = option

    quantityWindow = g_ui.loadUI('incensequantity', modules.game_interface.getRootPanel())
    if not quantityWindow then
        return
    end

    quantityWindow:getChildById("quantityTitle"):setText(option.itemName)
    local item = quantityWindow:getChildById("quantityItem")
    item:setItemId(option.clientId)

    local spinbox = quantityWindow.quantitySpinner.field

    spinbox.onValueChange = function(self, value)
        item:setItemCount(value)
    end
    spinbox:setMinimum(1)
    spinbox:setMaximum(maxClaims)
    spinbox:setValue(1)
    spinbox:focus()

    quantityWindow:show()
    quantityWindow:raise()
    quantityWindow:focus()
end

function closeQuantityWindow()
    if quantityWindow then
        quantityWindow:destroy()
        quantityWindow = nil
    end
    selectedOption = nil
end

function confirmClaim()
    if not quantityWindow or not selectedOption then
        return
    end

    local amount = quantityWindow.quantitySpinner.field:getValue()

    g_game.claimIncense(selectedOption.itemId, amount)
    closeQuantityWindow()
end