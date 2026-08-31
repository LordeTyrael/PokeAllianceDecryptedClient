local pokelogWindow
local elementGridPanel
pokemonListPanel = nil
local detailPanel
local elementGrid
pokemonList = nil
local pointsLabel
local bankLabel
local searchField
local collectAllButton

-- Collect All needs the server-side 0x06 CLAIM_ALL opcode; flip when it ships.
local COLLECT_ALL_ENABLED = true

-- Rune bar widgets
local runeSlots = {}
local RUNE_CATEGORIES = { "offensive", "defensive", "utility" }
local RUNE_CAT_LABELS = { offensive = "OFFENSIVE", defensive = "DEFENSIVE", utility = "UTILITY" }

-- State
local currentElement = nil
selectedPokemon = nil

-- Cache for pokemon config data (rewards)
configCache = {}

-- Cache for pokemon pokelog data
pokelogData = {}

-- elementName(lower) -> widget do botao na grade, para aplicar o badge de "!" sem varrer filhos
elementButtons = {}

-- Element types (alphabetical)
local ELEMENTS = {
  "Bug", "Dark", "Dragon", "Electric", "Fairy", "Fighting",
  "Fire", "Flying", "Ghost", "Grass", "Ground", "Ice",
  "Normal", "Poison", "Psychic", "Rock", "Steel", "Water"
}

local function formatNumber(n)
  if n >= 1000000 then
    local v = n / 1000000
    if v == math.floor(v) then
      return string.format('%dM', v)
    else
      return string.format('%.1fM', v):gsub('%.0M', 'M')
    end
  elseif n >= 1000 then
    local v = n / 1000
    if v == math.floor(v) then
      return string.format('%dk', v)
    else
      return string.format('%.1fk', v):gsub('%.0k', 'k')
    end
  end
  return tostring(n)
end

local function refreshRuneTargetPreview(targetLabel, targetOutfit, targetName, targetLookType)
  local hasLookType = targetOutfit and targetLookType and targetLookType > 0

  if targetOutfit then
    if hasLookType then
      targetOutfit:setOutfit({type = targetLookType})
      targetOutfit:show()
    else
      targetOutfit:hide()
    end
  end

  if targetLabel then
    targetLabel:setMarginLeft(hasLookType and 28 or 6)
    targetLabel:setText((targetName and targetName ~= '') and targetName:toHumanCase() or 'Click to browse')
  end
end

local function bindPokelogModalInputLock(dialog)
  if not dialog then
    return nil
  end

  local previousOnDestroy = dialog.onDestroy

  g_uistates.push(dialog)
  dialog.onDestroy = function()
    if previousOnDestroy then
      previousOnDestroy()
    end

    if pokelogWindow and pokelogWindow:isVisible() then
      g_uistates.push(pokelogWindow)
    else
      g_uistates.remove(dialog)
    end
  end

  return dialog
end

local function showPokelogModalBox(title, message, buttons, onEnterCallback, onEscapeCallback)
  local dialog
  local wrappedButtons = {}

  local function wrapModalCallback(callback)
    if not callback then
      return nil
    end

    return function()
      if dialog then
        dialog:destroy()
      end

      callback()
    end
  end

  for index, button in ipairs(buttons or {}) do
    wrappedButtons[index] = {
      text = button.text,
      callback = wrapModalCallback(button.callback),
    }
  end

  wrappedButtons.anchor = buttons and buttons.anchor or nil

  dialog = bindPokelogModalInputLock(
    displayAllianceBox(
      title,
      message,
      wrappedButtons,
      wrapModalCallback(onEnterCallback),
      wrapModalCallback(onEscapeCallback)
    )
  )

  return dialog
end

local function onGameEnd()
  if not pokelogWindow then return end
  if runeWindowClose then
    runeWindowClose()
  end
  pokelogWindow:hide()
  g_uistates.remove(pokelogWindow)
  -- clear rune bar
  for _, w in ipairs(runeSlots or {}) do
    local ri = w:recursiveGetChildById('runeImage')
    local pb = w:recursiveGetChildById('runePlusBtn')
    local ll = w:recursiveGetChildById('runeLevelLabel')
    local nl = w:recursiveGetChildById('runeNameLabel')
    local to = w:recursiveGetChildById('runeTargetOutfit')
    local rb = w:recursiveGetChildById('runeRemoveBtn')
    if ri then ri:hide() end
    if pb then pb:show() end
    if ll then ll:hide() end
    if nl then nl:hide() end
    if to then to:hide() end
    if rb then rb:hide() end
  end
  configCache = {}
  pokelogData = {}
  currentElement = nil
  selectedPokemon = nil
end

