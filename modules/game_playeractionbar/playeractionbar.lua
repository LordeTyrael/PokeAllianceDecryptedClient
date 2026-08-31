actionBarWindow = false
mouseGrabberWidget = false
dexButton = false
autoComboButton = false
actionBarSlots = false
slotsSeparator = false

local HotkeyRegistry = modules.client_hotkeys.HotkeyRegistry


local TYPE = {
  BLANK = 0,
  TEXT = 1,
  ITEM = 3
}
local ACTION = {
  BLANK = 0,
  ON_POKEMON = 1,
  USE = 2,
  USE_SELF = 3,
  USE_TARGET = 4,
  USE_CROSS = 5,
  SMART_USE = 6,
  AUTO_REVIVE = 7
}

local maxSlotCount = 50
-- ActionButton is 34 wide with a 1px margin on each side
local SLOT_WIDTH = 36
-- collapsed keeps only the stats row (3 top margin + 16 + 3); expanding adds the 37px slot row
local COLLAPSED_HEIGHT = 22
local EXPANDED_HEIGHT = 59

local HOTKEYS_CONFIG = {
  { "MouseMid", "MMB" },
  { "MouseX1",  "M4" },
  { "MouseX2",  "M5" },
  { "Shift",    "S" },
  { "Ctrl",     "C" },
  { "PageUp",   "PgUp" },
  { "PageDown", "PgDn" },
  { "Enter",    "Rtn" },
  { "Insert",   "Ins" },
  { "Delete",   "Del" },
  { "Escape",   "Esc" },
  { "Alt",      "A" }
}

local boundKeys = {}
local ItemsCount = {}
local hotkeyDelay = 200
local ORDER_CLIENT_ID = 3453
local updateBarItemEvent
local visibleSlotCount = 0
local slotLimitEvent

local function getActionSlot(actionName)
  -- Special slots bypass the slotsPanel lookup entirely.
  if actionName == "ACTION_BAR_DEX" then return dexButton or nil end
  if actionName == "ACTION_BAR_ORDER" then return orderButton end
  if actionName == "ACTION_BAR_AUTOCOMBO" then return autoComboButton or nil end
  -- Guard against the shutdown race: this callback is registered with
  -- client_hotkeys and stays live after our terminate() nils actionBarSlots,
  -- so client_hotkeys.unbindAllHotkeys() (run AFTER us due to module
  -- dependency order) would fire `onPostUnbind` and crash here.
  if not actionBarSlots then return nil end
  return actionBarSlots:getChildById(actionName)
end

local function actionBarFactory(actionName, action, keyInfo, chatState, keyType)
  local gameRootPanel = modules.game_interface.getRootPanel()
  local actionSlot = getActionSlot(actionName)

  if actionSlot and keyType == "primaryKey" and chatState == "chatDisabled" then
    actionSlot.hotkeyLabel:setText(translateHotkeyDesc(keyInfo.key))
  end

  local callback = function()
    if isChatStateCorrect(chatState == "chatEnabled") then
      if actionName == "ACTION_BAR_ORDER_SELF" then
        g_game.useInventoryItemWith(ORDER_CLIENT_ID, g_game.getLocalPlayer(), -1)
      elseif actionSlot then
        actionSlot.callback()
      end
    end
  end

  return { callback = callback, widget = gameRootPanel }
end

local function actionBarAssign(actionName, action, keyInfo, chatState, keyType, event)
  if event == "unbind" then
    local actionSlot = getActionSlot(actionName)
    if actionSlot then
      actionSlot.hotkeyLabel:setText("")
    end
  end
end

