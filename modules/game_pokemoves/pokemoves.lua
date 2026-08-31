local GamePokemovesOpcode = 92
local GamePokemovesWindow = nil
local GamePokemonConditionBar = nil
local conditionBarOrientation = nil
local defaultHeight = 42
local defaultWidth = 36
local pokemonMoves = {}
local originalMoves = {}
local MouseGrabberWidget = nil
local pokemonTableInfo = {}
local pokemonName = ""
local previousPokemonName = nil
local hotkeyDelay = 200
local hotkeyDelayTo = 0
local movebarSettings = nil

local boundKeys = {
  chatEnabled = {},
  chatDisabled = {}
}

local boundKeysUI = {
  chatEnabled = {},
  chatDisabled = {}
}

local pokemonOffensiveBindings = {
  ['OFFENSIVE_MODE'] = FightOffensive,
  ['BALANCED_MODE'] = FightBalanced,
  ['DEFENSIVE_MODE'] = FightDefensive
}

local HotkeyRegistry = modules.client_hotkeys.HotkeyRegistry

local function pokemonFactory(actionName, action, keyInfo, chatState, keyType)
  local fightMode = pokemonOffensiveBindings[actionName]
  if fightMode then
    local callback = function()
      if isChatStateCorrect(chatState == "chatEnabled") then
        g_game.setFightMode(fightMode)
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end

  local callback = function()
    if isChatStateCorrect(chatState == "chatEnabled") then
      if hotkeyDelayTo ~= nil and g_clock.millis() < hotkeyDelayTo then
        return
      end
      hotkeyDelayTo = g_clock.millis() + hotkeyDelay
      local number = tonumber(actionName:match("%d+"))
      sendCastMove("m" .. number)
    end
  end
  return { callback = callback, widget = modules.game_interface.getRootPanel() }
end

local function pokemonAssign(actionName, action, keyInfo, chatState, keyType, event)
  if not modules.game_chat then return end
  local cs = modules.game_chat.isActive() and "chatEnabled" or "chatDisabled"
  updateUI(cs)
end

do
  local pokemonActions = { "OFFENSIVE_MODE", "BALANCED_MODE", "DEFENSIVE_MODE" }
  for i = 1, 12 do
    pokemonActions[#pokemonActions + 1] = "ACTION_" .. i
  end
  for _, actionName in ipairs(pokemonActions) do
    modules.client_hotkeys.registerHotkeyCallback(actionName, pokemonFactory, pokemonAssign)
  end
end

function onGameStart()
    removePokemoves()
    g_ui.loadUI('pokemoves')
    GamePokemovesWindow = g_ui.createWidget('PokemovesWindow')
    MouseGrabberWidget = g_ui.createWidget('UIWidget')
    MouseGrabberWidget:setVisible(false)
    MouseGrabberWidget:setFocusable(false)
    MouseGrabberWidget.onMouseRelease = onDropMovebarButton
    GamePokemovesWindow:setParent(modules.game_interface.getRootPanel())
    GamePokemonConditionBar = g_ui.createWidget('PokemonConditionBar', modules.game_interface.getRootPanel())
    connect(GamePokemovesWindow, {
        onGeometryChange = updateConditionBarPosition,
        onVisibilityChange = onPokemovesVisibilityChange,
    })
    connect(GamePokemonConditionBar, {
        onGeometryChange = updateConditionBarPosition,
    })
    loadPosition()
    GamePokemovesWindow:hide()
    GamePokemovesWindow.onDragLeave = function(widget)
        setBarPosition({
            x = GamePokemovesWindow:getX(),
            y = GamePokemovesWindow:getY()
        })
        return true
    end
    local pokemonInfo = g_settings.get("pokemonMovesTable", "")
    if pokemonInfo:len() > 0 then
        pokemonTableInfo = json.decode(pokemonInfo)
    end

    g_mouse.bindPress(GamePokemovesWindow, function()
        createMenu()
    end, MouseRightButton)
end

function onGameEnd()
    removePokemoves()

    if GamePokemovesWindow then
        if not GamePokemovesWindow:isDestroyed() then
            disconnect(GamePokemovesWindow, {
                onGeometryChange = updateConditionBarPosition,
                onVisibilityChange = onPokemovesVisibilityChange,
            })
            GamePokemovesWindow:destroy()
        end
        GamePokemovesWindow = nil
    end

    if GamePokemonConditionBar then
        if not GamePokemonConditionBar:isDestroyed() then
            GamePokemonConditionBar:destroy()
        end
        GamePokemonConditionBar = nil
    end
    conditionBarOrientation = nil

    if MouseGrabberWidget then
        MouseGrabberWidget:destroy()
    end
    pokemonName = ""
    previousPokemonName = nil
end

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onMovebarReceived = onMovebarReceived,
        onMovebarCooldownUpdate = onMovebarCooldownUpdate
    })
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onMovebarReceived = onMovebarReceived,
        onMovebarCooldownUpdate = onMovebarCooldownUpdate
    })
