---@diagnostic disable: undefined-global
local bossHealthWindow = nil

POSITION_TOP_LEFT = 1
POSITION_TOP_RIGHT = 2
POSITION_BOTTOM_LEFT = 3
POSITION_BOTTOM_RIGHT = 4

function init()
  g_ui.loadUI('healthboss')
  bossHealthWindow = g_ui.createWidget('bossHealthWindow', modules.game_interface.getMapPanel())
  bossHealthWindow:hide()

  setPosition(g_settings.getNumber('bossHealthBarPosition', POSITION_TOP_LEFT))

  connect(g_game, {
    onCreatureBossHealth = updateBossHealthBar,
    onGameEnd = hide,
  })
end

function setPosition(index)
  if not bossHealthWindow then return end

  bossHealthWindow:breakAnchors()
  bossHealthWindow:setMarginTop(0)
  bossHealthWindow:setMarginLeft(0)
  bossHealthWindow:setMarginRight(0)
  bossHealthWindow:setMarginBottom(0)

  if index == POSITION_TOP_RIGHT then
    bossHealthWindow:addAnchor(AnchorTop, 'parent', AnchorTop)
    bossHealthWindow:addAnchor(AnchorRight, 'parent', AnchorRight)
    bossHealthWindow:setMarginTop(30)
    bossHealthWindow:setMarginRight(30)
  elseif index == POSITION_BOTTOM_LEFT then
    bossHealthWindow:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    bossHealthWindow:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    bossHealthWindow:setMarginBottom(30)
    bossHealthWindow:setMarginLeft(30)
  elseif index == POSITION_BOTTOM_RIGHT then
    bossHealthWindow:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    bossHealthWindow:addAnchor(AnchorRight, 'parent', AnchorRight)
    bossHealthWindow:setMarginBottom(30)
    bossHealthWindow:setMarginRight(30)
  else
    bossHealthWindow:addAnchor(AnchorTop, 'parent', AnchorTop)
    bossHealthWindow:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    bossHealthWindow:setMarginTop(30)
    bossHealthWindow:setMarginLeft(30)
  end
end

function updateBossHealthBar(creatureID, hpBossPercent, lookType)
  if hpBossPercent <= 0 then
    bossHealthWindow:hide()
    return
  end

  bossHealthWindow:getChildById('bossPhoto'):setOutfit({ type = lookType })
  bossHealthWindow:getChildById('hpPercent'):setText(hpBossPercent .. '%')
  bossHealthWindow:getChildById('health_bar'):setPercent(hpBossPercent)
  bossHealthWindow:show()
end

function terminate()
  disconnect(g_game, {
    onCreatureBossHealth = updateBossHealthBar,
    onGameEnd = hide,
  })
end

function hide()
  if bossHealthWindow then
    bossHealthWindow:hide()
  end
end