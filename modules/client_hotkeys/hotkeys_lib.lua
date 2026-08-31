KeyConfig = {}
KeyConfig.__index = KeyConfig

function KeyConfig:new(name, key, config)
  local keyConfig = setmetatable({}, KeyConfig)
  keyConfig.name = name or ""
  keyConfig.key = key or ""
  keyConfig.config = config
  return keyConfig
end

Action = {}
Action.__index = Action

function Action:new(description, lockKeyType, editableKeyType)
  local action = setmetatable({}, Action)
  action.description = description
  action.lockKeyType = lockKeyType or false
  action.editableKeyType = editableKeyType or false
  action.keys = {
    chatDisabled = {
      primaryKey = KeyConfig:new("primaryKey", "", KeyType.KeyPress),
      secondaryKey = KeyConfig:new("secondaryKey", "", KeyType.KeyPress),
      tertiaryKey = KeyConfig:new("tertiaryKey", "", KeyType.KeyPress)
    },
    chatEnabled = {
      primaryKey = KeyConfig:new("primaryKey", "", KeyType.KeyPress),
      secondaryKey = KeyConfig:new("secondaryKey", "", KeyType.KeyPress),
      tertiaryKey = KeyConfig:new("tertiaryKey", "", KeyType.KeyPress)
    }
  }
  return action
end

function Action:setKeys(chatType, primary, secondary, tertiary, config)
  self.keys[chatType].primaryKey = primary or self.keys[chatType].primaryKey
  self.keys[chatType].secondaryKey = secondary or self.keys[chatType].secondaryKey
  self.keys[chatType].tertiaryKey = tertiary or self.keys[chatType].tertiaryKey
  self.keys[chatType].config = config or nil
end

function Action:getKeys(hotkeysList)
  return self.keys[hotkeysList]
end

ActionProfile = {}
ActionProfile.__index = ActionProfile

function ActionProfile:new(profileName)
  local profile = setmetatable({}, ActionProfile)
  profile.name = profileName
  profile.actions = {}
  return profile
end

function ActionProfile:addAction(actionName, action)
  self.actions[actionName] = action
end

function ActionProfile:getAction(actionName)
  return self.actions[actionName]
end

HotkeyProfiles = {}
HotkeyProfiles.__index = HotkeyProfiles

function HotkeyProfiles:new(name)
  local profiles = setmetatable({}, HotkeyProfiles)
  profiles.name = name or "defaultProfile"
  profiles.actionProfiles = {}
  return profiles
end

function HotkeyProfiles:addActionProfile(profileName)
  local actionProfile = ActionProfile:new(profileName)
  self.actionProfiles[profileName] = actionProfile
  return actionProfile
end

function HotkeyProfiles:getActionProfile(profileName)
  return self.actionProfiles[profileName]
end

-- =============================================================================
-- HotkeyRegistry: Centralized hotkey binding system
-- Modules register handlers; the registry manages all g_keyboard/g_mouse binding,
-- unbinding, conflict resolution, and boundKeys storage.
-- =============================================================================

HotkeyRegistry = {
  boundKeys = {},     -- [profileName][actionName][chatState][keyType] = { keyInfo, callbacks... }
}

function HotkeyRegistry:getHandler(profileName, actionName)
  local factory = DefaultActions and DefaultActions[actionName]
  if not factory then return nil end

  local handler = {
    bindMode = (DefaultBindModes and DefaultBindModes[actionName]) or "standard",
    onBind = factory,
  }
  local assign = DefaultAssignCallbacks and DefaultAssignCallbacks[actionName]
  if assign then
    handler.onPostBind = function(an, action, keyInfo, chatState, keyType)
      return assign(an, action, keyInfo, chatState, keyType, "bind")
    end
    handler.onPostUnbind = function(an, action)
      return assign(an, action, nil, nil, nil, "unbind")
    end
  end
  return handler
end

