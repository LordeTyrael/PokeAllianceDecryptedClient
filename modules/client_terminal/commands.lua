local function pcolored(text, color)
  color = color or 'white'
  modules.client_terminal.addLine(tostring(text), color)
end

function draw_debug_boxes()
  g_ui.setDebugBoxesDrawing(not g_ui.isDrawingDebugBoxes())
end

function hide_map()
  modules.game_interface.getMapPanel():hide()
end

function show_map()
  modules.game_interface.getMapPanel():show()
end

local pinging = false
local function pingBack(ping)
  if ping < 300 then color = 'green'
  elseif ping < 600 then color = 'yellow'
  else color = 'red' end
  pcolored(g_game.getWorldName() .. ' => ' .. ping .. ' ms', color)
end
function ping()
  if pinging then
    pcolored('Ping stopped.')
    g_game.setPingDelay(1000)
    disconnect(g_game, 'onPingBack', pingBack)
  else
    if not (g_game.getFeature(GameClientPing) or g_game.getFeature(GameExtendedClientPing)) then
      pcolored('this server does not support ping', 'red')
      return
    elseif not g_game.isOnline() then
      pcolored('ping command is only allowed when online', 'red')
      return
    end

    pcolored('Starting ping...')
    g_game.setPingDelay(0)
    connect(g_game, 'onPingBack', pingBack)
  end
  pinging = not pinging
end

function clear()
  modules.client_terminal.clear()
end

function ls(path)
  path = path or '/'
  local files = g_resources.listDirectoryFiles(path)
  for k,v in pairs(files) do
    if g_resources.directoryExists(path .. v) then
      pcolored(path .. v, 'blue')
    else
      pcolored(path .. v)
    end
  end
end

function about_version()
  pcolored(g_app.getName() .. ' ' .. g_app.getVersion() .. '\n' .. g_app.getAuthor())
end

function about_graphics()
  pcolored('Vendor ' .. g_graphics.getVendor())
  pcolored('Renderer ' .. g_graphics.getRenderer())
  pcolored('Version ' .. g_graphics.getVersion())
  pcolored('Context recoveries ' .. g_app.getGraphicsRecoveryCount())
end

function simulate_context_loss(surfaceOnly)
  g_window.simulateContextLoss(surfaceOnly == true)
end

function about_modules()
  for k,m in pairs(g_modules.getModules()) do
    local loadedtext
    if m:isLoaded() then
      pcolored(m:getName() .. ' => loaded', 'green')
    else
      pcolored(m:getName() .. ' => not loaded', 'red')
    end
  end
end

function live_otml_reload()
    local files = {}
    local hasFile = false
  
    otmlPath = 'data/things/854/Tibia.otml'

    local time = g_platform.getFileModificationTime(otmlPath)
    if time > 0 then
      files[otmlPath] = time
      hasFile = true
    end
    
    if not hasFile then
      pcolored('ERROR: unable to find any file for moduleA', 'red')
      return
  else
    pcolored('Started Live OMTL', 'yellow')
    end

    cycleEvent(function()
      for filepath, time in pairs(files) do
        local newtime = g_platform.getFileModificationTime(filepath)
        if newtime > time then
          modules.client_terminal.flushLines()
      
      if not g_things.loadOtml('/things/854/Tibia') then
       pcolored("Unable to load otml file, please place a valid otml", "red")
      else
       pcolored("OTML reloaded.", "green")
      end
      
          files[filepath] = newtime
    
          if name == 'client_terminal' then
            modules.client_terminal.show()
          end
          break
        end
      end
    end, 1000)
end

function live_module_reload(name)
  if not name then
    pcolored('ERROR: missing module name', 'red')
    return
  end

  local module = g_modules.getModule(name)
  if not module then
    pcolored('ERROR: unable to find module ' .. name, 'red')
    return
  end

  if not module:isReloadble() then
    pcolored('ERROR: that module is not reloadable', 'red')
    return
  end

  if not module:canReload() then
    pcolored('ERROR: some other modules requires this module, cannot reload now', 'red')
    return
  end

  local files = {}
  local hasFile = false
  for _,file in pairs(g_resources.listDirectoryFiles('/' .. name)) do
    local filepath = 'modules/' .. name .. '/' .. file
    local time = g_platform.getFileModificationTime(filepath)
    if time > 0 then
      files[filepath] = time
      hasFile = true
    end
  end

  if not hasFile then
    pcolored('ERROR: unable to find any file for moduleA', 'red')
    return
  end

  cycleEvent(function()
    for filepath, time in pairs(files) do
      local newtime = g_platform.getFileModificationTime(filepath)
      if newtime > time then
        pcolored('Reloading: ' .. name, 'green')
        modules.client_terminal.flushLines()
        module:reload()
        files[filepath] = newtime

        if name == 'client_terminal' then
          modules.client_terminal.show()
        end
        break
      end
    end
  end, 1000)
end

-- stream <url> [title] -- open a Twitch/YouTube channel in the embedded panel.
-- Reaching it in-game needs a creature carrying a stream link, so this is the
-- way to exercise game_streamview without one.
function stream(url, title)
  local streamView = modules.game_streamview
  if not streamView then
    pcolored('ERROR: game_streamview is not loaded', 'red')
    return
  end

  if not url or url == '' then
    pcolored('usage: stream <url> [title]', 'red')
    pcolored('  stream https://www.twitch.tv/pokealliance', 'white')
    return
  end

  local available = g_webview.isAvailable()
  pcolored('g_webview.isAvailable() => ' .. tostring(available), available and 'green' or 'red')

  if not streamView.open(url, title) then
    -- Same fallback the creature menu takes: unsupported host, or no webview.
    pcolored('refused -> the system browser would be used instead', 'yellow')
    return
  end
  pcolored('opened ' .. url, 'green')
end

function stream_close()
  local streamView = modules.game_streamview
  if streamView then
    streamView.hide()
  end
end
