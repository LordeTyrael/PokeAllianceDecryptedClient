-- Os alternatives sao destruidos em bloco pelo offline() do game_minimap; quem guarda a propria
-- lista de marcadores chega aqui com widgets ja mortos, e o destroy repetido dispara o aviso de
-- "attempt to destroy widget two times".
local function destroyIfAlive(widget)
  if widget and not widget:isDestroyed() then
    widget:destroy()
  end
end

function UIMinimap:onCreate()
  self.autowalk = true
end

function UIMinimap:resetAlternative()
  self.autowalk = true
end

function UIMinimap:onSetup()
  self.flagWindow = nil
  self.flags = {}
  self.alternatives = {}
  self.onAddAutomapFlag = function(pos, icon, description) self:addFlag(pos, icon, description) end
  self.onRemoveAutomapFlag = function(pos, icon, description) self:removeFlag(pos, icon, description) end
  connect(g_game, {
    onAddAutomapFlag = self.onAddAutomapFlag,
    onRemoveAutomapFlag = self.onRemoveAutomapFlag,
  })
end

function UIMinimap:onDestroy()
  for _,widget in pairs(self.alternatives) do
    destroyIfAlive(widget)
  end
  self.alternatives = {}
  disconnect(g_game, {
    onAddAutomapFlag = self.onAddAutomapFlag,
    onRemoveAutomapFlag = self.onRemoveAutomapFlag,
  })
  self:destroyFlagWindow()
  self.flags = {}
end

function UIMinimap:onVisibilityChange()
  if not self:isVisible() then
    self:destroyFlagWindow()
  end
end

function UIMinimap:onCameraPositionChange(cameraPos)
  if self.cross then
    self:setCrossPosition(self.cross.pos)
  end

  -- Marcadores de localizacao do Pokedex sao RELATIVOS ao andar da camera: a ancora tem de bater com
  -- ele (Minimap::getTileRect descarta pos.z ~= camera.z) e a seta indica subir/descer a partir dele.
  -- Trocar o andar da camera obriga a redesenhar; o proprio modulo ignora movimento lateral.
  --
  -- Mesmo padrao que o game_minimap ja usa para limpar esses marcadores ao fechar o fullmap
  -- (minimap.lua chama modules.game_pokedex.cleanLocationWidgets()).
  if modules.game_pokedex and modules.game_pokedex.refreshLocationWidgets then
    modules.game_pokedex.refreshLocationWidgets()
  end
end

function UIMinimap:hideFloor()
  self.floorUpWidget:hide()
  self.floorDownWidget:hide()
end

function UIMinimap:hideZoom()
  self.zoomInWidget:hide()
  self.zoomOutWidget:hide()
end

function UIMinimap:disableAutoWalk()
  self.autowalk = false
end

-- g_settings stores a position as the text "x y z", so what save() wrote as a position comes back
-- as a string and centerInPosition has nothing to cast. Accepts the table form too: older configs
-- carry it, and a live flag's pos is always one.
local function toPosition(value)
  if type(value) == 'table' then
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if x and y and z then return { x = x, y = y, z = z } end
    return nil
  end
  if type(value) ~= 'string' then return nil end
  local x, y, z = value:match('^%s*(-?%d+)%s+(-?%d+)%s+(-?%d+)%s*$')
  if not x then return nil end
  return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
end

function UIMinimap:load()
  local settings = g_settings.getNode('Minimap')
  if settings then
    if settings.flags then
      for _,flag in pairs(settings.flags) do
        self:addFlag(toPosition(flag.position), flag.icon, flag.description)
      end
    end
    self:setZoom(settings.zoom)
  end
end

function UIMinimap:save()
  local settings = { flags={} }
  for _,flag in pairs(self.flags) do
    if not flag.temporary then
      table.insert(settings.flags, {
        -- written as text so the format never depends on what type pos happens to be; toPosition
        -- above is the other half of the round trip
        position = string.format('%d %d %d', flag.pos.x, flag.pos.y, flag.pos.z),
        icon = flag.icon,
        description = flag.description,
      })
    end
  end

  settings.zoom = self:getZoom()
  g_settings.setNode('Minimap', settings)
end

local function onFlagMouseRelease(widget, pos, button)
  if button == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Delete mark'), function() widget:destroy() end)
    menu:display(pos)
    return true
  end
  return false
end

function UIMinimap:setCrossPosition(pos)
  local cross = self.cross
  if not self.cross then
    cross = g_ui.createWidget('MinimapCross', self)
    cross:setIcon('/images/game/minimap/cross')
    self.cross = cross
  end

  pos.z = self:getCameraPosition().z
  cross.pos = pos
  if pos then
    self:centerInPosition(cross, pos)
  else
    cross:breakAnchors()
  end
