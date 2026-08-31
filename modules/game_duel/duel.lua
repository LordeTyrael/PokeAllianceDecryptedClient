local duelManagementWindow = nil
local duelCreationWindow = nil
local duelCreated = false
local maxPokeballs = 6
local selectedPokeballs = 6
local leaderCreatureId = nil
local participantList = {}
local duelsInvitesList = {}
local duelsInvitedList = {}
local mainWindow = nil
local updateEvent = nil
local duelTopButton

function init()
  connect(g_game, {
    onGameEnd = onGameEnd,
    onGameStart = onGameStart,
    onDuelCreate = onDuelCreate,
    onDuelEnd = onDuelEnd,
    onDuelLeader = onDuelLeader,
    onDuelPokeballsChange = onDuelPokeballsChange,
    onDuelParticipantsChange = onDuelParticipantsChange,
    onDuelInvitedPlayersChange = onDuelInvitedPlayersChange,
    onDuelReceiveInvitesList = onDuelReceiveInvitesList,
    onDuelAccept = onDuelAccept
  })
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onGameEnd,
    onGameStart = onGameStart,
    onDuelCreate = onDuelCreate,
    onDuelEnd = onDuelEnd,
    onDuelLeader = onDuelLeader,
    onDuelPokeballsChange = onDuelPokeballsChange,
    onDuelParticipantsChange = onDuelParticipantsChange,
    onDuelInvitedPlayersChange = onDuelInvitedPlayersChange,
    onDuelReceiveInvitesList = onDuelReceiveInvitesList,
    onDuelAccept = onDuelAccept
  })
end

function onGameEnd()
  if mainWindow then
      mainWindow:destroy()
      mainWindow = nil
  end
  participantList = {}
  duelsInvitesList = {}
  duelsInvitedList = {}
  duelCreated = false
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end

  if duelTopButton then
    duelTopButton:destroy()
    duelTopButton = nil
  end
end

function onGameStart()
  duelTopButton = modules.client_topmenu.addMiddleGameToggleButton('duelTopButton', tr('Duel') .. '', '/images/ui/topbuttons/icons/duel', toggle)
end

function toggle()
  if not duelTopButton then
    return
  end

  if not mainWindow then
    show()
    duelTopButton:setOn(true)
    return
  end

  hide()
  duelTopButton:setOn(false)
end

function show()
  if mainWindow then
    mainWindow:destroy()
    mainWindow = nil
  end

  local windowName = 'duel_create'
  if duelCreated then
      windowName = 'duel_management'
  end
  mainWindow = g_ui.displayUI(windowName)
  mainWindow:show()
  mainWindow:raise()
  mainWindow:focus()
  addEvent(function()
    if mainWindow and mainWindow.centralPanel then
      local visible = false
      if isLeader() then
        mainWindow.centralPanel.cancelButton:setText(tr("Cancel"))
        visible = true
      end
      mainWindow.centralPanel.startButton:setVisible(visible)
      mainWindow.centralPanel.inviteButton:setVisible(visible)
    end

    onDuelInvitedPlayersChange(duelsInvitedList)
    onDuelReceiveInvitesList(duelsInvitesList)
    onDuelParticipantsChange(participantList)
    renderPokeballs()
    g_effects.fadeIn(mainWindow)
  end)
end

function hide()
  if not mainWindow then
    return
  end

  addEvent(function() g_effects.fadeOut(mainWindow) end)
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end
  updateEvent = scheduleEvent(function()
    mainWindow:destroy()
    mainWindow = nil
  end, 250)
end

function renderPokeballs()
  if not mainWindow then
    return
  end

  local pokeballs = mainWindow:recursiveGetChildById('pokeballs')
  if not pokeballs then
    return
  end
  local layout = pokeballs:getLayout();
  layout:disableUpdates()
  pokeballs:destroyChildren()
  for i = 1, maxPokeballs do
    local pokeball = g_ui.createWidget('PokeballButton', pokeballs)
    if isLeader() then
      pokeball.onClick = function (self)
        selectedPokeballs = i
        renderPokeballs()
        g_game.duelSetPokeballs(selectedPokeballs)
      end
    end

    pokeball:setId('pokeball' .. i)
    if i <= selectedPokeballs then
      pokeball:setOn(true)
    else
      pokeball:setOn(false)
    end
  end

  layout:enableUpdates()
  layout:update()
end

