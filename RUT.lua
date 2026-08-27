-- RUT - Roblox Universal Troller
--
-- Built on the same Duvome library as PIHD, so it inherits the tabs, themes,
-- glass, keybind boxes, side panels and key system rather than reinventing a
-- worse version of each. Everything here acts on YOUR client: movement,
-- rendering and camera. Nothing reaches into another player's session.
--
-- Plain URLs, no cache-buster, matching every other script in this repo.
-- raw.githubusercontent sits behind a CDN with a five minute TTL, so after a
-- push give it a moment before deciding a fix did not work.
-- The executor globals table. Not every executor exposes getgenv, and on the
-- ones that do not, a fallback table is enough: it only has to survive within
-- one execution for the unload hook below to be reachable from the next one.
local ENV = (typeof(getgenv) == "function" and getgenv()) or _G

-- Re-executing used to stack a second window over the first and, worse, a
-- second set of RenderStepped handlers - two flies fighting over one velocity,
-- with only the newer window's toggles able to stop either. bind() prevents
-- that within one instance and can do nothing across two, so the previous
-- instance is asked to shut itself down before this one builds anything.
if type(ENV.RUT_UNLOAD) == "function" then
    pcall(ENV.RUT_UNLOAD)
    ENV.RUT_UNLOAD = nil
end

-- Where to fetch this file from when re-queueing across a teleport.
local RUT_URL = "https://raw.githubusercontent.com/aparaanana-hue/DW/"
    .. "refs/heads/main/RUT.lua"

local Duvome = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/aparaanana-hue/DW/refs/heads/main/DL.lua"))()

-- Bumped on every push. If the About panel does not show the newest one, the
-- CDN is still serving a cached copy - wait out the five minute TTL rather than
-- chasing a bug that is not there.
local RUT_BUILD = "Aug 27 16:45"

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")

local LP     = Players.LocalPlayer
local Mouse  = LP:GetMouse()
local Camera = workspace.CurrentCamera

-- One table for all feature state. Not tidiness: a file-scope local per feature
-- is how PIHD reached Luau's 200-register ceiling, and this is meant to grow.
local R = {
    flySpeed   = 60,
    flyOn      = false,
    noclipOn   = false,
    infJumpOn  = false,
    walkSpeed  = 16,
    jumpPower  = 50,
    speedOn    = false,
    jumpOn     = false,
    espOn      = false,
    espNames   = true,
    espBoxes   = true,
    fullbright = false,
    xrayOn     = false,
    xrayAmount = 0.6,
    hiddenOn   = false,
    freecamOn  = false,
    freecamSpd = 60,
    antiAfkOn  = false,
    ctpKey     = Enum.KeyCode.T,
    waypoints  = {},
    conns      = {},
    espObjects = {},
    lightSaved = nil,
}

-- Every running feature registers a stop function here. The panic key calls the
-- lot: when something has gone wrong, turning features off one at a time while
-- your character is 400 studs in the air is not a workable plan.
local ACTIVE = {}

local function register(name, stop) ACTIVE[name] = stop end
local function unregister(name)     ACTIVE[name] = nil end

local function notify(title, content, time)
    pcall(function()
        Duvome:MakeNotification({
            Name = title, Content = content or "", Time = time or 3,
        })
    end)
end

-- Teleporting tears the script down with the old place instance, so both the
-- hop buttons below used to drop RUT on the way out and leave you re-executing
-- by hand on arrival. queue_on_teleport hands the executor a source string to
-- run once the next place has loaded. Not every executor spells it the same
-- way and some do not have it at all, hence the lookup rather than a call.
local function queueSelf()
    local q = (typeof(queue_on_teleport) == "function" and queue_on_teleport)
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if not q then return false end
    local ok = pcall(q, [[loadstring(game:HttpGet("]] .. RUT_URL .. [["))()]])
    return ok
end

-- Character parts, re-read every time rather than cached. Respawning replaces
-- the model, and a cached HumanoidRootPart from a previous life is the single
-- most common reason one of these features silently stops working.
local function parts()
    local char = LP.Character
    if not char then return nil, nil, nil end
    return char,
           char:FindFirstChildOfClass("Humanoid"),
           char:FindFirstChild("HumanoidRootPart")
end

-- Connections are tracked by name so a feature can be restarted without
-- stacking a second listener on top of the first. Toggling fly off and on
-- twice used to leave three RenderStepped handlers fighting over one velocity.
local function bind(name, signal, fn)
    if R.conns[name] then R.conns[name]:Disconnect() end
    R.conns[name] = signal:Connect(fn)
end

local function unbind(name)
    if R.conns[name] then
        R.conns[name]:Disconnect()
        R.conns[name] = nil
    end
end

-- True while the user is typing into the UI, so WASD does not fly you across
-- the map while you are naming a waypoint.
local function typing()
    return UserInputService:GetFocusedTextBox() ~= nil
end

local Window = Duvome:MakeWindow({
    Name         = "RUT - Roblox Universal Troller",
    HidePremium  = false,
    SaveConfig   = true,
    ConfigFolder = "RUT",
    -- No blur. Roblox's BlurEffect works on the camera, so it frosts the whole
    -- screen rather than only what is behind the window.
    Blur         = false,
})

pcall(function() Duvome:SetGlass(0.38) end)

-- Icon names come from the BuilderIcons font the library already loads. These
-- are glyphs known to exist in it; swap them freely, an unknown name renders as
-- its own text rather than an icon.
local MoveTab  = Window:MakeTab({Name = "Movement",  Icon = "star",     Columns = true})
local CharTab  = Window:MakeTab({Name = "Character", Icon = "backpack", Columns = true})
local ViewTab  = Window:MakeTab({Name = "Visuals",   Icon = "tag",      Columns = true})
local PlayTab  = Window:MakeTab({Name = "Players",   Icon = "house",    Columns = true})
local ServTab  = Window:MakeTab({Name = "Server",    Icon = "code",     Columns = true})
local DevTab   = Window:MakeTab({Name = "Dev",       Icon = "wrench",   Columns = true})
local SetTab   = Window:MakeTab({Name = "Settings",  Icon = "gear",     Columns = true})

-- ===========================================================================
-- MOVEMENT
-- ===========================================================================
local ML, MR = MoveTab:AddLeft(), MoveTab:AddRight()

local flySec = ML:AddSection({Name = "Fly"})

local function stopFly()
    unbind("fly")
    local char, hum, hrp = parts()
    if hrp then
        local v = hrp:FindFirstChild("RUTFlyVelocity")
        local g = hrp:FindFirstChild("RUTFlyGyro")
        if v then v:Destroy() end
        if g then g:Destroy() end
    end
    if hum then hum.PlatformStand = false end
    R.flyOn = false
    unregister("Fly")
end

local function startFly()
    local char, hum, hrp = parts()
    if not hrp then
        notify("Fly", "No character to fly", 3)
        return false
    end
    stopFly()

    local bv = Instance.new("BodyVelocity")
    bv.Name      = "RUTFlyVelocity"
    bv.MaxForce  = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity  = Vector3.new(0, 0, 0)
    bv.Parent    = hrp

    local bg = Instance.new("BodyGyro")
    bg.Name      = "RUTFlyGyro"
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.P         = 9e4
    bg.CFrame    = Camera.CFrame
    bg.Parent    = hrp

    R.flyOn = true
    register("Fly", stopFly)

    bind("fly", RunService.RenderStepped, function()
        local _, hum2, hrp2 = parts()
        if not hrp2 then return end
        -- The movers live on the ROOT PART, which is replaced on respawn. If
        -- ours have gone with it, rebuild rather than steering a dead handle.
        local v = hrp2:FindFirstChild("RUTFlyVelocity")
        local g = hrp2:FindFirstChild("RUTFlyGyro")
        if not v or not g then
            if R.flyOn then task.defer(startFly) end
            return
        end

        local dir = Vector3.new(0, 0, 0)
        if not typing() then
            local cf = Camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W)         then dir = dir + cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S)         then dir = dir - cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A)         then dir = dir - cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D)         then dir = dir + cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
        end

        if dir.Magnitude > 0 then
            v.Velocity = dir.Unit * R.flySpeed
        else
            -- Held at zero rather than released: letting go would hand you back
            -- to gravity mid-air, which reads as the fly having failed.
            v.Velocity = Vector3.new(0, 0, 0)
        end
        g.CFrame = Camera.CFrame
    end)
    return true
