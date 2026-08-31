local tabBar
local missions
local missionsTab
local rewards
local rewardsTab
shop = nil
local shopTab
local selectedItemWidget
local purchaseMessageBox

local _loadStyles
local _createTabs
local gamePassButton

local gamePassState = nil
local gamePassStateIndex = nil

GamePassExp = nil
GamePassLevel = nil
GamePassPremium = nil
GamePassPrice = nil
GamePassRemainingBuyLevels = 0

function init()
  gamePassWindow = g_ui.displayUI('gamepass')
  gamePassWindow.onEscape = hide

  tabBar = gamePassWindow:getChildById('tabBar')
  tabBar:setContentWidget(gamePassWindow:getChildById('tabContent'))

  _loadStyles()
  _createTabs()

  tabBar.onTabChange = onTabChange
  hide()

  -- Botao FIXO da topbar (grupo da esquerda). Ate agora o Game Pass so abria pelo menu interno
  -- do trainer.
  gamePassButton = modules.client_topmenu.addMiddleGameToggleButton('gamePassButton',
    tr('Battle Pass'), '/images/ui/topbuttons/icons/battle_pass', toggle)
  gamePassButton:setOn(false)

  connect(g_game, {
    onGameEnd = onLogout,
    onGamePassOpen = onGamePassOpen,
    onGamePassMissions = onGamePassMissions,
    onGamePassExperience = onGamePassExperience,
    onGamePassClaimed = onGamePassClaimed,
    onGamePassPoints = onGamePassPoints,
    onGamePassShop = onGamePassShop
  })
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onLogout,
    onGamePassOpen = onGamePassOpen,
    onGamePassMissions = onGamePassMissions,
    onGamePassExperience = onGamePassExperience,
    onGamePassClaimed = onGamePassClaimed,
    onGamePassPoints = onGamePassPoints,
    onGamePassShop = onGamePassShop
  })

  releaseGamePassState()
  gamePassState = nil
  gamePassStateIndex = nil

  tabBar:destroy()
  gamePassWindow:destroy()
end

function _loadStyles()
  rewards = g_ui.loadUI('rewards')
  missions = g_ui.loadUI('missions')
  shop = g_ui.loadUI('shop')
end

function _createTabs()
  rewardsTab = tabBar:addTab(tr('REWARDS'), rewards, nil, true)
  missionsTab = tabBar:addTab(tr('MISSIONS'), missions, nil, true)
  shopTab = tabBar:addTab(tr('SHOP'), shop, nil, true)

  createMissionsCategoryTab(missions)
end

function onLogout()
  ReceivedFirstPacket = false
  hide()
end

function setupGamePassState()
  if not gamePassWindow then return end
  if not gamePassState then
    gamePassState = UIState.create()
    gamePassStateIndex = gamePassState:new(function(released)
      if released then
        if gamePassWindow and not gamePassWindow:isDestroyed() then
          g_uistates.remove(gamePassWindow)
        end
      else
        if gamePassWindow and not gamePassWindow:isDestroyed() then
          g_uistates.push(gamePassWindow)
        end
      end
    end)
    gamePassState:gotoState(0)
  end
  gamePassState:gotoState(gamePassStateIndex)
end

function releaseGamePassState()
  if gamePassState and gamePassStateIndex then
    gamePassState:gotoState(0)
  end
end

function show()
  if ReceivedFirstPacket then
    if tabBar:getCurrentTab() == missionsTab then
      sendMissionsRequest()
    elseif tabBar:getCurrentTab() == shopTab then
      sendShopRequest()
    end
    gamePassWindow:show()
    setupGamePassState()
    -- Aqui e nao no toggle(): sem o primeiro pacote, show() so dispara o sendOpenRequest e a
    -- janela ainda nao abre — o onGamePassOpen chama show() de novo e cai neste ramo.
    if gamePassButton then gamePassButton:setOn(true) end
  else
    sendOpenRequest()
  end
end

function hide()
  releaseGamePassState()
  gamePassWindow:hide()
  if gamePassButton then gamePassButton:setOn(false) end

  closePurchaseLevelWindow()

  if purchaseMessageBox then
    purchaseMessageBox:cancel()
    purchaseMessageBox = nil
  end
