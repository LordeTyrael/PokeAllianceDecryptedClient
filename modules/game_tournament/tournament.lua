local protocolNumber = 272
local tournamentRegisterWindow

local TournamentModel = {
  items = {},         -- [id] = { id, name, boost, lookType, selected, initialIndex }
  order = {},         -- ordem original (ids)
  maxSelectable = 0,  -- 0 = sem limite (ajuste aqui se quiser 0 = bloqueado)
}

local function resetTournamentModel()
	TournamentModel = {
	  items = {},
	  order = {},
	  maxSelectable = 0,
	}
end

local function baseKey(name, lookType)
  return string.format("%s:%d", name, lookType)
end


local function ensureWindow()
  if not tournamentRegisterWindow then
	tournamentRegisterWindow = g_ui.loadUI('tournament', modules.game_interface.getRootPanel())
  end
  return tournamentRegisterWindow
end

local function countSelected()
  local n = 0
  for _, it in pairs(TournamentModel.items) do
	if it.selected then n = n + 1 end
  end
  return n
end

-- Se recebeu um limite novo menor que o selecionado atual, desmarca o excedente preservando a ordem inicial
local function enforceSelectionLimit()
  local limit = TournamentModel.maxSelectable or 0
  if limit <= 0 then return end
  local selectedIds = {}
  for _, id in ipairs(TournamentModel.order) do
	local it = TournamentModel.items[id]
	if it and it.selected then table.insert(selectedIds, id) end
  end
  for i = limit + 1, #selectedIds do
	local it = TournamentModel.items[selectedIds[i]]
	if it then it.selected = false end
  end
end

local function notifyLimit()
  local ok = pcall(function()
	displayInfoBox(tr("Tournament"), string.format(tr("You can select up to %d Pokémon."), TournamentModel.maxSelectable))
  end)
  if not ok then
	g_logger.info(string.format("[Tournament] selection limit reached: %d", TournamentModel.maxSelectable))
  end
end

local function renderPokemonGrid()
  local win = ensureWindow()
  local panel = win.pokemonPanel
  local layout = panel:getLayout()

  -- Atualiza título com o limite (opcional)
  if win.title then
	local base = tr("Tournament")
	if TournamentModel.maxSelectable > 0 then
	  win.title:setText(string.format("%s  (max %d)", base, TournamentModel.maxSelectable))
	else
	  win.title:setText(base)
	end
  end

  layout:disableUpdates()
  panel:destroyChildren()

  -- Ordena: selecionados primeiro; dentro do grupo, respeita ordem inicial
  local ids = {}
  for _, id in ipairs(TournamentModel.order) do table.insert(ids, id) end
  table.sort(ids, function(a, b)
	local A, B = TournamentModel.items[a], TournamentModel.items[b]
	if A.selected ~= B.selected then return A.selected and not B.selected end
	return A.initialIndex < B.initialIndex
  end)

  for _, id in ipairs(ids) do
	local it = TournamentModel.items[id]
	local w = g_ui.createWidget("TournamentPokemonWidget", panel)
	w.__id = id
	w.selected = it.selected or false

	w.pokemon:setOutfit({ type = it.lookType })
	w:setTooltip(humanCase(it.name))
	w.pokemonBoost:setText("+" .. it.boost)
	w:setBorderColor(w.selected and "green" or "red")

	w.onMouseRelease = function(self, pos, button)
	  if button == MouseLeftButton then
		selectWidget(self)
		return true
	  end
	end
  end

  layout:enableUpdates()
  layout:update()
end

-- Toggle com respeito ao limite
function selectWidget(widget)
  if not widget or not widget.__id then return end
  local it = TournamentModel.items[widget.__id]
  if not it then return end

  local limit = TournamentModel.maxSelectable or 0
  local goingToSelect = not (it.selected or false)

  if goingToSelect and limit > 0 and (countSelected()) >= limit then
	notifyLimit()
	return
  end

  it.selected = goingToSelect
  renderPokemonGrid()
end

function init()
  connect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
end

function terminate()
  disconnect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
end

function onGameStart()
  ProtocolGame.registerOpcode(protocolNumber, parseTournamentMessage)
end

function onGameEnd()
  ProtocolGame.unregisterOpcode(protocolNumber)
end

function parseTournamentMessage(opcode, msg)
	local limit = msg:getU8()
  local count = msg:getU8()
  TournamentModel.maxSelectable = limit

  -- preserva seleção anterior
  local prevSelected = {}
  for id, it in pairs(TournamentModel.items) do
    if it.selected then prevSelected[id] = true end
  end

  TournamentModel.items = {}
  TournamentModel.order = {}

  -- contador de ocorrências por (name, lookType)
  local occ = {}  -- ex: occ["Pikachu:128"] = 2

  for i = 1, count do
    local name = msg:getString()
    local boost = msg:getU8()
    local lookType = msg:getU16()

    local bk = baseKey(name, lookType)
    occ[bk] = (occ[bk] or 0) + 1
    local id = string.format("%s#%d", bk, occ[bk]) -- id único por ocorrência

    TournamentModel.items[id] = {
      id = id,
      name = name,
      boost = boost,
      lookType = lookType,
      selected = prevSelected[id] or false,
      initialIndex = i,
    }
    table.insert(TournamentModel.order, id)
  end

  enforceSelectionLimit()
  renderPokemonGrid()
end

function show()
  ensureWindow()
  renderPokemonGrid()
end

function closeRegisterWindow()
  if tournamentRegisterWindow then
	tournamentRegisterWindow:destroy()
	tournamentRegisterWindow = nil
  end
  resetTournamentModel()
end

local function getSelectedIdsOrderedCapped()
  -- mantém ordem inicial, depois aplica cap (min 20 e maxSelectable se > 0)
  local ids = {}
  for _, id in ipairs(TournamentModel.order) do
    local it = TournamentModel.items[id]
    if it and it.selected then table.insert(ids, id) end
  end

  local hardCap = 20
  local limit = TournamentModel.maxSelectable or 0
  if limit > 0 then hardCap = math.min(hardCap, limit) end

  while #ids > hardCap do table.remove(ids) end
  return ids
end

function sendTournamentRegistration()
  local pg = g_game.getProtocolGame()
  if not pg then return end

  local ids = getSelectedIdsOrderedCapped()
  if #ids == 0 then
    displayInfoBox(tr("Tournament"), tr("Select at least 1 Pokémon."))
    return
  end

  local msg = OutputMessage.create()
  msg:addU16(protocolNumber)
  -- payload:
  -- U8 count
  -- para cada entry:
  --   U8 hasUid (0/1)
  --   se hasUid=1:  U32 uid
  --   se hasUid=0:  U16 index (initialIndex, 1-based igual veio do server)
  msg:addU8(#ids)

  for _, id in ipairs(ids) do
    local it = TournamentModel.items[id]
    if it.uid then
      msg:addU8(1)
      msg:addU32(it.uid)
    else
      msg:addU8(0)
      msg:addU16(it.initialIndex)
    end
  end

  pg:send(msg)
end