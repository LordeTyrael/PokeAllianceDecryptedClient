local runeWindow
local titleLabel
local pointsLabel
local subtitleLabel
local subtitleLooktype
local emptyLabel
local runeList

local currentCategory = nil
local currentPoints = 0
local currentBankBalance = 0
local currentRunes = {}
local currentTargets = {}
local pendingResetRefresh = false
local pendingAttachRuneKey = nil

local RUNE_DEFS = {
  offensive = {
    { key = "attack",           label = "Attack (+2.0%/lv)" },
    { key = "critical_damage",  label = "Crit Damage (+2.0%/lv)" },
    { key = "critical_chance",  label = "Crit Chance (+1.0%/lv)" },
  },
  defensive = {
    { key = "defense",          label = "Defense (+1.0%/lv)" },
    { key = "critical_res",     label = "Crit Resistance (+2.0%/lv)" },
  },
  utility = {
    { key = "precision",        label = "Precision (+1.0%/lv)" },
    { key = "evasion",          label = "Evasion (+2.0%/lv)" },
    { key = "shiny_charm",      label = "Shiny Charm (+1.0%/lv)" },
  },
}

local CATEGORY_LABELS = {
  offensive = "Offensive",
  defensive = "Defensive",
  utility = "Utility",
}

local attachPickerWindow = nil

local function normalizeSearchText(text)
  return (text or ""):lower():gsub('%s+', '')
end

local function humanizeName(value)
  value = (value or ""):gsub("_", " ")
  return value:gsub("(%a)([%w']*)", function(first, rest)
    return first:upper() .. rest
  end)
end

local function getRuneTotalLabel(category, runeKey, level)
  for _, def in ipairs(RUNE_DEFS[category] or {}) do
    if def.key == runeKey then
      local baseName = def.label:match("^([^%(]+)") or humanizeName(runeKey)
      local perLevel = tonumber(def.label:match("%(%+([%d%.]+)%%%/lv%)"))
      if perLevel then
        local displayLevel = (level and level > 0) and level or 1
        local total = perLevel * displayLevel
        if total == math.floor(total) then
          return string.format("%s+%d%%", baseName, math.floor(total))
        else
          return string.format("%s+%.1f%%", baseName, total)
        end
      end
      return def.label
    end
  end
  return humanizeName(runeKey)
end

local function getRuneLabel(category, runeKey)
  for _, rune in ipairs(RUNE_DEFS[category] or {}) do
    if rune.key == runeKey then
      return rune.label
    end
  end
  return humanizeName(runeKey)
end

local function closeAttachPicker()
  if attachPickerWindow then
    attachPickerWindow:destroy()
    attachPickerWindow = nil
  end
end

local showAttachConfirmBox  -- forward declaration

local function refreshAttachPickerEntries(category, runeKey, searchText)
  if not attachPickerWindow then
    return
  end

  local list = attachPickerWindow:recursiveGetChildById("pickerList")
  local emptyLabel = attachPickerWindow:recursiveGetChildById("pickerEmptyLabel")
  if not list then
    return
  end

  local searchBox = attachPickerWindow and attachPickerWindow:recursiveGetChildById('pickerSearch')
  list:destroyChildren()

  local filter = normalizeSearchText(searchText)
  local visibleCount = 0
  for _, target in ipairs(currentTargets or {}) do
    local displayName = humanizeName(target.targetName)
    local matchesFilter = filter == "" or normalizeSearchText(displayName):find(filter, 1, true) ~= nil
    if matchesFilter then
      visibleCount = visibleCount + 1

      local btn = g_ui.createWidget("AttachPickerEntry", list)
      local creatureIcon = btn:getChildById("creatureIcon")
      if creatureIcon and target.lookType and target.lookType > 0 then
        creatureIcon:setOutfit({type = target.lookType})
      end

      btn:setTooltip(displayName)
      btn.onClick = function()
        showAttachConfirmBox(category, runeKey, target)
      end
    end
  end

  if emptyLabel then
    emptyLabel:setVisible(visibleCount == 0)
  end

  if searchBox and not searchBox:isDestroyed() then
    searchBox:focus()
  end
end

