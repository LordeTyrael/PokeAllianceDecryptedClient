function sendLocale()
  local userLocaleName = g_settings.getString('locale')
  if userLocaleName and string.len(userLocaleName) == 2 then
    if g_game.isOnline() then
        print(string.format("[locale] sending locale %s", userLocaleName))
        g_game.getProtocolGame():sendExtendedOpcode(1, userLocaleName)
        return
    end

    print("[locale] cannot send locale due offline cond")
    return
  end

  print(string.format("[locale.lua] cannot send undefined locale: %s", userLocaleName))
end

playerExperienceInfo = {}