local ConfirmWindow
local mainShopButton = nil
local mainShopWindow = nil
local marketCategories = nil
local searchEvent = nil
local pixWindow = nil
local creditCardWindow = nil
local paymentInFlight = false
local paymentTimeoutEvent = nil
local PAYMENT_TIMEOUT_MS = 15000
local Current = {items = {}, subCategorys = {}}
local ChangeNameWindow
local ConfirmPixWindow
local lastQRCode
local lastPaymentId = nil
local errorBox = nil
local playerDiamonds = 0
local accountDiamonds = 0
local balanceHidden = false

-- The eye buttons existed in the otui with no handler at all, so nothing was ever wired. Both hide
-- the two balances together: they sit one above the other and hiding only one reads as a bug.
local function balanceText(value)
    if balanceHidden then return '****' end
    return value
end

function isBalanceHidden()
    return balanceHidden
end

function refreshBalances()
    if not mainShopWindow then return end
    mainShopWindow.playerDiamonds:setText(balanceText(playerDiamonds))
    mainShopWindow.accountDiamonds:setText(balanceText(accountDiamonds))
end

function toggleBalanceHidden()
    balanceHidden = not balanceHidden
    g_settings.set('store-balance-hidden', balanceHidden)
    g_settings.save()
    refreshBalances()
end
local storeBuildGen = 0
local STORE_CHUNK_SIZE = 15

Store = {
    opcode = 26
}

modules.client_hotkeys.registerHotkeyCallback("GAME_SHOP",
  function(actionName, action, keyInfo, chatState, keyType)
    local callback = function()
      local chatModeEnabled = not modules.game_chat.consoleToggleChat
      local wantChat = (chatState == "chatEnabled")
      if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
        -- openDiamondShop e nao toggleTopButton: o botao da topbar agora abre um MENU de lojas,
        -- e abrir um menu de mouse por atalho de teclado obrigaria a largar o teclado. O atalho
        -- segue fazendo o que sempre fez -- abrir/fechar o Diamond Shop.
        openDiamondShop()
      end
    end
    return { callback = callback, widget = modules.game_interface.getRootPanel() }
  end)

-- Must be assigned to true _G so C++ callGlobalField("Payments", ...) can find it
-- (module-level assignments stay in the module sandbox, not _G).
_G.Payments = _G.Payments or {}

local PAYMENT_TOAST_DURATION_MS = 5000
local PAYMENT_TOAST_TICK_MS = 20
local PAYMENT_TOAST_GAP = 6      -- vertical gap between stacked toasts
local PAYMENT_TOAST_TOP_OFFSET = 20
local DIAMOND_CLIENT_ID = 3028

local activeToasts = {}
local toastCounter = 0

local function onGameEnd()
    playerDiamonds = 0
    accountDiamonds = 0
    lastPaymentId = nil
    activeToasts = {}
    hide()
end

local function _reanchorToasts()
    for i, t in ipairs(activeToasts) do
        if t and not t:isDestroyed() then
            t:removeAnchor(AnchorTop)
            if i == 1 then
                t:addAnchor(AnchorTop, 'parent', AnchorTop)
                t:setMarginTop(PAYMENT_TOAST_TOP_OFFSET)
            else
                t:addAnchor(AnchorTop, activeToasts[i-1]:getId(), AnchorBottom)
                t:setMarginTop(PAYMENT_TOAST_GAP)
            end
        end
    end
end

local function _destroyToast(toast)
    if not toast then return end
    for i, t in ipairs(activeToasts) do
        if t == toast then
            table.remove(activeToasts, i)
            break
        end
    end
    if not toast:isDestroyed() then
        toast:destroy()
    end
    _reanchorToasts()
end

