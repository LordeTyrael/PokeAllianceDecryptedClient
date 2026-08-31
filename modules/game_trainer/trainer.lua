local MainWindow, PixSearchWindow, PixWindow, PortraitWindow, WithdrawWindow
local profileButton
local Panel = {}
local expSpeedEvent = nil
local securityWindow = nil
local passwordPanel = nil
local trainerPasswordPanel = nil
local passwordValue = ""
local MAX_PASSWORD_LEN = 8
local Opcode = 13
local loaded = false
local pixConfirmBox = nil

local function closePixConfirmBox()
	if pixConfirmBox then
		pixConfirmBox:destroy()
		pixConfirmBox = nil
	end
end

modules.client_hotkeys.registerHotkeyCallback("TRAINER",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        toggle()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

-- Cosmetic catalog state
local cosmeticTab = "profiles"
local cosmeticSelectedProfileId = 0
local cosmeticSelectedBackgroundId = 0
local cosmeticEquippedProfileId = 0
local cosmeticEquippedBackgroundId = 0
local cosmeticProfilesData = {}
local cosmeticBackgroundsData = {}

local _onKeyDown
local _onEscape
local SkillResolver = {
	[0] = {label = "Vehicles Ablity", id = "fist"},
	[3] = {label = "Rock Smash", id = "rock_smash", widget = "skillRockSmash"},
	[4] = {label = "Headbutt",   id = "headbutt",   widget = "skillHeadbutt"},
	[6] = {label = "Fishing",    id = "fish",       widget = "skillFishing"}
}


local function formatTrainerLastLogin(timestamp)
	if not timestamp or timestamp == 0 then
		return ""
	end
	return os.date("%d/%m/%Y %H:%M", timestamp)
end

local blessConfig = {
	["pve"] = {
		[1] = {itemId = 37800, tooltip = "Life Insurance"},
		[2] = {itemId = 37801, tooltip = "Life Insurance Plus"}
	},
	["pvp"] = {
		[1] = {itemId = 37803, tooltip = "Life Insurance PVP"}
	}
}

local function onGameStart()
	MainWindow = g_ui.loadUI("trainer", modules.game_interface.getRootPanel())
	PortraitWindow = g_ui.loadUI("portrait", modules.game_interface.getRootPanel())
	Panel.left = MainWindow:getChildById("leftPanel")
	Panel.right = MainWindow:getChildById("rightPanel")

	PixWindow = g_ui.loadUI("pixwindow", modules.game_interface.getRootPanel())
	PixSearchWindow = g_ui.loadUI("pixsearchwindow", modules.game_interface.getRootPanel())
	WithdrawWindow = g_ui.loadUI("withdrawwindow", modules.game_interface.getRootPanel())
	loaded = true

	local categories = {
		{ name = tr("Main"), onClick = function() showPanel("informationPanel") end, internal = true },
		{ name = tr("Wallet"), onClick = function() showPanel("walletPanel") end, internal = true },
		{ name = tr("Achievements"), onClick = function() modules.game_achievements.open() end },
		{ name = tr("Pokémon Brokes"), onClick = function() modules.game_pokemonbrokes.toggle() end},
		{ name = tr("Talents"), onClick = function() modules.game_abilitytree.toggle() end },
		{ name = tr("Medals"), onClick = function() modules.game_medals.openPokemonMedals() end },
		{ name = tr("Pokélog"), onClick = function() modules.game_pokelog.toggle() end },
		{ name = tr("Celebi Shrine"), onClick = function() g_game.requestOpenGacha() end },
	}

	for _, cat in ipairs(categories) do
		local btn = g_ui.createWidget('ProfilyCategoryButton', MainWindow.categoryPanel)
		btn.category_name:setText(cat.name)
		if cat.onClick then
			local originalOnClick = cat.onClick
			local isInternal = cat.internal
			btn.onClick = function()
				if isInternal then
					setActiveCategoryButton(btn)
				end
				originalOnClick()
			end
		end
	end

	-- highlight first button by default
	local firstBtn = MainWindow.categoryPanel:getFirstChild()
	if firstBtn then
		setActiveCategoryButton(firstBtn)
	end

	MainWindow:hide()
	PixWindow:hide()
	PixSearchWindow:hide()
	WithdrawWindow:hide()
	refresh()

end

local function onGameEnd()
	-- ANTES do guard: o botao da topbar sobrevive ao logout (topMenu e criado uma vez so). Sem
	-- isto, sair com o trainer aberto deixava o botao aceso no login seguinte, com a janela
	-- fechada. onGameEnd destroi a MainWindow direto, sem passar pelo hide().
	if profileButton then profileButton:setOn(false) end
	if not MainWindow then
		return
	end
	closePixConfirmBox()
	g_uistates.remove(MainWindow)
	signalcall(g_client.onTrainerClose, true)
	MainWindow:destroy()
	MainWindow = nil
	closeSecurityWindow()
	closePasswordPanel()
	if expSpeedEvent then expSpeedEvent:cancel() expSpeedEvent = nil end
	-- Limpa OS CAMPOS, sem reatribuir a tabela: `playerExperienceInfo = {}` aqui criaria um global no
	-- sandbox do game_trainer e o game_playeractionbar continuaria apontando para a tabela antiga — os dois
	-- parariam de compartilhar estado depois do primeiro logout. A tabela é declarada em
	-- modules/gamelib/game.lua (gamelib não é sandboxed).
	playerExperienceInfo.lastExps = nil
	playerExperienceInfo.expSpeed = nil
end



function checkExpSpeed()
	local player = g_game.getLocalPlayer()
	if not player then
		return
	end
	local currentExp = player:getExperience()
	local currentTime = g_clock.seconds()
	if playerExperienceInfo.lastExps ~= nil then
		playerExperienceInfo.expSpeed = (currentExp - playerExperienceInfo.lastExps[1][1]) / (currentTime - playerExperienceInfo.lastExps[1][2])
		onLevelChange(player, player:getLevel(), player:getLevelPercent())
	else
		playerExperienceInfo.lastExps = {}
	end
	table.insert(playerExperienceInfo.lastExps, {currentExp, currentTime})
	if #playerExperienceInfo.lastExps > 30 then
		table.remove(playerExperienceInfo.lastExps, 1)
	end
end

function init()
	connect(g_game, {
		onGameEnd = onGameEnd,
		onGameStart = onGameStart,
		onTrainerError = onTrainerError,
		onPixInfoReceived = onPixInfoReceived,
		onCosmeticCatalog = onCosmeticCatalog,
		onSecurity = parseSecurityProtocol
	})

	connect(LocalPlayer, {
		onExperienceChange = onExperienceChange,
		onLevelChange = onLevelChange,
		onSkillChange = onSkillChange,
		onCatchesChange = onCatchesChange,
		onCasinoCoinsChange = onCasinoCoinsChange,
		onBankBalanceChange = onBankBalanceChange,
		onGuildNameChange = onGuildNameChange,
		onGuildRankNameChange = onGuildRankNameChange,
		onTrainerIdChange = onTrainerIdChange,
		onOnlinePointsChange = onOnlinePointsChange,
		onPlayerIconChange = onPlayerIconChange,
		onLifeInsuranceChange = onLifeInsuranceChange,
		onLifeInsurancePvpChange = onLifeInsurancePvpChange,
		onTrainerIconsChange = onTrainerIconsChange,
		onLastLoginChange = onLastLoginChange,
		onCompletedAchievementsChange = onCompletedAchievementsChange,
		onPlayerHazardLevelChange = onPlayerHazardLevelChange,
		onTotalDexChange = onTotalDexChange,
		onHouseNameChange = onHouseNameChange,
		onEquippedProfileChange = onEquippedProfileChange,
		onEquippedBannerChange = onEquippedBannerChange
	})

	-- Botao FIXO da topbar (grupo da esquerda). Nao passa pela aba Top Icons: o jogador nao pode
	-- remove-lo nem reordena-lo. Ate agora o trainer so abria pelo hotkey Ctrl+T.
	profileButton = modules.client_topmenu.addMiddleGameToggleButton('profileButton', tr('Profile'),
		'/images/ui/topbuttons/icons/trainer_id', toggle)
	profileButton:setOn(false)
end

function terminate()
	-- Removing the connectors
	if MainWindow then
		MainWindow:destroy()
		MainWindow = nil
	end
	if PixSearchWindow then
		PixSearchWindow:destroy()
		PixSearchWindow = nil
	end

	if PixWindow then
		PixWindow:destroy()
		PixWindow = nil
	end

	if WithdrawWindow then
		WithdrawWindow:destroy()
		WithdrawWindow = nil
	end

	if PortraitWindow then
		PortraitWindow:destroy()
		PortraitWindow = nil
	end

	closeSecurityWindow()
	closePasswordPanel()

	disconnect(g_game, {
		onGameEnd = onGameEnd,
		onGameStart = onGameStart,
		onTrainerError = onTrainerError,
		onPixInfoReceived = onPixInfoReceived,
		onCosmeticCatalog = onCosmeticCatalog,
		onSecurity = parseSecurityProtocol
	})

	disconnect(LocalPlayer, {
		onExperienceChange = onExperienceChange,
		onLevelChange = onLevelChange,
		onSkillChange = onSkillChange,
		onCatchesChange = onCatchesChange,
		onCasinoCoinsChange = onCasinoCoinsChange,
		onBankBalanceChange = onBankBalanceChange,
		onGuildNameChange = onGuildNameChange,
		onGuildRankNameChange = onGuildRankNameChange,
		onTrainerIdChange = onTrainerIdChange,
		onOnlinePointsChange = onOnlinePointsChange,
		onPlayerIconChange = onPlayerIconChange,
		onLifeInsuranceChange = onLifeInsuranceChange,
		onLifeInsurancePvpChange = onLifeInsurancePvpChange,
		onTrainerIconsChange = onTrainerIconsChange,
		onLastLoginChange = onLastLoginChange,
		onCompletedAchievementsChange = onCompletedAchievementsChange,
		onPlayerHazardLevelChange = onPlayerHazardLevelChange,
		onTotalDexChange = onTotalDexChange,
		onHouseNameChange = onHouseNameChange,
		onEquippedProfileChange = onEquippedProfileChange,
		onEquippedBannerChange = onEquippedBannerChange
	})
end

function toggle()
	--if modules.game_walking.wsadWalking then
	--  return
	--end
	if not MainWindow then
		return
	end

	if MainWindow:isVisible() then
		hide()
	else
		show()
	end
end

function show()
	if not MainWindow then
		return
	end
	
	MainWindow:show()
    MainWindow:raise()
    g_effects.fadeIn(MainWindow)
	if profileButton then profileButton:setOn(true) end
	playerExperienceInfos()
	g_uistates.push(MainWindow)
	connect(MainWindow, { onKeyDown = _onKeyDown })

	-- Resume background video if visible
	local bgVideo = MainWindow:getChildById("backgroundVideo")
	if bgVideo and bgVideo:isVisible() then
		bgVideo:play()
	end
end

function hide()
	closePixConfirmBox()
	disconnect(MainWindow, { onKeyDown = _onKeyDown })
	revertCosmeticPreview()
	if profileButton then profileButton:setOn(false) end

	-- Pause background video
	local bgVideo = MainWindow:getChildById("backgroundVideo")
	if bgVideo and bgVideo:isVisible() then
		bgVideo:pause()
	end

	g_effects.fadeOut(MainWindow)
	scheduleEvent(function()
		if MainWindow then
			MainWindow:hide()
		end
	end, 500)
	hideAllWalletSubPanels()
	g_uistates.remove(MainWindow)
	PixSearchWindow:hide()
	PixWindow:hide()
	WithdrawWindow:hide()
	PortraitWindow:hide()
	closeSecurityWindow()
	signalcall(g_client.onTrainerClose)
end

function _onKeyDown(widget, keyCode, keyText)
	if keyCode == KeyEscape then
		hide()
		return true
	end
	return false
end

-- g_game.getProtocolGame():sendExtendedOpcode(Opcode, json.encode(params))

function drawRightPanel(id, focused)
	--if not loaded then
	--	return
	--end
	--Panel.right:getChildById(id):setVisible(focused)
	--if id == "pix" and not focused then
	--	PixSearchWindow:hide()
	--	PixWindow:hide()
	--	WithdrawWindow:hide()
	--end
end

-- Overlay helper: hide all wallet overlays and restore input lock to MainWindow
function hideAllWalletSubPanels()
	if not MainWindow then return end
	local overlays = { "pixOverlay", "pixConfirmOverlay", "withdrawOverlay" }
	for _, id in ipairs(overlays) do
		local w = MainWindow:getChildById(id)
		if w then
			g_uistates.remove(w)
			w:hide()
		end
	end
end

local function showOverlay(id)
	if not MainWindow then return end
	hideAllWalletSubPanels()
	local overlay = MainWindow:getChildById(id)
	if overlay then
		overlay:show()
		overlay:raise()
		overlay:focus()
		g_uistates.push(overlay)
	end
end

function showPixSubPanel()
	showOverlay("pixOverlay")
	local overlay = MainWindow.pixOverlay
	if overlay then
		overlay.pixNameEdit:setText("")
		overlay.pixNameEdit:focus()
	end
end

function hidePixSubPanel()
	hideAllWalletSubPanels()
end

function doSearchPixInline()
	if not MainWindow then return end
	local overlay = MainWindow.pixOverlay
	if not overlay then return end
	local name = overlay.pixNameEdit:getText()
	if not name or name:len() < 3 then return end
	g_game.searchPix(name)
end

function showPixConfirmSubPanel(playerName, playerLevel, playerIcon)
	showOverlay("pixConfirmOverlay")
	local panel = MainWindow.pixConfirmOverlay
	if not panel then return end
	panel.pixPlayerName:setText(playerName or "")
	panel.pixPlayerLevel:setText(playerLevel and ("Level " .. playerLevel) or "")
	if playerIcon then
		panel.pixPlayerIcon:setImageSource(playerIcon)
	end
	panel.pixValueEdit:setText("")
	panel.pixValueEdit:focus()
end

function hidePixConfirmSubPanel()
	closePixConfirmBox()
	hideAllWalletSubPanels()
	showPixSubPanel()
end

function doPixInline()
	if not MainWindow then return end
	local panel = MainWindow.pixConfirmOverlay
	if not panel then return end
	local name = panel.pixPlayerName:getText()
	local value = tonumber(panel.pixValueEdit:getText())
	if not name or not value then return end
	if name:len() < 3 or value <= 0 then return end

	closePixConfirmBox()

	local accept = function()
		closePixConfirmBox()
		g_game.sendPix(name, value)
		hideAllWalletSubPanels()
	end

	pixConfirmBox = displayAllianceBox(tr('Pix - Send'),
		tr('Send $%s to %s?', comma_value(value), name) .. '\n' .. tr('This cannot be undone.'), {
			{ text = tr('Confirm'), callback = accept },
			{ text = tr('Cancel'), callback = closePixConfirmBox },
			anchor = AnchorHorizontalCenter
		}, accept)
	pixConfirmBox:setupModal(closePixConfirmBox)
end

function showWithdrawSubPanel()
	showOverlay("withdrawOverlay")
	local overlay = MainWindow.withdrawOverlay
	if overlay then
		overlay.withdrawValueEdit:setText("")
		overlay.withdrawValueEdit:focus()
	end
end

function hideWithdrawSubPanel()
	hideAllWalletSubPanels()
end

function doWithdrawInline()
	if not MainWindow then return end
	local overlay = MainWindow.withdrawOverlay
	if not overlay then return end
	local value = tonumber(overlay.withdrawValueEdit:getText())
	if not value or value <= 0 then return end
	g_game.withdrawBalance(value)
	hideAllWalletSubPanels()
end

-- Legacy functions (redirect to inline overlays for backward compatibility)
function showPixSearchWindow()
	showPixSubPanel()
end

function showPixWindow()
	if PixWindow then
		local name = PixWindow:getChildById("name") and PixWindow:getChildById("name"):getText() or ""
		local level = PixWindow:getChildById("level") and PixWindow:getChildById("level"):getText() or ""
		local icon = PixWindow:getChildById("icon") and PixWindow:getChildById("icon"):getImageSource() or nil
		showPixConfirmSubPanel(name, level, icon)
	end
end

function doSearchPix()
	doSearchPixInline()
end

function doPix()
	doPixInline()
end

function showWithdrawWindow()
	showWithdrawSubPanel()
end

function doWithdraw()
	doWithdrawInline()
end

local trainerErrorBox = nil

function onTrainerError(message)
	if trainerErrorBox then
		trainerErrorBox:destroy()
		trainerErrorBox = nil
	end
	local function closeCallback()
		if trainerErrorBox then
			g_uistates.remove(trainerErrorBox)
			trainerErrorBox:destroy()
			trainerErrorBox = nil
		end
	end
	trainerErrorBox = displayAllianceBox(tr("Information"), message, {
		{text = "Ok", callback = closeCallback},
		anchor = AnchorHorizontalCenter
	}, closeCallback, closeCallback)
	if trainerErrorBox then
		trainerErrorBox:raise()
		trainerErrorBox:focus()
		g_uistates.push(trainerErrorBox)
	end
end

function onPixInfoReceived(name, level, icon)
	local iconPath = icon and icon > 0 and string.format("images/icons/%d", icon) or nil
	showPixConfirmSubPanel(name, tostring(level), iconPath)
end

function showPortraitWindow()
	PortraitWindow:show()
	PortraitWindow:focus()
	PortraitWindow:raise()
end

function changeIcon()
	local icon = PortraitWindow:getChildById("list"):getFocusedChild().id
	g_game.changeTrainerIcon(icon)
	PortraitWindow:hide()
	local characters = G.characters
	local player = g_game.getLocalPlayer()
	if not player then
		return
	end
	for i, char in pairs(characters) do
		if char.name == player:getName() then
			G.characters[i].icon = icon
			if loadBox then
				loadBox:destroy()
				loadBox = nil
			end
			CharacterList.init()
		end
	end
end

function populateInformationPanel()
	local player = g_game.getLocalPlayer()
	if not player or not MainWindow then
		return
	end

	local info = MainWindow.informationPanel
	if not info then
		return
	end

	-- Name + VIP
	info.characterName:setText(player:getName())
	if player:isPremium() then
		info.vipIcon:setOpacity(1.0)
	else
		info.vipIcon:setOpacity(0.3)
	end

	-- Level + Rank
	info.levelLabel:setText("Lvl. " .. player:getLevel())
	local rank = player:getPlayerRank() or 65535
	local rankText = (rank >= 65535) and "+2000" or tostring(rank)
	info.rankLabel:setText("Rank. " .. rankText)

	-- Title (subtitle)
	info.characterTitle:setText("")

	-- World card
	info.worldCard.badge.badgeLabel:setText(tr("World"))
	info.worldCard.cardValue:setText(g_game.getServerName() or "")
	info.worldCard.cardIcon:setImageSource(string.format("/images/game/icons/%s_image", g_game.getServerName():lower()))

	-- Guild card
	local guildName = player:getGuildName()
	local guildRankName = player:getGuildRankName()
	if guildName and guildName ~= "" then
		info.guildCard.badge.badgeLabel:setText(string.upper(guildRankName ~= "" and guildRankName or tr("Member")))
		info.guildCard.cardValue:setText(guildName)
		info.guildCard.guildIcon:setImageSource(string.format("/images/guild_banners/%d.png", player:getGuildBanner()))
	else
		info.guildCard.badge.badgeLabel:setText("")
		info.guildCard.cardValue:setText("No Guild")
		info.guildCard.guildIcon:setImageSource("")
	end
	info.guildCard:show()

	-- Stats grid (left column)
	info.statRow1Left.statBadge.badgeLabel:setText(tr("Arceus Level"))
	info.statRow1Left.statValue:setText(tostring(player:getPlayerHazardLevel() or 0))

	local lastLogin = player:getLastLogin()
	info.statRow2Left.statBadge.badgeLabel:setText(tr("Last Login"))
	info.statRow2Left.statValue:setText(lastLogin and lastLogin > 0 and formatTrainerLastLogin(lastLogin) or "")

	info.statRow3Left.statBadge.badgeLabel:setText(tr("House"))
	local houseName = player:getHouseName()
	info.statRow3Left.statValue:setText((houseName and houseName ~= "") and houseName or "")

	-- Stats grid (right column)
	info.statRow1Right.statBadge.badgeLabel:setText(tr("Achievements"))
	info.statRow1Right.statValue:setText(tostring(player:getCompletedAchievements() or 0))

	info.statRow2Right.statBadge.badgeLabel:setText(tr("Pokédex"))
	info.statRow2Right.statValue:setText(tostring(player:getTotalDex() or 0))

	info.statRow3Right.statBadge.badgeLabel:setText(tr("Catches"))
	info.statRow3Right.statValue:setText(tostring(player:getTotalCatches() or 0))
end

local panelIds = {"informationPanel", "walletPanel", "cosmeticPanel"}

local activeCategoryButton = nil

function setActiveCategoryButton(btn)
	if not MainWindow then return end
	local children = MainWindow.categoryPanel:getChildren()
	if children then
		for _, child in ipairs(children) do
			if child.category_name then
				child.category_name:setColor("#ffffff")
			end
		end
	end
	activeCategoryButton = btn
	if btn and btn.category_name then
		btn.category_name:setColor("#218cdd")
	end
end

function showPanel(panelId)
	if not MainWindow then return end

	-- If leaving cosmetic panel without confirming, revert preview
	local cosmeticPanel = MainWindow:getChildById("cosmeticPanel")
	if cosmeticPanel and cosmeticPanel:isVisible() and panelId ~= "cosmeticPanel" then
		revertCosmeticPreview()
	end

	for _, id in ipairs(panelIds) do
		local panel = MainWindow:getChildById(id)
		if panel then
			panel:setVisible(id == panelId)
		end
	end
	if panelId == "walletPanel" then
		populateWalletPanel()
	end
end

function populateWalletPanel()
	local player = g_game.getLocalPlayer()
	if not player or not MainWindow then return end

	local wallet = MainWindow.walletPanel
	if not wallet then return end

	wallet.walletBalance.statBadge.badgeLabel:setText(tr("Bank Balance"))
	wallet.walletBalance.statValue:setText("$" .. comma_value2(player:getBankBalance()))

	wallet.walletCasino.statBadge.badgeLabel:setText(tr("Casino Coins"))
	wallet.walletCasino.statValue:setText(comma_value2(player:getCasinoCoins()))

	wallet.walletOnlinePoints.statBadge.badgeLabel:setText(tr("Online Points"))
	wallet.walletOnlinePoints.statValue:setText(comma_value2(player:getOnlinePoints()))
end

function playerExperienceInfos()
	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	populateInformationPanel()
	onLevelChange(player, player:getLevel(), player:getLevelPercent())
	onExperienceChange(player, player:getExperience())
	onCatchesChange(player, player:getTotalCatches())
	onCasinoCoinsChange(player, player:getCasinoCoins())
	onBankBalanceChange(player, player:getBankBalance())
	onGuildNameChange(player, player:getGuildName())
	onGuildRankNameChange(player, player:getGuildRankName())
	onTrainerIdChange(player, player:getTrainerId())
	onOnlinePointsChange(player, player:getOnlinePoints())
	onLifeInsuranceChange(player, player:getLifeInsurance())
	onLifeInsurancePvpChange(player, player:getLifeInsurancePvp())


	for _, i in ipairs({3, 4, 6}) do
		onSkillChange(player, i, player:getSkillLevel(i), player:getSkillLevelPercent(i))
	end
end

function onLevelChange(localPlayer, value, percent)
	local text =
		tr("You have %s percent to go", 100 - percent) ..
		"\n" ..
			comma_value(g_game.getExpToAdvance(localPlayer:getLevel(), localPlayer:getExperience())) .. tr(" of experience left")

	if playerExperienceInfo.expSpeed ~= nil then
		local expPerHour = math.floor(playerExperienceInfo.expSpeed * 3600)
		if expPerHour > 0 then
			local nextLevelExp = g_game.getExpForLevel(localPlayer:getLevel() + 1)
			local hoursLeft = (nextLevelExp - localPlayer:getExperience()) / expPerHour
			local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft)) * 60)
			hoursLeft = math.floor(hoursLeft)
			text = text .. "\n" .. comma_value(expPerHour) .. " of experience per hour"
			text = text .. "\n" .. tr("Next level in %d hours and %d minutes", hoursLeft, minutesLeft)
		end
	end

	if not Panel.left then
		return
	end

	Panel.left:getChildById("level"):setText(tr("Level") .. ": " .. value)
	Panel.left:getChildById("experience_bar"):setTooltip(text)
	Panel.left:getChildById("experience_bar"):setPercent(percent)
