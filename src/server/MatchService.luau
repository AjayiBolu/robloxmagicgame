--[[
    MatchService.luau
    Location: ServerScriptService/Server/MatchService

    MATCHMAKING + MATCH LIFECYCLE
    ==============================
    Responsible for:
      1. Queuing players who want to find a match
      2. Pairing two queued players into a live match
      3. Owning every active GameState on the server
      4. Handling all battle-related remote calls from clients

    This module does NOT contain game logic (damage math, effect
    resolution, combat) — those live in CardEffectResolver and
    CombatResolver (Phase 2). Right now MatchService drives
    the turn structure and delegates effect/combat resolution
    once those modules exist.

    Usage (from init.server.luau):
        local MatchService = require(script.MatchService)
        MatchService.start(matchRemotes, deckService)
]]

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared     = ReplicatedStorage:WaitForChild("Shared")
local CardSystem = require(Shared:WaitForChild("CardSystem"))
local GameState  = require(Shared:WaitForChild("GameState"))
local BoardSkinRegistry = require(Shared:WaitForChild("BoardSkinRegistry"))

-- Resolve a deck's equipped board skin, falling back to the default.
-- Skin equipping isn't persisted yet (out of scope) so this is "default"
-- in practice, but the plumbing carries it end-to-end already.
local function deckSkinId(deck)
    return (deck and deck.equippedSkinId) or BoardSkinRegistry.DEFAULT_SKIN_ID
end

-- ── IN-MEMORY STATE ────────────────────────────────────────────
-- Queue of players waiting for a match (list of Player objects)
local queue = {}

-- Active matches keyed by matchId.
-- matchId is just a string "match_<p1UserId>_<p2UserId>"
-- { matchId, state (GameState), p1 (Player), p2 (Player),
--   p1Key ("p1"), p2Key ("p2") }
local activeMatches = {}

-- Map userId → matchId for quick lookup
local playerMatch = {}

-- ── PRIVATE HELPERS ────────────────────────────────────────────

local function getMatchForPlayer(player)
    local matchId = playerMatch[player.UserId]
    if not matchId then return nil end
    return activeMatches[matchId]
end

-- Given a match and a Player, return which key they are ("p1" or "p2")
local function playerKey(match, player)
    return match.p1.UserId == player.UserId and "p1" or "p2"
end

-- Notify both players of the current game snapshot
local function broadcastState(match, remotes)
    local p1Key = "p1"
    local p2Key = "p2"

    -- Send each player their own perspective
    remotes.MatchStateUpdate:FireClient(
        match.p1,
        match.state:getSnapshot(p1Key)
    )
    remotes.MatchStateUpdate:FireClient(
        match.p2,
        match.state:getSnapshot(p2Key)
    )
end

-- Fire a cosmetic cutscene cue to BOTH match participants.
-- State is ALWAYS broadcast before this is called — the cutscene is purely
-- cosmetic and never gates game progress. Each client decides (from its own
-- local settings) whether to actually play it or silently drop it.
-- payload: { cardId, cutsceneType = "cardPlay"|"cardIntro"|"win"|"loss", actorKey }
local function fireCutscene(match, remotes, payload)
    if not remotes.TriggerCutscene then return end
    remotes.TriggerCutscene:FireClient(match.p1, payload)
    remotes.TriggerCutscene:FireClient(match.p2, payload)
end

-- Notify both players that the match ended
local function broadcastMatchOver(match, remotes)
    local winner = match.state.winner
    -- winner is "p1" or "p2"; translate to userId for the client
    local winnerUserId = match[winner].UserId

    remotes.MatchOver:FireClient(match.p1, winnerUserId)
    remotes.MatchOver:FireClient(match.p2, winnerUserId)

    -- Cosmetic win/loss cinematics — fired AFTER MatchOver so state leads.
    -- Each participant gets the type that matches their result.
    local loser = winner == "p1" and "p2" or "p1"
    if remotes.TriggerCutscene then
        remotes.TriggerCutscene:FireClient(match[winner], { cutsceneType = "win",  actorKey = "victory" })
        remotes.TriggerCutscene:FireClient(match[loser],  { cutsceneType = "loss", actorKey = "defeat"  })
    end

    -- Clean up
    activeMatches[match.matchId] = nil
    playerMatch[match.p1.UserId] = nil
    playerMatch[match.p2.UserId] = nil

    print("[MatchService] Match over:", match.matchId, "| Winner userId:", winnerUserId)
