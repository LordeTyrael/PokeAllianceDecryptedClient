-- ============================================================================
-- Global Buff Contribution System - Client Module
-- ============================================================================

-- Buff types
local BUFF_TYPE_EXP   = 0
local BUFF_TYPE_DROP  = 1
local BUFF_TYPE_SHINY = 2

-- Buff status
local BUFF_STATUS_COLLECTING = 0
local BUFF_STATUS_ACTIVE     = 1
local BUFF_STATUS_BLOCKED    = 2

local BUFF_NAMES = {
  [BUFF_TYPE_EXP]   = "Experience",
  [BUFF_TYPE_DROP]  = "Drop Rate",
  [BUFF_TYPE_SHINY] = "Shiny Charm",
}

local STATUS_LABELS = {
  [BUFF_STATUS_COLLECTING] = { text = "Collecting...",   color = "#7f8fa4" },
  [BUFF_STATUS_ACTIVE]     = { text = "Active",         color = "#24fc03" },
  [BUFF_STATUS_BLOCKED]    = { text = "Blocked due to the current event",         color = "#ff4444" },
}

local FILL_COLORS = {
  [BUFF_TYPE_EXP]   = "#2ea1f8",
  [BUFF_TYPE_DROP]  = "#f5a623",
  [BUFF_TYPE_SHINY] = "#b86ef0",
}

local BUFF_ICONS = {
  [BUFF_TYPE_EXP]   = "images/icon_exp",
  [BUFF_TYPE_DROP]  = "images/icon_drop",
  [BUFF_TYPE_SHINY] = "images/icon_shiny",
}

local BLOCKED_ICON = "images/icon_blocked"

local BAR_IMAGES = {
  [BUFF_TYPE_EXP]   = "images/bar_exp",
  [BUFF_TYPE_DROP]  = "images/bar_drop",
  [BUFF_TYPE_SHINY] = "images/bar_shiny",
}

local BAR_FILL_WIDTH  = 192
local BAR_FILL_HEIGHT = 18

local TIMER_BAR_IMAGE = "images/bar_timer"

-- ============================================================================
-- State
-- ============================================================================

local globalBuffWindow = nil
local globalBuffButton = nil
local shopWindow = nil
local buyConfirmWindow = nil
local contributeConfirmWindow = nil
local shopState = nil
local shopStateIndex = nil
local buffCards = {}
local tiers = {}
local currentPlayerPoints = 0
local currentShopItems = {}
local timerEvents = {}

local totalDurations = {}