end

-- Quem manda no ciclo de vida do menu e o UIPopupMenu: ele se destroi sozinho ao escolher uma
-- opcao, clicar fora ou apertar Escape, e o display() ja mata o menu anterior. Guardar a referencia
-- aqui so criava um ponteiro pendurado para um widget ja morto, redestruido no onGameEnd
-- ("attempt to destroy widget two times"). setGameMenu(true) entrega o fechamento no logout ao
-- proprio corelib (uipopupmenu.lua:115).
function createMenu()
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    local current = getBarOrientation()
    menu:addOption(tr(current == 'H' and 'Set Vertical' or 'Set Horizontal'), function()
        toggle()
    end)
    menu:addOption(tr("Open Auto Combo"), function()
        if modules.game_autocombo then
            modules.game_autocombo.showMainWindow()
        end
    end)
    menu:addOption(tr("Reset Pokémon moves to Default."), function()
        resetPokemonMoves()
    end)
    menu:display()
end

function isChatStateCorrect(chatEnabled)
  local chatModeEnabled = not modules.game_chat.consoleToggleChat
  return (chatEnabled and chatModeEnabled) or (not chatEnabled and not chatModeEnabled)
end

function toggle()
    local current = getBarOrientation()
    local new = current and current == 'H' and 'V' or 'H'
    setBarOrientation(new)
    loadByOrientation()
end

function loadByOrientation()
    if not GamePokemovesWindow then
        return
    end

    local layout = GamePokemovesWindow.spellWindow:getLayout()
    layout:disableUpdates()

    local j = GamePokemovesWindow.spellWindow:getChildCount()
    local orientation = getBarOrientation()
    local maxSize = (32 * (j)) + (3 * (j - 1)) + 10
    if orientation == 'H' then
        layout:setNumColumns(j)
        layout:setNumLines(1)
        
        GamePokemovesWindow:setWidth(maxSize)
        GamePokemovesWindow:setHeight(defaultHeight)
    else
        layout:setNumColumns(1)
        layout:setNumLines(j)
        GamePokemovesWindow:setHeight(maxSize)
        GamePokemovesWindow:setWidth(defaultHeight)
    end
    loadPosition()
    layout:enableUpdates()
    layout:update()
    updateConditionBarPosition()
end

local function moveIdentitySnapshot(moves)
    local snap = {}
    for i, m in ipairs(moves) do
        snap[i] = { name = m.name, spellword = m.spellword, icon = m.icon, cooldown = m.cooldown }
    end
    return snap
end