end

-- Create a match between two players
local function createMatch(p1, p2, p1Deck, p2Deck, remotes)
    local matchId = "match_" .. p1.UserId .. "_" .. p2.UserId

    local state = GameState.new(
        p1.UserId, p1Deck.cards,
        p2.UserId, p2Deck.cards
    )

    local match = {
        matchId  = matchId,
        state    = state,
        p1       = p1,
        p2       = p2,
    }

    activeMatches[matchId] = match
    playerMatch[p1.UserId] = matchId
    playerMatch[p2.UserId] = matchId

    print("[MatchService] Match created:", matchId)

    -- Each player's equipped board skin — sent to BOTH clients so each can
    -- render the opponent's half with their skin immediately on match start.
    local p1Skin = deckSkinId(p1Deck)
    local p2Skin = deckSkinId(p2Deck)

    -- Tell clients they are in a match and who they're facing.
    -- playerSkinId   = the recipient's own skin
    -- opponentSkinId = the other player's skin
    remotes.MatchFound:FireClient(p1, {
        matchId        = matchId,
        opponentName   = p2.Name,
        playerName     = p1.Name,
        playerKey      = "p1",
        playerSkinId   = p1Skin,
        opponentSkinId = p2Skin,
    })
    remotes.MatchFound:FireClient(p2, {
        matchId        = matchId,
        opponentName   = p1.Name,
        playerName     = p2.Name,
        playerKey      = "p2",
        playerSkinId   = p2Skin,
        opponentSkinId = p1Skin,
    })

    -- Send initial game state to both players
    broadcastState(match, remotes)

    return match
end

-- Try to pair two players from the queue
local function tryPairPlayers(remotes, deckService)
    while #queue >= 2 do
        local p1 = table.remove(queue, 1)
        local p2 = table.remove(queue, 1)

        -- Make sure both players are still in the game
        if not p1.Parent or not p2.Parent then
            -- One of them left — put the surviving one back
            if p1.Parent then table.insert(queue, 1, p1) end
            if p2.Parent then table.insert(queue, 1, p2) end
            continue
        end

        -- Make sure neither is already in a match
        if playerMatch[p1.UserId] or playerMatch[p2.UserId] then
            continue
        end

        -- Fetch their decks
        local p1Deck = deckService.getDeck(p1)
        local p2Deck = deckService.getDeck(p2)

        if not p1Deck or not p1Deck.packId or #p1Deck.cards == 0 then
            warn("[MatchService] " .. p1.Name .. " has no valid deck — returning to queue")
            table.insert(queue, 1, p2)
            continue
        end
        if not p2Deck or not p2Deck.packId or #p2Deck.cards == 0 then
            warn("[MatchService] " .. p2.Name .. " has no valid deck — returning to queue")
            table.insert(queue, 1, p1)
            continue
        end

        createMatch(p1, p2, p1Deck, p2Deck, remotes)
    end
end

-- ── PUBLIC API ────────────────────────────────────────────────
local MatchService = {}

