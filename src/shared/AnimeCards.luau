--[[
    AnimeCards.luau
    Location: ReplicatedStorage/Shared/AnimeCards

    Registers all anime-themed cards into CardSystem.
    Require this module once (DeckService does it) to populate the registry.

    ── ORGANISATION ───────────────────────────────────────────────
      Section 1 — NARUTO        (12 cards)  Red/Green  Aggro + Clone Swarm
      Section 2 — ONE PIECE     (12 cards)  Blue/Red   Tempo + Devil Fruit
      Section 3 — BLEACH        (12 cards)  White/Black Control + Bankai Burst
      Section 4 — DRAGON BALL Z  (8 cards)  Red/White  Pure Ki Power

    ── FUTURE UPDATE NOTE ────────────────────────────────────────
      A "special summon" mechanic (think: Synchro / Fusion) is planned.
      When building new cards, tag them with "tribute" or "fusion_material"
      if they are intended to feed into that system.
      The cardType field will gain "Fusion" and "Synchro" in that update.
    ──────────────────────────────────────────────────────────────

    ── CARD COUNT TARGET ─────────────────────────────────────────
      Keep each theme to ~12 cards for now.
      Leave endgame transformations (Baryon Mode, Gear 5, TYBW) for
      a future expansion — the base set should be completable and
      fun without them.
    ──────────────────────────────────────────────────────────────
]]

local CardSystem = require(script.Parent.CardSystem)

-- ═══════════════════════════════════════════════════════════════════
--  SECTION 1 — NARUTO
--  Colors: Red (Fire) + Green (Earth)
--  Strategy: Flood the board with clone tokens early, ramp into
--  big jutsu finishers. Kakashi copies spells for free. Rock Lee
--  ignores all jutsu and just swings harder as the game goes long.
--
--  Cross-theme tags: "swift", "clone", "pierce", "control"
-- ═══════════════════════════════════════════════════════════════════

-- ── LEGENDARY CREATURES ──────────────────────────────────────────

CardSystem.registerCard({
    id        = "naruto_uzumaki",
    name      = "Naruto Uzumaki, Nine-Tails Vessel",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Ninja", "Jinchuriki" },
    element   = "Fire",
    rarity    = "Mythic Rare",
    manaCost  = 4,
    power     = 4,
    toughness = 4,
    keywords  = { "Haste" },
    effects   = {
        -- On enter: spawn two 1/1 Shadow Clone tokens
        { type = "summon_token", amount = 2, target = "self",
          special = "shadow_clone_1_1" },
        -- Passive: if you control 3+ clones → +3/+3 this turn (Kyuubi Mode)
        { type = "buff", amount = 3, target = "self", duration = 1,
          special = "kyuubi_if_3_clones" },
    },
    description = "Haste. When Naruto enters, create two 1/1 Shadow Clone tokens. "
               .. "If you control 3 or more clones, Naruto gets +3/+3 until end of turn.",
    art  = "naruto_uzumaki",
    tags = { "clone", "swift", "spiritual", "fire" },
})

CardSystem.registerCard({
    id        = "sasuke_uchiha",
    name      = "Sasuke Uchiha, Last Avenger",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Ninja", "Uchiha" },
    element   = "Dark",
    rarity    = "Mythic Rare",
    manaCost  = 4,
    power     = 4,
    toughness = 3,
    keywords  = { "First Strike" },
    effects   = {
        -- Activated: tap → 2 damage to any target (Chidori)
        { type = "damage", amount = 2, target = "enemy", special = "chidori_tap" },
        -- Triggered: if enemy attacked you last turn → gain Deathtouch
        { type = "buff", amount = 0, target = "self", duration = 1,
          special = "deathtouch_if_attacked" },
    },
    description = "First Strike. Tap: deal 2 damage to any target (Chidori). "
               .. "If an opponent's creature attacked you last turn, Sasuke gains Deathtouch.",
    art  = "sasuke_uchiha",
    tags = { "pierce", "swift", "control", "dark" },
})

CardSystem.registerCard({
    id        = "kakashi_hatake",
    name      = "Kakashi, Copy Ninja",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Ninja", "Sensei" },
    element   = "Air",
    rarity    = "Mythic Rare",
    manaCost  = 4,
    power     = 3,
    toughness = 4,
    keywords  = {},
    effects   = {
        -- On enter: copy target Jutsu spell you control — cast the copy for free
        { type = "copy", amount = 1, target = "self", special = "copy_jutsu_free" },
    },
    description = "When Kakashi enters, copy target Jutsu spell you control and cast it for free. "
               .. "(Sharingan — sees and copies any jutsu once per turn.)",
    art  = "kakashi_hatake",
    tags = { "draw", "swift", "spiritual", "air" },
})

