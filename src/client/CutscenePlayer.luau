--[[
    CutscenePlayer.luau
    Location: StarterPlayerScripts/Client/CutscenePlayer

    CLIENT-SIDE CUTSCENE PLAYBACK
    =============================
    Owns everything about cinematic cutscenes on the local client:
      • receives a TriggerCutscene cue (relayed by MatchClient),
      • decides — from THIS player's local settings — whether to play it,
      • plays the cinematic over the board, and
      • lets the player Skip at any time (local only, never the server).

    DESIGN PRINCIPLES (from the PRD)
    --------------------------------
      • Cutscenes are purely COSMETIC. The match state always advances
        underneath; skipping or watching never delays the game.
      • Cutscenes are GLOBAL (both players are told) but experienced and
        controlled INDEPENDENTLY — Skip dismisses it for this player only.
      • Settings are LOCAL (module-level table for now; DataStore later).
      • Adding a new cutscene type = a new `cutsceneType` string + a handler
        branch in `buildContent()`. No server change required.

    PAYLOAD SHAPE
    -------------
        { cardId?, cutsceneType = "cardPlay"|"cardIntro"|"win"|"loss", actorKey? }

    USAGE (from MatchClient)
    ------------------------
        local CutscenePlayer = require(script.Parent.CutscenePlayer)
        CutscenePlayer.handle(payload)        -- on TriggerCutscene
        CutscenePlayer.reset()                -- on match end/close
        CutscenePlayer.getSettings()          -- for the settings panel
        CutscenePlayer.setEnabled(bool)
        CutscenePlayer.setFrequency("all"|"rare"|"legendary")
]]

local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CardSystem is shared and read-only; used to read rarity / subtypes so we
-- can gate by frequency and detect "intro-worthy" cards.
local CardSystem do
    local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
    CardSystem = Shared and require(Shared:WaitForChild("CardSystem", 10)) or nil
end

local CutscenePlayer = {}

-- ── LOCAL SETTINGS (module-level; wired to DataStore in a later pass) ──
local settings = {
    enabled   = true,
    frequency = "all",   -- "all" | "rare" | "legendary"
}

-- ── ACTIVE PLAYBACK STATE ──────────────────────────────────────
local overlayGui    = nil   -- the ScreenGui holding the active cutscene
local activeTweens  = {}    -- tweens to cancel on skip
local playToken     = 0     -- generation counter; stale callbacks no-op
local seenIntros    = {}    -- [cardId] = true  → intro already shown once

-- ── THEME ──────────────────────────────────────────────────────
local C = {
    backdrop  = Color3.fromRGB(0, 0, 0),
    gold      = Color3.fromRGB(255, 210, 90),
    red       = Color3.fromRGB(235, 70, 70),
    textHi    = Color3.fromRGB(245, 245, 255),
    textSub   = Color3.fromRGB(170, 175, 200),
    skipBg    = Color3.fromRGB(40, 42, 60),
    skipHover = Color3.fromRGB(70, 74, 100),
    panel     = Color3.fromRGB(18, 20, 34),
}

-- ── RARITY HELPERS ──────────────────────────────────────────────
-- Rarities (from CardSystem): "Common" | "Uncommon" | "Rare" | "Mythic Rare".
-- We map the PRD's frequency tiers onto these:
--   "rare"      → Rare or Mythic Rare
--   "legendary" → Mythic Rare, or any card with the "Legendary" subtype
local RANK = { Common = 1, Uncommon = 2, Rare = 3, ["Mythic Rare"] = 4 }

local function cardData(cardId)
    return CardSystem and cardId and CardSystem.getCard(cardId) or nil
end

local function isLegendary(card)
    if not card then return false end
    if card.rarity == "Mythic Rare" then return true end
    for _, sub in ipairs(card.subTypes or {}) do
        if sub == "Legendary" then return true end
    end
    return false
end

-- Does this card warrant an intro cinematic (anime character summon)?
local function hasIntro(card)
    return isLegendary(card)
end

