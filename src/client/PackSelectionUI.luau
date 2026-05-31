--[[
    PackSelectionUI.luau
    Location: StarterPlayerScripts/Client/PackSelectionUI

    ANIME PACK SELECTION SCREEN
    ===========================
    Each anime is displayed as a physical card-pack box (portrait box art,
    series header, card count, select button). Inspired by the Yu-Gi-Oh
    Deck Build Pack visual style.

    ── HOW TO ADD YOUR COVER ART ──────────────────────────────────
    1. In Roblox Studio open the Toolbox → My Decals (or Image Manager).
    2. Upload each anime's cover image.
    3. Copy the asset ID number (the long number after "rbxassetid://").
    4. Paste each one into the PACK_DECALS table below.
    ────────────────────────────────────────────────────────────────
]]

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PackSelectionUI = {}

-- ══════════════════════════════════════════════════════════════
--  PACK DECAL IDs  ← PASTE YOUR ASSET IDs HERE
-- ══════════════════════════════════════════════════════════════
local PACK_DECALS = {
    starter  = "rbxassetid://0",   -- ← replace with Starter cover art ID
    onepiece = "rbxassetid://0",   -- ← replace with One Piece cover art ID
    bleach   = "rbxassetid://0",   -- ← replace with Bleach cover art ID
    naruto   = "rbxassetid://0",   -- ← replace with Naruto cover art ID
    dbz      = "rbxassetid://0",   -- ← replace with Dragon Ball Z cover art ID
}

-- ══════════════════════════════════════════════════════════════
--  PER-PACK VISUAL THEMES
-- ══════════════════════════════════════════════════════════════
local PACK_THEMES = {
    starter  = {
        primary   = Color3.fromRGB(155, 115,  25),   -- antique gold
        glow      = Color3.fromRGB(255, 215,  90),   -- bright gold
        headerBg  = Color3.fromRGB(130,  95,  18),
        label     = "STARTER  SET",
        btnText   = "Open Starter Set",
    },
    onepiece = {
        primary   = Color3.fromRGB(195,  25,  25),   -- Straw Hat red
        glow      = Color3.fromRGB(255, 200,  50),   -- treasure gold
        headerBg  = Color3.fromRGB(160,  18,  18),
        label     = "ONE  PIECE",
        btnText   = "Set Sail",
    },
    bleach   = {
        primary   = Color3.fromRGB(160,   8,   8),   -- Shinigami blood red
        glow      = Color3.fromRGB(210, 220, 245),   -- spirit white
        headerBg  = Color3.fromRGB(120,   5,   5),
        label     = "BLEACH",
        btnText   = "Release Zanpakutō",
    },
    naruto   = {
        primary   = Color3.fromRGB(215,  85,   0),   -- Naruto orange
        glow      = Color3.fromRGB(140, 110, 255),   -- chakra purple
        headerBg  = Color3.fromRGB(175,  65,   0),
        label     = "NARUTO",
        btnText   = "Believe It!",
    },
    dbz      = {
        primary   = Color3.fromRGB(230, 130,   0),   -- Super Saiyan gold
        glow      = Color3.fromRGB(255, 235,  55),   -- ki yellow
        headerBg  = Color3.fromRGB(190, 105,   0),
        label     = "DRAGON  BALL  Z",
        btnText   = "Power Up!",
    },
}

-- ══════════════════════════════════════════════════════════════
--  COLOURS
-- ══════════════════════════════════════════════════════════════
local C = {
    bg        = Color3.fromRGB(5,  5, 10),
    boxDark   = Color3.fromRGB(9,  9, 18),
    gold      = Color3.fromRGB(255, 215, 90),
    textBrt   = Color3.fromRGB(240, 240, 255),
    textSub   = Color3.fromRGB(140, 143, 170),
    infoBg    = Color3.fromRGB(7,   7, 15),
}

-- ══════════════════════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════════════════════
local function mkCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 10)
    c.Parent = parent
    return c
end

local function mkStroke(parent, color, thick)
    local s = Instance.new("UIStroke")
    s.Color     = color
    s.Thickness = thick or 2
    s.Parent    = parent
    return s
end

local function squareFix(parent, bg)
    -- Covers rounded corners on one side of a frame to make them square.
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, 14)
    f.BackgroundColor3 = bg
    f.BorderSizePixel  = 0
    f.Parent           = parent
    return f
end

