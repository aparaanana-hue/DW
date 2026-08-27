-- ===========================================================================
-- SAE - Steal An Egg toolkit          PlaceId 107778070777162
-- ===========================================================================
-- Built from a 58,552-instance class dump of the live client, not from source.
-- Nothing decompiled: MacSploit's decompile() returns the string "Error occured
-- while decompiling, error: ..." instead of throwing, so all 1,387 scripts came
-- back as error text. What the dump did give is the whole instance graph, and
-- that turned out to be enough to work from:
--
--   Workspace.AreaEggSlotsClient.<32-hex>          field eggs; name IS the egg id
--   Workspace.PlacedEggRenders.<userId>_<eggId>    placed eggs; owner in the name
--   Workspace.<player>.<Name> (<n> kg)             carried eggs are Tools
--   ReplicatedStorage.Packages.Networking.RE/x/y   136 events, 83 functions
--
-- The remote names are self-describing (RF/EggWorld/AskFieldEggCarry), but a
-- name is not a signature - nothing here knows what arguments the server wants.
-- That is what the Spy tab is for: it watches the game make its own calls and
-- writes down the real shapes. Recon first, then the Remotes tab fires them
-- back. Anything that guesses at a signature before the spy has seen it is
-- labelled GUESS in the UI.
--
-- NOT RUN. This has never executed in Roblox - it parses, and the paths come
-- from a real dump, but no claim beyond that.

local Players            = game:GetService("Players")
local _RunService        = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local StarterGui         = game:GetService("StarterGui")

local LP = Players.LocalPlayer
local _CAM = workspace.CurrentCamera

-- ---------------------------------------------------------------------------
-- Executor surface
-- ---------------------------------------------------------------------------
-- Every one of these is optional. The script degrades feature by feature rather
-- than erroring out on load, because which of them MacSploit actually provides
-- is not something the dump could answer.
local F = {
    hookmeta   = (typeof(hookmetamethod)   == "function") and hookmetamethod   or nil,
    getraw     = (typeof(getrawmetatable)  == "function") and getrawmetatable  or nil,
    setread    = (typeof(setreadonly)      == "function") and setreadonly      or nil,
    namecall   = (typeof(getnamecallmethod)== "function") and getnamecallmethod or nil,
    newcc      = (typeof(newcclosure)      == "function") and newcclosure      or function(f) return f end,
    checkcall  = (typeof(checkcaller)      == "function") and checkcaller      or function() return false end,
    clip       = (typeof(setclipboard)     == "function") and setclipboard     or nil,
    write      = (typeof(writefile)        == "function") and writefile        or nil,
    fireprompt = (typeof(fireproximityprompt) == "function") and fireproximityprompt or nil,
}

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification",
            { Title = title, Text = text, Duration = dur or 4 })
    end)
end

-- ---------------------------------------------------------------------------
-- Networking folder
-- ---------------------------------------------------------------------------
-- Resolved once and cached. The dump shows every gameplay remote living here as
-- a flat list with slash-separated names, so no tree walking is needed - but
-- FindFirstChild is used rather than WaitForChild so a missing Packages folder
-- disables the remote features instead of hanging the script forever.
local NET do
    local pkgs = ReplicatedStorage:FindFirstChild("Packages")
    NET = pkgs and pkgs:FindFirstChild("Networking") or nil
end

-- Live scan rather than the hardcoded 219 names from the dump: the dump is a
-- snapshot of one server on one day, and an update that adds a remote should
-- show up here without the script being edited.
local function listRemotes()
    local out = {}
    if not NET then return out end
    for _, r in ipairs(NET:GetChildren()) do
        if r:IsA("RemoteEvent") or r:IsA("RemoteFunction")
            or r:IsA("UnreliableRemoteEvent") then
            table.insert(out, r)
        end
    end
    table.sort(out, function(a, b) return a.Name < b.Name end)
    return out
end

