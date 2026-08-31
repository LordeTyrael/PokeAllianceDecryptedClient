MessageSettings = {
  none            = {},
  consoleRed      = { color = TextColors.red,    consoleTab='Default' },
  consoleOrange   = { color = TextColors.orange, consoleTab='Default' },
  consoleBlue     = { color = TextColors.blue,   consoleTab='Default' },
  centerRed       = { color = TextColors.red,    consoleTab='Server Log', screenTarget='lowCenterLabel' },
  centerGreen     = { color = TextColors.green,  consoleTab='Server Log', screenTarget='highCenterLabel',   consoleOption='showInfoMessagesInConsole' },
  centerWhite     = { color = TextColors.white,  consoleTab='Server Log', screenTarget='middleCenterLabel', consoleOption='showEventMessagesInConsole' },
  bottomWhite     = { color = TextColors.white,  consoleTab='Server Log', screenTarget='statusLabel',       consoleOption='showEventMessagesInConsole' },
  status          = { color = TextColors.white,  consoleTab='Server Log', screenTarget='statusLabel',       consoleOption='showStatusMessagesInConsole' },
  statusSmall     = { color = TextColors.white,                           screenTarget='statusLabel' },
  private         = { color = TextColors.lightblue,                       screenTarget='privateLabel' },
  loot            = { color = TextColors.white,  consoleTab='Loot', coloredMessage = true},
}

MessageTypes = {
  [MessageModes.MonsterSay] = MessageSettings.consoleOrange,
  [MessageModes.MonsterYell] = MessageSettings.consoleOrange,
  [MessageModes.BarkLow] = MessageSettings.consoleOrange,
  [MessageModes.BarkLoud] = MessageSettings.consoleOrange,
  [MessageModes.Failure] = MessageSettings.statusSmall,
  [MessageModes.Login] = MessageSettings.bottomWhite,
  [MessageModes.Game] = MessageSettings.centerWhite,
  [MessageModes.Status] = MessageSettings.status,
  [MessageModes.Warning] = MessageSettings.centerRed,
  [MessageModes.Look] = MessageSettings.centerGreen,
  [MessageModes.Loot] = MessageSettings.centerGreen,
  [MessageModes.Red] = MessageSettings.consoleRed,
  [MessageModes.Blue] = MessageSettings.consoleBlue,
  [MessageModes.PrivateFrom] = MessageSettings.consoleBlue,
  [MessageModes.ServerBroadcast] = MessageSettings.serverMessages,

  [MessageModes.DamageDealed] = MessageSettings.status,
  [MessageModes.DamageReceived] = MessageSettings.status,
  [MessageModes.Heal] = MessageSettings.status,
  [MessageModes.Exp] = MessageSettings.status,

  [MessageModes.DamageOthers] = MessageSettings.none,
  [MessageModes.HealOthers] = MessageSettings.none,
  [MessageModes.ExpOthers] = MessageSettings.none,

  [MessageModes.TradeNpc] = MessageSettings.centerWhite,
  [MessageModes.Guild] = MessageSettings.centerWhite,
  [MessageModes.PartyManagement] = MessageSettings.centerWhite,
  [MessageModes.TutorialHint] = MessageSettings.centerWhite,
  [MessageModes.Market] = MessageSettings.centerWhite,
  [MessageModes.BeyondLast] = MessageSettings.centerWhite,
  [MessageModes.Report] = MessageSettings.consoleRed,
  [MessageModes.HotkeyUse] = MessageSettings.centerGreen,
  [MessageModes.Loot] = MessageSettings.loot,

  [254] = MessageSettings.private
}

messagesPanel = nil
local broadcastWidget = nil
local broadcastUpdateWaitEvent = nil

local CENTER_MESSAGE_GAP = 8
local centerPlacementEvent = nil

-- Anchors cannot be used here: the action bar changes parent between the map panel and the bottom
-- strip, so it is not always a sibling of this panel. The chat preview solves the same problem the
-- same way (see applyDefaultPreviewPosition in game_chat).
local function placeCenterMessages()
  if not messagesPanel then return true end
  local panel = messagesPanel:recursiveGetChildById('statusLabel')
  local mapPanel = modules.game_interface.getMapPanel()
  if not panel or not mapPanel then return true end

  local mapBottom = mapPanel:getY() + mapPanel:getHeight()
  local actionBar = modules.game_interface.getRootPanel():recursiveGetChildById('playerActionBar')
  local onGameScreen = actionBar and actionBar:isVisible() and actionBar:getHeight() > 0
    and actionBar:getY() < mapBottom

  if onGameScreen then
    panel:setMarginBottom(math.max(0, mapBottom - actionBar:getY()) + CENTER_MESSAGE_GAP)
  else
    panel:setMarginBottom(CENTER_MESSAGE_GAP)
  end
  return true
end

function refreshCenterMessagePlacement()
  removeEvent(centerPlacementEvent)
  centerPlacementEvent = addEvent(function()
    centerPlacementEvent = nil
    placeCenterMessages()
  end)
end

function init()
  connect(g_game, 'onTextMessage', displayMessage)
  connect(g_game, 'onGameEnd', clearMessages)
  messagesPanel = g_ui.loadUI('textmessage', modules.game_interface.getRootPanel())
  broadcastWidget = g_ui.loadUI('broadcast', modules.game_interface.getRootPanel())
  broadcastWidget:hide()

  local mapPanel = modules.game_interface.getMapPanel()
  if mapPanel then connect(mapPanel, { onGeometryChange = refreshCenterMessagePlacement }) end
  refreshCenterMessagePlacement()
