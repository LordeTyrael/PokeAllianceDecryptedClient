InventorySlotStyles = {
  [InventorySlotHead] = "HeadSlot",
  [InventorySlotNeck] = "NeckSlot",
  [InventorySlotBack] = "BackSlot",
  [InventorySlotBody] = "BodySlot",
  [InventorySlotRight] = "RightSlot",
  [InventorySlotLeft] = "LeftSlot",
  [InventorySlotLeg] = "LegSlot",
  [InventorySlotFeet] = "FeetSlot",
  [InventorySlotFinger] = "FingerSlot",
  [InventorySlotAmmo] = "AmmoSlot"
}

pokemonWindow = nil
healthBar = nil
pokeHealthBar = nil
pokeballs = {}

orderPanel = nil

fightOffensiveBox = nil
fightBalancedBox = nil
fightDefensiveBox = nil
fightModeRadioGroup = nil
local confirmThrowWindow
local confirmUseWindow

modules.client_hotkeys.registerHotkeyCallback("POKEBAG",
  function(actionName, action, keyInfo, chatState, keyType)
    if pokemonButton and keyType == "primaryKey" and chatState == "chatDisabled" then
      pokemonButton:setTooltip(string.format("Pokémon (%s)", keyInfo.key))
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
  connect(LocalPlayer, { onHealthChange = onHealthChange,
                         onFreeCapacityChange = onPokeballsChange,
                         onStatesChange = onStatesChange,
                         onInventoryChange = onInventoryChange
                          })

  connect(g_game, { onGameStart = refresh,
                    onGameEnd = offline,
                    onFightModeChange = update,
                    onConfirmThrow = onConfirmThrow,
                    onConfirmUse = onConfirmUse,
                    -- protocolo custom 1585 (parsePokeHealth em C++); substituiu o extended 104
                    onPokeHealthChange = onPokeHealthChange
                  })

  pokemonButton = modules.client_topmenu.addMiddleGameToggleButton('pokemonButton', tr('Pokémon') .. ' (Ctrl+P)', '/images/ui/topbuttons/icons/pokemon', toggle)
  pokemonButton:setWidth(25)
  pokemonButton:setOn(true)

  pokemonWindow = g_ui.loadUI('pokemon', modules.game_interface.getRightPanel())
  pokemonWindow:disableResize()
  healthBar = pokemonWindow:recursiveGetChildById('healthBar')
  pokeHealthBar = pokemonWindow:recursiveGetChildById('pokeHealthBar')
  pokeballBar = pokemonWindow:recursiveGetChildById('pokeballBar')

  fightOffensiveBox = pokemonWindow:recursiveGetChildById('fightOffensiveBox')
  fightBalancedBox = pokemonWindow:recursiveGetChildById('fightBalancedBox')
  fightDefensiveBox = pokemonWindow:recursiveGetChildById('fightDefensiveBox')

  fightModeRadioGroup = UIRadioGroup.create()
  fightModeRadioGroup:addWidget(fightOffensiveBox)
  fightModeRadioGroup:addWidget(fightBalancedBox)
  fightModeRadioGroup:addWidget(fightDefensiveBox)

  orderPanel = pokemonWindow:recursiveGetChildById('orderPanel')
  separator2 = pokemonWindow:recursiveGetChildById('separator2')

  connect(fightModeRadioGroup, { onSelectionChange = onSetFightMode })

  if g_game.isOnline() then
    refresh()
    pokemonWindow:setup()
  end
end

function terminate()
  disconnect(LocalPlayer, { onHealthChange = onHealthChange,
                            onFreeCapacityChange = onPokeballsChange,
                            onStatesChange = onStatesChange,
                            onInventoryChange = onInventoryChange })

  disconnect(g_game, { onGameStart = refresh,
                       onGameEnd = offline,
                       onFightModeChange = update,
                       onConfirmThrow = onConfirmThrow,
                       onConfirmUse = onConfirmUse,
                       onPokeHealthChange = onPokeHealthChange })

  pokemonWindow:destroy()
  pokemonButton:destroy()
  fightModeRadioGroup:destroy()
end

function refresh()
  local player = g_game.getLocalPlayer()
  if g_game.isOnline() then
    onHealthChange(player, player:getHealth(), player:getMaxHealth())
    -- O sendExtendedOpcode(104, 'refresh') que existia aqui era no-op: nenhum handler no servidor
    -- escutava o C2S do extended 104, então o pedido de refresh nunca teve efeito.
    onPokeballsChange(player, player:getFreeCapacity())
    onStatesChange(player, player:getStates(), 0)
    local content = pokemonWindow:recursiveGetChildById('contentsPanel')
    if content and content.pokemonBackground then
      content.pokemonBackground.battleActive = false
      content.pokemonBackground.protectionActive = false
    end
    pokemonWindow:setup()
  end

  for i = InventorySlotFirst, InventorySlotLast do
    if g_game.isOnline() then
      onInventoryChange(player, i, player:getInventoryItem(i))
    else
      onInventoryChange(player, i, nil)
    end
  end

  if player then
    local char = g_game.getCharacterName()

    local lastCombatControls = g_settings.getNode('LastCombatControls')

    if not table.empty(lastCombatControls) then
      if lastCombatControls[char] then
        g_game.setFightMode(lastCombatControls[char].fightMode)
      end
    end
  end

  update()
end

function update()
  local fightMode = g_game.getFightMode()
  if fightMode == FightOffensive then
    fightModeRadioGroup:selectWidget(fightOffensiveBox)
  elseif fightMode == FightBalanced then
    fightModeRadioGroup:selectWidget(fightBalancedBox)
  else
    fightModeRadioGroup:selectWidget(fightDefensiveBox)
  end
end

function toggle()
  if pokemonButton:isOn() then
    pokemonWindow:close()
    pokemonButton:setOn(false)
  else
    pokemonWindow:open()
    pokemonButton:setOn(true)
  end
end

function toggleIcon(bitChanged)
  local content = pokemonWindow:recursiveGetChildById('contentsPanel')
  if not content then
    return
  end

  local background = content.pokemonBackground
  if not background then
    return
  end

  if bitChanged == 128 then
    background.battleActive = not background.battleActive
  elseif bitChanged == 16384 then
    background.protectionActive = not background.protectionActive
  else
    return
  end

  if background.battleActive and background.protectionActive then
    background:setImageColor("blue")
  elseif background.battleActive then
    background:setImageColor("red")
  elseif background.protectionActive then
    background:setImageColor("blue")
  else
    background:setImageColor()
  end
end


function offline()
  local lastCombatControls = g_settings.getNode('LastCombatControls')
  if not lastCombatControls then
    lastCombatControls = {}
  end

  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()
    lastCombatControls[char] = {
      fightMode = g_game.getFightMode(),
      chaseMode = g_game.getChaseMode()
    }

    g_settings.setNode('LastCombatControls', lastCombatControls)
  end
  confirmThrowWindowCleanup()
end

function onpokemonWindowClose()
  pokemonButton:setOn(false)
end

function onSkillButtonClick(button)
  local percentBar = button:getChildById('percent')
  if percentBar then
    percentBar:setVisible(not percentBar:isVisible())
    if percentBar:isVisible() then
      button:setHeight(21)
      pokemonWindow:setHeight(pokemonWindow:getHeight() + 6)
    else
      button:setHeight(21 - 6)
      pokemonWindow:setHeight(pokemonWindow:getHeight() - 6)
    end
  end
end

function onHealthChange(localPlayer, health, maxHealth)
  healthBar:setText(health .. ' / ' .. maxHealth)
  local totalWidth = 101
  local totalHeight = 14

  if maxHealth > 0 then
    local progressPercent = math.max((health / maxHealth * 100), 1)
    local clippedWidth = math.ceil(totalWidth * (progressPercent / 100))
    local rect = { x = 0, y = 0, width = clippedWidth, height = totalHeight }
    healthBar:setImageRect(rect)
  else
    healthBar:setImageRect({ x = 0, y = 0, width = totalWidth, height = totalHeight })
  end
end

-- Recebe o opcode 1585 (parsePokeHealth). Antes vinha como string "hp|hpmax" pelo extended 104 e era
-- fatiada aqui com string.explode; agora chegam dois inteiros direto do wire.
function onPokeHealthChange(mana, maxMana)
  local totalWidth = 101
  local totalHeight = 14

  if maxMana <= 0 then
    pokeHealthBar:clearText()
    pokeHealthBar:setImageRect({ x = 0, y = 0, width = totalWidth, height = totalHeight })
  else
    pokeHealthBar:setText(mana .. ' / ' .. maxMana)
    local progressPercent = math.max((mana / maxMana * 100), 1)
    local clippedWidth = math.ceil(totalWidth * (progressPercent / 100))
    pokeHealthBar:setImageRect({ x = 0, y = 0, width = clippedWidth, height = totalHeight })
  end
end

function onPokeballsChange(player, freeCapacity)
  local totalSlots = 6
  local used = 7 - freeCapacity

  if used < 0 then used = 0 end
  if used > totalSlots then used = totalSlots end

  for i = 1, totalSlots do
    if i <= used then
      pokeballBar["pokeball_" .. i]:setImageSource("images/pokeballs")
    else
      pokeballBar["pokeball_" .. i]:setImageSource("images/empty_ball")
    end
  end
end

function onStatesChange(localPlayer, now, old)
  if now == old then return end

  local bitsChanged = bit32.bxor(now, old)
  for i = 1, 32 do
    local pow = math.pow(2, i-1)
    if pow > bitsChanged then break end
    local bitChanged = bit32.band(bitsChanged, pow)
    if bitChanged ~= 0 then
      toggleIcon(bitChanged)
    end
  end
end

function onInventoryChange(player, slot, item, oldItem)
  if slot > InventorySlotPurse then return end
  local itemWidget = pokemonWindow:recursiveGetChildById('slot' .. slot)
  if item and itemWidget then
    itemWidget:setItem(item)
  else
    if itemWidget then
      itemWidget:setItem(nil)
    end
  end

  if slot == 8 then
    if item then
      pokemonWindow.contentsPanel.pokemonLooktype:setOutfit({type = item:getPokemonLookType()})
    else
      pokemonWindow.contentsPanel.pokemonLooktype:setOutfit({type = 0})
    end
  end
end

function onSetFightMode(self, selectedFightButton)
  if selectedFightButton == nil then return end
  local buttonId = selectedFightButton:getId()
  local fightMode = 1
  if buttonId == 'fightOffensiveBox' then
    fightMode = 1
  elseif buttonId == 'fightBalancedBox' then
    fightMode = 2
  else
    fightMode = 3
  end
	-- O extended opcode 107 que existia aqui era SENDER MORTO: nenhum handler no servidor, em nenhum dos
	-- dois caminhos de dispatch. O fight mode real já viaja no setFightMode acima (opcode 0xA0 vanilla).
	g_game.setFightMode(fightMode)
end

function hideOrderPanel()
  orderPanel:setHeight(0)
  pokemonWindow:setHeight(120)
  orderPanel:setVisible(false)
  separator2:setVisible(false)

end

function showOrderPanel()
  orderPanel:setHeight(34)
  pokemonWindow:setHeight(158)
  orderPanel:setVisible(true)
  separator2:setVisible(true)
end

function toggleOrder()
  if orderPanel:isVisible() then
    hideOrderPanel()
  else
    showOrderPanel()
  end
end

function onMiniWindowClose()
  pokemonButton:setOn(false)
end

local function displayItemConfirmBox(title, message, item, onYes, onNo)
  local dialog = g_ui.createWidget('AllianceMessageBoxWindow', rootWidget)
  dialog:setSize({width = 420, height = 210})

  local function close()
    if dialog and not dialog:isDestroyed() then
      dialog:destroy()
    end
  end

  local titleLabel = g_ui.createWidget('AllianceTitle', dialog)
  titleLabel:setText(title)
  titleLabel:addAnchor(AnchorTop, 'parent', AnchorTop)
  titleLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  titleLabel:setMarginTop(8)

  local itemWidget = g_ui.createWidget('Item', dialog)
  itemWidget:setSize({width = 64, height = 64})
  itemWidget:setVirtual(true)
  itemWidget:setItem(Item.create(item:getId(), item:getCountOrSubType()))
  itemWidget:addAnchor(AnchorTop, 'prev', AnchorBottom)
  itemWidget:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  itemWidget:setMarginTop(12)

  local messageLabel = g_ui.createWidget('AllianceLabel', dialog)
  messageLabel:setText(message)
  messageLabel:addAnchor(AnchorTop, 'prev', AnchorBottom)
  messageLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  messageLabel:setMarginTop(10)

  local buttonHolder = g_ui.createWidget('AllianceBoxButtonHolder', dialog)
  buttonHolder:addAnchor(AnchorBottom, 'parent', AnchorBottom)
  buttonHolder:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)

  local yesBtn = g_ui.createWidget('AllianceStraightBlueButton', buttonHolder)
  yesBtn:setText(tr('Yes'))
  yesBtn:setMarginLeft(0)
  yesBtn:addAnchor(AnchorBottom, 'parent', AnchorBottom)
  yesBtn:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  connect(yesBtn, { onClick = function()
    close()
    if onYes then onYes() end
  end })

  local noBtn = g_ui.createWidget('AllianceStraightBlueButton', buttonHolder)
  noBtn:setText(tr('No'))
  noBtn:setMarginLeft(25)
  noBtn:addAnchor(AnchorBottom, 'prev', AnchorBottom)
  noBtn:addAnchor(AnchorLeft, 'prev', AnchorRight)
  connect(noBtn, { onClick = function()
    close()
    if onNo then onNo() end
  end })

  buttonHolder:setWidth(yesBtn:getWidth() + noBtn:getWidth() + 25)
  buttonHolder:setHeight(yesBtn:getHeight())

  connect(dialog, { onEscape = function() close(); if onNo then onNo() end end })
  connect(dialog, { onEnter  = function() close(); if onYes then onYes() end end })

  return dialog
end

function confirmThrowWindowCleanup()
    if confirmThrowWindow then
        if not confirmThrowWindow:isDestroyed() then
            confirmThrowWindow:destroy()
        end
        confirmThrowWindow = nil
    end
end

function onConfirmThrow(item, toPos, count)
  if confirmThrowWindow then
    return
  end

  confirmThrowWindow = displayItemConfirmBox(
    tr('Confirm'),
    tr("Are you sure you want to throw this item on the floor?"),
    item,
    function()
      g_game.move(item, toPos, count, true)
      confirmThrowWindow = nil
    end,
    function() confirmThrowWindow = nil end
  )
end


function confirmUseWindowCleanup()
    if confirmUseWindow then
        if not confirmUseWindow:isDestroyed() then
            confirmUseWindow:destroy()
        end
        confirmUseWindow = nil
    end
end

function onConfirmUse(item)
  if confirmUseWindow then
    return
  end

  confirmUseWindow = displayItemConfirmBox(
    tr('Confirm'),
    tr("Are you sure you want to use this?"),
    item,
    function()
      g_game.use(item, true)
      confirmUseWindow = nil
    end,
    function() confirmUseWindow = nil end
  )
end