end

function UIMinimap:addFlag(pos, icon, description, temporary)
  if not pos or not icon then return end
  local flag = self:getFlag(pos, icon, description)
  if flag or not icon then
    return
  end
  temporary = temporary or false

  flag = g_ui.createWidget('MinimapFlag')
  self:insertChild(1, flag)
  flag.pos = pos
  flag.description = description
  flag.icon = icon
  flag.temporary = temporary
  if type(tonumber(icon)) == 'number' then
    -- MapFlags (game_minimap/mapflags.lua) troca o PNG /images/game/minimap/flagN por Font Awesome.
    -- Fallback no PNG se o indice nao existir na tabela: markType desconhecido nao pode sumir da tela.
    local flagInfo = MapFlags and MapFlags[tonumber(icon)]
    if flagInfo then
      flag:setIcon(flagInfo.source)
      if flagInfo.defaultColor then
        flag:setIconColor(flagInfo.defaultColor)
      end
    else
      flag:setIcon('/images/game/minimap/flag' .. icon)
    end
  else
    flag:setIcon(resolvepath(icon, 1))
  end
  flag:setTooltip(description)
  flag.onMouseRelease = onFlagMouseRelease
  flag.onDestroy = function() table.removevalue(self.flags, flag) end
  table.insert(self.flags, flag)
  self:centerInPosition(flag, pos)
end

function UIMinimap:deleteAllAlternativesWidgets()
  for _,widget in pairs(self.alternatives) do
    destroyIfAlive(widget)
  end
  self.alternatives = {}
end

function UIMinimap:addAlternativeWidget(widget, pos)
  widget.pos = pos
  table.insert(self.alternatives, widget)
end

function UIMinimap:addAlternativeWidgetsBatch(widgets)
  local layout = self:getLayout()
  layout:disableUpdates()
  -- Congela tambem o estado de indice dos filhos: sem isto cada insertChild refaz o estado de
  -- todos os filhos ja inseridos (uiwidget.cpp:1802), e abrir o mapa com centenas de marcadores
  -- vira O(N^2). Mesmo par ja usado por game_prey e game_store.
  self:beginBatchAdd()
  for _, widget in ipairs(widgets) do
    table.insert(self.alternatives, widget)
    self:insertChild(1, widget)
    self:centerInPosition(widget, widget.pos)
  end
  self:endBatchAdd()
  layout:enableUpdates()
  layout:update()
end

function UIMinimap:removeAlternativeWidget(widgetToRemove)
  for index = #self.alternatives, 1, -1 do
    if self.alternatives[index] == widgetToRemove then
      table.remove(self.alternatives, index)
      break
    end
  end

  destroyIfAlive(widgetToRemove)
end

--- Remove varios alternatives de uma vez. O :removeAlternativeWidget acima, chamado em laco, e
--- O(N^2) por DOIS motivos independentes:
---
---   1. ele varre self.alternatives inteiro a cada widget;
---   2. cada :destroy() desemboca em UIAnchorLayout::removeAnchors -> update(), que reprocessa
---      TODAS as ancoras restantes (uianchorlayout.cpp:127 e :254).
---
--- O (2) e o caro: com N marcadores sao N resolucoes completas de layout. Aqui a lista e varrida
--- uma vez so e as destruicoes acontecem com o layout congelado -- m_updateDisabled e um CONTADOR
--- (uilayout.h:42), entao aninhar com quem ja desabilitou e seguro --, virando UM update no fim.
function UIMinimap:removeAlternativeWidgetsBatch(widgets)
  if not widgets or #widgets == 0 then return end

  local remover = {}
  for _, widget in ipairs(widgets) do
    remover[widget] = true
  end

  local restantes = {}
  for _, widget in ipairs(self.alternatives) do
    if not remover[widget] then
      table.insert(restantes, widget)
    end
  end
  self.alternatives = restantes

  local layout = self:getLayout()
  layout:disableUpdates()
  -- O destroy passa por removeChild, que tambem refaz o estado de indice de todos os filhos
  -- (uiwidget.cpp:468). Sem o lote, fechar o mapa e O(N^2) por esse caminho mesmo com o layout
  -- congelado -- as duas travas sao independentes e precisam das duas guardas.
  self:beginBatchAdd()
  for _, widget in ipairs(widgets) do
    destroyIfAlive(widget)
  end
  self:endBatchAdd()
  layout:enableUpdates()
  layout:update()
end

