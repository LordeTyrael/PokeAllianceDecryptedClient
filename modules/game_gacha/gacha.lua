local gachaWindow = nil
local currentGachaData = nil
local isRolling = false
local isSkippingVideo = false
local currentFragmentsReceived = nil
local gachaRewardsState = nil
local gachaRewardsStateIndex = nil
local rewardAnimationEvents = {}
local currentRewardsData = {}
local gachaVideoWidget = nil
local pendingRewards = nil

function onSpacePressed()
    if not gachaWindow then
        releaseGachaRewardsState()
        return
    end

    if gachaVideoWidget and not gachaVideoWidget:isDestroyed() and gachaVideoWidget:isVisible() then
        skipGachaVideo()
        return
    end

    local resultPanel = gachaWindow.resultPanel
    if not resultPanel or not resultPanel:isVisible() then
        return
    end

    local fragmentsOverlay = resultPanel:getChildById('fragmentsOverlay')
    if fragmentsOverlay and not fragmentsOverlay:isDestroyed() then
        g_game.requestGachaCloseFragments()
        return
    end

    local skipButton = resultPanel:getChildById('skipButton')
    if skipButton and not skipButton:isDestroyed() and skipButton:isVisible() then
        skipRewardsAnimation()
        return
    end

    local closeButton = resultPanel:getChildById('closeRewardsButton')
    if closeButton and not closeButton:isDestroyed() and closeButton:isVisible() then
        closeRewardsPanel()
        return
    end
end

function setupGachaRewardsState()
    if not gachaWindow then return end
    if not gachaRewardsState then
        gachaRewardsState = UIState.create()
        gachaRewardsStateIndex = gachaRewardsState:new(function(released)
            if released then
                if gachaWindow and not gachaWindow:isDestroyed() then
                    g_uistates.remove(gachaWindow)
                end
            else
                if gachaWindow and not gachaWindow:isDestroyed() then
                    g_uistates.push(gachaWindow)
                end
            end
        end)
        gachaRewardsState:connect(gachaWindow, {
            onKeyDown = function(widget, keyCode, keyboardModifiers)
                if keyCode == KeySpace then
                    onSpacePressed()
                    return true
                end
                return false
            end
        })
        gachaRewardsState:gotoState(0)
    end
    gachaRewardsState:gotoState(gachaRewardsStateIndex)
end

function releaseGachaRewardsState()
    if gachaRewardsState and gachaRewardsStateIndex then
        gachaRewardsState:gotoState(0)
    end
end

function init()
    connect(g_game, {
        onGameEnd = onCloseGacha,
        onOpenGacha = onOpenGacha,
        onCloseGacha = onCloseGacha,
        onGachaRewards = onGachaRewards,
        onGachaUpdatePoints = onGachaUpdatePoints,
        onGachaSkipResponse = onGachaSkipResponse,
        onGachaSkipVideoResponse = onGachaSkipVideoResponse,
        onGachaCloseRewardsResponse = onGachaCloseRewardsResponse,
        onGachaUpdateFragments = onGachaUpdateFragments,
        onGachaCloseFragmentsResponse = onGachaCloseFragmentsResponse
    })
    
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onCloseGacha,
        onOpenGacha = onOpenGacha,
        onCloseGacha = onCloseGacha,
        onGachaRewards = onGachaRewards,
        onGachaUpdatePoints = onGachaUpdatePoints,
        onGachaSkipResponse = onGachaSkipResponse,
        onGachaSkipVideoResponse = onGachaSkipVideoResponse,
        onGachaCloseRewardsResponse = onGachaCloseRewardsResponse,
        onGachaUpdateFragments = onGachaUpdateFragments,
        onGachaCloseFragmentsResponse = onGachaCloseFragmentsResponse
    })
end

-- Evento chamado pelo C++ quando servidor envia GACHA_OPEN
function onOpenGacha(gachaData)
    if gachaWindow then
        gachaWindow:destroy()
    end

    gachaWindow = g_ui.loadUI("gacha", modules.game_interface.getRootPanel())
    gachaWindow:breakAnchors()
    local mapPanel = modules.game_interface.getMapPanel()
    local mapId = mapPanel and mapPanel:getId() or nil
    if mapId then
        gachaWindow:addAnchor(AnchorVerticalCenter, mapId, AnchorVerticalCenter)
        gachaWindow:addAnchor(AnchorHorizontalCenter, mapId, AnchorHorizontalCenter)
    end
    
    -- Armazena dados da season atual
    currentGachaData = {
        gachaPoints = gachaData.gachaPoints or 0,
        seasonId = gachaData.seasonId or 0,
        seasonName = gachaData.seasonName or "Gacha System",
        banner = gachaData.banner or "",
        fragments = gachaData.fragments or {},
        items = gachaData.items or {}
    }
    
    -- Atualiza título com nome da season
    local titleLabel = gachaWindow:recursiveGetChildById('gachaTitle')
    if titleLabel then
        if currentGachaData.seasonId > 0 and currentGachaData.seasonName ~= "" then
            titleLabel:setText(currentGachaData.seasonName)
        else
            titleLabel:setText(tr("Gacha System"))
        end
    end

    gachaWindow.banner:setImageSource(string.format("images/%s", currentGachaData.banner))
    
    -- Atualiza pontos do jogador
    local pointsLabel = gachaWindow:recursiveGetChildById('gachaPoints')
    if pointsLabel then
        pointsLabel:setText(tostring(currentGachaData.gachaPoints))
    end
    
    -- Atualiza fragmentos
    updateFragmentsDisplay()
    
    -- Criar tooltip com todos os itens possíveis
    createItemsTooltip()
    
    show()
    if not gachaData.spectate then
        g_uistates.push(gachaWindow)
    end
end

