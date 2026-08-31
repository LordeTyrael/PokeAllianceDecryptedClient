-- @docclass
g_tooltip = {}

-- private variables
local toolTipLabel
local currentHoveredWidget
local currentTooltip

-- private functions
local function moveToolTip(tooltipWidget, first)
  if not first and (not tooltipWidget:isVisible() or tooltipWidget:getOpacity() < 0.1) then return end

  local pos = g_window.getMousePosition()
  local windowSize = g_window.getSize()
  local tooltipSize = tooltipWidget:getSize()

  if tooltipWidget:getClassName() == "UITooltip" then
    if not tooltipWidget:canFollowMouse() then
      return
    end

    local followMouseOffset = tooltipWidget:getFollowMouseOffset()
    pos.x = pos.x + followMouseOffset.x
    pos.y = pos.y + followMouseOffset.y
  end

  pos.x = pos.x + 1
  pos.y = pos.y + 1

  if windowSize.width - (pos.x + tooltipSize.width) < 10 then
    pos.x = pos.x - tooltipSize.width - 3
  else
    pos.x = pos.x + 10
  end

  if windowSize.height - (pos.y + tooltipSize.height) < 10 then
    pos.y = pos.y - tooltipSize.height - 3
  else
    pos.y = pos.y + 10
  end

  tooltipWidget:setPosition(pos)
end

local function onWidgetHoverChange(widget, hovered)
  if hovered then
    if widget.tooltip and not g_mouse.isPressed() then
      g_tooltip.display(widget, widget.tooltip)
      currentHoveredWidget = widget
    end
  else
    if widget == currentHoveredWidget then
      g_tooltip.hide()
      currentHoveredWidget = nil
    end
  end
end

local function onWidgetStyleApply(widget, styleName, styleNode)
  if styleNode.tooltip then
    widget.tooltip = styleNode.tooltip
  end
end

-- public functions
function g_tooltip.init()
  connect(UIWidget, {  onStyleApply = onWidgetStyleApply,
                       onHoverChange = onWidgetHoverChange})

  addEvent(function()
    toolTipLabel = g_ui.createWidget('UILabel', rootWidget)
    toolTipLabel:setId('toolTip')
    toolTipLabel:setBackgroundColor('#111111cc')
    toolTipLabel:setTextAlign(AlignCenter)
    toolTipLabel:hide()
  end)
end

function g_tooltip.terminate()
  disconnect(UIWidget, { onStyleApply = onWidgetStyleApply,
                         onHoverChange = onWidgetHoverChange })

  currentHoveredWidget = nil
  currentTooltip = nil
  toolTipLabel:destroy()
  toolTipLabel = nil

  g_tooltip = nil
end

function g_tooltip.display(widget, tooltip)
  local tooltipWidget = type(tooltip) == "userdata" and tooltip or toolTipLabel
  if not tooltipWidget then
    return
  end

  tooltipWidget:setDrawOnTopOfBlur(true)

  if type(tooltip) == "string" then
    if tooltip:len() == 0 then
      return
    end

    tooltipWidget:setText(tooltip)
    tooltipWidget:resizeToText()
    tooltipWidget:resize(tooltipWidget:getWidth() + 4, tooltipWidget:getHeight() + 4)
  end

  currentTooltip = tooltipWidget
  tooltipWidget:show()
  tooltipWidget:raise()
  tooltipWidget:enable()
  g_effects.fadeIn(tooltipWidget, 100)
  moveToolTip(tooltipWidget, true)

  rootWidget.onMouseMove = function()
    moveToolTip(tooltipWidget)
  end
end

function g_tooltip.hide()
  if not currentTooltip then
    return
  end

  g_effects.fadeOut(currentTooltip, 100)
  currentTooltip = nil
  rootWidget.onMouseMove = nil
end

g_tooltip.init()
connect(g_app, { onTerminate = g_tooltip.terminate })
