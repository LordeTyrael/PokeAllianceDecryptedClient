local mainWindow = nil
local listWindow = nil
local taskWindow = nil
local loaded = false
local gameTaskTopButton

local function onGameStart()
  if not MainWindow then return end
  MainWindow:hide()
  listWindow:hide()
  taskWindow:hide()
end

local function onGameEnd()
  if not MainWindow then return end
  MainWindow:hide()
  loaded = false
end

local function connecting(gameEvent)
  -- TODO: Conectar apenas quando for usado
  if gameEvent then
    connect(g_game, {
      onOpenTasks = openTasks,
      onGameEnd = onGameEnd,
      onGameStart = onGameStart
    })
  end
  return true
end

local function disconnecting(gameEvent)
  if gameEvent then
    connect(g_game, {
      onGameEnd = onGameEnd,
      onGameStart = onGameStart
    })
  end
  return true
end

function init()
  connecting(true)
  local rootPanel = modules.game_interface.getRootPanel()
  mainWindow = g_ui.loadUI('tasks', rootPanel)
  gameTaskTopButton = modules.client_topmenu.addMiddleGameToggleButton('gameTaskTopButton', tr('Tasks') .. '', '/images/ui/topbuttons/icons/time', toggle)
  mainWindow:hide()
end

function terminate()
  disconnecting(true)
  if MainWindow then
    MainWindow:destroy()
    MainWindow = nil
  end
  if listWindow then
    listWindow:destroy()
    listWindow = nil
  end
  if taskWindow then
    taskWindow:destroy()
    taskWindow = nil
  end
  loaded = false
end

function toggle()
  if not loaded then
    return
  end
  if gameTaskTopButton:isOn() then
    mainWindow:hide()
    gameTaskTopButton:setOn(false)
  else
    mainWindow:show()
    mainWindow:focus()
    gameTaskTopButton:setOn(true)
  end
end

function show()
  mainWindow:show()
end

function hide()
  mainWindow:hide()
end

function close()
  if gameTaskTopButton:isOn() then
    gameTaskTopButton:setOn(false)
  end
  mainWindow:hide()
end

function openTasks(taskList)
  local npcTasks = {}
  for _, npcData in pairs(taskList) do
      local npcName = npcData.npcName
  
      if not npcTasks[npcName] then
          npcTasks[npcName] = {
              outfit = {
                  lookType = npcData.npcOutfit.lookType,
                  lookFeet = npcData.npcOutfit.lookFeet,
                  lookHead = npcData.npcOutfit.lookHead,
                  lookLegs = npcData.npcOutfit.lookLegs,
                  lookBody = npcData.npcOutfit.lookBody
              },
              tasks = {}
          }
      end
  
      for _, taskData in pairs(npcData.tasks) do
          table.insert(npcTasks[npcName].tasks, {
              countPokemon = taskData.countPokemon,
              pokemonOutfit = {
                  lookType = taskData.pokemonOutfit.lookType,
                  lookFeet = taskData.pokemonOutfit.lookFeet,
                  lookHead = taskData.pokemonOutfit.lookHead,
                  lookLegs = taskData.pokemonOutfit.lookLegs,
                  lookBody = taskData.pokemonOutfit.lookBody
              },
              pokemonName = taskData.pokemonName,
              npcName = npcName,
              taskCompleteIndicator = taskData.taskCompleteIndicator
          })
      end
  end

  local first = true
  local taskPanel = mainWindow:recursiveGetChildById('panelTasks')
  taskPanel:destroyChildren()
  for npcName, data in pairs(npcTasks) do
    local newOutfit = data.outfit
    local npcWidget = g_ui.createWidget('NpcPanel', taskPanel)
    if first then
      npcWidget:addAnchor(AnchorTop, 'parent', AnchorTop)
      first = false
    else
      npcWidget:addAnchor(AnchorTop, 'prev', AnchorBottom)
    end

    local outfitvar = {type = newOutfit.lookType, head = newOutfit.lookHead, body = newOutfit.lookBody, legs = newOutfit.lookLegs, feet = newOutfit.lookFeet}
    npcWidget:getChildById("outfit"):setOutfit(outfitvar)
    npcWidget:getChildById("npcName"):setText(npcName)
    local firstCreature = true
    for _, task in pairs(data.tasks) do
      local creatureWidget = g_ui.createWidget("CreaturePanel", npcWidget)
      if firstCreature then
        creatureWidget:addAnchor(AnchorLeft, 'outfit', AnchorRight)
        creatureWidget:setMarginLeft(50)
        firstCreature = false
      else
        creatureWidget:addAnchor(AnchorLeft, 'prev', AnchorRight)
      end
      local creatureNewOutfit = task.pokemonOutfit
      local creatureOutfitVar = {type = creatureNewOutfit.lookType, head = creatureNewOutfit.head, body = creatureNewOutfit.body, legs = creatureNewOutfit.legs, feet = creatureNewOutfit.feet}
      creatureWidget:getChildById("creatureOutfit"):setCenter(true)
      creatureWidget:getChildById("creatureOutfit"):setOutfit(creatureOutfitVar)
      if task.countPokemon == 0 then
        creatureWidget:getChildById("creatureCount"):setImageSource("images/done")
      else
        creatureWidget:getChildById("creatureCount"):setText(task.countPokemon)
      end
      
      creatureWidget:getChildById("creatureOutfit"):setFixedCreatureSize(true)
    end
  end
  loaded = true
end
