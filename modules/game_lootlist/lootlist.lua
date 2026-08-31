local lootList = nil
local defaultWidth
local defaultHeight

--

function hide()
    lootList:hide()
end

function show()
    lootList:show()
end

function reset()
    lootList:destroyChildren()
end

local function reallocateIcons()
    local last = nil
    for k, v in pairs(lootList:getChildren()) do
        v:breakAnchors()

        if last then
            v:addAnchor(AnchorLeft, last:getId(), AnchorRight)
        else
            v:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        end
        last = v
    end
end

local function resize()
    if (lootList:getChildCount() == 0) then
        lootList:resize(defaultWidth, defaultHeight)
        return
    end

    local width = lootList:getPaddingLeft() + lootList:getPaddingRight()
    for k, v in pairs(lootList:getChildren()) do
        width = width + v:getWidth()
    end

    lootList:resize(width, defaultHeight)
end

--

function onLootAdd(itemId, count)
    local icon = g_ui.createWidget('LootItem', lootList)
    icon:setItemId(itemId)

    resize()
    reallocateIcons()

    local label = g_ui.createWidget('CountLabel', icon)
    label:setId(icon:getId() .. 'label')
    label:setText(count)
    label:addAnchor(AnchorRight, 'parent', AnchorRight)
    label:addAnchor(AnchorBottom, 'parent', AnchorBottom)

    local finishFunc = function()
        icon:destroy()
        resize()
        reallocateIcons()
    end
    g_effects.fadeOut(icon, 5000)
    scheduleEvent(finishFunc, 5010)
end

function updateLootList(classic)
    if not lootList then
        return
    end
    local defaultMarginTop = 42
    if not classic then
        defaultMarginTop = 142
    end
    lootList:setMarginTop(defaultMarginTop)
end

function onLootList(protocol, opcode, payload)
    local list = payload
    for index, config in pairs(list) do
        onLootAdd(config.itemId, config.count)
    end
end

function onOnline()
    reset()
    show()
end

function onOffline()
    hide()
    reset()
end

function onInit()
    connect(g_game, {
        onGameStart = onOnline,
        onGameEnd = onOffline
    })

    ProtocolGame.registerExtendedJSONOpcode(94, onLootList)
    lootList = g_ui.loadUI('lootlist', modules.game_interface.getRootPanel())

    defaultWidth = lootList:getWidth()
    defaultHeight = lootList:getHeight()

    if (g_game.isOnline()) then
        onOnline()
    end
end

function onTerminate()
    disconnect(g_game, {
        onGameStart = onOnline,
        onGameEnd = onOffline
    })

    ProtocolGame.unregisterExtendedJSONOpcode(94)
    lootList:destroy()
end