do
  local actionBarActions = { "ACTION_BAR_ORDER", "ACTION_BAR_ORDER_SELF", "ACTION_BAR_DEX", "ACTION_BAR_AUTOCOMBO" }
  for i = 1, 50 do
    actionBarActions[#actionBarActions + 1] = "ACTION_BAR_" .. i
  end
  for _, actionName in ipairs(actionBarActions) do
    modules.client_hotkeys.registerHotkeyCallback(actionName, actionBarFactory, actionBarAssign)
  end
end

-- game_interface calls this when the view mode changes; the bar only needs to re-run its placement
function switchMode()
  applyPlacement()
end

function createActionBar()
  actionBarWindow = g_ui.loadUI('playeractionbar', modules.game_interface.getRootPanel())
  actionBarWindow:hide()
  -- release, not press: the slots answer right-click on release and return true, so anchoring here
  -- keeps their menu from competing with this one
  actionBarWindow.onMouseRelease = function(self, mousePos, mouseButton)
    -- fullscreen pins the bar to the strip, so neither placement option would do anything
    if mouseButton ~= MouseRightButton or isPlacementForced() then return false end
    showPlacementMenu(mousePos)
    return true
  end

  mouseGrabberWidget = g_ui.createWidget('UIWidget')
  mouseGrabberWidget:setVisible(false)
  mouseGrabberWidget:setFocusable(false)
  mouseGrabberWidget.onMouseRelease = onDropActionButton
  dexButton = actionBarWindow:getChildById("ACTION_BAR_DEX")
  dexButton.background:setImageSource('images/dex')
  dexButton.callback = usePokedexItem
  dexButton.isStatic = true
  autoComboButton = actionBarWindow:getChildById("ACTION_BAR_AUTOCOMBO")
  autoComboButton.background:setImageSource('images/combo')
  autoComboButton.callback = useAutoCombo
  autoComboButton.isStatic = true
  orderButton = actionBarWindow:getChildById("ACTION_BAR_ORDER")
  orderButton.background:setImageSource('images/cursor-finger')
  orderButton.callback = useOrderItem
  orderButton.isStatic = true
  slotsSeparator = actionBarWindow:getChildById('slotsSeparator')
  actionBarSlots = actionBarWindow:getChildById('slotsPanel')
  for i = 1, maxSlotCount do
    local widget = g_ui.createWidget('ActionButton', actionBarSlots)
    widget:setId("ACTION_BAR_" .. i)
    widget:setVisible(false)
  end
  if g_game.isOnline() then
    show()
  end
end

-- Stats row (health / experience), migrated here from the old game_playerinfo HUD.
local function statsRow()
  return actionBarWindow and actionBarWindow:getChildById('statsRow') or nil
end

-- The fill is drawn into a sub-rect of the widget, so the 100% width is whatever the widget
-- currently measures. Reading it live is what lets the exp bar stretch with the action bar.
-- Floor is 2px: the fill is 9-sliced with a 1px border, and below that the two edge slices overlap.
local function setBarPercent(bar, percent)
  local pct = math.max(0, math.min(100, percent))
  local width = math.max(2, math.floor(bar:getWidth() * pct / 100))
  bar:setImageRect({ x = 0, y = 0, width = width, height = bar:getHeight() })
end

local function experienceTooltip(localPlayer, experiencePercent)
  local expLeft = comma_value(g_game.getExpToAdvance(localPlayer:getLevel(), localPlayer:getExperience()))
  local text = expLeft .. tr(" of experience left") .. " (" .. experiencePercent .. "%)"
  if playerExperienceInfo.expSpeed ~= nil then
    local expPerHour = math.floor(playerExperienceInfo.expSpeed * 3600)
    if expPerHour > 0 then
      local nextLevelExp = g_game.getExpForLevel(localPlayer:getLevel() + 1)
      local hoursLeft = (nextLevelExp - localPlayer:getExperience()) / expPerHour
      local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft)) * 60)
      hoursLeft = math.floor(hoursLeft)
      text = text .. "\n" .. comma_value(expPerHour) .. tr(" of experience per hour")
      text = text .. "\n" .. tr("Next level in %d hours and %d minutes", hoursLeft, minutesLeft)
    end
  end
  return text
end

local function refreshExperience(localPlayer, experiencePercent)
  local row = statsRow()
  if not row then return end
  experiencePercent = experiencePercent or localPlayer:getLevelPercent()
  local experience = row.playerExperience
  setBarPercent(experience.experienceProgress, math.max(1, experiencePercent))
  experience:setTooltip(experienceTooltip(localPlayer, experiencePercent))
end

function onHealthChange(localPlayer, health, maxHealth)
  local row = statsRow()
  if not row then return end
  local healthPercent = (maxHealth > 0) and (health / maxHealth * 100) or 0
  setBarPercent(row.playerHealth.healthProgress, healthPercent)
  row.playerHealthValue:setText(health)
  local tooltip = health .. " / " .. maxHealth
  row.playerHealthValue:setTooltip(tooltip)
  row.playerHealth:setTooltip(tooltip)
end

function onExperienceChange(localPlayer, value)
  refreshExperience(localPlayer)
end

function onLevelChange(localPlayer, value, experiencePercent)
  local row = statsRow()
  if row then
    row.playerLevel:setText(value)
  end
  refreshExperience(localPlayer, experiencePercent)
end

-- Sits ABOVE the action bar as a sibling, not inside it: the icons carry tooltips, and a widget
-- drawn outside its parent's rect renders but stops receiving the mouse.
local conditionBarWidget = nil

local function createConditionBar()
  if conditionBarWidget then return end
  -- ConditionBarPanel, not a bare Panel: it carries the horizontalBox the icons need. Under the
  -- default UIAnchorLayout, UIAnchorLayout::internalUpdate only walks widgets that own an anchor
  -- group, and ConditionSquare declares none - so the icons were never positioned at all. It also
  -- matches the 32px ConditionSquare height, which the old 20 did not.
  conditionBarWidget = g_ui.createWidget('ConditionBarPanel', modules.game_interface.getRootPanel())
  conditionBarWidget:setId('playerConditionBar')
  -- Panel is focusable by default. Docked, this bar is reparented onto gameRootPanel and lands
  -- after chatWindow in the child list, so closing any window made focusPreviousChild (which scans
  -- children in reverse) hand it the focus meant for the chat and typing went dead.
  conditionBarWidget:setFocusable(false)
  applyPlacement()
end

-- game_conditionicons asks the HUD owner for the bar to draw into. It builds the bar on demand
-- instead of trusting show() to have run: the server pushes the player's active conditions during
-- the login burst, before the deferred refreshStatsRow gets a turn, and handleAdd drops any icon it
-- has no bar for - silently and for good, since those conditions are never resent.
function getPlayerConditionBar()
  createConditionBar()
  return conditionBarWidget
end

-- Non-classic is the fullscreen view: the side panels turn transparent and the map fills the window,
-- so there is no clear band left for a floating bar and it is pinned down instead. This never writes
-- 'actionBar-docked', which is what makes classic view restore the player's own choice.
function isPlacementForced()
  return not g_settings.getBoolean('classicView', false)
end

local function isDocked()
  return isPlacementForced() or g_settings.getBoolean('actionBar-docked', false)
end

