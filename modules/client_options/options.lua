local defaultOptions = {
  layout = DEFAULT_LAYOUT, -- set in init.lua
  vsync = true,
  showFps = true,
  showPing = true,
  fullscreen = false,
  classicView = false,
  classicControl = not g_app.isMobile(),
  smartWalk = false,
  dash = false,
  showStatusMessagesInConsole = true,
  showEventMessagesInConsole = true,
  showInfoMessagesInConsole = true,
  showTimestampsInConsole = true,
  showLevelsInConsole = true,
  showPrivateMessagesInConsole = true,
  showPrivateMessagesOnScreen = true,
  showChatPreview = true,
  chatPreviewShowPrivate = true,
  chatPreviewMuteStopsBlink = false,
  chatPreviewDuration = 5,
  chatPreviewLines = 5,
  chatPreviewFontSize = 12,
  chatHistoryEnabled = false,
  rightPanels = 2,
  leftPanels = 1,
  topLeftPanel = false,
  topRightPanel = false,
  containerPanel = 1,
  backgroundFrameRate = 60,
  enableAudio = true,
  audioDevice = '',
  enableMusicSound = true,
  musicSoundVolume = 100,
  enableAmbientSound = true,
  ambientSoundVolume = 10,
  combatEffectOpacityOwn = 100,
  combatEffectOpacityOthers = 100,
  botSoundVolume = 0,
  enableLights = false,
  floorFading = 700,
  crosshair = 1,
  ambientLight = 100,
  optimizationLevel = 1,
  multithreadRendering = false,
  displayDisplacementNames = true,
  pokebarVersion = 3,
  displayNames = true,
  displayHealth = true,
  displayMana = false,
  displayHealthOnTop = true,
  showGuildName = true,
  showGuildIcon = true,
  hidePlayerBars = true,
  highlightThingsUnderCursor = false,
  displayText = true,
  dontStretchShrink = false,
  turnDelay = 30,
  hotkeyDelay = 30,
  fadeInTime = 500,
  fadeOutTime = 500,
  actionBarSize = 20,
  walkRightClick = false,
  leftMouseAction = 1,
  containerShiftRightClickNewWindow = true,
  turnPokemon = true,
  targetNpcs = false,
  healthColorLabel = 1,
  hudScale = 1,
  shinyIcon = false,
  shinyCorpse = false,
  pokeballOnFloor = true,
  pokeballOnIcon = true,
  pokemonInUseAlwaysOnTop = false,
  showFlyButtons = true,
  pokebarScaleMode = 1,
  pokebarSizeMode = 2,
  pokebarShowPortrait = true,
  pokebarShowHpPercent = true,
  pokebarShowCooldownText = true,
  bossHealthBarPosition = 1,
  conditionBarPosition = 1,
  conditionBarOrientation = 1,
  notificationPosition = 2,
  notificationDuration = 8,
  showPokebarHotkeys = true,
  showCreatureGhostOpacity = true,
  hideTipsMessages = false,
  ignorePaymentsAlerts = false,
  walkFirstStepDelay = 200,
  walkTurnDelay = 100,
  walkStairsDelay = 50,
  walkTeleportDelay = 200,
  walkCtrlTurnDelay = 150,
  gameHudScale = 1,
  sidePanelOpacity = 100,
  sidePanelFadeDelay = 3,

  topBar = false,

  actionbarBottom1 = true,
  actionbarBottom2 = false,
  actionbarBottom3 = false,

  actionbarLeft1 = false,
  actionbarLeft2 = false,
  actionbarLeft3 = false,

  actionbarRight1 = false,
  actionbarRight2 = false,
  actionbarRight3 = false,

  actionbarLock = false,

  profile = 1
}

-- Top Icons: a topbar tem TRES grupos, nesta ordem, todos dentro do middleGameButtonsPanel:
--
--   [fixos da esquerda] | [customizaveis do jogador] | [fixos da direita]
--
-- Os fixos NAO sao customizaveis em hipotese nenhuma: nao aparecem na lista de disponiveis, nao
-- podem ser removidos nem reordenados, e applyTopIconVisibility forca a visibilidade deles.
local TOP_SEPARATOR_LEFT_ID = "topFixedSeparatorLeft"
local TOP_SEPARATOR_RIGHT_ID = "topFixedSeparatorRight"

local topIconLeftFixedButtons = {
  { id = "profileButton",  label = "Profile" },
  { id = "gamePassButton", label = "Battle Pass" },
  { id = "storeButton",    label = "Store" }
}

local topIconRightFixedButtons = {
  { id = "mailTopButton", label = "Mail" },
  { id = "optionsButton", label = "Options" },
  { id = "audioButton",   label = "Sound" },
  { id = "logoutButton",  label = "Exit" }
}

-- All toggleable buttons with display names (only middleGameButtonsPanel buttons)
local topIconAllButtons = {
  { id = "battleButton",              label = "Battle" },
  { id = "inventoryButton",           label = "Inventory" },
  { id = "vipListButton",             label = "VIP List" },
  { id = "minimapButton",             label = "Minimap" },
  { id = "pokemonButton",             label = "Pokemon" },
  { id = "guildButton",               label = "Guild" },
  { id = "calendarButton",            label = "Calendar" },
  { id = "dailiesTopButton",          label = "Dailies" },
  { id = "pokemonsTopButton",         label = "Pokemons" },
  { id = "globalBuffButton",          label = "Global Buff" },
  { id = "analyzerTopButton",         label = "Analyzer" },
  { id = "gameTaskTopButton",         label = "Tasks" },
  { id = "stashTopButton",            label = "Hunt Stash" },
  { id = "duelTopButton",             label = "Duel" },
  { id = "pbarButton",                label = "Pokemon Bar" },
  { id = "preyTopButton",             label = "Prey" },
  { id = "linkedTasksButton",         label = "Linked Tasks" },
}

