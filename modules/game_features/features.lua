function init()
  connect(g_game, { onClientVersionChange = updateFeatures })
end

function terminate()
  disconnect(g_game, { onClientVersionChange = updateFeatures })
end

function updateFeatures(version)
    g_game.resetFeatures()
    if version <= 0 then
      return
    end
    
    -- you can add custom features here, list of them is in the modules\gamelib\const.lua
    -- NÃO REMOVER, apesar do transporte extended opcode ter sido apagado. Nesta fork esta feature
    -- virou, na prática, o "eu sou OTClient": com ela desligada o entergame chama setCustomOs(2/5)
    -- e passa a se anunciar como Windows, e é o `operatingSystem >= CLIENTOS_OTCLIENT_LINUX` do
    -- servidor que liga enableCompression(). Desligar aqui quebra a compressão, não os opcodes.
   	g_game.enableFeature(GameExtendedOpcode)
    g_game.enableFeature(GamePlayerStamina)
    g_game.enableFeature(GameNewFluids)
    g_game.enableFeature(GameNewOutfitProtocol)
    g_game.enableFeature(GameWritableDate)
    g_game.enableFeature(GameProtocolChecksum)
    g_game.enableFeature(GameAccountNames)
    g_game.enableFeature(GameDoubleShopSellAmount)
    --g_game.enableFeature(GameNoDebug)
    --g_game.enableFeature(GameDontCacheFiles)
    g_game.enableFeature(GameDoubleFreeCapacity)
    g_game.enableFeature(GameChallengeOnLogin)
    g_game.enableFeature(GameMessageSizeCheck)
    g_game.enableFeature(GameTileAddThingWithStackpos)
    g_game.enableFeature(GameCreatureEmblems)
    g_game.enableFeature(GameThingMarks)
    g_game.enableFeature(GameOutfitShaders)
    g_game.enableFeature(GameDoubleTradeMoney)
    g_game.enableFeature(GameDoubleExperience)
    --g_game.enableFeature(GameClientPing)
    --g_game.enableFeature(GameDoubleHealth)

    if(version >= 860) then
        g_game.enableFeature(GameAttackSeq)
    end

    if(version >= 862) then
        g_game.enableFeature(GamePenalityOnDeath)
    end

    if(version >= 870) then
        g_game.enableFeature(GameDoubleExperience)
        g_game.enableFeature(GamePlayerMounts)
        g_game.enableFeature(GameSpellList)
    end

    if(version >= 910) then
        g_game.enableFeature(GameNameOnNpcTrade)
        g_game.enableFeature(GameTotalCapacity)
        g_game.enableFeature(GameSkillsBase)
        g_game.enableFeature(GamePlayerRegenerationTime)
        g_game.enableFeature(GameChannelPlayerList)
        g_game.enableFeature(GameEnvironmentEffect)
        g_game.enableFeature(GameItemAnimationPhase)
    end

    if(version >= 940) then
        g_game.enableFeature(GamePlayerMarket)
    end

    if(version >= 953) then
        g_game.enableFeature(GamePurseSlot)
        g_game.enableFeature(GameClientPing)
    end

    if(version >= 960) then
        g_game.enableFeature(GameOfflineTrainingTime)
    end

    if(version >= 963) then
        g_game.enableFeature(GameAdditionalVipInfo)
    end

    if(version >= 972) then
        g_game.enableFeature(GameDoublePlayerGoodsMoney)
    end

    if(version >= 980) then
        g_game.enableFeature(GamePreviewState)
        g_game.enableFeature(GameClientVersion)
    end

    if(version >= 981) then
        g_game.enableFeature(GameLoginPending)
        g_game.enableFeature(GameNewSpeedLaw)
    end

    if(version >= 984) then
        g_game.enableFeature(GameContainerPagination)
        g_game.enableFeature(GameBrowseField)
    end

    if(version >= 1035) then
        g_game.enableFeature(GameDoubleSkills)
        g_game.enableFeature(GameBaseSkillU16)
    end

    if(version >= 1036) then
        g_game.enableFeature(GameCreatureIcons)
        g_game.enableFeature(GameHideNpcNames)
    end

    if(version >= 1038) then
        g_game.enableFeature(GamePremiumExpiration)
    end

    if(version >= 1054) then
        g_game.enableFeature(GameExperienceBonus)
    end

    if(version >= 1055) then
        g_game.enableFeature(GameDeathType)
    end

    if(version >= 1057) then
        g_game.enableFeature(GameIdleAnimations)
    end

    if(version >= 1061) then
        g_game.enableFeature(GameOGLInformation)
    end

    if(version >= 1071) then
        g_game.enableFeature(GameContentRevision)
    end

    if(version >= 1072) then
        g_game.enableFeature(GameAuthenticator)
    end

    if(version >= 1074) then
        g_game.enableFeature(GameSessionKey)
    end

    if(version >= 1080) then
        g_game.enableFeature(GameIngameStore)
    end

    if(version >= 1092) then
        g_game.enableFeature(GameIngameStoreServiceType)
    end

    if(version >= 1093) then
        g_game.enableFeature(GameIngameStoreHighlights)
    end

    if(version >= 1094) then
        g_game.enableFeature(GameAdditionalSkills)
    end

    if(version >= 1098) then
        g_game.enableFeature(GameChangeMapAwareRange)
    end
       
    if(version >= 1100) then
        g_game.enableFeature(GamePrey)    
    end
    
    if(version >= 1200) then
      g_game.enableFeature(GameSequencedPackets)
      --g_game.enableFeature(GameSendWorldName)
      g_game.enableFeature(GamePlayerStateU32)
      g_game.enableFeature(GameTibia12Protocol)      
    end    
    modules.game_things.load()
end