end

R.flyToggle = flySec:AddToggle({
    Name    = "Fly",
    Default = false,
    Tooltip = "WASD to move, Space up, Left Shift down, all relative to the camera. Speed is in the gear.",
    Options = {
        {Type = "slider", Name = "Speed", Min = 10, Max = 400, Default = 60, ValueName = " st/s",
         Callback = function(v) R.flySpeed = v end},
        {Type = "keybind", Name = "Key", OnPress = function()
            if R.flyToggle then R.flyToggle:Set(not R.flyOn) end
        end},
    },
    Callback = function(value)
        if value then
            if not startFly() then
                if R.flyToggle then R.flyToggle:Set(false) end
            end
        else
            stopFly()
        end
    end,
})

local walkSec = ML:AddSection({Name = "Speed & Jump"})

-- Applied on a signal rather than once. Many games reset WalkSpeed on respawn,
-- on entering a zone, or on a timer, and a value set once is a value that
-- lasts until the first thing that touches it.
local function applySpeed()
    local _, hum = parts()
    if not hum then return end
    if R.speedOn and hum.WalkSpeed ~= R.walkSpeed then hum.WalkSpeed = R.walkSpeed end
    if R.jumpOn then
        if hum.UseJumpPower then
            if hum.JumpPower ~= R.jumpPower then hum.JumpPower = R.jumpPower end
        else
            -- JumpHeight games: JumpPower is ignored, so drive the other one.
            local h = R.jumpPower / 10
            if hum.JumpHeight ~= h then hum.JumpHeight = h end
        end
    end
end

local function speedWatch(on)
    if on then
        bind("speed", RunService.Heartbeat, applySpeed)
        register("Speed", function() unbind("speed") end)
    elseif not R.speedOn and not R.jumpOn then
        unbind("speed")
        unregister("Speed")
        local _, hum = parts()
        if hum then
            hum.WalkSpeed = 16
            if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
        end
    end
end

walkSec:AddToggle({
    Name = "Walk Speed", Default = false,
    Tooltip = "Holds your walk speed at the value in the gear, reapplying it whenever the game resets it.",
    Options = {
        {Type = "slider", Name = "Speed", Min = 16, Max = 500, Default = 16,
         Callback = function(v) R.walkSpeed = v end},
    },
    Callback = function(v) R.speedOn = v speedWatch(v) end,
})

walkSec:AddToggle({
    Name = "Jump Power", Default = false,
    Tooltip = "Holds your jump power. Games using JumpHeight instead of JumpPower are handled too.",
    Options = {
        {Type = "slider", Name = "Power", Min = 50, Max = 500, Default = 50,
         Callback = function(v) R.jumpPower = v end},
    },
    Callback = function(v) R.jumpOn = v speedWatch(v) end,
})

