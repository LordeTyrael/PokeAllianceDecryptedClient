local STATE_WAITING = 0
local STATE_RUNNING = 1
local STATE_ENDED = 2
local BID_MAX = 999999999999

local ACCESS_OWNER = 3
local ACCESS_SUBOWNER = 2
local ACCESS_GUEST = 1
local ACCESS_NONE = 0

local ACCESS_ICON = {
  [ACCESS_OWNER]    = '/images/game/icons/house',
  [ACCESS_SUBOWNER] = '/images/game/icons/house',
  [ACCESS_GUEST]    = '/images/game/icons/house',
  [ACCESS_NONE]     = '/images/game/icons/house',
}

local AUCTION_ROWS = { 'clockIcon', 'countdownLabel', 'countdownHint',
                       'statusKey', 'statusValue', 'currentBidKey', 'currentBidValue',
                       'maxBidKey', 'maxBidValue' }

local houseWindow = nil
local bidWindow = nil
local sellWindow = nil
local sellHouseId = nil
local leaveWindow = nil
local leaveHouseId = nil
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
  if not houseWindow or not current then
    return
  end
  local remaining = (current.deadlineMillis - g_clock.millis()) / 1000
  houseWindow:recursiveGetChildById('countdownLabel'):setText(formatDuration(remaining))
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
  closeSellWindow()
  closeLeaveWindow()
  stopCountdown()
  current = nil
  if houseWindow then
    g_uistates.remove(houseWindow)
    houseWindow:destroy()
    houseWindow = nil
  end
end

local function setBidAllowed(allowed)
  local bidButton = houseWindow:getChildById('bidButton')
  bidButton:setEnabled(allowed)
  bidButton:setOpacity(allowed and 1 or 0.5)
end

local function setAuctionRowsVisible(visible)
  for _, id in ipairs(AUCTION_ROWS) do
    local w = houseWindow:recursiveGetChildById(id)
    if w then w:setVisible(visible) end
  end
end

function onHouseAuctionState(auction)
  if not houseWindow then
    houseWindow = g_ui.loadUI('houseinfo', modules.game_interface.getRootPanel())
  end

  -- A server re-push must not leave a stale sub-window open over the refreshed state.
  closeBidWindow()
  closeSellWindow()
  closeLeaveWindow()

  current = auction
  current.deadlineMillis = g_clock.millis() + math.max(0, auction.stateTime - auction.serverNow) * 1000

  local access = auction.access or ACCESS_NONE
  -- Auction UI only for ownerless houses; an owned house is never auctionable.
  local showAuction = (auction.owner == nil or auction.owner == '')

  houseWindow:recursiveGetChildById('base_text'):setText(auction.name)
  houseWindow:getChildById('icon'):setImageSource(ACCESS_ICON[access] or ACCESS_ICON[ACCESS_NONE])
  houseWindow:getChildById('ownerValue'):setText((auction.owner and auction.owner ~= '') and auction.owner or tr('Nobody'))
  houseWindow:getChildById('townValue'):setText((auction.town and auction.town ~= '') and auction.town or '-')
  houseWindow:getChildById('sizeValue'):setText(tr('%s tiles', auction.sqm))
  houseWindow:getChildById('priceValue'):setText(money(auction.price))
  houseWindow:getChildById('maxBidValue'):setText(auction.winning and money(auction.maxBid) or '-')

  stopCountdown()
  setAuctionRowsVisible(showAuction)

  if showAuction then
    local statusValue = houseWindow:getChildById('statusValue')
    local currentBidValue = houseWindow:getChildById('currentBidValue')
    local countdownHint = houseWindow:getChildById('countdownHint')

    if auction.state == STATE_RUNNING then
      statusValue:setText(tr('In progress'))
      countdownHint:setText(tr('ends in'))
      currentBidValue:setText(auction.hasBids and money(auction.currentBid) or tr('No bids yet'))
    elseif auction.state == STATE_WAITING then
      statusValue:setText(tr('Not started'))
      countdownHint:setText(tr('starts in'))
      currentBidValue:setText(tr('No bids yet'))
    else
      statusValue:setText(tr('Ended'))
      countdownHint:setText(tr('next check in'))
      currentBidValue:setText('-')
    end

    updateCountdown()
    countdownEvent = cycleEvent(updateCountdown, 1000)
  end

  local bidButton = houseWindow:getChildById('bidButton')
  local leaveButton = houseWindow:getChildById('leaveButton')
  local sellButton = houseWindow:getChildById('sellButton')
  local hasAccess = (access ~= ACCESS_NONE)
  bidButton:setVisible(showAuction)
  if showAuction then
    setBidAllowed(auction.state == STATE_RUNNING)
  end
  leaveButton:setVisible((not showAuction) and hasAccess)
  sellButton:setVisible((not showAuction) and access == ACCESS_OWNER)

  houseWindow:show()
  houseWindow:raise()
  houseWindow:focus()
  g_uistates.push(houseWindow)
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
  g_uistates.push(bidWindow)
  edit:focus()
end

function closeBidWindow()
  if bidWindow then
    g_uistates.remove(bidWindow)
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

function leaveHouse()
  if not current then return end
  closeLeaveWindow()
  leaveHouseId = current.houseId

  leaveWindow = g_ui.loadUI('leaveconfirm', modules.game_interface.getRootPanel())
  leaveWindow:show()
  leaveWindow:raise()
  leaveWindow:focus()
  g_uistates.push(leaveWindow)
end

function closeLeaveWindow()
  if leaveWindow then
    g_uistates.remove(leaveWindow)
    leaveWindow:destroy()
    leaveWindow = nil
    if houseWindow then g_uistates.push(houseWindow) end
  end
end

function confirmLeave()
  if not leaveWindow then return end
  closeLeaveWindow()
  g_game.houseLeave(leaveHouseId)
  close()
end

function sellHouse()
  if not current then return end
  closeSellWindow()
  sellHouseId = current.houseId

  sellWindow = g_ui.loadUI('sellwindow', modules.game_interface.getRootPanel())
  local edit = sellWindow:getChildById('buyerEdit')
  edit:setText('')

  sellWindow:show()
  sellWindow:raise()
  g_uistates.push(sellWindow)
  edit:focus()
end

function closeSellWindow()
  if sellWindow then
    g_uistates.remove(sellWindow)
    sellWindow:destroy()
    sellWindow = nil
    if houseWindow then g_uistates.push(houseWindow) end
  end
end

function confirmSell()
  if not sellWindow then return end
  local name = sellWindow:getChildById('buyerEdit'):getText()
  if name and name ~= '' then
    g_game.houseSell(sellHouseId, name)
  end
  closeSellWindow()
  close()
end
