local rewardWindow

function init()
    connect(g_game, {
        onGameStart = hideMainWindow,
        onGameEnd = hideMainWindow,
        onWalk = hideMainWindow,
        onAutoWalk = hideMainWindow,
        onGenericRewardInfo = onReceiveRewardInfo,
    })
end

function terminate()
    disconnect(g_game, {
        onGameStart = hideMainWindow,
        onGameEnd = hideMainWindow,
        onWalk = hideMainWindow,
        onAutoWalk = hideMainWindow,
        onGenericRewardInfo = onReceiveRewardInfo,
    })
end

function hideMainWindow()
    if rewardWindow then
        rewardWindow:destroy()
        rewardWindow = nil
    end
end

function onReceiveRewardInfo(rewardInfo)
    hideMainWindow()

    rewardWindow = g_ui.loadUI("rewards", modules.game_interface.getRootPanel())
    rewardWindow.background.rewardTitle:setText(rewardInfo.rewardName)
    rewardWindow.background.rewardImage:setImageSource("images/"..rewardInfo.rewardName:lower())

    local rewardPanel = rewardWindow.background.rewardPanel
    if rewardInfo.experience and rewardInfo.experience > 0 then
        local reward = g_ui.createWidget('InfoCompleteBase', rewardPanel)
        reward:setImageSource("/images/playerBuffs/experience")
        reward.experienceCount:setVisible(true)
        reward.experienceCount:setText(formatNumberValue(rewardInfo.experience))
    end

    for _, rewardItem in ipairs(rewardInfo.items) do
        local reward = g_ui.createWidget('InfoCompleteBase', rewardPanel)
        reward.completedOption:setItemId(rewardItem.id)
        reward.completedOption:setItemCount(rewardItem.count)
    end

    addEvent(function()
        g_effects.fadeIn(rewardWindow)
    end)
end