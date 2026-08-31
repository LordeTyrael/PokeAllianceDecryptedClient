-- Hunt Finder — cliente. Protocolo custom opcode 1574 (parseHuntFinder -> onHuntFinderList), pareado com o
-- módulo servidor data/modules/huntFinder. Ver .claude/rules/HUNTFINDER_SPEC.md.
--
-- FASE 2 (janela): layout completo do design — header, sidebar de filtros, sort, linhas ricas (estrela +
-- portraits + dots de elemento + tier), rodapé com Selected + Show/Track. Filtros 100% client-side sobre o
-- snapshot cacheado. Tipos/cores derivados da cyclopedia. Show/Track são finalizados nas Fases 4/5.

-- ---------------------------------------------------------------------------------------------------
-- Dados estáticos
-- ---------------------------------------------------------------------------------------------------
local CONTINENTS = { [1] = "Kanto", [2] = "Johto", [3] = "Hoenn" }
local CONTINENT_ID = { Kanto = 1, Johto = 2, Hoenn = 3 }

-- enum de tipo = cyclopedia PokemonType (1..18; dark=16, steel=17, fairy=18)
local TYPE_NAMES = { "Normal", "Fire", "Water", "Grass", "Electric", "Ice", "Fighting", "Poison", "Ground",
  "Flying", "Psychic", "Bug", "Rock", "Ghost", "Dragon", "Dark", "Steel", "Fairy" }
local NAME_TO_TYPE = {}
for i, n in ipairs(TYPE_NAMES) do NAME_TO_TYPE[n:lower()] = i end

local TYPE_COLORS = { "#a8a29a", "#e25822", "#3b82c4", "#57a02f", "#d4a017", "#5fb8c9", "#bf5540", "#8e44ad",
  "#b98e4c", "#7f9fc9", "#d4608d", "#93a824", "#a48f5a", "#6f5a9e", "#6f56c9", "#8c6f5a", "#8a9bb0", "#d977b8" }

-- super-efetivo (atacante -> tipos defensores 2x). Só o que o filtro "Pokémon Used" precisa (client não tem chart).
local SUPER_EFFECTIVE = {
  [2]  = { 4, 6, 12, 17 },        -- fire
  [3]  = { 2, 9, 13 },            -- water
  [4]  = { 3, 9, 13 },            -- grass
  [5]  = { 3, 10 },               -- electric
  [6]  = { 4, 9, 10, 15 },        -- ice
  [7]  = { 1, 6, 13, 16, 17 },    -- fighting
  [8]  = { 4, 18 },               -- poison
  [9]  = { 2, 5, 8, 13, 17 },     -- ground
  [10] = { 4, 7, 12 },            -- flying
  [11] = { 7, 8 },                -- psychic
  [12] = { 4, 11, 16 },           -- bug
  [13] = { 2, 6, 10, 12 },        -- rock
  [14] = { 11, 14 },              -- ghost
  [15] = { 15 },                  -- dragon
  [16] = { 11, 14 },              -- dark
  [17] = { 6, 13, 18 },           -- steel
  [18] = { 7, 15, 16 },           -- fairy
}

local TIER_NAMES = { [8] = "Super Rare", [9] = "Ultra Rare", [10] = "Legendary", [11] = "Mythic" }
local function tierText(t) return TIER_NAMES[t] or ("Tier " .. t) end
local function tierColor(t)
  if t >= 10 then return "#7a5aa5" end
  if t >= 4 then return "#3b9aa5" end
  if t >= 3 then return "#3b6ea5" end
  return "#4a545f"
end

-- ---------------------------------------------------------------------------------------------------
local window, huntButton, list
local huntsCache = {}
local selected = nil
local sortMode = "level"
local filters = { search = "", minLevel = nil, maxLevel = nil, used = "", target = "",
  element = nil, tier = nil, wildscape = nil, continent = nil }

-- ---------------------------------------------------------------------------------------------------
-- pokedata (derivado da cyclopedia)
-- ---------------------------------------------------------------------------------------------------
local function pokeSprite(dex) return "/images/pokemons/" .. string.format("%03d", dex) end

local function pokeName(dex)
  local n = g_pokemonCyclopedia.getNameByNumber(dex)
  if n == nil or n == "" then return "#" .. dex end
  return n
end

