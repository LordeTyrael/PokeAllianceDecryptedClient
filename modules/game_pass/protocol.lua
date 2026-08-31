ReceivedFirstPacket = false

-- Send functions (client -> server via C++)
function sendOpenRequest()
  g_game.sendGamePassOpen()
end

function sendMissionsRequest()
  local category = getSelectedMissionCategory()
  if not category then
    g_logger.error("Failed to request game pass missions, invalid category: " .. tostring(category))
    return
  end

  g_game.sendGamePassMissions(category)
end

function requestClaim(category, level)
  g_game.sendGamePassClaim(category, level)
end

function sendPurchaseRequest()
  g_game.sendGamePassPurchase()
end

function sendShopRequest()
  g_game.sendGamePassShop()
end

function sendPurchaseLevelRequest(quantity)
  g_game.sendGamePassPurchaseLevel(quantity)
end

-- Parse callbacks (server -> client via C++)
function onGamePassOpen(name, premium, price, points, endTimestamp, experience, standardPass, premiumPass, remainingBuyLevels)
  setTitle(name)
  setPremium(premium)
  setPrice(price)
  setPoints(points)
  setEndsAt(endTimestamp)
  setExperience(experience)
  setRemainingBuyLevels(remainingBuyLevels)

  ReceivedFirstPacket = true

  show()

  local rewards = {
    standardPass = standardPass,
    premiumPass = premiumPass
  }

  scheduleEvent(function()
    setupRewards(rewards)
  end, 100)
end

function onGamePassMissions(category, missions)
  setupMissions(category, missions)
end

function onGamePassExperience(experience, remainingBuyLevels)
  setExperience(experience)
  setRemainingBuyLevels(remainingBuyLevels)
end

function onGamePassClaimed(category, level)
  setClaimedReward(category, level)
end

function onGamePassPoints(points)
  setPoints(points)
end