-- Lookup label by button id
local topIconLabelMap = {}
for _, btn in ipairs(topIconAllButtons) do
  topIconLabelMap[btn.id] = btn.label
end

-- Conjunto dos fixos, para o ordenador saber o que NAO pertence a faixa do meio.
local topIconFixedSet = {}
for _, btn in ipairs(topIconLeftFixedButtons) do topIconFixedSet[btn.id] = true end
for _, btn in ipairs(topIconRightFixedButtons) do topIconFixedSet[btn.id] = true end

-- Current displayed order (list of button ids); persisted as JSON
local topIconDisplayed = {}
local topIconsPanel = nil
local topIconsHighlightActive = false
local loadTopIconSettings
local saveTopIconSettings
local refreshTopIconLists

local optionsWindow
local optionsButton
local optionsTabBar
local options = {}
local extraOptions = {}
local optionsLoading = false
local generalPanel
local interfacePanel
local consolePanel
local graphicsPanel
audioPanel = nil
local pokebarPanel
local broadcastPanel
local extrasPanel
local audioButton

local hudScaleIndex = {1, 1.25, 1.5, 1.75, 2}

modules.client_hotkeys.registerHotkeyCallback("SETTINGS",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        toggle()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

function init()
  optionsLoading = true
  -- pre-0-option configs stored rightPanels as the panel count; now it is count+1 like leftPanels
  if not g_settings.getBoolean("rightPanelsIndexed") then
    local legacy = g_settings.getNumber("rightPanels")
    if legacy > 0 then
      g_settings.set("rightPanels", math.min(legacy + 1, 5))
    end
    g_settings.set("rightPanelsIndexed", true)
  end

  -- pre-split configs dimmed every effect with one slider; carry that value into both combat ones
  if g_settings.exists('gameOpacity') then
    local legacy = g_settings.getNumber('gameOpacity')
    g_settings.set('combatEffectOpacityOwn', legacy)
    g_settings.set('combatEffectOpacityOthers', legacy)
    g_settings.remove('gameOpacity')
  end

  for k,v in pairs(defaultOptions) do
    g_settings.setDefault(k, v)
    options[k] = v
  end
  for _, v in ipairs(g_extras.getAll()) do
	  extraOptions[v] = g_extras.get(v)
    g_settings.setDefault("extras_" .. v, extraOptions[v])
  end

  optionsWindow = g_ui.displayUI('options')
  optionsWindow:hide()

  optionsTabBar = optionsWindow:getChildById('optionsTabBar')
  optionsTabBar:setContentWidget(optionsWindow:getChildById('optionsTabContent'))

  g_keyboard.bindKeyDown('Ctrl+Shift+F', function() toggleOption('fullscreen') end)
  g_keyboard.bindKeyDown('Ctrl+N', toggleDisplays)

  interfacePanel = g_ui.loadUI('interface')
  optionsTabBar:addTab(tr('Interface'), interfacePanel)

  generalPanel = g_ui.loadUI('game')
  optionsTabBar:addTab(tr('Game'), generalPanel)

  pokebarPanel = g_ui.loadUI('pokebar')
  optionsTabBar:addTab(tr('Pokebar'), pokebarPanel)

  consolePanel = g_ui.loadUI('console')
  optionsTabBar:addTab(tr('Console'), consolePanel)

  graphicsPanel = g_ui.loadUI('graphics')
  optionsTabBar:addTab(tr('Graphics'), graphicsPanel)

  audioPanel = g_ui.loadUI('audio')
  optionsTabBar:addTab(tr('Audio'), audioPanel)


  extrasPanel = g_ui.createWidget('OptionPanel')
  for _, v in ipairs(g_extras.getAll()) do
    local extrasButton = g_ui.createWidget('OptionCheckBox')
    extrasButton:setId(v)
    --extrasButton.optionLabel:setText(g_extras.getDescription(v))
    extrasPanel:addChild(extrasButton)
  end
  if not g_game.getFeature(GameNoDebug) and not g_app.isMobile() then
    --optionsTabBar:addTab(tr('Extras'), extrasPanel, '/images/optionstab/extras')
  end

  broadcastPanel = g_ui.loadUI('broadcasts')
  optionsTabBar:addTab(tr('Messages'), broadcastPanel)
  topIconsPanel = g_ui.loadUI('topicons')
  optionsTabBar:addTab(tr('Top Icons'), topIconsPanel)
  initTopIcons()

  optionsTabBar:addButton(tr('Hotkeys') .. ' (Ctrl+K)', function()
    modules.client_hotkeys.toggle()
  end)

  optionsTabBar.onTabChange = function(tabBar, tab)
    if tab and tab:getText() == tr('Top Icons') then
      highlightTopBar(true)
    else
      highlightTopBar(false)
    end
  end

  optionsButton = modules.client_topmenu.addMiddleGameToggleButton('optionsButton', tr('Options'), '/images/ui/topbuttons/icons/options', toggle)
  audioButton = modules.client_topmenu.addMiddleGameToggleButton('audioButton', tr('Audio'), '/images/ui/topbuttons/icons/audio', function() toggleOption('enableAudio') end)
  if g_app.isMobile() then
    audioButton:hide()
  end

  addEvent(function() setup() end)

  connect(g_game, { onGameStart = online,
                     onGameEnd = offline })
  optionsLoading = false
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                     onGameEnd = offline })

  g_keyboard.unbindKeyDown('Ctrl+Shift+F')
  optionsWindow:destroy()
  optionsButton:destroy()
  audioButton:destroy()
