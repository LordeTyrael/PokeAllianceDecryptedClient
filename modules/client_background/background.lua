-- private variables
local background
local clientVersionLabel
-- Declarado AQUI, junto das outras privadas, e nao em cima do changeClientLanguage: local declarado
-- depois nao existe para as funcoes acima dele, e o terminate() leria um global nil.
local localeErrorBox = nil

-- public functions
function init()
  background = g_ui.displayUI('background')
  background:lower()

  updateLanguageWidget('en', 'English', '/modules/client_entergame/new_images/language/english')
  updateLanguageWidget('pt', 'Português', '/modules/client_entergame/new_images/language/portuguese')
  updateLanguageWidget('es', 'Español', '/modules/client_entergame/new_images/language/spanish')
  updateLanguageWidget('de', 'Deutsch', '/modules/client_entergame/new_images/language/german')
  updateLanguageWidget('pl', 'Polski', '/modules/client_entergame/new_images/language/polish')

  clientVersionLabel = background:getChildById('clientVersionLabel')
  background:getChildById('clientVersionLabel'):hide()
  clientVersionLabel:setText('BUILD ' .. g_app.getVersion())
  clientVersionLabel:show()

  connect(g_game, { onGameStart = hide })
  connect(g_game, { onGameEnd = show })
  local userLocaleName = g_settings.get('locale', 'en')
  changeClientLanguage(userLocaleName, true)
  setLocale(userLocaleName, true)
    --connect(g_app, { onRun = createWindow })
end

function terminate()
  disconnect(g_game, { onGameStart = hide })
  disconnect(g_game, { onGameEnd = show })

  g_effects.cancelFade(background:getChildById('clientVersionLabel'))
  background:destroy()

  -- O box e' filho do rootWidget, nao do background: sem isto ele sobrevive ao terminate do modulo
  -- e fica orfao na tela depois de um reload.
  if localeErrorBox then
    localeErrorBox:destroy()
  end

  Background = nil
end

function hide()
  background:hide()
  if g_discord ~= nil then
    g_discord.update()
  end
end

function show()
  background:show()
  if g_discord ~= nil then
    g_discord.update()
  end
end

function hideVersionLabel()
  background:getChildById('clientVersionLabel'):hide()
end

function setVersionText(text)
  clientVersionLabel:setText(text)
end

function getBackground()
  return background
end

function updateLanguageWidget(widgetId, countryName, iconPath)
  local widget = background.language:getChildById(widgetId)
  if not widget then
    return
  end

  local countryLabel = widget:getChildById('countryName')
  if countryLabel then
    countryLabel:setText(countryName)
  end

  local countryIcon = widget:getChildById('countryIcon')
  if countryIcon then
    countryIcon:setImageSource(iconPath)
  end
end

function changeClientLanguage(language, first)
  local widget = background.language:getChildById(language)
  if widget then
    widget:focus()
    widget.selectConfirm:show()
    widget.countryName:setColoredText({widget.countryName:getText(), "#2ea2f8"})
  end

  if not first then
    -- So destroi o que ainda esta aberto. O botao Ok do proprio box ja o destroi
    -- (UIMessageBox:ok -> destroy), e a referencia daqui continuava apontando para o widget morto --
    -- na troca de idioma seguinte este destroy era o SEGUNDO do mesmo widget, que e' o
    -- "attempt to destroy widget two times" no log.
    if localeErrorBox then
      localeErrorBox:destroy()
    end

    localeErrorBox = displayErrorBox(tr('Change Language'), tr("Please reopen the client for the changes to take effect."))

    -- Zera a referencia por QUALQUER caminho de fechamento (Ok, Enter, Escape, destroy explicito),
    -- em vez de so depois do destroy acima. Mesmo padrao do channelsWindow em game_chat/chat.lua.
    localeErrorBox.onDestroy = function()
      localeErrorBox = nil
    end
  end
  return true
end

function setLocale(name, first)
  local locales = modules.client_locales.getInstalledLocales()
  local locale = locales[name]
  if locale == modules.client_locales.getCurrentLocale() then return end
  if not locale then
    pwarning("Locale " .. name .. ' does not exist.')
    return false
  end
  modules.client_locales.setCurrentLocale(locale)
  g_settings.set('locale', name)
  if onLocaleChanged then
    onLocaleChanged(name)
  end
  changeClientLanguage(name, first)
  return true
end

function getLanguageWindow()
  if not background then
    return nil
  end

  return background.language
end