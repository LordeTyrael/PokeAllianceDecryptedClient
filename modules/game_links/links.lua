local GameLinksWindow = nil

function onGameStart()
    if not g_game.isOnline() then
        return
    end

    g_ui.loadUI('links')        
    GameLinksTopButton = modules.client_topmenu.addMiddleGameToggleButton('GameLinksTopButton', tr('Links') .. '', '/images/ui/topbuttons/icons/links', toggle)
    GameLinksTopButton:setOn(false)

    GameLinksWindow = g_ui.createWidget('LinksWindow', modules.game_interface.getRootPanel())
    GameLinksWindow:hide()        
end

function onGameEnd()    
    if GameLinksWindow then
        GameLinksWindow:destroy()
    end    
end

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if g_game.isOnline() then
        onGameStart()
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
end

function toggle()
    if GameLinksTopButton and GameLinksTopButton:isOn() then
        GameLinksTopButton:setOn(false)
        GameLinksWindow:hide()
    else
        GameLinksTopButton:setOn(true)
        GameLinksWindow:show()        
    end
end