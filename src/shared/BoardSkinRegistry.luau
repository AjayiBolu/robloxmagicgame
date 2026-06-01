--[[
    BoardSkinRegistry.luau
    Location: ReplicatedStorage/Shared/BoardSkinRegistry

    BOARD SKIN DATA (read-only, data-driven)
    ========================================
    Maps a skinId → cosmetic appearance for one half of the battle board.
    A "skin" describes how a player's half of the field is painted: its
    background colour, the accent used for labels/zone tints, the colour of
    the border glow around the half, and an optional pattern enum.

    Skin IDs are intentionally opaque strings (NOT an enum) so new skins can
    be added here without touching any other code. The default skin is always
    available; unlockable skins are added by the microtransaction system
    (out of scope) — this module only needs to be queryable by skin ID.

    ── ADDING A NEW SKIN ─────────────────────────────────────────────
        Add an entry to SKINS below. Required fields:
            bgColor    : Color3   -- half background fill
            accentColor: Color3   -- zone tints, labels
            glowColor  : Color3   -- border glow around the half
            patternId  : string   -- "none" | "grid" | "diagonal" | "rune"
                                     (renderer falls back to "none" if unknown)
        Optional:
            name       : string   -- human-readable label (store/UI)
    ──────────────────────────────────────────────────────────────────
]]

local BoardSkinRegistry = {}

-- The id every player falls back to. Always present in SKINS.
BoardSkinRegistry.DEFAULT_SKIN_ID = "default"

-- ── SKIN TABLE ──────────────────────────────────────────────────
local SKINS = {
    default = {
        name        = "Midnight Arena",
        bgColor     = Color3.fromRGB(13, 15, 26),
        accentColor = Color3.fromRGB(70, 90, 150),
        glowColor   = Color3.fromRGB(90, 120, 210),
        patternId   = "grid",
    },

    -- Example unlockables (queryable now; unlock flow is a separate feature).
    ember = {
        name        = "Ember Forge",
        bgColor     = Color3.fromRGB(26, 12, 10),
        accentColor = Color3.fromRGB(170, 80, 45),
        glowColor   = Color3.fromRGB(235, 110, 45),
        patternId   = "diagonal",
    },

    verdant = {
        name        = "Verdant Grove",
        bgColor     = Color3.fromRGB(10, 22, 14),
        accentColor = Color3.fromRGB(70, 140, 80),
        glowColor   = Color3.fromRGB(90, 200, 110),
        patternId   = "rune",
    },

    void = {
        name        = "Void Sigil",
        bgColor     = Color3.fromRGB(16, 10, 26),
        accentColor = Color3.fromRGB(120, 70, 180),
        glowColor   = Color3.fromRGB(160, 90, 230),
        patternId   = "rune",
    },
}

-- ── PUBLIC API ──────────────────────────────────────────────────

-- Returns the skin table for `skinId`, or the default skin if the id is
-- unknown / nil. Never returns nil so render code can stay branch-free.
function BoardSkinRegistry.get(skinId)
    return SKINS[skinId] or SKINS[BoardSkinRegistry.DEFAULT_SKIN_ID]
end

-- Returns true if `skinId` is a real registered skin.
function BoardSkinRegistry.exists(skinId)
    return SKINS[skinId] ~= nil
end

-- Returns a list of all registered skin ids (for store/preview UIs).
function BoardSkinRegistry.allIds()
    local ids = {}
    for id in pairs(SKINS) do
        table.insert(ids, id)
    end
    return ids
end

return BoardSkinRegistry
