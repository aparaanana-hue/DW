-- Islands Auto Builder loader.
--
-- Execute this instead of IAB.lua itself. raw.githubusercontent sits behind a
-- CDN that keeps serving the previous copy for minutes after a push, which is
-- why re-executing can leave you on an old build no matter how many times you
-- run it. The "?t=" makes every request a different URL, so the CDN has
-- nothing to serve from cache.
--
-- The build stamp it prints on load is the check: if it does not match the
-- newest commit, you are still on a cached copy.

local REPO = "https://raw.githubusercontent.com/aparaanana-hue/DW/refs/heads/main/"

local function fresh(name)
    return game:HttpGet(REPO .. name .. "?t=" .. tostring(os.time()) .. tostring(math.random(1e6)))
end

local ok, err = pcall(function()
    loadstring(fresh("IAB.lua"))()
end)

if not ok then
    warn("[IAB loader] failed: " .. tostring(err))
end