-- Atualiza exibição dos fragmentos
function updateFragmentsDisplay()
    if not gachaWindow or not currentGachaData then return end
    
    local fragmentsPanel = gachaWindow:getChildById('fragmentsPanel')
    local fragmentsContainer = fragmentsPanel:getChildById('fragmentsContainer')
    
    if not fragmentsPanel or not fragmentsContainer then return end
    
    -- Limpar fragmentos anteriores
    fragmentsContainer:destroyChildren()
    
    -- Se não há fragmentos, esconder painel
    if not currentGachaData.fragments or #currentGachaData.fragments == 0 then
        fragmentsPanel:setVisible(false)
        return
    end
    
    -- Mostrar painel e criar widgets para cada fragmento
    fragmentsPanel:setVisible(true)
    
    -- Mostrar apenas o primeiro fragmento (outfit) no painel externo
    local panelHeight = 20 + 65
    fragmentsPanel:setHeight(panelHeight)
    
    local fragment = currentGachaData.fragments[1]
    if not fragment then return end
    
    do
        local fragmentWidget = g_ui.createWidget('FragmentWidget', fragmentsContainer)
        local fragmentOutfitFemale = fragmentWidget:recursiveGetChildById('fragmentOutfitFemale')
        local fragmentOutfitMale = fragmentWidget:recursiveGetChildById('fragmentOutfitMale')
        local fragmentName = fragmentWidget:recursiveGetChildById('fragmentName')
        local fragmentProgress = fragmentWidget:recursiveGetChildById('fragmentProgress')
        
        -- Configurar onClick para abrir seleção com todos os fragments
        fragmentWidget.onClick = function()
            showFragmentItemSelection()
        end
        
        -- Definir outfit baseado no gênero do jogador
        if fragmentOutfitFemale then
            fragmentOutfitFemale:setOutfit({type = fragment.lookTypeFemale})
            fragmentOutfitFemale:show()
        end

        if fragmentOutfitMale then
            fragmentOutfitMale:setOutfit({type = fragment.lookTypeMale})
            fragmentOutfitMale:show()
        end
        
        -- Definir nome do fragmento (usar nome da season)
        if fragmentName then
            fragmentName:setText(currentGachaData.seasonName .. " Shards")
        end
        
        -- Definir progresso (usar requiredCount do primeiro item do primeiro fragmento)
        if fragmentProgress then
            local current = fragment.currentCount or 0
            local required = 100
            if fragment.requiredCounts and fragment.requiredCounts[1] then
                required = fragment.requiredCounts[1]
            end
            local percentage = math.min(100, math.floor((current / required) * 100))
            fragmentProgress:setText(string.format("%d/%d (%d%%)", current, required, percentage))
            
            -- Atualizar barra de progresso visual
            local fullProgress = fragmentWidget:recursiveGetChildById('fullProgress')
            if fullProgress then
                local barWidth = 200
                local clippedWidth = math.max(1, barWidth * (percentage / 100))
                local rect = { x = 0, y = 0, width = clippedWidth, height = fullProgress:getHeight() }
                fullProgress:setImageClip(rect)
                fullProgress:setImageRect(rect)
            end
            
            -- Mudar cor e shader baseado no progresso
            if current >= required then
                fragmentProgress:setColor('#00ff00') -- Verde se completo
                -- Adicionar shader aos outfits quando completo
                if fragmentOutfitMale then
                    local outfit = fragmentOutfitMale:getOutfit()
                    outfit.shader = "premier"
                    fragmentOutfitMale:setOutfit(outfit)
                end
                if fragmentOutfitFemale then
                    local outfit = fragmentOutfitFemale:getOutfit()
                    outfit.shader = "premier"
                    fragmentOutfitFemale:setOutfit(outfit)
                end
            elseif percentage >= 50 then
                fragmentProgress:setColor('#ffff00') -- Amarelo se >50%
                -- Remover shader
                if fragmentOutfitMale then
                    local outfit = fragmentOutfitMale:getOutfit()
                    outfit.shader = ""
                    fragmentOutfitMale:setOutfit(outfit)
                end
                if fragmentOutfitFemale then
                    local outfit = fragmentOutfitFemale:getOutfit()
                    outfit.shader = ""
                    fragmentOutfitFemale:setOutfit(outfit)
                end
            else
                fragmentProgress:setColor('#ffffff') -- Branco se <50%
                -- Remover shader
                if fragmentOutfitMale then
                    local outfit = fragmentOutfitMale:getOutfit()
                    outfit.shader = ""
                    fragmentOutfitMale:setOutfit(outfit)
                end
                if fragmentOutfitFemale then
                    local outfit = fragmentOutfitFemale:getOutfit()
                    outfit.shader = ""
                    fragmentOutfitFemale:setOutfit(outfit)
                end
            end
        end
    end
end

-- Cria tooltip mostrando todos os itens possíveis do gacha
function createItemsTooltip()
    if not gachaWindow or not currentGachaData then return end
    local itemsTooltip = g_ui.createWidget('GachaItemsTooltip', rootWidget)
    local categoriesContainer = itemsTooltip:getChildById('categoriesContainer')
    
    -- Ordenar categorias por range (menor para maior)
    local sortedCategories = {}
    for rangeKey, itemList in pairs(currentGachaData.items) do
        -- Extrair min e max do rangeKey "[min,max]"
        local min, max = rangeKey:match("%[(%d+),(%d+)%]")
        if min and max then
            table.insert(sortedCategories, {
                rangeKey = rangeKey,
                min = tonumber(min),
                max = tonumber(max),
                items = itemList
            })
        end
    end
    
    -- Ordenar por min range
    table.sort(sortedCategories, function(a, b) return a.min < b.min end)
    
    -- Criar seção para cada categoria
    for _, category in ipairs(sortedCategories) do
        local categorySection = g_ui.createWidget('CategorySection', categoriesContainer)
        local categoryTitle = categorySection:getChildById('categoryTitle')
        local itemsGrid = categorySection:getChildById('itemsGrid')
        
        -- Definir título da categoria com range em porcentagem
        local rarityName = getRarityName(category.min, category.max)
        local diff = category.max - category.min
        local percentage = (diff / 10000) * 100
        categoryTitle:setText(string.format("%s (%.2f%%)", rarityName, percentage))
        
        -- Adicionar itens desta categoria
        for _, item in ipairs(category.items) do
            local itemWidget = g_ui.createWidget('ItemSlot', itemsGrid)
            itemWidget:setItemId(item.clientId)
            itemWidget:setItemCount(item.amount)
        end
        
        -- Ajustar altura do grid baseado na quantidade de itens
        local itemCount = #category.items
        if itemCount > 10 then
            local itemsPerRow = 10
            local rows = math.ceil(itemCount / itemsPerRow)
            local itemHeight = 34
            local spacing = 2
            local newGridHeight = (itemHeight * rows) + (spacing * (rows - 1))
            itemsGrid:setHeight(newGridHeight)
        end
    end
    
    -- Adicionar tooltip ao chest icon
    local chestIcon = gachaWindow:getChildById('pokeballIcon')
    if chestIcon then
        chestIcon:setTooltip(itemsTooltip)
    end
