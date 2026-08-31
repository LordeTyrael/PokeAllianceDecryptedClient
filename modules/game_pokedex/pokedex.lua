DEX_SLOT = 6

local roleIdToName = {
  [1] = "offensive tanker",
  [2] = "burst damage dealer",
}

local roleTable = {
  ["offensive tanker"] = "offensive_tanker",
  ["burst damage dealer"] = "burst_damage"
}

ElementsIndex = {
  ['normal']   = 1,
  ['fire']     = 2,
  ['water']    = 3,
  ['grass']    = 4,
  ['electric'] = 5,
  ['ice']      = 6,
  ['fighting'] = 7,
  ['poison']   = 8,
  ['ground']   = 9,
  ['flying']   = 10,
  ['psychic']  = 11,
  ['bug']      = 12,
  ['rock']     = 13,
  ['ghost']    = 14,
  ['dragon']   = 15,
  ['steel']    = 18,
  ['dark']     = 19,
  ['crystal']  = 20,
  ['fairy']    = 22,
}

Effects = {
  'damage',
  'buff',
  'silence',
  'stun',
  'lifesteal',
  'burn',
  'poison',
  'debuff',
  'blind',
  'healing',
  'paralyze',
  'knockback',
  'slow',
  'confusion',
  'freeze',
  'nevermiss'
}

local STANDARD_TYPES = {
  'normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'poison', 'ground',
  'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy'
}

local TypeColors = {
  normal   = '#a8a29a',
  fire     = '#e25822',
  water    = '#3b82c4',
  grass    = '#57a02f',
  electric = '#d4a017',
  ice      = '#5fb8c9',
  fighting = '#bf5540',
  poison   = '#8e44ad',
  ground   = '#b98e4c',
  flying   = '#7f9fc9',
  psychic  = '#d4608d',
  bug      = '#93a824',
  rock     = '#a48f5a',
  ghost    = '#6f5a9e',
  dragon   = '#6f56c9',
  dark     = '#8c6f5a',
  steel    = '#8a9bb0',
  fairy    = '#d977b8',
  crystal  = '#6fc7bd',
}
local DEFAULT_ACCENT = '#3b82c4'

local EFF_BUCKETS = {
  { key = 'super',            label = 'SUPER EFFECTIVE',    mult = '2x',   color = '#e07a7a' },
  { key = 'effective',        label = 'EFFECTIVE',          mult = '1.5x', color = '#e0a37a' },
  { key = 'neutral',          label = 'NEUTRAL',            mult = '1x',   color = '#8a9099' },
  { key = 'ineffective',      label = 'NOT VERY EFFECTIVE', mult = '0.5x', color = '#7ac08a' },
  { key = 'superIneffective', label = 'SUPER INEFFECTIVE',  mult = '0.4x', color = '#4d9960' },
  { key = 'immune',           label = 'IMMUNE',             mult = '0x',   color = '#a78bda' },
}

local BadgeColors = {
  target  = '#3b82c4',
  aoe     = '#e2952f',
  passive = '#57a02f',
}

local specialCases = {
  rocksmash = "Rock Smash"
}

local p_locationWidgets = {}
-- Guardado para redesenhar quando a CAMERA troca de andar: a seta e a cor do pino sao relativas ao
-- andar que esta sendo olhado, entao o mesmo resultado de busca muda de aparencia.
local p_lastLocations = nil
local p_lastCameraFloor = nil

-- Mascara de zona: bit0 = wildscape, bit1 = primal (vem do servidor em um byte).
--
-- Testada por aritmetica, e nao por band(): este cliente registra `bit32`, NAO `bit`
-- (luainterface.cpp:825 -> luaopen_bit32). O `_G.bit` que aparece no corelib/base64.lua e um
-- fallback dentro de funcao, que nunca chega a ser avaliado aqui. Com 2 bits, modulo dispensa
-- qualquer biblioteca e nao quebra de novo se a lib mudar.
local function hasWildscape(zoneFlags)
  return zoneFlags % 2 == 1
end

local function hasPrimal(zoneFlags)
  return zoneFlags % 4 >= 2
end

-- Zona = COR DA CUPULA da pokebola, e nao um badge no canto. O sufixo compoe com o pino do andar:
-- location_up + _primal = location_up_primal. Sem sufixo (zona comum) a cupula fica vermelha, que e
-- a arte original.
local ZONE_PIN = {
  wildscape = { suffix = '_wildscape', label = 'Wildscape' },
  primal    = { suffix = '_primal',    label = 'Primal' },
}

-- Legenda do fullmap: uma linha por zona, com o pino de exemplo e a caixa de marcar. A chave e o
-- MESMO sufixo que o marcador guarda em widget.zoneSuffix (zona comum = string vazia), entao
-- filtrar e so consultar a tabela -- nao ha um segundo vocabulario de zona para manter em sincronia.
local LEGEND_ROWS = {
  { id = 'rowCommon',    key = '',           label = 'Common',    image = '/images/modules/location' },
  { id = 'rowWildscape', key = '_wildscape', label = 'Wildscape', image = '/images/modules/location_wildscape' },
  { id = 'rowPrimal',    key = '_primal',    label = 'Primal',    image = '/images/modules/location_primal' },
}

-- Sobrevive ao fechar/reabrir o mapa e a uma nova busca: e preferencia do jogador na sessao.
local p_zoneVisible = { [''] = true, ['_wildscape'] = true, ['_primal'] = true }
local p_legend = nil

local PIN_SIZE = 24

-- Seta de andar: caret da FontAwesome na camada de icone do proprio pino, no canto inferior
-- direito (o canto e transparente na arte -- o desenho vai so ate x=218 de 256).
--
-- caret-up / caret-down (f0d8 / f0d7) e nao arrow-up / arrow-down (f062 / f063): o caret e um
-- triangulo cheio e continua legivel no tamanho que sobra aqui, enquanto a seta com haste vira
-- risco.
--
-- PNG e nao '@fa solid 13 f0d8' direto, embora a forma seja exatamente a mesma: o contorno preto
-- e impossivel em runtime, porque a camada de icone desenha UMA textura com UMA cor
-- (addTexturedRect com m_iconColor). Os arquivos sao o proprio glifo do fa-solid-900.ttf
-- rasterizado com a borda ja embutida, no tamanho exato de exibicao (14x9).
--
-- A cor continua ajustavel aqui porque o tint e MULTIPLICATIVO e o arquivo e preto-e-branco:
-- miolo branco * verde = verde, borda preta * qualquer = preta.
--
-- Sem setIconRect: com m_iconRect valido a textura e ESTICADA para dentro do retangulo
-- (uiwidgetbasestyle.cpp:402). Pelo align ela sai 1:1, sem reamostrar e sem borrar.
local FLOOR_ICON = {
  up   = { image = '/images/modules/caret_up',   color = '#22dd55' },
  down = { image = '/images/modules/caret_down', color = '#ff2222' },
}

