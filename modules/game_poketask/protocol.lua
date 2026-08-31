-- Protocolo custom 1584 nas duas direções (parsePokeTask em C++). Substituiu o extended 244, que
-- trafegava JSON chunked. O 244 NÃO foi reusado como número: Proto::GameServerItemInfo já é 244 no
-- S2C, e no servidor um C2S 244 cairia no switch de ProtocolGame antes do default: que alimenta o
-- onReceivePacket dos módulos.

local _parseError

local errorBox

-- Handlers dos eventos disparados pelo parsePokeTask ------------------------------------------------

function onPokeTaskOpen(slotCount, shards)
  createTasks(slotCount, shards)
end

function onPokeTaskClose()
  hide()
end

-- O 3º argumento de onDungeonShard é a contagem de shards e o 2º é o índice do slot; aqui o índice vai
-- nil de propósito, para o widget ser resolvido por lastUseSlot (o slot em que o jogador acabou de
-- soltar a shard), igual ao comportamento do JSON antigo.
function onPokeTaskShard(info)
  onDungeonShard(info, nil, info.shardCount, info.finalTimeout)
end

function onPokeTaskPokemon(params)
  onDungeonPokemon(params)
end

function onPokeTaskError(message, reference)
  _parseError(message, reference)
end

function onPokeTaskStartMission(index)
  onStartMission(index)
end

function onPokeTaskCancelMission(index)
  onCancelMission(index)
end

function onPokeTaskClaimMission(index)
  onClaimMission(index)
end

function _parseError(message, reference)
  if errorBox then
    errorBox:destroy()
    errorBox = nil
  end

  errorBox = displayErrorBox(tr("Error"), message)
  connect(errorBox,
    { onOk = function() errorBox = nil end }
  )

  if reference == "shard-item" then
    onShardItemError()
  elseif reference == "pokemon" then
    onPokemonItemError()
  end
end

function terminateProtocol()
  if errorBox then
    errorBox:destroy()
    errorBox = nil
  end
end

-- Envio C2S ----------------------------------------------------------------------------------------

-- getStackPos() pode devolver -1 (item fora de tile) e o wire carrega u8; o servidor já tratava
-- ausência como 0. index é o slot da janela, sempre dentro de availableSlots.
local function itemStackPos(item)
  local stackPos = item:getStackPos()
  if not stackPos or stackPos < 0 then
    return 0
  end
  if stackPos > 255 then
    return 255
  end
  return stackPos
end

function sendDungeonShard(item, index, count)
  count = count or item:getCount()
  g_game.sendPokeTaskShard(item:getPosition(), item:getId(), index, count, itemStackPos(item))
end

function sendDungeonPokemon(item, index)
  g_game.sendPokeTaskPokemon(item:getPosition(), item:getId(), index, itemStackPos(item))
end

function sendStartMission(index)
  g_game.sendPokeTaskStartMission(index)
end

function sendClaimMission(index)
  g_game.sendPokeTaskClaimMission(index)
end

function sendCancelMission(index)
  g_game.sendPokeTaskCancelMission(index)
end
