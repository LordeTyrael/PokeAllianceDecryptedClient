-- Icones das marcas do minimapa, em Font Awesome no lugar dos PNG /images/game/minimap/flagN.
--
-- ⚠️ A ORDEM AQUI E A NOSSA (MAPMARK_* de src/enums.h), nao a da PokeXGames. A lista deles bate nos
-- 4 primeiros e diverge do 5o em diante -- eles usam checkmark/question/exclamation/star/pointup...,
-- enquanto o padrao (e o que o servidor envia no byte markType) e
-- tick/question/exclamation/star/cross/temple/kiss/shovel/... Copiar por indice trocaria os icones.
--
-- SINTAXE: este cliente usa `@fa <estilo> <tamanho> <codepoint>` (ver guild.lua:683), NAO o formato
-- `@FontAwesome-blackrounded-12sp-xf00c` da PokeXGames. Os codepoints sao os mesmos; so a forma muda.
-- Fontes disponiveis em data/fonts: blackrounded, regular, light, brands e as sharp-*.
--
-- O estilo `blackrounded` esta declarado em data/fonts/fa.otfont: fa-sharp-solid-900 com
-- outline-width 1 / outline-color #0008 -- a mesma variante com contorno que a PokeXGames usa.

MapFlagsColor = {
  [1] = '#ffffff',
  [2] = '#4ec9b0',  -- verde-agua: confirmacao / servico
  [3] = '#dcdcaa',  -- amarelo: atencao
  [4] = '#f14c4c',  -- vermelho: perigo / direcao
  [5] = '#569cd6',  -- azul
  [6] = '#c586c0',  -- roxo
  [7] = '#9cdcfe',  -- azul claro
  [8] = '#d16969',  -- vermelho escuro
  [9] = '#a0a0a0',  -- cinza: morte
}

-- Indexado pelo markType que vem no fio (0..19), igual ao MAPMARK_* do servidor.
MapFlags = {
  [0]  = { id = 'tick',        source = '@fa blackrounded 12 f00c', defaultColor = MapFlagsColor[2] },
  [1]  = { id = 'question',    source = '@fa blackrounded 11 f128', defaultColor = MapFlagsColor[7] },
  [2]  = { id = 'exclamation', source = '@fa blackrounded 11 f12a', defaultColor = MapFlagsColor[4] },
  [3]  = { id = 'star',        source = '@fa blackrounded 11 f005', defaultColor = MapFlagsColor[3] },
  [4]  = { id = 'cross',       source = '@fa blackrounded 13 f00d', defaultColor = MapFlagsColor[4] },
  -- 5 = TEMPLE. E o que o modulo minimapMarks usa para POKEMON CENTER, entao vale mais um icone
  -- medico que um templo: f7f2 = suitcase-medical.
  [5]  = { id = 'temple',      source = '@fa blackrounded 11 f7f2', defaultColor = MapFlagsColor[2] },
  [6]  = { id = 'kiss',        source = '@fa blackrounded 11 f004', defaultColor = MapFlagsColor[6] },
  -- 7 = SHOVEL. Usado para FISHERMAN: f578 = fish.
  [7]  = { id = 'shovel',      source = '@fa blackrounded 11 f578', defaultColor = MapFlagsColor[5] },
  [8]  = { id = 'sword',       source = '@fa blackrounded 11 f71c', defaultColor = MapFlagsColor[8] },
  [9]  = { id = 'flag',        source = '@fa blackrounded 11 f024', defaultColor = MapFlagsColor[7] },
  [10] = { id = 'lock',        source = '@fa blackrounded 11 f023', defaultColor = MapFlagsColor[3] },
  [11] = { id = 'bag',         source = '@fa blackrounded 11 f290', defaultColor = MapFlagsColor[2] },
  [12] = { id = 'skull',       source = '@fa blackrounded 11 f54c', defaultColor = MapFlagsColor[9] },
  -- 13 = DOLLAR. Usado para POKE MART: f155 = dollar-sign, igual ao deles.
  [13] = { id = 'dollar',      source = '@fa blackrounded 11 f155', defaultColor = MapFlagsColor[2] },
  [14] = { id = 'rednorth',    source = '@fa blackrounded 16 f0d8', defaultColor = MapFlagsColor[4] },
  [15] = { id = 'redsouth',    source = '@fa blackrounded 16 f0d7', defaultColor = MapFlagsColor[4] },
  [16] = { id = 'redeast',     source = '@fa blackrounded 16 f0da', defaultColor = MapFlagsColor[4] },
  [17] = { id = 'redwest',     source = '@fa blackrounded 16 f0d9', defaultColor = MapFlagsColor[4] },
  [18] = { id = 'greennorth',  source = '@fa blackrounded 16 f0d8', defaultColor = MapFlagsColor[2] },
  [19] = { id = 'greensouth',  source = '@fa blackrounded 16 f0d7', defaultColor = MapFlagsColor[2] },
}
