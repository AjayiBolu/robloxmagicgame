--[[
    CardSystem.luau
    Place in: src/shared/CardSystem.luau

    THE CORE CARD FOUNDATION
    ========================
    This is the single source of truth for every card in the game.
    To add a new card in the future, just call CardSystem.registerCard({...})
    at the bottom of this file (or from a separate card pack module).

    Every card follows the same structure (template below).
    Missing fields will be filled in with safe defaults automatically.
]]

local CardSystem = {}

-- ============================================================
--  UNIVERSAL CARD TEMPLATE  (MTG-style)
--  Every card in the game uses this exact structure.
--  Only fill in what matters — defaults handle the rest.
-- ============================================================
--[[
    IDENTITY
    --------
    id          : string   -- Unique snake_case key. e.g. "naruto_uzumaki"
    name        : string   -- Display name on the card
    description : string   -- Rules text shown to the player
    art         : string   -- "default" or "rbxassetid://YOUR_ID" once uploaded
    rarity      : string   -- "Common" | "Uncommon" | "Rare" | "Mythic Rare"

    MTG CLASSIFICATION
    ------------------
    cardType    : string   -- "Creature" | "Instant" | "Sorcery" |
                           --  "Enchantment" | "Artifact" | "Land"
    subTypes    : table    -- Creature subtypes e.g. {"Ninja","Legendary"}
                           -- Spell subtypes e.g. {"Jutsu"} or {"Bankai"}

    MANA
    ----
    manaCost    : number   -- Total mana to play this card
    element     : string   -- Color identity for UI: "Fire"|"Water"|"Earth"|
                           --  "Air"|"Dark"|"Light"|"Neutral"

    CREATURE STATS  (Creatures only)
    --------------------------------
    power       : number   -- Attack strength  (the left number, e.g. 4/4)
    toughness   : number   -- Hit points       (the right number, e.g. 4/4)

    KEYWORD ABILITIES  (Creatures and some spells)
    -----------------------------------------------
    keywords    : table    -- e.g. {"Haste","Trample","First Strike"}
    Valid keywords:
      Haste          — can attack the turn it enters
      Trample        — excess combat damage hits the player
      First Strike   — deals combat damage before non-first-strikers
      Double Strike  — deals first and normal combat damage
      Vigilance      — doesn't tap when attacking
      Reach          — can block flying creatures
      Flying         — only blocked by flying / reach creatures
      Deathtouch     — any damage dealt is lethal
      Lifelink       — damage dealt also heals you
      Indestructible — cannot be destroyed by damage or destroy effects

    ACTIVATED / TRIGGERED ABILITIES  (described for the battle system)
    -------------------------------------------------------------------
    effects     : table    -- What the card does beyond base stats
    Effect format: {
        type    : string   -- "damage"|"heal"|"draw"|"buff"|"debuff"|
                           --  "summon_token"|"tap"|"exile"|"copy"
        amount  : number   -- Quantity (damage, HP, cards drawn, etc.)
        target  : string   -- "enemy"|"self"|"ally"|"all_enemies"|"all"
        duration: number   -- Turns for ongoing effects (0 = instant)
        special : string   -- Named behavior: "burn","freeze","stun",
                           --  "deathtouch","haste","clone","copy_jutsu"
    }

    SYNERGY TAGS  (internal — never shown to the player)
    -----------------------------------------------------
    tags        : table    -- Mechanic tags enabling cross-theme archetypes
                           -- e.g. {"swift","pierce","spiritual","clone"}
    Useful cross-theme tags:
      swift      → speed-based decks
      pierce     → armor-break decks
      burn       → damage-over-time decks
      clone      → token/swarm decks
      control    → lockdown decks
      regen      → sustain decks
      draw       → card-engine decks
      berserker  → high risk / high reward
      spiritual  → soul/chakra/ki energy (cross-anime energy type)
]]

-- ============================================================
--  INTERNAL REGISTRY
--  All registered cards live here. Do not edit directly.
-- ============================================================
local _registry = {}

-- ============================================================
--  PUBLIC API
-- ============================================================

-- Register a new card into the system.
-- Call this once per card, usually at the bottom of this file
-- or inside a dedicated card-pack module that requires CardSystem.
function CardSystem.registerCard(data)
    assert(type(data) == "table", "CardSystem.registerCard: card data must be a table")
    assert(type(data.id) == "string" and data.id ~= "", "CardSystem.registerCard: card must have a string 'id'")
    assert(type(data.name) == "string" and data.name ~= "", "CardSystem.registerCard: card must have a string 'name'")

    if _registry[data.id] then
        warn("CardSystem: Card '" .. data.id .. "' is already registered. Overwriting.")
    end

    -- Apply defaults for any missing fields
    local card = {
        -- Identity
        id          = data.id,
        name        = data.name,
        description = data.description or "No description.",
        art         = data.art         or "default",
        rarity      = data.rarity      or "Common",

        -- MTG classification
        cardType    = data.cardType    or "Creature",
        subTypes    = data.subTypes    or {},

        -- Mana + color
        manaCost    = data.manaCost    or 1,
        element     = data.element     or "Neutral",

        -- Creature stats
        power       = data.power       or 0,
        toughness   = data.toughness   or data.defense or 0,  -- support both names

        -- Keywords
        keywords    = data.keywords    or {},

        -- Abilities
        effects     = data.effects     or {},

        -- Synergy tags (internal)
        tags        = data.tags        or {},
    }

    _registry[card.id] = card
