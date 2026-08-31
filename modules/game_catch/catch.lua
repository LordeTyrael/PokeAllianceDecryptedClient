function init()
  -- onCatchWindow: protocolo custom 1577 (parseCatchWindow em C++), migrado do extended opcode 70
  connect(g_game, { onGameEnd = onGameEnd, onCatchWindow = onCatchWindow })

  catchWindow = g_ui.displayUI('catch')
  catchWindow:hide()
end

function terminate()
  disconnect(g_game, { onGameEnd = onGameEnd, onCatchWindow = onCatchWindow })

  catchWindow:destroy()
end

function onGameEnd()
  if catchWindow:isVisible() then
    catchWindow:hide()
  end
end

-- O campo "protocol" do JSON antigo era só um discriminador dentro do opcode 70; com opcode
-- dedicado ele não existe mais e a checagem sai junto.
function onCatchWindow(pokemonName, experience, lookType, shiny)
  show(pokemonName, experience, lookType, shiny)
end

function show(pokemonName, experience, lookType, isShiny)
  if not catchWindow:isVisible() then
    addEvent(function() g_effects.fadeIn(catchWindow) end)
  end
  catchWindow:getChildById('looktype'):setOutfit({type = lookType})
  if experience > 0 then
    catchWindow:getChildById('text'):setText(tr(string.format('Congratulations, you caught a %s!\nXP: %s', pokemonName, experience)))
  else
    catchWindow:getChildById('text'):setText(tr(string.format('Congratulations, you caught a %s!', pokemonName)))
  end
  catchWindow:show()
  catchWindow:setVisible(true)
  g_effects.fadeIn(catchWindow)

  scheduleEvent(function() g_effects.fadeOut(catchWindow) end, 3000)
  scheduleEvent(function() catchWindow:hide() end, 3500)
end

function hide()
  addEvent(function() g_effects.fadeOut(catchWindow) end)
  scheduleEvent(function() catchWindow:hide() end, 250)
end