-- Bind a single action (replaces bindActionForProfile)
function HotkeyRegistry:bindAction(actionProfile, actionName, action)
  local handler = self:getHandler(actionProfile.name, actionName)
  if not handler then return end

  local actionKeys = action.keys
  for chatState, keys in pairs(actionKeys) do
    for _, keyType in ipairs({"primaryKey", "secondaryKey", "tertiaryKey"}) do
      local keyInfo = keys[keyType]
      if not keyInfo or keyInfo.key == "" then
        goto continue
      end

      -- Per-(chatState,keyType) duplicate guard: lets multiple modules call bindAction
      -- on the same profile (shared profile pattern) without double-binding individual keys,
      -- while still allowing partial rebinds (e.g. after assignHotkey clears one slot).
      local profileBound = self.boundKeys[actionProfile.name]
      local actionBound = profileBound and profileBound[actionName]
      local chatBound = actionBound and actionBound[chatState]
      if chatBound and chatBound[keyType] then
        goto continue
      end

      local bindResult = handler.onBind(actionName, action, keyInfo, chatState, keyType)
      if not bindResult then goto continue end

      local widget = bindResult.widget
      local bindMode = handler.bindMode or "standard"

      if bindMode == "walk" or bindMode == "triple" then
        -- Triple bind: KeyDown + KeyUp + KeyPress (used by walking/turning)
        if bindResult.callbackDown then
          g_keyboard.bindKeyDown(keyInfo.key, bindResult.callbackDown, widget, bindResult.passthrough or false)
        end
        if bindResult.callbackUp then
          g_keyboard.bindKeyUp(keyInfo.key, bindResult.callbackUp, widget, bindResult.passthrough or false)
        end
        if bindResult.callbackPress then
          g_keyboard.bindKeyPress(keyInfo.key, bindResult.callbackPress, widget)
        end

        self:_store(actionProfile.name, actionName, chatState, keyType, {
          keyInfo = keyInfo,
          action = action,
          callbackKeyDown = bindResult.callbackDown,
          callbackKeyUp = bindResult.callbackUp,
          callbackKeyPress = bindResult.callbackPress,
          widget = widget,
          bindMode = "triple"
        })

      else
        -- Standard bind: single callback based on keyInfo.config
        if not bindResult.callback then goto continue end
        -- othersProfile e KeyDown FIXO por design (2026-08-28): o tipo "client-defined per
        -- category" era por SLOT, e todo slot fora do chatDisabled.primaryKey herda o default
        -- KeyPress do Action:new -- ex.: Next Chat atribuido a um slot secundario/chatEnabled
        -- repetia com a tecla segurada. Normaliza no ponto unico da decisao de bind (cobre
        -- defaults de slot, load de config salvo e addAction futuro) e, como muta o proprio
        -- KeyConfig da action, o proximo save persiste KeyDown (auto-cura de configs velhos).
        -- A UI ja esconde o seletor de tipo para este profile (canEditKeyType).
        if actionProfile.name == "othersProfile" then
          keyInfo.config = KeyType.KeyDown
        end
        if keyInfo.config == KeyType.KeyPress then
          g_keyboard.bindKeyPress(keyInfo.key, bindResult.callback, widget)
        elseif keyInfo.config == KeyType.KeyUp then
          g_keyboard.bindKeyUp(keyInfo.key, bindResult.callback, widget)
        else
          g_keyboard.bindKeyDown(keyInfo.key, bindResult.callback, widget)
        end

        self:_store(actionProfile.name, actionName, chatState, keyType, {
          keyInfo = keyInfo,
          action = action,
          callbackPress = bindResult.callback,
          widget = widget,
          bindMode = "standard"
        })
      end

      if handler.onPostBind then
        handler.onPostBind(actionName, action, keyInfo, chatState, keyType)
      end

      ::continue::
    end
  end
end

-- Unbind a single action (replaces unbindActionForProfile)
function HotkeyRegistry:unbindAction(actionProfile, actionName, action)
  local handler = self:getHandler(actionProfile.name, actionName)
  if not handler then return end

  local profileBound = self.boundKeys[actionProfile.name]
  if not profileBound or not profileBound[actionName] then return end

  for chatState, keyTypes in pairs(profileBound[actionName]) do
    for keyType, boundData in pairs(keyTypes) do
      self:_unbindSingle(boundData)
    end
  end

  profileBound[actionName] = nil

  if handler.onPostUnbind then
    handler.onPostUnbind(actionName, action)
  end
end

-- Check if a key combo is already bound somewhere (returns info or false)
function HotkeyRegistry:isKeyAlreadyBound(keyCombo, chatState)
  for profileName, actions in pairs(self.boundKeys) do
    for actionName, chatStates in pairs(actions) do
      local csData = chatStates[chatState]
      if csData then
        for keyType, boundData in pairs(csData) do
          if tostring(boundData.keyInfo.key) == keyCombo then
            return {
              profileName = profileName,
              actionName = actionName,
              keyType = keyType,
              boundData = boundData
            }
          end
        end
      end
    end
  end
  return false
end