walkSec:AddToggle({
    Name = "Infinite Jump", Default = false,
    Tooltip = "Every jump request jumps, in the air or not.",
    Callback = function(value)
        R.infJumpOn = value
        if value then
            bind("infjump", UserInputService.JumpRequest, function()
                if not R.infJumpOn or typing() then return end
                local _, hum = parts()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
            register("Infinite Jump", function() unbind("infjump") R.infJumpOn = false end)
        else
            unbind("infjump")
            unregister("Infinite Jump")
        end
    end,
})

local clipSec = MR:AddSection({Name = "Collision"})

R.noclipToggle = clipSec:AddToggle({
    Name = "Noclip", Default = false,
    Tooltip = "Walks through walls. Reapplied every frame, since anything that rebuilds your character turns collision back on.",
    Options = {
        {Type = "keybind", Name = "Key", OnPress = function()
            if R.noclipToggle then R.noclipToggle:Set(not R.noclipOn) end
        end},
    },
    Callback = function(value)
        R.noclipOn = value
        if value then
            bind("noclip", RunService.Stepped, function()
                local char = LP.Character
                if not char then return end
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                end
            end)
            register("Noclip", function()
                unbind("noclip")
                R.noclipOn = false
                local char = LP.Character
                if char then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                            p.CanCollide = true
                        end
                    end
                end
            end)
        else
            local stop = ACTIVE["Noclip"]
            if stop then stop() end
            unregister("Noclip")
        end
    end,
})

local tpSec = MR:AddSection({Name = "Teleport"})

tpSec:AddToggle({
    Name = "Click Teleport", Default = false,
    Tooltip = "Press the key in the gear to jump to whatever your mouse is over.",
    Options = {
        {Type = "keybind", Name = "Key", OnPress = function()
            local _, _, hrp = parts()
            if not hrp then return end
            if not Mouse.Target then
                notify("Click Teleport", "Point at something solid first", 2)
                return
            end
            hrp.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
        end},
    },
    Callback = function() end,
})

local function waypointNames()
    local t = {}
    for name in pairs(R.waypoints) do table.insert(t, name) end
    table.sort(t)
    if #t == 0 then table.insert(t, "(none saved)") end
    return t
end

local wpName, wpPick = "", nil

tpSec:AddTextbox({
    Name = "Waypoint Name", Default = "", TextDisappear = false,
    Tooltip = "Name to save your current position under.",
    Callback = function(text) wpName = text end,
})

tpSec:AddButton({
    Name = "Save Waypoint",
    Callback = function()
        local _, _, hrp = parts()
        if not hrp then notify("Waypoint", "No character", 3) return end
        local name = (wpName ~= "" and wpName) or ("Point " .. (#waypointNames() + 1))
        R.waypoints[name] = hrp.CFrame
        if R.wpDrop then pcall(function() R.wpDrop:Refresh(waypointNames(), true) end) end
        notify("Waypoint", "Saved " .. name, 2)
    end,
})

R.wpDrop = tpSec:AddDropdown({
    Name = "Go To", Options = waypointNames(), Default = "", Search = true,
    OnRefresh = waypointNames,
    Callback = function(value) wpPick = value end,
})

tpSec:AddButton({
    Name = "Teleport",
    Callback = function()
        local _, _, hrp = parts()
        local cf = wpPick and R.waypoints[wpPick]
        if not hrp then notify("Waypoint", "No character", 3) return end
        if not cf then notify("Waypoint", "Pick a saved waypoint first", 3) return end
        hrp.CFrame = cf
    end,
})

tpSec:AddButton({
    Name = "Delete Waypoint",
    Callback = function()
        if not wpPick or not R.waypoints[wpPick] then
            notify("Waypoint", "Pick one first", 2) return
        end
        local gone = wpPick
        R.waypoints[gone] = nil
        wpPick = nil
        if R.wpDrop then pcall(function() R.wpDrop:Refresh(waypointNames(), true) end) end
        notify("Waypoint", "Deleted " .. gone, 2)
    end,
})

-- ===========================================================================
-- CHARACTER
-- ===========================================================================
local CL, CR = CharTab:AddLeft(), CharTab:AddRight()

local selfSec = CL:AddSection({Name = "Self"})

selfSec:AddToggle({
    Name = "Hide Character", Default = false,
    Tooltip = "Hides your own body from YOUR screen only. Other players still see you - client transparency does not replicate, and any script claiming otherwise is wrong.",
    Callback = function(value)
        R.hiddenOn = value
        local char = LP.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then
                p.LocalTransparencyModifier = value and 1 or 0
            end
        end
        if value then
            register("Hide Character", function()
                local c = LP.Character
                if c then
                    for _, p in ipairs(c:GetDescendants()) do
                        if p:IsA("BasePart") or p:IsA("Decal") then
                            p.LocalTransparencyModifier = 0
                        end
                    end
                end
                R.hiddenOn = false
            end)
        else
            unregister("Hide Character")
        end
    end,
})

selfSec:AddButton({
    Name = "Reset Character",
    Tooltip = "Breaks your joints, which respawns you. Also clears anything stuck to your character.",
    Callback = function()
        local _, hum = parts()
        if hum then hum.Health = 0 else notify("Reset", "No character", 3) end
    end,
})

selfSec:AddButton({
    Name = "Return To Spawn",
    Tooltip = "Teleports you to the place the game spawns players.",
    Callback = function()
        local _, _, hrp = parts()
        if not hrp then notify("Spawn", "No character", 3) return end
        local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
        if not spawn then
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("SpawnLocation") then spawn = d break end
            end
        end
        if not spawn then notify("Spawn", "No SpawnLocation in this game", 3) return end
        hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
    end,
})

local antiSec = CR:AddSection({Name = "Safety"})

antiSec:AddToggle({
    Name = "Anti Void", Default = false,
    Tooltip = "Catches you when you fall below the map and puts you back where you were standing.",
    Callback = function(value)
        if value then
            local lastSafe = nil
            bind("antivoid", RunService.Heartbeat, function()
                local _, _, hrp = parts()
                if not hrp then return end
                if hrp.Position.Y > -50 then
                    lastSafe = hrp.CFrame
                elseif lastSafe then
                    hrp.CFrame = lastSafe
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    notify("Anti Void", "Caught you", 2)
                end
            end)
            register("Anti Void", function() unbind("antivoid") end)
        else
            unbind("antivoid")
            unregister("Anti Void")
        end
    end,
})

-- ===========================================================================
-- VISUALS
-- ===========================================================================
local VL, VR = ViewTab:AddLeft(), ViewTab:AddRight()

local lightSec = VL:AddSection({Name = "Lighting"})

lightSec:AddToggle({
    Name = "Fullbright", Default = false,
    Tooltip = "Flattens the lighting so nothing is in shadow. Restores the game's own settings when turned off.",
    Callback = function(value)
        if value then
            -- Saved before the first change, not on every toggle: turning it on
            -- twice would otherwise save the fullbright values as the original.
            if not R.lightSaved then
                R.lightSaved = {
                    Brightness    = Lighting.Brightness,
                    ClockTime     = Lighting.ClockTime,
                    FogEnd        = Lighting.FogEnd,
                    GlobalShadows = Lighting.GlobalShadows,
                    Ambient       = Lighting.Ambient,
                    OutdoorAmbient = Lighting.OutdoorAmbient,
                }
            end
            Lighting.Brightness     = 2
            Lighting.ClockTime      = 12
            Lighting.FogEnd         = 1e6
            Lighting.GlobalShadows  = false
            Lighting.Ambient        = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
            register("Fullbright", function()
                if R.lightSaved then
                    for k, v in pairs(R.lightSaved) do
                        pcall(function() Lighting[k] = v end)
                    end
                end
                R.fullbright = false
            end)
        else
            local stop = ACTIVE["Fullbright"]
            if stop then stop() end
            unregister("Fullbright")
        end
        R.fullbright = value
    end,
})

lightSec:AddSlider({
    Name = "Field Of View", Min = 20, Max = 120, Default = 70, ValueName = " deg",
    Callback = function(v) Camera.FieldOfView = v end,
})

lightSec:AddToggle({
    Name = "X-Ray", Default = false,
    Tooltip = "Makes the world semi-transparent so you can see through walls. Your own character and other players are left alone.",
    Options = {
        {Type = "slider", Name = "Amount", Min = 1, Max = 9, Default = 6,
         Callback = function(v) R.xrayAmount = v / 10 end},
    },
    Callback = function(value)
        R.xrayOn = value
        local function skip(p)
            if p:IsDescendantOf(LP.Character or workspace) then return true end
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.Character and p:IsDescendantOf(pl.Character) then return true end
            end
            return false
        end
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("BasePart") and not skip(p) then
                p.LocalTransparencyModifier = value and R.xrayAmount or 0
            end
        end
        if value then
            register("X-Ray", function()
                for _, p in ipairs(workspace:GetDescendants()) do
                    if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end
                end
                R.xrayOn = false
            end)
        else
            unregister("X-Ray")
        end
    end,
})

local espSec = VR:AddSection({Name = "Player ESP"})

local function clearESP(plr)
    if plr then
        local o = R.espObjects[plr]
        if o then pcall(function() o:Destroy() end) end
        R.espObjects[plr] = nil
        return
    end
    for p, o in pairs(R.espObjects) do
        pcall(function() o:Destroy() end)
        R.espObjects[p] = nil
    end
end

local function buildESP(plr)
    if plr == LP or R.espObjects[plr] then return end
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local holder = Instance.new("Folder")
    holder.Name = "RUT_ESP_" .. plr.Name

    if R.espBoxes then
        local hl = Instance.new("Highlight")
        hl.FillColor        = Color3.fromRGB(140, 90, 220)
        hl.OutlineColor     = Color3.fromRGB(220, 190, 255)
        hl.FillTransparency = 0.7
        hl.Adornee          = char
        hl.Parent           = holder
    end

    if R.espNames then
        local bb = Instance.new("BillboardGui")
        bb.Name          = "Tag"
        bb.Adornee       = head
        bb.Size          = UDim2.new(0, 200, 0, 24)
        bb.StudsOffset   = Vector3.new(0, 2.4, 0)
        bb.AlwaysOnTop   = true
        bb.Parent        = holder

        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Size       = UDim2.new(1, 0, 1, 0)
        lbl.Font       = Enum.Font.GothamBold
        lbl.TextSize   = 13
        lbl.TextColor3 = Color3.fromRGB(230, 210, 255)
        lbl.TextStrokeTransparency = 0.4
        lbl.Text       = plr.DisplayName
        lbl.Parent     = bb
    end

    holder.Parent = workspace
    R.espObjects[plr] = holder
end

local function refreshESP()
    if not R.espOn then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local o = R.espObjects[plr]
            -- Rebuilt on respawn: a Highlight adorned to a destroyed character
            -- is still a live instance, it just highlights nothing.
            if o and (not plr.Character or not o.Parent) then
                clearESP(plr)
                o = nil
            end
            if not o then buildESP(plr) end
        end
    end
    for plr in pairs(R.espObjects) do
        if not plr.Parent then clearESP(plr) end
    end
end

espSec:AddToggle({
    Name = "Player ESP", Default = false,
    Tooltip = "Highlights every other player and labels them. Names and boxes can be turned off separately in the gear.",
    Options = {
        {Type = "toggle", Name = "Names", Default = true,
         Callback = function(v) R.espNames = v clearESP() refreshESP() end},
        {Type = "toggle", Name = "Boxes", Default = true,
         Callback = function(v) R.espBoxes = v clearESP() refreshESP() end},
    },
    Callback = function(value)
        R.espOn = value
        if value then
            refreshESP()
            bind("esp", RunService.Heartbeat, function()
                if not R.espOn then return end
                -- once a second is plenty; this walks every player
                R.espClock = (R.espClock or 0) + 1
                if R.espClock % 60 == 0 then refreshESP() end
            end)
            register("Player ESP", function()
                unbind("esp") clearESP() R.espOn = false
            end)
        else
            unbind("esp")
            clearESP()
            unregister("Player ESP")
        end
    end,
})

-- ===========================================================================
-- PLAYERS
-- ===========================================================================
local PL_, PR_ = PlayTab:AddLeft(), PlayTab:AddRight()

local plrSec = PL_:AddSection({Name = "Target"})

local targetName = nil

local function otherPlayers()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(t, p.Name) end
    end
    table.sort(t)
    if #t == 0 then table.insert(t, "(nobody else here)") end
    return t
end

local function targetPlayer()
    if not targetName or targetName == "(nobody else here)" then return nil end
    return Players:FindFirstChild(targetName)
end

R.plrDrop = plrSec:AddDropdown({
    Name = "Player", Options = otherPlayers(), Default = "", Search = true,
    OnRefresh = otherPlayers,
    Callback = function(v) targetName = v end,
})

plrSec:AddButton({
    Name = "Teleport To",
    Callback = function()
        local t = targetPlayer()
        if not t then notify("Teleport", "Pick a player first", 3) return end
        local theirs = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
        local _, _, hrp = parts()
        if not theirs or not hrp then notify("Teleport", "They are not spawned", 3) return end
        hrp.CFrame = theirs.CFrame * CFrame.new(0, 0, 4)
    end,
})

plrSec:AddToggle({
    Name = "Spectate", Default = false,
    Tooltip = "Watches the selected player. Turning it off returns the camera to you.",
    Callback = function(value)
        if value then
            local t = targetPlayer()
            local hum = t and t.Character and t.Character:FindFirstChildOfClass("Humanoid")
            if not hum then
                notify("Spectate", "Pick a spawned player first", 3)
                return
            end
            Camera.CameraSubject = hum
            register("Spectate", function()
                local _, myHum = parts()
                if myHum then Camera.CameraSubject = myHum end
            end)
        else
            local stop = ACTIVE["Spectate"]
            if stop then stop() end
            unregister("Spectate")
        end
    end,
})

local infoSec = PR_:AddSection({Name = "Info"})

R.plrInfo = infoSec:AddParagraph("Selected Player", "Pick someone to see their details.")

infoSec:AddButton({
    Name = "Look Up",
    Callback = function()
        local t = targetPlayer()
        if not t then notify("Player Info", "Pick a player first", 3) return end
        local hum = t.Character and t.Character:FindFirstChildOfClass("Humanoid")
        local dist = "unknown"
        local _, _, hrp = parts()
        local theirs = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
        if hrp and theirs then
            dist = string.format("%.0f studs", (hrp.Position - theirs.Position).Magnitude)
        end
        pcall(function()
            R.plrInfo:Set(string.format(
                "Name: %s\nDisplay: %s\nUser ID: %d\nAccount age: %d days\nHealth: %s\nDistance: %s",
                t.Name, t.DisplayName, t.UserId, t.AccountAge,
                hum and string.format("%.0f / %.0f", hum.Health, hum.MaxHealth) or "not spawned",
                dist))
        end)
    end,
})

infoSec:AddButton({
    Name = "Copy User ID",
    Callback = function()
        local t = targetPlayer()
        if not t then notify("Copy", "Pick a player first", 3) return end
        if setclipboard then
            setclipboard(tostring(t.UserId))
            notify("Copied", tostring(t.UserId), 2)
        else
            notify("Copy", "This executor has no clipboard function", 3)
        end
    end,
})

-- ===========================================================================
-- SERVER
-- ===========================================================================
local SL, SR = ServTab:AddLeft(), ServTab:AddRight()

local srvSec = SL:AddSection({Name = "This Server"})

R.srvInfo = srvSec:AddParagraph("Server", "Loading...")

local function refreshServerInfo()
    pcall(function()
        R.srvInfo:Set(string.format(
            "Place: %d\nJob: %s\nPlayers: %d / %d\nPing: %s",
            game.PlaceId, tostring(game.JobId),
            #Players:GetPlayers(), Players.MaxPlayers,
            "see the watch list"))
    end)
end
refreshServerInfo()

srvSec:AddButton({
    Name = "Rejoin",
    Tooltip = "Teleports you back into this exact server.",
    Callback = function()
        local queued = queueSelf()
        notify("Rejoin", queued and "Teleporting, RUT will reload..."
            or "Teleporting (re-run RUT on arrival)", 3)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
        end)
    end,
})

srvSec:AddButton({
    Name = "Server Hop",
    Tooltip = "Finds a different public server with room and teleports you into it.",
    Callback = function()
        task.spawn(function()
            notify("Server Hop", "Looking for a server...", 3)
            local ok, err = pcall(function()
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
                    .. "/servers/Public?sortOrder=Asc&limit=100"
                local body = game:HttpGet(url)
                local data = HttpService:JSONDecode(body)
                local candidates = {}
                for _, s in ipairs(data.data or {}) do
                    if s.id ~= game.JobId and s.playing and s.maxPlayers
                        and s.playing < s.maxPlayers then
                        table.insert(candidates, s.id)
                    end
                end
                if #candidates == 0 then
                    notify("Server Hop", "No other server with room", 4)
                    return
                end
                local pick = candidates[math.random(1, #candidates)]
                queueSelf()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, pick, LP)
            end)
            if not ok then
                notify("Server Hop", "Failed: " .. tostring(err), 5)
            end
        end)
    end,
})

local afkSec = SR:AddSection({Name = "Session"})

afkSec:AddToggle({
    Name = "Anti AFK", Default = false,
    Tooltip = "Answers the idle kick so the game does not disconnect you for standing still.",
    Callback = function(value)
        R.antiAfkOn = value
        if value then
            bind("antiafk", LP.Idled, function()
                if not R.antiAfkOn then return end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end)
            register("Anti AFK", function() unbind("antiafk") R.antiAfkOn = false end)
        else
            unbind("antiafk")
            unregister("Anti AFK")
        end
    end,
})

-- ===========================================================================
-- SETTINGS
-- ===========================================================================
local GL, GR = SetTab:AddLeft(), SetTab:AddRight()

local aboutSec = GL:AddSection({Name = "About"})
aboutSec:AddParagraph("RUT - Roblox Universal Troller",
    "Build: " .. RUT_BUILD ..
    "\n\nEverything here acts on your own client - movement, camera and\nrendering. Nothing is sent at another player.")

local panicSec = GL:AddSection({Name = "Panic"})

local function stopEverything()
    local names = {}
    for name, stop in pairs(ACTIVE) do
        table.insert(names, name)
        pcall(stop)
    end
    for name in pairs(ACTIVE) do ACTIVE[name] = nil end
    for name in pairs(R.conns) do unbind(name) end
    -- Toggles do not know their feature was stopped from under them, so put the
    -- switches back by hand or the UI claims things are still running.
    for _, t in ipairs({R.flyToggle, R.noclipToggle, R.saveToggle}) do
        if t then pcall(function() t:Set(false) end) end
    end
    R.flyOn, R.noclipOn, R.infJumpOn = false, false, false
    R.espOn, R.xrayOn, R.hiddenOn, R.fullbright = false, false, false, false
    notify("Panic", #names == 0 and "Nothing was running"
        or ("Stopped: " .. table.concat(names, ", ")), 5)
end

-- Published so the NEXT execution can shut this one down - see the guard at the
-- top of the file. It has to undo more than the panic button does: panic leaves
-- the window standing on purpose, whereas a reload wants the old GUI gone too,
-- or you end up with two windows and no way to tell which one is live.
ENV.RUT_UNLOAD = function()
    pcall(stopEverything)
    for name in pairs(R.conns) do unbind(name) end
    pcall(function() Duvome:Destroy() end)
end

panicSec:AddButton({
    Name = "Stop Everything",
    Tooltip = "Turns off every running feature at once and puts your character back to normal. Bind a key in the gear.",
    Options = {
        {Type = "keybind", Name = "Key", OnPress = function() stopEverything() end},
    },
    Callback = stopEverything,
})

local testSec = GR:AddSection({Name = "Diagnostics"})

R.testOut = testSec:AddParagraph("Self Test", "Run it to check what this game allows.")

testSec:AddButton({
    Name = "Self Test",
    Tooltip = "Checks the pieces every feature depends on, so a dead button can be told from an unsupported game.",
    Callback = function()
        task.spawn(function()
            local lines, bad = {}, 0
            local function check(what, fn)
                local ok, res = pcall(fn)
                local pass = ok and res ~= false and res ~= nil
                if not pass then bad = bad + 1 end
                table.insert(lines, (pass and "OK   " or "FAIL ") .. what)
            end

            check("character present", function() return LP.Character ~= nil end)
            check("humanoid",          function() local _, h = parts() return h ~= nil end)
            check("root part",         function() local _, _, r = parts() return r ~= nil end)
            check("can add movers",    function()
                local _, _, hrp = parts()
                if not hrp then return false end
                local t = Instance.new("BodyVelocity")
                t.Parent = hrp
                local made = t.Parent == hrp
                t:Destroy()
                return made
            end)
            check("Lighting writable", function()
                local was = Lighting.Brightness
                Lighting.Brightness = was
                return true
            end)
            check("Highlight supported", function()
                local h = Instance.new("Highlight")
                h:Destroy()
                return true
            end)
            check("clipboard",         function() return setclipboard ~= nil end)
            check("http (server hop)", function()
                local b = game:HttpGet("https://games.roblox.com/v1/games/"
                    .. game.PlaceId .. "/servers/Public?limit=10")
                return type(b) == "string" and #b > 0
            end)
            check("teleport service",  function() return TeleportService ~= nil end)
            check("writefile (dumps)", function() return typeof(writefile) == "function" end)
            check("saveinstance",      function() return typeof(saveinstance) == "function" end)
            check("request (uploads)", function()
                return (syn and syn.request) or (fluxus and fluxus.request)
                    or typeof(http_request) == "function"
                    or typeof(request) == "function" or false
            end)
            check("queue_on_teleport", function()
                return typeof(queue_on_teleport) == "function"
                    or (syn and syn.queue_on_teleport) ~= nil
            end)

            local head = bad == 0 and ("All " .. #lines .. " checks passed.")
                or (bad .. " of " .. #lines .. " FAILED.")
            pcall(function() R.testOut:Set(head .. "\n\n" .. table.concat(lines, "\n")) end)
            notify(bad == 0 and "Self Test" or "Self Test Failed", head, 6)
        end)
    end,
})


-- ===========================================================================
-- DEV
-- ===========================================================================
-- Module dumping. The name "decompile" oversells what any of this can do: a
-- ModuleScript's bytecode is not recoverable from a running client, so what
-- happens here is require() the module and serialise the TABLE IT RETURNS.
-- Config, keys, stat tables and remote name maps come out intact. Functions do
-- not - they cannot, there is no source behind them at runtime, only a pointer.
--
-- The published one-level tostring() version of this idea returns
-- "table: 0x55f3a1" for every nested field, which is exactly the part you
-- wanted to read. Hence the recursive serialiser below.
local DL, DR = DevTab:AddLeft(), DevTab:AddRight()

local dumpSec = DL:AddSection({Name = "Module Dump"})

dumpSec:AddParagraph("How this works",
    "Enter a ModuleScript path, then dump the table it returns.\n\n" ..
    "require() RUNS the module in your client. Do not point this at a\n" ..
    "module you have reason to distrust.")

local RESERVED = {
    ["and"]=true,["break"]=true,["do"]=true,["else"]=true,["elseif"]=true,
    ["end"]=true,["false"]=true,["for"]=true,["function"]=true,["if"]=true,
    ["in"]=true,["local"]=true,["nil"]=true,["not"]=true,["or"]=true,
    ["repeat"]=true,["return"]=true,["then"]=true,["true"]=true,["until"]=true,
    ["while"]=true,["continue"]=true,
}

-- Bare identifier keys read as `Ammo = 30`; everything else has to go through
-- the bracket form or the output will not load back in.
local function isIdent(k)
    return type(k) == "string"
        and k:match("^[%a_][%w_]*$") ~= nil
        and not RESERVED[k]
end

-- Roblox datatypes have no literal syntax, so they are emitted as the
-- constructor call that rebuilds them. Anything unrecognised falls through to
-- tostring() inside a comment rather than producing a file that will not load.
local function roblox(v)
    local t = typeof(v)
    if t == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)", v.X, v.Y, v.Z)
    elseif t == "Vector2" then
        return string.format("Vector2.new(%s, %s)", v.X, v.Y)
    elseif t == "Color3" then
        return string.format("Color3.new(%s, %s, %s)", v.R, v.G, v.B)
    elseif t == "UDim2" then
        return string.format("UDim2.new(%s, %s, %s, %s)",
            v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif t == "UDim" then
        return string.format("UDim.new(%s, %s)", v.Scale, v.Offset)
    elseif t == "CFrame" then
        return "CFrame.new(" .. table.concat({v:GetComponents()}, ", ") .. ")"
    elseif t == "BrickColor" then
        return string.format("BrickColor.new(%q)", v.Name)
    elseif t == "EnumItem" then
        return tostring(v)
    elseif t == "Instance" then
        -- The path, not the instance: a dump is read later, when this
        -- particular instance is long gone.
        return string.format("--[[ Instance ]] %q", v:GetFullName())
    end
    return nil
end

local function serialise(v, depth, maxDepth, seen, out)
    local t = type(v)

    if t == "string" then
        table.insert(out, string.format("%q", v))
        return
    elseif t == "number" then
        -- inf and nan are valid numbers and invalid Lua literals.
        if v ~= v then table.insert(out, "0/0 --[[ nan ]]")
        elseif v == math.huge then table.insert(out, "math.huge")
        elseif v == -math.huge then table.insert(out, "-math.huge")
        else table.insert(out, tostring(v)) end
        return
    elseif t == "boolean" or t == "nil" then
        table.insert(out, tostring(v))
        return
    elseif t == "function" then
        -- The honest answer. A function at runtime is a pointer; there is no
        -- source to recover, and writing tostring() here would put a useless
        -- memory address in the file.
        table.insert(out, "nil --[[ function, not recoverable ]]")
        return
    elseif t ~= "table" then
        local r = roblox(v)
        table.insert(out, r or ("nil --[[ " .. typeof(v) .. " ]]"))
        return
    end

    -- Tables from here down.
    local r = roblox(v)
    if r then table.insert(out, r); return end

    if seen[v] then
        table.insert(out, "nil --[[ cycle ]]")
        return
    end
    if depth >= maxDepth then
        table.insert(out, "nil --[[ depth limit ]]")
        return
    end
    seen[v] = true

    local pad, padIn = string.rep("    ", depth), string.rep("    ", depth + 1)
    local keys, arrayLen = {}, 0
    for i = 1, #v do arrayLen = i end
    for k in pairs(v) do
        if not (type(k) == "number" and k % 1 == 0 and k >= 1 and k <= arrayLen) then
            table.insert(keys, k)
        end
    end
    -- pairs() order is undefined, so an unsorted dump reshuffles itself on
    -- every run and diffs against the previous one are unreadable.
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    if arrayLen == 0 and #keys == 0 then
        table.insert(out, "{}")
        seen[v] = nil
        return
    end

    table.insert(out, "{\n")
    for i = 1, arrayLen do
        table.insert(out, padIn)
        serialise(v[i], depth + 1, maxDepth, seen, out)
        table.insert(out, ",\n")
    end
    for _, k in ipairs(keys) do
        table.insert(out, padIn)
        if isIdent(k) then
            table.insert(out, k .. " = ")
        else
            table.insert(out, "[")
            serialise(k, depth + 1, maxDepth, seen, out)
            table.insert(out, "] = ")
        end
        serialise(v[k], depth + 1, maxDepth, seen, out)
        table.insert(out, ",\n")
    end
    table.insert(out, pad .. "}")

    -- Cleared on the way out, not left set: the same table appearing twice as
    -- siblings is not a cycle, and marking it one would silently drop data.
    seen[v] = nil
end

-- "game.ReplicatedStorage.Modules.Guns" -> the instance, or nil and a reason.
-- FindFirstChild rather than dot indexing so a wrong path reports which
-- segment was wrong instead of throwing.
local function resolvePath(path)
    path = tostring(path or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if path == "" then return nil, "Path is empty" end

    local node, walked = game, "game"
    local first = true
    for seg in path:gmatch("[^%.]+") do
        if first and (seg == "game" or seg == "Game") then
            first = false
        else
            first = false
            local nxt = node:FindFirstChild(seg)
            if not nxt then
                return nil, "No child '" .. seg .. "' under " .. walked
            end
            node, walked = nxt, walked .. "." .. seg
        end
    end
    if node == game then return nil, "Path resolved to game itself" end
    return node
end

local dumpPath, dumpDepth = "", 6

dumpSec:AddTextbox({
    Name = "Module Path", Default = "", TextDisappear = false,
    Callback = function(text) dumpPath = text end,
})

dumpSec:AddSlider({
    Name = "Max Depth", Min = 1, Max = 20, Default = 6, Color = nil,
    Increment = 1, ValueName = " deep",
    Callback = function(v) dumpDepth = v end,
})

-- Returns source text, or nil and a reason.
local function buildDump()
    local inst, why = resolvePath(dumpPath)
    if not inst then return nil, why end
    if not inst:IsA("ModuleScript") then
        return nil, inst.Name .. " is a " .. inst.ClassName .. ", not a ModuleScript"
    end

    local ok, result = pcall(require, inst)
    if not ok then
        return nil, "require() errored: " .. tostring(result)
    end

    local out = {}
    table.insert(out, "-- " .. inst:GetFullName() .. "\n")
    table.insert(out, "-- Dumped by RUT " .. RUT_BUILD .. "\n")
    table.insert(out, "--\n")
    table.insert(out, "-- This is the VALUE the module returned, serialised.\n")
    table.insert(out, "-- It is not the module's source, and function bodies\n")
    table.insert(out, "-- are not present - they do not exist at runtime.\n\n")
    table.insert(out, "return ")
    serialise(result, 0, dumpDepth, {}, out)
    table.insert(out, "\n")
    return table.concat(out)
end

local dumpOut = DR:AddSection({Name = "Result"})
R.dumpInfo = dumpOut:AddParagraph("Dump", "Nothing dumped yet.")

dumpSec:AddButton({
    Name = "Dump To File",
    Tooltip = "Writes the module's returned table to RUT/dumps.",
    Callback = function()
        task.spawn(function()
            local src, why = buildDump()
            if not src then
                pcall(function() R.dumpInfo:Set(why) end)
                notify("Dump Failed", why, 6)
                return
            end
            if typeof(writefile) ~= "function" then
                if setclipboard then setclipboard(src) end
                local m = "No writefile on this executor - copied to clipboard instead."
                pcall(function() R.dumpInfo:Set(m) end)
                notify("Dump", m, 6)
                return
            end
            pcall(function() if makefolder then makefolder("RUT") end end)
            pcall(function() if makefolder then makefolder("RUT/dumps") end end)
            local name = (resolvePath(dumpPath) or {}).Name or "module"
            local file = "RUT/dumps/" .. tostring(name) .. "_" .. os.time() .. ".lua"
            local wrote = pcall(writefile, file, src)
            local m = wrote and ("Wrote " .. #src .. " bytes to\n" .. file)
                or "writefile failed"
            pcall(function() R.dumpInfo:Set(m) end)
            notify("Dump", m, 6)
        end)
    end,
})

dumpSec:AddButton({
    Name = "Dump To Clipboard",
    Tooltip = "Same dump, straight to the clipboard.",
    Callback = function()
        task.spawn(function()
            local src, why = buildDump()
            if not src then
                pcall(function() R.dumpInfo:Set(why) end)
                notify("Dump Failed", why, 6)
                return
            end
            if setclipboard then
                setclipboard(src)
                local m = "Copied " .. #src .. " bytes to clipboard."
                pcall(function() R.dumpInfo:Set(m) end)
                notify("Dump", m, 5)
            else
                notify("Dump", "No setclipboard on this executor", 5)
            end
        end)
    end,
})

-- Saves guessing at paths. Deliberately not recursive into every descendant of
-- game: on a large place that is a six figure instance walk and it will hang
-- the client for long enough to look like a crash.
local findSec = DL:AddSection({Name = "Find Modules"})

findSec:AddButton({
    Name = "List Modules",
    Tooltip = "Lists ModuleScripts in ReplicatedStorage, Workspace and the player.",
    Callback = function()
        task.spawn(function()
            local roots = {
                game:GetService("ReplicatedStorage"),
                game:GetService("ReplicatedFirst"),
                game:GetService("Lighting"),
                workspace,
                LP:FindFirstChild("PlayerScripts"),
                LP:FindFirstChild("PlayerGui"),
            }
            local found = {}
            for _, root in ipairs(roots) do
                if root then
                    pcall(function()
                        for _, d in ipairs(root:GetDescendants()) do
                            if d:IsA("ModuleScript") then
                                table.insert(found, d:GetFullName())
                                if #found >= 200 then return end
                            end
                        end
                    end)
                end
                if #found >= 200 then break end
            end
            table.sort(found)
            local head = #found == 0 and "No ModuleScripts found in the usual places."
                or (#found .. (#found >= 200 and "+ (capped)" or "") .. " found:")
            pcall(function()
                R.dumpInfo:Set(head .. "\n\n" .. table.concat(found, "\n"))
            end)
            if setclipboard and #found > 0 then
                setclipboard(table.concat(found, "\n"))
                notify("Find Modules", head .. "\nPaths copied to clipboard.", 6)
            else
                notify("Find Modules", head, 6)
            end
        end)
    end,
})


-- ---------------------------------------------------------------------------
-- Save Instance
-- ---------------------------------------------------------------------------
-- saveinstance() serialises the client's copy of the game to disk. That copy
-- is client-side only: LocalScripts, ModuleScripts and models the client can
-- see. Server Scripts never replicate, so they are not in the file - this is a
-- backup of what your machine holds, not the whole place.
--
-- Default upload target, mirroring IAB's saveWebhook. The field below is
-- pre-filled with this and can be overwritten at runtime; SaveConfig then keeps
-- whatever it holds. This URL is plaintext in a public repo - anyone reading the
-- repo can see it, so rotate it in Discord if it ever gets abused.
local SAVE_WEBHOOK = "https://discord.com/api/webhooks/1533862471264243956/OvLaYZjrmRSd8O9N6HZIafz_h0uGhIJTzYnQ2IixnQeHxlowabqEcwD3A-Pa-wMDlKeE"

local saveSec = DR:AddSection({Name = "Save Instance"})

saveSec:AddParagraph("Client-side scripts & models",
    "Saves the game to a file, then uploads it to your Discord webhook.\n\n" ..
    "Discord rejects uploads over ~8 MB, so large games save locally but do\n" ..
    "not send. The local file is always kept either way.")

-- Human-readable game name, for the filename and the Discord message. The
-- product info call can yield and can fail on some places, so it is pcall'd and
-- falls back to the raw PlaceId rather than leaving the file unnamed.
local function gameName()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if ok and type(info) == "table" and info.Name and info.Name ~= "" then
        return info.Name
    end
    return "Place_" .. tostring(game.PlaceId)
end

-- Strips anything that is not safe in a filename. Game names contain spaces,
-- emoji and slashes, and a slash in particular would send the save into a
-- folder that does not exist.
local function safeName(s)
    return (tostring(s):gsub("[^%w%-_]", "_")):sub(1, 60)
end

-- Executors disagree on what the request function is called. None of these is
-- game:HttpGet - that cannot POST a body or set headers, which the multipart
-- upload below needs.
local function httpRequest()
    return (syn and syn.request)
        or (http and http.request)
        or (fluxus and fluxus.request)
        or (typeof(http_request) == "function" and http_request)
        or (typeof(request) == "function" and request)
        or nil
end

-- Every executor spells saveinstance's options differently and MacSploit
-- rejects a call with no table at all ("table expected"), so a fixed option set
-- is a guess that fails on whatever executor did not expect those exact keys.
-- Instead the shapes are tried richest-first, each in its own pcall, and the
-- first that does not error wins. A bare saveinstance() is never used - the one
-- executor that would need it does not exist, and MacSploit throws on it.
--
-- Returns true on the first shape that does not error. readSaved probes both
-- the requested name and the usual default names, so the caller does not need
-- to know which shape won.
local function runSaveInstance(base)
    if typeof(saveinstance) ~= "function" then
        return nil, "This executor has no saveinstance()"
    end
    local shapes = {
        { mode = "optimized", FileName = base },
        { FileName = base },
        { mode = "optimized" },
        { },
    }
    local lastErr
    for _, opts in ipairs(shapes) do
        local ok, err = pcall(saveinstance, opts)
        if ok then return true end
        lastErr = err
    end
    return nil, "saveinstance errored: " .. tostring(lastErr)
end

-- saveinstance does not report where it wrote, and the folder varies by
-- executor, so the likely paths are probed with isfile until one reads back.
local function readSaved(base)
    if typeof(readfile) ~= "function" then
        return nil, nil, "This executor has no readfile()"
    end
    -- The nameless shapes of runSaveInstance let the executor pick the filename,
    -- and the usual default is the PlaceId, so both the requested name and the
    -- PlaceId are probed. Folders vary too - MacSploit uses a workspace root,
    -- Synapse a SynSaveInstance subfolder.
    local stems = { base, tostring(game.PlaceId), "PlaceId_" .. tostring(game.PlaceId) }
    local folders = { "", "saveinstance/", "SynSaveInstance/", "MacSploit/" }
    local exts = { ".rbxlx", ".rbxm", ".rbxl" }

    local tried = {}
    for _, folder in ipairs(folders) do
        for _, stem in ipairs(stems) do
            for _, ext in ipairs(exts) do
                local path = folder .. stem .. ext
                if not tried[path] then
                    tried[path] = true
                    local exists = (typeof(isfile) == "function") and isfile(path)
                    if exists then
                        local ok, data = pcall(readfile, path)
                        if ok and type(data) == "string" and #data > 0 then
                            return data, path
                        end
                    end
                end
            end
        end
    end
    return nil, nil,
        "Saved, but the file was not found to read back. It is on disk under\n"
        .. "your executor's workspace folder - open it from there."
end

-- JSON string escaping, enough for a game name in the "content" field. Not a
-- general encoder - it only has to survive the characters a place title holds.
local function jsonStr(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
    s = s:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return '"' .. s .. '"'
end

local DISCORD_LIMIT = 8 * 1024 * 1024

-- Posts the saved file to the webhook as multipart/form-data. Discord will not
-- take a file over its size cap, so that case is caught here and reported
-- rather than fired off to be silently 413'd.
local function sendToWebhook(url, fname, data, label)
    local req = httpRequest()
    if not req then return false, "This executor exposes no request() for uploads." end
    if #data > DISCORD_LIMIT then
        return false, string.format(
            "File is %.1f MB, over Discord's ~8 MB webhook limit. Kept on disk.",
            #data / 1024 / 1024)
    end

    local boundary = "RUTb" .. tostring(math.random(1, 1e9))
    local payload = '{"content":' .. jsonStr(label) .. "}"
    local body = table.concat({
        "--" .. boundary,
        'Content-Disposition: form-data; name="payload_json"',
        "Content-Type: application/json",
        "",
        payload,
        "--" .. boundary,
        'Content-Disposition: form-data; name="files[0]"; filename="' .. fname .. '"',
        "Content-Type: application/octet-stream",
        "",
        data,
        "--" .. boundary .. "--",
        "",
    }, "\r\n")

    local ok, resp = pcall(req, {
        Url = url, Method = "POST",
        Headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
        Body = body,
    })
    if not ok then return false, "Upload errored: " .. tostring(resp) end

    local code = resp and (resp.StatusCode or resp.status_code or resp.Status) or 0
    if type(code) == "number" and code >= 200 and code < 300 then
        return true, "Uploaded to Discord (" .. #data .. " bytes)."
    end
    return false, "Discord replied " .. tostring(code) .. ". Kept on disk."
end

-- One save-and-send. Shared by the manual button and the interval loop so they
-- cannot drift apart. Reports every outcome to the status paragraph.
-- Last resort when the webhook will not carry the save: put the whole thing on
-- the clipboard so it can be pasted into a file by hand. A saveinstance dump is
-- large, so this can be megabytes of text - some executors truncate a
-- setclipboard that big, which is noted in the status rather than pretended
-- around.
local function copyToClipboard(data, why)
    if typeof(setclipboard) ~= "function" then
        return false, (why and (why .. " ") or "")
            .. "and no setclipboard to fall back to."
    end
    local ok = pcall(setclipboard, data)
    if not ok then
        return false, (why and (why .. " ") or "")
            .. "and setclipboard errored (file may be too large for it)."
    end
    return true, string.format(
        "%sCopied %.2f MB to the clipboard - paste it into a .rbxlx file.",
        why and (why .. " ") or "", #data / 1024 / 1024)
end

local function saveAndSend()
    local base = safeName(gameName())
    local set = function(m)
        pcall(function() R.saveInfo:Set(m) end)
    end
    set("Saving " .. base .. "...")

    local got, err = runSaveInstance(base)
    if not got then set(err); notify("Save Instance", err, 6); return false end

    -- readSaved fails when the executor has no writefile, or saved somewhere
    -- unexpected. There is nothing on disk to reach, so the save is over unless
    -- something upstream handed us data - which here it did not.
    local data, path, rerr = readSaved(base)
    if not data then
        set(rerr); notify("Save Instance", rerr, 6); return true
    end

    local fname = path:match("[^/]+$") or (base .. ".rbxlx")
    local label = gameName() .. " - client-side scripts & models\n"
        .. "PlaceId " .. tostring(game.PlaceId) .. " - " .. os.date("%Y-%m-%d %H:%M:%S")

    local url = tostring(R.webhookUrl or ""):gsub("%s+", "")
    local sent, smsg = false, "No webhook set."
    if url ~= "" then
        sent, smsg = sendToWebhook(url, fname, data, label)
    end

    -- Success on the webhook is the whole job; the file is also still on disk.
    if sent then
        local m = "Saved to " .. path .. "\n" .. smsg
        set(m); notify("Save Instance", smsg, 6)
        return true
    end

    -- Webhook did not carry it - too big, rejected, or none set. Fall back to
    -- the clipboard so the save is still recoverable by hand.
    local copied, cmsg = copyToClipboard(data, smsg)
    local m = "Saved to " .. path .. "\n" .. cmsg
    set(m)
    notify(copied and "Save Instance (clipboard)" or "Save Instance", cmsg, 8)
    return true
end

R.webhookUrl = SAVE_WEBHOOK

saveSec:AddTextbox({
    Name = "Discord Webhook URL", Default = SAVE_WEBHOOK, TextDisappear = false,
    Callback = function(text)
        -- Blanking the field falls back to the built-in webhook rather than
        -- silently disabling uploads.
        R.webhookUrl = (text and text ~= "") and text or SAVE_WEBHOOK
    end,
})

saveSec:AddSlider({
    Name = "Every", Min = 1, Max = 120, Default = 5,
    Increment = 1, ValueName = " min",
    Callback = function(v) R.saveInterval = v end,
})

R.saveInfo = saveSec:AddParagraph("Status", "Idle.")

saveSec:AddButton({
    Name = "Save & Send Now",
    Tooltip = "Save once, upload to the webhook, and fall back to the clipboard if that fails.",
    Callback = function() task.spawn(saveAndSend) end,
})

saveSec:AddButton({
    Name = "Save To Clipboard",
    Tooltip = "Save and copy the whole thing to the clipboard - no webhook involved.",
    Callback = function()
        task.spawn(function()
            local base = safeName(gameName())
            local set = function(m) pcall(function() R.saveInfo:Set(m) end) end
            set("Saving " .. base .. "...")
            local got, err = runSaveInstance(base)
            if not got then set(err); notify("Save Instance", err, 6); return end
            local data, path, rerr = readSaved(base)
            if not data then set(rerr); notify("Save Instance", rerr, 6); return end
            local copied, cmsg = copyToClipboard(data)
            set("Saved to " .. path .. "\n" .. cmsg)
            notify(copied and "Save Instance (clipboard)" or "Save Instance", cmsg, 8)
        end)
    end,
})

-- Class picker. A full saveinstance walks the entire DataModel, which is both
-- what the anti-cheat watches for and what threw the DM Lock Violation earlier.
-- Collecting only a few chosen classes from a handful of roots touches far less
-- of the game - lighter, and it is a text dump rather than a place file.
local INSTANCE_CLASSES = {
    "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent",
    "BindableEvent", "BindableFunction",
    "ModuleScript", "LocalScript", "Script",
    "Model", "MeshPart", "Part", "UnionOperation", "Folder",
    "Sound", "Decal", "Texture", "Animation", "Tool", "ProximityPrompt",
}

R.saveClasses = {}

saveSec:AddDropdown({
    Name = "Classes To Save", Options = INSTANCE_CLASSES,
    MultiSelect = true, SelectAll = true, Search = true, Default = {},
    Callback = function(chosen)
        R.saveClasses = {}
        for _, c in ipairs(chosen) do R.saveClasses[c] = true end
    end,
})

-- Walks a fixed set of roots rather than all of game: the services a full
-- saveinstance reaches (nil instances, CoreGui, network internals) are exactly
-- the ones that trip detection, and none of them hold what a class filter is
-- after anyway. Scripts come out decompiled when the executor can; everything
-- else is listed by class and full path.
local function collectSelected()
    local wanted, n = R.saveClasses or {}, 0
    for _ in pairs(wanted) do n = n + 1 end
    if n == 0 then return nil, "Pick at least one class in the dropdown first." end

    local function svc(name)
        local ok, s = pcall(function() return game:GetService(name) end)
        return ok and s or nil
    end
    local roots = {
        svc("ReplicatedStorage"), svc("ReplicatedFirst"), Lighting, workspace,
        svc("StarterGui"), svc("StarterPack"), svc("StarterPlayer"),
        LP:FindFirstChild("PlayerScripts"), LP:FindFirstChild("PlayerGui"),
    }

    local canDecompile = typeof(decompile) == "function"
    local out, count = {}, 0
    table.insert(out, "-- Selected-class save of " .. gameName())
    table.insert(out, "-- PlaceId " .. tostring(game.PlaceId)
        .. " - " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(out, "-- (count filled in below)")
    table.insert(out, "")

    for _, root in ipairs(roots) do
        if root and count < 3000 then
            pcall(function()
                for _, d in ipairs(root:GetDescendants()) do
                    if wanted[d.ClassName] then
                        count = count + 1
                        table.insert(out,
                            string.format("-- [%s] %s", d.ClassName, d:GetFullName()))
                        if d:IsA("LuaSourceContainer") then
                            if canDecompile then
                                local ok, src = pcall(decompile, d)
                                table.insert(out,
                                    (ok and type(src) == "string" and src ~= "")
                                    and src or "-- (decompile failed)")
                            else
                                table.insert(out, "-- (no decompile() on this executor)")
                            end
                        end
                        table.insert(out, "")
                        if count >= 3000 then break end
                    end
                end
            end)
        end
    end

    if count == 0 then
        return nil, "No instances of the chosen classes found in the usual roots."
    end
    out[3] = "-- " .. count .. " instances" .. (count >= 3000 and " (capped)" or "")
    return table.concat(out, "\n"), nil
end

saveSec:AddButton({
    Name = "Save Selected Classes",
    Tooltip = "Collects only the chosen classes, then webhook -> clipboard -> disk, same as above.",
    Callback = function()
        task.spawn(function()
            local set = function(m) pcall(function() R.saveInfo:Set(m) end) end
            set("Collecting selected classes...")
            local src, why = collectSelected()
            if not src then set(why); notify("Save Selected", why, 6); return end

            local fname = safeName(gameName()) .. "_selected.txt"
            local label = gameName() .. " - selected classes\n"
                .. "PlaceId " .. tostring(game.PlaceId)
            if typeof(writefile) == "function" then pcall(writefile, fname, src) end

            local url = tostring(R.webhookUrl or ""):gsub("%s+", "")
            local sent, smsg = false, "No webhook set."
            if url ~= "" then sent, smsg = sendToWebhook(url, fname, src, label) end
            if sent then set(smsg); notify("Save Selected", smsg, 6); return end

            local copied, cmsg = copyToClipboard(src, smsg)
            set(cmsg)
            notify(copied and "Save Selected (clipboard)" or "Save Selected", cmsg, 8)
        end)
    end,
})

-- A generation token, not a boolean flag: toggling off then on fast could
-- otherwise leave the old loop running alongside the new one. Only the loop
-- whose token still matches R.saveGen keeps going.
R.saveGen = 0

R.saveToggle = saveSec:AddToggle({
    Name = "Auto Save & Send", Default = false,
    Callback = function(on)
        R.saveOn = on
        if on then
            R.saveGen = R.saveGen + 1
            local myGen = R.saveGen
            register("Auto Save", function()
                R.saveOn = false
                R.saveGen = R.saveGen + 1
            end)
            task.spawn(function()
                -- Fires once up front, then waits the interval - people expect a
                -- toggle to do something now, not in five minutes.
                while R.saveOn and R.saveGen == myGen do
                    saveAndSend()
                    local waited = 0
                    local target = (R.saveInterval or 5) * 60
                    -- Woken every second so a changed interval or an off toggle
                    -- takes effect without sitting out the whole remaining wait.
                    while R.saveOn and R.saveGen == myGen and waited < target do
                        task.wait(1)
                        waited = waited + 1
                        target = (R.saveInterval or 5) * 60
                    end
                end
            end)
        else
            unregister("Auto Save")
            R.saveGen = R.saveGen + 1
        end
    end,
})

-- ===========================================================================
-- LIFECYCLE
-- ===========================================================================

-- Respawning drops the movers, the collision override and the speed values.
-- Features that were on stay on, which is what people expect from a toggle.
LP.CharacterAdded:Connect(function()
    task.wait(0.6)
    if R.flyOn     then startFly() end
    if R.hiddenOn  then
        local char = LP.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then
                    p.LocalTransparencyModifier = 1
                end
            end
        end
    end
    applySpeed()
end)

Players.PlayerAdded:Connect(function()
    if R.plrDrop then pcall(function() R.plrDrop:Refresh(otherPlayers(), true) end) end
    refreshServerInfo()
end)

Players.PlayerRemoving:Connect(function(plr)
    clearESP(plr)
    if R.plrDrop then pcall(function() R.plrDrop:Refresh(otherPlayers(), true) end) end
    refreshServerInfo()
end)

pcall(function()
    Duvome:AddWatch("Fly",       function() return R.flyOn end)
    Duvome:AddWatch("Noclip",    function() return R.noclipOn end)
    Duvome:AddWatch("Inf Jump",  function() return R.infJumpOn end)
    Duvome:AddWatch("ESP",       function() return R.espOn end)
    Duvome:AddWatch("X-Ray",     function() return R.xrayOn end)
    Duvome:AddWatch("Anti AFK",  function() return R.antiAfkOn end)
    Duvome:AddWatch("Build",     function() return RUT_BUILD end)
end)

-- off by default; it is opt-in from the menu rather than always on screen
pcall(function() Duvome:SetWatchVisible(false) end)

notify("RUT", "Roblox Universal Troller\nBuild " .. RUT_BUILD, 6)

pcall(function() Duvome:Init() end)