end

function onExperienceChange(localPlayer, value)
	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	if not Panel.left then
		return
	end

	Panel.left:getChildById("experience"):setText(tr("Experience") .. ": " .. comma_value2(value))
	Panel.left:getChildById("experience_bar"):setPercent(player:getLevelPercent())
end

function onSkillChange(localPlayer, id, level, percent)
	local config = SkillResolver[id]
	if not config or not config.widget or not MainWindow then
		return
	end

	local info = MainWindow.informationPanel
	if not info then return end
	local row = info:getChildById(config.widget)
	if not row then return end

	row.skillName:setText(tr(config.label))
	row.skillLevel:setText(tostring(level or 0))

	local bg = row.skillBarBg
	if bg and bg.skillBarFill then
		local p = math.max(0, math.min(percent or 0, 100))
		local fillWidth = math.floor((bg:getWidth() * p) / 100)
		-- image-border-left/right always render their fixed pixel slices, so a
		-- 0-width fill still draws both rounded caps overlapping. Hide it when
		-- there's no progress, and clamp small fills above the cap width so the
		-- rendering doesn't compress the caps into each other.
		if fillWidth <= 0 then
			bg.skillBarFill:setVisible(false)
		else
			bg.skillBarFill:setVisible(true)
			bg.skillBarFill:setWidth(math.max(fillWidth, 20))
		end
		row:setTooltip(tr("You have %s percent to go", 100 - p))
	end
