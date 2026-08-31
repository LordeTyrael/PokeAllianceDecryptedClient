-- Outfit Displacement Manager - Sistema C++ Direto
-- Usa apenas g_game.updateOutfitDisplacement() sem OTML

OffsetManager = {}

local offsetWindow = nil
local offsetButton = nil
local outfitWidget = nil
local currentDirection = nil
local currentDisplacementType = nil
local modifiedOutfits = {} -- Para tracking das alterações

local function validateNumericInput(inputWidget)
  inputWidget:setText(inputWidget:getText():gsub("[^%d%-]", ""))
end

local offsets = {
    ["left"] = { offsetX = 0, offsetY = 0 },
    ["right"] = { offsetX = 0, offsetY = 0 },
    ["up"] = { offsetX = 0, offsetY = 0 },
    ["down"] = { offsetX = 0, offsetY = 0 }
}

function init()
  g_ui.importStyle('offset.otui')

  -- Verifica se a API está disponível
  if not g_game.updateOutfitDisplacement then
    print("[OffsetManager] ERRO: updateOutfitDisplacement não está disponível!")
    return
  end

  offsetButton = modules.client_topmenu.addLeftGameButton(
    'offsetButton', 
    tr('Outfit Displacement'), 
    '/images/topbuttons/offset',  
    OffsetManager.toggle, 
    false, 
    1
  )

  offsetWindow = g_ui.createWidget('OffsetWindow', modules.game_interface.getRootPanel())

  setupInterface()
  outfitWidget = offsetWindow:recursiveGetChildById('outfitView')

  outfitWidget:hide()
  offsetWindow:hide()

  setupNumericFields()
  setupIdInputValidation()

  local movementCheck = offsetWindow:recursiveGetChildById('movement')
  movementCheck.onCheckChange = function(checkBox, checked)
    if outfitWidget:isVisible() then
      outfitWidget:setAnimate(checked)
    end
  end
  
  OffsetManager.bindKeys()
end

function OffsetManager.toggleDirection(direction)
  if currentDirection == direction then
    return
  end

  if currentDirection then
    local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
    local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
    local prevOffsetX = tonumber(offsetXField:getText()) or 0
    local prevOffsetY = tonumber(offsetYField:getText()) or 0
    offsets[currentDirection].offsetX = prevOffsetX
    offsets[currentDirection].offsetY = prevOffsetY
  end

  currentDirection = direction

  local offsetX = offsets[direction].offsetX or 0
  local offsetY = offsets[direction].offsetY or 0
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  offsetXField:setText(tostring(offsetX))
  offsetYField:setText(tostring(offsetY))

  local checkUp = offsetWindow:recursiveGetChildById('checkUp')
  local checkRight = offsetWindow:recursiveGetChildById('checkRight')
  local checkDown = offsetWindow:recursiveGetChildById('checkDown')
  local checkLeft = offsetWindow:recursiveGetChildById('checkLeft')

  checkUp:setChecked(direction == 'up')
  checkRight:setChecked(direction == 'right')
  checkDown:setChecked(direction == 'down')
  checkLeft:setChecked(direction == 'left')

  if outfitWidget:isVisible() then
    local directions = {
      up = Directions.North,
      right = Directions.East,
      down = Directions.South,
      left = Directions.West
    }

    local newDirection = directions[direction]
    if newDirection then
      outfitWidget:setDirection(newDirection)
    end
  end
end

function OffsetManager.applyOffsetToAllDirections()
  local offsetX = tonumber(offsetWindow:recursiveGetChildById('offsetX'):getText()) or 0
  local offsetY = tonumber(offsetWindow:recursiveGetChildById('offsetY'):getText()) or 0

  offsets["up"].offsetX = offsetX
  offsets["up"].offsetY = offsetY
  offsets["right"].offsetX = offsetX
  offsets["right"].offsetY = offsetY
  offsets["down"].offsetX = offsetX
  offsets["down"].offsetY = offsetY
  offsets["left"].offsetX = offsetX
  offsets["left"].offsetY = offsetY

  updateOffsetFields()
  
  -- Aplica automaticamente se for um outfit
  local selectedOption = offsetWindow:getChildById('offsetComboBox'):getText()
  if selectedOption == 'Outfit' then
    OffsetManager.saveOffset()
  end
end



