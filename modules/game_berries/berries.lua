local berriesWindow = nil
local berriesPanel = nil

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = onGameEnd,
        onAutoWalk = onGameEnd,
        -- protocolo custom 1578 (parseBerryTooltip em C++), migrado do extended opcode 156
        onBerryTooltip = openBerriesTooltip
    })
    berriesWindow = g_ui.loadUI('berries', modules.game_interface.getRootPanel())
    berriesPanel = berriesWindow:getChildById("berriesPanel")
    berriesWindow:hide()
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onAutoWalk = onGameEnd,
        onBerryTooltip = openBerriesTooltip
    })
    if berriesWindow then
        berriesWindow:destroy()
    end
end

function onGameEnd()
    resetCountdown()
    if berriesWindow then
      berriesWindow:hide()
    end
end

function openBerriesTooltip(clientId, leftTime, totalDuration, phase, totalPhase)
    resetCountdown()
    berriesPanel.item:setItemId(clientId)
    berriesPanel.item:setImageOffsetX(7)
    berriesPanel.item:setImageOffsetY(7)
    berriesWindow:show()
    berriesWindow:focus()
    berriesPanel.progress.leftTime = leftTime
    berriesPanel.progress.totalDuration = totalDuration
    berriesPanel.progress:setText(phase .. "/" .. totalPhase)
    if leftTime > 0 then
        startCooldown()
    end
end

function resetCountdown()
    removeEvent(berriesPanel.progress.cooldownEvent)
    berriesPanel.progress.cooldownEvent = nil
end

function startCooldown()
    updateCooldown(true)
    berriesPanel.progress.cooldownEvent = cycleEvent(function()
        updateCooldown()
    end, 1000)
end

function updateCooldown(start)
    if not berriesPanel or not berriesPanel.progress then
        return
    end

    local progress = berriesPanel.progress

    if not progress:isVisible() then
        progress:show()
    end

    if progress.leftTime - 1 == 0 then
        resetCountdown()
        progress:setText("")
        progress:hide()
        return
    end

    if progress then
        if not start then
            progress.leftTime = progress.leftTime - 1
        end
        progress:setPercent(100 - (progress.leftTime * 100 / progress.totalDuration))
    end
end