function onMovebarReceived(data)
    if data.type == 0 then
        removePokemoves()
        if GamePokemovesWindow then
            if GamePokemovesWindow:isVisible() then
                GamePokemovesWindow:hide()
            end
        end
        return
    end

    if data.type == 1 then
        local incoming = {}
        for _, spell in ipairs(data.spells) do
            table.insert(incoming, {
                name = spell.name,
                spellword = spell.spellword,
                icon = spell.icon,
                currentCooldown = spell.currentCooldown,
                cooldown = spell.cooldown
            })
        end

        if pokemonTableInfo[data.pokemonName] then
            local savedOrder = pokemonTableInfo[data.pokemonName]
            local reorderedMoves = {}
            local matched = {}

            for _, savedMove in ipairs(savedOrder) do
                for idx, move in ipairs(incoming) do
                    if not matched[idx] and move.spellword == savedMove.spellword and move.name == savedMove.name then
                        table.insert(reorderedMoves, move)
                        matched[idx] = true
                        break
                    end
                end
            end

            -- Append any moves that weren't in the saved order (new/changed moveset)
            for idx, move in ipairs(incoming) do
                if not matched[idx] then
                    table.insert(reorderedMoves, move)
                end
            end

            -- Only apply reorder if at least one move matched; otherwise keep original order
            if #reorderedMoves == #incoming then
                incoming = reorderedMoves
            end
        end

        if data.pokemonName == previousPokemonName and table.equal(moveIdentitySnapshot(pokemonMoves), moveIdentitySnapshot(incoming)) then
            pokemonName = data.pokemonName
            for _, m in ipairs(incoming) do
                onMovebarCooldownUpdate(m.spellword, m.currentCooldown)
            end
            return
        end

        pokemonName = data.pokemonName
        previousPokemonName = data.pokemonName
        removePokemoves()
        pokemonMoves = incoming
        originalMoves = table.copy(pokemonMoves)
    end

    drawPokeMoves()
end

function onMovebarCooldownUpdate(spellword, cooldown)
    if not GamePokemovesWindow or not GamePokemovesWindow.spellWindow then return end

    for i, moveInfo in ipairs(pokemonMoves) do
        if moveInfo.spellword == spellword then
            moveInfo.currentCooldown = cooldown
            local spellWidget = GamePokemovesWindow.spellWindow:getChildById("ACTION_" .. i)
            if spellWidget then
                if cooldown > 0 then
                    if not spellWidget.cooldownEvent then
                        startCooldown(spellWidget)
                    else
                        spellWidget.spellInfo.currentCooldown = cooldown
                        local progress = spellWidget:recursiveGetChildById("progress")
                        if progress then
                            progress:setText(cooldown)
                            progress:setPercent(100 - (cooldown * 100 / moveInfo.cooldown))
                            if not progress:isVisible() then progress:show() end
                        end
                    end
                else
                    if spellWidget.cooldownEvent then
                        removeEvent(spellWidget.cooldownEvent)
                        spellWidget.cooldownEvent = nil
                    end
                    local progress = spellWidget:recursiveGetChildById("progress")
                    if progress then
                        progress:setText("")
                        progress:hide()
                    end
                end
            end
            break
        end
    end
end

function updateUI(chatState)
    if not GamePokemovesWindow or not GamePokemovesWindow.spellWindow then
        return
    end
    local registryKeys = HotkeyRegistry:getBoundKeys("pokemonProfile")
    for actionName, chatStateKeys in pairs(registryKeys) do
        local widget = GamePokemovesWindow.spellWindow:getChildById(actionName)
        if widget and widget.spellInfo.spellword ~= "passive" then
            local keys = chatStateKeys[chatState]
            if keys and keys.primaryKey then
                widget.moveNumber:setText(keys.primaryKey.keyInfo.key)
            else
                widget.moveNumber:setText("")
            end
        end
    end
end

