local pokebar = nil
local pokebarButton = nil
local MouseGrabberWidget = nil
local maxPokes = 6
local pokeballs = {}
local hotkeyDelayTo = 0
local pokebarSettings = nil
local pokebarCooldowns = {}
local cooldownCycleEvent = nil
local activeSlot = nil
local activeBarTracker = nil
local slotsPanel = nil

-- The slots live in contentsPanel now; UIMiniWindow needs that child to size and save itself
local function getSlot(i)
    return slotsPanel and slotsPanel:getChildById("poke" .. i) or nil
end

-- Per-pokemon portrait clip offsets (dex number -> {x, y})
-- Adjusts the default 80x80 clip region (starting at x=30, y=10) of 140x140 pokedex images
PokemonPortraitOffsets = {}

-- Active slot scale animation config
local POKEMON_CALL_DELAY = 250
local SCALE_FACTOR = 1.20
local TRANSITION_SPEC = string.format("%dms cubic", POKEMON_CALL_DELAY)

local function getScaleMode()
    if not modules.client_options then return 1 end
    return modules.client_options.getOption('pokebarScaleMode') or 1
end

local function animateSlotGrow(slot)
    if not pokebar then return end
    local mode = getScaleMode()
    if mode == 3 then return end -- Disabled
    local item = getSlot(slot)
    if not item then return end
    item:applyScaleTransition(SCALE_FACTOR, TRANSITION_SPEC, mode)
end

local function animateSlotShrink(slot)
    if not pokebar then return end
    local mode = getScaleMode()
    if mode == 3 then return end -- Disabled
    local item = getSlot(slot)
    if not item then return end
    item:applyScaleTransition(1.0, TRANSITION_SPEC, mode)
end

local function resetSlotScale(slot)
    if not pokebar then return end
    local item = getSlot(slot)
    if not item then return end
    item:resetScaleTransition()
end

local function setBarClip(widget, percent)
    local w = widget:getWidth()
    local h = widget:getHeight()
    local clipW = math.max(1, math.floor(w * math.max(0, math.min(100, percent)) / 100))
    widget:setImageRect({x = 0, y = 0, width = clipW, height = h})
end

local function getMoveCooldownStats(spells)
    local maxRemaining, maxTotal, totalMoves, readyMoves = 0, 0, 0, 0
    for _, spell in ipairs(spells) do
        if spell.spellword ~= "passive" then
            totalMoves = totalMoves + 1
            local cd = spell.currentCooldown or 0
            local total = spell.cooldown or 0
            if cd > 0 then
                if cd > maxRemaining then
                    maxRemaining = cd
                    maxTotal = total
                end
            else
                readyMoves = readyMoves + 1
            end
        end
    end
    return maxRemaining, maxTotal, readyMoves, totalMoves
end

local function updateSlotText(slot, readyMoves, totalMoves)
    if not pokebar then return end
    local item = getSlot(slot)
    if not item then return end
    local cdText = item:getChildById("cooldownText")
    if cdText and totalMoves > 0 then
        cdText:setText(readyMoves .. "/" .. totalMoves)
    end
end

local boundKeys = {
  chatEnabled = {},
  chatDisabled = {}
}

local boundKeysUI = {
  chatEnabled = {},
  chatDisabled = {}
}

local POKE_SLOT_HEIGHT = 45
local showHotkeys = false

local POKEBAR_SIZE = {
    [1] = 0.8,  -- Compact
    [2] = 1.0,  -- Normal
    [3] = 1.2,  -- Large
}

local function getSizeScale()
    if not modules.client_options then return 1.0 end
    return POKEBAR_SIZE[modules.client_options.getOption('pokebarSizeMode') or 2] or 1.0
end

local function slotHeight(scale)
    scale = scale or getSizeScale()
    local base = POKE_SLOT_HEIGHT
    return math.floor(base * scale + 0.5)
end

