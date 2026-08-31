CharacterList = { }
ChangePassword = { }
ChangeEmail = { }

-- private variables
local test
local charactersWindow
local changePasswordWindow
local changeEmailWindow
local loadBox
local characterList
local errorBox
local waitingWindow
--local autoReconnectButton
local updateWaitEvent
local resendWaitEvent
local loginEvent
--local autoReconnectEvent
local lastLogout = 0
local logoutEvent

local function destroyCharactersWindow()
  logoutEvent = nil
  characterList = nil
  if charactersWindow then
    charactersWindow:destroy()
    charactersWindow = nil
  end
end

local function formatBallName(name)
    if name == "poke" then
        return "Poke Ball"
    elseif name == "great" then
        return "Great Ball"
    elseif name == "saffari" then
        return "Safari Ball"
    elseif name == "super" then
        return "Super Ball"
    elseif name == "ultra" then
        return "Ultra Ball"
    elseif name == "premier" then
        return "Premier Ball"
    elseif name == "master" then
        return "Master Ball"
    elseif name == "magu" then
        return "Magu Ball"
    elseif name == "sora" then
        return "Sora Ball"
    elseif name == "yume" then
        return "Yume Ball"
    elseif name == "dusk" then
        return "Dusk Ball"
    elseif name == "tale" then
        return "Tale Ball"
    elseif name == "moon" then
        return "Moon Ball"
    elseif name == "net" then
        return "Net Ball"
    elseif name == "janguru" then
        return "Janguru Ball"
    elseif name == "tinker" then
        return "Tinker Ball"
    elseif name == "fast" then
        return "Fast Ball"
    elseif name == "heavy" then
        return "Heavy Ball"
    elseif name == "friendBall" then
        return "Friend Ball"
    else
        return name
    end
end

-- private functions
local function tryLogin(charInfo, tries)
  tries = tries or 1

  if tries > 50 then
    return
  end

  if g_game.isOnline() then
    if tries == 1 then
      g_game.safeLogout()
    end
    loginEvent = scheduleEvent(function() tryLogin(charInfo, tries+1) end, 100)
    return
  end
  
  -- proxies
  if g_proxy then
    g_proxy.clear()
    if G.proxies then
      for i, proxy in ipairs(G.proxies) do
        if proxy.worldId == charInfo.worldId then
          g_proxy.addProxy(proxy["host"], tonumber(proxy["port"]), tonumber(proxy["priority"]))
        end
      end
    end
  end

  CharacterList.hide()
  g_game.loginWorld(G.account, G.password, charInfo.worldName, charInfo.worldHost, charInfo.worldPort, charInfo.characterName, getLocale(), G.authenticatorToken, G.sessionKey)
  loadBox = displayAllianceCancelBox(tr('Please wait'), tr('Connecting to game server...'))
  connect(loadBox, { onCancel = function()
                                  loadBox = nil
                                  g_game.cancelLogin()
                                  CharacterList.show()
                                end })

  -- save last used character
  g_settings.set('last-used-character', charInfo.characterName)
  g_settings.set('last-used-world', charInfo.worldName)
end

local function updateWait(timeStart, timeEnd)
  if waitingWindow then
    local time = g_clock.seconds()
    if time <= timeEnd then
      local percent = ((time - timeStart) / (timeEnd - timeStart)) * 100
      local timeStr = string.format("%.0f", timeEnd - time)

      local progressBar = waitingWindow:getChildById('progressBar')
      progressBar:setPercent(percent)

      local label = waitingWindow:getChildById('timeLabel')
      label:setText(tr('Trying to reconnect in %s seconds.', timeStr))

      updateWaitEvent = scheduleEvent(function() updateWait(timeStart, timeEnd) end, 1000 * progressBar:getPercentPixels() / 100 * (timeEnd - timeStart))
      return true
    end
  end

  if updateWaitEvent then
    updateWaitEvent:cancel()
    updateWaitEvent = nil
  end
end

local function resendWait()
  if waitingWindow then
    waitingWindow:destroy()
    waitingWindow = nil

    if updateWaitEvent then
      updateWaitEvent:cancel()
      updateWaitEvent = nil
    end

    if charactersWindow then
      local selected = characterList:getFocusedChild()
      if selected then
        local charInfo = {  worldId = selected.worldId,
                            worldHost = selected.worldHost,
                            worldPort = selected.worldPort,
                            worldName = selected.worldName,
                            characterName = selected.characterName }
        tryLogin(charInfo)
      end
    end
  end
