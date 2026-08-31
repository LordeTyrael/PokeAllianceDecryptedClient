local twitchShopWindow, confirmWindow
local twitchShopItems = nil
local twitchPoints = 0
local twitchTopButton = nil
local categories = {
    ["exclusives"] = 1,
    ["market"] = 2,
    ["clothes"] = 3,
    ["addons"] = 4,
    ["decorations"] = 5,
}

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onTwitchShop = onTwitchShop,
        onUpdateTwitchPoints = onUpdateTwitchPoints
    })

end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onTwitchShop = onTwitchShop,
        onUpdateTwitchPoints = onUpdateTwitchPoints
    })
end

function onGameStart()
    -- Sem botao proprio na topbar desde 2026-08: virou entrada do menu do botao Store
    -- (game_store.getShopMenuEntries chama este toggle). Os `if twitchTopButton then ...` do
    -- onGameEnd ficam inertes de proposito, para o dia em que o botao voltar.
end

function onGameEnd()
    if twitchShopWindow then
        twitchShopWindow:destroy()
        twitchShopWindow = nil
    end

    twitchShopItems = nil
    if twitchTopButton then
        twitchTopButton:destroy()
        twitchTopButton = nil
    end

    if confirmWindow then
        confirmWindow:destroy()
        confirmWindow = nil
    end
end

function toggle()
  if twitchShopWindow and twitchShopWindow:isVisible() then
    close()
  else
    requestOpenTwitchShop()
  end
end

function requestOpenTwitchShop()
    if not twitchShopItems then
        g_game.requestTwitchShop()
        return
    end
    g_game.requestTwitchPoints()
    show()
end

function show()
    twitchShopWindow = g_ui.loadUI("twitchshop", modules.game_interface.getRootPanel())
    twitchShopWindow.categoriesPanel.exclusives:focus()
    if twitchShopItems then
        renderByCategory("exclusives")
        twitchShopWindow.twitchPanel.twitchPoints:setText(comma_value2(twitchPoints))
    end
end

function renderByCategory(category)
    local categoryIndex = categories[category]
    if not categoryIndex then
        return
    end
    local panel  = twitchShopWindow.shop_panel
    local layout = panel:getLayout()
    
    layout:disableUpdates()
    panel:destroyChildren()
    
    for index, info in ipairs(twitchShopItems) do
      if info.category == categoryIndex then
        local itemWidget = g_ui.createWidget("TwitchShopItem", panel)
        itemWidget.shopItemIndex = index
        itemWidget.categoryIndex = categoryIndex
        itemWidget.item:setItemId(info.clientId)
        itemWidget.item:setItemCount(info.count)
        itemWidget:setTooltip(info.itemDescription)
        itemWidget.name:setText(info.count .. "x " ..info.itemName)
        itemWidget.price:setText(comma_value2(info.itemPrice))
        itemWidget.buyWidget.onClick = function() buyItem(itemWidget) end
      end
    end
    
    layout:enableUpdates()
    layout:update()
end

function onTwitchShop(shopInfo, points)
    twitchShopItems = shopInfo
    twitchPoints = points
    show()
end

function onUpdateTwitchPoints(points)
    twitchPoints = points
    if twitchShopWindow and twitchShopWindow:isVisible() then
        twitchShopWindow.twitchPanel.twitchPoints:setText(comma_value2(twitchPoints))
    end
end

function close()
    if twitchShopWindow then
        twitchShopWindow:destroy()
        twitchShopWindow = nil
    end
end

function buyItem(card)
    if confirmWindow then
        return
    end

    if not card then
        return
    end

    local itemIndex = card.shopItemIndex
    if not itemIndex then
        return
    end

    local categoryIndex = card.categoryIndex
    if not categoryIndex then
        return
    end

    local info = twitchShopItems[itemIndex]
    if not info then
        return
    end

    local clientId = card.item:getItemId()
    local itemCount = card.item:getItemCount()

    confirmWindow = ShopConfirm.show({
        title = tr("Confirm Buy Item"),
        itemId = clientId,
        itemCount = itemCount,
        tooltip = info.count .. "x " .. info.itemName,
        priceIcon = "/game_twitchshop/images/twitch_icon",
        unitPrice = info.itemPrice,
        maxAmount = 10000,
        onConfirm = function(amount)
            g_game.sendBuyTwitchShopItem(categoryIndex, itemIndex, clientId, amount)
            confirmWindow = nil
        end,
        onClose = function()
            confirmWindow = nil
        end,
    })
end
