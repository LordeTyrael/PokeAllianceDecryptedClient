-- @docclass
g_effects = {}

-- Single source of truth for fade duration: callers omit `time` and get the Options -> Interface
-- value, so the client fades at one speed. Only effects that are not window transitions (tooltips,
-- the autoloot icon) pass their own duration.
FADE_DEFAULT_TIME = 500

local FADE_STEP_MS = 30
-- smallest change a colour channel can express: below it the fade is invisible and only costs work
local FADE_MIN_DELTA = 1/255

local function fadeTime(key)
  local value = g_settings.getNumber(key, FADE_DEFAULT_TIME)
  if value < 0 then return 0 end
  if value > FADE_DEFAULT_TIME then return FADE_DEFAULT_TIME end
  return value
end

function g_effects.getFadeInTime()
  return fadeTime('fadeInTime')
end

function g_effects.getFadeOutTime()
  return fadeTime('fadeOutTime')
end

function g_effects.fadeIn(widget, time, elapsed)
  if not widget then return end
  if not elapsed then
    elapsed = 0
    time = time or g_effects.getFadeInTime()
  end
  -- 0 disables the animation: land on the final opacity in one step
  if not time or time <= 0 then
    removeEvent(widget.fadeEvent)
    widget.fadeEvent = nil
    widget:setOpacity(1)
    return
  end
  widget:setOpacity(math.min(elapsed/time, 1))
  removeEvent(widget.fadeEvent)
  if elapsed < time then
    widget.fadeEvent = scheduleEvent(function()
      g_effects.fadeIn(widget, time, elapsed + FADE_STEP_MS)
    end, FADE_STEP_MS)
  else
    widget.fadeEvent = nil
  end
end

function g_effects.fadeOut(widget, time, elapsed)
  if not widget then return end
  if not elapsed then
    elapsed = 0
    time = time or g_effects.getFadeOutTime()
  end
  if not time or time <= 0 then
    removeEvent(widget.fadeEvent)
    widget.fadeEvent = nil
    widget:setOpacity(0)
    return
  end
  elapsed = math.max((1 - widget:getOpacity()) * time, elapsed)
  removeEvent(widget.fadeEvent)
  widget:setOpacity(math.max((time - elapsed)/time, 0))
  if elapsed < time then
    widget.fadeEvent = scheduleEvent(function()
      g_effects.fadeOut(widget, time, elapsed + FADE_STEP_MS)
    end, FADE_STEP_MS)
  else
    widget.fadeEvent = nil
  end
end

-- clock driven, so a dispatcher hitch is caught up in one step instead of replayed step by step
function g_effects.fadeTo(widget, target, time)
  if not widget or widget:isDestroyed() then return end

  g_effects.cancelFade(widget)

  local from = widget:getOpacity()
  if not time or time <= 0 or math.abs(target - from) < FADE_MIN_DELTA then
    widget:setOpacity(target)
    return
  end

  local startTime = g_clock.millis()
  local function step()
    if widget:isDestroyed() then
      widget.fadeEvent = nil
      return
    end
    local progress = (g_clock.millis() - startTime) / time
    if progress >= 1 then
      widget.fadeEvent = nil
      widget:setOpacity(target)
      return
    end
    widget:setOpacity(from + (target - from) * progress)
    widget.fadeEvent = scheduleEvent(step, FADE_STEP_MS)
  end
  widget.fadeEvent = scheduleEvent(step, FADE_STEP_MS)
end

function g_effects.cancelFade(widget)
  removeEvent(widget.fadeEvent)
  widget.fadeEvent = nil
end

function g_effects.slideOut(widget, time, startX, endX, startY, endY, elapsed)
  if not elapsed then elapsed = 0 end
  if not time then time = 300 end
  elapsed = math.max((elapsed / time) * time, elapsed)
  removeEvent(widget.slideEvent)

  local progress = math.min(elapsed / time, 1)
  local newX = startX + (endX - startX) * progress
  local newY = startY + (endY - startY) * progress

  if startX ~= endX then
    widget:setMarginLeft(-newX)
  end

  if startY ~= endY then
    widget:setMarginTop(newY)
  end

  if elapsed < time then
    widget.slideEvent = scheduleEvent(function()
      g_effects.slideOut(widget, time, startX, endX, startY, endY, elapsed + 15)
    end, 15)
  else
    widget.slideEvent = nil
  end
end

function g_effects.slideOutBottom(widget, time, startX, endX, startY, endY, elapsed)
  if not elapsed then elapsed = 0 end
  if not time then time = 300 end
  elapsed = math.max((elapsed / time) * time, elapsed)
  removeEvent(widget.slideEvent)

  local progress = math.min(elapsed / time, 1)
  local newX = startX + (endX - startX) * progress
  local newY = startY + (endY - startY) * progress

  if startX ~= endX then
    widget:setMarginLeft(-newX)
  end

  if startY ~= endY then
    widget:setMarginBottom(newY)
  end

  if elapsed < time then
    widget.slideEvent = scheduleEvent(function()
      g_effects.slideOut(widget, time, startX, endX, startY, endY, elapsed + 15)
    end, 15)
  else
    widget.slideEvent = nil
  end
end

function g_effects.cancelSlide(widget)
  removeEvent(widget.slideEvent)
  widget.slideEvent = nil
end


function g_effects.startBlink(widget, duration, interval, clickCancel)
  duration = duration or 0 -- until stop is called
  interval = interval or 500
  clickCancel = clickCancel or true

  removeEvent(widget.blinkEvent)
  removeEvent(widget.blinkStopEvent)

  widget.blinkEvent = cycleEvent(function()
    widget:setOn(not widget:isOn())
  end, interval)

  if duration > 0 then
    widget.blinkStopEvent = scheduleEvent(function()
      g_effects.stopBlink(widget)
    end, duration)
  end

  connect(widget, { onClick = g_effects.stopBlink })
end

function g_effects.stopBlink(widget)
  disconnect(widget, { onClick = g_effects.stopBlink })
  removeEvent(widget.blinkEvent)
  removeEvent(widget.blinkStopEvent)
  widget.blinkEvent = nil
  widget.blinkStopEvent = nil
  widget:setOn(false)
end