end

function onCatchesChange(localPlayer, value)
	--Panel.right:getChildById("knows"):getChildById("catchs"):setText(tr("Catchs") .. ": " .. value)
end

function onCasinoCoinsChange(localPlayer, value)
	if MainWindow and MainWindow.walletPanel and MainWindow.walletPanel:isVisible() then
		MainWindow.walletPanel.walletCasino.statValue:setText(comma_value2(value))
	end
end

function onBankBalanceChange(localPlayer, value)
	if MainWindow and MainWindow.walletPanel and MainWindow.walletPanel:isVisible() then
		MainWindow.walletPanel.walletBalance.statValue:setText("$" .. comma_value2(value))
	end
end

function onGuildNameChange(localPlayer, value)
	--local label = Panel.left:getChildById("guild")
	--if not label then
	--	return
	--end
	--label:setText(tr(string.format("%s of %s", localPlayer:getGuildRankName(), value)))
end

function onGuildRankNameChange(localPlayer, value)
	--local label = Panel.left:getChildById("guild")
	--if not label then
	--	return
	--end
	--label:setText(tr(string.format("%s of %s", value, localPlayer:getGuildName())))
end

function onTrainerIdChange(localPlayer, value)
	--Panel.left:getChildById("trainer_id"):setText("#" .. value)
