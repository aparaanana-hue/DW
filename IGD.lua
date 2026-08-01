repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualInput = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = workspace

local LocalPlayer = Players.LocalPlayer

local NetManaged = ReplicatedStorage
	:WaitForChild("rbxts_include")
	:WaitForChild("node_modules")
	:WaitForChild("@rbxts")
	:WaitForChild("net")
	:WaitForChild("out")
	:WaitForChild("_NetManaged")

local HASH_PREFIX = "\7\240\159\164\163\240\159\164\161\7\n\7\n\7\n"

local function findRemote(name)
	return NetManaged:FindFirstChild(name)
end

local Remotes = {
	Kill        = findRemote("fLafXsVXagmlXhlc/UlpaomJfNzwc"),
	BlockHit    = findRemote("CLIENT_BLOCK_HIT_REQUEST"),
	BlockPlace  = findRemote("CLIENT_BLOCK_PLACE_REQUEST"),
	CropHarvest = findRemote("CLIENT_HARVEST_CROP_REQUEST"),
	ToolPickup  = findRemote("CLIENT_TOOL_PICKUP_REQUEST"),
	FishCast    = findRemote("bybFwzowayukxnCeCx/ecxnnzkznjuFaqtmlrjrov"),
	FishFinish  = findRemote("bybFwzowayukxnCeCx/iNxxqhXmhuflLjt"),
	PetCollect  = findRemote("CLIENT_PET_ANIMAL"),
	Chest       = findRemote("CLIENT_CHEST_TRANSACTION"),
	VisitIsland = findRemote("CLIENT_VISIT_ISLAND_REQUEST"),
	PlowBlock   = findRemote("CLIENT_PLOW_BLOCK_REQUEST"),
	SwingSickle = findRemote("SwingSickle"),
	EatFood     = findRemote("CLIENT_EAT_FOOD"),
	TrimTree    = findRemote("CLIENT_TRIM_TREE_REQUEST"),
	WaterBlock  = findRemote("CLIENT_WATER_BLOCK"),
	Fertilize   = findRemote("CLIENT_FERTILIZE_BLOCK"),
	Pesticide   = findRemote("CLIENT_PESTICIDE_BLOCK"),
	DropTool    = findRemote("CLIENT_DROP_TOOL_REQUEST"),
	OpenJar     = findRemote("CLIENT_OPEN_JAR"),
	CollectHoney = findRemote("CLIENT_COLLECT_HONEY"),
	MilkCow     = findRemote("CLIENT_MILK_COW"),
	FeedAnimal  = findRemote("CLIENT_FEED_ANIMAL"),
	Flower      = findRemote("client_request_1"),
	Bank        = findRemote("TransactionBankBalance"),
	CatchInsect = findRemote("CLIENT_CATCH_INSECT"),
	WorkerDeposit = findRemote("CLIENT_BLOCK_WORKER_DEPOSIT_TOOL_REQUEST"),
	PirateIsland = findRemote("TravelPirateIsland"),
	Mail        = findRemote("Mailbox/ReadMail"),
	UseTeleporter = findRemote("Teleporters/UseTeleporter"),
	UseHub      = findRemote("Teleporters/UseHubTeleporter"),
	Spell       = findRemote("CLIENT_CAST_SPELL"),
	Bow         = findRemote("CLIENT_SHOOT_ARROW"),
	ThrowPotion = findRemote("CLIENT_THROW_POTION"),
	LaunchRocket = findRemote("CLIENT_LAUNCH_ROCKET"),
	PopConfetti = findRemote("CLIENT_POP_CONFETTI"),
	PartyHorn   = findRemote("CLIENT_PARTY_HORN"),
	Rageblade   = findRemote("CLIENT_RAGEBLADE"),
	UnlockedRecipes = findRemote("CLIENT_UNLOCKED_RECIPES_REQUEST"),
	QuestProgress = findRemote("CLIENT_QUEST_PROGRESS_REQUEST"),
	RedeemQuest = findRemote("CLIENT_REDEEM_QUEST_REQUEST"),
}

local BlocksFolder = ReplicatedStorage:FindFirstChild("Blocks")

local Hashes = {
	Kill        = { key = "IucpoZdgwp",            val = HASH_PREFIX .. "efmmgivC" },
	BlockHit    = { key = "Xoeoxuqilfgenamojfjmj", val = HASH_PREFIX .. "ohIstskUiftvgjy" },
	BlockPlace  = { key = "uwhiHAMdjExWka",        val = HASH_PREFIX .. "ffEgdldU" },
	CropHarvest = { key = "dZnpyRtxna",            val = HASH_PREFIX .. "sDahbvdxZludavlcoipDDMYasPlcm" },
	ToolPickup  = { key = "oesmuqhxddgxp",         val = HASH_PREFIX .. "gnerJcfMftkYelk" },
}

local function newGUID()
	return HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false)
end

local function getChar()
	return LocalPlayer.Character
end

local function getRoot()
	local c = LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
	local c = LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getBackpack()
	return LocalPlayer:FindFirstChildOfClass("Backpack")
end

local TOOL_TIERS = {
	sword = {
		"swordNetherite", "swordCrystal", "swordPlatinum", "swordRuby", "swordDiamond",
		"swordGold", "swordIron", "swordStone", "swordWood",
	},
	axe = {
		"axeNetherite", "axeCrystal", "axePlatinum", "axeRuby", "axeDiamond",
		"axeGold", "axeIron", "axeStone", "axeWood",
	},
	pickaxe = {
		"pickaxeNetherite", "pickaxeCrystal", "pickaxePlatinum", "pickaxeRuby", "pickaxeDiamond",
		"pickaxeGold", "pickaxeIron", "pickaxeStone", "pickaxeWood",
	},
	sickle = {
		"sickleNetherite", "sickleCrystal", "sicklePlatinum", "sickleRuby", "sickleDiamond",
		"sickleGold", "sickleIron", "sickleStone",
	},
	rod = {
		"fishingRodEnchanted", "fishingRodGold", "fishingRodIron", "fishingRod",
	},
	hammer = { "gregsHammer", "stoneHammer", "forgeHammer" },
}

local function findBestTool(kind)
	local list = TOOL_TIERS[kind]
	if not list then return nil end
	local char = getChar()
	local bp = getBackpack()
	for _, name in ipairs(list) do
		if char then
			local t = char:FindFirstChild(name)
			if t and t:IsA("Tool") then return t end
		end
		if bp then
			local t = bp:FindFirstChild(name)
			if t and t:IsA("Tool") then return t end
		end
	end
	if char then
		local current = char:FindFirstChildOfClass("Tool")
		if current then
			for _, name in ipairs(list) do
				if current.Name:find(kind) then return current end
			end
		end
	end
	return nil
end

local function equipTool(kind)
	local char = getChar()
	if not char then return false end
	local current = char:FindFirstChildOfClass("Tool")
	local list = TOOL_TIERS[kind]
	if not list then return false end
	if current then
		for _, name in ipairs(list) do
			if current.Name == name then return true end
		end
	end
	local tool = findBestTool(kind)
	if not tool then return false end
	if tool.Parent ~= char then
		tool.Parent = char
	end
	return true
end

local function safeChild(parent, name)
	return parent and parent:FindFirstChild(name)
end

local function getEntities()
	local wi = safeChild(Workspace, "WildernessIsland")
	return wi and wi:FindFirstChild("Entities")
end

local function getWildernessBlocks()
	return safeChild(Workspace, "WildernessBlocks")
end

local function getIslands()
	return safeChild(Workspace, "Islands")
end

local function getMyIsland()
	local islands = getIslands()
	if not islands then return nil end
	local uid = LocalPlayer.UserId
	for _, island in ipairs(islands:GetChildren()) do
		local owners = island:FindFirstChild("Owners")
		if owners and owners:FindFirstChild(tostring(uid)) then
			return island
		end
	end
	return islands:FindFirstChildWhichIsA("Model")
end

local function inSelection(value, name)
	if value == nil or name == nil then return false end
	if type(value) == "string" then return value == "all" or value == name end
	if type(value) ~= "table" then return false end
	if value[name] == true then return true end
	if value.all == true then return true end
	if value.All == true then return true end
	for k, v in pairs(value) do
		if k == name or v == name then return true end
	end
	return false
end

local function nearestPart(parts, fromPos)
	local best, bestDist = nil, math.huge
	for _, part in ipairs(parts) do
		local p = part.Position or (part.PrimaryPart and part.PrimaryPart.Position)
		if p then
			local d = (p - fromPos).Magnitude
			if d < bestDist then
				best, bestDist = part, d
			end
		end
	end
	return best, bestDist
end

local State = {
	AutoFarmMob       = false,
	AutoFarmBoss      = false,
	BossAutoSpawn     = false,
	MobKillAura       = false,
	SelectedMobs      = { slime = true },
	SelectedBoss      = "slimeKing",
	MobTpY            = 8,
	MobHitsPerSwing   = 5,
	MobSwingDelay     = 0.3,
	MobPreSwingDelay  = 0.5,
	AutoEquipBest     = true,

	AutoFarmCrop      = false,
	CropAura          = false,
	AutoReplaceCrop   = true,
	CropFastMode      = false,
	SelectedCrops     = { wheat = true },
	CropRange         = 30,
	CropDelay         = 0.4,
	UseSickle         = true,

	AutoFarmTree      = false,
	TreeAura          = false,
	SelectedTree      = "all",
	TreeHitDelay      = 0.05,
	TreeCycleDelay    = 0.2,

	AutoFarmRock      = false,
	RockAura          = false,
	SelectedRocks     = { Stone = true },
	RockHitDelay      = 0.05,

	AutoFarmFish      = false,
	FishWaitTime      = 10,
	FishCycleDelay    = 0.2,

	AutoCollectFruits = false,
	AutoFarmFlower    = false,
	AutoFarmChest     = false,
	AutoFarmPet       = false,
	AutoFarmHoney     = false,
	AutoMilkCow       = false,

	AutoCollectInsects = false,

	AutoFarmFlower    = false,
	FlowerAura        = false,

	AutoFarmSpirit    = false,
	AutoFarmVoid      = false,

	PlowAura          = false,
	UnPlowAura        = false,
	PlowRange         = 15,

	CropPlaceAura     = false,
	CropPlaceRange    = 25,
	CropPlaceType     = "wheat",

	UseResizeTool     = false,
	UseRotateTool     = false,
	SchematicName     = "Template",

	IslandFarmUserId  = LocalPlayer.UserId,
	AutoOwnIsland     = false,

	TeleportMethod    = "Tween",
	TeleportSpeed     = 50,
	TweenSpeed        = 30,
	StealthStepSize   = 80,
	WalkSpeed         = 30,
	JumpPower         = 50,
	NoclipEnabled     = false,
	FlyEnabled        = false,
	FlySpeed          = 1,

	BlockPrinterTP    = true,
	BlockPrinterAbort = false,
	BlockPrinterHits  = 1,
	BlockPrinterDelay = 0,
	BlockPrinterParallel = 5,

	StartBlock        = nil,
	EndBlock          = nil,
	CloneFolder       = nil,
}

