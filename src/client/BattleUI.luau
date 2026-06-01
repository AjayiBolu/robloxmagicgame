--[[
    BattleUI.luau
    Location: StarterPlayerScripts/Client/BattleUI

    MTG ARENA-INSPIRED, FULLY-OPAQUE BATTLE BOARD
    =============================================
    The root frame is OPAQUE and covers the whole screen — the Roblox 3D
    world is completely hidden during a match (no camera work needed).

    The board is split at the vertical midpoint:
        • top half    → the opponent (renders THEIR board skin)
        • bottom half → the local player (renders MY board skin)

    Each half carries its own cosmetic skin (BoardSkinRegistry). Life totals
    sit as circles straddling the centre divider; the hand fans up from the
    bottom edge. Deck + graveyard piles stack on the right of each half.

    Layout (top → bottom)
    ┌───────────────────────────────────────────────────────────┐
    │ ⚙        [ Phase Banner ]              [Forfeit] opp name  │
    │  ── OPPONENT HALF (top 50%) ──────────────┬ Opp Deck       │
    │  │ Opp Battlefield                        │ Opp Graveyard  │
    │ ─[Opp Life]──────── centre divider ───────[My Life|Mana]── │
    │  │ My Battlefield      [End Phase]        │ My Deck        │
    │  ── MY HALF (bottom 50%) ─────────────────┴ My Graveyard   │
    │  my name                                                   │
    │  ───────────────── FAN HAND ──────────────────────────────│
    └───────────────────────────────────────────────────────────┘

    Called by MatchClient — never talks to the server directly.
]]

local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Shared + sibling client modules
local BoardSkinRegistry do
    local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
    BoardSkinRegistry = require(Shared:WaitForChild("BoardSkinRegistry", 10))
end
local CutscenePlayer = require(script.Parent.CutscenePlayer)

-- ── THEME ──────────────────────────────────────────────────────
local T = {
    rootBg        = Color3.fromRGB(6, 7, 12),

    gold          = Color3.fromRGB(255, 210, 80),
    goldDim       = Color3.fromRGB(165, 125, 45),
    red           = Color3.fromRGB(225, 70, 70),
    redDim        = Color3.fromRGB(150, 45, 45),
    blue          = Color3.fromRGB(70, 140, 255),
    mana          = Color3.fromRGB(90, 160, 255),
    life          = Color3.fromRGB(80, 220, 115),
    danger        = Color3.fromRGB(235, 60, 60),

    textBright    = Color3.fromRGB(238, 240, 252),
    textSub       = Color3.fromRGB(150, 156, 188),
    textDim       = Color3.fromRGB(95, 100, 135),

    cardBg        = Color3.fromRGB(22, 24, 44),
    cardHover     = Color3.fromRGB(34, 38, 66),
    cardBorder    = Color3.fromRGB(52, 58, 98),
    cardBack      = Color3.fromRGB(26, 30, 58),

    btnGreen      = Color3.fromRGB(52, 160, 84),
    btnGreenHover = Color3.fromRGB(68, 190, 104),
    btnRed        = Color3.fromRGB(160, 45, 45),
    btnRedHover   = Color3.fromRGB(196, 60, 60),
    btnAttack     = Color3.fromRGB(198, 68, 22),
    btnAttackHvr  = Color3.fromRGB(224, 88, 38),
    btnNeutral    = Color3.fromRGB(48, 54, 92),
    btnBlue       = Color3.fromRGB(48, 104, 204),

    atkHighlight  = Color3.fromRGB(224, 78, 28),

    sm   = UDim.new(0, 6),
    md   = UDim.new(0, 10),
    lg   = UDim.new(0, 16),
    full = UDim.new(0.5, 0),
}

local ELEMENT_COLORS = {
    Fire    = Color3.fromRGB(225, 70, 20),
    Water   = Color3.fromRGB(30, 120, 225),
    Earth   = Color3.fromRGB(125, 80, 30),
    Air     = Color3.fromRGB(145, 200, 255),
    Dark    = Color3.fromRGB(125, 40, 210),
    Light   = Color3.fromRGB(255, 225, 65),
    Neutral = Color3.fromRGB(130, 130, 155),
}

-- ── LOW-LEVEL HELPERS ──────────────────────────────────────────
local function mkCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or T.md
    c.Parent = parent
    return c
end

local function mkStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color        = color or T.cardBorder
    s.Thickness    = thickness or 1.5
    s.Transparency = transparency or 0
    s.Parent       = parent
    return s
end

local function onHover(obj, normalColor, hoverColor)
    obj.MouseEnter:Connect(function()
        TweenService:Create(obj, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
    end)
    obj.MouseLeave:Connect(function()
        TweenService:Create(obj, TweenInfo.new(0.12), { BackgroundColor3 = normalColor }):Play()
    end)
end

local function mkButton(parent, text, bg, size, pos, cornerR)
    local b = Instance.new("TextButton")
    b.Size             = size
    b.Position         = pos or UDim2.new(0, 0, 0, 0)
    b.BackgroundColor3 = bg
    b.BorderSizePixel  = 0
    b.Text             = text
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 13
    b.AutoButtonColor  = false
    b.Parent           = parent
    mkCorner(b, cornerR or T.sm)
    return b
end

-- ── MODULE ─────────────────────────────────────────────────────
local BattleUI = {}

-- Live references (rebuilt each open)
local screenGui    = nil
local root         = nil
local myHalf       = nil
local oppHalf      = nil
local myFieldFrame = nil
local oppFieldFrame= nil
local handLayer    = nil
local myLifeLabel  = nil
local oppLifeLabel = nil
local myManaLabel  = nil
local phaseBanner  = nil
local turnLabel    = nil
local phaseLabel   = nil
local endPhaseBtn  = nil
local myNameLabel  = nil
local oppNameLabel = nil
local myEmptyHint  = nil
local oppEmptyHint = nil
local myDeckLabel  = nil
local oppDeckLabel = nil
local myGyCount    = nil
local oppGyCount   = nil
local myGyTop      = nil
local oppGyTop     = nil

-- Cosmetic / settings state (client-local, never sent to server)
local mySkinId          = BoardSkinRegistry.DEFAULT_SKIN_ID
local oppSkinId         = BoardSkinRegistry.DEFAULT_SKIN_ID
local showOpponentSkin  = true

-- Last snapshot graveyards (for the inspection modal)
local lastMyGraveyard  = {}
local lastOppGraveyard = {}

-- Stubs — matchmaking panel is owned by MatchClient
function BattleUI.showFindMatchButton(_) end
function BattleUI.showQueueStatus(_)    end
function BattleUI.hideQueueStatus()     end

-- ── CARD-NAME LOOKUP (lazy require of CardSystem) ───────────────
local _cardSystem = nil
local function cardSystem()
    if _cardSystem == nil then
        local Shared = ReplicatedStorage:WaitForChild("Shared", 5)
        _cardSystem  = Shared and require(Shared:WaitForChild("CardSystem", 5)) or false
    end
    return _cardSystem or nil
end

local function cardName(cardId)
    local cs   = cardSystem()
    local data = cs and cs.getCard(cardId)
    return data and data.name or cardId
end

-- ════════════════════════════════════════════════════════════════
--  BOARD SKIN BACKGROUND
-- ════════════════════════════════════════════════════════════════
-- Paints one half of the board with a skin: background fill, depth gradient,
-- a faint pattern, and a glow border. Patterns are decorative only and fall
-- back to plain when unknown.
local function applyPattern(half, skin)
    -- clear any prior decoration
    local existing = half:FindFirstChild("Pattern")
    if existing then existing:Destroy() end

    local pat = Instance.new("Frame")
    pat.Name                   = "Pattern"
    pat.Size                   = UDim2.new(1, 0, 1, 0)
    pat.BackgroundTransparency = 1
    pat.ZIndex                 = 0
    pat.Parent                 = half

    local id = skin.patternId or "none"
    if id == "grid" then
        for i = 1, 5 do
            local line = Instance.new("Frame")
            line.Size                   = UDim2.new(1, 0, 0, 1)
            line.Position               = UDim2.new(0, 0, i / 6, 0)
            line.BackgroundColor3       = skin.accentColor
            line.BackgroundTransparency = 0.9
            line.BorderSizePixel        = 0
            line.ZIndex                 = 0
            line.Parent                 = pat
        end
    elseif id == "diagonal" then
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, skin.bgColor),
            ColorSequenceKeypoint.new(0.5, skin.accentColor),
            ColorSequenceKeypoint.new(1, skin.bgColor),
        })
        grad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.88),
            NumberSequenceKeypoint.new(1, 1),
        })
        grad.Rotation = 35
        local fill = Instance.new("Frame")
        fill.Size             = UDim2.new(1, 0, 1, 0)
        fill.BackgroundColor3 = skin.accentColor
        fill.BorderSizePixel  = 0
        fill.ZIndex           = 0
        fill.Parent           = pat
        grad.Parent           = fill
    elseif id == "rune" then
        local rune = Instance.new("TextLabel")
        rune.AnchorPoint            = Vector2.new(0.5, 0.5)
        rune.Position               = UDim2.new(0.5, 0, 0.5, 0)
        rune.Size                   = UDim2.new(0, 240, 0, 240)
        rune.BackgroundTransparency = 1
        rune.Text                   = "◈"
        rune.TextColor3             = skin.accentColor
        rune.TextTransparency       = 0.9
        rune.Font                   = Enum.Font.GothamBlack
        rune.TextSize               = 200
        rune.ZIndex                 = 0
        rune.Parent                 = pat
    end
