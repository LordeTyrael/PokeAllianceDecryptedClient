local instanceEntryWindow = nil
local instanceContent = nil
local selectedRow = nil
local currentAreaId = nil

-- Opcode do pacote que abre esta janela. Contrato com data/modules/huntInstances/instance_entry.lua
-- no servidor: a ordem de leitura em Proto::GameServerInstanceEntry tem de espelhar a ordem de
-- escrita de la. Nao usar 0x118 (280): ja e' do game_arceusblessings.
local INSTANCE_ENTRY_OPCODE = 1587

-- Icone do marcador de porta no minimapa. A CAVEIRA e so' para area wildscape; area iniciante
-- ganha o broto, para o jogador novo distinguir de longe onde ele consegue cacar.
-- O servidor manda o tipo no catalogo de portas (door.wildscape); o estilo InstanceDoorMarker ja
-- nasce com a caveira, entao so a area iniciante precisa trocar em runtime.
-- Se algum dia o glyph nao renderizar, f005 (estrela) e' um codepoint ja provado no mapflags.lua.
local BEGINNER_ICON  = '@fa blackrounded 14 f4d8' -- fa-seedling
local BEGINNER_COLOR = '#5cd65c'
-- Acao C2S. Tem de bater com INSTANCE_ACTION_ENTER no servidor.
local INSTANCE_ACTION_ENTER = 1

-- Catalogo de portas do mapa, recebido uma vez no login: { {creatureName, position, pokemonId} }
entranceDoors = {}

-- Marcadores das portas no minimapa, no formato { {widget = w} } que a legenda do game_minimap
-- consome (mesmo shape de minimapHouses/minimapDungeons).
local doorMarkers = {}

-- Consumido pelo legendCollection('instances') do game_minimap.
function getDoorMarkers()
    return doorMarkers
end

local function clearDoorMarkers()
    if #doorMarkers == 0 then
        return
    end

    local minimap = modules.game_minimap.getMinimapWidget()
    if minimap then
        local widgets = {}
        for i, marker in ipairs(doorMarkers) do
            widgets[i] = marker.widget
        end
        -- Em lote, nunca em laco de removeAlternativeWidget: aquele caminho e O(N^2) (ver a nota
        -- no gamelib/ui/uiminimap.lua).
        minimap:removeAlternativeWidgetsBatch(widgets)
    end
    doorMarkers = {}
end

function init()
    connect(g_game, {
        onInstanceEntry = onInstanceEntry,
        onEntranceDoors = onEntranceDoors,
        onAutoWalk = hide,
        onGameEnd = onGameEnd
    })

    instanceEntryWindow = g_ui.loadUI('instanceentry', modules.game_interface.getRootPanel())
    instanceEntryWindow:hide()
    instanceContent = instanceEntryWindow.instancePanel.instanceList.instanceContent
end

function terminate()
    disconnect(g_game, {
        onInstanceEntry = onInstanceEntry,
        onEntranceDoors = onEntranceDoors,
        onAutoWalk = hide,
        onGameEnd = onGameEnd
    })

    clearDoorMarkers()
    entranceDoors = {}

    if instanceEntryWindow then
        instanceEntryWindow:destroy()
        instanceEntryWindow = nil
    end
    instanceContent = nil
    selectedRow = nil
    currentAreaId = nil
end

function selectRow(row)
    if selectedRow then
        selectedRow:setChecked(false)
    end
    selectedRow = row
    row:setChecked(true)
end

