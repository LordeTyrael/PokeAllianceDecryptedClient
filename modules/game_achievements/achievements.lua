-- S2C = 201 nativo (parseReceiveAchievements em C++); C2S = 1580 via g_game.sendAchievements*
local unlockedWindow
local achievements
local cleanEvent
local achievementsWindow
local constCategories = {
	ACHIEVEMENTCATEGORY_GERAL = 0,
	ACHIEVEMENTCATEGORY_CHARACTER = 1,
	ACHIEVEMENTCATEGORY_POKEBALLS = 2,
	ACHIEVEMENTCATEGORY_MISSIONS = 3,
	ACHIEVEMENTCATEGORY_PVE = 4,
	ACHIEVEMENTCATEGORY_PVP = 5
}

local categoryColors = {
	[1] = "#66ccff",
	[2] = "#ffcc66",
	[3] = "#66ff99",
	[4] = "#ff9966",
	[5] = "#99aaff",
	[6] = "#ff6699",
}

local categories = {
	[1] = {
		const = constCategories.ACHIEVEMENTCATEGORY_GERAL,
		name = "General",
		icon = "new_images/category_icon/general"
	},
	[2] = {
		const = constCategories.ACHIEVEMENTCATEGORY_CHARACTER,
		name = "Characters",
		icon = "new_images/category_icon/characters"
	},
	[3] = {
		const = constCategories.ACHIEVEMENTCATEGORY_POKEBALLS,
		name = "Pokeballs",
		icon = "new_images/category_icon/pokeball"
	},
	[4] = {
		const = constCategories.ACHIEVEMENTCATEGORY_MISSIONS,
		name = "Missions",
		icon = "new_images/category_icon/mission"
	},
	[5] = {
		const = constCategories.ACHIEVEMENTCATEGORY_PVE,
		name = "PvE",
		icon = "new_images/category_icon/pve"
	},
	[6] = {
		const = constCategories.ACHIEVEMENTCATEGORY_PVP,
		name = "PvP",
		icon = "new_images/category_icon/pvp"
	}
}

local function getPriority(item)
  	if item.percent == 100 and item.rewardCollected == 0 then
		return 1
  	elseif item.percent < 100 then
		return 2
  	else
		return 3
  	end
end

local activeTooltip = nil
local hoveredAchievement = nil

local shiftPollEvent = nil
local shiftWasPressed = false

local onShiftDown, onShiftUp

local function buildPokemonTooltip(achievement)
	local tooltip = g_ui.createWidget('AchievementPokemonTooltip', g_ui.getRootWidget())
	tooltip:setPhantom(true)
	tooltip:setDrawOnTopOfBlur(true)
	tooltip:hide()

	tooltip:getChildById('title'):setText(achievement.name or "")

	local total, caught = #achievement.pokemons, 0
	for _, p in ipairs(achievement.pokemons) do
		if p.caught then caught = caught + 1 end
	end
	tooltip:getChildById('progressText'):setText(string.format("%d / %d caught", caught, total))

	local list = tooltip:getChildById('pokemonList')
	for _, p in ipairs(achievement.pokemons) do
		local entry = g_ui.createWidget('AchievementPokemonEntry', list)
		entry:getChildById('creature'):setOutfit({ type = p.lookType })
		local label = entry:getChildById('pokemonName')
		label:setText(p.name)
		if p.caught then
			label:setColor("#7cd672")
		else
			label:setColor("#888888")
			entry:getChildById('creature'):setOpacity(0.4)
		end
	end
	return tooltip
end

local function positionTooltipForAchievement(tooltip, achievementWidget)
	local row = achievementWidget:getParent()
	local anchor = (row and row:getChildById('achievementIcon')) or achievementWidget
	local rect = anchor:getRect()
	local screenSize = g_window.getSize()
	local size = tooltip:getSize()
	local pos = { x = rect.x, y = rect.y }

	if pos.x + size.width > screenSize.width - 4 then
		pos.x = screenSize.width - size.width - 4
	end
	if pos.y + size.height > screenSize.height - 4 then
		pos.y = rect.y + rect.height - size.height
	end
	if pos.x < 4 then pos.x = 4 end
	if pos.y < 4 then pos.y = 4 end
	tooltip:setPosition(pos)