end

-- Re-paint a half frame in place from a skin id.
local function paintHalf(half, skinId, isOpp)
    local skin = BoardSkinRegistry.get(skinId)

    half.BackgroundColor3       = skin.bgColor
    half.BackgroundTransparency = 0

    -- depth gradient
    local grad = half:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
    grad.Color = ColorSequence.new(
        skin.bgColor,
        Color3.new(
            math.clamp(skin.bgColor.R * 0.6, 0, 1),
            math.clamp(skin.bgColor.G * 0.6, 0, 1),
            math.clamp(skin.bgColor.B * 0.6, 0, 1)
        )
    )
    grad.Rotation = isOpp and 90 or 270   -- darker toward the centre divider
    grad.Parent   = half

    -- glow border
    local stroke = half:FindFirstChildOfClass("UIStroke") or mkStroke(half, skin.glowColor, 2, 0.25)
    stroke.Color        = skin.glowColor
    stroke.Thickness    = 2
    stroke.Transparency = 0.25

    applyPattern(half, skin)

    -- store accent for the zone label
    local label = half:FindFirstChild("ZoneLabel")
    if label then label.TextColor3 = skin.accentColor end
end

-- ════════════════════════════════════════════════════════════════
--  ZONE BUILDERS
-- ════════════════════════════════════════════════════════════════
local function buildBattlefield(half, isOpp)
    local field = Instance.new("Frame")
    field.Name                   = isOpp and "OppField" or "MyField"
    -- battlefield occupies the left ~76% of the half, inset from edges
    field.Position               = UDim2.new(0, 14, 0, isOpp and 30 or 14)
    field.Size                   = UDim2.new(0.76, -14, 1, -44)
    field.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    field.BackgroundTransparency = 0.74
    field.BorderSizePixel        = 0
    field.Parent                 = half
    mkCorner(field, T.md)
    mkStroke(field, isOpp and T.redDim or T.blue, 1, 0.5)

    local layout = Instance.new("UIListLayout")
    layout.FillDirection       = Enum.FillDirection.Horizontal
    layout.VerticalAlignment   = Enum.VerticalAlignment.Center
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding             = UDim.new(0, 10)
    layout.SortOrder           = Enum.SortOrder.LayoutOrder
    layout.Parent              = field

    local hint = Instance.new("TextLabel")
    hint.Name                   = "EmptyHint"
    hint.Size                   = UDim2.new(1, 0, 1, 0)
    hint.BackgroundTransparency = 1
    hint.Text                   = isOpp and "No creatures in play" or "Play creatures to defend and attack"
    hint.TextColor3             = isOpp and Color3.fromRGB(120, 70, 70) or Color3.fromRGB(70, 90, 140)
    hint.Font                   = Enum.Font.GothamMedium
    hint.TextSize               = 13
    hint.Parent                 = field

    return field, hint
end

-- Deck pile: a stacked card-back look + remaining count.
local function buildDeckZone(half, isOpp)
    local zone = Instance.new("Frame")
    zone.Name                   = isOpp and "OppDeck" or "MyDeck"
    zone.AnchorPoint            = Vector2.new(1, 0)
    zone.Position               = UDim2.new(1, -14, 0, isOpp and 30 or 14)
    zone.Size                   = UDim2.new(0, 92, 0.5, -28)
    zone.BackgroundTransparency = 1
    zone.Parent                 = half

    -- stacked backs for depth
    for i = 2, 0, -1 do
        local back = Instance.new("Frame")
        back.AnchorPoint            = Vector2.new(0.5, 0)
        back.Position               = UDim2.new(0.5, i * 3, 0, i * 3)
        back.Size                   = UDim2.new(0, 64, 0, 86)
        back.BackgroundColor3       = T.cardBack
        back.BackgroundTransparency = 0
        back.BorderSizePixel        = 0
        back.ZIndex                 = 3 - i
        back.Parent                 = zone
        mkCorner(back, T.sm)
        mkStroke(back, T.cardBorder, 1)
        if i == 0 then
            local emblem = Instance.new("TextLabel")
            emblem.Size                   = UDim2.new(1, 0, 1, 0)
            emblem.BackgroundTransparency = 1
            emblem.Text                   = "✦"
            emblem.TextColor3             = T.goldDim
            emblem.Font                   = Enum.Font.GothamBlack
            emblem.TextSize               = 28
            emblem.ZIndex                 = 4
            emblem.Parent                 = back
        end
    end

    local label = Instance.new("TextLabel")
    label.AnchorPoint            = Vector2.new(0.5, 1)
    label.Position               = UDim2.new(0.5, 0, 1, 0)
    label.Size                   = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text                   = "Deck: 0"
    label.TextColor3             = T.textSub
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 12
    label.ZIndex                 = 5
    label.Parent                 = zone

    return label
end