CardSystem.registerCard({
    id        = "rock_lee",
    name      = "Rock Lee, Lotus Unleashed",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Ninja", "Taijutsu" },
    element   = "Earth",
    rarity    = "Rare",
    manaCost  = 3,
    power     = 2,
    toughness = 5,
    keywords  = { "Trample" },
    effects   = {
        -- Combat: +X/+0 where X = lands you control (Eight Gates)
        { type = "buff", amount = 0, target = "self", duration = 1,
          special = "power_equals_lands" },
    },
    description = "Trample. Cannot play Jutsu cards. During combat, Rock Lee gets "
               .. "+X/+0 where X equals the number of lands you control.",
    art  = "rock_lee",
    tags = { "berserker", "burst", "earth" },
})

-- ── SUPPORT CREATURES ────────────────────────────────────────────

CardSystem.registerCard({
    id        = "shadow_clone_nin",
    name      = "Shadow Clone Nin",
    cardType  = "Creature",
    subTypes  = { "Clone", "Ninja" },
    element   = "Fire",
    rarity    = "Common",
    manaCost  = 1,
    power     = 1,
    toughness = 1,
    keywords  = {},
    effects   = {
        -- Triggered: whenever another clone enters, this gets +1/+0 that turn
        { type = "buff", amount = 1, target = "self", duration = 1,
          special = "plus1_per_clone_enter" },
    },
    description = "Whenever another Clone creature enters, this gets +1/+0 until end of turn.",
    art  = "shadow_clone_nin",
    tags = { "clone", "swift", "fire" },
})

CardSystem.registerCard({
    id        = "shikamaru_nara",
    name      = "Shikamaru Nara, Shadow Tactician",
    cardType  = "Creature",
    subTypes  = { "Ninja" },
    element   = "Dark",
    rarity    = "Uncommon",
    manaCost  = 2,
    power     = 1,
    toughness = 3,
    keywords  = {},
    effects   = {
        -- Activated: tap → tap target creature; it doesn't untap next turn
        { type = "tap", amount = 0, target = "enemy", special = "shadow_possession" },
    },
    description = "Tap: tap target creature. That creature doesn't untap during its controller's next untap step.",
    art  = "shikamaru_nara",
    tags = { "control", "dark" },
})

CardSystem.registerCard({
    id        = "gaara_sand",
    name      = "Gaara of the Sand",
    cardType  = "Creature",
    subTypes  = { "Ninja", "Jinchuriki" },
    element   = "Earth",
    rarity    = "Uncommon",
    manaCost  = 3,
    power     = 3,
    toughness = 5,
    keywords  = {},
    effects   = {
        -- Passive: prevent the first 2 damage each turn (Sand Shield)
        { type = "buff",   amount = 2, target = "self", duration = 0,
          special = "prevent_2_damage_per_turn" },
        -- Triggered: when attacked, deal 1 damage to attacker
        { type = "damage", amount = 1, target = "enemy", special = "on_attacked" },
    },
    description = "Sand Shield: prevent the first 2 damage dealt to Gaara each turn. "
               .. "When Gaara is attacked, deal 1 damage to the attacker.",
    art  = "gaara_sand",
    tags = { "defensive", "control", "earth" },
})

-- ── JUTSU SPELLS ─────────────────────────────────────────────────

CardSystem.registerCard({
    id       = "jutsu_rasengan",
    name     = "Rasengan",
    cardType = "Instant",
    subTypes = { "Jutsu" },
    element  = "Air",
    rarity   = "Common",
    manaCost = 2,
    effects  = {
        { type = "damage", amount = 4, target = "enemy" },
        -- If Naruto cast this, deal 6 instead
        { type = "damage", amount = 2, target = "enemy", special = "bonus_if_naruto" },
    },
    description = "Deal 4 damage to target creature. If Naruto is on your side, deal 6 instead.",
    art  = "jutsu_rasengan",
    tags = { "burst", "spiritual", "air" },
})

CardSystem.registerCard({
    id       = "jutsu_shadow_clone",
    name     = "Shadow Clone Jutsu",
    cardType = "Sorcery",
    subTypes = { "Jutsu" },
    element  = "Fire",
    rarity   = "Uncommon",
    manaCost = 3,
    effects  = {
        -- Create 3 Shadow Clone tokens (1/1)
        { type = "summon_token", amount = 3, target = "self",
          special = "shadow_clone_1_1" },
        -- Each clone you control gets +1/+1 until end of turn
        { type = "buff", amount = 1, target = "ally", duration = 1,
          special = "buff_all_clones" },
    },
    description = "Create three 1/1 Shadow Clone tokens. Each Clone you control gets +1/+1 until end of turn.",
    art  = "jutsu_shadow_clone",
    tags = { "clone", "burst", "fire" },
})

CardSystem.registerCard({
    id       = "jutsu_chidori",
    name     = "Chidori",
    cardType = "Instant",
    subTypes = { "Jutsu" },
    element  = "Dark",
    rarity   = "Uncommon",
    manaCost = 3,
    effects  = {
        { type = "damage", amount = 5, target = "enemy" },
        -- That creature can't block next turn
        { type = "debuff", amount = 0, target = "enemy", duration = 1,
          special = "cant_block" },
    },
    description = "Deal 5 damage to target creature. That creature can't block during its controller's next turn.",
    art  = "jutsu_chidori",
    tags = { "pierce", "control", "dark" },
})

