--[[
    init.client.luau
    Location: StarterPlayerScripts/Client
]]

task.spawn(function()
    local ok, err = pcall(function() require(script.DeckClient) end)
    if not ok then warn("[init] DeckClient failed:", err) end
end)

-- MatchClient disabled — battle is moving to instanced servers.
-- Re-enable once the instanced combat system is ready.
-- task.spawn(function()
--     local ok, err = pcall(function() require(script.MatchClient) end)
--     if not ok then warn("[init] MatchClient failed:", err) end
-- end)
