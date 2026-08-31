-- Tracker (side panel)
local trackerWindow
local trackerList
local trackedPokemons = {}
local stopTrackingBox

-- Linked Task Tracker state
local linkedTaskSection
local linkedTaskPanel
local pokelogSection
local linkedTaskEntry = nil

function trackerInit()
  trackerWindow = g_ui.loadUI('pokelog_tracker', modules.game_interface.getRightPanel())
  trackerList = trackerWindow:recursiveGetChildById('trackerList')
  linkedTaskSection = trackerWindow:recursiveGetChildById('linkedTaskSection')
  linkedTaskPanel = trackerWindow:recursiveGetChildById('linkedTaskPanel')
  pokelogSection = trackerWindow:recursiveGetChildById('pokelogSection')

  trackerWindow:setup()

  connect(g_game, {
    onPokelogTrackerStart = onPokelogTrackerStart,
    onPokelogTrackerStop = onPokelogTrackerStop,
    onPokelogTrackerUpdateCount = onPokelogTrackerUpdateCount,
    onLinkedTaskTrackerStart = onLinkedTaskTrackerStart,
    onLinkedTaskTrackerStop = onLinkedTaskTrackerStop,
    onLinkedTaskTrackerUpdateCount = onLinkedTaskTrackerUpdateCount,
    onGameEnd = onTrackerGameEnd
  })
end

local function closeStopTrackingBox()
  if stopTrackingBox then
    stopTrackingBox:destroy()
    stopTrackingBox = nil
  end
end

local function confirmStopTracking(pokemonName)
  closeStopTrackingBox()

  local accept = function()
    closeStopTrackingBox()
    g_game.sendPokelogTrackerStop(pokemonName)
  end

  stopTrackingBox = displayAllianceBox(tr('Stop Tracking'),
    tr('Stop tracking %s?', pokemonName:toHumanCase()), {
      { text = tr('Confirm'), callback = accept },
      { text = tr('Cancel'), callback = closeStopTrackingBox },
      anchor = AnchorHorizontalCenter
    }, accept)
  stopTrackingBox:setupModal(closeStopTrackingBox)
end

function trackerTerminate()
  disconnect(g_game, {
    onPokelogTrackerStart = onPokelogTrackerStart,
    onPokelogTrackerStop = onPokelogTrackerStop,
    onPokelogTrackerUpdateCount = onPokelogTrackerUpdateCount,
    onLinkedTaskTrackerStart = onLinkedTaskTrackerStart,
    onLinkedTaskTrackerStop = onLinkedTaskTrackerStop,
    onLinkedTaskTrackerUpdateCount = onLinkedTaskTrackerUpdateCount,
    onGameEnd = onTrackerGameEnd
  })

  closeStopTrackingBox()

  if trackerWindow then
    trackerWindow:destroy()
    trackerWindow = nil
  end
end

function onTrackerGameEnd()
  closeStopTrackingBox()
  trackedPokemons = {}
  linkedTaskEntry = nil
  if trackerList then
    trackerList:destroyChildren()
  end
  if linkedTaskPanel then
    linkedTaskPanel:destroyChildren()
  end
  updateSectionVisibility()
end

function isTracked(pokemonName)
  return trackedPokemons[pokemonName:lower()] ~= nil
end

function getTrackedPokemons()
  return trackedPokemons
end

function onPokelogTrackerStart(pokemonName)
  local lowerName = pokemonName:lower()
  if trackedPokemons[lowerName] then return end

  trackedPokemons[lowerName] = true
  addTrackerEntry(pokemonName)
  updateSectionVisibility()

  -- Refresh pokélog list sorting if open
  if pokemonList and pokemonListPanel and pokemonListPanel:isVisible() then
    refreshPokemonListSort()
  end

  updateTrackerButton(pokemonName)
end

function onPokelogTrackerStop(pokemonName)
  local lowerName = pokemonName:lower()
  if not trackedPokemons[lowerName] then return end

  trackedPokemons[lowerName] = nil
  removeTrackerEntry(pokemonName)
  updateSectionVisibility()

  -- Refresh pokélog list sorting if open
  if pokemonList and pokemonListPanel and pokemonListPanel:isVisible() then
    refreshPokemonListSort()
  end

  updateTrackerButton(pokemonName)
end

function onPokelogTrackerUpdateCount(pokemonName, count)
  local lowerName = pokemonName:lower()
  if not trackedPokemons[lowerName] then return end

  updateTrackerEntryCount(pokemonName, count)
end