end

function onLifeInsuranceChange(localPlayer, value)
	if not MainWindow then return end

	local blessItem = MainWindow:recursiveGetChildById("blessItem")
	if not blessItem then return end

	local config = blessConfig["pve"][value]
	if not config then
		blessItem:setItemId(37800)
		blessItem:setOpacity(0.3)
		blessItem:setTooltip(tr("No Life Insurance"))
		return
	end

	blessItem:setItemId(config.itemId)
	blessItem:setOpacity(1.0)
	blessItem:setTooltip(config.tooltip)
end

function onLifeInsurancePvpChange(localPlayer, value)
	--local config = blessConfig["pvp"][value]
	--if not config then
	--	Panel.left.bless_pvp:hide()
	--	return
	--end
	--Panel.left.bless_pvp:setItemId(config.itemId)
	--Panel.left.bless_pvp:setTooltip(config.tooltip)
end

function onOnlinePointsChange(localPlayer, value)
	if MainWindow and MainWindow.walletPanel and MainWindow.walletPanel:isVisible() then
		MainWindow.walletPanel.walletOnlinePoints.statValue:setText(comma_value2(value))
	end
end

function onPlayerIconChange(localPlayer, newIcon)
	if not newIcon then
		return
	end
	local playerSex = localPlayer:getPlayerSex() or 0
    local sexData = playerSex == 0 and "male" or "female"

    if not MainWindow then
    	return
    end

    --MainWindow.background.playerAvatar:setImageSource(string.format("/images/avatars/%s/%d", sexData, newIcon))
