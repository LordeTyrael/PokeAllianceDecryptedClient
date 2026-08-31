-- @docclass UIState

-- Creates a new state with an optional callback.
-- The callback receives `true` when deactivated and `false` when activated.
-- Returns the state index.
function UIState:new(callback)
  return self:createState(callback)
end



-- Connects a widget's signals to the current state.
-- When the state is activated, `connect(widget, connections)` is called.
-- When the state is deactivated, `disconnect(widget, connections)` is called.
function UIState:connect(widget, connections)
  self:addConnect(function()
    connect(widget, connections)
  end)

  self:addDisconnect(function()
    disconnect(widget, connections)
  end)
end
