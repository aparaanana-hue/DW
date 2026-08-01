local Duvome = loadstring(game:HttpGet("https://raw.githubusercontent.com/aparaanana-hue/DW/refs/heads/main/DL.lua"))()
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
local IAB_BUILD = "Aug 01 14:54"

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
            local center = Vector3.new(centerX, (minY + maxY) / 2, centerZ)
            table.sort(items, function(a, b) return (a.pos - center).Magnitude < (b.pos - center).Magnitude end)
            local chunk = {}
            for _, it in ipairs(items) do
                if not isBuilding then break end
                hoverAbove(it.pos)
                pace()
                pcall(function() placeNow(it.b) end)
                chunk[#chunk + 1] = it
                if #chunk >= 40 then
                    confirmPlaced(chunk)
                    chunk = {}
                end
            end
            if #chunk > 0 then confirmPlaced(chunk) end

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

    local path = "autoBuilder/" .. selectedFile

    if not isfile(path) then
        notify("Error", "File not found: " .. tostring(selectedFile), 4)
        return nil
    end

    local text = readfile(path)
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
        local targetCF = CFrame.new(snapGridVec(base.Position)) * base.Rotation
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
                    clone.Parent = model
                    rendered = true
                    work = work + 8
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
            part.Size = Vector3.new(previewBlockSize, previewBlockSize, previewBlockSize)
            part.CFrame = targetCF
            part.Color = colorForBlockType(blockType)
            part:SetAttribute("GhostPreview", true)
            part.Parent = model
            work = work + 1
        end

        if work >= 600 then
            work = 0
            task.wait()
        end
    end

    if isPreviewing then
        notify("Preview Ready", "Turn on Drag Mode, then drag it with your mouse.", 6)
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
    selectedFile = name
    pcall(function() saveAlignment(name, CFrame.new()) end)
    pcall(function() fileDropdown:Refresh(getFiles()) fileDropdown:Set({ name }) end)
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
        local blocksFolder = ReplicatedStorage:FindFirstChild("blocks")
        local template = blocksFolder and blocksFolder:FindFirstChild(key)
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
        table.insert(list, {
            name = resolveBlockDisplayName(t),
            have = have[t] or 0,
            need = needed[t],
            from = swappedFrom[t],
        })
    end
    table.sort(list, function(a, b) return a.need > b.need end)

    local lines = {}
    local hidden = 0
    for _, e in ipairs(list) do
        if e.need < requiredMinCount then
            hidden = hidden + 1
        else
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

auto:CreateSection("Build")

progressParagraph = auto:CreateParagraph({
    Title = "Build Progress",
    Content = "Idle. Start a build to see live progress and ETA."
})

auto:CreateDropdown({
    Name = "Build Style",
    Options = {"Around Preview", "Expand from Middle", "Batch (verify)"},
    CurrentOption = {"Around Preview"},
    MultipleOptions = false,
    Flag = "BuildMode",
    Callback = function(option)
        buildMode = (typeof(option) == "table") and option[1] or option
    end
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
    -- Refresh and Delete live in this dropdown's gear rather than as two more
    -- buttons in the panel.
    Gear = {
        { Type = "button", Name = "Refresh File List", OnClick = function()
            pcall(function() fileDropdown:Refresh(getFiles()) end)
            notify("Files", "List refreshed", 2, "info")
        end },
        { Type = "button", Name = "Delete Selected File", OnClick = function()
            if not selectedFile or selectedFile == "" then
                notifyWarn("No File", "Pick a build file first", 3)
                return
            end
            local target = selectedFile
            confirm("Delete Build File",
                "Permanently delete '" .. target .. "'? This cannot be undone.",
                "Delete", function()
                    local ok = pcall(function()
                        local path = "autoBuilder/" .. target
                        if isfile(path) then delfile(path) end
                    end)
                    pcall(function() clearAlignment(target) end)
                    if ok then
                        selectedFile = nil
                        fileDropdown:Refresh(getFiles())
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
        { Type = "toggle", Name = "Walk To Each Block", Default = true,
          Callback = function(v) moveToBuildPosition = v end },
    },
    Tooltip = "Starts placing the selected build file. Turn off to stop mid-build.",
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
                local src = data.blocks
                task.spawn(function()
                    notify("Building", "Building where the ghost sits", 3, "info")
                    local transformed = transformBlocks(src, previewTransform)
                    runBuild(transformed, missingOnly)
                end)
            else
                runBuild(data.blocks, missingOnly)
            end
        else
            isBuilding = false
            releaseShift()
            notifyWarn("Stopped", "Build stopped", 3)
        end
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

-- The Objects controls are identical on every tab that can stamp geometry, so
-- they are built from one place instead of being copy-pasted per tab. Each tab
-- keeps its own scene name, matching the previous behaviour.
local function addObjectsSection(tab, stampLabel, getBlocks, opts)
    local sceneName = "MyScene"

    tab:CreateSection("Objects", { Collapsible = true, Column = opts and opts.Column or nil })

    tab:CreateButton({
        Name = stampLabel,
        Tooltip = "Place the current blocks into the world as a movable object.",
        Callback = function()
            task.spawn(function()
                local blocks, label = getBlocks()
                if blocks and #blocks > 0 then
                    objStamp(blocks, label)
                end
            end)
        end
    })

    tab:CreateButton({
        Name = "Duplicate",
        Tooltip = "Make a copy of the selected object.",
        Callback = function() objDuplicate() end
    })

    tab:CreateButton({
        Name = "Delete",
        Tooltip = "Remove the selected object.",
        Callback = function() objDeleteSel() end
    })

    tab:CreateDivider()

    tab:CreateInput({
        Name = "Scene Name",
        Default = sceneName,
        Callback = function(t) if t and t ~= "" then sceneName = t end end
    })

    tab:CreateButton({
        Name = "Combine All to Build File",
        Tooltip = "Merge every stamped object into a single build file.",
        Callback = function()
            task.spawn(function() objCombineToFile(sceneName) end)
        end
    })

    tab:CreateButton({
        Name = "Clear All Objects",
        Tooltip = "Remove every stamped object from the world.",
        Callback = function()
            confirm("Clear All Objects",
                "This removes every stamped object from the world. This cannot be undone.",
                "Clear All", function() objClearAll() end)
        end
    })
end

-- Blocks from the currently selected build file, used by Auto Build and Preview.
local function selectedFileBlocks()
    local data = loadSelectedBuild()
    if not data then
        notifyWarn("No File", "Pick a build file first", 3)
        return nil
    end
    local label = (selectedFile or "build"):gsub("%.json$", "")
    return data.blocks, label
end

addObjectsSection(auto, "Stamp File as Object", selectedFileBlocks, { Column = "left" })

do
local saveFileName = "MyBuild"
local saveSplitMode = "Full"
selBoxOnly = false
selBoxPart = nil
selHandles = nil

blockSelMode = false
blockSelConn = nil
blockSelDown = false
selectedBlocks = {}
blockSelCount = 0

function highlightBlock(part)
    if selectedBlocks[part] then return end
    local h = Instance.new("SelectionBox")
    h.Adornee = part
    h.Color3 = Color3.fromRGB(0, 255, 255)
    h.LineThickness = 0.05
    h.SurfaceColor3 = Color3.fromRGB(0, 255, 255)
    h.SurfaceTransparency = 0.6
    h.Parent = part
    selectedBlocks[part] = h
    blockSelCount = blockSelCount + 1
end

function unhighlightBlock(part)
    local h = selectedBlocks[part]
    if h then h:Destroy() selectedBlocks[part] = nil blockSelCount = blockSelCount - 1 end
end

function clearBlockSelection()
    for part, h in pairs(selectedBlocks) do
        if h then h:Destroy() end
    end
    selectedBlocks = {}
    blockSelCount = 0
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
    local folder = getBlocksFolder()
    if not folder then return nil end
    params.FilterDescendantsInstances = { folder }
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
    if hit and hit.Instance and hit.Instance:IsA("BasePart") then
        local n = hit.Instance.Name
        if n ~= "bedrock" and n ~= "portalToSpawn" then
            return hit.Instance
        end
    end
    return nil
end

function partToBlockEntry(part)
    local cf = part.CFrame
    local p = cf.Position
    local r = cf.RightVector
    local u = cf.UpVector
    local upper = false
    if part.Size.Y < 2.9 then
        local frac = p.Y - (math.floor(p.Y / 3 + 0.5) * 3)
        if frac > 0.35 then upper = true end
    end
    return {
        blockType = part.Name,
        upperBlock = upper,
        cframe = { p.X, p.Y, p.Z, r.X, r.Y, r.Z, u.X, u.Y, u.Z },
        parts = {},
    }
end

function finishSaveBlocks(blocks)
    if #blocks == 0 then
        notify("Save Failed", "No blocks found to save", 4)
        return
    end

    if saveSplitMode ~= "Full" then
        local minX, maxX = math.huge, -math.huge
        local minZ, maxZ = math.huge, -math.huge
        for _, b in ipairs(blocks) do
            local x, z = b.cframe[1], b.cframe[3]
            if x < minX then minX = x end
            if x > maxX then maxX = x end
            if z < minZ then minZ = z end
            if z > maxZ then maxZ = z end
        end
        local cx = math.floor((minX + maxX) / 2 / 3 + 0.5) * 3
        local cz = math.floor((minZ + maxZ) / 2 / 3 + 0.5) * 3

        local kept = {}
        for _, b in ipairs(blocks) do
            local x, z = b.cframe[1], b.cframe[3]
            local keep
            if saveSplitMode == "Half (mirror)" then
                keep = x >= cx
            else
                keep = x >= cx and z >= cz
            end
            if keep then kept[#kept + 1] = b end
        end

        local function mirror(b, mX, mZ)
            local c = b.cframe
            local nx = mX and (2 * cx - c[1]) or c[1]
            local nz = mZ and (2 * cz - c[3]) or c[3]
            local rX = mX and -c[4] or c[4]
            local rZ = mZ and -c[6] or c[6]
            local uX = mX and -c[7] or c[7]
            local uZ = mZ and -c[9] or c[9]
            return {
                blockType = b.blockType,
                upperBlock = b.upperBlock,
                cframe = { nx, c[2], nz, rX, c[5], rZ, uX, c[8], uZ },
                parts = {},
            }
        end

        local out, seen = {}, {}
        local function push(b)
            local k = b.cframe[1] .. "_" .. b.cframe[2] .. "_" .. b.cframe[3]
            if not seen[k] then seen[k] = true out[#out + 1] = b end
        end
        for _, b in ipairs(kept) do
            push(b)
            if saveSplitMode == "Half (mirror)" then
                push(mirror(b, true, false))
            else
                push(mirror(b, true, false))
                push(mirror(b, false, true))
                push(mirror(b, true, true))
            end
        end
        blocks = out
    end

    if not isfolder("autoBuilder") then makefolder("autoBuilder") end
    local name = saveFileName
    if not (name:lower():sub(-5) == ".json" or name:lower():sub(-4) == ".txt") then
        name = name .. ".json"
    end
    local ok, err = pcall(function()
        writefile("autoBuilder/" .. name, HttpService:JSONEncode({ blocks = blocks }))
    end)
    if ok then
        saveAlignment(name, CFrame.new())
        fileDropdown:Refresh(getFiles())
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

    local startSize, startCF
    selHandles.MouseButton1Down:Connect(function()
        startSize = selBoxPart.Size
        startCF = selBoxPart.CFrame
    end)
    selHandles.MouseDrag:Connect(function(face, distance)
        if not startSize then return end
        local normal = Vector3.FromNormalId(face)
        local axisAbs = Vector3.new(math.abs(normal.X), math.abs(normal.Y), math.abs(normal.Z))
        -- Snap to whole blocks. Raw handle distance is continuous, which let the
        -- box land on half a block and made the saved region ambiguous.
        local snapped = math.floor(distance / 3 + 0.5) * 3
        local newSize = startSize + axisAbs * snapped
        newSize = Vector3.new(
            math.max(3, math.floor(newSize.X / 3 + 0.5) * 3),
            math.max(3, math.floor(newSize.Y / 3 + 0.5) * 3),
            math.max(3, math.floor(newSize.Z / 3 + 0.5) * 3))
        local applied = newSize - startSize
        local worldNormal = startCF:VectorToWorldSpace(normal)
        selBoxPart.Size = newSize
        selBoxPart.CFrame = startCF + worldNormal * (applied:Dot(axisAbs) / 2)
    end)
    selHandles.MouseButton1Up:Connect(function()
        startSize = nil
    end)
end

previewTab:CreateSection("Preview", { Collapsible = true, Column = "right" })

BuilderAPI.toggles.preview = previewTab:CreateToggle({
    Name = "Preview Build",
    CurrentValue = false,
    Flag = "PreviewToggle",
    Gear = {
        { Type = "toggle", Name = "Use Real Models", Default = true,
          Callback = function(v) previewRealModels = v end },
        { Type = "toggle", Name = "Low-Lag Preview", Default = false,
          Callback = function(v) previewMinimized = v end },
        -- popover sliders are integers, so transparency is a percentage
        { Type = "button", Name = "Rotate 90", OnClick = function()
        if not previewModel or not previewModel.Parent then
            notify("No Preview", "Preview a build first", 3)
            return
        end
        rotatePreview(90)
        notify("Rotated", "Turned 90 degrees", 2)
    end },
        { Type = "slider", Name = "Transparency %", Min = 0, Max = 90, Default = 50,
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
                previewBuild(data.blocks)
            end)
        else
            clearPreview()
            notify("Preview Off", "Ghost blocks removed", 2)
        end
    end
})

BuilderAPI.toggles.handles = previewTab:CreateToggle({
    Name = "Move Handles",
    Tooltip = "Show drag arrows so you can slide the ghost into place before building.",
    CurrentValue = false,
    Flag = "PreviewDrag",
    Callback = function(v)
        setDragMode(v)
    end
})


-- Objects controls live on the Auto Build tab; this tab used an identical copy.


-- declared before use: the required-blocks scan refreshes these
local buildTypeDropdown, invBlockDropdown
local requiredBlocksParagraph = previewTab:CreateParagraph({
    Title = "Required Blocks",
    Content = "Tap 'Show Required Blocks' to see what you need."
})

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

previewTab:CreateButton({
    Name = "Show Required Blocks",
    Gear = {
        { Type = "slider", Name = "Hide under", Min = 1, Max = 64, Default = 1,
          Callback = function(v) requiredMinCount = v end },
    },
    Callback = function()
        local blocks = lastPreviewBlocks
        if not blocks then
            local data = loadSelectedBuild()
            if not data then
                return
            end
            blocks = data.blocks
        end

        task.spawn(function()
            notify("Scanning", "Checking what's still missing...", 3)
            local _, missing = getPlacedAndMissingBlocks(blocks)

            if #missing == 0 then
                requiredBlocksParagraph:Set({
                    Title = "Required Blocks (Missing)",
                    Content = "Nothing missing - all blocks are already placed."
                })
                notify("Done", "Nothing missing", 3)
                return
            end

            requiredBlocksParagraph:Set({
                Title = "Required Blocks (Missing)",
                Content = getRequiredBlocksText(missing)
            })
            -- fill the replace pickers now, so Refresh is not a separate step
            pcall(function()
                buildTypeDropdown:Refresh(getBuildTypeOptions())
                invBlockDropdown:Refresh(getInventoryOptions())
            end)
            notify("Done", "Still need " .. #missing .. " block(s)", 4)
        end)
    end
})


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
    Gear = { { Type = "button", Name = "Refresh Lists", OnClick = function()
        buildTypeDropdown:Refresh(getBuildTypeOptions())
        invBlockDropdown:Refresh(getInventoryOptions())
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
    Gear = { { Type = "button", Name = "Refresh Lists", OnClick = function()
        buildTypeDropdown:Refresh(getBuildTypeOptions())
        invBlockDropdown:Refresh(getInventoryOptions())
        notify("Refreshed", "Build & inventory lists updated", 2)
    end } },
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
                requiredBlocksParagraph:Set({ Title = "Required Blocks", Content = getRequiredBlocksText(lastPreviewBlocks) })
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
                requiredBlocksParagraph:Set({ Title = "Required Blocks", Content = getRequiredBlocksText(lastPreviewBlocks) })
            end)
        end
        notify("Replacement Added", resolveBlockDisplayName(replaceFromType) .. " -> " .. resolveBlockDisplayName(replaceToType), 4)
    end
})


saveTab:CreateSection("Save", { Collapsible = true, Column = "right" })

saveTab:CreateInput({
    Name = "Save As",
    PlaceholderText = "MyBuild",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text and text ~= "" then
            saveFileName = text
        end
    end
})

saveTab:CreateToggle({
    Name = "Show Selection Box",
    CurrentValue = false,
    Flag = "ShowSelBox",
    Tooltip = "Shows the box and limits Save Island Build to what is inside it.",
    Callback = function(v)
        selBoxOnly = v
        if v then
            showSelBox()
            notify("Box Shown", "Drag the face handles to resize it", 3)
        else
            hideSelBox()
        end
    end
})



BuilderAPI.toggles.brush = saveTab:CreateToggle({
    Name = "Block Brush",
    Gear = {
        { Type = "button", Name = "Clear Selection", OnClick = function()
        clearBlockSelection()
        notify("Cleared", "Selection cleared", 2)
    end },
        { Type = "button", Name = "Save Selected Blocks", OnClick = function()
        task.spawn(function()
            if blockSelCount == 0 then
                notify("Nothing Selected", "Use the Block Brush to select blocks first", 4)
                return
            end
            saveSelectedBrush()
        end)
    end },
    },
    Tooltip = "Hold click and drag over blocks in the world to add them to the selection.",
    CurrentValue = false,
    Flag = "BlockBrush",
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
                local part = blockUnderCursor()
                if part then
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                        unhighlightBlock(part)
                    else
                        highlightBlock(part)
                    end
                    -- count now shows on the watch overlay rather than a panel label
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


saveTab:CreateDropdown({
    Name = "Save Mode",
    Options = { "Full", "Half (mirror)", "Quarter (4x)" },
    CurrentOption = { "Full" },
    MultipleOptions = false,
    Flag = "SaveSplitMode",
    Callback = function(v)
        saveSplitMode = (typeof(v) == "table") and v[1] or v
    end
})

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
            if selBoxOnly then
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

saveTab:CreateButton({
    Name = "Save Island Build",
    Callback = function()
        task.spawn(function()
            notify("Saving", "Scanning island blocks...", 3)
            saveIslandBuild()
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

structTab:CreateSection("Structures")

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
    Gear = { { Type = "button", Name = "Refresh Blocks", OnClick = function()
        local list = structFetchBlocks()
        structBlockDropdown:Refresh(list)
        notify("Refreshed", #list .. " blocks found", 3)
    end } },
    Options = structFetchBlocks(),
    CurrentOption = {"grass"},
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


structTab:CreateParagraph({
    Title = "Sculpt the Terrain",
    Content = "Make a Landscape with Live Preview on, then use these to shape it. Raise hills, dig holes, and add water. Or turn on Cursor Sculpt to paint with your mouse."
})

structTab:CreateDropdown({
    Name = "Brush Mode",
    Options = {"Raise", "Lower", "Flatten", "Smooth"},
    CurrentOption = {"Raise"},
    MultipleOptions = false,
    Flag = "TerraMode",
    Callback = function(v)
        terraMode = (typeof(v) == "table") and v[1] or v
    end
})

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

structTab:CreateSection("Save", { Collapsible = true })

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

            selectedFile = name
            savedPreviewTransform = nil
            pcall(function()
                fileDropdown:Refresh(getFiles())
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

cityTab:CreateSection("City", { Collapsible = true })

cityTab:CreateParagraph({
    Title = "City Generator",
    Content = "Makes roads and drops a house on each lot. The same seed makes the same city. Then preview and build it."
})

cityTab:CreateDivider()

for _, s in ipairs({
    { "Lots Across",  1,  8, 1, 3,  "CityLotsX", function(v) cityLotsX = v end },
    { "Lots Deep",    1,  8, 1, 3,  "CityLotsZ", function(v) cityLotsZ = v end },
    { "Lot Width",    7, 25, 1, 13, "CityLotW",  function(v) cityLotW  = v end },
    { "Lot Depth",    7, 25, 1, 13, "CityLotD",  function(v) cityLotD  = v end },
    { "Road Width",   1,  8, 1, 3,  "CityRoadW", function(v) cityRoadW = v end },
}) do
    local name, lo, hi, step, default, flag, apply = s[1], s[2], s[3], s[4], s[5], s[6], s[7]
    cityTab:CreateSlider({
        Name = name,
        Range = { lo, hi }, Increment = step, CurrentValue = default,
        Suffix = "blk", Flag = flag,
        Callback = apply
    })
end

cityTab:CreateDivider()

-- Was two separate Min/Max sliders; a single two-handle range slider makes the
-- relationship obvious and can't be set inside-out.
cityTab:CreateRangeSlider({
    Name = "House Height",
    Range = { 3, 30 }, Increment = 1,
    DefaultMin = 5, DefaultMax = 11,
    Suffix = "blk", Flag = "CityHeight",
    Callback = function(mn, mx)
        cityMinH = mn
        cityMaxH = mx
    end
})

cityTab:CreateSlider({
    Name = "City Seed",
    Range = {1, 10000}, Increment = 1, CurrentValue = 1, Flag = "CitySeed",
    Callback = function(v) citySeed = v end
})

cityTab:CreateDivider()

cityTab:CreateToggle({
    Name = "Generate on Landscape",
    CurrentValue = false,
    Flag = "CityLandscape",
    Tooltip = "Lay the city over generated terrain instead of a flat plane.",
    Callback = function(v) cityLandscape = v end
})

cityTab:CreateSlider({
    Name = "Terrain Height",
    Range = {3, 60}, Increment = 3, CurrentValue = 12, Suffix = "blk", Flag = "CityTerrainH",
    Callback = function(v) cityTerrainH = v end
})

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
                    if ok then written = written + 1 end
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
                selectedFile = name
                savedPreviewTransform = nil
                pcall(function() fileDropdown:Set({ name }) end)
                notify("City Saved", #blocks .. " blocks -> " .. name .. " (selected)", 6)
            end

            cityStats:Set({
                Title = "City Stats",
                Content = (cityLotsX * cityLotsZ) .. " houses · " .. #blocks .. " blocks"
            })
            pcall(function() fileDropdown:Refresh(getFiles()) end)
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

platTab:CreateSection("Platforms", { Collapsible = true })

platTab:CreateParagraph({
    Title = "Platform Designer",
    Content = "Makes fancy floor patterns. Pick a style, change the seed and density, preview it, then generate a file."
})

platTab:CreateDropdown({
    Name = "Style",
    Options = { "Mandala", "Ornament", "Rings", "Snowflake", "Maze" },
    CurrentOption = { "Mandala" },
    MultipleOptions = false,
    Flag = "PlatStyle",
    Callback = function(v) platStyle = (typeof(v) == "table") and v[1] or v end
})

platTab:CreateSlider({
    Name = "Tile Size",
    Range = { 11, 121 }, Increment = 2, CurrentValue = 41, Suffix = "blk", Flag = "PlatSize",
    Callback = function(v) platSize = v end
})

platTab:CreateSlider({
    Name = "Seed",
    Range = { 1, 10000 }, Increment = 1, CurrentValue = 1, Flag = "PlatSeed",
    Callback = function(v) platSeed = v end
})

platTab:CreateSlider({
    Name = "Density",
    Range = { 10, 90 }, Increment = 5, CurrentValue = 50, Suffix = "%", Flag = "PlatDensity",
    Callback = function(v) platDensity = v / 100 end
})

platTab:CreateToggle({
    Name = "Diagonal Symmetry",
    CurrentValue = true,
    Flag = "PlatDiag",
    Tooltip = "Mirrors the pattern across the diagonals. Mostly affects the Mandala style.",
    Callback = function(v) platMirrorDiag = v end
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
    Name = "Preview Pattern",
    Callback = function()
        task.spawn(function()
            notify("Generating", "Building " .. platStyle .. " pattern...", 3)
            local blocks = platGenerate()
            if #blocks == 0 then notify("Empty", "Nothing generated", 3) return end
            platStats:Set({ Title = "Pattern Stats", Content = platStyle .. " · " .. platSize .. "x" .. platSize .. " · " .. #blocks .. " blocks" })
            showThumbnail(blocks, platStyle .. " Platform")
        end)
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

            selectedFile = name
            savedPreviewTransform = nil
            saveAlignment(name, CFrame.new())
            pcall(function() fileDropdown:Refresh(getFiles()) fileDropdown:Set({ name }) end)
            platStats:Set({ Title = "Pattern Stats", Content = platStyle .. " · " .. #blocks .. " blocks -> " .. name })
            notify("Platform Saved", #blocks .. " blocks -> " .. name .. " (selected)", 6)
        end)
    end
})

platTab:CreateParagraph({
    Title = "Next Steps",
    Content = "1. Pick a Style, tap Randomize Seed, set Density\n2. Preview Pattern (3D)\n3. Generate Build File\n4. Preview tab: Preview Build\n5. Auto Build tab: Build Selected File"
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
            selectedFile = name
            savedPreviewTransform = nil
            pcall(function()
                fileDropdown:Refresh(getFiles())
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

local function scanColours()
    local folder = ReplicatedStorage:FindFirstChild("blocks")
    if not folder then
        notifyErr("Colour Scan", "ReplicatedStorage.blocks not found", 5)
        return
    end
    local out = {}
    for _, child in ipairs(folder:GetChildren()) do
        local col = averageColour(child)
        if col then
            local L, a, b = toOklab(col)
            out[#out + 1] = { name = child.Name, col = col, L = L, a = a, b = b }
        end
    end
    table.sort(out, function(p, q) return p.L < q.L end)
    C.cache = out
    pcall(function()
        scanPara:Set({
            Title = "Colour Index",
            Content = #out .. " block colours sampled, sorted dark to light.",
        })
    end)
    notifyOK("Colour Scan", #out .. " blocks indexed", 5)
end

local function ensureCache()
    if C.cache and #C.cache > 0 then return true end
    scanColours()
    return C.cache ~= nil and #C.cache > 0
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
    Tooltip = "Sample every block in ReplicatedStorage.blocks and index it in OKLab. Run this once per session.",
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
        pcall(function() annDropdown:Refresh(annList()) end)
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
        pcall(function() annDropdown:Refresh(annList()) end)
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

tabEdit:CreateColorpicker({
    Name = "Accent Colour",
    Default = Color3.fromRGB(120, 80, 255),
    Callback = function(c) Duvome:SetAccent(c) end
})

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
    cache = nil,      -- decoded { pixels = {}, w = , h = }
    match = {},       -- memo: "r,g,b" -> block name
}

local imgPara

local function say(title, body)
    pcall(function() imgPara:Set({ Title = title, Content = body }) end)
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

local function inflate(reader, out)
    local bitStream = createBitStream(reader)
    parseZlibHeader(bitStream)
    local window, pos = {}, 1
    local function write(byte)
        out(byte)
        window[pos] = byte
        pos = pos % 32768 + 1
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
-- Memoised per distinct pixel colour: returns the block name and the colour
-- that block actually is, so the preview shows the quantised result.
local function blockFor(r, g, b)
    local k = r .. "," .. g .. "," .. b
    local hit = IMG.match[k]
    if hit then return hit[1], hit[2] end
    local e = BA.nearestBlockEntry(Color3.fromRGB(r, g, b))
    local rec = e and { e.name, e.col } or { O.activeBlock, Color3.fromRGB(r, g, b) }
    IMG.match[k] = rec
    return rec[1], rec[2]
end

-- ── preview ────────────────────────────────────────────────────────────────
local PREVIEW_FOLDER = "IABImagePreview"
local MAX_PREVIEW = 12000

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
        if py % 16 == 0 then task.wait() end
    end
    return out, tw, th
end

-- Resolves the image into world cells. Each entry is {x, y, z, name, colour}.
local function imageCells()
    local grid, tw, th = sampled()
    local ax, ay, az = 0, 0, 0
    local part = targetPart()
    if part then
        ax, ay, az = toCell(part.Position)
    else
        local _, _, hrp = getCharacterParts()
        if hrp then ax, ay, az = toCell(hrp.Position) end
    end

    local cells = {}
    for py = 1, th do
        for px = 1, tw do
            local px4 = grid[py][px]
            local r, g, b, a = px4[1], px4[2], px4[3], px4[4]
            if a >= 128 then                       -- skip transparent pixels
                local name, col = blockFor(r, g, b)
                if IMG.mode == "Pixel Art (Wall)" then
                    -- image rows run top-down, world Y runs up
                    cells[#cells + 1] = { ax + px, ay + (th - py), az, name, col }
                elseif IMG.mode == "Pixel Art (Floor)" then
                    cells[#cells + 1] = { ax + px, ay, az + py, name, col }
                else
                    -- Heightmap: brightness drives column height
                    local lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
                    local hgt = math.max(1, math.floor(lum * IMG.maxHeight + 0.5))
                    for y = 1, hgt do
                        cells[#cells + 1] = { ax + px, ay + y, az + py, name, col }
                    end
                end
            end
        end
        if py % 8 == 0 then task.wait() end
    end
    return cells, tw, th
end

local function previewImage()
    if not IMG.cache then notifyWarn("Image", "Load an image first", 4) return end
    task.spawn(function()
        clearImagePreview()
        say("Image", "Building preview...")
        local cells, tw, th = imageCells()
        if #cells == 0 then
            notifyWarn("Image", "Nothing to preview (all transparent?)", 4)
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

local function buildImage()
    if not IMG.cache then
        notifyWarn("Image", "Load an image first", 4)
        return
    end
    runCommit("Image", function(rec)
        local cells, tw, th = imageCells()
        if #cells == 0 then notifyWarn("Image", "Nothing to build (all transparent?)", 4) return end
        clearImagePreview()
        say("Image", "Placing " .. #cells .. " blocks...")
        placeCells(cells, rec)
        notifyOK("Image", #cells .. " blocks from " .. tw .. "x" .. th, 6)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════════════════
tabEdit:CreateDivider()

imgPara = tabEdit:CreateParagraph({
    Title = "Image",
    Content = "Needs a DIRECT link to a .png file - one that ends in .png and\n"
        .. "shows only the image, no page around it.\n"
        .. "A gallery page link (imgur.com/abc) returns HTML, not an image;\n"
        .. "open the image, right-click it, Copy image address.\n"
        .. "Only PNG works. JPEG, WebP and GIF are not supported.\n"
        .. "Run Scan Block Colours on the Colour tab once first.",
})

tabEdit:CreateInput({
    Name = "Image URL",
    Default = "",
    Callback = function(t) if t and t ~= "" then IMG.url = t end end
})

tabEdit:CreateButton({
    Name = "Load Image",
    Gear = { { Type = "button", Name = "Check URL", OnClick = function()
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
    end } },
    Tooltip = "Download and decode the PNG. 8-bit non-interlaced PNGs are supported.",
    Callback = loadImage
})

tabEdit:CreateDropdown({
    Name = "Image Mode",
    Options = { "Pixel Art (Wall)", "Pixel Art (Floor)", "Heightmap Terrain" },
    CurrentOption = { "Pixel Art (Wall)" }, MultipleOptions = false,
    Flag = "IMGMode",
    Callback = function(v) IMG.mode = (typeof(v) == "table") and v[1] or v end
})

tabEdit:CreateSlider({
    Name = "Build Width", Range = { 8, 160 }, Increment = 4, CurrentValue = 48,
    Suffix = "blk", Flag = "IMGW",
    Callback = function(v)
        IMG.width = v
        if IMG.cache then
            say("Image", "Loaded " .. IMG.cache.w .. " x " .. IMG.cache.h
                .. "\nWill build at " .. v .. " blocks wide.")
        end
    end
})

tabEdit:CreateSlider({
    Name = "Heightmap Max Height", Range = { 2, 64 }, Increment = 1, CurrentValue = 24,
    Suffix = "blk", Flag = "IMGH", Callback = function(v) IMG.maxHeight = v end
})

tabEdit:CreateButton({
    Name = "Preview Image at Cursor",
    Gear = { { Type = "button", Name = "Clear Image Preview", OnClick = function()
        clearImagePreview()
        notify("Image", "Preview cleared", 2, "info")
    end } },
    Tooltip = "Show the image as coloured ghost blocks first, without placing anything.",
    Callback = previewImage
})

tabEdit:CreateButton({
    Name = "Build Image at Cursor",
    Tooltip = "Place the image where you are pointing, or at you if pointing at nothing.",
    Callback = buildImage
})

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
    pcall(function() fileDrop:Refresh(list) end)
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

local blockList = (function()
    local seen, b = {}, {}
    local f = ReplicatedStorage:FindFirstChild("blocks")
    if f then
        for _, v in ipairs(f:GetChildren()) do
            if not seen[v.Name] then seen[v.Name] = true table.insert(b, v.Name) end
        end
    end
    table.sort(b)
    if #b == 0 then b = { "stone", "grass" } end
    return b
end)()

panel:AddDropdown({
    Name = "Active Block",
    Options = blockList, Default = "stone", Search = true,
    Callback = function(v) O.activeBlock = v end
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
    ["Landscape"]      = { "radius", "width", "height", "smooth", "seed", "fill", "rot" },
    ["Square Floor"]   = { "radius", "width", "rot" },
    ["Circle"]         = { "radius", "thickness", "rot" },
}

BuilderAPI.structMode = BuilderAPI.structMode or "Sphere"
local shapeCtl = {}

local function addShapeControls()
    -- Block choice lives on the panel too, so each shape can be textured
    -- without leaving it.
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
local MAX_PARTS = 20000         -- render everything up to this; beyond it, sample

local thumbPanel = Duvome:MakeSidePanel({ Name = "Thumbnail", Width = 220, Height = 300, Side = "right" })
BuilderAPI.thumbPanel = thumbPanel

local host = thumbPanel:Container()

local viewport = Instance.new("ViewportFrame")
viewport.BackgroundColor3 = Color3.fromRGB(8, 3, 16)
viewport.BackgroundTransparency = 0.15
viewport.BorderSizePixel = 0
viewport.Size = UDim2.new(1, 0, 0, 250)
viewport.LayoutOrder = 1
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
    local folder = ReplicatedStorage:FindFirstChild("blocks")
    local model = folder and folder:FindFirstChild(name)
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

local function render()
    local data = loadSelectedBuild()
    if not data or not data.blocks or #data.blocks == 0 then
        notifyWarn("Thumbnail", "Pick a build file first", 3)
        infoLabel.Text = "No file selected."
        return
    end

    clearWorld()
    local blocks = data.blocks
    local total = #blocks
    -- even sampling rather than the first N, so the shape stays recognisable
    local step = math.max(1, math.ceil(total / MAX_PARTS))

    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local made = 0

    for i = 1, total, step do
        local b = blocks[i]
        local cf = b.cframe
        if cf and cf[1] then
            local x, y, z = cf[1], cf[2], cf[3]
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.Size = Vector3.new(BS, BS, BS)
            p.CFrame = CFrame.new(x, y, z)
            p.Color = colourFor(b.blockType)
            p.Material = Enum.Material.SmoothPlastic
            p.Parent = world
            made = made + 1
            if x < minX then minX = x end
            if x > maxX then maxX = x end
            if y < minY then minY = y end
            if y > maxY then maxY = y end
            if z < minZ then minZ = z end
            if z > maxZ then maxZ = z end
        end
        if made % 400 == 0 then task.wait() end
    end

    if made == 0 then
        infoLabel.Text = "That file has no placeable blocks."
        return
    end

    T.count = made
    T.name = (selectedFile or "build"):gsub("%.json$", "")
    local centre = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
    local span = math.max(maxX - minX, maxY - minY, maxZ - minZ, BS)

    -- park the model at the origin so the camera can orbit a fixed point
    for _, p in ipairs(world:GetChildren()) do
        if p:IsA("BasePart") then p.CFrame = p.CFrame - centre end
    end

    T.radius = span * 1.5 + 10
    T.height = span * 0.55 + 5

    infoLabel.Text = T.name .. "\n" .. total .. " blocks"
        .. (made < total and ("  (showing " .. made .. ")") or "")
    notifyOK("Thumbnail", T.name .. " rendered", 3)
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

pcall(function() Duvome:SetWatchVisible(true) end)

notifyOK("Islands Auto Builder", "Build " .. IAB_BUILD, 6)
Duvome:AddWatch("Build", function() return IAB_BUILD end)