end

function refreshAudioDevices()
  local panel = audioPanel:recursiveGetChildById('audioDevicePanel')
  if g_sounds == nil then
    panel:setVisible(false)
    return
  end
  local combobox = audioPanel:recursiveGetChildById('audioDevice')
  local devices = g_sounds.getDevices()
  panel:setVisible(#devices > 0)
  if #devices == 0 then
    return
  end
  combobox:clearOptions()
  combobox:addOption(tr('System default'), '', true)
  for _, name in ipairs(devices) do
    local label = name:gsub('^OpenAL Soft on ', '')
    combobox:addOption(label, name)
  end
  local current = getOption('audioDevice')
  if current ~= '' then
    combobox:setCurrentOptionByData(current, true)
  end
end

function onAudioDeviceChange(combobox)
  local option = combobox:getCurrentOption()
  setOption('audioDevice', option and option.data or '')
end

function setup()
  -- load options
  for k,v in pairs(defaultOptions) do
    if type(v) == 'boolean' then
      setOption(k, g_settings.getBoolean(k), true)
    elseif type(v) == 'number' then
      setOption(k, g_settings.getNumber(k), true)
    elseif type(v) == 'string' then
      setOption(k, g_settings.getString(k), true)
    end
  end

  for _, v in ipairs(g_extras.getAll()) do
    g_extras.set(v, g_settings.getBoolean("extras_" .. v))
    local widget = extrasPanel:recursiveGetChildById(v)
    if widget then
      widget:setChecked(g_extras.get(v))
    end
  end

  refreshAudioDevices()

  if g_game.isOnline() then
    online()
  end
end

function toggle()
  if optionsWindow:isVisible() then
    hide()
  else
    show()
  end
end

function show()
    refreshAudioDevices()
    optionsWindow:show()
    optionsWindow:raise()
    optionsWindow:focus()
    g_uistates.push(optionsWindow)
    -- Re-apply highlight if currently on Top Icons tab
    local currentTab = optionsTabBar:getCurrentTab()
    if currentTab and currentTab:getText() == tr('Top Icons') then
      highlightTopBar(true)
    end
end

function hide()
    highlightTopBar(false)
    g_uistates.remove(optionsWindow)
    optionsWindow:hide()
end

function highlightTopBar(enabled)
  if not modules.client_topmenu then return end
  local topMenu = modules.client_topmenu.getTopMenu()
  if not topMenu then return end
  local middlePanel = topMenu:getChildById('middleGameButtonsPanel')
  if not middlePanel then return end

  if enabled and not topIconsHighlightActive then
    topIconsHighlightActive = true
    topMenu:setDrawOnTopOfBlur(true)
    middlePanel:setBlurHighlight(true)
    middlePanel:setBorderWidth(2)
    middlePanel:setBorderColor('#269bf3')
  elseif not enabled and topIconsHighlightActive then
    topIconsHighlightActive = false
    topMenu:setDrawOnTopOfBlur(false)
    middlePanel:setBlurHighlight(false)
    middlePanel:setBorderWidth(0)
  end
end

function toggleDisplays()
  if options['displayHealthOnTop'] then
    setOption('displayHealthOnTop', false)
  elseif options['displayNames'] and options['displayHealth'] then
    setOption('displayNames', false)
  elseif options['displayHealth'] then
    setOption('displayHealth', false)
  else
    setOption('displayHealthOnTop', true)
    setOption('displayHealth', true)
    setOption('displayNames', true)
  end
end

function toggleOption(key)
  setOption(key, not getOption(key))
end

function setOption(key, value, force)
  if extraOptions[key] ~= nil then
    g_extras.set(key, value)
    g_settings.set("extras_" .. key, value)
    if key == "debugProxy" and modules.game_proxy then
      if value then
        modules.game_proxy.show()
      else
        modules.game_proxy.hide()
      end
    end
    return
  end

  if optionsLoading then
    return
  end

  if modules.game_interface == nil then
    return
  end

  if not force and options[key] == value then return end
  local gameMapPanel = modules.game_interface.getMapPanel()

  if key == 'vsync' then
    g_window.setVerticalSync(value)
  elseif key == 'walkRightClick' then
    if value then
    else
    end
    if options[key] then
      options[key] = false
    else
      options[key] = true
    end
  elseif key == 'turnPokemon' then
    options[key] = value
  elseif key == 'healthColorLabel' then
    if options[key] then
      g_game.setColorHealth(value)
    end
  elseif key == "hudScale" then
    if hudScaleIndex[value] then
      options[key] = value
      scheduleEvent(function()
        updateHudScale()
      end, 100)
    end
  elseif key == 'showFps' then
    modules.client_topmenu.setFpsVisible(value)
    if modules.game_stats and modules.game_stats.ui.fps then
      modules.game_stats.ui.fps:setVisible(value)
    end
  elseif key == 'showPing' then
    modules.client_topmenu.setPingVisible(value)
    if modules.game_stats and modules.game_stats.ui.ping then
      modules.game_stats.ui.ping:setVisible(value)
    end
  elseif key == 'fullscreen' then
    g_window.setFullscreen(value)
  elseif key == 'enableAudio' then
    if g_sounds ~= nil then
      g_sounds.setAudioEnabled(value)
    end
    if value then
      audioButton:setIcon('/images/ui/topbuttons/icons/audio')
    else
      audioButton:setIcon('/images/ui/topbuttons/icons/audio_mute')
    end
  elseif key == 'audioDevice' then
    if g_sounds ~= nil then
      g_sounds.setDevice(value)
    end
  elseif key == 'enableAmbientSound' then
    if g_sounds ~= nil then
      g_sounds.getChannel(SoundChannels.Ambient):setEnabled(value)
    end
  elseif key == 'ambientSoundVolume' then
    if g_sounds ~= nil then
      g_sounds.getChannel(SoundChannels.Ambient):setGain(value/100)
    end
    audioPanel.ambientSoundPanel:getChildById('ambientSoundVolumeLabel'):setText(tr('Ambient volume: %d', value))
  elseif key == 'enableMusicSound' then
    if g_sounds ~= nil then
      g_sounds.getChannel(SoundChannels.Music):setEnabled(value)
    end
  elseif key == 'musicSoundVolume' then
    if g_sounds ~= nil then
      g_sounds.getChannel(SoundChannels.Music):setGain(value/100)
    end
    audioPanel.musicSoundPanel:getChildById('musicSoundVolumeLabel'):setText(tr('Music volume: %d', value))
  elseif key == 'botSoundVolume' then
    if g_sounds ~= nil then
      g_sounds.getChannel(SoundChannels.Bot):setGain(0)
    end
  elseif key == 'backgroundFrameRate' then
    local text, v = value, value
    if value <= 0 or value >= 201 then text = 'max' v = 0 end
    graphicsPanel.frameRatePanel:getChildById('backgroundFrameRateLabel'):setText(tr('Game framerate limit: %s', text))
    g_app.setMaxFps(v)
  elseif key == 'enableLights' then
    gameMapPanel:setDrawLights(value and options['ambientLight'] < 100)
    graphicsPanel.ambientLightPanel:getChildById('ambientLight'):setEnabled(value)
    graphicsPanel.ambientLightPanel:getChildById('ambientLightLabel'):setEnabled(value)
  elseif key == 'floorFading' then
    gameMapPanel:setFloorFading(value)
    interfacePanel:getChildById('floorFadingLabel'):setText(tr('Floor fading: %s ms', value))
  elseif key == 'crosshair' then
    if value == 1 then
      gameMapPanel:setCrosshair("")
    elseif value == 2 then
      gameMapPanel:setCrosshair("/images/crosshair/default.png")
    elseif value == 3 then
      gameMapPanel:setCrosshair("/images/crosshair/full.png")
    end
  elseif key == 'ambientLight' then
    graphicsPanel.ambientLightPanel:getChildById('ambientLightLabel'):setText(tr('Ambient light: %s%%', tostring(value)))
    gameMapPanel:setMinimumAmbientLight(value/100)
    gameMapPanel:setDrawLights(options['enableLights'] and value < 100)
  elseif key == 'combatEffectOpacityOwn' then
    graphicsPanel.combatEffectOpacityOwnPanel:getChildById('combatEffectOpacityOwnLabel'):setText(tr('Opacity Combat Effects Own: %s%%', tostring(value)))
    g_game.setCombatEffectOpacityOwn(value/100)
  elseif key == 'combatEffectOpacityOthers' then
    graphicsPanel.combatEffectOpacityOthersPanel:getChildById('combatEffectOpacityOthersLabel'):setText(tr('Opacity Combat Effects Others: %s%%', tostring(value)))
    g_game.setCombatEffectOpacityOthers(value/100)
  elseif key == 'optimizationLevel' then
    g_adaptiveRenderer.setLevel(value - 2)
  elseif key == 'displayNames' then
    gameMapPanel:setDrawNames(value)
  elseif key == 'displayHealth' then
    gameMapPanel:setDrawHealthBars(value)
  elseif key == 'displayMana' then
    gameMapPanel:setDrawManaBar(false)
  elseif key == 'showGuildName' then
    g_game.setShowGuildName(value)
  elseif key == 'showGuildIcon' then
    g_game.setShowGuildIcon(value)
  elseif key == 'shinyIcon' then
    g_game.setActivatedShinyIcon(value)
  elseif key == 'pokeballOnFloor' then
    g_game.setDrawPokeballIconsOnFloor(value)
  elseif key == 'pokeballOnIcon' then
    g_game.setDrawPokeballIconsOnWindow(value)
  elseif key == 'hideTipsMessages' then
    options[key] = value
  elseif key == 'ignorePaymentsAlerts' then
    options[key] = value
  elseif key == 'shinyCorpse' then
    g_game.setActivatedShinyCorpse(value)
  elseif key == 'showCreatureGhostOpacity' then
    g_game.setShowCreatureGhostOpacity(not value)
  elseif key == 'displayHealthOnTop' then
    gameMapPanel:setDrawHealthBarsOnTop(value)
  elseif key == 'hidePlayerBars' then
    gameMapPanel:setDrawPlayerBars(value)
  elseif key == 'displayText' then
    gameMapPanel:setDrawTexts(value)
  elseif key == 'dontStretchShrink' then
    addEvent(function()
      modules.game_interface.updateStretchShrink()
    end)
  elseif key == 'fadeInTime' then
    interfacePanel.fadeInLabelPanel:getChildById('fadeInLabel'):setText(
      value == 0 and tr('Fade In: Disabled') or tr('Fade In: %s ms', value))
  elseif key == 'fadeOutTime' then
    interfacePanel.fadeOutLabelPanel:getChildById('fadeOutLabel'):setText(
      value == 0 and tr('Fade Out: Disabled') or tr('Fade Out: %s ms', value))
  elseif key == 'actionBarSize' then
    interfacePanel.actionBarLabelPanel:getChildById('actionBarLabel'):setText(tr('Action Bar Slots: %s', value))
    modules.game_playeractionbar.showSlots(value)
  elseif key == 'sidePanelOpacity' then
    interfacePanel.sidePanelOpacityPanel:getChildById('sidePanelOpacityLabel'):setText(
      value >= 100 and tr('Side panel opacity: Disabled') or tr('Side panel opacity: %s%%', value))
  elseif key == 'sidePanelFadeDelay' then
    interfacePanel.sidePanelFadeDelayPanel:getChildById('sidePanelFadeDelayLabel'):setText(
      tr('Side panel fade delay: %ss', value))
  elseif key == 'pokebarScaleMode' then
    if modules.game_pokebar then
      modules.game_pokebar.onScaleModeChanged(value)
    end
  elseif key == 'pokebarSizeMode' then
    if modules.game_pokebar and modules.game_pokebar.onSizeModeChanged then
      modules.game_pokebar.onSizeModeChanged(value)
    end
  elseif key == 'pokebarShowPortrait' then
    if modules.game_pokebar and modules.game_pokebar.setShowPortrait then
      modules.game_pokebar.setShowPortrait(value)
    end
  elseif key == 'pokebarShowHpPercent' then
    if modules.game_pokebar and modules.game_pokebar.setShowHpPercent then
      modules.game_pokebar.setShowHpPercent(value)
    end
  elseif key == 'pokebarShowCooldownText' then
    if modules.game_pokebar and modules.game_pokebar.setShowCooldownText then
      modules.game_pokebar.setShowCooldownText(value)
    end
  elseif key == 'bossHealthBarPosition' then
    if modules.game_bosshealth then
      modules.game_bosshealth.setPosition(value)
    end
  elseif key == 'conditionBarPosition' then
    if modules.game_pokemoves and modules.game_pokemoves.setConditionBarPosition then
      modules.game_pokemoves.setConditionBarPosition(value)
    end
  elseif key == 'conditionBarOrientation' then
    if modules.game_pokemoves and modules.game_pokemoves.setConditionBarOrientation then
      modules.game_pokemoves.setConditionBarOrientation(value)
    end
  elseif key == 'notificationPosition' then
    if modules.game_notifications then
      modules.game_notifications.setPosition(value)
    end
  elseif key == 'notificationDuration' then
    if broadcastPanel then
      local label = broadcastPanel:recursiveGetChildById('notificationDurationLabel')
      if label then label:setText(tr('Notification duration: %ss', value)) end
    end
  elseif key == 'showPokebarHotkeys' then
    if modules.game_pokebar and modules.game_pokebar.setShowHotkeys then
      modules.game_pokebar.setShowHotkeys(value)
    end
  elseif key == 'showFlyButtons' then
    if modules.game_flycontrols then
      modules.game_flycontrols.setEnabled(value)
    end
  elseif key == 'chatPreviewDuration' then
    if consolePanel then
      local label = consolePanel:recursiveGetChildById('chatPreviewDurationLabel')
      if label then label:setText(tr('Chat preview duration: %ss', value)) end
    end
  elseif key == 'chatPreviewLines' then
    if consolePanel then
      local label = consolePanel:recursiveGetChildById('chatPreviewLinesLabel')
      if label then label:setText(tr('Chat preview lines: %s', value)) end
    end
  elseif key == 'chatPreviewFontSize' then
    if consolePanel then
      local label = consolePanel:recursiveGetChildById('chatPreviewFontSizeLabel')
      if label then label:setText(tr('Chat preview text size: %s', value)) end
    end
  end

  -- change value for keybind updates
  for _,panel in pairs(optionsTabBar:getTabsPanel()) do
    local widget = panel:recursiveGetChildById(key)
    if widget then
      -- Check if it's an OptionCheckBox (Panel with SwitchBox inside)
      local switchBox = widget:getChildById('switchBox')
      if switchBox and switchBox:getStyle().__class == 'UICheckBox' then
        switchBox:setChecked(value)
        -- Trigger visual update for the switch
        local checked = value
        local margin = checked and 20 or 2
        local imageSource = checked and "/images/general_ui/icons/base_slider_selected" or "/images/general_ui/icons/base_slider"
        local sliderButton = switchBox.sliderButton
        if sliderButton then
          sliderButton:setMarginLeft(margin)
        end
        switchBox:setImageSource(imageSource)
      elseif widget:getStyle().__class == 'UICheckBox' then
        widget:setChecked(value)
      elseif widget:getStyle().__class == 'UIScrollBar' then
        widget:setValue(value)
      elseif widget:getStyle().__class == 'UIComboBox' then
        if type(value) == "string" then
          widget:setCurrentOption(value, true)
          break
        end
        if value == nil or value < 1 then
          value = 1
        end
        if widget.currentIndex ~= value then
          widget:setCurrentIndex(value, true)
        end
      end
      break
    end
  end

  g_settings.set(key, value)
  options[key] = value

  if key == "profile" then
    modules.client_profiles.onProfileChange()
  end

  if key == 'classicView' or key == 'rightPanels' or key == 'leftPanels' then
    modules.game_interface.refreshViewMode()
  end

  if key == 'topLeftPanel' or key == 'topRightPanel' then
    modules.game_interface.updateHorizontalPanels()
  end

  if key == 'sidePanelOpacity' or key == 'sidePanelFadeDelay' then
    interfacePanel.sidePanelFadeDelayPanel:setEnabled(options['sidePanelOpacity'] < 100)
    modules.game_interface.applySidePanelOpacity()
  end

  -- the loop shape is fixed in run(), so compare against what is actually running, not against
  -- `force`: the widget-sync loop re-enters setOption unforced on every boot
  if key == 'multithreadRendering' and value ~= g_app.isMultithreadRendering() then
    g_settings.save()
    displayAllianceInfoBox(tr('Graphics'), tr('Please reopen the client for the changes to take effect.'))
  end

  if key == 'topBar' then
    --modules.game_topbar.show()
  end
end

function getOption(key)
  return options[key]
end

function addTab(name, panel, icon)
  optionsTabBar:addTab(name, panel, icon)
end

function addButton(name, func, icon)
  optionsTabBar:addButton(name, func, icon)
end

-- hide/show

function online()
  setLightOptionsVisibility(not g_game.getFeature(GameForceLight))
  topIconDisplayed = loadTopIconSettings()
  refreshTopIconLists()
  addEvent(function()
    applyTopIconVisibility()
    applyTopIconOrder()
  end)
end

function offline()
  saveTopIconSettings()
  setLightOptionsVisibility(true)
end

-- classic view

-- graphics
function setLightOptionsVisibility(value)
  graphicsPanel:getChildById('enableLights'):setEnabled(value)
  graphicsPanel.ambientLightPanel:getChildById('ambientLightLabel'):setEnabled(value)
  graphicsPanel.ambientLightPanel:getChildById('ambientLight'):setEnabled(value)
  interfacePanel:getChildById('floorFading'):setEnabled(value)
  interfacePanel:getChildById('floorFadingLabel'):setEnabled(value)
  interfacePanel:getChildById('floorFadingLabel2'):setEnabled(value)
end

function updateHealthColor()
  local selectColor = g_settings.getNumber('healthColorLabel', 1)
  g_game.setColorHealth(selectColor)
end

function updateHudScale()
  local hudScale = g_settings.getNumber('hudScale', 1)
  if hudScaleIndex[hudScale] then
    g_app.scale(hudScaleIndex[hudScale])
  end
end

-- =====================================================
-- Top Icons dual-panel management
-- =====================================================

local function getDefaultDisplayedIds()
  local ids = {}
  for _, btn in ipairs(topIconAllButtons) do
    table.insert(ids, btn.id)
  end
  return ids
end

loadTopIconSettings = function()
  if not modules.client_profiles then return getDefaultDisplayedIds() end
  local settingsFile = modules.client_profiles.getSettingsFilePath('topicons.json')
  if g_resources.fileExists(settingsFile) then
    local ok, data = pcall(function()
      return json.decode(g_resources.readFileContents(settingsFile))
    end)
    if ok and type(data) == 'table' then
      local displayed = data.displayed or {}
      local hidden = data.hidden or {}
      local valid = {}
      local seen = {}
      for _, id in ipairs(displayed) do
        if topIconLabelMap[id] and not seen[id] then
          table.insert(valid, id)
          seen[id] = true
        end
      end
      for _, id in ipairs(hidden) do
        seen[id] = true
      end
      -- Append only truly new buttons (not in displayed nor hidden)
      for _, btn in ipairs(topIconAllButtons) do
        if not seen[btn.id] then
          table.insert(valid, btn.id)
        end
      end
      return valid
    end
  end
  return getDefaultDisplayedIds()
end

saveTopIconSettings = function()
  if not modules.client_profiles then return end
  local settingsFile = modules.client_profiles.getSettingsFilePath('topicons.json')
  local displayedSet = {}
  for _, id in ipairs(topIconDisplayed) do
    displayedSet[id] = true
  end
  local hidden = {}
  for _, btn in ipairs(topIconAllButtons) do
    if not displayedSet[btn.id] then
      table.insert(hidden, btn.id)
    end
  end
  local data = { displayed = topIconDisplayed, hidden = hidden }
  local ok, result = pcall(function() return json.encode(data, 2) end)
  if ok then
    g_resources.writeFileContents(settingsFile, result)
  end
end

local function getAvailableIds()
  local displayedSet = {}
  for _, id in ipairs(topIconDisplayed) do
    displayedSet[id] = true
  end
  local available = {}
  for _, btn in ipairs(topIconAllButtons) do
    if not displayedSet[btn.id] then
      table.insert(available, btn.id)
    end
  end
  return available
end

refreshTopIconLists = function()
  if not topIconsPanel then return end

  local displayedList = topIconsPanel:recursiveGetChildById('displayedList')
  local availableList = topIconsPanel:recursiveGetChildById('availableList')
  if not displayedList or not availableList then return end

  -- Clear both lists
  local children
  children = displayedList:getChildren()
  for i = #children, 1, -1 do
    children[i]:destroy()
  end
  children = availableList:getChildren()
  for i = #children, 1, -1 do
    children[i]:destroy()
  end

  -- Fixos da esquerda, no topo. Sao TopIconFixedItem: nao focavel e sem `buttonId`, entao
  -- mover/remover (que exigem os dois) nunca os alcancam.
  for _, btn in ipairs(topIconLeftFixedButtons) do
    local item = g_ui.createWidget('TopIconFixedItem', displayedList)
    item:setText(tr(btn.label))
    item:setId('topicon_' .. btn.id)
  end

  -- Add displayed items
  for _, id in ipairs(topIconDisplayed) do
    local label = topIconLabelMap[id]
    if label then
      local item = g_ui.createWidget('TopIconItem', displayedList)
      item:setText(tr(label))
      item:setId('topicon_' .. id)
      item.buttonId = id
    end
  end

  -- Fixos da direita, no fim — a lista espelha a ordem real da topbar.
  for _, btn in ipairs(topIconRightFixedButtons) do
    local item = g_ui.createWidget('TopIconFixedItem', displayedList)
    item:setText(tr(btn.label))
    item:setId('topicon_' .. btn.id)
  end

  -- Add available items
  local available = getAvailableIds()
  for _, id in ipairs(available) do
    local label = topIconLabelMap[id]
    if label then
      local item = g_ui.createWidget('TopIconItem', availableList)
      item:setText(tr(label))
      item:setId('topicon_' .. id)
      item.buttonId = id
    end
  end
end

function applyTopIconVisibility()
  local displayedSet = {}
  for _, id in ipairs(topIconDisplayed) do
    displayedSet[id] = true
  end

  for _, btn in ipairs(topIconAllButtons) do
    local button = modules.client_topmenu.getButton(btn.id)
    if button then
      button:setVisible(displayedSet[btn.id] == true)
    end
  end

  -- Fixos sao forcados VISIVEIS. Sem isto, um topicons.json antigo (quando storeButton e
  -- mailTopButton ainda eram customizaveis) poderia deixar um fixo escondido para sempre: o laco
  -- acima nao alcanca mais esses ids e nada os traria de volta.
  local function forceVisible(list)
    for _, btn in ipairs(list) do
      local button = modules.client_topmenu.getButton(btn.id)
      if button then
        button:setVisible(true)
      end
    end
  end
  forceVisible(topIconLeftFixedButtons)
  forceVisible(topIconRightFixedButtons)
end

function applyTopIconOrder()
  if not modules.client_topmenu then return end
  local panel = modules.client_topmenu.getTopMenu()
  if not panel then return end
  local middlePanel = panel:getChildById('middleGameButtonsPanel')
  if not middlePanel then return end

  local separatorLeft = modules.client_topmenu.addMiddleSeparator(TOP_SEPARATOR_LEFT_ID)
  local separatorRight = modules.client_topmenu.addMiddleSeparator(TOP_SEPARATOR_RIGHT_ID)

  local idx = 0
  local function place(id)
    local button = middlePanel:getChildById(id)
    if button then
      idx = idx + 1
      button.index = idx
      return true
    end
    return false
  end

  -- 1) fixos da esquerda
  local leftCount = 0
  for _, btn in ipairs(topIconLeftFixedButtons) do
    if place(btn.id) then leftCount = leftCount + 1 end
  end

  -- 2) divisor
  if separatorLeft then
    idx = idx + 1
    separatorLeft.index = idx
  end

  -- 3) customizaveis, na ordem escolhida pelo jogador
  local middleVisible = 0
  local placed = {}
  for _, id in ipairs(topIconDisplayed) do
    if place(id) then
      placed[id] = true
      middleVisible = middleVisible + 1
    end
  end

  -- 3b) botoes do meio que nao estao em NENHUMA lista (ex.: huntFinderButton, linkedTasksButton).
  -- Sem isto eles caem no `index or 1000` do sort e vao parar DEPOIS do grupo fixo da direita —
  -- ou seja, do lado de fora do Logout. Ficam na faixa do meio, no fim, sem virar customizaveis.
  for _, child in ipairs(middlePanel:getChildren()) do
    local id = child:getId()
    if not child.isTopSeparator and not topIconFixedSet[id] and not placed[id] then
      idx = idx + 1
      child.index = idx
      if child:isExplicitlyVisible() then
        middleVisible = middleVisible + 1
      end
    end
  end

  -- 4) divisor
  if separatorRight then
    idx = idx + 1
    separatorRight.index = idx
  end

  -- 5) fixos da direita
  local rightCount = 0
  for _, btn in ipairs(topIconRightFixedButtons) do
    if place(btn.id) then rightCount = rightCount + 1 end
  end

  -- Um divisor so faz sentido com conteudo dos DOIS lados. Sem isto: faixa do meio vazia deixaria
  -- dois divisores colados, e um grupo fixo faltando (modulo nao carregado) deixaria um divisor
  -- solto na ponta.
  if separatorLeft then
    separatorLeft:setVisible(leftCount > 0 and (middleVisible > 0 or rightCount > 0))
  end
  if separatorRight then
    separatorRight:setVisible(rightCount > 0 and middleVisible > 0)
  end

  -- Reorder children by index
  local children = middlePanel:getChildren()
  table.sort(children, function(a, b)
    return (a.index or 1000) < (b.index or 1000)
  end)
  middlePanel:reorderChildren(children)
