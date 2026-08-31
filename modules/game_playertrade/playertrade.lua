tradeWindow = nil

-- Margem do canto inferior direito onde a janela nasce na primeira vez.
local FLOAT_MARGIN = 12

function init()
  g_ui.importStyle('tradewindow')

  connect(g_game, { onOwnTrade = onGameOwnTrade,
                    onCounterTrade = onGameCounterTrade,
                    onCloseTrade = onGameCloseTrade,
                    onGameEnd = onGameCloseTrade })
end

function terminate()
  disconnect(g_game, { onOwnTrade = onGameOwnTrade,
                       onCounterTrade = onGameCounterTrade,
                       onCloseTrade = onGameCloseTrade,
                       onGameEnd = onGameCloseTrade })

  if tradeWindow then
    tradeWindow:destroy()
    tradeWindow = nil
  end
end

-- Só na PRIMEIRA vez: sem posição salva, nasce no canto inferior direito. Depois disso a posição
-- que o jogador escolheu manda (o setup() a restaura), que é o comportamento esperado de janela
-- flutuante.
local function placeTradeWindowIfUnplaced()
  if tradeWindow:getSettings('position') then
    return
  end

  local layer = tradeWindow:getParent()
  if not layer then
    return
  end

  local layerRect = layer:getRect()
  tradeWindow:setPosition({
    x = layerRect.x + layerRect.width - tradeWindow:getWidth() - FLOAT_MARGIN,
    y = layerRect.y + layerRect.height - tradeWindow:getHeight() - FLOAT_MARGIN,
  })
end

function createTrade()
  -- FLUTUANTE, não no painel direito. Motivo não é estética: dentro de um UIMiniWindowContainer a
  -- janela fica ao alcance do fitAll(), que fecha filhos quando o painel transborda
  -- (uiminiwindowcontainer.lua:112) — e close() dispara o onClose daqui, que cancela o trade DE
  -- VERDADE. Fora do container esse caminho deixa de existir.
  --
  -- Não precisa de forceOpen para impedir que o jogador arraste a janela de volta para um painel:
  -- UIMiniWindowContainer:onDrop já recusa docar janela flutuante (`if widget.floating then return
  -- true`). E forceOpen seria pior — close() faz early-return com ele, o que quebraria o X.
  local floatLayer = modules.game_interface.getFloatLayer()
  tradeWindow = g_ui.createWidget('TradeWindow', floatLayer)
  tradeWindow.floating = true

  -- Duas coisas SALVAS que o setup() logo abaixo aplicaria, e as duas precisam ser corrigidas
  -- antes, porque ele roda com as settings antigas do jogador:
  --
  -- 1) `closed`: a janela tem `save: true`, então fechar no X grava closed=true. O setup() lê essa
  --    flag e chama close(true); o open(true) do final vem com dontSave e NUNCA limpa a flag. Quem
  --    fechasse a janela uma vez tinha todo trade seguinte cancelado sozinho, para sempre.
  --
  -- 2) `parentId`/`index`: jogador que já usou o trade tem o painel direito salvo como pai. O
  --    setup() re-docaria a janela lá dentro (os dois ramos de fallback fazem setParent), anulando
  --    o float e devolvendo-a para o alcance do fitAll. Reaponta para a camada flutuante; a
  --    `position` salva continua valendo, e agora é interpretada dentro dela.
  tradeWindow:setSettings({ closed = false, floating = true, parentId = floatLayer:getId() })
  tradeWindow:eraseSettings({ index = true })
  tradeWindow:setup()

  -- onClose SÓ DEPOIS do setup(). Ele estava sendo amarrado ANTES, então o close(true) interno do
  -- setup() disparava este handler e mandava rejectTrade() antes de o jogador ver qualquer coisa.
  -- Daqui para baixo, o único close() que sobra é o X — que é intenção real de cancelar.
  tradeWindow.onClose = function()
    g_game.rejectTrade()
    -- Não basta hide(): a referência ficaria viva e o fillTrade() do trade SEGUINTE reusaria uma
    -- janela invisível, fazendo o trade "não abrir".
    onGameCloseTrade()
  end

  tradeWindow:open(true)
  placeTradeWindowIfUnplaced()
  tradeWindow:raise()
end

function fillTrade(name, items, counter)
  if not tradeWindow then
    createTrade()
  end

  local tradeItemWidget = tradeWindow:getChildById('tradeItem')
  tradeItemWidget:setItemId(items[1]:getId())

  local tradeContainer
  local label
  local countLabel
  if counter then
    tradeContainer = tradeWindow:recursiveGetChildById('counterTradeContainer')
    label = tradeWindow:recursiveGetChildById('counterTradeLabel')
    countLabel = tradeWindow:recursiveGetChildById('counterTradeCountLabel')
    tradeWindow:recursiveGetChildById('acceptButton'):enable()
  else
    tradeContainer = tradeWindow:recursiveGetChildById('ownTradeContainer')
    label = tradeWindow:recursiveGetChildById('ownTradeLabel')
    countLabel = tradeWindow:recursiveGetChildById('ownTradeCountLabel')
  end
  label:setText(name)
  countLabel:setText(tr("Items") .. ": " .. #items)


  for index,item in ipairs(items) do
    local itemWidget = g_ui.createWidget('Item', tradeContainer)
    itemWidget:setItem(item)
    itemWidget:setVirtual(true)
    itemWidget:setMargin(0)
    itemWidget.onClick = function()
      g_game.inspectTrade(counter, index-1)
    end
  end
end

function onGameOwnTrade(name, items)
  fillTrade(name, items, false)
end

function onGameCounterTrade(name, items)
  fillTrade(name, items, true)
end

function onGameCloseTrade()
  if tradeWindow then
    -- destroy() não dispara onClose, então este caminho (servidor fechou / fim de jogo / o próprio
    -- handler do X) nunca reenvia rejectTrade.
    tradeWindow:destroy()
    tradeWindow = nil
  end
end