function UIMinimap:setAlternativeWidgetsVisible(show)
  local layout = self:getLayout()
  layout:disableUpdates()
  self:beginBatchAdd()
  for _, widget in pairs(self.alternatives) do
    -- getParent() == self cobre os dois sentidos: no show, o widget ja pode ter entrado pelo
    -- addAlternativeWidgetsBatch (que tambem insere como filho) e reinserir so gera o aviso
    -- "attempt to insert a child again"; no hide, e a unica forma confiavel de saber se ele esta
    -- na arvore -- a varredura antiga por recursiveGetChildren() comparando getId() era O(N*M) e
    -- nem funcionava, ja que os marcadores nao tem id e id vazio bate com id vazio.
    if show then
      if widget:getParent() ~= self then
        self:insertChild(1, widget)
      end
      self:centerInPosition(widget, widget.pos)
    elseif widget:getParent() == self then
      self:removeChild(widget)
    end
  end
  self:endBatchAdd()

  -- Camada de cima. Todo alternative entra por insertChild(1, ...), entao quem entra primeiro fica
  -- na frente -- e a varredura acima usa pairs, cuja ordem Lua nao garante. Sem este passo a
  -- profundidade seria acidental. raise() manda o widget para o fim da lista de filhos (a frente)
  -- sem depender de ordem. Usado pelos rotulos de cidade, que ficam por cima dos icones.
  if show then
    for _, widget in pairs(self.alternatives) do
      if widget.alwaysOnTop then
        widget:raise()
      end
    end
  end

  layout:enableUpdates()
  layout:update()
end

function UIMinimap:onZoomChange(zoom)
  for _,widget in pairs(self.alternatives) do
    -- zoneHidden = escondido por decisao de quem criou o marcador (a legenda de zona do Pokedex),
    -- e nao pelo zoom. Sem esta saida, dar zoom devolvia a vida a tudo que estava desmarcado.
    if widget.zoneHidden then
      widget:hide()
    elseif (not widget.minZoom or widget.minZoom >= zoom) and widget.maxZoom <= zoom then
      widget:show()
    else
      widget:hide()
    end
  end
  local creatures = modules.game_minimap.getCreaturesWidgets()
  if creatures then
    for _, creature in pairs(creatures) do
      if creature and creature.widget then
        creature.widget:setScale(math.min(1, math.max(0.7, 0.5 * zoom)))
      end
    end
  end
end

function UIMinimap:getFlag(pos)
  for _,flag in pairs(self.flags) do
    if flag.pos.x == pos.x and flag.pos.y == pos.y and flag.pos.z == pos.z then
      return flag
    end
  end
  return nil
end

function UIMinimap:removeFlag(pos, icon, description)
  local flag = self:getFlag(pos)
  if flag then
    flag:destroy()
  end
end

function UIMinimap:reset()
  self:setZoom(0)
  if self.cross then
    local player = g_game.getLocalPlayer()
    local newPos = player and {x = self.cross.pos.x, y = self.cross.pos.y, z = player:getPosition().z}
    self:setCameraPosition(newPos)
  end
end

function UIMinimap:move(x, y)
  local cameraPos = self:getCameraPosition()
  local scale = self:getScale()
  if scale > 1 then scale = 1 end
  local dx = x/scale
  local dy = y/scale
  local pos = {x = cameraPos.x - dx, y = cameraPos.y - dy, z = cameraPos.z}
  self:setCameraPosition(pos)
end

function UIMinimap:onMouseWheel(mousePos, direction)
  local keyboardModifiers = g_keyboard.getModifiers()
  if direction == MouseWheelUp and keyboardModifiers == KeyboardNoModifier then
    self:zoomIn()
  elseif direction == MouseWheelDown and keyboardModifiers == KeyboardNoModifier then
    self:zoomOut()
  elseif direction == MouseWheelDown and keyboardModifiers == KeyboardCtrlModifier then
    self:floorUp(1)
  elseif direction == MouseWheelUp and keyboardModifiers == KeyboardCtrlModifier then
    self:floorDown(1)
  end
end

function UIMinimap:onMousePress(pos, button)
  if not self:isDragging() then
    self.allowNextRelease = true
  end
end

function UIMinimap:onMouseRelease(pos, button)
  if not self.allowNextRelease then return true end
  self.allowNextRelease = false

  local widget = self:getChildByPos(pos)
  if widget and widget.creature  and widget.creature:getClassName() == "UICreature" then
    return
  end

  local mapPos = self:getTilePosition(pos)
  if not mapPos then return end

  if button == MouseLeftButton then
    local player = g_game.getLocalPlayer()
    if self.autowalk then
      player:autoWalk(mapPos)
    end
    return true
  elseif button == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Create mark'), function() self:createFlagWindow(mapPos) end)
    menu:addOption(tr('Copy position'), function() g_window.setClipboardText(string.format('%d, %d, %d', mapPos.x, mapPos.y, mapPos.z)) end)
    if g_game.isGM() then
      menu:addOption(tr('Go to position'), function() g_game.talk(string.format('/goto %d, %d, %d', mapPos.x, mapPos.y, mapPos.z)) end)
    end
    menu:display(pos)
    return true
  end
  return false
