POSITION_TOP_LEFT = 1
POSITION_TOP_RIGHT = 2
POSITION_BOTTOM_LEFT = 3
POSITION_BOTTOM_RIGHT = 4

local DEFAULT_DURATION = 8000
local TIMER_TICK = 50
local MAX_CARDS = 4
local EDGE_MARGIN = 12

-- Card geometry, kept here because the height is derived per notification:
-- 9 (top pad) + 17 (title) + 3 + message + 9 (bottom pad), and never below the icon slot
-- (48 + padding) when there is an icon to hold.
local PAD = 9
local TIMER_ROOM = 6  -- 2px bar + 4px margin at the bottom of the card
local TITLE_HEIGHT = 17
local TITLE_GAP = 3
local ICON_MIN_HEIGHT = 68
local TEXT_LEFT_WITH_ICON = 68
local TEXT_LEFT_NO_ICON = 10
local TEXT_WIDTH_WITH_ICON = 207
local TEXT_WIDTH_NO_ICON = 265
local TITLE_COLOR = '#ffffff'

local stack
local position = POSITION_TOP_RIGHT
local hideEvents = {}
local appliedMargins
local onGeometryChange
local timerEvent

-- poppins ships spacing: 4 -5, so each line after the first advances 5px less than the
-- glyphs need and calculateTextRectSize reports a box shorter than what gets drawn. The
-- two numbers are measured once from a real label instead of hardcoding the 5.
local lineHeight = 0
local lineAdvance = 0

local function measureTextMetrics(card)
  local label = card.message
  local text = label:getText()

  label:setText('M')
  lineHeight = label:getHeight()
  label:setText('M\nM')
  lineAdvance = label:getHeight() - lineHeight
  label:setText(text)
end

local function textBlockHeight(reportedHeight)
  if lineAdvance <= 0 then return reportedHeight end

  local extraLines = math.max(0, math.floor((reportedHeight - lineHeight) / lineAdvance + 0.5))
  return reportedHeight + (lineHeight - lineAdvance) * extraLines
end

--- One event drives every countdown bar: N cards would otherwise mean N timers at 20Hz.
local function updateTimers()
  if not stack then return end

  local running = false
  local now = g_clock.millis()
  for _, card in ipairs(stack:getChildren()) do
    if card.duration and not card.dismissing then
      local left = math.max(card.shownAt + card.duration - now, 0)
      card.timerTrack.timerFill:setWidth(math.floor(card.timerTrack:getWidth() * left / card.duration))
      running = true
    end
  end

  if not running then
    removeEvent(timerEvent)
    timerEvent = nil
  end
end

function startTimers()
  if timerEvent then return end
  timerEvent = cycleEvent(updateTimers, TIMER_TICK)
end

local function destroyCard(card)
  local event = hideEvents[card]
  if event then
    removeEvent(event)
    hideEvents[card] = nil
  end
  g_effects.cancelFade(card)
  card:destroy()
end

--- immediate skips the fade (game end / terminate, where the widget is going away anyway).
local function dismiss(card, immediate)
  if not card or card:isDestroyed() or card.dismissing then return end
  card.dismissing = true

  local fadeTime = g_effects.getFadeOutTime()
  if immediate or fadeTime <= 0 then
    destroyCard(card)
    return
  end

  g_effects.fadeOut(card)
  -- the card keeps its slot in the stack while it fades, so the ones below don't jump twice
  hideEvents[card] = scheduleEvent(function()
    hideEvents[card] = nil
    destroyCard(card)
  end, fadeTime)
end

function clear()
  if not stack then return end
  for _, card in ipairs(stack:getChildren()) do
    dismiss(card, true)
  end
end

--- The stack sits in gameRootPanel, not in the map panel: the docked side/bottom panels are
--- siblings of the map panel and are painted after it, so a card parented to the map would
--- render behind the minimap and the mini-windows. Being a sibling of those panels means the
--- corners have to clear them explicitly, which is what this derives — from the live widgets,
--- so it follows the view mode, the panel count and the optional top bar on its own.
local function insetOf(widget, root, edge)
  if not widget or not widget:isVisible() or widget:getWidth() <= 0 or widget:getHeight() <= 0 then
    return 0
  end

  if edge == 'top' then return (widget:getY() + widget:getHeight()) - root:getY() end
  if edge == 'bottom' then return (root:getY() + root:getHeight()) - widget:getY() end
  if edge == 'left' then return (widget:getX() + widget:getWidth()) - root:getX() end
  return (root:getX() + root:getWidth()) - widget:getX()