end

function terminate()
  disconnect(g_game, 'onTextMessage', displayMessage)
  disconnect(g_game, 'onGameEnd',clearMessages)
  clearMessages()
  messagesPanel:destroy()
end

function calculateVisibleTime(text)
  return math.max(#text * 100, 4000)
end

local function updateWait(timeStart, timeEnd)
    if broadcastWidget then
        local time = g_clock.seconds()
        if time <= timeEnd then
          local percent = ((time - timeStart) / (timeEnd - timeStart)) * 100    
          local progressBar = broadcastWidget.progressBar
          progressBar:setPercent(percent)    
          broadcastUpdateWaitEvent = scheduleEvent(function() updateWait(timeStart, timeEnd) end, 1000 * progressBar:getPercentPixels() / 100 * (timeEnd - timeStart))
          return true
        end
    end

    if broadcastUpdateWaitEvent then
        broadcastUpdateWaitEvent:cancel()
        broadcastUpdateWaitEvent = nil
    end
end

function confirmWarning()
    if not broadcastWidget then
        return
    end

    if broadcastUpdateWaitEvent then
        broadcastUpdateWaitEvent:cancel()
        broadcastUpdateWaitEvent = nil
    end

    g_effects.fadeOut(broadcastWidget)
    scheduleEvent(function()
        if broadcastWidget then
            broadcastWidget:hide()
        end
    end, 1000)
end

function showAlertsBroadcast(text)
    if modules.client_options.getOption("hideTipsMessages") then
        return
    end
    if text:len() == 0 then
      return
    end
    if not broadcastWidget then
        return
    end

    if broadcastUpdateWaitEvent then
        broadcastUpdateWaitEvent:cancel()
        broadcastUpdateWaitEvent = nil
    end

    broadcastWidget.centerTextMessagePanel:setText(text)
    g_effects.fadeIn(broadcastWidget)
    local parentWidget = modules.game_interface.getRootPanel()
    parentWidget:moveChildToIndex(broadcastWidget, parentWidget:getChildCount())
    broadcastWidget:show()
    scheduleEvent(function()
        if broadcastWidget then
            g_effects.fadeOut(broadcastWidget)
        end
    end, 9000)
    scheduleEvent(function()
        if broadcastWidget then
            broadcastWidget:hide()
        end
    end, 10000)
    updateWaitEvent = scheduleEvent(function() updateWait(g_clock.seconds(), g_clock.seconds() + 9) end, 0)
end

function displayMessage(mode, text)
  if not g_game.isOnline() then return end
  if mode == MessageModes.ServerBroadcast then
    showAlertsBroadcast(text)
    return
  end
  local msgtype = MessageTypes[mode]

  if not msgtype then
    --perror('unhandled onTextMessage message mode ' .. mode .. ': ' .. text)
    return
  end

  if msgtype == MessageSettings.none then return end

  if msgtype.consoleTab ~= nil and (msgtype.consoleOption == nil or modules.client_options.getOption(msgtype.consoleOption)) then
    modules.game_chat.addText(text, msgtype, tr(msgtype.consoleTab))
    --TODO move to game_chat
  end

  if msgtype.screenTarget then
    if string.find(text, '12//,') or string.find(text, '12|,') or string.find(text, 'p#,') or string.find(text, '12&,') or string.find(text, '#ph#,') or string.find(text, '%Naddon') then
    return     --alterado!
    end   
    local label = messagesPanel:recursiveGetChildById(msgtype.screenTarget)
    local setColoredText = false
    if msgtype.coloredMessage then
      local coloredText = modules.game_chat.getPkaColoredText(text, msgtype.color)
      if #coloredText > 0 then
        label:setColoredText(coloredText)
        setColoredText = true
      end
    end    

    if not setColoredText then
      label:setText(text)
      label:setColor(msgtype.color)
    end
    label:setVisible(true)
    removeEvent(label.hideEvent)
    label.hideEvent = scheduleEvent(function() label:setVisible(false) end, calculateVisibleTime(text))
  end
end

function getTextCollors(text, color, highlightColor)
  local tmpData = {}

  for i, part in ipairs(text:split("{")) do
    if i == 1 then
      table.insert(tmpData, part)
      table.insert(tmpData, color)
    else
      for j, part2 in ipairs(part:split("}")) do
        if j == 1 then
          table.insert(tmpData, part2)
          table.insert(tmpData, highlightColor)
        else
          table.insert(tmpData, part2)
          table.insert(tmpData, color)
        end
      end
    end
  end

  return tmpData
end

function displayPrivateMessage(text)
  displayMessage(254, text)
end

function displayStatusMessage(text)
  displayMessage(MessageModes.Status, text)
end

function displayFailureMessage(text)
  displayMessage(MessageModes.Failure, text)
end

function displayGameMessage(text)
  displayMessage(MessageModes.Game, text)
end

function displayBroadcastMessage(text)
  displayMessage(MessageModes.Warning, text)
end

function clearMessages()
  for _i,child in pairs(messagesPanel:recursiveGetChildren()) do
    if child:getId():match('Label') then
      child:hide()
      removeEvent(child.hideEvent)
    end
  end

    if broadcastUpdateWaitEvent then
        broadcastUpdateWaitEvent:cancel()
        broadcastUpdateWaitEvent = nil
    end
    if broadcastWidget then
        broadcastWidget:hide()
    end
end

function LocalPlayer:onAutoWalkFail(player)
  modules.game_textmessage.displayFailureMessage(tr('There is no way.'))
end