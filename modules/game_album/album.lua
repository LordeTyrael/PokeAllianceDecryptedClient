local albumWindow
local searchEdit
local pageLabel
local prevArrow
local nextArrow
local collectProgress
local progressLabel
local emptyState
local sortButton
local filterButtons = {}
local cells = {}
local detailWindow
local albumState
local albumStateIndex

local PER_PAGE = 8
local SORT_MODES = { 'index', 'name', 'owned' }
local SORT_LABEL = { index = '1-N', name = 'A-Z', owned = '*1' }
local UNLOCK_SOUND = '/sounds/actions/achievement_unlocked.ogg'

local currentPage = 1
local totalPages = 1
local currentFilterMode = 'all'
local currentSortMode = 'index'
local viewList = {}
local albumData = {}
local newlyUnlocked = {}
local hasReceivedRealData = false
local lastOwnedCount = 0

local function cardImageFor(index)
  local card = AlbumCards[index]
  return card and card.image or ''
end

local function buildPlaceholder()
  albumData = {}
  for i, card in ipairs(AlbumCards) do
    albumData[i] = { name = card.name, unlocked = false }
  end
end

local function countOwned()
  local owned = 0
  for i = 1, #albumData do
    if albumData[i].unlocked then owned = owned + 1 end
  end
  return owned
end

function init()
  connect(g_game, {
    onGameEnd = offline,
    onAlbumData = onAlbumData,
    onAlbumRankingData = onAlbumRankingData,
  })

  albumWindow = g_ui.loadUI('album', modules.game_interface.getRootPanel())
  albumWindow:hide()

  searchEdit = albumWindow:getChildById('searchEdit')
  pageLabel = albumWindow:getChildById('pageLabel')
  prevArrow = albumWindow:getChildById('prevArrow')
  nextArrow = albumWindow:getChildById('nextArrow')
  collectProgress = albumWindow:getChildById('collectProgress')
  progressLabel = albumWindow:getChildById('progressLabel')
  emptyState = albumWindow:getChildById('emptyState')
  sortButton = albumWindow:getChildById('sortButton')
  filterButtons = {
    all = albumWindow:getChildById('filterAll'),
    owned = albumWindow:getChildById('filterOwned'),
    missing = albumWindow:getChildById('filterMissing'),
  }
  for i = 1, PER_PAGE do
    cells[i] = albumWindow:getChildById('card' .. i)
  end
  searchEdit.onTextChange = onSearchTextChange

  buildPlaceholder()
  updateFilterButtons()
  updateSortButton()
  rebuildViewList('')
  refreshProgress()
end

function terminate()
  disconnect(g_game, {
    onGameEnd = offline,
    onAlbumData = onAlbumData,
    onAlbumRankingData = onAlbumRankingData,
  })
  terminateRanking()

  if detailWindow then detailWindow:destroy() detailWindow = nil end
  if albumWindow then albumWindow:destroy() albumWindow = nil end
  cells = {}
  filterButtons = {}
  viewList = {}
  albumData = {}
  newlyUnlocked = {}
end

function offline()
  -- drop the previous character's state so a relog never shows their album/view prefs
  hasReceivedRealData = false
  newlyUnlocked = {}
  lastOwnedCount = 0
  currentFilterMode = 'all'
  currentSortMode = 'index'
  currentPage = 1
  if searchEdit then searchEdit:setText('') end
  buildPlaceholder()
  updateFilterButtons()
  updateSortButton()
  rebuildViewList('')
  refreshProgress()
  close()
  closeDetail()
  clearRanking()
end

function setFilter(mode)
  currentFilterMode = mode
  currentPage = 1
  updateFilterButtons()
  rebuildViewList(searchEdit:getText())
end

function updateFilterButtons()
  for mode, btn in pairs(filterButtons) do
    btn:setOn(mode == currentFilterMode)
  end
end