end

-- Retorna nome de raridade baseado no range
function getRarityName(min, max)
    local diff = max - min
    if diff <= 5 then
        return "Legendary"
    elseif diff <= 100 then
        return "Ultra Rare"
    elseif diff <= 500 then
        return "Rare"
    elseif diff <= 1000 then
        return "Uncommon"
    elseif diff <= 3400 then
        return "Common"
    elseif diff <= 5000 then
        return "Frequent"
    else
        return "Abundant"
    end
end

-- Evento chamado pelo C++ quando servidor envia GACHA_CLOSE
function onCloseGacha()
    releaseGachaRewardsState()
    gachaRewardsState = nil
    gachaRewardsStateIndex = nil
    closeFragmentSelection()
    if gachaWindow then
        g_uistates.remove(gachaWindow)
        gachaWindow:destroy()
        gachaWindow = nil
    end
    currentGachaData = nil
    isRolling = false
end

-- Determina a raridade de um item baseado nas categorias (clientId + amount)
function getItemRarity(clientId, amount)
    if not currentGachaData or not currentGachaData.items then return 0, "Abundant" end
    
    for rangeKey, itemList in pairs(currentGachaData.items) do
        for _, item in ipairs(itemList) do
            if item.clientId == clientId and item.amount == amount then
                local min, max = rangeKey:match("%[(%d+),(%d+)%]")
                if min and max then
                    local diff = tonumber(max) - tonumber(min)
                    local rarityName = getRarityName(tonumber(min), tonumber(max))
                    return diff, rarityName
                end
            end
        end
    end
    
    return 10000, "Abundant" -- Default para itens não encontrados
end

-- Retorna soundID baseado na raridade
function getRaritySoundID(rarityName)
    if rarityName == "Legendary" then
        return 47 -- Som de legendary
    elseif rarityName == "Ultra Rare" then
        return 46 -- Som de ultra rare
    else
        return 45 -- Som de common/frequent/abundant
    end
end

-- Reproduz vídeo do gacha antes de mostrar rewards
function playGachaVideo(rewards)
    if not gachaWindow then return end
    
    -- Armazenar rewards para usar depois
    pendingRewards = rewards
    
    gachaVideoWidget = gachaWindow:getChildById('gachaVideo')
    if not gachaVideoWidget then 
        return 
    end
    
    -- Resetar estado do widget antes de começar
    gachaVideoWidget:reset() -- Reset completo do vídeo
    gachaVideoWidget:setVisible(true)
    gachaVideoWidget:raise()    
    -- Iniciar reprodução
    gachaVideoWidget:play()
    
    -- Manter foco na janela principal para que a tecla espaço funcione
    gachaWindow:focus()
    
    -- Fade in usando g_effects (500ms)
    g_effects.fadeIn(gachaVideoWidget)
    
    -- Mostrar botão Skip Video
    local skipVideoButton = gachaWindow:getChildById('skipVideoButton')
    if skipVideoButton then
        skipVideoButton:setVisible(true)
        skipVideoButton:raise()
    end
    
    -- Agendar fade out antes do vídeo terminar (aos 7 segundos, 1 segundo antes do fim)
    scheduleEvent(function()
        if gachaVideoWidget and not gachaVideoWidget:isDestroyed() and gachaVideoWidget:isVisible() then
            g_effects.fadeOut(gachaVideoWidget)
            
            -- Esconder o widget após fade out completar
            scheduleEvent(function()
                if gachaVideoWidget and not gachaVideoWidget:isDestroyed() then
                    gachaVideoWidget:setVisible(false)
                end
            end, 1200)
        end
    end, 7000)
    
    -- Conectar evento de fim do vídeo
    connect(gachaVideoWidget, { onVideoEnd = function() onGachaVideoFinished(rewards) end })
end

-- Chamado quando o vídeo termina
function onGachaVideoFinished(rewards)
    -- Esconder botão Skip Video
    local skipVideoButton = gachaWindow and gachaWindow:getChildById('skipVideoButton')
    if skipVideoButton then
        skipVideoButton:setVisible(false)
    end
    
    if gachaVideoWidget then
        gachaVideoWidget:setVisible(false)
        gachaVideoWidget:setPaused(true)
        gachaVideoWidget:setOpacity(1) -- Resetar opacity para próxima vez
        disconnect(gachaVideoWidget, { onVideoEnd = onGachaVideoFinished })
    end
    
    -- Limpar pendingRewards e mostrar
    pendingRewards = nil
    showGachaRewards(rewards)
end

-- Pula o vídeo do gacha (envia request ao servidor)
function skipGachaVideo()
    if not g_game.isOnline() then return end
    if isSkippingVideo then 
        return 
    end
    
    isSkippingVideo = true
    
    -- Enviar requisição ao servidor
    g_game.requestGachaSkipVideo()
end

-- Evento chamado pelo C++ quando servidor responde ao skip de vídeo
function onGachaSkipVideoResponse()
    if not gachaWindow then 
        isSkippingVideo = false
        return 
    end
    
    -- Esconder botão Skip Video
    local skipVideoButton = gachaWindow:getChildById('skipVideoButton')
    if skipVideoButton then
        skipVideoButton:setVisible(false)
    end
    
    -- Parar e esconder vídeo imediatamente
    if gachaVideoWidget and not gachaVideoWidget:isDestroyed() then
        disconnect(gachaVideoWidget, { onVideoEnd = onGachaVideoFinished })
        gachaVideoWidget:setPaused(true)
        gachaVideoWidget:setVisible(false)
        gachaVideoWidget:setOpacity(1)
        -- Aguardar um pouco antes de resetar para evitar race condition
        scheduleEvent(function()
            if gachaVideoWidget and not gachaVideoWidget:isDestroyed() then
                gachaVideoWidget:reset()
            end
        end, 100)
    end
    
    isSkippingVideo = false
    
    -- Mostrar rewards se existirem
    if pendingRewards then
        showGachaRewards(pendingRewards)
        pendingRewards = nil
    end
