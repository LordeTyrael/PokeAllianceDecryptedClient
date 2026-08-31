local window = nil
local host = nil
local watchControl = nil
local hostControl = nil
local syncEvent = nil
local watchSyncEvent = nil
local pokeballs = nil
local ChangeNameWindow
local activeControl = true
local watchCollapsed = false
local hostCollapsed = false
isHosting = false
isSpectating = false
local lastFetchTime = 0
dataInfo = nil

function init()
  connect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy,
      -- protocolo custom 1575 (parseCam em C++); substituiu o extended opcode 114
      onCamList = onCamList,
      onCamHostingStarted = onCamHostingStarted,
      onCamHostingStopped = onCamHostingStopped,
      onCamCreateDialog = onCamCreateDialog,
      onCamHostZone = onCamHostZone
    }
  )
  ProtocolGame.registerOpcode(194, onReceiveCameraInfo)
  ProtocolGame.registerOpcode(GameServerOpcodes.GameServerSpectate, onStartSpectate)

  if g_game.isOnline() then
    create()
  end
end

function terminate()
  disconnect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy,
      onCamList = onCamList,
      onCamHostingStarted = onCamHostingStarted,
      onCamHostingStopped = onCamHostingStopped,
      onCamCreateDialog = onCamCreateDialog,
      onCamHostZone = onCamHostZone
    }
  )

  ProtocolGame.unregisterOpcode(194)
  ProtocolGame.unregisterOpcode(GameServerOpcodes.GameServerSpectate)
  if syncEvent then
      removeEvent(syncEvent)
      syncEvent = nil
  end

    if watchSyncEvent then
        removeEvent(watchSyncEvent)
        watchSyncEvent = nil
    end

  destroy()
end

function create()
  if window then
    return
  end

  window = g_ui.displayUI("spectate")
  window:hide()

  host = g_ui.displayUI("host")
  host:hide()

  host.password.viewButton.onClick = function()
    host.password:setTextHidden(not host.password:isTextHidden())
  end

  hostControl = g_ui.loadUI("cameracontrol", modules.game_interface.getFloatLayer())
  hostControl:setup()
  DockableWindow.register(hostControl)
  hostControl:hide()

  watchControl = g_ui.loadUI("watchcontrol", modules.game_interface.getFloatLayer())
  watchControl:setup()
  DockableWindow.register(watchControl)
  watchControl:hide()
end

function unbindKeyboardKeys()
    g_keyboard.unbindKeyDown(
        "Right"
    )
    g_keyboard.unbindKeyDown(
        "Left"
    )
    g_keyboard.unbindKeyDown(
        "Up"
    )
    g_keyboard.unbindKeyDown(
        "Down"
    )
    g_keyboard.unbindKeyDown(
        "Escape"
    )
end

function destroy()
  isHosting = false
  isSpectating = false
  lastFetchTime = 0

  if window then
    window:destroy()
    window = nil
  end

  if host then
    host:destroy()
    host = nil
  end

  if watchControl then
    watchControl:destroy()
    watchControl = nil
  end

  if hostControl then
    hostControl:destroy()
    hostControl = nil
  end

    if syncEvent then
        removeEvent(syncEvent)
        syncEvent = nil
    end
  modules.game_walking.enableClientWalk()

    unbindKeyboardKeys()
end

-- ---------------------------------------------------------------------------------------------------
-- Eventos do protocolo custom 1575 (disparados por ProtocolGame::parseCam em C++). Substituíram o
-- antigo dispatch JSON do extended opcode 114.
-- ---------------------------------------------------------------------------------------------------
function onCamList(entries)
  dataInfo = entries
  show(dataInfo)
end

function onCamHostingStarted(description, openTime)
  onStartHosting({description = description, openTime = openTime})
end

function onCamHostingStopped()
  onStopHosting()
end

function onCamCreateDialog(itemId)
  showHosting(itemId)
end