local function _showPaymentToast(text, points)
    if modules.client_options and modules.client_options.getOption('ignorePaymentsAlerts') then
        return
    end
    local mapPanel = modules.game_interface and modules.game_interface.getMapPanel()
    if not mapPanel then return end

    toastCounter = toastCounter + 1
    local toast = g_ui.createWidget('PaymentToast', mapPanel)
    toast:setId('paymentToast_' .. toastCounter)
    toast:addAnchor(AnchorRight, 'parent', AnchorRight)
    toast:setMarginRight(20)

    if #activeToasts == 0 then
        toast:addAnchor(AnchorTop, 'parent', AnchorTop)
        toast:setMarginTop(PAYMENT_TOAST_TOP_OFFSET)
    else
        local prev = activeToasts[#activeToasts]
        toast:addAnchor(AnchorTop, prev:getId(), AnchorBottom)
        toast:setMarginTop(PAYMENT_TOAST_GAP)
    end
    table.insert(activeToasts, toast)

    local diamond = toast:getChildById('diamond')
    if diamond then
        diamond:setItemId(DIAMOND_CLIENT_ID)
        if points and points > 1 then
            diamond:setItemCount(points)
        end
    end
    local label = toast:getChildById('text')
    if label then label:setText(text) end

    local timer = toast:getChildById('timer')

    local closeBtn = toast:getChildById('closeButton')
    if closeBtn then
        closeBtn.onClick = function()
            _destroyToast(toast)
        end
    end

    g_effects.fadeIn(toast)

    local elapsed = 0
    local function tick()
        if not toast or toast:isDestroyed() then return end
        elapsed = elapsed + PAYMENT_TOAST_TICK_MS
        if timer and not timer:isDestroyed() then
            timer:setPercent(math.max(0, 100 - (elapsed / PAYMENT_TOAST_DURATION_MS) * 100))
        end
        if elapsed >= PAYMENT_TOAST_DURATION_MS then
            _destroyToast(toast)
        else
            scheduleEvent(tick, PAYMENT_TOAST_TICK_MS)
        end
    end
    scheduleEvent(tick, PAYMENT_TOAST_TICK_MS)
end

local function onPaymentCompleted(kind, paymentId, points)
    if kind == "buyer" then
        if ConfirmPixWindow and not ConfirmPixWindow:isDestroyed() and ConfirmPixWindow:isVisible() and tostring(lastPaymentId) == tostring(paymentId) then
            local qrcode = ConfirmPixWindow:getChildById("qrcode")
            local copyBtn = ConfirmPixWindow:getChildById("copy")
            local completedLbl = ConfirmPixWindow:getChildById("paymentCompleted")
            if qrcode then qrcode:hide() end
            if copyBtn then copyBtn:hide() end
            if completedLbl then completedLbl:show() end
            scheduleEvent(function()
                if ConfirmPixWindow and not ConfirmPixWindow:isDestroyed() then
                    ConfirmPixWindow:destroy()
                end
                ConfirmPixWindow = nil
            end, 5000)
            lastPaymentId = nil
        else
            _showPaymentToast(tr("Diamonds added to your account!"), points)
        end
    elseif kind == "streamer" then
        _showPaymentToast(tr("Coupon bonus added!"), points)
    end
end

function init()
    g_ui.importStyle('paymenttoast')

    connect(g_game, {
        onGameEnd = onGameEnd,
        onReceiveShopInfo = onReceiveShopInfo,
        onReceiveShopCategories = onReceiveShopCategories,
        onUpdateAccountDiamonds = onUpdateAccountDiamonds
    })

    connect(_G.Payments, {
        onCompleted = onPaymentCompleted
    })

    mainShopButton =
        modules.client_topmenu.addMiddleGameToggleButton(
        "storeButton",
        tr("Store") .. "",
        "/images/ui/topbuttons/icons/store",
        --toggle
        toggleTopButton
    )

    mainShopButton:setOn(false)
end

function terminate()
    disconnect(g_game, {
        onGameEnd = onGameEnd,
        onReceiveShopInfo = onReceiveShopInfo,
        onReceiveShopCategories = onReceiveShopCategories,
        onUpdateAccountDiamonds = onUpdateAccountDiamonds
    })

    disconnect(_G.Payments, {
        onCompleted = onPaymentCompleted
    })

    if ConfirmWindow then
        ConfirmWindow:destroy()
        ConfirmWindow = nil
    end
    hide()
    mainShopButton:destroy()
    mainShopButton = nil
    hideChangeNameOption()
end

function hide()
    storeBuildGen = storeBuildGen + 1
    hidePixWindow()
    hideCreditCardWindow()
    closeConfirmPixWindow()
    if mainShopWindow then
        g_uistates.remove(mainShopWindow)
        mainShopWindow:destroy()
        mainShopWindow = nil
    end
    if ConfirmWindow then
        ConfirmWindow:destroy()
        ConfirmWindow = nil
    end
    modules.game_walking.enableClientWalk()
    if searchEvent then
        removeEvent(searchEvent)
        searchEvent = nil
    end
end

-- O botao Store nao abre mais o Diamond Shop direto: abre um menu com as tres lojas.
-- Cada entrada e opcional — modulo nao carregado simplesmente nao aparece, em vez de estourar.
local function getShopMenuEntries()
    local entries = {
        {
            id = 'diamondShopEntry',
            tooltip = tr('Diamond Shop'),
            icon = '/images/ui/topbuttons/icons/diamond_shop',
            callback = openDiamondShop
        }
    }

    if modules.game_onlineshop then
        table.insert(entries, {
            id = 'onlinePointsEntry',
            tooltip = tr('Online Shop'),
            icon = '/images/ui/topbuttons/icons/online_shop',
            callback = function() modules.game_onlineshop.toggleTopButton() end
        })
    end

    if modules.game_twitchshop then
        table.insert(entries, {
            id = 'twitchShopEntry',
            tooltip = tr('Twitch Shop'),
            icon = '/images/ui/topbuttons/icons/twitch_shop',
            callback = function() modules.game_twitchshop.toggle() end
        })
    end

    return entries
end

function openDiamondShop()
    if mainShopWindow then
        hide()
        return
    end

    requestStoreItems("Exclusives")
end

function toggleTopButton()
    -- Loja ja aberta: o botao fecha, sem passar pelo menu (mesmo gesto de antes para sair).
    if mainShopWindow then
        modules.client_topmenu.hideButtonMenu()
        hide()
        return
    end

    modules.client_topmenu.toggleButtonMenu('storeButton', getShopMenuEntries())
end

function showHistoric()
    g_game.requestShopCategory("historic")
end

function requestStoreItems(category)
    g_game.requestShopCategory(category)
end

-- Preço unitário efetivo: promocional enquanto o servidor a enviar (ele zera promo expirada
-- na serialização e cobra pela mesma regra — o cliente só espelha o que veio no catálogo).
local function effectiveUnitPrice(item)
    if item.promoPrice and item.promoPrice > 0 then
        return item.promoPrice
    end
    return item.price or 0
end

local function itemHasPromo(item)
    return item.promoPrice and item.promoPrice > 0 and item.price and item.price > item.promoPrice
end

-- Tempo restante da promoção: só a maior unidade (11d → 4h → 12m)
local function formatPromoTimeLeft(seconds)
    local days = math.floor(seconds / 86400)
    if days > 0 then
        return string.format("%dd", days)
    end
    local hours = math.floor(seconds / 3600)
    if hours > 0 then
        return string.format("%dh", hours)
    end
    return string.format("%dm", math.max(math.floor(seconds / 60), 1))
end

-- Detalhamento completo pro tooltip (11d 3h 42m)
local function formatPromoTimeLeftFull(seconds)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local parts = {}
    if days > 0 then parts[#parts + 1] = days .. "d" end
    if hours > 0 then parts[#parts + 1] = hours .. "h" end
    if minutes > 0 then parts[#parts + 1] = minutes .. "m" end
    if #parts == 0 then parts[1] = "<1m" end
    return table.concat(parts, " ")
end

function onAmountChange()
    if not ConfirmWindow then
        return
    end
    local value = ConfirmWindow.amountSpinner.field:getValue()
    local item = ConfirmWindow.item
    ConfirmWindow:recursiveGetChildById("price"):setText(effectiveUnitPrice(item) * value)
    local oldW = ConfirmWindow:recursiveGetChildById("oldPrice")
    if oldW and oldW:isVisible() then
        oldW:setText(item.price * value)
    end
end

-- ===== Prévia de animações no Buy Confirm (Taunt / Idle / Transformação) =====
-- Pills clicáveis (mesmo estilo do card) que tocam a animação na própria sprite do confirm:
-- idle/tauntSeq via player nativo de outfit sequence (opcode 1571, mesmos mecanismos do jogo),
-- tauntAnim via overlay de animação, transformação ciclando os lookTypes. Clicar de novo para.
local PREVIEW_DEFS = {
    { key = "walk",      label = "Walk",    color = "#4dd07a", has = function(anims) return true end },
    { key = "taunt",     label = "Taunt",   color = "#f5b942", has = function(anims) return anims.tauntSeq ~= nil or anims.tauntAnim ~= nil end },
    { key = "idle",      label = "Idle",    color = "#8fd4ff", has = function(anims) return anims.idle ~= nil end },
    { key = "transform", label = "Transf.", color = "#c97bff", has = function(anims) return anims.transforms ~= nil end },
}

local function confirmPreviewCreature()
    if not ConfirmWindow then
        return nil
    end
    local ow = ConfirmWindow:getChildById("outfit")
    if not ow then
        return nil
    end
    return ow:getCreature(), ow
end

local function stopConfirmPreview()
    if not ConfirmWindow then
        return
    end
    ConfirmWindow.previewGen = (ConfirmWindow.previewGen or 0) + 1
    ConfirmWindow.activePreview = nil
    local creature, ow = confirmPreviewCreature()
    if creature then
        creature:cancelOutfitSequence()
        creature:setStaticWalking(false)
    end
    if ow then
        ow:setAnimate(false)
        if ConfirmWindow.baseOutfit then
            ow:setOutfit(ConfirmWindow.baseOutfit)
        end
    end
end

-- Agenda um passo amarrado à janela/geração atuais: troca de aba, reopen ou destroy invalidam
-- o closure — nada roda em cima de janela morta ou prévia trocada.
local function schedulePreviewStep(delay, fn)
    local win, gen = ConfirmWindow, ConfirmWindow.previewGen
    scheduleEvent(function()
        if win ~= ConfirmWindow or win:isDestroyed() or win.previewGen ~= gen then
            return
        end
        fn()
    end, delay)
end

local function normalizedSteps(steps)
    -- duration 0 no data = "segura até mover" (idle) — na prévia vira pausa visível no loop
    local out = {}
    for _, step in ipairs(steps) do
        out[#out + 1] = { lookType = step.lookType, duration = (step.duration and step.duration > 0) and step.duration or 900 }
    end
    return out
end

local function playConfirmPreview(key)
    stopConfirmPreview()
    if not ConfirmWindow then
        return
    end
    local anims = ConfirmWindow.item.anims or {}
    local creature, ow = confirmPreviewCreature()
    if not creature or not ow then
        return
    end

    ConfirmWindow.activePreview = key
    -- animate (computação de fase do outfit) só quando a prévia pede: walk = sempre; sequências =
    -- durante os frames (desligado nas PAUSAS, senão o look base fica andando no meio do taunt);
    -- transformação = formas estáticas.

    if key == "walk" then
        -- fase de walk REAL (frames de andar, mesma matemática do mapa) — o setAnimate sozinho
        -- só cicla o idle animator (era o "primeiro frame sempre")
        creature:setStaticWalking(true)
    elseif key == "idle" and anims.idle then
        ow:setAnimate(true) -- loop contínuo, sem pausas
        creature:startOutfitSequence(normalizedSteps(anims.idle), 0) -- 0 = loop
    elseif key == "taunt" and (anims.tauntSeq or anims.tauntAnim) then
        if anims.tauntSeq then
            local steps = normalizedSteps(anims.tauntSeq)
            local total = 0
            for _, step in ipairs(steps) do
                total = total + step.duration
            end
            local function playOnce()
                local c, w = confirmPreviewCreature()
                if not c then return end
                w:setAnimate(true)
                c:startOutfitSequence(steps, 1) -- 1 = revert (volta ao look base no fim)
                schedulePreviewStep(total, function()
                    local _, w2 = confirmPreviewCreature()
                    if w2 then w2:setAnimate(false) end -- pausa: look base parado, sem walk
                end)
                schedulePreviewStep(total + 800, playOnce)
            end
            playOnce()
        else
            local animId, duration = anims.tauntAnim.id, math.max(anims.tauntAnim.duration or 0, 300)
            local function playOnce()
                local c, w = confirmPreviewCreature()
                if not c then return end
                w:setAnimate(true)
                c:setAnimation(animId, 0, duration)
                schedulePreviewStep(duration, function()
                    local _, w2 = confirmPreviewCreature()
                    if w2 then w2:setAnimate(false) end -- pausa: look base parado, sem walk
                end)
                schedulePreviewStep(duration + 800, playOnce)
            end
            playOnce()
        end
    elseif key == "transform" and anims.transforms then
        local base = ConfirmWindow.baseOutfit
        local cycle = { base.type }
        for _, lookType in ipairs(anims.transforms) do
            cycle[#cycle + 1] = lookType
        end
        local index = 0
        local function nextForm()
            index = (index % #cycle) + 1
            -- preserva as cores do outfit base em cada forma do ciclo; formas estáticas
            ow:setOutfit({ type = cycle[index], head = base.head, body = base.body, legs = base.legs, feet = base.feet })
            schedulePreviewStep(900, nextForm)
        end
        nextForm()
    end
end

local function buildConfirmAnimTabs(item)
    local tabsPanel = ConfirmWindow:getChildById("animTabs")
    if not tabsPanel then
        return
    end
    tabsPanel:destroyChildren()
    if not item.lookType or item.lookType == 0 then
        return
    end
    local anims = item.anims or {} -- walk existe pra todo outfit; as demais dependem do catálogo

    -- pills do confirm: branco por padrão, azul de seleção do cliente quando ativa
    -- (as cores por tipo ficam só nas barras do card)
    local TAB_IDLE_COLOR, TAB_ACTIVE_COLOR = "#ffffff", "#0089ff"

    local tabs = {}
    local function refreshTabColors()
        for _, entry in ipairs(tabs) do
            if ConfirmWindow.activePreview == entry.def.key then
                entry.widget:setColor(TAB_ACTIVE_COLOR)
            else
                entry.widget:setColor(TAB_IDLE_COLOR)
            end
        end
    end

    for _, def in ipairs(PREVIEW_DEFS) do
        if def.has(anims) then
            local tab = g_ui.createWidget('StoreAnimBar', tabsPanel)
            tab:setText(tr(def.label))
            tab:setColor(TAB_IDLE_COLOR)
            tab:setPhantom(false)
            tab.onClick = function()
                if ConfirmWindow.activePreview == def.key then
                    stopConfirmPreview() -- clicar na ativa = parar (volta ao look normal)
                else
                    playConfirmPreview(def.key)
                end
                refreshTabColors()
            end
            tabs[#tabs + 1] = { widget = tab, def = def }
        end
    end
end

function closeConfirmWindow()
    if ConfirmWindow then
        stopConfirmPreview()
        ConfirmWindow:destroy()
        ConfirmWindow = nil
    end
end

function buyItem()
    if not ConfirmWindow then
        return
    end

    local category = ConfirmWindow.item.category
    local id = ConfirmWindow.item.id
    local amount = ConfirmWindow.amountSpinner.field:getValue()

    if not category or not id or not amount then
        return
    end

    -- eco do preço unitário exibido: servidor recusa se o efetivo na hora for maior (promo expirada)
    g_game.buyShopItem(category, id, amount, effectiveUnitPrice(ConfirmWindow.item))
    closeConfirmWindow()
end

local CONFIRM_HEIGHT_ITEM = 250
local CONFIRM_HEIGHT_OUTFIT = 306

function showBuyConfirm(widget)
    if not mainShopWindow then
        return
    end

    if ConfirmWindow then
        ConfirmWindow:destroy()
    end

    ConfirmWindow = g_ui.loadUI("confirm", modules.game_interface.getRootPanel())

    ConfirmWindow.item = widget.item
    ConfirmWindow.previewGen = 0

    local amountField = ConfirmWindow.amountSpinner.field
    amountField.onValueChange = onAmountChange
    amountField:setMinimum(1)
    if widget.item.limit and widget.item.limit ~= 0 then
        amountField:setMaximum(widget.item.limit)
    else
        amountField:setMaximum(100)
    end
    amountField:setValue(1)
    ConfirmWindow:getChildById("name"):setText(widget.item.name)
    ConfirmWindow:recursiveGetChildById("price"):setText(effectiveUnitPrice(widget.item))
    if itemHasPromo(widget.item) then
        ConfirmWindow:recursiveGetChildById("price"):setColor("#4dd07a")
        local oldW = ConfirmWindow:recursiveGetChildById("oldPrice")
        if oldW then
            oldW:setText(widget.item.price)
            oldW:setMarginRight(2)
            oldW:show()
        end
        local strikeW = ConfirmWindow:recursiveGetChildById("oldPriceStrike")
        if strikeW then strikeW:show() end
    end
    if widget.item.lookType and widget.item.lookType > 0 then
        local outfitvar = {type = widget.item.lookType}
        if widget.item.lookHead then
            outfitvar.head = widget.item.lookHead
        end
        if widget.item.lookBody then
            outfitvar.body = widget.item.lookBody
        end
        if widget.item.lookLegs then
            outfitvar.legs = widget.item.lookLegs
        end
        if widget.item.lookFeet then
            outfitvar.feet = widget.item.lookFeet
        end
        ConfirmWindow.baseOutfit = outfitvar
        widget:getChildById("outfit"):setOutfit(outfitvar)
        ConfirmWindow:getChildById("outfit"):setOutfit(outfitvar)
        ConfirmWindow:getChildById("outfit"):show()
        ConfirmWindow:getChildById("item"):hide()
    else
        ConfirmWindow:getChildById("item"):setItemId(widget.item.clientId)
        ConfirmWindow:getChildById("item"):show()
        ConfirmWindow:getChildById("outfit"):hide()
    end
    if widget.item.image then
        ConfirmWindow:getChildById("item"):setImageSource(widget.item.image)
    end

    buildConfirmAnimTabs(widget.item)

    local hasOutfit = widget.item.lookType ~= nil and widget.item.lookType > 0
    ConfirmWindow:setHeight(hasOutfit and CONFIRM_HEIGHT_OUTFIT or CONFIRM_HEIGHT_ITEM)

    ConfirmWindow:show()
    ConfirmWindow:raise()
    ConfirmWindow:focus()
    ConfirmWindow:setupModal(closeConfirmWindow)
end

function openWithdrawPanel()
    local withdrawWindow = mainShopWindow and mainShopWindow:getChildById('withdraw_panel')
    if not withdrawWindow then
        return
    end
    depositPanelClose()
    withdrawWindow:show()
    withdrawWindow.points:setText(accountDiamonds)
    withdrawWindow:focus()
end

function openDepositPanel()
    local depositWindow = mainShopWindow and mainShopWindow:getChildById('deposit_panel')
    if not depositWindow then
        return
    end
    playerDiamonds = modules.game_playeractionbar.getPlayerItemCount(3028)
    depositWindow.points:setText(playerDiamonds)
    withdrawPanelClose()
    depositWindow:show()
    depositWindow:focus()
end

function openDonatePixPanel()
    if not pixWindow then
        pixWindow = g_ui.loadUI("donatepix", mainShopWindow)
    end
    pixWindow:focus()
end

function openDonateCreditCardPanel()
    if not creditCardWindow then
        creditCardWindow = g_ui.loadUI("donatecreditcard", mainShopWindow)
    end
    creditCardWindow:focus()
end

-- Lock global pra evitar duplo-clique enviar 2 pagamentos seguidos.
-- Solta automaticamente quando o servidor responde, ou apos PAYMENT_TIMEOUT_MS
-- caso a request trave (rede caiu, servidor lento, etc.).
local function lockPayment()
    if paymentInFlight then return false end
    paymentInFlight = true
    if paymentTimeoutEvent then
        removeEvent(paymentTimeoutEvent)
    end
    paymentTimeoutEvent = scheduleEvent(function()
        paymentInFlight = false
        paymentTimeoutEvent = nil
    end, PAYMENT_TIMEOUT_MS)
    return true
end

local function unlockPayment()
    paymentInFlight = false
    if paymentTimeoutEvent then
        removeEvent(paymentTimeoutEvent)
        paymentTimeoutEvent = nil
    end
end

local function onHTTPResult(data, err)
    unlockPayment()
    if not data.success then
        displayInfoBox(tr("Pix Error"), data.message)
        return
    end

    hidePixWindow()
    if ConfirmPixWindow then
        ConfirmPixWindow:destroy()
    end

    ConfirmPixWindow = g_ui.loadUI("confirmpix", mainShopWindow)
    ConfirmPixWindow.qrcode:setImageSourceBase64(data.qrcode)
    ConfirmPixWindow.copyPaste:setText(data.copypaste)
    ConfirmPixWindow:show()
    ConfirmPixWindow:focus()
    lastQRCode = os.time()
    lastPaymentId = data.payment_id
end

local function onCreditCardHTTPResult(data, err)
    unlockPayment()
    if not data.success then
        displayInfoBox(tr("Credit Card Error"), data.message)
        return
    end

    hideCreditCardWindow()
    if data.checkout_url then
        g_platform.openUrl(data.checkout_url)
    end
end

function closeConfirmPixWindow()
    if not ConfirmPixWindow then
        return
    end
    ConfirmPixWindow:destroy()
    ConfirmPixWindow = nil
end


function hidePixWindow()
    if not pixWindow then
        return
    end

    pixWindow:destroy()
    pixWindow = nil
end

function hideCreditCardWindow()
    if not creditCardWindow then
        return
    end

    creditCardWindow:destroy()
    creditCardWindow = nil
end

function sendDonateHttp()
    local countText = pixWindow.quantidadeEdit:getText()
    local count = countText and tonumber(countText) or nil
    if not count then
        return
    end

    if not lockPayment() then
        return
    end

    local localPlayer = g_game.getLocalPlayer()
    if not localPlayer then
        return
    end

    local data = {
        account = G.account,
        email = pixWindow.emailEdit:getText(),
        cpf = pixWindow.cpfEdit:getText(),
        quantity = count,
        coupon = pixWindow.cupomEdit:getText()
    }

    HTTP.postJSON(Services.apiPix.."/client-pix", data, onHTTPResult)
end

function sendDonateCreditCardHttp()
    if not creditCardWindow then return end

    local countText = creditCardWindow.quantidadeEdit:getText()
    local count = countText and tonumber(countText) or nil
    if not count then
        return
    end

    if not lockPayment() then
        return
    end

    local data = {
        account = G.account,
        quantity = count,
        coupon = creditCardWindow.cupomEdit:getText()
    }

    HTTP.postJSON(Services.apiPix.."/client-card", data, onCreditCardHTTPResult)
end

function sendWithdrawRequest()
    local withdrawWindow = mainShopWindow:getChildById('withdraw_panel')
    if not withdrawWindow then
        return
    end
    if errorBox then
        return
    end

    local countInput = withdrawWindow:recursiveGetChildById('count')
    local count = tonumber(countInput:getText())
    if not count then
        errorBox = displayErrorBox(tr("Error"), "Please enter a valid number.")
        errorBox.onOk = function()
            errorBox = nil
        end
        return
    end
    if count > accountDiamonds then
        errorBox = displayErrorBox(tr("Error"), "You don't have that amount of Diamonds in your Account.")
        errorBox.onOk = function()
            errorBox = nil
        end
        return
    end
    
    g_game.sendWithdrawRequest(count)
    
    withdrawWindow:hide()
end

function sendDepositRequest()
    local depositWindow = mainShopWindow:getChildById('deposit_panel')
    if not depositWindow then
        return
    end
    if errorBox then
        return
    end
    local countInput = depositWindow:recursiveGetChildById('count')
    local count = tonumber(countInput:getText())
    if not count then
        errorBox = displayErrorBox(tr("Error"), "Please enter a valid number.")
        errorBox.onOk = function()
            errorBox = nil
        end
        return
    end

    if count > playerDiamonds then
        errorBox = displayErrorBox(tr("Error"), "You don't have that amount of Diamonds in your Character.")
        errorBox.onOk = function()
            errorBox = nil
        end
        return
    end

    g_game.sendDepositRequest(count)
    depositWindow:hide()
end

function withdrawPanelClose()
    local withdrawWindow = mainShopWindow and mainShopWindow:getChildById('withdraw_panel')
    if not withdrawWindow then
        return
    end
    withdrawWindow:hide()
end

function depositPanelClose()
    local depositWindow = mainShopWindow and mainShopWindow:getChildById('deposit_panel')
    if not depositWindow then
        return
    end
    depositWindow:hide()
end

function showChangeNameOption()
    ChangeNameWindow = g_ui.loadUI("changename", mainShopWindow)
    ChangeNameWindow:focus()
    ChangeNameWindow:show()
    local chatModeEnabled = modules.game_chat.consoleToggleChat
    if chatModeEnabled then
        modules.game_walking.disableWSAD()
    end
end

function hideChangeNameOption()
    if ChangeNameWindow then
        ChangeNameWindow:destroy()
        ChangeNameWindow = nil
    end
    local chatModeEnabled = modules.game_chat.consoleToggleChat
    if chatModeEnabled then
        modules.game_walking.enableWSAD()
    end
end

function confirmChangeName()
    local newName = ChangeNameWindow.changeNameTextEdit:getText()
    if newName and newName ~= "" then
        g_game.changeName(newName)
    end
    hideChangeNameOption()
end

function copyQrCode()
    g_window.setClipboardText(ConfirmPixWindow.copyPaste:getText())
end

local function buildShopCategories()
    local catPanel = mainShopWindow and mainShopWindow.categoryPanel
    if not catPanel then return end
    
    catPanel:destroyChildren()
    if not marketCategories then
        return
    end

    local catLayout = catPanel:getLayout()
    if catLayout then catLayout:disableUpdates() end
    catPanel:beginBatchAdd()

    for _, config in ipairs(marketCategories.categories) do
        local name = config.key
        local id = name:lower()
        local btn = g_ui.createWidget("StoreCategory", catPanel)
        btn:setId(id)
        btn.category_name:setText(name)
        btn.category_icon:setImageSource("icons/category_"..config.iconId)
        
        if Current.category == name then
            btn:setImageSource("/images/modules/store_ui/category_selected")
            local subcategories = config.subcategories or {}
            local categoryName = subcategories[1] and subcategories[1].name or name
            mainShopWindow.itemPanel.subcategoriesButton:setText(name)
            mainShopWindow.itemPanel.title_background.categoryIcon:setImageSource("icons/title_"..config.iconId)
            mainShopWindow.itemPanel.title_background.categoryTitle:setText(tr(name))
            mainShopWindow.itemPanel.title_background.categoryTitle:setColoredText({tr(name), config.titleColor})
            mainShopWindow.itemPanel.title_background.categoryDescription:setText(tr(config.desc))
            mainShopWindow.itemPanel.subcategoriesButton.onClick = function()
                local menu = g_ui.createWidget("AlliancePopupMenu")
                menu:setGameMenu(true)
                menu:addOption(name, function()
                    mainShopWindow.itemPanel.subcategoriesButton:setText(name)
                    applySubCategory(name)
                end)

                for _, configCategories in ipairs(config.subcategories) do
                    menu:addOption(configCategories.name, function()
                        mainShopWindow.itemPanel.subcategoriesButton:setText(configCategories.name)
                        applySubCategory(configCategories.name)
                    end)
                end
                local position = mainShopWindow.itemPanel.subcategoriesButton:getPosition()
                position.y = position.y + mainShopWindow.itemPanel.subcategoriesButton:getHeight()
                menu:display(position)
            end          
        end
        
        btn.onClick = function()
            if Current.category == name then
                return
            end
        
            requestStoreItems(name)
        end
    end

    catPanel:endBatchAdd()
    if catLayout then
        catLayout:enableUpdates()
        catLayout:update()
    end
end

function onReceiveShopInfo(shopInfo)
    if not mainShopWindow then
        mainShopWindow = g_ui.loadUI("store", modules.game_interface.getRootPanel())
        modules.game_walking.disableClientWalk()

        -- keyboard grab: hotkeys and walking keys stay dead while the store is open, and
        -- Escape reaches the window instead of the game. The sub-panels are children, so
        -- the grab covers them too once they take focus.
        g_uistates.push(mainShopWindow)

        -- a diamond amount is digits or nothing: tonumber() on the way out already
        -- rejected the rest, but only after the player had typed it
        for _, id in ipairs({ 'withdraw_panel', 'deposit_panel' }) do
            local field = mainShopWindow:getChildById(id):recursiveGetChildById('count')
            if field then field:setValidCharacters('0123456789') end
        end
    end

    mainShopWindow.itemPanel.searchShopItem:setText("")

    local category = shopInfo.category
    Current.category = category

    buildShopCategories()

    balanceHidden = g_settings.getBoolean('store-balance-hidden', false)
    playerDiamonds = modules.game_playeractionbar.getPlayerItemCount(3028)
    refreshBalances()

    local panel = mainShopWindow.itemPanel.itemShopPanel
    if not panel then return end

       -- armazenar info útil
    Current.serverTimestamp = shopInfo.timestamp
    Current.playerSex       = shopInfo.playerSex -- pode ser nil

    panel:destroyChildren()

    -- Cancel any in-flight chunk creation from previous call
    storeBuildGen = storeBuildGen + 1
    local currentGen = storeBuildGen

    -- Pre-build flat filtered item list
    local itemList = {}

    for id, item in ipairs(shopInfo.items) do
        item.id = id
        item.category = category
        if category ~= "Outfits" or (shopInfo.playerSex == nil) or (item.gender == shopInfo.playerSex) then
          itemList[#itemList + 1] = item
        end
    end

    local total = #itemList
    if total == 0 then return end

    local layout = panel:getLayout()
    if layout then layout:disableUpdates() end
    panel:beginBatchAdd()

    local startIdx = 1

    local function buildNextStoreChunk()
        if storeBuildGen ~= currentGen then return end

        local endIdx = math.min(startIdx + STORE_CHUNK_SIZE - 1, total)
        for i = startIdx, endIdx do
            local item = itemList[i]

            local widget = g_ui.createWidget("StoreWidget", panel)

            widget._nameLower = (item.name or ""):lower()

            widget._haystack = ((item.name or ""):lower())
                       .. "\n" .. ((item.desc or ""):lower())
                       .. "\n" .. ((item.subcategory or ""):lower())

            if item.name == "Change Name" then
              widget.buyWidget.onClick = function() showChangeNameOption() end
            else
                widget.buyWidget.onClick = function()
                    showBuyConfirm(widget)
                end
            end

            if item.enable == 1 then
              widget:setEnabled(false)
            end

            local nameW = widget:getChildById("name")
            if nameW then
              nameW:setText(item.name or "")
              nameW:setHeight(27)
            end
            widget:setTooltip(item.desc or "")

            local priceText = (item.price and item.price > 0) and tostring(item.price) or 0
            if priceText == 0 and widget.label then
              widget.label:show()
              widget.label:setImageSource("/images/modules/store_ui/free")
            end
            local priceW = widget:recursiveGetChildById("price")
            if priceW then priceW:setText(priceText) end

            local clockIcon = widget:getChildById("clockIcon")
            if clockIcon then
              clockIcon:hide()
            end

            -- promoção: preço original riscado em cinza + promocional em dourado do lado
            if itemHasPromo(item) then
              if priceW then
                priceW:setText(item.promoPrice)
                priceW:setColor("#4dd07a")
                priceW:setMarginLeft(4)
              end
              local oldW = widget:recursiveGetChildById("oldPrice")
              if oldW then
                oldW:setText(item.price)
                oldW:setMarginLeft(3)
                oldW:show()
              end
              local strikeW = widget:recursiveGetChildById("oldPriceStrike")
              if strikeW then strikeW:show() end

              -- tempo restante da promoção (canto superior direito, mesmo pill das barras);
              -- referência = timestamp do SERVIDOR no envio do catálogo (imune a fuso do cliente)
              local timeLeftW = widget:getChildById("promoTimeLeft")
              if timeLeftW and item.promoUntil and item.promoUntil > 0 then
                local remaining = item.promoUntil - (Current.serverTimestamp or os.time())
                if remaining > 0 then
                  timeLeftW:setText(formatPromoTimeLeft(remaining))
                  timeLeftW:setTooltip(tr("Promotion ends in %s", formatPromoTimeLeftFull(remaining)))
                  timeLeftW:show()
                  if clockIcon then
                    clockIcon:show()
                  end
                end
              end
            end

            -- lupa acima do nome: hover lista as animações que o outfit tem
            local lensW = widget:getChildById("animLens")
            if lensW and item.anims and item.lookType and item.lookType > 0 then
              local lines = {}
              if (item.anims.tauntSeq ~= nil) or (item.anims.tauntAnim ~= nil) then
                lines[#lines + 1] = tr("Has Taunt")
              end
              if item.anims.transforms ~= nil then
                lines[#lines + 1] = tr("Has Transformation")
              end
              if item.anims.idle ~= nil then
                lines[#lines + 1] = tr("Has Idle")
              end
              if #lines > 0 then
                lensW:setTooltip(table.concat(lines, "\n"))
                lensW:show()
              end
            end

            local hasOutfit = (item.lookType ~= nil and item.lookType > 0)
            local hasImage  = (item.image ~= nil and item.image ~= "")
            if hasOutfit then
              local outfitvar = { type = item.lookType }
              if item.lookHead then outfitvar.head = item.lookHead end
              if item.lookBody then outfitvar.body = item.lookBody end
              if item.lookLegs then outfitvar.legs = item.lookLegs end
              if item.lookFeet then outfitvar.feet = item.lookFeet end

              local ow = widget:getChildById("outfit")
              if ow then
                ow:setOutfit(outfitvar)
                ow:show()
              end
            elseif hasImage then
              local iw = widget:getChildById("item")
              if iw then
                iw:setImageSource(item.image)
                iw:show()
              end
            else
              local iw = widget:getChildById("item")
              if iw then
                iw:setItemId(item.clientId or 0)
                iw:setItemCount(item.count or 1)
                iw:setShowCount(false)
                iw:show()
              end
            end

            if item.limit ~= nil then
              local infoW = widget:getChildById("info")
              if infoW then
                if item.limit <= 0 then
                  infoW:setText(tr("sold out"))
                else
                  if item.limit > 1 then
                    infoW:setText(tr("%d remaining", item.limit))
                  else
                    infoW:setText(tr("%d remaining (singular)", item.limit))
                  end
                end
              end
            end
            widget.item = item
        end

        startIdx = endIdx + 1
        if startIdx <= total then
            scheduleEvent(buildNextStoreChunk, 10)
        else
            panel:endBatchAdd()
            if layout then
              layout:enableUpdates()
              layout:update()
            end
        end
    end

    scheduleEvent(buildNextStoreChunk, 10)
end

function onReceiveShopCategories(categories)
    marketCategories = categories
end

local function tokenize(q)
  local tokens = {}
  for w in (q or ""):gmatch("%S+") do
    tokens[#tokens+1] = w:lower()
  end
  return tokens
end

local function applyVisibilityByFlags(panel)
  for _, child in ipairs(panel:getChildren()) do
    local a = (child._matchSubcat ~= false)  -- default true
    local b = (child._matchText   ~= false)  -- default true
    child:setVisibleBatched(a and b)
  end
  panel:finishBatchVisibility()
end

local function getCurrentSearchText()
  if not mainShopWindow then return "" end
  local w = mainShopWindow.itemPanel.searchShopItem
  return (w and w:getText()) or ""
end


function onSearchTextChange(text)
  if not mainShopWindow then return end
  local panel = mainShopWindow.itemPanel and mainShopWindow.itemPanel.itemShopPanel
  if not panel then return end

  if searchEvent then removeEvent(searchEvent) end
  local q = (text or ""):lower()
  local tokens = tokenize(q)

  searchEvent = scheduleEvent(function()
    if q == "" or #tokens == 0 then
      -- tudo casa com o texto
      for _, child in ipairs(panel:getChildren()) do
        child._matchText = true
      end
      applyVisibilityByFlags(panel)
      return
    end

    for _, child in ipairs(panel:getChildren()) do
      local hay = child._haystack or ""
      local ok = true
      for i = 1, #tokens do
        if not hay:find(tokens[i], 1, true) then ok = false; break end
      end
      child._matchText = ok
    end
    applyVisibilityByFlags(panel)
  end, 80)
end

function applySubCategory(subcatName)
  if not mainShopWindow then return end
  local panel = mainShopWindow.itemPanel and mainShopWindow.itemPanel.itemShopPanel
  if not panel then return end

  -- sem filtro se for vazio/"all" OU igual ao nome da categoria atual
  local s = subcatName or ""
  local noFilter = (s == "" or s == "all" or s == Current.category)

  for _, child in ipairs(panel:getChildren()) do
    local itemSub = child.item and child.item.subcategory or ""
    child._matchSubcat = noFilter or (itemSub == s)
  end

  -- reaplica o filtro de texto atual (AND com subcategoria)
  local search = mainShopWindow.itemPanel.searchShopItem
  local q = (search and search:getText()) or ""
  onSearchTextChange(q)
end

function onUpdateDiamondCount(count)
    playerDiamonds = count
    if not mainShopWindow then
        return
    end
    if mainShopWindow:isVisible() then
        mainShopWindow.playerDiamonds:setText(balanceText(count))
    end
    local depositWindow = mainShopWindow.deposit_panel
    if depositWindow and depositWindow:isVisible() then
        depositWindow.points:setText(count)
    end
end

function onUpdateAccountDiamonds(count)
    accountDiamonds = count
    if not mainShopWindow then
        return
    end

    if mainShopWindow:isVisible() then
        mainShopWindow.accountDiamonds:setText(balanceText(count))
    end
    local withdrawWindow = mainShopWindow.withdraw_panel
    if withdrawWindow and withdrawWindow:isVisible() then
        withdrawWindow.points:setText(count)
    end
end