local function applySlotSize(item, scale)
    if not item then return end
    local function dim(id, w, h)
        local c = item:getChildById(id)
        if c then
            c:setWidth(math.floor(w * scale + 0.5))
            c:setHeight(math.floor(h * scale + 0.5))
        end
    end
    dim("bar", 180, 45)
    local clip = item:getChildById("portraitClip")
    if clip then
        local s = math.floor(32 * scale + 0.5)
        clip:setWidth(s)
        clip:setHeight(s)
        clip:setImageSize(tosize(s .. ' ' .. s))
    end
    dim("lifeBackground", 125, 15)
    dim("life", 123, 13)
    dim("cooldownBackground", 86, 14)
    dim("cooldownProgress", 84, 12)
    local f = math.max(10, math.min(14, math.floor(12 * scale + 0.5)))
    local percent = item:getChildById("percent")
    if percent then percent:setFont('poppins semibold ' .. f) end
    local cdText = item:getChildById("cooldownText")
    if cdText then cdText:setFont('poppins semibold ' .. f) end
    item:setWidth(math.floor(180 * scale + 0.5))
end

local function acceptsPokebarHotkey(chatState)
  if not isChatStateCorrect(chatState == "chatEnabled") then
    return false
  end
  if hotkeyDelayTo ~= nil and g_clock.millis() < hotkeyDelayTo then
    return false
  end
  hotkeyDelayTo = g_clock.millis() + 200
  return true
end

local function pokebarFactory(actionName, action, keyInfo, chatState, keyType)
  local number = tonumber(actionName:match("%d+"))
  if number and keyType == "primaryKey" and boundKeysUI[chatState] then
    boundKeysUI[chatState][number] = keyInfo and keyInfo.key or nil
  end
  local callback = function()
    if number and acceptsPokebarHotkey(chatState) then
      changePokemon(number)
    end
  end
  return { callback = callback, widget = modules.game_interface.getRootPanel() }
end

local function pokebarCycleFactory(actionName, action, keyInfo, chatState, keyType)
  local callback = function()
    if acceptsPokebarHotkey(chatState) then
      cycleNextPokemon()
    end
  end
  return { callback = callback, widget = modules.game_interface.getRootPanel() }
end

local function pokebarAssign(actionName, action, keyInfo, chatState, keyType)
  local number = tonumber(actionName:match("%d+"))
  if number and keyType == "primaryKey" and boundKeysUI[chatState] then
    boundKeysUI[chatState][number] = keyInfo and keyInfo.key or nil
  end
  updateUI(chatState)
end

for i = 1, 6 do
  modules.client_hotkeys.registerHotkeyCallback("POKEBAR_" .. i, pokebarFactory, pokebarAssign)
end

modules.client_hotkeys.registerHotkeyCallback("POKEBAR_CYCLE", pokebarCycleFactory)