end

-- Get a single card by its id. Returns nil if not found.
function CardSystem.getCard(cardId)
    return _registry[cardId]
end

-- Get every registered card. Returns a copy so the registry stays safe.
function CardSystem.getAllCards()
    local copy = {}
    for id, card in pairs(_registry) do
        copy[id] = card
    end
    return copy
end

-- Get all cards belonging to a specific element.
function CardSystem.getCardsByElement(element)
    local result = {}
    for id, card in pairs(_registry) do
        if card.element == element then
            result[id] = card
        end
    end
    return result
end

-- Get all cards of a specific rarity.
function CardSystem.getCardsByRarity(rarity)
    local result = {}
    for id, card in pairs(_registry) do
        if card.rarity == rarity then
            result[id] = card
        end
    end
    return result
end

-- Get all cards matching a tag (e.g. "burn", "aoe")
function CardSystem.getCardsByTag(tag)
    local result = {}
    for id, card in pairs(_registry) do
        for _, t in ipairs(card.tags) do
            if t == tag then
                result[id] = card
                break
            end
        end
    end
    return result
end

-- Check if a card id exists in the registry.
function CardSystem.cardExists(cardId)
    return _registry[cardId] ~= nil
end

-- ============================================================
--  STARTER CARDS
--  These are the base cards that come with the game.
--  Add new cards below using CardSystem.registerCard({...})
-- ============================================================

-- FIRE ELEMENT
CardSystem.registerCard({
    id          = "fire_blast",
    name        = "Fire Blast",
    description = "Hurl a bolt of flame at the enemy, dealing 30 damage.",
    element     = "Fire",
    rarity      = "Common",
    cardType    = "Spell",
    manaCost    = 2,
    power       = 30,
    effects     = {
        { type = "damage", amount = 30, target = "enemy" }
    },
    art         = "fire_blast",
    tags        = { "fire", "direct" },
})

CardSystem.registerCard({
    id          = "inferno_wave",
    name        = "Inferno Wave",
    description = "Release a wave of fire that scorches all enemies for 20 damage and applies burn.",
    element     = "Fire",
    rarity      = "Uncommon",
    cardType    = "Spell",
    manaCost    = 4,
    power       = 20,
    effects     = {
        { type = "damage", amount = 20, target = "all_enemies" },
        { type = "debuff", amount = 5,  target = "all_enemies", duration = 2, special = "burn" }
    },
    art         = "inferno_wave",
    tags        = { "fire", "aoe", "burn" },
})

CardSystem.registerCard({
    id          = "ember_shield",
    name        = "Ember Shield",
    description = "Surround yourself in embers, gaining 25 shield. Attackers take 5 burn damage.",
    element     = "Fire",
    rarity      = "Uncommon",
    cardType    = "Spell",
    manaCost    = 3,
    defense     = 25,
    effects     = {
        { type = "shield",  amount = 25, target = "self" },
        { type = "debuff",  amount = 5,  target = "enemy", duration = 1, special = "burn" }
    },
    art         = "ember_shield",
    tags        = { "fire", "defensive", "burn" },
})

-- WATER ELEMENT
CardSystem.registerCard({
    id          = "tidal_surge",
    name        = "Tidal Surge",
    description = "Crash a wave into the enemy, dealing 25 damage and slowing them.",
    element     = "Water",
    rarity      = "Common",
    cardType    = "Spell",
    manaCost    = 2,
    power       = 25,
    effects     = {
        { type = "damage", amount = 25, target = "enemy" },
        { type = "debuff", amount = 0,  target = "enemy", duration = 1, special = "slow" }
    },
    art         = "tidal_surge",
    tags        = { "water", "slow" },
})

CardSystem.registerCard({
    id          = "healing_rain",
    name        = "Healing Rain",
    description = "Summon a calming rain that restores 35 HP.",
    element     = "Water",
    rarity      = "Common",
    cardType    = "Spell",
    manaCost    = 3,
    effects     = {
        { type = "heal", amount = 35, target = "self" }
    },
    art         = "healing_rain",
    tags        = { "water", "heal" },
})