function cycleSort()
  local i = table.find(SORT_MODES, currentSortMode) or 1
  currentSortMode = SORT_MODES[(i % #SORT_MODES) + 1]
  currentPage = 1
  updateSortButton()
  rebuildViewList(searchEdit:getText())
end

function updateSortButton()
  if sortButton then
    sortButton:setText(SORT_LABEL[currentSortMode])
    sortButton:setTooltip(tr('Sort order'))
  end
end

function rebuildViewList(filter)
  filter = (filter or ''):lower()
  viewList = {}
  for i, entry in ipairs(albumData) do
    local owned = entry.unlocked
    local modeOk = currentFilterMode == 'all'
      or (currentFilterMode == 'owned' and owned)
      or (currentFilterMode == 'missing' and not owned)
    local textOk = filter == '' or string.find(entry.name:lower(), filter, 1, true) ~= nil
    if modeOk and textOk then
      table.insert(viewList, { idx = i, name = entry.name, unlocked = owned })
    end
  end

  if currentSortMode == 'name' then
    table.sort(viewList, function(a, b) return a.name:lower() < b.name:lower() end)
  elseif currentSortMode == 'owned' then
    table.sort(viewList, function(a, b)
      if a.unlocked ~= b.unlocked then return a.unlocked end
      return a.idx < b.idx
    end)
  end

  totalPages = math.max(math.ceil(#viewList / PER_PAGE), 1)
  if currentPage > totalPages then currentPage = totalPages end
  if currentPage < 1 then currentPage = 1 end
  renderSpread()
end

local function emptyMessage()
  if searchEdit:getText() ~= '' then
    return tr('No cards match your search')
  elseif currentFilterMode == 'owned' then
    return tr('No stickers collected yet')
  elseif currentFilterMode == 'missing' then
    return tr('Album complete!')
  end
  return tr('No cards match your search')
end

function renderSpread()
  local empty = (#viewList == 0)
  emptyState:setVisible(empty)
  if empty then emptyState:setText(emptyMessage()) end
  prevArrow:setVisible(not empty)
  nextArrow:setVisible(not empty)
  pageLabel:setVisible(not empty)

  local start = (currentPage - 1) * PER_PAGE
  for k = 1, PER_PAGE do
    local cell = cells[k]
    local entry = viewList[start + k]
    if entry and not empty then
      local owned = entry.unlocked
      cell:show()
      cell.cardIndex = entry.idx
      cell:setOpacity(owned and 1 or 0.6)
      cell.cardImage:setImageSource(cardImageFor(entry.idx))
      cell.cardImage:setImageColor(owned and '#ffffff' or '#1a2330')
      cell.lockIcon:setVisible(not owned)
      cell.newBadge:setVisible(newlyUnlocked[entry.idx] == true)
      cell.cardName:setText(entry.name)
      if entry.name:len() >= 18 then
        cell.cardName:setTTF("poppins", "semibold", 10)
      end
      cell.cardName:setColor(owned and '#ffffff' or '#9aa6b2')
      cell:setTooltip(entry.name .. ' - ' .. (owned and tr('Owned') or tr('Missing')))
    else
      cell:hide()
    end
  end

  pageLabel:setText(string.format('%d/%d', currentPage, totalPages))
  prevArrow:setEnabled(currentPage > 1)
  nextArrow:setEnabled(currentPage < totalPages)
end

function refreshProgress()
  local total = #albumData
  local owned = countOwned()
  collectProgress:setPercent(total > 0 and (owned / total) * 100 or 0)
  progressLabel:setText(string.format('%d / %d', owned, total))
  progressLabel:setColor((total > 0 and owned == total) and '#ffd24a' or '#f4fff3')
end

local function playUnlockSound()
  pcall(function()
    if g_sounds.isAudioEnabled() then g_sounds.play(UNLOCK_SOUND) end
  end)
end

local function announceUnlocks(newCount, firstName)
  playUnlockSound()
  local msg = (newCount == 1) and tr('New sticker: %s!', firstName) or tr('%d new stickers!', newCount)
  pcall(function() modules.game_textmessage.displayGameMessage(msg) end)
end

local function checkMilestones(prevOwned, owned, total)
  if total <= 0 then return end
  local prevPct = prevOwned / total * 100
  local nowPct = owned / total * 100
  for _, t in ipairs({ 25, 50, 75 }) do
    if prevPct < t and nowPct >= t then
      pcall(function() modules.game_textmessage.displayGameMessage(tr('%d%% of the album collected!', t)) end)
    end
  end
  if prevOwned < total and owned == total then
    pcall(function() modules.game_textmessage.displayGameMessage(tr('Album complete!')) end)
  end
end

function onAlbumData(data)
  data = data or {}
  if #data ~= #AlbumCards then
    g_logger.warning(string.format('[album] server sent %d entries, client has %d card images', #data, #AlbumCards))
  end

  newlyUnlocked = {}
  local newCount, firstName = 0, nil
  if hasReceivedRealData then
    for i, entry in ipairs(data) do
      if entry.unlocked and not (albumData[i] and albumData[i].unlocked) then
        newlyUnlocked[i] = true
        newCount = newCount + 1
        firstName = firstName or entry.name
      end
    end
  end

  local prevOwned = lastOwnedCount
  albumData = data

  local owned = countOwned()
  if hasReceivedRealData and newCount > 0 then
    announceUnlocks(newCount, firstName)
    checkMilestones(prevOwned, owned, #albumData)
  end
  lastOwnedCount = owned
  hasReceivedRealData = true

  rebuildViewList(searchEdit:getText())
  refreshProgress()

  -- server pushes 1569 when the player uses the album item -> surface the album
  if albumWindow and not albumWindow:isVisible() then
    open()
  end
end

function onCardClick(cell)
  if cell and cell.cardIndex then showCardDetail(cell.cardIndex) end
end

function showCardDetail(idx)
  local entry = albumData[idx]
  if not entry then return end
  if not detailWindow then
    detailWindow = g_ui.loadUI('albumdetail', modules.game_interface.getRootPanel())
  end
  local owned = entry.unlocked
  detailWindow.detailImage:setImageSource(cardImageFor(idx))
  detailWindow.detailImage:setImageColor(owned and '#ffffff' or '#1a2330')
  detailWindow.detailLock:setVisible(not owned)
  detailWindow.detailName:setText(entry.name)
  detailWindow.detailStatus:setText(owned and tr('Owned') or tr('Missing'))
  detailWindow.detailStatus:setColor(owned and '#52d869' or '#9aa6b2')
  detailWindow:show()
  detailWindow:raise()
  detailWindow:focus()
end

function closeDetail()
  if detailWindow then detailWindow:hide() end
end

function jumpToMissing()
  if currentFilterMode == 'owned' then
    setFilter('all') -- the 'owned' filter hides missing cards, so the scan below would find none
  end
  for i, entry in ipairs(viewList) do
    if not entry.unlocked then
      currentPage = math.ceil(i / PER_PAGE)
      renderSpread()
      return
    end
  end
end

function nextPage()
  if currentPage < totalPages then
    currentPage = currentPage + 1
    renderSpread()
  end
end

function prevPage()
  if currentPage > 1 then
    currentPage = currentPage - 1
    renderSpread()
  end
end

function onSearchTextChange()
  currentPage = 1
  rebuildViewList(searchEdit:getText())
end

function setupAlbumState()
  if not albumWindow then return end
  if not albumState then
    albumState = UIState.create()
    albumStateIndex = albumState:new(function(released)
      if released then
        if albumWindow and not albumWindow:isDestroyed() then
          g_uistates.remove(albumWindow)
        end
      else
        if albumWindow and not albumWindow:isDestroyed() then
          g_uistates.push(albumWindow)
        end
      end
    end)
    albumState:gotoState(0)
  end
  albumState:gotoState(albumStateIndex)
end

local function releaseAlbumState()
  if albumState then
    albumState:release()
    albumState = nil
    albumStateIndex = nil
  end
end

function open()
  albumWindow:show()
  albumWindow:raise()
  albumWindow:focus()
  setupAlbumState()
  rebuildViewList(searchEdit:getText())
  refreshProgress()
end

function close()
  if not albumWindow then return end
  albumWindow:hide()
  closeDetail()
  releaseAlbumState()
end