local function setButtonState(button, text, enabled, callback)
  if not button then return end
  button:setText(text)
  button:setOpacity(enabled and 1.0 or 0.55)
  button.onClick = enabled and callback or nil
end

local function getModalFallbackWidget()
  if attachPickerWindow and attachPickerWindow:isVisible() then
    return attachPickerWindow
  end

  if runeWindow and runeWindow:isVisible() then
    return runeWindow
  end

  return nil
end

local function bindModalInputLock(dialog, fallbackWidget)
  if not dialog then
    return nil
  end

  local previousLockWidget = fallbackWidget or getModalFallbackWidget()
  local previousOnDestroy = dialog.onDestroy

  g_uistates.push(dialog)
  dialog.onDestroy = function()
    if previousOnDestroy then
      previousOnDestroy()
    end

    if previousLockWidget and previousLockWidget:isVisible() then
      g_uistates.push(previousLockWidget)
    else
      g_uistates.remove(dialog)
    end
  end

  return dialog
end

local function showRuneInfoBox(title, message)
  return bindModalInputLock(displayAllianceInfoBox(title, message))
end

local function wrapModalCallback(dialogProvider, callback)
  if not callback then
    return nil
  end

  return function()
    local dialog = dialogProvider()
    if dialog then
      dialog:destroy()
    end

    callback()
  end
end

showAttachConfirmBox = function(category, runeKey, target)
  local dialog = g_ui.createWidget('AllianceMessageBoxWindow', rootWidget)
  dialog:setId('attachConfirmDialog')
  dialog:setSize({width = 280, height = 230})

  bindModalInputLock(dialog)

  local function closeDialog()
    if dialog and not dialog:isDestroyed() then
      dialog:destroy()
    end
  end

  -- Title
  local title = g_ui.createWidget('AllianceTitle', dialog)
  title:setText('Attach Rune')
  title:addAnchor(AnchorTop, 'parent', AnchorTop)
  title:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  title:setMarginTop(8)

  -- Creature sprite
  local creature = g_ui.createWidget('AttachConfirmCreature', dialog)
  creature:setSize({width = 64, height = 64})
  creature:addAnchor(AnchorTop, 'prev', AnchorBottom)
  creature:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  creature:setMarginTop(8)
  if target.lookType and target.lookType > 0 then
    creature:setOutfit({type = target.lookType})
  end

  -- Pokémon name
  local nameLabel = g_ui.createWidget('AllianceLabel', dialog)
  nameLabel:setText(humanizeName(target.targetName))
  nameLabel:addAnchor(AnchorTop, 'prev', AnchorBottom)
  nameLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  nameLabel:setMarginTop(4)

  -- Buttons
  local buttonHolder = g_ui.createWidget('AllianceBoxButtonHolder', dialog)
  buttonHolder:addAnchor(AnchorBottom, 'parent', AnchorBottom)
  buttonHolder:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)

  local confirmBtn = g_ui.createWidget('AllianceStraightBlueButton', buttonHolder)
  confirmBtn:setText('Confirm')
  confirmBtn:setMarginLeft(0)
  confirmBtn:addAnchor(AnchorBottom, 'parent', AnchorBottom)
  confirmBtn:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  connect(confirmBtn, { onClick = function()
    closeDialog()
    g_game.sendRuneAttach(target.targetName, category, runeKey)
    closeAttachPicker()
  end })

  local cancelBtn = g_ui.createWidget('AllianceStraightBlueButton', buttonHolder)
  cancelBtn:setText('Cancel')
  cancelBtn:setMarginLeft(25)
  cancelBtn:addAnchor(AnchorBottom, 'prev', AnchorBottom)
  cancelBtn:addAnchor(AnchorLeft, 'prev', AnchorRight)
  connect(cancelBtn, { onClick = function()
    closeDialog()
  end })

  local bw = confirmBtn:getWidth() + cancelBtn:getWidth() + 25
  buttonHolder:setWidth(bw)
  buttonHolder:setHeight(confirmBtn:getHeight())

  return dialog
end