end

function onTrainerIconsChange(localPlayer, icons)

end

function onLastLoginChange(localPlayer, value)
	if not MainWindow then return end
	local info = MainWindow.informationPanel
	if not info then return end
	info.statRow2Left.statValue:setText(formatTrainerLastLogin(value))
end

function onCompletedAchievementsChange(localPlayer, value)
	if not MainWindow then return end
	local info = MainWindow.informationPanel
	if not info then return end
	info.statRow1Right.statValue:setText(tostring(value or 0))
end

function onPlayerHazardLevelChange(localPlayer, value)
	if not MainWindow then return end
	local info = MainWindow.informationPanel
	if not info then return end
	info.statRow1Left.statValue:setText(tostring(value or 0))
end

function onTotalDexChange(localPlayer, value)
	if not MainWindow then return end
	local info = MainWindow.informationPanel
	if not info then return end
	info.statRow3Right.statValue:setText(tostring(value or 0))
end

function onHouseNameChange(localPlayer, value)
	if not MainWindow then return end
	local info = MainWindow.informationPanel
	if not info then return end
	info.statRow3Left.statValue:setText(value or "")
end

function onEquippedProfileChange(localPlayer, profileId)
	if not MainWindow then return end
	local perfil = MainWindow:getChildById("perfil")
	if perfil and profileId and profileId > 0 then
		perfil:setImageSource(string.format("/images/profile_avatars/%d", profileId))
	end