end

-- Evento chamado pelo C++ quando servidor envia recompensas
function onGachaRewards(rewards, fragmentsReceived)
    isRolling = false
    
    -- Limpar fragmentos de rolls anteriores ANTES de processar novo
    currentFragmentsReceived = nil
    
    -- Limpar eventos anteriores
    for _, eventId in ipairs(rewardAnimationEvents) do
        removeEvent(eventId)
    end
    rewardAnimationEvents = {}
    
    if not gachaWindow or not rewards then return end
    
    -- Armazenar fragmentos recebidos para exibir depois
    currentFragmentsReceived = fragmentsReceived
    
    -- Bindar tecla espaço via UIState para pular estados
    setupGachaRewardsState()
    
    -- Iniciar reprodução do vídeo antes de mostrar rewards
    playGachaVideo(rewards)
end

-- Mostra as recompensas (separado da função onGachaRewards)
function showGachaRewards(rewards)
    if not gachaWindow or not rewards then 
        -- Limpar fragmentos se não pode mostrar rewards
        currentFragmentsReceived = nil
        return 
    end
    
    local resultPanel = gachaWindow.resultPanel
    if not resultPanel then 
        -- Limpar fragmentos se não há painel
        currentFragmentsReceived = nil
        return 
    end
    
    -- Limpar itens anteriores
    local rewardsContainer = resultPanel:getChildById('rewardsContainer')
    if not rewardsContainer then return end
    rewardsContainer:destroyChildren()
    
    -- Ajustar tamanho da interface baseado na quantidade de rewards
    local rewardCount = #rewards
    local panelWidth, panelHeight, containerWidth, containerHeight, itemWidth, itemHeight, cellSpacing
    
    if rewardCount == 1 then
        -- Interface pequena para 1 reward - item médio e centralizado
        itemWidth = 64
        itemHeight = 64
        cellSpacing = 0
        containerWidth = 64
        containerHeight = 64
        panelWidth = 250
        panelHeight = 175
    elseif rewardCount <= 25 then
        -- Interface média para até 25 rewards - 5 itens por linha
        itemWidth = 64
        itemHeight = 64
        cellSpacing = 8
        local itemsPerRow = 5
        containerWidth = (itemWidth * itemsPerRow) + (cellSpacing * (itemsPerRow - 1))  -- 64*5 + 8*4 = 352
        containerHeight = 340
        panelWidth = containerWidth + 60  -- margem extra
        panelHeight = 450
    else
        -- Interface grande para 50+ rewards - 10 itens por linha
        itemWidth = 64
        itemHeight = 64
        cellSpacing = 8
        local itemsPerRow = 10
        containerWidth = (itemWidth * itemsPerRow) + (cellSpacing * (itemsPerRow - 1))  -- 64*10 + 8*9 = 712
        containerHeight = 340
        panelWidth = containerWidth + 60  -- margem extra
        panelHeight = 450
    end
    
    -- Aplicar novos tamanhos
    resultPanel:setSize({width = panelWidth, height = panelHeight})
    rewardsContainer:setSize({width = containerWidth, height = containerHeight})
    
    -- Atualizar layout do grid (com flow = true, centraliza automaticamente)
    local layout = rewardsContainer:getLayout()
    if layout then
        layout:setCellSpacing(cellSpacing)
        layout:setCellSize({width = itemWidth, height = itemHeight})
    end
    
    -- Criar widgets para todos os itens (inicialmente invisíveis)
    local itemWidgets = {}
    currentRewardsData = {} -- Resetar dados de rewards
    
    for i, reward in ipairs(rewards) do
        local itemWidget = g_ui.createWidget('RewardItemWidget', rewardsContainer)
        local itemIcon = itemWidget:getChildById('itemIcon')
        local itemAmount = itemWidget:getChildById('itemAmount')
        
        -- Ajustar tamanho do widget e seus componentes
        itemWidget:setSize({width = itemWidth, height = itemHeight})
        
        if itemIcon then
            -- Tamanho do ícone é igual ao tamanho do item
            itemIcon:setSize({width = itemWidth, height = itemHeight})
            itemIcon:setItemId(reward.clientId)
            
            -- Sistema de offset para itens específicos
            if reward.clientId == 48404 then
                itemIcon:setImageOffset({x = 10, y = 10})
            end
        end
        
        -- Determinar raridade do item (considera clientId + amount)
        local rarityDiff, rarityName = getItemRarity(reward.clientId, reward.amount)
        local soundID = getRaritySoundID(rarityName)
        
        -- Definir borda baseada na raridade
        local itemBorder = itemWidget:getChildById('itemBorder')
        if itemBorder then
            local borderImage = "images/border_0" -- padrão
            if rarityName == "Legendary" then
                borderImage = "images/border_3"
            elseif rarityName == "Ultra Rare" then
                borderImage = "images/border_2"
            elseif rarityName == "Super Rare" then
                borderImage = "images/border_1"
            end
            itemBorder:setImageSource(borderImage)
        end
        
        -- Armazenar dados do reward incluindo raridade
        currentRewardsData[i] = {
            clientId = reward.clientId,
            amount = reward.amount,
            rarityDiff = rarityDiff,
            rarityName = rarityName,
            soundID = soundID,
            revealed = false
        }
        
        if itemAmount and reward.amount > 1 then
            itemAmount:setText(tostring(reward.amount))
            itemAmount:setVisible(true)
            itemAmount:setOpacity(0)
        elseif itemAmount then
            itemAmount:setVisible(false)
        end
        
        -- Item (itemIcon) começa invisível, carta visível
        if itemIcon then
            itemIcon:setOpacity(0)
        end
        
        table.insert(itemWidgets, itemWidget)
    end
    
    -- Mostrar painel de resultados
    resultPanel:show()
    resultPanel:raise()
    
    -- Destruir overlay de fragmentos antigo se existir (de roll anterior)
    local oldFragmentsOverlay = resultPanel:getChildById('fragmentsOverlay')
    if oldFragmentsOverlay and not oldFragmentsOverlay:isDestroyed() then
        oldFragmentsOverlay:destroy()
    end
    
    -- Mostrar botão SKIP e esconder botão CLOSE (resetar estado)
    local skipButton = resultPanel:getChildById('skipButton')
    if skipButton then
        skipButton:setVisible(true)
    end
    
    local closeButton = resultPanel:getChildById('closeRewardsButton')
    if closeButton then
        closeButton:setVisible(false)
    end
    
    local closeButton = resultPanel:getChildById('closeRewardsButton')
    if closeButton then
        closeButton:setVisible(false)
    end
    
    -- Animar revelação dos itens (1 por segundo) - fadeout da carta
    local accumulatedDelay = 0
    for i, widget in ipairs(itemWidgets) do
        local eventId = scheduleEvent(function()
            if widget and not widget:isDestroyed() then
                -- Tocar som baseado na raridade
                local rewardData = currentRewardsData[i]
                if rewardData and g_game.getLocalPlayer() then
                    local player = g_game.getLocalPlayer()
                    local pos = player:getPosition()
                    g_game.onSoundServer(pos, 6, rewardData.soundID, 2, player:getId())
                    rewardData.revealed = true
                end
                
                -- Fazer fade-out da carta e fade-in do item simultaneamente
                local cardCover = widget:getChildById('cardCover')
                local itemIcon = widget:getChildById('itemIcon')
                local itemAmount = widget:getChildById('itemAmount')
                if cardCover and not cardCover:isDestroyed() then
                    -- Transição simultânea em 500ms
                    local steps = 10
                    local stepDuration = 50 -- 500ms total
                    local currentStep = 0
                    
                    local fadeEvent = nil
                    fadeEvent = cycleEvent(function()
                        currentStep = currentStep + 1
                        if currentStep <= steps then
                            local progress = currentStep / steps
                            -- Carta: opacity 1 -> 0 (linear)
                            if cardCover and not cardCover:isDestroyed() then
                                cardCover:setOpacity(1 - progress)
                            end
                            -- Item: opacity 0 -> 1 (mais lento, usando curva quadrática)
                            local itemProgress = progress * progress -- progress^2 para aparecer mais devagar
                            if itemIcon and not itemIcon:isDestroyed() then
                                itemIcon:setOpacity(itemProgress)
                            end
                            -- ItemAmount: mesma progressão do item
                            if itemAmount and not itemAmount:isDestroyed() and itemAmount:isVisible() then
                                itemAmount:setOpacity(itemProgress)
                            end
                        else
                            removeEvent(fadeEvent)
                            -- Destruir carta após fadeout completo
                            if cardCover and not cardCover:isDestroyed() then
                                cardCover:destroy()
                            end
                        end
                    end, stepDuration)
                end
            end
            
        end, accumulatedDelay)
        table.insert(rewardAnimationEvents, eventId)
        
        -- Calcular delay acumulado para o próximo item
        local currentReward = currentRewardsData[i]
        if currentReward and currentReward.rarityName == "Legendary" then
            accumulatedDelay = accumulatedDelay + 2000 -- 2 segundos após lendário
        else
            accumulatedDelay = accumulatedDelay + 1000 -- 1 segundo padrão
        end
    end
    
    -- Após agendar TODOS os itens, agendar a exibição de fragmentos/botão close para depois do ÚLTIMO
    local lastItemDelay = accumulatedDelay -- Tempo do último item
    local totalDelay = lastItemDelay + 500 -- Último item + fade-out de 500ms
    
    local finalEventId = scheduleEvent(function()
        if not resultPanel or resultPanel:isDestroyed() then return end
        
        local skipButton = resultPanel:getChildById('skipButton')
        if skipButton and not skipButton:isDestroyed() then
            skipButton:setVisible(false)
        end
        
        -- Se há fragmentos recebidos, exibir tela de fragmentos
        if currentFragmentsReceived and #currentFragmentsReceived > 0 then
            showFragmentsReceived()
        else
            -- Se não há fragmentos, mostrar botão CLOSE normalmente
            local closeButton = resultPanel:getChildById('closeRewardsButton')
            if closeButton and not closeButton:isDestroyed() then
                closeButton:setVisible(true)
            end
        end
    end, totalDelay)
    table.insert(rewardAnimationEvents, finalEventId)
