item_rarities = {}

raritis_base = {
  {"commum"}, -- #a4a4a4
  {"uncommum"}, -- #6abe30
  {"rare"}, -- #3089be
  {"epic"}, -- #8d00ee
  {"legendary"}, -- #d8b616
  {"mythical"}, -- #c31616
  {"bright"}, -- #f6ff68
}

channelPrefixes = {
    [0] = " [a](Default)[a/] ",
    [1] = " [s](Server Log)[s/] ",
	
    [9] = " [i](Help)[i/] ",
    [6] = " [y](Trade)[y/] ",
	
    [""] = " [q](Groups)[q/] ",
	
    [22] = " [t](Game PT)[t/] ",
    [23] = " [t](Game EN)[t/] ",
    [24] = " [t](Game ES)[t/] ",
    [25] = " [t](Game PL)[t/] ",
    [8] = " [t](RL Chat)[t/] ",
	
    [5] = " [p](Gamemaster)[p/] "
}

dataHexColors = {
  -- Tons de Cinza - Gray Colors
  {name = "Dim Gray", hex = "#696969", rgb = "(105,105,105)"},
  {name = "Gray", hex = "#808080", rgb = "(128,128,128)"},
  {name = "Dark Gray", hex = "#A9A9A9", rgb = "(169,169,169)"},
  {name = "Silver", hex = "#C0C0C0", rgb = "(192,192,192)"},
  {name = "Light Grey", hex = "#D3D3D3", rgb = "(211,211,211)"},
  {name = "Gainsboro", hex = "#DCDCDC", rgb = "(220,220,220)"},
  
  -- Tons de Azul - Blue Colors
  {name = "Slate Blue 1", hex = "#6A5ACD", rgb = "(106,90,205)"},
  {name = "Slate Blue 2", hex = "#836FFF", rgb = "(131,111,255)"},
  {name = "Slate Blue 3", hex = "#6959CD", rgb = "(105,89,205)"},
  {name = "Dark Slate Blue", hex = "#483D8B", rgb = "(72,61,139)"},
  {name = "Midnight Blue", hex = "#191970", rgb = "(25,25,112)"},
  {name = "Navy", hex = "#000080", rgb = "(0,0,128)"},
  {name = "Dark Blue", hex = "#00008B", rgb = "(0,0,139)"},
  {name = "Medium Blue", hex = "#0000CD", rgb = "(0,0,205)"},
  {name = "Blue", hex = "#0000FF", rgb = "(0,0,255)"},
  {name = "Cornflower Blue", hex = "#6495ED", rgb = "(100,149,237)"},
  {name = "Royal Blue", hex = "#4169E1", rgb = "(65,105,225)"},
  {name = "Dodger Blue", hex = "#1E90FF", rgb = "(30,144,255)"},
  {name = "Deep Sky Blue", hex = "#00BFFF", rgb = "(0,191,255)"},
  {name = "Light Sky Blue", hex = "#87CEFA", rgb = "(135,206,250)"},
  {name = "Sky Blue", hex = "#87CEEB", rgb = "(135,206,235)"},
  {name = "Light Blue", hex = "#ADD8E6", rgb = "(173,216,230)"},
  {name = "Steel Blue", hex = "#4682B4", rgb = "(70,130,180)"},
  {name = "Light Steel Blue", hex = "#B0C4DE", rgb = "(176,196,222)"},
  {name = "Slate Gray", hex = "#708090", rgb = "(112,128,144)"},
  {name = "Light Slate Gray", hex = "#778899", rgb = "(119,136,153)"},
  
  -- Tons de Ciano - Cyan Colors
  {name = "Aqua / Cyan", hex = "#00FFFF", rgb = "(0,255,255)"},
  {name = "Dark Turquoise", hex = "#00CED1", rgb = "(0,206,209)"},
  {name = "Turquoise", hex = "#40E0D0", rgb = "(64,224,208)"},
  {name = "Medium Turquoise", hex = "#48D1CC", rgb = "(72,209,204)"},
  {name = "Light Sea Green", hex = "#20B2AA", rgb = "(32,178,170)"},
  {name = "Dark Cyan", hex = "#008B8B", rgb = "(0,139,139)"},
  {name = "Teal", hex = "#008080", rgb = "(0,128,128)"},
  {name = "Aquamarine", hex = "#7FFFD4", rgb = "(127,255,212)"},
  {name = "Medium Aquamarine", hex = "#66CDAA", rgb = "(102,205,170)"},
  {name = "Cadet Blue", hex = "#5F9EA0", rgb = "(95,158,160)"},
  
  -- Tons de Verde - Green Colors
  {name = "Dark Slate Gray", hex = "#2F4F4F", rgb = "(47,79,79)"},
  {name = "Medium Spring Green", hex = "#00FA9A", rgb = "(0,250,154)"},
  {name = "Spring Green", hex = "#00FF7F", rgb = "(0,255,127)"},
  {name = "Pale Green", hex = "#98FB98", rgb = "(152,251,152)"},
  {name = "Light Green", hex = "#90EE90", rgb = "(144,238,144)"},
  {name = "Dark Sea Green", hex = "#8FBC8F", rgb = "(143,188,143)"},
  {name = "Medium Sea Green", hex = "#3CB371", rgb = "(60,179,113)"},
  {name = "Sea Green", hex = "#2E8B57", rgb = "(46,139,87)"},
  {name = "Dark Green", hex = "#006400", rgb = "(0,100,0)"},
  {name = "Green", hex = "#008000", rgb = "(0,128,0)"},
  {name = "Forest Green", hex = "#228B22", rgb = "(34,139,34)"},
  {name = "Lime Green", hex = "#32CD32", rgb = "(50,205,50)"},
  {name = "Lime", hex = "#00FF00", rgb = "(0,255,0)"},
  {name = "Lawn Green", hex = "#7CFC00", rgb = "(124,252,0)"},
  {name = "Chartreuse", hex = "#7FFF00", rgb = "(127,255,0)"},
  {name = "Green Yellow", hex = "#ADFF2F", rgb = "(173,255,47)"},
  {name = "Yellow Green", hex = "#9ACD32", rgb = "(154,205,50)"},
  {name = "Olive Drab", hex = "#6B8E23", rgb = "(107,142,35)"},
  {name = "Dark Olive Green", hex = "#556B2F", rgb = "(85,107,47)"},
  {name = "Olive", hex = "#808000", rgb = "(128,128,0)"},
  
  -- Tons de Marrom - Brown Colors
  {name = "Dark Khaki", hex = "#BDB76B", rgb = "(189,83,107)"},
  {name = "Goldenrod", hex = "#DAA520", rgb = "(218,165,32)"},
  {name = "Dark Goldenrod", hex = "#B8860B", rgb = "(184,134,11)"},
  {name = "Saddle Brown", hex = "#8B4513", rgb = "(139,69,19)"},
  {name = "Sienna", hex = "#A0522D", rgb = "(160,82,45)"},
  {name = "Rosy Brown", hex = "#BC8F8F", rgb = "(188,143,143)"},
  {name = "Peru", hex = "#CD853F", rgb = "(205,133,63)"},
  {name = "Chocolate", hex = "#D2691E", rgb = "(210,105,30)"},
  {name = "Sandy Brown", hex = "#F4A460", rgb = "(244,164,96)"},
  {name = "Navajo White", hex = "#FFDEAD", rgb = "(255,222,173)"},
  {name = "Wheat", hex = "#F5DEB3", rgb = "(245,222,179)"},
  {name = "Burly Wood", hex = "#DEB887", rgb = "(222,184,135)"},
  {name = "Tan", hex = "#D2B48C", rgb = "(210,180,140)"},
  
  -- Tons de Roxo - Purple Colors
  {name = "Medium Slate Blue", hex = "#7B68EE", rgb = "(123,104,238)"},
  {name = "Medium Purple", hex = "#9370DB", rgb = "(147,112,219)"},
  {name = "Blue Violet", hex = "#8A2BE2", rgb = "(138,43,226)"},
  {name = "Indigo", hex = "#4B0082", rgb = "(75,0,130)"},
  {name = "Dark Violet", hex = "#9400D3", rgb = "(148,0,211)"},
  {name = "Dark Orchid", hex = "#9932CC", rgb = "(153,50,204)"},
  {name = "Medium Orchid", hex = "#BA55D3", rgb = "(186,85,211)"},
  {name = "Purple", hex = "#A020F0", rgb = "(128,0,128)"},
  {name = "Dark Magenta", hex = "#8B008B", rgb = "(139,0,139)"},
  {name = "Fuchsia / Magenta", hex = "#FF00FF", rgb = "(255,0,255)"},
  {name = "Violet", hex = "#EE82EE", rgb = "(238,130,238)"},
  {name = "Orchid", hex = "#DA70D6", rgb = "(218,112,214)"},
  {name = "Plum", hex = "#DDA0DD", rgb = "(221,160,221)"},
  
  -- Tons de Rosa - Pink Colors
  {name = "Medium Violet Red", hex = "#C71585", rgb = "(199,21,133)"},
  {name = "Deep Pink", hex = "#FF1493", rgb = "(255,20,147)"},
  {name = "Hot Pink", hex = "#FF69B4", rgb = "(255,105,180)"},
  {name = "Pale Violet Red", hex = "#DB7093", rgb = "(219,112,147)"},
  {name = "Light Pink", hex = "#FFB6C1", rgb = "(255,182,193)"},
  {name = "Pink", hex = "#FFC0CB", rgb = "(255,192,203)"},
  {name = "Light Coral", hex = "#F08080", rgb = "(240,128,128)"},
  {name = "Indian Red", hex = "#CD5C5C", rgb = "(205,92,92)"},
  {name = "Crimson", hex = "#DC143C", rgb = "(220,20,60)"},
  
  -- Tons de Vermelho - Red Colors
  {name = "Maroon", hex = "#800000", rgb = "(128,0,0)"},
  {name = "Dark Red", hex = "#8B0000", rgb = "(139,0,0)"},
  {name = "Fire Brick", hex = "#B22222", rgb = "(178,34,34)"},
  {name = "Brown", hex = "#A52A2A", rgb = "(165,42,42)"},
  {name = "Salmon", hex = "#FA8072", rgb = "(250,128,114)"},
  {name = "Dark Salmon", hex = "#E9967A", rgb = "(233,150,122)"},
  {name = "Light Salmon", hex = "#FFA07A", rgb = "(255,160,122)"},
  {name = "Coral", hex = "#FF7F50", rgb = "(255,127,80)"},
  {name = "Tomato", hex = "#FF6347", rgb = "(255,99,71)"},
  {name = "Red", hex = "#FF0000", rgb = "(255,0,0)"},
  
  -- Tons de Laranja - Orange Colors
  {name = "Orange Red", hex = "#FF4500", rgb = "(255,69,0)"},
  {name = "Dark Orange", hex = "#FF8C00", rgb = "(255,140,0)"},
  {name = "Orange", hex = "#FFA500", rgb = "(255,165,0)"},
  
  -- Tons de Amarelo - Yellow Colors
  {name = "Gold", hex = "#FFD700", rgb = "(255,215,0)"},
  {name = "Yellow", hex = "#FFFF00", rgb = "(255,255,0)"},
  {name = "Khaki", hex = "#F0E68C", rgb = "(240,230,140)"},
  
  -- Tons Pastel - Light Colors
  {name = "Alice Blue", hex = "#F0F8FF", rgb = "(240,248,255)"},
  {name = "Ghost White", hex = "#F8F8FF", rgb = "(248,248,255)"},
  {name = "Snow", hex = "#FFFAFA", rgb = "(255,250,250)"},
  {name = "Seashell", hex = "#FFF5EE", rgb = "(255,245,238)"},
  {name = "Floral White", hex = "#FFFAF0", rgb = "(255,250,240)"},
  {name = "White Smoke", hex = "#F5F5F5", rgb = "(245,245,245)"},
  {name = "Beige", hex = "#F5F5DC", rgb = "(245,245,220)"},
  {name = "Old Lace", hex = "#FDF5E6", rgb = "(253,245,230)"},
  {name = "Ivory", hex = "#FFFFF0", rgb = "(255,255,240)"},
  {name = "Linen", hex = "#FAF0E6", rgb = "(250,240,230)"},
  {name = "Cornsilk", hex = "#FFF8DC", rgb = "(255,248,220)"},
  {name = "Antique White", hex = "#FAEBD7", rgb = "(250,235,215)"},
  {name = "Blanched Almond", hex = "#FFEBCD", rgb = "(255,235,205)"},
  {name = "Bisque", hex = "#FFE4C4", rgb = "(255,228,196)"},
  {name = "Light Yellow", hex = "#FFFFE0", rgb = "(255,255,224)"},
  {name = "Lemon Chiffon", hex = "#FFFACD", rgb = "(255,250,205)"},
  {name = "Light Goldenrod Yellow", hex = "#FAFAD2", rgb = "(250,250,210)"},
  {name = "Papaya Whip", hex = "#FFEFD5", rgb = "(255,239,213)"},
  {name = "Peach Puff", hex = "#FFDAB9", rgb = "(255,218,185)"},
  {name = "Moccasin", hex = "#FFE4B5", rgb = "(255,228,181)"},
  {name = "Pale Goldenrod", hex = "#EEE8AA", rgb = "(238,232,170)"},
  {name = "Misty Rose", hex = "#FFE4E1", rgb = "(255,228,225)"},
  {name = "Lavender Blush", hex = "#FFF0F5", rgb = "(255,240,245)"},
  {name = "Lavender", hex = "#E6E6FA", rgb = "(230,230,250)"},
  {name = "Thistle", hex = "#D8BFD8", rgb = "(216,191,216)"},
  {name = "Azure", hex = "#F0FFFF", rgb = "(240,255,255)"},
  {name = "Light Cyan", hex = "#E0FFFF", rgb = "(224,255,255)"},
  {name = "Powder Blue", hex = "#B0E0E6", rgb = "(176,224,230)"},
  {name = "Pale Turquoise", hex = "#E0FFFF", rgb = "(175,238,238)"},
  {name = "Honeydew", hex = "#F0FFF0", rgb = "(240,255,240)"},
  {name = "MintCream", hex = "#F5FFFA", rgb = "(245,255,250)"},
}