-- Get the bound keys table for a specific profile (for UI updates like updateUI)
function HotkeyRegistry:getBoundKeys(profileName)
  return self.boundKeys[profileName] or {}
end

-- Internal: store bound key data
function HotkeyRegistry:_store(profileName, actionName, chatState, keyType, data)
  self.boundKeys[profileName] = self.boundKeys[profileName] or {}
  self.boundKeys[profileName][actionName] = self.boundKeys[profileName][actionName] or {}
  self.boundKeys[profileName][actionName][chatState] = self.boundKeys[profileName][actionName][chatState] or {}
  self.boundKeys[profileName][actionName][chatState][keyType] = data
end

-- Internal: unbind a single key entry
function HotkeyRegistry:_unbindSingle(boundData)
  local keyInfo = boundData.keyInfo
  local widget = boundData.widget

  if boundData.bindMode == "triple" then
    if boundData.callbackKeyDown then
      g_keyboard.unbindKeyDown(keyInfo.key, boundData.callbackKeyDown, widget)
    end
    if boundData.callbackKeyUp then
      g_keyboard.unbindKeyUp(keyInfo.key, boundData.callbackKeyUp, widget)
    end
    if boundData.callbackKeyPress then
      g_keyboard.unbindKeyPress(keyInfo.key, boundData.callbackKeyPress, widget)
    end
  else
    if not boundData.callbackPress then return end
    -- Mirror the bind path: standard mode dispatches by keyInfo.config, so
    -- the unbind must too (else KeyPress/KeyUp bindings leak after switch).
    if keyInfo.config == KeyType.KeyPress then
      g_keyboard.unbindKeyPress(keyInfo.key, boundData.callbackPress, widget)
    elseif keyInfo.config == KeyType.KeyUp then
      g_keyboard.unbindKeyUp(keyInfo.key, boundData.callbackPress, widget)
    else
      g_keyboard.unbindKeyDown(keyInfo.key, boundData.callbackPress, widget)
    end
  end
end

-- Internal: remove stored entry and clean up empty tables
function HotkeyRegistry:_removeStored(profileName, actionName, chatState, keyType)
  local profileBound = self.boundKeys[profileName]
  if not profileBound or not profileBound[actionName] then return end

  local csData = profileBound[actionName][chatState]
  if csData then
    csData[keyType] = nil
    if not next(csData) then
      profileBound[actionName][chatState] = nil
    end
  end

  if not next(profileBound[actionName]) then
    profileBound[actionName] = nil
  end
end

-- Unbind all actions across all profiles
function HotkeyRegistry:unbindAll()
  for profileName, actions in pairs(self.boundKeys) do
    for actionName, chatStates in pairs(actions) do
      local actionObj
      for chatState, keyTypes in pairs(chatStates) do
        for keyType, boundData in pairs(keyTypes) do
          self:_unbindSingle(boundData)
          actionObj = actionObj or boundData.action
        end
      end
      -- Symmetric with unbindAction: must fire onPostUnbind so handlers can
      -- clear UI state (action-bar labels, tooltips, move-bar UI, etc.).
      -- Without this, profile switches leave stale labels for slots whose
      -- new keys are empty (onBind only updates labels for non-empty keys).
      local handler = self:getHandler(profileName, actionName)
      if handler and handler.onPostUnbind then
        handler.onPostUnbind(actionName, actionObj)
      end
    end
  end
  self.boundKeys = {}
end

-- Bind all actions for a given HotkeyProfiles object
function HotkeyRegistry:bindAll(hotkeyProfile)
  for profileName, actionProfile in pairs(hotkeyProfile.actionProfiles) do
    for actionName, action in pairs(actionProfile.actions) do
      self:bindAction(actionProfile, actionName, action)
    end
  end
end

local ORDER_DEFAULT_MOUSE_KEY = 'MouseMid'