end

local function onLoginWait(message, time)
  CharacterList.destroyLoadBox()

  waitingWindow = g_ui.displayUI('waitinglist')

  local label = waitingWindow:getChildById('infoLabel')
  label:setText(message)

  updateWaitEvent = scheduleEvent(function() updateWait(g_clock.seconds(), g_clock.seconds() + time) end, 0)
  resendWaitEvent = scheduleEvent(resendWait, time * 1000)
end

function CharacterList.showCreateCharacter()
  CharacterList.hide()
  CreateCharacter.setNoCharactersMode(false)
  CreateCharacter.show()
end

function CharacterList.logoutToEnterGame()
  destroyCharactersWindow()
  if EnterGame then
    EnterGame.show()
  end
end

function CharacterList.showChangePassword()
  CharacterList.hide()
  changePasswordWindow:show()
  changePasswordWindow.passwordTextEdit:focus()
end

function CharacterList.showChangeEmail()
  CharacterList.hide()
  changeEmailWindow:show()
  changeEmailWindow.passwordTextEdit:focus()
end

function onGameLoginError(message)
  CharacterList.destroyLoadBox()
  if errorBox then
    errorBox:destroy()
    errorBox = nil
  end
  errorBox = displayAllianceErrorBox(tr("Login Error"), message)
  errorBox.onOk = function()
    errorBox = nil
    CharacterList.showAgain()
  end
  --scheduleAutoReconnect()
end

function onGameLoginToken(unknown)
  CharacterList.destroyLoadBox()
  -- TODO: make it possible to enter a new token here / prompt token
  errorBox = displayAllianceErrorBox(tr("Two-Factor Authentification"), 'A new authentification token is required.\nPlease login again.')
  errorBox.onOk = function()
    errorBox = nil
    EnterGame.show()
  end
end

function onGameConnectionError(message, code)
  CharacterList.destroyLoadBox()
  if (not g_game.isOnline() or code ~= 2) and not errorBox then -- code 2 is normal disconnect, end of file
    local text = translateNetworkError(code, g_game.getProtocolGame() and g_game.getProtocolGame():isConnecting(), message)
    errorBox = displayAllianceErrorBox(tr("Connection Error"), text)
    errorBox.onOk = function()
      errorBox = nil
      CharacterList.showAgain()
    end
  end
end

function onGameUpdateNeeded(signature)
  CharacterList.destroyLoadBox()
  errorBox = displayAllianceErrorBox(tr("Update needed"), tr('Enter with your account again to update your client.'))
  errorBox.onOk = function()
    errorBox = nil
    CharacterList.showAgain()
  end
end

function onGameEnd()
  --scheduleAutoReconnect()
  CharacterList.showAgain()
end

function onLogout()
  lastLogout = g_clock.millis()
end

-- public functions
function CharacterList.init()
  connect(g_game, { onLoginError = onGameLoginError })
  connect(g_game, { onLoginToken = onGameLoginToken })
  connect(g_game, { onUpdateNeeded = onGameUpdateNeeded })
  connect(g_game, { onConnectionError = onGameConnectionError })
  connect(g_game, { onGameStart = CharacterList.destroyLoadBox })
  connect(g_game, { onLoginWait = onLoginWait })
  connect(g_game, { onGameEnd = onGameEnd })
  connect(g_game, { onLogout = onLogout })

  if G.characters then
    CharacterList.create(G.characters, G.characterAccount, nil, G.proxies)
  end
end

function CharacterList.terminate()
  disconnect(g_game, { onLoginError = onGameLoginError })
  disconnect(g_game, { onLoginToken = onGameLoginToken })
  disconnect(g_game, { onUpdateNeeded = onGameUpdateNeeded })
  disconnect(g_game, { onConnectionError = onGameConnectionError })
  disconnect(g_game, { onGameStart = CharacterList.destroyLoadBox })
  disconnect(g_game, { onLoginWait = onLoginWait })
  disconnect(g_game, { onGameEnd = onGameEnd })
  disconnect(g_game, { onLogout = onLogout })

  if logoutEvent then
    removeEvent(logoutEvent)
    logoutEvent = nil
  end

  destroyCharactersWindow()

  if loadBox then
    g_game.cancelLogin()
    loadBox:destroy()
    loadBox = nil
  end

  if waitingWindow then
    waitingWindow:hide()
    waitingWindow:destroy()
    waitingWindow = nil
  end

  if updateWaitEvent then
    removeEvent(updateWaitEvent)
    updateWaitEvent = nil
  end

  if resendWaitEvent then
    removeEvent(resendWaitEvent)
    resendWaitEvent = nil
  end

  if loginEvent then
    removeEvent(loginEvent)
    loginEvent = nil
  end

  CharacterList = nil
