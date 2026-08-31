local mainAutoComboWindow = nil
local availableMoves = {}
local comboSequence = {}
local currentPokemonName = ""
local MouseGrabberWidget = nil
local draggedMove = nil
local dragSource = nil -- 'available' ou 'combo'
local currentPokemonLookType = nil

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onWalk = closeWindow,
        onAutoWalk = closeWindow,
        onPokemonInfoReceived = onPokemonInfoReceived,
        onAutoComboReceived = onAutoComboReceived
    })
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onGameStart = onGameStart,
        onWalk = closeWindow,
        onAutoWalk = closeWindow,
        onPokemonInfoReceived = onPokemonInfoReceived,
        onAutoComboReceived = onAutoComboReceived
    })
    
    if MouseGrabberWidget then
        MouseGrabberWidget:destroy()
    end
end

function showMainWindow()
    if mainAutoComboWindow then
        mainAutoComboWindow:destroy()
    end

    mainAutoComboWindow = g_ui.loadUI("autocombo", modules.game_interface.getRootPanel())
    
    -- Atualiza o looktype da criatura se já tiver informação
    if currentPokemonLookType then
        local pokemonCreature = mainAutoComboWindow:recursiveGetChildById('pokemonCombo')
        if pokemonCreature then
            local outfit = pokemonCreature:getOutfit()
            outfit.type = currentPokemonLookType
            pokemonCreature:setOutfit(outfit)
        end
    end
    
    -- Atualiza o nome do Pokémon
    local pokemonNameLabel = mainAutoComboWindow:recursiveGetChildById('pokemonNameLabel')
    if pokemonNameLabel then
        if currentPokemonName and currentPokemonName ~= "" then
            pokemonNameLabel:setText(currentPokemonName)
        else
            pokemonNameLabel:setText("---")
        end
    end
    
    -- Carrega moves da pokebar
    loadAvailableMoves()
    
    -- Carrega combo salvo
    loadSavedCombo()
    
    -- Desenha interface
    updateWindowDisplay()
    
    addEvent(function() 
        if mainAutoComboWindow then
            g_effects.fadeIn(mainAutoComboWindow) 
        end
    end)
end

function onGameStart()
    MouseGrabberWidget = g_ui.createWidget('UIWidget')
    MouseGrabberWidget:setVisible(false)
    MouseGrabberWidget:setFocusable(false)
    MouseGrabberWidget.onMouseRelease = onDropMove
end

function onGameEnd()
    if mainAutoComboWindow then
        mainAutoComboWindow:destroy()
        mainAutoComboWindow = nil
    end

    if MouseGrabberWidget then
        MouseGrabberWidget:destroy()
        MouseGrabberWidget = nil
    end
    
    availableMoves = {}
    comboSequence = {}
    currentPokemonName = ""
    currentPokemonLookType = nil
end

-- New C++ callback function
function onPokemonInfoReceived(pokemonInfo)
    local infoType = pokemonInfo.infoType
    
    if infoType == 0 then
        -- Reset: limpa as informações
        currentPokemonLookType = nil
        currentPokemonName = ""
        availableMoves = {}
        comboSequence = {}
        
        -- Se a janela está aberta, atualiza
        if mainAutoComboWindow and mainAutoComboWindow:isVisible() then
            closeWindow()
        end
    elseif infoType == 1 then
        -- Recebe informações do pokémon
        local lookType = pokemonInfo.lookType
        local pokemonName = pokemonInfo.pokemonName
        
        currentPokemonLookType = lookType
        currentPokemonName = pokemonName
        
        -- Carrega moves e combo salvo automaticamente
        loadAvailableMoves()
        loadSavedCombo()
        
        -- Se a janela está aberta, atualiza a interface
        if mainAutoComboWindow and mainAutoComboWindow:isVisible() then
            -- Atualiza o outfit da criatura
            local pokemonCreature = mainAutoComboWindow:recursiveGetChildById('pokemonCombo')
            if pokemonCreature then
                local outfit = pokemonCreature:getOutfit()
                outfit.type = lookType
                pokemonCreature:setOutfit(outfit)
            end
            
            -- Atualiza o nome do Pokémon
            local pokemonNameLabel = mainAutoComboWindow:recursiveGetChildById('pokemonNameLabel')
            if pokemonNameLabel then
                pokemonNameLabel:setText(pokemonName)
            end
            
            updateWindowDisplay()
        end
    end
