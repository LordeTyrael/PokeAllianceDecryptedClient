-- @docclass
-- Reusable progress bar built from two stacked UIWidgets sharing
-- /images/modules/progressbar_load_{bg,overlay}.
-- Use the OTML style 'AllianceProgressBar' or call setPercent(0..100) at runtime.
UIAllianceProgressBar = extends(UIWidget, "UIAllianceProgressBar")

function UIAllianceProgressBar.create()
  local bar = UIAllianceProgressBar.internalCreate()
  bar.percent = 100
  return bar
end

function UIAllianceProgressBar:onSetup()
  self:updateFill()
end

function UIAllianceProgressBar:onGeometryChange(oldRect, newRect)
  self:updateFill()
end

function UIAllianceProgressBar:setPercent(pct)
  self.percent = math.max(0, math.min(100, pct or 0))
  self:updateFill()
end

function UIAllianceProgressBar:getPercent()
  return self.percent or 0
end

function UIAllianceProgressBar:updateFill()
  local clipper = self:getChildById('clipper')
  if not clipper or clipper:isDestroyed() then return end
  local fill = clipper:getChildById('fill')
  if not fill or fill:isDestroyed() then return end

  -- -2 = 1px de borda de cada lado horizontal (o clipper já tem margin-left 1; o resto do bg
  -- aparece como borda). Vertical vem das margens do clipper no estilo.
  local fullW = math.max(0, self:getWidth() - 2)
  -- Fill is always rendered at the bar's full width so the image borders draw
  -- correctly. The clipper masks it down to the visible portion.
  fill:setWidth(fullW)

  local pct = self.percent or 0
  clipper:setWidth(math.floor(fullW * (pct / 100)))
end