-- Docked, the bar becomes a row in the strip between map and chat; floating, it overlays the game
-- screen. The condition strip must land in the same parent either way: anchors only resolve among
-- siblings (UIAnchor::getHookedWidget), so splitting them detaches the conditions without a warning.
-- Three placements. Fullscreen has no chat panel under the map, so there "bottom" means the bottom
-- of the window itself. Docked in classic view it becomes a row in the strip above the chat. Free,
-- it floats on the bottom of the map - the root panel would drop it underneath the chat.
local function placementHost()
  if isPlacementForced() then return modules.game_interface.getRootPanel() end
  if isDocked() then return modules.game_interface.getBottomActionPanel() end
  return modules.game_interface.getMapPanel()
end

-- Only the strip runs a layout over the bar; the other two placements anchor and size themselves.
local function isInStrip()
  return isDocked() and not isPlacementForced()
end

function applyPlacement()
  if not actionBarWindow then return end
  local host = placementHost()
  if not host then return end
  local inStrip = isInStrip()

  if actionBarWindow:getParent() ~= host then
    actionBarWindow:breakAnchors()
    actionBarWindow:setParent(host)
  end
  if not inStrip then
    actionBarWindow:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    actionBarWindow:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  end
  -- in the strip the verticalBox stretches the bar across it. That is deliberate: the strip has no
  -- background of its own, so anything the bar does not cover reads as a black gap.

  if conditionBarWidget then
    conditionBarWidget:breakAnchors()
    if inStrip then
      -- not a row in the strip: an empty condition bar has no background and would show as a black
      -- band. It hangs off the strip's TOP rather than the map's bottom - gameMapPanel.bottom is
      -- anchored to gameBottomPanel.top, which is gameBottomActionPanel.bottom, so the map runs
      -- behind the strip and anchoring there drew the icons on top of the docked bar.
      conditionBarWidget:setParent(modules.game_interface.getRootPanel())
      conditionBarWidget:addAnchor(AnchorBottom, 'gameBottomActionPanel', AnchorTop)
      conditionBarWidget:addAnchor(AnchorLeft, 'gameBottomActionPanel', AnchorLeft)
      conditionBarWidget:addAnchor(AnchorRight, 'gameBottomActionPanel', AnchorRight)
    else
      conditionBarWidget:setParent(host)
      conditionBarWidget:addAnchor(AnchorBottom, 'playerActionBar', AnchorTop)
      conditionBarWidget:addAnchor(AnchorLeft, 'playerActionBar', AnchorLeft)
      conditionBarWidget:addAnchor(AnchorRight, 'playerActionBar', AnchorRight)
    end
    conditionBarWidget:setMarginBottom(2)
  end

  applyBarMode()
  refreshSlotLimit()
  -- the centre text messages sit above the bar, so they follow it between placements
  if modules.game_textmessage and modules.game_textmessage.refreshCenterMessagePlacement then
    modules.game_textmessage.refreshCenterMessagePlacement()
  end
end

function setActionBarDocked(docked)
  g_settings.set('actionBar-docked', docked)
  g_settings.save()
  applyPlacement()
end

function showPlacementMenu(mousePos)
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  if isDocked() then
    menu:addOption(tr('Show on game screen'), function() setActionBarDocked(false) end)
  else
    menu:addOption(tr('Remove from game screen'), function() setActionBarDocked(true) end)
  end
  menu:display(mousePos)
end

function refreshStatsRow()
  local player = g_game.getLocalPlayer()
  if not player then return end
  createConditionBar()
  onHealthChange(player, player:getHealth(), player:getMaxHealth())
  onLevelChange(player, player:getLevel(), player:getLevelPercent())
end

function init()
  connect(g_game, {
    onGameStart = onLogin,
    onGameEnd = onLogout,
    onItemList = onItemList,
    onItemUpdate = onItemUpdate,
    onUpdateItemCooldown = onUpdateItemCooldown
  })

  connect(LocalPlayer, {
    onHealthChange = onHealthChange,
    onExperienceChange = onExperienceChange,
    onLevelChange = onLevelChange
  })

  createActionBar()

  local mapPanel = modules.game_interface.getMapPanel()
  if mapPanel then
    connect(mapPanel, { onGeometryChange = refreshSlotLimit })
  end

  if g_game.isOnline() then
    show()
  end
end

function terminate()
  hide()
  disconnect(g_game, {
    onGameStart = onLogin,
    onGameEnd = onLogout,
    onItemList = onItemList,
    onItemUpdate = onItemUpdate,
    onUpdateItemCooldown = onUpdateItemCooldown
  })

  disconnect(LocalPlayer, {
    onHealthChange = onHealthChange,
    onExperienceChange = onExperienceChange,
    onLevelChange = onLevelChange
  })
  local mapPanel = modules.game_interface.getMapPanel()
  if mapPanel then
    disconnect(mapPanel, { onGeometryChange = refreshSlotLimit })
  end

  if updateBarItemEvent then
    removeEvent(updateBarItemEvent)
    updateBarItemEvent = nil
  end
  if slotLimitEvent then
    removeEvent(slotLimitEvent)
    slotLimitEvent = nil
  end

  if actionBarSlots then
    for i = 1, maxSlotCount do
      local widget = actionBarSlots:getChildById("ACTION_BAR_" .. i)
      if widget and widget.cooldownEvent then
        removeEvent(widget.cooldownEvent)
        widget.cooldownEvent = nil
      end
    end
  end

  destroyAssignWindows()

  if mouseGrabberWidget then
    mouseGrabberWidget:destroy()
    mouseGrabberWidget = false
  end
  if actionBarWindow then
    actionBarWindow:destroy()
    actionBarWindow = false
  end

  actionBarSlots = false
  slotsSeparator = false
  dexButton = false
  autoComboButton = false
  orderButton = nil