-- Graveyard pile: top card + count, clickable to inspect.
local function buildGraveyardZone(half, isOpp, onClick)
    local zone = Instance.new("TextButton")
    zone.Name                   = isOpp and "OppGraveyard" or "MyGraveyard"
    zone.AnchorPoint            = Vector2.new(1, 1)
    zone.Position               = UDim2.new(1, -14, 1, isOpp and -8 or -14)
    zone.Size                   = UDim2.new(0, 92, 0.5, -28)
    zone.BackgroundTransparency = 1
    zone.Text                   = ""
    zone.AutoButtonColor        = false
    zone.Parent                 = half

    local slot = Instance.new("Frame")
    slot.AnchorPoint            = Vector2.new(0.5, 0)
    slot.Position               = UDim2.new(0.5, 0, 0, 0)
    slot.Size                   = UDim2.new(0, 64, 0, 86)
    slot.BackgroundColor3       = Color3.fromRGB(14, 14, 20)
    slot.BackgroundTransparency = 0.15
    slot.BorderSizePixel        = 0
    slot.Parent                 = zone
    mkCorner(slot, T.sm)
    mkStroke(slot, T.textDim, 1, 0.3)

    local topLbl = Instance.new("TextLabel")
    topLbl.Name                   = "TopCard"
    topLbl.Size                   = UDim2.new(1, -8, 1, -8)
    topLbl.Position               = UDim2.new(0, 4, 0, 4)
    topLbl.BackgroundTransparency = 1
    topLbl.Text                   = "empty"
    topLbl.TextColor3             = T.textDim
    topLbl.Font                   = Enum.Font.GothamMedium
    topLbl.TextSize               = 10
    topLbl.TextWrapped            = true
    topLbl.Parent                 = slot

    local label = Instance.new("TextLabel")
    label.AnchorPoint            = Vector2.new(0.5, 1)
    label.Position               = UDim2.new(0.5, 0, 1, 0)
    label.Size                   = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text                   = "Graveyard: 0"
    label.TextColor3             = T.textSub
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 12
    label.Parent                 = zone

    zone.MouseButton1Click:Connect(onClick)
    zone.MouseEnter:Connect(function()
        TweenService:Create(slot, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
    end)
    zone.MouseLeave:Connect(function()
        TweenService:Create(slot, TweenInfo.new(0.12), { BackgroundTransparency = 0.15 }):Play()
    end)

    return label, topLbl
end

-- ── LIFE CIRCLE ─────────────────────────────────────────────────
local function mkLifeCircle(parent, isOpp)
    local accent = isOpp and T.red or T.life
    local circle = Instance.new("Frame")
    circle.Size                   = UDim2.new(0, 64, 0, 64)
    circle.BackgroundColor3       = isOpp and Color3.fromRGB(34, 10, 12) or Color3.fromRGB(10, 30, 16)
    circle.BackgroundTransparency = 0
    circle.BorderSizePixel        = 0
    circle.ZIndex                 = 20
    circle.Parent                 = parent
    mkCorner(circle, T.full)
    mkStroke(circle, accent, 3)

    local num = Instance.new("TextLabel")
    num.Size                   = UDim2.new(1, 0, 1, 0)
    num.BackgroundTransparency = 1
    num.Text                   = "20"
    num.TextColor3             = accent
    num.Font                   = Enum.Font.GothamBlack
    num.TextSize               = 26
    num.ZIndex                 = 21
    num.Parent                 = circle

    return circle, num
end

-- ════════════════════════════════════════════════════════════════
--  GRAVEYARD INSPECTION MODAL
-- ════════════════════════════════════════════════════════════════
local function openGraveyardModal(title, cardIds)
    if not screenGui then return end
    local existing = screenGui:FindFirstChild("GraveyardModal")
    if existing then existing:Destroy() end

    local modal = Instance.new("Frame")
    modal.Name                   = "GraveyardModal"
    modal.Size                   = UDim2.new(1, 0, 1, 0)
    modal.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    modal.BackgroundTransparency = 0.45
    modal.BorderSizePixel        = 0
    modal.ZIndex                 = 40
    modal.Parent                 = screenGui

    local panel = Instance.new("Frame")
    panel.AnchorPoint            = Vector2.new(0.5, 0.5)
    panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
    panel.Size                   = UDim2.new(0, 360, 0, 420)
    panel.BackgroundColor3       = Color3.fromRGB(16, 18, 30)
    panel.BorderSizePixel        = 0
    panel.ZIndex                 = 41
    panel.Parent                 = modal
    mkCorner(panel, T.lg)
    mkStroke(panel, T.goldDim, 2)

    local header = Instance.new("TextLabel")
    header.Position               = UDim2.new(0, 16, 0, 12)
    header.Size                   = UDim2.new(1, -60, 0, 28)
    header.BackgroundTransparency = 1
    header.Text                   = title .. "  (" .. #cardIds .. ")"
    header.TextColor3             = T.gold
    header.Font                   = Enum.Font.GothamBold
    header.TextSize               = 18
    header.TextXAlignment         = Enum.TextXAlignment.Left
    header.ZIndex                 = 42
    header.Parent                 = panel

    local closeBtn = mkButton(panel, "✕", T.btnRed,
        UDim2.new(0, 32, 0, 32), UDim2.new(1, -44, 0, 10), T.sm)
    closeBtn.ZIndex = 42
    closeBtn.MouseButton1Click:Connect(function() modal:Destroy() end)
    onHover(closeBtn, T.btnRed, T.btnRedHover)

    local list = Instance.new("ScrollingFrame")
    list.Position               = UDim2.new(0, 12, 0, 52)
    list.Size                   = UDim2.new(1, -24, 1, -64)
    list.BackgroundColor3       = Color3.fromRGB(10, 11, 20)
    list.BackgroundTransparency = 0.3
    list.BorderSizePixel        = 0
    list.ScrollBarThickness     = 4
    list.ScrollBarImageColor3   = T.cardBorder
    list.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    list.CanvasSize             = UDim2.new(0, 0, 0, 0)
    list.ZIndex                 = 42
    list.Parent                 = panel
    mkCorner(list, T.sm)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop  = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight  = UDim.new(0, 6)
    pad.Parent = list

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding       = UDim.new(0, 4)
    listLayout.SortOrder     = Enum.SortOrder.LayoutOrder
    listLayout.Parent        = list

    if #cardIds == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size                   = UDim2.new(1, 0, 0, 40)
        empty.BackgroundTransparency = 1
        empty.Text                   = "Nothing here yet."
        empty.TextColor3             = T.textDim
        empty.Font                   = Enum.Font.GothamMedium
        empty.TextSize               = 14
        empty.ZIndex                 = 43
        empty.Parent                 = list
    else
        for i, cardId in ipairs(cardIds) do
            local entry = Instance.new("Frame")
            entry.Name                   = "Entry"
            entry.Size                   = UDim2.new(1, 0, 0, 34)
            entry.BackgroundColor3       = T.cardBg
            entry.BackgroundTransparency = 0.2
            entry.BorderSizePixel        = 0
            entry.LayoutOrder            = i
            entry.ZIndex                 = 43
            entry.Parent                 = list
            mkCorner(entry, T.sm)

            local lbl = Instance.new("TextLabel")
            lbl.Position               = UDim2.new(0, 10, 0, 0)
            lbl.Size                   = UDim2.new(1, -20, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text                   = cardName(cardId)
            lbl.TextColor3             = T.textBright
            lbl.Font                   = Enum.Font.GothamMedium
            lbl.TextSize               = 13
            lbl.TextXAlignment         = Enum.TextXAlignment.Left
            lbl.ZIndex                 = 44
            lbl.Parent                 = entry
        end
    end
end

-- ════════════════════════════════════════════════════════════════
--  SETTINGS PANEL  (cutscenes + opponent skin)
-- ════════════════════════════════════════════════════════════════
local function buildToggleRow(parent, y, labelText, initial, onChange)
    local row = Instance.new("Frame")
    row.Size                   = UDim2.new(1, -32, 0, 38)
    row.Position               = UDim2.new(0, 16, 0, y)
    row.BackgroundTransparency = 1
    row.Parent                 = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -64, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = labelText
    lbl.TextColor3             = T.textBright
    lbl.Font                   = Enum.Font.GothamMedium
    lbl.TextSize               = 14
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Parent                 = row

    local toggle = Instance.new("TextButton")
    toggle.AnchorPoint       = Vector2.new(1, 0.5)
    toggle.Position          = UDim2.new(1, 0, 0.5, 0)
    toggle.Size              = UDim2.new(0, 52, 0, 26)
    toggle.BorderSizePixel   = 0
    toggle.Text              = ""
    toggle.AutoButtonColor   = false
    toggle.Parent            = row
    mkCorner(toggle, UDim.new(0, 13))

    local knob = Instance.new("Frame")
    knob.Size              = UDim2.new(0, 20, 0, 20)
    knob.AnchorPoint       = Vector2.new(0, 0.5)
    knob.BackgroundColor3  = Color3.fromRGB(245, 245, 255)
    knob.BorderSizePixel   = 0
    knob.Parent            = toggle
    mkCorner(knob, T.full)

    local state = initial
    local function render()
        toggle.BackgroundColor3 = state and T.btnGreen or Color3.fromRGB(60, 64, 90)
        knob.Position = state and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    end
    render()

    toggle.MouseButton1Click:Connect(function()
        state = not state
        render()
        onChange(state)
    end)

    return row
end

local function openSettingsPanel()
    if not screenGui then return end
    local existing = screenGui:FindFirstChild("SettingsModal")
    if existing then existing:Destroy() end

    local cs = CutscenePlayer.getSettings()

    local modal = Instance.new("Frame")
    modal.Name                   = "SettingsModal"
    modal.Size                   = UDim2.new(1, 0, 1, 0)
    modal.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    modal.BackgroundTransparency = 0.45
    modal.BorderSizePixel        = 0
    modal.ZIndex                 = 40
    modal.Parent                 = screenGui

    local panel = Instance.new("Frame")
    panel.AnchorPoint      = Vector2.new(0.5, 0.5)
    panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
    panel.Size             = UDim2.new(0, 380, 0, 300)
    panel.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
    panel.BorderSizePixel  = 0
    panel.ZIndex           = 41
    panel.Parent           = modal
    mkCorner(panel, T.lg)
    mkStroke(panel, T.goldDim, 2)

    local header = Instance.new("TextLabel")
    header.Position               = UDim2.new(0, 16, 0, 12)
    header.Size                   = UDim2.new(1, -60, 0, 28)
    header.BackgroundTransparency = 1
    header.Text                   = "Settings"
    header.TextColor3             = T.gold
    header.Font                   = Enum.Font.GothamBold
    header.TextSize               = 18
    header.TextXAlignment         = Enum.TextXAlignment.Left
    header.ZIndex                 = 42
    header.Parent                 = panel

    local closeBtn = mkButton(panel, "✕", T.btnRed,
        UDim2.new(0, 32, 0, 32), UDim2.new(1, -44, 0, 10), T.sm)
    closeBtn.ZIndex = 42
    closeBtn.MouseButton1Click:Connect(function() modal:Destroy() end)
    onHover(closeBtn, T.btnRed, T.btnRedHover)

    -- Cutscenes enabled
    buildToggleRow(panel, 52, "Cutscenes", cs.enabled, function(v)
        CutscenePlayer.setEnabled(v)
    end)

    -- Show opponent board skin
    buildToggleRow(panel, 94, "Show opponent's board skin", showOpponentSkin, function(v)
        BattleUI.setShowOpponentSkin(v)
    end)

    -- Frequency selector
    local freqLbl = Instance.new("TextLabel")
    freqLbl.Position               = UDim2.new(0, 16, 0, 140)
    freqLbl.Size                   = UDim2.new(1, -32, 0, 22)
    freqLbl.BackgroundTransparency = 1
    freqLbl.Text                   = "Cutscene frequency"
    freqLbl.TextColor3             = T.textBright
    freqLbl.Font                   = Enum.Font.GothamMedium
    freqLbl.TextSize               = 14
    freqLbl.TextXAlignment         = Enum.TextXAlignment.Left
    freqLbl.ZIndex                 = 42
    freqLbl.Parent                 = panel

    local options = { { "all", "All" }, { "rare", "Rare+" }, { "legendary", "Legendary" } }
    local buttons = {}
    local function renderFreq(active)
        for _, b in ipairs(buttons) do
            b.BackgroundColor3 = (b.Name == active) and T.btnBlue or T.btnNeutral
        end
    end
    for i, opt in ipairs(options) do
        local b = mkButton(panel, opt[2], T.btnNeutral,
            UDim2.new(0, 110, 0, 36),
            UDim2.new(0, 16 + (i - 1) * 118, 0, 170),
            T.sm)
        b.Name   = opt[1]
        b.ZIndex = 42
        b.MouseButton1Click:Connect(function()
            CutscenePlayer.setFrequency(opt[1])
            renderFreq(opt[1])
        end)
        buttons[i] = b
    end
    renderFreq(cs.frequency)

    local note = Instance.new("TextLabel")
    note.Position               = UDim2.new(0, 16, 1, -54)
    note.Size                   = UDim2.new(1, -32, 0, 40)
    note.BackgroundTransparency = 1
    note.Text                   = "Cutscenes are cosmetic — the match never waits for them."
    note.TextColor3             = T.textDim
    note.Font                   = Enum.Font.Gotham
    note.TextSize               = 12
    note.TextWrapped            = true
    note.TextXAlignment         = Enum.TextXAlignment.Left
    note.ZIndex                 = 42
    note.Parent                 = panel
end

-- ════════════════════════════════════════════════════════════════
--  OPEN THE BOARD
-- ════════════════════════════════════════════════════════════════
function BattleUI.open(matchClient, opts)
    if screenGui then screenGui:Destroy() end
    opts = opts or {}

    mySkinId  = opts.playerSkinId   or BoardSkinRegistry.DEFAULT_SKIN_ID
    oppSkinId = opts.opponentSkinId or BoardSkinRegistry.DEFAULT_SKIN_ID

    screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "BattleScreen"
    screenGui.ResetOnSpawn   = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder   = 5
    screenGui.Parent         = playerGui

    -- ── OPAQUE ROOT — hides the 3D world entirely ───────────────
    root = Instance.new("Frame")
    root.Name                   = "Root"
    root.Size                   = UDim2.new(1, 0, 1, 0)
    root.BackgroundColor3       = T.rootBg
    root.BackgroundTransparency = 0
    root.BorderSizePixel        = 0
    root.Parent                 = screenGui

    -- ── OPPONENT HALF (top 50%) ─────────────────────────────────
    oppHalf = Instance.new("Frame")
    oppHalf.Name             = "OppHalf"
    oppHalf.Position         = UDim2.new(0, 0, 0, 0)
    oppHalf.Size             = UDim2.new(1, 0, 0.5, 0)
    oppHalf.BorderSizePixel  = 0
    oppHalf.ZIndex           = 1
    oppHalf.Parent           = root

    local oppZoneLabel = Instance.new("TextLabel")
    oppZoneLabel.Name                   = "ZoneLabel"
    oppZoneLabel.AnchorPoint            = Vector2.new(0, 0)
    oppZoneLabel.Position               = UDim2.new(0, 18, 0, 8)
    oppZoneLabel.Size                   = UDim2.new(0, 260, 0, 18)
    oppZoneLabel.BackgroundTransparency = 1
    oppZoneLabel.Text                   = "▼  OPPONENT'S BATTLEFIELD"
    oppZoneLabel.Font                   = Enum.Font.GothamBold
    oppZoneLabel.TextSize               = 11
    oppZoneLabel.TextXAlignment         = Enum.TextXAlignment.Left
    oppZoneLabel.ZIndex                 = 2
    oppZoneLabel.Parent                 = oppHalf

    -- ── MY HALF (bottom 50%) ────────────────────────────────────
    myHalf = Instance.new("Frame")
    myHalf.Name             = "MyHalf"
    myHalf.Position         = UDim2.new(0, 0, 0.5, 0)
    myHalf.Size             = UDim2.new(1, 0, 0.5, 0)
    myHalf.BorderSizePixel  = 0
    myHalf.ZIndex           = 1
    myHalf.Parent           = root

    local myZoneLabel = Instance.new("TextLabel")
    myZoneLabel.Name                   = "ZoneLabel"
    myZoneLabel.AnchorPoint            = Vector2.new(0, 1)
    myZoneLabel.Position               = UDim2.new(0, 18, 1, -8)
    myZoneLabel.Size                   = UDim2.new(0, 260, 0, 18)
    myZoneLabel.BackgroundTransparency = 1
    myZoneLabel.Text                   = "▲  YOUR BATTLEFIELD"
    myZoneLabel.Font                   = Enum.Font.GothamBold
    myZoneLabel.TextSize               = 11
    myZoneLabel.TextXAlignment         = Enum.TextXAlignment.Left
    myZoneLabel.ZIndex                 = 2
    myZoneLabel.Parent                 = myHalf

    -- Battlefields
    oppFieldFrame, oppEmptyHint = buildBattlefield(oppHalf, true)
    myFieldFrame,  myEmptyHint  = buildBattlefield(myHalf,  false)

    -- Deck + graveyard piles
    oppDeckLabel              = buildDeckZone(oppHalf, true)
    myDeckLabel               = buildDeckZone(myHalf,  false)
    oppGyCount, oppGyTop      = buildGraveyardZone(oppHalf, true,  function()
        openGraveyardModal("Opponent Graveyard", lastOppGraveyard)
    end)
    myGyCount, myGyTop        = buildGraveyardZone(myHalf, false, function()
        openGraveyardModal("Your Graveyard", lastMyGraveyard)
    end)

    -- Paint the skins (after zone labels exist so accent applies)
    paintHalf(oppHalf, showOpponentSkin and oppSkinId or BoardSkinRegistry.DEFAULT_SKIN_ID, true)
    paintHalf(myHalf, mySkinId, false)

    -- ── CENTRE DIVIDER ──────────────────────────────────────────
    local divider = Instance.new("Frame")
    divider.Name                   = "Divider"
    divider.AnchorPoint            = Vector2.new(0.5, 0.5)
    divider.Position               = UDim2.new(0.5, 0, 0.5, 0)
    divider.Size                   = UDim2.new(1, 0, 0, 2)
    divider.BackgroundColor3       = T.gold
    divider.BackgroundTransparency = 0.4
    divider.BorderSizePixel        = 0
    divider.ZIndex                 = 15
    divider.Parent                 = root

    -- ── LIFE CIRCLES (straddling the divider, left of centre) ───
    local oppCircle, oppNum = mkLifeCircle(root, true)
    oppCircle.AnchorPoint = Vector2.new(0.5, 1)
    oppCircle.Position    = UDim2.new(0.42, 0, 0.5, -6)   -- just above divider
    oppLifeLabel          = oppNum

    local myCircle, myNum = mkLifeCircle(root, false)
    myCircle.AnchorPoint = Vector2.new(0.5, 0)
    myCircle.Position    = UDim2.new(0.42, 0, 0.5, 6)     -- just below divider
    myLifeLabel          = myNum

    -- Mana, beside my life circle
    local manaBadge = Instance.new("Frame")
    manaBadge.AnchorPoint       = Vector2.new(0, 0)
    manaBadge.Position          = UDim2.new(0.42, 38, 0.5, 12)
    manaBadge.Size              = UDim2.new(0, 92, 0, 50)
    manaBadge.BackgroundColor3  = Color3.fromRGB(12, 20, 40)
    manaBadge.BorderSizePixel   = 0
    manaBadge.ZIndex            = 20
    manaBadge.Parent            = root
    mkCorner(manaBadge, T.sm)
    mkStroke(manaBadge, T.mana, 1.5)

    local manaTitle = Instance.new("TextLabel")
    manaTitle.Position               = UDim2.new(0, 8, 0, 5)
    manaTitle.Size                   = UDim2.new(1, -16, 0, 14)
    manaTitle.BackgroundTransparency = 1
    manaTitle.Text                   = "⚡ MANA"
    manaTitle.TextColor3             = T.mana
    manaTitle.Font                   = Enum.Font.GothamBold
    manaTitle.TextSize               = 10
    manaTitle.TextXAlignment         = Enum.TextXAlignment.Left
    manaTitle.ZIndex                 = 21
    manaTitle.Parent                 = manaBadge

    myManaLabel = Instance.new("TextLabel")
    myManaLabel.Position               = UDim2.new(0, 8, 0, 20)
    myManaLabel.Size                   = UDim2.new(1, -16, 0, 24)
    myManaLabel.BackgroundTransparency = 1
    myManaLabel.Text                   = "0 / 0"
    myManaLabel.TextColor3             = T.textBright
    myManaLabel.Font                   = Enum.Font.GothamBlack
    myManaLabel.TextSize               = 20
    myManaLabel.TextXAlignment         = Enum.TextXAlignment.Left
    myManaLabel.ZIndex                 = 21
    myManaLabel.Parent                 = manaBadge

    -- End Phase button (my side, near centre divider, right of centre)
    endPhaseBtn = mkButton(root, "End Phase  →", T.btnGreen,
        UDim2.new(0, 150, 0, 40),
        UDim2.new(0.62, 0, 0.5, 14),
        T.sm)
    endPhaseBtn.ZIndex = 20
    endPhaseBtn.MouseButton1Click:Connect(function()
        matchClient.endPhase()
    end)
    onHover(endPhaseBtn, T.btnGreen, T.btnGreenHover)

    -- ── PHASE BANNER (top centre) ───────────────────────────────
    phaseBanner = Instance.new("Frame")
    phaseBanner.Name             = "PhaseBanner"
    phaseBanner.AnchorPoint      = Vector2.new(0.5, 0)
    phaseBanner.Position         = UDim2.new(0.5, 0, 0, 10)
    phaseBanner.Size             = UDim2.new(0, 300, 0, 56)
    phaseBanner.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
    phaseBanner.BorderSizePixel  = 0
    phaseBanner.ZIndex           = 22
    phaseBanner.Parent           = root
    mkCorner(phaseBanner, T.md)
    mkStroke(phaseBanner, T.goldDim, 1.5)

    turnLabel = Instance.new("TextLabel")
    turnLabel.Size                   = UDim2.new(1, 0, 0, 28)
    turnLabel.Position               = UDim2.new(0, 0, 0, 6)
    turnLabel.BackgroundTransparency = 1
    turnLabel.Text                   = "Waiting for match…"
    turnLabel.TextColor3             = T.gold
    turnLabel.Font                   = Enum.Font.GothamBold
    turnLabel.TextSize               = 16
    turnLabel.ZIndex                 = 23
    turnLabel.Parent                 = phaseBanner

    phaseLabel = Instance.new("TextLabel")
    phaseLabel.Size                   = UDim2.new(1, 0, 0, 16)
    phaseLabel.Position               = UDim2.new(0, 0, 0, 34)
    phaseLabel.BackgroundTransparency = 1
    phaseLabel.Text                   = ""
    phaseLabel.TextColor3             = T.textSub
    phaseLabel.Font                   = Enum.Font.GothamMedium
    phaseLabel.TextSize               = 11
    phaseLabel.ZIndex                 = 23
    phaseLabel.Parent                 = phaseBanner

    -- ── FORFEIT (top-right) ─────────────────────────────────────
    local forfeitBtn = mkButton(root, "✕  Forfeit", T.btnRed,
        UDim2.new(0, 96, 0, 34),
        UDim2.new(1, -108, 0, 12),
        T.sm)
    forfeitBtn.ZIndex = 24
    forfeitBtn.MouseButton1Click:Connect(function()
        matchClient.forfeit()
        BattleUI.close()
    end)
    onHover(forfeitBtn, T.btnRed, T.btnRedHover)

    -- ── SETTINGS (top-left) ─────────────────────────────────────
    local settingsBtn = mkButton(root, "⚙", T.btnNeutral,
        UDim2.new(0, 40, 0, 34),
        UDim2.new(0, 12, 0, 12),
        T.sm)
    settingsBtn.TextSize = 18
    settingsBtn.ZIndex   = 24
    settingsBtn.MouseButton1Click:Connect(openSettingsPanel)
    onHover(settingsBtn, T.btnNeutral, T.cardHover)

    -- ── OPPONENT NAME (top-right, under forfeit) ────────────────
    oppNameLabel = Instance.new("TextLabel")
    oppNameLabel.AnchorPoint            = Vector2.new(1, 0)
    oppNameLabel.Position               = UDim2.new(1, -12, 0, 50)
    oppNameLabel.Size                   = UDim2.new(0, 220, 0, 20)
    oppNameLabel.BackgroundTransparency = 1
    oppNameLabel.Text                   = opts.opponentName or "Opponent"
    oppNameLabel.TextColor3             = T.textBright
    oppNameLabel.Font                   = Enum.Font.GothamBold
    oppNameLabel.TextSize               = 14
    oppNameLabel.TextXAlignment         = Enum.TextXAlignment.Right
    oppNameLabel.ZIndex                 = 24
    oppNameLabel.Parent                 = root

    -- ── MY NAME (bottom-left, above the hand) ───────────────────
    myNameLabel = Instance.new("TextLabel")
    myNameLabel.AnchorPoint            = Vector2.new(0, 1)
    myNameLabel.Position               = UDim2.new(0, 14, 1, -134)
    myNameLabel.Size                   = UDim2.new(0, 240, 0, 20)
    myNameLabel.BackgroundTransparency = 1
    myNameLabel.Text                   = opts.playerName or player.DisplayName
    myNameLabel.TextColor3             = T.textBright
    myNameLabel.Font                   = Enum.Font.GothamBold
    myNameLabel.TextSize               = 14
    myNameLabel.TextXAlignment         = Enum.TextXAlignment.Left
    myNameLabel.ZIndex                 = 24
    myNameLabel.Parent                 = root

    -- ── FAN HAND LAYER (bottom edge) ────────────────────────────
    handLayer = Instance.new("Frame")
    handLayer.Name                   = "HandLayer"
    handLayer.AnchorPoint            = Vector2.new(0.5, 1)
    handLayer.Position               = UDim2.new(0.5, 0, 1, 6)
    handLayer.Size                   = UDim2.new(1, 0, 0, 170)
    handLayer.BackgroundTransparency = 1
    handLayer.ZIndex                 = 30
    handLayer.Parent                 = root
end

-- ════════════════════════════════════════════════════════════════
--  HAND CARD  (fan)
-- ════════════════════════════════════════════════════════════════
local CARD_W, CARD_H = 96, 132

local function buildHandCard(cardId, cardData, playable, matchClient)
    local elem     = cardData and cardData.element  or "Neutral"
    local elemCol  = ELEMENT_COLORS[elem] or ELEMENT_COLORS.Neutral
    local nameStr  = cardData and cardData.name     or cardId
    local cardType = cardData and cardData.cardType or "?"
    local manaCost = cardData and cardData.manaCost or 0

    -- TextButton root so the whole card is clickable (no room for a button
    -- in a fanned hand).
    local card = Instance.new("TextButton")
    card.Name                   = "HC_" .. cardId
    card.Size                   = UDim2.new(0, CARD_W, 0, CARD_H)
    card.BackgroundColor3       = T.cardBg
    card.BackgroundTransparency = playable and 0 or 0.35
    card.BorderSizePixel        = 0
    card.AutoButtonColor        = false
    card.Text                   = ""
    card.AutoLocalize           = false
    mkCorner(card, T.sm)
    mkStroke(card, playable and elemCol or T.cardBorder, playable and 2 or 1,
        playable and 0 or 0.4)

    local dim = playable and 0 or 0.5   -- child transparency for unplayable

    -- element bar
    local elemBar = Instance.new("Frame")
    elemBar.Size                   = UDim2.new(1, 0, 0, 6)
    elemBar.BackgroundColor3       = elemCol
    elemBar.BackgroundTransparency = dim
    elemBar.BorderSizePixel        = 0
    mkCorner(elemBar, UDim.new(0, 6))
    elemBar.Parent                 = card

    -- mana cost circle
    local manaCirc = Instance.new("Frame")
    manaCirc.AnchorPoint            = Vector2.new(1, 0)
    manaCirc.Position               = UDim2.new(1, -5, 0, 5)
    manaCirc.Size                   = UDim2.new(0, 24, 0, 24)
    manaCirc.BackgroundColor3       = playable and T.mana or Color3.fromRGB(40, 46, 80)
    manaCirc.BackgroundTransparency = dim
    manaCirc.BorderSizePixel        = 0
    mkCorner(manaCirc, T.full)
    manaCirc.Parent                 = card

    local manaNum = Instance.new("TextLabel")
    manaNum.Size                   = UDim2.new(1, 0, 1, 0)
    manaNum.BackgroundTransparency = 1
    manaNum.Text                   = tostring(manaCost)
    manaNum.TextColor3             = Color3.fromRGB(255, 255, 255)
    manaNum.TextTransparency       = dim
    manaNum.Font                   = Enum.Font.GothamBold
    manaNum.TextSize               = 13
    manaNum.Parent                 = manaCirc

    -- name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Position               = UDim2.new(0, 5, 0, 9)
    nameLbl.Size                   = UDim2.new(1, -34, 0, 34)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = nameStr
    nameLbl.TextColor3             = T.textBright
    nameLbl.TextTransparency       = dim
    nameLbl.Font                   = Enum.Font.GothamBold
    nameLbl.TextSize               = 11
    nameLbl.TextWrapped            = true
    nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
    nameLbl.TextYAlignment         = Enum.TextYAlignment.Top
    nameLbl.Parent                 = card

    -- type tag
    local typeTag = Instance.new("Frame")
    typeTag.Position               = UDim2.new(0, 5, 0, 46)
    typeTag.Size                   = UDim2.new(1, -10, 0, 16)
    typeTag.BackgroundColor3       = elemCol
    typeTag.BackgroundTransparency = 0.78 + (dim * 0.15)
    typeTag.BorderSizePixel        = 0
    mkCorner(typeTag, UDim.new(0, 4))
    typeTag.Parent                 = card

    local typeLbl = Instance.new("TextLabel")
    typeLbl.Position               = UDim2.new(0, 4, 0, 0)
    typeLbl.Size                   = UDim2.new(1, -8, 1, 0)
    typeLbl.BackgroundTransparency = 1
    typeLbl.Text                   = cardType
    typeLbl.TextColor3             = elemCol
    typeLbl.TextTransparency       = dim
    typeLbl.Font                   = Enum.Font.GothamMedium
    typeLbl.TextSize               = 10
    typeLbl.TextXAlignment         = Enum.TextXAlignment.Left
    typeLbl.Parent                 = typeTag

    -- art placeholder
    local artBg = Instance.new("Frame")
    artBg.Position               = UDim2.new(0, 5, 0, 66)
    artBg.Size                   = UDim2.new(1, -10, 0, 38)
    artBg.BackgroundColor3       = elemCol
    artBg.BackgroundTransparency = 0.82 + (dim * 0.1)
    artBg.BorderSizePixel        = 0
    mkCorner(artBg, UDim.new(0, 4))
    artBg.Parent                 = card

    local artLbl = Instance.new("TextLabel")
    artLbl.Size                   = UDim2.new(1, 0, 1, 0)
    artLbl.BackgroundTransparency = 1
    artLbl.Text                   = elem
    artLbl.TextColor3             = elemCol
    artLbl.TextTransparency       = dim
    artLbl.Font                   = Enum.Font.GothamBold
    artLbl.TextSize               = 11
    artLbl.Parent                 = artBg

    -- P/T badge for creatures
    if cardData and cardData.cardType == "Creature" then
        local ptBadge = Instance.new("Frame")
        ptBadge.AnchorPoint            = Vector2.new(1, 1)
        ptBadge.Position               = UDim2.new(1, -5, 1, -5)
        ptBadge.Size                   = UDim2.new(0, 52, 0, 20)
        ptBadge.BackgroundColor3       = Color3.fromRGB(10, 12, 22)
        ptBadge.BackgroundTransparency = dim
        ptBadge.BorderSizePixel        = 0
        mkCorner(ptBadge, UDim.new(0, 4))
        mkStroke(ptBadge, T.cardBorder, 1, dim)
        ptBadge.Parent                 = card

        local ptLbl = Instance.new("TextLabel")
        ptLbl.Size                   = UDim2.new(1, 0, 1, 0)
        ptLbl.BackgroundTransparency = 1
        ptLbl.Text                   = (cardData.power or 0) .. " / " .. (cardData.toughness or 0)
        ptLbl.TextColor3             = T.textBright
        ptLbl.TextTransparency       = dim
        ptLbl.Font                   = Enum.Font.GothamBold
        ptLbl.TextSize               = 12
        ptLbl.Parent                 = ptBadge
    end

    -- play on click (playable only)
    card:SetAttribute("Playable", playable)
    if playable then
        card.MouseButton1Click:Connect(function()
            matchClient.playCard(cardId)
        end)
    end

    return card
end

-- Lay out the hand as a shallow upward arc. Each card gets a distinct Y
-- offset (arc shape); a slight per-card tilt keeps mirrored cards distinct.
local MAX_LIFT  = 34   -- px the centre card rises above the edge cards
local SPACING   = 78   -- px between card centres
local MAX_ROT   = 8    -- degrees of fan rotation at the edges
local TILT      = 0.4  -- tiny linear term so no two Y offsets collide

local function layoutFanHand(cards)
    local n = #cards
    if n == 0 then return end
    local mid = (n + 1) / 2

    for i, card in ipairs(cards) do
        local t    = i - mid
        local norm = (n > 1) and (t / mid) or 0           -- -1 .. 1
        local lift = (1 - norm * norm) * MAX_LIFT          -- parabola, peak centre
        local yOff = -lift + (i * TILT)                    -- TILT breaks symmetry
        local xOff = t * SPACING

        card.AnchorPoint = Vector2.new(0.5, 1)
        card.Rotation    = norm * MAX_ROT
        card.Position    = UDim2.new(0.5, xOff, 1, yOff)

        -- unplayable cards: no hover interaction (PRD) — leave them at rest
        if not card:GetAttribute("Playable") then
            continue
        end

        -- hover: lift + enlarge
        local basePos = card.Position
        local baseRot = card.Rotation
        local baseSize= card.Size
        card.MouseEnter:Connect(function()
            card.ZIndex = 50
            TweenService:Create(card, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, xOff, 1, yOff - 30),
                Rotation = 0,
                Size     = UDim2.new(0, math.floor(CARD_W * 1.15), 0, math.floor(CARD_H * 1.15)),
            }):Play()
        end)
        card.MouseLeave:Connect(function()
            card.ZIndex = 1
            TweenService:Create(card, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = basePos,
                Rotation = baseRot,
                Size     = baseSize,
            }):Play()
        end)
    end