-- ══════════════════════════════════════════════════════════════
--  BUILD A SINGLE PACK BOX
-- ══════════════════════════════════════════════════════════════
local function buildPackBox(pack, onSelect)
    local theme  = PACK_THEMES[pack.id] or PACK_THEMES.starter
    local decal  = PACK_DECALS[pack.id] or "rbxassetid://0"
    local hasArt = (decal ~= "rbxassetid://0") and (#decal > 15)

    -- ── SLOT (managed by UIListLayout) ───────────────────────
    -- Has extra top space so the box can animate upward without clipping.
    local slot = Instance.new("Frame")
    slot.Name                   = "Slot_" .. pack.id
    slot.Size                   = UDim2.new(0, 192, 1, 0)
    slot.BackgroundTransparency = 1
    slot.BorderSizePixel        = 0
    -- slot is the layout child; the visual box lives inside it

    -- ── VISUAL BOX (inside slot, tweened on hover) ────────────
    local box = Instance.new("Frame")
    box.Name                   = "Box"
    box.Position               = UDim2.new(0, 0, 0, 14)   -- 14px gap at top for lift room
    box.Size                   = UDim2.new(1, 0, 1, -14)
    box.BackgroundColor3       = C.boxDark
    box.BackgroundTransparency = 0
    box.BorderSizePixel        = 0
    box.ClipsDescendants       = true
    box.Parent                 = slot
    mkCorner(box, UDim.new(0, 12))
    local boxStroke = mkStroke(box, theme.primary, 2)

    -- ── SERIES HEADER BAR (top of box) ───────────────────────
    local header = Instance.new("Frame")
    header.Size             = UDim2.new(1, 0, 0, 44)
    header.BackgroundColor3 = theme.headerBg
    header.BorderSizePixel  = 0
    header.ClipsDescendants = false
    header.Parent           = box
    mkCorner(header, UDim.new(0, 12))
    -- square off the bottom corners of the header bar
    local hFix = squareFix(header, theme.headerBg)
    hFix.Position = UDim2.new(0, 0, 1, -14)

    local seriesLbl = Instance.new("TextLabel")
    seriesLbl.Size                   = UDim2.new(1, 0, 1, 0)
    seriesLbl.BackgroundTransparency = 1
    seriesLbl.Text                   = theme.label
    seriesLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
    seriesLbl.Font                   = Enum.Font.GothamBold
    seriesLbl.TextSize               = 11
    seriesLbl.TextXAlignment         = Enum.TextXAlignment.Center
    seriesLbl.TextScaled             = false
    seriesLbl.Parent                 = header

    -- Thin gold accent line under header
    local accentLine = Instance.new("Frame")
    accentLine.Position       = UDim2.new(0, 0, 1, 0)
    accentLine.Size           = UDim2.new(1, 0, 0, 2)
    accentLine.BackgroundColor3 = theme.glow
    accentLine.BackgroundTransparency = 0.3
    accentLine.BorderSizePixel = 0
    accentLine.Parent         = header

    -- ── ART AREA (middle) ─────────────────────────────────────
    local artFrame = Instance.new("Frame")
    artFrame.Position               = UDim2.new(0, 0, 0, 46)
    artFrame.Size                   = UDim2.new(1, 0, 1, -170)   -- art fills middle
    artFrame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    artFrame.BackgroundTransparency = 0
    artFrame.BorderSizePixel        = 0
    artFrame.ClipsDescendants       = true
    artFrame.Parent                 = box

    if hasArt then
        -- Real cover art from Roblox decal
        local img = Instance.new("ImageLabel")
        img.Size                   = UDim2.new(1, 0, 1, 0)
        img.BackgroundTransparency = 1
        img.Image                  = decal
        img.ScaleType              = Enum.ScaleType.Crop
        img.Parent                 = artFrame
    else
        -- Styled placeholder (removed once you add the decal IDs)
        local placeholderBg = Instance.new("Frame")
        placeholderBg.Size                   = UDim2.new(1, 0, 1, 0)
        placeholderBg.BackgroundColor3       = theme.primary
        placeholderBg.BackgroundTransparency = 0.85
        placeholderBg.BorderSizePixel        = 0
        placeholderBg.Parent                 = artFrame

        local placeholderText = Instance.new("TextLabel")
        placeholderText.Size                   = UDim2.new(1, -16, 1, 0)
        placeholderText.Position               = UDim2.new(0, 8, 0, 0)
        placeholderText.BackgroundTransparency = 1
        placeholderText.Text                   = pack.name .. "\n\n" .. "[ Add Cover Art ]"
        placeholderText.TextColor3             = theme.glow
        placeholderText.Font                   = Enum.Font.GothamBold
        placeholderText.TextSize               = 14
        placeholderText.TextTransparency       = 0.15
        placeholderText.TextXAlignment         = Enum.TextXAlignment.Center
        placeholderText.TextWrapped            = true
        placeholderText.Parent                 = artFrame
    end

    -- Subtle gradient fade at the bottom of the art into the info section
    local artFade = Instance.new("Frame")
    artFade.AnchorPoint            = Vector2.new(0, 1)
    artFade.Position               = UDim2.new(0, 0, 1, 0)
    artFade.Size                   = UDim2.new(1, 0, 0, 40)
    artFade.BackgroundColor3       = C.infoBg
    artFade.BackgroundTransparency = 0.25
    artFade.BorderSizePixel        = 0
    artFade.Parent                 = artFrame

    -- ── BOTTOM INFO SECTION ───────────────────────────────────
    local info = Instance.new("Frame")
    info.AnchorPoint            = Vector2.new(0, 1)
    info.Position               = UDim2.new(0, 0, 1, 0)
    info.Size                   = UDim2.new(1, 0, 0, 124)
    info.BackgroundColor3       = C.infoBg
    info.BackgroundTransparency = 0
    info.BorderSizePixel        = 0
    info.ClipsDescendants       = false
    info.Parent                 = box
    mkCorner(info, UDim.new(0, 12))
    -- square off the top corners of the info section
    local iFix = squareFix(info, C.infoBg)
    iFix.Position = UDim2.new(0, 0, 0, 0)

    -- Thin top separator line on info section
    local infoLine = Instance.new("Frame")
    infoLine.Position               = UDim2.new(0, 0, 0, 0)
    infoLine.Size                   = UDim2.new(1, 0, 0, 1)
    infoLine.BackgroundColor3       = theme.primary
    infoLine.BackgroundTransparency = 0.4
    infoLine.BorderSizePixel        = 0
    infoLine.Parent                 = info

    -- Pack name
    local packNameLbl = Instance.new("TextLabel")
    packNameLbl.Position               = UDim2.new(0, 10, 0, 10)
    packNameLbl.Size                   = UDim2.new(1, -20, 0, 19)
    packNameLbl.BackgroundTransparency = 1
    packNameLbl.Text                   = pack.name
    packNameLbl.TextColor3             = C.gold
    packNameLbl.Font                   = Enum.Font.GothamBold
    packNameLbl.TextSize               = 13
    packNameLbl.TextXAlignment         = Enum.TextXAlignment.Center
    packNameLbl.TextTruncate           = Enum.TextTruncate.AtEnd
    packNameLbl.Parent                 = info

    -- Description line
    local descLbl = Instance.new("TextLabel")
    descLbl.Position               = UDim2.new(0, 10, 0, 32)
    descLbl.Size                   = UDim2.new(1, -20, 0, 24)
    descLbl.BackgroundTransparency = 1
    descLbl.Text                   = pack.description or ""
    descLbl.TextColor3             = C.textSub
    descLbl.Font                   = Enum.Font.Gotham
    descLbl.TextSize               = 10
    descLbl.TextXAlignment         = Enum.TextXAlignment.Center
    descLbl.TextWrapped            = true
    descLbl.Parent                 = info

    -- Card count badge
    local countBadge = Instance.new("Frame")
    countBadge.AnchorPoint            = Vector2.new(0.5, 0)
    countBadge.Position               = UDim2.new(0.5, 0, 0, 58)
    countBadge.Size                   = UDim2.new(0, 0, 0, 18)
    countBadge.AutomaticSize          = Enum.AutomaticSize.X
    countBadge.BackgroundColor3       = theme.primary
    countBadge.BackgroundTransparency = 0.65
    countBadge.BorderSizePixel        = 0
    mkCorner(countBadge, UDim.new(0.5, 0))
    countBadge.Parent                 = info

    local countLbl = Instance.new("TextLabel")
    countLbl.Size                   = UDim2.new(0, 0, 1, 0)
    countLbl.AutomaticSize          = Enum.AutomaticSize.X
    countLbl.BackgroundTransparency = 1
    countLbl.Text                   = "  " .. #pack.starterDeck .. " Starter Cards  "
    countLbl.TextColor3             = theme.glow
    countLbl.Font                   = Enum.Font.GothamBold
    countLbl.TextSize               = 10
    countLbl.Parent                 = countBadge

    -- SELECT PACK button
    local selectBtn = Instance.new("TextButton")
    selectBtn.Position               = UDim2.new(0, 10, 0, 82)
    selectBtn.Size                   = UDim2.new(1, -20, 0, 36)
    selectBtn.BackgroundColor3       = theme.primary
    selectBtn.BackgroundTransparency = 0.05
    selectBtn.BorderSizePixel        = 0
    selectBtn.Text                   = theme.btnText
    selectBtn.TextColor3             = Color3.fromRGB(255, 255, 255)
    selectBtn.Font                   = Enum.Font.GothamBold
    selectBtn.TextSize               = 12
    selectBtn.AutoButtonColor        = false
    mkCorner(selectBtn, UDim.new(0, 8))
    mkStroke(selectBtn, theme.glow, 0)   -- stroke used for glow effect (starts invisible)
    selectBtn.Parent                 = info

    -- ── HOVER / SELECT ANIMATIONS ─────────────────────────────
    -- box lifts up (tweens its Position.Y.Offset from 14 → 0)
    -- stroke brightens and thickens

    slot.MouseEnter:Connect(function()
        TweenService:Create(box, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
        TweenService:Create(boxStroke, TweenInfo.new(0.18), {
            Color = theme.glow, Thickness = 3
        }):Play()
        TweenService:Create(selectBtn, TweenInfo.new(0.14), {
            BackgroundTransparency = 0,
            BackgroundColor3       = theme.glow
        }):Play()
    end)

    slot.MouseLeave:Connect(function()
        TweenService:Create(box, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 14)
        }):Play()
        TweenService:Create(boxStroke, TweenInfo.new(0.18), {
            Color = theme.primary, Thickness = 2
        }):Play()
        TweenService:Create(selectBtn, TweenInfo.new(0.14), {
            BackgroundTransparency = 0.05,
            BackgroundColor3       = theme.primary
        }):Play()
    end)

    -- Click: white flash → close
    selectBtn.MouseButton1Click:Connect(function()
        -- Brief white flash on the box
        TweenService:Create(boxStroke, TweenInfo.new(0.06), {
            Color = Color3.fromRGB(255, 255, 255), Thickness = 5
        }):Play()
        task.delay(0.12, function()
            onSelect(pack.id)
        end)
    end)

    return slot