end

function initTopIcons()
  topIconDisplayed = loadTopIconSettings()
  refreshTopIconLists()
end

function topIconMoveUp()
  if not topIconsPanel then return end
  local displayedList = topIconsPanel:recursiveGetChildById('displayedList')
  if not displayedList then return end
  local focused = displayedList:getFocusedChild()
  if not focused or not focused.buttonId then return end

  local pos = nil
  for i, id in ipairs(topIconDisplayed) do
    if id == focused.buttonId then pos = i break end
  end
  if not pos or pos <= 1 then return end

  local movedId = focused.buttonId
  topIconDisplayed[pos], topIconDisplayed[pos - 1] = topIconDisplayed[pos - 1], topIconDisplayed[pos]
  refreshTopIconLists()
  applyTopIconOrder()

  local function restoreFocus()
    local item = displayedList:getChildById('topicon_' .. movedId)
    if item then
      displayedList:focusChild(item)
      displayedList:ensureChildVisible(item)
    end
    disconnect(displayedList, 'onLayoutUpdate', restoreFocus)
  end
  connect(displayedList, 'onLayoutUpdate', restoreFocus)
end

function topIconMoveDown()
  if not topIconsPanel then return end
  local displayedList = topIconsPanel:recursiveGetChildById('displayedList')
  if not displayedList then return end
  local focused = displayedList:getFocusedChild()
  if not focused or not focused.buttonId then return end

  local pos = nil
  for i, id in ipairs(topIconDisplayed) do
    if id == focused.buttonId then pos = i break end
  end
  if not pos or pos >= #topIconDisplayed then return end

  local movedId = focused.buttonId
  topIconDisplayed[pos], topIconDisplayed[pos + 1] = topIconDisplayed[pos + 1], topIconDisplayed[pos]
  refreshTopIconLists()
  applyTopIconOrder()

  local function restoreFocus()
    local item = displayedList:getChildById('topicon_' .. movedId)
    if item then
      displayedList:focusChild(item)
      displayedList:ensureChildVisible(item)
    end
    disconnect(displayedList, 'onLayoutUpdate', restoreFocus)
  end
  connect(displayedList, 'onLayoutUpdate', restoreFocus)
