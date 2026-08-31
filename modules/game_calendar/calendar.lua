local calendarWindow = nil
local calendarPanel = nil
local calendarButton
local calendarFreeInfo = nil
local calendarType = nil
local calendarUnlockWindow = nil
local calendarCollectWindow = nil
local calendarPrice = 0
local unlockedPremium = false
local progress = {
    free = 0,
    premium = 0
}
local collectedToday = {
    free = false,
    premium = false
}
local day = 0

function init()
    connect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = hidecalendarWindow,
        onAutoWalk = hidecalendarWindow,
        onCalendarData = onCalendarData,
        onCalendarUpdateDays = onCalendarUpdateDays,
        onCalendarUnlockedPremium = onCalendarUnlockedPremium,
        onCalendarShow = onCalendarShow,
    })
    calendarWindow = g_ui.loadUI('calendar', modules.game_interface.getRootPanel())
    calendarButton = modules.client_topmenu.addMiddleGameToggleButton('calendarButton', tr('Calendar'),
        '/images/ui/topbuttons/icons/calendar', toggle)
    calendarPanel = calendarWindow:getChildById("calendarPanel")
    calendarWindow:hide()
    for slot = 1, 21 do
        local calendarItem = g_ui.createWidget("ItemCel", calendarWindow:getChildById("calendarRewards"))
        calendarItem:setId(slot)
        calendarItem.celItem:setVirtual(true)
    end
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onWalk = hidecalendarWindow,
        onAutoWalk = hidecalendarWindow,
        onCalendarData = onCalendarData,
        onCalendarUpdateDays = onCalendarUpdateDays,
        onCalendarUnlockedPremium = onCalendarUnlockedPremium,
        onCalendarShow = onCalendarShow,
    })

    if calendarWindow then
        calendarWindow:destroy()
    end
end

function onGameEnd()
    hidecalendarWindow()
    calendarFreeInfo = nil
    calendarType = nil
    unlockedPremium = false
    progress = {
        free = 0,
        premium = 0
    }
    collectedToday = {
        free = false,
        premium = false
    }
    day = 0
end

function onCalendarData(freeItems, premiumItems, price, freeProgress, premiumProgress, unlocked, currentDay,
                       collectedFreeToday, collectedPremiumToday)
    calendarFreeInfo = {
        free = freeItems,
        premium = premiumItems
    }
    calendarPrice = price or 0
    unlockedPremium = unlocked or false
    progress["free"] = freeProgress or 0
    progress["premium"] = premiumProgress or 0
    collectedToday["free"] = collectedFreeToday == true
    collectedToday["premium"] = collectedPremiumToday == true
    day = currentDay or 0
    showCalendarInfo("free")
end

function onCalendarUpdateDays(freeProgress, premiumProgress, collectedFreeToday, collectedPremiumToday)
    progress["free"] = freeProgress or 0
    progress["premium"] = premiumProgress or 0
    if collectedFreeToday ~= nil then
        collectedToday["free"] = collectedFreeToday == true
    end
    if collectedPremiumToday ~= nil then
        collectedToday["premium"] = collectedPremiumToday == true
    end
    showCalendarInfo(calendarType, true)
end

function onCalendarUnlockedPremium()
    unlockPremiumCalendar()
end

function onCalendarShow(calendarInfoType)
    if calendarButton then
        calendarButton:setOn(true)
    end
    opencalendarWindow()
    showCalendarInfo(calendarInfoType, true)
end

-- Premium keeps a claim available for every day already passed: collecting again the
-- same day is allowed, it just costs Online Points. Free is one per day, full stop.
local function willChargeOnlinePoints()
    return calendarType == "premium"
        and unlockedPremium
        and collectedToday["premium"]
        and progress["premium"] < day
end

local function canClaim()
    if calendarType == "premium" then
        return unlockedPremium and (not collectedToday["premium"] or progress["premium"] < day)
    end
    return not collectedToday["free"]
end

