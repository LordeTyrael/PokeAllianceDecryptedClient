-- private variables
local topMenu
local hideTopBar
local fpsUpdateEvent = nil
local statusUpdateEvent = nil
local middleBarIsVisible = false
local hoverIsVisible = false
local fpsVisible = true
local buttonMenu = nil
local buttonMenuOwnerId = nil

-- private functions
local function addButton(id, description, icon, callback, panel, toggle, front, index)
  local class
  if toggle then
    class = 'TopToggleButton'
  else
    class = 'TopButton'
  end
  
  if topMenu.reverseButtons then
    front = not front
  end

  local button = panel:getChildById(id)
  if not button then
    button = g_ui.createWidget(class)
    if front then
      panel:insertChild(1, button)
    else
      panel:addChild(button)
    end
  end
  button:setId(id)
  button:setTooltip(description)
  button:setIcon(resolvepath(icon, 3))
  button.onMouseRelease = function(widget, mousePos, mouseButton)
    if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton and mouseButton ~= MouseTouch then
      callback()
      return true
    end
  end
  button.onTouchRelease = button.onMouseRelease
  if not button.index and type(index) == 'number' then
    button.index = index
  end
  return button
end

-- public functions
function init()
  connect(g_game, { onGameStart = online,
                    onGameEnd = offline,
                    onPingBack = updatePing })

  topMenu = g_ui.createWidget('TopMenu', g_ui.getRootWidget())
  hideTopBar = g_ui.createWidget('HideTopBar', g_ui.getRootWidget())
  hideTopBar.onMouseRelease = function() return true end
  hideTopBar.onHoverChange = function(self, hovered)
    if hovered then
      hideTopBar:show()
      g_effects.fadeIn(hideTopBar)
      updateHideBarIcon()
    else
      g_effects.fadeOut(hideTopBar)
      --hideTopBar:setImageSource("")
    end
  end

  if g_game.isOnline() then
    scheduleEvent(online, 10)
  end
  
  updateFps()  
  updateStatus()
  topMenu.middleGameButtonsPanel:hide()
  hideTopBar:hide()
  topMenu.fpsLabel:hide()
  topMenu.danPosition = topMenu:getPosition()
  middleBarIsVisible = false
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                       onGameEnd = offline,
                       onPingBack = updatePing })
  removeEvent(fpsUpdateEvent)
  removeEvent(statusUpdateEvent)
  hideButtonMenu()
  topMenu:destroy()
end

function online()
  if topMenu.hideIngame then
    hide()
  else
    modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'topMenu', AnchorTop)
  end
  if topMenu.onlineLabel then
    topMenu.onlineLabel:hide()
  end

  -- Restored from the previous session. The parked margin has to follow the state too: the toggle
  -- animates hideTopBar between 40 (bar open) and 0 (bar hidden), so restoring hidden without it
  -- would leave the arrow floating where the open bar used to be.
  middleBarIsVisible = g_settings.getBoolean('topmenu-middlebar-visible', true)
  topMenu.middleGameButtonsPanel:setVisible(middleBarIsVisible)
  hideTopBar:show()
  hideTopBar:setMarginTop(middleBarIsVisible and 40 or 0)
  -- No icon yet on purpose: the widget stays imageless (and so invisible) until the mouse reaches
  -- it, which is how it hides itself. onHoverChange is what paints the arrow.

  if fpsVisible then
    topMenu.fpsLabel:show()
  end
  
  showGameButtons()

  if topMenu.pingLabel then
    addEvent(function()
      if modules.client_options.getOption('showPing') and (g_game.getFeature(GameClientPing) or g_game.getFeature(GameExtendedClientPing)) then
        topMenu.pingLabel:show()
      else
        topMenu.pingLabel:hide()      
      end
    end)
  end
end

