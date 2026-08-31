-- @docclass
UITooltip = extends(UIWidget, "UITooltip")

function UITooltip.create()
  local tooltip = UITooltip.internalCreate()
  tooltip:setPhantom(true)
  tooltip:setFocusable(false)
  tooltip:setVisible(false)
  tooltip:setIgnoreDrawIntersect(true)
  tooltip.followMouse = true
  tooltip.followMouseOffset = { x = 0, y = 0 }
  tooltip._locked = false
  return tooltip
end

function UITooltip:setLocked(locked)
  if self._locked == locked then return end
  self._locked = locked
  if locked then
    g_uistates.push(self)
  else
    g_uistates.remove(self)
  end
end

function UITooltip:isLocked()
  return self._locked == true
end

function UITooltip:onStyleApply(styleName, styleNode)
  for name, value in pairs(styleNode) do
    if name == "follow-mouse" then
      self:setFollowMouse(value)
    elseif name == "follow-mouse-offset" then
      self:setFollowMouseOffset(topoint(value))
    end
  end
end

function UITooltip:setFollowMouse(state)
  self.followMouse = state
end

function UITooltip:canFollowMouse()
  return self.followMouse
end

function UITooltip:setFollowMouseOffset(offset)
  self.followMouseOffset = offset
end

function UITooltip:getFollowMouseOffset()
  return self.followMouseOffset
end
