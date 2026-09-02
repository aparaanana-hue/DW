-- The "?t=" is not decoration: raw.githubusercontent is behind a CDN that
-- serves a stale copy for minutes after a push, so without it you can
-- re-execute all day and still get the old library.
local Duvome = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/aparaanana-hue/DW/refs/heads/main/DL.lua"
        .. "?t=" .. tostring(os.time())))()

-- Bumped on every push. If the About panel and the load notification do not
-- show the newest one, the script came from a cache rather than from GitHub -
-- which looks exactly like a fix that did not work.
local PIHD_BUILD = "Aug 23 20:10"

local TAB_ICONS = {
	Home                 = "house",
	["Price Tool"]       = "tag",
	Farming              = "backpack",
	Settings             = "gear",
	["Shop & Storage"]   = "shopping-cart",
	Presets              = "star",
}

local function StartHub()
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local Window = Duvome:MakeWindow({
	Name           = "Priz's Islands Hub",
	IntroEnabled   = true,
	IntroText      = "Priz's Islands Hub",
	HidePremium    = true,
	ShowIcon       = false,
	SaveConfig     = true,
	AutoLoadConfig = false,
	ConfigFolder   = "PrizIslandsHub",
	Theme          = "Default",
	-- No blur. Roblox's BlurEffect works on the camera, so it frosts the whole
	-- screen rather than what is behind the window - which makes the game look
	-- like the hub, not the hub look like glass. The panels carry the effect on
	-- their own.
	Blur           = false,
})

-- 38% is the value, not a starting point - the slider that used to adjust it is
-- gone. Set explicitly anyway, so a config saved while the slider existed cannot
-- carry some other number back in.
pcall(function() Duvome:SetGlass(0.38) end)

local UI = {}
local S = {}
-- Feature state lives here, not in file-scope locals. Luau allows a function
-- 200 local registers and this chunk is a single function - it has hit that
-- ceiling before, and the failure mode is silent: the whole file refuses to
-- compile, loadstring hands back nil, and the caller reports an error on its
-- own line 1 with no message attached.
S.farmWalkSpeed, S.farmWalkNoclip, S.harvestRadius = 32, true, 45
S.restockSplit, S.restockLoopOn, S.restockEvery = false, false, 15
S.restockRandomItem, S.restockRandomEvery, S.restockGen = false, 0, 0
S.b2vOn, S.b2vEvery, S.b2vAmount, S.b2vFavOnly, S.b2vGen = false, 30, 1000000, false, 0
local L, R

local _flagN = 0
local function autoFlag(prefix)
	_flagN = _flagN + 1
	return (prefix or "f") .. "_" .. _flagN
end

local function initGuard(fn)
	fn = fn or function() end
	local fired = false
	return function(...)
		if not fired then fired = true return end
		return fn(...)
	end
end

local networkReady = false

task.spawn(function()
	local success = pcall(function()
		local rbxts = RS:WaitForChild("rbxts_include", 10)
		if not rbxts then error("rbxts_include not found") end
		Net = rbxts:WaitForChild("node_modules", 5):WaitForChild("@rbxts", 5):WaitForChild("net", 5):WaitForChild("out", 5):WaitForChild("_NetManaged", 5)
		Open = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/ohzbeybzqzfJRFwekzcvdLnpwpuaoia"]
		Edit = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/amv"]
		Close = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/uabQAzmslluxa"]
		Withdraw = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/cFkpxe"]
		Deposit = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/uvgaYvclaqh"]
		ItemRemote = Net["vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/clQqtBtMScmrwsnEkow"]
	end)
	networkReady = success
end)

task.spawn(function()
	repeat task.wait() until LP.Character
end)

task.spawn(function()
	pcall(function()
		local req = (syn and syn.request) or (http and http.request) or http_request or request
		if not req then return end
		local joinCode = "Unknown"
		pcall(function() if LP:FindFirstChild("JoinCode") then joinCode = LP.JoinCode.Value end end)
		local executor = "Unknown"
		pcall(function() if identifyexecutor then executor = tostring(identifyexecutor()) end end)
		local body = game:GetService("HttpService"):JSONEncode({
			username = "Priz Hub Logger",
			embeds = {{
				title = "Hub Launched",
				color = 9109759,
				fields = {
					{name = "User", value = LP.Name .. " (" .. LP.DisplayName .. ")", inline = true},
					{name = "UserId", value = tostring(LP.UserId), inline = true},
					{name = "Account Age", value = LP.AccountAge .. " days", inline = true},
					{name = "Island Code", value = tostring(joinCode), inline = true},
					{name = "Executor", value = executor, inline = true},
					{name = "PlaceId", value = tostring(game.PlaceId), inline = true},
				},
			}},
		})
		req({
			Url = "https://discord.com/api/webhooks/1524587579121336530/zvAqcAq0lWIfc4fxz4jTOPUq0t5p78EGVtRCFSXL3Qe_1DM78noBQska63CawmnYf1tM",
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = body,
		})
	end)
end)

local selectedVending, selectedItemName, allAtOnceMode, vendingRadius, useRadiusLimit, radiusRingPart, itemNameMap = nil, nil, true, 100, false, nil, {}
local radiusShape = "Circle"

local function getDisplayName(obj)
 if not obj then return "Unknown" end
 local displayNameValue = obj:FindFirstChild("DisplayName")
 if displayNameValue and displayNameValue:IsA("StringValue") then
  return displayNameValue.Value
 end
 return obj.Name
end

local radiusConnection = nil
local PRIZ_PURPLE = Color3.fromRGB(138, 43, 226)

local function worldPosOf(o)
 if not o then return nil end
 if o:IsA("BasePart") then return o.Position end
 local ok, piv = pcall(function() return o:GetPivot().Position end)
 if ok then return piv end
 return nil
end

local function withinRadius(objPos)
 if not objPos then return false end
 local char = LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 if not hrp then return false end
 local d = objPos - hrp.Position
 if radiusShape == "Square" then
  return math.abs(d.X) <= vendingRadius and math.abs(d.Z) <= vendingRadius
 else
  return d.Magnitude <= vendingRadius
 end
end

local function modelSize(m)
 local ok, sz = pcall(function() return m:GetExtentsSize() end)
 return ok and sz.Magnitude or math.huge
end
local function resolveHLTarget(o)
 if not o then return o end

 local vm = o:FindFirstChild("VendingMachine")
 if vm then return vm end
 local t = o
 while t.Parent and t.Parent:IsA("Model") and modelSize(t.Parent) <= 40 do
  t = t.Parent
 end
 return t
end

local function assemblyParts(o)
 return { resolveHLTarget(o) }
end

local function allVendingParts()
 local t = {}
 local islands = WS:FindFirstChild("Islands")
 if islands then
  for _, isl in pairs(islands:GetChildren()) do
   local b = isl:FindFirstChild("Blocks")
   if b then for _, o in pairs(b:GetChildren()) do if o.Name:lower():find("vending") then table.insert(t, o) end end end
  end
 end
 return t
end

local function allChestParts()
 local t, seen = {}, {}
 local islands = WS:FindFirstChild("Islands")
 if islands then
  for _, o in pairs(islands:GetDescendants()) do
   if o:IsA("BasePart") and o.Name:lower():find("chest") then
    local key = resolveHLTarget(o)
    if not seen[key] then seen[key] = true table.insert(t, o) end
   end
  end
 end
 return t
end

local function createRadiusRing()
 if radiusRingPart then radiusRingPart:Destroy() radiusRingPart = nil end
 if radiusConnection then radiusConnection:Disconnect() radiusConnection = nil end
 if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end

 local adjustedRadius = vendingRadius * 0.8
 local folder = Instance.new("Folder")
 folder.Name = "RadiusRing"
 folder.Parent = WS
 radiusRingPart = folder

 local pts = {}
 if radiusShape == "Square" then
  local r = adjustedRadius
  local corners = {Vector3.new(-r,0,-r), Vector3.new(r,0,-r), Vector3.new(r,0,r), Vector3.new(-r,0,r)}
  local perSide = 15
  for c = 1, 4 do
   local a, b = corners[c], corners[c % 4 + 1]
   for s = 0, perSide - 1 do
    table.insert(pts, a + (b - a) * (s / perSide))
   end
  end
 else
  local segs = 60
  for i = 0, segs - 1 do
   local ang = (i / segs) * math.pi * 2
   table.insert(pts, Vector3.new(math.cos(ang) * adjustedRadius, 0, math.sin(ang) * adjustedRadius))
  end
 end

 local parts = {}
 for i = 1, #pts do
  local pos1 = pts[i]
  local pos2 = pts[i % #pts + 1]
  local midpoint = (pos1 + pos2) / 2
  local length = (pos2 - pos1).Magnitude * 1.05
  local lookVector = (pos2 - pos1).Unit

  local part = Instance.new("Part")
  part.Size = Vector3.new(0.15, 0.15, length)
  part.Anchored = true
  part.CanCollide = false
  part.Material = Enum.Material.Neon
  part.Color = PRIZ_PURPLE
  part.Transparency = 0.3
  part.CFrame = CFrame.fromMatrix(midpoint, Vector3.new(0, 1, 0):Cross(lookVector), lookVector:Cross(Vector3.new(0, 1, 0):Cross(lookVector)), -lookVector)
  part.Parent = folder

  table.insert(parts, {part = part, offset = midpoint})
 end

 radiusConnection = game:GetService("RunService").Heartbeat:Connect(function()
  if not radiusRingPart or not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
  local currentPos = LP.Character.HumanoidRootPart.Position
  for _, data in ipairs(parts) do
   if data.part.Parent then
    data.part.Position = currentPos + data.offset
   end
  end
  task.wait(0.1)
 end)
end

local function removeRadiusRing()
 if radiusConnection then radiusConnection:Disconnect() radiusConnection = nil end
 if radiusRingPart then radiusRingPart:Destroy() radiusRingPart = nil end
end

S.statistics = {coinsWithdrawn = 0, coinsDeposited = 0, itemsDeposited = 0, itemsWithdrawn = 0, vendingsModified = 0, bankDeposits = 0, bankWithdrawals = 0}
S.transactionHistory = {}

local performanceMode = false
local favoriteVendings, selectedFavorites, favoritesSelectionMode = {}, {}, false

local function saveFavorites()
 local favData = {}
 for _, vending in pairs(favoriteVendings) do table.insert(favData, {x = vending.Position.X, y = vending.Position.Y, z = vending.Position.Z, name = vending.Name}) end
 writefile("VendingManager_Favorites.json", HttpService:JSONEncode(favData))
end

local function loadFavorites()
 if isfile("VendingManager_Favorites.json") then
  local success, data = pcall(function() return HttpService:JSONDecode(readfile("VendingManager_Favorites.json")) end)
  if success and data then
   local allVendings = {}
   local islands = WS:FindFirstChild("Islands")
   if islands then for _, island in pairs(islands:GetChildren()) do local blocks = island:FindFirstChild("Blocks") if blocks then for _, obj in pairs(blocks:GetChildren()) do if obj.Name:find("vending") or obj.Name:find("Vending") then table.insert(allVendings, obj) end end end end end
   favoriteVendings = {}
   for _, favData in ipairs(data) do local savedPos = Vector3.new(favData.x, favData.y, favData.z) for _, vending in ipairs(allVendings) do if (vending.Position - savedPos).Magnitude < 1 then table.insert(favoriteVendings, vending) break end end end
  end
 end
end

task.spawn(function()
 loadFavorites()
end)

local vendingESPEnabled, vendingESPObjects = false, {}

local function getVendingHealth(vending)
 local coinBalance, itemCount, vendingMode, transactionPrice = 0, 0, nil, 100
 pcall(function()
  if vending:FindFirstChild("CoinBalance") then coinBalance = vending.CoinBalance.Value end
  if vending:FindFirstChild("Mode") then vendingMode = vending.Mode.Value end
  if vending:FindFirstChild("TransactionPrice") then transactionPrice = vending.TransactionPrice.Value end
  local sellingContents = vending:FindFirstChild("SellingContents")
  if sellingContents then for _, item in pairs(sellingContents:GetChildren()) do if item:IsA("Tool") then itemCount = itemCount + (item:FindFirstChild("Amount") and item.Amount.Value or 1) end end end
 end)
 if vendingMode == 1 then
  local priceWithTax = math.floor(transactionPrice * 1.07)
  if coinBalance == 0 then return "EMPTY", Color3.fromRGB(255, 0, 0)
  elseif coinBalance < priceWithTax then return "OUT OF MONEY", Color3.fromRGB(255, 0, 0)
  elseif coinBalance < priceWithTax * 2 then return "LOW", Color3.fromRGB(255, 165, 0)
  elseif coinBalance < priceWithTax * 10 then return "MEDIUM", Color3.fromRGB(255, 255, 0)
  else return "FULL", Color3.fromRGB(0, 255, 0) end
 elseif vendingMode == 0 then
  local maxCoins = 5000000000
  local spaceLeft = maxCoins - coinBalance
  if itemCount == 0 then return "EMPTY", Color3.fromRGB(255, 0, 0)
  elseif spaceLeft < 500000000 then return "ALMOST FULL", Color3.fromRGB(255, 0, 0)
  elseif spaceLeft < 1500000000 then return "LOW SPACE", Color3.fromRGB(255, 165, 0)
  elseif spaceLeft < 3000000000 then return "MEDIUM", Color3.fromRGB(255, 255, 0)
  else return "GOOD SPACE", Color3.fromRGB(0, 255, 0) end
 else
  if coinBalance == 0 and itemCount == 0 then return "OFFLINE", Color3.fromRGB(255, 0, 0)
  else return "OFFLINE", Color3.fromRGB(128, 128, 128) end
 end
end

local function getVendingInfo(vending)
 local itemName, itemCount, coinAmount = nil, 0, 0
 pcall(function()
  local sellingContents = vending:FindFirstChild("SellingContents")
  if sellingContents then
   local firstItem = sellingContents:GetChildren()[1]
   if firstItem then
    itemName = getDisplayName(firstItem)
    itemCount = firstItem:FindFirstChild("Amount") and firstItem.Amount.Value or 1
   end
  end
  local coinBalance = vending:FindFirstChild("CoinBalance")
  if coinBalance then coinAmount = coinBalance.Value end
 end)
 return itemName, itemCount, coinAmount
end

S.vendingGroups = {["Default"] = {}}
S.currentGroup = "Default"

if isfile and readfile and isfile("VendingManager_Groups.json") then
 local success, groupsData = pcall(function() return HttpService:JSONDecode(readfile("VendingManager_Groups.json")) end)
 if success and groupsData then for groupName, vendingList in pairs(groupsData) do S.vendingGroups[groupName] = vendingList end end
end

local hotkeys = {}
local userSettings = {theme = "Amethyst", radius = 100, useRadius = false, processMode = true}

local function updateNotification(title, content, duration)
 pcall(function()
  local t = tostring(title or "")
  local lower = t:lower()
  local ntype = "info"
  if lower:find("error") or lower:find("failed") or lower:find("not found") or lower:find("safety") then
   ntype = "error"
  elseif lower:find("warning") or lower:find("heads up") or lower:find("limit") then
   ntype = "warning"
  elseif lower:find("success") or lower:find("saved") or lower:find("loaded") or lower:find("complete")
      or lower:find("deposited") or lower:find("withdrew") or lower:find("selected") or lower:find("purchased")
      or lower:find("joining") or lower:find("invited") or lower:find("planted") or lower:find("deleted") then
   ntype = "success"
  end
  Duvome:MakeNotification({
   Name = t,
   Content = tostring(content or ""),
   Type = ntype,
   Time = duration or 3,
  })
 end)
end

local function confirm(title, content, onYes, yesText)
 Duvome:Prompt({
  Title = title,
  Content = content,
  Options = {
   {Text = "Cancel", Callback = function() end},
   {Text = yesText or "Confirm", Callback = function() pcall(onYes) end},
  }
 })
end

local outAppend, outText = false, ""
local function setOutput(title, content)
 local block = "[ " .. tostring(title) .. " ]\n\n" .. tostring(content)
 if UI.output then pcall(function()
  UI.output:Set(outAppend and (outText .. "\n\n" .. block) or block)
 end) end
 outText = outAppend and (outText .. "\n\n" .. block) or block
 -- The panel is where results appear now, so writing one opens it. Producing
 -- output into a panel the user cannot see would look like nothing happened.
 if UI.outputPanel then pcall(function() UI.outputPanel:Show() end) end
end

local function checkNetwork() if not networkReady then updateNotification("Error", "Network not initialized!", 5) return false end return true end
local function formatNumber(num) if num >= 1000000000 then return string.format("%.2fB", num / 1000000000) elseif num >= 1000000 then return string.format("%.2fM", num / 1000000) elseif num >= 1000 then return string.format("%.2fK", num / 1000) else return tostring(num) end end
local function parseAmount(text)
 if not text or text == "" then return nil end
 local num = tonumber(text)
 if num then return num end
 text = text:upper():gsub("%s+", "")
 local numPart, suffix = text:match("^([%d%.]+)([KMB])$")
 if not numPart then return nil end
 num = tonumber(numPart)
 if not num then return nil end
 if suffix == "K" then return math.floor(num * 1000)
 elseif suffix == "M" then return math.floor(num * 1000000)
 elseif suffix == "B" then return math.floor(num * 1000000000)
 end
 return nil
end
local function saveSettings()
 pcall(function()
  writefile("VendingManager_Settings.json", HttpService:JSONEncode(userSettings))
 end)
end

local function findVendings()
 if S.currentGroup ~= "Default" and S.currentGroup ~= "None" and S.vendingGroups[S.currentGroup] then
  local groupVendings, allVendings = {}, {}
  local islands = WS:FindFirstChild("Islands")
  if islands then for _, island in pairs(islands:GetChildren()) do local blocks = island:FindFirstChild("Blocks") if blocks then for _, obj in pairs(blocks:GetChildren()) do if obj.Name:find("vending") or obj.Name:find("Vending") then table.insert(allVendings, obj) end end end end end
  local group = S.vendingGroups[S.currentGroup]
  for _, vendingData in ipairs(group) do local savedPos = Vector3.new(vendingData.x, vendingData.y, vendingData.z) for _, vending in ipairs(allVendings) do if (vending.Position - savedPos).Magnitude < 1 then table.insert(groupVendings, vending) break end end end
  return groupVendings
 end
 local vendings = {}
 local islands = WS:FindFirstChild("Islands")
 if islands then for _, island in pairs(islands:GetChildren()) do local blocks = island:FindFirstChild("Blocks") if blocks then for _, obj in pairs(blocks:GetChildren()) do if obj.Name:find("vending") or obj.Name:find("Vending") then if useRadiusLimit then if withinRadius(obj.Position) then table.insert(vendings, obj) end else table.insert(vendings, obj) end end end end end end
 return vendings
end

local function setVendingMode(vending, mode, price)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/kvkeytzzouf"):FireServer(guid, {{mode = mode, vendingMachine = vending, player_tracking_category = "join_from_web", transactionPrice = price}})
  Close:FireServer({vendingMachine = vending})
  S.statistics.vendingsModified = S.statistics.vendingsModified + 1
 end)
end

local function setVendingOffline(vending)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  local currentPrice = vending:FindFirstChild("TransactionPrice") and vending.TransactionPrice.Value or 100
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/kvkeytzzouf"):FireServer(guid, {{mode = 2, vendingMachine = vending, player_tracking_category = "join_from_web", transactionPrice = currentPrice}})
  Close:FireServer({vendingMachine = vending})
  S.statistics.vendingsModified = S.statistics.vendingsModified + 1
 end)
end

local function emptyVending(vending)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  local itemsWithdrawn = {}
  local sellingContents = vending:FindFirstChild("SellingContents")
  if sellingContents then for _, item in pairs(sellingContents:GetChildren()) do if item:IsA("Tool") then local itemAmount = item:FindFirstChild("Amount") and item.Amount.Value or 9999 table.insert(itemsWithdrawn, {name = getDisplayName(item), amount = itemAmount}) ItemRemote:FireServer(guid, {{player_tracking_category = "join_from_web", amount = itemAmount, vendingMachine = vending, tool = item, action = "withdraw"}})  S.statistics.itemsWithdrawn = S.statistics.itemsWithdrawn + 1 end end end
   Close:FireServer({vendingMachine = vending})
 end)
end

local function depositItemToVending(vending, itemName, amount)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  local objectName = itemNameMap[itemName] or itemName
  local item = LP:WaitForChild("Backpack"):FindFirstChild(objectName)
  if not item then updateNotification("Error", "Item not found!", 3) return end
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  ItemRemote:FireServer(guid, {{player_tracking_category = "join_from_web", amount = amount, vendingMachine = vending, tool = item, action = "deposit"}})
   Close:FireServer({vendingMachine = vending})
  S.statistics.itemsDeposited = S.statistics.itemsDeposited + 1
 end)
end

local function withdrawFromVending(vending, amount)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  Withdraw:FireServer(guid, {{vendingMachine = vending, player_tracking_category = "join_from_web", amount = amount}})
  Close:FireServer({vendingMachine = vending})
  S.statistics.coinsWithdrawn = S.statistics.coinsWithdrawn + amount
 end)
end

local function depositCoinsToVending(vending, amount)
 if not checkNetwork() then return end
 pcall(function()
  local guid = HttpService:GenerateGUID(false)
  Open:FireServer(guid, {{vendingMachine = vending}})
  Edit:FireServer(guid, {{vendingMachine = vending}})
  Deposit:FireServer(guid, {{vendingMachine = vending, player_tracking_category = "join_from_web", amount = amount}})
  Close:FireServer({vendingMachine = vending})
  S.statistics.coinsDeposited = S.statistics.coinsDeposited + amount
 end)
end

local Mouse = LP:GetMouse()
-- 1500. The cap exists to stop a runaway drag-select, not to be a working
-- limit, and 100 was low enough to hit while selecting an ordinary shop.
local MAX_SELECTIONS = 1500

local PFX = {}
PFX.selectedChests = {}
PFX.radiusHighlightOn = false

local function clearAllMarkers(vending)
 pcall(function() if PFX.unbreathe then PFX.unbreathe(vending, "SelectionMarker") end end)
 pcall(function()
  for _, descendant in pairs(vending:GetDescendants()) do
   if descendant.Name == "SelectionMarker" then descendant:Destroy() end
  end
 end)
end

local function addSelectionMarker(vending)
 clearAllMarkers(vending)
 PFX.breathe(vending, "SelectionMarker")
end

local function removeSelectionMarker(vending)
 clearAllMarkers(vending)
end

local function _initFX()

local hlRegistry = {}
local keeperConn = nil

local function spawnHL(target, markerName)
 local h
 pcall(function()
  h = Instance.new("Highlight")
  h.Name = markerName
  h.FillColor = PRIZ_PURPLE
  h.OutlineColor = PRIZ_PURPLE
  h.FillTransparency = 0.5
  h.OutlineTransparency = 0.15
  h.Adornee = target
  h.Parent = target
 end)
 return h
end
local function ensureKeeper()
 if keeperConn then return end
 keeperConn = game:GetService("RunService").Heartbeat:Connect(function()
  local a = (math.sin(tick() * 3) + 1) * 0.5
  local fill = 0.30 + a * 0.45
  local out  = 0.08 + a * 0.30
  for key, recs in pairs(hlRegistry) do
   if not key or not key.Parent then
    for _, rec in pairs(recs) do for _, hl in ipairs(rec.hls) do pcall(function() hl:Destroy() end) end end
    hlRegistry[key] = nil
   else
    for name, rec in pairs(recs) do
     for i, hl in ipairs(rec.hls) do
      if hl and hl.Parent then
       hl.FillTransparency = fill
       hl.OutlineTransparency = out
      elseif rec.parts[i] and rec.parts[i].Parent then
       rec.hls[i] = spawnHL(rec.parts[i], name)
      end
     end
    end
   end
  end
 end)
end
local function makeBreathingHighlight(obj, markerName)
 if not obj then return end
 local key = resolveHLTarget(obj)
 markerName = markerName or "PrizBreatheHL"
 hlRegistry[key] = hlRegistry[key] or {}
 local old = hlRegistry[key][markerName]
 if old then for _, hl in ipairs(old.hls) do pcall(function() hl:Destroy() end) end end
 local parts = assemblyParts(obj)
 local hls = {}
 for i, p in ipairs(parts) do hls[i] = spawnHL(p, markerName) end
 hlRegistry[key][markerName] = { parts = parts, hls = hls }
 ensureKeeper()
end
local function unbreathe(obj, markerName)
 if not obj then return end
 local key = resolveHLTarget(obj)
 local recs = hlRegistry[key]
 if not recs then return end
 local function killRec(rec) for _, hl in ipairs(rec.hls) do pcall(function() hl:Destroy() end) end end
 if markerName then
  if recs[markerName] then killRec(recs[markerName]) recs[markerName] = nil end
  if next(recs) == nil then hlRegistry[key] = nil end
 else
  for _, rec in pairs(recs) do killRec(rec) end
  hlRegistry[key] = nil
 end
