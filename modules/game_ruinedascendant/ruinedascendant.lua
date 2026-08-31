local cancelConfirmWindow
local ascendantWindow
local selectedMegaStone = nil

function init()
  connect(g_game, {
    onGameEnd = onLogout,
    onItemUpdate = onAscendantItemUpdate,
  })
  connect(LocalPlayer, {
    onOpenRuinedAscendant = openRuinedAscendant,
  })
  initConversion()
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onLogout,
    onItemUpdate = onAscendantItemUpdate,
  })
  disconnect(LocalPlayer, {
    onOpenRuinedAscendant = openRuinedAscendant,
  })
  terminateConversion()
end

function applyMegaStoneFilters()
  if not ascendantWindow then
    return
  end
  local megaStonesPanel = ascendantWindow.megaStonePanel.megaStones
  if not megaStonesPanel then
    return
  end
  local searchText = ascendantWindow:recursiveGetChildById('searchText')
  local showAvailableButton = ascendantWindow:recursiveGetChildById('availableBackground')

  local searchLower = searchText and searchText:getText():lower() or ""
  local showingOnlyAvailable = showAvailableButton and not showAvailableButton.showingAll

  for _, child in pairs(megaStonesPanel:getChildren()) do
    local itemName = child:getTooltip():lower()
    local matchesSearch = searchLower == "" or itemName:find(searchLower, 1, true)
    local shouldShowBasedOnAvailability = not showingOnlyAvailable or child.hasItem
    if matchesSearch and shouldShowBasedOnAvailability then
      child:show()
    else
      child:hide()
    end
  end
end

function reorderMegaStones()
  if not ascendantWindow then
    return
  end
  local megaStonesPanel = ascendantWindow.megaStonePanel.megaStones
  if not megaStonesPanel then
    return
  end

  local children = megaStonesPanel:getChildren()
  table.sort(children, function(a, b)
    if (a.hasItem == true) ~= (b.hasItem == true) then
      return a.hasItem == true
    end
    return (a:getItemId() or 0) < (b:getItemId() or 0)
  end)

  megaStonesPanel:reorderChildren(children)
end

function onAscendantItemUpdate(itemId, count)
  if not ascendantWindow then
    return
  end
  local megaStonesPanel = ascendantWindow.megaStonePanel.megaStones
  if not megaStonesPanel then
    return
  end

  local found = false
  for _, child in pairs(megaStonesPanel:getChildren()) do
    if child:getItemId() == itemId then
      child.hasItem = count > 0
      child:setOpacity(count > 0 and 1 or 0.3)
      found = true
      break
    end
  end

  if found then
    reorderMegaStones()
    applyMegaStoneFilters()
  end
end

local banners = {
  ["sealed Audinite"] = "audino",
  ["sealed Venusaurite"] = "venusaur",
  ["sealed Charizardite X"] = "charizardX",
  ["sealed Charizardite Y"] = "charizardY",
  ["sealed Alakazite"] = "alakazam",
  ["sealed Gengarite"] = "gengar",
  ["sealed Kangaskhanite"] = "kangaskhan",
  ["sealed Gyaradosite"] = "gyarados",
  ["sealed Aerodactylite"] = "aerodactyl",
  ["sealed Ampharosite"] = "ampharos",
  ["sealed Scizorite"] = "scizor",
  ["sealed Blastoisinite"] = "blastoise",
  ["sealed Heracronite"] = "heracross",
  ["sealed Houndoominite"] = "houndoom",
  ["sealed Tyranitarite"] = "tyranitar",
  ["sealed Blazikenite"] = "blaziken",
  ["sealed Gardevoirite"] = "gardevoir",
  ["sealed Mawilite"] = "mawile",
  ["sealed Aggronite"] = "aggron",
  ["sealed Medichamite"] = "medicham",
  ["sealed Manectite"] = "manectric",
  ["sealed Banettite"] = "banette",
  ["sealed Absolite"] = "absol",
  ["sealed Lucarionite"] = "lucario",
  ["sealed Abomasite"] = "abomasnow",
  ["sealed Pidgeotite"] = "pidgeot",
  ["sealed Steelixite"] = "steelix",
  ["sealed Sceptilite"] = "sceptile",
  ["sealed Swampertite"] = "swampert",
  ["sealed Sablenite"] = "sableye",
  ["sealed Altaria"] = "altaria",
  ["sealed Glalitite"] = "glalie",
  ["sealed Salamencite"] = "salamence",
  ["sealed Metagrossite"] = "metagross",
  ["sealed Scolipite"] = "scolipede",
  ["sealed Dragalgite"] = "dragalge"
}

