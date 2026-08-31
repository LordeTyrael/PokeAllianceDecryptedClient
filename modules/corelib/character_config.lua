CharacterConfig = {}

local configFile = nil

function CharacterConfig.getConfig()
  if not configFile then
    configFile = g_settings.getConfig("characters.otml")
  end
  return configFile
end

function CharacterConfig.get(section)
  local charName = g_game.getCharacterName()
  if not charName or charName == "" then return nil end

  local config = CharacterConfig.getConfig()
  local charNode = config:getNode(charName)
  if not charNode then return nil end

  return charNode[section]
end

function CharacterConfig.set(section, data)
  local charName = g_game.getCharacterName()
  if not charName or charName == "" then return end

  local config = CharacterConfig.getConfig()
  local charNode = config:getNode(charName)
  if not charNode then
    charNode = {}
  end

  charNode[section] = data
  config:setNode(charName, charNode)
end

function CharacterConfig.save()
  local config = CharacterConfig.getConfig()
  config:save()
end
