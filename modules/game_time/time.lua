---@diagnostic disable: undefined-global
CLOCK_OPCODE = 130
local clockTimeWindow = nil

function init()

  g_ui.loadUI('time')
  --clockTimeTopButton = modules.client_topmenu.addMiddleGameToggleButton('clockTimeTopButton', tr('Clock') .. '', '/images/ui/topbuttons/icons/time', toggle)
  --clockTimeTopButton:setOn(false)
  clockTimeWindow = g_ui.createWidget('ClockTimeWindow', modules.game_interface.getRootPanel())
  clockTimeWindow.onDragLeave = onDragLeave
  clockTimeWindow:setPosition(g_settings.getPoint("poketime-pos") or { x = 35, y = 200})
  ProtocolGame.registerOpcode(CLOCK_OPCODE, getTibiaHour)
  connect(g_game, {
    onGameEnd = offline,
  })
end


function onDragLeave(widget, pos)
  g_settings.set("poketime-pos", widget:getPosition())
  return true
end

function getTibiaHour(opcode, msg)
  local intensity = msg:getU8()
  local color = msg:getU8()
  local minutes = msg:getU32()
  local hours = 0

  local hours = math.floor(minutes / 60)
  local minutes = minutes % 60
  local gameTime = string.format("%02d:%02d", hours, minutes)
  local widget = clockTimeWindow:getChildById("time")
  widget:setText(gameTime)
  local widgetIcon = clockTimeWindow:getChildById("time_icon")
  local icon = nil
  if hours >= 6 and hours < 18 then
    icon = "day"
  else
    icon = "night"
  end
  --widgetIcon:setImageSource("/modules/game_time/images/"..icon..".png")
  --print(gameTime)

  clockTimeWindow:show()

end

function terminate()
  ProtocolGame.unregisterOpcode(CLOCK_OPCODE)
  disconnect(g_game, {
    onGameEnd = offline,
  })

  clockTimeWindow:destroy()
end

function show()
  if not g_game.isOnline() then return end
  if clockTimeWindow then
  clockTimeWindow:setVisible(true)
  end
end

function hide()
  if not g_game.isOnline() then return end
  if clockTimeWindow then
    clockTimeWindow:setVisible(false)
  end
end

function toggle()
  if not g_game.isOnline() then return end
  if not clockTimeWindow then
    return
  end

  local visible = clockTimeWindow:isVisible()
  if visible then
    hide()
  else
    show()
  end
  
end