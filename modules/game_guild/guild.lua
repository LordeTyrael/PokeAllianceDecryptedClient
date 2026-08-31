-- local MainWindow, MainButton
-- local Panel = {}
-- local Opcode = 12
-- local MaxBanners = 15
-- local loaded = false
-- local isLeader, isVice = false, false
-- local onInit = true
GUILDLEVEL_MEMBER = 1
GUILDLEVEL_VICELEADER = 2
GUILDLEVEL_LEADER = 3

local guildDataLoaded = false
local guildWindow
local guestGuildWindow
local guildButton
local dailyWindow
local confirmShopWindow

local playerInvitesWindow
local guildInvitesWindow
local changeMotdWindow
local inviteWindow
local guildCreateWindow
local kickWindow
local promoteWindow
local passLeadershipWindow
local demoteWindow
local revokeWindow
local leaveWindow
local joinWindow
local emblemWindow
local confirmDailyWindow
local disbandWindow
local balanceWindow
local diamondCost = 0

local confirmJoinBossWindow
local confirmOpenBossWindow
local contributeGuildBalanceWindow
local renameGuildWindow

local bossRewardCycleEvent = nil
local bossRewardCycleSlots = {}

local storageMembership
local storageGuildInfo
local storageMembers
local storagePlayerInvites
local storageEmblems

local guildItems = {}

local selectedEmblem
local selectedTab

modules.client_hotkeys.registerHotkeyCallback("GUILD",
	function(actionName, action, keyInfo, chatState, keyType)
		local callback = function()
			local chatModeEnabled = not modules.game_chat.consoleToggleChat
			local wantChat = (chatState == "chatEnabled")
			if (wantChat and chatModeEnabled) or (not wantChat and not chatModeEnabled) then
				toggle()
			end
		end
		return { callback = callback, widget = modules.game_interface.getRootPanel() }
	end)

local guildConfig = {
	["Critical Damage"] = {
		image = "images/buffsicon/critical",
		description = "Gain more %d%% Critical Damage."
	},
	["Critical Chance"] = {
		image = "images/buffsicon/critical_chance",
		description = "Gain more %d%% Critical Chance."
	},
	["Critical Capture"] = {
		image = "images/buffsicon/critical_catch",
		description = "Gain a %d%% chance of a critical capture (2x capture chance)"
	},
	["Lucky Bonus"] = {
		image = "images/buffsicon/lucky",
		description = "Gain more %d%% Lucky Bonus."
	},
	["Attack in All Pokémon"] = {
		image = "images/buffsicon/power_up",
		description = "Gain more %d%% Attack in All Pokémon."
	},
	["Defense in All Pokémon"] = {
		image = "images/buffsicon/defense",
		description = "Gain more %d%% Defense in All Pokémon."
	},
	["Experience"] = {
		image = "images/buffsicon/experience",
		description = "Gain more %d%% Experience."
	},
	["Guild Members"] = {
		image = "images/buffsicon/members",
		description = "Increase the maximum number of members in your guild by %d."
	},
	["Attack in Boss Battle"] = {
		image = "images/buffsicon/boss_damage",
		description = "Increase the damage dealt to bosses by %d%%."
	},
	["Defense in Boss Battle"] = {
		image = "images/buffsicon/boss_defense",
		description = "Reduce the damage taken from bosses by %d%%."
	}
}

local tabs = {
	["main"] = "mainContent",
	["members"] = "membersContent",
	["boss"] = "bossContent",
	["buffs"] = "buffsContent",
	["shop"] = "shopContent",
	["audits"] = "auditsContent"
}

function init()
	connect(g_game, {
		onGameEnd = onGameEnd,
		onGameStart = onGameStart,
		onAutoWalk = onAutoWalk
	})

	connect(LocalPlayer, {
		onBankBalanceChange = onBankBalanceChange
	})

	guildWindow = g_ui.loadUI("guild", modules.game_interface.getRootPanel())
	guildWindow.onEscape = toggle
	guildWindow:hide(false)

	guestGuildWindow = g_ui.loadUI("guild_guest", modules.game_interface.getRootPanel())

	-- The grab follows visibility instead of being pushed/removed by hand: guild.lua hides these
	-- windows from a dozen places, and a single missed remove leaves a hidden window holding the
	-- keyboard - the chat then never regains focus on Enter.
	local function trackGrab(window)
		window.onVisibilityChange = function(self, visible)
			if visible then g_uistates.push(self) else g_uistates.remove(self) end
		end
	end
	trackGrab(guildWindow)
	trackGrab(guestGuildWindow)
	guestGuildWindow:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	guestGuildWindow:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
	guestGuildWindow:hide()

	inviteWindow = g_ui.loadUI("guild_invite", modules.game_interface.getRootPanel())
	inviteWindow:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	inviteWindow:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
	inviteWindow:hide()

	guildInvitesWindow = g_ui.loadUI("guild_invitelist", modules.game_interface.getRootPanel())
	guildInvitesWindow:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	guildInvitesWindow:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
	guildInvitesWindow:hide()

	playerInvitesWindow = g_ui.loadUI("guild_playerinvitelist", modules.game_interface.getRootPanel())
	playerInvitesWindow:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	playerInvitesWindow:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
	playerInvitesWindow:hide()

	changeMotdWindow = g_ui.loadUI("guild_motd", modules.game_interface.getRootPanel())
	changeMotdWindow:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	changeMotdWindow:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
	changeMotdWindow:hide()
	-- opens on top of the guild window, which holds the grab: without its own push the text edit
	-- never sees the keyboard (same reason the prey choices window needs one)
	trackGrab(changeMotdWindow)

	g_ui.importStyle('guild_rename')

	emblemWindow = g_ui.loadUI("guild_emblems", modules.game_interface.getRootPanel())
	emblemWindow:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	emblemWindow:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
	emblemWindow:hide()

	balanceWindow = g_ui.loadUI("guild_addbalance", guildWindow)
	balanceWindow:hide()

	guildButton = modules.client_topmenu.addMiddleGameToggleButton('guildButton', tr('Guild') .. ' (Ctrl+J)',
		'/images/ui/topbuttons/icons/guild', toggle)
	guildButton:setOn(false)

	if g_game.isOnline() then
		onGameStart()
	end
end

function terminate()
	stopBossRewardCycle()
	bossRewardCycleSlots = {}
	storageMembership = nil
	storageGuildInfo = nil
	storageMembers = nil
	storagePlayerInvites = nil
	storageEmblems = nil
	selectedEmblem = nil
	selectedTab = nil

	for tab, content in pairs(tabs) do
		if guildWindow:getChildById(content) then
			guildWindow:getChildById(content):destroy()
		end
	end

	if guildWindow then
		guildWindow:destroy()
		guildWindow = nil
	end

	if guestGuildWindow then
		guestGuildWindow:destroy()
		guestGuildWindow = nil
	end

	if guildButton then
		guildButton:destroy()
		guildButton = nil
	end

	if playerInvitesWindow then
		playerInvitesWindow:destroy()
		playerInvitesWindow = nil
	end

	if guildInvitesWindow then
		guildInvitesWindow:destroy()
		guildInvitesWindow = nil
	end

	if changeMotdWindow then
		changeMotdWindow:destroy()
		changeMotdWindow = nil
	end

	if inviteWindow then
		inviteWindow:destroy()
		inviteWindow = nil
	end

	if kickWindow then
		kickWindow:destroy()
		kickWindow = nil
	end

	if promoteWindow then
		promoteWindow:destroy()
		promoteWindow = nil
	end

	if passLeadershipWindow then
		passLeadershipWindow:destroy()
		passLeadershipWindow = nil
	end

	if demoteWindow then
		demoteWindow:destroy()
		demoteWindow = nil
	end

	if revokeWindow then
		revokeWindow:destroy()
		revokeWindow = nil
	end

	if leaveWindow then
		leaveWindow:destroy()
		leaveWindow = nil
	end

	if disbandWindow then
		disbandWindow:destroy()
		disbandWindow = nil
	end

	if joinWindow then
		joinWindow:destroy()
		joinWindow = nil
	end

	if emblemWindow then
		emblemWindow:destroy()
		emblemWindow = nil
	end

	if renameGuildWindow then
		renameGuildWindow:destroy()
		renameGuildWindow = nil
	end

	if confirmShopWindow then
		confirmShopWindow:destroy()
		confirmShopWindow = nil
	end

	if confirmJoinBossWindow then
		confirmJoinBossWindow:destroy()
		confirmJoinBossWindow = nil
	end
	
	if confirmOpenBossWindow then
		confirmOpenBossWindow:destroy()
		confirmOpenBossWindow = nil
	end

	confirmDailyWindowCleanup()

	disconnect(g_game, {
		onGameEnd = onGameEnd,
		onGameStart = onGameStart,
		onAutoWalk = onAutoWalk
	})

	disconnect(LocalPlayer, {
		onBankBalanceChange = onBankBalanceChange
	})
end

function onGameStart()
	connect(g_game, {
		onGuildMembership = onGuildMembership,
		onGuildFullInfo = onGuildFullInfo,
		onGuildRanking = onGuildRanking,
		onGuildAudits = onGuildAudits,
		onGuildContributions = onGuildContributions,
		onGuildEmblems = onGuildEmblems,
		onGuildBuffs = onGuildBuffs,
		onGuildDailies = onGuildDailies,
		onGuildPlayerInvites = onGuildPlayerInvites,
		onGuildShopItems = onGuildShopItems,
		onGuildReply = onGuildReply,
		onGuildClose = onGuildClose
	})
	guildButton:setOn(false)
	guildDataLoaded = false
end