-- ============================================================================
-- Helpers (number/time formatting come from corelib/util.lua:
--   formatNumberValue -> 1k / 2.5kk / 1kkk
--   formatHMS         -> HH:MM:SS
-- ============================================================================
-- ============================================================================
-- Sending (via game.cpp -> protocolgamesend.cpp)
-- ============================================================================

local function sendRequestState()
  g_game.sendGlobalBuffRequestState()
end

local function sendContribute(buffType, tierIndex)
  g_game.sendGlobalBuffContribute(buffType, tierIndex)
end

local function sendRequestShop()
  g_game.sendGlobalBuffRequestShop()
end

local function sendBuyItem(shopIndex, quantity)
  g_game.sendGlobalBuffBuyItem(shopIndex, quantity or 1)
end

-- ============================================================================
-- Timer management
-- ============================================================================

local function stopTimer(buffType)
  if timerEvents[buffType] then
    removeEvent(timerEvents[buffType])
    timerEvents[buffType] = nil
  end
end

local function stopAllTimers()
  for buffType = BUFF_TYPE_EXP, BUFF_TYPE_SHINY do
    stopTimer(buffType)
  end
end

local function startTimer(buffType, remaining)
  stopTimer(buffType)

  local card = buffCards[buffType]
  if not card then return end

  local timeLeft = remaining
  local totalDuration = totalDurations[buffType] or remaining

  local lastTimeText = nil
  local lastFillWidth = nil

  local function tick()
    if timeLeft <= 0 then
      sendRequestState()
      return
    end

    if card and card.timerBarBg then
      if not card.timerBarBg:isVisible() then
        card.timerBarBg:setVisible(true)
      end

      local timeText = formatHMS(timeLeft)
      if timeText ~= lastTimeText then
        card.timerBarBg.timerText:setText(timeText)
        lastTimeText = timeText
      end

      -- Regressive bar: shrinks from right to left as time passes
      local pct = totalDuration > 0 and math.min(timeLeft / totalDuration, 1.0) or 0
      local fillWidth = math.max(0, math.floor(BAR_FILL_WIDTH * pct))
      if fillWidth ~= lastFillWidth then
        card.timerBarBg.timerFill:setWidth(fillWidth)
        lastFillWidth = fillWidth
      end
    end

    timeLeft = timeLeft - 1
    timerEvents[buffType] = scheduleEvent(tick, 1000)
  end

  tick()
end

-- ============================================================================
-- UI update - Buff cards
-- ============================================================================

local function updateBuffCard(buffType, status, value, goal, multiplier)
  local card = buffCards[buffType]
  if not card then return end

  local pctText = multiplier and multiplier > 0 and ("+" .. multiplier .. "%") or ""

  if status == BUFF_STATUS_ACTIVE then
    card.buffName:setText(tr(BUFF_NAMES[buffType] or "Unknown"))
    card.statusLabel:setText(pctText)
    card.statusLabel:setColor("#24fc03")
  elseif status == BUFF_STATUS_COLLECTING then
    local name = tr(BUFF_NAMES[buffType] or "Unknown")
    if pctText ~= "" then
      card.buffName:setText(name .. " (" .. pctText .. ")")
    else
      card.buffName:setText(name)
    end
    local statusInfo = STATUS_LABELS[status]
    card.statusLabel:setText(tr(statusInfo.text))
    card.statusLabel:setColor(statusInfo.color)
  else
    card.buffName:setText(tr(BUFF_NAMES[buffType] or "Unknown"))
    local statusInfo = STATUS_LABELS[status] or STATUS_LABELS[BUFF_STATUS_COLLECTING]
    card.statusLabel:setText(tr(statusInfo.text))
    card.statusLabel:setColor(statusInfo.color)
  end

  local fillColor = FILL_COLORS[buffType] or "#2ea1f8"

  if status == BUFF_STATUS_ACTIVE then
    -- Active: show buff icon, timer bar, hide progress/buttons
    card.progressBarBg:setVisible(false)
    card.tierPanel:setVisible(false)

    -- Reset status label to auto-resize
    card.statusLabel:setTextAutoResize(true)
    card.statusLabel:setTextWrap(false)
    card.statusLabel:setMarginTop(2)

    card.activeIcon:setImageSource(BUFF_ICONS[buffType] or BUFF_ICONS[BUFF_TYPE_EXP])
    card.activeIcon:setVisible(true)

    -- Use totalDuration from server
    card.timerBarBg:setVisible(true)

    startTimer(buffType, value)

  elseif status == BUFF_STATUS_BLOCKED then
    -- Blocked: show lock icon, hide progress/buttons/timer
    card.progressBarBg:setVisible(false)
    card.timerBarBg:setVisible(false)
    card.tierPanel:setVisible(false)

    -- Allow status text to wrap on 2 lines and center icon
    card.statusLabel:setTextAutoResize(false)
    card.statusLabel:setTextWrap(true)
    card.statusLabel:setWidth(130)
    card.statusLabel:setHeight(30)
    card.statusLabel:setTextAlign(AlignCenter)
    card.statusLabel:setMarginTop(4)

    card.activeIcon:setImageSource(BLOCKED_ICON)
    card.activeIcon:setMarginTop(15)
    card.activeIcon:setVisible(true)

    stopTimer(buffType)

  else -- COLLECTING
    -- Collecting: show progress bar with text, buttons, hide icon
    card.progressBarBg:setVisible(true)
    card.timerBarBg:setVisible(false)
    card.tierPanel:setVisible(true)
    card.activeIcon:setVisible(false)

    -- Reset status label to auto-resize
    card.statusLabel:setTextAutoResize(true)
    card.statusLabel:setTextWrap(false)
    card.statusLabel:setMarginTop(2)
    card.activeIcon:setMarginTop(6)

    -- Set fill image per buff type
    local fill = card.progressBarBg.progressFill
    fill:setImageSource(BAR_IMAGES[buffType] or BAR_IMAGES[BUFF_TYPE_EXP])

    -- Resize fill widget width based on progress (clip from left to right)
    local pct = goal > 0 and math.min(value / goal, 1.0) or 0
    local fillWidth = math.max(0, math.floor(BAR_FILL_WIDTH * pct))
    fill:setWidth(fillWidth)
    fill:setImageRect({ x = 0, y = 0, width = fillWidth, height = BAR_FILL_HEIGHT })

    card.progressBarBg.progressText:setText(formatNumberValue(value) .. " / " .. formatNumberValue(goal))

    for i = 1, card.tierPanel:getChildCount() do
      local btn = card.tierPanel:getChildByIndex(i)
      btn:setEnabled(true)
      btn:setOpacity(1.0)
    end

    stopTimer(buffType)
  end
end

local function closeContributeConfirm()
  if contributeConfirmWindow then
    contributeConfirmWindow:destroy()
    contributeConfirmWindow = nil
  end
end

local function openContributeConfirm(buffType, tierIndex, tierValue)
  closeContributeConfirm()

  local confirm = function()
    closeContributeConfirm()
    sendContribute(buffType, tierIndex)
  end

  contributeConfirmWindow = displayAllianceBox(tr('Confirm Contribution'),
    tr('Are you sure you want to contribute %s to the %s bonus?',
       "$" .. comma_value2(tierValue), tr(BUFF_NAMES[buffType] or "Unknown")), {
      { text = tr('Yes'), callback = confirm },
      { text = tr('No'),  callback = closeContributeConfirm },
      anchor = AnchorHorizontalCenter
    }, confirm, closeContributeConfirm)
end

local function createBuffCards()
  if not globalBuffWindow then return end

  local container = globalBuffWindow.buffContainer
  container:destroyChildren()
  buffCards = {}

  for buffType = BUFF_TYPE_EXP, BUFF_TYPE_SHINY do
    local card = g_ui.createWidget("BuffCard", container)
    card:setId("buffCard_" .. buffType)
    card.buffName:setText(tr(BUFF_NAMES[buffType] or "Unknown"))

    card.tierPanel:destroyChildren()
    for i, tierValue in ipairs(tiers) do
      local btn = g_ui.createWidget("TierButton", card.tierPanel)
      btn:setText(formatNumberValue(tierValue))
      local bt = buffType
      local ti = i
      local tv = tierValue
      btn.onClick = function()
        openContributeConfirm(bt, ti, tv)
      end
    end

    buffCards[buffType] = card
  end
end

-- ============================================================================
-- Shop window
-- ============================================================================

function showShop()
  sendRequestShop()
end

local function setupShopState()
  if not shopWindow then return end
  if not shopState then
    shopState = UIState.create()
    shopStateIndex = shopState:new(function(released)
      if released then
        if shopWindow and not shopWindow:isDestroyed() then
          g_uistates.remove(shopWindow)
        end
      else
        if shopWindow and not shopWindow:isDestroyed() then
          g_uistates.push(shopWindow)
        end
      end
    end)
    shopState:gotoState(0)
  end
  shopState:gotoState(shopStateIndex)
end

local function releaseShopState()
  if shopState and shopStateIndex then
    shopState:gotoState(0)
  end
end

function hideShop()
  closeBuyConfirm()
  releaseShopState()
  if shopWindow then
    g_effects.fadeOut(shopWindow)
    scheduleEvent(function()
      if shopWindow then
        shopWindow:destroy()
        shopWindow = nil
      end
    end, 250)
  end
end

-- ============================================================================
-- Buy confirmation window
-- ============================================================================

function closeBuyConfirm()
  if buyConfirmWindow then
    buyConfirmWindow:destroy()
    buyConfirmWindow = nil
  end
end

local function openBuyConfirm(shopIndex, clientId, count, name, price)
  closeBuyConfirm()

  local maxQty = price > 0 and math.floor(currentPlayerPoints / price) or 0
  maxQty = math.max(1, math.min(10000, maxQty))

  buyConfirmWindow = ShopConfirm.show({
    title = name,
    itemId = clientId,
    itemCount = count,
    priceGlyph = '@fa solid 14 f005',
    priceGlyphColor = '#ffcc00',
    unitPrice = price,
    maxAmount = maxQty,
    onConfirm = function(quantity)
      buyConfirmWindow = nil
      sendBuyItem(shopIndex, quantity)
    end,
    onClose = function()
      buyConfirmWindow = nil
    end,
  })
end

-- ============================================================================
-- Shop window creation
-- ============================================================================

local function populateShopItems(items, filter)
  if not shopWindow then return end
  local shopPanel = shopWindow.shopItemsPanel
  shopPanel:destroyChildren()

  local lowerFilter = filter and filter:lower() or ""

  for index, item in ipairs(items) do
    local clientId   = tonumber(item[1])
    local count      = tonumber(item[2])
    local name       = item[3]
    local price      = tonumber(item[4])
    local isUnique   = tonumber(item[5]) == 1
    local description = item[6] or ""

    if lowerFilter == "" or name:lower():find(lowerFilter, 1, true) then
      local widget = g_ui.createWidget("ShopItemWidget", shopPanel)
      widget.name:setText(count > 1 and (count .. "x " .. name) or name)
      widget.price:setText(comma_value2(price))

      if clientId and clientId > 0 then
        widget.item:setItemId(clientId)
        widget.item:setItemCount(count)
      end

      if description ~= "" then
        widget:setTooltip(description)
      end

      widget.buyWidget.onClick = function()
        openBuyConfirm(index, clientId, count, name, price)
      end
    end
  end
end

local function createShopWindow(items)
  currentShopItems = items

  -- Se a janela já está aberta (ex: re-envio do catálogo após uma compra),
  -- só repopula sem destruir nem refazer fadeIn.
  if shopWindow and not shopWindow:isDestroyed() then
    shopWindow.shopPointsLabel:setText(tr("Community Points: %d", currentPlayerPoints))
    local searchText = shopWindow.shopSearchField and shopWindow.shopSearchField:getText() or ""
    populateShopItems(items, searchText)
    return
  end

  shopWindow = g_ui.loadUI("globalbuff_shop", modules.game_interface.getRootPanel())
  if not shopWindow then return end

  shopWindow.shopPointsLabel:setText(tr("Community Points: %d", currentPlayerPoints))

  populateShopItems(items, "")

  setupShopState()

  addEvent(function()
    if shopWindow then
      g_effects.fadeIn(shopWindow)
    end
  end)
end

function onShopSearchChange()
  if not shopWindow then return end
  local searchText = shopWindow.shopSearchField:getText() or ""
  populateShopItems(currentShopItems, searchText)
end

-- ============================================================================
-- Event handlers (called from C++ via g_lua.callGlobalField)
-- ============================================================================

local function onGlobalBuffState(buffs, playerPoints, tierList)
  tiers = tierList or {}
  currentPlayerPoints = playerPoints or 0

  if not globalBuffWindow then return end

  if not buffCards[BUFF_TYPE_EXP] then
    createBuffCards()
  end

  for _, buffInfo in ipairs(buffs) do
    local buffType      = buffInfo[1]
    local status        = buffInfo[2]
    local value         = buffInfo[3]
    local goal          = buffInfo[4]
    local totalDuration = buffInfo[5] or 0
    local multiplier    = buffInfo[6] or 0

    -- Store total duration from server for active buffs
    if status == BUFF_STATUS_ACTIVE and totalDuration > 0 then
      totalDurations[buffType] = totalDuration
    end

    updateBuffCard(buffType, status, value, goal, multiplier)
  end

  globalBuffWindow.bottomPanel.pointsLabel:setText(tr("Community Points: %d", playerPoints))
end

local function onGlobalBuffActivated(buffType, remaining, totalDuration, multiplierPct)
  local name = tr(BUFF_NAMES[buffType] or "Unknown")
  local pctText = multiplierPct and multiplierPct > 0 and ("+" .. multiplierPct .. "%") or ""

  -- Store total duration from server
  totalDurations[buffType] = totalDuration or remaining

  modules.game_textmessage.displayStatusMessage(
    tr("Global Buff '%s' %s has been activated! (%.0fh remaining)", name, pctText, remaining / 3600)
  )

  if globalBuffWindow then
    sendRequestState()
  end
end

local function onGlobalBuffShop(items)
  createShopWindow(items)
end

-- ============================================================================
-- Window management
-- ============================================================================

function show()
  if not g_game.isOnline() then return end

  if globalBuffWindow then
    globalBuffWindow:setVisible(true)
    globalBuffWindow:raise()
    globalBuffWindow:focus()
  else
    globalBuffWindow = g_ui.loadUI("globalbuff", modules.game_interface.getRootPanel())
    if not globalBuffWindow then return end
    addEvent(function()
      if globalBuffWindow then
        g_effects.fadeIn(globalBuffWindow)
      end
    end)
  end

  if globalBuffButton then
    globalBuffButton:setOn(true)
  end

  sendRequestState()

  -- Update bank balance immediately
  local player = g_game.getLocalPlayer()
  if player and globalBuffWindow then
    globalBuffWindow.bottomPanel.bankLabel:setText("$" .. comma_value2(player:getBankBalance()))
  end
end

function hide()
  closeContributeConfirm()

  if globalBuffWindow then
    stopAllTimers()
    g_effects.fadeOut(globalBuffWindow)
    scheduleEvent(function()
      if globalBuffWindow then
        globalBuffWindow:destroy()
        globalBuffWindow = nil
        buffCards = {}
      end
    end, 250)
  end

  hideShop()

  if globalBuffButton then
    globalBuffButton:setOn(false)
  end
end

function toggle()
  if globalBuffWindow and globalBuffWindow:isVisible() then
    hide()
  else
    show()
  end
end

local function onBankBalanceChange(localPlayer, value)
  if globalBuffWindow then
    globalBuffWindow.bottomPanel.bankLabel:setText("$" .. comma_value2(value))
  end
end

-- ============================================================================
-- Game events
-- ============================================================================

local function onGameEnd()
  stopAllTimers()
  releaseShopState()

  if globalBuffWindow then
    globalBuffWindow:destroy()
    globalBuffWindow = nil
    buffCards = {}
  end

  if shopWindow then
    shopWindow:destroy()
    shopWindow = nil
  end
end

-- ============================================================================
-- Init / Terminate
-- ============================================================================

function init()
  connect(g_game, {
    onGameEnd              = onGameEnd,
    onWalk                 = hide,
    onAutoWalk             = hide,
    onGlobalBuffState      = onGlobalBuffState,
    onGlobalBuffActivated  = onGlobalBuffActivated,
    onGlobalBuffShop       = onGlobalBuffShop,
  })

  connect(LocalPlayer, {
    onBankBalanceChange = onBankBalanceChange,
  })

  globalBuffButton = modules.client_topmenu.addMiddleGameToggleButton(
    'globalBuffButton',
    tr('Global Buff'),
    '/images/ui/topbuttons/icons/world_change',
    toggle
  )
  globalBuffButton:setOn(false)
end

function terminate()
  disconnect(g_game, {
    onGameEnd              = onGameEnd,
    onWalk                 = hide,
    onAutoWalk             = hide,
    onGlobalBuffState      = onGlobalBuffState,
    onGlobalBuffActivated  = onGlobalBuffActivated,
    onGlobalBuffShop       = onGlobalBuffShop,
  })

  disconnect(LocalPlayer, {
    onBankBalanceChange = onBankBalanceChange,
  })

  stopAllTimers()

  if globalBuffWindow then
    globalBuffWindow:destroy()
    globalBuffWindow = nil
    buffCards = {}
  end

  if shopWindow then
    shopWindow:destroy()
    shopWindow = nil
  end

  closeBuyConfirm()
  closeContributeConfirm()

  if shopState then
    shopState:release()
    shopState = nil
    shopStateIndex = nil
  end

  if globalBuffButton then
    globalBuffButton:destroy()
    globalBuffButton = nil
  end
end