end

local function setTooltipInteractive(tooltip, interactive)
	tooltip:setPhantom(not interactive)
	local footer = tooltip:getChildById('footerLabel')
	if footer then
		footer:setText(interactive and tr("Inspecting...") or tr("Hold Shift to Inspect"))
		footer:setColor(interactive and "#7cd672" or "#aaaaaa")
	end
end

local function hideActiveTooltip()
	if activeTooltip then
		if activeTooltip:isLocked() then
			activeTooltip:setLocked(false)
			setTooltipInteractive(activeTooltip, false)
		end
		activeTooltip:hide()
		local list = activeTooltip:getChildById('pokemonList')
		if list and list.setVerticalScrollPos then list:setVerticalScrollPos(0) end
		activeTooltip = nil
	end
end

local function showAchievementTooltip(tooltip, achievementWidget)
	if activeTooltip and activeTooltip ~= tooltip then
		activeTooltip:hide()
	end
	positionTooltipForAchievement(tooltip, achievementWidget)
	tooltip:show()
	tooltip:raise()
	activeTooltip = tooltip
end

local function onAchievementHoverChange(self, hovered, tooltip)
	if activeTooltip and activeTooltip:isLocked() then
		if hovered then
			hoveredAchievement = self
		elseif hoveredAchievement == self then
			hoveredAchievement = nil
		end
		return
	end

	if hovered then
		hoveredAchievement = self
		showAchievementTooltip(tooltip, self)
	else
		if hoveredAchievement == self then hoveredAchievement = nil end
		hideActiveTooltip()
	end
end

onShiftDown = function()
	if not activeTooltip or activeTooltip:isLocked() then return end
	activeTooltip:setLocked(true)
	setTooltipInteractive(activeTooltip, true)
end

onShiftUp = function()
	if not activeTooltip or not activeTooltip:isLocked() then return end
	local prev = activeTooltip
	prev:setLocked(false)
	setTooltipInteractive(prev, false)
	if not hoveredAchievement then
		hideActiveTooltip()
	else
		local nextTooltip = hoveredAchievement._pokemonTooltip
		if nextTooltip and nextTooltip ~= prev then
			showAchievementTooltip(nextTooltip, hoveredAchievement)
		end
	end
end

local function setFavoriteButtonState(button, isFavorite)
	if not button then return end
	button.isFavorite = isFavorite
	button:setImageSource(isFavorite and "new_images/favorite" or "new_images/favorite_select")
	button:setTooltip(isFavorite and tr("Remove from favorites") or tr("Add to favorites"))
end

local function setRewardCollectedState(progressBackground)
	progressBackground.collectWidget.icon:setImageSource("new_images/completed_icon")
	progressBackground.collectWidget.collectText:setText(tr("Completed"))
	progressBackground.collectButton:setImageSource("new_images/collected")
	progressBackground.collectButton:setText(tr("Collected"))
	progressBackground.collectButton:disable()
end

