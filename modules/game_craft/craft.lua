-- Craft (cliente)
-- Substituiu extended opcode 91 pelo opcode dedicado 1556. O servidor envia:
--   - catalogo (workshop + recipes)         -> onCraftCatalog
--   - progresso dos crafts ativos do player -> onCraftProgress
--   - refresh single (apos craft/collect)   -> onCraftRefresh

local MainWindow, CreateWindow
local CraftListPanel
local CraftItemCreate, CraftItemCollect

local activeWorkshopId = nil
local activeWorkshopName = nil
local activeRecipes = {}            -- recipeId -> recipe (do servidor)
local recipesByCategory = {}        -- category -> list of recipes
local activeProgress = {}           -- recipeId -> { craftedAmount, collectedAmount, startedAt }
local depotStashCounts = {}         -- clientId -> count (do depot stash, vem do server no progress)
local currentCategory = nil
local currentRecipeId = nil         -- ultima receita focada (sobrevive a CreateWindow roubando o foco)
local progressTickEvent = nil

local function compatItemInfo(recipe)
	-- Adapta o `recipe` do novo protocolo pra estrutura usada pelo OTUI
	-- antigo (`INFO.itemid` em vez de `outputClientId`, etc.).
	local recipeList = {}
	for _, ing in ipairs(recipe.ingredients) do
		table.insert(recipeList, { ing.itemId, ing.count, "" })
	end
	return {
		id          = recipe.id,
		category    = recipe.category,
		itemid      = recipe.outputClientId,
		qnt         = recipe.outputQnt,
		name        = recipe.name,
		desc        = recipe.description,
		recipe      = recipeList,
		timePerUnit = recipe.timePerUnit,
	}
end

local function getProgress(recipeId)
	local p = activeProgress[recipeId]
	if not p then return 0, 0, 0 end
	local recipe = activeRecipes[recipeId]
	local timePerUnit = recipe and recipe.timePerUnit or 1
	if timePerUnit < 1 then timePerUnit = 1 end
	local elapsed = os.time() - p.startedAt
	if elapsed < 0 then elapsed = 0 end
	local ready = math.floor(elapsed / timePerUnit)
	if ready > p.craftedAmount then ready = p.craftedAmount end
	local collectable = ready - p.collectedAmount
	if collectable < 0 then collectable = 0 end
	return ready, collectable, p.craftedAmount
end

local function getRemainingSeconds(recipeId)
	local p = activeProgress[recipeId]
	if not p then return 0 end
	local recipe = activeRecipes[recipeId]
	local timePerUnit = recipe and recipe.timePerUnit or 1
	if timePerUnit < 1 then timePerUnit = 1 end
	local elapsed = os.time() - p.startedAt
	if elapsed < 0 then elapsed = 0 end
	local total = p.craftedAmount * timePerUnit
	local remaining = total - elapsed
	if remaining < 0 then remaining = 0 end
	return remaining
end

-- formatRemaining is provided by corelib/util.lua as formatCompactDuration
local formatRemaining = formatCompactDuration

function init()
	connect(g_game, {
		onGameEnd = onGameEnd,
		onWalk = onWalk,
		onAutoWalk = onWalk,
		onCraftCatalog  = onCraftCatalog,
		onCraftProgress = onCraftProgress,
		onCraftRefresh  = onCraftRefresh,
	})

	MainWindow = g_ui.loadUI("craft", modules.game_interface.getRootPanel())
	CraftListPanel = MainWindow:getChildById("craftListPanel")
	connect(CraftListPanel, {
		onChildFocusChange = function(self, focusedChild, unfocusedChild, reason)
			if focusedChild == nil then return end
			updateCraftPanel(self, focusedChild, unfocusedChild, reason)
		end
	})

	CraftItemCreate = MainWindow:getChildById("craftItemCreate")
	CraftItemCollect = MainWindow:getChildById("craftItemCollect")
	MainWindow:hide()

	CreateWindow = g_ui.createWidget("CreateWindow", MainWindow)
	for slot = 1, 16 do
		local recipeItem = g_ui.createWidget("NewUIItem", CreateWindow:getChildById("recipe"))
		recipeItem:setId(slot)
	end
	CreateWindow:hide()
end