end

local function cornerMargins()
  local root = modules.game_interface.getRootPanel()
  if not root then return EDGE_MARGIN, EDGE_MARGIN, EDGE_MARGIN, EDGE_MARGIN end

  local function inset(widget, edge)
    return math.max(insetOf(widget, root, edge), 0) + EDGE_MARGIN
  end

  local top = math.max(inset(modules.client_topmenu and modules.client_topmenu.getTopMenu(), 'top'),
                       inset(root:getChildById('gameTopBar'), 'top'))
  local bottom = inset(root:getChildById('gameBottomPanel'), 'bottom')
  local left = inset(root:getChildById('gameLeftPanels'), 'left')
  local right = inset(root:getChildById('gameRightPanels'), 'right')

  return top, bottom, left, right
end

function setPosition(index)
  position = tonumber(index) or position
  if not stack then return end

  local topMargin, bottomMargin, leftMargin, rightMargin = cornerMargins()
  appliedMargins = topMargin .. ':' .. bottomMargin .. ':' .. leftMargin .. ':' .. rightMargin

  stack:breakAnchors()
  stack:setMarginTop(0)
  stack:setMarginLeft(0)
  stack:setMarginRight(0)
  stack:setMarginBottom(0)

  local top = position == POSITION_TOP_LEFT or position == POSITION_TOP_RIGHT
  local left = position == POSITION_TOP_LEFT or position == POSITION_BOTTOM_LEFT

  stack:addAnchor(top and AnchorTop or AnchorBottom, 'parent', top and AnchorTop or AnchorBottom)
  stack:addAnchor(left and AnchorLeft or AnchorRight, 'parent', left and AnchorLeft or AnchorRight)

  if top then stack:setMarginTop(topMargin) else stack:setMarginBottom(bottomMargin) end
  if left then stack:setMarginLeft(leftMargin) else stack:setMarginRight(rightMargin) end

  stack:raise()
end

function getPosition()
  return position
end

--- Re-derive the corner margins in place. refreshViewMode calls this after it moves the
--- map panel: onGeometryChange alone is not enough, the view mode also changes what is
--- painted over the panel without changing the panel's own rect.
function refreshPosition()
  setPosition(position)
end

local function applyIcon(card, data)
  if data.itemId then
    card.item:setItemId(data.itemId)
    card.item:setItemCount(data.itemCount or 1)
    card.item:setVisible(true)
    return true
  end

  local outfit = data.outfit or (data.lookType and { type = data.lookType })
  if outfit then
    card.creature:setOutfit(outfit)
    card.creature:setVisible(true)
    return true
  end

  if data.imageSource then
    card.icon:setImageSource(data.imageSource)
    if data.imageClip then card.icon:setImageClip(data.imageClip) end
    card.icon:setVisible(true)
    return true
  end

  return false
end

local function findCard(identifier)
  for _, card in ipairs(stack:getChildren()) do
    if card.identifier == identifier and not card.dismissing then
      return card
    end
  end
end

--- A replaced card keeps the widget it already has, so everything fillCard writes into one has
--- to be undone here or the previous notification bleeds into the new one.
local function resetCard(card)
  local event = hideEvents[card]
  if event then
    removeEvent(event)
    hideEvents[card] = nil
  end

  card.icon:setVisible(false)
  card.creature:setVisible(false)
  card.item:setVisible(false)
  card.onClick = nil
  card:setCursor()
  card.shownAt = nil
  card.duration = nil
end