function onGameStart()
    if not g_game.isOnline() then
        return
    end

    if pokeBarButton then
        pokeBarButton:destroy()
    end

    pokeBarButton = modules.client_topmenu.addMiddleGameToggleButton("pbarButton", tr("Pokémon Bar"),
        "/images/ui/topbuttons/icons/bar_icon", toggle)
    pokeBarButton:setWidth(34)
    pokeBarButton:setOn(false)

    if pokebar then
        pokebar:destroy()
        pokebar = nil
    end

    pokebar = g_ui.loadUI("pokebar", modules.game_interface.getRightPanel())
    slotsPanel = pokebar:recursiveGetChildById('contentsPanel')
    pokebar:disableResize()
    MouseGrabberWidget = g_ui.createWidget('UIWidget')
    MouseGrabberWidget:setVisible(false)
    MouseGrabberWidget:setFocusable(false)
    MouseGrabberWidget.onMouseRelease = onDropPokebar

    -- setup() wires lock/minimize/topbar-drag by id and restores the saved column, geometry and
    -- floating flag. DockableWindow then drives dock/undock through the native path.
    pokebar:setup()
    pokebar.onMaximize = refreshHeight
    DockableWindow.register(pokebar)

    for i = 1, maxPokes do
        local item = getSlot(i)
        if item then
            item.onDragEnter = onDragEnter
            item.onDragMove = onDragMove
            item.onDragLeave = onDragLeave
            item.id = i
            item:hide()

            -- On the item, not on its children: every child is phantom, and UIManager resolves the
            -- pressed widget with recursiveGetChildByPos(pos, false), which skips phantom. onClick
            -- only fires when press and release land on that same widget, so dragging the window by
            -- its top bar and letting go over a slot no longer switches pokemon.
            item.onClick = function(widget, pos)
                if g_ui.isMouseGrabbed() then return end
                changePokemon(i)
            end

            -- The right button never produces a pressed widget (UIManager tracks one for the left
            -- and touch buttons only), so it cannot go through onClick. Going through the release
            -- is safe for it: only the left button drags the window, so a right release over a slot
            -- is always a real click and never the tail of a move.
            item.onMouseRelease = function(widget, pos, button)
                if button ~= MouseRightButton then return false end
                if g_ui.isMouseGrabbed() then return false end
                changePokemon(i)
                return true
            end

            local children = item:getChildren()
            for j = 1, #children do
                if children[j]:getId() ~= "pokeName" then
                    children[j].onDragEnter = onDragEnter
                    children[j].onDragMove = onDragMove
                    children[j].onDragLeave = onDragLeave
                end
            end
        end
    end

    local openned = g_settings.getBoolean('pokebar-active', true)
    pokeBarButton:setOn(openned)
    if openned then pokebar:open() else pokebar:close() end

    applyMinimizedState()
    local show = true
    if modules.client_options and modules.client_options.getOption then
        show = modules.client_options.getOption('showPokebarHotkeys')
    end
    setShowHotkeys(show)

    if modules.client_options and modules.client_options.getOption then
        setShowPortrait(modules.client_options.getOption('pokebarShowPortrait'))
        setShowHpPercent(modules.client_options.getOption('pokebarShowHpPercent'))
        setShowCooldownText(modules.client_options.getOption('pokebarShowCooldownText'))
    end
end

function onGameEnd()
    if pokebar then
        pokebar:destroy()
        pokebar = nil
    end

    if pokebarButton then
        pokebarButton:destroy()
        pokebarButton = nil
    end

    if MouseGrabberWidget then
        MouseGrabberWidget:destroy()
        MouseGrabberWidget = nil
    end

    pokeballs = {}
    pokebarCooldowns = {}
    activeSlot = nil
    for i = 1, maxPokes do
        resetSlotScale(i)
    end
    stopCooldownCycle()
end

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onPokeBarReceived = onPokeBarReceived,
        onPokemonInfoReceived = onPokemonInfoReceived,
        onPokeballUpdateReceived = onPokeballUpdateReceived,
        onMovebarReceived = onMovebarReceived,
        onMovebarCooldownUpdate = onMovebarCooldownUpdate
    })

    if g_game.isOnline() then
        onGameStart()
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onPokeBarReceived = onPokeBarReceived,
        onPokemonInfoReceived = onPokemonInfoReceived,
        onPokeballUpdateReceived = onPokeballUpdateReceived,
        onMovebarReceived = onMovebarReceived,
        onMovebarCooldownUpdate = onMovebarCooldownUpdate
    })
    stopCooldownCycle()
end

function applyMinimizedState()
    if not pokebar then return end
    for i = 1, maxPokes do
        local item = getSlot(i)
        if item then item:setVisible(pokeballs[i] ~= nil) end
    end
    refreshHeight()
end

function onMiniWindowClose()
    if pokeBarButton then pokeBarButton:setOn(false) end
    g_settings.set("pokebar-active", false)
end

function toggle()
    if pokeBarButton and pokeBarButton:isOn() then
        pokeBarButton:setOn(false)
        pokebar:close()
        g_settings.set("pokebar-active", false)
    else
        pokeBarButton:setOn(true)
        g_settings.set("pokebar-active", true)
        pokebar:open()
        refreshHeight()
    end
end