-- ── DECISION: should THIS cue play given local settings? ────────
function CutscenePlayer.shouldPlay(payload)
    if not settings.enabled then return false end
    if type(payload) ~= "table" then return false end

    local t = payload.cutsceneType

    -- Win/loss cinematics ignore the frequency tier — only the master toggle.
    if t == "win" or t == "loss" then
        return true
    end

    -- Card cutscenes are gated by frequency.
    local card = cardData(payload.cardId)
    if settings.frequency == "all" then
        return true
    elseif settings.frequency == "rare" then
        return card ~= nil and (RANK[card.rarity] or 1) >= RANK.Rare
    elseif settings.frequency == "legendary" then
        return isLegendary(card)
    end
    return false
end

-- ── TWEEN BOOKKEEPING ───────────────────────────────────────────
local function track(tween)
    table.insert(activeTweens, tween)
    tween:Play()
    return tween
end

local function cancelTweens()
    for _, tw in ipairs(activeTweens) do
        pcall(function() tw:Cancel() end)
    end
    table.clear(activeTweens)
end

-- ── LOW-LEVEL UI HELPERS ────────────────────────────────────────
local function mkCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 8)
    c.Parent = parent
end

local function mkStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color
    s.Thickness = thickness or 1.5
    s.Parent    = parent
end

-- Build the per-type cutscene content inside `parent` (the backdrop).
-- Returns nothing — purely visual. ZIndex sits above the backdrop but below
-- the Skip button. Card intros use a ViewportFrame stub (full 3D rigs are a
-- follow-up once character models exist).
local function buildContent(parent, payload)
    local t    = payload.cutsceneType
    local card = cardData(payload.cardId)

    local stage = Instance.new("Frame")
    stage.Name                   = "Stage"
    stage.AnchorPoint            = Vector2.new(0.5, 0.5)
    stage.Position               = UDim2.new(0.5, 0, 0.5, 0)
    stage.Size                   = UDim2.new(0, 460, 0, 280)
    stage.BackgroundTransparency = 1
    stage.ZIndex                 = 12
    stage.Parent                 = parent

    if t == "win" or t == "loss" then
        local won = (t == "win")
        local title = Instance.new("TextLabel")
        title.AnchorPoint            = Vector2.new(0.5, 0.5)
        title.Position               = UDim2.new(0.5, 0, 0.42, 0)
        title.Size                   = UDim2.new(1, 0, 0, 90)
        title.BackgroundTransparency = 1
        title.Text                   = won and "VICTORY" or "DEFEAT"
        title.TextColor3             = won and C.gold or C.red
        title.Font                   = Enum.Font.GothamBlack
        title.TextScaled             = false
        title.TextSize               = 72
        title.ZIndex                 = 13
        title.Parent                 = stage

        local sub = Instance.new("TextLabel")
        sub.AnchorPoint            = Vector2.new(0.5, 0.5)
        sub.Position               = UDim2.new(0.5, 0, 0.66, 0)
        sub.Size                   = UDim2.new(1, 0, 0, 30)
        sub.BackgroundTransparency = 1
        sub.Text                   = won and "The battlefield is yours." or "Your light fades…"
        sub.TextColor3             = C.textSub
        sub.Font                   = Enum.Font.GothamMedium
        sub.TextSize               = 20
        sub.ZIndex                 = 13
        sub.Parent                 = stage

    elseif t == "cardIntro" then
        -- ── ViewportFrame stub for the anime summon ──────────────
        -- Full 3D character rigs are a follow-up; for now we frame a
        -- placeholder viewport with the card's name as the "summon".
        local vp = Instance.new("ViewportFrame")
        vp.AnchorPoint            = Vector2.new(0.5, 0.5)
        vp.Position               = UDim2.new(0.5, 0, 0.42, 0)
        vp.Size                   = UDim2.new(0, 220, 0, 220)
        vp.BackgroundColor3       = C.panel
        vp.BackgroundTransparency = 0.1
        vp.ZIndex                 = 13
        vp.Parent                 = stage
        mkCorner(vp, UDim.new(0, 14))
        mkStroke(vp, C.gold, 2)

        local placeholder = Instance.new("TextLabel")
        placeholder.Size                   = UDim2.new(1, 0, 1, 0)
        placeholder.BackgroundTransparency = 1
        placeholder.Text                   = "✦"
        placeholder.TextColor3             = C.gold
        placeholder.Font                   = Enum.Font.GothamBlack
        placeholder.TextSize               = 64
        placeholder.ZIndex                 = 14
        placeholder.Parent                 = vp

        local name = Instance.new("TextLabel")
        name.AnchorPoint            = Vector2.new(0.5, 0.5)
        name.Position               = UDim2.new(0.5, 0, 0.84, 0)
        name.Size                   = UDim2.new(1, 0, 0, 32)
        name.BackgroundTransparency = 1
        name.Text                   = card and card.name or "Summon"
        name.TextColor3             = C.gold
        name.Font                   = Enum.Font.GothamBold
        name.TextSize               = 24
        name.TextWrapped            = true
        name.ZIndex                 = 13
        name.Parent                 = stage

    else
        -- "cardPlay" (default) — a quick name flourish.
        local elemName = card and card.name or (payload.actorKey or "A card")
        local banner = Instance.new("TextLabel")
        banner.AnchorPoint            = Vector2.new(0.5, 0.5)
        banner.Position               = UDim2.new(0.5, 0, 0.45, 0)
        banner.Size                   = UDim2.new(1, 0, 0, 60)
        banner.BackgroundTransparency = 1
        banner.Text                   = elemName
        banner.TextColor3             = C.textHi
        banner.Font                   = Enum.Font.GothamBlack
        banner.TextSize               = 44
        banner.TextWrapped            = true
        banner.ZIndex                 = 13
        banner.Parent                 = stage

        local tag = Instance.new("TextLabel")
        tag.AnchorPoint            = Vector2.new(0.5, 0.5)
        tag.Position               = UDim2.new(0.5, 0, 0.68, 0)
        tag.Size                   = UDim2.new(1, 0, 0, 26)
        tag.BackgroundTransparency = 1
        tag.Text                   = "ENTERS THE FIELD"
        tag.TextColor3             = C.textSub
        tag.Font                   = Enum.Font.GothamMedium
        tag.TextSize               = 16
        tag.ZIndex                 = 13
        tag.Parent                 = stage
    end