local function showRuneGeneralBox(title, message, buttons, onEnterCallback, onEscapeCallback)
  local dialog
  local wrappedButtons = {}

  for index, button in ipairs(buttons or {}) do
    wrappedButtons[index] = {
      text = button.text,
      callback = wrapModalCallback(function() return dialog end, button.callback),
    }
  end

  wrappedButtons.anchor = buttons and buttons.anchor or nil

  dialog = bindModalInputLock(
    displayAllianceBox(
      title,
      message,
      wrappedButtons,
      wrapModalCallback(function() return dialog end, onEnterCallback),
      wrapModalCallback(function() return dialog end, onEscapeCallback)
    )
  )

  return dialog
end

local function refreshHeader()
  if not runeWindow then return end

  local categoryLabel = CATEGORY_LABELS[currentCategory] or humanizeName(currentCategory or "Rune")
  if titleLabel then
    titleLabel:setText(tr(string.format("%s Runes", categoryLabel)))
  end

  if pointsLabel then
    pointsLabel:setText(tr("PokeLog Points: %d", currentPoints or 0))
  end
end

local function openAttachPicker(category, runeKey)
  closeAttachPicker()

  if not currentTargets or #currentTargets == 0 then
    showRuneInfoBox("Rune System", "Complete a Pokemon's Pokelog before attaching runes.")
    return
  end

  attachPickerWindow = g_ui.createWidget("AttachPickerWindow", modules.game_interface.getRootPanel())
  bindModalInputLock(attachPickerWindow, runeWindow)
  attachPickerWindow:recursiveGetChildById("pickerTitle"):setText(string.format("Attach %s Rune", CATEGORY_LABELS[category] or humanizeName(category)))

  local searchBox = attachPickerWindow:recursiveGetChildById("pickerSearch")
  if searchBox then
    searchBox.onTextChange = function(widget, text)
      refreshAttachPickerEntries(category, runeKey, text or widget:getText())
    end
    searchBox:setText("")
    searchBox:focus()
  end

  refreshAttachPickerEntries(category, runeKey, "")

  attachPickerWindow:recursiveGetChildById("pickerClose").onClick = function()
    closeAttachPicker()
  end
end

local function requestAttachTargets(runeKey)
  if not currentCategory or not runeKey then
    return
  end

  pendingAttachRuneKey = runeKey
  g_game.sendRuneRequestCategory(currentCategory)
end