-- Same rule as UIWidget::fitParentToChildren, which rewrites both values on
-- every scale-animation tick; diverging here would fight the scale transition.
-- Measured off the base slot height, not off the children: the active slot grows by SCALE_FACTOR
-- and applyScaleTransition -> fitParentToChildren resizes contentsPanel, which is the slots' parent,
-- never the window. Reading the grown children back would feed that growth into the window height
-- every refresh. The headroom below is reserved once so the grown slot always fits.
function refreshHeight()
    if not pokebar or not slotsPanel then return end
    -- minimized the height belongs to the collapse; onMaximize recomputes it from the live slots
    if pokebar:isOn() then return end
    local base = slotHeight()
    local count = 0
    local margins = 0
    for _, child in ipairs(slotsPanel:getChildren()) do
        -- explicit: with the window closed or minimized contentsPanel is hidden and isVisible()
        -- reports every populated slot as gone, collapsing the height
        if child:isExplicitlyVisible() then
            count = count + 1
            margins = margins + child:getMarginTop()
        end
    end

    local height = count * base + margins
    if count > 0 and getScaleMode() ~= 3 then
        height = height + math.ceil(base * (SCALE_FACTOR - 1))
    end
    pokebar:setContentHeight(height)
end

function onScaleModeChanged(newMode)
    if not pokebar then return end
    -- Reset all slots first
    for i = 1, maxPokes do
        resetSlotScale(i)
    end
    refreshHeight()
    -- Re-apply grow on active slot if not disabled
    if activeSlot and newMode ~= 3 then
        local item = getSlot(activeSlot)
        if item then
            item:applyScaleTransition(SCALE_FACTOR, TRANSITION_SPEC, newMode)
        end
    end
end

local function reapplyBarClips()
    if not pokebar then return end
    for i = 1, maxPokes do
        if pokeballs[i] then
            local item = getSlot(i)
            local life = item and item:getChildById("life")
            if life then setBarClip(life, pokeballs[i].health or 0) end
        end
    end
    updateAllCooldownBars()
end

function onSizeModeChanged(mode)
    if not pokebar then return end
    local scale = POKEBAR_SIZE[mode] or 1.0
    local h = slotHeight(scale)
    for i = 1, maxPokes do
        resetSlotScale(i)
        local item = getSlot(i)
        if item then
            applySlotSize(item, scale)
            item:setHeight(h)
        end
    end
    refreshHeight()
    reapplyBarClips()
    if activeSlot and getScaleMode() ~= 3 then
        animateSlotGrow(activeSlot)
    end
end

local function applyChildVisibility(childId, show)
    if not pokebar then return end
    for i = 1, maxPokes do
        local item = getSlot(i)
        local child = item and item:getChildById(childId)
        if child then child:setVisible(show) end
    end
end

function setShowPortrait(show)
    applyChildVisibility("portraitClip", show)
end

function setShowHpPercent(show)
    applyChildVisibility("percent", show)
end

function setShowCooldownText(show)
    applyChildVisibility("cooldownText", show)
end

function resetBars()
    if not slotsPanel then return end
    -- Cancel all slot animations and reset scales
    for i = 1, maxPokes do
        resetSlotScale(i)
    end
    pokebarCooldowns = {}
    activeSlot = nil
    stopCooldownCycle()
    for numeration = 1, maxPokes do
        local pokeBarItem = getSlot(numeration)
        local pokeBarBar = pokeBarItem:getChildById("bar")

        if pokeBarBar then
            pokeBarItem:recursiveGetChildById("portrait"):setImageSource("")
            pokeBarItem:getChildById("percent"):setText("")
            setBarClip(pokeBarItem:getChildById("life"), 0)
            local cdBar = pokeBarItem:getChildById("cooldownProgress")
            if cdBar then
                setBarClip(cdBar, 1)
            end
            pokeBarItem:hide()
        end
    end
end

function getPlayerPokeballs()
    return pokeballs and pokeballs or false
end

-- Slot of the pokemon currently out of its ball (nil when all are stored).
function getActiveSlot()
    return activeSlot
end

