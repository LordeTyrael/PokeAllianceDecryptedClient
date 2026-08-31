-- @docclass UIWidget

function UIWidget:setMargin(...)
  local params = {...}
  if #params == 1 then
    self:setMarginTop(params[1])
    self:setMarginRight(params[1])
    self:setMarginBottom(params[1])
    self:setMarginLeft(params[1])
  elseif #params == 2 then
    self:setMarginTop(params[1])
    self:setMarginRight(params[2])
    self:setMarginBottom(params[1])
    self:setMarginLeft(params[2])
  elseif #params == 4 then
    self:setMarginTop(params[1])
    self:setMarginRight(params[2])
    self:setMarginBottom(params[3])
    self:setMarginLeft(params[4])
  end
end

-- a userdata tooltip passed to setTooltip is owned by the widget: destroyed on replace/remove/widget destroy
local function destroyOwnedTooltip(widget)
  if not widget.tooltipDestroyCallback then
    return
  end
  disconnect(widget, { onDestroy = widget.tooltipDestroyCallback })
  widget.tooltipDestroyCallback = nil
  if not widget.tooltip:isDestroyed() then
    widget.tooltip:destroy()
  end
end

function UIWidget:setTooltip(tooltip)
  if not tooltip then
    self:removeTooltip()
    return
  end

  if self.tooltip == tooltip then
    return
  end

  if type(tooltip) == "userdata" and tooltip:getClassName() ~= "UITooltip" then
    g_logger.error("UIWidget:setTooltip - The userdata is not a UITooltip.")
    return
  end

  destroyOwnedTooltip(self)
  self.tooltip = tooltip

  if type(tooltip) == "userdata" then
    self.tooltipDestroyCallback = function()
      if not tooltip:isDestroyed() then
        tooltip:destroy()
      end
    end
    connect(self, { onDestroy = self.tooltipDestroyCallback })
  end
end

function UIWidget:removeTooltip()
  destroyOwnedTooltip(self)
  self.tooltip = nil
end

function UIWidget:getTooltip()
  return self.tooltip
end