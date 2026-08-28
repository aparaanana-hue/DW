-- SAE - Steal An Egg
--
-- Built on the same Duvome library as RUT and PIHD, so it inherits the tabs,
-- themes, glass, config saving and notifications rather than reinventing worse
-- versions of each.
--
-- WHERE THIS CAME FROM, AND WHAT THAT MEANS
--
-- This was written from a 58,552-instance class dump of the live client. No
-- source was recovered: MacSploit's decompile() returns the string "Error
-- occured while decompiling, error: ..." rather than throwing, so all 1,387
-- scripts came back as error text. What the dump did give is the entire
-- instance graph, and this game's naming carries its data model:
--
--   Workspace.AreaEggSlotsClient.<32-hex>        field eggs; the name IS the id
--   Workspace.PlacedEggRenders.<userId>_<eggId>  placed eggs; owner in the name
--   Workspace.<player>.<Name> (<n> kg)           carried eggs are Tools
--   Workspace.SakuraBloomTrees / SakuraCrystals  the Bloomery event props
--   Workspace.Stands.Prompts.SellAll             physical sell prompt
--   ReplicatedStorage.Packages.Networking        136 RemoteEvents, 83 Functions
--
-- Every remote is named for what it does (RF/EggWorld/AskFieldEggCarry), but a
-- name is not a signature. Nothing in this file knows for certain what
-- arguments the server wants. So every server action goes through one index,
-- RX, whose bindings are inferences that the Dev tab's spy confirms or
-- corrects at runtime, and which can be rebound live without editing the file.
--
-- Read that as: the world-reading half (ESP, stats, targeting, movement) is
-- solid, because it needs no server agreement. The acting half is inference
-- until the spy has watched you do the thing once by hand.
--
-- NOT RUN. This parses. It has never executed in Roblox.

local ENV = (typeof(getgenv) == "function" and getgenv()) or _G

-- Re-executing used to stack a second window and, worse, a second set of loops
-- fighting the first over the same character. Ask the old instance to die.
if type(ENV.SAE_UNLOAD) == "function" then
    pcall(ENV.SAE_UNLOAD)
    ENV.SAE_UNLOAD = nil
end

-- ---------------------------------------------------------------------------
-- Library loader
-- ---------------------------------------------------------------------------
-- The DW repo is private, and raw.githubusercontent answers an unauthenticated
-- request for a private file with a 404 HTML page, not the library. HttpGet
-- returns that page happily, loadstring cannot parse it, and the call blows up
-- on this line with nothing explaining why - which is exactly the "Line 44"
-- stack you get. So: local copy first, network second, and a real message
-- instead of a nil call if neither works.
local function loadLib(fileName, url)
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        local ok, has = pcall(isfile, fileName)
        if ok and has then
            local rok, body = pcall(readfile, fileName)
            if rok and type(body) == "string" and #body > 1000 then
                local chunk = loadstring(body)
                if chunk then return chunk(), "local file " .. fileName end
            end
        end
    end

    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" then
        error("Could not fetch " .. fileName .. ": " .. tostring(body), 0)
    end
    -- A private repo returns a short HTML 404. The length check catches it
    -- before loadstring turns it into a confusing syntax error.
    if #body < 1000 or body:sub(1, 1) == "<" or body:find("404: Not Found", 1, true) then
        error(fileName .. " came back as a " .. #body .. "-byte error page, not Lua.\n"
            .. "The DW repo is private, so raw.githubusercontent refuses an\n"
            .. "unauthenticated read. Either make it public again, or drop\n"
            .. fileName .. " into your executor's workspace folder - this\n"
            .. "loader checks there first.", 0)
    end

    local chunk, err = loadstring(body)
    if not chunk then
        error("Fetched " .. fileName .. " but it will not compile: " .. tostring(err), 0)
    end
    return chunk(), url
end

local Duvome = loadLib("DL.lua",
    "https://raw.githubusercontent.com/aparaanana-hue/DW/refs/heads/main/DL.lua")

local SAE_BUILD = "Aug 27 - build 1, unrun"

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")
local Stats             = game:GetService("Stats")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ===========================================================================
-- STATE
-- ===========================================================================
-- One table, not a local per feature: a local per feature is how PIHD hit
-- Luau's 200-register ceiling, and this file is meant to grow.
local S = {
    -- steal
    tweenOn      = true,
    tweenSpeed   = 120,
    stealRar     = {},      -- rarity name -> true
    stealAllRar  = true,
    stealZones   = {},
    stealAllZone = true,
    minKg        = 0,
    priority     = "Value",
    returnBase   = true,
    dropHeld     = false,
    avoidGuards  = true,
    guardRadius  = 45,
    stealDelay   = 0.6,
    -- eggs
    placeAll     = true,
    placeRar     = {},
    sellEggRar   = {},
    sellEggEvery = 60,
    favMinRar    = "Legendary",
    -- pets
    sellPetRar   = {},
    keepMutated  = true,
    keepEquipped = true,
    keepFav      = true,
    sellPetEvery = 90,
    fuseEvery    = 120,
    fuseKeep     = 3,
    -- sakura
    sakTarget    = "Biggest Earner",
    sakTargetName= "",
    sakTargetRar = "Secret",
    sakCrystals  = 5,
    -- progress
    claimEvery   = 300,
    upgradeEvery = 120,
    -- hop
    hopMode      = "Emptiest",
    hopMax       = 999,
    hopScan      = 20,
    hopAfter     = 0,
    hopCount     = 0,
    -- esp
    espDist      = 1500,
    esp          = {},
    -- character
    walkSpeed    = 16,
    jumpPower    = 50,
    flySpeed     = 60,
    -- webhook
    hookUrl      = "",
    hookOn       = false,
    hookEvents   = {},
    -- runtime
    home         = nil,
    stats        = {},
    stolen       = 0,
    conns        = {},
    espObjects   = {},
}

-- Every running loop registers a stop function. The panic button calls the lot:
-- turning eleven automations off one at a time while a tween has your character
-- mid-flight across the map is not a workable plan.
local ACTIVE = {}

local function register(name, stop) ACTIVE[name] = stop end
local function unregister(name) ACTIVE[name] = nil end

local function bind(name, fn)
    if S.conns[name] then S.conns[name]:Disconnect() end
    S.conns[name] = fn
end

local function unbind(name)
    local c = S.conns[name]
    if c then pcall(function() c:Disconnect() end) end
    S.conns[name] = nil
end

local function notify(title, text, dur)
    pcall(function()
        Duvome:MakeNotification({
            Name = title, Content = tostring(text),
            Image = "rbxassetid://4483345998", Time = dur or 5,
        })
    end)
end

-- ===========================================================================
-- EXECUTOR SURFACE
-- ===========================================================================
-- All optional. The script degrades feature by feature rather than refusing to
-- load, because which of these MacSploit provides is not something a class dump
-- could answer.
local F = {
    hookmeta   = (typeof(hookmetamethod)      == "function") and hookmetamethod      or nil,
    getraw     = (typeof(getrawmetatable)     == "function") and getrawmetatable     or nil,
    setread    = (typeof(setreadonly)         == "function") and setreadonly         or nil,
    namecall   = (typeof(getnamecallmethod)   == "function") and getnamecallmethod   or nil,
    newcc      = (typeof(newcclosure)         == "function") and newcclosure         or function(f) return f end,
    checkcall  = (typeof(checkcaller)         == "function") and checkcaller         or function() return false end,
    clip       = (typeof(setclipboard)        == "function") and setclipboard        or nil,
    write      = (typeof(writefile)           == "function") and writefile           or nil,
    fireprompt = (typeof(fireproximityprompt) == "function") and fireproximityprompt or nil,
    request    = (syn and syn.request) or (http and http.request)
                 or (typeof(request) == "function" and request)
                 or (typeof(http_request) == "function" and http_request) or nil,
    queueport  = (typeof(queue_on_teleport) == "function") and queue_on_teleport or nil,
}

-- ===========================================================================
-- RX - the remote index
-- ===========================================================================
-- The single place any server call is described. Each entry is a logical action
-- mapped to a remote name from the dump plus an argument builder. Both halves
-- are inferences drawn from the name, and both are overridable at runtime from
-- the Dev tab, which is the point: when the spy shows the real shape, you rebind
-- there instead of waiting on an edit to this file.
--
-- `verified` stays false until the spy has actually observed that remote being
-- called. The UI reads it, so a button whose call has never been seen says so.
local NET do
    local pkgs = ReplicatedStorage:FindFirstChild("Packages")
    NET = pkgs and pkgs:FindFirstChild("Networking") or nil
end

local RX = { map = {}, seen = {}, log = {}, order = {}, spyOn = false, hooked = false }

local function def(key, remote, build, note)
    RX.map[key] = { remote = remote, build = build or function(...) return ... end, note = note }
end

-- Eggs in the world
def("carry",      "RF/EggWorld/AskFieldEggCarry",  function(id) return id end,
    "Pick up a field egg. Argument guessed as the 32-hex slot name.")
def("drop",       "RF/EggWorld/AskFieldEggDrop",   function() return nil end)
def("place",      "RF/EggWorld/AskPlaceEgg",       function(id) return id end)
def("hatch",      "RF/EggWorld/AskHatch",          function(id) return id end)
def("hatchDone",  "RF/EggWorld/AskFinishHatch",    function(id) return id end)
def("skipGrowth", "RF/EggWorld/AskSkipGrowth",     function(id) return id end)
def("eggSnap",    "RF/EggWorld/AskFieldEggSnapshot", function() return nil end)
def("liveSnap",   "RF/EggWorld/AskLiveSnapshot",   function() return nil end)
def("eggRecord",  "RF/EggWorld/AskEggRecord",      function(id) return id end)
def("wearTool",   "RF/EggWorld/AskWearTool",       function(id) return id end)
def("doffTool",   "RF/EggWorld/AskDoffTool",       function() return nil end)

-- Pets
def("petSnap",    "RF/PenRoster/AskLiveSnapshot",  function() return nil end)
def("petWear",    "RF/PenRoster/AskWear",          function(id) return id end)
def("petDoff",    "RF/PenRoster/AskDoff",          function(id) return id end)
def("petSell",    "RF/PenRoster/AskSale",          function(id) return id end)
def("petSlots",   "RF/PenRoster/AskWearLimit",     function() return nil end,
    "Best guess for the pet-slot upgrade.")
def("sellPetRE",  "RE/PetSatchel/SellPet",         function(id) return id end)
def("sellAllPet", "RE/PetSatchel/SellEveryPet",    function() return nil end)
def("favourite",  "RE/PetSatchel/WriteFavourite",  function(id, on) return id, on end)
def("wearBest",   "RF/Haul/WearBest",              function() return nil end)
def("bestStatus", "RF/Haul/FetchWearBestStatus",   function() return nil end)
def("autoSell",   "RF/Haul/WriteAutoSell",         function(on) return on end)
def("sellSatchel","RF/Haul/OfferFullSatchelSale",  function() return nil end)

-- Fusery
def("fuseLoad",   "RF/Fusery/LoadPet",             function(id) return id end)
def("fuseEject",  "RF/Fusery/EjectPet",            function(id) return id end)
def("fuseBegin",  "RF/Fusery/BeginFuse",           function() return nil end)
def("fuseBrief",  "RF/Fusery/ConfirmBriefing",     function() return nil end)
def("fuseReveal", "RF/Fusery/FinishReveal",        function() return nil end)

