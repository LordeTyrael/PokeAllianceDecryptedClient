-- chunkname: @/modules/game_walking/walking.lua

smartWalkDirs = {}
smartWalkDir = nil
nextWalkDir = nil
lastWalkDir = nil
lastFinishedStep = 0
autoWalkEvent = nil
firstStep = true
walkLock = 0
walkEvent = nil
lastWalk = 0
lastTurn = 0
lastTurnDirection = 0
lastStop = 0
lastManualWalk = 0
autoFinishNextServerWalk = 0

local disableWalk = false

local walkBindings = {
  ['WALK_NORTH'] = North,
  ['WALK_NORTH_EAST'] = NorthEast,
  ['WALK_EAST'] = East,
  ['WALK_SOUTH_EAST'] = SouthEast,
  ['WALK_SOUTH'] = South,
  ['WALK_SOUTH_WEST'] = SouthWest,
  ['WALK_WEST'] = West,
  ['WALK_NORTH_WEST'] = NorthWest,
}

local turnBindings = {
  ['TURN_NORTH'] = North,
  ['TURN_EAST'] = East,
  ['TURN_SOUTH'] = South,
  ['TURN_WEST'] = West,
}

local pokemonTurnBindings = {
  ['TURN_POKEMON_NORTH'] = North,
  ['TURN_POKEMON_EAST'] = East,
  ['TURN_POKEMON_SOUTH'] = South,
  ['TURN_POKEMON_WEST'] = West,
}

local dirToTurn = {
  [North] = "#s t1",
  [East] = "#s t2",
  [South] = "#s t3",
  [West] = "#s t4"
}

local boundKeys = {
  chatEnabled = {},
  chatDisabled = {}
}

local function movementFactory(actionName, action, keyInfo, chatState, keyType)
  local gameRootPanel = modules.game_interface.getRootPanel()

  local dir = walkBindings[actionName]
  if dir then
    local callbackDown = function()
      if isChatStateCorrect(chatState == "chatEnabled") then
        changeWalkDir(dir)
      end
    end
    local callbackUp = function()
      changeWalkDir(dir, true)
    end
    local callbackPress = function(c, k, ticks)
      if isChatStateCorrect(chatState == "chatEnabled") then
        smartWalk(dir, ticks)
      end
    end
    return {
      callbackDown = callbackDown,
      callbackUp = callbackUp,
      callbackPress = callbackPress,
      widget = gameRootPanel,
      passthrough = true
    }
  end

  dir = turnBindings[actionName]
  if dir then
    local callbackDown = function()
      if isChatStateCorrect(chatState == "chatEnabled") then
        turn(dir, false)
      end
    end
    local callbackUp = function()
      if isChatStateCorrect(chatState == "chatEnabled") then
        local player = g_game.getLocalPlayer()
        if player then
          player:lockWalk(200)
        end
      end
    end
    local callbackPress = function()
      if isChatStateCorrect(chatState == "chatEnabled") then
        turn(dir, true)
      end
    end
    return {
      callbackDown = callbackDown,
      callbackUp = callbackUp,
      callbackPress = callbackPress,
      widget = gameRootPanel
    }
  end

  dir = pokemonTurnBindings[actionName]
  if dir then
    local callbackDown = function()
      if isChatStateCorrect(chatState == "chatEnabled") then
        local message = dirToTurn[dir]
        if message then
          modules.game_chat.sendMessage(message)
        end
      end
    end
    return {
      callbackDown = callbackDown,
      widget = gameRootPanel
    }
  end

  return nil
end

for _, bindingTable in ipairs({ walkBindings, turnBindings, pokemonTurnBindings }) do
  for actionName in pairs(bindingTable) do
    modules.client_hotkeys.registerHotkeyCallback(actionName, movementFactory, nil, "triple")
  end
end

function init()
  connect(g_game, { onTeleport = onTeleport })

  connect(LocalPlayer, {
    onPositionChange = onPositionChange,
    onWalk = onWalk,
    onWalkFinish = onWalkFinish,
    onCancelWalk = onCancelWalk
  })

  connect(g_uistates, { onGrabChanged = stopSmartWalk })

  modules.game_interface.getRootPanel().onFocusChange = stopSmartWalk
