-- ═════════════════════════════════════════════════════════════════════════════
-- DUVOME LIBRARY — FULL FEATURE EXAMPLE
-- Loads the library from the raw URL, then demonstrates every feature.
-- Upload DuvomeLib.lua (the library file) to that raw URL for this to work.
-- ═════════════════════════════════════════════════════════════════════════════

-- The "?t=" is not decoration: raw.githubusercontent is behind a CDN that
-- serves a stale copy for minutes after a push, so without it you can
-- re-execute all day and still get the old library.
local Duvome = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/aparaanana-hue/DW/refs/heads/main/DL.lua"
        .. "?t=" .. tostring(os.time())))()

-- small helper so every interaction gives visible feedback
local function notify(name, content, ntype)
    Duvome:MakeNotification({Name = name, Content = content, Type = ntype, Time = 3})
end

-- ── Window ───────────────────────────────────────────────────────────────────
local Window = Duvome:MakeWindow({
    Name           = "Duvome Demo",
    HidePremium    = true,
    SaveConfig     = true,                 -- enable config save/load
    AutoLoadConfig = false,                -- don't auto-apply saved config on launch
    ConfigFolder   = "DuvomeDemo",         -- folder name for saved configs
    Theme          = "Default",            -- starting theme (Default/Ocean/Crimson/Emerald/Midnight)
    IntroEnabled   = false,
    Blur           = false,                -- background blur off
    BlurSize       = 8,
    IconFont       = "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json",
})

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 1 — CORE ELEMENTS (button, toggle, slider, textbox, label, paragraph)
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "Core", Icon = "house", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    local S1 = L:AddSection({Name = "Buttons & Toggles"})

    S1:AddButton({
        Name = "Click Me",
        Callback = function() notify("Button", "You clicked the button!", "info") end
    })

    S1:AddToggle({
        Name = "Basic Toggle",
        Default = false,
        Flag = "core_toggle",
        Callback = function(v) notify("Toggle", "Now: " .. tostring(v), v and "success" or "warning") end
    })

    S1:AddToggle({
        Name = "Custom Color Toggle",
        Default = true,
        Color = Color3.fromRGB(255, 120, 0),
        Flag = "core_toggle_color",
        Callback = function(v) end
    })

    local S2 = L:AddSection({Name = "Sliders"})

    S2:AddSlider({
        Name = "Volume",
        Min = 0, Max = 100, Default = 50, Increment = 1,
        ValueName = "%",
        Flag = "core_volume",
        Callback = function(v) end
    })

    S2:AddSlider({
        Name = "Walk Speed",
        Min = 16, Max = 300, Default = 16, Increment = 2,
        ValueName = "spd",
        Flag = "core_walkspeed",
        Callback = function(v)
            local char = game.Players.LocalPlayer.Character
            if char and char:FindFirstChildWhichIsA("Humanoid") then
                char:FindFirstChildWhichIsA("Humanoid").WalkSpeed = v
            end
        end
    })

    local S3 = R:AddSection({Name = "Text Input"})

    S3:AddTextbox({
        Name = "Your Name",
        Default = "",
        Flag = "core_name",
        Callback = function(t) notify("Textbox", "You typed: " .. t, "info") end
    })

    S3:AddTextbox({
        Name = "Big Number",
        Default = "1000000",
        Flag = "core_bignum",
        Callback = function(t) end
    })

    local S4 = R:AddSection({Name = "Display"})
    S4:AddLabel("This is a plain label.")
    S4:AddParagraph("Paragraph", "Paragraphs wrap across multiple lines and auto-resize. Try dragging the window's bottom-right corner to resize.")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 2 — DROPDOWNS & SEARCH (single, multi-select, search)
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "Dropdowns", Icon = "list", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    local S1 = L:AddSection({Name = "Single-Select + Search"})
    S1:AddDropdown({
        Name = "Pick One Fruit",
        Options = {"Apple", "Banana", "Cherry", "Mango", "Grape", "Orange", "Kiwi", "Peach", "Plum", "Lemon"},
        Default = "Apple",
        Search = true,                    -- in-dropdown search box
        Flag = "dd_single",
        Callback = function(v) notify("Dropdown", "Picked " .. v, "info") end
    })

    local S2 = L:AddSection({Name = "Multi-Select + Search + Select All"})
    S2:AddDropdown({
        Name = "Pick Many ESP",
        Options = {"Boxes", "Tracers", "Names", "Health", "Distance", "Skeletons", "Chams", "Weapon"},
        Default = {"Boxes"},
        MultiSelect = true,
        Search = true,                    -- in-dropdown search box
        SelectAll = true,                 -- adds Select All / Clear All buttons
        Flag = "dd_multi",
        Callback = function(list)
            notify("Multi", #list .. " selected", "info")
        end
    })
    S2:AddParagraph("Tip", "Type in the search box to filter. Use Select All / Clear All for multi-select.")

    local S3 = R:AddSection({Name = "Search"})
    S3:AddSearch({
        Name = "Filter Items",
        Items = {"Apple", "Banana", "Cherry", "Mango", "Grape", "Orange", "Kiwi"},
        Placeholder = "Type to filter...",
        Callback = function(item) notify("Search", "Selected " .. item, "info") end
    })
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 3 — RANGE SLIDER & ADVANCED SLIDERS
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "Ranges", Icon = "three-sliders-horizontal", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    local S1 = L:AddSection({Name = "Range Slider (two handles)"})
    S1:AddRangeSlider({
        Name = "Weight Range",
        Min = 0, Max = 100,
        DefaultMin = 20, DefaultMax = 80,
        Increment = 1,
        ValueName = "kg",
        Flag = "range_weight",
        Callback = function(mn, mx) end
    })
    S1:AddParagraph("Tip", "Drag either handle. Callback returns both min and max.")

    local S2 = R:AddSection({Name = "Range Slider (custom color)"})
    S2:AddRangeSlider({
        Name = "Price Range",
        Min = 0, Max = 1000,
        DefaultMin = 100, DefaultMax = 750,
        Increment = 25,
        ValueName = "$",
        Color = Color3.fromRGB(80, 220, 120),
        Flag = "range_price",
        Callback = function(mn, mx) end
    })
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 4 — KEYBINDS (press / toggle / hold+repeat) + per-element visibility
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "Keybinds", Icon = "crosshairs", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    local S1 = L:AddSection({Name = "Keybind Modes"})

    S1:AddBind({
        Name = "Press (fires once)",
        Default = Enum.KeyCode.F,
        Mode = "press",
        Flag = "kb_press",
        Callback = function() notify("Press", "Fired once on F", "info") end
    })

    S1:AddBind({
        Name = "Toggle (on/off)",
        Default = Enum.KeyCode.G,
        Mode = "toggle",
        Flag = "kb_toggle",
        Callback = function(state) notify("Toggle Key", "State: " .. tostring(state), state and "success" or "warning") end
    })

    S1:AddBind({
        Name = "Hold + Repeat (0.5s)",
        Default = Enum.KeyCode.H,
        Mode = "hold",
        Interval = 0.5,
        Flag = "kb_hold",
        Callback = function(down) if down then notify("Hold", "Repeating while held...", "info") end end
    })
    S1:AddParagraph("Tip", "Press = once. Toggle = on/off. Hold = repeats every 0.5s while held. Press Backspace while rebinding to clear it.")

    local S2 = R:AddSection({Name = "Conditional Visibility"})
    local hiddenSlider = S2:AddSlider({
        Name = "Hidden Speed",
        Min = 16, Max = 200, Default = 50,
        Flag = "vis_speed",
        Callback = function(v) end
    })
    hiddenSlider:SetVisible(false)

    local hiddenBind = S2:AddBind({
        Name = "Hidden Keybind",
        Default = Enum.KeyCode.K,
        Mode = "press",
        Flag = "vis_key",
        Callback = function() end
    })
    hiddenBind:SetVisible(false)

    S2:AddToggle({
        Name = "Reveal Hidden Controls",
        Default = false,
        Flag = "vis_reveal",
        Callback = function(on)
            hiddenSlider:SetVisible(on)
            hiddenBind:SetVisible(on)
            notify("Visibility", on and "Controls shown" or "Controls hidden", "info")
        end
    })
    S2:AddParagraph("Tip", "The slider and keybind above stay hidden until you flip this toggle (uses :SetVisible).")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 5 — GEAR SETTINGS (working ESP driven by a colorpicker+alpha, toggle, slider, keybind)
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "Gear Settings", Icon = "gear", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    local Players    = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP         = Players.LocalPlayer

    -- ESP state, all driven by the gear popover settings
    local ESP = {
        enabled    = false,
        color      = Color3.fromRGB(255, 0, 80),
        alpha      = 0,           -- 0 = solid, 1 = invisible
        showNames  = true,
        maxDist    = 300,
        highlights = {},          -- player -> {highlight, billboard, nameLbl}
    }

    local function clearESP(plr)
        local h = ESP.highlights[plr]
        if h then
            if h.highlight then h.highlight:Destroy() end
            if h.billboard then h.billboard:Destroy() end
            ESP.highlights[plr] = nil
        end
    end

    local function buildESP(plr)
        local char = plr.Character
        if not char then return end
        clearESP(plr)
        local hl = Instance.new("Highlight")
        hl.FillColor           = ESP.color
        hl.OutlineColor        = ESP.color
        hl.FillTransparency    = 0.5 + (ESP.alpha * 0.5)
        hl.OutlineTransparency = ESP.alpha
        hl.Adornee             = char
        hl.Parent              = char
        local bb, nameLbl
        if ESP.showNames then
            bb = Instance.new("BillboardGui")
            bb.Size        = UDim2.new(0, 100, 0, 20)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Adornee     = char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
            bb.Parent      = char
            nameLbl = Instance.new("TextLabel")
            nameLbl.BackgroundTransparency = 1
            nameLbl.Size                   = UDim2.new(1, 0, 1, 0)
            nameLbl.Font                   = Enum.Font.GothamBold
            nameLbl.TextSize               = 13
            nameLbl.TextColor3             = ESP.color
            nameLbl.TextStrokeTransparency = 0.5
            nameLbl.Text                   = plr.Name
            nameLbl.Parent                 = bb
        end
        ESP.highlights[plr] = {highlight = hl, billboard = bb, nameLbl = nameLbl}
    end

    local function refreshAll()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                if ESP.enabled then buildESP(plr) else clearESP(plr) end
            end
        end
    end

    -- distance cull / spawn loop
    task.spawn(function()
        while true do
            task.wait(0.5)
            if ESP.enabled then
                local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LP then
                        local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if root and myRoot then
                            local dist = (root.Position - myRoot.Position).Magnitude
                            if dist <= ESP.maxDist then
                                if not ESP.highlights[plr] then buildESP(plr) end
                            else
                                if ESP.highlights[plr] then clearESP(plr) end
                            end
                        end
                    end
                end
            end
        end
    end)
    Players.PlayerRemoving:Connect(clearESP)

    local function toggleESP()
        ESP.enabled = not ESP.enabled
        refreshAll()
        notify("ESP", ESP.enabled and "Enabled" or "Disabled", ESP.enabled and "success" or "warning")
    end

    local S1 = L:AddSection({Name = "ESP (working)"})
    S1:AddParagraph("How to", "Turn on ESP, then click the gear icon to set box color + alpha, toggle names, set distance, or bind a key. Changes apply live to player highlights.")
    local espToggle
    espToggle = S1:AddToggle({
        Name = "ESP",
        Default = false,
        Flag = "gear_esp",
        Callback = function(v)
            ESP.enabled = v
            refreshAll()
            notify("ESP", v and "Enabled" or "Disabled", v and "success" or "warning")
        end,
        Options = {
            {Type = "colorpicker", Name = "Box Color", Default = Color3.fromRGB(255, 0, 80), UseAlpha = true,
                Callback = function(c, a)            -- live drag: recolor existing highlights
                    ESP.color = c
                    ESP.alpha = a or 0
                    for _, h in pairs(ESP.highlights) do
                        if h.highlight then
                            h.highlight.FillColor           = c
                            h.highlight.OutlineColor        = c
                            h.highlight.FillTransparency    = 0.5 + (ESP.alpha * 0.5)
                            h.highlight.OutlineTransparency = ESP.alpha
                        end
                        if h.nameLbl then h.nameLbl.TextColor3 = c end
                    end
                end},
            {Type = "toggle", Name = "Show Names", Default = true,
                Callback = function(v) ESP.showNames = v refreshAll() end},
            {Type = "slider", Name = "Max Distance", Min = 50, Max = 2000, Default = 300,
                Callback = function(v) ESP.maxDist = v end},
            {Type = "keybind", Name = "Toggle Key", Default = Enum.KeyCode.RightControl,
                OnPress = function()
                    -- flip the actual toggle so the switch updates AND the callback runs
                    if espToggle and espToggle.Set then
                        espToggle:Set(not ESP.enabled)
                    else
                        ESP.enabled = not ESP.enabled
                        refreshAll()
                    end
                end,
                OnBind = function(k) end},
        }
    })

    local S2 = R:AddSection({Name = "Notes"})
    S2:AddParagraph("Alpha slider", "The 2nd bar under the hue bar is the ALPHA slider. Drag it right = more transparent highlight, left = solid.")
    S2:AddParagraph("Tip", "ESP draws a Highlight on every other player within Max Distance, recolored live by the color picker. Needs at least one other player in the server to see it.")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 6 — NOTIFICATIONS (types, icons, action buttons) + prompt dialog
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "Notifications", Icon = "bell", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    local S1 = L:AddSection({Name = "Types & Icons"})
    S1:AddButton({Name = "Info",    Callback = function() notify("Information", "Blue info notification.", "info") end})
    S1:AddButton({Name = "Success", Callback = function() notify("Success", "Green success notification.", "success") end})
    S1:AddButton({Name = "Warning", Callback = function() notify("Warning", "Yellow warning notification.", "warning") end})
    S1:AddButton({Name = "Error",   Callback = function() notify("Error", "Red error notification.", "error") end})
    S1:AddButton({Name = "Default", Callback = function() notify("Default", "Standard notification.") end})

    local S2 = R:AddSection({Name = "Action Buttons"})
    S2:AddButton({
        Name = "Two-Button Notify",
        Callback = function()
            Duvome:MakeNotification({
                Name = "Confirm Action", Content = "Do you want to proceed?", Type = "info", Time = 10,
                Actions = {
                    {Text = "Yes", Callback = function() notify("Confirmed", "You chose Yes!", "success") end},
                    {Text = "No",  Callback = function() notify("Declined", "You chose No.", "warning") end},
                }
            })
        end
    })
    S2:AddButton({
        Name = "One-Button Notify",
        Callback = function()
            Duvome:MakeNotification({
                Name = "Update Available", Content = "A new version is ready.", Type = "info", Time = 8,
                Actions = { {Text = "Install", Callback = function() notify("Installing", "Started!", "success") end} }
            })
        end
    })

    local S3 = L:AddSection({Name = "Prompt Dialog"})
    S3:AddButton({
        Name = "Open Confirm Dialog",
        Callback = function()
            Duvome:Prompt({
                Title = "Reset Everything",
                Content = "This will wipe all saved settings. Are you sure?",
                Options = {
                    {Text = "Cancel", Callback = function() notify("Cancelled", "No changes made", "warning") end},
                    {Text = "Reset",  Callback = function() notify("Reset", "Everything wiped!", "success") end},
                }
            })
        end
    })
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 7 — THEMES (live switching via SetTheme / GetThemes)
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "Themes", Icon = "bookmark", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    local S1 = L:AddSection({Name = "Switch Theme"})
    S1:AddDropdown({
        Name = "UI Theme",
        Options = Duvome:GetThemes(),
        Default = "Default",
        Flag = "theme_pick",
        Callback = function(name)
            Duvome:SetTheme(name)
            notify("Theme", "Switched to " .. name, "success")
        end
    })
    S1:AddParagraph("Note", "You can also switch themes from the gear icon in the top bar (next to X and -). Both stay in sync with the same SetTheme call.")

    local S3 = L:AddSection({Name = "Custom Accent (SetAccent)"})
    S3:AddParagraph("What", "Pick any color to recolor the whole UI. When you save a config, this custom accent is saved too and re-applies on load.")
    S3:AddColorpicker({
        Name = "UI Accent",
        Default = Color3.fromRGB(120, 80, 255),
        Callback = function(c) Duvome:SetAccent(c) end
    })
    S3:AddButton({
        Name = "Quick Green Accent",
        Callback = function() Duvome:SetAccent(Color3.fromRGB(45, 200, 110)) notify("Accent", "UI set to green", "success") end
    })

    local S2 = R:AddSection({Name = "Config Save/Load"})
    S2:AddParagraph("Pencil panel", "Click the pencil icon at the bottom-left of the window to open the config panel. Type a name, hit Save Config, and it appears under Saved Configs. Your custom accent color is saved with it and restored on load. Drag the panel to snap it to either side, just like the avatar panel.")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB — NEW FEATURES (colorpicker element, watch list, editable slider, tooltips)
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "New Stuff", Icon = "star", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    -- Standalone colorpicker element
    local S1 = L:AddSection({Name = "Standalone Colorpicker"})
    S1:AddParagraph("Try it", "Click the swatch to expand the picker. No gear needed \u{2014} it's its own element.")
    S1:AddColorpicker({
        Name = "Accent Color",
        Default = Color3.fromRGB(120, 80, 255),
        UseAlpha = true,
        Flag = "nf_color",
        Callback = function(c, a) end
    })

    -- Editable slider (click the number to type)
    local S2 = L:AddSection({Name = "Editable Slider"})
    S2:AddParagraph("Try it", "Drag the slider OR click the number on the right and type an exact value.")
    S2:AddSlider({
        Name = "Exact Value",
        Min = 0, Max = 1000, Default = 250, Increment = 1,
        ValueName = "u",
        Flag = "nf_slider",
        Callback = function(v) end
    })

    -- Tooltips
    local S3 = R:AddSection({Name = "Tooltips (hover me)"})
    S3:AddToggle({
        Name = "Hover for Tooltip",
        Default = false,
        Tooltip = "This explains what the toggle does when you hover over it.",
        Flag = "nf_tip_toggle",
        Callback = function(v) end
    })
    S3:AddButton({
        Name = "Hover This Button",
        Tooltip = "Buttons can have tooltips too. Handy for non-obvious features.",
        Callback = function() end
    })

    -- On-screen watch list (features/keybinds overlay)
    local S4 = R:AddSection({Name = "On-Screen Watch List"})
    S4:AddParagraph("What", "A floating list in the top-left shows active features + state. Toggle these and watch it update.")

    local flyOn, godOn = false, false
    S4:AddToggle({Name = "Fly", Default = false, Flag = "nf_fly",
        Callback = function(v) flyOn = v end})
    S4:AddToggle({Name = "God Mode", Default = false, Flag = "nf_god",
        Callback = function(v) godOn = v end})

    -- register watch items (name, state function, optional key)
    Duvome:AddWatch("Fly", function() return flyOn end, Enum.KeyCode.F)
    Duvome:AddWatch("God Mode", function() return godOn end)
    local _fps = 60
    game:GetService("RunService").RenderStepped:Connect(function(dt) _fps = math.floor(1/dt) end)
    Duvome:AddWatch("FPS", function() return _fps .. " fps" end)

    S4:AddToggle({Name = "Show Watch List", Default = true, Flag = "nf_watch",
        Callback = function(v) Duvome:SetWatchVisible(v) end})
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB — LAYOUT & EXTRAS (dividers, collapsible sections, keybind toggles/buttons)
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "Layout", Icon = "layout-fluid", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    -- Dividers between elements
    local S1 = L:AddSection({Name = "Dividers"})
    S1:AddButton({Name = "Button Above Line", Callback = function() end})
    S1:AddDivider()                                   -- themed separator line
    S1:AddButton({Name = "Button Below Line", Callback = function() end})
    S1:AddDivider()
    S1:AddToggle({Name = "Toggle After Divider", Default = false, Callback = function(v) end})

    -- Collapsible section (click the header to fold/unfold)
    local S2 = L:AddSection({Name = "Collapsible Section", Collapsible = true})
    S2:AddParagraph("Fold me", "This whole section starts collapsed. Click the section header to expand or fold it.")
    S2:AddToggle({Name = "Hidden Toggle", Default = false, Callback = function(v) end})
    S2:AddSlider({Name = "Hidden Slider", Min = 0, Max = 100, Default = 50, Callback = function(v) end})

    -- Toggle & button with an inline keybind (ShowKeybind)
    local S3 = R:AddSection({Name = "Elements With Keybinds"})
    S3:AddParagraph("What", "Set ShowKeybind = true to attach a rebindable key box directly to a toggle or button.")
    S3:AddToggle({
        Name = "Aimbot",
        Default = false,
        ShowKeybind = true,                            -- adds a keybind box to the toggle
        Flag = "lay_aimbot",
        Callback = function(v) notify("Aimbot", v and "ON" or "OFF", v and "success" or "warning") end
    })
    S3:AddButton({
        Name = "Trigger Action",
        ShowKeybind = true,                            -- adds a keybind box to the button
        Callback = function() notify("Action", "Triggered!", "info") end
    })

    -- Auto-column placement (AddAuto picks left/right automatically)
    local S4 = R:AddSection({Name = "Auto Layout"})
    S4:AddParagraph("AddAuto", "Instead of AddLeft/AddRight, AddAuto alternates columns for you automatically.")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 8 — PLAYER UTILITIES (real working examples)
-- ══════════════════════════════════════════════════════════════════════════════
do
    local Tab = Window:MakeTab({Name = "Player", Icon = "user", Columns = true})
    local L, R = Tab:AddLeft(), Tab:AddRight()

    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer

    local S1 = L:AddSection({Name = "Movement"})

    local infJumpOn = false
    S1:AddToggle({
        Name = "Infinite Jump",
        Default = false,
        Flag = "plr_infjump",
        Callback = function(v) infJumpOn = v end
    })
    game:GetService("UserInputService").JumpRequest:Connect(function()
        if infJumpOn and LP.Character and LP.Character:FindFirstChildWhichIsA("Humanoid") then
            LP.Character:FindFirstChildWhichIsA("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

    S1:AddSlider({
        Name = "Jump Power",
        Min = 50, Max = 500, Default = 50, Increment = 10,
        ValueName = "pwr",
        Flag = "plr_jumppower",
        Callback = function(v)
            local hum = LP.Character and LP.Character:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.JumpPower = v hum.UseJumpPower = true end
        end
    })

    local S2 = R:AddSection({Name = "Info"})
    S2:AddButton({
        Name = "Copy User ID",
        Callback = function()
            if setclipboard then setclipboard(tostring(LP.UserId)) end
            notify("Copied", "User ID: " .. LP.UserId, "success")
        end
    })
    S2:AddParagraph("Avatar panel", "Click your profile picture in the sidebar to open the avatar info panel. Drag it to snap it to either side of the window.")
end

-- ── Initialize (applies saved config if AutoLoadConfig = true) ──────────────────
Duvome:Init()