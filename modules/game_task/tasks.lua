local MainWindow = nil
local loaded = false
local gameTaskTopButton
local playerTaskList = nil

local function onGameStart()
  local rootPanel = modules.game_interface.getRootPanel()
  MainWindow = g_ui.loadUI('tasks', rootPanel)
  gameTaskTopButton = modules.client_topmenu.addMiddleGameToggleButton('gameTaskTopButton', tr('Tasks') .. '', '/images/ui/topbuttons/icons/task', toggle)
  MainWindow:hide()
end

local function onGameEnd()
  if gameTaskTopButton then
    gameTaskTopButton:destroy()
    gameTaskTopButton = nil
  end
  if not MainWindow then return end
  MainWindow:destroy()
  loaded = false
  MainWindow = nil
end

local function connecting(gameEvent)
  -- TODO: Conectar apenas quando for usado
  if gameEvent then
    connect(g_game, {
      onOpenTasks = openTasks,
      onOpenTask = updateTask,
      onGameEnd = onGameEnd,
      onGameStart = onGameStart,
      onTileMapDescription = onTileMapDescription
    })
  end
  return true
end

local function disconnecting(gameEvent)
  if gameEvent then
    disconnect(g_game, {
      onOpenTasks = openTasks,
      onOpenTask = updateTask,
      onGameEnd = onGameEnd,
      onGameStart = onGameStart,
      onTileMapDescription = onTileMapDescription
    })
  end
  return true
end

function init()
  connecting(true)
  -- the module is loaded by game_interface, which can happen with a game already running; without
  -- this the window is never built and every server push lands on a nil MainWindow
  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  disconnecting(true)
  onGameEnd()
end

function toggle()
  if not loaded then
    return
  end
  if gameTaskTopButton:isOn() then
    MainWindow:hide()
    gameTaskTopButton:setOn(false)
  else
    MainWindow:show()
    MainWindow:focus()
    gameTaskTopButton:setOn(true)
  end
end

function show()
  MainWindow:show()
end

function hide()
  MainWindow:hide()
end

function close()
  if gameTaskTopButton:isOn() then
    gameTaskTopButton:setOn(false)
  end
  MainWindow:hide()
end

function openTasks(taskList)
    if not MainWindow then return end
    playerTaskList = {}
    for _, npcData in pairs(taskList) do
        local npcName = npcData.npcName
  
        if not playerTaskList[npcName] then
            playerTaskList[npcName] = {
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
            table.insert(playerTaskList[npcName].tasks, {
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
    local taskPanel = MainWindow:recursiveGetChildById('panelTasks')
    taskPanel:destroyChildren()
    for npcName, data in pairs(playerTaskList) do
        local newOutfit = data.outfit
        local npcWidget = g_ui.createWidget('NpcPanel', taskPanel)
        npcWidget.targetIcon.onClick = function()
            g_game.sendRequestTaskLocalization(npcName)
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
            creatureWidget:setId(task.pokemonName)
            local creatureNewOutfit = task.pokemonOutfit
            local creatureOutfitVar = {type = creatureNewOutfit.lookType, head = creatureNewOutfit.head, body = creatureNewOutfit.body, legs = creatureNewOutfit.legs, feet = creatureNewOutfit.feet}
            creatureWidget:getChildById("creatureOutfit"):setCenter(true)
            creatureWidget:getChildById("creatureOutfit"):setOutfit(creatureOutfitVar)
            if task.countPokemon == 0 then
                creatureWidget:getChildById("creatureCount"):setText()
                creatureWidget:getChildById("creatureCount"):setImageSource("images/done")
            else
                creatureWidget:getChildById("creatureCount"):setText(task.countPokemon)
            end
            
            creatureWidget:getChildById("creatureOutfit"):setFixedCreatureSize(true)
        end
    end
    loaded = true
end

function updateTask(updatedTask)
    if not MainWindow or not playerTaskList then
        return
    end

    -- Pegamos a primeira entrada de `updatedTask`, pois agora é um array com apenas um NPC
    local npcData = updatedTask[1]
    if not npcData then
        return
    end

    local npcName = npcData.npcName
    if not npcName then
        return
    end

    -- Se o NPC não existir na `playerTaskList`, criamos ele
    if not playerTaskList[npcName] then
        playerTaskList[npcName] = {
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

    -- Itera sobre as novas tasks
    for _, taskData in pairs(npcData.tasks) do
        local pokemonName = taskData.pokemonName
        if not pokemonName then
            return
        end

        local found = false
        for _, storedTask in pairs(playerTaskList[npcName].tasks) do
            if storedTask.pokemonName == pokemonName then
                -- Apenas atualiza os valores existentes
                storedTask.countPokemon = taskData.countPokemon
                storedTask.taskCompleteIndicator = taskData.taskCompleteIndicator
                storedTask.pokemonOutfit = taskData.pokemonOutfit
                found = true
                break
            end
        end

        -- Se a task não existir, adicionamos
        if not found then
            table.insert(playerTaskList[npcName].tasks, {
                countPokemon = taskData.countPokemon,
                pokemonOutfit = {
                    lookType = taskData.pokemonOutfit.lookType,
                    lookFeet = taskData.pokemonOutfit.lookFeet,
                    lookHead = taskData.pokemonOutfit.lookHead,
                    lookLegs = taskData.pokemonOutfit.lookLegs,
                    lookBody = taskData.pokemonOutfit.lookBody
                },
                pokemonName = pokemonName,
                npcName = npcName,
                taskCompleteIndicator = taskData.taskCompleteIndicator
            })
        end
    end

    -- Atualiza a UI sem recriar o NPC
    local taskPanel = MainWindow:recursiveGetChildById('panelTasks')
    if not taskPanel then
        return
    end

    -- Encontra o NPC na interface gráfica e atualiza os dados
    for _, npcWidget in pairs(taskPanel:getChildren() or {}) do
        local npcNameWidget = npcWidget:getChildById("npcName")
        if npcNameWidget and npcNameWidget:getText() == npcName then
            -- Atualiza o outfit do NPC
            local outfitData = playerTaskList[npcName].outfit
            npcWidget:getChildById("outfit"):setOutfit({
                type = outfitData.lookType,
                head = outfitData.lookHead,
                body = outfitData.lookBody,
                legs = outfitData.lookLegs,
                feet = outfitData.lookFeet
            })

            -- Percorre todas as tasks e atualiza a UI do Pokémon correto
            for _, task in pairs(playerTaskList[npcName].tasks) do
                for _, creatureWidget in pairs(npcWidget:getChildren() or {}) do
                    if creatureWidget:getId() == task.pokemonName then
                        local countWidget = creatureWidget:getChildById("creatureCount")
                        if countWidget then
                            if task.countPokemon == 0 then
                                countWidget:setText()
                                countWidget:setImageSource("images/done")
                            else
                                countWidget:setText(task.countPokemon)
                            end
                        end

                        local creatureOutfit = creatureWidget:getChildById("creatureOutfit")
                        if creatureOutfit then
                            creatureOutfit:setOutfit({
                                type = task.pokemonOutfit.lookType,
                                head = task.pokemonOutfit.lookHead,
                                body = task.pokemonOutfit.lookBody,
                                legs = task.pokemonOutfit.lookLegs,
                                feet = task.pokemonOutfit.lookFeet
                            })
                        end
                    end
                end
            end
        end
    end
end

function onTileMapDescription()
    if MainWindow and MainWindow:isVisible() then
        close()
    end
end