function initProfile(hotkeyProfile)
  migrateHotkeysConfig()

  local movementProfile = hotkeyProfile:addActionProfile("movementProfile")

  local walkNorth = Action:new("Walk North")
  walkNorth:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Up"), KeyConfig:new("secondaryKey", "W"), KeyConfig:new("tertiaryKey", "Numpad8"))
  walkNorth:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Up"))
  movementProfile:addAction("WALK_NORTH", walkNorth)

  local walkWest = Action:new("Walk West")
  walkWest:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Left"), KeyConfig:new("secondaryKey", "A"), KeyConfig:new("tertiaryKey", "Numpad4"))
  walkWest:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Left"))
  movementProfile:addAction("WALK_WEST", walkWest)

  local walkSouth = Action:new("Walk South")
  walkSouth:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Down"), KeyConfig:new("secondaryKey", "S"), KeyConfig:new("tertiaryKey", "Numpad2"))
  walkSouth:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Down"))
  movementProfile:addAction("WALK_SOUTH", walkSouth)

  local walkEast = Action:new("Walk East")
  walkEast:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Right"), KeyConfig:new("secondaryKey", "D"), KeyConfig:new("tertiaryKey", "Numpad6"))
  walkEast:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Right"))
  movementProfile:addAction("WALK_EAST", walkEast)

  local walkNorthEast = Action:new("Walk North-East")
  walkNorthEast:setKeys("chatDisabled", nil, nil, KeyConfig:new("tertiaryKey", "Numpad9"))
  walkNorthEast:setKeys("chatEnabled", nil, nil, KeyConfig:new("tertiaryKey", "Numpad9"))
  movementProfile:addAction("WALK_NORTH_EAST", walkNorthEast)

  local walkSouthEast = Action:new("Walk South-East")
  walkSouthEast:setKeys("chatDisabled", nil, nil, KeyConfig:new("tertiaryKey", "Numpad3"))
  walkSouthEast:setKeys("chatEnabled", nil, nil, KeyConfig:new("tertiaryKey", "Numpad3"))
  movementProfile:addAction("WALK_SOUTH_EAST", walkSouthEast)

  local walkSouthWest = Action:new("Walk South-West")
  walkSouthWest:setKeys("chatDisabled", nil, nil, KeyConfig:new("tertiaryKey", "Numpad1"))
  walkSouthWest:setKeys("chatEnabled", nil, nil, KeyConfig:new("tertiaryKey", "Numpad1"))
  movementProfile:addAction("WALK_SOUTH_WEST", walkSouthWest)

  local walkNorthWest = Action:new("Walk North-West")
  walkNorthWest:setKeys("chatDisabled", nil, nil, KeyConfig:new("tertiaryKey", "Numpad7"))
  walkNorthWest:setKeys("chatEnabled", nil, nil, KeyConfig:new("tertiaryKey", "Numpad7"))
  movementProfile:addAction("WALK_NORTH_WEST", walkNorthWest)

  local turnNorth = Action:new("Turn North")
  turnNorth:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Up"), KeyConfig:new("secondaryKey", "Ctrl+W"))
  movementProfile:addAction("TURN_NORTH", turnNorth)

  local turnWest = Action:new("Turn West")
  turnWest:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Left"), KeyConfig:new("secondaryKey", "Ctrl+A"))
  movementProfile:addAction("TURN_WEST", turnWest)

  local turnSouth = Action:new("Turn South")
  turnSouth:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Down"), KeyConfig:new("secondaryKey", "Ctrl+S"))
  movementProfile:addAction("TURN_SOUTH", turnSouth)

  local turnEast = Action:new("Turn East")
  turnEast:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Right"), KeyConfig:new("secondaryKey", "Ctrl+D"))
  movementProfile:addAction("TURN_EAST", turnEast)

  local turnPokemonNorth = Action:new("Turn Pokémon North")
  turnPokemonNorth:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Numpad8"))
  movementProfile:addAction("TURN_POKEMON_NORTH", turnPokemonNorth)

  local turnPokemonEast = Action:new("Turn Pokémon East")
  turnPokemonEast:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Numpad6"))
  movementProfile:addAction("TURN_POKEMON_EAST", turnPokemonEast)

  local turnPokemonWest = Action:new("Turn Pokémon West")
  turnPokemonWest:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Numpad4"))
  movementProfile:addAction("TURN_POKEMON_WEST", turnPokemonWest)

  local turnPokemonSouth = Action:new("Turn Pokémon South")
  turnPokemonSouth:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Numpad2"))
  movementProfile:addAction("TURN_POKEMON_SOUTH", turnPokemonSouth)

  local flyUp = Action:new("Fly Up", false, true)
  flyUp:setKeys("chatDisabled", KeyConfig:new("primaryKey", "PageUp", KeyType.KeyPress))
  movementProfile:addAction("FLY_UP", flyUp)

  local flyDown = Action:new("Fly Down", false, true)
  flyDown:setKeys("chatDisabled", KeyConfig:new("primaryKey", "PageDown", KeyType.KeyPress))
  movementProfile:addAction("FLY_DOWN", flyDown)

  local pokemonProfile = hotkeyProfile:addActionProfile("pokemonProfile")
  for i = 1, 12 do
    local actionName = "ACTION_" .. i
    local pokemonAction = Action:new("Pokemon Action " .. i)
    pokemonAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "F" .. i, KeyType.KeyPress))
    pokemonAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "F" .. i, KeyType.KeyPress))
    pokemonProfile:addAction(actionName, pokemonAction)
  end

  local pokemonOffensiveAction = Action:new("Offensive Fight Mode")
  pokemonOffensiveAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", nil, KeyType.KeyPress))
  pokemonOffensiveAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", nil, KeyType.KeyPress))
  pokemonProfile:addAction("OFFENSIVE_MODE", pokemonOffensiveAction)

  local pokemonBalancedAction = Action:new("Balanced Fight Mode")
  pokemonBalancedAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", nil, KeyType.KeyPress))
  pokemonBalancedAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", nil, KeyType.KeyPress))
  pokemonProfile:addAction("BALANCED_MODE", pokemonBalancedAction)

  local pokemonDefensiveAction = Action:new("Defensive Fight Mode")
  pokemonDefensiveAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", nil, KeyType.KeyPress))
  pokemonDefensiveAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", nil, KeyType.KeyPress))
  pokemonProfile:addAction("DEFENSIVE_MODE", pokemonDefensiveAction)

  local pokebarProfile = hotkeyProfile:addActionProfile("pokebarProfile")
  for i = 1, 6 do
    local actionName = "POKEBAR_" .. i
    local pokemonAction = Action:new("Pokébar Pokémon " .. i)
    pokemonAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", nil, KeyType.KeyDown))
    pokemonAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", nil, KeyType.KeyDown))
    pokebarProfile:addAction(actionName, pokemonAction)
  end

  local pokebarCycleAction = Action:new("Pokébar Cycle Pokémon")
  pokebarCycleAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", nil, KeyType.KeyDown))
  pokebarCycleAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", nil, KeyType.KeyDown))
  pokebarProfile:addAction("POKEBAR_CYCLE", pokebarCycleAction)

  local actionProfile = hotkeyProfile:addActionProfile("actionProfile")

  local order = Action:new("Action Bar Order")
  order:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Q", KeyType.KeyPress), KeyConfig:new("secondaryKey", ORDER_DEFAULT_MOUSE_KEY, KeyType.KeyPress))
  order:setKeys("chatEnabled", nil, KeyConfig:new("secondaryKey", ORDER_DEFAULT_MOUSE_KEY, KeyType.KeyPress))
  actionProfile:addAction("ACTION_BAR_ORDER", order)

  local orderSelf = Action:new("Order on Yourself", true)
  orderSelf:setKeys("chatDisabled", KeyConfig:new("primaryKey", "", KeyType.KeyPress))
  actionProfile:addAction("ACTION_BAR_ORDER_SELF", orderSelf)

  local pokedex = Action:new("Action Bar Pokedex")
  pokedex:setKeys("chatDisabled", KeyConfig:new("primaryKey", "E", KeyType.KeyPress))
  actionProfile:addAction("ACTION_BAR_DEX", pokedex)

  local autoCombo = Action:new("Action Bar AutoCombo")
  autoCombo:setKeys("chatDisabled", KeyConfig:new("primaryKey", "", KeyType.KeyPress))
  actionProfile:addAction("ACTION_BAR_AUTOCOMBO", autoCombo)

  for i = 1, 50 do
    local actionBar = Action:new("Action Bar " .. i)
    actionProfile:addAction("ACTION_BAR_" .. i, actionBar)
  end

  local othersProfile = hotkeyProfile:addActionProfile("othersProfile")

  local switchTarget = Action:new("Switch Target")
  switchTarget:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Tab", KeyType.KeyDown))
  othersProfile:addAction("SWITCH_TARGET", switchTarget)

  local switchTargetBackward = Action:new("Switch Target Backward")
  switchTargetBackward:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Shift+Tab", KeyType.KeyDown))
  othersProfile:addAction("SWITCH_TARGET_BACKWARD", switchTargetBackward)

  local tabChat = Action:new("Next Chat Channel", true)
  tabChat:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Tab", KeyType.KeyDown))
  othersProfile:addAction("NEXT_CHAT", tabChat)

  local closeChat = Action:new("Close Chat Channel", true)
  closeChat:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+E", KeyType.KeyDown))
  closeChat:setKeys("chatEnabled",  KeyConfig:new("primaryKey", "Ctrl+E", KeyType.KeyDown))
  othersProfile:addAction("CLOSE_CHAT", closeChat)

  local autoLoot = Action:new("Auto Loot", true)
  autoLoot:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Space", KeyType.KeyDown))
  autoLoot:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Space", KeyType.KeyDown))
  othersProfile:addAction("AUTO_LOOT", autoLoot)

  local topMenuProfile = hotkeyProfile:addActionProfile("topMenuProfile")

  local logoutAction = Action:new("Logout", true)
  logoutAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Q", KeyType.KeyDown))
  logoutAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Ctrl+Q", KeyType.KeyDown))
  topMenuProfile:addAction("LOGOUT", logoutAction)

  local settingsAction = Action:new("Settings", true)
  settingsAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+U", KeyType.KeyDown))
  settingsAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Ctrl+U", KeyType.KeyDown))
  topMenuProfile:addAction("SETTINGS", settingsAction)

  local pokebagAction = Action:new("Poke Bag", true)
  pokebagAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+P", KeyType.KeyDown))
  pokebagAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Ctrl+P", KeyType.KeyDown))
  topMenuProfile:addAction("POKEBAG", pokebagAction)

  local playerbagAction = Action:new("Player Bag", true)
  playerbagAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+I", KeyType.KeyDown))
  playerbagAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Ctrl+I", KeyType.KeyDown))
  topMenuProfile:addAction("PLAYERBAG", playerbagAction)

  local minimapAction = Action:new("Mini Map", true)
  minimapAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+M", KeyType.KeyDown))
  minimapAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Ctrl+M", KeyType.KeyDown))
  topMenuProfile:addAction("MINIMAP", minimapAction)

  local fullMapAction = Action:new("Full Map", true)
  fullMapAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Tab", KeyType.KeyDown))
  fullMapAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Ctrl+Tab", KeyType.KeyDown))
  topMenuProfile:addAction("FULLMAP", fullMapAction)

  local vipAction = Action:new("Friends List", true)
  vipAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+F", KeyType.KeyDown))
  vipAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Ctrl+F", KeyType.KeyDown))
  topMenuProfile:addAction("VIPLIST", vipAction)

  local battleAction = Action:new("Battle List", true)
  battleAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+B", KeyType.KeyDown))
  battleAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Ctrl+B", KeyType.KeyDown))
  topMenuProfile:addAction("BATTLELIST", battleAction)

  local playerActionsProfile = hotkeyProfile:addActionProfile("playerActionsProfile")

  local fishingRod = Action:new("Fishing Rod", true)
  fishingRod:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+Z", KeyType.KeyDown))
  fishingRod:setKeys("chatEnabled", KeyConfig:new("primaryKey", "Ctrl+Z", KeyType.KeyDown))
  playerActionsProfile:addAction("FISHING_ROD", fishingRod)

  local walkAction = Action:new("Walk", true)
  walkAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Shift+Home", KeyType.KeyDown))
  walkAction:setKeys("chatEnabled",  KeyConfig:new("primaryKey", "Shift+Home", KeyType.KeyDown))
  playerActionsProfile:addAction("WALK", walkAction)

  local pokestopAction = Action:new("Pokestop", true)
  pokestopAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "P", KeyType.KeyDown))
  pokestopAction:setKeys("chatEnabled",  KeyConfig:new("primaryKey", "Shift+P", KeyType.KeyDown))
  playerActionsProfile:addAction("POKESTOP", pokestopAction)

  -- Collect from a resource node (vein). chatEnabled slot deixado VAZIO de propósito: é o guard contra
  -- disparar a coleta enquanto o jogador digita no chat. KeyDown (não KeyPress) para não auto-repetir.
  local gatherAction = Action:new("Collect from Resource Node", true)
  gatherAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "F", KeyType.KeyDown))
  playerActionsProfile:addAction("GATHER", gatherAction)

  for i = 1, 6 do
    local memoryAction = Action:new("Ditto Memory " .. i, true)
    memoryAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "", KeyType.KeyDown))
    memoryAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "", KeyType.KeyDown))
    playerActionsProfile:addAction("MEMORY_" .. i, memoryAction)
  end

  local outfitAnimationAction = Action:new("Start Outfit Animation", true)
  outfitAnimationAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "", KeyType.KeyDown))
  outfitAnimationAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "", KeyType.KeyDown))
  playerActionsProfile:addAction("OUTFIT_ANIMATION", outfitAnimationAction)

  local outfitTauntAction = Action:new("Start Outfit Taunt", true)
  outfitTauntAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "", KeyType.KeyDown))
  outfitTauntAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "", KeyType.KeyDown))
  playerActionsProfile:addAction("OUTFIT_TAUNT", outfitTauntAction)

  local outfitIdleAction = Action:new("Start Outfit Idle", true)
  outfitIdleAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "", KeyType.KeyDown))
  outfitIdleAction:setKeys("chatEnabled", KeyConfig:new("primaryKey", "", KeyType.KeyDown))
  playerActionsProfile:addAction("OUTFIT_IDLE", outfitIdleAction)

  local generalWindowsProfile = hotkeyProfile:addActionProfile("generalWindowsProfile")

  local achievementsAction = Action:new("Achievements", true)
  generalWindowsProfile:addAction("ACHIEVEMENTS", achievementsAction)

  local brokesAction = Action:new("Brokes", true)
  generalWindowsProfile:addAction("BROKES", brokesAction)

  local talentsAction = Action:new("Talents", true)
  generalWindowsProfile:addAction("TALENTS", talentsAction)

  local medalsAction = Action:new("Medals", true)
  generalWindowsProfile:addAction("MEDALS", medalsAction)

  local pokelogAction = Action:new("Pok\233log", true)
  generalWindowsProfile:addAction("POKELOG", pokelogAction)

  local gameShopAction = Action:new("Game Shop", true)
  generalWindowsProfile:addAction("GAME_SHOP", gameShopAction)

  local linkedTasksAction = Action:new("Linked Tasks", true)
  linkedTasksAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+L", KeyType.KeyDown))
  linkedTasksAction:setKeys("chatEnabled",  KeyConfig:new("primaryKey", "Ctrl+L", KeyType.KeyDown))
  generalWindowsProfile:addAction("LINKED_TASKS", linkedTasksAction)

  local guildAction = Action:new("Guild", true)
  guildAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+J", KeyType.KeyDown))
  guildAction:setKeys("chatEnabled",  KeyConfig:new("primaryKey", "Ctrl+J", KeyType.KeyDown))
  generalWindowsProfile:addAction("GUILD", guildAction)

  local trainerAction = Action:new("Trainer", true)
  trainerAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+T", KeyType.KeyDown))
  trainerAction:setKeys("chatEnabled",  KeyConfig:new("primaryKey", "Ctrl+T", KeyType.KeyDown))
  generalWindowsProfile:addAction("TRAINER", trainerAction)

  local reportRuleAction = Action:new("Report Rule Violation", true)
  reportRuleAction:setKeys("chatDisabled", KeyConfig:new("primaryKey", "Ctrl+R", KeyType.KeyDown))
  reportRuleAction:setKeys("chatEnabled",  KeyConfig:new("primaryKey", "Ctrl+R", KeyType.KeyDown))
  generalWindowsProfile:addAction("REPORT_RULE_VIOLATION", reportRuleAction)

  local savedConfig = getHotkeysConfig(hotkeyProfile.name)
  if savedConfig then
    for profileName, profileData in pairs(savedConfig) do
      local profile = hotkeyProfile:getActionProfile(profileName)
      if profile then
        for actionName, actionData in pairs(profileData) do
          local action = profile:getAction(actionName)
          if action and actionData.keys then

            -- Restore only the saved key COMBO; the bind TYPE is client-defined
            -- per category (code), never taken from the saved OTML — so changing
            -- a default in code applies to everyone regardless of stale configs.
            for chatState, keys in pairs(actionData.keys) do
              local codeKeys = action.keys[chatState]
              if codeKeys then
                local primaryKey = keys.primaryKey and KeyConfig:new("primaryKey", keys.primaryKey.key, codeKeys.primaryKey.config) or nil
                local secondaryKey = keys.secondaryKey and KeyConfig:new("secondaryKey", keys.secondaryKey.key, codeKeys.secondaryKey.config) or nil
                local tertiaryKey = keys.tertiaryKey and KeyConfig:new("tertiaryKey", keys.tertiaryKey.key, codeKeys.tertiaryKey.config) or nil
                action:setKeys(chatState, primaryKey, secondaryKey, tertiaryKey)
              end
            end
          end
        end
      end
    end
  end

