gameRootPanel = nil
gameMapPanel = nil
gameRightPanels = nil
gameLeftPanels = nil
horizontalLeftDock = nil
horizontalRightDock = nil
horizontalLeftPanel = nil
horizontalRightPanel = nil
horizontalLeftResizeBorder = nil
horizontalRightResizeBorder = nil
gameBottomPanel = nil
gameBottomActionPanel = nil
gameLeftActionPanel = nil
gameRightActionPanel = nil
gameLeftActions = nil
gameTopBar = nil
gameFloatPanel = nil
logoutButton = nil
mouseGrabberWidget = nil
countWindow = nil
logoutWindow = nil
exitWindow = nil
bottomSplitter = nil
limitedZoom = false
hookedMenuOptions = {}
lastDirTime = g_clock.millis()

local LEFT_MOUSE_ACTION = {
    WALK = 1,
    ORDER = 2,
    NOTHING = 3
}
-- the default side panel shipped without an id, so it kept the engine's process-wide counter id
-- (game_interfaceNNN, widgetNNN before ad97660f). Every parentId saved against it stopped resolving
-- as soon as that counter shifted, and UIMiniWindow:setup() then silently leaves the window in the
-- parent its own module created it in.
local DEFAULT_RIGHT_PANEL_ID = "rightPanel1"
local MINIWINDOW_SETTINGS_VERSION = 1

local function migrateMiniWindowSettings()
    if g_settings.getNumber("miniWindowsSettingsVersion") >= MINIWINDOW_SETTINGS_VERSION then
        return
    end

    local dirtyNodes = {}
    local docked = {}
    for _, node in pairs(UIMiniWindow.SETTINGS_NODES) do
        local settings = g_settings.getNode(node)
        if settings then
            for id, entry in pairs(settings) do
                local parentId = type(entry) == "table" and entry.parentId
                if type(parentId) == "string" and
                    (parentId:match("^game_interface%d+$") or parentId:match("^widget%d+$")) then
                    dirtyNodes[node] = settings
                    local index = tonumber(entry.index)
                    if index then
                        entry.parentId = DEFAULT_RIGHT_PANEL_ID
                        table.insert(docked, {id = tostring(id), entry = entry, index = index})
                    else
                        -- never docked in a side panel, so there is nothing to point at; keeping the
                        -- id would only let it resolve by colliding with an unrelated widget
                        entry.parentId = nil
                        entry.position = nil
                    end
                end
            end
        end
    end

    -- indexes written by different sessions leave holes and duplicates, and scheduleInsert only
    -- places an index once the panel already holds index - 1 children, so everything past the first
    -- hole would stay undocked forever
    table.sort(docked, function(a, b)
        if a.index ~= b.index then
            return a.index < b.index
        end
        return a.id < b.id
    end)
    for i = 1, #docked do
        docked[i].entry.index = i
    end

    for node, settings in pairs(dirtyNodes) do
        g_settings.setNode(node, settings)
    end
    g_settings.set("miniWindowsSettingsVersion", MINIWINDOW_SETTINGS_VERSION)
    g_settings.save()
end

function init()
    migrateMiniWindowSettings()

    g_ui.importStyle("styles/countwindow")

    connect(
        g_game,
        {
            onGameStart = onGameStart,
            onGameEnd = onGameEnd,
            onLoginAdvice = onLoginAdvice
        },
        true
    )

    connect(
        g_app,
        {
            onRun = load,
            onExit = save
        }
    )

    gameRootPanel = g_ui.displayUI("gameinterface")
    gameRootPanel:hide()
    gameRootPanel:lower()
    gameRootPanel.onGeometryChange = updateStretchShrink

    mouseGrabberWidget = gameRootPanel:getChildById("mouseGrabber")
    mouseGrabberWidget.onMouseRelease = onMouseGrabberRelease
    mouseGrabberWidget.onTouchRelease = mouseGrabberWidget.onMouseRelease

    bottomSplitter = gameRootPanel:getChildById("bottomSplitter")
    gameMapPanel = gameRootPanel:getChildById("gameMapPanel")
    gameRightPanels = gameRootPanel:getChildById("gameRightPanels")
    gameLeftPanels = gameRootPanel:getChildById("gameLeftPanels")
    gameBottomPanel = gameRootPanel:getChildById("gameBottomPanel")
    gameBottomActionPanel = gameRootPanel:getChildById("gameBottomActionPanel")
    gameRightActionPanel = gameRootPanel:getChildById("gameRightActionPanel")
    gameLeftActionPanel = gameRootPanel:getChildById("gameLeftActionPanel")
    gameTopBar = gameRootPanel:getChildById("gameTopBar")
    gameLeftActions = gameRootPanel:getChildById("gameLeftActions")
    horizontalLeftDock = gameRootPanel:getChildById("horizontalLeftDock")
    horizontalRightDock = gameRootPanel:getChildById("horizontalRightDock")
    horizontalLeftPanel = horizontalLeftDock:getChildById("horizontalLeftPanel")
    horizontalRightPanel = horizontalRightDock:getChildById("horizontalRightPanel")
    horizontalLeftResizeBorder = horizontalLeftDock:getChildById("horizontalLeftResizeBorder")
    horizontalRightResizeBorder = horizontalRightDock:getChildById("horizontalRightResizeBorder")
    horizontalLeftPanel.overflowHandler = moveToVerticalPanel
    horizontalRightPanel.overflowHandler = moveToVerticalPanel
    connect(horizontalLeftResizeBorder, {onMouseRelease = function() saveDockHeight(horizontalLeftDock, "horizontalLeftHeight") end})
    connect(horizontalRightResizeBorder, {onMouseRelease = function() saveDockHeight(horizontalRightDock, "horizontalRightHeight") end})
    connect(gameLeftPanels, {onGeometryChange = updateHorizontalDockWidths})
    connect(gameRightPanels, {onGeometryChange = updateHorizontalDockWidths})
    updateHorizontalPanels()
    gameFloatPanel = gameRootPanel:getChildById("gameFloatPanel")
    connect(gameLeftPanel, {onVisibilityChange = onLeftPanelVisibilityChange})

    logoutButton =
        modules.client_topmenu.addMiddleGameToggleButton("logoutButton", tr("Exit"), "/images/ui/topbuttons/icons/logout", tryLogout, true)

    local seedPanel = g_ui.createWidget("GameSidePanel")
    seedPanel:setId("rightPanel1")
    gameRightPanels:addChild(seedPanel)
    local defaultRightPanel = g_ui.createWidget("GameSidePanel")
    defaultRightPanel:setId(DEFAULT_RIGHT_PANEL_ID)
    gameRightPanels:addChild(defaultRightPanel)

    setupLeftActions()
    refreshViewMode()
    modules.client_options.updateHealthColor()

    bindKeys()

    modules.client_hotkeys.registerHotkeyCallback("LOGOUT",
      function(actionName, action, keyInfo, chatState, keyType)
        local callback = function()
          local chatModeEnabled = not modules.game_chat.consoleToggleChat
          local wantChat = (chatState == "chatEnabled")
          if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
            tryLogout(false)
          end
        end
        return { callback = callback, widget = gameRootPanel }
      end)

    connect(gameMapPanel, {onGeometryChange = updateSize, onVisibleDimensionChange = updateSize})
    connect(g_game, {onMapChangeAwareRange = updateSize})

    if g_game.isOnline() then
        show()
    end
