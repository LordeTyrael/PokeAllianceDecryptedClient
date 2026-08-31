vipWindow = nil
vipButton = nil
addVipWindow = nil
editVipWindow = nil
vipInfo = {}

local VIP_SIZE = {
  compact = { row = 22, rowDesc = 36, icon = 16, nameFont = 'poppins semibold 11' },
  normal  = { row = 30, rowDesc = 44, icon = 24, nameFont = 'poppins semibold 12' },
  large   = { row = 38, rowDesc = 52, icon = 32, nameFont = 'poppins semibold 12' },
}

modules.client_hotkeys.registerHotkeyCallback("VIPLIST",
  function(actionName, action, keyInfo, chatState, keyType)
    if vipButton and keyType == "primaryKey" and chatState == "chatDisabled" then
      vipButton:setTooltip(tr("VIP List (%s)", keyInfo.key))
    end
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        toggle()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

function init()
  connect(g_game, { onGameStart = refresh,
                    onGameEnd = clear,
                    onAddVip = onAddVip,
                    onVipStateChange = onVipStateChange })


  vipButton = modules.client_topmenu.addMiddleGameToggleButton('vipListButton', tr('VIP List') .. ' (Ctrl+F)', '/images/ui/topbuttons/icons/viplist', toggle, false, 3)
  vipButton:setOn(true)
  vipWindow = g_ui.loadUI('viplist', modules.game_interface.getRightPanel())

  loadVipInfo()
  refresh()
  vipWindow:setup()
  DockableWindow.register(vipWindow, {buildMenu = function(menu) buildVipOptions(menu) end})
end

function terminate()
  disconnect(g_game, { onGameStart = refresh,
                       onGameEnd = clear,
                       onAddVip = onAddVip,
                       onVipStateChange = onVipStateChange })

  saveVipInfo()

  if addVipWindow then
    addVipWindow:destroy()
  end

  if editVipWindow then
    editVipWindow:destroy()
  end

  vipWindow:destroy()
  vipButton:destroy()
end

function loadVipInfo()
  local settings = g_settings.getNode('VipList')
  if not settings then
    vipInfo = {}
    return
  end
  vipInfo = settings['VipInfo'] or {}
end

function saveVipInfo()
  settings = {}
  settings['VipInfo'] = vipInfo
  g_settings.mergeNode('VipList', settings)
end


function refresh()
  clear()
  for id,vip in pairs(g_game.getVips()) do
    onAddVip(id, unpack(vip))
  end

  insertSectionLabels()
  vipWindow:setContentMinimumHeight(VIP_SIZE[getEntrySize()].row)
end

function insertSectionLabels()
  local vipList = vipWindow:getChildById('contentsPanel')

  for i = vipList:getChildCount(), 1, -1 do
    local child = vipList:getChildByIndex(i)
    if not child.vipState then
      child:destroy()
    end
  end

  local children = vipList:getChildren()
  local onlineInserted = false
  local offlineInserted = false

  for i = 1, #children do
    local child = children[i]
    if child.vipState then
      if child.vipState == VipState.Online and not onlineInserted then
        local label = g_ui.createWidget('VipSectionLabel')
        label:setId('sectionOnline')
        label.sectionText:setText(tr('Friends Online'))
        connect(label, { onMousePress = onSectionPress })
        vipList:insertChild(i, label)
        onlineInserted = true
      elseif child.vipState ~= VipState.Online and not offlineInserted then
        local label = g_ui.createWidget('VipSectionLabel')
        label:setId('sectionOffline')
        label.sectionText:setText(tr('Friends Offline'))
        connect(label, { onMousePress = onSectionPress })
        vipList:insertChild(i + (onlineInserted and 1 or 0), label)
        offlineInserted = true
      end
    end
  end
end

function onSectionPress(widget, mousePos, mouseButton)
  if mouseButton ~= MouseLeftButton then return false end
  toggleSection(widget)
  return true
end

function toggleSection(label)
  if not label or not vipWindow then return end
  local online = label:getId() == 'sectionOnline'
  local collapsed = not (label.collapsed and true or false)
  label.collapsed = collapsed

  local arrow = label:recursiveGetChildById('sectionArrow')
  if arrow then
    arrow:setIcon(collapsed and '@fa solid 8 f0da' or '@fa solid 8 f0d7')
  end

  local hidingOffline = isHiddingOffline()
  local vipList = vipWindow:getChildById('contentsPanel')
  for _, child in ipairs(vipList:getChildren()) do
    if child.vipState ~= nil then
      local matches = (online and child.vipState == VipState.Online) or (not online and child.vipState ~= VipState.Online)
      if matches then
        if collapsed then
          child:setVisible(false)
        elseif not online and hidingOffline then
          child:setVisible(false)
        else
          child:setVisible(true)
        end
      end
    end
  end
end

function clear()
  local vipList = vipWindow:getChildById('contentsPanel')
  vipList:destroyChildren()
end

function toggle()
  if vipButton:isOn() then
    vipWindow:close()
    vipButton:setOn(false)
  else
    vipWindow:open()
    vipButton:setOn(true)
  end
end

function onMiniWindowClose()
  vipButton:setOn(false)
end

function createAddWindow()
  if not addVipWindow then
    addVipWindow = g_ui.displayUI('addvip')
  end
end

function createEditWindow(widget)
  if editVipWindow then
    return
  end

  editVipWindow = g_ui.displayUI('editvip')

  local name = widget:recursiveGetChildById("playerName"):getText()
  local id = widget:getId():sub(4)

  local okButton = editVipWindow:getChildById('buttonOK')
  local cancelButton = editVipWindow:getChildById('buttonCancel')

  local nameLabel = editVipWindow:getChildById('nameLabel')
  nameLabel:setText(name)

  local descriptionText = editVipWindow:getChildById('descriptionText')
  descriptionText:appendText(widget:getTooltip())

  local notifyCheckBox = editVipWindow:getChildById('checkBoxNotify')
  notifyCheckBox:setChecked(widget.notifyLogin)

  local iconRadioGroup = UIRadioGroup.create()
  for i = VipIconFirst, VipIconLast do
    iconRadioGroup:addWidget(editVipWindow:recursiveGetChildById('icon' .. i))
  end
  iconRadioGroup:selectWidget(editVipWindow:recursiveGetChildById('icon' .. widget.iconId))

  local cancelFunction = function()
    editVipWindow:destroy()
    iconRadioGroup:destroy()
    editVipWindow = nil
  end

  local saveFunction = function()
    local vipList = vipWindow:getChildById('contentsPanel')
    if not widget or not vipList:hasChild(widget) then
      cancelFunction()
      return
    end

    local name = widget:recursiveGetChildById("playerName"):getText()
    local state = widget.vipState
    local description = descriptionText:getText()
    local iconId = tonumber(iconRadioGroup:getSelectedWidget():getId():sub(5))
    local notify = notifyCheckBox:isChecked()
    local trainerId = widget.trainerId

    if g_game.getFeature(GameAdditionalVipInfo) then
      g_game.editVip(tonumber(id), description, iconId, notify)
    end

    if notify ~= false or #description > 0 or iconId > 0 then
      vipInfo[id] = {description = description, iconId = iconId, notifyLogin = notify}
    else
      vipInfo[id] = nil
    end
    saveVipInfo()
    g_settings.save()

    widget:destroy()
    onAddVip(id, name, state, description, iconId, notify, trainerId)

    editVipWindow:destroy()
    iconRadioGroup:destroy()
    editVipWindow = nil
  end

  cancelButton.onClick = cancelFunction
  okButton.onClick = saveFunction

  editVipWindow.onEscape = cancelFunction
  editVipWindow.onEnter = saveFunction
end

function destroyAddWindow()
  addVipWindow:destroy()
  addVipWindow = nil
end

function addVip()
  g_game.addVip(addVipWindow:getChildById('name'):getText())
  destroyAddWindow()
end

function removeVip(widgetOrName)
  if not widgetOrName then
    return
  end

  local widget
  local vipList = vipWindow:getChildById('contentsPanel')
  if type(widgetOrName) == 'string' then
    local entries = vipList:getChildren()
    for i = 1, #entries do
      local nameWidget = entries[i]:recursiveGetChildById("playerName")
      if nameWidget and nameWidget:getText():lower() == widgetOrName:lower() then
        widget = entries[i]
        break
      end
    end
    if not widget then
      return
    end
  else
    widget = widgetOrName
  end

  if widget then
    local id = widget:getId():sub(4)
    g_game.removeVip(id)
    vipList:removeChild(widget)
    if vipInfo[id] then
      vipInfo[id] = nil
      saveVipInfo()
      g_settings.save()
    end

    -- Update section labels after removal
    local childrenCount = vipList:getChildCount()
    for i=childrenCount, 1, -1 do
      local child = vipList:getChildByIndex(i)
      if not child.vipState then
        child:destroy()
      end
    end
    insertSectionLabels()
  end
end

function hideOffline(state)
  settings = {}
  settings['hideOffline'] = state
  g_settings.mergeNode('VipList', settings)

  refresh()
end

function isHiddingOffline()
  local settings = g_settings.getNode('VipList')
  if not settings then
    return false
  end
  return settings['hideOffline']
end

function getSortedBy()
  local settings = g_settings.getNode('VipList')
  if not settings or not settings['sortedBy'] then
    return 'status'
  end
  return settings['sortedBy']
end

function sortBy(state)
  settings = {}
  settings['sortedBy'] = state
  g_settings.mergeNode('VipList', settings)

  refresh()
end

function getEntrySize()
  local settings = g_settings.getNode('VipList')
  if not settings or not settings['entrySize'] or not VIP_SIZE[settings['entrySize']] then
    return 'normal'
  end
  return settings['entrySize']
end

function setEntrySize(size)
  g_settings.mergeNode('VipList', { entrySize = size })
  g_settings.save()
  refresh()
end

function isShowingCommentIcon()
  local settings = g_settings.getNode('VipList')
  if not settings or settings['showCommentIcon'] == nil then
    return true
  end
  return settings['showCommentIcon']
end

function setShowCommentIcon(state)
  g_settings.mergeNode('VipList', { showCommentIcon = state })
  g_settings.save()
  refresh()
end

function isShowingAvatar()
  local settings = g_settings.getNode('VipList')
  if not settings or settings['showAvatar'] == nil then
    return true
  end
  return settings['showAvatar']
end

function setShowAvatar(state)
  g_settings.mergeNode('VipList', { showAvatar = state })
  g_settings.save()
  refresh()
end

function onAddVip(id, name, state, description, iconId, notify, playerIcon)
  if not name or name:len() == 0 then
    return
  end
  local vipList = vipWindow:getChildById('contentsPanel')
  
  -- Clear existing section labels before sorting/inserting
  local childrenCount = vipList:getChildCount()
  for i=childrenCount, 1, -1 do
    local child = vipList:getChildByIndex(i)
    if not child.vipState then
      child:destroy()
    end
  end

  childrenCount = vipList:getChildCount()
  for i=1,childrenCount do
    local child = vipList:getChildByIndex(i)
    local nameWidget = child:recursiveGetChildById("playerName")
    if nameWidget and nameWidget:getText() == name then
      insertSectionLabels()
      return -- don't add duplicated vips
    end
  end
  
  
  local widget = g_ui.createWidget('VipListItem')
  widget.onMousePress = onVipListLabelMousePress
  widget:setId('vip' .. id)

  local trainerId = widget:recursiveGetChildById("playerIcon")
  trainerId:setImageSource(string.format("/modules/game_trainer/images/icons/%s", playerIcon))

  local label = widget:recursiveGetChildById("playerName")
  label:setText(name)

  local descLabel = widget:recursiveGetChildById("playerDescription")
  local tmpVipInfo
  if g_game.getFeature(GameAdditionalVipInfo) and ((description and #description > 0) or (iconId and iconId > 0)) then
    tmpVipInfo = { description = description, iconId = iconId, notifyLogin = notify }
  else
    tmpVipInfo = vipInfo[tostring(id)]
  end
  widget.iconId = 0
  widget.trainerId = playerIcon
  widget.notifyLogin = false
  local hasDescription = false
  if tmpVipInfo then
    if tmpVipInfo.iconId then
      widget.iconId = tmpVipInfo.iconId
      local starIcon = widget:recursiveGetChildById("starIcon")
      if starIcon and tmpVipInfo.iconId > 0 then
        starIcon:setImageClip(torect((tmpVipInfo.iconId * 12) .. ' 0 12 12'))
        starIcon:setVisible(true)
      end
    end
    if tmpVipInfo.description and #tmpVipInfo.description > 0 then
      widget:setTooltip(tmpVipInfo.description)
      if descLabel then descLabel:setText(tmpVipInfo.description) end
      hasDescription = true
    end
    widget.notifyLogin = tmpVipInfo.notifyLogin or false
  end

  local preset = VIP_SIZE[getEntrySize()]
  local showAvatar = isShowingAvatar()
  local showCommentIcon = isShowingCommentIcon()
  local effectiveDesc = hasDescription and showCommentIcon

  local iconClip = widget:recursiveGetChildById("playerIconClip")
  if iconClip then
    iconClip:setVisible(showAvatar)
    if showAvatar then
      iconClip:setWidth(preset.icon)
      iconClip:setHeight(preset.icon)
      iconClip:setImageSize(tosize(preset.icon .. ' ' .. preset.icon))
    end
  end

  if not showCommentIcon then
    local starIcon = widget:recursiveGetChildById("starIcon")
    if starIcon then starIcon:setVisible(false) end
  end

  label:setFont(preset.nameFont)
  label:breakAnchors()
  if showAvatar then
    label:addAnchor(AnchorLeft, 'playerIconClip', AnchorRight)
  else
    label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  end
  label:setMarginLeft(10)
  if effectiveDesc then
    label:addAnchor(AnchorTop, 'parent', AnchorTop)
    label:setMarginTop(5)
  else
    label:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    label:setMarginTop(0)
  end

  if descLabel then descLabel:setVisible(effectiveDesc) end

  widget:setHeight(effectiveDesc and preset.rowDesc or preset.row)

  if state == VipState.Online then
    label:setColor('#00ff00')
  elseif state == VipState.Pending then
    label:setColor('#ffca38')
  else
    label:setColor('#ff0000')
  end

  widget.vipState = state

  widget:setPhantom(false)
  connect(widget, { onDoubleClick = function ()
    g_game.openPrivateChannel(name) return true end
  })

  if state == VipState.Offline and isHiddingOffline() then
    widget:setVisible(false)
  end

  local nameLower = name:lower()
  local childrenCount = vipList:getChildCount()

  for i=1,childrenCount do
    local child = vipList:getChildByIndex(i)
    if not child.vipState then
      -- skip section label widgets
    elseif (state == VipState.Online and child.vipState ~= VipState.Online and getSortedBy() == 'status')
        or (widget.iconId > child.iconId and getSortedBy() == 'type') then
      vipList:insertChild(i, widget)
      insertSectionLabels()
      return
    end

    if (((state ~= VipState.Online and child.vipState ~= VipState.Online) or (state == VipState.Online and child.vipState == VipState.Online)) and getSortedBy() == 'status')
        or (widget.iconId == child.iconId and getSortedBy() == 'type') or getSortedBy() == 'name' then

      local childText = child:recursiveGetChildById("playerName"):getText():lower()
      local length = math.min(childText:len(), nameLower:len())

      for j=1,length do
        if nameLower:byte(j) < childText:byte(j) then
          vipList:insertChild(i, widget)
          insertSectionLabels()
          return
        elseif nameLower:byte(j) > childText:byte(j) then
          break
        elseif j == nameLower:len() then -- We are at the end of nameLower, and its shorter than childText, thus insert before
          vipList:insertChild(i, widget)
          insertSectionLabels()
          return
        end
      end
    end
  end

  vipList:insertChild(childrenCount+1, widget)
  insertSectionLabels()
end

function onVipStateChange(id, state, playerIcon)
    local vipList = vipWindow:getChildById('contentsPanel')
    local label = vipList:getChildById('vip' .. id)
    if not label then
      return
    end
    local name = label:recursiveGetChildById("playerName"):getText()
    local description = label:getTooltip()
    local iconId = label.iconId
    local notify = label.notifyLogin
    label:destroy()

    onAddVip(id, name, state, description, iconId, notify, playerIcon)

    if notify and state ~= VipState.Pending then
        modules.game_textmessage.displayFailureMessage(tr('%s has logged %s.', name, (state == VipState.Online and 'in' or 'out')))
    end
end

function displaySizeMenu()
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  local current = getEntrySize()
  local sizes = { { 'compact', tr('Compact') }, { 'normal', tr('Normal') }, { 'large', tr('Large') } }
  for _, s in ipairs(sizes) do
    local labelText = s[2]
    if s[1] == current then
      labelText = labelText .. ' ' .. tr('(current)')
    end
    menu:addOption(labelText, function() setEntrySize(s[1]) end)
  end
  menu:display(g_window.getMousePosition())
end

function buildVipOptions(menu)
  menu:addOption(tr('Add new VIP'), function() createAddWindow() end)

  menu:addSeparator()
  menu:addOption(tr('Entry size...'), function() displaySizeMenu() end)
  if isShowingCommentIcon() then
    menu:addOption(tr('Hide comment & icon'), function() setShowCommentIcon(false) end)
  else
    menu:addOption(tr('Show comment & icon'), function() setShowCommentIcon(true) end)
  end
  if isShowingAvatar() then
    menu:addOption(tr('Hide avatar'), function() setShowAvatar(false) end)
  else
    menu:addOption(tr('Show avatar'), function() setShowAvatar(true) end)
  end

  menu:addSeparator()
  if not isHiddingOffline() then
    menu:addOption(tr('Hide Offline'), function() hideOffline(true) end)
  else
    menu:addOption(tr('Show Offline'), function() hideOffline(false) end)
  end

  if not(getSortedBy() == 'name') then
    menu:addOption(tr('Sort by name'), function() sortBy('name') end)
  end

  if not(getSortedBy() == 'status') then
    menu:addOption(tr('Sort by status'), function() sortBy('status') end)
  end

  if not(getSortedBy() == 'type') then
    menu:addOption(tr('Sort by type'), function() sortBy('type') end)
  end
end

function buildVipMenu()
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  buildVipOptions(menu)
  return menu
end

function onVipListMousePress(widget, mousePos, mouseButton)
  if mouseButton ~= MouseRightButton then return end
  buildVipMenu():display(mousePos)
  return true
end

function onVipListLabelMousePress(widget, mousePos, mouseButton)
  if mouseButton ~= MouseRightButton then return end

  local vipList = vipWindow:getChildById('contentsPanel')
  local name = widget:recursiveGetChildById("playerName"):getText()
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  menu:addOption(tr('Send Message'), function() g_game.openPrivateChannel(name) end)
  menu:addOption(tr('Add new VIP'), function() createAddWindow() end)
  menu:addOption(tr('Edit %s', name), function() if widget then createEditWindow(widget) end end)
  menu:addOption(tr('Remove %s', name), function() if widget then removeVip(widget) end end)
  menu:addSeparator()
  menu:addOption(tr('Copy Name'), function() g_window.setClipboardText(name) end)

  if modules.game_chat.getOwnPrivateTab() then
    menu:addSeparator()
    menu:addOption(tr('Invite to private chat'), function() g_game.inviteToOwnChannel(name) end)
    menu:addOption(tr('Exclude from private chat'), function() g_game.excludeFromOwnChannel(name) end)
  end

  if not isHiddingOffline() then
    menu:addOption(tr('Hide Offline'), function() hideOffline(true) end)
  else
    menu:addOption(tr('Show Offline'), function() hideOffline(false) end)
  end

  if not(getSortedBy() == 'name') then
    menu:addOption(tr('Sort by name'), function() sortBy('name') end)
  end

  if not(getSortedBy() == 'status') then
    menu:addOption(tr('Sort by status'), function() sortBy('status') end)
  end

  menu:display(mousePos)

  return true
end