local function rebuildAchievementsUI()
  	if not achievementsWindow or not achievementsWindow.achievementPanel then
		return
  	end
	
  	local panel  = achievementsWindow.achievementPanel
  	local layout = achievementsWindow:getLayout()
  	if layout then
  		layout:disableUpdates()
  	end
	
  	panel:destroyChildren()

  	for i, achievement in ipairs(achievements or {}) do
		local w = g_ui.createWidget("AchievementWidget", panel)
		w:setId(achievement.achievementID)
		w.baseWidget.achievementID = achievement.achievementID
	
		w.baseWidget.achievementName:setText(achievement.name or "")
		w.baseWidget.achievementDescription:setText(achievement.description or "")
	
		w.achievementIcon:setImageSource("new_images/icons/" .. (achievement.tier or 0))
	
		setFavoriteButtonState(w.baseWidget.favoriteButton, achievement.favorite and true or false)
	
		if achievement.name == "???" then
		  	w.achievementIcon.itemImage:setImageSource("new_images/achievement_icons/secret")
		else
		  	local icon = achievement.icon
		  	if icon and icon.type == 1 and icon.lookType then
				w.achievementIcon.creatureIcon:setOutfit({ type = icon.lookType })
		  	elseif icon and icon.type == 2 and icon.clientId then
				w.achievementIcon.itemIcon:setItemId(icon.clientId)
		  	elseif icon and icon.type == 3 and icon.image then
				w.achievementIcon.itemImage:setImageSource("new_images/achievement_icons/" .. icon.image)
		  	end
		end

		if achievement.pokemons and #achievement.pokemons > 0 then
			local tooltip = buildPokemonTooltip(achievement)
			w.baseWidget._pokemonTooltip = tooltip
			connect(w.baseWidget, {
				onHoverChange = function(self, hovered)
					onAchievementHoverChange(self, hovered, tooltip)
				end,
				onDestroy = function()
					if activeTooltip == tooltip then activeTooltip = nil end
					if tooltip and not tooltip:isDestroyed() then
						tooltip:destroy()
					end
				end
			})
		end
	
		local bg = w.baseWidget.progressBackground
		if achievement.unlocked == 0 then
			local pct = tonumber(achievement.percent) or 0
			if pct > 0 then
				if pct == 100 then
					bg.collectButton:show()
					bg.progressBarBackground:hide()
					bg.collectWidget:show()
				
					if achievement.rewardCollected == 1 then
						setRewardCollectedState(bg)
					end
				else
					local totalWidth = 352
					local totalHeight = 8
					local clippedWidth = math.ceil(totalWidth * (pct / 100))
					bg.progressBarBackground.percentProgress:setImageRect({x = 0, y = 0, width = clippedWidth, height = totalHeight})
				end
			else
				bg.progressBarBackground.percentProgress:hide()
			end
			bg.progressPercentText:setText((achievement.percent ~= 100 and (achievement.percent .. "%")) or "")
		end
	end
	
	if layout then
		layout:enableUpdates()
		layout:update()
	end
	
	if achievementsWindow:isVisible() and achievementsWindow.loadingScreen then
		achievementsWindow.loadingScreen:hide()
	end
end

