-- opcode 195 nas duas direções: S2C nativo (GameServerMarkableSpells), C2S via g_game.sendMarkableSpell
local MouseGrabberWidget = nil
local spellName = nil
local areaMatrix = nil
local areaSize = {width = 0, height = 0}
local hoveredTilePos = nil
local previousWidgets = {}
local rootPanel = nil

function init()
    connect(g_game, { onGameEnd = onGameEnd, onMarkableSpell = parseMarkableSpell })
    connect(modules.game_interface.getMapPanel(), {onMouseMove = moveSpellMark})

    MouseGrabberWidget = g_ui.createWidget('UIWidget')
    MouseGrabberWidget:setVisible(false)
    MouseGrabberWidget:setFocusable(false)
    MouseGrabberWidget.onMouseRelease = onMouseGrabberRelease
    rootPanel = modules.game_interface.getRootPanel()
end

function moveSpellMark(mouseBindWidget, mousePos, mouseMove)
    if not g_ui.isMouseGrabbed() or not areaMatrix then
        return
    end

    clearSpellWidgets()
    local widget = rootPanel:recursiveGetChildByPos(mousePos, false)
    if not widget or widget:getClassName() ~= "UIGameMap" then
        return
    end

    local tile = widget:getTile(mousePos)
    if not tile then
        return
    end

    highlightSpellAreaAt(tile:getPosition())
end

function highlightSpellAreaAt(pos)
    local centerX, centerY
    for y = 1, areaSize.height do
        for x = 1, areaSize.width do
            if areaMatrix[y][x] == 3 then
                centerX = x
                centerY = y
                break
            end
        end
        if centerX then break end
    end

    if not centerX or not centerY then
        return
    end

    for y = 1, areaSize.height do
        for x = 1, areaSize.width do
            if areaMatrix[y][x] > 0 then
                local offsetX = x - centerX
                local offsetY = y - centerY

                local tilePos = {
                    x = pos.x + offsetX,
                    y = pos.y + offsetY,
                    z = pos.z
                }

                local tile = g_map.getTile(tilePos)
                if tile then
                    applySpellMarkTile(tile)
                end
            end
        end
    end
end

function terminate()
    disconnect(g_game, { onGameEnd = onGameEnd, onMarkableSpell = parseMarkableSpell })

    local mapPanel = modules.game_interface and modules.game_interface.getMapPanel()
    if mapPanel then
        disconnect(mapPanel, { onMouseMove = moveSpellMark })
    end

    clearSpellWidgets()

    if MouseGrabberWidget then
        MouseGrabberWidget:destroy()
        MouseGrabberWidget = nil
    end
    rootPanel = nil
    areaMatrix = nil
    spellName = nil
end

function parseMarkableSpell(spell)
    spellName = spell.spellName
    areaSize.width = spell.width
    areaSize.height = spell.height
    areaMatrix = spell.area

    grabMouseForSpell()
end

function createSpellMarkWidget()
    local widget = g_ui.createWidget("UIWidget")
    widget:setSize({ width = 32, height = 32 })
    widget:setBorderWidth(2)
    widget:setFocusable(false)
    widget:setPhantom(true)
    return widget
end

function applySpellMarkTile(tile)
    local widget = createSpellMarkWidget()
    if tile:isWalkable(true) then
        widget:setImageColor({ r = 0, g = 128, b = 0, a = 100 })       -- verde translúcido
        widget:setBackgroundColor({ r = 0, g = 128, b = 0, a = 100 })  -- fundo verde
        widget:setBorderColor("green")
    else
        widget:setImageColor({ r = 255, g = 0, b = 0, a = 100 })
        widget:setBackgroundColor({ r = 255, g = 0, b = 0, a = 100 })
        widget:setBorderColor("red")
    end

    tile:setWidget(widget)
    table.insert(previousWidgets, { tile = tile, widget = widget })
end

function grabMouseForSpell()
    if g_ui.isMouseGrabbed() then
        g_mouse.popCursor("target")
        MouseGrabberWidget:ungrabMouse()
        MouseGrabberWidget:setVisible(false)
    end

    g_mouse.pushCursor("target")
    MouseGrabberWidget:grabMouse()
    MouseGrabberWidget:setVisible(true)
end

function onMouseGrabberRelease(self, mousePosition, mouseButton)
    if mouseButton == MouseTouch then return end
    if spellName == nil then return false end

    if mouseButton == MouseLeftButton then
        local tilePos = nil
        local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
        if clickedWidget and clickedWidget:getClassName() == "UIGameMap" then
            local tile = clickedWidget:getTile(mousePosition)
            if tile then
                tilePos = tile:getPosition()
            end
        end

        if tilePos then
            -- opcode 195 (mesmo número do S2C). O campo `type = "sendSpell"` do JSON antigo era morto:
            -- o servidor nunca o leu.
            g_game.sendMarkableSpell(spellName, tilePos)
        end
    end

    spellName = nil
    areaMatrix = nil
    g_mouse.popCursor("target")
    self:ungrabMouse()
    self:setVisible(false)
    hoveredTilePos = nil
    clearSpellWidgets()
    return true
end

function clearSpellWidgets()
    for _, entry in pairs(previousWidgets) do
        if entry.tile and entry.widget then
            entry.tile:removeWidget(entry.widget)
            entry.widget:destroy()
        end
    end
    previousWidgets = {}
end
