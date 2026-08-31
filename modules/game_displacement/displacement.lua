local displacementWindow
local selectedOutfit = 370
local selectedDirection = 1

function init()
  connect(g_game, {
    onGameStart = showWindow,
    onGameEnd = hideWindow
  })
end

function terminate()
  disconnect(g_game, {
    onGameEnd = hideWindow
  })
end

function showWindow()
  if 1 == 1 then return end
  if not displacementWindow then
    displacementWindow = g_ui.loadUI('displacement', modules.game_interface.getRootPanel())
    displacementWindow.sendButton.onClick = saveUpdateDisplacement
  end

  displacementWindow:show()
  displacementWindow:raise()
  displacementWindow:focus()
  loadOutfitDisplacement(selectedOutfit, selectedDirection)
end

function setDirection(index)
    local direction = index - 1
    selectedDirection = direction
    loadOutfitDisplacement(selectedOutfit, selectedDirection)
end

function hideWindow()
  if displacementWindow then
    displacementWindow:hide()
  end
end

function loadOutfitDisplacement(outfitId, direction)
    if not displacementWindow then return end
    selectedOutfit = outfitId
    local outfit = { type = outfitId }
    displacementWindow.creatureOutfit:setOutfit(outfit)
    displacementWindow.creatureOutfit:setDirection(direction)

    local outfitDisp = g_game.getOutfitDisplacement(outfitId, direction)
    local nameDisp = g_game.getNameDisplacement(outfitId, direction)
    
    displacementWindow.outfitDispX:setText(tostring(outfitDisp.x))
    displacementWindow.outfitDispY:setText(tostring(outfitDisp.y))
    displacementWindow.nameDispX:setText(tostring(nameDisp.x))
    displacementWindow.nameDispY:setText(tostring(nameDisp.y))
end

function sendDisplacementUpdate()
    if not displacementWindow then return end
    local x = tonumber(displacementWindow.outfitDispX:getText())
    local y = tonumber(displacementWindow.outfitDispY:getText())
    local nx = tonumber(displacementWindow.nameDispX:getText())
    local ny = tonumber(displacementWindow.nameDispY:getText())

    if not x or not y or not nx or not ny then
        return
    end

    g_game.updateOutfitDisplacement(selectedOutfit, selectedDirection, x, y, nx, ny)
    loadOutfitDisplacement(selectedOutfit, selectedDirection)
end

function saveUpdateDisplacement()
  local filepath = "modules/game_displacement/displacements.txt"
  local file = io.open(filepath, "a+")

  if not file then
    perror("Não foi possível abrir ou criar o arquivo de displacements.")
    return
  end

  for direction = 0, 3 do
    local outfitDisp = g_game.getOutfitDisplacement(selectedOutfit, direction)
    local nameDisp = g_game.getNameDisplacement(selectedOutfit, direction)

    local line = string.format("{%d, {%d, {%d, %d, %d, %d}}}\n",
      selectedOutfit,
      direction,
      outfitDisp.x, outfitDisp.y,
      nameDisp.x, nameDisp.y
    )
    file:write(line)
  end
  file:write("\n")
  file:close()
  print(string.format("Displacements do looktype %d salvos.", selectedOutfit))
end