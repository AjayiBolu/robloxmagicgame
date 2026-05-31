--[[
    PackConfig.luau
    Location: ReplicatedStorage/Shared/PackConfig

    Defines every starter pack available on the pack selection screen.
    Each pack gives the player a 10-card starting deck.

    ── ADDING A NEW PACK ──────────────────────────────────────────
    1. Add a new entry to PackConfig.PACKS below.
    2. List card ids from AnimeCards.luau (or CardSystem.luau).
    3. Add the pack id to getPackOrder() so it shows on screen.
    That's it — the UI and server pick it up automatically.
    ──────────────────────────────────────────────────────────────
]]

local PackConfig = {}

-- ── DECK RULES ─────────────────────────────────────────────────
-- These apply to every deck regardless of pack.
PackConfig.DECK_RULES = {
    MIN_CARDS  = 10,
    MAX_CARDS  = 20,
    MAX_COPIES = 2,
}

-- ── PACK DEFINITIONS ───────────────────────────────────────────
PackConfig.PACKS = {

    -- ── ONE PIECE ─────────────────────────────────────────────
    onepiece = {
        id          = "onepiece",
        name        = "Straw Hat Pack",
        description = "Fight with the will of D. High damage, relentless pressure, and a surprise draw engine.",
        element     = "Fire",
        starterDeck = {
            "luffy_king",
            "luffy_king",
            "zoro_three_sword",
            "zoro_three_sword",
            "sanji_black_leg",
            "sanji_black_leg",
            "nami_navigator",
            "nami_navigator",
            "robin_clutch",
            "law_surgeon",
        },
    },

    -- ── BLEACH ────────────────────────────────────────────────
    bleach = {
        id          = "bleach",
        name        = "Soul Reaper Pack",
        description = "Release your Zanpakuto. Spiritual pressure, speed, and a devastating Bankai finisher.",
        element     = "Dark",
        starterDeck = {
            "ichigo_substitute",
            "ichigo_substitute",
            "yoruichi_shunko",
            "yoruichi_shunko",
            "byakuya_noble",
            "byakuya_noble",
            "rukia_ice",
            "rukia_ice",
            "kenpachi_eyepatch",
            "spell_soul_king",
        },
    },

    -- ── NARUTO ────────────────────────────────────────────────
    naruto = {
        id          = "naruto",
        name        = "Shinobi Pack",
        description = "Follow your ninja way. Control the battlefield with genjutsu then burst through with ninjutsu.",
        element     = "Air",
        starterDeck = {
            "naruto_uzumaki",
            "naruto_uzumaki",
            "sasuke_uchiha",
            "sasuke_uchiha",
            "shadow_clone_nin",
            "shadow_clone_nin",
            "jutsu_rasengan",
            "jutsu_rasengan",
            "jutsu_shadow_clone",
            "shikamaru_nara",
        },
    },

    -- ── DRAGON BALL Z ─────────────────────────────────────────
    dbz = {
        id          = "dbz",
        name        = "Saiyan Pack",
        description = "Power level over everything. Pure ki blasts, armor-piercing beams, and one Legendary that ends fights.",
        element     = "Fire",
        starterDeck = {
            "goku_saiyan",
            "goku_saiyan",
            "vegeta_prince",
            "vegeta_prince",
            "piccolo_namekian",
            "piccolo_namekian",
            "ki_kamehameha",
            "ki_kamehameha",
            "trunks_future",
            "ki_spirit_bomb",
        },
    },

    -- ── CROSSOVER STARTER ─────────────────────────────────────
    starter = {
        id          = "starter",
        name        = "Crossover Pack",
        description = "One card from every world. Explore all four themes before committing to your main deck.",
        element     = "Neutral",
        starterDeck = {
            "naruto_uzumaki",
            "zoro_three_sword",
            "ichigo_substitute",
            "goku_saiyan",
            "sasuke_uchiha",
            "luffy_king",
            "byakuya_noble",
            "jutsu_rasengan",
            "spell_getsuga",
            "ki_kamehameha",
        },
    },
}

-- ── PUBLIC API ─────────────────────────────────────────────────

function PackConfig.getPack(packId)
    return PackConfig.PACKS[packId]
end

function PackConfig.getAllPacks()
    return PackConfig.PACKS
end

-- Display order on the pack selection screen.
-- Add new pack ids here when you create new packs above.
function PackConfig.getPackOrder()
    return { "starter", "onepiece", "bleach", "naruto", "dbz" }
end

-- Validate a deck against global rules.
-- Returns: isValid (bool), reason (string or nil)
function PackConfig.validateDeck(deckCardIds)
    local rules = PackConfig.DECK_RULES

    if #deckCardIds < rules.MIN_CARDS then
        return false, "Need at least " .. rules.MIN_CARDS .. " cards (have " .. #deckCardIds .. ")"
    end
    if #deckCardIds > rules.MAX_CARDS then
        return false, "Maximum " .. rules.MAX_CARDS .. " cards (have " .. #deckCardIds .. ")"
    end

    local counts = {}
    for _, cardId in ipairs(deckCardIds) do
        counts[cardId] = (counts[cardId] or 0) + 1
        if counts[cardId] > rules.MAX_COPIES then
            return false, "Too many copies of '" .. cardId .. "' (max " .. rules.MAX_COPIES .. ")"
        end
    end

    return true, nil
end

return PackConfig
