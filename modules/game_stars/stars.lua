local mainWindow = nil
-- opcode custom 1581 nas duas direções (migrado do extended 204, que não podia ser reusado como
-- número custom porque GameServerImpactTracker = 204 já existe)
local selectedOption = "diamondOption"
local priceConfig
local confirmWindow = nil

local function destroyConfirmWindow()
    if confirmWindow then
        confirmWindow:destroy()
        confirmWindow = nil
    end
end

function onGameEnd()
    hide()
end

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = hide,
        onAutoWalk = hide,
        -- protocolo custom 1581 (parseStarAscension em C++)
        onStarAscensionOpen = onStarAscensionOpen,
        onStarAscensionClose = onStarAscensionClose,
        onStarAscensionSlotUpdate = onStarAscensionSlotUpdate,
        onStarAscensionSlotClear = onStarAscensionSlotClear
    })
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = hide,
        onAutoWalk = hide,
        onStarAscensionOpen = onStarAscensionOpen,
        onStarAscensionClose = onStarAscensionClose,
        onStarAscensionSlotUpdate = onStarAscensionSlotUpdate,
        onStarAscensionSlotClear = onStarAscensionSlotClear
    })
    hide()
end

function hide()
    destroyConfirmWindow()
    if not mainWindow then return end
    mainWindow:destroy()
    mainWindow = nil
    selectedOption = "diamondOption"
    priceConfig = nil
end

-- Custo único (sempre 100% de sucesso): o servidor manda os totais prontos por forma de
-- pagamento (priceConfig[selectedOption] = {diamond, money}) — aqui só espelha no display.
local function refreshCostDisplay()
    if not mainWindow then
        return
    end
    local total = priceConfig and priceConfig[selectedOption]
    local diamond = (total and total.diamond) or 0
    local money = (total and total.money) or 0
    mainWindow.priceBackground.taxDiamondBackground.diamondCost:setText(diamond)
    mainWindow.priceBackground.taxMoneyBackground.moneyCost:setText("$" .. (money > 0 and formatNumberValue(money) or 0))
end

local function resetStarPanel(starPanel, filledStars)
    if not starPanel then
        return
    end
    for i = 1, 5 do
        local widget = starPanel:getChildById("star" .. i)
        if widget then
            local imageSource = (filledStars and i <= filledStars) and "images/yellow_star" or "images/star"
            widget:setImageSource(imageSource)
        end
    end
end

function dropPokeball(widget, item)
    if not mainWindow or not widget then
        return
    end

    local basePokeball = widget:getParent()
    if not basePokeball then
        return
    end

    local pokeballSlot = basePokeball:getParent()
    if not pokeballSlot then
        return
    end

    local mainSlot = pokeballSlot:getId() == "leftPokeballPoke" or false

    -- opcode 1581 (migrado do extended 204).
    -- getPosition() devolve nil quando a posição não é válida; o servidor já abandonava nesse caso
    -- (checagem de payload.info.position), então não mandar dá o mesmo resultado sem gastar pacote.
    local pos = item:getPosition()
    if not pos then
        return
    end

    -- getStackPos() pode devolver -1; o servidor já usava 0 como default (`stackpos or 0`), e o campo
    -- viaja como u8, então clampa aqui em vez de estourar o addU8.
    local stackpos = item:getStackPos()
    if not stackpos or stackpos < 0 then
        stackpos = 0
    end

    g_game.sendStarAscensionSlot(mainSlot, pos, item:getId(), stackpos)
end

-- Eventos do protocolo custom 1581 (parseStarAscension em C++), migrados do extended opcode 204.
function onStarAscensionOpen()
    hide()
    mainWindow = g_ui.loadUI("stars", modules.game_interface.getRootPanel())
end

function onStarAscensionClose()
    hide()
end

function onStarAscensionSlotUpdate(receive)
    do
        if not mainWindow then return end
        destroyConfirmWindow()
        local pokeballBackground = mainWindow.pokemonBackground
        if not pokeballBackground then
            return
        end

        local pokeballWidget = receive.mainSlot and pokeballBackground.leftPokeballPoke or pokeballBackground.rightPokeballPoke
        if not pokeballWidget then
            return
        end

        local pokemonWidget = receive.mainSlot and pokeballBackground.pokemonInfo or pokeballBackground.foodPokemonInfo
        if not pokemonWidget then
            return
        end

        pokemonWidget.pokemonOutfit:setOutfit({type = receive.lookType})

        -- "" no wire == ausente no JSON antigo; setPokeballName() sem argumento é o "limpar" da UI
        local pokeballName = receive.pokeballName
        if pokeballName == "" then pokeballName = nil end
        pokeballWidget.basePokeball.pokeball:setPokeballName(pokeballName)
        pokeballWidget.basePokeball.pokeball:setItemId(receive.clientId)

        resetStarPanel(pokemonWidget.starPanel, receive.pokeballStars)

        if not receive.mainSlot then
            pokeballBackground.newPokemonInfo.pokemonOutfit:setOutfit({type = receive.lookType})
            resetStarPanel(pokeballBackground.newPokemonInfo.starPanel, receive.pokeballStars + 1)
        else
            local secondaryPokeballWidget = pokeballBackground.rightPokeballPoke
            if secondaryPokeballWidget then
                pokeballBackground.foodPokemonInfo.pokemonOutfit:setOutfit({})
                secondaryPokeballWidget.basePokeball.pokeball:setPokeballName()
                secondaryPokeballWidget.basePokeball.pokeball:setItemId(0)
                resetStarPanel(pokeballBackground.foodPokemonInfo.starPanel)
            end

            pokeballBackground.newPokemonInfo.pokemonOutfit:setOutfit({})
            resetStarPanel(pokeballBackground.newPokemonInfo.starPanel)

            -- `price` só vem quando mainSlot; ausente == nil, e refreshCostDisplay já trata nil
            priceConfig = receive.price
            refreshCostDisplay()
        end
    end
