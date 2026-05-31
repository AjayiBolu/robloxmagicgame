--[[
    DeckClient.luau
    Place in: src/client/DeckClient.luau

    CLIENT-SIDE DECK INTERFACE
    ==========================
    Talks to DeckService on the server to manage the player's deck.
    Drives the Pack Selection UI and Deck Manager UI.

    Keybind: Press M to open/close the Deck Manager at any time.
]]

local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local UserInputService     = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Wait for DeckEvents folder to be created by the server
local DeckEvents = ReplicatedStorage:WaitForChild("DeckEvents", 10)
if not DeckEvents then
    error("DeckClient: DeckEvents folder not found in ReplicatedStorage. Is DeckService running?")
end

-- Grab each remote
local SelectPack  = DeckEvents:WaitForChild("SelectPack")
local AddCard     = DeckEvents:WaitForChild("AddCard")
local RemoveCard  = DeckEvents:WaitForChild("RemoveCard")
local GetDeck     = DeckEvents:WaitForChild("GetDeck")
local GetAllCards = DeckEvents:WaitForChild("GetAllCards")
local GetAllPacks = DeckEvents:WaitForChild("GetAllPacks")

-- UI modules (sibling ModuleScripts)
local PackSelectionUI = require(script.Parent.PackSelectionUI)
local DeckManagerUI   = require(script.Parent.DeckManagerUI)

-- ============================================================
--  LOCAL STATE
-- ============================================================
local myDeck   = nil   -- { packId = string, cards = {string,...} }
local allCards = nil
local allPacks = nil

-- ============================================================
--  DATA FETCHING
-- ============================================================
local function refreshData()
    myDeck   = GetDeck:InvokeServer()
    allCards = GetAllCards:InvokeServer()
    allPacks = GetAllPacks:InvokeServer()
end

-- ============================================================
--  PUBLIC API
-- ============================================================
local DeckClient = {}

function DeckClient.hasPack()
    return myDeck ~= nil and myDeck.packId ~= nil
end

function DeckClient.getMyDeck()
    return myDeck
end

function DeckClient.getAllCards()
    return allCards
end

function DeckClient.getAllPacks()
    return allPacks
end

function DeckClient.selectPack(packId)
    if DeckClient.hasPack() then return false end
    if not allPacks or not allPacks[packId] then return false end

    SelectPack:FireServer(packId)

    local pack = allPacks[packId]
    myDeck = { packId = packId, cards = {} }
    for _, cardId in ipairs(pack.starterDeck) do
        table.insert(myDeck.cards, cardId)
    end

    print("DeckClient: Selected pack — " .. pack.name)
    return true
end

function DeckClient.addCard(cardId)
    if not DeckClient.hasPack() then return false end
    if not allCards or not allCards[cardId] then return false end

    AddCard:FireServer(cardId)
    table.insert(myDeck.cards, cardId)
    return true
end

function DeckClient.removeCard(cardId)
    if not DeckClient.hasPack() then return false end

    local cards = myDeck.cards
    for i = #cards, 1, -1 do
        if cards[i] == cardId then
            RemoveCard:FireServer(cardId)
            table.remove(cards, i)
            return true
        end
    end
    return false
end

-- ============================================================
--  DECK MANAGER TOGGLE (M key)
-- ============================================================
local function openDeckManager()
    if not DeckClient.hasPack() then return end
    DeckManagerUI.open(myDeck, allCards,
        function(cardId) DeckClient.addCard(cardId) end,
        function(cardId) DeckClient.removeCard(cardId) end
    )
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.M then
        openDeckManager()
    end
end)

-- ============================================================
--  STARTUP
-- ============================================================
local function init()
    task.wait(1)
    refreshData()

    if DeckClient.hasPack() then
        -- Returning player — show a small hint
        print("DeckClient: Welcome back! Press M to open your deck.")

        -- Show a brief on-screen hint
        local playerGui = player:WaitForChild("PlayerGui")
        local hint = Instance.new("ScreenGui")
        hint.Name         = "DeckHint"
        hint.ResetOnSpawn = false
        hint.Parent       = playerGui

        local label = Instance.new("TextLabel")
        label.AnchorPoint      = Vector2.new(0.5, 1)
        label.Position         = UDim2.new(0.5, 0, 1, -24)
        label.Size             = UDim2.new(0, 280, 0, 32)
        label.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
        label.BackgroundTransparency = 0.2
        label.BorderSizePixel  = 0
        label.Text             = "Press  M  to open your Deck Manager"
        label.TextColor3       = Color3.fromRGB(200, 200, 220)
        label.Font             = Enum.Font.Gotham
        label.TextSize         = 13
        label.Parent           = hint

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = label

        -- Fade out after 4 seconds
        task.delay(3.5, function()
            for i = 0, 10 do
                label.BackgroundTransparency = 0.2 + (i / 10) * 0.8
                label.TextTransparency       = i / 10
                task.wait(0.05)
            end
            hint:Destroy()
        end)

    else
        -- New player — open pack selection
        print("DeckClient: New player — opening pack selection screen.")

        local packOrder = { "starter", "onepiece", "bleach", "naruto", "dbz" }
        PackSelectionUI.open(allPacks, packOrder, function(packId)
            DeckClient.selectPack(packId)
            -- Refresh data so the deck manager has the starter cards
            task.delay(0.5, function()
                refreshData()
                print("DeckClient: Pack selected. Press M to view your deck.")
            end)
        end)
    end
end

init()

return DeckClient
