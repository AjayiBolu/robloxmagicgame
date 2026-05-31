--[[
    BattleUI.luau
    Location: StarterPlayerScripts/Client/BattleUI

    MTG ARENA-INSPIRED GAME BOARD
    ==============================
    Transparent root so the 3D Roblox world shows through.
    All panels are semi-transparent, floating overlays.

    Layout (top → bottom):
    ┌─────────────────────────────────────────────────────────┐
    │  [Opp Badge: life circle + hand count]  [Phase Banner]  │
    │  ─────────────────── OPP BATTLEFIELD ───────────────── │
    │  ─────────────────────────────────────────────────────  │
    │  ──────────────────── MY BATTLEFIELD ──────────────────  │
    │  ─────── [♥ Life] [⚡ Mana] ─────── [End Phase →] ──── │
    │  ────────────────── HAND (scrollable) ─────────────────  │
    └─────────────────────────────────────────────────────────┘

    Called by MatchClient — never talks to the server directly.
]]

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── THEME ──────────────────────────────────────────────────────
local T = {
    -- Panel backgrounds (paired with BackgroundTransparency)
    panelDark     = Color3.fromRGB(8,  10, 20),
    panelMid      = Color3.fromRGB(14, 16, 32),
    oppZoneBg     = Color3.fromRGB(30,  8, 12),   -- red-dark tint
    myZoneBg      = Color3.fromRGB( 8, 14, 32),   -- blue-dark tint

    -- Accent colours
    gold          = Color3.fromRGB(255, 210,  80),
    goldDim       = Color3.fromRGB(160, 120,  35),
    red           = Color3.fromRGB(220,  55,  55),
    redDim        = Color3.fromRGB(140,  35,  35),
    blue          = Color3.fromRGB( 70, 140, 255),
    blueDim       = Color3.fromRGB( 40,  80, 170),
    mana          = Color3.fromRGB( 80, 150, 255),
    life          = Color3.fromRGB( 70, 215, 105),
    danger        = Color3.fromRGB(230,  55,  55),

    -- Text
    textBright    = Color3.fromRGB(235, 235, 250),
    textSub       = Color3.fromRGB(145, 150, 180),
    textDim       = Color3.fromRGB( 90,  95, 130),

    -- Card
    cardBg        = Color3.fromRGB(20, 22, 42),
    cardHover     = Color3.fromRGB(32, 36, 62),
    cardBorder    = Color3.fromRGB(50, 55, 95),

    -- Buttons
    btnGreen      = Color3.fromRGB( 50, 155,  80),
    btnGreenHover = Color3.fromRGB( 65, 185, 100),
    btnRed        = Color3.fromRGB(155,  40,  40),
    btnRedHover   = Color3.fromRGB(190,  55,  55),
    btnAttack     = Color3.fromRGB(195,  65,  20),
    btnAttackHvr  = Color3.fromRGB(220,  85,  35),
    btnBlue       = Color3.fromRGB( 45, 100, 200),

    -- Attack / block highlights
    atkHighlight  = Color3.fromRGB(220, 75, 25),

    -- Corner shorthands
    sm   = UDim.new(0,  6),
    md   = UDim.new(0, 10),
    lg   = UDim.new(0, 14),
    full = UDim.new(0.5, 0),
}

local ELEMENT_COLORS = {
    Fire    = Color3.fromRGB(225,  70,  20),
    Water   = Color3.fromRGB( 30, 120, 225),
    Earth   = Color3.fromRGB(125,  80,  30),
    Air     = Color3.fromRGB(145, 200, 255),
    Dark    = Color3.fromRGB(125,  40, 210),
    Light   = Color3.fromRGB(255, 225,  65),
    Neutral = Color3.fromRGB(130, 130, 155),
}

-- ── LOW-LEVEL HELPERS ──────────────────────────────────────────
local function mkCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or T.md
    c.Parent = parent
    return c
end

local function mkStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or T.cardBorder
    s.Thickness = thickness or 1.5
    s.Parent    = parent
    return s
end

local function mkPad(parent, top, bot, left, right)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, top  or 8)
    p.PaddingBottom = UDim.new(0, bot  or 8)
    p.PaddingLeft   = UDim.new(0, left or 8)
    p.PaddingRight  = UDim.new(0, right or 8)
    p.Parent = parent
    return p
end

local function mkListLayout(parent, fillDir, vAlign, hAlign, padding)
    local l = Instance.new("UIListLayout")
    l.FillDirection        = fillDir  or Enum.FillDirection.Horizontal
    l.VerticalAlignment    = vAlign   or Enum.VerticalAlignment.Center
    l.HorizontalAlignment  = hAlign   or Enum.HorizontalAlignment.Center
    l.Padding              = padding  or UDim.new(0, 8)
    l.Parent               = parent
    return l
end