end

function onEquippedBannerChange(localPlayer, bannerId)
	if not MainWindow then return end
	if bannerId and bannerId > 0 then
		setBackgroundDisplay(bannerId)
	end
end

function setBackgroundDisplay(backgroundId)
	if not MainWindow then return end

	local bg = MainWindow:getChildById("background")
	local bgVideo = MainWindow:getChildById("backgroundVideo")
	if not bg or not bgVideo then return end

	local videoPath = string.format("/data/images/profile_backgrounds/%d.mp4", backgroundId)
	local imagePath = string.format("/data/images/profile_backgrounds/%d", backgroundId)

	if g_resources.fileExists(videoPath) then
		-- Video background
		bg:setVisible(false)
		bg:setImageSource("")
		-- setVideoSource already handles cleanup/reset internally
		bgVideo:setVideoSource(videoPath)
		bgVideo:setLoop(true)
		bgVideo:setVisible(true)
		bgVideo:play()
	else
		-- Image background
		if bgVideo:isVisible() then
			bgVideo:pause()
			bgVideo:reset()
			bgVideo:setVisible(false)
		end
		bg:setImageSource(imagePath)
		bg:setVisible(true)
	end
end

function refresh()
  local player = g_game.getLocalPlayer()
  if not player then return end

  if expSpeedEvent then expSpeedEvent:cancel() end
  expSpeedEvent = cycleEvent(checkExpSpeed, 30*1000)
