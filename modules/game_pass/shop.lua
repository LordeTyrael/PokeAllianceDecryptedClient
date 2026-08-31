local currentShopItems = {}
local shopPurchaseMessageBox

function sendShopRequest()
  g_game.sendGamePassShop()
end

function onGamePassShop(items)
  currentShopItems = items
  populateShopItems(items, "")
end

function populateShopItems(items, filter)
  if not shop then return end

  local shopPanel = shop:getChildById('shopItemsPanel')
  shopPanel:destroyChildren()

  local loading = shop:getChildById('loading')
  loading:hide()

  local lowerFilter = filter and filter:lower() or ""

  for index, item in ipairs(items) do
    local name = item.name
    local itemId = item.itemId
    local count = item.count
    local points = item.points
    local lookType = item.lookType

    if lowerFilter == "" or name:lower():find(lowerFilter, 1, true) then
      local widget = g_ui.createWidget("GamePassShopItemWidget", shopPanel)
      widget:getChildById('itemName'):setText(name)
      widget:recursiveGetChildById('costValue'):setText(points)

      local description = item.description
      if description and description ~= "" then
        widget:setTooltip(description)
      end

      if lookType and lookType > 0 then
        widget:getChildById('itemIcon'):setVisible(false)
        local outfitIcon = widget:getChildById('outfitIcon')
        outfitIcon:setOutfit({type = lookType})
        outfitIcon:setVisible(true)
      elseif itemId and itemId > 0 then
        widget:getChildById('itemIcon'):setItemId(itemId)
      end

      widget.onClick = function()
        purchaseShopItem(index, name, points)
      end
    end
  end
end

function purchaseShopItem(index, name, points)
  if shopPurchaseMessageBox then
    shopPurchaseMessageBox:cancel()
    shopPurchaseMessageBox = nil
  end

  local message = tr("Are you sure you want to buy %s for %d points?", name, points)
  local confirmCallback = function()
    g_game.sendGamePassPurchaseShopItem(index)
    shopPurchaseMessageBox:ok()
    shopPurchaseMessageBox = nil
  end

  local cancelCallback = function()
    shopPurchaseMessageBox:cancel()
    shopPurchaseMessageBox = nil
  end

  shopPurchaseMessageBox = AllianceMessageBox.display(tr("Game Pass Shop"), message, {
    { text = "Ok", callback = confirmCallback },
    { text = "Cancel", callback = cancelCallback },
    anchor = AnchorHorizontalCenter
  }, confirmCallback, cancelCallback)
end

function onShopSearchChange()
  if not shop then return end
  local searchField = shop:getChildById('shopSearchField')
  local searchText = searchField:getText() or ""
  populateShopItems(currentShopItems, searchText)
end