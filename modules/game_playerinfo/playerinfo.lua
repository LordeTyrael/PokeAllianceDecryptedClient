local playerInfoWindow = nil
local simpleClassicBar
local simpleBar
local extendedClassicBar
local extendedBar

-- playerExperienceInfo é declarado em modules/gamelib/game.lua, que NÃO é sandboxed. Não reatribua
-- aqui: `playerExperienceInfo = ...` dentro de um módulo sandboxed cria um global local ao sandbox e
-- os dois módulos param de ver a mesma tabela.

function init()
    connect(LocalPlayer, {
        onHealthChange = onHealthChange,
        onExperienceChange = onExperienceChange,
        onPlayerIconChange = onPlayerIconChange,
        onLevelChange = onLevelChange
    })

    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = offline
    })
end

function terminate()
    disconnect(LocalPlayer, {
        onHealthChange = onHealthChange,
        onExperienceChange = onExperienceChange,
        onPlayerIconChange = onPlayerIconChange,
        onLevelChange = onLevelChange,
    })

    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = offline
    })

    offline()
end

function onGameStart()
    if not playerInfoWindow then
        playerInfoWindow = g_ui.loadUI("playerinfo", modules.game_interface.getRootPanel())
    end

    loadPosition()

    playerInfoWindow.onDragLeave = function(widget)
        setTrainerInfoPosition({
            x = playerInfoWindow:getX(),
            y = playerInfoWindow:getY()
        })
        return true
    end

    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    refreshPlayerExperience()
    playerInfoWindow.playerName:setText(player:getName())
    onLevelChange(player, player:getLevel(), player:getLevelPercent())
    onHealthChange(player, player:getHealth(), player:getMaxHealth())
    playerInfoWindow:show()
    
    -- Aplicar estado salvo de expansão/retração
    local isHudCollapsed = g_settings.getBoolean('playerinfo-hud-collapsed', false)
    if isHudCollapsed then
        applyCollapsedState()
    end

    -- Definir tooltip inicial
    updateHudTooltip()

    -- Aplicar estado salvo do lock da janela
    applyLockState(g_settings.getBoolean('playerinfo-locked', false))
end

function applyLockState(locked)
    if not playerInfoWindow then return end
    playerInfoWindow:setDraggable(not locked)
    local xpBar = playerInfoWindow.playerExperience
    if xpBar then xpBar:setDraggable(not locked) end

    local lockBtn = playerInfoWindow.lockButton
    if lockBtn then
        -- f023 = cadeado fechado, f09c = cadeado aberto
        lockBtn:setIcon(locked and '@fa solid 12 f023' or '@fa solid 12 f09c')
        lockBtn:setIconColor(locked and '#ffffff' or '#aaaaaa')
        lockBtn:setTooltip(locked and tr("Click to unlock window position") or tr("Click to lock window position"))
    end
end

function toggleLock()
    local locked = not g_settings.getBoolean('playerinfo-locked', false)
    g_settings.set('playerinfo-locked', locked)
    g_settings.save()
    applyLockState(locked)
end

function updateHudTooltip()
    if not playerInfoWindow or not playerInfoWindow.hudIcon then
        return
    end
    
    local isExpanded = playerInfoWindow.playerHUD:isVisible()
    if isExpanded then
        playerInfoWindow.hudIcon:setTooltip(tr("Click to Hide Details"))
    else
        playerInfoWindow.hudIcon:setTooltip(tr("Click to Show Details"))
    end
end

function offline()
    if playerInfoWindow then
        playerInfoWindow:hide()
    end
end

function setTrainerInfoPosition(pos)
    g_settings.set('trainerInfo_x', pos.x)
    g_settings.set('trainerInfo_y', pos.y)
    g_settings.save()
end

function getTrainerInfoPositionX()
    return g_settings.getNumber('trainerInfo_x', 100)
end

function getTrainerInfoPositionY()
    return g_settings.getNumber('trainerInfo_y', 100)
end

function getPlayerConditionBar()
    if not playerInfoWindow then
        return nil
    end
    return playerInfoWindow:recursiveGetChildById('conditionBar')
end


function loadPosition()
    if not playerInfoWindow then
        return
    end

    playerInfoWindow:move(getTrainerInfoPositionX(), getTrainerInfoPositionY())
end




function refreshPlayerExperience()
  local player = g_game.getLocalPlayer()
  if not player then return end

  if expSpeedEvent then expSpeedEvent:cancel() end
  expSpeedEvent = cycleEvent(checkExpSpeed, 30*1000)
end

function checkExpSpeed()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end
    if playerExperienceInfo.lastExps ~= nil then
        onLevelChange(player, player:getLevel(), player:getLevelPercent())
    end
end

function onHealthChange(localPlayer, health, maxHealth)
    local healthPercent = health/maxHealth
    local Xhppc = math.floor(110 * (1 - (healthPercent)))
    local rect = { x = 0, y = 0, width = 110 - Xhppc, height = 14 }
    playerInfoWindow.playerHealth.healthProgress:setImageRect(rect)
    playerInfoWindow.playerHealth.healthPercent:setText(math.floor(healthPercent * 100).."%")
end