end

function CharacterList.create(characters, account, otui, proxies)
    destroyCharactersWindow()

    if not otui then
        otui = 'characterlist'
    end

    charactersWindow = g_ui.displayUI(otui)
    
    -- Apply scale based on window size
    local currentSize = g_window.getSize()
    local widthScale = currentSize.width / 1920.0
    local heightScale = currentSize.height / 1080.0
    local scale = math.min(widthScale, heightScale)
    
    if scale < 1.0 then
        charactersWindow:scale(scale)
    end
    
    characterList = charactersWindow.backgroundLabel.characterList
    
    -- Update layout properties after scaling
    if scale < 1.0 and characterList then
        local layout = characterList:getLayout()
        if layout then
            -- Scale cell-size and cell-spacing
            local baseCellSize = 122
            local baseCellSpacing = 5
            local newCellSize = math.floor(baseCellSize * scale)
            local newCellSpacing = math.floor(baseCellSpacing * scale)
            
            layout:setCellSize({width = newCellSize, height = newCellSize})
            layout:setCellSpacing(newCellSpacing)
            characterList:updateLayout()
        end
    end

    G.characters = characters
    G.characterAccount = account
    G.proxies = proxies

    characterList:destroyChildren()
    local focusLabel
    for i, characterInfo in ipairs(characters) do
        local widget = g_ui.createWidget('NewCharacterWidget', characterList)
        for key, value in pairs(characterInfo) do
            if key == "level" then
                widget.level:setText(value)
            elseif key == "name" then
                widget.name:setText(value)
            elseif key == 'icon' then
                local playerSex = characterInfo.sex or 0
                local sexData = playerSex == 0 and "male" or "female"
                widget.icon:setImageSource(string.format("/images/perfil/circle/%s/%d", sexData, value))
            end
        end

        -- these are used by login
        widget.characterName = characterInfo.name
        widget.worldId = characterInfo.worldId
        widget.worldName = characterInfo.worldName
        widget.worldHost = characterInfo.worldIp
        widget.worldPort = characterInfo.worldPort
        widget.characterInfo = characterInfo
        connect(widget, { onDoubleClick = function () CharacterList.doLogin() return true end } )

        if i == 1 or (g_settings.get('last-used-character') == widget.characterName and g_settings.get('last-used-world') == widget.worldName) then
            focusLabel = widget
        end
    end

    local newWidget = g_ui.createWidget('NewCharacterWidget', characterList)
    newWidget.newCharacter:show()
    newWidget:setFocusable(false)

    changePasswordWindow = g_ui.displayUI("changepassword")
    changeEmailWindow = g_ui.displayUI("changeemail")

    -- account
    local status = ''
    if account.status == AccountStatus.Frozen then
        status = tr(' (Frozen)')
    elseif account.status == AccountStatus.Suspended then
        status = tr(' (Suspended)')
    end

    local accountInfo = charactersWindow.accountInformation.accountInfo
    local accountStatusLabel = accountInfo.accountStatusCaption
    if account.subStatus == SubscriptionStatus.Free and account.premDays < 1 then
        accountStatusLabel:setText(('%s%s'):format(tr('Free Account'), status))
    else
        accountStatusLabel:setText(('%s%s'):format(tr(string.format('VIP Account (%s)', account.premDays)), status))
    end

    if account.premDays > 0 and account.premDays <= 7 then
        accountStatusLabel:setOn(true)
    else
        accountStatusLabel:setOn(false)
    end

    local characterSkills = charactersWindow.accountInformation.characterSkills
    local skills = {
        {id = "experience", name ="Experience", icon = "character_list/skills/exp", progress = "character_list/skills/exp_progress"},
        {id = "fishing", name ="Fishing", icon = "character_list/skills/fishing", progress = "character_list/skills/fishing_progress"},
        {id = "headbutt", name ="Headbutt", icon = "character_list/skills/headbutt", progress = "character_list/skills/headbutt_progress"},
        {id = "rockSmash", name ="Rock Smash", icon = "character_list/skills/rock_smash", progress = "character_list/skills/rock_smash_progress"},
        {id = "balance", name ="Balance", icon = "character_list/skills/balance", progress = "character_list/skills/balance_fill"}
    }

    for _, skill in ipairs(skills) do
        local skillWidget = characterSkills:getChildById(skill.id)
        if skillWidget then
            local skillIcon = skillWidget.skillIcon
            if skillIcon then
                skillIcon:setImageSource(skill.icon)
            end

            local skillName = skillWidget.skillName
            if skillName then
                skillName:setText(tr(skill.name))
            end

            local skillValue = skillWidget.skillProgressValue
            if skillValue then
                skillValue:setImageSource(skill.progress)
            end
        end
    end

    if focusLabel then
        characterList:focusChild(focusLabel, KeyboardFocusReason)
        addEvent(function() characterList:ensureChildVisible(focusLabel) end)
        local information = focusLabel.characterInfo
        local informationWindow = charactersWindow.accountInformation.characterSkills
        informationWindow.experience.skillValue:setText(comma_value2(information.experience))
        local playerSex = information.sex or 0
        local sexData = playerSex == 0 and "male" or "female"
        charactersWindow.selectedCharacterInfo.playerIcon:setImageSource(string.format("/images/perfil/circle/%s/%d", sexData, information.icon))
        charactersWindow.accountInformation.playerIcon:setImageSource(string.format("/images/perfil/circle/%s/%d", sexData, information.icon))

        local widthSize = 205

        local clippedExperienceWidth = math.max(1, widthSize * (information.experiencePercent / 100))
        local experienceRect = {x = 0, y = 0, width = clippedExperienceWidth, height = informationWindow.experience.skillProgressValue:getHeight()}
        informationWindow.experience.skillProgressValue:setImageClip(experienceRect)
        informationWindow.experience.skillProgressValue:setImageRect(experienceRect)

        local fishingWindow = informationWindow.fishing
        fishingWindow.skillValue:setText(information.fishingSkill)

        local clippedFishingWidth = math.max(1, widthSize * (information.fishingPercent / 100))
        local fishingRect = {x = 0, y = 0, width = clippedFishingWidth, height = fishingWindow.skillProgressValue:getHeight()}
        fishingWindow.skillProgressValue:setImageClip(fishingRect)
        fishingWindow.skillProgressValue:setImageRect(fishingRect)

        local headbuttWindow = informationWindow.headbutt
        informationWindow.headbutt.skillValue:setText(information.headbuttSkill)

        local clippedHeadbuttWidth = math.max(1, widthSize * (information.headbuttPercent / 100))
        local headbuttRect = {x = 0, y = 0, width = clippedHeadbuttWidth, height = headbuttWindow.skillProgressValue:getHeight()}
        headbuttWindow.skillProgressValue:setImageClip(headbuttRect)
        headbuttWindow.skillProgressValue:setImageRect(headbuttRect)

        local rockSmashWindow = informationWindow.rockSmash
        informationWindow.rockSmash.skillValue:setText(information.rockSmashSkill)

        local clippedRockSmashWidth = math.max(1, widthSize * (information.rockSmashPercent / 100))
        local rockSmashRect = {x = 0, y = 0, width = clippedRockSmashWidth, height = rockSmashWindow.skillProgressValue:getHeight()}
        rockSmashWindow.skillProgressValue:setImageClip(rockSmashRect)
        rockSmashWindow.skillProgressValue:setImageRect(rockSmashRect)

        informationWindow.balance.skillValue:setText("$"..comma_value2(information.balance))

        local selectedWindow = charactersWindow.selectedCharacterInfo
        selectedWindow.name:setText(information.name)
        selectedWindow.level:setText(tr("Lv. %d", information.level))

        if information.guildName:len() > 0 then
            selectedWindow.guildName:setText(information.guildName)
        else
            selectedWindow.guildName:setText(tr("No Guild"))
        end

        selectedWindow.worldName:setText(information.worldName)

        if information.guildIcon > 0 then
            selectedWindow.guildIcon:setImageSource("/images/guildIcons/"..information.guildIcon)
        else
            selectedWindow.guildIcon:setImageSource("/images/guildIcons/0")
        end

        for i = 1, 6 do
            local pokemonWindow = selectedWindow.pokemonWindow:getChildById("pokeball"..i)
            if pokemonWindow then
                local pokeball = information.pokeballs[i]
                if pokeball then
                    pokemonWindow:setImageSource("character_list/poke")
                    local number = g_pokemonCyclopedia.getDexNumber(pokeball.pokemon:lower())
                    if number ~= "" then
                        pokemonWindow.pokemonImage:setImageSource('/images/pokemons/' .. number)
                    else
                        pokemonWindow.pokemonImage:setImageSource(nil)
                    end
                else
                    pokemonWindow:setImageSource("character_list/empty_poke")
                    pokemonWindow.pokemonImage:setImageSource(nil)
                end
            end
        end
    end

    if account.diamonds > 0 then
        accountInfo.diamondCount:setText(account.diamonds)
    end
