--[[
    GameState.luau
    Location: ReplicatedStorage/Shared/GameState

    THE LIVE MATCH DATA MODEL
    =========================
    This module defines and manages the state of a single active match.
    One GameState object is created per match by MatchService on the server.

    A match has two players (identified as "p1" and "p2").
    Each player has:
        hand        — cards currently in hand
        deck        — remaining cards to draw from (shuffled at match start)
        graveyard   — cards that have been destroyed or discarded
        battlefield — creatures currently in play
        life        — current life total (starts at 20)
        mana        — mana available this turn
        maxMana     — mana cap this turn (increases 1 per turn, max 10)

    The match itself tracks:
        turnNumber  — how many turns have elapsed
        activePlayer— "p1" or "p2" — whose turn it is
        phase       — "draw" | "main" | "combat" | "end"
        winner      — nil until the game ends; then "p1" or "p2"

    ── HOW TO USE ────────────────────────────────────────────────
        local GameState = require(Shared.GameState)
        local state = GameState.new(p1UserId, p1Deck, p2UserId, p2Deck)

    All mutating helpers live here so game logic stays in one place.
    ──────────────────────────────────────────────────────────────
]]

local GameState = {}
GameState.__index = GameState

-- ── CONSTANTS ──────────────────────────────────────────────────
local STARTING_LIFE   = 20
local STARTING_HAND   = 5    -- cards drawn at match start
local MAX_HAND_SIZE   = 7
local MAX_MANA        = 10   -- mana cap per turn