end

function bindKeys()
    gameRootPanel:setAutoRepeatDelay(10)

    local lastAction = 0
    g_keyboard.bindKeyPress(
        "Escape",
        function()
            if lastAction + 50 > g_clock.millis() then
                return
            end
            lastAction = g_clock.millis()
            g_game.cancelAttackAndFollow()
        end,
        gameRootPanel
    )
	
	g_keyboard.bindKeyDown('Enter', function() modules.game_chat.sendCurrentMessage() end, gameRootPanel)
	
    g_keyboard.bindKeyDown(
        "Ctrl+.",
        function()
            refreshView()
        end,
        gameRootPanel
    )
    g_keyboard.bindKeyDown(
        "Shift+W",
        function()
            g_map.cleanTexts()
            modules.game_textmessage.clearMessages()
        end,
        gameRootPanel
    )
end

function terminate()
    stopSidePanelFade()
    hide()

    hookedMenuOptions = {}
    markThing = nil

    disconnect(
        g_game,
        {
            onGameStart = onGameStart,
            onGameEnd = onGameEnd,
            onLoginAdvice = onLoginAdvice
        }
    )

    disconnect(gameMapPanel, {onGeometryChange = updateSize})
    connect(gameMapPanel, {onGeometryChange = updateSize, onVisibleDimensionChange = updateSize})

    logoutButton:destroy()
    gameRootPanel:destroy()
end

function resetCinematicView()
    if gameMapPanel then
        gameMapPanel:endCinematicView()
    end
    g_map.endBigMapRetention()
end

function onGameStart()
    resetCinematicView()
    refreshViewMode()
    show()
    modules.client_options.updateHealthColor()

    if not g_game.isOfficialTibia() then
        g_game.enableFeature(GameForceFirstAutoWalkStep)
    else
        g_game.disableFeature(GameForceFirstAutoWalkStep)
    end
end

function onGameEnd()
    stopSidePanelFade()
    resetCinematicView()
    hide()
    modules.client_topmenu.getTopMenu():setImageColor("white")
end

function show()
    connect(g_app, {onClose = tryExit})
    modules.client_background.hide()
    gameRootPanel:show()
    gameRootPanel:focus()
    gameMapPanel:followCreature(g_game.getLocalPlayer())

    updateStretchShrink()
    logoutButton:setTooltip(tr("Logout"))

    addEvent(
        function()
            if not limitedZoom or g_game.isGM() then
                gameMapPanel:setMaxZoomOut(513)
                gameMapPanel:setLimitVisibleRange(false)
            else
                gameMapPanel:setMaxZoomOut(15)
                gameMapPanel:setLimitVisibleRange(true)
            end
        end
    )
end

function hide()
    disconnect(g_app, {onClose = tryExit})
    logoutButton:setTooltip(tr("Exit"))

    if logoutWindow then
        logoutWindow:destroy()
        logoutWindow = nil
    end
    if exitWindow then
        exitWindow:destroy()
        exitWindow = nil
    end
    if countWindow then
        countWindow:destroy()
        countWindow = nil
    end
    gameRootPanel:hide()
    gameMapPanel:setShader("")
    modules.client_background.show()
end

-- applyDockState reapplies this on every login, so a drag left unsaved is lost on the next relog
function saveDockHeight(dock, heightKey)
    local height = dock:getHeight()
    if height <= 0 then
        return
    end
    local settings = g_settings.getNode("game_interface") or {}
    if settings[heightKey] == height then
        return
    end
    settings[heightKey] = height
    g_settings.setNode("game_interface", settings)
    g_settings.save()
end

function save()
    local settings = g_settings.getNode("game_interface") or {}
    settings.splitterMarginBottom = bottomSplitter:getMarginBottom()
    if horizontalLeftDock:getHeight() > 0 then
        settings.horizontalLeftHeight = horizontalLeftDock:getHeight()
    end
    if horizontalRightDock:getHeight() > 0 then
        settings.horizontalRightHeight = horizontalRightDock:getHeight()
    end
    g_settings.setNode("game_interface", settings)
end

function load()
    local settings = g_settings.getNode("game_interface")
    if settings then
        if settings.splitterMarginBottom then
            bottomSplitter:setMarginBottom(settings.splitterMarginBottom)
        end
    end
end

local function getItemDistance(p1, p2)
    return math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y))
end

function onLoginAdvice(message)
    displayAllianceInfoBox(tr("For Your Information"), message)
end

function forceExit()
    g_game.cancelLogin()
    scheduleEvent(exit, 10)
    return true
end

function tryExit()
    if exitWindow then
        return true
    end

    local exitFunc = function()
        g_uistates.remove(exitWindow)
        g_game.safeLogout()
        forceExit()
    end
    local logoutFunc = function()
        g_game.safeLogout()
        g_uistates.remove(exitWindow)
        exitWindow:destroy()
        exitWindow = nil
    end
    local cancelFunc = function()
        g_uistates.remove(exitWindow)
        exitWindow:destroy()
        exitWindow = nil
    end

    exitWindow =
        displayAllianceBox(
        tr("Exit"),
        tr(
            "If you shut down the program, your character might stay in the game.\nClick on 'Logout' to ensure that you character leaves the game properly.\nClick on 'Exit' if you want to exit the program without logging out your character."
        ),
        {
            {text = tr("Force Exit"), callback = exitFunc},
            {text = tr("Logout"), callback = logoutFunc},
            {text = tr("Cancel"), callback = cancelFunc},
            anchor = AnchorHorizontalCenter
        },
        logoutFunc,
        cancelFunc
    )
    g_uistates.push(exitWindow)
    return true
end

function tryLogout(prompt)
    if type(prompt) ~= "boolean" then
        prompt = true
    end
    if not g_game.isOnline() then
        exit()
        return
    end

    if logoutWindow then
        return
    end

    local msg, yesCallback
    if not g_game.isConnectionOk() then
        msg =
            tr("Your connection is failing, if you logout now your character will be still online, do you want to force logout?")

        yesCallback = function()
            g_game.forceLogout()
            if logoutWindow then
                logoutWindow:destroy()
                logoutWindow = nil
            end
        end
    else
        msg = tr("Are you sure you want to logout?")

        yesCallback = function()
            g_game.safeLogout()
            if logoutWindow then
                logoutWindow:destroy()
                logoutWindow = nil
            end
        end
    end

    local noCallback = function()
        logoutWindow:destroy()
        logoutWindow = nil
    end

    if prompt then
        logoutWindow =
            displayGeneralBox(
            tr("Logout"),
            msg,
            {
                {text = tr("Yes"), callback = yesCallback},
                {text = tr("No"), callback = noCallback},
                anchor = AnchorHorizontalCenter
            },
            yesCallback,
            noCallback
        )
    else
        yesCallback()
    end

    if g_discord ~= nil then
        g_discord.update()
    end
end

function updateStretchShrink()
    if modules.client_options.getOption("dontStretchShrink") and not alternativeView then
        gameMapPanel:setVisibleDimension({width = 15, height = 11})
        bottomSplitter:setMarginBottom(bottomSplitter:getMarginBottom() + (gameMapPanel:getHeight() - 32 * 11) - 10)
    end