end

function updateCharacterListFocus(focusedWidget)
    local children = focusedWidget:getChildren()
    for i=1,#children do
        children[i]:setOn(focusedWidget:isFocused())
    end
    if focusedWidget:isFocused() then
        focusedWidget:setImageSource("character_list/base_focused")
        local information = focusedWidget.characterInfo
        if information then
            local informationWindow = charactersWindow.accountInformation.characterSkills
            informationWindow.experience.skillValue:setText(comma_value2(information.experience))
            local playerSex = information.sex or 0
            local sexData = playerSex == 0 and "male" or "female"
            charactersWindow.selectedCharacterInfo.playerIcon:setImageSource(string.format("/images/perfil/circle/%s/%d", sexData, information.icon))
            focusedWidget.icon:setImageSource(string.format("/images/perfil/circle/%s/%d", sexData, information.icon))
            charactersWindow.accountInformation.playerIcon:setImageSource(string.format("/images/perfil/circle/%s/%d", sexData, information.icon))

            local widthSize = 205

            local clippedExperienceWidth = math.max(1, widthSize * (information.experiencePercent / 100))
            local experienceRect = {x = 0, y = 0, width = clippedExperienceWidth, height = informationWindow.experience.skillProgressValue:getHeight()}
            informationWindow.experience.skillProgressValue:setImageClip(experienceRect)
            informationWindow.experience.skillProgressValue:setImageRect(experienceRect)

            local fishingWindow = informationWindow.fishing
            fishingWindow.skillValue:setText(information.fishingSkill)

            local clippedFishingWidth = math.max(1, widthSize * (information.fishingPercent / 100))
            local fishingRect = {x = 0, y = 0, width = clippedFishingWidth, height = fishingWindow.skillProgressValue:getHeight()}
            fishingWindow.skillProgressValue:setImageClip(fishingRect)
            fishingWindow.skillProgressValue:setImageRect(fishingRect)

            local headbuttWindow = informationWindow.headbutt
            informationWindow.headbutt.skillValue:setText(information.headbuttSkill)

            local clippedHeadbuttWidth = math.max(1, widthSize * (information.headbuttPercent / 100))
            local headbuttRect = {x = 0, y = 0, width = clippedHeadbuttWidth, height = headbuttWindow.skillProgressValue:getHeight()}
            headbuttWindow.skillProgressValue:setImageClip(headbuttRect)
            headbuttWindow.skillProgressValue:setImageRect(headbuttRect)

            local rockSmashWindow = informationWindow.rockSmash
            informationWindow.rockSmash.skillValue:setText(information.rockSmashSkill)

            local clippedRockSmashWidth = math.max(1, widthSize * (information.rockSmashPercent / 100))
            local rockSmashRect = {x = 0, y = 0, width = clippedRockSmashWidth, height = rockSmashWindow.skillProgressValue:getHeight()}
            rockSmashWindow.skillProgressValue:setImageClip(rockSmashRect)
            rockSmashWindow.skillProgressValue:setImageRect(rockSmashRect)

            informationWindow.balance.skillValue:setText("$"..comma_value2(information.balance))

            local selectedWindow = charactersWindow.selectedCharacterInfo
            selectedWindow.name:setText(information.name)
            selectedWindow.level:setText(tr("Lv. %d", information.level))

            if information.guildName:len() > 0 then
                selectedWindow.guildName:setText(information.guildName)
            else
                selectedWindow.guildName:setText(tr("No Guild"))
            end

            selectedWindow.worldName:setText(information.worldName)

            if information.guildIcon > 0 then
                selectedWindow.guildIcon:setImageSource("/images/guildIcons/"..information.guildIcon)
            else
                selectedWindow.guildIcon:setImageSource("/images/guildIcons/0")
            end

            for i = 1, 6 do
                local pokemonWindow = selectedWindow.pokemonWindow:getChildById("pokeball"..i)
                if pokemonWindow then
                    local pokeball = information.pokeballs[i]
                    if pokeball then
                        pokemonWindow:setImageSource("character_list/poke")
                        local number = g_pokemonCyclopedia.getDexNumber(pokeball.pokemon:lower())
                        if number ~= "" then
                            pokemonWindow.pokemonImage:setImageSource('/images/pokemons/' .. number)
                        else
                            pokemonWindow.pokemonImage:setImageSource(nil)
                        end
                    else
                        pokemonWindow:setImageSource("character_list/empty_poke")
                        pokemonWindow.pokemonImage:setImageSource(nil)
                    end
                end
            end
        end
    else
        focusedWidget:setImageSource("character_list/base_char")
    end