end

function terminate()
  removeEvent(autoWalkEvent)
  stopSmartWalk()
end

function isChatStateCorrect(chatEnabled)
  local chatModeEnabled = not modules.game_chat.consoleToggleChat
  return (chatEnabled and chatModeEnabled) or (not chatEnabled and not chatModeEnabled)
end

function enableWSAD()
end

function disableWSAD()
end

function enableClientWalk()
  disableWalk = false
end

function disableClientWalk()
  disableWalk = true
end

function stopSmartWalk()
  smartWalkDirs = {}
  smartWalkDir = nil
  nextWalkDir = nil
  removeEvent(autoWalkEvent)
  autoWalkEvent = nil
  -- NÃO cancelar o walkEvent aqui. Chegou a ser adicionado para matar o "1 passo a mais" do
  -- pokeview, mas o stopSmartWalk vale para TODO jogador: fora do pokeview o disparo pendente não
  -- é lixo — ele passa pelo canWalk() e, quando o passo tinha acabado de terminar, vira passo
  -- legítimo. Cancelando, o personagem parava um passo antes do esperado.
  --
  -- E é desnecessário: com o gate do walk() reapontado para o sujeito certo (walkSubject), o
  -- disparo pendente já é recusado sozinho enquanto o passo está em curso.
end

function changeWalkDir(dir, pop)
  while table.removevalue(smartWalkDirs, dir) do end
  if pop then
    if #smartWalkDirs == 0 then
      stopSmartWalk()
      return
    end
  else
    table.insert(smartWalkDirs, 1, dir)
  end

  smartWalkDir = smartWalkDirs[1]

  if modules.client_options.getOption('smartWalk') and #smartWalkDirs > 1 then
    for _,d in pairs(smartWalkDirs) do
      if (smartWalkDir == North and d == West) or (smartWalkDir == West and d == North) then
        smartWalkDir = NorthWest
        break
      elseif (smartWalkDir == North and d == East) or (smartWalkDir == East and d == North) then
        smartWalkDir = NorthEast
        break
      elseif (smartWalkDir == South and d == West) or (smartWalkDir == West and d == South) then
        smartWalkDir = SouthWest
        break
      elseif (smartWalkDir == South and d == East) or (smartWalkDir == East and d == South) then
        smartWalkDir = SouthEast
        break
      end
    end
  end
end

function smartWalk(dir, ticks)
  if disableWalk then
    return
  end
  walkEvent = scheduleEvent(function()
    if g_keyboard.getModifiers() == KeyboardNoModifier then
      local direction = smartWalkDir or dir
      walk(direction, ticks)
      return true
    end
    return false
  end, 20)
end

function canChangeFloorDown(pos)
  pos.z = pos.z + 1
  toTile = g_map.getTile(pos)
  return toTile and toTile:hasElevation(3)
end

function canChangeFloorUp(pos)
  pos.z = pos.z - 1
  toTile = g_map.getTile(pos)
  return toTile and toTile:isWalkable()
end

function onPositionChange(player, newPos, oldPos)
  return
end

function onWalk(player, newPos, oldPos)
  if autoFinishNextServerWalk + 200 > g_clock.millis() then
    player:finishServerWalking()
  end
end

function onTeleport(player, newPos, oldPos)
  if not newPos or not oldPos then
    return
  end
  -- floor change is also teleport
  if math.abs(newPos.x - oldPos.x) >= 3 or math.abs(newPos.y - oldPos.y) >= 3 or math.abs(newPos.z - oldPos.z) >= 2 then
    -- far teleport, lock walk for 100ms
    walkLock = g_clock.millis() + g_settings.getNumber('walkTeleportDelay')
  else
    walkLock = g_clock.millis() + g_settings.getNumber('walkStairsDelay')
  end
  nextWalkDir = nil -- cancel autowalk
end

function onWalkFinish(player)
  local player = g_game.getLocalPlayer()
  lastFinishedStep = g_clock.millis()
  if nextWalkDir ~= nil then
    removeEvent(autoWalkEvent)
    autoWalkEvent = addEvent(function() if nextWalkDir ~= nil then walk(nextWalkDir, 0) end end, false)
  end
