local builderKitWindow = nil

local imageConfigs = {
    ["Grounds"] = "images/ground_icon"
}

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onWalk = onGameEnd,
        onAutoWalk = onGameEnd,
        onBuilderKitData = onReceiveBuilderKit
    })
    builderKitWindow = g_ui.loadUI("builderkit", modules.game_interface.getRootPanel())
    builderKitWindow:hide()
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onWalk = onGameEnd,
        onAutoWalk = onGameEnd,
        onBuilderKitData = onReceiveBuilderKit
    })
    if builderKitWindow then
        if builderKitWindow.event then
            removeEvent(builderKitWindow.event)
        end
        builderKitWindow:destroy()
    end
end

function onGameStart()
end

function onReceiveBuilderKit(currentGroundId, categories)
    if builderKitWindow:isVisible() then
        return
    end

    if not categories or #categories == 0 then
        return
    end

    local categoriesPanel = builderKitWindow.categories.categories_panel
    if not categoriesPanel then
        return
    end

    local tilesPanel = builderKitWindow.category_info.availableTiles
    if not tilesPanel then
        return
    end

    local newFloorPanel = builderKitWindow.category_info.new_floor_tiles
    if not newFloorPanel then
        return
    end

    categoriesPanel:destroyChildren()
    tilesPanel:destroyChildren()
    for _, entry in ipairs(categories) do
        local categoryName = entry[1]
        local ids = entry[2]
        local categoriesButton = g_ui.createWidget("CategoryWidget", categoriesPanel)
        categoriesButton.category_name:setText(categoryName)
        local imageConfig = imageConfigs[categoryName]
        if imageConfig then
            categoriesButton.category_icon:setImageSource(imageConfig)
        end
        local i = 1
        for _, clientId in ipairs(ids) do
            local groundButtons = g_ui.createWidget("UIItem", tilesPanel)
            if i == 1 then
                groundButtons:setBorderWidth(3)
                groundButtons:setBorderColor("#62b5bd")
                groundButtons:focus()
                newFloorPanel:destroyChildren()
                for j = 1, 20 do
                    local groundItem = g_ui.createWidget("UIItem", newFloorPanel)
                    groundItem:setDraggable(false)
                    groundItem:setItemId(clientId)
                end
            end
            groundButtons:setBackgroundColor("#0123ff")
            groundButtons:setSize("32 32")
            groundButtons.onClick = function()
                if not newFloorPanel then
                    return
                end
                newFloorPanel:destroyChildren()
                for j = 1, 20 do
                    local groundItem = g_ui.createWidget("UIItem", newFloorPanel)
                    groundItem:setDraggable(false)
                    groundItem:setItemId(clientId)
                end
            end
            groundButtons:setDraggable(false)
            groundButtons.onFocusChange = function(widget, focused)
                if focused then
                    widget:setBorderWidth(3)
                    widget:setBorderColor("#62b5bd")
                else
                    widget:setBorderWidth(0)
                end
            end
            groundButtons:setItemId(clientId)
            i = i + 1
        end
    end

    if currentGroundId and currentGroundId > 0 then
        local groundPanel = builderKitWindow.category_info.current_floor_tiles
        if groundPanel then
            groundPanel:destroyChildren()
            for i = 1, 20 do
                local groundItem = g_ui.createWidget("UIItem", groundPanel)
                groundItem:setDraggable(false)
                groundItem:setItemId(currentGroundId)
            end
        end
    end
    show()
end

function onGameEnd()
    hide()
end

function show()
    if not builderKitWindow:isVisible() then
      addEvent(function() g_effects.fadeIn(builderKitWindow) end)
    end
    builderKitWindow:show()
    builderKitWindow:focus()
    g_effects.fadeIn(builderKitWindow)
end

function hide()
    addEvent(function() g_effects.fadeOut(builderKitWindow) end)
    scheduleEvent(function() builderKitWindow:hide() end, 250)
end

function sendChangeFloor(preview)
    if not builderKitWindow or not builderKitWindow.category_info.availableTiles then
        return
    end

    local selectedWidget = builderKitWindow.category_info.availableTiles:getFocusedChild()
    if not selectedWidget then
        return
    end

    local selectedGround = selectedWidget:getItemId()
    g_game.builderKitChangeFloor(preview and 1 or 0, selectedGround)
    hide()
end
