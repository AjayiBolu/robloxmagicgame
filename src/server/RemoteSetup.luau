--[[
    RemoteSetup.luau
    Location: ServerScriptService/Server/RemoteSetup

    Single responsibility: create all RemoteEvents and RemoteFunctions
    the client and server use to talk to each other.

    Called once at game start from init.server.luau.
    Returns a table with two folders:
        result.deckEvents  — DeckEvents  (deck management)
        result.matchEvents — MatchEvents (battle system)

    To add a new remote in the future:
      1. Add its name and class to the right REMOTES table below.
      2. That's it — everything else is automatic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── DECK REMOTES ───────────────────────────────────────────────
-- Used by DeckService ↔ DeckClient
local DECK_REMOTES = {
    SelectPack  = "RemoteEvent",
    AddCard     = "RemoteEvent",
    RemoveCard  = "RemoteEvent",
    GetDeck     = "RemoteFunction",
    GetAllCards = "RemoteFunction",
    GetAllPacks = "RemoteFunction",
}

-- ── MATCH REMOTES ──────────────────────────────────────────────
-- Used by MatchService ↔ MatchClient
local MATCH_REMOTES = {
    -- Client → Server (player actions)
    JoinQueue        = "RemoteEvent",   -- player wants to find a match
    LeaveQueue       = "RemoteEvent",   -- player cancels queue
    PlayCard         = "RemoteEvent",   -- play a card from hand (cardId)
    DeclareAttacker  = "RemoteEvent",   -- declare a creature as attacker (instanceId)
    DeclareBlocker   = "RemoteEvent",   -- assign a blocker (blockerInstanceId, attackerInstanceId)
    EndPhase         = "RemoteEvent",   -- advance the current phase
    ForfeitMatch     = "RemoteEvent",   -- concede the match

    -- Server → Client (game events)
    QueueStatus      = "RemoteEvent",   -- { inQueue, position }
    MatchFound       = "RemoteEvent",   -- { matchId, opponentName, playerKey }
    MatchStateUpdate = "RemoteEvent",   -- full snapshot of game state
    MatchOver        = "RemoteEvent",   -- winnerUserId
    ActionFailed     = "RemoteEvent",   -- reason string (invalid action feedback)
    TriggerCutscene  = "RemoteEvent",   -- { cardId, cutsceneType, actorKey } cosmetic cinematic cue

    -- Client → Server (request/response)
    GetMatchState    = "RemoteFunction", -- request a fresh state snapshot
}

-- ── SETUP ──────────────────────────────────────────────────────
local function makeFolder(name, remotes)
    local folder  = Instance.new("Folder")
    folder.Name   = name
    folder.Parent = ReplicatedStorage

    for remoteName, className in pairs(remotes) do
        local remote  = Instance.new(className)
        remote.Name   = remoteName
        remote.Parent = folder
    end

    return folder
end

local deckEvents  = makeFolder("DeckEvents",  DECK_REMOTES)
local matchEvents = makeFolder("MatchEvents", MATCH_REMOTES)

return {
    deckEvents  = deckEvents,
    matchEvents = matchEvents,
}
