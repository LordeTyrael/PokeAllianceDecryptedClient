Opcode = 244

local _parseOpen
local _parseError
local _parseShard
local _parsePokemon
local _parseStartMission
local _parseCancelMission
local _parseClaimMission

local errorBox

function parseOpcode(protocol, opcode, buffer)
  local data = json.decode(buffer)
  local action = data.action

  if action == 'open' then
    local availableTasksSlots = data.availableTasksSlots
    local shards = data.shards
    _parseOpen(availableTasksSlots, shards)

  elseif action == 'shard' then
    local shard = data.shard
    local count = data.count
    _parseShard(shard, count, data.finalTimeout)

  elseif action == 'pokemon' then
    _parsePokemon(data.params)

  elseif action == 'error' then
    local message = data.message
    local reference = data.reference
    _parseError(message, reference)

  elseif action == 'start-mission' then
    local index = data.index
    _parseStartMission(index)

  elseif action == 'cancel-mission' then
    local index = data.index
    _parseCancelMission(index)

  elseif action == 'claim-mission' then
    local index = data.index
    _parseClaimMission(index)

  elseif action == 'close' then
    _parseClose()
  else
    g_logger.error(string.format("Not found action with id: '%s'", tostring(action)))
  end
end

function _parseOpen(availableTasksSlots, shards)
  createTasks(availableTasksSlots, shards)
end

function _parseClose()
  hide()
end

function _parseShard(shard, count, finalTimeout)
  onDungeonShard(shard, nil, count, finalTimeout)
end

function _parsePokemon(pokeballParams)
  onDungeonPokemon(pokeballParams)
end

function _parseError(message, reference)
  if errorBox then
    errorBox:destroy()
    errorBox = nil
  end

  errorBox = displayErrorBox(tr("Error"), tr(message))
  connect(errorBox,
    { onOk = function() errorBox = nil end }
  )

  if reference == "shard-item" then
    onShardItemError()
  elseif reference == "pokemon" then
    onPokemonItemError()
  end
end

function _parseStartMission(index)
  onStartMission(index)
end

function _parseCancelMission(index)
  onCancelMission(index)
end

function _parseClaimMission(index)
  onClaimMission(index)
end

function sendDungeonShard(item, index, count)
  local protocolGame = g_game.getProtocolGame()
  if not protocolGame then
    return
  end

  count = count or item:getCount()
  protocolGame:sendExtendedJSONOpcode(Opcode, { action = "shard", itemPos = item:getPosition(), stackPos = item:getStackPos(), spriteId = item:getId(), index = index, count = count })
end

function sendDungeonPokemon(item, index)
  local protocolGame = g_game.getProtocolGame()
  if not protocolGame then
    return
  end

  protocolGame:sendExtendedJSONOpcode(Opcode, { action = "pokemon", itemPos = item:getPosition(), stackPos = item:getStackPos(), spriteId = item:getId(), index = index })
end

function sendStartMission(index)
  local protocolGame = g_game.getProtocolGame()
  if not protocolGame then
    return
  end

  protocolGame:sendExtendedJSONOpcode(Opcode, { action = "start-mission", index = index } )
end

function sendClaimMission(index)
  local protocolGame = g_game.getProtocolGame()
  if not protocolGame then
    return
  end

  protocolGame:sendExtendedJSONOpcode(Opcode, { action = "claim", index = index } )
end

function sendCancelMission(index)
  local protocolGame = g_game.getProtocolGame()
  if not protocolGame then
    return
  end

  protocolGame:sendExtendedJSONOpcode(Opcode, { action = "cancel", index = index } )
end
