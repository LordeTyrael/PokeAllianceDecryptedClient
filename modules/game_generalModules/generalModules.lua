local mewtwoMainWindow = nil
local mewtwoShopWindow = nil
local mewtwoDifficultyWindow = nil
local protocolsType = { open = 1, confirm = 2 }
local clonesInfo = {
	shop = {},
	difficulties = {}
}

local protocols = {
	mewtwoClones = 273
}

function init()
	connect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd,
		onWalk = hideMewtwoPanel,
    onAutoWalk = hideMewtwoPanel
	})
end

function terminate()
	disconnect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd,
		onWalk = hideMewtwoPanel,
    onAutoWalk = hideMewtwoPanel
	})
end

function onGameStart()
	ProtocolGame.registerOpcode(protocols.mewtwoClones, _handleStartMewtwo)
end

function onGameEnd()
	ProtocolGame.unregisterOpcode(protocols.mewtwoClones)
	hideMewtwoPanel()
end

function _handleStartMewtwo(opcode, msg)
	local pktType = msg:getU8()
	if pktType == 1 then
		local requiredPlayers = msg:getU8()
		local description     = msg:getString()
		local difficultyIndex = msg:getU8()
		local maxTime         = msg:getU16()
		local requiredLevel   = msg:getU16()
		local difficultyName  = msg:getString()
	
		clonesInfo.difficulties = {}                   -- mapa por id
		local diffCount = msg:getU8()
		for i = 1, diffCount do
			local id   = msg:getU8()
			local name = msg:getString()
			local req  = msg:getU16()
			local time = msg:getU16()
			
			local exp  = msg:getU32()
			local cnt  = msg:getU8()
			local items = {}
			for j = 1, cnt do
				local itemId = msg:getU16()
				local qty    = msg:getU16()
				items[#items+1] = { id = itemId, count = qty }
			end
			
			clonesInfo.difficulties[id] = {
				id = id, name = name, requiredLevel = req, maxTime = time,
				rewards = { experience = exp, items = items }
			}
		end
	
  	-- shop
		local shopCount = msg:getU8()
		clonesInfo.shop = {}
		for i = 1, shopCount do
			local id   = msg:getU8()
			local name = msg:getString()
			local key = msg:getString()
			local desc = msg:getString()
			local cost = msg:getU32()
			table.insert(clonesInfo.shop, { id = id, name = name, key = key, desc = desc, cost = cost, selected = nil })
		end
	
  	if mewtwoMainWindow then
		mewtwoMainWindow:destroy()
  	end
  	mewtwoMainWindow = g_ui.displayUI("mewtwoClones")
	
  	local dungeonImage = mewtwoMainWindow.dungeon_image
  	local rewardPanel  = mewtwoMainWindow.reward_panel
	
  	-- preencher infos
  	if dungeonImage then
		dungeonImage:setImageSource("mewtwoClones/background")
		if dungeonImage.time_info    then dungeonImage.time_info:setText(tr("%d min", maxTime)) end
		if dungeonImage.players_info then dungeonImage.players_info:setText(tr("Players: %d", requiredPlayers)) end
		if dungeonImage.level_info   then dungeonImage.level_info:setText(tr("Level: %d", requiredLevel)) end
  	end
	
  	if mewtwoMainWindow.difficultyLabel then
		local fallback = ({ "Easy", "Medium", "Hard" })[difficultyIndex] or ("#" .. difficultyIndex)
		local name = (difficultyName ~= "" and difficultyName) or fallback
		mewtwoMainWindow.difficultyLabel:setText(name:gsub("^%l", string.upper))
		mewtwoMainWindow.difficultyLabel.onClick = openMewtwoDifficultyWindow
  	end
	
  	if mewtwoMainWindow.dungeon_description then
		mewtwoMainWindow.dungeon_description:setText(description)
  	end
	
  	if mewtwoMainWindow.shopButton then
		mewtwoMainWindow.shopButton.onClick = function()
		  openMewtwoShopWindow()
		end
  	end
	
  	if mewtwoMainWindow.startButton then
		local player = g_game.getLocalPlayer()
		local canStart = true
		if player and player.getLevel then canStart = player:getLevel() >= requiredLevel end
		mewtwoMainWindow.startButton:setEnabled(canStart)
  	end
	
		clonesInfo.difficultyIndex = difficultyIndex
		local cur = clonesInfo.difficulties[difficultyIndex]
		clonesInfo.rewards = cur and cur.rewards or { experience = 0, items = {} }
		renderRewards()
		return
	elseif pktType == 3 then
		hideMewtwoPanel()
	end
end

local mewtwoShopWindow = nil

function openMewtwoShopWindow()
  -- fecha instância anterior
  if mewtwoShopWindow and not mewtwoShopWindow:isDestroyed() then
	mewtwoShopWindow:destroy()
	mewtwoShopWindow = nil
  end

  -- abre a janela do OTUI (use o nome do arquivo sem extensão)
  mewtwoShopWindow = g_ui.displayUI('mewtwoClonesShop')
  mewtwoShopWindow:raise()
  mewtwoShopWindow:focus()

  -- acessos diretos aos widgets
  local list = mewtwoShopWindow.shopArea
  if not list then return end

  list:destroyChildren()

  -- popula itens da loja
  local items = clonesInfo and clonesInfo.shop or {}
  --[[if #items == 0 then
	local empty = g_ui.createWidget('Label', list)
	empty:setText(tr("No items available."))
	empty:setFont('poppins semibold 12')
	empty:setOpacity(0.8)
	return
  end]]

  for _, it in ipairs(items) do
	local row = g_ui.createWidget('MewtwoShopRow', list)
	-- texto + tooltip
	row.itemIndex = it.id
	row.description:setText(it.desc or "")
	row.buffImage:setImageSource("mewtwoClones/buffs/"..it.key)
	local config = clonesInfo.shop and clonesInfo.shop[it.id] or nil
	if config then
		local imageSource = config.selected and "/images/newui/greenStraight" or "/images/newui/blueStraight"
		local text = config.selected and "Active" or formatNumberValue(config.cost)
		row.purchase:setText(text)
		row.purchase:setImageSource(imageSource)
	end

	


	-- ação de compra (placeholder: talk). Troque para opcode quando criar no server.
	--row.buyButton.onClick = function()
	--  -- Exemplo via talkaction (teste):
	--  g_game.talk(string.format("/mewtwo_buy %d", it.id))
--
	--  -- Exemplo via opcode (quando implementar):
	--  -- local n = OutputMessage.create()
	--  -- n:addU8(protocolsType.buy)  -- 2, por exemplo
	--  -- n:addU8(it.id)
	--  -- ProtocolGame.sendExtendedOpcode(protocols.mewtwoClones, n)
	--end]]
  end

  -- botão fechar (se quiser sobrescrever o @onClick do OTUI)
  if mewtwoShopWindow.close then
	mewtwoShopWindow.close.onClick = function()
	  if mewtwoShopWindow and not mewtwoShopWindow:isDestroyed() then
		mewtwoShopWindow:destroy()
		mewtwoShopWindow = nil
	  end
	end
  end