end

-- ════════════════════════════════════════════════════════════════
--  BATTLEFIELD CARD
-- ════════════════════════════════════════════════════════════════
local function buildFieldCard(creature, isMine, isAttacker, matchClient)
    local elemCol   = ELEMENT_COLORS[creature.element] or ELEMENT_COLORS.Neutral
    local isDamaged = (creature.damageTaken or 0) > 0
    local W, H      = 80, 116

    local card = Instance.new("Frame")
    card.Name                   = "FC_" .. creature.instanceId
    card.Size                   = UDim2.new(0, W, 0, H)
    card.BackgroundColor3       = isAttacker and Color3.fromRGB(40, 16, 8) or T.cardBg
    card.BackgroundTransparency = 0
    card.BorderSizePixel        = 0
    mkCorner(card, T.sm)

    local borderCol = isAttacker and T.atkHighlight
        or creature.tapped       and Color3.fromRGB(48, 52, 86)
        or elemCol
    mkStroke(card, borderCol, isAttacker and 2.5 or 1.5)

    if creature.tapped then card.Rotation = 13 end

    local stripe = Instance.new("Frame")
    stripe.Size                   = UDim2.new(1, 0, 0, 5)
    stripe.BackgroundColor3       = elemCol
    stripe.BackgroundTransparency = creature.tapped and 0.5 or 0
    stripe.BorderSizePixel        = 0
    mkCorner(stripe, UDim.new(0, 6))
    stripe.Parent                 = card

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Position               = UDim2.new(0, 3, 0, 8)
    nameLbl.Size                   = UDim2.new(1, -6, 0, 32)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = creature.name or creature.id
    nameLbl.TextColor3             = creature.tapped and T.textSub or T.textBright
    nameLbl.Font                   = Enum.Font.GothamBold
    nameLbl.TextSize               = 9
    nameLbl.TextWrapped            = true
    nameLbl.Parent                 = card

    if isAttacker then
        local atkBadge = Instance.new("Frame")
        atkBadge.Position               = UDim2.new(0, 3, 0, 42)
        atkBadge.Size                   = UDim2.new(1, -6, 0, 16)
        atkBadge.BackgroundColor3       = T.atkHighlight
        atkBadge.BackgroundTransparency = 0.15
        atkBadge.BorderSizePixel        = 0
        mkCorner(atkBadge, UDim.new(0, 4))
        atkBadge.Parent                 = card

        local atkLbl = Instance.new("TextLabel")
        atkLbl.Size                   = UDim2.new(1, 0, 1, 0)
        atkLbl.BackgroundTransparency = 1
        atkLbl.Text                   = "⚔ ATTACKING"
        atkLbl.TextColor3             = Color3.fromRGB(255, 180, 95)
        atkLbl.Font                   = Enum.Font.GothamBold
        atkLbl.TextSize               = 8
        atkLbl.Parent                 = atkBadge
    elseif creature.tapped then
        local tappedLbl = Instance.new("TextLabel")
        tappedLbl.Position               = UDim2.new(0, 3, 0, 42)
        tappedLbl.Size                   = UDim2.new(1, -6, 0, 16)
        tappedLbl.BackgroundTransparency = 1
        tappedLbl.Text                   = "TAPPED"
        tappedLbl.TextColor3             = Color3.fromRGB(90, 92, 135)
        tappedLbl.Font                   = Enum.Font.GothamBold
        tappedLbl.TextSize               = 8
        tappedLbl.Parent                 = card
    end

    if creature.keywords and #creature.keywords > 0 then
        local kwLbl = Instance.new("TextLabel")
        kwLbl.AnchorPoint            = Vector2.new(0, 1)
        kwLbl.Position               = UDim2.new(0, 3, 1, -24)
        kwLbl.Size                   = UDim2.new(1, -6, 0, 12)
        kwLbl.BackgroundTransparency = 1
        kwLbl.Text                   = table.concat(creature.keywords, " · ")
        kwLbl.TextColor3             = T.mana
        kwLbl.Font                   = Enum.Font.GothamMedium
        kwLbl.TextSize               = 7
        kwLbl.TextWrapped            = true
        kwLbl.Parent                 = card
    end

    local currentToughness = creature.toughness - (creature.damageTaken or 0)
    local ptBadge = Instance.new("Frame")
    ptBadge.AnchorPoint            = Vector2.new(1, 1)
    ptBadge.Position               = UDim2.new(1, -3, 1, -3)
    ptBadge.Size                   = UDim2.new(0, 48, 0, 18)
    ptBadge.BackgroundColor3       = isDamaged and Color3.fromRGB(58, 14, 14) or Color3.fromRGB(10, 12, 22)
    ptBadge.BackgroundTransparency = 0
    ptBadge.BorderSizePixel        = 0
    mkCorner(ptBadge, UDim.new(0, 4))
    mkStroke(ptBadge, isDamaged and T.danger or T.cardBorder, 1)
    ptBadge.Parent                 = card

    local ptLbl = Instance.new("TextLabel")
    ptLbl.Size                   = UDim2.new(1, 0, 1, 0)
    ptLbl.BackgroundTransparency = 1
    ptLbl.Text                   = creature.power .. "/" .. currentToughness
    ptLbl.TextColor3             = isDamaged and T.danger or T.textBright
    ptLbl.Font                   = Enum.Font.GothamBold
    ptLbl.TextSize               = 11
    ptLbl.Parent                 = ptBadge

    if isMine and matchClient then
        local atkBtn = mkButton(card,
            isAttacker and "⚔ Atk" or "Attack",
            isAttacker and T.btnAttack or T.btnNeutral,
            UDim2.new(1, -6, 0, 18),
            UDim2.new(0.5, 0, 0, 60),
            UDim.new(0, 4))
        atkBtn.AnchorPoint = Vector2.new(0.5, 0)
        atkBtn.TextSize    = 9
        atkBtn.MouseButton1Click:Connect(function()
            matchClient.declareAttacker(creature.instanceId)
        end)
        onHover(atkBtn,
            isAttacker and T.btnAttack or T.btnNeutral,
            isAttacker and T.btnAttackHvr or T.cardHover)
    end

    return card