function onPokeBarReceived(data)
    -- Remember which UUID was active so we can re-find it after reindex
    local savedActiveUUID = nil
    if activeSlot and pokeballs[activeSlot] then
        savedActiveUUID = pokeballs[activeSlot].uuid
    end

    pokeballs = {}
    resetBars()

    local pokeballList = data.pokeballs
    local globalAbilityValue = data.abilityValue or 0
    
    if not pokeballList or #pokeballList == 0 then
        if pokebar then pokebar:hide() end
        return
    end

    for i, pokeball in ipairs(pokeballList) do
        local buffer = {
            name = pokeball.name,
            boost = pokeball.boost,
            portrait = pokeball.portrait,
            health = pokeball.health,
            price = pokeball.price,
            uuid = pokeball.uuid
        }
        table.insert(pokeballs, buffer)

        if savedActiveUUID and pokeball.uuid == savedActiveUUID then
            activeSlot = i
        end

        -- Process cooldown data embedded in each pokeball
        if pokeball.moves and #pokeball.moves > 0 then
            processCooldownData(i, globalAbilityValue, pokeball.moves)
        end
    end

    -- All data processed, now start cycle once
    stopCooldownCycle()
    updateAllCooldownBars()
    startCooldownCycle()
    
    if pokebar and g_settings.getBoolean('pokebar-active', true) then
        pokebar:show()
    end
    
    for index, config in pairs(pokeballs) do
        local pokeBarItem = getSlot(index)
        if not pokeBarItem then
            return
        end
        local pokeBarBar = pokeBarItem:getChildById("bar")
        if pokeBarBar then
            local dexNumber = g_pokemonCyclopedia.getDexNumber(config.name:lower())
            local portrait = pokeBarItem:recursiveGetChildById("portrait")
            if dexNumber ~= "" then
                portrait:setImageSource("/images/pokemons/" .. dexNumber)
                -- Clip center-top region of 140x140 image (head/face area)
                local clipX, clipY = 10, 10
                local offset = PokemonPortraitOffsets[dexNumber]
                if offset then
                    clipX = clipX + (offset.x or 0)
                    clipY = clipY + (offset.y or 0)
                end
                portrait:setImageClip({x = clipX, y = clipY, width = 120, height = 120})
            else
                portrait:setImageSource("")
            end
            portrait:setTooltip(config.name)
            pokeBarItem:getChildById("percent"):setText(config.health .. "%")
            setBarClip(pokeBarItem:getChildById("life"), config.health)
            pokeBarItem:setVisible(true)
        end  
    end
    modules.game_pokemonshop.show(true)
    refreshHeight()

    if activeSlot then
        animateSlotGrow(activeSlot)
    end
end

function onPokeballUpdateReceived(data)
    if not data or not data.slot then return end
    local slot = data.slot
    if not pokebar then return end

    -- Update health
    local pokeBarItem = getSlot(slot)
    if pokeBarItem then
        local pokeBarBar = pokeBarItem:getChildById("bar")
        if pokeBarBar then
            pokeBarItem:getChildById("percent"):setText(data.health .. "%")
            setBarClip(pokeBarItem:getChildById("life"), data.health)
        end
        -- Update stored health
        if pokeballs[slot] then
            pokeballs[slot].health = data.health
        end
    end

    -- Process cooldown data (authoritative single-slot update)
    if data.moves then
        processCooldownData(slot, data.abilityValue or 0, data.moves)
        stopCooldownCycle()
        updateAllCooldownBars()
        startCooldownCycle()
    end
end

function processCooldownData(slot, abilityValue, moves)
    local hasCooldown = false
    local totalMoves = #moves
    for _, move in ipairs(moves) do
        if move.remaining and move.remaining > 0 then
            hasCooldown = true
            break
        end
    end

    pokebarCooldowns[slot] = {
        moves = moves,
        abilityValue = abilityValue,
        startTime = g_clock.millis(),
        inBall = true,
        completed = not hasCooldown
    }

    if not hasCooldown then
        setCooldownBarProgress(slot, 0, 1)
        updateSlotText(slot, totalMoves, totalMoves)
    end
end

-- Shift+drag swaps slots; plain dragging belongs to UIMiniWindow, which moves and docks the window
function onDragEnter(widget, pos)
    if not pokebar:isDraggable() then return true end
    local sourceIndex = tonumber(string.match(widget:getId(), "^poke(%d+)$"))
    if sourceIndex and g_keyboard.isShiftPressed() then
        if g_ui.isMouseGrabbed() then return end
        MouseGrabberWidget:grabMouse()
        g_mouse.pushCursor('target')
        widget:setBorderColor('#FFFFFF')
        pokebarSettings = { id = widget:getId(), widget = widget }
    end
    return true