-- ── PRIVATE: Fisher-Yates shuffle ──────────────────────────────
local function shuffle(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- ── PRIVATE: build a fresh player state ────────────────────────
local function newPlayer(userId, deckCardIds)
    -- Deep-copy and shuffle the deck
    local deck = {}
    for _, id in ipairs(deckCardIds) do
        table.insert(deck, id)
    end
    shuffle(deck)

    return {
        userId      = userId,
        life        = STARTING_LIFE,
        mana        = 0,
        maxMana     = 0,
        hand        = {},       -- list of card ids currently in hand
        deck        = deck,     -- remaining draw pile
        graveyard   = {},       -- discarded / destroyed cards
        battlefield = {},       -- { id, instanceId, power, toughness, keywords,
                                --   damageTaken, tapped, summonedThisTurn, effects }
        attackers   = {},       -- creature instanceIds declared as attackers
        blockers    = {},       -- { [attackerInstanceId] = blockerInstanceId }
    }
end

-- ── CONSTRUCTOR ────────────────────────────────────────────────
-- Creates a brand-new match state.
-- p1DeckIds / p2DeckIds: ordered lists of card id strings (from PlayerDeck.cards)
function GameState.new(p1UserId, p1DeckIds, p2UserId, p2DeckIds)
    local self = setmetatable({}, GameState)

    self.p1 = newPlayer(p1UserId, p1DeckIds)
    self.p2 = newPlayer(p2UserId, p2DeckIds)

    self.turnNumber   = 1
    self.activePlayer = "p1"   -- p1 always goes first
    self.phase        = "main" -- both players already drew opening hands; skip draw step
    self.winner       = nil    -- set when a player's life hits 0

    -- Draw opening hands (no draw step on turn 1 — straight to main)
    self:_drawCards("p1", STARTING_HAND)
    self:_drawCards("p2", STARTING_HAND)

    -- Give p1 their first turn's mana (done here so they can act immediately)
    self:_refreshMana("p1")

    return self
end

-- ── PRIVATE HELPERS ────────────────────────────────────────────

-- Returns the player table for a given key ("p1" or "p2")
function GameState:_player(key)
    return self[key]
end

-- Returns the key of the opponent of `key`
function GameState:_opponent(key)
    return key == "p1" and "p2" or "p1"
end

-- Draw n cards from the player's deck into their hand.
-- Returns the list of card ids that were drawn.
function GameState:_drawCards(playerKey, n)
    local p      = self:_player(playerKey)
    local drawn  = {}

    for _ = 1, n do
        if #p.deck == 0 then
            -- Deck out — player loses
            self.winner = self:_opponent(playerKey)
            break
        end
        if #p.hand >= MAX_HAND_SIZE then
            -- Discard to graveyard (max hand size reached)
            local discarded = table.remove(p.deck, 1)
            table.insert(p.graveyard, discarded)
        else
            local card = table.remove(p.deck, 1)
            table.insert(p.hand, card)
            table.insert(drawn, card)
        end
    end

    return drawn
end

-- Ramp mana for a player at the start of their turn.
function GameState:_refreshMana(playerKey)
    local p      = self:_player(playerKey)
    p.maxMana    = math.min(p.maxMana + 1, MAX_MANA)
    p.mana       = p.maxMana
end

-- ── UNIQUE INSTANCE IDs ────────────────────────────────────────
-- Every creature that enters the battlefield gets a unique id so we can
-- target and track it even if the same card id appears multiple times.
local _nextInstanceId = 1
local function nextInstanceId()
    local id = _nextInstanceId
    _nextInstanceId += 1
    return "creature_" .. id
end

-- ── PUBLIC MUTATORS ────────────────────────────────────────────

--[[
    Play a card from the player's hand onto the battlefield (Creature)
    or resolve it immediately (Spell).
    Returns: true on success, false + reason string on failure.

    cardData: the full card table from CardSystem (pass it in; GameState
              doesn't require CardSystem itself to stay dependency-free).
]]
function GameState:playCard(playerKey, cardId, cardData)
    local p = self:_player(playerKey)

    -- Check it's this player's main phase
    if self.activePlayer ~= playerKey then
        return false, "Not your turn."
    end
    if self.phase ~= "main" then
        return false, "Can only play cards during the main phase."
    end

    -- Check mana
    if p.mana < cardData.manaCost then
        return false, "Not enough mana (need " .. cardData.manaCost .. ", have " .. p.mana .. ")."
    end

    -- Check the card is in hand
    local handIndex = nil
    for i, id in ipairs(p.hand) do
        if id == cardId then handIndex = i; break end
    end
    if not handIndex then
        return false, "Card not in hand."
    end

    -- Spend mana and remove from hand
    p.mana -= cardData.manaCost
    table.remove(p.hand, handIndex)

    if cardData.cardType == "Creature" then
        -- Enter the battlefield
        local instance = {
            id               = cardData.id,
            instanceId       = nextInstanceId(),
            name             = cardData.name,
            power            = cardData.power,
            toughness        = cardData.toughness,
            keywords         = { table.unpack(cardData.keywords or {}) },
            effects          = cardData.effects or {},
            damageTaken      = 0,
            tapped           = false,
            -- Haste: can attack immediately; others must wait until next turn
            summonedThisTurn = not (table.find(cardData.keywords, "Haste") ~= nil),
        }
        table.insert(p.battlefield, instance)
        return true, instance.instanceId

    else
        -- Non-creature: goes to graveyard after resolving
        -- (Effect resolution is handled by CardEffectResolver, not here)
        table.insert(p.graveyard, cardId)
        return true, nil
    end
end

--[[
    Spend mana explicitly (used by activated abilities like Kamehameha).
]]
function GameState:spendMana(playerKey, amount)
    local p = self:_player(playerKey)
    if p.mana < amount then return false, "Not enough mana." end
    p.mana -= amount
    return true
end

--[[
    Deal damage to a player's life total.
    Automatically sets self.winner if life drops to 0.
]]
function GameState:damagePlayer(playerKey, amount)
    local p = self:_player(playerKey)
    p.life = math.max(0, p.life - amount)
    if p.life == 0 then
        self.winner = self:_opponent(playerKey)
    end
end

--[[
    Heal a player's life total (no upper cap — same as MTG).
]]
function GameState:healPlayer(playerKey, amount)
    local p = self:_player(playerKey)
    p.life += amount
end

--[[
    Deal damage to a creature on the battlefield.
    Creature is destroyed when damageTaken >= toughness.
    Returns true if the creature was destroyed.
]]
function GameState:damageCreature(playerKey, instanceId, amount)
    local p = self:_player(playerKey)
    for i, creature in ipairs(p.battlefield) do
        if creature.instanceId == instanceId then
            creature.damageTaken += amount
            if creature.damageTaken >= creature.toughness then
                table.remove(p.battlefield, i)
                table.insert(p.graveyard, creature.id)
                return true  -- creature died
            end
            return false  -- creature survived
        end
    end
    return false  -- instanceId not found
end

--[[
    Buff a creature's power and/or toughness.
    duration: 0 = permanent, 1+ = end of turn (tracking is caller's responsibility)
]]
function GameState:buffCreature(playerKey, instanceId, powerBonus, toughnessBonus)
    local p = self:_player(playerKey)
    for _, creature in ipairs(p.battlefield) do
        if creature.instanceId == instanceId then
            creature.power     += (powerBonus    or 0)
            creature.toughness += (toughnessBonus or 0)
            return true
        end
    end
    return false
end

--[[
    Tap a creature (sets tapped = true).
    Tapped creatures cannot attack and some effects require untapping.
]]
function GameState:tapCreature(playerKey, instanceId)
    local p = self:_player(playerKey)
    for _, creature in ipairs(p.battlefield) do
        if creature.instanceId == instanceId then
            creature.tapped = true
            return true
        end
    end
    return false
end

--[[
    Untap all creatures for a player (called at start of their turn).
]]
function GameState:untapAll(playerKey)
    local p = self:_player(playerKey)
    for _, creature in ipairs(p.battlefield) do
        creature.tapped = false
    end
end

--[[
    Clear per-turn damage from all creatures (end-of-turn cleanup).
    In MTG, damage is removed from creatures at end of turn.
]]
function GameState:clearCombatDamage(playerKey)
    local p = self:_player(playerKey)
    for _, creature in ipairs(p.battlefield) do
        creature.damageTaken = 0
    end
end

--[[
    Advance to the next turn.
    Switches active player, increments turn counter, runs upkeep.
    Returns the key of the new active player.
]]
function GameState:nextTurn()
    local current  = self.activePlayer
    local next     = self:_opponent(current)

    -- End-of-turn cleanup for the player who just went
    self:clearCombatDamage(current)

    -- Clear declared attackers / blockers
    self.p1.attackers = {}
    self.p1.blockers  = {}
    self.p2.attackers = {}
    self.p2.blockers  = {}

    -- Mark all creatures as no longer summoned this turn
    for _, creature in ipairs(self:_player(next).battlefield) do
        creature.summonedThisTurn = false
    end

    -- Advance state
    self.turnNumber  += 1
    self.activePlayer = next
    self.phase        = "draw"

    -- Untap + ramp mana for the new active player
    self:untapAll(next)
    self:_refreshMana(next)

    -- Draw one card for the new active player
    local drawn = self:_drawCards(next, 1)

    -- Automatically move to main phase after draw
    self.phase = "main"

    return next, drawn
end

--[[
    Get a snapshot of the match safe to send to a specific player.
    Hides the opponent's hand (they can only see card counts, not ids).
]]
function GameState:getSnapshot(forPlayerKey)
    local opponentKey = self:_opponent(forPlayerKey)
    local me  = self:_player(forPlayerKey)
    local opp = self:_player(opponentKey)

    return {
        myUserId        = me.userId,
        oppUserId       = opp.userId,

        myLife          = me.life,
        oppLife         = opp.life,

        myMana          = me.mana,
        myMaxMana       = me.maxMana,

        myHand          = table.clone(me.hand),       -- full card ids
        oppHandCount    = #opp.hand,                  -- count only (hidden info)

        myDeckCount     = #me.deck,
        oppDeckCount    = #opp.deck,

        myBattlefield   = me.battlefield,             -- full creature data
        oppBattlefield  = opp.battlefield,            -- full creature data (visible)

        myGraveyard     = me.graveyard,
        oppGraveyard    = opp.graveyard,

        turnNumber      = self.turnNumber,
        activePlayer    = self.activePlayer,          -- "p1" or "p2"
        isMyTurn        = self.activePlayer == forPlayerKey,
        phase           = self.phase,
        winner          = self.winner,
    }
end

-- ── UTILITY ────────────────────────────────────────────────────

-- Find a creature on ANY player's battlefield by instanceId.
-- Returns: playerKey, creature table (or nil, nil if not found)
function GameState:findCreature(instanceId)
    for _, key in ipairs({ "p1", "p2" }) do
        for _, creature in ipairs(self:_player(key).battlefield) do
            if creature.instanceId == instanceId then
                return key, creature
            end
        end
    end
    return nil, nil
end

-- Check if the match is over.
function GameState:isOver()
    return self.winner ~= nil
end

return GameState