function create()
  if duelCreated then
    return
  end

  if not mainWindow then
    return
  end

  g_game.duelCreate(maxPokeballs);
end

function invite(playerName)
  if not duelCreated then
    return
  end

  if not mainWindow then
    return
  end

  g_game.duelInvite(playerName);
end

function switchTeam(playerName)
  if not duelCreated then
    return
  end

  if not mainWindow then
    return
  end

  g_game.duelSwitchTeam(playerName);
end

function join(creature)
  if not duelCreated then
    return
  end

  if not mainWindow then
    return
  end

  g_game.duelAccept(creature:getId());
end

function leave()
  if not duelCreated then
    return
  end

  if not mainWindow then
    return
  end

  g_game.duelLeave();
end

function cancel()
  if not duelCreated then
    return
  end

  if not mainWindow then
    return
  end

  g_game.duelCancel();
end

-- opcodes

function onDuelCreate(pokeballs)
  duelCreated = true

  if not mainWindow then
    return
  end

  addEvent(function() g_effects.fadeOut(mainWindow) end)
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end

  updateEvent = scheduleEvent(function()
    if mainWindow and mainWindow:getId() ~= 'duelManagementWindow' then
      mainWindow:destroy()
      mainWindow = nil
      mainWindow = g_ui.displayUI('duel_management')
    end

    if not mainWindow then
      return
    end
    mainWindow:raise()
    mainWindow:focus()
    if mainWindow and mainWindow.centralPanel then
      local visible = false
      if isLeader() then
        mainWindow.centralPanel.cancelButton:setText(tr("Cancel"))
        visible = true
      end
      mainWindow.centralPanel.startButton:setVisible(visible)
      mainWindow.centralPanel.inviteButton:setVisible(visible)
    end

    onDuelParticipantsChange(participantList)
    addEvent(function() g_effects.fadeIn(mainWindow) end)
  end, 250)

  renderPokeballs()
end

function onDuelEnd()
  if not mainWindow then
    return
  end

  addEvent(function() g_effects.fadeOut(mainWindow) end)
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end

  updateEvent = scheduleEvent(function()
    mainWindow:destroy()
    mainWindow = nil
  end, 250)
  
  duelCreated = false
end

function onDuelPokeballsChange(pokeballs)
  selectedPokeballs = pokeballs
  if mainWindow then
    local pokeballs = mainWindow:recursiveGetChildById('pokeballs')
    if not pokeballs then
      return
    end
    if mainWindow:isVisible() then
      local layout = pokeballs:getLayout();
      layout:disableUpdates()
      pokeballs:destroyChildren()
      for i = 1, maxPokeballs do
        local pokeball = g_ui.createWidget('PokeballButton', pokeballs)
        if isLeader() then
          pokeball.onClick = function (self)
            selectedPokeballs = i
            renderPokeballs()
            g_game.duelSetPokeballs(selectedPokeballs)
          end
        end
    
        pokeball:setId('pokeball' .. i)
        if i <= selectedPokeballs then
          pokeball:setOn(true)
        else
          pokeball:setOn(false)
        end
      end
    
      layout:enableUpdates()
      layout:update()
    end
  end
end

function onDuelParticipantsChange(participants)
  participantList = participants
  if not mainWindow or not mainWindow.firstPanel or not mainWindow.secondPanel then
    return
  end

  local firstTeamPanel = mainWindow.firstPanel.firstTeam
  local secondTeamPanel = mainWindow.secondPanel.secondTeam

  local firstLayout = firstTeamPanel:getLayout()
  local secondLayout = secondTeamPanel:getLayout()

  firstLayout:disableUpdates()
  secondLayout:disableUpdates()

  firstTeamPanel:destroyChildren()
  secondTeamPanel:destroyChildren()

  for _, participantInfo in ipairs(participants) do
    local teamWindow = participantInfo.teamNumber == 1 and firstTeamPanel or secondTeamPanel
    if teamWindow then
      local widget = g_ui.createWidget('PlayerListWidget', teamWindow)
      widget.playerName:setText(participantInfo.participantName)
      widget.description:setText(tr("Member"))
      widget.switchButton:setVisible(isLeader())
      widget.kickButton:setVisible(isLeader())
      if isLeader() then
        widget.switchButton.onClick = function ()
          g_game.duelSwitch(participantInfo.participantName)
        end
        widget.kickButton.onClick = function ()
          g_game.duelKick(participantInfo.participantName)
        end
      end
    end
  end

  firstLayout:enableUpdates()
  firstLayout:update()

  secondLayout:enableUpdates()
  secondLayout:update()
