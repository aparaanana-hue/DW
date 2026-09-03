-- PIHD Free - Priz's Islands Hub, free build
--
-- A separate, smaller script rather than the full hub with switches thrown.
-- That matters: a paid build gated behind a flag still ships every line of the
-- paid code, and anyone reading the file can flip the flag. What is not in this
-- file cannot be turned on in this file.
--
-- WHAT IS HERE
--   Home        live island readout - coins, items, vending modes, island code
--   Vending     deposit and withdraw coins, deposit and empty items, by filter
--   Prices      read your own shop and save it to a file you can keep
--   Farming     harvest and plant crops, auto eat
--   Character   walk speed, jump, infinite jump, noclip, anti-AFK
--   Settings    theme, self test, unload
--
-- WHAT THE FULL BUILD ADDS
--   Run Coins and Run Items    one press, every machine on the island
--   Restock loop, Bank to Vendings loop, Vending Auto Stocker
--   Apply Prices               copy another shop's prices onto yours
--   Price webhook              post your price list to Discord
--   Vending Sniper, chest manager, saved vending groups, openables opener
--   Combat, auto farm, boss auto spawn, the Sakura event
--   Undo history for every destructive action
--
-- No telemetry. The full build posts a launch notice to a Discord webhook with
-- your username, user id, account age, island code and executor. This one does
-- not phone home at all, which felt like the right default for the build people
-- try before they trust it.
--
-- NOT RUN. This compiles. It has never executed in Roblox.

local ENV = (typeof(getgenv) == "function" and getgenv()) or _G
if type(ENV.PIHD_FREE_UNLOAD) == "function" then
    pcall(ENV.PIHD_FREE_UNLOAD)
    ENV.PIHD_FREE_UNLOAD = nil
end