function OffsetManager.openWithLooktype(looktype)
  OffsetManager.toggle()

  local offsetComboBox = offsetWindow:getChildById('offsetComboBox')
  if offsetComboBox then
    offsetComboBox:setCurrentOption('Outfit')
  end

  local idInput = offsetWindow:getChildById('idInput')
  if idInput then
    idInput:setText(tostring(looktype))
  end

  OffsetManager.viewOffset()
end

function OffsetManager.showInfo()
  local apiAvailable = g_game.updateOutfitDisplacement and tr("YES") or tr("NO")

  local message = tr("Outfit Displacement Manager") .. "\n\n" ..
    tr("API updateOutfitDisplacement: %s", apiAvailable) .. "\n\n"

  if g_game.updateOutfitDisplacement then
    message = message ..
      tr("FEATURES:") .. "\n" ..
      tr("• Applies offsets in real time as you adjust") .. "\n" ..
      tr("• Use arrows (Shift+Arrow) for fine adjustment") .. "\n" ..
      tr("• Use Ctrl+Arrow to switch directions") .. "\n" ..
      tr("• Click 'Apply' to save all directions") .. "\n" ..
      tr("• Click 'Apply All' to apply the same offset to all directions") .. "\n" ..
      tr("• Click 'Dump' to view all modified outfits") .. "\n\n" ..
      tr("DISPLACEMENT TYPES:") .. "\n" ..
      tr("• Outfit Displacement: Move only the outfit (name stays in place)") .. "\n" ..
      tr("• Name Displacement: Move only the name (outfit stays in place)") .. "\n" ..
      tr("• Target Displacement: Move only the outfit (name stays in place)") .. "\n\n" ..
      tr("TIPS:") .. "\n" ..
      tr("• Offsets are applied directly in C++") .. "\n" ..
      tr("• SubOutfits work with the ID2 field") .. "\n" ..
      tr("• Use DUMP to generate C++ code of the changes")
  else
    message = message ..
      tr("ERROR: The updateOutfitDisplacement API is not available!") .. "\n" ..
      tr("This module requires the C++ function to work.")
  end

  displayInfoBox(tr("Help - Outfit Displacement"), message)
end