end

function openSecurityWindow()
	if securityWindow or not MainWindow or not MainWindow:isVisible() then
		return
	end

	securityWindow = g_ui.loadUI('security', modules.game_interface.getRootPanel())
end

function closeSecurityWindow()
	if securityWindow then
		securityWindow:destroy()
		securityWindow = nil
	end
end

function closePasswordPanel()
	if passwordPanel then
		passwordPanel:destroy()
		passwordPanel = nil
	end
end

local globalPasswordConfig = {
	requestPassword = 0,
	setPassword = 1,
}

local TYPE_CFG = {
	[0] = { title = "Set new Password",  typeConfig = globalPasswordConfig.setPassword },
	[1] = { title = "Put your Password", typeConfig = globalPasswordConfig.requestPassword },
}

function parseSecurityProtocol(securityType)
	local cfg = TYPE_CFG[securityType]
	if not cfg then return end

	if passwordPanel then
		passwordPanel:destroy()
	end

	passwordValue = nil
	passwordPanel = g_ui.loadUI('passwordpanel', modules.game_interface.getRootPanel())
	passwordPanel.title:setText(cfg.title)
	passwordPanel.typeConfig = cfg.typeConfig

	setupPasswordPanelBindingsClickOnly()
end

function tryOpenSetPassword()
	if passwordPanel then
		return
	end

	g_game.sendRequestSetPassword()
end

function tryOpenUnlock()
	if passwordPanel then
		return
	end

	g_game.sendRequestSetPassword()
end

function tryRemovePassword()
	if passwordPanel then
		return
	end

	g_game.sendRequestRemovePassword()
end

function tryOpenCheckPassword()
	if passwordPanel then
		return
	end

	g_game.sendRequestWritePassword()
end

function tryOpenLostPassword()
	if passwordPanel then
		return
	end

	g_game.sendRequestLostPassword()
end