end

function onDuelInvitedPlayersChange(inviteList)
    duelsInvitedList = inviteList
    if not mainWindow or not mainWindow.centralPanel then
      return
    end

    local invitePanel = mainWindow.centralPanel.invitedPanel.pendingInvites
    if not invitePanel then
      return
    end

    local layout = invitePanel:getLayout()
    layout:disableUpdates()
    invitePanel:destroyChildren()

    for _, playerName in ipairs(duelsInvitedList) do
      local widget = g_ui.createWidget('InvitedItemWidget', invitePanel)
      widget.playerName:setText(playerName)
    end

    layout:enableUpdates()
    layout:update()
end

function onDuelReceiveInvitesList(inviteList)
    duelsInvitesList = inviteList
    if not mainWindow or not mainWindow.inviteList_background then
      return
    end

    local invitePanel = mainWindow.inviteList_background.invitePanel
    if not invitePanel then
      return
    end

    local layout = invitePanel:getLayout()
    layout:disableUpdates()
    invitePanel:destroyChildren()

    for _, playerName in ipairs(duelsInvitesList) do
      local widget = g_ui.createWidget('InviteItemWidget', invitePanel)
      widget.playerName:setText(playerName)
      widget.acceptButton.onClick = function ()
        g_game.duelJoin(playerName)
      end
      widget.rejectButton.onClick = function ()
        g_game.duelReject(playerName)
      end
    end

    layout:enableUpdates()
    layout:update()
end

function onDuelAccept()
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end

  updateEvent = scheduleEvent(function()
    if mainWindow and mainWindow:getId() ~= 'duelManagementWindow' then
      mainWindow:destroy()
      mainWindow = nil
    end

    if not mainWindow then
      mainWindow = g_ui.displayUI('duel_management')
    end
  
    --mainWindow:raise()
    mainWindow:focus()
  
    local visible = false
    if isLeader() then
      mainWindow.centralPanel.cancelButton:setText(tr("Cancel"))
      visible = true
    end
    mainWindow.centralPanel.startButton:setVisible(visible)
    mainWindow.centralPanel.inviteButton:setVisible(visible)
  
    onDuelParticipantsChange(participantList)
    onDuelPokeballsChange(selectedPokeballs)
    renderPokeballs()
  end, 300)
end

function onDuelLeader(leaderCid)
  leaderCreatureId = leaderCid
end

function isLeader()
  if not leaderCreatureId then
    return false
  end

  local player = g_game.getLocalPlayer()
  if not player then
    return false
  end

  return player:getId() == leaderCreatureId
end

function showInvitePanel()
  local chatModeEnabled = modules.game_chat.consoleToggleChat
  if chatModeEnabled then
      modules.game_walking.disableClientWalk()
  end

  if not mainWindow then
    return
  end

  if mainWindow.invitePanel then
    mainWindow.invitePanel:show()
    g_effects.fadeIn(mainWindow.invitePanel)

    if mainWindow.invitePanel.searchItemEdit then
      connect(mainWindow.invitePanel.searchItemEdit, {
        onKeyPress = inviteHandleKeyPress
      })
    end
  end
end

function hideInvitePanel()
  local chatModeEnabled = modules.game_chat.consoleToggleChat
  if chatModeEnabled then
      modules.game_walking.enableClientWalk()
  end

  if not mainWindow then
    return
  end

  if mainWindow.invitePanel then
    if mainWindow.invitePanel.searchItemEdit then
      disconnect(mainWindow.invitePanel.searchItemEdit, {
        onKeyPress = inviteHandleKeyPress
      })
    end

    addEvent(function() g_effects.fadeOut(mainWindow.invitePanel) end)
    scheduleEvent(function()
      if mainWindow and mainWindow.invitePanel then
        mainWindow.invitePanel.searchItemEdit:setText("")
        mainWindow.invitePanel:hide()
      end
    end, 250)
  end
end

function confirmInvite()
  if not mainWindow or not mainWindow.invitePanel then
    return
  end

  local playerName = mainWindow.invitePanel.searchItemEdit:getText()
  if not playerName then
    return
  end

  g_game.duelInvite(playerName)
  hideInvitePanel()
end

function inviteHandleKeyPress(self, keyCode)
  if keyCode == KeyEnter then
    confirmInvite()    
  end
end