modules.client_hotkeys.registerHotkeyCallback("POKELOG",
  function(actionName, action, keyInfo, chatState, keyType)
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
  pokelogWindow = g_ui.loadUI('pokelog', modules.game_interface.getRootPanel())
  elementGridPanel = pokelogWindow:recursiveGetChildById('elementGridPanel')
  pokemonListPanel = pokelogWindow:recursiveGetChildById('pokemonListPanel')
  detailPanel = pokelogWindow:recursiveGetChildById('detailPanel')
  elementGrid = pokelogWindow:recursiveGetChildById('elementGrid')
  pokemonList = pokelogWindow:recursiveGetChildById('pokemonList')
  pointsLabel = pokelogWindow:recursiveGetChildById('pointsLabel')
  bankLabel = pokelogWindow:recursiveGetChildById('bankLabel')
  searchField = pokelogWindow:recursiveGetChildById('searchField')
  collectAllButton = pokelogWindow:recursiveGetChildById('collectAllButton')

  pokelogWindow:hide()

  createElementGrid()
  applyCollectAllState()

  local trackerButton = pokelogWindow:recursiveGetChildById('trackerButton')
  if trackerButton then
    trackerButton.onClick = function()
      if selectedPokemon then
        toggleTracker(selectedPokemon)
      end
    end
  end

  local dexButton = pokelogWindow:recursiveGetChildById('detailDexButton')
  if dexButton then
    dexButton.onClick = function()
      if selectedPokemon then
        modules.game_pokedex.openFor(selectedPokemon)
      end
    end
  end

  connect(g_game, {
    onGameStart = function()
      local icon = pokelogWindow:recursiveGetChildById('bankIcon')
      if icon then icon:setItemId(37382) end
    end,
    onGameEnd = onGameEnd,
    onPokelogInfo = onPokelogInfo,
    onPokelogListInfo = onPokelogListInfo,
    onPokelogUpdateInfo = onPokelogUpdateInfo,
    onPokelogPoints = onPokelogPoints,
    onPokelogElementList = onPokelogElementList,
    onPokelogClaimAll = onPokelogClaimAll,
    onPokelogClaimableSummary = onPokelogClaimableSummary,
    onRuneSystemState = onRuneSystemState,
  })

  connect(g_client, {
    onTrainerClose = close
  })

  -- Rune bar slot widgets
  runeSlots = {
    pokelogWindow:recursiveGetChildById('runeSlot0'),
    pokelogWindow:recursiveGetChildById('runeSlot1'),
    pokelogWindow:recursiveGetChildById('runeSlot2'),
  }

  for index, category in ipairs(RUNE_CATEGORIES) do
    local slotWidget = runeSlots[index]
    if slotWidget then
      slotWidget.onClick = function()
        runeWindowOpen(category)
      end
    end
  end

  runeWindowInit()

  trackerInit()
end

function terminate()
  runeWindowTerminate()

  trackerTerminate()

  disconnect(g_game, {
    onGameStart = function() end,
    onGameEnd = onGameEnd,
    onPokelogInfo = onPokelogInfo,
    onPokelogListInfo = onPokelogListInfo,
    onPokelogUpdateInfo = onPokelogUpdateInfo,
    onPokelogPoints = onPokelogPoints,
    onPokelogElementList = onPokelogElementList,
    onPokelogClaimAll = onPokelogClaimAll,
    onPokelogClaimableSummary = onPokelogClaimableSummary,
    onRuneSystemState = onRuneSystemState,
  })

  disconnect(g_client, {
    onTrainerClose = close
  })

  if pokelogWindow then
    pokelogWindow:destroy()
    pokelogWindow = nil
  end
end

local function paintTrackerButton(pokemonName)
  local button = detailPanel and detailPanel:getChildById('trackerButton')
  if not button then return end

  local tracked = isTracked(pokemonName)
  button:setIconColor(tracked and '#55bbff' or '#666666')
  button:setTooltip(tracked and tr('Stop Tracking') or tr('Add to Tracker'))
end

function updateTrackerButton(pokemonName)
  if not selectedPokemon then return end
  if selectedPokemon:lower() ~= pokemonName:lower() then return end

  paintTrackerButton(pokemonName)
end

--- Reordena a lista JÁ MONTADA (ao favoritar, ao coletar). Mesma ordem do sortEntries: pronto para
--- coletar > favoritado > dex. As chaves saem uma vez, fora do comparador, pelo mesmo motivo.
function refreshPokemonListSort()
  if not pokemonList then return end

  local children = pokemonList:getChildren()
  if not children or #children == 0 then return end

  local entries = {}
  for _, child in ipairs(children) do
    if child.pokemonName then
      local data = pokelogData[child.pokemonName:lower()]
      table.insert(entries, {
        widget = child,
        ready = (data and (data.lastUnclaimedRewardStage or 0) > 0) and 1 or 0,
        tracked = isTracked(child.pokemonName) and 1 or 0,
        dex = tonumber(g_pokemonCyclopedia.getDexNumber(child.pokemonName:lower())) or 99999,
      })
    end
  end

  table.sort(entries, function(a, b)
    if a.ready ~= b.ready then return a.ready > b.ready end
    if a.tracked ~= b.tracked then return a.tracked > b.tracked end
    return a.dex < b.dex
  end)

  for idx, e in ipairs(entries) do
    pokemonList:moveChildToIndex(e.widget, idx)
  end
end

-- =====================
-- Element Grid
-- =====================

function createElementGrid()
  if not elementGrid then return end

  elementButtons = {}

  for _, elementName in ipairs(ELEMENTS) do
    local btn = g_ui.createWidget('PokelogElementButton', elementGrid)
    local lowerName = elementName:lower()
    elementButtons[lowerName] = btn

    local icon = btn:getChildById('icon')
    if icon then
      local idx = g_pokemonCyclopedia.getElementSpriteIndex(elementName)
      if idx and idx > 0 then
        icon:setImageClip({x = 0, y = 24 * (idx - 1), width = 24, height = 24})
      end
    end

    local label = btn:getChildById('typeName')
    if label then
      label:setText(elementName)
    end

    btn.onClick = function()
      onElementClick(elementName)
    end
  end
end

function onElementClick(elementName)
  showPokemonList(elementName)
  sendRequestElementList(elementName)
end

function onSearchTextChange(text)
  if not pokemonList then return end
  local filter = text:lower():gsub('%s+', '')

  local children = pokemonList:getChildren()
  for _, child in ipairs(children) do
    if child.pokemonName then
      local name = child.pokemonName:lower():gsub('%s+', '')
      child:setVisible(filter == '' or name:find(filter, 1, true) ~= nil)
    end
  end
end

-- =====================
-- Collect All
-- =====================

function collectAll()
  if not COLLECT_ALL_ENABLED then return end

  showPokelogModalBox(
    tr('Collect All'),
    tr('Claim all available rewards?'),
    {
      { text = tr('Confirm'), callback = function() sendClaimAll() end },
      { text = tr('Cancel'), callback = function() end },
      anchor = AnchorHorizontalCenter,
    }
  )
end

function applyCollectAllState()
  if not collectAllButton then return end

  if COLLECT_ALL_ENABLED then
    collectAllButton:setOpacity(1)
    collectAllButton:setTooltip(tr('Collect all available rewards'))
    collectAllButton.onClick = collectAll
  else
    collectAllButton:setOpacity(0.4)
    collectAllButton:setTooltip(tr('Coming soon'))
    collectAllButton.onClick = nil
  end
end

-- =====================
-- Rune bar
-- =====================

local function refreshRuneBar(activeCategories)
  local slots = {}
  for _, entry in ipairs(activeCategories or {}) do
    if entry.category then
      slots[entry.category] = entry
    end
  end

  for i, cat in ipairs(RUNE_CATEGORIES) do
    local widget = runeSlots[i]
    if not widget then goto continue end

    local runeImage    = widget:recursiveGetChildById('runeImage')
    local plusBtn      = widget:recursiveGetChildById('runePlusBtn')
    local levelLabel   = widget:recursiveGetChildById('runeLevelLabel')
    local targetOutfit = widget:recursiveGetChildById('runeTargetOutfit')
    local removeBtn    = widget:recursiveGetChildById('runeRemoveBtn')

    local info = slots[cat]
    if info and info.hasRune then
      if runeImage then
        runeImage:setImageSource('/images/modules/runes/' .. info.runeKey .. '.png')
        runeImage:show()
      end
      if plusBtn then plusBtn:hide() end
      if levelLabel then
        levelLabel:setText(toRoman(info.level))
        levelLabel:show()
      end
      local rk = info.runeKey:gsub('_', ' '):gsub('(%a)([%w]*)', function(f, r) return f:upper() .. r end)
      widget:setTooltip(rk)
      if targetOutfit then
        if info.targetLookType and info.targetLookType > 0 then
          targetOutfit:setOutfit({type = info.targetLookType})
          targetOutfit:show()
        else
          targetOutfit:hide()
        end
      end
      removeBtn:show()
      removeBtn.onClick = function()
        local targetName = info.targetName
        showPokelogModalBox(
          'Detach Rune',
          string.format('Cost: $500,000.\nDetach %s rune from %s?',
            RUNE_CAT_LABELS[cat], targetName:gsub('^%l', string.upper)),
          {
            { text = 'Confirm', callback = function()
                g_game.sendRuneDetach(targetName, cat)
                g_game.sendRuneRequestState()
              end
            },
            { text = 'Cancel', callback = function() end },
            anchor = AnchorHorizontalCenter,
          }
        )
      end
    else
      if runeImage then runeImage:hide() end
      if plusBtn then plusBtn:show() end
      if levelLabel then levelLabel:hide() end
      if nameLabel then nameLabel:hide() end
      if targetOutfit then targetOutfit:hide() end
      removeBtn:hide()
    end

    ::continue::
  end
end

function onRuneSystemState(pokelogPoints, bankBalance, activeCategories)
  if not pokelogWindow then return end
  refreshRuneBar(activeCategories)
  if bankLabel then
    bankLabel:setText('$' .. formatNumber(bankBalance or 0))
  end
end

-- =====================
-- Navigation (3 views)
-- =====================

function toggle()
  if not pokelogWindow then return end

  if pokelogWindow:isVisible() then
    close()
  else
    showElementGrid()
    pokelogWindow:show()
    pokelogWindow:raise()
    g_effects.fadeIn(pokelogWindow)
    g_uistates.push(pokelogWindow)
    sendRequestPoints()
    sendRequestClaimableSummary()
    g_game.sendRuneRequestState()
  end
end

function close()
  if not pokelogWindow then return end
  if not pokelogWindow:isVisible() then return end

  g_effects.fadeOut(pokelogWindow)
  scheduleEvent(function()
    if pokelogWindow then
      pokelogWindow:hide()
      g_uistates.remove(pokelogWindow)
    end
  end, 500)
end

function onEscape()
  if detailPanel and detailPanel:isVisible() then
    showPokemonListBack()
  elseif pokemonListPanel and pokemonListPanel:isVisible() then
    showElementGrid()
  else
    close()
  end
end

function showElementGrid()
  if elementGridPanel then elementGridPanel:setVisible(true) end
  if pokemonListPanel then pokemonListPanel:setVisible(false) end
  if detailPanel then detailPanel:setVisible(false) end
  currentElement = nil
  selectedPokemon = nil
end

function showPokemonList(element)
  if elementGridPanel then elementGridPanel:setVisible(false) end
  if pokemonListPanel then pokemonListPanel:setVisible(true) end
  if detailPanel then detailPanel:setVisible(false) end
  if searchField then searchField:setText('') end
  if pokemonList then pokemonList:destroyChildren() end
  currentElement = element
  selectedPokemon = nil
end

function showPokemonListBack()
  if not currentElement then
    showElementGrid()
    return
  end
  if elementGridPanel then elementGridPanel:setVisible(false) end
  if pokemonListPanel then pokemonListPanel:setVisible(true) end
  if detailPanel then detailPanel:setVisible(false) end
  selectedPokemon = nil
end

function showDetailView(pokemonName)
  if elementGridPanel then elementGridPanel:setVisible(false) end
  if pokemonListPanel then pokemonListPanel:setVisible(false) end
  if detailPanel then detailPanel:setVisible(true) end
  selectedPokemon = pokemonName
  updateDetailPanel(pokemonName)
end

-- =====================
-- Protocol callbacks
-- =====================

function onPokelogPoints(points)
  if pointsLabel then
    pointsLabel:setText(tostring(points))
  end
end

--- Badge de "!" nos elementos que têm recompensa pronta.
--- O servidor só manda elemento com contagem > 0, então zera todos antes de aplicar — é o que faz o
--- badge SUMIR depois de coletar, sem precisar de um pacote de "limpa este aqui".
function onPokelogClaimableSummary(total, elements)
  for _, btn in pairs(elementButtons) do
    local badge = btn:getChildById('claimBadge')
    local countLabel = btn:getChildById('claimCount')
    if badge then badge:setVisible(false) end
    if countLabel then countLabel:setVisible(false) end
  end

  for _, element in ipairs(elements or {}) do
    local btn = elementButtons[element.elementName:lower()]
    if btn then
      local badge = btn:getChildById('claimBadge')
      local countLabel = btn:getChildById('claimCount')
      if badge then badge:setVisible(true) end
      if countLabel then
        countLabel:setText(tostring(element.count))
        countLabel:setVisible(true)
      end
    end
  end

  -- Deixa explícito no botão de coletar tudo quanto há pendente, que era a outra queixa do feedback
  -- ("é meio que na cabeça você pesquisa o pokémon e vê se coletou").
  if collectAllButton then
    if total and total > 0 then
      collectAllButton:setText(tr('Collect All') .. ' (' .. total .. ')')
    else
      collectAllButton:setText(tr('Collect All'))
    end
  end
end

function onPokelogClaimAll(points, entries)
  if pointsLabel then
    pointsLabel:setText(tostring(points))
  end

  if not entries then return end

  for _, entry in ipairs(entries) do
    local lowerName = entry.pokemonName:lower()
    local oldData = pokelogData[lowerName]

    pokelogData[lowerName] = {
      pokemonName = entry.pokemonName,
      lookType = oldData and oldData.lookType or 0,
      count = entry.count,
      rewardStage = entry.rewardStage,
      lastUnclaimedRewardStage = entry.lastUnclaimedRewardStage
    }

    updatePokemonEntry(entry.pokemonName)

    if selectedPokemon and selectedPokemon:lower() == lowerName then
      updateDetailPanel(entry.pokemonName)
    end
  end

  -- Uma vez só, depois de aplicar todas as entradas: o que foi coletado deixa de estar "pronto" e
  -- desce, mantendo o topo da lista com o que ainda falta.
  refreshPokemonListSort()
end

function onPokelogInfo(pokemonName, lookType, count, rewardStage, lastUnclaimedRewardStage, hasConfigData, rewards)
  local lowerName = pokemonName:lower()

  pokelogData[lowerName] = {
    pokemonName = pokemonName,
    lookType = lookType,
    count = count,
    rewardStage = rewardStage,
    lastUnclaimedRewardStage = lastUnclaimedRewardStage
  }

  if hasConfigData and rewards and #rewards > 0 then
    configCache[lowerName] = rewards
  end

  updatePokemonEntry(pokemonName)

  if selectedPokemon and selectedPokemon:lower() == lowerName then
    updateDetailPanel(pokemonName)
  end
end

--- Ordem da lista: quem tem recompensa PRONTA primeiro, depois favoritados, depois dex.
---
--- PERF: as chaves saem UMA vez por entrada, fora do comparador. table.sort chama o comparador
--- O(n log n) vezes — com isTracked() e getDexNumber() lá dentro, uma lista de 150 pokémon fazia
--- ~2200 lookups em vez de 150. Converter o dex para número aqui também tira a comparação
--- lexicográfica (em string, '9' > '10').
local function sortEntries(entries)
  local keys = {}
  for i = 1, #entries do
    local entry = entries[i]
    keys[entry] = {
      ready = (entry.lastUnclaimedRewardStage or 0) > 0 and 1 or 0,
      tracked = isTracked(entry.pokemonName) and 1 or 0,
      dex = tonumber(g_pokemonCyclopedia.getDexNumber(entry.pokemonName:lower())) or 99999,
    }
  end

  table.sort(entries, function(a, b)
    local ka, kb = keys[a], keys[b]
    if ka.ready ~= kb.ready then return ka.ready > kb.ready end
    if ka.tracked ~= kb.tracked then return ka.tracked > kb.tracked end
    return ka.dex < kb.dex
  end)
  return entries
end

function onPokelogListInfo(entries)
  if not entries or not pokemonList then return end

  sortEntries(entries)

  for _, entry in ipairs(entries) do
    local lowerName = entry.pokemonName:lower()

    pokelogData[lowerName] = {
      pokemonName = entry.pokemonName,
      lookType = entry.lookType or 0,
      count = entry.count,
      rewardStage = entry.rewardStage,
      lastUnclaimedRewardStage = entry.lastUnclaimedRewardStage
    }

    if entry.rewards and #entry.rewards > 0 then
      configCache[lowerName] = entry.rewards
    end
  end

  if not (pokemonListPanel and pokemonListPanel:isVisible()) then return end

  pokemonList:destroyChildren()
  for _, entry in ipairs(entries) do
    createPokemonEntry(entry.pokemonName)
  end
  if searchField and not searchField:isDestroyed() then searchField:focus() end
end

function onPokelogElementList(elementName, entries)
  if not entries or not pokemonList then return end

  if currentElement and currentElement:lower() ~= elementName:lower() then return end

  sortEntries(entries)

  for _, entry in ipairs(entries) do
    local lowerName = entry.pokemonName:lower()

    pokelogData[lowerName] = {
      pokemonName = entry.pokemonName,
      lookType = entry.lookType or 0,
      count = entry.count,
      rewardStage = entry.rewardStage,
      lastUnclaimedRewardStage = entry.lastUnclaimedRewardStage
    }

    if entry.rewards and #entry.rewards > 0 then
      configCache[lowerName] = entry.rewards
    end
  end

  if not (pokemonListPanel and pokemonListPanel:isVisible()) then return end

  pokemonList:destroyChildren()
  for _, entry in ipairs(entries) do
    createPokemonEntry(entry.pokemonName)
  end
  if searchField and not searchField:isDestroyed() then searchField:focus() end
end

function onPokelogUpdateInfo(pokemonName, count, rewardStage, lastUnclaimedRewardStage)
  local lowerName = pokemonName:lower()
  local oldData = pokelogData[lowerName]

  pokelogData[lowerName] = {
    pokemonName = pokemonName,
    lookType = oldData and oldData.lookType or 0,
    count = count,
    rewardStage = rewardStage,
    lastUnclaimedRewardStage = lastUnclaimedRewardStage
  }

  updatePokemonEntry(pokemonName)

  if selectedPokemon and selectedPokemon:lower() == lowerName then
    updateDetailPanel(pokemonName)
  end
end

-- =====================
-- UI Logic
-- =====================

function createPokemonEntry(pokemonName)
  if not pokemonList then return end

  local lowerName = pokemonName:lower()
  local data = pokelogData[lowerName]
  if not data then return end

  local entryId = 'entry_' .. lowerName:gsub(' ', '_')
  local entry = g_ui.createWidget('PokelogPokemonEntry', pokemonList)
  entry:setId(entryId)
  entry.pokemonName = pokemonName
  entry:setTooltip(pokemonName:toHumanCase())
  entry.onClick = function()
    selectPokemon(pokemonName)
  end

  local outfitIcon = entry:getChildById('outfitIcon')
  if outfitIcon and data.lookType and data.lookType > 0 then
    outfitIcon:setOutfit({type = data.lookType})
  end

  -- Set element icons from cyclopedia
  local elementIcon = entry:recursiveGetChildById('elementIcon')
  local elementIcon2 = entry:recursiveGetChildById('elementIcon2')
  local elementRow = entry:getChildById('elementRow')
  local hasSecondary = g_pokemonCyclopedia.hasSecondaryType(pokemonName)
  local showPrimary = false
  local showSecondary = false

  if elementIcon then
    local idx = g_pokemonCyclopedia.getPrimarySpriteIndex(pokemonName)
    if idx and idx > 0 then
      elementIcon:setImageClip({x = 0, y = 24 * (idx - 1), width = 24, height = 24})
      elementIcon:setVisible(true)
      showPrimary = true
    else
      elementIcon:setVisible(false)
    end
  end

  if elementIcon2 then
    if hasSecondary then
      local idx2 = g_pokemonCyclopedia.getSecondarySpriteIndex(pokemonName)
      if idx2 and idx2 > 0 then
        elementIcon2:setImageClip({x = 0, y = 24 * (idx2 - 1), width = 24, height = 24})
        elementIcon2:setVisible(true)
        showSecondary = true
      else
        elementIcon2:setVisible(false)
      end
    else
      elementIcon2:setVisible(false)
    end
  end

  if elementRow then
    if showPrimary and showSecondary then
      elementRow:setWidth(33) -- 16 + 1 + 16
    elseif showPrimary then
      elementRow:setWidth(16)
    else
      elementRow:setWidth(0)
    end
  end

  updatePokemonEntryLabels(entry, data)
end

function updatePokemonEntry(pokemonName)
  if not pokemonList then return end

  local lowerName = pokemonName:lower()
  local data = pokelogData[lowerName]
  if not data then return end

  local entryId = 'entry_' .. lowerName:gsub(' ', '_')
  local entry = pokemonList:getChildById(entryId)
  if not entry then return end

  updatePokemonEntryLabels(entry, data)
end

function updatePokemonEntryLabels(entry, data)
  local nameLabel = entry:getChildById('name')
  if nameLabel then
    nameLabel:setText(data.pokemonName:toHumanCase())
  end

  local readyBadge = entry:getChildById('readyBadge')
  if readyBadge then
    readyBadge:setVisible((data.lastUnclaimedRewardStage or 0) > 0)
  end

  local lowerName = data.pokemonName:lower()
  local rewards = configCache[lowerName]
  local totalStages = rewards and #rewards or 3
  local count = data.count or 0
  local rewardStage = data.rewardStage or 0

  local progressBar = entry:getChildById('progressBarBg')
  if progressBar then
    local segWidth = 32

    for i = 1, 3 do
      local seg = progressBar:getChildById('seg' .. i)
      if seg then
        local fill = seg:getChildById('fill')
        if fill then
          if i <= totalStages and rewards then
            local goal = rewards[i] and rewards[i].count or 0
            local prevGoal = 0
            if i > 1 and rewards[i - 1] then
              prevGoal = rewards[i - 1].count
            end

            local segRange = goal - prevGoal
            local segProgress = 0
            if segRange > 0 then
              segProgress = math.max(0, math.min((count - prevGoal) / segRange, 1.0))
            end

            fill:setWidth(math.floor(segWidth * segProgress))

            if i <= rewardStage then
              fill:setBackgroundColor('#00aa00')
            elseif segProgress >= 1.0 then
              fill:setBackgroundColor('#ffd700')
            else
              if i == 1 then
                fill:setBackgroundColor('#2ea1f8')
              elseif i == 2 then
                fill:setBackgroundColor('#d4a017')
              else
                fill:setBackgroundColor('#00ff00')
              end
            end
          else
            fill:setWidth(0)
          end
        end
      end
    end
  end
end

function selectPokemon(pokemonName)
  selectedPokemon = pokemonName
  local lowerName = pokemonName:lower()
  local hasCache = configCache[lowerName] ~= nil
  sendRequestInfo(pokemonName, hasCache)
  showDetailView(pokemonName)
end

function updateDetailPanel(pokemonName)
  if not detailPanel then return end

  local lowerName = pokemonName:lower()
  local data = pokelogData[lowerName]
  if not data then return end

  local detailCreature = detailPanel:getChildById('detailCreature')
  local detailElementIcon = detailPanel:recursiveGetChildById('detailElementIcon')
  local detailElementIcon2 = detailPanel:recursiveGetChildById('detailElementIcon2')
  local nameLabel = detailPanel:getChildById('detailName')
  local rewardDisplayRow = detailPanel:getChildById('rewardDisplayRow')

  paintTrackerButton(pokemonName)

  if detailCreature then
    if data.lookType and data.lookType > 0 then
      detailCreature:setOutfit({type = data.lookType})
    end
  end

  local showPrimary = false
  local showSecondary = false

  if detailElementIcon then
    local idx = g_pokemonCyclopedia.getPrimarySpriteIndex(pokemonName)
    if idx and idx > 0 then
      detailElementIcon:setImageClip({x = 0, y = 24 * (idx - 1), width = 24, height = 24})
      detailElementIcon:setVisible(true)
      showPrimary = true
    else
      detailElementIcon:setVisible(false)
    end
  end

  if detailElementIcon2 then
    local hasSecondary = g_pokemonCyclopedia.hasSecondaryType(pokemonName)
    if hasSecondary then
      local idx2 = g_pokemonCyclopedia.getSecondarySpriteIndex(pokemonName)
      if idx2 and idx2 > 0 then
        detailElementIcon2:setImageClip({x = 0, y = 24 * (idx2 - 1), width = 24, height = 24})
        detailElementIcon2:setVisible(true)
        showSecondary = true
      else
        detailElementIcon2:setVisible(false)
      end
    else
      detailElementIcon2:setVisible(false)
    end
  end

  local detailElementRow = detailPanel:getChildById('detailElementRow')
  if detailElementRow then
    if showPrimary and showSecondary then
      detailElementRow:setWidth(50) -- 24 + 2 + 24
    elseif showPrimary then
      detailElementRow:setWidth(24)
    else
      detailElementRow:setWidth(0)
    end
  end

  if nameLabel then
    nameLabel:setText(pokemonName:toHumanCase())
  end

  local detailDefeats = detailPanel:getChildById('detailDefeats')
  if detailDefeats then
    detailDefeats:setText(tr('%d Defeats', data.count or 0))
  end

  -- Segmented progress bar
  local rewards = configCache[lowerName]
  local count = data.count or 0
  local rewardStage = data.rewardStage or 0
  local totalStages = rewards and #rewards or 3

  local maxCount = 0
  if rewards and #rewards > 0 then
    maxCount = rewards[#rewards].count or 0
  end

  local detailProgressBg = detailPanel:recursiveGetChildById('detailProgressBg')
  if detailProgressBg then
    for i = 1, 3 do
      local seg = detailProgressBg:getChildById('seg' .. i)
      if seg then
        local fill = seg:getChildById('fill')
        if fill then
          if i <= totalStages and rewards then
            local goal = rewards[i] and rewards[i].count or 0
            local prevGoal = 0
            if i > 1 and rewards[i - 1] then
              prevGoal = rewards[i - 1].count
            end

            local segRange = goal - prevGoal
            local segProgress = 0
            if segRange > 0 then
              segProgress = math.max(0, math.min((count - prevGoal) / segRange, 1.0))
            end

            if segProgress >= 1.0 then
              fill:removeAnchor(AnchorRight)
              fill:addAnchor(AnchorRight, 'parent', AnchorRight)
            else
              fill:removeAnchor(AnchorRight)
              local segWidth = seg:getWidth()
              fill:setWidth(math.floor(segWidth * segProgress))
            end

            if i <= rewardStage then
              fill:setBackgroundColor('#00aa00')
            elseif segProgress >= 1.0 then
              fill:setBackgroundColor('#ffd700')
            else
              if i == 1 then
                fill:setBackgroundColor('#2ea1f8')
              elseif i == 2 then
                fill:setBackgroundColor('#d4a017')
              else
                fill:setBackgroundColor('#00ff00')
              end
            end

            -- Milestone label inside segment
            local milestoneLabel = seg:getChildById('milestoneLabel')
            if milestoneLabel then
              milestoneLabel:setText(formatNumber(rewards[i].count))
            end
          else
            fill:setWidth(0)
            local milestoneLabel = seg:getChildById('milestoneLabel')
            if milestoneLabel then milestoneLabel:setText('') end
          end
        end
      end
    end
  end

  -- Reward display above progress bar
  if rewardDisplayRow then
    rewardDisplayRow:destroyChildren()
  end

  if rewards then
    local colPositions = {
      {x = 0, width = 125},
      {x = 127, width = 124},
      {x = 253, width = 127}
    }

    for i, reward in ipairs(rewards) do
      if i > 3 then break end
      local col = colPositions[i]

      -- Build reward item list
      local slotData = {}
      if reward.experience and reward.experience > 0 then
        table.insert(slotData, {type = 'exp', value = reward.experience})
      end
      if reward.pokelogPoints and reward.pokelogPoints > 0 then
        table.insert(slotData, {type = 'points', value = reward.pokelogPoints})
      end
      if reward.items then
        for _, item in ipairs(reward.items) do
          table.insert(slotData, {type = 'item', id = item.id, count = item.count})
        end
      end

      if rewardDisplayRow and #slotData > 0 then
        -- Create stage container
        local container = g_ui.createWidget('UIWidget', rewardDisplayRow)
        container:addAnchor(AnchorTop, 'parent', AnchorTop)
        container:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        container:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        container:setMarginLeft(col.x)
        container:setWidth(col.width)

        -- Claim state
        local totalCompleted = data.rewardStage + data.lastUnclaimedRewardStage
        local isCompleted = i <= totalCompleted
        local isClaimed = i <= data.rewardStage
        local isClaimable = isCompleted and not isClaimed

        -- Create reward slots centered in container
        local slotSize = 40
        local spacing = 2
        local totalWidth = #slotData * slotSize + (#slotData - 1) * spacing
        local startX = math.floor((col.width - totalWidth) / 2)

        for j, sdata in ipairs(slotData) do
          local slot = g_ui.createWidget('PokelogRewardSlot', container)
          slot:setPhantom(true)
          slot:addAnchor(AnchorTop, 'parent', AnchorTop)
          slot:setMarginTop(0)
          slot:addAnchor(AnchorLeft, 'parent', AnchorLeft)
          slot:setMarginLeft(startX + (j - 1) * (slotSize + spacing))

          if sdata.type == 'exp' then
            local iconImage = slot:getChildById('iconImage')
            if iconImage then
              iconImage:setImageSource('/images/playerBuffs/experience')
              iconImage:setVisible(true)
            end
            local countLabel = slot:getChildById('countLabel')
            if countLabel then
              countLabel:setText(formatNumber(sdata.value))
            end
          elseif sdata.type == 'points' then
            local iconImage = slot:getChildById('iconImage')
            if iconImage then
              iconImage:setImageSource('/images/modules/pokelog_points')
              iconImage:setVisible(true)
            end
            local countLabel = slot:getChildById('countLabel')
            if countLabel then
              countLabel:setText(formatNumber(sdata.value))
            end
          elseif sdata.type == 'item' then
            local itemDisplay = slot:getChildById('itemDisplay')
            if itemDisplay then
              itemDisplay:setItemId(sdata.id)
              itemDisplay:setItemCount(sdata.count)
            end
          end
        end

        -- Visual state + claimable label
        if not isClaimable then
          container:setOpacity(isClaimed and 0.5 or 0.4)
        else
          container:setCursor('pointer')
          container.onClick = function()
            sendClaimRewards(pokemonName)
          end

          local claimLabel = g_ui.createWidget('PoppinsSemibold11', container)
          claimLabel:setPhantom(true)
          claimLabel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
          claimLabel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
          claimLabel:addAnchor(AnchorRight, 'parent', AnchorRight)
          claimLabel:setMarginBottom(-4)
          claimLabel:setTextAlign(AlignCenter)
          claimLabel:setColor('#ffd700')
          claimLabel:setText(tr('Available Rewards'))
          claimLabel:setTextOffset({x = 0, y = 4})
        end

        -- Make the segment itself clickable when claimable
        local seg = detailProgressBg and detailProgressBg:getChildById('seg' .. i)
        if seg then
          if isClaimable then
            seg:setCursor('pointer')
            seg.onClick = function()
              sendClaimRewards(pokemonName)
            end
          else
            seg:setCursor('')
            seg.onClick = nil
          end
        end

        -- Build tooltip
        local tooltip = g_ui.createWidget('PokelogRewardTooltip', rootWidget)
        local tooltipTitle = tooltip:getChildById('tooltipTitle')
        if tooltipTitle then
          tooltipTitle:setText(tr('Rewards'))
        end

        local rewardsPanel = tooltip:getChildById('rewards')
        local totalSlots = 0

        if reward.experience and reward.experience > 0 then
          local tSlot = g_ui.createWidget('PokelogRewardSlot', rewardsPanel)
          local iconImage = tSlot:getChildById('iconImage')
          if iconImage then
            iconImage:setImageSource('/images/playerBuffs/experience')
            iconImage:setVisible(true)
          end
          local countLabel = tSlot:getChildById('countLabel')
          if countLabel then
            countLabel:setText(formatNumber(reward.experience))
          end
          totalSlots = totalSlots + 1
        end

        if reward.pokelogPoints and reward.pokelogPoints > 0 then
          local tSlot = g_ui.createWidget('PokelogRewardSlot', rewardsPanel)
          local iconImage = tSlot:getChildById('iconImage')
          if iconImage then
            iconImage:setImageSource('/images/modules/pokelog_points')
            iconImage:setVisible(true)
          end
          local countLabel = tSlot:getChildById('countLabel')
          if countLabel then
            countLabel:setText(formatNumber(reward.pokelogPoints))
          end
          totalSlots = totalSlots + 1
        end

        if reward.items then
          for _, item in ipairs(reward.items) do
            local tSlot = g_ui.createWidget('PokelogRewardSlot', rewardsPanel)
            local itemDisplay = tSlot:getChildById('itemDisplay')
            if itemDisplay then
              itemDisplay:setItemId(item.id)
              itemDisplay:setItemCount(item.count)
            end
            totalSlots = totalSlots + 1
          end
        end

        if totalSlots > 4 then
          local rows = math.ceil(totalSlots / 4)
          local newHeight = (34 * rows) + (2 * (rows - 1))
          rewardsPanel:setHeight(newHeight)
        end

        --container:setTooltip(tooltip)
      end
    end
  end
end
