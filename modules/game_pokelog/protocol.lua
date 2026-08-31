-- Protocol send wrappers (client -> server)

function sendRequestPoints()
  g_game.sendPokelogRequestPoints()
end

function sendClaimRewards(pokemonName)
  g_game.sendPokelogClaimRewards(pokemonName)
end

function sendClaimAll()
  g_game.sendPokelogClaimAll()
end

function sendRequestInfo(pokemonName, clientCache)
  g_game.sendPokelogRequestInfo(pokemonName, clientCache or false)
end

function sendRequestListInfo(pokemons)
  g_game.sendPokelogRequestListInfo(pokemons)
end

function sendRequestElementList(elementName)
  g_game.sendPokelogRequestElementList(elementName)
end

function sendRequestClaimableSummary()
  g_game.sendPokelogRequestClaimableSummary()
end