-- data = { areaId, creature = { name, pokemonId, level }, instances = { { id, name, players } } }
function show(data)
    if not instanceEntryWindow or not data then
        return
    end

    currentAreaId = data.areaId
    selectedRow = nil

    local creaturePanel = instanceEntryWindow.creaturePanel
    local creature = data.creature or {}
    creaturePanel.creatureName:setText(creature.name or '')
    creaturePanel.levelValue:setText(creature.level or 0)

    -- Mesma fonte de imagem da Pokedex (ver renderHero em game_pokedex): numero com tres digitos.
    -- O 000 e' o placeholder de quando o servidor nao resolveu o id.
    creaturePanel.creatureFrame.pokeImage:setImageSource(
        string.format('/images/pokemons/%03d', creature.pokemonId or 0))

    local instances = data.instances or {}
    local layout = instanceContent:getLayout()
    layout:disableUpdates()
    instanceContent:destroyChildren()

    local total = 0
    for _, inst in ipairs(instances) do
        total = total + (inst.players or 0)
        local row = g_ui.createWidget('InstanceRow', instanceContent)
        row.instanceId = inst.id
        row.instanceName:setText(inst.name)
        row.playerCount:setText(inst.players == 1 and tr('1 player') or tr('%d players', inst.players or 0))
        row:setTooltip(string.format('%s - %d %s', inst.name, inst.players or 0, tr('players inside')))
        row.onClick = function(widget) selectRow(widget) end
    end

    layout:enableUpdates()
    layout:update()

    instanceEntryWindow.instancePanel.listCount:setText(tr('%d available', #instances))
    creaturePanel.areaTotal.totalText:setText(tr('%d players in this area', total))

    local first = instanceContent:getFirstChild()
    if first then
        selectRow(first)
    end

    instanceEntryWindow:show()
    instanceEntryWindow:raise()
    instanceEntryWindow:focus()
end

function hide()
    if instanceEntryWindow then
        instanceEntryWindow:hide()
    end
    selectedRow = nil
end

function enterSelected()
    if not selectedRow or not currentAreaId then
        return
    end

    -- Antes isto mandava "/instance <areaId> <instanceId>" por g_game.talk. Nao funcionava por dois
    -- motivos: o talkaction /instance e' de debug e so aceita UM parametro (tonumber("53 30020") da
    -- nil, e ele respondia "You are in instance 0."), e alem disso e' ACCOUNT_TYPE_GOD e nao
    -- materializa nem teleporta. A entrada de verdade vai por pacote, no mesmo opcode da janela.
    local protocol = g_game.getProtocolGame()
    if not protocol then
        return
    end

    -- Byte de acao antes do payload: e' a forma que TODOS os C2S enviados do Lua neste cliente
    -- usam (game_album, game_outfit, game_tournament). Serve para o mesmo opcode comportar mais
    -- de uma acao depois, e mantem este pacote com a mesma estrutura dos que comprovadamente
    -- chegam ao servidor.
    local msg = OutputMessage.create()
    msg:addU16(INSTANCE_ENTRY_OPCODE)
    msg:addU8(INSTANCE_ACTION_ENTER)
    msg:addU16(selectedRow.instanceId or 0)
    protocol:send(msg)

    hide()
end

function onInstanceEntry(data)
    show(data)
end

function onGameEnd()
    hide()
    clearDoorMarkers()
    entranceDoors = {}
end

-- O servidor manda a porta pelo NOME da criatura; o looktype vem da cyclopedia do cliente, que ja
-- indexa por nome em minusculas, entao o nome chega como veio do servidor.
function onEntranceDoors(doors)
    entranceDoors = doors or {}
    clearDoorMarkers()

    local minimap = modules.game_minimap.getMinimapWidget()
    if not minimap then
        return
    end

    local widgets = {}
    for _, door in ipairs(entranceDoors) do
        local lookType = g_pokemonCyclopedia.getLookType(door.creatureName or '')
        if lookType > 0 and door.position then
            door.position.z = 7
            local widget = g_ui.createWidget('InstanceDoorMarker')
            widget:setOutfit({ type = lookType })
            widget.maxZoom = -5
            widget.pos = door.position

            -- door.wildscape vem do servidor. Cliente velho contra servidor novo nunca cai aqui
            -- (o campo chega nil e o marcador fica com a caveira do estilo).
            if door.wildscape == false then
                widget.skull:setIcon(BEGINNER_ICON)
                widget.skull:setIconColor(BEGINNER_COLOR)
            end
            table.insert(widgets, widget)
            table.insert(doorMarkers, { widget = widget })
        end
    end

    minimap:addAlternativeWidgetsBatch(widgets)

    -- Marcadores novos nascem visiveis: reaplica o estado do switch da legenda, senao uma lista
    -- recebida com a camada desligada reapareceria sozinha.
    modules.game_minimap.applyLegendLayer('instances')
end