end

-- ══════════════════════════════════════════════════════════════
--  OPEN THE SCREEN
-- ══════════════════════════════════════════════════════════════
function PackSelectionUI.open(allPacks, packOrder, onPackSelected)
    if playerGui:FindFirstChild("PackSelectionScreen") then return end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "PackSelectionScreen"
    screenGui.ResetOnSpawn   = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder   = 10
    screenGui.Parent         = playerGui

    -- ── FULL DARK BACKGROUND ─────────────────────────────────
    local bg = Instance.new("Frame")
    bg.Name                   = "Bg"
    bg.Size                   = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3       = C.bg
    bg.BackgroundTransparency = 1   -- will fade in
    bg.BorderSizePixel        = 0
    bg.Parent                 = screenGui

    -- Subtle vignette (dark radial edge — faked with a semi-transparent black frame)
    local vignette = Instance.new("Frame")
    vignette.Size                   = UDim2.new(1, 0, 1, 0)
    vignette.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    vignette.BackgroundTransparency = 0.55
    vignette.BorderSizePixel        = 0
    vignette.Parent                 = bg

    -- ── HEADER ───────────────────────────────────────────────
    local headerFrame = Instance.new("Frame")
    headerFrame.Size                   = UDim2.new(1, 0, 0, 108)
    headerFrame.BackgroundTransparency = 1
    headerFrame.BorderSizePixel        = 0
    headerFrame.Parent                 = bg

    -- Game subtitle (small, top)
    local gameSub = Instance.new("TextLabel")
    gameSub.AnchorPoint            = Vector2.new(0.5, 0)
    gameSub.Position               = UDim2.new(0.5, 0, 0, 16)
    gameSub.Size                   = UDim2.new(0, 400, 0, 16)
    gameSub.BackgroundTransparency = 1
    gameSub.Text                   = "ANIME CARD CLASH"
    gameSub.TextColor3             = Color3.fromRGB(120, 120, 155)
    gameSub.Font                   = Enum.Font.GothamBold
    gameSub.TextSize               = 11
    gameSub.TextXAlignment         = Enum.TextXAlignment.Center
    gameSub.Parent                 = headerFrame

    -- Main title
    local titleLbl = Instance.new("TextLabel")
    titleLbl.AnchorPoint            = Vector2.new(0.5, 0)
    titleLbl.Position               = UDim2.new(0.5, 0, 0, 34)
    titleLbl.Size                   = UDim2.new(0, 700, 0, 44)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                   = "SELECT  YOUR  STARTER  PACK"
    titleLbl.TextColor3             = C.gold
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.TextSize               = 30
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Center
    titleLbl.Parent                 = headerFrame

    -- Animated gold underline
    local underline = Instance.new("Frame")
    underline.AnchorPoint            = Vector2.new(0.5, 0)
    underline.Position               = UDim2.new(0.5, 0, 0, 80)
    underline.Size                   = UDim2.new(0, 0, 0, 2)
    underline.BackgroundColor3       = C.gold
    underline.BackgroundTransparency = 0.25
    underline.BorderSizePixel        = 0
    underline.Parent                 = headerFrame

    -- Subtitle
    local subtitleLbl = Instance.new("TextLabel")
    subtitleLbl.AnchorPoint            = Vector2.new(0.5, 0)
    subtitleLbl.Position               = UDim2.new(0.5, 0, 0, 86)
    subtitleLbl.Size                   = UDim2.new(0, 520, 0, 18)
    subtitleLbl.BackgroundTransparency = 1
    subtitleLbl.Text                   = "Choose the anime that defines your playstyle. This choice is permanent."
    subtitleLbl.TextColor3             = C.textSub
    subtitleLbl.Font                   = Enum.Font.Gotham
    subtitleLbl.TextSize               = 12
    subtitleLbl.TextXAlignment         = Enum.TextXAlignment.Center
    subtitleLbl.Parent                 = headerFrame

    -- ── PACK ROW ─────────────────────────────────────────────
    -- The ScrollingFrame fills the remaining height after the header.
    -- ClipsDescendants is OFF so the box lift animation clears the top edge.
    local packRow = Instance.new("ScrollingFrame")
    packRow.Name                   = "PackRow"
    packRow.Position               = UDim2.new(0, 28, 0, 108)
    packRow.Size                   = UDim2.new(1, -56, 1, -126)
    packRow.BackgroundTransparency = 1
    packRow.BorderSizePixel        = 0
    packRow.ScrollBarThickness     = 0        -- hidden for clean look
    packRow.CanvasSize             = UDim2.new(0, 0, 0, 0)
    packRow.AutomaticCanvasSize    = Enum.AutomaticSize.X
    packRow.ScrollingDirection     = Enum.ScrollingDirection.X
    packRow.ClipsDescendants       = false    -- allow box lift to overflow
    packRow.Parent                 = bg

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection       = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rowLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
    rowLayout.Padding             = UDim.new(0, 18)
    rowLayout.SortOrder           = Enum.SortOrder.LayoutOrder
    rowLayout.Parent              = packRow

    -- Build each pack box
    for i, packId in ipairs(packOrder) do
        local pack = allPacks[packId]
        if pack then
            local slot = buildPackBox(pack, function(selectedId)
                -- Screen flash → fade out → destroy
                local flash = Instance.new("Frame")
                flash.Size                   = UDim2.new(1, 0, 1, 0)
                flash.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
                flash.BackgroundTransparency = 0.65
                flash.BorderSizePixel        = 0
                flash.ZIndex                 = 30
                flash.Parent                 = screenGui
                TweenService:Create(flash, TweenInfo.new(0.35), {
                    BackgroundTransparency = 1
                }):Play()
                TweenService:Create(bg, TweenInfo.new(0.35), {
                    BackgroundTransparency = 1
                }):Play()
                task.delay(0.38, function()
                    screenGui:Destroy()
                end)
                onPackSelected(selectedId)
            end)
            slot.LayoutOrder = i
            slot.Parent      = packRow
        end
    end

    -- ── FADE IN ───────────────────────────────────────────────
    TweenService:Create(bg, TweenInfo.new(0.45), {
        BackgroundTransparency = 0
    }):Play()
    -- Animate underline expanding after fade
    task.delay(0.2, function()
        TweenService:Create(underline, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 420, 0, 2)
        }):Play()
    end)

    return screenGui
end

-- ══════════════════════════════════════════════════════════════
--  CLOSE
-- ══════════════════════════════════════════════════════════════
function PackSelectionUI.close()
    local gui = playerGui:FindFirstChild("PackSelectionScreen")
    if gui then gui:Destroy() end
end

return PackSelectionUI