end

-- Mostra tela com fragmentos recebidos
function showFragmentsReceived()
    if not gachaWindow or not currentFragmentsReceived or #currentFragmentsReceived == 0 then
        currentFragmentsReceived = nil
        return
    end
    
    local resultPanel = gachaWindow.resultPanel
    if not resultPanel then 
        currentFragmentsReceived = nil
        return 
    end
    
    -- Verificar se resultPanel está visível (rewards devem estar sendo mostradas)
    if not resultPanel:isVisible() then
        currentFragmentsReceived = nil
        return
    end
    
    -- Criar overlay escuro
    local fragmentsOverlay = g_ui.createWidget('FragmentEarnWidget', resultPanel)
    fragmentsPanel = fragmentsOverlay.fragmentsPanel
    
    -- Adicionar cada fragmento
    local currentY = 0
    for _, fragment in ipairs(currentFragmentsReceived) do
        local fragmentWidget = g_ui.createWidget('UIWidget', fragmentsPanel.fragmentsContainer)
        fragmentWidget:setHeight(80)
        
        if currentY == 0 then
            fragmentWidget:addAnchor(AnchorTop, 'parent', AnchorTop)
        else
            fragmentWidget:addAnchor(AnchorTop, 'prev', AnchorBottom)
            fragmentWidget:setMarginTop(10)
        end
        fragmentWidget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        fragmentWidget:addAnchor(AnchorRight, 'parent', AnchorRight)
        
        currentY = currentY + 60
        
        -- Ícone do item
        local itemIcon = g_ui.createWidget('UIItem', fragmentWidget)
        itemIcon:setItemId(fragment.clientId)
        itemIcon:setSize({width = 80, height = 80})
        itemIcon:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        itemIcon:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        itemIcon:setVirtual(true)
        
        -- Texto do fragmento
        local fragmentText = g_ui.createWidget('Label', fragmentWidget)
        local fragmentCount = fragment.amount or fragment.count or 1
        fragmentText:setTextAutoResize(true)
        fragmentText:setText(string.format('%dx Fragment Shards', fragmentCount))
        fragmentText:setTTF('poppins', 'semibold', 12)
        fragmentText:setColor('#e7d7be')
        fragmentText:addAnchor(AnchorHorizontalCenter, 'prev', AnchorHorizontalCenter)
        fragmentText:addAnchor(AnchorTop, 'prev', AnchorBottom)
    end
    
    -- Botão continuar
    local continueButton = g_ui.createWidget('NewButton', fragmentsPanel)
    continueButton:setText('Continue')
    continueButton:setSize({width = 120, height = 35})
    continueButton:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    continueButton:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    continueButton:setMarginBottom(15)
    continueButton:setImageSource("images/points_background")
    continueButton.onClick = function()
        -- Enviar request ao servidor
        g_game.requestGachaCloseFragments()
    end
