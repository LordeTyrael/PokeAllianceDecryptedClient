loaded = false

function init()
  connect(g_game, { onProtocolVersionChange = load })
end

function terminate()
  disconnect(g_game, { onProtocolVersionChange = load })
end

function isLoaded()
  return loaded
end

function load()
  if loaded then return end
  local version = g_game.getClientVersion()  
  g_game.enableFeature(GameDiagonalAnimatedText)
  g_game.enableFeature(GameMagicEffectU16)
  g_game.enableFeature(GameSpritesAlphaChannel)
  
  
  local datPath, sprPath  
  datPath = resolvepath('/things/things')
  sprPath = resolvepath('/things/things')


  local errorMessage = ''
  if not g_things.loadDat(datPath) then   
      errorMessage = errorMessage .. tr("Unable to load dat file, please place a valid dat in '%s'", datPath) .. '\n'    
  end
  if not g_sprites.loadSpr(sprPath) then
    errorMessage = errorMessage .. tr("Unable to load spr file, please place a valid spr in '%s'", sprPath)
  end  
 
  loaded = (errorMessage:len() == 0)
  --g_things.loadOtml(resolvepath('/things/things'))
  
  if errorMessage:len() > 0 then
    local messageBox = displayErrorBox(tr('Error'), errorMessage)
    addEvent(function() messageBox:raise() messageBox:focus() end)
    
     disconnect(g_game, { onProtocolVersionChange = load })
    g_game.setProtocolVersion(0)
    connect(g_game, { onProtocolVersionChange = load })
  end
end