end

function onMouseGrabberRelease(self, mousePosition, mouseButton)
    if mouseButton == MouseTouch then
        return
    end
    if selectedThing == nil then
        return false
    end

    if mouseButton == MouseLeftButton then
        local clickedWidget = gameRootPanel:recursiveGetChildByPos(mousePosition, false)
        if clickedWidget then
            if selectedType == "use" then
                onUseWith(clickedWidget, mousePosition)
            elseif selectedType == "trade" then
                onTradeWith(clickedWidget, mousePosition)
            end
        end
    end

    selectedThing = nil
    g_mouse.popCursor("target")
    self:ungrabMouse()
    gameMapPanel:blockNextMouseRelease(true)
    return true
end

function isRevive(itemID)
    local IDs = {3156, 3077, 39748}
    if table.contains(IDs, itemID) then
        return true
    end
    return false
end

function onUseWith(clickedWidget, mousePosition, optionalSelectedThing)
    if not selectedThing then
        selectedThing = optionalSelectedThing
    end

    if not selectedThing then
        return
    end
    
    local selectThingID = selectedThing:getId()
    if isRevive(selectThingID) then
        local pokemon = modules.game_pokebar.getPokebarSlotAt(mousePosition)
        if pokemon then
            modules.game_pokebar.sendPokebarRevive(pokemon.id, selectedThing)
            return true
        end
    end

    if clickedWidget:getClassName() == "UIGameMap" then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
            if selectedThing:isFluidContainer() or selectedThing:isMultiUse() then
                g_game.useWith(
                    selectedThing,
                    tile:getTopMultiUseThingEx(clickedWidget:getPositionOffset(mousePosition)),
                    selectedSubtype
                )
            else
                g_game.useWith(selectedThing, tile:getTopUseThing(), selectedSubtype)
            end
        end
    elseif clickedWidget:getClassName() == "UIItem" and not clickedWidget:isVirtual() then
        g_game.useWith(selectedThing, clickedWidget:getItem(), selectedSubtype)
    elseif clickedWidget:getClassName() == "UICreatureButton" then
        local creature = clickedWidget:getCreature()
        if creature then
            g_game.useWith(selectedThing, creature, selectedSubtype)
        end
    end
end

function onTradeWith(clickedWidget, mousePosition)
    if clickedWidget:getClassName() == "UIGameMap" then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
            g_game.requestTrade(selectedThing, tile:getTopCreatureEx(clickedWidget:getPositionOffset(mousePosition)))
        end
    elseif clickedWidget:getClassName() == "UICreatureButton" then
        local creature = clickedWidget:getCreature()
        if creature then
            g_game.requestTrade(selectedThing, creature)
        end
    end
end

function startUseWith(thing, subType)
    gameMapPanel:blockNextMouseRelease()
    if not thing then
        return
    end
    if g_ui.isMouseGrabbed() then
        if selectedThing then
            selectedThing = thing
            selectedType = "use"
        end
        return
    end
    selectedType = "use"
    selectedThing = thing
    selectedSubtype = subType or 0
    mouseGrabberWidget:grabMouse()
    g_mouse.pushCursor("target")
end

function cancelUseWith()
    selectedThing = nil
    g_mouse.popCursor("target")
    mouseGrabberWidget:ungrabMouse()
end

function startTradeWith(thing)
    if not thing then
        return
    end
    if g_ui.isMouseGrabbed() then
        if selectedThing then
            selectedThing = thing
            selectedType = "trade"
        end
        return
    end
    selectedType = "trade"
    selectedThing = thing
    mouseGrabberWidget:grabMouse()
    g_mouse.pushCursor("target")
end

function isMenuHookCategoryEmpty(category)
    if category then
        for _, opt in pairs(category) do
            if opt then
                return false
            end
        end
    end
    return true
end

function addMenuHook(category, name, callback, condition, shortcut)
    if not hookedMenuOptions[category] then
        hookedMenuOptions[category] = {}
    end
    hookedMenuOptions[category][name] = {
        callback = callback,
        condition = condition,
        shortcut = shortcut
    }
end

function removeMenuHook(category, name)
    if not name then
        hookedMenuOptions[category] = {}
    else
        hookedMenuOptions[category][name] = nil
    end
end

local function openStreamChannel(url, name)
    local streamView = modules.game_streamview
    if streamView and streamView.open(url, name) then
        return
    end
    g_platform.openUrl(url)
end

