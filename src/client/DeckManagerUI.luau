--[[
    DeckManagerUI.luau
    Location: StarterPlayerScripts/Client/DeckManagerUI

    DECK MANAGER
    ============
    Full-screen card collection manager.
    Left panel  — your current deck (cards in deck, remove button)
    Right panel — full card browser (all cards, add button, element filters)

    Open via the M key (wired in DeckClient).
]]

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DeckManagerUI = {}

-- ══════════════════════════════════════════════════════════════
--  COLOURS
-- ══════════════════════════════════════════════════════════════
local C = {
    bg          = Color3.fromRGB(6,  6, 12),
    panelL      = Color3.fromRGB(10, 10, 20),
    panelR      = Color3.fromRGB(7,   7, 15),
    header      = Color3.fromRGB(10, 10, 22),
    cardBg      = Color3.fromRGB(16, 16, 30),
    cardHover   = Color3.fromRGB(24, 24, 44),
    cardBorder  = Color3.fromRGB(42, 42, 72),
    gold        = Color3.fromRGB(255, 210, 80),
    goldDim     = Color3.fromRGB(155, 120, 35),
    textBrt     = Color3.fromRGB(230, 230, 245),
    textSub     = Color3.fromRGB(130, 132, 162),
    addBtn      = Color3.fromRGB(45,  150,  80),
    addHover    = Color3.fromRGB(60,  180, 100),
    removeBtn   = Color3.fromRGB(165,  40,  40),
    removeHover = Color3.fromRGB(200,  58,  58),
    closeBtn    = Color3.fromRGB(140,  35,  35),
    filterOn    = Color3.fromRGB(65,  115, 210),
    filterOff   = Color3.fromRGB(22,  22,  40),
    separator   = Color3.fromRGB(28,  28,  50),
}

local ELEMENT_COLORS = {
    Fire    = Color3.fromRGB(220,  72, 22),
    Water   = Color3.fromRGB( 35, 120, 220),
    Earth   = Color3.fromRGB(130,  80, 28),
    Air     = Color3.fromRGB(145, 200, 255),
    Dark    = Color3.fromRGB(120,  40, 200),
    Light   = Color3.fromRGB(255, 225, 60),
    Neutral = Color3.fromRGB(140, 140, 162),
}

local RARITY_COLORS = {
    Common          = Color3.fromRGB(160, 160, 168),
    Uncommon        = Color3.fromRGB(60,  185,  90),
    Rare            = Color3.fromRGB(50,  118, 235),
    ["Mythic Rare"] = Color3.fromRGB(210,  88,  20),
}

-- ══════════════════════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════════════════════
local function mkCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 8)
    c.Parent = parent
    return c
end

local function mkStroke(parent, color, thick)
    local s = Instance.new("UIStroke")
    s.Color     = color or C.cardBorder
    s.Thickness = thick or 1.2
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

local function onHover(obj, n, h)
    obj.MouseEnter:Connect(function()
        TweenService:Create(obj, TweenInfo.new(0.1), { BackgroundColor3 = h }):Play()
    end)
    obj.MouseLeave:Connect(function()
        TweenService:Create(obj, TweenInfo.new(0.1), { BackgroundColor3 = n }):Play()
    end)
end

-- Small pill-badge (element, rarity, mana cost)
local function mkBadge(parent, text, bgColor)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(0, 0, 0, 18)
    f.AutomaticSize    = Enum.AutomaticSize.X
    f.BackgroundColor3 = bgColor
    f.BackgroundTransparency = 0.35
    f.BorderSizePixel  = 0
    mkCorner(f, UDim.new(0.5, 0))
    local t = Instance.new("TextLabel")
    t.Size                   = UDim2.new(0, 0, 1, 0)
    t.AutomaticSize          = Enum.AutomaticSize.X
    t.BackgroundTransparency = 1
    t.Text                   = text
    t.TextColor3             = Color3.fromRGB(255, 255, 255)
    t.Font                   = Enum.Font.GothamBold
    t.TextSize               = 9
    mkPad(t, 0, 0, 6, 6)
    t.Parent = f
    f.Parent = parent
    return f