CardSystem.registerCard({
    id       = "kyuubi_awakening",
    name     = "Kyuubi Awakening",
    cardType = "Sorcery",
    subTypes = { "Transformation" },
    element  = "Fire",
    rarity   = "Rare",
    manaCost = 5,
    effects  = {
        -- Transform Naruto: becomes 9/9 with Trample and Haste
        { type = "buff", amount = 9, target = "ally", duration = 0,
          special = "transform_naruto_9_9_trample_haste" },
        -- All Clone tokens get +2/+2
        { type = "buff", amount = 2, target = "ally", duration = 0,
          special = "buff_all_clones_permanent" },
    },
    description = "Transform Naruto into a 9/9 with Trample and Haste. "
               .. "All Clone tokens you control get +2/+2.",
    art  = "kyuubi_awakening",
    tags = { "clone", "burst", "berserker", "fire" },
})


-- ═══════════════════════════════════════════════════════════════════
--  SECTION 2 — ONE PIECE
--  Colors: Blue (Water) + Red (Fire)
--  Strategy: Board control with crew abilities, draw with Nami,
--  lock with Law, close with Gear transformations or Shanks Haki.
--
--  Cross-theme tags: "swift", "draw", "control", "pierce"
-- ═══════════════════════════════════════════════════════════════════

-- ── LEGENDARY CREATURES ──────────────────────────────────────────

CardSystem.registerCard({
    id        = "luffy_king",
    name      = "Luffy, King of Pirates",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Pirate", "Rubber" },
    element   = "Fire",
    rarity    = "Mythic Rare",
    manaCost  = 4,
    power     = 4,
    toughness = 4,
    keywords  = { "Haste" },
    effects   = {
        -- Cannot be blocked by creatures power 1 or less (Gomu Gomu stretch)
        { type = "buff", amount = 0, target = "self", duration = 0,
          special = "unblockable_by_power_1" },
        -- Activated: +2/+0, deal double damage this combat (Gear 2nd)
        { type = "buff", amount = 2, target = "self", duration = 1,
          special = "gear2_double_damage" },
    },
    description = "Haste. Luffy can't be blocked by creatures with power 1 or less. "
               .. "Activate — Gear 2nd: +2/+0 and double damage this combat.",
    art  = "luffy_king",
    tags = { "swift", "burst", "fire" },
})

CardSystem.registerCard({
    id        = "zoro_three_sword",
    name      = "Zoro, Three Sword Style",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Pirate", "Swordsman" },
    element   = "Dark",
    rarity    = "Mythic Rare",
    manaCost  = 5,
    power     = 5,
    toughness = 3,
    keywords  = { "Double Strike" },
    effects   = {
        -- When Zoro deals combat damage to a player, destroy one of their enchantments/artifacts
        { type = "debuff", amount = 0, target = "enemy", duration = 0,
          special = "destroy_enchantment_on_damage" },
    },
    description = "Double Strike. When Zoro deals combat damage to a player, "
               .. "destroy one enchantment or artifact they control.",
    art  = "zoro_three_sword",
    tags = { "pierce", "burst", "dark" },
})

CardSystem.registerCard({
    id        = "nami_navigator",
    name      = "Nami, Navigator of Storms",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Pirate" },
    element   = "Water",
    rarity    = "Rare",
    manaCost  = 3,
    power     = 1,
    toughness = 3,
    keywords  = {},
    effects   = {
        -- On enter: draw 2 cards
        { type = "draw", amount = 2, target = "self" },
        -- Activated once per turn: tap target creature an opponent controls
        { type = "tap", amount = 0, target = "enemy", special = "climatact_tap_once" },
    },
    description = "When Nami enters, draw 2 cards. "
               .. "Once per turn: tap target creature an opponent controls.",
    art  = "nami_navigator",
    tags = { "draw", "control", "water" },
})

CardSystem.registerCard({
    id        = "shanks_emperor",
    name      = "Shanks, Emperor of the Sea",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Pirate", "Emperor" },
    element   = "Fire",
    rarity    = "Mythic Rare",
    manaCost  = 6,
    power     = 6,
    toughness = 6,
    keywords  = {},
    effects   = {
        -- On enter: all opponent creatures power 3 or less are tapped + skip untap
        { type = "tap", amount = 0, target = "all_enemies",
          special = "conquerors_haki_power3" },
    },
    description = "Shanks can't be targeted by spells or abilities. "
               .. "When Shanks enters, all opponent creatures with power 3 or less "
               .. "are tapped and skip their next untap step.",
    art  = "shanks_emperor",
    tags = { "control", "spiritual", "fire" },
})

