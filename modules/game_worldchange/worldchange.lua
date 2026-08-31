local GameWorldChangeOpcode = 93
local GameWorldChangeWindow = nil

function onGameStart()
    if not g_game.isOnline() then
        return
    end

    g_ui.loadUI('worldchange')        
    GameWorldChangeTopButton = modules.client_topmenu.addMiddleGameToggleButton('GameWorldChangeTopButton', tr('World Migration') .. '', '/images/ui/topbuttons/icons/world_change', toggle)
    GameWorldChangeTopButton:setOn(false)

    GameWorldChangeWindow = g_ui.createWidget('WorldChangeWindow', modules.game_interface.getRootPanel())
    GameWorldChangeWindow:hide()

    GameWorldChangeWindow2 = g_ui.createWidget('WorldChangeWindow2', modules.game_interface.getRootPanel())
    GameWorldChangeWindow2:hide()

    GameWorldChangeWindow3 = g_ui.createWidget('WorldChangeWindow3', modules.game_interface.getRootPanel())
    GameWorldChangeWindow3:hide()

    ProtocolGame.registerExtendedJSONOpcode(GameWorldChangeOpcode, handle)
end

function onGameEnd()
    ProtocolGame.unregisterExtendedJSONOpcode(GameWorldChangeOpcode)

    if GameWorldChangeWindow then
        GameWorldChangeWindow:destroy()
    end
    if GameWorldChangeWindow2 then
        GameWorldChangeWindow2:destroy()
    end
    if GameWorldChangeWindow3 then
        GameWorldChangeWindow3:destroy()
    end
end

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if g_game.isOnline() then
        onGameStart()
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
end

function toggle()
    if GameWorldChangeTopButton and GameWorldChangeTopButton:isOn() then
        GameWorldChangeTopButton:setOn(false)
        GameWorldChangeWindow:hide()
    else
        GameWorldChangeTopButton:setOn(true)
        GameWorldChangeWindow:show()
        local widget = GameWorldChangeWindow:getChildById("widget1")
        widget:setColoredText({"Once you go from a ","white","PvP","red", " to a ","white","Non-PvP","#007eff"," world, you will only be able to migrate again to ","white","Non-PvP","#007eff"," worlds.","white"})
        widget:show()

        local widget = GameWorldChangeWindow:getChildById("widget2")
        widget:setColoredText({"You will be able to migrate again only after 30 days.","white"})
        widget:show()

        local widget = GameWorldChangeWindow:getChildById("widget3")
        widget:setColoredText({"You cannot migrate to a world that has been created less than 3 months.","white"})
        widget:show()
    end
end

function handle(protocol, opcode, payload)
    if GameWorldChangeWindow then
        if payload.type == "reply-requirements" then
            for name, config in pairs(payload.data) do
                if config == 0 then
                    truePath = "/modules/game_worldchange/images/icon_true.png"
                elseif config >= 1 then
                    truePath = "/modules/game_worldchange/images/icon_false.png"
                end

                if name == "haveHouse" then
                    GameWorldChangeWindow2:recursiveGetChildById('house_icon'):setImageSource(truePath)
                elseif name == "haveMarketOffer" then
                    GameWorldChangeWindow2:recursiveGetChildById('market_icon'):setImageSource(truePath)
                elseif name == "haveGuild" then
                    GameWorldChangeWindow2:recursiveGetChildById('guild_icon'):setImageSource(truePath)
                elseif name == "onTradeCenter" then
                    GameWorldChangeWindow2:recursiveGetChildById('tc_icon'):setImageSource(truePath)
                elseif name == "registeredOnTournament" then
                    GameWorldChangeWindow2:recursiveGetChildById('tournament_icon'):setImageSource(truePath)
                elseif name == "havePvpPenalty" then
                    GameWorldChangeWindow2:recursiveGetChildById('pvp_icon'):setImageSource(truePath)
                elseif name == "haveTransferReleased" then
                    GameWorldChangeWindow2:recursiveGetChildById('transfer_icon'):setImageSource(truePath)
                elseif name == "haveTransferCoins" then
                    GameWorldChangeWindow2:recursiveGetChildById('pending_coins_icon'):setImageSource(truePath)
                elseif name == "haveTicket" then
                    GameWorldChangeWindow2:getChildById("world_panel"):getChildById("price"):setImageSource(truePath)
                end
                --elseif config == 1 then
                --    worldChangeWidget:hide()
            end
            local worlds = {"Select", "Gold", "Silver"}
            if GameWorldChangeWindow2:getChildById("world_panel"):getChildById("server_box"):getOptionsCount() == 0 then
                for _, tab in pairs(worlds) do
                    GameWorldChangeWindow2:getChildById("world_panel"):getChildById("server_box"):addOption(tab:sub(1,1):upper()..tab:sub(2), _)
                end
            end
            GameWorldChangeWindow2:getChildById("world_panel"):getChildById("server_box").onOptionChange = requestTransferInfo
        end

        if payload.type == "reply-transfer-info" then
            table.dump(payload.data)
            data = payload.data
            if data.errors then
                errorBox = displayErrorBox(tr("Error"), data.errors[1])
                errorBox.onOk = function()
                    errorBox = nil
                end
                return
            end
            requestRequirements()
        end

        if payload.type == "reply-transfer-confirm" then
            data = payload.data
            if data.errors then
                errorBox2 = displayErrorBox(tr("Error"), data.errors[1])
                errorBox2.onOk = function()
                    errorBox2 = nil
                end
                return
            end
        end
    end
    
end

function next()
    requestRequirements()
    GameWorldChangeWindow2:show()
    GameWorldChangeWindow:hide()
end

function prev()
    GameWorldChangeWindow2:hide()
    GameWorldChangeWindow:show()
end

function confirm()
    GameWorldChangeWindow3:show()
    GameWorldChangeWindow2:hide()
end

function requestRequirements()
    local buffer = {
        type = "requirements",
    }
    g_game.getProtocolGame():sendExtendedOpcode(GameWorldChangeOpcode, json.encode(buffer))
end

function requestTransferInfo()
    selectWorld = GameWorldChangeWindow2:getChildById("world_panel"):getChildById("server_box"):getCurrentOption().data
    local buffer = {
        type = "transfer-info",
        data = {
            world = selectWorld,
        }
    }
    requestRequirements()
    if selectWorld == 1 then
        errorBox3 = displayErrorBox(tr("Attention"), 'You must select a valid world.')
        errorBox3.onOk = function()
            errorBox3 = nil
        end
        return
    end
    g_game.getProtocolGame():sendExtendedOpcode(GameWorldChangeOpcode, json.encode(buffer))
end

function confirmWindow()
    password = GameWorldChangeWindow3:getChildById("password_confirm"):getText()
    selectWorld = GameWorldChangeWindow2:getChildById("world_panel"):getChildById("server_box"):getCurrentOption().data
    local buffer = {
        type = "transfer-confirm",
        data = {
            password = password,
            world = selectWorld,
        }
    }
    g_game.getProtocolGame():sendExtendedOpcode(GameWorldChangeOpcode, json.encode(buffer))
end