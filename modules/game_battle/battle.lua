battleWindow = nil
battleButton = nil
battlePanel = nil
filterPanel = nil
toggleFilterButton = nil

mouseWidget = nil
updateEvent = nil

hoveredCreature = nil
newHoveredCreature = nil
prevCreature = nil

battleButtons = {}
local ageNumber = 1
local ages = {}

local hotkeyDelay = 200
local hotkeyDelayTo = 0

local HotkeyRegistry = modules.client_hotkeys.HotkeyRegistry

local filteredCreatures = {}

local FILTER_BUTTON_IDS = { 'hidePlayers', 'hideNPCs', 'hideMonsters', 'hideParty' }
local restoringFilters = false

local boundKeys = {
  chatEnabled = {},
  chatDisabled = {}
}

local boundKeysUI = {
  chatEnabled = {},
  chatDisabled = {}
}

modules.client_hotkeys.registerHotkeyCallback("BATTLELIST",
  function(actionName, action, keyInfo, chatState, keyType)
    if battleButton and keyType == "primaryKey" and chatState == "chatDisabled" then
      battleButton:setTooltip(tr("Battle (%s)", keyInfo.key))
    end
    local callback = function()
      if isChatStateCorrect(chatState == "chatEnabled") then
        if hotkeyDelayTo ~= nil and g_clock.millis() < hotkeyDelayTo then
          return
        end
        toggle()
        hotkeyDelayTo = g_clock.millis() + hotkeyDelay
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end,
  function(actionName, action, keyInfo, chatState, keyType, event)
    if event == "unbind" and battleButton then
      battleButton:setTooltip(tr("Battle"))
    end
  end)