end

function toggle()
  if gamePassWindow:isVisible() then
    hide()
  else
    show()
  end
end

function onTabChange(tabBar, currentTab)
  if currentTab == missionsTab then
    sendMissionsRequest()
  elseif currentTab == shopTab then
    sendShopRequest()
  end
end

function getLevel(experience)
  return math.floor(experience / 300)
end

function getCurrentLevelExperience(experience)
  local level = getLevel(experience)
  if experience < 300 then
    return experience
  end
  return math.max((experience - (300 * level)), 0)
end

function setTitle(title)
  gamePassWindow:recursiveGetChildById('title'):setText(title)
end

function setEndsAt(endTimestamp)
  local secondsLeft = endTimestamp - os.time()
  local daysLeft = math.ceil(secondsLeft / (24 * 60 * 60))
  gamePassWindow:recursiveGetChildById('endsAt'):setText(tr("Ends in %d days", daysLeft))
end

function setExperience(experience)
  local levelLabel = gamePassWindow:recursiveGetChildById('levelLabel')
  local oldLevel = GamePassLevel

  GamePassLevel = getLevel(experience)
  levelLabel:setText(tr("LEVEL %d", GamePassLevel))

  local currentLevelExp = getCurrentLevelExperience(experience)

  local progressPanel = gamePassWindow:recursiveGetChildById('progressPanel')
  local progressLabel = progressPanel:getChildById('progressLabel')
  local progress = progressPanel:getChildById('progress')

  progressLabel:setText(string.format("%d/300", currentLevelExp))
  local percent = math.max(0, currentLevelExp/300 * 100)
  progress:setPercent(percent)

  GamePassExp = experience

  if GamePassLevel ~= oldLevel then
    refreshRewards()
  end
end

function setPremium(premium)
  local statusLabel = gamePassWindow:recursiveGetChildById('status')
  statusLabel:setChecked(premium)

  if premium then
    statusLabel:setText(tr("PREMIUM"))
    statusLabel:setTooltip()
    statusLabel:setCursor()
    statusLabel:setEnabled(false)
  else
    statusLabel:setText(tr("FREE"))
    statusLabel:setTooltip(tr("Click to buy!"))
    statusLabel:setCursor("pointer")
    statusLabel:setEnabled(true)
  end

  GamePassPremium = premium
end

function setPrice(price)
  GamePassPrice = price
end

function setPoints(points)
  local pointsLabel = gamePassWindow:recursiveGetChildById('points')
  pointsLabel:setText(points)
end

function setClaimedReward(category, level)
  local scrollPanel = rewards:getChildById('scrollPanel')
  local rewardPanel = scrollPanel:getChildById(level)

  if not rewardPanel then
    return
  end

  local categoryPanel = rewardPanel:getChildById(category)
  if not categoryPanel then
    return
  end

  local itemWidget = categoryPanel:getChildById('item')
  setItemWidgetClaimed(itemWidget)
end

function setItemWidgetClaimed(itemWidget)
  itemWidget.claimed = true
  itemWidget:setOn(false)

  local check = itemWidget:getParent():getChildById('check')
  check:setVisible(true)
end