rarityColors = {
  ["P"] = "#a9a9a9",  -- Um tom de cinza escuro.
  ["c"] = "#a4a4a4",  -- Um tom de cinza claro.
  ["u"] = "#6abe30",  -- Um tom de verde claro.
  ["r"] = "#3089be",  -- Um tom de azul médio.
  ["e"] = "#8d00ee",  -- Um tom de roxo intenso.
  ["l"] = "#d8b616",  -- Um tom de amarelo dourado.
  ["m"] = "#c31616",  -- Um tom de vermelho escuro.
  ["b"] = "#f6ff68",  -- Um tom de amarelo claro.
  ["d"] = "#3cff00",  -- Um tom de verde claro brilhante.
  ["o"] = "#ff4800",  -- Um tom de laranja escuro.
  ["q"] = "#ca3b03",  -- Um tom de laranja queimado.
  ["v"] = "#ff8604",  -- Um tom de laranja claro.
  ["w"] = "#bffdff",  -- Um tom de azul claro.
  ["t"] = "#82a9d0",  -- Um tom de azul claro acinzentado.
  ["y"] = "#e6b843",  -- Um tom de amarelo alaranjado.
  ["i"] = "#8aca6f",  -- Um tom de verde claro amarelado.
  ["p"] = "#ca6f6f",  -- Um tom de rosa claro.
  ["a"] = "#bcca6f",  -- Um tom de verde amarelado.
  ["s"] = "#6fca91",  -- Um tom de verde azulado claro.
  ["j"] = "#ff0000",  -- Um tom de vermelho claro.
  ["X"] = "#00b4ff",  -- Um tom de azul claro e brilhante.
  ["M"] = "#9262ad",  -- 
  ["B"] = "#ff4c4c",  -- 
  ["F"] = "#14ff8a",  -- 
  ["L"] = "#ffffff",  -- 
  
  ["N"] = "#43caf6",  -- 
  ["n"] = "#32a5cb",  -- 

  -- COLOR BY TYPE
  ["1"] = "#A8A878", -- Normal
  ["2"] = "#F08030", -- Fire
  ["3"] = "#6890F0", -- Water
  ["4"] = "#F8D030", -- Electric
  ["5"] = "#78C850", -- Grass
  ["6"] = "#98D8D8", -- Ice
  ["7"] = "#C03028", -- Fighting
  ["8"] = "#A040A0", -- Poison
  ["9"] = "#E0C068", -- Ground
  ["Q"] = "#A890F0", -- Flying
  ["W"] = "#F85888", -- Psychic
  ["E"] = "#A8B820", -- Bug
  ["R"] = "#B8A038", -- Rock
  ["T"] = "#705898", -- Ghost
  ["Y"] = "#7038F8", -- Dragon
  ["U"] = "#705848", -- Dark
  ["I"] = "#B8B8D0", -- Steel
  ["O"] = "#EE99AC", -- Fairy
}

