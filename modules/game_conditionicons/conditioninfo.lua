-- Mapeamento de ConditionType_t (TFS) para apresentação visual no cliente.
-- O servidor manda { type, subId, time } via opcode 220; o cliente lookups
-- nesta tabela para resolver path/tooltip e flags de comportamento.
--
-- Campos suportados por entrada:
--   path                  -> nome do icone em /images/conditions/<path>
--   tooltip               -> texto do tooltip (sem tr() porque o módulo já roda runtime)
--   ignore                -> se true, o pacote é descartado (silêncio)
--   parseInSeconds        -> se true, time vem em segundos (multiplica por 1000)
--   isStatic              -> se true, sem progress bar (icon permanente até remove)
--   stackById             -> se true, múltiplas instâncias coexistem (key = type+subId)
--   keepLongestDuration   -> se true, ao re-applicar mantem a duração maior
--
-- Os keys são valores numéricos do enum ConditionType_t em src/enums.h.

ConditionInfo = {
    [1]          = { path = "poisoned",        tooltip = tr("Poisoned") },        -- CONDITION_POISON
    [2]          = { path = "burning",         tooltip = tr("Burning") },         -- CONDITION_FIRE
    [4]          = { path = "energized",       tooltip = tr("Energized") },       -- CONDITION_ENERGY
    [8]          = { path = "bleeding",        tooltip = tr("Bleeding") },        -- CONDITION_BLEEDING
    [16]         = { path = "hastened",        tooltip = tr("Hasted") },          -- CONDITION_HASTE
    [32]         = { path = "paralyzed",       tooltip = tr("Paralyzed") },       -- CONDITION_PARALYZE
    [64]         = { ignore = true },                                              -- CONDITION_OUTFIT
    [128]        = { path = "invisible",       tooltip = tr("Invisible") },       -- CONDITION_INVISIBLE
    [256]        = { ignore = true },                                              -- CONDITION_LIGHT
    [1024]       = { isStatic = true, path = "in_combat", tooltip = tr("Fighting") }, -- CONDITION_INFIGHT
    [2048]       = { path = "confused",        tooltip = tr("Confused") },        -- CONDITION_CONFUSION
    [8192]       = { path = "hungry",    tooltip = tr("Regenerating") },    -- CONDITION_REGENERATION
    [16384]      = { path = "soul",            tooltip = tr("Soul") },            -- CONDITION_SOUL
    [32768]      = { path = "drowning",        tooltip = tr("Drowning") },        -- CONDITION_DROWN
    [65536]      = { path = "muted",           tooltip = tr("Muted") },           -- CONDITION_MUTED
    [131072]     = { ignore = true },                                              -- CONDITION_CHANNELMUTEDTICKS
    [262144]     = { ignore = true },                                              -- CONDITION_YELLTICKS
    [524288]     = { keepLongestDuration = true, path = "buffed", tooltip = tr("Buffed") }, -- CONDITION_ATTRIBUTES
    [1048576]    = { path = "freezing",        tooltip = tr("Freezing") },        -- CONDITION_FREEZING
    [2097152]    = { path = "dazzled",         tooltip = tr("Dazzled") },         -- CONDITION_DAZZLED
    [4194304]    = { path = "cursed",          tooltip = tr("Cursed") },          -- CONDITION_CURSED
    [33554432]   = { path = "pacified",        tooltip = tr("Pacified") },        -- CONDITION_PACIFIED
    [67108864]   = { path = "paralyzed",       tooltip = tr("Paralyzed") },       -- CONDITION_PARALIZED
    [134217728]  = { path = "blind",           tooltip = tr("Blind") },           -- CONDITION_BLIND
    [268435456]  = { path = "freezing",        tooltip = tr("Frozen") },          -- CONDITION_FREEZE
    [536870912]  = { path = "strafing",        tooltip = tr("Strafe") },          -- CONDITION_STRAFE
    [1073741824] = { path = "sleeping",        tooltip = tr("Sleeping") },        -- CONDITION_SLEEP
    [2147483648] = { path = "silenced",        tooltip = tr("Silenced") },        -- CONDITION_SILENCE
    [4294967296] = { path = "scared",          tooltip = tr("Feared") },          -- CONDITION_FEAR
    [8589934592] = { keepLongestDuration = true, path = "defense_broken", tooltip = tr("Defense Broken") }, -- CONDITION_DEFENSE_BROKEN
    [17179869184]  = { path = "leech_seed_debuff", tooltip = tr("Leechlife") },   -- CONDITION_LEECHLIFE
    [34359738368]  = { path = "hardened",      tooltip = tr("Hardened") },        -- CONDITION_HARDEN
    [68719476736]  = { keepLongestDuration = true, path = "enraged", tooltip = tr("Enraged") }, -- CONDITION_RAGE
    [137438953472] = { path = "stunned",       tooltip = tr("Stunned") },         -- CONDITION_STUN
    [274877906944] = { path = "no_move",       tooltip = tr("Blocked Movement") }, -- CONDITION_NOMOVE
    [549755813888] = { path = "unbreakable",   tooltip = tr("Invulnerable") },    -- CONDITION_INVULNERABLE
    [1099511627776]= { path = "slowed",        tooltip = tr("Slowed") },          -- CONDITION_SLOW
    [2199023255552]= { path = "focused",       tooltip = tr("Focused") },         -- CONDITION_FOCUS
    [4398046511104]= { path = "stunned",       tooltip = tr("Self-stunned") },    -- CONDITION_SELFSTUN
    [8796093022208]= { path = "stuck",         tooltip = tr("Tongue") },          -- CONDITION_TONGUE
    [17592186044416]= { path = "teleport",     tooltip = tr("Blink") },           -- CONDITION_BLINK
    [35184372088832]= { path = "reflecting",   tooltip = tr("Reflecting") },      -- CONDITION_REFLECT
    [70368744177664]= { path = "vulnerable_to_ground-type_moves", tooltip = tr("Attack Flying") }, -- CONDITION_ATTACKFLYING
    [140737488355328]= { path = "locked",      tooltip = tr("Barrier") },         -- CONDITION_BARRIER
    [281474976710656]= { path = "condition_neutral", tooltip = tr("Effect"), parseInSeconds = true, stackById = true }, -- CONDITION_GENERIC
    [562949953421312]= { ignore = true },                                          -- CONDITION_POKESTOP
    [1125899906842624]= { path = "strengthened_by_dark_accurate", tooltip = tr("Dark Eye") }, -- CONDITION_DARKEYE
    [2251799813685248]= { path = "strengthened_by_miracle_eye", tooltip = tr("Miracle Eye") }, -- CONDITION_MIRACLEEYE
    [4503599627370496]= { ignore = true },                                         -- CONDITION_SHAREDEXPERIENCE
    [9007199254740992]= { path = "boost_broken", tooltip = tr("Boost Blocked") }, -- CONDITION_BLOCKPASSIVE
}

-- Diretório base dos ícones. Coloque os PNGs como /images/conditions/<path>.png
CONDITION_PATH_PREFIX = "/images/conditions/"