function setupRewards(rewardsList)
  local standardPass = rewardsList.standardPass
  local premiumPass = rewardsList.premiumPass

  local scrollPanel = rewards:getChildById('scrollPanel')
  scrollPanel:destroyChildren()
  scrollPanel:hide()

  local loading = rewards:getChildById('loading')
  loading:show()

  for level = 1, #standardPass do
    local rewardPanel = g_ui.createWidget('GamePassReward', scrollPanel)
    rewardPanel:setId(level)
    rewardPanel.level = level

    local standardPanel = rewardPanel:getChildById('standard')
    standardPanel:setText(level)

    local standardReward = standardPass[level]
    local standardItemWidget = standardPanel:getChildById('item')
    standardItemWidget:setItemId(standardReward.itemId)
    standardItemWidget:setItemCount(standardReward.count)
    standardItemWidget.itemId = standardReward.itemId
    standardItemWidget.itemName = standardReward.name
    standardItemWidget.itemDescription = standardReward.description

    if standardReward.claimed then
      setItemWidgetClaimed(standardItemWidget)
    end

    local premiumPanel = rewardPanel:getChildById('premium')
    premiumPanel:setText(level)

    local premiumReward = premiumPass[level]
    local premiumItemWidget = premiumPanel:getChildById('item')
    if premiumReward.lookType and premiumReward.lookType > 0 then
      premiumItemWidget.outfit:setVisible(true)
      premiumItemWidget.outfit:setOutfit({type = premiumReward.lookType})
    else
      premiumItemWidget:setItemId(premiumReward.itemId)
      premiumItemWidget:setItemCount(premiumReward.count)
    end
    
    premiumItemWidget.itemId = premiumReward.itemId
    premiumItemWidget.itemName = premiumReward.name
    premiumItemWidget.itemDescription = premiumReward.description

    if premiumReward.claimed then
      setItemWidgetClaimed(premiumItemWidget)
    end

    if GamePassLevel < level then
      standardItemWidget:setOn(false)
      premiumItemWidget:setOn(false)
    elseif not GamePassPremium then
      premiumItemWidget:setOn(false)
    end
  end

  local firstRewardPanel = scrollPanel:getFirstChild()
  local standardPanel = firstRewardPanel:getChildById('standard')
  local standardItemWidget = standardPanel:getChildById('item')

  rewards:getChildById('leftEffectPanel'):show()
  rewards:getChildById('rightEffectPanel'):show()

  loading:hide()
  scrollPanel:show()

  displayItemInfo(standardItemWidget)
end

function refreshRewards()
  local scrollPanel = rewards:getChildById('scrollPanel')
  for _, rewardPanel in pairs(scrollPanel:getChildren()) do
    local standardPanel = rewardPanel:getChildById('standard')
    local standardItemPanel = standardPanel:getChildById('item')

    local premiumPanel = rewardPanel:getChildById('premium')
    local premiumItemPanel = premiumPanel:getChildById('item')

    local active = GamePassLevel >= rewardPanel.level
    standardItemPanel:setOn(active)

    if GamePassPremium then
      premiumItemPanel:setOn(active)
    end
  end
end

function displayItemInfo(itemWidget)
  if selectedItemWidget then
    selectedItemWidget:setChecked(false)
  end

  local itemId = itemWidget.itemId
  local itemName = itemWidget.itemName
  local itemDescription = itemWidget.itemDescription
  local descriptionPanel = rewards:getChildById('descriptionPanel')

  local titleLabel = descriptionPanel:getChildById('title')
  titleLabel:setText(itemName:gsub("^%l", string.upper))

  local descriptionLabel = descriptionPanel:getChildById('description')
  descriptionLabel:setText(itemDescription)

  local displayItemWidget = descriptionPanel:getChildById('item')
  displayItemWidget:setItemId(itemId)

  local claimButton = rewards:getChildById('claimButton')
  claimButton:hide()

  if not itemWidget.claimed then
    local categoryPanel = itemWidget:getParent()
    local rewardPanel = categoryPanel:getParent()
    if GamePassLevel >= rewardPanel.level and (categoryPanel:getId() == "standard" or GamePassPremium) then
      claimButton:show()
    end
  end

  itemWidget:setChecked(true)
  selectedItemWidget = itemWidget
end

function claimReward()
  if not selectedItemWidget then
    return
  end

  local categoryPanel = selectedItemWidget:getParent()
  local rewardPanel = categoryPanel:getParent()

  if rewardPanel.claimed then
    return
  end

  local rewardLevel = rewardPanel.level
  if GamePassLevel < rewardLevel then
    return
  end

  local category = categoryPanel:getId()
  requestClaim(category, rewardLevel)
end

local function disconnectMessageBoxSignals()
  disconnect(gamePassWindow, {
    onEnter = onMessageBoxEnter,
    onEscape = onMessageBoxEscape
  })
end

local function closePurchaseMessageBox(confirm)
  if not purchaseMessageBox then return end
  local box = purchaseMessageBox
  local onConfirm = purchaseMessageBox._onConfirm
  purchaseMessageBox = nil
  disconnectMessageBoxSignals()
  if confirm then
    box:ok()
    if onConfirm then onConfirm() end
  else
    box:cancel()
  end