end

function CharacterList.destroy()
  CharacterList.hide(true)
  destroyCharactersWindow()
end

function CharacterList.show()
  if loadBox or errorBox or not charactersWindow then return end
  charactersWindow:show()
  charactersWindow:raise()
  charactersWindow:focus()
end

function CharacterList.hide(showLogin)
  showLogin = showLogin or false
  if charactersWindow then
    charactersWindow:hide()
  end

  if showLogin and EnterGame and not g_game.isOnline() then
    EnterGame.show()
  end
end

function CharacterList.showAgain()
  if characterList and characterList:hasChildren() then
    CharacterList.show()
  end
end

function CharacterList.isVisible()
  if charactersWindow and charactersWindow:isVisible() then
    return true
  end
  return false
end

function CharacterList.doLogin()
  --removeEvent(autoReconnectEvent)
  --autoReconnectEvent = nil

  local selected = characterList:getFocusedChild()
  if selected then
    local charInfo = { worldHost = selected.worldHost,
                       worldId = selected.worldId,
                       worldPort = selected.worldPort,
                       worldName = selected.worldName,
                       characterName = selected.characterName }
    charactersWindow:hide()
    if loginEvent then
      removeEvent(loginEvent)
      loginEvent = nil
    end

    tryLogin(charInfo)
  else
    displayAllianceErrorBox(tr('Error'), tr('You must select a character to login!'))
  end