-- Zona do host enquanto assistimos. O servidor manda sempre (string vazia quando a zona não liberou),
-- então trocar de CAM nunca deixa o nome da anterior na tela.
function onCamHostZone(zoneName)
    if not watchControl then
        return
    end
    watchControl.zoneName:setText(zoneName or "")
end

function onStartHosting(data)
    isHosting = true
    hostControl:show()
    hostControl.channelName:setText(data.description)
    hostControl.openTime = data.openTime
    if not activeControl then
        activeControl = true
        hostControl.iconsPanel.changePokemonView:setImageSource("images/pokeball_on")
    end
    if syncEvent then
        removeEvent(syncEvent)
        syncEvent = nil
    end
    syncCamTime()
end

function stopSpectating()
    g_game.sendCamStopSpectate()
end

function nextCamera()
    g_game.sendCamNext()
end

function previousCamera()
    g_game.sendCamPrev()
end

function showChangeNameOption()
    if ChangeNameWindow then
        return
    end
    ChangeNameWindow = g_ui.loadUI("changename", rootWidget)

    -- Prefilled and selected: renaming is almost always a tweak of the current name, and the caret
    -- landing on an empty field forced retyping it from scratch.
    local edit = ChangeNameWindow.changeNameTextEdit
    if hostControl and hostControl.channelName then
        edit:setText(hostControl.channelName:getText())
    end
    ChangeNameWindow.onEnter = confirmChangeName

    ChangeNameWindow:focus()
    ChangeNameWindow:show()
    edit:focus()
    edit:setCursorPos(#edit:getText())
    modules.game_walking.disableClientWalk()
end

function hideChangeNameOption()
    if ChangeNameWindow then
        ChangeNameWindow:destroy()
        ChangeNameWindow = nil
    end
    modules.game_walking.enableClientWalk()
end

function confirmChangeName()
    -- Corta em 60 porque OutputMessage::addString lança acima do MAX_STRING_LENGTH e o campo é texto livre.
    -- utf8.sub (não :sub) para não partir um caractere multibyte no meio e gerar UTF-8 inválido.
    g_game.sendCamChangeName(utf8.sub(ChangeNameWindow.changeNameTextEdit:getText(), 1, 60))
    hideChangeNameOption()
end

function changePokemonPreview()
    if not activeControl then
        activeControl = true
        hostControl.iconsPanel.changePokemonView:setImageSource("images/pokeball_on")
    else
        activeControl = false
        hostControl.iconsPanel.changePokemonView:setImageSource("images/pokeball_off")
    end
    g_game.sendCamChangePokemonView()
end

function syncCamTime()
    if not hostControl then
        if syncEvent then
            removeEvent(syncEvent)
            syncEvent = nil
        end
        return
    end

    local time = math.max(0, os.time() - hostControl.openTime)
    hostControl.timeChannelOpenned:setText(formatHMS(time))
    syncEvent = scheduleEvent(syncCamTime, 1000)
end

function closeWatching()
    g_game.sendCamStopHost()
end

function requestChannelCameras()
    g_game.sendCamRequestChannels()
end

function hideWatching()
    if not watchControl then
        return
    end
    watchCollapsed = not watchCollapsed
    watchControl:setHeight(watchCollapsed and 26 or 232) -- 232 tem que casar com o size do watchcontrol.otui
    local collapseButton = watchControl:recursiveGetChildById('collapseButton')
    if collapseButton then
        collapseButton:setOn(watchCollapsed)
    end
end

function closeHosting()
    g_game.sendCamStopHost()
end

function hideHosting()
    if not hostControl then
        return
    end
    hostCollapsed = not hostCollapsed
    hostControl:setHeight(hostCollapsed and 26 or 170)
    local collapseButton = hostControl:recursiveGetChildById('collapseButton')
    if collapseButton then
        collapseButton:setOn(hostCollapsed)
    end
end

function requestViewersName()
  g_game.sendCamViewersName()
end

function requestBannedsViewersName()
  g_game.sendCamBannedViewersName()
end

function onStopHosting()
    isHosting = false
    hostControl:hide()
    hide()
    if syncEvent then
        removeEvent(syncEvent)
        syncEvent = nil
    end
end

function showHosting(itemId)
  if isHosting then
    g_game.sendCamStopHost()
    hide()
    return
  end

  host.cameraItemId = itemId
  host.description:setText(g_settings.get('tvcam-description'))
  host.password:setText(g_settings.get('tvcam-password'))
  host:raise()
  host:show()
  host:focus()
end

function confirmHost()
  local description = host.description:getText()
  local password = host.password:getText()
  g_settings.set('tvcam-description', description)
  g_settings.set('tvcam-password', password)
  g_settings.save()
  host:hide()
  window:hide()
  local cameraID = host.cameraItemId or 0
  g_game.sendCamHost(cameraID, password or "", description or "")
end

function cancelHost()
  host:hide()
end

function onStartSpectate(protocol, msg)
  local start = msg:getU8()
  local creature = g_map.getCreatureById(msg:getU32())
  if start == 1 then
    isSpectating = true
    watchControl:show()
    g_keyboard.bindKeyDown(
        "Right",
        function()
            nextCamera()
        end
    )
    g_keyboard.bindKeyDown(
        "Up",
        function()
            nextCamera()
        end
    )
    g_keyboard.bindKeyDown(
        "Left",
        function()
            previousCamera()
        end
    )
    g_keyboard.bindKeyDown(
        "Down",
        function()
            previousCamera()
        end
    )
    -- bound with the other cam keys so it only answers while spectating; unbindKeyboardKeys drops
    -- it on stop, keeping Escape free for the rest of the interface
    g_keyboard.bindKeyDown(
        "Escape",
        function()
            stopSpectating()
        end
    )

  else
    watchControl:hide()
    isSpectating = false
    watchControl.zoneName:setText("") -- não sobrevive para a próxima CAM
    if watchSyncEvent then
        removeEvent(watchSyncEvent)
        watchSyncEvent = nil
    end
    unbindKeyboardKeys()
  end
  if creature then
    modules.game_interface.getMapPanel():followCreature(creature)
  end
  hide()
end

function show(data)
    if not window then
        window = g_ui.displayUI("spectate")
    end
    
    window.hosts:destroyChildren()
    for _, host in ipairs(data) do
        local widget = g_ui.createWidget("HostPanel", window.hosts)
        widget:setId(host.name)
        widget.background.name:setText(host.name)
        widget.background.desc:setText(host.description)
        widget.background.viewers:setText(host.viewers)
        -- No binário não existe "chave ausente": guildName/zoneName chegam como "". Em Lua "" é TRUTHY,
        -- então os testes precisam ser explicitamente ~= "" — com `or`/`if x then` o fallback nunca rodaria.
        local guildName = host.guildName
        widget.background.guildName:setText((guildName and guildName ~= "") and guildName or tr("No Guild"))
        widget.background.playerLevel:setText(tr("Lv. %d", host.playerLevel or 1))
        local zoneName = host.zoneName or ""
        widget.background.zoneName:setText(zoneName)
        if zoneName ~= "" then
            -- nome completo no hover: o card corta nomes longos. O corelib destrói o tooltip junto
            -- com o widget dono, e destroyChildren() acima já derruba os anteriores.
            local zoneTip = g_ui.createWidget("SpectateZoneTooltip", rootWidget)
            zoneTip.zoneLabel:setText(zoneName)
            widget.background.zoneName:setTooltip(zoneTip)
        end
        widget.background.pass:setVisible(host.password)
        widget.background.camerabackGround.cameraIcon:setItemId(host.cameraItemId)
        widget.background.guildIcon:setImageSource("/images/guild_banners/mini-icons/"..host.guildIcon)
        widget.watchButton.onClick = startSpectating
    end
    window:show()
    window:focus()
    modules.game_walking.disableClientWalk()
end

function startSpectating(button)
    local parent = button:getParent()
    if parent.background.pass:isVisible() then
        modules.client_textedit.show(
            "",
            {
              title = tr("Password"),
              description = tr("Enter password to spectate this player"),
              width = 280
        },
            function(password)
              g_game.sendCamSpectate(parent:getId(), password or "")
            end
        )
    else
      g_game.sendCamSpectate(parent:getId(), "") -- "" = cast sem senha
    end
    modules.game_walking.enableClientWalk()
end

function hideProtected(widget)
    local checked = not widget:isChecked()
    if not checked then
        for _, host in pairs(window.hosts:getChildren()) do
            host:setVisible(not host.background.pass:isVisible())
        end
    else
        for _, host in pairs(window.hosts:getChildren()) do
            host:setVisible(true)
        end
    end
    widget:setChecked(checked)
end

function kickPlayer(name)
  g_game.sendCamKick(name)
end

function banPlayer(name)
  g_game.sendCamBan(name)
end

function hide()
    if window and window.searchCameraName then
        window.searchCameraName:setText("")
    end

    if window then
        window:hide()
    end
    modules.game_walking.enableClientWalk()
end

function onReceiveCameraInfo(protocol, msg)
    local type = msg:getU8()
    if type == 1 then
        local viewerCount = msg:getU16()
        if isHosting then
            hostControl.viewerCount:setText(math.max(0, viewerCount))
            return
        end
        watchControl.viewerCount:setText(math.max(0, viewerCount))
        return
    end

    if type == 2 then
        local pokemonSize = msg:getU16()
        pokeballs = {}
        for i = 1, pokemonSize do
            local clientID = msg:getU16()
            local pokemonName = msg:getString()
            table.insert(pokeballs, {name = humanCase(pokemonName), clientId = clientID})
        end
        watchControl.iconsPanel.pokemonPanel:destroyChildren()
        watchControl.iconsPanel.pokemonPanel:setWidth(#pokeballs * 30)
        for _, config in ipairs(pokeballs) do
            local pokeballWidget = g_ui.createWidget('PokemonIcon', watchControl.iconsPanel.pokemonPanel)
            pokeballWidget.pokemonIcon:setItemId(config.clientId)
            pokeballWidget.pokemonIcon:setTooltip(config.name)
        end
        return
    end

    if type == 3 then
        local cameraName = msg:getString()
        local startTime = msg:getU64()
        local cameraItemID = msg:getU16()
        watchControl.channelName:setText(cameraName)
        watchControl.openTime = startTime
        syncWatchCamTime()
    end

    if type == 4 then
      local cameraName = msg:getString()
      watchControl.channelName:setText(cameraName)
      hostControl.channelName:setText(cameraName)
    end
end

function syncWatchCamTime()
    if not watchControl then
        if watchSyncEvent then
            removeEvent(watchSyncEvent)
            watchSyncEvent = nil
        end
        return
    end

    local time = math.max(0, os.time() - watchControl.openTime)
    watchControl.timeChannelOpenned:setText(formatHMS(time))
    watchSyncEvent = scheduleEvent(syncWatchCamTime, 1000)
end

function onSearchCameraNames(searchText)
    if not searchText or searchText:len() == 0 then
        show(dataInfo)
        return
    end

    local filteredHosts = {}
    local searchLower = searchText:lower()

    for _, host in ipairs(dataInfo) do
        local nameMatch = host.name and host.name:lower():find(searchLower)
        local descMatch = host.description and host.description:lower():find(searchLower)
        local guildMatch = host.guildName and host.guildName:lower():find(searchLower)
        local zoneMatch = host.zoneName and host.zoneName:lower():find(searchLower)

        if nameMatch or descMatch or guildMatch or zoneMatch then
            table.insert(filteredHosts, host)
        end
    end

    show(filteredHosts)
end