end

-- Pula toda a animação de recompensas (envia request ao servidor)
function skipRewardsAnimation()
    if not g_game.isOnline() then return end
    
    -- Enviar requisição ao servidor
    g_game.requestGachaSkip()
end

-- Evento chamado pelo C++ quando servidor responde ao skip
function onGachaSkipResponse()
    if not gachaWindow then return end    
    local resultPanel = gachaWindow.resultPanel
    if not resultPanel then return end
    
    -- Determinar maior raridade entre itens não revelados
    local highestRaritySound = nil
    local lowestDiff = 10000
    
    for i, rewardData in pairs(currentRewardsData) do
        if not rewardData.revealed and rewardData.rarityDiff < lowestDiff then
            lowestDiff = rewardData.rarityDiff
            highestRaritySound = rewardData.soundID
        end
    end
    
    -- Tocar som da maior raridade
    if highestRaritySound and g_game.getLocalPlayer() then
        local player = g_game.getLocalPlayer()
        local pos = player:getPosition()
        g_game.onSoundServer(pos, 6, highestRaritySound, 2, player:getId())
    end
    
    -- Cancelar todos os eventos de animação
    for _, eventId in ipairs(rewardAnimationEvents) do
        removeEvent(eventId)
    end
    rewardAnimationEvents = {}
    
    -- Fazer fadeout simultâneo de todas as cartas restantes e fadein dos itens
    local rewardsContainer = resultPanel:getChildById('rewardsContainer')
    if rewardsContainer then
        for i, widget in ipairs(rewardsContainer:getChildren()) do
            if widget and not widget:isDestroyed() then
                local cardCover = widget:getChildById('cardCover')
                local itemIcon = widget:getChildById('itemIcon')
                local itemAmount = widget:getChildById('itemAmount')
                if cardCover and not cardCover:isDestroyed() then
                    -- Fazer fadeout da carta e fadein do item simultaneamente
                    local steps = 10
                    local stepDuration = 50 -- 500ms total
                    local currentStep = 0
                    
                    local fadeEvent = nil
                    fadeEvent = cycleEvent(function()
                        currentStep = currentStep + 1
                        if currentStep <= steps then
                            local progress = currentStep / steps
                            -- Carta: opacity 1 -> 0 (linear)
                            if cardCover and not cardCover:isDestroyed() then
                                cardCover:setOpacity(1 - progress)
                            end
                            -- Item: opacity 0 -> 1 (mais lento, usando curva quadrática)
                            local itemProgress = progress * progress
                            if itemIcon and not itemIcon:isDestroyed() then
                                itemIcon:setOpacity(itemProgress)
                            end
                            -- ItemAmount: mesma progressão do item
                            if itemAmount and not itemAmount:isDestroyed() and itemAmount:isVisible() then
                                itemAmount:setOpacity(itemProgress)
                            end
                        else
                            removeEvent(fadeEvent)
                            -- Destruir carta após fadeout completo
                            if cardCover and not cardCover:isDestroyed() then
                                cardCover:destroy()
                            end
                        end
                    end, stepDuration)
                end
            end
        end
    end
    
    -- Esconder botão SKIP e mostrar CLOSE após fadeout completar
    scheduleEvent(function()
        if not resultPanel or resultPanel:isDestroyed() then return end
        
        local skipButton = resultPanel:getChildById('skipButton')
        if skipButton and not skipButton:isDestroyed() then
            skipButton:setVisible(false)
        end
        
        -- Se há fragmentos recebidos E resultPanel está visível, exibir tela de fragmentos
        if currentFragmentsReceived and #currentFragmentsReceived > 0 and resultPanel:isVisible() then
            showFragmentsReceived()
        else
            -- Se não há fragmentos, mostrar botão CLOSE normalmente
            local closeButton = resultPanel:getChildById('closeRewardsButton')
            if closeButton and not closeButton:isDestroyed() then
                closeButton:setVisible(true)
            end
            -- Limpar fragmentos se não foram mostrados
            if currentFragmentsReceived then
                currentFragmentsReceived = nil
            end
        end
    end, 500)
end

-- Fecha o painel de recompensas (envia request ao servidor)
function closeRewardsPanel()
    if not g_game.isOnline() then return end
    
    -- Enviar requisição ao servidor
    g_game.requestGachaCloseRewards()
end

-- Evento chamado pelo C++ quando servidor responde ao close rewards
function onGachaCloseRewardsResponse()
    releaseGachaRewardsState()
    if not gachaWindow then return end
    local resultPanel = gachaWindow.resultPanel
    if resultPanel then
        resultPanel:hide()
        
        -- Limpar itens
        local rewardsContainer = resultPanel:getChildById('rewardsContainer')
        if rewardsContainer then
            rewardsContainer:destroyChildren()
        end
    end
    
    -- Limpar fragmentos recebidos ao fechar rewards
    currentFragmentsReceived = nil
end