function createThingMenu(menuPosition, lookThing, useThing, creatureThing)
    if not g_game.isOnline() then
        return
    end

    local menu = g_ui.createWidget("PopupMenu")
    menu:setGameMenu(true)

    local classic = modules.client_options.getOption("classicControl")
    local shortcut = nil

    if not classic and not g_app.isMobile() then
        shortcut = "(Shift)"
    else
        shortcut = nil
    end
    if lookThing then
        menu:addOption(
            tr("Look"),
            function()
                g_game.look(lookThing)
            end,
            shortcut
        )
    end

    if not classic and not g_app.isMobile() then
        shortcut = "(Ctrl)"
    else
        shortcut = nil
    end

    local newWindowShortcut = nil
    if not g_app.isMobile() and modules.client_options.getOption("containerShiftRightClickNewWindow") then
        newWindowShortcut = "(Shift)"
    end

    if useThing then
        if useThing:isContainer() then
            if useThing:getParentContainer() then
                menu:addOption(
                    tr("Open"),
                    function()
                        g_game.open(useThing, useThing:getParentContainer())
                    end,
                    shortcut
                )
                menu:addOption(
                    tr("Open in new window"),
                    function()
                        g_game.open(useThing)
                    end,
                    newWindowShortcut
                )
            else
                menu:addOption(
                    tr("Open"),
                    function()
                        g_game.open(useThing)
                    end,
                    shortcut
                )
            end
        else
            if useThing:isMultiUse() then
                menu:addOption(
                    tr("Use with ..."),
                    function()
                        startUseWith(useThing)
                    end,
                    shortcut
                )
            else
                menu:addOption(
                    tr("Use"),
                    function()
                        g_game.use(useThing)
                    end,
                    shortcut
                )
            end
        end

        if useThing:hasSwitchMode() then
            menu:addOption(
                tr("Switch Mode"),
                function()
                    g_game.switchMode(useThing)
                end
            )
        end

        if useThing:isRotateable() then
            menu:addOption(
                tr("Rotate"),
                function()
                    g_game.rotate(useThing)
                end
            )
        end
        if useThing:isWrapable() then
            menu:addOption(
                tr("Wrap"),
                function()
                    g_game.wrap(useThing)
                end
            )
        end
        if useThing:isUnwrapable() then
            menu:addOption(
                tr("Unwrap"),
                function()
                    g_game.wrap(useThing)
                end
            )
        end

        if g_game.getFeature(GameBrowseField) and useThing:getPosition().x ~= 0xffff then
            menu:addOption(
                tr("Browse Field"),
                function()
                    g_game.browseField(useThing:getPosition())
                end
            )
        end
    end

    if lookThing and not lookThing:isCreature() and not lookThing:isNotMoveable() and lookThing:isPickupable() then
        if lookThing:isPokeball() and lookThing:canCustomizePokeball() then
            menu:addSeparator()
            menu:addOption(
                tr("Customize Pokéball"),
                function()
                    modules.game_pokeballmanagement.setPokeball(lookThing)
                    g_game.requestPokeballManagement(lookThing)
                end
            )
        end
        
        menu:addSeparator()
        menu:addOption(
            tr("Trade with ..."),
            function()
                startTradeWith(lookThing)
            end
        )
        menu:addOption(
            tr("Browse Drops"),
            function()
                g_game.requestItemDrops(lookThing)
            end
        )
        if lookThing and lookThing:getParentContainer() then
            menu:addOption(
                tr("Find Items"),
                function()
                    if modules.game_itemlocator then
                        modules.game_itemlocator.show()
                    end
                end
            )
        end
    end

    if lookThing and lookThing:isItem() and lookThing:isPokeball() and lookThing:getPokemonLookType() == 635 then
        menu:addSeparator()
        menu:addOption(
            tr("Ditto Memory"),
            function()
                modules.game_memory.requestOpenMemory()
            end
        )
    end

    if lookThing then
        local parentContainer = lookThing:getParentContainer()
        if parentContainer and parentContainer:hasParent() then
            menu:addOption(
                tr("Move up"),
                function()
                    g_game.moveToParentContainer(lookThing, lookThing:getCount())
                end
            )
        end
    end

    if creatureThing then
        local localPlayer = g_game.getLocalPlayer()
        menu:addSeparator()

        if creatureThing:isLocalPlayer() then
            menu:addOption(
                tr("Set Outfit"),
                function()
                    g_game.requestOutfit()
                end
            )

            if g_game.getFeature(GamePlayerMounts) then
                if not localPlayer:isMounted() then
                    menu:addOption(
                        tr("Mount"),
                        function()
                            localPlayer:mount()
                        end
                    )
                else
                    menu:addOption(
                        tr("Dismount"),
                        function()
                            localPlayer:dismount()
                        end
                    )
                end
            end

            if g_game.getFeature(GamePrey) and modules.game_prey then
                menu:addOption(
                    tr("Open Prey Dialog"),
                    function()
                        modules.game_prey.show()
                    end
                )
            end

            if creatureThing:isPartyMember() then
                if creatureThing:isPartyLeader() then
                    if creatureThing:isPartySharedExperienceActive() then
                        menu:addOption(
                            tr("Disable Shared Experience"),
                            function()
                                g_game.partyShareExperience(false)
                            end
                        )
                    else
                        menu:addOption(
                            tr("Enable Shared Experience"),
                            function()
                                g_game.partyShareExperience(true)
                            end
                        )
                    end
                end
                menu:addOption(
                    tr("Leave Party"),
                    function()
                        g_game.partyLeave()
                    end
                )
            end
        else
            local localPosition = localPlayer:getPosition()
            if not classic and not g_app.isMobile() then
                shortcut = "(Alt)"
            else
                shortcut = nil
            end
            if creatureThing:getPosition().z == localPosition.z then
                if g_game.getAttackingCreature() ~= creatureThing then
                    menu:addOption(
                        tr("Attack"),
                        function()
                            g_game.attack(creatureThing)
                        end,
                        shortcut
                    )
                else
                    menu:addOption(
                        tr("Stop Attack"),
                        function()
                            g_game.cancelAttack()
                        end,
                        shortcut
                    )
                end

                if g_game.getFollowingCreature() ~= creatureThing then
                    menu:addOption(
                        tr("Follow"),
                        function()
                            g_game.follow(creatureThing)
                        end
                    )
                else
                    menu:addOption(
                        tr("Stop Follow"),
                        function()
                            g_game.cancelFollow()
                        end
                    )
                end
            end

            if creatureThing:isPlayer() then
                menu:addSeparator()
                local creatureName = creatureThing:getName()
                menu:addOption(
                    tr("Message to %s", creatureName),
                    function()
                        g_game.openPrivateChannel(creatureName)
                    end
                )
                if modules.game_chat.getOwnPrivateTab() then
                    menu:addOption(
                        tr("Invite to private chat"),
                        function()
                            g_game.inviteToOwnChannel(creatureName)
                        end
                    )
                    menu:addOption(
                        tr("Exclude from private chat"),
                        function()
                            g_game.excludeFromOwnChannel(creatureName)
                        end
                    )
                end
                if not localPlayer:hasVip(creatureName) then
                    menu:addOption(
                        tr("Add to Friend List"),
                        function()
                            g_game.addVip(creatureName)
                        end
                    )
                end

                if modules.game_chat.isIgnored(creatureName) then
                    menu:addOption(
                        tr("Unignore") .. " " .. creatureName,
                        function()
                            modules.game_chat.removeIgnoredPlayer(creatureName)
                        end
                    )
                else
                    menu:addOption(
                        tr("Ignore") .. " " .. creatureName,
                        function()
                            modules.game_chat.addIgnoredPlayer(creatureName)
                        end
                    )
                end

                -- Antes: `MySkullType == 2 and ThingSkullType == 1` (verde + amarelo), ou seja
                -- "estou em grupo" + "essa pessoa ja me atacou". Nunca foi sinal de convite de
                -- duelo -- casava por coincidencia das semanticas de skull herdadas do Tibia.
                -- DuelShieldInvited e' o sinal REAL: o servidor devolve exatamente quando o outro
                -- jogador me convidou E e' o lider do duelo (Player::getDuelShield, player.cpp).
                if creatureThing:getDuelShield() == DuelShieldInvited then
                    menu:addOption(
                        tr("Accept duel of %s", creatureThing:getName()),
                        function()
                            modules.game_duel.join(creatureThing:getId())
                        end
                    )
                else
                    menu:addOption(
                        tr("Duel with %s", creatureThing:getName()),
                        function()
                            modules.game_duel.show(creatureThing)
                        end
                    )
                end

                local localPlayerShield = localPlayer:getShield()
                local creatureShield = creatureThing:getShield()

                if localPlayerShield == ShieldNone or localPlayerShield == ShieldWhiteBlue then
                    if creatureShield == ShieldWhiteYellow then
                        menu:addOption(
                            tr("Join %s's Party", creatureThing:getName()),
                            function()
                                g_game.partyJoin(creatureThing:getId())
                            end
                        )
                    else
                        menu:addOption(
                            tr("Invite to Party"),
                            function()
                                g_game.partyInvite(creatureThing:getId())
                            end
                        )
                    end
                elseif localPlayerShield == ShieldWhiteYellow then
                    if creatureShield == ShieldWhiteBlue then
                        menu:addOption(
                            tr("Revoke %s's Invitation", creatureThing:getName()),
                            function()
                                g_game.partyRevokeInvitation(creatureThing:getId())
                            end
                        )
                    end
                elseif
                    localPlayerShield == ShieldYellow or localPlayerShield == ShieldYellowSharedExp or
                        localPlayerShield == ShieldYellowNoSharedExpBlink or
                        localPlayerShield == ShieldYellowNoSharedExp
                 then
                    if creatureShield == ShieldWhiteBlue then
                        menu:addOption(
                            tr("Revoke %s's Invitation", creatureThing:getName()),
                            function()
                                g_game.partyRevokeInvitation(creatureThing:getId())
                            end
                        )
                    elseif
                        creatureShield == ShieldBlue or creatureShield == ShieldBlueSharedExp or
                            creatureShield == ShieldBlueNoSharedExpBlink or
                            creatureShield == ShieldBlueNoSharedExp
                     then
                        menu:addOption(
                            tr("Pass Leadership to %s", creatureThing:getName()),
                            function()
                                g_game.partyPassLeadership(creatureThing:getId())
                            end
                        )
                    else
                        menu:addOption(
                            tr("Invite to Party"),
                            function()
                                g_game.partyInvite(creatureThing:getId())
                            end
                        )
                    end
                end
                local streamLink = lookThing:getTwitchLink()
                if streamLink ~= "" then
                    local streamLabel
                    if string.find(streamLink, "twitch") then
                        streamLabel = tr("Open Twitch Channel")
                    elseif string.find(streamLink, "youtube") then
                        streamLabel = tr("Open Youtube Channel")
                    end

                    if streamLabel then
                        menu:addOption(streamLabel, function()
                            openStreamChannel(streamLink, lookThing:getName())
                        end)
                    end
                end
            end
        end

        menu:addSeparator()
        menu:addOption(
            tr("Copy Name"),
            function()
                g_window.setClipboardText(creatureThing:getName())
            end
        )
    end

    for _, category in pairs(hookedMenuOptions) do
        if not isMenuHookCategoryEmpty(category) then
            menu:addSeparator()
            for name, opt in pairs(category) do
                if opt and opt.condition(menuPosition, lookThing, useThing, creatureThing) then
                    menu:addOption(
                        name,
                        function()
                            opt.callback(menuPosition, lookThing, useThing, creatureThing)
                        end,
                        opt.shortcut
                    )
                end
            end
        end
    end

    if g_game.getFeature(GameBot) and useThing and useThing:isItem() then
        menu:addSeparator()
        if useThing:getSubType() > 1 then
            menu:addOption(
                "ID: " .. useThing:getId() .. " SubType: " .. useThing:getSubType(),
                function()
                end
            )
        else
            menu:addOption(
                "ID: " .. useThing:getId(),
                function()
                end
            )
        end
    end

    menu:display(menuPosition)
