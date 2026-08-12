-- The "?t=" is not decoration: raw.githubusercontent is behind a CDN that
-- serves a stale copy for minutes after a push, so without it you can
-- re-execute all day and still get the old library.
local Duvome = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/aparaanana-hue/DW/refs/heads/main/DL.lua"
        .. "?t=" .. tostring(os.time())))()
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer

Duvome:Init()


-- Bumped on every push. If the notification on load does not match the
-- newest commit, the script came from a cache, not from GitHub.
local IAB_BUILD = "Aug 14 15:00"

local DuvomeWindow = Duvome:MakeWindow({
    Name         = "Priz's Islands Hub",
    IntroText    = "Priz's Islands Hub",
    ConfigFolder = "PrizIslandsHub",
    SaveConfig   = true,
    AutoLoadConfig = false,
    IntroEnabled = true,
    ShowIcon     = true,
})

local function _asTable(v)
    if type(v) == "table" then return v end
    return { v }
end

-- Compatibility shim over the Duvome element API.
-- Legacy config keys (CurrentValue / Range / Suffix / CurrentOption / MultipleOptions)
-- still work. Native extras are passed through where the library supports them:
--   Tooltip  -> buttons and toggles only
--   Keybind  -> buttons and toggles (ShowKeybind)
--   Gear     -> toggles (popover with colorpicker/slider/toggle/keybind rows)
--   Color    -> toggles, sliders, range sliders
--   Collapsible / Column -> sections
local function wrapTab(container)
    local tab = {}

    local left = container:AddLeft()
    local right = container:AddRight()
    local current = left
    local sectionCount = 0

    local currentSection = nil
    local function cur()
        return currentSection or current
    end

    -- opts.Column = "left"/"right" pins a side, otherwise sections alternate.
    -- opts.Collapsible starts the section folded.
    function tab:CreateSection(name, opts)
        opts = opts or {}
        sectionCount = sectionCount + 1
        if opts.Column == "left" then
            current = left
        elseif opts.Column == "right" then
            current = right
        else
            current = (sectionCount % 2 == 1) and left or right
        end
        currentSection = current:AddSection({
            Name = name,
            Collapsible = opts.Collapsible,
            -- sections default to 0 and fall back to creation order; Order lets
            -- one built later still sit above one built earlier
            Order = opts.Order,
        })
        return currentSection
    end

    function tab:CreateDivider()
        return cur():AddDivider()
    end

    function tab:CreateButton(cfg)
        return cur():AddButton({
            Name = cfg.Name,
            Tooltip = cfg.Tooltip,
            ShowKeybind = cfg.Keybind,
            Options = cfg.Gear,
            Callback = cfg.Callback or function() end,
        })
    end

    function tab:CreateToggle(cfg)
        return cur():AddToggle({
            Name = cfg.Name,
            Default = cfg.CurrentValue or false,
            Flag = cfg.Flag,
            Save = cfg.Flag ~= nil,
            Tooltip = cfg.Tooltip,
            Color = cfg.Color,
            ShowKeybind = cfg.Keybind,
            Options = cfg.Gear,
            -- icon button on the toggle row, for an action that should not
            -- require flipping the toggle
            GearAction = cfg.GearAction,
            Callback = cfg.Callback or function() end,
        })
    end

    function tab:CreateSlider(cfg)
        local rng = cfg.Range or { 0, 100 }
        return cur():AddSlider({
            Name = cfg.Name,
            Min = rng[1],
            Max = rng[2],
            Increment = cfg.Increment or 1,
            Default = cfg.CurrentValue or rng[1],
            ValueName = cfg.Suffix or "",
            Flag = cfg.Flag,
            Save = cfg.Flag ~= nil,
            Color = cfg.Color,
            Callback = cfg.Callback or function() end,
        })
    end

    function tab:CreateRangeSlider(cfg)
        local rng = cfg.Range or { 0, 100 }
        return cur():AddRangeSlider({
            Name = cfg.Name,
            Min = rng[1],
            Max = rng[2],
            DefaultMin = cfg.DefaultMin or rng[1],
            DefaultMax = cfg.DefaultMax or rng[2],
            Increment = cfg.Increment or 1,
            ValueName = cfg.Suffix or "",
            Flag = cfg.Flag,
            Save = cfg.Flag ~= nil,
            Color = cfg.Color,
            Callback = cfg.Callback or function() end,
        })
    end

    function tab:CreateColorpicker(cfg)
        return cur():AddColorpicker({
            Name = cfg.Name,
            Default = cfg.Default or Color3.fromRGB(255, 255, 255),
            UseAlpha = cfg.UseAlpha,
            Flag = cfg.Flag,
            Save = cfg.Flag ~= nil,
            Callback = cfg.Callback or function() end,
        })
    end

    function tab:CreateBind(cfg)
        return cur():AddBind({
            Name = cfg.Name,
            Default = cfg.Default,
            Mode = cfg.Mode or "press",
            Interval = cfg.Interval,
            Flag = cfg.Flag,
            Save = cfg.Flag ~= nil,
            Callback = cfg.Callback or function() end,
        })
    end

    function tab:CreateDropdown(cfg)
        local default = cfg.CurrentOption
        if type(default) == "table" then default = default[1] end
        local d = cur():AddDropdown({
            Name = cfg.Name,
            Options = cfg.Options or {},
            Default = default or "",
            MultiSelect = cfg.MultipleOptions or false,
            SelectAll = cfg.MultipleOptions or false,
            Search = true,
            Gear = cfg.Gear,
            GearAction = cfg.GearAction,
            Actions = cfg.Actions,
            Flag = cfg.Flag,
            Save = cfg.Flag ~= nil,
            Callback = function(v)
                cfg.Callback(_asTable(v))
            end,
        })
        local rawSet = d.Set
        d.Set = function(self, val)
            if type(val) == "table" and not cfg.MultipleOptions then val = val[1] end
            return rawSet(self, val)
        end
        local rawRefresh = d.Refresh
        d.Refresh = function(self, options)
            return rawRefresh(self, options, true)
        end
        return d
    end

    function tab:CreateInput(cfg)
        return cur():AddTextbox({
            Name = cfg.Name,
            Default = cfg.Default or "",
            TextDisappear = cfg.RemoveTextAfterFocusLost or false,
            Actions = cfg.Actions,
            Callback = cfg.Callback or function() end,
        })
    end

    function tab:CreateParagraph(cfg)
        local p = cur():AddParagraph(cfg.Title or "", cfg.Content or "")
        local rawSet = p.Set
        p.Set = function(self, arg)
            if type(arg) == "table" then
                return rawSet(self, arg.Content or "")
            end
            return rawSet(self, arg)
        end
        return p
    end

    function tab:CreateLabel(text)
        return cur():AddLabel(text)
    end

    return tab
end

local main = {}
function main:CreateTab(name, icon)
    local container = DuvomeWindow:MakeTab({ Name = name, Icon = icon or "", Columns = true })
    return wrapTab(container)
end

-- Four tabs instead of eleven. The old per-feature tab variables now alias a
-- shared tab, so each feature keeps its own sections without its own tab.
local tabBuild    = main:CreateTab("Build", "layout-fluid")
local tabGenerate = main:CreateTab("Generate", "star")
local tabEdit     = main:CreateTab("Edit", "three-sliders-horizontal")
local tabConvert  = main:CreateTab("Convert", "gear")

-- Build: placing, previewing and saving a build file
local auto        = tabBuild
local previewTab  = tabBuild
local saveTab     = tabBuild

-- Generate: procedural content
local structTab   = tabGenerate
local cityTab     = tabGenerate
local platTab     = tabGenerate

-- Shared bridge between the Builder scope and the Operations/Colour scope.
local BuilderAPI = {}
-- Every saved-file kind registers here; one UI drives them all.
BuilderAPI.fileKinds = {}
-- Block destroyer settings. The runner lives in its own scope further down.
BuilderAPI.destroyer = {
    running   = false,
    abort     = false,
    types     = {},      -- empty means every type
    hits      = 3,       -- hits fired per attempt
    minDelay  = 20,      -- ms, low end of the gap between blocks
    maxDelay  = 60,      -- ms, high end
    hitGap    = 30,      -- ms between hits on the same block
    boxOnly   = true,    -- confine to the selection box
    brushOnly = false,   -- destroy exactly what the block brush painted
    confirm   = true,    -- wait until the block is actually gone
    maxTries  = 6,       -- attempts before giving up on a stubborn block
}
-- Toggle handles, so the watch list rows can flip them.
BuilderAPI.toggles = {}

local net = ReplicatedStorage
    :WaitForChild("rbxts_include")
    :WaitForChild("node_modules")
    :WaitForChild("@rbxts")
    :WaitForChild("net")
    :WaitForChild("out")
    :WaitForChild("_NetManaged")
    :WaitForChild("CLIENT_BLOCK_PLACE_REQUEST")

if not isfolder("autoBuilder") then
    makefolder("autoBuilder")
end

-- .glb models live in their own folder rather than mixed in with the build
-- files. MODEL_DIR is the one place that decides where, so the file list, the
-- loader and the delete button cannot drift apart.
MODEL_DIR = "autoBuilder/models"
if not isfolder(MODEL_DIR) then
    makefolder(MODEL_DIR)
end

-- Schematics dropped in here are converted on the Convert tab.
CONVERT_DIR = "autoBuilder/converter"
if not isfolder(CONVERT_DIR) then
    makefolder(CONVERT_DIR)
end

local placeDelay = 0.03
local retryDelay = 0.04
local verifyWaitTime = 1.5
local rounding = 0.1
local maxTriesPerBlock = 3

local selectedFile = nil
local isBuilding = false

local moveToBuildPosition = true
local movementThreshold = 60
local walkOffset = 15
local moveTimeout = 4
local waypointTimeout = 2.2

local buildFlySpeed = 35
local placeReach = 26
local buildStandoff = 12
-- how far Expand from Middle will reach from where it parked before re-parking
local expandReach = 120
local autoFillMissing = true
local maxFillPasses = 3
local groupByType = false
local verifyPlacements = true
local moveMode = "Fly"
local buildBottomUp = false
local buildMode = "Around Preview"
local onlyUseOwned = false
local placeMissingOnly = false
local adaptiveRate = false
local pipelineMode = false
local pipelineDepth = 8

local progressPlaced = 0
local progressTotal = 0
local progressStart = 0
local lastProgressUpdate = 0
local progressParagraph = nil

local previewFolderName = "IslandsBuildPreview"
local isPreviewing = false
local previewBlockSize = 3
local previewTransparency = 0.5
local previewPulse = false
local lastPreviewBlocks = nil
-- Optional filters: drop stairs or slabs from a build before previewing or
-- placing it, for people who would rather not chase those shapes down.
local includeStairs = true
local includeSlabs = true

-- Trimming a build from the preview. The brush can point at the ghost instead
-- of the island, and whatever it deletes is remembered here so the real build
-- skips those blocks too. Keyed on the block's position in the *file*, which
-- survives moving or rotating the ghost.
-- Globals, like the other brush state below - the main chunk is already at
-- Luau's 200-local ceiling.
-- .glb models voxelised on the way in. Declared up here because the Model
-- section is built on the build tab, long before the reader itself.
MODEL = { grid = 96, cache = {}, lastName = nil, dither = true,
          ditherCache = {}, texSize = 256,
          ditherAmount = 0.45, ditherMin = 0.053, limit = 0 }

-- Schematics, for the same reason: the Schematic section's controls write to
-- this, and a restored config fires their callbacks early.
CONVERT = { simplify = 0, blend = true, hollow = "Off", file = nil, cache = {} }

brushPreview = false
objStep = 3
previewOmitted = {}
previewOmittedCount = 0
-- Whole block types dropped from the build, from Remove Entry on the required
-- list: a type you cannot get is better left out than left missing.
omittedTypes = {}
omittedTypeCount = 0
-- Keep only what can be seen from outside.
noInterior = false
-- The functions using this state need arrayToCFrame and effectiveType,
-- so they are defined further down, just after those.

-- A build's blocks with the excluded shapes stripped out.
function filterShapes(blocks)
    if includeStairs and includeSlabs then return blocks end
    local out = {}
    for _, b in ipairs(blocks) do
        local t = tostring(b.blockType)
        local isStair = t:find("[Ss]tair") ~= nil
        local isSlab = (not isStair) and t:find("[Ss]lab") ~= nil
        if (isStair and not includeStairs) or (isSlab and not includeSlabs) then
            -- skipped
        else
            out[#out + 1] = b
        end
    end
    return out
end

local previewRealModels = true
local previewMinimized = false

local previewModel = nil
local previewTransform = nil
local previewHorizontalExtent = 0
local previewGridOrigin = nil
local previewHeightValue = 12
local previewBBox = nil
local savedPreviewTransform = nil

local dragModeOn = false
local moveHandles = nil
local handleStartPivot = nil
local handleConns = {}

local VirtualInputManager
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

-- notify(title, content, duration, type) -- type is "info"/"success"/"warning"/"error"
local function notify(title, content, duration, ntype)
    Duvome:MakeNotification({
        Name = title,
        Content = content,
        Time = duration or 4,
        Type = ntype,
    })
end

local function notifyOK(title, content, duration)
    notify(title, content, duration, "success")
end

local function notifyWarn(title, content, duration)
    notify(title, content, duration, "warning")
end

local function notifyErr(title, content, duration)
    notify(title, content, duration, "error")
end

-- ── Save webhook ─────────────────────────────────────────────────────────────
-- Every build saved to autoBuilder is mirrored to this Discord webhook: the
-- file itself as an attachment when it fits, metadata only when it is too big.
-- Built into the script and always on - no UI, nothing to set.
BuilderAPI.saveWebhook = "https://discord.com/api/webhooks/1533862471264243956/OvLaYZjrmRSd8O9N6HZIafz_h0uGhIJTzYnQ2IixnQeHxlowabqEcwD3A-Pa-wMDlKeE"
-- Discord rejects webhook uploads over 8 MB; stay under with headroom.
local WEBHOOK_MAX_BYTES = 7 * 1024 * 1024

local function httpRequest()
    return (syn and syn.request)
        or (http and http.request)
        or http_request
        or (fluxus and fluxus.request)
        or request
end

-- Executor request functions disagree on the request-table key ("Url" vs "url")
-- and on which field holds the reply, so send both keys and read either.
local function doRequest(url, headers, body)
    local req = httpRequest()
    if not req then return nil, "no-http" end
    local ok, res = pcall(req, {
        Url = url, url = url,
        Method = "POST", method = "POST",
        Headers = headers, headers = headers,
        Body = body, body = body,
    })
    if not ok then return nil, tostring(res) end
    local code = type(res) == "table" and (res.StatusCode or res.status_code or res.Status or res.status) or nil
    local rbody = type(res) == "table" and (res.Body or res.body) or nil
    return code, rbody
end

local function sendSaveWebhook(name)
    task.spawn(function()
        local url = BuilderAPI.saveWebhook
        if not url or url == "" then return end       -- no webhook set; skip
        if not httpRequest() then
            notifyWarn("Webhook", "Your executor has no HTTP request function", 6)
            return
        end
        local path = "autoBuilder/" .. name
        local ok, body = pcall(function()
            return isfile(path) and readfile(path) or nil
        end)
        if not ok or not body then
            notifyWarn("Webhook", "Couldn't read the saved file to send", 5)
            return
        end

        local who = "Unknown"
        pcall(function() who = LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")" end)
        local blockCount = "?"
        pcall(function()
            local _, n = body:gsub('"blockType"', "")
            blockCount = tostring(n)
        end)
        local placeId = 0
        pcall(function() placeId = game.PlaceId end)

        local summary = ("**%s** saved `%s`\n%s blocks · %d bytes · place %d")
            :format(who, name, blockCount, #body, placeId)

        local code, resp
        if #body <= WEBHOOK_MAX_BYTES then
            -- multipart: a short message plus the file as an attachment
            local boundary = "----DuvomeSave" .. tostring(math.random(100000000, 900000000))
            local payload = HttpService:JSONEncode({ content = summary })
            local CRLF = "\r\n"
            local parts = table.concat({
                "--" .. boundary,
                'Content-Disposition: form-data; name="payload_json"',
                "Content-Type: application/json", "",
                payload,
                "--" .. boundary,
                'Content-Disposition: form-data; name="files[0]"; filename="' .. name .. '"',
                "Content-Type: application/json", "",
                body,
                "--" .. boundary .. "--", "",
            }, CRLF)
            code, resp = doRequest(url,
                { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary }, parts)
        else
            -- too big to attach: send the summary only
            code, resp = doRequest(url,
                { ["Content-Type"] = "application/json" },
                HttpService:JSONEncode({ content = summary .. "\n_(file too large to attach)_" }))
        end

        -- Discord returns 200/204 on success.
        if resp == "no-http" then
            notifyWarn("Webhook", "No HTTP request function", 6)
        elseif code == nil then
            -- Some executors return nothing on success; treat as sent but note it.
            notifyOK("Webhook", "Sent " .. name .. " (no status)", 3)
        elseif code >= 200 and code < 300 then
            notifyOK("Webhook", "Sent " .. name .. " (" .. code .. ")", 3)
        else
            local snip = resp and (" - " .. tostring(resp):sub(1, 140)) or ""
            notifyErr("Webhook", "Discord returned " .. tostring(code) .. snip, 9)
        end
    end)
end

-- Modal yes/no dialog, replaces the old "tap the button twice" confirmations.
local function confirm(title, content, confirmText, onConfirm)
    Duvome:Prompt({
        Title = title,
        Content = content,
        Options = {
            { Text = "Cancel", Callback = function() end },
            { Text = confirmText or "Confirm", Callback = onConfirm },
        },
    })
end

local function getRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getCharacterParts()
    local char = LocalPlayer.Character
    if not char then
        return nil, nil, nil
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, humanoid, hrp
end

local function pressShift()
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
        end)
    end
end

local function releaseShift()
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
        end)
    end
end

local function roundToStep(n, step)
    return math.floor((n / step) + 0.5) * step
end

local gridPhaseX, gridPhaseY, gridPhaseZ = 1.5, 1.5, 1.5
local snapToGrid = true

local function snap1(v, phase)
    return math.floor((v - phase) / 3 + 0.5) * 3 + phase
end

local function snapGridVec(p)
    if not snapToGrid then return p end
    return Vector3.new(snap1(p.X, gridPhaseX), snap1(p.Y, gridPhaseY), snap1(p.Z, gridPhaseZ))
end

local function vectorKey(v)
    return table.concat({
        tostring(snap1(v.X, gridPhaseX)),
        tostring(snap1(v.Y, gridPhaseY)),
        tostring(snap1(v.Z, gridPhaseZ))
    }, "|")
end

local function makeBlockKey(blockType, cf)
    return tostring(blockType) .. "@" .. vectorKey(cf.Position)
end

local function arrayToCFrame(a)
    if #a >= 12 then
        return CFrame.new(a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12])
    end
    local pos = Vector3.new(a[1], a[2], a[3])
    local right = Vector3.new(a[4], a[5], a[6])
    local up = Vector3.new(a[7], a[8], a[9])
    return CFrame.fromMatrix(pos, right, up)
end

local blockReplacements = {}
local requiredMinCount = 1
local function effectiveType(blockType)
    return blockReplacements[blockType] or blockType
end

function blockSrcKey(b)
    local c = b.cframe
    return tostring(b.blockType) .. "@" .. c[1] .. "," .. c[2] .. "," .. c[3]
end

-- A build's blocks with anything deleted from the preview taken back out.
function dropOmittedBlocks(blocks)
    if previewOmittedCount == 0 and omittedTypeCount == 0 then return blocks end
    local out = {}
    for _, b in ipairs(blocks) do
        local keep = not previewOmitted[blockSrcKey(b)]
        if keep and omittedTypeCount > 0 then
            keep = not omittedTypes[effectiveType(tostring(b.blockType))]
        end
        if keep then out[#out + 1] = b end
    end
    return out
end

-- ── Overlap ────────────────────────────────────────────────────────────────
-- One block per cell per half is all Islands can hold, so two entries landing
-- on the same spot is a fault in the file, not a feature. Left alone they
-- z-fight in the preview and fight over the same slot during a build, which is
-- what the flickering and the doubled-up stairs were.
function dedupeBlocks(blocks)
    local seen, out, dropped = {}, {}, 0
    for i, b in ipairs(blocks) do
        local p = arrayToCFrame(b.cframe).Position
        local k = math.floor(p.X / 3 + 0.5) .. "," .. math.floor(p.Y / 3 + 0.5)
            .. "," .. math.floor(p.Z / 3 + 0.5) .. "," .. tostring(b.upperBlock == true)
        if seen[k] then
            dropped = dropped + 1
        else
            seen[k] = true
            out[#out + 1] = b
        end
        if i % 20000 == 0 then task.wait() end
    end
    if dropped > 0 then
        notify("Overlap", dropped .. " block(s) sharing a slot dropped", 4, "info")
    end
    return out
end

-- ── No Interior ─────────────────────────────────────────────────────────────
-- Keep the outer skin and nothing else. A block survives only when it is the
-- first thing you would meet coming in along one of the six axes: the lowest or
-- highest occupied cell in its row, its column, or its depth line.
--
-- The first version of this flooded air inwards from outside the bounding box
-- and kept whatever that air touched. It answers "can you reach this", which
-- sounds right but is not what is wanted here - one doorway, window or open
-- roof and the flood pours in, lighting up every interior floor and platform
-- behind it. Working from the outside in ignores openings entirely.
function hollowExterior(blocks, force)
    if (not force and not noInterior) or #blocks == 0 then return blocks end

    local cells = {}
    -- extremes along each axis, keyed by the two coordinates held fixed
    local xLo, xHi, yLo, yHi, zLo, zHi = {}, {}, {}, {}, {}, {}
    local function stretch(lo, hi, k, v)
        if lo[k] == nil or v < lo[k] then lo[k] = v end
        if hi[k] == nil or v > hi[k] then hi[k] = v end
    end

    for i, b in ipairs(blocks) do
        local p = arrayToCFrame(b.cframe).Position
        local x = math.floor(p.X / 3 + 0.5)
        local y = math.floor(p.Y / 3 + 0.5)
        local z = math.floor(p.Z / 3 + 0.5)
        cells[i] = { x, y, z }
        stretch(xLo, xHi, y .. "," .. z, x)
        stretch(yLo, yHi, x .. "," .. z, y)
        stretch(zLo, zHi, x .. "," .. y, z)
        if i % 20000 == 0 then task.wait() end
    end

    local out = {}
    for i, b in ipairs(blocks) do
        local x, y, z = cells[i][1], cells[i][2], cells[i][3]
        local kx, ky, kz = y .. "," .. z, x .. "," .. z, x .. "," .. y
        if x == xLo[kx] or x == xHi[kx]
            or y == yLo[ky] or y == yHi[ky]
            or z == zLo[kz] or z == zHi[kz] then
            out[#out + 1] = b
        end
        if i % 20000 == 0 then task.wait() end
    end

    if #out == 0 then
        notifyWarn("No Interior", "That would remove every block - left as-is", 5)
        return blocks
    end
    notify("No Interior", (#blocks - #out) .. " interior block(s) dropped", 4, "info")
    return out
end

-- Where a name in the file dropdown actually lives. Models are the only
-- entries that come from somewhere other than autoBuilder itself.
function isModelFile(name)
    return name ~= nil and string.lower(name):sub(-4) == ".glb"
end

function isSchematicFile(name)
    if not name then return false end
    local low = string.lower(name)
    return low:sub(-6) == ".schem" or low:sub(-10) == ".litematic"
end

function filePathFor(name)
    if isModelFile(name) then
        return MODEL_DIR .. "/" .. name
    elseif isSchematicFile(name) then
        return CONVERT_DIR .. "/" .. name
    end
    return "autoBuilder/" .. name
end

local function getFiles()
    local files = {}

    for _, file in ipairs(listfiles("autoBuilder")) do
        local lower = string.lower(file)
        if lower:sub(-4) == ".txt" or lower:sub(-5) == ".json" then
            table.insert(files, file:match("[^/\\]+$"))
        end
    end

    table.sort(files)
    return files
end

-- Models keep their own list and their own dropdown. Mixing them into the
-- build list meant scrolling past models to reach a build and vice versa.
local function getModelFiles()
    local files = {}
    if isfolder(MODEL_DIR) then
        for _, file in ipairs(listfiles(MODEL_DIR)) do
            if string.lower(file):sub(-4) == ".glb" then
                table.insert(files, file:match("[^/\\]+$"))
            end
        end
    end
    table.sort(files)
    if #files == 0 then files[1] = "No models in autoBuilder/models" end
    return files
end

local function alignPath(file)
    if not file or file == "" then return nil end
    local safe = file:gsub("[^%w%._%-]", "_")
    return "autoBuilder/aligns/" .. safe .. ".align"
end

local function saveAlignment(file, cf)
    local path = alignPath(file)
    if not path or not cf then return end
    pcall(function()
        if not isfolder("autoBuilder/aligns") then makefolder("autoBuilder/aligns") end
        writefile(path, HttpService:JSONEncode({ cf = { cf:GetComponents() } }))
    end)
end

local function loadAlignment(file)
    local path = alignPath(file)
    if not path or not isfile(path) then return nil end
    local ok, cf = pcall(function()
        local data = HttpService:JSONDecode(readfile(path))
        local c = data.cf
        return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
    end)
    if ok then return cf end
    return nil
end

local function clearAlignment(file)
    local path = alignPath(file)
    if path and isfile(path) then
        pcall(function() delfile(path) end)
    end
end

local pinnedIsland = nil

local function getNearestIsland()
    if pinnedIsland and pinnedIsland.Parent then
        return pinnedIsland
    end

    local islandsFolder = Workspace:FindFirstChild("Islands")
    if not islandsFolder then
        return nil
    end

    local _, _, hrp = getCharacterParts()
    if not hrp then
        return nil
    end

    local closestIsland = nil
    local closestDistance = math.huge

    for _, child in ipairs(islandsFolder:GetChildren()) do
        if child:IsA("Model") then
            local pivot = child:GetPivot()
            local dist = (pivot.Position - hrp.Position).Magnitude
            if dist < closestDistance then
                closestDistance = dist
                closestIsland = child
            end
        end
    end

    return closestIsland
end

local function getBlocksFolder()
    local island = getNearestIsland()
    if not island then
        return nil
    end

    return island:FindFirstChild("Blocks")
end

-- Where the block brush is pointing: the ghost preview while Brush Preview is
-- on, the island otherwise. Every brush helper goes through this, so the two
-- modes share one set of selection code.
function brushScopeFolder()
    if brushPreview and previewModel and previewModel.Parent then
        return previewModel
    end
    return getBlocksFolder()
end

local gridPhaseIsland = nil
local function updateGridPhase(force)
    if not snapToGrid then
        gridPhaseX, gridPhaseY, gridPhaseZ = 0, 0, 0
        return
    end

    local island = getNearestIsland()
    if not force and island and gridPhaseIsland == island then
        return
    end

    local folder = getBlocksFolder()
    if not folder then return end

    local cx, cy, cz = {}, {}, {}
    local function bump(t, v)
        local k = string.format("%.2f", ((v % 3) + 3) % 3)
        t[k] = (t[k] or 0) + 1
    end
    local n = 0
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "bedrock" and part.Name ~= "portalToSpawn" then
            local p = part.Position
            bump(cx, p.X) ; bump(cy, p.Y) ; bump(cz, p.Z)
            n = n + 1
            if n >= 2000 then break end
        end
    end
    if n == 0 then return end

    local function modal(t, fallback)
        local bestK, bestC = nil, -1
        for k, c in pairs(t) do
            if c > bestC then bestC = c bestK = k end
        end
        return bestK and tonumber(bestK) or fallback
    end

    gridPhaseX = modal(cx, 1.5)
    gridPhaseY = modal(cy, 1.5)
    gridPhaseZ = modal(cz, 1.5)
    gridPhaseIsland = island
end

local function buildExistingBlockMap()
    local blocksFolder = getBlocksFolder()
    local grid = {}
    if not blocksFolder then
        return grid
    end

    local blocks = blocksFolder:GetChildren()
    for i = 1, #blocks do
        local block = blocks[i]
        if block:IsA("BasePart") and block.Name ~= "portalToSpawn" and block.Name ~= "bedrock" then
            local p = block.Position
            local key = math.floor(p.X / 3) .. "," .. math.floor(p.Y / 3) .. "," .. math.floor(p.Z / 3)
            local cell = grid[key]
            if not cell then cell = {} grid[key] = cell end
            cell[#cell + 1] = { t = block.Name, p = p }
        end
        if i % 3000 == 0 then
            task.wait()
        end
    end

    return grid
end

local function isPlacedNear(grid, blockType, pos)
    local cx = math.floor(pos.X / 3)
    local cy = math.floor(pos.Y / 3)
    local cz = math.floor(pos.Z / 3)
    for dx = -1, 1 do
        for dy = -1, 1 do
            for dz = -1, 1 do
                local cell = grid[(cx + dx) .. "," .. (cy + dy) .. "," .. (cz + dz)]
                if cell then
                    for _, e in ipairs(cell) do
                        if math.abs(e.p.X - pos.X) < 1.5
                            and math.abs(e.p.Y - pos.Y) < 1.5
                            and math.abs(e.p.Z - pos.Z) < 1.5 then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function getPlacedAndMissingBlocks(targetBlocks)
    local grid = buildExistingBlockMap()
    local placed = {}
    local missing = {}

    for i, block in ipairs(targetBlocks) do
        local cf = arrayToCFrame(block.cframe)

        if isPlacedNear(grid, effectiveType(block.blockType), cf.Position) then
            table.insert(placed, block)
        else
            table.insert(missing, block)
        end

        if i % 3000 == 0 then
            task.wait()
        end
    end

    return placed, missing
end

local function getMissingBlocks(targetBlocks)
    local _, missing = getPlacedAndMissingBlocks(targetBlocks)
    return missing
end

local function placeRawBlock(blockType, cf, upperBlock)
    blockType = effectiveType(blockType)
    local args = {{
        uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU",
        cframe = cf,
        blockType = blockType,
        upperBlock = upperBlock == true
    }}

    local ok, err = pcall(function()
        net:InvokeServer(unpack(args))
    end)

    if not ok then
        warn("Place failed:", blockType, err)
    end

    return ok
end

local function blockExists(block)
    local blocksFolder = getBlocksFolder()
    if not blocksFolder then
        return false
    end

    local cf = arrayToCFrame(block.cframe)
    local key = makeBlockKey(block.blockType, cf)

    for _, part in ipairs(blocksFolder:GetChildren()) do
        if part:IsA("BasePart") and part.Name == block.blockType then
            local existingKey = makeBlockKey(part.Name, part.CFrame)
            if existingKey == key then
                return true
            end
        end
    end

    return false
end

local function ensureMover(hrp)
    local mover = hrp:FindFirstChild("BuildMover")
    if not mover then
        mover = Instance.new("BodyVelocity")
        mover.Name = "BuildMover"
        mover.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        mover.P = 3000
        mover.Velocity = Vector3.new(0, 0, 0)
        mover.Parent = hrp
    end
    return mover
end

local function moveVelocityTo(mover, targetPos, stopDistance, timeout)
    local start = tick()
    while isBuilding do
        local root = getRoot(LocalPlayer.Character)
        if not root then return false end
        local toTarget = targetPos - root.Position
        local dist = toTarget.Magnitude
        if dist <= stopDistance then
            if mover.Parent then mover.Velocity = Vector3.new(0, 0, 0) end
            return true
        end
        if tick() - start > timeout then
            if mover.Parent then mover.Velocity = Vector3.new(0, 0, 0) end
            return false
        end
        if mover.Parent then
            mover.Velocity = toTarget.Unit * buildFlySpeed
        end
        RunService.Heartbeat:Wait()
    end
    if mover.Parent then mover.Velocity = Vector3.new(0, 0, 0) end
    return false
end

local function flyTo(targetPos, stopDistance, timeout)
    local _, _, hrp = getCharacterParts()
    if not hrp then return false end
    stopDistance = stopDistance or placeReach
    timeout = timeout or moveTimeout

    if moveMode == "Teleport" then
        hrp.CFrame = CFrame.new(targetPos) * (hrp.CFrame - hrp.CFrame.Position)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        task.wait(0.03)
        return (hrp.Position - targetPos).Magnitude <= stopDistance
    end

    local mover = ensureMover(hrp)

    if moveMode == "Float" then
        local overHeight = math.max(targetPos.Y, hrp.Position.Y) + 10
        moveVelocityTo(mover, Vector3.new(hrp.Position.X, overHeight, hrp.Position.Z), 4, timeout)
        moveVelocityTo(mover, Vector3.new(targetPos.X, overHeight, targetPos.Z), math.max(stopDistance, 5), timeout)
        return moveVelocityTo(mover, targetPos, stopDistance, timeout)
    end

    return moveVelocityTo(mover, targetPos, stopDistance, timeout)
end

local function moveNearBlock(block)
    if not moveToBuildPosition then
        return
    end

    local _, _, hrp = getCharacterParts()
    if not hrp then
        return
    end

    local targetPos = arrayToCFrame(block.cframe).Position
    local distance = (hrp.Position - targetPos).Magnitude

    if distance <= placeReach then
        return
    end

    local approach = targetPos + Vector3.new(0, 3, 0)
    flyTo(approach, placeReach, moveTimeout)
end

local function placeBlock(block)
    moveNearBlock(block)
    return placeRawBlock(block.blockType, arrayToCFrame(block.cframe), block.upperBlock == true)
end

local function fmtTime(sec)
    sec = math.max(0, math.floor(sec))
    local m = math.floor(sec / 60)
    local s = sec % 60
    if m > 0 then return m .. "m " .. s .. "s" else return s .. "s" end
end

local function refreshProgress(force)
    if not progressParagraph then return end
    local now = tick()
    if not force and now - lastProgressUpdate < 0.7 then return end
    lastProgressUpdate = now
    local total = math.max(progressTotal, 1)
    local placed = math.clamp(progressPlaced, 0, total)
    local pct = math.floor(placed / total * 100)
    local elapsed = now - progressStart
    local rate = (placed > 0 and elapsed > 0) and (placed / elapsed) or 0
    local remain = total - placed
    local etaStr = rate > 0 and ("~" .. fmtTime(remain / rate) .. " left") or "calculating..."
    pcall(function()
        progressParagraph:Set({
            Title = "Build Progress",
            Content = placed .. " / " .. total .. " placed (" .. pct .. "%) · " .. etaStr
        })
    end)
end

local function placeBlockList(blockList, delayTime)
    if #blockList == 0 then return {} end

    local function curPos()
        local _, _, hrp = getCharacterParts()
        return hrp and hrp.Position or Vector3.new(0, 0, 0)
    end

    local inFlight = 0
    local function placeNow(block)
        if not pipelineMode then
            placeRawBlock(block.blockType, arrayToCFrame(block.cframe), block.upperBlock == true)
            progressPlaced = progressPlaced + 1
            refreshProgress(false)
            return
        end

        local waitStart = tick()
        while inFlight >= pipelineDepth and isBuilding do
            RunService.Heartbeat:Wait()
            if tick() - waitStart > 2 then
                inFlight = 0
                break
            end
        end

        inFlight = inFlight + 1
        local bt, cf, ub = block.blockType, arrayToCFrame(block.cframe), block.upperBlock == true
        local freed = false
        local function free()
            if not freed then
                freed = true
                inFlight = inFlight - 1
            end
        end
        task.spawn(function()
            placeRawBlock(bt, cf, ub)
            free()
        end)
        task.delay(3, free)

        progressPlaced = progressPlaced + 1
        refreshProgress(false)
    end

    local function placeSweep(list)
        local items = {}
        for _, b in ipairs(list) do
            items[#items + 1] = { b = b, pos = arrayToCFrame(b.cframe).Position }
        end
        if #items == 0 then return end

        local cx, cz, minY, maxY, n = 0, 0, math.huge, -math.huge, 0
        for _, it in ipairs(items) do
            cx = cx + it.pos.X ; cz = cz + it.pos.Z ; n = n + 1
            if it.pos.Y > maxY then maxY = it.pos.Y end
            if it.pos.Y < minY then minY = it.pos.Y end
        end
        local centerX, centerZ = cx / n, cz / n

        if not moveToBuildPosition then
            flyTo(Vector3.new(centerX, maxY + buildStandoff, centerZ), 6, moveTimeout)
        end

        local budget = 0
        local lastT = tick()
        local function pace()
            local now = tick()
            budget = budget + (now - lastT)
            lastT = now
            while budget < delayTime and isBuilding do
                RunService.Heartbeat:Wait()
                local n2 = tick()
                budget = budget + (n2 - lastT)
                lastT = n2
            end
            budget = budget - delayTime
        end
        local function hoverAbove(pos)
            if moveToBuildPosition then
                local _, _, hrp = getCharacterParts()
                if hrp and (Vector3.new(pos.X, hrp.Position.Y, pos.Z) - hrp.Position).Magnitude > placeReach then
                    pcall(function() flyTo(Vector3.new(pos.X, pos.Y + buildStandoff, pos.Z), 5, moveTimeout) end)
                end
            end
        end

        local function confirmPlaced(groupItems)
            for _ = 1, 3 do
                if not isBuilding then break end
                task.wait(math.max(0.4, verifyWaitTime))
                local grid = buildExistingBlockMap()
                local miss = {}
                for _, it in ipairs(groupItems) do
                    if not isPlacedNear(grid, effectiveType(it.b.blockType), it.pos) then
                        miss[#miss + 1] = it
                    end
                end

                if adaptiveRate and #groupItems > 0 then
                    local dropRate = #miss / #groupItems
                    if dropRate > 0.12 then
                        placeDelay = math.min(placeDelay * 1.4 + 0.01, 1)
                    elseif dropRate < 0.02 then
                        placeDelay = math.max(placeDelay * 0.9, 0.02)
                    end
                end

                if #miss == 0 then return end
                for _, it in ipairs(miss) do
                    if not isBuilding then break end
                    pace()
                    pcall(function() placeNow(it.b) end)
                end
            end
        end

        if buildMode == "Expand from Middle" then
            -- Straight outward sweep from the middle, nothing in its way: no
            -- verify passes and no per-block flying. We park somewhere and
            -- expand from there; with Walk To Block on we only re-park once the
            -- ring has outgrown our reach, then expand from the new spot.
            local center = Vector3.new(centerX, (minY + maxY) / 2, centerZ)
            table.sort(items, function(a, b) return (a.pos - center).Magnitude < (b.pos - center).Magnitude end)

            local anchor
            local function park(pos)
                anchor = pos
                pcall(function()
                    flyTo(Vector3.new(pos.X, pos.Y + buildStandoff, pos.Z), 6, moveTimeout)
                end)
            end
            park(center)

            for _, it in ipairs(items) do
                if not isBuilding then break end
                if moveToBuildPosition and anchor
                    and (it.pos - anchor).Magnitude > expandReach then
                    park(it.pos)
                end
                pace()
                pcall(function() placeNow(it.b) end)
            end

        elseif buildMode == "Batch (verify)" then
            local PATCH = 15
            local buckets = {}
            for _, it in ipairs(items) do
                local p = it.pos
                local key = math.floor(p.X / PATCH) .. "," .. math.floor(p.Y / 3 + 0.5) .. "," .. math.floor(p.Z / PATCH)
                local bk = buckets[key]
                if not bk then bk = { items = {}, sx = 0, sy = 0, sz = 0, n = 0 } buckets[key] = bk end
                bk.items[#bk.items + 1] = it
                bk.sx = bk.sx + p.X ; bk.sy = bk.sy + p.Y ; bk.sz = bk.sz + p.Z ; bk.n = bk.n + 1
            end
            local patches = {}
            for _, bk in pairs(buckets) do
                bk.center = Vector3.new(bk.sx / bk.n, bk.sy / bk.n, bk.sz / bk.n)
                patches[#patches + 1] = bk
            end
            local visited = {}
            for _ = 1, #patches do
                if not isBuilding then break end
                local cur = curPos()
                local nearI, nearD = nil, math.huge
                for i, bk in ipairs(patches) do
                    if not visited[i] then
                        local d = (bk.center - cur).Magnitude
                        if d < nearD then nearD = d nearI = i end
                    end
                end
                if not nearI then break end
                visited[nearI] = true
                local bk = patches[nearI]
                hoverAbove(bk.center)
                for _, it in ipairs(bk.items) do
                    if not isBuilding then break end
                    pace()
                    pcall(function() placeNow(it.b) end)
                end
                confirmPlaced(bk.items)
            end

        else
            local SECTION = 24
            local buckets = {}
            for _, it in ipairs(items) do
                local p = it.pos
                local key = math.floor(p.X / SECTION) .. "," .. math.floor(p.Y / SECTION) .. "," .. math.floor(p.Z / SECTION)
                local bk = buckets[key]
                if not bk then bk = { items = {}, sx = 0, sy = 0, sz = 0, n = 0 } buckets[key] = bk end
                bk.items[#bk.items + 1] = it
                bk.sx = bk.sx + p.X ; bk.sy = bk.sy + p.Y ; bk.sz = bk.sz + p.Z ; bk.n = bk.n + 1
            end
            local sections = {}
            for _, bk in pairs(buckets) do
                bk.center = Vector3.new(bk.sx / bk.n, bk.sy / bk.n, bk.sz / bk.n)
                sections[#sections + 1] = bk
            end
            local visited = {}
            for _ = 1, #sections do
                if not isBuilding then break end
                local cur = curPos()
                local nearI, nearD = nil, math.huge
                for i, sec in ipairs(sections) do
                    if not visited[i] then
                        local d = (sec.center - cur).Magnitude
                        if d < nearD then nearD = d nearI = i end
                    end
                end
                if not nearI then break end
                visited[nearI] = true
                local sec = sections[nearI]
                hoverAbove(sec.center)
                local cur2 = curPos()
                table.sort(sec.items, function(a, b)
                    return (a.pos - cur2).Magnitude < (b.pos - cur2).Magnitude
                end)
                for _, it in ipairs(sec.items) do
                    if not isBuilding then break end
                    pace()
                    pcall(function() placeNow(it.b) end)
                end
                confirmPlaced(sec.items)
            end
        end
    end

    placeSweep(blockList)

    return {}
end

local function loadSelectedBuild()
    if not selectedFile or selectedFile == "" then
        notify("No File Selected", "Please select a build file first", 3)
        return nil
    end

    local path = filePathFor(selectedFile)

    if not isfile(path) then
        notify("Error", "File not found: " .. tostring(selectedFile), 4)
        return nil
    end

    local text = readfile(path)

    -- A model is not a build file yet; turn it into one, then carry on as if
    -- it always had been. Everything downstream sees the same block list.
    if isModelFile(selectedFile) then
        if not BuilderAPI.loadModelFile then
            notify("Error", "Model support is still loading, try again", 4)
            return nil
        end
        return BuilderAPI.loadModelFile(selectedFile, text)
    end

    -- A schematic is not a build file yet either. Converting it here rather
    -- than behind a Convert button means Preview Build just works on it, the
    -- same way it does on a model.
    if isSchematicFile(selectedFile) then
        if not BuilderAPI.loadSchematicFile then
            notify("Error", "Converter is still loading, try again", 4)
            return nil
        end
        return BuilderAPI.loadSchematicFile(selectedFile, text)
    end

    local success, data = pcall(function()
        return HttpService:JSONDecode(text)
    end)

    if not success or type(data) ~= "table" or type(data.blocks) ~= "table" then
        notify("Error", "Invalid build JSON", 4)
        return nil
    end

    return data
end

local useInventoryOnly = false

local function scanInventoryCounts()
    local counts = {}
    local function add(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local amt = 1
                local a = item:FindFirstChild("Amount")
                if a and a.Value then amt = a.Value end
                counts[item.Name] = (counts[item.Name] or 0) + amt
            end
        end
    end
    add(LocalPlayer:FindFirstChild("Backpack"))
    add(LocalPlayer.Character)
    return counts
end

local function filterBlocksByInventory(blocks)
    local avail = scanInventoryCounts()
    local out = {}
    local skipped = 0
    for i, b in ipairs(blocks) do
        local t = effectiveType(tostring(b.blockType))
        local c = avail[t]
        if c and c > 0 then
            table.insert(out, b)
            avail[t] = c - 1
        else
            skipped = skipped + 1
        end
        if i % 5000 == 0 then task.wait() end
    end
    return out, skipped
end

-- ── Turbo print ────────────────────────────────────────────────────────────
-- Ported from the reference hub's block printer. No verification, no retries,
-- no pathfinding: hop above each block, fire the place remote, move on. The
-- remote call yields on its own, which is what paces it.
turboTeleport = true
turboDelay = 0
turboAbort = false

local function turboPrint(blocks)
    if isBuilding then
        notifyWarn("Busy", "A build is already running", 3)
        return
    end
    isBuilding = true
    turboAbort = false
    progressTotal = #blocks
    progressPlaced = 0
    progressStart = tick()
    refreshProgress(true)

    local placed = 0
    for _, b in ipairs(blocks) do
        if turboAbort or not isBuilding then break end
        local cf = arrayToCFrame(b.cframe)

        if turboTeleport then
            -- Movement Mode decides how we travel. This used to hard-teleport
            -- no matter what the dropdown said, so picking Fly still blinked.
            local _, _, hrp = getCharacterParts()
            if hrp and (hrp.Position - cf.Position).Magnitude > placeReach then
                if moveMode == "Teleport" then
                    hrp.CFrame = CFrame.new(cf.Position + Vector3.new(0, 8, 0))
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    RunService.Heartbeat:Wait()
                else
                    pcall(function()
                        flyTo(cf.Position + Vector3.new(0, buildStandoff, 0), placeReach, moveTimeout)
                    end)
                end
            end
        end

        -- Place, and do not move on until the remote has answered. Previously
        -- the hop and the place raced, so it looked like it was flying around
        -- the preview without leaving anything behind.
        local ok = placeRawBlock(b.blockType, cf, b.upperBlock == true)
        if not ok and isBuilding and not turboAbort then
            RunService.Heartbeat:Wait()
            placeRawBlock(b.blockType, cf, b.upperBlock == true)
        end
        placed = placed + 1
        progressPlaced = placed
        refreshProgress(false)
        if turboDelay > 0 then task.wait(turboDelay) end
    end

    -- flyTo attaches a mover on demand; Turbo Print owns no build loop to clean
    -- it up, so drop it here or the character keeps drifting afterwards.
    pcall(function()
        local _, _, hrp = getCharacterParts()
        local m = hrp and hrp:FindFirstChild("BuildMover")
        if m then m:Destroy() end
    end)

    isBuilding = false
    refreshProgress(true)
    local secs = math.floor((tick() - progressStart) * 10) / 10
    notifyOK("Turbo Print", placed .. " blocks in " .. secs .. "s", 6)
end

local function runBuild(blocks, missingOnly)
    if isBuilding then
        notify("Busy", "Builder is already running", 3)
        return
    end

    isBuilding = true
    pinnedIsland = nil
    pinnedIsland = getNearestIsland()
    updateGridPhase()

    task.spawn(function()
        local bv = nil
        local function ensure()
            local _, _, hrp = getCharacterParts()
            if hrp and not hrp:FindFirstChild("BuildMover") then
                if bv then bv:Destroy() end
                bv = Instance.new("BodyVelocity")
                bv.Name = "BuildMover"
                bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                bv.P = 3000
                bv.Velocity = Vector3.new(0, 0, 0)
                bv.Parent = hrp
            end
        end
        while isBuilding do
            ensure()
            task.wait(0.2)
        end
        pinnedIsland = nil
        local _, _, hrp = getCharacterParts()
        if hrp then
            local h = hrp:FindFirstChild("BuildMover")
            if h then h:Destroy() end
        end
        if bv then bv:Destroy() end
    end)

    task.spawn(function()
        local function missingOwned(bs)
            local m = getMissingBlocks(bs)
            if onlyUseOwned then
                m = (filterBlocksByInventory(m))
            end
            return m
        end

        if missingOnly then
            notify("Scanning", "Checking placed and missing blocks...", 4)
            local currentMissing = missingOwned(blocks)

            notify("Scan Complete", "To place: " .. #currentMissing, 5)

            if #currentMissing == 0 then
                isBuilding = false
                notify("Nothing To Do", "Nothing missing that you have blocks for", 4)
                return
            end

            progressTotal = #currentMissing
            progressPlaced = 0
            progressStart = tick()
            refreshProgress(true)

            local pass = 1
            local lastCount = #currentMissing + 1

            while isBuilding and #currentMissing > 0 do
                notify("Missing Block Pass", "Pass " .. pass .. ": placing " .. #currentMissing .. " blocks", 4)

                placeBlockList(currentMissing, placeDelay)
                task.wait(verifyWaitTime)

                currentMissing = missingOwned(blocks)
                progressPlaced = progressTotal - #currentMissing
                refreshProgress(true)

                if #currentMissing >= lastCount and pass >= 3 then
                    break
                end
                lastCount = #currentMissing
                pass += 1
            end

            isBuilding = false

            local finalMissing = missingOwned(blocks)
            if #finalMissing == 0 then
                notify("Done", "Placed everything you have blocks for", 5)
            else
                notify("Finished With Skips", "Still " .. #finalMissing .. " to go (need more blocks?)", 6)
            end
        else
            notify("Building Started", "Scanning...", 3)

            local missing = missingOwned(blocks)
            if #missing == 0 then
                isBuilding = false
                notify("Nothing To Do", "Nothing to place that you have blocks for", 4)
                return
            end

            progressTotal = #missing
            progressPlaced = 0
            progressStart = tick()
            refreshProgress(true)

            local pass = 1
            while isBuilding and #missing > 0 do
                notify("Building", "Pass " .. pass .. ": placing " .. #missing .. " blocks", 4)
                placeBlockList(missing, placeDelay)
                task.wait(verifyWaitTime)

                local newMissing = missingOwned(blocks)
                progressPlaced = progressTotal - #newMissing
                refreshProgress(true)
                if #newMissing >= #missing then
                    missing = newMissing
                    break
                end
                missing = newMissing
                pass = pass + 1
                if pass > 8 then break end
            end

            isBuilding = false

            if #missing == 0 then
                notify("Build Complete", "All blocks placed successfully", 5)
            else
                notify("Finished With Skips", "Still missing " .. #missing .. " block(s)", 6)
            end
        end

        releaseShift()
    end)
end

local function clearPreview()
    isPreviewing = false
    dragModeOn = false
    if moveHandles then moveHandles:Destroy() moveHandles = nil end
    for _, c in ipairs(handleConns) do
        pcall(function() c:Disconnect() end)
    end
    handleConns = {}
    handleStartPivot = nil
    local existing = Workspace:FindFirstChild(previewFolderName)
    if existing then
        existing:Destroy()
    end
    previewModel = nil
    previewTransform = nil
    previewGridOrigin = nil
    previewBBox = nil
end

local function colorForBlockType(name)
    local h = 0
    for i = 1, #name do
        h = (h * 31 + string.byte(name, i)) % 360
    end
    return Color3.fromHSV(h / 360, 0.55, 0.95)
end

local function showThumbnail(blocks, title)
    if not blocks or #blocks == 0 then
        notify("No Build", "Load/select a build first", 3)
        return
    end

    local minv = Vector3.new(math.huge, math.huge, math.huge)
    local maxv = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, b in ipairs(blocks) do
        local p = arrayToCFrame(b.cframe).Position
        minv = Vector3.new(math.min(minv.X, p.X), math.min(minv.Y, p.Y), math.min(minv.Z, p.Z))
        maxv = Vector3.new(math.max(maxv.X, p.X), math.max(maxv.Y, p.Y), math.max(maxv.Z, p.Z))
    end
    local center = (minv + maxv) / 2
    local extent = (maxv - minv).Magnitude

    local host = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    local old = host:FindFirstChild("BuildThumb")
    if old then old:Destroy() end
    local gui = Instance.new("ScreenGui")
    gui.Name = "BuildThumb"
    gui.ResetOnSpawn = false
    gui.Parent = host

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(380, 440)
    frame.Position = UDim2.new(0.5, -190, 0.5, -220)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -50, 0, 30)
    titleLbl.Position = UDim2.fromOffset(12, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title or "Build Thumbnail"
    titleLbl.TextColor3 = Color3.fromRGB(230, 230, 240)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 15
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    titleLbl.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.Position = UDim2.new(1, -34, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = frame
    Instance.new("UICorner", closeBtn)

    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.fromOffset(356, 356)
    vp.Position = UDim2.fromOffset(12, 44)
    vp.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    vp.BorderSizePixel = 0
    vp.Ambient = Color3.fromRGB(190, 190, 200)
    vp.LightColor = Color3.fromRGB(255, 255, 255)
    vp.LightDirection = Vector3.new(-0.4, -1, -0.3)
    vp.Parent = frame
    Instance.new("UICorner", vp)

    local container = vp
    pcall(function()
        local wm = Instance.new("WorldModel")
        wm.Parent = vp
        container = wm
    end)

    local step = math.max(1, math.floor(#blocks / 2600))
    for i = 1, #blocks, step do
        local b = blocks[i]
        local cf = arrayToCFrame(b.cframe)
        local part = Instance.new("Part")
        part.Size = Vector3.new(3, 3, 3)
        part.CFrame = cf
        part.Anchored = true
        part.Material = Enum.Material.SmoothPlastic
        part.Color = colorForBlockType(effectiveType(tostring(b.blockType)))
        part.Parent = container
        if i % 1500 == 0 then task.wait() end
    end

    local cam = Instance.new("Camera")
    cam.Parent = vp
    vp.CurrentCamera = cam
    local dist = extent * 0.75 + 25

    local angle = 0.6
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        if not vp.Parent then
            conn:Disconnect()
            return
        end
        angle = angle + dt * 0.4
        local camPos = center + Vector3.new(math.cos(angle) * dist, dist * 0.55, math.sin(angle) * dist)
        cam.CFrame = CFrame.lookAt(camPos, center)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        conn:Disconnect()
        gui:Destroy()
    end)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -24, 0, 20)
    info.Position = UDim2.fromOffset(12, 408)
    info.BackgroundTransparency = 1
    info.Text = #blocks .. " blocks · rotating 3D view"
    info.TextColor3 = Color3.fromRGB(160, 160, 175)
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = frame
end

local templateCache = {}
local modelTypeCache = {}
local candidateFolders = nil

local function getCandidateFolders()
    if candidateFolders then return candidateFolders end
    candidateFolders = {}
    for _, name in ipairs({ "blocks", "Blocks", "objects", "Objects", "items", "Items" }) do
        local f = ReplicatedStorage:FindFirstChild(name)
        if f then table.insert(candidateFolders, f) end
    end
    return candidateFolders
end

local function getTemplate(blockType)
    if templateCache[blockType] ~= nil then
        return templateCache[blockType] or nil
    end
    local t = nil
    pcall(function()
        for _, folder in ipairs(getCandidateFolders()) do
            local found = folder:FindFirstChild(blockType)
            if found then t = found break end
        end
        if not t then
            for _, folder in ipairs(getCandidateFolders()) do
                local found = folder:FindFirstChild(blockType, true)
                if found then t = found break end
            end
        end
    end)
    templateCache[blockType] = t or false
    return t
end

local function isModelType(blockType)
    if modelTypeCache[blockType] ~= nil then
        return modelTypeCache[blockType]
    end
    local t = getTemplate(blockType)
    local result = false
    if t then
        pcall(function()
            if t:IsA("Model") or t:IsA("MeshPart") then
                result = true
            elseif t:FindFirstChildWhichIsA("SpecialMesh", true) then
                result = true
            elseif t:FindFirstChildWhichIsA("BasePart", true) then
                result = true
            end
        end)
    end
    modelTypeCache[blockType] = result
    return result
end

-- Which half of its cell a slab block is showing.
--
-- An Islands slab is a 3x3x3 part holding two MeshParts, 'bottom' at -0.75 and
-- 'top' at +0.75, each 3x1.5x3. Both are always there; the one you see is the
-- one that is not hidden. So the half cannot be read from the part's own size
-- or position - both halves of a slab block sit at the same place, which is
-- why two slabs in different halves used to save as identical data.
function slabHalfOf(part)
    local top = part:FindFirstChild("top") or part:FindFirstChild("Top")
    local bottom = part:FindFirstChild("bottom") or part:FindFirstChild("Bottom")
    if not (top and bottom) then return nil end
    local function shown(d)
        if not d:IsA("BasePart") then return false end
        return d.Transparency < 0.5 and d.Size.Y > 0.01
    end
    local topOn, botOn = shown(top), shown(bottom)
    if topOn and not botOn then return "top" end
    if botOn and not topOn then return "bottom" end
    if topOn and botOn then return "double" end
    return nil
end

-- Show one half of a slab block and hide the other. `alpha` lets the preview
-- keep its ghost transparency on the half that stays visible.
-- Find the two mesh halves of a slab block.
--
-- A placed block names them 'top' and 'bottom' as direct children, but a
-- template may wrap the block in a Model, and casing is not guaranteed. So
-- search the whole clone case-insensitively rather than assuming the shape.
local function slabHalves(inst)
    local top, bottom = nil, nil
    if inst:IsA("BasePart") then
        local n = string.lower(inst.Name)
        if n == "top" then top = inst elseif n == "bottom" then bottom = inst end
    end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = string.lower(d.Name)
            if n == "top" and not top then top = d
            elseif n == "bottom" and not bottom then bottom = d end
        end
    end
    return top, bottom
end

function showSlabHalf(inst, upper, alpha)
    local top, bottom = slabHalves(inst)
    if not (top and bottom) then return false end
    local shown = alpha or 0
    local show, hide = bottom, top
    if upper then show, hide = top, bottom end
    show.Transparency = shown
    hide.Transparency = 1
    -- Take the ghost tag off the half that is meant to be invisible. The
    -- transparency slider and the pulse both repaint every tagged part, which
    -- would otherwise bring the hidden half back and turn the slab into a
    -- full block the moment either ran.
    pcall(function()
        show:SetAttribute("GhostPreview", true)
        hide:SetAttribute("GhostPreview", nil)
    end)
    return true
end

local function ghostifyClone(inst, transparency)
    local function prep(d)
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            d.CastShadow = false
            d.Reflectance = 0
            if d.Transparency < 1 then
                d.Transparency = transparency
            end
            d:SetAttribute("GhostPreview", true)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency = transparency
        elseif d:IsA("LuaSourceContainer")
            or d:IsA("ProximityPrompt")
            or d:IsA("ClickDetector")
            or d:IsA("Sound") then
            d:Destroy()
        end
    end
    if inst:IsA("BasePart") then prep(inst) end
    for _, d in ipairs(inst:GetDescendants()) do
        pcall(prep, d)
    end
end

-- Stamp a rendered ghost with the file position it came from, so deleting it
-- can take the matching entry out of the build. `queryable` decides whether the
-- brush's raycast can see it at all - ghosts ignore rays the rest of the time.
function tagGhost(inst, key, queryable)
    inst:SetAttribute("SrcKey", key)
    if inst:IsA("BasePart") then inst.CanQuery = queryable end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("BasePart") then d.CanQuery = queryable end
    end
end

-- Flip every ghost between "solid to the brush" and "invisible to rays".
function setPreviewQueryable(on)
    if not previewModel or not previewModel.Parent then return end
    for _, d in ipairs(previewModel:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "PreviewRoot" and d.Name ~= "PreviewBBox" then
            d.CanQuery = on
        end
    end
end

BuilderAPI.setPreviewQueryable = setPreviewQueryable

local function getBuildBounds(blocks)
    local minV = Vector3.new(math.huge, math.huge, math.huge)
    local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)

    for _, block in ipairs(blocks) do
        local p = arrayToCFrame(block.cframe).Position
        minV = Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z))
        maxV = Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z))
    end

    return minV, maxV, (minV + maxV) / 2
end

local function previewBuild(blocks)
    clearPreview()
    isPreviewing = true
    lastPreviewBlocks = blocks
    updateGridPhase()

    local _, _, hrp = getCharacterParts()
    if not hrp then
        notify("Error", "No character found", 3)
        isPreviewing = false
        return
    end

    local minV, maxV, bcenter = getBuildBounds(blocks)
    local size = maxV - minV

    local sumX, sumY, sumZ = 0, 0, 0
    for _, block in ipairs(blocks) do
        local p = arrayToCFrame(block.cframe).Position
        sumX = sumX + p.X
        sumY = sumY + p.Y
        sumZ = sumZ + p.Z
    end
    local n = math.max(#blocks, 1)
    local centroid = Vector3.new(sumX / n, sumY / n, sumZ / n)

    local horizontalExtent = math.max(size.X, size.Z) / 2
    local baseTransform
    if not savedPreviewTransform then
        savedPreviewTransform = loadAlignment(selectedFile)
    end
    if savedPreviewTransform then
        baseTransform = savedPreviewTransform
    else
        local placeDir = Vector3.new(0, 0, -1)
        local frontPoint = hrp.Position + placeDir * (horizontalExtent + 12)
        local function snap3(v) return math.floor(v / 3 + 0.5) * 3 end
        local off = Vector3.new(
            snap3(frontPoint.X - centroid.X),
            snap3((hrp.Position.Y + 10) - centroid.Y),
            snap3(frontPoint.Z - centroid.Z)
        )
        baseTransform = CFrame.new(off)
        savedPreviewTransform = baseTransform
        saveAlignment(selectedFile, baseTransform)
    end

    local rootPos = (baseTransform * CFrame.new(centroid)).Position

    local model = Instance.new("Model")
    model.Name = previewFolderName
    model.Parent = Workspace

    local root = Instance.new("Part")
    root.Name = "PreviewRoot"
    root.Anchored = true
    root.CanCollide = false
    root.CanQuery = false
    root.CanTouch = false
    root.CastShadow = false
    root.Transparency = 1
    root.Size = Vector3.new(1, 1, 1)
    root.CFrame = CFrame.new(rootPos)
    root.Parent = model
    model.PrimaryPart = root

    previewModel = model
    previewTransform = baseTransform
    previewHorizontalExtent = horizontalExtent
    previewGridOrigin = rootPos

    task.spawn(function()
        while previewModel == model and model.Parent do
            if previewPulse then
                local a = (math.sin(tick() * 1.6) + 1) / 2
                local tr = 0.35 + a * 0.4
                for _, d in ipairs(model:GetDescendants()) do
                    if d:IsA("BasePart") and d:GetAttribute("GhostPreview") then
                        d.Transparency = tr
                    end
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)

    local bbox = Instance.new("Part")
    bbox.Name = "PreviewBBox"
    bbox.Anchored = true
    bbox.CanCollide = false
    bbox.CanQuery = false
    bbox.CanTouch = false
    bbox.CastShadow = false
    bbox.Transparency = 1
    bbox.Size = Vector3.new(14, 14, 14)
    bbox.CFrame = CFrame.new((baseTransform * CFrame.new(bcenter)).Position)
    bbox.Parent = model
    previewBBox = bbox

    notify("Preview", "Rendering " .. #blocks .. " blocks...", 4)

    local work = 0
    local slabSwapped, slabFellBack, slabStandIn = 0, 0, 0
    -- Two ghosts in one cell z-fight, which reads as a flickering block with
    -- something grey behind it. Count them rather than guess.
    local occupied, clashes, clashSample = {}, 0, nil
    local renderList = blocks
    if previewMinimized then
        local occupied = {}
        for _, b in ipairs(blocks) do
            local p = arrayToCFrame(b.cframe).Position
            occupied[math.floor(p.X / 3) .. "," .. math.floor(p.Y / 3) .. "," .. math.floor(p.Z / 3)] = true
        end
        local function occ(cx, cy, cz)
            return occupied[cx .. "," .. cy .. "," .. cz] == true
        end

        local surface = {}
        for i, b in ipairs(blocks) do
            local p = arrayToCFrame(b.cframe).Position
            local cx, cy, cz = math.floor(p.X / 3), math.floor(p.Y / 3), math.floor(p.Z / 3)
            local buried = occ(cx + 1, cy, cz) and occ(cx - 1, cy, cz)
                and occ(cx, cy + 1, cz) and occ(cx, cy - 1, cz)
                and occ(cx, cy, cz + 1) and occ(cx, cy, cz - 1)
            if not buried then
                surface[#surface + 1] = b
            end
            if i % 6000 == 0 then task.wait() end
        end

        local CAP = 9000
        if #surface > CAP then
            local step = math.ceil(#surface / CAP)
            local thinned = {}
            for i = 1, #surface, step do
                thinned[#thinned + 1] = surface[i]
            end
            surface = thinned
        end

        renderList = surface
        notify("Minimized Preview", #renderList .. " of " .. #blocks .. " parts drawn", 4)
    end

    for i, block in ipairs(renderList) do
        if not isPreviewing then
            break
        end

        local blockType = effectiveType(tostring(block.blockType))
        local base = baseTransform * arrayToCFrame(block.cframe)
        local cellCF = CFrame.new(snapGridVec(base.Position)) * base.Rotation
        local upper = block.upperBlock == true
        local isSlab = blockType:find("[Ss]lab") ~= nil
        local isStair = blockType:find("[Ss]tair") ~= nil

        -- upperBlock means two different things and they were being treated as
        -- one. A top slab really does sit in the upper half of its cell, so it
        -- moves half a cell up. A top stair is an upside-down stair: it still
        -- fills its own cell, and is rolled over about the way it faces so the
        -- step ends up at the top. Moving that one up as well pushed a
        -- full-height stair straight through the block above it, which is the
        -- overlap you could see everywhere stairs met slabs.
        local targetCF = cellCF
        if upper and isStair then
            targetCF = cellCF * CFrame.Angles(0, 0, math.pi)
        end
        local rendered = false

        if previewRealModels and not previewMinimized and isModelType(blockType) then
            local template = getTemplate(blockType)
            if template then
                local ok, clone = pcall(function()
                    return template:Clone()
                end)
                if ok and clone then
                    ghostifyClone(clone, previewTransparency)
                    clone.Name = blockType
                    if clone:IsA("Model") then
                        pcall(function() clone:PivotTo(targetCF) end)
                    elseif clone:IsA("BasePart") then
                        clone.CFrame = targetCF
                    end
                    -- A slab block is one 3x3x3 part holding both halves as
                    -- MeshParts, 'bottom' at -0.75 and 'top' at +0.75, and the
                    -- half you see is whichever is not transparent. The
                    -- template shows its bottom, so a clone is always a bottom
                    -- slab however the block was flagged - which is why every
                    -- previewed slab looked low. Swap the halves instead of
                    -- moving the part: the geometry is already in the right
                    -- place, it is just the wrong half showing.
                    local slabOk = true
                    if isSlab then
                        local ok2, res = pcall(function()
                            return showSlabHalf(clone, upper, previewTransparency)
                        end)
                        slabOk = ok2 and res == true
                        if slabOk then
                            slabSwapped = slabSwapped + 1
                        else
                            slabFellBack = slabFellBack + 1
                        end
                    end
                    if not slabOk then
                        -- the template is not shaped like a placed block, so
                        -- it cannot show one half; the stand-in below can
                        pcall(function() clone:Destroy() end)
                    else
                        tagGhost(clone, blockSrcKey(block), brushPreview)
                        clone.Parent = model
                        rendered = true
                        work = work + 8
                    end
                end
            end
        end

        if not rendered then
            local part = Instance.new("Part")
            part.Name = blockType
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.CastShadow = false
            part.Material = Enum.Material.SmoothPlastic
            part.Transparency = previewTransparency
            -- A slab fills half its cell, so the stand-in is drawn half height
            -- and seated in the half it belongs to. Everything else, stairs
            -- included, fills the whole cell and is left alone: a full-height
            -- cube nudged up or down only ends up inside its neighbour.
            -- A hair under a full cell. A stand-in that exactly matches the
            -- block it sits over shares its surfaces, and two coplanar faces
            -- flicker as the camera moves - which is the grey block that
            -- appears to fight with the real one. Shrinking it by a fiftieth
            -- of a stud is invisible at this scale and stops that outright.
            local SHRINK = 0.02
            if isSlab then
                slabStandIn = slabStandIn + 1
                local dy = (upper and 1 or -1) * (previewBlockSize / 4)
                part.Size = Vector3.new(previewBlockSize - SHRINK,
                                        previewBlockSize / 2 - SHRINK,
                                        previewBlockSize - SHRINK)
                part.CFrame = cellCF + Vector3.new(0, dy, 0)
            else
                part.Size = Vector3.new(previewBlockSize - SHRINK,
                                        previewBlockSize - SHRINK,
                                        previewBlockSize - SHRINK)
                part.CFrame = cellCF
            end
            part.Color = colorForBlockType(blockType)
            part:SetAttribute("GhostPreview", true)
            tagGhost(part, blockSrcKey(block), brushPreview)
            part.Parent = model
            work = work + 1
        end

        do
            local c = cellCF.Position
            local key = (math.floor(c.X / 3 + 0.5) * 4096
                + math.floor(c.Y / 3 + 0.5)) * 4096 + math.floor(c.Z / 3 + 0.5)
            local was = occupied[key]
            -- a slab cell legitimately holds a top and a bottom; anything
            -- else sharing a cell is two things drawn in one place
            local slot = isSlab and (upper and "t" or "b") or "f"
            if was and (was == slot or was == "f" or slot == "f") then
                clashes = clashes + 1
                clashSample = clashSample or blockType
            end
            occupied[key] = slot
        end

        if work >= 600 then
            work = 0
            task.wait()
        end
    end

    if isPreviewing then
        -- Say what happened to the slabs. If they still look wrong, this is
        -- the line that says which of the three paths drew them.
        local total = slabSwapped + slabFellBack + slabStandIn
        local msg = "Turn on Move Handles, then drag it into place."
        if total > 0 then
            msg = ("%d slabs: %d real, %d stand-ins%s"):format(
                total, slabSwapped, slabStandIn + slabFellBack,
                slabFellBack > 0 and (" (" .. slabFellBack .. " had no halves)") or "")
        end
        if clashes > 0 then
            msg = msg .. ("\n%d blocks share a cell with another - that is the"
                .. " flicker. First one: %s"):format(clashes, tostring(clashSample))
            notifyWarn("Preview Ready", msg, 10)
        else
            notify("Preview Ready", msg, 7, "info")
        end
    end
end

local function applyPreviewDelta(delta)
    if not previewModel or not previewModel.Parent or not previewTransform then
        return
    end
    local pivot = previewModel:GetPivot()
    pcall(function() previewModel:PivotTo(delta * pivot) end)
    previewTransform = delta * previewTransform
    savedPreviewTransform = previewTransform
    saveAlignment(selectedFile, previewTransform)
end

local function setPreviewPivot(targetPivot)
    if not previewModel or not previewModel.Parent or not previewTransform then
        return
    end
    local pivot = previewModel:GetPivot()
    local delta = targetPivot * pivot:Inverse()
    pcall(function() previewModel:PivotTo(targetPivot) end)
    previewTransform = delta * previewTransform
    savedPreviewTransform = previewTransform
    saveAlignment(selectedFile, previewTransform)
end

local function nudgePreview(worldVec)
    applyPreviewDelta(CFrame.new(worldVec))
end

local function rotatePreview(deg)
    if not previewModel or not previewModel.Parent then return end
    local pivot = previewModel:GetPivot()
    setPreviewPivot(pivot * CFrame.Angles(0, math.rad(deg), 0))
end

local function snapPreviewToPlaced()
    if not previewModel or not previewModel.Parent or not lastPreviewBlocks or not previewTransform then
        notify("No Preview", "Preview a build first", 3)
        return
    end
    local folder = getBlocksFolder()
    if not folder then
        notify("No Island", "No island found near you", 3)
        return
    end

    local placedByType = {}
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "bedrock" and part.Name ~= "portalToSpawn" then
            local l = placedByType[part.Name]
            if not l then l = {} placedByType[part.Name] = l end
            l[#l + 1] = part.Position
        end
    end

    local counts, best, bestCount = {}, nil, 0
    local step = math.max(1, math.floor(#lastPreviewBlocks / 400))
    local n = 0
    for i = 1, #lastPreviewBlocks, step do
        local b = lastPreviewBlocks[i]
        local placedList = placedByType[effectiveType(tostring(b.blockType))]
        if placedList then
            local tpos = snapGridVec((previewTransform * arrayToCFrame(b.cframe)).Position)
            local nearD, nearP = 30, nil
            for _, pp in ipairs(placedList) do
                local d = (pp - tpos).Magnitude
                if d < nearD then nearD = d nearP = pp end
            end
            if nearP then
                local ox = math.floor((nearP.X - tpos.X) / 3 + 0.5) * 3
                local oy = math.floor((nearP.Y - tpos.Y) / 3 + 0.5) * 3
                local oz = math.floor((nearP.Z - tpos.Z) / 3 + 0.5) * 3
                local key = ox .. "," .. oy .. "," .. oz
                counts[key] = (counts[key] or 0) + 1
                if counts[key] > bestCount then
                    bestCount = counts[key]
                    best = Vector3.new(ox, oy, oz)
                end
            end
        end
        n = n + 1
        if n % 100 == 0 then task.wait() end
    end

    if not best then
        notify("No Match", "Move the preview closer to the placed build, then retry", 5)
    elseif best.Magnitude < 0.1 then
        notify("Already Aligned", "Preview already matches the placed blocks", 4)
    else
        applyPreviewDelta(CFrame.new(best))
        notify("Snapped To Build", "Aligned onto the placed blocks", 4)
    end
end

local function setDragMode(on)
    dragModeOn = on

    if moveHandles then moveHandles:Destroy() moveHandles = nil end
    for _, c in ipairs(handleConns) do pcall(function() c:Disconnect() end) end
    handleConns = {}
    handleStartPivot = nil

    if not on then
        notify("Move Handles OFF", "Locked. Use Build at Preview to place it.", 4)
        return
    end

    if not previewModel or not previewModel.Parent or not previewBBox then
        dragModeOn = false
        notify("No Preview", "Preview a build first", 3)
        return
    end

    local handles = Instance.new("Handles")
    handles.Adornee = previewBBox
    handles.Style = Enum.HandlesStyle.Movement
    handles.Color3 = Color3.fromRGB(255, 210, 40)
    handles.Transparency = 0
    local guiHost = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    handles.Parent = guiHost
    moveHandles = handles

    local lastSnap = nil

    table.insert(handleConns, handles.MouseButton1Down:Connect(function()
        handleStartPivot = previewModel:GetPivot()
        lastSnap = nil
    end))

    table.insert(handleConns, handles.MouseButton1Up:Connect(function()
        handleStartPivot = nil
        lastSnap = nil
    end))

    table.insert(handleConns, handles.MouseDrag:Connect(function(face, distance)
        if not previewModel or not previewModel.Parent then return end
        if not handleStartPivot then handleStartPivot = previewModel:GetPivot() end

        local snapped = math.floor(distance / 3 + 0.5) * 3
        local key = tostring(face) .. ":" .. snapped
        if key == lastSnap then return end
        lastSnap = key

        local localDir = Vector3.FromNormalId(face)
        local worldDir = previewBBox.CFrame:VectorToWorldSpace(localDir)
        setPreviewPivot(handleStartPivot + worldDir * snapped)
    end))

    notify("Move Handles ON", "Grab an arrow and drag. Snaps per block.", 6)
end

local function transformBlocks(blocks, transform)
    local out = {}
    for i, b in ipairs(blocks) do
        local cf = transform * arrayToCFrame(b.cframe)
        local p = snapGridVec(cf.Position)
        local r = cf.RightVector
        local u = cf.UpVector
        out[i] = {
            blockType  = b.blockType,
            upperBlock = b.upperBlock,
            cframe     = { p.X, p.Y, p.Z, r.X, r.Y, r.Z, u.X, u.Y, u.Z },
        }
        if i % 4000 == 0 then
            task.wait()
        end
    end
    return out
end

objList = {}
objSel = nil
objCount = 0
objMoveHandles = nil
objRotHandles = nil
objClickConn = nil
local objFolderName = "AB_ObjectsLive"

function objGetFolder()
    local f = Workspace:FindFirstChild(objFolderName)
    if not f then
        f = Instance.new("Folder")
        f.Name = objFolderName
        f.Parent = Workspace
    end
    return f
end

function objDrawOne(obj)
    if obj.model then obj.model:Destroy() end
    local model = Instance.new("Model")
    model.Name = obj.name
    model.Parent = objGetFolder()

    local isSel = (obj == objSel)
    local col = isSel and Color3.fromRGB(0, 255, 180) or Color3.fromRGB(255, 150, 0)
    local tr = isSel and 0.35 or 0.6

    for _, b in ipairs(obj.blocks) do
        local cf = obj.cframe * arrayToCFrame(b.cframe)
        local p = Instance.new("Part")
        p.Size = Vector3.new(3, 3, 3)
        p.CFrame = CFrame.new(snapGridVec(cf.Position))
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = true
        p.CanTouch = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Color = col
        p.Transparency = tr
        p:SetAttribute("ObjId", obj.id)
        p.Parent = model
    end

    local root = Instance.new("Part")
    root.Name = "ObjRoot"
    root.Anchored = true root.CanCollide = false root.CanQuery = false
    root.CanTouch = false root.CastShadow = false root.Transparency = 1
    root.Size = Vector3.new(1, 1, 1)
    root.CFrame = obj.cframe
    root.Parent = model
    model.PrimaryPart = root
    obj.model = model
end

function objClearHandles()
    if objMoveHandles then objMoveHandles:Destroy() objMoveHandles = nil end
    if objRotHandles then objRotHandles:Destroy() objRotHandles = nil end
end

function objSelect(obj)
    objSel = obj
    for _, o in ipairs(objList) do objDrawOne(o) end
    objClearHandles()
    if not (obj and obj.model and obj.model.PrimaryPart) then return end

    local hostGui = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")

    objMoveHandles = Instance.new("Handles")
    objMoveHandles.Adornee = obj.model.PrimaryPart
    objMoveHandles.Style = Enum.HandlesStyle.Movement
    objMoveHandles.Color3 = Color3.fromRGB(0, 255, 180)
    objMoveHandles.Parent = hostGui
    local mStart
    objMoveHandles.MouseButton1Down:Connect(function() mStart = obj.cframe end)
    objMoveHandles.MouseDrag:Connect(function(face, dist)
        if not mStart then return end
        local axis = Vector3.FromNormalId(face)
        local step = math.floor(dist / 3 + 0.5) * 3
        obj.cframe = mStart + axis * step
        objDrawOne(obj)
        objMoveHandles.Adornee = obj.model.PrimaryPart
        objRotHandles.Adornee = obj.model.PrimaryPart
    end)

    objRotHandles = Instance.new("ArcHandles")
    objRotHandles.Adornee = obj.model.PrimaryPart
    objRotHandles.Color3 = Color3.fromRGB(0, 200, 255)
    objRotHandles.Parent = hostGui
    local rStart
    objRotHandles.MouseButton1Down:Connect(function() rStart = obj.cframe end)
    objRotHandles.MouseDrag:Connect(function(axis, relAngle, deltaAngle)
        if not rStart then return end
        local snapped = math.rad(math.floor(math.deg(relAngle) / 15 + 0.5) * 15)
        local rot
        if axis == Enum.Axis.X then rot = CFrame.Angles(snapped, 0, 0)
        elseif axis == Enum.Axis.Y then rot = CFrame.Angles(0, snapped, 0)
        else rot = CFrame.Angles(0, 0, snapped) end
        obj.cframe = rStart * rot
        objDrawOne(obj)
        objMoveHandles.Adornee = obj.model.PrimaryPart
        objRotHandles.Adornee = obj.model.PrimaryPart
    end)
end

function objSelectById(id)
    for _, o in ipairs(objList) do
        if o.id == id then objSelect(o) return end
    end
end

function objEnableClickSelect()
    if objClickConn then return end
    objClickConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local mp = UserInputService:GetMouseLocation()
        local ray = cam:ViewportPointToRay(mp.X, mp.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { objGetFolder() }
        local hit = Workspace:Raycast(ray.Origin, ray.Direction * 8000, params)
        if hit and hit.Instance then
            local id = hit.Instance:GetAttribute("ObjId")
            if id then objSelectById(id) end
        end
    end)
end

function objStamp(blocks, label)
    objCount = objCount + 1
    local _, _, hrp = getCharacterParts()
    local base = hrp and (hrp.Position + Vector3.new(0, 6, 0)) or Vector3.new(0, 50, 0)
    local obj = {
        id = objCount,
        name = "Obj" .. objCount .. "_" .. (label or "build"),
        blocks = blocks,
        cframe = CFrame.new(snapGridVec(base)),
        model = nil,
    }
    objList[#objList + 1] = obj
    objDrawOne(obj)
    objSelect(obj)
    objEnableClickSelect()
    notify("Object Added", "Click any object to pick it. Drag arrows to move, rings to rotate.", 5)
    return obj
end

function objDuplicate()
    if not objSel then notify("No Object", "Click an object first", 3) return end
    objCount = objCount + 1
    local copy = {
        id = objCount,
        name = "Obj" .. objCount .. "_copy",
        blocks = objSel.blocks,
        cframe = objSel.cframe * CFrame.new(6, 0, 6),
        model = nil,
    }
    objList[#objList + 1] = copy
    objDrawOne(copy)
    objSelect(copy)
    notify("Duplicated", "Moved the copy over a bit", 3)
end

function objDeleteSel()
    if not objSel then notify("No Object", "Click an object first", 3) return end
    for i, o in ipairs(objList) do
        if o == objSel then
            if o.model then o.model:Destroy() end
            table.remove(objList, i)
            break
        end
    end
    objClearHandles()
    objSel = nil
    notify("Deleted", "Object removed", 2)
end

function objClearAll()
    for _, o in ipairs(objList) do if o.model then o.model:Destroy() end end
    objList = {}
    objSel = nil
    objClearHandles()
    if objClickConn then objClickConn:Disconnect() objClickConn = nil end
    notify("Cleared", "All objects removed", 2)
end

function objCombineToFile(fileName)
    if #objList == 0 then notify("No Objects", "Stamp at least one object", 3) return end
    local out, seen = {}, {}
    for _, o in ipairs(objList) do
        for _, b in ipairs(o.blocks) do
            local cf = o.cframe * arrayToCFrame(b.cframe)
            local p = snapGridVec(cf.Position)
            local key = p.X .. "_" .. p.Y .. "_" .. p.Z
            if not seen[key] then
                seen[key] = true
                local r, u = cf.RightVector, cf.UpVector
                out[#out + 1] = {
                    blockType = b.blockType,
                    upperBlock = b.upperBlock,
                    cframe = { p.X, p.Y, p.Z, r.X, r.Y, r.Z, u.X, u.Y, u.Z },
                    parts = {},
                }
            end
        end
    end
    if not isfolder("autoBuilder") then makefolder("autoBuilder") end
    local name = fileName or "MyScene"
    if not (name:lower():sub(-5) == ".json" or name:lower():sub(-4) == ".txt") then
        name = name .. ".json"
    end
    local ok, err = pcall(function()
        writefile("autoBuilder/" .. name, HttpService:JSONEncode({ blocks = out }))
    end)
    if not ok then notify("Save Failed", tostring(err), 5) return end
    sendSaveWebhook(name)
    selectedFile = name
    pcall(function() saveAlignment(name, CFrame.new()) end)
    pcall(function() fileDropdown:Refresh(getFiles(), true) fileDropdown:Set({ name }) end)
    notify("Saved", #out .. " blocks -> " .. name, 6)
end

local blockDisplayCache = {}

local function prettifyBlockName(name)
    local s = tostring(name)
    s = s:gsub("(%l)(%u)", "%1 %2")
    s = s:gsub("(%u)(%u%l)", "%1 %2")
    s = s:gsub("(%a)(%d)", "%1 %2")
    s = s:gsub("(%a)([%w]*)", function(a, rest) return a:upper() .. rest end)
    return s
end

local function resolveBlockDisplayName(blockType)
    local key = tostring(blockType)
    if blockDisplayCache[key] ~= nil then
        return blockDisplayCache[key]
    end

    local result = nil
    pcall(function()
        -- The game keeps the readable name on the *tool* template, not the
        -- block template, so "flowerDaisyYellowFertile" only resolves to
        -- "Fertile Yellow Daisy" if we look in Tools as well. Folder casing
        -- differs between places, hence both spellings.
        for _, folderName in ipairs({ "Tools", "tools", "Blocks", "blocks", "Items" }) do
            local folder = ReplicatedStorage:FindFirstChild(folderName)
            local template = folder and folder:FindFirstChild(key)
            if template then
                local dn = template:FindFirstChild("DisplayName")
                if dn and dn:IsA("StringValue") and dn.Value ~= "" then
                    result = dn.Value
                else
                    for _, d in ipairs(template:GetDescendants()) do
                        if d.Name == "DisplayName" and d:IsA("StringValue") and d.Value ~= "" then
                            result = d.Value
                            break
                        end
                    end
                end
            end
            if result and result ~= "" then break end
        end
    end)

    if not result or result == "" then
        result = prettifyBlockName(key)
    end

    blockDisplayCache[key] = result
    return result
end


-- ── Block list ─────────────────────────────────────────────────────────────
-- One source for every block picker. Filters out tools and anything without
-- geometry (the raw folder contains axes and the like), and presents display
-- names while callers keep working in internal names.
local blockListCache, blockByDisplay = nil, {}

local function isPlaceableBlock(inst)
    if inst:IsA("Tool") then return false end
    if inst:FindFirstChild("Handle") then return false end
    local low = inst.Name:lower()
    for _, bad in ipairs({ "axe", "pickaxe", "sword", "shovel", "hoe", "bow",
                           "rod", "tool", "bucket", "hammer", "scythe" }) do
        if low:find(bad) then return false end
    end
    if inst:IsA("BasePart") then return true end
    return inst:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function blockDisplayList()
    if blockListCache then return blockListCache end
    local out = {}
    blockByDisplay = {}
    local folder = ReplicatedStorage:FindFirstChild("blocks")
    if folder then
        for _, v in ipairs(folder:GetChildren()) do
            if isPlaceableBlock(v) then
                local d = resolveBlockDisplayName(v.Name)
                if not blockByDisplay[d] then
                    blockByDisplay[d] = v.Name
                    out[#out + 1] = d
                end
            end
        end
    end
    table.sort(out)
    if #out == 0 then out = { "Stone", "Grass" } blockByDisplay = { Stone = "stone", Grass = "grass" } end
    blockListCache = out
    return out
end

-- display name back to the internal id the placement code needs
local function blockIdFor(display)
    if not display then return nil end
    blockDisplayList()
    return blockByDisplay[display] or display
end

local function blockDisplayFor(id)
    return resolveBlockDisplayName(id)
end

-- The same required-blocks rundown the paragraph shows, but as data, so the
-- panel can render one clickable row per entry.
requiredBlocksList = {}
-- block ids the user clicked away; cleared by Unhide All
requiredHidden = {}

local function getRequiredBlocksText(blocks)
    local needed = {}
    local order = {}
    for _, b in ipairs(blocks) do
        local t = effectiveType(tostring(b.blockType))
        if needed[t] == nil then
            needed[t] = 0
            table.insert(order, t)
        end
        needed[t] = needed[t] + 1
    end

    local have = scanInventoryCounts()

    -- reverse map so an entry knows the type it was replaced from
    local swappedFrom = {}
    for from, to in pairs(blockReplacements) do swappedFrom[to] = from end

    local list = {}
    for _, t in ipairs(order) do
        if not requiredHidden[t] then
            table.insert(list, {
                name = resolveBlockDisplayName(t),
                have = have[t] or 0,
                need = needed[t],
                from = swappedFrom[t],
                id = t,
            })
        end
    end
    table.sort(list, function(a, b) return a.need > b.need end)

    requiredBlocksList = {}
    local lines = {}
    local hidden = 0
    for _, e in ipairs(list) do
        if e.need < requiredMinCount then
            hidden = hidden + 1
        else
            requiredBlocksList[#requiredBlocksList + 1] = e
            -- show the swap inline when this type is being replaced
            local label = e.name
            if e.from then
                label = resolveBlockDisplayName(e.from) .. " -> " .. e.name
            end
            local line = label .. "  " .. e.have .. "/" .. e.need
            if e.have < e.need then
                line = '<font color="rgb(255,80,80)">' .. line .. "</font>"
            end
            table.insert(lines, line)
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Types: " .. (#list - hidden)
        .. (hidden > 0 and ("  (" .. hidden .. " under " .. requiredMinCount .. " hidden)") or ""))

    return table.concat(lines, "\n")
end

-- These two drive everything else on the tab, so they sit above the sections
-- rather than inside one.
auto:CreateToggle({
    Name = "Show Selection Box",
    CurrentValue = false,
    Flag = "ShowSelBox",
    Tooltip = "Turn this on, then click where you want the box. Anything inside it is what gets saved.",
    Callback = function(v)
        selBoxOnly = v
        if v then
            pcall(function() BuilderAPI.showSelBox() end)
            pcall(function() BuilderAPI.armSelBoxPlacement() end)
            notify("Click to Place", "Click where you want the box, then drag its handles to resize", 6)
        else
            pcall(function() BuilderAPI.hideSelBox() end)
        end
    end
})

BuilderAPI.toggles.brush = auto:CreateToggle({
    Name = "Block Brush",
    Tooltip = "Hold click and drag over blocks to pick them. The gear opens the brush settings, and the dot menu opens the object tools.",
    CurrentValue = false,
    Flag = "BlockBrush",
    -- The gear opens the brush settings without arming the brush.
    GearAction = {
        Icon = "gear",
        OnClick = function()
            local ok = pcall(function() BuilderAPI.brushPanel:Toggle() end)
            if not ok then notifyWarn("Brush", "Panel not ready yet", 3) end
        end,
    },
    Callback = function(v)
        blockSelMode = v
        if v then
            if blockSelConn then blockSelConn.Disconnect() end
            local downC = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then blockSelDown = true end
            end)
            local upC = UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then blockSelDown = false end
            end)
            local paintC = RunService.Heartbeat:Connect(function()
                if not blockSelMode or not blockSelDown then return end
                local part, normal = blockUnderCursor()
                if part then
                    local erase = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                    for _, b in ipairs(brushTargets(part, normal)) do
                        if erase then unhighlightBlock(b) else highlightBlock(b) end
                    end
                end
            end)
            blockSelConn = { Disconnect = function() downC:Disconnect() upC:Disconnect() paintC:Disconnect() end }
            notify("Block Brush On", "Hold left-click to select, hold Shift to erase", 6)
        else
            if blockSelConn then blockSelConn.Disconnect() blockSelConn = nil end
            blockSelDown = false
            notify("Block Brush Off", blockSelCount .. " blocks still selected", 3)
        end
    end
})

auto:CreateButton({
    Name = "Object Tools",
    Tooltip = "Opens the tools for what you have picked in a preview: duplicate, delete, move, rotate and mirror.",
    Callback = function()
        local ok = pcall(function() BuilderAPI.objectPanel:Toggle() end)
        if not ok then notifyWarn("Objects", "Panel not ready yet", 3) end
    end
})

auto:CreateSection("Build", { Collapsible = true })

progressParagraph = auto:CreateParagraph({
    Title = "Build Progress",
    Content = "Idle. Start a build to see live progress and ETA."
})

fileDropdown = auto:CreateDropdown({
    Name = "Select Build File",
    GearAction = {
        Icon = "eye",
        OnClick = function()
            if BuilderAPI.thumbOpen then
                BuilderAPI.thumbOpen(not (BuilderAPI.thumbPanel and BuilderAPI.thumbPanel:IsOpen()))
            end
        end,
    },
    -- Refresh and Delete sit in the dropdown list itself; a gear for two
    -- actions was more chrome than they deserve.
    Actions = {
        { Text = "Refresh", OnClick = function()
            pcall(function() fileDropdown:Refresh(getFiles(), true) end)
            notify("Files", "List refreshed", 2, "info")
        end },
        { Text = "Delete", OnClick = function()
            if not selectedFile or selectedFile == "" then
                notifyWarn("No File", "Pick a build file first", 3)
                return
            end
            local target = selectedFile
            confirm("Delete Build File",
                "Permanently delete '" .. target .. "'? This cannot be undone.",
                "Delete", function()
                    local ok = pcall(function()
                        local path = filePathFor(target)
                        if isfile(path) then delfile(path) end
                    end)
                    pcall(function() clearAlignment(target) end)
                    if ok then
                        selectedFile = nil
                        fileDropdown:Refresh(getFiles(), true)
                        notifyOK("Deleted", "'" .. target .. "' removed", 4)
                    else
                        notifyErr("Delete Failed", "Couldn't delete the file", 4)
                    end
                end)
        end },
    },
    Options = getFiles(),
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "FileDropdown",
    Callback = function(option)
        if typeof(option) == "table" then
            selectedFile = option[1]
        else
            selectedFile = option
        end
        savedPreviewTransform = nil
        -- deletions belong to the build they were made on
        restorePreviewDeletions()
        omittedTypes = {}
        omittedTypeCount = 0
        requiredHidden = {}
    end
})

auto:CreateToggle({
    Name = "Build Tuning",
    CurrentValue = false,
    Flag = "UseRecommended",
    Tooltip = "On applies safe values: interval 0.2s, fly 25, gap 12. Open the gear to tune them yourself.",
    Gear = {
        -- popover sliders are whole numbers only, hence milliseconds here
        { Type = "slider", Name = "Place Interval (ms)", Min = 5, Max = 1000, Default = 20,
          Callback = function(v) placeDelay = v / 1000 end },
        { Type = "slider", Name = "Fly Speed", Min = 8, Max = 80, Default = 35,
          Callback = function(v) buildFlySpeed = v end },
        { Type = "slider", Name = "Build Gap", Min = 3, Max = 40, Default = 12,
          Callback = function(v) buildStandoff = v end },
    },
    Callback = function(v)
        if v then
            placeDelay = 0.2
            buildFlySpeed = 25
            buildStandoff = 12
            notifyOK("Build Tuning", "Interval 0.2s, Fly 25, Gap 12", 4)
        end
    end
})

auto:CreateDropdown({
    Name = "Build Style",
    Options = {"Around Preview", "Expand from Middle", "Batch (verify)", "Turbo Print"},
    CurrentOption = {"Around Preview"},
    MultipleOptions = false,
    Flag = "BuildMode",
    Callback = function(option)
        buildMode = (typeof(option) == "table") and option[1] or option
    end
})

auto:CreateDropdown({
    Name = "Movement Mode",
    Options = {"Fly", "Float", "Teleport"},
    CurrentOption = {"Fly"},
    MultipleOptions = false,
    Flag = "MoveMode",
    Callback = function(option)
        moveMode = (typeof(option) == "table") and option[1] or option
    end
})

BuilderAPI.toggles.build = auto:CreateToggle({
    Name = "Start Build",
    CurrentValue = false,
    Flag = "BuildToggle",
    Gear = {
        { Type = "toggle", Name = "Skip Existing", Default = false,
          Callback = function(v) placeMissingOnly = v end },
        { Type = "toggle", Name = "Owned Only", Default = false,
          Callback = function(v) onlyUseOwned = v end },
        { Type = "toggle", Name = "Adaptive Rate", Default = false,
          Callback = function(v) adaptiveRate = v end },
        { Type = "toggle", Name = "Pipelined Placing", Default = false,
          Callback = function(v) pipelineMode = v end },
        { Type = "slider", Name = "Pipeline Depth", Min = 2, Max = 30, Default = 8,
          Callback = function(v) pipelineDepth = v end },
        { Type = "toggle", Name = "Turbo Hop", Default = true,
          Callback = function(v) turboTeleport = v end },
        { Type = "slider", Name = "Turbo Delay (ms)", Min = 0, Max = 200, Default = 0,
          Callback = function(v) turboDelay = v / 1000 end },
        { Type = "toggle", Name = "Walk To Block", Default = true,
          Callback = function(v) moveToBuildPosition = v end },
        { Type = "slider", Name = "Expand Reach", Min = 20, Max = 400, Default = 120,
          Callback = function(v) expandReach = v end },
    },
    Tooltip = "Starts building. Turn it off to stop partway.",
    Callback = function(v)
        if v then
            if isBuilding then
                notifyWarn("Busy", "A build is already running", 3)
                return
            end
            if dragModeOn then
                notifyWarn("Lock It First", "Turn off Move Handles to lock the spot", 3)
                return
            end
            local data = loadSelectedBuild()
            if not data then
                return
            end
            local missingOnly = placeMissingOnly
            if previewTransform then
                local raw = dropOmittedBlocks(data.blocks)
                task.spawn(function()
                    notify("Building", "Building where the ghost sits", 3, "info")
                    -- hollowExterior yields, so it belongs in here
                    local src = hollowExterior(dedupeBlocks(raw))
                    local transformed = filterShapes(transformBlocks(src, previewTransform))
                    if buildMode == "Turbo Print" then
                        turboPrint(transformed)
                    else
                        runBuild(transformed, missingOnly)
                    end
                end)
            else
                -- hollowExterior yields, so this runs off the toggle callback
                task.spawn(function()
                    local blocks = filterShapes(hollowExterior(dedupeBlocks(dropOmittedBlocks(data.blocks))))
                    if buildMode == "Turbo Print" then
                        turboPrint(blocks)
                    else
                        runBuild(blocks, missingOnly)
                    end
                end)
            end
        else
            isBuilding = false
            turboAbort = true
            releaseShift()
            notifyWarn("Stopped", "Build stopped", 3)
        end
    end
})

BuilderAPI.toggles.destroy = auto:CreateToggle({
    Name = "Block Destroyer",
    CurrentValue = false,
    Tooltip = "Breaks blocks inside the selection box. Waits for each one to actually vanish before moving on.",
    Gear = {
        { Type = "toggle", Name = "Brush Selection", Default = false,
          Callback = function(v) BuilderAPI.destroyer.brushOnly = v end },
        { Type = "toggle", Name = "Selection Box Only", Default = true,
          Callback = function(v) BuilderAPI.destroyer.boxOnly = v end },
        { Type = "toggle", Name = "Confirm Destroyed", Default = true,
          Callback = function(v) BuilderAPI.destroyer.confirm = v end },
        { Type = "slider", Name = "Hits Per Block", Min = 1, Max = 20, Default = 3,
          Callback = function(v) BuilderAPI.destroyer.hits = v end },
        { Type = "slider", Name = "Hit Gap (ms)", Min = 0, Max = 200, Default = 30,
          Callback = function(v) BuilderAPI.destroyer.hitGap = v end },
        { Type = "slider", Name = "Give Up After", Min = 1, Max = 20, Default = 6,
          Callback = function(v) BuilderAPI.destroyer.maxTries = v end },
    },
    Callback = function(on)
        local D = BuilderAPI.destroyer
        if on then
            if D.run then D.run() end
        else
            D.abort = true
        end
    end
})

auto:CreateDropdown({
    Name = "Destroy Only These",
    Options = blockDisplayList(), CurrentOption = {}, MultipleOptions = true,
    Callback = function(v)
        local set = {}
        if typeof(v) == "table" then
            for _, d in ipairs(v) do set[blockIdFor(d)] = true end
        elseif v then
            set[blockIdFor(v)] = true
        end
        BuilderAPI.destroyer.types = set
    end
})

auto:CreateRangeSlider({
    Name = "Delay Between Blocks",
    Range = { 0, 500 }, Increment = 5,
    DefaultMin = 20, DefaultMax = 60, Suffix = "ms",
    Callback = function(mn, mx)
        BuilderAPI.destroyer.minDelay = mn
        BuilderAPI.destroyer.maxDelay = mx
    end
})


-- ── Schematics ─────────────────────────────────────────────────────────────
-- Sits with the other file pickers because that is what a schematic is here:
-- another thing you can preview and build. Converting happens when you pick
-- it, not behind a separate button, so Preview Build works straight away.
auto:CreateSection("Schematic", { Collapsible = true, Column = "left", Order = 2 })

-- declared before use: its own Refresh action reaches it
schemDropdown = auto:CreateDropdown({
    Name = "Select Schematic",
    Actions = {
        { Text = "Refresh", OnClick = function()
            pcall(function() schemDropdown:Refresh(BuilderAPI.schematicFiles(), true) end)
            notify("Schematics", "List refreshed", 2, "info")
        end },
        { Text = "Delete", OnClick = function()
            if not CONVERT or not CONVERT.file then
                notifyWarn("No Schematic", "Pick one first", 3)
                return
            end
            local target = CONVERT.file
            confirm("Delete Schematic", "Permanently delete '" .. target .. "'?",
                "Delete", function()
                    pcall(function()
                        local path = filePathFor(target)
                        if isfile(path) then delfile(path) end
                    end)
                    CONVERT.file = nil
                    CONVERT.cache = {}
                    pcall(function() schemDropdown:Refresh(BuilderAPI.schematicFiles(), true) end)
                    notifyOK("Deleted", "'" .. target .. "' removed", 4)
                end)
        end },
    },
    Options = { "Press Refresh" },
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "ConvertFile",
    Tooltip = "Put .schem and .litematic files in the converter folder inside autoBuilder. Picking one converts it, then Preview Build shows it.",
    Callback = function(v)
        local name = (typeof(v) == "table") and v[1] or v
        if not isSchematicFile(name) or not CONVERT then return end
        CONVERT.file = name
        selectedFile = name
        savedPreviewTransform = nil
    end
})

auto:CreateButton({
    Name = "Test Slab Placement",
    Tooltip = "Places two slabs in front of you - one asked for the bottom half, one for the top - then reads back which half each actually got. That is the one thing left to find out about slabs, and it takes a click.",
    Callback = function()
        task.spawn(function()
            -- a slab from your inventory to test with
            local slabName
            for _, where in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
                if where then
                    for _, item in ipairs(where:GetChildren()) do
                        if item:IsA("Tool") and string.lower(item.Name):find("slab") then
                            slabName = item.Name
                            break
                        end
                    end
                end
                if slabName then break end
            end
            if not slabName then
                notifyWarn("Slab Test", "Put any slab in your inventory first", 6)
                return
            end

            local _, _, hrp = getCharacterParts()
            if not hrp then return end
            updateGridPhase(true)

            -- two empty cells in front of you, three studs apart
            local base = hrp.Position + hrp.CFrame.LookVector * 9
            local a = snapGridVec(Vector3.new(base.X, hrp.Position.Y, base.Z))
            local b = a + Vector3.new(6, 0, 0)

            notify("Slab Test", "Placing two " .. slabName .. "...", 5, "info")
            placeRawBlock(slabName, CFrame.new(a), false)
            task.wait(0.4)
            placeRawBlock(slabName, CFrame.new(b), true)
            task.wait(1.2)

            local folder = getBlocksFolder()
            if not folder then
                notifyWarn("Slab Test", "Lost the island somehow", 4)
                return
            end
            local function halfAt(pos)
                local best, bestD
                for _, part in ipairs(folder:GetChildren()) do
                    if part:IsA("BasePart") and string.lower(part.Name):find("slab") then
                        local d = (part.Position - pos).Magnitude
                        if d < 3 and (not bestD or d < bestD) then best, bestD = part, d end
                    end
                end
                if not best then return "nothing placed" end
                return slabHalfOf(best) or "could not tell"
            end

            local askedBottom = halfAt(a)
            local askedTop = halfAt(b)
            local verdict
            if askedTop == "top" and askedBottom == "bottom" then
                verdict = "upperBlock WORKS - converted slabs should be correct"
            elseif askedTop == "bottom" then
                verdict = "upperBlock IS IGNORED - the server always makes a bottom slab"
            else
                verdict = "inconclusive"
            end

            local text = table.concat({
                "=== SLAB PLACEMENT TEST ===",
                "block: " .. slabName,
                "asked for bottom -> got " .. tostring(askedBottom),
                "asked for top    -> got " .. tostring(askedTop),
                verdict,
                "===========================",
            }, "\n")
            warn(text)
            pcall(function() setclipboard(text) end)
            notifyOK("Slab Test", verdict, 12)
        end)
    end
})

auto:CreateButton({
    Name = "Inspect Slabs",
    Tooltip = "Place one slab in the bottom half and one in the top half near you, then press this. It reports how the game itself stores them, which is what decides how a converted slab has to be written.",
    Callback = function()
        task.spawn(function()
            local folder = getBlocksFolder()
            if not folder then
                notifyWarn("Inspect", "No island found near you", 4)
                return
            end
            local _, _, hrp = getCharacterParts()
            local origin = hrp and hrp.Position or Vector3.new()

            local found = {}
            for _, part in ipairs(folder:GetChildren()) do
                if part:IsA("BasePart") and string.lower(part.Name):find("slab")
                    and (part.Position - origin).Magnitude < 60 then
                    found[#found + 1] = part
                end
            end
            if #found == 0 then
                notifyWarn("Inspect", "No slabs within 60 studs - place one and try again", 6)
                return
            end
            table.sort(found, function(a, b)
                return (a.Position - origin).Magnitude < (b.Position - origin).Magnitude
            end)

            -- Two slabs in different halves save as identical data, so the
            -- thing that tells them apart is not the position, the rotation or
            -- the size. Dump everything the part carries and find it.
            -- A slab block is one 3x3x3 part holding a 'bottom' and a 'top'
            -- MeshPart. Both are always present, so which half you see is a
            -- property of those children. Rather than dump everything again,
            -- compare the two nearest slabs and print only what differs -
            -- that difference is the thing the converter has to reproduce.
            local PROPS = {
                "Transparency", "LocalTransparencyModifier", "CanCollide",
                "CanQuery", "CanTouch", "CastShadow", "Massless", "Anchored",
                "Reflectance", "Material", "Color", "Size", "Name",
                "MeshId", "TextureID", "MeshSize", "Archivable",
            }
            local function snapshot(part)
                local out = {}
                for _, d in ipairs(part:GetChildren()) do
                    for _, prop in ipairs(PROPS) do
                        local ok, v = pcall(function() return d[prop] end)
                        if ok and v ~= nil then
                            out[d.Name .. "." .. prop] = tostring(v)
                        end
                    end
                    pcall(function()
                        for k, v in pairs(d:GetAttributes()) do
                            out[d.Name .. ".@" .. k] = tostring(v)
                        end
                    end)
                    if d:IsA("BasePart") then
                        local rel = part.CFrame:PointToObjectSpace(d.Position)
                        out[d.Name .. ".relY"] = string.format("%.3f", rel.Y)
                    end
                end
                for _, prop in ipairs(PROPS) do
                    local ok, v = pcall(function() return part[prop] end)
                    if ok and v ~= nil then out["SELF." .. prop] = tostring(v) end
                end
                return out
            end

            local function compare()
                if #found < 2 then return end
                local a, b = snapshot(found[1]), snapshot(found[2])
                local keys, seen = {}, {}
                for k in pairs(a) do if not seen[k] then seen[k] = true keys[#keys+1] = k end end
                for k in pairs(b) do if not seen[k] then seen[k] = true keys[#keys+1] = k end end
                table.sort(keys)
                local diffs = {}
                for _, k in ipairs(keys) do
                    if a[k] ~= b[k] then
                        diffs[#diffs + 1] = ("   %-34s  slab1=%-22s slab2=%s")
                            :format(k, tostring(a[k]), tostring(b[k]))
                    end
                end
                local head = { "=== WHAT DIFFERS BETWEEN THE TWO NEAREST SLABS ===" }
                if #diffs == 0 then
                    head[#head + 1] = "   nothing - they are identical in every property checked"
                else
                    for _, d in ipairs(diffs) do head[#head + 1] = d end
                end
                head[#head + 1] = ""
                return table.concat(head, "\n")
            end

            local lines = { "=== SLAB INSPECTION ===" }
            for i = 1, math.min(4, #found) do
                local p = found[i]
                local y = p.Position.Y
                local cell = math.floor(y / 3 + 0.5) * 3
                lines[#lines + 1] = ("--- slab %d: %s ---"):format(i, p.Name)
                lines[#lines + 1] = ("  class=%s  size=%.3f,%.3f,%.3f")
                    :format(p.ClassName, p.Size.X, p.Size.Y, p.Size.Z)
                lines[#lines + 1] = ("  pos=%.3f,%.3f,%.3f  cell=%.0f  yOffset=%+.3f")
                    :format(p.Position.X, y, p.Position.Z, cell, y - cell)
                lines[#lines + 1] = ("  orientation=%.1f,%.1f,%.1f")
                    :format(p.Orientation.X, p.Orientation.Y, p.Orientation.Z)

                local attrs = {}
                pcall(function()
                    for k, v in pairs(p:GetAttributes()) do
                        attrs[#attrs + 1] = k .. "=" .. tostring(v)
                    end
                end)
                table.sort(attrs)
                lines[#lines + 1] = "  attributes: " .. (#attrs > 0 and table.concat(attrs, ", ") or "none")

                if p:IsA("MeshPart") then
                    lines[#lines + 1] = ("  meshId=%s  meshSize=%.3f,%.3f,%.3f")
                        :format(tostring(p.MeshId), p.MeshSize.X, p.MeshSize.Y, p.MeshSize.Z)
                end

                -- The half that is showing is the whole question, so put it
                -- on its own line per half rather than buried in a list.
                for _, which in ipairs({ "bottom", "top" }) do
                    local d = p:FindFirstChild(which)
                    if d and d:IsA("BasePart") then
                        local rel = p.CFrame:PointToObjectSpace(d.Position)
                        lines[#lines + 1] = ("  %-6s transparency=%.2f  ltm=%.2f  size=%.2f,%.2f,%.2f  relY=%+.2f  collide=%s  -> %s")
                            :format(which, d.Transparency, d.LocalTransparencyModifier,
                                    d.Size.X, d.Size.Y, d.Size.Z, rel.Y,
                                    tostring(d.CanCollide),
                                    (d.Transparency < 0.5 and d.Size.Y > 0.01) and "SHOWING" or "hidden")
                    else
                        lines[#lines + 1] = ("  %-6s not present"):format(which)
                    end
                end
                local others = {}
                for _, d in ipairs(p:GetChildren()) do
                    if d.Name ~= "top" and d.Name ~= "bottom" then
                        local v = ""
                        pcall(function() if d.Value ~= nil then v = "=" .. tostring(d.Value) end end)
                        others[#others + 1] = d.ClassName .. " '" .. d.Name .. "'" .. v
                    end
                end
                lines[#lines + 1] = "  other children: " .. (#others > 0 and table.concat(others, " | ") or "none")

                -- and the parent, in case the marker lives above the part
                if p.Parent then
                    lines[#lines + 1] = ("  parent=%s '%s'"):format(p.Parent.ClassName, p.Parent.Name)
                end
            end
            lines[#lines + 1] = "=== " .. #found .. " slabs near you ==="
            local diff = compare()
            if diff then
                lines[#lines + 1] = ""
                lines[#lines + 1] = diff
            end
            local text = table.concat(lines, "\n")
            warn(text)
            pcall(function() setclipboard(text) end)
            notifyOK("Inspect", #found .. " slabs - written to the console and copied to your clipboard", 9)
        end)
    end
})

auto:CreateDropdown({
    Name = "Hollow",
    -- Two settings rather than one toggle, because the two do very different
    -- amounts of work depending on the build. On Mawglass Citadel, Hidden
    -- Blocks finds 1.5% and Outside Only finds 58.5%: the first is for solid
    -- masses, the second for anything you only ever see from outside.
    Options = { "Off", "Hidden Blocks", "Outside Only" },
    CurrentOption = { "Off" },
    MultipleOptions = false,
    Flag = "ConvertHollow",
    Tooltip = "Off builds every block. Hidden Blocks drops only the ones sealed inside, so it looks exactly the same and costs less. Outside Only keeps the shell you can see and throws away everything behind it, which is far cheaper but loses interior floors and rooms.",
    Callback = function(v)
        if not CONVERT then return end
        CONVERT.hollow = (typeof(v) == "table") and v[1] or v
        CONVERT.cache = {}
    end
})

auto:CreateSlider({
    Name = "Blend to Colours", Range = { 0, 40 }, Increment = 1, CurrentValue = 0,
    Suffix = "types", Flag = "ConvertSimplify",
    Tooltip = "Minecraft's stone, andesite and diorite all arrive as different Islands blocks, so one wall turns into several greys and looks like scattered blocks. This keeps the most-used blocks and moves the rest onto the nearest one that looks the same. 0 leaves every block as it converted.",
    Callback = function(v)
        if not CONVERT then return end
        CONVERT.simplify = v
        CONVERT.cache = {}
    end
})

auto:CreateToggle({
    Name = "Smooth the Blend",
    CurrentValue = true,
    Flag = "ConvertBlend",
    Tooltip = "When a colour sits between two of the blocks you kept, alternate between them so it reads as the shade in between instead of jumping to one.",
    Callback = function(v)
        if not CONVERT then return end
        CONVERT.blend = v
        CONVERT.cache = {}
    end
})

-- ── Models ─────────────────────────────────────────────────────────────────
-- Sits under Build because a .glb in autoBuilder is picked from the same file
-- list as a build file; these are the settings for turning one into blocks.
auto:CreateSection("Model", { Collapsible = true, Column = "left", Order = 1 })

-- declared before use: its own Actions refresh it


modelDropdown = auto:CreateDropdown({
    Name = "Select Model",
    -- Shows the real mesh where the executor allows it, and the blocks it
    -- would become where it does not.
    GearAction = {
        Icon = "eye",
        OnClick = function()
            if not MODEL or not MODEL.selected then
                notifyWarn("Model", "Pick a model first", 3)
                return
            end
            if BuilderAPI.thumbOpen then
                BuilderAPI.thumbOpen(not (BuilderAPI.thumbPanel and BuilderAPI.thumbPanel:IsOpen()))
            end
        end,
    },
    Actions = {
        { Text = "Refresh", OnClick = function()
            pcall(function() modelDropdown:Refresh(getModelFiles(), true) end)
            notify("Models", "List refreshed", 2, "info")
        end },
        { Text = "Delete", OnClick = function()
            if not MODEL or not MODEL.selected then
                notifyWarn("No Model", "Pick a model first", 3)
                return
            end
            local target = MODEL.selected
            confirm("Delete Model", "Permanently delete '" .. target .. "'?",
                "Delete", function()
                    pcall(function()
                        local path = filePathFor(target)
                        if isfile(path) then delfile(path) end
                    end)
                    MODEL.selected = nil
                    MODEL.cache = {}
                    pcall(function() modelDropdown:Refresh(getModelFiles(), true) end)
                    notifyOK("Deleted", "'" .. target .. "' removed", 4)
                end)
        end },
    },
    Options = getModelFiles(),
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "ModelDropdown",
    Tooltip = "Models go in the models folder inside autoBuilder. Pick one here and it becomes what you preview and build.",
    Callback = function(option)
        local name = (typeof(option) == "table") and option[1] or option
        if not name or not isModelFile(name) then return end
        if not MODEL then return end
        MODEL.selected = name
        -- the rest of the hub works off selectedFile, so a model simply
        -- becomes the selected file; the build dropdown does the same
        selectedFile = name
        savedPreviewTransform = nil
    end
})

auto:CreateSlider({
    Name = "Model Detail", Range = { 16, 512 }, Increment = 8, CurrentValue = 96,
    Suffix = "cells", Flag = "ModelDetail",
    Tooltip = "How big the model comes out, in blocks along its longest side. Bigger looks more like the real thing and costs a lot more blocks. Turn the preview off and on to redraw it.",
    Callback = function(v)
        if not MODEL then return end
        MODEL.grid = v
    end
})

auto:CreateDropdown({
    Name = "Model Palette",
    -- The same nine families the image converter offers. Spelled out here
    -- because IMAGE_GROUPS is defined further down the file than this tab.
    Options = { "Solid", "Wool", "Clay", "Neon", "Pastel", "Wood", "Stone",
                "Natural", "Ore" },
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ModelPalette",
    Tooltip = "Which kinds of blocks the model is allowed to use. Leave it empty to allow all of them. That is usually best.",
    Callback = function(v)
        if not MODEL then return end
        local set = {}
        if typeof(v) == "table" then
            for _, g in ipairs(v) do set[g] = true end
        elseif v then
            set[v] = true
        end
        MODEL.groups = set
        MODEL.cache = {}
        if MODEL.buildPalette then MODEL.buildPalette() end
    end
})

auto:CreateSlider({
    Name = "Simplify", Range = { 0, 40 }, Increment = 1, CurrentValue = 0,
    Suffix = "types", Flag = "ModelSimplify",
    Tooltip = "The most different blocks the whole model may use. 0 means no limit. A small number looks simpler and is much cheaper to build.",
    Callback = function(v)
        if not MODEL then return end
        MODEL.limit = v
        MODEL.cache = {}
    end
})

auto:CreateToggle({
    Name = "Blend Colours",
    CurrentValue = true,
    Flag = "ModelDither",
    Tooltip = "Off uses one block per colour. That looks clean, and it is usually better for skin and clothes. On mixes two close blocks so your eye sees the shade between them, which helps where colours fade into each other. The gear sets how much mixing.",
    Gear = {
        { Type = "slider", Name = "Blend Amount", Min = 0, Max = 100, Default = 45,
          Callback = function(v)
            if not MODEL then return end
            -- One dial over two: how often the second block is allowed, and
            -- how badly the nearest has to fit before mixing is worth it.
            MODEL.ditherAmount = v / 100
            MODEL.ditherMin = 0.08 - 0.06 * (v / 100)
            MODEL.cache = {}
            MODEL.ditherCache = {}
        end },
    },
    Callback = function(v)
        if not MODEL then return end
        MODEL.dither = v
        MODEL.cache = {}
    end
})







-- ── Block Destroyer ────────────────────────────────────────────────────────
-- The Objects controls are identical on every tab that can stamp geometry, so
-- they are built from one place instead of being copy-pasted per tab. Each tab
-- keeps its own scene name, matching the previous behaviour.


do
local saveFileName = "MyBuild"
selBoxOnly = false
selBoxPart = nil
selHandles = nil

blockSelMode = false
blockSelConn = nil
blockSelDown = false
selectedBlocks = {}
blockSelCount = 0

-- A block in this game can be a Model of several parts (grass has its surface,
-- a tree has trunk and branches). Clicking one part used to grab that part
-- alone, so you could pick a branch off a tree. Resolve to the whole thing.
brushRadius = 0        -- 0 = single block
brushSurface = false   -- click selects the connected flat surface
brushConnected = false -- click selects everything touching, in 3D

function resolveBlockRoot(part)
    local folder = brushScopeFolder()
    local node = part
    while node and node.Parent and node.Parent ~= folder and node.Parent ~= Workspace do
        node = node.Parent
    end
    return node or part
end

-- Containers holding hit volumes rather than anything you can see. A tree keeps
-- its trunk and leaves alongside a CollisionBoxes folder, and adorning the model
-- as a whole boxes all of it - which is why the highlight looked far bigger than
-- the tree.
local HITBOX_CONTAINERS = {
    CollisionBoxes = true, CollisionBox = true,
    Hitbox = true, Hitboxes = true, HitBox = true,
}

-- The parts actually worth outlining: visible geometry, no hit volumes.
function visualParts(root)
    local out = {}
    if not root then return out end
    -- A block can be a part that itself has parts under it: grass is a part
    -- with a Top child. Take the root when visible, then keep walking.
    if root:IsA("BasePart") and root.Transparency < 1 then
        out[#out + 1] = root
    end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("BasePart") and d.Transparency < 1 then
            local a, skip = d.Parent, false
            while a and a ~= root do
                if HITBOX_CONTAINERS[a.Name] then skip = true break end
                a = a.Parent
            end
            if not skip then out[#out + 1] = d end
        end
    end
    -- a block with nothing visible still needs something to show
    if #out == 0 and root:IsA("Model") then
        local p = root:FindFirstChildWhichIsA("BasePart", true)
        if p then out[1] = p end
    end
    return out
end

-- A block's world position, whether it is one part or a model of several.
function blockOrigin(inst)
    if not inst then return Vector3.new() end
    if inst:IsA("BasePart") then return inst.Position end
    local ok, cf = pcall(function() return inst:GetPivot() end)
    if ok and cf then return cf.Position end
    local p = inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position or Vector3.new()
end

-- Flood fill from a block. `plane` restricts the spread to one layer:
--   "y" - a floor, spreading sideways only
--   "x" / "z" - a wall, spreading along the wall and vertically
--   nil - free in all six directions
function floodSelect(part, plane, limit)
    local folder = brushScopeFolder()
    if not folder then return {} end
    -- Clicks land on whatever sub-part the ray hit ("Top" on grass, a branch on
    -- a tree). Everything below works in whole blocks, which is why picking a
    -- surface used to only catch on every so often.
    local root = resolveBlockRoot(part)
    local byCell, key = {}, function(x, y, z) return x .. "," .. y .. "," .. z end
    local function cellOf(v)
        return math.floor(v.X/3+0.5), math.floor(v.Y/3+0.5), math.floor(v.Z/3+0.5)
    end
    for _, b in ipairs(folder:GetChildren()) do
        if b:IsA("BasePart") or b:IsA("Model") then
            byCell[key(cellOf(blockOrigin(b)))] = b
        end
    end

    local sx, sy, sz = cellOf(blockOrigin(root))
    local wanted = root.Name
    local dirs
    if plane == "y" then
        dirs = { {1,0,0},{-1,0,0},{0,0,1},{0,0,-1} }
    elseif plane == "x" then
        dirs = { {0,0,1},{0,0,-1},{0,1,0},{0,-1,0} }
    elseif plane == "z" then
        dirs = { {1,0,0},{-1,0,0},{0,1,0},{0,-1,0} }
    else
        dirs = { {1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1} }
    end

    local queue, seen, out = { {sx,sy,sz} }, { [key(sx,sy,sz)] = true }, {}
    while #queue > 0 and #out < (limit or 4000) do
        local c = table.remove(queue)
        local b = byCell[key(c[1], c[2], c[3])]
        if b and b.Name == wanted then
            out[#out + 1] = b
            for _, d in ipairs(dirs) do
                local nk = key(c[1]+d[1], c[2]+d[2], c[3]+d[3])
                if not seen[nk] then
                    seen[nk] = true
                    queue[#queue + 1] = { c[1]+d[1], c[2]+d[2], c[3]+d[3] }
                end
            end
        end
    end
    -- a click should never come back empty-handed
    if #out == 0 then out[1] = root end
    return out
end

-- Which plane the clicked face lies in: a floor gives "y", a wall gives the
-- axis it faces along.
local function planeFromNormal(normal)
    if not normal then return "y" end
    local ax, ay, az = math.abs(normal.X), math.abs(normal.Y), math.abs(normal.Z)
    if ay >= ax and ay >= az then return "y" end
    if ax >= az then return "x" end
    return "z"
end

-- Everything a single brush stroke should affect at this point.
function brushTargets(part, normal)
    if brushConnected then return floodSelect(part, nil) end
    if brushSurface then return floodSelect(part, planeFromNormal(normal)) end
    local root = resolveBlockRoot(part)
    if brushRadius <= 0 then return { root } end
    local folder = brushScopeFolder()
    local out = {}
    if not folder then return { root } end
    local origin = blockOrigin(root)
    local r = brushRadius * 3
    for _, b in ipairs(folder:GetChildren()) do
        if (b:IsA("BasePart") or b:IsA("Model"))
            and (blockOrigin(b) - origin).Magnitude <= r then
            out[#out + 1] = b
        end
    end
    if #out == 0 then out[1] = root end
    return out
end

function highlightBlock(part)
    part = resolveBlockRoot(part)
    if selectedBlocks[part] then return end
    -- One box per visible piece, so grass takes its Top with it and a tree is
    -- outlined around trunk and leaves instead of its collision volume.
    local boxes = {}
    for _, piece in ipairs(visualParts(part)) do
        local h = Instance.new("SelectionBox")
        h.Adornee = piece
        h.Color3 = Color3.fromRGB(0, 255, 255)
        h.LineThickness = 0.04
        h.SurfaceColor3 = Color3.fromRGB(0, 255, 255)
        h.SurfaceTransparency = 0.65
        h.Parent = piece
        boxes[#boxes + 1] = h
    end
    if #boxes == 0 then return end
    selectedBlocks[part] = boxes
    blockSelCount = blockSelCount + 1
end

function unhighlightBlock(part)
    part = resolveBlockRoot(part)
    local boxes = selectedBlocks[part]
    if not boxes then return end
    for _, h in ipairs(boxes) do pcall(function() h:Destroy() end) end
    selectedBlocks[part] = nil
    blockSelCount = blockSelCount - 1
end

function clearBlockSelection()
    for part, boxes in pairs(selectedBlocks) do
        if type(boxes) == "table" then
            for _, h in ipairs(boxes) do pcall(function() h:Destroy() end) end
        elseif boxes then
            pcall(function() boxes:Destroy() end)
        end
    end
    selectedBlocks = {}
    blockSelCount = 0
end

-- Take the current selection out of the ghost. The parts go now so the change
-- is visible, and the file positions are remembered so Start Build leaves them
-- out too. Returns how many blocks were dropped.
function deleteSelectedFromPreview()
    local gone = 0
    for part in pairs(selectedBlocks) do
        local key = part:GetAttribute("SrcKey")
        if key then
            if not previewOmitted[key] then
                previewOmitted[key] = true
                previewOmittedCount = previewOmittedCount + 1
            end
            gone = gone + 1
        end
    end
    clearBlockSelection()
    -- destroy after clearing, so the SelectionBoxes parented to them are
    -- already gone and nothing is left adorning a dead part
    if previewModel and previewModel.Parent then
        for _, d in ipairs(previewModel:GetChildren()) do
            local key = d:GetAttribute("SrcKey")
            if key and previewOmitted[key] then pcall(function() d:Destroy() end) end
        end
    end
    if lastPreviewBlocks then
        lastPreviewBlocks = dropOmittedBlocks(lastPreviewBlocks)
    end
    return gone
end

-- Put everything deleted from the preview back into the build.
function restorePreviewDeletions()
    local n = previewOmittedCount
    previewOmitted = {}
    previewOmittedCount = 0
    return n
end

task.spawn(function()
    while true do
        local a = (math.sin(tick() * 1.8) + 1) / 2
        local fill = 0.45 + a * 0.35
        for part, h in pairs(selectedBlocks) do
            if h and h.Parent then h.SurfaceTransparency = fill end
        end
        task.wait(0.03)
    end
end)

function blockUnderCursor()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local mp = UserInputService:GetMouseLocation()
    local ray = cam:ViewportPointToRay(mp.X, mp.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    local folder = brushScopeFolder()
    if not folder then return nil end
    params.FilterDescendantsInstances = { folder }
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
    if hit and hit.Instance and hit.Instance:IsA("BasePart") then
        local n = resolveBlockRoot(hit.Instance).Name
        -- the ghost's own scaffolding is not a block you can paint
        if n ~= "bedrock" and n ~= "portalToSpawn"
            and n ~= "PreviewRoot" and n ~= "PreviewBBox" then
            -- the face normal tells Surface Select whether it is looking at a
            -- floor or a wall
            return hit.Instance, hit.Normal
        end
    end
    return nil
end

function partToBlockEntry(part)
    local cf = part.CFrame
    local p = cf.Position
    local r = cf.RightVector
    local u = cf.UpVector

    -- The old test here was `part.Size.Y < 2.9`, which no Islands block ever
    -- satisfies - every one of them is a 3x3x3 part - so upperBlock came back
    -- false for every slab ever saved, and top slabs were quietly lost.
    local upper = false
    local half = slabHalfOf(part)
    if half == "top" then upper = true end
    return {
        blockType = part.Name,
        upperBlock = upper,
        cframe = { p.X, p.Y, p.Z, r.X, r.Y, r.Z, u.X, u.Y, u.Z },
        parts = {},
    }
end

function finishSaveBlocks(blocks, nameOverride)
    if #blocks == 0 then
        notify("Save Failed", "No blocks found to save", 4)
        return
    end

    if not isfolder("autoBuilder") then makefolder("autoBuilder") end
    local name = nameOverride
    if not name or name == "" then name = saveFileName end
    if not (name:lower():sub(-5) == ".json" or name:lower():sub(-4) == ".txt") then
        name = name .. ".json"
    end
    local ok, err = pcall(function()
        writefile("autoBuilder/" .. name, HttpService:JSONEncode({ blocks = blocks }))
    end)
    if ok then
        sendSaveWebhook(name)
        saveAlignment(name, CFrame.new())
        fileDropdown:Refresh(getFiles(), true)
        notify("Build Saved", #blocks .. " blocks -> " .. name, 6)
    else
        notify("Save Failed", "Could not write file: " .. tostring(err), 5)
    end
end

function saveSelectedBrush()
    local blocks = {}
    for part, _ in pairs(selectedBlocks) do
        if part and part.Parent then
            blocks[#blocks + 1] = partToBlockEntry(part)
        end
    end
    finishSaveBlocks(blocks)
end

local function selBounds()
    if not selBoxPart or not selBoxPart.Parent then return nil end
    local half = selBoxPart.Size / 2
    local c = selBoxPart.Position
    return c - half, c + half
end

local function inSelectionBox(pos)
    local minv, maxv = selBounds()
    if not minv then return true end
    return pos.X >= minv.X and pos.X <= maxv.X
        and pos.Y >= minv.Y and pos.Y <= maxv.Y
        and pos.Z >= minv.Z and pos.Z <= maxv.Z
end

local function hideSelBox()
    if selHandles then selHandles:Destroy() selHandles = nil end
    if selBoxPart then selBoxPart:Destroy() selBoxPart = nil end
end

-- Place the box by clicking, rather than dropping it on the player. It used to
-- appear inside your own character, which is almost never where you want it,
-- so the first click after turning it on puts it where you are pointing.
local function placeSelBoxAtCursor()
    if not selBoxPart or not selBoxPart.Parent then return false end
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local mp = UserInputService:GetMouseLocation()
    local ray = cam:ViewportPointToRay(mp.X, mp.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { selBoxPart }
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    if char then ignore[#ignore + 1] = char end
    local ghost = Workspace:FindFirstChild(previewFolderName)
    if ghost then ignore[#ignore + 1] = ghost end
    params.FilterDescendantsInstances = ignore

    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
    local pos = hit and hit.Position
        or (ray.Origin + ray.Direction * 60)
    -- sit the box on what was clicked rather than half-sunk into it
    selBoxPart.CFrame = CFrame.new(pos + Vector3.new(0, selBoxPart.Size.Y / 2, 0))
    return true
end

local function showSelBox()
    hideSelBox()
    local _, _, hrp = getCharacterParts()
    local pos = hrp and hrp.Position or Vector3.new(0, 50, 0)

    selBoxPart = Instance.new("Part")
    selBoxPart.Name = "SelectionBox_AB"
    selBoxPart.Anchored = true
    selBoxPart.CanCollide = false
    selBoxPart.CanQuery = false
    selBoxPart.CanTouch = false
    selBoxPart.CastShadow = false
    selBoxPart.Material = Enum.Material.Neon
    selBoxPart.Color = Color3.fromRGB(0, 255, 255)
    selBoxPart.Transparency = 0.55
    selBoxPart.Size = Vector3.new(48, 48, 48)
    selBoxPart.CFrame = CFrame.new(pos)
    selBoxPart.Parent = Workspace

    local selOutline = Instance.new("SelectionBox")
    selOutline.Adornee = selBoxPart
    selOutline.Color3 = Color3.fromRGB(0, 255, 255)
    selOutline.LineThickness = 0.06
    selOutline.SurfaceColor3 = Color3.fromRGB(0, 255, 255)
    selOutline.SurfaceTransparency = 0.85
    selOutline.Parent = selBoxPart

    task.spawn(function()
        while selBoxPart and selBoxPart.Parent do
            local t = tick() * 1.6
            local a = (math.sin(t) + 1) / 2
            selBoxPart.Transparency = 0.45 + a * 0.35
            RunService.Heartbeat:Wait()
        end
    end)

    selHandles = Instance.new("Handles")
    selHandles.Adornee = selBoxPart
    selHandles.Style = Enum.HandlesStyle.Resize
    selHandles.Color3 = Color3.fromRGB(120, 200, 255)
    local guiHost = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    selHandles.Parent = guiHost

    -- Roblox's own Resize keeps the opposite face anchored and moves the part
    -- for you, which is both simpler and more accurate than recomputing the
    -- CFrame by hand. Deltas are accumulated so a drag steps block by block.
    local prevDistance = 0
    selHandles.MouseButton1Down:Connect(function()
        prevDistance = 0
    end)
    selHandles.MouseDrag:Connect(function(face, distance)
        local delta = distance - prevDistance
        if math.abs(delta) < 3 then return end
        local step = math.floor(delta / 3 + 0.5) * 3
        if step == 0 then return end
        local oldSize, oldPos = selBoxPart.Size, selBoxPart.Position
        if selBoxPart:Resize(face, step) then
            -- never let a face collapse past one block
            if selBoxPart.Size.X < 3 or selBoxPart.Size.Y < 3 or selBoxPart.Size.Z < 3 then
                selBoxPart.Size, selBoxPart.Position = oldSize, oldPos
            end
            prevDistance = distance
        end
    end)
    selHandles.MouseButton1Up:Connect(function()
        prevDistance = 0
    end)
end

-- The Show Selection Box toggle is built at the top of the tab, above these
-- definitions, so it reaches them through here.
BuilderAPI.showSelBox = showSelBox
BuilderAPI.hideSelBox = hideSelBox

-- One click after switching the box on drops it where you point. It is a
-- one-shot rather than a mode, so it cannot get in the way of the resize
-- handles afterwards.
local selBoxArm = nil
BuilderAPI.armSelBoxPlacement = function()
    if selBoxArm then selBoxArm:Disconnect() selBoxArm = nil end
    selBoxArm = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if placeSelBoxAtCursor() then
            notify("Box Placed", "Drag the face handles to resize it", 4, "info")
        end
        if selBoxArm then selBoxArm:Disconnect() selBoxArm = nil end
    end)
end

-- Everything the box contains, in the ghost preview. The brush can already
-- trim a preview block by block; this does the same job to a whole region at
-- once, which is what the box is for.
BuilderAPI.selectPreviewInBox = function(erase)
    if not selBoxPart or not selBoxPart.Parent then
        notifyWarn("Selection Box", "Turn Show Selection Box on and place it first", 4)
        return 0
    end
    local model = previewModel
    if not model or not model.Parent then
        notifyWarn("Selection Box", "Preview a build or model first", 4)
        return 0
    end
    local n = 0
    for _, d in ipairs(model:GetChildren()) do
        if d.Name ~= "PreviewRoot" and d.Name ~= "PreviewBBox" then
            local ok, pos = pcall(function()
                return d:IsA("BasePart") and d.Position or d:GetPivot().Position
            end)
            if ok and pos and inSelectionBox(pos) then
                if erase then unhighlightBlock(d) else highlightBlock(d) end
                n = n + 1
            end
        end
    end
    return n
end

-- Right column runs Preview, Image, Save; Image is built last but sits above
-- Save, so all three are ordered explicitly.
previewTab:CreateSection("Preview", { Collapsible = true, Column = "right", Order = 0 })

BuilderAPI.toggles.preview = previewTab:CreateToggle({
    Name = "Preview Build",
    CurrentValue = false,
    Flag = "PreviewToggle",
    -- The brick icon opens the block list; the gear holds the settings. Neither
    -- needs a preview running, so you can check what a build needs first.
    GearAction = {
        Icon = "bricks",
        OnClick = function()
            local ok = pcall(function() BuilderAPI.previewPanel:Toggle() end)
            if not ok then notifyWarn("Blocks Needed", "Not ready yet", 3) end
        end,
    },
    Gear = {
        { Type = "toggle", Name = "Use Real Models", Default = true,
          Callback = function(v) previewRealModels = v end },
        { Type = "toggle", Name = "Low-Lag Preview", Default = false,
          Callback = function(v) previewMinimized = v end },
        { Type = "toggle", Name = "Include Stairs", Default = true,
          Callback = function(v) includeStairs = v end },
        { Type = "toggle", Name = "Include Slabs", Default = true,
          Callback = function(v) includeSlabs = v end },
        { Type = "toggle", Name = "No Interior", Default = false,
          Callback = function(v)
            noInterior = v
            if v then notify("No Interior", "Turn the preview off and on to redraw it", 5, "info") end
          end },
        { Type = "slider", Name = "Transparency", Min = 0, Max = 90, Default = 50,
          Callback = function(v)
            previewTransparency = v / 100
            local folder = Workspace:FindFirstChild(previewFolderName)
            if folder then
                for _, part in ipairs(folder:GetDescendants()) do
                    if part:IsA("BasePart") and part:GetAttribute("GhostPreview") then
                        part.Transparency = previewTransparency
                    end
                end
            end
            if previewTransparency > 0 and brushPreview then
                brushPreview = false
                pcall(function() BuilderAPI.setPreviewQueryable(false) end)
                pcall(function() BuilderAPI.toggles.brushPreview:Set(false) end)
                notifyWarn("Brush Preview", "Off - the ghost is see-through again", 4)
            end
          end },
        { Type = "button", Name = "Rotate 90", OnClick = function()
            if not previewModel or not previewModel.Parent then
                notify("Nothing to Turn", "Turn the preview on first", 3)
                return
            end
            rotatePreview(90)
            notify("Rotated", "Turned 90 degrees", 2)
        end },
    },
    Callback = function(v)
        if v then
            local data = loadSelectedBuild()
            if not data then
                notify("No File", "Pick a build file first", 3)
                return
            end
            task.spawn(function()
                previewBuild(filterShapes(hollowExterior(dedupeBlocks(dropOmittedBlocks(data.blocks)))))
            end)
        else
            clearPreview()
            -- the ghost the brush was painting is gone with it
            if brushPreview then
                brushPreview = false
                clearBlockSelection()
                pcall(function() BuilderAPI.toggles.brushPreview:Set(false) end)
            end
            notify("Preview Off", "Ghost blocks removed", 2)
        end
    end
})

-- Move Handles rides directly under the toggle it belongs to, rather than being
-- buried in the panel.
BuilderAPI.toggles.handles = previewTab:CreateToggle({
    Name = "Move Handles",
    CurrentValue = false,
    Flag = "PreviewDrag",
    Tooltip = "Shows arrows you can drag to slide the preview where you want it.",
    Callback = function(v) setDragMode(v) end
})


-- Objects controls live on the Auto Build tab; this tab used an identical copy.


-- declared before use: the required-blocks scan refreshes these
local buildTypeDropdown, invBlockDropdown
-- Lives on the Preview panel now, alongside the scan button.
local requiredBlocksParagraph = { Set = function() end }

task.spawn(function()
    task.wait(1)
    pcall(function()
        local host = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
        local rf = host:FindFirstChild("Duvome")
        if rf then
            for _, d in ipairs(rf:GetDescendants()) do
                if d:IsA("TextLabel") then d.RichText = true end
            end
        end
    end)
end)

-- Exposed so the Preview panel's button can run the same scan.
BuilderAPI.scanRequired = function()
    -- open the panel so the result is actually visible when this is fired
    -- from the tab rather than from inside the panel
    pcall(function()
        if not BuilderAPI.previewPanel:IsOpen() then BuilderAPI.previewPanel:Show() end
    end)
    local blocks = lastPreviewBlocks
    if not blocks then
        local data = loadSelectedBuild()
        if not data then return end
        blocks = data.blocks
    end

    task.spawn(function()
        notify("Scanning", "Checking what's still missing...", 3)
        local _, missing = getPlacedAndMissingBlocks(blocks)

        if #missing == 0 then
            requiredBlocksList = {}
            if BuilderAPI.renderRequired then BuilderAPI.renderRequired("Nothing missing - all blocks are already placed.") end
            notify("Done", "Nothing missing", 3)
            return
        end

        local text = getRequiredBlocksText(missing)
        if BuilderAPI.renderRequired then BuilderAPI.renderRequired(text) end
        -- fill the replace pickers now, so Refresh is not a separate step
        pcall(function()
            buildTypeDropdown:Refresh(getBuildTypeOptions(), true)
            invBlockDropdown:Refresh(getInventoryOptions(), true)
        end)
        notify("Done", "Still need " .. #missing .. " block(s)", 4)
    end)
end

local buildTypeMap = {}
local invTypeMap = {}
local replaceFromType = nil
local replaceToType = nil
-- replacements now show inline in the required list; this stub keeps the
-- existing :Set calls harmless
local replaceListParagraph = { Set = function() end }

local function getBuildTypeOptions()
    buildTypeMap = {}
    local opts = {}
    local seen = {}
    local blocks = lastPreviewBlocks
    if not blocks then
        local d = loadSelectedBuild()
        blocks = d and d.blocks
    end
    if blocks then
        for _, b in ipairs(blocks) do
            local internal = tostring(b.blockType)
            if not seen[internal] then
                seen[internal] = true
                local disp = resolveBlockDisplayName(internal)
                buildTypeMap[disp] = internal
                table.insert(opts, disp)
            end
        end
    end
    table.sort(opts)
    if #opts == 0 then table.insert(opts, "Preview/select a build first") end
    return opts
end

local function getInventoryOptions()
    invTypeMap = {}
    local opts = {}
    local seen = {}
    local function add(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and not seen[item.Name] then
                seen[item.Name] = true
                local disp = resolveBlockDisplayName(item.Name)
                invTypeMap[disp] = item.Name
                table.insert(opts, disp)
            end
        end
    end
    add(LocalPlayer:FindFirstChild("Backpack"))
    add(LocalPlayer.Character)
    table.sort(opts)
    if #opts == 0 then table.insert(opts, "No items") end
    return opts
end

local function replacementsText()
    local lines = {}
    for from, to in pairs(blockReplacements) do
        table.insert(lines, resolveBlockDisplayName(from) .. "  ->  " .. resolveBlockDisplayName(to))
    end
    if #lines == 0 then return "No replacements set." end
    return table.concat(lines, "\n")
end

buildTypeDropdown = previewTab:CreateDropdown({
    Name = "Replace Block",
    -- refresh belongs with the list it refreshes, not behind a gear
    Actions = { { Text = "Refresh", OnClick = function()
        buildTypeDropdown:Refresh(getBuildTypeOptions(), true)
        invBlockDropdown:Refresh(getInventoryOptions(), true)
        notify("Refreshed", "Build & inventory lists updated", 2)
    end } },
    Options = getBuildTypeOptions(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(option)
        local disp = (typeof(option) == "table") and option[1] or option
        replaceFromType = buildTypeMap[disp]
    end
})

invBlockDropdown = previewTab:CreateDropdown({
    Name = "With Block",
    -- Refresh lists what you are carrying. All Blocks lists everything the
    -- game has, for planning a swap to something you have not got yet.
    Actions = {
        { Text = "Refresh", OnClick = function()
            buildTypeDropdown:Refresh(getBuildTypeOptions(), true)
            invBlockDropdown:Refresh(getInventoryOptions(), true)
            notify("Refreshed", "Back to the blocks you are carrying", 3)
        end },
        { Text = "All Blocks", OnClick = function()
            local pal = BuilderAPI.blockPalette
            if not pal or #pal == 0 then
                notifyWarn("All Blocks", "The block list is not ready yet", 4)
                return
            end
            invTypeMap = {}
            local opts = {}
            for _, blockName in ipairs(pal) do
                local disp = resolveBlockDisplayName(blockName)
                if not invTypeMap[disp] then
                    invTypeMap[disp] = blockName
                    opts[#opts + 1] = disp
                end
            end
            table.sort(opts)
            invBlockDropdown:Refresh(opts, true)
            notify("All Blocks", #opts .. " blocks listed - Refresh goes back to yours", 5, "info")
        end },
    },
    Options = getInventoryOptions(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(option)
        local disp = (typeof(option) == "table") and option[1] or option
        replaceToType = invTypeMap[disp]
    end
})

previewTab:CreateButton({
    Name = "Add Replacement",
    Gear = { { Type = "button", Name = "Clear Replacements", OnClick = function()
        blockReplacements = {}
        replaceListParagraph:Set({ Title = "Current Replacements", Content = "No replacements set." })
        if lastPreviewBlocks then
            pcall(function()
                local t = getRequiredBlocksText(lastPreviewBlocks)
                if BuilderAPI.renderRequired then BuilderAPI.renderRequired(t) end
            end)
        end
        notify("Cleared", "All replacements removed", 3)
    end } },
    Callback = function()
        if not replaceFromType or not replaceToType then
            notify("Pick Both", "Choose a build block and an inventory block", 3)
            return
        end
        blockReplacements[replaceFromType] = replaceToType
        replaceListParagraph:Set({ Title = "Current Replacements", Content = replacementsText() })
        if lastPreviewBlocks then
            pcall(function()
                local t = getRequiredBlocksText(lastPreviewBlocks)
                if BuilderAPI.renderRequired then BuilderAPI.renderRequired(t) end
            end)
        end
        notify("Replacement Added", resolveBlockDisplayName(replaceFromType) .. " -> " .. resolveBlockDisplayName(replaceToType), 4)
    end
})


saveTab:CreateSection("Save", { Collapsible = true, Column = "right", Order = 2 })

saveTab:CreateInput({
    Name = "Build Name",
    PlaceholderText = "MyBuild",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text and text ~= "" then
            saveFileName = text
        end
    end
})



-- Declared up here because saveIslandBuild reads it: naming a local before it
-- exists compiles as a global lookup, and the box would be quietly ignored.
local saveTarget = "Whole Island"

local function saveIslandBuild()
    local island = getNearestIsland()
    if not island then
        notify("Save Failed", "No island found near you", 4)
        return
    end
    local blocksFolder = island:FindFirstChild("Blocks")
    if not blocksFolder then
        notify("Save Failed", "Island has no Blocks folder", 4)
        return
    end

    updateGridPhase(true)

    local blocks = {}
    local children = blocksFolder:GetChildren()
    for i, part in ipairs(children) do
        if part:IsA("BasePart") and part.Name ~= "bedrock" and part.Name ~= "portalToSpawn" then
            local include = true
            if selBoxOnly and saveTarget == "Inside Selection Box" then
                include = inSelectionBox(part.Position)
            end
            if include then
                blocks[#blocks + 1] = partToBlockEntry(part)
            end
        end
        if i % 3000 == 0 then task.wait() end
    end

    finishSaveBlocks(blocks)
end

saveTab:CreateDropdown({
    Name = "Save Target",
    -- Replaces the old Full/Half/Quarter mirror modes. What gets saved is
    -- decided by the tools you already point at things with - the selection
    -- box and the brush - rather than by a separate splitting mode.
    Options = { "Whole Island", "Inside Selection Box", "Brush Selection",
                "Model or Schematic", "Image" },
    CurrentOption = { "Whole Island" },
    MultipleOptions = false,
    Flag = "SaveTarget",
    Tooltip = "What the Save button saves. The box option needs the selection box turned on. The brush option needs blocks picked with the brush. Model saves the model you picked as a build file.",
    Callback = function(v)
        saveTarget = (typeof(v) == "table") and v[1] or v
    end
})

saveTab:CreateButton({
    Name = "Save",
    Tooltip = "Saves it as a build file, named whatever you put in Build Name.",
    Callback = function()
        task.spawn(function()
            if saveTarget == "Brush Selection" then
                if blockSelCount == 0 then
                    notifyWarn("Save", "Paint some blocks with the Block Brush first", 4)
                    return
                end
                saveSelectedBrush()
            elseif saveTarget == "Image" then
                if not BuilderAPI.generateImage then
                    notifyWarn("Save", "Image tool not ready", 4)
                    return
                end
                BuilderAPI.generateImage(saveFileName)
            elseif saveTarget == "Model or Schematic" then
                -- a model is already a block list by the time it is previewed;
                -- saving it just writes that out as an ordinary build file
                if not MODEL or not MODEL.selected then
                    notifyWarn("Save", "Pick a model in the Model section first", 4)
                    return
                end
                local data = loadSelectedBuild()
                if not data or not data.blocks then return end
                -- through the shared path, so it is mirrored to the webhook
                -- and listed like any other save rather than quietly written
                local name = saveFileName
                if not name or name == "" then
                    name = MODEL.selected:gsub("%.[Gg][Ll][Bb]$", "")
                end
                finishSaveBlocks(data.blocks, name)
            elseif saveTarget == "Inside Selection Box" then
                if not selBoxOnly then
                    notifyWarn("Save", "Turn Show Selection Box on and place it first", 4)
                    return
                end
                notify("Saving", "Scanning blocks inside the box...", 3)
                saveIslandBuild()
            else
                notify("Saving", "Scanning island blocks...", 3)
                saveIslandBuild()
            end
        end)
    end
})

end







do

local structRadius = 30
local structWidth = 30
local structHeight = 30
local structSmooth = 25
local structSeed = 1
local structMode = "Sphere"
local structHollow = true
local structFillSteps = false
local structThickness = 1
local structTurns = 2

local structHeightmap = nil
local structWaterLevel = nil
local terraBrush = 12
local terraStrength = 3
local terraMode = "Raise"
local structPointTypes = {}
local structRX, structRY, structRZ = 0, 0, 0
local structSelectedBlock = "grass"
local structFileName = "MyStructure"

local function snap3local(v)
    return math.floor(v / 3 + 0.5) * 3
end

local function structGetPoints()
    local pts = {}
    local seen = {}
    structPointTypes = {}
    local baseCF = CFrame.Angles(math.rad(structRX), math.rad(structRY), math.rad(structRZ))
    local R = structRadius
    local W = math.max(structWidth, 3)
    local H = structHeight
    local T = math.max(3, structThickness * 3)

    local function add(lPos)
        local w = (baseCF * CFrame.new(lPos)).Position
        local s = Vector3.new(snap3local(w.X), snap3local(w.Y), snap3local(w.Z))
        local key = s.X .. "_" .. s.Y .. "_" .. s.Z
        if not seen[key] then
            seen[key] = true
            table.insert(pts, s)
        end
    end

    local function addTyped(lPos, blockType)
        local w = (baseCF * CFrame.new(lPos)).Position
        local s = Vector3.new(snap3local(w.X), snap3local(w.Y), snap3local(w.Z))
        local key = s.X .. "_" .. s.Y .. "_" .. s.Z
        if not seen[key] then
            seen[key] = true
            table.insert(pts, s)
            structPointTypes[key] = blockType
        end
    end

    local function isShell(inside, x, y, z, axes)
        if not inside(x, y, z) then return false end
        if axes ~= "xz" then
            if not inside(x, y + T, z) or not inside(x, y - T, z) then return true end
        end
        return not inside(x + T, y, z) or not inside(x - T, y, z)
            or not inside(x, y, z + T) or not inside(x, y, z - T)
    end

    local xr = R / W
    local function emit(inside, bx0, bx1, by0, by1, bz0, bz1, axes)
        for x = -W, W, 3 do
            local sx = x * xr
            for y = by0, by1, 3 do
                for z = bz0, bz1, 3 do
                    if structHollow then
                        local function ins(ax, ay, az) return inside(ax, ay, az) end
                        local here = ins(sx, y, z)
                        if here then
                            local shell = false
                            if axes ~= "xz" and (not ins(sx, y + T, z) or not ins(sx, y - T, z)) then shell = true end
                            if not shell and (not ins(sx + T * xr, y, z) or not ins(sx - T * xr, y, z)
                                or not ins(sx, y, z + T) or not ins(sx, y, z - T)) then shell = true end
                            if shell then add(Vector3.new(x, y, z)) end
                        end
                    elseif inside(sx, y, z) then
                        add(Vector3.new(x, y, z))
                    end
                end
            end
            task.wait()
        end
    end

    if structMode == "Landscape" then
        local grid = structHeightmap
        if not grid then
            grid = {}
            for x = -W, W, 3 do
                grid[x] = {}
                for z = -R, R, 3 do
                    local nV = math.noise(x / structSmooth, z / structSmooth, structSeed)
                    grid[x][z] = math.floor((nV * H) / 3) * 3
                end
            end
            structHeightmap = grid
        end

        for x = -W, W, 3 do
            if grid[x] then
            for z = -R, R, 3 do
                local yH = grid[x][z]
                if yH then
                if structHollow then
                    add(Vector3.new(x, yH, z))
                    if structFillSteps or structHeightmap then
                        if grid[x + 3] and grid[x + 3][z] then
                            local yN = grid[x + 3][z]
                            for fY = math.min(yH, yN), math.max(yH, yN), 3 do add(Vector3.new(x, fY, z)) end
                        end
                        if grid[x][z + 3] then
                            local yN = grid[x][z + 3]
                            for fY = math.min(yH, yN), math.max(yH, yN), 3 do add(Vector3.new(x, fY, z)) end
                        end
                    end
                else
                    for y = math.min(0, yH), math.max(0, yH), 3 do add(Vector3.new(x, y, z)) end
                end

                if structWaterLevel and yH < structWaterLevel then
                    for wy = yH + 3, structWaterLevel, 3 do
                        addTyped(Vector3.new(x, wy, z), "water")
                    end
                end
                end
            end
            end
        end

    elseif structMode == "Sphere" then
        local function inside(x, y, z) return x * x + y * y + z * z <= R * R end
        emit(inside, -R, R, -R, R, -R, R)

    elseif structMode == "Dome" then
        local function inside(x, y, z) return x * x + y * y + z * z <= R * R end
        emit(inside, -R, R, 0, R, -R, R)

    elseif structMode == "Cylinder" then
        local function inside(x, y, z)
            return (x * x + z * z <= R * R) and y >= 0 and y <= H
        end
        emit(inside, -R, R, 0, H, -R, R)

    elseif structMode == "Tube / Wall" then
        local function inside(x, _, z) return x * x + z * z <= R * R end
        emit(inside, -R, R, 0, H, -R, R, "xz")

    elseif structMode == "Cone" then
        local function inside(x, y, z)
            if y < 0 or y > H then return false end
            local rr = R * (1 - y / math.max(H, 1))
            return x * x + z * z <= rr * rr
        end
        emit(inside, -R, R, 0, H, -R, R)

    elseif structMode == "Pyramid" then
        local function inside(x, y, z)
            if y < 0 or y > H then return false end
            local rr = R * (1 - y / math.max(H, 1))
            return math.abs(x) <= rr and math.abs(z) <= rr
        end
        emit(inside, -R, R, 0, H, -R, R)

    elseif structMode == "Torus (Ring)" then
        local tube = math.max(T, 3)
        local function inside(x, y, z)
            local q = math.sqrt(x * x + z * z) - R
            return q * q + y * y <= tube * tube
        end
        emit(inside, -(R + tube), R + tube, -tube, tube, -(R + tube), R + tube)

    elseif structMode == "Box" then
        local function inside(x, y, z)
            return math.abs(x) <= R and math.abs(z) <= R and y >= 0 and y <= H
        end
        emit(inside, -R, R, 0, H, -R, R)

    elseif structMode == "Octahedron" then
        local function inside(x, y, z)
            return math.abs(x) + math.abs(y) + math.abs(z) <= R
        end
        emit(inside, -R, R, -R, R, -R, R)

    elseif structMode == "Spiral Stairs" then
        local turns = math.max(structTurns, 0.25)
        local totalDeg = 360 * turns
        local steps = math.max(math.floor(H / 3), 1)
        for i = 0, steps do
            local t = i / steps
            local ang = math.rad(totalDeg * t)
            local y = i * 3
            for rr = math.max(R - T, 0), R, 3 do
                add(Vector3.new(math.cos(ang) * rr, y, math.sin(ang) * rr))
            end
        end

    elseif structMode == "Square Floor" then
        for x = -R, R, 3 do
            for z = -R, R, 3 do
                local edge = (math.abs(x) >= R - 1.5) or (math.abs(z) >= R - 1.5)
                if not structHollow or edge then add(Vector3.new(x, 0, z)) end
            end
        end

    elseif structMode == "Circle" then
        local step = math.max(0.5, 30 / math.max(R / 3, 1))
        for d = 0, 360, step do
            local r = math.rad(d)
            if not structHollow then
                for i = 0, R, 3 do add(Vector3.new(math.cos(r) * i, 0, math.sin(r) * i)) end
            else
                add(Vector3.new(math.cos(r) * R, 0, math.sin(r) * R))
            end
        end
    end

    return pts
end

local function structFetchBlocks()
    local seen, b = {}, {}
    local function addName(n)
        if n and n ~= "" and not seen[n] then
            seen[n] = true
            table.insert(b, n)
        end
    end

    local f = ReplicatedStorage:FindFirstChild("blocks")
    if not f then
        for _, d in ipairs(ReplicatedStorage:GetChildren()) do
            if d:FindFirstChild("blocks") then f = d.blocks break end
        end
    end
    if f then
        for _, v in ipairs(f:GetChildren()) do addName(v.Name) end
    end

    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then addName(item.Name) end
        end
    end
    if LocalPlayer.Character then
        for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
            if item:IsA("Tool") then addName(item.Name) end
        end
    end

    table.sort(b)
    if #b == 0 then table.insert(b, "grass") end
    return b
end

local structPreviewFolderName = "StructureLivePreview"
local structShowPreview = false
local structOrigin = nil
local structHandles = nil
local structRenderToken = 0

local function structClearPreview()
    local existing = Workspace:FindFirstChild(structPreviewFolderName)
    if existing then existing:Destroy() end
end

local function structEnsureOrigin()
    if structOrigin and structOrigin.Parent then return structOrigin end
    updateGridPhase()
    local _, _, hrp = getCharacterParts()
    local base = hrp and (hrp.Position + Vector3.new(0, 8, 0)) or Vector3.new(0, 50, 0)
    structOrigin = Instance.new("Part")
    structOrigin.Name = "StructureOrigin"
    structOrigin.Size = Vector3.new(4, 4, 4)
    structOrigin.CFrame = CFrame.new(snapGridVec(base))
    structOrigin.Anchored = true
    structOrigin.CanCollide = false
    structOrigin.CanQuery = false
    structOrigin.CastShadow = false
    structOrigin.Transparency = 0.35
    structOrigin.Material = Enum.Material.Neon
    structOrigin.Color = Color3.fromRGB(255, 60, 60)
    structOrigin.Parent = Workspace
    return structOrigin
end

local function structRenderPreview()
    structClearPreview()
    if not structShowPreview then return end

    local origin = structEnsureOrigin()
    structRenderToken = structRenderToken + 1
    local myToken = structRenderToken

    local folder = Instance.new("Folder")
    folder.Name = structPreviewFolderName
    folder.Parent = Workspace

    task.spawn(function()
        local pts = structGetPoints()
        if myToken ~= structRenderToken or not folder.Parent then
            if folder.Parent then folder:Destroy() end
            return
        end

        local originCF = origin.CFrame
        local work = 0
        for _, lp in ipairs(pts) do
            if myToken ~= structRenderToken or not folder.Parent then break end
            local wPos = snapGridVec((originCF * CFrame.new(lp)).Position)
            local p = Instance.new("Part")
            p.Size = Vector3.new(3, 3, 3)
            p.CFrame = CFrame.new(wPos)
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = true
            p.CanTouch = false
            p.CastShadow = false
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(255, 120, 0)
            p.Transparency = 0.7
            p.Parent = folder

            work = work + 1
            if work >= 400 then
                work = 0
                task.wait()
            end
        end
    end)
end

local structDirty = false
local function structRefreshPreview()
    if not structShowPreview then return end
    if structDirty then return end
    structDirty = true
    task.delay(0.15, function()
        structDirty = false
        structRenderPreview()
    end)
end
BuilderAPI.structRefresh = structRefreshPreview

local function structUpdatePreviewLive()
    if not structShowPreview then return end
    local origin = structEnsureOrigin()
    local folder = Workspace:FindFirstChild(structPreviewFolderName)
    if not folder then
        structRenderPreview()
        return
    end

    local pts = structGetPoints()
    local originCF = origin.CFrame

    local pool = {}
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("BasePart") then pool[#pool + 1] = c end
    end

    local idx = 0
    for _, lp in ipairs(pts) do
        idx = idx + 1
        local wPos = snapGridVec((originCF * CFrame.new(lp)).Position)
        local p = pool[idx]
        if p then
            p.CFrame = CFrame.new(wPos)
            p.Transparency = 0.7
        else
            p = Instance.new("Part")
            p.Size = Vector3.new(3, 3, 3)
            p.CFrame = CFrame.new(wPos)
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = true
            p.CanTouch = false
            p.CastShadow = false
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(255, 120, 0)
            p.Transparency = 0.7
            p.Parent = folder
        end
    end
    for i = idx + 1, #pool do
        pool[i].Transparency = 1
        pool[i].CFrame = CFrame.new(0, -10000, 0)
    end
end

structTab:CreateParagraph({
    Title = "Structures",
    Content = "Turn on Live Preview to see the shape and watch it change as you move the sliders. Move it with the arrows, then Generate Build File to save."
})

structTab:CreateToggle({
    Name = "Live Preview",
    CurrentValue = false,
    Flag = "StructLivePreview",
    Gear = {
        { Type = "toggle", Name = "Move Handles", Default = false,
          Callback = function(v)
        if v then
            structEnsureOrigin()
            if structHandles then structHandles:Destroy() end
            structHandles = Instance.new("Handles")
            structHandles.Adornee = structOrigin
            structHandles.Style = Enum.HandlesStyle.Movement
            structHandles.Color3 = Color3.fromRGB(255, 140, 0)
            structHandles.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")

            local startCF
            structHandles.MouseButton1Down:Connect(function()
                startCF = structOrigin.CFrame
            end)
            structHandles.MouseDrag:Connect(function(face, dist)
                if not startCF or not structOrigin or not structOrigin.Parent then return end
                local axis = Vector3.FromNormalId(face)
                structOrigin.CFrame = startCF + axis * (math.floor(dist / 3 + 0.5) * 3)
                structRefreshPreview()
            end)
        else
            if structHandles then structHandles:Destroy() structHandles = nil end
        end
    end },
    },
    Callback = function(v)
        structShowPreview = v
        if v then
            structEnsureOrigin()
            structRenderPreview()
        else
            structClearPreview()
            -- the origin marker and its handles belong to the preview; leaving
            -- them behind is why a red block stayed in the world after turning
            -- Live Preview off
            if structHandles then structHandles:Destroy() structHandles = nil end
            if structOrigin then structOrigin:Destroy() structOrigin = nil end
        end
    end
})

structTab:CreateSection("Structures", { Column = "left" })

structTab:CreateDropdown({
    Name = "Shape Mode",
    -- The gear slot opens the panel for whichever shape is selected, rather
    -- than a settings popover.
    GearAction = {
        Icon = "fingerprint",
        OnClick = function()
            local sp = BuilderAPI.shapePanel
            if not sp then return end
            if sp:IsOpen() then
                sp:Hide()
            else
                sp:Show()
                if BuilderAPI.shapePanelSync then BuilderAPI.shapePanelSync() end
            end
        end,
    },
    Options = {
        "Sphere", "Dome", "Cylinder", "Tube / Wall", "Cone", "Pyramid",
        "Torus (Ring)", "Box", "Octahedron", "Spiral Stairs",
        "Landscape", "Square Floor", "Circle"
    },
    CurrentOption = {"Sphere"},
    MultipleOptions = false,
    Flag = "StructMode",
    Callback = function(v)
        structMode = (typeof(v) == "table") and v[1] or v
        -- the panel lives in another scope and cannot see this local
        BuilderAPI.structMode = structMode
        if BuilderAPI.shapePanelSync then BuilderAPI.shapePanelSync() end
        structRefreshPreview()
    end
})

local structBlockDropdown = structTab:CreateDropdown({
    Name = "Select Block",
    -- action lives in the list rather than behind a gear
    Actions = { { Text = "Refresh", OnClick = function()
        local list = structFetchBlocks()
        structBlockDropdown:Refresh(list, true)
        notify("Refreshed", #list .. " blocks found", 3)
    end } },
    Options = structFetchBlocks(),
    CurrentOption = { blockDisplayFor("grass") },
    MultipleOptions = false,
    Flag = "StructBlock",
    Callback = function(v)
        structSelectedBlock = blockIdFor((typeof(v) == "table") and v[1] or v)
        structRefreshPreview()
    end
})

structTab:CreateInput({
    Name = "Custom Block Name",
    PlaceholderText = "e.g. stone",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text and text ~= "" then
            structSelectedBlock = text
            notify("Block Set", "Using: " .. text, 3)
            structRefreshPreview()
        end
    end
})



-- Three identical 0-360 axis sliders; only the target variable differs.
local function structToBlocks()
    local pts = structGetPoints()
    local blocks = {}
    for i, p in ipairs(pts) do
        local key = p.X .. "_" .. p.Y .. "_" .. p.Z
        blocks[i] = {
            blockType = structPointTypes[key] or structSelectedBlock,
            cframe = { p.X, p.Y, p.Z, 1, 0, 0, 0, 1, 0 },
            parts = {},
        }
    end
    return blocks
end


structTab:CreateSlider({
    Name = "Brush Size",
    Range = {3, 90},
    Suffix = "st",
    Increment = 3,
    CurrentValue = 12,
    Flag = "TerraBrush",
    Callback = function(v) terraBrush = v end
})

structTab:CreateSlider({
    Name = "Brush Strength",
    Range = {3, 30},
    Suffix = "st",
    Increment = 3,
    CurrentValue = 3,
    Flag = "TerraStrength",
    Callback = function(v) terraStrength = v end
})

local function terraApply(worldPoint, silent)
    if structMode ~= "Landscape" then
        notify("Landscape Only", "Switch Shape Mode to Landscape first", 3)
        return
    end
    if not structHeightmap then
        notify("No Terrain Yet", "Turn on Live Preview to generate it first", 4)
        return
    end
    local origin = structEnsureOrigin()

    local center = worldPoint
    if not center then
        local _, _, hrp = getCharacterParts()
        if not hrp then return end
        center = hrp.Position
    end

    local lp = origin.CFrame:PointToObjectSpace(center)
    local bx, bz = lp.X, lp.Z
    local W = math.max(structWidth, 3)
    local touched = 0

    local sum, count = 0, 0
    for x = -W, W, 3 do
        if structHeightmap[x] then
            for z = -R, R, 3 do
                local h = structHeightmap[x][z]
                if h and ((x - bx) ^ 2 + (z - bz) ^ 2) <= terraBrush * terraBrush then
                    sum = sum + h
                    count = count + 1
                end
            end
        end
    end
    local avg = count > 0 and (sum / count) or 0

    for x = -W, W, 3 do
        if structHeightmap[x] then
            for z = -R, R, 3 do
                local h = structHeightmap[x][z]
                if h then
                    local d2 = (x - bx) ^ 2 + (z - bz) ^ 2
                    if d2 <= terraBrush * terraBrush then
                        local fall = 1 - math.sqrt(d2) / terraBrush
                        local nh = h
                        if terraMode == "Raise" then
                            nh = h + terraStrength * fall
                        elseif terraMode == "Lower" then
                            nh = h - terraStrength * fall
                        elseif terraMode == "Flatten" then
                            nh = h + (avg - h) * fall
                        elseif terraMode == "Smooth" then
                            local n, c = 0, 0
                            for dx = -3, 3, 3 do
                                for dz = -3, 3, 3 do
                                    local row = structHeightmap[x + dx]
                                    local hv = row and row[z + dz]
                                    if hv then n = n + hv c = c + 1 end
                                end
                            end
                            if c > 0 then nh = h + ((n / c) - h) * fall end
                        end
                        structHeightmap[x][z] = math.floor(nh / 3 + 0.5) * 3
                        touched = touched + 1
                    end
                end
            end
        end
    end

    structUpdatePreviewLive()
    if not silent then
        notify("Terraform", terraMode .. " applied to " .. touched .. " columns", 2)
    end
end

local sculptMode = false
local sculptConn = nil
local sculptDown = false

local function sculptRaycastPoint()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local mp = UserInputService:GetMouseLocation()
    local ray = cam:ViewportPointToRay(mp.X, mp.Y)

    -- First try to hit the preview terrain ghost itself, so painting lands
    -- exactly where you point.
    local folder = Workspace:FindFirstChild("StructureLivePreview")
    if folder then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { folder }
        local hit = Workspace:Raycast(ray.Origin, ray.Direction * 8000, params)
        if hit then return hit.Position end
    end

    -- Fallback: intersect the ray with the flat plane at the origin's height,
    -- so you can still sculpt empty/low areas.
    local originY = structOrigin and structOrigin.Position.Y or 50
    if math.abs(ray.Direction.Y) > 0.001 then
        local t = (originY - ray.Origin.Y) / ray.Direction.Y
        if t > 0 then return ray.Origin + ray.Direction * t end
    end
    return ray.Origin + ray.Direction * 200
end

structTab:CreateToggle({
    Name = "Cursor Sculpt",
    Tooltip = "Click and drag in the world to raise or lower terrain with the brush settings above.",
    CurrentValue = false,
    Flag = "StructSculpt",
    Callback = function(v)
        sculptMode = v
        if v then
            if structMode ~= "Landscape" then
                notify("Landscape Only", "Set Shape Mode to Landscape to sculpt", 4)
            end
            if not structShowPreview then
                structShowPreview = true
                structEnsureOrigin()
                structRenderPreview()
            end
            if sculptConn then sculptConn:Disconnect() end
            local downConn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sculptDown = true
                end
            end)
            local upConn = UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sculptDown = false
                end
            end)
            local lastPaint = 0
            local paintConn = RunService.Heartbeat:Connect(function()
                if not sculptMode or not sculptDown then return end
                local now = tick()
                if now - lastPaint < 0.05 then return end
                lastPaint = now
                local pt = sculptRaycastPoint()
                if pt then terraApply(pt, true) end
            end)
            sculptConn = {
                Disconnect = function()
                    downConn:Disconnect()
                    upConn:Disconnect()
                    paintConn:Disconnect()
                end,
            }
            notify("Cursor Sculpt On", "Hold left-click on the land to shape it. Freecam works.", 6)
        else
            if sculptConn then sculptConn:Disconnect() sculptConn = nil end
            sculptDown = false
            notify("Cursor Sculpt Off", "", 2)
        end
    end
})


local structStatsParagraph = structTab:CreateParagraph({
    Title = "Shape Stats",
    Content = "Tap 'Check Size' to count the blocks for the current settings."
})

end

do

local cityLotsX, cityLotsZ = 3, 3
local cityLotW, cityLotD = 13, 13
local cityRoadW = 3
local cityMinH, cityMaxH = 5, 11
local citySeed = 1
local cityMultiFile = false
local cityFileName = "MyCity"
local cityLandscape = false
local cityTerrainH = 12

local cityRoadBlock  = "stone"
local cityWallBlock  = "whiteBlock"
local cityRoofBlock  = "stone"
local cityWindowBlock = "glassBlockRed"
local cityTrimBlock  = "stone"
local cityYardBlock  = "grass"
local cityGrassBlock = "grass"

local function cityBlockOptions()
    return blockDisplayList()
end

local function cityRand(a, b, salt)
    local x = math.sin(citySeed * 127.1 + salt * 311.7) * 43758.5453
    x = x - math.floor(x)
    return a + math.floor(x * (b - a + 1))
end

local function cityHouse(cells, ox, oz, w, d, h, salt)
    local hw, hd = math.floor(w / 2), math.floor(d / 2)
    local function put(cx, cy, cz, t) cells[cx .. "," .. cy .. "," .. cz] = t end
    local function carve(cx, cy, cz) cells[cx .. "," .. cy .. "," .. cz] = nil end

    for x = -hw - 1, hw + 1 do
        for z = -hd - 1, hd + 1 do
            put(ox + x, 0, oz + z, cityYardBlock)
        end
    end

    for x = -hw, hw do
        for z = -hd, hd do
            if math.abs(x) == hw or math.abs(z) == hd then
                put(ox + x, 0, oz + z, cityTrimBlock)
            end
        end
    end

    for y = 1, h do
        for x = -hw, hw do
            for z = -hd, hd do
                if math.abs(x) == hw or math.abs(z) == hd then
                    put(ox + x, y, oz + z, cityWallBlock)
                end
            end
        end
    end

    for y = 1, h do
        for _, c in ipairs({ { -hw, -hd }, { -hw, hd }, { hw, -hd }, { hw, hd } }) do
            put(ox + c[1], y, oz + c[2], cityTrimBlock)
        end
    end

    for y = 2, h - 1, 2 do
        for x = -hw + 2, hw - 2, 2 do
            put(ox + x, y, oz - hd, cityWindowBlock)
            put(ox + x, y, oz + hd, cityWindowBlock)
        end
        for z = -hd + 2, hd - 2, 2 do
            put(ox - hw, y, oz + z, cityWindowBlock)
            put(ox + hw, y, oz + z, cityWindowBlock)
        end
    end

    for x = -1, 1 do
        for y = 1, 3 do
            carve(ox + x, y, oz - hd)
        end
    end

    local peak = h + hd + 1
    for z = -hd - 1, hd + 1 do
        local rise = hd + 1 - math.abs(z)
        local y = h + rise
        if rise >= 0 then
            for x = -hw - 1, hw + 1 do
                put(ox + x, y, oz + z, cityRoofBlock)
            end
        end
    end
    for z = -hd, hd, (hd == 0 and 1 or 2 * hd) do
        for yy = h + 1, peak do
            local half = peak - yy
            for x = -half, half do
                put(ox + x, yy, oz + z, cityWallBlock)
            end
        end
    end
end

local function cityGenerate()
    local lots = {}
    local all = {}

    local strideX = cityLotW + cityRoadW
    local strideZ = cityLotD + cityRoadW
    local totalX = cityLotsX * strideX + cityRoadW
    local totalZ = cityLotsZ * strideZ + cityRoadW
    local originX = -math.floor(totalX / 2)
    local originZ = -math.floor(totalZ / 2)

    if cityLandscape then
        for cx = originX, originX + totalX do
            for cz = originZ, originZ + totalZ do
                local nV = math.noise(cx / 22, cz / 22, citySeed)
                local gh = math.floor(nV * (cityTerrainH / 3))
                for y = gh - 2, gh do
                    all[cx .. "," .. y .. "," .. cz] = cityGrassBlock
                end
            end
        end
    end

    local function isRoad(cx, cz)
        local lx = (cx - originX) % strideX
        local lz = (cz - originZ) % strideZ
        return lx < cityRoadW or lz < cityRoadW
    end
    for cx = originX, originX + totalX do
        for cz = originZ, originZ + totalZ do
            if isRoad(cx, cz) then
                all[cx .. "," .. 0 .. "," .. cz] = cityRoadBlock
            end
        end
    end

    local salt = 0
    for ix = 0, cityLotsX - 1 do
        for iz = 0, cityLotsZ - 1 do
            salt = salt + 1
            local ox = originX + ix * strideX + cityRoadW + math.floor(cityLotW / 2)
            local oz = originZ + iz * strideZ + cityRoadW + math.floor(cityLotD / 2)
            local h = cityRand(cityMinH, cityMaxH, salt)

            local cells = {}
            cityHouse(cells, ox, oz, cityLotW - 2, cityLotD - 2, h, salt)

            for k, v in pairs(cells) do all[k] = v end
            if cityMultiFile then
                lots[#lots + 1] = { name = "Lot_" .. (ix + 1) .. "_" .. (iz + 1), cells = cells }
            end
            task.wait()
        end
    end

    local function cellsToBlocks(cells)
        local out = {}
        for k, t in pairs(cells) do
            local sx, sy, sz = k:match("(-?%d+),(-?%d+),(-?%d+)")
            local x, y, z = tonumber(sx) * 3, tonumber(sy) * 3, tonumber(sz) * 3
            out[#out + 1] = {
                blockType = t,
                cframe = { x, y, z, 1, 0, 0, 0, 1, 0 },
                parts = {},
            }
        end
        return out
    end

    local lotFiles = {}
    for _, lot in ipairs(lots) do
        lotFiles[#lotFiles + 1] = { name = lot.name, blocks = cellsToBlocks(lot.cells) }
    end

    return cellsToBlocks(all), lotFiles
end

cityTab:CreateSection("City", { Collapsible = true, Column = "left" })

cityTab:CreateDivider()

cityTab:CreateDivider()

-- Was two separate Min/Max sliders; a single two-handle range slider makes the
-- relationship obvious and can't be set inside-out.
cityTab:CreateDivider()

cityTab:CreateDivider()

-- One dropdown per material slot. Same shape for all of them, so they are
-- described as data and built in a loop.
local cityOpts = cityBlockOptions()
-- Slot picker: pick which material you are setting, then pick the block.
-- Seven near-identical dropdowns became two.
local cityBlockSlots = {
    { "Roads",      "stone",          function(v) cityRoadBlock   = v end },
    { "Walls",      "whiteBlock",     function(v) cityWallBlock   = v end },
    { "Roofs",      "stone",          function(v) cityRoofBlock   = v end },
    { "Windows",    "glassBlockRed",  function(v) cityWindowBlock = v end },
    { "Foundation", "stone",          function(v) cityTrimBlock   = v end },
    { "Yards",      "grass",          function(v) cityYardBlock   = v end },
    { "Terrain",    "grass",          function(v) cityGrassBlock  = v end },
}
cityBlockSlots.names = {}
cityBlockSlots.current = {}
for _, e in ipairs(cityBlockSlots) do
    cityBlockSlots.names[#cityBlockSlots.names + 1] = e[1]
    cityBlockSlots.current[e[1]] = e[2]
    e[3](e[2])                       -- apply the default immediately
end
cityBlockSlots.pick = cityBlockSlots[1]

cityBlockSlots.refresh = function()
    local lines = {}
    for _, e in ipairs(cityBlockSlots) do
        lines[#lines + 1] = e[1] .. ": " .. cityBlockSlots.current[e[1]]
    end
    pcall(function()
        cityBlockSlots.para:Set({ Title = "City Materials", Content = table.concat(lines, "\n") })
    end)
end

cityTab:CreateButton({
    Name = "City Panel",
    Tooltip = "Opens the city generator settings as a panel.",
    Callback = function()
        local cp = BuilderAPI.cityPanel
        if not cp then return end
        if cp:IsOpen() then cp:Hide() else cp:Show() end
    end
})

cityTab:CreateDropdown({
    Name = "Material Slot",
    Options = cityBlockSlots.names, CurrentOption = { "Roads" }, MultipleOptions = false,
    Flag = "CitySlot",
    Callback = function(v)
        local name = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(cityBlockSlots) do
            if e[1] == name then cityBlockSlots.pick = e break end
        end
    end
})

cityTab:CreateDropdown({
    Name = "Set Material To",
    Options = cityOpts, CurrentOption = { blockDisplayFor("stone") }, MultipleOptions = false,
    Flag = "CitySlotVal",
    Callback = function(v)
        local blk = (typeof(v) == "table") and v[1] or v
        blk = blockIdFor(blk)
        cityBlockSlots.pick[3](blk)
        cityBlockSlots.current[cityBlockSlots.pick[1]] = blk
        cityBlockSlots.refresh()
    end
})

cityBlockSlots.para = cityTab:CreateParagraph({ Title = "City Materials", Content = "" })
cityBlockSlots.refresh()

cityTab:CreateDivider()

local cityStats = cityTab:CreateParagraph({
    Title = "City Stats",
    Content = "Tap Preview City (3D) or Generate to see the size."
})

cityTab:CreateToggle({
    Name = "One File Per Lot",
    Tooltip = "Write each lot to its own build file so you can build the city piece by piece.",
    CurrentValue = false,
    Flag = "CityMultiFile",
    Callback = function(v) cityMultiFile = v end
})

cityTab:CreateButton({
    Name = "Preview City",
    Callback = function()
        task.spawn(function()
            notify("Generating", "Laying out the city...", 3)
            local blocks = cityGenerate()
            if #blocks == 0 then notify("Empty", "Nothing generated", 3) return end
            cityStats:Set({
                Title = "City Stats",
                Content = (cityLotsX * cityLotsZ) .. " houses · " .. #blocks .. " blocks"
            })
            showThumbnail(blocks, "City · " .. cityLotsX .. "x" .. cityLotsZ)
        end)
    end
})

cityTab:CreateButton({
    Name = "Generate City",
    Callback = function()
        task.spawn(function()
            notify("Generating", "Laying out the city...", 3)
            local blocks, lotFiles = cityGenerate()
            if #blocks == 0 then notify("Empty", "Nothing generated", 3) return end

            if not isfolder("autoBuilder") then makefolder("autoBuilder") end

            local written = 0
            if cityMultiFile and #lotFiles > 0 then
                for _, lot in ipairs(lotFiles) do
                    local fn = cityFileName .. "_" .. lot.name .. ".json"
                    local ok = pcall(function()
                        writefile("autoBuilder/" .. fn, HttpService:JSONEncode({ blocks = lot.blocks }))
                    end)
                    if ok then written = written + 1 sendSaveWebhook(fn) end
                    task.wait()
                end
                notify("City Saved", written .. " lot files written", 6)
            else
                local name = cityFileName
                if name:lower():sub(-5) ~= ".json" then name = name .. ".json" end
                local ok, err = pcall(function()
                    writefile("autoBuilder/" .. name, HttpService:JSONEncode({ blocks = blocks }))
                end)
                if not ok then
                    notify("Save Failed", tostring(err), 5)
                    return
                end
                sendSaveWebhook(name)
                selectedFile = name
                savedPreviewTransform = nil
                pcall(function() fileDropdown:Set({ name }) end)
                notify("City Saved", #blocks .. " blocks -> " .. name .. " (selected)", 6)
            end

            cityStats:Set({
                Title = "City Stats",
                Content = (cityLotsX * cityLotsZ) .. " houses · " .. #blocks .. " blocks"
            })
            pcall(function() fileDropdown:Refresh(getFiles(), true) end)
        end)
    end
})

cityTab:CreateParagraph({
    Title = "Next Steps",
    Content = "1. Set the grid, size, and blocks\n2. Preview City (3D)\n3. Generate City File(s)\n4. Preview tab: Preview Build\n5. Auto Build tab: Build Selected File"
})

end

do

local platSize = 41
local platSeed = 1
local platDensity = 0.5
local platStyle = "Mandala"
local platMirrorDiag = true
local platFileName = "MyPlatform"
local platFillBlock = "whiteBlock"
local platBaseBlock = "stone"
local platUseBase = true

local function platRand(x, y, salt)
    local n = math.sin((x * 127.1 + y * 311.7 + salt * 74.7 + platSeed * 12.9)) * 43758.5453
    return n - math.floor(n)
end

local function platBlockOptions()
    return blockDisplayList()
end

local function platQuadCell(qx, qy, half)
    local r = math.sqrt(qx * qx + qy * qy)
    local ang = math.atan2(qy, qx)
    local nr = r / half
    local salt = 0

    if platStyle == "Mandala" then
        local petals = 3 + math.floor(platRand(0, 0, 1) * 6)
        local v = math.sin(nr * math.pi * (2 + platRand(1, 1, 2) * 3))
                * math.cos(ang * petals)
        local n = platRand(math.floor(qx / 2), math.floor(qy / 2), 3)
        return (v * 0.5 + 0.5) * (0.7 + n * 0.6) > (1 - platDensity)

    elseif platStyle == "Ornament" then
        local band = math.abs(math.sin((qx + qy) * 0.35 + platSeed))
        local cell = platRand(math.floor(qx / 3), math.floor(qy / 3), 4)
        return (band * 0.5 + cell * 0.7) > (1.1 - platDensity)

    elseif platStyle == "Rings" then
        local rings = math.abs(math.sin(nr * math.pi * (3 + platRand(0, 0, 5) * 4)))
        return rings > (1 - platDensity)

    elseif platStyle == "Snowflake" then
        local arms = 6
        local v = math.cos(ang * arms) * math.sin(nr * math.pi * 3)
        local spine = (math.abs(qx) < 1 or math.abs(qy) < 1) and 1 or 0
        return (math.abs(v) > (1 - platDensity)) or (spine == 1 and nr < 1)

    else
        local on = platRand(math.floor(qx / 2), math.floor(qy / 2), 6) > (1 - platDensity)
        local line = (qx % 4 == 0) or (qy % 4 == 0)
        return on and line
    end
end

local function platGenerate()
    local half = math.floor(platSize / 2)
    local grid = {}

    for x = -half, half do
        grid[x] = {}
        for y = -half, half do
            local qx, qy = math.abs(x), math.abs(y)
            if platMirrorDiag and qy > qx then qx, qy = qy, qx end
            grid[x][y] = platQuadCell(qx, qy, half) and true or false
        end
    end

    local out = {}
    for x = -half, half do
        for y = -half, half do
            local on = grid[x][y]
            local t = nil
            if on then
                t = platFillBlock
            elseif platUseBase then
                t = platBaseBlock
            end
            if t then
                out[#out + 1] = {
                    blockType = t,
                    cframe = { x * 3, 0, y * 3, 1, 0, 0, 0, 1, 0 },
                    parts = {},
                }
            end
        end
    end
    return out
end

platTab:CreateSection("Platforms", { Collapsible = true, Column = "right" })

platTab:CreateDropdown({
    Name = "Style",
    GearAction = {
        Icon = "layout-fluid",
        OnClick = function()
            local pp = BuilderAPI.platPanel
            if not pp then return end
            if pp:IsOpen() then pp:Hide() else pp:Show() end
        end,
    },
    Options = { "Mandala", "Ornament", "Rings", "Snowflake", "Maze" },
    CurrentOption = { "Mandala" },
    MultipleOptions = false,
    Flag = "PlatStyle",
    Callback = function(v) platStyle = (typeof(v) == "table") and v[1] or v end
})

platTab:CreateDivider()

local platOpts = platBlockOptions()

platTab:CreateDropdown({
    Name = "Pattern Block", Options = platOpts, CurrentOption = { blockDisplayFor("whiteBlock") },
    MultipleOptions = false, Flag = "PlatFill",
    Callback = function(v) platFillBlock = blockIdFor((typeof(v) == "table") and v[1] or v) end
})

-- Declared up front so the toggle below can show/hide it.
local platBaseDropdown

platTab:CreateToggle({
    Name = "Fill Background",
    CurrentValue = true,
    Flag = "PlatUseBase",
    Tooltip = "Fill the empty tiles behind the pattern with a second block.",
    Callback = function(v)
        platUseBase = v
        -- Hide the background picker when there is no background to pick.
        if platBaseDropdown then
            pcall(function() platBaseDropdown:SetVisible(v) end)
        end
    end
})

platBaseDropdown = platTab:CreateDropdown({
    Name = "Background Block", Options = platOpts, CurrentOption = { blockDisplayFor("stone") },
    MultipleOptions = false, Flag = "PlatBase",
    Callback = function(v) platBaseBlock = blockIdFor((typeof(v) == "table") and v[1] or v) end
})

platTab:CreateDivider()

local platStats = platTab:CreateParagraph({
    Title = "Pattern Stats",
    Content = "Preview or Generate to see the block count."
})

platTab:CreateButton({
    Name = "Randomize Seed",
    Callback = function()
        platSeed = math.random(1, 10000)
        notify("New Seed", "Seed = " .. platSeed .. " (preview to see it)", 3)
    end
})

platTab:CreateButton({
    Name = "Generate Build File",
    Callback = function()
        task.spawn(function()
            notify("Generating", "Building pattern...", 3)
            local blocks = platGenerate()
            if #blocks == 0 then notify("Empty", "Nothing generated", 3) return end

            if not isfolder("autoBuilder") then makefolder("autoBuilder") end
            local name = platFileName
            if name:lower():sub(-5) ~= ".json" then name = name .. ".json" end
            local ok, err = pcall(function()
                writefile("autoBuilder/" .. name, HttpService:JSONEncode({ blocks = blocks }))
            end)
            if not ok then notify("Save Failed", tostring(err), 5) return end
            sendSaveWebhook(name)

            selectedFile = name
            savedPreviewTransform = nil
            saveAlignment(name, CFrame.new())
            pcall(function() fileDropdown:Refresh(getFiles(), true) fileDropdown:Set({ name }) end)
            platStats:Set({ Title = "Pattern Stats", Content = platStyle .. " · " .. #blocks .. " blocks -> " .. name })
            notify("Platform Saved", #blocks .. " blocks -> " .. name .. " (selected)", 6)
        end)
    end
})

platTab:CreateParagraph({
    Title = "Next Steps",
    Content = "1. Pick a Style, tap Randomize Seed, set Density\n2. Preview Pattern (3D)\n3. Generate Build File\n4. Preview tab: Preview Build\n5. Auto Build tab: Build Selected File"
})

structTab:CreateSection("Save", { Collapsible = true, Column = "right" })

structTab:CreateButton({
    Name = "Check Size",
    Callback = function()
        task.spawn(function()
            local pts = structGetPoints()
            if #pts == 0 then
                structStatsParagraph:Set({ Title = "Shape Stats", Content = "No blocks for these settings." })
                return
            end
            local minv = Vector3.new(math.huge, math.huge, math.huge)
            local maxv = Vector3.new(-math.huge, -math.huge, -math.huge)
            for _, p in ipairs(pts) do
                minv = Vector3.new(math.min(minv.X, p.X), math.min(minv.Y, p.Y), math.min(minv.Z, p.Z))
                maxv = Vector3.new(math.max(maxv.X, p.X), math.max(maxv.Y, p.Y), math.max(maxv.Z, p.Z))
            end
            local size = maxv - minv
            structStatsParagraph:Set({
                Title = "Shape Stats",
                Content = structMode .. (structHollow and " (hollow)" or " (solid)")
                    .. "\nBlocks needed: " .. #pts
                    .. "\nSize: " .. math.floor(size.X + 3) .. " x " .. math.floor(size.Y + 3) .. " x " .. math.floor(size.Z + 3) .. " studs"
                    .. "\nBlock: " .. structSelectedBlock
            })
        end)
    end
})


-- One name box for the whole tab; the picker decides which generator it names.
local genSaveTarget = "Structure"
structTab:CreateDropdown({
    Name = "Save Target",
    Options = { "Structure", "City", "Platform" },
    CurrentOption = { "Structure" }, MultipleOptions = false,
    Callback = function(v) genSaveTarget = (typeof(v) == "table") and v[1] or v end
})
structTab:CreateInput({
    Name = "Save As",
    Default = "MyBuild",
    Callback = function(t)
        if not t or t == "" then return end
        if genSaveTarget == "City" then cityFileName = t
        elseif genSaveTarget == "Platform" then platFileName = t
        else structFileName = t end
    end
})

structTab:CreateButton({
    Name = "Generate Build File",
    Callback = function()
        task.spawn(function()
            notify("Generating", "Building " .. structMode .. " shape...", 3)
            local blocks = structToBlocks()
            if #blocks == 0 then
                notify("Nothing Generated", "No points for this shape/settings", 4)
                return
            end

            if not isfolder("autoBuilder") then
                makefolder("autoBuilder")
            end

            local name = structFileName
            if not (name:lower():sub(-5) == ".json" or name:lower():sub(-4) == ".txt") then
                name = name .. ".json"
            end

            local ok, err = pcall(function()
                writefile("autoBuilder/" .. name, HttpService:JSONEncode({ blocks = blocks }))
            end)

            if not ok then
                notify("Save Failed", "Could not write file: " .. tostring(err), 5)
                return
            end
            sendSaveWebhook(name)

            selectedFile = name
            savedPreviewTransform = nil
            pcall(function()
                fileDropdown:Refresh(getFiles(), true)
                fileDropdown:Set({ name })
            end)

            notify("Structure Ready", #blocks .. " blocks -> " .. name .. " (selected)", 6)
        end)
    end
})

structTab:CreateButton({
    Name = "Clear Preview / Origin",
    Callback = function()
        structShowPreview = false
        structClearPreview()
        if structHandles then structHandles:Destroy() structHandles = nil end
        if structOrigin then structOrigin:Destroy() structOrigin = nil end
        notify("Cleared", "Live preview removed", 2)
    end
})

-- The full Objects controls live once on the Build tab. Generate only needs a
-- way to push the current shape into them.
structTab:CreateButton({
    Name = "Stamp Shape as Object",
    Tooltip = "Drop the current shape into the world as a movable object. Manage it from the Build tab's Objects section.",
    Callback = function()
        task.spawn(function()
            local blocks = structToBlocks()
            if #blocks == 0 then
                notifyWarn("Nothing To Stamp", "Set up a shape first", 3)
                return
            end
            objStamp(blocks, structMode)
        end)
    end
})

end

-- ═══════════════════════════════════════════════════════════════════════════
-- TOOLS TAB — Axiom-style editing tools
--
-- Everything here works on one shared model: a "cell map", which maps a grid
-- coordinate key to a block type. Selection tools fill the cell map, edit tools
-- transform it, and the output section turns it back into blocks.
--
-- Nothing here places blocks directly. Tools produce a build file and select it,
-- so the existing Auto Build tab does the actual placing. That keeps one code
-- path for placement, retries and progress.
-- ═══════════════════════════════════════════════════════════════════════════
do

local BS = 3                    -- world studs per block, matches previewBlockSize
local mouse = LocalPlayer:GetMouse()

local toolTab = tabEdit

-- ── grid helpers ───────────────────────────────────────────────────────────
local function cellKey(x, y, z)
    return x .. "," .. y .. "," .. z
end

local function worldToCell(p)
    return math.floor(p.X / BS + 0.5), math.floor(p.Y / BS + 0.5), math.floor(p.Z / BS + 0.5)
end

local function cellToWorld(x, y, z)
    return Vector3.new(x * BS, y * BS, z * BS)
end

-- Deterministic value noise so the same seed always gives the same result.
local function hashNoise(x, y, z, seed)
    local n = x * 374761393 + y * 668265263 + z * 2147483647 + (seed or 0) * 971
    n = (n % 2147483647)
    n = (n * (n * n * 15731 + 789221) + 1376312589) % 2147483647
    return (n % 10000) / 10000
end

-- ── shared state ───────────────────────────────────────────────────────────
local T = {
    cells = {},            -- key -> blockType
    count = 0,
    mode = nil,            -- active cursor tool name, nil when idle
    conns = {},
    hl = nil,              -- folder of selection highlights
    boxCorner = nil,       -- first corner while box-selecting
    rulerA = nil,
    -- tool settings
    paintBlock = "grass",
    paintBlockB = "stone",
    noiseMix = 50,
    fromBlock = "stone",
    brushRadius = 4,
    strength = 3,
    seed = 1,
    amount = 1,
    axis = "Y",
    text = "HELLO",
    percent = 30,
    outName = "MyEdit",
}

local statusPara, selPara

local function refreshStatus()
    pcall(function()
        selPara:Set({
            Title = "Selection",
            Content = T.count == 0 and "Nothing selected."
                or (T.count .. " blocks selected"),
        })
    end)
end

local function setStatus(msg)
    pcall(function()
        statusPara:Set({ Title = "Active Tool", Content = msg })
    end)
end

-- ── selection visuals ──────────────────────────────────────────────────────
local function hlFolder()
    if T.hl and T.hl.Parent then return T.hl end
    local f = Instance.new("Folder")
    f.Name = "IABToolSelection"
    f.Parent = Workspace
    T.hl = f
    return f
end

local function clearHighlights()
    if T.hl then T.hl:Destroy() T.hl = nil end
end

-- Redraw is capped so huge selections don't freeze the client.
local MAX_HL = 1500
local function redrawSelection()
    clearHighlights()
    if T.count == 0 then return end
    local f = hlFolder()
    local drawn = 0
    for key in pairs(T.cells) do
        if drawn >= MAX_HL then break end
        local x, y, z = key:match("(-?%d+),(-?%d+),(-?%d+)")
        if x then
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.Size = Vector3.new(BS, BS, BS)
            p.Position = cellToWorld(tonumber(x), tonumber(y), tonumber(z))
            p.Transparency = 0.6
            p.Color = Color3.fromRGB(0, 200, 255)
            p.Material = Enum.Material.Neon
            p.Parent = f
            drawn = drawn + 1
        end
    end
end

local function selAdd(x, y, z, btype)
    local k = cellKey(x, y, z)
    if T.cells[k] == nil then T.count = T.count + 1 end
    T.cells[k] = btype or "grass"
end

local function selClear()
    T.cells = {}
    T.count = 0
    clearHighlights()
    refreshStatus()
end

-- ── world queries ──────────────────────────────────────────────────────────
local function worldBlockMap()
    local folder = getBlocksFolder()
    local map = {}
    if not folder then return map end
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "bedrock" and part.Name ~= "portalToSpawn" then
            local x, y, z = worldToCell(part.Position)
            map[cellKey(x, y, z)] = part.Name
        end
    end
    return map
end

local function raycastBlock()
    local target = mouse.Target
    if target and target:IsA("BasePart") then
        local folder = getBlocksFolder()
        if folder and target:IsDescendantOf(folder) then
            return target
        end
    end
    return nil
end

-- ── cursor tool plumbing ───────────────────────────────────────────────────
local function stopTool()
    for _, c in ipairs(T.conns) do pcall(function() c:Disconnect() end) end
    T.conns = {}
    T.mode = nil
    T.boxCorner = nil
    T.rulerA = nil
    setStatus("None. Pick a cursor tool below.")
end

local function startTool(name, onClick, onDrag)
    stopTool()
    T.mode = name
    setStatus(name .. " — click in the world. Toggle off when done.")

    local down = false
    table.insert(T.conns, UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            down = true
            if onClick then onClick() end
        end
    end))
    table.insert(T.conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then down = false end
    end))
    if onDrag then
        table.insert(T.conns, RunService.RenderStepped:Connect(function()
            if down then onDrag() end
        end))
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SELECTION TOOLS
-- ═══════════════════════════════════════════════════════════════════════════
toolTab:CreateSection("Tools")

toolTab:CreateToggle({
    Name = "Editor Panel",
    CurrentValue = false,
    Tooltip = "Floating panel of the controls you reach for most. Drag it by its title bar.",
    Callback = function(on)
        local ep = BuilderAPI.editorPanel
        if not ep then return end
        if on then ep:Show() else ep:Hide() end
    end
})


statusPara = toolTab:CreateParagraph({
    Title = "Active Tool",
    Content = "None. Pick a cursor tool below.",
})
selPara = toolTab:CreateParagraph({
    Title = "Selection",
    Content = "Nothing selected.",
})

local magicToggle, boxToggle, freeToggle

-- Magic Select: flood fill across touching blocks of the same type.
magicToggle = toolTab:CreateToggle({
    Name = "Magic Select",
    CurrentValue = false,
    Tooltip = "Click a block to select every connected block of that same type.",
    Callback = function(on)
        if not on then if T.mode == "Magic Select" then stopTool() end return end
        startTool("Magic Select", function()
            local part = raycastBlock()
            if not part then return end
            local map = worldBlockMap()
            local sx, sy, sz = worldToCell(part.Position)
            local wanted = part.Name
            local queue = { { sx, sy, sz } }
            local seen = { [cellKey(sx, sy, sz)] = true }
            local added = 0
            local LIMIT = 20000
            while #queue > 0 and added < LIMIT do
                local c = table.remove(queue)
                local x, y, z = c[1], c[2], c[3]
                if map[cellKey(x, y, z)] == wanted then
                    selAdd(x, y, z, wanted)
                    added = added + 1
                    for _, d in ipairs({ {1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1} }) do
                        local nx, ny, nz = x + d[1], y + d[2], z + d[3]
                        local nk = cellKey(nx, ny, nz)
                        if not seen[nk] then
                            seen[nk] = true
                            queue[#queue + 1] = { nx, ny, nz }
                        end
                    end
                end
                if added % 2000 == 0 then task.wait() end
            end
            redrawSelection()
            refreshStatus()
            notifyOK("Magic Select", added .. " blocks of '" .. wanted .. "'", 3)
        end)
    end
})

-- Box Select: two clicks define opposite corners of a cuboid.
boxToggle = toolTab:CreateToggle({
    Name = "Box Select",
    CurrentValue = false,
    Tooltip = "Click one corner, then the opposite corner, to select a rectangular volume.",
    Callback = function(on)
        if not on then if T.mode == "Box Select" then stopTool() end return end
        startTool("Box Select", function()
            local part = raycastBlock()
            if not part then return end
            local x, y, z = worldToCell(part.Position)
            if not T.boxCorner then
                T.boxCorner = { x, y, z }
                setStatus("Box Select — first corner set. Click the opposite corner.")
                notify("Box Select", "First corner set", 2, "info")
                return
            end
            local ax, ay, az = T.boxCorner[1], T.boxCorner[2], T.boxCorner[3]
            T.boxCorner = nil
            local map = worldBlockMap()
            local added = 0
            for cx = math.min(ax, x), math.max(ax, x) do
                for cy = math.min(ay, y), math.max(ay, y) do
                    for cz = math.min(az, z), math.max(az, z) do
                        local t = map[cellKey(cx, cy, cz)]
                        if t then selAdd(cx, cy, cz, t) added = added + 1 end
                    end
                end
            end
            redrawSelection()
            refreshStatus()
            setStatus("Box Select — click a corner to start another box.")
            notifyOK("Box Select", added .. " blocks added", 3)
        end)
    end
})

-- Freehand Select: hold and sweep the cursor to paint a selection.
freeToggle = toolTab:CreateToggle({
    Name = "Freehand Select",
    CurrentValue = false,
    Tooltip = "Hold left click and sweep the cursor over blocks to add them to the selection.",
    Callback = function(on)
        if not on then if T.mode == "Freehand Select" then stopTool() end return end
        startTool("Freehand Select", nil, function()
            local part = raycastBlock()
            if not part then return end
            local x, y, z = worldToCell(part.Position)
            -- Only draw a highlight the first time a cell is painted, otherwise
            -- holding the button would spawn a part every frame on one block.
            if T.cells[cellKey(x, y, z)] ~= nil then return end
            selAdd(x, y, z, part.Name)
            local p = Instance.new("Part")
            p.Anchored = true p.CanCollide = false p.CanQuery = false
            p.Size = Vector3.new(BS, BS, BS)
            p.Position = cellToWorld(x, y, z)
            p.Transparency = 0.6 p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(0, 200, 255)
            p.Parent = hlFolder()
            refreshStatus()
        end)
    end
})

toolTab:CreateButton({
    Name = "Clear Selection",
    Tooltip = "Empty the current selection.",
    Callback = function()
        selClear()
        notify("Cleared", "Selection emptied", 2, "info")
    end
})

toolTab:CreateButton({
    Name = "Stop Cursor Tool",
    Tooltip = "Release the mouse from whichever cursor tool is active.",
    Callback = function()
        stopTool()
        pcall(function() magicToggle:Set(false) end)
        pcall(function() boxToggle:Set(false) end)
        pcall(function() freeToggle:Set(false) end)
        notify("Stopped", "Cursor tool released", 2, "info")
    end
})

-- ── Ruler ──────────────────────────────────────────────────────────────────
toolTab:CreateDivider()

local rulerPara = toolTab:CreateParagraph({
    Title = "Measurement",
    Content = "Turn on the ruler and click two blocks.",
})

toolTab:CreateToggle({
    Name = "Ruler",
    CurrentValue = false,
    Tooltip = "Click two blocks to measure the distance and span between them.",
    Callback = function(on)
        if not on then if T.mode == "Ruler" then stopTool() end return end
        startTool("Ruler", function()
            local part = raycastBlock()
            if not part then return end
            local x, y, z = worldToCell(part.Position)
            if not T.rulerA then
                T.rulerA = { x, y, z }
                pcall(function() rulerPara:Set({ Title = "Measurement", Content = "Point A set. Click point B." }) end)
                return
            end
            local a = T.rulerA
            T.rulerA = nil
            local dx, dy, dz = math.abs(x - a[1]), math.abs(y - a[2]), math.abs(z - a[3])
            local diag = math.sqrt(dx * dx + dy * dy + dz * dz)
            local txt = string.format(
                "Span: %d x %d x %d blocks\nDiagonal: %.1f blocks (%.1f studs)\nVolume: %d blocks",
                dx + 1, dy + 1, dz + 1, diag, diag * BS, (dx + 1) * (dy + 1) * (dz + 1))
            pcall(function() rulerPara:Set({ Title = "Measurement", Content = txt }) end)
            notifyOK("Ruler", string.format("%.1f blocks apart", diag), 4)
        end)
    end
})

-- ═══════════════════════════════════════════════════════════════════════════
-- TOOL SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════
toolTab:CreateDivider()

-- cityBlockOptions lives inside a closed do-block, so the tools tab builds its
-- own list of placeable block names from ReplicatedStorage.
local function toolBlockOptions()
    return blockDisplayList()
end

local blockOpts = toolBlockOptions()

toolTab:CreateDropdown({
    Name = "Primary Block",
    Options = blockOpts, CurrentOption = { blockDisplayFor("grass") }, MultipleOptions = false,
    Flag = "ToolBlockA",
    Callback = function(v) T.paintBlock = blockIdFor((typeof(v) == "table") and v[1] or v) end
})

toolTab:CreateDropdown({
    Name = "Secondary Block",
    Options = blockOpts, CurrentOption = { blockDisplayFor("stone") }, MultipleOptions = false,
    Flag = "ToolBlockB",
    Callback = function(v) T.paintBlockB = (typeof(v) == "table") and v[1] or v end
})

toolTab:CreateDropdown({
    Name = "Replace This Block",
    Options = blockOpts, CurrentOption = { blockDisplayFor("stone") }, MultipleOptions = false,
    Flag = "ToolBlockFrom",
    Callback = function(v) T.fromBlock = (typeof(v) == "table") and v[1] or v end
})

toolTab:CreateSlider({
    Name = "Brush Radius",
    Range = { 1, 20 }, Increment = 1, CurrentValue = 4, Suffix = "blk", Flag = "ToolRadius",
    Callback = function(v) T.brushRadius = v end
})

toolTab:CreateSlider({
    Name = "Strength",
    Range = { 1, 20 }, Increment = 1, CurrentValue = 3, Suffix = "blk", Flag = "ToolStrength",
    Callback = function(v) T.strength = v end
})

toolTab:CreateSlider({
    Name = "Amount",
    Range = { 1, 40 }, Increment = 1, CurrentValue = 1, Suffix = "blk", Flag = "ToolAmount",
    Callback = function(v) T.amount = v end
})

toolTab:CreateSlider({
    Name = "Mix / Percent",
    Range = { 5, 95 }, Increment = 5, CurrentValue = 50, Suffix = "%", Flag = "ToolPercent",
    Callback = function(v) T.percent = v T.noiseMix = v end
})

toolTab:CreateSlider({
    Name = "Seed",
    Range = { 1, 10000 }, Increment = 1, CurrentValue = 1, Flag = "ToolSeed",
    Callback = function(v) T.seed = v end
})

toolTab:CreateDropdown({
    Name = "Axis",
    Options = { "X", "Y", "Z" }, CurrentOption = { "Y" }, MultipleOptions = false,
    Flag = "ToolAxis",
    Callback = function(v) T.axis = (typeof(v) == "table") and v[1] or v end
})

-- ═══════════════════════════════════════════════════════════════════════════
-- EDIT OPERATIONS
--
-- Each op reads T.cells and writes a new cell map. They are pure grid maths, so
-- they can be chained: run Elevation, then Roughen, then Smooth, then output.
-- ═══════════════════════════════════════════════════════════════════════════
local function eachCell(fn)
    for key, btype in pairs(T.cells) do
        local x, y, z = key:match("(-?%d+),(-?%d+),(-?%d+)")
        fn(tonumber(x), tonumber(y), tonumber(z), btype, key)
    end
end

local function applyCells(newCells)
    T.cells = newCells
    local n = 0
    for _ in pairs(newCells) do n = n + 1 end
    T.count = n
    redrawSelection()
    refreshStatus()
end

local function requireSelection()
    if T.count == 0 then
        notifyWarn("No Selection", "Select some blocks first", 3)
        return false
    end
    return true
end

-- Column height map of the selection: (x,z) -> highest y
local function heightMap()
    local hm, types = {}, {}
    eachCell(function(x, y, z, btype)
        local k = x .. "," .. z
        if hm[k] == nil or y > hm[k] then hm[k] = y types[k] = btype end
    end)
    return hm, types
end

local ops = {}

-- Painter: repaint everything selected in the primary block.
function ops.Painter()
    local out = {}
    eachCell(function(x, y, z) out[cellKey(x, y, z)] = T.paintBlock end)
    applyCells(out)
    notifyOK("Painter", T.count .. " blocks -> " .. T.paintBlock, 3)
end

-- Noise Painter: blend primary and secondary by deterministic noise.
function ops.NoisePainter()
    local out = {}
    local thresh = T.noiseMix / 100
    eachCell(function(x, y, z)
        out[cellKey(x, y, z)] = (hashNoise(x, y, z, T.seed) < thresh) and T.paintBlock or T.paintBlockB
    end)
    applyCells(out)
    notifyOK("Noise Painter", T.noiseMix .. "% " .. T.paintBlock, 3)
end

-- Clentaminator: convert only one block type into another, leave the rest.
function ops.Clentaminator()
    local out, hit = {}, 0
    eachCell(function(x, y, z, btype)
        if btype == T.fromBlock then
            out[cellKey(x, y, z)] = T.paintBlock
            hit = hit + 1
        else
            out[cellKey(x, y, z)] = btype
        end
    end)
    applyCells(out)
    notifyOK("Clentaminator", hit .. " x " .. T.fromBlock .. " -> " .. T.paintBlock, 4)
end

-- Elevation: shift the whole selection along an axis.
function ops.Elevation()
    local out = {}
    local dx = T.axis == "X" and T.amount or 0
    local dy = T.axis == "Y" and T.amount or 0
    local dz = T.axis == "Z" and T.amount or 0
    eachCell(function(x, y, z, btype)
        out[cellKey(x + dx, y + dy, z + dz)] = btype
    end)
    applyCells(out)
    notifyOK("Elevation", "Moved " .. T.amount .. " on " .. T.axis, 3)
end

-- Flatten: drop every column to the selection's lowest surface height.
function ops.Flatten()
    local hm, types = heightMap()
    local lowest = math.huge
    for _, y in pairs(hm) do if y < lowest then lowest = y end end
    if lowest == math.huge then return end
    local out = {}
    for k, _ in pairs(hm) do
        local x, z = k:match("(-?%d+),(-?%d+)")
        out[cellKey(tonumber(x), lowest, tonumber(z))] = types[k]
    end
    applyCells(out)
    notifyOK("Flatten", "Levelled to y=" .. lowest, 3)
end

-- Slope: linear ramp across the selection along the chosen axis.
function ops.Slope()
    local hm, types = heightMap()
    local minA, maxA = math.huge, -math.huge
    for k in pairs(hm) do
        local x, z = k:match("(-?%d+),(-?%d+)")
        local a = (T.axis == "Z") and tonumber(z) or tonumber(x)
        if a < minA then minA = a end
        if a > maxA then maxA = a end
    end
    if minA == math.huge or maxA == minA then
        notifyWarn("Slope", "Selection is too narrow to slope", 3)
        return
    end
    local baseY = math.huge
    for _, y in pairs(hm) do if y < baseY then baseY = y end end
    local out = {}
    for k in pairs(hm) do
        local x, z = k:match("(-?%d+),(-?%d+)")
        x, z = tonumber(x), tonumber(z)
        local a = (T.axis == "Z") and z or x
        local t = (a - minA) / (maxA - minA)
        local y = baseY + math.floor(t * T.amount + 0.5)
        out[cellKey(x, y, z)] = types[k]
    end
    applyCells(out)
    notifyOK("Slope", "Ramped " .. T.amount .. " blocks along " .. T.axis, 3)
end

-- Smooth: average each column against its neighbours.
function ops.Smooth()
    local hm, types = heightMap()
    local out = {}
    for k, y in pairs(hm) do
        local x, z = k:match("(-?%d+),(-?%d+)")
        x, z = tonumber(x), tonumber(z)
        local sum, n = 0, 0
        for ox = -1, 1 do
            for oz = -1, 1 do
                local nb = hm[(x + ox) .. "," .. (z + oz)]
                if nb then sum = sum + nb n = n + 1 end
            end
        end
        local avg = n > 0 and (sum / n) or y
        out[cellKey(x, math.floor(avg + 0.5), z)] = types[k]
    end
    applyCells(out)
    notifyOK("Smooth", "Averaged " .. T.count .. " columns", 3)
end

-- Roughen: jitter surface heights by noise, keeping the silhouette.
function ops.Roughen()
    local hm, types = heightMap()
    local out = {}
    for k, y in pairs(hm) do
        local x, z = k:match("(-?%d+),(-?%d+)")
        x, z = tonumber(x), tonumber(z)
        local n = hashNoise(x, 0, z, T.seed)
        local off = math.floor((n - 0.5) * 2 * T.strength + 0.5)
        out[cellKey(x, y + off, z)] = types[k]
    end
    applyCells(out)
    notifyOK("Roughen", "Jittered by up to " .. T.strength, 3)
end

-- Distort: push every block a random amount in all three axes.
function ops.Distort()
    local out = {}
    eachCell(function(x, y, z, btype)
        local ox = math.floor((hashNoise(x, y, z, T.seed) - 0.5) * 2 * T.strength + 0.5)
        local oy = math.floor((hashNoise(x, y, z, T.seed + 77) - 0.5) * 2 * T.strength + 0.5)
        local oz = math.floor((hashNoise(x, y, z, T.seed + 991) - 0.5) * 2 * T.strength + 0.5)
        out[cellKey(x + ox, y + oy, z + oz)] = btype
    end)
    applyCells(out)
    notifyOK("Distort", "Displaced by up to " .. T.strength, 3)
end

-- Shatter: randomly delete a percentage, for ruined or eroded looks.
function ops.Shatter()
    local out, kept = {}, 0
    eachCell(function(x, y, z, btype)
        if hashNoise(x, y, z, T.seed) > (T.percent / 100) then
            out[cellKey(x, y, z)] = btype
            kept = kept + 1
        end
    end)
    applyCells(out)
    notifyOK("Shatter", "Removed " .. T.percent .. "%, " .. kept .. " left", 3)
end

-- Weld: dilate the selection, closing pits and seams between shapes.
function ops.Weld()
    local out = {}
    eachCell(function(x, y, z, btype) out[cellKey(x, y, z)] = btype end)
    eachCell(function(x, y, z, btype)
        for _, d in ipairs({ {1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1} }) do
            local k = cellKey(x + d[1], y + d[2], z + d[3])
            if out[k] == nil then out[k] = btype end
        end
    end)
    applyCells(out)
    notifyOK("Weld", "Grew to " .. T.count .. " blocks", 3)
end

-- Melt: erode exposed blocks, rounding hard edges off.
function ops.Melt()
    local out, removed = {}, 0
    eachCell(function(x, y, z, btype)
        local exposed = 0
        for _, d in ipairs({ {1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1} }) do
            if T.cells[cellKey(x + d[1], y + d[2], z + d[3])] == nil then
                exposed = exposed + 1
            end
        end
        -- More exposed faces means more likely to melt away.
        if exposed >= 3 and hashNoise(x, y, z, T.seed) < (exposed / 6) then
            removed = removed + 1
        else
            out[cellKey(x, y, z)] = btype
        end
    end)
    applyCells(out)
    notifyOK("Melt", "Eroded " .. removed .. " blocks", 3)
end

-- Extrude: repeat the selection along an axis to make it solid or longer.
function ops.Extrude()
    local out = {}
    eachCell(function(x, y, z, btype) out[cellKey(x, y, z)] = btype end)
    local dx = T.axis == "X" and 1 or 0
    local dy = T.axis == "Y" and 1 or 0
    local dz = T.axis == "Z" and 1 or 0
    eachCell(function(x, y, z, btype)
        for i = 1, T.amount do
            out[cellKey(x + dx * i, y + dy * i, z + dz * i)] = btype
        end
    end)
    applyCells(out)
    notifyOK("Extrude", "Extended " .. T.amount .. " along " .. T.axis, 3)
end

-- Rock: replace the selection with a noisy blob filling its bounds.
function ops.Rock()
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    eachCell(function(x, y, z)
        if x < minX then minX = x end if x > maxX then maxX = x end
        if y < minY then minY = y end if y > maxY then maxY = y end
        if z < minZ then minZ = z end if z > maxZ then maxZ = z end
    end)
    if minX == math.huge then return end
    local cx, cy, cz = (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2
    local rx = math.max((maxX - minX) / 2, 1)
    local ry = math.max((maxY - minY) / 2, 1)
    local rz = math.max((maxZ - minZ) / 2, 1)
    local out, n = {}, 0
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                local d = ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 + ((z - cz) / rz) ^ 2
                local wobble = (hashNoise(x, y, z, T.seed) - 0.5) * (T.strength / 10)
                if d + wobble <= 1 then
                    out[cellKey(x, y, z)] = T.paintBlock
                    n = n + 1
                end
            end
        end
    end
    applyCells(out)
    notifyOK("Rock", "Carved a " .. n .. " block boulder", 3)
end

-- ── Text ───────────────────────────────────────────────────────────────────
-- Compact 5x7 uppercase font. Each entry is 7 rows of 5 bits, top row first.
local FONT = {
    A = {0x0E,0x11,0x11,0x1F,0x11,0x11,0x11}, B = {0x1E,0x11,0x11,0x1E,0x11,0x11,0x1E},
    C = {0x0E,0x11,0x10,0x10,0x10,0x11,0x0E}, D = {0x1E,0x11,0x11,0x11,0x11,0x11,0x1E},
    E = {0x1F,0x10,0x10,0x1E,0x10,0x10,0x1F}, F = {0x1F,0x10,0x10,0x1E,0x10,0x10,0x10},
    G = {0x0E,0x11,0x10,0x17,0x11,0x11,0x0F}, H = {0x11,0x11,0x11,0x1F,0x11,0x11,0x11},
    I = {0x0E,0x04,0x04,0x04,0x04,0x04,0x0E}, J = {0x07,0x02,0x02,0x02,0x02,0x12,0x0C},
    K = {0x11,0x12,0x14,0x18,0x14,0x12,0x11}, L = {0x10,0x10,0x10,0x10,0x10,0x10,0x1F},
    M = {0x11,0x1B,0x15,0x15,0x11,0x11,0x11}, N = {0x11,0x19,0x15,0x13,0x11,0x11,0x11},
    O = {0x0E,0x11,0x11,0x11,0x11,0x11,0x0E}, P = {0x1E,0x11,0x11,0x1E,0x10,0x10,0x10},
    Q = {0x0E,0x11,0x11,0x11,0x15,0x12,0x0D}, R = {0x1E,0x11,0x11,0x1E,0x14,0x12,0x11},
    S = {0x0F,0x10,0x10,0x0E,0x01,0x01,0x1E}, T = {0x1F,0x04,0x04,0x04,0x04,0x04,0x04},
    U = {0x11,0x11,0x11,0x11,0x11,0x11,0x0E}, V = {0x11,0x11,0x11,0x11,0x11,0x0A,0x04},
    W = {0x11,0x11,0x11,0x15,0x15,0x1B,0x11}, X = {0x11,0x11,0x0A,0x04,0x0A,0x11,0x11},
    Y = {0x11,0x11,0x0A,0x04,0x04,0x04,0x04}, Z = {0x1F,0x01,0x02,0x04,0x08,0x10,0x1F},
    ["0"] = {0x0E,0x11,0x13,0x15,0x19,0x11,0x0E}, ["1"] = {0x04,0x0C,0x04,0x04,0x04,0x04,0x0E},
    ["2"] = {0x0E,0x11,0x01,0x02,0x04,0x08,0x1F}, ["3"] = {0x1F,0x02,0x04,0x02,0x01,0x11,0x0E},
    ["4"] = {0x02,0x06,0x0A,0x12,0x1F,0x02,0x02}, ["5"] = {0x1F,0x10,0x1E,0x01,0x01,0x11,0x0E},
    ["6"] = {0x06,0x08,0x10,0x1E,0x11,0x11,0x0E}, ["7"] = {0x1F,0x01,0x02,0x04,0x08,0x08,0x08},
    ["8"] = {0x0E,0x11,0x11,0x0E,0x11,0x11,0x0E}, ["9"] = {0x0E,0x11,0x11,0x0F,0x01,0x02,0x0C},
    ["!"] = {0x04,0x04,0x04,0x04,0x04,0x00,0x04}, ["-"] = {0x00,0x00,0x00,0x1F,0x00,0x00,0x00},
    ["."] = {0x00,0x00,0x00,0x00,0x00,0x00,0x04},
}

function ops.Text()
    local str = tostring(T.text or ""):upper()
    if str == "" then
        notifyWarn("Text", "Type something in the Text box first", 3)
        return
    end
    -- Anchor the text where the player stands so it appears in front of them.
    local _, _, hrp = getCharacterParts()
    local ox, oy, oz = 0, 0, 0
    if hrp then ox, oy, oz = worldToCell(hrp.Position) end

    local out, n, col = {}, 0, 0
    for i = 1, #str do
        local ch = str:sub(i, i)
        if ch == " " then
            col = col + 3
        else
            local glyph = FONT[ch]
            if glyph then
                for row = 1, 7 do
                    local bits = glyph[row]
                    for bit = 0, 4 do
                        -- bit 4 is the leftmost pixel of the 5-wide glyph
                        if math.floor(bits / (2 ^ (4 - bit))) % 2 == 1 then
                            local x = ox + col + bit
                            local y = oy + (7 - row)
                            out[cellKey(x, y, oz)] = T.paintBlock
                            n = n + 1
                        end
                    end
                end
                col = col + 6
            end
        end
    end
    if n == 0 then
        notifyWarn("Text", "No drawable characters (A-Z, 0-9, -, ., !)", 4)
        return
    end
    applyCells(out)
    notifyOK("Text", "'" .. str .. "' -> " .. n .. " blocks", 4)
end

-- ── cursor draw tools ──────────────────────────────────────────────────────
-- These add to the cell map directly under the cursor rather than from a
-- selection, so you can sketch shapes freehand.
toolTab:CreateToggle({
    Name = "Freehand Draw",
    CurrentValue = false,
    Tooltip = "Hold left click and sweep to draw a single-block-thick trail of the primary block.",
    Callback = function(on)
        if not on then if T.mode == "Freehand Draw" then stopTool() end return end
        startTool("Freehand Draw", nil, function()
            local part = raycastBlock()
            if not part then return end
            local x, y, z = worldToCell(part.Position)
            selAdd(x, y + 1, z, T.paintBlock)   -- draw on top of the surface
            refreshStatus()
        end)
    end
})

toolTab:CreateToggle({
    Name = "Sculpt Draw",
    CurrentValue = false,
    Tooltip = "Hold left click to add a ball of blocks at the cursor, sized by Brush Radius.",
    Callback = function(on)
        if not on then if T.mode == "Sculpt Draw" then stopTool() end return end
        startTool("Sculpt Draw", nil, function()
            local part = raycastBlock()
            if not part then return end
            local cx, cy, cz = worldToCell(part.Position)
            local r = T.brushRadius
            for x = cx - r, cx + r do
                for y = cy - r, cy + r do
                    for z = cz - r, cz + r do
                        local d = (x - cx) ^ 2 + (y - cy) ^ 2 + (z - cz) ^ 2
                        if d <= r * r then selAdd(x, y, z, T.paintBlock) end
                    end
                end
            end
            refreshStatus()
        end)
    end
})

-- ═══════════════════════════════════════════════════════════════════════════
-- OPERATION BUTTONS
-- ═══════════════════════════════════════════════════════════════════════════
-- One dropdown plus one Run button, instead of a button per operation.
-- The description updates as you change the selection so nothing is lost.
local TOOL_OPS = {
    { "Painter",       "Repaint the whole selection in the primary block.",                          ops.Painter,      true  },
    { "Noise Painter", "Blend primary and secondary blocks using Mix % and Seed.",                   ops.NoisePainter, true  },
    { "Clentaminator", "Convert only 'Replace This Block' into the primary block.",                  ops.Clentaminator,true  },
    { "Rock",          "Replace the selection with a boulder. Strength controls lumpiness.",         ops.Rock,         true  },
    { "Extrude",       "Repeat the selection along Axis by Amount.",                                 ops.Extrude,      true  },
    { "Weld",          "Grow the selection outward one block, closing seams and pits.",              ops.Weld,         true  },
    { "Melt",          "Erode exposed blocks so hard edges round off.",                              ops.Melt,         true  },
    { "Shatter",       "Randomly delete Percent of the selection for a ruined look.",                ops.Shatter,      true  },
    { "Elevation",     "Shift the selection by Amount along Axis.",                                  ops.Elevation,    true  },
    { "Flatten",       "Level every column to the lowest point in the selection.",                   ops.Flatten,      true  },
    { "Slope",         "Ramp the surface by Amount across Axis.",                                    ops.Slope,        true  },
    { "Smooth",        "Average each column against its neighbours.",                                ops.Smooth,       true  },
    { "Roughen",       "Jitter surface heights by up to Strength.",                                  ops.Roughen,      true  },
    { "Distort",       "Randomly displace every block by up to Strength.",                           ops.Distort,      true  },
    { "Build Text",    "Turn the Text box into blocks in front of you (A-Z, 0-9, - . !).",           ops.Text,         false },
}

local toolOpNames = {}
for _, e in ipairs(TOOL_OPS) do toolOpNames[#toolOpNames + 1] = e[1] end

local chosenOp = TOOL_OPS[1]
local opDescPara

toolTab:CreateDivider()

toolTab:CreateDropdown({
    Name = "Operation",
    Options = toolOpNames, CurrentOption = { "Painter" }, MultipleOptions = false,
    Flag = "ToolOp",
    Callback = function(v)
        local name = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(TOOL_OPS) do
            if e[1] == name then
                chosenOp = e
                pcall(function()
                    opDescPara:Set({ Title = name, Content = e[2] })
                end)
                break
            end
        end
    end
})

opDescPara = toolTab:CreateParagraph({
    Title = TOOL_OPS[1][1],
    Content = TOOL_OPS[1][2],
})

toolTab:CreateInput({
    Name = "Text",
    Default = "HELLO",
    Callback = function(t) if t and t ~= "" then T.text = t end end
})

toolTab:CreateButton({
    Name = "Run Operation",
    Tooltip = "Run the operation chosen above on the current selection.",
    Callback = function()
        task.spawn(function()
            if chosenOp[4] ~= false and not requireSelection() then return end
            local ok, err = pcall(chosenOp[3])
            if not ok then notifyErr(chosenOp[1] .. " Failed", tostring(err), 5) end
        end)
    end
})

-- ═══════════════════════════════════════════════════════════════════════════
-- OUTPUT
-- ═══════════════════════════════════════════════════════════════════════════
toolTab:CreateDivider()

toolTab:CreateParagraph({
    Title = "How This Works",
    Content = "Tools never place blocks directly. When the result looks right, save it to a build file here, then use the Auto Build tab to place it.",
})

toolTab:CreateInput({
    Name = "Save As",
    Default = "MyEdit",
    Callback = function(t) if t and t ~= "" then T.outName = t end end
})

toolTab:CreateButton({
    Name = "Save Selection to Build File",
    Tooltip = "Write the current cell map to autoBuilder and select it in the Auto Build tab.",
    Callback = function()
        task.spawn(function()
            if not requireSelection() then return end
            local blocks = {}
            eachCell(function(x, y, z, btype)
                local p = cellToWorld(x, y, z)
                blocks[#blocks + 1] = {
                    blockType = btype,
                    upperBlock = false,
                    cframe = { p.X, p.Y, p.Z, 1, 0, 0, 0, 1, 0 },
                    parts = {},
                }
            end)
            local name = T.outName
            if name:lower():sub(-5) ~= ".json" then name = name .. ".json" end
            if not isfolder("autoBuilder") then makefolder("autoBuilder") end
            local ok, err = pcall(function()
                writefile("autoBuilder/" .. name, HttpService:JSONEncode({ blocks = blocks }))
            end)
            if not ok then
                notifyErr("Save Failed", tostring(err), 5)
                return
            end
            sendSaveWebhook(name)
            selectedFile = name
            savedPreviewTransform = nil
            pcall(function()
                fileDropdown:Refresh(getFiles(), true)
                fileDropdown:Set({ name })
            end)
            notifyOK("Saved", #blocks .. " blocks -> " .. name .. " (selected)", 6)
        end)
    end
})

toolTab:CreateButton({
    Name = "Load World Blocks into Selection",
    Tooltip = "Select every block on the nearest island, so you can run tools over an existing build.",
    Callback = function()
        task.spawn(function()
            confirm("Load Whole Island",
                "This selects every block on the nearest island. Large islands may take a moment.",
                "Load", function()
                    task.spawn(function()
                        local map = worldBlockMap()
                        local n = 0
                        T.cells = {} T.count = 0
                        for k, v in pairs(map) do T.cells[k] = v n = n + 1 end
                        T.count = n
                        redrawSelection()
                        refreshStatus()
                        notifyOK("Loaded", n .. " blocks selected", 5)
                    end)
                end)
        end)
    end
})

toolTab:CreateButton({
    Name = "Hide Selection Overlay",
    Tooltip = "Remove the blue highlight parts without clearing the selection.",
    Callback = function()
        clearHighlights()
        notify("Hidden", "Overlay cleared, selection kept", 2, "info")
    end
})

-- Expose the active tool on the on-screen watch list.
Duvome:AddWatch("Tool", function() return T.mode or false end)
Duvome:AddWatch("Selected Blocks", function() return T.count > 0 and T.count or false end)

end

-- ═══════════════════════════════════════════════════════════════════════════
-- BUILDER TAB — Axiom-style cuboid tools
--
-- One shared session drives every tool: pick two corners, a hologram appears,
-- nudge/flip/rotate it, then confirm. Undo and redo wrap every world change.
--
-- Placement reuses placeRawBlock. Destruction uses CLIENT_BLOCK_HIT_REQUEST,
-- the same remote PIHD uses to demolish blocks (read as reference only, PIHD
-- itself is untouched).
-- ═══════════════════════════════════════════════════════════════════════════
do

local BS = 3
local mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

local buildTab = tabEdit

-- ── remote for breaking blocks ─────────────────────────────────────────────
local hitRemote
pcall(function()
    hitRemote = ReplicatedStorage
        :WaitForChild("rbxts_include"):WaitForChild("node_modules")
        :WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out")
        :WaitForChild("_NetManaged"):WaitForChild("CLIENT_BLOCK_HIT_REQUEST")
end)

local function vcreate(x, y, z)
    if vector and vector.create then return vector.create(x, y, z) end
    return Vector3.new(x, y, z)
end

-- Payload shape mirrors PIHD's working demolish call.
local function breakPart(part)
    if not hitRemote or not part then return false end
    local ok = pcall(function()
        hitRemote:InvokeServer({
            Xoeoxuqilfgenamojfjmj = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nohIstskUiftvgjy",
            part = part,
            block = part,
            norm = vcreate(-3502.331787109375, 39.44426345825195, -3521.013671875),
            pos = vcreate(0.9916929006576538, 0.07807211577892303, -0.10222448408603668),
        })
    end)
    return ok
end

-- ── grid helpers ───────────────────────────────────────────────────────────
local function key3(x, y, z) return x .. "," .. y .. "," .. z end
local function toCell(p)
    return math.floor(p.X / BS + 0.5), math.floor(p.Y / BS + 0.5), math.floor(p.Z / BS + 0.5)
end
local function toWorld(x, y, z) return Vector3.new(x * BS, y * BS, z * BS) end

-- ── session state ──────────────────────────────────────────────────────────
local B = {
    tool = nil,
    a = nil, b = nil,            -- selection corners (cells)
    clip = nil,                  -- captured blocks, relative coords
    off = { 0, 0, 0 },           -- current nudge offset
    rotY = 0,                    -- 0/1/2/3 quarter turns
    flip = { false, false, false },
    holo = nil,
    undo = {}, redo = {},
    stackCount = 3,
    smearLen = 8,
    eraseLimit = 128,
    sym = nil,                   -- symmetry node cell
    symFlip = { false, false, false },
    symRot = false,
    conns = {},
}

local statusPara, histPara

local function setStatus(title, body)
    pcall(function() statusPara:Set({ Title = title, Content = body }) end)
end

local function refreshHistory()
    pcall(function()
        histPara:Set({
            Title = "History",
            Content = #B.undo .. " undo · " .. #B.redo .. " redo",
        })
    end)
end

-- ── world lookup ───────────────────────────────────────────────────────────
local function blockPartMap()
    local folder = getBlocksFolder()
    local map = {}
    if not folder then return map end
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "bedrock" and part.Name ~= "portalToSpawn" then
            local x, y, z = toCell(part.Position)
            map[key3(x, y, z)] = part
        end
    end
    return map
end

local function targetPart()
    local t = mouse.Target
    if t and t:IsA("BasePart") then
        local f = getBlocksFolder()
        if f and t:IsDescendantOf(f) then return t end
    end
    return nil
end

-- Dominant axis of where the camera is looking, as a unit cell step.
local function facingStep()
    local look = Camera and Camera.CFrame.LookVector or Vector3.new(0, 0, -1)
    local ax, ay, az = math.abs(look.X), math.abs(look.Y), math.abs(look.Z)
    if ax >= ay and ax >= az then return (look.X > 0 and 1 or -1), 0, 0, "X" end
    if ay >= ax and ay >= az then return 0, (look.Y > 0 and 1 or -1), 0, "Y" end
    return 0, 0, (look.Z > 0 and 1 or -1), "Z"
end

-- Held X/Y/Z forces movement onto a single axis.
local function axisLock()
    if UserInputService:IsKeyDown(Enum.KeyCode.X) then return "X" end
    if UserInputService:IsKeyDown(Enum.KeyCode.Y) then return "Y" end
    if UserInputService:IsKeyDown(Enum.KeyCode.Z) then return "Z" end
    return nil
end

local function ctrlDown()
    return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

-- ── hologram ───────────────────────────────────────────────────────────────
local function clearHolo()
    if B.holo then B.holo:Destroy() B.holo = nil end
end

local function holoFolder()
    if B.holo and B.holo.Parent then return B.holo end
    local f = Instance.new("Folder")
    f.Name = "IABBuilderHolo"
    f.Parent = Workspace
    B.holo = f
    return f
end

-- Apply rotation and flips to a relative coordinate.
local function xform(dx, dy, dz, sx, sy, sz)
    if B.flip[1] then dx = (sx - 1) - dx end
    if B.flip[2] then dy = (sy - 1) - dy end
    if B.flip[3] then dz = (sz - 1) - dz end
    for _ = 1, B.rotY do
        dx, dz = dz, (sx - 1) - dx      -- clockwise quarter turn about Y
        sx, sz = sz, sx
    end
    return dx, dy, dz
end

-- Resolve the clip into absolute cells at the current offset.
local function resolvedCells()
    local out = {}
    if not B.clip then return out end
    local sx, sy, sz = B.clip.sx, B.clip.sy, B.clip.sz
    for _, c in ipairs(B.clip.cells) do
        local dx, dy, dz = xform(c[1], c[2], c[3], sx, sy, sz)
        out[#out + 1] = {
            B.clip.ox + dx + B.off[1],
            B.clip.oy + dy + B.off[2],
            B.clip.oz + dz + B.off[3],
            c[4],
        }
    end
    return out
end

local MAX_HOLO = 2500
local function drawHolo()
    clearHolo()
    if not B.clip then return end
    local f = holoFolder()
    local cells = resolvedCells()
    local n = 0
    for _, c in ipairs(cells) do
        if n >= MAX_HOLO then break end
        local p = Instance.new("Part")
        p.Anchored = true p.CanCollide = false p.CanQuery = false
        p.Size = Vector3.new(BS, BS, BS)
        p.Position = toWorld(c[1], c[2], c[3])
        p.Transparency = 0.55
        p.Material = Enum.Material.Neon
        p.Color = Color3.fromRGB(90, 200, 255)
        p.Parent = f
        n = n + 1
    end
    -- Arrow showing which way a scroll-up will push the selection.
    local fx, fy, fz = facingStep()
    local lock = axisLock()
    if lock == "X" then fx, fy, fz = (fx >= 0 and 1 or -1), 0, 0
    elseif lock == "Y" then fx, fy, fz = 0, (fy >= 0 and 1 or -1), 0
    elseif lock == "Z" then fx, fy, fz = 0, 0, (fz >= 0 and 1 or -1) end
    if #cells > 0 then
        local sum = Vector3.new()
        for _, c in ipairs(cells) do sum = sum + toWorld(c[1], c[2], c[3]) end
        local mid = sum / #cells
        local arrow = Instance.new("Part")
        arrow.Anchored = true arrow.CanCollide = false arrow.CanQuery = false
        arrow.Size = Vector3.new(1, 1, BS * 3)
        arrow.CFrame = CFrame.lookAt(mid + Vector3.new(fx, fy, fz) * BS * 3,
            mid + Vector3.new(fx, fy, fz) * BS * 6)
        arrow.Color = Color3.fromRGB(255, 220, 60)
        arrow.Material = Enum.Material.Neon
        arrow.Parent = f
    end
end

-- ── selection ──────────────────────────────────────────────────────────────
local function selectionSize()
    if not (B.a and B.b) then return 0, 0, 0 end
    return math.abs(B.a[1] - B.b[1]) + 1,
           math.abs(B.a[2] - B.b[2]) + 1,
           math.abs(B.a[3] - B.b[3]) + 1
end

local function describeSelection()
    if not (B.a and B.b) then
        return "No selection. Left-click one corner, right-click the opposite."
    end
    local sx, sy, sz = selectionSize()
    return sx .. " x " .. sy .. " x " .. sz .. " (" .. (sx * sy * sz) .. " cells)"
end

local function drawSelectionBox()
    clearHolo()
    if not (B.a and B.b) then return end
    local f = holoFolder()
    local minX, maxX = math.min(B.a[1], B.b[1]), math.max(B.a[1], B.b[1])
    local minY, maxY = math.min(B.a[2], B.b[2]), math.max(B.a[2], B.b[2])
    local minZ, maxZ = math.min(B.a[3], B.b[3]), math.max(B.a[3], B.b[3])
    local p = Instance.new("Part")
    p.Anchored = true p.CanCollide = false p.CanQuery = false
    p.Size = Vector3.new((maxX - minX + 1) * BS, (maxY - minY + 1) * BS, (maxZ - minZ + 1) * BS)
    p.Position = Vector3.new((minX + maxX) / 2 * BS, (minY + maxY) / 2 * BS, (minZ + maxZ) / 2 * BS)
    p.Transparency = 0.75
    p.Color = Color3.fromRGB(255, 210, 70)
    p.Material = Enum.Material.Neon
    p.Parent = f
    local sb = Instance.new("SelectionBox")
    sb.Adornee = p
    sb.Color3 = Color3.fromRGB(255, 210, 70)
    sb.LineThickness = 0.06
    sb.Parent = p
end

-- Middle-click grows the box one step along the face you're looking at.
local function expandFace()
    if not (B.a and B.b) then return end
    local fx, fy, fz = facingStep()
    local lock = axisLock()
    if lock == "X" then fy, fz = 0, 0 elseif lock == "Y" then fx, fz = 0, 0
    elseif lock == "Z" then fx, fy = 0, 0 end
    -- Grow whichever corner sits on the face we're pushing.
    local function grow(i, d)
        if d == 0 then return end
        if (B.a[i] >= B.b[i]) == (d > 0) then B.a[i] = B.a[i] + d else B.b[i] = B.b[i] + d end
    end
    grow(1, fx) grow(2, fy) grow(3, fz)
    drawSelectionBox()
    setStatus(B.tool or "Builder", describeSelection())
end

-- Capture the world blocks inside the selection into a clip.
local function captureClip()
    if not (B.a and B.b) then return false end
    local map = blockPartMap()
    local minX, maxX = math.min(B.a[1], B.b[1]), math.max(B.a[1], B.b[1])
    local minY, maxY = math.min(B.a[2], B.b[2]), math.max(B.a[2], B.b[2])
    local minZ, maxZ = math.min(B.a[3], B.b[3]), math.max(B.a[3], B.b[3])
    local cells = {}
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                local part = map[key3(x, y, z)]
                if part then
                    cells[#cells + 1] = { x - minX, y - minY, z - minZ, part.Name }
                end
            end
        end
    end
    if #cells == 0 then
        notifyWarn("Empty", "No blocks inside that selection", 3)
        return false
    end
    B.clip = {
        cells = cells,
        ox = minX, oy = minY, oz = minZ,
        sx = maxX - minX + 1, sy = maxY - minY + 1, sz = maxZ - minZ + 1,
    }
    B.off = { 0, 0, 0 }
    B.rotY = 0
    B.flip = { false, false, false }
    return true
end

-- ── world mutation with undo records ───────────────────────────────────────
local function pushUndo(record)
    table.insert(B.undo, record)
    if #B.undo > 25 then table.remove(B.undo, 1) end
    B.redo = {}
    refreshHistory()
end

-- Place a list of {x,y,z,type}; returns the cells actually written.
local function placeCells(cells, record)
    local placed = {}
    local existing = blockPartMap()
    for i, c in ipairs(cells) do
        local k = key3(c[1], c[2], c[3])
        if not existing[k] then
            local p = toWorld(c[1], c[2], c[3])
            placeRawBlock(c[4], CFrame.new(p), false)
            placed[#placed + 1] = { c[1], c[2], c[3], c[4] }
        end
        if i % 20 == 0 then task.wait(placeDelay) else task.wait(0.01) end
    end
    if record then record.placed = placed end
    return placed
end

-- Break a list of cells; returns what was removed so undo can restore it.
local function eraseCells(cells, record)
    local map = blockPartMap()
    local removed = {}
    for i, c in ipairs(cells) do
        local part = map[key3(c[1], c[2], c[3])]
        if part then
            removed[#removed + 1] = { c[1], c[2], c[3], part.Name }
            breakPart(part)
        end
        if i % 20 == 0 then task.wait(0.05) else task.wait(0.01) end
    end
    if record then record.removed = removed end
    return removed
end

local function doUndo()
    local rec = table.remove(B.undo)
    if not rec then notifyWarn("Undo", "Nothing to undo", 2) return end
    task.spawn(function()
        setStatus("Undo", "Reverting...")
        if rec.placed and #rec.placed > 0 then eraseCells(rec.placed, nil) end
        if rec.removed and #rec.removed > 0 then placeCells(rec.removed, nil) end
        table.insert(B.redo, rec)
        refreshHistory()
        notifyOK("Undo", "Reverted " .. rec.label, 3)
        setStatus(B.tool or "Builder", describeSelection())
    end)
end

local function doRedo()
    local rec = table.remove(B.redo)
    if not rec then notifyWarn("Redo", "Nothing to redo", 2) return end
    task.spawn(function()
        setStatus("Redo", "Reapplying...")
        if rec.removed and #rec.removed > 0 then eraseCells(rec.removed, nil) end
        if rec.placed and #rec.placed > 0 then placeCells(rec.placed, nil) end
        table.insert(B.undo, rec)
        refreshHistory()
        notifyOK("Redo", "Reapplied " .. rec.label, 3)
    end)
end

-- ── symmetry ───────────────────────────────────────────────────────────────
-- Mirrors a cell about the symmetry node for each enabled modifier.
local function symmetryImages(x, y, z)
    if not B.sym then return {} end
    local out = {}
    local nx, ny, nz = B.sym[1], B.sym[2], B.sym[3]
    local function add(px, py, pz)
        if px == x and py == y and pz == z then return end
        out[#out + 1] = { px, py, pz }
    end
    if B.symFlip[1] then add(2 * nx - x, y, z) end
    if B.symFlip[2] then add(x, 2 * ny - y, z) end
    if B.symFlip[3] then add(x, y, 2 * nz - z) end
    if B.symFlip[1] and B.symFlip[3] then add(2 * nx - x, y, 2 * nz - z) end
    if B.symRot then
        local rx, rz = x - nx, z - nz
        for _ = 1, 3 do
            rx, rz = rz, -rx
            add(nx + rx, y, nz + rz)
        end
    end
    return out
end

local function symmetryActive()
    return B.sym ~= nil and (B.symFlip[1] or B.symFlip[2] or B.symFlip[3] or B.symRot)
end

local symNodePart
local function drawSymNode()
    if symNodePart then symNodePart:Destroy() symNodePart = nil end
    if not B.sym then return end
    local p = Instance.new("Part")
    p.Anchored = true p.CanCollide = false p.CanQuery = false
    p.Size = Vector3.new(1.2, 1.2, 1.2)
    p.Position = toWorld(B.sym[1], B.sym[2], B.sym[3])
    p.Material = Enum.Material.Neon
    p.Color = symmetryActive() and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(150, 150, 150)
    p.Parent = Workspace
    symNodePart = p
end

-- ── tool commits ───────────────────────────────────────────────────────────
local function withSymmetry(cells)
    if not symmetryActive() then return cells end
    local seen, out = {}, {}
    for _, c in ipairs(cells) do
        local k = key3(c[1], c[2], c[3])
        if not seen[k] then seen[k] = true out[#out + 1] = c end
        for _, img in ipairs(symmetryImages(c[1], c[2], c[3])) do
            local ik = key3(img[1], img[2], img[3])
            if not seen[ik] then
                seen[ik] = true
                out[#out + 1] = { img[1], img[2], img[3], c[4] }
            end
        end
    end
    return out
end

local busy = false
local function runCommit(label, fn)
    if busy then notifyWarn("Busy", "Another operation is running", 2) return end
    busy = true
    task.spawn(function()
        local rec = { label = label }
        local ok, err = pcall(fn, rec)
        if not ok then
            notifyErr(label .. " Failed", tostring(err), 5)
        else
            pushUndo(rec)
        end
        busy = false
        setStatus(B.tool or "Builder", describeSelection())
    end)
end

local function commitMove()
    runCommit("Move", function(rec)
        local src = {}
        for _, c in ipairs(B.clip.cells) do
            src[#src + 1] = { B.clip.ox + c[1], B.clip.oy + c[2], B.clip.oz + c[3], c[4] }
        end
        local dst = withSymmetry(resolvedCells())
        setStatus("Move", "Removing originals...")
        eraseCells(src, rec)
        setStatus("Move", "Placing " .. #dst .. " blocks...")
        placeCells(dst, rec)
        notifyOK("Move", #dst .. " blocks moved", 4)
        clearHolo()
        B.clip = nil
    end)
end

local function commitClone()
    runCommit("Clone", function(rec)
        local dst = withSymmetry(resolvedCells())
        setStatus("Clone", "Placing " .. #dst .. " blocks...")
        placeCells(dst, rec)
        notifyOK("Clone", #dst .. " blocks copied", 4)
    end)
end

local function commitStack()
    runCommit("Stack", function(rec)
        local fx, fy, fz = facingStep()
        local lock = axisLock()
        if lock == "X" then fy, fz = 0, 0 elseif lock == "Y" then fx, fz = 0, 0
        elseif lock == "Z" then fx, fy = 0, 0 end
        local sx, sy, sz = B.clip.sx, B.clip.sy, B.clip.sz
        local stepX, stepY, stepZ = fx * sx, fy * sy, fz * sz
        local all = {}
        for i = 1, B.stackCount do
            for _, c in ipairs(resolvedCells()) do
                all[#all + 1] = { c[1] + stepX * i, c[2] + stepY * i, c[3] + stepZ * i, c[4] }
            end
        end
        all = withSymmetry(all)
        setStatus("Stack", "Placing " .. #all .. " blocks...")
        placeCells(all, rec)
        notifyOK("Stack", B.stackCount .. " copies, " .. #all .. " blocks", 4)
    end)
end

local function commitSmear()
    runCommit("Smear", function(rec)
        local fx, fy, fz = facingStep()
        local lock = axisLock()
        if lock == "X" then fy, fz = 0, 0 elseif lock == "Y" then fx, fz = 0, 0
        elseif lock == "Z" then fx, fy = 0, 0 end
        local base = resolvedCells()
        local seen, all = {}, {}
        -- Stretch one block at a time so the result is continuous, not spaced.
        for step = 0, B.smearLen do
            for _, c in ipairs(base) do
                local x, y, z = c[1] + fx * step, c[2] + fy * step, c[3] + fz * step
                local k = key3(x, y, z)
                if not seen[k] then
                    seen[k] = true
                    all[#all + 1] = { x, y, z, c[4] }
                end
            end
        end
        all = withSymmetry(all)
        setStatus("Smear", "Placing " .. #all .. " blocks...")
        placeCells(all, rec)
        notifyOK("Smear", "Stretched " .. B.smearLen .. " blocks", 4)
    end)
end

local function commitErase()
    if not (B.a and B.b) then notifyWarn("Erase", "Make a selection first", 3) return end
    runCommit("Erase", function(rec)
        local minX, maxX = math.min(B.a[1], B.b[1]), math.max(B.a[1], B.b[1])
        local minY, maxY = math.min(B.a[2], B.b[2]), math.max(B.a[2], B.b[2])
        local minZ, maxZ = math.min(B.a[3], B.b[3]), math.max(B.a[3], B.b[3])
        local cells = {}
        for x = minX, maxX do
            for y = minY, maxY do
                for z = minZ, maxZ do cells[#cells + 1] = { x, y, z } end
            end
        end
        setStatus("Erase", "Removing " .. #cells .. " cells...")
        local removed = eraseCells(cells, rec)
        notifyOK("Erase", #removed .. " blocks removed", 4)
    end)
end

-- Erase Connected: flood fill the same block type, capped like Axiom's 128.
local function eraseConnected(part)
    if not part then return end
    runCommit("Erase Connected", function(rec)
        local map = blockPartMap()
        local sx, sy, sz = toCell(part.Position)
        local wanted = part.Name
        local queue = { { sx, sy, sz } }
        local seen = { [key3(sx, sy, sz)] = true }
        local cells = {}
        while #queue > 0 and #cells < B.eraseLimit do
            local c = table.remove(queue)
            local k = key3(c[1], c[2], c[3])
            local p = map[k]
            if p and p.Name == wanted then
                cells[#cells + 1] = { c[1], c[2], c[3] }
                for _, d in ipairs({ {1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1} }) do
                    local nk = key3(c[1] + d[1], c[2] + d[2], c[3] + d[3])
                    if not seen[nk] then
                        seen[nk] = true
                        queue[#queue + 1] = { c[1] + d[1], c[2] + d[2], c[3] + d[3] }
                    end
                end
            end
        end
        setStatus("Erase Connected", "Removing " .. #cells .. " blocks...")
        eraseCells(cells, rec)
        notifyOK("Erase Connected", #cells .. " x " .. wanted .. " removed", 4)
    end)
end

-- Extrude works on a face, with no selection at all.
local function extrudeFace(part, grow)
    if not part then return end
    runCommit(grow and "Extrude" or "Shrink", function(rec)
        local fx, fy, fz = facingStep()
        -- Push out against the way we're looking, so the near face moves toward us.
        fx, fy, fz = -fx, -fy, -fz
        local map = blockPartMap()
        local sx, sy, sz = toCell(part.Position)
        local wanted = part.Name
        -- Collect the connected same-type face slab.
        local queue = { { sx, sy, sz } }
        local seen = { [key3(sx, sy, sz)] = true }
        local face = {}
        while #queue > 0 and #face < 512 do
            local c = table.remove(queue)
            local p = map[key3(c[1], c[2], c[3])]
            if p and p.Name == wanted then
                face[#face + 1] = c
                for _, d in ipairs({ {1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1} }) do
                    -- stay in the plane perpendicular to the extrude direction
                    if not (d[1] == fx and fx ~= 0) and not (d[2] == fy and fy ~= 0)
                        and not (d[3] == fz and fz ~= 0) then
                        local nk = key3(c[1] + d[1], c[2] + d[2], c[3] + d[3])
                        if not seen[nk] then
                            seen[nk] = true
                            queue[#queue + 1] = { c[1] + d[1], c[2] + d[2], c[3] + d[3] }
                        end
                    end
                end
            end
        end
        if grow then
            local out = {}
            for _, c in ipairs(face) do
                out[#out + 1] = { c[1] + fx, c[2] + fy, c[3] + fz, wanted }
            end
            out = withSymmetry(out)
            placeCells(out, rec)
            notifyOK("Extrude", #out .. " blocks added", 3)
        else
            eraseCells(face, rec)
            notifyOK("Shrink", #face .. " blocks removed", 3)
        end
    end)
end

-- ── input handling ─────────────────────────────────────────────────────────
local function stopSession()
    for _, c in ipairs(B.conns) do pcall(function() c:Disconnect() end) end
    B.conns = {}
    B.tool = nil
    clearHolo()
    setStatus("Builder", "No tool active.")
end


local function startSession(toolName)
    for _, c in ipairs(B.conns) do pcall(function() c:Disconnect() end) end
    B.conns = {}
    B.tool = toolName
    setStatus(toolName, describeSelection())

    table.insert(B.conns, UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local t = input.UserInputType
        local k = input.KeyCode

        -- history
        if ctrlDown() and k == Enum.KeyCode.Z then doUndo() return end
        if ctrlDown() and k == Enum.KeyCode.Y then doRedo() return end
        -- modifiers on the live clip
        -- While the symmetry tool is active these keys configure the node
        -- instead of the clip, so the clip branches are skipped there.
        if ctrlDown() and k == Enum.KeyCode.F and B.clip and B.tool ~= "Setup Symmetry" then
            local _, _, _, axis = facingStep()
            local i = axis == "X" and 1 or (axis == "Y" and 2 or 3)
            B.flip[i] = not B.flip[i]
            drawHolo()
            notify("Flip", "Flipped on " .. axis, 2, "info")
            return
        end
        if ctrlDown() and k == Enum.KeyCode.R and B.clip and B.tool ~= "Setup Symmetry" then
            B.rotY = (B.rotY + 1) % 4
            drawHolo()
            notify("Rotate", (B.rotY * 90) .. " degrees", 2, "info")
            return
        end
        -- symmetry modifiers work whenever a node exists
        if ctrlDown() and k == Enum.KeyCode.F and B.sym then
            local _, _, _, axis = facingStep()
            local i = axis == "X" and 1 or (axis == "Y" and 2 or 3)
            B.symFlip[i] = not B.symFlip[i]
            drawSymNode()
            notify("Symmetry", "Flip " .. axis .. (B.symFlip[i] and " on" or " off"), 2, "info")
            return
        end
        if ctrlDown() and k == Enum.KeyCode.R and B.sym then
            B.symRot = not B.symRot
            drawSymNode()
            notify("Symmetry", "Rotation " .. (B.symRot and "on" or "off"), 2, "info")
            return
        end
        -- delete clears erase selection or the symmetry node
        if k == Enum.KeyCode.Delete or k == Enum.KeyCode.Backspace then
            if B.tool == "Setup Symmetry" and B.sym then
                B.sym = nil
                B.symFlip = { false, false, false }
                B.symRot = false
                drawSymNode()
                notify("Symmetry", "Node removed", 2, "info")
            elseif B.tool == "Erase" then
                commitErase()
            end
            return
        end

        if t == Enum.UserInputType.MouseButton1 then
            if B.tool == "Extrude" then
                extrudeFace(targetPart(), false)   -- left-click shrinks
                return
            end
            if B.tool == "Clone" and B.clip then
                -- left-click finishes a clone run
                clearHolo() B.clip = nil
                notify("Clone", "Finished", 2, "info")
                return
            end
            local p = targetPart()
            if p then
                local x, y, z = toCell(p.Position)
                B.a = { x, y, z }
                if not B.b then B.b = { x, y, z } end
                B.clip = nil
                drawSelectionBox()
                setStatus(B.tool, describeSelection())
            end

        elseif t == Enum.UserInputType.MouseButton2 then
            if B.tool == "Extrude" then
                extrudeFace(targetPart(), true)    -- right-click extrudes
                return
            end
            if B.tool == "Erase" then
                eraseConnected(targetPart())
                return
            end
            if B.tool == "Setup Symmetry" then
                local p = targetPart()
                if p then
                    local x, y, z = toCell(p.Position)
                    B.sym = { x, y, z }
                    drawSymNode()
                    notifyOK("Symmetry", "Node set. Ctrl+F / Ctrl+R to enable.", 4)
                end
                return
            end
            if B.clip then
                -- confirm the pending operation
                if B.tool == "Move" then commitMove()
                elseif B.tool == "Clone" then commitClone()
                elseif B.tool == "Stack" then commitStack()
                elseif B.tool == "Smear" then commitSmear() end
                return
            end
            local p = targetPart()
            if p then
                local x, y, z = toCell(p.Position)
                B.b = { x, y, z }
                if not B.a then B.a = { x, y, z } end
                drawSelectionBox()
                setStatus(B.tool, describeSelection())
            end

        elseif t == Enum.UserInputType.MouseButton3 then
            if B.clip then
                -- jump the clip to whatever we middle-clicked
                local p = targetPart()
                if p then
                    local x, y, z = toCell(p.Position)
                    B.off = { x - B.clip.ox, y - B.clip.oy, z - B.clip.oz }
                    drawHolo()
                end
            else
                expandFace()
            end
        end
    end))

    -- scroll nudges the clip, creating it on first scroll
    table.insert(B.conns, UserInputService.InputChanged:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
        if not (B.a and B.b) then return end
        if not B.clip then
            if not captureClip() then return end
            notify(B.tool or "Builder", "Hologram created. Scroll to nudge, right-click to confirm.", 3, "info")
        end
        local dir = input.Position.Z > 0 and 1 or -1
        local fx, fy, fz = facingStep()
        local lock = axisLock()
        if lock == "X" then fy, fz = 0, 0 elseif lock == "Y" then fx, fz = 0, 0
        elseif lock == "Z" then fx, fy = 0, 0 end
        B.off[1] = B.off[1] + fx * dir
        B.off[2] = B.off[2] + fy * dir
        B.off[3] = B.off[3] + fz * dir
        drawHolo()
        setStatus(B.tool, "Offset " .. B.off[1] .. ", " .. B.off[2] .. ", " .. B.off[3]
            .. (lock and ("  [" .. lock .. " locked]") or ""))
    end))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════════
buildTab:CreateSection("Builder", { Collapsible = true })

statusPara = buildTab:CreateParagraph({
    Title = "Builder",
    Content = "No tool active.",
})
histPara = buildTab:CreateParagraph({
    Title = "History",
    Content = "0 undo · 0 redo",
})

-- One dropdown picks the tool, one toggle arms it. Replaces seven toggles that
-- all had to be manually kept mutually exclusive.
B.toolList = {
    { "Move",           "Left-click a corner, right-click the opposite, scroll to lift the hologram, right-click to confirm. Originals are removed." },
    { "Clone",          "Same as Move but the originals stay. Right-click confirms a copy, left-click finishes." },
    { "Stack",          "Repeats the selection in a row. Scroll to aim, set Stack Count, right-click to confirm." },
    { "Smear",          "Stretches the selection between its origin and where you nudge it, filling every step." },
    { "Extrude",        "No selection needed. Right-click a face to extrude it out, left-click to shrink it back." },
    { "Erase",          "Select a cuboid then press Delete or Backspace. Right-click a block to erase connected blocks of that type." },
    { "Setup Symmetry", "Right-click to place the symmetry node, then Ctrl+F or Ctrl+R to enable mirroring for every other tool." },
}
B.toolNames = {}
for _, e in ipairs(B.toolList) do B.toolNames[#B.toolNames + 1] = e[1] end
B.pick = B.toolList[1]

buildTab:CreateDivider()

buildTab:CreateDropdown({
    Name = "Active Tool",
    Options = B.toolNames, CurrentOption = { "Move" }, MultipleOptions = false,
    Flag = "BldTool",
    Callback = function(v)
        local name = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(B.toolList) do
            if e[1] == name then
                B.pick = e
                pcall(function() B.pickDesc:Set({ Title = name, Content = e[2] }) end)
                break
            end
        end
        -- switching tools while armed re-arms the new one
        if B.tool then startSession(B.pick[1]) end
    end
})

B.pickDesc = buildTab:CreateParagraph({ Title = B.toolList[1][1], Content = B.toolList[1][2] })

B.armToggle = buildTab:CreateToggle({
    Name = "Enable Tool",
    CurrentValue = false,
    Tooltip = "Arms the selected tool so it captures your mouse and keyboard.",
    Callback = function(on)
        if on then startSession(B.pick[1]) else stopSession() end
    end
})

buildTab:CreateDivider()

buildTab:CreateSlider({
    Name = "Erase Connected Limit",
    Range = { 16, 512 }, Increment = 16, CurrentValue = 128, Suffix = "blk", Flag = "BldEraseLim",
    Callback = function(v) B.eraseLimit = v end
})

buildTab:CreateButton({
    Name = "Stop Tool",
    Tooltip = "Release the mouse and keyboard from the builder.",
    Callback = function()
        stopSession()
        pcall(function() B.armToggle:Set(false) end)
    end
})

buildTab:CreateDivider()

buildTab:CreateParagraph({
    Title = "Symmetry Node",
    Content = "With the Setup Symmetry tool active, right-click a block to drop the node. Grey means off, yellow means active. Ctrl+F toggles a mirror on the axis you face, Ctrl+R toggles 4-way rotation. Delete removes the node.",
})

buildTab:CreateButton({
    Name = "Clear Symmetry",
    Tooltip = "Remove the symmetry node and all its modifiers.",
    Callback = function()
        B.sym = nil
        B.symFlip = { false, false, false }
        B.symRot = false
        drawSymNode()
        notify("Symmetry", "Cleared", 2, "info")
    end
})

buildTab:CreateDivider()
buildTab:CreateParagraph({
    Title = "Mouse",
    Content = "Left-click: first corner (Extrude: shrink face, Clone: finish)\nRight-click: second corner, then confirm (Extrude: extrude, Erase: erase connected)\nMiddle-click: expand the selection face, or jump the hologram to the clicked block\nScroll: nudge one block, away on scroll-up, based on where you face",
})
buildTab:CreateParagraph({
    Title = "Keyboard",
    Content = "Hold X / Y / Z: lock movement to that axis\nCtrl+F: flip on the axis you face\nCtrl+R: rotate 90 degrees clockwise\nCtrl+Z / Ctrl+Y: undo / redo\nDelete or Backspace: erase the selection, or remove the symmetry node",
})

Duvome:AddWatch("Builder", function() return B.tool or false end)
Duvome:AddWatch("Symmetry", function()
    if not B.sym then return false end
    return symmetryActive() and "on" or "node set"
end)

-- Hand the Builder's state and helpers to the Operations/Colour scope. They
-- must live in their own block: Luau allows only 200 locals per scope and the
-- Builder already sits near that ceiling.
BuilderAPI.B                = B
BuilderAPI.key3             = key3
BuilderAPI.toCell           = toCell
BuilderAPI.blockPartMap     = blockPartMap
BuilderAPI.placeCells       = placeCells
BuilderAPI.eraseCells       = eraseCells
BuilderAPI.runCommit        = runCommit
BuilderAPI.drawSelectionBox = drawSelectionBox
BuilderAPI.describeSelection= describeSelection
BuilderAPI.setStatus        = setStatus
BuilderAPI.doUndo           = doUndo
BuilderAPI.doRedo           = doRedo
BuilderAPI.ctrlDown         = ctrlDown
BuilderAPI.startSession     = startSession
BuilderAPI.stopSession      = stopSession
BuilderAPI.targetPart       = targetPart

end

-- ═══════════════════════════════════════════════════════════════════════════
-- Operations and Colour run in their own scope, importing the Builder API.
-- ═══════════════════════════════════════════════════════════════════════════
do

local BA = BuilderAPI
local B = BA.B
local key3, toCell = BA.key3, BA.toCell
local blockPartMap, placeCells, eraseCells, runCommit =
    BA.blockPartMap, BA.placeCells, BA.eraseCells, BA.runCommit
local drawSelectionBox, describeSelection, setStatus =
    BA.drawSelectionBox, BA.describeSelection, BA.setStatus
local doUndo, doRedo, ctrlDown = BA.doUndo, BA.doRedo, BA.ctrlDown
local startSession, stopSession, targetPart = BA.startSession, BA.stopSession, BA.targetPart

-- ═══════════════════════════════════════════════════════════════════════════
-- OPERATIONS TAB — Axiom-style Editor operations
--
-- Lives inside the Builder scope on purpose: every operation acts on the
-- Builder's selection and routes through its placeCells/eraseCells/undo stack,
-- so Ctrl+Z reverts an operation exactly like it reverts a Move.
-- ═══════════════════════════════════════════════════════════════════════════

local opsTab = tabEdit

local O = {
    activeBlock = "stone",
    palette = {},
    gradFrom = "stone",
    gradTo = "whiteBlock",
    replaceFrom = "stone",
    filterBlock = "stone",
    expandBy = 1,
    keepExisting = true,
    pasteAir = false,
    shadeDark = "stone",
    shadeMid = "whiteBlock",
    shadeLight = "snow",
    clip = nil,          -- clipboard: { cells = {{dx,dy,dz,type}}, sx, sy, sz }
    blueprintName = "MyBlueprint",
    floodLimit = 512,
    presetName = "MyPreset",
}

local opsStatus, analyzePara

local function opsSet(title, body)
    pcall(function() opsStatus:Set({ Title = title, Content = body }) end)
end

-- Cells of the current cuboid selection, regardless of what is in them.
local function selBounds()
    if not (B.a and B.b) then return nil end
    return math.min(B.a[1], B.b[1]), math.max(B.a[1], B.b[1]),
           math.min(B.a[2], B.b[2]), math.max(B.a[2], B.b[2]),
           math.min(B.a[3], B.b[3]), math.max(B.a[3], B.b[3])
end

local function needSelection()
    if not (B.a and B.b) then
        notifyWarn("No Selection", "Use the Builder tab to pick two corners first", 4)
        return false
    end
    return true
end

local function selCells()
    local minX, maxX, minY, maxY, minZ, maxZ = selBounds()
    local out = {}
    if not minX then return out end
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do out[#out + 1] = { x, y, z } end
        end
    end
    return out
end

-- ── Tool Masks ─────────────────────────────────────────────────────────────
-- A rule that each candidate block must satisfy before an operation touches it.
-- Covers the useful subset of Axiom's mask rules; Invert gives the NOT case.
O.mask = { on = false, rule = "Surface", block = "stone", invert = false, y = 0, radius = 2 }
O.maskExpr = "y > 40"
O.maskFn = nil

-- Compiles a one-line Lua condition into a mask. Variables available:
-- x, y, z (grid cell) and name (block type under the cell).
function O.setMaskExpr(text)
    local src = "return function(x, y, z, name) return (" .. tostring(text) .. ") and true or false end"
    local chunk = loadstring(src)
    if not chunk then return false, "could not compile" end
    local ok, fn = pcall(chunk)
    if not ok or type(fn) ~= "function" then return false, tostring(fn) end
    O.maskFn = fn
    O.maskExpr = text
    return true
end

O.maskRules = {
    { "Surface",       "Only blocks with air on at least one side." },
    { "Block Is",      "Only blocks matching the mask block." },
    { "Above Is",      "Only blocks with the mask block directly above." },
    { "Below Is",      "Only blocks with the mask block directly below." },
    { "Neighbour Is",  "Only blocks with the mask block on any of the six sides." },
    { "Adjacent Is",   "Only blocks with the mask block horizontally beside them." },
    { "Near Is",       "Only blocks with the mask block inside the mask radius." },
    { "Can See Sky",   "Only blocks with nothing above them." },
    { "Y Above",       "Only blocks above the mask Y level." },
    { "Y Below",       "Only blocks below the mask Y level." },
    { "Lua Expression","Your own condition, e.g. y > 40 and name == \"stone\"." },
}

O.sides = { {1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1} }
O.flat  = { {1,0,0},{-1,0,0},{0,0,1},{0,0,-1} }

-- Returns true when the block at this cell passes the active mask.
function O.maskAllows(map, x, y, z)
    if not O.mask.on then return true end
    local m = O.mask
    local hit = false

    if m.rule == "Surface" then
        for _, d in ipairs(O.sides) do
            if not map[key3(x + d[1], y + d[2], z + d[3])] then hit = true break end
        end
    elseif m.rule == "Block Is" then
        local p = map[key3(x, y, z)]
        hit = p ~= nil and p.Name == m.block
    elseif m.rule == "Above Is" then
        local p = map[key3(x, y + 1, z)]
        hit = p ~= nil and p.Name == m.block
    elseif m.rule == "Below Is" then
        local p = map[key3(x, y - 1, z)]
        hit = p ~= nil and p.Name == m.block
    elseif m.rule == "Neighbour Is" then
        for _, d in ipairs(O.sides) do
            local p = map[key3(x + d[1], y + d[2], z + d[3])]
            if p and p.Name == m.block then hit = true break end
        end
    elseif m.rule == "Adjacent Is" then
        for _, d in ipairs(O.flat) do
            local p = map[key3(x + d[1], y + d[2], z + d[3])]
            if p and p.Name == m.block then hit = true break end
        end
    elseif m.rule == "Near Is" then
        local r = m.radius
        for ox = -r, r do
            for oy = -r, r do
                for oz = -r, r do
                    local p = map[key3(x + ox, y + oy, z + oz)]
                    if p and p.Name == m.block then hit = true break end
                end
                if hit then break end
            end
            if hit then break end
        end
    elseif m.rule == "Can See Sky" then
        hit = true
        for up = y + 1, y + 40 do
            if map[key3(x, up, z)] then hit = false break end
        end
    elseif m.rule == "Y Above" then
        hit = y > m.y
    elseif m.rule == "Y Below" then
        hit = y < m.y
    elseif m.rule == "Lua Expression" then
        if O.maskFn then
            local p = map[key3(x, y, z)]
            local ok, res = pcall(O.maskFn, x, y, z, p and p.Name or "")
            hit = ok and res == true
        end
    end

    if m.invert then return not hit end
    return hit
end

-- ── Fill family ────────────────────────────────────────────────────────────
-- mode picks which shell of the cuboid gets written.
local function fillMode(mode)
    if not needSelection() then return end
    runCommit("Fill", function(rec)
        local minX, maxX, minY, maxY, minZ, maxZ = selBounds()
        O.fillMap = blockPartMap()
        local want = {}
        for x = minX, maxX do
            for y = minY, maxY do
                for z = minZ, maxZ do
                    local onX = (x == minX or x == maxX)
                    local onY = (y == minY or y == maxY)
                    local onZ = (z == minZ or z == maxZ)
                    local take = false
                    if mode == "Fill" then
                        take = true
                    elseif mode == "Outline" then
                        -- an edge of the cuboid lies on two faces at once
                        local faces = (onX and 1 or 0) + (onY and 1 or 0) + (onZ and 1 or 0)
                        take = faces >= 2
                    elseif mode == "Walls" then
                        take = onX or onZ
                    elseif mode == "Top" then
                        take = (y == maxY)
                    elseif mode == "Bottom" then
                        take = (y == minY)
                    end
                    if take and O.maskAllows(O.fillMap, x, y, z) then
                        want[#want + 1] = { x, y, z, O.activeBlock }
                    end
                end
            end
        end
        if not O.keepExisting then eraseCells(want, rec) end
        opsSet("Fill", "Placing " .. #want .. " blocks...")
        placeCells(want, rec)
        notifyOK("Fill " .. mode, #want .. " blocks of " .. O.activeBlock, 4)
    end)
end

-- Fill Nearest: every empty cell copies whatever solid block is closest.
local function fillNearest()
    if not needSelection() then return end
    runCommit("Fill Nearest", function(rec)
        local map = blockPartMap()
        local solids = {}
        for k, part in pairs(map) do
            local x, y, z = k:match("(-?%d+),(-?%d+),(-?%d+)")
            solids[#solids + 1] = { tonumber(x), tonumber(y), tonumber(z), part.Name }
        end
        if #solids == 0 then notifyWarn("Fill Nearest", "No blocks nearby to sample", 3) return end
        local want = {}
        for _, c in ipairs(selCells()) do
            if not map[key3(c[1], c[2], c[3])] then
                local best, bestD = nil, math.huge
                for _, s in ipairs(solids) do
                    local d = (s[1] - c[1]) ^ 2 + (s[2] - c[2]) ^ 2 + (s[3] - c[3]) ^ 2
                    if d < bestD then bestD = d best = s end
                end
                if best then want[#want + 1] = { c[1], c[2], c[3], best[4] } end
            end
        end
        opsSet("Fill Nearest", "Placing " .. #want .. " blocks...")
        placeCells(want, rec)
        notifyOK("Fill Nearest", #want .. " blocks filled", 4)
    end)
end

-- ── Replace ────────────────────────────────────────────────────────────────
local function replaceBlocks()
    if not needSelection() then return end
    runCommit("Replace", function(rec)
        local map = blockPartMap()
        local hits = {}
        for _, c in ipairs(selCells()) do
            local part = map[key3(c[1], c[2], c[3])]
            if part and part.Name == O.replaceFrom and O.maskAllows(map, c[1], c[2], c[3]) then
                hits[#hits + 1] = { c[1], c[2], c[3], O.activeBlock }
            end
        end
        if #hits == 0 then notifyWarn("Replace", "No " .. O.replaceFrom .. " in selection", 3) return end
        opsSet("Replace", "Swapping " .. #hits .. " blocks...")
        eraseCells(hits, rec)
        placeCells(hits, rec)
        notifyOK("Replace", #hits .. " x " .. O.replaceFrom .. " -> " .. O.activeBlock, 4)
    end)
end

-- ── Hollow / Fill Gaps ─────────────────────────────────────────────────────
local function isEnclosed(map, x, y, z)
    for _, d in ipairs({ {1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1} }) do
        if not map[key3(x + d[1], y + d[2], z + d[3])] then return false end
    end
    return true
end

local function hollowSelection()
    if not needSelection() then return end
    runCommit("Hollow", function(rec)
        local map = blockPartMap()
        local inner = {}
        for _, c in ipairs(selCells()) do
            if map[key3(c[1], c[2], c[3])] and isEnclosed(map, c[1], c[2], c[3]) then
                inner[#inner + 1] = c
            end
        end
        if #inner == 0 then notifyWarn("Hollow", "Nothing enclosed to remove", 3) return end
        opsSet("Hollow", "Removing " .. #inner .. " interior blocks...")
        eraseCells(inner, rec)
        notifyOK("Hollow", #inner .. " interior blocks removed", 4)
    end)
end

local function fillGaps()
    if not needSelection() then return end
    runCommit("Fill Gaps", function(rec)
        local map = blockPartMap()
        local gaps = {}
        for _, c in ipairs(selCells()) do
            if not map[key3(c[1], c[2], c[3])] and isEnclosed(map, c[1], c[2], c[3]) then
                gaps[#gaps + 1] = { c[1], c[2], c[3], O.activeBlock }
            end
        end
        if #gaps == 0 then notifyWarn("Fill Gaps", "No enclosed gaps found", 3) return end
        opsSet("Fill Gaps", "Filling " .. #gaps .. " gaps...")
        placeCells(gaps, rec)
        notifyOK("Fill Gaps", #gaps .. " gaps filled", 4)
    end)
end

-- ── Drain ──────────────────────────────────────────────────────────────────
local function looksLikeWater(name)
    local n = tostring(name):lower()
    return n:find("water") ~= nil or n:find("liquid") ~= nil
end

local function drainSelection()
    if not needSelection() then return end
    runCommit("Drain", function(rec)
        local map = blockPartMap()
        local wet = {}
        for _, c in ipairs(selCells()) do
            local part = map[key3(c[1], c[2], c[3])]
            if part and looksLikeWater(part.Name) then wet[#wet + 1] = c end
        end
        if #wet == 0 then notifyWarn("Drain", "No water in selection", 3) return end
        eraseCells(wet, rec)
        notifyOK("Drain", #wet .. " water blocks removed", 4)
    end)
end

-- ── Simulate Gravity ───────────────────────────────────────────────────────
local function simulateGravity()
    if not needSelection() then return end
    runCommit("Simulate Gravity", function(rec)
        local map = blockPartMap()
        local minX, maxX, minY, maxY, minZ, maxZ = selBounds()

        -- Support must be judged against blocks OUTSIDE the selection, since
        -- everything inside it is about to fall too.
        local outside = {}
        for k, part in pairs(map) do
            local sx, sy, sz = k:match("(-?%d+),(-?%d+),(-?%d+)")
            sx, sy, sz = tonumber(sx), tonumber(sy), tonumber(sz)
            local inSel = sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
                and sz >= minZ and sz <= maxZ
            if not inSel then outside[k] = part end
        end

        local moves = {}
        -- Walk each column bottom-up so blocks stack instead of overlapping.
        for x = minX, maxX do
            for z = minZ, maxZ do
                local stack = {}
                for y = minY, maxY do
                    local part = map[key3(x, y, z)]
                    if part then stack[#stack + 1] = part.Name end
                end
                -- Fall while the cell below is empty, stopping on solid ground.
                local restY = minY
                while restY - 1 >= minY - 64 and not outside[key3(x, restY - 1, z)] do
                    restY = restY - 1
                end
                for i, name in ipairs(stack) do
                    moves[#moves + 1] = { x, restY + i - 1, z, name }
                end
            end
        end
        local old = {}
        for _, c in ipairs(selCells()) do
            if map[key3(c[1], c[2], c[3])] then old[#old + 1] = c end
        end
        opsSet("Simulate Gravity", "Settling " .. #moves .. " blocks...")
        eraseCells(old, rec)
        placeCells(moves, rec)
        notifyOK("Simulate Gravity", #moves .. " blocks settled", 4)
    end)
end

-- ── Smoothsnow ─────────────────────────────────────────────────────────────
local function smoothSnow()
    if not needSelection() then return end
    runCommit("Smoothsnow", function(rec)
        local map = blockPartMap()
        local minX, maxX, _, maxY, minZ, maxZ = selBounds()
        local caps = {}
        for x = minX, maxX do
            for z = minZ, maxZ do
                -- top-most solid in this column, then cap it
                for y = maxY, -64, -1 do
                    if map[key3(x, y, z)] then
                        if not map[key3(x, y + 1, z)] then
                            caps[#caps + 1] = { x, y + 1, z, O.activeBlock }
                        end
                        break
                    end
                end
            end
        end
        if #caps == 0 then notifyWarn("Smoothsnow", "No surfaces found", 3) return end
        placeCells(caps, rec)
        notifyOK("Smoothsnow", #caps .. " surface blocks capped", 4)
    end)
end

-- ── Palette Painter (the biome-painter analogue) ───────────────────────────
-- Scatters the saved palette across the selection instead of one flat block.
function O.palettePaint()
    if not needSelection() then return end
    if #O.palette == 0 then
        notifyWarn("Palette Painter", "Save some blocks to the Palette first", 4)
        return
    end
    runCommit("Palette Painter", function(rec)
        local map = blockPartMap()
        local want = {}
        for _, c in ipairs(selCells()) do
            if map[key3(c[1], c[2], c[3])] and O.maskAllows(map, c[1], c[2], c[3]) then
                want[#want + 1] = { c[1], c[2], c[3], O.palette[math.random(1, #O.palette)] }
            end
        end
        if #want == 0 then notifyWarn("Palette Painter", "Nothing matched", 3) return end
        opsSet("Palette Painter", "Scattering " .. #want .. " blocks...")
        eraseCells(want, rec)
        placeCells(want, rec)
        notifyOK("Palette Painter", #want .. " blocks from " .. #O.palette .. " types", 5)
    end)
end

-- ── Floodfill ──────────────────────────────────────────────────────────────
-- Recolours every connected block of the same type as the one under the cursor.
function O.floodfill()
    local part = targetPart()
    if not part then
        notifyWarn("Floodfill", "Point at a block first, then press Run", 4)
        return
    end
    runCommit("Floodfill", function(rec)
        local map = blockPartMap()
        local sx, sy, sz = toCell(part.Position)
        local wanted = part.Name
        local queue, seen, cells = { { sx, sy, sz } }, { [key3(sx, sy, sz)] = true }, {}
        while #queue > 0 and #cells < O.floodLimit do
            local c = table.remove(queue)
            local p = map[key3(c[1], c[2], c[3])]
            if p and p.Name == wanted then
                cells[#cells + 1] = { c[1], c[2], c[3], O.activeBlock }
                for _, d in ipairs(O.sides) do
                    local nk = key3(c[1] + d[1], c[2] + d[2], c[3] + d[3])
                    if not seen[nk] then
                        seen[nk] = true
                        queue[#queue + 1] = { c[1] + d[1], c[2] + d[2], c[3] + d[3] }
                    end
                end
            end
        end
        if #cells == 0 then notifyWarn("Floodfill", "Nothing connected", 3) return end
        opsSet("Floodfill", "Recolouring " .. #cells .. " blocks...")
        eraseCells(cells, rec)
        placeCells(cells, rec)
        notifyOK("Floodfill", #cells .. " x " .. wanted .. " -> " .. O.activeBlock, 5)
    end)
end

-- ── Stamp ──────────────────────────────────────────────────────────────────
-- Drops the clipboard on whatever block the cursor is on.
function O.stampAtCursor()
    if not O.clip then notifyWarn("Stamp", "Copy something or load a blueprint first", 4) return end
    local part = targetPart()
    if not part then notifyWarn("Stamp", "Point at a block first, then press Run", 4) return end
    runCommit("Stamp", function(rec)
        local ox, oy, oz = toCell(part.Position)
        local want = {}
        for _, c in ipairs(O.clip.cells) do
            want[#want + 1] = { ox + c[1], oy + c[2] + 1, oz + c[3], c[4] }
        end
        opsSet("Stamp", "Placing " .. #want .. " blocks...")
        placeCells(want, rec)
        notifyOK("Stamp", #want .. " blocks stamped", 4)
    end)
end

-- ── Analyze ────────────────────────────────────────────────────────────────
local function analyzeSelection()
    if not needSelection() then return end
    task.spawn(function()
        local map = blockPartMap()
        local counts, total = {}, 0
        for _, c in ipairs(selCells()) do
            local part = map[key3(c[1], c[2], c[3])]
            if part then
                counts[part.Name] = (counts[part.Name] or 0) + 1
                total = total + 1
            end
        end
        if total == 0 then
            pcall(function() analyzePara:Set({ Title = "Analyze", Content = "Selection is empty." }) end)
            notifyWarn("Analyze", "No blocks in selection", 3)
            return
        end
        local rows = {}
        for name, n in pairs(counts) do rows[#rows + 1] = { name, n } end
        table.sort(rows, function(p, q) return p[2] > q[2] end)
        local lines = {}
        for i = 1, math.min(#rows, 12) do
            local name, n = rows[i][1], rows[i][2]
            lines[#lines + 1] = string.format("%s  %d  (%.1f%%)", name, n, n / total * 100)
        end
        if #rows > 12 then lines[#lines + 1] = "... and " .. (#rows - 12) .. " more types" end
        lines[#lines + 1] = "TOTAL  " .. total .. "  (100%)"
        pcall(function()
            analyzePara:Set({ Title = "Analyze", Content = table.concat(lines, "\n") })
        end)
        notifyOK("Analyze", #rows .. " block types, " .. total .. " blocks", 5)
    end)
end

-- ── Autoshade ──────────────────────────────────────────────────────────────
-- Ambient-occlusion style: the more neighbours a block has, the darker it gets.
local function autoshade()
    if not needSelection() then return end
    runCommit("Autoshade", function(rec)
        local map = blockPartMap()
        local surface = {}
        for _, c in ipairs(selCells()) do
            local k = key3(c[1], c[2], c[3])
            if map[k] and not map[key3(c[1], c[2] + 1, c[3])] then
                -- count occupied neighbours in a 3x3x3 shell as the occlusion term
                local occ = 0
                for ox = -1, 1 do
                    for oy = -1, 1 do
                        for oz = -1, 1 do
                            if not (ox == 0 and oy == 0 and oz == 0)
                                and map[key3(c[1] + ox, c[2] + oy, c[3] + oz)] then
                                occ = occ + 1
                            end
                        end
                    end
                end
                surface[#surface + 1] = { c[1], c[2], c[3], occ }
            end
        end
        if #surface == 0 then notifyWarn("Autoshade", "No exposed surface in selection", 3) return end
        local want = {}
        for _, s in ipairs(surface) do
            local occ = s[4]
            local block
            if occ >= 16 then block = O.shadeDark
            elseif occ >= 9 then block = O.shadeMid
            else block = O.shadeLight end
            want[#want + 1] = { s[1], s[2], s[3], block }
        end
        opsSet("Autoshade", "Shading " .. #want .. " surface blocks...")
        eraseCells(want, rec)
        placeCells(want, rec)
        notifyOK("Autoshade", #want .. " surface blocks shaded", 5)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SELECTION MODIFIERS (shape only, blocks untouched)
-- ═══════════════════════════════════════════════════════════════════════════
local function growSelection(by)
    if not needSelection() then return end
    -- Corners can be stored in any order, so normalise before growing,
    -- otherwise "expand" would shrink whichever axis is stored backwards.
    local minX, maxX, minY, maxY, minZ, maxZ = selBounds()
    B.a = { minX - by, minY - by, minZ - by }
    B.b = { maxX + by, maxY + by, maxZ + by }
    -- Never let a shrink collapse the box inside out.
    for i = 1, 3 do
        if B.a[i] > B.b[i] then
            local mid = math.floor((B.a[i] + B.b[i]) / 2)
            B.a[i], B.b[i] = mid, mid
        end
    end
    drawSelectionBox()
    setStatus(B.tool or "Builder", describeSelection())
    notifyOK(by > 0 and "Expand" or "Shrink", "Selection resized by " .. math.abs(by), 3)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CLIPBOARD
-- ═══════════════════════════════════════════════════════════════════════════
-- onDone runs after the clipboard is populated, so callers that want to paste
-- straight away (Ctrl+J duplicate) don't race the spawned copy.
local function copySelection(cut, onDone)
    if not needSelection() then return end
    task.spawn(function()
        local map = blockPartMap()
        local minX, maxX, minY, maxY, minZ, maxZ = selBounds()
        local cells = {}
        for x = minX, maxX do
            for y = minY, maxY do
                for z = minZ, maxZ do
                    local part = map[key3(x, y, z)]
                    if part then
                        cells[#cells + 1] = { x - minX, y - minY, z - minZ, part.Name }
                    end
                end
            end
        end
        if #cells == 0 then notifyWarn("Copy", "Selection is empty", 3) return end
        O.clip = {
            cells = cells,
            sx = maxX - minX + 1, sy = maxY - minY + 1, sz = maxZ - minZ + 1,
        }
        notifyOK(cut and "Cut" or "Copy", #cells .. " blocks on the clipboard", 4)
        if onDone then onDone() end
        if cut then
            runCommit("Cut", function(rec)
                local abs = {}
                for _, c in ipairs(cells) do
                    abs[#abs + 1] = { minX + c[1], minY + c[2], minZ + c[3] }
                end
                eraseCells(abs, rec)
            end)
        end
    end)
end

-- Paste lands at the selection's low corner, or at the player if none is set.
local function pasteClipboard()
    if not O.clip then notifyWarn("Paste", "Clipboard is empty", 3) return end
    runCommit("Paste", function(rec)
        local ox, oy, oz
        local minX, _, minY, _, minZ = selBounds()
        if minX then
            ox, oy, oz = minX, minY, minZ
        else
            local _, _, hrp = getCharacterParts()
            if not hrp then notifyWarn("Paste", "No selection and no character", 3) return end
            ox, oy, oz = toCell(hrp.Position)
        end
        local want = {}
        for _, c in ipairs(O.clip.cells) do
            want[#want + 1] = { ox + c[1], oy + c[2], oz + c[3], c[4] }
        end
        if not O.keepExisting then eraseCells(want, rec) end
        opsSet("Paste", "Placing " .. #want .. " blocks...")
        placeCells(want, rec)
        notifyOK("Paste", #want .. " blocks pasted", 4)
    end)
end

-- Scale the clipboard by whole factors, nearest-neighbour style.
local function scaleClipboard(factor)
    if not O.clip then notifyWarn("Scale", "Clipboard is empty", 3) return end
    local out = {}
    for _, c in ipairs(O.clip.cells) do
        for dx = 0, factor - 1 do
            for dy = 0, factor - 1 do
                for dz = 0, factor - 1 do
                    out[#out + 1] = {
                        c[1] * factor + dx, c[2] * factor + dy, c[3] * factor + dz, c[4]
                    }
                end
            end
        end
    end
    O.clip = {
        cells = out,
        sx = O.clip.sx * factor, sy = O.clip.sy * factor, sz = O.clip.sz * factor,
    }
    notifyOK("Scale" .. factor .. "x", #out .. " blocks on the clipboard", 4)
end

local function flipClipboard(axis)
    if not O.clip then notifyWarn("Flip", "Clipboard is empty", 3) return end
    local i = axis == "X" and 1 or (axis == "Y" and 2 or 3)
    local size = axis == "X" and O.clip.sx or (axis == "Y" and O.clip.sy or O.clip.sz)
    for _, c in ipairs(O.clip.cells) do c[i] = (size - 1) - c[i] end
    notifyOK("Flip", "Clipboard flipped on " .. axis, 3)
end

local function rotateClipboard()
    if not O.clip then notifyWarn("Rotate", "Clipboard is empty", 3) return end
    local sx = O.clip.sx
    for _, c in ipairs(O.clip.cells) do
        c[1], c[3] = c[3], (sx - 1) - c[1]
    end
    O.clip.sx, O.clip.sz = O.clip.sz, O.clip.sx
    notifyOK("Rotate", "Clipboard rotated 90 degrees", 3)
end

-- ── Blueprints ─────────────────────────────────────────────────────────────
local BP_DIR = "autoBuilder/blueprints"

local function ensureBpDir()
    if not isfolder("autoBuilder") then makefolder("autoBuilder") end
    if not isfolder(BP_DIR) then makefolder(BP_DIR) end
end

local function blueprintFiles()
    local out = {}
    pcall(function()
        ensureBpDir()
        for _, f in ipairs(listfiles(BP_DIR)) do
            if f:lower():sub(-5) == ".json" then out[#out + 1] = f:match("[^/\\]+$") end
        end
    end)
    if #out == 0 then out = { "(none saved)" } end
    return out
end


local function saveBlueprint()
    if not O.clip then notifyWarn("Blueprint", "Copy something first", 3) return end
    local name = O.blueprintName
    if name:lower():sub(-5) ~= ".json" then name = name .. ".json" end
    ensureBpDir()
    local ok, err = pcall(function()
        writefile(BP_DIR .. "/" .. name, HttpService:JSONEncode(O.clip))
    end)
    if not ok then notifyErr("Blueprint", tostring(err), 5) return end
    notifyOK("Blueprint Saved", name .. " (" .. #O.clip.cells .. " blocks)", 5)
end

local function loadBlueprint(name)
    if not name or name == "(none saved)" then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(BP_DIR .. "/" .. name))
    end)
    if not ok or type(data) ~= "table" or not data.cells then
        notifyErr("Blueprint", "Could not read " .. tostring(name), 5)
        return
    end
    O.clip = data
    notifyOK("Blueprint Loaded", name .. " (" .. #data.cells .. " blocks)", 5)
end

-- ── Export CSV ─────────────────────────────────────────────────────────────
local function exportCSV()
    if not needSelection() then return end
    task.spawn(function()
        local map = blockPartMap()
        local rows = { "x,y,z,block" }
        for _, c in ipairs(selCells()) do
            local part = map[key3(c[1], c[2], c[3])]
            if part then
                rows[#rows + 1] = c[1] .. "," .. c[2] .. "," .. c[3] .. "," .. part.Name
            end
        end
        if #rows == 1 then notifyWarn("Export CSV", "Selection is empty", 3) return end
        ensureBpDir()
        local name = O.blueprintName:gsub("%.json$", "") .. ".csv"
        local ok, err = pcall(function()
            writefile(BP_DIR .. "/" .. name, table.concat(rows, "\n"))
        end)
        if not ok then notifyErr("Export CSV", tostring(err), 5) return end
        notifyOK("Export CSV", (#rows - 1) .. " rows -> " .. name, 5)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- OPERATIONS UI
-- ═══════════════════════════════════════════════════════════════════════════
opsTab:CreateSection("Operations", { Collapsible = true })

opsStatus = opsTab:CreateParagraph({
    Title = "Operations",
    Content = "All operations act on the Builder tab's selection.",
})

-- Own copy: the Tools tab's helper lives in a different, closed scope.
local function opsBlockOptions()
    return blockDisplayList()
end

local opsBlocks = opsBlockOptions()

-- One slot picker plus one block list, instead of a dropdown per block role.
O.slotList = {
    { "Active Block",  function() return O.activeBlock end, function(v) O.activeBlock = v end },
    { "Replace Block", function() return O.replaceFrom end, function(v) O.replaceFrom = v end },
    { "Mask Block",    function() return O.mask.block end,  function(v) O.mask.block = v end },
    { "Shade Dark",    function() return O.shadeDark end,   function(v) O.shadeDark = v end },
    { "Shade Mid",     function() return O.shadeMid end,    function(v) O.shadeMid = v end },
    { "Shade Light",   function() return O.shadeLight end,  function(v) O.shadeLight = v end },
    { "Gradient From", function() return O.gradFrom end,    function(v) O.gradFrom = v end },
    { "Gradient To",   function() return O.gradTo end,      function(v) O.gradTo = v end },
}
O.slotNames = {}
for _, e in ipairs(O.slotList) do O.slotNames[#O.slotNames + 1] = e[1] end
O.slotPick = O.slotList[1]

function O.refreshSlots()
    local lines = {}
    for _, e in ipairs(O.slotList) do
        lines[#lines + 1] = e[1] .. ": " .. tostring(e[2]())
    end
    pcall(function()
        O.slotPara:Set({ Title = "Blocks In Use", Content = table.concat(lines, "\n") })
    end)
end

opsTab:CreateDropdown({
    Name = "Block Slot",
    Options = O.slotNames, CurrentOption = { "Active Block" }, MultipleOptions = false,
    Flag = "OpsSlot",
    Callback = function(v)
        local name = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(O.slotList) do
            if e[1] == name then O.slotPick = e break end
        end
    end
})

opsTab:CreateDropdown({
    Name = "Set Slot To",
    Options = opsBlocks, CurrentOption = { blockDisplayFor("stone") }, MultipleOptions = false,
    Flag = "OpsSlotVal",
    Callback = function(v)
        local blk = (typeof(v) == "table") and v[1] or v
        blk = blockIdFor(blk)
        O.slotPick[3](blk)
        O.refreshSlots()
        notify("Blocks", O.slotPick[1] .. " = " .. blk, 2, "info")
    end
})

O.slotPara = opsTab:CreateParagraph({ Title = "Blocks In Use", Content = "" })
O.refreshSlots()

opsTab:CreateToggle({
    Name = "Keep Existing",
    CurrentValue = true,
    Tooltip = "Leave blocks that are already there instead of overwriting them.",
    Callback = function(v) O.keepExisting = v end
})

-- Every operation behind one dropdown and one Run button. Selecting an
-- operation shows what it does, so the tooltips are not lost.
O.list = {
    { "Fill",             "Fill the whole selection with the active block.",                    function() fillMode("Fill") end },
    { "Fill Outline",     "Fill only the 12 edges of the selection.",                           function() fillMode("Outline") end },
    { "Fill Walls",       "Fill the four vertical sides of the selection.",                     function() fillMode("Walls") end },
    { "Fill Top",         "Fill the top face of the selection.",                                function() fillMode("Top") end },
    { "Fill Bottom",      "Fill the bottom face of the selection.",                             function() fillMode("Bottom") end },
    { "Fill Nearest",     "Fill each empty cell with whichever solid block is closest.",        fillNearest },
    { "Fill Gaps",        "Fill fully enclosed pockets of air with the active block.",          fillGaps },
    { "Replace",          "Swap 'Replace This Block' for the active block in the selection.",   replaceBlocks },
    { "Hollow",           "Remove every fully enclosed interior block, leaving a shell.",       hollowSelection },
    { "Drain",            "Remove water blocks inside the selection.",                          drainSelection },
    { "Simulate Gravity", "Drop every block in the selection until it rests on something.",     simulateGravity },
    { "Smoothsnow",       "Lay one layer of the active block over the top surface.",            smoothSnow },
    { "Autoshade",        "Shade exposed surfaces into the dark/mid/light palette below.",      autoshade },
    { "Analyze",          "Count every block type inside the selection.",                       analyzeSelection },
    { "Expand Selection", "Grow the selection box outward on every axis.",                      function() growSelection(O.expandBy) end },
    { "Shrink Selection", "Pull the selection box inward on every axis.",                       function() growSelection(-O.expandBy) end },
    { "Palette Painter",  "Scatter the saved Palette randomly across the selection.",            O.palettePaint },
    { "Floodfill",        "Point at a block, then Run: recolour every connected block of that type.", O.floodfill },
    { "Stamp",            "Point at a block, then Run: drop the clipboard on top of it.",         O.stampAtCursor },
}

O.names = {}
for _, e in ipairs(O.list) do O.names[#O.names + 1] = e[1] end

O.chosen = O.list[1]

opsTab:CreateDivider()

opsTab:CreateDropdown({
    Name = "Operation",
    Options = O.names, CurrentOption = { "Fill" }, MultipleOptions = false,
    Flag = "OpsPick",
    Callback = function(v)
        local name = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(O.list) do
            if e[1] == name then
                O.chosen = e
                pcall(function() O.desc:Set({ Title = name, Content = e[2] }) end)
                break
            end
        end
    end
})

O.desc = opsTab:CreateParagraph({ Title = O.list[1][1], Content = O.list[1][2] })

opsTab:CreateButton({
    Name = "Run Operation",
    Tooltip = "Run the operation chosen above on the Builder selection.",
    Callback = function() O.chosen[3]() end
})

opsTab:CreateDivider()

O.maskNames = {}
for _, e in ipairs(O.maskRules) do O.maskNames[#O.maskNames + 1] = e[1] end

opsTab:CreateDropdown({
    Name = "Mask Rule",
    Options = O.maskNames, CurrentOption = { "Surface" }, MultipleOptions = false,
    Flag = "OpsMaskRule",
    Callback = function(v)
        O.mask.rule = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(O.maskRules) do
            if e[1] == O.mask.rule then
                pcall(function() O.maskDesc:Set({ Title = e[1], Content = e[2] }) end)
                break
            end
        end
    end
})

O.maskDesc = opsTab:CreateParagraph({ Title = O.maskRules[1][1], Content = O.maskRules[1][2] })

opsTab:CreateInput({
    Name = "Lua Condition",
    Default = "y > 40",
    Callback = function(t)
        if not t or t == "" then return end
        local ok, err = O.setMaskExpr(t)
        if ok then
            notifyOK("Mask", "Condition compiled", 3)
        else
            notifyErr("Mask", "Bad condition: " .. tostring(err), 5)
        end
    end
})

opsTab:CreateToggle({
    Name = "Invert Mask",
    CurrentValue = false,
    Tooltip = "Flips the rule, so it matches everything that would normally fail.",
    Callback = function(v) O.mask.invert = v end
})

opsTab:CreateDivider()

analyzePara = opsTab:CreateParagraph({
    Title = "Analyze",
    Content = "Run Analyze to see the block breakdown.",
})

opsTab:CreateDivider()

O.clipList = {
    { "Copy",      "Copy the selection's blocks to the clipboard.",            function() copySelection(false) end },
    { "Cut",       "Copy the selection then remove the originals.",            function() copySelection(true) end },
    { "Paste",     "Paste at the selection's low corner, or at you if none.",  pasteClipboard },
    { "Duplicate", "Copy and immediately paste in one step.",                  function() copySelection(false, pasteClipboard) end },
    { "Rotate 90", "Rotate the clipboard clockwise about Y.",                  rotateClipboard },
    { "Flip X",    "Mirror the clipboard on the X axis.",                      function() flipClipboard("X") end },
    { "Flip Y",    "Mirror the clipboard on the Y axis.",                      function() flipClipboard("Y") end },
    { "Flip Z",    "Mirror the clipboard on the Z axis.",                      function() flipClipboard("Z") end },
    { "Scale 2x",  "Double the clipboard, nearest-neighbour.",                 function() scaleClipboard(2) end },
    { "Scale 3x",  "Triple the clipboard, nearest-neighbour.",                 function() scaleClipboard(3) end },
}

O.clipNames = {}
for _, e in ipairs(O.clipList) do O.clipNames[#O.clipNames + 1] = e[1] end

O.clipChosen = O.clipList[1]

opsTab:CreateDropdown({
    Name = "Clipboard Action",
    Options = O.clipNames, CurrentOption = { "Copy" }, MultipleOptions = false,
    Flag = "OpsClip",
    Callback = function(v)
        local name = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(O.clipList) do
            if e[1] == name then
                O.clipChosen = e
                pcall(function() O.clipDesc:Set({ Title = name, Content = e[2] }) end)
                break
            end
        end
    end
})

O.clipDesc = opsTab:CreateParagraph({ Title = O.clipList[1][1], Content = O.clipList[1][2] })

opsTab:CreateButton({
    Name = "Run Clipboard Action",
    Tooltip = "Run the clipboard action chosen above.",
    Callback = function() O.clipChosen[3]() end
})

BuilderAPI.fileKinds[#BuilderAPI.fileKinds + 1] = {
    name = "Blueprint", dir = BP_DIR, list = blueprintFiles, load = loadBlueprint,
    save = function(n) O.blueprintName = n saveBlueprint() end,
}

opsTab:CreateDivider()
opsTab:CreateButton({ Name = "Export Selection as CSV", Tooltip = "Write x,y,z,block rows to the blueprints folder.", Callback = exportCSV })

-- ── editor keybinds ────────────────────────────────────────────────────────
-- Ctrl+C / X / V / J work whenever the Operations tab's shortcuts are enabled.
local editorKeys
opsTab:CreateDivider()
opsTab:CreateParagraph({
    Title = "Editor Keybinds",
    Content = "Ctrl+C copy · Ctrl+X cut · Ctrl+V paste · Ctrl+J duplicate\nCtrl+Z undo · Ctrl+Y redo (always on while a Builder tool is active)",
})
opsTab:CreateToggle({
    Name = "Enable Clipboard Shortcuts",
    CurrentValue = false,
    Tooltip = "Listen for Ctrl+C/X/V/J globally. Turn off if they clash with anything.",
    Callback = function(on)
        if editorKeys then editorKeys:Disconnect() editorKeys = nil end
        if not on then return end
        editorKeys = UserInputService.InputBegan:Connect(function(input, gp)
            if gp or not ctrlDown() then return end
            local k = input.KeyCode
            if k == Enum.KeyCode.C then copySelection(false)
            elseif k == Enum.KeyCode.X then copySelection(true)
            elseif k == Enum.KeyCode.V then pasteClipboard()
            elseif k == Enum.KeyCode.J then copySelection(false, pasteClipboard)
            elseif k == Enum.KeyCode.Z then doUndo()
            elseif k == Enum.KeyCode.Y then doRedo() end
        end)
    end
})

Duvome:AddWatch("Clipboard", function()
    return O.clip and (#O.clip.cells .. " blocks") or false
end)

-- Close the Operations scope and hand its state to Colour, which needs its own
-- 200-local budget.
BuilderAPI.O               = O
BuilderAPI.opsSet          = opsSet
BuilderAPI.needSelection   = needSelection
BuilderAPI.selBounds       = selBounds
BuilderAPI.selCells        = selCells
BuilderAPI.opsBlockOptions = opsBlockOptions

end

do

local BA = BuilderAPI
local B, O = BA.B, BA.O
local key3, toCell = BA.key3, BA.toCell
local blockPartMap, placeCells, eraseCells, runCommit =
    BA.blockPartMap, BA.placeCells, BA.eraseCells, BA.runCommit
local startSession, stopSession, targetPart = BA.startSession, BA.stopSession, BA.targetPart
local opsSet, needSelection, selBounds, selCells, opsBlockOptions =
    BA.opsSet, BA.needSelection, BA.selBounds, BA.selCells, BA.opsBlockOptions

-- ═══════════════════════════════════════════════════════════════════════════
-- COLOUR TAB — Colour Picker, Gradient Helper, Gradient Painter
--
-- Block colours are sampled from the models in ReplicatedStorage.blocks and
-- compared in OKLab, which is perceptually uniform, so "nearest colour" matches
-- what the eye actually sees instead of what raw RGB distance suggests.
--
-- Also inside the Builder scope so the painter can use the selection and undo.
-- ═══════════════════════════════════════════════════════════════════════════

local colTab = tabEdit

local C = {
    cache = nil,            -- { {name=, col=Color3, L=, a=, b=} }
    target = Color3.fromRGB(150, 150, 150),
    steps = 8,
    gradient = nil,         -- ordered list of block names
    axis = "Y",
    matchCount = 8,
    presetName = "MyPreset",
}

local scanPara, matchPara, gradPara

-- ── OKLab ──────────────────────────────────────────────────────────────────
local function srgbToLinear(c)
    if c <= 0.04045 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function cbrt(x)
    if x >= 0 then return x ^ (1 / 3) end
    return -((-x) ^ (1 / 3))
end

-- Björn Ottosson's sRGB -> OKLab transform.
local function toOklab(col)
    local r = srgbToLinear(col.R)
    local g = srgbToLinear(col.G)
    local b = srgbToLinear(col.B)

    local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    local l_, m_, s_ = cbrt(l), cbrt(m), cbrt(s)

    return 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
           1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
           0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
end

local function oklabDist(L1, a1, b1, L2, a2, b2)
    local dL, da, db = L1 - L2, a1 - a2, b1 - b2
    return dL * dL + da * da + db * db
end

-- ── sampling block colours ─────────────────────────────────────────────────
-- Averages every BasePart in a block model, weighted by surface area so big
-- faces count for more than trim details.
local function averageColour(inst)
    if inst:IsA("BasePart") then return inst.Color end
    local rt, gt, bt, wt = 0, 0, 0, 0
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("BasePart") then
            local s = d.Size
            local w = math.max(s.X * s.Y + s.Y * s.Z + s.X * s.Z, 0.001)
            rt = rt + d.Color.R * w
            gt = gt + d.Color.G * w
            bt = bt + d.Color.B * w
            wt = wt + w
        end
    end
    if wt == 0 then return nil end
    return Color3.new(rt / wt, gt / wt, bt / wt)
end

-- Every placeable block in the game, from the saved block palette. This is the
-- authoritative list the image tool matches against: scanning
-- ReplicatedStorage.blocks was unreliable (folder sometimes missing, templates
-- often textured meshes with a flat tint), so the candidate set comes from here
-- instead. Names only - positions were dropped, they only mattered in the swatch
-- board the palette was built from.
local BLOCK_PALETTE = {
    "clayDeposit", "coalBlock", "buffalkorCrystalBlock", "darkGreenBlock", "clayPink", "neonCyan",
    "coralBlockPink", "neonRed", "copperDeposit", "neonYellow", "clayYellow", "woolLightGreen",
    "woolCyan", "clayBlue", "oilDeposit", "whiteBlock", "neonBlue", "pearlBlock",
    "haybaleBlock", "blueBlock", "blackBlock", "neonPurple", "targetBlockIron", "clayOrange",
    "neonWhite", "coralBlockYellow", "woolOrange", "honeycombBlock", "goldBlock", "diamondBlock",
    "neonBlack", "clayLightGreen", "redBronzeBlock", "lightGreenBlock", "clayWhite", "neonOrange",
    "ironBlock", "orangeBlock", "purpleBlock", "goldDeposit", "targetBlockWood", "honeyBlock",
    "clayCyan", "neonDarkGreen", "yellowBlock", "clayDarkGreen", "clayPurple", "neonLightGreen",
    "clayRed", "woolYellow", "coralBlockLightBlue", "neonPink", "woolWhite", "woolPurple",
    "woolBlack", "woolPink", "clayBlack", "woolDarkGreen", "woolRed", "pinkBlock",
    "cyanBlock", "opalBlock", "copperBlock", "rubyBlock", "amethystBlock", "coralBlockBlue",
    "woolBlue", "redBlock", "voidStoneCarvedStair", "yellowStair", "voidStoneTiledSlab", "purpleStair",
    "pastelOrangeSlab", "stairBirch", "pinkSlab", "stairCherryBlossom", "leavesBlock", "pastelOrangeStair",
    "mapleSlab", "woodSpirit", "cyanSlab", "purpleSlab", "stairMaple", "woodCherryBlossom",
    "darkGreenStair", "pastelBlueStair", "slimeBlockPink", "stairHickory", "iceCompact", "blueStair",
    "whiteSlab", "snowCompact", "pinkStair", "orangeSlab", "glassBlockBlue", "bambooBlock",
    "snow", "mudBlock", "glassBlockRed", "voidBlock", "grass", "ice",
    "voidGrass", "voidStoneTiledStair", "pastelOrangeBlock", "glowingMushroomPinkBlock", "pastelPinkStair", "checkerTiledBlock",
    "voidStonePolishedSlab", "slimeBlockBlue", "pastelRedBlock", "voidSandBlock", "redSlab", "voidStoneTiled",
    "blackSlab", "pastelPurpleStair", "pastelRedSlab", "stairOak", "hickorySlab", "oakSlab",
    "pastelPinkSlab", "yellowSlab", "woodMaple", "darkGreenSlab", "blackStair", "glowingMushroomCyanBlock",
    "pinePlank", "pastelBlueSlab", "voidStoneCarvedSlab", "birchSlab", "woodHickory", "pastelGreenStair",
    "pastelYellowStair", "stairPine", "cyanStair", "voidStoneStair", "cautionSlab", "orangeStair",
    "redStair", "checkerTiledSlab", "checkerTiledStair", "pastelPurpleSlab", "pineSlab", "voidStoneCobbleStair",
    "spiritPlank", "pastelYellowSlab", "voidStoneSlab", "glassBlockChrome", "voidStoneBrick", "testGenerator",
    "blueSlab", "magmaBlock", "ledLight", "pastelGreenBlock", "whiteStair", "stairSpirit",
    "lightGreenSlab", "cautionBlock", "sand", "glassBlockPurple", "voidStoneBrickStair", "cherryBlossomPlank",
    "cautionStair", "pastelGreenSlab", "pumpkinHarvested", "wood", "cherryBlossomSlab", "grassDry",
    "lightGreenStair", "voidStoneCobbleSlab", "candyCane", "glassBlockDarkGreen", "spiritSlab", "glassBlockOrange",
    "glassBlockBlack", "voidStoneBlock", "glassBlockCyan", "voidStoneBrickSlab", "glassBlockLightGreen", "maplePlank",
    "pastelPinkBlock", "glowingMushroomGreenBlock", "glassBlockYellow", "woodBirch", "boneBlock", "jackOLantern",
    "bambooDriedBlock", "glassBlockPink", "voidStonePolished", "voidStonePolishedStair", "leavesMapleBlock", "slimeBlockGreen",
    "pastelPurpleBlock", "pastelYellowBlock", "woodPlank", "melonHarvested", "woodPine", "voidStoneCobble",
    "mushroomBlock", "voidStoneCarved", "birchPlank", "pastelBlueBlock", "hickoryPlank", "glowingMushroomBlueBlock",
    "graniteBrickStair", "graniteBrickSlab", "graniteStair", "graniteCarved", "graniteSlab", "granite",
    "graniteSmooth", "graniteBrick", "graniteTiles", "stairAquamarineSmooth", "stairMarble", "stairStoneBrick",
    "sandstoneSmoothRedSlab", "dioriteStair", "sandstoneSlab", "basaltSlab", "dioriteBrickSlab", "basaltStair",
    "sandstoneRedSlab", "stairSandstoneSmooth", "sandstoneBrickSlab", "slateSlab", "stairMarbleBrick", "stoneSmooth",
    "aquamarineSmooth", "prismarineBrick", "prismarineBrickStair", "stairSandstoneBrick", "slateBrickSlab", "marbleBrickSlab",
    "dioriteBrickStair", "slateTiles", "mossyCobblestoneSlab", "sandstoneSmoothRedBrickSlab", "stairSandstoneSmoothBrick", "marbleTiles",
    "stairBrick", "sandstoneSmooth", "stairSandstoneRedBrick", "cobblestoneSlab", "sandstoneSmoothBrickSlab", "sandstoneSmoothSlab",
    "andesite", "stone", "stairSlateBrick", "dioriteSlab", "sandstoneBrick", "stairSandstoneSmoothRed",
    "slateSmooth", "aquamarineSmoothBrickSlab", "basaltBrickStair", "stoneBrick", "basaltBrickSlab", "aquamarineSmoothSlab",
    "aquamarineCarved", "andesiteSlab", "mossySlab", "andesiteStair", "andesiteCarved", "sandstoneRedBrickSlab",
    "basaltSmooth", "stoneTiles", "prismarineSlab", "andesiteSmooth", "dioriteCarved", "marblePillar",
    "stoneBrickSlab", "stoneCarved", "clay", "andesiteBrickSlab", "slateBrick", "prismarineBlock",
    "andesiteTiles", "stairAquamarineSmoothBrick", "stairSandstoneSmoothRedBrick", "dioriteSmooth", "andesiteBrickStair", "brickSlab",
    "prismarineBrickSlab", "prismarineStair", "stairSlate", "basaltBrick", "aquamarineSmoothBrick", "marbleSlab",
    "cobblestoneStair", "slateBlock", "sandstone", "slateCarved", "marbleCarved", "stairSandstoneRed",
    "basaltTiles", "marbleSmooth", "sandstoneSmoothRed", "diorite", "dioriteTiles", "stairSandstone",
    "andesiteBrick", "sandstoneSmoothRedBrick", "cobblestoneBlock", "mossyCobblestoneBlock", "sandstoneSmoothBrick", "dioriteBrick",
    "stoneBrickMossy", "sandstoneRed", "basaltCarved", "brick", "aquamarineTiles", "mossyBlock",
    "sandstoneRedBrick", "marbleBrick", "marbleBlock", "basalt",
}
BuilderAPI.blockPalette = BLOCK_PALETTE

-- One placed block of each name from the world, so colours come from the real
-- rendered blocks (the swatch board, or anything already built) rather than the
-- flat tint on a textured template.
local function worldColourByName()
    local map = {}
    local island = getNearestIsland()
    local folder = island and island:FindFirstChild("Blocks")
    if folder then
        for _, b in ipairs(folder:GetChildren()) do
            if not map[b.Name] then
                local c = averageColour(b)
                if c then map[b.Name] = c end
            end
        end
    end
    return map
end

-- The template folder, whatever it is called in this place.
local function templateFolder()
    for _, n in ipairs({ "blocks", "Blocks", "BlockModels", "blockModels", "Items" }) do
        local f = ReplicatedStorage:FindFirstChild(n)
        if f then return f end
    end
    return nil
end

local function scanColours()
    -- Colour each palette block: prefer the real placed block, fall back to the
    -- ReplicatedStorage template. The palette is the source of names, so the
    -- index always covers exactly the game's placeable blocks.
    local world = worldColourByName()
    local folder = templateFolder()
    local out = {}
    local missing = 0
    for _, name in ipairs(BLOCK_PALETTE) do
        local col = world[name]
        if not col and folder then
            local tmpl = folder:FindFirstChild(name)
            if tmpl then col = averageColour(tmpl) end
        end
        if col then
            local L, a, b = toOklab(col)
            out[#out + 1] = { name = name, col = col, L = L, a = a, b = b }
        else
            missing = missing + 1
        end
    end
    table.sort(out, function(p, q) return p.L < q.L end)
    C.cache = out
    pcall(function()
        scanPara:Set({
            Title = "Colour Index",
            Content = #out .. " of " .. #BLOCK_PALETTE .. " palette blocks coloured, dark to light."
                .. (missing > 0 and ("\n" .. missing .. " had no colour source (build the block palette to colour them).") or ""),
        })
    end)
    if #out == 0 then
        notifyErr("Colour Scan", "No block colours found - build the block palette or check ReplicatedStorage", 6)
    else
        notifyOK("Colour Scan", #out .. " palette blocks indexed", 5)
    end
end

local function ensureCache()
    if C.cache and #C.cache > 0 then return true end
    scanColours()
    return C.cache ~= nil and #C.cache > 0
end

-- The measured in-game colour of every placeable block, for anything that
-- needs to reason about how blocks look rather than what they are called.
-- Scans on first use, which takes a moment and only happens once.
BuilderAPI.blockColours = function()
    if not ensureCache() then return nil end
    local out = {}
    for _, e in ipairs(C.cache) do
        out[e.name] = { col = e.col, L = e.L, a = e.a, b = e.b }
    end
    return out
end

-- ── nearest matches ────────────────────────────────────────────────────────
local function nearestBlocks(col, n)
    if not ensureCache() then return {} end
    local L, a, b = toOklab(col)
    local scored = {}
    for _, e in ipairs(C.cache) do
        scored[#scored + 1] = { e, oklabDist(L, a, b, e.L, e.a, e.b) }
    end
    table.sort(scored, function(p, q) return p[2] < q[2] end)
    local out = {}
    for i = 1, math.min(n or 8, #scored) do out[#out + 1] = scored[i][1] end
    return out
end

local function showMatches()
    local list = nearestBlocks(C.target, C.matchCount)
    if #list == 0 then
        notifyWarn("Colour", "No colours indexed yet", 3)
        return
    end
    local lines = {}
    for i, e in ipairs(list) do
        lines[#lines + 1] = string.format("%d. %s  (%d, %d, %d)", i, e.name,
            math.floor(e.col.R * 255 + 0.5),
            math.floor(e.col.G * 255 + 0.5),
            math.floor(e.col.B * 255 + 0.5))
    end
    pcall(function()
        matchPara:Set({ Title = "Similar Blocks", Content = table.concat(lines, "\n") })
    end)
    notifyOK("Colour", "Closest match: " .. list[1].name, 4)
end

local function findByName(name)
    if not ensureCache() then return nil end
    for _, e in ipairs(C.cache) do
        if e.name == name then return e end
    end
    return nil
end

-- ── gradient ───────────────────────────────────────────────────────────────
-- Interpolates in OKLab between the two endpoint blocks, then snaps each step
-- to the closest real block.
local function buildGradient()
    local from, to = findByName(O.gradFrom), findByName(O.gradTo)
    if not (from and to) then
        notifyWarn("Gradient", "Scan colours first, then pick both endpoints", 4)
        return
    end
    local seq, names = {}, {}
    for i = 0, C.steps - 1 do
        local t = (C.steps == 1) and 0 or (i / (C.steps - 1))
        local L = from.L + (to.L - from.L) * t
        local a = from.a + (to.a - from.a) * t
        local b = from.b + (to.b - from.b) * t
        -- snap the interpolated colour onto a real block
        local best, bestD = nil, math.huge
        for _, e in ipairs(C.cache) do
            local d = oklabDist(L, a, b, e.L, e.a, e.b)
            if d < bestD then bestD = d best = e end
        end
        seq[#seq + 1] = best.name
        names[#names + 1] = (i + 1) .. ". " .. best.name
    end
    C.gradient = seq
    pcall(function()
        gradPara:Set({ Title = "Gradient", Content = table.concat(names, "\n") })
    end)
    notifyOK("Gradient", C.steps .. " steps built", 4)
end

-- ── gradient painter ───────────────────────────────────────────────────────
local function paintGradient()
    if not C.gradient or #C.gradient == 0 then
        notifyWarn("Gradient Painter", "Build a gradient first", 3)
        return
    end
    if not needSelection() then return end
    runCommit("Gradient Painter", function(rec)
        local map = blockPartMap()
        local minX, maxX, minY, maxY, minZ, maxZ = selBounds()
        local lo, hi
        if C.axis == "X" then lo, hi = minX, maxX
        elseif C.axis == "Z" then lo, hi = minZ, maxZ
        else lo, hi = minY, maxY end

        local want = {}
        for _, c in ipairs(selCells()) do
            if map[key3(c[1], c[2], c[3])] then
                local v = (C.axis == "X") and c[1] or ((C.axis == "Z") and c[3] or c[2])
                local t = (hi == lo) and 0 or ((v - lo) / (hi - lo))
                local idx = math.clamp(math.floor(t * (#C.gradient - 1) + 0.5) + 1, 1, #C.gradient)
                want[#want + 1] = { c[1], c[2], c[3], C.gradient[idx] }
            end
        end
        if #want == 0 then notifyWarn("Gradient Painter", "No blocks in selection", 3) return end
        opsSet("Gradient Painter", "Painting " .. #want .. " blocks...")
        eraseCells(want, rec)
        placeCells(want, rec)
        notifyOK("Gradient Painter", #want .. " blocks painted along " .. C.axis, 5)
    end)
end

-- ── hex parsing ────────────────────────────────────────────────────────────
local function parseHex(str)
    local s = tostring(str):gsub("#", ""):gsub("%s", "")
    if #s == 3 then
        s = s:sub(1,1):rep(2) .. s:sub(2,2):rep(2) .. s:sub(3,3):rep(2)
    end
    if #s ~= 6 or s:match("%X") then return nil end
    local r = tonumber(s:sub(1, 2), 16)
    local g = tonumber(s:sub(3, 4), 16)
    local b = tonumber(s:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r, g, b)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════════
colTab:CreateSection("Colour", { Collapsible = true })

scanPara = colTab:CreateParagraph({
    Title = "Colour Index",
    Content = "Scan to sample the average colour of every block type.",
})

colTab:CreateButton({
    Name = "Scan Block Colours",
    Tooltip = "Colour every block in the palette (from real placed blocks first, template otherwise) and index it in OKLab. Run once per session; build the block palette in the world for the truest colours.",
    Callback = function() task.spawn(scanColours) end
})

colTab:CreateDivider()

local targetPicker
targetPicker = colTab:CreateColorpicker({
    Name = "Target Colour",
    Default = Color3.fromRGB(150, 150, 150),
    Callback = function(col) C.target = col end
})

colTab:CreateInput({
    Name = "Hex Code",
    Default = "969696",
    Callback = function(t)
        local col = parseHex(t)
        if not col then
            notifyWarn("Hex", "Use RRGGBB or RGB, e.g. 8A5C2B", 4)
            return
        end
        C.target = col
        pcall(function() targetPicker:Set(col) end)
        notify("Hex", "Target set", 2, "info")
    end
})

colTab:CreateSlider({
    Name = "Matches to Show",
    Range = { 3, 20 }, Increment = 1, CurrentValue = 8, Flag = "ColMatches",
    Callback = function(v) C.matchCount = v end
})

colTab:CreateButton({
    Name = "Find Similar Blocks",
    Tooltip = "List the blocks closest to the target colour, nearest first.",
    Callback = function() task.spawn(showMatches) end
})

-- Eyedropper: click a world block to adopt its colour.
colTab:CreateToggle({
    Name = "Eyedropper",
    CurrentValue = false,
    Tooltip = "Click any block in the world to copy its colour into the target.",
    Callback = function(on)
        if not on then
            if B.tool == "Eyedropper" then stopSession() end
            return
        end
        startSession("Eyedropper")
        table.insert(B.conns, UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local part = targetPart()
            if not part then return end
            C.target = part.Color
            pcall(function() targetPicker:Set(part.Color) end)
            showMatches()
        end))
    end
})

matchPara = colTab:CreateParagraph({
    Title = "Similar Blocks",
    Content = "Pick a colour, then Find Similar Blocks.",
})

colTab:CreateDivider()

colTab:CreateSlider({
    Name = "Gradient Steps",
    Range = { 2, 24 }, Increment = 1, CurrentValue = 8, Flag = "ColSteps",
    Callback = function(v) C.steps = v end
})

colTab:CreateButton({
    Name = "Build Gradient",
    Tooltip = "Interpolate between the two blocks in OKLab and snap each step to the nearest real block.",
    Callback = function() task.spawn(buildGradient) end
})

gradPara = colTab:CreateParagraph({
    Title = "Gradient",
    Content = "Build a gradient to see the block sequence.",
})

colTab:CreateDivider()

colTab:CreateDropdown({
    Name = "Gradient Axis",
    Options = { "X", "Y", "Z" }, CurrentOption = { "Y" }, MultipleOptions = false,
    Flag = "ColAxis",
    Callback = function(v) C.axis = (typeof(v) == "table") and v[1] or v end
})

colTab:CreateButton({
    Name = "Paint Selection with Gradient",
    Tooltip = "Recolour every block in the Builder selection, stepping through the gradient along the chosen axis.",
    Callback = paintGradient
})

colTab:CreateButton({
    Name = "Send Gradient to Autoshade",
    Tooltip = "Use the gradient's darkest, middle and lightest blocks as the Autoshade palette.",
    Callback = function()
        if not C.gradient or #C.gradient < 3 then
            notifyWarn("Gradient", "Build a gradient with at least 3 steps first", 4)
            return
        end
        O.shadeDark = C.gradient[1]
        O.shadeMid = C.gradient[math.ceil(#C.gradient / 2)]
        O.shadeLight = C.gradient[#C.gradient]
        notifyOK("Autoshade Palette",
            O.shadeDark .. " / " .. O.shadeMid .. " / " .. O.shadeLight, 5)
    end
})

-- ═══════════════════════════════════════════════════════════════════════════
-- TOOL PRESETS — saves the Operations + Colour settings that share this scope
-- ═══════════════════════════════════════════════════════════════════════════
local PRESET_DIR = "autoBuilder/presets"

local function ensurePresetDir()
    if not isfolder("autoBuilder") then makefolder("autoBuilder") end
    if not isfolder(PRESET_DIR) then makefolder(PRESET_DIR) end
end

local function presetFiles()
    local out = {}
    pcall(function()
        ensurePresetDir()
        for _, f in ipairs(listfiles(PRESET_DIR)) do
            if f:lower():sub(-5) == ".json" then out[#out + 1] = f:match("[^/\\]+$") end
        end
    end)
    if #out == 0 then out = { "(none saved)" } end
    return out
end


local function currentPreset()
    return {
        activeBlock = O.activeBlock,
        replaceFrom = O.replaceFrom,
        keepExisting = O.keepExisting,
        shadeDark = O.shadeDark,
        shadeMid = O.shadeMid,
        shadeLight = O.shadeLight,
        expandBy = O.expandBy,
        gradFrom = O.gradFrom,
        gradTo = O.gradTo,
        steps = C.steps,
        axis = C.axis,
        gradient = C.gradient,
        stackCount = B.stackCount,
        smearLen = B.smearLen,
        eraseLimit = B.eraseLimit,
    }
end

local function savePreset()
    local name = C.presetName
    if name:lower():sub(-5) ~= ".json" then name = name .. ".json" end
    ensurePresetDir()
    local ok, err = pcall(function()
        writefile(PRESET_DIR .. "/" .. name, HttpService:JSONEncode(currentPreset()))
    end)
    if not ok then notifyErr("Preset", tostring(err), 5) return end
    notifyOK("Preset Saved", name, 4)
end

local function loadPreset(name)
    if not name or name == "(none saved)" then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(PRESET_DIR .. "/" .. name))
    end)
    if not ok or type(data) ~= "table" then
        notifyErr("Preset", "Could not read " .. tostring(name), 5)
        return
    end
    O.activeBlock  = data.activeBlock  or O.activeBlock
    O.replaceFrom  = data.replaceFrom  or O.replaceFrom
    if data.keepExisting ~= nil then O.keepExisting = data.keepExisting end
    O.shadeDark    = data.shadeDark    or O.shadeDark
    O.shadeMid     = data.shadeMid     or O.shadeMid
    O.shadeLight   = data.shadeLight   or O.shadeLight
    O.expandBy     = data.expandBy     or O.expandBy
    O.gradFrom     = data.gradFrom     or O.gradFrom
    O.gradTo       = data.gradTo       or O.gradTo
    C.steps        = data.steps        or C.steps
    C.axis         = data.axis         or C.axis
    C.gradient     = data.gradient     or C.gradient
    B.stackCount   = data.stackCount   or B.stackCount
    B.smearLen     = data.smearLen     or B.smearLen
    B.eraseLimit   = data.eraseLimit   or B.eraseLimit
    notifyOK("Preset Loaded", name .. " (sliders keep their old positions)", 6)
end

-- Expose colour matching so the Image module can reuse this index instead of
-- building a second one.
BuilderAPI.ensureColourCache = ensureCache
BuilderAPI.nearestBlockName = function(col)
    local list = nearestBlocks(col, 1)
    return list[1] and list[1].name or nil
end
BuilderAPI.nearestBlockEntry = function(col)
    return nearestBlocks(col, 1)[1]
end
BuilderAPI.toOklab = toOklab

colTab:CreateDivider()

colTab:CreateParagraph({
    Title = "About Presets",
    Content = "Saves the Operations and Colour settings, plus the Builder's stack, smear and erase limits. The on-screen sliders won't visually move on load, but the saved values are what the tools use.",
})

BuilderAPI.fileKinds[#BuilderAPI.fileKinds + 1] = {
    name = "Preset", dir = PRESET_DIR, list = presetFiles, load = loadPreset,
    save = function(n) C.presetName = n savePreset() end,
}



end

-- ═══════════════════════════════════════════════════════════════════════════
-- SESSION WINDOWS — History, Target Info, Views, Palette, Theme
--
-- The Axiom Editor's supporting windows. All collapsed by default so they add
-- headers, not clutter. Own scope to stay inside the 200-local limit.
-- ═══════════════════════════════════════════════════════════════════════════
do

local BA = BuilderAPI
local B, O = BA.B, BA.O
local key3, toCell, targetPart = BA.key3, BA.toCell, BA.targetPart

local S = {
    viewName = "MyView",
    annText = "Note",
    timeConn = nil,
    paletteName = "MyPalette",
    infoOn = false,
    infoConn = nil,
    lastInfo = 0,
}

local histPara2, infoPara

-- ── History ────────────────────────────────────────────────────────────────
local function refreshHistoryList()
    local lines = {}
    for i = #B.undo, math.max(1, #B.undo - 11), -1 do
        local rec = B.undo[i]
        local placed = rec.placed and #rec.placed or 0
        local removed = rec.removed and #rec.removed or 0
        lines[#lines + 1] = string.format("%d. %s  (+%d / -%d)", i, rec.label, placed, removed)
    end
    if #lines == 0 then lines[1] = "Nothing yet. Run a builder tool or operation." end
    if #B.redo > 0 then lines[#lines + 1] = "-- " .. #B.redo .. " undone, redoable --" end
    pcall(function()
        histPara2:Set({ Title = "History", Content = table.concat(lines, "\n") })
    end)
end

tabEdit:CreateSection("Session", { Collapsible = true })

histPara2 = tabEdit:CreateParagraph({
    Title = "History",
    Content = "Nothing yet. Run a builder tool or operation.",
})

tabEdit:CreateButton({
    Name = "Refresh History",
    Tooltip = "List recent operations with how many blocks each placed and removed.",
    Callback = refreshHistoryList
})

tabEdit:CreateButton({
    Name = "Clear History",
    Tooltip = "Drop the undo and redo stacks. Does not change the world.",
    Callback = function()
        B.undo = {}
        B.redo = {}
        refreshHistoryList()
        notify("History", "Cleared", 2, "info")
    end
})

-- ── Target Info ────────────────────────────────────────────────────────────
tabEdit:CreateDivider()

infoPara = tabEdit:CreateParagraph({
    Title = "Target Info",
    Content = "Turn on to inspect whatever block is under your cursor.",
})

tabEdit:CreateToggle({
    Name = "Show Target Info",
    CurrentValue = false,
    Tooltip = "Continuously report the block under the cursor: name, grid cell and distance.",
    Callback = function(on)
        S.infoOn = on
        if S.infoConn then S.infoConn:Disconnect() S.infoConn = nil end
        if not on then
            pcall(function()
                infoPara:Set({ Title = "Target Info", Content = "Off." })
            end)
            return
        end
        S.infoConn = RunService.RenderStepped:Connect(function()
            -- throttled: this runs every frame otherwise
            local now = tick()
            if now - S.lastInfo < 0.2 then return end
            S.lastInfo = now
            local part = targetPart()
            if not part then
                pcall(function()
                    infoPara:Set({ Title = "Target Info", Content = "No block under cursor." })
                end)
                return
            end
            local x, y, z = toCell(part.Position)
            local _, _, hrp = getCharacterParts()
            local dist = hrp and math.floor((part.Position - hrp.Position).Magnitude) or 0
            pcall(function()
                infoPara:Set({
                    Title = "Target Info",
                    Content = string.format("Block: %s\nCell: %d, %d, %d\nWorld: %d, %d, %d\nDistance: %d studs",
                        part.Name, x, y, z,
                        math.floor(part.Position.X), math.floor(part.Position.Y), math.floor(part.Position.Z),
                        dist),
                })
            end)
        end)
    end
})

tabEdit:CreateButton({
    Name = "Pick Block to Active",
    Tooltip = "Copy the block under your cursor into the Active Block used by operations.",
    Callback = function()
        local part = targetPart()
        if not part then notifyWarn("Pick Block", "Point at a block first", 3) return end
        O.activeBlock = part.Name
        notifyOK("Active Block", part.Name, 3)
    end
})

-- ── Views ──────────────────────────────────────────────────────────────────
local VIEW_DIR = "autoBuilder/views"

local function ensureViewDir()
    if not isfolder("autoBuilder") then makefolder("autoBuilder") end
    if not isfolder(VIEW_DIR) then makefolder(VIEW_DIR) end
end

local function viewFiles()
    local out = {}
    pcall(function()
        ensureViewDir()
        for _, f in ipairs(listfiles(VIEW_DIR)) do
            if f:lower():sub(-5) == ".json" then out[#out + 1] = f:match("[^/\\]+$") end
        end
    end)
    if #out == 0 then out = { "(none saved)" } end
    return out
end

BuilderAPI.fileKinds[#BuilderAPI.fileKinds + 1] = {
    name = "View", dir = VIEW_DIR, list = viewFiles,
    load = function(name)
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(VIEW_DIR .. "/" .. name))
        end)
        if not ok or type(data) ~= "table" or not data.x then
            notifyErr("Views", "Could not read " .. tostring(name), 5) return
        end
        local _, _, hrp = getCharacterParts()
        if not hrp then notifyWarn("Views", "No character found", 3) return end
        hrp.CFrame = CFrame.new(data.x, data.y, data.z) * hrp.CFrame.Rotation
        notifyOK("View", "Teleported to " .. name, 3)
    end,
    save = function(name)
        local _, _, hrp = getCharacterParts()
        if not hrp then notifyWarn("Views", "No character found", 3) return end
        if name:lower():sub(-5) ~= ".json" then name = name .. ".json" end
        ensureViewDir()
        local p2 = hrp.Position
        local ok, err = pcall(function()
            writefile(VIEW_DIR .. "/" .. name, HttpService:JSONEncode({ x = p2.X, y = p2.Y, z = p2.Z }))
        end)
        if not ok then notifyErr("Views", tostring(err), 5) return end
        notifyOK("View Saved", name, 4)
    end,
}

-- ── Palette ────────────────────────────────────────────────────────────────
local PAL_DIR = "autoBuilder/palettes"

local function ensurePalDir()
    if not isfolder("autoBuilder") then makefolder("autoBuilder") end
    if not isfolder(PAL_DIR) then makefolder(PAL_DIR) end
end

local function palFiles()
    local out = {}
    pcall(function()
        ensurePalDir()
        for _, f in ipairs(listfiles(PAL_DIR)) do
            if f:lower():sub(-5) == ".json" then out[#out + 1] = f:match("[^/\\]+$") end
        end
    end)
    if #out == 0 then out = { "(none saved)" } end
    return out
end

tabEdit:CreateDivider()

tabEdit:CreateParagraph({
    Title = "Palette",
    Content = "Collect blocks you use together, save the group, and reload it later.",
})

tabEdit:CreateButton({
    Name = "Add Active Block to Palette",
    Gear = { { Type = "button", Name = "Clear Palette", OnClick = function()
        O.palette = {}
        notify("Palette", "Emptied", 2, "info")
    end } },
    Tooltip = "Append the current Active Block to the working palette.",
    Callback = function()
        for _, n in ipairs(O.palette) do
            if n == O.activeBlock then
                notifyWarn("Palette", O.activeBlock .. " is already in it", 3)
                return
            end
        end
        O.palette[#O.palette + 1] = O.activeBlock
        notifyOK("Palette", O.activeBlock .. " added (" .. #O.palette .. " total)", 3)
    end
})

BuilderAPI.fileKinds[#BuilderAPI.fileKinds + 1] = {
    name = "Palette", dir = PAL_DIR, list = palFiles,
    load = function(name)
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(PAL_DIR .. "/" .. name))
        end)
        if not ok or type(data) ~= "table" or not data.blocks then
            notifyErr("Palette", "Could not read " .. tostring(name), 5) return
        end
        O.palette = data.blocks
        if O.palette[1] then O.activeBlock = O.palette[1] end
        notifyOK("Palette Loaded", #O.palette .. " blocks", 5)
    end,
    save = function(name)
        if #O.palette == 0 then notifyWarn("Palette", "Add some blocks first", 3) return end
        if name:lower():sub(-5) ~= ".json" then name = name .. ".json" end
        ensurePalDir()
        local ok, err = pcall(function()
            writefile(PAL_DIR .. "/" .. name, HttpService:JSONEncode({ blocks = O.palette }))
        end)
        if not ok then notifyErr("Palette", tostring(err), 5) return end
        notifyOK("Palette Saved", name .. " (" .. #O.palette .. " blocks)", 4)
    end,
}

-- ── World & View ───────────────────────────────────────────────────────────
-- Islands has no gamerules a client can set, but the render-side equivalents of
-- Axiom's time / brightness / fluid opacity settings are all client-side.
local Lighting = game:GetService("Lighting")

-- Duvome runs Slider:Set(default) while building the UI, which fires the
-- callback. These sliders used to apply immediately, so Min Brightness = 0 set
-- Ambient to black on load and darkened the whole game. Nothing here touches
-- Lighting until the master toggle is on, and the originals are restored when
-- it goes off.
S.wvOn = false
S.wvSaved = {
    Ambient        = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd         = Lighting.FogEnd,
    ClockTime      = Lighting.ClockTime,
}
pcall(function() S.wvSaved.WaterTransparency = Workspace.Terrain.WaterTransparency end)

local function wvRestore()
    pcall(function()
        Lighting.Ambient        = S.wvSaved.Ambient
        Lighting.OutdoorAmbient = S.wvSaved.OutdoorAmbient
        Lighting.FogEnd         = S.wvSaved.FogEnd
        Lighting.ClockTime      = S.wvSaved.ClockTime
        if S.wvSaved.WaterTransparency then
            Workspace.Terrain.WaterTransparency = S.wvSaved.WaterTransparency
        end
    end)
end

tabEdit:CreateDivider()

tabEdit:CreateParagraph({
    Title = "World & View",
    Content = "Local render settings, off by default so nothing changes how your\n"
        .. "game looks unless you ask. Turn the override on, then use the sliders.",
})

tabEdit:CreateToggle({
    Name = "Enable World & View",
    CurrentValue = false,
    Tooltip = "Off means the sliders below do nothing and your lighting is untouched.",
    Callback = function(on)
        S.wvOn = on
        if not on then
            wvRestore()
            notify("World & View", "Lighting restored", 3, "info")
        end
    end
})

tabEdit:CreateButton({
    Name = "Reset Lighting",
    Tooltip = "Put the game's original lighting back.",
    Callback = function()
        wvRestore()
        notifyOK("World & View", "Original lighting restored", 4)
    end
})

tabEdit:CreateSlider({
    Name = "Time of Day",
    Range = { 0, 24 }, Increment = 1, CurrentValue = 14, Suffix = "h", Flag = "WVTime",
    Callback = function(v) if S.wvOn then pcall(function() Lighting.ClockTime = v end) end end
})

tabEdit:CreateToggle({
    Name = "Freeze Time",
    CurrentValue = false,
    Tooltip = "Stop the day/night cycle moving while you build.",
    Callback = function(on)
        if S.timeConn then S.timeConn:Disconnect() S.timeConn = nil end
        if not on then return end
        local held = Lighting.ClockTime
        S.timeConn = RunService.Heartbeat:Connect(function()
            if Lighting.ClockTime ~= held then
                pcall(function() Lighting.ClockTime = held end)
            end
        end)
    end
})

tabEdit:CreateSlider({
    Name = "Min Brightness",
    Range = { 0, 100 }, Increment = 5, CurrentValue = 0, Suffix = "%", Flag = "WVBright",
    Callback = function(v)
        if not S.wvOn then return end
        pcall(function()
            -- lifting Ambient floors how dark shadowed faces can get
            local a = math.floor(v / 100 * 255)
            Lighting.Ambient = Color3.fromRGB(a, a, a)
            Lighting.OutdoorAmbient = Color3.fromRGB(a, a, a)
        end)
    end
})

tabEdit:CreateSlider({
    Name = "Fog Distance",
    Range = { 100, 5000 }, Increment = 100, CurrentValue = 5000, Suffix = "st", Flag = "WVFog",
    Callback = function(v) if S.wvOn then pcall(function() Lighting.FogEnd = v end) end end
})

tabEdit:CreateSlider({
    Name = "Water Opacity",
    Range = { 0, 100 }, Increment = 10, CurrentValue = 100, Suffix = "%", Flag = "WVWater",
    Callback = function(v)
        if not S.wvOn then return end
        pcall(function() Workspace.Terrain.WaterTransparency = 1 - (v / 100) end)
    end
})

tabEdit:CreateToggle({
    Name = "Reveal Invisible Parts",
    CurrentValue = false,
    Tooltip = "Show fully transparent blocks, the equivalent of Axiom's collision mesh view.",
    Callback = function(on)
        task.spawn(function()
            local folder = getBlocksFolder()
            if not folder then notifyWarn("Reveal", "No island found", 3) return end
            local n = 0
            for _, part in ipairs(folder:GetChildren()) do
                if part:IsA("BasePart") then
                    if on and part.Transparency >= 1 then
                        part:SetAttribute("IABHidden", true)
                        part.Transparency = 0.6
                        n = n + 1
                    elseif not on and part:GetAttribute("IABHidden") then
                        part.Transparency = 1
                        part:SetAttribute("IABHidden", nil)
                        n = n + 1
                    end
                end
            end
            notifyOK("Reveal", n .. " parts updated", 4)
        end)
    end
})

-- ── Annotations ────────────────────────────────────────────────────────────
-- Floating labels you can leave around a build as notes.
tabEdit:CreateDivider()

local function annFolder()
    local f = Workspace:FindFirstChild("IABAnnotations")
    if not f then
        f = Instance.new("Folder")
        f.Name = "IABAnnotations"
        f.Parent = Workspace
    end
    return f
end

local annDropdown

local function annList()
    local out = {}
    for _, a in ipairs(annFolder():GetChildren()) do out[#out + 1] = a.Name end
    if #out == 0 then out = { "(none placed)" } end
    return out
end

tabEdit:CreateInput({
    Name = "Annotation Text",
    Default = "Note",
    Callback = function(t) if t and t ~= "" then S.annText = t end end
})

tabEdit:CreateButton({
    Name = "Place Annotation at Cursor",
    Gear = { { Type = "button", Name = "Clear All Annotations", OnClick = function()
        annFolder():ClearAllChildren()
        pcall(function() annDropdown:Refresh(annList(), true) end)
        notify("Annotations", "Cleared", 2, "info")
    end } },
    Tooltip = "Drop a floating label on the block under your cursor.",
    Callback = function()
        local part = targetPart()
        if not part then notifyWarn("Annotation", "Point at a block first", 3) return end
        local anchor2 = Instance.new("Part")
        anchor2.Name = S.annText or "Note"
        anchor2.Anchored = true anchor2.CanCollide = false anchor2.CanQuery = false
        anchor2.Transparency = 1
        anchor2.Size = Vector3.new(1, 1, 1)
        anchor2.Position = part.Position + Vector3.new(0, 4, 0)
        anchor2.Parent = annFolder()
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 200, 0, 40)
        bb.AlwaysOnTop = true
        bb.Adornee = anchor2
        bb.Parent = anchor2
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 0.4
        lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.TextColor3 = Color3.fromRGB(255, 230, 120)
        lbl.Text = S.annText or "Note"
        lbl.Parent = bb
        pcall(function() annDropdown:Refresh(annList(), true) end)
        notifyOK("Annotation", "Placed: " .. (S.annText or "Note"), 3)
    end
})

annDropdown = tabEdit:CreateDropdown({
    Name = "Go To Annotation",
    Options = annList(), CurrentOption = {}, MultipleOptions = false,
    Callback = function(v)
        local name = (typeof(v) == "table") and v[1] or v
        if not name or name == "(none placed)" then return end
        local a = annFolder():FindFirstChild(name)
        if not a then return end
        local _, _, hrp = getCharacterParts()
        if hrp then
            hrp.CFrame = CFrame.new(a.Position + Vector3.new(0, 3, 0)) * hrp.CFrame.Rotation
            notifyOK("Annotation", "Teleported to " .. name, 3)
        end
    end
})

-- ── Theme ──────────────────────────────────────────────────────────────────
tabEdit:CreateDivider()

tabEdit:CreateDropdown({
    Name = "UI Theme",
    Options = Duvome:GetThemes(), CurrentOption = { "Default" }, MultipleOptions = false,
    Flag = "UITheme",
    Callback = function(v)
        local name = (typeof(v) == "table") and v[1] or v
        Duvome:SetTheme(name)
        notifyOK("Theme", name, 3)
    end
})

tabEdit:CreateSlider({
    Name = "Glass",
    Range = { 0, 80 }, Increment = 2, CurrentValue = 16, Suffix = "%",
    Flag = "UIGlass",
    Callback = function(v)
        pcall(function() Duvome:SetGlass(v / 100) end)
    end
})

-- Colorpicker:Set runs while the UI is built and fires this callback, so the
-- default purple was calling SetAccent immediately - which builds a Custom
-- theme and switches to it, replacing the black Default before you ever see it.
S.accentReady = false
tabEdit:CreateColorpicker({
    Name = "Accent Colour",
    Default = Color3.fromRGB(120, 80, 255),
    Callback = function(c)
        if not S.accentReady then return end
        Duvome:SetAccent(c)
    end
})
task.defer(function() S.accentReady = true end)

end

-- ═══════════════════════════════════════════════════════════════════════════
-- NOISE PAINTER + SCRIPT BRUSH
--
-- Own scope for its own 200-local budget. Everything it changes goes through
-- the Builder's place/erase/undo stack, so Ctrl+Z reverts a script run.
-- ═══════════════════════════════════════════════════════════════════════════
do

local BA = BuilderAPI
local B, O = BA.B, BA.O
local key3, toCell = BA.key3, BA.toCell
local blockPartMap, placeCells, eraseCells, runCommit =
    BA.blockPartMap, BA.placeCells, BA.eraseCells, BA.runCommit
local needSelection, selCells, selBounds = BA.needSelection, BA.selCells, BA.selBounds

-- ═══════════════════════════════════════════════════════════════════════════
-- NOISE LIBRARY
-- Gradient (Perlin-style) fBm plus cellular variants. Not Minecraft's exact
-- OpenSimplex, but the same families with the same tuning knobs.
-- ═══════════════════════════════════════════════════════════════════════════
local N = {}

-- Integer hash in [0,1). Uses bit32 so intermediates stay inside 32 bits;
-- the arithmetic version overflowed double precision and returned garbage.
local function hash3(i, j, k, seed)
    local h = bit32.bxor(
        bit32.band(i * 374761393, 0xFFFFFFFF),
        bit32.band(j * 668265263, 0xFFFFFFFF),
        bit32.band(k * 1274126177, 0xFFFFFFFF),
        bit32.band((seed or 0) * 971, 0xFFFFFFFF)
    )
    h = bit32.bxor(h, bit32.rshift(h, 13))
    h = bit32.band(h * 1274126177, 0xFFFFFFFF)
    h = bit32.bxor(h, bit32.rshift(h, 16))
    return h / 4294967296
end

-- pseudo-random unit-ish gradient for a lattice corner
local function grad3(i, j, k, seed, x, y, z)
    local a = hash3(i, j, k, seed) * 6.2831853
    local b = hash3(i, j, k, (seed or 0) + 7919) * 6.2831853
    local gx = math.cos(a) * math.sin(b)
    local gy = math.sin(a) * math.sin(b)
    local gz = math.cos(b)
    return gx * x + gy * y + gz * z
end

local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
local function lerp(a, b, t) return a + (b - a) * t end

-- Gradient noise in [0,1]
function N.gradient(x, y, z, seed)
    local i, j, k = math.floor(x), math.floor(y), math.floor(z)
    local fx, fy, fz = x - i, y - j, z - k
    local u, v, w = fade(fx), fade(fy), fade(fz)
    local n = lerp(
        lerp(
            lerp(grad3(i,   j,   k,   seed, fx,   fy,   fz),
                 grad3(i+1, j,   k,   seed, fx-1, fy,   fz), u),
            lerp(grad3(i,   j+1, k,   seed, fx,   fy-1, fz),
                 grad3(i+1, j+1, k,   seed, fx-1, fy-1, fz), u), v),
        lerp(
            lerp(grad3(i,   j,   k+1, seed, fx,   fy,   fz-1),
                 grad3(i+1, j,   k+1, seed, fx-1, fy,   fz-1), u),
            lerp(grad3(i,   j+1, k+1, seed, fx,   fy-1, fz-1),
                 grad3(i+1, j+1, k+1, seed, fx-1, fy-1, fz-1), u), v), w)
    return math.clamp(n * 0.7 + 0.5, 0, 1)
end

-- Fractal Brownian motion: octaves / lacunarity / gain, as in the spec
function N.fbm(x, y, z, seed, octaves, lacunarity, gain)
    local amp, freq, sum, norm = 1, 1, 0, 0
    for _ = 1, math.max(1, octaves) do
        sum = sum + N.gradient(x * freq, y * freq, z * freq, seed) * amp
        norm = norm + amp
        amp = amp * gain
        freq = freq * lacunarity
    end
    return norm > 0 and (sum / norm) or 0
end

-- Distances to the nearest feature points in the surrounding cells
local function cellular(x, y, z, seed, jitter)
    local i, j, k = math.floor(x), math.floor(y), math.floor(z)
    local d1, d2 = math.huge, math.huge
    for oi = -1, 1 do
        for oj = -1, 1 do
            for ok = -1, 1 do
                local ci, cj, ck = i + oi, j + oj, k + ok
                local px = ci + 0.5 + (hash3(ci, cj, ck, seed) - 0.5) * 2 * jitter
                local py = cj + 0.5 + (hash3(ci, cj, ck, (seed or 0) + 13) - 0.5) * 2 * jitter
                local pz = ck + 0.5 + (hash3(ci, cj, ck, (seed or 0) + 29) - 0.5) * 2 * jitter
                local dx, dy, dz = px - x, py - y, pz - z
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                if d < d1 then d2 = d1 d1 = d elseif d < d2 then d2 = d end
            end
        end
    end
    return d1, d2
end

function N.worley(x, y, z, seed, jitter)
    local d1 = cellular(x, y, z, seed, jitter)
    return math.clamp(d1 / 1.1, 0, 1)
end

function N.voronoiEdges(x, y, z, seed, jitter)
    local d1, d2 = cellular(x, y, z, seed, jitter)
    return math.clamp((d2 - d1) / 0.75, 0, 1)
end

function N.metaball(x, y, z, seed, jitter, range)
    local d1 = cellular(x, y, z, seed, jitter)
    local r = math.max(range or 1, 0.001)
    return math.clamp(1 - (d1 / (r * 1.4)), 0, 1)
end

function N.white(x, y, z, seed)
    return hash3(math.floor(x), math.floor(y), math.floor(z), seed)
end

function N.splatter(x, y, z, seed, octaves, lacunarity, gain)
    local jx = (hash3(math.floor(x), math.floor(y), math.floor(z), (seed or 0) + 3) - 0.5) * 2
    local jz = (hash3(math.floor(x), math.floor(y), math.floor(z), (seed or 0) + 5) - 0.5) * 2
    return N.fbm(x + jx, y, z + jz, seed, octaves, lacunarity, gain)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NOISE PAINTER
-- ═══════════════════════════════════════════════════════════════════════════
local NP = {
    kind = "Simplex",
    scale = 12,
    octaves = 3,
    lacunarity = 2,
    gain = 0.5,
    seed = 1,
    jitter = 1,
    range = 1,
    threshold = 50,
    three_d = false,
}

local NOISE_KINDS = {
    { "Simplex",       "Smooth rolling fBm. Good for terrain-like blends." },
    { "Worley",        "Cellular blobs, each cell fading from its centre." },
    { "Voronoi Edges", "Cracked lines along cell boundaries. Good for stone tiling." },
    { "Metaball",      "Overlapping spheres with smooth joins, lava-lamp style." },
    { "White Noise",   "Pure static, no structure at all." },
    { "Splatter",      "Simplex with a random offset, for a speckled look." },
}

local function noiseAt(x, y, z)
    local s = math.max(NP.scale, 0.001)
    -- Offset off the integer lattice: gradient noise is exactly 0 there, so a
    -- scale that divides the cell coordinate evenly would give flat output.
    local nx, nz = x / s + 0.37, z / s + 0.61
    local ny = NP.three_d and (y / s + 0.23) or 0.19
    if NP.kind == "Simplex" then
        return N.fbm(nx, ny, nz, NP.seed, NP.octaves, NP.lacunarity, NP.gain)
    elseif NP.kind == "Worley" then
        return N.worley(nx, ny, nz, NP.seed, NP.jitter)
    elseif NP.kind == "Voronoi Edges" then
        return N.voronoiEdges(nx, ny, nz, NP.seed, NP.jitter)
    elseif NP.kind == "Metaball" then
        return N.metaball(nx, ny, nz, NP.seed, NP.jitter, NP.range)
    elseif NP.kind == "White Noise" then
        return N.white(nx, ny, nz, NP.seed)
    end
    return N.splatter(nx, ny, nz, NP.seed, NP.octaves, NP.lacunarity, NP.gain)
end

-- Paints the selection using the palette when there is one, otherwise the
-- active block against whatever is already there.
local function runNoisePainter()
    if not needSelection() then return end
    runCommit("Noise Painter", function(rec)
        local map = blockPartMap()
        local want = {}
        local pal = O.palette
        local usePal = #pal > 1
        local t = NP.threshold / 100
        for _, c in ipairs(selCells()) do
            if map[key3(c[1], c[2], c[3])] and O.maskAllows(map, c[1], c[2], c[3]) then
                local n = noiseAt(c[1], c[2], c[3])
                if usePal then
                    -- spread the palette across the noise range
                    local idx = math.clamp(math.floor(n * #pal) + 1, 1, #pal)
                    want[#want + 1] = { c[1], c[2], c[3], pal[idx] }
                elseif n >= t then
                    want[#want + 1] = { c[1], c[2], c[3], O.activeBlock }
                end
            end
        end
        if #want == 0 then notifyWarn("Noise Painter", "Nothing matched", 3) return end
        eraseCells(want, rec)
        placeCells(want, rec)
        notifyOK("Noise Painter", #want .. " blocks (" .. NP.kind .. ")", 5)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SCRIPT BRUSH
--
-- Duvome textboxes are single-line, so scripts live as files in
-- autoBuilder/scripts. The quick box is there for one-liners.
-- ═══════════════════════════════════════════════════════════════════════════
local SCRIPT_DIR = "autoBuilder/scripts"

local SB = { file = nil, quick = "return blocks.stone", source = nil }
local scriptHelp

local function ensureScriptDir()
    if not isfolder("autoBuilder") then makefolder("autoBuilder") end
    if not isfolder(SCRIPT_DIR) then makefolder(SCRIPT_DIR) end
end

local function scriptFiles()
    local out = {}
    pcall(function()
        ensureScriptDir()
        for _, f in ipairs(listfiles(SCRIPT_DIR)) do
            local low = f:lower()
            if low:sub(-4) == ".lua" or low:sub(-4) == ".txt" then
                out[#out + 1] = f:match("[^/\\]+$")
            end
        end
    end)
    if #out == 0 then out = { "(none saved)" } end
    return out
end

-- Builds the sandbox a script runs inside. `writes` collects setBlock calls.
local function makeEnv(map, writes)
    local blocksTable = setmetatable({}, {
        -- blocks.stone -> "stone"; unknown names still resolve to themselves
        __index = function(_, k) return tostring(k) end,
    })

    local function getBlock(x, y, z)
        local p = map[key3(x, y, z)]
        return p and p.Name or "air"
    end

    local function setBlock(x, y, z, name)
        if not name or name == "air" then return end
        writes[#writes + 1] = { x, y, z, tostring(name) }
    end

    local function isSolid(name)
        return name ~= nil and name ~= "air" and name ~= ""
    end

    local function getHighestBlockYAt(x, z)
        for y = 128, -64, -1 do
            if map[key3(x, y, z)] then return y end
        end
        return -64
    end

    return {
        blocks = blocksTable,
        getBlock = getBlock,
        setBlock = setBlock,
        isSolid = isSolid,
        getHighestBlockYAt = getHighestBlockYAt,
        getSimplexNoise = function(x, y, z, seed) return N.gradient(x / 8, y / 8, z / 8, seed or 0) end,
        getVoronoiEdgeNoise = function(x, y, z, seed) return N.voronoiEdges(x / 8, y / 8, z / 8, seed or 0, 1) end,
        getWorleyNoise = function(x, y, z, seed) return N.worley(x / 8, y / 8, z / 8, seed or 0, 1) end,
        -- read-only maths helpers; no game access from inside a script
        math = math, string = string, table = table,
        tostring = tostring, tonumber = tonumber, ipairs = ipairs, pairs = pairs,
        print = function(...) end,
    }
end

local function runScript(source)
    if not source or source == "" then
        notifyWarn("Script Brush", "Pick a script file or type a quick script", 4)
        return
    end
    if not needSelection() then return end

    -- Wrap so both `return blocks.x` and multi-statement scripts work.
    local chunk, err = loadstring("return function(x, y, z)\n" .. source .. "\nend")
    if not chunk then
        notifyErr("Script Brush", "Compile error: " .. tostring(err), 8)
        pcall(function()
            scriptHelp:Set({ Title = "Script Error", Content = tostring(err) })
        end)
        return
    end
    runCommit("Script Brush", function(rec)
        local map = blockPartMap()
        local writes = {}
        local env = makeEnv(map, writes)

        -- The sandbox has to be attached to the chunk BEFORE it runs, so the
        -- closure it returns inherits it. Running the chunk first would build
        -- the script body against the real globals instead.
        if setfenv then setfenv(chunk, env) end
        local okc, body = pcall(chunk)
        if not okc or type(body) ~= "function" then
            notifyErr("Script Brush", "Script did not load: " .. tostring(body), 6)
            return
        end

        local errors, ran = 0, 0
        for _, c in ipairs(selCells()) do
            if O.maskAllows(map, c[1], c[2], c[3]) then
                local ok, res = pcall(body, c[1], c[2], c[3])
                ran = ran + 1
                if not ok then
                    errors = errors + 1
                    if errors == 1 then
                        notifyErr("Script Brush", "Runtime error: " .. tostring(res), 8)
                    end
                elseif res ~= nil and res ~= false then
                    -- a returned block name places at the target cell
                    writes[#writes + 1] = { c[1], c[2], c[3], tostring(res) }
                end
            end
            if ran % 400 == 0 then task.wait() end
        end

        if #writes == 0 then
            notifyWarn("Script Brush", "Script produced no blocks", 4)
            return
        end
        eraseCells(writes, rec)
        placeCells(writes, rec)
        notifyOK("Script Brush", #writes .. " blocks from " .. ran .. " cells", 6)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════════
tabEdit:CreateSection("Advanced Tools", { Collapsible = true })

NP.names = {}
for _, e in ipairs(NOISE_KINDS) do NP.names[#NP.names + 1] = e[1] end

tabEdit:CreateDropdown({
    Name = "Noise Type",
    Options = NP.names, CurrentOption = { "Simplex" }, MultipleOptions = false,
    Flag = "NPKind",
    Callback = function(v)
        NP.kind = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(NOISE_KINDS) do
            if e[1] == NP.kind then
                pcall(function() NP.desc:Set({ Title = e[1], Content = e[2] }) end)
                break
            end
        end
    end
})

NP.desc = tabEdit:CreateParagraph({ Title = NOISE_KINDS[1][1], Content = NOISE_KINDS[1][2] })

for _, sl in ipairs({
    { "Noise Scale",  2, 64,  1, 12, "NPScale",  function(v) NP.scale = v end },
    { "Octaves",      1,  6,  1, 3,  "NPOct",    function(v) NP.octaves = v end },
    { "Lacunarity",   1,  4,  1, 2,  "NPLac",    function(v) NP.lacunarity = v end },
    { "Gain",         1, 10,  1, 5,  "NPGain",   function(v) NP.gain = v / 10 end },
    { "Jitter",       0, 10,  1, 10, "NPJit",    function(v) NP.jitter = v / 10 end },
    { "Threshold",    0, 100, 5, 50, "NPThresh", function(v) NP.threshold = v end },
    { "Noise Seed",   1, 10000, 1, 1, "NPSeed",  function(v) NP.seed = v end },
}) do
    tabEdit:CreateSlider({
        Name = sl[1], Range = { sl[2], sl[3] }, Increment = sl[4],
        CurrentValue = sl[5], Flag = sl[6], Callback = sl[7]
    })
end

tabEdit:CreateToggle({
    Name = "3D Noise",
    CurrentValue = false,
    Tooltip = "Vary the pattern with height too, so vertical faces get textured instead of striped.",
    Callback = function(v) NP.three_d = v end
})

tabEdit:CreateButton({
    Name = "Run Noise Painter",
    Tooltip = "Paint the selection with the noise. Uses the Palette if it has 2+ blocks, otherwise the Active Block above the threshold.",
    Callback = runNoisePainter
})

tabEdit:CreateDivider()

scriptHelp = tabEdit:CreateParagraph({
    Title = "Script Brush",
    Content = "Runs Lua for every block in the selection.\n"
        .. "Variables: x, y, z\n"
        .. "Return a block name to place it there.\n"
        .. "API: getBlock(x,y,z), setBlock(x,y,z,name), isSolid(name),\n"
        .. "getHighestBlockYAt(x,z), getSimplexNoise(x,y,z,seed),\n"
        .. "getVoronoiEdgeNoise(...), getWorleyNoise(...), blocks.<name>\n"
        .. "Put .lua files in autoBuilder/scripts for longer scripts.",
})

tabEdit:CreateInput({
    Name = "Quick Script",
    Default = "return blocks.stone",
    Callback = function(t) if t and t ~= "" then SB.quick = t end end
})

tabEdit:CreateButton({
    Name = "Run Quick Script",
    Gear = { { Type = "button", Name = "Write Example Script", OnClick = function()
        ensureScriptDir()
        local example = [[
-- Example: grass on top, dirt just under it, stone deeper.
-- Runs once per block in the selection. x, y, z are that block's cell.

local here = getBlock(x, y, z)
if not isSolid(here) then return end

local top = getHighestBlockYAt(x, z)

if y == top then
    return blocks.grass
elseif y > top - 3 then
    return blocks.dirt
else
    -- speckle the deep stone with a second material
    if getSimplexNoise(x, y, z, 1337) > 0.6 then
        return blocks.sand
    end
    return blocks.stone
end
]]
        local ok, err = pcall(function()
            writefile(SCRIPT_DIR .. "/example.lua", example)
        end)
        if not ok then notifyErr("Scripts", tostring(err), 5) return end
        notifyOK("Scripts", "example.lua written", 5)
    end } },
    Tooltip = "Compile and run the one-liner above over the selection.",
    Callback = function() runScript(SB.quick) end
})

tabEdit:CreateButton({
    Name = "Run Script File",
    Tooltip = "Run the script loaded from Saved Files over the selection.",
    Callback = function() runScript(SB.source) end
})

BuilderAPI.fileKinds[#BuilderAPI.fileKinds + 1] = {
    name = "Script", dir = SCRIPT_DIR, list = scriptFiles,
    load = function(name)
        local ok, src = pcall(function() return readfile(SCRIPT_DIR .. "/" .. name) end)
        if not ok then notifyErr("Script Brush", "Could not read " .. name, 5) return end
        SB.file = name SB.source = src
        notifyOK("Script Loaded", name .. " (" .. #src .. " chars)", 4)
    end,
}

end

-- ═══════════════════════════════════════════════════════════════════════════
-- SHAPE, PATH AND MODIFY TOOLS
--
-- Shapes are implicit functions sampled over a bounding box, so hollow and
-- scaling fall out of the same maths. Paths are node lists resolved by a curve
-- function then thickened by a brush. Modify transforms the live selection.
--
-- Own scope for its own 200-local budget; everything routes through the
-- Builder's place/erase/undo stack.
-- ═══════════════════════════════════════════════════════════════════════════
do

local BA = BuilderAPI
local B, O = BA.B, BA.O
local key3, toCell = BA.key3, BA.toCell
local blockPartMap, placeCells, eraseCells, runCommit =
    BA.blockPartMap, BA.placeCells, BA.eraseCells, BA.runCommit
local needSelection, selBounds, targetPart = BA.needSelection, BA.selBounds, BA.targetPart

local SP = {
    shape = "Sphere",
    size = 8,
    height = 8,
    hollow = false,
    nodes = {},
    pathKind = "Line (DDA)",
    radius = 1,
    slack = 3,
    looped = false,
    modMode = "Translate Copies",
    count = 3,
    offX = 0, offY = 0, offZ = 0,
    angle = 90,
    axis = "Y",
}

local shapeDesc, nodePara, modDesc

-- Where a generated shape is anchored: the cursor block, else the player.
local function anchorCell()
    local part = targetPart()
    if part then return toCell(part.Position) end
    local _, _, hrp = getCharacterParts()
    if hrp then return toCell(hrp.Position) end
    return 0, 0, 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SHAPES  (implicit field: <=1 is inside)
-- ═══════════════════════════════════════════════════════════════════════════
local SHAPES = {
    { "Sphere",      "A round solid ball." },
    { "Cuboid",      "A rectangular box." },
    { "Octahedron",  "Eight triangular faces, a diamond." },
    { "Cylinder",    "A round column of the given height." },
    { "Cone",        "Tapers from a round base to a point." },
    { "Pyramid",     "Tapers from a square base to a point." },
    { "Torus",       "A doughnut ring lying flat." },
    { "Supersphere", "A rounded cube, between a sphere and a box." },
    { "Tube",        "A hollow cylinder, open through the middle." },
    { "Disk",        "A flat filled circle, one block thick." },
    { "Plane",       "A flat filled square, one block thick." },
}

-- Returns the implicit value for a shape at a normalised offset.
local function shapeField(kind, dx, dy, dz, r, h)
    local nx, nz = dx / r, dz / r
    local ny = (h > 0) and (dy / h) or 0
    if kind == "Sphere" then
        return nx * nx + ny * ny + nz * nz
    elseif kind == "Cuboid" then
        return math.max(math.abs(nx), math.abs(ny), math.abs(nz))
    elseif kind == "Octahedron" then
        return math.abs(nx) + math.abs(ny) + math.abs(nz)
    elseif kind == "Cylinder" then
        return math.max(nx * nx + nz * nz, math.abs(ny))
    elseif kind == "Cone" then
        -- radius shrinks linearly from base (ny=-1) to tip (ny=1)
        local t = (ny + 1) / 2
        local allow = math.max(1 - t, 0.0001)
        return math.max((nx * nx + nz * nz) / (allow * allow), math.abs(ny))
    elseif kind == "Pyramid" then
        local t = (ny + 1) / 2
        local allow = math.max(1 - t, 0.0001)
        return math.max(math.abs(nx) / allow, math.abs(nz) / allow, math.abs(ny))
    elseif kind == "Torus" then
        local q = math.sqrt(nx * nx + nz * nz) - 0.65
        return (q * q + ny * ny) / (0.35 * 0.35)
    elseif kind == "Supersphere" then
        local p = 4
        return math.abs(nx) ^ p + math.abs(ny) ^ p + math.abs(nz) ^ p
    elseif kind == "Tube" then
        local d = nx * nx + nz * nz
        if d < 0.55 then return 99 end          -- carve the bore
        return math.max(d, math.abs(ny))
    elseif kind == "Disk" then
        if dy ~= 0 then return 99 end
        return nx * nx + nz * nz
    elseif kind == "Plane" then
        if dy ~= 0 then return 99 end
        return math.max(math.abs(nx), math.abs(nz))
    end
    return 99
end

local function buildShape()
    runCommit("Shape", function(rec)
        local ax, ay, az = anchorCell()
        local r = SP.size
        local h = (SP.shape == "Disk" or SP.shape == "Plane") and 0 or SP.height
        local cells = {}
        local yr = (h > 0) and h or 0
        for dx = -r, r do
            for dy = -yr, yr do
                for dz = -r, r do
                    local v = shapeField(SP.shape, dx, dy, dz, r, h)
                    if v <= 1 then
                        local keep = true
                        if SP.hollow then
                            -- A cell is shell if any neighbour falls outside.
                            -- Flat shapes are one block thick, so testing Y
                            -- would mark every cell as shell and hollow would
                            -- do nothing; check only the horizontal ring there.
                            keep = false
                            for _, d in ipairs(h > 0 and O.sides or O.flat) do
                                if shapeField(SP.shape, dx + d[1], dy + d[2], dz + d[3], r, h) > 1 then
                                    keep = true
                                    break
                                end
                            end
                        end
                        if keep then
                            cells[#cells + 1] = { ax + dx, ay + dy, az + dz, O.activeBlock }
                        end
                    end
                end
            end
        end
        if #cells == 0 then notifyWarn("Shape", "That shape produced nothing", 3) return end
        placeCells(cells, rec)
        notifyOK("Shape", SP.shape .. ": " .. #cells .. " blocks", 5)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PATHS
-- ═══════════════════════════════════════════════════════════════════════════
local PATHS = {
    { "Line (Bresenham)", "Exactly one block wide, straight between nodes." },
    { "Line (DDA)",       "Straight between nodes, thickened by Radius." },
    { "Catenary",         "Hangs between nodes like a rope. Slack sets the dip." },
    { "Catmull-Rom",      "Smooth curve that passes through every node." },
    { "Bezier",           "Smooth curve pulled toward the middle nodes." },
}

local function lerp3(a, b, t)
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

local function catmull(p0, p1, p2, p3, t)
    local function c(a, b, cc, d)
        return 0.5 * ((2 * b) + (-a + cc) * t
            + (2 * a - 5 * b + 4 * cc - d) * t * t
            + (-a + 3 * b - 3 * cc + d) * t * t * t)
    end
    return c(p0[1], p1[1], p2[1], p3[1]), c(p0[2], p1[2], p2[2], p3[2]), c(p0[3], p1[3], p2[3], p3[3])
end

-- Samples the chosen curve into a list of float points.
local function pathPoints()
    local n = SP.nodes
    local pts = {}
    if #n < 2 then return pts end
    local list = { table.unpack(n) }
    if SP.looped then list[#list + 1] = n[1] end

    if SP.pathKind == "Bezier" then
        local steps = 24 * #list
        for i = 0, steps do
            local t = i / steps
            -- de Casteljau over all nodes
            local tmp = {}
            for k, p in ipairs(list) do tmp[k] = { p[1], p[2], p[3] } end
            for r = #tmp - 1, 1, -1 do
                for k = 1, r do
                    local x, y, z = lerp3(tmp[k], tmp[k + 1], t)
                    tmp[k] = { x, y, z }
                end
            end
            pts[#pts + 1] = tmp[1]
        end
        return pts
    end

    for i = 1, #list - 1 do
        local a, b = list[i], list[i + 1]
        local dist = math.max(math.abs(b[1] - a[1]), math.abs(b[2] - a[2]), math.abs(b[3] - a[3]))
        local steps = math.max(math.floor(dist * 2), 2)
        for s = 0, steps do
            local t = s / steps
            local x, y, z
            if SP.pathKind == "Catmull-Rom" then
                local p0 = list[math.max(i - 1, 1)]
                local p3 = list[math.min(i + 2, #list)]
                x, y, z = catmull(p0, a, b, p3, t)
            elseif SP.pathKind == "Catenary" then
                x, y, z = lerp3(a, b, t)
                -- parabolic approximation of a hanging chain
                y = y - SP.slack * 4 * t * (1 - t)
            else
                x, y, z = lerp3(a, b, t)
            end
            pts[#pts + 1] = { x, y, z }
        end
    end
    return pts
end

local function buildPath()
    if #SP.nodes < 2 then
        notifyWarn("Path", "Add at least two nodes first", 4)
        return
    end
    runCommit("Path", function(rec)
        local pts = pathPoints()
        local seen, cells = {}, {}
        local r = (SP.pathKind == "Line (Bresenham)") and 0 or SP.radius
        for _, p in ipairs(pts) do
            local cx = math.floor(p[1] + 0.5)
            local cy = math.floor(p[2] + 0.5)
            local cz = math.floor(p[3] + 0.5)
            for dx = -r, r do
                for dy = -r, r do
                    for dz = -r, r do
                        if dx * dx + dy * dy + dz * dz <= r * r + 0.001 then
                            local k = key3(cx + dx, cy + dy, cz + dz)
                            if not seen[k] then
                                seen[k] = true
                                cells[#cells + 1] = { cx + dx, cy + dy, cz + dz, O.activeBlock }
                            end
                        end
                    end
                end
            end
        end
        if #cells == 0 then notifyWarn("Path", "Path produced nothing", 3) return end
        placeCells(cells, rec)
        notifyOK("Path", SP.pathKind .. ": " .. #cells .. " blocks", 5)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MODIFY  (transforms the current selection's blocks)
-- ═══════════════════════════════════════════════════════════════════════════
local MODS = {
    { "Translate Copies", "Clone the selection Count times, each offset by X/Y/Z." },
    { "Rotate Copies",    "Clone the selection Count times around its centre, stepping by Angle." },
    { "Revolve",          "Sweep the selection around its centre through Angle degrees." },
    { "Twist",            "Rotate each layer progressively, twisting the selection." },
}

local function selectionBlocks(map)
    local minX, maxX, minY, maxY, minZ, maxZ = selBounds()
    local out = {}
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                local p = map[key3(x, y, z)]
                if p then out[#out + 1] = { x, y, z, p.Name } end
            end
        end
    end
    return out, minX, maxX, minY, maxY, minZ, maxZ
end

local function rotateXZ(x, z, cx, cz, deg)
    local a = math.rad(deg)
    local ca, sa = math.cos(a), math.sin(a)
    local rx, rz = x - cx, z - cz
    return cx + rx * ca - rz * sa, cz + rx * sa + rz * ca
end

local function runModify()
    if not needSelection() then return end
    runCommit("Modify", function(rec)
        local map = blockPartMap()
        local src, minX, maxX, minY, maxY, minZ, maxZ = selectionBlocks(map)
        if #src == 0 then notifyWarn("Modify", "Selection is empty", 3) return end
        local cx = (minX + maxX) / 2
        local cz = (minZ + maxZ) / 2
        local seen, out = {}, {}

        local function put(x, y, z, name)
            x, y, z = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5)
            local k = key3(x, y, z)
            if not seen[k] then
                seen[k] = true
                out[#out + 1] = { x, y, z, name }
            end
        end

        if SP.modMode == "Translate Copies" then
            for i = 1, SP.count do
                for _, b in ipairs(src) do
                    put(b[1] + SP.offX * i, b[2] + SP.offY * i, b[3] + SP.offZ * i, b[4])
                end
            end
        elseif SP.modMode == "Rotate Copies" then
            for i = 1, SP.count do
                for _, b in ipairs(src) do
                    local nx, nz = rotateXZ(b[1], b[3], cx, cz, SP.angle * i)
                    put(nx, b[2] + SP.offY * i, nz, b[4])
                end
            end
        elseif SP.modMode == "Revolve" then
            -- many small steps so the sweep is continuous, not spaced copies
            local steps = math.max(SP.angle, 1)
            for d = 1, steps do
                for _, b in ipairs(src) do
                    local nx, nz = rotateXZ(b[1], b[3], cx, cz, d)
                    put(nx, b[2], nz, b[4])
                end
            end
        else -- Twist
            local span = math.max(maxY - minY, 1)
            for _, b in ipairs(src) do
                local t = (b[2] - minY) / span
                local nx, nz = rotateXZ(b[1], b[3], cx, cz, SP.angle * t)
                put(nx, b[2], nz, b[4])
            end
        end

        if #out == 0 then notifyWarn("Modify", "Nothing produced", 3) return end
        if SP.modMode == "Twist" or SP.modMode == "Revolve" then
            eraseCells(src, rec)
        end
        placeCells(out, rec)
        notifyOK("Modify", SP.modMode .. ": " .. #out .. " blocks", 5)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════════
tabEdit:CreateDivider()

SP.shapeNames = {}
for _, e in ipairs(SHAPES) do SP.shapeNames[#SP.shapeNames + 1] = e[1] end

tabEdit:CreateDropdown({
    Name = "Shape",
    Options = SP.shapeNames, CurrentOption = { "Sphere" }, MultipleOptions = false,
    Flag = "SPShape",
    Callback = function(v)
        SP.shape = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(SHAPES) do
            if e[1] == SP.shape then
                pcall(function() shapeDesc:Set({ Title = e[1], Content = e[2] }) end)
                break
            end
        end
    end
})

shapeDesc = tabEdit:CreateParagraph({ Title = SHAPES[1][1], Content = SHAPES[1][2] })

tabEdit:CreateSlider({
    Name = "Shape Size", Range = { 1, 40 }, Increment = 1, CurrentValue = 8,
    Suffix = "blk", Flag = "SPSize", Callback = function(v) SP.size = v end
})
tabEdit:CreateSlider({
    Name = "Shape Height", Range = { 1, 40 }, Increment = 1, CurrentValue = 8,
    Suffix = "blk", Flag = "SPHeight", Callback = function(v) SP.height = v end
})
tabEdit:CreateToggle({
    Name = "Hollow",
    CurrentValue = false,
    Tooltip = "Keep only the outer shell of the shape.",
    Callback = function(v) SP.hollow = v end
})
tabEdit:CreateButton({
    Name = "Build Shape at Cursor",
    Tooltip = "Generates the shape in the Active Block where your cursor points, or at you if it points at nothing.",
    Callback = buildShape
})

tabEdit:CreateDivider()

SP.pathNames = {}
for _, e in ipairs(PATHS) do SP.pathNames[#SP.pathNames + 1] = e[1] end

nodePara = tabEdit:CreateParagraph({
    Title = "Path Nodes",
    Content = "No nodes yet. Point at a block and press Add Node.",
})

tabEdit:CreateButton({
    Name = "Add Node at Cursor",
    Gear = { { Type = "button", Name = "Clear Nodes", OnClick = function()
        SP.nodes = {}
        pcall(function()
            nodePara:Set({ Title = "Path Nodes", Content = "No nodes yet. Point at a block and press Add Node." })
        end)
        notify("Path", "Nodes cleared", 2, "info")
    end } },
    Tooltip = "Append the block under your cursor to the path.",
    Callback = function()
        local part = targetPart()
        if not part then notifyWarn("Path", "Point at a block first", 3) return end
        local x, y, z = toCell(part.Position)
        SP.nodes[#SP.nodes + 1] = { x, y, z }
        pcall(function()
            nodePara:Set({
                Title = "Path Nodes",
                Content = #SP.nodes .. " nodes. Last: " .. x .. ", " .. y .. ", " .. z,
            })
        end)
        notifyOK("Path", "Node " .. #SP.nodes .. " added", 2)
    end
})

tabEdit:CreateDropdown({
    Name = "Path Type",
    Options = SP.pathNames, CurrentOption = { "Line (DDA)" }, MultipleOptions = false,
    Flag = "SPPath",
    Callback = function(v) SP.pathKind = (typeof(v) == "table") and v[1] or v end
})

tabEdit:CreateSlider({
    Name = "Path Radius", Range = { 0, 8 }, Increment = 1, CurrentValue = 1,
    Suffix = "blk", Flag = "SPRad", Callback = function(v) SP.radius = v end
})
tabEdit:CreateSlider({
    Name = "Catenary Slack", Range = { 0, 20 }, Increment = 1, CurrentValue = 3,
    Suffix = "blk", Flag = "SPSlack", Callback = function(v) SP.slack = v end
})
tabEdit:CreateToggle({
    Name = "Looped Path",
    CurrentValue = false,
    Tooltip = "Join the last node back to the first.",
    Callback = function(v) SP.looped = v end
})
tabEdit:CreateButton({
    Name = "Build Path",
    Tooltip = "Draw the path through the nodes using the Active Block.",
    Callback = buildPath
})

tabEdit:CreateDivider()

SP.modNames = {}
for _, e in ipairs(MODS) do SP.modNames[#SP.modNames + 1] = e[1] end

tabEdit:CreateDropdown({
    Name = "Modify Mode",
    Options = SP.modNames, CurrentOption = { "Translate Copies" }, MultipleOptions = false,
    Flag = "SPMod",
    Callback = function(v)
        SP.modMode = (typeof(v) == "table") and v[1] or v
        for _, e in ipairs(MODS) do
            if e[1] == SP.modMode then
                pcall(function() modDesc:Set({ Title = e[1], Content = e[2] }) end)
                break
            end
        end
    end
})

modDesc = tabEdit:CreateParagraph({ Title = MODS[1][1], Content = MODS[1][2] })

tabEdit:CreateSlider({
    Name = "Copy Count", Range = { 1, 32 }, Increment = 1, CurrentValue = 3,
    Suffix = "x", Flag = "SPCount", Callback = function(v) SP.count = v end
})
for _, ax in ipairs({ { "Offset X", "SPOX", 1 }, { "Offset Y", "SPOY", 2 }, { "Offset Z", "SPOZ", 3 } }) do
    tabEdit:CreateSlider({
        Name = ax[1], Range = { -32, 32 }, Increment = 1, CurrentValue = 0,
        Suffix = "blk", Flag = ax[2],
        Callback = function(v)
            if ax[3] == 1 then SP.offX = v elseif ax[3] == 2 then SP.offY = v else SP.offZ = v end
        end
    })
end
tabEdit:CreateSlider({
    Name = "Angle", Range = { 1, 360 }, Increment = 1, CurrentValue = 90,
    Suffix = "deg", Flag = "SPAngle", Callback = function(v) SP.angle = v end
})
tabEdit:CreateButton({
    Name = "Run Modify",
    Tooltip = "Apply the selected transform to the Builder selection.",
    Callback = runModify
})

end

-- ═══════════════════════════════════════════════════════════════════════════
-- FLUID BALL, MODELLING, GAUSSIAN SMOOTH / WELD / MELT
--
-- Own do-block: the main chunk has only ~39 locals of headroom, so every module
-- must keep its declarations inside a scope of its own. See check_locals.py.
-- ═══════════════════════════════════════════════════════════════════════════
do

local BA = BuilderAPI
local B, O = BA.B, BA.O
local key3, toCell, targetPart = BA.key3, BA.toCell, BA.targetPart
local blockPartMap, placeCells, eraseCells, runCommit =
    BA.blockPartMap, BA.placeCells, BA.eraseCells, BA.runCommit
local needSelection, selBounds, selCells = BA.needSelection, BA.selBounds, BA.selCells

local M = {
    fluid = "water",
    fluidRadius = 3,
    flowLength = 6,
    modelMode = "Convex Hull",
    nodes = {},
    smoothStrength = 2,
    blockRatio = 100,
    weldStrength = 3,
    weldThreshold = 50,
}

local fluidPara, modelPara

-- ═══════════════════════════════════════════════════════════════════════════
-- FLUID BALL
-- Block names are discovered at runtime rather than hardcoded, since the
-- game's internal names are not guaranteed to be "water"/"lava"/"snow".
-- ═══════════════════════════════════════════════════════════════════════════
local function findFluidNames()
    local found = { water = nil, lava = nil, snow = nil }
    local folder = ReplicatedStorage:FindFirstChild("blocks")
    if not folder then return found end
    for _, v in ipairs(folder:GetChildren()) do
        local low = v.Name:lower()
        if not found.water and low:find("water") then found.water = v.Name end
        if not found.lava and (low:find("lava") or low:find("magma")) then found.lava = v.Name end
        if not found.snow and low:find("snow") then found.snow = v.Name end
    end
    return found
end

local function reportFluids()
    local f = findFluidNames()
    local lines = {}
    for _, k in ipairs({ "water", "lava", "snow" }) do
        lines[#lines + 1] = k .. ": " .. (f[k] or "not found in this game")
    end
    pcall(function()
        fluidPara:Set({ Title = "Fluid Blocks", Content = table.concat(lines, "\n") })
    end)
    return f
end

-- Places a ball of fluid, then lets it run downhill across the surface.
local function fluidBall()
    local part = targetPart()
    if not part then notifyWarn("Fluid Ball", "Point at a block first", 3) return end
    local names = findFluidNames()
    local blockName = names[M.fluid]
    if not blockName then
        notifyErr("Fluid Ball", "No " .. M.fluid .. " block exists in this game", 5)
        reportFluids()
        return
    end

    runCommit("Fluid Ball", function(rec)
        local map = blockPartMap()
        local cx, cy, cz = toCell(part.Position)
        local r = M.fluidRadius
        local seen, sources, cells = {}, {}, {}

        -- the initial ball, only where there is space
        for dx = -r, r do
            for dy = -r, r do
                for dz = -r, r do
                    if dx * dx + dy * dy + dz * dz <= r * r then
                        local x, y, z = cx + dx, cy + dy + r, cz + dz
                        local k = key3(x, y, z)
                        if not map[k] and not seen[k] then
                            seen[k] = true
                            cells[#cells + 1] = { x, y, z, blockName }
                            sources[#sources + 1] = { x, y, z }
                        end
                    end
                end
            end
        end

        -- spread outward and downward, the way a fluid settles on terrain
        local frontier = sources
        for _ = 1, M.flowLength do
            local nextF = {}
            for _, c in ipairs(frontier) do
                for _, d in ipairs({ {1,0,0},{-1,0,0},{0,0,1},{0,0,-1},{0,-1,0} }) do
                    local x, y, z = c[1] + d[1], c[2] + d[2], c[3] + d[3]
                    local k = key3(x, y, z)
                    -- flow into empty space that has something to sit on
                    if not map[k] and not seen[k] and (map[key3(x, y - 1, z)] or d[2] == -1) then
                        seen[k] = true
                        cells[#cells + 1] = { x, y, z, blockName }
                        nextF[#nextF + 1] = { x, y, z }
                    end
                end
            end
            frontier = nextF
            if #frontier == 0 then break end
        end

        if #cells == 0 then notifyWarn("Fluid Ball", "No space to place fluid", 3) return end
        placeCells(cells, rec)
        notifyOK("Fluid Ball", #cells .. " x " .. blockName, 5)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MODELLING
-- Convex Hull: every triple of nodes forms a candidate face; a triple is a real
-- hull face when all other nodes sit on one side of its plane. A cell is inside
-- when it is behind every face.
-- ═══════════════════════════════════════════════════════════════════════════
local function hullFaces(pts)
    local faces = {}
    local n = #pts
    for i = 1, n - 2 do
        for j = i + 1, n - 1 do
            for k = j + 1, n do
                local a, b, c = pts[i], pts[j], pts[k]
                local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
                local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
                -- plane normal from the cross product
                local nx = uy * vz - uz * vy
                local ny = uz * vx - ux * vz
                local nz = ux * vy - uy * vx
                if nx ~= 0 or ny ~= 0 or nz ~= 0 then
                    local pos, neg = false, false
                    for m2 = 1, n do
                        if m2 ~= i and m2 ~= j and m2 ~= k then
                            local p = pts[m2]
                            local s = nx * (p[1] - a[1]) + ny * (p[2] - a[2]) + nz * (p[3] - a[3])
                            if s > 1e-9 then pos = true elseif s < -1e-9 then neg = true end
                        end
                    end
                    -- All remaining points on one side => this is a hull face.
                    -- Those points are the interior, so the outward normal is
                    -- the one pointing AWAY from them: flip when they are on
                    -- the positive side. Getting this backwards makes every
                    -- test fail and the hull come out empty.
                    if not (pos and neg) then
                        local sign = pos and -1 or 1
                        faces[#faces + 1] = { a, nx * sign, ny * sign, nz * sign }
                    end
                end
            end
        end
    end
    return faces
end

local function buildModel()
    if #M.nodes < 3 then
        notifyWarn("Modelling", "Add at least 3 nodes", 4)
        return
    end
    runCommit("Modelling", function(rec)
        local pts = M.nodes
        local minX, maxX = math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge
        local minZ, maxZ = math.huge, -math.huge
        for _, p in ipairs(pts) do
            minX = math.min(minX, p[1]) maxX = math.max(maxX, p[1])
            minY = math.min(minY, p[2]) maxY = math.max(maxY, p[2])
            minZ = math.min(minZ, p[3]) maxZ = math.max(maxZ, p[3])
        end

        local cells = {}
        if M.modelMode == "Convex Hull" then
            local faces = hullFaces(pts)
            if #faces == 0 then
                notifyWarn("Modelling", "Nodes are flat or in a line; hull needs volume", 5)
                return
            end
            for x = minX, maxX do
                for y = minY, maxY do
                    for z = minZ, maxZ do
                        local inside = true
                        for _, f in ipairs(faces) do
                            local a = f[1]
                            local s = f[2] * (x - a[1]) + f[3] * (y - a[2]) + f[4] * (z - a[3])
                            if s > 1e-9 then inside = false break end
                        end
                        if inside then cells[#cells + 1] = { x, y, z, O.activeBlock } end
                    end
                end
            end
        else
            -- Triangle Fan: every triangle shares node 1, sampled barycentrically
            local seen = {}
            local a = pts[1]
            for i = 2, #pts - 1 do
                local b, c = pts[i], pts[i + 1]
                local steps = 40
                for u = 0, steps do
                    for v = 0, steps - u do
                        local wu, wv = u / steps, v / steps
                        local ww = 1 - wu - wv
                        local x = math.floor(a[1] * ww + b[1] * wu + c[1] * wv + 0.5)
                        local y = math.floor(a[2] * ww + b[2] * wu + c[2] * wv + 0.5)
                        local z = math.floor(a[3] * ww + b[3] * wu + c[3] * wv + 0.5)
                        local k = key3(x, y, z)
                        if not seen[k] then
                            seen[k] = true
                            cells[#cells + 1] = { x, y, z, O.activeBlock }
                        end
                    end
                end
            end
        end

        if #cells == 0 then notifyWarn("Modelling", "Nothing produced", 3) return end
        placeCells(cells, rec)
        notifyOK("Modelling", M.modelMode .. ": " .. #cells .. " blocks", 5)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GAUSSIAN SMOOTH / WELD / MELT
-- All three blur a column height field. Smooth keeps the block count, Weld
-- biases upward (adds mass), Melt biases downward (removes it).
-- ═══════════════════════════════════════════════════════════════════════════
local function columnHeights(map, minX, maxX, minY, maxY, minZ, maxZ)
    local h, types = {}, {}
    for x = minX, maxX do
        for z = minZ, maxZ do
            local top = nil
            for y = maxY, minY, -1 do
                if map[key3(x, y, z)] then top = y break end
            end
            local k = x .. "," .. z
            h[k] = top or (minY - 1)
            if top then types[k] = map[key3(x, top, z)].Name end
        end
    end
    return h, types
end

-- separable-ish Gaussian over the column grid
local function blurHeights(h, minX, maxX, minZ, maxZ, strength)
    local out = {}
    local rad = math.max(1, math.floor(strength))
    local sigma = math.max(strength, 0.5)
    for x = minX, maxX do
        for z = minZ, maxZ do
            local sum, wsum = 0, 0
            for ox = -rad, rad do
                for oz = -rad, rad do
                    local v = h[(x + ox) .. "," .. (z + oz)]
                    if v then
                        local w = math.exp(-(ox * ox + oz * oz) / (2 * sigma * sigma))
                        sum = sum + v * w
                        wsum = wsum + w
                    end
                end
            end
            out[x .. "," .. z] = wsum > 0 and (sum / wsum) or h[x .. "," .. z]
        end
    end
    return out
end

local function gaussianOp(mode)
    if not needSelection() then return end
    runCommit(mode, function(rec)
        local map = blockPartMap()
        local minX, maxX, minY, maxY, minZ, maxZ = selBounds()
        local h, types = columnHeights(map, minX, maxX, minY, maxY, minZ, maxZ)
        local blurred = blurHeights(h, minX, maxX, minZ, maxZ, M.smoothStrength)

        -- Smooth preserves total mass; the ratio nudges it up or down.
        local before, after = 0, 0
        for k, v in pairs(h) do before = before + math.max(v - minY + 1, 0) end
        for k, v in pairs(blurred) do after = after + math.max(v - minY + 1, 0) end
        local bias = 0
        if mode == "Smooth" and after > 0 then
            local target = before * (M.blockRatio / 100)
            bias = (target - after) / math.max(#selCells() / math.max(maxY - minY + 1, 1), 1)
        elseif mode == "Weld" then
            bias = M.weldStrength
        elseif mode == "Melt" then
            bias = -M.weldStrength
        end

        local add, remove = {}, {}
        for k, target in pairs(blurred) do
            local x, z = k:match("(-?%d+),(-?%d+)")
            x, z = tonumber(x), tonumber(z)
            local newTop = math.floor(target + bias + 0.5)
            local oldTop = h[k]
            local name = types[k] or O.activeBlock
            if newTop > oldTop then
                for y = oldTop + 1, math.min(newTop, maxY) do
                    add[#add + 1] = { x, y, z, name }
                end
            elseif newTop < oldTop then
                for y = math.max(newTop + 1, minY), oldTop do
                    remove[#remove + 1] = { x, y, z }
                end
            end
        end

        if #add == 0 and #remove == 0 then
            notifyWarn(mode, "Nothing changed; try a higher strength", 3)
            return
        end
        if #remove > 0 then eraseCells(remove, rec) end
        if #add > 0 then placeCells(add, rec) end
        notifyOK(mode, "+" .. #add .. " / -" .. #remove .. " blocks", 5)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════════
tabEdit:CreateDivider()

fluidPara = tabEdit:CreateParagraph({
    Title = "Fluid Blocks",
    Content = "Press Detect to see which fluid blocks this game actually has.",
})

tabEdit:CreateButton({
    Name = "Detect Fluid Blocks",
    Tooltip = "Scan the game's block list for water, lava and snow.",
    Callback = function() reportFluids() end
})

tabEdit:CreateDropdown({
    Name = "Fluid Type",
    Options = { "water", "lava", "snow" }, CurrentOption = { "water" }, MultipleOptions = false,
    Flag = "FBType",
    Callback = function(v) M.fluid = (typeof(v) == "table") and v[1] or v end
})

tabEdit:CreateSlider({
    Name = "Fluid Radius", Range = { 1, 10 }, Increment = 1, CurrentValue = 3,
    Suffix = "blk", Flag = "FBRad", Callback = function(v) M.fluidRadius = v end
})
tabEdit:CreateSlider({
    Name = "Flow Length", Range = { 0, 24 }, Increment = 1, CurrentValue = 6,
    Suffix = "blk", Flag = "FBFlow", Callback = function(v) M.flowLength = v end
})
tabEdit:CreateButton({
    Name = "Place Fluid at Cursor",
    Tooltip = "Drop a ball of fluid above the block you are pointing at and let it run downhill.",
    Callback = fluidBall
})

tabEdit:CreateDivider()

modelPara = tabEdit:CreateParagraph({
    Title = "Model Nodes",
    Content = "No nodes. Point at blocks and press Add Node to outline a shape.",
})

tabEdit:CreateDropdown({
    Name = "Model Mode",
    Options = { "Convex Hull", "Triangle Fan" }, CurrentOption = { "Convex Hull" },
    MultipleOptions = false, Flag = "MDMode",
    Callback = function(v) M.modelMode = (typeof(v) == "table") and v[1] or v end
})

tabEdit:CreateButton({
    Name = "Add Model Node",
    Gear = { { Type = "button", Name = "Clear Model Nodes", OnClick = function()
        M.nodes = {}
        pcall(function()
            modelPara:Set({ Title = "Model Nodes", Content = "No nodes." })
        end)
        notify("Modelling", "Nodes cleared", 2, "info")
    end } },
    Tooltip = "Append the block under your cursor to the model.",
    Callback = function()
        local part = targetPart()
        if not part then notifyWarn("Modelling", "Point at a block first", 3) return end
        local x, y, z = toCell(part.Position)
        M.nodes[#M.nodes + 1] = { x, y, z }
        pcall(function()
            modelPara:Set({ Title = "Model Nodes", Content = #M.nodes .. " nodes placed." })
        end)
        notifyOK("Modelling", "Node " .. #M.nodes, 2)
    end
})

tabEdit:CreateButton({
    Name = "Build Model",
    Tooltip = "Fill the shape described by the nodes with the Active Block.",
    Callback = buildModel
})

tabEdit:CreateDivider()

tabEdit:CreateParagraph({
    Title = "Gaussian Terrain",
    Content = "Blurs the surface height of the selection. Smooth keeps the block count, Weld adds mass, Melt removes it.",
})

tabEdit:CreateSlider({
    Name = "Smoothing Strength", Range = { 1, 8 }, Increment = 1, CurrentValue = 2,
    Flag = "GSStr", Callback = function(v) M.smoothStrength = v end
})
tabEdit:CreateSlider({
    Name = "Block Ratio", Range = { 80, 120 }, Increment = 1, CurrentValue = 100,
    Suffix = "%", Flag = "GSRatio", Callback = function(v) M.blockRatio = v end
})
tabEdit:CreateSlider({
    Name = "Weld / Melt Amount", Range = { 1, 10 }, Increment = 1, CurrentValue = 3,
    Suffix = "blk", Flag = "GSWeld", Callback = function(v) M.weldStrength = v end
})

for _, mode in ipairs({ "Smooth", "Weld", "Melt" }) do
    tabEdit:CreateButton({
        Name = mode .. " (Gaussian)",
        Tooltip = "Gaussian " .. mode:lower() .. " over the selection's surface.",
        Callback = function() gaussianOp(mode) end
    })
end

end

-- ═══════════════════════════════════════════════════════════════════════════
-- IMAGE TOOLS — PNG decode, pixel art, and image heightmaps
--
-- PNG decoder adapted from the ImageConverter source, with fixes noted inline.
-- Pixels are matched to blocks through the Colour tab's OKLab index, memoised
-- so each distinct pixel colour is only matched once.
--
-- Own do-block; see check_locals.py for the 200-local budget.
-- ═══════════════════════════════════════════════════════════════════════════
do

local BA = BuilderAPI
local O = BA.O
local key3, toCell, targetPart = BA.key3, BA.toCell, BA.targetPart
local placeCells, runCommit = BA.placeCells, BA.runCommit

local IMG = {
    url = "",
    width = 48,
    mode = "Pixel Art (Wall)",
    maxHeight = 24,
    file = "MyImage",
    cache = nil,      -- decoded { pixels = {}, w = , h = }
    match = {},       -- memo: "r,g,b" -> block name
    groups = {},      -- palette groups in play; empty = all of them
    limit = 0,        -- max distinct blocks for the whole image; 0 = no limit
    chosen = nil,     -- the reduced palette picked for this image, when limited
}

-- The image status used to live in a paragraph on the tab, which sat there
-- empty most of the time taking up space. It is a notification now.
local function say(title, body)
    notify(title, body, 5, "info")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INFLATE  (zlib / DEFLATE)
-- ═══════════════════════════════════════════════════════════════════════════
local band, lshift, rshift = bit32.band, bit32.lshift, bit32.rshift

local LENS = { [0] = 3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258 }
local LEXT = { [0] = 0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0 }
local DISTS = { [0] = 1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577 }
local DEXT = { [0] = 0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13 }
local ORDER = { 16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15 }
local FIXED_LIT = { 0,8,144,9,256,7,280,8,288 }
local FIXED_DIST = { 0,5,32 }

local function memoize(fn)
    local meta = {}
    local m = setmetatable({}, meta)
    function meta:__index(k) local v = fn(k) m[k] = v return v end
    return m
end

local pow2 = memoize(function(n) return 2 ^ n end)

local function createBitStream(reader)
    local buffer, bitsLeft = 0, 0
    local stream = {}
    function stream:GetBitsLeft() return bitsLeft end
    function stream:Read(count)
        count = count or 1
        while bitsLeft < count do
            local byte = reader:ReadByte()
            if not byte then return end
            buffer = buffer + lshift(byte, bitsLeft)
            bitsLeft = bitsLeft + 8
        end
        local bits
        if count == 0 then bits = 0
        elseif count == 32 then bits = buffer buffer = 0
        else
            bits = band(buffer, rshift(2 ^ 32 - 1, 32 - count))
            buffer = rshift(buffer, count)
        end
        bitsLeft = bitsLeft - count
        return bits
    end
    return stream
end

local function msb(bits, numBits)
    local res = 0
    for _ = 1, numBits do
        res = lshift(res, 1) + band(bits, 1)
        bits = rshift(bits, 1)
    end
    return res
end

local function createHuffmanTable(init, isFull)
    local t = {}
    if isFull then
        for val, numBits in pairs(init) do
            if numBits ~= 0 then t[#t + 1] = { Value = val, NumBits = numBits } end
        end
    else
        for i = 1, #init - 2, 2 do
            local firstVal, numBits, nextVal = init[i], init[i + 1], init[i + 2]
            if numBits ~= 0 then
                for val = firstVal, nextVal - 1 do
                    t[#t + 1] = { Value = val, NumBits = numBits }
                end
            end
        end
    end
    table.sort(t, function(a, b)
        return a.NumBits == b.NumBits and a.Value < b.Value or a.NumBits < b.NumBits
    end)
    local code, numBits = 1, 0
    for _, slide in ipairs(t) do
        if slide.NumBits ~= numBits then
            code = code * pow2[slide.NumBits - numBits]
            numBits = slide.NumBits
        end
        slide.Code = code
        code = code + 1
    end
    local minBits, look = math.huge, {}
    for _, slide in ipairs(t) do
        minBits = math.min(minBits, slide.NumBits)
        look[slide.Code] = slide.Value
    end
    local firstCode = memoize(function(bits) return pow2[minBits] + msb(bits, minBits) end)
    function t:Read(bitStream)
        local c, nb = 1, 0
        while true do
            if nb == 0 then
                c = firstCode[bitStream:Read(minBits)]
                nb = nb + minBits
            else
                c = c * 2 + bitStream:Read()
                nb = nb + 1
            end
            local val = look[c]
            if val then return val end
        end
    end
    return t
end

local function parseZlibHeader(bitStream)
    local cm = bitStream:Read(4)
    local cinfo = bitStream:Read(4)
    local fcheck = bitStream:Read(5)
    local fdict = bitStream:Read(1)
    local flevel = bitStream:Read(2)
    local cmf = cinfo * 16 + cm
    local flg = fcheck + fdict * 32 + flevel * 64
    if cm ~= 8 then error("unsupported zlib compression " .. tostring(cm)) end
    if cinfo > 7 then error("invalid zlib window size") end
    if (cmf * 256 + flg) % 31 ~= 0 then error("bad zlib header checksum") end
    if fdict == 1 then error("zlib FDICT not supported") end
end

local function parseHuffmanTables(bitStream)
    local numLits, numDists, numCodes = bitStream:Read(5), bitStream:Read(5), bitStream:Read(4)
    local codeLens = {}
    for i = 1, numCodes + 4 do codeLens[ORDER[i]] = bitStream:Read(3) end
    codeLens = createHuffmanTable(codeLens, true)
    local function decode(n)
        local init, numBits, val = {}, nil, 0
        while val < n do
            local codeLen = codeLens:Read(bitStream)
            local numRepeats
            if codeLen <= 15 then numRepeats = 1 numBits = codeLen
            elseif codeLen == 16 then numRepeats = 3 + bitStream:Read(2)
            elseif codeLen == 17 then numRepeats = 3 + bitStream:Read(3) numBits = 0
            else numRepeats = 11 + bitStream:Read(7) numBits = 0 end
            for _ = 1, numRepeats do init[val] = numBits val = val + 1 end
        end
        return createHuffmanTable(init, true)
    end
    return decode(numLits + 257), decode(numDists + 1)
end

-- `skipHeader` is for gzip, whose header the caller has already stepped over;
-- a zlib stream still needs its two-byte header read off the front.
local function inflate(reader, out, skipHeader)
    local bitStream = createBitStream(reader)
    if not skipHeader then parseZlibHeader(bitStream) end
    local window, pos = {}, 1
    -- Yield every so many bytes written. Without this the whole stream is
    -- decompressed in one uninterrupted go, and a megabyte-scale PNG - a
    -- model texture, say - locks the client up for the best part of a second
    -- with no way to tell it apart from a hang.
    local written = 0
    local function write(byte)
        out(byte)
        window[pos] = byte
        pos = pos % 32768 + 1
        written = written + 1
        if written % 24000 == 0 then task.wait() end
    end
    repeat
        local bFinal = bitStream:Read(1)
        local bType = bitStream:Read(2)
        if bType == 0 then
            bitStream:Read(bitStream:GetBitsLeft())
            local len = bitStream:Read(16)
            bitStream:Read(16)
            for _ = 1, len do write(bitStream:Read(8)) end
        elseif bType == 1 or bType == 2 then
            local litTable, distTable
            if bType == 2 then
                litTable, distTable = parseHuffmanTables(bitStream)
            else
                litTable = createHuffmanTable(FIXED_LIT)
                distTable = createHuffmanTable(FIXED_DIST)
            end
            while true do
                local val = litTable:Read(bitStream)
                if val < 256 then
                    write(val)
                elseif val == 256 then
                    break
                else
                    local len = LENS[val - 257] + bitStream:Read(LEXT[val - 257])
                    local dv = distTable:Read(bitStream)
                    local dist = DISTS[dv] + bitStream:Read(DEXT[dv])
                    for _ = 1, len do
                        write(assert(window[(pos - 1 - dist) % 32768 + 1], "back-reference out of range"))
                    end
                end
            end
        else
            error("invalid DEFLATE block type")
        end
    until bFinal ~= 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PNG
-- ═══════════════════════════════════════════════════════════════════════════
local Reader = {}
Reader.__index = Reader

function Reader.new(buf)
    return setmetatable({ Position = 1, Buffer = buf, Length = #buf }, Reader)
end
function Reader:ReadByte()
    local p = self.Position
    if p <= self.Length then
        self.Position = p + 1
        return self.Buffer:byte(p)
    end
end
function Reader:ReadBytes(n, asArray)
    local v = {}
    for i = 1, n do v[i] = self:ReadByte() end
    if asArray then return v end
    return table.unpack(v)
end
function Reader:ReadUInt16() local a, b = self:ReadBytes(2) return a * 256 + b end
function Reader:ReadUInt32() return self:ReadUInt16() * 65536 + self:ReadUInt16() end
function Reader:ReadInt32()
    local u = self:ReadUInt32()
    if u >= 2 ^ 31 then u = u - 2 ^ 32 end
    return u
end
function Reader:ReadString(len)
    local p = self.Position
    local nextP = math.min(self.Length + 1, p + len)
    self.Position = nextP
    return self.Buffer:sub(p, nextP - 1)
end
function Reader:Fork(len) return Reader.new(self:ReadString(len)) end

local function bytesPerPixel(colorType)
    if colorType == 0 or colorType == 3 then return 1
    elseif colorType == 4 then return 2
    elseif colorType == 2 then return 3
    elseif colorType == 6 then return 4 end
    return 0
end

-- Unfilter. NOTE: the source's Average filter read pixels[row-1] in its own
-- row == 1 branch, which is nil and throws. Row 1 has no row above, so the
-- upper term is simply zero there.
local function unfilter(ft, scan, pixels, bpp, row)
    local out = pixels[row]
    local up = pixels[row - 1]
    if ft == 0 then
        for i = 1, #scan do out[i] = scan[i] end
    elseif ft == 1 then
        for i = 1, bpp do out[i] = scan[i] end
        for i = bpp + 1, #scan do out[i] = band(scan[i] + out[i - bpp], 0xFF) end
    elseif ft == 2 then
        if up then
            for i = 1, #scan do out[i] = band(scan[i] + up[i], 0xFF) end
        else
            for i = 1, #scan do out[i] = scan[i] end
        end
    elseif ft == 3 then
        for i = 1, #scan do
            local a = (i > bpp) and out[i - bpp] or 0
            local b = up and up[i] or 0
            out[i] = band(scan[i] + rshift(a + b, 1), 0xFF)
        end
    elseif ft == 4 then
        for i = 1, #scan do
            local a = (i > bpp) and out[i - bpp] or 0
            local b = up and up[i] or 0
            local c = (up and i > bpp) and up[i - bpp] or 0
            local p = a + b - c
            local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
            local pr
            if pa <= pb and pa <= pc then pr = a elseif pb <= pc then pr = b else pr = c end
            out[i] = band(scan[i] + pr, 0xFF)
        end
    else
        for i = 1, #scan do out[i] = scan[i] end
    end
end

-- Works out what a download actually is, so a wrong link produces a useful
-- message instead of "bad signature".
local function sniffFormat(data)
    if not data or #data == 0 then return "nothing", "The link returned an empty response." end
    local head = data:sub(1, 16)
    if head:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
    if head:sub(1, 3) == "\255\216\255" then
        return "jpeg", "That link is a JPEG. Only PNG is supported - convert it to .png first."
    end
    if head:sub(1, 4) == "GIF8" then
        return "gif", "That link is a GIF. Only PNG is supported."
    end
    if head:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WEBP" then
        return "webp", "That link is a WebP. Only PNG is supported - convert it to .png first."
    end
    if head:sub(1, 2) == "BM" then
        return "bmp", "That link is a BMP. Only PNG is supported."
    end
    local start = data:sub(1, 400):lower()
    if start:find("<!doctype") or start:find("<html") or start:find("<head") then
        return "html", "That link returned a web page, not an image. Open the image itself, "
            .. "right-click it and copy the image address - it should end in .png"
    end
    if start:find("^%s*{") or start:find("^%s*%[") then
        return "json", "That link returned JSON, not an image. Use a direct image URL."
    end
    -- unknown: show the leading bytes so the cause is at least visible
    local hex = {}
    for i = 1, math.min(#data, 8) do hex[#hex + 1] = string.format("%02X", data:byte(i)) end
    return "unknown", "Not a PNG. First bytes: " .. table.concat(hex, " ")
        .. " (" .. #data .. " bytes). Use a direct .png link."
end

-- Returns { w, h, get(x, y) -> r, g, b, a } with 0-255 channels.
local function decodePNG(data)
    local kind, why = sniffFormat(data)
    if kind ~= "png" then
        error(why or "not a PNG file")
    end
    local reader = Reader.new(data)
    reader:ReadString(8)

    local width, height, bitDepth, colorType
    local palette, alphaData
    local zlib = {}
    local reading = true

    while reading do
        local length = reader:ReadInt32()
        local ctype = reader:ReadString(4)
        local chunk
        if length > 0 then
            chunk = reader:Fork(length)
            reader:ReadUInt32()          -- CRC, not verified
        end
        if ctype == "IHDR" then
            width = chunk:ReadInt32()
            height = chunk:ReadInt32()
            bitDepth = chunk:ReadByte()
            colorType = chunk:ReadByte()
            chunk:ReadByte() chunk:ReadByte()
            local interlace = chunk:ReadByte()
            if interlace ~= 0 then error("interlaced PNGs are not supported") end
        elseif ctype == "PLTE" then
            palette = {}
            local raw = chunk:ReadBytes(chunk.Length, true)
            for i = 1, #raw, 3 do
                palette[#palette + 1] = { raw[i], raw[i + 1], raw[i + 2] }
            end
        elseif ctype == "tRNS" then
            if colorType == 3 then
                alphaData = chunk:ReadBytes(chunk.Length, true)
            end
        elseif ctype == "IDAT" then
            zlib[#zlib + 1] = chunk.Buffer
        elseif ctype == "IEND" then
            reading = false
        end
        if reader.Position > reader.Length then reading = false end
    end

    if not width then error("PNG has no IHDR header") end
    if bitDepth ~= 8 then
        error("only 8-bit PNGs are supported (this one is " .. tostring(bitDepth) .. "-bit)")
    end

    local outBytes, n = {}, 0
    inflate(Reader.new(table.concat(zlib)), function(byte)
        n = n + 1
        outBytes[n] = string.char(byte)
    end)

    local buf = Reader.new(table.concat(outBytes))
    local channels = bytesPerPixel(colorType)
    local bpp = math.max(1, channels)
    local rows = {}
    for row = 1, height do
        local ft = buf:ReadByte()
        local scan = buf:ReadBytes(width * bpp, true)
        rows[row] = {}
        unfilter(ft, scan, rows, bpp, row)
        if row % 64 == 0 then task.wait() end
    end

    local function get(x, y)
        local row = rows[y]
        if not row then return 0, 0, 0, 0 end
        local i = (x - 1) * bpp + 1
        if colorType == 0 then
            local g = row[i] or 0
            return g, g, g, 255
        elseif colorType == 4 then
            local g = row[i] or 0
            return g, g, g, row[i + 1] or 255
        elseif colorType == 2 then
            return row[i] or 0, row[i + 1] or 0, row[i + 2] or 0, 255
        elseif colorType == 6 then
            return row[i] or 0, row[i + 1] or 0, row[i + 2] or 0, row[i + 3] or 255
        elseif colorType == 3 then
            local idx = (row[i] or 0) + 1
            local p = palette and palette[idx] or { 0, 0, 0 }
            local a = alphaData and alphaData[idx] or 255
            return p[1], p[2], p[3], a
        end
        return 0, 0, 0, 255
    end

    return { w = width, h = height, get = get, colorType = colorType }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- IMAGE -> BLOCKS
-- ═══════════════════════════════════════════════════════════════════════════
-- Pixel art only looks right with flat, solid-colour blocks, and only if their
-- colours are accurate. Matching against all 316 blocks (stairs, slabs, ores,
-- textured stone) with colours guessed from a grey template is what made images
-- come out wrong. This is a hand-picked palette of the game's flat blocks with
-- their real colours; images match against just these.
local IMAGE_PALETTE = {
    -- { name, r, g, b, group }
    -- basic colour blocks
    { "whiteBlock", 236,236,236, "Solid" }, { "blackBlock", 30,30,32, "Solid" },
    { "redBlock", 200,45,45, "Solid" }, { "blueBlock", 45,80,200, "Solid" }, { "cyanBlock", 55,190,205, "Solid" },
    { "pinkBlock", 235,120,175, "Solid" }, { "orangeBlock", 230,130,40, "Solid" }, { "purpleBlock", 130,55,180, "Solid" },
    { "yellowBlock", 235,205,55, "Solid" }, { "lightGreenBlock", 120,200,90, "Solid" }, { "darkGreenBlock", 45,110,55, "Solid" },
    -- wool (softer)
    { "woolWhite", 240,240,235, "Wool" }, { "woolBlack", 45,45,48, "Wool" }, { "woolRed", 190,60,55, "Wool" },
    { "woolBlue", 55,90,180, "Wool" }, { "woolCyan", 80,190,200, "Wool" }, { "woolPink", 235,150,190, "Wool" },
    { "woolOrange", 225,145,60, "Wool" }, { "woolPurple", 135,75,175, "Wool" }, { "woolYellow", 235,210,90, "Wool" },
    { "woolLightGreen", 140,205,110, "Wool" }, { "woolDarkGreen", 60,120,65, "Wool" },
    -- clay (earthy, muted)
    { "clayWhite", 220,210,200, "Clay" }, { "clayBlack", 55,50,50, "Clay" }, { "clayRed", 175,80,60, "Clay" },
    { "clayBlue", 90,110,160, "Clay" }, { "clayCyan", 110,170,175, "Clay" }, { "clayPink", 220,150,150, "Clay" },
    { "clayOrange", 200,120,70, "Clay" }, { "clayPurple", 140,100,150, "Clay" }, { "clayYellow", 215,185,110, "Clay" },
    { "clayLightGreen", 150,180,120, "Clay" }, { "clayDarkGreen", 90,120,80, "Clay" },
    -- neon (vivid)
    { "neonWhite", 255,255,255, "Neon" }, { "neonBlack", 40,40,45, "Neon" }, { "neonRed", 255,50,50, "Neon" },
    { "neonBlue", 50,90,255, "Neon" }, { "neonCyan", 40,240,240, "Neon" }, { "neonPink", 255,90,200, "Neon" },
    { "neonOrange", 255,140,30, "Neon" }, { "neonPurple", 180,50,240, "Neon" }, { "neonYellow", 250,240,40, "Neon" },
    { "neonLightGreen", 120,255,90, "Neon" }, { "neonDarkGreen", 30,180,60, "Neon" },
    -- pastel (light)
    { "pastelPinkBlock", 245,200,215, "Pastel" }, { "pastelBlueBlock", 190,215,240, "Pastel" },
    { "pastelGreenBlock", 200,230,190, "Pastel" }, { "pastelPurpleBlock", 210,195,235, "Pastel" },
    { "pastelYellowBlock", 245,235,190, "Pastel" }, { "pastelOrangeBlock", 245,210,175, "Pastel" },
    { "pastelRedBlock", 240,180,180, "Pastel" },
    -- wood tones
    { "woodPlank", 165,120,75, "Wood" }, { "maplePlank", 175,95,65, "Wood" },
    { "birchPlank", 220,205,165, "Wood" }, { "pinePlank", 115,95,70, "Wood" },
    { "hickoryPlank", 145,105,70, "Wood" }, { "cherryBlossomPlank", 240,185,200, "Wood" },
    { "spiritPlank", 95,200,180, "Wood" }, { "bambooBlock", 200,190,120, "Wood" },
    { "leavesBlock", 60,140,60, "Wood" }, { "haybaleBlock", 210,185,80, "Wood" },
    -- stone tones
    { "marbleBlock", 235,235,240, "Stone" }, { "slateBlock", 90,100,120, "Stone" },
    { "basalt", 60,60,66, "Stone" }, { "granite", 150,120,115, "Stone" },
    { "andesite", 140,140,145, "Stone" }, { "diorite", 210,210,215, "Stone" },
    { "stone", 140,140,145, "Stone" }, { "cobblestoneBlock", 120,120,125, "Stone" },
    { "sandstone", 220,200,150, "Stone" }, { "brick", 170,80,60, "Stone" },
    { "prismarineBlock", 70,160,150, "Stone" },
    -- naturals
    { "grass", 95,170,75, "Natural" }, { "grassDry", 200,180,95, "Natural" },
    { "sand", 225,205,150, "Natural" }, { "snow", 245,245,250, "Natural" },
    { "ice", 175,215,245, "Natural" }, { "mudBlock", 95,70,50, "Natural" },
    { "magmaBlock", 210,80,40, "Natural" }, { "voidBlock", 60,35,95, "Natural" },
    -- ores and gems
    { "goldBlock", 235,200,70, "Ore" }, { "ironBlock", 200,200,205, "Ore" },
    { "diamondBlock", 150,225,235, "Ore" }, { "coalBlock", 45,45,50, "Ore" },
    { "copperBlock", 200,120,70, "Ore" }, { "amethystBlock", 150,90,200, "Ore" },
    { "rubyBlock", 190,40,60, "Ore" }, { "opalBlock", 225,230,235, "Ore" },
    { "pearlBlock", 235,230,225, "Ore" }, { "boneBlock", 235,230,215, "Ore" },
    { "honeycombBlock", 235,185,70, "Ore" },
}

-- The groups offered in the palette dropdown, in display order.
local IMAGE_GROUPS = { "Solid", "Wool", "Clay", "Neon", "Pastel", "Wood", "Stone", "Natural", "Ore" }

-- Precompute each palette colour in OKLab once, for perceptual nearest-match.
local IMAGE_PAL = {}
do
    local toOk = BA.toOklab
    for _, e in ipairs(IMAGE_PALETTE) do
        local col = Color3.fromRGB(e[2], e[3], e[4])
        local L, a, b = toOk(col)
        IMAGE_PAL[#IMAGE_PAL + 1] = { name = e[1], col = col, L = L, a = a, b = b, group = e[5] }
    end
end

-- The palette actually in play: every group when none are picked, otherwise
-- only the chosen ones. Rebuilt when the dropdown changes.
local activePal = IMAGE_PAL
local function rebuildActivePalette()
    local want = IMG.groups
    if not want or next(want) == nil then
        activePal = IMAGE_PAL
    else
        local out = {}
        for _, e in ipairs(IMAGE_PAL) do
            if want[e.group] then out[#out + 1] = e end
        end
        activePal = (#out > 0) and out or IMAGE_PAL
    end
    IMG.match = {}      -- cached matches were made against the old palette
    IMG.chosen = nil
end

-- Nearest entry in a given palette, in OKLab.
local function nearestIn(pal, L, a, bb)
    local best, bestD
    for _, e in ipairs(pal) do
        local dL, da, db = L - e.L, a - e.a, bb - e.b
        local d = dL * dL + da * da + db * db
        if not bestD or d < bestD then bestD, best = d, e end
    end
    return best
end

-- "Simple" mode: cap how many distinct blocks the whole image may use. Pick the
-- ones that would cover the most pixels, then match everything to just those,
-- so you get a poster-like reduction instead of a hundred near-identical
-- shades. Needs the image, so it runs once per build from the sampled grid.
local function chooseLimitedPalette(grid, tw, th, limit)
    local tally = {}
    for py = 1, th do
        local row = grid[py]
        for px = 1, tw do
            local p = row[px]
            if p[4] >= 128 then
                local L, a, bb = BA.toOklab(Color3.fromRGB(p[1], p[2], p[3]))
                local e = nearestIn(activePal, L, a, bb)
                if e then tally[e] = (tally[e] or 0) + 1 end
            end
        end
        if py % 8 == 0 then task.wait() end
    end
    local ranked = {}
    for e, n in pairs(tally) do ranked[#ranked + 1] = { e = e, n = n } end
    table.sort(ranked, function(x, y) return x.n > y.n end)
    local out = {}
    for i = 1, math.min(limit, #ranked) do out[#out + 1] = ranked[i].e end
    return (#out > 0) and out or activePal
end

-- Memoised per distinct pixel colour: nearest palette block in OKLab, plus the
-- colour that block actually is, so the preview shows the quantised result.
local function blockFor(r, g, b)
    local k = r .. "," .. g .. "," .. b
    local hit = IMG.match[k]
    if hit then return hit[1], hit[2] end
    local L, a, bb = BA.toOklab(Color3.fromRGB(r, g, b))
    local best = nearestIn(IMG.chosen or activePal, L, a, bb)
    local rec = best and { best.name, best.col } or { O.activeBlock, Color3.fromRGB(r, g, b) }
    IMG.match[k] = rec
    return rec[1], rec[2]
end

-- Generated from mcconvert/blockmap.py. Do not hand-edit: run
-- mcconvert/export_blockmap.py to rebuild it when the table changes.
MC_MAP = {
    ["acacia_button"]="furnitureLampWall", ["acacia_door"]="doorPine2", ["acacia_fence"]="fenceMaple",
    ["acacia_fence_gate"]="fenceMaple", ["acacia_hanging_sign"]="mapleSlab", ["acacia_leaves"]="leavesMapleBlock",
    ["acacia_log"]="woodMaple", ["acacia_planks"]="maplePlank", ["acacia_pressure_plate"]="mapleSlab",
    ["acacia_sapling"]="saplingMaple", ["acacia_sign"]="signPostMaple", ["acacia_slab"]="mapleSlab",
    ["acacia_stairs"]="stairMaple", ["acacia_trapdoor"]="trapDoorMapleFlipped",
    ["acacia_wall_hanging_sign"]="mapleSlab", ["acacia_wall_sign"]="signPostMaple", ["acacia_wood"]="woodMaple",
    ["allium"]="tallGrass", ["amethyst_block"]="amethystBlock", ["ancient_debris"]="basaltCarved",
    ["andesite"]="andesite", ["andesite_slab"]="andesiteBrickSlab", ["andesite_stairs"]="andesiteBrickStair",
    ["andesite_wall"]="andesite", ["anvil"]="ironBlock", ["azalea"]="leavesBlock", ["azalea_leaves"]="leavesBlock",
    ["azure_bluet"]="tallGrass", ["bamboo"]="bambooBlock", ["bamboo_block"]="bambooBlock",
    ["bamboo_button"]="furnitureLampWall", ["bamboo_door"]="doorPine2", ["bamboo_fence"]="fenceMaple",
    ["bamboo_fence_gate"]="fenceMaple", ["bamboo_hanging_sign"]="bambooDriedBlock",
    ["bamboo_mosaic"]="bambooDriedBlock", ["bamboo_mosaic_slab"]="bambooDriedBlock",
    ["bamboo_mosaic_stairs"]="bambooDriedBlock", ["bamboo_planks"]="bambooBlock",
    ["bamboo_pressure_plate"]="trapDoorMapleFlipped", ["bamboo_sapling"]="saplingMaple",
    ["bamboo_shelf"]="bambooDriedBlock", ["bamboo_sign"]="signPostMaple", ["bamboo_slab"]="bambooDriedBlock",
    ["bamboo_stairs"]="bambooDriedBlock", ["bamboo_trapdoor"]="trapDoorMapleFlipped",
    ["bamboo_wall_sign"]="signPostMaple", ["barrel"]="pinePlank", ["barrel_open"]="pinePlank", ["basalt"]="basalt",
    ["beacon"]="glassBlockChrome", ["bed"]="woolRed", ["bee_nest"]="honeycombBlock", ["beehive"]="honeycombBlock",
    ["bell"]="goldBlock", ["big_dripleaf"]="leavesBlock", ["big_dripleaf_stem"]="tallGrass",
    ["birch_button"]="furnitureLampWall", ["birch_door"]="doorPine2", ["birch_fence"]="fenceBirch",
    ["birch_fence_gate"]="fenceBirch", ["birch_hanging_sign"]="birchSlab", ["birch_leaves"]="leavesBlock",
    ["birch_log"]="woodBirch", ["birch_planks"]="birchPlank", ["birch_pressure_plate"]="birchSlab",
    ["birch_sapling"]="saplingBirch", ["birch_shelf"]="birchSlab", ["birch_sign"]="signPostBirch",
    ["birch_slab"]="birchSlab", ["birch_stairs"]="stairBirch", ["birch_trapdoor"]="trapDoorBirchFlipped",
    ["birch_wall_hanging_sign"]="birchSlab", ["birch_wall_sign"]="signPostBirch", ["birch_wood"]="woodBirch",
    ["black_banner"]="woolBlack", ["black_bed"]="woolBlack", ["black_candle"]="clayBlack",
    ["black_carpet"]="carpetBlack", ["black_concrete"]="blackBlock", ["black_concrete_powder"]="clayBlack",
    ["black_glazed_terracotta"]="clayBlack", ["black_shulker_box"]="clayBlack",
    ["black_stained_glass"]="glassBlockBlack", ["black_stained_glass_pane"]="glassPaneBlack",
    ["black_terracotta"]="clayBlack", ["black_wall_banner"]="woolBlack", ["black_wool"]="woolBlack",
    ["blackstone"]="basalt", ["blackstone_slab"]="basaltSlab", ["blackstone_stairs"]="basaltStair",
    ["blackstone_wall"]="basalt", ["blast_furnace"]="ironBlock", ["blue_banner"]="woolBlue", ["blue_bed"]="woolBlue",
    ["blue_candle"]="clayBlue", ["blue_carpet"]="carpetBlue", ["blue_concrete"]="blueBlock",
    ["blue_concrete_powder"]="pastelBlueBlock", ["blue_glazed_terracotta"]="clayBlue", ["blue_ice"]="iceCompact",
    ["blue_orchid"]="tallGrass", ["blue_shulker_box"]="clayBlue", ["blue_stained_glass"]="glassBlockBlue",
    ["blue_stained_glass_pane"]="glassPaneBlue", ["blue_terracotta"]="clayBlue", ["blue_wall_banner"]="woolBlue",
    ["blue_wool"]="woolBlue", ["bone_block"]="boneBlock", ["bookshelf"]="hickoryPlank",
    ["brain_coral_block"]="coralBlockPink", ["brain_coral_fan"]="coralBlockPink", ["brewing_stand"]="ironBlock",
    ["brick_slab"]="brickSlab", ["brick_stairs"]="stairBrick", ["brick_wall"]="brick", ["bricks"]="brick",
    ["brown_banner"]="clayOrange", ["brown_bed"]="clayOrange", ["brown_candle"]="clayOrange",
    ["brown_carpet"]="carpetOrange", ["brown_concrete"]="clayOrange", ["brown_concrete_powder"]="pastelOrangeBlock",
    ["brown_glazed_terracotta"]="clayOrange", ["brown_mushroom"]="tallGrass",
    ["brown_mushroom_block"]="mushroomBlock", ["brown_shulker_box"]="clayOrange",
    ["brown_stained_glass"]="glassBlockOrange", ["brown_stained_glass_pane"]="glassPaneOrange",
    ["brown_terracotta"]="clayOrange", ["brown_wall_banner"]="clayOrange", ["brown_wool"]="clayOrange",
    ["bubble_coral_block"]="coralBlockBlue", ["bubble_coral_fan"]="coralBlockBlue",
    ["budding_amethyst"]="amethystBlock", ["cake"]="woolWhite", ["calcite"]="pearlBlock",
    ["calibrated_sculk_sensor"]="voidStoneCarved", ["campfire"]="magmaBlock", ["candle"]="clayWhite",
    ["cartography_table"]="woodPlank", ["carved_pumpkin"]="jackOLantern", ["cauldron"]="ironBlock",
    ["chain"]="ironBlock", ["cherry_button"]="furnitureLampWall", ["cherry_door"]="doorPine2",
    ["cherry_fence"]="fenceCherryBlossom", ["cherry_fence_gate"]="fenceCherryBlossom",
    ["cherry_hanging_sign"]="cherryBlossomSlab", ["cherry_leaves"]="leavesBlock", ["cherry_log"]="woodCherryBlossom",
    ["cherry_planks"]="cherryBlossomPlank", ["cherry_pressure_plate"]="cherryBlossomSlab",
    ["cherry_sapling"]="saplingCherryBlossom", ["cherry_sign"]="signPostCherryBlossom",
    ["cherry_slab"]="cherryBlossomSlab", ["cherry_stairs"]="stairCherryBlossom",
    ["cherry_trapdoor"]="trapDoorMapleFlipped", ["cherry_wall_sign"]="signPostCherryBlossom",
    ["cherry_wood"]="woodCherryBlossom", ["chest"]="woodPlank", ["chipped_anvil"]="ironBlock",
    ["chiseled_bookshelf"]="hickoryPlank", ["chiseled_copper"]="copperBlock", ["chiseled_deepslate"]="slateCarved",
    ["chiseled_nether_bricks"]="basaltCarved", ["chiseled_polished_blackstone"]="basaltCarved",
    ["chiseled_quartz_block"]="marbleCarved", ["chiseled_red_sandstone"]="sandstoneRedBrick",
    ["chiseled_red_sandstone_slab"]="sandstoneRedBrickSlab", ["chiseled_resin_bricks"]="sandstoneSmoothRedBrick",
    ["chiseled_sandstone"]="sandstoneBrick", ["chiseled_stone_bricks"]="stoneCarved",
    ["chiseled_tuff"]="andesiteCarved", ["chiseled_tuff_bricks"]="andesiteCarved", ["clay"]="clay",
    ["coal_block"]="coalBlock", ["coal_ore"]="coalBlock", ["coarse_dirt"]="mudBlock",
    ["cobbled_deepslate"]="slateBlock", ["cobbled_deepslate_slab"]="slateSlab",
    ["cobbled_deepslate_stairs"]="stairSlate", ["cobbled_deepslate_wall"]="slateBlock",
    ["cobblestone"]="cobblestoneBlock", ["cobblestone_slab"]="cobblestoneSlab",
    ["cobblestone_stairs"]="cobblestoneStair", ["cobblestone_wall"]="cobblestoneBlock", ["cobweb"]="woolWhite",
    ["cocoa"]="clayOrange", ["command_block"]="stoneSmooth", ["comparator"]="stoneSmooth", ["composter"]="woodPlank",
    ["conduit"]="prismarineBrick", ["copper_block"]="copperBlock", ["copper_bulb"]="ledLight",
    ["copper_chain"]="copperBlock", ["copper_door"]="doorIron", ["copper_grate"]="copperBlock",
    ["copper_trapdoor"]="trapDoorIronFlipped", ["cornflower"]="tallGrass", ["cracked_deepslate_bricks"]="slateBrick",
    ["cracked_deepslate_tiles"]="slateTiles", ["cracked_nether_bricks"]="basaltTiles",
    ["cracked_polished_blackstone_bricks"]="basaltBrick", ["cracked_stone_bricks"]="stoneBrick",
    ["crafter"]="hickoryPlank", ["crafting_table"]="workbench4", ["creaking_heart"]="woodBirch",
    ["creeper_head"]="clayLightGreen", ["crimson_button"]="furnitureLampWall", ["crimson_door"]="doorPine2",
    ["crimson_fence"]="fenceCherryBlossom", ["crimson_fence_gate"]="fenceCherryBlossom",
    ["crimson_fungus"]="saplingCherryBlossom", ["crimson_hanging_sign"]="cherryBlossomSlab",
    ["crimson_hyphae"]="woodCherryBlossom", ["crimson_nylium"]="glowingMushroomPinkBlock",
    ["crimson_planks"]="cherryBlossomPlank", ["crimson_pressure_plate"]="cherryBlossomSlab",
    ["crimson_sign"]="signPostCherryBlossom", ["crimson_slab"]="cherryBlossomSlab",
    ["crimson_stairs"]="stairCherryBlossom", ["crimson_stem"]="woodCherryBlossom",
    ["crimson_trapdoor"]="trapDoorMapleFlipped", ["crimson_wall_sign"]="signPostCherryBlossom",
    ["crying_obsidian"]="voidStonePolished", ["cut_copper"]="copperBlock", ["cut_copper_slab"]="copperBlock",
    ["cut_copper_stairs"]="copperBlock", ["cut_red_sandstone"]="sandstoneRedBrick",
    ["cut_sandstone"]="sandstoneBrick", ["cut_sandstone_slab"]="sandstoneBrickSlab", ["cyan_banner"]="woolCyan",
    ["cyan_bed"]="woolCyan", ["cyan_candle"]="clayCyan", ["cyan_carpet"]="carpetCyan", ["cyan_concrete"]="cyanBlock",
    ["cyan_concrete_powder"]="pastelBlueBlock", ["cyan_glazed_terracotta"]="clayCyan",
    ["cyan_shulker_box"]="clayCyan", ["cyan_stained_glass"]="glassBlockCyan",
    ["cyan_stained_glass_pane"]="glassPaneCyan", ["cyan_terracotta"]="clayCyan", ["cyan_wall_banner"]="woolCyan",
    ["cyan_wool"]="woolCyan", ["damaged_anvil"]="ironBlock", ["dandelion"]="tallGrass",
    ["dark_oak_button"]="furnitureLampWall", ["dark_oak_door"]="doorPine2", ["dark_oak_fence"]="fenceHickory",
    ["dark_oak_fence_gate"]="fenceHickory", ["dark_oak_hanging_sign"]="hickorySlab",
    ["dark_oak_leaves"]="leavesBlock", ["dark_oak_log"]="woodHickory", ["dark_oak_planks"]="hickoryPlank",
    ["dark_oak_pressure_plate"]="hickorySlab", ["dark_oak_sapling"]="saplingHickory",
    ["dark_oak_shelf"]="hickorySlab", ["dark_oak_sign"]="signPostHickory", ["dark_oak_slab"]="hickorySlab",
    ["dark_oak_stairs"]="stairHickory", ["dark_oak_trapdoor"]="trapDoorHickoryFlipped",
    ["dark_oak_wall_hanging_sign"]="hickorySlab", ["dark_oak_wall_sign"]="signPostHickory",
    ["dark_oak_wood"]="woodHickory", ["dark_prismarine"]="prismarineBrick",
    ["dark_prismarine_slab"]="prismarineBrickSlab", ["dark_prismarine_stairs"]="prismarineBrickStair",
    ["daylight_detector"]="hickorySlab", ["dead_brain_coral"]="clayWhite", ["dead_brain_coral_block"]="clayWhite",
    ["dead_brain_coral_fan"]="clayWhite", ["dead_brain_coral_wall_fan"]="clayWhite",
    ["dead_bubble_coral"]="clayWhite", ["dead_bubble_coral_block"]="clayWhite", ["dead_bubble_coral_fan"]="clayWhite",
    ["dead_bubble_coral_wall_fan"]="clayWhite", ["dead_bush"]="saplingHickory", ["dead_fire_coral"]="clayWhite",
    ["dead_fire_coral_block"]="clayWhite", ["dead_fire_coral_fan"]="clayWhite",
    ["dead_fire_coral_wall_fan"]="clayWhite", ["dead_horn_coral"]="clayWhite", ["dead_horn_coral_block"]="clayWhite",
    ["dead_horn_coral_fan"]="clayWhite", ["dead_horn_coral_wall_fan"]="clayWhite", ["dead_tube_coral"]="clayWhite",
    ["dead_tube_coral_block"]="clayWhite", ["dead_tube_coral_fan"]="clayWhite",
    ["dead_tube_coral_wall_fan"]="clayWhite", ["decorated_pot"]="clayOrange", ["deepslate"]="slateBlock",
    ["deepslate_brick_slab"]="slateBrickSlab", ["deepslate_brick_stairs"]="stairSlateBrick",
    ["deepslate_brick_wall"]="slateBrick", ["deepslate_bricks"]="slateBrick", ["deepslate_coal_ore"]="coalBlock",
    ["deepslate_copper_ore"]="copperBlock", ["deepslate_diamond_ore"]="diamondBlock",
    ["deepslate_emerald_ore"]="slimeBlockGreen", ["deepslate_gold_ore"]="goldBlock",
    ["deepslate_iron_ore"]="ironBlock", ["deepslate_lapis_ore"]="buffalkorCrystalBlock",
    ["deepslate_redstone_ore"]="rubyBlock", ["deepslate_tile_slab"]="slateSlab",
    ["deepslate_tile_stairs"]="stairSlate", ["deepslate_tile_wall"]="slateTiles", ["deepslate_tiles"]="slateTiles",
    ["diamond_block"]="diamondBlock", ["diamond_ore"]="diamondBlock", ["diorite"]="diorite",
    ["diorite_slab"]="dioriteSlab", ["diorite_stairs"]="dioriteStair", ["diorite_wall"]="diorite",
    ["dirt"]="mudBlock", ["dirt_path"]="grassDry", ["dispenser"]="cobblestoneBlock", ["dragon_egg"]="voidStoneBlock",
    ["dragon_head"]="clayBlack", ["dried_ghast"]="boneBlock", ["dried_kelp_block"]="clayDarkGreen",
    ["dripstone_block"]="sandstoneSmooth", ["dropper"]="cobblestoneBlock", ["emerald_block"]="slimeBlockGreen",
    ["emerald_ore"]="amethystBlock", ["enchanting_table"]="voidStoneBlock", ["end_portal_frame"]="voidStoneCarved",
    ["end_rod"]="ledLight", ["end_stone"]="sandstoneSmooth", ["end_stone_brick_slab"]="sandstoneSmoothBrickSlab",
    ["end_stone_brick_stairs"]="stairSandstoneSmoothBrick", ["end_stone_brick_wall"]="sandstoneSmoothBrick",
    ["end_stone_bricks"]="sandstoneSmoothBrick", ["ender_chest"]="voidStoneBlock",
    ["exposed_chiseled_copper"]="copperBlock", ["exposed_copper"]="copperBlock",
    ["exposed_copper_chain"]="copperBlock", ["exposed_copper_trapdoor"]="trapDoorIronFlipped",
    ["exposed_cut_copper"]="copperBlock", ["exposed_cut_copper_slab"]="copperBlock",
    ["exposed_cut_copper_stairs"]="copperBlock", ["farmland"]="soil", ["fern"]="tallGrass",
    ["fire_coral_block"]="coralBlockPink", ["fire_coral_fan"]="coralBlockPink", ["fletching_table"]="woodPlank",
    ["flower_pot"]="clayOrange", ["flowering_azalea"]="leavesBlock", ["flowering_azalea_leaves"]="leavesBlock",
    ["furnace"]="stoneTiles", ["gilded_blackstone"]="basaltBrick", ["glass"]="glassBlock", ["glass_pane"]="glassPane",
    ["glow_lichen"]="mossyBlock", ["glowstone"]="ledLight", ["gold_block"]="goldBlock", ["gold_ore"]="goldBlock",
    ["granite"]="granite", ["granite_slab"]="graniteSlab", ["granite_stairs"]="graniteStair",
    ["granite_wall"]="granite", ["grass"]="tallGrass", ["grass_block"]="grass", ["grass_path"]="grassDry",
    ["gravel"]="cobblestoneBlock", ["gray_banner"]="clayBlack", ["gray_bed"]="clayBlack", ["gray_candle"]="clayBlack",
    ["gray_carpet"]="carpetBlack", ["gray_concrete"]="slateSmooth", ["gray_concrete_powder"]="clayBlack",
    ["gray_glazed_terracotta"]="clayBlack", ["gray_shulker_box"]="clayBlack",
    ["gray_stained_glass"]="glassBlockBlack", ["gray_stained_glass_pane"]="glassPaneBlack",
    ["gray_terracotta"]="clayBlack", ["gray_wall_banner"]="clayBlack", ["gray_wool"]="clayBlack",
    ["green_banner"]="woolDarkGreen", ["green_bed"]="woolDarkGreen", ["green_candle"]="clayDarkGreen",
    ["green_carpet"]="carpetDarkGreen", ["green_concrete"]="darkGreenBlock",
    ["green_concrete_powder"]="pastelGreenBlock", ["green_glazed_terracotta"]="clayDarkGreen",
    ["green_shulker_box"]="clayDarkGreen", ["green_stained_glass"]="glassBlockDarkGreen",
    ["green_stained_glass_pane"]="glassPaneDarkGreen", ["green_terracotta"]="clayDarkGreen",
    ["green_wall_banner"]="woolDarkGreen", ["green_wool"]="woolDarkGreen", ["grindstone"]="woodPlank",
    ["hay_block"]="haybaleBlock", ["heavy_core"]="basaltCarved", ["heavy_weighted_pressure_plate"]="ironBlock",
    ["honey_block"]="honeyBlock", ["honeycomb_block"]="honeycombBlock", ["hopper"]="ironBlock",
    ["horn_coral_block"]="coralBlockYellow", ["horn_coral_fan"]="coralBlockYellow", ["ice"]="ice",
    ["infested_cobblestone"]="cobblestoneBlock", ["infested_deepslate"]="slateBlock",
    ["infested_mossy_stone_bricks"]="stoneBrickMossy", ["infested_stone_bricks"]="stoneBrick",
    ["iron_bars"]="ironBlock", ["iron_block"]="ironBlock", ["iron_chain"]="ironBlock", ["iron_door"]="doorIron",
    ["iron_ore"]="ironBlock", ["iron_trapdoor"]="trapDoorIronFlipped", ["item_frame"]="woodPlank",
    ["jack_o_lantern"]="jackOLantern", ["jukebox"]="hickoryPlank", ["jungle_button"]="furnitureLampWall",
    ["jungle_door"]="doorPine2", ["jungle_fence"]="fenceMaple", ["jungle_fence_gate"]="fenceMaple",
    ["jungle_hanging_sign"]="mapleSlab", ["jungle_leaves"]="leavesMapleBlock", ["jungle_log"]="woodMaple",
    ["jungle_planks"]="maplePlank", ["jungle_pressure_plate"]="mapleSlab", ["jungle_sapling"]="saplingMaple",
    ["jungle_sign"]="signPostMaple", ["jungle_slab"]="mapleSlab", ["jungle_stairs"]="stairMaple",
    ["jungle_trapdoor"]="trapDoorMapleFlipped", ["jungle_wall_hanging_sign"]="mapleSlab",
    ["jungle_wall_sign"]="signPostMaple", ["jungle_wood"]="woodMaple", ["kelp"]="tallGrass",
    ["kelp_plant"]="tallGrass", ["ladder"]="oakSlab", ["lantern"]="furnitureLampWall",
    ["lapis_block"]="buffalkorCrystalBlock", ["lapis_ore"]="blueBlock", ["large_fern"]="tallGrass",
    ["lava_cauldron"]="ironBlock", ["lectern"]="woodPlank", ["lever"]="oakSlab", ["light_blue_banner"]="woolCyan",
    ["light_blue_bed"]="woolCyan", ["light_blue_candle"]="clayCyan", ["light_blue_carpet"]="carpetCyan",
    ["light_blue_concrete"]="cyanBlock", ["light_blue_concrete_powder"]="pastelBlueBlock",
    ["light_blue_glazed_terracotta"]="clayCyan", ["light_blue_shulker_box"]="clayCyan",
    ["light_blue_stained_glass"]="glassBlockCyan", ["light_blue_stained_glass_pane"]="glassPaneCyan",
    ["light_blue_terracotta"]="clayCyan", ["light_blue_wall_banner"]="woolCyan", ["light_blue_wool"]="woolCyan",
    ["light_gray_banner"]="clayWhite", ["light_gray_bed"]="clayWhite", ["light_gray_candle"]="clayWhite",
    ["light_gray_carpet"]="carpet", ["light_gray_concrete"]="marbleSmooth",
    ["light_gray_concrete_powder"]="clayWhite", ["light_gray_glazed_terracotta"]="clayWhite",
    ["light_gray_shulker_box"]="clayWhite", ["light_gray_stained_glass"]="glassBlockChrome",
    ["light_gray_stained_glass_pane"]="glassPane", ["light_gray_terracotta"]="clayWhite",
    ["light_gray_wall_banner"]="clayWhite", ["light_gray_wool"]="clayWhite", ["lightning_rod"]="copperBlock",
    ["lilac"]="tallGrass", ["lily_of_the_valley"]="tallGrass", ["lily_pad"]="carpetDarkGreen",
    ["lime_banner"]="woolLightGreen", ["lime_bed"]="woolLightGreen", ["lime_candle"]="clayLightGreen",
    ["lime_carpet"]="carpetLightGreen", ["lime_concrete"]="lightGreenBlock",
    ["lime_concrete_powder"]="pastelGreenBlock", ["lime_glazed_terracotta"]="clayLightGreen",
    ["lime_shulker_box"]="clayLightGreen", ["lime_stained_glass"]="glassBlockLightGreen",
    ["lime_stained_glass_pane"]="glassPaneLightGreen", ["lime_terracotta"]="clayLightGreen",
    ["lime_wall_banner"]="woolLightGreen", ["lime_wool"]="woolLightGreen", ["lodestone"]="stoneSmooth",
    ["loom"]="woodPlank", ["magenta_banner"]="woolPink", ["magenta_bed"]="woolPink", ["magenta_candle"]="clayPink",
    ["magenta_carpet"]="carpetPink", ["magenta_concrete"]="pinkBlock",
    ["magenta_concrete_powder"]="pastelPurpleBlock", ["magenta_glazed_terracotta"]="clayPink",
    ["magenta_shulker_box"]="clayPink", ["magenta_stained_glass"]="glassBlockPink",
    ["magenta_stained_glass_pane"]="glassPanePink", ["magenta_terracotta"]="clayPink",
    ["magenta_wall_banner"]="woolPink", ["magenta_wool"]="woolPink", ["magma_block"]="magmaBlock",
    ["mangrove_button"]="furnitureLampWall", ["mangrove_door"]="doorPine2", ["mangrove_fence"]="fenceCherryBlossom",
    ["mangrove_fence_gate"]="fenceCherryBlossom", ["mangrove_hanging_sign"]="cherryBlossomSlab",
    ["mangrove_leaves"]="leavesBlock", ["mangrove_log"]="woodCherryBlossom", ["mangrove_planks"]="cherryBlossomPlank",
    ["mangrove_pressure_plate"]="cherryBlossomSlab", ["mangrove_roots"]="woodCherryBlossom",
    ["mangrove_sapling"]="saplingCherryBlossom", ["mangrove_sign"]="signPostCherryBlossom",
    ["mangrove_slab"]="cherryBlossomSlab", ["mangrove_stairs"]="stairCherryBlossom",
    ["mangrove_trapdoor"]="trapDoorMapleFlipped", ["mangrove_wall_sign"]="signPostCherryBlossom",
    ["mangrove_wood"]="woodCherryBlossom", ["melon"]="melonHarvested", ["moss_block"]="mossyBlock",
    ["moss_carpet"]="carpetDarkGreen", ["mossy_cobblestone"]="mossyCobblestoneBlock",
    ["mossy_cobblestone_slab"]="mossyCobblestoneSlab", ["mossy_cobblestone_stairs"]="cobblestoneStair",
    ["mossy_cobblestone_wall"]="mossyCobblestoneBlock", ["mossy_stone_brick_slab"]="stoneBrickSlab",
    ["mossy_stone_brick_stairs"]="stairStoneBrick", ["mossy_stone_brick_wall"]="stoneBrickMossy",
    ["mossy_stone_bricks"]="stoneBrickMossy", ["moving_piston"]="ironBlock", ["mud"]="mudBlock",
    ["mud_brick_slab"]="mudBlock", ["mud_brick_stairs"]="mudBlock", ["mud_brick_wall"]="mudBlock",
    ["mud_bricks"]="mudBlock", ["mud_bricks_wall"]="mudBlock", ["muddy_mangrove_roots"]="mudBlock",
    ["mushroom_stem"]="mushroomBlock", ["nether_brick_fence"]="fenceHickory", ["nether_brick_slab"]="basaltSlab",
    ["nether_brick_stairs"]="basaltStair", ["nether_brick_wall"]="basaltTiles", ["nether_bricks"]="basaltTiles",
    ["nether_gold_ore"]="goldBlock", ["nether_portal"]="voidBlock", ["nether_quartz_ore"]="marbleBlock",
    ["nether_wart_block"]="glowingMushroomPinkBlock", ["netherite_block"]="basaltCarved", ["netherrack"]="magmaBlock",
    ["note_block"]="woodPlank", ["oak_button"]="furnitureLampWall", ["oak_door"]="doorPine",
    ["oak_fence"]="woodFence", ["oak_fence_gate"]="woodFence", ["oak_hanging_sign"]="oakSlab",
    ["oak_leaves"]="leavesBlock", ["oak_log"]="wood", ["oak_planks"]="woodPlank", ["oak_pressure_plate"]="oakSlab",
    ["oak_sapling"]="sapling", ["oak_shelf"]="oakSlab", ["oak_sign"]="signPostOak", ["oak_slab"]="oakSlab",
    ["oak_stairs"]="stairOak", ["oak_trapdoor"]="trapDoorOakFlipped", ["oak_wall_hanging_sign"]="oakSlab",
    ["oak_wall_sign"]="signPostOak", ["oak_wood"]="wood", ["observer"]="slateSmooth", ["obsidian"]="voidStoneBlock",
    ["ochre_froglight"]="glowingMushroomGreenBlock", ["orange_banner"]="woolOrange", ["orange_bed"]="woolOrange",
    ["orange_candle"]="clayOrange", ["orange_carpet"]="carpetOrange", ["orange_concrete"]="orangeBlock",
    ["orange_concrete_powder"]="pastelOrangeBlock", ["orange_glazed_terracotta"]="clayOrange",
    ["orange_shulker_box"]="clayOrange", ["orange_stained_glass"]="glassBlockOrange",
    ["orange_stained_glass_pane"]="glassPaneOrange", ["orange_terracotta"]="clayOrange",
    ["orange_wall_banner"]="woolOrange", ["orange_wool"]="woolOrange", ["oxeye_daisy"]="tallGrass",
    ["oxidized_chiseled_copper"]="prismarineBlock", ["oxidized_copper"]="prismarineBlock",
    ["oxidized_copper_chain"]="prismarineBlock", ["oxidized_copper_trapdoor"]="trapDoorIronFlipped",
    ["oxidized_cut_copper"]="prismarineBlock", ["oxidized_cut_copper_slab"]="prismarineSlab",
    ["oxidized_cut_copper_stairs"]="prismarineStair", ["packed_ice"]="iceCompact", ["packed_mud"]="mudBlock",
    ["painting"]="woodPlank", ["pale_hanging_moss"]="mossyBlock", ["pale_moss_block"]="mossyBlock",
    ["pale_moss_carpet"]="carpetLightGreen", ["pale_oak_button"]="furnitureLampWall", ["pale_oak_door"]="doorPine2",
    ["pale_oak_fence"]="fenceBirch", ["pale_oak_fence_gate"]="fenceBirch", ["pale_oak_hanging_sign"]="birchSlab",
    ["pale_oak_leaves"]="leavesBlock", ["pale_oak_log"]="woodBirch", ["pale_oak_planks"]="birchPlank",
    ["pale_oak_pressure_plate"]="birchSlab", ["pale_oak_sapling"]="saplingBirch", ["pale_oak_shelf"]="birchSlab",
    ["pale_oak_sign"]="signPostBirch", ["pale_oak_slab"]="birchSlab", ["pale_oak_stairs"]="stairBirch",
    ["pale_oak_trapdoor"]="trapDoorBirchFlipped", ["pale_oak_wall_sign"]="signPostBirch",
    ["pale_oak_wood"]="woodBirch", ["pearlescent_froglight"]="ledLight", ["peony"]="tallGrass",
    ["petrified_oak_slab"]="oakSlab", ["pink_banner"]="woolPink", ["pink_bed"]="woolPink", ["pink_candle"]="clayPink",
    ["pink_carpet"]="carpetPink", ["pink_concrete"]="pinkBlock", ["pink_concrete_powder"]="pastelPinkBlock",
    ["pink_glazed_terracotta"]="clayPink", ["pink_shulker_box"]="clayPink", ["pink_stained_glass"]="glassBlockPink",
    ["pink_stained_glass_pane"]="glassPanePink", ["pink_terracotta"]="clayPink", ["pink_wall_banner"]="woolPink",
    ["pink_wool"]="woolPink", ["piston"]="ironBlock", ["piston_head"]="hickoryPlank", ["player_head"]="boneBlock",
    ["player_wall_head"]="boneBlock", ["podzol"]="mudBlock", ["polished_andesite"]="andesiteSmooth",
    ["polished_andesite_slab"]="andesiteSlab", ["polished_andesite_stairs"]="andesiteStair",
    ["polished_basalt"]="basaltSmooth", ["polished_blackstone"]="basaltSmooth",
    ["polished_blackstone_brick_slab"]="basaltBrickSlab", ["polished_blackstone_brick_stairs"]="basaltBrickStair",
    ["polished_blackstone_brick_wall"]="basaltBrick", ["polished_blackstone_bricks"]="basaltBrick",
    ["polished_blackstone_button"]="furnitureLampWall", ["polished_blackstone_pressure_plate"]="basaltSlab",
    ["polished_blackstone_slab"]="basaltBrickSlab", ["polished_blackstone_stairs"]="basaltBrickStair",
    ["polished_blackstone_wall"]="basaltBrick", ["polished_deepslate"]="slateSmooth",
    ["polished_deepslate_slab"]="slateSlab", ["polished_deepslate_stairs"]="stairSlate",
    ["polished_deepslate_wall"]="slateSmooth", ["polished_diorite"]="dioriteSmooth",
    ["polished_diorite_slab"]="dioriteSlab", ["polished_diorite_stairs"]="dioriteStair",
    ["polished_granite"]="graniteSmooth", ["polished_granite_slab"]="graniteSlab",
    ["polished_granite_stairs"]="graniteStair", ["polished_tuff"]="andesiteSmooth",
    ["polished_tuff_slab"]="andesiteSlab", ["polished_tuff_stairs"]="andesiteStair",
    ["polished_tuff_wall"]="andesiteSmooth", ["poppy"]="tallGrass", ["powder_snow_cauldron"]="ironBlock",
    ["prismarine"]="prismarineBlock", ["prismarine_brick_slab"]="prismarineBrickSlab",
    ["prismarine_brick_stairs"]="prismarineBrickStair", ["prismarine_bricks"]="prismarineBrick",
    ["prismarine_slab"]="prismarineSlab", ["prismarine_stairs"]="prismarineStair",
    ["prismarine_wall"]="prismarineBlock", ["pumpkin"]="pumpkinHarvested", ["purple_banner"]="woolPurple",
    ["purple_bed"]="woolPurple", ["purple_candle"]="clayPurple", ["purple_carpet"]="carpetPurple",
    ["purple_concrete"]="purpleBlock", ["purple_concrete_powder"]="pastelPurpleBlock",
    ["purple_glazed_terracotta"]="clayPurple", ["purple_shulker_box"]="clayPurple",
    ["purple_stained_glass"]="glassBlockPurple", ["purple_stained_glass_pane"]="glassPanePurple",
    ["purple_terracotta"]="clayPurple", ["purple_wall_banner"]="woolPurple", ["purple_wool"]="woolPurple",
    ["purpur_block"]="clayPurple", ["purpur_pillar"]="clayPurple", ["purpur_slab"]="pastelPurpleSlab",
    ["purpur_stairs"]="pastelPurpleStair", ["quartz_block"]="marbleBlock", ["quartz_bricks"]="marbleBrick",
    ["quartz_pillar"]="marblePillar", ["quartz_slab"]="marbleSlab", ["quartz_stairs"]="stairMarble",
    ["raw_copper_block"]="copperBlock", ["raw_gold_block"]="goldBlock", ["raw_iron_block"]="ironBlock",
    ["red_banner"]="woolRed", ["red_bed"]="woolRed", ["red_candle"]="clayRed", ["red_carpet"]="carpetRed",
    ["red_concrete"]="redBlock", ["red_concrete_powder"]="pastelRedBlock", ["red_glazed_terracotta"]="clayRed",
    ["red_mushroom"]="tallGrass", ["red_mushroom_block"]="mushroomBlock",
    ["red_nether_brick_slab"]="sandstoneRedBrickSlab", ["red_nether_brick_stairs"]="sandstoneRedBrick",
    ["red_nether_brick_wall"]="sandstoneRedBrick", ["red_nether_bricks"]="sandstoneRedBrick",
    ["red_sand"]="sandstoneRed", ["red_sandstone"]="sandstoneRed", ["red_sandstone_slab"]="sandstoneRedSlab",
    ["red_sandstone_stairs"]="stairSandstoneRed", ["red_sandstone_wall"]="sandstoneRed",
    ["red_shulker_box"]="clayRed", ["red_stained_glass"]="glassBlockRed", ["red_stained_glass_pane"]="glassPaneRed",
    ["red_terracotta"]="clayRed", ["red_wall_banner"]="woolRed", ["red_wool"]="woolRed",
    ["redstone_block"]="rubyBlock", ["redstone_lamp"]="ledLight", ["redstone_ore"]="redBlock",
    ["redstone_torch"]="ledLight", ["redstone_wall_torch"]="ledLight", ["reinforced_deepslate"]="slateCarved",
    ["repeater"]="stoneSmooth", ["repeating_command_block"]="stoneSmooth", ["resin_block"]="clayOrange",
    ["resin_brick_slab"]="sandstoneSmoothRedBrickSlab", ["resin_brick_stairs"]="stairSandstoneSmoothRedBrick",
    ["resin_brick_wall"]="sandstoneSmoothRedBrick", ["resin_bricks"]="sandstoneSmoothRedBrick",
    ["respawn_anchor"]="voidStonePolished", ["rooted_dirt"]="mudBlock", ["rose_bush"]="tallGrass", ["sand"]="sand",
    ["sandstone"]="sandstone", ["sandstone_slab"]="sandstoneSlab", ["sandstone_stairs"]="stairSandstone",
    ["sandstone_wall"]="sandstone", ["sandstone_wall_red"]="sandstoneRed", ["scaffolding"]="bambooBlock",
    ["sculk"]="voidBlock", ["sculk_catalyst"]="voidStoneCarved", ["sculk_sensor"]="voidStoneCarved",
    ["sculk_shrieker"]="voidStoneCarved", ["sea_lantern"]="opalBlock", ["sea_pickle"]="glowingMushroomGreenBlock",
    ["seagrass"]="tallGrass", ["short_grass"]="tallGrass", ["shroomlight"]="ledLight", ["shulker_box"]="clayPurple",
    ["skeleton_skull"]="boneBlock", ["skeleton_wall_skull"]="boneBlock", ["slime_block"]="slimeBlockGreen",
    ["smithing_table"]="hickoryPlank", ["smoker"]="pinePlank", ["smooth_basalt"]="basaltSmooth",
    ["smooth_quartz"]="marbleTiles", ["smooth_quartz_slab"]="marbleSlab", ["smooth_quartz_stairs"]="stairMarble",
    ["smooth_red_sandstone"]="sandstoneSmoothRed", ["smooth_red_sandstone_slab"]="sandstoneSmoothRedSlab",
    ["smooth_red_sandstone_stairs"]="stairSandstoneSmoothRed", ["smooth_sandstone"]="sandstoneSmooth",
    ["smooth_sandstone_slab"]="sandstoneSmoothSlab", ["smooth_sandstone_stairs"]="stairSandstoneSmooth",
    ["smooth_stone"]="stoneSmooth", ["smooth_stone_slab"]="stoneBrickSlab", ["snow_block"]="snowCompact",
    ["soul_lantern"]="furnitureLampWall", ["soul_sand"]="mudBlock", ["soul_soil"]="mudBlock", ["soul_torch"]="torch",
    ["soul_wall_torch"]="torch", ["spawner"]="voidStoneCobble", ["sponge"]="clayYellow",
    ["spruce_button"]="furnitureLampWall", ["spruce_door"]="doorPine", ["spruce_fence"]="fencePine",
    ["spruce_fence_gate"]="fencePine", ["spruce_hanging_sign"]="pineSlab", ["spruce_leaves"]="leavesBlock",
    ["spruce_log"]="woodPine", ["spruce_planks"]="pinePlank", ["spruce_pressure_plate"]="pineSlab",
    ["spruce_sapling"]="saplingPine", ["spruce_shelf"]="pineSlab", ["spruce_sign"]="signPostPine",
    ["spruce_slab"]="pineSlab", ["spruce_stairs"]="stairPine", ["spruce_trapdoor"]="trapDoorPineFlipped",
    ["spruce_wall_hanging_sign"]="pineSlab", ["spruce_wall_sign"]="signPostPine", ["spruce_wood"]="woodPine",
    ["sticky_piston"]="slimeBlockGreen", ["stone"]="stone", ["stone_brick_slab"]="stoneBrickSlab",
    ["stone_brick_stairs"]="stairStoneBrick", ["stone_brick_wall"]="stoneBrick", ["stone_bricks"]="stoneBrick",
    ["stone_button"]="furnitureLampWall", ["stone_pressure_plate"]="stoneSmooth", ["stone_slab"]="stoneBrickSlab",
    ["stone_stairs"]="stairStoneBrick", ["stonecutter"]="stoneSmooth", ["stripped_acacia_log"]="woodMaple",
    ["stripped_acacia_wood"]="woodMaple", ["stripped_bamboo_block"]="bambooDriedBlock",
    ["stripped_birch_log"]="woodBirch", ["stripped_birch_wood"]="woodBirch",
    ["stripped_cherry_log"]="woodCherryBlossom", ["stripped_cherry_wood"]="woodCherryBlossom",
    ["stripped_crimson_hyphae"]="woodCherryBlossom", ["stripped_crimson_stem"]="woodCherryBlossom",
    ["stripped_dark_oak_log"]="woodHickory", ["stripped_dark_oak_wood"]="woodHickory",
    ["stripped_jungle_log"]="woodMaple", ["stripped_jungle_wood"]="woodMaple",
    ["stripped_mangrove_log"]="woodCherryBlossom", ["stripped_mangrove_wood"]="woodCherryBlossom",
    ["stripped_oak_log"]="wood", ["stripped_oak_wood"]="wood", ["stripped_pale_oak_log"]="woodBirch",
    ["stripped_pale_oak_wood"]="woodBirch", ["stripped_spruce_log"]="woodPine", ["stripped_spruce_wood"]="woodPine",
    ["stripped_warped_hyphae"]="woodSpirit", ["stripped_warped_stem"]="woodSpirit", ["sulfur_block"]="clayYellow",
    ["sulfur_wall"]="clayYellow", ["sunflower"]="tallGrass", ["suspicious_gravel"]="cobblestoneBlock",
    ["suspicious_sand"]="sand", ["sweet_berry_bush"]="tallGrass", ["tall_grass"]="tallGrass",
    ["tall_seagrass"]="tallGrass", ["target"]="targetBlockWood", ["terracotta"]="clayOrange",
    ["tinted_glass"]="glassBlockBlack", ["tnt"]="redBlock", ["torch"]="torch", ["trapped_chest"]="woodPlank",
    ["trial_spawner"]="voidStoneCarved", ["tripwire_hook"]="oakSlab", ["tube_coral_block"]="coralBlockLightBlue",
    ["tube_coral_fan"]="coralBlockLightBlue", ["tuff"]="andesiteTiles", ["tuff_brick_slab"]="andesiteBrickSlab",
    ["tuff_brick_stairs"]="andesiteBrickStair", ["tuff_brick_wall"]="andesiteBrick", ["tuff_bricks"]="andesiteBrick",
    ["tuff_slab"]="andesiteBrickSlab", ["tuff_stairs"]="andesiteBrickStair", ["tuff_wall"]="andesiteTiles",
    ["turtle_egg"]="boneBlock", ["vault"]="voidStoneCarved", ["verdant_froglight"]="glowingMushroomBlueBlock",
    ["vine"]="leavesBlock", ["wall_torch"]="torch", ["warped_button"]="furnitureLampWall",
    ["warped_door"]="doorPine2", ["warped_fence"]="fenceSpirit", ["warped_fence_gate"]="fenceSpirit",
    ["warped_fungus"]="saplingSpirit", ["warped_hanging_sign"]="spiritSlab", ["warped_hyphae"]="woodSpirit",
    ["warped_nylium"]="glowingMushroomCyanBlock", ["warped_planks"]="spiritPlank",
    ["warped_pressure_plate"]="spiritSlab", ["warped_shelf"]="spiritSlab", ["warped_sign"]="signPostSpirit",
    ["warped_slab"]="spiritSlab", ["warped_stairs"]="stairSpirit", ["warped_stem"]="woodSpirit",
    ["warped_trapdoor"]="trapDoorSpiritFlipped", ["warped_wall_sign"]="signPostSpirit",
    ["warped_wart_block"]="glowingMushroomCyanBlock", ["water"]="slimeBlockBlue", ["water_cauldron"]="ironBlock",
    ["waxed_chiseled_copper"]="copperBlock", ["waxed_copper_block"]="copperBlock",
    ["waxed_copper_chain"]="copperBlock", ["waxed_copper_trapdoor"]="trapDoorIronFlipped",
    ["waxed_cut_copper"]="copperBlock", ["waxed_cut_copper_slab"]="copperBlock",
    ["waxed_cut_copper_stairs"]="copperBlock", ["waxed_exposed_copper"]="copperBlock",
    ["waxed_exposed_copper_chain"]="copperBlock", ["waxed_exposed_copper_trapdoor"]="trapDoorIronFlipped",
    ["waxed_exposed_cut_copper"]="copperBlock", ["waxed_exposed_cut_copper_slab"]="copperBlock",
    ["waxed_exposed_cut_copper_stairs"]="copperBlock", ["waxed_lightning_rod"]="copperBlock",
    ["waxed_oxidized_copper"]="prismarineBlock", ["waxed_oxidized_copper_chain"]="prismarineBlock",
    ["waxed_oxidized_copper_trapdoor"]="trapDoorIronFlipped", ["waxed_oxidized_cut_copper"]="prismarineBlock",
    ["waxed_oxidized_cut_copper_slab"]="prismarineSlab", ["waxed_oxidized_cut_copper_stairs"]="prismarineStair",
    ["waxed_weathered_copper"]="prismarineBlock", ["waxed_weathered_copper_chain"]="prismarineBlock",
    ["waxed_weathered_copper_trapdoor"]="trapDoorIronFlipped", ["waxed_weathered_cut_copper"]="prismarineBlock",
    ["waxed_weathered_cut_copper_slab"]="prismarineSlab", ["waxed_weathered_cut_copper_stairs"]="prismarineStair",
    ["weathered_chiseled_copper"]="prismarineBlock", ["weathered_copper"]="prismarineBlock",
    ["weathered_copper_chain"]="prismarineBlock", ["weathered_copper_trapdoor"]="trapDoorIronFlipped",
    ["weathered_cut_copper"]="prismarineBlock", ["weathered_cut_copper_slab"]="prismarineSlab",
    ["weathered_cut_copper_stairs"]="prismarineStair", ["wet_sponge"]="clayYellow", ["white_banner"]="woolWhite",
    ["white_bed"]="woolWhite", ["white_candle"]="clayWhite", ["white_carpet"]="carpet",
    ["white_concrete"]="whiteBlock", ["white_concrete_powder"]="clayWhite", ["white_glazed_terracotta"]="clayWhite",
    ["white_shulker_box"]="clayWhite", ["white_stained_glass"]="glassBlockChrome",
    ["white_stained_glass_pane"]="glassPane", ["white_terracotta"]="clayWhite", ["white_wall_banner"]="woolWhite",
    ["white_wool"]="woolWhite", ["wither_skeleton_skull"]="coalBlock", ["wither_skeleton_wall_skull"]="coalBlock",
    ["yellow_banner"]="woolYellow", ["yellow_bed"]="woolYellow", ["yellow_candle"]="clayYellow",
    ["yellow_carpet"]="carpetYellow", ["yellow_concrete"]="yellowBlock",
    ["yellow_concrete_powder"]="pastelYellowBlock", ["yellow_glazed_terracotta"]="clayYellow",
    ["yellow_shulker_box"]="clayYellow", ["yellow_stained_glass"]="glassBlockYellow",
    ["yellow_stained_glass_pane"]="glassPaneYellow", ["yellow_terracotta"]="clayYellow",
    ["yellow_wall_banner"]="woolYellow", ["yellow_wool"]="woolYellow", ["zombie_head"]="clayDarkGreen",
}
MC_DROP = {
    ["air"]=true, ["amethyst_cluster"]=true, ["barrier"]=true, ["beetroots"]=true, ["bush"]=true,
    ["cactus_flower"]=true, ["carrots"]=true, ["cave_air"]=true, ["cave_vines"]=true, ["cave_vines_plant"]=true,
    ["crimson_roots"]=true, ["dead_bush"]=true, ["fire"]=true, ["firefly_bush"]=true, ["hanging_roots"]=true,
    ["large_amethyst_bud"]=true, ["large_fern"]=true, ["leaf_litter"]=true, ["light"]=true,
    ["mangrove_propagule"]=true, ["medium_amethyst_bud"]=true, ["nether_sprouts"]=true, ["orange_tulip"]=true,
    ["pink_petals"]=true, ["pink_tulip"]=true, ["pitcher_plant"]=true, ["pointed_dripstone"]=true, ["potatoes"]=true,
    ["rail"]=true, ["red_tulip"]=true, ["redstone_wire"]=true, ["resin_clump"]=true, ["sea_pickle"]=true,
    ["sea_pickle_single"]=true, ["seagrass"]=true, ["small_amethyst_bud"]=true, ["small_dripleaf"]=true,
    ["snow"]=true, ["soul_fire"]=true, ["spore_blossom"]=true, ["structure_void"]=true, ["sugar_cane"]=true,
    ["torchflower"]=true, ["tripwire"]=true, ["twisting_vines"]=true, ["twisting_vines_plant"]=true,
    ["void_air"]=true, ["warped_roots"]=true, ["weeping_vines"]=true, ["weeping_vines_plant"]=true, ["wheat"]=true,
    ["white_tulip"]=true, ["wildflowers"]=true, ["wither_rose"]=true,
}
MC_FACING = {
    north = { -1, 0, 0, 0, 1, 0 },
    east = { 0, 0, -1, 0, 1, 0 },
    south = { 1, 0, 0, 0, 1, 0 },
    west = { 0, 0, 1, 0, 1, 0 },
}
MC_AXIS = {
    y = { 1, 0, 0, 0, 1, 0 },
    x = { 0, 1, 0, 1, 0, 0 },
    z = { 1, 0, 0, 0, 0, 1 },
}
MC_IDENTITY = { 1, 0, 0, 0, 1, 0 }

-- ═══════════════════════════════════════════════════════════════════════════
-- MINECRAFT CONVERTER — .schem and .litematic straight into a build file
-- ═══════════════════════════════════════════════════════════════════════════
-- Drop a schematic into autoBuilder/converter and turn it into a build file
-- without leaving the game. The block table is generated from the same
-- mcconvert/blockmap.py the offline converters use, so a schematic converts
-- the same way here as it does on a desktop.
--
-- Both formats are gzipped NBT. The inflate that reads PNGs reads these too,
-- once the gzip header is stepped over.
do

-- ── gzip ───────────────────────────────────────────────────────────────────
local function gunzip(data)
    if data:byte(1) ~= 0x1F or data:byte(2) ~= 0x8B then
        -- some tools hand out plain NBT, and a few hand out zlib
        if data:byte(1) == 0x78 then
            local out = {}
            local ok = pcall(inflate, Reader.new(data), function(b)
                out[#out + 1] = string.char(b)
            end)
            if ok then return table.concat(out) end
        end
        return data
    end
    if data:byte(3) ~= 8 then return nil, "unsupported gzip method" end

    local flags = data:byte(4)
    local pos = 11                     -- 10-byte header, 1-based
    if bit32.band(flags, 4) ~= 0 then  -- FEXTRA
        local xlen = data:byte(pos) + data:byte(pos + 1) * 256
        pos = pos + 2 + xlen
    end
    if bit32.band(flags, 8) ~= 0 then  -- FNAME
        while data:byte(pos) and data:byte(pos) ~= 0 do pos = pos + 1 end
        pos = pos + 1
    end
    if bit32.band(flags, 16) ~= 0 then -- FCOMMENT
        while data:byte(pos) and data:byte(pos) ~= 0 do pos = pos + 1 end
        pos = pos + 1
    end
    if bit32.band(flags, 2) ~= 0 then pos = pos + 2 end  -- FHCRC

    local out = {}
    local n = 0
    local ok, err = pcall(inflate, Reader.new(data:sub(pos)), function(b)
        n = n + 1
        out[n] = string.char(b)
    end, true)
    if not ok then return nil, "could not unpack: " .. tostring(err) end
    return table.concat(out)
end

-- ── NBT ────────────────────────────────────────────────────────────────────
-- Big-endian, tag-prefixed. Only what a schematic uses is read; the tags for
-- entities and block entities are stepped over rather than decoded.
local function readNBT(data)
    local pos = 1

    local function u8() local v = data:byte(pos) pos = pos + 1 return v end
    local function u16() local v = string.unpack(">I2", data, pos) pos = pos + 2 return v end
    local function i32() local v = string.unpack(">i4", data, pos) pos = pos + 4 return v end
    local function i64() local v = string.unpack(">i8", data, pos) pos = pos + 8 return v end
    local function f32() local v = string.unpack(">f", data, pos) pos = pos + 4 return v end
    local function f64() local v = string.unpack(">d", data, pos) pos = pos + 8 return v end
    local function str()
        local len = u16()
        local v = data:sub(pos, pos + len - 1)
        pos = pos + len
        return v
    end

    local readPayload
    local function readList()
        local kind = u8()
        local count = i32()
        local out = { _kind = kind }
        for i = 1, count do out[i] = readPayload(kind) end
        return out
    end

    readPayload = function(kind)
        if kind == 1 then local v = u8() if v > 127 then v = v - 256 end return v
        elseif kind == 2 then local v = u16() if v > 32767 then v = v - 65536 end return v
        elseif kind == 3 then return i32()
        elseif kind == 4 then return i64()
        elseif kind == 5 then return f32()
        elseif kind == 6 then return f64()
        elseif kind == 7 then
            local len = i32()
            local v = data:sub(pos, pos + len - 1)
            pos = pos + len
            return { _bytes = v }
        elseif kind == 8 then return str()
        elseif kind == 9 then return readList()
        elseif kind == 10 then
            local out = {}
            while true do
                local t = u8()
                if t == 0 then break end
                local name = str()
                out[name] = readPayload(t)
                if pos % 262144 == 0 then task.wait() end
            end
            return out
        elseif kind == 11 then
            local len = i32()
            local out = table.create(len)
            for i = 1, len do out[i] = i32() end
            return out
        elseif kind == 12 then
            local len = i32()
            local out = table.create(len)
            for i = 1, len do out[i] = i64() end
            return out
        end
        error("unknown NBT tag " .. tostring(kind))
    end

    local kind = u8()
    if kind ~= 10 then return nil, "not NBT data" end
    str()                               -- root name
    return readPayload(10)
end

-- ── block states ───────────────────────────────────────────────────────────
-- "minecraft:oak_stairs[facing=north,half=top]" -> name, properties
local function parseState(state)
    state = state:gsub("^minecraft:", "")
    local base, rest = state:match("^([^%[]+)%[(.*)%]$")
    if not base then return state, {} end
    local props = {}
    for k, v in rest:gmatch("([%w_]+)=([%w_]+)") do props[k] = v end
    return base, props
end

local function resolveState(state)
    local base, props = parseState(state)
    if MC_DROP[base] or base == "air" or base == "cave_air" or base == "void_air" then
        return nil
    end
    local target = MC_MAP[base]
    if not target then
        if base:match("^potted_") then target = "clayOrange" else return nil, base end
    end

    local rot = MC_IDENTITY
    if props.facing and MC_FACING[props.facing] then
        rot = MC_FACING[props.facing]
    elseif props.axis and MC_AXIS[props.axis] then
        rot = MC_AXIS[props.axis]
    end

    -- Only a slab is half-height in Islands, so half=top on a stair and a
    -- double slab that maps to a full block are both ignored. This is the same
    -- rule blockmap.py applies, and skipping it is what put stairs inside
    -- their neighbours.
    local isSlab = target:lower():find("slab") ~= nil
    local upper, doubled = false, false
    if isSlab then
        if props.half == "top" or props.type == "top" then upper = true end
        if props.type == "double" then doubled = true end
    end
    return target, rot, upper, doubled
end

-- ── Sponge .schem ──────────────────────────────────────────────────────────
local function readSchem(root)
    local d = root.Schematic or root
    local w, h, l = d.Width, d.Height, d.Length
    local palette, blockData
    if d.Blocks then                    -- version 3
        palette = d.Blocks.Palette
        blockData = d.Blocks.Data and d.Blocks.Data._bytes
    else                                -- version 2
        palette = d.Palette
        blockData = d.BlockData and d.BlockData._bytes
    end
    if not (w and h and l and palette and blockData) then
        return nil, "this file is missing the parts a schematic needs"
    end

    -- palette maps state -> index; flip it
    local byIndex = {}
    for state, idx in pairs(palette) do byIndex[idx] = state end

    -- Sponge stores the blocks as unsigned LEB128 varints
    local ids = table.create(w * h * l)
    local n, pos, len = 0, 1, #blockData
    while pos <= len do
        local value, shift = 0, 0
        while true do
            local byte = blockData:byte(pos)
            pos = pos + 1
            value = value + (byte % 128) * (2 ^ shift)
            if byte < 128 then break end
            shift = shift + 7
        end
        n = n + 1
        ids[n] = value
        if n % 200000 == 0 then task.wait() end
    end

    return { w = w, h = h, l = l, ids = ids, byIndex = byIndex, count = n }
end

-- ── Litematica .litematic ──────────────────────────────────────────────────
local function readLitematic(root)
    local regions = root.Regions
    if not regions then return nil, "no regions in this litematic" end
    local name, region = next(regions)
    if not region then return nil, "no regions in this litematic" end

    local size = region.Size
    local w = math.abs(size.x or size.X or 0)
    local h = math.abs(size.y or size.Y or 0)
    local l = math.abs(size.z or size.Z or 0)
    local palette = region.BlockStatePalette
    local states = region.BlockStates
    if not (palette and states and w > 0) then
        return nil, "this litematic is missing its block data"
    end

    local byIndex = {}
    for i, entry in ipairs(palette) do
        local nm = entry.Name or "minecraft:air"
        local props = entry.Properties
        if props and next(props) then
            local parts = {}
            for k, v in pairs(props) do parts[#parts + 1] = k .. "=" .. tostring(v) end
            table.sort(parts)
            nm = nm .. "[" .. table.concat(parts, ",") .. "]"
        end
        byIndex[i - 1] = nm
    end

    -- Entries are packed into a long array, and an entry may straddle two
    -- longs. Litematica keeps the pre-1.16 spanning layout whatever the game
    -- version, so this always unpacks that way.
    local bits = 2
    while bit32.lshift(1, bits) < #palette do bits = bits + 1 end
    local vol = w * h * l
    local ids = table.create(vol)
    local mask = 2 ^ bits - 1

    for i = 0, vol - 1 do
        local at = i * bits
        local word = math.floor(at / 64) + 1
        local offset = at % 64
        local low = states[word] or 0
        local value
        if offset + bits <= 64 then
            value = math.floor(low / 2 ^ offset) % (mask + 1)
        else
            local high = states[word + 1] or 0
            local lowBits = 64 - offset
            value = math.floor(low / 2 ^ offset) % (2 ^ lowBits)
                + (high % 2 ^ (bits - lowBits)) * 2 ^ lowBits
        end
        ids[i + 1] = value
        if i % 200000 == 0 then task.wait() end
    end

    return { w = w, h = h, l = l, ids = ids, byIndex = byIndex, count = vol, name = name }
end

-- ── the conversion ─────────────────────────────────────────────────────────
BuilderAPI.schematicFiles = function()
    local files = {}
    if isfolder(CONVERT_DIR) then
        for _, f in ipairs(listfiles(CONVERT_DIR)) do
            local low = string.lower(f)
            if low:sub(-6) == ".schem" or low:sub(-10) == ".litematic" then
                table.insert(files, f:match("[^/\\]+$"))
            end
        end
    end
    table.sort(files)
    if #files == 0 then files[1] = "Nothing in autoBuilder/converter" end
    return files
end

BuilderAPI.convertSchematic = function(name, data, onProgress)
    local raw, err = gunzip(data)
    if not raw then return nil, err or "could not unpack the file" end

    local root
    local ok, res = pcall(readNBT, raw)
    if not ok or not res then return nil, "could not read the schematic data" end
    root = res

    local parsed, perr
    if string.lower(name):sub(-10) == ".litematic" then
        parsed, perr = readLitematic(root)
    else
        parsed, perr = readSchem(root)
    end
    if not parsed then return nil, perr or "unrecognised schematic" end

    local w, h, l = parsed.w, parsed.h, parsed.l
    local blocks = {}
    local kept = {}
    local unmapped = {}
    local dropped = 0

    for i = 1, parsed.count do
        local state = parsed.byIndex[parsed.ids[i]]
        if state then
            local target, rot, upper, doubled = resolveState(state)
            if target then
                -- schematics store blocks in Y, Z, X order
                local idx = i - 1
                local y = math.floor(idx / (w * l))
                local rem = idx % (w * l)
                local z = math.floor(rem / w)
                local x = rem % w
                local px, py, pz = x * 3, y * 3, z * 3
                -- On the grid, like every other block. A capture of a real
                -- island has its slabs at exactly the same heights as its full
                -- blocks, so Islands does not record the half in the position;
                -- upperBlock carries it.
                blocks[#blocks + 1] = {
                    blockType = target, upperBlock = upper,
                    cframe = { px, py, pz, rot[1], rot[2], rot[3], rot[4], rot[5], rot[6] },
                    parts = {},
                }
                kept[target] = (kept[target] or 0) + 1
                if doubled then
                    blocks[#blocks + 1] = {
                        blockType = target, upperBlock = true,
                        cframe = { px, py, pz, rot[1], rot[2], rot[3], rot[4], rot[5], rot[6] },
                        parts = {},
                    }
                end
            elseif rot then
                unmapped[rot] = (unmapped[rot] or 0) + 1
            else
                dropped = dropped + 1
            end
        end
        if i % 40000 == 0 then
            task.wait()
            if onProgress then onProgress(i, parsed.count, #blocks) end
        end
    end

    if #blocks == 0 then return nil, "nothing in that file mapped to an Islands block" end

    -- anchor to the build's own corner, like every other converter
    local mnx, mny, mnz = math.huge, math.huge, math.huge
    for _, b in ipairs(blocks) do
        if b.cframe[1] < mnx then mnx = b.cframe[1] end
        if b.cframe[2] < mny then mny = b.cframe[2] end
        if b.cframe[3] < mnz then mnz = b.cframe[3] end
    end
    for i, b in ipairs(blocks) do
        b.cframe[1] = b.cframe[1] - mnx
        b.cframe[2] = b.cframe[2] - mny
        b.cframe[3] = b.cframe[3] - mnz
        if i % 60000 == 0 then task.wait() end
    end

    return blocks, nil, {
        size = { w, h, l }, kept = kept, unmapped = unmapped, dropped = dropped,
    }
end

-- ── hollowing ──────────────────────────────────────────────────────────────
-- Drops every block whose six neighbours are all filled. Those cannot be seen
-- from anywhere, so the build looks identical and costs less. It only helps
-- where there is solid mass: on a castle of thin walls it finds almost
-- nothing, which is why the aggressive pass exists alongside it.
function hollowBuried(blocks)
    local occ = {}
    for _, b in ipairs(blocks) do
        local c = b.cframe
        occ[(math.floor(c[1] / 3 + 0.5) * 2048 + math.floor(c[2] / 3 + 0.5)) * 2048
            + math.floor(c[3] / 3 + 0.5)] = true
    end
    local out = {}
    for i, b in ipairs(blocks) do
        local c = b.cframe
        -- round, not floor: a seated slab sits three quarters off the grid and
        -- would otherwise be counted in the cell below its own
        local x = math.floor(c[1] / 3 + 0.5)
        local y = math.floor(c[2] / 3 + 0.5)
        local z = math.floor(c[3] / 3 + 0.5)
        local hidden =
            occ[((x + 1) * 2048 + y) * 2048 + z] and occ[((x - 1) * 2048 + y) * 2048 + z]
            and occ[(x * 2048 + y + 1) * 2048 + z] and occ[(x * 2048 + y - 1) * 2048 + z]
            and occ[(x * 2048 + y) * 2048 + z + 1] and occ[(x * 2048 + y) * 2048 + z - 1]
        if not hidden then out[#out + 1] = b end
        if i % 40000 == 0 then task.wait() end
    end
    return out
end

-- ── blending ───────────────────────────────────────────────────────────────
-- A converted build often reads as noise: Minecraft's stone, andesite,
-- diorite, smooth stone and their polished cousins all map to different
-- Islands blocks, so a wall that was one material over there arrives as five
-- slightly different greys over here. Nothing is wrong with any single choice;
-- together they look like blocks thrown at a wall.
--
-- This keeps the most-used blocks and moves the rest onto the nearest one that
-- survived, judged by the colours measured in game. Two blocks that look the
-- same become the same block, so surfaces read as surfaces. When two kept
-- blocks sit either side of the colour being replaced, it alternates between
-- them by position, which reads as the shade in between rather than a hard
-- edge - the same trick the model converter uses.
BuilderAPI.blendBuild = function(blocks, limit, dither, onProgress)
    local colours = BuilderAPI.blockColours and BuilderAPI.blockColours()
    if not colours then
        notifyWarn("Blend", "Could not read block colours - left as it was", 5)
        return blocks
    end

    local counts = {}
    for _, b in ipairs(blocks) do
        counts[b.blockType] = (counts[b.blockType] or 0) + 1
    end

    -- Shape matters as much as colour: swapping a slab for a full block or a
    -- stair fills a gap that was meant to be there, and a roof stops being a
    -- roof. Blocks only ever move onto another of the same shape.
    local function shapeOf(name)
        local low = name:lower()
        if low:find("slab") then return "slab" end
        if low:find("stair") then return "stair" end
        return "full"
    end

    local ranked = {}
    for name in pairs(counts) do
        if colours[name] then ranked[#ranked + 1] = name end
    end
    table.sort(ranked, function(p, q) return counts[p] > counts[q] end)
    if limit <= 0 or limit >= #ranked then return blocks end

    -- the budget is shared out by how common each shape is, so a build made
    -- mostly of full blocks does not spend it all on its handful of stairs
    local byShape, totals = {}, {}
    for _, name in ipairs(ranked) do
        local sh = shapeOf(name)
        byShape[sh] = byShape[sh] or {}
        table.insert(byShape[sh], name)
        totals[sh] = (totals[sh] or 0) + counts[name]
    end
    local grand = 0
    for _, n in pairs(totals) do grand = grand + n end

    local keep = {}
    local keepByShape = {}
    for sh, names in pairs(byShape) do
        local share = math.max(1, math.floor(limit * (totals[sh] / grand) + 0.5))
        keepByShape[sh] = {}
        for i = 1, math.min(share, #names) do
            keepByShape[sh][#keepByShape[sh] + 1] = names[i]
            keep[#keep + 1] = names[i]
        end
    end

    -- worked out once per block type, not once per block
    local swap = {}
    for _, name in ipairs(ranked) do
        local c = colours[name]
        local pool = keepByShape[shapeOf(name)] or keep
        local best, bestD, second, secondD
        for _, k in ipairs(pool) do
            local e = colours[k]
            local dL, da, db = c.L - e.L, c.a - e.a, c.b - e.b
            local d = dL * dL + da * da + db * db
            if not bestD or d < bestD then
                second, secondD = best, bestD
                best, bestD = k, d
            elseif not secondD or d < secondD then
                second, secondD = k, d
            end
        end
        local t = 0
        if second and dither then
            local e1, e2 = colours[best], colours[second]
            local vx, vy, vz = e2.L - e1.L, e2.a - e1.a, e2.b - e1.b
            local dx, dy, dz = c.L - e1.L, c.a - e1.a, c.b - e1.b
            local den = vx * vx + vy * vy + vz * vz
            if den > 1e-12 then
                t = math.clamp((dx * vx + dy * vy + dz * vz) / den, 0, 1)
            end
        end
        swap[name] = { best, second, t }
    end

    local changed = 0
    for i, b in ipairs(blocks) do
        local rule = swap[b.blockType]
        if rule and rule[1] ~= b.blockType then
            local pick = rule[1]
            if dither and rule[2] and rule[3] > 0 then
                local c = b.cframe
                local x = math.floor(c[1] / 3) % 4
                local y = math.floor(c[2] / 3) % 4
                local z = math.floor(c[3] / 3) % 4
                if MODEL.bayer[z][y][x] < rule[3] then pick = rule[2] end
            end
            if pick ~= b.blockType then
                b.blockType = pick
                changed = changed + 1
            end
        end
        if i % 40000 == 0 then
            task.wait()
            if onProgress then onProgress(i, #blocks) end
        end
    end

    notify("Blended", changed .. " blocks moved onto " .. limit .. " colours", 5, "info")
    return blocks
end

-- Called from loadSelectedBuild when the picked file is a schematic. Cached
-- per file and per blend setting, so previewing twice does not re-read it.
BuilderAPI.loadSchematicFile = function(name, data)
    CONVERT.cache = CONVERT.cache or {}
    local key = name .. "@" .. tostring(CONVERT.simplify) .. "@"
        .. tostring(CONVERT.blend) .. "@" .. tostring(CONVERT.hollow)
    if CONVERT.cache[key] then return { blocks = CONVERT.cache[key] } end

    notify("Schematic", "Reading " .. name .. "...", 5, "info")
    local lastMark = 0
    local blocks, err, info = BuilderAPI.convertSchematic(name, data,
        function(done, total)
            local mark = math.floor(done / total * 4)
            if mark > lastMark and mark < 4 then
                lastMark = mark
                notify("Schematic", (mark * 25) .. "% read", 2, "info")
            end
        end)
    if not blocks then
        notifyErr("Schematic", err or "Could not convert that file", 9)
        return nil
    end

    local mode = CONVERT.hollow or "Off"
    if mode ~= "Off" then
        local before = #blocks
        notify("Schematic", "Hollowing...", 4, "info")
        if mode == "Outside Only" then
            blocks = hollowExterior(blocks, true)
        else
            blocks = hollowBuried(blocks)
        end
        notify("Hollowed", before .. " -> " .. #blocks .. " blocks", 5, "info")
    end

    -- after hollowing, so the counts it ranks by are of blocks that survive
    if (CONVERT.simplify or 0) > 0 then
        notify("Schematic", "Blending colours...", 4, "info")
        blocks = BuilderAPI.blendBuild(blocks, CONVERT.simplify, CONVERT.blend)
    end

    CONVERT.cache[key] = blocks
    local kinds = 0
    for _ in pairs(info.kept) do kinds = kinds + 1 end
    local un = 0
    for _ in pairs(info.unmapped) do un = un + 1 end
    notifyOK("Schematic", ("%d blocks, %dx%dx%d, %d block types%s")
        :format(#blocks, info.size[1], info.size[2], info.size[3], kinds,
                un > 0 and (", " .. un .. " kinds had no match") or ""), 9)
    return { blocks = blocks }
end

end

-- ═══════════════════════════════════════════════════════════════════════════
-- GLB -> BLOCKS
-- ═══════════════════════════════════════════════════════════════════════════
-- Drop a .glb straight into autoBuilder next to the build files and it shows
-- up in the file list like one. It is voxelised here, on the client, using the
-- same palette and the same OKLab match the image converter uses, so a model
-- and an image come out looking like they belong to each other.
--
-- The Python converter in mcconvert does the same job with more room to move -
-- solid fill, block budgets, huge models. This is for dropping a model in and
-- seeing it, without leaving the game.

do

local GLB_MAGIC = 0x46546C67
local GLB_JSON = 0x4E4F534A
local GLB_BIN = 0x004E4942

-- componentType -> (string.unpack format, byte width)
local GLB_COMP = {
    [5120] = { "i1", 1 }, [5121] = { "I1", 1 }, [5122] = { "i2", 2 },
    [5123] = { "I2", 2 }, [5125] = { "I4", 4 }, [5126] = { "f", 4 },
}
local GLB_COUNT = { SCALAR = 1, VEC2 = 2, VEC3 = 3, VEC4 = 4, MAT4 = 16 }

-- ── 4x4 matrices, row-major, 1-based ───────────────────────────────────────
-- CFrame cannot carry the scale a glTF node may have, so these are plain
-- tables rather than CFrames.
local function matIdentity()
    return { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 }
end

local function matMul(a, b)
    local m = {}
    for r = 0, 3 do
        for c = 1, 4 do
            m[r * 4 + c] = a[r * 4 + 1] * b[c]
                + a[r * 4 + 2] * b[4 + c]
                + a[r * 4 + 3] * b[8 + c]
                + a[r * 4 + 4] * b[12 + c]
        end
    end
    return m
end

local function matApply(m, x, y, z)
    return m[1] * x + m[2] * y + m[3] * z + m[4],
           m[5] * x + m[6] * y + m[7] * z + m[8],
           m[9] * x + m[10] * y + m[11] * z + m[12]
end

local function nodeMatrix(node)
    if node.matrix then
        -- glTF matrices are column-major; transpose into row-major
        local a, m = node.matrix, {}
        for r = 0, 3 do
            for c = 1, 4 do m[r * 4 + c] = a[(c - 1) * 4 + r + 1] end
        end
        return m
    end
    local m = matIdentity()
    if node.scale then
        m = matMul({ node.scale[1],0,0,0, 0,node.scale[2],0,0,
                     0,0,node.scale[3],0, 0,0,0,1 }, m)
    end
    if node.rotation then
        local x, y, z, w = node.rotation[1], node.rotation[2], node.rotation[3], node.rotation[4]
        m = matMul({
            1-2*(y*y+z*z), 2*(x*y-z*w),   2*(x*z+y*w),   0,
            2*(x*y+z*w),   1-2*(x*x+z*z), 2*(y*z-x*w),   0,
            2*(x*z-y*w),   2*(y*z+x*w),   1-2*(x*x+y*y), 0,
            0, 0, 0, 1 }, m)
    end
    if node.translation then
        m = matMul({ 1,0,0,node.translation[1], 0,1,0,node.translation[2],
                     0,0,1,node.translation[3], 0,0,0,1 }, m)
    end
    return m
end

-- ── container ──────────────────────────────────────────────────────────────
local function parseGLB(data)
    if #data < 20 then return nil, "File is too small to be a GLB" end
    local magic = string.unpack("<I4", data, 1)
    if magic ~= GLB_MAGIC then
        if data:sub(1, 1) == "{" then
            return nil, "That is a .gltf, not a .glb. Export it as .glb so the textures come with it."
        end
        return nil, "Not a GLB file"
    end
    local version = string.unpack("<I4", data, 5)
    if version ~= 2 then return nil, "GLB version " .. version .. ", only 2 is supported" end

    local gltf, bin
    local pos = 13
    while pos + 8 <= #data + 1 do
        local len = string.unpack("<I4", data, pos)
        local kind = string.unpack("<I4", data, pos + 4)
        local body = data:sub(pos + 8, pos + 7 + len)
        pos = pos + 8 + len + ((-len) % 4)
        if kind == GLB_JSON then
            local ok, decoded = pcall(function()
                return HttpService:JSONDecode((body:gsub("[%s%z]+$", "")))
            end)
            if not ok then return nil, "The GLB's JSON chunk would not parse" end
            gltf = decoded
        elseif kind == GLB_BIN then
            bin = body
        end
    end
    if not gltf then return nil, "No JSON chunk in the GLB" end

    for _, ext in ipairs(gltf.extensionsRequired or {}) do
        if ext == "KHR_draco_mesh_compression" then
            return nil, "Mesh is Draco-compressed. Re-export it without Draco."
        elseif ext == "EXT_meshopt_compression" then
            return nil, "Mesh is meshopt-compressed. Re-export it without that."
        end
    end
    return { gltf = gltf, bin = bin or "" }
end

local function accessorReader(m, index)
    local acc = m.gltf.accessors[index + 1]
    if not acc then return nil end
    if acc.sparse then return nil end
    local comp = GLB_COMP[acc.componentType]
    local n = GLB_COUNT[acc.type]
    if not comp or not n then return nil end
    if acc.bufferView == nil then return nil end

    local bv = m.gltf.bufferViews[acc.bufferView + 1]
    local base = (bv.byteOffset or 0) + (acc.byteOffset or 0)
    local stride = bv.byteStride or (comp[2] * n)
    local fmt = "<" .. string.rep(comp[1], n)
    local norm = acc.normalized
    local scale = 1
    if norm then
        if acc.componentType == 5121 then scale = 1 / 255
        elseif acc.componentType == 5123 then scale = 1 / 65535 end
    end

    -- returns the i-th element (0-based) as up to 4 numbers
    return function(i)
        local at = base + i * stride + 1
        if n == 1 then
            local v = string.unpack(fmt, m.bin, at)
            return norm and v * scale or v
        end
        if n > 4 then
            -- MAT4 and friends. string.unpack returns the values *and* the
            -- position it stopped at, so that trailing index has to go or the
            -- caller sees 17 numbers where it wanted 16.
            local vals = { string.unpack(fmt, m.bin, at) }
            vals[#vals] = nil
            return table.unpack(vals)
        end
        local a, b, c, d = string.unpack(fmt, m.bin, at)
        if norm then
            a = a * scale
            if b then b = b * scale end
            if c then c = c * scale end
            if d then d = d * scale end
        end
        return a, b, c, d
    end, acc.count
end

-- ── materials and textures ─────────────────────────────────────────────────
-- ── JPEG ───────────────────────────────────────────────────────────────────
-- Enough of a baseline JPEG decoder to colour blocks, and no more.
--
-- A JPEG stores each 8x8 pixel block as a DC coefficient - the block's average
-- - plus 63 AC coefficients describing the detail within it. Reconstructing
-- the pixels means an inverse DCT on every block, which is where the cost and
-- most of the code lives. But a model only needs a few hundred blocks of
-- colour, so the averages alone are plenty: taking the DC and discarding the
-- rest yields the image at 1/8 scale with no IDCT, no upsampling and no
-- colour-fringe handling. A 1024px texture lands at 128px, which is already
-- finer than any model will resolve.
--
-- Baseline (SOF0/SOF1) only. Progressive JPEG interleaves coefficients across
-- scans and cannot be read this way; it is refused by name.
MODEL.decodeJPEG8 = function(data)
    if data:byte(1) ~= 0xFF or data:byte(2) ~= 0xD8 then
        return nil, "not a JPEG"
    end

    local qt, huffDC, huffAC = {}, {}, {}
    local comps, frameW, frameH = nil, 0, 0
    local restart = 0
    local pos = 3
    local scanAt = nil

    local function u16(at) return data:byte(at) * 256 + data:byte(at + 1) end

    while pos < #data do
        if data:byte(pos) ~= 0xFF then pos = pos + 1 else
            local marker = data:byte(pos + 1)
            if marker == 0xD8 or marker == 0x01 or (marker >= 0xD0 and marker <= 0xD7) then
                pos = pos + 2
            elseif marker == 0xD9 then
                break
            else
                local len = u16(pos + 2)
                local body = pos + 4

                if marker == 0xDB then                      -- quantisation
                    local at = body
                    while at < pos + 2 + len do
                        local pq = math.floor(data:byte(at) / 16)
                        local tq = data:byte(at) % 16
                        at = at + 1
                        local tbl = {}
                        for i = 1, 64 do
                            if pq == 1 then
                                tbl[i] = u16(at) at = at + 2
                            else
                                tbl[i] = data:byte(at) at = at + 1
                            end
                        end
                        qt[tq] = tbl
                    end

                elseif marker == 0xC0 or marker == 0xC1 then -- baseline frame
                    frameH = u16(body + 1)
                    frameW = u16(body + 3)
                    local n = data:byte(body + 5)
                    comps = {}
                    for i = 1, n do
                        local at = body + 6 + (i - 1) * 3
                        comps[i] = {
                            id = data:byte(at),
                            h = math.floor(data:byte(at + 1) / 16),
                            v = data:byte(at + 1) % 16,
                            tq = data:byte(at + 2),
                            pred = 0,
                        }
                    end

                elseif marker == 0xC2 then
                    return nil, "progressive JPEG - re-export it as baseline, or as PNG"
                elseif marker == 0xC3 or (marker >= 0xC5 and marker <= 0xCF and marker ~= 0xC8) then
                    return nil, "unsupported JPEG type (not baseline)"

                elseif marker == 0xC4 then                   -- huffman tables
                    local at = body
                    while at < pos + 2 + len do
                        local tc = math.floor(data:byte(at) / 16)
                        local th = data:byte(at) % 16
                        at = at + 1
                        local counts, total = {}, 0
                        for i = 1, 16 do
                            counts[i] = data:byte(at + i - 1)
                            total = total + counts[i]
                        end
                        at = at + 16
                        local tbl, code = {}, 0
                        for len2 = 1, 16 do
                            tbl[len2] = {}
                            for _ = 1, counts[len2] do
                                tbl[len2][code] = data:byte(at)
                                at = at + 1
                                code = code + 1
                            end
                            code = code * 2
                        end
                        if tc == 0 then huffDC[th] = tbl else huffAC[th] = tbl end
                    end

                elseif marker == 0xDD then                   -- restart interval
                    restart = u16(body)

                elseif marker == 0xDA then                   -- start of scan
                    local n = data:byte(body)
                    for i = 1, n do
                        local at = body + 1 + (i - 1) * 2
                        local cid = data:byte(at)
                        for _, c in ipairs(comps or {}) do
                            if c.id == cid then
                                c.td = math.floor(data:byte(at + 1) / 16)
                                c.ta = data:byte(at + 1) % 16
                            end
                        end
                    end
                    scanAt = pos + 2 + len
                    break
                end
                pos = pos + 2 + len
            end
        end
    end

    if not comps or not scanAt then return nil, "JPEG has no baseline scan" end

    -- ── entropy-coded data ─────────────────────────────────────────────────
    local at, bitBuf, bitCount = scanAt, 0, 0

    local function readBit()
        if bitCount == 0 then
            local b = data:byte(at)
            if b == nil then return 0 end
            at = at + 1
            if b == 0xFF then
                local nxt = data:byte(at)
                if nxt == 0x00 then at = at + 1
                elseif nxt and nxt >= 0xD0 and nxt <= 0xD7 then at = at + 1
                else return 0 end
            end
            bitBuf, bitCount = b, 8
        end
        bitCount = bitCount - 1
        return math.floor(bitBuf / (2 ^ bitCount)) % 2
    end

    local function decodeHuff(tbl)
        if not tbl then return 0 end
        local code = 0
        for len = 1, 16 do
            code = code * 2 + readBit()
            local row = tbl[len]
            if row then
                local v = row[code]
                if v ~= nil then return v end
            end
        end
        return 0
    end

    local function receive(n)
        local v = 0
        for _ = 1, n do v = v * 2 + readBit() end
        return v
    end

    local function extend(v, n)
        if n == 0 then return 0 end
        if v < 2 ^ (n - 1) then return v - 2 ^ n + 1 end
        return v
    end

    local maxH, maxV = 1, 1
    for _, c in ipairs(comps) do
        if c.h > maxH then maxH = c.h end
        if c.v > maxV then maxV = c.v end
    end
    local mcusX = math.ceil(frameW / (8 * maxH))
    local mcusY = math.ceil(frameH / (8 * maxV))
    for _, c in ipairs(comps) do
        c.bw = mcusX * c.h
        c.plane = {}
    end

    local done = 0
    for my = 0, mcusY - 1 do
        for mx = 0, mcusX - 1 do
            if restart > 0 and done > 0 and done % restart == 0 then
                bitCount = 0
                -- step over the restart marker itself
                while at < #data do
                    if data:byte(at) == 0xFF then
                        local nxt = data:byte(at + 1)
                        if nxt and nxt >= 0xD0 and nxt <= 0xD7 then at = at + 2 break end
                    end
                    at = at + 1
                end
                for _, c in ipairs(comps) do c.pred = 0 end
            end

            for _, c in ipairs(comps) do
                for by = 0, c.v - 1 do
                    for bx = 0, c.h - 1 do
                        local t = decodeHuff(huffDC[c.td or 0])
                        c.pred = c.pred + (t == 0 and 0 or extend(receive(t), t))
                        c.plane[(my * c.v + by) * c.bw + (mx * c.h + bx)] = c.pred

                        -- walk the AC coefficients only to stay in step with
                        -- the bitstream; their values are of no use here
                        local k = 1
                        while k <= 63 do
                            local rs = decodeHuff(huffAC[c.ta or 0])
                            local r = math.floor(rs / 16)
                            local sz = rs % 16
                            if sz == 0 then
                                if r == 15 then k = k + 16 else break end
                            else
                                k = k + r + 1
                                receive(sz)
                            end
                        end
                    end
                end
            end
            done = done + 1
        end
        if my % 2 == 0 then task.wait() end
    end

    -- ── DC to pixels ───────────────────────────────────────────────────────
    local outW, outH = mcusX * maxH, mcusY * maxV
    local px = table.create(outW * outH * 3)

    local function sampleOf(c, x, y)
        local sx = math.floor(x * c.h / maxH)
        local sy = math.floor(y * c.v / maxV)
        local dc = c.plane[sy * c.bw + sx] or 0
        local q = qt[c.tq] and qt[c.tq][1] or 1
        return dc * q / 8 + 128
    end

    for y = 0, outH - 1 do
        for x = 0, outW - 1 do
            local r, g, b
            if #comps >= 3 then
                local Y = sampleOf(comps[1], x, y)
                local cb = sampleOf(comps[2], x, y) - 128
                local cr = sampleOf(comps[3], x, y) - 128
                r = Y + 1.402 * cr
                g = Y - 0.344136 * cb - 0.714136 * cr
                b = Y + 1.772 * cb
            else
                r = sampleOf(comps[1], x, y)
                g, b = r, r
            end
            local o = (y * outW + x) * 3
            px[o + 1] = math.clamp(math.floor(r + 0.5), 0, 255)
            px[o + 2] = math.clamp(math.floor(g + 0.5), 0, 255)
            px[o + 3] = math.clamp(math.floor(b + 0.5), 0, 255)
        end
    end

    return {
        w = outW, h = outH, from = frameW .. "x" .. frameH,
        get = function(x, y)
            if x < 1 then x = 1 elseif x > outW then x = outW end
            if y < 1 then y = 1 elseif y > outH then y = outH end
            local o = ((y - 1) * outW + (x - 1)) * 3
            return px[o + 1], px[o + 2], px[o + 3], 255
        end,
    }
end

-- A decoded 1024x1024 texture is about three million Lua numbers - tens of
-- megabytes - and a model with three of them would hold all three at once.
-- That is a good way to run an executor out of memory, and the failure is
-- silent: the texture is dropped and the material falls back to plain white.
-- Nothing here needs that much detail, since even a large model is only a few
-- hundred blocks tall, so each texture is shrunk and the full-size copy let go
-- immediately.
MODEL.shrinkTexture = function(tex, maxDim)
    local w, h = tex.w, tex.h
    if w <= maxDim and h <= maxDim then return tex end
    local nw = math.min(maxDim, w)
    local nh = math.max(1, math.floor(h * nw / w + 0.5))
    local px = table.create(nw * nh * 3)
    for y = 1, nh do
        local sy = math.min(h, math.floor((y - 0.5) * h / nh) + 1)
        for x = 1, nw do
            local sx = math.min(w, math.floor((x - 0.5) * w / nw) + 1)
            local r, g, b = tex.get(sx, sy)
            local o = ((y - 1) * nw + (x - 1)) * 3
            px[o + 1], px[o + 2], px[o + 3] = r, g, b
        end
        if y % 12 == 0 then task.wait() end
    end
    return { w = nw, h = nh, from = w .. "x" .. h, get = function(x, y)
        if x < 1 then x = 1 elseif x > nw then x = nw end
        if y < 1 then y = 1 elseif y > nh then y = nh end
        local o = ((y - 1) * nw + (x - 1)) * 3
        return px[o + 1], px[o + 2], px[o + 3], 255
    end }
end

-- Colour for a material: its texture if one can be decoded, else its flat
-- base colour. Every outcome is counted, because they are indistinguishable in
-- the result: a glTF with no baseColorFactor defaults to pure white, and pure
-- white is an exact match for neonWhite. So a texture that fails to decode
-- produces a flat white-neon model - which looks identical to a palette
-- restricted to Neon, and has an entirely different cause.
local function materialColour(m, index)
    m.tex = m.tex or { ok = 0, failed = 0, jpeg = 0, missing = 0, sizes = {} }
    local mat = index ~= nil and m.gltf.materials and m.gltf.materials[index + 1]
    if not mat then
        m.tex.missing = m.tex.missing + 1
        return { 1, 1, 1 }, nil
    end
    local pbr = mat.pbrMetallicRoughness or {}
    local f = pbr.baseColorFactor or { 1, 1, 1, 1 }
    local tex = nil
    if pbr.baseColorTexture then
        local ti = pbr.baseColorTexture.index
        m.texCache = m.texCache or {}
        if m.texCache[ti] == nil then
            m.texCache[ti] = false
            local t = m.gltf.textures and m.gltf.textures[ti + 1]
            local img = t and t.source ~= nil and m.gltf.images[t.source + 1]
            if img and img.bufferView ~= nil then
                local bv = m.gltf.bufferViews[img.bufferView + 1]
                local bytes = m.bin:sub((bv.byteOffset or 0) + 1,
                                        (bv.byteOffset or 0) + bv.byteLength)
                local isPNG = bytes:sub(1, 8) == "\137PNG\r\n\26\n"
                local isJPEG = bytes:byte(1) == 0xFF and bytes:byte(2) == 0xD8
                if isPNG or isJPEG then
                    local ok, decoded, why
                    if isPNG then
                        ok, decoded = pcall(decodePNG, bytes)
                    else
                        ok, decoded, why = pcall(MODEL.decodeJPEG8, bytes)
                        if ok and not decoded then why = decoded end
                    end
                    if ok and decoded then
                        local small = MODEL.shrinkTexture(decoded, MODEL.texSize or 256)
                        decoded = nil          -- let the full-size copy go
                        m.texCache[ti] = small
                        m.tex.ok = m.tex.ok + 1
                        m.tex.sizes[#m.tex.sizes + 1] =
                            (small.from and (small.from .. "->") or "")
                            .. small.w .. "x" .. small.h
                    else
                        m.tex.failed = m.tex.failed + 1
                        m.tex.why = m.tex.why or tostring(why or decoded)
                    end
                else
                    m.tex.other = (m.tex.other or 0) + 1
                end
            else
                m.tex.missing = m.tex.missing + 1
            end
        end
        tex = m.texCache[ti] or nil
    else
        m.tex.missing = m.tex.missing + 1
    end
    return { f[1] or 1, f[2] or 1, f[3] or 1 }, tex
end

-- ── skinning ───────────────────────────────────────────────────────────────
-- A rigged model stores POSITION in its bind pose - arms out, the T-pose - and
-- keeps the pose you actually see in the joint nodes. Reading POSITION alone
-- gives you a T-pose however the model looks in a viewer. Each vertex belongs
-- to up to four joints by weight:
--
--   p' = sum_j  w_j * (globalTransform(joint_j) * inverseBindMatrix_j) * p
--
-- The mesh node's own transform is deliberately left out: for a skinned mesh
-- glTF says the joint matrices already carry it.
local function skinMatrices(m, skinIndex, globals)
    local skin = m.gltf.skins and m.gltf.skins[skinIndex + 1]
    if not skin or not skin.joints then return nil end

    local ibmRead
    if skin.inverseBindMatrices ~= nil then
        ibmRead = accessorReader(m, skin.inverseBindMatrices)
    end

    local mats = {}
    for i, nodeIndex in ipairs(skin.joints) do
        local ibm = matIdentity()
        if ibmRead then
            -- MAT4 comes back column-major, sixteen at a time
            local c = { ibmRead(i - 1) }
            if #c == 16 then
                for r = 0, 3 do
                    for col = 1, 4 do ibm[r * 4 + col] = c[(col - 1) * 4 + r + 1] end
                end
            end
        end
        mats[i] = matMul(globals[nodeIndex] or matIdentity(), ibm)
    end
    return mats
end

-- ── palette ────────────────────────────────────────────────────────────────
-- Models keep their own palette. They used to borrow the image converter's,
-- which meant a group left selected on the Image tab silently governed every
-- model too - pick Neon there for one picture and every model afterwards comes
-- out in white neon with no detail. These are stored on MODEL rather than as
-- locals because the main chunk is at Luau's 200-local ceiling.
MODEL.buildPalette = function()
    local want = MODEL.groups
    if not want or next(want) == nil then
        MODEL.pal = IMAGE_PAL
    else
        local out = {}
        for _, e in ipairs(IMAGE_PAL) do
            if want[e.group] then out[#out + 1] = e end
        end
        MODEL.pal = (#out > 0) and out or IMAGE_PAL
    end
    MODEL.match = {}
    MODEL.ditherCache = {}
end

MODEL.blockFor = function(r, g, b)
    MODEL.match = MODEL.match or {}
    local key = r .. "," .. g .. "," .. b
    local hit = MODEL.match[key]
    if hit then return hit[1], hit[2] end
    local L, a, bb = BA.toOklab(Color3.fromRGB(r, g, b))
    local best = nearestIn(MODEL.pal or IMAGE_PAL, L, a, bb)
    local rec = best and { best.name, best.col }
        or { "stone", Color3.fromRGB(r, g, b) }
    MODEL.match[key] = rec
    return rec[1], rec[2]
end

-- ── dithering ──────────────────────────────────────────────────────────────
-- Ninety-one colours cannot express a face. But a block is small: put two
-- nearby colours next to each other in a pattern and the eye averages them,
-- which buys far more apparent colours for nothing. Find the nearest block,
-- then the nearest block on the far side of the wanted colour, work out how
-- far between the two the real colour lies, and let an ordered threshold taken
-- from the cell's own position decide which to place. Nothing is carried
-- between cells, so it stays deterministic and seamless.
-- Built inside a function so its loop variables get their own registers: the
-- main chunk is at Luau's 200-local ceiling and a bare do block shares them.
MODEL.bayer = (function()
    local base = { {0,8,2,10}, {12,4,14,6}, {3,11,1,9}, {15,7,13,5} }
    local out = {}
    for z = 0, 3 do
        out[z] = {}
        for y = 0, 3 do
            out[z][y] = {}
            for x = 0, 3 do
                local v = (base[y + 1][x + 1]
                    + 16 * (math.floor(base[z + 1][y + 1] / 4) % 4)) % 64
                out[z][y][x] = (v + 0.5) / 64
            end
        end
    end
    return out
end)()

local function ditherBlock(r, g, b, x, y, z)
    local key = math.floor(r / 2) .. "," .. math.floor(g / 2) .. "," .. math.floor(b / 2)
    MODEL.ditherCache = MODEL.ditherCache or {}
    local pair = MODEL.ditherCache[key]
    if not pair then
        local n1, c1 = MODEL.blockFor(r, g, b)
        -- How wrong the single nearest block actually is. Mixing two blocks
        -- only earns its keep when no single block is close: a broad even
        -- surface like skin has a block that matches it well, and speckling a
        -- second one through it adds a checker pattern that is not detail,
        -- just noise.
        local dL, da, db = BA.toOklab(Color3.fromRGB(r, g, b))
        local cL, ca, cb = BA.toOklab(c1)
        local miss = math.sqrt((dL - cL) ^ 2 + (da - ca) ^ 2 + (db - cb) ^ 2)
        -- reflect the colour through the nearest block to find what lies beyond
        local rr = math.clamp(2 * r - c1.R * 255, 0, 255)
        local gg = math.clamp(2 * g - c1.G * 255, 0, 255)
        local bb = math.clamp(2 * b - c1.B * 255, 0, 255)
        local n2, c2 = MODEL.blockFor(math.floor(rr + 0.5), math.floor(gg + 0.5), math.floor(bb + 0.5))
        if n2 == n1 then
            pair = { n1, n1, 0 }
        else
            local L2, a2, b2 = BA.toOklab(c2)
            local vx, vy, vz = L2 - cL, a2 - ca, b2 - cb
            local dx, dy, dz = dL - cL, da - ca, db - cb
            local den = vx * vx + vy * vy + vz * vz
            local t = den <= 1e-12 and 0 or (dx * vx + dy * vy + dz * vz) / den
            pair = { n1, n2, math.clamp(t, 0, 1), miss }
        end
        MODEL.ditherCache[key] = pair
    end
    if pair[3] <= 0 then return pair[1] end
    -- below the threshold the nearest block is close enough on its own
    if (pair[4] or 0) < (MODEL.ditherMin or 0.035) then return pair[1] end
    local t = pair[3] * (MODEL.ditherAmount or 1)
    if t <= 0 then return pair[1] end
    return MODEL.bayer[z % 4][y % 4][x % 4] < t and pair[2] or pair[1]
end

-- ── voxelising ─────────────────────────────────────────────────────────────
-- Samples every triangle on a barycentric lattice fine enough that no cell it
-- crosses is missed. A rasteriser would be faster but needs a special case for
-- every skinny or edge-on triangle; this one has none.
local MODEL_MAX_CELLS = 600000
-- A ceiling on sampling work as well as on output. A model with a few huge
-- triangles can want tens of millions of samples at a high detail setting, and
-- grinding through those is what makes it look like a freeze.
local MODEL_MAX_SAMPLES = 9000000

-- Parse a GLB and hand back its meshes as world-space, posed vertices. Both
-- the voxeliser and the mesh viewer start here, so there is one implementation
-- of the node walk and of skinning rather than two that can drift apart.
MODEL.readMeshes = function(data)
    local m, err = parseGLB(data)
    if not m then return nil, err end
    local gltf = m.gltf

    -- Flatten the node tree into (primitive, world matrix) jobs, keeping every
    -- node's world transform as we go: a joint can live in a different branch
    -- from the mesh it drives, so skinning needs all of them.
    local jobs = {}
    local globals = {}
    local function walk(nodeIndex, parent)
        local node = gltf.nodes[nodeIndex + 1]
        if not node then return end
        local world = matMul(parent, nodeMatrix(node))
        globals[nodeIndex] = world
        if node.mesh ~= nil then
            local mesh = gltf.meshes[node.mesh + 1]
            for _, prim in ipairs(mesh and mesh.primitives or {}) do
                if (prim.mode or 4) == 4 and prim.attributes
                    and prim.attributes.POSITION ~= nil then
                    jobs[#jobs + 1] = { prim = prim, world = world, skin = node.skin }
                end
            end
        end
        for _, child in ipairs(node.children or {}) do walk(child, world) end
    end
    local scene = gltf.scenes and gltf.scenes[(gltf.scene or 0) + 1]
    if scene and scene.nodes then
        for _, n in ipairs(scene.nodes) do walk(n, matIdentity()) end
    else
        for i = 0, #(gltf.nodes or {}) - 1 do walk(i, matIdentity()) end
    end
    if #jobs == 0 then return nil, "No triangle geometry in that file" end

    -- pass one: world-space vertices and the bounding box
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local posedAny = false
    for _, job in ipairs(jobs) do
        local attrs = job.prim.attributes
        local read, count = accessorReader(m, attrs.POSITION)
        if not read then return nil, "Unsupported vertex data in that file" end

        -- a rigged mesh is posed by its skeleton, not by its own node
        local jointMats, jointRead, weightRead
        if job.skin ~= nil and attrs.JOINTS_0 ~= nil and attrs.WEIGHTS_0 ~= nil then
            jointMats = skinMatrices(m, job.skin, globals)
            if jointMats then
                jointRead = accessorReader(m, attrs.JOINTS_0)
                weightRead = accessorReader(m, attrs.WEIGHTS_0)
                if not jointRead or not weightRead then jointMats = nil end
            end
        end
        if jointMats then posedAny = true end

        local verts = table.create(count)
        for i = 0, count - 1 do
            local px, py, pz = read(i)
            local x, y, z
            if jointMats then
                local j1, j2, j3, j4 = jointRead(i)
                local w1, w2, w3, w4 = weightRead(i)
                local js = { j1, j2, j3, j4 }
                local ws = { w1 or 0, w2 or 0, w3 or 0, w4 or 0 }
                local total = ws[1] + ws[2] + ws[3] + ws[4]
                if total > 1e-8 then
                    x, y, z = 0, 0, 0
                    for k = 1, 4 do
                        local w = ws[k] / total
                        if w > 1e-8 then
                            local mat = jointMats[(js[k] or 0) + 1]
                            if mat then
                                local ax, ay, az = matApply(mat, px, py, pz)
                                x, y, z = x + ax * w, y + ay * w, z + az * w
                            end
                        end
                    end
                else
                    -- an unweighted vertex would otherwise collapse to the origin
                    x, y, z = matApply(job.world, px, py, pz)
                end
            else
                x, y, z = matApply(job.world, px, py, pz)
            end
            verts[i + 1] = { x, y, z }
            if x < minX then minX = x end
            if y < minY then minY = y end
            if z < minZ then minZ = z end
            if x > maxX then maxX = x end
            if y > maxY then maxY = y end
            if z > maxZ then maxZ = z end
            if i % 1200 == 0 then task.wait() end
        end
        job.verts = verts
    end

    return {
        m = m, jobs = jobs, posed = posedAny,
        minX = minX, minY = minY, minZ = minZ,
        maxX = maxX, maxY = maxY, maxZ = maxZ,
    }
end

-- ── the model as a mesh ────────────────────────────────────────────────────
-- The thumbnail used to show the blocks a model turns into. That is useful,
-- but it is not the model. Roblox can build a mesh at runtime from raw
-- triangles through EditableMesh, so the viewer can show the real thing.
--
-- The API has changed shape more than once and is not present in every
-- environment, so every call is guarded and the caller falls back to the block
-- render. Colour is per-vertex, sampled from the base texture at that vertex's
-- UV, which avoids needing an editable image as well.
MODEL.meshFromGLB = function(data, maxTris)
    local AssetService = game:GetService("AssetService")
    if not AssetService then return nil, "no AssetService" end

    local ok, em = pcall(function()
        return AssetService:CreateEditableMesh({})
    end)
    if not ok or not em then
        ok, em = pcall(function() return AssetService:CreateEditableMesh() end)
    end
    if not ok or not em then return nil, "this executor has no EditableMesh" end

    local read, err = MODEL.readMeshes(data)
    if type(read) ~= "table" then return nil, err or "could not read the model" end

    local cx = (read.minX + read.maxX) / 2
    local cy = (read.minY + read.maxY) / 2
    local cz = (read.minZ + read.maxZ) / 2
    local span = math.max(read.maxX - read.minX, read.maxY - read.minY,
                          read.maxZ - read.minZ, 1e-6)
    -- normalise into a sensible size for the viewport, centred on the origin
    local scale = 20 / span

    local tris, added = 0, 0
    local budget = maxTris or 40000

    for _, job in ipairs(read.jobs) do
        local prim = job.prim
        local verts = job.verts
        local attrs = prim.attributes
        local uvRead = attrs.TEXCOORD_0 ~= nil
            and accessorReader(read.m, attrs.TEXCOORD_0) or nil
        local base, tex = materialColour(read.m, prim.material)
        if not uvRead then tex = nil end

        local idxRead, idxCount
        if prim.indices ~= nil then
            idxRead, idxCount = accessorReader(read.m, prim.indices)
        else
            idxCount = #verts
            idxRead = function(i) return i end
        end
        if not idxRead then break end

        -- one editable vertex per glTF vertex, coloured once
        local ids = {}
        local function vertexId(vi)
            local id = ids[vi]
            if id then return id end
            local v = verts[vi]
            if not v then return nil end
            local okv, made = pcall(function()
                return em:AddVertex(Vector3.new(
                    (v[1] - cx) * scale, (v[2] - cy) * scale, (v[3] - cz) * scale))
            end)
            if not okv or not made then return nil end
            local r, g, b = base[1], base[2], base[3]
            if tex then
                local u, vv = uvRead(vi - 1)
                if u then
                    local tr, tg, tb = tex.get(
                        math.floor((u % 1) * (tex.w - 1)) + 1,
                        math.floor((vv % 1) * (tex.h - 1)) + 1)
                    r, g, b = r * tr / 255, g * tg / 255, b * tb / 255
                end
            end
            -- colour APIs differ between EditableMesh versions; try, shrug off
            pcall(function() em:SetVertexColor(made, Color3.new(r, g, b)) end)
            ids[vi] = made
            return made
        end

        for t = 0, math.floor(idxCount / 3) - 1 do
            if tris >= budget then break end
            local a = vertexId(idxRead(t * 3) + 1)
            local b = vertexId(idxRead(t * 3 + 1) + 1)
            local c = vertexId(idxRead(t * 3 + 2) + 1)
            if a and b and c then
                local okt = pcall(function() em:AddTriangle(a, b, c) end)
                if okt then added = added + 1 end
            end
            tris = tris + 1
            if t % 400 == 0 then task.wait() end
        end
        if tris >= budget then break end
    end

    if added == 0 then return nil, "no triangles could be added" end

    local okPart, part = pcall(function()
        return AssetService:CreateMeshPartAsync(Content.fromObject(em))
    end)
    if not okPart or not part then
        return nil, "this executor cannot turn an editable mesh into a part"
    end
    return part, nil, { triangles = added, posed = read.posed }
end

local function glbToBlocks(data, gridCells, onProgress)
    local read, readErr = MODEL.readMeshes(data)
    if type(read) ~= "table" then return nil, readErr or "Could not read that model" end
    local m, jobs, posedAny = read.m, read.jobs, read.posed
    local minX, minY, minZ = read.minX, read.minY, read.minZ
    local maxX, maxY, maxZ = read.maxX, read.maxY, read.maxZ

    local sx, sy, sz = maxX - minX, maxY - minY, maxZ - minZ
    -- glTF is Y-up by spec, but plenty of exports are Z-up and land on their
    -- side. A model standing up is taller than it is deep.
    local zUp = sz > sy * 1.6 and sz > sx * 1.1
    local longest = math.max(sx, sy, sz, 1e-9)
    local scale = gridCells / longest
    local spacing = 0.34 / scale

    local cells, order = {}, {}
    local placed = 0
    local stopped = false
    local tooBig = false
    local limited = nil
    local samples, lastYield = 0, 0

    for ji, job in ipairs(jobs) do
        local prim = job.prim
        local verts = job.verts
        local uvRead = prim.attributes.TEXCOORD_0 ~= nil
            and accessorReader(m, prim.attributes.TEXCOORD_0) or nil
        local base, tex = materialColour(m, prim.material)
        if not uvRead then tex = nil end

        local idxRead, idxCount
        if prim.indices ~= nil then
            idxRead, idxCount = accessorReader(m, prim.indices)
        else
            idxCount = #verts
            idxRead = function(i) return i end
        end
        if not idxRead then return nil, "Unsupported index data in that file" end

        -- Sampling one triangle. Four things used to make this crawl, and
        -- together they were the freeze:
        --
        --  * the UVs were read from the binary blob three times per *sample*
        --    rather than once per triangle - thousands of string.unpack calls
        --    for a single triangle;
        --  * every sample built a "x,y,z" string to key the cell table, so a
        --    few million string allocations and hashes;
        --  * a closure was allocated per triangle just to measure an edge;
        --  * and it yielded every 250 triangles, which at up to two thousand
        --    samples each is half a million samples inside one frame.
        --
        -- The sample count is also taken from the two edges separately now.
        -- Sizing a square lattice by the longest edge gives a long thin
        -- triangle thousands of samples when it needs dozens; this makes the
        -- work follow the area instead.
        local tw, th, tget
        if tex then tw, th, tget = tex.w - 1, tex.h - 1, tex.get end
        local br, bg, bb = base[1], base[2], base[3]
        local triCount = math.floor(idxCount / 3)

        for t = 0, triCount - 1 do
            local i0 = idxRead(t * 3) + 1
            local i1 = idxRead(t * 3 + 1) + 1
            local i2 = idxRead(t * 3 + 2) + 1
            local a, b, c = verts[i0], verts[i1], verts[i2]
            if a and b and c then
                local ax, ay, az = a[1], a[2], a[3]
                local e1x, e1y, e1z = b[1] - ax, b[2] - ay, b[3] - az
                local e2x, e2y, e2z = c[1] - ax, c[2] - ay, c[3] - az
                local nu = math.ceil(math.sqrt(e1x * e1x + e1y * e1y + e1z * e1z) / spacing) + 1
                local nv = math.ceil(math.sqrt(e2x * e2x + e2y * e2y + e2z * e2z) / spacing) + 1
                if nu < 1 then nu = 1 elseif nu > 64 then nu = 64 end
                if nv < 1 then nv = 1 elseif nv > 64 then nv = 64 end

                -- UVs once per triangle, not once per sample
                local u0, v0, u1, v1, u2, v2
                if tex then
                    u0, v0 = uvRead(i0 - 1)
                    u1, v1 = uvRead(i1 - 1)
                    u2, v2 = uvRead(i2 - 1)
                end

                for i = 0, nu do
                    local wi = i / nu
                    local jmax = math.floor((1 - wi) * nv)
                    for j = 0, jmax do
                        local wj = j / nv
                        local wk = 1 - wi - wj
                        local px = ax + e1x * wi + e2x * wj
                        local py = ay + e1y * wi + e2y * wj
                        local pz = az + e1z * wi + e2z * wj

                        -- reorient so Y is up, as a build file expects
                        local gx, gy, gz
                        if zUp then
                            gx = math.floor((px - minX) * scale)
                            gy = math.floor((pz - minZ) * scale)
                            gz = math.floor((maxY - py) * scale)
                        else
                            gx = math.floor((px - minX) * scale)
                            gy = math.floor((py - minY) * scale)
                            gz = math.floor((pz - minZ) * scale)
                        end

                        -- a plain number keys the table far more cheaply than
                        -- a concatenated string
                        local key = (gx * 2048 + gy) * 2048 + gz
                        local cell = cells[key]
                        if not cell then
                            if placed >= MODEL_MAX_CELLS then
                                stopped = true
                                break
                            end
                            cell = { gx, gy, gz, 0, 0, 0, 0 }
                            cells[key] = cell
                            order[#order + 1] = cell
                            placed = placed + 1
                        end

                        local r, g, bl = br, bg, bb
                        if tex then
                            local u = u0 * wk + u1 * wi + u2 * wj
                            local v = v0 * wk + v1 * wi + v2 * wj
                            local tr, tg, tb = tget(
                                math.floor((u % 1) * tw) + 1,
                                math.floor((v % 1) * th) + 1)
                            r, g, bl = r * tr / 255, g * tg / 255, bl * tb / 255
                        end
                        r, g, bl = r * 255, g * 255, bl * 255
                        cell[4] = cell[4] + r
                        cell[5] = cell[5] + g
                        cell[6] = cell[6] + bl
                        cell[7] = cell[7] + 1

                        -- Group the samples coarsely and keep a tally. A cell
                        -- on an edge - a hairline, a lash, the rim of an eye -
                        -- is crossed by two very different surfaces, and the
                        -- plain average of those is a colour on neither, which
                        -- is what made faces look smeared. The winning group's
                        -- own average is used instead.
                        local bk = math.floor(r / 40) * 49
                            + math.floor(g / 40) * 7 + math.floor(bl / 40)
                        local tally = cell[8]
                        if not tally then
                            tally = {}
                            cell[8] = tally
                        end
                        local slot = tally[bk]
                        if slot then
                            slot[1] = slot[1] + 1
                            slot[2] = slot[2] + r
                            slot[3] = slot[3] + g
                            slot[4] = slot[4] + bl
                        else
                            tally[bk] = { 1, r, g, bl }
                        end
                    end
                    if stopped then break end
                end

                -- Yield on work done, not on triangles counted, so a frame
                -- never runs long however heavy the triangles happen to be.
                samples = samples + (nu + 1) * (nv + 1) / 2
                if samples - lastYield >= 5000 then
                    lastYield = samples
                    task.wait()
                    if onProgress then onProgress(ji, #jobs, placed, t, triCount) end
                end
                if samples > MODEL_MAX_SAMPLES then
                    stopped = true
                    tooBig = true
                end
            end
            if stopped then break end
        end
        if stopped then break end
    end

    if #order == 0 then return nil, "Nothing was voxelised - the model may be empty" end

    -- Simplify: cap how many different blocks the whole model may use. Two
    -- passes, as the image converter does - tally what every cell would pick
    -- from the full palette, keep the most popular, then match again against
    -- only those. A low cap gives a poster look rather than a muddle.
    if (MODEL.limit or 0) > 0 and MODEL.pal and #MODEL.pal > MODEL.limit then
        local counts = {}
        for i, cell in ipairs(order) do
            local n = math.max(cell[7], 1)
            local name = MODEL.blockFor(
                math.clamp(math.floor(cell[4] / n + 0.5), 0, 255),
                math.clamp(math.floor(cell[5] / n + 0.5), 0, 255),
                math.clamp(math.floor(cell[6] / n + 0.5), 0, 255))
            counts[name] = (counts[name] or 0) + 1
            if i % 4000 == 0 then task.wait() end
        end
        local ranked = {}
        for _, e in ipairs(MODEL.pal) do ranked[#ranked + 1] = e end
        table.sort(ranked, function(a, b)
            return (counts[a.name] or 0) > (counts[b.name] or 0)
        end)
        local kept = {}
        for i = 1, math.min(MODEL.limit, #ranked) do kept[i] = ranked[i] end
        MODEL.pal = kept
        MODEL.match = {}
        MODEL.ditherCache = {}
        limited = #kept
    end

    local blocks = table.create(#order)
    for i, cell in ipairs(order) do
        local n = math.max(cell[7], 1)
        local sr, sg, sb = cell[4], cell[5], cell[6]
        -- take the group that covers most of the cell, not the blend of all
        local tally = cell[8]
        if tally then
            local bestN
            for _, slot in pairs(tally) do
                if not bestN or slot[1] > bestN then
                    bestN, sr, sg, sb = slot[1], slot[2], slot[3], slot[4]
                end
            end
            n = math.max(bestN or n, 1)
        end
        local cr = math.clamp(math.floor(sr / n + 0.5), 0, 255)
        local cg = math.clamp(math.floor(sg / n + 0.5), 0, 255)
        local cb = math.clamp(math.floor(sb / n + 0.5), 0, 255)
        -- At zero blend go straight to the plain match: the dither path keys
        -- its cache on the colour rounded to steps of two, so it would answer
        -- a shade or two off for no reason.
        local name
        if MODEL.dither == false or (MODEL.ditherAmount or 1) <= 0 then
            name = MODEL.blockFor(cr, cg, cb)
        else
            name = ditherBlock(cr, cg, cb, cell[1], cell[2], cell[3])
        end
        blocks[i] = {
            blockType = name,
            upperBlock = false,
            cframe = { cell[1] * 3, cell[2] * 3, cell[3] * 3, 1, 0, 0, 0, 1, 0 },
            parts = {},
        }
        if i % 1500 == 0 then task.wait() end
    end

    return blocks, nil, {
        posed = posedAny,
        tex = m.tex,
        stopped = stopped,
        tooBig = tooBig,
        limited = limited,
        samples = samples,
        jpeg = m.jpegSeen,
        zUp = zUp,
        -- report the size the blocks actually came out, not the model's own
        -- axes, which differ once a Z-up model has been stood up
        size = zUp
            and { math.floor(sx * scale) + 1, math.floor(sz * scale) + 1,
                  math.floor(sy * scale) + 1 }
            or { math.floor(sx * scale) + 1, math.floor(sy * scale) + 1,
                 math.floor(sz * scale) + 1 },
    }
end

-- Called from loadSelectedBuild when the chosen file is a .glb. Results are
-- cached per file and detail level, so flipping Preview Build on and off does
-- not re-voxelise a model every time.
BuilderAPI.loadModelFile = function(name, data)
    local key = name .. "@" .. MODEL.grid
    if MODEL.cache[key] then
        return { blocks = MODEL.cache[key] }
    end

    MODEL.buildPalette()
    notify("Model", "Voxelising " .. name .. " at detail " .. MODEL.grid .. "...", 6, "info")

    -- No status box any more, so progress arrives as a handful of notices at
    -- the quarter marks rather than a running commentary nobody can read.
    local lastMark = 0
    local blocks, err, info = glbToBlocks(data, MODEL.grid,
        function(done, total, cells, tri, tris)
            if not tris or tris <= 0 then return end
            local pct = math.floor(tri / tris * 100)
            local mark = math.floor(pct / 25)
            if mark > lastMark and mark < 4 then
                lastMark = mark
                notify("Model", (mark * 25) .. "% - " .. cells .. " blocks so far", 2, "info")
            end
        end)
    if not blocks then
        notifyErr("Model", err or "Could not read that model", 8)
        return nil
    end

    MODEL.cache[key] = blocks
    local msg = ("%d blocks, %dx%dx%d"):format(#blocks, info.size[1], info.size[2], info.size[3])
    if info.zUp then msg = msg .. "\nStood it up: the model was authored Z-up." end
    if info.posed then msg = msg .. "\nPosed from its skeleton." end

    -- Say plainly where the colours came from. A flat white model has two very
    -- different causes that look the same, and guessing between them wastes
    -- everyone's time.
    local t = info.tex or {}
    local pal = #(MODEL.pal or {})
    local groups = {}
    for g in pairs(MODEL.groups or {}) do groups[#groups + 1] = g end
    table.sort(groups)
    msg = msg .. "\nPalette: " .. pal .. " blocks"
        .. (#groups > 0 and (" (" .. table.concat(groups, ", ") .. ")") or " (all)")
        .. (info.limited and (", simplified to " .. info.limited) or "")

    if (t.ok or 0) > 0 then
        msg = msg .. "\nTextures: " .. t.ok .. " decoded"
            .. (t.sizes and #t.sizes > 0 and (" - " .. table.concat(t.sizes, ", ")) or "")
    end
    if (t.failed or 0) > 0 or (t.other or 0) > 0
        or ((t.ok or 0) == 0 and (t.missing or 0) > 0) then
        msg = msg .. "\nNO TEXTURE COLOUR"
        if (t.failed or 0) > 0 then
            msg = msg .. ": " .. t.failed .. " would not decode"
                .. (t.why and (" (" .. tostring(t.why):sub(1, 90) .. ")") or "")
        elseif (t.other or 0) > 0 then
            msg = msg .. ": " .. t.other .. " in a format that is neither PNG nor JPEG"
        else
            msg = msg .. ": the materials carry no texture"
        end
        msg = msg .. ".\nThose parts fall back to the material's flat colour,"
            .. " which is usually plain white - so the model comes out white."
            .. "\nConvert it with mcconvert/model_to_islands.py instead for"
            .. " full colour."
    end
    if #groups > 0 then
        msg = msg .. "\nModel Palette is restricted - clear it for a textured model."
    end
    if info.tooBig then
        msg = msg .. "\nStopped early: this model needs more sampling than one"
            .. " session should spend. Lower Model Detail and try again."
    elseif info.stopped then
        msg = msg .. "\nHit the " .. MODEL_MAX_CELLS .. " block ceiling; lower Model Detail."
    end
    notifyOK("Model", msg, 8)
    return { blocks = blocks }
end

end


-- ── preview ────────────────────────────────────────────────────────────────
local PREVIEW_FOLDER = "IABImagePreview"
local MAX_PREVIEW = 70000
-- Ceiling on how many blocks one image may resolve to. A 1024-wide heightmap
-- at max height would otherwise run to hundreds of millions of cells and take
-- the client down before it ever got to writing a file.
local MAX_CELLS = 750000

local function clearImagePreview()
    local f = Workspace:FindFirstChild(PREVIEW_FOLDER)
    if f then f:Destroy() end
end

local function loadImage()
    if IMG.url == "" then
        notifyWarn("Image", "Paste a direct .png link first", 4)
        return
    end
    task.spawn(function()
        say("Image", "Downloading...")
        local ok, data = pcall(function() return game:HttpGet(IMG.url) end)
        if not ok or not data or #data == 0 then
            notifyErr("Image", "Download failed. Use a direct .png URL.", 6)
            say("Image", "Download failed.")
            return
        end
        say("Image", "Decoding " .. #data .. " bytes...\nLarge images can take 10-60 seconds. The game may look frozen.")
        local ok2, img = pcall(decodePNG, data)
        if not ok2 then
            -- pcall prefixes "file:line:", which is noise for a URL problem
            local msg = tostring(img):gsub("^.-:%d+:%s*", "")
            notifyErr("Image", msg, 10)
            say("Image Problem", msg)
            return
        end
        IMG.cache = img
        IMG.match = {}
        say("Image", "Loaded " .. img.w .. " x " .. img.h
            .. "\nWill build at " .. IMG.width .. " blocks wide.")
        notifyOK("Image", "Loaded " .. img.w .. "x" .. img.h, 5)
    end)
end

-- Nearest-neighbour sample down to the target width, keeping aspect ratio.
local function sampled()
    local img = IMG.cache
    local tw = math.min(IMG.width, img.w)
    local th = math.max(1, math.floor(img.h * (tw / img.w)))
    local out = {}
    for py = 1, th do
        out[py] = {}
        local sy = math.min(img.h, math.max(1, math.floor((py - 0.5) * img.h / th) + 1))
        for px = 1, tw do
            local sx = math.min(img.w, math.max(1, math.floor((px - 0.5) * img.w / tw) + 1))
            local r, g, b, a = img.get(sx, sy)
            out[py][px] = { r, g, b, a }
        end
        -- rows are up to 1024 px wide now, so yield more often than every 16
        if py % 4 == 0 then task.wait() end
    end
    return out, tw, th
end

-- Resolves the image into world cells. Each entry is {x, y, z, name, colour}.
-- atOrigin keeps it at 0,0,0 instead of anchoring to the cursor - that is what
-- a saved build file wants, since the preview transform places it later.
local function imageCells(atOrigin)
    local grid, tw, th = sampled()

    -- With a block limit set, decide which blocks this image gets to use before
    -- resolving any cells, so every pixel matches against the same reduced set.
    IMG.match = {}
    if IMG.limit and IMG.limit > 0 then
        say("Image", "Picking the best " .. IMG.limit .. " blocks...")
        IMG.chosen = chooseLimitedPalette(grid, tw, th, IMG.limit)
    else
        IMG.chosen = nil
    end

    local ax, ay, az = 0, 0, 0
    if not atOrigin then
        local part = targetPart()
        if part then
            ax, ay, az = toCell(part.Position)
        else
            local _, _, hrp = getCharacterParts()
            if hrp then ax, ay, az = toCell(hrp.Position) end
        end
    end

    local cells = {}
    local n = 0
    -- The row-based yield was fine at 160 wide. At 1024, and with a heightmap
    -- stacking up to 512 blocks per pixel, a single row can be half a million
    -- cells - so pace on the cell count instead, or the client locks up.
    local truncated = false
    for py = 1, th do
        for px = 1, tw do
            local px4 = grid[py][px]
            local r, g, b, a = px4[1], px4[2], px4[3], px4[4]
            if a >= 128 then                       -- skip transparent pixels
                local name, col = blockFor(r, g, b)
                if IMG.mode == "Pixel Art (Wall)" then
                    -- image rows run top-down, world Y runs up
                    n = n + 1
                    cells[n] = { ax + px, ay + (th - py), az, name, col }
                elseif IMG.mode == "Pixel Art (Floor)" then
                    n = n + 1
                    cells[n] = { ax + px, ay, az + py, name, col }
                else
                    -- Heightmap: brightness drives column height
                    local lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
                    local hgt = math.max(1, math.floor(lum * IMG.maxHeight + 0.5))
                    for y = 1, hgt do
                        n = n + 1
                        cells[n] = { ax + px, ay + y, az + py, name, col }
                    end
                end
                if n % 20000 == 0 then
                    say("Image", "Resolving blocks... " .. n)
                    task.wait()
                end
                -- Better a capped build than a frozen client and no build.
                if n >= MAX_CELLS then truncated = true break end
            end
        end
        if truncated then break end
        if py % 8 == 0 then task.wait() end
    end
    if truncated then
        notifyWarn("Image", "Capped at " .. MAX_CELLS .. " blocks - lower the width or height", 8)
    end
    return cells, tw, th, truncated
end

-- The image never became a build file: it could only be placed live, cell by
-- cell. This turns the same cells into the { blockType, cframe } records every
-- other generator writes, so the ghost preview and the builder can take it.
local function imageBlocks()
    local cells, tw, th = imageCells(true)
    local out = {}
    for i, c in ipairs(cells) do
        out[#out + 1] = {
            blockType = c[4],
            -- cells are in block units; files are in studs, 3 per block
            cframe = { c[1] * 3, c[2] * 3, c[3] * 3, 1, 0, 0, 0, 1, 0 },
            parts = {},
        }
        if i % 20000 == 0 then
            say("Image", "Converting to blocks... " .. i .. " / " .. #cells)
            task.wait()
        end
    end
    return out, tw, th
end

local function generateImageFile()
    if not IMG.cache then
        notifyWarn("Image", "Load an image first", 4)
        return
    end
    task.spawn(function()
        say("Image", "Converting to blocks...")
        local blocks, tw, th = imageBlocks()
        if #blocks == 0 then
            notifyWarn("Image", "Nothing to save (all transparent?)", 4)
            say("Image", "Nothing to save - every pixel was transparent.")
            return
        end

        if not isfolder("autoBuilder") then makefolder("autoBuilder") end
        local name = IMG.file
        if name == "" then name = "MyImage" end
        if name:lower():sub(-5) ~= ".json" then name = name .. ".json" end

        say("Image", "Encoding " .. #blocks .. " blocks...\nLarge images can take a while here.")
        task.wait()
        local ok, err = pcall(function()
            writefile("autoBuilder/" .. name, HttpService:JSONEncode({ blocks = blocks }))
        end)
        if not ok then
            notifyErr("Image", "Save failed: " .. tostring(err), 6)
            say("Image", "Save failed:\n" .. tostring(err)
                .. "\n\nIf this is a size problem, lower Build Width and try again.")
            return
        end
        sendSaveWebhook(name)

        selectedFile = name
        savedPreviewTransform = nil
        pcall(function() saveAlignment(name, CFrame.new()) end)
        pcall(function() fileDropdown:Refresh(getFiles(), true) fileDropdown:Set({ name }) end)
        say("Image Saved", #blocks .. " blocks (" .. tw .. " x " .. th .. ")\n-> "
            .. name .. "\nPreview tab: Preview Build, then Start Build.")
        notifyOK("Image", #blocks .. " blocks -> " .. name .. " (selected)", 6)
    end)
end

-- the toggle owns the preview, so put it back when we cannot deliver one
local function previewFailed(msg)
    notifyWarn("Image", msg, 4)
    pcall(function() BuilderAPI.toggles.imagePreview:Set(false) end)
end

local function previewImage()
    if not IMG.cache then previewFailed("Load an image first") return end
    task.spawn(function()
        clearImagePreview()
        say("Image", "Building preview...")
        local cells, tw, th = imageCells()
        if #cells == 0 then
            previewFailed("Nothing to preview (all transparent?)")
            return
        end
        local folder = Instance.new("Folder")
        folder.Name = PREVIEW_FOLDER
        folder.Parent = Workspace
        local drawn = 0
        for i, c in ipairs(cells) do
            if drawn >= MAX_PREVIEW then break end
            local p = Instance.new("Part")
            p.Anchored = true p.CanCollide = false p.CanQuery = false
            p.Size = Vector3.new(3, 3, 3)
            p.Position = Vector3.new(c[1] * 3, c[2] * 3, c[3] * 3)
            p.Color = c[5] or Color3.fromRGB(200, 200, 200)
            p.Material = Enum.Material.SmoothPlastic
            p.Transparency = 0.25
            p.Parent = folder
            drawn = drawn + 1
            if i % 500 == 0 then task.wait() end
        end
        local note = drawn .. " of " .. #cells .. " ghost blocks"
        if drawn < #cells then note = note .. " (preview capped)" end
        say("Preview", note .. "\n" .. tw .. " x " .. th
            .. "\nHappy with it? Press Build. Otherwise Clear Preview.")
        notifyOK("Image Preview", note, 6)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════════
-- Lives on Build rather than Edit: it produces a build file now, so it belongs
-- next to the rest of the build pipeline.
-- Order 1 puts Image above the Save section, which is built earlier.
auto:CreateSection("Image", { Collapsible = true, Column = "right", Order = 1 })

-- Doubles as the status readout; say() writes here. No how-to wall of text -
-- each control has its own hover tooltip.

-- Load and Check ride on the URL field itself rather than being separate
-- controls below it.
auto:CreateInput({
    Name = "Image URL",
    Default = "",
    Actions = {
        { Text = "Load Image", OnClick = function(text)
            if text and text ~= "" then IMG.url = text end
            loadImage()
        end },
        { Text = "Check URL", OnClick = function(text)
            if text and text ~= "" then IMG.url = text end
            if IMG.url == "" then notifyWarn("Image", "Paste a link first", 3) return end
            task.spawn(function()
                say("Checking", IMG.url)
                local ok, data = pcall(function() return game:HttpGet(IMG.url) end)
                if not ok then
                    local msg = tostring(data):gsub("^.-:%d+:%s*", "")
                    say("Check Failed", "The request itself failed:\n" .. msg
                        .. "\nThe host may be blocking the game.")
                    notifyErr("Image", "Request failed", 6)
                    return
                end
                local kind, why = sniffFormat(data)
                if kind == "png" then
                    say("Check OK", "That is a PNG, " .. #data .. " bytes. Press Load Image.")
                    notifyOK("Image", "Valid PNG (" .. #data .. " bytes)", 5)
                else
                    say("Check: " .. kind, why or "Unsupported file type.")
                    notifyWarn("Image", why or ("Got " .. kind), 8)
                end
            end)
        end },
    },
    Callback = function(t) if t and t ~= "" then IMG.url = t end end
})

auto:CreateDropdown({
    Name = "Image Mode",
    Options = { "Pixel Art (Wall)", "Pixel Art (Floor)", "Heightmap Terrain" },
    CurrentOption = { "Pixel Art (Wall)" }, MultipleOptions = false,
    Flag = "IMGMode",
    Callback = function(v) IMG.mode = (typeof(v) == "table") and v[1] or v end
})

auto:CreateDropdown({
    Name = "Palette",
    Options = IMAGE_GROUPS,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "IMGPalette",
    Tooltip = "Which families of blocks the image may use. Pick none to allow all of them.",
    Callback = function(v)
        local set = {}
        if typeof(v) == "table" then
            for _, g in ipairs(v) do set[g] = true end
        elseif v then
            set[v] = true
        end
        IMG.groups = set
        rebuildActivePalette()
    end
})

auto:CreateSlider({
    Name = "Simplify", Range = { 0, 40 }, Increment = 1, CurrentValue = 0,
    Suffix = "types", Flag = "IMGSimple",
    Tooltip = "Cap how many different blocks the whole image uses. 0 is off. Low values give a poster look.",
    Callback = function(v)
        IMG.limit = v
        IMG.match = {}
        IMG.chosen = nil
    end
})

auto:CreateSlider({
    Name = "Build Width", Range = { 8, 1024 }, Increment = 4, CurrentValue = 48,
    Suffix = "blk", Flag = "IMGW",
    Callback = function(v)
        IMG.width = v
        if IMG.cache then
            -- block count grows with the square of the width, so show it: 1024
            -- wide is a different order of magnitude from 160
            local th = math.max(1, math.floor(IMG.cache.h * (math.min(v, IMG.cache.w) / IMG.cache.w)))
            say("Image", "Loaded " .. IMG.cache.w .. " x " .. IMG.cache.h
                .. "\nWill build at " .. v .. " blocks wide (" .. v .. " x " .. th .. ")"
                .. "\nUp to " .. (v * th) .. " blocks before transparent pixels are dropped.")
        end
    end
})

auto:CreateSlider({
    Name = "Heightmap Max Height", Range = { 2, 512 }, Increment = 1, CurrentValue = 24,
    Suffix = "blk", Flag = "IMGH", Callback = function(v) IMG.maxHeight = v end
})

-- One toggle owns the preview: on shows it at the cursor, off clears it.
BuilderAPI.toggles.imagePreview = auto:CreateToggle({
    Name = "Preview Image",
    CurrentValue = false,
    Flag = "IMGPreview",
    Tooltip = "Shows the image as the real blocks it will use, where you are pointing. Turn off to remove it.",
    Callback = function(v)
        if v then
            previewImage()
        else
            clearImagePreview()
            notify("Image", "Preview removed", 2, "info")
        end
    end
})

-- Saving the image build file is driven from the Save section's dropdown now,
-- so it can share the one Build Name box. Exposed for that button to call.
BuilderAPI.generateImage = function(nameOverride)
    if nameOverride and nameOverride ~= "" then IMG.file = nameOverride end
    generateImageFile()
end

end

-- ═══════════════════════════════════════════════════════════════════════════
-- SAVED FILES — one picker for blueprints, presets, palettes, views, scripts
--
-- Each of those used to carry its own name box, save button, load dropdown and
-- refresh button: twenty controls doing one job. They register a handler
-- instead and this drives all of them.
-- ═══════════════════════════════════════════════════════════════════════════
do

local kinds = BuilderAPI.fileKinds
local F = { kind = kinds[1], name = "MySave", current = nil }
local fileDrop, filePara

local kindNames = {}
for _, k in ipairs(kinds) do kindNames[#kindNames + 1] = k.name end

local function refreshList()
    if not F.kind then return end
    local ok, list = pcall(F.kind.list)
    if not ok or type(list) ~= "table" or #list == 0 then list = { "(none saved)" } end
    pcall(function() fileDrop:Refresh(list, true) end)
    pcall(function()
        filePara:Set({
            Title = F.kind.name .. " Files",
            Content = (list[1] == "(none saved)")
                and ("No " .. F.kind.name:lower() .. "s saved yet.")
                or (#list .. " saved. Pick one to load it."),
        })
    end)
end

tabEdit:CreateDivider()

filePara = tabEdit:CreateParagraph({
    Title = "Saved Files",
    Content = "Blueprints, presets, palettes, views and scripts all load from here.",
})

tabEdit:CreateDropdown({
    Name = "File Type",
    Options = kindNames, CurrentOption = { kindNames[1] }, MultipleOptions = false,
    Flag = "FileKind",
    Callback = function(v)
        local n = (typeof(v) == "table") and v[1] or v
        for _, k in ipairs(kinds) do
            if k.name == n then F.kind = k break end
        end
        refreshList()
    end
})

fileDrop = tabEdit:CreateDropdown({
    Name = "Load",
    Options = { "(none saved)" }, CurrentOption = {}, MultipleOptions = false,
    Gear = {
        { Type = "button", Name = "Refresh List", OnClick = function() refreshList() end },
        { Type = "button", Name = "Delete Selected", OnClick = function()
            if not F.current or not F.kind then
                notifyWarn("Saved Files", "Pick a file first", 3)
                return
            end
            local target, dir = F.current, F.kind.dir
            if not dir then
                notifyWarn("Saved Files", "This type cannot be deleted from here", 4)
                return
            end
            confirm("Delete File", "Permanently delete '" .. target .. "'?", "Delete", function()
                local ok = pcall(function()
                    if isfile(dir .. "/" .. target) then delfile(dir .. "/" .. target) end
                end)
                if ok then
                    F.current = nil
                    refreshList()
                    notifyOK("Deleted", target, 4)
                else
                    notifyErr("Delete Failed", target, 4)
                end
            end)
        end },
    },
    Callback = function(v)
        local n = (typeof(v) == "table") and v[1] or v
        if not n or n == "(none saved)" or not F.kind then return end
        F.current = n
        F.kind.load(n)
    end
})

tabEdit:CreateInput({
    Name = "Save As",
    Default = "MySave",
    Callback = function(t) if t and t ~= "" then F.name = t end end
})

tabEdit:CreateButton({
    Name = "Save",
    Tooltip = "Save under the name above, for whichever file type is selected. Views save your current position.",
    Callback = function()
        if not F.kind then return end
        if not F.kind.save then
            notifyWarn("Saved Files",
                F.kind.name .. " files are load-only. Put them in the folder yourself.", 6)
            return
        end
        F.kind.save(F.name)
        refreshList()
    end
})

refreshList()

end

-- ═══════════════════════════════════════════════════════════════════════════
-- EDITOR PANEL — floating side panel of the controls used most while building
--
-- Same idea as the avatar panel: docks beside the window, drag it anywhere.
-- Built from the library's element factory, so these are real controls, not
-- copies - they write to the same state the tabs do.
-- ═══════════════════════════════════════════════════════════════════════════
do

local BA = BuilderAPI
local B, O = BA.B, BA.O

local panel = Duvome:MakeSidePanel({ Name = "Editor", Width = 175, Height = 420, Side = "right" })
BuilderAPI.editorPanel = panel

panel:AddLabel("Blocks")

panel:AddDropdown({
    Name = "Active Block",
    Options = blockDisplayList(), Default = blockDisplayFor("stone"), Search = true,
    Callback = function(v) O.activeBlock = blockIdFor((typeof(v) == "table") and v[1] or v) end
})

panel:AddDivider()
panel:AddLabel("Edit")

panel:AddToggle({
    Name = "Tool Mask",
    Default = false,
    Callback = function(v) O.mask.on = v end
})

panel:AddSlider({
    Name = "Expand / Shrink",
    Min = 1, Max = 16, Increment = 1, Default = 1, ValueName = "blk",
    Callback = function(v) O.expandBy = v end
})

panel:AddSlider({
    Name = "Stack Count",
    Min = 1, Max = 32, Increment = 1, Default = 3, ValueName = "x",
    Callback = function(v) B.stackCount = v end
})

panel:AddSlider({
    Name = "Smear Length",
    Min = 1, Max = 64, Increment = 1, Default = 8, ValueName = "blk",
    Callback = function(v) B.smearLen = v end
})

panel:AddDivider()
panel:AddLabel("History")

panel:AddButton({
    Name = "Undo",
    Callback = function() BA.doUndo() end
})

panel:AddButton({
    Name = "Redo",
    Callback = function() BA.doRedo() end
})

panel:AddButton({
    Name = "Clear Selection",
    Callback = function()
        B.a, B.b, B.clip = nil, nil, nil
        notify("Builder", "Selection dropped", 2, "info")
    end
})

-- the switch that reveals it, on the Edit tab
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SHAPE PANEL — the Structures parameters as a two-column floating panel
--
-- Same live state as the Generate tab's sliders, so a change here refreshes the
-- structure preview exactly as it would there.
-- ═══════════════════════════════════════════════════════════════════════════
do

local shapePanel = Duvome:MakeSidePanel({ Name = "Shape", Width = 200, Height = 420, Side = "right" })
BuilderAPI.shapePanel = shapePanel

-- Which controls matter per shape. Anything not listed is hidden for that
-- shape, so the panel only ever shows what actually affects the result.
local SHAPE_FIELDS = {
    ["Sphere"]         = { "radius", "hollow", "thickness", "rot" },
    ["Dome"]           = { "radius", "hollow", "thickness", "rot" },
    ["Cylinder"]       = { "radius", "height", "hollow", "thickness", "rot" },
    ["Tube / Wall"]    = { "radius", "height", "thickness", "rot" },
    ["Cone"]           = { "radius", "height", "hollow", "rot" },
    ["Pyramid"]        = { "radius", "height", "hollow", "rot" },
    ["Torus (Ring)"]   = { "radius", "thickness", "rot" },
    ["Box"]            = { "radius", "width", "height", "hollow", "thickness", "rot" },
    ["Octahedron"]     = { "radius", "hollow", "rot" },
    ["Spiral Stairs"]  = { "radius", "height", "turns", "width", "rot" },
    ["Landscape"]      = { "radius", "width", "height", "smooth", "seed", "fill", "brush", "rot" },
    ["Square Floor"]   = { "radius", "width", "rot" },
    ["Circle"]         = { "radius", "thickness", "rot" },
}

BuilderAPI.structMode = BuilderAPI.structMode or "Sphere"
local shapeCtl = {}

local function addShapeControls()
    -- Block choice lives on the panel too, so each shape can be textured
    -- without leaving it.
    shapeCtl.brush = shapePanel:AddDropdown({
        Name = "Brush Mode",
        Options = { "Raise", "Lower", "Smooth", "Flatten" },
        Default = "Raise",
        Callback = function(v)
        terraMode = (typeof(v) == "table") and v[1] or v
    end
    })
    shapeCtl.block = shapePanel:AddDropdown({
        Name = "Block",
        Options = blockDisplayList(), Default = blockDisplayFor("grass"), Search = true,
        Callback = function(v) structSelectedBlock = blockIdFor(v) end
    })
    shapeCtl.radius = shapePanel:AddSlider({
        Name = "Radius / Length", Min = 3, Max = 450, Increment = 3, Default = 30, ValueName = "blk",
        Callback = function(v) structRadius = v structHeightmap = nil BuilderAPI.structRefresh() end })
    shapeCtl.width = shapePanel:AddSlider({
        Name = "Width", Min = 3, Max = 450, Increment = 3, Default = 30, ValueName = "blk",
        Callback = function(v) structWidth = v structHeightmap = nil BuilderAPI.structRefresh() end })
    shapeCtl.height = shapePanel:AddSlider({
        Name = "Height", Min = 3, Max = 450, Increment = 3, Default = 30, ValueName = "blk",
        Callback = function(v) structHeight = v structHeightmap = nil BuilderAPI.structRefresh() end })
    shapeCtl.thickness = shapePanel:AddSlider({
        Name = "Thickness", Min = 1, Max = 10, Increment = 1, Default = 1, ValueName = "blk",
        Callback = function(v) structThickness = v BuilderAPI.structRefresh() end })
    shapeCtl.turns = shapePanel:AddSlider({
        Name = "Spiral Turns", Min = 1, Max = 40, Increment = 1, Default = 4,
        Callback = function(v) structTurns = v / 4 BuilderAPI.structRefresh() end })
    shapeCtl.smooth = shapePanel:AddSlider({
        Name = "Smoothness", Min = 5, Max = 200, Increment = 1, Default = 25,
        Callback = function(v) structSmooth = v structHeightmap = nil BuilderAPI.structRefresh() end })
    shapeCtl.seed = shapePanel:AddSlider({
        Name = "Seed", Min = 1, Max = 10000, Increment = 1, Default = 1,
        Callback = function(v) structSeed = v structHeightmap = nil BuilderAPI.structRefresh() end })
    shapeCtl.hollow = shapePanel:AddToggle({
        Name = "Hollow", Default = true,
        Callback = function(v) structHollow = v BuilderAPI.structRefresh() end })
    shapeCtl.fill = shapePanel:AddToggle({
        Name = "Fill Steps", Default = false,
        Callback = function(v) structFillSteps = v BuilderAPI.structRefresh() end })
    shapeCtl.rotX = shapePanel:AddSlider({
        Name = "Tilt (X)", Min = 0, Max = 360, Increment = 90, Default = 0, ValueName = "deg",
        Callback = function(v) structRX = v BuilderAPI.structRefresh() end })
    shapeCtl.rotY = shapePanel:AddSlider({
        Name = "Spin (Y)", Min = 0, Max = 360, Increment = 90, Default = 0, ValueName = "deg",
        Callback = function(v) structRY = v BuilderAPI.structRefresh() end })
    shapeCtl.rotZ = shapePanel:AddSlider({
        Name = "Roll (Z)", Min = 0, Max = 360, Increment = 90, Default = 0, ValueName = "deg",
        Callback = function(v) structRZ = v BuilderAPI.structRefresh() end })
end
addShapeControls()

-- Show only the fields the current shape uses, and retitle the panel.
function BuilderAPI.shapePanelSync()
    local mode = BuilderAPI.structMode or "Sphere"
    local fields = SHAPE_FIELDS[mode] or { "radius", "height", "hollow", "rot" }
    local want = {}
    for _, f in ipairs(fields) do want[f] = true end
    local map = {
        radius = shapeCtl.radius, width = shapeCtl.width, height = shapeCtl.height,
        thickness = shapeCtl.thickness, turns = shapeCtl.turns, smooth = shapeCtl.smooth,
        seed = shapeCtl.seed, hollow = shapeCtl.hollow, fill = shapeCtl.fill,
        brush = shapeCtl.brush,
    }
    for key, ctl in pairs(map) do
        if ctl and ctl.SetVisible then pcall(function() ctl:SetVisible(want[key] == true) end) end
    end
    for _, ctl in ipairs({ shapeCtl.rotX, shapeCtl.rotY, shapeCtl.rotZ }) do
        if ctl and ctl.SetVisible then pcall(function() ctl:SetVisible(want.rot == true) end) end
    end
    pcall(function() shapePanel:SetTitle(mode) end)
end
BuilderAPI.shapePanelSync()

end

do


end

-- ═══════════════════════════════════════════════════════════════════════════
-- BUILD THUMBNAIL — spinning 3D preview of the selected build file
--
-- Renders the file's blocks into a ViewportFrame on a side panel, so you can
-- see what a file is before building it. Nothing is placed in the world.
-- ═══════════════════════════════════════════════════════════════════════════
do

local BS = 3

local thumbPanel = Duvome:MakeSidePanel({ Name = "Thumbnail", Width = 220, Height = 300, Side = "right" })
BuilderAPI.thumbPanel = thumbPanel

local host = thumbPanel:Container()

local viewport = Instance.new("ViewportFrame")
viewport.BackgroundColor3 = Color3.fromRGB(8, 3, 16)
viewport.BackgroundTransparency = 0.15
viewport.BorderSizePixel = 0
viewport.Size = UDim2.new(1, 0, 0, 250)
viewport.LayoutOrder = 1
viewport.Ambient = Color3.fromRGB(190, 190, 200)
viewport.LightColor = Color3.fromRGB(255, 255, 255)
viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
viewport.Parent = host
Instance.new("UICorner").Parent = viewport

local cam = Instance.new("Camera")
cam.FieldOfView = 45
viewport.CurrentCamera = cam
cam.Parent = viewport

local world = Instance.new("Model")
world.Parent = viewport

local T = { spin = 0, radius = 30, height = 12, conn = nil, count = 0, name = nil,
            open = false, speed = 0.4 }

local infoLabel = Instance.new("TextLabel")
infoLabel.BackgroundTransparency = 1
infoLabel.Size = UDim2.new(1, 0, 0, 30)
infoLabel.LayoutOrder = 2
infoLabel.Font = Enum.Font.GothamSemibold
infoLabel.TextSize = 11
infoLabel.TextColor3 = Color3.fromRGB(210, 175, 255)
infoLabel.TextWrapped = true
infoLabel.Text = "Pick a build file, then press Render."
infoLabel.Parent = host

-- ── block colours ──────────────────────────────────────────────────────────
local colourCache = {}
local function colourFor(name)
    local hit = colourCache[name]
    if hit then return hit end
    local col = Color3.fromRGB(160, 160, 165)
    local model = BuilderAPI.findBlockTemplate and BuilderAPI.findBlockTemplate(name)
    if model then
        if model:IsA("BasePart") then
            col = model.Color
        else
            -- area-weighted average, same approach as the Colour tab
            local r, g, b, w = 0, 0, 0, 0
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BasePart") then
                    local sz = d.Size
                    local a = math.max(sz.X * sz.Y + sz.Y * sz.Z + sz.X * sz.Z, 0.001)
                    r, g, b, w = r + d.Color.R * a, g + d.Color.G * a, b + d.Color.B * a, w + a
                end
            end
            if w > 0 then col = Color3.new(r / w, g / w, b / w) end
        end
    end
    colourCache[name] = col
    return col
end

-- ── render ─────────────────────────────────────────────────────────────────
local function clearWorld()
    world:ClearAllChildren()
    T.count = 0
end

-- Clone the real model for a block type, stripped of anything a viewport
-- cannot use. Cached, because cloning per block would be brutal.
local templateCache = {}
-- Block names are not always what a build file calls them, and templates live
-- in two places: blocks/<name> and Blocks/<name>/Root. Try both.
local BLOCK_ALIASES = { dirt = "soil" }

local function findBlockTemplate(name)
    local want = BLOCK_ALIASES[name] or name
    local lower = ReplicatedStorage:FindFirstChild("blocks")
    local hit = lower and lower:FindFirstChild(want)
    if hit then return hit end
    local upper = ReplicatedStorage:FindFirstChild("Blocks")
    local entry = upper and upper:FindFirstChild(want)
    if entry then
        return entry:FindFirstChild("Root") or entry
    end
    return nil
end

BuilderAPI.findBlockTemplate = findBlockTemplate

local function templateFor(name)
    local hit = templateCache[name]
    if hit ~= nil then return hit or nil end
    local src = findBlockTemplate(name)
    if not src then templateCache[name] = false return nil end

    local ok, clone = pcall(function() return src:Clone() end)
    if not ok or not clone then templateCache[name] = false return nil end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
        elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript")
            or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Fire") then
            d:Destroy()
        end
    end
    if clone:IsA("BasePart") then
        clone.Anchored = true clone.CanCollide = false
    end
    templateCache[name] = clone
    return clone
end

local function render()
    -- A model is shown as the model, not as the blocks it becomes. That is
    -- what you actually want to check before converting. Falls back to the
    -- block render when the executor has no EditableMesh.
    if isModelFile(selectedFile) then
        local path = filePathFor(selectedFile)
        if isfile(path) then
            infoLabel.Text = "Building the mesh..."
            clearWorld()
            local part, why, info
            local ok = pcall(function()
                part, why, info = MODEL.meshFromGLB(readfile(path))
            end)
            if ok and part then
                part.Anchored = true
                part.CanCollide = false
                part.CanQuery = false
                part.Parent = world
                pcall(function() part:PivotTo(CFrame.new(0, 0, 0)) end)
                -- same orbit the block view uses, sized to the mesh
                local span = math.max(part.Size.X, part.Size.Y, part.Size.Z, 1)
                T.count = (info and info.triangles) or 0
                T.name = selectedFile
                T.radius = span * 1.5 + 10
                T.height = span * 0.55 + 5
                infoLabel.Text = selectedFile .. "\n"
                    .. T.count .. " triangles"
                    .. ((info and info.posed) and ", posed from its skeleton" or "")
                notifyOK("Thumbnail", "Showing the model itself", 3)
                return
            end
            notifyWarn("Thumbnail", "Showing blocks instead - " .. tostring(why or "no mesh support"), 6)
        end
    end

    local data = loadSelectedBuild()
    if not data or not data.blocks or #data.blocks == 0 then
        notifyWarn("Thumbnail", "Pick a build file first", 3)
        infoLabel.Text = "No file selected."
        return
    end

    clearWorld()
    local blocks = data.blocks
    local total = #blocks
    if total > 15000 then
        notifyWarn("Thumbnail", total .. " blocks - this may take a moment", 5)
    end
    infoLabel.Text = "Rendering " .. total .. " blocks..."

    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local made = 0

    -- every block, using its real model so textures and shape come through
    for i = 1, total do
        local b = blocks[i]
        local cf = b.cframe
        if cf and cf[1] then
            local x, y, z = cf[1], cf[2], cf[3]
            local tpl = templateFor(b.blockType)
            local inst
            if tpl then
                inst = tpl:Clone()
                if inst:IsA("BasePart") then
                    inst.CFrame = CFrame.new(x, y, z)
                else
                    pcall(function() inst:PivotTo(CFrame.new(x, y, z)) end)
                end
                -- a cloned slab shows its bottom half whatever it was flagged
                if b.upperBlock then
                    pcall(function() showSlabHalf(inst, true) end)
                end
            else
                -- only when the game has no model for that id
                inst = Instance.new("Part")
                inst.Anchored = true
                inst.CanCollide = false
                inst.Size = Vector3.new(BS, BS, BS)
                inst.CFrame = CFrame.new(x, y, z)
                inst.Color = colourFor(b.blockType)
                inst.Material = Enum.Material.SmoothPlastic
            end
            inst.Parent = world
            made = made + 1

            if x < minX then minX = x end
            if x > maxX then maxX = x end
            if y < minY then minY = y end
            if y > maxY then maxY = y end
            if z < minZ then minZ = z end
            if z > maxZ then maxZ = z end
        end
        if i % 250 == 0 then task.wait() end
    end

    if made == 0 then
        infoLabel.Text = "That file has no placeable blocks."
        return
    end

    T.count = made
    T.name = (selectedFile or "build"):gsub("%.json$", "")
    local centre = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
    local span = math.max(maxX - minX, maxY - minY, maxZ - minZ, BS)

    -- park on the origin so the camera can orbit a fixed point
    for _, inst in ipairs(world:GetChildren()) do
        if inst:IsA("BasePart") then
            inst.CFrame = inst.CFrame - centre
        else
            pcall(function() inst:PivotTo(inst:GetPivot() - centre) end)
        end
    end

    T.radius = span * 1.5 + 10
    T.height = span * 0.55 + 5
    infoLabel.Text = T.name .. "\n" .. made .. " blocks"
    notifyOK("Thumbnail", T.name .. " - " .. made .. " blocks", 3)
end

-- ── spin ───────────────────────────────────────────────────────────────────
local function aimCamera()
    local x = math.cos(T.spin) * T.radius
    local z = math.sin(T.spin) * T.radius
    cam.CFrame = CFrame.new(Vector3.new(x, T.height, z), Vector3.new(0, 0, 0))
end

local function stopSpin()
    if T.conn then T.conn:Disconnect() T.conn = nil end
end

-- One connection, created only while the panel is open. The speed slider fires
-- its callback as the UI is built, so without the open check this would spin a
-- hidden viewport for the whole session.
local function applySpin()
    stopSpin()
    if not T.open then return end
    aimCamera()
    if T.speed <= 0 then return end
    T.conn = RunService.RenderStepped:Connect(function(dt)
        T.spin = (T.spin + dt * T.speed) % (math.pi * 2)
        aimCamera()
    end)
end

-- ── controls ───────────────────────────────────────────────────────────────
-- opened from the Build tab toggle, which is created earlier in the file
function BuilderAPI.thumbOpen(on)
    T.open = on
    if on then
        thumbPanel:Show()
        applySpin()
        task.spawn(render)
    else
        thumbPanel:Hide()
        stopSpin()
    end
end

end

-- ═══════════════════════════════════════════════════════════════════════════
-- CITY AND PLATFORM PANELS
-- The generators carry a lot of knobs; these move them off the tab.
-- ═══════════════════════════════════════════════════════════════════════════
do

local cityPanel = Duvome:MakeSidePanel({ Name = "City", Width = 200, Height = 420, Side = "right" })
BuilderAPI.cityPanel = cityPanel

cityPanel:AddLabel("Layout")
for _, sl in ipairs({
    { "Lots Across", 1, 8, 1, 3, function(v) cityLotsX = v end },
    { "Lots Deep",   1, 8, 1, 3, function(v) cityLotsZ = v end },
    { "Lot Width",   7, 25, 1, 13, function(v) cityLotW = v end },
    { "Lot Depth",   7, 25, 1, 13, function(v) cityLotD = v end },
    { "Road Width",  1, 8, 1, 3, function(v) cityRoadW = v end },
}) do
    cityPanel:AddSlider({ Name = sl[1], Min = sl[2], Max = sl[3], Increment = sl[4],
        Default = sl[5], ValueName = "blk", Callback = sl[6] })
end

cityPanel:AddDivider()
cityPanel:AddLabel("Houses")
cityPanel:AddSlider({ Name = "Min Height", Min = 3, Max = 30, Increment = 1, Default = 5,
    ValueName = "blk", Callback = function(v) cityMinH = v end })
cityPanel:AddSlider({ Name = "Max Height", Min = 3, Max = 30, Increment = 1, Default = 11,
    ValueName = "blk", Callback = function(v) cityMaxH = v end })
cityPanel:AddSlider({ Name = "City Seed", Min = 1, Max = 10000, Increment = 1, Default = 1,
    Callback = function(v) citySeed = v end })

cityPanel:AddDivider()
cityPanel:AddLabel("Terrain")
cityPanel:AddToggle({ Name = "On Landscape", Default = false,
    Callback = function(v) cityLandscape = v end })
cityPanel:AddSlider({ Name = "Terrain Height", Min = 3, Max = 60, Increment = 3, Default = 12,
    ValueName = "blk", Callback = function(v) cityTerrainH = v end })

local platPanel = Duvome:MakeSidePanel({ Name = "Platform", Width = 200, Height = 300, Side = "right" })
BuilderAPI.platPanel = platPanel

platPanel:AddSlider({ Name = "Tile Size", Min = 11, Max = 121, Increment = 2, Default = 41,
    ValueName = "blk", Callback = function(v) platSize = v end })
platPanel:AddSlider({ Name = "Seed", Min = 1, Max = 10000, Increment = 1, Default = 1,
    Callback = function(v) platSeed = v end })
platPanel:AddSlider({ Name = "Density", Min = 10, Max = 90, Increment = 5, Default = 50,
    ValueName = "%%", Callback = function(v) platDensity = v / 100 end })
platPanel:AddToggle({ Name = "Diagonal Symmetry", Default = true,
    Callback = function(v) platMirrorDiag = v end })
platPanel:AddDivider()
platPanel:AddButton({ Name = "Preview Pattern", Callback = function()
        task.spawn(function()
            notify("Generating", "Building " .. platStyle .. " pattern...", 3)
            local blocks = platGenerate()
            if #blocks == 0 then notify("Empty", "Nothing generated", 3) return end
            platStats:Set({ Title = "Pattern Stats", Content = platStyle .. " · " .. platSize .. "x" .. platSize .. " · " .. #blocks .. " blocks" })
            showThumbnail(blocks, platStyle .. " Platform")
        end)
    end })

end

-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCK DESTROYER
--
-- IGD's version fires three hits at a block and moves on regardless, so tough
-- blocks survive and the pass has to be repeated. This one re-hits until the
-- block is actually gone from the world, then advances.
-- ═══════════════════════════════════════════════════════════════════════════
do

local D = BuilderAPI.destroyer

local hitRemote
pcall(function()
    hitRemote = ReplicatedStorage
        :WaitForChild("rbxts_include"):WaitForChild("node_modules")
        :WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out")
        :WaitForChild("_NetManaged"):WaitForChild("CLIENT_BLOCK_HIT_REQUEST")
end)

local function vcreate(x, y, z)
    if vector and vector.create then return vector.create(x, y, z) end
    return Vector3.new(x, y, z)
end

local function hit(part)
    if not (hitRemote and part) then return end
    pcall(function()
        hitRemote:InvokeServer({
            Xoeoxuqilfgenamojfjmj = "\7\240\159\164\163\240\159\164\161\7\n\7\n\7\nohIstskUiftvgjy",
            part = part, block = part,
            norm = vcreate(-3502.331787109375, 39.44426345825195, -3521.013671875),
            pos = vcreate(0.9916929006576538, 0.07807211577892303, -0.10222448408603668),
        })
    end)
end

-- gone when the instance leaves the Blocks folder
local function stillThere(inst)
    return inst and inst.Parent ~= nil
end

-- inSelectionBox lives in a closed scope, so test containment directly
local function insideBox(box, p)
    local half = box.Size / 2
    local c = box.Position
    return p.X >= c.X - half.X and p.X <= c.X + half.X
       and p.Y >= c.Y - half.Y and p.Y <= c.Y + half.Y
       and p.Z >= c.Z - half.Z and p.Z <= c.Z + half.Z
end

local function collect()
    local folder = getBlocksFolder()
    if not folder then return nil, "No island found near you" end

    local wantTypes = D.types
    local anyType = true
    for _ in pairs(wantTypes) do anyType = false break end

    -- A brush selection is an explicit list of blocks, so it wins over the box:
    -- paint exactly what you want gone, then run the destroyer.
    if D.brushOnly then
        if blockSelCount == 0 then
            return nil, "Paint blocks with the Block Brush first, or switch off Brush Selection"
        end
        local picked = {}
        for root in pairs(selectedBlocks) do
            if root and root.Parent and (anyType or wantTypes[root.Name]) then
                if root:IsA("BasePart") then
                    picked[#picked + 1] = root
                else
                    for _, p in ipairs(visualParts(root)) do picked[#picked + 1] = p end
                end
            end
        end
        return picked
    end

    local box = D.boxOnly and selBoxPart or nil
    if D.boxOnly and not box then
        return nil, "Turn Show Selection Box on, or switch off Selection Box Only"
    end

    local wantAll = true
    for _ in pairs(D.types) do wantAll = false break end

    local out = {}
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "bedrock" and part.Name ~= "portalToSpawn" then
            if wantAll or D.types[part.Name] then
                if not box or insideBox(box, part.Position) then
                    out[#out + 1] = part
                end
            end
        end
    end
    return out
end

function D.run()
    if D.running then
        notifyWarn("Destroyer", "Already running", 3)
        return
    end
    if not hitRemote then
        notifyErr("Destroyer", "Block hit remote not found", 5)
        return
    end

    task.spawn(function()
        D.running, D.abort = true, false
        local targets, err = collect()
        if not targets then
            notifyWarn("Destroyer", err, 5)
            D.running = false
            pcall(function() BuilderAPI.toggles.destroy:Set(false) end)
            return
        end
        if #targets == 0 then
            notifyWarn("Destroyer", "Nothing matched inside the box", 4)
            D.running = false
            pcall(function() BuilderAPI.toggles.destroy:Set(false) end)
            return
        end

        notify("Destroyer", "Breaking " .. #targets .. " blocks...", 3, "info")
        local started = tick()
        local broken, stubborn = 0, 0

        for i, part in ipairs(targets) do
            if D.abort then break end
            if stillThere(part) then
                local tries = 0
                repeat
                    for _ = 1, D.hits do
                        if not stillThere(part) then break end
                        hit(part)
                        if D.hitGap > 0 then task.wait(D.hitGap / 1000) end
                    end
                    tries = tries + 1
                    -- give the server a moment to remove it before judging
                    if stillThere(part) then task.wait(0.05) end
                until (not D.confirm) or (not stillThere(part)) or tries >= D.maxTries or D.abort

                if stillThere(part) then stubborn = stubborn + 1 else broken = broken + 1 end
            end

            -- randomised gap so the request pattern is not perfectly uniform
            local lo = math.min(D.minDelay, D.maxDelay)
            local hi = math.max(D.minDelay, D.maxDelay)
            local wait = (hi > 0) and (math.random(lo, hi) / 1000) or 0
            if wait > 0 then task.wait(wait) end

            if i % 25 == 0 then
                pcall(function()
                    progressParagraph:Set({
                        Title = "Build Progress",
                        Content = "Destroying " .. i .. " / " .. #targets
                            .. "  (" .. broken .. " broken)"
                    })
                end)
            end
        end

        local secs = math.floor((tick() - started) * 10) / 10
        D.running = false
        pcall(function() BuilderAPI.toggles.destroy:Set(false) end)
        if stubborn > 0 then
            notifyWarn("Destroyer", broken .. " broken, " .. stubborn .. " survived in " .. secs .. "s", 6)
        else
            notifyOK("Destroyer", broken .. " blocks in " .. secs .. "s", 5)
        end
    end)
end

Duvome:AddWatch("Destroyer", function() return D.running end)

end

-- ═══════════════════════════════════════════════════════════════════════════
-- PREVIEW PANEL — ghost settings and the move handles, off the tab
-- ═══════════════════════════════════════════════════════════════════════════
do

local previewPanel = Duvome:MakeSidePanel({ Name = "Required Blocks", Width = 210, Height = 320, Side = "right" })
BuilderAPI.previewPanel = previewPanel

-- ── Required blocks ────────────────────────────────────────────────────────
previewPanel:AddButton({
    Name = "Show Required Blocks",
    Tooltip = "Checks what blocks this build needs and how many you are short.",
    Callback = function()
        if BuilderAPI.scanRequired then BuilderAPI.scanRequired() end
    end })

local reqSummary = previewPanel:AddParagraph("Required", "Press Show Required Blocks to check.")

previewPanel:AddSlider({
    Name = "Hide Under", Min = 1, Max = 64, Increment = 1, Default = 1, ValueName = "blk",
    Tooltip = "Hide blocks the build barely uses. Set it to 1 to see them all.",
    Callback = function(v)
        requiredMinCount = v
        -- only re-render a list that already exists; scanning from here would
        -- open the panel, and this fires when the saved config is restored
        if BuilderAPI.scanRequired and requiredBlocksList and #requiredBlocksList > 0 then
            BuilderAPI.scanRequired()
        end
    end })

-- One dropdown of the listed entries plus a Remove button, rather than a row of
-- buttons per entry - that filled the panel with controls.
local reqPick = nil
local reqDrop = previewPanel:AddDropdown({
    Name = "Pick Entry",
    Options = { "Scan first" }, Default = "Scan first", Search = true,
    -- the required list runs long; five visible rows was not enough to work with
    MaxElements = 12,
    Tooltip = "Pick a line from the list so you can do something with it.",
    Callback = function(v) reqPick = (typeof(v) == "table") and v[1] or v end })

previewPanel:AddButton({
    Name = "Remove Entry",
    Tooltip = "Takes that line off the list. If you swapped that block for another, this undoes the swap. If you did not, it takes that block out of the build.",
    Callback = function()
        if not reqPick or reqPick == "Scan first" then
            notifyWarn("Required Blocks", "Pick an entry first", 3)
            return
        end
        local e
        for _, r in ipairs(requiredBlocksList or {}) do
            if r.label == reqPick then e = r break end
        end
        if not e then
            notifyWarn("Required Blocks", "That entry is no longer listed", 3)
            return
        end
        if e.from then
            confirm("Remove Replacement",
                "Stop replacing " .. resolveBlockDisplayName(e.from)
                    .. " with " .. e.name .. "?",
                "Remove", function()
                    blockReplacements[e.from] = nil
                    notifyOK("Replacement Removed", resolveBlockDisplayName(e.from) .. " left as-is", 4)
                    if BuilderAPI.scanRequired then BuilderAPI.scanRequired() end
                end)
        else
            confirm("Remove Entry",
                "Drop every " .. e.name .. " from this build? It leaves the list"
                    .. " and the preview, and will not be placed.",
                "Remove", function()
                    requiredHidden[e.id] = true
                    if not omittedTypes[e.id] then
                        omittedTypes[e.id] = true
                        omittedTypeCount = omittedTypeCount + 1
                    end
                    -- clear it out of the ghost that is already on screen, so
                    -- the preview matches the build without a re-render
                    if previewModel and previewModel.Parent then
                        for _, d in ipairs(previewModel:GetChildren()) do
                            if d.Name ~= "PreviewRoot" and d.Name ~= "PreviewBBox"
                                and effectiveType(d.Name) == e.id then
                                pcall(function() d:Destroy() end)
                            end
                        end
                    end
                    if lastPreviewBlocks then
                        lastPreviewBlocks = dropOmittedBlocks(lastPreviewBlocks)
                    end
                    notifyOK("Removed", e.name .. " dropped from the build", 4)
                    if BuilderAPI.scanRequired then BuilderAPI.scanRequired() end
                end)
        end
    end })

previewPanel:AddButton({
    Name = "Unhide All",
    Tooltip = "Puts back everything you took off the list.",
    Callback = function()
        requiredHidden = {}
        omittedTypes = {}
        omittedTypeCount = 0
        notify("Required Blocks", "Removed rows and their blocks restored", 4, "info")
        if BuilderAPI.scanRequired then BuilderAPI.scanRequired() end
    end })


-- Fills the summary and the picker from requiredBlocksList.
BuilderAPI.renderRequired = function(summaryText)
    pcall(function()
        local list = requiredBlocksList or {}
        local opts = {}
        for _, e in ipairs(list) do
            local label = e.name
            if e.from then label = resolveBlockDisplayName(e.from) .. " -> " .. e.name end
            label = label .. "   " .. e.have .. "/" .. e.need
            e.label = label
            opts[#opts + 1] = label
        end
        if #opts == 0 then opts = { "Nothing listed" } end
        -- the entry that was just acted on is gone from the list, so stop
        -- pointing Remove Entry at it
        if reqPick and not table.find(opts, reqPick) then reqPick = nil end
        reqDrop:Refresh(opts, true)
        reqSummary:Set(tostring(summaryText or ""))
    end)
end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- OBJECT PANEL — copy, move and delete parts of a preview
-- ═══════════════════════════════════════════════════════════════════════════
-- These act on what you have selected in a preview, so the ghost has to be
-- solid to work with: at any transparency above zero you cannot see or click
-- what you are picking, and every one of these would be a guess.
do

local objectPanel = Duvome:MakeSidePanel({ Name = "Objects", Width = 210, Height = 400, Side = "right" })
BuilderAPI.objectPanel = objectPanel

local function ready()
    if not previewModel or not previewModel.Parent then
        notifyWarn("Objects", "Turn on Preview Build first", 4)
        return false
    end
    if previewTransparency > 0 then
        notifyWarn("Objects", "Set Transparency to 0 first - the ghost has to be solid", 6)
        return false
    end
    return true
end

local function haveSelection()
    if blockSelCount == 0 then
        notifyWarn("Objects", "Nothing picked. Use the brush or Select Box Contents", 5)
        return false
    end
    return true
end

-- The blocks currently picked, as plain entries anchored to their own corner.
local function selectionBlocks()
    local out = {}
    for part in pairs(selectedBlocks) do
        local key = part:GetAttribute("SrcKey")
        local ok, pos = pcall(function()
            return part:IsA("BasePart") and part.Position or part:GetPivot().Position
        end)
        if ok and pos then
            out[#out + 1] = {
                blockType = part.Name,
                upperBlock = false,
                pos = pos,
                key = key,
            }
        end
    end
    return out
end

objectPanel:AddParagraph("Objects",
    "Pick blocks in a preview with the brush or the selection box, then use these.")

objectPanel:AddButton({
    Name = "Duplicate",
    Tooltip = "Makes a second copy of what you picked, one step to the side. Move it where you want with the arrows.",
    Callback = function()
        if not ready() or not haveSelection() then return end
        local picked = selectionBlocks()
        local step = objStep or 3
        local made = 0
        for _, b in ipairs(picked) do
            local part = Instance.new("Part")
            part.Name = b.blockType
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = true
            part.CastShadow = false
            part.Material = Enum.Material.SmoothPlastic
            part.Size = Vector3.new(previewBlockSize, previewBlockSize, previewBlockSize)
            part.CFrame = CFrame.new(b.pos + Vector3.new(step, 0, 0))
            part.Color = colorForBlockType(b.blockType)
            part:SetAttribute("GhostPreview", true)
            part.Parent = previewModel
            made = made + 1
            if made % 400 == 0 then task.wait() end
        end
        notifyOK("Duplicated", made .. " blocks copied one step across", 4)
    end })

objectPanel:AddButton({
    Name = "Delete",
    Tooltip = "Removes what you picked from the preview. The build will skip those blocks too.",
    Callback = function()
        if not ready() or not haveSelection() then return end
        local n = blockSelCount
        confirm("Delete Blocks", "Remove " .. n .. " block(s) from this build?",
            "Delete", function()
                local gone = deleteSelectedFromPreview()
                notifyOK("Deleted", gone .. " blocks removed", 4)
            end)
    end })

objectPanel:AddDivider()

objectPanel:AddSlider({
    Name = "Move Step", Min = 3, Max = 30, Increment = 3, Default = 3, ValueName = "studs",
    Tooltip = "How far one nudge moves things. 3 studs is one block.",
    Callback = function(v) objStep = v end })

-- Nudging: one row of directions rather than six separate buttons.
for _, d in ipairs({
    { "Move Left",   -1,  0,  0 }, { "Move Right",  1, 0, 0 },
    { "Move Up",      0,  1,  0 }, { "Move Down",   0, -1, 0 },
    { "Move Forward", 0,  0, -1 }, { "Move Back",   0,  0, 1 },
}) do
    objectPanel:AddButton({
        Name = d[1],
        Callback = function()
            if not ready() or not haveSelection() then return end
            local step = objStep or 3
            local shift = Vector3.new(d[2] * step, d[3] * step, d[4] * step)
            for part in pairs(selectedBlocks) do
                pcall(function()
                    if part:IsA("BasePart") then
                        part.CFrame = part.CFrame + shift
                    else
                        part:PivotTo(part:GetPivot() + shift)
                    end
                end)
            end
        end })
end

objectPanel:AddDivider()

objectPanel:AddButton({
    Name = "Rotate 90",
    Tooltip = "Spins what you picked a quarter turn around its own middle.",
    Callback = function()
        if not ready() or not haveSelection() then return end
        local sum, n = Vector3.new(), 0
        for part in pairs(selectedBlocks) do
            local ok, pos = pcall(function()
                return part:IsA("BasePart") and part.Position or part:GetPivot().Position
            end)
            if ok and pos then sum = sum + pos n = n + 1 end
        end
        if n == 0 then return end
        local centre = sum / n
        local turn = CFrame.Angles(0, math.rad(90), 0)
        for part in pairs(selectedBlocks) do
            pcall(function()
                local cf = part:IsA("BasePart") and part.CFrame or part:GetPivot()
                local moved = CFrame.new(centre) * turn * CFrame.new(-centre) * cf
                -- keep it on the block grid after turning
                local p = moved.Position
                local snapped = CFrame.new(
                    math.floor(p.X / 3 + 0.5) * 3,
                    math.floor(p.Y / 3 + 0.5) * 3,
                    math.floor(p.Z / 3 + 0.5) * 3) * moved.Rotation
                if part:IsA("BasePart") then part.CFrame = snapped
                else part:PivotTo(snapped) end
            end)
        end
        notify("Rotated", n .. " blocks rotated", 3, "info")
    end })

objectPanel:AddButton({
    Name = "Mirror",
    Tooltip = "Flips what you picked left to right.",
    Callback = function()
        if not ready() or not haveSelection() then return end
        local sum, n = Vector3.new(), 0
        for part in pairs(selectedBlocks) do
            local ok, pos = pcall(function()
                return part:IsA("BasePart") and part.Position or part:GetPivot().Position
            end)
            if ok and pos then sum = sum + pos n = n + 1 end
        end
        if n == 0 then return end
        local cx = sum.X / n
        for part in pairs(selectedBlocks) do
            pcall(function()
                local cf = part:IsA("BasePart") and part.CFrame or part:GetPivot()
                local p = cf.Position
                local flipped = CFrame.new(2 * cx - p.X, p.Y, p.Z) * cf.Rotation
                if part:IsA("BasePart") then part.CFrame = flipped
                else part:PivotTo(flipped) end
            end)
        end
        notify("Mirrored", n .. " blocks flipped", 3, "info")
    end })

objectPanel:AddDivider()

objectPanel:AddButton({
    Name = "Save Selection",
    Tooltip = "Saves just what you picked as its own build file.",
    Callback = function()
        if not haveSelection() then return end
        task.spawn(function() saveSelectedBrush() end)
    end })

objectPanel:AddButton({
    Name = "Clear Selection",
    Callback = function()
        clearBlockSelection()
        notify("Cleared", "Nothing is picked now", 2)
    end })

-- ── stamped objects ────────────────────────────────────────────────────────
-- The Structures tab can stamp a shape into the world as a movable object.
-- These are the controls for those, which used to live in the Objects section
-- on the tab.
objectPanel:AddDivider()
objectPanel:AddLabel("Objects")

objectPanel:AddButton({
    Name = "Stamp Build as Object",
    Tooltip = "Drops the build file you picked into the world as one movable piece.",
    Callback = function()
        task.spawn(function()
            if not (isPreviewing or structShowPreview) then
                notifyWarn("Objects", "Turn a preview on first", 4)
                return
            end
            local data = loadSelectedBuild()
            if not data or not data.blocks then
                notifyWarn("Objects", "Pick a build file first", 3)
                return
            end
            objStamp(data.blocks, (selectedFile or "build"):gsub("%.json$", ""))
        end)
    end })

objectPanel:AddButton({
    Name = "Duplicate Object",
    Tooltip = "Makes another one of the stamped shape you have selected.",
    Callback = function() objDuplicate() end })

objectPanel:AddButton({
    Name = "Delete Object",
    Tooltip = "Removes the stamped shape you have selected.",
    Callback = function() objDeleteSel() end })

local sceneName = "MyScene"
objectPanel:AddTextbox({
    Name = "Scene Name",
    Default = sceneName,
    Callback = function(t) if t and t ~= "" then sceneName = t end end })

objectPanel:AddButton({
    Name = "Combine to Build File",
    Tooltip = "Puts every stamped shape together into a single build file.",
    Callback = function()
        task.spawn(function() objCombineToFile(sceneName) end)
    end })

objectPanel:AddButton({
    Name = "Clear All Objects",
    Tooltip = "Removes every stamped shape from the world.",
    Callback = function()
        confirm("Clear Stamped Shapes",
            "This removes every stamped shape from the world. You cannot undo it.",
            "Clear All", function() objClearAll() end)
    end })

end

-- ═══════════════════════════════════════════════════════════════════════════
-- BRUSH PANEL — modes and actions for the block brush, off the tab
-- ═══════════════════════════════════════════════════════════════════════════
do

local brushPanel = Duvome:MakeSidePanel({ Name = "Brush", Width = 200, Height = 420, Side = "right" })
BuilderAPI.brushPanel = brushPanel

local surfaceT, connectedT
surfaceT = brushPanel:AddToggle({
    Name = "Surface Select", Default = false,
    Tooltip = "Picks the whole flat area you clicked, like a floor or one side of a wall.",
    Callback = function(v)
        brushSurface = v
        -- the modes are mutually exclusive
        if v then brushConnected = false pcall(function() connectedT:Set(false) end) end
    end })

connectedT = brushPanel:AddToggle({
    Name = "Connected Select", Default = false,
    Callback = function(v)
        brushConnected = v
        if v then brushSurface = false pcall(function() surfaceT:Set(false) end) end
    end })

brushPanel:AddSlider({
    Name = "Brush Size", Min = 0, Max = 8, Increment = 1, Default = 0, ValueName = "blk",
    Callback = function(v) brushRadius = v end })

-- ── Editing the preview ────────────────────────────────────────────────────
-- Point the brush at the ghost instead of the island, so a build can be
-- trimmed before a single block is placed. Surface and Connected Select work
-- here exactly as they do on the island.
brushPanel:AddDivider()

BuilderAPI.toggles.brushPreview = brushPanel:AddToggle({
    Name = "Brush Preview", Default = false,
    Tooltip = "Paint on the preview instead of your island. The preview has to be solid first, so set See Through to 0.",
    Callback = function(v)
        if v then
            if not previewModel or not previewModel.Parent then
                notifyWarn("Brush Preview", "Preview a build first", 4)
                pcall(function() BuilderAPI.toggles.brushPreview:Set(false) end)
                return
            end
            if previewTransparency > 0 then
                notifyWarn("Brush Preview", "Set Transparency to 0 first, then turn this on", 6)
                pcall(function() BuilderAPI.toggles.brushPreview:Set(false) end)
                return
            end
            clearBlockSelection()
            brushPreview = true
            setPreviewQueryable(true)
            notify("Brush Preview On", "Paint the ghost, then Delete Selected", 6)
        else
            clearBlockSelection()
            brushPreview = false
            setPreviewQueryable(false)
            notify("Brush Preview Off", "The brush is back on the island", 3, "info")
        end
    end })

brushPanel:AddButton({
    Name = "Select Box Contents",
    Tooltip = "Picks everything inside the box at once, so you do not have to paint over it all.",
    Callback = function()
        local n = BuilderAPI.selectPreviewInBox and BuilderAPI.selectPreviewInBox(false) or 0
        if n > 0 then notify("Selection Box", n .. " block(s) added", 3, "info") end
    end })

brushPanel:AddButton({
    Name = "Deselect Box Contents",
    Tooltip = "Unpicks everything inside the box.",
    Callback = function()
        local n = BuilderAPI.selectPreviewInBox and BuilderAPI.selectPreviewInBox(true) or 0
        if n > 0 then notify("Selection Box", n .. " block(s) removed", 3, "info") end
    end })

brushPanel:AddButton({
    Name = "Delete Selected",
    Tooltip = "Takes the blocks you picked out of the preview, so they will not get built.",
    Callback = function()
        if blockSelCount == 0 then
            notifyWarn("Delete", "Paint ghost blocks with the brush, or use Select Box Contents", 5)
            return
        end
        local n = blockSelCount
        confirm("Delete From Preview",
            "Remove " .. n .. " block(s) from this build? Start Build will skip them.",
            "Delete", function()
                local gone = deleteSelectedFromPreview()
                notifyOK("Deleted", gone .. " block(s) removed from the build", 4)
            end)
    end })

brushPanel:AddButton({
    Name = "Restore Deleted",
    Tooltip = "Puts back every block you deleted.",
    Callback = function()
        local n = restorePreviewDeletions()
        if n == 0 then
            notify("Restore", "Nothing was deleted", 3, "info")
            return
        end
        notifyOK("Restored", n .. " block(s) back in - re-run Preview Build to see them", 5)
    end })

-- ── Selection ──────────────────────────────────────────────────────────────
brushPanel:AddDivider()
brushPanel:AddButton({ Name = "Clear Selection", Callback = function()
        clearBlockSelection()
        notify("Cleared", "Selection cleared", 2)
    end })
brushPanel:AddButton({ Name = "Save Selected Blocks", Callback = function()
        task.spawn(function()
            if brushPreview then
                notifyWarn("Save", "Brush Preview paints the ghost, not real blocks", 4)
                return
            end
            if blockSelCount == 0 then
                notify("Nothing Selected", "Use the Block Brush to select blocks first", 4)
                return
            end
            saveSelectedBrush()
        end)
    end })

end


-- ── On-screen status overlay ─────────────────────────────────────────────────
-- Floating list in the corner so build state is visible with the panel closed.
Duvome:AddWatch("Building", function()
    if not isBuilding then return false end
    if progressTotal > 0 then
        return progressPlaced .. "/" .. progressTotal
    end
    return true
end, nil, function(v)
    pcall(function() BuilderAPI.toggles.build:Set(v) end)
end)
Duvome:AddWatch("Preview", function() return isPreviewing end, nil, function(v)
    pcall(function() BuilderAPI.toggles.preview:Set(v) end)
end)
Duvome:AddWatch("Move Handles", function() return dragModeOn end, nil, function(v)
    pcall(function() BuilderAPI.toggles.handles:Set(v) end)
end)
Duvome:AddWatch("Block Brush", function()
    if not blockSelMode then return false end
    return blockSelCount > 0 and (blockSelCount .. " blocks") or true
end, nil, function(v)
    pcall(function() BuilderAPI.toggles.brush:Set(v) end)
end)
Duvome:AddWatch("File", function()
    return selectedFile and selectedFile:gsub("%.json$", "") or false
end)

-- watch list stays hidden until asked for
pcall(function() Duvome:SetWatchVisible(false) end)

notifyOK("Islands Auto Builder", "Build " .. IAB_BUILD, 6)
Duvome:AddWatch("Build", function() return IAB_BUILD end)