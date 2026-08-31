local stashWindow = nil
local quickLoot = nil
local selectedPokeball = nil
local lockWindow = nil
local confirmationLockWindow = nil
local selectedPokemonName = nil
local editNameWindow = nil
local confirmationCleanWindow = nil

local constAurasNames = {
	["premier"] = "Premier",
	["alliance"] = "Alliance",
	["noelPulse"] = "Christmas 2024",
	["halloween2025"] = "Halloween 2025",
	["soloLeveling"] = "Solo Leveling",
	["3525"] = "Digimon Red Aura",
	["godSpeed"] = "Killua God Speed"
}

-- Aura values arrive as strings from the server. A purely numeric string ("5")
-- denotes a numeric aura (rendered via outfit.aura); anything else is a shader
-- name (rendered via outfit.shader). This mirrors the C++ applyAuraDescriptor.
local function buildAuraOutfit(aura)
	local outfit = { type = 3128 }
	local n = tonumber(aura)
	if n then
		outfit.aura = n
	else
		outfit.shader = aura
	end
	return outfit
end

local currentTab = "auras"

local pokemonAddons = {}
local pokemonCurrentOutfit = {}
local selectedCurrentAddon = ""

local hasUnsavedChanges = false
local originalSelectedAddon = ""
local originalSelectedAura = nil
local confirmDialog = nil

function init()
	connect(g_game, {
		onGameEnd = onGameEnd,
		onGameStart = onGameStart,
		onReceivePokeballInfo = onReceivePokeballInfo,
		onSendMoveItem = onSendMoveItem
	})
end

function terminate()
	disconnect(g_game, {
		onGameEnd = onGameEnd,
		onGameStart = onGameStart,
		onReceivePokeballInfo = onReceivePokeballInfo,
		onSendMoveItem = onSendMoveItem
	})
end

function destroyPokeballManagementWindow()
	if hasUnsavedChanges then
		checkUnsavedChanges(function()
			closeLockWindow()
			confirmationLockWindowCleanup()
			closeOpenEditName()

			if stashWindow then
				stashWindow:destroy()
				stashWindow = nil
			end
			
			-- Limpar estado
			hasUnsavedChanges = false
			originalSelectedAddon = ""
			originalSelectedAura = nil
		end)
	else
		closeLockWindow()
		confirmationLockWindowCleanup()
		closeOpenEditName()

		if stashWindow then
			stashWindow:destroy()
			stashWindow = nil
		end
		
		-- Limpar estado
		hasUnsavedChanges = false
		originalSelectedAddon = ""
		originalSelectedAura = nil
	end
end

function onGameStart()
end

local friendlyNames = {
	["attack"] = "Attack",
	["criticaldamage"] = "Critical Damage",
	["defense"] = "Defense",
	["hp"] = "HP",
	["precision"] = "Precision",
	["evasion"] = "Evasion",
	["criticalchance"] = "Critical Chance",
	["criticalresistance"] = "Critical Resistance"
}