function offline()
  hideButtonMenu()
  if topMenu.hideIngame then
    show()
  end
  if topMenu.onlineLabel then
    topMenu.onlineLabel:show()
  end

  --hideGameButtons()
  if topMenu.pingLabel then
    topMenu.pingLabel:hide()
  end
  if topMenu.middleGameButtonsPanel then
    topMenu.middleGameButtonsPanel:hide()
  end

  if hideTopBar then
    hideTopBar:hide()
  end

  topMenu.fpsLabel:hide()
  middleBarIsVisible = false
  updateStatus()
end

function updateFps()
  if not topMenu.fpsLabel then return end
  fpsUpdateEvent = scheduleEvent(updateFps, 500)
  text = 'FPS\n' .. g_app.getFps()
  topMenu.fpsLabel:setText(text)
end

function updatePing(ping)
  if not topMenu.pingLabel then return end
  if g_proxy and g_proxy.getPing() > 0 then
    ping = g_proxy.getPing()
  end
  
  local text = 'Ping: '
  local color
  if ping < 0 then
    text = text .. "??"
    color = 'yellow'
  else
    text = text .. ping .. ' ms'
    if ping >= 500 then
      color = 'red'
    elseif ping >= 250 then
      color = 'yellow'
    else
      color = 'green'
    end
  end
  topMenu.pingLabel:setColor(color)
  topMenu.pingLabel:setText(text)
end

function setPingVisible(enable)
  if not topMenu.pingLabel then return end
  topMenu.pingLabel:setVisible(enable)
end

function setFpsVisible(enable)
  if not topMenu.fpsLabel then return end
  fpsVisible = true
  if g_game.isOnline() then
    topMenu.fpsLabel:setVisible(enable)
  end
end

function addLeftButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.leftButtonsPanel, false, front, index)
end

function addLeftToggleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.leftButtonsPanel, true, front, index)
end

function addRightButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.rightButtonsPanel, false, front, index)
end

function addRightToggleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.rightButtonsPanel, true, front, index)
end

function addMiddleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.MiddleButtonsPanel, false, front, index)
end

function addMiddleToggleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.middleButtonsPanel, true, front, index)
end

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- Menu de um botao da topbar (abre logo abaixo dele, centralizado)
-- ─────────────────────────────────────────────────────────────────────────────────────────────

-- Distancia entre a base da barra e o topo do menu.
local BUTTON_MENU_GAP = 10

function hideButtonMenu()
  if buttonMenu then
    local menu = buttonMenu
    buttonMenu = nil
    buttonMenuOwnerId = nil
    menu:destroy()
  end
end

function isButtonMenuVisible(ownerId)
  if not buttonMenu then return false end
  return ownerId == nil or buttonMenuOwnerId == ownerId
end

