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

local auto = main:CreateTab("Auto Build", "hammer")
local previewTab = main:CreateTab("Preview", "eye")
local saveTab = main:CreateTab("Save Build", "save")
local structTab = main:CreateTab("Structures", "mountain")
local cityTab = main:CreateTab("City Gen", "building-2")
local platTab = main:CreateTab("Platforms", "layout-grid")

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

    local list = {}
    for _, t in ipairs(order) do
        table.insert(list, { name = resolveBlockDisplayName(t), have = have[t] or 0, need = needed[t] })
    end
    table.sort(list, function(a, b) return a.need > b.need end)

    local lines = {}
    for _, e in ipairs(list) do
        local line = e.name .. " " .. e.have .. "/" .. e.need
        if e.have < e.need then
            line = '<font color="rgb(255,80,80)">' .. line .. "</font>"
        end
        table.insert(lines, line)
    end

    table.insert(lines, "")
    table.insert(lines, "Types: " .. #list)

    return table.concat(lines, "\n")
end

auto:CreateSection("Build File")

fileDropdown = auto:CreateDropdown({
    Name = "Select Build File",
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

auto:CreateButton({
    Name = "Delete Selected File",
    Tooltip = "Permanently delete the selected build file from the autoBuilder folder.",
    Callback = function()
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
    end
})

auto:CreateSection("Build")

auto:CreateToggle({
    Name = "Start Build",
    CurrentValue = false,
    Flag = "BuildToggle",
    Keybind = true,
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

auto:CreateToggle({
    Name = "Skip Existing Blocks",
    CurrentValue = false,
    Flag = "PlaceMissingToggle",
    Tooltip = "Only place blocks that are missing. Useful for finishing a partial build.",
    Callback = function(v)
        placeMissingOnly = v
    end
})

auto:CreateToggle({
    Name = "Only Use Blocks I Own",
    CurrentValue = false,
    Flag = "OnlyUseOwned",
    Tooltip = "Skip any block type you don't have in your inventory instead of failing on it.",
    Callback = function(v)
        onlyUseOwned = v
    end
})

auto:CreateToggle({
    Name = "Use Recommended Settings",
    CurrentValue = false,
    Flag = "UseRecommended",
    Tooltip = "Applies safe, smooth values: interval 0.2, fly speed 25, gap 12. You can still adjust the sliders afterwards.",
    Callback = function(v)
        if v then
            pcall(function() intervalSlider:Set(0.2) end)
            pcall(function() flySpeedSlider:Set(25) end)
            pcall(function() gapSlider:Set(12) end)
            placeDelay = 0.2
            buildFlySpeed = 25
            buildStandoff = 12
            notifyOK("Recommended Applied", "Interval 0.2, Fly 25, Gap 12", 4)
        end
    end
})

progressParagraph = auto:CreateParagraph({
    Title = "Build Progress",
    Content = "Idle. Start a build to see live progress and ETA."
})

-- The Objects controls are identical on every tab that can stamp geometry, so
-- they are built from one place instead of being copy-pasted per tab. Each tab
-- keeps its own scene name, matching the previous behaviour.
local function addObjectsSection(tab, stampLabel, getBlocks)
    local sceneName = "MyScene"

    tab:CreateSection("Objects", { Collapsible = true })

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

addObjectsSection(auto, "Stamp File as Object", selectedFileBlocks)

auto:CreateSection("Style & Speed")

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
        local newSize = startSize + axisAbs * distance
        newSize = Vector3.new(math.max(4, newSize.X), math.max(4, newSize.Y), math.max(4, newSize.Z))
        local applied = newSize - startSize
        local worldNormal = startCF:VectorToWorldSpace(normal)
        selBoxPart.Size = newSize
        selBoxPart.CFrame = startCF + worldNormal * (applied:Dot(axisAbs) / 2)
    end)
    selHandles.MouseButton1Up:Connect(function()
        startSize = nil
    end)
end

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

saveTab:CreateSection("Selection Box")

saveTab:CreateToggle({
    Name = "Show Selection Box",
    CurrentValue = false,
    Flag = "ShowSelBox",
    Callback = function(v)
        if v then
            showSelBox()
            notify("Box Shown", "Drag the face handles to resize it", 3)
        else
            hideSelBox()
        end
    end
})

saveTab:CreateToggle({
    Name = "Save Only Box Area",
    CurrentValue = false,
    Callback = function(v)
        selBoxOnly = v
    end
})

saveTab:CreateSection("Block Brush Select")

saveTab:CreateParagraph({
    Title = "Paint-Select Blocks",
    Content = "Turn this on and hold left-click to paint over blocks. They glow cyan. Good for odd shapes the box misses, like a cone. Works in freecam."
})

local blockSelCountLabel = saveTab:CreateParagraph({
    Title = "Selection",
    Content = "0 blocks selected"
})

saveTab:CreateToggle({
    Name = "Block Brush",
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
                    blockSelCountLabel:Set({ Title = "Selection", Content = blockSelCount .. " blocks selected" })
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

saveTab:CreateButton({
    Name = "Clear Selection",
    Callback = function()
        clearBlockSelection()
        blockSelCountLabel:Set({ Title = "Selection", Content = "0 blocks selected" })
        notify("Cleared", "Selection cleared", 2)
    end
})

saveTab:CreateButton({
    Name = "Save Selected Blocks",
    Callback = function()
        task.spawn(function()
            if blockSelCount == 0 then
                notify("Nothing Selected", "Use the Block Brush to select blocks first", 4)
                return
            end
            saveSelectedBrush()
        end)
    end
})

saveTab:CreateSection("Save & Mirror")

saveTab:CreateParagraph({
    Title = "Split / Mirror Save",
    Content = "Full saves it all. Half saves one side and mirrors it. Quarter saves one corner and mirrors it 4 ways. Great for even builds."
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

local intervalSlider = auto:CreateSlider({
    Name = "Place Interval",
    Range = {0.005, 1},
    Increment = 0.005,
    CurrentValue = 0.02,
    Suffix = "s",
    Flag = "PlaceInterval",
    Callback = function(v)
        placeDelay = v
    end
})

auto:CreateSection("Advanced Speed", { Collapsible = true })

auto:CreateToggle({
    Name = "Adaptive Rate",
    CurrentValue = false,
    Flag = "AdaptiveRate",
    Tooltip = "Changes the build speed on its own. Slows down if blocks fail, speeds up when it's safe.",
    Callback = function(v)
        adaptiveRate = v
    end
})

auto:CreateToggle({
    Name = "Pipelined Placing",
    CurrentValue = false,
    Flag = "PipelineMode",
    Tooltip = "Places many blocks at once instead of one at a time. Much faster, but a little riskier.",
    Callback = function(v)
        pipelineMode = v
        if v then
            notifyOK("Pipelined", "Faster placing is on", 4)
        else
            notify("Sequential", "One block at a time", 3, "info")
        end
    end
})

auto:CreateSlider({
    Name = "Pipeline Depth",
    Range = {2, 30},
    Increment = 1,
    CurrentValue = 8,
    Suffix = "blk",
    Flag = "PipelineDepth",
    Callback = function(v)
        pipelineDepth = v
    end
})

auto:CreateSection("Movement")

auto:CreateToggle({
    Name = "Move Before Placing",
    CurrentValue = true,
    Flag = "MoveNearBlock",
    Tooltip = "Walk or fly close to each block before placing it. Slower, but far more reliable.",
    Callback = function(v)
        moveToBuildPosition = v
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

local flySpeedSlider = auto:CreateSlider({
    Name = "Fly Speed",
    Range = {8, 80},
    Suffix = "st/s",
    Increment = 1,
    CurrentValue = 35,
    Flag = "BuildFlySpeed",
    Callback = function(v)
        buildFlySpeed = v
    end
})

local gapSlider = auto:CreateSlider({
    Name = "Build Gap",
    Range = {3, 40},
    Suffix = "st",
    Increment = 1,
    CurrentValue = 12,
    Flag = "BuildStandoff",
    Callback = function(v)
        buildStandoff = v
    end
})

previewTab:CreateParagraph({
    Title = "Schematic Preview",
    Content = "Shows your build as see-through blocks in front of you. Each block type has its own color."
})

previewTab:CreateToggle({
    Name = "Preview Build",
    CurrentValue = false,
    Flag = "PreviewToggle",
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

previewTab:CreateSection("Move Preview")

previewTab:CreateToggle({
    Name = "Move Handles",
    Tooltip = "Show drag arrows so you can slide the ghost into place before building.",
    CurrentValue = false,
    Flag = "PreviewDrag",
    Callback = function(v)
        setDragMode(v)
    end
})

previewTab:CreateButton({
    Name = "Rotate 90°",
    Callback = function()
        if not previewModel or not previewModel.Parent then
            notify("No Preview", "Preview a build first", 3)
            return
        end
        rotatePreview(90)
        notify("Rotated", "Turned 90 degrees", 2)
    end
})

addObjectsSection(previewTab, "Stamp File as Object", selectedFileBlocks)

previewTab:CreateSection("Appearance")

previewTab:CreateToggle({
    Name = "Use Real Models",
    Tooltip = "Show machines and objects as their real models instead of plain blocks. Looks better, costs more FPS.",
    CurrentValue = true,
    Flag = "PreviewRealModels",
    Callback = function(v)
        previewRealModels = v
    end
})

previewTab:CreateToggle({
    Name = "Low-Lag Preview",
    Tooltip = "Draw a simplified ghost. Use this for very large builds.",
    CurrentValue = false,
    Flag = "PreviewMinimized",
    Callback = function(v)
        previewMinimized = v
        if v then
            notify("Minimized Preview", "Hides buried blocks. Re-preview to apply.", 4)
        else
            notify("Full Preview", "Re-preview to apply.", 3)
        end
    end
})

previewTab:CreateSlider({
    Name = "Preview Transparency",
    Range = {0, 0.9},
    Increment = 0.05,
    CurrentValue = 0.5,
    Flag = "PreviewTransparency",
    Callback = function(v)
        previewTransparency = v
        local folder = Workspace:FindFirstChild(previewFolderName)
        if folder then
            for _, part in ipairs(folder:GetDescendants()) do
                if part:IsA("BasePart") and part:GetAttribute("GhostPreview") then
                    part.Transparency = v
                end
            end
        end
    end
})

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
            notify("Done", "Still need " .. #missing .. " block(s)", 4)
        end)
    end
})

previewTab:CreateSection("Replace Blocks", { Collapsible = true })

previewTab:CreateParagraph({
    Title = "Swap Block Types",
    Content = "Swap one block type for another from your bag. Refresh, pick both, then Add."
})

local buildTypeMap = {}
local invTypeMap = {}
local replaceFromType = nil
local replaceToType = nil
local buildTypeDropdown, invBlockDropdown, replaceListParagraph

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
    Options = getInventoryOptions(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(option)
        local disp = (typeof(option) == "table") and option[1] or option
        replaceToType = invTypeMap[disp]
    end
})

previewTab:CreateButton({
    Name = "Refresh Lists",
    Callback = function()
        buildTypeDropdown:Refresh(getBuildTypeOptions())
        invBlockDropdown:Refresh(getInventoryOptions())
        notify("Refreshed", "Build & inventory lists updated", 2)
    end
})

replaceListParagraph = previewTab:CreateParagraph({
    Title = "Current Replacements",
    Content = "No replacements set."
})

previewTab:CreateButton({
    Name = "Add Replacement",
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

previewTab:CreateButton({
    Name = "Clear Replacements",
    Callback = function()
        blockReplacements = {}
        replaceListParagraph:Set({ Title = "Current Replacements", Content = "No replacements set." })
        if lastPreviewBlocks then
            pcall(function()
                requiredBlocksParagraph:Set({ Title = "Required Blocks", Content = getRequiredBlocksText(lastPreviewBlocks) })
            end)
        end
        notify("Cleared", "All replacements removed", 3)
    end
})

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
    Callback = function(v)
        structShowPreview = v
        if v then
            structEnsureOrigin()
            structRenderPreview()
        else
            structClearPreview()
        end
    end
})

structTab:CreateToggle({
    Name = "Move Handles",
    Tooltip = "Show drag arrows so you can slide the ghost into place before building.",
    CurrentValue = false,
    Flag = "StructHandles",
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
    end
})

structTab:CreateSection("Shape")

structTab:CreateDropdown({
    Name = "Shape Mode",
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
        structRefreshPreview()
    end
})

local structBlockDropdown = structTab:CreateDropdown({
    Name = "Select Block",
    Options = structFetchBlocks(),
    CurrentOption = {"grass"},
    MultipleOptions = false,
    Flag = "StructBlock",
    Callback = function(v)
        structSelectedBlock = (typeof(v) == "table") and v[1] or v
        structRefreshPreview()
    end
})

structTab:CreateButton({
    Name = "Refresh Blocks",
    Callback = function()
        local list = structFetchBlocks()
        structBlockDropdown:Refresh(list)
        notify("Refreshed", #list .. " blocks found", 3)
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

structTab:CreateSlider({
    Name = "Radius / Length",
    Range = {3, 450},
    Increment = 3,
    CurrentValue = 30,
    Flag = "StructRadius",
    Callback = function(v) structRadius = v structHeightmap = nil structRefreshPreview() end
})

structTab:CreateSlider({
    Name = "Width",
    Range = {3, 450},
    Increment = 3,
    CurrentValue = 30,
    Flag = "StructWidth",
    Callback = function(v) structWidth = v structRefreshPreview() end
})

structTab:CreateSlider({
    Name = "Height",
    Range = {3, 450},
    Increment = 3,
    CurrentValue = 30,
    Flag = "StructHeight",
    Callback = function(v) structHeight = v structHeightmap = nil structRefreshPreview() end
})

structTab:CreateToggle({
    Name = "Hollow",
    CurrentValue = true,
    Flag = "StructHollow",
    Callback = function(v) structHollow = v structRefreshPreview() end
})

structTab:CreateToggle({
    Name = "Fill Steps",
    Tooltip = "Fill the vertical gaps between landscape height steps so walls are solid.",
    CurrentValue = false,
    Flag = "StructFillSteps",
    Callback = function(v) structFillSteps = v structRefreshPreview() end
})

structTab:CreateSlider({
    Name = "Thickness",
    Range = {1, 10},
    Suffix = "blk",
    Increment = 1,
    CurrentValue = 1,
    Flag = "StructThickness",
    Callback = function(v) structThickness = v structRefreshPreview() end
})

structTab:CreateSlider({
    Name = "Spiral Turns",
    Range = {0.25, 10},
    Increment = 0.25,
    CurrentValue = 2,
    Flag = "StructTurns",
    Callback = function(v) structTurns = v structRefreshPreview() end
})

structTab:CreateSection("Noise")

structTab:CreateSlider({
    Name = "Smoothness",
    Range = {5, 200},
    Increment = 1,
    CurrentValue = 25,
    Flag = "StructSmooth",
    Callback = function(v) structSmooth = v structHeightmap = nil structRefreshPreview() end
})

structTab:CreateSlider({
    Name = "Seed",
    Range = {1, 10000},
    Increment = 1,
    CurrentValue = 1,
    Flag = "StructSeed",
    Callback = function(v) structSeed = v structHeightmap = nil structRefreshPreview() end
})

structTab:CreateSection("Rotation", { Collapsible = true })

-- Three identical 0-360 axis sliders; only the target variable differs.
for _, axis in ipairs({
    { "Tilt (X)", "StructRX", function(v) structRX = v end },
    { "Spin (Y)", "StructRY", function(v) structRY = v end },
    { "Roll (Z)", "StructRZ", function(v) structRZ = v end },
}) do
    local name, flag, apply = axis[1], axis[2], axis[3]
    structTab:CreateSlider({
        Name = name,
        Range = {0, 360},
        Increment = 90,
        CurrentValue = 0,
        Suffix = "deg",
        Flag = flag,
        Callback = function(v)
            apply(v)
            structRefreshPreview()
        end
    })
end

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

structTab:CreateSection("Terraform", { Collapsible = true })

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

structTab:CreateSection("Generate")

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

structTab:CreateInput({
    Name = "Save As",
    PlaceholderText = "MyStructure",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        if text and text ~= "" then structFileName = text end
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

addObjectsSection(structTab, "Stamp Shape as Object", function()
    local blocks = structToBlocks()
    if #blocks == 0 then
        notifyWarn("Nothing To Stamp", "Set up a shape first", 3)
        return nil
    end
    return blocks, structMode
end)

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

cityTab:CreateParagraph({
    Title = "City Generator",
    Content = "Makes roads and drops a house on each lot. The same seed makes the same city. Then preview and build it."
})

cityTab:CreateSection("Layout", { Column = "left" })

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

cityTab:CreateSection("Houses", { Column = "left" })

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

cityTab:CreateSection("Terrain", { Column = "left" })

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

cityTab:CreateSection("Blocks", { Column = "right" })

-- One dropdown per material slot. Same shape for all of them, so they are
-- described as data and built in a loop.
local cityOpts = cityBlockOptions()
local cityBlockSlots = {
    { "Roads",      "stone",          "CityRoad",   function(v) cityRoadBlock   = v end },
    { "Walls",      "whiteBlock",     "CityWall",   function(v) cityWallBlock   = v end },
    { "Roofs",      "stone",          "CityRoof",   function(v) cityRoofBlock   = v end },
    { "Windows",    "glassBlockRed",  "CityWindow", function(v) cityWindowBlock = v end },
    { "Foundation", "stone",          "CityTrim",   function(v) cityTrimBlock   = v end },
    { "Yards",      "grass",          "CityYard",   function(v) cityYardBlock   = v end },
    { "Terrain",    "grass",          "CityGrass",  function(v) cityGrassBlock  = v end },
}

for _, slot in ipairs(cityBlockSlots) do
    local label, default, flag, apply = slot[1], slot[2], slot[3], slot[4]
    cityTab:CreateDropdown({
        Name = label,
        Options = cityOpts,
        CurrentOption = { default },
        MultipleOptions = false,
        Flag = flag,
        Callback = function(v)
            apply((typeof(v) == "table") and v[1] or v)
        end
    })
end

cityTab:CreateSection("Generate", { Column = "right" })

local cityStats = cityTab:CreateParagraph({
    Title = "City Stats",
    Content = "Tap Preview City (3D) or Generate to see the size."
})

cityTab:CreateInput({
    Name = "Save As",
    PlaceholderText = "MyCity",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) if t and t ~= "" then cityFileName = t end end
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
    local seen, b = {}, {}
    local f = ReplicatedStorage:FindFirstChild("blocks")
    if f then
        for _, v in ipairs(f:GetChildren()) do
            if not seen[v.Name] then seen[v.Name] = true table.insert(b, v.Name) end
        end
    end
    table.sort(b)
    if #b == 0 then b = { "whiteBlock", "stone" } end
    return b
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

platTab:CreateSection("Blocks")

local platOpts = platBlockOptions()

platTab:CreateDropdown({
    Name = "Pattern Block", Options = platOpts, CurrentOption = { "whiteBlock" },
    MultipleOptions = false, Flag = "PlatFill",
    Callback = function(v) platFillBlock = (typeof(v) == "table") and v[1] or v end
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
    Name = "Background Block", Options = platOpts, CurrentOption = { "stone" },
    MultipleOptions = false, Flag = "PlatBase",
    Callback = function(v) platBaseBlock = (typeof(v) == "table") and v[1] or v end
})

platTab:CreateSection("Generate")

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

platTab:CreateInput({
    Name = "Save As",
    PlaceholderText = "MyPlatform",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) if t and t ~= "" then platFileName = t end end
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

-- ── On-screen status overlay ─────────────────────────────────────────────────
-- Floating list in the corner so build state is visible with the panel closed.
Duvome:AddWatch("Building", function()
    if not isBuilding then return false end
    if progressTotal > 0 then
        return progressPlaced .. "/" .. progressTotal
    end
    return true
end)
Duvome:AddWatch("Preview", function() return isPreviewing end)
Duvome:AddWatch("Move Handles", function() return dragModeOn end)
Duvome:AddWatch("Block Brush", function() return blockSelMode end)
Duvome:AddWatch("File", function()
    return selectedFile and selectedFile:gsub("%.json$", "") or false
end)

pcall(function() Duvome:SetWatchVisible(true) end)