function onExperienceChange(localPlayer, value)
    local experiencePercent = localPlayer:getLevelPercent()
    local Xhppc = math.floor(110 * (1 - (math.max(1, experiencePercent) / 100)))
    local rect = { x = 0, y = 0, width = 110 - Xhppc, height = 14 }
    playerInfoWindow.playerExperience.experienceProgress:setImageRect(rect)
    playerInfoWindow.playerExperience.experiencePercent:setText(experiencePercent.."%")
    local text = comma_value(g_game.getExpToAdvance(localPlayer:getLevel(), localPlayer:getExperience())) .. tr(" of experience left")
    if playerExperienceInfo.expSpeed ~= nil then
        local expPerHour = math.floor(playerExperienceInfo.expSpeed * 3600)
        if expPerHour > 0 then
            local nextLevelExp = g_game.getExpForLevel(localPlayer:getLevel() + 1)
            local hoursLeft = (nextLevelExp - localPlayer:getExperience()) / expPerHour
            local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft)) * 60)
            hoursLeft = math.floor(hoursLeft)
            text = text .. "\n" .. comma_value(expPerHour) .. " of experience per hour"
            text = text .. "\n" .. tr("Next level in %d hours and %d minutes", hoursLeft, minutesLeft)
        end
    end
    playerInfoWindow.playerExperience:setTooltip(text)
end

function onLevelChange(localPlayer, value, experiencePercent)
    if not playerInfoWindow then
        return
    end

    local levelMsg = tr('Lvl.'..value)
    playerInfoWindow.playerLevel:setText(levelMsg)    
    local Xhppc = math.floor(110 * (1 - (math.max(1, experiencePercent) / 100)))
    local rect = { x = 0, y = 0, width = 110 - Xhppc, height = 14 }
    playerInfoWindow.playerExperience.experienceProgress:setImageRect(rect)
    playerInfoWindow.playerExperience.experiencePercent:setText(experiencePercent.."%")

    local text = comma_value(g_game.getExpToAdvance(localPlayer:getLevel(), localPlayer:getExperience())) .. tr(" of experience left")
    if playerExperienceInfo.expSpeed ~= nil then
        local expPerHour = math.floor(playerExperienceInfo.expSpeed * 3600)
        if expPerHour > 0 then
            local nextLevelExp = g_game.getExpForLevel(localPlayer:getLevel() + 1)
            local hoursLeft = (nextLevelExp - localPlayer:getExperience()) / expPerHour
            local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft)) * 60)
            hoursLeft = math.floor(hoursLeft)
            text = text .. "\n" .. comma_value(expPerHour) .. " of experience per hour"
            text = text .. "\n" .. tr("Next level in %d hours and %d minutes", hoursLeft, minutesLeft)
        end
    end
    playerInfoWindow.playerExperience:setTooltip(text)
end

function onPlayerIconChange(localPlayer, newIcon)
    if not newIcon then
        return
    end
    --playerInfoWindow.hudIcon.playerIcon:setImageSource("/modules/game_trainer/images/icons/" .. newIcon)
    local playerSex = localPlayer:getPlayerSex() or 0
    local sexData = playerSex == 0 and "male" or "female"
    playerInfoWindow.hudIcon.playerIcon:setImageSource(string.format("/images/avatars/rounded/%s/%d", sexData, newIcon))
end

function applyCollapsedState()
    if not playerInfoWindow then
        return
    end
    
    local elementsToHide = {
        playerInfoWindow.playerHUD, playerInfoWindow.playerHealth, playerInfoWindow.playerExperience, 
        playerInfoWindow.playerName, playerInfoWindow.playerLevel, playerInfoWindow.trainer_id, 
        playerInfoWindow.fish_icon, playerInfoWindow.gamepass_icon
    }

    playerInfoWindow:setSize({width = 72, height = 120})
    
    for _, element in ipairs(elementsToHide) do
        if element then
            element:hide()
        end
    end
    
    -- Manter apenas hudIcon e hudBorder visíveis
    playerInfoWindow.hudIcon:show()
    playerInfoWindow.hudBorder:show()
    
    -- Atualizar tooltip para estado retraído
    updateHudTooltip()
end

function toggleHud()
    if not playerInfoWindow then
        return
    end
    
    local hudIcon = playerInfoWindow.hudIcon
    local hudBorder = playerInfoWindow.hudBorder
    local playerHUD = playerInfoWindow.playerHUD
    local playerHealth = playerInfoWindow.playerHealth
    local playerExperience = playerInfoWindow.playerExperience
    local playerName = playerInfoWindow.playerName
    local playerLevel = playerInfoWindow.playerLevel
    local trainerId = playerInfoWindow.trainer_id
    local fishIcon = playerInfoWindow.fish_icon
    local gamepassIcon = playerInfoWindow.gamepass_icon
    
    -- Elementos que serão ocultados/mostrados
    local elementsToToggle = {
        playerHUD, playerHealth, playerExperience, 
        playerName, playerLevel, trainerId, fishIcon, gamepassIcon
    }
    
    -- Verifica se está expandido (se playerHUD está visível)
    local isExpanded = playerHUD:isVisible()
    
    if isExpanded then
        -- Retrair: Primeiro esconder elementos, depois animar janela
        for _, element in ipairs(elementsToToggle) do
            if element then
                element:hide()
            end
        end
        
        -- Animar janela encolhendo suavemente
        playerInfoWindow:setSize({width = 72, height = 120})
        
        -- Manter apenas hudIcon e hudBorder visíveis
        hudIcon:show()
        hudBorder:show()
        
        -- Salvar estado retraído
        g_settings.set('playerinfo-hud-collapsed', true)
        
        -- Atualizar tooltip
        updateHudTooltip()
        
    else
        -- Expandir: Primeiro animar janela, depois mostrar elementos
        playerInfoWindow:setSize({width = 209, height = 120})
        
        -- Mostrar elementos após a animação da janela
        addEvent(function()
            for _, element in ipairs(elementsToToggle) do
                if element then
                    element:show()
                end
            end
            -- Atualizar tooltip após mostrar elementos
            updateHudTooltip()
        end, 300)
        
        -- Manter hudIcon e hudBorder visíveis
        hudIcon:show()
        hudBorder:show()
        
        -- Salvar estado expandido
        g_settings.set('playerinfo-hud-collapsed', false)
    end
    
    g_settings.save()
end