CardSystem.registerCard({
    id          = "frost_barrier",
    name        = "Frost Barrier",
    description = "Encase yourself in ice, gaining 40 shield. Has a chance to freeze attackers.",
    element     = "Water",
    rarity      = "Rare",
    cardType    = "Spell",
    manaCost    = 4,
    defense     = 40,
    effects     = {
        { type = "shield", amount = 40, target = "self" },
        { type = "debuff", amount = 0,  target = "enemy", duration = 1, special = "freeze" }
    },
    art         = "frost_barrier",
    tags        = { "water", "defensive", "freeze" },
})

-- EARTH ELEMENT
CardSystem.registerCard({
    id          = "stone_throw",
    name        = "Stone Throw",
    description = "Hurl a boulder at the enemy, dealing 35 damage.",
    element     = "Earth",
    rarity      = "Common",
    cardType    = "Spell",
    manaCost    = 2,
    power       = 35,
    effects     = {
        { type = "damage", amount = 35, target = "enemy" }
    },
    art         = "stone_throw",
    tags        = { "earth", "direct" },
})

CardSystem.registerCard({
    id          = "iron_skin",
    name        = "Iron Skin",
    description = "Harden your body, gaining 50 defense and reducing incoming damage by 10 for 2 turns.",
    element     = "Earth",
    rarity      = "Uncommon",
    cardType    = "Spell",
    manaCost    = 4,
    defense     = 50,
    effects     = {
        { type = "shield", amount = 50, target = "self" },
        { type = "buff",   amount = 10, target = "self", duration = 2, special = "damage_reduction" }
    },
    art         = "iron_skin",
    tags        = { "earth", "defensive", "buff" },
})

-- AIR ELEMENT
CardSystem.registerCard({
    id          = "gust",
    name        = "Gust",
    description = "A quick burst of wind deals 15 damage. Draw 1 card.",
    element     = "Air",
    rarity      = "Common",
    cardType    = "Spell",
    manaCost    = 1,
    power       = 15,
    effects     = {
        { type = "damage", amount = 15, target = "enemy" },
        { type = "draw",   amount = 1,  target = "self"  }
    },
    art         = "gust",
    tags        = { "air", "draw", "swift" },
})

CardSystem.registerCard({
    id          = "cyclone",
    name        = "Cyclone",
    description = "Spin up a cyclone, dealing 20 damage to all enemies and pushing them back.",
    element     = "Air",
    rarity      = "Rare",
    cardType    = "Spell",
    manaCost    = 5,
    power       = 20,
    effects     = {
        { type = "damage", amount = 20, target = "all_enemies" },
        { type = "debuff", amount = 0,  target = "all_enemies", duration = 1, special = "pushback" }
    },
    art         = "cyclone",
    tags        = { "air", "aoe", "control" },
})

-- DARK ELEMENT
CardSystem.registerCard({
    id          = "shadow_strike",
    name        = "Shadow Strike",
    description = "Strike from the darkness, dealing 40 damage and ignoring 10 defense.",
    element     = "Dark",
    rarity      = "Uncommon",
    cardType    = "Spell",
    manaCost    = 3,
    power       = 40,
    effects     = {
        { type = "damage", amount = 40, target = "enemy", special = "armor_pierce_10" }
    },
    art         = "shadow_strike",
    tags        = { "dark", "pierce", "direct" },
})

CardSystem.registerCard({
    id          = "void_drain",
    name        = "Void Drain",
    description = "Siphon life from the enemy, dealing 20 damage and healing yourself for 20.",
    element     = "Dark",
    rarity      = "Rare",
    cardType    = "Spell",
    manaCost    = 4,
    power       = 20,
    effects     = {
        { type = "damage", amount = 20, target = "enemy" },
        { type = "heal",   amount = 20, target = "self"  }
    },
    art         = "void_drain",
    tags        = { "dark", "lifesteal" },
})

-- LIGHT ELEMENT
CardSystem.registerCard({
    id          = "holy_bolt",
    name        = "Holy Bolt",
    description = "Launch a beam of pure light, dealing 28 damage. Extra effective against Dark.",
    element     = "Light",
    rarity      = "Common",
    cardType    = "Spell",
    manaCost    = 2,
    power       = 28,
    effects     = {
        { type = "damage", amount = 28, target = "enemy", special = "bonus_vs_dark" }
    },
    art         = "holy_bolt",
    tags        = { "light", "direct" },
})

CardSystem.registerCard({
    id          = "divine_shield",
    name        = "Divine Shield",
    description = "Call upon divine protection. Gain 60 shield that cleanses debuffs.",
    element     = "Light",
    rarity      = "Rare",
    cardType    = "Spell",
    manaCost    = 5,
    defense     = 60,
    effects     = {
        { type = "shield",  amount = 60, target = "self" },
        { type = "buff",    amount = 0,  target = "self", special = "cleanse" }
    },
    art         = "divine_shield",
    tags        = { "light", "defensive", "cleanse" },
})

return CardSystem