local function refreshRuneList()
  if not runeList then return end
  runeList:destroyChildren()

  local categoryBusy = false
  for _, rune in ipairs(currentRunes or {}) do
    if rune.isActive then
      categoryBusy = true
      break
    end
  end

  if not currentRunes or #currentRunes == 0 then
    if emptyLabel then
      emptyLabel:setText(tr("No runes available for this category."))
      emptyLabel:show()
    end
    return
  end

  if emptyLabel then
    emptyLabel:hide()
  end

  for _, rune in ipairs(currentRunes) do
    local row = g_ui.createWidget("RuneBrowserRow", runeList)

    -- Rune image
    local runeImage = row:recursiveGetChildById("runeImage")
    if runeImage then
      runeImage:setImageSource("/images/modules/runes/" .. rune.runeKey .. ".png")
      if rune.isOwned then
        runeImage:setImageColor({r = 255, g = 255, b = 255, a = 255})
      else
        runeImage:setImageColor({r = 100, g = 100, b = 100, a = 200})
      end
    end

    -- Name
    local nameLabel = row:recursiveGetChildById("runeNameLabel")
    if nameLabel then nameLabel:setText(humanizeName(rune.runeKey)) end

    -- Context line — cleared (info shown via desc and right panel)
    local activeLabel = row:recursiveGetChildById("runeActiveLabel")
    if activeLabel then activeLabel:setText("") end

    -- Buff description — always shown regardless of ownership
    local descLabel = row:recursiveGetChildById("runeDescLabel")
    if descLabel then
      descLabel:setText(getRuneTotalLabel(currentCategory, rune.runeKey, rune.level))
    end

    -- Badges: only level (owned) or locked (not owned)
    local levelBadge  = row:recursiveGetChildById("levelBadge")
    local lockedBadge = row:recursiveGetChildById("lockedBadge")
    local levelOverlay = row:recursiveGetChildById("runeLevelOverlay")
    if rune.isOwned then
      if levelBadge then
        levelBadge:recursiveGetChildById("levelText"):setText(toRoman(rune.level))
        levelBadge:show()
      end
      if lockedBadge then lockedBadge:hide() end
      if levelOverlay then levelOverlay:setText(toRoman(rune.level)); levelOverlay:show() end
    else
      if levelBadge  then levelBadge:hide() end
      if lockedBadge then lockedBadge:show() end
      if levelOverlay then levelOverlay:hide() end
    end

    -- Upgrade / Unlock button in the center panel
    local upgradeBtn     = row:recursiveGetChildById("upgradeBtn")
    local costIcon       = row:recursiveGetChildById("costIcon")
    local costLabel      = row:recursiveGetChildById("costLabel")
    local maxLevelLabel  = row:recursiveGetChildById("maxLevelLabel")

    local function showCost(value, color)
      if costIcon      then costIcon:show() end
      if costLabel     then costLabel:setText(tostring(value)); costLabel:setColor(color or "#d4a017"); costLabel:show() end
      if maxLevelLabel then maxLevelLabel:hide() end
    end

    local function showMaxLevel()
      if costIcon      then costIcon:hide() end
      if costLabel     then costLabel:hide() end
      if maxLevelLabel then maxLevelLabel:show() end
    end

    if upgradeBtn then
      if not rune.isOwned then
        upgradeBtn:setText(tr("Unlock"))
        upgradeBtn:setOpacity(1.0)
        upgradeBtn.onClick = function()
          local runeName = humanizeName(rune.runeKey)
          local cost = rune.unlockCost or 0
          showRuneGeneralBox(
            "Unlock Rune",
            string.format("Unlock %s for %d Pokelog Points?", runeName, cost),
            {
              { text = "Confirm", callback = function() g_game.sendRuneUnlock(currentCategory, rune.runeKey) end },
              { text = "Cancel",  callback = function() end },
              anchor = AnchorHorizontalCenter,
            }
          )
        end
        showCost(rune.unlockCost or 0)
      elseif rune.level >= rune.maxLevel then
        upgradeBtn:setText(tr("Max"))
        upgradeBtn:setOpacity(0.55)
        upgradeBtn.onClick = nil
        showMaxLevel()
      else
        upgradeBtn:setText(tr("Upgrade"))
        upgradeBtn:setOpacity(1.0)
        upgradeBtn.onClick = function()
          local runeName = humanizeName(rune.runeKey)
          local cost = rune.upgradeCost or 0
          local nextLevel = rune.level + 1
          showRuneGeneralBox(
            "Upgrade Rune",
            string.format("Upgrade %s to level %s for %d Pokelog Points?", runeName, toRoman(nextLevel), cost),
            {
              { text = "Confirm", callback = function() g_game.sendRuneUpgrade(currentCategory, rune.runeKey, 1) end },
              { text = "Cancel",  callback = function() end },
              anchor = AnchorHorizontalCenter,
            }
          )
        end
        showCost(rune.upgradeCost or 0)
      end
    end

    -- Right panel: visual state only, no action buttons
    local rightLocked   = row:recursiveGetChildById("rightLocked")
    local rightAttach   = row:recursiveGetChildById("rightAttach")
    local rightEquipped = row:recursiveGetChildById("rightEquipped")
    local rightBusy     = row:recursiveGetChildById("rightBusy")

    local function hideAllRight()
      if rightLocked   then rightLocked:hide() end
      if rightAttach   then rightAttach:hide() end
      if rightEquipped then rightEquipped:hide() end
      if rightBusy     then rightBusy:hide() end
    end

    if not rune.isOwned then
      hideAllRight()
      if rightLocked then rightLocked:show() end
    elseif rune.isActive and rune.attachedTargetName ~= "" then
      hideAllRight()
      if rightEquipped then
        rightEquipped:show()
        local creature = rightEquipped:recursiveGetChildById("equippedCreature")
        local crName   = rightEquipped:recursiveGetChildById("equippedCreatureName")
        if creature and rune.attachedTargetLookType and rune.attachedTargetLookType > 0 then
          creature:setOutfit({type = rune.attachedTargetLookType})
        end
        if crName then crName:setText(humanizeName(rune.attachedTargetName)) end
      end
    elseif categoryBusy then
      hideAllRight()
      if rightBusy then rightBusy:show() end
    else
      hideAllRight()
      if rightAttach then
        rightAttach:show()
        rightAttach.onClick = function()
          requestAttachTargets(rune.runeKey)
        end
      end
    end
  end