-- ---------------------------------------------------------------------------
-- Value serialiser
-- ---------------------------------------------------------------------------
-- Turns a captured argument into something readable in the log and pasteable
-- back into the Remotes tab. Depth-limited because the game passes profile
-- tables around that are large enough to lock the client if printed whole.
local MAX_DEPTH, MAX_STR, MAX_KEYS = 3, 120, 24

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
        return string.format("Vector3.new(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        local p = v.Position
        return string.format("CFrame.new(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
    elseif t == "EnumItem" then
        return tostring(v)
    elseif t == "table" then
        if depth >= MAX_DEPTH then return "{...}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > MAX_KEYS then table.insert(parts, "...") break end
            local key = (type(k) == "string" and k:match("^%a[%w_]*$"))
                and (k .. " = ")
                or ("[" .. ser(k, depth + 1) .. "] = ")
            table.insert(parts, key .. ser(val, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return "<" .. t .. ">"
end

-- The signature is what makes the log readable. Two hundred FieldEggCarry calls
-- with different ids are one fact, not two hundred - so calls collapse onto
-- remote name plus argument types, and only the first example of each is kept.
local function sig(name, args, count)
    local types = {}
    for i = 1, count do types[i] = typeof(args[i]) end
    return name .. "(" .. table.concat(types, ", ") .. ")"
end

-- ---------------------------------------------------------------------------
-- Spy state
-- ---------------------------------------------------------------------------
local Spy = {
    on      = false,
    hooked  = false,
    seen    = {},   -- signature -> record
    order   = {},   -- signatures, first-seen order
    total   = 0,
    netOnly = true,
}

local function record(remote, method, args, count)
    local ok, full = pcall(function() return remote:GetFullName() end)
    local name = ok and full or remote.Name

    -- The Networking folder is the game's own API. Everything else is Cmdr,
    -- analytics heartbeats and the gear tools, which drown the log during
    -- normal play - hence the filter, defaulted on.
    if Spy.netOnly and NET and remote.Parent ~= NET then return end

    Spy.total = Spy.total + 1
    local s = sig(remote.Name, args, count)
    local rec = Spy.seen[s]
    if rec then
        rec.hits = rec.hits + 1
        rec.last = os.clock()
        return
    end

    local shown = {}
    for i = 1, count do shown[i] = ser(args[i]) end
    Spy.seen[s] = {
        sig    = s,
        path   = name,
        remote = remote.Name,
        method = method,
        args   = table.concat(shown, ", "),
        hits   = 1,
        first  = os.clock(),
        last   = os.clock(),
    }
    table.insert(Spy.order, s)
end

-- __namecall catches FireServer/InvokeServer however the game reaches them,
-- including through the Networking package's own wrappers, which a per-remote
-- connection would miss. checkcaller keeps the Remotes tab's own fires out of
-- the log - otherwise testing a call would look like the game making it.
local function installHook()
    if Spy.hooked then return true end
    if not F.namecall then
        return false, "No getnamecallmethod() - this executor cannot run the spy."
    end

    local function handler(orig)
        return function(self, ...)
            if Spy.on and not F.checkcall() then
                local m = F.namecall()
                if m == "FireServer" or m == "InvokeServer" then
                    local ok, cls = pcall(function() return self.ClassName end)
                    if ok and (cls == "RemoteEvent" or cls == "RemoteFunction"
                        or cls == "UnreliableRemoteEvent") then
                        local args = table.pack(...)
                        -- pcall'd so a serialiser mistake can never break the
                        -- call it is observing. A broken game is worse than a
                        -- missed log line.
                        pcall(record, self, m, args, args.n)
                    end
                end
            end
            return orig(self, ...)
        end
    end

    if F.hookmeta then
        local orig
        orig = F.hookmeta(game, "__namecall", F.newcc(handler(function(self, ...)
            return orig(self, ...)
        end)))
        Spy.hooked = true
        return true
    end

    if F.getraw and F.setread then
        local mt = F.getraw(game)
        local orig = mt.__namecall
        F.setread(mt, false)
        mt.__namecall = handler(orig)
        F.setread(mt, true)
        Spy.hooked = true
        return true
    end

    return false, "No hookmetamethod() or getrawmetatable() - spy unavailable."
end

-- The report is the actual deliverable of a play session: paste it back and the
-- Remotes tab has real signatures instead of guesses.
local function spyReport()
    local out = {}
    table.insert(out, "-- Steal An Egg - observed remote signatures")
    table.insert(out, "-- " .. os.date("%Y-%m-%d %H:%M:%S")
        .. "  |  " .. #Spy.order .. " unique, " .. Spy.total .. " calls")
    table.insert(out, "")
    for _, s in ipairs(Spy.order) do
        local r = Spy.seen[s]
        table.insert(out, string.format("-- x%d  %s", r.hits, r.method))
        table.insert(out, r.path)
        table.insert(out, "  args: " .. r.args)
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- World readers
-- ---------------------------------------------------------------------------
local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
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

-- Field eggs. The folder name came out of the dump as AreaEggSlotsClient, and
-- every child was a 32-hex GUID - which is almost certainly the egg id the
-- server wants, though the spy is what will confirm that.
local function fieldEggs()
    local folder = workspace:FindFirstChild("AreaEggSlotsClient")
    local out = {}
    if not folder then return out end
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") then
            table.insert(out, { id = m.Name, model = m, dist = distTo(m) })
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

-- Placed eggs sit under PlacedEggRenders named "<ownerUserId>_<eggId>", so the
-- owner is readable without a single remote call - which is the whole steal
-- targeting problem solved by a string split.
local function placedEggs()
    local folder = workspace:FindFirstChild("PlacedEggRenders")
    local out = {}
    if not folder then return out end
    for _, m in ipairs(folder:GetChildren()) do
        local uid, eggId = m.Name:match("^(%d+)_(%x+)$")
        if uid then
            local owner = Players:GetPlayerByUserId(tonumber(uid))
            table.insert(out, {
                userId = tonumber(uid),
                who    = owner and owner.Name or ("UserId " .. uid),
                mine   = tonumber(uid) == LP.UserId,
                id     = eggId,
                model  = m,
                dist   = distTo(m),
            })
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

-- Carried eggs are Tools parented into the character, named "Duckling (3.07 kg)"
-- in the dump. Weight is in the name, so who is worth robbing is answerable from
-- the client with no remote involved.
local function carried()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") then
                    local base, kg = t.Name:match("^(.-)%s*%(([%d%.]+) kg%)$")
                    if base then
                        table.insert(out, {
                            player = p, name = base,
                            kg = tonumber(kg) or 0,
                            me = (p == LP),
                        })
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.kg > b.kg end)
    return out
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------
-- Tweened rather than a CFrame snap. A snap across the map is the single most
-- obvious thing a client can do; a tween at a plausible speed at least looks
-- like travel. This is still teleporting - it is not subtle, only less blunt.
local TP_STUDS_PER_SEC = 90

local function travelTo(pos, instant)
    local root = hrp()
    if not root then return false, "No character." end
    local target = CFrame.new(pos + Vector3.new(0, 4, 0))
    if instant then
        root.CFrame = target
        return true
    end
    local d = (root.Position - pos).Magnitude
    local tw = TweenService:Create(root,
        TweenInfo.new(math.clamp(d / TP_STUDS_PER_SEC, 0.15, 8), Enum.EasingStyle.Linear),
        { CFrame = target })
    tw:Play()
    tw.Completed:Wait()
    return true
end

-- ---------------------------------------------------------------------------
-- Highlights
-- ---------------------------------------------------------------------------
local HL = {}

local function clearHighlights()
    for inst, h in pairs(HL) do
        pcall(function() h:Destroy() end)
        HL[inst] = nil
    end
end

local function highlight(model, colour)
    if HL[model] then return end
    local ok = pcall(function()
        local h = Instance.new("Highlight")
        h.FillColor = colour
        h.OutlineColor = Color3.new(1, 1, 1)
        h.FillTransparency = 0.6
        h.OutlineTransparency = 0
        h.Adornee = model
        h.Parent = model
        HL[model] = h
    end)
    return ok
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
local BG      = Color3.fromRGB(18, 18, 22)
local PANEL   = Color3.fromRGB(26, 26, 32)
local ACCENT  = Color3.fromRGB(120, 200, 140)
local WARN    = Color3.fromRGB(230, 180, 90)
local TEXT    = Color3.fromRGB(228, 228, 232)
local DIM     = Color3.fromRGB(140, 140, 150)

local gui = Instance.new("ScreenGui")
gui.Name = "SAE"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- CoreGui when the executor can reach it, so a respawn or a game-made
-- PlayerGui wipe does not take the panel with it.
local parented = false
if typeof(gethui) == "function" then
    parented = pcall(function() gui.Parent = gethui() end)
end
if not parented then
    parented = pcall(function() gui.Parent = game:GetService("CoreGui") end)
end
if not parented then
    gui.Parent = LP:WaitForChild("PlayerGui")
end

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = inst
    return c
end

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(430, 470)
root.Position = UDim2.new(0, 40, 0.5, -235)
root.BackgroundColor3 = BG
root.BorderSizePixel = 0
root.Parent = gui
corner(root, 10)

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 34)
bar.BackgroundColor3 = PANEL
bar.BorderSizePixel = 0
bar.Parent = root
corner(bar, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextColor3 = TEXT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "SAE  -  Steal An Egg"
title.Parent = bar

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.fromOffset(28, 22)
hideBtn.Position = UDim2.new(1, -36, 0, 6)
hideBtn.BackgroundColor3 = BG
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 13
hideBtn.TextColor3 = DIM
hideBtn.Text = "-"
hideBtn.Parent = bar
corner(hideBtn, 5)

-- Dragging by hand rather than Frame.Draggable, which is deprecated and does
-- not follow a touch input.
do
    local dragging, startPos, startMouse
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startMouse = true, root.Position, i.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startMouse
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 28)
tabBar.Position = UDim2.fromOffset(8, 40)
tabBar.BackgroundTransparency = 1
tabBar.Parent = root

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -16, 1, -108)
body.Position = UDim2.fromOffset(8, 74)
body.BackgroundTransparency = 1
body.Parent = root

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 26)
status.Position = UDim2.new(0, 8, 1, -30)
status.BackgroundColor3 = PANEL
status.BorderSizePixel = 0
status.Font = Enum.Font.Code
status.TextSize = 11
status.TextColor3 = DIM
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "  Ready."
status.Parent = root
corner(status, 5)

local function say(msg)
    status.Text = "  " .. msg
end

local pages, buttons, current = {}, {}, nil

local function showTab(name)
    for n, page in pairs(pages) do
        page.Visible = (n == name)
        buttons[n].BackgroundColor3 = (n == name) and ACCENT or PANEL
        buttons[n].TextColor3 = (n == name) and BG or TEXT
    end
    current = name
end

local function addTab(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new()
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = body

    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.Parent = page

    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(96, 28)
    b.BackgroundColor3 = PANEL
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextColor3 = TEXT
    b.Text = name
    b.Parent = tabBar
    corner(b, 5)
    b.MouseButton1Click:Connect(function() showTab(name) end)

    pages[name], buttons[name] = page, b
    return page
end

local function button(page, text, tip, fn)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -8, 0, 30)
    b.BackgroundColor3 = PANEL
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.TextColor3 = TEXT
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = page
    corner(b, 5)
    b.MouseButton1Click:Connect(function()
        if tip then say(tip) end
        task.spawn(function()
            local ok, err = pcall(fn)
            if not ok then say("Error: " .. tostring(err)) end
        end)
    end)
    return b
end

local function label(page, text, colour)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -8, 0, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Code
    l.TextSize = 11
    l.TextColor3 = colour or DIM
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Text = text
    l.Parent = page
    return l
end

local function textbox(page, placeholder)
    local t = Instance.new("TextBox")
    t.Size = UDim2.new(1, -8, 0, 28)
    t.BackgroundColor3 = PANEL
    t.Font = Enum.Font.Code
    t.TextSize = 11
    t.TextColor3 = TEXT
    t.PlaceholderText = placeholder
    t.Text = ""
    t.ClearTextOnFocus = false
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = page
    corner(t, 5)
    return t
end

-- ---------------------------------------------------------------------------
-- SPY tab
-- ---------------------------------------------------------------------------
local spyPage = addTab("Spy")

label(spyPage, "The dump recovered no script source, so nothing here knows what\n"
    .. "arguments any remote takes. Turn this on, play normally for a\n"
    .. "few minutes - carry an egg, place it, hatch, sell - then Copy\n"
    .. "Report. That report is the signatures the decompiler could not\n"
    .. "give you, and the Remotes tab can fire them back.", TEXT)

local spyCount = label(spyPage, "Off.", ACCENT)

local spyBtn
spyBtn = button(spyPage, "Start Spy", nil, function()
    if not Spy.on then
        local ok, err = installHook()
        if not ok then say(err); notify("SAE", err, 6); return end
        Spy.on = true
        spyBtn.Text = "Stop Spy"
        say("Spy running. Play the game.")
    else
        Spy.on = false
        spyBtn.Text = "Start Spy"
        say("Spy stopped. " .. #Spy.order .. " unique signatures.")
    end
end)

button(spyPage, "Filter: Networking only  [on]", nil, function()
    Spy.netOnly = not Spy.netOnly
    say("Filter " .. (Spy.netOnly and "on - Networking folder only."
        or "off - every remote, including analytics spam."))
end)

button(spyPage, "Copy Report", "Building report...", function()
    if #Spy.order == 0 then say("Nothing captured yet."); return end
    local rep = spyReport()
    if F.write then pcall(F.write, "SAE_remotes.txt", rep) end
    if F.clip then
        pcall(F.clip, rep)
        say(string.format("Copied %d signatures (%.1f KB).", #Spy.order, #rep / 1024))
    else
        say("Wrote SAE_remotes.txt - no setclipboard on this executor.")
    end
end)

button(spyPage, "Clear", nil, function()
    Spy.seen, Spy.order, Spy.total = {}, {}, 0
    say("Cleared.")
end)

local spyLog = label(spyPage, "", DIM)

-- ---------------------------------------------------------------------------
-- EGGS tab
-- ---------------------------------------------------------------------------
local eggPage = addTab("Eggs")

label(eggPage, "Read straight off the workspace - no remotes, nothing to guess.\n"
    .. "Field egg ids are the folder names; placed eggs carry their\n"
    .. "owner's UserId in the name; carried eggs are Tools with the\n"
    .. "weight in the name.", TEXT)

local eggList = label(eggPage, "Refreshing...", ACCENT)

button(eggPage, "Highlight Field Eggs", nil, function()
    clearHighlights()
    local n = 0
    for _, e in ipairs(fieldEggs()) do
        if highlight(e.model, ACCENT) then n = n + 1 end
    end
    say("Highlighted " .. n .. " field eggs.")
end)

button(eggPage, "Highlight Placed Eggs (others')", nil, function()
    clearHighlights()
    local n = 0
    for _, e in ipairs(placedEggs()) do
        if not e.mine and highlight(e.model, WARN) then n = n + 1 end
    end
    say("Highlighted " .. n .. " eggs on other plots.")
end)

button(eggPage, "Clear Highlights", nil, clearHighlights)

button(eggPage, "Travel To Nearest Field Egg", "Travelling...", function()
    local list = fieldEggs()
    local e = list[1]
    if not e then say("No field eggs in the world right now."); return end
    local p = partOf(e.model)
    if not p then say("Nearest egg has no part to aim at."); return end
    travelTo(p.Position)
    say(string.format("At %s (%.0f studs travelled).", e.id:sub(1, 8), e.dist))
end)

button(eggPage, "Travel To Heaviest Carrier", "Travelling...", function()
    local list = carried()
    for _, c in ipairs(list) do
        if not c.me then
            local ch = c.player.Character
            local r = ch and ch:FindFirstChild("HumanoidRootPart")
            if r then
                travelTo(r.Position + Vector3.new(0, 0, 4))
                say(string.format("%s is holding %s (%.2f kg).",
                    c.player.Name, c.name, c.kg))
                return
            end
        end
    end
    say("Nobody else is carrying an egg.")
end)

button(eggPage, "Sell All  (fires the stand prompt)", nil, function()
    local stands = workspace:FindFirstChild("Stands")
    local prompts = stands and stands:FindFirstChild("Prompts")
    local sellAll = prompts and prompts:FindFirstChild("SellAll")
    local prompt = sellAll and sellAll:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then say("SellAll prompt not found in Workspace.Stands."); return end
    if not F.fireprompt then
        say("No fireproximityprompt() - walk to the stand instead.")
        return
    end
    pcall(F.fireprompt, prompt)
    say("Fired the SellAll prompt.")
end)

-- ---------------------------------------------------------------------------
-- REMOTES tab
-- ---------------------------------------------------------------------------
local remPage = addTab("Remotes")

label(remPage, "Every remote in Packages.Networking, fired by hand. Arguments\n"
    .. "are parsed as Lua-ish literals: numbers, \"strings\", true/false,\n"
    .. "nil, me (LocalPlayer), @Name (that player). A bare word is a\n"
    .. "string, so an egg id can be pasted in raw.", TEXT)

local remFilter = textbox(remPage, "filter, e.g.  EggWorld")
local remName   = textbox(remPage, "remote name, e.g.  RF/EggWorld/AskFieldEggCarry")
local remArgs   = textbox(remPage, "args, e.g.  05750d62f2e6455da2aa038981516e21")

local remHits = label(remPage, "", DIM)

-- A deliberately small parser. It only has to carry the values that show up in
-- this game's calls - an id, a number, a flag, a player - and anything more
-- structured is better captured by the spy and replayed than typed by hand.
local function parseArgs(s)
    local out, n = {}, 0
    for raw in tostring(s):gmatch("[^,]+") do
        local tok = raw:match("^%s*(.-)%s*$")
        n = n + 1
        if tok == "" then
            out[n] = nil
        elseif tok == "nil" then
            out[n] = nil
        elseif tok == "true" then
            out[n] = true
        elseif tok == "false" then
            out[n] = false
        elseif tok == "me" then
            out[n] = LP
        elseif tok:sub(1, 1) == "@" then
            local want = tok:sub(2):lower()
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower():sub(1, #want) == want then out[n] = p break end
            end
        elseif tonumber(tok) then
            out[n] = tonumber(tok)
        else
            out[n] = (tok:gsub('^"(.*)"$', "%1"))
        end
    end
    return out, n
end

local function refreshRemoteList()
    local want = remFilter.Text:lower()
    local hits, shown = {}, 0
    for _, r in ipairs(listRemotes()) do
        if want == "" or r.Name:lower():find(want, 1, true) then
            shown = shown + 1
            if shown <= 14 then table.insert(hits, "  " .. r.Name) end
        end
    end
    if shown == 0 then
        remHits.Text = NET and "No match." or "Packages.Networking not found."
    else
        remHits.Text = shown .. " match" .. (shown == 1 and "" or "es") .. ":\n"
            .. table.concat(hits, "\n") .. (shown > 14 and "\n  ..." or "")
    end
end

remFilter:GetPropertyChangedSignal("Text"):Connect(refreshRemoteList)

button(remPage, "Fire", "Firing...", function()
    if not NET then say("Packages.Networking not found."); return end
    local name = remName.Text:match("^%s*(.-)%s*$")
    if name == "" then say("Type a remote name first."); return end
    local r = NET:FindFirstChild(name)
    if not r then say("No remote named " .. name); return end

    local args, n = parseArgs(remArgs.Text)
    if r:IsA("RemoteFunction") then
        local ok, res = pcall(function() return r:InvokeServer(table.unpack(args, 1, n)) end)
        if not ok then say("InvokeServer errored: " .. tostring(res)); return end
        local text = ser(res)
        if F.clip then pcall(F.clip, text) end
        say("-> " .. text:sub(1, 90))
    else
        local ok, err = pcall(function() r:FireServer(table.unpack(args, 1, n)) end)
        say(ok and "Fired." or ("FireServer errored: " .. tostring(err)))
    end
end)

button(remPage, "Copy Every Remote Name", nil, function()
    local names = {}
    for _, r in ipairs(listRemotes()) do
        table.insert(names, r.ClassName .. "  " .. r.Name)
    end
    if #names == 0 then say("Networking folder is empty or missing."); return end
    local text = table.concat(names, "\n")
    if F.write then pcall(F.write, "SAE_remote_names.txt", text) end
    if F.clip then pcall(F.clip, text) end
    say("Copied " .. #names .. " remote names.")
end)

-- ---------------------------------------------------------------------------
-- AUTO tab
-- ---------------------------------------------------------------------------
local autoPage = addTab("Auto")

label(autoPage, "GUESS - read this first.\n\n"
    .. "The collect loop travels to a field egg and then has to tell the\n"
    .. "server it picked it up. Which remote that is, and what it wants,\n"
    .. "is not known: RF/EggWorld/AskFieldEggCarry taking the folder's\n"
    .. "32-hex name is an inference from the dump, nothing more. It may\n"
    .. "do nothing, or error, or be rejected.\n\n"
    .. "Run the Spy through one manual pickup first. If the real call\n"
    .. "differs, put it in the two boxes below and the loop will use it.", WARN)

local carryRemote = textbox(autoPage, "carry remote  (default RF/EggWorld/AskFieldEggCarry)")
local carryStyle  = textbox(autoPage, "arg style: id | model | id,me   (default id)")

local Auto = { on = false, gen = 0 }

-- The prompt is tried before the remote every time. If the egg has a
-- ProximityPrompt then firing it is the game's own code path - it needs no
-- guessed signature and it is what a real pickup does.
local function grab(egg)
    local p = partOf(egg.model)
    if p then
        local prompt = egg.model:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and F.fireprompt then
            pcall(F.fireprompt, prompt)
            return true, "prompt"
        end
    end

    if not NET then return false, "no Networking folder" end
    local name = carryRemote.Text:match("^%s*(.-)%s*$")
    if name == "" then name = "RF/EggWorld/AskFieldEggCarry" end
    local r = NET:FindFirstChild(name)
    if not r then return false, "no remote " .. name end

    local style = carryStyle.Text:match("^%s*(.-)%s*$")
    local args
    if style == "model" then
        args = { egg.model }
    elseif style == "id,me" then
        args = { egg.id, LP }
    else
        args = { egg.id }
    end

    local ok, res
    if r:IsA("RemoteFunction") then
        ok, res = pcall(function() return r:InvokeServer(table.unpack(args)) end)
    else
        ok, res = pcall(function() r:FireServer(table.unpack(args)) end)
    end
    if not ok then return false, tostring(res) end
    return true, "remote -> " .. ser(res)
end

local autoBtn
autoBtn = button(autoPage, "Start Auto Collect", nil, function()
    if Auto.on then
        Auto.on = false
        Auto.gen = Auto.gen + 1
        autoBtn.Text = "Start Auto Collect"
        say("Auto collect stopped.")
        return
    end

    Auto.on = true
    Auto.gen = Auto.gen + 1
    local myGen = Auto.gen
    autoBtn.Text = "Stop Auto Collect"

    task.spawn(function()
        local got, failed = 0, 0
        while Auto.on and Auto.gen == myGen do
            local list = fieldEggs()
            local e = list[1]
            if not e then
                say("No field eggs - waiting for a spawn.")
                task.wait(3)
            else
                local p = partOf(e.model)
                if p then travelTo(p.Position) end
                task.wait(0.3)
                local ok, how = grab(e)
                if ok then got = got + 1 else failed = failed + 1 end
                say(string.format("Collect: %d ok, %d failed  (last: %s)",
                    got, failed, tostring(how):sub(1, 40)))
                -- Ten straight failures means the signature is wrong, and
                -- hammering a rejected remote is exactly what gets a client
                -- flagged. Stop and say so rather than loop forever.
                if failed >= 10 and got == 0 then
                    Auto.on = false
                    autoBtn.Text = "Start Auto Collect"
                    say("Stopped: 10 failures, 0 pickups. The carry call is wrong - spy it.")
                    notify("SAE", "Auto collect stopped - carry signature is wrong.", 8)
                    return
                end
                task.wait(0.6)
            end
        end
    end)
end)

button(autoPage, "Test Carry Once (nearest egg)", "Testing...", function()
    local e = fieldEggs()[1]
    if not e then say("No field eggs right now."); return end
    local p = partOf(e.model)
    if p then travelTo(p.Position) end
    task.wait(0.3)
    local ok, how = grab(e)
    say((ok and "OK: " or "Failed: ") .. tostring(how))
end)

-- ---------------------------------------------------------------------------
-- Refresh loop
-- ---------------------------------------------------------------------------
-- Half-second tick rather than per-frame: everything on screen is a count or a
-- distance, and none of it is worth a RenderStepped budget.
task.spawn(function()
    while gui.Parent do
        task.wait(0.5)
        local ok = pcall(function()
            if current == "Spy" then
                spyCount.Text = Spy.on
                    and string.format("Running - %d unique, %d calls",
                        #Spy.order, Spy.total)
                    or string.format("Off - %d unique captured", #Spy.order)

                local lines, n = {}, 0
                for i = #Spy.order, 1, -1 do
                    n = n + 1
                    if n > 10 then break end
                    local r = Spy.seen[Spy.order[i]]
                    table.insert(lines, string.format("x%-4d %s\n       %s",
                        r.hits, r.remote, r.args:sub(1, 70)))
                end
                spyLog.Text = table.concat(lines, "\n")

            elseif current == "Eggs" then
                local f, p, c = fieldEggs(), placedEggs(), carried()
                local lines = {
                    string.format("Field eggs:  %d", #f),
                    string.format("Placed eggs: %d  (%d not yours)", #p,
                        (function()
                            local k = 0
                            for _, e in ipairs(p) do if not e.mine then k = k + 1 end end
                            return k
                        end)()),
                    "",
                }
                for i = 1, math.min(4, #f) do
                    table.insert(lines, string.format("  %-8s  %.0f studs",
                        f[i].id:sub(1, 8), f[i].dist))
                end
                if #c > 0 then
                    table.insert(lines, "")
                    table.insert(lines, "Carrying now:")
                    for i = 1, math.min(4, #c) do
                        table.insert(lines, string.format("  %-14s %s (%.2f kg)",
                            c[i].player.Name:sub(1, 14), c[i].name, c[i].kg))
                    end
                end
                eggList.Text = table.concat(lines, "\n")
            end
        end)
        if not ok then task.wait(1) end
    end
end)

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------
local hidden = false
hideBtn.MouseButton1Click:Connect(function()
    hidden = not hidden
    body.Visible = not hidden
    tabBar.Visible = not hidden
    status.Visible = not hidden
    root.Size = hidden and UDim2.fromOffset(430, 34) or UDim2.fromOffset(430, 470)
    hideBtn.Text = hidden and "+" or "-"
end)

UserInputService.InputBegan:Connect(function(i, typing)
    if typing then return end
    if i.KeyCode == Enum.KeyCode.RightControl then
        root.Visible = not root.Visible
    end
end)

showTab("Spy")

if not NET then
    say("Packages.Networking missing - remote tabs are dead.")
elseif not F.namecall then
    say("No getnamecallmethod() - spy unavailable, world tabs still work.")
else
    say(string.format("%d remotes found. Start the spy, then play.", #listRemotes()))
end

notify("SAE loaded", "RightCtrl hides. Start on the Spy tab.", 6)
