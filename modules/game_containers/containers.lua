local gameStart = 0
local updateEvent = nil
local containerTitles = {}
local localPlayerName
local titleWindow


function destroyTitleWindow()
  if titleWindow then
    titleWindow:destroy()
    titleWindow = nil
  end
end

-- container ids are keyed by bag uuid, so unlike the fixed miniwindow ids their key space grows
-- with play; it must not share the MiniWindows node
local CONTAINER_SETTINGS_NODE = UIMiniWindow.SETTINGS_NODES.containers

local function containerPersistentId(uuid)
  return 'container_' .. uuid
end

-- one-time: move container entries out of MiniWindows, where one permanent entry per bag uuid grew
-- until it tripped that node's restore guard and reset every panel's placement. Pre-uuid containerN
-- and volatile container_tmp_N ids are dropped, not moved; heights are dropped because they predate
-- the user-resize gate in UIMiniWindow:onHeightChange.
local function migrateContainerSettings()
  local config = g_settings.getConfig("containers.otml")
  if config:getValue("ContainerSettingsMigrated") == "1" then
    return
  end

  local mini = g_settings.getNode('MiniWindows')
  if mini then
    local containers = g_settings.getNode(CONTAINER_SETTINGS_NODE) or {}
    for id, entry in pairs(mini) do
      local key = tostring(id)
      if key:find('^container_tmp_') or key:find('^container%d+$') then
        mini[id] = nil
      elseif key:find('^container_') and type(entry) == 'table' then
        entry.height = nil
        containers[key] = entry
        mini[id] = nil
      end
    end
    g_settings.setNode('MiniWindows', mini)
    g_settings.setNode(CONTAINER_SETTINGS_NODE, containers)
    g_settings.save()
  end

  config:setValue("ContainerSettingsMigrated", "1")
  config:save()
end

local function pruneTemporaryContainerSettings()
  local settings = g_settings.getNode(CONTAINER_SETTINGS_NODE)
  if not settings then return end

  local pruned = false
  for id in pairs(settings) do
    if tostring(id):find('^container_tmp_') then
      settings[id] = nil
      pruned = true
    end
  end

  if pruned then
    g_settings.setNode(CONTAINER_SETTINGS_NODE, settings)
    g_settings.save()
  end
end

function init()
  connect(Container, { onOpen = onContainerOpen,
                       onClose = onContainerClose,
                       onSizeChange = onContainerChangeSize,
                       onUpdateItem = onContainerUpdateItem })
  connect(g_game, {
    onGameStart = markStart,
    onGameEnd = onGameEnd
  })

  migrateContainerSettings()
  pruneTemporaryContainerSettings()
  reloadContainers()
end

function terminate()
  disconnect(Container, { onOpen = onContainerOpen,
                          onClose = onContainerClose,
                          onSizeChange = onContainerChangeSize,
                          onUpdateItem = onContainerUpdateItem })
  disconnect(g_game, {
    onGameStart = markStart,
    onGameEnd = onGameEnd
  })

  destroyTitleWindow()
end

function reloadContainers()
  clean()
  for _,container in pairs(g_game.getContainers()) do
    onContainerOpen(container)
  end
end

function clean()
  for containerid, container in pairs(g_game.getContainers()) do
    destroy(container)
  end
end

-- Container::onClose e' disparado tambem pelo logout (game.cpp:111), onde a posicao guardada tem de
-- sobreviver. O onGameEnd do Lua roda antes desse laco (game.cpp:241), entao a flag chega a tempo.
local gameEnding = false

local function forgetContainerSettings(window)
  -- window.save e' false para bag sem uuid: essas nunca foram persistidas.
  if not window or not window.save then return end

  local id = window:getId()
  local settings = g_settings.getNode(CONTAINER_SETTINGS_NODE)
  if not settings or not settings[id] then return end

  settings[id] = nil
  g_settings.setNode(CONTAINER_SETTINGS_NODE, settings)
  g_settings.save()
end

function markStart()
  gameEnding = false
  gameStart = g_clock.millis()
  local config = g_settings.getConfig("containers.otml")
  containerTitles = config:getNode("ContainerTitlesNew") or {}
  local player = g_game.getLocalPlayer()
  if player then
    localPlayerName = player:getName()
  end
end

function onGameEnd()
  gameEnding = true
  local config = g_settings.getConfig("containers.otml")
  config:setNode("ContainerTitlesNew", containerTitles)
  config:save()
  pruneTemporaryContainerSettings()
  destroyTitleWindow()
  clean()
end

