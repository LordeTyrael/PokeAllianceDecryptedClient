local STATE_WAITING = 0
local STATE_RUNNING = 1
local STATE_ENDED = 2
local BID_MAX = 999999999999

local auctionWindow = nil
local bidWindow = nil
local current = nil
local countdownEvent = nil

local function money(value)
  return tr('%s dollars', formatMoney(value, '.'))
end

local function formatDuration(seconds)
  seconds = math.max(0, math.floor(seconds))
  local clock = string.format('%02d:%02d:%02d', math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60, seconds % 60)
  local days = math.floor(seconds / 86400)
  if days > 0 then
    return days .. 'd ' .. clock
  end
  return clock
end

local function stopCountdown()
  if countdownEvent then
    countdownEvent:cancel()
    countdownEvent = nil
  end
end

local function updateCountdown()
  if not auctionWindow or not current then
    return
  end
  local remaining = (current.deadlineMillis - g_clock.millis()) / 1000
  auctionWindow:recursiveGetChildById('countdownLabel'):setText(formatDuration(remaining))
  if remaining <= 0 then
    stopCountdown()
  end
end

function init()
  connect(g_game, {
    onGameEnd = close,
    onHouseAuctionState = onHouseAuctionState
  })
end

function terminate()
  disconnect(g_game, {
    onGameEnd = close,
    onHouseAuctionState = onHouseAuctionState
  })
  close()
end

function close()
  closeBidWindow()
  stopCountdown()
  current = nil
  if auctionWindow then
    g_client.removeInputLockWidget(auctionWindow)
    auctionWindow:destroy()
    auctionWindow = nil
  end
end

local function setBidAllowed(allowed)
  local bidButton = auctionWindow:getChildById('bidButton')
  bidButton:setEnabled(allowed)
  bidButton:setOpacity(allowed and 1 or 0.5)
end

function onHouseAuctionState(auction)
  if not auctionWindow then
    auctionWindow = g_ui.loadUI('houseauction', modules.game_interface.getRootPanel())
  end

  current = auction
  current.deadlineMillis = g_clock.millis() + math.max(0, auction.stateTime - auction.serverNow) * 1000

  auctionWindow:recursiveGetChildById('base_text'):setText(auction.name)
  auctionWindow:getChildById('ownerValue'):setText(tr('Nobody'))
  auctionWindow:getChildById('sizeValue'):setText(tr('%s tiles', auction.sqm))
  auctionWindow:getChildById('priceValue'):setText(money(auction.price))

  local statusValue = auctionWindow:getChildById('statusValue')
  local currentBidValue = auctionWindow:getChildById('currentBidValue')
  local maxBidValue = auctionWindow:getChildById('maxBidValue')
  local countdownHint = auctionWindow:getChildById('countdownHint')

  if auction.state == STATE_RUNNING then
    statusValue:setText(tr('In progress'))
    countdownHint:setText(tr('ends in'))
    currentBidValue:setText(auction.hasBids and money(auction.currentBid) or tr('No bids yet'))
    maxBidValue:setText(auction.winning and money(auction.maxBid) or '-')
    setBidAllowed(true)
  elseif auction.state == STATE_WAITING then
    statusValue:setText(tr('Not started'))
    countdownHint:setText(tr('starts in'))
    currentBidValue:setText(tr('No bids yet'))
    maxBidValue:setText('-')
    setBidAllowed(false)
  else
    statusValue:setText(tr('Ended'))
    countdownHint:setText(tr('next check in'))
    currentBidValue:setText('-')
    maxBidValue:setText('-')
    setBidAllowed(false)
  end

  stopCountdown()
  updateCountdown()
  countdownEvent = cycleEvent(updateCountdown, 1000)

  auctionWindow:show()
  auctionWindow:raise()
  auctionWindow:focus()
  g_client.setInputLockWidget(auctionWindow)
end

function openBidWindow()
  if not current or current.state ~= STATE_RUNNING then
    return
  end
  closeBidWindow()

  bidWindow = g_ui.loadUI('bidwindow', modules.game_interface.getRootPanel())
  bidWindow:getChildById('minBidLabel'):setText(tr('Minimum bid: %s', formatMoney(current.minNextBid, '.')))

  local edit = bidWindow:getChildById('bidEdit')
  local confirmButton = bidWindow:getChildById('confirmButton')
  local function refreshConfirm()
    local amount = tonumber(edit:getText())
    local valid = amount ~= nil and amount >= current.minNextBid and amount <= BID_MAX
    confirmButton:setEnabled(valid)
    confirmButton:setOpacity(valid and 1 or 0.5)
  end

  edit:setValidCharacters('0123456789')
  edit:setText(tostring(current.minNextBid))
  edit:selectAll()
  edit.onTextChange = refreshConfirm
  refreshConfirm()

  bidWindow:show()
  bidWindow:raise()
  g_client.setInputLockWidget(bidWindow)
  edit:focus()
end

function closeBidWindow()
  if bidWindow then
    g_client.removeInputLockWidget(bidWindow)
    bidWindow:destroy()
    bidWindow = nil
  end
end

function confirmBid()
  if not bidWindow or not current then
    return
  end
  local amount = tonumber(bidWindow:getChildById('bidEdit'):getText())
  if not amount or amount < current.minNextBid or amount > BID_MAX then
    return
  end
  g_game.houseAuctionBid(current.houseId, amount)
  closeBidWindow()
end