--[[
    MatchService.start(remotes, deckService)

    remotes     — MatchEvents folder from RemoteSetup
    deckService — reference to DeckService so we can read player decks

    Wires all remote handlers.
]]
function MatchService.start(remotes, deckService)

    -- ── Remote: JoinQueue ───────────────────────────────────────
    -- Client fires this when the player wants to find a match.
    remotes.JoinQueue.OnServerEvent:Connect(function(player)
        -- Don't queue if already in a match or already queued
        if playerMatch[player.UserId] then
            warn("[MatchService]", player.Name, "tried to queue but is already in a match")
            return
        end
        for _, p in ipairs(queue) do
            if p == player then return end  -- already in queue
        end

        table.insert(queue, player)
        print("[MatchService]", player.Name, "joined the queue. Queue size:", #queue)

        -- Tell the client they're in queue
        remotes.QueueStatus:FireClient(player, { inQueue = true, position = #queue })

        -- Try to pair immediately
        tryPairPlayers(remotes, deckService)
    end)

    -- ── Remote: LeaveQueue ──────────────────────────────────────
    remotes.LeaveQueue.OnServerEvent:Connect(function(player)
        for i, p in ipairs(queue) do
            if p == player then
                table.remove(queue, i)
                print("[MatchService]", player.Name, "left the queue")
                remotes.QueueStatus:FireClient(player, { inQueue = false })
                return
            end
        end
    end)

    -- ── Remote: PlayCard ────────────────────────────────────────
    -- Client fires when the player plays a card from their hand.
    -- args: cardId (string)
    remotes.PlayCard.OnServerEvent:Connect(function(player, cardId)
        local match = getMatchForPlayer(player)
        if not match then return end

        local key      = playerKey(match, player)
        local cardData = CardSystem.getCard(cardId)
        if not cardData then
            warn("[MatchService] PlayCard: unknown cardId:", cardId)
            return
        end

        local ok, result = match.state:playCard(key, cardId, cardData)
        if not ok then
            -- Tell the client why it failed (optional feedback)
            remotes.ActionFailed:FireClient(player, result)
            return
        end

        print("[MatchService]", player.Name, "played:", cardData.name)

        -- ── Phase 2 hook: resolve card effects ──────────────────
        -- When CardEffectResolver exists, call it here:
        --   CardEffectResolver.resolve(match.state, key, cardData)
        -- For now, instant effects (damage, heal) are skipped;
        -- the card just enters the battlefield or goes to graveyard.

        if match.state:isOver() then
            broadcastMatchOver(match, remotes)
        else
            broadcastState(match, remotes)

            -- Cosmetic cue — state is already delivered above. Both clients
            -- decide whether to play it based on their local settings + the
            -- card's rarity. actorKey lets the client pick the right visuals.
            fireCutscene(match, remotes, {
                cardId       = cardId,
                cutsceneType = "cardPlay",
                actorKey     = cardData.id,
            })
        end
    end)

    -- ── Remote: DeclareAttacker ─────────────────────────────────
    -- Client fires this for each creature they want to attack with.
    -- args: instanceId (string)
    remotes.DeclareAttacker.OnServerEvent:Connect(function(player, instanceId)
        local match = getMatchForPlayer(player)
        if not match then return end

        local key   = playerKey(match, player)
        local state = match.state

        if state.activePlayer ~= key or state.phase ~= "combat" then
            remotes.ActionFailed:FireClient(player, "Can only declare attackers during your combat phase.")
            return
        end

        -- Find the creature
        local _, creature = state:findCreature(instanceId)
        if not creature then return end

        -- Only the active player's own creatures can attack
        local p = state:_player(key)
        local owned = false
        for _, c in ipairs(p.battlefield) do
            if c.instanceId == instanceId then owned = true; break end
        end
        if not owned then return end

        -- Can't attack if tapped or summoned this turn (no Haste)
        if creature.tapped then
            remotes.ActionFailed:FireClient(player, creature.name .. " is tapped.")
            return
        end
        if creature.summonedThisTurn then
            remotes.ActionFailed:FireClient(player, creature.name .. " was just summoned (no Haste).")
            return
        end

        -- Add to attackers if not already there
        if not table.find(p.attackers, instanceId) then
            table.insert(p.attackers, instanceId)
            creature.tapped = true  -- attacking taps the creature (unless Vigilance)
            if table.find(creature.keywords, "Vigilance") then
                creature.tapped = false
            end
        end

        broadcastState(match, remotes)
    end)

    -- ── Remote: DeclareBlocker ──────────────────────────────────
    -- Client fires this to assign a blocker to an attacker.
    -- args: blockerInstanceId, attackerInstanceId
    remotes.DeclareBlocker.OnServerEvent:Connect(function(player, blockerInstanceId, attackerInstanceId)
        local match = getMatchForPlayer(player)
        if not match then return end

        local key   = playerKey(match, player)
        local state = match.state

        -- Blockers are declared by the NON-active player during combat
        if state.activePlayer == key or state.phase ~= "combat" then
            remotes.ActionFailed:FireClient(player, "You can only declare blockers during the opponent's combat phase.")
            return
        end

        local p = state:_player(key)

        -- Verify the blocker is this player's creature and is untapped
        local blocker = nil
        for _, c in ipairs(p.battlefield) do
            if c.instanceId == blockerInstanceId then blocker = c; break end
        end
        if not blocker or blocker.tapped then return end

        -- Verify the attacker exists and is actually attacking
        local attackerKey = state:_opponent(key)
        local attackerP   = state:_player(attackerKey)
        if not table.find(attackerP.attackers, attackerInstanceId) then return end

        p.blockers[attackerInstanceId] = blockerInstanceId
        broadcastState(match, remotes)
    end)

    -- ── Remote: EndPhase ────────────────────────────────────────
    -- Client fires this to advance through the phases of their turn.
    -- Phase order: main → combat → end (draw is automatic)
    remotes.EndPhase.OnServerEvent:Connect(function(player)
        local match = getMatchForPlayer(player)
        if not match then return end

        local key   = playerKey(match, player)
        local state = match.state

        if state.activePlayer ~= key then
            remotes.ActionFailed:FireClient(player, "It's not your turn.")
            return
        end

        if state.phase == "main" then
            -- Move to combat phase
            state.phase = "combat"
            broadcastState(match, remotes)

        elseif state.phase == "combat" then
            -- Resolve combat damage then move to end phase
            -- ── Phase 2 hook: CombatResolver.resolve(state) ─────
            -- For now: simple direct damage from unblocked attackers
            local activeKey  = state.activePlayer
            local defKey     = state:_opponent(activeKey)
            local attP       = state:_player(activeKey)
            local defP       = state:_player(defKey)

            for _, attackerInstId in ipairs(attP.attackers) do
                local blocker = attP.blockers[attackerInstId]

                -- Find attacker creature
                local attCreature = nil
                for _, c in ipairs(attP.battlefield) do
                    if c.instanceId == attackerInstId then attCreature = c; break end
                end
                if not attCreature then continue end

                if blocker then
                    -- Find blocker creature
                    local blkCreature = nil
                    for _, c in ipairs(defP.battlefield) do
                        if c.instanceId == blocker then blkCreature = c; break end
                    end
                    if blkCreature then
                        -- Both deal damage to each other simultaneously
                        state:damageCreature(defKey, blocker, attCreature.power)
                        state:damageCreature(activeKey, attackerInstId, blkCreature.power)
                    end
                else
                    -- Unblocked — damage goes to the defending player
                    state:damagePlayer(defKey, attCreature.power)
                end
            end

            -- End phase
            state.phase = "end"

            if match.state:isOver() then
                broadcastMatchOver(match, remotes)
                return
            end

            broadcastState(match, remotes)

        elseif state.phase == "end" then
            -- Advance to next turn
            local nextKey, drawn = state:nextTurn()
            local nextPlayer = nextKey == "p1" and match.p1 or match.p2

            print("[MatchService] Turn", state.turnNumber, "— now", nextPlayer.Name .. "'s turn")

            if match.state:isOver() then
                broadcastMatchOver(match, remotes)
                return
            end

            broadcastState(match, remotes)
        end
    end)

    -- ── Remote: GetMatchState ────────────────────────────────────
    -- Client can request a fresh snapshot at any time (reconnect).
    remotes.GetMatchState.OnServerInvoke = function(player)
        local match = getMatchForPlayer(player)
        if not match then return nil end
        local key = playerKey(match, player)
        return match.state:getSnapshot(key)
    end

    -- ── Remote: ForfeitMatch ─────────────────────────────────────
    remotes.ForfeitMatch.OnServerEvent:Connect(function(player)
        local match = getMatchForPlayer(player)
        if not match then return end

        local key = playerKey(match, player)
        local oppKey = key == "p1" and "p2" or "p1"
        match.state.winner = oppKey

        print("[MatchService]", player.Name, "forfeited.")
        broadcastMatchOver(match, remotes)
    end)

    -- ── Player cleanup on leave ─────────────────────────────────
    Players.PlayerRemoving:Connect(function(player)
        -- Remove from queue
        for i, p in ipairs(queue) do
            if p == player then table.remove(queue, i); break end
        end

        -- Forfeit any active match
        local match = getMatchForPlayer(player)
        if match then
            local key    = playerKey(match, player)
            local oppKey = key == "p1" and "p2" or "p1"
            match.state.winner = oppKey

            local opponent = match[oppKey]
            if opponent and opponent.Parent then
                remotes.MatchOver:FireClient(opponent, opponent.UserId)
            end

            activeMatches[match.matchId] = nil
            playerMatch[player.UserId]   = nil
            playerMatch[match[oppKey].UserId] = nil
        end
    end)

    print("[MatchService] Ready.")
end

-- ── Expose getDeck helper so DeckService can be passed in ──────
-- DeckService is passed in as a table with getDeck(player) method.
-- This keeps MatchService decoupled from DeckService's internals.

return MatchService