end

-- ════════════════════════════════════════════════════════════════
--  UPDATE FROM SNAPSHOT
-- ════════════════════════════════════════════════════════════════
function BattleUI.update(snapshot, matchClient)
    if not screenGui then return end

    -- store graveyards for the inspection modal
    lastMyGraveyard  = snapshot.myGraveyard  or {}
    lastOppGraveyard = snapshot.oppGraveyard or {}

    -- life
    local myLife  = snapshot.myLife  or 20
    local oppLife = snapshot.oppLife or 20
    if myLifeLabel then
        myLifeLabel.Text       = tostring(myLife)
        myLifeLabel.TextColor3 = myLife <= 5 and T.danger or T.life
    end
    if oppLifeLabel then
        oppLifeLabel.Text       = tostring(oppLife)
        oppLifeLabel.TextColor3 = oppLife <= 5 and T.danger or T.red
    end

    -- mana
    if myManaLabel then
        myManaLabel.Text = (snapshot.myMana or 0) .. " / " .. (snapshot.myMaxMana or 0)
    end

    -- phase / turn banner
    if snapshot.winner then
        if turnLabel    then turnLabel.Text    = "MATCH OVER" end
        if phaseLabel   then phaseLabel.Text   = "" end
        if endPhaseBtn  then endPhaseBtn.Visible = false end
    elseif snapshot.isMyTurn then
        if turnLabel    then turnLabel.Text    = "YOUR TURN" end
        if phaseLabel   then phaseLabel.Text   = "Phase: " .. (snapshot.phase or "?"):upper() end
        if endPhaseBtn  then endPhaseBtn.Visible = true end
    else
        if turnLabel    then turnLabel.Text    = "OPPONENT'S TURN" end
        if phaseLabel   then phaseLabel.Text   = "Phase: " .. (snapshot.phase or "?"):upper() end
        if endPhaseBtn  then endPhaseBtn.Visible = false end
    end

    -- deck counts
    if myDeckLabel  then myDeckLabel.Text  = "Deck: " .. (snapshot.myDeckCount  or 0) end
    if oppDeckLabel then oppDeckLabel.Text = "Deck: " .. (snapshot.oppDeckCount or 0) end

    -- graveyard counts + top card
    local myGy  = snapshot.myGraveyard  or {}
    local oppGy = snapshot.oppGraveyard or {}
    if myGyCount  then myGyCount.Text  = "Graveyard: " .. #myGy  end
    if oppGyCount then oppGyCount.Text = "Graveyard: " .. #oppGy end
    if myGyTop    then myGyTop.Text    = #myGy  > 0 and cardName(myGy[#myGy])   or "empty" end
    if oppGyTop   then oppGyTop.Text   = #oppGy > 0 and cardName(oppGy[#oppGy]) or "empty" end

    -- clear dynamic frames
    for _, child in ipairs(myFieldFrame:GetChildren()) do
        if child:IsA("GuiButton") or child:IsA("Frame") then child:Destroy() end
    end
    for _, child in ipairs(oppFieldFrame:GetChildren()) do
        if child:IsA("GuiButton") or child:IsA("Frame") then child:Destroy() end
    end
    for _, child in ipairs(handLayer:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end

    -- empty hints
    local myCount  = snapshot.myBattlefield  and #snapshot.myBattlefield  or 0
    local oppCount = snapshot.oppBattlefield and #snapshot.oppBattlefield or 0
    if myEmptyHint  then myEmptyHint.Visible  = myCount  == 0 end
    if oppEmptyHint then oppEmptyHint.Visible = oppCount == 0 end

    -- my battlefield
    if snapshot.myBattlefield then
        local canAttack = snapshot.isMyTurn and snapshot.phase == "combat"
        for _, creature in ipairs(snapshot.myBattlefield) do
            local c = buildFieldCard(creature, true, false, canAttack and matchClient or nil)
            c.Parent = myFieldFrame
        end
    end

    -- opponent battlefield
    if snapshot.oppBattlefield then
        for _, creature in ipairs(snapshot.oppBattlefield) do
            local c = buildFieldCard(creature, false, false, nil)
            c.Parent = oppFieldFrame
        end
    end

    -- hand (fan)
    local canPlayCards = snapshot.isMyTurn and snapshot.phase == "main"
    if snapshot.myHand then
        local cs = cardSystem()
        local builtCards = {}
        for _, cardId in ipairs(snapshot.myHand) do
            local data       = cs and cs.getCard(cardId)
            local affordable = data and (snapshot.myMana or 0) >= data.manaCost
            local playable   = canPlayCards and affordable and true or false
            local cardFrame  = buildHandCard(cardId, data, playable, matchClient)
            cardFrame.Parent = handLayer
            table.insert(builtCards, cardFrame)
        end
        layoutFanHand(builtCards)
    end
end

-- ── OPPONENT-SKIN TOGGLE (client-local) ─────────────────────────
function BattleUI.setShowOpponentSkin(value)
    showOpponentSkin = value and true or false
    if oppHalf then
        paintHalf(oppHalf, showOpponentSkin and oppSkinId or BoardSkinRegistry.DEFAULT_SKIN_ID, true)
    end
end

-- ════════════════════════════════════════════════════════════════
--  MATCH RESULT
-- ════════════════════════════════════════════════════════════════
function BattleUI.showResult(won)
    if not screenGui then return end

    local dimmer = Instance.new("Frame")
    dimmer.Size                   = UDim2.new(1, 0, 1, 0)
    dimmer.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    dimmer.BackgroundTransparency = 0.5
    dimmer.BorderSizePixel        = 0
    dimmer.ZIndex                 = 36
    dimmer.Parent                 = screenGui

    local resultCard = Instance.new("Frame")
    resultCard.AnchorPoint      = Vector2.new(0.5, 0.5)
    resultCard.Position         = UDim2.new(0.5, 0, 0.5, 0)
    resultCard.Size             = UDim2.new(0, 400, 0, 0)
    resultCard.BackgroundColor3 = Color3.fromRGB(14, 16, 28)
    resultCard.BorderSizePixel  = 0
    resultCard.ZIndex           = 37
    mkCorner(resultCard, T.lg)
    mkStroke(resultCard, won and T.gold or T.danger, 2.5)
    resultCard.Parent           = screenGui

    local headline = Instance.new("TextLabel")
    headline.AnchorPoint            = Vector2.new(0.5, 0.5)
    headline.Position               = UDim2.new(0.5, 0, 0.38, 0)
    headline.Size                   = UDim2.new(0.9, 0, 0, 64)
    headline.BackgroundTransparency = 1
    headline.Text                   = won and "🏆  VICTORY!" or "💀  DEFEAT"
    headline.TextColor3             = won and T.gold or T.danger
    headline.Font                   = Enum.Font.GothamBlack
    headline.TextSize               = 42
    headline.ZIndex                 = 38
    headline.Parent                 = resultCard

    local subMsg = Instance.new("TextLabel")
    subMsg.AnchorPoint            = Vector2.new(0.5, 0.5)
    subMsg.Position               = UDim2.new(0.5, 0, 0.62, 0)
    subMsg.Size                   = UDim2.new(0.88, 0, 0, 24)
    subMsg.BackgroundTransparency = 1
    subMsg.Text                   = won and "Well played, champion!" or "Better luck next time."
    subMsg.TextColor3             = T.textSub
    subMsg.Font                   = Enum.Font.GothamMedium
    subMsg.TextSize               = 14
    subMsg.ZIndex                 = 38
    subMsg.Parent                 = resultCard

    local lobbyBtn = mkButton(resultCard, "Back to Lobby",
        won and T.btnGreen or T.btnBlue,
        UDim2.new(0, 170, 0, 42),
        UDim2.new(0.5, -85, 1, -58),
        T.sm)
    lobbyBtn.ZIndex = 38
    lobbyBtn.MouseButton1Click:Connect(function()
        BattleUI.close()
    end)
    onHover(lobbyBtn, won and T.btnGreen or T.btnBlue,
        won and T.btnGreenHover or Color3.fromRGB(58, 118, 214))

    TweenService:Create(resultCard,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 400, 0, 210) }):Play()