end

function processMouseAction(
    menuPosition,
    mouseButton,
    autoWalkPos,
    lookThing,
    useThing,
    creatureThing,
    attackCreature,
    marking)
    local keyboardModifiers = g_keyboard.getModifiers()

    if g_app.isMobile() then
        if mouseButton == MouseRightButton then
            createThingMenu(menuPosition, lookThing, useThing, creatureThing)
            return true
        end
        if mouseButton ~= MouseLeftButton and mouseButton ~= MouseTouch2 and mouseButton ~= MouseTouch3 then
            return false
        end
        local action = getLeftAction()
        if action == "look" then
            if lookThing then
                resetLeftActions()
                g_game.look(lookThing)
                return true
            end
            return true
        elseif action == "use" then
            if useThing then
                resetLeftActions()
                if useThing:isContainer() then
                    if useThing:getParentContainer() then
                        g_game.open(useThing, useThing:getParentContainer())
                    else
                        g_game.open(useThing)
                    end
                    return true
                elseif useThing:isMultiUse() then
                    startUseWith(useThing)
                    return true
                else
                    g_game.use(useThing)
                    return true
                end
            end
            return true
        elseif action == "attack" then
            if attackCreature and attackCreature ~= player then
                resetLeftActions()
                g_game.attack(attackCreature)
                return true
            elseif creatureThing and creatureThing ~= player and creatureThing:getPosition().z == autoWalkPos.z then
                resetLeftActions()
                g_game.attack(creatureThing)
                return true
            end
            return true
        elseif action == "follow" then
            if attackCreature and attackCreature ~= player then
                resetLeftActions()
                g_game.follow(attackCreature)
                return true
            elseif creatureThing and creatureThing ~= player and creatureThing:getPosition().z == autoWalkPos.z then
                resetLeftActions()
                g_game.follow(creatureThing)
                return true
            end
            return true
        elseif not autoWalkPos and useThing then
            createThingMenu(menuPosition, lookThing, useThing, creatureThing)
            return true
        end
    elseif not modules.client_options.getOption("classicControl") then
        if keyboardModifiers == KeyboardNoModifier and mouseButton == MouseRightButton then
            createThingMenu(menuPosition, lookThing, useThing, creatureThing)
            return true
        elseif
            useThing and useThing:isContainer() and keyboardModifiers == KeyboardShiftModifier and
                mouseButton == MouseRightButton and
                modules.client_options.getOption("containerShiftRightClickNewWindow")
         then
            g_game.open(useThing)
            return true
        elseif
            lookThing and keyboardModifiers == KeyboardShiftModifier and
                (mouseButton == MouseLeftButton or mouseButton == MouseRightButton)
         then
            g_game.look(lookThing)
            return true
        elseif
            useThing and keyboardModifiers == KeyboardCtrlModifier and
                (mouseButton == MouseLeftButton or mouseButton == MouseRightButton)
         then
            if useThing:isContainer() then
                if useThing:getParentContainer() then
                    g_game.open(useThing, useThing:getParentContainer())
                else
                    g_game.open(useThing)
                end
                return true
            elseif useThing:isMultiUse() then
                startUseWith(useThing)
                return true
            else
                g_game.use(useThing)
                return true
            end
            return true
        elseif
            attackCreature and g_keyboard.isAltPressed() and
                (mouseButton == MouseLeftButton or mouseButton == MouseRightButton)
         then
            g_game.attack(attackCreature)
            return true
        elseif
            creatureThing and creatureThing:getPosition().z == autoWalkPos.z and g_keyboard.isAltPressed() and
                (mouseButton == MouseLeftButton or mouseButton == MouseRightButton)
         then
            g_game.attack(creatureThing)
            return true
        end
    else
        if useThing and keyboardModifiers == KeyboardNoModifier and mouseButton == MouseRightButton and not g_mouse.isPressed(MouseLeftButton) then
            local player = g_game.getLocalPlayer()
            if attackCreature and attackCreature ~= player then
                g_game.attack(attackCreature)
                return true
            elseif creatureThing and creatureThing ~= player and creatureThing:getPosition().z == autoWalkPos.z then
                g_game.attack(creatureThing)
                return true
            elseif useThing:isContainer() then
                if modules.client_options.getOption("walkRightClick") and useThing:getPosition().x ~= 65535 and getItemDistance(useThing:getPosition(), player:getPosition(true)) > 1 then
                    return true
                end
                if useThing:getParentContainer() then
                    g_game.open(useThing, useThing:getParentContainer())
                    return true
                else
                    g_game.open(useThing)
                    return true
                end
            elseif useThing:isMultiUse() then
                if modules.client_options.getOption("walkRightClick") and useThing:getPosition().x ~= 65535 and getItemDistance(useThing:getPosition(), player:getPosition(true)) > 1 then
                    return true
                end
                startUseWith(useThing)
                return true
            else
                if modules.client_options.getOption("walkRightClick") and useThing:getPosition().x ~= 65535 and getItemDistance(useThing:getPosition(), player:getPosition(true)) > 1 then
                    return true
                end
                g_game.use(useThing)
                return true
            end
            return true
        elseif
            useThing and useThing:isContainer() and keyboardModifiers == KeyboardShiftModifier and
                mouseButton == MouseRightButton and
                modules.client_options.getOption("containerShiftRightClickNewWindow")
         then
            g_game.open(useThing)
            return true
        elseif
            lookThing and keyboardModifiers == KeyboardShiftModifier and
                (mouseButton == MouseLeftButton or mouseButton == MouseRightButton)
         then
            g_game.look(lookThing)
            return true
        elseif
            lookThing and
                ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton) or
                    (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton))
         then
            g_game.look(lookThing)
            return true
        elseif
            useThing and keyboardModifiers == KeyboardCtrlModifier and
                (mouseButton == MouseLeftButton or mouseButton == MouseRightButton)
         then
            createThingMenu(menuPosition, lookThing, useThing, creatureThing)
            return true
        elseif
            attackCreature and g_keyboard.isAltPressed() and
                (mouseButton == MouseLeftButton or mouseButton == MouseRightButton)
         then
            g_game.attack(attackCreature)
            return true
        elseif
            creatureThing and creatureThing:getPosition().z == autoWalkPos.z and g_keyboard.isAltPressed() and
                (mouseButton == MouseLeftButton or mouseButton == MouseRightButton)
         then
            g_game.attack(creatureThing)
            return true
        end
    end

    local player = g_game.getLocalPlayer()
    if player then
        player:stopAutoWalk()
    end

    if
        autoWalkPos and keyboardModifiers == KeyboardNoModifier and
            (mouseButton == MouseLeftButton or mouseButton == MouseTouch2 or mouseButton == MouseTouch3)
     then
        if mouseButton == MouseLeftButton then
            local leftAction = modules.client_options.getOption("leftMouseAction")
            if leftAction == LEFT_MOUSE_ACTION.NOTHING then
                return true
            elseif leftAction == LEFT_MOUSE_ACTION.ORDER then
                return modules.game_playeractionbar.orderAt(menuPosition)
            end
        end

        local autoWalkTile = g_map.getTile(autoWalkPos)
        if autoWalkTile and not autoWalkTile:isWalkable(true) then
            modules.game_textmessage.displayFailureMessage(tr("Sorry, not possible."))
            return false
        end
        player:autoWalk(autoWalkPos)
        return true
    end

    return false