end

function onDragMove(widget, pos, moved)
    return true
end

function onDragLeave(widget)
    swapPokeBar(g_window.getMousePosition())
    return true
end

function getPokebar()
    return pokebar
end

-- The slots sit inside contentsPanel, out of reach of a plain getChildByPos on the window
function getPokebarSlotAt(pos)
    if not slotsPanel then return nil end
    local widget = slotsPanel:recursiveGetChildByPos(pos, false)
    while widget and widget ~= slotsPanel do
        if tonumber(string.match(widget:getId() or '', "^poke(%d+)$")) then return widget end
        widget = widget:getParent()
    end
    return nil
end

function sendPokebarRevive(index, selectThing)
    g_game.requestPokebarRevive(selectThing, index)
end

function sendPokebarReviveByHotkey(index, itemId)
    g_game.requestPokebarReviveByItemId(itemId, index)
end

function changePokemon(index)
    g_game.requestChangePokemon(index)
end

function cycleNextPokemon()
    local count = #pokeballs
    if count == 0 then
        return
    end

    changePokemon((activeSlot or count) % count + 1)
end

function isChatStateCorrect(chatEnabled)
  local chatModeEnabled = not modules.game_chat.consoleToggleChat
  return (chatEnabled and chatModeEnabled) or (not chatEnabled and not chatModeEnabled)
end

function updateUI(chatState)
    if not pokebar then return end
    chatState = chatState or (isChatStateCorrect(true) and "chatEnabled" or "chatDisabled")
    local keys = boundKeysUI[chatState] or {}
    for i = 1, 6 do
        local item = getSlot(i)
        local label = item and item:getChildById("hotkeyLabel")
        if label then
            label:setText(keys[i] or "")
            label:setVisible(showHotkeys)
        end
    end
end

function setShowHotkeys(show)
    showHotkeys = show and true or false
    if not pokebar then return end
    local scale = getSizeScale()
    local h = slotHeight()
    for i = 1, maxPokes do
        local item = getSlot(i)
        if item then
            applySlotSize(item, scale)
            item:setHeight(h)
        end
    end
    updateUI()
    refreshHeight()
    reapplyBarClips()
end

function onDropPokebar(self, mousePosition, mouseButton)
    swapPokeBar(mousePosition)
end

function swapPokeBar(mousePosition)
    if not g_ui.isMouseGrabbed() then
        return
    end
    g_mouse.popCursor('target')
    MouseGrabberWidget:ungrabMouse()

    if not pokebarSettings then
        return
    end

    local sourceWidget = pokebarSettings.widget
    pokebarSettings = nil
    if not sourceWidget then
        return
    end

    local targetWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
    if not targetWidget or not targetWidget:getStyleName():find('UIPokeBarItem') then
        return
    end

    local sourceIndex = tonumber(string.match(sourceWidget:getId(), "^poke(%d+)$"))
    local targetIndex = tonumber(string.match(targetWidget:getId(), "^poke(%d+)$"))

    if not sourceIndex or not targetIndex or sourceIndex == targetIndex then
        return
    end

    g_game.swapPokeballs(sourceIndex, targetIndex)
end