-- ── SUPPORT CREATURES ────────────────────────────────────────────

CardSystem.registerCard({
    id        = "sanji_black_leg",
    name      = "Sanji, Black Leg",
    cardType  = "Creature",
    subTypes  = { "Pirate" },
    element   = "Fire",
    rarity    = "Uncommon",
    manaCost  = 3,
    power     = 4,
    toughness = 2,
    keywords  = { "Haste" },
    effects   = {
        -- Can only be blocked by creatures with 3+ toughness
        { type = "buff", amount = 0, target = "self", duration = 0,
          special = "unblockable_by_toughness_2" },
        -- Ifrit Jambe: +3/+0 when attacking alone
        { type = "buff", amount = 3, target = "self", duration = 1,
          special = "plus3_if_attacking_alone" },
    },
    description = "Haste. Sanji can only be blocked by creatures with toughness 3 or greater. "
               .. "Ifrit Jambe: Sanji gets +3/+0 when he attacks alone.",
    art  = "sanji_black_leg",
    tags = { "swift", "burn", "fire" },
})

CardSystem.registerCard({
    id        = "robin_clutch",
    name      = "Robin, Clutch Bloom",
    cardType  = "Creature",
    subTypes  = { "Pirate" },
    element   = "Earth",
    rarity    = "Uncommon",
    manaCost  = 3,
    power     = 2,
    toughness = 3,
    keywords  = {},
    effects   = {
        -- Tap: target creature becomes tapped and can't attack next turn
        { type = "tap", amount = 0, target = "enemy", special = "arm_trap_no_attack" },
        -- Once per game: deal 4 damage to a creature (Mil Fleur Gigantesco Mano)
        { type = "damage", amount = 4, target = "enemy",
          special = "mil_fleur_once_per_game" },
    },
    description = "Tap: target creature is tapped and can't attack next turn. "
               .. "Once per game — Mil Fleur Gigantesco Mano: deal 4 damage to a creature.",
    art  = "robin_clutch",
    tags = { "control", "draw", "earth" },
})

CardSystem.registerCard({
    id        = "law_surgeon",
    name      = "Trafalgar Law, Surgeon of Death",
    cardType  = "Creature",
    subTypes  = { "Pirate", "Warlord" },
    element   = "Dark",
    rarity    = "Rare",
    manaCost  = 4,
    power     = 3,
    toughness = 4,
    keywords  = {},
    effects   = {
        -- ROOM: once per turn, opponent can't activate abilities for 1 turn
        { type = "debuff", amount = 0, target = "enemy", duration = 1,
          special = "room_no_abilities" },
        -- SHAMBLES: swap a creature you control with one in your hand
        { type = "buff", amount = 0, target = "self", special = "shambles_swap" },
    },
    description = "ROOM: once per turn, opponent can't activate abilities until your next turn. "
               .. "SHAMBLES: swap a creature you control with one in your hand.",
    art  = "law_surgeon",
    tags = { "control", "draw", "dark" },
})

-- ── DEVIL FRUITS & SPELLS ────────────────────────────────────────

CardSystem.registerCard({
    id       = "fruit_gura_gura",
    name     = "Gura Gura no Mi",
    cardType = "Artifact",
    subTypes = { "Devil Fruit", "Equipment" },
    element  = "Earth",
    rarity   = "Rare",
    manaCost = 3,
    effects  = {
        -- Equip to a Pirate. That creature deals 1 shockwave to all enemy creatures when attacking
        { type = "damage", amount = 1, target = "all_enemies",
          special = "shockwave_on_attack" },
    },
    description = "Equip to a Pirate creature. "
               .. "Whenever equipped creature attacks, deal 1 damage to all opponent creatures.",
    art  = "fruit_gura_gura",
    tags = { "aoe", "pierce", "earth" },
})

CardSystem.registerCard({
    id       = "conquerors_haki",
    name     = "Conqueror's Haki Wave",
    cardType = "Instant",
    subTypes = {},
    element  = "Fire",
    rarity   = "Rare",
    manaCost = 4,
    effects  = {
        -- All opponent creatures power 4 or less are stunned — skip combat
        { type = "debuff", amount = 0, target = "all_enemies", duration = 1,
          special = "stun_power4_or_less" },
        -- Draw 2 cards
        { type = "draw", amount = 2, target = "self" },
    },
    description = "All opponent creatures with power 4 or less skip their next combat step. Draw 2 cards.",
    art  = "conquerors_haki",
    tags = { "control", "draw", "spiritual", "fire" },
})

CardSystem.registerCard({
    id       = "will_of_d",
    name     = "Will of D.",
    cardType = "Enchantment",
    subTypes = {},
    element  = "Fire",
    rarity   = "Mythic Rare",
    manaCost = 3,
    effects  = {
        -- Once per game: if your legendary creature would die, it doesn't
        { type = "buff", amount = 0, target = "ally", duration = 0,
          special = "legendary_survives_death_once" },
    },
    description = "Once per game, if a legendary creature you control would be destroyed, "
               .. "it isn't. Instead it survives with 1 toughness. (The D. never dies.)",
    art  = "will_of_d",
    tags = { "defensive", "regen", "fire" },
})