end

-- How long the cutscene holds before auto-finishing (seconds).
local function holdDuration(t)
    if t == "win" or t == "loss" then return 3.0 end
    if t == "cardIntro" then return 2.4 end
    return 1.3
end

-- ── TEARDOWN (shared by skip + auto-finish) ─────────────────────
local function teardown(myToken, fast)
    if myToken ~= playToken then return end          -- superseded; ignore
    if not overlayGui then return end

    cancelTweens()
    local backdrop = overlayGui:FindFirstChild("Backdrop")
    local gui      = overlayGui
    overlayGui     = nil                              -- mark inactive immediately

    if backdrop then
        local fade = TweenService:Create(
            backdrop,
            TweenInfo.new(fast and 0.12 or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        )
        fade:Play()
        fade.Completed:Connect(function()
            if gui and gui.Parent then gui:Destroy() end
        end)
        -- Safety: destroy even if Completed never fires.
        task.delay((fast and 0.12 or 0.3) + 0.1, function()
            if gui and gui.Parent then gui:Destroy() end
        end)
    else
        gui:Destroy()
    end
end

-- ── PUBLIC: play immediately (assumes shouldPlay already passed) ──
local function startPlayback(payload)
    -- Supersede any currently-playing cutscene (e.g. win cinematic over a
    -- lingering card flourish). Skip is local-only; this is too.
    if overlayGui then
        teardown(playToken, true)
    end

    playToken += 1
    local myToken = playToken

    local gui = Instance.new("ScreenGui")
    gui.Name            = "CutsceneOverlay"
    gui.ResetOnSpawn    = false
    gui.IgnoreGuiInset  = true
    gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder    = 50          -- above the battle board (DisplayOrder 5)
    gui.Parent          = playerGui
    overlayGui          = gui

    -- Black backdrop — fades the board to black (alpha tween).
    local backdrop = Instance.new("Frame")
    backdrop.Name                   = "Backdrop"
    backdrop.Size                   = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3       = C.backdrop
    backdrop.BackgroundTransparency = 1     -- starts clear, tweens to opaque
    backdrop.BorderSizePixel        = 0
    backdrop.ZIndex                 = 10
    backdrop.Parent                 = gui

    buildContent(backdrop, payload)

    -- Skip button — ALWAYS visible during playback, above everything.
    local skipBtn = Instance.new("TextButton")
    skipBtn.Name              = "SkipButton"
    skipBtn.AnchorPoint       = Vector2.new(1, 1)
    skipBtn.Position          = UDim2.new(1, -24, 1, -24)
    skipBtn.Size              = UDim2.new(0, 130, 0, 40)
    skipBtn.BackgroundColor3  = C.skipBg
    skipBtn.BorderSizePixel   = 0
    skipBtn.Text              = "Skip  ⏭"
    skipBtn.TextColor3        = C.textHi
    skipBtn.Font              = Enum.Font.GothamBold
    skipBtn.TextSize          = 16
    skipBtn.AutoButtonColor   = false
    skipBtn.ZIndex            = 100
    skipBtn.Parent            = gui
    mkCorner(skipBtn, UDim.new(0, 8))
    mkStroke(skipBtn, Color3.fromRGB(90, 94, 130), 1)

    skipBtn.MouseEnter:Connect(function()
        TweenService:Create(skipBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.skipHover }):Play()
    end)
    skipBtn.MouseLeave:Connect(function()
        TweenService:Create(skipBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.skipBg }):Play()
    end)
    skipBtn.MouseButton1Click:Connect(function()
        CutscenePlayer.skip()
    end)

    -- Fade in to black, hold, then auto fade back to the board.
    track(TweenService:Create(
        backdrop,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0 }
    ))

    task.delay(0.3 + holdDuration(payload.cutsceneType), function()
        teardown(myToken, false)
    end)