end

function onMessageBoxEnter()
  closePurchaseMessageBox(true)
end

function onMessageBoxEscape()
  closePurchaseMessageBox(false)
end

local function connectMessageBoxSignals()
  connect(gamePassWindow, {
    onEnter = onMessageBoxEnter,
    onEscape = onMessageBoxEscape
  })
end

function purchase()
  closePurchaseMessageBox(false)

  local message = tr("Are you sure you want to buy this game pass for %d Diamonds?", GamePassPrice)

  purchaseMessageBox = AllianceMessageBox.display(tr("Game Pass"), message, {
    { text = "Ok", callback = function() closePurchaseMessageBox(true) end },
    { text = "Cancel", callback = function() closePurchaseMessageBox(false) end },
    anchor = AnchorHorizontalCenter
  }, function() closePurchaseMessageBox(true) end, function() closePurchaseMessageBox(false) end)

  purchaseMessageBox._onConfirm = sendPurchaseRequest
  connectMessageBoxSignals()
end

function setRemainingBuyLevels(remaining)
  GamePassRemainingBuyLevels = remaining or 0

  local topPanel = gamePassWindow:getChildById('topPanel')
  local buyLevelButton = topPanel:getChildById('buyLevelButton')

  if GamePassRemainingBuyLevels <= 0 then
    buyLevelButton:setEnabled(false)
    buyLevelButton:setCursor()
    buyLevelButton:setTooltip(tr("You have reached the maximum number of purchasable levels."))
  else
    buyLevelButton:setEnabled(true)
    buyLevelButton:setCursor('pointer')
    buyLevelButton:setTooltip(tr("Buy Level (%d remaining)", GamePassRemainingBuyLevels))
  end
end

local purchaseLevelWindow = nil
local LEVEL_COST = 4

local function disconnectPurchaseLevelSignals()
  disconnect(gamePassWindow, {
    onEnter = onPurchaseLevelEnter,
    onEscape = onPurchaseLevelEscape
  })
end

local function connectPurchaseLevelSignals()
  connect(gamePassWindow, {
    onEnter = onPurchaseLevelEnter,
    onEscape = onPurchaseLevelEscape
  })
end

function closePurchaseLevelWindow()
  if purchaseLevelWindow then
    disconnectPurchaseLevelSignals()
    purchaseLevelWindow:destroy()
    purchaseLevelWindow = nil
  end
end

function confirmPurchaseLevel()
  if not purchaseLevelWindow then return end

  local scrollbar = purchaseLevelWindow:getChildById('quantityScrollBar')
  local quantity = scrollbar:getValue()

  closePurchaseLevelWindow()
  sendPurchaseLevelRequest(quantity)
end

function onPurchaseLevelEnter()
  confirmPurchaseLevel()
end

function onPurchaseLevelEscape()
  closePurchaseLevelWindow()
end

function purchaseLevel()
  if GamePassRemainingBuyLevels <= 0 then
    return
  end

  closePurchaseLevelWindow()

  purchaseLevelWindow = g_ui.loadUI("purchaselevel", rootWidget)
  if not purchaseLevelWindow then return end

  local scrollbar = purchaseLevelWindow:getChildById('quantityScrollBar')
  local costPanel = purchaseLevelWindow:getChildById('costPanel')
  local levelCountLabel = costPanel:getChildById('levelCountLabel')
  local diamondItem = costPanel:getChildById('diamondItem')
  local maxLevels = GamePassRemainingBuyLevels

  scrollbar:setMinimum(1)
  scrollbar:setMaximum(maxLevels)
  scrollbar:setValue(1)

  local function updateLevelText(value)
    if value == 1 then
      levelCountLabel:setText(tr("%d Level", value))
    else
      levelCountLabel:setText(tr("%d Levels", value))
    end
    diamondItem:setItemCount(value * LEVEL_COST)
  end

  updateLevelText(1)

  scrollbar.onValueChange = function(self, value)
    updateLevelText(value)
  end

  purchaseLevelWindow:show()
  purchaseLevelWindow:raise()
  purchaseLevelWindow:focus()
  connectPurchaseLevelSignals()
end