local Stats = {
	MobsKilled    = 0,
	CropsHarvested = 0,
	TreesChopped  = 0,
	RocksMined    = 0,
	FishCaught    = 0,
	BlocksPlaced  = 0,
	BlocksDestroyed = 0,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- Duvome adapter for the Islands.God UI calls.
--
-- The hub was written against SoldoxD's library. Rather than rewrite 2000+
-- lines of logic, this implements that library's surface on top of Duvome, so
-- every CreateToggle/CreateSlider/... below runs unchanged.
--
-- Mapping:
--   CreateWindow  -> Duvome:MakeWindow
--   CreateTab     -> Window:MakeTab, with left/right columns
--   CreateSection -> a new section, alternating columns
--   Create*       -> the matching Duvome element on the current section
-- ═══════════════════════════════════════════════════════════════════════════
local Duvome = loadstring(game:HttpGet("https://raw.githubusercontent.com/aparaanana-hue/DW/refs/heads/main/DL.lua"))()
Duvome:Init()

local GuiLibrary = {}

-- Roblox fonts have no emoji glyphs, so they render as boxes. Strip them from
-- labels and keep a matching BuilderIcons name for the tab instead.
local TAB_ICONS = {
    Combat = "crosshairs", Farming = "backpack", Movement = "user",
    Building = "layout-fluid", Vending = "shopping-cart",
    Island = "house", Settings = "gear",
}

local function clean(text)
    local out = tostring(text or "")
    out = out:gsub("[\128-\255]", "")       -- drop non-ASCII (emoji)
    out = out:gsub("^%s+", ""):gsub("%s+$", "")
    return out
end

local _window

function GuiLibrary:CreateWindow(title, _size)
    _window = Duvome:MakeWindow({
        Name           = clean(title),
        IntroText      = clean(title),
        ConfigFolder   = "IslandsGod",
        SaveConfig     = true,
        AutoLoadConfig = false,
        IntroEnabled   = true,
        ShowIcon       = true,
    })
    return _window
end

function GuiLibrary:CreateTab(window, name)
    local label = clean(name)
    local container = (window or _window):MakeTab({
        Name = label, Icon = TAB_ICONS[label] or "list", Columns = true,
    })
    local tab = {
        _left = container:AddLeft(),
        _right = container:AddRight(),
        _count = 0,
        _section = nil,
    }
    -- something to hang elements on before any CreateSection call
    tab._section = tab._left:AddSection({ Name = label })
    return tab
end

local function host(tab)
    return tab._section or tab._left
end

function GuiLibrary:CreateSection(tab, title)
    tab._count = tab._count + 1
    local col = (tab._count % 2 == 1) and tab._right or tab._left
    tab._section = col:AddSection({ Name = clean(title), Collapsible = tab._count > 1 })
    return tab._section
end

function GuiLibrary:CreateLabel(tab, text)
    return host(tab):AddLabel(clean(text))
end

function GuiLibrary:CreateButton(tab, name, callback)
    return host(tab):AddButton({ Name = clean(name), Callback = callback or function() end })
end

function GuiLibrary:CreateToggle(tab, name, default, callback)
    return host(tab):AddToggle({
        Name = clean(name), Default = default and true or false,
        Callback = callback or function() end,
    })
end

function GuiLibrary:CreateSlider(tab, name, min, max, default, callback)
    -- the hub passes whole numbers throughout
    return host(tab):AddSlider({
        Name = clean(name), Min = min or 0, Max = max or 100,
        Increment = 1, Default = default or min or 0,
        Callback = callback or function() end,
    })
end

function GuiLibrary:CreateDropdown(tab, name, options, callback)
    return host(tab):AddDropdown({
        Name = clean(name), Options = options or {},
        Default = (options and options[1]) or "", Search = true,
        Callback = callback or function() end,
    })
end

-- The hub expects a table of selected names back, so multi-select results are
-- reshaped from Duvome's list into the { [name] = true } form it uses.
function GuiLibrary:CreateMultiSelect(tab, name, options, defaults, callback)
    return host(tab):AddDropdown({
        Name = clean(name), Options = options or {},
        Default = defaults or {}, MultiSelect = true, SelectAll = true, Search = true,
        Callback = function(list)
            local set = {}
            if type(list) == "table" then
                for _, v in ipairs(list) do set[v] = true end
            elseif list then
                set[list] = true
            end
            if callback then callback(set) end
        end,
    })
end

function GuiLibrary:CreateInput(tab, name, callback)
    return host(tab):AddTextbox({
        Name = clean(name), Default = "",
        Callback = callback or function() end,
    })
end

function GuiLibrary:CreateNotification(title, msg, duration, kind)
    Duvome:MakeNotification({
        Name = clean(title), Content = clean(msg),
        Time = duration or 3, Type = kind,
    })
end


local Window = GuiLibrary:CreateWindow("⚔️ Islands.God | Reborn", UDim2.fromOffset(620, 480))

local Tabs = {
	Combat   = GuiLibrary:CreateTab(Window, "⚔️ Combat"),
	Farming  = GuiLibrary:CreateTab(Window, "🌾 Farming"),
	Movement = GuiLibrary:CreateTab(Window, "✈️ Movement"),
	Building = GuiLibrary:CreateTab(Window, "🏗️ Building"),
	Vending  = GuiLibrary:CreateTab(Window, "🛒 Vending"),
	Island   = GuiLibrary:CreateTab(Window, "🏝️ Island"),
	Settings = GuiLibrary:CreateTab(Window, "⚙️ Settings"),
}

local function notify(title, msg, duration, kind)
	pcall(function()
		GuiLibrary:CreateNotification(title or "Info", msg or "", duration or 3, kind or "info")
	end)
end

local CloneFolder do
	local existing = Workspace:FindFirstChild("Clones_IslandsGod")
	if existing then
		CloneFolder = existing
	else
		CloneFolder = Instance.new("Model")
		CloneFolder.Name = "Clones_IslandsGod"
		CloneFolder.Parent = Workspace
	end
	State.CloneFolder = CloneFolder
end

local FOLDER_ROOT = "IslandsGod"
local FOLDER_SCHEMA = FOLDER_ROOT .. "/Schematica"

pcall(function()
	if not isfolder(FOLDER_ROOT) then makefolder(FOLDER_ROOT) end
	if not isfolder(FOLDER_SCHEMA) then makefolder(FOLDER_SCHEMA) end
end)

local function listSchematics()
	local out = {}
	local ok, files = pcall(listfiles, FOLDER_SCHEMA)
	if not ok or not files then return out end
	for _, full in ipairs(files) do
		local name = full:match("([^/\\]+)$") or full
		out[#out + 1] = name
	end
	return out
end

local function readSchematic(name)
	local path = FOLDER_SCHEMA .. "/" .. name
	local ok, data = pcall(readfile, path)
	if not ok then return nil end
	return data
end

local function writeSchematic(name, data)
	local path = FOLDER_SCHEMA .. "/" .. name
	return pcall(writefile, path, data)
end

local function deleteSchematic(name)
	local path = FOLDER_SCHEMA .. "/" .. name
	return pcall(delfile, path)
end

LocalPlayer.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end)

pcall(function()
	game:GetService("NetworkClient"):SetOutgoingKBPSLimit(math.huge)
end)

local Teleport = {} do
	local Active = nil
	local TweenWait = false

	local function setNoclip(on)
		local char = getChar()
		if not char then return end
		for _, c in ipairs(char:GetDescendants()) do
			if c:IsA("BasePart") then
				if on and c.CanCollide then c.CanCollide = false end
				if (not on) and (not c.CanCollide) then c.CanCollide = true end
			end
		end
	end

	local function tweenMethod(pos)
		if TweenWait then return end
		local root = getRoot()
		if not root then return end
		TweenWait = true
		setNoclip(true)
		local dist = (root.Position - pos).Magnitude
		local speed = State.TweenSpeed or 30
		local info = TweenInfo.new(dist / speed, Enum.EasingStyle.Linear)
		if Active then Active:Cancel() end
		Active = TweenService:Create(root, info, { CFrame = CFrame.new(pos) })
		Active:Play()
		Active.Completed:Connect(function()
			TweenWait = false
			setNoclip(false)
		end)
	end

	local function tweenV3Method(pos)
		local root = getRoot()
		local char = getChar()
		if not (root and char) then return end
		local dist = (root.Position - pos).Magnitude
		local speed = 15
		if dist < 30 then speed = 15 end
		if dist < 10 then speed = 20 end
		setNoclip(true)
		local completed = false
		if Active then Active:Cancel() end
		Active = TweenService:Create(root, TweenInfo.new(dist / speed), { CFrame = CFrame.new(pos) })
		task.spawn(function()
			repeat
				task.wait()
				local c, r = getChar(), getRoot()
				if c and r then
					pcall(function()
						c:SetPrimaryPartCFrame(CFrame.new(r.Position.X, pos.Y, r.Position.Z))
					end)
				end
			until completed
		end)
		Active:Play()
		Active.Completed:Connect(function()
			completed = true
			setNoclip(false)
		end)
	end

	local function instantMethod(pos)
		local root = getRoot()
		if not root then return end
		root.CFrame = CFrame.new(pos)
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end)
	end

	local function stealthMethod(pos)
		local root = getRoot()
		if not root then return end
		local startPos = root.Position
		local dist = (pos - startPos).Magnitude
		local stepSize = State.StealthStepSize or 80
		local steps = math.max(1, math.ceil(dist / stepSize))
		for i = 1, steps do
			if not getRoot() then return end
			root.CFrame = CFrame.new(startPos:Lerp(pos, i / steps))
			if i % 2 == 0 then task.wait() end
		end
		pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
	end

	function Teleport.go(target)
		local pos
		if typeof(target) == "Vector3" then
			pos = target
		elseif typeof(target) == "CFrame" then
			pos = target.Position
		elseif typeof(target) == "Instance" then
			if target:IsA("BasePart") then pos = target.Position
			elseif target:IsA("Model") then
				if target.PrimaryPart then pos = target.PrimaryPart.Position
				else pos = target:GetPivot().Position end
			end
		end
		if not pos then return end
		local method = State.TeleportMethod or "Tween"
		if method == "Instant"       then instantMethod(pos)
		elseif method == "Stealth"   then stealthMethod(pos)
		elseif method == "TweenV3"   then tweenV3Method(pos)
		elseif method == "PortalCF"  then instantMethod(pos)
		else tweenMethod(pos) end
	end

	function Teleport.cframe(cf)
		local root = getRoot()
		if not root then return end
		root.CFrame = cf
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end)
	end

	function Teleport.cancel()
		if Active then Active:Cancel(); Active = nil end
		TweenWait = false
		setNoclip(false)
	end

	function Teleport.isBusy() return TweenWait end
end

local Fly do
	local flying = false
	local bv, bg
	local conn

	local function disable()
		flying = false
		if conn then conn:Disconnect(); conn = nil end
		if bv then bv:Destroy(); bv = nil end
		if bg then bg:Destroy(); bg = nil end
		local hum = getHum()
		if hum then hum.PlatformStand = false end
	end

	local function enable()
		local root = getRoot()
		local hum = getHum()
		if not (root and hum) then return end
		disable()
		flying = true
		hum.PlatformStand = true
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Velocity = Vector3.zero
		bv.Parent = root
		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bg.P = 9000
		bg.CFrame = root.CFrame
		bg.Parent = root
		conn = RunService.RenderStepped:Connect(function()
			if not flying then return end
			local cam = Workspace.CurrentCamera
			local moveVec = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - cam.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + cam.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec = moveVec - Vector3.new(0, 1, 0) end
			bv.Velocity = moveVec * (50 * (State.FlySpeed or 1))
			bg.CFrame = cam.CFrame
		end)
	end

	Fly = { enable = enable, disable = disable, isOn = function() return flying end }