end

-- New C++ callback for AutoCombo protocol
function onAutoComboReceived(buffer)
    -- Handle auto combo data received from server
    print("AutoCombo data received:", buffer)
    -- You can implement specific logic here based on what the server sends
end

-- Legacy function for compatibility
function onReceivePokemonInfo(protocol, msg)
    local infoType = msg:getU8() -- 0 = reset, 1 = pokemon info
    
    local pokemonInfo = {
        infoType = infoType,
        lookType = 0,
        pokemonName = ""
    }
    
    if infoType == 1 then
        pokemonInfo.lookType = msg:getU16()
        pokemonInfo.pokemonName = msg:getString()
    end
    
    onPokemonInfoReceived(pokemonInfo)
end

function closeWindow()
    if mainAutoComboWindow then
        if mainAutoComboWindow and mainAutoComboWindow:isVisible() then
            addEvent(function()
                if mainAutoComboWindow then
                    g_effects.fadeOut(mainAutoComboWindow)
                    scheduleEvent(function()
                        if mainAutoComboWindow then
                            mainAutoComboWindow:destroy()
                            mainAutoComboWindow = nil
                        end
                    end, 250)
                end
            end)
        end
    end
end

function loadAvailableMoves()
    availableMoves = {}
    currentPokemonName = modules.game_pokemoves.getPokemonName() or ""
    
    local pokemonMoves = modules.game_pokemoves.getPokemonMoves()
    if pokemonMoves then
        for _, move in ipairs(pokemonMoves) do
            if move.spellword ~= "passive" then
                table.insert(availableMoves, {
                    spellword = move.spellword,
                    name = move.name,
                    icon = move.icon or 9047
                })
            end
        end
    end
end

function loadSavedCombo()
    comboSequence = {}
    
    if currentPokemonName == "" then
        return
    end
    
    local savedCombos = g_settings.get("autoComboSettings", "")
    local comboTable = {}
    
    if savedCombos:len() > 0 then
        comboTable = json.decode(savedCombos)
    end
    
    if comboTable[currentPokemonName] then
        -- Valida combo salvo contra moves disponíveis
        for _, savedMove in ipairs(comboTable[currentPokemonName]) do
            for _, availMove in ipairs(availableMoves) do
                if availMove.spellword == savedMove.spellword and 
                   availMove.name == savedMove.name then
                    table.insert(comboSequence, {
                        spellword = savedMove.spellword,
                        name = savedMove.name,
                        icon = savedMove.icon
                    })
                    break
                end
            end
        end
    end
end