end

local function runeWindowOnCategory(category, pokelogPoints, bankBalance, runes, targets)
  if not runeWindow or category ~= currentCategory then return end

  currentPoints = pokelogPoints or 0
  currentBankBalance = bankBalance or 0
  currentRunes = runes or {}
  currentTargets = targets or {}

  refreshHeader()
  refreshRuneList()

  if pendingAttachRuneKey then
    local runeKey = pendingAttachRuneKey
    pendingAttachRuneKey = nil

    if currentTargets and #currentTargets > 0 then
      openAttachPicker(category, runeKey)
    else
      showRuneInfoBox("Rune System", "No completed Pokelog creatures are available for this attach.")
    end
  end
end

local function runeWindowOnResult(success, message)
  if not success and message and message ~= "" then
    pendingResetRefresh = false
    pendingAttachRuneKey = nil
    showRuneInfoBox("Rune System", message)
    return
  end

  if pendingResetRefresh and success and currentCategory then
    pendingResetRefresh = false
    g_game.sendRuneRequestCategory(currentCategory)
  end
end

function runeWindowOpen(category)
  if not runeWindow or not category then return end

  currentCategory = category:lower()
  currentPoints = 0
  currentBankBalance = 0
  currentRunes = {}
  currentTargets = {}
  pendingResetRefresh = false
  pendingAttachRuneKey = nil

  refreshHeader()
  if emptyLabel then
    emptyLabel:setText(tr("Loading runes..."))
    emptyLabel:show()
  end
  if runeList then
    runeList:destroyChildren()
  end

  runeWindow:show()
  runeWindow:raise()
  runeWindow:focus()
  g_uistates.push(runeWindow)
  g_game.sendRuneRequestCategory(currentCategory)
end

function runeWindowClose()
  if not runeWindow then return end
  closeAttachPicker()
  pendingAttachRuneKey = nil
  runeWindow:hide()
  g_uistates.remove(runeWindow)
end

function runeWindowInit()
  runeWindow = g_ui.loadUI("rune_window", modules.game_interface.getRootPanel())
  titleLabel = runeWindow:recursiveGetChildById("base_text")
  pointsLabel = runeWindow:recursiveGetChildById("pointsLabel")
  emptyLabel = runeWindow:recursiveGetChildById("emptyLabel")
  runeList = runeWindow:recursiveGetChildById("runeList")

  runeWindow:hide()

  runeWindow:recursiveGetChildById("closeButton").onClick = function()
    runeWindowClose()
  end

  runeWindow:recursiveGetChildById("resetAllBtn").onClick = function()
    pendingResetRefresh = true
    showRuneGeneralBox(
      "Reset All Runes",
      "This will cost 50 Diamonds and reset every owned rune. Invested Pokelog Points will be refunded. Continue?",
      {
        { text = "Confirm", callback = function() g_game.sendRuneResetGlobal() end },
        { text = "Cancel", callback = function() pendingResetRefresh = false end },
        anchor = AnchorHorizontalCenter,
      }
    )
  end

  connect(g_game, {
    onGameStart = function()
      local item = runeWindow:recursiveGetChildById("resetCostItem")
      if item then item:setItemId(3028) end
    end,
    onRuneSystemCategory = runeWindowOnCategory,
    onRuneSystemResult = runeWindowOnResult,
  })
end

function runeWindowTerminate()
  pendingResetRefresh = false
  pendingAttachRuneKey = nil
  closeAttachPicker()
  disconnect(g_game, {
    onGameStart = function() end,
    onRuneSystemCategory = runeWindowOnCategory,
    onRuneSystemResult = runeWindowOnResult,
  })
  if runeWindow then
    runeWindow:destroy()
    runeWindow = nil
  end
end