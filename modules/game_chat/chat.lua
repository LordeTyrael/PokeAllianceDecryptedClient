SpeakTypesSettings = {
  none = {},
  say = { speakType = MessageModes.Say, color = '#FFFF00' },
  whisper = { speakType = MessageModes.Whisper, color = '#FFFF00' },
  yell = { speakType = MessageModes.Yell, color = '#FFFF00' },
  broadcast = { speakType = MessageModes.GamemasterBroadcast, color = '#F55E5E' },
  private = { speakType = MessageModes.PrivateTo, color = '#5FF7F7', private = true },
  privateRed = { speakType = MessageModes.GamemasterTo, color = '#F55E5E', private = true },
  privatePlayerToPlayer = { speakType = MessageModes.PrivateTo, color = '#9F9DFD', private = true },
  privatePlayerToNpc = { speakType = MessageModes.NpcTo, color = '#9F9DFD', private = true, npcChat = true },
  privateNpcToPlayer = { speakType = MessageModes.NpcFrom, color = '#5FF7F7', private = true, npcChat = true },
  channelYellow = { speakType = MessageModes.Channel, color = '#FFFF00' },
  channelWhite = { speakType = MessageModes.ChannelManagement, color = '#FFFFFF' },
  channelRed = { speakType = MessageModes.GamemasterChannel, color = '#F55E5E' },
  channelOrange = { speakType = MessageModes.ChannelHighlight, color = '#F6A731' },
  monsterSay = { speakType = MessageModes.MonsterSay, color = '#FE6500', hideInConsole = true},
  monsterYell = { speakType = MessageModes.MonsterYell, color = '#FE6500', hideInConsole = true},
  rvrAnswerFrom = { speakType = MessageModes.RVRAnswer, color = '#FE6500' },
  rvrAnswerTo = { speakType = MessageModes.RVRAnswer, color = '#FE6500' },
  rvrContinue = { speakType = MessageModes.RVRContinue, color = '#FFFF00' },
}

SpeakTypes = {
  [MessageModes.Say] = SpeakTypesSettings.say,
  [MessageModes.Whisper] = SpeakTypesSettings.whisper,
  [MessageModes.Yell] = SpeakTypesSettings.yell,
  [MessageModes.GamemasterBroadcast] = SpeakTypesSettings.broadcast,
  [MessageModes.PrivateFrom] = SpeakTypesSettings.private,
  [MessageModes.GamemasterPrivateFrom] = SpeakTypesSettings.privateRed,
  [MessageModes.NpcTo] = SpeakTypesSettings.privatePlayerToNpc,
  [MessageModes.NpcFrom] = SpeakTypesSettings.privateNpcToPlayer,
  [MessageModes.Channel] = SpeakTypesSettings.channelYellow,
  [MessageModes.ChannelManagement] = SpeakTypesSettings.channelWhite,
  [MessageModes.GamemasterChannel] = SpeakTypesSettings.channelRed,
  [MessageModes.ChannelHighlight] = SpeakTypesSettings.channelOrange,
  [MessageModes.MonsterSay] = SpeakTypesSettings.monsterSay,
  [MessageModes.MonsterYell] = SpeakTypesSettings.monsterYell,
  [MessageModes.RVRChannel] = SpeakTypesSettings.channelWhite,
  [MessageModes.RVRContinue] = SpeakTypesSettings.rvrContinue,
  [MessageModes.RVRAnswer] = SpeakTypesSettings.rvrAnswerFrom,
  [MessageModes.NpcFromStartBlock] = SpeakTypesSettings.privateNpcToPlayer,

  -- ignored types
  [MessageModes.Spell] = SpeakTypesSettings.none,
  [MessageModes.BarkLow] = SpeakTypesSettings.none,
  [MessageModes.BarkLoud] = SpeakTypesSettings.none,
}

SayModes = {
  [1] = { speakTypeDesc = 'whisper', icon = '/images/game/console/whisper' },
  [2] = { speakTypeDesc = 'say', icon = '/images/game/console/say' },
  [3] = { speakTypeDesc = 'yell', icon = '/images/game/console/yell' }
}

ChannelEventFormats = {
  [ChannelEvent.Join] = '%s joined the channel.',
  [ChannelEvent.Leave] = '%s left the channel.',
  [ChannelEvent.Invite] = '%s has been invited to the channel.',
  [ChannelEvent.Exclude] = '%s has been removed from the channel.',
}

MAX_HISTORY = 500
MAX_LINES = 100
HELP_CHANNEL = 9
TIME_CLEAR_TEXT = 10000

chatWindow = nil
contentPanel = nil
consoleTabBar = nil
textEdit = nil
channels = nil
channelsWindow = nil
communicationWindow = nil
ownPrivateName = nil
messageHistory = {}
currentMessageIndex = 0
ignoreNpcMessages = false
defaultTab = nil
serverTab = nil
lootTab = nil
violationsChannelId = nil
violationWindow = nil
violationReportTab = nil
chatLocked = false
ignoredChannels = {}
filters = {}
isOnline = false
oldPos = {}
pendingMessages = {}
local pendingMessagesEvent = nil
consoleToggleChat = true
local chatActive = false
local chatPreviewPanel = nil
local previewDragMode = false
local previewShiftPoll = nil
local previewDefaultPlacementEvent = nil
local previewDragHint = nil
local previewMutedTabs = {}

local function updatePreviewMutedIcon(tab)
  local muted = previewMutedTabs[tab:getText()] == true
  local icon = tab:getChildById('previewMutedIcon')
  if icon then icon:setVisible(muted) end
  -- the eye is parked in the right padding strip, 2px off the label; pull the label away from it
  tab:setTextOffset({ x = muted and -8 or 0, y = 0 })
end

local function isPreviewMutable(tab)
  return tab ~= nil and tab ~= defaultTab and tab ~= serverTab
end

local function isPreviewMuted(tab)
  return tab ~= nil and previewMutedTabs[tab:getText()] == true
end