end

function hideMewtwoPanel()
	if mewtwoDifficultyWindow then
		mewtwoDifficultyWindow:destroy()
		mewtwoDifficultyWindow = nil
	end
	
	hideBuffShopWindow()
	if mewtwoMainWindow then
		mewtwoMainWindow:destroy()
		mewtwoMainWindow = nil
	end
end

function hideBuffShopWindow()
	if mewtwoShopWindow then
		mewtwoShopWindow:destroy()
		mewtwoShopWindow = nil
	end
end

function confirmMewtwoShopRow(widget)
	local parent = widget and widget:getParent() or nil
	if not widget or not parent then
		return
	end

	local index = parent.itemIndex or nil
	if not index then
		return
	end

	local config = clonesInfo.shop and clonesInfo.shop[index] or nil
	if not config then
		return
	end

	local selected = not config.selected
	local imageSource = selected and "/images/newui/greenStraight" or "/images/newui/blueStraight"
	local text = selected and "Active" or formatNumberValue(config.cost)

	clonesInfo.shop[index].selected = selected
	widget:setText(text)
	widget:setImageSource(imageSource)
end

local function canUseDifficulty(entry)
  local p = g_game.getLocalPlayer()
  local lvl = (p and p.getLevel and p:getLevel()) or 1
  return lvl >= (entry.requiredLevel or 0)
end

