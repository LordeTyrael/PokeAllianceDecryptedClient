local GameRankingWindow = nil
local GameRankingColors = {
    [1] = "#f6d001",
    [2] = "#b7b7b7",
    [3] = "#a25020",
}

local function ensureWindow()
    if GameRankingWindow then
        return GameRankingWindow
    end

    GameRankingWindow = g_ui.loadUI('ranking', modules.game_interface.getRootPanel())
    GameRankingWindow:hide()

    local filters = GameRankingWindow:recursiveGetChildById("filterBox")
    if filters then
        filters.onOptionChange = function(self)
            local option = self:getCurrentOption()
            if not option or not option.data then
                return
            end

            local header = GameRankingWindow:recursiveGetChildById('columns')
            if header then
                local title = header:recursiveGetChildById('value')
                if title then
                    title:setText(option.data.label)
                end
            end

            g_game.sendRequestRanking(option.data.id)
        end
    end

    return GameRankingWindow
end

function onGameStart()
    if not g_game.isOnline() then
        return
    end

    ensureWindow()
end

function onGameEnd()
    if GameRankingWindow then
        GameRankingWindow:destroy()
        GameRankingWindow = nil
    end
end

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onRankingData = onRankingData,
    })

    if g_game.isOnline() then
        onGameStart()
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onRankingData = onRankingData,
    })
end

function onRankingData(rankingId, label, hasOptions, options, rows)
    local window = ensureWindow()
    local layout = window:getLayout()
    layout:disableUpdates()

    local header = window:recursiveGetChildById('columns')
    if header then
        local title = header:recursiveGetChildById('value')
        if title then
            title:setText(label)
        end
    end

    if hasOptions then
        local filters = window:recursiveGetChildById("filterBox")
        if filters then
            filters:clearOptions()
            local current
            for _, option in ipairs(options) do
                local optionId, optionLabel = option[1], option[2]
                local data = { id = optionId, label = optionLabel }
                filters:addOption(optionLabel, data, true)
                if optionId == rankingId then
                    current = optionLabel
                end
            end
            if current then
                filters:setCurrentOption(current, true)
            end
        end
    end

    local content = window:getChildById('content')
    if content then
        content:destroyChildren()
        for _, data in ipairs(rows) do
            local rankId, icon, name, level, value = data[1], data[2], data[3], data[4], data[5]
            local row = g_ui.createWidget('RankingRow', content)
            if rankId < 4 then
                if GameRankingColors[rankId] then
                    row:recursiveGetChildById('name'):setColor(GameRankingColors[rankId])
                end
                row:setHeight(50)
                row:setWidth(656)
                row:setMarginTop(4)
                row:setPaddingLeft(4)
                row:setMarginLeft(0)
            end
            row:recursiveGetChildById('rankid'):setText(rankId)
            row:recursiveGetChildById('icon'):setImageSource(string.format("/modules/game_trainer/images/icons/%s", icon))
            row:recursiveGetChildById('name'):setText(name)
            row:recursiveGetChildById('level'):setText(level)
            setAbbreviatedNumber(row:recursiveGetChildById('value'), value)
        end
    end

    layout:enableUpdates()
    layout:update()
    window:show()
end
