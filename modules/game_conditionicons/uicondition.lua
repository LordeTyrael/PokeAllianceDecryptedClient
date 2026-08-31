-- Widget reutilizável para conditions (poison, paralyze, buffs, etc.)
-- Encapsula a animação de cooldown via applyTransition no progressRect filho.
-- Atribuímos no _G para que o OTUI consiga resolver `ConditionSquare < UICondition`
-- (o módulo é sandboxed, então classes locais não ficam visíveis ao C++ ui manager).

_G.UICondition = extends(UIWidget, "UICondition")
local UICondition = _G.UICondition

local function formatTimeMillis(ms)
  if not ms or ms <= 0 then
    return ""
  end
  if ms >= 86400000 then -- >= 1 dia
    return string.format("%dd", math.floor(ms / 86400000))
  end
  if ms >= 3600000 then  -- >= 1 hora
    return string.format("%dh", math.floor(ms / 3600000))
  end
  if ms >= 60000 then    -- >= 1 minuto
    return string.format("%dm", math.floor(ms / 60000))
  end
  -- Abaixo de 1 minuto: 1 casa decimal (1.5, 1.4, 1.3...)
  return string.format("%.1f", math.floor(ms / 100) / 10)
end

function UICondition.create()
  local widget = UICondition.internalCreate()
  widget:setFocusable(false)
  return widget
end

local function cacheChildren(self)
  if not self._progressRect then
    self._progressRect = self:getChildById('progressRect')
  end
  if not self._timeLabel then
    self._timeLabel = self:getChildById('timeLabel')
  end
end

-- Cancela tick e limpa visual.
function UICondition:cancelCooldown()
  if self.cooldownEvent then
    removeEvent(self.cooldownEvent)
    self.cooldownEvent = nil
  end

  cacheChildren(self)
  if self._progressRect and not self._progressRect:isDestroyed() then
    self._progressRect:setPercent(100)
  end
  if self._timeLabel and not self._timeLabel:isDestroyed() then self._timeLabel:setText("") end
  self.cooldownEnd = nil
end

-- Tick a cada 100ms:
--  * Atualiza visual (progressRect.percent + label).
--  * Quando remaining <= 0 chama `finishedCallback(self)` (que destrói o widget).
function UICondition:animateCooldown(durationMs, finishedCallback)
  if not durationMs or durationMs <= 0 then
    self:cancelCooldown()
    if finishedCallback then
      finishedCallback(self)
    end
    return
  end

  if self.cooldownEvent then
    removeEvent(self.cooldownEvent)
    self.cooldownEvent = nil
  end

  local startTime = g_clock.millis()
  self.cooldownEnd = startTime + durationMs

  cacheChildren(self)
  local progressRect = self._progressRect
  local label = self._timeLabel
  if progressRect and not progressRect:isDestroyed() then
    progressRect:setPercent(100)
  end
  if label and not label:isDestroyed() then label:setText(formatTimeMillis(durationMs)) end

  local function tick()
    if not self or self:isDestroyed() then
      return
    end

    local now = g_clock.millis()
    local remaining = (self.cooldownEnd or now) - now

    if remaining <= 0 then
      self.cooldownEvent = nil
      self.cooldownEnd = nil
      if finishedCallback then
        finishedCallback(self)
      end
      return
    end

    if progressRect and not progressRect:isDestroyed() then
      progressRect:setPercent(math.floor((remaining / durationMs) * 100))
    end
    if label and not label:isDestroyed() then label:setText(formatTimeMillis(remaining)) end

    self.cooldownEvent = scheduleEvent(tick, 100)
  end

  self.cooldownEvent = scheduleEvent(tick, 100)
end

function UICondition:getCooldownTimeLeft()
  if not self.cooldownEnd then
    return 0
  end
  return math.max(0, self.cooldownEnd - g_clock.millis())
end
