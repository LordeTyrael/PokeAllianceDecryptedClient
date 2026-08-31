local shopWindow
local mainShopButton = nil
local coinCount = 0
local confirmShopWindow = nil
local shopItems = nil
local pendingOpen = false  -- esperando o servidor responder o request

OnlineShop = {}

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onOnlineShopItems = onReceiveItems,
    })

    connect(LocalPlayer, {
        onOnlinePointsChange = onOnlinePointsChange
    })

    -- Sem botao proprio na topbar desde 2026-08: virou entrada do menu do botao Store
    -- (game_store.getShopMenuEntries chama este toggleTopButton). Os `if mainShopButton then ...`
    -- espalhados pelo arquivo ficam inertes de proposito, para o dia em que o botao voltar.
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onOnlineShopItems = onReceiveItems,
    })
    disconnect(LocalPlayer, {
        onOnlinePointsChange = onOnlinePointsChange
    })
    destroyOnlineShop()
    if mainShopButton then mainShopButton:destroy() mainShopButton = nil end
end

function onGameStart()
end

function onGameEnd()
    shopItems = nil
    pendingOpen = false
    destroyOnlineShop()
end

function onReceiveItems(items)
    shopItems = items
    if pendingOpen then
        pendingOpen = false
        drawOnlineShop()
    end
end

function toggleTopButton()
    if shopWindow and shopWindow:isVisible() then
        destroyOnlineShop()
        return
    end

    -- Sem cache local ainda — peca a lista ao servidor e abre quando chegar.
    if not shopItems then
        pendingOpen = true
        g_game.onlineShopRequestItems()
        return
    end

    drawOnlineShop()
end

function destroyOnlineShop()
    if shopWindow then
        shopWindow:destroy()
        shopWindow = nil
    end

    if confirmShopWindow then
        confirmShopWindow:destroy()
        confirmShopWindow = nil
    end

    if mainShopButton then mainShopButton:setOn(false) end
end

function drawOnlineShop()
    if shopWindow then
        shopWindow:destroy()
        shopWindow = nil
    end

    if not shopItems or #shopItems == 0 then
        return
    end

    shopWindow = g_ui.loadUI("onlineshop", modules.game_interface.getRootPanel())
    if mainShopButton then mainShopButton:setOn(true) end
    local layout = shopWindow.shopPanel:getLayout()
    layout:disableUpdates()
    shopWindow.shopPanel:destroyChildren()
    for _, itemConfig in ipairs(shopItems) do
        local itemWidget = g_ui.createWidget('OnlineShopItem', shopWindow.shopPanel)
        itemWidget.shopId = itemConfig.id
        itemWidget:setTooltip(itemConfig.description)
        itemWidget.item:setItemId(itemConfig.clientId)
        itemWidget.item:setItemCount(itemConfig.count)
        itemWidget.name:setText(itemConfig.name)
        itemWidget.price:setText(itemConfig.price)
        itemWidget.buyWidget.onClick = function() buyOnlineItemShop(itemConfig) end
    end
    shopWindow.playerPoints:setText(comma_value2(coinCount))
    layout:enableUpdates()
    layout:update()
    shopWindow:raise()
end

function destroyConfirmShopWindow()
    if confirmShopWindow then
        confirmShopWindow:destroy()
        confirmShopWindow = nil
    end
end

function buyOnlineItemShop(itemConfig)
    if not shopWindow or confirmShopWindow then
        return
    end

    local unitPrice = tonumber(itemConfig.price) or 0
    if unitPrice <= 0 then
        return
    end

    local affordable = math.floor(coinCount / unitPrice)
    confirmShopWindow = ShopConfirm.show({
        title = tr("Confirm Buy"),
        itemId = itemConfig.clientId,
        itemCount = itemConfig.count,
        tooltip = itemConfig.description,
        priceIcon = "/game_onlineshop/images/item_currency_icon",
        unitPrice = unitPrice,
        maxAmount = math.min(10000, math.max(1, affordable)),
        onConfirm = function(amount)
            confirmShopWindow = nil
            g_game.onlineShopBuy(itemConfig.id, amount)
        end,
        onClose = function()
            confirmShopWindow = nil
        end,
    })
end

function onOnlinePointsChange(localPlayer, value)
    coinCount = value
    if shopWindow and shopWindow:isVisible() then
        shopWindow.playerPoints:setText(comma_value2(value))
    end
end