function OffsetManager.dumpModifications()
  if next(modifiedOutfits) == nil then
    displayInfoBox(tr("Dump"), tr("No modifications have been made yet."))
    return
  end
  
  local dumpText = "// Modificações feitas pelo Offset Manager\n"
  dumpText = dumpText .. "// Adicione estas linhas ao outfitdisplacement.cpp\n"
  dumpText = dumpText .. "// Gerado em: " .. os.date("%d/%m/%Y %H:%M:%S") .. "\n\n"
  
  local count = 0
  for outfitId, data in pairs(modifiedOutfits) do
    
    -- Consultar valores atuais diretamente do C++
    local directions = {
      {"up", "Otc::North", Directions.North},
      {"right", "Otc::East", Directions.East}, 
      {"down", "Otc::South", Directions.South},
      {"left", "Otc::West", Directions.West}
    }
    
    local lines = {}
    local hasNonZero = false
    
    for _, dirPair in ipairs(directions) do
      local dirName = dirPair[1]
      local dirConstant = dirPair[2]
      local dirValue = dirPair[3]
      
      -- Buscar valores atuais do C++
      local outfitOffsetX, outfitOffsetY = 0, 0
      local nameOffsetX, nameOffsetY = 0, 0
      
      if g_game.getOutfitDisplacement then
        local outfitPoint = g_game.getOutfitDisplacement(outfitId, dirValue)
        if outfitPoint then
          outfitOffsetX = outfitPoint.x or 0
          outfitOffsetY = outfitPoint.y or 0
        end
      end
      
      if g_game.getNameDisplacement then
        local namePoint = g_game.getNameDisplacement(outfitId, dirValue)
        if namePoint then
          nameOffsetX = namePoint.x or 0
          nameOffsetY = namePoint.y or 0
        end
      end
      
      -- Verificar se há algum offset configurado
      if outfitOffsetX ~= 0 or outfitOffsetY ~= 0 or nameOffsetX ~= 0 or nameOffsetY ~= 0 then
        hasNonZero = true
        table.insert(lines, string.format("            { %s, { %d, %d, %d, %d } }", 
          dirConstant, outfitOffsetX, outfitOffsetY, nameOffsetX, nameOffsetY))
      end
    end
    
    if hasNonZero then
      count = count + 1
      dumpText = dumpText .. string.format("    {%d, {\n", outfitId)
      
      if #lines > 0 then
        dumpText = dumpText .. table.concat(lines, ",\n") .. "\n"
      end
      
      dumpText = dumpText .. "        }},\n"
    end
  end
  
  -- Criar diretório dumps se não existir e gerar nome do arquivo
  local dumpDir = "modules/game_offset/dumps"
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local filename = string.format("%s/outfit_displacement_dump_%s.txt", dumpDir, timestamp)
  
  -- Tentar criar o diretório e escrever o arquivo
  local success, errorMsg = pcall(function()
    -- Criar diretório se não existir (funciona no Windows)    
    local file = io.open(filename, "w")
    if file then
      file:write(dumpText)
      file:close()
      return true
    else
      error("Não foi possível criar o arquivo")
    end
  end)
  
  if success then
    if count > 0 then
      -- Contar tipos de displacement encontrados
      local outfitCount, nameCount = 0, 0
      for outfitId, data in pairs(modifiedOutfits) do
        -- Verificar quais tipos têm offsets configurados
        local directions = { Directions.North, Directions.East, Directions.South, Directions.West }
        for _, dir in ipairs(directions) do
          if g_game.getOutfitDisplacement then
            local outfitPoint = g_game.getOutfitDisplacement(outfitId, dir)
            if outfitPoint and (outfitPoint.x ~= 0 or outfitPoint.y ~= 0) then
              outfitCount = 1  -- Pelo menos um outfit displacement
              break
            end
          end
        end
        
        for _, dir in ipairs(directions) do
          if g_game.getNameDisplacement then
            local namePoint = g_game.getNameDisplacement(outfitId, dir)
            if namePoint and (namePoint.x ~= 0 or namePoint.y ~= 0) then
              nameCount = 1  -- Pelo menos um name displacement
              break
            end
          end
        end
      end
      
      -- Limpar as modificações após dump bem-sucedido
      modifiedOutfits = {}
      
      local message = tr("File created successfully!\n\nLocation: %s\n\nC++ code generated for %d outfit(s).", filename, count)
      if outfitCount > 0 or nameCount > 0 then
        message = message .. "\n\n" .. tr("Included types:")
        if outfitCount > 0 then message = message .. "\n" .. tr("• Outfit Displacement") end
        if nameCount > 0 then message = message .. "\n" .. tr("• Name Displacement") end
      end
      message = message .. "\n\n" .. tr("Modifications list has been cleared.")

      displayInfoBox(tr("Dump Generated"), message)
    else
      displayInfoBox(tr("Dump"), tr("No valid modifications found to generate file."))
    end
  else
    displayInfoBox(tr("Error"), tr("Error creating file:\n%s\n\nAttempted to save in: %s", errorMsg or tr("Unknown error"), filename))
  end
end

function OffsetManager.clearModifications()
  local count = 0
  for _ in pairs(modifiedOutfits) do
    count = count + 1
  end
  
  if count > 0 then
    modifiedOutfits = {}
    displayInfoBox(tr("Cleanup"), tr("Modifications list cleared!\n\n%d outfit(s) removed from list.", count))
  else
    displayInfoBox(tr("Cleanup"), tr("There are no modifications to clear."))
  end
end


function onMovementChange(checkBox, checked)
  previewCreature:setAnimate(checked)
  settings.movement = checked
end

function updateCheckboxes(selectedDirection)
  local checkUp = offsetWindow:recursiveGetChildById('checkUp')
  local checkRight = offsetWindow:recursiveGetChildById('checkRight')
  local checkDown = offsetWindow:recursiveGetChildById('checkDown')
  local checkLeft = offsetWindow:recursiveGetChildById('checkLeft')

  checkUp:setChecked(selectedDirection == 'up')
  checkRight:setChecked(selectedDirection == 'right')
  checkDown:setChecked(selectedDirection == 'down')
  checkLeft:setChecked(selectedDirection == 'left')
end


function setupIdInputValidation()
  local idInput = offsetWindow:getChildById('idInput')
  idInput.onTextChange = function() validateNumericInput(idInput) end
end

function terminate()
  if offsetWindow then offsetWindow:destroy() end
  if offsetButton then offsetButton:destroy() end
end

function OffsetManager.toggle()
  if offsetWindow:isVisible() then
    offsetWindow:hide()
    offsetButton:setOn(false)
  else
    offsetWindow:show()
    offsetWindow:raise()
    offsetWindow:focus()
    offsetButton:setOn(true)
  end