function terminate()
	disconnect(g_game, {
		onGameEnd = onGameEnd,
		onWalk = onWalk,
		onAutoWalk = onWalk,
		onCraftCatalog  = onCraftCatalog,
		onCraftProgress = onCraftProgress,
		onCraftRefresh  = onCraftRefresh,
	})
	stopProgressTick()
	-- CreateWindow is a child of MainWindow, so destroying MainWindow takes it with it.
	if MainWindow then MainWindow:destroy() end
	MainWindow = nil
	CreateWindow = nil
end

function onGameEnd()
	hide()
end

function onWalk()
	hide()
end

function hide()
	stopProgressTick()
	currentRecipeId = nil
	if MainWindow then MainWindow:setVisible(false) end
	if CreateWindow then CreateWindow:hide() end
end

function startProgressTick()
	stopProgressTick()
	progressTickEvent = cycleEvent(function()
		if not MainWindow:isVisible() then return end
		for _, child in ipairs(CraftListPanel:getChildren()) do
			refreshItemProgressLabel(child)
		end
		refreshActionButtons()
	end, 1000)
end

function stopProgressTick()
	if progressTickEvent then
		removeEvent(progressTickEvent)
		progressTickEvent = nil
	end
end

function refreshItemProgressLabel(craftItemWidget)
	local recipeId = craftItemWidget.recipeId
	if not recipeId then return end
	local ready, collectable, total = getProgress(recipeId)
	local progressBg = craftItemWidget:getChildById("progressBg")
	local clockLabel = craftItemWidget:getChildById("clockLabel")
	local recipe = activeRecipes[recipeId]
	local timePerUnit = (recipe and recipe.timePerUnit) or 1

	if total <= 0 then
		if progressBg then progressBg:setVisible(false) end
		if clockLabel then clockLabel:setText(formatRemaining(timePerUnit)) end
		return
	end

	if clockLabel then
		local remaining = getRemainingSeconds(recipeId)
		clockLabel:setText(remaining > 0 and formatRemaining(remaining) or tr("Done"))
	end

	if not progressBg then return end
	progressBg:setVisible(true)

	local progressFill = progressBg:getChildById("progressFill")
	local progressText = progressBg:getChildById("progressText")
	if progressFill then
		local fillWidth = math.floor((progressBg:getWidth() * ready) / total)
		if fillWidth <= 0 then
			progressFill:setVisible(false)
		else
			progressFill:setVisible(true)
			progressFill:setWidth(math.max(fillWidth, 20))
		end
	end
	if progressText then
		progressText:setText(string.format("%d(%d) / %d", ready, collectable, total))
	end
end

function refreshActionButtons()
	if not CraftItemCreate or not CraftItemCollect then return end
	if not currentRecipeId then
		CraftItemCreate:setEnabled(false)
		CraftItemCollect:setEnabled(false)
		return
	end
	CraftItemCreate:setEnabled(true)
	local _, collectable = getProgress(currentRecipeId)
	CraftItemCollect:setEnabled(collectable > 0)
end

-- ============================================================================
-- Catalogo / progress
-- ============================================================================

function onCraftCatalog(workshop)
	activeWorkshopId = workshop.id
	activeWorkshopName = workshop.name
	activeRecipes = {}
	recipesByCategory = {}
	for _, recipe in ipairs(workshop.recipes) do
		activeRecipes[recipe.id] = recipe
		local cat = (recipe.category ~= "" and recipe.category) or "default"
		recipesByCategory[cat] = recipesByCategory[cat] or {}
		table.insert(recipesByCategory[cat], recipe)
	end

	-- Mostra o painel lateral apenas quando ha MULTIPLAS categorias (caso do
	-- Boost Stone com bug/fire/etc.). Workshops com so 1 categoria - Easter,
	-- Halloween, ou os de categoria default tipo Kurt - nao precisam do
	-- filtro lateral.
	local categoryCount = 0
	for _ in pairs(recipesByCategory) do categoryCount = categoryCount + 1 end
	updateCategoryPanelVisibility(categoryCount > 1)

	local firstCat
	for cat in pairs(recipesByCategory) do
		if not firstCat or cat < firstCat then firstCat = cat end
	end

	selectTypeToDraw(firstCat or "default")
	MainWindow:show()
	startProgressTick()
