-- Watches a streamer's channel inside the client instead of handing the URL to
-- the system browser (game_interface's creature menu).
--
-- g_webview is a native OS panel layered over the GL surface: it always paints
-- above the OTUI and cannot be clipped. The panel covers panelArea, so the only
-- chrome that stays clickable is what sits outside it -- the title bar and the
-- resize grips framing the window.

local ALLOWED_DOMAINS = { 'twitch.tv' }
local SETTINGS_NODE = 'streamview'

-- The opening size lives in the .otui; this is only the floor a resize may reach.
local MIN_WIDTH, MIN_HEIGHT = 266, 182
-- Title bar plus the frame around it, which is all that is left when collapsed.
local MINIMIZED_HEIGHT = 38

-- Somewhere the host window will never show. Minimizing cannot hide the native
-- panel -- an OS widget has no z-order against OTUI -- so it is parked instead,
-- which is also what keeps the stream playing while collapsed.
local PARKED_POSITION = -20000

-- Which edges each grip drags. Corners carry both axes, which is what makes them
-- resize horizontally and vertically at once.
local GRIPS = {
  resizeLeft        = { x = -1, y =  0 },
  resizeRight       = { x =  1, y =  0 },
  resizeTop         = { x =  0, y = -1 },
  resizeBottom      = { x =  0, y =  1 },
  resizeTopLeft     = { x = -1, y = -1 },
  resizeTopRight    = { x =  1, y = -1 },
  resizeBottomLeft  = { x = -1, y =  1 },
  resizeBottomRight = { x =  1, y =  1 }
}

local window
local currentUrl
local resizing
local minimized = false
local expandedHeight
local parkedSize

-- isAvailable() only reports the native window handle, not whether the WebView2
-- runtime is installed, so a missing runtime can only be discovered by trying.
-- It never recovers within a session; remember it instead of flashing an empty
-- window on every click.
local webviewBroken = false

-- webviewbackend.h ErrorCode. The ones here are the machine's, not the page's:
-- retrying is pointless until the player fixes something outside the client.
local WEBVIEW_RUNTIME_MISSING = 4
local PERMANENT_ERRORS = {
  [1] = true, -- no host window
  [3] = true, -- COM apartment
  [4] = true, -- WebView2 runtime missing
  [5] = true  -- panel creation failed
}

local function hostOf(url)
  if type(url) ~= 'string' then return nil end

  local host = url:match('^%s*[Hh][Tt][Tt][Pp][Ss]?://([^/?#]+)')
  if not host then return nil end

  host = host:lower():match('([^@]*)$')
  return host:match('^([^:]+)')
end

local function isAllowedHost(host)
  if not host then return false end

  for _, domain in ipairs(ALLOWED_DOMAINS) do
    -- The leading dot is what keeps "evil-twitch.tv" and "twitch.tv.evil.com" out.
    if host == domain or host:sub(-(#domain + 1)) == '.' .. domain then
      return true
    end
  end
  return false
end

local function shortUrl(url)
  return (url:gsub('^%s*[Hh][Tt][Tt][Pp][Ss]?://', ''):gsub('^www%.', ''):gsub('/$', ''))
end

-- The player wants BCP-47, the client's locales are bare language names, and only
-- Portuguese needs the regional form.
local EMBED_LANGUAGES = { pt = 'pt-BR' }

local function embedLanguage()
  local locale = modules.client_locales.getCurrentLocale()
  local name = locale and locale.name or 'en'
  return EMBED_LANGUAGES[name] or name
end

-- What the panel actually loads: our own page embedding the player, which reads the
-- channel and the language off the fragment. The allow-list still gates the link the
-- server sent -- this URL comes from Services, not from the wire.
local function embedUrl(url)
  local base = Services and Services.twitchStream
  if not base or base == '' then return url end

  local channel = url:match('^%s*[Hh][Tt][Tt][Pp][Ss]?://[^/]+/([^/?#]+)')
  if not channel then return url end

  -- Services carries the page; the fragment is this side's business.
  return string.format('%s#channel=%s&lang=%s',
    (base:gsub('#.*$', '')), channel, embedLanguage())
end

local function syncBounds()
  if not (window and g_webview.isOpen()) then return end

  if minimized then
    -- Kept at the size the page was laid out at: shrinking it to the collapsed
    -- sliver would reflow the player and stop the video.
    g_webview.setBounds({ x = PARKED_POSITION, y = PARKED_POSITION,
                          width = parkedSize.width, height = parkedSize.height })
    return
  end

  g_webview.setBounds(window.panelArea:getRect())
end

local function minimize()
  if minimized then return end

  minimized = true
  expandedHeight = window:getHeight()
  parkedSize = window.panelArea:getRect()
  window.minimizeButton:setOn(true)
  window.panelArea:hide()
  window:setHeight(MINIMIZED_HEIGHT)
end

local function restore()
  if not minimized then return end

  minimized = false
  window.minimizeButton:setOn(false)
  window.panelArea:show()
  window:setHeight(expandedHeight)
  window:bindRectToParent()
end

function toggleMinimize()
  if minimized then restore() else minimize() end
end

-- One axis of the drag: the edge the grip does not belong to stays put, and the
-- one being dragged stops at the parent's border.
local function resizeAxis(direction, base, size, minSize, parentBase, parentSize, delta)
  if direction == 0 then return base, size end

  local newSize = math.max(minSize, size + delta * direction)
  if direction < 0 then
    newSize = math.min(newSize, base + size - parentBase)
    return base + size - newSize, newSize
  end

  return base, math.min(newSize, parentBase + parentSize - base)
end

local function onGripPress(grip, mousePos, mouseButton)
  if mouseButton ~= MouseLeftButton then return false end

  -- Anchors would fight setRect back to the centre on the next layout pass.
  window:breakAnchors()
  resizing = {
    direction = GRIPS[grip:getId()],
    rect = window:getRect(),
    bounds = window:getParent():getPaddingRect(),
    origin = mousePos
  }
  return true
end

-- Anchored to where the drag started rather than accumulated per move, so pushing
-- past the minimum and coming back does not leave the edge offset from the cursor.
local function onGripMove(mousePos)
  if not resizing then return end

  local base, bounds = resizing.rect, resizing.bounds
  local x, width = resizeAxis(resizing.direction.x, base.x, base.width, MIN_WIDTH,
                              bounds.x, bounds.width, mousePos.x - resizing.origin.x)
  -- A collapsed window owns its height; only the width is the player's to drag.
  local vertical = minimized and 0 or resizing.direction.y
  local y, height = resizeAxis(vertical, base.y, base.height, MIN_HEIGHT,
                               bounds.y, bounds.height, mousePos.y - resizing.origin.y)

  window:setRect({ x = x, y = y, width = width, height = height })
end

local function setupGrips()
  for id in pairs(GRIPS) do
    local grip = window:getChildById(id)
    grip.onMousePress = onGripPress
    grip.onMouseRelease = function() resizing = nil end
    g_mouse.bindPressMove(grip, onGripMove)
  end
end

local function saveGeometry()
  if not window then return end

  local rect = window:getRect()
  g_settings.setNode(SETTINGS_NODE,
    { x = rect.x, y = rect.y, width = rect.width,
      height = minimized and expandedHeight or rect.height })
  -- setNode alone only reaches disk on a clean exit.
  g_settings.save()
end

local function restoreGeometry()
  local saved = g_settings.getNode(SETTINGS_NODE)
  if not saved or not saved.width or not saved.x then return end

  window:breakAnchors()
  window:setRect({ x = tonumber(saved.x), y = tonumber(saved.y),
                   width = math.max(MIN_WIDTH, tonumber(saved.width)),
                   height = math.max(MIN_HEIGHT, tonumber(saved.height)) })
  -- A smaller screen than last session would leave it off-view.
  window:bindRectToParent()
end

function hide()
  if not window then return end
  if window:isVisible() then
    saveGeometry()
  end

  resizing = nil
  restore()
  g_webview.close()
  currentUrl = nil
  window:hide()
end

function openInBrowser()
  local url = currentUrl
  hide()
  if url then
    g_platform.openUrl(url)
  end
end

-- Returns false when the caller must fall back to the system browser.
function open(url, title)
  if webviewBroken or not g_webview.isAvailable() then return false end
  if not isAllowedHost(hostOf(url)) then return false end

  currentUrl = url
  restore()
  window.titleLabel:setText(title and title ~= '' and title or shortUrl(url))
  window:show()
  -- Deliberately not focused: the keyboard belongs to the game, and taking the
  -- focus chain here kills hotkeys for as long as the panel is up. The panel
  -- itself takes the OS focus when the player clicks into it.
  window:raise()

  -- One panel at a time: switching channels replaces the current one.
  g_webview.close()
  g_webview.open(embedUrl(url), window.panelArea:getRect())
  return true
end

-- The code is what a player can repeat back in a bug report; the detail is in the log.
local function notifyFallback(code)
  local textMessage = modules.game_textmessage
  if not textMessage then return end

  if code == WEBVIEW_RUNTIME_MISSING then
    textMessage.displayFailureMessage(tr(
      'Microsoft WebView2 is missing: opening the stream in your browser (WV-%d).', code))
    return
  end

  textMessage.displayFailureMessage(tr(
    'The stream could not open inside the client, using your browser instead (WV-%d).', code))
end

local webviewHandlers = {
  onError = function(code, detail)
    g_logger.error(string.format('streamview: WV-%d %s', code, detail))

    if PERMANENT_ERRORS[code] then
      webviewBroken = true
    end

    local url = currentUrl
    if not url then return end

    hide()
    notifyFallback(code)
    g_platform.openUrl(url)
  end
}

function init()
  window = g_ui.displayUI('streamview')
  window:hide()
  setupGrips()
  restoreGeometry()

  window.closeButton.onClick = hide
  window.minimizeButton.onClick = toggleMinimize
  window.browserButton.onClick = openInBrowser
  window.onEscape = hide
  -- Dragging, resizing and minimizing all have to carry the native panel along.
  window.onGeometryChange = syncBounds

  connect(g_webview, webviewHandlers)
  connect(g_game, { onGameEnd = hide })
end

function terminate()
  disconnect(g_game, { onGameEnd = hide })
  disconnect(g_webview, webviewHandlers)

  hide()

  window:destroy()
  window = nil
end