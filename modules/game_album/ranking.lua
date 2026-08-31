local rankingWindow
local rankingContent
local rankingEmpty
local rankPageLabel
local rankPrev
local rankNext

local RANK_COLORS = { [1] = '#f6d001', [2] = '#b7b7b7', [3] = '#a25020' }
local RANK_PER_PAGE = 10 -- must match the server's page size in sendRankingPage
local rankPage = 1
local rankTotalPages = 1

local function formatTime(ts)
  if not ts or ts == 0 then return '-' end
  local d = os.date('*t', ts)
  if not d then return '-' end
  return string.format('%02d/%02d/%04d %02d:%02d', d.day, d.month, d.year, d.hour, d.min)
end

local function ensureRankingWindow()
  if rankingWindow then return rankingWindow end
  rankingWindow = g_ui.loadUI('albumranking', modules.game_interface.getRootPanel())
  rankingWindow:hide()
  rankingContent = rankingWindow:getChildById('content')
  rankingEmpty = rankingWindow:getChildById('emptyState')
  rankPageLabel = rankingWindow:getChildById('rankPageLabel')
  rankPrev = rankingWindow:getChildById('rankPrev')
  rankNext = rankingWindow:getChildById('rankNext')
  return rankingWindow
end

function onAlbumRankingData(page, total, entries)
  ensureRankingWindow()
  rankTotalPages = math.max(math.ceil((total or 0) / RANK_PER_PAGE), 1)
  rankPage = math.max(math.min(page or 1, rankTotalPages), 1)

  local layout = rankingContent:getLayout()
  layout:disableUpdates()
  rankingContent:destroyChildren()

  local base = (rankPage - 1) * RANK_PER_PAGE
  local shown = 0
  for i, e in ipairs(entries or {}) do
    local rank = base + i
    local row = g_ui.createWidget('AlbumRankRow', rankingContent)
    row.pos:setText(rank)
    row.nick:setText(e.name)
    row.time:setText(formatTime(e.time))
    row.world:setText(e.world)
    if RANK_COLORS[rank] then
      row.pos:setColor(RANK_COLORS[rank])
      row.nick:setColor(RANK_COLORS[rank])
    end
    shown = shown + 1
  end

  layout:enableUpdates()
  layout:update()
  rankingEmpty:setVisible(shown == 0)
  rankPageLabel:setText(string.format('%d/%d', rankPage, rankTotalPages))
  rankPrev:setEnabled(rankPage > 1)
  rankNext:setEnabled(rankPage < rankTotalPages)

  rankingWindow:show()
  rankingWindow:raise()
end

function openRanking()
  ensureRankingWindow()
  rankingWindow:show()
  rankingWindow:raise()
  rankingWindow:focus()
  sendRankingRequest(1)
end

function nextRankPage()
  if rankPage < rankTotalPages then
    rankPrev:setEnabled(false)
    rankNext:setEnabled(false)
    sendRankingRequest(rankPage + 1)
  end
end

function prevRankPage()
  if rankPage > 1 then
    rankPrev:setEnabled(false)
    rankNext:setEnabled(false)
    sendRankingRequest(rankPage - 1)
  end
end

function closeRanking()
  if rankingWindow then rankingWindow:hide() end
end

function clearRanking()
  rankPage = 1
  rankTotalPages = 1
  if rankingContent then rankingContent:destroyChildren() end
  closeRanking()
end

function terminateRanking()
  if rankingWindow then
    rankingWindow:destroy()
    rankingWindow = nil
  end
end