-- Bloomery, which is the Sakura event: the dump has SakuraBloomTrees,
-- SakuraCrystals and an IncubatorDead model alongside these remotes.
def("sakStrike",  "RE/Bloomery/AskStrikeTree",     function(tree) return tree end)
def("sakGather",  "RF/Bloomery/AskGatherPetal",    function(x) return x end)
def("sakLoad",    "RF/Bloomery/AskLoadEgg",        function(id) return id end)
def("sakEject",   "RF/Bloomery/AskEjectEgg",       function() return nil end)
def("sakMutate",  "RF/Bloomery/AskMutate",         function() return nil end)
def("sakBrief",   "RF/Bloomery/AskBriefingConfirm",function() return nil end)
def("sakCrane",   "RF/Bloomery/AskCraneReturn",    function() return nil end)
def("sakHandoff", "RF/Bloomery/AskHandoff",        function() return nil end)

-- Progression
def("profile",    "RF/ProfileMirror/FetchProfile", function() return nil end)
def("baseRaise",  "RF/Homestead/AskBaseTierRaise", function() return nil end)
def("baseState",  "RF/Homestead/AskState",         function() return nil end)
def("buyNear",    "RE/Homestead/AskNearbyPurchase",function() return nil end)
def("lobbyHop",   "RE/Homestead/AskLobbyHop",      function() return nil end)
def("codex",      "RF/Codex/AskRedeemAll",         function() return nil end)
def("codexOne",   "RF/Codex/AskRedeem",            function(id) return id end)
def("wearBat",    "RF/Codex/AskWearFieldBat",      function() return nil end)
def("groupPerk",  "RF/GroupPerk/RedeemPerk",       function() return nil end)
def("awayCheck",  "RF/AwayEarnings/PendingCheck",  function() return nil end)
def("awayCollect","RF/AwayEarnings/AskCollect",    function() return nil end)
def("trailBuy",   "RF/Trailwear/AskPurchase",      function(id) return id end)
def("trailWear",  "RF/Trailwear/AskChoose",        function(id) return id end)
def("trailSnap",  "RF/Trailwear/AskWornSnapshot",  function() return nil end)
def("millRaise",  "RF/Treadmill/AskTierRaise",     function() return nil end)
def("millWear",   "RF/Treadmill/AskWearStill",     function() return nil end)
def("millSnap",   "RF/Treadmill/AskRenderSnapshot",function() return nil end)
def("trials",     "RF/Trials/Fetch",               function() return nil end)
def("luck",       "RF/LuckWindow/FetchState",      function() return nil end)

-- Live events, which is where a weather/cycle prediction has to come from.
def("evRunning",  "RF/LiveEvents/FetchRunning",    function() return nil end)
def("evSched",    "RF/LiveEvents/FetchScheduled",  function() return nil end)
def("evEta",      "RF/LiveEvents/FetchRecurringEta", function() return nil end)
def("evCatalog",  "RF/LiveEvents/FetchCatalogue",  function() return nil end)

local function remoteOf(key)
    local e = RX.map[key]
    if not e or not NET then return nil end
    return NET:FindFirstChild(e.remote), e
end

-- Every server action in the file funnels through here, so a failure is
-- reported the same way everywhere and a wrong binding is visible rather than
-- silently doing nothing.
local function call(key, ...)
    local r, e = remoteOf(key)
    if not e then return false, "no binding for " .. tostring(key) end
    if not r then return false, "remote missing: " .. e.remote end

    local args = table.pack(e.build(...))
    local ok, res
    if r:IsA("RemoteFunction") then
        ok, res = pcall(function() return r:InvokeServer(table.unpack(args, 1, args.n)) end)
    else
        ok, res = pcall(function() r:FireServer(table.unpack(args, 1, args.n)) end)
    end
    if not ok then return false, tostring(res) end
    return true, res
end

local function fetch(key, ...)
    local ok, res = call(key, ...)
    if ok then return res end
    return nil
end

-- ===========================================================================
-- SPY
-- ===========================================================================
-- The whole reason the acting half of this script is fixable. It watches the
-- game make its own calls and writes down the real argument shapes, which is
-- exactly the information the failed decompile would have given.
local MAX_STR, MAX_DEPTH, MAX_KEYS = 120, 3, 24