end

function topIconRemove()
  if not topIconsPanel then return end
  local displayedList = topIconsPanel:recursiveGetChildById('displayedList')
  if not displayedList then return end
  local focused = displayedList:getFocusedChild()
  if not focused or not focused.buttonId then return end

  -- Find position and determine next selection
  local removedPos = nil
  for i, id in ipairs(topIconDisplayed) do
    if id == focused.buttonId then
      removedPos = i
      table.remove(topIconDisplayed, i)
      break
    end
  end

  -- Pick the next item to select (next if exists, otherwise previous)
  local nextSelectId = nil
  if removedPos then
    if topIconDisplayed[removedPos] then
      nextSelectId = topIconDisplayed[removedPos]
    elseif topIconDisplayed[removedPos - 1] then
      nextSelectId = topIconDisplayed[removedPos - 1]
    end
  end

  refreshTopIconLists()
  applyTopIconVisibility()
  applyTopIconOrder()

  if nextSelectId then
    local function restoreFocus()
      local item = displayedList:getChildById('topicon_' .. nextSelectId)
      if item then
        displayedList:focusChild(item)
        displayedList:ensureChildVisible(item)
      end
      disconnect(displayedList, 'onLayoutUpdate', restoreFocus)
    end
    connect(displayedList, 'onLayoutUpdate', restoreFocus)
  end