end


HOTKEYS_CONFIG_VERSION = 3

local KEY_SLOT_NAMES = {"primaryKey", "secondaryKey", "tertiaryKey"}

local MOUSE_COMBO_RENAMES = {
  ['MMB'] = 'MouseMid',
}

local function migrateComboString(combo)
  if type(combo) ~= 'string' or combo == '' then
    return combo, false
  end
  local changed = false
  local parts = combo:split('+')
  for i, token in ipairs(parts) do
    local renamed = MOUSE_COMBO_RENAMES[token]
    if renamed then
      parts[i] = renamed
      changed = true
    end
  end
  if not changed then
    return combo, false
  end
  return table.concat(parts, '+'), true
end

-- Per-chatState, matching isKeyAlreadyBound: the same key may serve two actions
-- as long as they live in different chat states.
local function isComboUsedInProfile(profiles, combo, chatState)
  for _, actions in pairs(profiles) do
    for _, actionData in pairs(actions) do
      local keys = actionData.keys and actionData.keys[chatState]
      if keys then
        for _, slotName in ipairs(KEY_SLOT_NAMES) do
          local kc = keys[slotName]
          if kc and kc.key == combo then
            return true
          end
        end
      end
    end
  end
  return false
end

-- Code-side defaults never reach players who already have a saved config: the
-- restore path overwrites every key slot with what was saved. So a new default
-- key has to be backfilled here. A chat state missing from the saved config
-- keeps the code default, so it is skipped.
local function backfillOrderMouseKey(profiles)
  local order = profiles.actionProfile and profiles.actionProfile.ACTION_BAR_ORDER
  if not order or not order.keys then
    return false
  end

  local changed = false
  for _, chatState in ipairs({"chatDisabled", "chatEnabled"}) do
    local keys = order.keys[chatState]
    local slot = keys and keys.secondaryKey
    local isEmpty = not slot or not slot.key or slot.key == ''
    if keys and isEmpty and not isComboUsedInProfile(profiles, ORDER_DEFAULT_MOUSE_KEY, chatState) then
      keys.secondaryKey = {name = 'secondaryKey', key = ORDER_DEFAULT_MOUSE_KEY}
      changed = true
    end
  end

  return changed
