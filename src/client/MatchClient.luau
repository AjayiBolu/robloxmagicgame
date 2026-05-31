--[[
    MatchClient.luau
    Location: StarterPlayerScripts/Client/MatchClient

    CLIENT-SIDE MATCH HANDLER
    =========================
    Talks to MatchService on the server.
    Shows a matchmaking panel on the right side of the screen.

    ROBLOX REMOTE EVENT RULES (important):
      Client → Server  :  remoteEvent:FireServer(...)
      Server → Client  :  remoteEvent.OnClientEvent:Connect(callback)
      RemoteFunction   :  remoteFunction:InvokeServer(...)
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for MatchEvents folder created by the server
local MatchEvents = ReplicatedStorage:WaitForChild("MatchEvents", 15)
if not MatchEvents then
    error("MatchClient: MatchEvents folder not found. Is MatchService running?")
end

-- ── REMOTES ────────────────────────────────────────────────────
-- Client fires these TO the server
local JoinQueue       = MatchEvents:WaitForChild("JoinQueue")
local LeaveQueue      = MatchEvents:WaitForChild("LeaveQueue")
local PlayCard        = MatchEvents:WaitForChild("PlayCard")
local DeclareAttacker = MatchEvents:WaitForChild("DeclareAttacker")
local DeclareBlocker  = MatchEvents:WaitForChild("DeclareBlocker")
local EndPhase        = MatchEvents:WaitForChild("EndPhase")
local ForfeitMatch    = MatchEvents:WaitForChild("ForfeitMatch")

-- Server fires these TO the client  (must use .OnClientEvent:Connect)
local QueueStatus      = MatchEvents:WaitForChild("QueueStatus")
local MatchFound       = MatchEvents:WaitForChild("MatchFound")
local MatchStateUpdate = MatchEvents:WaitForChild("MatchStateUpdate")
local MatchOver        = MatchEvents:WaitForChild("MatchOver")
local ActionFailed     = MatchEvents:WaitForChild("ActionFailed")

local BattleUI = require(script.Parent.BattleUI)

-- ── LOCAL STATE ────────────────────────────────────────────────
local inMatch     = false
local inQueue     = false
local myPlayerKey = nil
local matchPanel  = nil

-- ── MATCHMAKING PANEL (right side of screen) ───────────────────
local function buildMatchPanel()
    if matchPanel then matchPanel:Destroy() end

    matchPanel = Instance.new("ScreenGui")
    matchPanel.Name           = "MatchPanel"
    matchPanel.ResetOnSpawn   = false
    matchPanel.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    matchPanel.Parent         = playerGui

    -- Panel frame — right side
    local panel = Instance.new("Frame")
    panel.Name             = "Panel"
    panel.AnchorPoint      = Vector2.new(1, 0.5)
    panel.Position         = UDim2.new(1, -12, 0.5, 0)
    panel.Size             = UDim2.new(0, 160, 0, 180)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    panel.BackgroundTransparency = 0.15
    panel.BorderSizePixel  = 0
    panel.Parent           = matchPanel

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color     = Color3.fromRGB(70, 70, 120)
    panelStroke.Thickness = 1.5
    panelStroke.Parent    = panel

    local layout = Instance.new("UIListLayout")
    layout.SortOrder           = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding             = UDim.new(0, 8)
    layout.Parent              = panel

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft   = UDim.new(0, 10)
    pad.PaddingRight  = UDim.new(0, 10)
    pad.Parent        = panel

    -- Title
    local title = Instance.new("TextLabel")
    title.Name             = "Title"
    title.Size             = UDim2.new(1, 0, 0, 22)
    title.BackgroundTransparency = 1
    title.Text             = "⚔  Battle"
    title.TextColor3       = Color3.fromRGB(255, 220, 100)
    title.Font             = Enum.Font.GothamBold
    title.TextSize         = 15
    title.LayoutOrder      = 1
    title.Parent           = panel

    -- Status label
    local status = Instance.new("TextLabel")
    status.Name             = "Status"
    status.Size             = UDim2.new(1, 0, 0, 32)
    status.BackgroundTransparency = 1
    status.Text             = "Ready to fight?"
    status.TextColor3       = Color3.fromRGB(160, 160, 190)
    status.Font             = Enum.Font.Gotham
    status.TextSize         = 11
    status.TextWrapped      = true
    status.TextXAlignment   = Enum.TextXAlignment.Center
    status.LayoutOrder      = 2
    status.Parent           = panel

    -- Find Match button
    local findBtn = Instance.new("TextButton")
    findBtn.Name             = "FindBtn"
    findBtn.Size             = UDim2.new(1, 0, 0, 36)
    findBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 80)
    findBtn.BorderSizePixel  = 0
    findBtn.Text             = "Find Match"
    findBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    findBtn.Font             = Enum.Font.GothamBold
    findBtn.TextSize         = 13
    findBtn.LayoutOrder      = 3
    findBtn.Parent           = panel

    local findCorner = Instance.new("UICorner")
    findCorner.CornerRadius = UDim.new(0, 8)
    findCorner.Parent = findBtn

    -- Cancel button (hidden until queuing)
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Name             = "CancelBtn"
    cancelBtn.Size             = UDim2.new(1, 0, 0, 30)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(140, 50, 50)
    cancelBtn.BorderSizePixel  = 0
    cancelBtn.Text             = "Cancel"
    cancelBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    cancelBtn.Font             = Enum.Font.GothamBold
    cancelBtn.TextSize         = 12
    cancelBtn.Visible          = false
    cancelBtn.LayoutOrder      = 4
    cancelBtn.Parent           = panel

    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 8)
    cancelCorner.Parent = cancelBtn

    -- Hover tween on Find Match button
    findBtn.MouseEnter:Connect(function()
        TweenService:Create(findBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(70, 170, 100)
        }):Play()
    end)
    findBtn.MouseLeave:Connect(function()
        TweenService:Create(findBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(50, 140, 80)
        }):Play()
    end)

    -- Find Match clicked
    findBtn.MouseButton1Click:Connect(function()
        if inQueue or inMatch then return end
        JoinQueue:FireServer()
        status.Text       = "Searching for\nopponent…"
        findBtn.Visible   = false
        cancelBtn.Visible = true
    end)

    -- Cancel clicked
    cancelBtn.MouseButton1Click:Connect(function()
        LeaveQueue:FireServer()
        status.Text       = "Ready to fight?"
        findBtn.Visible   = true
        cancelBtn.Visible = false
        inQueue           = false
    end)