end

-- Small icon button (+ or −)
local function mkIconBtn(parent, text, bgNorm, bgHover)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 28, 0, 24)
    btn.BackgroundColor3 = bgNorm
    btn.BackgroundTransparency = 0.08
    btn.BorderSizePixel  = 0
    btn.Text             = text
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 16
    btn.AutoButtonColor  = false
    mkCorner(btn, UDim.new(0, 6))
    onHover(btn, bgNorm, bgHover)
    btn.Parent = parent
    return btn
end

-- ══════════════════════════════════════════════════════════════
--  CARD ROW
-- ══════════════════════════════════════════════════════════════
local function buildCardRow(card, countInDeck, onAdd, onRemove, maxCopies)
    local elemColor   = ELEMENT_COLORS[card.element] or C.textSub
    local rarityColor = RARITY_COLORS[card.rarity]   or C.textSub

    local row = Instance.new("Frame")
    row.Name             = "CardRow_" .. card.id
    row.Size             = UDim2.new(1, 0, 0, 62)
    row.BackgroundColor3 = C.cardBg
    row.BackgroundTransparency = 0
    row.BorderSizePixel  = 0
    mkCorner(row)
    mkStroke(row, C.cardBorder, 1)

    -- Left element stripe
    local stripe = Instance.new("Frame")
    stripe.Size             = UDim2.new(0, 3, 1, 0)
    stripe.BackgroundColor3 = elemColor
    stripe.BorderSizePixel  = 0
    mkCorner(stripe, UDim.new(0, 8))
    stripe.Parent = row

    -- Art thumbnail
    local art = Instance.new("Frame")
    art.Name             = "Art"
    art.Position         = UDim2.new(0, 10, 0.5, -23)
    art.Size             = UDim2.new(0, 46, 0, 46)
    art.BackgroundColor3 = Color3.fromRGB(12, 12, 24)
    art.BorderSizePixel  = 0
    mkCorner(art, UDim.new(0, 6))
    mkStroke(art, elemColor, 1)

    if card.art and card.art:sub(1, 13) == "rbxassetid://" then
        local img = Instance.new("ImageLabel")
        img.Size                   = UDim2.new(1, 0, 1, 0)
        img.BackgroundTransparency = 1
        img.Image                  = card.art
        img.ScaleType              = Enum.ScaleType.Crop
        img.Parent                 = art
        mkCorner(img, UDim.new(0, 6))
    else
        -- Element abbreviation placeholder
        local artTxt = Instance.new("TextLabel")
        artTxt.Size                   = UDim2.new(1, 0, 1, 0)
        artTxt.BackgroundTransparency = 1
        artTxt.Text                   = card.element:sub(1, 2):upper()
        artTxt.TextColor3             = elemColor
        artTxt.Font                   = Enum.Font.GothamBold
        artTxt.TextSize               = 15
        artTxt.TextTransparency       = 0.15
        artTxt.Parent                 = art
    end
    art.Parent = row

    -- Info block (name, badges, description)
    local info = Instance.new("Frame")
    info.Position               = UDim2.new(0, 64, 0, 0)
    info.Size                   = UDim2.new(1, -178, 1, 0)
    info.BackgroundTransparency = 1
    info.Parent                 = row

    local infoLayout = Instance.new("UIListLayout")
    infoLayout.SortOrder = Enum.SortOrder.LayoutOrder
    infoLayout.Padding   = UDim.new(0, 3)
    infoLayout.Parent    = info
    mkPad(info, 10, 8, 0, 6)

    -- Card name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size             = UDim2.new(1, 0, 0, 16)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = card.name
    nameLbl.TextColor3       = C.textBrt
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 13
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.TextTruncate     = Enum.TextTruncate.AtEnd
    nameLbl.LayoutOrder      = 1
    nameLbl.Parent           = info

    -- Badge row
    local badgeRow = Instance.new("Frame")
    badgeRow.Size                   = UDim2.new(1, 0, 0, 18)
    badgeRow.BackgroundTransparency = 1
    badgeRow.LayoutOrder            = 2
    badgeRow.Parent                 = info

    local badgeLayout = Instance.new("UIListLayout")
    badgeLayout.FillDirection    = Enum.FillDirection.Horizontal
    badgeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    badgeLayout.Padding          = UDim.new(0, 4)
    badgeLayout.Parent           = badgeRow

    mkBadge(badgeRow, card.element,  elemColor)
    mkBadge(badgeRow, card.rarity,   rarityColor)
    mkBadge(badgeRow, "⚡ " .. card.manaCost, Color3.fromRGB(60, 80, 140))

    -- Description
    local descLbl = Instance.new("TextLabel")
    descLbl.Size             = UDim2.new(1, 0, 0, 13)
    descLbl.BackgroundTransparency = 1
    descLbl.Text             = card.description or ""
    descLbl.TextColor3       = C.textSub
    descLbl.Font             = Enum.Font.Gotham
    descLbl.TextSize         = 10
    descLbl.TextXAlignment   = Enum.TextXAlignment.Left
    descLbl.TextTruncate     = Enum.TextTruncate.AtEnd
    descLbl.LayoutOrder      = 3
    descLbl.Parent           = info

    -- Right side: stats + count + buttons
    local right = Instance.new("Frame")
    right.AnchorPoint            = Vector2.new(1, 0.5)
    right.Position               = UDim2.new(1, -8, 0.5, 0)
    right.Size                   = UDim2.new(0, 106, 0, 50)
    right.BackgroundTransparency = 1
    right.Parent                 = row

    local rightLayout = Instance.new("UIListLayout")
    rightLayout.SortOrder             = Enum.SortOrder.LayoutOrder
    rightLayout.HorizontalAlignment   = Enum.HorizontalAlignment.Right
    rightLayout.Padding               = UDim.new(0, 4)
    rightLayout.Parent                = right

    -- Stats label
    local statsLbl = Instance.new("TextLabel")
    statsLbl.Size             = UDim2.new(1, 0, 0, 14)
    statsLbl.BackgroundTransparency = 1
    statsLbl.TextColor3       = C.textSub
    statsLbl.Font             = Enum.Font.Gotham
    statsLbl.TextSize         = 11
    statsLbl.TextXAlignment   = Enum.TextXAlignment.Right
    statsLbl.LayoutOrder      = 1
    statsLbl.Parent           = right

    if card.cardType == "Creature" then
        local kwStr = (card.keywords and #card.keywords > 0)
            and "  " .. table.concat(card.keywords, " · ")
            or ""
        statsLbl.Text = string.format("⚔ %d / %d%s", card.power, card.toughness, kwStr)
    else
        statsLbl.Text      = card.cardType
        statsLbl.TextColor3 = elemColor
    end

    -- Count in deck
    local inDeck  = countInDeck or 0
    local countLbl = Instance.new("TextLabel")
    countLbl.Name            = "CountLabel"
    countLbl.Size            = UDim2.new(1, 0, 0, 12)
    countLbl.BackgroundTransparency = 1
    countLbl.Text            = "In deck: " .. inDeck .. " / " .. (maxCopies or 2)
    countLbl.TextColor3      = inDeck > 0 and C.addBtn or C.textSub
    countLbl.Font            = Enum.Font.Gotham
    countLbl.TextSize        = 10
    countLbl.TextXAlignment  = Enum.TextXAlignment.Right
    countLbl.LayoutOrder     = 2
    countLbl.Parent          = right

    -- Button row
    local btnRow = Instance.new("Frame")
    btnRow.Size              = UDim2.new(1, 0, 0, 24)
    btnRow.BackgroundTransparency = 1
    btnRow.LayoutOrder       = 3
    btnRow.Parent            = right

    local btnLayout = Instance.new("UIListLayout")
    btnLayout.FillDirection        = Enum.FillDirection.Horizontal
    btnLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Right
    btnLayout.VerticalAlignment    = Enum.VerticalAlignment.Center
    btnLayout.Padding              = UDim.new(0, 4)
    btnLayout.Parent               = btnRow

    if onRemove then
        local removeBtn = mkIconBtn(btnRow, "−", C.removeBtn, C.removeHover)
        removeBtn.MouseButton1Click:Connect(function() onRemove(card.id) end)
    end

    if onAdd then
        local addBtn = mkIconBtn(btnRow, "+", C.addBtn, C.addHover)
        addBtn.MouseButton1Click:Connect(function() onAdd(card.id) end)
    end

    -- Row hover
    onHover(row, C.cardBg, C.cardHover)

    return row
end

-- ══════════════════════════════════════════════════════════════
--  OPEN
-- ══════════════════════════════════════════════════════════════
function DeckManagerUI.open(deckData, allCards, onAdd, onRemove)
    -- Toggle: if already open, close it
    if playerGui:FindFirstChild("DeckManagerScreen") then
        playerGui.DeckManagerScreen:Destroy()
        return
    end

    local MAX_COPIES = 2
    local MAX_CARDS  = 20

    local function countInDeck(cards, cardId)
        local n = 0
        for _, id in ipairs(cards) do
            if id == cardId then n += 1 end
        end
        return n
    end

    -- ── SCREEN GUI ────────────────────────────────────────────
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "DeckManagerScreen"
    screenGui.ResetOnSpawn   = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder   = 8
    screenGui.Parent         = playerGui

    -- Main panel
    local main = Instance.new("Frame")
    main.Name             = "Main"
    main.AnchorPoint      = Vector2.new(0.5, 0.5)
    main.Position         = UDim2.new(0.5, 0, -0.6, 0)   -- off-screen; slides in
    main.Size             = UDim2.new(0.96, 0, 0.93, 0)
    main.BackgroundColor3 = C.bg
    main.BorderSizePixel  = 0
    mkCorner(main, UDim.new(0, 14))
    mkStroke(main, Color3.fromRGB(55, 55, 90), 1.5)
    main.Parent = screenGui

    TweenService:Create(main,
        TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.5, 0) }
    ):Play()

    -- ── HEADER ────────────────────────────────────────────────
    local header = Instance.new("Frame")
    header.Name             = "Header"
    header.Size             = UDim2.new(1, 0, 0, 54)
    header.BackgroundColor3 = C.header
    header.BorderSizePixel  = 0
    header.Parent           = main
    mkCorner(header, UDim.new(0, 14))
    -- square off the bottom corners
    local hFix = Instance.new("Frame")
    hFix.Size             = UDim2.new(1, 0, 0, 14)
    hFix.Position         = UDim2.new(0, 0, 1, -14)
    hFix.BackgroundColor3 = C.header
    hFix.BorderSizePixel  = 0
    hFix.Parent           = header

    -- Gold left accent bar inside header
    local accentBar = Instance.new("Frame")
    accentBar.Position         = UDim2.new(0, 0, 0, 10)
    accentBar.Size             = UDim2.new(0, 3, 1, -20)
    accentBar.BackgroundColor3 = C.gold
    accentBar.BackgroundTransparency = 0.3
    accentBar.BorderSizePixel  = 0
    mkCorner(accentBar, UDim.new(0.5, 0))
    accentBar.Parent           = header

    local titleLbl = Instance.new("TextLabel")
    titleLbl.AnchorPoint      = Vector2.new(0, 0.5)
    titleLbl.Position         = UDim2.new(0, 20, 0.5, 0)
    titleLbl.Size             = UDim2.new(0, 240, 0, 28)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text             = "DECK  MANAGER"
    titleLbl.TextColor3       = C.gold
    titleLbl.Font             = Enum.Font.GothamBold
    titleLbl.TextSize         = 19
    titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
    titleLbl.Parent           = header

    local deckCountLbl = Instance.new("TextLabel")
    deckCountLbl.Name         = "DeckCount"
    deckCountLbl.AnchorPoint  = Vector2.new(0.5, 0.5)
    deckCountLbl.Position     = UDim2.new(0.5, 0, 0.5, 0)
    deckCountLbl.Size         = UDim2.new(0, 200, 0, 24)
    deckCountLbl.BackgroundTransparency = 1
    deckCountLbl.Text         = "Cards: " .. #deckData.cards .. " / " .. MAX_CARDS
    deckCountLbl.TextColor3   = C.textSub
    deckCountLbl.Font         = Enum.Font.Gotham
    deckCountLbl.TextSize     = 13
    deckCountLbl.Parent       = header

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.AnchorPoint      = Vector2.new(1, 0.5)
    closeBtn.Position         = UDim2.new(1, -14, 0.5, 0)
    closeBtn.Size             = UDim2.new(0, 82, 0, 32)
    closeBtn.BackgroundColor3 = C.closeBtn
    closeBtn.BackgroundTransparency = 0.08
    closeBtn.BorderSizePixel  = 0
    closeBtn.Text             = "✕  Close"
    closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.TextSize         = 13
    closeBtn.AutoButtonColor  = false
    mkCorner(closeBtn, UDim.new(0, 8))
    closeBtn.Parent = header

    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 1.5, 0)
        }):Play()
        task.delay(0.24, function() screenGui:Destroy() end)
    end)

    -- ── BODY ──────────────────────────────────────────────────
    local body = Instance.new("Frame")
    body.Position               = UDim2.new(0, 0, 0, 54)
    body.Size                   = UDim2.new(1, 0, 1, -54)
    body.BackgroundTransparency = 1
    body.Parent                 = main

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.FillDirection = Enum.FillDirection.Horizontal
    bodyLayout.Padding       = UDim.new(0, 1)
    bodyLayout.Parent        = body

    -- ── LEFT PANEL (Your Deck) ─────────────────────────────────
    local leftPanel = Instance.new("Frame")
    leftPanel.Name             = "LeftPanel"
    leftPanel.Size             = UDim2.new(0.40, 0, 1, 0)
    leftPanel.BackgroundColor3 = C.panelL
    leftPanel.BorderSizePixel  = 0
    leftPanel.Parent           = body

    -- Left panel sub-header
    local lHead = Instance.new("Frame")
    lHead.Size             = UDim2.new(1, 0, 0, 40)
    lHead.BackgroundColor3 = Color3.fromRGB(12, 12, 24)
    lHead.BorderSizePixel  = 0
    lHead.Parent           = leftPanel
    mkPad(lHead, 0, 0, 16, 12)

    local lHeadLayout = Instance.new("UIListLayout")
    lHeadLayout.FillDirection     = Enum.FillDirection.Horizontal
    lHeadLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    lHeadLayout.Padding           = UDim.new(0, 8)
    lHeadLayout.Parent            = lHead

    -- Colour dot
    local lDot = Instance.new("Frame")
    lDot.Size             = UDim2.new(0, 8, 0, 8)
    lDot.BackgroundColor3 = C.gold
    lDot.BackgroundTransparency = 0.2
    lDot.BorderSizePixel  = 0
    mkCorner(lDot, UDim.new(0.5, 0))
    lDot.Parent = lHead

    local lTitle = Instance.new("TextLabel")
    lTitle.Size             = UDim2.new(0, 120, 1, 0)
    lTitle.BackgroundTransparency = 1
    lTitle.Text             = "Your Deck"
    lTitle.TextColor3       = C.gold
    lTitle.Font             = Enum.Font.GothamBold
    lTitle.TextSize         = 14
    lTitle.TextXAlignment   = Enum.TextXAlignment.Left
    lTitle.Parent           = lHead

    -- Divider
    local lDivider = Instance.new("Frame")
    lDivider.Position         = UDim2.new(0, 0, 0, 40)
    lDivider.Size             = UDim2.new(1, 0, 0, 1)
    lDivider.BackgroundColor3 = C.separator
    lDivider.BorderSizePixel  = 0
    lDivider.Parent           = leftPanel

    -- Deck scroll
    local deckScroll = Instance.new("ScrollingFrame")
    deckScroll.Name                  = "DeckScroll"
    deckScroll.Position              = UDim2.new(0, 0, 0, 41)
    deckScroll.Size                  = UDim2.new(1, 0, 1, -41)
    deckScroll.BackgroundTransparency = 1
    deckScroll.BorderSizePixel       = 0
    deckScroll.ScrollBarThickness    = 4
    deckScroll.ScrollBarImageColor3  = Color3.fromRGB(60, 60, 100)
    deckScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    deckScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
    deckScroll.Parent                = leftPanel
    mkPad(deckScroll, 6, 8, 8, 8)

    local deckLayout = Instance.new("UIListLayout")
    deckLayout.SortOrder = Enum.SortOrder.LayoutOrder
    deckLayout.Padding   = UDim.new(0, 5)
    deckLayout.Parent    = deckScroll

    -- ── RIGHT PANEL (All Cards Browser) ───────────────────────
    local rightPanel = Instance.new("Frame")
    rightPanel.Name             = "RightPanel"
    rightPanel.Size             = UDim2.new(0.60, 0, 1, 0)
    rightPanel.BackgroundColor3 = C.panelR
    rightPanel.BorderSizePixel  = 0
    rightPanel.Parent           = body

    -- Right panel sub-header with filter buttons
    local rHead = Instance.new("Frame")
    rHead.Name             = "FilterBar"
    rHead.Size             = UDim2.new(1, 0, 0, 44)
    rHead.BackgroundColor3 = Color3.fromRGB(8, 8, 18)
    rHead.BorderSizePixel  = 0
    rHead.Parent           = rightPanel
    mkPad(rHead, 8, 6, 12, 12)

    local rHeadLayout = Instance.new("UIListLayout")
    rHeadLayout.FillDirection    = Enum.FillDirection.Horizontal
    rHeadLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rHeadLayout.Padding          = UDim.new(0, 6)
    rHeadLayout.Parent           = rHead

    local filterLbl = Instance.new("TextLabel")
    filterLbl.Size             = UDim2.new(0, 46, 1, -8)
    filterLbl.BackgroundTransparency = 1
    filterLbl.Text             = "Filter:"
    filterLbl.TextColor3       = C.textSub
    filterLbl.Font             = Enum.Font.Gotham
    filterLbl.TextSize         = 11
    filterLbl.TextXAlignment   = Enum.TextXAlignment.Left
    filterLbl.Parent           = rHead

    -- Divider
    local rDivider = Instance.new("Frame")
    rDivider.Position         = UDim2.new(0, 0, 0, 44)
    rDivider.Size             = UDim2.new(1, 0, 0, 1)
    rDivider.BackgroundColor3 = C.separator
    rDivider.BorderSizePixel  = 0
    rDivider.Parent           = rightPanel

    -- All-cards scroll
    local allScroll = Instance.new("ScrollingFrame")
    allScroll.Name                   = "AllCardsScroll"
    allScroll.Position               = UDim2.new(0, 0, 0, 45)
    allScroll.Size                   = UDim2.new(1, 0, 1, -45)
    allScroll.BackgroundTransparency = 1
    allScroll.BorderSizePixel        = 0
    allScroll.ScrollBarThickness     = 4
    allScroll.ScrollBarImageColor3   = Color3.fromRGB(60, 60, 100)
    allScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    allScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    allScroll.Parent                 = rightPanel
    mkPad(allScroll, 6, 8, 8, 8)

    local allLayout = Instance.new("UIListLayout")
    allLayout.SortOrder = Enum.SortOrder.LayoutOrder
    allLayout.Padding   = UDim.new(0, 5)
    allLayout.Parent    = allScroll

    -- ══════════════════════════════════════════════════════════
    --  POPULATE
    -- ══════════════════════════════════════════════════════════
    local activeFilter = "All"

    local function refreshDeck()
        for _, child in ipairs(deckScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local counts, seen = {}, {}
        for _, id in ipairs(deckData.cards) do
            counts[id] = (counts[id] or 0) + 1
        end

        local order = 1
        for _, cardId in ipairs(deckData.cards) do
            if not seen[cardId] then
                seen[cardId] = true
                local card = allCards[cardId]
                if card then
                    local row = buildCardRow(card, counts[cardId], nil, function(id)
                        onRemove(id)
                        for i = #deckData.cards, 1, -1 do
                            if deckData.cards[i] == id then
                                table.remove(deckData.cards, i); break
                            end
                        end
                        deckCountLbl.Text = "Cards: " .. #deckData.cards .. " / " .. MAX_CARDS
                        refreshDeck()
                    end, MAX_COPIES)
                    row.LayoutOrder = order; order += 1
                    row.Parent = deckScroll
                end
            end
        end

        if #deckData.cards == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size             = UDim2.new(1, 0, 0, 50)
            empty.BackgroundTransparency = 1
            empty.Text             = "Your deck is empty.\nAdd cards from the browser →"
            empty.TextColor3       = C.textSub
            empty.Font             = Enum.Font.Gotham
            empty.TextSize         = 12
            empty.TextWrapped      = true
            empty.TextXAlignment   = Enum.TextXAlignment.Center
            empty.Parent           = deckScroll
        end
    end

    local function refreshBrowser(filterElem)
        for _, child in ipairs(allScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local sorted = {}
        for _, card in pairs(allCards) do
            if filterElem == "All" or card.element == filterElem then
                table.insert(sorted, card)
            end
        end
        table.sort(sorted, function(a, b)
            if a.element ~= b.element then return a.element < b.element end
            return (a.manaCost or 0) < (b.manaCost or 0)
        end)

        for i, card in ipairs(sorted) do
            local inDeck = countInDeck(deckData.cards, card.id)
            local row = buildCardRow(card, inDeck, function(id)
                if #deckData.cards >= MAX_CARDS then return end
                if countInDeck(deckData.cards, id) >= MAX_COPIES then return end
                onAdd(id)
                table.insert(deckData.cards, id)
                deckCountLbl.Text = "Cards: " .. #deckData.cards .. " / " .. MAX_CARDS
                refreshDeck()
                refreshBrowser(activeFilter)
            end, nil, MAX_COPIES)
            row.LayoutOrder = i
            row.Parent = allScroll
        end
    end

    -- Filter buttons
    local elements = { "All", "Fire", "Water", "Earth", "Air", "Dark", "Light" }
    for _, el in ipairs(elements) do
        local isAll = (el == "All")
        local fBtn = Instance.new("TextButton")
        fBtn.Size             = UDim2.new(0, 0, 1, -10)
        fBtn.AutomaticSize    = Enum.AutomaticSize.X
        fBtn.BackgroundColor3 = isAll and C.filterOn or C.filterOff
        fBtn.BackgroundTransparency = 0.1
        fBtn.BorderSizePixel  = 0
        fBtn.Text             = el
        fBtn.TextColor3       = Color3.fromRGB(220, 220, 235)
        fBtn.Font             = Enum.Font.Gotham
        fBtn.TextSize         = 11
        fBtn.AutoButtonColor  = false
        mkCorner(fBtn, UDim.new(0.5, 0))
        mkPad(fBtn, 0, 0, 8, 8)
        fBtn.Parent = rHead

        fBtn.MouseButton1Click:Connect(function()
            activeFilter = el
            for _, child in ipairs(rHead:GetChildren()) do
                if child:IsA("TextButton") then
                    TweenService:Create(child, TweenInfo.new(0.1), {
                        BackgroundColor3 = C.filterOff
                    }):Play()
                end
            end
            TweenService:Create(fBtn, TweenInfo.new(0.1), {
                BackgroundColor3 = C.filterOn
            }):Play()
            refreshBrowser(el)
        end)
    end

    -- Initial render
    refreshDeck()
    refreshBrowser("All")

    return screenGui
end

-- ══════════════════════════════════════════════════════════════
function DeckManagerUI.close()
    local gui = playerGui:FindFirstChild("DeckManagerScreen")
    if gui then gui:Destroy() end
end

return DeckManagerUI