end

function updateCategoryPanelVisibility(hasCategories)
	local elementListPanel = MainWindow:getChildById("elementListPanel")
	local craftListPanel = MainWindow:getChildById("craftListPanel")
	if elementListPanel then
		elementListPanel:setVisible(hasCategories)
	end
	-- O craftListPanel tinha margin-left: 100 pra abrir espaço pro painel
	-- lateral. Quando o painel some, encosta na borda esquerda.
	if craftListPanel then
		craftListPanel:setMarginLeft(hasCategories and 100 or 20)
	end
end

function onCraftProgress(progress)
	if progress.workshopId ~= activeWorkshopId then return end
	activeProgress = {}
	local now = os.time()
	for _, entry in ipairs(progress.entries) do
		activeProgress[entry.recipeId] = {
			craftedAmount   = entry.craftedAmount,
			collectedAmount = entry.collectedAmount,
			startedAt       = now - entry.elapsedSeconds,
		}
	end
	depotStashCounts = {}
	if progress.stash then
		for _, s in ipairs(progress.stash) do
			depotStashCounts[s.clientId] = s.count
		end
	end
	-- Reordena: o catálogo chegou antes de activeProgress, então a primeira
	-- ordenação não conhecia os crafts em andamento. Agora que sabemos, sobe
	-- as receitas ativas pro topo.
	reorderCurrentList()
end

function onCraftRefresh(refresh)
	if refresh.workshopId ~= activeWorkshopId then return end
	if refresh.cleared then
		activeProgress[refresh.recipeId] = nil
	else
		local now = os.time()
		activeProgress[refresh.recipeId] = {
			craftedAmount   = refresh.craftedAmount,
			collectedAmount = refresh.collectedAmount,
			startedAt       = now - refresh.elapsedSeconds,
		}
	end
	if MainWindow:isVisible() and CreateWindow then CreateWindow:hide() end

	reorderCurrentList()
end

-- ============================================================================
-- UI: lista por categoria
-- ============================================================================

function selectTypeToDraw(category, preserveFocusId)
	if not CraftListPanel then return end
	CraftListPanel:destroyChildren()
	if CreateWindow then CreateWindow:hide() end
	currentCategory = category
	currentRecipeId = nil

	local list = recipesByCategory[category]
	if not list then return end

	table.sort(list, function(a, b)
		local aActive = activeProgress[a.id] ~= nil
		local bActive = activeProgress[b.id] ~= nil
		if aActive ~= bActive then return aActive end
		return a.id < b.id
	end)

	local firstWidget, restoredFocus
	for displayIndex, recipe in ipairs(list) do
		local itemWidget = g_ui.createWidget("NewCraftItemWidget", CraftListPanel)
		itemWidget:setId(tostring(recipe.id))
		itemWidget.recipeId = recipe.id
		drawItemInList(itemWidget, recipe, displayIndex)
		refreshItemProgressLabel(itemWidget)
		if displayIndex == 1 then firstWidget = itemWidget end
		if preserveFocusId and recipe.id == preserveFocusId then restoredFocus = itemWidget end
	end
	local target = restoredFocus or firstWidget
	if target then
		target:focus()
		target:setImageSource("/images/newui/background_popup")
		currentRecipeId = target.recipeId
	end
	refreshActionButtons()
end

function reorderCurrentList()
	if not currentCategory or not MainWindow:isVisible() then return end
	selectTypeToDraw(currentCategory, currentRecipeId)
end

function drawItemInList(craftItemWidget, recipe, displayIndex)
	local INFO = compatItemInfo(recipe)
	craftItemWidget.INFO = INFO

	craftItemWidget:getChildById("item"):setItemId(INFO.itemid)
	craftItemWidget:getChildById("item"):setItemCount(INFO.qnt)
	craftItemWidget:getChildById("item"):setTooltip(((INFO.qnt or 1) > 1 and " " .. INFO.qnt .. "x " or "") .. INFO.name)
	craftItemWidget:getChildById("desc"):setText(INFO.desc)
	craftItemWidget:getChildById("clockLabel"):setText(formatRemaining(INFO.timePerUnit or 1))

	local recipePanel = craftItemWidget:getChildById("recipe")
	recipePanel:destroyChildren()
	for _, ing in ipairs(INFO.recipe) do
		local recipeItem = g_ui.createWidget("NewUIItem", recipePanel)
		recipeItem:setItemId(ing[1])
		recipeItem:setItemCount(ing[2])
		recipeItem:setVirtual(true)
	end