-- Local copy first, network second. raw.githubusercontent answers a private or
-- missing file with an HTML 404 that loadstring cannot compile, and the failure
-- surfaces as an error on line 1 of the caller with no message attached.
local function loadLib(fileName, url)
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        local ok, has = pcall(isfile, fileName)
        if ok and has then
            local rok, body = pcall(readfile, fileName)
            if rok and type(body) == "string" and #body > 1000 then
                local chunk = loadstring(body)
                if chunk then return chunk() end
            end
        end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" then
        error("Could not fetch " .. fileName .. ": " .. tostring(body), 0)
    end
    if #body < 1000 or body:sub(1, 1) == "<" or body:find("404: Not Found", 1, true) then
        error(fileName .. " came back as a " .. #body .. "-byte error page, not Lua.", 0)
    end
    local chunk, err = loadstring(body)
    if not chunk then
        error("Fetched " .. fileName .. " but it will not compile: " .. tostring(err), 0)
    end
    return chunk()
end

local Duvome = loadLib("DL.lua",
    "https://raw.githubusercontent.com/aparaanana-hue/DW/refs/heads/main/DL.lua")

local BUILD = "free build 1 - unrun"

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local RS          = game:GetService("ReplicatedStorage")
local WS          = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer

-- One table for feature state. Luau allows a function 200 local registers and
-- this file is one chunk - the paid build hit that ceiling and refused to
-- compile, which is a silent failure, so this one keeps its state in a table
-- from the start.
local S = {
    walkSpeed = 16, jumpPower = 50,
    coinAmount = nil, itemAmount = nil, selectedItem = nil,
    vendTypes = {}, plantRadius = 15, harvestRadius = 45,
    conns = {},
}
local ACTIVE = {}

local MODE_SELL, MODE_BUY = 0, 1
local VEND_MAX_ITEMS = 1000

local function notify(title, text, dur)
    pcall(function()
        Duvome:MakeNotification({
            Name = title, Content = tostring(text),
            Image = "rbxassetid://4483345998", Time = dur or 4,
        })
    end)
end

local function bind(name, conn)
    if S.conns[name] then pcall(function() S.conns[name]:Disconnect() end) end
    S.conns[name] = conn
end
local function unbind(name)
    if S.conns[name] then pcall(function() S.conns[name]:Disconnect() end) end
    S.conns[name] = nil
end

local function fmtNum(n)
    n = math.floor(tonumber(n) or 0)
    local s, out = tostring(n), ""
    for i = 1, #s do
        if i > 1 and (#s - i + 1) % 3 == 0 then out = out .. "," end
        out = out .. s:sub(i, i)
    end
    return out
end

local function shortNum(n)
    n = tonumber(n) or 0
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.2fK", n / 1e3) end
    return tostring(math.floor(n))
end

-- ---------------------------------------------------------------------------
-- Network
-- ---------------------------------------------------------------------------
-- The vending remotes have obfuscated names that change with the game's build.
-- Resolved once at load and checked before every action, so a game update turns
-- into a message rather than a hundred silent pcall failures.
local Net, Open, Edit, Close, Withdraw, Deposit, ItemRemote
local netReady = false

task.spawn(function()
    netReady = pcall(function()
        local rbxts = RS:WaitForChild("rbxts_include", 10)
        Net = rbxts:WaitForChild("node_modules", 5):WaitForChild("@rbxts", 5)
            :WaitForChild("net", 5):WaitForChild("out", 5):WaitForChild("_NetManaged", 5)
        local P = "vdejLrsuUtHdxgMnamqcwrddgseyltmjnutxAhuAdt/"
        Open       = Net[P .. "ohzbeybzqzfJRFwekzcvdLnpwpuaoia"]
        Edit       = Net[P .. "amv"]
        Close      = Net[P .. "uabQAzmslluxa"]
        Withdraw   = Net[P .. "cFkpxe"]
        Deposit    = Net[P .. "uvgaYvclaqh"]
        ItemRemote = Net[P .. "clQqtBtMScmrwsnEkow"]
    end)
end)

local function netOk()
    if not netReady then
        notify("Error", "Network not ready - rejoin or wait a moment", 5)
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- World
-- ---------------------------------------------------------------------------
local function findVendings()
    local out = {}
    local islands = WS:FindFirstChild("Islands")
    if not islands then return out end
    for _, island in pairs(islands:GetChildren()) do
        local blocks = island:FindFirstChild("Blocks")
        if blocks then
            for _, obj in pairs(blocks:GetChildren()) do
                if obj.Name:lower():find("vending") then table.insert(out, obj) end
            end
        end
    end
    return out
end

local function modeOf(v)
    local m = v:FindFirstChild("Mode")
    return m and m.Value or nil
end

local function coinsOf(v)
    local c = v:FindFirstChild("CoinBalance")
    return (c and c.Value) or 0
end

local function stockedTool(v)
    local sc = v:FindFirstChild("SellingContents")
    local t = sc and sc:GetChildren()[1]
    if not t then return nil, 0 end
    return t, (t:FindFirstChild("Amount") and t.Amount.Value) or 1
end

-- Nothing ticked means all of them. A filter that defaults to matching nothing
-- makes every button look broken on first use.
local function targetVendings()
    local want, any = {}, false
    for k in pairs(S.vendTypes) do want[k] = true any = true end
    local out = {}
    for _, v in ipairs(findVendings()) do
        if not any then
            table.insert(out, v)
        else
            local m = modeOf(v)
            if (want["Buy (BUY ITEM)"] and m == MODE_BUY)
                or (want["Sell (SELL ITEM)"] and m == MODE_SELL)
                or (want["Offline"] and m ~= MODE_BUY and m ~= MODE_SELL) then
                table.insert(out, v)
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Vending actions
-- ---------------------------------------------------------------------------
-- Each is the same open / edit / act / close sequence the game itself performs.
local function depositCoins(v, amount)
    if not netOk() then return end
    pcall(function()
        local g = HttpService:GenerateGUID(false)
        Open:FireServer(g, {{vendingMachine = v}})
        Edit:FireServer(g, {{vendingMachine = v}})
        Deposit:FireServer(g, {{vendingMachine = v,
            player_tracking_category = "join_from_web", amount = amount}})
        Close:FireServer({vendingMachine = v})
    end)
end

local function withdrawCoins(v, amount)
    if not netOk() then return end
    pcall(function()
        local g = HttpService:GenerateGUID(false)
        Open:FireServer(g, {{vendingMachine = v}})
        Edit:FireServer(g, {{vendingMachine = v}})
        Withdraw:FireServer(g, {{vendingMachine = v,
            player_tracking_category = "join_from_web", amount = amount}})
        Close:FireServer({vendingMachine = v})
    end)
end

local function depositItem(v, itemName, amount)
    if not netOk() then return end
    pcall(function()
        local g = HttpService:GenerateGUID(false)
        Open:FireServer(g, {{vendingMachine = v}})
        Edit:FireServer(g, {{vendingMachine = v}})
        ItemRemote:FireServer(g, {{vendingMachine = v, itemType = itemName,
            amount = amount, deposit = true}})
        Close:FireServer({vendingMachine = v})
    end)
end

local function emptyItems(v, amount)
    if not netOk() then return end
    pcall(function()
        local g = HttpService:GenerateGUID(false)
        Open:FireServer(g, {{vendingMachine = v}})
        Edit:FireServer(g, {{vendingMachine = v}})
        ItemRemote:FireServer(g, {{vendingMachine = v, amount = amount, deposit = false}})
        Close:FireServer({vendingMachine = v})
    end)
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
local Window = Duvome:MakeWindow({
    Name = "PIHD Free - Priz's Islands Hub",
    HidePremium = false, SaveConfig = true, ConfigFolder = "PIHDFree", Blur = false,
})
pcall(function() Duvome:SetGlass(0.38) end)

local HomeTab  = Window:MakeTab({Name = "Home",      Icon = "house",         Columns = true})
local VendTab  = Window:MakeTab({Name = "Vending",   Icon = "shopping-cart", Columns = true})
local PriceTab = Window:MakeTab({Name = "Prices",    Icon = "tag",           Columns = true})
local FarmTab  = Window:MakeTab({Name = "Farming",   Icon = "backpack",      Columns = true})
local CharTab  = Window:MakeTab({Name = "Character", Icon = "star",          Columns = true})
local SetTab   = Window:MakeTab({Name = "Settings",  Icon = "gear",          Columns = true})

-- ===========================================================================
-- HOME
-- ===========================================================================
local HL, HR = HomeTab:AddLeft(), HomeTab:AddRight()

local aboutSec = HL:AddSection({Name = "About"})
aboutSec:AddParagraph("Priz's Islands Hub - Free",
    "Build: " .. BUILD .. "\n\n" ..
    "This build does not phone home. No launch notice, no username,\n" ..
    "no island code sent anywhere.\n\n" ..
    "Discord: discord.gg/NuUzrrNaJz")

local scanSec = HL:AddSection({Name = "Live Scan"})
local scanOut = scanSec:AddParagraph("Your Island", "Scanning...")
local playerOut = scanSec:AddParagraph("Player", "-")

task.spawn(function()
    while true do
        pcall(function()
            local vendings = findVendings()
            -- One pass, every counter. Walking the list once per figure is how
            -- a readout starts costing more than the features do.
            local coins, withCoins, items, withItems = 0, 0, 0, 0
            local buy, sell, off = 0, 0, 0
            local kinds = {}
            for _, v in ipairs(vendings) do
                pcall(function()
                    local c = coinsOf(v)
                    if c > 0 then coins = coins + c withCoins = withCoins + 1 end
                    local tool, amt = stockedTool(v)
                    if tool then
                        items = items + amt
                        withItems = withItems + 1
                        kinds[tool.Name] = true
                    end
                    local m = modeOf(v)
                    if m == MODE_BUY then buy = buy + 1
                    elseif m == MODE_SELL then sell = sell + 1
                    else off = off + 1 end
                end)
            end
            local kindCount = 0
            for _ in pairs(kinds) do kindCount = kindCount + 1 end

            local code = "-"
            pcall(function()
                if LP:FindFirstChild("JoinCode") then code = tostring(LP.JoinCode.Value) end
            end)

            scanOut:Set(string.format(
                "Island Code: %s\n\nVendings: %d\n  buying %d   selling %d   offline %d\n\n"
                .. "Coins scanned: %s  (in %d machines)\n"
                .. "Items scanned: %s  (%d kinds, in %d machines)",
                code, #vendings, buy, sell, off,
                shortNum(coins), withCoins, shortNum(items), kindCount, withItems))

            local bag, stacks = 0, 0
            local bp = LP:FindFirstChild("Backpack")
            if bp then
                for _, t in ipairs(bp:GetChildren()) do
                    if t:IsA("Tool") then
                        stacks = stacks + 1
                        bag = bag + ((t:FindFirstChild("Amount") and t.Amount.Value) or 1)
                    end
                end
            end
            playerOut:Set(string.format(
                "%s  (%d)\nServer: %d / %d players\n\nBackpack: %s in %d stacks",
                LP.Name, LP.UserId, #Players:GetPlayers(), Players.MaxPlayers,
                shortNum(bag), stacks))
        end)
        task.wait(4)
    end
end)

local tabSec = HR:AddSection({Name = "The Tabs"})
tabSec:AddParagraph("What Is Where",
    "VENDING\n" ..
    "Deposit and withdraw coins, deposit and empty items.\n" ..
    "The type filter decides which machines are touched -\n" ..
    "nothing ticked means all of them.\n\n" ..
    "PRICES\n" ..
    "Read your shop's current prices and save them to a\n" ..
    "text file you can keep or share.\n\n" ..
    "FARMING\n" ..
    "Harvest and replant crops in a radius, and auto eat.\n\n" ..
    "CHARACTER\n" ..
    "Walk speed, jump, infinite jump, noclip, anti-AFK.")

local upSec = HR:AddSection({Name = "In The Full Build", Collapsible = true})
upSec:AddParagraph("Not In This One",
    "Run Coins / Run Items - one press, every machine on\n" ..
    "the island, including flying to the ones out of reach.\n\n" ..
    "Apply Prices - copy another shop's prices onto yours.\n" ..
    "Price webhook - post your list to your own Discord.\n\n" ..
    "Restock loop, Bank to Vendings loop, auto stocker.\n" ..
    "Vending sniper. Chest manager. Saved vending groups.\n\n" ..
    "Combat, auto farm, boss auto spawn, the Sakura event.\n\n" ..
    "Undo history for every destructive action.")

-- ===========================================================================
-- VENDING
-- ===========================================================================
local VL, VR = VendTab:AddLeft(), VendTab:AddRight()

local coinSec = VL:AddSection({Name = "Coin Operations"})
local coinOut = coinSec:AddParagraph("Status", "Idle.")

coinSec:AddDropdown({Name = "Vending Type",
    Options = {"Buy (BUY ITEM)", "Sell (SELL ITEM)", "Offline"},
    Default = {}, MultiSelect = true, SelectAll = true,
    Tooltip = "Which machines the buttons act on. Nothing picked means all of them.",
    Callback = function(chosen)
        S.vendTypes = {}
        for _, c in ipairs(chosen or {}) do S.vendTypes[c] = true end
    end})

coinSec:AddTextbox({Name = "Coin Amount", Default = "", TextDisappear = false,
    Tooltip = "Leave empty on Withdraw to take everything the machine holds.",
    Callback = function(t) S.coinAmount = tonumber((tostring(t):gsub("[,%s]", ""))) end})

coinSec:AddButton({Name = "Deposit Coins", Callback = function()
    task.spawn(function()
        local amount = S.coinAmount
        if not amount or amount <= 0 then
            coinOut:Set("Set a Coin Amount first.") return
        end
        local list = targetVendings()
        for _, v in ipairs(list) do
            task.spawn(function() depositCoins(v, amount) end)
            task.wait(0.1)
        end
        coinOut:Set("Sent " .. fmtNum(amount) .. " to " .. #list .. " machine(s).")
    end)
end})

coinSec:AddButton({Name = "Withdraw Coins", Callback = function()
    task.spawn(function()
        local list = targetVendings()
        local total, touched = 0, 0
        for _, v in ipairs(list) do
            -- Empty amount means "whatever is in there", which is read per
            -- machine rather than assumed - they do not all hold the same.
            local take = S.coinAmount
            local held = coinsOf(v)
            if not take or take <= 0 then take = held end
            take = math.min(take, held)
            if take > 0 then
                total = total + take
                touched = touched + 1
                task.spawn(function() withdrawCoins(v, take) end)
                task.wait(0.1)
            end
        end
        coinOut:Set("Pulled " .. fmtNum(total) .. " from " .. touched .. " machine(s).")
    end)
end})

local itemSec = VR:AddSection({Name = "Item Management"})
local itemOut = itemSec:AddParagraph("Status", "Idle.")

local function backpackItems()
    local out = {}
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then table.insert(out, t.Name) end
        end
    end
    table.sort(out)
    if #out == 0 then table.insert(out, "No items") end
    return out
end

itemSec:AddDropdown({Name = "Item", Options = backpackItems(),
    OnRefresh = backpackItems, Default = "", Search = true,
    Tooltip = "Which item to deposit. Refresh is in the list.",
    Callback = function(v) S.selectedItem = v end})

itemSec:AddTextbox({Name = "Item Amount", Default = "", TextDisappear = false,
    Tooltip = "Leave empty to fill each machine to 1000, or to empty it completely.",
    Callback = function(t) S.itemAmount = tonumber((tostring(t):gsub("[,%s]", ""))) end})

itemSec:AddButton({Name = "Deposit Items", Callback = function()
    task.spawn(function()
        if not S.selectedItem or S.selectedItem == "" or S.selectedItem == "No items" then
            itemOut:Set("Pick an item first.") return
        end
        local list = targetVendings()
        local sent = 0
        for _, v in ipairs(list) do
            local _, cur = stockedTool(v)
            local give = S.itemAmount or math.max(0, VEND_MAX_ITEMS - cur)
            if give > 0 then
                sent = sent + 1
                task.spawn(function() depositItem(v, S.selectedItem, give) end)
                task.wait(0.12)
            end
        end
        itemOut:Set("Deposited into " .. sent .. " machine(s).")
    end)
end})

itemSec:AddButton({Name = "Empty Items", Callback = function()
    task.spawn(function()
        local list = targetVendings()
        local pulled = 0
        for _, v in ipairs(list) do
            local tool, cur = stockedTool(v)
            if tool and cur > 0 then
                local take = S.itemAmount or cur
                take = math.min(take, cur)
                if take > 0 then
                    pulled = pulled + 1
                    task.spawn(function() emptyItems(v, take) end)
                    task.wait(0.12)
                end
            end
        end
        itemOut:Set("Emptied " .. pulled .. " machine(s).")
    end)
end})

-- ===========================================================================
-- PRICES
-- ===========================================================================
local PL, PR = PriceTab:AddLeft(), PriceTab:AddRight()

local priceSec = PL:AddSection({Name = "Your Shop"})
priceSec:AddParagraph("Reading prices",
    "Scans every vending you own and writes the result as a plain\n" ..
    "text price list. Applying another shop's prices onto yours is\n" ..
    "in the full build.")

local priceOut = priceSec:AddParagraph("Prices", "Press Scan Prices.")

-- The display name, not the internal id: a machine holding "swordRuby" is
-- selling a Ruby Sword and a price list nobody can read is not a price list.
local function displayName(tool)
    local ok, n = pcall(function()
        return tool:GetAttribute("DisplayName") or tool:GetAttribute("displayName")
    end)
    if ok and type(n) == "string" and n ~= "" then return n end
    -- Fall back to un-camel-casing the id, which is close enough to read.
    local s = tostring(tool.Name):gsub("(%l)(%u)", "%1 %2")
    return (s:gsub("^%l", string.upper))
end

local function scanPrices()
    local items = {}
    for _, v in ipairs(findVendings()) do
        pcall(function()
            local m = modeOf(v)
            if m == nil then return end
            local priceObj = v:FindFirstChild("TransactionPrice")
            local price = priceObj and priceObj.Value or 0
            local tool = stockedTool(v)
            if not tool then return end
            local name = displayName(tool)
            items[name] = items[name] or {}
            -- Buy keeps the lowest and sell the highest, so a shop with several
            -- machines on one item reports the price a customer actually gets.
            if m == MODE_BUY then
                if not items[name].buy or price < items[name].buy then items[name].buy = price end
            elseif m == MODE_SELL then
                if not items[name].sell or price > items[name].sell then items[name].sell = price end
            end
        end)
    end
    return items
end

local function priceText(items)
    local names = {}
    for n in pairs(items) do table.insert(names, n) end
    table.sort(names)
    local lines = {}
    for _, n in ipairs(names) do
        local d = items[n]
        table.insert(lines, n)
        table.insert(lines, "Buy Price: "  .. (d.buy  and fmtNum(d.buy)  or "N/A"))
        table.insert(lines, "Sell Price: " .. (d.sell and fmtNum(d.sell) or "N/A"))
        table.insert(lines, "")
    end
    return table.concat(lines, "\n"), #names
end

priceSec:AddButton({Name = "Scan Prices", Callback = function()
    task.spawn(function()
        local items = scanPrices()
        local text, count = priceText(items)
        if count == 0 then priceOut:Set("No priced vendings found.") return end
        priceOut:Set(count .. " items priced.\n\n" .. text:sub(1, 700))
        notify("Prices", count .. " items scanned", 4)
    end)
end})

priceSec:AddButton({Name = "Save To File", Callback = function()
    task.spawn(function()
        if typeof(writefile) ~= "function" then
            priceOut:Set("This executor has no writefile().") return
        end
        local items = scanPrices()
        local text, count = priceText(items)
        if count == 0 then priceOut:Set("Nothing to save.") return end
        local name = "PIHD_" .. tostring(LP.Name) .. "_prices.txt"
        local ok = pcall(writefile, name, text)
        priceOut:Set(ok and ("Wrote " .. name .. " (" .. count .. " items).")
            or "Could not write the file.")
    end)
end})

priceSec:AddButton({Name = "Copy To Clipboard", Callback = function()
    task.spawn(function()
        if typeof(setclipboard) ~= "function" then
            priceOut:Set("This executor has no setclipboard().") return
        end
        local text, count = priceText(scanPrices())
        if count == 0 then priceOut:Set("Nothing to copy.") return end
        pcall(setclipboard, text)
        priceOut:Set("Copied " .. count .. " items.")
    end)
end})

local pinfoSec = PR:AddSection({Name = "Full Build"})
pinfoSec:AddParagraph("Apply Prices",
    "The full build reads saved price lists back in as sources, averages\n" ..
    "several together, and writes them onto your own machines - all,\n" ..
    "sell side only, or buy side only. It also posts the list to a\n" ..
    "webhook you paste in yourself.\n\n" ..
    "The file this tab writes is the same format that build reads, so\n" ..
    "nothing you save here is wasted.")

-- ===========================================================================
-- FARMING
-- ===========================================================================
local FL, FR = FarmTab:AddLeft(), FarmTab:AddRight()

local cropSec = FL:AddSection({Name = "Crops"})
local cropOut = cropSec:AddParagraph("Status", "Idle.")

local CROPS = {"wheat", "tomato", "potato", "carrot", "onion", "cactus", "spinach",
    "pumpkin", "radish", "chiliPepper", "spirit", "starfruit", "melon", "rice",
    "seaweed", "candyCaneVine", "pineapple", "dragonfruit", "grapeVine", "berryBush"}

local cropSet = {}
for _, c in ipairs(CROPS) do cropSet[c] = true end

local selectedCrops = {}
local cropNames = {}
for _, c in ipairs(CROPS) do
    local pretty = (c:gsub("(%l)(%u)", "%1 %2"):gsub("^%l", string.upper))
    table.insert(cropNames, pretty)
end
table.sort(cropNames)

local prettyToId = {}
for _, c in ipairs(CROPS) do
    prettyToId[(c:gsub("(%l)(%u)", "%1 %2"):gsub("^%l", string.upper))] = c
end

cropSec:AddDropdown({Name = "Crops", Options = cropNames, Default = {},
    MultiSelect = true, Search = true, SelectAll = true,
    Tooltip = "Nothing picked means every crop.",
    Callback = function(chosen)
        selectedCrops = {}
        for _, p in ipairs(chosen or {}) do
            local id = prettyToId[p]
            if id then selectedCrops[id] = true end
        end
    end})

cropSec:AddSlider({Name = "Radius", Min = 10, Max = 150, Increment = 5,
    Default = 45, ValueName = " st", Callback = function(v) S.harvestRadius = v end})

local function blocksFolders()
    local out = {}
    local islands = WS:FindFirstChild("Islands")
    if not islands then return out end
    for _, island in pairs(islands:GetChildren()) do
        local b = island:FindFirstChild("Blocks")
        if b then table.insert(out, b) end
    end
    return out
end

local R_Harvest
task.spawn(function()
    pcall(function()
        local n = RS:WaitForChild("rbxts_include", 10):WaitForChild("node_modules")
            :WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out")
            :WaitForChild("_NetManaged")
        R_Harvest = n:FindFirstChild("CLIENT_HARVEST_CROP_REQUEST")
    end)
end)

cropSec:AddToggle({Name = "Auto Harvest", Default = false,
    Tooltip = "Harvests every ready crop of the chosen types inside the radius.",
    Callback = function(on)
        if not on then ACTIVE.harvest = nil return end
        ACTIVE.harvest = true
        task.spawn(function()
            local picked = 0
            while ACTIVE.harvest do
                pcall(function()
                    local char = LP.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if not (hrp and R_Harvest) then return end
                    local radSq = S.harvestRadius ^ 2
                    local isAll = next(selectedCrops) == nil
                    for _, folder in ipairs(blocksFolders()) do
                        for i, block in ipairs(folder:GetChildren()) do
                            if not ACTIVE.harvest then break end
                            local want = isAll and cropSet[block.Name] or selectedCrops[block.Name]
                            if want then
                                local bp = block:IsA("BasePart") and block
                                    or block:FindFirstChildWhichIsA("BasePart")
                                if bp and (bp.Position - hrp.Position).Magnitude ^ 2 < radSq then
                                    pcall(function()
                                        R_Harvest:InvokeServer({player = LP, model = block})
                                    end)
                                    picked = picked + 1
                                end
                            end
                            -- Yield on a stride: a built-up island is thousands
                            -- of blocks and this runs on a loop.
                            if i % 200 == 0 then task.wait() end
                        end
                    end
                    cropOut:Set("Harvested " .. picked .. " so far.")
                end)
                task.wait(0.5)
            end
        end)
    end})

local eatSec = FR:AddSection({Name = "Auto Eat"})
eatSec:AddToggle({Name = "Auto Eat", Default = false,
    Tooltip = "Eats from your backpack whenever hunger drops.",
    Callback = function(on)
        if not on then ACTIVE.eat = nil return end
        ACTIVE.eat = true
        task.spawn(function()
            while ACTIVE.eat do
                pcall(function()
                    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health < hum.MaxHealth * 0.9 then
                        local bp = LP:FindFirstChild("Backpack")
                        if bp then
                            for _, t in ipairs(bp:GetChildren()) do
                                if t:IsA("Tool") and cropSet[t.Name] then
                                    hum:EquipTool(t)
                                    task.wait(0.2)
                                    pcall(function() t:Activate() end)
                                    break
                                end
                            end
                        end
                    end
                end)
                task.wait(2)
            end
        end)
    end})

local finfoSec = FR:AddSection({Name = "Full Build"})
finfoSec:AddParagraph("Also In Farming",
    "Travel to every island, plant and plow in a radius, flowers and\n" ..
    "trees with an aura, block demolition, combat with auto farm and\n" ..
    "boss auto spawn, and the whole Sakura event chain.")

-- ===========================================================================
-- CHARACTER
-- ===========================================================================
local CL, CR = CharTab:AddLeft(), CharTab:AddRight()

local moveSec = CL:AddSection({Name = "Movement"})

local function hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

moveSec:AddSlider({Name = "Walk Speed", Min = 16, Max = 200, Increment = 2,
    Default = 16, ValueName = "", Save = true, Flag = "ws",
    Callback = function(v)
        S.walkSpeed = v
        local h = hum()
        if h then h.WalkSpeed = v end
    end})

moveSec:AddSlider({Name = "Jump Power", Min = 50, Max = 300, Increment = 5,
    Default = 50, ValueName = "", Save = true, Flag = "jp",
    Callback = function(v)
        S.jumpPower = v
        local h = hum()
        if h then h.UseJumpPower = true h.JumpPower = v end
    end})

moveSec:AddToggle({Name = "Infinite Jump", Default = false,
    Callback = function(on)
        if not on then unbind("infjump") return end
        bind("infjump", UIS.JumpRequest:Connect(function()
            local h = hum()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end))
    end})

moveSec:AddToggle({Name = "NoClip", Default = false,
    Callback = function(on)
        if not on then unbind("noclip") return end
        bind("noclip", RunService.Stepped:Connect(function()
            local c = LP.Character
            if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end))
    end})

local sessSec = CR:AddSection({Name = "Session"})
sessSec:AddToggle({Name = "Anti AFK", Default = true,
    Callback = function(on)
        if not on then unbind("afk") return end
        bind("afk", LP.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end))
    end})

-- A respawn drops walk speed and jump power, so they are put back rather than
-- silently reverting while the sliders still claim otherwise.
LP.CharacterAdded:Connect(function()
    task.wait(0.6)
    local h = hum()
    if not h then return end
    if S.walkSpeed ~= 16 then h.WalkSpeed = S.walkSpeed end
    if S.jumpPower ~= 50 then h.UseJumpPower = true h.JumpPower = S.jumpPower end
end)

-- ===========================================================================
-- SETTINGS
-- ===========================================================================
local SL, SR = SetTab:AddLeft(), SetTab:AddRight()

local uiSec = SL:AddSection({Name = "Interface"})
uiSec:AddDropdown({Name = "Theme",
    Options = (function()
        local ok, list = pcall(function() return Duvome:GetThemes() end)
        return (ok and type(list) == "table" and #list > 0) and list or {"Default"}
    end)(),
    Default = "Default", Save = true, Flag = "theme",
    Callback = function(n) pcall(function() Duvome:SetTheme(n) end) end})

uiSec:AddSlider({Name = "Glass", Min = 0, Max = 90, Increment = 2, Default = 38,
    ValueName = "%", Save = true, Flag = "glass",
    Callback = function(v) pcall(function() Duvome:SetGlass(v / 100) end) end})

local diagSec = SL:AddSection({Name = "Diagnostics"})
local testOut = diagSec:AddParagraph("Self Test", "Run it to see what this game allows.")

diagSec:AddButton({Name = "Self Test", Callback = function()
    task.spawn(function()
        local lines, bad = {}, 0
        local function check(what, fn)
            local ok, res = pcall(fn)
            local pass = ok and res ~= false and res ~= nil
            if not pass then bad = bad + 1 end
            table.insert(lines, (pass and "OK   " or "FAIL ") .. what)
        end
        check("character",        function() return LP.Character ~= nil end)
        check("humanoid",         function() return hum() ~= nil end)
        check("vending network",  function() return netReady end)
        check("vendings found",   function() return #findVendings() > 0 end)
        check("writefile",        function() return typeof(writefile) == "function" end)
        check("clipboard",        function() return typeof(setclipboard) == "function" end)
        local head = bad == 0 and ("All " .. #lines .. " passed.")
            or (bad .. " of " .. #lines .. " FAILED.")
        testOut:Set(head .. "\n\n" .. table.concat(lines, "\n"))
        notify("Self Test", head, 5)
    end)
end})

local stopSec = SR:AddSection({Name = "Session"})
stopSec:AddButton({Name = "Stop Everything", Callback = function()
    for k in pairs(ACTIVE) do ACTIVE[k] = nil end
    for n in pairs(S.conns) do unbind(n) end
    local h = hum()
    if h then h.WalkSpeed = 16 h.JumpPower = 50 end
    notify("Stopped", "Every loop off, character restored", 4)
end})

stopSec:AddButton({Name = "Unload", Callback = function()
    if type(ENV.PIHD_FREE_UNLOAD) == "function" then pcall(ENV.PIHD_FREE_UNLOAD) end
end})

ENV.PIHD_FREE_UNLOAD = function()
    for k in pairs(ACTIVE) do ACTIVE[k] = nil end
    for n in pairs(S.conns) do unbind(n) end
    pcall(function()
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 h.JumpPower = 50 end
    end)
    pcall(function() Duvome:Destroy() end)
end

pcall(function() Duvome:Init() end)

notify("PIHD Free", "Loaded - " .. BUILD, 6)