function destroy(container)
  if container.window then
    container.window:destroy()
    container.window = nil
    container.itemsPanel = nil
  end
end

function refreshContainerItems(container)
  for slot = 0, container:getCapacity() - 1 do
    local itemWidget = container.itemsPanel:getChildById('item' .. slot)
    local shader = ""
    if container:getItem(slot) then
      shader = container:getItem(slot):getShader()
    end
    itemWidget:setItem(container:getItem(slot))
    itemWidget:setItemShader(shader)
  end

  if container:hasPages() then
    refreshContainerPages(container)
  end
end

function toggleContainerPages(containerWindow, hasPages)
  if hasPages == containerWindow.pagePanel:isOn() then
    return
  end
  containerWindow.pagePanel:setOn(hasPages)
  if hasPages then
    containerWindow.miniwindowScrollBar:setMarginTop(containerWindow.miniwindowScrollBar:getMarginTop() + containerWindow.pagePanel:getHeight())
    containerWindow.contentsPanel:setMarginTop(containerWindow.contentsPanel:getMarginTop() + containerWindow.pagePanel:getHeight())  
  else  
    containerWindow.miniwindowScrollBar:setMarginTop(containerWindow.miniwindowScrollBar:getMarginTop() - containerWindow.pagePanel:getHeight())
    containerWindow.contentsPanel:setMarginTop(containerWindow.contentsPanel:getMarginTop() - containerWindow.pagePanel:getHeight())
  end
end

function refreshContainerPages(container)
  local currentPage = 1 + math.floor(container:getFirstIndex() / container:getCapacity())
  local pages = 1 + math.floor(math.max(0, (container:getSize() - 1)) / container:getCapacity())
  container.window:recursiveGetChildById('pageLabel'):setText(tr('Page %i of %i', currentPage, pages))

  local prevPageButton = container.window:recursiveGetChildById('prevPageButton')
  if currentPage == 1 then
    prevPageButton:setEnabled(false)
  else
    prevPageButton:setEnabled(true)
    prevPageButton.onClick = function() g_game.seekInContainer(container:getId(), container:getFirstIndex() - container:getCapacity()) end
  end

  local nextPageButton = container.window:recursiveGetChildById('nextPageButton')
  if currentPage >= pages then
    nextPageButton:setEnabled(false)
  else
    nextPageButton:setEnabled(true)
    nextPageButton.onClick = function() g_game.seekInContainer(container:getId(), container:getFirstIndex() + container:getCapacity()) end
  end
  
  local pagePanel = container.window:recursiveGetChildById('pagePanel')
  if pagePanel then
    pagePanel.onMouseWheel = function(widget, mousePos, mouseWheel)
      if pages == 1 then return end
      if mouseWheel == MouseWheelUp then
        return prevPageButton.onClick()
      else
        return nextPageButton.onClick()
      end
    end
  end
end

local function saveTitles()
  local config = g_settings.getConfig("containers.otml")
  config:setNode("ContainerTitlesNew", containerTitles)
  config:save()
end

local function getTitleEntry(container)
  if not localPlayerName then return nil end
  local uuid = container:getUUID()
  if not uuid or uuid == "" then return nil end
  local byPlayer = containerTitles[localPlayerName]
  local entry = byPlayer and byPlayer[uuid] or nil
  if entry and entry.title ~= nil then
    entry.title = tostring(entry.title)
  end
  return entry
end

local function getContainerDisplayName(container)
  local realName = container:getName()
  realName = realName:sub(1, 1):upper() .. realName:sub(2)
  local entry = getTitleEntry(container)
  local full = realName
  if entry and entry.title and entry.title ~= "" then
    full = entry.showReal and (entry.title .. " (" .. realName .. ")") or entry.title
  end
  local maxLen = 14
  local display = full
  if #display > maxLen then
    display = display:sub(1, maxLen) .. "..."
  end
  return display, full
end

local function setMiniwindowTitle(label, container)
  if not label then return end
  local display, full = getContainerDisplayName(container)
  label:setText(display)
  label:setTooltip(full ~= display and full or nil)
end

local function applyContainerTitle(container)
  if not container.window then return end
  setMiniwindowTitle(container.window.miniwindowName, container)
end

local function clearContainerTitle(container)
  if not localPlayerName then return end
  local uuid = container:getUUID()
  if not uuid or uuid == "" then return end
  if containerTitles[localPlayerName] then
    containerTitles[localPlayerName][uuid] = nil
  end
  saveTitles()
  applyContainerTitle(container)
end

