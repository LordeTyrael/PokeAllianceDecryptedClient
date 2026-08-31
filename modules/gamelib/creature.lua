-- @docclass Creature

-- @docconsts @{

SkullNone = 0
SkullYellow = 1
SkullGreen = 2
SkullWhite = 3
SkullRed = 4
SkullBlack = 5
SkullOrange = 6

ShieldNone = 0
ShieldWhiteYellow = 1
ShieldWhiteBlue = 2
ShieldBlue = 3
ShieldYellow = 4
ShieldBlueSharedExp = 5
ShieldYellowSharedExp = 6
ShieldBlueNoSharedExpBlink = 7
ShieldYellowNoSharedExpBlink = 8
ShieldBlueNoSharedExp = 9
ShieldYellowNoSharedExp = 10

EmblemNone = 0
EmblemGreen = 1
EmblemRed = 2
EmblemBlue = 3

NpcIconNone = 0
NpcIconCatch = 1
NpcIconDuel = 2
NpcIconEvent = 3
NpcIconGyms = 4
NpcIconItem = 5
NpcIconKill = 6
NpcIconMark = 7
NpcIconNurse = 8
NpcIconRequirement = 9

CreatureTypePlayer = 0
CreatureTypeMonster = 1
CreatureTypeNpc = 2
CreatureTypeSummonOwn = 3
CreatureTypeSummonOther = 4

-- @}

function getNextSkullId(skullId)
  if skullId == SkullRed or skullId == SkullBlack then
    return SkullBlack
  end
  return SkullRed
end

function getSkullImagePath(skullId)
  local path
  if skullId == SkullYellow then
    path = '/images/game/skulls/skull_yellow'
  elseif skullId == SkullGreen then
    path = '/images/game/skulls/skull_green'
  elseif skullId == SkullWhite then
    path = '/images/game/skulls/skull_white'
  elseif skullId == SkullRed then
    path = '/images/game/skulls/skull_red'
  elseif skullId == SkullBlack then
    path = '/images/game/skulls/skull_black'
  elseif skullId == SkullOrange then
    path = '/images/game/skulls/skull_orange'
  end
  return path
end

function getShieldImagePathAndBlink(shieldId)
  local path, blink
  if shieldId == ShieldWhiteYellow then
    path, blink = '/images/game/shields/shield_yellow_white', false
  elseif shieldId == ShieldWhiteBlue then
    path, blink = '/images/game/shields/shield_blue_white', false
  elseif shieldId == ShieldBlue then
    path, blink = '/images/game/shields/shield_blue', false
  elseif shieldId == ShieldYellow then
    path, blink = '/images/game/shields/shield_yellow', false
  elseif shieldId == ShieldBlueSharedExp then
    path, blink = '/images/game/shields/shield_blue_shared', false
  elseif shieldId == ShieldYellowSharedExp then
    path, blink = '/images/game/shields/shield_yellow_shared', false
  elseif shieldId == ShieldBlueNoSharedExpBlink then
    path, blink = '/images/game/shields/shield_blue_not_shared', true
  elseif shieldId == ShieldYellowNoSharedExpBlink then
    path, blink = '/images/game/shields/shield_yellow_not_shared', true
  elseif shieldId == ShieldBlueNoSharedExp then
    path, blink = '/images/game/shields/shield_blue_not_shared', false
  elseif shieldId == ShieldYellowNoSharedExp then
    path, blink = '/images/game/shields/shield_yellow_not_shared', false
  elseif shieldId == ShieldGray then
    path, blink = '/images/game/shields/shield_gray', false
  end
  return path, blink
end

function getShinyIconImagePath(shinyIcon)
  local path
  if shinyIcon == 1 then
    path = '/images/game/shields/shinyicon'
  end
  return path
end

