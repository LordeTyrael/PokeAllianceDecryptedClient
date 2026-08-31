local MIN_OPACITY = 20
local MAX_OPACITY = 100
local MAX_DELAY_SECONDS = 10

local groups = nil

local function configuredOpacity()
    return math.min(math.max(g_settings.getNumber("sidePanelOpacity"), MIN_OPACITY), MAX_OPACITY) / 100
end

local function fadeDelayMs()
    return math.min(math.max(g_settings.getNumber("sidePanelFadeDelay"), 0), MAX_DELAY_SECONDS) * 1000
end

local function belongsTo(group, widget)
    while widget do
        if widget == group.dock or widget == group.column then
            return true
        end
        widget = widget:getParent()
    end
    return false
end

-- HoverState is exclusive to the deepest widget and the containers are phantom, so resolve the
-- cursor the way the engine does
local function widgetUnderMouse(mousePos)
    return rootWidget:recursiveGetChildByPos(mousePos, false)
end

local function isSolid(group, hovered, dragging, pressed)
    -- any drag keeps every group legible: the player is looking for a drop target
    return dragging or belongsTo(group, hovered) or belongsTo(group, pressed)
end

local function fadeGroup(group)
    group.delayEvent = nil
    local target = configuredOpacity()
    local time = g_effects.getFadeOutTime()
    g_effects.fadeTo(group.dock, target, time)
    g_effects.fadeTo(group.column, target, time)
end

local function setGroupSolid(group, solid)
    if group.solid == solid then
        return
    end
    group.solid = solid
    removeEvent(group.delayEvent)
    group.delayEvent = nil

    if solid then
        g_effects.cancelFade(group.dock)
        g_effects.cancelFade(group.column)
        group.dock:setOpacity(1)
        group.column:setOpacity(1)
        return
    end

    local delay = fadeDelayMs()
    if delay > 0 then
        group.delayEvent = scheduleEvent(function() fadeGroup(group) end, delay)
    else
        fadeGroup(group)
    end
end

local function onSidePanelMouseMove(mousePos)
    -- a grab routes input to a popup or a targeting cursor, so freeze instead of reading the cursor
    if g_ui.isMouseGrabbed() then
        return
    end

    local hovered = widgetUnderMouse(mousePos)
    local dragging = g_ui.getDraggingWidget() ~= nil
    local pressed = g_ui.getPressedWidget()
    for i = 1, #groups do
        setGroupSolid(groups[i], isSolid(groups[i], hovered, dragging, pressed))
    end
end

function stopSidePanelFade()
    if not groups then
        return
    end

    disconnect(g_ui, {onMouseMove = onSidePanelMouseMove})
    for i = 1, #groups do
        local group = groups[i]
        removeEvent(group.delayEvent)
        g_effects.cancelFade(group.dock)
        g_effects.cancelFade(group.column)
        group.dock:setOpacity(1)
        group.column:setOpacity(1)
    end
    groups = nil
end

function applySidePanelOpacity()
    stopSidePanelFade()

    if g_app.isMobile() or not g_game.isOnline() or g_settings.getBoolean("classicView") then
        return
    end
    -- at full opacity UIWidget::draw skips the opacity path entirely, so disarmed costs nothing
    if g_settings.getNumber("sidePanelOpacity") >= MAX_OPACITY then
        return
    end

    groups = {
        {dock = horizontalLeftDock, column = gameLeftPanels},
        {dock = horizontalRightDock, column = gameRightPanels}
    }

    local hovered = widgetUnderMouse(g_window.getMousePosition())
    local dragging = g_ui.getDraggingWidget() ~= nil
    local pressed = g_ui.getPressedWidget()
    local resting = configuredOpacity()
    for i = 1, #groups do
        local group = groups[i]
        group.solid = isSolid(group, hovered, dragging, pressed)
        local opacity = group.solid and 1 or resting
        group.dock:setOpacity(opacity)
        group.column:setOpacity(opacity)
    end

    connect(g_ui, {onMouseMove = onSidePanelMouseMove})
end