-- Evento chamado pelo C++ quando servidor responde ao close fragments
function onGachaCloseFragmentsResponse()
    if not gachaWindow then return end
    local resultPanel = gachaWindow.resultPanel
    if not resultPanel then return end
    
    -- Destruir overlay de fragmentos
    local fragmentsOverlay = resultPanel:getChildById('fragmentsOverlay')
    if fragmentsOverlay and not fragmentsOverlay:isDestroyed() then
        fragmentsOverlay:destroy()
    end
    
    -- Mostrar botão CLOSE após fechar tela de fragmentos
    local closeButton = resultPanel:getChildById('closeRewardsButton')
    if closeButton and not closeButton:isDestroyed() then
        closeButton:setVisible(true)
    end
    
    -- Limpar fragmentos
    currentFragmentsReceived = nil
end

-- Processa resultado da rolagem
function handleRollResult(data)
    isRolling = false
    
    if not gachaWindow then return end
    
    -- Mostra animação de resultado
    local resultPanel = gachaWindow:recursiveGetChildById('resultPanel')
    if resultPanel then
        resultPanel:show()
        
        -- Atualiza item recebid (pode ser chamado via extended opcode JSON separado)o
        local itemLabel = resultPanel:recursiveGetChildById('rewardName')
        if itemLabel then
            itemLabel:setText(data.itemName or tr("Unknown Item"))
        end
        
        local rarityLabel = resultPanel:recursiveGetChildById('rewardRarity')
        if rarityLabel then
            rarityLabel:setText(tr("Rarity: %s", data.rarity or tr("Common")))
        end
    end
end

-- Mostra mensagem de erro
function handleError(message)
    isRolling = false
    
    local errorWindow = displayErrorBox(tr("Gacha - Error"), message or tr("Unknown error"))
end

-- Solicita rolagem do gacha (envia para servidor via extended opcode se necessário)
function requestRoll(type)
    if not g_game.isOnline() or isRolling then return end
    if not currentGachaData then return end
    
    -- Bloquear se painel de rewards estiver aberto
    local resultPanel = gachaWindow and gachaWindow.resultPanel
    if resultPanel and resultPanel:isVisible() then
        return
    end
    
    isRolling = true
    
    -- Aqui você pode usar ExtendedOpcode ou outro método para enviar request ao servidor
    -- Por enquanto, apenas simula localmente
    g_game.requestGachaRoll(type)
    -- Esconde resultado anterior
    if resultPanel then
        resultPanel:hide()
    end
end

-- Solicita lista de gachas disponíveis (implementar comunicação com servidor)
function requestGachaList()
    if not g_game.isOnline() then return end
end

-- Mostra a janela
function show()
    if gachaWindow then
        gachaWindow:show()
        gachaWindow:raise()
        gachaWindow:focus()
    end
end

-- Solicita ao servidor para abrir o gacha
function requestOpenGacha()
    if not g_game.isOnline() then return end
    
    g_game.requestOpenGacha()
end

-- Atualiza os pontos do gacha quando servidor envia update
function onGachaUpdatePoints(gachaPoints)
    if not currentGachaData then return end
    
    -- Atualiza dados locais
    currentGachaData.gachaPoints = gachaPoints
    
    -- Atualiza UI se janela estiver aberta
    if gachaWindow then
        local pointsLabel = gachaWindow:recursiveGetChildById('gachaPoints')
        if pointsLabel then
            pointsLabel:setText(tostring(gachaPoints))
        end
    end
end

-- Atualiza os fragmentos quando servidor envia update
function onGachaUpdateFragments(fragmentCounts)
    if not currentGachaData then 
        return 
    end
    
    if not currentGachaData.fragments then 
        return 
    end
    
    -- Atualiza counts locais
    for i, count in ipairs(fragmentCounts) do
        if currentGachaData.fragments[i] then
            currentGachaData.fragments[i].currentCount = count
        end
    end
    
    -- Atualiza UI se janela estiver aberta
    if not gachaWindow then
        return
    end
    
    local fragmentsPanel = gachaWindow:getChildById('fragmentsPanel')
    if not fragmentsPanel then
        return
    end
    
    local fragmentsContainer = fragmentsPanel:getChildById('fragmentsContainer')
    if not fragmentsContainer then
        return
    end
    
    local widgets = fragmentsContainer:getChildren()
    
    for i, widget in ipairs(widgets) do
        local fragment = currentGachaData.fragments[i]
        if fragment then
            local fragmentProgress = widget:recursiveGetChildById('fragmentProgress')
            local fragmentOutfitMale = widget:recursiveGetChildById('fragmentOutfitMale')
            local fragmentOutfitFemale = widget:recursiveGetChildById('fragmentOutfitFemale')
            
            if fragmentProgress then
                local current = fragment.currentCount or 0
                local required = math.huge
                if fragment.requiredCounts then
                    for _, rc in ipairs(fragment.requiredCounts) do
                        if rc < required then required = rc end
                    end
                end
                if required == math.huge then required = 100 end
                local percentage = math.min(100, math.floor((current / required) * 100))
                local progressText = string.format("%d/%d (%d%%)", current, required, percentage)
                fragmentProgress:setText(progressText)
                
                -- Atualizar barra de progresso visual
                local fullProgress = widget:recursiveGetChildById('fullProgress')
                if fullProgress then
                    local barWidth = 200
                    local clippedWidth = math.max(1, barWidth * (percentage / 100))
                    local rect = { x = 0, y = 0, width = clippedWidth, height = fullProgress:getHeight() }
                    fullProgress:setImageClip(rect)
                    fullProgress:setImageRect(rect)
                end
                
                -- Mudar cor e shader baseado no progresso
                if current >= required then
                    fragmentProgress:setColor('#00ff00') -- Verde se completo
                    -- Adicionar shader aos outfits quando completo
                    if fragmentOutfitMale then
                        local outfit = fragmentOutfitMale:getOutfit()
                        outfit.shader = "premier"
                        fragmentOutfitMale:setOutfit(outfit)
                    end
                    if fragmentOutfitFemale then
                        local outfit = fragmentOutfitFemale:getOutfit()
                        outfit.shader = "premier"
                        fragmentOutfitFemale:setOutfit(outfit)
                    end
                elseif percentage >= 50 then
                    fragmentProgress:setColor('#ffff00') -- Amarelo se >50%
                    -- Remover shader
                    if fragmentOutfitMale then
                        local outfit = fragmentOutfitMale:getOutfit()
                        outfit.shader = ""
                        fragmentOutfitMale:setOutfit(outfit)
                    end
                    if fragmentOutfitFemale then
                        local outfit = fragmentOutfitFemale:getOutfit()
                        outfit.shader = ""
                        fragmentOutfitFemale:setOutfit(outfit)
                    end
                else
                    fragmentProgress:setColor('#ffffff') -- Branco se <50%
                    -- Remover shader
                    if fragmentOutfitMale then
                        local outfit = fragmentOutfitMale:getOutfit()
                        outfit.shader = ""
                        fragmentOutfitMale:setOutfit(outfit)
                    end
                    if fragmentOutfitFemale then
                        local outfit = fragmentOutfitFemale:getOutfit()
                        outfit.shader = ""
                        fragmentOutfitFemale:setOutfit(outfit)
                    end
                end
            end
        end
    end