function updateWindowDisplay()
    if not mainAutoComboWindow then
        return
    end
    
    -- Atualiza área de moves disponíveis
    local availablePanel = mainAutoComboWindow:recursiveGetChildById('availableMovesPanel')
    if not availablePanel then
        return
    end
    
    availablePanel:destroyChildren()
    
    for index, move in ipairs(availableMoves) do
        local moveWidget = g_ui.createWidget("AvailableMoveItem", availablePanel)
        moveWidget:setId("available_" .. index)
        moveWidget.moveIndex = index
        moveWidget.moveData = move
        
        local icon = moveWidget:getChildById("icon")
        if icon then
            local iconId = move.icon or 9047
            icon:setItemId(iconId)
            icon:setTooltip(move.name)
        end        

        -- Drag
        icon.onDragEnter = function(self)
            if g_ui.isMouseGrabbed() then return end
            MouseGrabberWidget:grabMouse()
            g_mouse.pushCursor('target')
            self:setOpacity(0.5)
            draggedMove = {
                widget = self,
                index = index,
                data = move
            }
            dragSource = 'available'
        end
    end
    
    -- Atualiza área de combo
    local comboPanel = mainAutoComboWindow:recursiveGetChildById('comboSequencePanel')
    if not comboPanel then
        return
    end
    
    local emptyComboLabel = mainAutoComboWindow:recursiveGetChildById('emptyComboLabel')
    
    comboPanel:destroyChildren()
    
    if #comboSequence == 0 then
        -- Mostra o label de combo vazio
        if emptyComboLabel then
            emptyComboLabel:show()
        end
    else
        -- Esconde o label de combo vazio
        if emptyComboLabel then
            emptyComboLabel:hide()
        end
        
        for index, move in ipairs(comboSequence) do
            local moveWidget = g_ui.createWidget("ComboMoveItem", comboPanel)
            moveWidget:setId("combo_" .. index)
            moveWidget.moveIndex = index
            moveWidget.moveData = move
            
            local icon = moveWidget:getChildById("icon")
            if icon then
                local iconId = move.icon or 9047
                icon:setItemId(iconId)
                icon:setTooltip(move.name)
            end
            
            icon.onClick = function()
                removeFromCombo(index)
            end
            
            -- Drag para reordenar
            icon.onDragEnter = function(self)
                if g_ui.isMouseGrabbed() then return end
                MouseGrabberWidget:grabMouse()
                g_mouse.pushCursor('target')
                self:setOpacity(0.5)
                draggedMove = {
                    widget = self,
                    index = index,
                    data = move
                }
                dragSource = 'combo'
            end
        end
    end
    
    -- Atualiza contador
    updateComboCounter()
end

function onDropMove(self, mousePosition, mouseButton)
    
    if not g_ui.isMouseGrabbed() then 
        return 
    end
    
    g_mouse.popCursor('target')
    MouseGrabberWidget:ungrabMouse()
    
    if not draggedMove then
        return
    end
    
    
    draggedMove.widget:setOpacity(1.0)
    
    local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
    
    if not clickedWidget then
        draggedMove = nil
        dragSource = nil
        return
    end
    
    
    -- Log parent info
    if clickedWidget:getParent() then
    end
    
    -- Procura se clicou em um ComboMoveItem
    local targetWidget = nil
    local targetIndex = nil
    
    if clickedWidget:getParent() and clickedWidget:getParent():getStyleName() == "ComboMoveItem" then
        targetWidget = clickedWidget:getParent()
        targetIndex = targetWidget.moveIndex
    elseif clickedWidget:getStyleName() == "ComboMoveItem" then
        targetWidget = clickedWidget
        targetIndex = targetWidget.moveIndex
    end
    
    if targetWidget and targetIndex then
        -- Soltou em cima de um move do combo
        if dragSource == 'combo' then
            -- Reordena dentro do combo
            local sourceIndex = draggedMove.index
            if sourceIndex and targetIndex and sourceIndex ~= targetIndex then
                comboSequence[sourceIndex], comboSequence[targetIndex] = 
                    comboSequence[targetIndex], comboSequence[sourceIndex]
                
                updateWindowDisplay()
                saveComboConfiguration()
            end
        elseif dragSource == 'available' then
            -- Verifica se o move já está no combo
            for _, move in ipairs(comboSequence) do
                if move.spellword == draggedMove.data.spellword then
                    showWarningMessage(tr("This move already configured in the Autocombo!"))
                    draggedMove = nil
                    dragSource = nil
                    return
                end
            end
            
            -- Insere na posição específica
            table.insert(comboSequence, targetIndex, {
                spellword = draggedMove.data.spellword,
                name = draggedMove.data.name,
                icon = draggedMove.data.icon
            })
            updateWindowDisplay()
            saveComboConfiguration()
        end
    else
        -- Verifica se soltou na área do combo
        
        -- Procura o autoComboWindow na hierarquia
        local current = clickedWidget
        local inAutoComboWindow = false
        
        while current do
            if current:getId() == "autoComboWindow" then
                inAutoComboWindow = true
                break
            end
            current = current:getParent()
            if not current then
                break
            end
        end
        
        if inAutoComboWindow then
            -- Está dentro da janela do autocombo
            -- Agora verifica se está na área do combo (não na área de available)
            local inAvailableArea = false
            current = clickedWidget
            
            while current do
                if current:getId() == "availableMovesPanel" or current:getId() == "availableMovesContainer" then
                    inAvailableArea = true
                    break
                end
                current = current:getParent()
                if not current or current:getId() == "autoComboWindow" then
                    break
                end
            end
            
            if not inAvailableArea and dragSource == 'available' then
                addToCombo(draggedMove.data)
            end
        end
    end
    
    draggedMove = nil
    dragSource = nil