function getEmblemImagePath(emblemId)
  local path
  if emblemId == EmblemGreen then
    path = '/images/game/emblems/emblem_green'
  elseif emblemId == EmblemRed then
    path = '/images/game/emblems/emblem_red'
  elseif emblemId == EmblemBlue then
    path = '/images/game/emblems/emblem_blue'
  elseif emblemId == EmblemMember then
    path = '/images/game/emblems/emblem_member'
  elseif emblemId == EmblemOther then
    path = '/images/game/emblems/emblem_other'
  end
  return path
end

function getTypeImagePath(creatureType)
  local path
  if creatureType == CreatureTypeSummonOwn then
    path = '/images/game/creaturetype/summon_own'
  elseif creatureType == CreatureTypeSummonOther then
    path = '/images/game/creaturetype/summon_other'
  end
  return path
end

function getIconImagePath(iconId)
  local path
  if iconId == NpcIconCatch then
    path = '/images/game/npcicons/catch'
  elseif iconId == NpcIconDuel then
    path = '/images/game/npcicons/duel'
  elseif iconId == NpcIconEvent then
    path = '/images/game/npcicons/event'
  elseif iconId == NpcIconGyms then
    path = '/images/game/npcicons/gyms'
  elseif iconId == NpcIconItem then
    path = '/images/game/npcicons/item'
  elseif iconId == NpcIconKill then
    path = '/images/game/npcicons/kill'
  elseif iconId == NpcIconMark then
    path = '/images/game/npcicons/mark'
  elseif iconId == NpcIconNurse then
    path = '/images/game/npcicons/nurse'
  elseif iconId == NpcIconRequirement then
    path = '/images/game/npcicons/requirement'
  end
  return path
end

function Creature:onSkullChange(skullId)
  local imagePath = getSkullImagePath(skullId)
  if imagePath then
    self:setSkullTexture(imagePath)
  end
end

function Creature:onShieldChange(shieldId)
  local imagePath, blink = getShieldImagePathAndBlink(shieldId)
  if imagePath then
    self:setShieldTexture(imagePath, blink)
  end
end

function Creature:onShinyIconChange(shinyIcon)
  local imagePath = getShinyIconImagePath(shinyIcon)
  if imagePath then
    self:setShinyIconTexture(imagePath)
  end
end

function Creature:onEmblemChange(emblemId)
  local imagePath = getEmblemImagePath(emblemId)
  if imagePath then
    self:setEmblemTexture(imagePath)
  end
end

function Creature:onTypeChange(typeId)
end

function Creature:onIconChange(iconId)
  local imagePath = getIconImagePath(iconId)
  if imagePath then
    self:setIconTexture(imagePath)
  end
end

function Creature:onBannerIconChange(linkId)
  local imagePath = ("/images/guild_banners/mini-icons/"..linkId)
  if imagePath then
    self:setGuildIconTexture(imagePath)
  end
end

function Creature:onTornadoChange(tornadoCount)
  if tornadoCount <= 0 then
    return
  end
  local imagePath = ("/images/minigames/"..tornadoCount)
  if imagePath then
    self:setTornadoTexture(imagePath)
  end
end

function Creature:onTwitchIconChange(linkId)
  if string.find(linkId, "twitch") then
    imagePath = '/images/game/shields/twitch'
  elseif string.find(linkId, "youtube") then
    imagePath = '/images/game/shields/youtube'
  elseif string.find(linkId, "kick") then
    imagePath = '/images/game/shields/kick'
  end
  if imagePath then
    self:setTwitchIconTexture(imagePath)
  end
end

function Creature:parsePokeView(target, start)
  if target then
    modules.game_interface.getMapPanel():followCreature(target)
    return
  end

  local player = g_game.getLocalPlayer()
  if player then
    modules.game_interface.getMapPanel():followCreature(player)
  end
end

--function Creature:setOutfitShader(shader) -- SHADER DESATIVADO
--  local outfit = self:getOutfit()
--  outfit.shader = shader
--  self:setOutfit(outfit)
--end