CardSystem.registerCard({
    id       = "marineford_war_cry",
    name     = "Marineford War Cry",
    cardType = "Sorcery",
    subTypes = {},
    element  = "Fire",
    rarity   = "Uncommon",
    manaCost = 4,
    effects  = {
        -- All Pirates you control get +2/+2 and Haste until end of turn
        { type = "buff", amount = 2, target = "ally", duration = 1,
          special = "buff_all_pirates_haste" },
        -- Destroy one artifact or enchantment
        { type = "exile", amount = 0, target = "enemy",
          special = "destroy_artifact_or_enchantment" },
    },
    description = "All Pirate creatures you control get +2/+2 and Haste until end of turn. "
               .. "Destroy target artifact or enchantment.",
    art  = "marineford_war_cry",
    tags = { "burst", "swift", "fire" },
})


-- ═══════════════════════════════════════════════════════════════════
--  SECTION 3 — BLEACH
--  Colors: White (Light) + Black (Dark)
--  Strategy: Stall with Captains and Zanpakuto abilities, accumulate
--  Bankai charges, then release for game-ending power spikes.
--  Espada serve as aggressive threats to keep opponents honest.
--
--  Cross-theme tags: "swift", "pierce", "control", "spiritual"
--  Note: TYBW-exclusive Bankais (Senbonzakura Kageyoshi final, etc.)
--  are intentionally held back for a future expansion.
-- ═══════════════════════════════════════════════════════════════════

-- ── LEGENDARY CAPTAINS ───────────────────────────────────────────

CardSystem.registerCard({
    id        = "ichigo_substitute",
    name      = "Ichigo Kurosaki, Substitute Shinigami",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Shinigami", "Hollow" },
    element   = "Dark",
    rarity    = "Mythic Rare",
    manaCost  = 5,
    power     = 5,
    toughness = 4,
    keywords  = { "First Strike" },
    effects   = {
        -- Bankai — Tensa Zangetsu: spend 3 mana → become 8/6 Trample, can't be blocked by 2+
        { type = "buff", amount = 3, target = "self", duration = 0,
          special = "bankai_8_6_trample_once_per_game" },
        -- Hollow Mask: once per game, prevent lethal damage
        { type = "buff", amount = 0, target = "self", duration = 0,
          special = "hollow_mask_prevent_lethal_once" },
    },
    description = "First Strike. Bankai — Tensa Zangetsu (3 mana): Ichigo becomes 8/6 "
               .. "with Trample and can't be blocked by more than one creature. "
               .. "Hollow Mask: once per game, prevent lethal damage.",
    art  = "ichigo_substitute",
    tags = { "pierce", "swift", "burst", "spiritual", "dark" },
})

CardSystem.registerCard({
    id        = "byakuya_noble",
    name      = "Byakuya Kuchiki, Noble Blade",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Shinigami", "Captain" },
    element   = "Air",
    rarity    = "Mythic Rare",
    manaCost  = 5,
    power     = 4,
    toughness = 5,
    keywords  = { "Vigilance" },
    effects   = {
        -- Bankai passive: deal 1 damage to all opponent creatures at start of your turn
        { type = "damage", amount = 1, target = "all_enemies",
          special = "petal_storm_each_turn" },
    },
    description = "Vigilance. Can't be removed by non-Legendary spells. "
               .. "Bankai — Senbonzakura Kageyoshi: at the start of each of your turns, "
               .. "deal 1 damage to all opponent creatures.",
    art  = "byakuya_noble",
    tags = { "aoe", "control", "spiritual", "air" },
})

CardSystem.registerCard({
    id        = "rukia_ice",
    name      = "Rukia Kuchiki, Dance of Ice",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Shinigami" },
    element   = "Water",
    rarity    = "Rare",
    manaCost  = 4,
    power     = 2,
    toughness = 4,
    keywords  = {},
    effects   = {
        -- White Dance: tap target creature; it doesn't untap for 2 turns
        { type = "tap", amount = 0, target = "enemy",
          special = "freeze_2_turns" },
        -- Bankai — Hakka no Togame: all opponents lose 3 life; freeze 2 targets permanently
        { type = "damage", amount = 3, target = "all_enemies",
          special = "bankai_freeze_2_permanent_once" },
    },
    description = "White Dance: tap target creature; it doesn't untap for 2 turns. "
               .. "Bankai — Hakka no Togame: all opponents lose 3 life. "
               .. "Freeze up to 2 targets permanently until Rukia leaves.",
    art  = "rukia_ice",
    tags = { "freeze", "control", "spiritual", "water" },
})

