ALBUM_OPCODE = 1569

-- server -> client message type (leading byte) -- must match server CopaStickers.RESPONSE_*
ALBUM_TYPE_ALBUM = 1
ALBUM_TYPE_RANKING = 2
-- client -> server action (leading byte) -- server CopaStickers.ACTION_REQUEST_RANKING
ALBUM_ACTION_REQUEST_RANKING = 1

function sendRankingRequest(page)
  local protocol = g_game.getProtocolGame()
  if not protocol then return end
  local msg = OutputMessage.create()
  msg:addU16(ALBUM_OPCODE)
  msg:addU8(ALBUM_ACTION_REQUEST_RANKING)
  msg:addU8(page or 1) -- 1-based page
  protocol:send(msg)
end
