local BUILD_CHUNK = 40
local SEARCH_DELAY = 120
local PRELOAD_ROWS = 2

local pokemonWindow = nil
local pokemonsTopButton = nil
local pokemonList = nil

local sortedPokemons = {}
local filteredPokemons = {}
local pokemonWidgets = {}
local spriteLoaded = {}

local pokemonLoaded = false
local drawn = false
local shinyOnly = false
local buildGen = 0
local searchEvent = nil

local function spriteSource(pokemonInfo)
    local source = '/images/pokemons/' .. string.format('%03d', pokemonInfo.id)
    if pokemonInfo.shinyId and pokemonInfo.shinyId > 0 then
        return source .. '.' .. pokemonInfo.shinyId
    end
    return source
end

local function updateVisibleSprites()
    local total = #pokemonWidgets
    if total == 0 then
        return
    end

    local layout = pokemonList:getLayout()
    local columns = layout:getNumColumns()
    local rowPitch = layout:getCellSize().height + layout:getCellSpacing()
    local viewHeight = pokemonList:getPaddingRect().height
    if columns < 1 or rowPitch < 1 or viewHeight < 1 then
        return
    end

    local offsetY = pokemonList:getVirtualOffset().y
    local firstRow = math.max(math.floor(offsetY / rowPitch) - PRELOAD_ROWS, 0)
    local lastRow = math.floor((offsetY + viewHeight) / rowPitch) + PRELOAD_ROWS

    for i = firstRow * columns + 1, math.min((lastRow + 1) * columns, total) do
        if not spriteLoaded[i] then
            spriteLoaded[i] = true
            pokemonWidgets[i].pokemonImage:setImageSourceAsync(spriteSource(filteredPokemons[i]))
        end
    end
end

local function buildChunk(startIndex, gen)
    if gen ~= buildGen then
        return
    end

    local total = #filteredPokemons
    local lastIndex = math.min(startIndex + BUILD_CHUNK - 1, total)
    local layout = pokemonList:getLayout()

    layout:disableUpdates()
    pokemonList:beginBatchAdd()
    for i = startIndex, lastIndex do
        local pokemonInfo = filteredPokemons[i]
        local widget = g_ui.createWidget('PokemonInfoWidget', pokemonList)
        widget.pokemonCount:setText(pokemonInfo.count)
        widget:setTooltip(pokemonInfo.name)
        pokemonWidgets[i] = widget
    end
    pokemonList:endBatchAdd()
    layout:enableUpdates()
    layout:update()

    updateVisibleSprites()

    if lastIndex < total then
        scheduleEvent(function() buildChunk(lastIndex + 1, gen) end, 0)
    else
        drawn = true
    end
end

local function rebuild()
    buildGen = buildGen + 1
    drawn = false
    pokemonWidgets = {}
    spriteLoaded = {}
    pokemonList:destroyChildren()
    pokemonWindow.newVerticalScrollbar:setValue(0)

    local gen = buildGen
    scheduleEvent(function() buildChunk(1, gen) end, 0)
end

local function computeFilter()
    local text = pokemonWindow.bottomBar.searchPokemon:getText():lower()

    filteredPokemons = {}
    for _, pokemonInfo in ipairs(sortedPokemons) do
        local shinyMatch = not shinyOnly or (pokemonInfo.shinyId and pokemonInfo.shinyId > 0)
        if shinyMatch and pokemonInfo.searchName:find(text, 1, true) then
            filteredPokemons[#filteredPokemons + 1] = pokemonInfo
        end
    end
end

local function scheduleFilter()
    removeEvent(searchEvent)
    searchEvent = scheduleEvent(function()
        searchEvent = nil
        computeFilter()
        rebuild()
    end, SEARCH_DELAY)
end

function init()
    connect(g_game, { onGameEnd = onGameEnd, onPokemonsList = onReceivePokemonInfo })
    pokemonsTopButton = modules.client_topmenu.addMiddleGameToggleButton('pokemonsTopButton', tr('Pokemons'), '/images/ui/topbuttons/icons/shinies', toggle)
    pokemonWindow = g_ui.loadUI("pokemons", modules.game_interface.getRootPanel())
    pokemonWindow:hide()

    pokemonList = pokemonWindow.pokemons
    connect(pokemonList, { onScrollChange = updateVisibleSprites })

    pokemonWindow.bottomBar.searchPokemon.onTextChange = scheduleFilter

    pokemonWindow.bottomBar.shinyFilter.onCheckChange = function(widget, checked)
        shinyOnly = checked
        scheduleFilter()
    end
end

function terminate()
    disconnect(g_game, { onGameEnd = onGameEnd, onPokemonsList = onReceivePokemonInfo })
    removeEvent(searchEvent)
    buildGen = buildGen + 1
    g_uistates.remove(pokemonWindow)
    pokemonWindow:destroy()
end

function onGameEnd()
    hide()
    pokemonLoaded = false
    drawn = false
    buildGen = buildGen + 1
end

function onReceivePokemonInfo(list)
    local uniqueByName = {}
    for _, entry in ipairs(list or {}) do
        entry.searchName = entry.name:lower()
        uniqueByName[entry.name] = entry
    end

    sortedPokemons = {}
    for _, entry in pairs(uniqueByName) do
        sortedPokemons[#sortedPokemons + 1] = entry
    end

    table.sort(sortedPokemons, function(a, b)
        if a.id == b.id then
            return a.shinyId < b.shinyId
        end
        return a.id < b.id
    end)

    computeFilter()
    pokemonLoaded = true

    if pokemonWindow:isVisible() then
        rebuild()
    else
        drawn = false
        buildGen = buildGen + 1
    end
end

function toggle()
    if pokemonsTopButton:isOn() then
        hide()
    else
        show()
    end
end

function show()
    if not pokemonLoaded then
        return
    end

    pokemonWindow:show()
    pokemonWindow:focus()
    g_uistates.push(pokemonWindow)
    g_effects.fadeIn(pokemonWindow)
    pokemonsTopButton:setOn(true)

    if not drawn then
        rebuild()
    end
end

function hide()
    g_uistates.remove(pokemonWindow)
    addEvent(function() g_effects.fadeOut(pokemonWindow) end)
    scheduleEvent(function() pokemonWindow:hide() end, g_effects.getFadeOutTime())
    pokemonsTopButton:setOn(false)
end