CardSystem.registerCard({
    id        = "kenpachi_eyepatch",
    name      = "Kenpachi Zaraki, No Eyepatch",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Shinigami", "Captain" },
    element   = "Dark",
    rarity    = "Mythic Rare",
    manaCost  = 6,
    power     = 6,
    toughness = 6,
    keywords  = {},
    effects   = {
        -- Always attacks if able; deals double combat damage
        { type = "buff", amount = 0, target = "self", duration = 0,
          special = "must_attack_double_damage" },
        -- Takes 3 damage at start of each turn (berserk cost)
        { type = "damage", amount = 3, target = "self",
          special = "berserk_upkeep_cost" },
        -- Eyepatch Off: once per game → 9/9 with Trample
        { type = "buff", amount = 3, target = "self", duration = 0,
          special = "eyepatch_off_9_9_trample_once" },
    },
    description = "Kenpachi attacks each turn if able and deals double combat damage. "
               .. "At the start of your turn, Kenpachi takes 3 damage. "
               .. "Eyepatch Off (once per game): Kenpachi becomes 9/9 with Trample.",
    art  = "kenpachi_eyepatch",
    tags = { "berserker", "burst", "dark" },
})

-- ── SUPPORT CREATURES ────────────────────────────────────────────

CardSystem.registerCard({
    id        = "hitsugaya_dragon",
    name      = "Toshiro Hitsugaya, Ice Dragon",
    cardType  = "Creature",
    subTypes  = { "Shinigami", "Captain" },
    element   = "Water",
    rarity    = "Uncommon",
    manaCost  = 3,
    power     = 3,
    toughness = 5,
    keywords  = {},
    effects   = {
        -- Hyorinmaru: whenever Hitsugaya deals damage, place an ice counter on that creature
        -- At 3 counters, it's exiled until Hitsugaya leaves
        { type = "debuff", amount = 0, target = "enemy", duration = 0,
          special = "ice_counter_3_exile" },
    },
    description = "Hyorinmaru: whenever Hitsugaya deals damage, place an ice counter on that creature. "
               .. "A creature with 3 ice counters is exiled until Hitsugaya leaves the battlefield.",
    art  = "hitsugaya_dragon",
    tags = { "freeze", "control", "spiritual", "water" },
})

CardSystem.registerCard({
    id        = "yoruichi_shunko",
    name      = "Yoruichi Shihoin, Flash Goddess",
    cardType  = "Creature",
    subTypes  = { "Shinigami" },
    element   = "Air",
    rarity    = "Uncommon",
    manaCost  = 3,
    power     = 4,
    toughness = 3,
    keywords  = {},
    effects   = {
        -- Cannot be targeted during opponent's turn
        { type = "buff", amount = 0, target = "self", duration = 0,
          special = "hexproof_opponents_turn" },
        -- Flash Step: untap after blocking — she blocks and returns safely
        { type = "buff", amount = 0, target = "self", duration = 0,
          special = "untap_after_blocking" },
    },
    description = "Yoruichi can't be targeted during your opponent's turn. "
               .. "Flash Step: after Yoruichi blocks, untap her.",
    art  = "yoruichi_shunko",
    tags = { "swift", "defensive", "spiritual", "air" },
})

CardSystem.registerCard({
    id        = "ulquiorra_cuatro",
    name      = "Ulquiorra Cifer, Cuatro Espada",
    cardType  = "Creature",
    subTypes  = { "Espada", "Hollow" },
    element   = "Dark",
    rarity    = "Rare",
    manaCost  = 4,
    power     = 4,
    toughness = 4,
    keywords  = { "Flying" },
    effects   = {
        -- Hierro: reduce non-legendary damage by 2
        { type = "buff", amount = 2, target = "self", duration = 0,
          special = "hierro_reduce_nonlegendary_damage" },
        -- Segunda Etapa: once per game, become 6/6 and regenerate if killed
        { type = "buff", amount = 2, target = "self", duration = 0,
          special = "segunda_etapa_6_6_once" },
    },
    description = "Flying. Hierro: reduce all non-Legendary damage dealt to Ulquiorra by 2. "
               .. "Segunda Etapa (once per game): become 6/6 and regenerate if destroyed this turn.",
    art  = "ulquiorra_cuatro",
    tags = { "defensive", "pierce", "spiritual", "dark" },
})

-- ── SHIKAI / BANKAI SPELLS ───────────────────────────────────────

CardSystem.registerCard({
    id       = "spell_getsuga",
    name     = "Getsuga Tensho",
    cardType = "Instant",
    subTypes = { "Zanpakuto" },
    element  = "Dark",
    rarity   = "Uncommon",
    manaCost = 3,
    effects  = {
        { type = "damage", amount = 6, target = "enemy" },
        -- If Ichigo cast it: costs 1 less and can't be countered
        { type = "buff", amount = 1, target = "self", special = "ichigo_discount_uncounterable" },
    },
    description = "Deal 6 damage to target creature or player. "
               .. "If Ichigo cast this, it costs 1 less and can't be countered.",
    art  = "spell_getsuga",
    tags = { "pierce", "burst", "spiritual", "dark" },
})