local function savePreviewMutedTabs()
  local char = g_game.getCharacterName()
  if not char or char == '' then return end
  local node = g_settings.getNode('chatPreviewMutedTabs') or {}
  local names = {}
  for name in pairs(previewMutedTabs) do names[#names + 1] = name end
  table.sort(names)
  if #names > 0 then node[char] = names else node[char] = nil end
  g_settings.setNode('chatPreviewMutedTabs', node)
  g_settings.save()
end

local function setPreviewMuted(tab, muted)
  if not isPreviewMutable(tab) then return end
  previewMutedTabs[tab:getText()] = muted or nil
  updatePreviewMutedIcon(tab)
  savePreviewMutedTabs()
end

local function loadPreviewMutedTabs()
  previewMutedTabs = {}
  local char = g_game.getCharacterName()
  if not char or char == '' then return end
  local node = g_settings.getNode('chatPreviewMutedTabs')
  local names = node and node[char]
  if not names then return end
  -- pairs, not ipairs: g_settings writes an array as tag-keyed OTML nodes ("1: Loot") because
  -- lua_isstring accepts numeric keys, so it reads back keyed by the *string* "1" and ipairs would
  -- iterate nothing. tostring guards a purely numeric channel name coming back as a number.
  for _, name in pairs(names) do previewMutedTabs[tostring(name)] = true end
  for name in pairs(previewMutedTabs) do
    local tab = getTab(name)
    if tab then updatePreviewMutedIcon(tab) end
  end
end

local function stripColorMarkup(text)
  local n
  repeat
    text, n = text:gsub("{([^,{}]+),%s*#%x+}", "%1")
  until n == 0
  return text
end

local communicationSettings = {
  useIgnoreList = true,
  useWhiteList = true,
  privateMessages = false,
  yelling = false,
  allowVIPs = false,
  ignoredPlayers = {},
  whitelistedPlayers = {}
}

local options = {
	["backgroundAlwaysVisible"] = false,
	["classicChat"] = false,
	["chatAlwaysActive"] = false,
}

local boundKeys = {
  chatEnabled = {},
  chatDisabled = {}
}

local boundKeysUI = {
  chatEnabled = {},
  chatDisabled = {}
}

modules.client_hotkeys.registerHotkeyCallback("NEXT_CHAT",
  function(actionName, action, keyInfo, chatState, keyType)
    -- Gate por estado do chat com FALLBACK (2026-08-28): a mesma tecla pode estar configurada
    -- nos DOIS estados (chatEnabled e chatDisabled) e ambos os binds ficam ativos -- sem gate,
    -- um toque avancava 2 canais (regressao exposta quando o othersProfile virou KeyDown fixo;
    -- antes o bind de chatEnabled era KeyPress e nao disparava no toque). Era o UNICO callback
    -- do others sem gate. O gate simples (padrao CLOSE_CHAT/AUTO_LOOT/SWITCH_TARGET) quebraria
    -- quem so tem tecla num estado (o default de fabrica define so chatDisabled): este callback
    -- so cede a vez quando o estado do MODO ATUAL tem tecla propria para assumir a acao.
    local callback = function()
      local chatModeEnabled = not consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if wantChat ~= chatModeEnabled then
        local currentState = chatModeEnabled and "chatEnabled" or "chatDisabled"
        local stateKeys = action.keys[currentState]
        local currentStateHasKey = stateKeys and (
          (stateKeys.primaryKey and stateKeys.primaryKey.key ~= "")
          or (stateKeys.secondaryKey and stateKeys.secondaryKey.key ~= "")
          or (stateKeys.tertiaryKey and stateKeys.tertiaryKey.key ~= ""))
        if currentStateHasKey then
          return
        end
      end
      if consoleTabBar then
        consoleTabBar:selectNextTab()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

modules.client_hotkeys.registerHotkeyCallback("CLOSE_CHAT",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        removeCurrentTab()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

modules.client_hotkeys.registerHotkeyCallback("REPORT_RULE_VIOLATION",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      openPlayerReportRuleViolationWindow()
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

function init()
	connect(g_game, {
		onTalk = onTalk,
		onChannelList = onChannelList,
		onOpenChannel = onOpenChannel,
		onOpenPrivateChannel = onOpenPrivateChannel,
		onOpenOwnPrivateChannel = onOpenOwnPrivateChannel,
		onCloseChannel = onCloseChannel,
		onRuleViolationChannel = onRuleViolationChannel,
		onRuleViolationRemove = onRuleViolationRemove,
		onRuleViolationCancel = onRuleViolationCancel,
		onRuleViolationLock = onRuleViolationLock,

		onGameEnd = onGameEnd,
		onGameStart = onGameStart,
	})
  connect(g_client, {
    onTrainerClose = focusChatChannel
  })
	chatWindow = g_ui.loadUI('chat', modules.game_interface.getRootPanel())
	configWindow = g_ui.loadUI('config', modules.game_interface.getRootPanel())
	allchat = g_ui.loadUI('allchat', modules.game_interface.getRootPanel())

	allchatPanel = allchat.consoleBuffer
  allchat:fill('chat')

	textEdit = chatWindow.textEdit
	contentPanel = chatWindow.contentPanel
	
	consoleTabBar = chatWindow.consoleTabBar
	consoleTabBar:setContentWidget(contentPanel)
	consoleTabBar:setTabSpacing(3)
	
	chatTextLineWindow = chatWindow.textLineWindow
	chatEnterBackground = chatWindow.enterBackground

	chatWindow.onGeometryChange = function(self)
		chatTextLineWindow:setHeight(self:getHeight()-75)
		chatTextLineWindow:setWidth(self:getWidth()-47)
		chatEnterBackground:setWidth(self:getWidth()-36)
    local classic = g_settings.getBoolean("classicView") and not g_app.isMobile()
    if not classic then
      g_settings.set('chat_size', chatWindow:getSize())
      if isOnline then
        g_settings.set('chat_x', chatWindow:getX())
        g_settings.set('chat_y', chatWindow:getY())
      end
    end
	end
	chatWindow.rB:setMaximum(1000)
	chatWindow.rB:setMinimum(245)
	chatWindow.rB2:setMaximum(600)
	chatWindow.rB2:setMinimum(140)
	chatWindow.rB3.inverted = true
	chatWindow.rB3:setMaximum(600)
	chatWindow.rB3:setMinimum(140)
	chatWindow.rB4.inverted = true
	chatWindow.rB4:setMaximum(1000)
	chatWindow.rB4:setMinimum(245)

  local function saveChatGeometry()
    local classic = g_settings.getBoolean("classicView") and not g_app.isMobile()
    if classic or not isOnline then return end
    g_settings.set('chat_size', chatWindow:getSize())
    g_settings.set('chat_x', chatWindow:getX())
    g_settings.set('chat_y', chatWindow:getY())
    g_settings.save()
  end

  for _, borderId in ipairs({ 'rB', 'rB2', 'rB3', 'rB4' }) do
    local border = chatWindow[borderId]
    local baseOnMouseRelease = border.onMouseRelease
    border.onMouseRelease = function(self, mousePos, mouseButton)
      local handled = baseOnMouseRelease and baseOnMouseRelease(self, mousePos, mouseButton)
      saveChatGeometry()
      return handled
    end
  end

  chatWindow.onDragLeave = function(widget)
    if not chatWindow then return true end
    saveChatGeometry()
    return true
  end
	
  chatWindow.closeChannelButton.tooltip = tr("Close this channel").." (Ctrl + E)"
  chatWindow.clearChannelButton.tooltip = tr("Clear current message window")
  chatWindow.channelsButton.tooltip = tr("Open new channel").." (Ctrl+O)"
  chatWindow.ignoreButton.tooltip = tr("Ignore players")
  chatWindow.lockButton.tooltip = tr("Block move Chat Window")
  -- chatWindow.sayModeButton.tooltip = tr("Adjust volume")

	hide()

	channels = {}

	chatWindow.onKeyPress = function(self, keyCode, keyboardModifiers)
    if keyCode == KeyEscape and not g_settings.getBoolean('classicView') and isActive() then
      toggleChat()
      return true
    end
		if not (keyboardModifiers == KeyboardCtrlModifier and keyCode == KeyC) then return false end

		local tab = consoleTabBar:getCurrentTab()
		if not tab then return false end

		local consoleBuffer = tab.tabPanel.consoleBuffer
		if not consoleBuffer then return false end

		return copyChatSelection(consoleBuffer, consoleBuffer:getFocusedChild())
	end
	g_keyboard.bindKeyPress('Shift+Up', function() navigateMessageHistory(1) end, chatWindow)
	g_keyboard.bindKeyPress('Shift+Down', function() navigateMessageHistory(-1) end, chatWindow)
	g_keyboard.bindKeyPress('Shift+Tab', function() consoleTabBar:selectPrevTab() end, chatWindow)
	g_keyboard.bindKeyPress('Ctrl+A', function() textEdit:clearText() end, chatWindow)

	g_keyboard.bindKeyDown('Ctrl+O', g_game.requestChannels)
	g_keyboard.bindKeyDown('Ctrl+H', openHelp)

  -- apply buttom functions after loaded
	consoleTabBar:setNavigation(chatWindow.prevChannelButton, chatWindow.nextChannelButton)
	consoleTabBar.onTabChange = onTabChange
	load()
	chatWindow:setVisible(false)
	createChatPreview()
	processPendingMessages()
	
	onGameStart()
  local classic = g_settings.getBoolean("classicView") and not g_app.isMobile()
  if classic then
    modules.game_chat.switchMode(false)
  end
  modules.game_chat.switchMode(classic)

  local locked = g_settings.getBoolean('chatLocked')
  chatLocked = not locked
  onClickLockButton()
end

function isActive()
	return chatActive
end

function doToggleAllChat()
  local classic = g_settings.getBoolean("classicView")
  if classic then
    allchat:hide()
    return
  end
	if chatWindow:isVisible() then
		allchat:show()
	end
end

function doSendCurrentMessageBtn()
  local message = textEdit:getText()
  if #message == 0 or not isActive() then return true end
	sendCurrentMessage()
end

function sendCurrentMessage()
  local message = textEdit:getText()
  if #message == 0 or not isActive() then
    chatWindow:focus()
    toggleChat()
	  doToggleAllChat() 
	  return 
  end
  
  textEdit:clearText()

  -- send message
  sendMessage(message)
  local classic = g_settings.getBoolean("classicView")
  if classic then
    toggleChat()
  end
  save()
end

local movesMessage = {
  "m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10", "m11", "m12"
}

function sendMessage(message, tab)
  local isValid = false
  if message:match("^#s !autocombo") then
    message = message:gsub("^#s ", "")
  end

  if message:match("^!autocombo") then
    modules.game_pokemoves.sendAutoCombo(message)
    return
  end

  for _, validMessage in ipairs(movesMessage) do
      if message == validMessage then
          modules.game_pokemoves.sendCastMove(message)
          return
      end
  end

  local tab = tab or getCurrentTab()
  if not tab then return end

  for k,func in pairs(filters) do
    if func(message) then
      return true
    end
  end

  -- when talking on server log, the message goes to default channel
  local name = tab:getText()
  if tab == serverTab or tab == getRuleViolationsTab() or tab == lootTab then
    tab = defaultTab
    name = defaultTab:getText()
  end

  -- handling chat commands
  local channel = tab.channelId
  local originalMessage = message
  local chatCommandSayMode
  local chatCommandPrivate
  local chatCommandPrivateReady
  local chatCommandMessage

  -- player used yell command
  chatCommandMessage = message:match("^%#[y|Y] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'yell'
    channel = 0
    message = chatCommandMessage
  end

   -- player used whisper
  chatCommandMessage = message:match("^%#[w|W] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'whisper'
    message = chatCommandMessage
    channel = 0
  end

  -- player say
  chatCommandMessage = message:match("^%#[s|S] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'say'
    message = chatCommandMessage
    channel = 0
  end

  -- player red talk on channel
  chatCommandMessage = message:match("^%#[c|C] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'channelRed'
    message = chatCommandMessage
  end

  -- player broadcast
  chatCommandMessage = message:match("^%#[b|B] (.*)")
  if chatCommandMessage ~= nil then
    chatCommandSayMode = 'broadcast'
    message = chatCommandMessage
    channel = 0
  end

  local findIni, findEnd, chatCommandInitial, chatCommandPrivate, chatCommandEnd, chatCommandMessage = message:find("([%*%@])(.+)([%*%@])(.*)")
  if findIni ~= nil and findIni == 1 then -- player used private chat command
    if chatCommandInitial == chatCommandEnd then
      chatCommandPrivateRepeat = false
      if chatCommandInitial == "*" then
        setTextEditText('*'.. chatCommandPrivate .. '* ')
      end
      message = chatCommandMessage:trim()
      chatCommandPrivateReady = true
    end
  end

  message = message:gsub("^(%s*)(.*)","%2") -- remove space characters from message init
  if #message == 0 then return end

  -- add new command to history
  currentMessageIndex = 0
  if #messageHistory == 0 or messageHistory[#messageHistory] ~= originalMessage then
    table.insert(messageHistory, originalMessage)
    if #messageHistory > MAX_HISTORY then
      table.remove(messageHistory, 1)
    end
  end

  local speaktypedesc
  if (channel or tab == defaultTab) and not chatCommandPrivateReady then
    if tab == defaultTab then
      speaktypedesc = chatCommandSayMode or SayModes[2].speakTypeDesc
      if speaktypedesc ~= 'say' then sayModeChange(2) end -- head back to say mode
    else
      speaktypedesc = chatCommandSayMode or 'channelYellow'
    end

    g_game.talkChannel(SpeakTypesSettings[speaktypedesc].speakType, channel, message)
    return
  else
    local isPrivateCommand = false
    local priv = true
    local tabname = name
    local dontAdd = false
    if chatCommandPrivateReady then
      speaktypedesc = 'privatePlayerToPlayer'
      name = chatCommandPrivate
      isPrivateCommand = true
    elseif tab.npcChat then
      speaktypedesc = 'privatePlayerToNpc'
    elseif tab == violationReportTab then
      if violationReportTab.locked then
        modules.game_textmessage.displayFailureMessage(tr('Wait for a gamemaster reply.'))
        dontAdd = true
      else
        speaktypedesc = 'rvrContinue'
        tabname = tr('Report Rule') .. '...'
      end
    elseif tab.violationChatName then
      speaktypedesc = 'rvrAnswerTo'
      name = tab.violationChatName
      tabname = tab.violationChatName .. '\'...'
    else
      speaktypedesc = 'privatePlayerToPlayer'
    end


    local speaktype = SpeakTypesSettings[speaktypedesc]
    local player = g_game.getLocalPlayer()
    g_game.talkPrivate(speaktype.speakType, name, message)
    if not dontAdd then
      message = applyMessagePrefixies(g_game.getCharacterName(), player:getLevel(), stripColorMarkup(message))
      addPrivateText(message, speaktype, tabname, isPrivateCommand, g_game.getCharacterName())
    end
  end
end


function sayModeChange(sayMode)
  local buttom = chatWindow.sayModeButton
  if sayMode == nil then
    sayMode = buttom.sayMode + 1
  end

  if sayMode > #SayModes then sayMode = 1 end

  -- buttom:setIcon(SayModes[sayMode].icon)
  -- buttom.sayMode = sayMode
end

function getOwnPrivateTab()
  if not ownPrivateName then return end
  return getTab(ownPrivateName)
end

function setIgnoreNpcMessages(ignore)
  ignoreNpcMessages = ignore
end

function navigateMessageHistory(step)
  local numCommands = #messageHistory
  if numCommands > 0 then
    currentMessageIndex = math.min(math.max(currentMessageIndex + step, 0), numCommands)
    if currentMessageIndex > 0 then
      local command = messageHistory[numCommands - currentMessageIndex + 1]
      setTextEditText(command)
    else
      textEdit:clearText()
    end
  end
end

function clearChannel(consoleTabBar)
  consoleTabBar:getCurrentTab().tabPanel.consoleBuffer:destroyChildren()
end

function setTextEditText(text)
  textEdit:setText(text)
  textEdit:setCursorPos(-1)
end

function openHelp()
  local helpChannel = 9
  if g_game.getClientVersion() <= 810 then
    helpChannel = 8
  end
  g_game.joinChannel(helpChannel)
end

function openPlayerReportRuleViolationWindow()
  if violationWindow or violationReportTab then return end
  violationWindow = g_ui.loadUI('violationwindow', rootWidget)
  violationWindow.onEscape = function()
    violationWindow:destroy()
    violationWindow = nil
  end
  violationWindow.onEnter = function()
    local text = violationWindow.text:getText()
    g_game.talkChannel(MessageModes.RVRChannel, 0, text)
    violationReportTab = addTab(tr('Report Rule') .. '...', true)
    addTabText(tr('Please wait patiently for a gamemaster to reply') .. '.', SpeakTypesSettings.privateRed, violationReportTab)
    addTabText(applyMessagePrefixies(g_game.getCharacterName(), 0, stripColorMarkup(text)),  SpeakTypesSettings.say, violationReportTab, g_game.getCharacterName())
    violationReportTab.locked = true
    violationWindow:destroy()
    violationWindow = nil
  end
end

function addTab(name, focus)
  local tab = getTab(name)
  if tab then
    if not focus then focus = true end
  else
    tab = consoleTabBar:addTab(name, nil, processChannelTabMenu)
    updatePreviewMutedIcon(tab)
  end
  if focus then
    consoleTabBar:selectTab(tab)
  end
  return tab
end

function removeTab(tab)
  if type(tab) == 'string' then
    tab = consoleTabBar:getTab(tab)
  end

  if tab == defaultTab or tab == serverTab or tab == lootTab then
    return
  end

  if tab == violationReportTab then
    g_game.cancelRuleViolation()
    violationReportTab = nil
  elseif tab.violationChatName then
    g_game.closeRuleViolation(tab.violationChatName)
  elseif tab.channelId then
    -- notificate the server that we are leaving the channel
    for k, v in pairs(channels) do
      if (k == tab.channelId) then channels[k] = nil end
    end
    g_game.leaveChannel(tab.channelId)
  elseif tab:getText() == "NPCs" then
    g_game.closeNpcChannel()
  end

  consoleTabBar:removeTab(tab)
end

function clearSelection(consoleBuffer)
  for _,label in pairs(consoleBuffer:getChildren()) do
    label:clearSelection()
  end
  consoleBuffer.selectionText = nil
  consoleBuffer.selection = nil
  consoleBuffer.selectionRanges = nil
end

function selectAll(consoleBuffer)
  local children = consoleBuffer:getChildren()
  local text = {}
  local ranges = {}
  for i, label in ipairs(children) do
    label:selectAll()
    table.insert(text, label:getSelection())
    ranges[i] = { s = label:getSelectionStart(), e = label:getSelectionEnd() }
  end
  consoleBuffer.selection = { first = 1, last = #children }
  consoleBuffer.selectionText = table.concat(text, '\n')
  consoleBuffer.selectionRanges = ranges
end

-- right-clicking a selected line steals keyboard focus (popup menu), and
-- UITextEdit::onFocusChange clears the focused label's selection. Re-apply the
-- stored ranges after the menu opens so the highlight survives until copy.
local function reapplySelection(consoleBuffer)
  if not consoleBuffer.selectionRanges then return end
  for idx, range in pairs(consoleBuffer.selectionRanges) do
    local label = consoleBuffer:getChildByIndex(idx)
    if label then label:setSelection(range.s, range.e) end
  end
end

local copyToast = nil
local COPY_TOAST_DURATION_MS = 2500
local COPY_TOAST_TICK_MS = 20

local function showCopyToast(text)
  local mapPanel = modules.game_interface and modules.game_interface.getMapPanel()
  if not mapPanel then return end

  if copyToast and not copyToast:isDestroyed() then
    if copyToast.tickEvent then removeEvent(copyToast.tickEvent) end
    copyToast:destroy()
  end

  local toast = g_ui.createWidget('ChatCopyToast', mapPanel)
  copyToast = toast
  toast:addAnchor(AnchorRight, 'parent', AnchorRight)
  toast:addAnchor(AnchorTop, 'parent', AnchorTop)
  toast:setMarginRight(20)
  toast:setMarginTop(20)

  local label = toast:getChildById('text')
  if label then label:setText(text) end
  local timer = toast:getChildById('timer')

  g_effects.fadeIn(toast)

  local elapsed = 0
  local function tick()
    if not toast or toast:isDestroyed() then return end
    elapsed = elapsed + COPY_TOAST_TICK_MS
    if timer and not timer:isDestroyed() then
      timer:setPercent(math.max(0, 100 - (elapsed / COPY_TOAST_DURATION_MS) * 100))
    end
    if elapsed >= COPY_TOAST_DURATION_MS then
      g_effects.fadeOut(toast)
      scheduleEvent(function() if toast and not toast:isDestroyed() then toast:destroy() end end, 220)
      if copyToast == toast then copyToast = nil end
    else
      toast.tickEvent = scheduleEvent(tick, COPY_TOAST_TICK_MS)
    end
  end
  toast.tickEvent = scheduleEvent(tick, COPY_TOAST_TICK_MS)
end

local function setClipboardWithToast(text)
  if not text or #text == 0 then return false end
  g_window.setClipboardText(text)
  showCopyToast(tr('Copied to clipboard'))
  return true
end

function copyChatSelection(consoleBuffer, focusedLabel)
  local text = consoleBuffer and consoleBuffer.selectionText
  if (not text or #text == 0) and focusedLabel and focusedLabel:hasSelection() then
    text = focusedLabel:getSelection()
  end
  return setClipboardWithToast(text)
end

function removeCurrentTab()
  removeTab(consoleTabBar:getCurrentTab())
end

function getTab(name)
  return consoleTabBar:getTab(name)
end

function getChannelTab(channelId)
  local channel = channels[channelId]
  if channel then
    return getTab(channel)
  end
  return nil
end

function getRuleViolationsTab()
  if violationsChannelId then
    return getChannelTab(violationsChannelId)
  end
  return nil
end

function getCurrentTab()
  return consoleTabBar:getCurrentTab()
end

function addChannel(name, id)
  channels[id] = name
  local focus = not table.find(ignoredChannels, id)
  local tab = addTab(name, focus)
  tab.channelId = id
  tab:setCursor("pointer")
  tab:setChangeCursorImage(true)
  replayChatHistory(name, tab)
  return tab
end

function addPrivateChannel(receiver)
  channels[receiver] = receiver
  local tab = addTab(receiver, false)
  replayChatHistory(receiver, tab)
  return tab
end

function addPrivateText(text, speaktype, name, isPrivateCommand, creatureName)
  local focus = false
  if speaktype.npcChat then
    name = 'NPCs'
    focus = true
  end

  local privateTab = getTab(name)
  if privateTab == nil then
    if (modules.client_options.getOption('showPrivateMessagesInConsole') and not focus) or (isPrivateCommand and not privateTab) then
      privateTab = defaultTab
    else
      privateTab = addTab(name, focus)
      channels[name] = name
    end
    privateTab.npcChat = speaktype.npcChat
  elseif focus then
    consoleTabBar:selectTab(privateTab)
  end
  addTabText(text, speaktype, privateTab, creatureName)
end

function addText(text, speaktype, tabName, creatureName)
  local tab = getTab(tabName)
  if tab ~= nil then
    addTabText(text, speaktype, tab, creatureName)
  end
end

function applyMessagePrefixies(name, level, message, worldName)
  if name then
    local namePrefix = name
    if worldName and worldName ~= "" then
      namePrefix = namePrefix .. ' {(' .. worldName .. '), #00FF00}'
    end
    if modules.client_options.getOption('showLevelsInConsole') and level > 0 then
      message = namePrefix .. ' (' .. level .. '): ' .. message
    else
      message = namePrefix .. ': ' .. message
    end
  end
  return message
end

function getHighlightedText(text)
  local tmpData = {}

  repeat
    local tmp = {string.find(text, "{([^}]+)}", tmpData[#tmpData-1])}
    for _, v in pairs(tmp) do
      table.insert(tmpData, v)
    end
  until not(string.find(text, "{([^}]+)}", tmpData[#tmpData-1]))

  return tmpData
end

function getNewHighlightedText(text, color, highlightColor)
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


function getPkaColoredText(text, defaultColor)
  local result = {}
  local pattern = "(.-){([^,{}]+),%s*(#%x+)}"
  local lastEnd = 1

  for before, item, color in text:gmatch(pattern) do
    if #before > 0 then
      table.insert(result, before)
      table.insert(result, defaultColor)
    end
    table.insert(result, item)
    table.insert(result, color)
    lastEnd = text:find("}", lastEnd) + 1
  end

  if lastEnd <= #text then
    local remainingText = text:sub(lastEnd)
    if #remainingText > 0 then
      table.insert(result, remainingText)
      table.insert(result, defaultColor)
    end
  end

  return result
end

local function cancelPreviewDefaultPlacement()
  removeEvent(previewDefaultPlacementEvent)
  previewDefaultPlacementEvent = nil
end

local function applyDefaultPreviewPosition()
  if not chatPreviewPanel then return true end
  local mapPanel = modules.game_interface.getMapPanel()
  local rootPanel = modules.game_interface.getRootPanel()
  local actionBar = rootPanel and rootPanel:recursiveGetChildById('playerActionBar')
  if not mapPanel or not actionBar or not actionBar:isVisible()
      or actionBar:getWidth() <= 0 or actionBar:getHeight() <= 0 then
    return false
  end

  local mapBottom = mapPanel:getY() + mapPanel:getHeight()
  chatPreviewPanel:setMarginLeft(math.max(0, actionBar:getX() - mapPanel:getX()))
  chatPreviewPanel:setMarginBottom(math.max(0, mapBottom - actionBar:getY()))
  return true
end

local function scheduleDefaultPreviewPosition()
  cancelPreviewDefaultPlacement()
  if applyDefaultPreviewPosition() then return end
  previewDefaultPlacementEvent = scheduleEvent(function()
    previewDefaultPlacementEvent = nil
    scheduleDefaultPreviewPosition()
  end, 50)
end

function createChatPreview()
  if chatPreviewPanel then return end
  local mapPanel = modules.game_interface.getMapPanel()
  if not mapPanel then return end
  chatPreviewPanel = g_ui.createWidget('ChatPreviewPanel', mapPanel)
  chatPreviewPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  chatPreviewPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
  chatPreviewPanel:setWidth(400)
  local hasSavedPosition = g_settings.exists('chatPreviewMarginLeft')
    and g_settings.exists('chatPreviewMarginBottom')
  if hasSavedPosition then
    chatPreviewPanel:setMarginLeft(g_settings.getNumber('chatPreviewMarginLeft'))
    chatPreviewPanel:setMarginBottom(g_settings.getNumber('chatPreviewMarginBottom'))
  else
    chatPreviewPanel:setMarginLeft(0)
    chatPreviewPanel:setMarginBottom(0)
    scheduleDefaultPreviewPosition()
  end

  chatPreviewPanel.onDragEnter = function(self) return true end
  chatPreviewPanel.onDragMove = function(self, mousePos, mouseMoved)
    cancelPreviewDefaultPlacement()
    self:setMarginLeft(math.max(0, self:getMarginLeft() + mouseMoved.x))
    self:setMarginBottom(math.max(0, self:getMarginBottom() - mouseMoved.y))
    return true
  end
  chatPreviewPanel.onDragLeave = function(self)
    g_settings.set('chatPreviewMarginLeft', self:getMarginLeft())
    g_settings.set('chatPreviewMarginBottom', self:getMarginBottom())
    g_settings.save()
    return true
  end

  removeEvent(previewShiftPoll)
  previewShiftPoll = cycleEvent(updatePreviewDragMode, 150)
end

local function clearPreviewDragHint()
  if previewDragHint and not previewDragHint:isDestroyed() then
    previewDragHint:destroy()
  end
  previewDragHint = nil
end

local function updatePreviewDragHint()
  if not chatPreviewPanel or previewDragHint then return end
  if chatPreviewPanel:getChildCount() > 0 then return end
  previewDragHint = g_ui.createWidget('ChatPreviewLabel', chatPreviewPanel)
  previewDragHint:setTTF('poppins', 'semibold',
    modules.client_options.getOption('chatPreviewFontSize') or 12)
  previewDragHint:setText(tr('Hold Shift to drag the preview on screen'))
end

function setPreviewDragMode(enabled)
  if not chatPreviewPanel then return end
  if enabled == previewDragMode then
    if enabled then updatePreviewDragHint() end
    return
  end
  previewDragMode = enabled
  if enabled then
    chatPreviewPanel:setPhantom(false)
    chatPreviewPanel:setDraggable(true)
    chatPreviewPanel:setBackgroundColor('#00000066')
    chatPreviewPanel:setBorderWidth(1)
    chatPreviewPanel:setBorderColor('#ffffff88')
    updatePreviewDragHint()
  else
    clearPreviewDragHint()
    chatPreviewPanel:setPhantom(true)
    chatPreviewPanel:setDraggable(false)
    chatPreviewPanel:setBackgroundColor('alpha')
    chatPreviewPanel:setBorderWidth(0)
  end
end

function updatePreviewDragMode()
  if not chatPreviewPanel then return end
  local shouldDrag = g_keyboard.isShiftPressed()
    and not chatWindow:isVisible()
    and not g_app.isMobile()
    and modules.client_options.getOption('showChatPreview')
  setPreviewDragMode(shouldDrag)
end

function clearChatPreview()
  if not chatPreviewPanel then return end
  clearPreviewDragHint()
  setPreviewDragMode(false)
  for _, child in pairs(chatPreviewPanel:getChildren()) do
    removeEvent(child.previewFadeEvent)
    removeEvent(child.previewDestroyEvent)
    g_effects.cancelFade(child)
    child:destroy()
  end
end

function destroyChatPreview()
  cancelPreviewDefaultPlacement()
  removeEvent(previewShiftPoll)
  previewShiftPoll = nil
  clearChatPreview()
  if chatPreviewPanel then
    chatPreviewPanel:destroy()
    chatPreviewPanel = nil
  end
end

function addPreviewText(text, coloredText, setColoredText, speaktype, tab)
  if not chatPreviewPanel then return end
  if not modules.client_options.getOption('showChatPreview') then return end
  if g_app.isMobile() then return end
  if chatWindow:isVisible() then return end
  if not speaktype or speaktype == SpeakTypesSettings.none or speaktype.hideInConsole then return end
  if speaktype.private and not modules.client_options.getOption('chatPreviewShowPrivate') then return end
  if isPreviewMuted(tab) then return end

  clearPreviewDragHint()
  local maxLines = modules.client_options.getOption('chatPreviewLines') or 5
  while chatPreviewPanel:getChildCount() >= maxLines do
    local old = chatPreviewPanel:getFirstChild()
    if not old then break end
    removeEvent(old.previewFadeEvent)
    removeEvent(old.previewDestroyEvent)
    g_effects.cancelFade(old)
    old:destroy()
  end

  local label = g_ui.createWidget('ChatPreviewLabel', chatPreviewPanel)
  label:setTTF('poppins', 'semibold', modules.client_options.getOption('chatPreviewFontSize') or 12)
  if setColoredText then
    label:setColoredText(coloredText)
  else
    label:setText(text)
    label:setColor(speaktype.color)
  end

  local duration = (modules.client_options.getOption('chatPreviewDuration') or 5) * 1000
  label.previewFadeEvent = scheduleEvent(function()
    if not label:isDestroyed() then g_effects.fadeOut(label) end
  end, duration)
  label.previewDestroyEvent = scheduleEvent(function()
    if not label:isDestroyed() then label:destroy() end
  end, duration + 1000)
end

function addTabText(text, speaktype, tab, creatureName, isReplay)
  if not tab or tab.locked or not text or #text == 0 then return end
  if not isReplay then
    recordChatMessage(tab, speaktype, text, creatureName)
    if modules.client_options.getOption('showTimestampsInConsole') then
      text = os.date('%H:%M') .. ' ' .. text
    end
  end

  local panel = consoleTabBar:getTabPanel(tab)
  local consoleBuffer = panel:getChildById('consoleBuffer')

  local label = nil
  if consoleBuffer:getChildCount() > MAX_LINES then
    label = consoleBuffer:getFirstChild()
    consoleBuffer:moveChildToIndex(label, consoleBuffer:getChildCount())
  end

  if not label then
    label = g_ui.createWidget('ConsoleLabel', consoleBuffer)
  end
  label:setId('consoleLabel' .. consoleBuffer:getChildCount())
  local setColoredText = false
  local coloredText = getPkaColoredText(text, speaktype.color)
  if #coloredText > 2 then
    label:setColoredText(coloredText)
    setColoredText = true
  end

  if not setColoredText then
    label:setText(text)
    label:setColor(speaktype.color)
  end

  if not isReplay then
    local blinkMuted = isPreviewMuted(tab) and modules.client_options.getOption('chatPreviewMuteStopsBlink')
    if not blinkMuted then consoleTabBar:blinkTab(tab) end
  end

  if speaktype.npcChat and (g_game.getCharacterName() ~= creatureName or g_game.getCharacterName() == 'Account Manager') then
    local highlightData = getNewHighlightedText(text, speaktype.color, "#1f9ffe")
    if #highlightData > 2 then
      label:setColoredText(highlightData)
      coloredText = highlightData
      setColoredText = true
    end
  end

  if not isReplay then addPreviewText(text, coloredText, setColoredText, speaktype, tab) end

  label.name = creatureName
  consoleBuffer.onMouseRelease = function(self, mousePos, mouseButton)
    processMessageMenu(mousePos, mouseButton, nil, nil, nil, tab)
  end
  label.onMouseRelease = function(self, mousePos, mouseButton)
    processMessageMenu(mousePos, mouseButton, creatureName, text, self, tab)
  end
  label.onMousePress = function(self, mousePos, button)
    if button == MouseLeftButton then clearSelection(consoleBuffer) end
  end
  label.onKeyPress = function(self, keyCode, keyboardModifiers)
    if not (keyboardModifiers == KeyboardCtrlModifier and keyCode == KeyC) then return false end
    return copyChatSelection(consoleBuffer, self)
  end
  label.onDragEnter = function(self, mousePos)
    clearSelection(consoleBuffer)
    return true
  end
  label.onDragLeave = function(self, droppedWidget, mousePos)
    if not consoleBuffer.selection then return true end
    local text = {}
    local ranges = {}
    for selectionChild = consoleBuffer.selection.first, consoleBuffer.selection.last do
      local lbl = self:getParent():getChildByIndex(selectionChild)
      if lbl then
        table.insert(text, lbl:getSelection())
        ranges[selectionChild] = { s = lbl:getSelectionStart(), e = lbl:getSelectionEnd() }
      end
    end
    consoleBuffer.selectionText = table.concat(text, '\n')
    consoleBuffer.selectionRanges = ranges
    return true
  end
  label.onDragMove = function(self, mousePos, mouseMoved)
    local parent = self:getParent()
    local parentRect = parent:getPaddingRect()
    local selfIndex = parent:getChildIndex(self)
    local child = parent:getChildByPos(mousePos)

    -- find bonding children
    if not child then
      if mousePos.y < self:getY() then
        for index = selfIndex - 1, 1, -1 do
          local label = parent:getChildByIndex(index)
          if label:getY() + label:getHeight() > parentRect.y then
            if (mousePos.y >= label:getY() and mousePos.y <= label:getY() + label:getHeight()) or index == 1 then
              child = label
              break
            end
          else
            child = parent:getChildByIndex(index + 1)
            break
          end
        end
      elseif mousePos.y > self:getY() + self:getHeight() then
        for index = selfIndex + 1, parent:getChildCount(), 1 do
          local label = parent:getChildByIndex(index)
          if label:getY() < parentRect.y + parentRect.height then
            if (mousePos.y >= label:getY() and mousePos.y <= label:getY() + label:getHeight()) or index == parent:getChildCount() then
              child = label
              break
            end
          else
            child = parent:getChildByIndex(index - 1)
            break
          end
        end
      else
        child = self
      end
    end

    if not child then return false end

    local childIndex = parent:getChildIndex(child)

    -- remove old selection
    clearSelection(consoleBuffer)

    -- update self selection
    local textBegin = self:getTextPos(self:getLastClickPosition())
    local textPos = self:getTextPos(mousePos)
    self:setSelection(textBegin, textPos)

    consoleBuffer.selection = { first = math.min(selfIndex, childIndex), last = math.max(selfIndex, childIndex) }

    -- update siblings selection
    if child ~= self then
      for selectionChild = consoleBuffer.selection.first + 1, consoleBuffer.selection.last - 1 do
        parent:getChildByIndex(selectionChild):selectAll()
      end

      local textPos = child:getTextPos(mousePos)
      if childIndex > selfIndex then
        child:setSelection(0, textPos)
      else
        child:setSelection(utf8.len(child:getText()), textPos)
      end
    end

    return true
  end
end

function processPendingMessages()
  if #pendingMessages > 0 then
    local currentTime = g_clock.millis()
    for i = #pendingMessages, 1, -1 do
      local message = pendingMessages[i]
      if currentTime >= message.deleteTime then
        message.label:destroy()
        table.remove(pendingMessages, i)
      end
    end
  end

  pendingMessagesEvent = scheduleEvent(processPendingMessages, 1000)
end

function removeTabLabelByName(tab, name)
  local panel = consoleTabBar:getTabPanel(tab)
  local consoleBuffer = panel.consoleBuffer
  for _,label in pairs(consoleBuffer:getChildren()) do
    if label.name == name then
      label:destroy()
    end
  end
end

function processChannelTabMenu(tab, mousePos, mouseButton)
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)

  local worldName = g_game.getWorldName()
  local characterName = g_game.getCharacterName()
  channelName = tab:getText()
  if tab ~= defaultTab and tab ~= serverTab and tab ~= lootTab then
    menu:addOption(tr('Close'), function() removeTab(channelName) end)
    --menu:addOption(tr('Show Server Messages'), function() --[[TODO]] end)
    menu:addSeparator()
  end

  if isPreviewMutable(tab) and modules.client_options.getOption('showChatPreview') then
    if isPreviewMuted(tab) then
      menu:addOption(tr('Show in chat preview'), function() setPreviewMuted(tab, false) end)
    else
      menu:addOption(tr('Hide in chat preview'), function() setPreviewMuted(tab, true) end)
    end
  end

  if consoleTabBar:getCurrentTab() == tab then
    menu:addOption(tr('Clear Messages'), function() clearChannel(consoleTabBar) end)
    menu:addOption(tr('Save Channels'), function()
      local panel = consoleTabBar:getTabPanel(tab)
      local consoleBuffer = panel:getChildById('consoleBuffer')
      local lines = {}
      for _,label in pairs(consoleBuffer:getChildren()) do
        table.insert(lines, label:getText())
      end

      local filename = worldName .. ' - ' .. characterName .. ' - ' .. channelName .. '.txt'
      local filepath = '/settings/modules/chatLog/'..filename
	  
	  if not g_resources.fileExists(filepath) then
	 	 g_resources.makeDir("/settings/modules/chatLog/")
	 	 g_resources.writeFileContents(filepath, '')
	  end

      -- extra information at the beginning
      table.insert(lines, 1, os.date('\nChannel saved at %a %b %d %H:%M:%S %Y'))

      if g_resources.fileExists(filepath) then
        table.insert(lines, 1, protectedcall(g_resources.readFileContents, filepath) or '')
      end

      g_resources.writeFileContents(filepath, table.concat(lines, '\n'))
      modules.game_textmessage.displayStatusMessage(tr('Channel appended to %s', filename))
    end)
  end

  menu:display(mousePos)
end

function processMessageMenu(mousePos, mouseButton, creatureName, text, label, tab)
  if mouseButton == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    if creatureName and #creatureName > 0 then
      if creatureName ~= g_game.getCharacterName() then
        menu:addOption(tr('Message to ' .. creatureName), function () g_game.openPrivateChannel(creatureName) end)
        if not g_game.getLocalPlayer():hasVip(creatureName) then
          menu:addOption(tr('Add to VIP list'), function () g_game.addVip(creatureName) end)
        end
        if modules.game_chat.getOwnPrivateTab() then
          menu:addSeparator()
          menu:addOption(tr('Invite to private chat'), function() g_game.inviteToOwnChannel(creatureName) end)
          menu:addOption(tr('Exclude from private chat'), function() g_game.excludeFromOwnChannel(creatureName) end)
        end
        if isIgnored(creatureName) then
          menu:addOption(tr('Unignore') .. ' ' .. creatureName, function() removeIgnoredPlayer(creatureName) end)
        else
          menu:addOption(tr('Ignore') .. ' ' .. creatureName, function() addIgnoredPlayer(creatureName) end)
        end
        menu:addSeparator()
      end
      if modules.game_ruleviolation.hasWindowAccess() then
        menu:addOption(tr('Rule Violation'), function() modules.game_ruleviolation.show(creatureName, text:match('.+%:%s(.+)')) end)
        menu:addSeparator()
      end

      menu:addOption(tr('Copy name'), function () setClipboardWithToast(creatureName) end)
    end
    local selection = tab.tabPanel:getChildById('consoleBuffer').selectionText
    if selection and #selection > 0 then
      menu:addOption(tr('Copy'), function() setClipboardWithToast(selection) end, '(Ctrl+C)')
    end
    if text then
      menu:addOption(tr('Copy message'), function() setClipboardWithToast(text) end)
    end
    menu:addOption(tr('Select all'), function() selectAll(tab.tabPanel:getChildById('consoleBuffer')) end)
    if tab.violations and creatureName then
      menu:addSeparator()
      menu:addOption(tr('Process') .. ' ' .. creatureName, function() processViolation(creatureName, text) end)
      menu:addOption(tr('Remove') .. ' ' .. creatureName, function() g_game.closeRuleViolation(creatureName) end)
    end
    menu:display(mousePos)
    local cb = tab.tabPanel:getChildById('consoleBuffer')
    reapplySelection(cb)
    scheduleEvent(function() reapplySelection(cb) end, 1)
  end
end

function terminate()
	disconnect(g_game, {
		onTalk = onTalk,
		onChannelList = onChannelList,
		onOpenChannel = onOpenChannel,
		onOpenPrivateChannel = onOpenPrivateChannel,
		onOpenOwnPrivateChannel = onOpenPrivateChannel,
		onCloseChannel = onCloseChannel,
		onRuleViolationChannel = onRuleViolationChannel,
		onRuleViolationRemove = onRuleViolationRemove,
		onRuleViolationCancel = onRuleViolationCancel,
		onRuleViolationLock = onRuleViolationLock,
		onGameEnd = onGameEnd,
		save = save,
		onGameStart = onGameStart,
	})
  disconnect(g_client, {
    onTrainerClose = focusChatChannel
  })
	if pendingMessagesEvent then
		removeEvent(pendingMessagesEvent)
		pendingMessagesEvent = nil
	end
	save()
	destroyChatPreview()
	chatWindow:destroy()
end

function save()
  local settings = {}
  settings.position = chatWindow:getPosition()
  settings.marginHeight = chatWindow:getHeight()
  settings.marginWidth = chatWindow:getWidth()
  settings.messageHistory = messageHistory
  g_settings.setNode('game_chat', settings)
end

function doSetPositionWindow()
  local settings = g_settings.getNode('game_chat')
  if settings then 
	local pos = settings.position or {x = 0, y = 0}
    chatWindow:setPosition(pos)
  end
end

function load()
  local settings = g_settings.getNode('game_chat')
  if settings then 
    messageHistory = settings.messageHistory or {}
    chatWindow:setHeight(settings.marginHeight or 600)
    chatWindow:setWidth(settings.marginWidth or 255)
	oldPos = settings.position
	doSetPositionWindow()
  end
  loadCommunicationSettings()
end

function onTabChange(tabBar, tab)
  if tab == defaultTab or tab == serverTab or tab == lootTab then
    chatWindow.closeChannelButton:disable()
  else
    chatWindow.closeChannelButton:enable()
  end
end

function clear()
  -- save last open channels
  local lastChannelsOpen = g_settings.getNode('lastChannelsOpen') or {}
  local char = g_game.getCharacterName()
  local savedChannels = {}
  local set = false
  for channelId, channelName in pairs(channels) do
    if type(channelId) == 'number' then
      savedChannels[channelName] = channelId
      set = true
    end
  end
  if set then
    lastChannelsOpen[char] = savedChannels
  else
    lastChannelsOpen[char] = nil
  end
  g_settings.setNode('lastChannelsOpen', lastChannelsOpen)
  saveChatHistoryTabs()

  -- close channels
  for _, channelName in pairs(channels) do
    local tab = consoleTabBar:getTab(channelName)
    consoleTabBar:removeTab(tab)
  end
  channels = {}

  if defaultTab and defaultTab:getParent() then
    consoleTabBar:removeTab(defaultTab)
  end

  if serverTab and serverTab:getParent() then
    consoleTabBar:removeTab(serverTab)
  end

  if lootTab and lootTab:getParent() then
    consoleTabBar:removeTab(lootTab)
  end

  local npcTab = consoleTabBar:getTab('NPCs')
  if npcTab then
    consoleTabBar:removeTab(npcTab)
  end

  if violationReportTab then
    consoleTabBar:removeTab(violationReportTab)
    violationReportTab = nil
  end

  textEdit:clearText()

  if violationWindow then
    violationWindow:destroy()
    violationWindow = nil
  end

  if channelsWindow then
    channelsWindow:destroy()
    channelsWindow = nil
  end
end


function onGameStart()
  isOnline = true
  defaultTab = addTab(tr('Default'), true)
  serverTab = addTab(tr('Server Log'), false)
  lootTab = addTab(tr('Loot'), false)

  defaultTab:setCursor("pointer")
  defaultTab:setChangeCursorImage(true)
  --defaultTab:setFont("poppins boldbordered 14")

  serverTab:setCursor("pointer")
  serverTab:setChangeCursorImage(true)
  --serverTab:setFont("poppins boldbordered 14")

  lootTab:setCursor("pointer")
  lootTab:setChangeCursorImage(true)
  --lootTab:setFont("poppins boldbordered 14")

  cleanupChatHistory()
  restoreChatHistoryTabs()
  loadPreviewMutedTabs()
  local lastChannelsOpen = g_settings.getNode('lastChannelsOpen')
  if lastChannelsOpen then
    local savedChannels = lastChannelsOpen[g_game.getCharacterName()]
    if savedChannels then
      for channelName, channelId in pairs(savedChannels) do
        channelId = tonumber(channelId)
        if channelId ~= -1 and channelId < 100 then
          if not table.find(channels, channelId) then
            g_game.joinChannel(channelId)
            table.insert(ignoredChannels, channelId)
          end
        end
      end
    end
  end
  scheduleEvent(function() ignoredChannels = {} end, 3000)
	
  local player = g_game.getLocalPlayer()
  if not chatWindow:isVisible() or chatWindow:getOpacity() < 0.95 then
  	addEvent(function() g_effects.fadeIn(chatWindow) end)
  end
  --chatWindow:setFocusable(false)
  chatWindow:setVisible(true)
  -- Start deactivated, matching chatActive. Not just cosmetic: UIWidget::setFocusable(true) focuses
  -- the widget on the spot when its parent has no focused child, so making the field focusable here
  -- opened every session with the chat capturing the keyboard. toggleChat() is what turns it on.
  chatActive = false
  consoleToggleChat = true
  chatWindow.textEdit:setFocusable(false)
end

function enableResize(e)
	if e then
		chatWindow.rB:setVisible(true)
		chatWindow.rB2:setVisible(true)
		chatWindow.rB3:setVisible(true)
		chatWindow.rB4:setVisible(true)
	else
		chatWindow.rB:setVisible(false)
		chatWindow.rB2:setVisible(false)
		chatWindow.rB3:setVisible(false)
		chatWindow.rB4:setVisible(false)
	end
end

function onGameEnd()
	isOnline = false
	previewMutedTabs = {}
	hide()
	clear()
	clearChatPreview()
end

function onClickLockButton()
	local lB = chatWindow.lockButton
	local phantomState = not chatLocked

  lB:setOn(phantomState)
  local classic = g_settings.getBoolean("classicView") and not g_app.isMobile()
  if not classic then
      chatWindow:setDraggable(chatLocked)
  end
	chatLocked = phantomState
  g_settings.set('chatLocked', chatLocked)
end

function onTalk(name, level, mode, message, channelId, creaturePos, worldName)
  if name == g_game.getLocalPlayer():getName() then
    if mode == MessageModes.Say then
      local thing = g_map.getThing(creaturePos)
      if thing and thing:getTile() then
        local tile = thing:getTile()
        if tile and tile:getTopCreature() and tile:getTopCreature():isNpc() then
          addTab("NPCs", true)
        end
      end
    end
  end

  if FightModeInfo[message] then
    if name == g_game.getLocalPlayer():getName() then
      g_game.setFightMode(FightModeInfo[message].fightmode)
    end
    return
  end

  if mode == MessageModes.GamemasterBroadcast then
    modules.game_textmessage.displayBroadcastMessage(name .. ': ' .. message)
    return
  end

  local isNpcMode = (mode == MessageModes.NpcFromStartBlock or mode == MessageModes.NpcFrom)

  if ignoreNpcMessages and isNpcMode then return end

  speaktype = SpeakTypes[mode]

  if not speaktype then
    perror('unhandled onTalk message mode ' .. mode .. ': ' .. message)
    return
  end

  local localPlayer = g_game.getLocalPlayer()
  if name ~= g_game.getCharacterName()
      and isUsingIgnoreList()
        and not(isUsingWhiteList()) or (isUsingWhiteList() and not(isWhitelisted(name)) and not(isAllowingVIPs() and localPlayer:hasVip(name))) then

    if mode == MessageModes.Yell and isIgnoringYelling() then
      return
    elseif speaktype.private and isIgnoringPrivate() and not isNpcMode then
      return
    elseif isIgnored(name) then
      return
    end
  end

  if mode ~= MessageModes.GamemasterChannel and mode ~= MessageModes.GamemasterPrivateFrom then
    message = stripColorMarkup(message)
  end

  if mode == MessageModes.RVRChannel then
    channelId = violationsChannelId
  end

  if (mode == MessageModes.Say or mode == MessageModes.Whisper or mode == MessageModes.Yell or
      mode == MessageModes.Spell or mode == MessageModes.MonsterSay or mode == MessageModes.MonsterYell or
      mode == MessageModes.NpcFrom or mode == MessageModes.BarkLow or mode == MessageModes.BarkLoud or
      mode == MessageModes.NpcFromStartBlock) and creaturePos then
    local staticText = StaticText.create()
    -- Remove curly braces from screen message
    local staticMessage = message
    if isNpcMode then
      local highlightData = getNewHighlightedText(staticMessage, speaktype.color, "#1f9ffe")
      if #highlightData > 2 then
        staticText:addColoredMessage(name, mode, highlightData)
      else
        staticText:addMessage(name, mode, staticMessage)
      end
      staticText:setColor(speaktype.color)
    else
      staticText:addMessage(name, mode, staticMessage)
    end
    g_map.addThing(staticText, creaturePos, -1)
  end

  local defaultMessage = mode <= 3 and true or false

  if speaktype == SpeakTypesSettings.none then return end

  if speaktype.hideInConsole then return end

  local composedMessage = applyMessagePrefixies(name, level, message, worldName)

  if mode == MessageModes.RVRAnswer then
    violationReportTab.locked = false
    addTabText(composedMessage, speaktype, violationReportTab, name)
  elseif mode == MessageModes.RVRContinue then
    addText(composedMessage, speaktype, name .. '\'...', name)
  elseif speaktype.private then
    addPrivateText(composedMessage, speaktype, name, false, name)
    if modules.client_options.getOption('showPrivateMessagesOnScreen') and speaktype ~= SpeakTypesSettings.privateNpcToPlayer then
      modules.game_textmessage.displayPrivateMessage(name .. ':\n' .. message)
    end
  else
    local channel = tr('Default')
    if not defaultMessage then
      channel = channels[channelId]
    end

    if channel then
      addText(composedMessage, speaktype, channel, name)
    else
      -- server sent a message on a channel that is not open
      pwarning('message in channel id ' .. channelId .. ' which is unknown, this is a server bug, relogin if you want to see messages in this channel')
    end
  end
end

function onOpenChannel(channelId, channelName)
  addChannel(channelName, channelId)
end

function onOpenPrivateChannel(receiver)
  addPrivateChannel(receiver)
end

function onOpenOwnPrivateChannel(channelId, channelName)
  local privateTab = getTab(channelName)
  if privateTab == nil then
    addChannel(channelName, channelId)
  end
  ownPrivateName = channelName
end

function onCloseChannel(channelId)
  local channel = channels[channelId]
  if channel then
    local tab = getTab(channel)
    if tab then
      consoleTabBar:removeTab(tab)
    end
    channels[channelId] = nil
  end
end

function processViolation(name, text)
  local tabname = name .. '\'...'
  local tab = addTab(tabname, true)
  channels[tabname] = tabname
  tab.violationChatName = name
  g_game.openRuleViolation(name)
  addTabText(text, SpeakTypesSettings.say, tab, name)
end

function onRuleViolationChannel(channelId)
  violationsChannelId = channelId
  local tab = addChannel(tr('Rule Violations'), channelId)
  tab.violations = true
end

function onRuleViolationRemove(name)
  local tab = getRuleViolationsTab()
  if not tab then return end
  removeTabLabelByName(tab, name)
end

function onRuleViolationCancel(name)
  local tab = getTab(name .. '\'...')
  if not tab then return end
  addTabText(tr('%s has finished the request', name) .. '.', SpeakTypesSettings.privateRed, tab)
  tab.locked = true
end

function onRuleViolationLock()
  if not violationReportTab then return end
  violationReportTab.locked = false
  addTabText(tr('Your request has been closed') .. '.', SpeakTypesSettings.privateRed, violationReportTab)
  violationReportTab.locked = true
end

function show()
	local player = g_game.getLocalPlayer()
	if not chatWindow:isVisible() or chatWindow:getOpacity() < 0.95 then
		addEvent(function() g_effects.fadeIn(chatWindow) end)
	end
	chatWindow:show()
	return true
end

function showConfigs()
	configWindow:show()
	local cC = configWindow.configsContent
	local oBAV = cC.backgroundAlwaysVisible
	local oCC = cC.classicChat
	local oCAA = cC.chatAlwaysActive
	oCC:setEnabled(oBAV:isChecked())
	oCAA:setEnabled(oBAV:isChecked())
end

function hideConfigs()
	configWindow:hide()
end

function clickConfigButton()
	if configWindow:isVisible() then
		configWindow:hide()
	else
		showConfigs()
	end
end

function getrB3()
  return chatWindow.backgroundkeys
end

function setOption(key, value, force)
	if not force and options[key] == value then return end
	

	configWindow.configsContent.classicChat:setEnabled(value)
	configWindow.configsContent.chatAlwaysActive:setEnabled(value)
	if not value then
		options['classicChat'] = value
		options['chatAlwaysActive'] = value
	end


	g_settings.set(key, value)
	options[key] = value
end

function getOption(key)
	return options[key]
end

function toggleChat()
  g_window.cancelHeldKeysPress()
  local classic = g_settings.getBoolean("classicView")
	if not isActive() then
		--chatWindow:setFocusable(true)
		chatWindow:setVisible(true)
		chatWindow:focus()
		chatWindow.textEdit:setFocusable(true)
    chatWindow.textEdit:focus()
		chatWindow.textEdit:raise()
		chatWindow.textEdit:focus()
		consoleToggleChat = false
    chatActive = true
    if modules.game_battle and modules.game_battle.updateUIButton then modules.game_battle.updateUIButton("chatEnabled") end
    if modules.game_playeractionbar and modules.game_playeractionbar.updateUI then modules.game_playeractionbar.updateUI("chatEnabled") end
    if modules.game_pokemoves and modules.game_pokemoves.updateUI then modules.game_pokemoves.updateUI("chatEnabled") end
    if modules.game_pokebar and modules.game_pokebar.updateUI then modules.game_pokebar.updateUI("chatEnabled") end
	else
    if not classic then
		  --chatWindow:setFocusable(false)
		  chatWindow:setVisible(false)
    end
		chatWindow.textEdit:setFocusable(false)
		consoleToggleChat = true
    chatActive = false
		save()
    if modules.game_battle and modules.game_battle.updateUIButton then modules.game_battle.updateUIButton("chatDisabled") end
    if modules.game_playeractionbar and modules.game_playeractionbar.updateUI then modules.game_playeractionbar.updateUI("chatDisabled") end
    if modules.game_pokemoves and modules.game_pokemoves.updateUI then modules.game_pokemoves.updateUI("chatDisabled") end
    if modules.game_pokebar and modules.game_pokebar.updateUI then modules.game_pokebar.updateUI("chatDisabled") end
	end
end

function doChannelListSubmit()
  local channelListPanel = channelsWindow.channelList
  local openPrivateChannelWith = channelsWindow.openPrivateChannelWith:getText()
  if openPrivateChannelWith ~= '' then
    if openPrivateChannelWith:lower() ~= g_game.getCharacterName():lower() then
      g_game.openPrivateChannel(openPrivateChannelWith)
    else
      modules.game_textmessage.displayFailureMessage(tr('You cannot create a private chat channel with yourself.'))
    end
  else
    local selectedChannelLabel = channelListPanel:getFocusedChild()
    if not selectedChannelLabel then return end
    if selectedChannelLabel.channelId == 0xFFFF then
      g_game.openOwnChannel()
    else
      g_game.joinChannel(selectedChannelLabel.channelId)
    end
  end

  channelsWindow:destroy()
end

function onChannelList(channelList)
  if channelsWindow then channelsWindow:destroy() end
  channelsWindow = g_ui.displayUI('channelswindow')
  local channelListPanel = channelsWindow.channelList
  channelsWindow.onEnter = doChannelListSubmit
  channelsWindow.onDestroy = function() channelsWindow = nil end
  g_keyboard.bindKeyPress('Down', function() channelListPanel:focusNextChild(KeyboardFocusReason) end, channelsWindow)
  g_keyboard.bindKeyPress('Up', function() channelListPanel:focusPreviousChild(KeyboardFocusReason) end, channelsWindow)

  for k,v in pairs(channelList) do
    local channelId = v[1]
    local channelName = v[2]

    if #channelName > 0 then
      local label = g_ui.createWidget('ChannelListLabel', channelListPanel)
      label.channelId = channelId
      label:setText(channelName)

      label:setPhantom(false)
      label.onDoubleClick = doChannelListSubmit
    end
  end
end

function loadCommunicationSettings()
  communicationSettings.whitelistedPlayers = {}
  communicationSettings.ignoredPlayers = {}

  -- pairs with string keys, not "for i = 1, #node": g_settings writes an array as tag-keyed OTML
  -- nodes ("1: Danvrb") because lua_isstring accepts numeric keys, so it reads back keyed by the
  -- STRING "1". # on that table is 0 and the loop never ran - the ignore list came back empty on
  -- every restart, which is why ignoring only lasted for the session it was set in.
  local ignoreNode = g_settings.getNode('IgnorePlayers')
  if ignoreNode then
    for _, name in pairs(ignoreNode) do
      table.insert(communicationSettings.ignoredPlayers, tostring(name))
    end
  end

  local whitelistNode = g_settings.getNode('WhitelistedPlayers')
  if whitelistNode then
    for _, name in pairs(whitelistNode) do
      table.insert(communicationSettings.whitelistedPlayers, tostring(name))
    end
  end

  communicationSettings.useIgnoreList = true -- always on: the list itself is the switch
  communicationSettings.useWhiteList = g_settings.getBoolean('UseWhiteList')
  communicationSettings.privateMessages = g_settings.getBoolean('IgnorePrivateMessages')
  communicationSettings.yelling = g_settings.getBoolean('IgnoreYelling')
  communicationSettings.allowVIPs = g_settings.getBoolean('AllowVIPs')
end

function saveCommunicationSettings()
  local tmpIgnoreList = {}
  local ignoredPlayers = getIgnoredPlayers()
  for i = 1, #ignoredPlayers do
    table.insert(tmpIgnoreList, ignoredPlayers[i])
  end

  local tmpWhiteList = {}
  local whitelistedPlayers = getWhitelistedPlayers()
  for i = 1, #whitelistedPlayers do
    table.insert(tmpWhiteList, whitelistedPlayers[i])
  end

  g_settings.set('UseIgnoreList', communicationSettings.useIgnoreList)
  g_settings.set('UseWhiteList', communicationSettings.useWhiteList)
  g_settings.set('IgnorePrivateMessages', communicationSettings.privateMessages)
  g_settings.set('IgnoreYelling', communicationSettings.yelling)
  g_settings.setNode('IgnorePlayers', tmpIgnoreList)
  g_settings.setNode('WhitelistedPlayers', tmpWhiteList)
end

function getIgnoredPlayers()
  return communicationSettings.ignoredPlayers
end

function getWhitelistedPlayers()
  return communicationSettings.whitelistedPlayers
end

function isUsingIgnoreList()
  return communicationSettings.useIgnoreList
end

function isUsingWhiteList()
  return communicationSettings.useWhiteList
end
function isIgnored(name)
  return table.find(communicationSettings.ignoredPlayers, name, true)
end

function addIgnoredPlayer(name)
  if isIgnored(name) then return end
  table.insert(communicationSettings.ignoredPlayers, name)
end

function removeIgnoredPlayer(name)
  table.removevalue(communicationSettings.ignoredPlayers, name)
end

function isWhitelisted(name)
  return table.find(communicationSettings.whitelistedPlayers, name, true)
end

function addWhitelistedPlayer(name)
  if isWhitelisted(name) then return end
  table.insert(communicationSettings.whitelistedPlayers, name)
end

function removeWhitelistedPlayer(name)
  table.removevalue(communicationSettings.whitelistedPlayers, name)
end

function isIgnoringPrivate()
  return communicationSettings.privateMessages
end

function isIgnoringYelling()
  return communicationSettings.yelling
end

function isAllowingVIPs()
  return communicationSettings.allowVIPs
end

function onClickIgnoreButton()
  if communicationWindow then return end
  communicationWindow = g_ui.displayUI('communicationwindow')
  communicationWindow.onDestroy = function() communicationWindow = nil end

  local ignoreListPanel = communicationWindow.ignoreList
  local addIgnoreName = communicationWindow.ignoreNameEdit

  -- The remove button lives on the row and only shows on the selected one, so visibility is driven
  -- here: a $focus block in the otui would react to the button's own focus, not the row's.
  local function addRow(name)
    local row = g_ui.createWidget('IgnoreListLabel', ignoreListPanel)
    row:setText(name)
    row.removeButton.onClick = function()
      ignoreListPanel:removeChild(row)
      row:destroy()
    end
    return row
  end

  ignoreListPanel.onChildFocusChange = function(self, focused)
    for i = 1, self:getChildCount() do
      local child = self:getChildByIndex(i)
      child.removeButton:setVisible(child == focused)
    end
  end

  -- The window used to open empty while Save rebuilt the list from it, so every visit wiped whatever
  -- was ignored. Seed it from the saved list instead.
  for _, name in ipairs(getIgnoredPlayers()) do
    addRow(name)
  end

  local function addIgnoreFunction()
    local newEntry = addIgnoreName:getText()
    if newEntry == '' then return end
    for i = 1, ignoreListPanel:getChildCount() do
      if ignoreListPanel:getChildByIndex(i):getText() == newEntry then return end
    end
    addRow(newEntry)
    addIgnoreName:setText('')
  end
  communicationWindow.buttonIgnoreAdd.onClick = addIgnoreFunction
  communicationWindow.onEnter = addIgnoreFunction

  communicationWindow.buttonSave.onClick = function()
    communicationSettings.ignoredPlayers = {}
    for i = 1, ignoreListPanel:getChildCount() do
      addIgnoredPlayer(ignoreListPanel:getChildByIndex(i):getText())
    end
    communicationWindow:destroy()
  end

  communicationWindow.buttonCancel.onClick = function()
    communicationWindow:destroy()
  end
end

function online()
  defaultTab = addTab(tr('Default'), true)
  serverTab = addTab(tr('Server Log'), false)
  lootTab = addTab(tr('Loot'), false)

  if g_game.getClientVersion() >= 820 then
    local tab = addTab("NPCs", false)
    tab.npcChat = true
  end
  
  -- open last channels
  local lastChannelsOpen = g_settings.getNode('lastChannelsOpen')
  if lastChannelsOpen then
    local savedChannels = lastChannelsOpen[g_game.getCharacterName()]
    if savedChannels then
      for channelName, channelId in pairs(savedChannels) do
        channelId = tonumber(channelId)
        if channelId ~= -1 and channelId < 100 then
          if not table.find(channels, channelId) then
            g_game.joinChannel(channelId)
            table.insert(ignoredChannels, channelId)
          end
        end
      end
    end
  end
  scheduleEvent(function() consoleTabBar:selectTab(defaultTab) end, 500)
  scheduleEvent(function() ignoredChannels = {} end, 3000)
end

function offline()
  clear()
end

function onChannelEvent(channelId, name, type)
  local fmt = ChannelEventFormats[type]
  if not fmt then
    print(('Unknown channel event type (%d).'):format(type))
    return
  end

  local channel = channels[channelId]
  if channel then
    local tab = getTab(channel)
    if tab then
      addTabText(fmt:format(name), SpeakTypesSettings.channelOrange, tab)
    end
  end
end


function hide()
	g_effects.fadeOut(chatWindow)
	scheduleEvent(function() if not isOnline then chatWindow:hide() end end, 200)
	configWindow:hide()
end

function switchMode(classic)
  if classic then
    chatWindow:show()
    modules.game_interface.getBottomPanel():show()
    chatWindow:setParent(modules.game_interface.getBottomPanel())
    chatWindow:addAnchor(AnchorTop, 'parent', AnchorTop)
    chatWindow:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    chatWindow:addAnchor(AnchorRight, 'parent', AnchorRight)
    chatWindow:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    chatWindow:setDraggable(false)
    chatWindow:setMarginLeft(3)
    chatWindow:setMarginRight(3)
    chatWindow:setMarginTop(0)
    chatWindow.rB:setEnabled(false)
    chatWindow.rB2:setEnabled(false)
    chatWindow.rB3:setEnabled(false)
    chatWindow.rB4:setEnabled(false)
    modules.game_interface.getRootPanel():getChildById('bottomSplitter'):setEnabled(true)
  else
    chatWindow:setVisible(false)
    chatActive = false
    consoleToggleChat = true
    modules.game_interface.getBottomPanel():hide()
    chatWindow:setParent(modules.game_interface.getRootPanel())
    chatWindow:addAnchor(AnchorTop, 'parent', AnchorTop)
    chatWindow:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    if not chatLocked then
      chatWindow:setDraggable(true)
    end
    chatWindow:setMarginLeft(g_settings.getNumber('chat_x', 250))
    chatWindow:setMarginTop(g_settings.getNumber('chat_y', 50))
    local chatSize = g_settings.getPoint('chat_size', nil)
    if chatSize.x == 0 and chatSize.y == 0 then
      chatSize = "450 250"
    else
      chatSize = chatSize.x .." "..chatSize.y
    end
    chatWindow:setSize(chatSize)
    chatWindow:setMarginRight(0)
    chatWindow.rB:setEnabled(true)
    chatWindow.rB2:setEnabled(true)
    chatWindow.rB3:setEnabled(true)
    chatWindow.rB4:setEnabled(true)
    modules.game_interface.getRootPanel():getChildById('bottomSplitter'):setEnabled(false)
    chatWindow:move(g_settings.getNumber('chat_x', 250), g_settings.getNumber('chat_y', 50))
  end

  if not isActive() then
    if modules.game_battle and modules.game_battle.updateUIButton then modules.game_battle.updateUIButton("chatDisabled") end
    if modules.game_playeractionbar and modules.game_playeractionbar.updateUI then modules.game_playeractionbar.updateUI("chatDisabled") end
    if modules.game_pokemoves and modules.game_pokemoves.updateUI then modules.game_pokemoves.updateUI("chatDisabled") end
    if modules.game_pokebar and modules.game_pokebar.updateUI then modules.game_pokebar.updateUI("chatDisabled") end
  else
    if modules.game_battle and modules.game_battle.updateUIButton then modules.game_battle.updateUIButton("chatEnabled") end
    if modules.game_playeractionbar and modules.game_playeractionbar.updateUI then modules.game_playeractionbar.updateUI("chatEnabled") end
    if modules.game_pokemoves and modules.game_pokemoves.updateUI then modules.game_pokemoves.updateUI("chatEnabled") end
    if modules.game_pokebar and modules.game_pokebar.updateUI then modules.game_pokebar.updateUI("chatEnabled") end
  end

  if classic then
    chatWindow:focus()
  end
end

function focusChatChannel(loggout)
  if loggout then
    return
  end
  chatWindow:focus()
  chatWindow.textEdit:setFocusable(true)
  chatWindow.textEdit:focus()
  chatWindow.textEdit:raise()
  chatWindow.textEdit:focus()
  local classic = g_settings.getBoolean("classicView") and not g_app.isMobile()
  if not classic then
    --chatWindow:setFocusable(false)
    chatWindow:setVisible(false)
  end
  chatWindow.textEdit:setFocusable(false)
  consoleToggleChat = true
  chatActive = false
  if modules.game_battle and modules.game_battle.updateUIButton then modules.game_battle.updateUIButton("chatDisabled") end
  if modules.game_playeractionbar and modules.game_playeractionbar.updateUI then modules.game_playeractionbar.updateUI("chatDisabled") end
  if modules.game_pokemoves and modules.game_pokemoves.updateUI then modules.game_pokemoves.updateUI("chatDisabled") end
  if modules.game_pokebar and modules.game_pokebar.updateUI then modules.game_pokebar.updateUI("chatDisabled") end
end

-- In-memory only. The previous implementation queued records and flushed them to JSON under
-- /settings/chat_history, and reading those files back on login was freezing some clients. History
-- now lives for as long as the client process does: relogging still replays it, restarting does not.
local CHAT_HISTORY_MAX_RECORDS = 200 -- per character per channel; replay shows at most MAX_LINES

-- [characterKey][channelKey] = { record, ... }
local chatHistoryStore = {}

local function chatHistoryCharacterKey()
  return tostring(g_game.getWorldName() or '') .. '|' .. tostring(g_game.getCharacterName() or '')
end

local function chatHistoryChannel(characterKey, channelKey, create)
  local character = chatHistoryStore[characterKey]
  if not character then
    if not create then return nil end
    character = {}
    chatHistoryStore[characterKey] = character
  end
  local records = character[channelKey]
  if not records and create then
    records = {}
    character[channelKey] = records
  end
  return records
end

local function chatHistoryEnqueue(channelKey, record)
  local records = chatHistoryChannel(chatHistoryCharacterKey(), channelKey, true)
  records[#records + 1] = record
  -- trim from the front so the table cannot grow unbounded over a long session
  if #records > CHAT_HISTORY_MAX_RECORDS then
    local trimmed = {}
    for i = #records - CHAT_HISTORY_MAX_RECORDS + 1, #records do trimmed[#trimmed + 1] = records[i] end
    chatHistoryStore[chatHistoryCharacterKey()][channelKey] = trimmed
  end
end

function recordChatMessage(tab, speaktype, text, creatureName)
  if not speaktype then return end
  if not modules.client_options.getOption('chatHistoryEnabled') then return end
  if not g_game.isOnline() then return end
  if tab == lootTab then return end

  local tabName = tab:getText()
  local isSystem = tab == serverTab
  local isNpc = tab.npcChat or tabName == 'NPCs'
  local isPrivate = not isSystem and not isNpc
    and ((speaktype.private and not speaktype.npcChat)
      or (tab ~= defaultTab and not tab.channelId))

  if not isPrivate then return end

  chatHistoryEnqueue(tabName, {
    t = os.time(),
    c = speaktype.color,
    n = speaktype.npcChat and true or nil,
    who = creatureName,
    msg = text,
  })
end

function replayChatHistory(channelKey, tab)
  if not tab then return end
  if not modules.client_options.getOption('chatHistoryEnabled') then return end
  local panel = consoleTabBar:getTabPanel(tab)
  if not panel then return end
  local consoleBuffer = panel:getChildById('consoleBuffer')
  if not consoleBuffer or consoleBuffer:getChildCount() > 0 then return end

  local records = chatHistoryChannel(chatHistoryCharacterKey(), channelKey, false)
  if not records or #records == 0 then return end

  local startIdx = math.max(1, #records - MAX_LINES + 1)
  local showTimestamps = modules.client_options.getOption('showTimestampsInConsole')
  local today = os.date('%Y%m%d')
  for i = startIdx, #records do
    local record = records[i]
    if type(record) == 'table' and record.msg then
      local speaktype = { color = record.c or SpeakTypesSettings.say.color, npcChat = record.n }
      local text = record.msg
      if showTimestamps and record.t then
        local fmt = (os.date('%Y%m%d', record.t) == today) and '%H:%M' or '%d/%m|%H:%M'
        text = os.date(fmt, record.t) .. ' ' .. text
      end
      addTabText(text, speaktype, tab, record.who, true)
    end
  end
end

function saveChatHistoryTabs()
  local char = g_game.getCharacterName()
  if not char or char == '' then return end
  local node = g_settings.getNode('lastPrivateTabs') or {}
  local names = {}
  for key, name in pairs(channels) do
    if type(key) == 'string' then
      local tab = consoleTabBar:getTab(name)
      if tab and not tab.channelId and tab ~= defaultTab and tab ~= serverTab and tab ~= lootTab then
        names[#names + 1] = name
      end
    end
  end
  if #names > 0 then node[char] = names else node[char] = nil end
  g_settings.setNode('lastPrivateTabs', node)
end

function restoreChatHistoryTabs()
  if not modules.client_options.getOption('chatHistoryEnabled') then return end
  if defaultTab then replayChatHistory(defaultTab:getText(), defaultTab) end
  if serverTab then replayChatHistory(serverTab:getText(), serverTab) end

  local node = g_settings.getNode('lastPrivateTabs')
  local names = node and node[g_game.getCharacterName()]
  if type(names) ~= 'table' then return end
  -- pairs, not ipairs: see loadPreviewMutedTabs - g_settings arrays read back with string keys
  for _, name in pairs(names) do
    name = tostring(name)
    local tab = getTab(name)
    if not tab then
      tab = addPrivateChannel(name)
      if name == 'NPCs' then tab.npcChat = true end
    end
    replayChatHistory(name, tab)
  end
end

-- One-shot sweep of what the old disk-backed history left behind. Reading those files on login is
-- what froze some clients, so they are deleted rather than migrated.
function cleanupChatHistory()
  local legacyDir = '/settings/chat_history/'
  local ok, files = pcall(g_resources.listDirectoryFiles, legacyDir)
  if not ok or type(files) ~= 'table' then return end
  for _, filename in ipairs(files) do
    if filename:match('^chat_.*%.json$') then
      pcall(g_resources.deleteFile, legacyDir .. filename)
    end
  end
end