end

local Noclip do
	local conn
	local function on()
		if conn then return end
		conn = RunService.Stepped:Connect(function()
			local char = getChar()
			if not char then return end
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
			end
		end)
	end
	local function off()
		if conn then conn:Disconnect(); conn = nil end
	end
	Noclip = { on = on, off = off }
end

local BOSS_PROX = {
	slimeKing   = "slime_king_spawn",
	slimeQueen  = "slime_queen_spawn",
	desertBoss  = "desert_boss_spawn",
	golem       = "golem_spawn",
}

local function spawnBoss(bossName)
	local proxName = BOSS_PROX[bossName]
	if not proxName then return end
	local spawnPrefabs = safeChild(Workspace, "spawnPrefabs")
	local triggers = spawnPrefabs and spawnPrefabs:FindFirstChild("WildEventTriggers")
	local target = triggers and triggers:FindFirstChild(proxName)
	if not target then return end
	local prox = target:FindFirstChildOfClass("ProximityPrompt")
	if not prox then return end
	Teleport.go(target.Position)
	task.wait(0.2)
	pcall(function() fireproximityprompt(prox) end)
end

local ANTICONSOLEWARNLOGANIMATION = false
local LastMob

local function bigHash()
	return HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false)
end

local Combat = {} do
	local cooldown = false

	local function findNearestMob(pool, rootPos)
		local best, bestDist = nil, math.huge
		for _, m in ipairs(pool) do
			local hrp = m:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = (hrp.Position - rootPos).magnitude
				if d < bestDist then best, bestDist = m, d end
			end
		end
		return best
	end

	local function pickMob(isBoss)
		local entities = getEntities()
		local root = getRoot()
		if not (entities and root) then return nil end
		if isBoss then
			return entities:FindFirstChild(State.SelectedBoss or "")
		end
		local rootPos = root.Position
		local pool = {}
		for _, v in ipairs(entities:GetChildren()) do
			if v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") then
				if inSelection(State.SelectedMobs, v.Name) then
					pool[#pool + 1] = v
				end
			end
		end
		return findNearestMob(pool, rootPos)
	end

	local function fireAnimationDecoy()
		if ANTICONSOLEWARNLOGANIMATION then return end
		ANTICONSOLEWARNLOGANIMATION = true
		task.spawn(function()
			for _, v in ipairs(Players:GetChildren()) do
				if v and v.Character and v.Character:FindFirstChild("Humanoid") then
					local ok, anim = pcall(Instance.new, "Animation")
					if ok then
						anim.AnimationId = "rbxassetid://5328169716"
						local ok2, track = pcall(v.Character.Humanoid.LoadAnimation, v.Character.Humanoid, anim)
						if ok2 and track then
							pcall(function()
								track:Play()
								track:AdjustSpeed(0)
							end)
							task.spawn(function()
								task.wait(8)
								pcall(function() anim:Destroy() end)
							end)
						end
					end
				end
			end
			task.wait(1)
			ANTICONSOLEWARNLOGANIMATION = false
		end)
	end

	local function spamKill(mob)
		if not (mob and mob.Parent) then return end
		local hrp = mob:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		if State.AutoEquipBest then equipTool("sword") end
		LastMob = mob

		local YVALUE = State.MobTpY or 0
		local targetPos = hrp.Position + Vector3.new(0, YVALUE, 0)

		task.spawn(function() Teleport.go(targetPos) end)

		for _ = 1, 1 do
			if not (State.AutoFarmMob or State.AutoFarmBoss) then return end
			if not (mob.Parent and hrp.Parent) then return end

			Teleport.go(hrp.Position + Vector3.new(0, YVALUE, 0))

			if State.MobBookFarm then
				State.MobRemoteSpammingSelectedMob = mob
				State.MobRemoteSpamming = true
				return
			end

			fireAnimationDecoy()

			task.wait(0.5)

			local killRemote = Remotes.Kill or NetManaged:FindFirstChild("fLafXsVXagmlXhlc/UlpaomJfNzwc")
			if killRemote and not Remotes.Kill then Remotes.Kill = killRemote end
			if not killRemote then return end

			local args = {
				[1] = bigHash(),
				[2] = {
					[1] = {
						[Hashes.Kill.key] = Hashes.Kill.val,
						hitUnit = mob,
					},
				},
			}

			local hits = State.MobHitsPerSwing or 5
			local delay = State.MobSwingDelay or 0.3
			if State.RagebladeMobFarm then hits = 50; delay = 0 end

			for _ = 1, hits do
				if not (State.AutoFarmMob or State.AutoFarmBoss) then return end
				if not (mob.Parent and hrp.Parent) then return end
				pcall(function() killRemote:FireServer(unpack(args)) end)
				if delay > 0 then task.wait(delay) else task.wait() end
			end
		end

		Stats.MobsKilled = Stats.MobsKilled + 1
	end

	local KILLAURA_COOLDOWN = false
	local ANTI_AURA_DECOY = false

	local function auraAnimationDecoy()
		if ANTI_AURA_DECOY then return end
		ANTI_AURA_DECOY = true
		task.spawn(function()
			for _, v in ipairs(Players:GetChildren()) do
				if v and v.Character and v.Character:FindFirstChild("Humanoid") then
					local ok, anim = pcall(Instance.new, "Animation")
					if ok then
						anim.AnimationId = "rbxassetid://5328169716"
						local ok2, track = pcall(v.Character.Humanoid.LoadAnimation, v.Character.Humanoid, anim)
						if ok2 and track then
							pcall(function()
								track:Play()
								track:AdjustSpeed(0)
							end)
						end
					end
				end
			end
			task.wait(5)
			ANTI_AURA_DECOY = false
		end)
	end

	local function killAuraTick()
		if KILLAURA_COOLDOWN then return end
		KILLAURA_COOLDOWN = true

		auraAnimationDecoy()

		local entities = getEntities()
		local root = getRoot()
		if not (entities and root) then
			task.wait(0.4)
			KILLAURA_COOLDOWN = false
			return
		end

		local killRemote = Remotes.Kill or NetManaged:FindFirstChild("fLafXsVXagmlXhlc/UlpaomJfNzwc")
		if killRemote and not Remotes.Kill then Remotes.Kill = killRemote end
		if not killRemote then
			task.wait(0.4)
			KILLAURA_COOLDOWN = false
			return
		end

		local rootPos = root.Position
		local pool = {}
		local hasSelection = State.SelectedMobs and next(State.SelectedMobs) ~= nil
		for _, v in ipairs(entities:GetChildren()) do
			if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") then
				local hum = v.Humanoid
				if hum.Health > 0 then
					if not hasSelection or inSelection(State.SelectedMobs, v.Name) then
						pool[#pool + 1] = v
					end
				end
			end
		end

		local best, bestDist = nil, math.huge
		for _, m in ipairs(pool) do
			local d = (m.HumanoidRootPart.Position - rootPos).magnitude
			if d < bestDist then best, bestDist = m, d end
		end

		if best then
			local args = {
				[1] = bigHash(),
				[2] = { [1] = { [Hashes.Kill.key] = Hashes.Kill.val, hitUnit = best } },
			}
			pcall(function() killRemote:FireServer(unpack(args)) end)
		end

		task.wait(State.MobKillAuraDelay or 0.4)
		KILLAURA_COOLDOWN = false
	end

	RunService.RenderStepped:Connect(function()
		if State.AutoFarmMob or State.AutoFarmBoss then
			if LastMob and LastMob.Parent then
				local hum = LastMob:FindFirstChild("Humanoid")
				local hrp = LastMob:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and hrp then
					Teleport.go(hrp.Position + Vector3.new(0, State.MobTpY or 0, 0))
				end
			end
		end
	end)

	function Combat.tick()
		if cooldown then return end
		if State.AutoFarmMob or State.AutoFarmBoss then
			cooldown = true
			local target = pickMob(State.AutoFarmBoss)
			if target then
				spamKill(target)
			elseif State.AutoFarmBoss and State.BossAutoSpawn then
				spawnBoss(State.SelectedBoss)
				task.wait(2)
			end
			cooldown = false
		elseif State.MobKillAura then
			cooldown = true
			killAuraTick()
			task.wait(0.2)
			cooldown = false
		end
	end
end

local Crops = {} do
	local busy = false

	local function harvestRemote(model)
		if not Remotes.CropHarvest then return end
		pcall(function()
			Remotes.CropHarvest:InvokeServer({
				[Hashes.CropHarvest.key] = Hashes.CropHarvest.val,
				player = LocalPlayer,
				model = model,
			})
		end)
	end

	local function placeRemote(cframe, blockType)
		if not Remotes.BlockPlace then return end
		pcall(function()
			Remotes.BlockPlace:InvokeServer({
				[Hashes.BlockPlace.key] = Hashes.BlockPlace.val,
				upperBlock = false,
				cframe = cframe,
				blockType = blockType,
			})
		end)
	end

	local function sickleSwing(crops)
		if not Remotes.SwingSickle then return end
		local tool = "sickleStone"
		local char = getChar()
		local equipped = char and char:FindFirstChildOfClass("Tool")
		if equipped then tool = equipped.Name end
		pcall(function()
			Remotes.SwingSickle:InvokeServer(tool, crops)
		end)
	end

	local function gatherCrops(island, root)
		local blocks = island:FindFirstChild("Blocks")
		if not blocks then return {} end
		local rootPos = root.Position
		local list = {}
		for _, b in ipairs(blocks:GetChildren()) do
			if inSelection(State.SelectedCrops, b.Name) then
				local mesh = b:FindFirstChildWhichIsA("MeshPart")
				local harvestable = mesh and mesh:FindFirstChild("Harvestable")
				if harvestable and harvestable.Value then
					if (b.Position - rootPos).Magnitude < State.CropRange then
						list[#list + 1] = b
					end
				end
			end
		end
		return list
	end

	function Crops.tick()
		if busy then return end
		if not (State.AutoFarmCrop or State.CropAura) then return end
		busy = true
		local island = getMyIsland()
		local root = getRoot()
		if not (island and root) then busy = false; return end

		local crops = gatherCrops(island, root)
		if #crops == 0 then
			busy = false
			task.wait(0.3)
			return
		end

		if State.AutoEquipBest and State.UseSickle then equipTool("sickle") end

		if State.AutoFarmCrop and crops[1] then
			Teleport.go(crops[1].Position + Vector3.new(0, 4, 0))
			task.wait(0.2)
		end

		if State.UseSickle and Remotes.SwingSickle then
			sickleSwing(crops)
			if State.AutoReplaceCrop then
				task.wait(0.15)
				for _, c in ipairs(crops) do
					placeRemote(c.CFrame, c.Name)
				end
			end
		else
			for _, c in ipairs(crops) do
				harvestRemote(c)
			end
			if State.AutoReplaceCrop then
				task.wait(0.1)
				for _, c in ipairs(crops) do
					placeRemote(c.CFrame, c.Name)
				end
			end
		end

		Stats.CropsHarvested = Stats.CropsHarvested + #crops
		task.wait(State.CropDelay)
		busy = false
	end
end

local Trees = {} do
	local busy = false

	function Trees.tick()
		if busy then return end
		if not (State.AutoFarmTree or State.TreeAura) then return end
		busy = true
		local island = getMyIsland()
		local root = getRoot()
		if not (island and root and Remotes.BlockHit) then busy = false; return end
		local blocks = island:FindFirstChild("Blocks")
		if not blocks then busy = false; return end

		local sel = State.SelectedTree or "all"
		local rootPos = root.Position
		local target, bestDist = nil, math.huge

		for _, b in ipairs(blocks:GetChildren()) do
			local nm = b.Name
			local match = false
			if sel == "all" or sel == "tree" then
				match = nm:sub(1, 4) == "tree"
			elseif sel == "Oak" then
				match = nm == "tree" or nm:match("^tree%d+$") ~= nil
			else
				match = nm:find(sel, 1, true) ~= nil
			end
			if match then
				local d = (b.Position - rootPos).Magnitude
				if d < bestDist then
					target, bestDist = b, d
				end
			end
		end

		if not target then
			busy = false
			task.wait(0.3)
			return
		end

		if State.AutoEquipBest then equipTool("axe") end

		if State.AutoFarmTree then
			Teleport.go(target.Position + Vector3.new(0, 0, 6))
			task.wait(0.2)
		end

		local hitPart = target:FindFirstChild("trunk") or target:FindFirstChildWhichIsA("MeshPart")
		if not hitPart then busy = false; return end

		local args = {
			[Hashes.BlockHit.key] = Hashes.BlockHit.val,
			part = hitPart,
			block = target,
			norm = Vector3.new(0, 1, 0),
			pos = target.Position,
		}

		for _ = 1, 30 do
			if not (State.AutoFarmTree or State.TreeAura) then break end
			if not (target.Parent and (target:FindFirstChild("trunk") or target:FindFirstChildWhichIsA("MeshPart"))) then break end
			pcall(function() Remotes.BlockHit:InvokeServer(args) end)
			task.wait(State.TreeHitDelay)
		end

		Stats.TreesChopped = Stats.TreesChopped + 1
		task.wait(State.TreeCycleDelay)
		busy = false
	end
end

local Rocks = {} do
	local busy = false

	function Rocks.tick()
		if busy then return end
		if not (State.AutoFarmRock or State.RockAura) then return end
		busy = true
		local wb = getWildernessBlocks()
		local root = getRoot()
		if not (wb and root and Remotes.BlockHit) then busy = false; return end

		local rootPos = root.Position
		local target, bestDist = nil, math.huge
		for _, b in ipairs(wb:GetChildren()) do
			local strippedName = (b.Name:gsub("rock", ""))
			if inSelection(State.SelectedRocks, b.Name) or inSelection(State.SelectedRocks, strippedName) then
				local d = (b.Position - rootPos).Magnitude
				if d < bestDist then target, bestDist = b, d end
			end
		end

		if not target then busy = false; task.wait(0.3); return end

		local hitPart = target:FindFirstChild("0") or target:FindFirstChild("1") or target:FindFirstChildWhichIsA("BasePart")
		if not hitPart then busy = false; return end

		if State.AutoEquipBest then equipTool("pickaxe") end

		if State.AutoFarmRock then
			Teleport.go(target.Position + Vector3.new(0, 4, 0))
			task.wait(0.15)
		end

		local args = {
			[Hashes.BlockHit.key] = Hashes.BlockHit.val,
			part = hitPart,
			block = target,
			norm = Vector3.new(0, 1, 0),
			pos = hitPart.Position,
		}

		for _ = 1, 40 do
			if not (State.AutoFarmRock or State.RockAura) then break end
			if not target.Parent then break end
			pcall(function() Remotes.BlockHit:InvokeServer(args) end)
			task.wait(State.RockHitDelay)
		end

		Stats.RocksMined = Stats.RocksMined + 1
		busy = false
	end
end

local FishFarm = {} do
	local busy = false

	function FishFarm.tick()
		if busy or not State.AutoFarmFish then return end
		local root = getRoot()
		if not (root and Remotes.FishCast) then return end
		busy = true

		if State.AutoEquipBest then equipTool("rod") end

		local lookVec = root.CFrame.LookVector
		local castArgs = { {
			playerLocation = root.Position,
			direction = lookVec,
			strength = math.random(70, 100) / 100,
		} }
		pcall(function() Remotes.FishCast:FireServer(newGUID(), castArgs) end)

		task.wait(State.FishWaitTime)

		if Remotes.FishFinish then
			pcall(function() Remotes.FishFinish:FireServer({ success = true }) end)
		end

		local hum = getHum()
		if hum then hum.Jump = true end

		Stats.FishCaught = Stats.FishCaught + 1
		task.wait(State.FishCycleDelay)
		busy = false
	end
end

local Pets = {} do
	local busy = false

	function Pets.tick()
		if busy or not State.AutoFarmPet then return end
		busy = true
		local island = getMyIsland()
		if not (island and Remotes.PetCollect) then busy = false; return end
		local blocks = island:FindFirstChild("Blocks")
		if not blocks then busy = false; return end

		local root = getRoot()
		if not root then busy = false; return end

		for _, b in ipairs(blocks:GetChildren()) do
			local animals = b:FindFirstChild("Animals") or b:FindFirstChild("AnimalContainer")
			if animals then
				for _, animal in ipairs(animals:GetChildren()) do
					pcall(function()
						Remotes.PetCollect:InvokeServer({ animal = animal })
					end)
				end
			end
		end
		task.wait(2)
		busy = false
	end
end

local Chests = {} do
	local busy = false

	function Chests.tick()
		if busy or not State.AutoFarmChest then return end
		busy = true
		local island = getMyIsland()
		if not (island and Remotes.Chest) then busy = false; return end
		local blocks = island:FindFirstChild("Blocks")
		if not blocks then busy = false; return end

		for _, chest in ipairs(blocks:GetChildren()) do
			local contents = chest:FindFirstChild("Contents")
			if contents then
				for _, tool in ipairs(contents:GetChildren()) do
					local amount = tool:FindFirstChild("Amount")
					if amount then
						pcall(function()
							Remotes.Chest:InvokeServer({
								chest = chest,
								tool = tool,
								amount = amount.Value,
								action = "withdraw",
								player_tracking_category = "join_from_web",
							})
						end)
					end
				end
			end
		end
		task.wait(3)
		busy = false
	end
end

local Fruits = {} do
	local busy = false

	function Fruits.tick()
		if busy or not State.AutoCollectFruits then return end
		busy = true
		local island = getMyIsland()
		local root = getRoot()
		if not (island and root and Remotes.ToolPickup) then busy = false; return end
		local blocks = island:FindFirstChild("Blocks")
		if not blocks then busy = false; return end

		local rootPos = root.Position
		for _, b in ipairs(blocks:GetChildren()) do
			local fl = b:FindFirstChild("FruitLocations")
			if fl then
				for _, spot in ipairs(fl:GetChildren()) do
					if spot:IsA("BasePart") then
						local tool = spot:FindFirstChildWhichIsA("Tool")
						if tool and (spot.Position - rootPos).Magnitude < 30 then
							pcall(function()
								Remotes.ToolPickup:InvokeServer({
									[Hashes.ToolPickup.key] = Hashes.ToolPickup.val,
									tool = tool,
								})
							end)
						end
					end
				end
			end
		end
		task.wait(1)
		busy = false
	end
end

local Honey = {} do
	local busy = false
	function Honey.tick()
		if busy or not State.AutoFarmHoney then return end
		busy = true
		local island = getMyIsland()
		if not (island and Remotes.CollectHoney) then busy = false; return end
		local blocks = island:FindFirstChild("Blocks")
		if not blocks then busy = false; return end
		for _, b in ipairs(blocks:GetChildren()) do
			if b.Name == "beeHive" or b.Name:find("beehive") then
				pcall(function() Remotes.CollectHoney:InvokeServer({ block = b }) end)
			end
		end
		task.wait(3)
		busy = false
	end
end

local Milk = {} do
	local busy = false
	function Milk.tick()
		if busy or not State.AutoMilkCow then return end
		busy = true
		local entities = getEntities()
		if not (entities and Remotes.MilkCow) then busy = false; return end
		for _, ent in ipairs(entities:GetChildren()) do
			if ent.Name == "cow" or ent.Name == "yak" then
				pcall(function() Remotes.MilkCow:InvokeServer({ animal = ent }) end)
			end
		end
		task.wait(5)
		busy = false
	end
end

local Flower = {} do
	local busy = false
	function Flower.tick()
		if busy then return end
		if not (State.AutoFarmFlower or State.FlowerAura) then return end
		busy = true
		local island = getMyIsland()
		if not (island and Remotes.Flower) then busy = false; return end
		local blocks = island:FindFirstChild("Blocks")
		if not blocks then busy = false; return end
		local root = getRoot()
		if not root then busy = false; return end
		local range = State.FlowerAura and 60 or math.huge
		local rootPos = root.Position
		for _, b in ipairs(blocks:GetChildren()) do
			if b:FindFirstChild("flower") then
				if (b.Position - rootPos).Magnitude < range then
					if State.AutoFarmFlower then
						Teleport.go(b.Position)
						task.wait(0.2)
					end
					pcall(function() Remotes.Flower:InvokeServer({ flower = b }) end)
				end
			end
		end
		task.wait(1)
		busy = false
	end
end

local Plow = {} do
	local busy = false
	function Plow.tick()
		if busy then return end
		if not (State.PlowAura or State.UnPlowAura) then return end
		busy = true
		local island = getMyIsland()
		local root = getRoot()
		if not (island and root and Remotes.PlowBlock) then busy = false; return end
		local blocks = island:FindFirstChild("Blocks")
		if not blocks then busy = false; return end
		local targetName = State.PlowAura and "grass" or "soil"
		local rootPos = root.Position
		local range = State.PlowRange or 15
		for _, b in ipairs(blocks:GetChildren()) do
			if b.Name == targetName and (b.Position - rootPos).Magnitude < range then
				pcall(function() Remotes.PlowBlock:InvokeServer({ block = b }) end)
			end
		end
		task.wait(0.3)
		busy = false
	end
end

local CropPlaceAura = {} do
	local busy = false
	function CropPlaceAura.tick()
		if busy or not State.CropPlaceAura then return end
		busy = true
		local island = getMyIsland()
		local root = getRoot()
		if not (island and root and Remotes.BlockPlace) then busy = false; return end
		local blocks = island:FindFirstChild("Blocks")
		if not blocks then busy = false; return end
		local rootPos = root.Position
		local range = State.CropPlaceRange or 25
		local blockType = State.CropPlaceType or "wheat"
		for _, b in ipairs(blocks:GetChildren()) do
			if b.Name == "soil" and (b.Position - rootPos).Magnitude < range then
				pcall(function()
					Remotes.BlockPlace:InvokeServer({
						[Hashes.BlockPlace.key] = Hashes.BlockPlace.val,
						upperBlock = true,
						cframe = b.CFrame + Vector3.new(0, 3, 0),
						blockType = blockType,
					})
				end)
			end
		end
		task.wait(0.5)
		busy = false
	end
end

local SpiritFarm = {} do
	local busy = false
	function SpiritFarm.tick()
		if busy or not State.AutoFarmSpirit then return end
		busy = true
		local entities = getEntities()
		local root = getRoot()
		if not (entities and root and Remotes.Kill) then busy = false; return end
		local rootPos = root.Position
		local target, bestDist = nil, math.huge
		for _, ent in ipairs(entities:GetChildren()) do
			if ent.Name == "spirit" or ent.Name == "spiritParasite" or ent.Name == "spiritCrop" then
				local hrp = ent:FindFirstChild("HumanoidRootPart") or ent.PrimaryPart
				if hrp then
					local d = (hrp.Position - rootPos).Magnitude
					if d < bestDist then target, bestDist = ent, d end
				end
			end
		end
		if target then
			local hrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
			if hrp then
				Teleport.go(hrp.Position + Vector3.new(0, 4, 0))
				task.wait(0.2)
				local reqId = newGUID()
				local args = { { [Hashes.Kill.key] = Hashes.Kill.val, hitUnit = target } }
				for _ = 1, 10 do
					if not target.Parent then break end
					pcall(function() Remotes.Kill:FireServer(reqId, args) end)
					task.wait(0.1)
				end
			end
		end
		task.wait(0.3)
		busy = false
	end
end

local VoidFarm = {} do
	local busy = false
	function VoidFarm.tick()
		if busy or not State.AutoFarmVoid then return end
		busy = true
		local entities = getEntities()
		local root = getRoot()
		if not (entities and root and Remotes.Kill) then busy = false; return end
		local rootPos = root.Position
		local target, bestDist = nil, math.huge
		for _, ent in ipairs(entities:GetChildren()) do
			if ent.Name == "voidParasite" or ent.Name == "voidDog" or ent.Name == "voidPup" then
				local hrp = ent:FindFirstChild("HumanoidRootPart") or ent.PrimaryPart
				if hrp then
					local d = (hrp.Position - rootPos).Magnitude
					if d < bestDist then target, bestDist = ent, d end
				end
			end
		end
		if target then
			local hrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
			if hrp then
				Teleport.go(hrp.Position + Vector3.new(0, 4, 0))
				task.wait(0.2)
				local reqId = newGUID()
				local args = { { [Hashes.Kill.key] = Hashes.Kill.val, hitUnit = target } }
				for _ = 1, 12 do
					if not target.Parent then break end
					pcall(function() Remotes.Kill:FireServer(reqId, args) end)
					task.wait(0.08)
				end
			end
		end
		task.wait(0.3)
		busy = false
	end
end

local Vending = {} do
	local busy = false
	local function findVendingMachines()
		local out = {}
		local islands = getIslands()
		if not islands then return out end
		for _, isle in ipairs(islands:GetChildren()) do
			local blocks = isle:FindFirstChild("Blocks")
			if blocks then
				for _, b in ipairs(blocks:GetChildren()) do
					if b.Name:find("vending") or b:FindFirstChild("VendingMachine") then
						out[#out + 1] = b
					end
				end
			end
		end
		return out
	end

	function Vending.scanOnce()
		if not State.VendingTarget or State.VendingTarget == "" then return end
		local machines = findVendingMachines()
		local matched = 0
		for _, m in ipairs(machines) do
			local contents = m:FindFirstChild("Contents") or m:FindFirstChild("WorkerContents")
			if contents then
				for _, tool in ipairs(contents:GetChildren()) do
					if tool.Name:find(State.VendingTarget) then
						local priceVal = m:FindFirstChild("Price") or tool:FindFirstChild("Price")
						local price = priceVal and priceVal.Value or 0
						if not State.VendingMaxPrice or price <= State.VendingMaxPrice then
							matched = matched + 1
						end
					end
				end
			end
		end
		notify("Vending", string.format("Found %d matches in %d machines", matched, #machines), 4, "info")
	end

	function Vending.tick()
		if busy or not State.VendingEnabled then return end
		busy = true
		Vending.scanOnce()
		task.wait(5)
		busy = false
	end
end

local Bank = {}
function Bank.deposit(amount)
	if not (Remotes.Bank and amount and amount > 0) then return end
	pcall(function()
		Remotes.Bank:FireServer(newGUID(), { {
			accountType = "PERSONAL",
			transferType = "DEPOSIT",
			amount = amount,
		} })
	end)
end
function Bank.withdraw(amount)
	if not (Remotes.Bank and amount and amount > 0) then return end
	pcall(function()
		Remotes.Bank:FireServer(newGUID(), { {
			accountType = "PERSONAL",
			transferType = "WITHDRAWAL",
			amount = amount,
		} })
	end)
end

local Schematica = {}
do
	local function getNewPartBlocks()
		local newPart = Workspace:FindFirstChild("NewPart")
		if not newPart then return nil, "No selection box (use Resize Tool)" end
		local island = getMyIsland()
		local blocks = island and island:FindFirstChild("Blocks")
		if not blocks then return nil, "Could not locate island Blocks folder" end
		local pos, size = newPart.Position, newPart.Size
		local half = size / 2
		local minP, maxP = pos - half, pos + half
		local out = {}
		for _, b in ipairs(blocks:GetChildren()) do
			local p = b.Position
			if p.X >= minP.X and p.X <= maxP.X
				and p.Y >= minP.Y and p.Y <= maxP.Y
				and p.Z >= minP.Z and p.Z <= maxP.Z
			then
				out[#out + 1] = b
			end
		end
		return out
	end

	function Schematica.save(name)
		if not name or name == "" then return false, "Name required" end
		local found, err = getNewPartBlocks()
		if not found then return false, err end
		if #found == 0 then return false, "No blocks in selection" end
		local data = { Blocks = {} }
		for _, b in ipairs(found) do
			data.Blocks[b.Name] = data.Blocks[b.Name] or {}
			table.insert(data.Blocks[b.Name], { C = { b.CFrame:GetComponents() } })
		end
		local encoded = HttpService:JSONEncode(data)
		local ok = writeSchematic(name, encoded)
		return ok, ok and ("Saved %d blocks"):format(#found) or "Write failed"
	end

	function Schematica.load(name)
		if not name or name == "" then return false, "Name required" end
		if not BlocksFolder then return false, "ReplicatedStorage.Blocks missing" end
		local raw = readSchematic(name)
		if not raw then return false, "Could not read file" end
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok or type(data) ~= "table" then return false, "Bad JSON" end
		if not data.Blocks then return false, "No Blocks in schematic" end
		for _, child in ipairs(CloneFolder:GetChildren()) do child:Destroy() end
		local total = 0
		for blockName, list in pairs(data.Blocks) do
			local resolvedName = blockName
			if blockName == "dirt" then resolvedName = "soil" end
			local template = BlocksFolder:FindFirstChild(resolvedName)
			local root = template and template:FindFirstChild("Root")
			if root then
				for _, entry in ipairs(list) do
					local clone = root:Clone()
					clone.Transparency = 0.5
					clone.CanCollide = false
					clone.Anchored = true
					clone.Name = resolvedName
					if entry.C and #entry.C >= 12 then
						clone.CFrame = CFrame.new(table.unpack(entry.C))
					end
					clone.Parent = CloneFolder
					total = total + 1
				end
			end
		end
		return true, ("Loaded %d ghost blocks"):format(total)
	end

	function Schematica.unload()
		for _, child in ipairs(CloneFolder:GetChildren()) do child:Destroy() end
	end

	function Schematica.printLoaded()
		if not Remotes.BlockPlace then return false, "Place remote missing" end
		local clones = CloneFolder:GetChildren()
		if #clones == 0 then return false, "Nothing loaded" end
		State.BlockPrinterAbort = false
		local startTime = tick()
		local placed = 0
		for _, c in ipairs(clones) do
			if State.BlockPrinterAbort then break end
			if State.BlockPrinterTP then
				Teleport.go(c.Position + Vector3.new(0, 8, 0))
				local deadline = tick() + 0.3
				while tick() < deadline do
					local r = getRoot()
					if not r then break end
					if (r.Position - c.Position).Magnitude < 30 then break end
					task.wait(0.05)
				end
			end
			pcall(function()
				Remotes.BlockPlace:InvokeServer({
					[Hashes.BlockPlace.key] = Hashes.BlockPlace.val,
					upperBlock = false,
					cframe = c.CFrame,
					blockType = c.Name,
				})
			end)
			placed = placed + 1
			Stats.BlocksPlaced = Stats.BlocksPlaced + 1
			if State.BlockPrinterDelay > 0 then task.wait(State.BlockPrinterDelay) end
		end
		local elapsed = math.floor((tick() - startTime) * 10) / 10
		return true, ("Printed %d in %.1fs"):format(placed, elapsed)
	end
end

local ResizeTool = {}
do
	local selectionBox, handles, mainPart
	local mouseDownConn, dragConn, downConn
	local previousDistance
	local changeMode = false

	local function disable()
		if selectionBox then selectionBox:Destroy(); selectionBox = nil end
		if handles then handles:Destroy(); handles = nil end
		if mouseDownConn then mouseDownConn:Disconnect(); mouseDownConn = nil end
		if dragConn then dragConn:Disconnect(); dragConn = nil end
		if downConn then downConn:Disconnect(); downConn = nil end
		for _, n in ipairs({ "NewPart", "Part_R", "Part_L" }) do
			local old = Workspace:FindFirstChild(n)
			if old then old:Destroy() end
		end
		mainPart = nil
		State.UseResizeTool = false
	end

	local function placeCornerMarkers(part)
		local pos, size = part.Position, part.Size
		for _, info in ipairs({
			{ name = "Part_R", offset = Vector3.new(1, 1, 1) },
			{ name = "Part_L", offset = Vector3.new(-1, -1, -1) },
		}) do
			local old = Workspace:FindFirstChild(info.name)
			if old then old:Destroy() end
			local marker = Instance.new("Part")
			marker.Name = info.name
			marker.Size = Vector3.new(3, 3, 3)
			marker.Anchored = true
			marker.CanCollide = false
			marker.Transparency = 1
			marker.Position = pos + info.offset * (size / 2 - Vector3.new(1.5, 1.5, 1.5))
			marker.Parent = Workspace
		end
		State.StartBlock = Workspace:FindFirstChild("Part_L")
		State.EndBlock = Workspace:FindFirstChild("Part_R")
	end

	local function onDragDown()
		previousDistance = 0
	end

	local function onDrag(face, distance)
		if not (handles and handles.Adornee) then return end
		local delta = distance - (previousDistance or 0)
		if math.abs(delta) < 3 then return end
		local sizeDelta = math.floor(delta / 3 + 0.5) * 3
		local part = handles.Adornee
		local oldSize, oldPos = part.Size, part.Position
		if part:Resize(face, sizeDelta) then
			if part.Size.X < 3 or part.Size.Y < 3 or part.Size.Z < 3 then
				part.Size, part.Position = oldSize, oldPos
			else
				placeCornerMarkers(part)
			end
			previousDistance = distance
		end
	end

	local function onMouseClick(mouse)
		if not changeMode then return end
		changeMode = false
		local target = mouse.Target
		if not target then
			selectionBox.Adornee = nil
			handles.Adornee = nil
			return
		end
		if not target:FindFirstChild("Health") then return end
		if target.Size.X ~= 3 then return end
		local np = Workspace:FindFirstChild("NewPart")
		if not np then
			np = Instance.new("Part")
			np.Name = "NewPart"
			np.Parent = Workspace
		end
		np.Transparency = 1
		np.Anchored = true
		np.CanCollide = false
		np.CastShadow = false
		np.Material = Enum.Material.Neon
		np.Size = target.Size
		np.Position = target.Position
		selectionBox.Adornee = np
		handles.Adornee = np
		handles.Faces = np.ResizeableFaces
		mainPart = np
		placeCornerMarkers(np)
	end

	function ResizeTool.enable()
		if selectionBox then return end
		selectionBox = Instance.new("SelectionBox")
		selectionBox.Color = BrickColor.Blue()
		selectionBox.Adornee = nil
		selectionBox.Parent = game:GetService("CoreGui")
		handles = Instance.new("Handles")
		handles.Color3 = Color3.fromRGB(65, 105, 225)
		handles.Style = Enum.HandlesStyle.Movement
		handles.Adornee = nil
		handles.Parent = game:GetService("CoreGui")
		downConn = handles.MouseButton1Down:Connect(onDragDown)
		dragConn = handles.MouseDrag:Connect(onDrag)
		local mouse = LocalPlayer:GetMouse()
		mouseDownConn = mouse.Button1Down:Connect(function() onMouseClick(mouse) end)
		changeMode = true
		State.UseResizeTool = true
	end

	function ResizeTool.disable()
		disable()
	end

	function ResizeTool.changeMode()
		changeMode = true
	end

	function ResizeTool.getRegion()
		local np = Workspace:FindFirstChild("NewPart")
		if not np then return nil end
		return np.Position, np.Size, np
	end
end

task.spawn(function()
	while true do
		Combat.tick()
		task.wait()
	end
end)

task.spawn(function()
	while true do
		Crops.tick()
		Trees.tick()
		Rocks.tick()
		FishFarm.tick()
		SpiritFarm.tick()
		VoidFarm.tick()
		Plow.tick()
		CropPlaceAura.tick()
		task.wait(0.05)
	end
end)

task.spawn(function()
	while true do
		Pets.tick()
		Chests.tick()
		Fruits.tick()
		Honey.tick()
		Milk.tick()
		Flower.tick()
		Vending.tick()
		task.wait(0.5)
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		local hum = getHum()
		if hum then
			if State.WalkSpeed and State.WalkSpeed > 0 then hum.WalkSpeed = State.WalkSpeed end
			if State.JumpPower and State.JumpPower > 0 then
				hum.UseJumpPower = true
				hum.JumpPower = State.JumpPower
			end
		end
	end
end)

local Building = {}

local SECTION = function(tab, title) GuiLibrary:CreateSection(tab, title) end

local function buildCombatTab()
	local tab = Tabs.Combat
	SECTION(tab, "👾 Mob Auto Farm")

	local MOB_LIST = {
		"slime", "buffalkor", "wraithBoss", "wizardLizard", "Skorpions",
		"magmaBlob", "magmaGolem", "skeletonPirate", "voidPup", "voidDog",
		"cow", "yak", "sheep", "chicken", "pig",
	}
	GuiLibrary:CreateMultiSelect(tab, "Selected Mobs", MOB_LIST, { "slime" }, function(selected)
		State.SelectedMobs = selected
	end)

	GuiLibrary:CreateSlider(tab, "Y Offset", -20, 20, 8, function(v)
		State.MobTpY = v
	end)

	GuiLibrary:CreateSlider(tab, "Hits per Swing", 1, 30, 8, function(v)
		State.MobHitsPerSwing = math.floor(v)
	end)

	GuiLibrary:CreateSlider(tab, "Swing Delay (s)", 0.05, 1.0, 0.12, function(v)
		State.MobSwingDelay = v
	end)

	GuiLibrary:CreateToggle(tab, "🟢 Auto Farm", false, function(v)
		State.AutoFarmMob = v
	end)

	GuiLibrary:CreateToggle(tab, "💀 Kill Aura", false, function(v)
		State.MobKillAura = v
	end)

	SECTION(tab, "👹 Boss Auto Farm")
	local BOSS_LIST = { "slimeKing", "slimeQueen", "desertBoss", "golem" }
	GuiLibrary:CreateDropdown(tab, "Boss Target", BOSS_LIST, function(v)
		State.SelectedBoss = v
	end)
	GuiLibrary:CreateToggle(tab, "🟢 Boss Auto Farm", false, function(v)
		State.AutoFarmBoss = v
	end)
	GuiLibrary:CreateToggle(tab, "🥚 Boss Auto Spawn", false, function(v)
		State.BossAutoSpawn = v
	end)

	SECTION(tab, "👻 Spirit Farm")
	GuiLibrary:CreateLabel(tab, "Targets spirit / spiritParasite / spiritCrop entities.")
	GuiLibrary:CreateToggle(tab, "🟢 Spirit Auto Farm", false, function(v) State.AutoFarmSpirit = v end)

	SECTION(tab, "🌀 Void Farm")
	GuiLibrary:CreateLabel(tab, "Targets voidParasite / voidDog / voidPup entities.")
	GuiLibrary:CreateToggle(tab, "🟢 Void Auto Farm", false, function(v) State.AutoFarmVoid = v end)
end

local function buildFarmingTab()
	local tab = Tabs.Farming
	SECTION(tab, "🌾 Crop Farm")
	local CROPS = {
		"all", "wheat", "carrot", "potato", "tomato", "onion", "pumpkin",
		"melon", "pineapple", "spinach", "starfruit", "dragonfruit",
		"chiliPepper", "berryBush", "blackberryBush", "blueberryBush",
		"grapeVine", "candyCaneVine", "spiritCrop",
	}
	GuiLibrary:CreateMultiSelect(tab, "Selected Crops", CROPS, { "wheat" }, function(s)
		State.SelectedCrops = s
	end)
	GuiLibrary:CreateSlider(tab, "Range", 5, 100, 30, function(v) State.CropRange = v end)
	GuiLibrary:CreateSlider(tab, "Cycle Delay (s)", 0.1, 3, 0.4, function(v) State.CropDelay = v end)
	GuiLibrary:CreateToggle(tab, "🪓 Use Sickle (bulk harvest)", true, function(v) State.UseSickle = v end)
	GuiLibrary:CreateToggle(tab, "🌱 Auto Replace Crop", true, function(v) State.AutoReplaceCrop = v end)
	GuiLibrary:CreateToggle(tab, "🟢 Auto Farm Crop", false, function(v) State.AutoFarmCrop = v end)
	GuiLibrary:CreateToggle(tab, "✨ Crop Aura", false, function(v) State.CropAura = v end)

	SECTION(tab, "🌳 Tree Farm")
	local TREES = { "all", "Oak", "Birch", "Maple", "Pine", "Hickory", "Spirit" }
	GuiLibrary:CreateDropdown(tab, "Tree Type", TREES, function(v) State.SelectedTree = v end)
	GuiLibrary:CreateToggle(tab, "🟢 Auto Farm Tree", false, function(v) State.AutoFarmTree = v end)
	GuiLibrary:CreateToggle(tab, "✨ Tree Aura", false, function(v) State.TreeAura = v end)

	SECTION(tab, "⛏️ Rock Farm")
	local ROCKS = { "Stone", "stoneCoal", "stoneCopper", "stoneIron", "stoneGold", "stoneDiamond", "stoneRuby", "stoneAmethyst", "stoneEmerald", "stoneSapphire", "stoneOpal", "stoneTopaz" }
	GuiLibrary:CreateMultiSelect(tab, "Selected Rocks", ROCKS, { "Stone" }, function(s) State.SelectedRocks = s end)
	GuiLibrary:CreateToggle(tab, "🟢 Auto Farm Rock", false, function(v) State.AutoFarmRock = v end)
	GuiLibrary:CreateToggle(tab, "✨ Rock Aura", false, function(v) State.RockAura = v end)

	SECTION(tab, "🎣 Fish Farm")
	GuiLibrary:CreateLabel(tab, "Casts the rod in front of you — works anywhere with the rod equipped.")
	GuiLibrary:CreateSlider(tab, "Wait Time (s)", 5, 20, 10, function(v) State.FishWaitTime = v end)
	GuiLibrary:CreateSlider(tab, "Cycle Delay (s)", 0.1, 3, 0.2, function(v) State.FishCycleDelay = v end)
	GuiLibrary:CreateToggle(tab, "🟢 Auto Fish", false, function(v) State.AutoFarmFish = v end)
end

local function visitIslandByUserId(userId)
	local islands = getIslands()
	if not (islands and Remotes.VisitIsland) then return false end
	for _, isle in ipairs(islands:GetChildren()) do
		local owners = isle:FindFirstChild("Owners")
		if owners and owners:FindFirstChild(tostring(userId)) then
			pcall(function() Remotes.VisitIsland:InvokeServer({ island = isle }) end)
			return true
		end
	end
	return false
end

local function teleportToOwnIsland()
	if visitIslandByUserId(LocalPlayer.UserId) then return true end
	local isle = getMyIsland()
	if not isle then return false end
	local blocks = isle:FindFirstChild("Blocks")
	if blocks then
		for _, b in ipairs(blocks:GetChildren()) do
			if b:FindFirstChild("PortalActive") and b:FindFirstChild("portal-to-spawn") then
				local cb = b:FindFirstChild("CollisionBoxes")
				local part = cb and cb:FindFirstChild("Part")
				if part then Teleport.cframe(part.CFrame); return true end
			end
		end
	end
	if isle.PrimaryPart then
		Teleport.cframe(isle.PrimaryPart.CFrame + Vector3.new(0, 30, 0))
		return true
	end
	return false
end

local teleportHome = teleportToOwnIsland

local LANDMARKS = {
	{ name = "🏠 My Island Portal", action = teleportHome },
	{ name = "🐢 Fishing Dock",     cframe = CFrame.new(-91, 34, -897) },
	{ name = "🟢 Slime Area",       cframe = CFrame.new(151.095, 37.135, -734.216) },
	{ name = "🟤 Buffalkor Area",   cframe = CFrame.new(885.378, 180.972, 23.214) },
	{ name = "🧙 Witch Hut",        cframe = CFrame.new(1709.623, 448.131, -204.412) },
	{ name = "🏜️ Desert Boss",     cframe = CFrame.new(1475.444, 342.177, -875.548) },
	{ name = "⛏️ Hub Mine",         cframe = CFrame.new(686.588, 200.419, -229.044) },
	{ name = "👻 Spirit Island",    cframe = CFrame.new(654.445, 184.972, -134.859) },
	{ name = "🏴‍☠️ Pirate Island",   action = function()
		if Remotes.PirateIsland then
			pcall(function() Remotes.PirateIsland:FireServer(false) end)
			return true
		end
		return false
	end },
}

local function buildMovementTab()
	local tab = Tabs.Movement
	SECTION(tab, "🚀 Landmark Teleports")
	GuiLibrary:CreateLabel(tab, "Uses portal CollisionBox CFrame for home (anti-cheat safe).")
	local landmarkNames = {}
	for i, p in ipairs(LANDMARKS) do landmarkNames[i] = p.name end
	local selectedLandmark = landmarkNames[1]
	GuiLibrary:CreateDropdown(tab, "Destination", landmarkNames, function(v) selectedLandmark = v end)
	GuiLibrary:CreateButton(tab, "🚀 Teleport", function()
		for _, p in ipairs(LANDMARKS) do
			if p.name == selectedLandmark then
				if p.cframe then
					Teleport.cframe(p.cframe)
				elseif p.action then
					p.action()
				end
				return
			end
		end
	end)

	SECTION(tab, "🏝️ Inter-Island Teleport (via Remote)")
	GuiLibrary:CreateLabel(tab, "Uses CLIENT_VISIT_ISLAND_REQUEST — the legit game mechanic for cross-island TP.")
	GuiLibrary:CreateButton(tab, "🏠 Go to My Island", function()
		if teleportToOwnIsland() then
			notify("Visit", "Teleporting to your island…", 2, "success")
		else
			notify("Visit", "Couldn't reach your island.", 3, "danger")
		end
	end)
	local visitId = LocalPlayer.UserId
	GuiLibrary:CreateInput(tab, "Visit UserId", function(t) visitId = tonumber(t) or visitId end)
	GuiLibrary:CreateButton(tab, "🏝️ Visit Player's Island", function()
		if visitIslandByUserId(visitId) then
			notify("Visit", "Visiting island of " .. visitId, 2, "success")
		else
			notify("Visit", "Player island not found.", 3, "warning")
		end
	end)
	GuiLibrary:CreateButton(tab, "📍 Save Spot", function()
		local r = getRoot()
		if r then State.SavedSpot = r.CFrame; notify("Movement", "Spot saved ✅", 2, "success") end
	end)
	GuiLibrary:CreateButton(tab, "↩️ Return to Saved", function()
		if State.SavedSpot then Teleport.cframe(State.SavedSpot) end
	end)

	SECTION(tab, "👤 Player")
	GuiLibrary:CreateSlider(tab, "Walk Speed", 16, 200, 30, function(v) State.WalkSpeed = v end)
	GuiLibrary:CreateSlider(tab, "Jump Power", 50, 500, 50, function(v) State.JumpPower = v end)
	GuiLibrary:CreateSlider(tab, "Fly Speed", 1, 10, 1, function(v) State.FlySpeed = v end)
	GuiLibrary:CreateToggle(tab, "✈️ Fly (WASD + Space/Shift)", false, function(v)
		State.FlyEnabled = v
		if v then Fly.enable() else Fly.disable() end
	end)
	GuiLibrary:CreateToggle(tab, "👻 Noclip", false, function(v)
		State.NoclipEnabled = v
		if v then Noclip.on() else Noclip.off() end
	end)
	GuiLibrary:CreateButton(tab, "🔄 Respawn", function()
		local hum = getHum()
		if hum then hum.Health = 0 end
	end)
end

local function buildBuildingTab()
	local tab = Tabs.Building

	SECTION(tab, "📐 Selection")
	GuiLibrary:CreateLabel(tab, "Two ways to define the build region: click-set two blocks, or use the 3D Resize Tool.")
	GuiLibrary:CreateButton(tab, "📍 Click → Set Start Block", function()
		State.SettingBlock = "start"
		notify("Selection", "Click a block to set as START", 4, "info")
	end)
	GuiLibrary:CreateButton(tab, "📍 Click → Set End Block", function()
		State.SettingBlock = "end"
		notify("Selection", "Click a block to set as END", 4, "info")
	end)
	GuiLibrary:CreateToggle(tab, "🧰 Resize Tool (3D selection box)", false, function(v)
		State.UseResizeTool = v
		if v then
			ResizeTool.enable()
			notify("Resize Tool", "Click a block on your island to start selection. Drag handles to resize.", 6, "info")
		else
			ResizeTool.disable()
		end
	end)
	GuiLibrary:CreateButton(tab, "🎯 Change Resize Target", function()
		ResizeTool.changeMode()
		notify("Resize Tool", "Click a different block to retarget.", 4, "info")
	end)

	SECTION(tab, "🏗️ Block Printer")
	GuiLibrary:CreateLabel(tab, "Hold the block/seed you want to place, then press Print.")
	GuiLibrary:CreateToggle(tab, "🛫 Teleport while printing", true, function(v) State.BlockPrinterTP = v end)
	GuiLibrary:CreateSlider(tab, "Hits per block", 1, 5, 1, function(v) State.BlockPrinterHits = math.floor(v) end)
	GuiLibrary:CreateSlider(tab, "Delay between blocks (s)", 0, 0.5, 0, function(v) State.BlockPrinterDelay = v end)
	GuiLibrary:CreateButton(tab, "🖨️ Print Blocks", function() Building.printBlocks() end)
	GuiLibrary:CreateButton(tab, "🛑 Stop Printer", function() State.BlockPrinterAbort = true end)

	SECTION(tab, "💥 Block Destroyer")
	GuiLibrary:CreateButton(tab, "💥 Destroy in Range", function() Building.destroyBlocks() end)

	SECTION(tab, "📜 Schematics")
	GuiLibrary:CreateLabel(tab, "Save the Resize Tool selection to a file, then load + print anywhere.")
	GuiLibrary:CreateInput(tab, "Schematic name", function(text) State.SchematicName = text ~= "" and text or "Template" end)
	local fileDropdown
	local function refreshList()
		local files = listSchematics()
		if #files == 0 then files = { "(no schematics yet)" } end
		if fileDropdown and fileDropdown.UpdateOptions then
			fileDropdown.UpdateOptions(files, true)
		end
	end
	fileDropdown = GuiLibrary:CreateDropdown(tab, "Saved Files", listSchematics(), function(v)
		if v and v ~= "(no schematics yet)" then State.SchematicName = v end
	end)
	GuiLibrary:CreateButton(tab, "💾 Save Selection → File", function()
		local ok, msg = Schematica.save(State.SchematicName)
		notify("Schematics", msg, 4, ok and "success" or "danger")
		refreshList()
	end)
	GuiLibrary:CreateButton(tab, "📂 Load File → Ghost Preview", function()
		local ok, msg = Schematica.load(State.SchematicName)
		notify("Schematics", msg, 4, ok and "success" or "danger")
	end)
	GuiLibrary:CreateButton(tab, "🖨️ Print Loaded Schematic", function()
		local ok, msg = Schematica.printLoaded()
		notify("Schematics", msg, 5, ok and "success" or "danger")
	end)
	GuiLibrary:CreateButton(tab, "🗑️ Clear Ghost Preview", function()
		Schematica.unload()
		notify("Schematics", "Ghost preview cleared", 2, "info")
	end)
	GuiLibrary:CreateButton(tab, "🔄 Refresh File List", refreshList)
	GuiLibrary:CreateButton(tab, "❌ Delete Selected File", function()
		if State.SchematicName and State.SchematicName ~= "" then
			deleteSchematic(State.SchematicName)
			notify("Schematics", "Deleted " .. State.SchematicName, 3, "info")
			refreshList()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			pcall(refreshList)
		end
	end)
end

local function buildIslandTab()
	local tab = Tabs.Island
	SECTION(tab, "🏝️ Island Visit")
	GuiLibrary:CreateInput(tab, "UserId to visit", function(text)
		local id = tonumber(text)
		if id then State.IslandFarmUserId = id end
	end)
	GuiLibrary:CreateButton(tab, "🏝️ Visit Island", function()
		if visitIslandByUserId(State.IslandFarmUserId) then
			notify("Visit", "Visiting island of " .. State.IslandFarmUserId, 2, "success")
		else
			notify("Visit Island", "Player island not found in this server.", 3, "warning")
		end
	end)
	GuiLibrary:CreateButton(tab, "🏠 Go to My Island", function() teleportToOwnIsland() end)

	SECTION(tab, "🍎 Pickup & Collection")
	GuiLibrary:CreateToggle(tab, "🍎 Auto Collect Fruits", false, function(v) State.AutoCollectFruits = v end)
	GuiLibrary:CreateToggle(tab, "💰 Auto Collect Chests", false, function(v) State.AutoFarmChest = v end)
	GuiLibrary:CreateToggle(tab, "🍯 Auto Collect Honey", false, function(v) State.AutoFarmHoney = v end)

	SECTION(tab, "🐾 Animals")
	GuiLibrary:CreateToggle(tab, "🐾 Auto Pet (Collect From Animals)", false, function(v) State.AutoFarmPet = v end)
	GuiLibrary:CreateToggle(tab, "🐄 Auto Milk Cows/Yaks", false, function(v) State.AutoMilkCow = v end)

	SECTION(tab, "🌸 Flowers")
	GuiLibrary:CreateToggle(tab, "🌸 Auto Farm Flowers", false, function(v) State.AutoFarmFlower = v end)
	GuiLibrary:CreateToggle(tab, "✨ Flower Aura (range only)", false, function(v) State.FlowerAura = v end)

	SECTION(tab, "🚜 Plow")
	GuiLibrary:CreateSlider(tab, "Plow Range", 5, 35, 15, function(v) State.PlowRange = v end)
	GuiLibrary:CreateToggle(tab, "🚜 Plow Aura (grass → soil)", false, function(v) State.PlowAura = v end)
	GuiLibrary:CreateToggle(tab, "🔄 Unplow Aura (soil → grass)", false, function(v) State.UnPlowAura = v end)

	SECTION(tab, "🌱 Crop Place Aura")
	local PLACEABLE = { "wheat", "carrot", "potato", "tomato", "onion", "pumpkin", "melon", "pineapple", "spinach", "starfruit", "dragonfruit" }
	GuiLibrary:CreateDropdown(tab, "Crop to Place", PLACEABLE, function(v) State.CropPlaceType = v end)
	GuiLibrary:CreateSlider(tab, "Place Range", 5, 30, 25, function(v) State.CropPlaceRange = v end)
	GuiLibrary:CreateToggle(tab, "🌱 Crop Place Aura", false, function(v) State.CropPlaceAura = v end)

	SECTION(tab, "💰 Bank")
	local bankAmt = 0
	GuiLibrary:CreateInput(tab, "Amount", function(text)
		bankAmt = tonumber(text) or 0
	end)
	GuiLibrary:CreateButton(tab, "💵 Deposit", function()
		Bank.deposit(bankAmt)
		notify("Bank", "Deposit " .. bankAmt .. " sent", 2, "success")
	end)
	GuiLibrary:CreateButton(tab, "💸 Withdraw", function()
		Bank.withdraw(bankAmt)
		notify("Bank", "Withdraw " .. bankAmt .. " sent", 2, "success")
	end)
end

local function buildVendingTab()
	local tab = Tabs.Vending
	SECTION(tab, "🛒 Vending Sniper")
	GuiLibrary:CreateLabel(tab, "Set item + max price, enable. Walks vending machines and auto-buys.")
	local statusLabel = GuiLibrary:CreateLabel(tab, "Status: Idle")
	local itemLabel = GuiLibrary:CreateLabel(tab, "Target item: (none)")

	GuiLibrary:CreateInput(tab, "Item name", function(text)
		State.VendingTarget = text
		if itemLabel and itemLabel.Text then itemLabel.Text = "Target item: " .. (text ~= "" and text or "(none)") end
	end)
	GuiLibrary:CreateInput(tab, "Max price", function(text)
		local n = tonumber(text)
		State.VendingMaxPrice = n
	end)
	GuiLibrary:CreateDropdown(tab, "Action", { "Buy", "Sell" }, function(v)
		State.VendingAction = v
	end)

	GuiLibrary:CreateButton(tab, "🎯 Use Holding Item", function()
		local char = getChar()
		local tool = char and char:FindFirstChildOfClass("Tool")
		if tool then
			State.VendingTarget = tool.Name
			if itemLabel and itemLabel.Text then itemLabel.Text = "Target item: " .. tool.Name end
			notify("Vending", "Target set to: " .. tool.Name, 3, "success")
		else
			notify("Vending", "No tool equipped.", 3, "warning")
		end
	end)

	GuiLibrary:CreateToggle(tab, "🟢 Sniper Enabled", false, function(v)
		State.VendingEnabled = v
		if statusLabel and statusLabel.Text then
			statusLabel.Text = "Status: " .. (v and "Searching…" or "Idle")
		end
	end)

	GuiLibrary:CreateButton(tab, "🔍 Search Now", function()
		notify("Vending", "Scanning visible vending machines…", 3, "info")
		Vending.scanOnce()
	end)
end

local function buildSettingsTab()
	local tab = Tabs.Settings
	SECTION(tab, "🚀 Teleport Settings")
	GuiLibrary:CreateLabel(tab, "TweenV3 is the original anti-cheat-balanced method (15–20 studs/sec).")
	local METHODS = { "Tween", "TweenV3", "Instant", "Stealth", "PortalCF" }
	GuiLibrary:CreateDropdown(tab, "Teleport Method", METHODS, function(v) State.TeleportMethod = v end)
	GuiLibrary:CreateSlider(tab, "Tween Speed (studs/sec)", 10, 200, 30, function(v) State.TweenSpeed = v end)
	GuiLibrary:CreateSlider(tab, "Stealth Step Size (studs)", 20, 200, 80, function(v) State.StealthStepSize = v end)
	GuiLibrary:CreateButton(tab, "🛑 Cancel Active Teleport", function() Teleport.cancel() end)

	SECTION(tab, "📊 Stats")
	local statsLabel = GuiLibrary:CreateLabel(tab, "Mobs: 0 | Crops: 0 | Trees: 0 | Rocks: 0 | Fish: 0")
	task.spawn(function()
		while true do
			task.wait(0.5)
			if statsLabel and statsLabel.Text then
				statsLabel.Text = string.format(
					"⚔️ Mobs: %d | 🌾 Crops: %d | 🌳 Trees: %d | ⛏️ Rocks: %d | 🎣 Fish: %d",
					Stats.MobsKilled, Stats.CropsHarvested, Stats.TreesChopped, Stats.RocksMined, Stats.FishCaught
				)
			end
		end
	end)

	SECTION(tab, "🔧 Farm Helpers")
	GuiLibrary:CreateToggle(tab, "🛠️ Auto Equip Best Tool", true, function(v) State.AutoEquipBest = v end)
	GuiLibrary:CreateButton(tab, "⚔️ Equip Best Sword", function() equipTool("sword") end)
	GuiLibrary:CreateButton(tab, "🪓 Equip Best Axe", function() equipTool("axe") end)
	GuiLibrary:CreateButton(tab, "⛏️ Equip Best Pickaxe", function() equipTool("pickaxe") end)
	GuiLibrary:CreateButton(tab, "🌾 Equip Best Sickle", function() equipTool("sickle") end)
	GuiLibrary:CreateButton(tab, "🎣 Equip Best Rod", function() equipTool("rod") end)

	SECTION(tab, "📦 Misc Remotes")
	GuiLibrary:CreateButton(tab, "📬 Read All Mail (1000 ids)", function()
		if not Remotes.Mail then notify("Mail", "Remote missing", 3, "danger"); return end
		for i = 1, 1000 do
			pcall(function() Remotes.Mail:FireServer("game_update_" .. i) end)
			task.wait()
		end
		notify("Mail", "Done.", 3, "success")
	end)
	GuiLibrary:CreateButton(tab, "🌫️ Disable Fog", function()
		Lighting.FogEnd = 1e9
		Lighting.FogStart = 1e9
		notify("Lighting", "Fog cleared", 2, "success")
	end)
	GuiLibrary:CreateButton(tab, "☀️ Always Day", function()
		Lighting.ClockTime = 12
		Lighting.GeographicLatitude = 0
		Lighting:SetMinutesAfterMidnight(12 * 60)
		notify("Lighting", "Clock set to noon", 2, "success")
	end)

	SECTION(tab, "🛑 Script Control")
	GuiLibrary:CreateButton(tab, "🛑 Stop All Farms", function()
		State.AutoFarmMob = false
		State.AutoFarmBoss = false
		State.MobKillAura = false
		State.AutoFarmCrop = false
		State.CropAura = false
		State.AutoFarmTree = false
		State.TreeAura = false
		State.AutoFarmRock = false
		State.RockAura = false
		State.AutoFarmFish = false
		State.AutoCollectFruits = false
		State.AutoFarmChest = false
		State.AutoFarmHoney = false
		State.AutoFarmPet = false
		State.AutoMilkCow = false
		State.AutoFarmSpirit = false
		State.AutoFarmVoid = false
		State.AutoFarmFlower = false
		State.FlowerAura = false
		State.PlowAura = false
		State.UnPlowAura = false
		State.CropPlaceAura = false
		notify("Stop All", "All auto farms disabled ✅", 3, "success")
	end)
	GuiLibrary:CreateButton(tab, "💀 Unload Script", function()
		for _, c in ipairs(game:GetService("CoreGui"):GetChildren()) do
			if c.Name == "GuiLibraryUI" then pcall(function() c:Destroy() end) end
		end
	end)
end

do
	local function getCurrentTool()
		local char = getChar()
		return char and char:FindFirstChildOfClass("Tool")
	end

	local function disableCollision()
		local char = getChar()
		if not char then return end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
		end
	end

	local function getRegion()
		local newPart = Workspace:FindFirstChild("NewPart")
		if newPart then
			local pos, size = newPart.Position, newPart.Size
			local half = size / 2
			return pos - half, pos + half
		end
		if State.StartBlock and State.EndBlock then
			local a, b = State.StartBlock.Position, State.EndBlock.Position
			return
				Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)),
				Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
		end
		return nil, nil
	end

	function Building.printBlocks()
		local char = getChar()
		local root = getRoot()
		if not (char and root) then notify("Printer", "Character not loaded.", 3, "danger"); return end
		local tool = getCurrentTool()
		if not tool then notify("Printer", "Equip the block/seed first.", 3, "danger"); return end
		local minP, maxP = getRegion()
		if not minP then
			notify("Printer", "Set a selection (Resize Tool or Start/End blocks).", 4, "danger")
			return
		end
		if not Remotes.BlockPlace then return end

		local blockType
		if tool:FindFirstChild("seeds") then
			blockType = (tool.Name:gsub("Seeds$", ""))
		else
			blockType = tool.Name
		end

		State.BlockPrinterAbort = false
		disableCollision()

		local positions = {}
		for x = minP.X, maxP.X, 3 do
			for y = minP.Y, maxP.Y, 3 do
				for z = minP.Z, maxP.Z, 3 do
					positions[#positions + 1] = Vector3.new(x, y, z)
				end
			end
		end

		local total = #positions
		notify("Printer", string.format("Placing %d blocks…", total), 3, "info")
		local startTime = tick()

		local function placeAt(pos)
			pcall(function()
				Remotes.BlockPlace:InvokeServer({
					[Hashes.BlockPlace.key] = Hashes.BlockPlace.val,
					upperBlock = false,
					cframe = CFrame.new(pos),
					blockType = blockType,
				})
			end)
		end

		local startUp = root.Position + Vector3.new(0, 10, 0)
		Teleport.cframe(CFrame.new(startUp))
		task.wait(0.5)

		local speed = State.BlockPrinterParallel or 5
		local remaining = total
		local done = {}

		for round = 1, speed do
			if State.BlockPrinterAbort then break end
			for i, pos in ipairs(positions) do
				if State.BlockPrinterAbort then break end
				if not done[i] then
					task.spawn(function()
						local r = getRoot()
						if not r then return end
						if State.BlockPrinterTP and (r.Position - pos).Magnitude > 30 then
							Teleport.go(pos + Vector3.new(0, 8, 0))
							local deadline = tick() + 0.6
							while tick() < deadline do
								local rr = getRoot()
								if not rr then return end
								if (rr.Position - pos).Magnitude < 30 then break end
								task.wait(0.1)
							end
						end
						for _ = 1, State.BlockPrinterHits do
							placeAt(pos)
						end
						done[i] = true
						Stats.BlocksPlaced = Stats.BlocksPlaced + 1
					end)
					task.wait()
				end
			end
			if State.BlockPrinterDelay > 0 then task.wait(State.BlockPrinterDelay) end
		end

		local count = 0
		for _ in pairs(done) do count = count + 1 end
		local elapsed = math.floor((tick() - startTime) * 10) / 10
		notify("Printer", string.format("Done — %d/%d in %.1fs", count, total, elapsed), 4, "success")
	end

	function Building.destroyBlocks()
		local char = getChar()
		if not char then notify("Destroyer", "Character not loaded.", 3, "danger"); return end
		local minP, maxP = getRegion()
		if not minP then
			notify("Destroyer", "Set a selection (Resize Tool or Start/End blocks).", 4, "danger")
			return
		end
		if not Remotes.BlockHit then return end

		disableCollision()
		State.BlockPrinterAbort = false

		local island = getMyIsland()
		local blocks = island and island:FindFirstChild("Blocks")
		if not blocks then notify("Destroyer", "Could not locate Blocks folder.", 3, "danger"); return end

		local targets = {}
		for _, blk in ipairs(blocks:GetChildren()) do
			local p = blk.Position
			if p.X >= minP.X - 1.5 and p.X <= maxP.X + 1.5
				and p.Y >= minP.Y - 1.5 and p.Y <= maxP.Y + 1.5
				and p.Z >= minP.Z - 1.5 and p.Z <= maxP.Z + 1.5
			then
				targets[#targets + 1] = blk
			end
		end

		notify("Destroyer", string.format("Destroying %d blocks…", #targets), 3, "info")
		local startTime = tick()

		for _, blk in ipairs(targets) do
			if State.BlockPrinterAbort then break end
			if not blk.Parent then continue end
			if State.BlockPrinterTP then
				Teleport.go(blk.Position + Vector3.new(0, 5, 0))
				local deadline = tick() + 0.25
				while tick() < deadline do
					local r = getRoot()
					if not r then break end
					if (r.Position - blk.Position).Magnitude < 18 then break end
					task.wait(0.05)
				end
			end
			local hitPart = blk:FindFirstChildWhichIsA("BasePart") or blk
			local args = {
				[Hashes.BlockHit.key] = Hashes.BlockHit.val,
				part = hitPart,
				block = blk,
				norm = Vector3.new(0, 1, 0),
				pos = blk.Position,
			}
			for _ = 1, 3 do
				if not blk.Parent then break end
				pcall(function() Remotes.BlockHit:InvokeServer(args) end)
			end
			Stats.BlocksDestroyed = Stats.BlocksDestroyed + 1
			task.wait(0.02)
		end

		local elapsed = math.floor((tick() - startTime) * 10) / 10
		notify("Destroyer", string.format("Done — %d blocks in %.1fs", #targets, elapsed), 4, "success")
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not State.SettingBlock then return end

	local mouse = LocalPlayer:GetMouse()
	local hit = mouse.Target
	if hit and hit:IsA("BasePart") then
		local block = hit:FindFirstAncestorWhichIsA("Model") or hit
		if hit.Parent and hit.Parent.Parent and hit.Parent.Parent.Name == "Blocks" then
			block = hit.Parent
		elseif hit.Parent and hit.Parent.Name == "Blocks" then
			block = hit
		end
		if State.SettingBlock == "start" then
			State.StartBlock = block
			notify("Block Printer", "Start block set ✅", 2, "success")
		elseif State.SettingBlock == "end" then
			State.EndBlock = block
			notify("Block Printer", "End block set ✅", 2, "success")
		end
		State.SettingBlock = nil
	end
end)

buildCombatTab()
buildFarmingTab()
buildMovementTab()
buildBuildingTab()
buildIslandTab()
buildVendingTab()
buildSettingsTab()

notify("Islands.God", "Loaded! Have fun 🎉", 5, "success")