CardSystem.registerCard({
    id       = "spell_kurohitsugi",
    name     = "Kido: Kurohitsugi",
    cardType = "Sorcery",
    subTypes = { "Kido" },
    element  = "Dark",
    rarity   = "Rare",
    manaCost = 4,
    effects  = {
        -- Exile target creature for 2 turns; it can't be searched or reanimated while exiled
        { type = "exile", amount = 2, target = "enemy",
          special = "exile_2_turns_untouchable" },
    },
    description = "Exile target creature for 2 turns. While exiled, it can't be searched, copied, or reanimated.",
    art  = "spell_kurohitsugi",
    tags = { "control", "spiritual", "dark" },
})

CardSystem.registerCard({
    id       = "spell_hollow_mask",
    name     = "Hollow Mask Surge",
    cardType = "Instant",
    subTypes = {},
    element  = "Dark",
    rarity   = "Uncommon",
    manaCost = 2,
    effects  = {
        -- Target Shinigami gets +3/+0 and Trample until end of turn
        { type = "buff", amount = 3, target = "ally", duration = 1,
          special = "shinigami_plus3_trample" },
        -- That creature takes 2 damage at end of turn (inner Hollow cost)
        { type = "damage", amount = 2, target = "ally",
          special = "recoil_end_of_turn" },
    },
    description = "Target Shinigami gets +3/+0 and Trample until end of turn. "
               .. "That creature takes 2 damage at end of turn.",
    art  = "spell_hollow_mask",
    tags = { "burst", "berserker", "dark" },
})

CardSystem.registerCard({
    id       = "spell_soul_king",
    name     = "Soul King's Blessing",
    cardType = "Enchantment",
    subTypes = {},
    element  = "Light",
    rarity   = "Rare",
    manaCost = 4,
    effects  = {
        -- All your Shinigami gain +2/+2 and Lifelink
        { type = "buff", amount = 2, target = "ally", duration = 0,
          special = "all_shinigami_plus2_lifelink" },
        -- When a Shinigami kills a creature, gain 2 life
        { type = "heal", amount = 2, target = "self",
          special = "on_shinigami_kill" },
    },
    description = "All Shinigami you control get +2/+2 and Lifelink. "
               .. "Whenever a Shinigami you control destroys a creature, gain 2 life.",
    art  = "spell_soul_king",
    tags = { "regen", "control", "spiritual", "light" },
})


-- ═══════════════════════════════════════════════════════════════════
--  SECTION 4 — DRAGON BALL Z
--  Colors: Red (Fire) + White (Light)
--  Strategy: Pure power escalation. Ki cards hit hard.
--  Saiyans get stronger as the game goes on. No frills — just
--  overwhelming force applied until the opponent runs out of answers.
--
--  Cross-theme tags: "burst", "spiritual", "swift", "pierce"
--  Note: Ultra Instinct and SSJ transformations beyond SSJ3 are
--  held for future updates — the base set runs Saiyan + Namekian.
-- ═══════════════════════════════════════════════════════════════════

-- ── LEGENDARY CREATURES ──────────────────────────────────────────

CardSystem.registerCard({
    id        = "goku_saiyan",
    name      = "Goku, Saiyan of Legend",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Saiyan", "Warrior" },
    element   = "Fire",
    rarity    = "Mythic Rare",
    manaCost  = 4,
    power     = 5,
    toughness = 4,
    keywords  = { "Haste" },
    effects   = {
        -- Zenkai Surge: when Goku returns from the graveyard, he enters with +1/+1 permanently
        { type = "buff", amount = 1, target = "self", duration = 0,
          special = "zenkai_reenter_plus1" },
        -- Kamehameha: 2 mana, deal 4 damage to any target
        { type = "damage", amount = 4, target = "enemy",
          special = "kamehameha_2mana" },
    },
    description = "Haste. Zenkai Surge: whenever Goku re-enters from the graveyard, he gets +1/+1 permanently. "
               .. "Activate — Kamehameha (2 mana): deal 4 damage to any target.",
    art  = "goku_saiyan",
    tags = { "burst", "swift", "spiritual", "fire" },
})

CardSystem.registerCard({
    id        = "vegeta_prince",
    name      = "Vegeta, Prince of Saiyans",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Saiyan", "Warrior" },
    element   = "Fire",
    rarity    = "Mythic Rare",
    manaCost  = 5,
    power     = 5,
    toughness = 5,
    keywords  = { "First Strike" },
    effects   = {
        -- It's Over 9000!: when Vegeta's total power exceeds 9 via buffs, he gains Indestructible
        { type = "buff", amount = 0, target = "self", duration = 0,
          special = "indestructible_if_power_9plus" },
        -- Final Flash: sorcery speed, deal 7 damage to one target
        { type = "damage", amount = 7, target = "enemy",
          special = "final_flash_sorcery_speed" },
    },
    description = "First Strike. It's Over 9000!: if Vegeta's power reaches 9 or more, he gains Indestructible. "
               .. "Activate — Final Flash (4 mana, sorcery speed): deal 7 damage to target creature.",
    art  = "vegeta_prince",
    tags = { "burst", "pierce", "spiritual", "fire" },
})