function onReceivePokeballInfo(pokeballName, aura, pokemonName, capsule, pokeballClientId, heldXClientId, heldYClientId, totalAuras, unlockedAuras, currentTrainingSkill, skillNames, skillLevels, skillPercentages, skillLocked, pokemonLookType, pokemonHead, pokemonBody, pokemonLegs, pokemonFeet, currentAddon, addonNames, addonLookTypes, addonUnlocked, addonCurrent)
	if not selectedPokeball then return end

	local previousTab = currentTab
	destroyPokeballManagementWindow()
	stashWindow = g_ui.loadUI('pokeball_management', modules.game_interface.getRootPanel())
	local rightPanel = stashWindow.rightPanel
	rightPanel.pokemonOutfit:setOutfit({ type = selectedPokeball:getPokemonLookType() })
	rightPanel.pokemonName:setText(humanCase(pokemonName))
	selectedPokemonName = pokemonName

	pokemonSkills = {}
	if skillNames and skillLevels and skillPercentages then
		for i = 1, #skillNames do
			local skillName = skillNames[i]
			local skillLevel = skillLevels[i] or 0
			local skillPercentage = skillPercentages[i] or 0
			local isLocked = skillLocked and skillLocked[i] or false
					
			pokemonSkills[skillName] = {
				name = friendlyNames[skillName] or skillName,
				level = skillLevel,
				percentage = skillPercentage,
				locked = isLocked
			}
		end
	end

	pokemonAddons = {}
	pokemonCurrentOutfit = {
		type = pokemonLookType or 0,
		head = pokemonHead or 0,
		body = pokemonBody or 0,
		legs = pokemonLegs or 0,
		feet = pokemonFeet or 0
	}
	selectedCurrentAddon = currentAddon or ""
	
	originalSelectedAddon = selectedCurrentAddon
	originalSelectedAura = aura
	hasUnsavedChanges = false
	
	if addonNames and addonLookTypes and addonUnlocked and addonCurrent then
		for i = 1, #addonNames do
			local addonName = addonNames[i]
			local addonLookType = addonLookTypes[i] or 0
			local isUnlocked = addonUnlocked[i] or false
			local isCurrent = addonCurrent[i] or false
			
			pokemonAddons[addonName] = {
				name = addonName,
				lookType = addonLookType,
				unlocked = isUnlocked,
				current = isCurrent
			}
		end
	end

	local defaultWidget = g_ui.createWidget('CreatureAuraWidget', stashWindow.optionPanel)
	defaultWidget.lockButton:setVisible(false)
	defaultWidget.blockImage:setVisible(true)
	defaultWidget.aura = ""
	defaultWidget:setTooltip(tr("None"))
	
	defaultWidget.onFocusChange = function(widget, focused)
		if focused then
			markAsChanged()
		end
	end

	local unlockedSet = {}
	for _, aura in ipairs(unlockedAuras) do
		unlockedSet[aura] = true
	end
	unlockedSet[pokeballName] = true

	local widgets = {}
	widgets[#widgets+1] = { aura = nil, widget = defaultWidget }

	for _, aura in ipairs(totalAuras) do
		local config = constAurasNames[aura]
		if unlockedSet[aura] then
			local w = g_ui.createWidget('CreatureAuraWidget', stashWindow.optionPanel)
			w.pokemon:setOutfit(buildAuraOutfit(aura))
			w.lockButton:setVisible(false)
			w.blockImage:setVisible(false)
			if config then
				w:setTooltip(config)
			end
			widgets[#widgets+1] = { aura = aura, widget = w }
			w.aura = aura
			
			w.onFocusChange = function(widget, focused)
				if focused then
					markAsChanged()
				end
			end
		end
	end

	for _, aura in ipairs(totalAuras) do
		local config = constAurasNames[aura]
		if not unlockedSet[aura] then
			local w = g_ui.createWidget('CreatureAuraWidget', stashWindow.optionPanel)
			w.pokemon:setOutfit(buildAuraOutfit(aura))
			w.lockButton:setVisible(true)
			w.blockImage:setVisible(false)
			w.aura = aura
			w:setFocusable(false)
			if config then
				w:setTooltip(config)
			end
			widgets[#widgets+1] = { aura = aura, widget = w }
		end
	end

	local selectedWidget = defaultWidget
	if aura and aura:len() > 0 then
		for _, entry in ipairs(widgets) do
			if entry.aura == aura then
				selectedWidget = entry.widget
				break
			end
		end
	end

	local children = stashWindow.optionPanel:getChildren()
	for i = #children, 1, -1 do
		stashWindow.optionPanel:removeChild(children[i])
	end

	for _, entry in ipairs(widgets) do
		stashWindow.optionPanel:addChild(entry.widget)
	end

	if selectedWidget then
		selectedWidget:focus()
		if defaultWidget ~= selectedWidget then
			stashWindow.optionPanel:moveChildToIndex(selectedWidget, 2)
		end
	end

	local equipped = rightPanel.equippedPanel
	equipped.heldX:setItemId(heldXClientId)
	equipped.heldY:setItemId(heldYClientId)
	equipped.pokeballColor:setItemId(pokeballClientId)
	equipped.capsuleEffect:setEffectId(capsule)
	equipped.capsuleEffect:setScale(0.5)

	-- Restaurar aba que estava ativa antes do refresh
	if previousTab == "training" then
		showTrainingTab()
	elseif previousTab == "addons" then
		showAddonsTab()
	else
		showAurasTab()
	end
end

function onGameEnd()
	destroyPokeballManagementWindow()
	selectedPokeball = nil
end

function setPokeball(pokeball)
	selectedPokeball = pokeball
end

function setRotate()
  if not stashWindow then
	return
  end

  local outfitWindow = stashWindow.rightPanel.pokemonOutfit
  if not outfitWindow then
	return
  end

  local direction = outfitWindow:getDirection()
  if not direction then
	direction = 0
  end

  local newDirection = (direction + 1) % 4
  outfitWindow:setDirection(newDirection)
end

function setWalk()
  if not stashWindow then
	return
  end

  local outfitWindow = stashWindow.rightPanel.pokemonOutfit
  if not outfitWindow then
	return
  end

  local animate = not outfitWindow:isAnimating() and true or false
  outfitWindow:setAnimate(animate)
end

function onConfirmWindow()
	if not stashWindow or not selectedPokeball then
		return
	end

	-- Salvar automaticamente de acordo com a aba atual (sem dialog)
	if currentTab == "addons" then
		local currentOutfit = stashWindow.rightPanel.pokemonOutfit:getOutfit()
		g_game.changePokeballAddon(
			selectedPokeball,
			currentOutfit.type or 0,
			currentOutfit.head or 0,
			currentOutfit.body or 0,
			currentOutfit.legs or 0,
			currentOutfit.feet or 0,
			selectedCurrentAddon or ""
		)

		-- Atualizar estado original
		originalSelectedAddon = selectedCurrentAddon
		hasUnsavedChanges = false

	elseif currentTab == "auras" then
		local auraWidget = stashWindow.optionPanel:getFocusedChild()
		if auraWidget then
			g_game.confirmPokeballManagement(selectedPokeball, auraWidget.aura)
			
			-- Atualizar estado original
			originalSelectedAura = auraWidget.aura
			hasUnsavedChanges = false
		end
	end
	
	destroyPokeballManagementWindow()
end

function openLockWindow()
	if lockWindow then
		lockWindow:destroy()
	end

	lockWindow = g_ui.createWidget('LockOptionsWidget', stashWindow)
	lockWindow:raise()
end

function closeLockWindow()
	if lockWindow then
		lockWindow:destroy()
		lockWindow = nil
	end
end

function confirmationLockWindowCleanup()
	if confirmationLockWindow then
		confirmationLockWindow:destroy()
		confirmationLockWindow = nil
	end
end

function clickOnLockButton(widget)
	if not widget then
		return
	end

	local number = tonumber(widget:getId())
	if not number then
		return
	end

	confirmationLockWindowCleanup()
	confirmationLockWindow = displayGeneralBox(tr('Confirm Lock'), tr('Are you sure you want to lock your Pokémon to %d days?', number), {
		{
			text = tr('Yes'),
			callback = confirmLockPokemon
		},
		{
			text = tr('No'),
			callback = confirmationLockWindowCleanup
		},
		anchor = AnchorHorizontalCenter
	}, confirmLockPokemon, confirmationLockWindowCleanup)
	confirmationLockWindow.lockDays = number
end

function confirmLockPokemon()
	if not confirmationLockWindow then
		return
	end

	local lockDays = confirmationLockWindow.lockDays
	if not lockDays or not tonumber(lockDays) then
		return
	end

	confirmationLockWindowCleanup()
	closeLockWindow()
	if not selectedPokemonName or not selectedPokeball or not lockDays or lockDays <= 0 then
		return
	end
	g_game.confirmLockDays(selectedPokeball, lockDays, selectedPokemonName)
end

function openEditName()
	if editNameWindow then
		editNameWindow:destroy()
	end

	editNameWindow = g_ui.createWidget('EditPokemonNameWidget', stashWindow)
	editNameWindow:raise()
	modules.game_walking.disableClientWalk()
end

function closeOpenEditName()
	if editNameWindow then
		editNameWindow:destroy()
		editNameWindow = nil
	end
	modules.game_walking.enableClientWalk()
end

function confirmEditName()
	if not editNameWindow then
		return
	end

	local text = editNameWindow.pokemonName:getText()
	if not text or text:len() < 3 then
		return
	end

	if not selectedPokemonName or not selectedPokeball then
		return
	end

	g_game.confirmNewPokeballName(selectedPokeball, text, selectedPokemonName)

	closeOpenEditName()
end

function sendConfirmCleanName()
	confirmationCleanWindowCleanup()
	confirmationCleanWindow = displayGeneralBox(tr('Confirm Clean Name'), tr('Are you sure you want to clean name of your Pokémon?'), {
		{
			text = tr('Yes'),
			callback = confirmCleanName
		},
		{
			text = tr('No'),
			callback = confirmationCleanWindowCleanup
		},
		anchor = AnchorHorizontalCenter
	}, confirmCleanName, confirmationCleanWindowCleanup)
	confirmationCleanWindow.lockDays = number
end

function confirmationCleanWindowCleanup()
	if confirmationCleanWindow then
		confirmationCleanWindow:destroy()
		confirmationCleanWindow = nil
	end
end

function confirmCleanName()
	if not confirmationCleanWindow then
		return
	end

	confirmationCleanWindowCleanup()

	if not selectedPokemonName or not selectedPokeball then
		return
	end

	g_game.cleanPokeballName(selectedPokeball, selectedPokemonName)
end

function onSendMoveItem(item, position, count)
	destroyPokeballManagementWindow()
end

function showAurasTab()
	if not stashWindow then return end
	checkUnsavedChanges(function()
		currentTab = "auras"
		
		stashWindow.optionPanel:setVisible(true)
		stashWindow.scrollableBar:setVisible(true)
		stashWindow.trainingPanel:setVisible(false)
		stashWindow.trainingScrollBar:setVisible(false)
		stashWindow.addonsPanel:setVisible(false)

		stashWindow.panelName:setText(tr("Auras"))

		local buttonsPanel = stashWindow.buttonsPanel
		buttonsPanel.auras:setImageSource('images/select_button_background')
		buttonsPanel.auras.auras_icon:setImageColor('white')
		buttonsPanel.training:setImageSource('images/button_background')
		buttonsPanel.training.training_icon:setImageColor('#999999')
		buttonsPanel.addons:setImageSource('images/button_background')
		buttonsPanel.addons.addons_icon:setImageColor('#999999')
	end)
end

function showTrainingTab()
	if not stashWindow then return end
	checkUnsavedChanges(function()
		currentTab = "training"
		
		stashWindow.optionPanel:setVisible(false)
		stashWindow.scrollableBar:setVisible(false)
		stashWindow.trainingPanel:setVisible(true)
		stashWindow.trainingScrollBar:setVisible(true)
		stashWindow.addonsPanel:setVisible(false)
		stashWindow.panelName:setText(tr("Training"))
		local buttonsPanel = stashWindow.buttonsPanel
		buttonsPanel.auras:setImageSource('images/button_background')
		buttonsPanel.auras.auras_icon:setImageColor('#999999')
		buttonsPanel.training:setImageSource('images/select_button_background')
		buttonsPanel.training.training_icon:setImageColor('white')
		buttonsPanel.addons:setImageSource('images/button_background')
		buttonsPanel.addons.addons_icon:setImageColor('#999999')
		
		-- Popular skills
		populateSkills()
	end)
end

function populateSkills()
	if not stashWindow or not stashWindow.trainingPanel then return end
	
	local trainingPanel = stashWindow.trainingPanel
	
	-- Limpar skills existentes de forma adequada
	local children = trainingPanel:getChildren()
	for i = #children, 1, -1 do
		local child = children[i]
		child:destroy()  -- Destruir explicitamente o widget
	end
	-- Adicionar skills em ordem fixa
	local skillOrder = {"attack", "criticaldamage", "criticalchance", "criticalresistance", "defense", "hp", "precision", "evasion"}
	
	for _, skillId in ipairs(skillOrder) do
		local skill = pokemonSkills[skillId]
		if skill then
			local skillWidget = g_ui.createWidget('SkillWidget', trainingPanel)
			skillWidget.skillNameAndLevel:setText(skill.name .. " Lv. " .. skill.level)
			skillWidget.skillPercent:setText(tostring(skill.percentage) .. "%")
			
			-- Calcular largura da barra de progresso
			local progressWidth = (skill.percentage / 100) * skillWidget.skillProgress:getWidth()
			skillWidget.skillProgress.progressFill:setWidth(progressWidth)

			-- Lock visual: cadeado fechado branco se locked, aberto cinza se unlocked
			if skill.locked then
				skillWidget.lockButton:setIcon('@fa solid 14 f023')
				skillWidget.lockButton:setIconColor('#ffffff')
				skillWidget.lockButton:setTooltip(tr("Locked: training will stop when this skill levels up."))
			else
				skillWidget.lockButton:setIcon('@fa solid 14 f09c')
				skillWidget.lockButton:setIconColor('#aaaaaa')
				skillWidget.lockButton:setTooltip(tr("Unlocked: click to lock. Training will stop when a locked skill levels up."))
			end

			-- onClick: envia toggle para o servidor
			local capturedSkillId = skillId
			skillWidget.lockButton.onClick = function()
				if selectedPokeball then
					g_game.toggleSkillLock(selectedPokeball, capturedSkillId)
				end
			end
		end
	end
end

function updateSkill(skillId, level, percentage)
	if pokemonSkills[skillId] then
		pokemonSkills[skillId].level = level
		pokemonSkills[skillId].percentage = percentage
		
		-- Atualizar interface se estiver na aba training
		if currentTab == "training" then
			populateSkills()
		end
	end
end

function showAddonsTab()
	if not stashWindow then return end
	checkUnsavedChanges(function()
		currentTab = "addons"
		stashWindow.optionPanel:setVisible(false)
		stashWindow.scrollableBar:setVisible(false)
		stashWindow.trainingPanel:setVisible(false)
		stashWindow.trainingScrollBar:setVisible(false)
		stashWindow.addonsPanel:setVisible(true)
		stashWindow.panelName:setText(tr("Addons"))
		local buttonsPanel = stashWindow.buttonsPanel
		buttonsPanel.auras:setImageSource('images/button_background')
		buttonsPanel.auras.auras_icon:setImageColor('#999999')
		buttonsPanel.training:setImageSource('images/button_background')
		buttonsPanel.training.training_icon:setImageColor('#999999')
		buttonsPanel.addons:setImageSource('images/select_button_background')
		buttonsPanel.addons.addons_icon:setImageColor('white')
		
		-- Popular addons
		populateAddons()
	end)
end

local selectedAddonOutfit
local selectedColorBox
local currentClotheButton
local colorBoxes = {}
local selectedOutfit

function populateAddons()
	if not stashWindow or not stashWindow.addonsPanel then return end
	

	selectedOutfit = {
		type = pokemonCurrentOutfit.type,
		head = pokemonCurrentOutfit.head,
		body = pokemonCurrentOutfit.body,
		legs = pokemonCurrentOutfit.legs,
		feet = pokemonCurrentOutfit.feet
	}

	initializeColorBoxes()
	initializeClotheButtons()
	populateAvailableAddons()
end

function initializeColorBoxes()
	local colorBoxPanel = stashWindow.addonsPanel.colorBoxPanel
	
	-- Limpar cores existentes de forma adequada
	colorBoxes = {}
	local children = colorBoxPanel:getChildren()
	for i = #children, 1, -1 do
		local child = children[i]
		child:destroy()  -- Destruir explicitamente o widget
	end
	
	-- Criar color boxes (7 linhas x 19 colunas = 133 cores)
	for j = 0, 6 do
		for i = 0, 18 do
			local colorBox = g_ui.createWidget('ColorBox', colorBoxPanel)
			local outfitColor = getOutfitColor(j * 19 + i)
			colorBox:setImageColor(outfitColor)
			colorBox:setId('colorBox' .. j * 19 + i)
			colorBox.colorId = j * 19 + i

			if j * 19 + i == selectedOutfit.head then
				selectedColorBox = colorBox
				colorBox:setChecked(true)
			end
			
			colorBox.onCheckChange = onColorCheckChange
			colorBoxes[#colorBoxes + 1] = colorBox
		end
	end
end

function initializeClotheButtons()
	local clotheButtons = stashWindow.addonsPanel.clotheButtons
	clotheButtons.head.onCheckChange = onClotheCheckChange
	clotheButtons.body.onCheckChange = onClotheCheckChange
	clotheButtons.legs.onCheckChange = onClotheCheckChange
	clotheButtons.feet.onCheckChange = onClotheCheckChange
	currentClotheButton = clotheButtons.head
	currentClotheButton:setColor('#03b1fc')
	currentClotheButton:setChecked(true)
end

function populateAvailableAddons()
	local availableAddons = stashWindow.addonsPanel.availableAddons
	
	-- Limpar addons existentes de forma adequada
	local children = availableAddons:getChildren()
	for i = #children, 1, -1 do
		local child = children[i]
		child:destroy()  -- Destruir explicitamente o widget
	end
	
	local widgets = {}
	local defaultWidget = g_ui.createWidget('CreatureAddonWidget', availableAddons)
	local defaultCreature = defaultWidget:getChildById('creature')
	defaultCreature:setOutfit(pokemonCurrentOutfit)
	defaultWidget:setTooltip(tr("Default (No Addon)"))
	defaultWidget.addonData = {name = "", lookType = pokemonCurrentOutfit.type}
	
	widgets[#widgets+1] = {name = "", widget = defaultWidget}
	
	defaultWidget.onMousePress = function(widget, mousePos, mouseButton)
		if mouseButton == MouseLeftButton then
			selectAddon(widget, {name = "", lookType = pokemonCurrentOutfit.type})
		end
	end
	
	-- Adicionar addons reais do servidor
	for addonName, addon in pairs(pokemonAddons) do
		local addonWidget = g_ui.createWidget('CreatureAddonWidget', availableAddons)
		local addonCreature = addonWidget:getChildById('creature')
		
		-- Criar outfit com o addon
		local addonOutfit = {
			type = addon.lookType,
			head = pokemonCurrentOutfit.head,
			body = pokemonCurrentOutfit.body,
			legs = pokemonCurrentOutfit.legs,
			feet = pokemonCurrentOutfit.feet
		}
		
		addonCreature:setOutfit(addonOutfit)
		addonWidget:setTooltip(addon.name)
		addonWidget.addonData = addon
		
		widgets[#widgets+1] = {name = addon.name, widget = addonWidget}
		
		if addon.unlocked then
			-- Addon desbloqueado - normal
			addonWidget:setOpacity(1.0)
			
			addonWidget.onMousePress = function(widget, mousePos, mouseButton)
				if mouseButton == MouseLeftButton then
					selectAddon(widget, addon)
				end
			end
		else
			-- Addon bloqueado - visual diferenciado
			addonWidget:setFocusable(false)
			addonWidget:setOpacity(0.4) -- Mais opaco
			local lockIcon = g_ui.createWidget('UIWidget', addonWidget)
			lockIcon:setSize({width = 16, height = 16})
			lockIcon:setImageSource('images/locked_icon')
			lockIcon:addAnchor(AnchorTop, 'parent', AnchorTop)
			lockIcon:addAnchor(AnchorRight, 'parent', AnchorRight)
			lockIcon:setMarginTop(2)
			lockIcon:setMarginRight(2)
			lockIcon:setPhantom(true)
			addonWidget:setTooltip(addon.name .. " (Locked)")
		end
	end
	
	-- Identificar qual widget deve estar selecionado
	local selectedWidget = defaultWidget
	for _, entry in ipairs(widgets) do
		if entry.name == selectedCurrentAddon then
			selectedWidget = entry.widget
			break
		end
	end
	
	-- Reorganizar widgets: remover todos e adicionar na ordem correta
	local children = availableAddons:getChildren()
	for i = #children, 1, -1 do
		availableAddons:removeChild(children[i])
	end
	
	for _, entry in ipairs(widgets) do
		availableAddons:addChild(entry.widget)
	end

	if selectedWidget then
		selectedWidget:setImageSource('images/pokemon_background_selected')
		selectedWidget:focus()
		if defaultWidget ~= selectedWidget then
			availableAddons:moveChildToIndex(selectedWidget, 2)
		end
	end
end

function onColorCheckChange(colorBox)
	if colorBox == selectedColorBox then
		colorBox.onCheckChange = nil
		colorBox:setChecked(true)
		colorBox.onCheckChange = onColorCheckChange
	else
		if selectedColorBox then
			selectedColorBox.onCheckChange = nil
			selectedColorBox:setChecked(false)
			selectedColorBox.onCheckChange = onColorCheckChange
		end
		selectedColorBox = colorBox

		if currentClotheButton:getId() == 'head' then
			selectedOutfit.head = selectedColorBox.colorId
		elseif currentClotheButton:getId() == 'body' then
			selectedOutfit.body = selectedColorBox.colorId
		elseif currentClotheButton:getId() == 'legs' then
			selectedOutfit.legs = selectedColorBox.colorId
		elseif currentClotheButton:getId() == 'feet' then
			selectedOutfit.feet = selectedColorBox.colorId
		end

		stashWindow.rightPanel.pokemonOutfit:setOutfit(selectedOutfit)
		
		-- Atualizar todos os addons com as novas cores
		local availableAddons = stashWindow.addonsPanel.availableAddons
		for i, child in ipairs(availableAddons:getChildren()) do
			local creature = child:getChildById('creature')
			if creature then
				local addonOutfit = creature:getOutfit()
				addonOutfit.head = selectedOutfit.head
				addonOutfit.body = selectedOutfit.body
				addonOutfit.legs = selectedOutfit.legs
				addonOutfit.feet = selectedOutfit.feet
				creature:setOutfit(addonOutfit)
			end
		end
		
		-- Marcar como alterado
		markAsChanged()
	end
end

function onClotheCheckChange(clotheButtonBox)
	if clotheButtonBox == currentClotheButton then
		clotheButtonBox.onCheckChange = nil
		clotheButtonBox:setChecked(true)
		clotheButtonBox.onCheckChange = onClotheCheckChange
	else
		currentClotheButton:setColor('#ffffff')
		currentClotheButton.onCheckChange = nil
		currentClotheButton:setChecked(false)
		currentClotheButton.onCheckChange = onClotheCheckChange
		
		currentClotheButton = clotheButtonBox
		currentClotheButton:setColor('#03b1fc')
		
		-- Obter colorId da parte do outfit correspondente
		local colorId = 0
		
		if currentClotheButton:getId() == 'head' then
			colorId = selectedOutfit.head
		elseif currentClotheButton:getId() == 'body' then
			colorId = selectedOutfit.body
		elseif currentClotheButton:getId() == 'legs' then
			colorId = selectedOutfit.legs
		elseif currentClotheButton:getId() == 'feet' then
			colorId = selectedOutfit.feet
		end
		
		-- Selecionar o colorBox correspondente
		local colorBoxPanel = stashWindow.addonsPanel.colorBoxPanel
		local targetColorBox = colorBoxPanel:recursiveGetChildById('colorBox' .. colorId)
		if targetColorBox then
			targetColorBox:setChecked(true)
		end
	end
end

function selectAddon(widget, addon)
	local availableAddons = stashWindow.addonsPanel.availableAddons
	local children = availableAddons:getChildren()
	for i = 1, #children do
		children[i]:setImageSource('images/pokemon_background')
	end
	
	-- Selecionar novo addon - aplicar imagem de selecionado
	widget:setImageSource('images/pokemon_background_selected')
	selectedAddonOutfit = addon
	selectedCurrentAddon = addon.name or ""
	markAsChanged()
	applyAddonToPokemon(addon)
end

function applyAddonToPokemon(addon)
	if not stashWindow or not stashWindow.rightPanel then return end
	local pokemonOutfit = stashWindow.rightPanel.pokemonOutfit
	if pokemonOutfit then
		selectedOutfit.type = addon.lookType or pokemonCurrentOutfit.type
		pokemonOutfit:setOutfit(selectedOutfit)
	end
end

function checkUnsavedChanges(callback)
	if hasUnsavedChanges then
		showConfirmDialog("You have unsaved changes. Do you want to save them?", function(result)
			if result == true then
				saveChanges(callback)
			elseif result == false then
				hasUnsavedChanges = false
				if callback then callback() end
			end
		end)
	else
		if callback then callback() end
	end
end

function showConfirmDialog(message, callback)
	if confirmDialog then
		confirmDialog:destroy()
		confirmDialog = nil
	end
	
	local buttons = {
		{
			text = "Save",
			callback = function()
				if confirmDialog then
					confirmDialog:destroy()
					confirmDialog = nil
				end
				callback(true)
			end
		},
		{
			text = "Discard",
			callback = function()
				if confirmDialog then
					confirmDialog:destroy()
					confirmDialog = nil
				end
				callback(false)
			end
		},
		{
			text = "Cancel",
			callback = function()
				if confirmDialog then
					confirmDialog:destroy()
					confirmDialog = nil
				end
				callback(nil)
			end
		},
		anchor = AnchorHorizontalCenter
	}
	
	confirmDialog = AllianceMessageBox.display("Unsaved Changes", message, buttons)
end

function saveChanges(callback)
	if currentTab == "addons" then
		saveAddonChanges(callback)
	elseif currentTab == "auras" then
		saveAuraChanges(callback)
	else
		if callback then callback() end
	end
end

function saveAddonChanges(callback)
	if not selectedPokeball then
		if callback then callback() end
		return
	end
	
	local currentOutfit = stashWindow.rightPanel.pokemonOutfit:getOutfit()
	g_game.changePokeballAddon(
		selectedPokeball,
		currentOutfit.type or 0,
		currentOutfit.head or 0,
		currentOutfit.body or 0,
		currentOutfit.legs or 0,
		currentOutfit.feet or 0,
		selectedCurrentAddon or ""
	)

	-- Atualizar estado original
	originalSelectedAddon = selectedCurrentAddon
	hasUnsavedChanges = false

	if callback then callback() end
end

function saveAuraChanges(callback)
	if not selectedPokeball then
		if callback then callback() end
		return
	end
	
	-- Para auras, usar o sistema original
	local auraWidget = stashWindow.optionPanel:getFocusedChild()
	if auraWidget and auraWidget.aura then
		g_game.confirmPokeballManagement(selectedPokeball, auraWidget.aura)
		originalSelectedAura = auraWidget.aura
	end
	
	hasUnsavedChanges = false
	if callback then callback() end
end

function markAsChanged()
	if currentTab == "addons" then
		hasUnsavedChanges = (selectedCurrentAddon ~= originalSelectedAddon)
	elseif currentTab == "auras" then
		local auraWidget = stashWindow and stashWindow.optionPanel and stashWindow.optionPanel:getFocusedChild()
		if auraWidget then
			local currentAura = auraWidget.aura or ""
			local originalAura = originalSelectedAura or ""
			hasUnsavedChanges = (currentAura ~= originalAura)
		end
	end
end

function onAuraSelected()
	markAsChanged()
end