end

-- ════════════════════════════════════════════════════════════════
--  ERROR TOAST
-- ════════════════════════════════════════════════════════════════
function BattleUI.showError(text)
    if not screenGui then return end

    local toast = Instance.new("Frame")
    toast.AnchorPoint            = Vector2.new(0.5, 1)
    toast.Position               = UDim2.new(0.5, 0, 1, 60)
    toast.Size                   = UDim2.new(0, 380, 0, 42)
    toast.BackgroundColor3       = Color3.fromRGB(168, 40, 40)
    toast.BorderSizePixel        = 0
    toast.ZIndex                 = 60
    mkCorner(toast, T.sm)
    mkStroke(toast, T.danger, 1.5)
    toast.Parent                 = screenGui

    local msg = Instance.new("TextLabel")
    msg.Size                   = UDim2.new(1, -16, 1, 0)
    msg.Position               = UDim2.new(0, 8, 0, 0)
    msg.BackgroundTransparency = 1
    msg.Text                   = "⚠  " .. text
    msg.TextColor3             = Color3.fromRGB(255, 255, 255)
    msg.Font                   = Enum.Font.GothamMedium
    msg.TextSize               = 13
    msg.TextWrapped            = true
    msg.ZIndex                 = 61
    msg.Parent                 = toast

    TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 1, -150)
    }):Play()

    task.delay(2.5, function()
        if toast and toast.Parent then
            TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            task.delay(0.35, function()
                if toast and toast.Parent then toast:Destroy() end
            end)
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
--  CLOSE
-- ════════════════════════════════════════════════════════════════
function BattleUI.close()
    CutscenePlayer.reset()
    if screenGui then
        screenGui:Destroy()
    end
    screenGui    = nil
    root         = nil
    myHalf       = nil
    oppHalf      = nil
    myFieldFrame = nil
    oppFieldFrame= nil
    handLayer    = nil
    myLifeLabel  = nil
    oppLifeLabel = nil
    myManaLabel  = nil
    phaseBanner  = nil
    turnLabel    = nil
    phaseLabel   = nil
    endPhaseBtn  = nil
    myNameLabel  = nil
    oppNameLabel = nil
    myEmptyHint  = nil
    oppEmptyHint = nil
    myDeckLabel  = nil
    oppDeckLabel = nil
    myGyCount    = nil
    oppGyCount   = nil
    myGyTop      = nil
    oppGyTop     = nil
end

return BattleUI