function setPasswordDisplay()
	if not passwordPanel then return end
	local disp = passwordPanel.passwordValue
	if disp then
		disp:setText(string.rep("*", #passwordValue))
	end
	local confirmBtn = passwordPanel.confirmButton
	if confirmBtn then
		confirmBtn:setEnabled(#passwordValue > 0)
	end
end

function onPasswordDigit(d)
	if not passwordPanel then return end
	if #passwordValue >= MAX_PASSWORD_LEN then return end
	passwordValue = passwordValue .. d
	setPasswordDisplay()
end

function onPasswordBackspace()
	if not passwordPanel then return end
	local n = #passwordValue
	if n > 0 then
		passwordValue = string.sub(passwordValue, 1, n - 1)
		setPasswordDisplay()
	end
end

function onPasswordConfirm()
  	if not passwordPanel or #passwordValue == 0 then return end
  	local mode = (passwordPanel.typeConfig == globalPasswordConfig.setPassword) and 1 or 0
	
  	if g_game and g_game.sendWritePassword then
		g_game.sendWritePassword(tonumber(passwordValue) or 0, mode)
  	end
	
  	closePasswordPanel()
end

function setupPasswordPanelBindingsClickOnly()
	if not passwordPanel then return end
	passwordValue = ""
	setPasswordDisplay()
end

function getTrainerWindow()
	return MainWindow
end

-- ============================================================
-- Cosmetic Catalog (integrated into trainer panel)
-- ============================================================

function openCosmeticPanel()
	if not MainWindow or not MainWindow:isVisible() then return end
	-- Deactivate category button immediately
	setActiveCategoryButton(nil)
	-- Request data from server
	g_game.openCosmeticCatalog()
end

function onCosmeticCatalog(eqProfile, eqBackground, profiles, backgrounds)
	cosmeticEquippedProfileId = eqProfile
	cosmeticEquippedBackgroundId = eqBackground
	cosmeticSelectedProfileId = eqProfile
	cosmeticSelectedBackgroundId = eqBackground

	cosmeticProfilesData = {}
	for _, p in ipairs(profiles) do
		table.insert(cosmeticProfilesData, {
			id = p[1],
			rarity = p[2],
			isFree = p[3] == 1,
			unlocked = p[4] == 1,
			favorite = p[5] == 1
		})
	end

	cosmeticBackgroundsData = {}
	for _, b in ipairs(backgrounds) do
		table.insert(cosmeticBackgroundsData, {
			id = b[1],
			rarity = b[2],
			isFree = b[3] == 1,
			unlocked = b[4] == 1,
			favorite = b[5] == 1
		})
	end

	if not MainWindow then return end

	-- Show cosmetic panel
	showPanel("cosmeticPanel")

	-- Update top preview with equipped
	updateCosmeticTopPreview()

	-- Default to profiles tab
	switchCosmeticTab("profiles")
end

function switchCosmeticTab(tab)
	if not MainWindow then return end
	cosmeticTab = tab

	local profileBtn = MainWindow:recursiveGetChildById("cosmeticProfileBtn")
	local bannerBtn = MainWindow:recursiveGetChildById("cosmeticBannerBtn")

	if tab == "profiles" then
		if profileBtn then profileBtn:setStyle("NewStraightBlueButton") end
		if bannerBtn then bannerBtn:setStyle("NewStraightGrayButton") end
	else
		if profileBtn then profileBtn:setStyle("NewStraightGrayButton") end
		if bannerBtn then bannerBtn:setStyle("NewStraightBlueButton") end
	end

	populateCosmeticGrid()
end

function populateCosmeticGrid()
	if not MainWindow then return end
	local grid = MainWindow:recursiveGetChildById("cosmeticGrid")
	if not grid then return end
	grid:destroyChildren()

	local layout = grid:getLayout()
	if layout then
		if cosmeticTab == "profiles" then
			layout:setCellSize({ width = 105, height = 105 })
			layout:setNumColumns(4)
		else
			layout:setCellSize({ width = 290, height = 140 })
			layout:setNumColumns(2)
		end
	end

	local items = cosmeticTab == "profiles" and cosmeticProfilesData or cosmeticBackgroundsData
	local selectedId = cosmeticTab == "profiles" and cosmeticSelectedProfileId or cosmeticSelectedBackgroundId

	for _, item in ipairs(items) do
		local widget = g_ui.createWidget("CosmeticItemWidget", grid)

		if cosmeticTab == "profiles" then
			widget:setSize({ width = 100, height = 100 })
		else
			widget:setSize({ width = 285, height = 135 })
		end

		local img = widget:getChildById("cosmeticImage")
		if img then
			if cosmeticTab == "profiles" then
				img:setImageSource(string.format("/images/profile_avatars/%d", item.id))
			else
				local videoPath = string.format("/data/images/profile_backgrounds/%d.mp4", item.id)
				if g_resources.fileExists(videoPath) then
					-- Video banner: show thumbnail (frame 0) in grid without playback
					img:setVisible(false)
					local vid = g_ui.createWidget("UIVideo", widget)
					vid:setId("cosmeticVideoThumb")
					vid:fill("parent")
					vid:setPhantom(true)
					vid:setVideoSource(videoPath)
					-- setVideoSource already calls loadThumbnail() internally,
					-- so frame 0 is displayed as a static image. No play() needed.
				else
					img:setImageSource(string.format("/images/profile_backgrounds/%d", item.id))
				end
			end
		end

		widget.cosmeticId = item.id

		widget.onClick = function()
			if cosmeticTab == "profiles" then
				cosmeticSelectedProfileId = item.id
			else
				cosmeticSelectedBackgroundId = item.id
			end
			updateCosmeticTopPreview()
			highlightCosmeticSelected()
		end

		if item.id == selectedId then
			widget:focus()
		end
	end

	highlightCosmeticSelected()
end

function highlightCosmeticSelected()
	if not MainWindow then return end
	local grid = MainWindow:recursiveGetChildById("cosmeticGrid")
	if not grid then return end
	local selectedId = cosmeticTab == "profiles" and cosmeticSelectedProfileId or cosmeticSelectedBackgroundId
	for _, child in ipairs(grid:getChildren()) do
		if child.cosmeticId == selectedId then
			child:focus()
		end
	end
end

function updateCosmeticTopPreview()
	if not MainWindow then return end

	local perfil = MainWindow:getChildById("perfil")

	if cosmeticSelectedBackgroundId > 0 then
		setBackgroundDisplay(cosmeticSelectedBackgroundId)
	end

	if perfil and cosmeticSelectedProfileId > 0 then
		perfil:setImageSource(string.format("/images/profile_avatars/%d", cosmeticSelectedProfileId))
	end
end

function revertCosmeticPreview()
	if not MainWindow then return end

	local perfil = MainWindow:getChildById("perfil")

	if cosmeticEquippedBackgroundId > 0 then
		setBackgroundDisplay(cosmeticEquippedBackgroundId)
	end

	if perfil and cosmeticEquippedProfileId > 0 then
		perfil:setImageSource(string.format("/images/profile_avatars/%d", cosmeticEquippedProfileId))
	end

	-- Reset selected back to equipped
	cosmeticSelectedProfileId = cosmeticEquippedProfileId
	cosmeticSelectedBackgroundId = cosmeticEquippedBackgroundId
end

function onCosmeticConfirm()
	if not MainWindow then return end

	local profileId = cosmeticSelectedProfileId > 0 and cosmeticSelectedProfileId or cosmeticEquippedProfileId
	local backgroundId = cosmeticSelectedBackgroundId > 0 and cosmeticSelectedBackgroundId or cosmeticEquippedBackgroundId

	-- Only send if something actually changed
	local changed = (profileId ~= cosmeticEquippedProfileId) or (backgroundId ~= cosmeticEquippedBackgroundId)
	if changed then
		g_game.cosmeticCatalogAction(profileId, backgroundId)
		-- Update local equipped state
		cosmeticEquippedProfileId = profileId
		cosmeticEquippedBackgroundId = backgroundId
	end

	-- Go back to Principal
	showPanel("informationPanel")
	local firstBtn = MainWindow.categoryPanel:getFirstChild()
	if firstBtn then
		setActiveCategoryButton(firstBtn)
	end
end