-- entries: { { id, tooltip, icon, callback }, ... }. O icone tem de ser caminho ABSOLUTO
-- (/images/... ou /modules/<mod>/...): quem resolve caminho relativo e o addButton, pelo nivel da
-- pilha do chamador, e aqui o chamador e outro modulo.
function showButtonMenu(ownerId, entries)
  hideButtonMenu()

  local owner = getButton(ownerId)
  if not owner or not entries or #entries == 0 then return nil end
  -- Um PopupMenu aberto ja detem o mouse; dois grabs simultaneos deixariam um deles preso.
  if g_ui.isMouseGrabbed() then return nil end

  buttonMenu = g_ui.createWidget('TopMenuButtonMenu', g_ui.getRootWidget())
  buttonMenuOwnerId = ownerId

  for _, entry in ipairs(entries) do
    local item = g_ui.createWidget('TopButton', buttonMenu)
    item:setId(entry.id)
    item:setTooltip(entry.tooltip)
    item:setIcon(entry.icon)
    -- onClick e nao onMouseRelease: com o mouse capturado, e o caminho que o UIPopupMenu usa e
    -- que comprovadamente chega nos filhos. Fecha ANTES do callback para soltar o grab primeiro.
    item.onClick = function()
      hideButtonMenu()
      entry.callback()
    end
  end

  -- fit-children so define a largura num evento posterior, entao centralizar uma vez so erraria;
  -- o onGeometryChange recentraliza quando a largura final chega.
  local function reposition()
    if not buttonMenu then return end
    local button = getButton(ownerId)
    local panel = topMenu.middleGameButtonsPanel
    if not button or not panel then return end
    buttonMenu:setX(math.floor(button:getX() + (button:getWidth() - buttonMenu:getWidth()) / 2))
    buttonMenu:setY(panel:getY() + panel:getHeight() + BUTTON_MENU_GAP)
  end

  buttonMenu.onGeometryChange = reposition
  buttonMenu.onDestroy = function(widget)
    widget:ungrabMouse()
    if buttonMenu == widget then
      buttonMenu = nil
      buttonMenuOwnerId = nil
    end
  end
  -- Fechar no RELEASE, nao no press, e segurar o grab pelo clique inteiro.
  --
  -- Fechando no press (como faz o UIPopupMenu) o ungrabMouse devolvia o m_mouseReceiver ao
  -- rootWidget NO MEIO do clique; o release seguinte entao descia a arvore, chegava no proprio
  -- botao dono e chamava toggleButtonMenu de novo -- o menu reabria no mesmo clique e o botao
  -- nunca conseguia fechar. Com o grab vivo no release, o widgetList sai do menu e o botao dono
  -- nem e visitado. De quebra, clique fora tambem para de vazar para o mapa.
  --
  -- Os icones nao dependem deste caminho: onClick e disparado pelo updatePressedWidget
  -- (uimanager.cpp:277), que roda ANTES do propagateOnMouseEvent no press e de novo no release.
  buttonMenu.onMousePress = function()
    return true
  end
  buttonMenu.onMouseRelease = function(widget, mousePos)
    if not widget:containsPoint(mousePos) then
      hideButtonMenu()
    end
    return true
  end

  reposition()
  buttonMenu:raise()
  buttonMenu:grabMouse()
  return buttonMenu
end

-- Devolve true se ABRIU, false se fechou.
function toggleButtonMenu(ownerId, entries)
  if isButtonMenuVisible(ownerId) then
    hideButtonMenu()
    return false
  end
  return showButtonMenu(ownerId, entries) ~= nil
end

-- Divisor vertical dentro do painel do meio. Idempotente: pode ser chamado a cada reordenacao
-- sem duplicar. Marcado com `isTopSeparator` para que quem ordena consiga distingui-lo dos botoes
-- sem depender do id.
function addMiddleSeparator(id)
  if not topMenu or not topMenu.middleGameButtonsPanel then return nil end
  local panel = topMenu.middleGameButtonsPanel
  local separator = panel:getChildById(id)
  if not separator then
    separator = g_ui.createWidget('TopMenuSeparator', panel)
    separator:setId(id)
    separator.isTopSeparator = true
  end
  return separator
end

function addLeftGameButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.leftGameButtonsPanel, false, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function addLeftGameToggleButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.leftGameButtonsPanel, true, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function addRightGameButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.rightGameButtonsPanel, false, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function addRightGameToggleButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.rightGameButtonsPanel, true, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function addMiddleGameButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.middleGameButtonsPanel, false, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function addMiddleGameToggleButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.middleGameButtonsPanel, true, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function showGameButtons()
  topMenu.leftGameButtonsPanel:show()
  topMenu.rightGameButtonsPanel:show()
  -- honours the minimised state instead of forcing it open: online() restores the saved state and
  -- then calls this, so an unconditional show() here would reopen the bar while leaving the arrow
  -- parked at the hidden margin, on top of the bar it was supposed to sit below.
  topMenu.middleGameButtonsPanel:setVisible(middleBarIsVisible)
  if modules.game_buttons then
    modules.game_buttons.takeButtons(topMenu.leftGameButtonsPanel:getChildren())
    modules.game_buttons.takeButtons(topMenu.middleGameButtonsPanel:getChildren())
    modules.game_buttons.takeButtons(topMenu.rightGameButtonsPanel:getChildren())
  end
end

function hideGameButtons()
  topMenu.leftGameButtonsPanel:hide()
  topMenu.middleGameButtonsPanel:hide()
  topMenu.rightGameButtonsPanel:hide()
