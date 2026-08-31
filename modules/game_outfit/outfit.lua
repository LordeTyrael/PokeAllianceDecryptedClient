local OutfitWindow
local lootPopupWindow
local outfits
local shaders
local selectedOutfit
local selectedWidget
local selectedLevelUp
local selectedLootEffects = {}
local lootEffectCatalog = {}
local currentClotheButtonBox
local colorBoxes = {}
local levelUpEffects = {}

local LOOT_CATEGORY_NAMES = {}

modules.client_hotkeys.registerHotkeyCallback("OUTFIT_TAUNT",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        g_game.outfitTaunt()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

modules.client_hotkeys.registerHotkeyCallback("OUTFIT_IDLE",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        g_game.outfitIdle()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

modules.client_hotkeys.registerHotkeyCallback("OUTFIT_ANIMATION",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        g_game.outfitTransform()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

function init()
  connect(g_game, {
    onOpenOutfitWindow = create,
    onLootEffectCatalog = parseLootEffectCatalog,
    onLevelUpEffects = parseLevelUpEffects,
    onGameEnd = destroy
  })
  connect(g_client, {
    onTrainerClose = destroy
  })
end

function terminate()
  disconnect(g_game, {
    onOpenOutfitWindow = create,
    onLootEffectCatalog = parseLootEffectCatalog,
    onLevelUpEffects = parseLevelUpEffects,
    onGameEnd = destroy
  })
  disconnect(g_client, {
    onTrainerClose = destroy
  })
  destroy()
end

function create(creatureOutfit, outfitList, creatureMount, mountList)
  if OutfitWindow then g_uistates.remove(OutfitWindow) OutfitWindow:destroy() OutfitWindow = nil end
  selectedOutfit = creatureOutfit
  OutfitWindow = g_ui.displayUI('outfit')
  --selectedOutfit = outfitWindow.type.creature:getOutfit()
  
  outfits = outfitList
  shaders = shaderList
  
  for num, out in ipairs(outfitList) do
    -- Match the player's looktype against the group's main OR any of its styles,
    -- so that when wearing a style we keep the style selected (not the main).
    local matches = (creatureOutfit.type == out[1])
    if not matches and out[4] then
      for _, sid in ipairs(out[4]) do
        if sid == creatureOutfit.type then matches = true; break end
      end
    end
    if matches then
	    selectedOutfit = {type = creatureOutfit.type, head = selectedOutfit.head, body = selectedOutfit.body, legs = selectedOutfit.legs, feet = selectedOutfit.feet, shader = nil}
      OutfitWindow:getChildById('outfitPanel'):getChildById('outfit'):setOutfit(selectedOutfit)
      OutfitWindow:getChildById('outfitPanel'):getChildById('name'):setText(out[2])
	    break
	  end
  end
  addEvent(drawOutfitList)
  
  currentClotheButtonBox = OutfitWindow:getChildById('outfitPanel'):getChildById('template'):getChildById('head')
  OutfitWindow:getChildById('outfitPanel'):getChildById('template'):getChildById('head').onCheckChange = onClotheCheckChange
  OutfitWindow:getChildById('outfitPanel'):getChildById('template'):getChildById('primary').onCheckChange = onClotheCheckChange
  OutfitWindow:getChildById('outfitPanel'):getChildById('template'):getChildById('secondary').onCheckChange = onClotheCheckChange
  OutfitWindow:getChildById('outfitPanel'):getChildById('template'):getChildById('detail').onCheckChange = onClotheCheckChange

  -- populate color panel
  for j=0,6 do
    for i=0,18 do
      local colorBox = g_ui.createWidget('ColorBox', OutfitWindow:getChildById('outfitPanel'):getChildById('colorBoxPanel'))
      local outfitColor = getOutfitColor(j*19 + i)
      colorBox:setImageColor(outfitColor)
      colorBox:setId('colorBox' .. j*19+i)
      colorBox.colorId = j*19 + i

      if j*19 + i == selectedOutfit.head then
        currentColorBox = colorBox
        colorBox:setChecked(true)
      end
      colorBox.onCheckChange = onColorCheckChange
      colorBoxes[#colorBoxes+1] = colorBox
    end
  end

  local wornTaunt, wornTransform, wornIdle = false, false, false
  for _, out in ipairs(outfitList) do
    local idx = nil
    if creatureOutfit.type == out[1] then
      idx = 1
    elseif out[4] then
      for i, sid in ipairs(out[4]) do
        if sid == creatureOutfit.type then idx = i + 1; break end
      end
    end
    if idx then
      wornTaunt     = (out[5] and out[5][idx] == 1) or false
      wornTransform = (out[6] and out[6][idx] == 1) or false
      wornIdle      = (out[7] and out[7][idx] == 1) or false
      break
    end
  end
  local actionPanel = OutfitWindow:getChildById('outfitPanel')
  local tauntBtn = actionPanel:getChildById('taunt')
  local transformBtn = actionPanel:getChildById('transformation')
  local idleBtn  = actionPanel:getChildById('idle')
  if tauntBtn then tauntBtn:setEnabled(wornTaunt); tauntBtn:setOpacity(wornTaunt and 1 or 0.4) end
  if transformBtn then transformBtn:setEnabled(wornTransform); transformBtn:setOpacity(wornTransform and 1 or 0.4) end
  if idleBtn then idleBtn:setEnabled(wornIdle); idleBtn:setOpacity(wornIdle and 1 or 0.4) end
  g_uistates.push(OutfitWindow)
  g_effects.fadeIn(OutfitWindow)

  -- Request loot effect catalog from server
  requestLootEffectCatalog()
end

function drawOutfitList()
  local outfitList = OutfitWindow:getChildById('outfitList')
  outfitList:destroyChildren()
  selectedWidget = nil
  for num, out in ipairs(outfits) do
    local ot = {type = out[1], head = selectedOutfit.head, body = selectedOutfit.body, legs = selectedOutfit.legs, feet = selectedOutfit.feet, shader = nil}
	  local widget = g_ui.createWidget('OutfitToList', OutfitWindow:getChildById('outfitList'))
    --widget:setScale(1)
	  widget:setOutfit(ot)
	  widget.ot = ot
	  widget.group = out
	  widget:setTooltip(out[2])
	  -- Match the group if the player's current looktype is the main OR any style.
	  local matchesGroup = (selectedOutfit.type == out[1])
	  if not matchesGroup and out[4] then
	    for _, sid in ipairs(out[4]) do
	      if sid == selectedOutfit.type then matchesGroup = true; break end
	    end
	  end
	  if matchesGroup then
	    selectedWidget = widget
		  selectedWidget:setBorderColor('blue')
	  end
	  widget.onFocusChange = function(widget, focus)
      if not focus then
        return
      end
	    -- Keep current style if it belongs to this group, otherwise default to main.
	    local newType = out[1]
	    if out[4] then
	      for _, sid in ipairs(out[4]) do
	        if sid == selectedOutfit.type then newType = sid; break end
	      end
	    end
	    selectedOutfit = {type = newType, head = selectedOutfit.head, body = selectedOutfit.body, legs = selectedOutfit.legs, feet = selectedOutfit.feet, shader = nil}
		  if selectedWidget then selectedWidget:setBorderColor('black') end
		    selectedWidget = widget
		    selectedWidget:setBorderColor('blue')
		    OutfitWindow:getChildById('outfitPanel'):getChildById('outfit'):setOutfit(selectedOutfit)
        OutfitWindow:getChildById('outfitPanel'):getChildById('name'):setText(out[2])
        OutfitWindow:getChildById('outfitPanel'):getChildById('name'):setWidth(310)
        drawStylesPanel(out)
	   end
  end
  if selectedWidget then
    selectedWidget:focus()
    outfitList:moveChildToIndex(selectedWidget, 1)
  end

  scheduleEvent(function()
    if not OutfitWindow then return end
    local panel = OutfitWindow:getChildById('outfitList')
    local sb    = OutfitWindow:getChildById('outfitAllianceScrollBar')
    if not panel or not sb then return end

    local rows         = math.ceil(#outfits / 4)
    local contentH     = rows * 70 - 5
    local visibleH     = panel:getHeight() - panel:getPaddingTop() - panel:getPaddingBottom()
    local scrollHeight = math.max(contentH - visibleH, 0)

    sb:setMinimum(0)
    sb:setMaximum(scrollHeight)
    sb:setOn(scrollHeight > 0)
  end, 30)
end

function drawStylesPanel(group)
  local outfitPanel = OutfitWindow:getChildById('outfitPanel')
  local panel       = outfitPanel:getChildById('stylesPanel')
  local label       = outfitPanel:getChildById('stylesLabel')
  local scrollbar   = outfitPanel:getChildById('stylesAllianceScrollBar')
  local outfitW     = outfitPanel:getChildById('outfit')
  if not panel then return end
  panel:destroyChildren()

  local styles = group[4] or {}
  local hasStyles = #styles > 0

  panel:setVisible(hasStyles)
  if label then label:setVisible(hasStyles) end
  -- The scrollbar auto-shows itself via $on style when there's overflow.
  -- We just need to keep it logically "alive" while panel is visible.
  if scrollbar and not hasStyles then scrollbar:setOn(false) end

  -- Shift outfit creature to the left when styles are present so the panel fits on the right.
  if outfitW then
    outfitW:breakAnchors()
    outfitW:addAnchor(AnchorTop, 'name', AnchorBottom)
    outfitW:setMarginTop(15)
    if hasStyles then
      outfitW:addAnchor(AnchorLeft, 'parent', AnchorLeft)
      outfitW:setMarginLeft(40)
    else
      outfitW:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
      outfitW:setMarginLeft(0)
    end
  end

  -- The action buttons follow the outfit. With styles they sit to the LEFT of the
  -- outfit (otherwise they'd overlap the styles panel on the right). Without styles
  -- they go back to the top-right corner (original layout).
  local taunt = outfitPanel:getChildById('taunt')
  if taunt then
    taunt:breakAnchors()
    if hasStyles then
      taunt:addAnchor(AnchorTop, 'parent', AnchorTop)
      taunt:setMarginTop(15)
      taunt:addAnchor(AnchorRight, 'outfit', AnchorLeft)
      taunt:setMarginRight(18)
    else
      -- No styles: top-right of the panel, at the name height (original layout).
      taunt:addAnchor(AnchorTop, 'parent', AnchorTop)
      taunt:setMarginTop(15)
      taunt:addAnchor(AnchorRight, 'parent', AnchorRight)
      taunt:setMarginRight(0)
    end
  end

  if not hasStyles then return end

  local mainLookType = group[1]
  local lookTypes = {mainLookType}
  for _, sid in ipairs(styles) do
    table.insert(lookTypes, sid)
  end

  local styleSelected = nil
  for _, lt in ipairs(lookTypes) do
    local thumbOutfit = {type = lt, head = selectedOutfit.head, body = selectedOutfit.body, legs = selectedOutfit.legs, feet = selectedOutfit.feet, shader = nil}
    local thumb = g_ui.createWidget('OutfitToList', panel)
    thumb:setOutfit(thumbOutfit)
    thumb.styleLookType = lt
    if lt == selectedOutfit.type then
      styleSelected = thumb
    end
    thumb.onFocusChange = function(widget, focus)
      if not focus then return end
      styleSelected = widget
      selectedOutfit.type = lt
      OutfitWindow:getChildById('outfitPanel'):getChildById('outfit'):setOutfit(selectedOutfit)
    end
  end

  -- The OutfitToList widget shows the "selected" look via its $focus style, so we
  -- need to actually focus the matching thumb (the first thumb auto-focuses
  -- otherwise, making it look selected even when the player wears another style).
  if styleSelected then
    styleSelected:focus()
  end

  -- Force the scrollbar to refresh its min/max range now that all thumbs exist.
  -- (onLayoutUpdate normally fires automatically, but recalculating here ensures the
  -- $on/$!on visibility state is correct even on first display.)
  if panel.updateScrollBars then panel:updateScrollBars() end
end

function parseLevelUpEffects(groups, activeGroup)
  levelUpEffects = groups or {}

  -- Define o grupo ativo como selecionado inicialmente
  selectedLevelUp = { group = activeGroup }

  if OutfitWindow and OutfitWindow.levelUpList then
    OutfitWindow.levelUpList:destroyChildren()

    -- Reorganiza os grupos para que o grupo ativo seja renderizado primeiro.
    local renderedGroups = {}
    for groupIndex, group in ipairs(levelUpEffects) do
      if groupIndex == activeGroup then
        table.insert(renderedGroups, 1, { index = groupIndex, group = group })
      else
        table.insert(renderedGroups, { index = groupIndex, group = group })
      end
    end

    local defaultWidget = g_ui.createWidget("LevelUpEffectWidget", OutfitWindow.levelUpList)     
    defaultWidget.defaultImage:show()
    defaultWidget.onFocusChange = function(widget, focus)
      if not focus then return end
      selectedLevelUp = { group = 0 }
    end

    for _, item in ipairs(renderedGroups) do
      local groupIndex = item.index
      local group = item.group
      local groupWidget = g_ui.createWidget("LevelUpEffectWidget", OutfitWindow.levelUpList)      
      groupWidget.onFocusChange = function(widget, focus)
        if not focus then return end
        selectedLevelUp = { group = groupIndex }
      end

      for effectIndex = #group.effects, 1, -1 do
        local effectId = group.effects[effectIndex]
        local uiEffect = g_ui.createWidget("LevelEffect", groupWidget)
        uiEffect:setEffectId(effectId)
        uiEffect:setScale(0.75)
      end
      if groupIndex == activeGroup then
        groupWidget:focus()
      end
    end
  end
end

function changeOutfitViewer(viewMode)
  if not OutfitWindow then return end

  -- Hide all lists
  OutfitWindow.outfitList:hide()
  OutfitWindow.levelUpList:hide()
  OutfitWindow.lootEffectList:hide()
  OutfitWindow.outfitAllianceScrollBar:hide()
  OutfitWindow.levelUpAllianceScrollBar:hide()

  -- Reset all circles
  OutfitWindow.optionsButton.outfitCircle:setImageSource("new_images/circle")
  OutfitWindow.optionsButton.outfitCircle:setOpacity(0.5)
  OutfitWindow.optionsButton.levelUpCircle:setImageSource("new_images/circle")
  OutfitWindow.optionsButton.levelUpCircle:setOpacity(0.5)
  OutfitWindow.optionsButton.lootEffectCircle:setImageSource("new_images/circle")
  OutfitWindow.optionsButton.lootEffectCircle:setOpacity(0.5)

  if viewMode == "levelUp" then
    OutfitWindow.levelUpList:show()
    OutfitWindow.levelUpAllianceScrollBar:show()
    OutfitWindow.optionsButton.levelUpCircle:setImageSource("new_images/blue_circle")
    OutfitWindow.optionsButton.levelUpCircle:setOpacity(1)
    OutfitWindow.outfits:setText(tr("Level Up"))
  elseif viewMode == "lootEffect" then
    OutfitWindow.lootEffectList:show()
    OutfitWindow.outfitAllianceScrollBar:show()
    OutfitWindow.optionsButton.lootEffectCircle:setImageSource("new_images/blue_circle")
    OutfitWindow.optionsButton.lootEffectCircle:setOpacity(1)
    OutfitWindow.outfits:setText(tr("Loot Effects"))
  else
    OutfitWindow.outfitList:show()
    OutfitWindow.outfitAllianceScrollBar:show()
    OutfitWindow.optionsButton.outfitCircle:setImageSource("new_images/blue_circle")
    OutfitWindow.optionsButton.outfitCircle:setOpacity(1)
    OutfitWindow.outfits:setText(tr("Outfits"))
  end
end

function randomize()
  local outfitTemplate = {
    OutfitWindow:getChildById('outfitPanel'):getChildById('template'):getChildById('head'),
    OutfitWindow:getChildById('outfitPanel'):getChildById('template'):getChildById('primary'),
    OutfitWindow:getChildById('outfitPanel'):getChildById('template'):getChildById('secondary'),
    OutfitWindow:getChildById('outfitPanel'):getChildById('template'):getChildById('detail')
  }

  for i = 1, #outfitTemplate do
    outfitTemplate[i]:setChecked(true)
    colorBoxes[math.random(1, #colorBoxes)]:setChecked(true)
    outfitTemplate[i]:setChecked(false)
  end
  outfitTemplate[1]:setChecked(true)
end

function onClotheCheckChange(clotheButtonBox)
  if clotheButtonBox == currentClotheButtonBox then
    clotheButtonBox.onCheckChange = nil
    clotheButtonBox:setChecked(true)
    clotheButtonBox.onCheckChange = onClotheCheckChange
  else
    currentClotheButtonBox.onCheckChange = nil
    currentClotheButtonBox:setChecked(false)
    currentClotheButtonBox.onCheckChange = onClotheCheckChange

    currentClotheButtonBox = clotheButtonBox

    local colorId = 0
    if currentClotheButtonBox:getId() == 'head' then
      colorId = selectedOutfit.head
    elseif currentClotheButtonBox:getId() == 'primary' then
      colorId = selectedOutfit.body
    elseif currentClotheButtonBox:getId() == 'secondary' then
      colorId = selectedOutfit.legs
    elseif currentClotheButtonBox:getId() == 'detail' then
      colorId = selectedOutfit.feet
    end
    OutfitWindow:getChildById('outfitPanel'):getChildById('colorBoxPanel'):recursiveGetChildById('colorBox' .. colorId):setChecked(true)
  end
end

function onColorCheckChange(colorBox)
  if colorBox == currentColorBox then
    colorBox.onCheckChange = nil
    colorBox:setChecked(true)
    colorBox.onCheckChange = onColorCheckChange
  else
    currentColorBox.onCheckChange = nil
    currentColorBox:setChecked(false)
    currentColorBox.onCheckChange = onColorCheckChange

    currentColorBox = colorBox

    if currentClotheButtonBox:getId() == 'head' then
      selectedOutfit.head = currentColorBox.colorId
    elseif currentClotheButtonBox:getId() == 'primary' then
      selectedOutfit.body = currentColorBox.colorId
    elseif currentClotheButtonBox:getId() == 'secondary' then
      selectedOutfit.legs = currentColorBox.colorId
    elseif currentClotheButtonBox:getId() == 'detail' then
      selectedOutfit.feet = currentColorBox.colorId
    end
	
    -- currentColorBox:setBorderColor(getOufitColor(currentColorBox.colorId))

    OutfitWindow:getChildById('outfitPanel'):getChildById('outfit'):setOutfit(selectedOutfit)
	for i, child in ipairs(OutfitWindow:getChildById('outfitList'):getChildren()) do
	  local out = child.ot
	  out.head = selectedOutfit.head
	  out.body = selectedOutfit.body
	  out.legs = selectedOutfit.legs
	  out.feet = selectedOutfit.feet
    out.shader = selectedOutfit.shader
	  child:setOutfit(out)
	end
    -- Propagate the new colors to the styles thumbnails too, so they stay in sync
    -- with the main preview while the user is recoloring.
    local stylesPanel = OutfitWindow:getChildById('outfitPanel'):getChildById('stylesPanel')
    if stylesPanel then
      for _, thumb in ipairs(stylesPanel:getChildren()) do
        local lt = thumb.styleLookType
        if lt then
          thumb:setOutfit({type = lt, head = selectedOutfit.head, body = selectedOutfit.body, legs = selectedOutfit.legs, feet = selectedOutfit.feet, shader = selectedOutfit.shader})
        end
      end
    end
  end
end

function destroy()
  closeLootPopup()
  if OutfitWindow then
	  selectedOutfit = nil
    selectedLevelUp = nil
    selectedLootEffects = {}
    currentColorBox = nil
    currentClotheButtonBox = nil
    colorBoxes = {}
    levelUpEffects = {}
    g_effects.fadeOut(OutfitWindow)
    scheduleEvent(function()
        if OutfitWindow then
          g_uistates.remove(OutfitWindow)
          OutfitWindow:destroy()
          OutfitWindow = nil
        end
    end, 500)
  end
end

function accept()
  if not selectedOutfit then return end
  g_game.changeOutfit(selectedOutfit)
  -- opcode 1579 (migrado do extended 194). NÃO reusa o 196 do S2C: o switch C2S do servidor tem um
  -- case 0xC4 que engoliria o pacote. O campo `type` do JSON antigo era redundante — o opcode é a action.
  g_game.sendLevelUpEffectGroup(selectedLevelUp and selectedLevelUp.group or 0)

  -- Send loot effect selections
  sendLootEffectSelections()

  destroy()
end

function sendWalk()
  if not OutfitWindow then
    return
  end

  local outfitWindow = OutfitWindow:getChildById('outfitPanel'):getChildById('outfit')
  if not outfitWindow then
    return
  end

  local animate = not outfitWindow:isAnimating() and true or false
  outfitWindow:setAnimate(animate)
end

function sendRotate()
  if not OutfitWindow then
    return
  end

  local outfitWindow = OutfitWindow:getChildById('outfitPanel'):getChildById('outfit')
  if not outfitWindow then
    return
  end

  local direction = outfitWindow:getDirection()
  if not direction then
    direction = 0
  end

  local newDirection = (direction + 1) % 4
  outfitWindow:setDirection(newDirection)
end

function sendTaunt()
  g_game.outfitTaunt()
  destroy()
end

function sendIdle()
  g_game.outfitIdle()
  destroy()
end

function sendTransform()
  g_game.outfitTransform()
  destroy()
end

-- ============================================================================
-- Loot Effects
-- ============================================================================

function requestLootEffectCatalog()
  local protocolGame = g_game.getProtocolGame()
  if not protocolGame then return end

  local msg = OutputMessage.create()
  msg:addU16(0x605) -- 1541, loot effect catalog opcode
  msg:addU8(1)      -- ACTION_REQUEST_LIST
  protocolGame:send(msg)
end

function sendLootEffectSelections()
  local protocolGame = g_game.getProtocolGame()
  if not protocolGame then return end

  for catId, effectId in pairs(selectedLootEffects) do
    local msg = OutputMessage.create()
    msg:addU16(0x605) -- 1541
    msg:addU8(2)      -- ACTION_SET_EFFECT
    msg:addU8(catId)
    msg:addU16(effectId)
    protocolGame:send(msg)
  end
end

function parseLootEffectCatalog(categories)
  lootEffectCatalog = {}

  for _, catInfo in ipairs(categories) do
    lootEffectCatalog[catInfo.id] = {
      id = catInfo.id,
      name = catInfo.name,
      defaultEffect = catInfo.defaultEffect,
      equippedEffect = catInfo.equippedEffect,
      effects = catInfo.effects,
    }
    if not selectedLootEffects[catInfo.id] then
      selectedLootEffects[catInfo.id] = catInfo.equippedEffect
    end
  end

  drawLootEffectList()
end

function drawLootEffectList()
  if not OutfitWindow or not OutfitWindow.lootEffectList then return end
  OutfitWindow.lootEffectList:destroyChildren()

  -- Sort categories by id
  local sortedCats = {}
  for catId, catInfo in pairs(lootEffectCatalog) do
    table.insert(sortedCats, catInfo)
  end
  table.sort(sortedCats, function(a, b) return a.id < b.id end)

  for _, catInfo in ipairs(sortedCats) do
    local equippedEffect = selectedLootEffects[catInfo.id] or catInfo.equippedEffect

    local row = g_ui.createWidget("LootCategoryRow", OutfitWindow.lootEffectList)
    row.categoryName:setText(catInfo.name)

    -- Show current effect preview
    local uiEffect = g_ui.createWidget("LootEffect", row.effectPreview)
    uiEffect:setEffectId(equippedEffect)
    uiEffect:setScale(0.6)
    if equippedEffect == 2421 then
      uiEffect:setEffectOffset({x = -32, y = -32})
    end

    -- Click opens popup
    local cId = catInfo.id
    row.onMouseRelease = function(w, mousePos, mouseButton)
      if mouseButton == MouseLeftButton then
        openLootPopup(cId)
      end
    end
  end
end

function openLootPopup(categoryId)
  closeLootPopup()

  local catInfo = lootEffectCatalog[categoryId]
  if not catInfo then return end

  lootPopupWindow = g_ui.createWidget('LootEffectPopup', OutfitWindow)
  lootPopupWindow.popupTitle:setText(catInfo.name)
  g_uistates.push(lootPopupWindow)

  local equippedEffect = selectedLootEffects[categoryId] or catInfo.equippedEffect

  -- Resize popup height based on rows
  local rows = math.ceil(#catInfo.effects / 4)
  local gridHeight = rows * 70
  lootPopupWindow:setHeight(35 + gridHeight + 15)

  local focusTarget = nil
  for _, effectId in ipairs(catInfo.effects) do
    local option = g_ui.createWidget("LootPopupOption", lootPopupWindow.popupGrid)
    option:setSize({width = 65, height = 65})

    local uiEffect = g_ui.createWidget("LootEffect", option)
    uiEffect:setEffectId(effectId)
    uiEffect:setScale(0.75)
    if effectId == 2421 then
      uiEffect:setEffectOffset({x = 16, y = 16})
    end

    -- Track which option to focus (the equipped one)
    if effectId == equippedEffect then
      focusTarget = option
    end

    local eId = effectId
    option.onMouseRelease = function(w, mousePos, mouseButton)
      if mouseButton == MouseLeftButton then
        selectedLootEffects[categoryId] = eId
        closeLootPopup()
        drawLootEffectList()
      end
    end
  end

  -- Focus the equipped option so $focus style highlights it
  if focusTarget then
    focusTarget:focus()
  end
end

function closeLootPopup()
  if lootPopupWindow then
    g_uistates.remove(lootPopupWindow)
    lootPopupWindow:destroy()
    lootPopupWindow = nil
  end
end