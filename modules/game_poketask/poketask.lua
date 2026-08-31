local lastUseSlot
local cancelConfirmWindow
local pokeTaskWindow

-- protocolo custom 1584 (parsePokeTask em C++); substituiu o extended 244
local protocolEvents = {
  onPokeTaskOpen = onPokeTaskOpen,
  onPokeTaskClose = onPokeTaskClose,
  onPokeTaskShard = onPokeTaskShard,
  onPokeTaskPokemon = onPokeTaskPokemon,
  onPokeTaskError = onPokeTaskError,
  onPokeTaskStartMission = onPokeTaskStartMission,
  onPokeTaskCancelMission = onPokeTaskCancelMission,
  onPokeTaskClaimMission = onPokeTaskClaimMission,
}

function init()
  connect(g_game, {
    onGameEnd = onLogout,
  })
  connect(g_game, protocolEvents)
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onLogout,
  })
  disconnect(g_game, protocolEvents)

  terminateProtocol()

  if pokeTaskWindow then
    pokeTaskWindow:destroy()
    pokeTaskWindow = nil
  end
end

function show()
  if pokeTaskWindow then
    pokeTaskWindow:destroy()
    pokeTaskWindow = nil
  end
  pokeTaskWindow = g_ui.displayUI('poketask')
end

function hide()
  if pokeTaskWindow then
    pokeTaskWindow:destroy()
    pokeTaskWindow = nil
  end
end

function onLogout()
  if cancelConfirmWindow then
    cancelConfirmWindow:destroy()
    cancelConfirmWindow = nil
  end
  hide()
end

function createTasks(count, shards)
  show()
  local taskPanel = pokeTaskWindow:getChildById('tasks')
  taskPanel:destroyChildren()

  for index = 1, count do
    local pokeTask = g_ui.createWidget('PokeTask', taskPanel)
    pokeTask:setId(index)

    local shard = pokeTask:getChildById('shard')
    local pokeball = pokeTask:getChildById('pokeball')

    local shardData = shards and shards[index]
    if shardData then
      onDungeonShard(shardData, shardData.index, shardData.shardCount, shardData.finalTimeout)
      
      -- Só inicia timer se a missão estiver ACTIVE (com startTime)
      if shardData.startTime then
        onStartMission(index, shardData.startTime)
      elseif shardData.status == 1 then
        -- Status READY: mostra botão START
        local pokeTask = taskPanel:getChildById(index)
        if pokeTask then
          local startWidget = pokeTask:getChildById('start')
          startWidget:setText(tr("START"))
          startWidget:setImageSource("images/missionheader")
          startWidget.onClick = function()
            sendStartMission(index)
          end
          startWidget:show()
        end
      end
    end

    shard.onDrop = onDropShard
    pokeball.onDrop = onDropPokeball
  end
end

function onDungeonShard(shard, index, count, finalTimeout)
  local taskPanel = pokeTaskWindow:getChildById('tasks')

  local pokeTask
  if index then
    pokeTask = taskPanel:getChildById(index)
  else
    pokeTask = lastUseSlot:getParent()
  end

  local itemId = shard.itemId
  if itemId then
    local shardWidget = pokeTask:getChildById('shard')
    shardWidget:setItemId(itemId)
    if count then
      shardWidget:setItemCount(count)
    end
  end
  pokeTask.rightInstructionLabel:hide()

  local pokeball = shard.pokeball
  local pokeballWidget = pokeTask:getChildById('pokeball')
  pokeballWidget:show()
  if pokeball then
    pokeTask.leftInstructionLabel:hide()
    pokeballWidget:setItemId(pokeball.itemId)
    pokeballWidget:setPokeballName(pokeball.pokeballName)
    pokeballWidget:setTooltip(humanCase(pokeball.pokemonName))
  else
    pokeTask.leftInstructionLabel:show()
  end

  local chest = pokeTask:getChildById('chest')

  local rewardsTooltip = g_ui.createWidget('RewardsTooltip', rootWidget)
  local rewardsPanel = rewardsTooltip:getChildById('rewards')
  local rewards = shard.rewards

  for _, reward in ipairs(rewards) do
    local itemWidget = g_ui.createWidget('ItemSlot', rewardsPanel)
    itemWidget:setItemId(reward.itemId)
    itemWidget:setItemCount(reward.count)
  end

  -- Ajustar altura do painel de rewards baseado na quantidade de itens
  local rewardCount = #rewards
  if rewardCount > 4 then
    -- Calcular quantas linhas são necessárias (4 itens por linha)
    local itemsPerRow = 4
    local rows = math.ceil(rewardCount / itemsPerRow)
    
    -- Cada item tem 32px de altura + 4px de espaçamento entre linhas
    local itemHeight = 36
    local spacing = 2
    local newPanelHeight = (itemHeight * rows) + (spacing * (rows - 1))
    
    rewardsPanel:setHeight(newPanelHeight)
  end

  chest:setTooltip(rewardsTooltip)
  chest:show()

  local banner = shard.banner
  local bannerWidget = pokeTask:getChildById('banner')
  bannerWidget:setImageSource('images/banners/' .. banner)
  bannerWidget:setOn(true)

  shard.timeout = finalTimeout
  local timerWidget = pokeTask:getChildById('timer')
  if not shard.startTime then
    timerWidget:setText(g_game.getFormatTimeFromMs(finalTimeout))
  end
  timerWidget:show()

  pokeTask.config = shard