end

function getButton(id)
  return topMenu:recursiveGetChildById(id)
end

function getTopMenu()
  return topMenu
end

function toggle()
  if topMenu.middleGameButtonsPanel:isVisible() then
  topMenu.middleGameButtonsPanel:hide()
  else
    topMenu.middleGameButtonsPanel:show()
  end
end

-- The arrow reflects the bar's state, not the hover: open shows the "hide" arrow, hidden shows the
-- "show" one. Global on purpose - the onHoverChange closure in init() is created before this point
-- in the file, so it can only reach this by name at call time.
function updateHideBarIcon()
  if not hideTopBar then return end
  hideTopBar:setImageSource(middleBarIsVisible
    and "/images/ui/topbuttons/icons/top_hidden"
    or "/images/ui/topbuttons/icons/top_show")
end

function toggleMidTopMenu()
  local widget = topMenu.middleGameButtonsPanel
  if middleBarIsVisible then
    --scheduleEvent(function()
    --  topMenu.middleGameButtonsPanel:hide()
    --  hideTopBar:setMarginTop(0)
    --end, 1000)
    middleBarIsVisible = false
    updateHideBarIcon()
    g_effects.slideOut(widget, 500, 0, 0, 0, -widget:getHeight())
    g_effects.slideOut(hideTopBar, 500, 0, 0, 40, 0)
  else
    middleBarIsVisible = true
    updateHideBarIcon()
    topMenu.middleGameButtonsPanel:show()
    g_effects.slideOut(widget, 500, 0, 0, -widget:getHeight(), 0)
    g_effects.slideOut(hideTopBar, 500, 0, 0, 0, 40)
  end

  -- save() right away, not just on exit: a killed or crashed client never runs terminate()
  g_settings.set('topmenu-middlebar-visible', middleBarIsVisible)
  g_settings.save()
end

function HoverHideBar()
  if hoverIsVisible then
    scheduleEvent(function()
      topMenu.hideTopBar:hide()
    end, 1000)
    hoverIsVisible = false
    --topMenu.middleGameButtonsPanel:setVisible(false)
    g_effects.fadeOut(topMenu.hideTopBar)
  else
    topMenu.middleGameButtonsPanel:setImageSource("/images/ui/topbuttons/icons/hidebar")
    topMenu.middleGameButtonsPanel:show()
    g_effects.fadeIn(topMenu.hideTopBar)
  end

end

function hide()
  topMenu:hide()
  if not topMenu.hideIngame then
    modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'parent', AnchorTop)
  end
  if modules.game_stats then
    modules.game_stats.show()
  end
end

function show()
  topMenu:show()
  if not topMenu.hideIngame then
    modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'topMenu', AnchorBottom)
  end
  if modules.game_stats then
    modules.game_stats.hide()
  end
end

function updateStatus()
  removeEvent(statusUpdateEvent)
  if not Services or not Services.status or Services.status:len() < 4 then return end
  if not topMenu.onlineLabel then return end
  if g_game.isOnline() then return end
  HTTP.postJSON(Services.status, {type="cacheinfo"}, function(data, err)
    if err then
      g_logger.warning("HTTP error for " .. Services.status .. ": " .. err) 
      statusUpdateEvent = scheduleEvent(updateStatus, 5000)
      return
    end
    if topMenu.onlineLabel then
      if data.online then
        topMenu.onlineLabel:setText(data.online)
      elseif data.playersonline then
        topMenu.onlineLabel:setText(data.playersonline .. " players online")
      end
    end
    if data.discord_online and topMenu.discordLabel then
      topMenu.discordLabel:setText(data.discord_online)
    end
    if data.discord_link and topMenu.discordLabel and topMenu.discord then
      local discordOnClick = function()
        g_platform.openUrl(data.discord_link)
      end
      topMenu.discordLabel.onClick = discordOnClick
      topMenu.discord.onClick = discordOnClick
    end
    statusUpdateEvent = scheduleEvent(updateStatus, 60000)
  end)
end