function drawPokeMoves()
    if GamePokemovesWindow then
        local layout = GamePokemovesWindow.spellWindow:getLayout()
        layout:disableUpdates()
        GamePokemovesWindow.spellWindow:destroyChildren()
        GamePokemovesWindow:hide()
        local j = 0
        for i, spellInfo in ipairs(pokemonMoves) do
            local spellWidget = g_ui.createWidget("PokemoveItem", GamePokemovesWindow.spellWindow)
            spellWidget:setId("ACTION_"..i)
            spellWidget.moveNumber:setText("")
            
            spellWidget.spellInfo = spellInfo
            

            local spellIcon = spellWidget:recursiveGetChildById("icon")
            if spellIcon then
                local icon = 9047
                if spellInfo.icon then
                    icon = spellInfo.icon
                end
                spellIcon:setItemId(icon)
                spellIcon.spellIcon = spellInfo.icon
                spellIcon.spellword = spellInfo.spellword
                spellIcon:setTooltip(spellInfo.name)
                if spellInfo.spellword ~= "passive" then
                    spellIcon.onClick = function()
                        g_game.talk(spellInfo.spellword)
                    end
                end
            end

            local spellCooldown = spellWidget:recursiveGetChildById("progress")
            if spellInfo.spellword ~= "passive" then
                spellCooldown.onClick = function()
                    g_game.talk(spellInfo.spellword)
                end
            end

            if spellIcon.spellword ~= "passive" then
                spellIcon.onDragEnter = function(self)
                    local lockWidget = GamePokemovesWindow.spellWindow:getChildById('lockButton')
                    if lockWidget and lockWidget:isOn() then return end
                    if g_ui.isMouseGrabbed() then return end
                    MouseGrabberWidget:grabMouse()
                    g_mouse.pushCursor('target')
                    self:setBorderColor('#FFFFFF')
                    movebarSettings = { id = spellIcon:getId(), widget = spellIcon }
                end
            end

            if spellInfo.currentCooldown > 0 then
                startCooldown(spellWidget)
            else
                spellCooldown:hide()
            end

            j = j + 1
        end
        
        local lockWidget = g_ui.createWidget("LockButton", GamePokemovesWindow.spellWindow)
        lockWidget:setId("lockButton")
        local locked = g_settings.get('cdBar_locked', "false")
        if locked == "true" then
            GamePokemovesWindow:setDraggable(false)
            lockWidget:setOn(true)
            lockWidget:setImageSource("images/locked")
        else
            GamePokemovesWindow:setDraggable(true)
            lockWidget:setOn(false)
            lockWidget:setImageSource("images/unlocked")
        end

        local chatState = modules.game_chat.isActive() and "chatEnabled" or "chatDisabled"
        updateUI(chatState)

        layout:enableUpdates()
        layout:update()

        if not GamePokemovesWindow:isVisible() then
            loadByOrientation()
            GamePokemovesWindow:show()
        end
        return
    end
end

function loadPosition()
    if not GamePokemovesWindow then
        return
    end

    GamePokemovesWindow:move(getBarPositionX(), getBarPositionY())
end

function updateCooldown(spellWidget, start)
    if not spellWidget then
        return
    end

    local progress = spellWidget:recursiveGetChildById("progress")
    if not progress then
        return
    end

    if not progress:isVisible() then
        progress:show()
    end

    local spellInfo = spellWidget.spellInfo
    if spellInfo.currentCooldown - 1 <= 0 then
        spellInfo.currentCooldown = 0
        removeEvent(spellWidget.cooldownEvent)
        spellWidget.cooldownEvent = nil
        progress:setText("")
        progress:hide()
        return
    end

    if progress then
        if not start then
            spellWidget.spellInfo.currentCooldown = spellWidget.spellInfo.currentCooldown - 1
        end
        progress:setText(spellWidget.spellInfo.currentCooldown)
        progress:setPercent(100 - (spellWidget.spellInfo.currentCooldown * 100 / spellWidget.spellInfo.cooldown))
    end
end

function startCooldown(spellWidget)
    updateCooldown(spellWidget, true)
    spellWidget.cooldownEvent = cycleEvent(function()
        updateCooldown(spellWidget)
    end, 1000)
end

function removePokemoves()
    if GamePokemovesWindow and GamePokemovesWindow.spellWindow then
        if GamePokemovesWindow.spellWindow:getChildCount() > 0 then
            for i = 1, GamePokemovesWindow.spellWindow:getChildCount() do
                local spellWidget = GamePokemovesWindow.spellWindow:getChildByIndex(i)
                if spellWidget.cooldownEvent then
                    removeEvent(spellWidget.cooldownEvent)
                end
            end
        end
    end
    pokemonMoves = {}
end

function getBarOrientation()
    return g_settings.get('cdBar_dir', 'H')
end

function setBarOrientation(value)
    g_settings.set('cdBar_dir', value)
    g_settings.save()