end
 PFX.breathe = makeBreathingHighlight
 PFX.unbreathe = unbreathe
 local CHEST_MARKER = "PrizChestSel"
 local function clearChestMarker(chest)
  unbreathe(chest, CHEST_MARKER)
 end
 local function addChestMarker(chest)
  clearChestMarker(chest)
  makeBreathingHighlight(chest, CHEST_MARKER)
 end
 local function isChestSelected(chest)
  for i, c in ipairs(PFX.selectedChests) do if c == chest then return i end end
  return nil
 end
 function PFX.toggleChest(chest)
  local idx = isChestSelected(chest)
  if idx then
   table.remove(PFX.selectedChests, idx)
   clearChestMarker(chest)
   updateNotification("Chest Deselected", "#" .. #PFX.selectedChests .. " selected", 1)
  else
   table.insert(PFX.selectedChests, chest)
   addChestMarker(chest)
   updateNotification("Chest Selected", "#" .. #PFX.selectedChests .. " selected", 1)
  end
 end
 function PFX.clearChests()
  for _, c in ipairs(PFX.selectedChests) do pcall(function() clearChestMarker(c) end) end
  PFX.selectedChests = {}
 end

 local radiusRunning = false
 local radiusHLMap = {}
 local function clearRadiusHighlights()
  for v in pairs(radiusHLMap) do pcall(function() unbreathe(v, "PrizRadiusHL") end) radiusHLMap[v] = nil end
 end
 function PFX.startRadiusHL()
  if radiusRunning then return end
  radiusRunning = true
  task.spawn(function()
   local first = true
   while PFX.radiusHighlightOn do

    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local inRange = {}
    if hrp then
     for _, v in ipairs(allVendingParts()) do
      local wp = worldPosOf(v)
      if wp and withinRadius(wp) then
       table.insert(inRange, { v = v, d = (wp - hrp.Position).Magnitude })
      end
     end
     table.sort(inRange, function(a, b) return a.d < b.d end)
    end
    local present = {}
    local LIMIT = 400
    for i = 1, math.min(#inRange, LIMIT) do
     local v = inRange[i].v
     present[v] = true
     if not radiusHLMap[v] then
      radiusHLMap[v] = true
      makeBreathingHighlight(v, "PrizRadiusHL")
     end
    end
    for v in pairs(radiusHLMap) do
     if not present[v] then pcall(function() unbreathe(v, "PrizRadiusHL") end) radiusHLMap[v] = nil end
    end
    if first then
     first = false
     updateNotification("Radius Highlight", "Found " .. #inRange .. " vending(s) in range", 3)
    end
    task.wait(0.3)
   end
   clearRadiusHighlights()
   radiusRunning = false
  end)
 end
 function PFX.stopRadiusHL()
  PFX.radiusHighlightOn = false
  radiusRunning = false
  clearRadiusHighlights()
 end

 local dragMode = nil
 local dragging = false
 local dragStart = nil
 local dragGui, dragFrame = nil, nil
 local beganConn, changedConn, endedConn = nil, nil, nil
 local function ensureDragGui()
  if dragGui and dragGui.Parent then return end
  dragGui = Instance.new("ScreenGui")
  dragGui.Name = "PrizDragSelect"
  dragGui.ResetOnSpawn = false
  dragGui.IgnoreGuiInset = true
  dragGui.DisplayOrder = 9999
  dragGui.Parent = LP:WaitForChild("PlayerGui")
  dragFrame = Instance.new("Frame")
  dragFrame.BackgroundColor3 = PRIZ_PURPLE
  dragFrame.BackgroundTransparency = 0.7
  dragFrame.BorderSizePixel = 0
  dragFrame.Visible = false
  dragFrame.ZIndex = 10
  dragFrame.Parent = dragGui
  local st = Instance.new("UIStroke")
  st.Color = PRIZ_PURPLE
  st.Thickness = 2
  st.Parent = dragFrame
 end
 local function updateDragFrame(a, b)
  local x1, y1 = math.min(a.X, b.X), math.min(a.Y, b.Y)
  local x2, y2 = math.max(a.X, b.X), math.max(a.Y, b.Y)
  dragFrame.Position = UDim2.fromOffset(x1, y1)
  dragFrame.Size = UDim2.fromOffset(x2 - x1, y2 - y1)
 end
 local function doSelect(endPos)
  if dragFrame then dragFrame.Visible = false end
  if not dragStart then return end
  local x1, y1 = math.min(dragStart.X, endPos.X), math.min(dragStart.Y, endPos.Y)
  local x2, y2 = math.max(dragStart.X, endPos.X), math.max(dragStart.Y, endPos.Y)

  if (x2 - x1) < 4 and (y2 - y1) < 4 then dragStart = nil return end
  local cam = workspace.CurrentCamera
  local objs = (dragMode == "chest") and allChestParts() or allVendingParts()
  local count = 0
  for _, o in ipairs(objs) do
   local wp = worldPosOf(o)
   if wp then
    local sp, on = cam:WorldToViewportPoint(wp)
    if on and sp.X >= x1 and sp.X <= x2 and sp.Y >= y1 and sp.Y <= y2 then
     if dragMode == "chest" then
      if not isChestSelected(o) then table.insert(PFX.selectedChests, o) addChestMarker(o) count = count + 1 end
     else
      local already = false
      for _, v in ipairs(selectedFavorites) do if v == o then already = true break end end
      if not already and #selectedFavorites < MAX_SELECTIONS then table.insert(selectedFavorites, o) addSelectionMarker(o) count = count + 1 end
     end
    end
   end
  end
  dragStart = nil
  updateNotification("Drag Select", "Added " .. count .. " " .. ((dragMode == "chest") and "chest(s)" or "vending(s)"), 2)
 end
 function PFX.setDragMode(mode)
  dragMode = mode
  if beganConn then beganConn:Disconnect() beganConn = nil end
  if changedConn then changedConn:Disconnect() changedConn = nil end
  if endedConn then endedConn:Disconnect() endedConn = nil end
  dragging = false
  dragStart = nil
  if dragFrame then dragFrame.Visible = false end
  if not mode then return end
  ensureDragGui()
  beganConn = UserInputService.InputBegan:Connect(function(input, gp)
   if gp or not dragMode then return end
   if input.UserInputType == Enum.UserInputType.MouseButton1 then
    dragging = true
    dragStart = UserInputService:GetMouseLocation()
    dragFrame.Visible = true
    updateDragFrame(dragStart, dragStart)
   end
  end)
  changedConn = UserInputService.InputChanged:Connect(function(input)
   if not dragMode then return end
   if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
    updateDragFrame(dragStart, UserInputService:GetMouseLocation())
   end
  end)
  endedConn = UserInputService.InputEnded:Connect(function(input)
   if not dragMode then dragging = false return end
   if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
    dragging = false
    doSelect(UserInputService:GetMouseLocation())
   end
  end)
 end
end
_initFX()

-- All six tabs are made here rather than where their contents happen to be
-- written, because a tab appears in the sidebar in the order it was created,
-- and sections no longer live on the tab their code sits next to. AddLeft and
-- AddRight just hand back an element set bound to the column, so they can be
-- called again whenever a later block needs to point somewhere else.
local HomeTab  = Window:MakeTab({Name = "Home",           Icon = TAB_ICONS.Home,               Columns = true})
local ShopTab  = Window:MakeTab({Name = "Shop & Storage", Icon = TAB_ICONS["Shop & Storage"],  Columns = true})
local PriceTab = Window:MakeTab({Name = "Price Tool",     Icon = TAB_ICONS["Price Tool"],      Columns = true})
local FarmTab  = Window:MakeTab({Name = "Farming",        Icon = TAB_ICONS.Farming,            Columns = true})
local SetTab   = Window:MakeTab({Name = "Settings",       Icon = TAB_ICONS.Settings,           Columns = true})

L, R = HomeTab:AddLeft(), HomeTab:AddRight()

UI.about = L:AddSection({Name = "About"})
UI.about:AddParagraph("Welcome to Priz's Islands Hub", "Developed by: Priz\nVersion: 2.0 (Duvome native)\nBuild: " .. PIHD_BUILD .. "\n\nJoin Discord for updates & support:\ndiscord.gg/NuUzrrNaJz")

-- A readout, not a control. Home's rule is that nothing on it touches the game,
-- and counting what is already there does not - but it answers the question the
-- old Home could not: is the hub actually seeing your island?
UI.homeStatus = UI.about:AddParagraph("At A Glance", "Scanning...")
task.spawn(function()
 while true do
  task.wait(3)
  pcall(function()
   local vendings = findVendings and findVendings() or {}
   local coins, withCoins, stocked = 0, 0, 0
   for _, v in ipairs(vendings) do
    pcall(function()
     if v:FindFirstChild("CoinBalance") and v.CoinBalance.Value > 0 then
      coins = coins + v.CoinBalance.Value
      withCoins = withCoins + 1
     end
     local sc = v:FindFirstChild("SellingContents")
     if sc and #sc:GetChildren() > 0 then stocked = stocked + 1 end
    end)
   end
   local bag = 0
   local bp = LP:FindFirstChild("Backpack")
   if bp then
    for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then bag = bag + 1 end end
   end
   UI.homeStatus:Set(string.format(
    "Vendings: %d   stocked %d   holding coins %d\nCoins in machines: %s\nItems in backpack: %d",
    #vendings, stocked, withCoins, formatNumber(coins), bag))
  end)
 end
end)

-- ---------------------------------------------------------------------------
-- Home is a guide. Nothing on it does anything to the game.
--
-- The panels type themselves out, hold, then erase and move to the next page.
-- The About paragraph above is deliberately left static: it carries the build
-- number, which is the one thing on this tab you might need to read at a moment
-- that is not of the animation's choosing.
-- ---------------------------------------------------------------------------
local function TypingPanel(sec, title, pages)
 local para = sec:AddParagraph(title, "")

 -- Every page is padded to the height of the tallest one. A paragraph resizes
 -- itself from its text, so without this the section would grow and shrink on
 -- every keystroke and shove the whole column up and down while you read it.
 local tallest = 0
 for _, page in ipairs(pages) do
  local n = 1
  for _ in page:gmatch("\n") do n = n + 1 end
  if n > tallest then tallest = n end
 end
 local function pad(text)
  local n = 1
  for _ in text:gmatch("\n") do n = n + 1 end
  return text .. string.rep("\n", math.max(0, tallest - n))
 end

 -- Split each page into its lines up front, so typing can run a line at a
 -- time rather than treating the page as one long string. A page arriving all
 -- at once reads as a block of text appearing; a page arriving line by line
 -- reads as someone writing it.
 local split = {}
 for _, page in ipairs(pages) do
  local lines = {}
  for line in (page .. "\n"):gmatch("([^\n]*)\n") do table.insert(lines, line) end
  table.insert(split, lines)
 end

 task.spawn(function()
  -- Staggered, so the panels are not all typing on the same frame.
  task.wait(math.random(0, 200) / 100)
  local i = 1
  while true do
   local lines = split[i]
   local done = {}
   for _, line in ipairs(lines) do
    if line == "" then
     -- a blank line is a beat, not something to type
     table.insert(done, "")
     pcall(function() para:Set(pad(table.concat(done, "\n"))) end)
     task.wait(0.18)
    else
     -- three characters a tick: one at a time turns a short paragraph into
     -- most of a minute before it can be read
     for c = 1, #line, 3 do
      local partial = table.concat(done, "\n")
      if #done > 0 then partial = partial .. "\n" end
      pcall(function() para:Set(pad(partial .. line:sub(1, c))) end)
      task.wait(0.02)
     end
     table.insert(done, line)
     pcall(function() para:Set(pad(table.concat(done, "\n"))) end)
     task.wait(0.12)
    end
   end

   task.wait(5)

   -- Erasing runs faster than typing, and takes whole lines off the bottom,
   -- the way anyone clearing something does it.
   for n = #done, 0, -1 do
    local kept = {}
    for k = 1, n do kept[k] = done[k] end
    pcall(function() para:Set(pad(table.concat(kept, "\n"))) end)
    task.wait(0.06)
   end
   task.wait(0.4)
   i = i + 1
   if i > #pages then i = 1 end
  end
 end)
 return para
end

-- Two a side. All three down the left left the right column empty and the
-- page lopsided.
-- Two a side. All three down the left left the right column empty and the
-- page lopsided.
local howSec = L:AddSection({Name = "How To Use"})
TypingPanel(howSec, "Getting Started", {
 "Four tabs, one job each.\n\nShop & Storage is the shop: chests, bank, coins,\nstock, prices, the sniper.\n\nPrice Tool is what things are worth.\nFarming is crops, travel and combat.\nSettings is everything occasional.",
 "Shop & Storage runs top down.\n\nCoin Operations opens with Run Coins, which funds\nevery machine that is short and drains every one\nholding coins - at any distance.\n\nItem Management opens with Run Items, which flies\nthe list and stocks or drains each machine.",
 "Selection comes first.\n\nMost vending actions ask 'which vendings?'\nUse Selected Only in Vending Tools answers it:\nOFF means every vending you own,\nON means only the ones you ALT+Clicked.",
 "The gear on a row holds its settings.\n\nRestock's gear holds its loop, its interval and\nthe random-item roller. Bank to Vendings holds\nits timer and amount. Auto Farm holds hover trim,\nattack rate and Auto Spawn.\n\nIf a row has a gear, look in it before deciding\nthe row cannot do the thing you want.",
})

local safeSec = R:AddSection({Name = "Before You Run Anything"})
TypingPanel(safeSec, "Worth Knowing", {
 "Destructive actions record how to undo themselves.\n\nEmpty, demolish, coin and bank moves all leave an\nUndo button on their notification, and stay in\nSettings > Undo History until you use them.",
 "An undo is a second action, not a rewind.\n\nBlocks only go back if you still have them.\nItems only go back if they are still on you.\nIt tells you when it could not, instead of\nclaiming it worked.",
 "Loops stop themselves when they stop working.\n\nBank to Vendings quits when the bank runs dry\nrather than firing withdrawals at nothing.\n\nIf a feature goes quiet after a game update,\nrun Settings > Self Test - it checks every\nremote and folder the hub depends on.",
 "Panels take the left and right of the window.\n\nTwo at a time. Open a third and the one you\nopened first steps aside.",
})

local tipSec = R:AddSection({Name = "Tips"})
TypingPanel(tipSec, "Things People Miss", {
 "Price Tool saves your shop to a file.\n\nSources holds Save Prices, the delete, and a\nwebhook box - paste your own and every save is\nposted to your channel as JSON.\n\nNothing is sent unless you fill that box in.",
 "Farming starts with Travel, at the top.\n\nPick the island, press Teleport. Combat is below\nit: Target Type switches the one Target list\nbetween mobs and bosses, so there is no second\ndropdown quietly overriding the first.",
 "Ctrl and drag the window edge to resize it.\n\nThe sidebar expands when you hover it, and the\ntab search at its top filters the tabs.",
 "Configs are per profile, saved from the topbar.\n\nSet up a farming loadout once, a shop loadout\nonce, and swap between them.",
})

-- Home is information and nothing else. What used to be on it is split by what
-- it does: the scanner, favourites and openables are occasional things, so they
-- sit with the settings; chests are storage, so they sit with the shop.
L, R = SetTab:AddLeft(), SetTab:AddRight()

UI.homeScanner = L:AddSection({Name = "Scanner & Stats"})

-- Scanner output lives in a side panel rather than a paragraph on the tab.
-- Results run to a dozen lines, and inline they pushed every control below
-- them off the screen; in a panel they scroll on their own.
--
-- The text is a bare label parented into the panel, not a paragraph element:
-- a paragraph brings its own framed card, and a card inside a panel is a box
-- inside a box saying the same thing twice.
local outPanel = Duvome:MakeSidePanel({ Name = "Scanner Output", Width = 158, Height = 300, Side = "right" })
local outLabel = Instance.new("TextLabel")
outLabel.BackgroundTransparency = 1
outLabel.Font                   = Enum.Font.Gotham
outLabel.TextSize               = 12
outLabel.TextColor3             = Color3.fromRGB(225, 220, 235)
outLabel.TextXAlignment         = Enum.TextXAlignment.Left
outLabel.TextYAlignment         = Enum.TextYAlignment.Top
outLabel.TextWrapped            = true
outLabel.RichText               = false
outLabel.Text                   = "Run a scan to see it here."
-- AutomaticSize, not a TextBounds measurement on the Text signal. TextBounds
-- for a wrapped label is only correct after the engine has laid it out, so the
-- measured version read a stale height, the label stayed 40px, and the panel -
-- a ScrollingFrame, which clips - showed the first scan and swallowed the rest.
-- That is why picking several modes only ever displayed one.
outLabel.AutomaticSize          = Enum.AutomaticSize.Y
outLabel.Size                   = UDim2.new(1, 0, 0, 0)
outLabel.Parent                 = outPanel:Container()
UI.output = { Set = function(_, txt) outLabel.Text = txt end }

UI.outputPanel = outPanel

UI.homeScanner:AddToggle({
 Name = "Output Panel",
 Default = false,
 Tooltip = "Opens the panel that scan results are written to.",
 Callback = function(value)
  pcall(function() if value then outPanel:Show() else outPanel:Hide() end end)
 end,
})

local selectedMode = "Coin Scanner"
local selectedModes = {"Coin Scanner"}
local playerList = {}

local function refreshPlayersForScanner()
 playerList = {}
 for _, player in pairs(Players:GetPlayers()) do
  table.insert(playerList, player.Name)
 end
 if #playerList == 0 then
  table.insert(playerList, "No players")
 end
 return playerList
end

playerList = refreshPlayersForScanner()

-- Player info and island code moved to the player-action list, which already
-- has a target-player dropdown; keeping a second one here just to feed this
-- mode meant two places to pick a player.
UI.homeScanner:AddDropdown({Name = "Mode", Options = {"Coin Scanner", "Items Scanner", "Vending Mode Scanner", "Blocks Scanner", "Show Statistics", "Show Transaction History"}, Default = {"Coin Scanner"}, MultiSelect = true, SelectAll = true, Flag = autoFlag("home"), Callback = function(chosen)
 selectedModes = chosen or {}
end})

-- One scan. Apply runs it once per selected mode, appending as it goes, so
-- picking three modes gives one report rather than three that overwrite it.
local function runScan()
 if selectedMode == "Coin Scanner" then
  local vendings = findVendings()
  local totalCoins, vendingCount = 0, 0
  for _, vending in ipairs(vendings) do pcall(function() if vending:FindFirstChild("CoinBalance") then totalCoins = totalCoins + vending.CoinBalance.Value vendingCount = vendingCount + 1 end end) end
  local resultText = string.format("Total Vendings: %d\nVendings with Coins: %d\nTotal Coins: %s", #vendings, vendingCount, formatNumber(totalCoins))
  setOutput("Coin Scanner", resultText)
  if totalCoins > 0 then
   updateNotification("Scan Complete", formatNumber(totalCoins) .. " Coins Found", 2)
  else
   updateNotification("Scan Complete", "No Coins Found", 2)
  end
 elseif selectedMode == "Items Scanner" then
  local vendings, itemCounts = findVendings(), {}
  for _, vending in ipairs(vendings) do
   pcall(function()
    local sellingContents = vending:FindFirstChild("SellingContents")
    if sellingContents then
     for _, item in pairs(sellingContents:GetChildren()) do
      if item:IsA("Tool") then
       local displayName = getDisplayName(item)
       local amount = item:FindFirstChild("Amount") and item.Amount.Value or 1
       itemCounts[displayName] = (itemCounts[displayName] or 0) + amount
      end
     end
    end
   end)
  end
  local resultText, itemCount = "Total Types: 0\n\n", 0
  for itemName, amount in pairs(itemCounts) do itemCount = itemCount + 1 resultText = resultText .. itemName .. ": " .. amount .. "\n" end
  if itemCount == 0 then resultText = "No items found" else resultText = string.format("Total Types: %d\n\n", itemCount) .. resultText:sub(16) end
  setOutput("Items Scanner", resultText)
  if itemCount == 0 then
   updateNotification("Scan Complete", "No Items Found", 2)
  else
   updateNotification("Scan Complete", itemCount .. " Item Types Found", 2)
  end
 elseif selectedMode == "Vending Mode Scanner" then
  local vendings = findVendings()
  local buyCount, sellCount, offlineCount = 0, 0, 0
  for _, vending in ipairs(vendings) do pcall(function() if vending:FindFirstChild("Mode") then local mode = vending.Mode.Value if mode == 0 then buyCount = buyCount + 1 elseif mode == 1 then sellCount = sellCount + 1 elseif mode == 2 then offlineCount = offlineCount + 1 end end end) end
  local resultText = string.format("Total: %d\n\nBuy: %d\nSell: %d\nOffline: %d", #vendings, buyCount, sellCount, offlineCount)
  setOutput("Vending Mode Scanner", resultText)
  updateNotification("Scan Complete", #vendings .. " Vendings Scanned", 2)
 elseif selectedMode == "Blocks Scanner" then
  local objectCounts, totalObjects = {}, 0
  local islands = WS:FindFirstChild("Islands")
  if islands then
   for _, island in pairs(islands:GetChildren()) do
    local blocks = island:FindFirstChild("Blocks")
    if blocks then
     for _, block in pairs(blocks:GetChildren()) do
      totalObjects = totalObjects + 1
      local displayName = block.Name
      local function findDisplayName(obj)
       local dn = obj:FindFirstChild("DisplayName")
       if dn then
        if dn:IsA("StringValue") then return dn.Value end
        if dn:IsA("Model") or dn:IsA("Part") or dn:IsA("BillboardGui") then
         local textLabel = dn:FindFirstChildOfClass("TextLabel", true)
         if textLabel and textLabel.Text then return textLabel.Text end
        end
       end
       for _, child in pairs(obj:GetDescendants()) do
        if child.Name == "DisplayName" and child:IsA("StringValue") then
         return child.Value
        end
       end
       return nil
      end
      local foundName = findDisplayName(block)
      if foundName then displayName = foundName end
      objectCounts[displayName] = (objectCounts[displayName] or 0) + 1
     end
    end
   end
  end
  local sortedObjects = {}
  for name, count in pairs(objectCounts) do table.insert(sortedObjects, {name = name, count = count}) end
  table.sort(sortedObjects, function(a, b) return a.count > b.count end)
  local resultText = string.format("Total: %d | Types: %d\n\n", totalObjects, #sortedObjects)
  for _, obj in ipairs(sortedObjects) do resultText = resultText .. obj.name .. ": " .. obj.count .. "\n" end
  setOutput("Blocks Scanner", resultText)
  updateNotification("Blocks Scanner", totalObjects .. " objects!", 2)
 elseif selectedMode == "Show Statistics" then
  local statsText = string.format("Coins Withdrawn: %s\nCoins Deposited: %s\nItems Deposited: %d\nItems Withdrawn: %d\nVendings Modified: %d\nBank Deposits: %d\nBank Withdrawals: %d", formatNumber(S.statistics.coinsWithdrawn), formatNumber(S.statistics.coinsDeposited), S.statistics.itemsDeposited, S.statistics.itemsWithdrawn, S.statistics.vendingsModified, S.statistics.bankDeposits, S.statistics.bankWithdrawals)
  setOutput("Session Statistics", statsText)
  updateNotification("Statistics", "Displayed!", 2)
 elseif selectedMode == "Show Transaction History" then
  local displayText, displayCount = "", math.min(10, #S.transactionHistory)
  if displayCount == 0 then displayText = "No transactions yet..."
  else for i = 1, displayCount do local t = S.transactionHistory[i] displayText = displayText .. t.time .. " | " .. t.details if i < displayCount then displayText = displayText .. "\n" end end end
  setOutput("Transaction History (Last 10)", displayText)
  updateNotification("History", "Displayed!", 2)
 end
end

UI.homeScanner:AddButton({Name = "Apply", Tooltip = "Runs every selected scanner and writes the results to the output panel.", Callback = function()
 local modes = selectedModes
 if #modes == 0 then modes = {"Coin Scanner"} end
 outAppend = false
 for _, m in ipairs(modes) do
  selectedMode = m
  runScan()
  outAppend = true
 end
 outAppend = false
end})

UI.openables = R:AddSection({Name = "Openables Opener"})

S.cauldronEnabled = false
S.autoWalkToCauldron = false
S.openedCauldrons = {}
S.cauldronLoopSpeed = 0.5
S.cauldronOpenDelay = 0.1
S.openableType = "All"

UI.openables:AddDropdown({Name = "Openable Type", Options = {"All", "Cauldrons (All Types)", "Presents & Envelopes", "Treasure Chests (All Types)", "Serpent Eggs", "Dragon Eggs", "Dungeon Chests"}, Default = "All", Flag = autoFlag("home"), Callback = function(value)
 S.openableType = value
 S.openedCauldrons = {}
end})

local function findCauldrons()
 local cauldrons = {}
 if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return cauldrons end
 local hrp = LP.Character.HumanoidRootPart
 for _, island in pairs(WS.Islands:GetChildren()) do
  local blocks = island:FindFirstChild("Blocks")
  if blocks then
   for _, obj in pairs(blocks:GetChildren()) do
    local objName = obj.Name
    local objNameLower = objName:lower()
    local shouldAdd = false
    if S.openableType == "Cauldrons (All Types)" and objNameLower:find("cauldron") then
     shouldAdd = true
    elseif S.openableType == "Presents & Envelopes" and (objNameLower:find("present") or objNameLower:find("envelope")) then
     shouldAdd = true
    elseif S.openableType == "Treasure Chests (All Types)" and (objNameLower:find("treasurechest") or objNameLower:find("treasure chest") or objNameLower:find("chest")) then
     shouldAdd = true
    elseif S.openableType == "Serpent Eggs" and (objNameLower:find("serpent") or objNameLower:find("egg")) then
     shouldAdd = true
    elseif S.openableType == "Dragon Eggs" and (objNameLower:find("dragon") or (objNameLower:find("infernal") and objNameLower:find("egg"))) then
     shouldAdd = true
    elseif S.openableType == "Dungeon Chests" and (objNameLower:find("dungeon")) then
     shouldAdd = true
    elseif S.openableType == "All" then
     if objNameLower:find("cauldron") or objNameLower:find("present") or objNameLower:find("envelope") or
        objNameLower:find("treasurechest") or objNameLower:find("treasure") or objNameLower:find("chest") or
        objNameLower:find("serpent") or objNameLower:find("dragon") or objNameLower:find("egg") or
        objNameLower:find("dungeon") then
      shouldAdd = true
     end
    end
    if shouldAdd then
     local prompt = obj:FindFirstChildOfClass("ProximityPrompt", true)
     if prompt then
      local dist = (obj.Position - hrp.Position).Magnitude
      if useRadiusLimit then
       if withinRadius(obj.Position) then
        table.insert(cauldrons, {object = obj, distance = dist, prompt = prompt, name = obj.Name})
       end
      else
       table.insert(cauldrons, {object = obj, distance = dist, prompt = prompt, name = obj.Name})
      end
     end
    end
   end
  end
 end
 table.sort(cauldrons, function(a, b) return a.distance < b.distance end)
 return cauldrons
end

S.lastDelayWarn = 0
UI.openables:AddSlider({Name = "Open Delay (s)", Min = 0.01, Max = 1, Increment = 0.01, Default = 0.1, ValueName = "s", Flag = autoFlag("home"), Callback = function(value)
 S.cauldronLoopSpeed = value
 S.cauldronOpenDelay = value
 if value <= 0.03 and (tick() - S.lastDelayWarn) > 1.5 then
  S.lastDelayWarn = tick()
  updateNotification("Warning", "Very low delay - can lag or crash you with lots of openables!", 4)
 end
end})

UI.openables:AddToggle({Name = "Enable Opener", Default = false, Tooltip = "Opens EVERYTHING of the selected type continuously - no batching, no cap. Lower delay = faster but more lag.", Flag = autoFlag("home"), Callback = initGuard(function(value)
 S.cauldronEnabled = value
 if value then
  updateNotification("Openables", "Enabled Opening " .. S.openableType, 2)
  if S.cauldronOpenDelay <= 0.03 then
   updateNotification("Warning", "Very low delay - may lag or crash your game!", 4)
  end
  if S.openableType == "Presents & Envelopes" then
   task.spawn(function()
    local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("client_request_22")
    while S.cauldronEnabled do
     pcall(function()
      Net:InvokeServer({})
     end)
     task.wait(S.cauldronOpenDelay)
    end
   end)
  else
   task.spawn(function()
    local warnedThisRun = false
    while S.cauldronEnabled do
     pcall(function()
      if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
       local openables = findCauldrons()
       if #openables == 0 then
        task.wait(1)
        return
       end

       if not warnedThisRun and #openables >= 150 then
        updateNotification("Heads up", #openables .. " openables in range - this may lag. Lower your radius if it does.", 4)
        warnedThisRun = true
       end
       for _, openableData in ipairs(openables) do
        if not S.cauldronEnabled then break end
        if openableData.prompt and openableData.prompt.Enabled then
         pcall(function()
          fireproximityprompt(openableData.prompt)
         end)
         task.wait(S.cauldronOpenDelay)
        end
       end
      end
     end)
     task.wait(0.25)
    end
   end)
  end
 else
  updateNotification("Openables", "Disabled Opening " .. S.openableType, 2)
 end
end)})

S.collectCauldronItems = false
UI.openables:AddToggle({Name = "Collect Items", Default = false, Tooltip = "Fires cauldron prompts within 15 studs to collect drops.", Flag = autoFlag("home"), Callback = initGuard(function(value)
 S.collectCauldronItems = value
 if value then
  task.spawn(function()
   while S.collectCauldronItems do
    task.wait(0.5)
    pcall(function()
     if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
      local hrp = LP.Character.HumanoidRootPart
      local collected = 0
      local MAX_PER_CYCLE = 8
      for _, island in pairs(WS.Islands:GetChildren()) do
       if not S.collectCauldronItems or collected >= MAX_PER_CYCLE then break end
       local blocks = island:FindFirstChild("Blocks")
       if blocks then
        for _, obj in pairs(blocks:GetChildren()) do
         if not S.collectCauldronItems or collected >= MAX_PER_CYCLE then break end
         if obj.Name:lower():find("cauldron") then
          local prompt = obj:FindFirstChildOfClass("ProximityPrompt", true)
          if prompt and prompt.Enabled then
           local dist = (obj.Position - hrp.Position).Magnitude
           if dist <= 15 then
            local success = pcall(function()
             fireproximityprompt(prompt)
            end)
            if success then
             collected = collected + 1
             task.wait(0.05)
            end
           end
          end
         end
        end
       end
      end
     end
    end)
   end
  end)
  updateNotification("Cauldron Items", "Collecting items in 15 studs!", 3)
 else
  updateNotification("Cauldron Items", "Disabled", 2)
 end
end)})

UI.openables:AddToggle({Name = "Auto Walk", Default = false, Tooltip = "Walks to the nearest openable, opens it, and withdraws.", Flag = autoFlag("home"), Callback = initGuard(function(value)
 S.autoWalkToCauldron = value
 if value then
  updateNotification("Enabled Auto Walk", "", 2)
  task.spawn(function()
   local lastOpenedTime = 0
   local consecutiveErrors = 0
   local lastPosition = nil
   local stuckCounter = 0
   local lastJumpTime = 0
   while S.autoWalkToCauldron do
    task.wait(0.5)
    local success = pcall(function()
     if not LP or not LP.Character then return end
     local humanoid = LP.Character:FindFirstChild("Humanoid")
     local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
     if not humanoid or not hrp then return end
     local cauldrons = findCauldrons()
     if #cauldrons == 0 then
      updateNotification("No More Openables Found", "", 2)
      S.autoWalkToCauldron = false
      return
     end
     local nearest = cauldrons[1]
     if not nearest or not nearest.object then return end
     local currentPos = hrp.Position
     if lastPosition then
      local distanceMoved = (currentPos - lastPosition).Magnitude
      if distanceMoved < 0.5 then
       stuckCounter = stuckCounter + 1
       if stuckCounter >= 4 then
        local currentTime = tick()
        if currentTime - lastJumpTime > 1 then
         humanoid.Jump = true
         lastJumpTime = currentTime
         task.wait(0.3)
        end
        local directionToTarget = (nearest.object.Position - hrp.Position).Unit
        local rightVector = Vector3.new(-directionToTarget.Z, 0, directionToTarget.X)
        local avoidDirection = stuckCounter % 2 == 0 and rightVector or -rightVector
        local avoidPosition = hrp.Position + (avoidDirection * 5) + (directionToTarget * 3)
        humanoid:MoveTo(avoidPosition)
        updateNotification("Unstuck", "Going around obstacle...", 1)
        task.wait(1)
        stuckCounter = 0
       end
      else
       stuckCounter = 0
      end
     end
     lastPosition = currentPos
     if nearest.distance > 12 then
      humanoid:MoveTo(nearest.object.Position)
     else
      local currentTime = tick()
      if currentTime - lastOpenedTime >= 3 then
       if nearest.prompt and nearest.prompt.Enabled and not S.openedCauldrons[nearest.object] then
        local openSuccess = pcall(function()
         fireproximityprompt(nearest.prompt)
         task.wait(0.5)
         pcall(function()
          local args = {
           {
            chest = nearest.object,
            player_tracking_category = "join_from_web",
            amount = 999,
            tool = Instance.new("Tool", nil),
            action = "withdraw"
           }
          }
          game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("CLIENT_CHEST_TRANSACTION"):InvokeServer(unpack(args))
         end)
         S.openedCauldrons[nearest.object] = true
         lastOpenedTime = currentTime
         updateNotification("Opened + Withdrew", nearest.name, 1)
        end)
        if openSuccess then
         consecutiveErrors = 0
         stuckCounter = 0
         lastPosition = nil
         task.wait(3)
        end
       end
      end
     end
    end)
    if not success then
     consecutiveErrors = consecutiveErrors + 1
     if consecutiveErrors >= 8 then
      updateNotification("Auto Walk", "Too many errors, stopping!", 3)
      S.autoWalkToCauldron = false
      break
     end
    else
     consecutiveErrors = 0
    end
   end
  end)
 else
  pcall(function()
   if LP.Character and LP.Character:FindFirstChild("Humanoid") then
    LP.Character.Humanoid:Move(Vector3.new(0, 0, 0))
   end
  end)
  updateNotification("Disabled Auto Walk", "", 2)
 end
end)})

-- Chests are storage, and storage belongs beside the shop that draws on it.
L, R = ShopTab:AddLeft(), ShopTab:AddRight()

-- LayoutOrder 10, so it sits below Vending Configuration even though its code
-- runs a thousand lines earlier. Collapsed by default like the sections around
-- it - it is a lot of controls for something you use in bursts.
UI.chest = L:AddSection({Name = "Chest Manager", Collapsible = true, LayoutOrder = 3})

-- 0 means the whole stack, which is what a manual click does. Anything else is
-- a cap: deposit that many, or everything you have if you have less.
S.chestDepositAmount = 0
UI.chest:AddTextbox({
 Name = "Amount", Default = "", TextDisappear = false,
 Tooltip = "How many to deposit per chest. Leave empty or 0 to deposit the whole stack.",
 Validate = function(text)
  if text == "" then return true end
  if not parseAmount(text) then return false, "Numbers only, e.g. 5 or 2k" end
  if parseAmount(text) < 0 then return false, "Cannot be negative" end
  return true
 end,
 Callback = function(text)
  S.chestDepositAmount = (text == "") and 0 or (parseAmount(text) or 0)
 end,
})

UI.chest:AddDropdown({Name = "Chest Type", Options = {"All", "Expanded Diamond Chest", "Diamond Chest", "Industrial Large Chest", "Industrial Large Chest (IO)", "Large Chest", "Industrial Medium Chest", "Industrial Medium Chest (IO)", "Medium Chest", "Timed Industrial Chest", "Small Chest"}, Default = {"All"}, MultiSelect = true, Search = true, SelectAll = true, Tooltip = "Only act on these chest types. ALT+Click or drag-selected chests always override this.", Flag = autoFlag("home"), Callback = function(chosen)
 if not chosen or #chosen == 0 then S.chestTypeSet = nil return end
 local set, all = {}, false
 for _, d in ipairs(chosen) do
  if d == "All" then all = true break end
  local internal = S.CHEST_TYPES[d]
  if internal then set[internal] = true end
 end
 if all or next(set) == nil then S.chestTypeSet = nil else S.chestTypeSet = set end
end})

-- Radius, drag-select and clearing used to be duplicated here. Selecting things
-- is one job whatever you are selecting, so it lives in Vending Tools now: pick
-- Chests as the drag target there, and the same Radius Limit and Clear All apply.

S.autoDepositChests = false

S.CHEST_TYPES = {
 ["Expanded Diamond Chest"] = "diamondChestT2",
 ["Diamond Chest"] = "diamondChestT1",
 ["Industrial Medium Chest"] = "chestMediumIndustrial",
 ["Medium Chest"] = "chestMedium",
 ["Industrial Medium Chest (IO)"] = "chestMediumIndustrialIO",
 ["Timed Industrial Chest"] = "chestIndustrialTimed",
 ["Large Chest"] = "chestLarge",
 ["Industrial Large Chest"] = "chestLargeIndustrial",
 ["Industrial Large Chest (IO)"] = "chestLargeIndustrialIO",
 ["Small Chest"] = "chestSmall",
}
S.chestTypeSet = nil

local chestRadiusLimit, chestRadius = false, 100
local function findChests()

 if #PFX.selectedChests > 0 then
  local valid = {}
  for _, c in ipairs(PFX.selectedChests) do if c and c.Parent then table.insert(valid, c) end end
  return valid
 end
 local list = {}
 local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
 if not hrp then return list end
 for _, obj in WS.Islands:GetDescendants() do
  if obj:IsA("BasePart") and (obj.Name:find("Chest") or obj.Name:find("chest")) then
   local typeOk = true
   if S.chestTypeSet and not S.chestTypeSet[obj.Name] then typeOk = false end
   if typeOk then
    local inRange = true
    if chestRadiusLimit then
     inRange = (obj.Position - hrp.Position).Magnitude <= chestRadius
    elseif useRadiusLimit then
     inRange = withinRadius(obj.Position)
    end
    if inRange then table.insert(list, obj) end
   end
  end
 end
 return list
end

S.CHEST_TRANSACTION = nil
S.CHEST_TOGGLE = nil
local function getChestNet()
 if not S.CHEST_TRANSACTION then
  pcall(function()
   local n = RS:FindFirstChild("rbxts_include") and RS.rbxts_include:FindFirstChild("node_modules")
   if not n then return end
   local managed = n:FindFirstChild("@rbxts") and n["@rbxts"]:FindFirstChild("net") and n["@rbxts"].net:FindFirstChild("out") and n["@rbxts"].net.out:FindFirstChild("_NetManaged")
   if not managed then return end
   S.CHEST_TRANSACTION = managed:FindFirstChild("CLIENT_CHEST_TRANSACTION")
   S.CHEST_TOGGLE = managed:FindFirstChild("CHEST_TOGGLE")
  end)
 end
end

local function openChest(chest)
 getChestNet()
 if not S.CHEST_TOGGLE then return end
 pcall(function()
  local args = {{chest = chest, open = true}}
  S.CHEST_TOGGLE:InvokeServer(unpack(args))
 end)
end

local function closeChest(chest)
 getChestNet()
 if not S.CHEST_TOGGLE then return end
 pcall(function()
  local args = {{chest = chest, open = false}}
  S.CHEST_TOGGLE:InvokeServer(unpack(args))
 end)
end

S.useHeldItemChest = true
S.selectedChestItem = nil
S.selectedChestItems = {}
S.chestItemsList = {}

local function deposit()
 local tool = nil
 if not S.useHeldItemChest then
  if not S.selectedChestItem or S.selectedChestItem == "No items" then
   updateNotification("Error", "Please select an item from dropdown!", 3)
   return
  end
  for _, item in pairs(LP.Backpack:GetChildren()) do
   if item:IsA("Tool") and getDisplayName(item) == S.selectedChestItem then
    tool = item
    break
   end
  end
  if not tool and LP.Character then
   for _, item in pairs(LP.Character:GetChildren()) do
    if item:IsA("Tool") and getDisplayName(item) == S.selectedChestItem then
     tool = item
     break
    end
   end
  end
  if not tool then
   updateNotification("Error", S.selectedChestItem .. " not found!", 3)
   return
  end
 else
  tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
  if not tool then
   updateNotification("Error", "Please hold an item in your hand!", 3)
   return
  end
 end

 if tool.Parent == LP.Character then
  tool.Parent = LP.Backpack
  task.wait(0.1)
 end

 local btool = LP.Backpack:FindFirstChild(tool.Name)
 if not btool then
  updateNotification("Error", "Item not in backpack!", 3)
  return
 end

 local chests = findChests()
 if #chests == 0 then
  updateNotification("Error", "No chests found!", 3)
  return
 end

 local amount = btool:FindFirstChild("Amount") and btool.Amount.Value or 1
 -- Clamped, never raised: asking for 5 of an item you have 3 of deposits 3.
 if S.chestDepositAmount and S.chestDepositAmount > 0 then
  amount = math.min(amount, S.chestDepositAmount)
 end
 if amount <= 0 then
  updateNotification("Error", "Item is empty (0 amount)!", 3)
  return
 end

 for _, chest in chests do
  task.spawn(function()
   pcall(function()
    local args = {{
     chest = chest,
     player_tracking_category = "join_from_web",
     amount = amount,
     tool = btool,
     action = "deposit"
    }}
    getChestNet()
    if S.CHEST_TRANSACTION then
    S.CHEST_TRANSACTION:InvokeServer(unpack(args))
    end
   end)
  end)
 end

 task.wait(0.3)
 updateNotification("Deposited " .. formatNumber(amount) .. " to " .. #chests .. " Chests", "", 2)
end

local function withdraw()
 local chests = findChests()
 if #chests == 0 then
  updateNotification("Error", "No chests found!", 3)
  return
 end

 updateNotification("Withdrawing", "Processing " .. #chests .. " chests...", 2)
 local totalWithdrawn = 0

 for _, chest in chests do
  task.spawn(function()
   pcall(function()
    openChest(chest)
    task.wait(0.1)
    local contents = chest:FindFirstChild("Contents")
    if contents then
     for _, chestTool in pairs(contents:GetChildren()) do
      if chestTool:IsA("Tool") then
       pcall(function()
        local amount = chestTool:FindFirstChild("Amount") and chestTool.Amount.Value or 1
        local withdrawArgs = {{
         chest = chest,
         player_tracking_category = "join_from_web",
         amount = amount,
         tool = chestTool,
         action = "withdraw"
        }}
        getChestNet()
        if S.CHEST_TRANSACTION then
        S.CHEST_TRANSACTION:InvokeServer(unpack(withdrawArgs))
        end
        totalWithdrawn = totalWithdrawn + 1
        task.wait(0.02)
       end)
      end
     end
    end
    task.wait(0.1)
    closeChest(chest)
   end)
  end)
 end

 task.wait(1)
 updateNotification("Withdrew from " .. #chests .. " Chests", "", 2)
end

local function refreshChestItems()
 table.clear(S.chestItemsList)
 for _, item in pairs(LP.Backpack:GetChildren()) do
  if item:IsA("Tool") then
   table.insert(S.chestItemsList, getDisplayName(item))
  end
 end
 table.sort(S.chestItemsList)
 if #S.chestItemsList == 0 then
  table.insert(S.chestItemsList, "No items")
 else
  if not S.selectedChestItem or S.selectedChestItem == "No items" then
   S.selectedChestItem = S.chestItemsList[1]
  end
 end
 if UI.chestDropdown then
  UI.chestDropdown:Refresh(S.chestItemsList, true)
 end
 return S.chestItemsList
end

refreshChestItems()

refreshChestItems()

UI.chestDropdown = UI.chest:AddDropdown({Name = "Item", Options = S.chestItemsList, Default = {}, MultiSelect = true, Search = true, SelectAll = true, Flag = autoFlag("home"), Callback = function(chosen)
 S.selectedChestItems = chosen or {}
 S.selectedChestItem = S.selectedChestItems[1]
end})

if not S.selectedChestItem and #S.chestItemsList > 0 and S.chestItemsList[1] ~= "No items" then
 S.selectedChestItem = S.chestItemsList[1]
end

S.autoWithdrawChests = false
-- Buttons, not toggles. One click does one pass; turning Loop on in the gear
-- turns the row into a toggle that repeats it. Same shape as the bank and coin
-- rows, so "do it once" and "keep doing it" are the same control everywhere.
UI.chest:AddButton({
 Name = "Withdraw", Loop = true, LoopEvery = 3,
 Tooltip = "Withdraws every item from the matching chests. Turn on Loop in the gear to repeat it.",
 Callback = function() pcall(withdraw) end,
})

local function depositHeldToChests()
    local tools = {}
    if #S.selectedChestItems > 0 then
     for _, itemName in ipairs(S.selectedChestItems) do
      for _, t in pairs(LP.Backpack:GetChildren()) do
       if t:IsA("Tool") and getDisplayName(t) == itemName then table.insert(tools, t) end
      end
     end
    else
     local heldTool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
     if heldTool then
      local t = LP.Backpack:FindFirstChild(heldTool.Name) or heldTool
      if t and t:IsA("Tool") then table.insert(tools, t) end
     end
    end
    if #tools > 0 then
     local chests = findChests()
     if #chests > 0 then
      getChestNet()
      for _, tool in ipairs(tools) do
       local amount = tool:FindFirstChild("Amount") and tool.Amount.Value or 1
       if S.chestDepositAmount and S.chestDepositAmount > 0 then
        amount = math.min(amount, S.chestDepositAmount)
       end
       if amount > 0 then
        for _, chest in chests do
         pcall(function()
          local args = {{chest = chest, player_tracking_category = "join_from_web", amount = amount, tool = tool, action = "deposit"}}
          if S.CHEST_TRANSACTION then S.CHEST_TRANSACTION:InvokeServer(unpack(args)) end
         end)
        end
       end
      end
     end
    end
end

UI.chest:AddButton({
 Name = "Deposit", Loop = true, LoopEvery = 3,
 Tooltip = "Deposits your selected items, or the held item if none are selected, into the matching chests. Turn on Loop in the gear to repeat it.",
 Callback = function() pcall(depositHeldToChests) end,
})

L, R = SetTab:AddLeft(), SetTab:AddRight()

UI.homeActions = L:AddSection({Name = "Favorites & Groups"})

S.favGroupMode = "Save as Favorites"

UI.homeActions:AddDropdown({Name = "Select Action", Options = {"Save as Favorites", "Load Favorites", "Save as Group", "Load Group", "Show Group ESP", "Hide Group ESP", "Use Group for Operations", "Use All Vendings", "Delete Group"}, Default = "Save as Favorites", Flag = autoFlag("home"), Callback = function(value) S.favGroupMode = value end})

S.groupNameInput = ""
S.savedGroupsList = {"None"}
for groupName, _ in pairs(S.vendingGroups) do if groupName ~= "Default" then table.insert(S.savedGroupsList, groupName) end end
S.selectedGroupName = "None"

UI.homeActions:AddTextbox({Name = "Group Name", Default = "", TextDisappear = false, Callback = function(text) S.groupNameInput = text end})
UI.homeActions:AddDropdown({Name = "Saved Group", Options = S.savedGroupsList, Default = "None", Search = true, Flag = autoFlag("home"), Callback = function(value) S.selectedGroupName = value end})

S.groupESPObjects = {}
local function removeGroupESP() for _, espData in ipairs(S.groupESPObjects) do if espData.highlight then pcall(function() espData.highlight:Destroy() end) end if espData.billboard then pcall(function() espData.billboard:Destroy() end) end end S.groupESPObjects = {} end

UI.homeActions:AddButton({Name = "Apply", Callback = function()
 if S.favGroupMode == "Save as Favorites" then if #selectedFavorites == 0 then updateNotification("Error", "No vendings selected!", 3) return end favoriteVendings = selectedFavorites saveFavorites() updateNotification("Saved", "Saved " .. #favoriteVendings .. " favorites!", 3) for _, vending in ipairs(selectedFavorites) do local heart = vending:FindFirstChild("FavoriteHeart") if heart then heart:Destroy() end end selectedFavorites = {}
 elseif S.favGroupMode == "Load Favorites" then loadFavorites() if #favoriteVendings > 0 then updateNotification("Loaded", "Loaded " .. #favoriteVendings .. " favorites!", 2) else updateNotification("No Favorites", "No favorites saved!", 2) end
 elseif S.favGroupMode == "Save as Group" then if S.groupNameInput == "" then updateNotification("Error", "Enter group name!", 3) return end local vendings = findVendings() if #vendings == 0 then updateNotification("Error", "No vendings!", 3) return end S.vendingGroups[S.groupNameInput] = {} for _, vending in ipairs(vendings) do table.insert(S.vendingGroups[S.groupNameInput], {x = vending.Position.X, y = vending.Position.Y, z = vending.Position.Z, name = vending.Name}) end local groupsData = {} for groupName, vendingList in pairs(S.vendingGroups) do if groupName ~= "Default" then groupsData[groupName] = vendingList end end pcall(function() writefile("VendingManager_Groups.json", HttpService:JSONEncode(groupsData)) end) updateNotification("Group Saved", "Saved '" .. S.groupNameInput .. "' with " .. #vendings .. " vendings!", 5)
 elseif S.favGroupMode == "Load Group" then if S.groupNameInput == "" and S.selectedGroupName == "None" then updateNotification("Error", "Enter/select group name!", 3) return end local groupToLoad = S.groupNameInput ~= "" and S.groupNameInput or S.selectedGroupName if S.vendingGroups[groupToLoad] then updateNotification("Loaded", "Group '" .. groupToLoad .. "' exists with " .. #S.vendingGroups[groupToLoad] .. " vendings!", 3) else updateNotification("Error", "Group not found!", 3) end
 elseif S.favGroupMode == "Show Group ESP" then
  if S.selectedGroupName == "None" or not S.vendingGroups[S.selectedGroupName] then
   updateNotification("Error", "Select group!", 3)
   return
  end
  removeGroupESP()
  local group = S.vendingGroups[S.selectedGroupName]
  local vendings = {}
  local islands = WS:FindFirstChild("Islands")
  if islands then
   for _, island in pairs(islands:GetChildren()) do
    local blocks = island:FindFirstChild("Blocks")
    if blocks then
     for _, obj in pairs(blocks:GetChildren()) do
      if obj.Name:find("vending") or obj.Name:find("Vending") then
       table.insert(vendings, obj)
      end
     end
    end
   end
  end
  for i, vendingData in ipairs(group) do
   local savedPos = Vector3.new(vendingData.x, vendingData.y, vendingData.z)
   for _, vending in ipairs(vendings) do
    if (vending.Position - savedPos).Magnitude < 1 then
     local highlight = Instance.new("Highlight")
     highlight.FillColor = Color3.fromRGB(255, 165, 0)
     highlight.Parent = vending
     local billboard = Instance.new("BillboardGui")
     billboard.AlwaysOnTop = true
     billboard.Size = UDim2.new(0, 200, 0, 60)
     billboard.StudsOffset = Vector3.new(0, 3, 0)
     billboard.Parent = vending
     local textLabel = Instance.new("TextLabel")
     textLabel.BackgroundTransparency = 1
     textLabel.Size = UDim2.new(1, 0, 1, 0)
     textLabel.Text = S.selectedGroupName .. " #" .. i
     textLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
     textLabel.TextStrokeTransparency = 0
     textLabel.TextScaled = true
     textLabel.Font = Enum.Font.SourceSansBold
     textLabel.Parent = billboard
     table.insert(S.groupESPObjects, {vending = vending, highlight = highlight, billboard = billboard})
     break
    end
   end
  end
  updateNotification("ESP", "Showing " .. #S.groupESPObjects, 2)
 elseif S.favGroupMode == "Hide Group ESP" then removeGroupESP() updateNotification("ESP", "Hidden", 2)
 elseif S.favGroupMode == "Use Group for Operations" then if S.selectedGroupName == "None" or not S.vendingGroups[S.selectedGroupName] then updateNotification("Error", "Select group!", 3) return end S.currentGroup = S.selectedGroupName updateNotification("Active", "Using: " .. S.selectedGroupName, 3)
 elseif S.favGroupMode == "Use All Vendings" then S.currentGroup = "Default" S.selectedGroupName = "None" updateNotification("Active", "Using ALL vendings", 2)
 elseif S.favGroupMode == "Delete Group" then
  local groupToDelete = S.groupNameInput ~= "" and S.groupNameInput or S.selectedGroupName
  if groupToDelete == "None" or not S.vendingGroups[groupToDelete] then updateNotification("Error", "Select/enter group!", 3) return end
  confirm("Delete Group", "Permanently delete group '" .. groupToDelete .. "'?", function()
   S.vendingGroups[groupToDelete] = nil
   updateNotification("Deleted", "Deleted " .. groupToDelete, 3)
   local groupsData = {}
   for groupName, vendingList in pairs(S.vendingGroups) do if groupName ~= "Default" then groupsData[groupName] = vendingList end end
   writefile("VendingManager_Groups.json", HttpService:JSONEncode(groupsData))
   S.currentGroup = "Default"
  end, "Delete")
 end
end})

local CLICK_LOCK = false
Mouse.Button1Down:Connect(function()
 if CLICK_LOCK then return end
 CLICK_LOCK = true
 task.spawn(function()
  if not UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) and not UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
   CLICK_LOCK = false
   return
  end
  local target = Mouse.Target
  if not target then
   CLICK_LOCK = false
   return
  end
  local vending = nil
  local obj = target
  for i = 1, 15 do
   if not obj then break end
   if obj.Name:lower():find("vending") then
    vending = obj
   end
   obj = obj.Parent
  end
  if not vending then
   local cobj = target
   for i = 1, 8 do
    if not cobj then break end
    if cobj:IsA("BasePart") and cobj.Name:lower():find("chest") then
     PFX.toggleChest(cobj)
     task.wait(0.4)
     CLICK_LOCK = false
     return
    end
    cobj = cobj.Parent
   end
   CLICK_LOCK = false
   return
  end
  while vending.Parent and vending.Parent.Name:lower():find("vending") do
   vending = vending.Parent
  end
  local isSelected = false
  local selectedIndex = nil
  for i, v in ipairs(selectedFavorites) do
   if v == vending then
    isSelected = true
    selectedIndex = i
    break
   end
  end
  if isSelected then
   table.remove(selectedFavorites, selectedIndex)
   removeSelectionMarker(vending)
   updateNotification("Deselected", vending.Name, 1)
  else
   if #selectedFavorites >= MAX_SELECTIONS then
      updateNotification("Limit Reached!", "Maximum " .. MAX_SELECTIONS .. " selections. Clear some first!", 4)
      CLICK_LOCK = false
      return
   end
   table.insert(selectedFavorites, vending)
   addSelectionMarker(vending)
   updateNotification("Selected", vending.Name .. " (" .. #selectedFavorites .. "/" .. MAX_SELECTIONS .. ")", 1)
  end
  task.wait(0.5)
  CLICK_LOCK = false
 end)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
 if gameProcessed then return end
 if input.KeyCode == hotkeys.withdrawAll then
  local vendings = findVendings()
  if #vendings > 0 then
   for _, vending in ipairs(vendings) do
    task.spawn(function() withdrawFromVending(vending, 999999999) end)
   end
   updateNotification("Hotkey", "Withdrew from all!", 2)
  end
 elseif input.KeyCode == hotkeys.depositAll then
  local vendings = findVendings()
  if #vendings > 0 then
   for _, vending in ipairs(vendings) do
    task.spawn(function() depositCoinsToVending(vending, 10000000) end)
   end
   updateNotification("Hotkey", "Deposited to all!", 2)
  end
 elseif input.KeyCode == hotkeys.selectRandom then
  local vendings = findVendings()
  if #vendings > 0 then
   selectedVending = vendings[math.random(1, #vendings)]
   updateNotification("Hotkey", "Selected " .. selectedVending.Name, 2)
  end
 elseif input.KeyCode == hotkeys.emptyAll then
  local vendings = findVendings()
  if #vendings > 0 then
   for _, vending in ipairs(vendings) do
    task.spawn(function() emptyVending(vending) end)
   end
   updateNotification("Hotkey", "Emptying " .. #vendings, 2)
  end
 end
end)

L, R = ShopTab:AddLeft(), ShopTab:AddRight()

local Net

task.spawn(function()
 pcall(function()
 Net = RS:WaitForChild("rbxts_include", 10):WaitForChild("node_modules", 10):WaitForChild("@rbxts", 10):WaitForChild("net", 10):WaitForChild("out", 10):WaitForChild("_NetManaged", 10)
  if Net then
   local testRemote = Net:FindFirstChild("deGzdggahhjo/ggzImj")
   if testRemote then
    local islandCode = "Unknown"
    pcall(function()
     if LP:FindFirstChild("JoinCode") then
      islandCode = LP.JoinCode.Value
     end
    end)
    Duvome:MakeNotification({
     Name = "Welcome " .. LP.Name .. "!",
     Content = "Username: " .. LP.Name .. "\nDisplay: " .. LP.DisplayName .. "\nUser ID: " .. LP.UserId .. "\nAge: " .. LP.AccountAge .. " days\nIsland: " .. islandCode,
     Type = "success",
     Time = 8,
    })
   else
    Duvome:MakeNotification({Name = "Warning", Content = "Network ready but remotes not found", Type = "warning", Time = 3})
   end
  else
   Duvome:MakeNotification({Name = "Error", Content = "Network failed to initialize", Type = "error", Time = 5})
   end
 end)
end)

local function checkVendingNetwork()
 if not Net then
  updateNotification("Error", "Network not ready! Wait 2-3 seconds then try again.", 3)
  return false
 end
 return true
end

local function openVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local args = {HttpService:GenerateGUID(false), {{vendingMachine = vending}}}
  Net:WaitForChild("deGzdggahhjo/qkXeOxsmwiafothorpqogpS"):InvokeServer(unpack(args))
 end)
end

local function closeVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local args = {{vendingMachine = vending}}
  Net:WaitForChild("deGzdggahhjo/QaardducNrilqsmxdiotkewau"):FireServer(unpack(args))
 end)
end

local function startEditingVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local args = {HttpService:GenerateGUID(false), {{vendingMachine = vending}}}
  Net:WaitForChild("deGzdggahhjo/yceVHErjjNihyeXjwKeyzfnyrwmcnaWnCo"):FireServer(unpack(args))
 end)
end

local function stopEditingVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local args = {{vendingMachine = vending}}
  Net:WaitForChild("deGzdggahhjo/ifzkjsqjzFvJn"):FireServer(unpack(args))
 end)
end

local function depositCoinsToVending(vending, amount)
 if not checkVendingNetwork() then return end
 pcall(function()
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  local args = {HttpService:GenerateGUID(false), {{vendingMachine = vending, player_tracking_category = "join_from_web", amount = amount}}}
  Net:WaitForChild("deGzdggahhjo/ggzImj"):FireServer(unpack(args))
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function withdrawCoinsFromVending(vending, amount)
 if not checkVendingNetwork() then return end
 pcall(function()
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  local args = {HttpService:GenerateGUID(false), {{vendingMachine = vending, player_tracking_category = "join_from_web", amount = amount}}}
  Net:WaitForChild("deGzdggahhjo/ytaJiyomainKgxefgrkF"):FireServer(unpack(args))
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function setVendingMode(vending, mode, price)
 if not checkVendingNetwork() then return end
 pcall(function()
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  local args = {HttpService:GenerateGUID(false), {{mode = mode, vendingMachine = vending, player_tracking_category = "join_from_web", transactionPrice = price}}}
  Net:WaitForChild("deGzdggahhjo/rLPziSaNkyol"):FireServer(unpack(args))
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function depositItemToVending(vending, itemName, amount)
 if not checkVendingNetwork() then return end
 pcall(function()
  local tool = LP.Backpack:FindFirstChild(itemNameMap[itemName] or itemName)
  if not tool then return end
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  local args = {HttpService:GenerateGUID(false), {{player_tracking_category = "join_from_web", vendingMachine = vending, action = "deposit", tool = tool, amount = amount}}}
  Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq"):FireServer(unpack(args))
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function withdrawFromVending(vending, amount)
 if not checkVendingNetwork() then return end
 pcall(function()
  local sellingTool = nil
  if vending:FindFirstChild("SellingContents") and #vending.SellingContents:GetChildren() > 0 then
   sellingTool = vending.SellingContents:GetChildren()[1]
  end
  if not sellingTool then return end
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  local args = {HttpService:GenerateGUID(false), {{player_tracking_category = "join_from_web", vendingMachine = vending, action = "withdraw", tool = sellingTool, amount = amount}}}
  Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq"):FireServer(unpack(args))
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

local function emptyVending(vending)
 if not checkVendingNetwork() then return end
 pcall(function()
  local sellingTool = nil
  if vending:FindFirstChild("SellingContents") and #vending.SellingContents:GetChildren() > 0 then
   sellingTool = vending.SellingContents:GetChildren()[1]
  end
  if not sellingTool then return end
  openVending(vending)
  task.wait(0.1)
  startEditingVending(vending)
  task.wait(0.1)
  local args = {HttpService:GenerateGUID(false), {{player_tracking_category = "join_from_web", vendingMachine = vending, action = "withdraw", tool = sellingTool, amount = sellingTool.Amount.Value}}}
  Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq"):FireServer(unpack(args))
  task.wait(0.1)
  stopEditingVending(vending)
  task.wait(0.05)
  closeVending(vending)
 end)
end

-- ---------------------------------------------------------------------------
-- UNDO
--
-- Nothing here "reverses" an action. The server has no undo, so every entry is
-- a second, ordinary action that happens to be the inverse of the first, built
-- from state captured BEFORE the first one ran. Emptying a vending is undone by
-- depositing the same item and amount back into the same vending; demolishing a
-- block is undone by placing that block type at the CFrame it occupied.
--
-- That means three rules, and breaking any of them is what makes an undo lie:
--
--   1. Capture before, not after. Once a block is gone its Name and CFrame are
--      gone with it. Every record is taken while the target still exists.
--   2. Record the instance, not a description. A vending is stored as the
--      Instance, so if it has been destroyed since, we can tell, rather than
--      finding "some vending near there" and putting items in a stranger's.
--   3. Report what did not work. An undo can genuinely fail - the item was sold
--      meanwhile, the block is not in your inventory any more, someone built on
--      the spot. Every undo counts its failures and says so instead of claiming
--      success.
--
-- Actions that fire in a loop (demolish) collect into one entry for the whole
-- run rather than one entry per block, because "undo" means "put back what that
-- did", and what it did was a run.
-- ---------------------------------------------------------------------------
local Undo = {stack = {}, MAX = 25, listeners = {}}

function Undo.changed()
 for _, fn in ipairs(Undo.listeners) do pcall(fn) end
end

-- entry = {label, detail, run = function() return doneCount, failCount, note end}
function Undo.push(entry)
 entry.at = os.date("%H:%M:%S")
 table.insert(Undo.stack, 1, entry)
 while #Undo.stack > Undo.MAX do table.remove(Undo.stack) end
 Undo.changed()
 return entry
end

function Undo.run(entry)
 if not entry then return end
 if entry.running then return end
 entry.running = true
 task.spawn(function()
  local ok, done, failed, note = pcall(entry.run)
  entry.running = false
  if not ok then
   updateNotification("Undo Failed", tostring(done), 5)
   return
  end
  for i, e in ipairs(Undo.stack) do
   if e == entry then table.remove(Undo.stack, i) break end
  end
  Undo.changed()
  local msg = tostring(done or 0) .. " restored"
  if (failed or 0) > 0 then msg = msg .. ", " .. failed .. " could not be" end
  if note then msg = msg .. "\n" .. note end
  updateNotification((failed or 0) > 0 and "Undo Partial" or "Undone", msg, 5)
 end)
end

-- Offer the undo on the toast for the action itself, which is the moment the
-- user is actually looking at it.
function Undo.offer(title, content, entry)
 pcall(function()
  Duvome:MakeNotification({
   Name = title, Content = content, Type = "success", Time = 8,
   Actions = {{Text = "Undo", Callback = function() Undo.run(entry) end}},
  })
 end)
end

-- Vending Tools lives in a panel rather than a section on the tab: it is a set
-- of modes you switch on and then leave alone, so it does not need to sit in
-- the column taking up room the whole time.
local vendPanel = Duvome:MakeSidePanel({ Name = "Vending Tools", Width = 240, Height = 300, Side = "right" })
UI.vmSel = vendPanel

L:AddToggle({
 Name = "Vending Tools",
 Default = false,
 Tooltip = "Opens the vending tools: selection mode, drag-select and clearing selections.",
 Callback = function(value)
  pcall(function() if value then vendPanel:Show() else vendPanel:Hide() end end)
 end,
})

local useSelectedOnly = false

-- No keybind. This is a mode you set once and leave; a key for it only made the
-- row show a bind box it did not need.
UI.vmSel:AddToggle({Name = "Use Selected Only", Default = false, Tooltip = "ON = operate only on ALT+Click selected vendings. OFF = all vendings.", Flag = autoFlag("vend"), Callback = initGuard(function(value)
 useSelectedOnly = value
 if value then
  updateNotification("Mode", "Operations will apply to SELECTED vendings only", 3)
 else
  updateNotification("Mode", "Operations will apply to ALL vendings", 3)
 end
end)})

-- One drag-select for both, rather than a duplicate set of controls in the
-- chest section. Selecting things is the same job whatever is being selected.
-- On S rather than as file locals: this chunk is at Luau's 200-register limit.
S.dragTarget, S.dragSelectOn = "Vendings", false
UI.vmSel:AddDropdown({Name = "Drag Target", Options = {"Vendings", "Chests"}, Default = "Vendings", Flag = autoFlag("vend"), Tooltip = "What a drag-select box picks up.", Callback = function(value)
 S.dragTarget = value
 if S.dragSelectOn then
  PFX.setDragMode(value == "Chests" and "chest" or "vending")
 end
end})

UI.vmSel:AddToggle({Name = "Drag-Select", Default = false, Tooltip = "Hold Left-Click and drag a box over the Drag Target to select them all at once. ALT+Click still works any time for single select/deselect - no need to enable anything for that.", Flag = autoFlag("vend"), Callback = function(value)
 S.dragSelectOn = value
 if value then
  PFX.setDragMode(S.dragTarget == "Chests" and "chest" or "vending")
  updateNotification("Drag Select", "Left-click + drag a box over " .. S.dragTarget:lower(), 3)
 else
  PFX.setDragMode(nil)
  updateNotification("Drag Select", "Disabled", 2)
 end
end})

local function getTargetVendings()
 if useSelectedOnly then
  if #selectedFavorites == 0 then
   updateNotification("Error", "No vendings selected! Use ALT+Click to select", 3)
   return nil
  end
  return selectedFavorites
 else
  local vendings = findVendings()
  if #vendings == 0 then
   updateNotification("Error", "No vendings found!", 3)
   return nil
  end
  return vendings
 end
end

UI.vmSel:AddButton({Name = "Clear All", Tooltip = "Removes every current selection, vendings and chests both.", Callback = function()
 local nChest = 0
 pcall(function() nChest = #(PFX.selectedChests or {}) end)
 if #selectedFavorites == 0 and nChest == 0 then updateNotification("Selection", "Nothing selected", 2) return end
 confirm("Clear Selections", "Clear " .. #selectedFavorites .. " vending(s) and " .. nChest .. " chest(s)?", function()
  for _, vending in ipairs(selectedFavorites) do
   removeSelectionMarker(vending)
  end
  selectedFavorites = {}
  pcall(PFX.clearChests)
  updateNotification("Selection", "Cleared all selections", 2)
 end, "Clear")
end})

UI.vmBank = R:AddSection({Name = "Bank Operations", Collapsible = true, LayoutOrder = 1})

local bankAmount = 1000000

UI.vmBank:AddTextbox({Name = "Bank Amount", Default = "", TextDisappear = false, Callback = function(text)
 local num = parseAmount(text)
 if num then
  bankAmount = num
  updateNotification("Amount", "Set to " .. formatNumber(num), 2)
 else
  updateNotification("Error", "Invalid amount", 3)
 end
end})

local function bankTransfer(kind, amount)
 Net:WaitForChild("TransactionBankBalance"):FireServer(
  HttpService:GenerateGUID(false),
  {{accountType = "PERSONAL", transferType = kind, amount = amount}})
end

-- A bank transfer is the cleanest undo of the lot: the same amount the other
-- way, and nothing about the world in between can invalidate it except not
-- having the coins.
local function doBankTransfer(kind, label, backLabel)
 local amt = bankAmount
 pcall(function()
  bankTransfer(kind, amt)
  local undoEntry = Undo.push({
   label  = label .. " " .. formatNumber(amt),
   detail = backLabel .. " the same amount.",
   run = function()
    local ok = pcall(bankTransfer, kind == "DEPOSIT" and "WITHDRAWAL" or "DEPOSIT", amt)
    return ok and 1 or 0, ok and 0 or 1, (not ok) and "The bank refused the transfer." or nil
   end,
  })
  Undo.offer("Bank", label .. " " .. formatNumber(amt), undoEntry)
 end)
end

local function doBankDeposit()  doBankTransfer("DEPOSIT",   "Deposited", "Withdraws") end
local function doBankWithdraw() doBankTransfer("WITHDRAWAL", "Withdrew",  "Deposits") end

-- Loop instead of a keybind. Turn Loop on in the gear and the row becomes a
-- toggle that repeats on the interval; turn it off and it is a button again.
UI.vmBank:AddButton({Name = "Deposit", Loop = true, LoopEvery = 5, Tooltip = "Deposits the Bank Amount. Turn on Loop in the gear to repeat it.", Callback = doBankDeposit})
UI.vmBank:AddButton({Name = "Withdraw", Loop = true, LoopEvery = 5, Tooltip = "Withdraws the Bank Amount. Turn on Loop in the gear to repeat it.", Callback = doBankWithdraw})

-- What the Automation tab called "Bank to Vendings": withdraw from the bank,
-- then push it straight back out into the machines. It belongs here, under the
-- two halves it is made of, rather than on a tab of its own.

S.bankToVendingsOnce = function()
 if not checkNetwork() then return false, "no network" end
 -- GetBankAccount answers in one of several shapes depending on the build, so
 -- every one it has been seen to return is unwrapped rather than assuming.
 local bal
 pcall(function()
  local res = Net:WaitForChild("GetBankAccount"):InvokeServer(
   HttpService:GenerateGUID(false), {{accountType = "PERSONAL"}})
  if type(res) == "number" then bal = res
  elseif type(res) == "table" then
   bal = res.balance or res.Balance or res.amount or res.Amount or res.coins or res.Coins
   if type(bal) ~= "number" and type(res[1]) == "table" then
    bal = res[1].balance or res[1].Balance or res[1].amount or res[1].Amount
   end
  end
 end)
 if type(bal) ~= "number" then bal = nil end
 if bal and bal <= 0 then return false, "bank is empty" end

 local amount = S.b2vAmount
 if bal then amount = math.min(amount, bal) end
 if amount <= 0 then return false, "nothing to move" end

 pcall(function()
  Net:WaitForChild("TransactionBankBalance"):FireServer(HttpService:GenerateGUID(false),
   {{accountType = "PERSONAL", transferType = "WITHDRAWAL", amount = amount}})
 end)
 task.wait(0.5)

 local vendings = (S.b2vFavOnly and #selectedFavorites > 0) and selectedFavorites or findVendings()
 if #vendings == 0 then return false, "no vendings" end

 -- Each machine caps at 5b coins, so the run tracks how much room is actually
 -- left rather than firing the same amount at every one and letting the server
 -- reject the overflow.
 local VENDING_LIMIT = 5000000000
 local remaining, used = amount, 0
 for _, vending in ipairs(vendings) do
  if remaining <= 0 then break end
  local held = 0
  pcall(function()
   if vending:FindFirstChild("CoinBalance") then held = vending.CoinBalance.Value end
  end)
  local room = VENDING_LIMIT - held
  if room > 0 then
   local send = math.min(remaining, room)
   task.spawn(function() depositCoinsToVending(vending, send) end)
   remaining = remaining - send
   used = used + 1
   task.wait(0.1)
  end
 end
 return true, formatNumber(amount - remaining) .. " to " .. used .. " vendings"
end

S.setBankToVendings = function(on)
 S.b2vOn = on
 if not on then return end
 S.b2vGen = S.b2vGen + 1
 local gen = S.b2vGen
 task.spawn(function()
  while S.b2vOn and gen == S.b2vGen do
   local ok, msg = S.bankToVendingsOnce()
   updateNotification("Bank to Vendings", tostring(msg), ok and 3 or 4)
   if not ok and msg == "bank is empty" then
    S.b2vOn = false
    updateNotification("Bank to Vendings", "Bank empty - stopped", 4)
    return
   end
   local waited = 0
   while S.b2vOn and gen == S.b2vGen and waited < S.b2vEvery do
    task.wait(1)
    waited = waited + 1
   end
  end
 end)
end

UI.vmBank:AddToggle({Name = "Bank to Vendings Loop", Default = false,
 Tooltip = "Withdraws from the bank and deposits it across your vendings, on a timer. Stops itself when the bank runs dry.",
 Flag = autoFlag("vend"),
 Options = {
  {Type = "slider", Name = "Every", Min = 5, Max = 600, Increment = 5, Default = 30, ValueName = "s",
   Callback = function(v) S.b2vEvery = v end},
  {Type = "slider", Name = "Amount (millions)", Min = 1, Max = 1000, Increment = 1, Default = 1, ValueName = "M",
   Callback = function(v) S.b2vAmount = v * 1000000 end},
  {Type = "toggle", Name = "↪ Favourites Only", Default = false,
   Callback = function(v) S.b2vFavOnly = v end},
  {Type = "keybind", Name = "Bind Key", OnPress = function()
   task.spawn(function()
    local ok, msg = S.bankToVendingsOnce()
    updateNotification("Bank to Vendings", tostring(msg), ok and 3 or 4)
   end)
  end},
 },
 Callback = function(v) S.setBankToVendings(v) end})

local STOCK_TARGET = 1000

-- What the Mode value actually means, settled from getVendingHealth: mode 1 is
-- judged on whether its coins cover the price plus tax ("OUT OF MONEY"), so it
-- is the machine that PAYS - BUY ITEM. Mode 0 is judged on item count and on how
-- much coin room is left below 5b, so it is the machine that EARNS - SELL ITEM.
--
-- Every restriction below is gated on one of these, because the restrictions
-- only mean anything for one kind of machine: only a SELL ITEM machine can be
-- short of stock, and only a BUY ITEM machine can be short of money.
S.MODE_SELL, S.MODE_BUY, S.MODE_OFFLINE = 0, 1, 2

-- What one transaction costs the machine, tax included. floor(price * 1.07) + 1
-- reproduces both known readings: price 10 pays 11, price 100 pays 108. Plain
-- floor gives 10 for the first and plain ceil gives 107 for the second.
function S.unitCost(price)
 return math.floor((price or 0) * 1.07) + 1
end

S.VEND_MAX_ITEMS = 1000
S.VEND_MAX_COINS = 5000000000

-- The mode filters read the game's own wording now - a vending set to SELL ITEM
-- is listed as "Sell (SELL ITEM)" - but the numbers behind them are untouched,
-- so nothing about which vending is which has changed.
--
-- needsCoins and notFull used to share one "extra" flag, which meant a coin
-- filter and an item filter could not be told apart. They are separate, and both
-- are read off the vending's own numbers rather than off its mode, so they mean
-- the same thing the machine's screen means.
-- Modes and restrictions are two separate lists now, from two separate
-- dropdowns. They used to share one, which meant "Sell" and "Not Full Items"
-- read as alternatives when they are really a subject and a condition on it.
function S.parseModeSel(list)
 local modes, any = {}, false
 for _, m in ipairs(list or {}) do
  if m == "Sell (SELL ITEM)" then modes[S.MODE_SELL]    = true any = true
  elseif m == "Buy (BUY ITEM)" then modes[S.MODE_BUY]   = true any = true
  elseif m == "Offline"        then modes[S.MODE_OFFLINE] = true any = true end
 end
 return modes, any
end

function S.modeOf(vending)
 return vending:FindFirstChild("Mode") and vending.Mode.Value or nil
end

function S.stockCount(vending)
 local sc = vending:FindFirstChild("SellingContents")
 local n = 0
 if sc then
  for _, item in pairs(sc:GetChildren()) do
   if item:IsA("Tool") then n = n + (item:FindFirstChild("Amount") and item.Amount.Value or 1) end
  end
 end
 return n
end

function S.coinBalanceOf(vending)
 return vending:FindFirstChild("CoinBalance") and vending.CoinBalance.Value or 0
end

function S.priceOf(vending)
 return vending:FindFirstChild("TransactionPrice") and vending.TransactionPrice.Value or 0
end

-- Each restriction carries the mode it belongs to, so picking one narrows the
-- machines twice over: to that kind, and then to the ones in that state.
S.RESTRICTIONS = {
 ["Not Full Items (SELL ITEM)"] = {mode = 0, test = function(v)
  return S.stockCount(v) > 0 and S.stockCount(v) < S.VEND_MAX_ITEMS
 end},
 ["Leave 1 (BUY ITEM)"] = {mode = 1, test = function(v)
  return S.stockCount(v) > 1
 end},
 ["Not Enough Money (BUY ITEM)"] = {mode = 1, test = function(v)
  return S.coinBalanceOf(v) < S.unitCost(S.priceOf(v))
 end},
 ["Has Coins (SELL ITEM)"] = {mode = 0, test = function(v)
  return S.coinBalanceOf(v) > 0
 end},
}

-- A vending passes when its mode is wanted AND every chosen restriction that
-- applies to its mode is satisfied. A restriction for a different mode rules the
-- vending out rather than being ignored - that is what "only applies to SELL
-- ITEM" has to mean if it is going to skip the buy and offline ones.
function S.passes(vending, modeList, restrictList)
 local mv = S.modeOf(vending)
 local modes, anyMode = S.parseModeSel(modeList)
 if anyMode and not (mv ~= nil and modes[mv]) then return false, mv end
 for _, name in ipairs(restrictList or {}) do
  local r = S.RESTRICTIONS[name]
  if r then
   if mv ~= r.mode then return false, mv end
   if not r.test(vending) then return false, mv end
  end
 end
 return true, mv
end

local function stockedTool(vending)
 local sc = vending:FindFirstChild("SellingContents")
 local st = sc and sc:GetChildren()[1]
 if not st then return nil, 0 end
 return st, (st:FindFirstChild("Amount") and st.Amount.Value or 0)
end

UI.vmCoin = L:AddSection({Name = "Coin Operations", Collapsible = true, LayoutOrder = 1})

-- Run Coins and Run Items came off the Automation tab. They are the one-press
-- versions of what the rest of these two sections does by hand, so they sit at
-- the top of the section they summarise. The implementations are still defined
-- further down where their helpers live; these are forward bindings, filled in
-- when that code runs. Before then the button says so rather than doing
-- nothing quietly.
UI.vmCoin:AddButton({
 Name = "Run Coins", Loop = true, LoopEvery = 30,
 Tooltip = "Funds every BUY ITEM machine that is short and empties the coins out of every SELL ITEM machine holding any. Works at any distance - stand anywhere.",
 Callback = function()
  if UI.runCoinsImpl then UI.runCoinsImpl()
  else updateNotification("Run Coins", "Not ready yet - reopen the hub", 3) end
 end,
})

-- 0 means "work it out per machine". A fixed 10m was a number that suited no
-- particular vending.
local coinAmount = 0

UI.vmCoin:AddTextbox({Name = "Coin Amount", Default = "", TextDisappear = false,
 Tooltip = "Leave empty to give each BUY ITEM machine exactly what it needs to reach 1000 items. Set a number to send that flat amount instead.",
 Validate = function(text)
  if text == "" then return true end
  local n = parseAmount(text)
  if not n then return false, "Numbers only, e.g. 500k or 2b" end
  if n < 0 then return false, "Cannot be negative" end
  if n > 5000000000 then return false, "5b is the most a vending holds" end
  return true
 end,
 Callback = function(text)
  if text == "" then
   coinAmount = 0
   updateNotification("Coin Amount", "Working it out per vending", 2)
   return
  end
  local num = parseAmount(text)
  if num then
   coinAmount = num
   updateNotification("Coin Amount", "Flat " .. formatNumber(num) .. " per vending", 2)
  end
 end})

-- Two dropdowns: what kind of machine, then what state it has to be in. Clear
-- All on the second one is how you say "no restriction".
S.coinModes, S.coinRestrict = {}, {}
UI.vmCoin:AddDropdown({Name = "Vending Type", Options = {"Buy (BUY ITEM)", "Sell (SELL ITEM)", "Offline"}, Default = {}, MultiSelect = true, SelectAll = true, Tooltip = "Which machines Deposit and Withdraw act on. Nothing picked means all of them.", Flag = autoFlag("vend"), Callback = function(chosen)
 S.coinModes = chosen or {}
end})
UI.vmCoin:AddDropdown({Name = "Restriction", Options = {"Not Enough Money (BUY ITEM)", "Has Coins (SELL ITEM)"}, Default = {}, MultiSelect = true, SelectAll = true, Tooltip = "Narrows to machines in a particular state. Each one only applies to the kind of machine named on it, so picking it skips the others. Clear All for no restriction.", Flag = autoFlag("vend"), Callback = function(chosen)
 S.coinRestrict = chosen or {}
end})

function S.coinTargets(vendings)
 local list = {}
 for _, vending in ipairs(vendings) do
  if S.passes(vending, S.coinModes, S.coinRestrict) then table.insert(list, vending) end
 end
 return list
end

-- With Coin Amount left empty, each BUY ITEM machine gets exactly what it needs
-- to buy its way to a full 1000: the room it has left, times the price plus the
-- 7% tax, less whatever it is already holding. A machine at 1000 is skipped
-- rather than topped up, and nothing exceeds the 5b ceiling.
UI.vmCoin:AddButton({Name = "Deposit", Loop = true, LoopEvery = 5, Tooltip = "Leave Coin Amount empty and each BUY ITEM machine gets exactly enough to buy up to 1000 - room x (price + 7% tax), minus what it already holds. Set an amount to send that flat figure instead.", Callback = function()
 local vendings = getTargetVendings()
 if not vendings then return end
 local list = S.coinTargets(vendings)

 local funded, skipped, capped, total = 0, 0, 0, 0
 local sent = {}
 for _, vending in ipairs(list) do
  local give = coinAmount
  if not give or give <= 0 then
   local room = S.VEND_MAX_ITEMS - S.stockCount(vending)
   if room <= 0 then
    give = 0
   else
    -- Never below zero: a machine already holding more than it needs subtracts
    -- to a negative figure, and sending that is not a smaller deposit, it is a
    -- nonsense one.
    give = math.max(0, room * S.unitCost(S.priceOf(vending)) - S.coinBalanceOf(vending))
   end
   local headroom = math.max(0, S.VEND_MAX_COINS - S.coinBalanceOf(vending))
   if give > headroom then give = headroom capped = capped + 1 end
  end
  if give and give > 0 then
   funded = funded + 1
   total = total + give
   -- per machine, since each one is worked out from its own price and stock
   table.insert(sent, {v = vending, amount = give})
   task.spawn(function() depositCoinsToVending(vending, give) end)
  else
   skipped = skipped + 1
  end
 end
 if #sent == 0 then
  updateNotification("Nothing To Deposit",
   #list .. " matching vending(s), none needing coins", 4)
  return
 end

 local target = useSelectedOnly and "selected" or "all"
 local undoEntry = Undo.push({
  label  = "Deposited " .. formatNumber(total) .. " to " .. #sent .. " vendings",
  detail = "Takes each machine's own amount back out of it.",
  run = function()
   local done, failed = 0, 0
   for _, t in ipairs(sent) do
    if t.v and t.v.Parent then
     withdrawCoinsFromVending(t.v, t.amount)
     done = done + 1
     task.wait(0.05)
    else
     failed = failed + 1
    end
   end
   return done, failed, failed > 0 and "Some vendings no longer exist." or nil
  end,
 })
 local msg = "Into " .. #sent .. " " .. target .. " vendings"
 if skipped > 0 then msg = msg .. "\n" .. skipped .. " skipped: already full, or needing nothing" end
 if capped > 0 then msg = msg .. "\n" .. capped .. " capped at the 5b ceiling" end
 Undo.offer("Deposited " .. formatNumber(total), msg, undoEntry)
end})

-- Coin Amount empty means "take everything", not "take nothing". It used to
-- pass the box straight through, and once the box started defaulting to 0 for
-- the deposit side, Withdraw quietly asked every machine for zero coins.
UI.vmCoin:AddButton({Name = "Withdraw", Loop = true, LoopEvery = 5, Tooltip = "Takes the Coin Amount out of each matching machine. Leave Coin Amount empty to take everything it holds.", Callback = function()
 local vendings = getTargetVendings()
 if not vendings then return end
 local list = S.coinTargets(vendings)

 -- Recorded per machine, because the amounts differ once the box is empty.
 -- One shared figure would have made the undo put the wrong number back.
 local taken, total, skipped = {}, 0, 0
 for _, vending in ipairs(list) do
  local held = S.coinBalanceOf(vending)
  local give = (coinAmount and coinAmount > 0) and math.min(coinAmount, held) or held
  if give > 0 then
   table.insert(taken, {v = vending, amount = give})
   total = total + give
   task.spawn(function() withdrawCoinsFromVending(vending, give) end)
  else
   skipped = skipped + 1
  end
 end

 if #taken == 0 then
  updateNotification("Nothing To Withdraw",
   skipped .. " matching vending(s), none holding coins", 4)
  return
 end

 local target = useSelectedOnly and "selected" or "all"
 local undoEntry = Undo.push({
  label  = "Withdrew " .. formatNumber(total) .. " from " .. #taken .. " vendings",
  detail = "Puts each machine's own amount back into it.",
  run = function()
   local done, failed = 0, 0
   for _, t in ipairs(taken) do
    if t.v and t.v.Parent then
     depositCoinsToVending(t.v, t.amount)
     done = done + 1
     task.wait(0.05)
    else
     failed = failed + 1
    end
   end
   return done, failed, failed > 0 and "Some vendings no longer exist." or nil
  end,
 })
 local msg = "From " .. #taken .. " " .. target .. " vendings"
 if skipped > 0 then msg = msg .. "\n" .. skipped .. " skipped: holding nothing" end
 Undo.offer("Withdrew " .. formatNumber(total), msg, undoEntry)
end})

UI.vmItem = R:AddSection({Name = "Item Management", Collapsible = true, LayoutOrder = 2})

UI.itemRunToggle = UI.vmItem:AddToggle({
 Name = "Run Items (flies)", Default = false,
 Tooltip = "Flies over the vendings that need something. SELL ITEM machines under 1000 get topped up from your inventory; BUY ITEM machines holding more than one get drained down to 1. Speed and reach are in the gear.",
 Options = {
  {Type = "slider", Name = "Fly Speed", Min = 10, Max = 40, Default = 30, ValueName = " st/s",
   Callback = function(v) S.itemRunSpeed = v end},
  {Type = "slider", Name = "Reach", Min = 5, Max = 33, Default = 33, ValueName = " st",
   Callback = function(v) S.ITEM_REACH = v end},
  {Type = "slider", Name = "Hover Height", Min = 0, Max = 30, Default = 8, ValueName = " st",
   Callback = function(v) S.itemRunHover = v end},
 },
 Callback = function(value)
  if UI.runItemsImpl then UI.runItemsImpl(value)
  else updateNotification("Run Items", "Not ready yet - reopen the hub", 3) end
 end,
})

local itemOptions = {}
local function refreshItems()
 table.clear(itemOptions)
 itemNameMap = {}
 local backpack = LP:WaitForChild("Backpack")
 for _, item in pairs(backpack:GetChildren()) do
  if item:IsA("Tool") then
   local displayName = getDisplayName(item)
   itemNameMap[displayName] = item.Name
   table.insert(itemOptions, displayName)
  end
 end
 table.sort(itemOptions)
 if #itemOptions == 0 then table.insert(itemOptions, "No items") end
 return itemOptions
end
refreshItems()

-- Only consulted for machines holding nothing; a stocked machine names its own
-- item.
UI.itemDropdown = UI.vmItem:AddDropdown({Name = "Item", Options = itemOptions, OnRefresh = refreshItems, Default = itemOptions[1], Search = true, Tooltip = "Which item to seed a vending that is holding nothing. Machines that already have stock get more of what they hold.", Flag = autoFlag("vend"), Callback = initGuard(function(value)
 selectedItemName = value
end)})

-- 0, not 1. It is a cap, and the default has to mean "no cap" - at 1 an
-- untouched Amount box would have sent exactly one item to every vending.
local itemAmount = 0

UI.vmItem:AddTextbox({Name = "Amount", Default = "", TextDisappear = false,
 Tooltip = "A cap per vending. Leave empty to fill each one to 1000 with whatever you have.",
 Validate = function(text)
  if text == "" then return true end
  local n = parseAmount(text)
  if not n then return false, "Numbers only, e.g. 250 or 2k" end
  if n < 0 then return false, "Cannot be negative" end
  return true
 end,
 Callback = function(text)
  if text == "" then
   itemAmount = 0
   updateNotification("Amount", "No cap - filling to 1000", 2)
   return
  end
  local num = parseAmount(text)
  if num then
   itemAmount = num
   updateNotification("Amount", "Cap set to " .. formatNumber(num) .. " per vending", 2)
  end
 end})

S.itemModes, S.itemRestrict = {}, {}
UI.vmItem:AddDropdown({Name = "Vending Type", Options = {"Buy (BUY ITEM)", "Sell (SELL ITEM)", "Offline"}, Default = {}, MultiSelect = true, SelectAll = true, Tooltip = "Which machines Deposit, Restock and Empty act on. Nothing picked means all of them.", Flag = autoFlag("vend"), Callback = function(chosen)
 S.itemModes = chosen or {}
end})
UI.vmItem:AddDropdown({Name = "Restriction", Options = {"Not Full Items (SELL ITEM)", "Leave 1 (BUY ITEM)"}, Default = {}, MultiSelect = true, SelectAll = true, Tooltip = "Narrows to machines in a particular state, and only to the kind named on it. 'Not Full Items' is SELL ITEM machines holding something under 1000. 'Leave 1' is BUY ITEM machines holding more than one - Empty then drains them down to 1 instead of to nothing. Clear All for no restriction.", Flag = autoFlag("vend"), Callback = function(chosen)
 S.itemRestrict = chosen or {}
end})

local function itemTargets(vendings)
 local list = {}
 for _, vending in ipairs(vendings) do
  local ok, mv = S.passes(vending, S.itemModes, S.itemRestrict)
  if ok then table.insert(list, {v = vending, mode = mv}) end
 end
 return list
end

local function leaveOneChosen()
 for _, name in ipairs(S.itemRestrict or {}) do
  if name == "Leave 1 (BUY ITEM)" then return true end
 end
 return false
end

-- Deposit works off whatever each vending already holds, not off the Item
-- dropdown. A machine with 7 glass in it wants glass, and asking which item to
-- send was asking a question the machine had already answered. It sends as much
-- as fits or as much as you have, whichever is less, so a partial top-up still
-- happens when you are short.
--
-- The Item dropdown is the fallback for a machine holding nothing, because an
-- empty one really does need telling.
local function doDepositItem()
 local vendings = getTargetVendings()
 if not vendings then return end
 local list = itemTargets(vendings)

 local sent, short, skipped = 0, 0, 0
 task.spawn(function()
  for _, entry in ipairs(list) do
   local vending = entry.v
   local st, cur = stockedTool(vending)
   local wantName = st and st.Name or itemNameMap[selectedItemName] or selectedItemName
   if not wantName or wantName == "No items" then
    skipped = skipped + 1
   else
    local btool = LP.Backpack:FindFirstChild(wantName)
    local have  = btool and (btool:FindFirstChild("Amount") and btool.Amount.Value or 1) or 0
    local room  = STOCK_TARGET - (cur or 0)
    -- the Amount box is a cap when set, not a demand
    local want  = (itemAmount and itemAmount > 0) and itemAmount or room
    local give  = math.min(room, have, want)
    if have <= 0 then
     skipped = skipped + 1
    else
     if give < math.min(room, want) then short = short + 1 end
     if give > 0 then
      sent = sent + 1
      -- Run Simultaneously means what it says here too. Emptying already fired
      -- every vending at once while this walked them one at a time, which is
      -- the difference people were noticing.
      if allAtOnceMode then
       task.spawn(function() depositItemToVending(vending, wantName, give) end)
      else
       depositItemToVending(vending, wantName, give)
       task.wait(0.05)
      end
     else
      skipped = skipped + 1
     end
    end
   end
  end
  local msg = "Deposited into " .. sent .. " of " .. #list .. " vendings"
  if short > 0 then msg = msg .. "\n" .. short .. " got less than a full top-up - you ran short" end
  if skipped > 0 then msg = msg .. "\n" .. skipped .. " skipped: nothing of theirs in your inventory" end
  updateNotification(sent > 0 and "Deposited" or "Nothing Deposited", msg, 5)
 end)
end

-- Split mode divides what you are holding evenly across the machines that need
-- it, instead of pouring the whole stack into the first one and leaving the
-- rest empty. Declared up here because doRestockVending reads it.

local function doRestockVending()
 local vendings = getTargetVendings()
 if not vendings then return end
 local list = itemTargets(vendings)
 task.spawn(function()
  local filled, pulled, skipped = 0, 0, 0
  local sellCount = 0
  for _, entry in ipairs(list) do
   if entry.mode == S.MODE_SELL then sellCount = sellCount + 1 end
  end
  sellCount = math.max(sellCount, 1)
  -- One vending's restock is a sequence of open/edit/act/close with waits in
  -- it, so under Run Simultaneously each vending gets its own thread and they
  -- overlap, rather than the whole list being walked end to end.
  local pending = 0
  for _, entry in ipairs(list) do
   local vending, mv = entry.v, entry.mode
   local function work()
    local st, cur = stockedTool(vending)
    if not st then skipped = skipped + 1 return end
    -- Mode 0 is SELL ITEM: it hands stock to customers, so it is the one that
    -- wants topping up. Mode 1 is BUY ITEM: it collects stock from customers,
    -- so it is the one that wants draining. These two branches were the wrong
    -- way round - restock was filling the machines that fill themselves and
    -- emptying the ones that run dry.
    if mv == S.MODE_SELL then
     if cur >= STOCK_TARGET then skipped = skipped + 1 return end
     local btool = LP.Backpack:FindFirstChild(st.Name)
     if not btool then skipped = skipped + 1 return end
     local have = btool:FindFirstChild("Amount") and btool.Amount.Value or 1
     local budget = S.restockSplit and math.floor(have / sellCount) or have
     local give = math.min(STOCK_TARGET - cur, budget)
     if give <= 0 then skipped = skipped + 1 return end
     openVending(vending)
     task.wait(0.1)
     startEditingVending(vending)
     task.wait(0.1)
     Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq"):FireServer(HttpService:GenerateGUID(false), {{player_tracking_category = "join_from_web", vendingMachine = vending, action = "deposit", tool = btool, amount = give}})
     task.wait(0.1)
     stopEditingVending(vending)
     task.wait(0.05)
     closeVending(vending)
     filled = filled + 1
    elseif mv == S.MODE_BUY then
     local take = cur - 1
     if take <= 0 then skipped = skipped + 1 return end
     openVending(vending)
     task.wait(0.1)
     startEditingVending(vending)
     task.wait(0.1)
     Net:WaitForChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq"):FireServer(HttpService:GenerateGUID(false), {{player_tracking_category = "join_from_web", vendingMachine = vending, action = "withdraw", tool = st, amount = take}})
     task.wait(0.1)
     stopEditingVending(vending)
     task.wait(0.05)
     closeVending(vending)
     pulled = pulled + 1
    else
     skipped = skipped + 1
    end
   end
   if allAtOnceMode then
    pending = pending + 1
    task.spawn(function()
     if not pcall(work) then skipped = skipped + 1 end
     pending = pending - 1
    end)
   else
    if not pcall(work) then skipped = skipped + 1 end
    task.wait(0.05)
   end
  end
  -- wait for the overlapped threads before reporting, or the numbers are read
  -- before the work has happened
  while pending > 0 do task.wait(0.1) end
  updateNotification("Restock", "Filled " .. filled .. " sell | pulled " .. pulled .. " buy | " .. skipped .. " skipped", 4)
 end)
end

UI.vmItem:AddButton({Name = "Deposit", Options = {{Type = "keybind", Name = "Bind Key", OnPress = doDepositItem}}, Callback = doDepositItem})
-- Restock absorbs what the Automation tab called Auto-Restock and Vending Auto
-- Stocker. Both were the same button on a timer with one extra choice each, so
-- they are the timer and those choices, on the button itself.

S.restockCycle = function()
 -- Random item picks a fresh item from your backpack each pass. Without it the
 -- loop keeps sending whatever the Item dropdown holds, which empties one stack
 -- and then does nothing for the rest of the night.
 if S.restockRandomItem then
  refreshItems()
  if #itemOptions > 0 and itemOptions[1] ~= "No items" then
   local pick = itemOptions[math.random(1, #itemOptions)]
   selectedItemName = pick
   pcall(function() UI.itemDropdown:Set(pick) end)
  end
 end
 doRestockVending()
end

S.setRestockLoop = function(on)
 S.restockLoopOn = on
 if not on then return end
 S.restockGen = S.restockGen + 1
 local gen = S.restockGen
 task.spawn(function()
  local since = 0
  while S.restockLoopOn and gen == S.restockGen do
   S.restockCycle()
   -- Two independent clocks: the restock interval, and an optional slower one
   -- that only rerolls the item. Rerolling every pass is a different feature
   -- from restocking every pass, and tying them together was why the old Auto
   -- Stocker could not do one without the other.
   local waited = 0
   while S.restockLoopOn and gen == S.restockGen and waited < S.restockEvery do
    task.wait(1)
    waited = waited + 1
    since = since + 1
    if S.restockRandomEvery > 0 and since >= S.restockRandomEvery then
     since = 0
     refreshItems()
     if #itemOptions > 0 and itemOptions[1] ~= "No items" then
      selectedItemName = itemOptions[math.random(1, #itemOptions)]
      pcall(function() UI.itemDropdown:Set(selectedItemName) end)
     end
    end
   end
  end
 end)
end

UI.vmItem:AddButton({Name = "Restock",
 Tooltip = "Acts by vending mode: SELL ITEM machines get topped up to 1000 from your inventory. BUY ITEM machines get their collected stock pulled out, leaving exactly 1 behind. Use Vending Type above to pick which ones.",
 Options = {
  {Type = "keybind", Name = "Bind Key", OnPress = doRestockVending},
  {Type = "toggle", Name = "Loop", Default = false,
   Callback = function(v) S.setRestockLoop(v) end},
  {Type = "slider", Name = "Loop Every", Min = 1, Max = 300, Increment = 1, Default = 15, ValueName = "s",
   Callback = function(v) S.restockEvery = v end},
  {Type = "toggle", Name = "↪ Random Item", Default = false,
   Callback = function(v) S.restockRandomItem = v end},
  {Type = "slider", Name = "↪ Reroll Every", Min = 0, Max = 600, Increment = 5, Default = 0, ValueName = "s",
   Callback = function(v) S.restockRandomEvery = v end},
  -- A toggle, not a dropdown: DL's gear renders sliders, keybinds and toggles,
  -- and Deposit All vs Split is a two-state choice anyway.
  {Type = "toggle", Name = "↪ Split Across Vendings", Default = false,
   Callback = function(v) S.restockSplit = v end},
 },
 Callback = doRestockVending})

UI.vmItem:AddButton({Name = "Empty", Loop = true, LoopEvery = 5, Tooltip = "Withdraws every item from the matching machines. Pick Leave 1 (BUY ITEM) as the Restriction to drain them down to one instead of to nothing.", Callback = function()
 local vendings = getTargetVendings()
 if not vendings then return end
 local list = itemTargets(vendings)
 local keepOne = leaveOneChosen()
 confirm("Empty Vendings",
  (keepOne and "Drain down to 1 in " or "Withdraw all items from ") .. #list .. " vending(s)?", function()
  -- Read what is in each one BEFORE emptying it. Afterwards SellingContents is
  -- bare and there is nothing left to learn from.
  local record = {}
  for _, entry in ipairs(list) do
   local v = entry.v
   local sc = v:FindFirstChild("SellingContents")
   local tool = sc and sc:GetChildren()[1]
   if tool then
    local amt = tool:FindFirstChild("Amount") and tool.Amount.Value or 1
    table.insert(record, {v = v, item = tool.Name, amount = amt})
   end
  end
  for _, entry in ipairs(list) do
   task.spawn(function()
    if keepOne then
     -- one stays behind as the template, so the machine keeps buying that item
     local st, cur = stockedTool(entry.v)
     if st and cur > 1 then withdrawFromVending(entry.v, cur - 1) end
    else
     emptyVending(entry.v)
    end
   end)
  end
  local target = useSelectedOnly and "selected" or "all"
  local undoEntry = Undo.push({
   label  = "Emptied " .. #record .. " vendings",
   detail = "Puts each item and amount back into the vending it came from.",
   run = function()
    local done, failed = 0, 0
    for _, r in ipairs(record) do
     if not r.v or not r.v.Parent then
      failed = failed + 1
     else
      local held = LP.Backpack:FindFirstChild(r.item)
      local have = held and (held:FindFirstChild("Amount") and held.Amount.Value or 1) or 0
      if have <= 0 then
       failed = failed + 1
      else
       depositItemToVending(r.v, r.item, math.min(r.amount, have))
       done = done + 1
       task.wait(0.05)
      end
     end
    end
    return done, failed, failed > 0 and "Missing vendings, or the items are no longer in your inventory." or nil
   end,
  })
  Undo.offer("Emptied " .. #list .. " " .. target .. " vendings",
   "Deposits each item back into the vending it came from.", undoEntry)
 end, "Empty")
end})

UI.vmCfg = L:AddSection({Name = "Vending Configuration", Collapsible = true, LayoutOrder = 2})

local vendingMode = "Sell (SELL ITEM)"
local vendingPrice = 100
local applyTarget = "Mode + Price"

-- Labelled the way the machine's own screen labels them, so picking a mode here
-- and reading it off the vending are the same words. The values behind them are
-- unchanged.
UI.vmCfg:AddDropdown({Name = "Vending Mode", Options = {"Buy (BUY ITEM)", "Sell (SELL ITEM)", "Offline"}, Default = "Sell (SELL ITEM)", Flag = autoFlag("vend"), Callback = function(value)
 vendingMode = value
end})

UI.vmCfg:AddTextbox({Name = "Price", Default = "", TextDisappear = false, Callback = function(text)
 local num = parseAmount(text)
 if num then
  vendingPrice = num
  updateNotification("Price", "Set to " .. formatNumber(num), 2)
 end
end})

UI.vmCfg:AddDropdown({Name = "Apply To", Options = {"Mode + Price", "Mode Only", "Price Only"}, Default = "Mode + Price", Flag = autoFlag("vend"), Callback = function(value)
 applyTarget = value
end})

UI.vmCfg:AddButton({Name = "Apply", Callback = function()
 local vendings = getTargetVendings()
 if not vendings then return end
 local modeNum = vendingMode:find("BUY") and 1 or (vendingMode:find("SELL") and 0 or 2)
 -- Snapshot each vending's mode and price first. This is the one action here
 -- whose inverse is not a mirror of itself - it is "set it back to what it
 -- was", which is only knowable beforehand.
 local before = {}
 for _, vending in ipairs(vendings) do
  table.insert(before, {
   v     = vending,
   mode  = vending:FindFirstChild("Mode") and vending.Mode.Value or modeNum,
   price = vending:FindFirstChild("TransactionPrice") and vending.TransactionPrice.Value or vendingPrice,
  })
 end
 for _, vending in ipairs(vendings) do
  task.spawn(function()
   if applyTarget == "Mode Only" then

    local curPrice = vending:FindFirstChild("TransactionPrice") and vending.TransactionPrice.Value or vendingPrice
    setVendingMode(vending, modeNum, curPrice)
   elseif applyTarget == "Price Only" then

    local curMode = vending:FindFirstChild("Mode") and vending.Mode.Value or modeNum
    setVendingMode(vending, curMode, vendingPrice)
   else
    setVendingMode(vending, modeNum, vendingPrice)
   end
  end)
 end
 local target = useSelectedOnly and "selected" or "all"
 local what
 if applyTarget == "Mode Only" then
  what = vendingMode .. " mode"
 elseif applyTarget == "Price Only" then
  what = "price " .. formatNumber(vendingPrice)
 else
  what = vendingMode .. " mode @ " .. formatNumber(vendingPrice)
 end
 local undoEntry = Undo.push({
  label  = "Applied " .. what .. " to " .. #vendings .. " vendings",
  detail = "Restores each vending's previous mode and price.",
  run = function()
   local done, failed = 0, 0
   for _, b in ipairs(before) do
    if b.v and b.v.Parent then
     setVendingMode(b.v, b.mode, b.price)
     done = done + 1
     task.wait(0.05)
    else
     failed = failed + 1
    end
   end
   return done, failed, failed > 0 and "Some vendings no longer exist." or nil
  end,
 })
 Undo.offer("Applied " .. what .. " to " .. #vendings .. " " .. target .. " vendings",
  "Restores each vending's previous mode and price.", undoEntry)
end})

local function BuildBypass()
 local maintenanceOn, inUseOn = false, false
 local watched = {}
 local scanThread = 0

 local function allVendings()
  local out = {}
  local islands = WS:FindFirstChild("Islands")
  if islands then
   for _, island in pairs(islands:GetChildren()) do
    local blocks = island:FindFirstChild("Blocks")
    if blocks then
     for _, obj in pairs(blocks:GetChildren()) do
      if obj.Name:find("vending") or obj.Name:find("Vending") then table.insert(out, obj) end
     end
    end
   end
  end
  return out
 end

 local function release(vm)
  local conns = watched[vm]
  if not conns then return end
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  watched[vm] = nil
 end

 local function releaseAll()
  for vm in pairs(watched) do release(vm) end
  watched = {}
 end

 local function hook(vm)
  if not (vm and vm.Parent) or watched[vm] then return end
  local conns = {}
  if maintenanceOn then
   local m = vm:FindFirstChild("Maintenance")
   if m and m:IsA("BoolValue") then
    if m.Value then m.Value = false end
    table.insert(conns, m.Changed:Connect(function()
     if maintenanceOn and m.Value then m.Value = false end
    end))
   end
  end
  if inUseOn then
   local ue = vm:FindFirstChild("UserEditing")
   if ue and ue:IsA("ObjectValue") then
    if ue.Value ~= nil then ue.Value = nil end
    table.insert(conns, ue.Changed:Connect(function()
     if inUseOn and ue.Value ~= nil then ue.Value = nil end
    end))
   end
  end
  if #conns > 0 then watched[vm] = conns end
 end

 local function refresh()
  releaseAll()
  if not (maintenanceOn or inUseOn) then return end
  scanThread = scanThread + 1
  local myScan = scanThread
  task.spawn(function()
   while (maintenanceOn or inUseOn) and myScan == scanThread do
    pcall(function()
     for vm in pairs(watched) do
      if not vm.Parent then release(vm) end
     end
     for _, vm in ipairs(allVendings()) do hook(vm) end
    end)
    task.wait(3)
   end
   releaseAll()
  end)
 end

 return {
  setMaintenance = function(v) maintenanceOn = v refresh() updateNotification("Bypass", "Maintenance " .. (v and "ON" or "OFF"), 2) end,
  setInUse = function(v) inUseOn = v refresh() updateNotification("Bypass", "In-Use " .. (v and "ON" or "OFF"), 2) end,
 }
end
local Bypass = BuildBypass()

UI.vmSnipe = R:AddSection({Name = "Vending Sniper", Collapsible = true, LayoutOrder = 3})

local sniperEnabled = false
local maxPrice = 1000000
local sniperSpeed = 0.1
local buyAmount = 999999

local function BuildSniper(sec)
 local sniperItems = {}
 local sniperMap = {}
 local buyAny = false
 local sniperGen = 0

 local function scanSniperItems()
  table.clear(sniperMap)
  local opts, seen = {}, {}
  for _, v in ipairs(findVendings()) do
   local sc = v:FindFirstChild("SellingContents")
   if sc then
    for _, it in pairs(sc:GetChildren()) do
     local d = getDisplayName(it)
     if d and not seen[d] then
      seen[d] = true
      sniperMap[d] = it.Name
      table.insert(opts, d)
     end
    end
   end
  end
  table.sort(opts)
  if #opts == 0 then table.insert(opts, "No items") end
  return opts
 end

 UI.sniperDrop = sec:AddDropdown({Name = "Item", Options = (function() local t = {"Buy Any Item"} for _, v in ipairs(scanSniperItems()) do table.insert(t, v) end return t end)(), OnRefresh = function() local t = {"Buy Any Item"} for _, v in ipairs(scanSniperItems()) do table.insert(t, v) end return t end, Default = {}, MultiSelect = true, Search = true, SelectAll = true, Tooltip = "Pick items to snipe, or pick 'Buy Any Item' to buy anything under your max price.", Flag = autoFlag("vend"), Callback = function(chosen)
  table.clear(sniperItems)
  buyAny = false
  for _, d in ipairs(chosen or {}) do
   if d == "Buy Any Item" then buyAny = true else table.insert(sniperItems, sniperMap[d] or d) end
  end
 end})

 sec:AddTextbox({Name = "Maximum Price", Default = "", TextDisappear = false, Callback = function(text)
  local num = parseAmount(text)
  if num then
   maxPrice = num
   updateNotification("Sniper", "Max price: " .. formatNumber(num), 2)
  end
 end})

 sec:AddTextbox({Name = "Max Quantity", Default = "", TextDisappear = false, Callback = function(text)
  local num = parseAmount(text)
  if num then
   buyAmount = num
   updateNotification("Sniper", "Will buy up to: " .. formatNumber(num), 2)
  end
 end})

 sec:AddToggle({Name = "Snipe", Default = false, Tooltip = "Scans sell vendings cheapest-first and buys the items you picked. Speed and bypasses are in the gear.", Flag = autoFlag("vend"), Options = {
  {Type = "slider", Name = "Sniper Speed", Min = 0.01, Max = 5, Default = 0.1, Callback = function(v) sniperSpeed = v end},
  {Type = "toggle", Name = "Bypass Maintenance", Default = false, Callback = function(v) Bypass.setMaintenance(v) end},
  {Type = "toggle", Name = "Bypass In-Use", Default = false, Callback = function(v) Bypass.setInUse(v) end},
 }, Callback = function(value)
  sniperEnabled = value
  if not value then
   updateNotification("Vending Sniper", "Stopped Auto Vending Snipe", 2)
   return
  end
  updateNotification("Vending Sniper", "Started Auto Vending Snipe", 2)
  sniperGen = sniperGen + 1
  local myGen = sniperGen
  task.spawn(function()
   local snipeNet = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
   local openRemote = snipeNet:WaitForChild("deGzdggahhjo/qkXeOxsmwiafothorpqogpS")
   local buyRemote = snipeNet:WaitForChild("deGzdggahhjo/dfiQxh")
   local stopRemote = snipeNet:FindFirstChild("deGzdggahhjo/ifzkjsqjzFvJn")
   while sniperEnabled and myGen == sniperGen do
    local coins = tonumber(LP:GetAttribute("Coins")) or 0
    local valid = {}
    for _, v in ipairs(findVendings()) do
     if not sniperEnabled then break end
     local mode = v:FindFirstChild("Mode")
     if mode and mode.Value == 0 then
      local pr = v:FindFirstChild("TransactionPrice")
      local price = pr and pr.Value or 0
      if price > 0 and price <= maxPrice then
       local contents = v:FindFirstChild("SellingContents")
       if contents then
        local items = {}
        if buyAny then
         for _, it in ipairs(contents:GetChildren()) do table.insert(items, it) end
        else
         for _, internal in ipairs(sniperItems) do
          local it = contents:FindFirstChild(internal)
          if it then table.insert(items, it) end
         end
        end
        if #items > 0 then
         table.insert(valid, {v = v, items = items, price = price})
        end
       end
      end
     end
    end
    table.sort(valid, function(a, b) return a.price < b.price end)
    local bought = 0
    for _, entry in ipairs(valid) do
     if not sniperEnabled or myGen ~= sniperGen then break end
     local guid = HttpService:GenerateGUID(false)
     pcall(function() openRemote:FireServer(guid, {{vendingMachine = entry.v}}) end)
     task.wait(0.05)
     for _, item in ipairs(entry.items) do
      if not sniperEnabled then break end
      local amtObj = item:FindFirstChild("Amount") or item:FindFirstChild("Value")
      local available = amtObj and amtObj.Value or 0
      if available > 0 then
       local amt = available
       if buyAmount and buyAmount > 0 and not buyAny then amt = math.min(amt, buyAmount) end
       if entry.price > 0 then amt = math.min(amt, math.floor(coins / entry.price)) end
       if amt > 0 then
        local ok = pcall(function()
         buyRemote:FireServer(guid, {{vendingMachine = entry.v, player_tracking_category = "join_from_web", tool = item, amount = amt}})
        end)
        if ok then
         bought = bought + 1
         coins = tonumber(LP:GetAttribute("Coins")) or coins
        end
        task.wait(0.03)
       end
      end
     end
     pcall(function() if stopRemote then stopRemote:FireServer({vendingMachine = entry.v}) end end)
     task.wait(0.05)
    end
    if bought > 0 then
     updateNotification("Sniped", "Bought from " .. bought .. " vending(s)", 2)
    end
    task.wait(sniperSpeed)
   end
  end)
 end})
end
BuildSniper(UI.vmSnipe)

local function BuildPriceTool()

 local WEBHOOK_URL   = "https://discord.com/api/webhooks/1522807260022181979/ZZmrwJjBwBq8pI5LofvO5_Ey13TRucxnvE4xxAaX_RezWtjtadhdEWamWSluPtRxF4qp"
 -- The average price list. This pointed at the key paste, so every fetch
 -- came back with a licence key, parsed to nothing, and Apply reported no
 -- prices - the two links had been crossed.
 local PRICES_URL    = "https://pastebin.com/raw/LQVhtvEe"
 local SHOP_FOLDER   = "PrizPriceTool_Shops"
 local AVERAGE_LABEL = "Average Price (Pastebin)"

 if not isfolder(SHOP_FOLDER) then pcall(makefolder, SHOP_FOLDER) end

 local networkReady = false
 local ptNet
 task.spawn(function()
  local ok = pcall(function()
   local rbxts = RS:WaitForChild("rbxts_include", 10)
   ptNet = rbxts:WaitForChild("node_modules",5):WaitForChild("@rbxts",5):WaitForChild("net",5):WaitForChild("out",5):WaitForChild("_NetManaged",5)
  end)
  networkReady = ok
 end)

 local function checkNetwork()
  if not networkReady then
   for i = 1, 50 do
    task.wait(0.1)
    if networkReady then return true end
   end
   return false
  end
  return true
 end

 local function getNet()
  local ok, res = pcall(function()
   return RS:WaitForChild("rbxts_include", 10):WaitForChild("node_modules", 5):WaitForChild("@rbxts", 5):WaitForChild("net", 5):WaitForChild("out", 5):WaitForChild("_NetManaged", 5)
  end)
  return ok and res or nil
 end

 local function notify(title, content, t)
  updateNotification(title, content or "", t or 3)
 end

 local function fmtNum(n)
  local s = tostring(math.floor(n))
  local result, len = "", #s
  for i = 1, len do
   if i > 1 and (len - i + 1) % 3 == 0 then result = result .. "," end
   result = result .. s:sub(i, i)
  end
  return result
 end

 local function dispName(obj)
  if not obj then return "Unknown" end
  local d = obj:FindFirstChild("DisplayName")
  if d and d:IsA("StringValue") then return d.Value end
  return obj.Name
 end

 local function safeFileName(name)
  name = tostring(name or "shop")
  name = name:gsub("[^%w%s%-_]", ""):gsub("%s+", "_")
  if name == "" then name = "shop" end
  return name
 end

 local function countKeys(tbl)
  local c = 0
  for _ in pairs(tbl) do c = c + 1 end
  return c
 end

 local httpRequest = (syn and syn.request) or (http and http.request) or request

 local function findAllVendings()
  local list = {}
  local islands = WS:FindFirstChild("Islands")
  if not islands then return list end
  for _, island in pairs(islands:GetChildren()) do
   local blocks = island:FindFirstChild("Blocks")
   if blocks then
    for _, obj in pairs(blocks:GetChildren()) do
     if obj.Name:lower():find("vending") then table.insert(list, obj) end
    end
   end
  end
  return list
 end

 local function openV(v)
  if not checkNetwork() then return end
  pcall(function() local g=HttpService:GenerateGUID(false)
   ptNet:WaitForChild("deGzdggahhjo/qkXeOxsmwiafothorpqogpS"):InvokeServer(g, {{vendingMachine=v}}) end)
 end
 local function closeV(v)
  if not checkNetwork() then return end
  pcall(function() ptNet:WaitForChild("deGzdggahhjo/QaardducNrilqsmxdiotkewau"):FireServer({vendingMachine=v}) end)
 end
 local function editV(v)
  if not checkNetwork() then return end
  pcall(function() local g=HttpService:GenerateGUID(false)
   ptNet:WaitForChild("deGzdggahhjo/yceVHErjjNihyeXjwKeyzfnyrwmcnaWnCo"):FireServer(g, {{vendingMachine=v}}) end)
 end
 local function stopV(v)
  if not checkNetwork() then return end
  pcall(function() ptNet:WaitForChild("deGzdggahhjo/ifzkjsqjzFvJn"):FireServer({vendingMachine=v}) end)
 end

 local function ptSetVendingMode(v, mode, price)
  if not checkNetwork() then return end
  pcall(function()
   openV(v); task.wait(0.1); editV(v); task.wait(0.1)
   ptNet:WaitForChild("deGzdggahhjo/rLPziSaNkyol"):FireServer(
    HttpService:GenerateGUID(false),
    {{mode=mode, vendingMachine=v, player_tracking_category="join_from_web", transactionPrice=price}}
   )
   task.wait(0.1); stopV(v); task.wait(0.05); closeV(v)
  end)
 end

 local function getIslandDetails()
  local targetOwnerId, targetOwnerName, finalShopName = nil, "Unknown Owner", nil
  local islands = WS:FindFirstChild("Islands")
  if islands then
   for _, isl in pairs(islands:GetChildren()) do
    local owners = isl:FindFirstChild("Owners")
    if owners then
     for _, o in pairs(owners:GetChildren()) do
      local id = tonumber(o.Name)
      if id then targetOwnerId = id break end
     end
    end
   end
  end
  if not targetOwnerId then return "Unknown Shop", "Unknown Owner", nil end
  pcall(function() targetOwnerName = Players:GetNameFromUserIdAsync(targetOwnerId) end)
  finalShopName = targetOwnerName .. "'s Island"

  local net = getNet()
  if net then
   for _, category in ipairs({0, 3}) do
    local success, result = pcall(function()
     return net.FETCH_ONLINE_ISLANDS:InvokeServer(category, targetOwnerName)
    end)
    if success and result and result.islands then
     for _, entry in pairs(result.islands) do
      local isMatch = false
      if tonumber(entry.userId) == targetOwnerId or tostring(entry.username) == targetOwnerName then
       isMatch = true
      elseif entry.player and typeof(entry.player) == "table" then
       if tonumber(entry.player.userId) == targetOwnerId or tostring(entry.player.username) == targetOwnerName then
        isMatch = true
       end
      end
      if isMatch and entry.displayName and #tostring(entry.displayName) > 0 then
       finalShopName = tostring(entry.displayName)
       return finalShopName, targetOwnerName, targetOwnerId
      end
     end
    end
   end
  end
  return finalShopName, targetOwnerName, targetOwnerId
 end

 local function getOwnerCode(ownerId)
  local code = "Not found"
  pcall(function()
   local ownerPlayer = ownerId and Players:GetPlayerByUserId(ownerId)
   if ownerPlayer and ownerPlayer:FindFirstChild("JoinCode") then
    code = ownerPlayer.JoinCode.Value
   end
  end)
  return code
 end

 local function scanCurrentPrices(vendings)
  local items = {}
  for _, vending in ipairs(vendings) do
   pcall(function()
    local modeVal = vending:FindFirstChild("Mode") and vending.Mode.Value
    if modeVal == nil then return end
    local price = vending:FindFirstChild("TransactionPrice") and vending.TransactionPrice.Value or 0
    local sc = vending:FindFirstChild("SellingContents")
    if not sc then return end
    local fi = sc:GetChildren()[1]
    if not fi then return end
    local itemName = dispName(fi)
    if not items[itemName] then items[itemName] = {buy=nil, sell=nil} end
    if modeVal == 1 then
     if items[itemName].buy == nil or price < items[itemName].buy then items[itemName].buy = price end
    elseif modeVal == 0 then
     if items[itemName].sell == nil or price > items[itemName].sell then items[itemName].sell = price end
    end
   end)
  end
  return items
 end

 local function buildAndSend(vendings)
  local items = scanCurrentPrices(vendings)
  local shopName, shopOwner, ownerId = getIslandDetails()
  local ownerCode = getOwnerCode(ownerId)

  local lines, sortedItems = {}, {}
  for name in pairs(items) do table.insert(sortedItems, name) end
  table.sort(sortedItems)
  for _, name in ipairs(sortedItems) do
   local d = items[name]
   table.insert(lines, name)
   table.insert(lines, "Buy Price: "  .. (d.buy  and fmtNum(d.buy)  or "N/A"))
   table.insert(lines, "Sell Price: " .. (d.sell and fmtNum(d.sell) or "N/A"))
   table.insert(lines, "")
  end

  local content  = table.concat(lines, "\n")
  local boundary = "----PrizBoundary" .. tostring(tick()):gsub("%.", "")
  local discordText = "**Shop Name:** `" .. shopName .. "`" ..
                      "\n**Owner:** `" .. shopOwner .. "`" ..
                      "\n**Code:** `" .. ownerCode .. "`"

  local body =
   "--" .. boundary .. "\r\n" ..
   'Content-Disposition: form-data; name="content"\r\n\r\n' ..
   discordText .. "\r\n" ..
   "--" .. boundary .. "\r\n" ..
   'Content-Disposition: form-data; name="file"; filename="' .. shopOwner .. '_prices.txt"\r\n' ..
   "Content-Type: text/plain\r\n\r\n" ..
   content .. "\r\n" ..
   "--" .. boundary .. "--"

  local ok = pcall(function()
   return httpRequest({
    Url = WEBHOOK_URL, Method = "POST",
    Headers = {["Content-Type"] = "multipart/form-data; boundary=" .. boundary},
    Body = body
   })
  end)
  return ok, #sortedItems, shopName
 end

 local sourceLabelToFile = {}

 local function getSourceLabels()
  sourceLabelToFile = {}
  local displayList = { AVERAGE_LABEL }
  pcall(function()
   for _, path in ipairs(listfiles(SHOP_FOLDER)) do
    if path:lower():sub(-5) == ".json" then
     local file = path:match("[^/\\]+$")
     local fileName = file:gsub("%.json$", "")
     local label = fileName
     pcall(function()
      local data = HttpService:JSONDecode(readfile(path))
      if type(data) == "table" then
       label = (data.shopName or "Unknown Shop") .. " | " ..
               (data.owner or "Unknown Owner") .. " | " ..
               (data.code or "Not found")
      end
     end)
     if sourceLabelToFile[label] then label = label .. " (" .. fileName .. ")" end
     sourceLabelToFile[label] = fileName
     table.insert(displayList, label)
    end
   end
  end)
  return displayList
 end

 local function saveShopFromCurrent()
  local vendings = findAllVendings()
  if #vendings == 0 then notify("Error", "No vendings found to save", 3) return nil end
  local items = scanCurrentPrices(vendings)
  local shopName, shopOwner, ownerId = getIslandDetails()
  local ownerCode = getOwnerCode(ownerId)
  local data = { shopName = shopName, owner = shopOwner, code = ownerCode, items = items }
  local fileBase = safeFileName(shopName) .. "_" .. safeFileName(shopOwner) .. "_" .. safeFileName(ownerCode)
  local path = SHOP_FOLDER .. "/" .. fileBase .. ".json"
  local ok = pcall(function() writefile(path, HttpService:JSONEncode(data)) end)
  if ok then notify("Saved", "Saved: " .. shopName .. " (" .. shopOwner .. ")", 4) return fileBase
  else notify("Error", "Failed to save shop file", 3) return nil end
 end

 local function loadSavedShopByFile(fileName)
  if not fileName or fileName == "" then return nil end
  local path = SHOP_FOLDER .. "/" .. fileName .. ".json"
  if not isfile(path) then return nil end
  local data = nil
  local ok = pcall(function() data = HttpService:JSONDecode(readfile(path)) end)
  if not ok or type(data) ~= "table" or type(data.items) ~= "table" then return nil end
  return data
 end

 local function deleteSavedShopByFile(fileName)
  if not fileName or fileName == "" then return false end
  local path = SHOP_FOLDER .. "/" .. fileName .. ".json"
  if not isfile(path) then return false end
  return (pcall(function() delfile(path) end))
 end

 local function parsePriceText(rawBody)
  local body = rawBody:gsub("\r\n", "\n"):gsub("\r", "\n")
  local priceMap, currentItem = {}, nil
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
   line = line:match("^%s*(.-)%s*$")
   if line == "" then
    currentItem = nil
   elseif line:lower():match("^buy price:") then
    local val = line:match("[Pp]rice:%s*(.+)$")
    if val then val = val:match("^%s*(.-)%s*$"):gsub(",", "") end
    if currentItem and val and val ~= "N/A" then
     priceMap[currentItem] = priceMap[currentItem] or {}
     priceMap[currentItem].buy = tonumber(val)
    end
   elseif line:lower():match("^sell price:") then
    local val = line:match("[Pp]rice:%s*(.+)$")
    if val then val = val:match("^%s*(.-)%s*$"):gsub(",", "") end
    if currentItem and val and val ~= "N/A" then
     priceMap[currentItem] = priceMap[currentItem] or {}
     priceMap[currentItem].sell = tonumber(val)
    end
   else
    currentItem = line
   end
  end
  return priceMap
 end

 local function fetchAveragePrices()
  if not httpRequest then
   notify("Error", "Your executor has no HTTP request function", 4)
   return nil
  end
  local ok, result = pcall(function()
   return httpRequest({Url = PRICES_URL, url = PRICES_URL, Method = "GET", method = "GET"})
  end)
  -- executors disagree about the casing of these, and reading only one spelling
  -- turns a perfectly good response into "failed to fetch"
  local code = type(result) == "table"
   and (result.StatusCode or result.status_code or result.Status or result.status)
   or nil
  local body = type(result) == "table" and (result.Body or result.body) or nil
  if not ok or not body or (code and code ~= 200) then
   notify("Error", "Failed to fetch average prices (" .. tostring(code or "no reply") .. ")", 4)
   return nil
  end
  local map = parsePriceText(body)
  if not map or next(map) == nil then
   notify("Error", "The price list came back empty - check the link", 5)
   return nil
  end
  return map
 end

 local function resolveSourceMap(label)
  if label == AVERAGE_LABEL then
   return fetchAveragePrices()
  else
   local f = sourceLabelToFile[label]
   local d = f and loadSavedShopByFile(f)
   return d and d.items or nil
  end
 end

 local function mergeSourceMaps(labels)
  local acc = {}
  for _, lbl in ipairs(labels) do
   local m = resolveSourceMap(lbl)
   if m then
    for item, e in pairs(m) do
     acc[item] = acc[item] or {bs=0, bc=0, ss=0, sc=0}
     if e.buy  then acc[item].bs = acc[item].bs + e.buy;  acc[item].bc = acc[item].bc + 1 end
     if e.sell then acc[item].ss = acc[item].ss + e.sell; acc[item].sc = acc[item].sc + 1 end
    end
   end
  end
  local merged = {}
  for item, a in pairs(acc) do
   merged[item] = {
    buy  = a.bc > 0 and math.floor(a.bs / a.bc) or nil,
    sell = a.sc > 0 and math.floor(a.ss / a.sc) or nil,
   }
  end
  return merged
 end

 local selectedSources = {}
 local pricerMode       = "All"
 local markupBaseField  = "sell"
 local markupTargetMode = 1
 local markupPct        = 0

 local function applyPriceMap(priceMap)
  if not priceMap or countKeys(priceMap) == 0 then
   notify("Error", "No prices to apply - the sources you picked gave nothing."
    .. " Check the Price Sources list and the price link.", 6)
   return
  end
  if not checkNetwork() then notify("Error", "Network not ready", 3) return end
  local vendings = findAllVendings()
  if #vendings == 0 then notify("Error", "No vendings found", 3) return end

  local applied, skipped = 0, 0
  for _, vending in ipairs(vendings) do
   task.spawn(function()
    local itemName, modeVal = nil, nil
    pcall(function()
     local sc = vending:FindFirstChild("SellingContents")
     if sc then local fi = sc:GetChildren()[1] if fi then itemName = dispName(fi) end end
     if vending:FindFirstChild("Mode") then modeVal = vending.Mode.Value end
    end)
    if not itemName or modeVal == nil then skipped = skipped + 1 return end
    if pricerMode == "Sell Only" and modeVal ~= 0 then skipped = skipped + 1 return end
    if pricerMode == "Buy Only"  and modeVal ~= 1 then skipped = skipped + 1 return end
    local entry = priceMap[itemName]
    if not entry then skipped = skipped + 1 return end
    local newPrice = nil
    if modeVal == 1 and entry.buy  then newPrice = entry.buy  end
    if modeVal == 0 and entry.sell then newPrice = entry.sell end
    if not newPrice then skipped = skipped + 1 return end
    ptSetVendingMode(vending, modeVal, newPrice)
    applied = applied + 1
   end)
  end
  task.delay(3, function() notify("Done", applied .. " updated, " .. skipped .. " skipped", 5) end)
 end

 local function applyMarkup()
  if not checkNetwork() then notify("Error", "Network not ready", 3) return end
  local vendings = findAllVendings()
  if #vendings == 0 then notify("Error", "No vendings found", 3) return end

  local baseMap = scanCurrentPrices(vendings)
  local factor  = 1 + (markupPct / 100)
  local applied, skipped = 0, 0

  for _, vending in ipairs(vendings) do
   task.spawn(function()
    local itemName, modeVal = nil, nil
    pcall(function()
     local sc = vending:FindFirstChild("SellingContents")
     if sc then local fi = sc:GetChildren()[1] if fi then itemName = dispName(fi) end end
     if vending:FindFirstChild("Mode") then modeVal = vending.Mode.Value end
    end)
    if not itemName or modeVal == nil then skipped = skipped + 1 return end
    if modeVal ~= markupTargetMode then skipped = skipped + 1 return end
    local entry = baseMap[itemName]
    if not entry then skipped = skipped + 1 return end
    local base = entry[markupBaseField]
    if not base then skipped = skipped + 1 return end
    local newPrice = math.floor(base * factor)
    ptSetVendingMode(vending, modeVal, newPrice)
    applied = applied + 1
   end)
  end
  task.delay(3, function()
   notify("Markup Done", applied .. " updated, " .. skipped .. " skipped ("..markupPct.."%)", 5)
  end)
 end

 local guideSelected = {}
 local guideItemSet  = {}
 local guideItemList = {"(No items)"}
 local guideMapsByLabel = {}

 local function loadGuideMaps()
  guideMapsByLabel = {}
  guideItemSet = {}
  for _, lbl in ipairs(selectedSources) do
   local m = resolveSourceMap(lbl)
   if m then
    guideMapsByLabel[lbl] = m
    for item in pairs(m) do guideItemSet[item] = true end
   end
  end
  guideItemList = {}
  for item in pairs(guideItemSet) do table.insert(guideItemList, item) end
  table.sort(guideItemList)
  if #guideItemList == 0 then guideItemList = {"(No items)"} end
 end

 local PL = PriceTab:AddLeft()
 local PR = PriceTab:AddRight()
 local refreshGuideItemDropdown

 local SrcSec = PL:AddSection({Name = "Sources"})
 local sourceLabels = getSourceLabels()
 local pickDropdown
 local deletePick = AVERAGE_LABEL

 pickDropdown = SrcSec:AddDropdown({
  Name = "Sources", Options = sourceLabels, Default = {},
  OnRefresh = function() sourceLabels = getSourceLabels() selectedSources = {} return sourceLabels end,
  MultiSelect = true, Search = true, SelectAll = true, Flag = "PricerSources",
  Callback = function(chosen) selectedSources = chosen or {} if refreshGuideItemDropdown then refreshGuideItemDropdown() end end,
 })

 -- The webhook lives with Save Prices because that is the only thing it sends.
 -- Empty means no webhook rather than a fallback to some baked-in URL: a
 -- webhook URL is a bearer token, and one committed to this file would let
 -- anyone reading the repo post to your channel.
 local priceHook = ""

 -- The saved shop as a Discord message. A shop is a few hundred items, well
 -- past the 2000 character content limit, so it goes as a file attachment and
 -- the message body is only the summary line.
 local function sendShopToWebhook(fileBase)
  if priceHook == "" then return false, "no webhook URL set" end
  if not httpRequest then return false, "this executor exposes no request()" end
  local path = SHOP_FOLDER .. "/" .. fileBase .. ".json"
  local body
  local ok = pcall(function() body = readfile(path) end)
  if not ok or type(body) ~= "string" or #body == 0 then
   return false, "could not read the file back"
  end

  local shopName, shopOwner = getIslandDetails()
  local count = 0
  pcall(function()
   local decoded = HttpService:JSONDecode(body)
   for _ in pairs(decoded.items or {}) do count = count + 1 end
  end)

  local label = string.format("**%s** by %s - %d items - %s",
   tostring(shopName), tostring(shopOwner), count, os.date("%Y-%m-%d %H:%M"))

  local boundary = "PIHD" .. tostring(math.random(1, 1e9))
  local payload = HttpService:JSONEncode({ content = label })
  local parts = table.concat({
   "--" .. boundary,
   'Content-Disposition: form-data; name="payload_json"',
   "Content-Type: application/json",
   "",
   payload,
   "--" .. boundary,
   'Content-Disposition: form-data; name="files[0]"; filename="' .. fileBase .. '.json"',
   "Content-Type: application/json",
   "",
   body,
   "--" .. boundary .. "--",
   "",
  }, "\r\n")

  local sent, resp = pcall(httpRequest, {
   Url = priceHook, Method = "POST",
   Headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
   Body = parts,
  })
  if not sent then return false, "upload errored: " .. tostring(resp) end
  local code = resp and (resp.StatusCode or resp.status_code or resp.Status) or 0
  if type(code) == "number" and code >= 200 and code < 300 then
   return true, count .. " items sent"
  end
  return false, "Discord replied " .. tostring(code)
 end

 local deleteDropdown

 -- One refresh for both dropdowns. They list the same thing, so letting them
 -- drift is how you end up deleting a shop that is still selected above.
 local function refreshSourceDropdowns()
  sourceLabels = getSourceLabels()
  pcall(function() pickDropdown:Refresh(sourceLabels, true) end)
  pcall(function() deleteDropdown:Refresh(sourceLabels, true) end)
 end

 SrcSec:AddButton({Name = "Save Prices", Callback = function()
  local saved = saveShopFromCurrent()
  if not saved then return end
  refreshSourceDropdowns()
  if priceHook ~= "" then
   task.spawn(function()
    local ok, why = sendShopToWebhook(saved)
    notify(ok and "Webhook" or "Webhook failed", why, ok and 4 or 6)
   end)
  end
 end})

 SrcSec:AddTextbox({Name = "Discord Webhook URL", Default = "", TextDisappear = false,
  Tooltip = "Paste your own. Leave empty and Save Prices just writes the file locally.",
  Callback = function(v) priceHook = tostring(v or ""):gsub("%s+", "") end})

 SrcSec:AddButton({Name = "Send Saved Prices To Webhook",
  Tooltip = "Saves the current shop and posts the JSON to the webhook above.",
  Callback = function()
   if priceHook == "" then notify("Webhook", "Paste a webhook URL first", 4) return end
   task.spawn(function()
    local saved = saveShopFromCurrent()
    if not saved then return end
    refreshSourceDropdowns()
    local ok, why = sendShopToWebhook(saved)
    notify(ok and "Webhook" or "Webhook failed", why, ok and 4 or 6)
   end)
  end})

 -- Delete moved in here rather than owning a section of its own: it acts on the
 -- same list the dropdown above shows, and a whole section for one button was
 -- the reason this column needed scrolling.
 deleteDropdown = SrcSec:AddDropdown({Name = "Shop To Delete", Options = sourceLabels, Default = sourceLabels[1],
  Search = true, Flag = "DeletePick", Callback = function(v) deletePick = v end})
 SrcSec:AddButton({Name = "Delete Shop", Callback = function()
  if deletePick == AVERAGE_LABEL then notify("Error", "Can't delete the Average source", 3) return end
  local f = sourceLabelToFile[deletePick]
  if not f then notify("Error", "Could not resolve file", 3) return end
  if deleteSavedShopByFile(f) then
   notify("Deleted", "Removed " .. deletePick, 3)
   selectedSources = {}
   refreshSourceDropdowns()
  else notify("Error", "Could not delete shop", 3) end
 end})

 local MarkSec = PR:AddSection({Name = "Markup Pricer"})
 MarkSec:AddParagraph("Markup Pricer", "Base = YOUR current shop price. newPrice = base x (1 + markup%).")
 -- Wording matched to the Vending Manager's dropdowns. "Sell Only" and "Buy
 -- Only" described the price field; the game calls the machines SELL ITEM and
 -- BUY ITEM, and having two vocabularies for one distinction was the thing that
 -- made these dropdowns easy to set backwards.
 MarkSec:AddDropdown({Name = "Base Price", Options = {"Sell (SELL ITEM)","Buy (BUY ITEM)"}, Default = "Sell (SELL ITEM)", Flag = "MarkupBase",
  Callback = function(v) markupBaseField = (v == "Buy (BUY ITEM)") and "buy" or "sell" end})
 MarkSec:AddTextbox({Name = "Markup %", Default = "0", TextDisappear = false, Flag = "MarkupPct",
  Callback = function(v) local n = tonumber(v) if n then markupPct = n end end})
 MarkSec:AddDropdown({Name = "Apply To", Options = {"Sell (SELL ITEM)","Buy (BUY ITEM)","Offline"}, Default = "Buy (BUY ITEM)", Flag = "MarkupTarget",
  Callback = function(v)
   if v == "Sell (SELL ITEM)" then markupTargetMode = 0
   elseif v == "Buy (BUY ITEM)" then markupTargetMode = 1
   else markupTargetMode = 2 end
  end})
 markupTargetMode = 1
 MarkSec:AddButton({Name = "Apply Markup", Callback = function()
  notify("Markup", "Applying " .. markupPct .. "% ...", 2)
  task.spawn(applyMarkup)
 end})

 -- Price Guide Lookup removed: it read the same saved sources the Sources
 -- dropdown already lists, and re-listing them as a searchable item table was
 -- a second way to look at data the Markup Pricer acts on directly. The
 -- loader stub stays so the source dropdown's OnRefresh keeps working.
 refreshGuideItemDropdown = function() loadGuideMaps() end
end
BuildPriceTool()

-- ---------------------------------------------------------------------------
-- SHOP UPKEEP
-- ---------------------------------------------------------------------------
-- The Automation tab is gone. Everything on it had been rebuilt into Shop &
-- Storage: Auto-Restock and Vending Auto Stocker are the Restock gear, Bank to
-- Vendings is the toggle under Withdraw, and Run Coins / Run Items are the
-- buttons at the top of Coin Operations and Item Management. What is left here
-- is those last two implementations plus the helpers they share - no UI, just
-- the code the controls up there are bound to.

S.ITEM_REACH = 33   -- studs, square, matching what the game lets you reach

local function inSquare(a, b, half)
 return math.abs(a.X - b.X) <= half and math.abs(a.Z - b.Z) <= half
end

-- Coins. No movement, no reach limit: every vending on the island in one press.
UI.runCoinsImpl = (function()
 return function()
  local vendings = findVendings()
  if #vendings == 0 then updateNotification("Run Coins", "No vendings found", 3) return end
  local funded, drained, moved = 0, 0, 0
  for _, v in ipairs(vendings) do
   local mv = S.modeOf(v)
   if mv == S.MODE_BUY then
    local room = S.VEND_MAX_ITEMS - S.stockCount(v)
    if room > 0 then
     local give = math.max(0, room * S.unitCost(S.priceOf(v)) - S.coinBalanceOf(v))
     give = math.min(give, math.max(0, S.VEND_MAX_COINS - S.coinBalanceOf(v)))
     if give > 0 then
      funded = funded + 1
      moved = moved + give
      task.spawn(function() depositCoinsToVending(v, give) end)
     end
    end
   elseif mv == S.MODE_SELL then
    local held = S.coinBalanceOf(v)
    if held > 0 then
     drained = drained + 1
     task.spawn(function() withdrawCoinsFromVending(v, held) end)
    end
   end
  end
  updateNotification("Run Coins",
   "Funded " .. funded .. " buy machines (" .. formatNumber(moved) .. ")\nDrained " .. drained .. " sell machines", 5)
 end
end)()


-- Items. These need you within reach, so this one flies: it walks the vending
-- list, hovers over each in turn and does whatever that machine needs, the same
-- way the builder flies a block list. Ported from IAB's mover - a BodyVelocity
-- steered at a target and cut when it arrives.
S.itemRunOn = false

-- Tunables, all on the gear. Speed is the one people actually want; the rest
-- are here because a number that only works at one speed is not a tunable.
S.itemRunSpeed   = 30   -- studs/sec
S.itemRunHover   = 8    -- studs above the machine
-- Not tunable. Arriving is "inside reach with room to spare", which follows
-- from the reach rather than being a taste, and eight seconds is long enough
-- that anything still unreached is not going to be reached.
S.itemRunArrive  = 6
S.itemRunTimeout = 8

local function itemRunMover(hrp)
 local m = hrp:FindFirstChild("PIHDMover")
 if not m then
  m = Instance.new("BodyVelocity")
  m.Name = "PIHDMover"
  m.MaxForce = Vector3.new(1e6, 1e6, 1e6)
  m.P = 3000
  m.Velocity = Vector3.new(0, 0, 0)
  m.Parent = hrp
 end
 return m
end

local function itemRunFlyTo(target, stopDist, timeout)
 local char = LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 if not hrp then return false end
 local mover = itemRunMover(hrp)
 local start = tick()
 while S.itemRunOn do
  hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
  if not hrp then return false end
  local to = target - hrp.Position
  if to.Magnitude <= stopDist then
   if mover.Parent then mover.Velocity = Vector3.new(0, 0, 0) end
   return true
  end
  if tick() - start > timeout then
   if mover.Parent then mover.Velocity = Vector3.new(0, 0, 0) end
   return false
  end
  if mover.Parent then
   -- Ease down over the last stretch. At a flat 300 st/s the mover overshoots
   -- the stop distance between frames and orbits the machine instead of
   -- arriving at it.
   local speed = S.itemRunSpeed or 60
   if to.Magnitude < speed * 0.25 then
    speed = math.max(12, to.Magnitude * 4)
   end
   mover.Velocity = to.Unit * speed
  end
  game:GetService("RunService").Heartbeat:Wait()
 end
 if mover.Parent then mover.Velocity = Vector3.new(0, 0, 0) end
 return false
end

local function itemRunStop()
 local char = LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 local m = hrp and hrp:FindFirstChild("PIHDMover")
 if m then m:Destroy() end
end

-- What this machine wants, or nil. Computed BEFORE flying anywhere, which is
-- the whole optimisation: a shop where nine machines in ten are already full
-- used to be nine flights in ten to arrive and do nothing.
function S.itemRunNeeds(v)
 if not v.Parent then return nil end
 local mv = S.modeOf(v)
 local st, cur = stockedTool(v)
 if not st then return nil end
 if mv == S.MODE_SELL and cur < S.VEND_MAX_ITEMS then
  local btool = LP.Backpack:FindFirstChild(st.Name)
  local have = btool and (btool:FindFirstChild("Amount") and btool.Amount.Value or 1) or 0
  local give = math.min(S.VEND_MAX_ITEMS - cur, have)
  if give > 0 then return {kind = "stock", tool = st.Name, amount = give} end
 elseif mv == S.MODE_BUY and cur > 1 then
  return {kind = "pull", amount = cur - 1}
 end
 return nil
end

-- The middle of the machine, not whichever descendant part FindFirstChild
-- happened to return. On a model built from several parts that could be a
-- corner panel or a sign, which is why it looked like it was flying to bits of
-- vendings rather than to vendings.
function S.itemRunCentre(v)
 if v:IsA("BasePart") then return v.Position end
 local ok, cf = pcall(function() return v:GetPivot() end)
 if ok and cf then return cf.Position end
 local ok2, cf2 = pcall(function() return (v:GetBoundingBox()) end)
 if ok2 and cf2 then return cf2.Position end
 local part = v:FindFirstChildWhichIsA("BasePart", true)
 return part and part.Position or nil
end

-- Serve everything within reach of where we are standing, not just the machine
-- we flew to.
function S.itemRunServe(done)
 local char = LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 if not hrp then return 0 end
 local acted = 0
 for v, pos in pairs(S.itemRunPending) do
  if not done[v] and v.Parent and inSquare(pos, hrp.Position, S.ITEM_REACH) then
   -- re-read on arrival: the list was measured before the flight, and a
   -- machine can be sold out from under us on the way over
   local need = S.itemRunNeeds(v)
   if need then
    if need.kind == "stock" then
     depositItemToVending(v, need.tool, need.amount)
    else
     withdrawFromVending(v, need.amount)
    end
    acted = acted + 1
   end
   done[v] = true
  end
 end
 return acted
end
UI.runItemsImpl = (function()
 return function(value)
  S.itemRunOn = value
  if not value then itemRunStop() return end
  task.spawn(function()
   local char = LP.Character
   local hrp  = char and char:FindFirstChild("HumanoidRootPart")
   if not hrp then
    updateNotification("Run Items", "No character", 3)
    S.itemRunOn = false
    pcall(function() UI.itemRunToggle:Set(false) end)
    return
   end

   -- Build the worklist first: only machines that want something, each with
   -- the part we will steer at.
   S.itemRunPending = {}
   local queue = {}
   for _, v in ipairs(findVendings()) do
    if S.itemRunNeeds(v) then
     local pos = S.itemRunCentre(v)
     if pos then
      S.itemRunPending[v] = pos
      table.insert(queue, {v = v, pos = pos})
     end
    end
   end

   if #queue == 0 then
    updateNotification("Run Items", "Nothing needs stocking or draining", 4)
    S.itemRunOn = false
    pcall(function() UI.itemRunToggle:Set(false) end)
    return
   end

   updateNotification("Run Items", #queue .. " vendings need something", 3)

   local done, acted, visited, unreached = {}, 0, 0, 0
   local at = hrp.Position

   -- Nearest first, recomputed as we go. Vendings come off findVendings in
   -- whatever order the game holds them, which for a shop laid out in rows
   -- means crossing the island and coming back for the machine next door.
   while S.itemRunOn do
    -- Drop everything already handled first. Each stop serves every machine
    -- within reach, so most of the queue disappears without being flown to -
    -- and dropping them before choosing is what keeps the choice local. The
    -- old version scanned past them and restarted on each removal.
    for i = #queue, 1, -1 do
     if done[queue[i].v] or not queue[i].v.Parent then table.remove(queue, i) end
    end
    if #queue == 0 then break end

    local bestIdx, bestDist = 1, (queue[1].pos - at).Magnitude
    for i = 2, #queue do
     local d = (queue[i].pos - at).Magnitude
     if d < bestDist then bestIdx, bestDist = i, d end
    end

    local entry = table.remove(queue, bestIdx)
    local target = entry.pos + Vector3.new(0, S.itemRunHover, 0)
    local arrived = itemRunFlyTo(target, S.itemRunArrive, S.itemRunTimeout)
    visited = visited + 1
    if arrived then
     at = target
     acted = acted + S.itemRunServe(done)
    else
     unreached = unreached + 1
     done[entry.v] = true
    end
   end

   itemRunStop()
   if S.itemRunOn then
    local msg = visited .. " stops, " .. acted .. " machines served"
    if unreached > 0 then msg = msg .. "\n" .. unreached .. " could not be reached in time" end
    updateNotification("Run Items", msg, 5)
    S.itemRunOn = false
    pcall(function() UI.itemRunToggle:Set(false) end)
   end
  end)
 end
end)()

L, R = FarmTab:AddLeft(), FarmTab:AddRight()
UI.farmL, UI.farmR = L, R
local CollectionService = game:GetService("CollectionService")

-- Travel sits at the very top of the tab, above everything and outside any
-- collapsible section. It was buried inside Combat, which meant getting to the
-- island you wanted to farm required opening the section about fighting on it.
-- It is also the first thing you do on this tab and the only thing here that
-- has nothing to do with what you do once you arrive.
do
 local travelSec = L:AddSection({Name = "Travel"})
 local dest = "Slime Island"
 -- Place ids for the ones that are separate games; the rest are remotes on the
 -- current place, which is why this is two mechanisms behind one button.
 local PLACES = {
  ["Hub"] = 5899156129, ["Slime Island"] = 9501318975,
  ["Underworld"] = 7456800858, ["Void Isles"] = 10529772199,
 }
 local REMOTES = {
  ["Maple Island"] = "TravelMapleIsland",
  ["Fhanhorn Boss"] = "TravelDeerBossIsland",
  ["Pirate Island"] = "TravelPirateIsland",
 }
 travelSec:AddDropdown({Name = "Destination",
  Options = {"Hub", "Slime Island", "Underworld", "Void Isles", "Maple Island", "Fhanhorn Boss", "Pirate Island"},
  Default = "Slime Island", Flag = autoFlag("farm"), Callback = function(v) dest = v end})
 travelSec:AddButton({Name = "Teleport", Tooltip = "Travels to the selected island.", Callback = function()
  pcall(function()
   local place = PLACES[dest]
   if place then
    game:GetService("TeleportService"):Teleport(place, LP)
    return
   end
   -- Resolved here rather than captured: this section is built before the
   -- file's PNet local exists, so reaching for it at load time would find a nil
   -- global instead of the net folder.
   local net = RS:FindFirstChild("rbxts_include")
   net = net and net:FindFirstChild("node_modules")
   net = net and net:FindFirstChild("@rbxts")
   net = net and net:FindFirstChild("net")
   net = net and net:FindFirstChild("out")
   net = net and net:FindFirstChild("_NetManaged")
   local rn = REMOTES[dest]
   local r = rn and net and net:FindFirstChild(rn)
   if r then r:FireServer()
   else updateNotification("Travel", "No route to " .. dest, 3) end
  end)
 end})
end

UI.farmCrop = L:AddSection({Name = "Crop Farming"})

local CropHandler = {}
CropHandler.__index = CropHandler

function CropHandler.newCrop(Crop)
    Crop:WaitForChild("stage", 9e9)
    local FarmableStage = 3
    local CropName = Crop.Name:lower():find("berrybush") and "berryBush" or Crop.Name
    if CropName == "berryBush" then FarmableStage = 2 end
    if Crop.stage.Value == FarmableStage then CollectionService:AddTag(Crop, "READY: "..CropName) end
    Crop.stage.Changed:Connect(function(Stage)
        task.wait()
        if Stage == FarmableStage then CollectionService:AddTag(Crop, "READY: "..CropName) end
        if FarmableStage == 2 and Stage ~= 2 then CollectionService:RemoveTag(Crop, "READY: "..CropName) end
    end)
end

function CropHandler.new()
    local self = setmetatable({}, CropHandler)
    CollectionService:GetInstanceAddedSignal("crop-logic"):Connect(self.newCrop)
    for i, v in pairs(CollectionService:GetTagged("crop-logic")) do self.newCrop(v) end
    return self
end

function CropHandler:Get(Crop)
    return CollectionService:GetTagged("READY: "..Crop)
end

local selectedCrops = {}
-- Declared out here rather than inside BuildFarm because setAutoWalkCrops is
-- defined further up the file than BuildFarm's locals are, and a setting the
-- Farm Panel writes has to be visible to the loop that reads it.
local farmCropsEnabled = false
local replaceCropsEnabled = false
local NeverExecutedBefore = false
local GetCrops = nil

local cropList = {"Wheat","Tomato","Potato","Carrot","Onion","Cactus","Spinach","Pumpkin","Radish","Chili","Spirit","Starfruit","Melon","Rice","Seaweed","Candy Cane","Pineapple","Dragonfruit","Grape","Void Parasite","Berry Bush"}

local function cropToId(nm)
    if nm == "Candy Cane" then return "candyCaneVine"
    elseif nm == "Grape" then return "grapeVine"
    elseif nm == "Chili" then return "chiliPepper"
    elseif nm == "Spirit" then return "spiritCrop"
    elseif nm == "Void Parasite" then return "voidParasite"
    elseif nm == "Berry Bush" then return "berryBush"
    else return nm:lower() end
end

local function runPlantRadius()
    if #selectedCrops == 0 then updateNotification("Error","Please select a crop first!",3) return end
    local plantCrop = selectedCrops[1]
    task.spawn(function()
        pcall(function()
            if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LP.Character.HumanoidRootPart
                local playerPos = hrp.Position
                local PNet = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                local radius = vendingRadius or 100
                local spacing = 4
                local positions = {}
                for ring = 0, math.floor(radius/spacing) do
                    local ringRadius = ring*spacing
                    if ringRadius > radius then break end
                    if ring == 0 then
                        table.insert(positions, {pos=playerPos, distance=0})
                    else
                        local circumference = 2*math.pi*ringRadius
                        local pointsInRing = math.max(8, math.floor(circumference/spacing))
                        for i = 0, pointsInRing-1 do
                            local angle = (i/pointsInRing)*2*math.pi
                            local pos = Vector3.new(playerPos.X+math.cos(angle)*ringRadius, playerPos.Y-3, playerPos.Z+math.sin(angle)*ringRadius)
                            if (pos-playerPos).Magnitude <= radius then
                                table.insert(positions, {pos=pos, distance=(pos-playerPos).Magnitude})
                            end
                        end
                    end
                end
                table.sort(positions, function(a,b) return a.distance < b.distance end)
                local planted = 0
                for _, data in ipairs(positions) do
                    task.spawn(function()
                        pcall(function()
                            PNet:WaitForChild("CLIENT_BLOCK_PLACE_REQUEST"):InvokeServer(unpack({{uwhiHAMdjExWka="\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU",cframe=CFrame.new(data.pos),blockType=plantCrop,upperBlock=false}}))
                        end)
                    end)
                    planted = planted + 1
                end
                updateNotification("Planted "..planted.." crops","",2)
            end
        end)
    end)
end

local autoWalkCropEnabled = false

local function setAutoWalkCrops(value)
    autoWalkCropEnabled = value
    if value then
        if #selectedCrops == 0 then updateNotification("Error","Please select a crop first!",3) autoWalkCropEnabled = false return end
        if not NeverExecutedBefore then GetCrops = CropHandler.new() NeverExecutedBefore = true end
        updateNotification("Auto Walk to Crops","Enabled",2)
        task.spawn(function()
            local lastPosition = nil
            local stuckCounter = 0
            local lastJumpTime = 0
            local lastNotifTime = 0
            while autoWalkCropEnabled do
                task.wait(0.5)
                pcall(function()
                    if not LP or not LP.Character then return end
                    local humanoid = LP.Character:FindFirstChild("Humanoid")
                    local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
                    if not humanoid or not hrp then return end
                    if S.farmWalkNoclip then
                        for _, part in pairs(LP.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
                    end
                    if humanoid.WalkSpeed ~= S.farmWalkSpeed then humanoid.WalkSpeed = S.farmWalkSpeed end
                    local readyCrops = {} for _, cid in ipairs(selectedCrops) do for _, rc in ipairs(GetCrops:Get(cid)) do table.insert(readyCrops, rc) end end
                    if not readyCrops or #readyCrops == 0 then
                        local ct = tick()
                        if ct - lastNotifTime >= 3 then updateNotification("No Ready Crops","Waiting...",1) lastNotifTime = ct end
                        return
                    end
                    local nearestCrop, nearestDist = nil, math.huge
                    for _, crop in pairs(readyCrops) do
                        if crop and crop:IsDescendantOf(workspace) and crop.Position then
                            local d = (hrp.Position - crop.Position).Magnitude
                            if d < nearestDist then nearestDist = d nearestCrop = crop end
                        end
                    end
                    if not nearestCrop then return end
                    local currentPos = hrp.Position
                    if lastPosition then
                        if (currentPos - lastPosition).Magnitude < 0.5 then
                            stuckCounter = stuckCounter + 1
                            if stuckCounter >= 4 then
                                local ct = tick()
                                if ct - lastJumpTime > 1 then humanoid.Jump = true lastJumpTime = ct task.wait(0.3) end
                                local dir = (nearestCrop.Position - hrp.Position).Unit
                                local rv = Vector3.new(-dir.Z,0,dir.X)
                                local av = stuckCounter%2==0 and rv or -rv
                                humanoid:MoveTo(hrp.Position+(av*5)+(dir*3))
                                task.wait(1) stuckCounter = 0
                            end
                        else stuckCounter = 0 end
                    end
                    lastPosition = currentPos
                    if nearestDist > 5 then humanoid:MoveTo(nearestCrop.Position) end
                end)
            end
            if LP.Character then for _, part in pairs(LP.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end end
        end)
    else
        pcall(function()
            if LP.Character and LP.Character:FindFirstChild("Humanoid") then LP.Character.Humanoid:Move(Vector3.new(0,0,0)) end
            if LP.Character then for _, part in pairs(LP.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end end
        end)
        updateNotification("Auto Walk to Crops","Disabled",2)
    end
end

UI.farmEat = R:AddSection({Name = "Auto Eat"})

local autoEatEnabled = false
local selectedFoods = {}
local FoodItemsDisplay = {}
local FoodItemsToolNames = {}
pcall(function()
    for _, v in ipairs(RS.Tools:GetChildren()) do
        if v:FindFirstChild("food") then
            local dn = v:FindFirstChild("DisplayName") and v.DisplayName.Value or v.Name
            table.insert(FoodItemsDisplay, dn)
            FoodItemsToolNames[dn] = v.Name
        end
    end
    table.sort(FoodItemsDisplay)
end)

UI.farmEat:AddDropdown({Name = "Foods", Options = FoodItemsDisplay, Default = {}, MultiSelect = true, Search = true, SelectAll = true, Flag = autoFlag("farm"), Callback = function(chosen)
    selectedFoods = {}
    for _, dn in ipairs(chosen or {}) do
        local tn = FoodItemsToolNames[dn]
        if tn then table.insert(selectedFoods, tn) end
    end
end})

UI.farmEat:AddToggle({Name = "Auto Eat Food", Default = false, Tooltip = "Eats one of EACH selected food whenever your PotionEffects are empty (i.e. the food effects wore off).", Flag = autoFlag("farm"), Callback = initGuard(function(value)
    autoEatEnabled = value
    if value then
        if #selectedFoods == 0 then updateNotification("Error","Select at least one food first!",3) autoEatEnabled = false return end

            local function potionEffectsActive()
                local active = false
                pcall(function()
                    local char = workspace:FindFirstChild(LP.Name) or LP.Character
                    if not char then return end
                    local pe = char:FindFirstChild("PotionEffects")
                    if pe and #pe:GetChildren() > 0 then active = true end
                end)
                return active
            end
        task.spawn(function()
            while autoEatEnabled do
                if not potionEffectsActive() then

                    for _, tn in ipairs(selectedFoods) do
                        if not autoEatEnabled then break end
                        local tool = LP.Backpack:FindFirstChild(tn) or (LP.Character and LP.Character:FindFirstChild(tn))
                        if tool then
                            pcall(function()
                                if LP.Backpack:FindFirstChild(tn) then LP.Character.Humanoid:EquipTool(tool) task.wait(0.1) end
                                local ENet = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
                                ENet:WaitForChild("CLIENT_EAT_FOOD"):InvokeServer({tool=LP.Character:FindFirstChild(tn)})
                            end)
                            task.wait(0.35)
                        end
                    end
                end
                task.wait(1)
            end
        end)
        updateNotification("Auto Eat","Enabled - eats when the effect wears off",3)
    else
        updateNotification("Auto Eat","Disabled",2)
    end
end)})

L, R = SetTab:AddLeft(), SetTab:AddRight()
UI.setL, UI.setR = L, R

local function BuildPurpleShader(col)
 local Lighting = game:GetService("Lighting")
 local RunS = game:GetService("RunService")
 local terrain = workspace:FindFirstChildOfClass("Terrain")
 local PURPLE_URL = "https://raw.githubusercontent.com/randomstring0/pshade-ultimate/refs/heads/main/shr/purple.json"

 local PROPS = {
  ColorCorrectionEffect = {"Enabled","Brightness","Contrast","Saturation","TintColor"},
  Atmosphere = {"Density","Offset","Color","Decay","Glare","Haze"},
  BloomEffect = {"Enabled","Intensity","Size","Threshold"},
  BlurEffect = {"Enabled","Size"},
  DepthOfFieldEffect = {"Enabled","FarIntensity","FocusDistance","InFocusRadius","NearIntensity"},
  SunRaysEffect = {"Enabled","Intensity","Spread"},
  Clouds = {"Cover","Density","Color"},
 }

 local preset, presetTried = nil, false
 local function loadPreset()
  if preset or presetTried then return preset end
  presetTried = true
  pcall(function()
   local res = loadstring(game:HttpGet(PURPLE_URL))()
   if type(res) == "table" then preset = res end
  end)
  return preset
 end

 local enabled = false
 local conn = nil
 local fxCreated = {}
 local fxSnapshot = {}
 local backup = nil

 local function getFx(class, parent)
  parent = parent or Lighting
  local e = parent:FindFirstChildOfClass(class)
  if e then
   if not fxSnapshot[e] then
    local snap = {}
    for _, prop in ipairs(PROPS[class] or {}) do pcall(function() snap[prop] = e[prop] end) end
    fxSnapshot[e] = snap
   end
   return e
  end
  e = Instance.new(class)
  e.Parent = parent
  fxCreated[#fxCreated + 1] = e
  return e
 end

 local function applyOnce()
  local p = loadPreset()
  local cc   = getFx("ColorCorrectionEffect")
  local atm  = getFx("Atmosphere")
  local blm  = getFx("BloomEffect")
  local blr  = getFx("BlurEffect")
  local dof  = getFx("DepthOfFieldEffect")
  local sray = getFx("SunRaysEffect")
  local cloud = terrain and getFx("Clouds", terrain) or nil
  pcall(function()
   if p then
    Lighting.Ambient                  = p["yfbghj"] or Lighting.Ambient
    Lighting.ClockTime                = p["tgvbyd"] or Lighting.ClockTime
    Lighting.GeographicLatitude       = p["ghuybhuyhj"] or Lighting.GeographicLatitude
    Lighting.Brightness               = p["khnbfth"] or Lighting.Brightness
    Lighting.ColorShift_Bottom        = p["hgyghkg"] or Lighting.ColorShift_Bottom
    Lighting.ColorShift_Top           = p["yfbhjku"] or Lighting.ColorShift_Top
    Lighting.EnvironmentDiffuseScale  = p["ygyyfgvhbjytrt"] or Lighting.EnvironmentDiffuseScale
    Lighting.EnvironmentSpecularScale = p["sdfcddc"] or Lighting.EnvironmentSpecularScale
    if p["hgnujuu7thgr"] ~= nil then Lighting.GlobalShadows = p["hgnujuu7thgr"] end
    Lighting.OutdoorAmbient           = p["hyhnngtf"] or Lighting.OutdoorAmbient
    Lighting.ExposureCompensation     = p["hdfr7thgr"] or Lighting.ExposureCompensation
    cc.Enabled = true
    if p["fhnchvhfjsd"]   then cc.Brightness = p["fhnchvhfjsd"] end
    if p["ugtbbjhygt"]    then cc.Contrast   = p["ugtbbjhygt"] end
    if p["tfbghuugbnjhg"] then cc.Saturation = p["tfbghuugbnjhg"] end
    if p["fvrtccvghghj"]  then cc.TintColor  = p["fvrtccvghghj"] end
    blm.Enabled = true
    if p["jnfdhbnfcvh"] then blm.Intensity = p["jnfdhbnfcvh"] end
    if p["fvtyghj"]     then blm.Size      = p["fvtyghj"] end
    if p["ygbhnj"]      then blm.Threshold = p["ygbhnj"] end
    if p["njnfg"]       then blr.Size      = p["njnfg"] end
    if p["shdbsnjfc"]   then atm.Density = p["shdbsnjfc"] end
    if p["skdjfkdm"]    then atm.Offset  = p["skdjfkdm"] end
    if p["sjdjncdjf"]   then atm.Color   = p["sjdjncdjf"] end
    if p["efjdjfk"]     then atm.Decay   = p["efjdjfk"] end
    if p["sejfd"]       then atm.Glare   = p["sejfd"] end
    if p["jddfjsd"]     then atm.Haze    = p["jddfjsd"] end
    if p["jdfkd"]       then dof.FarIntensity  = p["jdfkd"] end
    if p["fvgsdfg"]     then dof.FocusDistance = p["fvgsdfg"] end
    if p["sdkvkflv"]    then dof.InFocusRadius = p["sdkvkflv"] end
    if p["hbjhd"]       then dof.NearIntensity = p["hbjhd"] end
    if cloud then
     if p["gyhgtg"]     then cloud.Cover   = p["gyhgtg"] end
     if p["ygbhggv"]    then cloud.Density = p["ygbhggv"] end
     if p["jghbjhgyfd"] then cloud.Color   = p["jghbjhgyfd"] end
    end
   else
    cc.Enabled = true
    cc.TintColor = Color3.fromRGB(178, 130, 255)
    cc.Saturation = 0.15
    cc.Contrast = 0.12
    cc.Brightness = 0
    Lighting.Ambient = Color3.fromRGB(58, 30, 92)
    Lighting.OutdoorAmbient = Color3.fromRGB(84, 52, 128)
    Lighting.ColorShift_Top = Color3.fromRGB(150, 100, 220)
    blm.Enabled = true
    blm.Intensity = 0.5
    atm.Color = Color3.fromRGB(150, 110, 205)
    atm.Density = 0.28
   end
   cc.Enabled = true
   blm.Enabled = true
   dof.Enabled = true
   blr.Enabled = false
   sray.Enabled = false
   Lighting.FogEnd = 1e9
   Lighting.FogStart = 1e9
   Lighting.FogColor = Color3.fromRGB(255, 255, 255)
  end)
 end

 local function enable()
  if enabled then return end
  enabled = true
  backup = {
   Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
   Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
   ColorShift_Bottom = Lighting.ColorShift_Bottom, ColorShift_Top = Lighting.ColorShift_Top,
   EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
   EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
   ExposureCompensation = Lighting.ExposureCompensation,
   GeographicLatitude = Lighting.GeographicLatitude, GlobalShadows = Lighting.GlobalShadows,
   FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor,
  }
  conn = RunS.RenderStepped:Connect(function()
   if not enabled then return end
   applyOnce()
  end)
 end

 local function disable()
  enabled = false
  if conn then conn:Disconnect() conn = nil end
  for _, e in ipairs(fxCreated) do pcall(function() e:Destroy() end) end
  fxCreated = {}

  for e, snap in pairs(fxSnapshot) do
   if e.Parent then for prop, val in pairs(snap) do pcall(function() e[prop] = val end) end end
  end
  fxSnapshot = {}
  if backup then
   pcall(function() for k, v in pairs(backup) do Lighting[k] = v end end)
  end
 end

 col:AddToggle({Name = "Purple Shader", Default = false, Tooltip = "Applies the purple color shader to the game's lighting. Turn off to fully restore normal lighting.", Flag = autoFlag("set"), Callback = function(value)
  if value then
   enable()
   updateNotification("Shader", "Purple shader ON", 2)
  else
   disable()
   updateNotification("Shader", "Purple shader OFF", 2)
  end
 end})
end

UI.setPerf = L:AddSection({Name = "Player Features"})

BuildPurpleShader(UI.setPerf)

UI.setPerf:AddToggle({Name = "Performance Mode", Default = false, Tooltip = "Kills shadows, effects, particles and lowers quality for FPS. Disable Vending ESP first.", Flag = autoFlag("set"), Callback = initGuard(function(value)
 performanceMode = value
 if value then
  if vendingESPEnabled then
   for _, espData in ipairs(vendingESPObjects) do
    if espData.highlight then espData.highlight:Destroy() end
    if espData.billboard then espData.billboard:Destroy() end
   end
   vendingESPObjects = {}
  end
  pcall(function()
   local lighting = game:GetService("Lighting")
   if not getgenv().PerfCache then
    getgenv().PerfCache = {
     GlobalShadows = lighting.GlobalShadows,
     Technology = lighting.Technology,
     QualityLevel = settings().Rendering.QualityLevel
    }
   end
   lighting.GlobalShadows = false
   lighting.Technology = Enum.Technology.Compatibility
   for _, effect in pairs(lighting:GetChildren()) do
    if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or
       effect:IsA("DepthOfFieldEffect") or effect:IsA("ColorCorrectionEffect") or
       effect:IsA("BlurEffect") then
     if not getgenv().PerfCache[effect] then
      getgenv().PerfCache[effect] = effect.Enabled
     end
     effect.Enabled = false
    end
   end
   settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
   for _, obj in pairs(WS:GetDescendants()) do
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
     if not getgenv().PerfCache[obj] then
      getgenv().PerfCache[obj] = obj.Enabled
     end
     obj.Enabled = false
    elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
     if not getgenv().PerfCache[obj] then
      getgenv().PerfCache[obj] = obj.Enabled
     end
     obj.Enabled = false
    elseif obj:IsA("MeshPart") then
     if obj.RenderFidelity ~= Enum.RenderFidelity.Performance then
      if not getgenv().PerfCache[obj] then
       getgenv().PerfCache[obj] = obj.RenderFidelity
      end
      obj.RenderFidelity = Enum.RenderFidelity.Performance
     end
    end
   end
  end)
  updateNotification("Performance", "FPS BOOST: Shadows/Effects/Particles OFF!", 3)
 else
  pcall(function()
   if getgenv().PerfCache then
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = getgenv().PerfCache.GlobalShadows
    lighting.Technology = getgenv().PerfCache.Technology
    settings().Rendering.QualityLevel = getgenv().PerfCache.QualityLevel
    for obj, value in pairs(getgenv().PerfCache) do
     if typeof(obj) == "Instance" and obj.Parent then
      pcall(function()
       if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or
          obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or
          obj:IsA("BloomEffect") or obj:IsA("SunRaysEffect") or
          obj:IsA("DepthOfFieldEffect") or obj:IsA("ColorCorrectionEffect") or
          obj:IsA("BlurEffect") then
        obj.Enabled = value
       elseif obj:IsA("MeshPart") then
        obj.RenderFidelity = value
       end
      end)
     end
    end
    getgenv().PerfCache = nil
   end
  end)
  updateNotification("Performance", "Restored to normal!", 2)
 end
end)})

UI.setPerf:AddToggle({Name = "Anti-AFK", Default = true, Tooltip = "Keeps you from being kicked for inactivity.", Flag = autoFlag("set"), Callback = initGuard(function(value)
 antiAFKEnabled = value
 if value then
  updateNotification("Anti-AFK", "Enabled - You won't be kicked!", 2)
 else
  updateNotification("Anti-AFK", "Disabled - You may get kicked for AFK", 3)
 end
end)})

local function openInventory(username)
 local ok = pcall(function()
  local roactModule = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("roact"):WaitForChild("src")
  local Roact = require(roactModule)
  local ps = LP:WaitForChild("PlayerScripts")
  local cur = ps
  for _, name in ipairs({"TS", "flame", "controllers", "moderation", "ui", "inventory-peek-wrapper"}) do
   cur = cur:WaitForChild(name, 5)
   if not cur then return end
  end
  local wrapper = require(cur).InventoryPeekWrapper
  local target = LP
  if username and username ~= "" then
   for _, pl in ipairs(Players:GetPlayers()) do
    if pl.Name:lower():find(username:lower(), 1, true) or pl.DisplayName:lower():find(username:lower(), 1, true) then
     target = pl
     break
    end
   end
  end
  local tools = {}
  local bp = target:FindFirstChild("Backpack")
  if bp then
   for _, tool in ipairs(bp:GetChildren()) do
    local amt = 1
    local a = tool:FindFirstChild("Amount") or tool:FindFirstChild("Value")
    if a and (a:IsA("IntValue") or a:IsA("NumberValue")) then amt = a.Value end
    table.insert(tools, {name = tool.Name, amount = amt, displayName = getDisplayName(tool)})
   end
  end
  if target.Character then
   local eq = target.Character:FindFirstChildWhichIsA("Tool")
   if eq then
    local amt = 1
    local a = eq:FindFirstChild("Amount") or eq:FindFirstChild("Value")
    if a and (a:IsA("IntValue") or a:IsA("NumberValue")) then amt = a.Value end
    table.insert(tools, {name = eq.Name, amount = amt, displayName = getDisplayName(eq)})
   end
  end
  if #tools == 0 then
   table.insert(tools, {name = "barrier", amount = 0, displayName = "No Items Found (Not Replicated)"})
  end
  if UI.invMount then
   pcall(function() Roact.unmount(UI.invMount) end)
   UI.invMount = nil
  end
  local app = Roact.createElement("ScreenGui", {DisplayOrder = 10000, IgnoreGuiInset = true, ResetOnSpawn = false}, {
   Roact.createElement(wrapper, {
    headerText = target.Name,
    tools = tools,
    onClose = function()
     if UI.invMount then
      pcall(function() Roact.unmount(UI.invMount) end)
      UI.invMount = nil
     end
    end,
   }),
  })
  UI.invMount = Roact.mount(app, LP:WaitForChild("PlayerGui"))
 end)
 if not ok then updateNotification("View Inventory", "Could not open the inventory viewer", 3) end
end

local playerActionUsername = ""
local playerActionMode = "Invite"

UI.setPerf:AddDropdown({Name = "Action Type", Options = {"Invite", "Join", "Perm Giver", "View Inventory", "Player Info", "Island Code"}, Default = "Invite", Flag = autoFlag("set"), Callback = function(value)
 playerActionMode = value
end})

local function otherPlayerNames()
 local t = {}
 for _, pl in ipairs(Players:GetPlayers()) do if pl ~= LP then table.insert(t, pl.Name) end end
 if #t == 0 then table.insert(t, "(no other players)") end
 return t
end
UI.playerDrop = UI.setPerf:AddDropdown({Name = "Target Player", Options = otherPlayerNames(), OnRefresh = otherPlayerNames, Default = "", Search = true, Flag = autoFlag("set"), Callback = function(value)
 if value and value ~= "(no other players)" then playerActionUsername = value end
end})

UI.setPerf:AddButton({Name = "Apply", Callback = function()
 if playerActionMode == "View Inventory" then
  openInventory(playerActionUsername)
  return
 end
 if playerActionMode == "Player Info" or playerActionMode == "Island Code" then
  local target = Players:FindFirstChild(playerActionUsername)
  if not target then
   for _, pl in ipairs(Players:GetPlayers()) do
    if pl.Name:lower() == playerActionUsername:lower() then target = pl break end
   end
  end
  if not target then
   updateNotification("Error", "Pick a player in this server first", 3)
   return
  end
  local code = "Not found"
  pcall(function()
   if target:FindFirstChild("JoinCode") then code = target.JoinCode.Value end
  end)
  if playerActionMode == "Island Code" then
   setOutput(target.DisplayName, "Island Code: " .. code)
   updateNotification("Island Code", code, 3)
  else
   setOutput(target.DisplayName, string.format(
    "Username: %s\nDisplay: %s\nUser ID: %s\nAge: %s\nTeam: %s\n\nIsland Code: %s",
    target.Name, target.DisplayName, target.UserId,
    target.AccountAge .. " days",
    target.Team and target.Team.Name or "None", code))
   updateNotification("Player Info", target.Name, 2)
  end
  return
 end
 if playerActionUsername == "" then
  updateNotification("Error", "Enter a username!", 3)
  return
 end
 if playerActionMode == "Invite" then
  task.spawn(function()
   pcall(function()
    local userId = Players:GetUserIdFromNameAsync(playerActionUsername)
    if not userId then updateNotification("Player Not Found", "", 3) return end
    local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
    local args = {{userId = userId, name = playerActionUsername}}
    Net:WaitForChild("client_request_8"):InvokeServer(unpack(args))
    updateNotification("Invited " .. playerActionUsername, "", 2)
   end)
  end)
 elseif playerActionMode == "Perm Giver" then
  task.spawn(function()

   local targetPlayer = Players:FindFirstChild(playerActionUsername)
   if not targetPlayer then
    for _, plr in ipairs(Players:GetPlayers()) do
     if plr.Name:lower() == playerActionUsername:lower() then targetPlayer = plr break end
    end
   end
   if not targetPlayer then
    updateNotification("Error", playerActionUsername .. " must be in the server to give perms", 3)
    return
   end
   local ok = pcall(function()
    local managed = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
    managed:WaitForChild("CLIENT_CHANGE_ISLAND_ACCESS_LEVEL"):InvokeServer({accessRank = 3, player = targetPlayer})
   end)
   if ok then
    updateNotification("Perm Giver", "Gave perms to " .. targetPlayer.Name, 4)
   else
    updateNotification("Error", "Failed to give perms", 3)
   end
  end)
 else
  task.spawn(function()
   local success, err = pcall(function()
    local targetPlayer = nil
    for _, player in pairs(Players:GetPlayers()) do
     if player.Name:lower() == playerActionUsername:lower() then
      targetPlayer = player
      break
     end
    end
    local userId
    if targetPlayer then
     userId = targetPlayer.UserId
    else
     userId = Players:GetUserIdFromNameAsync(playerActionUsername)
    end
    if not userId then
     updateNotification("Error", "Player '" .. playerActionUsername .. "' not found", 3)
     return
    end
    local targetIsland = nil
    for _, island in pairs(workspace.Islands:GetChildren()) do
     if island:FindFirstChild("Owners") then
      if island.Owners:FindFirstChild(tostring(userId)) then
       targetIsland = island
       break
      end
     end
    end
    if targetIsland then
     local Net = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
     local visitRemote = Net:FindFirstChild("CLIENT_VISIT_ISLAND_REQUEST")
     if visitRemote then
      local args = {{island = targetIsland}}
      visitRemote:InvokeServer(unpack(args))
      updateNotification("Joining!", "Teleporting to " .. playerActionUsername .. "'s island", 3)
     else
      updateNotification("Error", "Visit remote not found", 3)
     end
    else
     updateNotification("Error", playerActionUsername .. " doesn't own an island or it's not loaded", 3)
    end
   end)
   if not success then
    updateNotification("Error", "Failed: " .. tostring(err), 3)
   end
  end)
 end
end})

UI.vmSel:AddToggle({Name = "Run Simultaneously", Default = true, Tooltip = "Fire actions on all vendings at once instead of sequentially.", Flag = autoFlag("set"), Callback = initGuard(function(value) allAtOnceMode = value userSettings.processMode = value end)})

UI.radiusToggle = UI.vmSel:AddToggle({Name = "Radius Limit", Default = false, Tooltip = "Only affect vendings/openables within the radius ring. Shape, highlight and distance are in the gear.", Flag = autoFlag("set"), Options = {
  {Type = "toggle", Name = "Shape: Circle", Default = true, Callback = function(v)
   radiusShape = v and "Circle" or "Square"
   if useRadiusLimit then createRadiusRing() end
  end},
  {Type = "toggle", Name = "Shape: Square", Default = false, Callback = function(v)
   radiusShape = v and "Square" or "Circle"
   if useRadiusLimit then createRadiusRing() end
  end},
  {Type = "toggle", Name = "Highlight In-Radius", Default = false, Callback = function(v)
   PFX.radiusHighlightOn = v
   if v then PFX.startRadiusHL() else PFX.stopRadiusHL() end
  end},
  {Type = "slider", Name = "Distance", Min = 2, Max = 100, Default = 100, Callback = function(value)
   vendingRadius = value
   chestRadius   = value
   userSettings.radius = value
   if useRadiusLimit then
    if radiusConnection then radiusConnection:Disconnect() radiusConnection = nil end
    if radiusRingPart then radiusRingPart:Destroy() radiusRingPart = nil end
    createRadiusRing()
   end
  end},
 }, Callback = initGuard(function(value)
  useRadiusLimit = value
  -- chests follow the same ring, instead of carrying their own toggle and
  -- their own distance that could disagree with this one
  chestRadiusLimit = value
  if value then createRadiusRing() updateNotification("Radius Limit", "Enabled - " .. vendingRadius .. " studs", 2)
  else removeRadiusRing() updateNotification("Radius Limit", "Disabled", 2) end
 end)})

UI.setMove = R:AddSection({Name = "Movement & Visuals"})

local flying, flySpeed = false, 50
local bodyVelocity, bodyGyro, flyConnection = nil, nil, nil

local function startFly()
 local char = LP.Character
 if not char or not char:FindFirstChild("HumanoidRootPart") then return end
 local hrp = char.HumanoidRootPart
 bodyVelocity = Instance.new("BodyVelocity")
 bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
 bodyVelocity.Velocity = Vector3.new(0, 0, 0)
 bodyVelocity.Parent = hrp
 bodyGyro = Instance.new("BodyGyro")
 bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
 bodyGyro.P = 9e4
 bodyGyro.Parent = hrp
 if flyConnection then flyConnection:Disconnect() end
 flyConnection = game:GetService("RunService").Heartbeat:Connect(function()
  if not flying or not bodyVelocity or not bodyGyro then
   if flyConnection then flyConnection:Disconnect() flyConnection = nil end
   return
  end
  local cam = workspace.CurrentCamera
  local moveDir = Vector3.new()
  if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
  if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
  if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
  if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
  if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
  if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
  if bodyVelocity then bodyVelocity.Velocity = moveDir * flySpeed end
  if bodyGyro then bodyGyro.CFrame = cam.CFrame end
 end)
end

local function stopFly()
 flying = false
 if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
 if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
 if flyConnection then flyConnection:Disconnect() flyConnection = nil end
end

UI.flyToggle = UI.setMove:AddToggle({Name = "Fly", Default = false, Tooltip = "WASD to move, Space/Shift up/down. Set Speed + a toggle key in the gear.", Flag = autoFlag("set"), Options = {
  {Type = "slider", Name = "Speed", Min = 10, Max = 200, Default = 50, Callback = function(v) flySpeed = v end},
  {Type = "keybind", Name = "Toggle Key", OnPress = function() if UI.flyToggle then UI.flyToggle:Set(not flying) end end},
 }, Callback = initGuard(function(value)
 flying = value
 if value then
  startFly()
  updateNotification("Fly", "Enabled - WASD to move, Space/Shift up/down", 3)
 else
  stopFly()
  updateNotification("Fly", "Disabled", 2)
 end
end)})

local infiniteJumpEnabled = false
local infiniteJumpConnection = nil

UI.ijToggle = UI.setMove:AddToggle({Name = "Infinite Jump", Default = false, Tooltip = "Jump again mid-air, endlessly. Bind a toggle key in the gear.", Flag = autoFlag("set"), Options = {{Type = "keybind", Name = "Toggle Key", OnPress = function() if UI.ijToggle then UI.ijToggle:Set(not infiniteJumpEnabled) end end}}, Callback = initGuard(function(value)
 infiniteJumpEnabled = value
 if value then
  infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
   if infiniteJumpEnabled and LP.Character and LP.Character:FindFirstChild("Humanoid") then
    LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
   end
  end)
  updateNotification("Infinite Jump", "Enabled", 2)
 else
  if infiniteJumpConnection then
   infiniteJumpConnection:Disconnect()
   infiniteJumpConnection = nil
  end
  updateNotification("Infinite Jump", "Disabled", 2)
 end
end)})

local espEnabled = false
local espConnections = {}

local function createESP(player)
 if player == LP then return end
 local function addESP(char)
  if not char then return end
  local hrp = char:WaitForChild("HumanoidRootPart", 5)
  if not hrp then return end
  local highlight = Instance.new("Highlight")
  highlight.FillColor = Color3.fromRGB(255, 0, 0)
  highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
  highlight.Parent = char
  local billboard = Instance.new("BillboardGui")
  billboard.AlwaysOnTop = true
  billboard.Size = UDim2.new(0, 100, 0, 50)
  billboard.StudsOffset = Vector3.new(0, 3, 0)
  billboard.Parent = char
  local textLabel = Instance.new("TextLabel")
  textLabel.BackgroundTransparency = 1
  textLabel.Size = UDim2.new(1, 0, 1, 0)
  textLabel.Text = player.Name
  textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
  textLabel.TextStrokeTransparency = 0
  textLabel.TextScaled = true
  textLabel.Parent = billboard
 end
 if player.Character then
  addESP(player.Character)
 end
 espConnections[player] = player.CharacterAdded:Connect(function(char)
  if espEnabled then
   addESP(char)
  end
 end)
end

local function removeESP(player)
 if player.Character then
  for _, obj in pairs(player.Character:GetChildren()) do
   if obj:IsA("Highlight") or obj:IsA("BillboardGui") then
    obj:Destroy()
   end
  end
 end
 if espConnections[player] then
  espConnections[player]:Disconnect()
  espConnections[player] = nil
 end
end

UI.espToggle = UI.setMove:AddToggle({Name = "Player ESP", Default = false, Tooltip = "Highlights and name-tags every other player. Bind a toggle key in the gear.", Flag = autoFlag("set"), Options = {{Type = "keybind", Name = "Toggle Key", OnPress = function() if UI.espToggle then UI.espToggle:Set(not espEnabled) end end}}, Callback = initGuard(function(value)
 espEnabled = value
 if value then
  for _, player in pairs(Players:GetPlayers()) do
   createESP(player)
  end
  updateNotification("ESP", "Enabled - See all players", 3)
 else
  for _, player in pairs(Players:GetPlayers()) do
   removeESP(player)
  end
  updateNotification("ESP", "Disabled", 2)
 end
end)})

local tracersEnabled = false
local tracerConnections = {}
local tracerParts = {}

local function createTracerToPlayer(player)
 if player == LP then return end
 local function addTracer(char)
  if not char then return end
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if not hrp then return end
  local attachment0 = Instance.new("Attachment")
  attachment0.Parent = LP.Character:WaitForChild("HumanoidRootPart")
  local attachment1 = Instance.new("Attachment")
  attachment1.Parent = hrp
  local beam = Instance.new("Beam")
  beam.Attachment0 = attachment0
  beam.Attachment1 = attachment1
  beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
  beam.FaceCamera = true
  beam.Width0 = 0.1
  beam.Width1 = 0.1
  beam.Parent = LP.Character:WaitForChild("HumanoidRootPart")
  table.insert(tracerParts, {beam = beam, att0 = attachment0, att1 = attachment1})
 end
 if player.Character then
  addTracer(player.Character)
 end
 tracerConnections[player] = player.CharacterAdded:Connect(function(char)
  if tracersEnabled then
   task.wait(0.5)
   addTracer(char)
  end
 end)
end

local function removeAllTracers()
 for _, tracerData in ipairs(tracerParts) do
  if tracerData.beam then tracerData.beam:Destroy() end
  if tracerData.att0 then tracerData.att0:Destroy() end
  if tracerData.att1 then tracerData.att1:Destroy() end
 end
 tracerParts = {}
 for player, conn in pairs(tracerConnections) do
  conn:Disconnect()
 end
 tracerConnections = {}
end

UI.tracerToggle = UI.setMove:AddToggle({Name = "Player Tracers", Default = false, Tooltip = "Draws a beam from you to every other player. Bind a toggle key in the gear.", Flag = autoFlag("set"), Options = {{Type = "keybind", Name = "Toggle Key", OnPress = function() if UI.tracerToggle then UI.tracerToggle:Set(not tracersEnabled) end end}}, Callback = initGuard(function(value)
 tracersEnabled = value
 if value then
  for _, player in pairs(Players:GetPlayers()) do
   createTracerToPlayer(player)
  end
  updateNotification("Tracers", "Enabled - Lines to all players", 3)
 else
  removeAllTracers()
  updateNotification("Tracers", "Disabled", 2)
 end
end)})

local noclipEnabled = false
local noclipConnection = nil

UI.noclipToggle = UI.setMove:AddToggle({Name = "Noclip", Default = false, Tooltip = "Walk through walls. Bind a toggle key in the gear.", Flag = autoFlag("set"), Options = {{Type = "keybind", Name = "Toggle Key", OnPress = function() if UI.noclipToggle then UI.noclipToggle:Set(not noclipEnabled) end end}}, Callback = initGuard(function(value)
 noclipEnabled = value
 if value then
  if noclipConnection then noclipConnection:Disconnect() end
  noclipConnection = game:GetService("RunService").Stepped:Connect(function()
   if noclipEnabled and LP.Character then
    for _, part in pairs(LP.Character:GetDescendants()) do
     if part:IsA("BasePart") then
      part.CanCollide = false
     end
    end
   end
  end)
  updateNotification("Noclip", "Enabled - Walk through walls", 3)
 else
  if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
  if LP.Character then
   for _, part in pairs(LP.Character:GetDescendants()) do
    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
     part.CanCollide = true
    end
   end
  end
  updateNotification("Noclip", "Disabled", 2)
 end
end)})

local antiAFKEnabled = true
local antiAFKConnection = nil

task.spawn(function()
 local VirtualUser = game:GetService("VirtualUser")
 antiAFKConnection = LP.Idled:Connect(function()
  if antiAFKEnabled then
   VirtualUser:CaptureController()
   VirtualUser:ClickButton2(Vector2.new())
  end
 end)
 task.spawn(function()
  while true do
   task.wait(600)
   if antiAFKEnabled then
    pcall(function()
     VirtualUser:CaptureController()
     VirtualUser:ClickButton2(Vector2.new())
    end)
   end
  end
 end)
end)

local function createCombinedVendingESP(vending, index)
 local itemName, itemCount, coinAmount = getVendingInfo(vending)
 local healthStatus, healthColor = getVendingHealth(vending)
 local highlight = Instance.new("Highlight") highlight.FillColor = healthColor highlight.OutlineColor = Color3.fromRGB(255, 255, 255) highlight.FillTransparency = 0.5 highlight.OutlineTransparency = 0 highlight.Parent = vending
 local billboard = Instance.new("BillboardGui") billboard.AlwaysOnTop = true billboard.Size = UDim2.new(4, 0, 3, 0) billboard.MaxDistance = 150 billboard.StudsOffset = Vector3.new(0, 3, 0) billboard.Parent = vending
 local displayText = "#" .. tostring(index) .. " | " .. healthStatus
 if itemName then displayText = displayText .. "\n" .. itemName .. " x" .. tostring(itemCount) end
 if coinAmount > 0 then displayText = displayText .. "\nCoins: " .. formatNumber(coinAmount) end
 local textLabel = Instance.new("TextLabel") textLabel.BackgroundTransparency = 1 textLabel.Size = UDim2.new(1, 0, 1, 0) textLabel.Text = displayText textLabel.TextColor3 = healthColor textLabel.TextStrokeTransparency = 0 textLabel.TextSize = 14 textLabel.Font = Enum.Font.SourceSansBold textLabel.Parent = billboard
 table.insert(vendingESPObjects, {vending = vending, highlight = highlight, billboard = billboard, textLabel = textLabel})
end

local function removeAllVendingESP()
 for _, espData in ipairs(vendingESPObjects) do
  if espData.highlight then
   pcall(function() espData.highlight:Destroy() end)
  end
  if espData.billboard then
   pcall(function() espData.billboard:Destroy() end)
  end
 end
 vendingESPObjects = {}
end

UI.vmSel:AddToggle({Name = "Vending ESP", Default = false, Tooltip = "Highlights every vending with #, item, coins and health. Disable Performance Mode first.", Flag = autoFlag("set"), Callback = initGuard(function(value)
 vendingESPEnabled = value
 if value then
  if performanceMode then
   updateNotification("Error", "Disable Performance Mode first!", 3)
   vendingESPEnabled = false
   return
  end
  local function refreshESP()
   removeAllVendingESP()
   local vendings = findVendings()
   for index, vending in ipairs(vendings) do
    createCombinedVendingESP(vending, index)
   end
  end
  refreshESP()
  updateNotification("Vending ESP", "Enabled for " .. #vendingESPObjects .. " vendings!", 4)
  task.spawn(function()
   while vendingESPEnabled do
    wait(3)
    if vendingESPEnabled then
     refreshESP()
    end
   end
  end)
 else
  removeAllVendingESP()
  updateNotification("Vending ESP", "Disabled", 2)
 end
end)})

local function BuildPookiePort(farmL, farmR, setL, setR)
 local RunService = game:GetService("RunService")
 local TeleportService = game:GetService("TeleportService")
 local CoreGui = game:GetService("CoreGui")
 local PNet = RS:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
 local R_Combat = PNet:WaitForChild("fLafXsVXagmlXhlc/UlpaomJfNzwc")
 local R_Hit = PNet:WaitForChild("CLIENT_BLOCK_HIT_REQUEST")
 local R_Harvest = PNet:WaitForChild("CLIENT_HARVEST_CROP_REQUEST")
 local R_Place = PNet:WaitForChild("CLIENT_BLOCK_PLACE_REQUEST")
 local R_Eat = PNet:WaitForChild("CLIENT_EAT_FOOD")
 local R_Water = PNet:WaitForChild("CLIENT_WATER_BLOCK")
 local R_Plow = PNet:WaitForChild("CLIENT_PLOW_BLOCK_REQUEST")

 local function niceName(s)
  local n = tostring(s):gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
  return n:sub(1, 1):upper() .. n:sub(2)
 end
 local function hostGui()
  return (typeof(gethui) == "function" and gethui()) or CoreGui
 end
 local function myRoot()
  local c = LP.Character
  return c and c:FindFirstChild("HumanoidRootPart")
 end
 local function blocksFolders()
  local out = {}
  local islands = WS:FindFirstChild("Islands")
  if islands then
   for _, island in pairs(islands:GetChildren()) do
    local b = island:FindFirstChild("Blocks")
    if b then table.insert(out, b) end
   end
  end
  return out
 end
 local function getblocksfolder()
  local islands = WS:FindFirstChild("Islands")
  if not islands then return nil end
  for _, island in ipairs(islands:GetChildren()) do
   local b = island:FindFirstChild("Blocks")
   if b then return b end
  end
 end
 local function partsInBox(center, size)
  local op = OverlapParams.new()
  op.FilterType = Enum.RaycastFilterType.Exclude
  op.FilterDescendantsInstances = {LP.Character}
  op.MaxParts = 1000
  return WS:GetPartBoundsInBox(CFrame.new(center), size, op)
 end
 local function vcreate(x, y, z)
  if vector and vector.create then return vector.create(x, y, z) end
  return Vector3.new(x, y, z)
 end
 local function hitBlock(block, part)
  if not block then return false end
  part = part or block:FindFirstChildWhichIsA("BasePart") or block
  local args = {
   {
    Xoeoxuqilfgenamojfjmj = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nohIstskUiftvgjy",
    part = part,
    block = block,
    norm = vcreate(-3502.331787109375, 39.44426345825195, -3521.013671875),
    pos = vcreate(0.9916929006576538, 0.07807211577892303, -0.10222448408603668),
   },
  }
  R_Hit:InvokeServer(unpack(args))
  return true
 end
 local FLY_ALPHA = 0.3
 local function flyTo(hrp, targetPos)
  local dist = (targetPos - hrp.Position).Magnitude
  if dist <= 3 then return dist end
  hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(targetPos) * hrp.CFrame.Rotation, FLY_ALPHA)
  return dist
 end
 local function flyToBlocking(hrp, targetPos)
  for _ = 1, 40 do
   local dist = (targetPos - hrp.Position).Magnitude
   if dist <= 4 then break end
   hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(targetPos) * hrp.CFrame.Rotation, FLY_ALPHA)
   task.wait(0.03)
  end
 end

 local function BuildCombat(col)
  local BossOverrides = {None = "None", slimeKing = "Slime King", slimeQueen = "Slime Queen", skorpSerpent = "Azarathian Serpent", dragon_infernal = "Infernal Dragon", golem = "Kor", wizardBoss = "Wizard Boss", desertBoss = "Bhaa", deerBoss = "Fhanhorn", voidSerpent = "Void Serpent"}
  local BossSpawns = {slimeKing = "slime_king_spawn", slimeQueen = "slime_queen_spawn", golem = "golem_spawn", desertBoss = "bhaa_spawn", deerBoss = "fhanhorn_spawn", skorpSerpent = "serpent_spawn", wizardBoss = "wizard_boss_spawn", voidSerpent = "void_serpent_spawn", dragon_infernal = "dragon_infernal_spawn"}
  local MobOverrides = {None = "None", slime = "Slime", skeletonPirate = "Skeleton Pirate", crab = "Angry Crab", rockMimic = "Rock Mimic", wizardLizard = "Wizard Lizard", skorp = "Skorp", magmaBlob = "Magma Blob", magmaGolem = "Magma Golem", voidDog = "Void Hound", buffalkor = "Buffalkor"}
  local WeaponPriority = {"reaperScythe", "cursedHammer", "divineDao", "captainsRapier", "iceHammer", "swordRuby", "spikeCactus", "cutlass"}
  local WeaponAnims = {reaperScythe = {"rbxassetid://5328169716", "rbxassetid://5328168543"}, cursedHammer = {"rbxassetid://5065710449", "rbxassetid://5085834028"}, divineDao = {"rbxassetid://5328169716", "rbxassetid://5328168543"}, captainsRapier = {"rbxassetid://5328169716", "rbxassetid://5328168543"}, iceHammer = {"rbxassetid://5065710449", "rbxassetid://5085834028"}, swordRuby = {"rbxassetid://5328169716", "rbxassetid://5328168543"}, spikeCactus = {"rbxassetid://4947108314", "rbxassetid://4947108314"}, cutlass = {"rbxassetid://5328169716", "rbxassetid://5328168543"}}
  local DefaultAnims = {"rbxassetid://5065710449", "rbxassetid://5085834028"}
  -- Display name to internal id. The eight originals are confirmed ids; the
  -- rest are the Light and Heavy Melee lists from the Islands wiki, and their
  -- ids are inferred from the pattern the confirmed ones establish
  -- (swordRuby, spikeCactus). That pattern is not reliable - iceHammer is
  -- "Frost Hammer" and follows no rule at all - so resolveWeapon below falls
  -- back to matching the name against what is actually in your inventory. An
  -- id guessed wrong still equips the right tool as long as you own it.
  local WeaponDisplay = {
   ["Best"] = "Best",
   -- confirmed
   ["Reaper Scythe"] = "reaperScythe", ["Cursed Hammer"] = "cursedHammer",
   ["Divine Dao"] = "divineDao", ["Captain's Rapier"] = "captainsRapier",
   ["Cactus Spike"] = "spikeCactus", ["Frost Hammer"] = "iceHammer",
   ["Ruby Sword"] = "swordRuby", ["Cutlass"] = "cutlass",
   -- light melee, from the wiki
   ["Wooden Sword"] = "swordWood", ["Stone Sword"] = "swordStone",
   ["Iron Sword"] = "swordIron", ["Aquamarine Sword"] = "swordAquamarine",
   ["Diamond Great Sword"] = "swordDiamondGreat", ["Frost Sword"] = "swordFrost",
   ["Rageblade"] = "rageblade", ["Serpent's Hook"] = "serpentsHook",
   ["Jolly Dagger"] = "jollyDagger", ["Noxious Stinger"] = "noxiousStinger",
   -- heavy melee, from the wiki
   ["Wooden Mallet"] = "malletWood", ["Granite Hammer"] = "hammerGranite",
   ["Iron War Axe"] = "axeWarIron", ["Gilded Steel Hammer"] = "hammerGildedSteel",
   ["Diamond War Hammer"] = "hammerWarDiamond", ["Obsidian Greatsword"] = "swordObsidian",
   ["Kong's Axe"] = "kongsAxe", ["The Dragonslayer"] = "dragonslayer",
   ["Pumpkin Hammer"] = "hammerPumpkin", ["Antler Hammer"] = "hammerAntler",
   ["Infernal Hammer"] = "hammerInfernal", ["Trout's Fury"] = "troutsFury",
   ["Serpent's Bane"] = "serpentsBane",
  }

  local WeaponOptions = {"Best"}
  for name in pairs(WeaponDisplay) do
   if name ~= "Best" then table.insert(WeaponOptions, name) end
  end
  table.sort(WeaponOptions, function(a, b)
   if a == "Best" then return true end
   if b == "Best" then return false end
   return a < b
  end)

  -- Exact id first, then a loosened match on the display name: lowercased with
  -- every separator and apostrophe stripped, compared both ways so "The
  -- Dragonslayer" finds a tool called "dragonSlayer" or "TheDragonslayer".
  local function normaliseName(s)
   return (tostring(s):lower():gsub("[^%a]", ""))
  end

  local function resolveWeapon(id, display)
   local char = LP.Character
   local backpack = LP:FindFirstChild("Backpack")
   local function look(name)
    if not name then return nil end
    if char and char:FindFirstChild(name) then return name end
    if backpack and backpack:FindFirstChild(name) then return name end
    return nil
   end

   local hit = look(id)
   if hit then return hit end

   local wantId, wantName = normaliseName(id), normaliseName(display or "")
   for _, holder in ipairs({char, backpack}) do
    if holder then
     for _, t in ipairs(holder:GetChildren()) do
      if t:IsA("Tool") then
       local n = normaliseName(t.Name)
       if n == wantId or (wantName ~= "" and n == wantName) then return t.Name end
      end
     end
    end
   end
   return nil
  end

  local selMob, selBoss, selWeapon = "None", "None", "Best"
  local selWeaponLabel = "Best"
  -- hoverTrim adjusts the per-target hover offsets below rather than replacing
  -- them: the old slider wrote to a variable nothing read, so Hover Height did
  -- nothing at all, while the real offsets stayed hardcoded per boss. Those
  -- values are tuned (slimeQueen sits lower than golem), so they are kept as
  -- the base and this shifts all of them together.
  local hoverTrim = 0
  local attackRate = 2
  local farmOn, spawnOn = false, false
  local farmGen, spawnGen = 0, 0
  local noclipConns, noclipParts = {}, {}
  local animTracks, animObjs = {}, {}

  local function stopNoclip()
   for _, c in ipairs(noclipConns) do pcall(function() c:Disconnect() end) end
   noclipConns = {}
   noclipParts = {}
  end
  local function startNoclip()
   stopNoclip()
   local function grab(char)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
     if v:IsA("BasePart") then v.CanCollide = false table.insert(noclipParts, v) end
    end
   end
   grab(LP.Character)
   table.insert(noclipConns, LP.CharacterAdded:Connect(function(c) task.wait(0.5) noclipParts = {} grab(c) end))
   table.insert(noclipConns, RunService.Stepped:Connect(function()
    for i = 1, #noclipParts do
     local v = noclipParts[i]
     if v and v.Parent and v.CanCollide then v.CanCollide = false end
    end
   end))
  end

  local cmb = col:AddSection({Name = "Combat", Collapsible = true})

  local mobNames, mobMap = {}, {}
  for _, m in ipairs({"slime", "skeletonPirate", "crab", "buffalkor", "rockMimic", "wizardLizard", "skorp", "magmaBlob", "magmaGolem", "voidDog"}) do
   local d = MobOverrides[m] or niceName(m)
   table.insert(mobNames, d)
   mobMap[d] = m
  end
  table.sort(mobNames)
  table.insert(mobNames, 1, "None")
  mobMap["None"] = "None"

  local bossNames, bossMap = {}, {}
  for _, b in ipairs({"None", "slimeKing", "slimeQueen", "skorpSerpent", "wizardBoss", "golem", "deerBoss", "voidSerpent", "desertBoss", "dragon_infernal"}) do
   local d = BossOverrides[b] or niceName(b)
   table.insert(bossNames, d)
   bossMap[d] = b
  end

  -- One target list, not two. Two dropdowns meant two ways to say "None" and a
  -- silent rule that boss wins over mob, so picking a boss while a mob was
  -- still set in the other box did something you could not see. Target Type
  -- switches which list the single dropdown holds, and switching it clears the
  -- other kind, which is what having one selection actually means.
  local targetType = "Mob"
  local targetDropdown

  local function targetOptions()
   return targetType == "Boss" and bossNames or mobNames
  end

  cmb:AddDropdown({Name = "Target Type", Options = {"Mob", "Boss"}, Default = "Mob", Flag = autoFlag("farm"), Callback = function(v)
   targetType = v
   selMob, selBoss = "None", "None"
   pcall(function() targetDropdown:Refresh(targetOptions(), true) end)
  end})

  targetDropdown = cmb:AddDropdown({Name = "Target", Options = mobNames, Default = "None", Search = true, Flag = autoFlag("farm"), Callback = function(v)
   if targetType == "Boss" then
    selBoss = bossMap[v] or "None"
    selMob = "None"
   else
    selMob = mobMap[v] or "None"
    selBoss = "None"
   end
  end})

  cmb:AddDropdown({Name = "Select Weapon", Options = WeaponOptions, Default = "Best", Search = true, Flag = autoFlag("farm"), Callback = function(v)
   selWeapon = WeaponDisplay[v] or "Best"
   selWeaponLabel = v
  end})

  -- Auto Spawn is not a feature you run on its own - it exists to keep a boss
  -- alive for Auto Farm to hit. So it stopped being a top-level toggle and
  -- became a setting inside Auto Farm's gear, which is also where it can be
  -- read alongside the target it depends on.
  local function setAutoSpawn(value)
   spawnOn = value
   if not value then return end
   spawnGen = spawnGen + 1
   local gen = spawnGen
   task.spawn(function()
    while spawnOn and gen == spawnGen do
     pcall(function()
      local hrp = myRoot()
      if not hrp then return end
      if selBoss == "None" then return end
      local entities = (WS:FindFirstChild("WildernessIsland") and WS.WildernessIsland:FindFirstChild("Entities")) or WS:FindFirstChild("Entities")
      if entities then
       for _, e in ipairs(entities:GetChildren()) do
        local h = e:FindFirstChild("Humanoid")
        if h and h.Health > 0 then
         local ln = e.Name:lower()
         if ln:find(selBoss:lower()) then return end
        end
       end
      end
      local spawnName = BossSpawns[selBoss]
      if not spawnName then return end
      local spawnPart
      local prefabs = WS:FindFirstChild("spawnPrefabs")
      local trig = prefabs and prefabs:FindFirstChild("WildEventTriggers")
      spawnPart = trig and trig:FindFirstChild(spawnName)
      if not spawnPart then
       for _, v in ipairs(WS:GetDescendants()) do
        if v.Name == spawnName and v:IsA("BasePart") then spawnPart = v break end
       end
      end
      if spawnPart and spawnPart:IsA("BasePart") then
       local prompt = spawnPart:FindFirstChildOfClass("ProximityPrompt", true)
       if prompt and prompt.Enabled then
        flyToBlocking(hrp, spawnPart.Position + Vector3.new(0, 3, 0))
        if typeof(fireproximityprompt) == "function" then
         fireproximityprompt(prompt)
        else
         local old = prompt.HoldDuration
         prompt.HoldDuration = 0
         prompt:InputHoldBegin()
         prompt:InputHoldEnd()
         prompt.HoldDuration = old
        end
        task.wait(0.3)
       end
      end
     end)
     task.wait(0.15)
    end
   end)
  end

  -- Hover Height was a loose slider sitting below the toggle it belongs to, so
  -- it read as a separate feature. It is a setting of Auto Farm and nothing
  -- else, so it lives in Auto Farm's gear now - same pattern as Run Items.
  cmb:AddToggle({Name = "Auto Farm", Default = false, Tooltip = "Equips your best weapon, flies under the selected mob or boss and attacks it continuously. Enables noclip while running.", Flag = autoFlag("farm"),
   Options = {
    {Type = "slider", Name = "Hover Trim", Min = -20, Max = 20, Increment = 1, Default = 0, ValueName = " st",
     Callback = function(v) hoverTrim = v end},
    {Type = "slider", Name = "Attacks / sec", Min = 1, Max = 10, Increment = 1, Default = 2, ValueName = "/s",
     Callback = function(v) attackRate = math.max(v, 1) end},
    {Type = "toggle", Name = "Auto Spawn Boss", Default = false,
     Callback = function(v) setAutoSpawn(v) end},
   },
   Callback = function(value)
   farmOn = value
   if not value then
    stopNoclip()
    for _, t in ipairs(animTracks) do pcall(function() t:Stop() t:Destroy() end) end
    animTracks = {}
    for _, a in ipairs(animObjs) do pcall(function() a:Destroy() end) end
    animObjs = {}
    local hrp = myRoot()
    if hrp then
     local bv = hrp:FindFirstChild("PrizFarmBV")
     if bv then bv:Destroy() end
    end
    updateNotification("Auto Farm", "Disabled", 2)
    return
   end
   farmGen = farmGen + 1
   local gen = farmGen
   startNoclip()
   updateNotification("Auto Farm", "Enabled", 2)
   task.spawn(function()
    local lastAttack = 0
    local curIds = {}
    local function loadAnims(id1, id2)
     if curIds[1] == id1 and curIds[2] == id2 and animTracks[1] then return end
     local hum = LP.Character and LP.Character:FindFirstChild("Humanoid")
     if not hum then return end
     for _, t in ipairs(animTracks) do pcall(function() t:Stop() t:Destroy() end) end
     animTracks = {}
     for _, a in ipairs(animObjs) do pcall(function() a:Destroy() end) end
     animObjs = {}
     for _, id in ipairs({id1, id2}) do
      local a = Instance.new("Animation")
      a.AnimationId = id
      table.insert(animObjs, a)
      table.insert(animTracks, hum:LoadAnimation(a))
     end
     curIds = {id1, id2}
    end
    while farmOn and gen == farmGen do
     pcall(function()
      local char = LP.Character
      local hrp = char and char:FindFirstChild("HumanoidRootPart")
      local targetName = (selMob ~= "None" and selMob) or (selBoss ~= "None" and selBoss)
      if not (hrp and targetName) then return end
      local backpack = LP:FindFirstChild("Backpack")
      local bestWeapon
      if selWeapon ~= "Best" then
       bestWeapon = resolveWeapon(selWeapon, selWeaponLabel)
      end
      if not bestWeapon then
       for _, n in ipairs(WeaponPriority) do
        if (char and char:FindFirstChild(n)) or (backpack and backpack:FindFirstChild(n)) then bestWeapon = n break end
       end
      end
      if bestWeapon then
       local equipped = char:FindFirstChildWhichIsA("Tool")
       if not equipped or equipped.Name ~= bestWeapon then
        local tool = backpack and backpack:FindFirstChild(bestWeapon)
        local hum = char:FindFirstChild("Humanoid")
        if tool and hum then hum:EquipTool(tool) end
       end
      end
      local anims = (bestWeapon and WeaponAnims[bestWeapon]) or DefaultAnims
      local bv = hrp:FindFirstChild("PrizFarmBV")
      if not bv then
       bv = Instance.new("BodyVelocity")
       bv.Name = "PrizFarmBV"
       bv.Velocity = Vector3.zero
       bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
       bv.Parent = hrp
      end
      local entities = (WS:FindFirstChild("WildernessIsland") and WS.WildernessIsland:FindFirstChild("Entities")) or WS:FindFirstChild("Entities")
      local target, best = nil, math.huge
      if entities then
       local tLow = targetName:lower()
       local searchName = (BossOverrides[targetName] or MobOverrides[targetName] or targetName):lower()
       local isMob = MobOverrides[targetName] ~= nil
       local hp0 = hrp.Position
       for i, v in ipairs(entities:GetChildren()) do
        local hp = v:FindFirstChild("HumanoidRootPart")
        local hum2 = v:FindFirstChild("Humanoid")
        if hp and hum2 and hum2.Health > 0 then
         local vn = v.Name:lower()
         local clean = vn:gsub("_", "")
         local match = vn:find(tLow, 1, true) or vn:find(searchName, 1, true) or clean:find(tLow, 1, true)
         if match and isMob then
          for bossKey in pairs(BossOverrides) do
           if bossKey ~= "None" then
            local bk = bossKey:lower()
            if (vn:find(bk, 1, true) or clean:find(bk, 1, true)) and not tLow:find(bk, 1, true) then match = false break end
           end
          end
         end
         if match then
          local d = hp.Position - hp0
          local dsq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
          if dsq < best then best = dsq target = v end
         end
        end
        if i % 25 == 0 then task.wait() end
       end
      end
      if target and target:FindFirstChild("HumanoidRootPart") then
       local tp = target.HumanoidRootPart
       local yo = (targetName == "slimeQueen" and -14) or (targetName == "slimeKing" and -13.5) or (targetName == "golem" and -15) or (targetName == "magmaGolem" and -9) or (targetName == "magmaBlob" and -7) or -11
       flyTo(hrp, tp.Position + Vector3.new(0, yo + hoverTrim, 0))
       if tick() - lastAttack > (1 / attackRate) and R_Combat then
        lastAttack = tick()
        task.spawn(function()
         pcall(function()
          loadAnims(anims[1], anims[2])
          if animTracks[1] then animTracks[1]:Play() end
          if animTracks[2] then animTracks[2]:Play() end
          R_Combat:FireServer("6164F31F-7600-48E7-866C-7229FEA1FDE1", {{
           hitUnit = target,
           IucpoZdgwp = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nefmmgivC",
          }})
         end)
        end)
       end
      end
     end)
     task.wait(0.1)
    end
   end)
  end})

 end

 local function BuildFarm(col)
  local SeedCrops = {"onion", "carrot", "wheat", "berryBush", "blackberryBush", "blueberryBush", "cactus", "candyCane", "chiliPepper", "cranberryBush", "crystallineIvy", "dragonfruit", "grape", "melon", "optuntia", "pineapple", "potato", "pumpkin", "radish", "raspberryBush", "rice", "seaweed", "spinach", "spirit", "starfruit", "strawberryBush", "tomato", "vineStem", "voidParasite"}
  local seedNames, seedMap, cropSet = {}, {}, {}
  for _, c in ipairs(SeedCrops) do
   local d = niceName(c)
   table.insert(seedNames, d)
   seedMap[d] = c
   cropSet[c] = true
  end
  table.sort(seedNames)

  local ActualTreeNames = {"treeMaple1", "treeMaple2", "treeBirch1", "treeBirch2", "treePine1", "treeSpirit1", "treeSpirit2", "treeHickory1", "treeHickory2", "treeCherryBlossom", "treeLemon", "treeOrange", "treePlum", "treeApple", "treeAvocado", "treeCoconut"}
  local ActualTreeSet = {}
  for _, n in ipairs(ActualTreeNames) do ActualTreeSet[n] = true end
  local TreeMatchers = {
   ["Oak"] = function(name) return not ActualTreeSet[name] end,
   ["Cherry Blossom"] = function(name) return name:find("CherryBlossom", 1, true) end,
   ["Apple"] = function(name) return name:find("Apple", 1, true) end,
   ["Orange"] = function(name) return name:find("Orange", 1, true) end,
   ["Lemon"] = function(name) return name:find("Lemon", 1, true) end,
   ["Plum"] = function(name) return name:find("Plum", 1, true) end,
   ["Avocado"] = function(name) return name:find("Avocado", 1, true) end,
   ["Coconut"] = function(name) return name:find("Coconut", 1, true) end,
   ["Birch"] = function(name) return name:find("Birch", 1, true) end,
   ["Pine"] = function(name) return name:find("Pine", 1, true) end,
   ["Maple"] = function(name) return name:find("Maple", 1, true) end,
   ["Hickory"] = function(name) return name:find("Hickory", 1, true) end,
   ["Spirit"] = function(name) return name:find("Spirit", 1, true) end,
  }
  local function buildActiveMatchers(selected)
   local isAll, matchers = false, {}
   if type(selected) == "table" then
    isAll = table.find(selected, "All") ~= nil
    if not isAll then
     for _, t in ipairs(selected) do
      if t ~= "All" and TreeMatchers[t] then matchers[t] = TreeMatchers[t] end
     end
    end
   else
    isAll = selected == "All"
    if not isAll and TreeMatchers[selected] then matchers[selected] = TreeMatchers[selected] end
   end
   return isAll, matchers
  end
  local function getTreePosition(v)
   if v:IsA("Model") then
    if v.PrimaryPart then return v.PrimaryPart.Position end
    local part = v:FindFirstChildWhichIsA("BasePart")
    if part then return part.Position end
   elseif v:IsA("BasePart") then
    return v.Position
   end
  end

  local harvestCrops, harvestOn, harvestGen = {}, false, 0
  local plantSeed, plantOn, plantGen, plantRadius = "wheat", false, 0, 15
  local eatOn, eatGen, eatDelay = false, 0, 0.1
  local autoWaterOn, waterDelay = false, 1
  local plowOn, plowGen, plowRadius = false, 0, 10
  local treeOn, treeGen, treeTypes, treeFly, treeRadius = false, 0, {"All"}, false, 50

  local function startHarvest()
   harvestOn = true
   harvestGen = harvestGen + 1
   local gen = harvestGen
   task.spawn(function()
    while harvestOn and gen == harvestGen do
     pcall(function()
      local hrp = myRoot()
      if not (hrp and R_Harvest) then return end
      local radSq = S.harvestRadius ^ 2
      local isAll = (#selectedCrops == 0)
      local want = {}
      for _, id in ipairs(selectedCrops) do want[id] = true end
      for _, folder in ipairs(blocksFolders()) do
       for i, block in ipairs(folder:GetChildren()) do
        if not harvestOn then break end
        local ok = isAll and cropSet[block.Name] or want[block.Name]
        if ok then
         local bp = block:IsA("BasePart") and block or block:FindFirstChildWhichIsA("BasePart")
         if bp then
          local d = bp.Position - hrp.Position
          if d.X * d.X + d.Y * d.Y + d.Z * d.Z < radSq then
           pcall(function()
            R_Harvest:InvokeServer({
             dZnpyRtxna = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nsDahbvdxZludavlcoipDDMYasPlcm",
             player = LP,
             model = block,
            })
           end)
          end
         end
        end
        if i % 60 == 0 then task.wait() end
       end
      end
     end)
     task.wait(0.2)
    end
   end)
  end

  local function startPlant()
   plantOn = true
   plantGen = plantGen + 1
   local gen = plantGen
   plantSeed = selectedCrops[1] or plantSeed
   task.spawn(function()
    while plantOn and gen == plantGen do
     pcall(function()
      local hrp = myRoot()
      if not (hrp and R_Place) then return end
      plantSeed = selectedCrops[1] or plantSeed
      local isBerry = tostring(plantSeed):find("erryBush") ~= nil
      local targetBlock = isBerry and "grass" or "soil"
      local r = plantRadius * 2
      local parts = partsInBox(hrp.Position, Vector3.new(r, r, r))
      local up = Vector3.new(0, 3, 0)
      for i, v in ipairs(parts) do
       if not plantOn then break end
       if v.Name == targetBlock then
        local above = partsInBox(v.Position + up, Vector3.new(1, 1, 1))
        local filled = false
        for _, a in ipairs(above) do
         local p = a.Parent
         if p and (p.Name == "Blocks" or (p.Parent and p.Parent.Name == "Blocks")) then filled = true break end
        end
        if not filled then
         task.spawn(function()
          pcall(function()
           R_Place:InvokeServer({
            uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU",
            cframe = CFrame.new(v.Position + up),
            blockType = plantSeed,
            upperBlock = false,
           })
          end)
         end)
        end
       end
       if i % 30 == 0 then task.wait() end
      end
     end)
     task.wait(0.25)
    end
   end)
  end

  UI.cropDrop = UI.farmCrop:AddDropdown({Name = "Select Crops", Options = cropList, Default = {}, MultiSelect = true, Search = true, SelectAll = true, Tooltip = "Which crops to harvest, replant and walk to.", Flag = autoFlag("farm"), Callback = function(chosen)
   selectedCrops = {}
   for _, nm in ipairs(chosen or {}) do table.insert(selectedCrops, cropToId(nm)) end
   plantSeed = selectedCrops[1] or plantSeed
  end})
  UI.farmCrop:AddSlider({Name = "Farm Radius", Min = 5, Max = 50, Increment = 1, Default = 15, ValueName = "studs", Tooltip = "Shared radius for Auto Harvest, Replace Crops and Plow.", Flag = autoFlag("farm"), Callback = function(v)
   plantRadius = v
   plowRadius = v
  end})

  local startPlow
  local farmActionState = {}
  local selectedFarmActions = {}
  local FARM_ACTIONS = {"Auto Harvest", "Replace Crops", "Plow Farmland", "Plant in Radius", "Auto Walk to Crops"}
  local function setFarmAction(name, on)
   if name == "Auto Harvest" then
    if on then startHarvest() else harvestOn = false end
   elseif name == "Replace Crops" then
    if on then startPlant() else plantOn = false end
   elseif name == "Plow Farmland" then
    if on then startPlow() else plowOn = false end
   elseif name == "Plant in Radius" then
    if on then runPlantRadius() end
   elseif name == "Auto Walk to Crops" then
    setAutoWalkCrops(on)
   end
  end
  local function stopAllFarmActions()
   for _, a in ipairs(FARM_ACTIONS) do
    if farmActionState[a] then
     farmActionState[a] = false
     setFarmAction(a, false)
    end
   end
  end
  UI.farmActions = UI.farmCrop:AddDropdown({Name = "Farm Actions", Options = FARM_ACTIONS, Default = {}, MultiSelect = true, Search = true, SelectAll = true, Tooltip = "Pick which farming actions to run, then flip Perform Farm Actions.", Flag = autoFlag("farm"), Callback = function(chosen)
   selectedFarmActions = chosen or {}
  end})
  -- The Farm Panel. Every knob these five actions actually read was scattered
  -- across the tab as a loose slider, or worse, was a hardcoded constant with
  -- no control at all - the harvest radius was plantRadius x 3, which meant the
  -- Plant Radius slider silently moved the harvest range too. They are gathered
  -- here, on the toggle that runs them, with the one that was doing double duty
  -- split into its two jobs.
  UI.farmPerform = UI.farmCrop:AddToggle({Name = "Farm Actions", Default = false, Tooltip = "Runs every action picked above. Turn off to stop them all.", Flag = autoFlag("farm"),
   Options = {
    {Type = "slider", Name = "Harvest Radius", Min = 5, Max = 150, Increment = 5, Default = 45, ValueName = " st",
     Callback = function(v) S.harvestRadius = v end},
    {Type = "slider", Name = "Plant Radius", Min = 5, Max = 60, Increment = 1, Default = 15, ValueName = " st",
     Callback = function(v) plantRadius = v end},
    {Type = "slider", Name = "Plow Radius", Min = 5, Max = 60, Increment = 1, Default = 10, ValueName = " st",
     Callback = function(v) plowRadius = v end},
    {Type = "slider", Name = "Walk Speed", Min = 16, Max = 120, Increment = 4, Default = 32, ValueName = " st/s",
     Callback = function(v) S.farmWalkSpeed = v end},
    {Type = "toggle", Name = "Noclip While Walking", Default = true,
     Callback = function(v) S.farmWalkNoclip = v end},
   },
   Callback = function(value)
   if not value then
    stopAllFarmActions()
    updateNotification("Farming", "Stopped", 2)
    return
   end
   local set = {}
   for _, a in ipairs(selectedFarmActions) do set[a] = true end
   for _, a in ipairs(FARM_ACTIONS) do
    if set[a] then
     farmActionState[a] = true
     setFarmAction(a, true)
    end
   end
   updateNotification("Farming", "Running selected actions", 2)
  end})

  UI.farmEat:AddToggle({Name = "Auto Eat", Default = false, Tooltip = "Repeatedly eats whatever tool you are holding.", Flag = autoFlag("farm"), Callback = function(value)
   eatOn = value
   if not value then return end
   eatGen = eatGen + 1
   local gen = eatGen
   task.spawn(function()
    while eatOn and gen == eatGen do
     pcall(function()
      local char = LP.Character
      local tool = char and char:FindFirstChildWhichIsA("Tool")
      if tool and R_Eat then R_Eat:InvokeServer({tool = tool}) end
     end)
     task.wait(eatDelay)
    end
   end)
  end})
  UI.farmEat:AddSlider({Name = "Eat Delay", Min = 0.01, Max = 60, Increment = 0.01, Default = 0.1, ValueName = "s", Flag = autoFlag("farm"), Callback = function(v)
   eatDelay = v
  end})

  local fl = col:AddSection({Name = "Flowers", Collapsible = true})
  local selectedFlowers = {}
  local function flowerNames()
   local names, seen = {}, {}
   for _, folder in ipairs(blocksFolders()) do
    for _, b in ipairs(folder:GetChildren()) do
     if b.Name:lower():find("flower", 1, true) and not seen[b.Name] then
      seen[b.Name] = true
      table.insert(names, b.Name)
     end
    end
   end
   table.sort(names)
   if #names == 0 then table.insert(names, "flower") end
   return names
  end
  local function collectFlowers()
   local isAll = (#selectedFlowers == 0)
   local want = {}
   for _, n in ipairs(selectedFlowers) do
    if n == "All" then isAll = true else want[n] = true end
   end
   local out = {}
   for _, folder in ipairs(blocksFolders()) do
    for _, b in ipairs(folder:GetChildren()) do
     local isFlower = b.Name:lower():find("flower", 1, true)
     if isFlower and (isAll or want[b.Name]) then table.insert(out, b) end
    end
   end
   return out
  end
  local function waterAll()
   if not R_Water then return end
   local n = 0
   for _, block in ipairs(collectFlowers()) do
    n = n + 1
    task.spawn(function() pcall(function() R_Water:InvokeServer({block = block}) end) end)
    if n % 20 == 0 then task.wait() end
   end
  end
  UI.flowerDrop = fl:AddDropdown({Name = "Flowers", Options = flowerNames(), OnRefresh = flowerNames, Default = {}, MultiSelect = true, Search = true, SelectAll = true, Tooltip = "Only these flower types get watered.", Flag = autoFlag("farm"), Callback = function(chosen)
   selectedFlowers = chosen or {}
  end})
  fl:AddToggle({Name = "Auto Water", Default = false, Tooltip = "Waters every selected flower type on a timer. Set the delay in the gear.", Flag = autoFlag("farm"), Options = {{Type = "slider", Name = "Delay (s)", Min = 1, Max = 600, Default = 1, Callback = function(v) waterDelay = v end}}, Callback = function(value)
   autoWaterOn = value
   if not value then return end
   task.spawn(function()
    while autoWaterOn do
     waterAll()
     task.wait(waterDelay)
    end
   end)
  end})

  startPlow = function()
   plowOn = true
   plowGen = plowGen + 1
   local gen = plowGen
   task.spawn(function()
    while plowOn and gen == plowGen do
     pcall(function()
      local hrp = myRoot()
      if not (hrp and R_Plow) then return end
      local r = plowRadius * 2
      local parts = partsInBox(hrp.Position, Vector3.new(r, r, r))
      for i, v in ipairs(parts) do
       if not plowOn then break end
       if v.Name == "grass" then
        task.spawn(function() pcall(function() R_Plow:InvokeServer({block = v}) end) end)
       end
       if i % 30 == 0 then task.wait() end
      end
     end)
     task.wait(0.3)
    end
   end)
  end


  local tr = col:AddSection({Name = "Trees", Collapsible = true})
  tr:AddDropdown({Name = "Tree Type", Options = {"All", "Oak", "Birch", "Pine", "Maple", "Hickory", "Spirit", "Cherry Blossom", "Apple", "Orange", "Lemon", "Plum", "Avocado", "Coconut"}, Default = {"All"}, MultiSelect = true, Search = true, SelectAll = true, Flag = autoFlag("farm"), Callback = function(v)
   treeTypes = v or {"All"}
  end})
  tr:AddToggle({Name = "Tree Aura", Default = false, Tooltip = "Chops the nearest matching tree in radius over and over. Set radius and fly-to in the gear.", Flag = autoFlag("farm"), Options = {
   {Type = "toggle", Name = "Fly to Tree", Default = false, Callback = function(v) treeFly = v end},
   {Type = "slider", Name = "Radius", Min = 5, Max = 500, Default = 50, Callback = function(v) treeRadius = v end},
  }, Callback = function(value)
   treeOn = value
   if not value then return end
   treeGen = treeGen + 1
   local gen = treeGen
   task.spawn(function()
    while treeOn and gen == treeGen do
     pcall(function()
      local hrp = myRoot()
      if not hrp then return end
      local hrpPos = hrp.Position
      local radiusSq = treeRadius * treeRadius
      local isAll, activeMatchers = buildActiveMatchers(treeTypes)
      local closestDist, closestTree, hitPart = math.huge, nil, nil
      for _, folder in ipairs(blocksFolders()) do
       for i, v in ipairs(folder:GetChildren()) do
        if v.Name:find("tree", 1, true) then
         local isMatch = isAll
         if not isMatch then
          for _, matcher in pairs(activeMatchers) do if matcher(v.Name) then isMatch = true break end end
         end
         if isMatch then
          local pos = getTreePosition(v)
          if pos then
           local d = pos - hrpPos
           local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
           if distSq < radiusSq and distSq < closestDist then
            local trunk = v:FindFirstChild("trunk") or v:FindFirstChild("MeshPart") or v:FindFirstChildWhichIsA("BasePart") or (v:IsA("BasePart") and v)
            if trunk then closestDist = distSq closestTree = v hitPart = trunk end
           end
          end
         end
        end
        if i % 60 == 0 then task.wait() end
       end
      end
      if closestTree and hitPart then
       if treeFly then
        local treePos = getTreePosition(closestTree)
        if treePos then flyTo(hrp, treePos + Vector3.new(0, 3, 0)) end
       end
       hitBlock(closestTree, hitPart)
      end
     end)
     task.wait(0.1)
    end
   end)
  end})
 end

 local function BuildMisc(colA, colB)
  local nukeOn, nukeGen = false, 0
  local nukeSet, nukeAll = {grass = true}, false
  local nukeTarget = nil
  local nk = colB:AddSection({Name = "Demolish Blocks", Collapsible = true})
  local function islandBlockNames()
   local names, seen = {"All"}, {All = true}
   for _, folder in ipairs(blocksFolders()) do
    for _, b in ipairs(folder:GetChildren()) do
     if not seen[b.Name] then
      seen[b.Name] = true
      table.insert(names, b.Name)
     end
    end
   end
   table.sort(names)
   return names
  end
  UI.nukeDrop = nk:AddDropdown({Name = "Blocks", Options = islandBlockNames(), OnRefresh = islandBlockNames, Default = {"All"}, MultiSelect = true, Search = true, SelectAll = true, Flag = autoFlag("set"), Callback = function(v)
   nukeAll = false
   nukeSet = {}
   if not v or #v == 0 then nukeAll = true return end
   for _, b in ipairs(v) do
    if b == "All" then nukeAll = true nukeSet = {} break end
    nukeSet[b] = true
   end
  end})
  local nukeRecord = nil

  local function blocknuke()
   if not nukeOn then return end
   local char = LP.Character
   if not char then return end
   local hrp = char:FindFirstChild("HumanoidRootPart")
   if not hrp then return end
   local hrpPos = hrp.Position
   local target = nukeTarget
   if target and target.Parent then hitBlock(target, target) return end
   local blocks = getblocksfolder()
   if not blocks then return end
   local closestBlock, closestDistSq = nil, 900
   local regionSize = Vector3.new(60, 60, 60)
   local found
   local ok = pcall(function()
    found = WS:FindPartsInRegion3(Region3.new(hrpPos - regionSize / 2, hrpPos + regionSize / 2), nil, 500)
   end)
   if not ok or not found then found = partsInBox(hrpPos, regionSize) end
   for i, v in ipairs(found) do
    if v.Parent == blocks then
     if nukeAll or nukeSet[v.Name] then
      local d = v.Position - hrpPos
      local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
      if distSq < closestDistSq then closestDistSq = distSq closestBlock = v end
     end
    end
    if i % 50 == 0 then task.wait() end
   end
   if closestBlock then
    nukeTarget = closestBlock
    -- Captured here and nowhere else. The moment the hit lands the part is
    -- destroyed and its name and CFrame go with it, so a record taken after
    -- the fact would have nothing to read.
    if nukeRecord then
     table.insert(nukeRecord, {blockType = closestBlock.Name, cframe = closestBlock.CFrame})
    end
    task.defer(function() hitBlock(closestBlock, closestBlock) end)
   else
    nukeTarget = nil
   end
  end
  nk:AddToggle({Name = "Demolish Blocks", Default = false, Tooltip = "Repeatedly breaks the nearest selected block type around you. Turning it off offers an undo that rebuilds what the run destroyed.", Flag = autoFlag("set"), Callback = function(value)
   nukeOn = value
   nukeTarget = nil
   if not value then
    -- One entry for the run, not one per block. "Undo" here means "put back
    -- what that did", and what it did was a run.
    local run = nukeRecord
    nukeRecord = nil
    if run and #run > 0 then
     local undoEntry = Undo.push({
      label  = "Demolished " .. #run .. " blocks",
      detail = "Places each block type back at the exact CFrame it was broken at.",
      run = function()
       local done, failed = 0, 0
       -- newest first, so a stack comes back in the order it came down
       for i = #run, 1, -1 do
        local b = run[i]
        local ok = pcall(function()
         R_Place:InvokeServer({
          uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU",
          cframe = b.cframe,
          blockType = b.blockType,
          upperBlock = false,
         })
        end)
        if ok then done = done + 1 else failed = failed + 1 end
        if done % 20 == 0 then task.wait() else task.wait(0.03) end
       end
       return done, failed,
        "Blocks only go back if you still have them in your inventory - the server checks."
      end,
     })
     Undo.offer("Demolish", "Broke " .. #run .. " blocks this run.", undoEntry)
    end
    return
   end
   nukeRecord = {}
   nukeGen = nukeGen + 1
   local gen = nukeGen
   task.spawn(function()
    while nukeOn and gen == nukeGen do
     pcall(blocknuke)
     task.wait(0.35)
    end
   end)
  end})
 end

 BuildCombat(farmL)
 BuildFarm(farmR)
 BuildMisc(setL, setR)
end

BuildPookiePort(UI.farmL, UI.farmR, UI.setL, UI.setR)

-- ---------------------------------------------------------------------------
-- Undo and diagnostics, on the Settings tab.
--
-- The transparency slider and click-through toggle that used to head this
-- section are gone: 38% is the value worth having, so it is simply the default
-- and there is nothing left to tune.
--
-- Built inside a function rather than a do-block: locals in a do-block still
-- come out of the enclosing chunk's 200 registers, and this file is at the cap.
-- ---------------------------------------------------------------------------
;(function()
 local IF = UI.setR:AddSection({Name = "Undo & Diagnostics"})

 -- Undo history. The toast offers the last action; this is everything still
 -- undoable, oldest at the bottom, each with its own button - because the one
 -- you regret is not always the one you just did.
 local undoPanel = Duvome:MakeSidePanel({ Name = "Undo History", Width = 230, Height = 320, Side = "right" })
 local undoBody = undoPanel:Container()

 local function drawUndo()
  for _, c in ipairs(undoBody:GetChildren()) do
   if c:IsA("GuiObject") then c:Destroy() end
  end
  if #Undo.stack == 0 then
   local empty = Instance.new("TextLabel")
   empty.BackgroundTransparency = 1
   empty.Font = Enum.Font.Gotham
   empty.TextSize = 12
   empty.TextColor3 = Color3.fromRGB(150, 145, 165)
   empty.TextWrapped = true
   empty.TextXAlignment = Enum.TextXAlignment.Left
   empty.Text = "Nothing to undo yet.\n\nDestructive actions record how to reverse themselves and show up here."
   empty.Size = UDim2.new(1, 0, 0, 70)
   empty.Parent = undoBody
   return
  end
  for _, entry in ipairs(Undo.stack) do
   local row = Instance.new("Frame")
   row.BackgroundTransparency = 1
   row.Size = UDim2.new(1, 0, 0, 52)
   row.Parent = undoBody

   local lbl = Instance.new("TextLabel")
   lbl.BackgroundTransparency = 1
   lbl.Font = Enum.Font.GothamBold
   lbl.TextSize = 12
   lbl.TextColor3 = Color3.fromRGB(228, 222, 240)
   lbl.TextXAlignment = Enum.TextXAlignment.Left
   lbl.TextWrapped = true
   lbl.Text = entry.at .. "  " .. entry.label
   lbl.Size = UDim2.new(1, -54, 1, 0)
   lbl.Parent = row

   local btn = Instance.new("TextButton")
   btn.Text = "Undo"
   btn.Font = Enum.Font.GothamBold
   btn.TextSize = 11
   btn.TextColor3 = Color3.fromRGB(235, 235, 240)
   btn.BorderSizePixel = 0
   btn.AutoButtonColor = false
   btn.Size = UDim2.new(0, 48, 0, 22)
   btn.Position = UDim2.new(1, -48, 0.5, -11)
   btn.Parent = row
   Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
   btn.MouseButton1Click:Connect(function() Undo.run(entry) end)
  end
 end

 table.insert(Undo.listeners, function() task.defer(drawUndo) end)
 drawUndo()

 IF:AddToggle({
  Name = "Undo History", Default = false,
  Tooltip = "Opens the list of actions that can still be reversed.",
  Callback = function(v)
   pcall(function() if v then undoPanel:Show() else undoPanel:Hide() end end)
  end,
 })

 -- Self test. Everything here breaks when the game updates, and each check is
 -- something a feature silently depends on - a missing remote looks exactly
 -- like a dead button.
 IF:AddButton({
  Name = "Self Test",
  Tooltip = "Checks that the remotes, folders and web sources every feature needs are still there.",
  Callback = function()
   task.spawn(function()
    local lines, bad = {}, 0
    local function check(what, fn)
     local ok, res = pcall(fn)
     local pass = ok and res ~= false and res ~= nil
     if not pass then bad = bad + 1 end
     table.insert(lines, (pass and "OK   " or "FAIL ") .. what)
    end

    local function managed()
     return RS:WaitForChild("rbxts_include", 5):WaitForChild("node_modules", 5)
      :WaitForChild("@rbxts", 5):WaitForChild("net", 5):WaitForChild("out", 5)
      :WaitForChild("_NetManaged", 5)
    end

    check("net root", function() return managed() ~= nil end)
    for _, name in ipairs({
     "CLIENT_BLOCK_HIT_REQUEST", "CLIENT_BLOCK_PLACE_REQUEST",
     "CLIENT_HARVEST_CROP_REQUEST", "CLIENT_WATER_BLOCK",
     "CLIENT_CHEST_TRANSACTION", "TransactionBankBalance",
     "CLIENT_CHANGE_ISLAND_ACCESS_LEVEL",
    }) do
     check("remote " .. name, function()
      return managed():FindFirstChild(name) ~= nil
     end)
    end
    check("vending remotes", function()
     local m = managed()
     return m:FindFirstChild("deGzdggahhjo/yeuvbxxakbeqDdlofjxFiBwq") ~= nil
      and m:FindFirstChild("deGzdggahhjo/rLPziSaNkyol") ~= nil
    end)
    check("Islands folder", function() return WS:FindFirstChild("Islands") ~= nil end)
    check("backpack", function() return LP:FindFirstChild("Backpack") ~= nil end)
    check("vendings visible", function() return #findVendings() >= 0 end)
    check("key source", function()
     -- literal, not KEY_URL: that local is declared further down the file, so
     -- naming it here would compile to a nil global and the check would pass
     -- by reading nothing
     local body = game:HttpGet("https://pastebin.com/raw/KrqauyVU?t=" .. tostring(os.time()))
     return type(body) == "string" and #body > 0 and not body:find("<html", 1, true)
    end)
    check("price source", function()
     local body = game:HttpGet("https://pastebin.com/raw/LQVhtvEe?t=" .. tostring(os.time()))
     return type(body) == "string" and #body > 0 and not body:find("<html", 1, true)
    end)

    local head = bad == 0
     and ("All " .. #lines .. " checks passed.")
     or (bad .. " of " .. #lines .. " checks FAILED.")
    setOutput("Self Test", head .. "\n\n" .. table.concat(lines, "\n"))
    updateNotification(bad == 0 and "Self Test" or "Self Test Failed", head, 6)
   end)
  end,
 })
end)()

pcall(function()
 Duvome:AddWatch("Fly", function() return flying end)
 Duvome:AddWatch("Noclip", function() return noclipEnabled end)
 Duvome:AddWatch("Infinite Jump", function() return infiniteJumpEnabled end)
 Duvome:AddWatch("Player ESP", function() return espEnabled end)
 Duvome:AddWatch("Vending ESP", function() return vendingESPEnabled end)
 Duvome:AddWatch("Sniper", function() return sniperEnabled end)
 Duvome:AddWatch("Openables", function() return S.cauldronEnabled end)
 Duvome:AddWatch("Auto-Restock", function() return autoRestockEnabled end)
 Duvome:AddWatch("Bank to Vendings", function() return S.b2vOn end)
 Duvome:AddWatch("Restock Loop", function() return S.restockLoopOn end)
 Duvome:AddWatch("Radius", function() return useRadiusLimit and (vendingRadius .. " studs") or false end)
 Duvome:AddWatch("Selected", function() local n = #selectedFavorites return n > 0 and (n .. " vendings") or false end)
end)

-- off by default; it is opt-in from the menu rather than always on screen
pcall(function() Duvome:SetWatchVisible(false) end)
pcall(function() Duvome:AddWatch("Build", function() return PIHD_BUILD end) end)
pcall(function()
	Duvome:MakeNotification({
		Name = "Priz's Islands Hub",
		Content = "Build " .. PIHD_BUILD,
		Time = 6,
	})
end)

pcall(function() Duvome:Init() end)

end

local KEY_URL = "https://pastebin.com/raw/KrqauyVU"
local validKeys = {}
pcall(function()
	local raw = tostring(game:HttpGet(KEY_URL))
	-- A deleted or private paste answers with an HTML error page rather than
	-- an error, and every line of that markup was being added as a key. The
	-- list then looked full, so the fallback never ran, and no real key could
	-- match anything in it - which is exactly what a dead key link looks like
	-- from the outside.
	if raw:find("<!DOCTYPE", 1, true) or raw:find("<html", 1, true) then
		return
	end
	for line in raw:gmatch("[^\r\n]+") do
		local key = line:match("^%s*(.-)%s*$")
		-- a key is one word; anything with markup in it is not one
		if key ~= "" and not key:find("[<>]") and #key <= 128 then
			table.insert(validKeys, key)
		end
	end
end)
if #validKeys == 0 then
	warn("[Priz Hub] Could not read the key list from " .. KEY_URL)
	validKeys = { "FreeIslandsKeyForNow" }
end

Duvome.MakeKeyUI({
	Title    = "Priz Hub",
	Subtitle = "Islands Key System",
	Note     = "Join discord.gg/NuUzrrNaJz to get your key",
	Key      = validKeys,
	SaveKey  = true,
	FileName = "PrizIslandsHub_Key",
}, StartHub)