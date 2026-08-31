-- Protocolo custom 1582 nas duas direções (parseMail em C++). Substituiu o extended 121 + o transporte
-- JSON chunked, que estava quebrado acima de 3000 chars (registro fora da tabela JSON, sem remontagem S/P/E).

local _parseMails
local _parseRead
local _parseMailClaim
local _parseUnreadMails

local m_cachedMails = false

-- Handlers dos eventos disparados pelo parseMail
function onMailList(mails, unreadMails)
  _parseMails(mails, unreadMails)
end

function onMailRead(mailId)
  _parseRead(mailId)
end

function onMailClaim(mailId)
  _parseMailClaim(mailId)
end

function onMailUnreadCount(unreadMails)
  _parseUnreadMails(unreadMails)
end

function _parseMails(mails, unreadMails)
  m_cachedMails = true

  table.sort(mails, function(a, b)
    if a.claimed ~= b.claimed then
      return not a.claimed
    end

    if a.read ~= b.read then
      return not a.read
    end

    local aTime = g_game.formatStringToTime(a.createdDate)
    local bTime = g_game.formatStringToTime(b.createdDate)

    if aTime ~= bTime then
      return aTime > bTime
    end

    if a.id and b.id then
      return a.id < b.id
    end

    return false
  end)

  clearMails()

  for index, mail in ipairs(mails) do
    addMail(mail, index == 1)
  end

  if unreadMails > 0 then
    sendUnreadMailsNotification(unreadMails)
  end
end

function _parseRead(mailId)
  setMailRead(mailId)
end

function _parseMailClaim(mailId)
  setMailClaimed(mailId)
end

function _parseUnreadMails(unreadMails)
  if unreadMails > 0 then
    m_cachedMails = false
  end

  sendUnreadMailsNotification(unreadMails)

  if mailWindow:isVisible() then
    sendMailsRequest()
  end
end

-- C2S no protocolo custom 1582 (migrado do extended 121)
function sendMailsRequest()
  if m_cachedMails then
    return
  end

  -- TODO
  local lang = 'en'
  g_game.sendMailRequestList(lang)
end

function sendMailRead(mailId)
  g_game.sendMailRead(mailId)
end

function sendClaimMail(mailId)
  g_game.sendMailClaim(mailId)
end
