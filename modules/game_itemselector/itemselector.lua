local activeWindow

function init()
  g_ui.importStyle('itemselector')

  connect(g_game, { onGameEnd = destroyWindow })
end

function terminate()
  disconnect(g_game, { onGameEnd = destroyWindow })

  destroyWindow()
end

function destroyWindow()
  if activeWindow then
    activeWindow:destroy()
    activeWindow = nil
  end
end

function show(itemWidget)
  if not itemWidget then
    return
  end
  if activeWindow then
    destroyWindow()
  end
  local window = g_ui.createWidget('ItemSelectorWindow', rootWidget)
  
  local destroy = function()
    window:destroy()
    if window == activeWindow then
      activeWindow = nil
    end
  end
  local doneFunc = function()
    itemWidget:setItem(Item.create(window.item:getItemId(), window.item:getItemCount()))
    destroy()
  end
  local clearFunc = function()
    window.item:setItemId(0)
    window.item:setItemCount(0)
    doneFunc()
  end
  
  window.clearButton.onClick = clearFunc
  window.okButton.onClick = doneFunc
  window.cancelButton.onClick = destroy
  window.onEnter = doneFunc
  window.onEscape = destroy
  
  window.item:setItem(Item.create(itemWidget:getItemId(), itemWidget:getItemCount()))
  
  window.itemId:setValue(itemWidget:getItemId())
  window.itemId:hideButtons()
  window.itemId.onValueChange = function(widget, value)
    window.item:setItemId(value)
  end

  window.itemCount:setMinimum(1)
  window.itemCount:setMaximum(100)
  local count = math.max(1, math.min(100, itemWidget:getItemCount()))
  window.itemCount:setValue(count)
  window.item:setItemCount(count)
  window.countValueLabel:setText(count)
  window.itemCount.onValueChange = function(self, value)
    window.item:setItemCount(value)
    window.countValueLabel:setText(value)
  end
  
  activeWindow = window
  activeWindow:raise()
  activeWindow:focus()
end

function hide()
  destroyWindow()
end
