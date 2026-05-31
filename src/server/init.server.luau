--[[
    init.server.luau
    Location: ServerScriptService/Server

    Server entry point — intentionally thin.
    Each service does exactly one job.

    ── ADDING A NEW SERVICE ──────────────────────────────────────
    1. Create YourService.luau in this folder
    2. require it below
    3. Call YourService.start(remotes) with whatever remotes it needs
    ──────────────────────────────────────────────────────────────
]]

local remotes = require(script.RemoteSetup)
-- remotes.deckEvents  = DeckEvents folder
-- remotes.matchEvents = MatchEvents folder

local DeckService  = require(script.DeckService)
local MatchService = require(script.MatchService)

-- DeckService exposes a getDeck helper that MatchService uses
-- to read a player's deck when starting a match.
DeckService.start(remotes.deckEvents)

-- Pass matchEvents and a deckService adapter so MatchService
-- can look up player decks without depending on DeckService directly.
local deckAdapter = {
    getDeck = function(player)
        return DeckService.getDeckForPlayer(player)
    end
}

MatchService.start(remotes.matchEvents, deckAdapter)
