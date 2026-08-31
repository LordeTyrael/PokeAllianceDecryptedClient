local function listDirectoryFilesRecursive(directory)
  local files = g_resources.listDirectoryFiles(directory)
  local allFiles = {}

  -- Itera sobre todos os arquivos encontrados no diretório
  for _, file in pairs(files) do
    local fullPath = directory .. '/' .. file

    -- Verifica se o arquivo tem uma extensão, se não tiver, assumimos que é um diretório
    if not file:find('%.') then
      -- Se for um diretório, chama recursivamente
      local subDirFiles = listDirectoryFilesRecursive(fullPath)
      for _, subFile in pairs(subDirFiles) do
        table.insert(allFiles, subFile)
      end
    else
      -- Se for um arquivo (tem extensão), adiciona à lista de arquivos
      table.insert(allFiles, fullPath)
    end
  end

  return allFiles
end

function init()
  local files
  local loaded_files = {}
  local layout = g_resources:getLayout()
  
  local style_files = {}
  if layout:len() > 0 then
    loaded_files = {}
    files = g_resources.listDirectoryFiles('/layouts/' .. layout .. '/styles')
    for _,file in pairs(files) do
      if g_resources.isFileType(file, 'otui') then
        table.insert(style_files, file)
        loaded_files[file] = true
      end
    end  
  end
  
  files = g_resources.listDirectoryFiles('/data/styles')
  for _,file in pairs(files) do
    if g_resources.isFileType(file, 'otui') and not loaded_files[file] then
        table.insert(style_files, file)
    end
  end

  table.sort(style_files)
  for _,file in pairs(style_files) do
    if g_resources.isFileType(file, 'otui') then
      g_ui.importStyle('/styles/' .. file)
    end
  end

  if layout:len() > 0 then
    files = g_resources.listDirectoryFiles('/layouts/' .. layout .. '/fonts')
    loaded_files = {}
    for _,file in pairs(files) do
      if g_resources.isFileType(file, 'otfont') then
        g_fonts.importFont('/layouts/' .. layout .. '/fonts/' .. file)
        loaded_files[file] = true
      end
    end
  end

  local files = listDirectoryFilesRecursive('/data/fonts')
  for _, file in pairs(files) do
    if g_resources.isFileType(file, 'otfont') then
      g_fonts.importFont(file)
    end
  end

  g_mouse.loadCursors('/data/cursors/cursors')
  if layout:len() > 0 and g_resources.directoryExists('/layouts/' .. layout .. '/cursors/cursors') then
    g_mouse.loadCursors('/layouts/' .. layout .. '/cursors/cursors')    
  end
end

function terminate()
end