end

-- ── PUBLIC: handle an incoming cue ──────────────────────────────
function CutscenePlayer.handle(payload)
    if type(payload) ~= "table" then return end

    -- Upgrade a generic cardPlay into a one-time cardIntro for intro-worthy
    -- cards the player hasn't seen yet this session. We only "consume" the
    -- first-time flag once the intro actually plays (below), so a disabled
    -- setting doesn't silently burn it.
    local isFirstIntro = false
    if payload.cutsceneType == "cardPlay" and payload.cardId then
        local card = cardData(payload.cardId)
        if hasIntro(card) and not seenIntros[payload.cardId] then
            payload = {
                cardId       = payload.cardId,
                actorKey     = payload.actorKey,
                cutsceneType = "cardIntro",
            }
            isFirstIntro = true
        end
    end

    if not CutscenePlayer.shouldPlay(payload) then
        return  -- silently dropped per local settings
    end

    if isFirstIntro then
        seenIntros[payload.cardId] = true
    end

    startPlayback(payload)
end

-- ── PUBLIC: skip the active cutscene (local only) ───────────────
function CutscenePlayer.skip()
    teardown(playToken, true)
end

-- ── PUBLIC: is a cutscene on screen right now? ──────────────────
function CutscenePlayer.isPlaying()
    return overlayGui ~= nil
end

-- ── PUBLIC: reset (called on match end / board close) ───────────
function CutscenePlayer.reset()
    teardown(playToken, true)
    table.clear(seenIntros)
end

-- ── PUBLIC: settings access (for the settings panel) ────────────
function CutscenePlayer.getSettings()
    return { enabled = settings.enabled, frequency = settings.frequency }
end

function CutscenePlayer.setEnabled(value)
    settings.enabled = value and true or false
    if not settings.enabled then
        CutscenePlayer.skip()   -- dismiss anything currently on screen
    end
end

function CutscenePlayer.setFrequency(freq)
    if freq == "all" or freq == "rare" or freq == "legendary" then
        settings.frequency = freq
    end
end

return CutscenePlayer