end

function setupInterface()
  local displacementTypeComboBox = offsetWindow:getChildById('displacementTypeComboBox')
  
  -- Apenas opções de displacement para outfits
  displacementTypeComboBox:addOption(tr("Outfit Displacement"), "Outfit Displacement")
  displacementTypeComboBox:addOption(tr("Name Displacement"),   "Name Displacement")
  displacementTypeComboBox:addOption(tr("Target Displacement"), "Target Displacement")

  displacementTypeComboBox.onOptionChange = function(_, option)
    currentDisplacementType = option
    -- Carrega os valores existentes para o novo tipo
    OffsetManager.loadExistingValues()
  end
  
  -- Inicializar com Outfit Displacement
  currentDisplacementType = "Outfit Displacement"
end


function OffsetManager.loadExistingValues()
  -- Carrega os valores existentes no C++ baseado no tipo de displacement selecionado
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local subId = tonumber(offsetWindow:getChildById('subIdInput') and offsetWindow:getChildById('subIdInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()
  
  if not id or id <= 0 then
    return -- Sem ID válido, não há o que carregar
  end
  
  local useSubOutfit = isSubOutfitChecked and subId and subId > 0
  local outfitId = useSubOutfit and subId or id
  local displacementType = currentDisplacementType
  
  -- Mapeamento das direções
  local directions = {
    up = Directions.North,
    right = Directions.East,
    down = Directions.South,
    left = Directions.West
  }
  
  -- Carrega valores para todas as direções
  for dirName, dirValue in pairs(directions) do
    local offsetX, offsetY = 0, 0
    
    if displacementType == 'Outfit Displacement' or displacementType == 'Target Displacement' then
      -- Para Outfit/Target Displacement, busca os valores da outfit
      if g_game.getOutfitDisplacement then
        local point = g_game.getOutfitDisplacement(outfitId, dirValue)
        if point then
          offsetX = point.x or 0
          offsetY = point.y or 0
        end
      end
    elseif displacementType == 'Name Displacement' then
      -- Para Name Displacement, busca os valores do nome
      if g_game.getNameDisplacement then
        local point = g_game.getNameDisplacement(outfitId, dirValue)
        if point then
          offsetX = point.x or 0
          offsetY = point.y or 0
        end
      end
    end
    
    -- Atualiza a estrutura local
    offsets[dirName].offsetX = offsetX
    offsets[dirName].offsetY = offsetY
  end
  
  -- Atualiza os campos da interface para a direção atual
  if currentDirection then
    local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
    local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
    
    if offsetXField and offsetYField then
      offsetXField:setText(tostring(offsets[currentDirection].offsetX))
      offsetYField:setText(tostring(offsets[currentDirection].offsetY))
    end
  end
end

function OffsetManager.bindKeys()
  local rootPanel = modules.game_interface.getRootPanel()

  g_keyboard.bindKeyPress('Shift+Up', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onUp()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Shift+Down', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onDown()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Shift+Left', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onLeft()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Shift+Right', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onRight()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Up', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('up')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Down', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('down')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Left', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('left')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Right', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('right')
    end
  end, rootPanel)
end


function OffsetManager.onUp()
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
  local currentY = tonumber(offsetYField:getText()) or 0
  offsetYField:setText(tostring(currentY + 1))
  OffsetManager.applyCurrentOffset()
  OffsetManager.saveOffset()
end

function OffsetManager.onDown()
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
  local currentY = tonumber(offsetYField:getText()) or 0
  offsetYField:setText(tostring(currentY - 1))
  OffsetManager.applyCurrentOffset()
  OffsetManager.saveOffset()
end

function OffsetManager.onLeft()
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local currentX = tonumber(offsetXField:getText()) or 0
  offsetXField:setText(tostring(currentX + 1))
  OffsetManager.applyCurrentOffset()
  OffsetManager.saveOffset()
end

function OffsetManager.onRight()
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local currentX = tonumber(offsetXField:getText()) or 0
  offsetXField:setText(tostring(currentX - 1))
  OffsetManager.applyCurrentOffset()
  OffsetManager.saveOffset()
end


function setupNumericFields()
  local panel = offsetWindow:getChildById('OffsetPanel')

  local numericFields = {'offsetX', 'offsetY'}
  for _, fieldId in ipairs(numericFields) do
    local field = panel:getChildById(fieldId)
    if field then
      field.onTextChange = function() 
        validateNumericInput(field)
        -- Aplica o offset em tempo real
        OffsetManager.applyCurrentOffset()
      end
    end
  end
end



function updateOffsetFields()
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  if not currentDirection then
    return
  end

  local currentOffsetX = offsets[currentDirection].offsetX or 0
  local currentOffsetY = offsets[currentDirection].offsetY or 0

  offsetXField:setText(tostring(currentOffsetX))
  offsetYField:setText(tostring(currentOffsetY))
end

function OffsetManager.loadAndShowOutfit(outfitId)
  if not outfitId or outfitId == 0 then
    outfitWidget:hide()
    return
  end

  local outfit = { type = outfitId, head = 78, body = 68, legs = 58, feet = 76, direction = currentDirection }
  outfitWidget:show()
  outfitWidget:setOutfit(outfit)
end



function OffsetManager.viewOffset()
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local subId = tonumber(offsetWindow:getChildById('subIdInput') and offsetWindow:getChildById('subIdInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()

  if not id or id <= 0 then
    return
  end

  local useSubOutfit = isSubOutfitChecked and subId and subId > 0
  local outfitId = useSubOutfit and subId or id

  -- Carregar valores existentes do C++
  OffsetManager.loadExistingValues()
  
  OffsetManager.loadAndShowOutfit(outfitId)
  OffsetManager.toggleDirection("down")
  
  -- Mostrar preview
  outfitWidget:show()
  offsetWindow:getChildById('preview'):show()
end

function OffsetManager.deleteOffset()
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local subId = tonumber(offsetWindow:getChildById('subIdInput') and offsetWindow:getChildById('subIdInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()

  if not id or id <= 0 then
    displayErrorBox(tr("Error"), tr("Please enter a valid ID to delete."))
    return
  end

  if not g_game.updateOutfitDisplacement then
    displayErrorBox(tr("Error"), tr("The updateOutfitDisplacement function is not available."))
    return
  end

  local useSubOutfit = isSubOutfitChecked and subId and subId > 0
  local outfitId = useSubOutfit and subId or id
  
  -- Resetar todos os offsets para zero usando a API
  local directions = {
    Directions.North,
    Directions.East,
    Directions.South,
    Directions.West
  }
  
  for _, dir in ipairs(directions) do
    g_game.updateOutfitDisplacement(outfitId, dir, 0, 0, 0, 0)
  end
  
  -- Remover do tracking local
  modifiedOutfits[outfitId] = nil
  
  -- Resetar os offsets locais também
  offsets["up"].offsetX, offsets["up"].offsetY = 0, 0
  offsets["right"].offsetX, offsets["right"].offsetY = 0, 0
  offsets["down"].offsetX, offsets["down"].offsetY = 0, 0
  offsets["left"].offsetX, offsets["left"].offsetY = 0, 0
  
  updateOffsetFields()
  
  displayInfoBox(tr("Reset"), tr("Outfit %d reset successfully!", outfitId))
end


-- Todas as funções OTML foram removidas - sistema C++ direto


function OffsetManager.applyCurrentOffset()
  -- Aplica apenas o offset da direção atual em tempo real
  if not g_game.updateOutfitDisplacement then
    return -- API não disponível
  end
  
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local subId = tonumber(offsetWindow:getChildById('subIdInput') and offsetWindow:getChildById('subIdInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()
  
  if not id or id <= 0 or not currentDirection then
    return
  end
  
  local selectedOption = offsetWindow:getChildById('offsetComboBox'):getText()
  local displacementType = offsetWindow:getChildById('displacementTypeComboBox'):getText()
  
  if selectedOption == 'Outfit' then
    local useSubOutfit = isSubOutfitChecked and subId and subId > 0
    local outfitId = useSubOutfit and subId or id
    
    local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
    local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
    local offsetX = tonumber(offsetXField:getText()) or 0
    local offsetY = tonumber(offsetYField:getText()) or 0
    
    -- Salva na estrutura local
    offsets[currentDirection].offsetX = offsetX
    offsets[currentDirection].offsetY = offsetY
    
    -- Converte direção
    local directions = {
      up = Directions.North,
      right = Directions.East,
      down = Directions.South,
      left = Directions.West
    }
    
    local dirValue = directions[currentDirection]
    if dirValue then
      -- Buscar valores existentes para preservar os outros tipos
      local existingOutfitPoint = g_game.getOutfitDisplacement and g_game.getOutfitDisplacement(outfitId, dirValue)
      local existingNamePoint = g_game.getNameDisplacement and g_game.getNameDisplacement(outfitId, dirValue)
      
      local outfitOffsetX = (existingOutfitPoint and existingOutfitPoint.x) or 0
      local outfitOffsetY = (existingOutfitPoint and existingOutfitPoint.y) or 0
      local nameOffsetX = (existingNamePoint and existingNamePoint.x) or 0
      local nameOffsetY = (existingNamePoint and existingNamePoint.y) or 0
      
      -- Atualizar apenas o tipo sendo editado, preservando os outros
      if displacementType == 'Outfit Displacement' then
        -- Atualiza apenas outfit, preserva name existente
        outfitOffsetX = offsetX
        outfitOffsetY = offsetY
        -- nameOffsetX e nameOffsetY mantêm valores existentes
      elseif displacementType == 'Name Displacement' then
        -- Atualiza apenas name, preserva outfit existente
        nameOffsetX = offsetX
        nameOffsetY = offsetY
        -- outfitOffsetX e outfitOffsetY mantêm valores existentes
      elseif displacementType == 'Target Displacement' then
        -- Atualiza apenas outfit, zera name
        outfitOffsetX = offsetX
        outfitOffsetY = offsetY
        nameOffsetX = 0
        nameOffsetY = 0
      end

      g_game.updateOutfitDisplacement(outfitId, dirValue, outfitOffsetX, outfitOffsetY, nameOffsetX, nameOffsetY)
    end
  end
end

function OffsetManager.saveOffset()
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local subId = tonumber(offsetWindow:getChildById('subIdInput') and offsetWindow:getChildById('subIdInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()

  if not id or id <= 0 then
    displayErrorBox(tr("Error"), tr("Please enter a valid ID to save."))
    return
  end

  if not g_game.updateOutfitDisplacement then
    displayErrorBox(tr("Error"), tr("The updateOutfitDisplacement function is not available."))
    return
  end

  local displacementType = offsetWindow:getChildById('displacementTypeComboBox'):getText()

  -- Salva o offset atual na direção selecionada
  if currentDirection then
    local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
    local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
    local offsetX = tonumber(offsetXField:getText()) or 0
    local offsetY = tonumber(offsetYField:getText()) or 0
    offsets[currentDirection].offsetX = offsetX
    offsets[currentDirection].offsetY = offsetY
  end

  local useSubOutfit = isSubOutfitChecked and subId and subId > 0
  local outfitId = useSubOutfit and subId or id

  -- Converte as direções do módulo para as constantes do jogo
  local directions = {
    up = Directions.North,
    right = Directions.East,
    down = Directions.South,
    left = Directions.West
  }

  -- Aplica os offsets para todas as direções
  for dirName, dirValue in pairs(directions) do
    local offsetX = offsets[dirName].offsetX or 0
    local offsetY = offsets[dirName].offsetY or 0
    
    -- Buscar valores existentes para preservar os outros tipos
    local existingOutfitPoint = g_game.getOutfitDisplacement and g_game.getOutfitDisplacement(outfitId, dirValue)
    local existingNamePoint = g_game.getNameDisplacement and g_game.getNameDisplacement(outfitId, dirValue)
    
    local outfitOffsetX = (existingOutfitPoint and existingOutfitPoint.x) or 0
    local outfitOffsetY = (existingOutfitPoint and existingOutfitPoint.y) or 0
    local nameOffsetX = (existingNamePoint and existingNamePoint.x) or 0
    local nameOffsetY = (existingNamePoint and existingNamePoint.y) or 0
    
    -- Atualizar apenas o tipo sendo editado, preservando os outros
    if displacementType == 'Outfit Displacement' then
      -- Atualiza apenas outfit, preserva name existente
      outfitOffsetX = offsetX
      outfitOffsetY = offsetY
      -- nameOffsetX e nameOffsetY mantêm valores existentes
    elseif displacementType == 'Name Displacement' then
      -- Atualiza apenas name, preserva outfit existente
      nameOffsetX = offsetX
      nameOffsetY = offsetY
      -- outfitOffsetX e outfitOffsetY mantêm valores existentes
    elseif displacementType == 'Target Displacement' then
      -- Atualiza apenas outfit, zera name
      outfitOffsetX = offsetX
      outfitOffsetY = offsetY
      nameOffsetX = 0
      nameOffsetY = 0
    end
    
    -- Chama a função do Game para atualizar o displacement
    g_game.updateOutfitDisplacement(outfitId, dirValue, outfitOffsetX, outfitOffsetY, nameOffsetX, nameOffsetY)
  end

  -- Adicionar ao tracking (preservando configurações anteriores)
  if not modifiedOutfits[outfitId] then
    modifiedOutfits[outfitId] = {
      displacementTypes = {},
      lastModified = os.time()
    }
  end
  
  -- Salvar o tipo atual sendo editado
  modifiedOutfits[outfitId].displacementTypes[displacementType] = {
    up = {offsetX = offsets["up"].offsetX, offsetY = offsets["up"].offsetY},
    right = {offsetX = offsets["right"].offsetX, offsetY = offsets["right"].offsetY},
    down = {offsetX = offsets["down"].offsetX, offsetY = offsets["down"].offsetY},
    left = {offsetX = offsets["left"].offsetX, offsetY = offsets["left"].offsetY}
  }
  
  modifiedOutfits[outfitId].lastModified = os.time()
end

function OffsetManager.resetOffset()
  offsetWindow:recursiveGetChildById('offsetX'):setText('0')
  offsetWindow:recursiveGetChildById('offsetY'):setText('0')

  outfitWidget:hide()

  offsets["up"].offsetX = 0
  offsets["up"].offsetY = 0
  offsets["right"].offsetX = 0
  offsets["right"].offsetY = 0
  offsets["down"].offsetX = 0
  offsets["down"].offsetY = 0
  offsets["left"].offsetX = 0
  offsets["left"].offsetY = 0

  offsetWindow:recursiveGetChildById('idInput'):setText('')
end

-- ========================================
-- SISTEMA DE SINCRONIZAÇÃO DE DIREÇÃO 
-- ========================================

local directionSyncEnabled = false
local playerDirectionConnection = nil
local targetConnection = nil

-- Função para obter todas as criaturas visíveis na tela
local function getAllVisibleCreatures()
    local creatures = {}
    local player = g_game.getLocalPlayer()
    if not player then return creatures end
    
    local playerPos = player:getPosition()
    local range = 15 -- Range de visão (ajuste conforme necessário)
    
    -- Percorrer tiles em volta do jogador
    for x = playerPos.x - range, playerPos.x + range do
        for y = playerPos.y - range, playerPos.y + range do
            local pos = {x = x, y = y, z = playerPos.z}
            local tile = g_map.getTile(pos)
            if tile then
                local creatures_on_tile = tile:getCreatures()
                for i = 1, #creatures_on_tile do
                    local creature = creatures_on_tile[i]
                    if creature and creature ~= player and not creature:isLocalPlayer() then
                        table.insert(creatures, creature)
                    end
                end
            end
        end
    end
    
    return creatures
end

-- Função para sincronizar direção de todas as criaturas
local function syncAllCreaturesDirection(direction)
    if not directionSyncEnabled or not offsetWindow:isVisible() then
        return
    end
    
    local creatures = getAllVisibleCreatures()
    for i = 1, #creatures do
        local creature = creatures[i]
        if creature then
            creature:setDirection(direction)
        end
    end
    
    print("[OffsetManager] Sincronizou direção {direction} para {#creatures} criaturas")
end

-- Função para detectar mudança de direção do jogador
local function onPlayerDirectionChange(player, direction, prevDirection)
    if directionSyncEnabled and offsetWindow:isVisible() then
        scheduleEvent(function()
            syncAllCreaturesDirection(direction)
        end, 50) -- Pequeno delay para garantir que a direção foi aplicada
    end
end

-- Função para capturar mudança de target
local function onTargetChange(creature, oldCreature)
    if not directionSyncEnabled or not offsetWindow:isVisible() then
        return
    end
    
    if creature then
        local outfit = creature:getOutfit()
        if outfit then
            local looktype = outfit.type
            if looktype and looktype > 0 then
                -- Preencher automaticamente o ID com o looktype da criatura targetada
                local idInput = offsetWindow:recursiveGetChildById('idInput')
                if idInput then
                    idInput:setText(tostring(looktype))
                    print("[OffsetManager] Auto-preenchido ID: " .. looktype .. " da criatura targetada: " .. creature:getName())
                    
                    -- Carregar automaticamente o outfit para visualização
                    scheduleEvent(function()
                        OffsetManager.viewOffset()
                    end, 100)
                end
            end
        end
    end
end

-- Hook adicional para capturar target manual (clique com botão direito)
local originalAttack = g_game.attack
g_game.attack = function(creature, ...)
    local result = originalAttack(creature, ...)
    
    -- Capturar target manual quando sync estiver ativo
    if directionSyncEnabled and offsetWindow:isVisible() and creature then
        scheduleEvent(function()
            onTargetChange(creature, nil)
        end, 50)
    end
    
    return result
end

-- Hook no g_game.turn para capturar turns manuais
local originalTurn = g_game.turn
g_game.turn = function(direction, ...)
    local result = originalTurn(direction, ...)
    
    -- Sincronizar criaturas após turn manual
    if directionSyncEnabled and offsetWindow:isVisible() then
        scheduleEvent(function()
            syncAllCreaturesDirection(direction)
        end, 100)
    end
    
    return result
end

-- Função para habilitar/desabilitar sincronização
function OffsetManager.toggleDirectionSync()
    directionSyncEnabled = not directionSyncEnabled
    
    if directionSyncEnabled then
        -- Conectar ao evento de mudança de direção
        if not playerDirectionConnection then
            playerDirectionConnection = connect(LocalPlayer, { 
                onTurn = onPlayerDirectionChange 
            })
        end
        
        -- Conectar ao evento de mudança de target
        if not targetConnection then
            targetConnection = connect(g_game, {
                onAttackingCreatureChange = onTargetChange
            })
        end
        
        -- Iniciar sincronização periódica
        startPeriodicSync()
        
        print("[OffsetManager] Sincronização de direção e auto-target HABILITADA")
        
        -- Sincronizar direção atual
        local player = g_game.getLocalPlayer()
        if player then
            syncAllCreaturesDirection(player:getDirection())
        end
    else
        -- Desconectar eventos
        if playerDirectionConnection then
            disconnect(playerDirectionConnection)
            playerDirectionConnection = nil
        end
        
        if targetConnection then
            disconnect(targetConnection)
            targetConnection = nil
        end
        
        -- Parar sincronização periódica
        stopPeriodicSync()
        
        print("[OffsetManager] Sincronização de direção e auto-target DESABILITADA")
    end
    
    -- Atualizar UI
    local syncButton = offsetWindow:recursiveGetChildById('directionSyncButton')
    if syncButton then
        syncButton:setText(directionSyncEnabled and 'Sync ON' or 'Sync OFF')
        syncButton:setColor(directionSyncEnabled and '#00FF00' or '#FF0000')
    end
end

-- Função para forçar sincronização manual
function OffsetManager.forceSyncDirection()
    local player = g_game.getLocalPlayer()
    if player then
        local direction = player:getDirection()
        syncAllCreaturesDirection(direction)
        print(f("[OffsetManager] Sincronização manual executada - Direção: {direction}"))
    end
end

-- Função para verificar se target atual pode ser usado
function OffsetManager.useCurrentTarget()
    local attackingCreature = g_game.getAttackingCreature()
    if attackingCreature then
        onTargetChange(attackingCreature, nil)
    else
        print("[OffsetManager] Nenhuma criatura está sendo targetada no momento")
    end
end

-- Timer para manter sincronização periódica (opcional)
local syncTimer = nil
function startPeriodicSync()
    if syncTimer then
        removeEvent(syncTimer)
    end
    
    syncTimer = cycleEvent(function()
        if directionSyncEnabled and offsetWindow:isVisible() then
            local player = g_game.getLocalPlayer()
            if player then
                syncAllCreaturesDirection(player:getDirection())
            end
        end
    end, 1000) -- A cada 1 segundo
end

local function stopPeriodicSync()
    if syncTimer then
        removeEvent(syncTimer)
        syncTimer = nil
    end
end

-- Limpar recursos no terminate
local originalTerminate = terminate
function terminate()
    -- Limpar conexões
    if playerDirectionConnection then
        disconnect(playerDirectionConnection)
        playerDirectionConnection = nil
    end
    
    if targetConnection then
        disconnect(targetConnection)
        targetConnection = nil
    end
    
    -- Parar timer
    stopPeriodicSync()
    
    -- Restaurar funções originais
    if originalTurn then
        g_game.turn = originalTurn
    end
    
    if originalAttack then
        g_game.attack = originalAttack
    end
    
    -- Chamar terminate original se existir
    if originalTerminate then
        originalTerminate()
    end
end