end

function getBarPositionX()
    return g_settings.getNumber('cdBar_x', 250)
end

function getBarPositionY()
    return g_settings.getNumber('cdBar_y', 50)
end

function setBarPosition(pos)
    g_settings.set('cdBar_x', pos.x)
    g_settings.set('cdBar_y', pos.y)
    g_settings.save()
end

function getCurrentMoveCooldowns()
    return pokemonMoves
end

function lockMovebar()
    local pokeMovesLock = GamePokemovesWindow.spellWindow.lockButton
    if pokeMovesLock then
        if GamePokemovesWindow:isDraggable() then
            pokeMovesLock:setOn(true)
            GamePokemovesWindow:setDraggable(false)
            g_settings.set('cdBar_locked', "true")
            g_settings.save()
            pokeMovesLock:setImageSource("images/locked")
        else
            GamePokemovesWindow:setDraggable(true)
            pokeMovesLock:setOn(false)
            g_settings.set('cdBar_locked', "false")
            g_settings.save()
            pokeMovesLock:setImageSource("images/unlocked")
        end
    end
end

function onDropMovebarButton(self, mousePosition, mouseButton)
    if not g_ui.isMouseGrabbed() then return end
    g_mouse.popCursor('target')
    MouseGrabberWidget:ungrabMouse()

    if not movebarSettings then
        return
    end

    local widget = movebarSettings.widget
    local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
    if clickedWidget and clickedWidget:getParent() and clickedWidget:getParent():getParent() and clickedWidget:getParent():getParent():getStyleName():find('PokemoveItem') then
        local spellword = clickedWidget.spellword
        if spellword and spellword == "passive" then
            return
        end
        local sourceId = tonumber(widget:getParent():getParent():getId():match("ACTION_(%d+)"))
        local targetId = tonumber(clickedWidget:getParent():getParent():getId():match("ACTION_(%d+)"))

        if sourceId and targetId and sourceId ~= targetId then
            pokemonMoves[sourceId], pokemonMoves[targetId] = pokemonMoves[targetId], pokemonMoves[sourceId]
            drawPokeMoves()

            local newMoveOrder = {}
            for _, move in ipairs(pokemonMoves) do
                table.insert(newMoveOrder, move)
            end
            pokemonTableInfo[pokemonName] = newMoveOrder
            g_settings.set('pokemonMovesTable', json.encode(pokemonTableInfo))
            g_settings.save()
            local actionSource = "ACTION_" .. sourceId
            local actionTarget = "ACTION_" .. targetId
            local chatState = modules.game_chat.isActive() and "chatEnabled" or "chatDisabled"
            updateUI(chatState)
            
            -- Notifica o autocombo sobre a reordena
            if modules.game_autocombo then
                modules.game_autocombo.onMovesReordered()
            end
        end
    end

    movebarSettings = nil
end

function sendCastMove(move)
    local cleanedMove = tonumber(move:sub(2))
    if not cleanedMove then
        return
    end
    local config = pokemonMoves[cleanedMove]
    if not config then
        return
    end

    if config.spellword == "passive" then
        return
    end

    g_game.talk(config.spellword)
end