function openRuinedAscendant()
  if ascendantWindow then
    return
  end

  selectedMegaStone = nil
  ascendantWindow = g_ui.displayUI("ruinedascendant")
  local megaStones = g_thingDataManager.getMegaStones(true)
  
  -- Verificar quantidade de cada mega stone e adicionar ao array
  local megaStonesWithCount = {}
  for _, megaStone in ipairs(megaStones) do
    local count = modules.game_playeractionbar.getPlayerItemCount(megaStone.itemId)
    table.insert(megaStonesWithCount, {
      itemId = megaStone.itemId,
      name = megaStone.name,
      count = count
    })
  end
  
  -- Ordenar: primeiro as que o jogador possui (count > 0)
  table.sort(megaStonesWithCount, function(a, b)
    if (a.count > 0) ~= (b.count > 0) then
      return a.count > 0
    end
    return a.itemId < b.itemId
  end)
  
  -- Criar widgets com opacity baseado na posse do item
  for _, megaStone in ipairs(megaStonesWithCount) do
    local itemSlot = g_ui.createWidget('RuinedItemSlot', ascendantWindow.megaStonePanel.megaStones)
    itemSlot:setItemId(megaStone.itemId)
    itemSlot:setTooltip(megaStone.name)
    itemSlot:setFocusable(true)
    
    -- Aplicar opacity 0.5 se não tiver o item
    if megaStone.count == 0 then
      itemSlot:setOpacity(0.3)
      itemSlot.hasItem = false
    else
      itemSlot.hasItem = true
    end
    
    -- Ao clicar, mudar o banner e destacar o item
    itemSlot.onClick = function(widget)
      -- Remover destaque de todos os outros itens
      local megaStonesPanel = ascendantWindow.megaStonePanel.megaStones
      for _, child in ipairs(megaStonesPanel:getChildren()) do
        child:setBackgroundColor('#00000000')
      end
      
      -- Destacar o item clicado
      widget:setBackgroundColor('#ffffff40')
      
      -- Salvar a mega stone selecionada
      selectedMegaStone = {
        itemId = megaStone.itemId,
        name = megaStone.name
      }
      
      -- Mudar o banner
      local bannerWidget = ascendantWindow:getChildById('dungeonImage')
      local bannerName = banners[megaStone.name]
      if bannerName then
        bannerWidget:setImageSource('images/banners/' .. bannerName)
        bannerWidget:setOn(true)
      end
    end
  end
  
  -- Configurar botão "Start Dungeon"
  local startButton = ascendantWindow:recursiveGetChildById('startButton')
  if startButton then
    startButton.onClick = function()
      if not selectedMegaStone then
        modules.game_textmessage.displayGameMessage("Please select a Mega Stone first.")
        return
      end

      if not selectedMegaStone.itemId then
        modules.game_textmessage.displayGameMessage("Invalid Mega Stone selected.")
        return
      end

      showConfirmWindow(selectedMegaStone.name, selectedMegaStone.itemId)
    end
  end

  -- Configurar botão "Convert Stones"
  local convertButton = ascendantWindow:recursiveGetChildById('convertButton')
  if convertButton then
    convertButton.onClick = function()
      showConversionWindow()
    end
  end

  -- Configurar botão "Merit"
  local meritButton = ascendantWindow:recursiveGetChildById('meritButton')
  if meritButton then
    meritButton.onClick = function()
      showMeritWindow()
      g_game.requestRuinedMerit()
    end
  end

  -- Configurar botão "show only available"
  local showAvailableButton = ascendantWindow:recursiveGetChildById('availableBackground')
  if showAvailableButton then
    showAvailableButton.showingAll = true
    showAvailableButton.onClick = function()
      local megaStonesPanel = ascendantWindow.megaStonePanel.megaStones
      local searchText = ascendantWindow:recursiveGetChildById('searchText')
      local searchLower = searchText and searchText:getText():lower() or ""
      
      -- Alterna o estado
      showAvailableButton.showingAll = not showAvailableButton.showingAll
      
      -- Reaplica os filtros em todos os itens
      for _, child in ipairs(megaStonesPanel:getChildren()) do
        local itemName = child:getTooltip():lower()
        local matchesSearch = searchLower == "" or itemName:find(searchLower, 1, true)
        local shouldShowBasedOnAvailability = showAvailableButton.showingAll or child.hasItem
        
        -- Mostra o item apenas se passar pelos dois filtros
        if matchesSearch and shouldShowBasedOnAvailability then
          child:show()
        else
          child:hide()
        end
      end
    end
  end
  
  -- Configurar filtro de pesquisa
  local searchText = ascendantWindow:recursiveGetChildById('searchText')
  if searchText then
    searchText.onTextChange = function(widget, newText)
      local megaStonesPanel = ascendantWindow.megaStonePanel.megaStones
      local searchLower = newText:lower()
      local showAvailableButton = ascendantWindow:recursiveGetChildById('availableBackground')
      local showingOnlyAvailable = showAvailableButton and not showAvailableButton.showingAll
      
      for _, child in ipairs(megaStonesPanel:getChildren()) do
        local itemName = child:getTooltip():lower()
        local matchesSearch = searchLower == "" or itemName:find(searchLower, 1, true)
        local shouldShowBasedOnAvailability = not showingOnlyAvailable or child.hasItem
        
        -- Mostra o item apenas se passar pelos dois filtros
        if matchesSearch and shouldShowBasedOnAvailability then
          child:show()
        else
          child:hide()
        end
      end
    end
  end
  g_uistates.push(ascendantWindow)
end

function showConfirmWindow(megaStoneName, itemId)
  if cancelConfirmWindow then
    return
  end
  
  local yesCallback = function()
    g_game.startRuinedDungeon(itemId)
    hideConfirmWindow()
    hideAscendantWindow()
  end
  
  local noCallback = function()
    hideConfirmWindow()
  end
  
  local message = tr("Do you really want to start the Dungeon with the %s?", megaStoneName)
  cancelConfirmWindow = displayAllianceBox(tr('Confirm'), message, {
    {text=tr('Yes'), callback=yesCallback},
    {text=tr('No'), callback=noCallback},
    anchor=AnchorHorizontalCenter}, yesCallback, noCallback)
  g_uistates.push(cancelConfirmWindow)
end

function hideConfirmWindow()
  if cancelConfirmWindow then
    g_uistates.remove(cancelConfirmWindow)
    cancelConfirmWindow:destroy()
    cancelConfirmWindow = nil
  end
end

function hideAscendantWindow()
  hideConversionWindow()
  if ascendantWindow then
    g_uistates.remove(ascendantWindow)
    ascendantWindow:destroy()
    ascendantWindow = nil
    selectedMegaStone = nil
  end
end

function onLogout()
  hideConfirmWindow()
  hideConversionWindow()
  hideAscendantWindow()
  hideMeritWindow()
end