local function setContainerTitle(container, text, showReal)
  if not localPlayerName then return end
  local uuid = container:getUUID()
  if not uuid or uuid == "" then return end
  text = text:trim()
  if text == "" then
    return clearContainerTitle(container)
  end
  if not containerTitles[localPlayerName] then
    containerTitles[localPlayerName] = {}
  end
  containerTitles[localPlayerName][uuid] = { title = text, showReal = showReal and true or false }
  saveTitles()
  applyContainerTitle(container)
end

local function openTitleDialog(container)
  destroyTitleWindow()

  local entry = getTitleEntry(container)
  titleWindow = g_ui.displayUI('bagtitle')
  if not titleWindow then
    return
  end
  titleWindow:raise()

  local titleEdit = titleWindow:getChildById('titleText')
  local showRealCheck = titleWindow:getChildById('checkBoxShowReal')
  local okButton = titleWindow:getChildById('buttonOK')
  local cancelButton = titleWindow:getChildById('buttonCancel')

  titleEdit:setMaxLength(30)
  if entry then
    titleEdit:setText(entry.title or '')
    showRealCheck:setChecked(entry.showReal and true or false)
  end
  titleEdit:focus()

  local save = function()
    setContainerTitle(container, titleEdit:getText(), showRealCheck:isChecked())
    destroyTitleWindow()
  end

  cancelButton.onClick = destroyTitleWindow
  okButton.onClick = save
  titleWindow.onEscape = destroyTitleWindow
  titleWindow.onEnter = save
end

