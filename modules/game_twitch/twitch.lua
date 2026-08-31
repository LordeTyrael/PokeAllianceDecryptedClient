local pollCheckInterval = 20
local pollCheckEvent = nil
local OPCODE = 114

local function clearPollResult()
  	local payload = {
  	  	action = "clear"
  	}
  	local payloadJson = json.encode(payload)
  	HTTP.post("http://186.225.68.51:7778/api/poll-result", payloadJson, function(response)
  	  	print("Resultado da votação foi limpo. Resposta: " .. response)
  	end)
end

local function checkPollResult()
  	HTTP.getJSON("http://186.225.68.51:7778/api/poll-result", function(result)
  	  	if result and result.finished and result.winner and result.winner ~= "" then
  	  	  	print("Votação encerrada! Vencedor: " .. result.winner .. " com " .. result.votes .. " votos.")
  	  	  	if g_game.getProtocolGame() then
  	  	  		g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({action = "spectate-twitch", data = {name = result.winner}}))
  	  	  		clearPollResult()
  	  	  	end
  	  	else
  	  	  	print("Votação ainda em andamento ou sem resultado disponível.")
  	  	end
  	end)
end

function onGameStart()
  	local localPlayer = g_game.getLocalPlayer()
  	if not localPlayer or localPlayer:getName() ~= "Twitch" then
  	  	return
  	end
  	pollCheckEvent = cycleEvent(checkPollResult, pollCheckInterval * 1000)
end

function onGameEnd()
  	if pollCheckEvent then
  	  	removeEvent(pollCheckEvent)
  	  	pollCheckEvent = nil
  	end
end

function init()
  	connect(g_game, {
  	  onGameStart = onGameStart,
  	  onGameEnd = onGameEnd,
  	})
end

function terminate()
  	if pollCheckEvent then
  	  	removeEvent(pollCheckEvent)
  	  	pollCheckEvent = nil
  	end
end
