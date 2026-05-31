--[[
    DeckService.luau
    Location: ServerScriptService/Server/DeckService

    Single responsibility: manage each player's deck data.

    Usage (from init.server.luau):
        local remotes     = require(script.RemoteSetup)
        local DeckService = require(script.DeckService)
        DeckService.start(remotes)

    To extend in the future:
        - Add new remote handlers inside DeckService.start()
        - Add new DataStore fields inside loadDeck / saveDeck
        - Do NOT add UI or visual logic here — this is server-only data
]]

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Shared modules (created by Rojo from src/shared/)
local Shared     = ReplicatedStorage:WaitForChild("Shared")
local CardSystem = require(Shared:WaitForChild("CardSystem"))
local PackConfig = require(Shared:WaitForChild("PackConfig"))

-- AnimeCards registers all anime cards into CardSystem at require-time.
-- Must be required here so GetAllCards returns the full card pool.
require(Shared:WaitForChild("AnimeCards"))

-- ──────────────────────────────────────────────────────────────
--  DATASTORE
--  Wrapped in pcall so the game still runs without Studio access.
--  Enable: Game Settings → Security → Studio Access to Game Services
-- ──────────────────────────────────────────────────────────────
local DeckStore = nil
local storeOk, storeResult = pcall(function()
    return DataStoreService:GetDataStore("PlayerDecks_v1")
end)
if storeOk then
    DeckStore = storeResult
else
    warn("[DeckService] DataStore unavailable — decks won't save this session.")
end

-- ──────────────────────────────────────────────────────────────
--  IN-MEMORY CACHE
--  { [userId]: { packId: string|nil, cards: string[] } }
-- ──────────────────────────────────────────────────────────────
local playerDecks = {}

-- ──────────────────────────────────────────────────────────────
--  PRIVATE: DataStore helpers
-- ──────────────────────────────────────────────────────────────
local function loadDeck(player)
    if not DeckStore then return nil end

    local ok, data = pcall(function()
        return DeckStore:GetAsync("deck_" .. player.UserId)
    end)

    if ok and data then return data end
    if not ok then warn("[DeckService] Load failed for " .. player.Name .. ": " .. tostring(data)) end
    return nil
end

local function saveDeck(player)
    if not DeckStore then return end

    local deck = playerDecks[player.UserId]
    if not deck then return end

    local ok, err = pcall(function()
        DeckStore:SetAsync("deck_" .. player.UserId, deck)
    end)

    if not ok then warn("[DeckService] Save failed for " .. player.Name .. ": " .. tostring(err)) end
end

-- ──────────────────────────────────────────────────────────────
--  PRIVATE: Player lifecycle
-- ──────────────────────────────────────────────────────────────
local function onPlayerAdded(player)
    local saved = loadDeck(player)

    if saved and saved.packId and saved.cards then
        playerDecks[player.UserId] = { packId = saved.packId, cards = saved.cards }
        print("[DeckService] Loaded deck for", player.Name, "— pack:", saved.packId, "| cards:", #saved.cards)
    else
        playerDecks[player.UserId] = { packId = nil, cards = {} }
        print("[DeckService] New player:", player.Name)
    end
end

local function onPlayerRemoving(player)
    saveDeck(player)
    playerDecks[player.UserId] = nil
    print("[DeckService] Saved and unloaded deck for", player.Name)
end

-- ──────────────────────────────────────────────────────────────
--  PUBLIC API
-- ──────────────────────────────────────────────────────────────
local DeckService = {}

--[[
    DeckService.start(remotes)
    Call once from init.server.luau after RemoteSetup runs.
    Wires up all remote handlers and player events.
    @param remotes  The DeckEvents folder returned by RemoteSetup
]]
function DeckService.start(remotes)
    -- Player events
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end

    -- ── Remote: SelectPack ──────────────────────────────────
    remotes.SelectPack.OnServerEvent:Connect(function(player, packId)
        local pack = PackConfig.getPack(packId)
        if not pack then
            warn("[DeckService]", player.Name, "sent invalid packId:", packId)
            return
        end

        local deck = playerDecks[player.UserId]
        if not deck or deck.packId then return end  -- already has a pack

        deck.packId = pack.id
        deck.cards  = {}
        for _, cardId in ipairs(pack.starterDeck) do
            table.insert(deck.cards, cardId)
        end

        saveDeck(player)
        print("[DeckService]", player.Name, "selected pack:", pack.name)
    end)

    -- ── Remote: AddCard ─────────────────────────────────────
    remotes.AddCard.OnServerEvent:Connect(function(player, cardId)
        local deck = playerDecks[player.UserId]
        if not deck or not deck.packId then return end
        if not CardSystem.cardExists(cardId) then return end

        local testCards = table.clone(deck.cards)
        table.insert(testCards, cardId)

        local valid, reason = PackConfig.validateDeck(testCards)
        if not valid then
            warn("[DeckService]", player.Name, "can't add card —", reason)
            return
        end

        table.insert(deck.cards, cardId)
        saveDeck(player)
    end)

    -- ── Remote: RemoveCard ──────────────────────────────────
    remotes.RemoveCard.OnServerEvent:Connect(function(player, cardId)
        local deck = playerDecks[player.UserId]
        if not deck or not deck.packId then return end

        for i = #deck.cards, 1, -1 do
            if deck.cards[i] == cardId then
                local testCards = {}
                for j, id in ipairs(deck.cards) do
                    if j ~= i then table.insert(testCards, id) end
                end

                local valid, reason = PackConfig.validateDeck(testCards)
                if not valid then
                    warn("[DeckService]", player.Name, "can't remove card —", reason)
                    return
                end

                table.remove(deck.cards, i)
                saveDeck(player)
                return
            end
        end
    end)

    -- ── Remote: GetDeck ─────────────────────────────────────
    remotes.GetDeck.OnServerInvoke = function(player)
        local deck = playerDecks[player.UserId]
        if not deck then return nil end
        return { packId = deck.packId, cards = table.clone(deck.cards) }
    end

    -- ── Remote: GetAllCards ─────────────────────────────────
    remotes.GetAllCards.OnServerInvoke = function(_player)
        return CardSystem.getAllCards()
    end

    -- ── Remote: GetAllPacks ─────────────────────────────────
    remotes.GetAllPacks.OnServerInvoke = function(_player)
        return PackConfig.getAllPacks()
    end

    print("[DeckService] Ready.")
end

-- ── Public helper for MatchService ─────────────────────────────
-- Returns a copy of the deck table for a player, or nil.
-- Called via the deckAdapter in init.server.luau.
function DeckService.getDeckForPlayer(player)
    local deck = playerDecks[player.UserId]
    if not deck then return nil end
    return { packId = deck.packId, cards = table.clone(deck.cards) }
end

return DeckService