-- Hover colour tween on a GuiObject
local function onHover(obj, normalColor, hoverColor)
    obj.MouseEnter:Connect(function()
        TweenService:Create(obj, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
    end)
    obj.MouseLeave:Connect(function()
        TweenService:Create(obj, TweenInfo.new(0.12), { BackgroundColor3 = normalColor }):Play()
    end)
end

-- Semi-transparent floating panel
local function mkPanel(parent, name, pos, size, bg, bgTransp, strokeCol, strokeThk, cornerR)
    local f = Instance.new("Frame")
    f.Name                   = name
    f.Position               = pos
    f.Size                   = size
    f.BackgroundColor3       = bg      or T.panelDark
    f.BackgroundTransparency = bgTransp or 0.45
    f.BorderSizePixel        = 0
    f.Parent                 = parent
    mkCorner(f, cornerR or T.md)
    if strokeCol then mkStroke(f, strokeCol, strokeThk or 1.5) end
    return f
end

-- Styled text label
local function mkLabel(parent, text, sz, color, bold, xAlign)
    local l = Instance.new("TextLabel")
    l.Size                   = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text                   = text
    l.TextSize               = sz    or 13
    l.TextColor3             = color or T.textBright
    l.Font                   = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextXAlignment         = xAlign or Enum.TextXAlignment.Center
    l.TextWrapped            = true
    l.Parent                 = parent
    return l
end

-- Styled button (TextButton)
local function mkButton(parent, text, bg, size, pos, cornerR)
    local b = Instance.new("TextButton")
    b.Size                   = size
    b.Position               = pos or UDim2.new(0, 0, 0, 0)
    b.BackgroundColor3       = bg
    b.BackgroundTransparency = 0.08
    b.BorderSizePixel        = 0
    b.Text                   = text
    b.TextColor3             = Color3.fromRGB(255, 255, 255)
    b.Font                   = Enum.Font.GothamBold
    b.TextSize               = 13
    b.AutoButtonColor        = false
    b.Parent                 = parent
    mkCorner(b, cornerR or T.sm)
    return b
end

-- ── MODULE ─────────────────────────────────────────────────────
local BattleUI = {}

-- Active UI references — rebuilt on each open()
local screenGui         = nil
local handScroll        = nil
local myFieldFrame      = nil
local oppFieldFrame     = nil
local myLifeLabel       = nil   -- the big number inside the life circle
local oppLifeLabel      = nil
local myManaLabel       = nil
local phaseBanner       = nil
local turnLabel         = nil
local phaseLabel        = nil
local endPhaseBtn       = nil
local oppHandCountLabel = nil
local myEmptyHint       = nil
local oppEmptyHint      = nil

-- Stubs — matchmaking panel is now owned by MatchClient
function BattleUI.showFindMatchButton(_) end
function BattleUI.showQueueStatus(_)    end
function BattleUI.hideQueueStatus()     end

-- ── LIFE CIRCLE ────────────────────────────────────────────────
-- Returns (circleFrame, numberLabel)
local function mkLifeCircle(parent, initVal, isOpp)
    local accent = isOpp and T.red or T.life
    local bgTint = isOpp
        and Color3.fromRGB(48, 8, 8)
        or  Color3.fromRGB(8, 40, 18)

    local circle = Instance.new("Frame")
    circle.Size                   = UDim2.new(0, 50, 0, 50)
    circle.BackgroundColor3       = bgTint
    circle.BackgroundTransparency = 0.1
    circle.BorderSizePixel        = 0
    circle.Parent                 = parent
    mkCorner(circle, T.full)
    mkStroke(circle, accent, 2)

    local numLbl = Instance.new("TextLabel")
    numLbl.Size                   = UDim2.new(1, 0, 1, 0)
    numLbl.BackgroundTransparency = 1
    numLbl.Text                   = tostring(initVal or 20)
    numLbl.TextColor3             = accent
    numLbl.Font                   = Enum.Font.GothamBold
    numLbl.TextSize               = 20
    numLbl.TextXAlignment         = Enum.TextXAlignment.Center
    numLbl.Parent                 = circle

    return circle, numLbl
end

-- ── OPEN THE BATTLE BOARD ──────────────────────────────────────
function BattleUI.open(matchClient)
    if screenGui then screenGui:Destroy() end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "BattleScreen"
    screenGui.ResetOnSpawn   = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder   = 5
    screenGui.Parent         = playerGui

    -- ── ROOT: transparent — the 3D world shows through ──────────
    local root = Instance.new("Frame")
    root.Name                   = "Root"
    root.Size                   = UDim2.new(1, 0, 1, 0)
    root.BackgroundTransparency = 1
    root.BorderSizePixel        = 0
    root.Parent                 = screenGui

    -- ══════════════════════════════════════════════════════════
    -- TOP ROW: Opponent badge  |  Phase banner  |  Forfeit btn
    -- ══════════════════════════════════════════════════════════

    -- Opponent badge (top-left)
    local oppBadge = mkPanel(root, "OppBadge",
        UDim2.new(0, 10, 0, 10),
        UDim2.new(0, 230, 0, 70),
        T.panelDark, 0.3,
        T.redDim, 1.5, T.md
    )
    -- Manual positions inside oppBadge (no layout — avoids layout manager fighting AnchorPoint)
    local oppCircle, oppLifeLbl = mkLifeCircle(oppBadge, 20, true)
    oppCircle.Position  = UDim2.new(0, 10, 0.5, -25)
    oppLifeLabel        = oppLifeLbl

    local oppNameLbl = Instance.new("TextLabel")
    oppNameLbl.Position               = UDim2.new(0, 70, 0, 10)
    oppNameLbl.Size                   = UDim2.new(1, -80, 0, 22)
    oppNameLbl.BackgroundTransparency = 1
    oppNameLbl.Text                   = "Opponent"
    oppNameLbl.TextColor3             = T.textBright
    oppNameLbl.Font                   = Enum.Font.GothamBold
    oppNameLbl.TextSize               = 13
    oppNameLbl.TextXAlignment         = Enum.TextXAlignment.Left
    oppNameLbl.Parent                 = oppBadge

    oppHandCountLabel = Instance.new("TextLabel")
    oppHandCountLabel.Position               = UDim2.new(0, 70, 0, 36)
    oppHandCountLabel.Size                   = UDim2.new(1, -80, 0, 18)
    oppHandCountLabel.BackgroundTransparency = 1
    oppHandCountLabel.Text                   = "Hand: — cards"
    oppHandCountLabel.TextColor3             = T.textSub
    oppHandCountLabel.Font                   = Enum.Font.Gotham
    oppHandCountLabel.TextSize               = 11
    oppHandCountLabel.TextXAlignment         = Enum.TextXAlignment.Left
    oppHandCountLabel.Parent                 = oppBadge

    -- Phase banner (top-centre)
    phaseBanner = mkPanel(root, "PhaseBanner",
        UDim2.new(0.5, -145, 0, 10),
        UDim2.new(0, 290, 0, 58),
        T.panelDark, 0.28,
        T.goldDim, 1.5, T.md
    )

    turnLabel = Instance.new("TextLabel")
    turnLabel.Size                   = UDim2.new(1, 0, 0, 28)
    turnLabel.Position               = UDim2.new(0, 0, 0, 6)
    turnLabel.BackgroundTransparency = 1
    turnLabel.Text                   = "Waiting for match…"
    turnLabel.TextColor3             = T.gold
    turnLabel.Font                   = Enum.Font.GothamBold
    turnLabel.TextSize               = 15
    turnLabel.TextXAlignment         = Enum.TextXAlignment.Center
    turnLabel.Parent                 = phaseBanner

    phaseLabel = Instance.new("TextLabel")
    phaseLabel.Size                   = UDim2.new(1, 0, 0, 18)
    phaseLabel.Position               = UDim2.new(0, 0, 0, 36)
    phaseLabel.BackgroundTransparency = 1
    phaseLabel.Text                   = ""
    phaseLabel.TextColor3             = T.textSub
    phaseLabel.Font                   = Enum.Font.Gotham
    phaseLabel.TextSize               = 11
    phaseLabel.TextXAlignment         = Enum.TextXAlignment.Center
    phaseLabel.Parent                 = phaseBanner

    -- Forfeit button (top-right)
    local forfeitBtn = mkButton(root, "✕  Forfeit", T.btnRed,
        UDim2.new(0, 90, 0, 34),
        UDim2.new(1, -102, 0, 22),
        T.sm
    )
    forfeitBtn.MouseButton1Click:Connect(function()
        matchClient.forfeit()
        BattleUI.close()
    end)
    onHover(forfeitBtn, T.btnRed, T.btnRedHover)

    -- ══════════════════════════════════════════════════════════
    -- OPPONENT BATTLEFIELD ZONE
    -- ══════════════════════════════════════════════════════════
    local oppZone = mkPanel(root, "OppZone",
        UDim2.new(0, 8, 0, 88),
        UDim2.new(1, -16, 0, 190),
        T.oppZoneBg, 0.58,
        T.redDim, 1.2, T.md
    )

    local oppZoneTitle = Instance.new("TextLabel")
    oppZoneTitle.Size                   = UDim2.new(1, 0, 0, 18)
    oppZoneTitle.Position               = UDim2.new(0, 0, 0, 5)
    oppZoneTitle.BackgroundTransparency = 1
    oppZoneTitle.Text                   = "▼   OPPONENT'S BATTLEFIELD"
    oppZoneTitle.TextColor3             = Color3.fromRGB(175, 70, 70)
    oppZoneTitle.Font                   = Enum.Font.GothamBold
    oppZoneTitle.TextSize               = 10
    oppZoneTitle.TextXAlignment         = Enum.TextXAlignment.Center
    oppZoneTitle.Parent                 = oppZone

    oppFieldFrame = Instance.new("Frame")
    oppFieldFrame.Name                   = "OppField"
    oppFieldFrame.Position               = UDim2.new(0, 0, 0, 24)
    oppFieldFrame.Size                   = UDim2.new(1, 0, 1, -24)
    oppFieldFrame.BackgroundTransparency = 1
    oppFieldFrame.Parent                 = oppZone

    mkListLayout(oppFieldFrame, Enum.FillDirection.Horizontal,
        Enum.VerticalAlignment.Center, Enum.HorizontalAlignment.Center, UDim.new(0, 10))

    oppEmptyHint = Instance.new("TextLabel")
    oppEmptyHint.Name                   = "EmptyHint"
    oppEmptyHint.Size                   = UDim2.new(1, 0, 1, 0)
    oppEmptyHint.BackgroundTransparency = 1
    oppEmptyHint.Text                   = "No creatures in play"
    oppEmptyHint.TextColor3             = Color3.fromRGB(100, 55, 55)
    oppEmptyHint.Font                   = Enum.Font.Gotham
    oppEmptyHint.TextSize               = 12
    oppEmptyHint.TextXAlignment         = Enum.TextXAlignment.Center
    oppEmptyHint.Parent                 = oppFieldFrame

    -- ══════════════════════════════════════════════════════════
    -- DIVIDER LINE
    -- ══════════════════════════════════════════════════════════
    local divider = Instance.new("Frame")
    divider.Name                   = "Divider"
    divider.AnchorPoint            = Vector2.new(0.5, 0)
    divider.Position               = UDim2.new(0.5, 0, 0, 283)
    divider.Size                   = UDim2.new(0.88, 0, 0, 1)
    divider.BackgroundColor3       = Color3.fromRGB(75, 80, 140)
    divider.BackgroundTransparency = 0.35
    divider.BorderSizePixel        = 0
    divider.Parent                 = root

    -- ══════════════════════════════════════════════════════════
    -- YOUR BATTLEFIELD ZONE
    -- ══════════════════════════════════════════════════════════
    local myZone = mkPanel(root, "MyZone",
        UDim2.new(0, 8, 0, 290),
        UDim2.new(1, -16, 0, 190),
        T.myZoneBg, 0.58,
        T.blueDim, 1.2, T.md
    )

    local myZoneTitle = Instance.new("TextLabel")
    myZoneTitle.Size                   = UDim2.new(1, 0, 0, 18)
    myZoneTitle.Position               = UDim2.new(0, 0, 0, 5)
    myZoneTitle.BackgroundTransparency = 1
    myZoneTitle.Text                   = "▲   YOUR BATTLEFIELD"
    myZoneTitle.TextColor3             = Color3.fromRGB(65, 120, 210)
    myZoneTitle.Font                   = Enum.Font.GothamBold
    myZoneTitle.TextSize               = 10
    myZoneTitle.TextXAlignment         = Enum.TextXAlignment.Center
    myZoneTitle.Parent                 = myZone

    myFieldFrame = Instance.new("Frame")
    myFieldFrame.Name                   = "MyField"
    myFieldFrame.Position               = UDim2.new(0, 0, 0, 24)
    myFieldFrame.Size                   = UDim2.new(1, 0, 1, -24)
    myFieldFrame.BackgroundTransparency = 1
    myFieldFrame.Parent                 = myZone

    mkListLayout(myFieldFrame, Enum.FillDirection.Horizontal,
        Enum.VerticalAlignment.Center, Enum.HorizontalAlignment.Center, UDim.new(0, 10))

    myEmptyHint = Instance.new("TextLabel")
    myEmptyHint.Name                   = "EmptyHint"
    myEmptyHint.Size                   = UDim2.new(1, 0, 1, 0)
    myEmptyHint.BackgroundTransparency = 1
    myEmptyHint.Text                   = "Play creatures to defend and attack"
    myEmptyHint.TextColor3             = Color3.fromRGB(50, 75, 130)
    myEmptyHint.Font                   = Enum.Font.Gotham
    myEmptyHint.TextSize               = 12
    myEmptyHint.TextXAlignment         = Enum.TextXAlignment.Center
    myEmptyHint.Parent                 = myFieldFrame

    -- ══════════════════════════════════════════════════════════
    -- YOUR INFO BAR (above the hand)
    -- ══════════════════════════════════════════════════════════
    local infoBar = mkPanel(root, "InfoBar",
        UDim2.new(0, 8, 1, -176),
        UDim2.new(1, -16, 0, 54),
        T.panelDark, 0.3,
        T.goldDim, 1.2, T.md
    )

    -- Life circle (manual position inside infoBar)
    local myCircle, myLifeLbl = mkLifeCircle(infoBar, 20, false)
    myCircle.Position = UDim2.new(0, 12, 0.5, -25)
    myLifeLabel       = myLifeLbl

    local lifeTagLbl = Instance.new("TextLabel")
    lifeTagLbl.Position               = UDim2.new(0, 68, 0.5, -20)
    lifeTagLbl.Size                   = UDim2.new(0, 38, 0, 40)
    lifeTagLbl.BackgroundTransparency = 1
    lifeTagLbl.Text                   = "♥\nLife"
    lifeTagLbl.TextColor3             = T.life
    lifeTagLbl.Font                   = Enum.Font.Gotham
    lifeTagLbl.TextSize               = 11
    lifeTagLbl.TextXAlignment         = Enum.TextXAlignment.Center
    lifeTagLbl.Parent                 = infoBar

    -- Vertical separator
    local sep = Instance.new("Frame")
    sep.Position               = UDim2.new(0, 114, 0.5, -18)
    sep.Size                   = UDim2.new(0, 1, 0, 36)
    sep.BackgroundColor3       = Color3.fromRGB(60, 65, 110)
    sep.BackgroundTransparency = 0.1
    sep.BorderSizePixel        = 0
    sep.Parent                 = infoBar

    -- Mana display
    local manaTitle = Instance.new("TextLabel")
    manaTitle.Position               = UDim2.new(0, 122, 0, 8)
    manaTitle.Size                   = UDim2.new(0, 95, 0, 16)
    manaTitle.BackgroundTransparency = 1
    manaTitle.Text                   = "⚡  MANA"
    manaTitle.TextColor3             = T.mana
    manaTitle.Font                   = Enum.Font.GothamBold
    manaTitle.TextSize               = 10
    manaTitle.TextXAlignment         = Enum.TextXAlignment.Left
    manaTitle.Parent                 = infoBar

    myManaLabel = Instance.new("TextLabel")
    myManaLabel.Position               = UDim2.new(0, 122, 0, 24)
    myManaLabel.Size                   = UDim2.new(0, 95, 0, 24)
    myManaLabel.BackgroundTransparency = 1
    myManaLabel.Text                   = "0 / 0"
    myManaLabel.TextColor3             = T.textBright
    myManaLabel.Font                   = Enum.Font.GothamBold
    myManaLabel.TextSize               = 18
    myManaLabel.TextXAlignment         = Enum.TextXAlignment.Left
    myManaLabel.Parent                 = infoBar

    -- End Phase button (right side of info bar)
    endPhaseBtn = mkButton(infoBar, "End Phase  →", T.btnGreen,
        UDim2.new(0, 130, 0, 36),
        UDim2.new(1, -142, 0.5, -18),
        T.sm
    )
    endPhaseBtn.MouseButton1Click:Connect(function()
        matchClient.endPhase()
    end)
    onHover(endPhaseBtn, T.btnGreen, T.btnGreenHover)

    -- ══════════════════════════════════════════════════════════
    -- HAND SCROLL (bottom — cards float up from screen edge)
    -- ══════════════════════════════════════════════════════════
    handScroll = Instance.new("ScrollingFrame")
    handScroll.Name                   = "HandScroll"
    handScroll.Position               = UDim2.new(0, 0, 1, -120)
    handScroll.Size                   = UDim2.new(1, 0, 0, 120)
    handScroll.BackgroundColor3       = T.panelDark
    handScroll.BackgroundTransparency = 0.42
    handScroll.BorderSizePixel        = 0
    handScroll.ScrollBarThickness     = 3
    handScroll.ScrollBarImageColor3   = Color3.fromRGB(75, 85, 150)
    handScroll.AutomaticCanvasSize    = Enum.AutomaticSize.X
    handScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    handScroll.ScrollingDirection     = Enum.ScrollingDirection.X
    handScroll.Parent                 = root
    mkPad(handScroll, 6, 6, 14, 14)

    -- Thin gold top-border on hand
    local handTopBorder = Instance.new("Frame")
    handTopBorder.Size                   = UDim2.new(1, 0, 0, 1)
    handTopBorder.BackgroundColor3       = T.goldDim
    handTopBorder.BackgroundTransparency = 0.4
    handTopBorder.BorderSizePixel        = 0
    handTopBorder.ZIndex                 = 2
    handTopBorder.Parent                 = handScroll

    local handTitleLbl = Instance.new("TextLabel")
    handTitleLbl.Size                   = UDim2.new(0, 70, 0, 12)
    handTitleLbl.Position               = UDim2.new(0, 14, 0, 4)
    handTitleLbl.BackgroundTransparency = 1
    handTitleLbl.Text                   = "YOUR HAND"
    handTitleLbl.TextColor3             = T.goldDim
    handTitleLbl.Font                   = Enum.Font.GothamBold
    handTitleLbl.TextSize               = 8
    handTitleLbl.ZIndex                 = 3
    handTitleLbl.Parent                 = handScroll

    local handLayout = Instance.new("UIListLayout")
    handLayout.FillDirection        = Enum.FillDirection.Horizontal
    handLayout.VerticalAlignment    = Enum.VerticalAlignment.Center
    handLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Left
    handLayout.Padding              = UDim.new(0, 6)
    handLayout.SortOrder            = Enum.SortOrder.LayoutOrder
    handLayout.Parent               = handScroll
end

-- ── BUILD A HAND CARD ──────────────────────────────────────────
-- Returns a Frame child ready to be parented into handScroll.
local function buildHandCard(cardId, cardData, canPlay, matchClient)
    local elem     = cardData and cardData.element or "Neutral"
    local elemCol  = ELEMENT_COLORS[elem] or ELEMENT_COLORS.Neutral
    local cardName = cardData and cardData.name    or cardId
    local cardType = cardData and cardData.cardType or "?"
    local manaCost = cardData and cardData.manaCost or 0

    local W, H = 85, 108

    local card = Instance.new("Frame")
    card.Name                   = "HC_" .. cardId
    card.Size                   = UDim2.new(0, W, 0, H)
    card.BackgroundColor3       = T.cardBg
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel        = 0
    mkCorner(card, T.sm)
    mkStroke(card, canPlay and elemCol or T.cardBorder, canPlay and 2 or 1)

    -- Element bar (top strip)
    local elemBar = Instance.new("Frame")
    elemBar.Size                   = UDim2.new(1, 0, 0, 5)
    elemBar.BackgroundColor3       = elemCol
    elemBar.BackgroundTransparency = canPlay and 0 or 0.55
    elemBar.BorderSizePixel        = 0
    mkCorner(elemBar, UDim.new(0, 6))
    elemBar.Parent                 = card

    -- Mana cost circle (top-right)
    local manaCirc = Instance.new("Frame")
    manaCirc.AnchorPoint            = Vector2.new(1, 0)
    manaCirc.Position               = UDim2.new(1, -4, 0, 4)
    manaCirc.Size                   = UDim2.new(0, 22, 0, 22)
    manaCirc.BackgroundColor3       = canPlay and T.mana or Color3.fromRGB(38, 45, 80)
    manaCirc.BackgroundTransparency = canPlay and 0.05 or 0.3
    manaCirc.BorderSizePixel        = 0
    mkCorner(manaCirc, T.full)
    manaCirc.Parent                 = card

    local manaNum = Instance.new("TextLabel")
    manaNum.Size                   = UDim2.new(1, 0, 1, 0)
    manaNum.BackgroundTransparency = 1
    manaNum.Text                   = tostring(manaCost)
    manaNum.TextColor3             = Color3.fromRGB(255, 255, 255)
    manaNum.Font                   = Enum.Font.GothamBold
    manaNum.TextSize               = 12
    manaNum.Parent                 = manaCirc

    -- Card name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Position               = UDim2.new(0, 4, 0, 7)
    nameLbl.Size                   = UDim2.new(1, -30, 0, 30)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = cardName
    nameLbl.TextColor3             = T.textBright
    nameLbl.Font                   = Enum.Font.GothamBold
    nameLbl.TextSize               = 9
    nameLbl.TextWrapped            = true
    nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
    nameLbl.Parent                 = card

    -- Type tag (below name)
    local typeTag = Instance.new("Frame")
    typeTag.Position               = UDim2.new(0, 4, 0, 39)
    typeTag.Size                   = UDim2.new(1, -8, 0, 15)
    typeTag.BackgroundColor3       = elemCol
    typeTag.BackgroundTransparency = 0.78
    typeTag.BorderSizePixel        = 0
    mkCorner(typeTag, UDim.new(0, 4))
    typeTag.Parent                 = card

    local typeLbl = Instance.new("TextLabel")
    typeLbl.Size                   = UDim2.new(1, -6, 1, 0)
    typeLbl.Position               = UDim2.new(0, 3, 0, 0)
    typeLbl.BackgroundTransparency = 1
    typeLbl.Text                   = cardType
    typeLbl.TextColor3             = elemCol
    typeLbl.Font                   = Enum.Font.Gotham
    typeLbl.TextSize               = 9
    typeLbl.TextXAlignment         = Enum.TextXAlignment.Left
    typeLbl.Parent                 = typeTag

    -- Art area (element-coloured placeholder)
    local artBg = Instance.new("Frame")
    artBg.Position               = UDim2.new(0, 4, 0, 57)
    artBg.Size                   = UDim2.new(1, -8, 0, 26)
    artBg.BackgroundColor3       = elemCol
    artBg.BackgroundTransparency = 0.82
    artBg.BorderSizePixel        = 0
    mkCorner(artBg, UDim.new(0, 4))
    artBg.Parent                 = card

    local artLbl = Instance.new("TextLabel")
    artLbl.Size                   = UDim2.new(1, 0, 1, 0)
    artLbl.BackgroundTransparency = 1
    artLbl.Text                   = elem
    artLbl.TextColor3             = elemCol
    artLbl.Font                   = Enum.Font.GothamBold
    artLbl.TextSize               = 9
    artLbl.Parent                 = artBg

    -- P/T badge for creatures
    if cardData and cardData.cardType == "Creature" then
        local ptBadge = Instance.new("Frame")
        ptBadge.AnchorPoint            = Vector2.new(1, 1)
        ptBadge.Position               = UDim2.new(1, -4, 1, -4)
        ptBadge.Size                   = UDim2.new(0, 48, 0, 18)
        ptBadge.BackgroundColor3       = T.panelDark
        ptBadge.BackgroundTransparency = 0.15
        ptBadge.BorderSizePixel        = 0
        mkCorner(ptBadge, UDim.new(0, 4))
        mkStroke(ptBadge, T.cardBorder, 1)
        ptBadge.Parent                 = card

        local ptLbl = Instance.new("TextLabel")
        ptLbl.Size                   = UDim2.new(1, 0, 1, 0)
        ptLbl.BackgroundTransparency = 1
        ptLbl.Text                   = cardData.power .. " / " .. cardData.toughness
        ptLbl.TextColor3             = T.textBright
        ptLbl.Font                   = Enum.Font.GothamBold
        ptLbl.TextSize               = 11
        ptLbl.Parent                 = ptBadge
    end

    -- Play button + hover (only when affordable / correct phase)
    if canPlay then
        onHover(card, T.cardBg, T.cardHover)

        local playBtn = mkButton(card, "▶  Play", T.btnGreen,
            UDim2.new(1, -8, 0, 18),
            UDim2.new(0.5, 0, 1, -22),
            UDim.new(0, 5)
        )
        playBtn.AnchorPoint = Vector2.new(0.5, 0)
        playBtn.TextSize    = 10
        playBtn.MouseButton1Click:Connect(function()
            matchClient.playCard(cardId)
        end)
        onHover(playBtn, T.btnGreen, T.btnGreenHover)
    end

    return card
end

-- ── BUILD A BATTLEFIELD CARD ───────────────────────────────────
local function buildFieldCard(creature, isMine, isAttacker, matchClient)
    -- element may not be in snapshot; fall back gracefully
    local elemCol   = ELEMENT_COLORS[creature.element] or ELEMENT_COLORS.Neutral
    local isDamaged = (creature.damageTaken or 0) > 0
    local W, H      = 75, 108

    local card = Instance.new("Frame")
    card.Name                   = "FC_" .. creature.instanceId
    card.Size                   = UDim2.new(0, W, 0, H)
    card.BackgroundColor3       = isAttacker and Color3.fromRGB(38, 14, 6) or T.cardBg
    card.BackgroundTransparency = 0.06
    card.BorderSizePixel        = 0
    mkCorner(card, T.sm)

    local borderCol = isAttacker   and T.atkHighlight
        or creature.tapped         and Color3.fromRGB(45, 48, 80)
        or elemCol
    mkStroke(card, borderCol, isAttacker and 2.5 or 1.5)

    -- Tapped = rotation cue
    if creature.tapped then card.Rotation = 13 end

    -- Element stripe (top)
    local stripe = Instance.new("Frame")
    stripe.Size                   = UDim2.new(1, 0, 0, 4)
    stripe.BackgroundColor3       = elemCol
    stripe.BackgroundTransparency = creature.tapped and 0.55 or 0
    stripe.BorderSizePixel        = 0
    mkCorner(stripe, UDim.new(0, 6))
    stripe.Parent                 = card

    -- Card name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Position               = UDim2.new(0, 3, 0, 7)
    nameLbl.Size                   = UDim2.new(1, -6, 0, 30)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = creature.name or creature.id
    nameLbl.TextColor3             = creature.tapped and T.textSub or T.textBright
    nameLbl.Font                   = Enum.Font.GothamBold
    nameLbl.TextSize               = 8
    nameLbl.TextWrapped            = true
    nameLbl.TextXAlignment         = Enum.TextXAlignment.Center
    nameLbl.Parent                 = card

    -- Status badge (ATTACKING / TAPPED)
    if isAttacker then
        local atkBadge = Instance.new("Frame")
        atkBadge.Position               = UDim2.new(0, 3, 0, 39)
        atkBadge.Size                   = UDim2.new(1, -6, 0, 16)
        atkBadge.BackgroundColor3       = T.atkHighlight
        atkBadge.BackgroundTransparency = 0.18
        atkBadge.BorderSizePixel        = 0
        mkCorner(atkBadge, UDim.new(0, 4))
        atkBadge.Parent                 = card

        local atkLbl = Instance.new("TextLabel")
        atkLbl.Size                   = UDim2.new(1, 0, 1, 0)
        atkLbl.BackgroundTransparency = 1
        atkLbl.Text                   = "⚔  ATTACKING"
        atkLbl.TextColor3             = Color3.fromRGB(255, 175, 90)
        atkLbl.Font                   = Enum.Font.GothamBold
        atkLbl.TextSize               = 8
        atkLbl.Parent                 = atkBadge
    elseif creature.tapped then
        local tappedLbl = Instance.new("TextLabel")
        tappedLbl.Position               = UDim2.new(0, 3, 0, 39)
        tappedLbl.Size                   = UDim2.new(1, -6, 0, 16)
        tappedLbl.BackgroundTransparency = 1
        tappedLbl.Text                   = "TAPPED"
        tappedLbl.TextColor3             = Color3.fromRGB(85, 88, 130)
        tappedLbl.Font                   = Enum.Font.GothamBold
        tappedLbl.TextSize               = 8
        tappedLbl.TextXAlignment         = Enum.TextXAlignment.Center
        tappedLbl.Parent                 = card
    end

    -- Keywords strip
    if creature.keywords and #creature.keywords > 0 then
        local kwLbl = Instance.new("TextLabel")
        kwLbl.AnchorPoint            = Vector2.new(0, 1)
        kwLbl.Position               = UDim2.new(0, 3, 1, -22)
        kwLbl.Size                   = UDim2.new(1, -6, 0, 12)
        kwLbl.BackgroundTransparency = 1
        kwLbl.Text                   = table.concat(creature.keywords, " · ")
        kwLbl.TextColor3             = T.mana
        kwLbl.Font                   = Enum.Font.Gotham
        kwLbl.TextSize               = 7
        kwLbl.TextWrapped            = true
        kwLbl.TextXAlignment         = Enum.TextXAlignment.Center
        kwLbl.Parent                 = card
    end

    -- P/T badge (bottom-right)
    local currentToughness = creature.toughness - (creature.damageTaken or 0)
    local ptBadge = Instance.new("Frame")
    ptBadge.AnchorPoint            = Vector2.new(1, 1)
    ptBadge.Position               = UDim2.new(1, -3, 1, -3)
    ptBadge.Size                   = UDim2.new(0, 46, 0, 18)
    ptBadge.BackgroundColor3       = isDamaged and Color3.fromRGB(55, 12, 12) or T.panelDark
    ptBadge.BackgroundTransparency = 0.12
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

    -- Attack / toggle button (your creatures during combat phase)
    if isMine and matchClient then
        onHover(card,
            isAttacker and Color3.fromRGB(38, 14, 6) or T.cardBg,
            T.cardHover
        )

        local atkBtn = mkButton(card,
            isAttacker and "⚔ Atk" or "Attack",
            isAttacker and T.btnAttack or Color3.fromRGB(45, 50, 90),
            UDim2.new(1, -6, 0, 18),
            UDim2.new(0.5, 0, 0, 57),
            UDim.new(0, 4)
        )
        atkBtn.AnchorPoint = Vector2.new(0.5, 0)
        atkBtn.TextSize    = 9
        atkBtn.MouseButton1Click:Connect(function()
            matchClient.declareAttacker(creature.instanceId)
        end)
        onHover(atkBtn,
            isAttacker and T.btnAttack or Color3.fromRGB(45, 50, 90),
            T.btnAttackHvr
        )
    end

    return card
end

-- ── UPDATE THE BOARD FROM A SNAPSHOT ──────────────────────────
function BattleUI.update(snapshot, matchClient)
    if not screenGui then return end

    -- ── Life ───────────────────────────────────────────────
    local myLife  = snapshot.myLife  or 20
    local oppLife = snapshot.oppLife or 20

    if myLifeLabel  then
        myLifeLabel.Text       = tostring(myLife)
        myLifeLabel.TextColor3 = myLife  <= 5 and T.danger or T.life
    end
    if oppLifeLabel then
        oppLifeLabel.Text       = tostring(oppLife)
        oppLifeLabel.TextColor3 = oppLife <= 5 and T.danger or T.life
    end

    -- ── Mana ───────────────────────────────────────────────
    if myManaLabel then
        myManaLabel.Text = (snapshot.myMana or 0) .. " / " .. (snapshot.myMaxMana or 0)
    end

    -- ── Phase / turn banner ────────────────────────────────
    if snapshot.winner then
        if turnLabel  then turnLabel.Text  = snapshot.winner == snapshot.myUserId and "🏆  VICTORY!" or "💀  DEFEAT" end
        if phaseLabel then phaseLabel.Text = "" end
        if endPhaseBtn then endPhaseBtn.Visible = false end
    elseif snapshot.isMyTurn then
        if turnLabel   then turnLabel.Text   = "YOUR TURN"  end
        if phaseLabel  then phaseLabel.Text  = "Phase: " .. (snapshot.phase or "?"):upper() end
        if endPhaseBtn then endPhaseBtn.Visible = true  end
        if phaseBanner then
            TweenService:Create(phaseBanner, TweenInfo.new(0.25), {
                BackgroundColor3 = Color3.fromRGB(12, 26, 16)
            }):Play()
        end
    else
        if turnLabel   then turnLabel.Text   = "OPPONENT'S TURN" end
        if phaseLabel  then phaseLabel.Text  = "Phase: " .. (snapshot.phase or "?"):upper() end
        if endPhaseBtn then endPhaseBtn.Visible = false end
        if phaseBanner then
            TweenService:Create(phaseBanner, TweenInfo.new(0.25), {
                BackgroundColor3 = Color3.fromRGB(22, 12, 18)
            }):Play()
        end
    end

    -- ── Opponent hand count ────────────────────────────────
    if oppHandCountLabel then
        oppHandCountLabel.Text = "Hand: " .. (snapshot.oppHandCount or 0) .. " cards"
    end

    -- ── Clear field frames (preserve TextLabel hints) ──────
    for _, child in ipairs(myFieldFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, child in ipairs(oppFieldFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, child in ipairs(handScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Show/hide empty-zone hints
    local myCount  = snapshot.myBattlefield  and #snapshot.myBattlefield  or 0
    local oppCount = snapshot.oppBattlefield and #snapshot.oppBattlefield or 0
    if myEmptyHint  then myEmptyHint.Visible  = myCount  == 0 end
    if oppEmptyHint then oppEmptyHint.Visible = oppCount == 0 end

    -- ── My battlefield ─────────────────────────────────────
    if snapshot.myBattlefield then
        local canAttack = snapshot.isMyTurn and snapshot.phase == "combat"
        for _, creature in ipairs(snapshot.myBattlefield) do
            local card = buildFieldCard(creature, true, false,
                canAttack and matchClient or nil)
            card.Parent = myFieldFrame
        end
    end

    -- ── Opponent battlefield ────────────────────────────────
    if snapshot.oppBattlefield then
        for _, creature in ipairs(snapshot.oppBattlefield) do
            local card = buildFieldCard(creature, false, false, nil)
            card.Parent = oppFieldFrame
        end
    end

    -- ── Hand ───────────────────────────────────────────────
    local canPlayCards = snapshot.isMyTurn and snapshot.phase == "main"
    if snapshot.myHand then
        local RS         = game:GetService("ReplicatedStorage")
        local Shared     = RS:WaitForChild("Shared", 5)
        local CardSystem = Shared and require(Shared:WaitForChild("CardSystem", 5))

        for _, cardId in ipairs(snapshot.myHand) do
            local cardData  = CardSystem and CardSystem.getCard(cardId)
            local affordable = cardData and snapshot.myMana >= cardData.manaCost
            local playable   = canPlayCards and affordable

            local cardFrame = buildHandCard(cardId, cardData, playable, matchClient)
            cardFrame.Parent = handScroll
        end
    end
end

-- ── MATCH RESULT ───────────────────────────────────────────────
function BattleUI.showResult(won)
    if not screenGui then return end

    -- Dimmer backdrop
    local dimmer = Instance.new("Frame")
    dimmer.Size                   = UDim2.new(1, 0, 1, 0)
    dimmer.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    dimmer.BackgroundTransparency = 0.5
    dimmer.BorderSizePixel        = 0
    dimmer.ZIndex                 = 18
    dimmer.Parent                 = screenGui

    -- Result card (centred floating panel)
    local resultCard = Instance.new("Frame")
    resultCard.AnchorPoint            = Vector2.new(0.5, 0.5)
    resultCard.Position               = UDim2.new(0.5, 0, 0.5, 0)
    resultCard.Size                   = UDim2.new(0, 380, 0, 0)   -- animated
    resultCard.BackgroundColor3       = T.panelDark
    resultCard.BackgroundTransparency = 0.08
    resultCard.BorderSizePixel        = 0
    resultCard.ZIndex                 = 19
    mkCorner(resultCard, T.lg)
    mkStroke(resultCard, won and T.gold or T.danger, 2.5)
    resultCard.Parent                 = screenGui

    -- Headline
    local headline = Instance.new("TextLabel")
    headline.AnchorPoint            = Vector2.new(0.5, 0.5)
    headline.Position               = UDim2.new(0.5, 0, 0.38, 0)
    headline.Size                   = UDim2.new(0.9, 0, 0, 64)
    headline.BackgroundTransparency = 1
    headline.Text                   = won and "🏆  VICTORY!" or "💀  DEFEAT"
    headline.TextColor3             = won and T.gold or T.danger
    headline.Font                   = Enum.Font.GothamBold
    headline.TextSize               = 40
    headline.ZIndex                 = 20
    headline.Parent                 = resultCard

    -- Sub-message
    local subMsg = Instance.new("TextLabel")
    subMsg.AnchorPoint            = Vector2.new(0.5, 0.5)
    subMsg.Position               = UDim2.new(0.5, 0, 0.62, 0)
    subMsg.Size                   = UDim2.new(0.88, 0, 0, 24)
    subMsg.BackgroundTransparency = 1
    subMsg.Text                   = won and "Well played, champion!" or "Better luck next time."
    subMsg.TextColor3             = T.textSub
    subMsg.Font                   = Enum.Font.Gotham
    subMsg.TextSize               = 14
    subMsg.ZIndex                 = 20
    subMsg.Parent                 = resultCard

    -- Back to lobby button
    local lobbyBtn = mkButton(resultCard,
        "Back to Lobby",
        won and T.btnGreen or T.btnBlue,
        UDim2.new(0, 160, 0, 40),
        UDim2.new(0.5, -80, 1, -56),
        T.sm
    )
    lobbyBtn.ZIndex = 20
    lobbyBtn.MouseButton1Click:Connect(function()
        BattleUI.close()
    end)
    onHover(lobbyBtn, won and T.btnGreen or T.btnBlue,
        won and T.btnGreenHover or Color3.fromRGB(55, 115, 210))

    -- Entrance animation — card expands from zero height
    TweenService:Create(resultCard,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 380, 0, 200) }
    ):Play()
end

-- ── ERROR / FEEDBACK TOAST ──────────────────────────────────────
function BattleUI.showError(text)
    if not screenGui then return end

    -- Start below visible area
    local toast = Instance.new("Frame")
    toast.AnchorPoint            = Vector2.new(0.5, 1)
    toast.Position               = UDim2.new(0.5, 0, 1, 50)
    toast.Size                   = UDim2.new(0, 360, 0, 40)
    toast.BackgroundColor3       = Color3.fromRGB(165, 38, 38)
    toast.BackgroundTransparency = 0.06
    toast.BorderSizePixel        = 0
    toast.ZIndex                 = 30
    mkCorner(toast, T.sm)
    mkStroke(toast, T.danger, 1.5)
    toast.Parent                 = screenGui

    local msg = Instance.new("TextLabel")
    msg.Size                   = UDim2.new(1, -16, 1, 0)
    msg.Position               = UDim2.new(0, 8, 0, 0)
    msg.BackgroundTransparency = 1
    msg.Text                   = "⚠  " .. text
    msg.TextColor3             = Color3.fromRGB(255, 255, 255)
    msg.Font                   = Enum.Font.Gotham
    msg.TextSize               = 13
    msg.TextWrapped            = true
    msg.ZIndex                 = 31
    msg.Parent                 = toast

    -- Slide up
    TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 1, -132)
    }):Play()

    -- Fade out after 2.5 s
    task.delay(2.5, function()
        TweenService:Create(toast, TweenInfo.new(0.3), {
            BackgroundTransparency = 1
        }):Play()
        task.delay(0.35, function()
            if toast and toast.Parent then toast:Destroy() end
        end)
    end)
end

-- ── CLOSE ──────────────────────────────────────────────────────
function BattleUI.close()
    if screenGui then
        screenGui:Destroy()
        -- Nil out all references so nothing lingers
        screenGui         = nil
        handScroll        = nil
        myFieldFrame      = nil
        oppFieldFrame     = nil
        myLifeLabel       = nil
        oppLifeLabel      = nil
        myManaLabel       = nil
        phaseLabel        = nil
        turnLabel         = nil
        phaseBanner       = nil
        endPhaseBtn       = nil
        oppHandCountLabel = nil
        myEmptyHint       = nil
        oppEmptyHint      = nil
    end
end

return BattleUI
