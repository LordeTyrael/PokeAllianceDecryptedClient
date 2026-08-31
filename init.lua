-- CONFIG
APP_NAME = "PokeAllianceV3"
APP_NAME_CRIP = "PokeAllianceV2"
APP_VERSION = 854       -- client version for updater and login to identify outdated client
--APP_VERSION = 101
DEFAULT_LAYOUT = "default" -- on android it's forced to "mobile", check code bellow

DLL_CHECKSUM = { {"d3dcompiler_47.dll", "d30621d9"}, {"libEGL.dll", "792836ce"}, {"libGLESv2.dll", "9b805101"} }
BAD_FILES = {"lam", "engine.spr", "LanEngine.key", "LanEngine.dll", "opengl32.dll"}
BAD_PROCESSES = {"NinjaRipper.exe", "injhelper.exe", "ripdump.exe"}
BAD_DLLS = {"intruder.dll", "d3dx8d.dll", "d3dwrap.dll"}

-- If you don't use updater or other service, set it to updater = ""
Services = {
  --website = "", -- currently not used
  --stats = "",
  --crash = "",
  --feedback = "",
  --status = ""
  clientServices = "http://clientservices.pokealliance.com:7778",
  apiPix = "https://payments.pokealliance.com",
  loginServices = "http://clientservices.pokealliance.com:8888"
}

-- Servers accept http login url, websocket login url or ip:port:version
Servers = {
  Localhost = Services.loginServices.."/login"
  --TestServer = "177.54.149.198:9787:854"
  --LocalHost2 = "186.225.68.51:7171:854"
  --Localhost = "http://login.pokealliance.com/login"
}

ALLOW_CUSTOM_SERVERS = false

g_app.setName("PokeAlliance")
-- CONFIG END

-- print first terminal message
g_logger.info(os.date("== application started at %b %d %Y %X"))
g_logger.info(g_app.getName() .. ' ' .. g_app.getVersion() .. ' rev ' .. g_app.getBuildRevision() .. ' (' .. g_app.getBuildCommit() .. ') made by ' .. g_app.getAuthor() .. ' built on ' .. g_app.getBuildDate() .. ' for arch ' .. g_app.getBuildArch())

if not g_resources.directoryExists("/data") then
  g_logger.fatal("Data dir doesn't exist.")
end


if not g_resources.directoryExists("/modules") then
  g_logger.fatal("Modules dir doesn't exist.")
end

-- settings
g_configs.loadSettings("/config.otml")

-- set layout
local settings = g_configs.getSettings()
local layout = DEFAULT_LAYOUT
if g_app.isMobile() then
  layout = "mobile"
elseif settings:exists('layout') then
  layout = settings:getValue('layout')
end
g_resources.setLayout(layout)
-- load mods
g_modules.discoverModules()
g_modules.ensureModuleLoaded("corelib")

local function loadModules()
  -- libraries modules 0-99
  g_modules.autoLoadModules(99)
  g_modules.ensureModuleLoaded("gamelib")

  -- client modules 100-499
  g_modules.autoLoadModules(499)
  g_modules.ensureModuleLoaded("client")

  -- game modules 500-999
  g_modules.autoLoadModules(999)
  g_modules.ensureModuleLoaded("game_interface")

  -- mods 1000-9999
  g_modules.autoLoadModules(9999)
end

-- report crash
if type(Services.crash) == 'string' and Services.crash:len() > 4 and g_modules.getModule("crash_reporter") then
  g_modules.ensureModuleLoaded("crash_reporter")
end

-- run updater, must use data.zip
loadModules()