function onPokemonInfoReceived(pokemonInfo)
    local infoType = pokemonInfo.infoType
    if infoType == 1 then
        local pokemonUUID = pokemonInfo.pokemonUUID

        -- Find which slot this pokemon is in and set it as active
        local foundSlot = nil
        for i, pokeball in ipairs(pokeballs) do
            if pokeball.uuid == pokemonUUID then
                foundSlot = i
                break
            end
        end

        if foundSlot then
            -- Shrink previous active slot if switching directly
            if activeSlot and activeSlot ~= foundSlot then
                animateSlotShrink(activeSlot)
            end

            activeSlot = foundSlot
            activeBarTracker = nil

            -- Initialize tracker from movebar data (movebar packet may have arrived before activeSlot was set)
            local moveCooldowns = modules.game_pokemoves.getCurrentMoveCooldowns()
            if moveCooldowns and #moveCooldowns > 0 then
                local maxRemaining, maxTotal, readyMoves, totalMoves = getMoveCooldownStats(moveCooldowns)
                updateSlotText(foundSlot, readyMoves, totalMoves)
                if maxRemaining > 0 then
                    activeBarTracker = {
                        baseRemaining = maxRemaining,
                        maxTotal = maxTotal,
                        startTime = g_clock.millis()
                    }
                end
            end

            startCooldownCycle()

            -- Animate active slot growing
            animateSlotGrow(foundSlot)

            if modules.client_options.getOption('pokemonInUseAlwaysOnTop') and foundSlot ~= 1 then
                g_game.movePokeballs(foundSlot, 1)
            end
        end
    elseif infoType == 0 then
        -- Pokemon returned to ball: snapshot live movebar into in-ball cooldowns
        if activeSlot then
            local moveCooldowns = modules.game_pokemoves.getCurrentMoveCooldowns()
            if moveCooldowns and #moveCooldowns > 0 then
                local maxRemaining, _, _, totalMoves = getMoveCooldownStats(moveCooldowns)

                local moves = {}
                for _, moveInfo in ipairs(moveCooldowns) do
                    if moveInfo.spellword ~= "passive" then
                        local cd = moveInfo.currentCooldown or 0
                        table.insert(moves, {
                            sw = moveInfo.spellword,
                            remaining = cd > 0 and cd or 0,
                            total = moveInfo.cooldown or 0
                        })
                    end
                end

                local abilityValue = (pokebarCooldowns[activeSlot] and pokebarCooldowns[activeSlot].abilityValue) or 0
                pokebarCooldowns[activeSlot] = {
                    moves = moves,
                    abilityValue = abilityValue,
                    startTime = g_clock.millis(),
                    inBall = true,
                    completed = (maxRemaining <= 0)
                }

                if maxRemaining <= 0 then
                    setCooldownBarProgress(activeSlot, 0, 1)
                    updateSlotText(activeSlot, totalMoves, totalMoves)
                end

                stopCooldownCycle()
                updateAllCooldownBars()
                startCooldownCycle()
            end
        end
        -- Animate previous active slot shrinking back
        if activeSlot then
            animateSlotShrink(activeSlot)
        end

        activeSlot = nil
        activeBarTracker = nil
    end
end

-- Cooldown Progress Bar System

function stopCooldownCycle()
    if cooldownCycleEvent then
        removeEvent(cooldownCycleEvent)
        cooldownCycleEvent = nil
    end
end

function startCooldownCycle()
    stopCooldownCycle()
    if cooldownCycleEvent then
        return
    end
    updateAllCooldownBars()
    cooldownCycleEvent = cycleEvent(function()
        updateAllCooldownBars()
    end, 1000)
end

function hideCooldownBar(slot)
    if not pokebar then return end
    local pokeBarItem = getSlot(slot)
    if not pokeBarItem then return end
    local cdBar = pokeBarItem:getChildById("cooldownProgress")
    if cdBar then
        setBarClip(cdBar, 1)
    end
    local cdText = pokeBarItem:getChildById("cooldownText")
    if cdText then
        cdText:setText("")
    end
end

function updateAllCooldownBars()
    if not pokebar then
        stopCooldownCycle()
        return
    end

    local anyActive = false

    for slot = 1, maxPokes do
        if activeSlot and activeSlot == slot then
            -- Active slot: always show live movebar data
            updateActiveSlotBar(slot)
            anyActive = true
        else
            local cdData = pokebarCooldowns[slot]
            if not cdData then
                hideCooldownBar(slot)
            elseif cdData.completed then
                -- Already complete, UI already showing 100% + text
            else
                updateInBallSlotBar(slot, cdData)
                if pokebarCooldowns[slot] and not pokebarCooldowns[slot].completed then
                    anyActive = true
                end
            end
        end
    end

    if not anyActive then
        stopCooldownCycle()
    end
end