end

-- Mostra janela de seleção de item (estilo Community Shop)
local fragmentSelectionWindow = nil
local fragmentBuyConfirmWindow = nil
local pendingClaimData = nil

function closeFragmentBuyConfirm()
    if fragmentBuyConfirmWindow then
        fragmentBuyConfirmWindow:destroy()
        fragmentBuyConfirmWindow = nil
    end
    pendingClaimData = nil
end

function closeFragmentSelection()
    closeFragmentBuyConfirm()
    if fragmentSelectionWindow then
        fragmentSelectionWindow:destroy()
        fragmentSelectionWindow = nil
    end
end

function confirmFragmentClaim()
    if not fragmentBuyConfirmWindow or not pendingClaimData then return end
    
    local quantity = fragmentBuyConfirmWindow.confirmSpinner.field:getValue()
    if quantity < 1 then return end
    
    g_game.requestGachaClaimFragment(pendingClaimData.fragmentId, pendingClaimData.itemIndex, quantity)
    closeFragmentBuyConfirm()
end

function openFragmentBuyConfirm(fragmentId, itemIndex, clientId, itemName, requiredCount, currentShards)
    closeFragmentBuyConfirm()
    
    local maxQty = math.floor(currentShards / requiredCount)
    if maxQty < 1 then return end
    if maxQty > 10000 then maxQty = 10000 end
    
    pendingClaimData = {
        fragmentId = fragmentId,
        itemIndex = itemIndex
    }
    
    fragmentBuyConfirmWindow = g_ui.createWidget('FragmentBuyConfirmWindow', gachaWindow)
    if not fragmentBuyConfirmWindow then return end
    
    fragmentBuyConfirmWindow.confirmTitle:setText(itemName)
    
    local item = fragmentBuyConfirmWindow.confirmItem
    if clientId and clientId > 0 then
        item:setItemId(clientId)
    end
    
    local costLabel = fragmentBuyConfirmWindow.confirmCostLabel
    local spinbox = fragmentBuyConfirmWindow.confirmSpinner.field

    local function updateLabels(value)
        item:setItemCount(value)
        costLabel:setText(tr("Cost: %d shards", requiredCount * value))
    end

    spinbox.onValueChange = function(self, value)
        updateLabels(value)
    end
    spinbox:setMinimum(1)
    spinbox:setMaximum(maxQty)
    spinbox:setValue(1)
    updateLabels(1)
    spinbox:focus()
    
    fragmentBuyConfirmWindow:show()
    fragmentBuyConfirmWindow:raise()
    fragmentBuyConfirmWindow:focus()
end

function showFragmentItemSelection()
    if not g_game.isOnline() then return end
    if not currentGachaData or not currentGachaData.fragments then
        return
    end
    
    -- Montar lista plana de todos os itens de todos os fragments
    local allItems = {}
    local currentShards = 0
    for fragId, frag in ipairs(currentGachaData.fragments) do
        currentShards = frag.currentCount or 0
        if frag.clientIds then
            for itemIdx, clientId in ipairs(frag.clientIds) do
                local itemRequired = (frag.requiredCounts and frag.requiredCounts[itemIdx]) or 100
                local itemName = ''
                local itemObj = Item.create(clientId)
                if itemObj then
                    itemName = itemObj:getName()
                end
                table.insert(allItems, {
                    fragmentId = fragId,
                    itemIndex = itemIdx - 1,
                    clientId = clientId,
                    requiredCount = itemRequired,
                })
            end
        end
    end
    
    if #allItems == 0 then return end
    
    -- Fechar janela anterior se existir
    closeFragmentSelection()
    
    -- Carregar janela da shop a partir do OTUI
    fragmentSelectionWindow = g_ui.loadUI('gacha_fragment_shop', gachaWindow)
    if not fragmentSelectionWindow then return end
    
    -- Atualizar label de shards
    fragmentSelectionWindow.shardsLabel:setText(string.format('Shards: %d', currentShards))
    
    local shopPanel = fragmentSelectionWindow.shopItemsPanel
    
    -- Criar item cards
    for _, entry in ipairs(allItems) do
        local canAfford = currentShards >= entry.requiredCount
        
        local widget = g_ui.createWidget('FragmentShopItem', shopPanel)
        
        widget.itemIcon:setItemId(entry.clientId)
        widget.itemName:setText(entry.name)
        widget.itemCost:setText(entry.requiredCount .. ' shards')
        
        if not canAfford then
            widget.itemName:setColor('#666666')
            widget.itemCost:setColor('#ff4444')
        end
        
        if canAfford then
            local fragId = entry.fragmentId
            local itemIdx = entry.itemIndex
            local cid = entry.clientId
            local nm = entry.name
            local req = entry.requiredCount
            local shards = currentShards
            widget.onClick = function()
                openFragmentBuyConfirm(fragId, itemIdx, cid, nm, req, shards)
            end
        end
    end
end

-- Solicita ao servidor para coletar um fragmento
function requestClaimFragment(fragmentId, itemIndex, quantity)
    if not g_game.isOnline() then return end
    quantity = quantity or 1
    g_game.requestGachaClaimFragment(fragmentId, itemIndex, quantity)
end

-- Solicita ao servidor para fechar o gacha (servidor valida se pode fechar)
function requestCloseGacha()
    if not g_game.isOnline() then return end
    
    g_game.requestCloseGacha()
end