end

function onDungeonPokemon(pokeballParams)
  local pokeTask = lastUseSlot:getParent()

  local startButton = pokeTask:getChildById('start')
  startButton:setText(tr("START"))
  startButton:setImageSource("images/missionheader")
  startButton.onClick = function()
    sendStartMission(tonumber(pokeTask:getId()))
  end

  local pokeball = pokeTask:getChildById('pokeball')
  pokeball:setItemId(pokeballParams.itemId)
  pokeball:setPokeballName(pokeballParams.pokeballName)
  pokeball:setTooltip(humanCase(pokeballParams.pokemonName))
  
  local timeout = pokeballParams.finalTimeout
  local timerWidget = pokeTask:getChildById('timer')
  timerWidget:setText(g_game.getFormatTimeFromMs(timeout))
  pokeTask.config.timeout = timeout

  startButton:show()
  pokeTask.leftInstructionLabel:hide()
end

function onStartMission(index, startTime)
  local taskPanel = pokeTaskWindow:getChildById('tasks')
  local pokeTask = taskPanel:getChildById(index)

  if not pokeTask then
    return
  end

  pokeTask.rightInstructionLabel:hide()
  pokeTask.leftInstructionLabel:hide()
  local timerWidget = pokeTask:getChildById('timer')

  local timerEvent = pokeTask.timerEvent
  if timerEvent then
    removeEvent(pokeTask.timerEvent)
  end

  local startWidget = pokeTask:getChildById('start')

  local shardConfig = pokeTask.config
  if not shardConfig or not shardConfig.timeout then
    return
  end
  
  -- Servidor já envia o tempo restante calculado
  local timeRemaining = shardConfig.timeout
  
  -- Se já passou do timeout, mostrar botão CLAIM
  if timeRemaining <= 0 then
    timerWidget:hide()
    startWidget:setText(tr("CLAIM"))
    startWidget:setImageSource("images/missionheader")
    startWidget.onClick = function()
      sendClaimMission(index)
    end
    startWidget:show()
    return
  end

  --local shardWidget = pokeTask:getChildById('shard')
  --shardWidget:setImageShader('grayscale')
--
  --local pokeballWidget = pokeTask:getChildById('pokeball')
  --pokeballWidget:setImageShader('grayscale')

  startWidget:setText(tr("CANCEL"))
  startWidget:setImageSource("images/mission_headerc")
  startWidget.onClick = function()
    if cancelConfirmWindow then
      return
    end
    
    cancelConfirmWindow = displayAllianceBox(tr("Cancel Mission"), tr("Are you sure you want to cancel this mission?\nAll shards will be returned and you will lose all progress."), {
      { text = tr("Yes"), callback = function()
        sendCancelMission(index)
        cancelConfirmWindow:destroy()
        cancelConfirmWindow = nil
      end },
      { text = tr("No"), callback = function()
        cancelConfirmWindow:destroy()
        cancelConfirmWindow = nil
      end },
      anchor = AnchorHorizontalCenter
    })
  end
  startWidget:show()

  -- Guardar tempo inicial (local) e tempo restante calculado
  local remainingTimeout = timeRemaining
  local startTimeMs = g_clock.millis()
  
  timerEvent = cycleEvent(function()
    if not timerWidget:isVisible() then
      removeEvent(pokeTask.timerEvent)
      pokeTask.timerEvent = nil
      return
    end

    -- Calcular tempo decorrido desde o início (no relógio local)
    local elapsedMs = g_clock.millis() - startTimeMs
    local timeout = math.max(remainingTimeout - elapsedMs, 0)

    timerWidget:setText(g_game.getFormatTimeFromMs(timeout))

    shardConfig.timeout = timeout

    if timeout == 0 then
      removeEvent(pokeTask.timerEvent)
      pokeTask.timerEvent = nil
      timerWidget:hide()
      startWidget:setText(tr("CLAIM"))
      startWidget:setImageSource("images/missionheader")
      startWidget.onClick = function()
        sendClaimMission(index)
      end
      return
    end
  end, 1000)

  pokeTask.timerEvent = timerEvent
end

function onCancelMission(index)
  clearMission(index)
end

function onClaimMission(index)
  -- visual effects?
  clearMission(index)
end