end

function addToCombo(moveData)
    -- Verifica se o move já está no combo
    for _, move in ipairs(comboSequence) do
        if move.spellword == moveData.spellword then
            showWarningMessage(tr("This move already configured in the Autocombo!"))
            return
        end
    end
    
    table.insert(comboSequence, {
        spellword = moveData.spellword,
        name = moveData.name,
        icon = moveData.icon
    })
    updateWindowDisplay()
    saveComboConfiguration()
end

function removeFromCombo(index)
    table.remove(comboSequence, index)
    updateWindowDisplay()
    saveComboConfiguration()
end

function saveComboConfiguration()
    if currentPokemonName == "" then
        return
    end
    
    local savedCombos = g_settings.get("autoComboSettings", "")
    local comboTable = {}
    
    if savedCombos:len() > 0 then
        comboTable = json.decode(savedCombos)
    end
    
    comboTable[currentPokemonName] = comboSequence
    
    g_settings.set("autoComboSettings", json.encode(comboTable))
    g_settings.save()
end

function updateComboCounter()
    if not mainAutoComboWindow then
        return
    end
    
    local counter = mainAutoComboWindow:recursiveGetChildById('comboCounter')
    if counter then
        counter:setText(tr("%d move(s)", #comboSequence))
    end
end

function showWarningMessage(text)
    if mainAutoComboWindow then
        local messageLabel = mainAutoComboWindow:recursiveGetChildById('messageLabel')
        if messageLabel then
            messageLabel:setText(text)
            messageLabel:setColor("#FF9900")
            messageLabel:show()
            
            scheduleEvent(function()
                if messageLabel then
                    messageLabel:hide()
                end
            end, 3000)
        end
    end
end

function showSuccessMessage(text)
    if mainAutoComboWindow then
        local messageLabel = mainAutoComboWindow:recursiveGetChildById('messageLabel')
        if messageLabel then
            messageLabel:setText(text)
            messageLabel:setColor("#00FF00")
            messageLabel:show()
            
            scheduleEvent(function()
                if messageLabel then
                    messageLabel:hide()
                end
            end, 2000)
        end
    end
end

function onMovesReordered()
    -- Quando os moves são reordenados na barra, atualiza os moves disponíveis
    if mainAutoComboWindow and mainAutoComboWindow:isVisible() then
        loadAvailableMoves()
        updateWindowDisplay()
        showSuccessMessage("Moves disponíveis atualizados!")
    end
end

function getComboSpellwords()
    -- Retorna a lista de spellwords do combo atual
    if not currentPokemonName or currentPokemonName == "" then
        return nil
    end
    
    if #comboSequence == 0 then
        return nil
    end
    
    local spellwords = {}
    for _, move in ipairs(comboSequence) do
        if move.spellword then
            table.insert(spellwords, move.spellword)
        end
    end
    
    return spellwords
end