function openMewtwoDifficultyWindow()
	if mewtwoDifficultyWindow then
		return
	end

	mewtwoDifficultyWindow = g_ui.displayUI('mewtwoClonesDifficulty', mewtwoMainWindow)
	mewtwoDifficultyWindow:raise(); mewtwoDifficultyWindow:focus()

	local list = mewtwoDifficultyWindow.diffArea
	if not list then return end
	list:destroyChildren()

	-- popula
	for _, d in ipairs(clonesInfo.difficulties or {}) do
		local row = g_ui.createWidget('MewtwoDifficultyRow', list)
	
		local label = string.format("%s    %d min  |  Lv %d", (d.name:gsub("^%l", string.upper)), d.maxTime or 0, d.requiredLevel or 0)
		row.select:setText(label)
	
		local allowed = canUseDifficulty(d)
		row.select:setEnabled(allowed)
	
		-- marca seleção atual
		if clonesInfo.difficultyIndex == d.id then
			row.select:setImageSource("/images/newui/greenStraight") -- highlight selecionado
		end
	
		if row.lockIcon then row.lockIcon:setVisible(not allowed) end
	
		row.select.onClick = function()
			if not allowed then return end
	
			-- aplica no painel principal
			clonesInfo.difficultyIndex = d.id
	
			if mewtwoMainWindow and mewtwoMainWindow.difficultyLabel then
			  mewtwoMainWindow.difficultyLabel:setText(d.name:gsub("^%l", string.upper))
			end
			if mewtwoMainWindow and mewtwoMainWindow.dungeon_image then
				local img = mewtwoMainWindow.dungeon_image
				if img.time_info  then img.time_info:setText(tr("%d min", d.maxTime or 0)) end
				if img.level_info then img.level_info:setText(tr("Level: %d", d.requiredLevel or 0)) end
			end

			clonesInfo.rewards = (clonesInfo.difficulties[d.id] and clonesInfo.difficulties[d.id].rewards) or { experience = 0, items = {} }
			renderRewards()
	
			mewtwoDifficultyWindow:destroy()
			mewtwoDifficultyWindow = nil
		end
	end

	if mewtwoDifficultyWindow.close then
		mewtwoDifficultyWindow.close.onClick = function() if not mewtwoDifficultyWindow:isDestroyed() then mewtwoDifficultyWindow:destroy() mewtwoDifficultyWindow = nil end end
	end
end

-- Preenche os 14 slots com os itens da dificuldade atual e atualiza o label de EXP
function renderRewards()
	if not mewtwoMainWindow or mewtwoMainWindow:isDestroyed() then return end
	local panel = mewtwoMainWindow.reward_panel
	if not panel or not panel.rewards then return end
	
	local grid   = panel.rewards
	local rewards = clonesInfo.rewards or {}
	local items   = rewards.items or {}
	local expAmt  = rewards.experience or 0
	
	grid:destroyChildren()
	
	local maxSlots = 14
	local n = math.min(#items, maxSlots)
	for i = 1, n do
		local info = items[i]
		local slot = g_ui.createWidget('MewtwoRewardBase', grid)
		local uiItem = slot and slot.completedOption
		if uiItem then
			uiItem:setVirtual(true)
			uiItem:setPhantom(true)
			uiItem:setItemId(info.id)
			if uiItem.setItemCount then
				uiItem:setItemCount(info.count or 1)
			end
			local countTxt = (info.count and info.count > 1) and (" x"..info.count) or ""
			if uiItem.setTooltip then
				local name = getItemNameById and getItemNameById(info.id) or tr("Item %s", info.id)
				uiItem:setTooltip(name .. countTxt)
			end
		end
	end
	
	for i = n + 1, maxSlots do
		g_ui.createWidget('MewtwoRewardBase', grid)
	end
	
	if panel.reward_text then
		local fmt = formatNumberValue and formatNumberValue(expAmt) or tostring(expAmt)
		local suffix = (expAmt > 0) and (" +"..fmt.." EXP") or ""
		panel.reward_text:setText(tr("Available Rewards") .. suffix)
	end
end

local function getSelectedBuffIdsOrderedCapped()
  	local ids = {}
  	for _, it in ipairs(clonesInfo.shop or {}) do
  	  	if it.selected then
  	  	  	ids[#ids+1] = it.id
  	  	end
  	end
  	table.sort(ids)
  	if #ids > 255 then
  	  	while #ids > 255 do table.remove(ids) end
  	end
  	return ids
end

function sendMewtwoConfirm()
  	local pg = g_game.getProtocolGame()
  	if not pg then return end
	
  	local diff = clonesInfo.difficultyIndex or 1
  	local buffIds = getSelectedBuffIdsOrderedCapped()
	
  	local msg = OutputMessage.create()
  	msg:addU16(protocols.mewtwoClones)
  	msg:addU8(protocolsType.confirm)
  	msg:addU8(diff)
  	msg:addU8(#buffIds)
  	for i = 1, #buffIds do
  	  	msg:addU8(buffIds[i])
  	end

  	pg:send(msg)
end