end

function moveStackableItem(item, toPos)
    if countWindow then
        return
    end
    if g_keyboard.isCtrlPressed() then
        g_game.move(item, toPos, item:getCount())
        return
    elseif g_keyboard.isShiftPressed() then
        g_game.move(item, toPos, 1)
        return
    end
    local count = item:getCount()

    countWindow = g_ui.createWidget("CountWindow", rootWidget)
    local itembox = countWindow:getChildById("item")
    local spinbox = countWindow.countSpinner.field
    itembox:setItemId(item:getId())
    itembox:setItemCount(count)

    spinbox:setMinimum(1)
    spinbox:setMaximum(count)
    spinbox:setValue(count)

    spinbox.onValueChange = function(self, value)
        itembox:setItemCount(value)
    end

    local okButton = countWindow:getChildById("buttonOk")
    local moveFunc = function()
        g_game.move(item, toPos, spinbox:getValue())
        okButton:getParent():destroy()
        countWindow = nil
    end
    local cancelButton = countWindow:getChildById("buttonCancel")
    local cancelFunc = function()
        cancelButton:getParent():destroy()
        countWindow = nil
    end

    countWindow:setupModal(cancelFunc)
    countWindow.onEnter = moveFunc
    countWindow.onEscape = cancelFunc

    okButton.onClick = moveFunc
    cancelButton.onClick = cancelFunc
    countWindow:getChildById("closeBtn").onClick = cancelFunc

    spinbox:focus()
end

function getRootPanel()
    return gameRootPanel
end

function getFloatLayer()
    return gameFloatPanel
end

function isSidePanel(panel)
    return panel ~= nil and (gameRightPanels:hasChild(panel) or gameLeftPanels:hasChild(panel))
end

function getMapPanel()
    return gameMapPanel
end

local function addRightPanel()
    if gameRightPanels:getChildCount() >= 4 then
        return
    end
    local panel = g_ui.createWidget("GameSidePanel")
    panel:setId("rightPanel" .. (gameRightPanels:getChildCount() + 1))
    gameRightPanels:insertChild(1, panel)
end

local function addLeftPanel()
    if gameLeftPanels:getChildCount() >= 4 then
        return
    end
    local panel = g_ui.createWidget("GameSidePanel")
    panel:setId("leftPanel" .. (gameLeftPanels:getChildCount() + 1))
    gameLeftPanels:addChild(panel)
end

function getRightPanel()
    if gameRightPanels:getChildCount() > 0 then
        return gameRightPanels:getChildByIndex(-1)
    end
    if gameLeftPanels:getChildCount() > 0 then
        return gameLeftPanels:getChildByIndex(-1)
    end
    addRightPanel()
    return gameRightPanels:getChildByIndex(-1)
end

function getLeftPanel()
    if gameLeftPanels:getChildCount() >= 1 then
        return gameLeftPanels:getChildByIndex(-1)
    end
    return getRightPanel()
end

local function removeRightPanel()
    if gameRightPanels:getChildCount() == 0 then
        return
    end
    local panel = gameRightPanels:getChildByIndex(1)
    if gameRightPanels:getChildCount() >= 2 then
        panel:moveTo(gameRightPanels:getChildByIndex(2))
    else
        panel:moveTo(gameLeftPanels:getChildByIndex(1))
    end
    gameRightPanels:removeChild(panel)
end

local function removeLeftPanel()
    if gameLeftPanels:getChildCount() == 0 then
        return
    end
    local panel = gameLeftPanels:getChildByIndex(-1)
    if gameLeftPanels:getChildCount() >= 2 then
        panel:moveTo(gameLeftPanels:getChildByIndex(-2))
    else
        panel:moveTo(gameRightPanels:getChildByIndex(1))
    end
    gameLeftPanels:removeChild(panel)
end

function moveToVerticalPanel(widget)
    for i = gameRightPanels:getChildCount(), 1, -1 do
        local panel = gameRightPanels:getChildByIndex(i)
        if panel:getEmptySpaceHeight() >= widget:getHeight() then
            widget:setParent(panel)
            return true
        end
    end
    for i = 1, gameLeftPanels:getChildCount() do
        local panel = gameLeftPanels:getChildByIndex(i)
        if panel:getEmptySpaceHeight() >= widget:getHeight() then
            widget:setParent(panel)
            return true
        end
    end
    widget:setParent(getRightPanel())
    return true
end

function evacuatePanel(panel)
    local children = panel:getChildren()
    for i = #children, 1, -1 do
        moveToVerticalPanel(children[i])
    end
end

function updateHorizontalDockWidths()
    horizontalLeftDock:setWidth(gameLeftPanels:getWidth())
    horizontalRightDock:setWidth(gameRightPanels:getWidth())
    if gameRootPanel:isVisible() then
        local maxHeight = math.min(800, math.max(gameRootPanel:getHeight() - 200, 100))
        horizontalLeftResizeBorder:setMaximum(maxHeight)
        horizontalRightResizeBorder:setMaximum(maxHeight)
        for _, dock in ipairs({horizontalLeftDock, horizontalRightDock}) do
            if dock:getHeight() > maxHeight then
                dock:setHeight(maxHeight)
            end
        end
    end
