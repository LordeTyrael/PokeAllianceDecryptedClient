local categoryTabBar
local weekly
local weeklyTab
local daily
local dailyTab
local challenges
local challengesTab

local _parseMissions
local _setupWeeklyMissions
local _setupDailyMissions
local _setupChallengeMissions

local _onTabChange

local dailyMissions
local weeklyMissions
local challengeMissions

function createMissionsCategoryTab(missions)
  categoryTabBar = missions:getChildById('categoryTabBar')
  categoryTabBar:setContentWidget(missions:getChildById('missionsCategoryContent'))
  categoryTabBar.onTabChange = _onTabChange

  weekly = g_ui.loadUI('missionsweekly')
  weeklyTab = categoryTabBar:addTab(tr('Weekly'), weekly, nil, true)

  daily = g_ui.loadUI('missionsdaily')
  dailyTab = categoryTabBar:addTab(tr('Daily'), daily, nil, true)

  challenges = g_ui.loadUI('missionschallenges')
  challengesTab = categoryTabBar:addTab(tr('Challenges'), challenges, nil, true)
end

function getSelectedMissionCategory()
  local currentTab = categoryTabBar:getCurrentTab()
  if currentTab == weeklyTab then
    return weekly:getId()
  elseif currentTab == dailyTab then
    return daily:getId()
  elseif currentTab == challengesTab then
    return challenges:getId()
  end
end

function setupMissions(category, missions)
  _parseMissions(missions)

  if category == weekly:getId() then
    _setupWeeklyMissions(missions)
  elseif category == daily:getId() then
    _setupDailyMissions(missions)
  elseif category == challenges:getId() then
    _setupChallengeMissions(missions)
  end
end

function _parseMissions(missions)
  table.sort(missions, function(a, b)
    return a.progress > b.progress
  end)
  for _, mission in ipairs(missions) do
    local descriptionArgs = mission.descriptionArgs
    if descriptionArgs then
      for name, value in pairs(descriptionArgs) do
        mission.description = mission.description:gsub(string.format("|%s|", name), value)
      end
    end
  end
end

function _setupWeeklyMissions(missions)
  local accumulateCheckBox = weekly:getChildById('accumulate')
  local accumulate = not accumulateCheckBox:isChecked()
  accumulateCheckBox:enable()

  local loading = weekly:getChildById('loading')

  local missionsContainer = weekly:getChildById('missions')
  missionsContainer:destroyChildren()
  missionsContainer:hide()

  if table.empty(missions) then
    weekly:getChildById('info'):show()
    loading:hide()
    return
  end

  weekly:getChildById('info'):hide()
  loading:show()

  local missionsPanel = { }

  for _, mission in ipairs(missions) do
    local missionId = mission.id
    local missionPanel = missionsPanel[missionId]

    if not accumulate or not missionPanel then
      missionPanel = g_ui.createWidget('WeeklyMissionPanel', missionsContainer)

      local descriptionLabel = missionPanel:recursiveGetChildById('description')
      descriptionLabel:setText(mission.description)

      local expLabel = missionPanel:recursiveGetChildById('exp')
      expLabel:setText(mission.exp)

      local count = mission.count
      local progress = mission.progress

      local progressLabel = missionPanel:getChildById('progress')
      progressLabel:setText(string.format("%d/%d", progress, count))

      missionsPanel[missionId] = missionPanel
    elseif accumulate then
      local missionAccumulatePanel = missionPanel:getChildById('accumulate')
      local count = tonumber(missionAccumulatePanel:getText())

      count = count + 1
      missionAccumulatePanel:setText(count)

      if count > 1 then
        missionAccumulatePanel:show()
      end
    end
  end

  loading:hide()
  missionsContainer:show()
  weeklyMissions = missions
end