end

function migrateHotkeysConfig()
  local version = tonumber(g_settings.getNumber('hotkeysConfigVersion')) or 0
  if version >= HOTKEYS_CONFIG_VERSION then
    return
  end

  -- Only the saved key COMBO is migrated here. The bind TYPE is no longer read
  -- from the saved config at all (it is client-defined per category on load), so
  -- there is nothing to migrate for it.
  local config = g_settings.getNode('hotkeysConfigSettings')
  if config then
    local changedAny = false
    for _, profiles in pairs(config) do
      for _, actions in pairs(profiles) do
        for _, actionData in pairs(actions) do
          if actionData.keys then
            for _, keys in pairs(actionData.keys) do
              for _, slotName in ipairs(KEY_SLOT_NAMES) do
                local kc = keys[slotName]
                if kc and kc.key then
                  local newKey, changed = migrateComboString(kc.key)
                  if changed then
                    kc.key = newKey
                    changedAny = true
                  end
                end
              end
            end
          end
        end
      end

      if backfillOrderMouseKey(profiles) then
        changedAny = true
      end
    end
    if changedAny then
      g_settings.setNode('hotkeysConfigSettings', config)
    end
  end

  g_settings.set('hotkeysConfigVersion', HOTKEYS_CONFIG_VERSION)
end

function getHotkeysConfig(profileName)
  local config = g_settings.getNode('hotkeysConfigSettings')

  if config and config[profileName] then
    return config[profileName]
  end

  return nil
end

function saveHotkeysConfig(hotkeyProfile)
  local config = g_settings.getNode('hotkeysConfigSettings') or {}

  config[hotkeyProfile.name] = {}

  for profileName, profile in pairs(hotkeyProfile.actionProfiles) do
    config[hotkeyProfile.name][profileName] = {}

    for actionName, action in pairs(profile.actions) do
      config[hotkeyProfile.name][profileName][actionName] = {
        keys = {
          chatDisabled = {
            primaryKey = action.keys.chatDisabled.primaryKey,
            secondaryKey = action.keys.chatDisabled.secondaryKey,
            tertiaryKey = action.keys.chatDisabled.tertiaryKey
          },
          chatEnabled = {
            primaryKey = action.keys.chatEnabled.primaryKey,
            secondaryKey = action.keys.chatEnabled.secondaryKey,
            tertiaryKey = action.keys.chatEnabled.tertiaryKey
          }
        }
      }
    end
  end

  g_settings.setNode('hotkeysConfigSettings', config)
end