end

function onItemList(itemlist)
  ItemsCount = itemlist
  if updateBarItemEvent then
    removeEvent(updateBarItemEvent)
  end
  updateBarItemEvent = addEvent(function()
    setItemCount()
  end, 200)
end

function onItemUpdate(itemId, count)
  ItemsCount[itemId] = count
  local layout = actionBarSlots:getLayout()
  layout:disableUpdates()
  for i = 1, maxSlotCount do
    local widget = actionBarSlots:getChildById("ACTION_BAR_" .. i)
    if widget then
      local config = getHotkeysConfig(widget:getId())
      if config and config.itemId and config.itemId > 100 and config.itemId == itemId then
        widget.itemCount = 0
        setupButton(widget)
      end
    end
  end

  if itemId == 47864 then
    modules.game_prey.onPreyCardUpdate(count)
  elseif itemId == 39993 then
    modules.game_guild.onUpdateShopCoin(count)
  elseif itemId == 3028 then
    modules.game_store.onUpdateDiamondCount(count)
  end
  layout:enableUpdates()
  layout:update()
end

function onUpdateItemCooldown(itemId, groupId, cooldownSecs)
  if not itemId or itemId <= 0 or cooldownSecs <= 0 then return end

  local now = os.time()
  for i = 1, maxSlotCount do
    local widget = actionBarSlots:getChildById("ACTION_BAR_" .. i)
    if widget then
      local config = getHotkeysConfig(widget:getId())
      if config and config.itemId == itemId then
        widget.spellInfo = widget.spellInfo or {}

        if widget.cooldownEvent then
          removeEvent(widget.cooldownEvent)
          widget.cooldownEvent = nil
        end

        widget.spellInfo.cooldown  = cooldownSecs
        widget.spellInfo.startTime = now
        widget.spellInfo.endTime   = now + cooldownSecs

        startCooldown(widget)
      end
    end
  end
end

function cancelWidgetEvent(actionWidget)
    if actionWidget.cooldownEvent then
        removeEvent(actionWidget.cooldownEvent)
        actionWidget.cooldownEvent = nil
    end

    if actionWidget.progress then
      actionWidget.progress:hide()
    end
end

function updateCooldown(widget)
  if not widget or not widget.spellInfo or not widget.progress then
    cancelWidgetEvent(widget)
    return
  end

  local now       = os.time()
  local info      = widget.spellInfo
  local remaining = info.endTime - now

  if remaining <= 0 then
    cancelWidgetEvent(widget)
    return
  end

  if not widget.progress:isVisible() then
    widget.progress:show()
  end

  widget.progress:setText(remaining .. "s")
  local pct = 0
  widget.progress:setPercent(pct)
end

function resumeCooldown(widget)
  if not widget.spellInfo or not widget.spellInfo.endTime then return end
  updateCooldown(widget)  -- atualiza uma vez agora
  widget.cooldownEvent = cycleEvent(function()
    updateCooldown(widget)
  end, 1000)
end

function startCooldown(widget)
  if not widget or not widget.spellInfo then return end

  local now = os.time()
  widget.spellInfo.endTime = now + widget.spellInfo.cooldown

  updateCooldown(widget)
  widget.cooldownEvent = cycleEvent(function()
    updateCooldown(widget)
  end, 1000)
end

-- What the player asked for, in every placement. It is stored untouched even where the strip
-- overrides the count on screen, so undocking restores the chosen number instead of the fill.
local function desiredSlotCount()
  return modules.client_options.getOption('actionBarSize') or 12
end

-- In the strip there is no collapse button to undo it with, so the bar must never sit collapsed
-- there. Fullscreen keeps the button, so it keeps the player's choice.
local function isExpanded()
  return isInStrip() or g_settings.getBoolean('actionBar-mode', true)
end

local function setSlotRowVisible(visible)
  dexButton:setVisible(visible)
  orderButton:setVisible(visible)
  autoComboButton:setVisible(visible)
  slotsSeparator:setVisible(visible)
  actionBarSlots:setVisible(visible)
end

-- Collapsing hides the slot row and shrinks the window onto the stats row, which is what keeps HP,
-- level and experience on screen while minimised: they live in this same window.
function applyBarMode()
  if not actionBarWindow then return end
  local expanded = isExpanded()
  setSlotRowVisible(expanded)
  actionBarWindow:setHeight(expanded and EXPANDED_HEIGHT or COLLAPSED_HEIGHT)
  local collapseButton = actionBarWindow.hideButtonBackground
  collapseButton:setVisible(not isInStrip())
  collapseButton:setRotation(expanded and 180 or 0)
  addEvent(refreshStatsRow)
end

-- Width the bar needs on top of its slots: the fixed buttons, the separator and the margins between
-- them. It never varies with the slot count, so it is read off the laid-out widgets rather than
-- restated as a constant somebody has to keep in sync with the OTUI by hand.
local function chromeWidth()
  return actionBarSlots:getX() - actionBarWindow:getX()
end