end

-- ── PUBLIC API ─────────────────────────────────────────────────
local MatchClient = {}

function MatchClient.isInMatch() return inMatch end

function MatchClient.playCard(cardId)
    if not inMatch then return end
    PlayCard:FireServer(cardId)
end

function MatchClient.declareAttacker(instanceId)
    if not inMatch then return end
    DeclareAttacker:FireServer(instanceId)
end

function MatchClient.declareBlocker(blockerInstanceId, attackerInstanceId)
    if not inMatch then return end
    DeclareBlocker:FireServer(blockerInstanceId, attackerInstanceId)
end

function MatchClient.endPhase()
    if not inMatch then return end
    EndPhase:FireServer()
end

function MatchClient.forfeit()
    if not inMatch then return end
    ForfeitMatch:FireServer()
    inMatch = false
end

-- ── SERVER → CLIENT LISTENERS ──────────────────────────────────
-- NOTE: Server→Client RemoteEvents MUST use .OnClientEvent:Connect()
--       NOT :Connect() — that is only valid on BindableEvents.

QueueStatus.OnClientEvent:Connect(function(data)
    inQueue = data.inQueue
    local panel = matchPanel and matchPanel:FindFirstChild("Panel")
    if not panel then return end
    local status    = panel:FindFirstChild("Status")
    local findBtn   = panel:FindFirstChild("FindBtn")
    local cancelBtn = panel:FindFirstChild("CancelBtn")
    if data.inQueue then
        if status then status.Text = "Searching…\nPosition: " .. (data.position or "?") end
    else
        if status    then status.Text       = "Ready to fight?" end
        if findBtn   then findBtn.Visible   = true              end
        if cancelBtn then cancelBtn.Visible = false             end
    end
end)

MatchFound.OnClientEvent:Connect(function(data)
    inMatch     = true
    inQueue     = false
    myPlayerKey = data.playerKey

    -- Hide panel during battle
    if matchPanel then matchPanel.Enabled = false end

    print("[MatchClient] Match found! Opponent:", data.opponentName, "| I am:", myPlayerKey)
    BattleUI.open(MatchClient)
end)

MatchStateUpdate.OnClientEvent:Connect(function(snapshot)
    BattleUI.update(snapshot, MatchClient)
end)

MatchOver.OnClientEvent:Connect(function(winnerUserId)
    inMatch = false
    local won = winnerUserId == player.UserId
    BattleUI.showResult(won)

    -- Restore the match panel after result screen
    task.delay(0.5, function()
        if matchPanel then
            matchPanel.Enabled = true
            local panel     = matchPanel:FindFirstChild("Panel")
            local status    = panel and panel:FindFirstChild("Status")
            local findBtn   = panel and panel:FindFirstChild("FindBtn")
            local cancelBtn = panel and panel:FindFirstChild("CancelBtn")
            if status    then status.Text       = "Ready to fight?" end
            if findBtn   then findBtn.Visible   = true              end
            if cancelBtn then cancelBtn.Visible = false             end
        end
    end)
end)

ActionFailed.OnClientEvent:Connect(function(reason)
    BattleUI.showError(reason)
end)

-- ── STARTUP ────────────────────────────────────────────────────
task.wait(1)
print("[MatchClient] Building match panel...")
local ok, err = pcall(buildMatchPanel)
if not ok then
    warn("[MatchClient] buildMatchPanel failed:", err)
else
    print("[MatchClient] Match panel ready.")
end

return MatchClient