function onContainerOpen(container, previousContainer, uuid)
  -- A normalizacao vem ANTES de qualquer uso: o reloadContainers() chama esta funcao com um
  -- argumento so, entao previousContainer e uuid chegam nil por ali.
  if not uuid then
    uuid = ""
  end

  if not localPlayerName then
    return
  end

  -- Stable id so the framework's native MiniWindows persistence (dock parent, index,
  -- position, height) keys off the container's uuid instead of the volatile,
  -- server-assigned containerId. Uuid-less containers get a unique, non-persistent id.
  local windowId = (uuid ~= "") and containerPersistentId(uuid) or ("container_tmp_" .. container:getId())


  local containerWindow
  local navigationParent
  local navigationIndex
  local navigationPos
  if previousContainer then
    local oldWindow = previousContainer.window
    navigationParent = oldWindow and oldWindow:getParent() or modules.game_interface.getRealContainerPanel()
    navigationIndex = oldWindow and navigationParent:getChildIndex(oldWindow) or nil
    navigationPos = oldWindow and oldWindow:getPosition() or nil
    if oldWindow then
      -- A bag anterior deixa de estar aberta: quem herda a vaga e' a nova, entao o historico so
      -- guarda a que ficou. Tem de ser aqui e nao no onContainerClose dela, que chega depois com
      -- window ja nil e sem id para remover.
      forgetContainerSettings(oldWindow)
      oldWindow:destroy()
    end
    previousContainer.window = nil
    previousContainer.itemsPanel = nil

    containerWindow = g_ui.createWidget('ContainerWindow', navigationParent)
    if navigationIndex and navigationParent:getClassName() == 'UIMiniWindowContainer' then
      -- not insertChild: it refuses a widget that is already a child, and createWidget parented this one
      navigationParent:moveChildToIndex(containerWindow, navigationIndex)
    elseif navigationPos then
      containerWindow:setPosition(navigationPos)
    end
  else
    containerWindow = g_ui.createWidget('ContainerWindow', modules.game_interface.getRealContainerPanel())
  end

  containerWindow.settingsNode = CONTAINER_SETTINGS_NODE
  containerWindow.save = uuid ~= ""
  containerWindow.uuid = uuid
  containerWindow:setId(windowId)

  containerWindow:setBorderWidth(2)
  containerWindow:setBorderColor("#FFFFFF")
  scheduleEvent(function()
    if containerWindow then
      containerWindow:setBorderWidth(0)
    end
  end, 300)

  containerWindow.containerId = container:getId()

  local containerPanel = containerWindow:getChildById('contentsPanel')
  local containerItemWidget = containerWindow:getChildById('miniwindowIcon')
  containerWindow.onClose = function()
    g_game.close(container)
    containerWindow:hide()
  end
  containerWindow.onDrop = function(containerWindow, widget, mousePos)
    if containerPanel:getChildByPos(mousePos) then
      return false
    end
    local child = containerPanel:getChildByIndex(-1)
    if child then
      child:onDrop(widget, mousePos, true)        
    end
  end

  -- this disables scrollbar auto hiding
  local scrollbar = containerWindow:getChildById('miniwindowScrollBar')
  scrollbar:mergeStyle({ ['$!on'] = { }})

  local upButton = containerWindow:getChildById('upButton')
  upButton.onClick = function()
    g_game.openParent(container)
  end
  upButton:setVisible(container:hasParent())


  setMiniwindowTitle(containerWindow.miniwindowName, container)

  containerItemWidget:setItem(container:getContainerItem())

  containerPanel:destroyChildren()
  for slot=0,container:getCapacity()-1 do
    local itemWidget = g_ui.createWidget('ContainerItem', containerPanel)
    itemWidget:setId('item' .. slot)
    local shader = ""
    if container:getItem(slot) then
      shader = container:getItem(slot):getShader()
    end
    itemWidget:setItemShader(shader)
    itemWidget:setItem(container:getItem(slot))
    itemWidget:setMargin(0)
    itemWidget.position = container:getSlotPosition(slot)

    if not container:isUnlocked() then
      itemWidget:setBorderColor('red')
    end
  end

  container.window = containerWindow
  container.itemsPanel = containerPanel

  toggleContainerPages(containerWindow, container:hasPages())
  refreshContainerPages(container)

  local layout = containerPanel:getLayout()
  local cellSize = layout:getCellSize()
  containerWindow:setContentMinimumHeight(cellSize.height)
  containerWindow:setContentMaximumHeight(cellSize.height*layout:getNumLines())

  if container:hasPages() then
    local height = containerWindow.miniwindowScrollBar:getMarginTop() + containerWindow.pagePanel:getHeight()+17
    if containerWindow:getHeight() < height then
      containerWindow:setHeight(height)
    end
  end

  containerWindow:setWidth(198)
  local savedHeight = containerWindow:getSettings('height')
  if not savedHeight then
    local filledLines = math.max(math.ceil(container:getItemsCount() / layout:getNumColumns()), 1)
    containerWindow:setContentHeight(filledLines * cellSize.height)
  end
  containerWindow:setup()
  if savedHeight and not containerWindow:isOn() then
    containerWindow:setHeight(savedHeight)
  end

  -- navigating in place must not move the window: setup() restores the placement saved
  -- under the new container's id, which would drop it onto whatever slot that bag last used
  if previousContainer and navigationParent and not navigationParent:isDestroyed() then
    -- a bag parked outside a column is still meant to dock on the next drag, so only the docked side
    -- is recorded; leaving the key unset lets setup() derive the rest
    containerWindow.floating = false
    if navigationParent:getClassName() == 'UIMiniWindowContainer' then
      containerWindow:setSettings({floating = false})
    end
    if containerWindow:getParent() ~= navigationParent then
      navigationParent:addChild(containerWindow)
    end
    if navigationParent:getClassName() == 'UIMiniWindowContainer' then
      if navigationIndex then
        navigationParent:moveChildToIndex(containerWindow, navigationIndex)
      end
      navigationParent:saveChildren()
    elseif navigationPos then
      containerWindow:setPosition(navigationPos)
      containerWindow:saveParent(navigationParent)
    end
  end

  DockableWindow.register(containerWindow, {
    buildMenu = function(menu, window)
      local ctr = g_game.getContainer(window.containerId)
      if not ctr or ctr:getUUID() == "" then return end
      local entry = getTitleEntry(ctr)
      menu:addOption(entry and tr('Edit title') or tr('Set title'), function()
        openTitleDialog(ctr)
      end)
      if entry then
        menu:addOption(tr('Clear title'), function()
          clearContainerTitle(ctr)
        end)
      end
    end
  })
end

function onContainerClose(container)
  -- Tres caminhos disparam este sinal. O logout (game.cpp:111) tem de preservar o historico, e e'
  -- coberto pelo gameEnding. A navegacao (game.cpp:378) tambem esquece a bag anterior, mas ja foi
  -- tratada no onContainerOpen e chega aqui com window nil. Sobra o fechamento real (game.cpp:389).
  if not gameEnding and container.window then
    forgetContainerSettings(container.window)
  end
  destroy(container)
end

function onContainerChangeSize(container, size)
  if not container.window then return end
  refreshContainerItems(container)
end

function onContainerUpdateItem(container, slot, item, oldItem)
  if not container.window then return end
  local itemWidget = container.itemsPanel:getChildById('item' .. slot)
  itemWidget:setItemShader(item:getShader())
  itemWidget:setItem(item)
end