-- COMO O MARCADOR COMUNICA AS DUAS DIMENSOES, e nenhuma delas custa um widget a mais.
--
-- Sao 9 PNGs = 3 andares x 3 zonas, todos o MESMO desenho, divergindo em duas regioes disjuntas:
--
--   MIOLO  (~2300px) = ANDAR da camera -- verde acima, vermelho abaixo, cinza mesmo andar
--   CUPULA (~10700px) = ZONA -- roxo Primal, verde-agua Wildscape, vermelho original = comum
--
-- Somam-se a isso, no proprio widget: opacidade 0.9 quando nao e o andar da camera, e a seta do
-- FLOOR_ICON na camada de icone (ver a nota la em cima).
--
-- O badge de zona era um widget-FILHO por marcador -- o dobro de widgets no minimapa -- e virou
-- cor no PNG, que custa zero em runtime. A seta ficou na camada de icone e nao assada no PNG
-- porque desenhada la ela nao ficou boa; a fonte resolve isso melhor e ainda deixa cor e tamanho
-- ajustaveis sem regerar asset.

local currentTab = 'info'
local moveMode = 'pve'
local currentRegion = 'Base'
local currentAccent = DEFAULT_ACCENT
local currentDetail = nil
local moveRows = {}

modules.client_hotkeys.registerHotkeyCallback("POKEDEX",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        show()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

local function firstUpper(s)
  if not s or s == '' then return '' end
  return string.upper(utf8.sub(s, 1, 1)) .. utf8.sub(s, 2)
end

local function accentFor(element)
  return TypeColors[element] or DEFAULT_ACCENT
end

local function setElementIcon(widget, elementName)
  local index = ElementsIndex[elementName]
  if not index then
    widget:hide()
    return
  end
  widget:show()
  widget:setImageClip({ x = 0, y = 24 * (index - 1), width = 24, height = 24 })
  widget:setTooltip(tr(firstUpper(elementName)))
end

--- Aplica as caixas marcadas aos marcadores ja existentes. Esconde, nao destroi: os widgets sao
--- caros de recriar e o jogador costuma ligar/desligar as zonas em sequencia.
local function applyZoneFilter()
  for _, widget in ipairs(p_locationWidgets) do
    local visivel = p_zoneVisible[widget.zoneSuffix or ''] ~= false
    -- zoneHidden e lido tambem por UIMinimap:onZoomChange, que senao devolveria o marcador
    -- escondido a vida no proximo zoom.
    widget.zoneHidden = not visivel
    if visivel then widget:show() else widget:hide() end
  end
end

local function destroyLegend()
  if p_legend then
    p_legend:destroy()
    p_legend = nil     -- sem isto, um segundo clean tentaria destruir de novo
  end
end

local SWITCH_ON  = '/images/general_ui/icons/base_slider_selected'
local SWITCH_OFF = '/images/general_ui/icons/base_slider'

--- Posiciona o slider do SwitchBox. Feito aqui, e nao so no @onCheckChange do .otui, porque ao
--- montar a legenda precisamos do visual certo mesmo quando setChecked NAO muda o estado (e ai
--- nao dispara callback nenhum) -- senao a chave nasceria desenhada como desligada estando ligada.
local function setLegendSwitch(check, checked)
  check:setChecked(checked)
  local slider = check:getChildById('sliderButton')
  if slider then
    slider:setMarginLeft(checked and 20 or 2)
  end
  check:setImageSource(checked and SWITCH_ON or SWITCH_OFF)
end

--- Chamado pelo @onCheckChange do PokedexLegendRow (pokedex.otui), no mesmo padrao que o
--- OptionCheckBox usa com client_options.setOption. Precisa ser global: o .otui resolve por
--- modules.game_pokedex.
function onLegendToggle(rowId, checked)
  if not p_legend then return end

  for _, row in ipairs(LEGEND_ROWS) do
    if row.id == rowId then
      -- setChecked com o valor que ja esta la nao redispara: sem recursao.
      setLegendSwitch(p_legend:getChildById(rowId):getChildById('check'), checked)
      p_zoneVisible[row.key] = checked
      applyZoneFilter()
      return
    end
  end
end

local function createLegend(minimap)
  destroyLegend()

  p_legend = g_ui.createWidget('PokedexMapLegend', minimap)
  -- Empilhada sob a legenda de icones, nao sob o painel do tempo: as duas se penduravam no mesmo
  -- ponto e se sobrepunham. Ancorar na de icones tambem acompanha o colapso dela.
  p_legend:addAnchor(AnchorTop, 'fullmapLegendPanel', AnchorBottom)
  p_legend:addAnchor(AnchorLeft, 'fullmapLegendPanel', AnchorLeft)
  p_legend:setMarginTop(8)

  -- A legenda ENGOLE o clique, senao ele sobe para o minimapa e o personagem sai andando:
  -- UIMinimap:onMouseRelease chama player:autoWalk (gamelib), e a legenda e filha dele.
  --
  -- Bloquear no RELEASE nao quebra a chave. Sao dois caminhos independentes: o widget pressionado
  -- e escolhido por POSICAO (uimanager.cpp:156, recursiveGetChildByPos), e o onClick sai do
  -- updatePressedWidget (:283) -- nao desta cadeia. Aqui so paramos a subida, e o painel esta
  -- entre o SwitchBox e o minimapa, entao a chave ja recebeu o evento antes.
  --
  -- Vale para os dois botoes: o direito abriria o menu de marcacao do minimapa, no mesmo handler.
  p_legend.onMouseRelease = function()
    return true
  end

  for _, row in ipairs(LEGEND_ROWS) do
    local widget = p_legend:getChildById(row.id)
    widget:getChildById('pin'):setImageSource(row.image)
    widget:getChildById('name'):setText(tr(row.label))
    setLegendSwitch(widget:getChildById('check'), p_zoneVisible[row.key] ~= false)
  end
end

function cleanLocationWidgets()
  destroyLegend()

  if #p_locationWidgets > 0 then
    local minimap = modules.game_minimap.getMinimapWidget()
    if minimap then
      -- Em LOTE, nunca em laco de removeAlternativeWidget: aquele caminho e O(N^2) e travava o
      -- cliente por segundos ao fechar o mapa. Ver a nota no gamelib.
      minimap:removeAlternativeWidgetsBatch(p_locationWidgets)
    end
    p_locationWidgets = {}
  end
end

function init()
  window = g_ui.displayUI('pokedex')
  pokemonList = window:recursiveGetChildById('pokemonList')
  searchEdit = window:recursiveGetChildById('search')
  capturedLabel = window:getChildById('capturedLabel')

  heroPanel = window:getChildById('heroPanel')
  tabsPanel = window:getChildById('tabsPanel')
  contentPanel = window:getChildById('contentPanel')

  pImage = window:recursiveGetChildById('pImage')
  pBackground = window:recursiveGetChildById('pBackground')
  heroGradient = window:recursiveGetChildById('heroGradient')
  chipsPanel = window:recursiveGetChildById('chipsPanel')
  redButton = window:recursiveGetChildById('redButton')

  infoTab = contentPanel:getChildById('infoTab')
  movesTab = contentPanel:getChildById('movesTab')
  lootTab = contentPanel:getChildById('lootTab')

  infoList = infoTab:recursiveGetChildById('infoList')
  movesList = movesTab:recursiveGetChildById('movesList')
  lootList = lootTab:recursiveGetChildById('lootList')
  catchesTab = contentPanel:getChildById('catchesTab')
  catchesList = catchesTab:recursiveGetChildById('catchesList')

  tabButtons = {
    info = tabsPanel:getChildById('infoTabButton'),
    moves = tabsPanel:getChildById('movesTabButton'),
    loot = tabsPanel:getChildById('lootTabButton'),
    catches = tabsPanel:getChildById('catchesTabButton'),
  }
  moveModeButtons = {
    pve = movesTab:recursiveGetChildById('pveButton'),
    pvp = movesTab:recursiveGetChildById('pvpButton'),
  }
  -- As chaves tem de casar 1:1 com os labels que o servidor manda no grupo de loot
  -- (POKEDEX_LOOT_TIERS em data/modules/pokedex/pokedex.lua): o filtro compara
  -- entry.region == currentRegion.
  regionButtons = {
    Base      = lootTab:recursiveGetChildById('baseButton'),
    Wildscape = lootTab:recursiveGetChildById('wildscapeButton'),
    Primal    = lootTab:recursiveGetChildById('primalButton'),
  }

  g_keyboard.bindKeyPress('Up', function() pokemonList:focusPreviousChild(KeyboardFocusReason) end, window)
  g_keyboard.bindKeyPress('Down', function() pokemonList:focusNextChild(KeyboardFocusReason) end, window)

  connect(g_game, {
    onGameEnd = hide,
    onPokedexList = onPokedexList,
    onPokedexDetail = onPokedexDetail,
    onPokedexLocalization = onPokedexLocalization,
    onPokedexLastCatches = onPokedexLastCatches
  })

  clearDetail()
  updateSegButtons()
  updateMoveHint()
end

function terminate()
  disconnect(g_game, {
    onGameEnd = hide,
    onPokedexList = onPokedexList,
    onPokedexDetail = onPokedexDetail,
    onPokedexLocalization = onPokedexLocalization,
    onPokedexLastCatches = onPokedexLastCatches
  })
  window:destroy()
end

function show()
  if g_game.isOnline() then
    searchEdit:setText('')
    clearDetail()
    local parent = window:getParent()
    window:setPosition({
      x = math.floor((parent:getWidth() - window:getWidth()) / 2),
      y = math.floor((parent:getHeight() - window:getHeight()) / 2),
    })
    window:show()
    window:raise()
    window:focus()
  end
end

function hide()
  window:hide()
end

-- Jump straight to one Pokemon in the dex, from anywhere in the client.
-- Accepts the dex id or the Pokemon name (resolved through g_pokemonCyclopedia, so
-- "Shiny Charizard" and the alternate forms land on their base entry).
-- When the list has not been received yet it asks the server for it (ACTION_REQUEST_LIST)
-- with this Pokemon as the selection, so a cold client works on the first click.
--- Exact lookup: the list the server sent first (it is the authority on the names it
--- uses), then the cyclopedia, whose "Shiny X" aliases come back as "025.1" - the dex
--- page is the base entry either way.
local function lookupExact(name)
  for _, row in ipairs(pokemonList:getChildren()) do
    if row.pokemonName and row.pokemonName:lower() == name then
      return row.pokemonId
    end
  end

  local dexNumber = g_pokemonCyclopedia.getDexNumber(name):match('^%d+')
  return dexNumber and tonumber(dexNumber) or nil
end

--- Forms carry qualifiers the exact lookup cannot see: the cyclopedia registers every
--- "Shiny X" but only a handful of FORM aliases, so Mega Charizard X, Giant Steelix and
--- Alolan Raichu resolve to nothing, and the server's list holds base names only.
--- Rather than keep a list of qualifiers here - the same list that already went stale in
--- pokemon_cyclopedia.cpp - try every run of consecutive words, longest first, and take
--- the first that resolves. "mega charizard x" finds "charizard"; "mewtwo" still wins
--- over "mew" because the longer run is tried first.
local function resolveDexId(pokemonIdOrName)
  local id = tonumber(pokemonIdOrName)
  if id then return math.floor(id) end
  if type(pokemonIdOrName) ~= 'string' then return nil end

  local name = pokemonIdOrName:lower()
  local exact = lookupExact(name)
  if exact then return exact end

  local words = {}
  for word in name:gmatch('%S+') do
    table.insert(words, word)
  end

  for length = #words - 1, 1, -1 do
    for first = 1, #words - length + 1 do
      local candidate = table.concat(words, ' ', first, first + length - 1)
      local found = lookupExact(candidate)
      if found then return found end
    end
  end

  return nil
end

function openFor(pokemonIdOrName)
  if not g_game.isOnline() then return false end

  local pokemonId = resolveDexId(pokemonIdOrName)

  -- Nothing resolved AND no list to check against: the client-side cyclopedia only knows
  -- ~429 species, so a cold client cannot rule the name out. Ask the server, which owns
  -- the full list, and let it resolve the name we were given.
  if not pokemonId and pokemonList:getChildCount() == 0 then
    g_game.sendPokedexListRequest(0, tostring(pokemonIdOrName))
    return true
  end

  if not pokemonId then
    modules.game_textmessage.displayFailureMessage(tr('No PokeDex entry for %s.', tostring(pokemonIdOrName)))
    return false
  end

  local row = pokemonList:getChildById(pokemonId)
  if not row then
    -- No list yet: the server answers with the whole list already selected on this
    -- Pokemon, so onPokedexList finishes the job (show + focus + scroll).
    g_game.sendPokedexListRequest(pokemonId, tostring(pokemonIdOrName))
    return true
  end

  show()

  -- show() clears the search box, and onSearchTextChange unhides the rows through
  -- updateLater: without settling the layout first, ensureChildVisible scrolls to
  -- where the row used to be while it was filtered out.
  local layout = pokemonList:getLayout()
  if layout then layout:update() end

  if pokemonList:getFocusedChild() == row then
    -- show() cleared the detail, and focusChild would not fire onChildFocusChange again
    g_game.sendPokedexRequest(row.pokemonId, row.pokemonName)
  else
    pokemonList:focusChild(row, MouseFocusReason)
  end
  pokemonList:ensureChildVisible(row)
  return true
end

function openDex()
  local player = g_game.getLocalPlayer()
  if not player then return end
  modules.game_interface.startUseWith(player:getInventoryItem(DEX_SLOT))
end

local function showDetailPanels()
  heroPanel:show()
  tabsPanel:show()
  contentPanel:show()
end

function clearDetail()
  currentDetail = nil
  moveRows = {}
  showDetailPanels()
  pImage:setImageSource('/images/pokemons/000')
  pBackground:setImageSource('')
  heroGradient:setImageColor('#ffffff00')
  heroPanel:getChildById('pokeName'):setText('')
  heroPanel:getChildById('pokeId'):setText('')
  chipsPanel:destroyChildren()
  heroPanel:recursiveGetChildById('roleIcon'):setVisible(false)
  heroPanel:recursiveGetChildById('heavyIcon'):setVisible(false)
  heroPanel:recursiveGetChildById('fastIcon'):setVisible(false)
  redButton:setVisible(false)
  heroPanel:getChildById('searchLocalizationButton'):setVisible(false)
  heroPanel:getChildById('worldCountLabel'):setVisible(false)
  catchesList:destroyChildren()
  infoList:getChildById('description'):hide()
  infoList:getChildById('evoRow'):hide()
  infoList:getChildById('abilitiesCard'):hide()
  infoList:getChildById('effCard'):hide()
  movesList:destroyChildren()
  lootList:destroyChildren()
end

function onPokedexList(list, selectedId)
  show()
  parsePokemonList(list, selectedId)
end

function onPokedexDetail(detail)
  local selectedLabel = pokemonList:getFocusedChild()
  if not selectedLabel then return end
  selectedLabel.info = detail
  renderDetail(detail)
  if currentTab == 'catches' then
    requestLastCatches()
  end
end

--- O andar de referencia e o da CAMERA do minimapa -- nao o do jogador.
---
--- Ele manda nas DUAS coisas:
---   * a ancora, porque Minimap::getTileRect (minimap.cpp:206) devolve Rect invalido quando
---     `pos.z != mapCenter.z`: marcador ancorado noutro andar simplesmente nao desenha;
---   * a seta e a cor do pino, porque a leitura e "em relacao ao que estou OLHANDO".
---
--- Usar o andar do jogador quebra os dois: no fullmap a camera CONGELA (updateCameraPosition,
--- minimap.lua:423, so chama setCameraPosition quando `not fullmapView`), entao ela e o jogador
--- divergem assim que ele sobe ou desce.
local function getCameraFloor(minimap)
  local camera = minimap and minimap:getCameraPosition()
  if camera and camera.z then
    return camera.z
  end

  local player = g_game.getLocalPlayer()
  local pos = player and player:getPosition()
  return pos and pos.z or 7
end

--- Estado do marcador que depende do andar da CAMERA. Separado do build porque a troca de andar
--- reaproveita os widgets em vez de recria-los -- so estes tres campos mudam.
---
--- Em Tibia o eixo Z e invertido: z MAIOR = andar mais BAIXO.
local function applyFloorState(widget, loc, cameraZ)
  local z = loc[3]

  local base, floorText
  if z > cameraZ then
    base = '/images/modules/location_down'
    floorText = tr('%d floor(s) below', z - cameraZ)
  elseif z < cameraZ then
    base = '/images/modules/location_up'
    floorText = tr('%d floor(s) above', cameraZ - z)
  else
    base = '/images/modules/location'
    floorText = tr('same floor')
  end
  -- O andar escolhe o arquivo, a zona escolhe a variante dele: as duas dimensoes vivem no mesmo
  -- PNG, entao trocar de andar preserva a cor da cupula sem nenhum trabalho extra.
  widget:setImageSource(base .. (widget.zoneSuffix or ''))

  -- Marcador de OUTRO andar (o de miolo verde ou vermelho) fica levemente apagado, para o andar
  -- que esta sendo olhado saltar. Reaplicado aqui, e nao no build, porque a cada troca de camera
  -- um marcador pode virar "deste andar" e vice-versa.
  widget:setOpacity(z == cameraZ and 1.0 or 0.9)

  local icon = z > cameraZ and FLOOR_ICON.down or (z < cameraZ and FLOOR_ICON.up or nil)
  if icon then
    -- ZERA O CLIP ANTES: setIcon so recalcula m_iconClipRect quando ele esta INVALIDO
    -- (uiwidgetbasestyle.cpp:462). Trocando de andar o mesmo widget troca de glifo, e sem isto
    -- ele herdaria o recorte do glifo anterior.
    widget:setIconClip({ x = 0, y = 0, width = 0, height = 0 })
    widget:setIcon(icon.image)
    widget:setIconColor(icon.color)
    widget:setIconAlign(AlignBottomRight)
  else
    widget:setIcon('')
  end

  -- Ancora no andar da CAMERA, nao no do spawn: getTileRect so devolve retangulo valido quando
  -- pos.z == camera.z (minimap.cpp:206), entao ancorar no z do spawn some com o marcador
  -- justamente quando saber o andar seria mais util.
  widget.pos = { x = loc[1], y = loc[2], z = cameraZ }

  local tooltip = tr('Floor %d', z) .. ' (' .. floorText .. ')'
  if widget.zoneText then
    tooltip = tooltip .. ' - ' .. widget.zoneText
  end
  widget:setTooltip(tooltip)
end

local function buildLocationWidget(loc, cameraZ)
  local zoneFlags = loc[4] or 0

  local widget = g_ui.createWidget('UIWidget')
  widget:setSize({ width = PIN_SIZE, height = PIN_SIZE })
  widget:setPhantom(true)
  widget.maxZoom = -5

  -- Primal antes de Wildscape: se a zona for as duas, o pino mostra a mais especifica.
  local zoneInfo
  if hasPrimal(zoneFlags) then
    zoneInfo = ZONE_PIN.primal
  elseif hasWildscape(zoneFlags) then
    zoneInfo = ZONE_PIN.wildscape
  end

  -- A zona nao muda com o andar da camera: fica guardada aqui para o applyFloorState escolher a
  -- variante certa e remontar o tooltip sem reavaliar as flags.
  widget.zoneSuffix = zoneInfo and zoneInfo.suffix
  widget.zoneText   = zoneInfo and zoneInfo.label
  applyFloorState(widget, loc, cameraZ)

  return widget
end

local function renderLocationWidgets(locations)
  cleanLocationWidgets()

  local minimap = modules.game_minimap.getMinimapWidget()
  if not minimap then return false end

  local cameraZ = getCameraFloor(minimap)

  local widgets = {}
  for _, loc in ipairs(locations) do
    local widget = buildLocationWidget(loc, cameraZ)
    widget.loc = loc                     -- pareamento explicito para o refresh, sem depender do indice
    table.insert(widgets, widget)
    table.insert(p_locationWidgets, widget)
  end

  minimap:addAlternativeWidgetsBatch(widgets)
  -- Depois do batch: os marcadores acabaram de nascer visiveis, e o filtro reaplica o que o
  -- jogador ja tinha desmarcado numa busca anterior.
  applyZoneFilter()
  createLegend(minimap)

  p_lastCameraFloor = cameraZ
  return true
end

--- Reage a CAMERA trocando de andar: muda a ancora (senao o marcador some, porque getTileRect exige
--- pos.z == camera.z) e muda a cor do pino, que e relativa ao andar que esta sendo olhado.
---
--- Chamado a cada movimento de camera -- inclusive lateral --, entao sai fora quando o ANDAR nao
--- mudou; do contrario refaria tudo a cada passo do jogador.
---
--- ATUALIZA NO LUGAR em vez de recriar. Recriar custava um cleanLocationWidgets (destruir N
--- widgets) mais N g_ui.createWidget a cada andar, e era metade do travamento. Aqui so mudam
--- imagem, tooltip e ancora; a zona ja esta no widget.zoneSuffix e so recompoe o nome do arquivo.
---
--- Com o layout congelado: centerInPosition faz dois addPositionAnchor, e cada um chama update()
--- (uimapanchorlayout.cpp:77). Sem congelar seriam 2N resolucoes completas de layout. Repetir
--- centerInPosition no mesmo widget e seguro -- UIAnchorGroup::addAnchor SUBSTITUI ancoras da
--- mesma borda (uianchorlayout.cpp:99), entao nao acumula.
function refreshLocationWidgets()
  if not p_lastLocations or #p_locationWidgets == 0 then
    return
  end

  local minimap = modules.game_minimap.getMinimapWidget()
  if not minimap then
    return
  end

  local cameraZ = getCameraFloor(minimap)
  if cameraZ == p_lastCameraFloor then
    return
  end

  local layout = minimap:getLayout()
  layout:disableUpdates()
  for _, widget in ipairs(p_locationWidgets) do
    applyFloorState(widget, widget.loc, cameraZ)
    minimap:centerInPosition(widget, widget.pos)
  end
  layout:enableUpdates()
  layout:update()

  p_lastCameraFloor = cameraZ
end

function onPokedexLocalization(pokemonId, creatureName, locations)
  local count = locations and #locations or 0
  if count == 0 then return end

  if not modules.game_minimap.getMinimapWidget() then return end

  p_lastLocations = locations

  -- ⚠ ORDEM IMPORTA: showFullMap() antes de criar os marcadores.
  --
  -- addAlternativeWidgetsBatch ja faz insertChild em cada widget, e o showFullMap desemboca em
  -- UIMinimap:setAlternativeWidgetsVisible(true) (uiminimap.lua:215), que faz insertChild de TODOS
  -- os alternatives sem checar se ja sao filhos. Criar antes = "attempt to insert a child again"
  -- por marcador. O refreshLocationWidgets nao tem esse problema: la o mapa ja esta aberto e nada
  -- chama setAlternativeWidgetsVisible depois.
  hide()
  modules.game_minimap.showFullMap()

  renderLocationWidgets(locations)
end


function parsePokemonList(list, id)
  disconnect(pokemonList, { onChildFocusChange = onPokemonChanged })

  pokemonList:destroyChildren()
  local lay = pokemonList:getLayout()
  lay:disableUpdates()

  local caughtCount = 0
  local count = #list
  for i = 1, count do
    local pokemonId = tonumber(list[i][2])
    local pokemonName = firstUpper(list[i][1])
    local pokemonCaught = tonumber(list[i][3]) == 1

    local row = g_ui.createWidget('PokedexListRow', pokemonList)
    row:setId(pokemonId)
    row.pokemonId = pokemonId
    row.pokemonName = pokemonName
    row.caught = pokemonCaught
    row.accent = accentFor(g_pokemonCyclopedia.getPrimaryType(list[i][1]:lower()))
    row.searchText = string.format('#%03d %s', pokemonId, pokemonName):lower()

    row:getChildById('number'):setText(string.format('#%03d', pokemonId))
    local nameLabel = row:getChildById('name')
    nameLabel:setText(pokemonName)

    if pokemonCaught then
      caughtCount = caughtCount + 1
      row:getChildById('ball'):setVisible(true)
      row:getChildById('dot'):setIconColor(row.accent)
    else
      nameLabel:setColor('#8a929e')
    end
  end

  capturedLabel:setText(tr('%d / %d captured', caughtCount, count))

  if id then
    local selected = pokemonList:getChildById(id)
    if selected then
      pokemonList:focusChild(selected, MouseFocusReason)
      clearDetail()
      local ensureVisible
      ensureVisible = function()
        pokemonList:ensureChildVisible(pokemonList:getFocusedChild())
        disconnect(pokemonList, 'onLayoutUpdate', ensureVisible)
      end
      connect(pokemonList, 'onLayoutUpdate', ensureVisible)
    end
  end

  lay:enableUpdates()
  lay:updateLater()

  connect(pokemonList, { onChildFocusChange = onPokemonChanged })
end

function onPokemonChanged(parent, focusedChild, unfocusedChild, reason)
  if not focusedChild then return end

  clearDetail()
  g_game.sendPokedexRequest(focusedChild.pokemonId, focusedChild.pokemonName)
end

function selectTab(tab)
  currentTab = tab
  infoTab:setVisible(tab == 'info')
  movesTab:setVisible(tab == 'moves')
  lootTab:setVisible(tab == 'loot')
  catchesTab:setVisible(tab == 'catches')
  updateSegButtons()
  if tab == 'catches' then
    requestLastCatches()
  end
end

function setMoveMode(mode)
  moveMode = mode
  updateSegButtons()
  updateMoveHint()
  updateMoveCooldowns()
end

function setRegion(region)
  currentRegion = region
  updateSegButtons()
  rebuildLoot()
end

local function styleSegButton(button, active)
  button:setOn(active)
end

function updateSegButtons()
  for name, button in pairs(tabButtons) do
    styleSegButton(button, name == currentTab)
  end
  for name, button in pairs(moveModeButtons) do
    styleSegButton(button, name == moveMode)
  end
  for name, button in pairs(regionButtons) do
    styleSegButton(button, name == currentRegion)
  end
end

function updateMoveHint()
  local hint = movesTab:getChildById('moveHint')
  if moveMode == 'pve' then
    hint:setText(tr('Cooldowns against wild pokemon and bosses'))
  else
    hint:setText(tr('Cooldowns in duels and tournaments'))
  end
end

local function addHeroChip(text, color, elementName)
  local chip = g_ui.createWidget(elementName and 'PokedexTypeChip' or 'PokedexChip', chipsPanel)
  chip:setText(text)
  -- element chips: icon(16)+gap(4) centered with the text via text-offset 10 and icon margin 10
  local extra = elementName and 40 or 24
  chip:setWidth(chip:getTextSize().width + extra)
  chip:setImageColor(color)
  if elementName then
    setElementIcon(chip:getChildById('icon'), elementName)
  end
end

local function addSoftChip(parent, text)
  local chip = g_ui.createWidget('PokedexSoftChip', parent)
  chip:setText(text)
end

local function renderHero(detail)
  local dex = string.format('%03d', detail.id)
  if detail.shinyId and detail.shinyId > 1 then
    pImage:setImageSource('/images/pokemons/' .. dex .. '.' .. detail.shinyId - 1)
  else
    pImage:setImageSource('/images/pokemons/' .. dex)
  end

  local bgPath = '/images/elemental_bg/' .. detail.firstElement .. '.png'
  pBackground:setImageSource(g_resources.fileExists(bgPath) and bgPath or '')
  heroGradient:setImageColor(currentAccent .. '1e')

  heroPanel:getChildById('pokeName'):setText(detail.name)
  heroPanel:getChildById('pokeId'):setText('#' .. detail.id)

  chipsPanel:destroyChildren()
  for _, element in ipairs({ detail.firstElement, detail.secondElement }) do
    if element ~= '' then
      addHeroChip(tr(firstUpper(element)), accentFor(element), element)
    end
  end
  if detail.level > 0 then
    addHeroChip(tr('LEVEL %d', detail.level), '#6b7280')
  end
  if detail.tier ~= '' then
    addHeroChip(tr('TIER %s', detail.tier), '#6b7280')
  end

  local worldCountLabel = heroPanel:getChildById('worldCountLabel')
  worldCountLabel:setText(tostring(detail.worldCount or 0))
  worldCountLabel:setVisible(true)

  local roleIcon = heroPanel:recursiveGetChildById('roleIcon')
  local roleName = roleIdToName[detail.role]
  local rolePath = roleName and roleTable[roleName]
  roleIcon:setVisible(rolePath ~= nil)
  if rolePath then
    roleIcon:setImageSource('/images/pokemon_roles/' .. rolePath)
    roleIcon:setTooltip(tr(roleName))
  end
  heroPanel:recursiveGetChildById('heavyIcon'):setVisible(detail.heavy)
  heroPanel:recursiveGetChildById('fastIcon'):setVisible(detail.fast)

  local hasShiny = #detail.shinyIds > 1 -- shinyIds[1] is the base form
  redButton:setVisible(true)
  redButton:setOpacity(hasShiny and 1 or 0.35)
  heroPanel:getChildById('searchLocalizationButton'):setVisible(true)
end

local function buildEvolutionCards(detail)
  local evoRow = infoList:getChildById('evoRow')
  local hasEvo = #detail.evolutions > 0 or detail.evoNote ~= ''
  if not hasEvo and #detail.stones == 0 then
    evoRow:hide()
    return
  end
  evoRow:show()

  local evoCard = evoRow:recursiveGetChildById('evoCard')
  local evoChain = evoRow:recursiveGetChildById('evoChain')
  local evoNote = evoRow:recursiveGetChildById('evoNote')
  evoChain:destroyChildren()

  -- manual flow layout: branch chains (4+ stages) wrap to extra rows instead of clipping
  local avail = 400 - 32
  local STAGE_W, ARROW_W, GAP, ROW_STEP = 96, 30, 4, 116
  local x, rowIndex = 0, 0
  local function place(widget, w)
    widget:addAnchor(AnchorTop, 'parent', AnchorTop)
    widget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    widget:setMarginTop(rowIndex * ROW_STEP)
    widget:setMarginLeft(x)
    x = x + w + GAP
  end

  local forkShown = false
  for i, evo in ipairs(detail.evolutions) do
    -- every stage after the first occupies a full slot (connector + box) so rows align in columns;
    -- sibling branches get an invisible connector, and wrapping moves the whole slot to the next row
    local needConnector = i > 1
    if x > 0 and x + (needConnector and (ARROW_W + GAP) or 0) + STAGE_W > avail then
      rowIndex = rowIndex + 1
      x = 0
      needConnector = false
    end

    -- the level always lives inside the stage box; arrows are pure connectors (no overflow over the boxes)
    local showLevelOnStage = i > 1 and evo.requiredLevel > 0
    if needConnector then
      local arrowWidget = g_ui.createWidget('PokedexEvoArrow', evoChain)
      if evo.branch and forkShown then
        arrowWidget:getChildById('arrow'):setVisible(false)
      else
        arrowWidget:getChildById('arrow'):setIconColor(currentAccent)
      end
      place(arrowWidget, ARROW_W)
    end
    if evo.branch then
      forkShown = true
    end

    local stage = g_ui.createWidget('PokedexEvoStage', evoChain)
    local dex = g_pokemonCyclopedia.getDexNumber(evo.name:lower())
    if dex == '' then
      dex = string.format('%03d', evo.id)
    end
    stage:getChildById('sprite'):setImageSource('/images/pokemons/' .. dex)
    -- shiny chains prefix every stage with "Shiny " and overflow the card; the sprite/tooltip carry that info
    stage:getChildById('stageName'):setText((evo.name:gsub('^Shiny ', '')))
    stage:setTooltip(evo.name)
    if showLevelOnStage then
      stage:getChildById('stageLv'):setText(tr('Lv %d', evo.requiredLevel))
    end
    if evo.current then
      stage:setImageColor(currentAccent .. '21')
    else
      local evoId, evoName = evo.id, evo.name
      stage.onClick = function()
        -- move the list selection so shiny/localize follow the shown pokemon; shiny forms share the base
        -- form's id and have no own list row, so they must be requested by name instead
        local row = not evoName:find('^Shiny ') and pokemonList:getChildById(evoId) or nil
        if row then
          pokemonList:focusChild(row, MouseFocusReason)
          pokemonList:ensureChildVisible(row)
        else
          g_game.sendPokedexRequest(evoId, evoName)
        end
      end
    end
    place(stage, STAGE_W)
  end

  local chainHeight = rowIndex * ROW_STEP + 110
  evoChain:setHeight(chainHeight)

  local note = detail.evoNote
  evoNote:setVisible(note ~= '')
  evoNote:setText(note)

  local stoneList = evoRow:recursiveGetChildById('stoneList')
  stoneList:destroyChildren()
  if #detail.stones == 0 then
    local none = g_ui.createWidget('PokedexInfoText', stoneList)
    none:setText(tr('None'))
    none:setHeight(20)
  else
    for _, group in ipairs(detail.stones) do
      local groupRow = g_ui.createWidget('PokedexStoneGroupRow', stoneList)
      groupRow:getChildById('evoName'):setText((group.evolution:gsub('^Shiny ', '')))
      local icons = groupRow:getChildById('stoneIcons')
      for _, stone in ipairs(group.stones) do
        local icon = g_ui.createWidget('PokedexStoneIcon', icons)
        icon:setItemId(stone.itemId)
        if stone.count > 1 then
          icon:setItemCount(stone.count)
        end
        icon:setTooltip(stone.count > 1 and string.format('%s (%dx)', stone.name, stone.count) or stone.name)
      end
    end
  end

  -- notes are a single short happiness sentence; fixed height avoids unreliable wrap measuring
  local noteHeight = note ~= '' and 30 or 0
  local stoneSide = 40 -- card title zone + bottom padding
  for _, child in ipairs(stoneList:getChildren()) do
    stoneSide = stoneSide + child:getHeight() + 2
  end
  evoRow:setHeight(math.max(26 + chainHeight + noteHeight + 12, stoneSide))
end

local function buildAbilitiesCard(detail)
  local card = infoList:getChildById('abilitiesCard')
  local chips = card:getChildById('abilityChips')
  chips:destroyChildren()
  if #detail.habilities == 0 then
    card:hide()
    return
  end
  card:show()

  for _, ability in ipairs(detail.habilities) do
    local formatted = specialCases[ability:lower()] or humanCase(ability)
    addSoftChip(chips, formatted)
  end
  local rows = math.ceil(#detail.habilities / 5)
  card:setHeight(30 + rows * 28 + 8)
end

local function buildEffectivenessCard(detail)
  local card = infoList:getChildById('effCard')
  local rowsPanel = card:getChildById('effRows')
  rowsPanel:destroyChildren()

  local bucketed = {}
  local buckets = {}
  for _, def in ipairs(EFF_BUCKETS) do
    if def.key ~= 'neutral' then
      buckets[def.key] = detail.effectiveness[def.key] or {}
      for _, element in ipairs(buckets[def.key]) do
        bucketed[element] = true
      end
    end
  end
  buckets.neutral = {}
  for _, element in ipairs(STANDARD_TYPES) do
    if not bucketed[element] then
      table.insert(buckets.neutral, element)
    end
  end

  local rowCount = 0
  for _, def in ipairs(EFF_BUCKETS) do
    local elements = buckets[def.key]
    if #elements > 0 then
      rowCount = rowCount + 1
      local row = g_ui.createWidget('PokedexEffRow', rowsPanel)
      local nameLabel = row:getChildById('effName')
      nameLabel:setText(tr(def.label))
      nameLabel:setColor(def.color)
      local multLabel = row:getChildById('effMult')
      multLabel:setText(def.mult)
      multLabel:setColor(def.color)
      local icons = row:getChildById('effIcons')
      for _, element in ipairs(elements) do
        local icon = g_ui.createWidget('PokedexElementIcon', icons)
        setElementIcon(icon, element)
      end
    end
  end

  card:setVisible(rowCount > 0)
  card:setHeight(38 + rowCount * 42) -- PokedexEffRow height 40 + 2 spacing
end

local function buildInfoTab(detail)
  local description = infoList:getChildById('description')
  description:setVisible(detail.description ~= '')
  description:setText(detail.description)

  buildEvolutionCards(detail)
  buildAbilitiesCard(detail)
  buildEffectivenessCard(detail)
end

function updateMoveCooldowns()
  for _, row in ipairs(moveRows) do
    if row.passive then
      row.icon:setText('')
    else
      local cooldown = moveMode == 'pve' and row.move.cooldownPve or row.move.cooldownPvp
      row.icon:setText(cooldown > 0 and tostring(cooldown) or '')
    end
  end
end

local function buildMovesTab(detail)
  movesList:destroyChildren()
  moveRows = {}

  for _, move in ipairs(detail.moves) do
    local row = g_ui.createWidget('PokedexMoveRow', movesList)

    local icon = row:getChildById('moveIcon')
    icon:setItemId(move.icon)
    icon:setTooltip(move.desc)

    row:getChildById('moveName'):setText(move.name)

    local primaryTag
    if table.contains(move.tags, 'passive') then
      primaryTag = 'passive'
    elseif table.contains(move.tags, 'aoe') then
      primaryTag = 'aoe'
    elseif table.contains(move.tags, 'target') then
      primaryTag = 'target'
    end

    local badge = row:getChildById('moveBadge')
    if primaryTag then
      local color = BadgeColors[primaryTag]
      badge:setText(tr(primaryTag:upper()))
      badge:setWidth(badge:getTextSize().width + 24)
      badge:setImageColor(color .. '21')
      badge:setColor(color)
    else
      badge:hide()
    end

    local effectsPanel = row:getChildById('moveEffects')
    for _, effect in ipairs(move.effects) do
      local effectId = table.find(Effects, effect)
      if effectId then
        local effectWidget = g_ui.createWidget('PokedexEffectIcon', effectsPanel)
        effectWidget:setImageClip({ x = 24 * (effectId - 1), y = 0, width = 24, height = 24 })
        effectWidget:setTooltip(tr(firstUpper(effect)))
      end
    end

    setElementIcon(row:getChildById('moveElement'), move.element)

    table.insert(moveRows, { icon = icon, move = move, passive = primaryTag == 'passive' })
  end

  updateMoveCooldowns()
end

function rebuildLoot()
  lootList:destroyChildren()
  if not currentDetail then return end

  local drops = {}
  for _, entry in ipairs(currentDetail.loot) do
    if entry.region == currentRegion then
      drops = entry.drops
      break
    end
  end

  if #drops == 0 then
    local none = g_ui.createWidget('PokedexInfoText', lootList)
    none:setText(tr('No drops in this zone type'))
    return
  end

  for _, drop in ipairs(drops) do
    local card = g_ui.createWidget('PokedexLootCard', lootList)
    card:getChildById('item'):setItemId(drop.itemId)
    card:getChildById('name'):setText(drop.name)
    card:getChildById('qty'):setText(tr('Quantity: %d-%d', math.max(drop.countMin, 1), drop.countMax))

    local chanceLabel = card:getChildById('chance')
    local barFill = card:recursiveGetChildById('barFill')
    local pct = drop.chance / 1000
    if pct >= 1 then
      chanceLabel:setText(string.format('%.1f%%', pct))
      chanceLabel:setColor('#e8eaed')
      barFill:setBackgroundColor(currentAccent)
      barFill:setWidth(math.max(3, math.floor(70 * math.min(pct, 100) / 100)))
    else
      chanceLabel:setText(tr('Very Rare'))
      chanceLabel:setColor('#e07a7a')
      barFill:setBackgroundColor('#e07a7a')
      barFill:setWidth(3)
    end
  end
end

function renderDetail(detail)
  currentDetail = detail
  currentAccent = accentFor(detail.firstElement)
  showDetailPanels()

  renderHero(detail)
  buildInfoTab(detail)
  buildMovesTab(detail)
  rebuildLoot()
  updateSegButtons()
  updateMoveHint()

end

function onSearchLocalizationClicked()
  local selectedLabel = pokemonList:getFocusedChild()
  if not selectedLabel then return end
  g_game.sendPokedexSearchLocalization(selectedLabel.pokemonId)
end

function onRedButtonClicked()
  local selectedLabel = pokemonList:getFocusedChild()
  if not selectedLabel then return end

  local info = selectedLabel.info
  if not info or #info.shinyIds <= 1 then return end

  local index = info.shinyId + 1
  if index > #info.shinyIds then
    index = 1
  end

  g_game.sendPokedexShinyRequest(selectedLabel.pokemonId, selectedLabel.pokemonName, info.shinyIds[index])
end

function requestLastCatches()
  if not currentDetail then return end
  g_game.sendPokedexLastCatches(currentDetail.id, currentDetail.name)
end

function onPokedexLastCatches(pokemonId, pokemonName, catches)
  catchesList:destroyChildren()
  if #catches == 0 then
    local none = g_ui.createWidget('PokedexInfoText', catchesList)
    none:setText(tr('No catches recorded yet.'))
    none:setHeight(20)
    return
  end
  for _, entry in ipairs(catches) do
    local catchRow = g_ui.createWidget('PokedexCatchRow', catchesList)
    catchRow:getChildById('playerName'):setText(entry.player)
    catchRow:getChildById('worldChip'):setText(entry.world)
    catchRow:getChildById('catchInfo'):setText(entry.message)
    catchRow:getChildById('date'):setText(entry.time > 0 and os.date('%d/%m/%Y %H:%M', entry.time) or '')
  end
end

function onSearchTextChange()
  local searchText = searchEdit:getText():lower()

  local children = pokemonList:getChildren()
  local lay = pokemonList:getLayout()
  lay:disableUpdates()
  for i = 1, #children do
    local child = children[i]
    child:setVisible(searchText:len() == 0 or string.find(child.searchText, searchText, 1, true) ~= nil)
  end
  lay:enableUpdates()
  lay:updateLater()
end
