--[[
    init.client.luau
    Location: StarterPlayerScripts/Client
]]

task.spawn(function()
    local ok, err = pcall(function() require(script.DeckClient) end)
    if not ok then warn("[init] DeckClient failed:", err) end
end)

task.spawn(function()
    local ok, err = pcall(function() require(script.MatchClient) end)
    if not ok then warn("[init] MatchClient failed:", err) end
end)