function showCalendarInfo(type, forceUpdate)
    if not forceUpdate and calendarType and calendarType == type then
        return
    end
    calendarType = type
    local index = 1
    for _, item in ipairs(calendarFreeInfo[type]) do
        if index > 21 then
            calendarWindow.calendarAdittionalRewardItem:setItemId(item.itemId)
            calendarWindow.calendarAdittionalRewardItem:setItemCount(item.count)
            calendarWindow.calendarAdittionalRewardItem:setShowCount(false)
            calendarWindow.calendarAdittionalRewards:setText(tr("After claiming reward #21, you'll get %dx %s every day until next month.", item.count, item.itemName))
            break
        end
        local calendarItem = calendarWindow.calendarRewards:getChildById(index)
        if calendarItem then
            calendarItem.celText:setText(index)
            local text = item.itemName
            if item.unique then
                text = text..". It's a unique item."
            end
            local opacity = 1.0
            local tooltip = text
            if index <= progress[type] then
                opacity = 0.5
                text = ""
            end

            if item.lookType and item.lookType > 0 then
                calendarItem.celItem:hide()
                calendarItem.celOutfit:show()
                calendarItem.celOutfit:setOutfit({type = item.lookType})
                calendarItem.celOutfit:setTooltip(text)
            else
                calendarItem.celOutfit:hide()
                calendarItem.celItem:show()
                calendarItem.celItem:setItemId(item.itemId)
                calendarItem.celItem:setItemCount(item.count)
                calendarItem.celItem:setOpacity(opacity)
                calendarItem.celItem:setTooltip(text)
            end
        end
        index = index + 1
    end

    if type == "premium" then
        if not unlockedPremium then
            calendarWindow.blockCalendarRewards:show()
            calendarWindow.cadeadoBlockCalendarRewards:show()
        end
    else
        calendarWindow.blockCalendarRewards:hide()
        calendarWindow.cadeadoBlockCalendarRewards:hide()
    end

    -- Note label, em cascata de prioridade: cobrança de 100 OP, lembrete do reset
    -- mensal (antes da compra, para o jogador saber), motivo do Claim desabilitado.
    local opWarning = calendarWindow:getChildById('opCostWarning')
    if opWarning then
        if willChargeOnlinePoints() then
            opWarning:setText(tr("Note: claiming today will cost 100 Online Points (delayed reward)."))
            opWarning:setColor("#f5b342")
            opWarning:setVisible(true)
        elseif type == "premium" and not unlockedPremium then
            opWarning:setText(tr("Note: the Premium Calendar resets on the 1st of next month. You'll need to repurchase it every month to keep collecting Premium rewards."))
            opWarning:setColor("#e8c05e")
            opWarning:setVisible(true)
        elseif not canClaim() then
            opWarning:setText(tr("You already claimed today's reward. Come back tomorrow."))
            opWarning:setColor("#8fb7d6")
            opWarning:setVisible(true)
        else
            opWarning:setVisible(false)
        end
    end

    updateClaimButton()
end

function unlockPremiumCalendar()
    calendarWindow.blockCalendarRewards:hide()
    calendarWindow.cadeadoBlockCalendarRewards:hide()
    unlockedPremium = true
    -- Refresh pra atualizar o note (passa a mostrar o lembrete de reset mensal)
    if calendarType then
        showCalendarInfo(calendarType, true)
    end
end

function hidecalendarWindow()
    if calendarButton then
        calendarButton:setOn(false)
    end
    if calendarWindow then
        calendarWindow:hide()
    end

    buyPremiumCleanup()
    callendarCollectCleanup()
end

function toggle()
    if not calendarFreeInfo then
        return
    end
    if calendarButton and calendarButton:isOn() then
        hidecalendarWindow()
    else
        calendarButton:setOn(true)
        opencalendarWindow()
    end
end

function opencalendarWindow()
    g_effects.fadeIn(calendarWindow)
    --calendarWindow:show()
    calendarWindow:setVisible(true)
    calendarWindow:focus()
end

function updateClaimButton()
    if calendarWindow and calendarWindow.claim then
        calendarWindow.claim:setEnabled(canClaim())
    end
end

function collectReward()
    if calendarCollectWindow then
        return
    end
    local player = g_game.getLocalPlayer()
    if not player then return end

    local text
    if willChargeOnlinePoints() then
        text = tr("Are you sure you want to claim this reward for %s?\nSince you already collected today, this delayed reward will cost 100 Online Points.",
            player:getName())
    else
        text = tr("Are you sure you want to claim this reward for %s?", player:getName())
    end

    calendarCollectWindow = displayAllianceBox(tr('Claim'), text, {
        {
            text = tr('Yes'),
            callback = callendarCollectConfirm
        },
        {
            text = tr('No'),
            callback = callendarCollectCleanup
        },
        anchor = AnchorHorizontalCenter
    }, callendarCollectConfirm, callendarCollectCleanup)
end

function callendarCollectConfirm()
    g_game.collectCalendar(calendarType)
    callendarCollectCleanup()
end

function callendarCollectCleanup()
    if calendarCollectWindow then
        calendarCollectWindow:destroy()
        calendarCollectWindow = nil
    end
end

function buyPremiumCalendar()
    if calendarUnlockWindow then
        return
    end
    calendarUnlockWindow = displayGeneralBox(tr('Confirm Purchase'), tr('Are you sure you want to buy Premium Calendar to your Account by %d Diamonds? NOTE: This calendar only works in the current month. A new purchase will be necessary next month.', calendarPrice), {
        {
            text = tr('Yes'),
            callback = buyPremiumConfirm
        },
        {
            text = tr('No'),
            callback = buyPremiumCleanup
        },
        anchor = AnchorHorizontalCenter
    }, buyPremiumConfirm, buyPremiumCleanup)
end

function buyPremiumCleanup()
    if calendarUnlockWindow then
        calendarUnlockWindow:destroy()
        calendarUnlockWindow = nil
    end
end

function buyPremiumConfirm()
    g_game.buyPremiumCalendar()
    buyPremiumCleanup()
end