-- The budget the bar must not overflow. Docked either way it is the strip, which spans between the
-- side panel columns - the root panel would let the bar slide underneath them. Floating it is the
-- map. It differs per monitor and shrinks when a side panel opens, hence a live measurement.
function maxSlotsThatFit()
  local host = isDocked() and modules.game_interface.getBottomActionPanel()
    or modules.game_interface.getMapPanel()
  if not host or not actionBarWindow or not actionBarSlots then return maxSlotCount end
  local room = host:getWidth() - chromeWidth()
  return math.max(1, math.min(maxSlotCount, math.floor(room / SLOT_WIDTH)))
end

-- Who sizes the bar decides who picks the count. In the strip the verticalBox stretches it across
-- the whole width, so anything short of a full row reads as an empty gap - there the count fills.
-- Everywhere else adjustActionBarWidth sizes the window to the count, so the slider is honoured.
-- The split is isInStrip, not isDocked: fullscreen docks the bar too, yet still sizes it.
local function resolveSlotCount(requested)
  local fits = maxSlotsThatFit()
  if isInStrip() then return fits end
  return math.max(1, math.min(requested or desiredSlotCount(), fits))
end

-- The map panel emits geometry changes continuously while the window is dragged, so the burst is
-- collapsed into one refresh and skipped outright when the fitting count did not actually move.
function refreshSlotLimit()
  if slotLimitEvent then return end
  slotLimitEvent = addEvent(function()
    slotLimitEvent = nil
    if not actionBarWindow or not actionBarSlots then return end
    local count = resolveSlotCount()
    if count ~= visibleSlotCount then
      showSlots(count)
    end
  end)
end

function show()
  showSlots(desiredSlotCount())
  reloadAllSlots()
  local player = g_game.getLocalPlayer()
  if player then
    onItemList(player:getItemsList())
  end
  -- deferred: anchors.fill resolves on the next layout pass, so measuring now would size the fill
  -- against a stale width
  addEvent(refreshStatsRow)
  actionBarWindow:show()
  applyPlacement()
end
function hide()
  actionBarWindow:hide()
end
function onLogin()
  show()
end
function onLogout()
  hide()
  ItemsCount = {}
end
function isChatStateCorrect(chatEnabled)
  local chatModeEnabled = not modules.game_chat.consoleToggleChat
  return (chatEnabled and chatModeEnabled) or (not chatEnabled and not chatModeEnabled)
end

function updateUI(chatState)
  local registryKeys = HotkeyRegistry:getBoundKeys("actionProfile")
  for actionName, chatStateKeys in pairs(registryKeys) do
    local actionSlot = getActionSlot(actionName)
    if actionSlot then
      local stateKeys = chatStateKeys[chatState]
      local primaryKey = stateKeys and stateKeys.primaryKey
      actionSlot.hotkeyLabel:setText(primaryKey and translateHotkeyDesc(primaryKey.keyInfo.key) or "")
    end
  end
end
function adjustActionBarWidth(count)
  -- in the strip the width belongs to its layout; setting it here would only thrash it
  if not isInStrip() then
    actionBarWindow:setWidth(chromeWidth() + (count * SLOT_WIDTH))
  end
  actionBarWindow:setHeight(isExpanded() and EXPANDED_HEIGHT or COLLAPSED_HEIGHT)
  -- the exp bar stretches with the window, so its fill has to be measured again after the resize
  addEvent(refreshStatsRow)
end
function getHotkeysConfig(id)
  local config = g_settings.getNode('actionBarSettings')
  if config and config[id] then
    return config[id]
  end
  return {}
end
function updateHotkeysConfig(id, newConfig)
  local config = {}
  if g_settings.exists("actionBarSettings") then
    config = g_settings.getNode('actionBarSettings')
  end
  config[id] = newConfig
  g_settings.setNode('actionBarSettings', config)
end
function clearHotkeysConfig()
  if g_settings.exists("actionBarSettings") then
    g_settings.setNode('actionBarSettings', {})
  end
  reloadAllSlots()
end
function showSlots(count)
  count = resolveSlotCount(count)
  visibleSlotCount = count
  for i = 1, maxSlotCount do
    local widget = actionBarSlots:getChildById("ACTION_BAR_" .. i)
    if widget then
      if i <= count then
        widget:setVisible(true)
        setupButton(widget)
      else
        widget:setVisible(false)
      end
    end
  end
  adjustActionBarWidth(count)
end
function hideAllSlots()
  for i = 1, maxSlotCount do
    local widget = actionBarSlots:getChildById("ACTION_BAR_" .. i)
    if widget then
      widget:setVisible(false)
    end
  end
end
function reloadAllSlots()
  for i = 1, maxSlotCount do
    local widget = actionBarSlots:getChildById("ACTION_BAR_" .. i)
    if widget then
      setupButton(widget)
    end
  end
  setupStaticButton(dexButton)
  setupStaticButton(orderButton)
  setupStaticButton(autoComboButton)
end
function updateSlotCount(count)
  hideAllSlots()
  showSlots(count)
end
function updateHotkeyDelay(count)
  hotkeyDelay = count
end
function usePokedexItem(...)
  local args = {...}
  local item = g_game.getLocalPlayer():getInventoryItem(InventorySlotPokedex)
  if item then
    modules.game_interface.startUseWith(item, -1)
    if #args >= 2 and type(args[1]) == "table" then
      local mousePosition = args[1]
      local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
      if clickedWidget then
        modules.game_interface.onUseWith(clickedWidget, mousePosition)
      end
    end
  end
end

function useAutoCombo(...)
  modules.game_pokemoves.sendAutoCombo("!autocombo")
