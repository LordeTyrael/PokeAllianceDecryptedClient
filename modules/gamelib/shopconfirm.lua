-- Purchase confirmation shared by every shop (twitch / online / npc trade):
-- item preview, unit or total price and the standard amount spinner.
ShopConfirm = {}

local function formatDefault(value)
  return comma_value2(value)
end

-- opts: title, itemId, itemCount, tooltip, priceIcon, unitPrice, formatPrice,
--       minAmount, maxAmount, amount, confirmText, onConfirm(amount), onClose()
function ShopConfirm.show(opts)
  local window = g_ui.createWidget('BuyItemCountWindow', rootWidget)
  window:getChildById('title'):setText(opts.title or tr('Confirm Buy Item'))

  local itembox = window:getChildById('item')
  itembox:setItemId(opts.itemId or 0)
  itembox:setItemCount(opts.itemCount or 1)
  if opts.tooltip then
    itembox:setTooltip(opts.tooltip)
  end

  local priceIcon = window.priceLabel.priceIcon
  if opts.priceIcon then
    priceIcon:setImageSource(opts.priceIcon)
  elseif opts.priceGlyph then
    priceIcon:setIcon(opts.priceGlyph)
    priceIcon:setIconColor(opts.priceGlyphColor or '#f5c542')
  else
    priceIcon:hide()
  end

  local okButton = window:getChildById('buttonOk')
  if opts.confirmText then
    okButton:setText(opts.confirmText)
  end

  local unitPrice = opts.unitPrice or 0
  local unitCount = opts.itemCount or 1
  local formatPrice = opts.formatPrice or formatDefault
  local priceCost = window.priceLabel.priceCost

  local spinbox = window.countSpinner.field
  spinbox.onValueChange = function(self, value)
    itembox:setItemCount(unitCount * value)
    priceCost:setText(formatPrice(unitPrice * value))
  end
  spinbox:setMinimum(opts.minAmount or 1)
  spinbox:setMaximum(math.max(opts.maxAmount or 1, opts.minAmount or 1))
  spinbox:setValue(opts.amount or opts.minAmount or 1)
  priceCost:setText(formatPrice(unitPrice * spinbox:getValue()))
  spinbox:focus()

  local closeFunc = function()
    window:destroy()
    if opts.onClose then
      opts.onClose()
    end
  end

  window.onEscape = closeFunc
  window:getChildById('buttonCancel').onClick = closeFunc
  window:getChildById('closeBtn').onClick = closeFunc

  local confirmFunc = function()
    local amount = spinbox:getValue()
    closeFunc()
    if opts.onConfirm then
      opts.onConfirm(amount)
    end
  end

  window.onEnter = confirmFunc
  okButton.onClick = confirmFunc

  window:setupModal(closeFunc)
  window:raise()

  return window
end