end

function updateHorizontalPanelSkins()
    local classic = g_settings.getBoolean("classicView") and not g_app.isMobile()
    local color = classic and "white" or "alpha"
    horizontalLeftPanel:setImageColor(color)
    horizontalRightPanel:setImageColor(color)
end

local function applyDockState(dock, panel, column, enabled, settings, heightKey)
    if enabled and column:getChildCount() > 0 and not g_app.isMobile() then
        local height = math.max(tonumber(settings[heightKey]) or 300, 100)
        if gameRootPanel:isVisible() then
            height = math.min(height, math.max(gameRootPanel:getHeight() - 200, 100))
        end
        dock:setHeight(height)
    else
        if dock:getHeight() > 0 then
            settings[heightKey] = dock:getHeight()
        end
        dock:setHeight(0)
        evacuatePanel(panel)
    end
end

function updateHorizontalPanels()
    local settings = g_settings.getNode("game_interface") or {}
    applyDockState(horizontalLeftDock, horizontalLeftPanel, gameLeftPanels, g_settings.getBoolean("topLeftPanel"), settings, "horizontalLeftHeight")
    applyDockState(horizontalRightDock, horizontalRightPanel, gameRightPanels, g_settings.getBoolean("topRightPanel"), settings, "horizontalRightHeight")
    g_settings.setNode("game_interface", settings)
    updateHorizontalPanelSkins()
end

function getBottomPanel()
    return gameBottomPanel
end

function getBottomActionPanel()
    return gameBottomActionPanel
end

function getLeftActionPanel()
    return gameLeftActionPanel
end

function getRightActionPanel()
    return gameRightActionPanel
end

function getTopBar()
    return gameTopBar
end
function refreshView()
    if (g_settings.getBoolean("classicView")) then
        g_settings.set("classicView", false)
    else
        g_settings.set("classicView", true)
    end
    refreshViewMode()
end

function refreshViewMode()
    local classic = g_settings.getBoolean("classicView") and not g_app.isMobile()
    local rightCount = math.min(math.max(g_settings.getNumber("rightPanels") - 1, 0), 4)
    local leftCount = math.min(math.max(g_settings.getNumber("leftPanels") - 1, 0), 4)
    if rightCount == 0 and leftCount == 0 then
        modules.client_options.setOption("rightPanels", 2, true)
        rightCount = 1
    end

    while gameRightPanels:getChildCount() < rightCount do
        addRightPanel()
    end
    while gameLeftPanels:getChildCount() < leftCount do
        addLeftPanel()
    end
    while gameRightPanels:getChildCount() > rightCount do
        removeRightPanel()
    end
    while gameLeftPanels:getChildCount() > leftCount do
        removeLeftPanel()
    end

    updateHorizontalPanels()

    if not g_game.isOnline() then
        return
    end

    local minimumWidth = (rightCount + leftCount) * 200 + 200
    minimumWidth = math.max(minimumWidth, g_resources.getLayout() == "mobile" and 640 or 800)
    minimumWidth = math.min(minimumWidth, g_window.getDisplaySize().width)
    g_window.setMinimumSize({width = minimumWidth, height = (g_resources.getLayout() == "mobile" and 360 or 600)})
    if g_window.getWidth() < minimumWidth then
        local oldPos = g_window.getPosition()
        local size = {width = minimumWidth, height = g_window.getHeight()}
        g_window.resize(size)
        g_window.move(oldPos)
    end

    for i = 1, gameRightPanels:getChildCount() + gameLeftPanels:getChildCount() do
        local panel
        if i > gameRightPanels:getChildCount() then
            panel = gameLeftPanels:getChildByIndex(i - gameRightPanels:getChildCount())
        else
            panel = gameRightPanels:getChildByIndex(i)
        end
        if classic then
            panel:setImageColor("white")
        else
            panel:setImageColor("alpha")
        end
    end

    if classic then
        gameRightPanels:setMarginTop(0)
        gameLeftPanels:setMarginTop(0)
        gameMapPanel:setMarginLeft(0)
        gameMapPanel:setMarginRight(0)
        gameMapPanel:setMarginTop(0)
    end

    gameMapPanel:setVisibleDimension({width = 21, height = 11})

    if classic then
        g_game.changeMapAwareRange(21, 11)
        gameMapPanel:addAnchor(AnchorLeft, "gameLeftActionPanel", AnchorRight)
        gameMapPanel:addAnchor(AnchorRight, "gameRightActionPanel", AnchorLeft)
        gameMapPanel:addAnchor(AnchorBottom, "gameBottomActionPanel", AnchorTop)
        gameMapPanel:addAnchor(AnchorTop, "gameTopBar", AnchorBottom)
        gameMapPanel:setKeepAspectRatio(true)
        gameMapPanel:setLimitVisibleRange(true)
        gameMapPanel:setMarginBottom(0)
        gameMapPanel:setZoom(11)
        gameMapPanel:setOn(false)
        modules.client_topmenu.getTopMenu():setImageColor("white")
    else
        g_game.changeMapAwareRange(21, 11)
        gameMapPanel:setKeepAspectRatio(true)
        gameMapPanel:setLimitVisibleRange(false)
        gameMapPanel:setOn(true)
        gameMapPanel:fill("parent")
        gameMapPanel:setMarginBottom(-90)

        if g_app.isMobile() then
            gameMapPanel:setZoom(11)
        else
            gameMapPanel:setZoom(11)
        end

        modules.client_topmenu.getTopMenu():setImageColor("#ffffff66")
        if g_app.isMobile() then
            gameMapPanel:setMarginTop(-32)
        end
    end
    if modules.game_playeractionbar then
        modules.game_playeractionbar.switchMode(classic)
    end

    if modules.game_chat then
        modules.game_chat.switchMode(classic)
    end

    updateSize()
    if modules.game_autoloot then
        modules.game_autoloot.updateLootList(classic)
    end

    if modules.game_notifications then
        modules.game_notifications.refreshPosition()
    end

    applySidePanelOpacity()
end

function limitZoom()
    limitedZoom = true
end

function updateSize()
    if g_app.isMobile() then
        return
    end

    local classic = g_settings.getBoolean("classicView")
    local height = gameMapPanel:getHeight()
    local width = gameMapPanel:getWidth()

    if not classic then
        local rheight = gameRootPanel:getHeight()
        local rwidth = gameRootPanel:getWidth()

        local dimenstion = gameMapPanel:getVisibleDimension()
        local zoom = gameMapPanel:getZoom()
        local awareRange = g_map.getAwareRange()
        local dheight = dimenstion.height
        local dwidth = dimenstion.width
        local tileSize = rheight / dheight
        local maxWidth = tileSize * (awareRange.width + 1)
        gameMapPanel:setMarginTop(-tileSize)
        if modules.game_stats then
            modules.game_stats.ui:setMarginTop(tileSize)
        end

        local margin = math.max(0, math.floor((rwidth - maxWidth) / 2))
        gameMapPanel:setMarginLeft(margin)
        gameMapPanel:setMarginRight(margin)

        if modules.game_bot then
            for i, child in ipairs(gameMapPanel:getChildren()) do
                if child.botIcon and child.onGeometryChange then
                    child.onGeometryChange(child)
                end
            end
        end
    else
        if modules.game_stats then
            modules.game_stats.ui:setMarginTop(0)
        end
    end