function onMovebarReceived(data)
    if not activeSlot or not pokebar then return end
    if data.type == 0 then return end

    local maxRemaining, maxTotal, readyMoves, totalMoves = getMoveCooldownStats(data.spells)
    updateSlotText(activeSlot, readyMoves, totalMoves)

    if maxRemaining > 0 then
        activeBarTracker = {
            baseRemaining = maxRemaining,
            maxTotal = maxTotal,
            startTime = g_clock.millis()
        }
        setCooldownBarProgress(activeSlot, maxRemaining, maxTotal)
        startCooldownCycle()
    else
        activeBarTracker = nil
        setCooldownBarProgress(activeSlot, 0, 1)
    end
end

function onMovebarCooldownUpdate(spellword, cooldown)
    if not activeSlot or not pokebar then return end

    -- Use global state from all spells (pokemoves already updated the single spell)
    local moveCooldowns = modules.game_pokemoves.getCurrentMoveCooldowns()
    if not moveCooldowns or #moveCooldowns == 0 then return end

    local maxRemaining, maxTotal, readyMoves, totalMoves = getMoveCooldownStats(moveCooldowns)
    updateSlotText(activeSlot, readyMoves, totalMoves)

    if maxRemaining > 0 then
        activeBarTracker = {
            baseRemaining = maxRemaining,
            maxTotal = maxTotal,
            startTime = g_clock.millis()
        }
        setCooldownBarProgress(activeSlot, maxRemaining, maxTotal)
        startCooldownCycle()
    else
        activeBarTracker = nil
        setCooldownBarProgress(activeSlot, 0, 1)
    end
end

function updateActiveSlotBar(slot)
    -- Update text from live movebar data (pokemoves decrements currentCooldown each second)
    local moveCooldowns = modules.game_pokemoves.getCurrentMoveCooldowns()
    if moveCooldowns and #moveCooldowns > 0 then
        local _, _, readyMoves, totalMoves = getMoveCooldownStats(moveCooldowns)
        updateSlotText(slot, readyMoves, totalMoves)
    end

    if not activeBarTracker then
        setCooldownBarProgress(slot, 0, 1)
        return
    end

    local elapsed = (g_clock.millis() - activeBarTracker.startTime) / 1000
    local effectiveRemaining = activeBarTracker.baseRemaining - elapsed

    if effectiveRemaining > 0 then
        setCooldownBarProgress(slot, effectiveRemaining, activeBarTracker.maxTotal)
    else
        activeBarTracker = nil
        setCooldownBarProgress(slot, 0, 1)
    end
end

function updateInBallSlotBar(slot, cdData)
    local elapsed = (g_clock.millis() - cdData.startTime) / 1000
    local divisor = math.max(1, 10 - (cdData.abilityValue or 0))
    local reduction = elapsed / divisor

    local maxRemaining = 0
    local maxTotal = 0
    local totalMoves = 0
    local readyMoves = 0

    for _, move in ipairs(cdData.moves) do
        totalMoves = totalMoves + 1
        local currentRemaining = math.max(0, move.remaining - reduction)
        if currentRemaining > 0 then
            if currentRemaining > maxRemaining then
                maxRemaining = currentRemaining
                maxTotal = move.total
            end
        else
            readyMoves = readyMoves + 1
        end
    end

    updateSlotText(slot, readyMoves, totalMoves)
    setCooldownBarProgress(slot, maxRemaining, maxTotal)
end

function setCooldownBarProgress(slot, remaining, total)
    if not pokebar then return end
    local pokeBarItem = getSlot(slot)
    if not pokeBarItem then return end
    local cdBar = pokeBarItem:getChildById("cooldownProgress")
    if not cdBar then return end

    if remaining <= 0 then
        setBarClip(cdBar, 100)
        -- Only mark completed for in-ball slots, not the active slot
        if pokebarCooldowns[slot] and slot ~= activeSlot then
            pokebarCooldowns[slot].completed = true
        end
        return
    end

    if total <= 0 then
        return
    end

    local progress = (1 - (remaining / total)) * 100
    progress = math.max(1, math.min(100, progress))
    setBarClip(cdBar, progress)
end