function onGameEnd()
	if guildWindow then
		guildWindow:hide()
	end

	if playerInvitesWindow then
		playerInvitesWindow:hide()
	end

	if guildInvitesWindow then
		guildInvitesWindow:hide()
	end

	if changeMotdWindow then
		changeMotdWindow:hide()
	end

	if inviteWindow then
		g_uistates.remove(inviteWindow)
		inviteWindow:hide()
	end

	if kickWindow then
		kickWindow:hide()
	end

	if promoteWindow then
		promoteWindow:hide()
	end

	if passLeadershipWindow then
		passLeadershipWindow:hide()
	end

	if demoteWindow then
		demoteWindow:hide()
	end

	if revokeWindow then
		revokeWindow:hide()
	end

	if leaveWindow then
		leaveWindow:hide()
	end

	if disbandWindow then
		disbandWindow:hide()
	end

	if joinWindow then
		joinWindow:hide()
	end

	if emblemWindow then
		emblemWindow:hide()
	end

	if renameGuildWindow then
		g_uistates.remove(renameGuildWindow)
		renameGuildWindow:destroy()
		renameGuildWindow = nil
	end

	if confirmShopWindow then
		confirmShopWindow:destroy()
		confirmShopWindow = nil
	end

	if confirmJoinBossWindow then
		confirmJoinBossWindow:destroy()
		confirmJoinBossWindow = nil
	end

	if confirmOpenBossWindow then
		confirmOpenBossWindow:destroy()
		confirmOpenBossWindow = nil
	end

	confirmDailyWindowCleanup()

	for tab, content in pairs(tabs) do
		if guildWindow:getChildById(content) then
			guildWindow:getChildById(content):hide()
		end
	end

	storageMembership = nil
	storageGuildInfo = nil
	storageMembers = nil
	storagePlayerInvites = nil
	storageEmblems = nil
	selectedEmblem = nil
	selectedTab = nil
	guildDataLoaded = false

	disconnect(g_game, {
		onGuildMembership = onGuildMembership,
		onGuildFullInfo = onGuildFullInfo,
		onGuildRanking = onGuildRanking,
		onGuildAudits = onGuildAudits,
		onGuildContributions = onGuildContributions,
		onGuildEmblems = onGuildEmblems,
		onGuildBuffs = onGuildBuffs,
		onGuildDailies = onGuildDailies,
		onGuildPlayerInvites = onGuildPlayerInvites,
		onGuildShopItems = onGuildShopItems,
		onGuildReply = onGuildReply,
		onGuildClose = onGuildClose
	})
end

function leaveGuildWindows()
	if guildWindow then
		guildWindow:hide()
	end

	if guestGuildWindow then
		guestGuildWindow:hide()
	end

	if playerInvitesWindow then
		playerInvitesWindow:hide()
	end

	if guildInvitesWindow then
		guildInvitesWindow:hide()
	end

	if changeMotdWindow then
		changeMotdWindow:hide()
	end

	if inviteWindow then
		g_uistates.remove(inviteWindow)
		inviteWindow:hide()
	end

	if kickWindow then
		kickWindow:hide()
	end

	if promoteWindow then
		promoteWindow:hide()
	end

	if passLeadershipWindow then
		passLeadershipWindow:hide()
	end

	if demoteWindow then
		demoteWindow:hide()
	end

	if revokeWindow then
		revokeWindow:hide()
	end

	if leaveWindow then
		leaveWindow:hide()
	end

	if disbandWindow then
		disbandWindow:hide()
	end

	if joinWindow then
		joinWindow:hide()
	end

	if emblemWindow then
		emblemWindow:hide()
	end

	if confirmShopWindow then
		confirmShopWindow:destroy()
		confirmShopWindow = nil
	end

	if balanceWindow then
		balanceWindow:hide()
	end

	for tab, content in pairs(tabs) do
		if guildWindow:getChildById(content) then
			guildWindow:getChildById(content):hide()
		end
	end
end

-- Guild event handlers (data pre-parsed by C++ protocolgameparse)

function onGuildMembership(data)
	updateMembership(data)
end

function onGuildFullInfo(data)
	updateGuildInfo(data)
end

function onGuildRanking(ranking)
	updateRanking(ranking)
end

function onGuildAudits(audits)
	updateAudits(audits)
end

function onGuildContributions(data)
	updateContribuitions(data)
end

function onGuildEmblems(emblems)
	updateEmblems(emblems)
end

function onGuildBuffs(data)
	updateGuildBuffs(data)
end

function onGuildDailies(categories)
	-- Convert from array of {taskType, missions} to taskType-keyed table
	local buffer = {}
	for _, cat in ipairs(categories) do
		buffer[cat.taskType] = cat.missions
	end
	updateDailies(buffer)
end

function onGuildPlayerInvites(invites)
	handlePlayerInvites(invites)
end

function onGuildShopItems(items)
	guildItems = items
end

function onGuildReply(reply)
	local data = {}
	if reply.success then
		data.success = true
		data.message = reply.message
	else
		data.errors = reply.errors
	end

	local replyType = reply.replyType
	if replyType == "create" then
		handleGuildCreate(data)
	elseif replyType == "kick" then
		handleGuildKick(data)
	elseif replyType == "promote" then
		handleGuildPromote(data)
	elseif replyType == "passleadership" then
		handleGuildPassLeadership(data)
	elseif replyType == "demote" then
		handleGuildDemote(data)
	elseif replyType == "invite" then
		handleInvite(data)
	elseif replyType == "motd" then
		handleMotd(data)
	elseif replyType == "revoke" then
		handleGuildRevoke(data)
	elseif replyType == "reject" then
		handleGuildReject(data)
	elseif replyType == "banner" then
		handleEmblem(data)
	elseif replyType == "join" then
		handleGuildJoin(data)
	elseif replyType == "leave" then
		handleGuildLeave(data)
	elseif replyType == "disband" then
		handleGuildDisband(data)
	elseif replyType == "taskItem" then
		handleGiveItems(data)
	elseif replyType == "rename" then
		handleGuildRename(data)
	end
end

function onGuildClose()
	leaveGuildWindows()
end

function toggle()
	local chatModeEnabled = modules.game_chat.consoleToggleChat
	if guildButton and guildButton:isOn() then
		guildButton:setOn(false)
		if chatModeEnabled then
			modules.game_walking.enableWSAD()
		end
		if balanceWindow then
			balanceWindow:hide()
		end
		stopBossRewardCycle()
		guildWindow:hide()
		guestGuildWindow:hide()
	else
		guildButton:setOn(true)
		if chatModeEnabled then
			modules.game_walking.disableWSAD()
		end
		open()
	end
end

function open()
	local player = g_game.getLocalPlayer()
	local hasGuild = player and player:getGuildName() ~= nil and player:getGuildName() ~= ''

	if hasGuild then
		if not guildDataLoaded then
			guildDataLoaded = true
			g_game.sendGuildRequestData()
		end
		guestGuildWindow:hide()
		guildWindow:show()
		-- see the note in game_prey: the grab is what makes onEscape reach this window
		guildWindow:getChildById('guildInfoWindow'):show()
		guildWindow:getChildById('menus'):show()
		chooseTab('main', true)
	else
		guildWindow:hide()
		guestGuildWindow:show()
		guestGuildWindow:raise()
	end
end