end

function setupLeftActions()
    if not g_app.isMobile() then
        return
    end
    for _, widget in ipairs(gameLeftActions:getChildren()) do
        widget.image:setChecked(false)
        widget.lastClicked = 0
        widget.onClick = function()
            if widget.image:isChecked() then
                widget.image:setChecked(false)
                if widget.doubleClickAction and widget.lastClicked + 200 > g_clock.millis() then
                    widget.doubleClickAction()
                end
                return
            end
            resetLeftActions()
            widget.image:setChecked(true)
            widget.lastClicked = g_clock.millis()
        end
    end
    if gameLeftActions.use then
        gameLeftActions.use.doubleClickAction = function()
            local player = g_game.getLocalPlayer()
            local dir = player:getDirection()
            local usePos = player:getPrewalkingPosition(true)
            if dir == North then
                usePos.y = usePos.y - 1
            elseif dir == East then
                usePos.x = usePos.x + 1
            elseif dir == South then
                usePos.y = usePos.y + 1
            elseif dir == West then
                usePos.x = usePos.x - 1
            end
            local tile = g_map.getTile(usePos)
            if not tile then
                return
            end
            local thing = tile:getTopUseThing()
            if thing then
                g_game.use(thing)
            end
        end
    end
    if gameLeftActions.attack then
        gameLeftActions.attack.doubleClickAction = function()
            local battlePanel = modules.game_battle.battlePanel
            local attackedCreature = g_game.getAttackingCreature()
            local child = battlePanel:getFirstChild()
            if child and (not child.creature or not child:isOn()) then
                child = nil
            end
            if child then
                g_game.attack(child.creature)
            else
                g_game.attack(nil)
            end
        end
    end
    if gameLeftActions.follow then
        gameLeftActions.follow.doubleClickAction = function()
            local battlePanel = modules.game_battle.battlePanel
            local attackedCreature = g_game.getAttackingCreature()
            local child = battlePanel:getFirstChild()
            if child and (not child.creature or not child:isOn()) then
                child = nil
            end
            if child then
                g_game.follow(child.creature)
            else
                g_game.follow(nil)
            end
        end
    end
    if gameLeftActions.look then
        gameLeftActions.look.doubleClickAction = function()
            local battlePanel = modules.game_battle.battlePanel
            local attackedCreature = g_game.getAttackingCreature()
            local child = battlePanel:getFirstChild()
            if child and (not child.creature or child:isHidden()) then
                child = nil
            end
            if child then
                g_game.look(child.creature)
            end
        end
    end
    if not gameLeftActions.chat then
        return
    end
    gameLeftActions.chat.onClick = function()
        if gameBottomPanel:getHeight() <= 5 then
            gameBottomPanel:setHeight(90)
        else
            gameBottomPanel:setHeight(0)
        end
    end
end

function resetLeftActions()
    for _, widget in ipairs(gameLeftActions:getChildren()) do
        widget.image:setChecked(false)
        widget.lastClicked = 0
    end
end

function getLeftAction()
    for _, widget in ipairs(gameLeftActions:getChildren()) do
        if widget.image:isChecked() then
            return widget:getId()
        end
    end
    return ""
end

function isChatVisible()
    return gameBottomPanel:getHeight() >= 5
end

function getMouseGrabberWidget()
    return mouseGrabberWidget
end

function getContainerSubPanel(panelChildren, widget)
  local parent = panelChildren[#panelChildren]
  local children = parent:getChildren()

  -- Desconta o espaco que o painel JA tem livre. Sem isto a conta partia da altura cheia do widget
  -- e fechava janelas a mais: com 100px livres e um widget de 120px, bastava liberar 20px, mas o
  -- laco so parava depois de somar 120px de janelas fechadas.
  local faltaHeight = widget:getHeight() - parent:getEmptySpaceHeight()
  if faltaHeight <= 0 then
    return parent
  end

  local widgetHeight = faltaHeight
  for i = #children, 1, -1 do
    local child = children[i]
    if child:isVisible() then
      local styleName = child:getStyleName()
      if styleName == "UIMiniWindow" or styleName == "MiniWindow" then
        widgetHeight = widgetHeight - child:getHeight()
        child:close()
        if widgetHeight <= 0 then
          break
        end
      end
    end
  end
  return parent
end

function getRealContainerPanel()
  if gameRightPanels:getChildCount() == 0 then
    return getLeftPanel()
  end
  local containerPanel = g_settings.getNumber("containerPanel")
  if containerPanel >= 5 then
    containerPanel = containerPanel - 4
  end
  return gameRightPanels:getChildByIndex(math.min(containerPanel, gameRightPanels:getChildCount()))
end


function getContainerPanel(widget)
  local containerPanel = g_settings.getNumber("containerPanel")
  -- Guardado ANTES de qualquer uso: `containerPanel` e reatribuido duas vezes abaixo (o -4 do bloco
  -- da direita e o clamp do bloco da esquerda), entao no fim da funcao ele ja nao diz mais de que
  -- lado era a preferencia.
  local prefersRightPanel = containerPanel >= 5
  local rightPanelChildren = gameRightPanels:getChildren()
  if prefersRightPanel then
    containerPanel = math.min(containerPanel - 4, #rightPanelChildren)
    local availableRightPanels = {}
    for i = 1, #rightPanelChildren do
      if rightPanelChildren[i]:getEmptySpaceHeight() - widget:getHeight() >= 0 then
        if i == containerPanel then
          return rightPanelChildren[i]
        else
          table.insert(availableRightPanels, 1, rightPanelChildren[i])
        end
      end
    end
    if #availableRightPanels > 0 then
      return availableRightPanels[1]
    end
  end
  
  local leftPanelChildren = gameLeftPanels:getChildren()
  if #leftPanelChildren == 0 then
    return getContainerSubPanel(rightPanelChildren, widget)
  end
  containerPanel = math.min(containerPanel, #leftPanelChildren)
  local availableLeftPanels = {}
  for i = 1, #leftPanelChildren do
    if leftPanelChildren[i]:getEmptySpaceHeight() - widget:getHeight() >= 0 then
      if i == containerPanel then
        return leftPanelChildren[i]
      else
        table.insert(availableLeftPanels, 1, leftPanelChildren[i])
      end
    end
  end
  if #availableLeftPanels > 0 then
    return availableLeftPanels[1]
  end

  -- Ninguem tem espaco: alguem vai ser FECHADO para abrir vaga (getContainerSubPanel). Quem paga
  -- essa conta tem de ser o lado que o jogador escolheu para os containers, e nao o outro.
  --
  -- Antes caia sempre no painel da ESQUERDA. Com a preferencia na direita (containerPanel >= 5),
  -- encher a direita ate o fim fazia o codigo escorregar para o bloco da esquerda e fechar bags de
  -- la -- bags que o jogador nunca pediu para ficarem sujeitas a isso.
  --
  -- O escorregar em si continua: direita cheia + esquerda COM espaco segue mandando para a
  -- esquerda, que e conveniencia util. So a escolha de quem fechar e que muda.
  if prefersRightPanel and #rightPanelChildren > 0 then
    return getContainerSubPanel(rightPanelChildren, widget)
  end
  return getContainerSubPanel(leftPanelChildren, widget)
end