function _setupDailyMissions(missions)
  local accumulateCheckBox = daily:getChildById('accumulate')
  local accumulate = not accumulateCheckBox:isChecked()
  accumulateCheckBox:enable()

  local loading = daily:getChildById('loading')

  local missionsContainer = daily:getChildById('missions')
  missionsContainer:destroyChildren()
  missionsContainer:hide()

  if table.empty(missions) then
    daily:getChildById('info'):show()
    loading:hide()
    return
  end

  daily:getChildById('info'):hide()
  loading:show()  

  local missionsPanel = { }

  for _, mission in ipairs(missions) do
    local missionId = mission.id
    local missionPanel = missionsPanel[missionId]

    if not accumulate or not missionPanel then
      missionPanel = g_ui.createWidget('WeeklyMissionPanel', missionsContainer)

      local descriptionLabel = missionPanel:recursiveGetChildById('description')
      descriptionLabel:setText(mission.description)

      local expLabel = missionPanel:recursiveGetChildById('exp')
      expLabel:setText(mission.exp)

      local count = mission.count
      local progress = mission.progress

      local progressLabel = missionPanel:getChildById('progress')
      progressLabel:setText(string.format("%d/%d", progress, count))

      missionsPanel[missionId] = missionPanel
    elseif accumulate then
      local missionAccumulatePanel = missionPanel:getChildById('accumulate')
      local count = tonumber(missionAccumulatePanel:getText())

      count = count + 1
      missionAccumulatePanel:setText(count)

      if count > 1 then
        missionAccumulatePanel:show()
      end
    end
  end

  loading:hide()
  missionsContainer:show()
  dailyMissions = missions
end

function _setupChallengeMissions(missions)
  local accumulateCheckBox = challenges:getChildById('accumulate')
  local accumulate = not accumulateCheckBox:isChecked()
  accumulateCheckBox:enable()

  local loading = challenges:getChildById('loading')

  local missionsContainer = challenges:getChildById('missions')
  missionsContainer:destroyChildren()
  missionsContainer:hide()

  if table.empty(missions) then
    challenges:getChildById('info'):show()
    loading:hide()
    return
  end

  challenges:getChildById('info'):hide()
  loading:show()

  local missionsPanel = { }

  for _, mission in ipairs(missions) do
    local missionId = mission.id
    local missionPanel = missionsPanel[missionId]

    if not accumulate or not missionPanel then
      missionPanel = g_ui.createWidget('ChallengeMissionPanel', missionsContainer)
      missionPanel:setText(mission.title)

      local count = mission.count
      local progress = mission.progress

      local progressLabel = missionPanel:getChildById('progress')
      progressLabel:setText(string.format("%d/%d", progress, count))

      local descriptionLabel = missionPanel:getChildById('description')
      descriptionLabel:setText(mission.description)

      local expPanel = missionPanel:getChildById('exp')
      expPanel:setText(mission.exp)

      missionsPanel[missionId] = missionPanel
    elseif accumulate then
      local missionAccumulatePanel = missionPanel:getChildById('accumulate')
      local count = tonumber(missionAccumulatePanel:getText())

      count = count + 1
      missionAccumulatePanel:setText(count)

      if count > 1 then
        missionAccumulatePanel:show()
      end
    end
  end

  loading:hide()
  missionsContainer:show()
  challengeMissions = missions
end

function _onTabChange(tabBar, currentTab)
  if currentTab == weeklyTab then
    weekly:getChildById('missions'):hide()
  elseif currentTab == dailyTab then
    weekly:getChildById('missions'):hide()
  elseif currentTab == challengesTab then
    challenges:getChildById('missions'):hide()
  end

  addEvent(function()
    sendMissionsRequest()
  end)
end

function toggleDailyAccumulate()
  if not daily then
    return
  end
  _setupDailyMissions(dailyMissions)
end

function toggleWeeklyAccumulate()
  if not weekly then
    return
  end
  _setupWeeklyMissions(weeklyMissions)
end

function toggleChallengesAccumulate()
  if not challenges then
    return
  end
  _setupChallengeMissions(challengeMissions)
end