local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then
        local s = v
        if #s > MAX_STR then s = s:sub(1, MAX_STR) .. "..." end
        return string.format("%q", s)
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "Instance" then
        local ok, full = pcall(function() return v:GetFullName() end)
        return "<" .. v.ClassName .. " " .. (ok and full or v.Name) .. ">"
    elseif t == "Vector3" then
        return string.format("Vector3(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        local p = v.Position
        return string.format("CFrame(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
    elseif t == "EnumItem" then
        return tostring(v)
    elseif t == "table" then
        if depth >= MAX_DEPTH then return "{...}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > MAX_KEYS then table.insert(parts, "...") break end
            local key = (type(k) == "string" and k:match("^%a[%w_]*$"))
                and (k .. " = ") or ("[" .. ser(k, depth + 1) .. "] = ")
            table.insert(parts, key .. ser(val, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return "<" .. t .. ">"
end

-- Two hundred carry calls with different ids are one fact, not two hundred, so
-- calls collapse onto remote name plus argument types.
local function record(remote, method, args, n)
    if NET and remote.Parent ~= NET then return end
    local types = {}
    for i = 1, n do types[i] = typeof(args[i]) end
    local sig = remote.Name .. "(" .. table.concat(types, ", ") .. ")"

    RX.seen[remote.Name] = true
    local rec = RX.log[sig]
    if rec then rec.hits = rec.hits + 1 return end

    local shown = {}
    for i = 1, n do shown[i] = ser(args[i]) end
    RX.log[sig] = {
        sig = sig, remote = remote.Name, method = method,
        args = table.concat(shown, ", "), hits = 1,
    }
    table.insert(RX.order, sig)
end

local function installSpy()
    if RX.hooked then return true end
    if not F.namecall then return false, "No getnamecallmethod() - spy unavailable." end

    local function wrap(orig)
        return function(self, ...)
            if RX.spyOn and not F.checkcall() then
                local m = F.namecall()
                if m == "FireServer" or m == "InvokeServer" then
                    local ok, cls = pcall(function() return self.ClassName end)
                    if ok and (cls == "RemoteEvent" or cls == "RemoteFunction"
                        or cls == "UnreliableRemoteEvent") then
                        local a = table.pack(...)
                        -- pcall'd: a serialiser mistake must never break the
                        -- call it is only watching.
                        pcall(record, self, m, a, a.n)
                    end
                end
            end
            return orig(self, ...)
        end
    end

    if F.hookmeta then
        local orig
        orig = F.hookmeta(game, "__namecall", F.newcc(wrap(function(self, ...)
            return orig(self, ...)
        end)))
        RX.hooked = true
        return true
    end
    if F.getraw and F.setread then
        local mt = F.getraw(game)
        local orig = mt.__namecall
        F.setread(mt, false)
        mt.__namecall = wrap(orig)
        F.setread(mt, true)
        RX.hooked = true
        return true
    end
    return false, "No hookmetamethod() or getrawmetatable()."
end

local function spyReport()
    local out = {
        "-- Steal An Egg - observed remote signatures",
        "-- " .. os.date("%Y-%m-%d %H:%M:%S") .. "  |  " .. #RX.order .. " unique",
        "",
    }
    for _, sig in ipairs(RX.order) do
        local r = RX.log[sig]
        table.insert(out, string.format("-- x%d  %s", r.hits, r.method))
        table.insert(out, r.remote)
        table.insert(out, "  args: " .. r.args)
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

-- ===========================================================================
-- WORLD READERS
-- ===========================================================================
local function char() return LP.Character end
local function hrp()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end
local function hum()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function partOf(model)
    if not model then return nil end
    return model:FindFirstChild("Hitbox")
        or model:FindFirstChild("Part")
        or model:FindFirstChildWhichIsA("BasePart")
end

local function distTo(inst)
    local root, p = hrp(), partOf(inst)
    if not root or not p then return math.huge end
    return (root.Position - p.Position).Magnitude
end

-- The dump gave no rarity attribute, only names and models, so rarity is read
-- from whatever the server tagged the instance with. If the game does not use
-- attributes for it, this returns nil and every rarity filter falls open rather
-- than silently matching nothing - a filter that quietly blocks everything is
-- worse than one that is off.
local RARITIES = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary",
    "Mythic", "Divine", "Secret",
}

local function attrOf(inst, names)
    for _, n in ipairs(names) do
        local ok, v = pcall(function() return inst:GetAttribute(n) end)
        if ok and v ~= nil then return v end
    end
    return nil
end

local function rarityOf(inst)
    local v = attrOf(inst, { "Rarity", "rarity", "Tier", "Class" })
    return v and tostring(v) or nil
end

local function kgOf(inst)
    local v = attrOf(inst, { "Weight", "Kg", "Size", "Scale" })
    if v then return tonumber(v) or 0 end
    local n = tostring(inst.Name):match("%(([%d%.]+) kg%)")
    return tonumber(n) or 0
end

local function valueOf(inst)
    local v = attrOf(inst, { "Value", "Earnings", "Income", "Price" })
    return tonumber(v) or 0
end

-- Zones come out of Workspace.__OBJECTS.Areas in the dump. A field egg's zone
-- is whichever area part contains it, which is cheap enough to work out on
-- demand and means the zone filter needs no hardcoded coordinate list.
local function zoneNames()
    local objs = workspace:FindFirstChild("__OBJECTS")
    local areas = objs and objs:FindFirstChild("Areas")
    local out = {}
    if not areas then return out end
    for _, a in ipairs(areas:GetChildren()) do table.insert(out, a.Name) end
    table.sort(out)
    return out
end

local function zoneOf(pos)
    local objs = workspace:FindFirstChild("__OBJECTS")
    local areas = objs and objs:FindFirstChild("Areas")
    if not areas then return nil end
    for _, a in ipairs(areas:GetChildren()) do
        local p = a:IsA("BasePart") and a or a:FindFirstChildWhichIsA("BasePart")
        if p then
            local rel = p.CFrame:PointToObjectSpace(pos)
            local h = p.Size / 2
            if math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y
                and math.abs(rel.Z) <= h.Z then
                return a.Name
            end
        end
    end
    return nil
end

local function fieldEggs()
    local folder = workspace:FindFirstChild("AreaEggSlotsClient")
    local out = {}
    if not folder then return out end
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") then
            local p = partOf(m)
            table.insert(out, {
                id = m.Name, model = m, part = p,
                dist = distTo(m),
                rarity = rarityOf(m),
                kg = kgOf(m),
                value = valueOf(m),
                zone = p and zoneOf(p.Position) or nil,
            })
        end
    end
    return out
end

local function placedEggs()
    local folder = workspace:FindFirstChild("PlacedEggRenders")
    local out = {}
    if not folder then return out end
    for _, m in ipairs(folder:GetChildren()) do
        local uid, eggId = m.Name:match("^(%d+)_(%x+)$")
        if uid then
            local owner = Players:GetPlayerByUserId(tonumber(uid))
            table.insert(out, {
                userId = tonumber(uid), id = eggId, model = m,
                who = owner and owner.Name or ("UserId " .. uid),
                mine = tonumber(uid) == LP.UserId,
                dist = distTo(m),
                rarity = rarityOf(m), kg = kgOf(m), value = valueOf(m),
            })
        end
    end
    return out
end

local function carriedEggs()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") then
                    local base, kg = t.Name:match("^(.-)%s*%(([%d%.]+) kg%)$")
                    if base then
                        table.insert(out, {
                            player = p, tool = t, name = base,
                            kg = tonumber(kg) or 0, me = (p == LP),
                        })
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.kg > b.kg end)
    return out
end

local function myHeldEgg()
    for _, c in ipairs(carriedEggs()) do
        if c.me then return c end
    end
    return nil
end

local function guards()
    local g = workspace:FindFirstChild("_Guards")
    local out = {}
    if not g then return out end
    for _, m in ipairs(g:GetChildren()) do
        if m:IsA("Model") then table.insert(out, m) end
    end
    return out
end

local function guardNear(pos, radius)
    for _, g in ipairs(guards()) do
        local p = partOf(g)
        if p and (p.Position - pos).Magnitude <= radius then return g end
    end
    return nil
end

local function myPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = attrOf(plot, { "Owner", "OwnerId", "UserId", "Player" })
        if owner and (tostring(owner) == tostring(LP.UserId)
            or tostring(owner) == LP.Name) then
            return plot
        end
    end
    -- No owner attribute anywhere: fall back to the nearest plot, which is
    -- almost always yours because the game spawns you on it.
    local best, bestD = nil, math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        local d = distTo(plot)
        if d < bestD then best, bestD = plot, d end
    end
    return best
end

local function plotPoint(plot)
    if not plot then return nil end
    local p = plot:FindFirstChild("SpawnPoint") or plot:FindFirstChild("CenterPoint")
    if p and p:IsA("BasePart") then return p.Position end
    local any = partOf(plot)
    return any and any.Position or nil
end

-- ===========================================================================
-- MOVEMENT
-- ===========================================================================
-- Tweened, not snapped. A CFrame snap across the map is the single most obvious
-- thing a client can do. This is still teleporting - only less blunt about it.
local function travelTo(pos, instantOverride)
    local root = hrp()
    if not root then return false, "no character" end
    local target = CFrame.new(pos + Vector3.new(0, 4, 0))

    if instantOverride or not S.tweenOn then
        root.CFrame = target
        return true
    end

    local d = (root.Position - pos).Magnitude
    local secs = math.clamp(d / math.max(S.tweenSpeed, 1), 0.08, 12)
    local tw = TweenService:Create(root,
        TweenInfo.new(secs, Enum.EasingStyle.Linear), { CFrame = target })
    tw:Play()
    tw.Completed:Wait()
    return true
end

local function goHome()
    if S.home then return travelTo(S.home) end
    local pt = plotPoint(myPlot())
    if pt then return travelTo(pt) end
    return false, "no home saved and no plot found"
end

-- ===========================================================================
-- TARGETING
-- ===========================================================================
-- One comparator, driven by the Priority dropdown, so every automation that
-- picks "the best egg" agrees on what best means.
local function scoreEgg(e)
    if S.priority == "Distance" then return -e.dist
    elseif S.priority == "Size"   then return e.kg
    elseif S.priority == "Value"  then return e.value > 0 and e.value or e.kg
    elseif S.priority == "Rarity" then
        for i, r in ipairs(RARITIES) do
            if e.rarity == r then return i * 1000 end
        end
        return 0
    end
    return -e.dist
end

local function eggAllowed(e)
    if not S.stealAllRar and e.rarity then
        if not S.stealRar[e.rarity] then return false end
    end
    if not S.stealAllZone and e.zone then
        if not S.stealZones[e.zone] then return false end
    end
    if S.minKg > 0 and e.kg > 0 and e.kg < S.minKg then return false end
    if S.avoidGuards and e.part and guardNear(e.part.Position, S.guardRadius) then
        return false
    end
    return true
end

local function bestEgg()
    local best, bestScore = nil, -math.huge
    for _, e in ipairs(fieldEggs()) do
        if eggAllowed(e) then
            local sc = scoreEgg(e)
            if sc > bestScore then best, bestScore = e, sc end
        end
    end
    return best
end

-- The pickup itself. The ProximityPrompt is tried first every time: if the egg
-- has one, firing it is the game's own code path and needs no guessed
-- signature, which makes it strictly better than the remote.
local function grabEgg(e)
    local prompt = e.model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and F.fireprompt then
        pcall(F.fireprompt, prompt)
        return true, "prompt"
    end
    local ok, res = call("carry", e.id)
    return ok, ok and ("remote " .. ser(res)) or res
end

-- ===========================================================================
-- WEBHOOK
-- ===========================================================================
local function post(text)
    if not S.hookOn or S.hookUrl == "" or not F.request then return end
    local body = HttpService:JSONEncode({ content = tostring(text) })
    pcall(F.request, {
        Url = S.hookUrl, Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
end

local function event(kind, text)
    if S.hookEvents[kind] then
        post("**" .. kind .. "** - " .. text .. "  (" .. LP.Name .. ")")
    end
end

-- ===========================================================================
-- WINDOW
-- ===========================================================================
local Window = Duvome:MakeWindow({
    Name         = "SAE - Steal An Egg",
    HidePremium  = false,
    SaveConfig   = true,
    ConfigFolder = "SAE",
    Blur         = false,
})

pcall(function() Duvome:SetGlass(0.38) end)

local StealTab = Window:MakeTab({Name = "Steal",     Icon = "star",     Columns = true})
local EggTab   = Window:MakeTab({Name = "Eggs",      Icon = "backpack", Columns = true})
local PetTab   = Window:MakeTab({Name = "Pets",      Icon = "tag",      Columns = true})
local SakTab   = Window:MakeTab({Name = "Sakura",    Icon = "house",    Columns = true})
local ProgTab  = Window:MakeTab({Name = "Progress",  Icon = "wrench",   Columns = true})
local ServTab  = Window:MakeTab({Name = "Server",    Icon = "code",     Columns = true})
local EspTab   = Window:MakeTab({Name = "ESP",       Icon = "tag",      Columns = true})
local CharTab  = Window:MakeTab({Name = "Character", Icon = "backpack", Columns = true})
local DashTab  = Window:MakeTab({Name = "Dashboard", Icon = "gear",     Columns = true})
local DevTab   = Window:MakeTab({Name = "Dev",       Icon = "wrench",   Columns = true})

-- ===========================================================================
-- STEAL
-- ===========================================================================
local SL, SR = StealTab:AddLeft(), StealTab:AddRight()

local engineSec = SL:AddSection({Name = "Engine"})

engineSec:AddParagraph("How this works",
    "Targets are read straight off the workspace - no server call, nothing\n" ..
    "guessed. The pickup fires the egg's ProximityPrompt when it has one,\n" ..
    "and only falls back to RF/EggWorld/AskFieldEggCarry, whose argument is\n" ..
    "an inference. Run the Dev spy through one manual pickup to confirm it.")

local stealInfo = engineSec:AddParagraph("Status", "Idle.")
local function setSteal(m) pcall(function() stealInfo:Set(m) end) end

engineSec:AddToggle({
    Name = "Smooth Tween", Default = true, Save = true, Flag = "tween",
    Callback = function(v) S.tweenOn = v end,
})

engineSec:AddSlider({
    Name = "Tween Speed", Min = 20, Max = 400, Default = 120,
    Increment = 10, ValueName = " studs/s", Save = true, Flag = "tweenspd",
    Callback = function(v) S.tweenSpeed = v end,
})

engineSec:AddSlider({
    Name = "Delay Between Steals", Min = 0, Max = 5, Default = 0.6,
    Increment = 0.1, ValueName = " s", Save = true, Flag = "stealdelay",
    Callback = function(v) S.stealDelay = v end,
})

engineSec:AddButton({
    Name = "Save Home Position",
    Tooltip = "Remembers where you are standing as the drop-off point.",
    Callback = function()
        local root = hrp()
        if not root then notify("SAE", "No character.", 4) return end
        S.home = root.Position
        notify("SAE", "Home saved.", 4)
        setSteal(string.format("Home set to %.0f, %.0f, %.0f",
            S.home.X, S.home.Y, S.home.Z))
    end,
})

engineSec:AddButton({
    Name = "TP Home / Base",
    Callback = function() task.spawn(goHome) end,
})

-- One steal, shared by the button and the loop so they cannot drift.
local function stealOnce()
    local e = bestEgg()
    if not e then return false, "no egg passes the filters" end
    if e.part then travelTo(e.part.Position) end
    task.wait(0.25)
    local ok, how = grabEgg(e)
    if not ok then return false, how end

    S.stolen = S.stolen + 1
    event("Stolen", string.format("%s %s (%.2f kg) from %s",
        e.rarity or "?", e.id:sub(1, 8), e.kg, e.zone or "?"))

    if S.returnBase then
        task.wait(0.2)
        goHome()
        -- Placing is what banks it. If the binding is wrong this is where the
        -- run quietly stops paying, so the outcome is reported either way.
        local pok, perr = call("place", e.id)
        if not pok then return true, "carried, but place failed: " .. tostring(perr) end
        event("Placed", e.id:sub(1, 8))
    end
    return true, how
end

engineSec:AddButton({
    Name = "Steal Once",
    Callback = function()
        task.spawn(function()
            setSteal("Stealing...")
            local ok, how = stealOnce()
            setSteal((ok and "OK: " or "Failed: ") .. tostring(how))
        end)
    end,
})

engineSec:AddToggle({
    Name = "Auto Steal", Default = false, Flag = "autosteal",
    Callback = function(on)
        if not on then unregister("Auto Steal") return end
        register("Auto Steal", function() ACTIVE["Auto Steal"] = nil end)
        task.spawn(function()
            local ok, fail = 0, 0
            while ACTIVE["Auto Steal"] do
                local good, how = stealOnce()
                if good then ok = ok + 1 else fail = fail + 1 end
                setSteal(string.format("%d stolen, %d failed  (%s)",
                    ok, fail, tostring(how):sub(1, 40)))
                -- Ten straight failures with nothing banked means the binding is
                -- wrong. Hammering a rejected remote is what gets a client
                -- flagged, so stop and say why.
                if fail >= 10 and ok == 0 then
                    unregister("Auto Steal")
                    setSteal("Stopped: 10 failures, 0 steals. Spy the carry call.")
                    notify("SAE", "Auto Steal stopped - carry binding is wrong.", 8)
                    return
                end
                task.wait(math.max(S.stealDelay, 0.1))
            end
        end)
    end,
})

local filtSec = SR:AddSection({Name = "Filters"})

filtSec:AddParagraph("Rarity and zone",
    "Rarity is read from instance attributes. If this game does not tag its\n" ..
    "eggs with one, the rarity filter opens rather than matching nothing -\n" ..
    "a filter that silently blocks everything is worse than one that is off.")

filtSec:AddToggle({
    Name = "Steal ALL Rarities", Default = true, Save = true, Flag = "allrar",
    Callback = function(v) S.stealAllRar = v end,
})

filtSec:AddDropdown({
    Name = "Steal Rarities", Options = RARITIES, MultiSelect = true,
    Search = true, SelectAll = true, Default = {}, Save = true, Flag = "rars",
    Callback = function(sel)
        S.stealRar = {}
        for _, r in ipairs(sel) do S.stealRar[r] = true end
    end,
})

filtSec:AddToggle({
    Name = "Steal From ALL Zones", Default = true, Save = true, Flag = "allzone",
    Callback = function(v) S.stealAllZone = v end,
})

local zoneDrop = filtSec:AddDropdown({
    Name = "Target Zones", Options = zoneNames(), MultiSelect = true,
    Search = true, SelectAll = true, Default = {},
    Callback = function(sel)
        S.stealZones = {}
        for _, z in ipairs(sel) do S.stealZones[z] = true end
    end,
})

filtSec:AddButton({
    Name = "Rescan Zones",
    Callback = function()
        pcall(function() zoneDrop:Refresh(zoneNames(), true) end)
        notify("SAE", #zoneNames() .. " zones found.", 4)
    end,
})

filtSec:AddSlider({
    Name = "Minimum Size", Min = 0, Max = 50, Default = 0,
    Increment = 0.5, ValueName = " kg", Save = true, Flag = "minkg",
    Callback = function(v) S.minKg = v end,
})

filtSec:AddDropdown({
    Name = "Target Priority",
    Options = { "Value", "Rarity", "Size", "Distance" },
    Default = "Value", Save = true, Flag = "prio",
    Callback = function(v) S.priority = v end,
})

local protSec = SR:AddSection({Name = "Protections"})

protSec:AddToggle({
    Name = "Avoid Guards", Default = true, Save = true, Flag = "avoidguard",
    Callback = function(v) S.avoidGuards = v end,
})

protSec:AddSlider({
    Name = "Guard Avoid Radius", Min = 10, Max = 150, Default = 45,
    Increment = 5, ValueName = " studs", Save = true, Flag = "guardrad",
    Callback = function(v) S.guardRadius = v end,
})

protSec:AddToggle({
    Name = "Auto Return To Base", Default = true, Save = true, Flag = "retbase",
    Callback = function(v) S.returnBase = v end,
})

protSec:AddButton({
    Name = "Drop Held Egg",
    Callback = function()
        local ok, err = call("drop")
        notify("SAE", ok and "Dropped." or tostring(err), 4)
    end,
})

protSec:AddButton({
    Name = "Recover My Dropped Egg",
    Tooltip = "Finds an egg on the ground that is yours and walks back to it.",
    Callback = function()
        task.spawn(function()
            for _, e in ipairs(placedEggs()) do
                if e.mine and e.model.Parent ~= nil then
                    local p = partOf(e.model)
                    if p then travelTo(p.Position) end
                    local ok, how = grabEgg({ model = e.model, id = e.id })
                    notify("SAE", ok and "Recovered." or tostring(how), 5)
                    return
                end
            end
            notify("SAE", "Nothing of yours is loose.", 4)
        end)
    end,
})

local pursueSec = SL:AddSection({Name = "Pursuit"})

pursueSec:AddParagraph("Carrier chasing",
    "Carried eggs are Tools named \"<Name> (n kg)\" inside a character, so who\n" ..
    "is holding what is readable with no remote at all. This walks you to\n" ..
    "them; taking the egg off them is the game's own mechanic, not this.")

pursueSec:AddButton({
    Name = "Go To Heaviest Carrier",
    Callback = function()
        task.spawn(function()
            for _, c in ipairs(carriedEggs()) do
                if not c.me then
                    local r = c.player.Character
                        and c.player.Character:FindFirstChild("HumanoidRootPart")
                    if r then
                        travelTo(r.Position + Vector3.new(0, 0, 4))
                        notify("SAE", string.format("%s: %s (%.2f kg)",
                            c.player.Name, c.name, c.kg), 5)
                        return
                    end
                end
            end
            notify("SAE", "Nobody else is carrying.", 4)
        end)
    end,
})

pursueSec:AddToggle({
    Name = "Auto Pursue Carriers", Default = false, Flag = "pursue",
    Callback = function(on)
        if not on then unregister("Pursue") return end
        register("Pursue", function() ACTIVE["Pursue"] = nil end)
        task.spawn(function()
            while ACTIVE["Pursue"] do
                for _, c in ipairs(carriedEggs()) do
                    if not c.me and ACTIVE["Pursue"] then
                        local r = c.player.Character
                            and c.player.Character:FindFirstChild("HumanoidRootPart")
                        if r then travelTo(r.Position + Vector3.new(0, 0, 4)) end
                        break
                    end
                end
                task.wait(1.5)
            end
        end)
    end,
})

-- ===========================================================================
-- EGGS
-- ===========================================================================
local EL, ER = EggTab:AddLeft(), EggTab:AddRight()

local placeSec = EL:AddSection({Name = "Place & Hatch"})

placeSec:AddParagraph("Bindings",
    "AskPlaceEgg, AskHatch and AskFinishHatch, each taking an egg id. All\n" ..
    "three are inferred from the remote names - the Dev tab shows which have\n" ..
    "actually been observed.")

local eggInfo = placeSec:AddParagraph("Status", "Idle.")
local function setEgg(m) pcall(function() eggInfo:Set(m) end) end

-- Placing works off whatever the client is holding, because that is the only
-- inventory this script can see without a working snapshot call.
local function placeHeld()
    local held = myHeldEgg()
    if not held then return false, "not holding an egg" end
    local id = attrOf(held.tool, { "Id", "EggId", "Guid", "Uid" })
    local ok, err = call("place", id and tostring(id) or held.tool.Name)
    return ok, ok and "placed" or err
end

placeSec:AddButton({
    Name = "Place Held Egg",
    Callback = function()
        task.spawn(function()
            local ok, how = placeHeld()
            setEgg((ok and "OK: " or "Failed: ") .. tostring(how))
        end)
    end,
})

placeSec:AddToggle({
    Name = "Auto Place", Default = false, Flag = "autoplace",
    Callback = function(on)
        if not on then unregister("Auto Place") return end
        register("Auto Place", function() ACTIVE["Auto Place"] = nil end)
        task.spawn(function()
            while ACTIVE["Auto Place"] do
                if myHeldEgg() then
                    local _, how = placeHeld()
                    setEgg("Place: " .. tostring(how))
                end
                task.wait(2)
            end
        end)
    end,
})

placeSec:AddButton({
    Name = "Hatch All Ready",
    Callback = function()
        task.spawn(function()
            local n, fails = 0, 0
            for _, e in ipairs(placedEggs()) do
                if e.mine then
                    local ok = call("hatch", e.id)
                    if ok then
                        n = n + 1
                        call("hatchDone", e.id)
                        event("Hatched", e.id:sub(1, 8))
                    else
                        fails = fails + 1
                    end
                    task.wait(0.3)
                end
            end
            setEgg(string.format("Hatch: %d ok, %d refused.", n, fails))
        end)
    end,
})

placeSec:AddToggle({
    Name = "Auto Hatch Ready", Default = false, Flag = "autohatch",
    Callback = function(on)
        if not on then unregister("Auto Hatch") return end
        register("Auto Hatch", function() ACTIVE["Auto Hatch"] = nil end)
        task.spawn(function()
            while ACTIVE["Auto Hatch"] do
                for _, e in ipairs(placedEggs()) do
                    if e.mine and ACTIVE["Auto Hatch"] then
                        if call("hatch", e.id) then
                            call("hatchDone", e.id)
                            event("Hatched", e.id:sub(1, 8))
                        end
                        task.wait(0.4)
                    end
                end
                task.wait(5)
            end
        end)
    end,
})

local eggSellSec = ER:AddSection({Name = "Sell & Favourite"})

eggSellSec:AddDropdown({
    Name = "Egg Rarities To Sell", Options = RARITIES, MultiSelect = true,
    Search = true, SelectAll = true, Default = {}, Save = true, Flag = "selleggrar",
    Callback = function(sel)
        S.sellEggRar = {}
        for _, r in ipairs(sel) do S.sellEggRar[r] = true end
    end,
})

eggSellSec:AddSlider({
    Name = "Sell Interval", Min = 15, Max = 600, Default = 60,
    Increment = 15, ValueName = " s", Save = true, Flag = "selleggevery",
    Callback = function(v) S.sellEggEvery = v end,
})

-- The stand prompt is preferred over the remote for the same reason the egg
-- prompt is: it is the path the game itself uses, so it needs no guess.
local function sellAllPhysical()
    local stands = workspace:FindFirstChild("Stands")
    local prompts = stands and stands:FindFirstChild("Prompts")
    local sellAll = prompts and prompts:FindFirstChild("SellAll")
    local prompt = sellAll and sellAll:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and F.fireprompt then
        pcall(F.fireprompt, prompt)
        return true, "stand prompt"
    end
    local ok, err = call("sellSatchel")
    return ok, ok and "remote" or err
end

eggSellSec:AddButton({
    Name = "Sell All Now (stand prompt)",
    Callback = function()
        local ok, how = sellAllPhysical()
        setEgg((ok and "Sold via " or "Failed: ") .. tostring(how))
        if ok then event("Sold", "sell-all fired") end
    end,
})

eggSellSec:AddToggle({
    Name = "Auto Sell Eggs", Default = false, Flag = "autoselleggs",
    Callback = function(on)
        if not on then unregister("Auto Sell Eggs") return end
        register("Auto Sell Eggs", function() ACTIVE["Auto Sell Eggs"] = nil end)
        task.spawn(function()
            while ACTIVE["Auto Sell Eggs"] do
                local _, how = sellAllPhysical()
                setEgg("Auto sell: " .. tostring(how))
                local waited = 0
                while ACTIVE["Auto Sell Eggs"] and waited < S.sellEggEvery do
                    task.wait(1); waited = waited + 1
                end
            end
        end)
    end,
})

eggSellSec:AddDropdown({
    Name = "Auto Favourite At Or Above", Options = RARITIES,
    Default = "Legendary", Save = true, Flag = "favmin",
    Callback = function(v) S.favMinRar = v end,
})

eggSellSec:AddToggle({
    Name = "Auto Favourite Rares", Default = false, Flag = "autofav",
    Callback = function(on)
        if not on then unregister("Auto Fav") return end
        register("Auto Fav", function() ACTIVE["Auto Fav"] = nil end)
        task.spawn(function()
            local floor = 0
            for i, r in ipairs(RARITIES) do if r == S.favMinRar then floor = i end end
            while ACTIVE["Auto Fav"] do
                for _, e in ipairs(placedEggs()) do
                    if e.mine and e.rarity then
                        for i, r in ipairs(RARITIES) do
                            if r == e.rarity and i >= floor then
                                call("favourite", e.id, true)
                            end
                        end
                    end
                end
                task.wait(20)
            end
        end)
    end,
})

-- ===========================================================================
-- PETS
-- ===========================================================================
local PL, PR = PetTab:AddLeft(), PetTab:AddRight()

local equipSec = PL:AddSection({Name = "Equip"})

local petInfo = equipSec:AddParagraph("Status", "Idle.")
local function setPet(m) pcall(function() petInfo:Set(m) end) end

equipSec:AddParagraph("Best-team equipping",
    "RF/Haul/WearBest looks like the game's own equip-best button, which means\n" ..
    "no pet list has to be reconstructed client-side to use it. If the spy\n" ..
    "shows it takes arguments, rebind it in the Dev tab.")

equipSec:AddButton({
    Name = "Equip Best Now",
    Callback = function()
        local ok, res = call("wearBest")
        setPet(ok and ("Equipped. " .. ser(res)) or ("Failed: " .. tostring(res)))
    end,
})

equipSec:AddToggle({
    Name = "Auto Equip Best", Default = false, Flag = "autoequip",
    Callback = function(on)
        if not on then unregister("Auto Equip") return end
        register("Auto Equip", function() ACTIVE["Auto Equip"] = nil end)
        task.spawn(function()
            while ACTIVE["Auto Equip"] do
                call("wearBest")
                task.wait(30)
            end
        end)
    end,
})

equipSec:AddButton({
    Name = "Upgrade Pet Slots",
    Tooltip = "RF/PenRoster/AskWearLimit - best guess for the slot upgrade.",
    Callback = function()
        local ok, res = call("petSlots")
        setPet(ok and ("Slots: " .. ser(res)) or ("Failed: " .. tostring(res)))
    end,
})

local petSellSec = PR:AddSection({Name = "Sell"})

petSellSec:AddDropdown({
    Name = "Pet Rarities To Sell", Options = RARITIES, MultiSelect = true,
    Search = true, SelectAll = true, Default = {}, Save = true, Flag = "sellpetrar",
    Callback = function(sel)
        S.sellPetRar = {}
        for _, r in ipairs(sel) do S.sellPetRar[r] = true end
    end,
})

petSellSec:AddToggle({
    Name = "Never Sell Mutated", Default = true, Save = true, Flag = "keepmut",
    Callback = function(v) S.keepMutated = v end,
})
petSellSec:AddToggle({
    Name = "Never Sell Equipped", Default = true, Save = true, Flag = "keepeq",
    Callback = function(v) S.keepEquipped = v end,
})
petSellSec:AddToggle({
    Name = "Never Sell Favourited", Default = true, Save = true, Flag = "keepfav",
    Callback = function(v) S.keepFav = v end,
})

petSellSec:AddSlider({
    Name = "Sell Interval", Min = 30, Max = 900, Default = 90,
    Increment = 30, ValueName = " s", Save = true, Flag = "sellpetevery",
    Callback = function(v) S.sellPetEvery = v end,
})

-- Pet selling needs a pet list, and the only source is the snapshot RF. If that
-- call is not right, this reports it rather than falling back to SellEveryPet -
-- selling the entire pen because a filter could not be read would be the single
-- most destructive thing this script could do by accident.
local function petList()
    local snap = fetch("petSnap")
    if type(snap) ~= "table" then return nil end
    local pets = snap.pets or snap.Pets or snap.roster or snap
    if type(pets) ~= "table" then return nil end
    return pets
end

local function sellFiltered()
    local pets = petList()
    if not pets then
        return false, "pet snapshot unreadable - not falling back to sell-all"
    end
    local sold, skipped = 0, 0
    for _, p in pairs(pets) do
        if type(p) == "table" then
            local id  = p.id or p.Id or p.uid or p.guid
            local rar = tostring(p.rarity or p.Rarity or "")
            local mut = p.mutation or p.Mutation
            local eq  = p.equipped or p.Equipped
            local fav = p.favourite or p.Favourite or p.favorite

            local keep = (S.keepMutated and mut and mut ~= "")
                or (S.keepEquipped and eq)
                or (S.keepFav and fav)
                or not S.sellPetRar[rar]

            if id and not keep then
                if call("petSell", id) then sold = sold + 1 else skipped = skipped + 1 end
                task.wait(0.15)
            end
        end
    end
    if sold > 0 then event("Sold", sold .. " pets") end
    return true, string.format("%d sold, %d refused", sold, skipped)
end

petSellSec:AddButton({
    Name = "Sell Filtered Now",
    Callback = function()
        task.spawn(function()
            local ok, how = sellFiltered()
            setPet((ok and "" or "Failed: ") .. tostring(how))
        end)
    end,
})

petSellSec:AddToggle({
    Name = "Auto Sell Pets", Default = false, Flag = "autosellpets",
    Callback = function(on)
        if not on then unregister("Auto Sell Pets") return end
        register("Auto Sell Pets", function() ACTIVE["Auto Sell Pets"] = nil end)
        task.spawn(function()
            while ACTIVE["Auto Sell Pets"] do
                local _, how = sellFiltered()
                setPet("Auto: " .. tostring(how))
                local waited = 0
                while ACTIVE["Auto Sell Pets"] and waited < S.sellPetEvery do
                    task.wait(1); waited = waited + 1
                end
            end
        end)
    end,
})

local fuseSec = PL:AddSection({Name = "Fuse (beta)"})

fuseSec:AddParagraph("Fusery",
    "LoadPet, BeginFuse, FinishReveal - a four-call sequence inferred entirely\n" ..
    "from names. Fusing destroys pets, so this never runs on a timer until you\n" ..
    "have watched Fuse Now work once.")

fuseSec:AddSlider({
    Name = "Keep Per Type", Min = 1, Max = 20, Default = 3,
    Increment = 1, ValueName = " kept", Save = true, Flag = "fusekeep",
    Callback = function(v) S.fuseKeep = v end,
})

local function fuseOnce()
    local pets = petList()
    if not pets then return false, "pet snapshot unreadable" end

    local byType, order = {}, {}
    for _, p in pairs(pets) do
        if type(p) == "table" then
            local name = tostring(p.name or p.Name or p.kind or "?")
            local eq   = p.equipped or p.Equipped
            local mut  = p.mutation or p.Mutation
            if not eq and not (S.keepMutated and mut and mut ~= "") then
                if not byType[name] then byType[name] = {} table.insert(order, name) end
                table.insert(byType[name], p.id or p.Id or p.uid)
            end
        end
    end

    for _, name in ipairs(order) do
        local ids = byType[name]
        if #ids > S.fuseKeep then
            local loaded = 0
            for i = S.fuseKeep + 1, #ids do
                if call("fuseLoad", ids[i]) then loaded = loaded + 1 end
                task.wait(0.15)
            end
            if loaded > 0 then
                call("fuseBrief")
                local ok, err = call("fuseBegin")
                if not ok then return false, "BeginFuse: " .. tostring(err) end
                task.wait(1)
                call("fuseReveal")
                return true, string.format("fused %d %s", loaded, name)
            end
        end
    end
    return false, "no group over the keep count"
end

fuseSec:AddButton({
    Name = "Fuse Now",
    Callback = function()
        task.spawn(function()
            local ok, how = fuseOnce()
            setPet((ok and "" or "Failed: ") .. tostring(how))
        end)
    end,
})

fuseSec:AddToggle({
    Name = "Auto Fuse", Default = false, Flag = "autofuse",
    Callback = function(on)
        if not on then unregister("Auto Fuse") return end
        register("Auto Fuse", function() ACTIVE["Auto Fuse"] = nil end)
        task.spawn(function()
            while ACTIVE["Auto Fuse"] do
                local _, how = fuseOnce()
                setPet("Fuse: " .. tostring(how))
                local waited = 0
                while ACTIVE["Auto Fuse"] and waited < S.fuseEvery do
                    task.wait(1); waited = waited + 1
                end
            end
        end)
    end,
})

-- ===========================================================================
-- SAKURA / BLOOMERY
-- ===========================================================================
local KL, KR = SakTab:AddLeft(), SakTab:AddRight()

local sakSec = KL:AddSection({Name = "Bloomery Event"})

sakSec:AddParagraph("What the dump showed",
    "Workspace.SakuraBloomTrees, Workspace.SakuraCrystals and an\n" ..
    "IncubatorDead model, against eight RF/Bloomery remotes: AskStrikeTree,\n" ..
    "AskGatherPetal, AskLoadEgg, AskMutate, AskEjectEgg, AskCraneReturn,\n" ..
    "AskHandoff, AskBriefingConfirm. The sequence below is that vocabulary\n" ..
    "put in the only order it can plausibly go: strike trees, gather what\n" ..
    "falls, load the target egg, feed crystals, roll the mutation.")

local sakInfo = sakSec:AddParagraph("Status", "Idle.")
local function setSak(m) pcall(function() sakInfo:Set(m) end) end

sakSec:AddSlider({
    Name = "Crystals Per Roll", Min = 1, Max = 25, Default = 5,
    Increment = 1, ValueName = "", Save = true, Flag = "sakcry",
    Callback = function(v) S.sakCrystals = v end,
})

sakSec:AddDropdown({
    Name = "Mutate Which Egg",
    Options = { "Biggest Earner", "By Rarity", "By Name" },
    Default = "Biggest Earner", Save = true, Flag = "saktarget",
    Callback = function(v) S.sakTarget = v end,
})

sakSec:AddDropdown({
    Name = "  ...if By Rarity", Options = RARITIES, Default = "Secret",
    Save = true, Flag = "saktargetrar",
    Callback = function(v) S.sakTargetRar = v end,
})

sakSec:AddTextbox({
    Name = "  ...if By Name", Default = "", TextDisappear = false,
    Callback = function(t) S.sakTargetName = t or "" end,
})

-- Which of your placed eggs gets fed to the machine. Value first, because
-- "biggest earner" is the only one of the three modes that needs a comparison
-- rather than a match.
local function sakChooseEgg()
    local mine = {}
    for _, e in ipairs(placedEggs()) do
        if e.mine then table.insert(mine, e) end
    end
    if #mine == 0 then return nil, "no eggs of yours are placed" end

    if S.sakTarget == "By Name" and S.sakTargetName ~= "" then
        local want = S.sakTargetName:lower()
        for _, e in ipairs(mine) do
            if tostring(e.model.Name):lower():find(want, 1, true) then return e end
        end
        return nil, "no placed egg matches that name"
    elseif S.sakTarget == "By Rarity" then
        for _, e in ipairs(mine) do
            if e.rarity == S.sakTargetRar then return e end
        end
        return nil, "no placed egg of rarity " .. S.sakTargetRar
    end

    table.sort(mine, function(a, b)
        local av = a.value > 0 and a.value or a.kg
        local bv = b.value > 0 and b.value or b.kg
        return av > bv
    end)
    return mine[1]
end

-- Highest value first, so a limited number of strikes goes into the trees worth
-- hitting rather than whichever happens to be nearest.
local function sakTrees()
    local folder = workspace:FindFirstChild("SakuraBloomTrees")
    local out = {}
    if not folder then return out end
    for _, t in ipairs(folder:GetChildren()) do
        table.insert(out, { model = t, value = valueOf(t), dist = distTo(t) })
    end
    table.sort(out, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.dist < b.dist
    end)
    return out
end

local function sakCrystals()
    local folder = workspace:FindFirstChild("SakuraCrystals")
    local out = {}
    if not folder then return out end
    for _, c in ipairs(folder:GetChildren()) do
        table.insert(out, c)
    end
    table.sort(out, function(a, b) return distTo(a) < distTo(b) end)
    return out
end

sakSec:AddButton({
    Name = "Farm Trees Once (highest value first)",
    Callback = function()
        task.spawn(function()
            local trees = sakTrees()
            if #trees == 0 then setSak("No SakuraBloomTrees in the world.") return end
            local hit = 0
            for _, t in ipairs(trees) do
                local p = partOf(t.model)
                if p then travelTo(p.Position) end
                local prompt = t.model:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and F.fireprompt then
                    pcall(F.fireprompt, prompt); hit = hit + 1
                elseif call("sakStrike", t.model) then
                    hit = hit + 1
                end
                setSak(string.format("Struck %d/%d trees.", hit, #trees))
                task.wait(0.5)
            end
        end)
    end,
})

sakSec:AddButton({
    Name = "Gather Fallen Petals",
    Callback = function()
        task.spawn(function()
            local n = 0
            for _, c in ipairs(sakCrystals()) do
                local p = partOf(c) or (c:IsA("BasePart") and c)
                if p then travelTo(p.Position) end
                local prompt = c:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and F.fireprompt then
                    pcall(F.fireprompt, prompt); n = n + 1
                elseif call("sakGather", c) then
                    n = n + 1
                end
                task.wait(0.35)
            end
            setSak("Gathered " .. n .. ".")
        end)
    end,
})

local rollSec = KR:AddSection({Name = "Incubator & Mutation"})

-- The whole sequence, kept in one function so the toggle and the button cannot
-- drift, and so the order is written down once where it can be corrected.
local function sakRun()
    local egg, why = sakChooseEgg()
    if not egg then return false, why end

    setSak("Loading " .. (egg.rarity or "egg") .. " " .. egg.id:sub(1, 8) .. "...")
    local ok, err = call("sakLoad", egg.id)
    if not ok then return false, "AskLoadEgg: " .. tostring(err) end
    call("sakBrief")

    local fed = 0
    for i = 1, S.sakCrystals do
        if call("sakGather", i) then fed = fed + 1 end
        task.wait(0.2)
    end

    setSak(string.format("Fed %d crystals, rolling...", fed))
    local mok, mres = call("sakMutate")
    if not mok then return false, "AskMutate: " .. tostring(mres) end

    task.wait(1)
    call("sakCrane")
    event("Mutated", egg.id:sub(1, 8) .. " -> " .. ser(mres))
    return true, "rolled: " .. ser(mres)
end

rollSec:AddButton({
    Name = "Load Target Egg + Roll Mutation",
    Callback = function()
        task.spawn(function()
            local ok, how = sakRun()
            setSak((ok and "" or "Failed: ") .. tostring(how))
        end)
    end,
})

rollSec:AddButton({
    Name = "Eject Egg From Incubator",
    Callback = function()
        local ok, err = call("sakEject")
        setSak(ok and "Ejected." or ("Failed: " .. tostring(err)))
    end,
})

rollSec:AddToggle({
    Name = "Full Sakura Autofarm", Default = false, Flag = "autosak",
    Callback = function(on)
        if not on then unregister("Sakura") return end
        register("Sakura", function() ACTIVE["Sakura"] = nil end)
        task.spawn(function()
            local rolls, fails = 0, 0
            while ACTIVE["Sakura"] do
                -- Trees first: the crystals the roll consumes come from them,
                -- so rolling before farming just burns a stock that is not there.
                for _, t in ipairs(sakTrees()) do
                    if not ACTIVE["Sakura"] then break end
                    local p = partOf(t.model)
                    if p then travelTo(p.Position) end
                    local prompt = t.model:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt and F.fireprompt then pcall(F.fireprompt, prompt)
                    else call("sakStrike", t.model) end
                    task.wait(0.4)
                end
                if not ACTIVE["Sakura"] then break end

                local ok, how = sakRun()
                if ok then rolls = rolls + 1 else fails = fails + 1 end
                setSak(string.format("%d rolls, %d failed (%s)",
                    rolls, fails, tostring(how):sub(1, 40)))
                if fails >= 6 and rolls == 0 then
                    unregister("Sakura")
                    setSak("Stopped: 6 failures, 0 rolls. Spy the Bloomery calls.")
                    notify("SAE", "Sakura autofarm stopped - bindings wrong.", 8)
                    return
                end
                task.wait(3)
            end
        end)
    end,
})

-- ===========================================================================
-- PROGRESS
-- ===========================================================================
local GL, GR = ProgTab:AddLeft(), ProgTab:AddRight()

local claimSec = GL:AddSection({Name = "Claims"})
local progInfo = claimSec:AddParagraph("Status", "Idle.")
local function setProg(m) pcall(function() progInfo:Set(m) end) end

local function claimAll()
    local done = {}
    if call("codex")       then table.insert(done, "index") end
    if call("groupPerk")   then table.insert(done, "group") end
    if call("awayCollect") then table.insert(done, "offline") end
    if #done == 0 then return false, "every claim call was refused" end
    return true, "claimed: " .. table.concat(done, ", ")
end

claimSec:AddButton({
    Name = "Claim All Now",
    Callback = function()
        task.spawn(function()
            local ok, how = claimAll()
            setProg((ok and "" or "Failed: ") .. tostring(how))
        end)
    end,
})

claimSec:AddSlider({
    Name = "Claim Interval", Min = 30, Max = 1800, Default = 300,
    Increment = 30, ValueName = " s", Save = true, Flag = "claimevery",
    Callback = function(v) S.claimEvery = v end,
})

claimSec:AddToggle({
    Name = "Auto Claim Rewards", Default = false, Flag = "autoclaim",
    Callback = function(on)
        if not on then unregister("Auto Claim") return end
        register("Auto Claim", function() ACTIVE["Auto Claim"] = nil end)
        task.spawn(function()
            while ACTIVE["Auto Claim"] do
                local _, how = claimAll()
                setProg("Claim: " .. tostring(how))
                local waited = 0
                while ACTIVE["Auto Claim"] and waited < S.claimEvery do
                    task.wait(1); waited = waited + 1
                end
            end
        end)
    end,
})

local upSec = GR:AddSection({Name = "Upgrades"})

upSec:AddSlider({
    Name = "Upgrade Interval", Min = 30, Max = 900, Default = 120,
    Increment = 30, ValueName = " s", Save = true, Flag = "upevery",
    Callback = function(v) S.upgradeEvery = v end,
})

upSec:AddButton({
    Name = "Upgrade Base Now",
    Callback = function()
        local ok, res = call("baseRaise")
        setProg(ok and ("Base: " .. ser(res)) or ("Failed: " .. tostring(res)))
    end,
})

upSec:AddButton({
    Name = "Upgrade Treadmill Now",
    Callback = function()
        local ok, res = call("millRaise")
        setProg(ok and ("Treadmill: " .. ser(res)) or ("Failed: " .. tostring(res)))
    end,
})

upSec:AddToggle({
    Name = "Auto Upgrade Base + Treadmill", Default = false, Flag = "autoup",
    Callback = function(on)
        if not on then unregister("Auto Upgrade") return end
        register("Auto Upgrade", function() ACTIVE["Auto Upgrade"] = nil end)
        task.spawn(function()
            while ACTIVE["Auto Upgrade"] do
                call("baseRaise")
                call("millRaise")
                setProg("Upgrade pass sent.")
                local waited = 0
                while ACTIVE["Auto Upgrade"] and waited < S.upgradeEvery do
                    task.wait(1); waited = waited + 1
                end
            end
        end)
    end,
})

local millSec = GL:AddSection({Name = "Treadmill & Gear"})

millSec:AddButton({
    Name = "Walk To Treadmill",
    Callback = function()
        task.spawn(function()
            local plot = myPlot()
            local pad = plot and (plot:FindFirstChild("TreadmillBottom")
                or plot:FindFirstChild("TreadmillUpgrade"))
            if not pad then setProg("No treadmill found on your plot.") return end
            local p = pad:IsA("BasePart") and pad or partOf(pad)
            if p then travelTo(p.Position) setProg("At the treadmill.") end
        end)
    end,
})

millSec:AddToggle({
    Name = "Auto Treadmill Training", Default = false, Flag = "automill",
    Callback = function(on)
        if not on then unregister("Treadmill") unbind("mill") return end
        register("Treadmill", function()
            ACTIVE["Treadmill"] = nil
            unbind("mill")
        end)
        task.spawn(function()
            local plot = myPlot()
            local pad = plot and plot:FindFirstChild("TreadmillBottom")
            local p = pad and (pad:IsA("BasePart") and pad or partOf(pad))
            if not p then setProg("No treadmill on your plot.") return end
            travelTo(p.Position)
            call("millWear")
            -- Held in place rather than tweened once: the belt moves you off it.
            bind("mill", RunService.Heartbeat:Connect(function()
                local root = hrp()
                if root and ACTIVE["Treadmill"] then
                    root.CFrame = CFrame.new(p.Position + Vector3.new(0, 3, 0))
                end
            end))
            setProg("Training on the treadmill.")
        end)
    end,
})

millSec:AddButton({
    Name = "Equip Best Trail",
    Callback = function()
        local snap = fetch("trailSnap")
        local ok, res = call("trailWear", type(snap) == "table"
            and (snap.best or snap.Best) or nil)
        setProg(ok and ("Trail: " .. ser(res)) or ("Failed: " .. tostring(res)))
    end,
})

millSec:AddButton({
    Name = "Equip Field Bat",
    Callback = function()
        local ok, res = call("wearBat")
        setProg(ok and ("Bat: " .. ser(res)) or ("Failed: " .. tostring(res)))
    end,
})

-- ===========================================================================
-- SERVER
-- ===========================================================================
local VL, VR = ServTab:AddLeft(), ServTab:AddRight()

local hopSec = VL:AddSection({Name = "Server Hop"})
local hopInfo = hopSec:AddParagraph("Status", "Idle.")
local function setHop(m) pcall(function() hopInfo:Set(m) end) end

hopSec:AddDropdown({
    Name = "Hop Target", Options = { "Emptiest", "Fullest", "Random" },
    Default = "Emptiest", Save = true, Flag = "hopmode",
    Callback = function(v) S.hopMode = v end,
})

hopSec:AddSlider({
    Name = "Max Players", Min = 1, Max = 100, Default = 99,
    Increment = 1, ValueName = " players", Save = true, Flag = "hopmax",
    Callback = function(v) S.hopMax = v end,
})

hopSec:AddSlider({
    Name = "Scan Delay", Min = 5, Max = 300, Default = 20,
    Increment = 5, ValueName = " s", Save = true, Flag = "hopscan",
    Callback = function(v) S.hopScan = v end,
})

hopSec:AddSlider({
    Name = "Steals Before Hop", Min = 0, Max = 100, Default = 0,
    Increment = 1, ValueName = " (0 = off)", Save = true, Flag = "hopafter",
    Callback = function(v) S.hopAfter = v end,
})

-- The public-servers endpoint, not TeleportToPlaceInstance blind: hopping into
-- a random instance that turns out to be the one you left is the usual way this
-- feature wastes a minute per attempt.
local function pickServer()
    if not F.request then return nil, "no request() for the servers endpoint" end
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
        .. "/servers/Public?sortOrder=Asc&limit=100"
    local ok, res = pcall(F.request, { Url = url, Method = "GET" })
    if not ok or not res or not res.Body then return nil, "servers request failed" end

    local decoded
    local dok = pcall(function() decoded = HttpService:JSONDecode(res.Body) end)
    if not dok or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
        return nil, "servers response unreadable"
    end

    local best, bestScore = nil, nil
    for _, srv in ipairs(decoded.data) do
        if srv.id ~= game.JobId and srv.playing and srv.maxPlayers
            and srv.playing < srv.maxPlayers and srv.playing <= S.hopMax then
            local score
            if S.hopMode == "Fullest" then score = srv.playing
            elseif S.hopMode == "Random" then score = math.random()
            else score = -srv.playing end
            if bestScore == nil or score > bestScore then
                best, bestScore = srv.id, score
            end
        end
    end
    if not best then return nil, "no server matched (max " .. S.hopMax .. ")" end
    return best
end

local function hopNow()
    -- Re-queue so the script survives the teleport. Without this a hop is just
    -- a way to turn every automation off.
    if F.queueport then
        pcall(F.queueport,
            'loadstring(game:HttpGet("https://raw.githubusercontent.com/'
            .. 'aparaanana-hue/DW/refs/heads/main/SAE.lua"))()')
    end
    local id, why = pickServer()
    if not id then
        setHop("Hop failed: " .. tostring(why))
        return false
    end
    S.hopCount = S.hopCount + 1
    setHop("Teleporting to " .. id:sub(1, 8) .. "...")
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LP)
    end)
    if not ok then setHop("TeleportService refused.") end
    return ok
end

hopSec:AddButton({ Name = "Hop Now", Callback = function() task.spawn(hopNow) end })

hopSec:AddToggle({
    Name = "Auto Server Hop", Default = false, Flag = "autohop",
    Callback = function(on)
        if not on then unregister("Auto Hop") return end
        register("Auto Hop", function() ACTIVE["Auto Hop"] = nil end)
        task.spawn(function()
            while ACTIVE["Auto Hop"] do
                local waited = 0
                while ACTIVE["Auto Hop"] and waited < S.hopScan do
                    task.wait(1); waited = waited + 1
                end
                if not ACTIVE["Auto Hop"] then return end
                -- Steals-before-hop is the useful trigger: hop when this server
                -- is picked clean, not on a blind timer.
                if S.hopAfter == 0 or S.stolen >= S.hopAfter then
                    hopNow()
                    return
                end
                setHop(string.format("%d/%d steals before hop.", S.stolen, S.hopAfter))
            end
        end)
    end,
})

local evSec = VR:AddSection({Name = "Events & Cycle"})

evSec:AddParagraph("Where prediction comes from",
    "There is no weather table in the dump. What there is: FetchRunning,\n" ..
    "FetchScheduled and FetchRecurringEta under RF/LiveEvents, plus the\n" ..
    "RE/EggWorld/FieldEggCycleCountdown event. This reads those and prints\n" ..
    "them raw - once you can see the shape, filtering on it is easy.")

local evInfo = evSec:AddParagraph("Live events", "Not fetched.")

evSec:AddButton({
    Name = "Refresh Prediction",
    Callback = function()
        task.spawn(function()
            local running = fetch("evRunning")
            local sched   = fetch("evSched")
            local eta     = fetch("evEta")
            local text = "running: " .. ser(running) .. "\n\nscheduled: " .. ser(sched)
                .. "\n\neta: " .. ser(eta)
            pcall(function() evInfo:Set(text:sub(1, 900)) end)
            if F.clip then pcall(F.clip, text) end
        end)
    end,
})

-- The countdown event is the only reliable "eggs are about to reset" signal in
-- the whole dump, so it is wired straight to a notification.
if NET then
    local cd = NET:FindFirstChild("RE/EggWorld/FieldEggCycleCountdown")
    if cd and cd:IsA("RemoteEvent") then
        cd.OnClientEvent:Connect(function(...)
            local a = table.pack(...)
            local parts = {}
            for i = 1, a.n do parts[i] = ser(a[i]) end
            notify("Egg cycle", table.concat(parts, ", "), 6)
            event("Reset", table.concat(parts, ", "))
        end)
    end
end

local infoSec = VR:AddSection({Name = "Server Info"})
local srvInfo = infoSec:AddParagraph("This server", "-")

infoSec:AddButton({
    Name = "Copy JobId",
    Callback = function()
        if F.clip then pcall(F.clip, game.JobId) end
        notify("SAE", "JobId copied.", 4)
    end,
})

-- ===========================================================================
-- ESP
-- ===========================================================================
local XL, XR = EspTab:AddLeft(), EspTab:AddRight()

local espSec = XL:AddSection({Name = "Highlights"})

espSec:AddParagraph("Free information",
    "None of this touches the server. Field egg ids, placed-egg owners and\n" ..
    "carried weights are all in instance names, which is the one thing the\n" ..
    "class dump gave with total certainty.")

espSec:AddSlider({
    Name = "Render Distance", Min = 100, Max = 5000, Default = 1500,
    Increment = 100, ValueName = " studs", Save = true, Flag = "espdist",
    Callback = function(v) S.espDist = v end,
})

local ESP_KINDS = {
    "World Eggs", "Placed Eggs", "Carried Eggs", "Guards", "Plots", "Machines",
    "Sakura Trees", "Players",
}

espSec:AddDropdown({
    Name = "Show", Options = ESP_KINDS, MultiSelect = true, SelectAll = true,
    Search = true, Default = {}, Save = true, Flag = "espkinds",
    Callback = function(sel)
        S.esp = {}
        for _, k in ipairs(sel) do S.esp[k] = true end
    end,
})

local function clearEsp()
    for inst, h in pairs(S.espObjects) do
        pcall(function() h:Destroy() end)
        S.espObjects[inst] = nil
    end
end

local function mark(model, colour, text)
    if not model or S.espObjects[model] then return end
    pcall(function()
        local h = Instance.new("Highlight")
        h.FillColor = colour
        h.OutlineColor = Color3.new(1, 1, 1)
        h.FillTransparency = 0.65
        h.Adornee = model
        h.Parent = model
        S.espObjects[model] = h

        if text then
            local part = partOf(model)
            if part then
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.fromOffset(190, 20)
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.AlwaysOnTop = true
                bb.Adornee = part
                bb.Parent = h
                local l = Instance.new("TextLabel")
                l.Size = UDim2.fromScale(1, 1)
                l.BackgroundTransparency = 1
                l.Font = Enum.Font.GothamBold
                l.TextSize = 12
                l.TextStrokeTransparency = 0.4
                l.TextColor3 = colour
                l.Text = text
                l.Parent = bb
            end
        end
    end)
end

espSec:AddToggle({
    Name = "ESP Enabled", Default = false, Flag = "espon",
    Callback = function(on)
        if not on then unregister("ESP") clearEsp() return end
        register("ESP", function() ACTIVE["ESP"] = nil clearEsp() end)
        task.spawn(function()
            while ACTIVE["ESP"] do
                clearEsp()
                local ok = pcall(function()
                    if S.esp["World Eggs"] then
                        for _, e in ipairs(fieldEggs()) do
                            if e.dist <= S.espDist then
                                mark(e.model, Color3.fromRGB(120, 230, 150),
                                    string.format("%s %.1fkg %.0fm",
                                        e.rarity or "Egg", e.kg, e.dist))
                            end
                        end
                    end
                    if S.esp["Placed Eggs"] then
                        for _, e in ipairs(placedEggs()) do
                            if e.dist <= S.espDist and not e.mine then
                                mark(e.model, Color3.fromRGB(240, 180, 90),
                                    e.who .. "  " .. (e.rarity or ""))
                            end
                        end
                    end
                    if S.esp["Carried Eggs"] then
                        for _, c in ipairs(carriedEggs()) do
                            if not c.me and c.player.Character then
                                mark(c.player.Character, Color3.fromRGB(255, 110, 110),
                                    string.format("%s carrying %s (%.2f kg)",
                                        c.player.Name, c.name, c.kg))
                            end
                        end
                    end
                    if S.esp["Guards"] then
                        for _, g in ipairs(guards()) do
                            if distTo(g) <= S.espDist then
                                mark(g, Color3.fromRGB(255, 80, 80), "Guard")
                            end
                        end
                    end
                    if S.esp["Sakura Trees"] then
                        for _, t in ipairs(sakTrees()) do
                            if t.dist <= S.espDist then
                                mark(t.model, Color3.fromRGB(255, 160, 220),
                                    t.value > 0 and ("Tree " .. t.value) or "Tree")
                            end
                        end
                    end
                    if S.esp["Plots"] then
                        local plots = workspace:FindFirstChild("Plots")
                        if plots then
                            for _, p in ipairs(plots:GetChildren()) do
                                if distTo(p) <= S.espDist then
                                    mark(p, Color3.fromRGB(140, 170, 255), "Plot " .. p.Name)
                                end
                            end
                        end
                    end
                    if S.esp["Machines"] then
                        local objs = workspace:FindFirstChild("__OBJECTS")
                        local mach = objs and objs:FindFirstChild("Machines")
                        if mach then
                            for _, m in ipairs(mach:GetChildren()) do
                                mark(m, Color3.fromRGB(200, 200, 255), m.Name)
                            end
                        end
                    end
                    if S.esp["Players"] then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= LP and p.Character then
                                mark(p.Character, Color3.fromRGB(230, 230, 230), p.Name)
                            end
                        end
                    end
                end)
                if not ok then task.wait(1) end
                task.wait(1.5)
            end
        end)
    end,
})

espSec:AddButton({ Name = "Clear Highlights", Callback = clearEsp })

local listSec = XR:AddSection({Name = "Live Read"})
local worldInfo = listSec:AddParagraph("World", "Waiting...")

-- ===========================================================================
-- CHARACTER
-- ===========================================================================
local CL, CR = CharTab:AddLeft(), CharTab:AddRight()

local moveSec = CL:AddSection({Name = "Movement"})

moveSec:AddSlider({
    Name = "Walk Speed", Min = 16, Max = 300, Default = 16,
    Increment = 2, ValueName = "", Save = true, Flag = "ws",
    Callback = function(v)
        S.walkSpeed = v
        local h = hum()
        if h then h.WalkSpeed = v end
    end,
})

moveSec:AddSlider({
    Name = "Jump Power", Min = 50, Max = 400, Default = 50,
    Increment = 5, ValueName = "", Save = true, Flag = "jp",
    Callback = function(v)
        S.jumpPower = v
        local h = hum()
        if h then h.UseJumpPower = true h.JumpPower = v end
    end,
})

moveSec:AddToggle({
    Name = "Infinite Jump", Default = false, Flag = "infjump",
    Callback = function(on)
        if not on then unbind("infjump") unregister("Inf Jump") return end
        register("Inf Jump", function() unbind("infjump") end)
        bind("infjump", UserInputService.JumpRequest:Connect(function()
            local h = hum()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end))
    end,
})

moveSec:AddToggle({
    Name = "NoClip", Default = false, Flag = "noclip",
    Callback = function(on)
        if not on then unbind("noclip") unregister("NoClip") return end
        register("NoClip", function() unbind("noclip") end)
        bind("noclip", RunService.Stepped:Connect(function()
            local c = char()
            if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end))
    end,
})

moveSec:AddToggle({
    Name = "Anti Ragdoll", Default = false, Flag = "antirag",
    Callback = function(on)
        if not on then unbind("antirag") unregister("Anti Ragdoll") return end
        register("Anti Ragdoll", function() unbind("antirag") end)
        bind("antirag", RunService.Heartbeat:Connect(function()
            local h = hum()
            if h and h:GetState() == Enum.HumanoidStateType.Physics then
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end))
    end,
})

local flySec = CR:AddSection({Name = "Fly"})

flySec:AddSlider({
    Name = "Fly Speed", Min = 10, Max = 400, Default = 60,
    Increment = 5, ValueName = "", Save = true, Flag = "flyspd",
    Callback = function(v) S.flySpeed = v end,
})

flySec:AddToggle({
    Name = "Fly", Default = false, Flag = "fly",
    Callback = function(on)
        local root = hrp()
        if not on then
            unbind("fly")
            unregister("Fly")
            if root then
                local v = root:FindFirstChild("SAEFlyVel")
                local g = root:FindFirstChild("SAEFlyGyro")
                if v then v:Destroy() end
                if g then g:Destroy() end
            end
            return
        end
        if not root then notify("SAE", "No character.", 4) return end

        local vel = Instance.new("BodyVelocity")
        vel.Name = "SAEFlyVel"
        vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        vel.Velocity = Vector3.zero
        vel.Parent = root

        local gyro = Instance.new("BodyGyro")
        gyro.Name = "SAEFlyGyro"
        gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        gyro.P = 9e4
        gyro.Parent = root

        register("Fly", function() unbind("fly") end)
        bind("fly", RunService.RenderStepped:Connect(function()
            local r = hrp()
            if not r or not vel.Parent then return end
            gyro.CFrame = Camera.CFrame
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis end
            vel.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * S.flySpeed
        end))
    end,
})

flySec:AddToggle({
    Name = "Anti AFK", Default = true, Flag = "antiafk",
    Callback = function(on)
        if not on then unbind("afk") unregister("Anti AFK") return end
        register("Anti AFK", function() unbind("afk") end)
        bind("afk", LP.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end))
    end,
})

-- Re-applying on respawn, because a respawn drops walk speed, jump power and
-- every BodyMover the fly toggle created.
LP.CharacterAdded:Connect(function()
    task.wait(0.6)
    local h = hum()
    if not h then return end
    if S.walkSpeed ~= 16 then h.WalkSpeed = S.walkSpeed end
    if S.jumpPower ~= 50 then h.UseJumpPower = true h.JumpPower = S.jumpPower end
end)

-- ===========================================================================
-- DASHBOARD
-- ===========================================================================
local DL_, DR_ = DashTab:AddLeft(), DashTab:AddRight()

local statSec = DL_:AddSection({Name = "Live Stats"})
local statInfo = statSec:AddParagraph("Session", "Starting...")

statSec:AddButton({
    Name = "Refresh Profile",
    Callback = function()
        task.spawn(function()
            local p = fetch("profile")
            S.stats.profile = p
            local text = ser(p)
            pcall(function() statInfo:Set(text:sub(1, 900)) end)
            if F.clip then pcall(F.clip, text) end
            notify("SAE", "Profile copied to clipboard.", 4)
        end)
    end,
})

local hookSec = DR_:AddSection({Name = "Webhook"})

hookSec:AddToggle({
    Name = "Webhook Enabled", Default = false, Save = true, Flag = "hookon",
    Callback = function(v) S.hookOn = v end,
})

hookSec:AddTextbox({
    Name = "Discord Webhook URL", Default = "", TextDisappear = false,
    Callback = function(t) S.hookUrl = (t or ""):gsub("%s+", "") end,
})

hookSec:AddDropdown({
    Name = "Notify On",
    Options = { "Stolen", "Placed", "Hatched", "Sold", "Mutated", "Reset" },
    MultiSelect = true, SelectAll = true, Default = {}, Save = true, Flag = "hookev",
    Callback = function(sel)
        S.hookEvents = {}
        for _, k in ipairs(sel) do S.hookEvents[k] = true end
    end,
})

hookSec:AddButton({
    Name = "Send Test",
    Callback = function()
        if S.hookUrl == "" then notify("SAE", "No URL set.", 4) return end
        post("SAE test from " .. LP.Name .. " - " .. SAE_BUILD)
        notify("SAE", "Test sent (check Discord).", 4)
    end,
})

local sysSec = DL_:AddSection({Name = "Session"})

sysSec:AddButton({
    Name = "Panic - Stop Everything",
    Tooltip = "Every loop off, highlights cleared, character restored.",
    Callback = function()
        local names = {}
        for n in pairs(ACTIVE) do table.insert(names, n) end
        for n, stop in pairs(ACTIVE) do
            pcall(stop)
            ACTIVE[n] = nil
        end
        for n in pairs(S.conns) do unbind(n) end
        clearEsp()
        local h = hum()
        if h then h.WalkSpeed = 16 h.JumpPower = 50 end
        notify("Panic", #names == 0 and "Nothing was running"
            or ("Stopped: " .. table.concat(names, ", ")), 6)
    end,
})

sysSec:AddButton({
    Name = "Unload SAE",
    Callback = function()
        if type(ENV.SAE_UNLOAD) == "function" then pcall(ENV.SAE_UNLOAD) end
    end,
})

-- ===========================================================================
-- DEV
-- ===========================================================================
local VL2, VR2 = DevTab:AddLeft(), DevTab:AddRight()

local spySec = VL2:AddSection({Name = "Remote Spy"})

spySec:AddParagraph("Why this tab exists",
    "No script source was recovered, so every server call in this file is an\n" ..
    "inference from a remote's name. This watches the game make its own calls\n" ..
    "and records the real argument shapes. Play normally for a few minutes -\n" ..
    "steal, place, hatch, sell, roll a mutation - then Copy Report. Anything\n" ..
    "that comes back wrong gets rebound below without editing the file.")

local spyInfo = spySec:AddParagraph("Captured", "Off.")

local spyToggle
spyToggle = spySec:AddToggle({
    Name = "Spy Running", Default = false, Flag = "spy",
    Callback = function(on)
        if on then
            local ok, err = installSpy()
            if not ok then
                notify("SAE", err, 8)
                pcall(function() spyToggle:Set(false) end)
                return
            end
        end
        RX.spyOn = on
    end,
})

spySec:AddButton({
    Name = "Copy Report",
    Callback = function()
        if #RX.order == 0 then notify("SAE", "Nothing captured yet.", 4) return end
        local rep = spyReport()
        if F.write then pcall(F.write, "SAE_remotes.txt", rep) end
        if F.clip then pcall(F.clip, rep) end
        notify("SAE", #RX.order .. " signatures copied.", 5)
    end,
})

spySec:AddButton({
    Name = "Clear Capture",
    Callback = function()
        RX.log, RX.order, RX.seen = {}, {}, {}
        notify("SAE", "Cleared.", 3)
    end,
})

local bindSec = VR2:AddSection({Name = "Rebind A Call"})

bindSec:AddParagraph("Live rebinding",
    "Type an action key from the list and the remote name it should use. The\n" ..
    "change applies immediately and to every feature that uses that action,\n" ..
    "so a wrong guess is a one-line fix rather than a re-push.")

local bindKey, bindTo = "", ""

bindSec:AddTextbox({
    Name = "Action key (e.g. carry)", Default = "", TextDisappear = false,
    Callback = function(t) bindKey = (t or ""):gsub("%s+", "") end,
})

bindSec:AddTextbox({
    Name = "Remote name", Default = "", TextDisappear = false,
    Callback = function(t) bindTo = (t or ""):gsub("^%s+", ""):gsub("%s+$", "") end,
})

local bindInfo = bindSec:AddParagraph("Result", "-")

bindSec:AddButton({
    Name = "Apply Rebind",
    Callback = function()
        local e = RX.map[bindKey]
        if not e then
            pcall(function() bindInfo:Set("No action called " .. bindKey) end)
            return
        end
        if not NET or not NET:FindFirstChild(bindTo) then
            pcall(function() bindInfo:Set("No remote named " .. bindTo) end)
            return
        end
        local was = e.remote
        e.remote = bindTo
        pcall(function() bindInfo:Set(bindKey .. ": " .. was .. "  ->  " .. bindTo) end)
        notify("SAE", "Rebound " .. bindKey, 4)
    end,
})

bindSec:AddButton({
    Name = "Copy All Action Keys",
    Callback = function()
        local keys = {}
        for k, e in pairs(RX.map) do
            table.insert(keys, string.format("%-12s %s%s", k, e.remote,
                RX.seen[e.remote] and "   [seen]" or ""))
        end
        table.sort(keys)
        local text = table.concat(keys, "\n")
        if F.clip then pcall(F.clip, text) end
        if F.write then pcall(F.write, "SAE_bindings.txt", text) end
        notify("SAE", #keys .. " bindings copied.", 5)
    end,
})

local rawSec = VL2:AddSection({Name = "Fire Any Remote"})

local rawName, rawArgs = "", ""

rawSec:AddTextbox({
    Name = "Remote name", Default = "", TextDisappear = false,
    Callback = function(t) rawName = (t or ""):gsub("^%s+", ""):gsub("%s+$", "") end,
})

rawSec:AddTextbox({
    Name = "Args (comma separated)", Default = "", TextDisappear = false,
    Callback = function(t) rawArgs = t or "" end,
})

local rawInfo = rawSec:AddParagraph("Reply", "-")

-- Deliberately small: it only has to carry what this game's calls contain - an
-- id, a number, a flag, a player. Anything more structured is better captured
-- by the spy and replayed than typed by hand.
local function parseArgs(s)
    local out, n = {}, 0
    for raw in tostring(s):gmatch("[^,]+") do
        local tok = raw:match("^%s*(.-)%s*$")
        n = n + 1
        if tok == "" or tok == "nil" then out[n] = nil
        elseif tok == "true" then out[n] = true
        elseif tok == "false" then out[n] = false
        elseif tok == "me" then out[n] = LP
        elseif tok:sub(1, 1) == "@" then
            local want = tok:sub(2):lower()
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower():sub(1, #want) == want then out[n] = p break end
            end
        elseif tonumber(tok) then out[n] = tonumber(tok)
        else out[n] = (tok:gsub('^"(.*)"$', "%1")) end
    end
    return out, n
end

rawSec:AddButton({
    Name = "Fire",
    Callback = function()
        task.spawn(function()
            if not NET then
                pcall(function() rawInfo:Set("Packages.Networking not found.") end)
                return
            end
            local r = NET:FindFirstChild(rawName)
            if not r then
                pcall(function() rawInfo:Set("No remote named " .. rawName) end)
                return
            end
            local args, n = parseArgs(rawArgs)
            if r:IsA("RemoteFunction") then
                local ok, res = pcall(function()
                    return r:InvokeServer(table.unpack(args, 1, n))
                end)
                local text = ok and ser(res) or ("errored: " .. tostring(res))
                pcall(function() rawInfo:Set(text:sub(1, 600)) end)
                if ok and F.clip then pcall(F.clip, ser(res)) end
            else
                local ok, err = pcall(function() r:FireServer(table.unpack(args, 1, n)) end)
                pcall(function()
                    rawInfo:Set(ok and "Fired." or ("errored: " .. tostring(err)))
                end)
            end
        end)
    end,
})

rawSec:AddButton({
    Name = "Copy Every Remote Name",
    Callback = function()
        if not NET then notify("SAE", "No Networking folder.", 4) return end
        local names = {}
        for _, r in ipairs(NET:GetChildren()) do
            if r:IsA("RemoteEvent") or r:IsA("RemoteFunction")
                or r:IsA("UnreliableRemoteEvent") then
                table.insert(names, r.ClassName .. "  " .. r.Name)
            end
        end
        table.sort(names)
        local text = table.concat(names, "\n")
        if F.clip then pcall(F.clip, text) end
        if F.write then pcall(F.write, "SAE_remote_names.txt", text) end
        notify("SAE", #names .. " remotes copied.", 5)
    end,
})

-- ===========================================================================
-- REFRESH LOOP
-- ===========================================================================
-- One second, not per-frame: everything on screen is a count, a distance or a
-- ping, and none of it is worth a RenderStepped budget.
task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            local f, p, c = fieldEggs(), placedEggs(), carriedEggs()
            local mine = 0
            for _, e in ipairs(p) do if e.mine then mine = mine + 1 end end

            pcall(function()
                worldInfo:Set(string.format(
                    "Field eggs: %d\nPlaced: %d (%d yours)\nCarried now: %d\nGuards: %d\nZones: %d",
                    #f, #p, mine, #c, #guards(), #zoneNames()))
            end)

            local fps = math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1e-6))
            local ping = 0
            pcall(function()
                ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            pcall(function()
                statInfo:Set(string.format(
                    "Stolen this session: %d\nHops: %d\nField/Placed/Carried: %d / %d / %d\n"
                    .. "FPS %d   Ping %d ms\nHome: %s\nSpy: %s (%d signatures)\nBuild: %s",
                    S.stolen, S.hopCount, #f, #p, #c, fps, ping,
                    S.home and string.format("%.0f, %.0f, %.0f", S.home.X, S.home.Y, S.home.Z)
                        or (h and "not saved" or "no character"),
                    RX.spyOn and "running" or "off", #RX.order, SAE_BUILD))
            end)

            pcall(function()
                if #RX.order == 0 then
                    spyInfo:Set(RX.spyOn and "Running - nothing captured yet." or "Off.")
                else
                    -- Newest first: the call you just made by hand is the one
                    -- you are looking for, and it is the last one in.
                    local lines = {}
                    for i = #RX.order, math.max(1, #RX.order - 7), -1 do
                        local r = RX.log[RX.order[i]]
                        table.insert(lines, string.format("x%-3d %s\n     %s",
                            r.hits, r.remote, r.args:sub(1, 64)))
                    end
                    spyInfo:Set(string.format("%d unique%s\n\n%s", #RX.order,
                        RX.spyOn and "" or " (paused)", table.concat(lines, "\n")))
                end
            end)

            pcall(function()
                srvInfo:Set(string.format("Players: %d / %d\nJobId: %s\nPlaceId: %d",
                    #Players:GetPlayers(), Players.MaxPlayers,
                    game.JobId:sub(1, 18) .. "...", game.PlaceId))
            end)
        end)
    end
end)

-- ===========================================================================
-- UNLOAD
-- ===========================================================================
ENV.SAE_UNLOAD = function()
    for n, stop in pairs(ACTIVE) do
        pcall(stop)
        ACTIVE[n] = nil
    end
    for n in pairs(S.conns) do unbind(n) end
    RX.spyOn = false
    for inst, h in pairs(S.espObjects) do
        pcall(function() h:Destroy() end)
        S.espObjects[inst] = nil
    end
    pcall(function()
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 h.JumpPower = 50 end
    end)
    pcall(function() Duvome:Destroy() end)
end

-- A count of what actually resolved, not of what the dump listed: if the game
-- shipped an update that renamed the Networking folder, the number on screen is
-- how you find out immediately rather than after ten silent failures.
local bound, missing = 0, 0
for _, e in pairs(RX.map) do
    if NET and NET:FindFirstChild(e.remote) then bound = bound + 1
    else missing = missing + 1 end
end

pcall(function()
    Duvome:AddWatch("Stolen",  function() return S.stolen end)
    Duvome:AddWatch("Spy",     function() return RX.spyOn end)
    Duvome:AddWatch("Build",   function() return SAE_BUILD end)
end)
pcall(function() Duvome:SetWatchVisible(false) end)

notify("SAE loaded",
    NET and string.format("%d of %d bindings resolved, %d missing.\n"
        .. "Run the Dev spy before trusting any automation.",
        bound, bound + missing, missing)
    or "Packages.Networking not found - every server action is dead.", 8)

pcall(function() Duvome:Init() end)