end

function orderAt(mousePosition)
  local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
  modules.game_interface.startUseWith(Item.create(ORDER_CLIENT_ID), -1)
  -- No widget under the cursor: leave the crosshair armed so the next click orders.
  if not clickedWidget then
    return false
  end

  modules.game_interface.onUseWith(clickedWidget, mousePosition)
  modules.game_interface.cancelUseWith()

  return true
end

function useOrderItem()
  orderAt(g_window.getMousePosition())
end

function setItemCount()
  local layout = actionBarSlots:getLayout()
  layout:disableUpdates()
  for i = 1, maxSlotCount do
    local widget = actionBarSlots:getChildById("ACTION_BAR_" .. i)
    if widget then
      widget.itemCount = 0
      setupButton(widget)
    end
  end
  layout:enableUpdates()
  layout:update()
  updateBarItemEvent = nil
end

function setupButton(widget)
  resetWidget(widget)
  applyInitialConfig(widget)
  widget.callback = function(fromClick) setupAction(widget, fromClick) end
  widget.item.onDragEnter = function(self)
    if g_ui.isMouseGrabbed() then return end
    mouseGrabberWidget:grabMouse()
    g_mouse.pushCursor('target')
    self:setBorderColor('#FFFFFF')
    cachedSettings = { id = widget:getId(), data = config, widget = widget }
  end
  widget.onMouseRelease = function(widget, mousePos, mouseButton)
    if mouseButton == MouseRightButton then
      local menu = g_ui.createWidget('PopupMenu')
      menu:setGameMenu(true)
      if widget.item:getItemId() > 100 then
        menu:addOption(tr('Edit Object'), function() assignItem(widget) end)
      end
      menu:addOption(widget.text:getText():len() > 0 and tr('Edit Text') or tr('Assign Text'), function() assignText(widget) end)
      menu:addOption(widget.hotkeyLabel:getText():len() > 0 and tr('Edit Hotkey') or tr('Assign Hotkey'), function() modules.client_hotkeys.show("actionProfile", widget:getId()) end)
      if widget.type > 0 then
        menu:addSeparator()
        menu:addOption(tr('Clear Action'), function() resetSlot(widget) end)
      end
      menu:display(mousePos)
    elseif mouseButton == MouseLeftButton and widget.callback then
      widget.callback(true)
    end
    return true
  end
  widget.item.onItemChange = function(widget)
    assignItem(widget:getParent())
  end
  local itemAction
  if widget.type == TYPE.ITEM then
    if widget.action == ACTION.USE then
      itemAction = "Use this object"
    elseif widget.action == ACTION.USE_SELF then
      itemAction = "Use this object on Yourself"
    elseif widget.action == ACTION.USE_TARGET then
      itemAction = "Use this object on Attack Target"
    elseif widget.action == ACTION.USE_CROSS then
      itemAction = "Use this object with Crosshair"
    elseif widget.action == ACTION.SMART_USE then
      itemAction = "Use this object in Mouse Position"
    elseif widget.action == ACTION.AUTO_REVIVE then
      itemAction = "Auto Revive"
    elseif widget.action == ACTION.ON_POKEMON then
      itemAction = "On Pokémon"
    end
  end
  local actionDesc = ""
  if widget.type == TYPE.BLANK then
    actionDesc = "None"
  elseif widget.type == TYPE.TEXT then
    actionDesc = 'Say: "' .. widget.text:getText() .. '"\n'
    actionDesc = actionDesc .. "Auto sent:  " .. (widget.autoSay and "Yes" or "No")
  elseif widget.type == TYPE.ITEM then
    actionDesc = itemAction
  end
  if not actionDesc then
    actionDesc = ""
  end
  local hotkeyDesc = widget.hotkey and widget.hotkey:len() > 0 and widget.hotkey or "None"
  local tooltip = "Action Button " .. widget:getId()
  tooltip = tooltip .. "\n\n\tAction:  " .. actionDesc
  tooltip = tooltip .. "\nHotkeys:  " .. hotkeyDesc
  widget.item:setTooltip(tooltip)
end

function setupStaticButton(widget)
  widget.type = TYPE.ITEM
  widget.onMouseRelease = function(widget, mousePos, mouseButton)
    if mouseButton == MouseRightButton then
      local menu = g_ui.createWidget('PopupMenu')
      menu:setGameMenu(true)
      menu:addOption(widget.hotkeyLabel:getText():len() > 0 and tr('Edit Hotkey') or tr('Assign Hotkey'), function() modules.client_hotkeys.show("actionProfile", widget:getId()) end)
      menu:display(mousePos)
    elseif mouseButton == MouseLeftButton and widget.callback then
      widget.callback()
    end
    return true
  end
