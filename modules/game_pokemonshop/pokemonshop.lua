local pokemonShopWindow = nil
local maxPokeballs = 6
local sellPokemonConfirm = nil
local lastRenderedRoster = nil

local function snapshotRoster(pokeballs)
    local snap = {}
    for i = 1, maxPokeballs do
        local p = pokeballs and pokeballs[i]
        snap[i] = p and { name = p.name, boost = p.boost, price = p.price } or false
    end
    return snap
end

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = onGameEnd,
        onAutoWalk = onGameEnd,
        onPokemonShopOpen = onPokemonShopOpen,
        onPokemonShopSellReply = onPokemonShopSellReply
    })
    pokemonShopWindow = g_ui.loadUI("pokemonshop", modules.game_interface.getRootPanel())
    pokemonShopWindow:hide()
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = onGameEnd,
        onAutoWalk = onGameEnd,
        onPokemonShopOpen = onPokemonShopOpen,
        onPokemonShopSellReply = onPokemonShopSellReply
    })
    if pokemonShopWindow then
        if pokemonShopWindow.event then
            removeEvent(pokemonShopWindow.event)
        end
        pokemonShopWindow:destroy()
    end
end

function onGameEnd()
    lastRenderedRoster = nil
    hide()
end

function onPokemonShopOpen()
    show()
end

function onPokemonShopSellReply(success, errors)
    handleSellPokemon({ success = success, errors = errors })
end

function show(disableFade)
    if not pokemonShopWindow or not pokemonShopWindow.pokemons then
        return
    end
    if disableFade and not pokemonShopWindow:isVisible() then
        return
    end
    local pokeballs = modules.game_pokebar.getPlayerPokeballs()
    if disableFade and lastRenderedRoster and table.equal(lastRenderedRoster, snapshotRoster(pokeballs)) then
        return
    end
    local layout = pokemonShopWindow.pokemons:getLayout()
    if layout then
        layout:disableUpdates()
    end
    pokemonShopWindow.pokemons:destroyChildren()
    if pokeballs then
        local lastValidChild = nil
        for i = 1, maxPokeballs do
            local widget = g_ui.createWidget("PokemonWidget", pokemonShopWindow.pokemons)
            widget.pokemonIndex = i
            local pokeball = pokeballs[i]
            if pokeball then
                local dexNumber = g_pokemonCyclopedia.getDexNumber(pokeball.name:lower())
                if dexNumber ~= "" then
                    local pokemonImage = widget.portraitClip.pokemonImage
                    pokemonImage:setImageSource("/images/pokemons/" .. dexNumber)
                    pokemonImage:setImageClip({x = 10, y = 10, width = 120, height = 120})
                else
                    widget.portraitClip.pokemonImage:setImageSource("")
                end
                widget.pokemonInformations.pokemonName:setText(pokeball.name)
                widget.pokemonInformations.pokemonBoost:setText(tr("Boost: +%s", pokeball.boost))
                widget.pokemonSellPrice = pokeball.price
                widget.pokemonBoostValue = pokeball.boost

                if pokeball.price > 0 then
                    widget.pokemonInformations.priceContainer:show()
                    widget.pokemonInformations.priceContainer.priceLabel:setText(comma_value2(pokeball.price))
                    widget.cartButton:show()
                    widget.pokemonInformations.unsellableContainer:hide()
                    widget.cartButton.onClick = function()
                        pokemonShopWindow.pokemons:focusChild(widget)
                        sellPokemonConfirmation(pokemonShopWindow)
                    end
                else
                    widget.pokemonInformations.priceContainer:hide()
                    widget.cartButton:hide()
                    widget.pokemonInformations.unsellableContainer:show()
                    widget.pokemonInformations.pokemonName:setColor("#FFCA59")
                    widget.pokemonInformations.pokemonBoost:setColor("#FFCA59")
                end
                lastValidChild = widget
            else
                widget:setOpacity(0.4)
                widget:setFocusable(false)
                widget.cartButton:hide()
                widget.pokemonInformations.unsellableContainer:hide()
                widget.pokemonInformations.priceContainer:hide()
                widget.pokemonInformations.pokemonName:setText("")
                widget.pokemonInformations.pokemonBoost:setText("")
                widget.portraitClip.pokemonImage:setImageSource("")
            end
        end
        if lastValidChild then
            pokemonShopWindow.pokemons:focusChild(lastValidChild)
        end
    end
    local localPlayer = g_game.getLocalPlayer()
    local bankBalance = localPlayer and localPlayer:getBankBalance() or 0
    pokemonShopWindow.bottomBar.balanceLabel:setText(comma_value2(bankBalance))
    if layout then
        layout:enableUpdates()
        layout:update()
    end
    lastRenderedRoster = snapshotRoster(pokeballs)
    if not disableFade then
        pokemonShopWindow:setOpacity(1)
        pokemonShopWindow:show()
        pokemonShopWindow:focus()
    end
end

function hide()
    pokemonShopWindow:hide()
end

function passSellPokemonConfirm(self)
    if not sellPokemonConfirm then
        return
    end

    local pokemonName = sellPokemonConfirm.pokemonName
    local index = sellPokemonConfirm.sellIndex
    g_game.requestSellPokemon(pokemonName, index)
end

function handleSellPokemon(data)
    if data.success then
        sellPokemonCleanup()
        return
    end

    local errorBox = displayErrorBox(tr("Error"), data.errors[1])
    errorBox.onOk = function()
        errorBox = nil
        sellPokemonCleanup()
    end
end

function sellPokemonCleanup()
    if sellPokemonConfirm then
        sellPokemonConfirm:destroy()
    end
    sellPokemonConfirm = nil
    lastRenderedRoster = nil
end

function sellPokemonConfirmation(widget)
    if sellPokemonConfirm then
        return
    end

    local pokemonWidget = widget.pokemons
    if not pokemonWidget then
        return
    end

    local sellIndex = 0
    local pokemonName = ""
    local pokemonBoost = ""
    local pokemonSellPrice = 0
    for _, child in pairs(pokemonWidget:getChildren()) do
        if child:isFocused() then
            sellIndex = child.pokemonIndex
            pokemonName = child.pokemonInformations.pokemonName:getText()
            pokemonBoost = child.pokemonBoostValue
            pokemonSellPrice = child.pokemonSellPrice
            if not pokemonSellPrice or pokemonSellPrice <= 0 then
                displayInfoBox(tr("Unsellable Pokemon"), tr("You can't sell this Pokemon"))
                return
            end
        end
    end

    if sellIndex <= 0 or sellIndex > maxPokeballs or pokemonName:len() <= 0 then
        displayInfoBox(tr("Unsellable Pokemon"), tr("You need to select a Pokemon"))
        return
    end

    sellPokemonConfirm = displayAllianceBox(tr('Confirm Sell Pokemon'), tr('Do you really want to sell your %s +%s for %s?', pokemonName, pokemonBoost, comma_value2(pokemonSellPrice)), {
        {
            text = tr('Yes'),
            callback = passSellPokemonConfirm
        },
        {
            text = tr('No'),
            callback = sellPokemonCleanup
        },
        anchor = AnchorHorizontalCenter
    }, passSellPokemonConfirm, sellPokemonCleanup)

    sellPokemonConfirm.pokemonName = pokemonName
    sellPokemonConfirm.sellIndex = sellIndex
end