-- Mapa: barId -> { iconWidget, ... } indexado por iconKey ("type-subId").
-- Mantemos referência aos eventos de timeout para cancelar em updates/removes.
local activeIcons = {}

local function getIconKey(type, subId)
  return tostring(type) .. "-" .. tostring(subId or 0)
end

local function getBarForCreature(creatureId)
  local localPlayer = g_game.getLocalPlayer()
  if not localPlayer then
    return nil
  end

  if localPlayer:getId() == creatureId then
    if modules.game_playeractionbar and modules.game_playeractionbar.getPlayerConditionBar then
      return modules.game_playeractionbar.getPlayerConditionBar(), "player"
    end
    return nil
  end

  local creature = g_map.getCreatureById(creatureId)
  if creature and creature:getType() == CreatureTypeSummonOwn then
    if modules.game_pokemoves and modules.game_pokemoves.getPokemonConditionBar then
      return modules.game_pokemoves.getPokemonConditionBar(), "summon"
    end
  end

  return nil
end

local function ensureBucket(bar)
  if not bar then
    return nil
  end
  local key = bar:getId() or tostring(bar)
  if not activeIcons[key] then
    activeIcons[key] = {}
  end
  return activeIcons[key]
end

local function destroyIcon(bucket, iconKey)
  local entry = bucket[iconKey]
  if not entry then
    return
  end
  if entry.widget and not entry.widget:isDestroyed() then
    entry.widget:cancelCooldown()
    entry.widget:destroy()
  end
  bucket[iconKey] = nil
end

local function applyIconAppearance(widget, info, tooltip, itemId)
  local iconImage = widget:getChildById('iconImage')
  if iconImage then
    iconImage:setImageSource(CONDITION_PATH_PREFIX .. (info.path or 'condition_neutral'))
  end

  widget:setTooltip(tooltip or info.tooltip or "")

  local itemIcon = widget:getChildById('item')
  if itemIcon then
    if itemId and itemId > 0 then
      itemIcon:setItemId(itemId)
      itemIcon:show()
    else
      itemIcon:hide()
    end
  end
end

local CONDITION_TIME_PERMANENT = 0xFFFFFFFF

local function addOrUpdateIcon(bar, bucket, iconKey, type, subId, time, tooltip, itemId, info)
  -- time == 0 do servidor significa "expirado/sem tempo" -> destrói o widget se existir.
  if time == 0 and not info.isStatic then
    destroyIcon(bucket, iconKey)
    return
  end

  local isPermanent = info.isStatic or time == CONDITION_TIME_PERMANENT
  if isPermanent then
    time = nil
  elseif info.parseInSeconds and time then
    time = time * 1000
  end

  local entry = bucket[iconKey]

  -- Entry pode existir com widget já destruído (bar foi limpa externamente,
  -- por ex.: pokemoves esconde a movebar e chama destroyChildren).
  if entry and (not entry.widget or entry.widget:isDestroyed()) then
    bucket[iconKey] = nil
    entry = nil
  end

  if entry and info.keepLongestDuration and time then
    local remaining = entry.widget and entry.widget:getCooldownTimeLeft() or 0
    if time < remaining then
      return
    end
  end

  if not entry then
    local widget = g_ui.createWidget('ConditionSquare', bar)
    if not widget then
      return
    end
    entry = { widget = widget, type = type, subId = subId }
    bucket[iconKey] = entry
  end

  applyIconAppearance(entry.widget, info, tooltip, itemId)

  if isPermanent or not time or time <= 0 then
    entry.widget:cancelCooldown()
  else
    entry.widget:animateCooldown(time, function()
      destroyIcon(bucket, iconKey)
    end)
  end
end

local function handleAdd(creatureId, type, subId, time)
  local info = ConditionInfo[type]
  if not info or info.ignore then
    return
  end

  local bar = getBarForCreature(creatureId)
  if not bar then
    return
  end

  local bucket = ensureBucket(bar)
  if not bucket then
    return
  end

  addOrUpdateIcon(bar, bucket, getIconKey(type, subId), type, subId, time, nil, nil, info)
end

local function handleUpdate(creatureId, type, subId, time)
  local info = ConditionInfo[type]
  if not info or info.ignore then
    return
  end

  local bar = getBarForCreature(creatureId)
  if not bar then
    return
  end

  local bucket = ensureBucket(bar)
  if not bucket then
    return
  end

  addOrUpdateIcon(bar, bucket, getIconKey(type, subId), type, subId, time, nil, nil, info)
end

local function handleRemove(creatureId, type, subId)
  local info = ConditionInfo[type]
  if not info or info.ignore then
    return
  end

  local bar = getBarForCreature(creatureId)
  if not bar then
    return
  end

  local bucket = ensureBucket(bar)
  if not bucket then
    return
  end

  destroyIcon(bucket, getIconKey(type, subId))
end

local function onConditionIcon(action, creatureId, type, subId, time)
  if action == "add" then
    handleAdd(creatureId, type, subId, time)
  elseif action == "update" then
    handleUpdate(creatureId, type, subId, time)
  elseif action == "remove" then
    handleRemove(creatureId, type, subId)
  end
end

local function clearAll()
  for _, bucket in pairs(activeIcons) do
    for key, entry in pairs(bucket) do
      if entry.widget and not entry.widget:isDestroyed() then
        entry.widget:cancelCooldown()
        entry.widget:destroy()
      end
      bucket[key] = nil
    end
  end
  activeIcons = {}
end

function init()
  g_ui.importStyle('conditionicons')
  connect(g_game, {
    onConditionIcon = onConditionIcon,
    onGameEnd = clearAll,
  })
end

function terminate()
  disconnect(g_game, {
    onConditionIcon = onConditionIcon,
    onGameEnd = clearAll,
  })
  clearAll()
end
