ui = nil
updateEvent = nil

function init()
    ui = g_ui.loadUI('stats', modules.game_interface.getMapPanel())
    ui.fps:hide()
    ui.ping:hide()

    print("init")

    connect(g_game, { onGameStart = onGameStart })
    connect(g_game, { onGameEnd = onGameEnd })
  
    updateEvent = scheduleEvent(update, 200)
end

function onGameStart()
  if modules.client_options.getOption("showPing") then
    ui.showPing:show()
  end

  if modules.client_options.getOption("showFps") then
    ui.fps:show()
  end
end

function onGameEnd()
  ui.fps:hide()
  ui.ping:hide()
end

function terminate()
  removeEvent(updateEvent)
end

function update()
  updateEvent = scheduleEvent(update, 500)
  if ui:isHidden() then return end

  text = 'FPS: ' .. g_app.getFps()
  ui.fps:setText(text)

  local ping = g_game.getPing()
  if g_proxy and g_proxy.getPing() > 0 then
    ping = g_proxy.getPing()
  end
  
  local text = 'Ping: '
  local color
  if ping < 0 then
    text = text .. "??"
    color = 'yellow'
  else
    text = text .. ping .. ' ms'
    if ping >= 500 then
      color = 'red'
    elseif ping >= 250 then
      color = 'yellow'
    else
      color = 'green'
    end
  end
  ui.ping:setText(text)
  ui.ping:setColor(color)
end

function show()
  ui:setVisible(true)
end

function hide()
  ui:setVisible(false)
end