function refreshGuildInfo()
	local infoWindow = guildWindow:recursiveGetChildById('infoWindow')
	if not infoWindow or not storageGuildInfo then
		return
	end

	local rankingNo = math.min(storageGuildInfo.rank, 4)
	local banner = infoWindow:recursiveGetChildById('guildImage')
	banner:setImageSource(string.format(
		"/images/guild_banners/%d.png", storageGuildInfo.bannerid))

	banner.onClick = function (e)
		if storageMembership and storageMembership.level == GUILDLEVEL_LEADER then
			emblemOpen()
		end
	end

	local guildNameWidget = infoWindow:recursiveGetChildById('guildName')
	guildNameWidget:setText(storageGuildInfo.name)

	-- Edit name button (leader only)
	local existingEditBtn = infoWindow:recursiveGetChildById('editNameButton')
	if existingEditBtn then
		existingEditBtn:destroy()
	end
	if storageMembership and storageMembership.level == GUILDLEVEL_LEADER then
		local editBtn = g_ui.createWidget('UIWidget', infoWindow)
		editBtn:setId('editNameButton')
		editBtn:setSize({width = 14, height = 14})
		editBtn:setIcon('@fa solid 12 f303')
		editBtn:setColor('#a0b0c0')
		editBtn:setCursor('pointer')
		editBtn:addAnchor(AnchorLeft, 'guildName', AnchorLeft)
		editBtn:addAnchor(AnchorVerticalCenter, 'guildName', AnchorVerticalCenter)
		editBtn:setMarginLeft(guildNameWidget:getTextSize().width + 5)
		editBtn.onClick = function()
			renameGuildOpen()
		end
	end

	infoWindow:recursiveGetChildById('guildLevel'):setText(string.format(tr('Level')..": %d", storageGuildInfo.level))
	guildWindow:recursiveGetChildById('motdText'):setText(storageGuildInfo.motd)
	infoWindow:recursiveGetChildById('guildLeader'):recursiveGetChildById('label'):setText(string.format("Leader: %s",
		storageGuildInfo.leader))
	infoWindow:recursiveGetChildById('guildMembers'):recursiveGetChildById('label'):setText(string.format("Members: %d/%d",
		#storageGuildInfo.members, storageGuildInfo.maxMembers or #storageGuildInfo.members))
	infoWindow:recursiveGetChildById('guildBalance'):recursiveGetChildById('label'):setText(string.format("Balance: $%d",
		storageGuildInfo.balance))
	infoWindow:recursiveGetChildById('guildExperience'):setText(comma_value2(storageGuildInfo.experience.."/"..storageGuildInfo.requiredExperience))
	infoWindow:recursiveGetChildById('guildExperience'):setTooltip(comma_value2(storageGuildInfo.experience.."/"..storageGuildInfo.requiredExperience))
	infoWindow:recursiveGetChildById('progressBar'):setTooltip(comma_value2(storageGuildInfo.experience.."/"..storageGuildInfo.requiredExperience))
	infoWindow:recursiveGetChildById('progressBar'):setPercent((storageGuildInfo.experience / storageGuildInfo.requiredExperience) * 100)

	if storageGuildInfo.members and #storageGuildInfo.members > 0 then
		local temporaryStorageMembers = {}
		storageMembers = {}
		for _, member in pairs(storageGuildInfo.members) do
			if not temporaryStorageMembers[member.rankLevel] then
				temporaryStorageMembers[member.rankLevel] = {}
			end

			table.insert(temporaryStorageMembers[member.rankLevel], member)
		end

		local ranks = {}
		local maxLevel = 0
		for _, rank in pairs(storageGuildInfo.ranks) do
			ranks[rank.level] = rank.name
			if rank.level > maxLevel then
				maxLevel = rank.level
			end
		end

		for level = maxLevel, 1, -1 do
			if ranks[level] then
				table.insert(storageMembers, {
					name = ranks[level],
					members = temporaryStorageMembers[level]
				})
			end
		end
	end

	local buffPanel = guildWindow:recursiveGetChildById('buffsScrollArea')
	if storageGuildInfo.allBuffs then
		buffPanel:destroyChildren()
		for index, config in ipairs(storageGuildInfo.allBuffs) do
			local buffName = config.name
			local buffWidget = g_ui.createWidget("BuffWidget", buffPanel)
			buffWidget:setId(buffName)
			buffWidget.index = index
			buffWidget.buffName:setText(buffName)
			local iconConfig = guildConfig[buffName]
			if iconConfig then
				buffWidget.background:setImageSource(iconConfig.image)
			end
			buffWidget.buffLevel:setText(config.level)
			buffWidget.progressPercent:hide()
			buffWidget.buffImprovement:disable()
			buffWidget:setTooltip("Your guild need at least Level "..config.requireUnlockLevel.. " to Unlock this Buff.")
		end
	end

	if storageGuildInfo.unlockedBuffs then
		for buffName, config in pairs(storageGuildInfo.unlockedBuffs) do
			local widget = buffPanel:recursiveGetChildById(buffName)
			if widget then
				if config.progress > 0 then
					local progressPercent = math.max(config.progress, 1) -- Garante que o progresso ménimo seja 1%
					local clippedHeight = math.ceil(56 * (progressPercent / 100)) -- Calcula a altura proporcional
					local rect = { x = 0, y = 56 - clippedHeight, width = 20, height = clippedHeight }
					widget.progressPercent:setImageClip(rect)
					widget.progressPercent:setImageRect(rect)
					widget.progressPercent:show()
				end
				local descriptionConfig = guildConfig[buffName]
				if descriptionConfig then
					widget:setTooltip(string.format(descriptionConfig.description, config.value))
				else
					widget:setTooltip(nil)
				end
				widget:setOpacity(1)
				widget.buffImprovement:enable()
				widget.buffLevel:setText(config.level)
			end
		end
	end

	if storageGuildInfo.buffs then
		for index, config in pairs (storageGuildInfo.buffs) do
			buffPanel:recursiveGetChildById('buff'..index):setText(config)
			if index > storageGuildInfo.level then
				buffPanel:recursiveGetChildById('buff'..index):setOpacity(0.3)
			else
				buffPanel:recursiveGetChildById('buff'..index):setOpacity(1)
			end
		end
	end
end

-------------------------- LISTAGEM DE MEMBROS INVITADOS NA GUILD --------------------

function updateGuildInvites()
	if not storageGuildInfo then
		return
	end

	local invites = guildInvitesWindow:recursiveGetChildById('invitesContent')
	invites:destroyChildren()

	local header = g_ui.createWidget('GuildInviteRow', invites)
	-- header:getChildById('action'):setVisible(false)
	header:addAnchor(AnchorTop, 'parent', AnchorTop)
	header:addAnchor(AnchorLeft, 'parent', AnchorLeft)
	header:addAnchor(AnchorRight, 'parent', AnchorRight)

	for i, invite in ipairs(storageGuildInfo.invites) do
		local row = g_ui.createWidget('GuildInviteRow', invites)
		local action = row:getChildById('action')
		local button = g_ui.createWidget('UIWidget', action)
		row:getChildById('name'):setText(invite.name)
		row:getChildById('level'):setText(invite.level)
		row:getChildById('action'):setText('')
		button:setImageSource("/images/newui/close")
		button:setCursor("pointer")
		button:setWidth(15)
		button:setHeight(15)
		button.onClick = function()
			revokeConfirmation(invite)
		end
		button:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
		button:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
		row:addAnchor(AnchorTop, 'prev', AnchorBottom)
		row:addAnchor(AnchorLeft, 'parent', AnchorLeft)
		row:addAnchor(AnchorRight, 'parent', AnchorRight)
	end

end

function inviteListOpen()
	guildInvitesWindow:show()
	guildInvitesWindow:focus()
end

function inviteListClose()
	guildInvitesWindow:hide()
end

--------------------------------------------------------------------------------------------

function updateMembers()
	if not storageMembers then
		return
	end

	local membersPanel = guildWindow:recursiveGetChildById('membersScrollArea')
	local membersLayout = membersPanel:getLayout()
	membersPanel:destroyChildren()
	-- membersLayout:disableUpdates()

	first = true
	for _, opts in pairs(storageMembers) do
		local members = opts.members
		if members and #members > 0 then
			local containerWidget = g_ui.createWidget('RankMembers', membersPanel)
			if first then
				containerWidget:addAnchor(AnchorTop, 'parent', AnchorTop)
				first = false
			else
				containerWidget:addAnchor(AnchorTop, 'prev', AnchorBottom)
			end

			containerWidget:addAnchor(AnchorRight, 'parent', AnchorRight)
			containerWidget:addAnchor(AnchorLeft, 'parent', AnchorLeft)

			local membersWidget = containerWidget:recursiveGetChildById('members')
			containerWidget:recursiveGetChildById('rankTitle'):setText(opts.name)

			local numColumns = math.max(1, math.floor(membersPanel:getWidth() / 165))
			local rows = math.max(1, math.ceil(#members / numColumns))
			local spacing = 0
			if rows > 1 then
				spacing = 10 * (rows - 1)
			end
			containerWidget:setHeight(28 + (60 * rows) + spacing)
			for i, member in ipairs(members) do
				local item = g_ui.createWidget('RankMember', membersWidget)
				--item:getChildById('emblem'):setImageSource(string.format('/modules/game_guild/images/playerIcons/%s.png', member.icon))
				--item:recursiveGetChildById('emblem'):setImageSource()
				item.emblem:setImageSource("/game_trainer/images/icons/" .. member.icon)
				item:recursiveGetChildById('name'):setText(member.name)
				item:recursiveGetChildById('level'):setText(string.format("Level: %d", member.level))
				if (member.lastLogin == 0) then
					item:recursiveGetChildById('lastLogin'):setTooltip("Online")
					item:recursiveGetChildById('lastLoginTime'):setText("Online")
					item:recursiveGetChildById('loginIcon'):setImageSource("images/online")
				else
					item:recursiveGetChildById('lastLogin'):setTooltip(string.format("Offline: %s", formatLastLogin(member.lastLogin)))
					item:recursiveGetChildById('lastLoginTime'):setText("Offline")
					item:recursiveGetChildById('loginIcon'):setImageSource("images/offline")
				end
				item.emblem:setTooltip(string.format("Completed %d daily missions this week.\nContributed $%s this week.", member.dailiesCompleted, comma_value2(member.contribuition)))

				g_mouse.bindPress(item, function()
					memberOptions(member)
				end, MouseRightButton)
			end
		end
	end

	-- membersLayout:enableUpdates()
	-- membersLayout:update()
end

function memberOptions(member)
	if not storageMembership or not storageMembership.hasGuild then
		return
	end

	if storageMembership.level < member.rankLevel then
		return
	end

	local menu = g_ui.createWidget('PopupMenu')
	menu:setGameMenu(true)


	if member.rankLevel < GUILDLEVEL_LEADER and storageMembership.level >= GUILDLEVEL_LEADER then
		menu:addOption("Pass Leadership", function()
			passLeadershipConfirmation(member)
		end)
	end

	if member.rankLevel == GUILDLEVEL_MEMBER and storageMembership.level > GUILDLEVEL_MEMBER then
		menu:addOption("Promote", function()
			promoteConfirmation(member)
		end)
	end

	if member.rankLevel == GUILDLEVEL_VICELEADER and storageMembership.level > GUILDLEVEL_VICELEADER then
		menu:addOption("Demote", function()
			demoteConfirmation(member)
		end)
	end

	if member.rankLevel < storageMembership.level then
		menu:addOption("Kick", function()
			kickConfirmation(member)
		end)
	end

	menu:display()
end

function updateMembership(membership)
	storageMembership = membership
	if not guildWindow:isVisible() then
		guildButton:setOn(false)
	end
	refreshOptions()
end

function refreshOptions()
	if not storageMembership then
		return
	end

	if storageMembership.id == 0 then
		leaveGuildWindows()
		return
	end

	local inviteButton = guildWindow:recursiveGetChildById('inviteButton')
	if inviteButton then
		inviteButton:setVisible(storageMembership.level >= GUILDLEVEL_VICELEADER)
		inviteButton.onClick = function()
			inviteOpen()
		end
	end

	local leaveButton = guildWindow:recursiveGetChildById('leaveButton')
	if leaveButton then
		leaveButton:setVisible(storageMembership.level <= GUILDLEVEL_VICELEADER)
		leaveButton.onClick = function()
			leaveConfirmation()
		end
	end

	local disbandButton = guildWindow:recursiveGetChildById('disbandButton')
	if disbandButton then
		disbandButton:setVisible(storageMembership.level >= GUILDLEVEL_LEADER)
		disbandButton.onClick = function()
			disbandConfirmation()
		end
	end

	local guildLevelButton = guildWindow:recursiveGetChildById('guildLevelUp')
	if guildLevelButton then
		guildLevelButton:setVisible(storageMembership.level >= GUILDLEVEL_VICELEADER)
		guildLevelButton.onClick = function()
			g_game.sendGuildLevelUp()
		end
	end

	local inviteList = guildWindow:recursiveGetChildById('inviteList')
	if inviteList then
		inviteList:setVisible(storageMembership.level >= GUILDLEVEL_VICELEADER)
		inviteList.onClick = function()
			inviteListOpen()
		end
	end

	local motdEdit = guildWindow:recursiveGetChildById('motdEdit')
	if motdEdit then
		motdEdit:setVisible(storageMembership.level >= GUILDLEVEL_VICELEADER)
		motdEdit.onClick = function()
			motdOpen()
		end
	end
end

function refreshAudits()
	g_game.sendGuildRefreshAudits()
end

function updateAudits(audits)
	local auditPanel = guildWindow:recursiveGetChildById('auditsScrollArea')
	local auditLayout = auditPanel:getLayout()
	auditPanel:destroyChildren()
	-- auditLayout:disableUpdates()

	local header = g_ui.createWidget('AuditHeaderRow', auditPanel)
	header:getChildById('time'):setText('Date')
	header:getChildById('action'):setText('Action')
	header:addAnchor(AnchorTop, 'parent', AnchorTop)
	header:addAnchor(AnchorLeft, 'parent', AnchorLeft)
	header:addAnchor(AnchorRight, 'parent', AnchorRight)

	if audits and #audits > 0 then
		for i, audit in ipairs(audits) do
			local item = g_ui.createWidget('AuditRow', auditPanel)
			item:getChildById('time'):setText(os.date('%Y-%m-%d %H:%M:%S', audit.time))
			item:getChildById('action'):setText(audit.action)
			item:addAnchor(AnchorTop, 'prev', AnchorBottom)
			item:addAnchor(AnchorLeft, 'parent', AnchorLeft)
			item:addAnchor(AnchorRight, 'parent', AnchorRight)
			if i % 2 == 0 then
				item:setBackgroundColor('#1a1e25')
			else
				item:setBackgroundColor('#222730')
			end
		end
	else
		local item = g_ui.createWidget('AuditEmptyRow', auditPanel)
		item:getChildById('text'):setText(tr('No data to display'))
		item:addAnchor(AnchorTop, 'prev', AnchorBottom)
		item:addAnchor(AnchorLeft, 'parent', AnchorLeft)
		item:addAnchor(AnchorRight, 'parent', AnchorRight)
	end

	-- auditLayout:enableUpdates()
	-- auditLayout:update()
end

function updateContribuitions(contribuitions)
	if not balanceWindow then
		return
	end
	local contribuitionPanel = balanceWindow:recursiveGetChildById('contribuitionPanel')
	balanceWindow.background.contribuitionPanel.cashPanel.cashContribuition:setText(contribuitions.cashContribuition.."/"..contribuitions.cashLimitContribuition.."\nContribution: $100.000")
	diamondCost = (contribuitions.diamondContribuition == 0) and 1 or (2 ^ contribuitions.diamondContribuition)
	balanceWindow.background.contribuitionPanel.diamondPanel.diamondConfirm.diamondIcon:setItemId(3028)
	balanceWindow.background.contribuitionPanel.diamondPanel.diamondConfirm.diamondCost:setText(diamondCost)
	
	if contribuitions.cashContribuition == contribuitions.cashLimitContribuition then
		balanceWindow.background.contribuitionPanel.cashPanel.cashConfirm:setImageSource("images/normal_button")
		balanceWindow.background.contribuitionPanel.cashPanel.cashConfirm:disable()
	else
		balanceWindow.background.contribuitionPanel.cashPanel.cashConfirm:setImageSource("images/button")
		balanceWindow.background.contribuitionPanel.cashPanel.cashConfirm:enable()
	end
end

function hideBalance()
	if not balanceWindow then
		return
	end
	balanceWindow:hide()
end

function updateRanking(ranking)
	local rankingPanel = guildWindow:recursiveGetChildById('rankingPanel')
	local rankingLayout = rankingPanel:getLayout()
	rankingLayout:disableUpdates()
	rankingLayout:destroyChildren()

	local header = g_ui.createWidget('RankingRow', rankingPanel)
	header:getChildById('position'):setText('Rank')
	header:getChildById('emblem'):setText('')
	header:getChildById('name'):setText('Name')
	header:getChildById('leader'):setText('Leader')
	header:getChildById('members'):setText('Members')
	header:getChildById('level'):setText('Level')
	header:getChildById('experience'):setText('Experience')

	for i, rank in ipairs(ranking) do
		local item = g_ui.createWidget('RankingRow', rankingPanel)
		item:getChildById('position'):setText('#' .. i)
		item:getChildById('emblem'):setImageSource(rank.emblem)
		item:getChildById('name'):setText(rank.name)
		item:getChildById('leader'):setText(rank.leader)
		item:getChildById('members'):setText(string.format("%d/%d", rank.membersCount, 10))
		item:getChildById('level'):setText(rank.level)
		item:getChildById('experience'):setText(rank.exp)
	end

	rankingLayout:enableUpdates()
	rankingLayout:update()
end

function updateGuildInfo(guildInfo)
	storageGuildInfo = guildInfo
	selectedEmblem = guildInfo.bannerid
	refreshGuildInfo()
	updateMembers()
	updateGuildInvites()
	parseGuildBosses()
end

function updateGuildBuffs(buffsInfo)
	if not storageGuildInfo then
		return
	end

	storageGuildInfo.unlockedBuffs = buffsInfo.buffer
	storageGuildInfo.balance = buffsInfo.balance
	refreshGuildInfo()
end

function sendDailyItems(taskId)
	g_game.sendGuildTaskItem(taskId)
end


--------------- GUILD REVOKE (CANCELAR UM INVITE) -----------
function handleGuildRevoke(data)
	if data.success then
		revokeCleanup()
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		revokeCleanup()
	end
end

function revokeConfirm(self)
	windowDisableButtons(revokeWindow)
	g_game.sendGuildRevoke(revokeWindow.invitation.name)
	guildInvitesWindow:hide()
end

function revokeCleanup()
	if revokeWindow then
		revokeWindow:destroy()
	end
end

function revokeConfirmation(invite)
	revokeCleanup()
	revokeWindow = displayAllianceBox(tr('Confirm Revoke'), tr("Are you sure you want to revoke %s's invitation from the Guild?", invite.name), {
		{
			text = tr('Yes'),
			callback = revokeConfirm
		},
		{
			text = tr('No'),
			callback = revokeCleanup
		},
		anchor = AnchorHorizontalCenter
	}, revokeConfirm, revokeCleanup)
	revokeWindow.invitation = invite
end

-------------- GUILD PROMOTE (SUBIR MEMBRO DE RANK) --------------------

function handleGuildPromote(data)
	if data.success then
		promoteCleanup()
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		promoteCleanup()
	end
end

function promoteConfirm(self)
	windowDisableButtons(promoteWindow)

	g_game.sendGuildPromote(promoteWindow.promoteMember.name)
end

function promoteCleanup()
	if promoteWindow then
		promoteWindow:destroy()
	end
end

function promoteConfirmation(member)
	promoteCleanup()
	promoteWindow = displayAllianceBox(tr('Confirm Promote'), tr('Are you sure you want to promote %s?', member.name), {
		{
			text = tr('Yes'),
			callback = promoteConfirm
		},
		{
			text = tr('No'),
			callback = promoteCleanup
		},
		anchor = AnchorHorizontalCenter
	}, promoteConfirm, promoteCleanup)
	promoteWindow.promoteMember = member
end

------------------------------- GUILD DEMOTE (DESCER MEMBRO DE RANK) --------------------------

function handleGuildDemote(data)
	if data.success then
		demoteCleanup()
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		demoteCleanup()
	end
end

function demoteConfirm(self)
	windowDisableButtons(demoteWindow)

	g_game.sendGuildDemote(demoteWindow.demoteMember.name)
end

function demoteCleanup()
	if demoteWindow then
		demoteWindow:destroy()
	end
end

function demoteConfirmation(member)
	demoteCleanup()
	demoteWindow = displayAllianceBox(tr('Confirm Demote'), tr('Are you sure you want to demote %s?', member.name), {
		{
			text = tr('Yes'),
			callback = demoteConfirm
		},
		{
			text = tr('No'),
			callback = demoteCleanup
		},
		anchor = AnchorHorizontalCenter
	}, demoteConfirm, demoteCleanup)
	demoteWindow.demoteMember = member
end

------------------- GUILD KICK (KIKAR UM MEMBRO DA GUILD) -----------------------

function handleGuildKick(data)
	if data.success then
		kickCleanup()
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		kickCleanup()
	end
end

function kickConfirm(self)
	windowDisableButtons(kickWindow)

	g_game.sendGuildKick(kickWindow.kickMember.name)
end

function kickCleanup()
	if kickWindow then
		kickWindow:destroy()
	end
end

function kickConfirmation(member)
	kickCleanup()
	kickWindow = displayAllianceBox(tr('Confirm Kick'), tr('Are you sure you want to kick %s from the Guild?', member.name), {
		{
			text = tr('Yes'),
			callback = kickConfirm
		},
		{
			text = tr('No'),
			callback = kickCleanup
		},
		anchor = AnchorHorizontalCenter
	}, kickConfirm, kickCleanup)
	kickWindow.kickMember = member
end

---------------------- CHECK INVITED GUILDS (VERIFICAR AS GUILDS QUE INVITARAM UM JOGADOR) --------------

function playerInvitesOpen()
	guestGuildWindow:hide()

	playerInvitesWindow:show()
	playerInvitesWindow:focus()
end

function handlePlayerInvites(data)
	storagePlayerInvites = data

	local inviteWidget = playerInvitesWindow:recursiveGetChildById('invitesContent')
	inviteWidget:destroyChildren()

	local header = g_ui.createWidget('PlayerInviteRow', inviteWidget)
	header:addAnchor(AnchorTop, 'parent', AnchorTop)
	header:addAnchor(AnchorLeft, 'parent', AnchorLeft)
	header:addAnchor(AnchorRight, 'parent', AnchorRight)

	for i, invite in ipairs(storagePlayerInvites) do
		local row = g_ui.createWidget('PlayerInviteRow', inviteWidget)
		row:getChildById('name'):setText(invite.name)

		local action = row:getChildById('action')
		action:setMarginLeft(6)
		action:setText("")

		local joinButton = g_ui.createWidget('UIWidget', action)
		joinButton:setImageSource("/images/modules/guild/check_icon")
		joinButton:setCursor("pointer")
		joinButton:setWidth(20)
		joinButton:setHeight(15)
		joinButton:setTooltip(tr('Join Invitation'))
		joinButton.onClick = function() guildJoinConfirmation(invite) end
		joinButton:addAnchor(AnchorLeft, 'parent', AnchorLeft)
		joinButton:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
		joinButton:setMarginLeft(8)

		local rejectButton = g_ui.createWidget('UIWidget', action)
		rejectButton:setImageSource("/images/newui/close")
		rejectButton:setCursor("pointer")
		rejectButton:setTooltip(tr('Reject Invitation'))
		rejectButton:setWidth(15)
		rejectButton:setHeight(15)
		rejectButton.onClick = function() guildRejectConfirmation(invite) end
		rejectButton:addAnchor(AnchorLeft, 'prev', AnchorRight)
		rejectButton:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
		rejectButton:setMarginLeft(8)

		row:addAnchor(AnchorTop, 'prev', AnchorBottom)
		row:addAnchor(AnchorLeft, 'parent', AnchorLeft)
		row:addAnchor(AnchorRight, 'parent', AnchorRight)
	end
end

function playerInviteListClose()
	playerInvitesWindow:hide()
	guildWindow:hide()
	guildButton:setOn(false)
end

-------------------------- EMBLEMA ----------------------------------

function emblemOpen()
	emblemWindow:show()
	emblemWindow:focus()
end

function handleEmblem(data)
	if data.success then
		displayAllianceInfoBox("Success", data.message)
		emblemClose()
		open()
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
	end
end

function updateEmblems(emblems)
	storageEmblems = emblems

	local emblemPanel = emblemWindow:recursiveGetChildById('emblemsContent')
	local emblemLayout = emblemPanel:getLayout()
	emblemLayout:disableUpdates()
	emblemPanel:destroyChildren()

	for _, emblem in ipairs(storageEmblems) do
		local item = g_ui.createWidget('EmblemWidget', emblemPanel)
		item:setImageSource(string.format("/images/guild_banners/%s", emblem.image))
		item:setTooltip(emblem.text)
		item.emblem = emblem

		item.onClick = function (self)
			selectEmblem(self.emblem.id)
		end
	end

	selectEmblem(selectedEmblem)
	emblemLayout:enableUpdates()
	emblemLayout:update()
end

function selectEmblem(id)
	local currentSelected = selectedEmblem
	local emblemPanel = emblemWindow:recursiveGetChildById('emblemsContent')
	for i = 1, emblemPanel:getChildCount() do
		local widget = emblemPanel:getChildByIndex(i)
		if widget and widget.emblem.id == id then
			widget:setBorderWidth(1)
			selectedEmblem = widget.emblem.id
		else
			widget:setBorderWidth(0)
		end
	end
end

function guildEmblemConfirm()
	local emblemPanel = emblemWindow:recursiveGetChildById('emblemsContent')
	windowDisableButtons(emblems)

	g_game.sendGuildBanner(selectedEmblem)

end

function emblemClose()
	emblemWindow:hide()
end

----------------------- SHOP WINDOW  -------------------------

function openShopWindow()
	local shopContent = guildWindow:recursiveGetChildById('shopContent')
	if not shopContent then
		return
	end

	local shopPanel = shopContent:recursiveGetChildById('shopPanel')
	local buyPanel = shopContent:recursiveGetChildById('buyPanel')
	if not shopPanel or not buyPanel then
		return
	end

	local layout = shopPanel:getLayout()
	layout:disableUpdates()
	buyPanel:recursiveGetChildById('itemCost'):setItemId(39993)
	shopPanel:destroyChildren()
	local focusedWidget = nil
	local coinCount = modules.game_playeractionbar.getPlayerItemCount(39993)
	for index, itemConfig in ipairs(guildItems) do
		local itemWidget = g_ui.createWidget('GuildShopItem', shopPanel)
		if not focusedWidget then
			focusedWidget = itemWidget
		end
		itemWidget.shopIndex = index
		itemWidget:setTooltip(itemConfig.description)
		itemWidget.item:setItemId(itemConfig.clientId)
		itemWidget.item:setItemCount(itemConfig.count)
		itemWidget.itemName.name = itemConfig.name
		itemWidget.itemName:setText(itemConfig.name)
		itemWidget.priceInfo.itemPrice:setText(itemConfig.price)

		itemWidget.onFocusChange = function(widget, focused)
			if not focused then
				return
			end
			buyPanel:recursiveGetChildById('item'):setItemId(itemConfig.clientId)
			buyPanel:recursiveGetChildById('item').count = itemConfig.count
			buyPanel:recursiveGetChildById('item'):setItemCount(itemConfig.count)
			buyPanel:recursiveGetChildById('itemName').name = itemConfig.name
			buyPanel:recursiveGetChildById('itemName'):setText(string.format("%dx %s", itemConfig.count, itemConfig.name))
			buyPanel:recursiveGetChildById('costDescription'):setText(itemConfig.price)
			buyPanel:recursiveGetChildById('costDescription').price = itemConfig.price
			buyPanel:recursiveGetChildById('quantityScroll'):setValue(1)
			local maxCount = coinCount > itemConfig.price and math.floor(coinCount/itemConfig.price) or 0
			maxCount = math.min(10000, maxCount)
			buyPanel:recursiveGetChildById('quantityScroll'):setMaximum(math.max(1, maxCount))
		end
	end
	shopContent:recursiveGetChildById('coinCount'):setText(coinCount)
	shopContent:recursiveGetChildById('coinItem'):setItemId(39993)
	
	if focusedWidget then
		focusedWidget:focus()
	end
	layout:enableUpdates()
	layout:update()
end

function onQuantityShopValueChange(value)
	local shopContent = guildWindow:recursiveGetChildById('shopContent')
	if not shopContent then return end
	local buyPanel = shopContent:recursiveGetChildById('buyPanel')
	if not buyPanel then return end
	local item = buyPanel:recursiveGetChildById('item')
	local costDesc = buyPanel:recursiveGetChildById('costDescription')
	if not item.count or not costDesc.price then
		return
	end

	local newCount = item.count * value
	item:setItemCount(newCount)
	local itemName = buyPanel:recursiveGetChildById('itemName').name or ""
	buyPanel:recursiveGetChildById('itemName'):setText(string.format("%dx %s", newCount, itemName))
	costDesc:setText(costDesc.price * value)
end

function onUpdateShopCoin(newCount)
	local shopContent = guildWindow:recursiveGetChildById('shopContent')
	if not shopContent or not shopContent:isVisible() then
		return
	end

	shopContent:recursiveGetChildById('coinCount'):setText(newCount)
end

function closeShopWindow()
	if confirmShopWindow then
		confirmShopWindow:destroy()
		confirmShopWindow = nil
	end
end

function confirmBuyItemShop()
	local shopContent = guildWindow:recursiveGetChildById('shopContent')
	if not shopContent then
		return
	end

	local shopPanel = shopContent:recursiveGetChildById('shopPanel')
	local buyPanel = shopContent:recursiveGetChildById('buyPanel')
	local selectedChild = shopPanel:getFocusedChild()
	if not selectedChild then
		return
	end

	local index = selectedChild.shopIndex
	local clientId = selectedChild.item:getItemId() or 0
	local count = buyPanel:recursiveGetChildById('quantityScroll'):getValue() or 0

	if not index or clientId == 0 or count == 0 then
		return
	end

	g_game.sendBuyGuildShopItem(index, clientId, count)

	if confirmShopWindow then
		confirmShopWindow:destroy()
		confirmShopWindow = nil
	end
end

function destroyConfirmShopWindow()
	if confirmShopWindow then
		confirmShopWindow:destroy()
		confirmShopWindow = nil
	end
end

function buyGuildItemShop()
	local shopContent = guildWindow:recursiveGetChildById('shopContent')
	if not shopContent or confirmShopWindow then
		return
	end

	local shopPanel = shopContent:recursiveGetChildById('shopPanel')
	local buyPanel = shopContent:recursiveGetChildById('buyPanel')

	-- precisa haver um item focado
	local selectedChild = shopPanel:getFocusedChild()
	if not selectedChild then
		return
	end

	-- lé do buyPanel (preenchido no onFocusChange)
	local itemName  = buyPanel:recursiveGetChildById('itemName').name or ""
	local packCount = tonumber(buyPanel:recursiveGetChildById('item').count) or 1 -- itens por pack
	local unitPrice = tonumber(buyPanel:recursiveGetChildById('costDescription').price) or 0
	local quantity  = tonumber(buyPanel:recursiveGetChildById('quantityScroll'):getValue()) or 0
	local coins     = tonumber(shopContent:recursiveGetChildById('coinCount'):getText()) or 0

	if itemName == "" or unitPrice <= 0 or quantity <= 0 then
		return
	end

	local totalItems = packCount * quantity
	local totalPrice = unitPrice * quantity

	local title = tr("Confirm Buy")
	local body = tr(
		"Buy %dx %s for %d Boss Golden Tokens?",
		totalItems, itemName, totalPrice
	)

	confirmShopWindow = displayAllianceBox(
		title,
		body,
		{
			{ text = tr("Yes"), callback = confirmBuyItemShop },
			{ text = tr("No"),  callback = destroyConfirmShopWindow },
			anchor = AnchorHorizontalCenter
		},
		confirmBuyItemShop,
		destroyConfirmShopWindow
	)
end

-------------------------- JOIN INVITE (ACEITAR UM INVITE DE GUILD) ----------------------------------
function joinConfirm(self)
	joinWindow:hide()
	playerInvitesWindow:hide()

	g_game.sendGuildJoin(joinWindow.name)
end

function handleGuildJoin(data)
	if data.success then
		guildJoinCleanup()
		displayAllianceInfoBox("Success", data.message)
		open()
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		guildJoinCleanup()
	end
end

function guildJoinCleanup()
	if joinWindow then
		joinWindow:destroy()
	end

	guildWindow:hide()
end

function guildJoinConfirmation(guild)
	joinWindow = displayAllianceBox(tr('Confirm Join'), tr('Are you sure you want to join %s?', guild.name), {
		{
			text = tr('Yes'),
			callback = joinConfirm
		},
		{
			text = tr('No'),
			callback = guildJoinCleanup
		},
		anchor = AnchorHorizontalCenter
	}, joinConfirm, guildJoinCleanup)
	joinWindow.name = guild.name
end


function handleGuildLeave(data)
	if data.success then
		guildLeaveCleanup()
		displayAllianceInfoBox("Success", data.message)
		open()
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		guildLeaveCleanup()
	end
end

function guildLeaveCleanup()
	if leaveWindow then
		leaveWindow:destroy()
	end
	guildWindow:hide()
end

-------------------------- REJECT INVITE (RECUSAR UM INVITE DE GUILD) ----------------------------------
function rejectConfirm(self)
	rejectWindow:hide()
	guildWindow:hide()
	playerInvitesWindow:hide()

	g_game.sendGuildReject(rejectWindow.name)
end

function handleGuildReject(data)
	if data.success then
		guildRejectCleanup()
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		guildRejectCleanup()
	end
end

function guildRejectCleanup()
	if rejectWindow then
		rejectWindow:destroy()
	end

	guildWindow:hide()
end

function guildRejectConfirmation(guild)
	rejectWindow = displayAllianceBox(tr('Confirm Reject'), tr('Confirm reject the %s invites?', guild.name), {
		{
			text = tr('Yes'),
			callback = rejectConfirm
		},
		{
			text = tr('No'),
			callback = guildRejectCleanup
		},
		anchor = AnchorHorizontalCenter
	}, rejectConfirm, guildRejectCleanup)
	rejectWindow.name = guild.name
end

function createGuildOpen()
	if guildCreateWindow then return end
	guestGuildWindow:hide()

	guildCreateWindow = g_ui.loadUI("guild_create", modules.game_interface.getRootPanel())
	guildCreateWindow:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	guildCreateWindow:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)

	local guildNameInput = guildCreateWindow:recursiveGetChildById('name')
	local guildNameButton = guildCreateWindow:recursiveGetChildById('button')

	guildNameInput:setBorderWidth(0)
	guildNameInput:setEnabled(true)
	guildNameButton:setEnabled(true)

	local localPlayer = g_game.getLocalPlayer()
	if localPlayer then
		local balance = localPlayer:getBankBalance()
		guildCreateWindow:recursiveGetChildById("balanceValue"):setText("$"..comma_value2(balance))
	end

	guildCreateWindow:show()
	guildCreateWindow:raise()
	g_uistates.push(guildCreateWindow)
	guildNameInput:focus()
end

function createGuildClose()
	if not guildCreateWindow then return end
	g_uistates.remove(guildCreateWindow)
	guildCreateWindow:destroy()
	guildCreateWindow = nil
	guestGuildWindow:show()
end

function createGuildSubmit()
	if not guildCreateWindow then return end
	local guildNameInput = guildCreateWindow:recursiveGetChildById('name')
	local guildNameButton = guildCreateWindow:recursiveGetChildById('button')

	guildNameInput:setEnabled(false)
	guildNameButton:setEnabled(false)

	g_game.sendGuildCreate(guildNameInput:getText())
end

function handleGuildCreate(data)
	if not guildCreateWindow then return end
	local guildNameInput = guildCreateWindow:recursiveGetChildById('name')
	local guildNameButton = guildCreateWindow:recursiveGetChildById('button')

	if data.success then
		createGuildClose()
		displayAllianceInfoBox("Success", data.message)
		guestGuildWindow:hide()
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		guildNameInput:setEnabled(true)
		guildNameButton:setEnabled(true)
	end
end

function inviteOpen()
	local inviteInput = inviteWindow:recursiveGetChildById('name')
	local inviteButton = inviteWindow:recursiveGetChildById('button')

	inviteInput:setBorderWidth(0)
	inviteInput:setEnabled(true)
	inviteButton:setEnabled(true)
	inviteInput:setText("")

	inviteWindow:show()
	inviteWindow:raise()
	inviteWindow:focus()
	g_uistates.push(inviteWindow)
	inviteInput:focus()
	inviteInput:setCursorPos(-1)
end

function inviteClose()
	--guildWindow:getChildById('mainContent'):show()
	g_uistates.remove(inviteWindow)
	inviteWindow:hide()
end

function inviteSubmit()
	local inviteInput = inviteWindow:recursiveGetChildById('name')
	local inviteButton = inviteWindow:recursiveGetChildById('button')

	inviteInput:setEnabled(false)
	inviteButton:setEnabled(false)

	g_game.sendGuildInvite(inviteInput:getText())

	inviteInput:setText("")
end

function handleInvite(data)
	local inviteInput = inviteWindow:recursiveGetChildById('name')
	local inviteButton = inviteWindow:recursiveGetChildById('button')

	if data.success then
		inviteClose()
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		inviteInput:setEnabled(true)
		inviteButton:setEnabled(true)
	end
end

--------------------- CHANGE MOTD FUNCTION ----------------

function motdOpen()
	local motdWindow = changeMotdWindow:getChildById('guildmotd')
	local motdInput = changeMotdWindow:recursiveGetChildById('name')
	local motdButton = changeMotdWindow:recursiveGetChildById('button')

	changeMotdWindow:show()
	changeMotdWindow:focus()
	motdInput:setBorderWidth(0)
	motdInput:setEnabled(true)
	motdButton:setEnabled(true)
end

function motdClose()
	--guildWindow:getChildById('mainContent'):show()
	changeMotdWindow:hide()
end

function motdSubmit()
	local motdWindow = changeMotdWindow:getChildById('guildmotd')
	local motdInput = changeMotdWindow:recursiveGetChildById('name')
	local motdButton = changeMotdWindow:recursiveGetChildById('button')

	motdInput:setEnabled(false)
	motdButton:setEnabled(false)

	g_game.sendGuildMotd(motdInput:getText())
end

function handleMotd(data)
	local motdWindow = changeMotdWindow:getChildById('guildmotd')
	local motdInput = changeMotdWindow:recursiveGetChildById('name')
	local motdButton = changeMotdWindow:recursiveGetChildById('button')

	if data.success then
		motdClose()
		--displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		motdInput:setEnabled(true)
		motdButton:setEnabled(true)
	end
end

------------------------------------------------------------------

--------------- GUILD RENAME -----------

function renameGuildOpen()
	if renameGuildWindow then return end
	renameGuildWindow = g_ui.createWidget('RenameGuildWindow', modules.game_interface.getRootPanel())
	renameGuildWindow:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
	renameGuildWindow:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
	g_uistates.push(renameGuildWindow)
	local nameInput = renameGuildWindow:getChildById('nameEdit')
	if nameInput then
		nameInput:focus()
	end
end

function renameGuildClose()
	if renameGuildWindow then
		g_uistates.remove(renameGuildWindow)
		renameGuildWindow:destroy()
		renameGuildWindow = nil
	end
end

function renameGuildSubmit()
	if not renameGuildWindow then return end
	local nameInput = renameGuildWindow:getChildById('nameEdit')
	local confirmBtn = renameGuildWindow:getChildById('confirmButton')
	if not nameInput or not confirmBtn then return end

	nameInput:setEnabled(false)
	confirmBtn:setEnabled(false)

	g_game.sendGuildRename(nameInput:getText())
end

function handleGuildRename(data)
	if data.success then
		renameGuildClose()
		return
	end

	if renameGuildWindow then
		local nameInput = renameGuildWindow:getChildById('nameEdit')
		local confirmBtn = renameGuildWindow:getChildById('confirmButton')
		local errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
		errorBox.onOk = function()
			if nameInput then nameInput:setEnabled(true) end
			if confirmBtn then confirmBtn:setEnabled(true) end
		end
	end
end

------------------------------------------------------------------

--------------- GUILD REVOKE (CANCELAR UM INVITE) -----------
function handleGuildleave(data)
	if data.success then
		leaveCleanup()
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		leaveCleanup()
	end
end

function leaveConfirm(self)
	windowDisableButtons(leaveWindow)
	g_game.sendGuildLeave()
end

function leaveCleanup()
	if leaveWindow then
		leaveWindow:destroy()
	end
end

function leaveConfirmation()
	leaveCleanup()
	leaveWindow = displayAllianceBox(tr('Confirm Leave'), tr('Are you sure you want to leave %s?', storageGuildInfo.name), {
		{
			text = tr('Yes'),
			callback = leaveConfirm
		},
		{
			text = tr('No'),
			callback = leaveCleanup
		},
		anchor = AnchorHorizontalCenter
	}, leaveConfirm, leaveCleanup)
end

---------------

function chooseTab(tabName, init)
	if not init and selectedTab == tabName then
		return
	end

	stopBossRewardCycle()
	for tab, content in pairs(tabs) do
		local tabButton = 'tab' .. tab:sub(1, 1):upper() .. tab:sub(2)

		if tab == tabName then
			selectedTab = tabName
			guildWindow:getChildById(content):show()
			guildWindow:recursiveGetChildById(tabButton):setOn(true)
			if tab == "shop" then
				openShopWindow()
			end
			if tab == "boss" then
				startBossRewardCycle()
			end
		else
			guildWindow:getChildById(content):hide()
			guildWindow:recursiveGetChildById(tabButton):setOn(false)
		end
	end
end

function windowDisableButtons(el)
	if not el then
		return
	end
	local buttonHolder = el:getChildById('buttonHolder')
	if buttonHolder and buttonHolder:getChildCount() > 0 then
		for i = 1, buttonHolder:getChildCount() do
			local button = buttonHolder:getChildByIndex(i)
			if button then
				button:setEnabled(false)
			end
		end
	end
end

function handleGiveItems(data)
	if data.success then
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
	end
end

-- Escolha da daily em DOIS passos: tier, depois elemento. Nada é sorteado — o jogador diz
-- exatamente o que vai caçar, e o servidor recebe o par como "tier:elemento".
local DAILY_TIERS = {
	{ id = "normal",    label = "Normal" },
	{ id = "wildscape", label = "Wildscape" },
	{ id = "primal",    label = "Primal" },
}

-- Mesma ordem e mesmos 18 nomes de GameGuild.DAILY_ELEMENTS no servidor. Grade 6 colunas x 3 linhas.
local DAILY_ELEMENTS = {
	"normal", "fire", "fighting", "water", "flying", "grass",
	"poison", "electric", "ground", "psychic", "rock", "ice",
	"bug", "dragon", "ghost", "dark", "steel", "fairy",
}
local ELEMENT_COLUMNS = 6

-- Ícone: a MESMA folha que a pokédex usa (modules/game_pokedex/elements.png), com o mesmo recorte
-- de 24px por linha.
--
-- O índice é uma CÓPIA do ElementsIndex da pokédex, de propósito: aquele é global de outro módulo,
-- e depender dele criaria ordem de carregamento entre game_guild e game_pokedex. Repare que a folha
-- tem LACUNAS (steel 18, dark 19, fairy 22) — os números não são sequenciais e têm de bater com
-- modules/game_pokedex/pokedex.lua:13 se a arte mudar.
local ELEMENT_SHEET = '/game_pokedex/elements.png'
local ELEMENT_SHEET_SIZE = 24
local ELEMENT_SHEET_INDEX = {
	normal = 1,  fire = 2,   water = 3,    grass = 4,  electric = 5, ice = 6,
	fighting = 7, poison = 8, ground = 9,  flying = 10, psychic = 11, bug = 12,
	rock = 13,   ghost = 14, dragon = 15,  steel = 18, dark = 19,    fairy = 22,
}

local function capitalize(text)
	return text:sub(1, 1):upper() .. text:sub(2)
end

-- Estado da escolha em andamento. O layout é todo do GuildDailyPicker (guild.otui); aqui só ficam
-- seleção e clique.
local pickerTier, pickerElement = nil, nil

local function refreshPickerSelection(picker)
	for _, tab in ipairs(picker:getChildById('tierTabs'):getChildren()) do
		tab:setOn(tab.tierId == pickerTier)
	end
	for _, cell in ipairs(picker:getChildById('elementGrid'):getChildren()) do
		cell:setChecked(cell.elementId == pickerElement)
	end
	picker:getChildById('confirmButton'):setEnabled(pickerTier ~= nil and pickerElement ~= nil)
end

function showDailyTierPicker(dailyPanel)
	dailyPanel:destroyChildren()
	pickerTier, pickerElement = nil, nil

	local picker = g_ui.createWidget('GuildDailyPicker', dailyPanel)

	local tabs = picker:getChildById('tierTabs')
	for _, tier in ipairs(DAILY_TIERS) do
		local tab = g_ui.createWidget('GuildDailyTierTab', tabs)
		tab:setText(tier.label)
		tab.tierId = tier.id
		tab.onClick = function()
			pickerTier = tier.id
			refreshPickerSelection(picker)
		end
	end

	local grid = picker:getChildById('elementGrid')
	for _, element in ipairs(DAILY_ELEMENTS) do
		local cell = g_ui.createWidget('GuildDailyElementCell', grid)
		cell.elementId = element
		cell:setTooltip(capitalize(element))
		local sheetIndex = ELEMENT_SHEET_INDEX[element]
		if sheetIndex then
			local icon = cell:getChildById('icon')
			icon:setImageSource(ELEMENT_SHEET)
			icon:setImageClip({ x = 0, y = ELEMENT_SHEET_SIZE * (sheetIndex - 1),
			                    width = ELEMENT_SHEET_SIZE, height = ELEMENT_SHEET_SIZE })
		else
			-- Sem linha na folha: mostra o texto em vez de virar um quadrado vazio.
			cell:setText(capitalize(element))
		end
		cell.onClick = function()
			pickerElement = element
			refreshPickerSelection(picker)
		end
	end

	picker:getChildById('confirmButton').onClick = function()
		if not pickerTier or not pickerElement then
			return
		end
		local tierLabel = pickerTier
		for _, tier in ipairs(DAILY_TIERS) do
			if tier.id == pickerTier then tierLabel = tier.label end
		end
		showDailyConfirmation(pickerTier .. ":" .. pickerElement, tierLabel, capitalize(pickerElement))
	end

	refreshPickerSelection(picker)
end

function updateDailies(buffer)
	local dailyPanel = guildWindow:recursiveGetChildById('dailyPanel')
	if not dailyPanel then
		return
	end

	dailyPanel:destroyChildren()

	local refreshRow = guildWindow:recursiveGetChildById('refreshRow')
	if refreshRow then
		refreshRow:setVisible(false)
	end

	-- A daily deixou de ser por continente e passou a ser por TIER de spawn selvagem + ELEMENTO.
	-- O servidor manda a categoria como "killElement:<tier>" — o tier vai colado no nome porque o
	-- pacote é parseado em C++ (protocolgameparse.cpp) e um campo novo obrigaria rebuild do cliente
	-- para todos os jogadores online.
	--
	-- A checagem antiga era `not buffer.killMonster`, presa ao nome antigo da categoria. Agora
	-- verifica se existe QUALQUER missão, senão o seletor nunca mais apareceria.
	local hasMission = false
	if buffer then
		for _, missions in pairs(buffer) do
			if type(missions) == "table" and next(missions) then
				hasMission = true
				break
			end
		end
	end

	if not hasMission then
		showDailyTierPicker(dailyPanel)
		return
	end

	if refreshRow then
		refreshRow:setVisible(true)
	end

	for dataType, dataInfo in pairs(buffer) do
		for index, dailyInfo in pairs(dataInfo) do
			local widget = g_ui.createWidget("TaskWidget", dailyPanel)
			local progress = 0
			if dailyInfo.progress and dailyInfo.progress > 0 then
				progress = dailyInfo.progress
			end

			-- killElement dailies show the element itself: the lookType the server sends is just a
			-- representative pokemon for that element, which tells the player less than the icon.
			local taskKind = dataType:match("^([^:]+)")
			local elementIndex = taskKind == "killElement"
				and ELEMENT_SHEET_INDEX[(dailyInfo.monsterName or ""):lower()] or nil
			local pokemonWidget = widget:recursiveGetChildById('pokemon')
			local elementWidget = widget:recursiveGetChildById('elementIcon')

			if elementIndex then
				pokemonWidget:setVisible(false)
				elementWidget:setImageSource(ELEMENT_SHEET)
				elementWidget:setImageClip({ x = 0, y = ELEMENT_SHEET_SIZE * (elementIndex - 1),
				                             width = ELEMENT_SHEET_SIZE, height = ELEMENT_SHEET_SIZE })
				elementWidget:setVisible(true)
			else
				-- no sheet row (or another task kind): keep the outfit rather than an empty square
				elementWidget:setVisible(false)
				pokemonWidget:setVisible(true)
				if dailyInfo.lookType and dailyInfo.lookType > 0 then
					pokemonWidget:setOutfit({type = dailyInfo.lookType})
				end
			end

			local status = progress >= dailyInfo.requiredCount or false
			if status then
				widget:recursiveGetChildById('status'):setImageSource('images/complete')
				widget:recursiveGetChildById('taskDescription'):setText("You already complete this Mission.")
				widget:setImageSource("/images/modules/guild/task_complete_base")
			else
				widget:setImageSource("/images/modules/guild/task_base")
				widget:recursiveGetChildById('status'):setImageSource('images/incomplete')
				local remainingCount = dailyInfo.requiredCount - progress
				-- "killElement:wildscape" -> kind = killElement, tier = wildscape
				local kind, tier = dataType:match("^([^:]+):?(.*)$")
				if kind == "killElement" then
					-- Aqui o campo monsterName do protocolo carrega o ELEMENTO (o sprite da linha vem
					-- do lookType, que o servidor resolve de um pokémon representativo).
					local element = dailyInfo.monsterName or ""
					element = element:sub(1, 1):upper() .. element:sub(2)
					local where = ""
					if tier and tier ~= "" then
						where = " in " .. tier:sub(1, 1):upper() .. tier:sub(2)
					end
					widget:recursiveGetChildById('taskDescription'):setText(
						"You still need to kill " .. remainingCount .. " " .. element .. " Pokemon" .. where .. ".")
				elseif kind == "killMonster" then
					local monsterName = dailyInfo.monsterName
					widget:recursiveGetChildById('taskDescription'):setText("You still need to kill " .. remainingCount .. " " .. monsterName..".")
				elseif dataType == "fish" then
					widget:recursiveGetChildById('taskDescription'):setText("You still need to fish " .. remainingCount .. " times.")
				end
			end
			widget:setVisible(true)
		end
	end
end

local dailyConfirmationWindow = nil

-- `choice` é o que vai no fio: "tier:elemento". tierLabel/elementLabel são só para o texto.
function showDailyConfirmation(choice, tierLabel, elementLabel)
	-- Verificar se jé existe uma janela de confirmaééo ativa
	if dailyConfirmationWindow then
		return
	end

	local title = "Daily Quest Selection"
	local message
	if tierLabel and elementLabel then
		message = "Do you want to start a " .. elementLabel .. " daily in " .. tierLabel .. "?"
			.. "\n\nYou will need to defeat " .. elementLabel .. " Pokemon in " .. tierLabel
			.. " areas. This choice can only be changed by resetting your dailies."
	else
		message = "Do you want to start " .. choice .. " daily quests?"
	end

	local yesCallback = function()
		g_game.sendDailyQuestSelection(choice)
		if dailyConfirmationWindow then
			dailyConfirmationWindow:destroy()
			dailyConfirmationWindow = nil
		end
	end
	
	local noCallback = function()
		if dailyConfirmationWindow then
			dailyConfirmationWindow:destroy()
			dailyConfirmationWindow = nil
		end
	end
	
	dailyConfirmationWindow = displayAllianceBox(
		title,
		message,
		{
			{text = "Yes", callback = yesCallback},
			{text = "No", callback = noCallback},
			anchor = AnchorHorizontalCenter
		},
		yesCallback,
		noCallback,
		guildWindow
	)
end

function confirmDailyWindowCleanup()
	if confirmDailyWindow then
		confirmDailyWindow:destroy()
		confirmDailyWindow = nil
	end
end

function confirmDailyWindowFunc()
	g_game.sendGuildResetDaily()
	confirmDailyWindowCleanup()
end

function resetDaily()
	if confirmDailyWindow then
		return
	end

	confirmDailyWindow = displayAllianceBox(tr('Confirm'), tr("Are you sure you want to reset your Dailies? This will cost you 1 reset guild daily ticket."), {
		{
			text = tr('Yes'),
			callback = confirmDailyWindowFunc
		},
		{
			text = tr('No'),
			callback = confirmDailyWindowCleanup
		},
		anchor = AnchorHorizontalCenter
	}, confirmDailyWindowFunc, confirmDailyWindowCleanup)
end

function stopBossRewardCycle()
	if bossRewardCycleEvent then
		bossRewardCycleEvent:cancel()
		bossRewardCycleEvent = nil
	end
end

local function cycleBossRewardItems()
	for _, entry in ipairs(bossRewardCycleSlots) do
		if #entry.clientIds > 1 then
			entry.currentIndex = (entry.currentIndex % #entry.clientIds) + 1
			local clientId = entry.clientIds[entry.currentIndex]
			if entry.widget and not entry.widget:isDestroyed() then
				entry.widget:setItemId(clientId)
			end
		end
	end
end

function startBossRewardCycle()
	if bossRewardCycleEvent then
		bossRewardCycleEvent:cancel()
		bossRewardCycleEvent = nil
	end
	if #bossRewardCycleSlots > 0 then
		bossRewardCycleEvent = cycleEvent(cycleBossRewardItems, 500)
	end
end

function parseGuildBosses()
	if not storageGuildInfo then
		return
	end
	local unlockedInfo = storageGuildInfo.activeBoss
	stopBossCooldown()
	stopBossRewardCycle()
	bossRewardCycleSlots = {}
	local bossesPanel = guildWindow:recursiveGetChildById('bossScrollArea')
	bossesPanel:destroyChildren()
	for index, config in ipairs(storageGuildInfo.bosses) do
		local widget = g_ui.createWidget("BossWidget", bossesPanel)
		widget.unlockBoss.onClick = nil
		widget:setId(config.bossName)
		widget.bossName:setText(config.bossName)
		widget.pokemon:setOutfit({type = config.lookType})
		widget.costLabel:setText("$" .. comma_value2(config.balanceCost or 0))
		widget.levelLabel:setText("Minimum Level: " .. (config.requiredLevel or 0))

		-- Populate reward slots with cycling
		if config.displaySlots then
			for _, slot in ipairs(config.displaySlots) do
				local clientIds = slot.clientIds or {}
				if #clientIds > 0 then
					local itemWidget = g_ui.createWidget("UIItem", widget.rewardsPanel)
					itemWidget:setSize({width = 28, height = 28})
					itemWidget:setItemId(clientIds[1])
					itemWidget:setItemCount(slot.count or 1)
					itemWidget:setPhantom(true)
					if config.rewardDescription and config.rewardDescription ~= "" then
						itemWidget:setTooltip(config.rewardDescription)
					end
					if #clientIds > 1 then
						table.insert(bossRewardCycleSlots, {
							widget = itemWidget,
							clientIds = clientIds,
							currentIndex = 1,
						})
					end
				end
			end
		end

		local text = "CLOSED"
		if storageMembership and storageMembership.level >= GUILDLEVEL_VICELEADER then
			text = "Unlock Boss"
			widget.unlockBoss:setImageSource("/images/newui/btnblue_large")
			widget.unlockBoss.onClick = function ()
				openGuildBoss(config.bossName)
			end
		end
		widget.unlockBoss:setText(text)
		if unlockedInfo then
			if unlockedInfo.bossName == config.bossName then
				widget.unlockBoss.endTime = os.time() + unlockedInfo.closeTime
				widget.unlockBoss:setText("JOIN: \n"..timeFormat(unlockedInfo.closeTime))
				widget.unlockBoss:setImageSource("/images/newui/btngreen_large")
				widget.unlockBoss.onClick = function ()
					joinGuildBoss()
				end
				startCooldown(widget)
			end
		end
	end
	startBossRewardCycle()
end

function startCooldown(bossWidget)
	if bossWidget.updateEvent then
		removeEvent(bossWidget.updateEvent)
		bossWidget.updateEvent = nil
	end
	updateCooldown(bossWidget, true)
	bossWidget.updateEvent = cycleEvent(function()
		updateCooldown(bossWidget)
	end, 1000)
end

function stopBossCooldown()
	if guildWindow then
		local bossesPanel = guildWindow:recursiveGetChildById('bossScrollArea')
		if bossesPanel and bossesPanel:getChildCount() > 0 then
			for i = 1, bossesPanel:getChildCount() do
				local buffWidget = bossesPanel:getChildByIndex(i)
				if buffWidget.updateEvent then
					removeEvent(buffWidget.updateEvent)
					buffWidget.updateEvent = nil
				end
			end
		end
	end
end

function updateCooldown(bossWidget, start)
	if not bossWidget or bossWidget:isDestroyed() then
		return
	end

	local duration = tonumber(bossWidget.unlockBoss.endTime)
	if not duration then
		if bossWidget.updateEvent then
			removeEvent(bossWidget.updateEvent)
			bossWidget.updateEvent = nil
		end
		parseGuildBosses()
		return
	end
	local leftTime = duration - os.time()
	if leftTime <= 0 then
		--parseGuildBosses()
		return
	end

	local durationText = timeFormat(leftTime)
	bossWidget.unlockBoss:setText("JOIN: \n"..durationText)
end

function confirmOpenBossWindowCleanup()
	if confirmOpenBossWindow then
		confirmOpenBossWindow:destroy()
		confirmOpenBossWindow = nil
	end
end

function confirmOpenBossWindowFunc()
	g_game.sendGuildOpenBoss(confirmOpenBossWindow.bossName)
	confirmOpenBossWindowCleanup()
end

function openGuildBoss(bossName)
	confirmOpenBossWindow = displayAllianceBox(tr('Confirm'), tr("Do you really want to open the guild boss battle? It's a battle in Pokéview mode in which you won't be able to change your Pokémon."), {
		{
			text = tr('Yes'),
			callback = confirmOpenBossWindowFunc
		},
		{
			text = tr('No'),
			callback = confirmOpenBossWindowCleanup
		},
		anchor = AnchorHorizontalCenter
	}, confirmOpenBossWindowFunc, confirmOpenBossWindowCleanup)
	confirmOpenBossWindow.bossName = bossName
end



function confirmJoinBossWindowCleanup()
	if confirmJoinBossWindow then
		confirmJoinBossWindow:destroy()
		confirmJoinBossWindow = nil
	end
end

function confirmJoinBossWindowFunc()
	g_game.sendGuildJoinBoss()
	confirmJoinBossWindowCleanup()
end

function joinGuildBoss()
	confirmJoinBossWindow = displayAllianceBox(tr('Confirm'), tr("Do you really want to join the guild boss battle? It's a battle in Pokéview mode in which you won't be able to change your Pokémon."), {
		{
			text = tr('Yes'),
			callback = confirmJoinBossWindowFunc
		},
		{
			text = tr('No'),
			callback = confirmJoinBossWindowCleanup
		},
		anchor = AnchorHorizontalCenter
	}, confirmJoinBossWindowFunc, confirmJoinBossWindowCleanup)
end

function handleGuildDisband(data)
	if data.success then
		disbandCleanup()
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		disbandCleanup()
	end
end

function disbandConfirm(self)
	windowDisableButtons(disbandWindow)
	g_game.sendGuildDisband()
end

function disbandCleanup()
	if disbandWindow then
		disbandWindow:destroy()
	end
end

function disbandConfirmation()
	disbandCleanup()
	disbandWindow = displayAllianceBox(tr('Confirm Disband'), tr('Are you sure you want to disband %s?', storageGuildInfo.name), {
		{
			text = tr('Yes'),
			callback = disbandConfirm
		},
		{
			text = tr('No'),
			callback = disbandCleanup
		},
		anchor = AnchorHorizontalCenter
	}, disbandConfirm, disbandCleanup)
end

function handleGuildPassLeadership(data)
	if data.success then
		passLeadershipCleanup()
		displayAllianceInfoBox("Success", data.message)
		return
	end

	errorBox = displayAllianceErrorBox(tr("Error"), data.errors[1])
	errorBox.onOk = function()
		errorBox = nil
		passLeadershipCleanup()
	end
end

function passLeadershipConfirm(self)
	windowDisableButtons(passLeadershipWindow)

	g_game.sendGuildPassLeadership(passLeadershipWindow.promoteMember.name)
end

function passLeadershipCleanup()
	if passLeadershipWindow then
		passLeadershipWindow:destroy()
	end
end

function passLeadershipConfirmation(member)
	passLeadershipCleanup()
	passLeadershipWindow = displayAllianceBox(tr('Confirm Promote'), tr('Are you sure you want to promote %s?', member.name), {
		{
			text = tr('Yes'),
			callback = passLeadershipConfirm
		},
		{
			text = tr('No'),
			callback = passLeadershipCleanup
		},
		anchor = AnchorHorizontalCenter
	}, passLeadershipConfirm, passLeadershipCleanup)
	passLeadershipWindow.promoteMember = member
end

function formatLastLogin(lastLogin)
	local brasiliaTime = lastLogin - 3 * 3600
	return os.date("%d/%m/%Y %H:%M:%S", brasiliaTime)
end

function onBankBalanceChange(localPlayer, value)
	if guildCreateWindow then
		guildCreateWindow:recursiveGetChildById("balanceValue"):setText("$"..comma_value2(value))
	end
end

function progressGuildBuff(widget)
	if not widget or not widget.index then
		return
	end

	g_game.sendGuildUpgradeBuff(widget.index)
end

function showBalanceGuildWindow()
	if not balanceWindow then
		return
	end

	balanceWindow.background.contribuitionPanel.cashPanel.cashItem:setItemId(37382)
	balanceWindow.background.contribuitionPanel.diamondPanel.diamondItem:setItemId(3028)
	balanceWindow:show()
	balanceWindow:focus()
end

function contributeGuildBalance(type)
	if contributeGuildBalanceWindow then
		return
	end

	local contributionType = (type == 2) and "Diamonds" or "Cash"
	local contributionCost = (type == 2) and diamondCost or "$100.000"

	local msg = tr("Are you sure you want to contribute %s (%s) to the Guild?", contributionCost, contributionType)

	contributeGuildBalanceWindow = displayAllianceBox(tr('Confirm Contribution'), msg, {
		{
			text = tr('Yes'),
			callback = confirmContributeGuildBalance
		},
		{
			text = tr('No'),
			callback = contributeGuildBalanceCleanup
		},
		anchor = AnchorHorizontalCenter
	}, confirmContributeGuildBalance, contributeGuildBalanceCleanup)

	contributeGuildBalanceWindow.type = type
end


function contributeGuildBalanceCleanup()
	if contributeGuildBalanceWindow then
		contributeGuildBalanceWindow:destroy()
		contributeGuildBalanceWindow = nil
	end
end

function confirmContributeGuildBalance()
	if not contributeGuildBalanceWindow or not contributeGuildBalanceWindow.type then
		return
	end

	g_game.sendGuildContribute(contributeGuildBalanceWindow.type)
	contributeGuildBalanceCleanup()
end

function onAutoWalk()
	closeShopWindow()
end