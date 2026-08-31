function init()
    -- onClientImage: protocolo custom 1576 (parseClientImage em C++), migrado do extended opcode 14
    connect(g_game, { onGameEnd = onGameEnd, onClientImage = onClientImage })
    imageWindow = g_ui.displayUI('images')
    imageWindow:hide()
end

function terminate()
    disconnect(g_game, { onGameEnd = onGameEnd, onClientImage = onClientImage })
    imageWindow:destroy()
end

function onGameEnd()
    if imageWindow:isVisible() then
      imageWindow:hide()
    end
end

function onClientImage(imageName)
    show(imageName)
end

function show(imagePath)
    if not imageWindow:isVisible() then
      addEvent(function() g_effects.fadeIn(imageWindow) end)
    end
    imageWindow:setImageSource("/game_images/images/"..imagePath)
    imageWindow:show()
    g_effects.fadeIn(imageWindow)
    scheduleEvent(function() imageWindow:hide() end, 5000)
end

function hide()
  addEvent(function() g_effects.fadeOut(imageWindow) end)
  scheduleEvent(function() imageWindow:hide() end, 250)
end