end

function UIMinimap:onDragEnter(pos)
  self.dragReference = pos
  self.dragCameraReference = self:getCameraPosition()
  return true
end

-- Mouse move fires far more often than the client draws, and every setCameraPosition runs a full
-- layout pass over every marker. Coalescing to one apply per dispatcher cycle collapses that burst
-- into a single pass per frame. Deliberately not a fixed interval: a 50ms timer would cap the map at
-- 20 updates/s and read as stutter, while this keeps the drag frame-tight.
function UIMinimap:applyPendingCamera()
  self.pendingCameraEvent = nil
  local pos = self.pendingCameraPos
  self.pendingCameraPos = nil
  if pos then
    self:setCameraPosition(pos)
  end
end

function UIMinimap:onDragMove(pos, moved)
  local scale = self:getScale()
  local dx = (self.dragReference.x - pos.x)/scale
  local dy = (self.dragReference.y - pos.y)/scale
  self.pendingCameraPos = {x = self.dragCameraReference.x + dx, y = self.dragCameraReference.y + dy, z = self.dragCameraReference.z}
  if not self.pendingCameraEvent then
    -- 16ms, not addEvent: the dispatcher cycles ~224x/s (measured), so plain coalescing still
    -- applied the camera far more often than the client draws. One apply per frame is the ceiling
    -- that means anything - beyond it the work is invisible.
    self.pendingCameraEvent = scheduleEvent(function() self:applyPendingCamera() end, 16)
  end
  return true
end

function UIMinimap:onDragLeave(widget, pos)
  -- land on the last position the cursor actually reached instead of dropping a coalesced move
  if self.pendingCameraEvent then
    removeEvent(self.pendingCameraEvent)
    self:applyPendingCamera()
  end
  return true
end

function UIMinimap:onStyleApply(styleName, styleNode)
  for name,value in pairs(styleNode) do
    if name == 'autowalk' then
      self.autowalk = value
    end
  end
end

function UIMinimap:createFlagWindow(pos)
  if self.flagWindow then return end
  if not pos then return end

  self.flagWindow = g_ui.createWidget('MinimapFlagWindow', rootWidget)

  -- recursive: the otui nests these (position inside positionBox, the flags inside flagGrid), and
  -- getChildById only sees direct children
  local positionLabel = self.flagWindow:recursiveGetChildById('position')
  local description = self.flagWindow:recursiveGetChildById('description')
  local okButton = self.flagWindow:recursiveGetChildById('okButton')
  local cancelButton = self.flagWindow:recursiveGetChildById('cancelButton')

  positionLabel:setText(string.format('%i, %i, %i', pos.x, pos.y, pos.z))

  local flagRadioGroup = UIRadioGroup.create()
  for i=0,19 do
    local checkbox = self.flagWindow:recursiveGetChildById('flag' .. i)
    -- O .otui declara os botoes com id fixo; se algum faltar, pular em vez de estourar.
    if checkbox then
      checkbox.icon = i
      -- Mesmo MapFlags que o addFlag usa: o icone da JANELA tem de ser o mesmo que vai aparecer
      -- no minimapa. Antes eram duas fontes de verdade -- spritesheet aqui, PNG la.
      local flagInfo = MapFlags and MapFlags[i]
      if flagInfo then
        checkbox:setIcon(flagInfo.source)
        if flagInfo.defaultColor then
          checkbox:setIconColor(flagInfo.defaultColor)
        end
      else
        -- O .otui nao declara mais icon-source nas celulas, entao sem MapFlags elas ficariam
        -- VAZIAS. Mesmo fallback que o addFlag usa: um markType desconhecido nao pode sumir.
        checkbox:setIcon('/images/game/minimap/flag' .. i)
      end
      flagRadioGroup:addWidget(checkbox)
    end
  end

  flagRadioGroup:selectWidget(flagRadioGroup:getFirstWidget())

  local successFunc = function()
    self:addFlag(pos, flagRadioGroup:getSelectedWidget().icon, description:getText())
    self:destroyFlagWindow()
  end

  local cancelFunc = function()
    self:destroyFlagWindow()
  end

  okButton.onClick = successFunc
  cancelButton.onClick = cancelFunc

  self.flagWindow.onEnter = successFunc
  self.flagWindow.onEscape = cancelFunc

  self.flagWindow.onDestroy = function() flagRadioGroup:destroy() end
end

function UIMinimap:destroyFlagWindow()
  if self.flagWindow then
    self.flagWindow:destroy()
    self.flagWindow = nil
  end
end