typeIdColors = {
  ["normal"] = "1",
  ["fire"] = "2",
  ["water"] = "3",
  ["electric"] = "4", 
  ["grass"] = "5",
  ["ice"] = "6",
  ["fighting"] = "7",
  ["poison"] = "8",
  ["ground"] = "9",
  ["flying"] = "Q",
  ["psychic"] = "W",
  ["bug"] = "E",
  ["rock"] = "R",
  ["ghost"] = "T",
  ["dragon"] = "Y",
  ["dark"] = "U",
  ["steel"] = "I",
  ["fairy"] = "O",
}




function doSetColoredColor(widget, text, colorBase)
    local NewText = highlightText(text)
    local highlightData = getLootColorByRarity(NewText, colorBase, rarityColors)
    if #highlightData > 2 then
      widget:setColoredText(highlightData)
	else
      widget:setText(text)
    end
end

function splitText(inputstr, sep)
  if not inputstr then
    return {}
  end

    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function highlightLoot(text)
  local items = text:match(": (.*)"):gsub(",?%s+and%s+", ", "):split(", ")
  local highlightedItems = {}
  for i, item in ipairs(items) do
    local rarity = item_rarities[item] or "commum"
	
	if string.match(item, "%d") then
       rarity = item_rarities[string.sub(item, 3, 9999)] or "commum"
	end
	
    local raritySymbol = "[" .. string.sub(rarity, 1, 1) .. "]"
    local raritySymbolEnd = "[" .. string.sub(rarity, 1, 1) .. "/]"
    table.insert(highlightedItems, raritySymbol .. item .. raritySymbolEnd)
  end
  local highlightedText = table.concat(highlightedItems, ", ")
  return text:gsub(": (.*)$", ": " .. highlightedText) 