modules.client_hotkeys.registerHotkeyCallback("ACHIEVEMENTS",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        if achievementsWindow then
          close()
        else
          open()
        end
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

-- UIWindow raises itself on focus, so any window the player clicks lands above the toast.
local function raiseUnlockedWindow()
	if unlockedWindow and not unlockedWindow:isDestroyed() and unlockedWindow:isVisible() then
		unlockedWindow:raise()
	end
end

local function destroyUnlockedWindow()
	if not unlockedWindow then return end

	disconnect(g_ui.getRootWidget(), { onChildFocusChange = raiseUnlockedWindow })
	removeEvent(unlockedWindow._closeEvt)
	removeEvent(unlockedWindow._hideEvt)
	if not unlockedWindow:isDestroyed() then
		unlockedWindow:destroy()
	end
	unlockedWindow = nil
end

function init()
	achievements = {}

	connect(g_game, {
		onGameEnd = onGameEnd,
		onAchievementsList = onAchievementsList,
		onAchievementRewardUpdate = onAchievementRewardUpdate,
		onAchievementFavoriteUpdate = onAchievementFavoriteUpdate,
		onAchievementNotification = onAchievementNotification
	})

	connect(g_client, {
		onTrainerClose = close
	})
end

function terminate()
	disconnect(g_game, {
		onGameEnd = onGameEnd,
		onAchievementsList = onAchievementsList,
		onAchievementRewardUpdate = onAchievementRewardUpdate,
		onAchievementFavoriteUpdate = onAchievementFavoriteUpdate,
		onAchievementNotification = onAchievementNotification
	})

	disconnect(g_client, {
		onTrainerClose = close,
	})

	destroyUnlockedWindow()
end

function onGameEnd()
	achievements = {}
	hideActiveTooltip()
	hoveredAchievement = nil
	destroyUnlockedWindow()
	if achievementsWindow then
		if not achievementsWindow:isDestroyed() then
			achievementsWindow:destroy()
		end
		achievementsWindow = nil
	end
end

function open()
	if achievementsWindow then
		return
	end
	achievementsWindow = g_ui.loadUI("achievements", modules.game_interface.getRootPanel())

	local layout = achievementsWindow:getLayout()
	layout:disableUpdates()

	for _, category in ipairs(categories) do
		local button = g_ui.createWidget('CategoryButton', achievementsWindow.categoryArea)
		button.icon:setImageSource(category.icon)
		button.name:setText(category.name)
		button.const = category.const
	end

	local firstIndex = achievementsWindow.categoryArea:getChildByIndex(1)
	if firstIndex then
		firstIndex:focus()
	end

	layout:enableUpdates()
	layout:update()

	requestAchivementsCategory(firstIndex)

	achievementsWindow:focus()
	achievementsWindow:show()
	g_uistates.push(achievementsWindow)
	g_effects.fadeIn(achievementsWindow)

	if shiftPollEvent then removeEvent(shiftPollEvent) end
	shiftPollEvent = cycleEvent(function()
		local pressed = g_keyboard.isShiftPressed()
		if pressed and not shiftWasPressed then
			onShiftDown()
		elseif not pressed and shiftWasPressed then
			onShiftUp()
		end
		shiftWasPressed = pressed
	end, 50)
end

function close()
	g_effects.fadeOut(achievementsWindow)
	scheduleEvent(function()
		if achievementsWindow then
			hideActiveTooltip()
			hoveredAchievement = nil
			if shiftPollEvent then
				removeEvent(shiftPollEvent)
				shiftPollEvent = nil
			end
			shiftWasPressed = false
			g_uistates.remove(achievementsWindow)
			if not achievementsWindow:isDestroyed() then
				achievementsWindow:destroy()
			end
			achievementsWindow = nil
		end
	end, 500)
end

function onAchievementsList(category, list)
	achievements = list or {}
	table.sort(achievements, function(a, b)
		if a.favorite ~= b.favorite then
			return a.favorite
		end
		local pa, pb = getPriority(a), getPriority(b)
		if pa ~= pb then
			return pa < pb
		end
		return (a.achievementID or 0) < (b.achievementID or 0)
	end)

	if achievementsWindow and achievementsWindow.selectedCategoryName and achievementsWindow.categoryArea then
		local focused = achievementsWindow.categoryArea:getFocusedChild()
		if focused and focused.name then
			achievementsWindow.selectedCategoryName:setText(focused.name:getText())
		end
	end

	rebuildAchievementsUI()

	if cleanEvent then
		removeEvent(cleanEvent)
		cleanEvent = nil
	end
end

function onAchievementRewardUpdate(achievementID, rewardCollected)
	if not achievements then return end

	for _, a in ipairs(achievements) do
		if a.achievementID == achievementID then
			a.rewardCollected = rewardCollected
			break
		end
	end

	table.sort(achievements, function(a, b)
		if a.favorite ~= b.favorite then
			return a.favorite
		end
		local pa, pb = getPriority(a), getPriority(b)
		if pa ~= pb then
			return pa < pb
		end
		return (a.achievementID or 0) < (b.achievementID or 0)
	end)

	if achievementsWindow and achievementsWindow.achievementPanel then
		local panel  = achievementsWindow.achievementPanel
		local widget = panel:getChildById(achievementID)

		local newIndex
		for i, a in ipairs(achievements) do
			if a.achievementID == achievementID then
				newIndex = i
				break
			end
		end

		if widget and newIndex then
			panel:moveChildToIndex(widget, newIndex)

			local bg = widget.baseWidget.progressBackground
			if tonumber(rewardCollected) == 1 then
				setRewardCollectedState(bg)
			end
			panel:ensureChildVisible(widget)
		end
	end
end

function onAchievementFavoriteUpdate(achievementID, isFav)
	if not achievements then return end

	for _, a in ipairs(achievements) do
		if a.achievementID == achievementID then
			a.favorite = isFav and true or false
			break
		end
	end

	table.sort(achievements, function(a, b)
		if a.favorite ~= b.favorite then
			return a.favorite
		end
		local pa, pb = getPriority(a), getPriority(b)
		if pa ~= pb then
			return pa < pb
		end
		return (a.achievementID or 0) < (b.achievementID or 0)
	end)

	if achievementsWindow and achievementsWindow.achievementPanel then
		local panel  = achievementsWindow.achievementPanel
		local widget = panel:getChildById(achievementID)

		local newIndex
		for i, a in ipairs(achievements) do
			if a.achievementID == achievementID then
				newIndex = i; break
			end
		end

		if widget and newIndex then
			panel:moveChildToIndex(widget, newIndex)
			setFavoriteButtonState(widget.baseWidget.favoriteButton, isFav and true or false)
			panel:ensureChildVisible(widget)
		end
	end
end

function requestAchivementsCategory(widget)
	local category = constCategories.ACHIEVEMENTCATEGORY_GERAL
	if widget and widget.const then
		category = widget.const
	end

	local layout = achievementsWindow.achievementPanel:getLayout()
	if layout then
		layout:disableUpdates()
	end

	if widget and widget.name and achievementsWindow and achievementsWindow.selectedCategoryName then
		achievementsWindow.selectedCategoryName:setText(widget.name:getText())
	end

	achievementsWindow.achievementPanel:destroyChildren()

	if layout then
		layout:enableUpdates()
		layout:update()
	end

	achievementsWindow.loadingScreen:show()

	cleanEvent = scheduleEvent(function()
		if achievementsWindow and achievementsWindow:isVisible() then
			achievementsWindow.loadingScreen:hide()
		end
		cleanEvent = nil
	end, 5000)

	-- opcode 1580 (migrado do extended 201). Número novo: o 201 do S2C é engolido no C2S por
	-- ClientUpdateTile=201 / case 0xC9 no servidor.
	g_game.sendAchievementsRequestCategory(category)
end

function collectReward(widget)
	if not widget then return end
	local parent = widget:getParent()
	if not parent or not parent.achievementID then return end

	g_game.sendAchievementsCollectReward(parent.achievementID)
end

function setFavorite(widget)
	if not widget or not widget.achievementID then return end

	local favorite = not widget.favoriteButton.isFavorite
	g_game.sendAchievementsSetFavorite(widget.achievementID, favorite)
end

local function safeSet(widget, setter, value)
	if widget and widget[setter] then
		widget[setter](widget, value)
	end
end

function onAchievementNotification(name, description, tier, category, targetOrEvent)
	if not unlockedWindow or unlockedWindow:isDestroyed() then
		unlockedWindow = g_ui.loadUI('unlocked', g_ui.getRootWidget())
		connect(g_ui.getRootWidget(), { onChildFocusChange = raiseUnlockedWindow })
	end
	
	local titleW = unlockedWindow.title
	local iconW  = unlockedWindow.icon
	local nameW  = unlockedWindow.name
	local descW  = unlockedWindow.description
	local elementIconW = unlockedWindow.elementIcon
	
	safeSet(nameW, 'setText', name or "")
	safeSet(descW, 'setText', description or "")
	if iconW and tier then
		iconW:setImageSource("new_images/icons/" .. tostring(tier))
	end
	if elementIconW then
		local element = targetOrEvent or ""
		elementIconW:setImageSource(element ~= "" and ("new_images/achievement_icons/" .. element) or "")
	end

	if titleW and category and categoryColors[category] then
		titleW:setColor(categoryColors[category])
	end
	
	if unlockedWindow._closeEvt then
		removeEvent(unlockedWindow._closeEvt)
		unlockedWindow._closeEvt = nil
	end
	if unlockedWindow._hideEvt then
		removeEvent(unlockedWindow._hideEvt)
		unlockedWindow._hideEvt = nil
	end

	unlockedWindow:show()
	unlockedWindow:raise()
	g_effects.fadeIn(unlockedWindow)

	unlockedWindow._closeEvt = scheduleEvent(function()
		if unlockedWindow and not unlockedWindow:isDestroyed() then
			g_effects.fadeOut(unlockedWindow)
			unlockedWindow._hideEvt = scheduleEvent(function()
				if unlockedWindow and not unlockedWindow:isDestroyed() then
					unlockedWindow:hide()
				end
			end, g_effects.getFadeOutTime() + 30)
		end
	end, 4500)
end