local function typesOfDex(dex)
  local name = g_pokemonCyclopedia.getNameByNumber(dex)
  if name == nil or name == "" then return {} end
  local t = {}
  local p = g_pokemonCyclopedia.getPrimaryTypeId(name)
  if p and p > 0 then t[#t + 1] = p end
  if g_pokemonCyclopedia.hasSecondaryType(name) then
    local s = g_pokemonCyclopedia.getSecondaryTypeId(name)
    if s and s > 0 then t[#t + 1] = s end
  end
  return t
end

local function dexOfName(raw)
  if not raw or raw == "" then return nil end
  local d = g_pokemonCyclopedia.getDexNumber(raw:lower())
  if not d or d == "" then return nil end
  return tonumber(d)
end

-- elementos de uma hunt = união dos tipos dos pokes (cacheado na table da hunt)
local function huntElements(h)
  if h._elements then return h._elements end
  local seen, out = {}, {}
  for _, dex in ipairs(h.pokes) do
    for _, tid in ipairs(typesOfDex(dex)) do
      if not seen[tid] then seen[tid] = true; out[#out + 1] = tid end
    end
  end
  h._elements = out
  return out
end

-- o pokémon "usado" (por nome) é super-efetivo contra algum elemento da hunt?
local function strongAgainst(usedRaw, h)
  local dex = dexOfName(usedRaw)
  if not dex then return false end
  local ut = typesOfDex(dex)
  if #ut == 0 then return false end
  local elems = huntElements(h)
  for _, atk in ipairs(ut) do
    local se = SUPER_EFFECTIVE[atk]
    if se then
      for _, def in ipairs(elems) do
        for _, x in ipairs(se) do if x == def then return true end end
      end
    end
  end
  return false
end

-- ---------------------------------------------------------------------------------------------------
-- Filtro + ordenação
-- ---------------------------------------------------------------------------------------------------
local function matches(h)
  local f = filters
  if f.search ~= "" and not h.name:lower():find(f.search, 1, true) then return false end
  if f.minLevel and h.levelMax < f.minLevel then return false end
  if f.maxLevel and h.levelMin > f.maxLevel then return false end
  if f.tier and h.shinyTier ~= f.tier then return false end
  if f.wildscape ~= nil and (h.wildscape == true) ~= f.wildscape then return false end
  if f.continent and h.continent ~= f.continent then return false end
  if f.element then
    local ok = false
    for _, tid in ipairs(huntElements(h)) do if tid == f.element then ok = true break end end
    if not ok then return false end
  end
  if f.target ~= "" then
    local ok = false
    for _, dex in ipairs(h.pokes) do
      if pokeName(dex):lower():find(f.target, 1, true) then ok = true break end
    end
    if not ok then return false end
  end
  if f.used ~= "" and not strongAgainst(f.used, h) then return false end
  return true
end

local function sorter(a, b)
  if sortMode == "name" then return a.name < b.name end
  if sortMode == "tier" then return a.shinyTier < b.shinyTier end
  return a.levelMin < b.levelMin
end

-- ---------------------------------------------------------------------------------------------------
-- Seleção
-- ---------------------------------------------------------------------------------------------------
local function select(h)
  selected = h
  local footer = window.footerBar
  footer.selectedName:setText(h and h.name or tr("None - click a hunt to select it"))
  footer.showButton:setEnabled(h ~= nil)
  footer.trackButton:setEnabled(h ~= nil and h.accessible == true)
  -- NewStraightBlueButton não tem visual de $disabled — esmaece na mão
  footer.showButton:setOpacity(h ~= nil and 1 or 0.45)
  footer.trackButton:setOpacity((h ~= nil and h.accessible == true) and 1 or 0.45)
end

-- ---------------------------------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------------------------------
local function buildRow(h)
  local row = g_ui.createWidget("HuntRow", list)
  if not h.accessible then row:setOpacity(0.6) end

  -- portraits (até 3)
  local shown = 0
  for _, dex in ipairs(h.pokes) do
    if shown >= 3 then break end
    shown = shown + 1
    local p = g_ui.createWidget("HuntPortrait", row.portraits)
    local name = pokeName(dex)
    -- Outfit real (looktype da cyclopedia) quando registrado; PNG por dex como fallback (gens 2/3 ainda = 0)
    local lt = g_pokemonCyclopedia.getLookType(name)
    if lt > 0 then
      p.circle.creature:setOutfit({ type = lt })
    else
      p.circle.sprite:setImageSource(pokeSprite(dex))
      p.circle.sprite:setImageClip({ x = 10, y = 10, width = 120, height = 120 })
    end
    -- nome só no tooltip (widget UITooltip estilizado; o corelib o destrói junto do portrait — sem leak);
    -- o portrait não é phantom (pra receber hover), então re-encaminha o clique pro select
    local tt = g_ui.createWidget("PokeNameTooltip", rootWidget)
    tt.nameLabel:setText(name)
    p:setTooltip(tt)
    p.onClick = function() select(h) list:focusChild(row) end
  end

  row.info.huntName:setText(h.name)
  row.info.wildBadge:setVisible(h.wildscape == true)
  row.info.continent:setText(CONTINENTS[h.continent] or "?")

  for _, tid in ipairs(huntElements(h)) do
    local dot = g_ui.createWidget("ElementDot", row.info.dots)
    dot:setBackgroundColor(TYPE_COLORS[tid] or "#888888")
    dot:setTooltip(TYPE_NAMES[tid] or "?")
  end

  -- hífen simples: a fonte poppins não tem o glifo de en-dash ("20–80" renderizava "2080")
  row.rightCol.level:setText(string.format("Lv. %d-%d", h.levelMin, h.levelMax))
  row.rightCol.tierBadge:setImageColor(tierColor(h.shinyTier))
  row.rightCol.tierBadge:setWidth(h.shinyTier >= 8 and 92 or 64) -- nomes longos (Super Rare...) precisam de mais
  row.rightCol.tierBadge.tierLabel:setText(tierText(h.shinyTier))

  row.onClick = function() select(h) list:focusChild(row) end
  return row
end

local function refresh()
  if not window or not list then return end

  local shown = {}
  for _, h in ipairs(huntsCache) do
    if matches(h) then shown[#shown + 1] = h end
  end
  table.sort(shown, sorter)

  local layout = list:getLayout()
  if layout then layout:disableUpdates() end
  list:destroyChildren()
  for _, h in ipairs(shown) do buildRow(h) end
  if layout then layout:enableUpdates() layout:update() end

  -- se a hunt selecionada sumiu do filtro, limpa a seleção
  if selected then
    local stillThere = false
    for _, h in ipairs(shown) do if h == selected then stillThere = true break end end
    if not stillThere then select(nil) end
  end
end

-- ---------------------------------------------------------------------------------------------------
-- Filtros: wiring dos controles
-- ---------------------------------------------------------------------------------------------------
local function setWildVisual(wt)
  local sel = "wildAll"
  if filters.wildscape == true then sel = "wildYes"
  elseif filters.wildscape == false then sel = "wildNo" end
  for _, id in ipairs({ "wildAll", "wildYes", "wildNo" }) do
    local active = (id == sel)
    -- troca a ARTE (arredondada) em vez de desenhar borda reta por cima: ativa = pill azul nativa
    wt[id]:setImageSource(active and "/images/newui/blueStraight" or "/images/newui/grayStraight")
    wt[id]:setColor(active and "#ffffff" or "#c8d2da")
  end
end

local function resetFilters()
  filters = { search = "", minLevel = nil, maxLevel = nil, used = "", target = "",
    element = nil, tier = nil, wildscape = nil, continent = nil }
  sortMode = "level"
  local sb = window.sidebar
  sb.searchEdit:setText("")
  sb.minEdit:setText("")
  sb.maxEdit:setText("")
  sb.usedEdit:setText("")
  sb.targetEdit:setText("")
  sb.elementCombo:setCurrentOption(tr("Any"), true)
  sb.tierCombo:setCurrentOption(tr("All"), true)
  sb.continentCombo:setCurrentOption(tr("All"), true)
  window.sortCombo:setCurrentOption(tr("Level"), true)
  setWildVisual(sb.wildToggle)
  refresh()
end

local function wireControls()
  local sb = window.sidebar

  sb.searchEdit.onTextChange = function(_, text) filters.search = text:lower() refresh() end
  sb.minEdit.onTextChange = function(_, text) filters.minLevel = tonumber(text) refresh() end
  sb.maxEdit.onTextChange = function(_, text) filters.maxLevel = tonumber(text) refresh() end
  sb.usedEdit.onTextChange = function(_, text) filters.used = text refresh() end
  sb.targetEdit.onTextChange = function(_, text) filters.target = text:lower() refresh() end

  -- comboboxes
  sb.elementCombo:addOption(tr("Any"))
  for _, n in ipairs(TYPE_NAMES) do sb.elementCombo:addOption(n) end
  sb.elementCombo.onOptionChange = function(_, text)
    filters.element = NAME_TO_TYPE[text:lower()] -- nil para "Any"
    refresh()
  end

  sb.tierCombo:addOption(tr("All"))
  for t = 1, 7 do sb.tierCombo:addOption("Tier " .. t) end
  for t = 8, 11 do sb.tierCombo:addOption(TIER_NAMES[t]) end
  sb.tierCombo.onOptionChange = function(_, text)
    if text == tr("All") then filters.tier = nil
    else
      local n = tonumber(text:match("%d+"))
      if not n then
        for tid, nm in pairs(TIER_NAMES) do if nm == text then n = tid break end end
      end
      filters.tier = n
    end
    refresh()
  end

  sb.continentCombo:addOption(tr("All"))
  for _, n in ipairs({ "Kanto", "Johto", "Hoenn" }) do sb.continentCombo:addOption(n) end
  sb.continentCombo.onOptionChange = function(_, text)
    filters.continent = CONTINENT_ID[text] -- nil para "All"
    refresh()
  end

  -- wildscape toggle
  local wt = sb.wildToggle
  wt.wildAll.onClick = function() filters.wildscape = nil setWildVisual(wt) refresh() end
  wt.wildYes.onClick = function() filters.wildscape = true setWildVisual(wt) refresh() end
  wt.wildNo.onClick = function() filters.wildscape = false setWildVisual(wt) refresh() end
  setWildVisual(wt)

  sb.resetButton.onClick = resetFilters

  -- sort
  window.sortCombo:addOption(tr("Level"))
  window.sortCombo:addOption(tr("Name"))
  window.sortCombo:addOption(tr("Tier"))
  window.sortCombo.onOptionChange = function(_, text)
    if text == tr("Name") then sortMode = "name"
    elseif text == tr("Tier") then sortMode = "tier"
    else sortMode = "level" end
    refresh()
  end

  -- Show / Track (comportamento completo nas Fases 4/5)
  window.footerBar.showButton.onClick = function()
    if selected then g_game.sendHuntFinderShowPlace(selected.id) end
  end
end

-- ---------------------------------------------------------------------------------------------------
-- Janela
-- ---------------------------------------------------------------------------------------------------
local function requestList()
  if g_game.isOnline() then g_game.sendHuntFinderRequestList() end
end

function show()
  if not window then return end
  window:show()
  window:raise()
  window:focus()
  g_uistates.push(window) -- teclado preso na janela (digitar nos filtros não anda/dispara hotkeys)
  if huntButton then huntButton:setOn(true) end
  if #huntsCache == 0 then requestList() else refresh() end
end

function hide()
  if window then
    g_uistates.remove(window)
    window:hide()
  end
  if huntButton then huntButton:setOn(false) end
end

function toggle()
  if window and window:isVisible() then hide() else show() end
end

-- ---------------------------------------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------------------------------------
local function onHuntFinderList(hunts)
  huntsCache = hunts or {}
  if window and window:isVisible() then refresh() end
end

local function onGameStart()
  requestList()
end

function onGameEnd()
  huntsCache = {}
  select(nil)
  hide()
end

-- ---------------------------------------------------------------------------------------------------
function init()
  connect(g_game, { onHuntFinderList = onHuntFinderList, onGameStart = onGameStart, onGameEnd = onGameEnd })

  window = g_ui.loadUI("huntfinder", modules.game_interface.getRootPanel())
  window:hide()
  list = window.huntList

  wireControls()
  select(nil)

  huntButton = modules.client_topmenu.addMiddleGameToggleButton(
    "huntFinderButton", tr("Hunt Finder"), "/images/ui/topbuttons/icons/guide_arrow", toggle)

  if g_game.isOnline() then onGameStart() end
end

function terminate()
  disconnect(g_game, { onHuntFinderList = onHuntFinderList, onGameStart = onGameStart, onGameEnd = onGameEnd })
  if huntButton then huntButton:destroy() huntButton = nil end
  if window then
    g_uistates.remove(window)
    window:destroy()
    window = nil
  end
end
