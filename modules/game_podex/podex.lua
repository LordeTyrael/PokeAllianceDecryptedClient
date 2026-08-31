local MainWindow, MainButton, DifficultyPanel, TypePanel, ListPanel
local Current = {skills = {}, category = 0, difficulty = 1}
local loaded = false
local podex = {}
podex.config = {
  opcode = 10,
}
podex.category = {
  active = 0,
  offensive = 1,
  defensive = 2,
  character = 3,
  others = 4,
}
podex.diff = {
  comum = 1,
  medium = 2,
  hard = 3,
  extreme = 4,
}

local function onGameStart()
  if not MainWindow then return end
  MainWindow:hide() 
end

local function onGameEnd()
  if not MainWindow then return end
  MainWindow:hide()
  loaded = false
end

local function connecting(gameEvent)
  -- TODO: Just connect when you will be using
  if gameEvent then
  	connect(g_game, {
  	  onGameEnd = onGameEnd,
  	  onGameStart = onGameStart
  	})
  end

  ProtocolGame.registerExtendedJSONOpcode(podex.config.opcode, parsePodex)
  return true
end

local function disconnecting(gameEvent)
  -- TODO: Just disconnect when you will be using
  if gameEvent then
  	connect(g_game, {
  	  onGameEnd = onGameEnd,
  	  onGameStart = onGameStart
  	})
  end

  ProtocolGame.unregisterExtendedJSONOpcode(podex.config.opcode)
  return true
end

function init()
  connecting(true)
  MainWindow = g_ui.loadUI("podex", modules.game_interface.getRootPanel())
  MainButton = modules.client_topmenu.addMiddleGameToggleButton('podexButton', tr('Podex') .. ' ', '/images/ui/topbuttons/icons/podex', toggle)
  MainButton:setOn(false)
  DifficultyPanel = MainWindow:getChildById('difficultyPanel')
  TypePanel = MainWindow:getChildById('typePanel')
  ListPanel = MainWindow:getChildById('listPanel')
 
  if g_game.isOnline() then onGameStart() end
end

function terminate()
  -- Removing the connectors
  disconnecting(true)

  MainWindow:destroy()
  MainWindow = nil
  MainButton:destroy()
  MainButton = nil
end

function toggle()
  if MainButton:isOn() then
    MainWindow:hide()
    MainButton:setOn(false)
  else
    if not loaded then
      g_game.getProtocolGame():sendExtendedOpcode(podex.config.opcode, json.encode({protocol = "request"}))
      loaded = true
    else
      MainWindow:show()
      MainButton:setOn(true)
	end
  end
end

function show()
  MainWindow:show()
  MainButton:setOn(true)
end

function hide()
  MainWindow:hide()
  MainButton:setOn(false)
end

function parsePodex(protocol, opcode, buffer)
  local receive = buffer
  if receive.protocol == "skills" then
    if receive.first then
      Current.skills = {}
	  ListPanel:destroyChildren()
	end
	for n, skill in ipairs(receive.skills) do
	  table.insert(Current.skills, skill)
	end
  elseif receive.protocol == "draw" then
    DifficultyPanel:getChildById('comum'):focus()
    TypePanel:getChildById('offensive'):focus()
	drawPodex()
    MainWindow:show()
    MainButton:setOn(true)
  end
end

function drawPodex()
  ListPanel:destroyChildren()
  for n, skill in ipairs(Current.skills) do
    if ((Current.category == 0 and skill.level >= 1) or skill.category == Current.category) and skill.diff == Current.difficulty then
	  local widget = g_ui.createWidget("PodexWidget", ListPanel)
	  widget:getChildById('icon'):setImageSource("/game_podex/images/icons/"..skill.category.."/"..skill.diff.."/"..skill.id)
	  widget:getChildById('name'):setText(skill.name.." Lvl. "..skill.level.."")
    if skill.level <= 0 then
      widget:getChildById('name'):setText(skill.name.."")      
    end
    if (Current.category == 1 or Current.category == 2) then
    local textPodex = (string.format(skill.description, skill.bonus[skill.level == 0 and 1 or skill.level]).."%.")
    widget:getChildById('desc'):setText(textPodex)
    else
	  widget:getChildById('desc'):setText(string.format(skill.description, skill.bonus[skill.level == 0 and 1 or skill.level]))
    end

	  if skill.level+1 <= #skill.recipe then
	    widget:getChildById('upgrade'):setVisible(true)
	    widget:getChildById('upgrade').onClick = function()
		  local params = {protocol = "upgrade", category =  skill.category, diff = skill.diff, id = skill.id}
		  g_game.getProtocolGame():sendExtendedOpcode(podex.config.opcode, json.encode(params))
		end
        for i, item in ipairs(skill.recipe[skill.level+1]) do
          local idget = g_ui.createWidget("UIItem", widget:getChildById('items'))
          idget:setItemId(item[3])
          idget:setItemCount(item[2])
          idget:setTooltip(item[4])
          idget:setFont("verdana-11px-rounded")
          idget:setVirtual(true)
        end
	  end
	end
  end
end

function toggleDifficulty(difficulty)
  if not loaded then return end
  if difficulty == Current.difficulty then return end
  Current.difficulty = difficulty
  drawPodex()
end

function toggleCategory(category)
  if not loaded then return end
  if category == Current.category then return end
  Current.category = category
  drawPodex()
end