end
function setupAction(widget, fromClick)
  if widget.type == TYPE.BLANK then
    return
  end
  if widget.hotkeyDelayTo ~= nil and g_clock.millis() < widget.hotkeyDelayTo then
    return
  end
  if widget.type == TYPE.TEXT then
    if widget.autoSay then
      modules.game_chat.sendMessage(widget.sayText)
    else
      modules.game_chat.setTextEditText(widget.sayText)
    end
    widget.hotkeyDelayTo = g_clock.millis() + hotkeyDelay
  elseif widget.type == TYPE.ITEM then
    -- Exclusivo do clique: pela hotkey o slot faz a acao configurada, sem entrar em mira.
    if fromClick and widget.action ~= ACTION.AUTO_REVIVE then
      local item = Item.create(widget.item:getItemId())
      if item:isMultiUse() then
        modules.game_interface.startUseWith(item, widget.item:getItemSubType() or -1)
        return
      end
    end

    if widget.action == ACTION.USE then
      g_game.useInventoryItem(widget.item:getItemId())
      widget.hotkeyDelayTo = g_clock.millis() + hotkeyDelay
    elseif widget.action == ACTION.USE_SELF then
      g_game.useInventoryItemWith(widget.item:getItemId(), g_game.getLocalPlayer(), widget.item:getItemSubType() or -1)
      widget.hotkeyDelayTo = g_clock.millis() + hotkeyDelay
    elseif widget.action == ACTION.USE_TARGET then
      local attackingCreature = g_game.getAttackingCreature()
      if not attackingCreature then
        local item = Item.create(widget.item:getItemId())
        modules.game_interface.startUseWith(item, widget.item:getItemSubType() or -1)
        return
      end
      if not attackingCreature:getTile() then return end
      g_game.useInventoryItemWith(widget.item:getItemId(), attackingCreature, widget.item:getItemSubType() or -1)
      widget.hotkeyDelayTo = g_clock.millis() + hotkeyDelay
    elseif widget.action == ACTION.USE_CROSS then
      local item = Item.create(widget.item:getItemId())
      modules.game_interface.startUseWith(item, widget.item:getItemSubType() or -1)
    elseif widget.action == ACTION.SMART_USE then
      local item = Item.create(widget.item:getItemId())
      local mousePosition = g_window.getMousePosition()
      local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
      if clickedWidget then
        local thing = nil
        local className = clickedWidget:getClassName()
        if className == "UIGameMap" then
          local tile = clickedWidget:getTile(mousePosition)
          if tile then
            thing = tile:getTopLookThing()
          end
        elseif className == "UIItem" then
          thing = clickedWidget:getItem()
        end

        if thing then
          g_game.useWith(item, thing)
          widget.hotkeyDelayTo = g_clock.millis() + hotkeyDelay
        end
      end
    elseif widget.action == ACTION.AUTO_REVIVE then
      g_game.useOnPokeball(widget.item:getItemId(), widget.item:getItemSubType() or -1)
      widget.hotkeyDelayTo = g_clock.millis() + 1000
    elseif widget.action == ACTION.ON_POKEMON then
      g_game.useOnPokemon(widget.item:getItemId(), widget.item:getItemSubType() or -1)
      widget.hotkeyDelayTo = g_clock.millis() + hotkeyDelay
    end
  end
end
function resetWidget(widget)
  widget.item.onItemChange = nil
  widget.item:setItemShader()
  widget.item:setItemId(0)
  widget.item:setOn(false)
  widget.item:setItemVisible(true)
  widget.type = TYPE.BLANK
  widget.text:setText("")
  widget.autoSay = nil
  widget.action = ACTION.BLANK
  widget.callback = nil
end
function applyInitialConfig(widget)
  local config = getHotkeysConfig(widget:getId())
  if not config then return end
  widget.type = config.type or TYPE.BLANK
  widget.text:setText(reduceText(tostring(config.sayText or "")))
  widget.sayText = tostring(config.sayText or "")
  widget.autoSay = config.autoSay
  widget.action = config.action
  widget.item:setOn(true)
  if widget.item:getItemId() ~= (config.itemId and config.itemId > 100 and config.itemId or 0) then
    local itemCount = ItemsCount[config.itemId] or 0
    widget.item:setItem(Item.create(config.itemId, itemCount))
  end
  if widget.type == TYPE.BLANK then
    widget.item:setItemVisible(false)
    widget.item:setOn(false)
  end
  widget.text:setImageSource('')
end
function resetSlot(widget)
  updateHotkeysConfig(widget:getId(), {})
  setupButton(widget)