end

function CharacterList.destroyLoadBox()
  if loadBox then
    loadBox:hide()
    loadBox:destroy()
    loadBox = nil
  end
end

function CharacterList.cancelWait()
  if waitingWindow then
    waitingWindow:hide()
    waitingWindow:destroy()
    waitingWindow = nil
    CharacterList.show()
  end

  if updateWaitEvent then
    removeEvent(updateWaitEvent)
    updateWaitEvent = nil
  end

  if resendWaitEvent then
    removeEvent(resendWaitEvent)
    resendWaitEvent = nil
  end

  CharacterList.destroyLoadBox()
 -- CharacterList.showAgain()
end

function ChangePassword.hideChangePasswordWindow()
  if changePasswordWindow then
    changePasswordWindow:hide()
  end
end

function ChangePassword.getWidget()
  return changePasswordWindow
end

function ChangeEmail.hideChangeEmailWindow()
  if changeEmailWindow then
    changeEmailWindow:hide()
  end
end

function ChangeEmail.updateRecoveryKeyNotice(recoveryKeyEdit)
  local window = recoveryKeyEdit:getParent()
  local hasKey = recoveryKeyEdit:getText():len() > 0
  window:getChildById('rkFilledNotice'):setVisible(hasKey)
  window:getChildById('rkEmptyNotice'):setVisible(not hasKey)
end

function ChangeEmail.getWidget()
  return changeEmailWindow
end

function CharacterList.accountLogout()
    if charactersWindow and not logoutEvent then
        addEvent(function() g_effects.fadeOut(charactersWindow) end)
        logoutEvent = scheduleEvent(destroyCharactersWindow, 250)
    end
    EnterGame.fadeIn()
end

function CharacterList.toggleCharacterWidget()
    if loadBox or errorBox or not charactersWindow then return end
    local visible = not charactersWindow.selectedCharacterInfo:isVisible()
    charactersWindow.selectedCharacterInfo:setVisible(visible)
end