function clearMission(index)
  local taskPanel = pokeTaskWindow:getChildById('tasks')
  local pokeTask = taskPanel:getChildById(index)

  if not pokeTask then
    return
  end

  local timerEvent = pokeTask.timerEvent
  if timerEvent then
    removeEvent(timerEvent)
    pokeTask.timerEvent = nil
  end

  local shardWidget = pokeTask:getChildById('shard')
  shardWidget:setItem(nil)
  pokeTask.rightInstructionLabel:show()

  local pokeballWidget = pokeTask:getChildById('pokeball')
  pokeballWidget:setItem(nil)
  pokeballWidget:hide()

  local bannerWidget = pokeTask:getChildById('banner')
  bannerWidget:setImageSource()
  bannerWidget:setOn(false)

  pokeTask:getChildById('chest'):hide()
  pokeTask:getChildById('start'):hide()
  pokeTask:getChildById('timer'):hide()

  pokeTask.config = nil
end

function onDropShard(itemWidget, widget, mousePos, forced)
  local item = widget.currentDragThing
  if not item or not item:isItem() then
    return false
  end

  local pokeTask = itemWidget:getParent()
  local shardConfig = pokeTask.config
  if shardConfig and shardConfig.startTime then
    return
  end

  local index = tonumber(pokeTask:getId())
  local itemCount = item:getCount()
  
  if itemCount > 1 then
    -- Mostrar dialog de seleção de quantidade
    local countWindow = g_ui.createWidget('CountWindow', rootWidget)
    local itemWidget2 = countWindow:getChildById('item')
    local spinbox = countWindow.countSpinner.field
    local okButton = countWindow:getChildById('buttonOk')
    local cancelButton = countWindow:getChildById('buttonCancel')

    itemWidget2:setItemId(item:getId())
    itemWidget2:setItemCount(itemCount)

    spinbox:setMinimum(1)
    spinbox:setMaximum(itemCount)
    spinbox:setValue(itemCount)

    spinbox:focus()

    spinbox.onValueChange = function(self, value)
      itemWidget2:setItemCount(value)
    end
    itemWidget2:setItemCount(spinbox:getValue())

    okButton.onClick = function()
      local count = spinbox:getValue()
      local pokeball = pokeTask:getChildById('pokeball')
      pokeball:setItem(nil)
      pokeball:setTooltip(tr("Put your pokemon here"))
      
      pokeTask:getChildById('start'):hide()
      
      itemWidget:setItemId(item:getId())
      itemWidget:setItemCount(count)
      lastUseSlot = itemWidget
      sendDungeonShard(item, index, count)
      
      countWindow:destroy()
      modules.game_interface.getMapPanel():focus()
    end
    
    local cancelFunc = function()
      countWindow:destroy()
      modules.game_interface.getMapPanel():focus()
    end
    cancelButton.onClick = cancelFunc
    countWindow:getChildById('closeBtn').onClick = cancelFunc
    countWindow:setupModal(cancelFunc)
  else
    -- Apenas 1 item, enviar diretamente
    local pokeball = pokeTask:getChildById('pokeball')
    pokeball:setItem(nil)
    pokeball:setTooltip(tr("Put your pokemon here"))
    
    pokeTask:getChildById('start'):hide()
    
    itemWidget:setItemId(item:getId())
    lastUseSlot = itemWidget
    sendDungeonShard(item, index, 1)
  end

  widget.currentDragThing = nil
  return true
end

function onDropPokeball(itemWidget, widget, mousePos, forced)
  local item = widget.currentDragThing
  if not item or not item:isItem() then
    return false
  end

  local pokeTask = itemWidget:getParent()
  local shardConfig = pokeTask.config
  if shardConfig.startTime then
    return
  end

  local index = tonumber(pokeTask:getId())

  lastUseSlot = itemWidget
  sendDungeonPokemon(item, index)

  return true
end

function onShardItemError()
  if not lastUseSlot then
    return
  end

  lastUseSlot:setItem(nil)
  lastUseSlot:setTooltip(tr("Put any shard here"))

  local pokeTask = lastUseSlot:getParent()
  local config = pokeTask.config

  local bannerWidget = pokeTask:getChildById('banner')
  bannerWidget:setImageSource()
  bannerWidget:setOn(false)

  local pokeball = pokeTask:getChildById('pokeball')
  pokeball:setItem(nil)
  pokeball:hide()

  pokeTask:getChildById('chest'):hide()
  pokeTask:getChildById('start'):hide()
  pokeTask:getChildById('timer'):hide()

  lastUseSlot = nil
end

function onPokemonItemError()
  if not lastUseSlot then
    return
  end

  local pokeTask = lastUseSlot:getParent()

  local startButton = pokeTask:getChildById('start')
  startButton:hide()

  lastUseSlot:setItem(nil)
  lastUseSlot = nil
end
