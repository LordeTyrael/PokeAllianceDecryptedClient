cachedConversion = {
  moneyCost = 0,
  stones = {},
}

local conversionWindow = nil
local quantityWindow = nil
local selectedSourceItemId = nil
local selectedTargetItemId = nil

local function getStoneCount(stone)
  return modules.game_playeractionbar.getPlayerItemCount(stone.clientId)
end

local function getStoneByItemId(itemId)
  for _, stone in ipairs(cachedConversion.stones) do
    if stone.itemId == itemId then
      return stone
    end
  end
  return nil
end

local function clearGrid(gridWidget)
  if not gridWidget then
    return
  end
  for _, child in pairs(gridWidget:getChildren()) do
    child:destroy()
  end
end

local function highlightSlot(slot, on)
  if not slot or slot:isDestroyed() then
    return
  end
  slot:setBackgroundColor(on and '#ffffff40' or '#00000000')
end

local function refreshTargetGrid()
  if not conversionWindow then
    return
  end
  local targetGrid = conversionWindow:recursiveGetChildById('targetGrid')
  clearGrid(targetGrid)

  for _, stone in ipairs(cachedConversion.stones) do
    if stone.itemId ~= selectedSourceItemId then
      local slot = g_ui.createWidget('ConversionItemSlot', targetGrid)
      slot:setItemId(stone.clientId)
      slot:setTooltip(stone.itemName)
      slot:setFocusable(true)
      slot.itemId = stone.itemId

      slot.onClick = function(widget)
        for _, c in pairs(targetGrid:getChildren()) do
          highlightSlot(c, false)
        end
        highlightSlot(widget, true)
        selectedTargetItemId = stone.itemId
      end
    end
  end

  if selectedTargetItemId then
    for _, c in pairs(targetGrid:getChildren()) do
      if c.itemId == selectedTargetItemId then
        highlightSlot(c, true)
        return
      end
    end
    selectedTargetItemId = nil
  end
end

local function refreshSourceGrid()
  if not conversionWindow then
    return
  end
  local sourceGrid = conversionWindow:recursiveGetChildById('sourceGrid')
  clearGrid(sourceGrid)

  local sourceStillPresent = false
  for _, stone in ipairs(cachedConversion.stones) do
    local count = getStoneCount(stone)
    if count > 0 then
      local slot = g_ui.createWidget('ConversionItemSlot', sourceGrid)
      slot:setItemId(stone.clientId)
      slot:setTooltip(stone.itemName .. " (" .. count .. ")")
      slot:setFocusable(true)
      slot.itemId = stone.itemId

      if stone.itemId == selectedSourceItemId then
        sourceStillPresent = true
        highlightSlot(slot, true)
      end

      slot.onClick = function(widget)
        for _, c in pairs(sourceGrid:getChildren()) do
          highlightSlot(c, false)
        end
        highlightSlot(widget, true)
        selectedSourceItemId = stone.itemId
        if selectedTargetItemId == stone.itemId then
          selectedTargetItemId = nil
        end
        refreshTargetGrid()
      end
    end
  end

  if not sourceStillPresent then
    selectedSourceItemId = nil
  end
end

function closeQuantityWindow()
  if quantityWindow then
    g_uistates.remove(quantityWindow)
    quantityWindow:destroy()
    quantityWindow = nil
  end
end

local function openQuantityWindow(sourceStone, targetStone)
  closeQuantityWindow()

  local maxAmount = math.max(1, modules.game_playeractionbar.getPlayerItemCount(sourceStone.clientId))
  maxAmount = math.min(maxAmount, 100)

  quantityWindow = g_ui.displayUI('conversionquantity')
  if not quantityWindow then
    return
  end

  quantityWindow:getChildById('quantitySourceItem'):setItemId(sourceStone.clientId)
  quantityWindow:getChildById('quantityTargetItem'):setItemId(targetStone.clientId)

  local sourceItem = quantityWindow:getChildById('quantitySourceItem')
  local costLabel = quantityWindow:getChildById('quantityCostLabel')
  local spinbox = quantityWindow.quantitySpinner.field

  local function updateLabels(value)
    sourceItem:setItemCount(value)
    costLabel:setText(tr("Cost: $%s", formatMoney(cachedConversion.moneyCost * value)))
  end

  spinbox.onValueChange = function(_, value)
    updateLabels(value)
  end
  spinbox:setMinimum(1)
  spinbox:setMaximum(maxAmount)
  spinbox:setValue(1)
  updateLabels(1)
  spinbox:focus()

  quantityWindow:getChildById('quantityConfirmButton').onClick = function()
    local amount = spinbox:getValue()
    g_game.convertRuinedAscendant(selectedSourceItemId, selectedTargetItemId, amount)
    closeQuantityWindow()
  end

  quantityWindow:show()
  quantityWindow:raise()
  quantityWindow:focus()
  g_uistates.push(quantityWindow)
end

local function onConfirm()
  if not selectedSourceItemId then
    modules.game_textmessage.displayGameMessage(tr("Select a source stone first."))
    return
  end
  if not selectedTargetItemId then
    modules.game_textmessage.displayGameMessage(tr("Select a target stone first."))
    return
  end
  if selectedSourceItemId == selectedTargetItemId then
    modules.game_textmessage.displayGameMessage(tr("Source and target must be different."))
    return
  end

  local sourceStone = getStoneByItemId(selectedSourceItemId)
  local targetStone = getStoneByItemId(selectedTargetItemId)
  if not sourceStone or not targetStone then
    return
  end

  openQuantityWindow(sourceStone, targetStone)
end

function showConversionWindow()
  if conversionWindow then
    return
  end
  if #cachedConversion.stones == 0 then
    modules.game_textmessage.displayGameMessage(tr("Conversion data not available yet."))
    return
  end

  selectedSourceItemId = nil
  selectedTargetItemId = nil

  conversionWindow = g_ui.displayUI('conversion')
  conversionWindow:recursiveGetChildById('costLabel'):setText(
    tr("Cost: $%s", formatMoney(cachedConversion.moneyCost))
  )

  refreshSourceGrid()
  refreshTargetGrid()

  conversionWindow:recursiveGetChildById('confirmButton').onClick = onConfirm

  g_uistates.push(conversionWindow)
end

function hideConversionWindow()
  closeQuantityWindow()
  if conversionWindow then
    g_uistates.remove(conversionWindow)
    conversionWindow:destroy()
    conversionWindow = nil
    selectedSourceItemId = nil
    selectedTargetItemId = nil
  end
end

local function onRuinedConversion(moneyCost, stones)
  cachedConversion.moneyCost = moneyCost or 0
  cachedConversion.stones = stones or {}
end

local function isLegendaryClientId(clientId)
  for _, stone in ipairs(cachedConversion.stones) do
    if stone.clientId == clientId then
      return true
    end
  end
  return false
end

local function onItemUpdate(itemId, count)
  if not conversionWindow then
    return
  end
  if isLegendaryClientId(itemId) then
    refreshSourceGrid()
    refreshTargetGrid()
  end
end

function initConversion()
  connect(g_game, {
    onRuinedConversion = onRuinedConversion,
    onItemUpdate = onItemUpdate,
  })
end

function terminateConversion()
  disconnect(g_game, {
    onRuinedConversion = onRuinedConversion,
    onItemUpdate = onItemUpdate,
  })
  hideConversionWindow()
  cachedConversion = { moneyCost = 0, stones = {} }
end