end

function onStarAscensionSlotClear(mainSlot)
    do
        if not mainWindow then return end
        destroyConfirmWindow()
        local pokeballBackground = mainWindow.pokemonBackground
        if not pokeballBackground then
            return
        end

        local mainPokeballWidget = pokeballBackground.leftPokeballPoke
        if mainSlot and mainPokeballWidget then
            pokeballBackground.pokemonInfo.pokemonOutfit:setOutfit({})
            mainPokeballWidget.basePokeball.pokeball:setPokeballName()
            mainPokeballWidget.basePokeball.pokeball:setItemId(0)
            resetStarPanel(pokeballBackground.pokemonInfo.starPanel)
        end

        local secondaryPokeballWidget = pokeballBackground.rightPokeballPoke
        if secondaryPokeballWidget then
            pokeballBackground.foodPokemonInfo.pokemonOutfit:setOutfit({})
            secondaryPokeballWidget.basePokeball.pokeball:setPokeballName()
            secondaryPokeballWidget.basePokeball.pokeball:setItemId(0)
            resetStarPanel(pokeballBackground.foodPokemonInfo.starPanel)
        end

        pokeballBackground.newPokemonInfo.pokemonOutfit:setOutfit({})
        resetStarPanel(pokeballBackground.newPokemonInfo.starPanel)

        if mainSlot then
            priceConfig = nil
        end
        refreshCostDisplay()
    end
end

function removePokemonFromSlot(widget)
    if not mainWindow or not widget then
        return
    end

    if widget:getItemId() == 0 then
        return
    end

    local parent = widget:getParent()
    if not parent then
        return
    end

    local topParent = parent:getParent()
    if not topParent then
        return
    end

    local mainSlot = topParent:getId() == "leftPokeballPoke" or false
    g_game.sendStarAscensionRemoveSlot(mainSlot)
end

function selectCashOption(widget)
    if not priceConfig then
        return
    end

    if not mainWindow or not widget then
        return
    end

    local parent = widget:getParent()
    if not parent then
        return
    end

    local childrens = parent:getChildren()
    if childrens then
        for _, children in ipairs(childrens) do
            local imageSource = children == widget and "images/selected_option" or ""
            children:setImageSource(imageSource)
        end
    end

    selectedOption = widget:getId()
    destroyConfirmWindow() -- custo mudou; confirmação aberta ficaria com valor velho
    refreshCostDisplay()
end

function sendConfirmUpgradeStar()
    if not mainWindow then
        return
    end

    -- só confirma com os dois slots preenchidos (o servidor valida de novo)
    local total = priceConfig and priceConfig[selectedOption]
    if not total then
        return
    end

    local secondaryBall = mainWindow.pokemonBackground.rightPokeballPoke.basePokeball.pokeball
    if not secondaryBall or secondaryBall:getItemId() == 0 then
        return
    end

    destroyConfirmWindow()

    local parts = {}
    if (total.diamond or 0) > 0 then
        table.insert(parts, ("%d %s"):format(total.diamond, tr('Diamonds')))
    end
    if (total.money or 0) > 0 then
        table.insert(parts, "$" .. formatNumberValue(total.money))
    end

    local message = tr('Are you sure you want to perform the Star Ascension?') .. '\n'
        .. tr('Cost: %s', table.concat(parts, " + ")) .. '\n'
        .. tr('The secondary Pokémon will be consumed!')

    local function onConfirm()
        destroyConfirmWindow()
        if not mainWindow then
            return
        end

        -- enum no lugar da string do JSON antigo; o servidor remapeia (MONEY_OPTIONS)
        local MONEY_OPTION_IDS = { diamondOption = 1, cashOption = 2, bothOption = 3 }
        g_game.sendStarAscensionUpgrade(MONEY_OPTION_IDS[selectedOption] or 1)
    end

    confirmWindow = displayGeneralBox(tr('Confirm Ascension'), message, {
        { text = tr('Yes'), callback = onConfirm },
        { text = tr('No'), callback = destroyConfirmWindow },
        anchor = AnchorHorizontalCenter
    }, onConfirm, destroyConfirmWindow)
end