CardSystem.registerCard({
    id        = "gohan_potential",
    name      = "Gohan, Hidden Potential",
    cardType  = "Creature",
    subTypes  = { "Legendary", "Saiyan", "Scholar" },
    element   = "Light",
    rarity    = "Rare",
    manaCost  = 4,
    power     = 3,
    toughness = 4,
    keywords  = {},
    effects   = {
        -- Latent Power: whenever Gohan takes damage, he gains +1/+0 permanently
        { type = "buff", amount = 1, target = "self", duration = 0,
          special = "plus1_power_per_damage_taken" },
        -- Hidden Potential: if power reaches 7+, gains Double Strike and Flying until end of turn
        { type = "buff", amount = 0, target = "self", duration = 1,
          special = "double_strike_flying_at_power7" },
    },
    description = "Latent Power: whenever Gohan takes damage, he gets +1/+0 permanently. "
               .. "If his power reaches 7 or more, he gains Double Strike and Flying.",
    art  = "gohan_potential",
    tags = { "burst", "spiritual", "light" },
})

-- ── SUPPORT CREATURES ────────────────────────────────────────────

CardSystem.registerCard({
    id        = "piccolo_namekian",
    name      = "Piccolo, Namekian Warrior",
    cardType  = "Creature",
    subTypes  = { "Namekian", "Warrior" },
    element   = "Dark",
    rarity    = "Uncommon",
    manaCost  = 3,
    power     = 4,
    toughness = 4,
    keywords  = { "Reach" },
    effects   = {
        -- Regeneration: once per turn, if Piccolo would die, regenerate him instead
        { type = "buff", amount = 0, target = "self", duration = 0,
          special = "regenerate_once_per_turn" },
        -- Special Beam Cannon: tap, 3 damage, pierces all defense
        { type = "damage", amount = 3, target = "enemy",
          special = "special_beam_pierce_all" },
    },
    description = "Reach. Regeneration: once per turn, if Piccolo would be destroyed, regenerate instead. "
               .. "Tap — Special Beam Cannon: deal 3 damage to target creature, ignoring all defense.",
    art  = "piccolo_namekian",
    tags = { "pierce", "regen", "dark" },
})

CardSystem.registerCard({
    id        = "trunks_future",
    name      = "Trunks, From the Future",
    cardType  = "Creature",
    subTypes  = { "Saiyan", "Warrior" },
    element   = "Light",
    rarity    = "Uncommon",
    manaCost  = 3,
    power     = 4,
    toughness = 3,
    keywords  = { "Haste", "First Strike" },
    effects   = {
        -- When Trunks enters, look at the top 2 cards of your deck and put one in hand
        { type = "draw", amount = 1, target = "self",
          special = "scry_2_draw_1" },
    },
    description = "Haste, First Strike. When Trunks enters, look at the top 2 cards of your deck "
               .. "and put one into your hand (the other goes to the bottom).",
    art  = "trunks_future",
    tags = { "swift", "burst", "draw", "light" },
})

-- ── KI SPELLS ────────────────────────────────────────────────────

CardSystem.registerCard({
    id       = "ki_kamehameha",
    name     = "Kamehameha",
    cardType = "Instant",
    subTypes = { "Ki" },
    element  = "Fire",
    rarity   = "Common",
    manaCost = 3,
    effects  = {
        { type = "damage", amount = 5, target = "enemy" },
    },
    description = "Deal 5 damage to target creature or player.",
    art  = "ki_kamehameha",
    tags = { "burst", "direct", "spiritual", "fire" },
})

CardSystem.registerCard({
    id       = "ki_spirit_bomb",
    name     = "Spirit Bomb",
    cardType = "Sorcery",
    subTypes = { "Ki", "Legendary" },
    element  = "Light",
    rarity   = "Mythic Rare",
    manaCost = 7,
    effects  = {
        -- Deal 10 damage split as you choose among any targets
        { type = "damage", amount = 10, target = "all_enemies",
          special = "split_10_damage_any_targets" },
    },
    description = "Deal 10 damage divided as you choose among any number of targets. "
               .. "(Goku channels the energy of all living things.)",
    art  = "ki_spirit_bomb",
    tags = { "burst", "aoe", "spiritual", "light" },
})

-- ──────────────────────────────────────────────────────────────────
-- Return true — DeckService uses this to confirm registration.
-- To add future cards, create a new file (e.g. TYBWCards.luau)
-- that follows the same pattern and require it alongside this one.
-- ──────────────────────────────────────────────────────────────────
return true
