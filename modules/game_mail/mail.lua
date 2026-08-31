local currentMail
local mailButton
local mailsWidgetByMailId = { }

function init()
  mailWindow = g_ui.displayUI('mail')
  mailButton = modules.client_topmenu.addMiddleGameToggleButton('mailTopButton', tr('Mail') .. '', '/images/ui/topbuttons/icons/mail', toggle)

  hide()

  connect(g_game, {
    onGameEnd = onLogout,
    -- protocolo custom 1582 (parseMail em C++); substituiu o extended 121
    onMailList = onMailList,
    onMailRead = onMailRead,
    onMailClaim = onMailClaim,
    onMailUnreadCount = onMailUnreadCount
  })
end

function terminate()
  mailsWidgetByMailId = nil

  disconnect(g_game, {
    onGameEnd = onLogout,
    onMailList = onMailList,
    onMailRead = onMailRead,
    onMailClaim = onMailClaim,
    onMailUnreadCount = onMailUnreadCount
  })

  mailWindow:destroy()
end

function show()
  mailWindow:show()
  mailWindow:focus()
  if mailButton then mailButton:setOn(true) end
  sendMailsRequest()
end

function hide()
  mailWindow:hide()
  if mailButton then mailButton:setOn(false) end
end

function toggle()
  if mailWindow:isVisible() then
    hide()
  else
    show()
  end
end

function onLogout()
  hide()
end

function clearMails()
  local mailsPanel = mailWindow:recursiveGetChildById('mails')
  mailsPanel:destroyChildren()
end

function addMail(mail, select)
  local mailsPanel = mailWindow:recursiveGetChildById('mails')
  local mailWidget = g_ui.createWidget('Mail', mailsPanel)

  local mailId = mail.id
  local read = mail.read
  local claimed = mail.claimed
  local title = mail.title
  local createdDate = mail.createdDate
  local endDate = mail.endDate
  local rewards = mail.rewards
  local bannerUrl = mail.bannerUrl
  local description = mail.description
  description = description:gsub("\\n", "\n")

  loadMailBanner(bannerUrl, mailWidget)

  local now = os.time()
  local endTimestamp = g_game.formatStringToTime(endDate)
  local daysLeft = math.ceil((endTimestamp - now) / (24 * 60 * 60))

  local readWidget = mailWidget:getChildById('read')
  readWidget:setChecked(read and (not rewards or claimed))
  mailWidget:getChildById('title'):setText(title)
  mailWidget:getChildById('date'):setText(g_game.formatShortDate(createdDate))
  mailWidget:getChildById('endDate'):setText(tr("Expires in %dd", daysLeft))

  mailWidget.mailId = mailId
  mailWidget.claimed = claimed
  mailWidget.hasRewards = not table.empty(rewards)
  mailsWidgetByMailId[mailId] = mailWidget

  mailWidget.onClick = function()
    if currentMail and currentMail ~= mailWidget then
      currentMail:setChecked(false)
    end

    currentMail = mailWidget
    mailWidget:setChecked(true)

    local mailsContainer = mailWindow:getChildById('mailsContainer')
    local banner = mailsContainer:getChildById('banner')
    banner:setImageSource(mailWidget.bannerSrc)
    banner:show()

    local header = mailsContainer:getChildById('header')
    header:getChildById('title'):setText(title)
    header:getChildById('date'):setText(g_game.formatDate(createdDate))
    header:show()

    local descriptionLabel = mailsContainer:getChildById('description')
    descriptionLabel:setText(string.format("%s", description))

    local rewardsContainer = mailWindow:getChildById('rewardsContainer')
    local hasRewards = rewards and not table.empty(rewards)
    rewardsContainer:setVisible(hasRewards)

    local claimed = mailWidget.claimed
    local rewardsPanel = rewardsContainer:getChildById('rewards')
    local claimButton = rewardsContainer:getChildById('claim')
    claimButton:setOn(claimed)

    if rewards then
      rewardsPanel:destroyChildren()

      for _, reward in ipairs(rewards) do
        local rewardWidget = g_ui.createWidget('MailReward', rewardsPanel)
        local item = rewardWidget:getChildById('item')
        item:setItemId(reward.itemId)
        item:setItemCount(reward.count)
      end

      updateMailRewards(mailWidget)

      rewardsContainer:show()
    else
      rewardsContainer:hide()
    end

    if not readWidget:isChecked() and not readWidget.claimed then
      sendMailRead(mailWidget.mailId)
    end
  end

  if select then
    mailWidget.onClick()
  end
end

function updateMailRewards(mailWidget)
  local claimed = mailWidget.claimed
  local rewardsContainer = mailWindow:getChildById('rewardsContainer')
  local rewardsPanel = rewardsContainer:getChildById('rewards')

  if claimed then
    local readWidget = mailWidget:getChildById('read')
    readWidget:setChecked(claimed)
  end

  for _, rewardWidget in ipairs(rewardsPanel:getChildren()) do
    local item = rewardWidget:getChildById('item')
    local check = rewardWidget:getChildById('check')
    item:setChecked(claimed)
    check:setVisible(claimed)
  end
end

function loadMailBanner(bannerUrl, mailWidget)
  HTTP.downloadImage(bannerUrl, function(file)
    mailWidget.bannerSrc = file

    if currentMail == mailWidget then
      local banner = mailWindow:recursiveGetChildById('banner')
      banner:setImageSource(file)
    end
  end)
end

function setMailRead(mailId)
  local mailWidget = mailsWidgetByMailId[mailId]
  if not mailWidget then
    return
  end

  local hasRewards = mailWidget.hasRewards
  mailWidget:getChildById('read'):setChecked(not hasRewards or mailWidget.claimed)
end

function setMailClaimed(mailId)
  local mailWidget = mailsWidgetByMailId[mailId]
  if not mailWidget then
    return
  end

  mailWidget.claimed = true
  if not currentMail or currentMail.mailId ~= mailId then
    return
  end

  updateMailRewards(mailWidget)
end

function claimReward()
  if not currentMail then
    return
  end

  local mailId = currentMail.mailId
  sendClaimMail(mailId)
end

function sendUnreadMailsNotification(unreadMails)
  print(string.format("New emails! (%d)", unreadMails))
  -- TODO:
end
