local memoryWindow = nil
local confirmationWidget = nil
local excludeMemoryWidget = nil
local maxSlots = 6

function init()
    memoryWindow = g_ui.loadUI('memory', modules.game_interface.getRootPanel())
    connect(g_game, {
        onGameEnd               = memoryHide,
        onDittoMemoryInterface  = onDittoMemoryInterface,
        onDittoMemorySlotUpdate = onDittoMemorySlotUpdate,
        onDittoMemoryPrice      = onDittoMemoryPrice,
        onDittoMemoryLookType   = onDittoMemoryLookType,
    })
    for i = 1, maxSlots do
        local creatureWidget = g_ui.createWidget("PokemonSlot", memoryWindow.creaturePanel)
        creatureWidget.memoryIndex = i
        creatureWidget.onClick = function(self)
            if not self.closeButton:isVisible() then
                sendSaveMemory(self)
            else
                sendLoadPokemon(self)
            end
        end
    end

    memoryWindow:hide()
end

function onDittoMemoryInterface(iface)
    local pokemonNames, lookTypes = {}, {}
    for _, slot in ipairs(iface.slots) do
        table.insert(pokemonNames, slot.pokemonName)
        table.insert(lookTypes, slot.lookType)
    end
    drawMemoryWindow(#iface.slots, pokemonNames, lookTypes, iface.copyLookType)
end

function onDittoMemorySlotUpdate(update)
    updateMemoryWindowSlot(update.index, update.pokemonName, update.lookType)
end

function onDittoMemoryPrice(payload)
    showConfirmationWindowPrice(payload.price)
end

function onDittoMemoryLookType(lookType)
    if memoryWindow then
        memoryWindow.dittoCopy:setOutfit({ type = lookType })
    end
end

function drawMemoryWindow(slots, pokemonNames, lookTypes, copyLookType)
    memoryWindow.topBar.dittoOutfit:setOutfit({type = 635})
    memoryWindow.dittoCopy:setOutfit({type = copyLookType})
    local creatureSlots = memoryWindow.creaturePanel:getChildren()

    for i = 1, maxSlots do
        local slotWidget = creatureSlots[i]
        if slotWidget then
            if i <= slots then
                slotWidget:show()
                slotWidget.fundoPago:hide()
                if pokemonNames[i] and pokemonNames[i] ~= "" then
                    slotWidget.closeButton:show()
                    slotWidget.pokemon:setOutfit({type = lookTypes[i]})
                    slotWidget.pokemon:setImageSource()
                    slotWidget.pokemonName = pokemonNames[i]

                    if slotWidget.pokemonNameLabel then
                        slotWidget.pokemonNameLabel:setText(pokemonNames[i])
                    end
                else
                    slotWidget.closeButton:hide()
                    slotWidget.pokemon:setImageSource("/images/newui/default")
                    slotWidget.pokemon:setOutfit({})
                end
            else
                slotWidget.pokemon:setOutfit({type = lookTypes[i]})
                slotWidget.pokemon:setImageSource()
                slotWidget.fundoPago:show()

            end
        end
    end

    -- Se houver somente 1 slot desbloqueado, exibe a widget que indica a compra de mais slots
    if slots == 1 then
        if memoryWindow.buySlotWidget then
            memoryWindow.buySlotWidget:show()
        end
    else
        if memoryWindow.buySlotWidget then
            memoryWindow.buySlotWidget:hide()
        end
    end

    memoryWindow:show()
    memoryWindow:focus()
end

function terminate()
    disconnect(g_game, {
        onGameEnd               = memoryHide,
        onDittoMemoryInterface  = onDittoMemoryInterface,
        onDittoMemorySlotUpdate = onDittoMemorySlotUpdate,
        onDittoMemoryPrice      = onDittoMemoryPrice,
        onDittoMemoryLookType   = onDittoMemoryLookType,
    })
end

function show()

end

function memoryHide()
    memoryWindow:hide()
    hideConfirmationWindow()
    hideExcludeMemoryWidget()
end

function requestOpenMemory()
    g_game.dittoMemoryRequest()
end

function updateMemoryWindowSlot(index, pokemonName, lookType)
    local creatureSlots = memoryWindow.creaturePanel:getChildren()
    local slotWidget = creatureSlots[index]
    if slotWidget then
        slotWidget.pokemonName = pokemonName

        if lookType > 0 then
            slotWidget.pokemon:setOutfit({type = lookType})
            slotWidget.pokemon:setImageSource()
            slotWidget.closeButton:show()
        else
            slotWidget.pokemon:setOutfit({})
            slotWidget.pokemon:setImageSource("/images/newui/default")
            slotWidget.closeButton:hide()
        end
    end
end


function sendSaveMemory(widget)
    if not widget or not widget.memoryIndex then
        return
    end
    g_game.dittoMemorySaveSlot(widget.memoryIndex)
end

function confirmExcludeMemory()
    if not excludeMemoryWidget or not excludeMemoryWidget.memoryIndex then
        return
    end
    g_game.dittoMemoryRemoveSlot(excludeMemoryWidget.memoryIndex)
    hideExcludeMemoryWidget()
end

function excludeMemory(widget)
    if excludeMemoryWidget or not widget then
        return
    end

    local parent = widget:getParent()
    if not parent then
        return
    end

    excludeMemoryWidget = g_ui.createWidget("ExcludeMemoryWidget", memoryWindow)
    excludeMemoryWidget.memoryIndex = parent.memoryIndex
    excludeMemoryWidget.textMessage:setText(tr("Do you really want to remove a\n%s\nfrom your Ditto Memory?", tostring(parent.pokemonName)))
end

function sendLoadPokemon(widget)
    if not widget or not widget.memoryIndex then
        return
    end
    g_game.dittoMemoryCopySlot(widget.memoryIndex)
end

function sendUnlockMemorySlot(confirmation)
    g_game.dittoMemoryUnlockSlot(confirmation and true or false)
    hideConfirmationWindow()
end

function showConfirmationWindowPrice(price)
    if confirmationWidget or not memoryWindow then
        return
    end

    confirmationWidget = g_ui.createWidget("ConfirmationWidget", memoryWindow)
    confirmationWidget.diamondIcon:setItemCount(price)
    confirmationWidget.textMessage:setText(tr("Do you really want to unlock a Memory Slot on your Ditto for\n%d Diamonds?", price))
    confirmationWidget:show()
end

function hideConfirmationWindow()
    if confirmationWidget then
        confirmationWidget:destroy()
        confirmationWidget = nil
    end
end

function hideExcludeMemoryWidget()
    if excludeMemoryWidget then
        excludeMemoryWidget:destroy()
        excludeMemoryWidget = nil
    end
end