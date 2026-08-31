local trackerWindow
local trackerList
local trackedBrokes = {}
local stopTrackingBox

function brokesTrackerInit()
  trackerWindow = g_ui.loadUI('brokes_tracker', modules.game_interface.getRightPanel())
  trackerList = trackerWindow:recursiveGetChildById('trackerList')
  trackerWindow:setup()

  local copyAllButton = trackerWindow:recursiveGetChildById('copyAllButton')
  if copyAllButton then
    copyAllButton.onClick = copyTrackedBrokes
  end

  loadTrackedBrokes()
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
    removeBrokeFromTracker(pokemonName)
    updateTrackerStarInBrokes(pokemonName)
  end

  stopTrackingBox = displayAllianceBox(tr('Stop Tracking'),
    tr('Stop tracking brokes for %s?', pokemonName), {
      { text = tr('Confirm'), callback = accept },
      { text = tr('Cancel'), callback = closeStopTrackingBox },
      anchor = AnchorHorizontalCenter
    }, accept)
  stopTrackingBox:setupModal(closeStopTrackingBox)
end

function brokesTrackerTerminate()
  closeStopTrackingBox()

  if trackerWindow then
    trackerWindow:destroy()
    trackerWindow = nil
  end
end

function onTrackerClose()
  if trackerWindow then
    trackerWindow:close()
  end
end

function openBrokesTracker()
  if trackerWindow then
    trackerWindow:open()
  end
end

function copyTrackedBrokes()
  local names = {}
  for pokemonName in pairs(trackedBrokes) do
    if getPokemons()[pokemonName] then
      table.insert(names, pokemonName)
    end
  end

  if #names == 0 then
    modules.game_textmessage.displayFailureMessage(tr("No tracked Pokemon to copy"))
    return
  end

  table.sort(names)
  local blocks = {}
  for _, pokemonName in ipairs(names) do
    table.insert(blocks, formatPokemonBrokesText(pokemonName))
  end

  g_window.setClipboardText(table.concat(blocks, "\n\n"))
  modules.game_textmessage.displayStatusMessage(tr("Tracked brokes copied to clipboard"))
end

function loadTrackedBrokes()
  local saved = CharacterConfig.get("brokesTracker")
  if saved and type(saved) == "table" then
    trackedBrokes = saved
  else
    trackedBrokes = {}
  end
end

function saveTrackedBrokes()
  CharacterConfig.set("brokesTracker", trackedBrokes)
  CharacterConfig.save()
end

function isBrokeTracked(pokemonName)
  return trackedBrokes[pokemonName] == true
end

function toggleBrokeTracker(pokemonName)
  if isBrokeTracked(pokemonName) then
    removeBrokeFromTracker(pokemonName)
  else
    addBrokeToTracker(pokemonName)
  end
end

function addBrokeToTracker(pokemonName)
  if isBrokeTracked(pokemonName) then return end

  trackedBrokes[pokemonName] = true
  saveTrackedBrokes()
  addTrackerEntry(pokemonName)
  updateTrackerVisibility()
end

function removeBrokeFromTracker(pokemonName)
  if not isBrokeTracked(pokemonName) then return end

  trackedBrokes[pokemonName] = nil
  saveTrackedBrokes()
  removeTrackerEntry(pokemonName)
end

function addTrackerEntry(pokemonName)
  if not trackerList then return end

  local entryId = 'tracker_' .. pokemonName:lower():gsub(' ', '_')
  if trackerList:getChildById(entryId) then return end

  local pokemonData = getPokemons()[pokemonName]

  local entry = g_ui.createWidget('BrokesTrackerEntry', trackerList)
  entry:setId(entryId)

  local pokemonIcon = entry:getChildById('pokemonIcon')
  if pokemonIcon and pokemonData then
    local widgetId = string.format('%03d', pokemonData.id)
    if pokemonData.shinyId > 0 then
      widgetId = widgetId .. "." .. pokemonData.shinyId
    end
    pokemonIcon:setImageSource("/images/pokemons/" .. widgetId)
  end

  local nameLabel = entry:getChildById('nameLabel')
  if nameLabel then
    nameLabel:setText(pokemonName)
  end

  local countLabel = entry:getChildById('countLabel')
  if countLabel then
    local totalBrokes = 0
    if pokemonData and pokemonData.brokes then
      for _, count in pairs(pokemonData.brokes) do
        totalBrokes = totalBrokes + count
      end
    end
    countLabel:setText(tr("Total: %s", comma_value2(totalBrokes)))
  end

  local removeButton = entry:getChildById('removeButton')
  if removeButton then
    removeButton.onClick = function()
      confirmStopTracking(pokemonName)
    end
  end
end

function removeTrackerEntry(pokemonName)
  if not trackerList then return end

  local entryId = 'tracker_' .. pokemonName:lower():gsub(' ', '_')
  local entry = trackerList:getChildById(entryId)
  if entry then
    entry:destroy()
  end
end

function updateTrackerVisibility()
  if not trackerWindow then return end

  local hasEntries = trackerList and trackerList:getChildCount() > 0
  if hasEntries then
    trackerWindow:open()
  end
end

function refreshTrackerCounts()
  if not trackerList then return end

  for _, entry in ipairs(trackerList:getChildren()) do
    local nameLabel = entry:getChildById('nameLabel')
    if nameLabel then
      local pokemonName = nameLabel:getText()
      local pokemonData = getPokemons()[pokemonName]
      local countLabel = entry:getChildById('countLabel')
      if countLabel then
        local totalBrokes = 0
        if pokemonData and pokemonData.brokes then
          for _, count in pairs(pokemonData.brokes) do
            totalBrokes = totalBrokes + count
          end
        end
        countLabel:setText(tr("Total: %s", comma_value2(totalBrokes)))
      end
    end
  end
end

function rebuildTracker()
  if not trackerList then return end

  loadTrackedBrokes()
  trackerList:destroyChildren()

  for pokemonName, _ in pairs(trackedBrokes) do
    if getPokemons()[pokemonName] then
      addTrackerEntry(pokemonName)
    end
  end

  updateTrackerVisibility()
end

function updateTrackerStarInBrokes(pokemonName)
  local window = getBrokesWindow()
  if not window then return end
  local brokesPanel = window:getChildById("pokemonBrokesPanel")
  if not brokesPanel then return end

  for _, widget in ipairs(brokesPanel:getChildren()) do
    local nameWidget = widget.pokemonsInfo and widget.pokemonsInfo.pokemonName
    if nameWidget and nameWidget:getText() == pokemonName then
      local trkBtn = widget.pokemonsInfo.trackerButton
      if trkBtn then
        if isBrokeTracked(pokemonName) then
          trkBtn:setIconColor("#55bbff")
          trkBtn:setTooltip(tr('Stop tracking brokes'))
        else
          trkBtn:setIconColor("#666666")
          trkBtn:setTooltip(tr('Track brokes'))
        end
      end
      break
    end
  end
end

function onBrokesTrackerGameEnd()
  closeStopTrackingBox()
  trackedBrokes = {}
  if trackerList then
    trackerList:destroyChildren()
  end
end