end

function getLootColorByRarity(text, color, rarityColors)
  local tmpData = {}
  
  for i, part in ipairs(splitText(text, "[")) do
    if i == 1 then
      table.insert(tmpData, part)
      table.insert(tmpData, color)
    else
      local rarityEndIndex = part:find("%]")
      if rarityEndIndex and rarityColors[part:sub(1, rarityEndIndex-1)] then
        local rarity = part:sub(1, rarityEndIndex-1)
        local remainingText = part:sub(rarityEndIndex+1, -1)
        table.insert(tmpData, remainingText)
        table.insert(tmpData, rarityColors[rarity])
      else
	    local addPart = string.sub(part, 4, 9999)
        table.insert(tmpData, "")
        table.insert(tmpData, color)
        table.insert(tmpData, addPart)
        table.insert(tmpData, color)
      end
    end
  end

  return tmpData
end

function highlightDAMAGE(text)
  return text:gsub("(%d+:%d+) You lose (%d+) hitpoints due to an attack by a ([^%.]+)%.", "%1 You lose [o]%2 hitpoints[o/] due to an attack by a [r]%3[r/].")
end
function highlightHitDAMAGE(text)
  return text:gsub("(%d+:%d+)%s(.+)%sloses%s(%d+)%s(hitpoint[s]*)%sdue%s+to%s+your%s+attack%.", "%1 [r]%2[r/] loses [o]%3 hitpoints[o/] due to your attack.")