modules.client_hotkeys.registerHotkeyCallback("SWITCH_TARGET",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      if isChatStateCorrect(chatState == "chatEnabled") then
        selectNextTarget()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

modules.client_hotkeys.registerHotkeyCallback("SWITCH_TARGET_BACKWARD",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      if isChatStateCorrect(chatState == "chatEnabled") then
        selectPreviousTarget()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

local sortOptions = {
    {label = "Name", value = 'name'},
    {label = "Distance", value = 'distance'},
    {label = "Screen age", value = 'screenage'},
    {label = "Health", value = 'health'}
}

function init()
  g_ui.importStyle('battlebutton')
  battleButton = modules.client_topmenu.addMiddleGameToggleButton('battleButton', tr('Battle'), '/images/ui/topbuttons/icons/battle', toggle, false, 2)
  battleButton:setOn(true)
  battleWindow = g_ui.loadUI('battle', modules.game_interface.getRightPanel())

  -- this disables scrollbar auto hiding
  local scrollbar = battleWindow:getChildById('miniwindowScrollBar')
  scrollbar:mergeStyle({ ['$!on'] = { }})

  battlePanel = battleWindow:recursiveGetChildById('battlePanel')

  filterPanel = battleWindow:recursiveGetChildById('filterPanel')
  toggleFilterButton = battleWindow:recursiveGetChildById('toggleFilterButton')

  restoreFilterStates()

  if isHidingFilters() then
    hideFilterPanel()
  end

  mouseWidget = g_ui.createWidget('UIButton')
  mouseWidget:setVisible(false)
  mouseWidget:setFocusable(false)
  mouseWidget.cancelNextRelease = false

  battleWindow:setContentMinimumHeight(80)
  battleWindow:setup()
  
  for i=1,30 do
    local battleButton = g_ui.createWidget('BattleButton', battlePanel)
    battleButton:setup()
    battleButton:hide()
    battleButton.onHoverChange = onBattleButtonHoverChange
    battleButton.onMouseRelease = onBattleButtonMouseRelease
    table.insert(battleButtons, battleButton)
  end
  
  updateBattleList()
  
  connect(LocalPlayer, {
    onPositionChange = onPlayerPositionChange
  })
  connect(Creature, {
    onAppear = updateSquare,
    onDisappear = updateSquare
  })  
  connect(g_game, { 
    onAttackingCreatureChange = updateSquare,
    onFollowingCreatureChange = updateSquare 
  })

end

function terminate()
  if battleButton == nil then
    return
  end
  
  battleButtons = {}

  battleButton:destroy()
  battleWindow:destroy()
  mouseWidget:destroy()
  
  disconnect(LocalPlayer, {
    onPositionChange = onPlayerPositionChange
  })
  disconnect(Creature, {
    onAppear = onCreatureAppear,
    onDisappear = onCreatureDisappear
  })  
  disconnect(g_game, { 
    onAttackingCreatureChange = updateSquare,
    onFollowingCreatureChange = updateSquare 
  })

  removeEvent(updateEvent)
end

function toggle()
  if battleButton:isOn() then
    battleWindow:close()
    battleButton:setOn(false)
  else
    battleWindow:open()
    battleButton:setOn(true)
  end
end

function updateHotkeyDelay(count)
  hotkeyDelay = count
end

function isChatStateCorrect(chatEnabled)
  local chatModeEnabled = not modules.game_chat.consoleToggleChat
  return (chatEnabled and chatModeEnabled) or (not chatEnabled and not chatModeEnabled)
end

function updateUIButton(chatState)
  local registryKeys = HotkeyRegistry:getBoundKeys("topMenuProfile")
  local battleKeys = registryKeys["BATTLELIST"]
  if battleKeys then
    local csData = battleKeys[chatState]
    if csData and csData.primaryKey then
      if battleButton then
        local tooltip = tr("Battle (%s)", tostring(csData.primaryKey.keyInfo.key))
        battleButton:setTooltip(tooltip)
      end
    end
  end
end

function createSortOptions()
  if not battleWindow then
    return
  end

  local menu = g_ui.createWidget("PopupMenu")
  menu:setGameMenu(true)
  local sortOption = isSortAsc() and 'Ascending Order' or 'Descending Order'
  menu:addOption(
      tr(sortOption),
      function()
          setSortOrder(isSortAsc() and 'desc' or 'asc')
      end
  )
  menu:addSeparator()
  local sortType = getSortType()
  for _, config in ipairs(sortOptions) do
    local selectLabel = (config.value == sortType)
    menu:addOption(
      tr(selectLabel and "Remove Order" or "Order by "..config.label),
      function()
          setSortType(selectLabel and 'age' or config.value)
      end
    )
  end

  menu:addSeparator()
  menu:addOption(
    tr(isTargetingNpcs() and "Don't target NPCs" or "Target NPCs"),
    function()
        modules.client_options.setOption('targetNpcs', not isTargetingNpcs())
    end
  )

  local position = battleWindow.filterPanel.buttons.showOptions:getPosition()
  position.y = position.y + battleWindow.filterPanel.buttons.showOptions:getHeight()
  menu:display(position)
end
function getSortType()
  local settings = g_settings.getNode('BattleList')
  if not settings then
    if g_app.isMobile() then
      return 'distance'
    else
      return 'age'
    end
  end
  return settings['sortType']
end

function setSortType(state)
  settings = {}
  settings['sortType'] = state
  g_settings.mergeNode('BattleList', settings)

  checkCreatures()
end

function getSortOrder()
  local settings = g_settings.getNode('BattleList')
  if not settings then
    return 'asc'
  end
  return settings['sortOrder']
end

function setSortOrder(state)
  settings = {}
  settings['sortOrder'] = state
  g_settings.mergeNode('BattleList', settings)

  checkCreatures()
end

function isSortAsc()
    return getSortOrder() == 'asc'
end

function isSortDesc()
    return getSortOrder() == 'desc'
end

function isTargetingNpcs()
  return modules.client_options.getOption('targetNpcs') == true
end

function isHidingFilters()
  local settings = g_settings.getNode('BattleList')
  if not settings then
    return false
  end
  return settings['hidingFilters']
end

function setHidingFilters(state)
  settings = {}
  settings['hidingFilters'] = state
  g_settings.mergeNode('BattleList', settings)
end

function getFilterState(id)
  local settings = g_settings.getNode('BattleList')
  if not settings then
    return nil
  end
  return settings[id]
end

function setFilterState(id, state)
  local settings = {}
  settings[id] = state
  g_settings.mergeNode('BattleList', settings)
  -- mergeNode alone only reaches disk on a clean exit; a crash would drop the
  -- filters again, which is the bug this persists in the first place.
  g_settings.save()
end

function onFilterChanged(button)
  if restoringFilters then
    return
  end

  setFilterState(button:getId(), button:isChecked())
  checkCreatures()
end

function restoreFilterStates()
  restoringFilters = true
  for _, id in ipairs(FILTER_BUTTON_IDS) do
    local saved = getFilterState(id)
    if saved ~= nil then
      filterPanel.buttons[id]:setChecked(saved)
    end
  end
  restoringFilters = false
end

function hideFilterPanel()
  filterPanel.originalHeight = filterPanel:getHeight()
  filterPanel:setHeight(0)
  setHidingFilters(true)
  filterPanel:setVisible(false)
end

function showFilterPanel()
  filterPanel:setHeight(filterPanel.originalHeight)
  setHidingFilters(false)
  filterPanel:setVisible(true)
end

function toggleFilterPanel()
  if filterPanel:isVisible() then
    hideFilterPanel()
  else
    showFilterPanel()
  end
end

function onChangeSortType(comboBox, option, value)
  setSortType(value:lower())
end

function onChangeSortOrder(comboBox, option, value)
  -- Replace dot in option name
  setSortOrder(value:lower():gsub('[.]', ''))
end

-- functions
function updateBattleList() 
  removeEvent(updateEvent)
  updateEvent = scheduleEvent(updateBattleList, 100)
  checkCreatures()
end

function prioritizeSummonOwns(creatures)
  local summonOwns = {}
  local otherCreatures = {}

  for _, creature in ipairs(creatures) do
    if creature:getType() == CreatureTypeSummonOwn then
      table.insert(summonOwns, creature)
    else
      table.insert(otherCreatures, creature)
    end
  end

  -- Concatenar summonOwns com outras criaturas
  local prioritizedCreatures = {}
  for _, summonOwn in ipairs(summonOwns) do
    table.insert(prioritizedCreatures, summonOwn)
  end
  for _, otherCreature in ipairs(otherCreatures) do
    table.insert(prioritizedCreatures, otherCreature)
  end

  return prioritizedCreatures
end

function checkCreatures()
  if not battlePanel or not g_game.isOnline() then
    return
  end

  local player = g_game.getLocalPlayer()
  if not player then
    return
  end
  
  local dimension = modules.game_interface.getMapPanel():getVisibleDimension()
  -- getPosition(true): em PokeView o centro da tela (e do battle) é o POKÉMON, não o treinador
  local spectators = g_map.getSpectatorsInRangeEx(player:getPosition(true), false, math.floor(dimension.width / 2), math.floor(dimension.width / 2), math.floor(dimension.height / 2), math.floor(dimension.height / 2))
  local maxCreatures = battlePanel:getChildCount()
  local haveOwnSummon = false
  local creatures = {}
  local now = g_clock.millis()
  local resetAgePoint = now - 250
  for _, creature in ipairs(spectators) do
    if creature:getType() == CreatureTypeSummonOwn or creature:getType() == CreatureTypeSummonOther or creature:canAttackCreature() then
      if doCreatureFitFilters(creature) and #creatures < maxCreatures then
        if not creature.lastSeen or creature.lastSeen < resetAgePoint then
          creature.screenAge = now        
        end      
        creature.lastSeen = now
        if not ages[creature:getId()] then
          if ageNumber > 1000 then
            ageNumber = 1
            ages = {}
          end
          ages[creature:getId()] = ageNumber
          ageNumber = ageNumber + 1
        end
        table.insert(creatures, creature) 
      end
    end
  end
  
  updateSquare()
  sortCreatures(creatures)
  battlePanel:getLayout():disableUpdates()

  filteredCreatures = {}

    -- sorting
    local ascOrder = isSortAsc()
    local creatures = prioritizeSummonOwns(creatures)
    for i=1,#creatures do  
      local creature = creatures[i]
      if ascOrder then
        creature = creatures[#creatures - i + 1]
      end
      local battleButton = battleButtons[i]      
      battleButton:creatureSetup(creature)
      battleButton:show()
      battleButton:setOn(true)

      if creature:getType() ~= CreatureTypeSummonOwn and creature:canAttackCreature() then
        table.insert(filteredCreatures, creature)
      end
    end

    if g_app.isMobile() and #creatures > 0 then
      onBattleButtonHoverChange(battleButtons[1], true)
    end
    
    for i=#creatures + 1,maxCreatures do
      if battleButtons[i]:isHidden() then break end
      battleButtons[i]:hide()
      battleButton:setOn(false)
    end

    battlePanel:getLayout():enableUpdates()
    battlePanel:getLayout():update()
  end

function doCreatureFitFilters(creature)
  if creature:isLocalPlayer() then
    return false
  end
  if creature:getHealthPercent() <= 0 then
    return false
  end

  local pos = creature:getPosition()
  if not pos then return false end

  local localPlayer = g_game.getLocalPlayer()
  -- getPosition(true): compara com o andar da CÂMERA (pokémon em PokeView), não do treinador
  if pos.z ~= localPlayer:getPosition(true).z or not creature:canBeSeen() then return false end

  local hidePlayers = filterPanel.buttons.hidePlayers:isChecked()
  local hideNPCs = filterPanel.buttons.hideNPCs:isChecked()
  local hideMonsters = filterPanel.buttons.hideMonsters:isChecked()
  local hideParty = filterPanel.buttons.hideParty:isChecked()

  if hidePlayers and creature:isPlayer() then
    return false
  elseif hideNPCs and creature:isNpc() then
    return false
  elseif hideMonsters and creature:isMonster() then
    return false
  elseif hideParty and creature:getShield() > ShieldWhiteBlue then
    return false
  end

  return true
end

local function getDistanceBetween(p1, p2)
    return math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y))
end

function sortCreatures(creatures)
  local player = g_game.getLocalPlayer()
  local sortType = getSortType()

  if sortType == 'distance' then
    local playerPos = player:getPosition(true) -- pokeview-aware: distância a partir da câmera
    local dist = {}
    local age = {}
    for i = 1, #creatures do
      local c = creatures[i]
      dist[c] = getDistanceBetween(playerPos, c:getPosition())
      age[c] = ages[c:getId()]
    end
    table.sort(creatures, function(a, b)
      if dist[a] == dist[b] then
        return age[a] > age[b]
      end
      return dist[a] > dist[b]
    end)
  elseif sortType == 'health' then
    local hp = {}
    local age = {}
    for i = 1, #creatures do
      local c = creatures[i]
      hp[c] = c:getHealthPercent()
      age[c] = ages[c:getId()]
    end
    table.sort(creatures, function(a, b)
      if hp[a] == hp[b] then
        return age[a] > age[b]
      end
      return hp[a] > hp[b]
    end)
  elseif sortType == 'age' then
    table.sort(creatures, function(a, b)
      local ageIdA = ages[a:getId()] or 0
      local ageIdB = ages[b:getId()] or 0
      return ageIdA > ageIdB
    end)
  elseif sortType == 'screenage' then
    table.sort(creatures, function(a, b) return a.screenAge > b.screenAge end)
  else -- name
    local name = {}
    local age = {}
    for i = 1, #creatures do
      local c = creatures[i]
      name[c] = c:getName():lower()
      age[c] = ages[c:getId()]
    end
    table.sort(creatures, function(a, b)
      local nameA = name[a]
      local nameB = name[b]

      if nameA == nameB then
        local ageA = age[a]
        local ageB = age[b]

        if not ageA and not ageB then
          return false
        elseif not ageA then
          return false
        elseif not ageB then
          return true
        else
          return ageA > ageB
        end
      end

      return nameA < nameB
    end)
  end
end

-- other functions
function onBattleButtonMouseRelease(self, mousePosition, mouseButton)
  if mouseWidget.cancelNextRelease then
    mouseWidget.cancelNextRelease = false
    return false
  end
  if not self.creature then
    return false
  end
  if ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton)
    or (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
    mouseWidget.cancelNextRelease = true
    g_game.look(self.creature, true)
    return true
  end
  if mouseButton ~= MouseLeftButton and mouseButton ~= MouseRightButton then
    return false
  end
  if g_keyboard.isShiftPressed() then
    g_game.look(self.creature, true)
    return true
  elseif g_keyboard.isCtrlPressed() then
    modules.game_interface.createThingMenu(mousePosition, nil, nil, self.creature)
    return true
  end
  if self.isTarget then
    g_game.cancelAttack()
  else
    g_game.attack(self.creature)
  end
  return true
end

function onBattleButtonHoverChange(battleButton, hovered)
  if not hovered then
    newHoveredCreature = nil    
  else
    newHoveredCreature = battleButton.creature
  end
  if battleButton.isHovered ~= hovered then
    battleButton.isHovered = hovered
    battleButton:update()
  end
  updateSquare()
end

function onPlayerPositionChange(creature, newPos, oldPos)
  addEvent(checkCreatures)
end

local CreatureButtonColors = {
  onIdle = {notHovered = '#888888', hovered = '#FFFFFF' },
  onTargeted = {notHovered = '#FF0000', hovered = '#FF8888' },
  onFollowed = {notHovered = '#00FF00', hovered = '#88FF88' }
}

function updateSquare()
  local following = g_game.getFollowingCreature()
  local attacking = g_game.getAttackingCreature()
    
  if newHoveredCreature == nil then
    if hoveredCreature ~= nil then
      hoveredCreature:hideStaticSquare()
      hoveredCreature = nil
    end
  else
    if hoveredCreature ~= nil then
      hoveredCreature:hideStaticSquare()
    end
    hoveredCreature = newHoveredCreature
    hoveredCreature:showStaticSquare(CreatureButtonColors.onIdle.hovered)
  end
  
  local color = CreatureButtonColors.onIdle
  local creature = nil
  if attacking then
    color = CreatureButtonColors.onTargeted
    creature = attacking
  elseif following then
    color = CreatureButtonColors.onFollowed
    creature = following
  end

  if prevCreature ~= creature then
    if prevCreature ~= nil then
      prevCreature:hideStaticSquare()
    end
    prevCreature = creature
  end
  
  if not creature then
    return
  end
  
  color = creature == hoveredCreature and color.hovered or color.notHovered
  creature:showStaticSquare(color)
end

local function getTargetCandidates()
  if isTargetingNpcs() then
    return filteredCreatures
  end

  local candidates = {}
  for _, creature in ipairs(filteredCreatures) do
    if not creature:isNpc() then
      table.insert(candidates, creature)
    end
  end
  return candidates
end

local function selectTargetByStep(step)
  if hotkeyDelayTo ~= nil and g_clock.millis() < hotkeyDelayTo then
    return
  end

  local candidates = getTargetCandidates()
  if #candidates == 0 then return end

  local attackingCreature = g_game.getAttackingCreature()
  local attackingId = attackingCreature and attackingCreature:getId()

  local target = step > 0 and candidates[1] or candidates[#candidates]
  if attackingId then
    for i, creature in ipairs(candidates) do
      if creature:getId() == attackingId then
        target = candidates[(i - 1 + step) % #candidates + 1]
        break
      end
    end
  end

  if not target then return end
  -- Only one valid target (or the next resolves to the current one): keep it,
  -- otherwise g_game.attack on the same creature toggles the target off.
  if attackingId and target:getId() == attackingId then return end

  g_game.attack(target)
  hotkeyDelayTo = g_clock.millis() + hotkeyDelay
end

function selectNextTarget()
  selectTargetByStep(1)
end

function selectPreviousTarget()
  selectTargetByStep(-1)
end


function onMiniWindowClose()
  battleButton:setOn(false)
end