itemdropsWindow = nil

function init()
  -- Cria janela mas mantém oculta
  itemdropsWindow = g_ui.displayUI('itemdrops')
  itemdropsWindow:hide()
  
  connect(g_game, {
    onGameEnd = onGameEnd,
    onReceiveItemDrops = onReceiveItemDrops
  })
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onGameEnd,
    onReceiveItemDrops = onReceiveItemDrops
  })
  
  if itemdropsWindow then
    itemdropsWindow:destroy()
    itemdropsWindow = nil
  end
end

function onGameEnd()
  hide()
end

-- Handler de resposta do servidor (via callGlobalField do C++)
function onReceiveItemDrops(itemId, monsters)
  local data = {
    itemId = itemId,
    monsters = {}
  }

  for _, monsterData in ipairs(monsters) do
    table.insert(data.monsters, {
      name = monsterData[1],
      min = tonumber(monsterData[2]),
      max = tonumber(monsterData[3]),
      lookType = tonumber(monsterData[4])
    })
  end

  displayDrops(data)
end

-- Exibe janela com lista de monstros
function displayDrops(data)
  if not itemdropsWindow then
    return
  end

  itemdropsWindow.itemDisplay:setItemId(data.itemId)

  -- Limpa grid anterior
  local monsterGrid = itemdropsWindow:getChildById('monsterGrid')
  monsterGrid:destroyChildren()

  local noDropsLabel = itemdropsWindow:getChildById('noDropsLabel')
  local monstersCount = #data.monsters

  if monstersCount == 0 then
    noDropsLabel:show()
    monsterGrid:hide()
    itemdropsWindow:getChildById('monsterGridScrollBar'):hide()
    itemdropsWindow:setHeight(130)
  else
    noDropsLabel:hide()
    monsterGrid:show()

    -- Calculate responsive height based on number of rows (max 3)
    local columns = 5
    local rows = math.ceil(monstersCount / columns)
    local maxRows = 3
    local showScrollBar = rows > maxRows
    rows = math.min(rows, maxRows)

    -- topArea (88) + gridPadding (8) + rows * 84 - lastSpacing (4) + marginBottom (10)
    local windowHeight = 88 + 8 + (rows * 84) - 4 + 10
    itemdropsWindow:setHeight(windowHeight)

    if showScrollBar then
      itemdropsWindow:getChildById('monsterGridScrollBar'):show()
    else
      itemdropsWindow:getChildById('monsterGridScrollBar'):hide()
    end

    for _, monster in ipairs(data.monsters) do
      local cell = g_ui.createWidget('MonsterDropCell', monsterGrid)

      -- Set creature outfit
      local creatureDisplay = cell:getChildById('creatureDisplay')
      if monster.lookType and monster.lookType > 0 then
        creatureDisplay:setOutfit({type = monster.lookType})
      end

      -- Set tooltip with monster name
      cell:setTooltip(monster.name)

      -- Set drop amount text
      local dropAmount = cell:getChildById('dropAmount')
      dropAmount:setText(string.format("(%d - %d)", monster.min, monster.max))

      local pokemonName = monster.name
      cell:getChildById('dexButton').onClick = function()
        modules.game_pokedex.openFor(pokemonName)
      end
    end
  end

  -- Exibe janela
  itemdropsWindow:setOpacity(0)
  itemdropsWindow:show()
  itemdropsWindow:raise()
  itemdropsWindow:focus()
  g_effects.fadeIn(itemdropsWindow)
  g_uistates.push(itemdropsWindow)
end

function show()
  if itemdropsWindow then
    itemdropsWindow:setOpacity(0)
    itemdropsWindow:show()
    itemdropsWindow:raise()
    itemdropsWindow:focus()
    g_effects.fadeIn(itemdropsWindow)
    g_uistates.push(itemdropsWindow)
  end
end

function hide()
  if itemdropsWindow then
    g_uistates.remove(itemdropsWindow)
    g_effects.fadeOut(itemdropsWindow)
    scheduleEvent(function()
      if itemdropsWindow then
        itemdropsWindow:hide()
      end
    end, 200)
  end
end