end

function onCancelWalk(player)
  player:lockWalk(50)
end

function walk(dir, ticks)
  lastManualWalk = g_clock.millis()
  local player = g_game.getLocalPlayer()
  if not player or g_game.isDead() or player:isDead() then
    return
  end

  if player:isServerAutoWalking() then
    player:setDirection(dir)
  end

  if player:isPreWalking() then
    return
  end

  if player:isWalkLocked() then
    nextWalkDir = nil
    return
  end

  if g_game.isFollowing() then
    g_game.cancelFollow()
  end

  if player:isAutoWalking() and lastStop + 100 < g_clock.millis() then
    lastStop = g_clock.millis()

    player:stopAutoWalk()
    g_game.stop()
  end

  local dash = false
  local ignoredCanWalk = false
  local pokeviewTarget = player:getPokeviewCreature()

  -- Em pokeview quem anda é o POKÉMON; o corpo do treinador fica congelado, às vezes em outro
  -- andar. Todo o gate abaixo falava do corpo do jogador (canWalk / getStepTicksLeft /
  -- getPrewalkingPosition), então a solução antiga era DESLIGAR o gate quando havia pokeview.
  -- Agora ele é REAPONTADO para a criatura. Fora do pokeview walkSubject é o próprio jogador e
  -- nada muda.
  local walkSubject = pokeviewTarget or player
  local ticksToNextWalk = walkSubject:getStepTicksLeft()

  local subjectCanWalk
  if pokeviewTarget then
    -- Equivalente do LocalPlayer::canWalk para uma criatura: parado (speed 0) não anda, o passo
    -- seguinte só sai quando o atual terminou, e não se empilha predição em cima de predição.
    -- getSpeed/isWalking/getStepTicksLeft/isPreWalking são bindados em Creature.
    subjectCanWalk = pokeviewTarget:getSpeed() > 0
                     and not (pokeviewTarget:isWalking() and ticksToNextWalk > 0)
                     and not pokeviewTarget:isPreWalking()
  else
    subjectCanWalk = player:canWalk(dir)
  end

  -- PREDIZER e diferente de ENVIAR. O cliente nao consegue replicar as excecoes do servidor --
  -- Monster::canIgnoreDuelCondition depende de estado de duelo que nao vai no fio, e
  -- canIgnoreBlockCreatures (pokemon com ghost atravessa criatura) nao existe aqui. Recusar
  -- localmente engoliria passo valido; nao predizer so custa suavidade.
  local shouldPredict = true
  if pokeviewTarget and pokeviewTarget:isWalkBlockedByCondition() then
    shouldPredict = false
  end

  if not subjectCanWalk then
      if ticksToNextWalk < 500 and (lastWalkDir ~= dir or ticks == 0) then
        nextWalkDir = dir
      end
      if ticksToNextWalk < 30 and lastFinishedStep + 400 > g_clock.millis() and nextWalkDir == nil then -- clicked walk 20 ms too early, try to execute again as soon possible to keep smooth walking
        nextWalkDir = dir
      end
      return
  end

  if nextWalkDir ~= nil and nextWalkDir ~= lastWalkDir then
    dir = nextWalkDir
  end

  -- Base do destino: a posicao de quem ANDA. Antes era sempre o corpo do treinador, entao em
  -- pokeview o toTile calculado era o vizinho do TREINADOR -- um tile sem relacao com o Pokemon.
  -- Era por isso que a checagem de andavel abaixo precisava de um `or player:onPokeview()`.
  local toPos = walkSubject:getPrewalkingPosition(true)
  if dir == North then
    toPos.y = toPos.y - 1
  elseif dir == East then
    toPos.x = toPos.x + 1
  elseif dir == South then
    toPos.y = toPos.y + 1
  elseif dir == West then
    toPos.x = toPos.x - 1
  elseif dir == NorthEast then
    toPos.x = toPos.x + 1
    toPos.y = toPos.y - 1
  elseif dir == SouthEast then
    toPos.x = toPos.x + 1
    toPos.y = toPos.y + 1
  elseif dir == SouthWest then
    toPos.x = toPos.x - 1
    toPos.y = toPos.y + 1
  elseif dir == NorthWest then
    toPos.x = toPos.x - 1
    toPos.y = toPos.y - 1
  end
  local toTile = g_map.getTile(toPos)

  if walkLock >= g_clock.millis() and lastWalkDir == dir then
    nextWalkDir = nil
    return
  end

  if firstStep and lastWalkDir == dir and lastWalk + g_settings.getNumber('walkFirstStepDelay') > g_clock.millis() then
    firstStep = false
    walkLock = lastWalk + g_settings.getNumber('walkFirstStepDelay')
    return
  end

  if lastWalkDir == dir and lastWalk + 50 > g_clock.millis() then
    return
  end

  firstStep = (not walkSubject:isWalking() and lastFinishedStep + 100 < g_clock.millis() and walkLock + 100 < g_clock.millis())
  if player:isServerWalking() and not dash then
    walkLock = walkLock + math.max(g_settings.getNumber('walkFirstStepDelay'), 100)
  end

  nextWalkDir = nil
  removeEvent(autoWalkEvent)
  autoWalkEvent = nil
  local preWalked = false
  -- O `or player:onPokeview()` saiu: o toTile agora e o vizinho do PROPRIO Pokemon, entao a
  -- checagem de andavel vale de verdade (era ela que deixava mandar passo contra parede).
  -- Em pokeview o corpo congelado do treinador ocupa tile de verdade: quem anda e o Pokemon e o
  -- servidor recusa com NOTENOUGHROOM. isWalkable() isenta o local player, entao ali era preciso
  -- a variante que nao isenta -- sem ela o cliente predizia o Pokemon em cima do proprio corpo.
  local destinationWalkable = false
  if toTile then
    if pokeviewTarget then
      destinationWalkable = toTile:isWalkableForCreature()
    else
      destinationWalkable = toTile:isWalkable()
    end
  end

  if destinationWalkable then
    if not player:isServerWalking() and not ignoredCanWalk and shouldPredict then
      -- preWalk agora existe em Creature: em pokeview a predicao e feita NA CRIATURA. O
      -- servidor avisa o dono por 0xB5 quando recusa o passo, e o cancelWalk do LocalPlayer
      -- desfaz a predicao do Pokemon.
      walkSubject:preWalk(dir)
      preWalked = true
    end
  else
    -- Tile de quem anda: a logica de escada/elevacao tem que olhar o andar do Pokemon.
    local playerTile = walkSubject:getTile()
    if (playerTile and playerTile:hasElevation(3) and canChangeFloorUp(toPos)) or canChangeFloorDown(toPos) or (toTile and toTile:isEmpty() and not toTile:isBlocking()) then
      player:lockWalk(100)
    elseif player:isServerWalking() then
      g_game.stop()
      return
    elseif not toTile then
      player:lockWalk(100) -- bug fix for missing stairs down on map
    else
      if g_app.isMobile() and dir <= Directions.West then
        turn(dir, ticks > 0)
      end
      return -- not walkable tile
    end
  end

  if player:isServerWalking() and not dash then
    g_game.stop()
    player:finishServerWalking()
    autoFinishNextServerWalk = g_clock.millis() + 200
  end
  g_game.walk(dir, preWalked)

  if not firstStep and lastWalkDir ~= dir then
    walkLock = g_clock.millis() + g_settings.getNumber('walkTurnDelay')
  end

  lastWalkDir = dir
  lastWalk = g_clock.millis()
  return true
end

function turn(dir, repeated)
  local player = g_game.getLocalPlayer()
  if player:isWalking() and player:getWalkDirection() == dir and not player:isServerWalking() then
    return
  end

  if player:isTurnBlocked() then
    return
  end

  removeEvent(walkEvent)

  if not repeated or (lastTurn + 100 < g_clock.millis()) then
    g_game.turn(dir, modules.client_options.getOption('turnPokemon'))
    lastTurn = g_clock.millis()
    if not repeated then
      lastTurn = g_clock.millis() + 50
    end
    lastTurnDirection = dir
    nextWalkDir = nil
    player:lockWalk(g_settings.getNumber('walkCtrlTurnDelay'))
  end
end