local function fillCard(card, data)
  local hasIcon = applyIcon(card, data)
  card.title:setMarginLeft(hasIcon and TEXT_LEFT_WITH_ICON or TEXT_LEFT_NO_ICON)
  local textWidth = hasIcon and TEXT_WIDTH_WITH_ICON or TEXT_WIDTH_NO_ICON
  card.title:setWidth(textWidth)
  card.message:setWidth(textWidth)

  local duration = data.duration or g_settings.getNumber('notificationDuration', DEFAULT_DURATION / 1000) * 1000

  card.title:setText(data.title or '')
  card.title:setColor(data.titleColor or TITLE_COLOR)
  card.message:setText(data.message or '')

  local contentHeight = PAD + TITLE_HEIGHT + TITLE_GAP + textBlockHeight(card.message:getHeight()) + PAD
  if duration > 0 then contentHeight = contentHeight + TIMER_ROOM end
  card:setHeight(hasIcon and math.max(ICON_MIN_HEIGHT, contentHeight) or contentHeight)

  card.closeButton.onClick = function() dismiss(card) end
  if data.onClick then
    card.onClick = function()
      data.onClick()
      dismiss(card)
    end
    card:setCursor('pointer')
  end

  card.timerTrack:setVisible(duration > 0)
  if duration > 0 then
    card.shownAt = g_clock.millis()
    card.duration = duration
    hideEvents[card] = scheduleEvent(function()
      hideEvents[card] = nil
      dismiss(card)
    end, duration)
    startTimers()
  end

  -- g_sounds only exists when the framework was built with FW_SOUND (FRAMEWORK_SOUND is
  -- OFF in the CMake dev path), so a notification must not depend on it being there.
  if data.sound and g_sounds and g_sounds.isAudioEnabled() then
    g_sounds.play(data.sound)
  end
end

--- show{ title, message, imageSource|itemId|outfit|lookType, titleColor, sound, duration,
---       identifier, onClick }
--- duration is in ms and defaults to the notificationDuration option; 0 keeps the card until
--- it is dismissed and hides the countdown bar. sound is a path under data/sounds and only
--- plays when the player has audio on. identifier rewrites the card already on screen that
--- carries the same one instead of stacking a second one, so a repeating notification (the
--- shutdown countdown) updates in place. Returns the card.
function show(data)
  if not stack then return end

  local identifier = data.identifier
  if identifier == '' then identifier = nil end

  local card = identifier and findCard(identifier)
  if card then
    resetCard(card)
    fillCard(card, data)
    stack:raise()
    return card
  end

  card = g_ui.createWidget('NotificationCard', stack)
  card.identifier = identifier
  fillCard(card, data)

  card:setOpacity(0)
  g_effects.fadeIn(card)
  stack:raise()  -- another module may have raised itself over us since the last card

  -- a card on its way out still holds its slot, so it does not count against the cap
  local alive = {}
  for _, other in ipairs(stack:getChildren()) do
    if not other.dismissing then table.insert(alive, other) end
  end
  for i = 1, #alive - MAX_CARDS do
    dismiss(alive[i])
  end

  return card
end

function init()
  g_ui.importStyle('notifications')
  stack = g_ui.createWidget('NotificationStack', modules.game_interface.getRootPanel())
  setPosition(g_settings.getNumber('notificationPosition', POSITION_TOP_RIGHT))

  local probe = g_ui.createWidget('NotificationCard', stack)
  measureTextMetrics(probe)
  probe:destroy()

  connect(g_game, {
    onGameEnd = clear,
    onGameStart = refreshPosition,
    onNotification = show
  })

  -- switching the view mode or resizing moves the chrome. onGeometryChange fires on every
  -- frame of a window resize, so re-anchor only when the derived margins actually moved.
  onGeometryChange = function()
    local top, bottom, left, right = cornerMargins()
    if (top .. ':' .. bottom .. ':' .. left .. ':' .. right) ~= appliedMargins then
      setPosition(position)
    end
  end
  connect(modules.game_interface.getRootPanel(), { onGeometryChange = onGeometryChange })
end

function terminate()
  disconnect(g_game, {
    onGameEnd = clear,
    onGameStart = refreshPosition,
    onNotification = show
  })

  removeEvent(timerEvent)
  timerEvent = nil
  local root = modules.game_interface.getRootPanel()
  if root and onGeometryChange then
    disconnect(root, { onGeometryChange = onGeometryChange })
    onGeometryChange = nil
  end

  clear()  -- immediate: the stack is about to be destroyed under any pending fade
  if stack then
    stack:destroy()
    stack = nil
  end
end
