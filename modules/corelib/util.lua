-- @docfuncs @{

function print(...)
  local msg = ""
  local args = {...}
  local appendSpace = #args > 1
  for i,v in ipairs(args) do
    msg = msg .. tostring(v)
    if appendSpace and i < #args then
      msg = msg .. '    '
    end
  end
  g_logger.log(LogInfo, msg)
end

function pinfo(msg)
  g_logger.log(LogInfo, msg)
end

function perror(msg)
  g_logger.log(LogError, msg)
end

function pwarning(msg)
  g_logger.log(LogWarning, msg)
end

function pdebug(msg)
  g_logger.log(LogDebug, msg)
end

function fatal(msg)
  g_logger.log(LogFatal, msg)
end

function exit()
  g_app.exit()
end

function quit()
  g_app.exit()
end

function connect(object, arg1, arg2, arg3)
  local signalsAndSlots
  local pushFront
  if type(arg1) == 'string' then
    signalsAndSlots = { [arg1] = arg2 }
    pushFront = arg3
  else
    signalsAndSlots = arg1
    pushFront = arg2
  end

  if not signalsAndSlots then
    return
  end

  for signal,slot in pairs(signalsAndSlots) do
    if not object[signal] then
      local mt = getmetatable(object)
      if mt and type(object) == 'userdata' then
        object[signal] = function(...)
          return signalcall(mt[signal], ...)
        end
      end
    end

    if not object[signal] then
      object[signal] = slot
    elseif type(object[signal]) == 'function' then
      object[signal] = { object[signal] }
    end

    if type(slot) ~= 'function' then
      perror(debug.traceback('unable to connect a non function value'))
    end

    if type(object[signal]) == 'table' then
      if pushFront then
        table.insert(object[signal], 1, slot)
      else
        table.insert(object[signal], #object[signal]+1, slot)
      end
    end
  end
end

function disconnect(object, arg1, arg2)
  local signalsAndSlots
  if type(arg1) == 'string' then
    if arg2 == nil then
      object[arg1] = nil
      return
    end
    signalsAndSlots = { [arg1] = arg2 }
  elseif type(arg1) == 'table' then
    signalsAndSlots = arg1
  else
    perror(debug.traceback('unable to disconnect'))
  end

  for signal,slot in pairs(signalsAndSlots) do
    if not object[signal] then
    elseif type(object[signal]) == 'function' then
      if object[signal] == slot then
        object[signal] = nil
      end
    elseif type(object[signal]) == 'table' then
      for k,func in pairs(object[signal]) do
        if func == slot then
          table.remove(object[signal], k)

          if #object[signal] == 1 then
            object[signal] = object[signal][1]
          end
          break
        end
      end
    end
  end
end

function newclass(name)
  if not name then
    perror(debug.traceback('new class has no name.'))
  end

  local class = {}
  function class.internalCreate()
    local instance = {}
    for k,v in pairs(class) do
      instance[k] = v
    end
    return instance
  end
  class.create = class.internalCreate
  class.__class = name
  class.getClassName = function() return name end
  return class
end

function extends(base, name)
  if not name then
    perror(debug.traceback('extended class has no name.'))
  end

  local derived = {}
  function derived.internalCreate()
    local instance = base.create()
    for k,v in pairs(derived) do
      instance[k] = v
    end
    return instance
  end
  derived.create = derived.internalCreate
  derived.__class = name
  derived.getClassName = function() return name end
  return derived
end

function runinsandbox(func, ...)
  if type(func) == 'string' then
    func, err = loadfile(resolvepath(func, 2))
    if not func then
      error(err)
    end
  end
  local env = { }
  local oldenv = getfenv(0)
  setmetatable(env, { __index = oldenv } )
  setfenv(0, env)
  func(...)
  setfenv(0, oldenv)
  return env
end

function loadasmodule(name, file)
  file = file or resolvepath(name, 2)
  if package.loaded[name] then
    return package.loaded[name]
  end
  local env = runinsandbox(file)
  package.loaded[name] = env
  return env
end

local function module_loader(modname)
  local module = g_modules.getModule(modname)
  if not module then
    return '\n\tno module \'' .. modname .. '\''
  end
  return function()
    if not module:load() then
      error('unable to load required module ' .. modname)
    end
    return module:getSandbox()
  end
end
table.insert(package.loaders, 1, module_loader)

function import(table)
  assert(type(table) == 'table')
  local env = getfenv(2)
  for k,v in pairs(table) do
    env[k] = v
  end
end

function export(what, key)
  if key ~= nil then
    _G[key] = what
  else
    for k,v in pairs(what) do
      _G[k] = v
    end
  end
end

function unexport(key)
  if type(key) == 'table' then
    for _k,v in pairs(key) do
      _G[v] = nil
    end
  else
    _G[key] = nil
  end
end

function getfsrcpath(depth)
  depth = depth or 2
  local info = debug.getinfo(1+depth, "Sn")
  local path
  if info.short_src then
    path = info.short_src:match("(.*)/.*")
  end
  if not path then
    path = '/'
  elseif path:sub(0, 1) ~= '/' then
    path = '/' .. path
  end
  return path
end

function resolvepath(filePath, depth)
  if not filePath then return nil end
  depth = depth or 1
  if filePath then
    if filePath:sub(0, 1) ~= '/' then
      local basepath = getfsrcpath(depth+1)
      if basepath:sub(#basepath) ~= '/' then basepath = basepath .. '/' end
      return  basepath .. filePath
    else
      return filePath
    end
  else
    local basepath = getfsrcpath(depth+1)
    if basepath:sub(#basepath) ~= '/' then basepath = basepath .. '/' end
    return basepath
  end
end

function toboolean(v)
  if type(v) == 'string' then
    v = v:trim():lower()
    if v == '1' or v == 'true' then
      return true
    end
  elseif type(v) == 'number' then
    if v == 1 then
      return true
    end
  elseif type(v) == 'boolean' then
    return v
  end
  return false
end

function fromboolean(boolean)
  if boolean then
    return 'true'
  else
    return 'false'
  end
end

function booleantonumber(boolean)
  if boolean then
    return 1
  else
    return 0
  end
end

function numbertoboolean(number)
  if number ~= 0 then
    return true
  else
    return false
  end
end

function protectedcall(func, ...)
  local status, ret = pcall(func, ...)
  if status then
    return ret
  end

  perror(ret)
  return false
end

function signalcall(param, ...)
  if type(param) == 'function' then
    local status, ret = pcall(param, ...)
    if status then
      return ret
    else
      perror(ret)
    end
  elseif type(param) == 'table' then
    for k,v in pairs(param) do
      local status, ret = pcall(v, ...)
      if status then
        if ret then return true end
      else
        perror(ret)
      end
    end
  elseif param ~= nil then
    error('attempt to call a non function value')
  end
  return false
end

function tr(s, ...)
  return string.format(s, ...)
end

function getOppositeAnchor(anchor)
  if anchor == AnchorLeft then
    return AnchorRight
  elseif anchor == AnchorRight then
    return AnchorLeft
  elseif anchor == AnchorTop then
    return AnchorBottom
  elseif anchor == AnchorBottom then
    return AnchorTop
  elseif anchor == AnchorVerticalCenter then
    return AnchorHorizontalCenter
  elseif anchor == AnchorHorizontalCenter then
    return AnchorVerticalCenter
  end
  return anchor
end

function makesingleton(obj)
  local singleton = {}
  if obj.getClassName then
    for key,value in pairs(_G[obj:getClassName()]) do
      if type(value) == 'function' then
        singleton[key] = function(...) return value(obj, ...) end
      end
    end
  end
  return singleton
end

local NUMBER_SUFFIXES = { 'k', 'kk', 'kkk', 'T', 'Qa', 'Qi', 'Sx' }

function formatNumberValue(n)
    local absn = math.abs(n)
    if absn < 1000 then
        return tostring(n)
    end

    -- divide em laço em vez de contar dígitos: tostring() usa %.14g e devolve
    -- notação científica a partir de 1e14, quebrando qualquer contagem textual
    local order = 0
    while absn >= 1000 and order < #NUMBER_SUFFIXES do
        absn = absn / 1000
        order = order + 1
    end

    -- três dígitos significativos: o rótulo vive numa coluna estreita e "433.58kk"
    -- não cabe onde "434kk" cabe
    local s = (absn >= 100 and string.format("%.0f", absn))
           or (absn >= 10 and string.format("%.1f", absn))
           or string.format("%.2f", absn)
    s = s:gsub("(%..-)0+$", "%1"):gsub("%.$", "")

    -- 999.96 arredonda para "1000": sobe uma ordem em vez de imprimir 1000k
    if tonumber(s) >= 1000 and order < #NUMBER_SUFFIXES then
        s, order = "1", order + 1
    end

    return (n < 0 and "-" or "") .. s .. NUMBER_SUFFIXES[order]
end

function setAbbreviatedNumber(widget, value, prefix)
    prefix = prefix or ""
    widget:setText(prefix .. formatNumberValue(value))
    -- comma_value2 opera sobre texto e recebe a notação científica de volta se o
    -- número chegar como float grande; %.0f garante os dígitos todos
    widget:setTooltip(prefix .. comma_value2(string.format("%.0f", value)))
end

function comma_value(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

function comma_value2(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

function isInArray(array, value, caseSensitive)
  if(caseSensitive == nil or caseSensitive == false) and type(value) == "string" then
    local lowerValue = value:lower()
    for _, _value in ipairs(array) do
      if type(_value) == "string" and lowerValue == _value:lower() then
        return true
      end
    end
  else
    for _, _value in ipairs(array) do
      if (value == _value) then return true end
    end
  end
  return false
end
-- @}

function switch(indice)
  return function(codetable)
    local case = codetable[indice] or codetable.default
    if ( case ) then
      if ( type(case) == "function" ) then
        return case(indice)
      else
        error("action "..tostring(indice).." not a function")
      end
    end
  end
end

function humanCase(string)
  local words = {}
  for word in string:gmatch("%S+") do
      table.insert(words, word)
  end
  
  -- Capitalizar a primeira letra de cada palavra
  for i, word in ipairs(words) do
      local firstLetter = word:sub(1, 1):upper()
      local restOfWord = word:sub(2):lower()
      words[i] = firstLetter .. restOfWord
  end
  
  -- Juntar as palavras formatadas
  local result = table.concat(words, " ")
  return result
end

function timeFormat(tempoSegundos)
    if tempoSegundos >= 86400 then
        local dias = math.floor(tempoSegundos / 86400)
        return dias .. " d"
    elseif tempoSegundos >= 3600 then
        local horas = math.floor(tempoSegundos / 3600)
        return horas .. " h"
    elseif tempoSegundos >= 60 then
        local minutos = math.floor(tempoSegundos / 60)
        return minutos .. " m"
    else
        return math.floor(tempoSegundos) .. " s"
    end
end

-- HH:MM:SS clock format (e.g. 01:23:45)
function formatHMS(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  local s = seconds % 60
  return string.format("%02d:%02d:%02d", h, m, s)
end

-- MM:SS clock format (e.g. 12:34)
function formatMS(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local m = math.floor(seconds / 60)
  local s = seconds % 60
  return string.format("%02d:%02d", m, s)
end

-- Compact countdown form: 1h02m / 1m02s / 12s
function formatCompactDuration(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  if seconds >= 86400 then
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    return string.format("%dd%02dh", d, h)
  elseif seconds >= 3600 then
    return string.format("%dh%02dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
  elseif seconds >= 60 then
    return string.format("%dm%02ds", math.floor(seconds / 60), seconds % 60)
  end
  return string.format("%ds", seconds)
end

-- Full duration form: "1d 2h 3m 4s" (omits zero parts; always shows seconds if total < 1m)
function formatDuration(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local d = math.floor(seconds / 86400); seconds = seconds % 86400
  local h = math.floor(seconds / 3600);  seconds = seconds % 3600
  local m = math.floor(seconds / 60);    seconds = seconds % 60
  local parts = {}
  if d > 0 then table.insert(parts, d .. "d") end
  if h > 0 then table.insert(parts, h .. "h") end
  if m > 0 then table.insert(parts, m .. "m") end
  if seconds > 0 or #parts == 0 then table.insert(parts, seconds .. "s") end
  return table.concat(parts, " ")
end

-- Short number form: 1.5K / 2.3M / 1.2B
function formatNumberShort(n)
  n = tonumber(n) or 0
  local absn = math.abs(n)
  if absn >= 1e9 then return string.format("%.1fB", n / 1e9) end
  if absn >= 1e6 then return string.format("%.1fM", n / 1e6) end
  if absn >= 1e3 then return string.format("%.1fK", n / 1e3) end
  return tostring(n)
end

-- Money/gold formatted with the given separator (defaults to comma). Alias around comma_value.
function formatMoney(amount, sep)
  sep = sep or ","
  local s = tostring(math.floor(tonumber(amount) or 0))
  local k = 1
  while k ~= 0 do
    s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1" .. sep .. "%2")
  end
  return s
end

-- Signed value with optional percent suffix. e.g. (10, false) -> "+10", (-5, true) -> "-5%"
function formatSigned(value, percent)
  local n = tonumber(value) or 0
  local sign = n > 0 and "+" or ""
  return sign .. tostring(n) .. (percent and "%" or "")
end

-- Função auxiliar para verificar se widget é um item
function isItemWidget(widget)
    if not widget then
        return false
    end
    
    return widget:getClassName() == "UIItem"
end