end

function updateCraftPanel(self, focusedChild, unfocusedChild, reason)
	if focusedChild then
		focusedChild:setImageSource("/images/newui/background_popup")
		currentRecipeId = focusedChild.recipeId
	end
	if unfocusedChild then
		unfocusedChild:setImageSource("/images/newui/background_3")
	end
	refreshActionButtons()
end

-- ============================================================================
-- UI: criar / coletar
-- ============================================================================

local function getCurrentInfo()
	if not currentRecipeId or not CraftListPanel then return nil end
	local widget = CraftListPanel:getChildById(tostring(currentRecipeId))
	if not widget then return nil end
	return widget.INFO
end

local function getMaxCraftableByMaterials(INFO)
	local player = g_game.getLocalPlayer()
	if not player then return 1 end
	local maxAmount = math.huge
	for _, ing in ipairs(INFO.recipe) do
		local need = ing[2]
		if need and need > 0 then
			local clientId = ing[1]
			local have = (player:getItemCount(clientId) or 0) + (depotStashCounts[clientId] or 0)
			local possible = math.floor(have / need)
			if possible < maxAmount then maxAmount = possible end
		end
	end
	if maxAmount == math.huge then maxAmount = 1 end
	return math.max(1, maxAmount)
end

local function updateCreateWindowTotals(INFO, qntValue)
	local totalUnits = INFO.qnt * qntValue
	local totalUnitsText
	if INFO.qnt > 1 then
		totalUnitsText = qntValue .. " (" .. totalUnits .. "x)"
	else
		totalUnitsText = tostring(totalUnits)
	end
	local totalSeconds = qntValue * (INFO.timePerUnit or 1)
	CreateWindow:getChildById("labelTotal"):setText(
		tr("Total units") .. ": " .. totalUnitsText ..
		"\n" .. tr("Total time") .. ": " .. formatRemaining(totalSeconds))
end

function showCreateWindow()
	local INFO = getCurrentInfo()
	if not INFO then return end

	local maxAmount = getMaxCraftableByMaterials(INFO)
	local spinbox = CreateWindow.qntSpinner.field
	spinbox.onValueChange = function() refreshCreateWindow() end
	spinbox:setMinimum(1)
	spinbox:setMaximum(maxAmount)
	spinbox:setValue(1)

	CreateWindow:getChildById("item"):setItemId(INFO.itemid)
	CreateWindow:getChildById("item"):setTooltip((INFO.qnt > 1 and " (" .. INFO.qnt .. "x)" or "") .. INFO.name)
	CreateWindow:getChildById("name"):setText(INFO.name)
	updateCreateWindowTotals(INFO, 1)
	for slot = 1, 16 do
		local recipeItem = CreateWindow:getChildById("recipe"):getChildById(slot)
		local ingredient = INFO.recipe[slot]
		recipeItem:setItemId(ingredient and ingredient[1] or 0)
		recipeItem:setItemCount(ingredient and ingredient[2] or 0)
	end
	CreateWindow:show()
	CreateWindow:focus()
	CreateWindow:raise()
	spinbox:focus()
end

function refreshCreateWindow()
	local INFO = getCurrentInfo()
	if not INFO then return end
	local qntValue = CreateWindow.qntSpinner.field:getValue()
	updateCreateWindowTotals(INFO, qntValue)
	for index, ing in ipairs(INFO.recipe) do
		local recipeItem = CreateWindow:getChildById("recipe"):getChildById(index)
		recipeItem:setItemCount(qntValue * ing[2])
	end
end

function doCreateItem()
	if not currentRecipeId or not activeWorkshopId then return end
	local qnt = tonumber(CreateWindow.qntSpinner.field:getValue()) or 1
	if qnt < 1 then return end
	g_game.craftStart(activeWorkshopId, currentRecipeId, qnt)
end

function collectItemCraft()
	if not currentRecipeId or not activeWorkshopId then return end
	g_game.craftCollect(activeWorkshopId, currentRecipeId)
end