end
function highlightHitDAMAGE2(text)
  return text:gsub("(%d+:%d+)%sYou%slost%s(%d+)%shitpoint[s]*%sdue%sto%san%sattack%sfrom%s(.+)%.", "%1 [o]Você perdeu %2 pontos de vida[o/] devido a um ataque de [r]%3[r/].")
end
function highlightHitDAMAGE3(text)
  return text:gsub("(%d+:%d+)%sYou%slose%s(%d+)%shitpoints.", "%1 [o]Você perdeu %2 pontos de vida[o].")
end
function highlightHitDAMAGE4(text)
  return text:gsub("(%d+:%d+)%sYou%slose%s(%d+)%shitpoint.", "%1 [o]Você perdeu %2 ponto de vida[o].")
end

function highlightLostEXP(text)
  return text:gsub("(%d+:%d+)%sYou've%sfainted%sand%slost%s(%d+%.%d+)%sexperience.", "%1 [r]Infelizmente, você desmaiou[r/] e [o]perdeu %2 pontos de experiência[o/]. [g] Mantenha a calma, respire fundo e tente novamente. Você é capaz![g/]")
end



function highlightSAVING(text)
  local minutesLeft = text:match("Server is saving game in (%d+) minute[s]?%.")
  local plural = minutesLeft ~= "1" and "s" or ""
  local highlightedText = text:gsub("Server is saving game in (%d+) minute[s]?%.", "[l]Server is saving game in "..minutesLeft.." minute"..plural..".[/l]")
  highlightedText = highlightedText:gsub("Please mind it may freeze%.", "[w]Please mind it may freeze.[/w]")
  return highlightedText
end
function highlightMENTION(text)
  return text:gsub("@(%S+%s?%S*)", "[l]%1[l/]"):gsub("%[l%]@","[l]"):gsub("%[l/%]@","[l/]")
end
function highlightText(text)
  return text:gsub("@(%S+%s?%S*)", "[l]%1[l/]"):gsub("%[l%]@","[l]"):gsub("%[l/%]@","[l/]")
end

function highlightLinks(text)
  local httpPattern = "http://[%w-_%.%?%.:/%+=&]+"
  local httpsPattern = "https://[%w-_%.%?%.:/%+=&]+"
  local highlighted = text:gsub(httpPattern, "[m]%0[m/]")
  highlighted = highlighted:gsub(httpsPattern, "[r]%0[r/]")
  return highlighted
end