end

function topIconAdd()
  if not topIconsPanel then return end
  local availableList = topIconsPanel:recursiveGetChildById('availableList')
  if not availableList then return end
  local focused = availableList:getFocusedChild()
  if not focused or not focused.buttonId then return end

  -- Find position in available list to select next/previous after adding
  local available = getAvailableIds()
  local removedPos = nil
  for i, id in ipairs(available) do
    if id == focused.buttonId then
      removedPos = i
      break
    end
  end

  table.insert(topIconDisplayed, focused.buttonId)

  -- Pick next available item to select
  local newAvailable = getAvailableIds()
  local nextSelectId = nil
  if removedPos then
    if newAvailable[removedPos] then
      nextSelectId = newAvailable[removedPos]
    elseif newAvailable[removedPos - 1] then
      nextSelectId = newAvailable[removedPos - 1]
    end
  end

  refreshTopIconLists()
  applyTopIconVisibility()
  applyTopIconOrder()

  if nextSelectId then
    local function restoreFocus()
      local item = availableList:getChildById('topicon_' .. nextSelectId)
      if item then
        availableList:focusChild(item)
        availableList:ensureChildVisible(item)
      end
      disconnect(availableList, 'onLayoutUpdate', restoreFocus)
    end
    connect(availableList, 'onLayoutUpdate', restoreFocus)
  end
end

function topIconReset()
  if not topIconsPanel then return end
  local box
  box = displayAllianceBox(tr('Reset Shortcuts'), tr('Are you sure you want to reset shortcuts to default?'), {
    anchor = AnchorHorizontalCenter,
    { text = tr('Yes'), callback = function()
      topIconDisplayed = getDefaultDisplayedIds()
      saveTopIconSettings()
      refreshTopIconLists()
      applyTopIconVisibility()
      applyTopIconOrder()
      g_uistates.remove(box)
      box:destroy()
      box = nil
    end },
    { text = tr('No'), callback = function()
      g_uistates.remove(box)
      box:destroy()
      box = nil
    end }
  })
  g_uistates.push(box)
end