function sendAutoCombo(message)
  -- Se for apenas !autocombo, pegar combo configurado e enviar
  if message == "!autocombo" then
    local comboSpellwords = modules.game_autocombo.getComboSpellwords()
    if not comboSpellwords or #comboSpellwords == 0 then
      return
    end

    if autoComboEvent then
        removeEvent(autoComboEvent)
        autoComboEvent = nil
    end
    
    local combinedMessage = table.concat(comboSpellwords, ", ")
    g_game.setFightMode(1)
    g_game.talk("!autocombo " .. combinedMessage)
    --autoComboEvent = scheduleEvent(function()
    --    g_game.setFightMode(3)
    --end, (#comboSpellwords * 250) + 2000)
    return
  end
  
  local moveList = string.gsub(message, "!autocombo ", "")
  local moves = {}
  
  for move in string.gmatch(moveList, "([^,]+)") do
    move = move:match("^%s*(.-)%s*$")
    table.insert(moves, move)
  end

  local spellwords = {}
  for _, move in ipairs(moves) do
    local cleanedMove = tonumber(move:sub(2))
    if cleanedMove and pokemonMoves[cleanedMove] then
      table.insert(spellwords, pokemonMoves[cleanedMove].spellword)
    end
  end

  local combinedMessage = table.concat(spellwords, ", ")
  g_game.talk("!autocombo "..combinedMessage)
end


function resetPokemonMoves()
    if not pokemonTableInfo[pokemonName] then
        return
    end

    pokemonTableInfo[pokemonName] = nil
    pokemonMoves = table.copy(originalMoves)
    drawPokeMoves()
    g_settings.set('pokemonMovesTable', json.encode(pokemonTableInfo))
    g_settings.save()
end

function getPokemonMoves()
    return pokemonMoves
end

function getPokemonName()
    return pokemonName
end

function getPokemonConditionBar()
    return GamePokemonConditionBar
end

local CONDITION_BAR_GAP = 4
local CONDITION_BAR_THICKNESS = 32

function onPokemovesVisibilityChange(widget, visible)
    if not GamePokemonConditionBar or GamePokemonConditionBar:isDestroyed() then
        return
    end
    if visible then
        GamePokemonConditionBar:show()
    else
        GamePokemonConditionBar:destroyChildren()
        GamePokemonConditionBar:hide()
    end
end

function getConditionBarCorner()
    return g_settings.getNumber('condBar_corner', 0)  -- 0 Auto, 1 LT, 2 RT, 3 BL, 4 BR
end

function getConditionBarOrientMode()
    local v = g_settings.getNumber('condBar_orient', 1) -- 1 Auto, 2 Vertical, 3 Horizontal
    if v == 2 then return 'V' end
    if v == 3 then return 'H' end
    return 'A'
end

function setConditionBarPosition(index)
    g_settings.set('condBar_corner', (index or 1) - 1)
    g_settings.save()
    updateConditionBarPosition()
end

function setConditionBarOrientation(index)
    g_settings.set('condBar_orient', index or 1)
    g_settings.save()
    conditionBarOrientation = nil
    updateConditionBarPosition()
end

function updateConditionBarPosition()
    if not GamePokemovesWindow or not GamePokemonConditionBar then
        return
    end
    if GamePokemovesWindow:isDestroyed() or GamePokemonConditionBar:isDestroyed() then
        return
    end

    local orientMode = getConditionBarOrientMode()
    local orientation = (orientMode == 'A') and getBarOrientation() or orientMode
    local corner = getConditionBarCorner()

    if conditionBarOrientation ~= orientation then
        conditionBarOrientation = orientation
        local layout
        if orientation == 'H' then
            layout = UIHorizontalLayout.create(GamePokemonConditionBar)
        else
            layout = UIVerticalLayout.create(GamePokemonConditionBar)
        end
        layout:setSpacing(2)
        layout:setFitChildren(true)
        GamePokemonConditionBar:setLayout(layout)
    end

    local x, y = GamePokemovesWindow:getX(), GamePokemovesWindow:getY()
    local w, h = GamePokemovesWindow:getWidth(), GamePokemovesWindow:getHeight()
    local bw = GamePokemonConditionBar:getWidth()
    local gap = CONDITION_BAR_GAP

    local nx, ny
    if corner == 1 then            -- Left-Top
        nx, ny = x - bw - gap, y
    elseif corner == 2 then        -- Right-Top
        nx, ny = x + w + gap, y
    elseif corner == 3 then        -- Bottom-Left
        nx, ny = x, y + h + gap
    elseif corner == 4 then        -- Bottom-Right
        nx, ny = x + w - bw, y + h + gap
    elseif orientation == 'H' then -- Auto: horizontal movebar -> below
        nx, ny = x, y + h + gap
    else                           -- Auto: vertical movebar -> right
        nx, ny = x + w + gap, y
    end

    GamePokemonConditionBar:breakAnchors()
    GamePokemonConditionBar:setPosition({ x = nx, y = ny })
end