end
function assignItem(widget)
  destroyAssignWindows()
  local radio = UIRadioGroup.create()
  local item = widget.item:getItem()
  local id = widget.item:getItemId()
  if id == 0 and widget.item:isOn() then
    return resetSlot(widget)
  end
  local window = g_ui.loadUI('object', modules.game_interface.getRootPanel())
  window:show()
  window:raise()
  window:focus()
  window:setText("Assign Object to Action Button " .. widget:getId())
  window:setId("assignItemWindow")
  window.item:setShowCount(false)
  window.item.onItemChange = function(widget)
    local item = window.item:getItem()
    if item then
      local known = item:getId() >= 100
      local multiUse = known and item:isMultiUse()
      for i, child in ipairs(window.checks:getChildren()) do
        radio:addWidget(child)
        child:setEnabled(known and (i >= 4 or multiUse))
      end
      if known then
        radio:selectWidget(window.checks.use)
      end
    end
    window.buttonOk:setEnabled(item and item:getId() > 100)
    window.buttonApply:setEnabled(item and item:getId() > 100)
  end
  window.item:setItemId(id)
  local actionType = widget.action or 0
  if actionType > ACTION.BLANK then
    local id
    if actionType == ACTION.USE_SELF then
      id = "useSelf"
    elseif actionType == ACTION.USE_TARGET then
      id = "useTarget"
    elseif actionType == ACTION.USE_CROSS then
      id = "useCross"
    elseif actionType == ACTION.USE then
      id = "use"
    elseif actionType == ACTION.SMART_USE then
      id = "smartUse"
    elseif actionType == ACTION.AUTO_REVIVE then
      id = "autorevive"
    elseif actionType == ACTION.ON_POKEMON then
      id = "onpokemon"
    end
    for i, child in ipairs(radio.widgets) do
      local childId = child:getId()
      if childId == id then
        radio:selectWidget(child)
        break
      end
    end
  end
  local okFunc = function(destroy)
    local config = getHotkeysConfig(widget:getId())
    config.itemId = window.item:getItemId()
    config.type = TYPE.ITEM
    config.sayText = ""
    config.autoSay = false
    local selected = radio:getSelectedWidget():getId()
    if selected == "useSelf" then
      config.action = ACTION.USE_SELF
    elseif selected == "useTarget" then
      config.action = ACTION.USE_TARGET
    elseif selected == "useCross" then
      config.action = ACTION.USE_CROSS
    elseif selected == "use" then
      config.action = ACTION.USE
    elseif selected == "smartUse" then
      config.action = ACTION.SMART_USE
    elseif selected == "autorevive" then
      config.action = ACTION.AUTO_REVIVE
    elseif selected == "onpokemon" then
      config.action = ACTION.ON_POKEMON
    end
    if destroy then
      window:destroy()
      radio:destroy()
    end
    updateHotkeysConfig(widget:getId(), config)
    setupButton(widget)
  end
  local cancelFunc = function()
    setupButton(widget)
    window:destroy()
    radio:destroy()
  end
  window.buttonOk.onClick = function() okFunc(true) end
  window.onEnter = function() okFunc(true) end
  window.buttonApply.onClick = function() okFunc(false) end
  window.buttonClose.onClick = cancelFunc
  window.onEscape = cancelFunc
end
function assignText(widget)
  destroyAssignWindows()
  local window = g_ui.loadUI('text', g_ui.getRootWidget())
  window:show()
  window:raise()
  window:focus()
  window.buttonOk:setEnabled(false)
  window.buttonApply:setEnabled(false)
  window.text.onTextChange = function(self, text)
    window.buttonOk:setEnabled(text:len() > 0)
    window.buttonApply:setEnabled(text:len() > 0)
  end
  window.text:setText(widget.sayText)
  if widget.type > 0 then
    window.checkPanel.tick:setChecked(widget.autoSay)
  end
  local okFunc = function(destroy)
    local text = window.text:getText()
    if text:len() <= 0 then return end
    local autoSay = window.checkPanel.tick:isChecked()
    local config = getHotkeysConfig(widget:getId())
    config.sayText = text
    config.type = TYPE.TEXT
    config.autoSay = autoSay
    if destroy then
      window:destroy()
    end
    updateHotkeysConfig(widget:getId(), config)
    setupButton(widget)
  end
  local cancelFunc = function()
    window:destroy()
    setupButton(widget)
  end
  window.buttonOk.onClick = function() okFunc(true) end
  window.buttonApply.onClick = function() okFunc(false) end
  window.buttonClose.onClick = cancelFunc
  window.onEscape = cancelFunc
  window.onEnter = function() okFunc(true) end
end
function translateHotkeyDesc(text)
  if not text then
    return ""
  end
  text = tostring(text)
  for i, v in pairs(HOTKEYS_CONFIG) do
    text = text:gsub(v[1], v[2])
  end
  return reduceText(text)
end
function reduceText(text)
  if text:len() > 4 then
    text = text:sub(1, 4)
  end
  return text
end
function destroyAssignWindows()
  local windows = {
    'assignItemWindow',
    'assignTextWindow'
  }
  local rootWidget = g_ui.getRootWidget()
  for i, id in ipairs(windows) do
    local widget = rootWidget[id]
    if widget then
      widget:destroy()
    end
  end
end

function onDropActionButton(self, mousePosition, mouseButton)
  if not g_ui.isMouseGrabbed() then return end
  local clicked = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
  if not (clicked and clicked:getParent() and clicked:getParent():getStyleName():find('ActionButton')) then
    goto finish
  end

  if cachedSettings then
    local dst = clicked:getParent()
    if dst ~= cachedSettings.widget then
      local cfgA = getHotkeysConfig(cachedSettings.id)
      local cfgB = getHotkeysConfig(dst:getId())
      cfgA.hotkey, cfgB.hotkey = cfgB.hotkey, cfgA.hotkey
      updateHotkeysConfig(dst:getId(), cfgA)
      updateHotkeysConfig(cachedSettings.id, cfgB)
      local infoA = cachedSettings.widget.spellInfo
      local infoB = dst.spellInfo
      cachedSettings.widget.spellInfo, dst.spellInfo = infoB, infoA
      setupButton(cachedSettings.widget)
      setupButton(dst)
      cancelWidgetEvent(cachedSettings.widget)
      cancelWidgetEvent(dst)
      local now = os.time()
      if infoA and infoA.endTime > now then
        dst.spellInfo = infoA
        resumeCooldown(dst)
      end
      if infoB and infoB.endTime > now then
        cachedSettings.widget.spellInfo = infoB
        resumeCooldown(cachedSettings.widget)
      end
    end
  end

  ::finish::
  cachedSettings.widget.item:setBorderColor('#00000000')
  cachedSettings = nil
  g_mouse.popCursor('target')
  self:ungrabMouse()
end

function slideActionBar()
  if not actionBarWindow then return end
  g_settings.set('actionBar-mode', not isExpanded())
  applyBarMode()
end

function getPlayerItemCount(itemId)
  return ItemsCount[itemId] or 0
end