local brotherhoodWindow
local brotherhoodWindowData

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = onGameEnd,
        onAutoWalk = onGameEnd,
        onBrotherhoodData = onReceiveBrotherhood
    })
end

function terminate()
    onGameEnd()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = onGameEnd,
        onAutoWalk = onGameEnd,
        onBrotherhoodData = onReceiveBrotherhood
    })
end

function onGameEnd()
    if brotherhoodWindow then
      brotherhoodWindow:destroy()
      brotherhoodWindow = nil
    end
end

function close()
    g_effects.fadeOut(brotherhoodWindow)
    scheduleEvent(function()
        if brotherhoodWindow then
            brotherhoodWindow:destroy()
            brotherhoodWindow = nil
        end
    end, 250)
end

function open()
    if brotherhoodWindow then
        return
    end

    brotherhoodWindow = g_ui.displayUI("brotherhood")
    brotherhoodWindow:focus()
    brotherhoodWindow:show()
    g_effects.fadeIn(brotherhoodWindow)
end

function drawBrotherhoodInfo()
    local layout = brotherhoodWindow:getLayout()
    layout:disableUpdates()

    -- render totalCompleted
    brotherhoodWindow.bottomPanel.totalCompleted.value:setText(brotherhoodWindowData.totalCompleted)

    -- render dailyCompleted
    brotherhoodWindow.bottomPanel.dailyCompleted.value:setText(brotherhoodWindowData.completed)

    -- render contracts
    local contracts = brotherhoodWindowData.contracts
    local completedOptions = brotherhoodWindowData.maxContracts - brotherhoodWindowData.completed

    brotherhoodWindow.contractsList:destroyChildren()

    for i = 1, 6 do
        local contractInfo = contracts[i]
        if contractInfo then
            local contract = g_ui.createWidget("PendingBrotherhoodItem", brotherhoodWindow.contractsList)
            contract.creature:setOutfit({
                type = contractInfo.lookType,
                head = contractInfo.lookHead,
                body = contractInfo.lookBody,
                legs = contractInfo.lookLegs,
                feet = contractInfo.lookFeet,
            })
            contract.title:setText(contractInfo.npcName)
            if contractInfo.isLegendary then
                contract.title:setColor("#c42202")
            else
                contract.title:setColor("#FFCA59")
            end
            contract.description:setText(contractInfo.description)
        elseif i > completedOptions then
            g_ui.createWidget("CompletedBrotherhoodItem", brotherhoodWindow.contractsList)
        else
            g_ui.createWidget("EmptyBrotherhoodItem", brotherhoodWindow.contractsList)
        end
    end

    layout:enableUpdates()
    layout:update()
end

function onReceiveBrotherhood(info)
    brotherhoodWindowData = info

    if not info.update then
        open()
    end

    drawBrotherhoodInfo()
end

function collectNpcContract()
    g_game.brotherhoodCollectContract()
end