function addTrackerEntry(pokemonName)
  if not trackerList then return end

  local lowerName = pokemonName:lower()
  local entryId = 'tracker_' .. lowerName:gsub(' ', '_')

  -- Avoid duplicates
  if trackerList:getChildById(entryId) then return end

  local data = pokelogData[lowerName]
  local rewards = configCache[lowerName]

  local entry = g_ui.createWidget('PokelogTrackerEntry', trackerList)
  entry:setId(entryId)
  entry.pokemonName = pokemonName

  local creatureIcon = entry:getChildById('creatureIcon')
  if creatureIcon and data and data.lookType and data.lookType > 0 then
    creatureIcon:setOutfit({type = data.lookType})
  end

  local nameLabel = entry:getChildById('nameLabel')
  if nameLabel then
    nameLabel:setText(pokemonName:toHumanCase())
  end

  local progressLabel = entry:getChildById('progressLabel')
  if progressLabel then
    local count = data and data.count or 0
    local maxCount = 0
    if rewards and #rewards > 0 then
      maxCount = rewards[#rewards].count or 0
    end
    progressLabel:setText(count .. '/' .. maxCount)
  end

  local removeButton = entry:getChildById('removeButton')
  if removeButton then
    removeButton.onClick = function()
      confirmStopTracking(pokemonName)
    end
  end

  entry.onClick = function()
    if pokelogWindow and pokelogWindow:isVisible() then
      selectPokemon(pokemonName)
    end
  end
end

function removeTrackerEntry(pokemonName)
  if not trackerList then return end

  local lowerName = pokemonName:lower()
  local entryId = 'tracker_' .. lowerName:gsub(' ', '_')
  local entry = trackerList:getChildById(entryId)
  if entry then
    entry:destroy()
  end
end

function updateTrackerEntryCount(pokemonName, count)
  if not trackerList then return end

  local lowerName = pokemonName:lower()
  local entryId = 'tracker_' .. lowerName:gsub(' ', '_')
  local entry = trackerList:getChildById(entryId)
  if not entry then return end

  local progressLabel = entry:getChildById('progressLabel')
  if progressLabel then
    local rewards = configCache[lowerName]
    local maxCount = 0
    if rewards and #rewards > 0 then
      maxCount = rewards[#rewards].count or 0
    end
    progressLabel:setText(count .. '/' .. maxCount)
  end
end

function updateSectionVisibility()
  if not trackerWindow then return end

  local hasPokelogEntries = trackerList and trackerList:getChildCount() > 0
  local hasLinkedTask = linkedTaskEntry ~= nil

  if pokelogSection then
    pokelogSection:setVisible(hasPokelogEntries)
  end

  if linkedTaskSection then
    linkedTaskSection:setVisible(hasLinkedTask)
  end

  if hasPokelogEntries or hasLinkedTask then
    trackerWindow:open()
  end
end

-- Linked Task Tracker callbacks

function onLinkedTaskTrackerStart(taskId, taskName, monsterName, lookType, currentCount, requiredCount)
  if not linkedTaskPanel then return end

  -- Remove existing entry if any
  linkedTaskPanel:destroyChildren()

  local entry = g_ui.createWidget('LinkedTaskTrackerEntry', linkedTaskPanel)
  entry:setId('linkedTaskEntry')
  entry.taskId = taskId

  local creatureIcon = entry:getChildById('creatureIcon')
  if creatureIcon and lookType and lookType > 0 then
    creatureIcon:setOutfit({type = lookType})
  end

  local nameLabel = entry:getChildById('nameLabel')
  if nameLabel then
    nameLabel:setText(monsterName)
  end

  local progressLabel = entry:getChildById('progressLabel')
  if progressLabel then
    local remaining = (requiredCount or 0) - (currentCount or 0)
    if remaining < 0 then remaining = 0 end
    progressLabel:setText(remaining .. ' remaining')
  end

  linkedTaskEntry = entry
  updateSectionVisibility()
end

function onLinkedTaskTrackerStop()
  if linkedTaskPanel then
    linkedTaskPanel:destroyChildren()
  end
  linkedTaskEntry = nil
  updateSectionVisibility()
end

function onLinkedTaskTrackerUpdateCount(currentCount, requiredCount)
  if not linkedTaskEntry then return end

  local progressLabel = linkedTaskEntry:getChildById('progressLabel')
  if progressLabel then
    local remaining = (requiredCount or 0) - (currentCount or 0)
    if remaining < 0 then remaining = 0 end
    progressLabel:setText(remaining .. ' remaining')
  end
end

function onTrackerClose()
  if trackerWindow then
    trackerWindow:close()
  end
end

function openTracker()
  if trackerWindow then
    trackerWindow:open()
  end
end

function toggleTracker(pokemonName)
  local lowerName = pokemonName:lower()
  if trackedPokemons[lowerName] then
    g_game.sendPokelogTrackerStop(pokemonName)
  else
    g_game.sendPokelogTrackerStart(pokemonName)
  end
end
