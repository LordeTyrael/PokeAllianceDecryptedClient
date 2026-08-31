-- @docclass
UICreatureButton = extends(UIWidget, "UICreatureButton")

local CreatureButtonColors = {
  onIdle = {notHovered = '#888888', hovered = '#FFFFFF' },
  onTargeted = {notHovered = '#FF0000', hovered = '#FF8888' },
  onFollowed = {notHovered = '#00FF00', hovered = '#88FF88' }
}

local LifeBarColors = {} -- Must be sorted by percentAbove
table.insert(LifeBarColors, {percentAbove = 92, color = '#00BC00' } )
table.insert(LifeBarColors, {percentAbove = 60, color = '#50A150' } )
table.insert(LifeBarColors, {percentAbove = 30, color = '#A1A100' } )
table.insert(LifeBarColors, {percentAbove = 8, color = '#BF0A0A' } )
table.insert(LifeBarColors, {percentAbove = 3, color = '#910F0F' } )
table.insert(LifeBarColors, {percentAbove = -1, color = '#850C0C' } )

function UICreatureButton.create()
  local button = UICreatureButton.internalCreate()
  button:setFocusable(false)
  button.creature = nil
  button.isHovered = false
  return button
end

function UICreatureButton:setCreature(creature)
    self.creature = creature
end

function UICreatureButton:getCreature()
  return self.creature
end

function UICreatureButton:getCreatureId()
    return self.creature:getId()
end

function UICreatureButton:setup(id)
  self.lifeBarWidget = self:getChildById('lifeBar')
  self.creatureWidget = self:getChildById('creature')
  self.labelWidget = self:getChildById('label')
  self.skullWidget = self:getChildById('skull')
  self.emblemWidget = self:getChildById('emblem')
end

function UICreatureButton:update()
  local color = CreatureButtonColors.onIdle
  local show = false
  if self.creature == g_game.getAttackingCreature() then
    color = CreatureButtonColors.onTargeted
  elseif self.creature == g_game.getFollowingCreature() then
    color = CreatureButtonColors.onFollowed
  end
  color = self.isHovered and color.hovered or color.notHovered

  if self.color == color then
    return
  end
  self.color = color

  if color ~= CreatureButtonColors.onIdle.notHovered then
    self.creatureWidget:setBorderWidth(1)
    self.creatureWidget:setBorderColor(color)
    self.labelWidget:setColor(color)
  else
    self.creatureWidget:setBorderWidth(0)
    self.labelWidget:setColor(color)
  end
end

function UICreatureButton:creatureSetup(creature)
	if self.creature ~= creature then
		self.creature = creature
		self.creatureWidget:setCreature(creature)	
    if self.creatureName ~= creature:getName() then
      self.creatureName = creature:getName()
      self.labelWidget:setText(creature:getName())
    end
	end

	self:updateLifeBarPercent()
	self:updateEmblem()
  self:update()
end

function UICreatureButton:updateEmblem()
  if not self.creature then
    return
  end
  local emblemId = self.creature:getEmblem()
  if self.emblemId == emblemId then
    return
  end
  self.emblemId = emblemId

  if emblemId ~= EmblemNone then
    self.emblemWidget:setWidth(self.emblemWidget:getHeight())
    local imagePath = getEmblemImagePath(emblemId)
    self.emblemWidget:setImageSource(imagePath)
    self.emblemWidget:setMarginLeft(5)
    self.labelWidget:setMarginLeft(8)
  else
    self.emblemWidget:setWidth(0)
    self.emblemWidget:setMarginLeft(0)
    if self.creature:getSkull() == SkullNone then
      self.labelWidget:setMarginLeft(5)
    end
  end
end

function UICreatureButton:updateLifeBarPercent()
  if not self.creature then
    return
  end
  local percent = self.creature:getHealthPercent()
  if self.percent == percent then
    return
  end

  self.percent = percent
  local Xhppc = math.floor(130 * (100 - (percent)) / 100)
  local rect = { x = 0, y = 0, width = 130 - Xhppc, height = 7 }
  self.lifeBarWidget.lifeBarPercent:setImageRect(rect)

  local color
  for i, v in pairs(LifeBarColors) do
    if percent > v.percentAbove then
      color = v.color
      break
    end
  end
  self.lifeBarWidget.lifeBarPercent:setImageColor(color)
end