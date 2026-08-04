

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local _realTS = TweenService
TweenService = setmetatable({}, {
	__index = function(_, k)
		if k == "Create" then
			return function(_, obj, info, props)
				local ok, tween = pcall(function()
					return _realTS:Create(obj, info, props)
				end)
				if ok and tween then
					return setmetatable({}, {
						__index = function(_, m)
							if m == "Play" then
								return function()
									pcall(function() tween:Play() end)
								end
							end
							return tween[m]
						end
					})
				end
				return setmetatable({}, {__index = function() return function() end end})
			end
		end
		return _realTS[k]
	end
})
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

local BICONS_PATH = "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json"

local function SafeFont(path, weight, style)
	local ok, f = pcall(Font.new, path, weight or Enum.FontWeight.Regular, style or Enum.FontStyle.Normal)
	return ok and f or Font.fromEnum(Enum.Font.GothamBold)
end

local function SetFontFace(obj, path)
	pcall(function()
		obj.FontFace = Font.new(path or BICONS_PATH, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	end)
end

local function MakeBIconFont()
	local ok, f = pcall(Font.new, BICONS_PATH, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	return ok and f or nil
end



local function GetExecutor()
	if identifyexecutor then
		local ok, name = pcall(identifyexecutor)
		if ok and name then return tostring(name):split(" ")[1] end
	end
	if syn then return "Synapse" end
	if KRNL_LOADED then return "Krnl" end
	if getexecutorname then
		local ok, name = pcall(getexecutorname)
		if ok and name then return tostring(name) end
	end
	return "Unknown"
end



local DuvomeLibrary = {
	Elements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	Themes = {
		Default = {
			Main    = Color3.fromRGB(0, 0, 0),
			Second  = Color3.fromRGB(20, 20, 20),
			Stroke  = Color3.fromRGB(95, 95, 95),
			Divider = Color3.fromRGB(70, 70, 70),
			Text    = Color3.fromRGB(245, 245, 245),
			TextDark = Color3.fromRGB(155, 155, 155)
		},
		Purple = {
			Main    = Color3.fromRGB(10, 4, 20),
			Second  = Color3.fromRGB(20, 8, 36),
			Stroke  = Color3.fromRGB(60, 20, 100),
			Divider = Color3.fromRGB(60, 20, 100),
			Text    = Color3.fromRGB(235, 210, 255),
			TextDark = Color3.fromRGB(140, 90, 190)
		},
		Ocean = {
			Main    = Color3.fromRGB(6, 14, 26),
			Second  = Color3.fromRGB(12, 24, 44),
			Stroke  = Color3.fromRGB(30, 70, 130),
			Divider = Color3.fromRGB(30, 70, 130),
			Text    = Color3.fromRGB(210, 230, 255),
			TextDark = Color3.fromRGB(90, 140, 200)
		},
		Crimson = {
			Main    = Color3.fromRGB(20, 6, 8),
			Second  = Color3.fromRGB(38, 12, 16),
			Stroke  = Color3.fromRGB(120, 30, 40),
			Divider = Color3.fromRGB(120, 30, 40),
			Text    = Color3.fromRGB(255, 215, 220),
			TextDark = Color3.fromRGB(190, 90, 100)
		},
		Emerald = {
			Main    = Color3.fromRGB(6, 20, 12),
			Second  = Color3.fromRGB(12, 36, 22),
			Stroke  = Color3.fromRGB(30, 110, 60),
			Divider = Color3.fromRGB(30, 110, 60),
			Text    = Color3.fromRGB(215, 255, 225),
			TextDark = Color3.fromRGB(90, 190, 120)
		},
		Midnight = {
			Main    = Color3.fromRGB(8, 8, 14),
			Second  = Color3.fromRGB(18, 18, 30),
			Stroke  = Color3.fromRGB(60, 60, 100),
			Divider = Color3.fromRGB(60, 60, 100),
			Text    = Color3.fromRGB(225, 225, 245),
			TextDark = Color3.fromRGB(120, 120, 170)
		},
	},
	SelectedTheme = "Default",
	Glass = 0.16,
	Folder = nil,
	SaveCfg = false
}

local Icons = {}

pcall(function()
	local raw = game:HttpGet("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")
	if raw and #raw > 10 then
		local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and decoded and decoded.icons then
			Icons = decoded.icons
		end
	end
end)

local function GetIcon(IconName)
	if Icons[IconName] ~= nil then
		return Icons[IconName]
	else
		return nil
	end
end

local Duvome = Instance.new("ScreenGui")
Duvome.Name = "Duvome"
pcall(function()
	if typeof(syn) == "table" and syn.protect_gui then
		syn.protect_gui(Duvome)
		Duvome.Parent = game.CoreGui
	end
end)
if not Duvome.Parent then
	Duvome.Parent = (typeof(gethui) == "function" and gethui()) or game.CoreGui
end

if typeof(gethui) == "function" then
	for _, Interface in ipairs(gethui():GetChildren()) do
		if Interface.Name == Duvome.Name and Interface ~= Duvome then
			Interface:Destroy()
		end
	end
else
	for _, Interface in ipairs(game.CoreGui:GetChildren()) do
		if Interface.Name == Duvome.Name and Interface ~= Duvome then
			Interface:Destroy()
		end
	end
end

function DuvomeLibrary:IsRunning()
	return Duvome ~= nil and Duvome.Parent ~= nil
end

local function AddConnection(Signal, Function)
	if not DuvomeLibrary:IsRunning() then
		return
	end
	local SignalConnect = Signal:Connect(Function)
	table.insert(DuvomeLibrary.Connections, SignalConnect)
	return SignalConnect
end

task.spawn(function()
	while DuvomeLibrary:IsRunning() do
		wait()
	end
	for _, Connection in next, DuvomeLibrary.Connections do
		Connection:Disconnect()
	end
end)

local function AddDraggingFunctionality(DragPoint, Main)
	pcall(function()
		local Dragging, DragInput, MousePos, FramePos = false
		DragPoint.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Dragging = true
				MousePos = Input.Position
				FramePos = Main.Position
				Input.Changed:Connect(function()
					if Input.UserInputState == Enum.UserInputState.End then
						Dragging = false
					end
				end)
			end
		end)
		DragPoint.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
				DragInput = Input
			end
		end)
		UserInputService.InputChanged:Connect(function(Input)
			if Input == DragInput and Dragging then
				local Delta = Input.Position - MousePos
				TweenService:Create(Main, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)}):Play()
			end
		end)
	end)
end

local function Create(Name, Properties, Children)
	local Object = Instance.new(Name)
	for i, v in next, Properties or {} do
		pcall(function() Object[i] = v end)
	end
	for i, v in next, Children or {} do
		pcall(function() v.Parent = Object end)
	end
	return Object
end

local function CreateElement(ElementName, ElementFunction)
	DuvomeLibrary.Elements[ElementName] = function(...)
		return ElementFunction(...)
	end
end

local function MakeElement(ElementName, ...)
	local NewElement = DuvomeLibrary.Elements[ElementName](...)
	return NewElement
end

local function SetProps(Element, Props)
	table.foreach(Props, function(Property, Value)
		Element[Property] = Value
	end)
	return Element
end

local function SetChildren(Element, Children)
	table.foreach(Children, function(_, Child)
		Child.Parent = Element
	end)
	return Element
end

local function Round(Number, Factor)
	local Result = math.floor(Number / Factor + (math.sign(Number) * 0.5)) * Factor
	if Result < 0 then Result = Result + Factor end
	return Result
end

local function ReturnProperty(Object)
	
	
	if Object:IsA("TextButton") then
		if Object.BackgroundTransparency >= 1 then
			return "TextColor3"
		end
		return "BackgroundColor3"
	end
	if Object:IsA("Frame") then
		return "BackgroundColor3"
	end
	if Object:IsA("ScrollingFrame") then
		return "ScrollBarImageColor3"
	end
	if Object:IsA("UIStroke") then
		return "Color"
	end
	if Object:IsA("TextLabel") or Object:IsA("TextBox") then
		return "TextColor3"
	end
	if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
		return "ImageColor3"
	end
end

local function AddThemeObject(Object, Type)
	if not DuvomeLibrary.ThemeObjects[Type] then
		DuvomeLibrary.ThemeObjects[Type] = {}
	end
	table.insert(DuvomeLibrary.ThemeObjects[Type], Object)
	Object[ReturnProperty(Object)] = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme][Type]
	-- Surfaces become glass: the game shows through, tinted by the theme colour.
	-- Only fully opaque objects are touched, so elements that were deliberately
	-- semi-transparent keep their own value.
	if (Type == "Main" or Type == "Second") and Object:IsA("GuiObject") then
		if Object.BackgroundTransparency == 0 then
			Object:SetAttribute("DuvomeGlass", true)
			Object.BackgroundTransparency = DuvomeLibrary.Glass
		end
	end
	return Object
end

-- AddThemeObject can only drive the one property ReturnProperty picks, and it
-- cannot express "this colour depends on state". Anything else - a TextBox's
-- background, a toggle knob that swaps colour when it flips - registers a
-- painter here and gets called on every theme change.
DuvomeLibrary._themePainters = {}
local function AddThemePainter(fn)
	table.insert(DuvomeLibrary._themePainters, fn)
	pcall(fn, DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme])
	return fn
end

local function SetTheme()
	local theme = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme]
	if not theme then return end
	for _, paint in ipairs(DuvomeLibrary._themePainters) do
		pcall(paint, theme)
	end
	for Name, Type in pairs(DuvomeLibrary.ThemeObjects) do
		local color = theme[Name]
		if color then
			for _, Object in pairs(Type) do
				pcall(function()
					local prop = ReturnProperty(Object)
					if prop and Object and Object.Parent ~= nil then
						Object[prop] = color
					end
				end)
			end
		end
	end
	
	if DuvomeLibrary._placeholders then
		for _, tb in ipairs(DuvomeLibrary._placeholders) do
			pcall(function()
				if tb and tb.Parent ~= nil then tb.PlaceholderColor3 = theme.TextDark end
			end)
		end
	end
	
	if DuvomeLibrary._dropdownOptions then
		for _, opt in ipairs(DuvomeLibrary._dropdownOptions) do
			pcall(function()
				if opt and opt.Parent ~= nil then opt.BackgroundColor3 = theme.Stroke end
			end)
		end
	end
end

local function AddPlaceholder(tb)
	DuvomeLibrary._placeholders = DuvomeLibrary._placeholders or {}
	table.insert(DuvomeLibrary._placeholders, tb)
	pcall(function() tb.PlaceholderColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].TextDark end)
	return tb
end

local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end


local function AddTooltip(guiObject, text)
	if not guiObject or not text or text == "" then return end
	local tip
	-- MouseEnter hands us the cursor position. The tooltip used to ignore it and
	-- rely on the first MouseMoved, so it flashed up in the top-left corner and
	-- then slid across the screen to the pointer.
	local function show(x, y)
		if tip then tip:Destroy() end
		local theme = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme] or DuvomeLibrary.Themes.Default
		tip = Create("TextLabel", {
			Text = text, Font = Enum.Font.GothamSemibold, TextSize = 12,
			TextColor3 = theme.Text, BackgroundColor3 = theme.Main,
			BackgroundTransparency = 0.05, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.XY,
			TextWrapped = false, ZIndex = 500,
			Position = UDim2.new(0, (x or 0) + 14, 0, (y or 0) + 4),
			Visible = x ~= nil,
			Parent = Duvome
		})
		Create("UICorner", {CornerRadius = UDim.new(0,5), Parent = tip})
		Create("UIStroke", {Color = theme.Stroke, Thickness = 1, Parent = tip})
		Create("UIPadding", {PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4), Parent = tip})
	end
	local function hide() if tip then tip:Destroy() tip = nil end end
	guiObject.MouseEnter:Connect(show)
	guiObject.MouseLeave:Connect(hide)
	guiObject.MouseMoved:Connect(function(x, y)
		if tip then
			tip.Position = UDim2.new(0, x + 14, 0, y + 4)
			tip.Visible = true
		end
	end)
end

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadCfg(Config)
	local Data = HttpService:JSONDecode(Config)
	
	if Data.__accent and DuvomeLibrary.SetAccent then
		pcall(function() DuvomeLibrary:SetAccent(UnpackColor(Data.__accent)) end)
	elseif Data.__theme and DuvomeLibrary.Themes[Data.__theme] then
		pcall(function() DuvomeLibrary:SetTheme(Data.__theme) end)
	end
	table.foreach(Data, function(a, b)
		if type(a) == "string" and a:sub(1,2) == "__" then return end
		if DuvomeLibrary.Flags[a] then
			spawn(function()
				if DuvomeLibrary.Flags[a].Type == "Colorpicker" then
					DuvomeLibrary.Flags[a]:Set(UnpackColor(b))
				else
					DuvomeLibrary.Flags[a]:Set(b)
				end
			end)
		else
			warn("Duvome Library Config Loader - Could not find ", a, b)
		end
	end)
end

local function SaveCfg(Name)
	if not DuvomeLibrary.SaveCfg then return end
	pcall(function()
		local Data = {}
		for i, v in pairs(DuvomeLibrary.Flags) do
			if v.Save then
				if v.Type == "Colorpicker" then
					Data[i] = PackColor(v.Value)
				else
					Data[i] = v.Value
				end
			end
		end
		
		if DuvomeLibrary._customAccent then
			Data.__accent = PackColor(DuvomeLibrary._customAccent)
		end
		Data.__theme = DuvomeLibrary.SelectedTheme
		writefile(DuvomeLibrary.Folder .. "/" .. Name .. ".txt", tostring(HttpService:JSONEncode(Data)))
	end)
end

local WhitelistedMouse = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3}
local BlacklistedKeys = {Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.Down, Enum.KeyCode.Right, Enum.KeyCode.Slash, Enum.KeyCode.Tab, Enum.KeyCode.Backspace, Enum.KeyCode.Escape}

local function CheckKey(Table, Key)
	for _, v in next, Table do
		if v == Key then
			return true
		end
	end
end

CreateElement("Corner", function(Scale, Offset)
	return Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 10)})
end)

CreateElement("Stroke", function(Color, Thickness)
	return Create("UIStroke", {Color = Color or Color3.fromRGB(255, 255, 255), Thickness = Thickness or 1})
end)

CreateElement("List", function(Scale, Offset)
	return Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(Scale or 0, Offset or 0)})
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
	return Create("UIPadding", {
		PaddingBottom = UDim.new(0, Bottom or 4),
		PaddingLeft   = UDim.new(0, Left   or 4),
		PaddingRight  = UDim.new(0, Right  or 4),
		PaddingTop    = UDim.new(0, Top    or 4)
	})
end)

CreateElement("TFrame", function()
	return Create("Frame", {BackgroundTransparency = 1})
end)

CreateElement("Frame", function(Color)
	return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255), BorderSizePixel = 0})
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
	return Create("Frame", {
		BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
		BorderSizePixel  = 0
	}, {
		Create("UICorner", {CornerRadius = UDim.new(Scale, Offset)})
	})
end)

CreateElement("Button", function()
	return Create("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0})
end)

CreateElement("ScrollFrame", function(Color, Width)
	return Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		MidImage    = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		TopImage    = "rbxassetid://7445543667",
		ScrollBarImageColor3  = Color,
		BorderSizePixel       = 0,
		ScrollBarThickness    = Width,
		CanvasSize            = UDim2.new(0, 0, 0, 0)
	})
end)

CreateElement("Image", function(ImageID)
	local ImageNew = Create("ImageLabel", {Image = ImageID, BackgroundTransparency = 1})
	if GetIcon(ImageID) ~= nil then
		ImageNew.Image = GetIcon(ImageID)
	end
	return ImageNew
end)

CreateElement("ImageButton", function(ImageID)
	return Create("ImageButton", {Image = ImageID, BackgroundTransparency = 1})
end)

CreateElement("Label", function(Text, TextSize, Transparency)
	return Create("TextLabel", {
		Text              = Text or "",
		TextColor3        = Color3.fromRGB(240, 240, 240),
		TextTransparency  = Transparency or 0,
		TextSize          = TextSize or 15,
		Font              = Enum.Font.Gotham,
		RichText          = true,
		BackgroundTransparency = 1,
		TextXAlignment    = Enum.TextXAlignment.Left
	})
end)

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
	SetProps(MakeElement("List"), {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder           = Enum.SortOrder.LayoutOrder,
		VerticalAlignment   = Enum.VerticalAlignment.Bottom,
		Padding             = UDim.new(0, 5)
	})
}), {
	Position    = UDim2.new(1, -25, 1, -25),
	Size        = UDim2.new(0, 300, 1, -25),
	AnchorPoint = Vector2.new(1, 1),
	Parent      = Duvome
})

function DuvomeLibrary:MakeNotification(NotificationConfig)
	spawn(function()
		NotificationConfig.Name    = NotificationConfig.Name    or "Notification"
		NotificationConfig.Content = NotificationConfig.Content or "Test"
		NotificationConfig.Time    = NotificationConfig.Time    or 15
		NotificationConfig.Type    = NotificationConfig.Type    or "default"

		
		-- The four semantic types keep their own colours (green means done, red
		-- means broken). "default" carries no meaning, so it follows the theme
		-- instead of the purple it was pinned to.
		local nTheme = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme] or DuvomeLibrary.Themes.Default
		local typeStyles = {
			default = {Image="rbxassetid://4384403532", Color=nTheme.Text, Stroke=nTheme.Stroke},
			info    = {Image="rbxassetid://14155658847", Color=Color3.fromRGB(90,160,255),  Stroke=Color3.fromRGB(40,90,180)},
			success = {Image="rbxassetid://14155623738", Color=Color3.fromRGB(90,220,130),  Stroke=Color3.fromRGB(40,160,80)},
			warning = {Image="rbxassetid://14155659131", Color=Color3.fromRGB(255,200,80),  Stroke=Color3.fromRGB(190,140,30)},
			error   = {Image="rbxassetid://14155637241", Color=Color3.fromRGB(255,95,95),   Stroke=Color3.fromRGB(190,40,40)},
		}
		local style = typeStyles[NotificationConfig.Type] or typeStyles.default
		local notifImage = NotificationConfig.Image or style.Image

		local hasActions = type(NotificationConfig.Actions) == "table" and #NotificationConfig.Actions > 0

		local NotificationParent = SetProps(MakeElement("TFrame"), {
			Size          = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent        = NotificationHolder
		})

		local children = {
			MakeElement("Stroke", style.Stroke, 1.5),
			MakeElement("Padding", 12, 12, 12, 12),
			SetProps(MakeElement("Image", notifImage), {
				Size        = UDim2.new(0, 18, 0, 18),
				ImageColor3 = style.Color,
				Name        = "Icon"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Name, 14), {
				Size      = UDim2.new(1, -30, 0, 20),
				Position  = UDim2.new(0, 26, 0, 0),
				Font      = Enum.Font.GothamBold,
				TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text,
				Name      = "Title"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 13), {
				Size          = UDim2.new(1, 0, 0, 0),
				Position      = UDim2.new(0, 0, 0, 24),
				Font          = Enum.Font.GothamSemibold,
				Name          = "Content",
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3    = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].TextDark,
				TextWrapped   = true
			})
		}

		local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Main, 0, 10), {
			Parent              = NotificationParent,
			Size                = UDim2.new(1, 0, 0, 0),
			Position            = UDim2.new(1, -55, 0, 0),
			BackgroundTransparency = 0,
			AutomaticSize       = Enum.AutomaticSize.Y
		}), children)

		
		if hasActions then
			local btnRow = Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
				Position = UDim2.new(0, 0, 0, 0),
				Name = "ActionRow",
				Parent = NotificationFrame
			})
			Create("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Right, Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder, Parent=btnRow})
			
			task.defer(function()
				local content = NotificationFrame:FindFirstChild("Content")
				if content then btnRow.Position = UDim2.new(0, 0, 0, 28 + content.AbsoluteSize.Y + 6) end
			end)
			for _, action in ipairs(NotificationConfig.Actions) do
				local btn = Create("TextButton", {
					Text = action.Text or "OK",
					Font = Enum.Font.GothamBold, TextSize = 12,
					TextColor3 = nTheme.Text,
					BackgroundColor3 = style.Stroke,
					BorderSizePixel = 0,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 1, 0),
					Parent = btnRow
				})
				Create("UICorner", {CornerRadius=UDim.new(0,5), Parent=btn})
				Create("UIPadding", {PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), Parent=btn})
				btn.MouseButton1Click:Connect(function()
					pcall(function() if action.Callback then action.Callback() end end)
					if action.Close ~= false then
						pcall(function() NotificationFrame:Destroy() end)
					end
				end)
			end
		end

		local function nfAlive() return NotificationFrame and NotificationFrame.Parent end
		if nfAlive() then pcall(function() TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, 0)}):Play() end) end
		wait(NotificationConfig.Time - 0.88)
		if nfAlive() then
			pcall(function()
				local icon = NotificationFrame:FindFirstChild("Icon")
				if icon then TweenService:Create(icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play() end
				TweenService:Create(NotificationFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.6}):Play()
			end)
		end
		wait(0.3)
		if nfAlive() then
			pcall(function()
				local stroke = NotificationFrame:FindFirstChildOfClass("UIStroke")
				local title  = NotificationFrame:FindFirstChild("Title")
				local body   = NotificationFrame:FindFirstChild("Content")
				if stroke then TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0.9}):Play() end
				if title  then TweenService:Create(title,  TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.4}):Play() end
				if body   then TweenService:Create(body,   TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play() end
			end)
		end
		wait(0.05)
		if nfAlive() then
			pcall(function()
				local curY = NotificationFrame.Position.Y.Offset
				TweenService:Create(NotificationFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(1, 20, 0, curY)}):Play()
			end)
		end
		wait(1.35)
		if nfAlive() then pcall(function() NotificationFrame:Destroy() end) end
	end)
end

function DuvomeLibrary:Init()
	if DuvomeLibrary.SaveCfg and DuvomeLibrary.AutoLoadConfig then
		pcall(function()
			if isfile(DuvomeLibrary.Folder .. "/" .. game.GameId .. ".txt") then
				LoadCfg(readfile(DuvomeLibrary.Folder .. "/" .. game.GameId .. ".txt"))
				DuvomeLibrary:MakeNotification({
					Name    = "Configuration",
					Content = "Auto-loaded configuration for the game " .. game.GameId .. ".",
					Time    = 5
				})
			end
		end)
	end
end

function DuvomeLibrary:MakeWindow(WindowConfig)
	local FirstTab = true
	local Minimized = false
	local Loaded = false
	local UIHidden = false
	local ToggleKey = Enum.KeyCode.RightShift  

	
	local UIBlur
	if WindowConfig and WindowConfig.Blur then
		UIBlur = Instance.new("BlurEffect")
		UIBlur.Size = 0
		UIBlur.Parent = game:GetService("Lighting")
	end
	local function setBlur(on)
		if not UIBlur then return end
		TweenService:Create(UIBlur, TweenInfo.new(0.3), {Size = on and (WindowConfig.BlurSize or 16) or 0}):Play()
	end

	WindowConfig = WindowConfig or {}
	WindowConfig.Name         = WindowConfig.Name         or "Duvome"
	WindowConfig.IconFont     = WindowConfig.IconFont or nil  
	WindowConfig.ConfigFolder = WindowConfig.ConfigFolder or WindowConfig.Name
	WindowConfig.SaveConfig   = WindowConfig.SaveConfig   or false
	WindowConfig.HidePremium  = WindowConfig.HidePremium  or false
	if WindowConfig.IntroEnabled == nil then
		WindowConfig.IntroEnabled = true
	end
	WindowConfig.IntroText     = WindowConfig.IntroText     or "Duvome Library"
	WindowConfig.CloseCallback = WindowConfig.CloseCallback or function() end
	WindowConfig.ShowIcon      = WindowConfig.ShowIcon      or false
	WindowConfig.Icon          = WindowConfig.Icon          or "rbxassetid://8834748103"
	WindowConfig.IntroIcon     = WindowConfig.IntroIcon     or "rbxassetid://8834748103"
	WindowConfig.Theme         = WindowConfig.Theme         or "Default"
	if WindowConfig.AutoLoadConfig == nil then WindowConfig.AutoLoadConfig = false end
	
	if DuvomeLibrary.Themes[WindowConfig.Theme] then DuvomeLibrary.SelectedTheme = WindowConfig.Theme end
	DuvomeLibrary.AutoLoadConfig = WindowConfig.AutoLoadConfig
	DuvomeLibrary.Folder  = WindowConfig.ConfigFolder
	local _iconFont = WindowConfig.IconFont
	DuvomeLibrary.SaveCfg = WindowConfig.SaveConfig

	if WindowConfig.SaveConfig then
		pcall(function()
			if not isfolder(WindowConfig.ConfigFolder) then
				makefolder(WindowConfig.ConfigFolder)
			end
		end)
	end

	local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 4), {
		Size     = UDim2.new(1, 0, 1, -120),
		Position = UDim2.new(0, 0, 0, 32)
	}), {
		MakeElement("List"),
		MakeElement("Padding", 8, 0, 0, 8)
	}), "Divider")

	
	
	local TabSearchBG = Create("Frame", {
		BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second,
		BackgroundTransparency = 0,
		BorderSizePixel  = 0,
		Size             = UDim2.new(1, -8, 0, 24),
		Position         = UDim2.new(0, 4, 0, 4),
		ZIndex           = 5,
		ClipsDescendants = true,
	})
	AddThemeObject(TabSearchBG, "Second")
	Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = TabSearchBG})
	local _searchStroke = Create("UIStroke", {Color = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke, Thickness = 1, Parent = TabSearchBG})
	AddThemeObject(_searchStroke, "Stroke")

	
	local SearchIcon = Create("TextButton", {
		Text = "magnifying-glass",
		FontFace = MakeBIconFont(),
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = Color3.fromRGB(140, 80, 200),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0, 26, 1, 0),
		Position = UDim2.new(0, 5, 0.5, 0),
		ZIndex = 7, Parent = TabSearchBG
	})
	AddThemeObject(SearchIcon, "TextDark")

	local TabSearchBox = Create("TextBox", {
		Text             = "",
		PlaceholderText  = "Search tabs...",
		PlaceholderColor3 = Color3.fromRGB(90, 55, 130),
		Font             = Enum.Font.GothamSemibold,
		TextSize         = 11,
		TextColor3       = Color3.fromRGB(210, 175, 255),
		BackgroundTransparency = 1,
		Size             = UDim2.new(1, -33, 1, 0),
		Position         = UDim2.new(0, 32, 0, 0),
		TextXAlignment   = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex           = 6,
		Visible          = false,
		Parent           = TabSearchBG
	})
	AddThemeObject(TabSearchBox, "Text")

	local _searchOpen = false
	local function openSearch()
		if _searchOpen then return end
		_searchOpen = true

		TabSearchBox.PlaceholderText = ""
		TabSearchBox.Visible = true
		TabSearchBox.Text = ""
		SearchIcon.TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text
		
		task.spawn(function()
			local ph = "Search features..."
			for i = 1, #ph do
				if not _searchOpen then break end
				TabSearchBox.PlaceholderText = ph:sub(1, i)
				task.wait(0.04)
			end
		end)
		TabSearchBox:CaptureFocus()
	end
	local function closeSearch()
		if not _searchOpen then return end
		_searchOpen = false
		TabSearchBox.Text = ""
		TabSearchBox.PlaceholderText = ""
		TabSearchBox.Visible = false
		SearchIcon.TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].TextDark
		
		for _, entry in ipairs(DuvomeLibrary._tabRegistry or {}) do
			if entry.Container then
				for _, desc in ipairs(entry.Container:GetDescendants()) do
					if desc:IsA("Frame") then desc.Visible = true end
				end
			end
		end
	end

	

	TabSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = TabSearchBox.Text:lower():match("^%s*(.-)%s*$")
		local registry = DuvomeLibrary._tabRegistry or {}

		local function restoreAll()
			for _, entry in ipairs(registry) do
				if entry.Container then
					for _, d in ipairs(entry.Container:GetDescendants()) do
						if d:IsA("Frame") then d.Visible = true end
					end
				end
			end
		end

		if q == "" then restoreAll() return end

		for _, entry in ipairs(registry) do
			if entry.Container then
				local hadParent = entry.Container.Parent ~= nil
				if not hadParent then entry.Container.Parent = Duvome end

				
				local items = {}
				local hasMatch = false

				for _, desc in ipairs(entry.Container:GetDescendants()) do
					if desc:IsA("TextLabel") and desc.Name == "Content" and #desc.Text > 1 then
						local itemFrame    = desc.Parent
						local holderFrame  = itemFrame and itemFrame.Parent
						local sectionFrame = holderFrame and holderFrame.Parent
						
						if itemFrame and holderFrame and sectionFrame then
							local matches = desc.Text:lower():find(q, 1, true) ~= nil
							local sf = holderFrame.Name == "Holder" and sectionFrame or holderFrame
							table.insert(items, {item=itemFrame, section=sf, matches=matches})
							if matches then hasMatch = true end
						end
					end
				end

				if not hadParent then entry.Container.Parent = nil end

				if hasMatch then
					restoreAll()
					if entry.ClickFn then entry.ClickFn() end
					local sectionHasMatch = {}
					for _, v in ipairs(items) do
						v.item.Visible = v.matches
						if v.matches then sectionHasMatch[v.section] = true end
					end
					for _, v in ipairs(items) do
						if not sectionHasMatch[v.section] then
							v.section.Visible = false
						end
					end
					break
				end
			end
		end
	end)


	AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		task.defer(function()
			if TabHolder.Parent then
				TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 16)
			end
		end)
	end)

	
	local PillBadge = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(90, 30, 150),
		Size             = UDim2.new(0, 160, 0, 30),
		Position         = UDim2.new(0, 120, 0.5, -15),
		BorderSizePixel  = 0,
		ZIndex           = 3
	})
	Create("UICorner",  {CornerRadius = UDim.new(1, 0), Parent = PillBadge})
	Create("UIStroke",  {Color = Color3.fromRGB(160, 60, 255), Thickness = 1.5, Parent = PillBadge})
	Create("TextLabel", {
		Text             = os.date("%m/%d/%Y %I:%M %p"),
		Font             = Enum.Font.GothamBold,
		TextSize         = 16,
		TextColor3       = Color3.fromRGB(220, 180, 255),
		BackgroundTransparency = 1,
		Size             = UDim2.new(1, 0, 1, 0),
		TextXAlignment   = Enum.TextXAlignment.Center,
		ZIndex           = 4,
		Parent           = PillBadge
	})



	local CloseBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size                = UDim2.new(0, 35, 1, 0),
		Position            = UDim2.new(0, 70, 0, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072725342"), {
			Position = UDim2.new(0, 9, 0, 6),
			Size     = UDim2.new(0, 18, 0, 18)
		}), "Text")
	})

	local MinimizeBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size                = UDim2.new(0, 35, 1, 0),
		Position            = UDim2.new(0, 35, 0, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072719338"), {
			Position = UDim2.new(0, 9, 0, 6),
			Size     = UDim2.new(0, 18, 0, 18),
			Name     = "Ico"
		}), "Text")
	})

	
	local DragPoint = SetProps(MakeElement("TFrame"), {
		Size = UDim2.new(1, -80, 1, 0),  
		Active = true                     
	})

	local ExecutorLbl = Create("TextLabel", {
		Name             = "ExecutorLbl",
		Text             = GetExecutor(),
		Font             = Enum.Font.Gotham,
		TextSize         = 12,
		TextColor3       = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].TextDark,
		BackgroundTransparency = 1,
		Size             = UDim2.new(0, 0, 0, 13),
		Position         = UDim2.new(0, 40, 0, 27),
		TextXAlignment   = Enum.TextXAlignment.Left,
		ClipsDescendants = true
	})
	AddThemeObject(ExecutorLbl, "TextDark")

	local WindowStuff = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 10), {
		Size                  = UDim2.new(0, 44, 1, -50),
		Position              = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 0
	}), {
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size     = UDim2.new(1, 0, 0, 10),
			Position = UDim2.new(0, 0, 0, 0)
		}), "Second"),
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size     = UDim2.new(0, 10, 1, 0),
			Position = UDim2.new(1, -10, 0, 0)
		}), "Second"),
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size     = UDim2.new(0, 1, 1, 0),
			Position = UDim2.new(1, -1, 0, 0)
		}), "Stroke"),
		TabSearchBG,
		TabHolder,
		SetChildren(SetProps(MakeElement("TFrame"), {
			Size     = UDim2.new(1, 0, 0, 50),
			Position = UDim2.new(0, 0, 1, -50)
		}), {
			AddThemeObject(SetProps(MakeElement("Frame"), {
				Size = UDim2.new(1, 0, 0, 1)
			}), "Stroke"),
			AddThemeObject(SetChildren(SetProps(Create("TextButton", {
				Text = "", BackgroundTransparency = 0, AutoButtonColor = false,
				AnchorPoint = Vector2.new(0, 0.5),
				Size        = UDim2.new(0, 32, 0, 32),
				Position    = UDim2.new(0, 4, 0.5, 0),
				BorderSizePixel = 0,
				Name = "AvatarBtn"
			}), {}), {
				SetProps(MakeElement("Image", "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"), {
					Size = UDim2.new(1, 0, 1, 0)
				}),
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://4031889928"), {
					Size = UDim2.new(1, 0, 1, 0)
				}), "Second"),
				MakeElement("Corner", 1)
			}), "Divider"),
			SetChildren(SetProps(MakeElement("TFrame"), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size        = UDim2.new(0, 32, 0, 32),
				Position    = UDim2.new(0, 4, 0.5, 0),
				Name        = "GlowRing"
			}), {
				Create("UIStroke", {
					Color     = Color3.fromRGB(0, 220, 255),
					Thickness = 1.8,
					Name      = "GlowStroke"
				}),
				MakeElement("Corner", 1)
			}),
			AddThemeObject(SetProps(MakeElement("Label", LocalPlayer.DisplayName, 15), {
				Size             = UDim2.new(0, 0, 0, 16),
				Position         = UDim2.new(0, 40, 0, 10),
				Font             = Enum.Font.GothamBold,
				ClipsDescendants = true,
				Name             = "DisplayNameLbl"
			}), "Text"),
			ExecutorLbl
		})
	}), "Second")

	local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 14), {
		Size     = UDim2.new(0, 250, 0, 26),
		Position = UDim2.new(0, 15, 0, 8),
		Font     = Enum.Font.GothamBlack,
		TextSize = 18
	}), "Text")

	local TopbarStats = AddThemeObject(Create("TextLabel", {
		Name             = "TopbarStats",
		Text             = "FPS: -- | Ping: --",
		Font             = Enum.Font.Gotham,
		TextSize         = 10,
		TextColor3       = Color3.fromRGB(140, 90, 190),
		BackgroundTransparency = 1,
		Size             = UDim2.new(0, 200, 0, 12),
		Position         = UDim2.new(0, 15, 0, 33),
		TextXAlignment   = Enum.TextXAlignment.Left
	}), "TextDark")

	local WindowTopBarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
		Size     = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1)
	}), "Stroke")

	local DragPoint = SetProps(MakeElement("TFrame"), {
		Size = UDim2.new(1, -80, 1, 0)
	})

	local SettingsBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size                   = UDim2.new(0, 35, 1, 0),
		Position               = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(Create("TextLabel", {
			Text        = "gear",
			FontFace = MakeBIconFont(),
			TextSize    = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			BackgroundTransparency = 1,
			Size        = UDim2.new(0, 22, 0, 22),
			Position    = UDim2.new(0.5, -11, 0.5, -11),
			Name        = "Ico"
		}), {}), "Text")
	})

	local MinimizeBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size                = UDim2.new(0, 35, 1, 0),
		Position            = UDim2.new(0, 35, 0, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072719338"), {
			Position = UDim2.new(0, 9, 0, 6),
			Size     = UDim2.new(0, 18, 0, 18),
			Name     = "Ico"
		}), "Text")
	})

	local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 10), {
		Parent                = Duvome,
		Position              = UDim2.new(0.5, -307, 0.5, -172),
		Size                  = UDim2.new(0, 615, 0, 344),
		ClipsDescendants      = true,
		BackgroundTransparency = 0
	}), {
		SetChildren(SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 50),
			Name = "TopBar"
		}), {
			WindowName,
			TopbarStats,
			WindowTopBarLine,
			DragPoint,
			AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 7), {
				Size     = UDim2.new(0, 105, 0, 30),
				Position = UDim2.new(1, -120, 0, 10)
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				AddThemeObject(SetProps(MakeElement("Frame"), {
					Size     = UDim2.new(0, 1, 1, 0),
					Position = UDim2.new(0, 35, 0, 0)
				}), "Stroke"),
				AddThemeObject(SetProps(MakeElement("Frame"), {
					Size     = UDim2.new(0, 1, 1, 0),
					Position = UDim2.new(0, 70, 0, 0)
				}), "Stroke"),
				SettingsBtn,
				CloseBtn,
				MinimizeBtn
			}), "Second")
		}),
		WindowStuff
	}), "Main")

	local MainStroke = Instance.new("UIStroke")
	MainStroke.Color     = Color3.fromRGB(0, 0, 0)
	MainStroke.Thickness = 5
	MainStroke.Parent    = MainWindow

	AddDraggingFunctionality(DragPoint, MainWindow)

	
	local PencilCfgBtn = Instance.new("TextButton")
	PencilCfgBtn.Text = ""
	PencilCfgBtn.AutoButtonColor = false
	PencilCfgBtn.BackgroundColor3 = Color3.fromRGB(30, 10, 60)
	PencilCfgBtn.BackgroundTransparency = 0.3
	PencilCfgBtn.BorderSizePixel = 0
	PencilCfgBtn.AnchorPoint = Vector2.new(0, 0)
	PencilCfgBtn.Size = UDim2.new(0, 30, 0, 30)
	PencilCfgBtn.Position = UDim2.new(0, 7, 1, -88)
	PencilCfgBtn.ZIndex = 8
	PencilCfgBtn.Parent = WindowStuff
	AddThemeObject(PencilCfgBtn, "Second")
	local _pc = Instance.new("UICorner", PencilCfgBtn); _pc.CornerRadius = UDim.new(0, 6)
	local _ps = Instance.new("UIStroke", PencilCfgBtn); _ps.Color = Color3.fromRGB(90, 30, 150); _ps.Thickness = 1
	AddThemeObject(_ps, "Stroke")
	local PencilIco = Instance.new("TextLabel", PencilCfgBtn)
	PencilIco.Text = "pencil-square"
	SetFontFace(PencilIco, BICONS_PATH)
	PencilIco.TextSize = 15
	PencilIco.TextWrapped = true
	PencilIco.TextColor3 = Color3.fromRGB(160, 100, 220)
	AddThemeObject(PencilIco, "Text")
	PencilIco.BackgroundTransparency = 1
	PencilIco.Size = UDim2.new(1, 0, 1, 0)
	PencilIco.TextXAlignment = Enum.TextXAlignment.Center
	PencilIco.TextYAlignment = Enum.TextYAlignment.Center
	PencilIco.ZIndex = 9

	
	local CfgPanel = Create("Frame", {
		Name                   = "CfgPanel",
		BackgroundColor3       = Color3.fromRGB(12, 4, 24),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(0, 175, 0, 344),
		Position               = UDim2.new(0, 0, 0, 0),
		Visible                = false,
		ZIndex                 = 100,
		Parent                 = Duvome,
	})
	AddThemeObject(CfgPanel, "Main")
	Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = CfgPanel})
	local _cfgStroke = Create("UIStroke", {Color = Color3.fromRGB(90, 30, 140), Thickness = 1.5, Parent = CfgPanel})
	AddThemeObject(_cfgStroke, "Stroke")

	
	AddThemeObject(Create("TextLabel", {
		Text = "Configs", Font = Enum.Font.GothamBlack, TextSize = 16,
		TextColor3 = Color3.fromRGB(220, 180, 255), BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0, 8, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101, Parent = CfgPanel,
	}), "Text")
	AddThemeObject(Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(80, 25, 130), BorderSizePixel = 0,
		Size = UDim2.new(0.9, 0, 0, 1), Position = UDim2.new(0.05, 0, 0, 38),
		ZIndex = 102, Parent = CfgPanel,
	}), "Stroke")

	
	local refreshCfgList 
	local CfgNameBG = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(18, 6, 36), BackgroundTransparency = 0,
		BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.new(0, 8, 0, 48), ZIndex = 101, Parent = CfgPanel,
	})
	AddThemeObject(CfgNameBG, "Second")
	Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = CfgNameBG})
	local _cfgNameStroke = Create("UIStroke", {Color = Color3.fromRGB(80, 25, 130), Thickness = 1, Parent = CfgNameBG})
	AddThemeObject(_cfgNameStroke, "Stroke")
	local CfgNameBox = AddPlaceholder(AddThemeObject(Create("TextBox", {
		Text = "", PlaceholderText = "Config name...",
		PlaceholderColor3 = Color3.fromRGB(90, 55, 130),
		Font = Enum.Font.GothamSemibold, TextSize = 11,
		TextColor3 = Color3.fromRGB(210, 175, 255),
		BackgroundTransparency = 1, ClearTextOnFocus = false,
		Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102, Parent = CfgNameBG,
	}), "Text"))

	
	local CfgSaveBtn = Create("TextButton", {
		Text = "", Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = Color3.fromRGB(220, 180, 255),
		BackgroundColor3 = Color3.fromRGB(70, 20, 120),
		BackgroundTransparency = 0, BorderSizePixel = 0, AutoButtonColor = false,
		Size = UDim2.new(0.6, -12, 0, 28), Position = UDim2.new(0, 8, 0, 84),
		ZIndex = 101, Parent = CfgPanel,
	})
	AddThemeObject(CfgSaveBtn, "Second")
	AddThemeObject(Create("TextLabel", {
		Text = "Save Config", Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = Color3.fromRGB(220, 180, 255), BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 102, Parent = CfgSaveBtn,
	}), "Text")
	Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = CfgSaveBtn})
	CfgSaveBtn.MouseEnter:Connect(function() TweenService:Create(CfgSaveBtn, TweenInfo.new(0.15), {BackgroundColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke}):Play() end)
	CfgSaveBtn.MouseLeave:Connect(function() TweenService:Create(CfgSaveBtn, TweenInfo.new(0.15), {BackgroundColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second}):Play() end)
	CfgSaveBtn.MouseButton1Click:Connect(function()
		local name = CfgNameBox.Text:match("^%s*(.-)%s*$")
		if name == "" then name = "config_"..os.time() end
		name = name:gsub("[^%w_%-]", "_")
		local data = {}
		for flag, elem in pairs(DuvomeLibrary.Flags) do
			if elem.Value ~= nil then data[flag] = elem.Value end
		end
		pcall(function()
			if not isfolder("DuvomeConfigs") then makefolder("DuvomeConfigs") end
			writefile("DuvomeConfigs/"..name..".json", game:GetService("HttpService"):JSONEncode(data))
		end)
		DuvomeLibrary:MakeNotification({Name="Config Saved", Content="'"..name.."'", Time=3})
		CfgNameBox.Text = ""
		refreshCfgList()
	end)

	
	local CfgExportBtn = Create("TextButton", {
		Text = "", Font = Enum.Font.GothamBold, TextSize = 12,
		BackgroundColor3 = Color3.fromRGB(70, 20, 120),
		BackgroundTransparency = 0, BorderSizePixel = 0, AutoButtonColor = false,
		Size = UDim2.new(0.4, -12, 0, 28), Position = UDim2.new(0.6, 4, 0, 84),
		ZIndex = 101, Parent = CfgPanel,
	})
	AddThemeObject(CfgExportBtn, "Second")
	AddThemeObject(Create("TextLabel", {
		Text = "Export", Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = Color3.fromRGB(220, 180, 255), BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 102, Parent = CfgExportBtn,
	}), "Text")
	Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = CfgExportBtn})
	CfgExportBtn.MouseEnter:Connect(function() TweenService:Create(CfgExportBtn, TweenInfo.new(0.15), {BackgroundColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke}):Play() end)
	CfgExportBtn.MouseLeave:Connect(function() TweenService:Create(CfgExportBtn, TweenInfo.new(0.15), {BackgroundColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second}):Play() end)
	CfgExportBtn.MouseButton1Click:Connect(function()
		local data = {}
		for flag, elem in pairs(DuvomeLibrary.Flags) do
			if elem.Type == "Colorpicker" and elem.Value then
				data[flag] = {R = elem.Value.R*255, G = elem.Value.G*255, B = elem.Value.B*255}
			elseif elem.Value ~= nil then
				data[flag] = elem.Value
			end
		end
		pcall(setclipboard, game:GetService("HttpService"):JSONEncode(data))
		DuvomeLibrary:MakeNotification({Name="Exported", Content="Config copied to clipboard.", Time=4})
	end)

	
	AddThemeObject(Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(80, 25, 130), BorderSizePixel = 0,
		Size = UDim2.new(0.9, 0, 0, 1), Position = UDim2.new(0.05, 0, 0, 120),
		ZIndex = 102, Parent = CfgPanel,
	}), "Stroke")
	AddThemeObject(Create("TextLabel", {
		Text = "Saved Configs", Font = Enum.Font.GothamBold, TextSize = 10,
		TextColor3 = Color3.fromRGB(140, 90, 200), BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 0, 128),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101, Parent = CfgPanel,
	}), "TextDark")

	
	local CfgScroll = AddThemeObject(Create("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 175), Position = UDim2.new(0, 4, 0, 148),
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(0,0,0,0), ZIndex = 101, Parent = CfgPanel,
	}), "Stroke")
	Create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), Parent=CfgScroll})
	Create("UIPadding", {PaddingLeft=UDim.new(0,4), PaddingRight=UDim.new(0,4), PaddingTop=UDim.new(0,2), Parent=CfgScroll})

	refreshCfgList = function()
		for _, c in ipairs(CfgScroll:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local files = {}
		pcall(function()
			if isfolder("DuvomeConfigs") then
				for _, f in ipairs(listfiles("DuvomeConfigs")) do
					local n = f:match("([^/\\]+)%.json$")
					if n then table.insert(files, n) end
				end
			end
		end)
		for i, name in ipairs(files) do
			local row = Create("Frame", {
				BackgroundColor3 = Color3.fromRGB(18,6,36), BackgroundTransparency=0.3,
				BorderSizePixel=0, Size=UDim2.new(1,0,0,26), LayoutOrder=i, ZIndex=102, Parent=CfgScroll,
			})
			Create("UICorner", {CornerRadius=UDim.new(0,4), Parent=row})
			AddThemeObject(Create("TextLabel", {
				Text=name, Font=Enum.Font.GothamSemibold, TextSize=11,
				TextColor3=Color3.fromRGB(200,160,255), BackgroundTransparency=1,
				Size=UDim2.new(1,-50,1,0), Position=UDim2.new(0,6,0,0),
				TextXAlignment=Enum.TextXAlignment.Left, ZIndex=103, Parent=row,
			}), "Text")
			
			local loadBtn = AddThemeObject(Create("TextButton", {
				Text="arrow-small-down",
				FontFace = MakeBIconFont(),
				TextSize=14, TextWrapped=true,
				TextColor3=Color3.fromRGB(140,90,200), BackgroundTransparency=1,
				Size=UDim2.new(0,22,1,0), Position=UDim2.new(1,-44,0,0),
				ZIndex=103, Parent=row,
			}), "TextDark")
			
			local delBtn = Create("TextButton", {
				Text="x", Font=Enum.Font.GothamBold, TextSize=12,
				TextColor3=Color3.fromRGB(220,80,80), BackgroundTransparency=1,
				Size=UDim2.new(0,20,1,0), Position=UDim2.new(1,-22,0,0),
				ZIndex=103, Parent=row,
			})
			delBtn.MouseEnter:Connect(function() delBtn.TextColor3=Color3.fromRGB(255,100,100) end)
			delBtn.MouseLeave:Connect(function() delBtn.TextColor3=Color3.fromRGB(220,80,80) end)
			local _dn = name
			delBtn.MouseButton1Click:Connect(function()
				pcall(function() delfile("DuvomeConfigs/".._dn..".json") end)
				refreshCfgList()
			end)
			local _n = name
			loadBtn.MouseButton1Click:Connect(function()
				pcall(function()
					local raw = readfile("DuvomeConfigs/".._n..".json")
					local data = game:GetService("HttpService"):JSONDecode(raw)
					for flag, val in pairs(data) do
						if DuvomeLibrary.Flags[flag] then pcall(function() DuvomeLibrary.Flags[flag]:Set(val) end) end
					end
				end)
				DuvomeLibrary:MakeNotification({Name="Config Loaded", Content="'"..name.."'", Time=3})
			end)
		end
		local ll = CfgScroll:FindFirstChildOfClass("UIListLayout")
		if ll then CfgScroll.CanvasSize = UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+8) end
	end

	local CfgPanelOpen = false
	
	DuvomeLibrary._panelState = DuvomeLibrary._panelState or {cfgOpen=false, cfgSide="left", vpOpen=false, vpSide="right"}
	local PS = DuvomeLibrary._panelState
	local cfgSide      = PS.cfgSide   
	local cfgDragging  = false    

	
	RunService.RenderStepped:Connect(function()
		if CfgPanelOpen and not cfgDragging then
			local wp  = MainWindow.AbsolutePosition
			local ws  = MainWindow.AbsoluteSize
			local pw  = CfgPanel.AbsoluteSize.X
			local ph  = CfgPanel.AbsoluteSize.Y
			local targetX = cfgSide == "right" and (wp.X + ws.X + 20) or (wp.X - pw - 20)
			local targetY = wp.Y + (ws.Y - ph) / 2
			local curX = CfgPanel.Position.X.Offset
			local curY = CfgPanel.Position.Y.Offset
			local newX = curX + (targetX - curX) * 0.12
			local newY = curY + (targetY - curY) * 0.12
			CfgPanel.Position = UDim2.new(0, newX, 0, newY)
		end
	end)

	local function openCfgPanel()
		CfgPanelOpen = true
		
		if PS.vpOpen and PS.vpSide == cfgSide then
			cfgSide = (cfgSide == "left") and "right" or "left"
		end
		PS.cfgOpen = true
		PS.cfgSide = cfgSide
		refreshCfgList()
		local wp    = MainWindow.AbsolutePosition
		local ws    = MainWindow.AbsoluteSize
		local pw    = CfgPanel.AbsoluteSize.X
		local ph    = CfgPanel.AbsoluteSize.Y
		local centY = wp.Y + (ws.Y - ph) / 2
		
		local landX = cfgSide == "left" and (wp.X - pw - 20) or (wp.X + ws.X + 20)
		
		local startX = cfgSide == "left" and (landX - pw - 40) or (landX + pw + 40)
		CfgPanel.Position = UDim2.new(0, startX, 0, centY)
		CfgPanel.BackgroundTransparency = 1
		CfgPanel.Visible = true
		TweenService:Create(CfgPanel,
			TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Position = UDim2.new(0, landX, 0, centY), BackgroundTransparency = 0.05}
		):Play()
	end

	local function closeCfgPanel()
		CfgPanelOpen = false
		PS.cfgOpen = false
		local curY = CfgPanel.Position.Y.Offset
		local curX = CfgPanel.Position.X.Offset
		local pw   = CfgPanel.AbsoluteSize.X
		
		local exitX = cfgSide == "left" and (curX - pw - 40) or (curX + pw + 40)
		local t = TweenService:Create(CfgPanel,
			TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{Position = UDim2.new(0, exitX, 0, curY), BackgroundTransparency = 1}
		)
		t:Play()
		t.Completed:Connect(function() CfgPanel.Visible = false end)
	end

	PencilCfgBtn.MouseEnter:Connect(function()
		TweenService:Create(PencilCfgBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.1}):Play()
		TweenService:Create(PencilIco, TweenInfo.new(0.15), {TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text}):Play()
	end)
	PencilCfgBtn.MouseLeave:Connect(function()
		TweenService:Create(PencilCfgBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.3}):Play()
		TweenService:Create(PencilIco, TweenInfo.new(0.15), {TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text}):Play()
	end)
	PencilCfgBtn.MouseButton1Click:Connect(function()
		if CfgPanelOpen then closeCfgPanel() else openCfgPanel() end
	end)

	
	local CfgDragBtn = Create("TextButton", {
		Text                = "",
		BackgroundTransparency = 1,
		Size                = UDim2.new(1, -30, 0, 40),
		Position            = UDim2.new(0, 0, 0, 0),
		ZIndex              = 110,
		Parent              = CfgPanel
	})
	local cfgDragStart, cfgFrameStart = nil, nil

	CfgDragBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			cfgDragging   = true
			cfgDragStart  = Vector2.new(input.Position.X, input.Position.Y)
			cfgFrameStart = Vector2.new(CfgPanel.Position.X.Offset, CfgPanel.Position.Y.Offset)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if cfgDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - cfgDragStart
			CfgPanel.Position = UDim2.new(0, cfgFrameStart.X + delta.X, 0, cfgFrameStart.Y + delta.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and cfgDragging then
			cfgDragging = false
			
			local wp  = MainWindow.AbsolutePosition
			local ws  = MainWindow.AbsoluteSize
			local pw  = CfgPanel.AbsoluteSize.X
			local ph  = CfgPanel.AbsoluteSize.Y
			local cfgX = CfgPanel.Position.X.Offset
			local snapY  = wp.Y + (ws.Y - ph) / 2
			local leftX  = wp.X - pw - 20
			local rightX = wp.X + ws.X + 20
			local want = (math.abs(cfgX - leftX) < math.abs(cfgX - rightX)) and "left" or "right"
			
			if PS.vpOpen and PS.vpSide == want then
				want = (want == "left") and "right" or "left"
			end
			cfgSide = want
			PS.cfgSide = want
			local dstX = (want == "left") and leftX or rightX
			TweenService:Create(CfgPanel,
				TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{Position = UDim2.new(0, dstX, 0, snapY)}
			):Play()
		end
	end)

	
	local _keybindListening = false
	local _keybindCancel    = nil
	local _keybindRegistry  = {}
	local _keybindBlocking  = false  

	local function abbrKey(kc)
		if not kc then return "---" end
		local names = {
			Return="Ent", BackSpace="Bsp", Space="Spc",
			Delete="Del", Escape="Esc", CapsLock="Cap",
			LeftControl="LCtrl", RightControl="RCtrl",
			LeftShift="LSft", RightShift="RSft",
			LeftAlt="LAlt", RightAlt="RAlt",
		}
		local n = kc.Name
		return names[n] or (n:len() > 4 and n:sub(1,4) or n)
	end

	local function makeKeybindBox(parent, posX, defaultKey, _, flagId, callback)
		local boundKey = defaultKey  
		local function kbWidth(kc)
			if not kc then return 28 end
			return math.max(28, #abbrKey(kc) * 7 + 8)
		end
		local kbBox = Create("TextButton", {
			Text             = abbrKey(boundKey),
			Font             = Enum.Font.GothamBold,
			TextSize         = 10,
			TextColor3       = Color3.fromRGB(180, 120, 255),
			BackgroundColor3 = Color3.fromRGB(25, 8, 48),
			BackgroundTransparency = 0,
			BorderSizePixel  = 0,
			Size             = UDim2.new(0, kbWidth(boundKey), 0, 24),
			Position         = UDim2.new(1, posX, 0.5, -12),
			ZIndex           = 6,
			Name             = "KeybindBox",
			Parent           = parent
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = kbBox})
		Create("UIStroke", {Color = Color3.fromRGB(80, 30, 130), Thickness = 1, Parent = kbBox})

		kbBox.MouseButton1Click:Connect(function()
			if _keybindListening then
				if _keybindCancel then _keybindCancel() end
			end
			_keybindListening = true
			_keybindBlocking  = true
			kbBox.Text = "..."
			kbBox.TextColor3 = Color3.fromRGB(255, 200, 80)
			local conn
			local function cancel(newKey)
				_keybindListening = false
				_keybindCancel    = nil
				task.delay(0.05, function() _keybindBlocking = false end)
				if newKey then
					local dupe = false
					for id, k in pairs(_keybindRegistry) do
						if id ~= flagId and k == newKey then dupe = true break end
					end
					if dupe then
						kbBox.Text = abbrKey(boundKey)
						kbBox.TextColor3 = Color3.fromRGB(180, 120, 255)
						DuvomeLibrary:MakeNotification({
							Name    = "Keybind Taken",
							Content = abbrKey(newKey) .. " is already bound to another action.",
							Time    = 3
						})
					else
						boundKey = newKey
						_keybindRegistry[flagId] = boundKey
						kbBox.Text = abbrKey(boundKey)
						kbBox.Size = UDim2.new(0, kbWidth(boundKey), 0, 24)
						kbBox.TextColor3 = Color3.fromRGB(180, 120, 255)
					end
				else
					kbBox.Text = abbrKey(boundKey)
					kbBox.TextColor3 = Color3.fromRGB(180, 120, 255)
				end
				pcall(function() conn:Disconnect() end)
			end
			_keybindCancel = function() cancel(nil) end
			conn = UserInputService.InputBegan:Connect(function(inp, gp)
				if gp then return end
				if inp.UserInputType == Enum.UserInputType.Keyboard then
					
					local _blocked = {
						[Enum.KeyCode.Escape] = true,
						[Enum.KeyCode.Tab]    = true,
						[Enum.KeyCode.Space]  = true,
					}
					if inp.KeyCode == Enum.KeyCode.Backspace then
						
						_keybindListening = false
						_keybindCancel    = nil
						_keybindRegistry[flagId] = nil
						boundKey = nil
						kbBox.Text = "---"
						kbBox.Size = UDim2.new(0, 28, 0, 24)
						kbBox.TextColor3 = Color3.fromRGB(180, 120, 255)
						pcall(function() conn:Disconnect() end)
						task.delay(0.05, function() _keybindBlocking = false end)
						DuvomeLibrary:MakeNotification({Name = "Keybind Removed", Content = "Keybind cleared.", Time = 2})
					elseif _blocked[inp.KeyCode] then
						cancel(nil)
					else
						cancel(inp.KeyCode)
					end
				end
			end)
		end)

		
		UserInputService.InputBegan:Connect(function(inp, gp)
			if gp then return end
			if inp.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
			if not kbBox or not kbBox.Parent then return end
			local mp = inp.Position
			local ap = kbBox.AbsolutePosition
			local as = kbBox.AbsoluteSize
			if mp.X >= ap.X and mp.X <= ap.X+as.X and mp.Y >= ap.Y and mp.Y <= ap.Y+as.Y then
				if _keybindListening then return end
				if boundKey then
					_keybindRegistry[flagId] = nil
					boundKey = nil
					kbBox.Text = "---"
					kbBox.Size = UDim2.new(0, 28, 0, 24)
					kbBox.TextColor3 = Color3.fromRGB(180, 120, 255)
					DuvomeLibrary:MakeNotification({Name = "Keybind Removed", Content = "Keybind cleared.", Time = 2})
				else
					DuvomeLibrary:MakeNotification({Name = "No Keybind", Content = "Left-click to set one.", Time = 2})
				end
			end
		end)

		UserInputService.InputBegan:Connect(function(inp, gp)
			if gp or _keybindListening or _keybindBlocking then return end
			if not boundKey then return end
			if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
			if inp.KeyCode == Enum.KeyCode.Space then return end
			if inp.KeyCode == boundKey then
				callback()
			end
		end)

		if flagId and boundKey then _keybindRegistry[flagId] = boundKey end
		return kbBox
	end

	
	local SB_WIDE = 150
	local SB_THIN = 44
	local sbOpen  = false  
	local resizing = false 

	local function setSidebar(open)
		sbOpen = open
		local tw = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local _w = open and SB_WIDE or SB_THIN
		local _t = open and 0 or 1

		TweenService:Create(WindowStuff, tw, {Size = UDim2.new(0, _w, 1, -50)}):Play()

		for _, c in ipairs(MainWindow:GetChildren()) do
			if c.Name == "ItemContainer" then
				TweenService:Create(c, tw, {
					Position = UDim2.new(0, _w, 0, 50),
					Size     = UDim2.new(1, -_w, 1, -50)
				}):Play()
			end
		end

		for _, tab in ipairs(TabHolder:GetChildren()) do
			if tab:IsA("TextButton") then
				local title = tab:FindFirstChild("Title")
				local ico   = tab:FindFirstChild("Ico")
				if title then
					title.ClipsDescendants = true
					if open then
						TweenService:Create(title, tw, {Size = UDim2.new(1, -36, 1, 0), TextTransparency = 0.4}):Play()
					else
						TweenService:Create(title, tw, {Size = UDim2.new(0, 0, 1, 0), TextTransparency = 0.4}):Play()
					end
				end
				
			end
		end

		local _nameW = open and UDim2.new(0, 100, 0, 14) or UDim2.new(0, 0, 0, 14)
		local _execW = open and UDim2.new(0, 100, 0, 13) or UDim2.new(0, 0, 0, 13)
		local dnl = WindowStuff:FindFirstChild("DisplayNameLbl", true)
		local exl = WindowStuff:FindFirstChild("ExecutorLbl", true)
		if dnl then dnl.ClipsDescendants = true TweenService:Create(dnl, tw, {Size = _nameW}):Play() end
		if exl then exl.ClipsDescendants = true TweenService:Create(exl, tw, {Size = _execW}):Play() end


	end

	local sbPinned = false

	WindowStuff.MouseEnter:Connect(function() if not sbPinned and not resizing then setSidebar(true)  end end)
	WindowStuff.MouseLeave:Connect(function() if not sbPinned and not _searchOpen and not resizing then setSidebar(false) end end)

	
	SearchIcon.MouseButton1Click:Connect(function()
		if _searchOpen then
			closeSearch()
		else
			setSidebar(true)
			openSearch()
		end
	end)

	
	AddConnection(UserInputService.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not _searchOpen then return end
		local mp = UserInputService:GetMouseLocation()
		local ap = TabSearchBG.AbsolutePosition
		local as = TabSearchBG.AbsoluteSize
		local overBar = mp.X >= ap.X and mp.X <= ap.X + as.X and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y
		if not overBar then
			closeSearch()
			if not sbPinned then setSidebar(false) end
		end
	end)

	local _bgBtn = Create("TextButton", {
		Text = "", BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 4, Parent = TabSearchBG
	})
	_bgBtn.MouseButton1Click:Connect(function()
		if not _searchOpen then setSidebar(true) openSearch() end
	end)

	
	local BottomPill = Create("Frame", {
		BackgroundColor3       = Color3.fromRGB(180, 80, 255),
		BackgroundTransparency = 0.3,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(0, 180, 0, 4),
		AnchorPoint            = Vector2.new(0.5, 0),
		Position               = UDim2.new(0, 0, 0, 0),
		ZIndex                 = 20,
		Parent                 = Duvome
	})
	AddThemeObject(BottomPill, "Stroke")
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = BottomPill})

	
	RunService.RenderStepped:Connect(function()
		if MainWindow and MainWindow.Parent then
			local wp = MainWindow.AbsolutePosition
			local ws = MainWindow.AbsoluteSize
			BottomPill.Position = UDim2.new(0, wp.X + ws.X / 2, 0, wp.Y + ws.Y + 8)
		end
	end)

	
	local function _pillCol() return DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke end
	local function _pillBright()
		local c = _pillCol()
		return Color3.fromRGB(math.clamp(c.R*255+40,0,255), math.clamp(c.G*255+40,0,255), math.clamp(c.B*255+40,0,255))
	end
	BottomPill.MouseEnter:Connect(function()
		TweenService:Create(BottomPill, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0, BackgroundColor3 = _pillBright()}):Play()
	end)
	BottomPill.MouseLeave:Connect(function()
		TweenService:Create(BottomPill, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.3, BackgroundColor3 = _pillCol()}):Play()
	end)

	
	AddDraggingFunctionality(BottomPill, MainWindow)

	
	local function getUIScale()
		local s = MainWindow:FindFirstChildOfClass("UIScale")
		if not s then s = Instance.new("UIScale"); s.Parent = MainWindow end
		return s
	end

	
	do
		local StarCanvas = Create("Frame", {
			Name                   = "StarCanvas",
			BackgroundTransparency = 1,
			Size                   = UDim2.new(1, 0, 1, 0),
			Position               = UDim2.new(0, 0, 0, 0),
			ZIndex                 = 0,
			ClipsDescendants       = true,
			Parent                 = MainWindow
		})

		local MAX_STARS = 40
		-- Three sizes so the field has depth rather than one uniform sparkle.
		local TIERS = { 12, 20, 30 }

		-- A star is drawn, not typed: Roblox fonts have no star glyph, which is
		-- why a text character rendered as a box. Two tapered bars crossed over
		-- a soft round glow reads as a four-point sparkle at any size.
		local function makeStar(size)
			local holder = Create("Frame", {
				BackgroundTransparency = 1,
				Size                   = UDim2.new(0, size, 0, size),
				Position               = UDim2.new(math.random(), 0, math.random(), 0),
				ZIndex                 = 0,
				Parent                 = StarCanvas
			})

			local glow = Create("Frame", {
				BackgroundColor3       = Color3.fromRGB(200, 170, 255),
				BackgroundTransparency = 1,
				BorderSizePixel        = 0,
				AnchorPoint            = Vector2.new(0.5, 0.5),
				Position               = UDim2.new(0.5, 0, 0.5, 0),
				Size                   = UDim2.new(0.45, 0, 0.45, 0),
				ZIndex                 = 0,
				Parent                 = holder
			})
			Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = glow})

			-- One tapered spike, rotated four ways, gives an eight-point
			-- sparkle. Long axis runs vertically; the gradient fades both tips
			-- to nothing so it reads as a point rather than a bar.
			local function spike(rotation, lengthScale, widthScale)
				local f = Create("Frame", {
					BackgroundColor3       = Color3.fromRGB(255, 250, 255),
					BackgroundTransparency = 1,
					BorderSizePixel        = 0,
					AnchorPoint            = Vector2.new(0.5, 0.5),
					Position               = UDim2.new(0.5, 0, 0.5, 0),
					Size                   = UDim2.new(widthScale, 0, lengthScale, 0),
					Rotation               = rotation,
					ZIndex                 = 0,
					Parent                 = holder
				})
				Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = f})
				Create("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
					Parent = f
				})
				return f
			end

			local parts = {
				spike(0,   1.00, 0.13),   -- long vertical
				spike(90,  1.00, 0.13),   -- long horizontal
				spike(45,  0.62, 0.09),   -- short diagonals
				spike(135, 0.62, 0.09),
			}
			return holder, { glow = glow, parts = parts }
		end

		local function fade(st, targetBar, targetGlow, time, style, dir)
			local info = TweenInfo.new(time, style, dir)
			for _, f in ipairs(st.parts) do
				TweenService:Create(f, info, {BackgroundTransparency = targetBar}):Play()
			end
			TweenService:Create(st.glow, info, {BackgroundTransparency = targetGlow}):Play()
		end

		-- Fade up, hold, fade out, reappear elsewhere at a new size.
		local function twinkle(holder, st)
			local size  = TIERS[math.random(1, #TIERS)]
			local peak  = 0.05 + math.random() * 0.25     -- bright enough to read through the glass
			local up    = 0.6 + math.random() * 0.9
			local hold  = 0.25 + math.random() * 1.1
			local down  = 0.7 + math.random() * 1.0

			holder.Position = UDim2.new(math.random(), 0, math.random(), 0)
			holder.Size     = UDim2.new(0, size, 0, size)
			for _, f in ipairs(st.parts) do f.BackgroundTransparency = 1 end
			st.glow.BackgroundTransparency = 1

			fade(st, peak, math.min(peak + 0.15, 1), up, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

			task.delay(up + hold, function()
				if not (holder and holder.Parent) then return end
				fade(st, 1, 1, down, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
				task.delay(down + math.random() * 1.6, function()
					if holder and holder.Parent then twinkle(holder, st) end
				end)
			end)
		end

		task.spawn(function()
			for _ = 1, MAX_STARS do
				local holder, st = makeStar(TIERS[math.random(1, #TIERS)])
				twinkle(holder, st)
				-- stagger so they never pulse in unison
				task.wait(0.06 + math.random() * 0.14)
			end
		end)
	end

	
	local ViewportOpen = false

	local ViewportFrame = Create("Frame", {
		Name                   = "AvatarViewport",
		BackgroundColor3       = Color3.fromRGB(12, 4, 24),
		BackgroundTransparency = 0.05,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(0, 175, 0, 420),
		Position               = UDim2.new(0, 0, 0, 0),
		Visible                = false,
		ZIndex                 = 100,
		Parent                 = Duvome
	})
	AddThemeObject(ViewportFrame, "Main")
	Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = ViewportFrame})
	local _avStroke = Create("UIStroke", {Color = Color3.fromRGB(90, 30, 140), Thickness = 1.5, Parent = ViewportFrame})
	AddThemeObject(_avStroke, "Stroke")

	
	Create("ImageLabel", {
		Image                  = "https://www.roblox.com/avatar-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png&thumbnailType=AvatarThumbnail",
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 145),
		Position               = UDim2.new(0, 0, 0, 20),
		ScaleType              = Enum.ScaleType.Fit,
		ZIndex                 = 101,
		Parent                 = ViewportFrame
	})

	local function loadViewportChar() end

	
	local _avDiv = Create("Frame", {
		BackgroundColor3       = Color3.fromRGB(80, 25, 130),
		BorderSizePixel        = 0,
		Size                   = UDim2.new(0.9, 0, 0, 1),
		Position               = UDim2.new(0.05, 0, 0, 170),
		ZIndex                 = 102,
		Parent                 = ViewportFrame
	})
	AddThemeObject(_avDiv, "Stroke")

	
	local function InfoRow(label, value, yPos)
		local lblObj = Create("TextLabel", {
			Text             = label,
			Font             = Enum.Font.GothamBold,
			TextSize         = 10,
			TextColor3       = Color3.fromRGB(140, 90, 200),
			BackgroundTransparency = 1,
			Size             = UDim2.new(0.45, 0, 0, 16),
			Position         = UDim2.new(0, 8, 0, yPos),
			TextXAlignment   = Enum.TextXAlignment.Left,
			ZIndex           = 103,
			Parent           = ViewportFrame
		})
		AddThemeObject(lblObj, "TextDark")
		local valLbl = Create("TextLabel", {
			Text             = tostring(value),
			Font             = Enum.Font.Gotham,
			TextSize         = 10,
			TextColor3       = Color3.fromRGB(220, 190, 255),
			BackgroundTransparency = 1,
			Size             = UDim2.new(0.55, -4, 0, 16),
			Position         = UDim2.new(0.45, 0, 0, yPos),
			TextXAlignment   = Enum.TextXAlignment.Left,
			ZIndex           = 103,
			TextTruncate     = Enum.TextTruncate.AtEnd,
			Parent           = ViewportFrame
		})
		AddThemeObject(valLbl, "Text")
		return valLbl
	end

	local yStart = 178

	
	InfoRow("Display", LocalPlayer.DisplayName, yStart)
	InfoRow("Username", "@" .. LocalPlayer.Name, yStart + 18)
	InfoRow("User ID", LocalPlayer.UserId, yStart + 36)
	InfoRow("Account Age", LocalPlayer.AccountAge .. "d", yStart + 54)
	InfoRow("Executor", GetExecutor(), yStart + 72)

	
	local nameRow  = InfoRow("Game", "Loading...", yStart + 90)
	local placeRow = InfoRow("Place ID", game.PlaceId, yStart + 108)
	
	task.spawn(function()
		local ok, info = pcall(function()
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		end)
		if ok and info and info.Name then nameRow.Text = info.Name else nameRow.Text = "Unknown" end
	end)

	
	local plDiv = Create("Frame", {BackgroundColor3=Color3.fromRGB(80,25,130), BorderSizePixel=0,
		Size=UDim2.new(0.9,0,0,1), Position=UDim2.new(0.05,0,0,yStart+132), ZIndex=102, Parent=ViewportFrame})
	AddThemeObject(plDiv, "Stroke")
	local plHeader = Create("TextLabel", {Text="Players", Font=Enum.Font.GothamBold, TextSize=10,
		TextColor3=Color3.fromRGB(140,90,200), BackgroundTransparency=1, Size=UDim2.new(1,-16,0,14),
		Position=UDim2.new(0,8,0,yStart+138), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=103, Parent=ViewportFrame})
	AddThemeObject(plHeader, "TextDark")
	local plCount = Create("TextLabel", {Text="0", Font=Enum.Font.GothamBold, TextSize=10,
		TextColor3=Color3.fromRGB(220,190,255), BackgroundTransparency=1, Size=UDim2.new(0,40,0,14),
		Position=UDim2.new(1,-48,0,yStart+138), TextXAlignment=Enum.TextXAlignment.Right, ZIndex=103, Parent=ViewportFrame})
	AddThemeObject(plCount, "Text")
	local plScroll = AddThemeObject(Create("ScrollingFrame", {BackgroundTransparency=1, BorderSizePixel=0,
		Size=UDim2.new(1,-16,0,68), Position=UDim2.new(0,8,0,yStart+154), ScrollBarThickness=3,
		CanvasSize=UDim2.new(0,0,0,0), ZIndex=103, Parent=ViewportFrame}), "Stroke")
	local plLayout = Create("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.Name, Parent=plScroll})
	AddConnection(plLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		plScroll.CanvasSize = UDim2.new(0,0,0,plLayout.AbsoluteContentSize.Y)
	end)

	local function refreshPlayers()
		for _, c in ipairs(plScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local players = game:GetService("Players"):GetPlayers()
		plCount.Text = tostring(#players)
		for _, plr in ipairs(players) do
			local row = Create("TextButton", {Text="", BackgroundColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second,
				BackgroundTransparency=0.3, BorderSizePixel=0, Size=UDim2.new(1,0,0,20), ZIndex=104,
				AutoButtonColor=false, Name=plr.Name, Parent=plScroll})
			Create("UICorner", {CornerRadius=UDim.new(0,4), Parent=row})
			local nm = Create("TextLabel", {Text=(plr==LocalPlayer and (plr.Name.." (you)") or plr.Name), Font=Enum.Font.GothamSemibold, TextSize=11,
				TextColor3=Color3.fromRGB(220,220,230), BackgroundTransparency=1, Size=UDim2.new(1,-8,1,0),
				Position=UDim2.new(0,6,0,0), TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=105, Parent=row})
			row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(0.12),{BackgroundTransparency=0}):Play() end)
			row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(0.12),{BackgroundTransparency=0.3}):Play() end)
			row.MouseButton1Click:Connect(function()
				if setclipboard then setclipboard(tostring(plr.UserId)) end
				DuvomeLibrary:MakeNotification({Name=plr.Name, Content="UserId "..plr.UserId.." copied.", Type="info", Time=3})
			end)
		end
	end
	refreshPlayers()
	game:GetService("Players").PlayerAdded:Connect(refreshPlayers)
	game:GetService("Players").PlayerRemoving:Connect(function() task.wait(0.1) refreshPlayers() end)





	


	
	local PS = DuvomeLibrary._panelState
	local vpSide     = PS.vpSide  
	local vpDragging = false    

	local function resetViewportPos()
		local wp  = MainWindow.AbsolutePosition
		local ws  = MainWindow.AbsoluteSize
		local vpH = ViewportFrame.AbsoluteSize.Y
		vpSide = "right"
		PS.vpSide = "right"
		
		ViewportFrame.Position = UDim2.new(0, wp.X + ws.X + 20, 0, wp.Y + (ws.Y - vpH) / 2)
	end

	
	RunService.RenderStepped:Connect(function()
		if ViewportFrame.Visible and not vpDragging then
			local wp  = MainWindow.AbsolutePosition
			local ws  = MainWindow.AbsoluteSize
			local vpw = ViewportFrame.AbsoluteSize.X
			local vpH     = ViewportFrame.AbsoluteSize.Y
			local targetX = vpSide == "right" and (wp.X + ws.X + 20) or (wp.X - vpw - 20)
			local targetY = wp.Y + (ws.Y - vpH) / 2
			local curX = ViewportFrame.Position.X.Offset
			local curY = ViewportFrame.Position.Y.Offset
			
			local newX = curX + (targetX - curX) * 0.12
			local newY = curY + (targetY - curY) * 0.12
			ViewportFrame.Position = UDim2.new(0, newX, 0, newY)
		end
	end)

	
	
	local VPScale = Instance.new("UIScale")
	VPScale.Scale  = 1
	VPScale.Parent = ViewportFrame  

	local function openViewport()
		ViewportOpen = true
		
		if PS.cfgOpen and PS.cfgSide == vpSide then
			vpSide = (vpSide == "left") and "right" or "left"
		end
		PS.vpOpen = true
		PS.vpSide = vpSide
		loadViewportChar()
		local wp    = MainWindow.AbsolutePosition
		local ws    = MainWindow.AbsoluteSize
		local vpW   = ViewportFrame.AbsoluteSize.X
		local vpH   = ViewportFrame.AbsoluteSize.Y
		local centY = wp.Y + (ws.Y - vpH) / 2
		
		local landX = vpSide == "left" and (wp.X - vpW - 20) or (wp.X + ws.X + 20)
		
		local startX = vpSide == "left" and (landX - vpW - 40) or (landX + vpW + 40)
		ViewportFrame.Position               = UDim2.new(0, startX, 0, centY)
		ViewportFrame.BackgroundTransparency = 1
		ViewportFrame.Visible                = true
		VPScale.Scale = 1
		TweenService:Create(ViewportFrame,
			TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Position = UDim2.new(0, landX, 0, centY), BackgroundTransparency = 0.05}
		):Play()
	end

	local function closeViewport()
		ViewportOpen = false
		PS.vpOpen = false
		local curY  = ViewportFrame.Position.Y.Offset
		local curX  = ViewportFrame.Position.X.Offset
		local vpW   = ViewportFrame.AbsoluteSize.X
		
		local exitX = vpSide == "left" and (curX - vpW - 40) or (curX + vpW + 40)
		local t = TweenService:Create(ViewportFrame,
			TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{Position = UDim2.new(0, exitX, 0, curY), BackgroundTransparency = 1}
		)
		t:Play()
		t.Completed:Connect(function()
			ViewportFrame.Visible = false
		end)
	end

	local AvatarBtn = MainWindow:FindFirstChild("AvatarBtn", true)
	if AvatarBtn then
		AvatarBtn.MouseButton1Click:Connect(function()
			if ViewportOpen then closeViewport() else openViewport() end
		end)
	end



	
	
	local VPDragBtn = Create("TextButton", {
		Text                = "",
		BackgroundTransparency = 1,
		Size                = UDim2.new(1, -30, 0, 20),
		Position            = UDim2.new(0, 0, 0, 0),
		ZIndex              = 110,
		Parent              = ViewportFrame
	})

	local vpDragStart, vpFrameStart = nil, nil

	VPDragBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			vpDragging   = true
			vpDragStart  = Vector2.new(input.Position.X, input.Position.Y)
			vpFrameStart = Vector2.new(ViewportFrame.Position.X.Offset, ViewportFrame.Position.Y.Offset)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if vpDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - vpDragStart
			ViewportFrame.Position = UDim2.new(0, vpFrameStart.X + delta.X, 0, vpFrameStart.Y + delta.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and vpDragging then
			vpDragging = false
			
			local wp  = MainWindow.AbsolutePosition
			local ws  = MainWindow.AbsoluteSize
			local vpw = ViewportFrame.AbsoluteSize.X
			local vpX = ViewportFrame.Position.X.Offset
			local vpY = ViewportFrame.Position.Y.Offset

			
			local vpH    = ViewportFrame.AbsoluteSize.Y
			local snapY  = wp.Y + (ws.Y - vpH) / 2
			local leftX  = wp.X - vpw - 20
			local rightX = wp.X + ws.X + 20
			local want = (math.abs(vpX - leftX) < math.abs(vpX - rightX)) and "left" or "right"
			
			if PS.cfgOpen and PS.cfgSide == want then
				want = (want == "left") and "right" or "left"
			end
			vpSide = want
			PS.vpSide = want
			local dstX = (want == "left") and leftX or rightX
			TweenService:Create(ViewportFrame,
				TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{Position = UDim2.new(0, dstX, 0, snapY)}
			):Play()
		end
	end)

	
	do
		local fpsBuffer = {}
		RunService.RenderStepped:Connect(function(dt)
			table.insert(fpsBuffer, dt)
			if #fpsBuffer > 20 then table.remove(fpsBuffer, 1) end
			if TopbarStats and TopbarStats.Parent then
				local avg = 0
				for _, v in ipairs(fpsBuffer) do avg = avg + v end
				avg = avg / #fpsBuffer
				local fps  = math.floor(1 / avg)
				local ping = 0
				pcall(function()
					ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
				end)
				TopbarStats.Text = "FPS: " .. fps .. "  |  Ping: " .. ping .. "ms"
			end
		end)
	end

	
	task.spawn(function()
		local glowStroke = nil
		
		for _, desc in ipairs(MainWindow:GetDescendants()) do
			if desc.Name == "GlowStroke" and desc:IsA("UIStroke") then
				glowStroke = desc
				break
			end
		end
		if not glowStroke then return end
		local bright = Color3.fromRGB(0, 220, 255)
		local dim    = Color3.fromRGB(0, 80, 120)
		local on     = true
		while MainWindow and MainWindow.Parent do
			local target = on and bright or dim
			TweenService:Create(glowStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = target}):Play()
			on = not on
			task.wait(0.9)
		end
	end)

	
	do
		MainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
		MainWindow.Position    = UDim2.new(0.5, 0, 0.5, 0)
		MainWindow.Visible     = true
		local uiScale = getUIScale()
		uiScale.Scale = 0
		TweenService:Create(uiScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end

	
	local SettingsPanelOpen = false

	
	local SettingsPanel = SetChildren(SetProps(MakeElement("RoundFrame",
		DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Main, 0, 8), {
		Size             = UDim2.new(0, 200, 0, 0),
		Position         = UDim2.new(1, -210, 0, 52),
		ZIndex           = 50,
		Visible          = false,
		ClipsDescendants = true,
		Parent           = Duvome
	}), {
		AddThemeObject(MakeElement("Stroke"), "Stroke"),
		MakeElement("Padding", 8, 8, 8, 8),
		MakeElement("List", 0, 6)
	})

	
	local PinRow = Create("Frame", {
		BackgroundColor3       = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, 32),
		ZIndex                 = 51,
		Parent                 = SettingsPanel
	})
	AddThemeObject(PinRow, "Second")
	Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = PinRow})
	AddThemeObject(Create("TextLabel", {
		Text = "Lock Tabs", Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = Color3.fromRGB(220, 180, 255), BackgroundTransparency = 1,
		Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 10, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52, Parent = PinRow
	}), "Text")
	local PinTrack = Create("Frame", {
		BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Divider,
		BorderSizePixel  = 0,
		Size             = UDim2.new(0, 36, 0, 20),
		Position         = UDim2.new(1, -44, 0.5, -10),
		ZIndex           = 52, Parent = PinRow
	})
	if not sbPinned then AddThemeObject(PinTrack, "Divider") end
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = PinTrack})
	local PinKnob = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(160, 160, 180),
		BorderSizePixel  = 0,
		Size             = UDim2.new(0, 14, 0, 14),
		Position         = UDim2.new(0, 3, 0.5, -7),
		ZIndex           = 53, Parent = PinTrack
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = PinKnob})
	local PinClickBtn = Create("TextButton", {
		Text = "", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 54, Parent = PinRow
	})
	PinClickBtn.MouseButton1Click:Connect(function()
		sbPinned = not sbPinned
		local tw = TweenInfo.new(0.2, Enum.EasingStyle.Quint)
		if sbPinned then
			TweenService:Create(PinTrack, tw, {BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke}):Play()
			TweenService:Create(PinKnob,  tw, {Position = UDim2.new(0, 19, 0.5, -7), BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
			setSidebar(true)
		else
			TweenService:Create(PinTrack, tw, {BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Divider}):Play()
			TweenService:Create(PinKnob,  tw, {Position = UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = Color3.fromRGB(160,160,180)}):Play()
			setSidebar(false)
		end
	end)

	
	local watchShown = false
	local WLRow = Create("Frame", {
		BackgroundColor3       = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, 32),
		ZIndex                 = 51,
		Parent                 = SettingsPanel
	})
	AddThemeObject(WLRow, "Second")
	Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = WLRow})
	AddThemeObject(Create("TextLabel", {
		Text = "Show Watch List", Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = Color3.fromRGB(220, 180, 255), BackgroundTransparency = 1,
		Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 10, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52, Parent = WLRow
	}), "Text")
	local WLTrack = Create("Frame", {
		BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke,
		BorderSizePixel  = 0,
		Size             = UDim2.new(0, 36, 0, 20),
		Position         = UDim2.new(1, -44, 0.5, -10),
		ZIndex           = 52, Parent = WLRow
	})
	AddThemeObject(WLTrack, "Stroke")
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = WLTrack})
	local WLKnob = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel  = 0,
		Size             = UDim2.new(0, 14, 0, 14),
		Position         = UDim2.new(0, 19, 0.5, -7),
		ZIndex           = 53, Parent = WLTrack
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = WLKnob})
	local WLClickBtn = Create("TextButton", {
		Text = "", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 54, Parent = WLRow
	})
	WLClickBtn.MouseButton1Click:Connect(function()
		watchShown = not watchShown
		DuvomeLibrary:SetWatchVisible(watchShown)
		local tw = TweenInfo.new(0.2, Enum.EasingStyle.Quint)
		if watchShown then
			TweenService:Create(WLTrack, tw, {BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke}):Play()
			TweenService:Create(WLKnob,  tw, {Position = UDim2.new(0, 19, 0.5, -7), BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
		else
			TweenService:Create(WLTrack, tw, {BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Divider}):Play()
			TweenService:Create(WLKnob,  tw, {Position = UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = Color3.fromRGB(160,160,180)}):Play()
		end
	end)

	
	local ThemeLabelRow = Create("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), ZIndex = 51, Parent = SettingsPanel
	})
	AddThemeObject(Create("TextLabel", {
		Text = "UI Theme", Font = Enum.Font.GothamBold, TextSize = 11,
		TextColor3 = Color3.fromRGB(150, 100, 210), BackgroundTransparency = 1,
		Size = UDim2.new(1, -4, 1, 0), Position = UDim2.new(0, 4, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52, Parent = ThemeLabelRow
	}), "TextDark")

	
	local ThemePicker = Create("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 108), ZIndex = 51, Parent = SettingsPanel
	})

	
	local _ah, _as, _av = Color3.toHSV(DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke)

	
	local svBox = Create("ImageLabel", {
		Image = "rbxassetid://4155801252",
		BackgroundColor3 = Color3.fromHSV(_ah, 1, 1), BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 60), Position = UDim2.new(0, 4, 0, 0), ZIndex = 52, Parent = ThemePicker
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = svBox})
	local svCursor = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0,
		Size = UDim2.new(0, 6, 0, 6), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(_as, 0, 1-_av, 0), ZIndex = 53, Parent = svBox
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = svCursor})

	
	local hueBar = Create("Frame", {
		BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 12), Position = UDim2.new(0, 4, 0, 66), ZIndex = 52, Parent = ThemePicker
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = hueBar})
	Create("UIGradient", {Parent = hueBar, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(255,0,0)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(0,255,255)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(255,0,0)),
	})})
	local hueCursor = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, 2), Position = UDim2.new(_ah, 0, 0, -1), ZIndex = 53, Parent = hueBar
	})

	
	-- Same inset as the saturation box and hue bar above, so the swatches line
	-- up with them instead of sitting 4px to the left.
	local _presetNames = {"Default","Ocean","Crimson","Emerald","Midnight"}
	local PresetRow = Create("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0,4,0,80), ZIndex = 51, Parent = ThemePicker
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = PresetRow
	})

	local function applyAccentFromHSV()
		local col = Color3.fromHSV(_ah, _as, _av)
		svBox.BackgroundColor3 = Color3.fromHSV(_ah, 1, 1)
		DuvomeLibrary:SetAccent(col)
	end

	local _swatchW = 1 / #_presetNames
	for _, tname in ipairs(_presetNames) do
		-- Swatch colour comes from the theme itself, so it can never drift from
		-- what clicking it actually applies - Default was still showing purple
		-- long after the theme went black.
		local sw = Create("TextButton", {
			Text = "", BackgroundColor3 = DuvomeLibrary.Themes[tname].Stroke, BorderSizePixel = 0,
			Size = UDim2.new(_swatchW, -4, 0, 18), AutoButtonColor = true, ZIndex = 52, Parent = PresetRow
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = sw})
		sw.MouseButton1Click:Connect(function()
			DuvomeLibrary:SetTheme(tname)
			
			_ah, _as, _av = Color3.toHSV(DuvomeLibrary.Themes[tname].Stroke)
			svBox.BackgroundColor3 = Color3.fromHSV(_ah, 1, 1)
			svCursor.Position = UDim2.new(_as, 0, 1-_av, 0)
			hueCursor.Position = UDim2.new(_ah, 0, 0, -1)
		end)
	end

	
	local dragSV, dragHue = false, false
	svBox.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragSV=true end end)
	hueBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragHue=true end end)
	UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragSV=false dragHue=false end end)
	UserInputService.InputChanged:Connect(function(i)
		if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
		if dragSV then
			_as = math.clamp((i.Position.X - svBox.AbsolutePosition.X)/svBox.AbsoluteSize.X, 0, 1)
			_av = 1 - math.clamp((i.Position.Y - svBox.AbsolutePosition.Y)/svBox.AbsoluteSize.Y, 0, 1)
			svCursor.Position = UDim2.new(_as, 0, 1-_av, 0)
			applyAccentFromHSV()
		elseif dragHue then
			_ah = math.clamp((i.Position.X - hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X, 0, 1)
			hueCursor.Position = UDim2.new(_ah, 0, 0, -1)
			applyAccentFromHSV()
		end
	end)

	local function MakeSettingBtn(text, cb)
		local f = Create("Frame", {
			BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second,
			Size             = UDim2.new(1, 0, 0, 32),
			BorderSizePixel  = 0,
			ZIndex           = 51,
			Parent           = SettingsPanel
		})
		AddThemeObject(f, "Second")
		Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = f})
		local lbl = AddThemeObject(Create("TextLabel", {
			Text             = text,
			Font             = Enum.Font.GothamSemibold,
			TextSize         = 13,
			TextColor3       = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text,
			BackgroundTransparency = 1,
			Size             = UDim2.new(1, -12, 1, 0),
			Position         = UDim2.new(0, 12, 0, 0),
			TextXAlignment   = Enum.TextXAlignment.Left,
			ZIndex           = 52,
			Name             = "Content",
			Parent           = f
		}), "Text")
		local click = Create("TextButton", {
			Text                = "",
			BackgroundTransparency = 1,
			Size                = UDim2.new(1, 0, 1, 0),
			ZIndex              = 53,
			Parent              = f
		})
		local base = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second
		local hover = Color3.fromRGB(
			math.clamp(base.R*255+8, 0, 255),
			math.clamp(base.G*255+8, 0, 255),
			math.clamp(base.B*255+8, 0, 255)
		)
		local function _baseCol() return DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second end
		local function _hoverCol()
			local b = _baseCol()
			return Color3.fromRGB(math.clamp(b.R*255+8,0,255), math.clamp(b.G*255+8,0,255), math.clamp(b.B*255+8,0,255))
		end
		click.MouseEnter:Connect(function()
			TweenService:Create(f,   TweenInfo.new(0.12, Enum.EasingStyle.Quint), {BackgroundColor3 = _hoverCol()}):Play()
			TweenService:Create(lbl, TweenInfo.new(0.12, Enum.EasingStyle.Quint), {TextSize = 14}):Play()
		end)
		click.MouseLeave:Connect(function()
			TweenService:Create(f,   TweenInfo.new(0.12, Enum.EasingStyle.Quint), {BackgroundColor3 = _baseCol()}):Play()
			TweenService:Create(lbl, TweenInfo.new(0.12, Enum.EasingStyle.Quint), {TextSize = 13}):Play()
		end)
		click.MouseButton1Click:Connect(function() spawn(cb) end)
	end

	
	local function SPGetFolder() return DuvomeLibrary.Folder or "DuvomeConfig" end
	local function SPGetPath(n) return SPGetFolder().."/"..n..".json" end
	local function SPEnsureFolder() pcall(function() if not isfolder(SPGetFolder()) then makefolder(SPGetFolder()) end end) end

	local function SPSave(name)
		SPEnsureFolder()
		local data={}
		for flag,elem in pairs(DuvomeLibrary.Flags) do
			if elem.Type=="Colorpicker" then data[flag]={R=elem.Value.R*255,G=elem.Value.G*255,B=elem.Value.B*255}
			elseif elem.Value~=nil then data[flag]=elem.Value end
		end
		local ok,err=pcall(writefile,SPGetPath(name),HttpService:JSONEncode(data))
		DuvomeLibrary:MakeNotification({Name=ok and "Config Saved" or "Save Failed",Content=ok and "Saved '"..name.."'" or tostring(err),Time=4})
	end

	local function SPLoad(name)
		local ok,raw=pcall(readfile,SPGetPath(name))
		if not ok or not raw or raw=="" then DuvomeLibrary:MakeNotification({Name="Load Failed",Content="No config: "..name,Time=4}) return end
		local dok,data=pcall(function() return HttpService:JSONDecode(raw) end)
		if not dok then DuvomeLibrary:MakeNotification({Name="Load Failed",Content="Bad JSON",Time=4}) return end
		for flag,val in pairs(data) do
			if DuvomeLibrary.Flags[flag] then spawn(function()
				if DuvomeLibrary.Flags[flag].Type=="Colorpicker" then DuvomeLibrary.Flags[flag]:Set(Color3.fromRGB(val.R,val.G,val.B))
				else DuvomeLibrary.Flags[flag]:Set(val) end
			end) end
		end
		DuvomeLibrary:MakeNotification({Name="Config Loaded",Content="Loaded '"..name.."'",Time=4})
	end

	
	local cfgName = (WindowConfig.ConfigFolder or "DuvomeConfig"):gsub("[^%w_]","_")

	
	
	local kbRow = Create("Frame", {
		BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second,
		Size             = UDim2.new(1, 0, 0, 32),
		BorderSizePixel  = 0,
		ZIndex           = 51,
		Parent           = SettingsPanel
	})
	AddThemeObject(kbRow, "Second")
	Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = kbRow})

	local kbLabel = AddThemeObject(Create("TextLabel", {
		Text             = "Toggle Key",
		Font             = Enum.Font.GothamSemibold,
		TextSize         = 13,
		TextColor3       = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text,
		BackgroundTransparency = 1,
		Size             = UDim2.new(0, 90, 1, 0),
		Position         = UDim2.new(0, 12, 0, 0),
		TextXAlignment   = Enum.TextXAlignment.Left,
		ZIndex           = 52,
		Parent           = kbRow
	}), "Text")

	local kbBox = Create("Frame", {
		BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Main,
		Size             = UDim2.new(0, 80, 0, 22),
		Position         = UDim2.new(1, -88, 0.5, -11),
		BorderSizePixel  = 0,
		ZIndex           = 52,
		Parent           = kbRow
	})
	AddThemeObject(kbBox, "Main")
	Create("UICorner",  {CornerRadius = UDim.new(0, 4), Parent = kbBox})
	local _kbBoxStroke = Create("UIStroke",  {Color = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke, Thickness = 1, Parent = kbBox})
	AddThemeObject(_kbBoxStroke, "Stroke")

	local kbText = AddThemeObject(Create("TextLabel", {
		Text             = "RightShift",
		Font             = Enum.Font.GothamBold,
		TextSize         = 11,
		TextColor3       = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text,
		BackgroundTransparency = 1,
		Size             = UDim2.new(1, -4, 1, 0),
		Position         = UDim2.new(0, 2, 0, 0),
		TextXAlignment   = Enum.TextXAlignment.Center,
		ZIndex           = 53,
		Parent           = kbBox
	}), "Text")

	
	local kbListening = false
	local kbClick = Create("TextButton", {
		Text = "", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 54, Parent = kbRow
	})

	kbClick.MouseButton1Click:Connect(function()
		if kbListening then return end
		kbListening = true
		kbText.Text = "..."
		
		TweenService:Create(kbBox, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 80, 120)}):Play()
		
		local conn
		conn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == Enum.KeyCode.Unknown then return end
			
			ToggleKey = input.KeyCode
			kbText.Text = input.KeyCode.Name
			TweenService:Create(kbBox, TweenInfo.new(0.15), {BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Main}):Play()
			kbListening = false
			conn:Disconnect()
			DuvomeLibrary:MakeNotification({
				Name    = "Keybind Set",
				Content = "Toggle key set to " .. input.KeyCode.Name,
				Time    = 3
			})
		end)
	end)

	
	AddThemeObject(Create("Frame", {
		BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke,
		Size             = UDim2.new(1, 0, 0, 1),
		BorderSizePixel  = 0,
		ZIndex           = 51,
		Parent           = SettingsPanel
	}), "Stroke")

	MakeSettingBtn("  Reset All",      function()
		for _,elem in pairs(DuvomeLibrary.Flags) do
			if elem.Type=="Toggle" then pcall(function() elem:Set(false) end)
			elseif elem.Type=="Colorpicker" then pcall(function() elem:Set(Color3.fromRGB(255,255,255)) end) end
		end
		DuvomeLibrary:MakeNotification({Name="Reset",Content="All settings reset.",Time=4})
	end)
	MakeSettingBtn("  Destroy UI",     function()
		DuvomeLibrary:MakeNotification({Name="Goodbye",Content="UI destroyed.",Time=2})
		task.wait(2.2); DuvomeLibrary:Destroy()
	end)

	
	task.defer(function()
		task.wait()
		local ll = SettingsPanel:FindFirstChild("UIListLayout")
		if ll then
			SettingsPanel.Size = UDim2.new(0, 200, 0, ll.AbsoluteContentSize.Y + 12)
		end
	end)

	local function openSettingsPanel()
		SettingsPanelOpen = true
		local ll = SettingsPanel:FindFirstChild("UIListLayout")
		local fullH = ll and ll.AbsoluteContentSize.Y + 12 or 200
		
		local bp = SettingsBtn.AbsolutePosition
		local bs = SettingsBtn.AbsoluteSize
		SettingsPanel.Position = UDim2.new(0, bp.X - 165, 0, bp.Y + bs.Y + 4)
		SettingsPanel.Size     = UDim2.new(0, 200, 0, 0)
		SettingsPanel.Visible  = true
		TweenService:Create(SettingsPanel,
			TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 200, 0, fullH)}
		):Play()
		TweenService:Create(SettingsBtn.Ico, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Rotation = 90}):Play()
	end

	local function closeSettingsPanel()
		SettingsPanelOpen = false
		TweenService:Create(SettingsPanel,
			TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 200, 0, 0)}
		):Play()
		TweenService:Create(SettingsBtn.Ico, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Rotation = 0}):Play()
		task.delay(0.22, function()
			SettingsPanel.Visible = false
		end)
	end

	AddConnection(SettingsBtn.MouseButton1Click, function()
		if SettingsPanelOpen then closeSettingsPanel() else openSettingsPanel() end
	end)

	
	RunService.RenderStepped:Connect(function()
		if SettingsPanelOpen and SettingsPanel.Visible then
			local bp = SettingsBtn.AbsolutePosition
			local bs = SettingsBtn.AbsoluteSize
			SettingsPanel.Position = UDim2.new(0, bp.X - 165, 0, bp.Y + bs.Y + 4)
		end
	end)

	
	AddConnection(UserInputService.InputBegan, function(Input)
		if not SettingsPanelOpen then return end
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local pos = Input.Position
		
		local sp = SettingsPanel.AbsolutePosition
		local ss = SettingsPanel.AbsoluteSize
		local inPanel = pos.X >= sp.X and pos.X <= sp.X+ss.X and pos.Y >= sp.Y and pos.Y <= sp.Y+ss.Y
		
		local bp = SettingsBtn.AbsolutePosition
		local bs = SettingsBtn.AbsoluteSize
		local inBtn = pos.X >= bp.X and pos.X <= bp.X+bs.X and pos.Y >= bp.Y and pos.Y <= bp.Y+bs.Y
		if not inPanel and not inBtn then
			closeSettingsPanel()
		end
	end)

	
	task.defer(function()
		pcall(function()
			if isfile and isfile(SPGetPath(cfgName)) then
				SPLoad(cfgName)
			end
		end)
	end)

	


	
	
	local ResizeArcClip = Create("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants       = true,
		Size                   = UDim2.new(0, 40, 0, 40),
		Position               = UDim2.new(0, 0, 0, 0),
		ZIndex                 = 20,
		Parent                 = Duvome
	})
	
	local ResizeArc = Create("Frame", {
		BackgroundTransparency = 1,
		Size                   = UDim2.new(0, 80, 0, 80),
		Position               = UDim2.new(0, -40, 0, -40),
		ZIndex                 = 21,
		Parent                 = ResizeArcClip
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ResizeArc})
	local ArcStroke = Create("UIStroke", {
		Color        = Color3.fromRGB(180, 80, 255),
		Thickness    = 4,
		Transparency = 0.3,
		Parent       = ResizeArc
	})
	AddThemeObject(ArcStroke, "Stroke")

	
	local RCBtn = Create("TextButton", {
		Text = "", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 22, Parent = ResizeArcClip
	})

	
	RunService.RenderStepped:Connect(function()
		if MainWindow and MainWindow.Parent then
			local wp = MainWindow.AbsolutePosition
			local ws = MainWindow.AbsoluteSize
			ResizeArcClip.Position = UDim2.new(0, wp.X + ws.X - 22, 0, wp.Y + ws.Y - 22)
		end
	end)

	
	RCBtn.MouseEnter:Connect(function()
		TweenService:Create(ArcStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Transparency = 0, Color = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke}):Play()
	end)
	RCBtn.MouseLeave:Connect(function()
		TweenService:Create(ArcStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Transparency = 0.3, Color = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke}):Play()
	end)

	
	local resizeStart, resizeStartSize
	local minW, minH = 400, 250

	RCBtn.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			resizing        = true
			resizeStart     = Vector2.new(Input.Position.X, Input.Position.Y)
			resizeStartSize = Vector2.new(MainWindow.AbsoluteSize.X, MainWindow.AbsoluteSize.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			resizing = false
		end
	end)
	UserInputService.InputChanged:Connect(function(Input)
		if resizing and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
			local delta = Vector2.new(Input.Position.X, Input.Position.Y) - resizeStart
			local newW  = math.max(minW, resizeStartSize.X + delta.X)
			local newH  = math.max(minH, resizeStartSize.Y + delta.Y)
			MainWindow.Size  = UDim2.new(0, newW, 0, newH)
			local _sw = sbOpen and SB_WIDE or SB_THIN
			WindowStuff.Size     = UDim2.new(0, _sw, 1, -50)
			WindowStuff.Position = UDim2.new(0, 0, 0, 50)
			for _, c in ipairs(MainWindow:GetChildren()) do
				if c.Name == "ItemContainer" then
					c.Position = UDim2.new(0, _sw, 0, 50)
					c.Size     = UDim2.new(1, -_sw, 1, -50)
				end
			end
		end
	end)

	
	local toggleDebounce = false

	
	local ReopenBtn = Create("TextButton", {
		Name = "ReopenBtn", Text = "", AutoButtonColor = false,
		BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke, BorderSizePixel = 0,
		Size = UDim2.new(0, 44, 0, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 38, 0.5, 0),
		Visible = false, ZIndex = 300, Parent = Duvome
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ReopenBtn})
	AddThemeObject(ReopenBtn, "Stroke")
	local ReopenScale = Create("UIScale", {Scale = 0, Parent = ReopenBtn})
	local ReopenIco = Create("TextLabel", {
		Text = "menu-burger", FontFace = MakeBIconFont(), TextSize = 20,
		TextColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 1,
		Size = UDim2.new(1,0,1,0), ZIndex = 301, Parent = ReopenBtn
	})
	
	local function showReopen()
		ReopenBtn.Visible = true
		ReopenScale.Scale = 0.3
		ReopenBtn.BackgroundTransparency = 1
		ReopenIco.TextTransparency = 1
		local strk = ReopenBtn:FindFirstChildOfClass("UIStroke")
		if strk then strk.Transparency = 1 end
		TweenService:Create(ReopenScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		TweenService:Create(ReopenBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
		TweenService:Create(ReopenIco, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
		if strk then TweenService:Create(strk, TweenInfo.new(0.3), {Transparency = 0}):Play() end
	end
	local function hideReopen(instant)
		if instant then ReopenBtn.Visible = false ReopenScale.Scale = 0.3 return end
		local strk = ReopenBtn:FindFirstChildOfClass("UIStroke")
		TweenService:Create(ReopenScale, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Scale = 0.3}):Play()
		TweenService:Create(ReopenBtn, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
		TweenService:Create(ReopenIco, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
		if strk then TweenService:Create(strk, TweenInfo.new(0.25), {Transparency = 1}):Play() end
		task.delay(0.3, function() ReopenBtn.Visible = false end)
	end
	
	local _reopenWasTap = false
	do
		local dragging, dragStart, startPos, moved = false, nil, nil, 0
		ReopenBtn.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true dragStart = i.Position startPos = ReopenBtn.Position moved = 0
			end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = i.Position - dragStart
				moved = math.max(moved, math.abs(d.X) + math.abs(d.Y))
				ReopenBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end)
		UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				if dragging then
					
					_reopenWasTap = moved < 6
				end
				dragging = false
			end
		end)
	end

	local function HideUI()
		if toggleDebounce then return end
		toggleDebounce = true
		UIHidden = true
		setBlur(false)
		local uiScale = getUIScale()
		TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
		task.delay(0.28, function()
			MainWindow.Visible    = false
			BottomPill.Visible    = false
			ResizeArcClip.Visible = false
			if ViewportOpen then
				ViewportOpen = false
				ViewportFrame.Visible = false
			end
			if CfgPanelOpen then
				CfgPanelOpen = false
				CfgPanel.Visible = false
			end
			if DuvomeLibrary._panelState then
				DuvomeLibrary._panelState.cfgOpen = false
				DuvomeLibrary._panelState.vpOpen = false
			end
			if SettingsPanel.Visible then
				SettingsPanel.Visible = false
			end
			
			if DuvomeLibrary._popovers then
				for _, p in ipairs(DuvomeLibrary._popovers) do
					pcall(p.forceClose)
				end
			end
			showReopen()
			uiScale.Scale = 1
			toggleDebounce = false
		end)
	end

	local function ShowUI()
		if toggleDebounce then return end
		toggleDebounce = true
		UIHidden = false
		setBlur(true)
		hideReopen()
		local uiScale = getUIScale()
		uiScale.Scale = 0
		
		MainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
		MainWindow.Position    = UDim2.new(0.5, 0, 0.5, 0)
		MainWindow.Visible     = true
		BottomPill.Visible     = true
		ResizeArcClip.Visible  = true
		TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		task.delay(0.45, function()
			toggleDebounce = false
		end)
	end

	ReopenBtn.MouseButton1Click:Connect(function() if _reopenWasTap then ShowUI() end _reopenWasTap = false end)

	AddConnection(CloseBtn.MouseButton1Up, function()
		HideUI()
		DuvomeLibrary:MakeNotification({
			Name    = "Interface Hidden",
			Content = "Press " .. ToggleKey.Name .. " to reopen",
			Time    = 4
		})
		WindowConfig.CloseCallback()
	end)

	
	UserInputService.InputBegan:Connect(function(Input)
		if Input.KeyCode == ToggleKey then
			if UIHidden then ShowUI() else HideUI() end
		end
	end)
	
	local lastKeyState = false
	RunService.Heartbeat:Connect(function()
		local pressed = UserInputService:IsKeyDown(ToggleKey)
		if pressed and not lastKeyState then
			if UIHidden then ShowUI() else HideUI() end
		end
		lastKeyState = pressed
	end)

	AddConnection(MinimizeBtn.MouseButton1Up, function()
		if Minimized then
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 615, 0, 344)}):Play()
			MinimizeBtn.Ico.Image = "rbxassetid://7072719338"
			task.wait(0.02)
			WindowStuff.Visible   = true
			WindowTopBarLine.Visible = true
			BottomPill.Visible    = true
			ResizeArcClip.Visible = true
		else
			WindowTopBarLine.Visible = false
			MinimizeBtn.Ico.Image = "rbxassetid://7072720870"
			local minWidth = math.max(400, WindowName.TextBounds.X + 320)
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, minWidth, 0, 50)}):Play()
			task.wait(0.1)
			WindowStuff.Visible   = false
			BottomPill.Visible    = false
			ResizeArcClip.Visible = false
			
			if ViewportOpen then ViewportOpen = false ViewportFrame.Visible = false end
			if CfgPanelOpen then CfgPanelOpen = false CfgPanel.Visible = false end
			if SettingsPanel.Visible then SettingsPanel.Visible = false SettingsPanelOpen = false end
			if DuvomeLibrary._panelState then
				DuvomeLibrary._panelState.cfgOpen = false
				DuvomeLibrary._panelState.vpOpen = false
			end
			if DuvomeLibrary._popovers then
				for _, p in ipairs(DuvomeLibrary._popovers) do pcall(p.forceClose) end
			end
		end
		Minimized = not Minimized
	end)

	local TabFunction = {}
	DuvomeLibrary._tabRegistry = DuvomeLibrary._tabRegistry or {}

	function TabFunction:MakeTab(TabConfig)
		TabConfig = TabConfig or {}
		TabConfig.Name       = TabConfig.Name       or "Tab"
		TabConfig.Icon       = TabConfig.Icon       or ""
		TabConfig.PremiumOnly = TabConfig.PremiumOnly or false

		
		local iconChar = (TabConfig.Icon ~= "" and TabConfig.Icon) or "three-dots-horizontal"
		local TabIconLbl = Create("TextLabel", {
			Text             = iconChar,
			FontFace = MakeBIconFont(),
			TextSize         = 16,
			TextColor3       = Color3.fromRGB(160, 80, 255),
			TextTransparency = 0.2,
			BackgroundTransparency = 1,
			AnchorPoint      = Vector2.new(0, 0.5),
			Size             = UDim2.new(0, 22, 0, 22),
			Position         = UDim2.new(0, 11, 0.5, 0),
			TextXAlignment   = Enum.TextXAlignment.Center,
			TextWrapped      = true,
			Name             = "Ico"
		})
		AddThemeObject(TabIconLbl, "Text")

		local TabFrame = SetChildren(SetProps(MakeElement("Button"), {
			Size   = UDim2.new(1, 0, 0, 30),
			Parent = TabHolder
		}), {
			TabIconLbl,
			AddThemeObject(SetProps(MakeElement("Label", TabConfig.Name, 14), {
				Size             = UDim2.new(0, 0, 1, 0),
				Position         = UDim2.new(0, 34, 0, 0),
				Font             = Enum.Font.GothamSemibold,
				TextTransparency = 0.4,
				ClipsDescendants = true,
				Name             = "Title"
			}), "Text")
		})

		local Container = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 5), {
			Size             = UDim2.new(1, -44, 1, -50),
			Position         = UDim2.new(0, 44, 0, 50),
			Parent           = MainWindow,
			Visible          = false,
			Name             = "ItemContainer",
			ScrollingEnabled = true,
			ScrollingDirection = Enum.ScrollingDirection.Y
		}), {
			MakeElement("List", 0, 6),
			MakeElement("Padding", 15, 10, 10, 15)
		}), "Divider")

		
		
		if not TabConfig.Columns then
			local function _updateCanvas()
				if not Container or not Container.Parent then return end
				local ll = Container:FindFirstChildOfClass("UIListLayout")
				if not ll then return end
				local newH = ll.AbsoluteContentSize.Y + 30
				if math.abs(Container.CanvasSize.Y.Offset - newH) > 1 then
					Container.CanvasSize = UDim2.new(0, 0, 0, newH)
				end
			end
			AddConnection(Container.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), _updateCanvas)
			task.defer(_updateCanvas)
		end

		
		local ColLeft, ColRight = nil, nil
		local colIndex = 0
		if TabConfig.Columns then
			
			local ColWrapper = Create("Frame", {
				BackgroundTransparency = 1,
				Size                   = UDim2.new(1, -44, 1, -50),
				Position               = UDim2.new(0, 44, 0, 50),
				Visible                = false,
				Name                   = "ItemContainer",
				Parent                 = MainWindow
			})

			ColLeft = Create("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel        = 0,
				Size                   = UDim2.new(0.5, -6, 1, 0),
				Position               = UDim2.new(0, 0, 0, 0),
				ScrollBarThickness     = 0,
				ScrollBarImageColor3   = Color3.fromRGB(0, 0, 0),
				CanvasSize             = UDim2.new(0, 0, 0, 0),
				ScrollingDirection     = Enum.ScrollingDirection.Y,
				Parent                 = ColWrapper
			})
			Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = ColLeft})
			Create("UIPadding",    {PaddingLeft = UDim.new(0,8), PaddingTop = UDim.new(0,10), PaddingRight = UDim.new(0,4), PaddingBottom = UDim.new(0,10), Parent = ColLeft})

			ColRight = Create("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel        = 0,
				Size                   = UDim2.new(0.5, -6, 1, 0),
				Position               = UDim2.new(0.5, 6, 0, 0),
				ScrollBarThickness     = 0,
				ScrollBarImageColor3   = Color3.fromRGB(0, 0, 0),
				CanvasSize             = UDim2.new(0, 0, 0, 0),
				ScrollingDirection     = Enum.ScrollingDirection.Y,
				Parent                 = ColWrapper
			})
			Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = ColRight})
			Create("UIPadding",    {PaddingLeft = UDim.new(0,4), PaddingTop = UDim.new(0,10), PaddingRight = UDim.new(0,8), PaddingBottom = UDim.new(0,10), Parent = ColRight})



			local function updateCol(col)
				local ll = col:FindFirstChildOfClass("UIListLayout")
				if ll then col.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 20) end
			end
			ColLeft:FindFirstChildOfClass("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() updateCol(ColLeft) end)
			ColRight:FindFirstChildOfClass("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() updateCol(ColRight) end)

			
			Container = ColWrapper
		end

		local _TabTitle = TabFrame:FindFirstChild("Title")
		local _TabIco   = TabFrame:FindFirstChild("Ico")
		local si = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

		if FirstTab then
			FirstTab = false
			TabIconLbl.TextTransparency = 0
			if _TabTitle then
				_TabTitle.TextTransparency = 0
				_TabTitle.Font = Enum.Font.GothamBlack
			end
			
			local _fcx = sbOpen and SB_WIDE or SB_THIN
			Container.Size     = UDim2.new(1, -_fcx, 1, -50)
			Container.Position = UDim2.new(0, _fcx, 0, 50)
			Container.Visible  = true
		end
		AddConnection(TabFrame.MouseEnter, function()
			if not Container.Visible then
				if _TabTitle then TweenService:Create(_TabTitle, si, {TextSize = 14.3, TextTransparency = 0.1}):Play() end
				if _TabIco   then TweenService:Create(_TabIco,   si, {TextSize = 15.3, TextTransparency = 0.05}):Play() end

			end
		end)
		AddConnection(TabFrame.MouseLeave, function()
			if not Container.Visible then
				if _TabTitle then TweenService:Create(_TabTitle, si, {TextSize = 14, TextTransparency = 0.4}):Play() end
				if _TabIco   then TweenService:Create(_TabIco,   si, {TextSize = 15, TextTransparency = 0.2}):Play() end

			end
		end)

		
		local _regEntry = {
			TabFrame = TabFrame,
			Container = Container,
			Name = TabConfig.Name,
			ClickFn = nil,
		}
		table.insert(DuvomeLibrary._tabRegistry, _regEntry)

		local function _doTabClick()
			
			for _, Tab in next, TabHolder:GetChildren() do
				if Tab:IsA("TextButton") then
					local TabTitle = Tab:FindFirstChild("Title")
					local TabIco   = Tab:FindFirstChild("Ico")
					if TabTitle then
						TabTitle.Font = Enum.Font.GothamSemibold
						TweenService:Create(TabTitle, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0.4, TextSize = 14}):Play()
					end
					if TabIco then
						TweenService:Create(TabIco, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0.4, TextSize = 15, TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text}):Play()
					end
				end
			end

			
			for _, ItemContainer in next, MainWindow:GetChildren() do
				if ItemContainer.Name == "ItemContainer" then
					ItemContainer.Visible = false
				end
			end

			
			if _TabTitle then
				TweenService:Create(_TabTitle, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0, TextSize = 14}):Play()
				_TabTitle.Font = Enum.Font.GothamBlack
			end
			if _TabIco then
				TweenService:Create(_TabIco, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0, TextSize = 16, TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text}):Play()
			end

			
			local _cx = sbOpen and SB_WIDE or SB_THIN
			Container.Size     = UDim2.new(1, -_cx, 1, -50)
			Container.Position = UDim2.new(0, _cx, 0, 38)
			Container.Visible  = true
			if not TabConfig.Columns then
				task.defer(function()
					local ll = Container:FindFirstChildOfClass("UIListLayout")
					if ll then Container.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 30) end
				end)
			end
			
			TweenService:Create(Container,
				TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{Position = UDim2.new(0, _cx, 0, 50)}
			):Play()
			
			local _fade = MainWindow:FindFirstChild("__FadeOverlay")
			if not _fade then
				_fade = Create("Frame", {
					Name                   = "__FadeOverlay",
					BackgroundColor3       = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Main,
					BackgroundTransparency = 0,
					BorderSizePixel        = 0,
					Size                   = UDim2.new(1, -_cx, 1, -50),
					Position               = UDim2.new(0, _cx, 0, 50),
					ZIndex                 = 200,
					Parent                 = MainWindow
				})
			end
			_fade.Size                   = UDim2.new(1, -_cx, 1, -50)
			_fade.Position               = UDim2.new(0, _cx, 0, 50)
			_fade.BackgroundTransparency = 0
			_fade.Visible                = true
			TweenService:Create(_fade,
				TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{BackgroundTransparency = 1}
			):Play()
			task.delay(0.32, function() if _fade and _fade.Parent then _fade.Visible = false end end)
		end
		AddConnection(TabFrame.MouseButton1Click, _doTabClick)
		if _regEntry then _regEntry.ClickFn = _doTabClick end

		local function GetElements(ItemParent)
			local ElementFunction = {}

			function ElementFunction:AddLabel(Text)
				local LabelFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size                = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 0.7,
					Parent              = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size     = UDim2.new(1, -12, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font     = Enum.Font.GothamBold,
						Name     = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")
				local LabelFunction = {}
				function LabelFunction:Set(ToChange) LabelFrame.Content.Text = ToChange end
				return LabelFunction
			end

			function ElementFunction:AddParagraph(Text, Content)
				Text    = Text    or "Text"
				Content = Content or "Content"
				local ParagraphFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size                = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 0.7,
					Parent              = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size     = UDim2.new(1, -12, 0, 14),
						Position = UDim2.new(0, 12, 0, 10),
						Font     = Enum.Font.GothamBold,
						Name     = "Title"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Label", "", 13), {
						Size        = UDim2.new(1, -24, 0, 0),
						Position    = UDim2.new(0, 12, 0, 26),
						Font        = Enum.Font.GothamSemibold,
						Name        = "Content",
						TextWrapped = true
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")
				local function resizeParagraph()
					ParagraphFrame.Content.Size = UDim2.new(1, -24, 0, ParagraphFrame.Content.TextBounds.Y)
					ParagraphFrame.Size         = UDim2.new(1, 0, 0, ParagraphFrame.Content.TextBounds.Y + 35)
				end
				AddConnection(ParagraphFrame.Content:GetPropertyChangedSignal("Text"), resizeParagraph)
				AddConnection(ParagraphFrame:GetPropertyChangedSignal("AbsoluteSize"), resizeParagraph)
				ParagraphFrame.Content.Text = Content
				task.defer(resizeParagraph)
				local ParagraphFunction = {}
				function ParagraphFunction:Set(ToChange) ParagraphFrame.Content.Text = ToChange end
				return ParagraphFunction
			end

			
			function ElementFunction:AddColorpicker(CPConfig)
				CPConfig          = CPConfig or {}
				CPConfig.Name     = CPConfig.Name     or "Colorpicker"
				CPConfig.Default  = CPConfig.Default  or Color3.fromRGB(255, 0, 80)
				CPConfig.Callback = CPConfig.Callback or function() end
				CPConfig.Flag     = CPConfig.Flag     or nil
				local col   = CPConfig.Default
				local alpha = CPConfig.DefaultAlpha or 0
				local hh, ss, vv = Color3.toHSV(col)
				local expanded = false

				local baseH = 38
				local openH = CPConfig.UseAlpha and 132 or 118
				local CPFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1, 0, 0, baseH), BackgroundTransparency = 0.7, ClipsDescendants = true, Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", CPConfig.Name, 15), {Size = UDim2.new(1, -70, 0, 38), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, ClipsDescendants = true, Name = "Content"}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")
				
				local preview = Create("Frame", {BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(0, 34, 0, 22), Position = UDim2.new(1, -46, 0, 8), Parent = CPFrame})
				Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = preview})
				Create("UIStroke", {Color = Color3.fromRGB(90,30,140), Thickness = 1, Parent = preview})
				local clickBtn = Create("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Position = UDim2.new(0,0,0,0), Parent = CPFrame})

				
				local svBox = Create("ImageLabel", {Image = "rbxassetid://4155801252", BackgroundColor3 = Color3.fromHSV(hh,1,1), BorderSizePixel = 0, Size = UDim2.new(1, -24, 0, 50), Position = UDim2.new(0, 12, 0, 42), Parent = CPFrame})
				Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = svBox})
				local svCur = Create("Frame", {BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0, Size = UDim2.new(0, 6, 0, 6), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(ss, 0, 1-vv, 0), Parent = svBox})
				Create("UICorner", {CornerRadius = UDim.new(1,0), Parent = svCur})
				
				local hueBar = Create("Frame", {BorderSizePixel = 0, Size = UDim2.new(1, -24, 0, 12), Position = UDim2.new(0, 12, 0, 98), Parent = CPFrame})
				Create("UICorner", {CornerRadius = UDim.new(1,0), Parent = hueBar})
				Create("UIGradient", {Parent = hueBar, Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)), ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)),
					ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,255,0)), ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),
					ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,0,255)), ColorSequenceKeypoint.new(0.83,Color3.fromRGB(255,0,255)),
					ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))})})
				local hueCur = Create("Frame", {BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 2), Position = UDim2.new(hh, 0, 0, -1), Parent = hueBar})
				
				local alphaBar, alphaCur, alphaGrad
				if CPConfig.UseAlpha then
					alphaBar = Create("Frame", {BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(1, -24, 0, 12), Position = UDim2.new(0, 12, 0, 114), Parent = CPFrame})
					Create("UICorner", {CornerRadius = UDim.new(1,0), Parent = alphaBar})
					alphaGrad = Create("UIGradient", {Parent = alphaBar, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)})})
					alphaCur = Create("Frame", {BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0, Size = UDim2.new(0,3,1,2), Position = UDim2.new(1-alpha,0,0,-1), Parent = alphaBar})
				end

				local function fireCB()
					if CPConfig.UseAlpha then CPConfig.Callback(col, alpha) else CPConfig.Callback(col) end
				end
				local function refresh()
					col = Color3.fromHSV(hh, ss, vv)
					svBox.BackgroundColor3 = Color3.fromHSV(hh,1,1)
					preview.BackgroundColor3 = col
					if alphaBar then alphaBar.BackgroundColor3 = col end
					if CPConfig.Flag then DuvomeLibrary.Flags[CPConfig.Flag] = {Value = col, Type = "Colorpicker"} end
				end

				clickBtn.MouseButton1Click:Connect(function()
					expanded = not expanded
					TweenService:Create(CPFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 0, expanded and openH or baseH)}):Play()
				end)

				local dragSV, dragHue, dragA = false, false, false
				svBox.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragSV=true end end)
				hueBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragHue=true end end)
				if alphaBar then alphaBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragA=true end end) end
				AddConnection(UserInputService.InputEnded, function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then if dragSV or dragHue or dragA then fireCB() end dragSV=false dragHue=false dragA=false end end)
				AddConnection(UserInputService.InputChanged, function(i)
					if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
					if dragSV then
						ss = math.clamp((i.Position.X - svBox.AbsolutePosition.X)/svBox.AbsoluteSize.X, 0, 1)
						vv = 1 - math.clamp((i.Position.Y - svBox.AbsolutePosition.Y)/svBox.AbsoluteSize.Y, 0, 1)
						svCur.Position = UDim2.new(ss,0,1-vv,0) refresh() fireCB()
					elseif dragHue then
						hh = math.clamp((i.Position.X - hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X, 0, 1)
						hueCur.Position = UDim2.new(hh,0,0,-1) refresh() fireCB()
					elseif dragA and alphaBar then
						local a = math.clamp((i.Position.X - alphaBar.AbsolutePosition.X)/alphaBar.AbsoluteSize.X, 0, 1)
						alpha = 1 - a
						alphaCur.Position = UDim2.new(1-alpha,0,0,-1) fireCB()
					end
				end)
				refresh()

				local CPFunction = {}
				function CPFunction:Set(c) hh,ss,vv = Color3.toHSV(c) svCur.Position=UDim2.new(ss,0,1-vv,0) hueCur.Position=UDim2.new(hh,0,0,-1) refresh() end
				function CPFunction:SetVisible(v) CPFrame.Visible = v end
				return CPFunction
			end

			
			local function MakePopover(anchorFrame, items)
				local pop = Create("Frame", {
					BackgroundColor3       = Color3.fromRGB(18, 6, 36),
					BackgroundTransparency = 1,
					BorderSizePixel        = 0,
					Size                   = UDim2.new(0, 0, 0, 0),
					ClipsDescendants       = true,
					Visible                = false,
					ZIndex                 = 60,
					Parent                 = Duvome
				})
				AddThemeObject(pop, "Second")
				
				local clickBlocker = Create("TextButton", {
					Text = "", BackgroundTransparency = 1, BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0), ZIndex = 59, AutoButtonColor = false,
					Parent = pop
				})
				Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = pop})
				local _popStroke = Create("UIStroke", {Color = Color3.fromRGB(90, 30, 140), Thickness = 1, Parent = pop})
				AddThemeObject(_popStroke, "Stroke")
				local popContent = Create("Frame", {
					BackgroundTransparency = 1, BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0), ZIndex = 61, Parent = pop
				})
				local popList = Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = popContent})
				Create("UIPadding", {PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8), Parent=popContent})

				for _, item in ipairs(items) do
					if item.Type == "slider" then
						local val = item.Default or item.Min
						local row = Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,36), ZIndex=62, Parent=popContent})
						AddThemeObject(Create("TextLabel", {Text=item.Name, Font=Enum.Font.GothamBold, TextSize=12,
							TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text, BackgroundTransparency=1,
							Size=UDim2.new(1,-32,0,14), ZIndex=62, Parent=row}), "Text")
						local valLbl = AddThemeObject(Create("TextLabel", {Text=tostring(val), Font=Enum.Font.GothamBold, TextSize=12,
							TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].TextDark, BackgroundTransparency=1,
							Size=UDim2.new(0,30,0,14), Position=UDim2.new(1,-30,0,0),
							TextXAlignment=Enum.TextXAlignment.Right, ZIndex=62, Parent=row}), "TextDark")
						local track = AddThemeObject(Create("Frame", {BackgroundColor3=Color3.fromRGB(35,12,60),
							BorderSizePixel=0, Size=UDim2.new(1,0,0,6), Position=UDim2.new(0,0,0,24), ZIndex=62, Parent=row}), "Main")
						Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=track})
						local pct = (val-item.Min)/math.max(1,item.Max-item.Min)
						local fill = AddThemeObject(Create("Frame", {BackgroundColor3=Color3.fromRGB(130,55,210),
							BorderSizePixel=0, Size=UDim2.new(pct,0,1,0), ZIndex=63, Parent=track}), "Stroke")
						Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=fill})
						local knob = Create("Frame", {BackgroundColor3=Color3.fromRGB(255,255,255),
							BorderSizePixel=0, Size=UDim2.new(0,12,0,12),
							Position=UDim2.new(pct,-6,0.5,-6), ZIndex=64, Parent=track})
						Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=knob})
						local drag = false
						track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true end end)
						UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
						UserInputService.InputChanged:Connect(function(i)
							if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
								local rel = math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
								val = math.floor(item.Min+rel*(item.Max-item.Min))
								fill.Size = UDim2.new(rel,0,1,0)
								knob.Position = UDim2.new(rel,-6,0.5,-6)
								valLbl.Text = tostring(val)
								item.Callback(val)
							end
						end)
					elseif item.Type == "input" then
						local row = Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,34), ZIndex=62, Parent=popContent})
						AddThemeObject(Create("TextLabel", {Text=item.Name, Font=Enum.Font.GothamBold, TextSize=12,
							TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text, BackgroundTransparency=1,
							Size=UDim2.new(0.45,0,1,0), ZIndex=62, Parent=row}), "Text")
						local box = AddThemeObject(Create("TextBox", {Text=tostring(item.Default or ""), Font=Enum.Font.Gotham, TextSize=12,
							BorderSizePixel=0, Size=UDim2.new(0.55,-4,0,24), Position=UDim2.new(0.45,4,0.5,-12),
							TextXAlignment=Enum.TextXAlignment.Center, ZIndex=62, ClearTextOnFocus=false, Parent=row}), "Text")
						-- a TextBox only gets TextColor3 from AddThemeObject, so its fill
						-- needs painting separately
						AddThemePainter(function(theme)
							if box.Parent then box.BackgroundColor3 = theme.Second end
						end)
						Create("UICorner", {CornerRadius=UDim.new(0,4), Parent=box})
						local _inStroke = Create("UIStroke", {Color=Color3.fromRGB(80,30,130), Thickness=1, Parent=box})
						AddThemeObject(_inStroke, "Stroke")
						box.FocusLost:Connect(function() item.Callback(box.Text) end)
					elseif item.Type == "keybind" then
						local row = Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,34), ZIndex=62, Parent=popContent})
						AddThemeObject(Create("TextLabel", {Text="Keybind", Font=Enum.Font.GothamBold, TextSize=12,
							TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text, BackgroundTransparency=1,
							Size=UDim2.new(0.5,0,1,0), ZIndex=62, Parent=row}), "Text")
						local kbBox = Create("TextButton", {
							Text = item.Default and (item.Default.Name or tostring(item.Default)) or "None",
							Font=Enum.Font.GothamBold, TextSize=12,
							TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text, BackgroundColor3=Color3.fromRGB(30,10,55),
							BorderSizePixel=0, Size=UDim2.new(0.45,0,0,24), Position=UDim2.new(0.55,0,0.5,-12),
							ZIndex=62, Parent=row,
						})
						AddThemeObject(kbBox, "Second")
						Create("UICorner", {CornerRadius=UDim.new(0,4), Parent=kbBox})
						local _kbStroke = Create("UIStroke", {Color=Color3.fromRGB(80,30,130), Thickness=1, Parent=kbBox})
						AddThemeObject(_kbStroke, "Stroke")

						
						DuvomeLibrary._boundKeys = DuvomeLibrary._boundKeys or {}
						local boundKey = item.Default
						local listening = false          
						local _blockUntil = 0            
						local function keyNameOf(k) return k and (k.Name or tostring(k)) or nil end

						
						if boundKey then local n=keyNameOf(boundKey) DuvomeLibrary._boundKeys[n] = (DuvomeLibrary._boundKeys[n] or 0) + 1 end

						
						AddConnection(UserInputService.InputBegan, function(inp, gpe)
							if gpe then return end
							if listening then return end                       
							if os.clock() < _blockUntil then return end        
							if UserInputService:GetFocusedTextBox() then return end
							if not boundKey then return end
							if inp.KeyCode == boundKey or inp.UserInputType == boundKey then
								if item.OnPress then item.OnPress()
								elseif item.Callback then item.Callback(boundKey) end
							end
						end)

						kbBox.MouseButton1Click:Connect(function()
							listening = true
							kbBox.Text = "..."
							local conn
							conn = UserInputService.InputBegan:Connect(function(inp)
								if not listening then return end
								
								if inp.KeyCode == Enum.KeyCode.Backspace then
									listening = false
									conn:Disconnect()
									if boundKey then local n=keyNameOf(boundKey) DuvomeLibrary._boundKeys[n] = math.max(0,(DuvomeLibrary._boundKeys[n] or 1)-1) end
									kbBox.Text = "None"
									boundKey = nil
									if item.OnBind then item.OnBind(nil) end
									return
								end
								if inp.KeyCode ~= Enum.KeyCode.Unknown or inp.UserInputType == Enum.UserInputType.MouseButton1 then
									local key = inp.KeyCode ~= Enum.KeyCode.Unknown and inp.KeyCode or inp.UserInputType
									local kn = keyNameOf(key)
									
									if kn ~= keyNameOf(boundKey) and (DuvomeLibrary._boundKeys[kn] or 0) > 0 then
										DuvomeLibrary:MakeNotification({Name="Key In Use", Content=kn.." is already bound to something else.", Type="warning", Time=3})
										listening = false
										conn:Disconnect()
										kbBox.Text = boundKey and keyNameOf(boundKey) or "None"
										return
									end
									listening = false
									conn:Disconnect()
									
									if boundKey then local on=keyNameOf(boundKey) DuvomeLibrary._boundKeys[on] = math.max(0,(DuvomeLibrary._boundKeys[on] or 1)-1) end
									boundKey = key
									DuvomeLibrary._boundKeys[kn] = (DuvomeLibrary._boundKeys[kn] or 0) + 1
									kbBox.Text = kn
									_blockUntil = os.clock() + 0.25   
									if item.OnBind then item.OnBind(key) end
								end
							end)
						end)
					elseif item.Type == "toggle" then
						local state = item.Default == true
						local row = Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,34), ZIndex=62, Parent=popContent})
						AddThemeObject(Create("TextLabel", {Text=item.Name, Font=Enum.Font.GothamBold, TextSize=12,
							TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text, BackgroundTransparency=1,
							Size=UDim2.new(0.7,0,1,0), ZIndex=62, Parent=row}), "Text")
						-- On used the theme colour but Off was a fixed purple, and the
						-- registration only happened while it was on, so a themed panel
						-- still showed purple switches.
						local function switchColour(theme)
							theme = theme or DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme]
							return state and theme.Stroke or theme.Second
						end
						local tBtn = Create("TextButton", {Text="", BackgroundColor3=switchColour(),
							BorderSizePixel=0, Size=UDim2.new(0,36,0,18), Position=UDim2.new(1,-36,0.5,-9), ZIndex=62, Parent=row})
						AddThemePainter(function(theme)
							if tBtn.Parent then tBtn.BackgroundColor3 = switchColour(theme) end
						end)
						Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=tBtn})
						local dot = Create("Frame", {BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0,
							Size=UDim2.new(0,14,0,14), Position=state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7), ZIndex=63, Parent=tBtn})
						Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=dot})
						tBtn.MouseButton1Click:Connect(function()
							state = not state
							TweenService:Create(tBtn, TweenInfo.new(0.2), {BackgroundColor3=switchColour()}):Play()
							TweenService:Create(dot, TweenInfo.new(0.2), {Position=state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
							item.Callback(state)
						end)
					elseif item.Type == "colorpicker" then
						local col = item.Default or Color3.fromRGB(255,255,255)
						local alpha = item.DefaultAlpha or 0  
						local h, s, v = Color3.toHSV(col)
						local rowH = item.UseAlpha and 102 or 88
						local row = Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,rowH), ZIndex=62, Parent=popContent})
						AddThemeObject(Create("TextLabel", {Text=item.Name, Font=Enum.Font.GothamBold, TextSize=12,
							TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text, BackgroundTransparency=1,
							Size=UDim2.new(1,0,0,14), ZIndex=62, Parent=row}), "Text")
						local preview = Create("Frame", {BackgroundColor3=col, BorderSizePixel=0,
							Size=UDim2.new(0,28,0,28), Position=UDim2.new(1,-28,0,0), ZIndex=63, Parent=row})
						Create("UICorner", {CornerRadius=UDim.new(0,5), Parent=preview})
						AddThemeObject(Create("UIStroke", {Thickness=1, Parent=preview}), "Stroke")
						
						local svBox = Create("ImageLabel", {Image="rbxassetid://4155801252",
							BackgroundColor3=Color3.fromHSV(h,1,1), BorderSizePixel=0,
							Size=UDim2.new(1,0,0,50), Position=UDim2.new(0,0,0,18), ZIndex=62, Parent=row})
						Create("UICorner", {CornerRadius=UDim.new(0,4), Parent=svBox})
						local svCursor = Create("Frame", {BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0,
							Size=UDim2.new(0,6,0,6), AnchorPoint=Vector2.new(0.5,0.5),
							Position=UDim2.new(s,0,1-v,0), ZIndex=63, Parent=svBox})
						Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=svCursor})
						
						local hueBar = Create("Frame", {BorderSizePixel=0, Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,0,72), ZIndex=62, Parent=row})
						Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=hueBar})
						local hueGrad = Create("UIGradient", {Parent=hueBar, Color=ColorSequence.new({
							ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),
							ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)),
							ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,255,0)),
							ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),
							ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,0,255)),
							ColorSequenceKeypoint.new(0.83,Color3.fromRGB(255,0,255)),
							ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0)),
						})})
						local hueCursor = Create("Frame", {BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0,
							Size=UDim2.new(0,3,1,2), Position=UDim2.new(h,0,0,-1), ZIndex=63, Parent=hueBar})
						
						local alphaBar, alphaCursor, alphaGrad
						if item.UseAlpha then
							alphaBar = Create("Frame", {BackgroundColor3=col, BorderSizePixel=0, Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,0,88), ZIndex=62, Parent=row})
							Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=alphaBar})
							
							alphaGrad = Create("UIGradient", {Parent=alphaBar, Transparency=NumberSequence.new({
								NumberSequenceKeypoint.new(0, 1),
								NumberSequenceKeypoint.new(1, 0),
							})})
							
							alphaCursor = Create("Frame", {BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0,
								Size=UDim2.new(0,3,1,2), Position=UDim2.new(1-alpha,0,0,-1), ZIndex=63, Parent=alphaBar})
						end
						local function fire()
							col = Color3.fromHSV(h,s,v)
							if alphaBar then alphaBar.BackgroundColor3 = col end
							preview.BackgroundColor3 = col
							svBox.BackgroundColor3 = Color3.fromHSV(h,1,1)
							if item.UseAlpha then item.Callback(col, alpha) else item.Callback(col) end
						end
						local dragSV, dragHue, dragAlpha = false,false,false
						svBox.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragSV=true end end)
						hueBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragHue=true end end)
						if alphaBar then alphaBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragAlpha=true end end) end
						UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then
							local wasDragging = dragSV or dragHue or dragAlpha
							dragSV=false dragHue=false dragAlpha=false
							if wasDragging and item.OnSelect then
								if item.UseAlpha then item.OnSelect(col, alpha) else item.OnSelect(col) end
							end
						end end)
						UserInputService.InputChanged:Connect(function(i)
							if i.UserInputType~=Enum.UserInputType.MouseMovement then return end
							if dragSV then
								s = math.clamp((i.Position.X-svBox.AbsolutePosition.X)/svBox.AbsoluteSize.X,0,1)
								v = 1-math.clamp((i.Position.Y-svBox.AbsolutePosition.Y)/svBox.AbsoluteSize.Y,0,1)
								svCursor.Position = UDim2.new(s,0,1-v,0); fire()
							elseif dragHue then
								h = math.clamp((i.Position.X-hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X,0,1)
								hueCursor.Position = UDim2.new(h,0,0,-1); fire()
							elseif dragAlpha and alphaBar then
								local a = math.clamp((i.Position.X-alphaBar.AbsolutePosition.X)/alphaBar.AbsoluteSize.X,0,1)
								alpha = 1-a; alphaCursor.Position = UDim2.new(a,0,0,-1); fire()
							end
						end)
					elseif item.Type == "button" then
						-- Action row: lets a gear hold things like Refresh or Delete
						-- instead of them each needing their own control in the panel.
						local row = Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,20), ZIndex=62, Parent=popContent})
						-- Styled like the other popover rows: plain label weight, no
						-- filled background, so it does not shout next to them.
						local btn = Create("TextButton", {
							Text = item.Name or "Action",
							Font = Enum.Font.GothamBold, TextSize = 12,
							TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text,
							BackgroundTransparency = 1,
							BorderSizePixel = 0, AutoButtonColor = false,
							TextXAlignment = Enum.TextXAlignment.Center,
							Size = UDim2.new(1,0,1,0), ZIndex = 63, Parent = row,
						})
						AddThemeObject(btn, "Text")
						btn.MouseEnter:Connect(function()
							btn.TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke
						end)
						btn.MouseLeave:Connect(function()
							btn.TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text
						end)
						btn.MouseButton1Click:Connect(function()
							if item.OnClick then pcall(item.OnClick) end
						end)
					end
				end

				local popW, popH = 0, 0
				local followConn
				local function updatePos()
					local ap = anchorFrame.AbsolutePosition
					local as = anchorFrame.AbsoluteSize
					pop.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 4)
				end
				local function showPop()
					task.defer(function()
						local ap = anchorFrame.AbsolutePosition
						local as = anchorFrame.AbsoluteSize
						local h  = math.max(popList.AbsoluteContentSize.Y + 20, 60)
						local w  = math.max(as.X, 160)
						popW, popH = w, h
						pop.Size                   = UDim2.new(0, w, 0, 0)
						pop.Position               = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 4)
						pop.BackgroundTransparency = 1
						pop.Visible                = true
						TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
							{Size = UDim2.new(0, w, 0, h), BackgroundTransparency = 0}):Play()
						if followConn then followConn:Disconnect() end
						followConn = RunService.RenderStepped:Connect(updatePos)
					end)
				end
				local function hidePop()
					if followConn then followConn:Disconnect() followConn = nil end
					TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
						{Size = UDim2.new(0, popW, 0, 0), BackgroundTransparency = 1}):Play()
					task.delay(0.27, function() pop.Visible = false end)
				end
				UserInputService.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 and pop.Visible then
						local mx, my = inp.Position.X, inp.Position.Y
						local px, py = pop.AbsolutePosition.X, pop.AbsolutePosition.Y
						local pw, ph = pop.AbsoluteSize.X, pop.AbsoluteSize.Y
						if mx < px or mx > px+pw or my < py or my > py+ph then
							hidePop() popOpen = false
						end
					end
				end)
				local popOpen = false
				
				DuvomeLibrary._popovers = DuvomeLibrary._popovers or {}
				table.insert(DuvomeLibrary._popovers, {
					frame = pop,
					forceClose = function()
						if followConn then followConn:Disconnect() followConn = nil end
						pop.Size = UDim2.new(0, popW, 0, 0)
						pop.BackgroundTransparency = 1
						pop.Visible = false
						popOpen = false
					end
				})
				return pop, showPop, hidePop, function() return popOpen end, function(v) popOpen = v end
			end

			function ElementFunction:AddButton(ButtonConfig)
				ButtonConfig          = ButtonConfig or {}
				ButtonConfig.Name     = ButtonConfig.Name     or "Button"
				ButtonConfig.Callback = ButtonConfig.Callback or function() end
				ButtonConfig.Icon     = ButtonConfig.Icon     or "rbxassetid://3944703587"
				local Button = {}
				local Click  = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})
				local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size   = UDim2.new(1, 0, 0, 33),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name, 15), {
						Size     = UDim2.new(1, -42, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font     = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = false,
						ClipsDescendants = true,
						Name     = "Content"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Image", ButtonConfig.Icon), {
						Size     = UDim2.new(0, 20, 0, 20),
						Position = UDim2.new(1, -30, 0, 7)
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					Click
				}), "Second")
				local btnSmooth = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				local btnFast   = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				local function _S() return DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second end
				local function _Slight(n) local s=_S() return Color3.fromRGB(math.clamp(s.R*255+n,0,255), math.clamp(s.G*255+n,0,255), math.clamp(s.B*255+n,0,255)) end
				AddConnection(Click.MouseEnter, function()
					TweenService:Create(ButtonFrame, btnSmooth, {BackgroundColor3 = _Slight(4)}):Play()
					TweenService:Create(ButtonFrame.Content, btnSmooth, {TextSize = 15.5}):Play()
				end)
				AddConnection(Click.MouseLeave, function()
					TweenService:Create(ButtonFrame, btnSmooth, {BackgroundColor3 = _S()}):Play()
					TweenService:Create(ButtonFrame.Content, btnSmooth, {TextSize = 15}):Play()
				end)
				AddConnection(Click.MouseButton1Down, function()
					TweenService:Create(ButtonFrame, btnFast, {BackgroundColor3 = _Slight(8)}):Play()
					TweenService:Create(ButtonFrame.Content, btnFast, {TextSize = 14.5}):Play()
				end)
				AddConnection(Click.MouseButton1Up, function()
					TweenService:Create(ButtonFrame, btnSmooth, {BackgroundColor3 = _Slight(4)}):Play()
					TweenService:Create(ButtonFrame.Content, btnSmooth, {TextSize = 15.5}):Play()
					spawn(function() ButtonConfig.Callback() end)
				end)
				function Button:Set(ButtonText) ButtonFrame.Content.Text = ButtonText end

				
				if ButtonConfig.ShowKeybind then
					local _btnFlagId = (ButtonConfig.Flag or ButtonConfig.Name) .. "_btn"
					makeKeybindBox(ButtonFrame, -58, ButtonConfig.Keybind, nil, _btnFlagId, function()
						spawn(function() ButtonConfig.Callback() end)
					end)
					ButtonFrame:FindFirstChild("Content").Size = UDim2.new(1, -66, 1, 0)
				end

				
				if ButtonConfig.Options then
					local dotBtn = Create("TextButton", {
						Text             = "",
						BackgroundColor3 = Color3.fromRGB(30, 10, 55),
						BackgroundTransparency = 0,
						BorderSizePixel  = 0,
						Size             = UDim2.new(0, 24, 0, 24),
						Position         = UDim2.new(1, -58, 0.5, -12),
						ZIndex           = 5,
						Parent           = ButtonFrame
					})
					AddThemeObject(dotBtn, "Second")
					AddThemeObject(Create("TextLabel", {
						Text = "gear", FontFace = MakeBIconFont(), TextSize = 13,
						TextColor3 = Color3.fromRGB(140, 80, 200), BackgroundTransparency = 1,
						Size = UDim2.new(1,0,1,0), ZIndex = 6, Parent = dotBtn,
					}), "TextDark")
					Create("UICorner", {CornerRadius=UDim.new(0,5), Parent=dotBtn})
					local _pop, showP, hideP, isOpen, setOpen = MakePopover(dotBtn, ButtonConfig.Options)
					dotBtn.MouseButton1Click:Connect(function()
						if isOpen() then hideP() setOpen(false)
						else showP() setOpen(true) end
					end)
					ButtonFrame:FindFirstChild("Content").Size = UDim2.new(1, -66, 1, 0)
				end

				function Button:SetVisible(v) ButtonFrame.Visible = v end
				if ButtonConfig.Tooltip then AddTooltip(ButtonFrame, ButtonConfig.Tooltip) end
				return Button
			end

			function ElementFunction:AddToggle(ToggleConfig)
				ToggleConfig          = ToggleConfig or {}
				ToggleConfig.Name     = ToggleConfig.Name     or "Toggle"
				ToggleConfig.Default  = ToggleConfig.Default  or false
				ToggleConfig.Callback = ToggleConfig.Callback or function() end
				local _userColor      = ToggleConfig.Color   
				ToggleConfig.Color    = ToggleConfig.Color    or Color3.fromRGB(120, 50, 200)
				ToggleConfig.Flag     = ToggleConfig.Flag     or nil
				ToggleConfig.Save     = ToggleConfig.Save     or false
				local Toggle = {Value = ToggleConfig.Default, Save = ToggleConfig.Save, Type = "Toggle"}
				local Click  = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})
				
				local SwitchTrack = Create("Frame", {
					Size             = UDim2.new(0, 40, 0, 22),
					Position         = UDim2.new(1, -50, 0.5, -11),
					BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Divider,
					BorderSizePixel  = 0,
				})
				Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = SwitchTrack})
				local _swTrackStroke = Create("UIStroke", {Color = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke, Thickness = 1, Name = "Stroke", Parent = SwitchTrack})
				
				if not ToggleConfig.Default then
					AddThemeObject(SwitchTrack, "Divider")
					AddThemeObject(_swTrackStroke, "Stroke")
				end
				
				local SwitchKnob = Create("Frame", {
					Size             = UDim2.new(0, 16, 0, 16),
					Position         = UDim2.new(0, 3, 0.5, -8),
					BackgroundColor3 = Color3.fromRGB(160, 160, 180),
					BorderSizePixel  = 0,
					ZIndex           = 2,
					Parent           = SwitchTrack
				})
				Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = SwitchKnob})
				local ToggleFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size   = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name, 15), {
						Size     = UDim2.new(1, -70, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font     = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = false,
						ClipsDescendants = true,
						Name     = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					SwitchTrack,
					Click
				}), "Second")
				function Toggle:Set(Value)
					Toggle.Value = Value
					pcall(function()
						local tw = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
						if Toggle.Value then
							local onColor = _userColor or DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke
							TweenService:Create(SwitchTrack, tw, {BackgroundColor3 = onColor}):Play()
							do local _s=SwitchTrack:FindFirstChild("Stroke") if _s then TweenService:Create(_s, tw, {Color = onColor}):Play() end end
							TweenService:Create(SwitchKnob, tw, {Position = UDim2.new(0, 21, 0.5, -8), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
						else
							TweenService:Create(SwitchTrack, tw, {BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Divider}):Play()
							do local _s=SwitchTrack:FindFirstChild("Stroke") if _s then TweenService:Create(_s, tw, {Color = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke}):Play() end end
							TweenService:Create(SwitchKnob, tw, {Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Color3.fromRGB(160, 160, 180)}):Play()
						end
					end)
					ToggleConfig.Callback(Toggle.Value)
				end
				task.defer(function() Toggle:Set(Toggle.Value) end)
				local tgSmooth = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				local function _ts2() return DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second end
				AddConnection(Click.MouseEnter,      function() local c=_ts2() TweenService:Create(ToggleFrame, tgSmooth, {BackgroundColor3 = Color3.fromRGB(c.R*255+4, c.G*255+4, c.B*255+4)}):Play() end)
				AddConnection(Click.MouseLeave,      function() TweenService:Create(ToggleFrame, tgSmooth, {BackgroundColor3 = _ts2()}):Play() end)
				AddConnection(Click.MouseButton1Up,  function() local c=_ts2() TweenService:Create(ToggleFrame, tgSmooth, {BackgroundColor3 = Color3.fromRGB(c.R*255+4, c.G*255+4, c.B*255+4)}):Play() SaveCfg(game.GameId) Toggle:Set(not Toggle.Value) end)
				AddConnection(Click.MouseButton1Down, function() local c=_ts2() TweenService:Create(ToggleFrame, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(math.clamp(c.R*255+8,0,255), math.clamp(c.G*255+8,0,255), math.clamp(c.B*255+8,0,255))}):Play() end)
				if ToggleConfig.Flag then DuvomeLibrary.Flags[ToggleConfig.Flag] = Toggle end

				
				if ToggleConfig.ShowKeybind then
					local _togFlagId = (ToggleConfig.Flag or ToggleConfig.Name) .. "_tog"
					makeKeybindBox(ToggleFrame, -80, ToggleConfig.Keybind, nil, _togFlagId, function()
						Toggle:Set(not Toggle.Value)
					end)
					ToggleFrame:FindFirstChild("Content").Size = UDim2.new(1, -88, 1, 0)
				end

				
				if ToggleConfig.Options then
					local dotBtn = Create("TextButton", {
						Text             = "",
						BackgroundColor3 = Color3.fromRGB(30, 10, 55),
						BackgroundTransparency = 0,
						BorderSizePixel  = 0,
						Size             = UDim2.new(0, 24, 0, 24),
						Position         = UDim2.new(1, -78, 0.5, -12),
						ZIndex           = 5,
						Parent           = ToggleFrame
					})
					AddThemeObject(dotBtn, "Second")
					AddThemeObject(Create("TextLabel", {
						Text = "gear", FontFace = MakeBIconFont(), TextSize = 13,
						TextColor3 = Color3.fromRGB(140, 80, 200), BackgroundTransparency = 1,
						Size = UDim2.new(1,0,1,0), ZIndex = 6, Parent = dotBtn,
					}), "TextDark")
					Create("UICorner", {CornerRadius=UDim.new(0,5), Parent=dotBtn})
					local _pop, showP, hideP, isOpen, setOpen = MakePopover(dotBtn, ToggleConfig.Options)
					dotBtn.MouseButton1Click:Connect(function()
						if isOpen() then hideP() setOpen(false)
						else showP() setOpen(true) end
					end)
					
					local _hasKb = ToggleConfig.ShowKeybind == true
					if _hasKb then
						dotBtn.Position = UDim2.new(1, -106, 0.5, -12)
					end
					ToggleFrame:FindFirstChild("Content").Size = UDim2.new(1, _hasKb and -118 or -90, 1, 0)
				end

				function Toggle:SetVisible(v) ToggleFrame.Visible = v end
				if ToggleConfig.Tooltip then AddTooltip(ToggleFrame, ToggleConfig.Tooltip) end
				return Toggle
			end

			function ElementFunction:AddSlider(SliderConfig)
				SliderConfig           = SliderConfig or {}
				SliderConfig.Name      = SliderConfig.Name      or "Slider"
				SliderConfig.Min       = SliderConfig.Min       or 0
				SliderConfig.Max       = SliderConfig.Max       or 100
				SliderConfig.Increment = SliderConfig.Increment or 1
				SliderConfig.Default   = SliderConfig.Default   or 50
				SliderConfig.Callback  = SliderConfig.Callback  or function() end
				SliderConfig.ValueName = SliderConfig.ValueName or SliderConfig.Suffix or ""
				local _userColor = SliderConfig.Color ~= nil
				SliderConfig.Color     = SliderConfig.Color     or Color3.fromRGB(120, 50, 200)
				SliderConfig.Flag      = SliderConfig.Flag      or nil
				SliderConfig.Save      = SliderConfig.Save      or false
				local Slider   = {Value = SliderConfig.Default, Save = SliderConfig.Save, Type = "Slider"}
				local Dragging = false
				local SliderDrag = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 5), {
					Size                = UDim2.new(0, 0, 1, 0),
					BackgroundTransparency = 0.3,
					ClipsDescendants    = true
				}), {
					AddThemeObject(SetProps(MakeElement("Label", "value", 13), {
						Size             = UDim2.new(1, -12, 0, 14),
						Position         = UDim2.new(0, 12, 0, 6),
						Font             = Enum.Font.GothamBold,
						Name             = "Value",
						TextTransparency = 0
					}), "Text")
				})
				if not _userColor then AddThemeObject(SliderDrag, "Stroke") end
				-- the track behind the fill: it was left on the stock purple, so
				-- it stayed purple no matter which theme was picked
				local SliderBar = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 5), {
					Size                = UDim2.new(1, -24, 0, 26),
					Position            = UDim2.new(0, 12, 0, 30),
					BackgroundTransparency = 0.9
				}), {
					(function() local s = SetProps(MakeElement("Stroke"), {Color = SliderConfig.Color}) if not _userColor then AddThemeObject(s, "Stroke") end return s end)(),
					AddThemeObject(SetProps(MakeElement("Label", "value", 13), {
						Size             = UDim2.new(1, -12, 0, 14),
						Position         = UDim2.new(0, 12, 0, 6),
						Font             = Enum.Font.GothamBold,
						Name             = "Value",
						TextTransparency = 0.8
					}), "Text"),
					SliderDrag
				})
				if not _userColor then AddThemeObject(SliderBar, "Stroke") end
				local SliderFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size   = UDim2.new(1, 0, 0, 65),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 15), {
						Size     = UDim2.new(1, -12, 0, 14),
						Position = UDim2.new(0, 12, 0, 10),
						Font     = Enum.Font.GothamBold,
						Name     = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					SliderBar
				}), "Second")
				SliderBar.InputBegan:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = true end end)
				SliderBar.InputEnded:Connect(function(Input)  if Input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end end)
				UserInputService.InputChanged:Connect(function(Input)
					if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
						local SizeScale = math.clamp((Input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
						Slider:Set(SliderConfig.Min + ((SliderConfig.Max - SliderConfig.Min) * SizeScale))
						SaveCfg(game.GameId)
					end
				end)
				function Slider:Set(Value)
					self.Value = math.clamp(Round(Value, SliderConfig.Increment), SliderConfig.Min, SliderConfig.Max)
					TweenService:Create(SliderDrag, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale((self.Value - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min), 1)}):Play()
					SliderBar.Value.Text  = tostring(self.Value) .. " " .. SliderConfig.ValueName
					SliderDrag.Value.Text = tostring(self.Value) .. " " .. SliderConfig.ValueName
					if self._valueBox and not self._valueBox:IsFocused() then self._valueBox.Text = tostring(self.Value) end
					SliderConfig.Callback(self.Value)
				end

				
				local ValueBG = Create("Frame", {
					BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Main, BorderSizePixel = 0,
					Size = UDim2.new(0, 56, 0, 18), Position = UDim2.new(1, -68, 0, 8), ZIndex = 5, Parent = SliderFrame,
				})
				AddThemeObject(ValueBG, "Main")
				Create("UICorner", {CornerRadius = UDim.new(0,4), Parent = ValueBG})
				AddThemeObject(Create("UIStroke", {Thickness = 1, Parent = ValueBG}), "Stroke")
				local ValueBox = Create("TextBox", {
					Text = "", PlaceholderText = "", ClearTextOnFocus = true,
					Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(240, 240, 245),
					BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0), ZIndex = 6, Parent = ValueBG,
				})
				Slider._valueBox = ValueBox
				ValueBox.FocusLost:Connect(function()
					local n = tonumber(ValueBox.Text)
					if n then Slider:Set(n) SaveCfg(game.GameId)
					else ValueBox.Text = tostring(Slider.Value) end
				end)

				Slider:Set(Slider.Value)
				if SliderConfig.Flag then DuvomeLibrary.Flags[SliderConfig.Flag] = Slider end
				function Slider:SetVisible(v) SliderFrame.Visible = v end

				
				SliderFrame:FindFirstChild("Content").Size = UDim2.new(1, -80, 0, 14)

				return Slider
			end

			function ElementFunction:AddRangeSlider(Config)
				Config           = Config or {}
				Config.Name      = Config.Name      or "Range Slider"
				Config.Min       = Config.Min       or 0
				Config.Max       = Config.Max       or 100
				Config.Increment = Config.Increment or 1
				Config.DefaultMin= Config.DefaultMin or Config.Min
				Config.DefaultMax= Config.DefaultMax or Config.Max
				Config.ValueName = Config.ValueName or Config.Suffix or ""
				local _rangeUserColor = Config.Color
				Config.Color     = Config.Color     or Color3.fromRGB(120, 50, 200)
				Config.Callback  = Config.Callback  or function() end
				Config.Flag      = Config.Flag      or nil

				local RS = {MinValue = Config.DefaultMin, MaxValue = Config.DefaultMax, Type = "RangeSlider",
					Save = Config.Save or false}

				local Frame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255,255,255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 50), Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Config.Name, 15), {
						Size=UDim2.new(0.5,-12,0,16), Position=UDim2.new(0,12,0,6), Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=false, ClipsDescendants=true, Name="Content"}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
				}), "Second")

				local valLbl = AddThemeObject(Create("TextLabel", {Text="", Font=Enum.Font.GothamBold, TextSize=13,
					TextColor3=Color3.fromRGB(170,120,240), BackgroundTransparency=1,
					Size=UDim2.new(0.5,-16,0,16), Position=UDim2.new(0.5,4,0,6), TextXAlignment=Enum.TextXAlignment.Right, TextWrapped=false, ClipsDescendants=true, Parent=Frame}), "TextDark")

				local track = AddThemeObject(Create("Frame", {BackgroundColor3=Color3.fromRGB(35,12,60), BorderSizePixel=0,
					Size=UDim2.new(1,-24,0,6), Position=UDim2.new(0,12,0,34), Parent=Frame}), "Main")
				Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=track})
				local fill = Create("Frame", {BackgroundColor3=Config.Color, BorderSizePixel=0, Parent=track})
				if not _rangeUserColor then AddThemeObject(fill, "Stroke") end
				Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=fill})

				local function makeKnob()
					local k = Create("Frame", {BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0,
						Size=UDim2.new(0,14,0,14), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0,0,0.5,0), ZIndex=5, Parent=track})
					Create("UICorner", {CornerRadius=UDim.new(1,0), Parent=k})
					return k
				end
				local knobMin, knobMax = makeKnob(), makeKnob()

				local function pctOf(v) return (v-Config.Min)/math.max(1,(Config.Max-Config.Min)) end
				local function refresh()
					local pMin, pMax = pctOf(RS.MinValue), pctOf(RS.MaxValue)
					knobMin.Position = UDim2.new(pMin,0,0.5,0)
					knobMax.Position = UDim2.new(pMax,0,0.5,0)
					fill.Position = UDim2.new(pMin,0,0,0)
					fill.Size = UDim2.new(pMax-pMin,0,1,0)
					valLbl.Text = RS.MinValue.." - "..RS.MaxValue.." "..Config.ValueName
				end
				refresh()

				local dragging = nil  
				knobMin.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging="min" end end)
				knobMax.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging="max" end end)
				UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=nil end end)
				UserInputService.InputChanged:Connect(function(i)
					if not dragging then return end
					if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
					local rel = math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
					local raw = Config.Min + rel*(Config.Max-Config.Min)
					local val = math.floor(raw/Config.Increment+0.5)*Config.Increment
					-- When both handles sit on the same value they overlap, and the
					-- clamp below pins whichever one you grabbed: min can never
					-- exceed max, max can never fall below min, so a 0-0 range
					-- locks up. Hand the drag to the other handle instead.
					if dragging=="min" then
						if RS.MinValue == RS.MaxValue and val > RS.MinValue then
							dragging = "max"
							RS.MaxValue = val
						else
							RS.MinValue = math.min(val, RS.MaxValue)
						end
					else
						if RS.MinValue == RS.MaxValue and val < RS.MaxValue then
							dragging = "min"
							RS.MinValue = val
						else
							RS.MaxValue = math.max(val, RS.MinValue)
						end
					end
					refresh()
					Config.Callback(RS.MinValue, RS.MaxValue)
				end)

				function RS:Set(mn, mx) RS.MinValue=mn RS.MaxValue=mx refresh() Config.Callback(mn,mx) end
				if Config.Flag then DuvomeLibrary.Flags[Config.Flag] = RS end
				return RS
			end

			function ElementFunction:AddDropdown(DropdownConfig)
				DropdownConfig          = DropdownConfig or {}
				DropdownConfig.Name     = DropdownConfig.Name     or "Dropdown"
				DropdownConfig.Options  = DropdownConfig.Options  or {}
				DropdownConfig.Default  = DropdownConfig.Default  or ""
				DropdownConfig.Callback = DropdownConfig.Callback or function() end
				DropdownConfig.Flag     = DropdownConfig.Flag     or nil
				DropdownConfig.Save     = DropdownConfig.Save     or false
				DropdownConfig.MultiSelect = DropdownConfig.MultiSelect or false
				DropdownConfig.Search      = DropdownConfig.Search or false
				DropdownConfig.SelectAll   = DropdownConfig.SelectAll or false
				local Dropdown   = {Value = DropdownConfig.Default, Selected = {}, Options = DropdownConfig.Options, Buttons = {}, Toggled = false, Type = "Dropdown", Save = DropdownConfig.Save, Multi = DropdownConfig.MultiSelect}
				
				if Dropdown.Multi then
					if type(DropdownConfig.Default) == "table" then
						for _,v in ipairs(DropdownConfig.Default) do Dropdown.Selected[v] = true end
					end
				end
				local MaxElements = 5
				if not Dropdown.Multi and not table.find(Dropdown.Options, Dropdown.Value) then Dropdown.Value = "..." end
				local DropdownList      = MakeElement("List")
				local DropdownContainer = AddThemeObject(SetProps(SetChildren(MakeElement("ScrollFrame", Color3.fromRGB(40, 40, 40), 4), {
					DropdownList,
					Create("UICorner", {CornerRadius = UDim.new(0, 5)})
				}), {
					Parent           = ItemParent,
					Position         = UDim2.new(0, 0, 0, 38),
					Size             = UDim2.new(1, 0, 1, -38),
					ClipsDescendants = true,
					Visible          = false
				}), "Divider")
				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})
				local DropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size             = UDim2.new(1, 0, 0, 38),
					Parent           = ItemParent,
					ClipsDescendants = true
				}), {
					DropdownContainer,
					SetProps(SetChildren(MakeElement("TFrame"), {
						AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 15), {Size = UDim2.new(0.5, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, ClipsDescendants = true, Name = "Content"}), "Text"),
						AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {Size = UDim2.new(0, 20, 0, 20), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -30, 0.5, 0), ImageColor3 = Color3.fromRGB(240, 240, 240), Name = "Ico"}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Label", "Selected", 13), {Size = UDim2.new(0.5, -40, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), Font = Enum.Font.Gotham, Name = "Selected", TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, ClipsDescendants = true}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Frame"), {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), Name = "Line", Visible = false}), "Stroke"),
						Click
					}), {Size = UDim2.new(1, 0, 0, 38), ClipsDescendants = true, Name = "F"}),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					MakeElement("Corner")
				}), "Second")
				AddConnection(DropdownList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, DropdownList.AbsoluteContentSize.Y)
				end)

				
				local SearchBox
				if DropdownConfig.Search then
					local searchBG = Create("Frame", {BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Main, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 26), LayoutOrder = -2, Parent = DropdownContainer})
					AddThemeObject(searchBG, "Main")
					Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = searchBG})
					AddThemeObject(Create("UIStroke", {Thickness = 1, Parent = searchBG}), "Stroke")
					SearchBox = AddPlaceholder(Create("TextBox", {
						Text = "", PlaceholderText = "Search...", ClearTextOnFocus = false,
						Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(235,235,240),
						BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0), Parent = searchBG,
					}))
				end

				
				-- Custom actions live in the list itself rather than behind a gear.
				if DropdownConfig.Actions then
					local actRow = Create("Frame", {BackgroundTransparency = 1,
						Size = UDim2.new(1, -4, 0, 24), LayoutOrder = -2, Parent = DropdownContainer})
					local n = #DropdownConfig.Actions
					for idx, act in ipairs(DropdownConfig.Actions) do
						local b = Create("TextButton", {
							Text = act.Text or "Action", Font = Enum.Font.GothamBold, TextSize = 11,
							TextColor3 = Color3.fromRGB(235,235,240),
							BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Main,
							BorderSizePixel = 0,
							Size = UDim2.new(1 / n, -2, 1, 0),
							Position = UDim2.new((idx - 1) / n, 0, 0, 0),
							Parent = actRow})
						AddThemeObject(b, "Main")
						Create("UICorner", {CornerRadius = UDim.new(0,4), Parent = b})
						AddThemeObject(Create("UIStroke", {Thickness = 1, Parent = b}), "Stroke")
						b.MouseButton1Click:Connect(function()
							if act.OnClick then pcall(act.OnClick) end
						end)
					end
				end
				if DropdownConfig.SelectAll and DropdownConfig.MultiSelect then
					local btnRow = Create("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 24), LayoutOrder = -1, Parent = DropdownContainer})
					local function mkBtn(txt, xoff, w, cb)
						local b = Create("TextButton", {Text = txt, Font = Enum.Font.GothamBold, TextSize = 11,
							TextColor3 = Color3.fromRGB(235,235,240), BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Main,
							BorderSizePixel = 0, Size = UDim2.new(w, -2, 1, 0), Position = UDim2.new(xoff, 0, 0, 0), Parent = btnRow})
						AddThemeObject(b, "Main")
						Create("UICorner", {CornerRadius = UDim.new(0,4), Parent = b})
						AddThemeObject(Create("UIStroke", {Thickness = 1, Parent = b}), "Stroke")
						b.MouseButton1Click:Connect(cb)
						return b
					end
					mkBtn("Select All", 0, 0.5, function()
						for _, opt in ipairs(Dropdown.Options) do
							if not Dropdown.Selected[opt] then Dropdown:Set(opt) end
						end
						SaveCfg(game.GameId)
					end)
					mkBtn("Clear All", 0.5, 0.5, function()
						for _, opt in ipairs(Dropdown.Options) do
							if Dropdown.Selected[opt] then Dropdown:Set(opt) end
						end
						SaveCfg(game.GameId)
					end)
				end
				local function AddOptions(Options)
					for _, Option in pairs(Options) do
						local OptionBtn = SetProps(SetChildren(MakeElement("Button", Color3.fromRGB(40, 40, 40)), {
							MakeElement("Corner", 0, 6),
							AddThemeObject(SetProps(MakeElement("Label", Option, 13, 0.4), {Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -8, 1, 0), Name = "Title"}), "Text")
						}), {Parent = DropdownContainer, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, ClipsDescendants = true})
						OptionBtn.BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke
						
						DuvomeLibrary._dropdownOptions = DuvomeLibrary._dropdownOptions or {}
						table.insert(DuvomeLibrary._dropdownOptions, OptionBtn)
						AddConnection(OptionBtn.MouseButton1Click, function()
						Dropdown:Set(Option)
						SaveCfg(game.GameId)
						
						if Dropdown.Toggled and not Dropdown.Multi then
							Dropdown.Toggled = false
							DropdownFrame.F.Line.Visible = false
							DropdownContainer.Visible = false
							TweenService:Create(DropdownFrame.F.Ico, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 0}):Play()
							TweenService:Create(DropdownFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, 38)}):Play()
						end
					end)
						Dropdown.Buttons[Option] = OptionBtn
					end
				end
				function Dropdown:Refresh(Options, Delete)
					if Delete then for _,v in pairs(Dropdown.Buttons) do v:Destroy() end table.clear(Dropdown.Options) table.clear(Dropdown.Buttons) end
					Dropdown.Options = Options
					AddOptions(Dropdown.Options)
				end
				function Dropdown:Set(Value)
					if Dropdown.Multi then
						
						Dropdown.Selected[Value] = not Dropdown.Selected[Value] or nil
						
						local chosen = {}
						for _, opt in ipairs(Dropdown.Options) do
							local btn = Dropdown.Buttons[opt]
							if btn then
								if Dropdown.Selected[opt] then
									table.insert(chosen, opt)
									TweenService:Create(btn,TweenInfo.new(.15),{BackgroundTransparency=0}):Play()
									TweenService:Create(btn.Title,TweenInfo.new(.15),{TextTransparency=0}):Play()
								else
									TweenService:Create(btn,TweenInfo.new(.15),{BackgroundTransparency=1}):Play()
									TweenService:Create(btn.Title,TweenInfo.new(.15),{TextTransparency=0.4}):Play()
								end
							end
						end
						Dropdown.Value = chosen
						DropdownFrame.F.Selected.Text = #chosen > 0 and table.concat(chosen, ", ") or "None"
						return DropdownConfig.Callback(chosen)
					end
					if not table.find(Dropdown.Options, Value) then
						Dropdown.Value = "..."
						DropdownFrame.F.Selected.Text = Dropdown.Value
						for _, v in pairs(Dropdown.Buttons) do TweenService:Create(v,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=1}):Play() TweenService:Create(v.Title,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0.4}):Play() end
						return
					end
					Dropdown.Value = Value
					DropdownFrame.F.Selected.Text = Dropdown.Value
					for _, v in pairs(Dropdown.Buttons) do TweenService:Create(v,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=1}):Play() TweenService:Create(v.Title,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0.4}):Play() end
					TweenService:Create(Dropdown.Buttons[Value],TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
					TweenService:Create(Dropdown.Buttons[Value].Title,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0}):Play()
					return DropdownConfig.Callback(Dropdown.Value)
				end
				AddConnection(Click.MouseButton1Click, function()
					Dropdown.Toggled = not Dropdown.Toggled
					DropdownFrame.F.Line.Visible = Dropdown.Toggled
					DropdownContainer.Visible = Dropdown.Toggled
					local _rot = Dropdown.Toggled and 180 or 0
					TweenService:Create(DropdownFrame.F.Ico,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Rotation=_rot}):Play()
					local _extra = 0
					if SearchBox then _extra = _extra + 30 end
					if DropdownConfig.SelectAll and DropdownConfig.MultiSelect then _extra = _extra + 28 end
					if DropdownConfig.Actions then _extra = _extra + 28 end
					if #Dropdown.Options > MaxElements then
						local _ddSize = Dropdown.Toggled and UDim2.new(1,0,0,38+_extra+(MaxElements*28)) or UDim2.new(1,0,0,38)
						TweenService:Create(DropdownFrame,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=_ddSize}):Play()
					else
						local _ddSize2 = Dropdown.Toggled and UDim2.new(1,0,0,DropdownList.AbsoluteContentSize.Y+38) or UDim2.new(1,0,0,38)
						TweenService:Create(DropdownFrame,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=_ddSize2}):Play()
					end
				end)
				Dropdown:Refresh(Dropdown.Options, false)

				
				if SearchBox then
					SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
						local q = SearchBox.Text:lower()
						for opt, btn in pairs(Dropdown.Buttons) do
							btn.Visible = (q == "") or (tostring(opt):lower():find(q, 1, true) ~= nil)
						end
					end)
				end
				if Dropdown.Multi then
					
					local chosen = {}
					for _, opt in ipairs(Dropdown.Options) do
						local btn = Dropdown.Buttons[opt]
						if btn and Dropdown.Selected[opt] then
							table.insert(chosen, opt)
							btn.BackgroundTransparency = 0
							btn.Title.TextTransparency = 0
						end
					end
					Dropdown.Value = chosen
					DropdownFrame.F.Selected.Text = #chosen > 0 and table.concat(chosen, ", ") or "None"
				else
					Dropdown:Set(Dropdown.Value)
				end
				if DropdownConfig.Flag then DuvomeLibrary.Flags[DropdownConfig.Flag] = Dropdown end
				-- Gear popover, same idea as toggles. Uses the key "Gear" because
				-- a dropdown's "Options" is already its list of choices.
				-- Same gear slot, but the button runs an action instead of opening
				-- a popover. Used where the "setting" is really a panel.
				if DropdownConfig.GearAction then
					local actBtn = Create("TextButton", {
						Text = "", BackgroundColor3 = Color3.fromRGB(30, 10, 55),
						BorderSizePixel = 0, Size = UDim2.new(0, 24, 0, 24),
						Position = UDim2.new(1, -56, 0, 7), ZIndex = 7,
						Parent = DropdownFrame:FindFirstChild("F") or DropdownFrame
					})
					AddThemeObject(actBtn, "Second")
					AddThemeObject(Create("TextLabel", {
						Text = DropdownConfig.GearAction.Icon or "layout-fluid",
						FontFace = MakeBIconFont(), TextSize = 13,
						TextColor3 = Color3.fromRGB(140, 80, 200), BackgroundTransparency = 1,
						Size = UDim2.new(1,0,1,0), ZIndex = 8, Parent = actBtn,
					}), "TextDark")
					Create("UICorner", {CornerRadius=UDim.new(0,5), Parent=actBtn})
					local selLbl2 = (DropdownFrame:FindFirstChild("F") or DropdownFrame):FindFirstChild("Selected")
					if selLbl2 then selLbl2.Size = UDim2.new(0.5, -72, 1, 0) end
					actBtn.MouseButton1Click:Connect(function()
						if DropdownConfig.GearAction.OnClick then
							pcall(DropdownConfig.GearAction.OnClick)
						end
					end)
				end

				if DropdownConfig.Gear then
					-- shift left when a GearAction already occupies the first slot
					local slotX = DropdownConfig.GearAction and -84 or -56
					local dotBtn = Create("TextButton", {
						Text = "", BackgroundColor3 = Color3.fromRGB(30, 10, 55),
						BorderSizePixel = 0, Size = UDim2.new(0, 24, 0, 24),
						Position = UDim2.new(1, slotX, 0, 7), ZIndex = 7,
						Parent = DropdownFrame:FindFirstChild("F") or DropdownFrame
					})
					AddThemeObject(dotBtn, "Second")
					AddThemeObject(Create("TextLabel", {
						Text = "gear", FontFace = MakeBIconFont(), TextSize = 13,
						TextColor3 = Color3.fromRGB(140, 80, 200), BackgroundTransparency = 1,
						Size = UDim2.new(1,0,1,0), ZIndex = 8, Parent = dotBtn,
					}), "TextDark")
					Create("UICorner", {CornerRadius=UDim.new(0,5), Parent=dotBtn})
					-- The Selected label runs to the right edge, so shorten it to
					-- make room; otherwise the gear covers the chosen value.
					local selLbl = (DropdownFrame:FindFirstChild("F") or DropdownFrame):FindFirstChild("Selected")
					if selLbl then
						selLbl.Size = UDim2.new(0.5, DropdownConfig.GearAction and -100 or -72, 1, 0)
					end
					local _pop, showP, hideP, isOpen, setOpen = MakePopover(dotBtn, DropdownConfig.Gear)
					dotBtn.MouseButton1Click:Connect(function()
						if isOpen() then hideP() setOpen(false) else showP() setOpen(true) end
					end)
				end

				function Dropdown:SetVisible(v) DropdownFrame.Visible = v end
				return Dropdown
			end

			function ElementFunction:AddBind(BindConfig)
				BindConfig          = BindConfig or {}
				BindConfig.Name     = BindConfig.Name     or "Bind"
				BindConfig.Default  = BindConfig.Default  or Enum.KeyCode.Unknown
				BindConfig.Hold     = BindConfig.Hold     or false
				BindConfig.Mode     = BindConfig.Mode     or (BindConfig.Hold and "hold" or "press") 
				BindConfig.Interval = BindConfig.Interval or 0   
				BindConfig.Modifier = BindConfig.Modifier or nil 
				BindConfig.Callback = BindConfig.Callback or function() end
				BindConfig.Flag     = BindConfig.Flag     or nil
				BindConfig.Save     = BindConfig.Save     or false
				local Bind    = {Value, Binding = false, Type = "Bind", Save = BindConfig.Save, ToggleState = false}
				local Holding = false
				local _holdLoop = nil
				local function modifierHeld()
					if not BindConfig.Modifier then return true end
					local m = BindConfig.Modifier
					
					local pairs_ = {
						[Enum.KeyCode.LeftAlt]=Enum.KeyCode.RightAlt, [Enum.KeyCode.RightAlt]=Enum.KeyCode.LeftAlt,
						[Enum.KeyCode.LeftControl]=Enum.KeyCode.RightControl, [Enum.KeyCode.RightControl]=Enum.KeyCode.LeftControl,
						[Enum.KeyCode.LeftShift]=Enum.KeyCode.RightShift, [Enum.KeyCode.RightShift]=Enum.KeyCode.LeftShift,
					}
					if UserInputService:IsKeyDown(m) then return true end
					if pairs_[m] and UserInputService:IsKeyDown(pairs_[m]) then return true end
					return false
				end
				local Click   = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})
				local BindBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size        = UDim2.new(0, 24, 0, 24),
					Position    = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					ClipsDescendants = true
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 14), {Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Name = "Value"}), "Text")
				}), "Main")
				local BindFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size   = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 15), {Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, ClipsDescendants = true, Name = "Content"}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					BindBox, Click
				}), "Second")
				AddConnection(BindBox.Value:GetPropertyChangedSignal("Text"), function()
					local sz = TextService:GetTextSize(BindBox.Value.Text, 14, Enum.Font.GothamBold, Vector2.new(1000,24))
					local w = math.clamp(sz.X + 16, 24, 130)
					TweenService:Create(BindBox,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.new(0,w,0,24)}):Play()
					local contentLbl = BindFrame:FindFirstChild("Content")
					if contentLbl then
						TweenService:Create(contentLbl,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.new(1, -(w + 32), 1, 0)}):Play()
					end
				end)
				AddConnection(Click.InputEnded, function(Input) if Input.UserInputType==Enum.UserInputType.MouseButton1 then if Bind.Binding then return end Bind.Binding=true BindBox.Value.Text="" end end)
				AddConnection(UserInputService.InputBegan, function(Input)
					if UserInputService:GetFocusedTextBox() then return end
					if (Input.KeyCode.Name==Bind.Value or Input.UserInputType.Name==Bind.Value) and not Bind.Binding then
						if not modifierHeld() then return end  
						if BindConfig.Mode == "hold" then
							Holding = true
							BindConfig.Callback(true)
							if BindConfig.Interval and BindConfig.Interval > 0 then
								_holdLoop = task.spawn(function()
									while Holding do
										task.wait(BindConfig.Interval)
										if Holding then BindConfig.Callback(true) end
									end
								end)
							end
						elseif BindConfig.Mode == "toggle" then
							Bind.ToggleState = not Bind.ToggleState
							BindConfig.Callback(Bind.ToggleState)
						else 
							BindConfig.Callback()
						end
					elseif Bind.Binding then
						if Input.KeyCode == Enum.KeyCode.Backspace then
							Bind.Binding = false
							Bind.Value = "None"
							BindBox.Value.Text = "None"
							if BindConfig.OnClear then BindConfig.OnClear() end
							SaveCfg(game.GameId)
							return
						end
						local Key
						pcall(function() if not CheckKey(BlacklistedKeys,Input.KeyCode) then Key=Input.KeyCode end end)
						pcall(function() if CheckKey(WhitelistedMouse,Input.UserInputType) and not Key then Key=Input.UserInputType end end)
						Key=Key or Bind.Value
						local keyName = (type(Key)=="string" and Key) or Key.Name
						
						DuvomeLibrary._boundKeys = DuvomeLibrary._boundKeys or {}
						if keyName ~= Bind.Value and (DuvomeLibrary._boundKeys[keyName] or 0) > 0 then
							DuvomeLibrary:MakeNotification({Name="Key In Use", Content=keyName.." is already bound to something else.", Type="warning", Time=3})
							Bind.Binding = false
							BindBox.Value.Text = (type(Bind.Value)=="string" and Bind.Value) or "None"
							return
						end
						
						if type(Bind.Value)=="string" and DuvomeLibrary._boundKeys[Bind.Value] then
							DuvomeLibrary._boundKeys[Bind.Value] = math.max(0,(DuvomeLibrary._boundKeys[Bind.Value] or 1)-1)
						end
						DuvomeLibrary._boundKeys[keyName] = (DuvomeLibrary._boundKeys[keyName] or 0) + 1
						Bind:Set(Key); SaveCfg(game.GameId)
					end
				end)
				AddConnection(UserInputService.InputEnded, function(Input)
					if Input.KeyCode.Name==Bind.Value or Input.UserInputType.Name==Bind.Value then
						if BindConfig.Mode == "hold" and Holding then
							Holding=false
							if _holdLoop then task.cancel(_holdLoop) _holdLoop=nil end
							BindConfig.Callback(false)
						end
					end
				end)
				AddConnection(Click.MouseEnter,      function() TweenService:Create(BindFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundColor3=Color3.fromRGB(DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.R*255+3,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.G*255+3,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.B*255+3)}):Play() end)
				AddConnection(Click.MouseLeave,      function() TweenService:Create(BindFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second}):Play() end)
				AddConnection(Click.MouseButton1Up,  function() TweenService:Create(BindFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundColor3=Color3.fromRGB(DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.R*255+3,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.G*255+3,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.B*255+3)}):Play() end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(BindFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundColor3=Color3.fromRGB(DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.R*255+6,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.G*255+6,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.B*255+6)}):Play() end)
				function Bind:Set(Key) Bind.Binding=false Bind.Value=Key or Bind.Value Bind.Value=Bind.Value.Name or Bind.Value BindBox.Value.Text=Bind.Value end
				Bind:Set(BindConfig.Default)
				function Bind:SetVisible(v) BindFrame.Visible = v end
				if BindConfig.Flag then DuvomeLibrary.Flags[BindConfig.Flag] = Bind end
				return Bind
			end

			function ElementFunction:AddTextbox(TextboxConfig)
				TextboxConfig              = TextboxConfig or {}
				TextboxConfig.Name         = TextboxConfig.Name         or "Textbox"
				TextboxConfig.Default      = TextboxConfig.Default      or ""
				TextboxConfig.TextDisappear = TextboxConfig.TextDisappear or false
				TextboxConfig.Callback     = TextboxConfig.Callback     or function() end
				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})
				local TextboxActual = AddThemeObject(Create("TextBox", {
					Size               = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					TextColor3         = Color3.fromRGB(255, 255, 255),
					PlaceholderColor3  = Color3.fromRGB(210, 210, 210),
					PlaceholderText    = "Input",
					Font               = Enum.Font.GothamSemibold,
					TextXAlignment     = Enum.TextXAlignment.Center,
					TextSize           = 14,
					ClearTextOnFocus   = false
				}), "Text")
				local TextContainer = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size        = UDim2.new(0, 24, 0, 24),
					Position    = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					ClipsDescendants = true
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextboxActual
				}), "Main")
				local TextboxFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size   = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", TextboxConfig.Name, 15), {Size = UDim2.new(1, -130, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, Name = "Content"}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextContainer, Click
				}), "Second")

				-- Optional action buttons carried by the input itself, so things
				-- like "Load" sit on the field instead of as separate controls.
				if type(TextboxConfig.Actions) == "table" and #TextboxConfig.Actions > 0 then
					TextboxFrame.Size = UDim2.new(1, 0, 0, 38 + 26)
					local n = #TextboxConfig.Actions
					local row = Create("Frame", {
						BackgroundTransparency = 1, BorderSizePixel = 0,
						Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 0, 38),
						Parent = TextboxFrame,
					})
					for i, act in ipairs(TextboxConfig.Actions) do
						local b = Create("TextButton", {
							Text = act.Text or "Action",
							Font = Enum.Font.GothamBold, TextSize = 11,
							TextColor3 = Color3.fromRGB(235, 235, 240),
							BorderSizePixel = 0, AutoButtonColor = false,
							Size = UDim2.new(1 / n, -3, 1, 0),
							Position = UDim2.new((i - 1) / n, 0, 0, 0),
							Parent = row,
						})
						AddThemeObject(b, "Main")
						Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = b})
						AddThemeObject(Create("UIStroke", {Thickness = 1, Parent = b}), "Stroke")
						b.MouseButton1Click:Connect(function()
							-- hand over the current text so the action can use it
							if act.OnClick then pcall(act.OnClick, TextboxActual.Text) end
						end)
					end
				end

				local _resizing = false
				local function measureAndSize(text)
					local sz = TextService:GetTextSize(text, 14, Enum.Font.GothamSemibold, Vector2.new(1000,24))
					local w = math.clamp(sz.X + 24, 40, 140)
					return w
				end
				AddConnection(TextboxActual:GetPropertyChangedSignal("Text"), function()
					if _resizing then return end
					local w = measureAndSize(TextboxActual.Text)
					TweenService:Create(TextContainer,TweenInfo.new(0.45,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.new(0,w,0,24)}):Play()
				end)
				AddConnection(TextboxActual.FocusLost, function() TextboxConfig.Callback(TextboxActual.Text) if TextboxConfig.TextDisappear then TextboxActual.Text="" end end)
				_resizing = true
				TextboxActual.Text = TextboxConfig.Default
				local measureText = TextboxConfig.Default ~= "" and TextboxConfig.Default or "Input"
				TextContainer.Size = UDim2.new(0, measureAndSize(measureText), 0, 24)
				_resizing = false
				AddConnection(Click.MouseEnter,      function() TweenService:Create(TextboxFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundColor3=Color3.fromRGB(DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.R*255+3,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.G*255+3,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.B*255+3)}):Play() end)
				AddConnection(Click.MouseLeave,      function() TweenService:Create(TextboxFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second}):Play() end)
				-- Double-click selects everything, like a browser field, so it can
				-- be replaced or deleted in one go instead of held-backspace.
				local _lastClick = 0
				local function selectAllText()
					local t = TextboxActual.Text
					if t == "" then return end
					TextboxActual.CursorPosition = #t + 1
					TextboxActual.SelectionStart = 1
				end
				AddConnection(Click.MouseButton1Up,  function()
					TweenService:Create(TextboxFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundColor3=Color3.fromRGB(DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.R*255+3,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.G*255+3,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.B*255+3)}):Play()
					TextboxActual:CaptureFocus()
					local now = tick()
					if now - _lastClick < 0.35 then task.defer(selectAllText) end
					_lastClick = now
				end)
				AddConnection(Click.MouseButton1Down, function() TweenService:Create(TextboxFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundColor3=Color3.fromRGB(DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.R*255+6,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.G*255+6,DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second.B*255+6)}):Play() end)
			end

			function ElementFunction:AddSearch(SearchConfig)
				SearchConfig             = SearchConfig or {}
				SearchConfig.Name        = SearchConfig.Name        or "Search"
				SearchConfig.Items       = SearchConfig.Items       or {}
				SearchConfig.Callback    = SearchConfig.Callback    or function() end
				SearchConfig.Placeholder = SearchConfig.Placeholder or "Type to search..."

				
				local ResultsFrame = AddThemeObject(Create("Frame", {
					BackgroundTransparency = 0,
					BorderSizePixel        = 0,
					Size                   = UDim2.new(1, 0, 0, 0),
					ClipsDescendants       = true,
					ZIndex                 = 20,
				}), "Second")
				Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = ResultsFrame})
				AddThemeObject(Create("UIStroke", {Color = Color3.fromRGB(80, 25, 130), Thickness = 1, Parent = ResultsFrame}), "Stroke")
				Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = ResultsFrame})

				
				local SearchMain = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size   = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", SearchConfig.Name, 15), {
						Size     = UDim2.new(0.45, 0, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font     = Enum.Font.GothamBold,
						Name     = "Content"
					}), "Text"),
					
					AddThemeObject(Create("TextBox", {
						Text               = "",
						PlaceholderText    = SearchConfig.Placeholder,
						Font               = Enum.Font.Gotham,
						TextSize           = 13,
						BackgroundTransparency = 1,
						ClearTextOnFocus   = false,
						Size               = UDim2.new(0.52, -24, 0, 22),
						Position           = UDim2.new(0.45, 4, 0.5, -11),
						TextXAlignment     = Enum.TextXAlignment.Left,
						ZIndex             = 2,
						Name               = "SearchBox"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
				}), "Second")

				local SearchBox = SearchMain:FindFirstChild("SearchBox")

				
				ResultsFrame.Position = UDim2.new(0, 0, 1, 2)

				
				ResultsFrame.Parent   = Duvome  
				ResultsFrame.Size     = UDim2.new(0, 0, 0, 0)
				ResultsFrame.Visible  = false

				
				RunService.RenderStepped:Connect(function()
					if ResultsFrame.Visible then
						local ap = SearchMain.AbsolutePosition
						local as = SearchMain.AbsoluteSize
						ResultsFrame.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 2)
						ResultsFrame.Size     = UDim2.new(0, as.X, 0, ResultsFrame.Size.Y.Offset)
					end
				end)

				local function hideResults()
					for _, c in ipairs(ResultsFrame:GetChildren()) do
						if c:IsA("TextButton") then c:Destroy() end
					end
					TweenService:Create(ResultsFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Size = UDim2.new(0, ResultsFrame.Size.X.Offset, 0, 0)}):Play()
					task.delay(0.18, function() ResultsFrame.Visible = false end)
				end

				local function showResults(query)
					for _, c in ipairs(ResultsFrame:GetChildren()) do
						if c:IsA("TextButton") then c:Destroy() end
					end
					local q = query:lower()
					if q == "" then hideResults() return end

					local count = 0
					for _, item in ipairs(SearchConfig.Items) do
						if tostring(item):lower():find(q, 1, true) then
							local btn = Create("TextButton", {
								Text             = tostring(item),
								Font             = Enum.Font.GothamSemibold,
								TextSize         = 13,
								TextColor3       = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text,
								BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second,
								BackgroundTransparency = 0,
								BorderSizePixel  = 0,
								Size             = UDim2.new(1, 0, 0, 30),
								TextXAlignment   = Enum.TextXAlignment.Left,
								ZIndex           = 51,
								Parent           = ResultsFrame
							})
							Create("UIPadding", {PaddingLeft = UDim.new(0, 12), Parent = btn})
							btn.MouseEnter:Connect(function()
								TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke}):Play()
							end)
							btn.MouseLeave:Connect(function()
								TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second}):Play()
							end)
							btn.MouseButton1Click:Connect(function()
								SearchBox.Text = tostring(item)
								SearchConfig.Callback(item)
								hideResults()
							end)
							count = count + 1
							if count >= 6 then break end
						end
					end

					if count > 0 then
						local h = count * 30
						local ap = SearchMain.AbsolutePosition
						local as = SearchMain.AbsoluteSize
						ResultsFrame.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 2)
						ResultsFrame.Size     = UDim2.new(0, as.X, 0, 0)
						ResultsFrame.Visible  = true
						TweenService:Create(ResultsFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.new(0, as.X, 0, h)}):Play()
					else
						hideResults()
					end
				end

				SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
					showResults(SearchBox.Text)
				end)

				SearchBox.FocusLost:Connect(function()
					task.delay(0.25, function() hideResults() end)
				end)
			end

			function ElementFunction:AddColorpicker(ColorpickerConfig)
				ColorpickerConfig          = ColorpickerConfig or {}
				ColorpickerConfig.Name     = ColorpickerConfig.Name     or "Colorpicker"
				ColorpickerConfig.Default  = ColorpickerConfig.Default  or Color3.fromRGB(255, 255, 255)
				ColorpickerConfig.Callback = ColorpickerConfig.Callback or function() end
				ColorpickerConfig.Flag     = ColorpickerConfig.Flag     or nil
				ColorpickerConfig.Save     = ColorpickerConfig.Save     or false
				local ColorH, ColorS, ColorV = 1, 1, 1
				local Colorpicker = {Value = ColorpickerConfig.Default, Toggled = false, Type = "Colorpicker", Save = ColorpickerConfig.Save}
				local ColorSelection = Create("ImageLabel", {Size = UDim2.new(0,18,0,18), Position = UDim2.new(select(3,Color3.toHSV(Colorpicker.Value))), ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5,0.5), BackgroundTransparency = 1, Image = "http://www.roblox.com/asset/?id=4805639000"})
				local HueSelection  = Create("ImageLabel", {Size = UDim2.new(0,18,0,18), Position = UDim2.new(0.5,0,1-select(1,Color3.toHSV(Colorpicker.Value))), ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5,0.5), BackgroundTransparency = 1, Image = "http://www.roblox.com/asset/?id=4805639000"})
				local Color = Create("ImageLabel", {Size = UDim2.new(1,-25,1,0), Visible = false, Image = "rbxassetid://4155801252"}, {Create("UICorner",{CornerRadius=UDim.new(0,5)}), ColorSelection})
				local Hue   = Create("Frame", {Size = UDim2.new(0,20,1,0), Position = UDim2.new(1,-20,0,0), Visible = false}, {
					Create("UIGradient",{Rotation=270,Color=ColorSequence.new{ColorSequenceKeypoint.new(0.00,Color3.fromRGB(255,0,4)),ColorSequenceKeypoint.new(0.20,Color3.fromRGB(234,255,0)),ColorSequenceKeypoint.new(0.40,Color3.fromRGB(21,255,0)),ColorSequenceKeypoint.new(0.60,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.80,Color3.fromRGB(0,17,255)),ColorSequenceKeypoint.new(0.90,Color3.fromRGB(255,0,251)),ColorSequenceKeypoint.new(1.00,Color3.fromRGB(255,0,4))}}),
					Create("UICorner",{CornerRadius=UDim.new(0,5)}), HueSelection
				})
				local ColorpickerContainer = Create("Frame", {Position=UDim2.new(0,0,0,32), Size=UDim2.new(1,0,1,-32), BackgroundTransparency=1, ClipsDescendants=true}, {Hue, Color, Create("UIPadding",{PaddingLeft=UDim.new(0,35),PaddingRight=UDim.new(0,35),PaddingBottom=UDim.new(0,10),PaddingTop=UDim.new(0,17)})})
				local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0)})
				local ColorpickerBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",Color3.fromRGB(255,255,255),0,4),{Size=UDim2.new(0,24,0,24),Position=UDim2.new(1,-12,0.5,0),AnchorPoint=Vector2.new(1,0.5)}),{AddThemeObject(MakeElement("Stroke"),"Stroke")}),"Main")
				local ColorpickerFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",Color3.fromRGB(255,255,255),0,5),{Size=UDim2.new(1,0,0,38),Parent=ItemParent}),{
					SetProps(SetChildren(MakeElement("TFrame"),{
						AddThemeObject(SetProps(MakeElement("Label",ColorpickerConfig.Name,15),{Size=UDim2.new(1,-12,1,0),Position=UDim2.new(0,12,0,0),Font=Enum.Font.GothamBold,Name="Content"}),"Text"),
						ColorpickerBox, Click,
						AddThemeObject(SetProps(MakeElement("Frame"),{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),Name="Line",Visible=false}),"Stroke")
					}),{Size=UDim2.new(1,0,0,38),ClipsDescendants=true,Name="F"}),
					ColorpickerContainer, AddThemeObject(MakeElement("Stroke"),"Stroke")
				}),"Second")
				AddConnection(Click.MouseButton1Click, function()
					Colorpicker.Toggled = not Colorpicker.Toggled
					local _cpSize = Colorpicker.Toggled and UDim2.new(1,0,0,148) or UDim2.new(1,0,0,38)
					TweenService:Create(ColorpickerFrame,TweenInfo.new(.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=_cpSize}):Play()
					Color.Visible = Colorpicker.Toggled; Hue.Visible = Colorpicker.Toggled; ColorpickerFrame.F.Line.Visible = Colorpicker.Toggled
				end)
				local function UpdateColorPicker()
					ColorpickerBox.BackgroundColor3 = Color3.fromHSV(ColorH,ColorS,ColorV)
					Color.BackgroundColor3 = Color3.fromHSV(ColorH,1,1)
					Colorpicker:Set(ColorpickerBox.BackgroundColor3)
					ColorpickerConfig.Callback(ColorpickerBox.BackgroundColor3)
					SaveCfg(game.GameId)
				end
				ColorH = 1-(math.clamp(HueSelection.AbsolutePosition.Y-Hue.AbsolutePosition.Y,0,Hue.AbsoluteSize.Y)/Hue.AbsoluteSize.Y)
				ColorS = (math.clamp(ColorSelection.AbsolutePosition.X-Color.AbsolutePosition.X,0,Color.AbsoluteSize.X)/Color.AbsoluteSize.X)
				ColorV = 1-(math.clamp(ColorSelection.AbsolutePosition.Y-Color.AbsolutePosition.Y,0,Color.AbsoluteSize.Y)/Color.AbsoluteSize.Y)
				AddConnection(Color.InputBegan, function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then if ColorInput then ColorInput:Disconnect() end ColorInput=AddConnection(RunService.RenderStepped,function() local CX=(math.clamp(Mouse.X-Color.AbsolutePosition.X,0,Color.AbsoluteSize.X)/Color.AbsoluteSize.X) local CY=(math.clamp(Mouse.Y-Color.AbsolutePosition.Y,0,Color.AbsoluteSize.Y)/Color.AbsoluteSize.Y) ColorSelection.Position=UDim2.new(CX,0,CY,0) ColorS=CX ColorV=1-CY UpdateColorPicker() end) end end)
				AddConnection(Color.InputEnded, function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then if ColorInput then ColorInput:Disconnect() end end end)
				AddConnection(Hue.InputBegan,   function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then if HueInput then HueInput:Disconnect() end HueInput=AddConnection(RunService.RenderStepped,function() local HY=(math.clamp(Mouse.Y-Hue.AbsolutePosition.Y,0,Hue.AbsoluteSize.Y)/Hue.AbsoluteSize.Y) HueSelection.Position=UDim2.new(0.5,0,HY,0) ColorH=1-HY UpdateColorPicker() end) end end)
				AddConnection(Hue.InputEnded,   function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then if HueInput then HueInput:Disconnect() end end end)
				function Colorpicker:Set(Value) Colorpicker.Value=Value ColorpickerBox.BackgroundColor3=Colorpicker.Value ColorpickerConfig.Callback(Colorpicker.Value) end
				Colorpicker:Set(Colorpicker.Value)
				if ColorpickerConfig.Flag then DuvomeLibrary.Flags[ColorpickerConfig.Flag] = Colorpicker end
				return Colorpicker
			end

			
			function ElementFunction:AddDivider()
				local DividerFrame = SetChildren(SetProps(MakeElement("TFrame"), {
					Size   = UDim2.new(1, 0, 0, 16),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Frame"), {
						AnchorPoint = Vector2.new(0, 0.5),
						Size        = UDim2.new(1, 0, 0, 1),
						Position    = UDim2.new(0, 0, 0.5, 0)
					}), "Stroke")
				})
				local DividerFunction = {}
				function DividerFunction:Set(Visible) DividerFrame.Visible = Visible end
				return DividerFunction
			end

			return ElementFunction
		end

		-- ── Side Panel ──────────────────────────────────────────────────────
		-- Styled and positioned exactly like the Configs panel: same frame,
		-- header, divider and stroke, and the same snap-to-window behaviour.
		-- Built from the tab element factory so it can hold real controls.
		if not DuvomeLibrary.MakeSidePanel then
			function DuvomeLibrary:MakeSidePanel(cfg)
				cfg = cfg or {}
				local title  = cfg.Name or "Panel"
				local width  = cfg.Width or 175
				local height = cfg.Height or 420

				local Panel = Create("Frame", {
					Name                   = "SidePanel",
					BackgroundColor3       = Color3.fromRGB(12, 4, 24),
					BackgroundTransparency = 0,
					BorderSizePixel        = 0,
					Size                   = UDim2.new(0, width, 0, height),
					Position               = UDim2.new(0, 0, 0, 0),
					Visible                = false,
					ZIndex                 = 100,
					Parent                 = Duvome,
				})
				AddThemeObject(Panel, "Main")
				Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = Panel})
				AddThemeObject(Create("UIStroke", {
					Color = Color3.fromRGB(90, 30, 140), Thickness = 1.5, Parent = Panel,
				}), "Stroke")

				-- Drag handle. Only this strip moves the panel: binding the whole
				-- frame meant dragging a slider also dragged the panel.
				local Header = Create("TextButton", {
					Text = "", AutoButtonColor = false,
					BackgroundTransparency = 1, BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 38), Position = UDim2.new(0, 0, 0, 0),
					ZIndex = 101, Parent = Panel,
				})
				AddThemeObject(Create("TextLabel", {
					Text = title, Font = Enum.Font.GothamBlack, TextSize = 16,
					TextColor3 = Color3.fromRGB(220, 180, 255), BackgroundTransparency = 1,
					Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0, 8, 0, 10),
					TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 102, Parent = Panel,
				}), "Text")
				AddThemeObject(Create("Frame", {
					BackgroundColor3 = Color3.fromRGB(80, 25, 130), BorderSizePixel = 0,
					Size = UDim2.new(0.9, 0, 0, 1), Position = UDim2.new(0.05, 0, 0, 38),
					ZIndex = 102, Parent = Panel,
				}), "Stroke")

				local Content = AddThemeObject(Create("ScrollingFrame", {
					BackgroundTransparency = 1, BorderSizePixel = 0,
					-- inset well clear of the 12px corner radius and the stroke,
					-- with room on the right for the scrollbar
					Position = UDim2.new(0, 12, 0, 46),
					Size = UDim2.new(1, -28, 1, -58),
					CanvasSize = UDim2.new(0, 0, 0, 0),
					ScrollBarThickness = 3,
					ZIndex = 101, Parent = Panel,
				}), "Stroke")
				Create("UIPadding", {
					PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 4),
					PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6),
					Parent = Content,
				})

				local LeftCol, RightCol
				if cfg.Columns then
					LeftCol = Create("Frame", {BackgroundTransparency = 1,
						Size = UDim2.new(0.5, -4, 0, 0), Position = UDim2.new(0, 0, 0, 0),
						ZIndex = 101, Parent = Content})
					RightCol = Create("Frame", {BackgroundTransparency = 1,
						Size = UDim2.new(0.5, -4, 0, 0), Position = UDim2.new(0.5, 4, 0, 0),
						ZIndex = 101, Parent = Content})
					local ll = Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = LeftCol})
					local rl = Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = RightCol})
					local function sync()
						local h = math.max(ll.AbsoluteContentSize.Y, rl.AbsoluteContentSize.Y)
						LeftCol.Size  = UDim2.new(0.5, -4, 0, h)
						RightCol.Size = UDim2.new(0.5, -4, 0, h)
						Content.CanvasSize = UDim2.new(0, 0, 0, h + 8)
					end
					AddConnection(ll:GetPropertyChangedSignal("AbsoluteContentSize"), sync)
					AddConnection(rl:GetPropertyChangedSignal("AbsoluteContentSize"), sync)
				else
					local list = Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Content})
					AddConnection(list:GetPropertyChangedSignal("AbsoluteContentSize"), function()
						Content.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 8)
					end)
				end

				-- Same docking as the Configs panel: glide to the side of the
				-- window, drag it loose, snap to whichever side is nearer.
				local isOpen, dragging = false, false
				local side = cfg.Side or "right"
				local dragStart, startPos

				local function sideX(which)
					local wp, ws = MainWindow.AbsolutePosition, MainWindow.AbsoluteSize
					local pw = Panel.AbsoluteSize.X
					return which == "left" and (wp.X - pw - 20) or (wp.X + ws.X + 20)
				end
				local function centreY()
					local wp, ws = MainWindow.AbsolutePosition, MainWindow.AbsoluteSize
					return wp.Y + (ws.Y - Panel.AbsoluteSize.Y) / 2
				end

				AddConnection(RunService.RenderStepped, function()
					if isOpen and not dragging then
						local tx, ty = sideX(side), centreY()
						local cx, cy = Panel.Position.X.Offset, Panel.Position.Y.Offset
						Panel.Position = UDim2.new(0, cx + (tx - cx) * 0.12, 0, cy + (ty - cy) * 0.12)
					end
				end)

				AddConnection(Header.InputBegan, function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1
						or i.UserInputType == Enum.UserInputType.Touch then
						dragging = true dragStart = i.Position startPos = Panel.Position
					end
				end)
				AddConnection(UserInputService.InputChanged, function(i)
					if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
						or i.UserInputType == Enum.UserInputType.Touch) then
						local d = i.Position - dragStart
						Panel.Position = UDim2.new(0, startPos.X.Offset + d.X, 0, startPos.Y.Offset + d.Y)
					end
				end)
				AddConnection(UserInputService.InputEnded, function(i)
					if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1
						or i.UserInputType == Enum.UserInputType.Touch) then
						dragging = false
						local x = Panel.Position.X.Offset
						side = (math.abs(x - sideX("left")) < math.abs(x - sideX("right"))) and "left" or "right"
						TweenService:Create(Panel,
							TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
							{Position = UDim2.new(0, sideX(side), 0, centreY())}
						):Play()
					end
				end)

				-- The element factory never sets ZIndex, so everything it builds
				-- defaults to 1 while this frame sits at 100. Under Sibling
				-- ZIndex behaviour the panel background then draws OVER its own
				-- controls, which reads as a dim sheet across the panel. Lift
				-- every descendant above the frame.
				local function liftZ()
					for _, d in ipairs(Panel:GetDescendants()) do
						if d:IsA("GuiObject") and d.ZIndex < 102 then
							d.ZIndex = d.ZIndex + 102
						end
					end
				end
				AddConnection(Panel.DescendantAdded, function(d)
					if d:IsA("GuiObject") then
						task.defer(function()
							if d.Parent and d.ZIndex < 102 then d.ZIndex = d.ZIndex + 102 end
						end)
					end
				end)

				local api = GetElements(cfg.Columns and LeftCol or Content)
				if cfg.Columns then
					local l, r = GetElements(LeftCol), GetElements(RightCol)
					function api:Left() return l end
					function api:Right() return r end
				end

				function api:Show()
					-- Right-hand space holds one panel. Close any other side panel
					-- first so they replace each other instead of stacking.
					DuvomeLibrary._sidePanels = DuvomeLibrary._sidePanels or {}
					for _, other in ipairs(DuvomeLibrary._sidePanels) do
						if other ~= api and other.IsOpen and other:IsOpen() then
							other:Hide()
						end
					end
					isOpen = true
					liftZ()
					-- Step aside if the Configs or avatar panel already holds this
					-- side, the same way those two avoid each other.
					local PS = DuvomeLibrary._panelState
					if PS then
						if (PS.cfgOpen and PS.cfgSide == side) or (PS.vpOpen and PS.vpSide == side) then
							side = (side == "left") and "right" or "left"
						end
					end
					-- slide in from off-side, matching the Configs panel entrance
					local landX = sideX(side)
					Panel.Position = UDim2.new(0, side == "left" and (landX - width - 40) or (landX + width + 40), 0, centreY())
					Panel.BackgroundTransparency = 1
					Panel.Visible = true
					TweenService:Create(Panel,
						TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
						{BackgroundTransparency = 0, Position = UDim2.new(0, landX, 0, centreY())}
					):Play()
				end
				-- Raw content frame, for callers that need to parent something the
				-- element factory cannot build (a ViewportFrame, for instance).
				function api:Container()
					return cfg.Columns and LeftCol or Content
				end
				function api:Hide()
					if not isOpen then Panel.Visible = false return end
					isOpen = false
					-- same exit as the avatar panel: slide out, fade, then hide
					local curX, curY = Panel.Position.X.Offset, Panel.Position.Y.Offset
					local exitX = (side == "left") and (curX - width - 40) or (curX + width + 40)
					local t = TweenService:Create(Panel,
						TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
						{Position = UDim2.new(0, exitX, 0, curY), BackgroundTransparency = 1}
					)
					t:Play()
					t.Completed:Connect(function() Panel.Visible = false end)
				end
				function api:Toggle() if isOpen then api:Hide() else api:Show() end return isOpen end
				function api:IsOpen() return isOpen end
				function api:SetTitle(t)
					local lbl = Panel:FindFirstChildWhichIsA("TextLabel")
					if lbl then lbl.Text = tostring(t) end
				end
				DuvomeLibrary._sidePanels = DuvomeLibrary._sidePanels or {}
				table.insert(DuvomeLibrary._sidePanels, api)
				return api
			end
		end

		local ElementFunction = {}

		
		local function makeColElements(colFrame)
			if not colFrame then return ElementFunction end
			local elems = GetElements(colFrame)
			
			function elems:AddSection(SectionConfig)
				SectionConfig = SectionConfig or {}
				SectionConfig.Name = SectionConfig.Name or "Section"
				local _hScale  = SectionConfig.Collapsible and 0 or 1
				local _hOffset = SectionConfig.Collapsible and 0 or -24
				local _hPad    = SectionConfig.Collapsible and 20 or 0
				local collapsed = SectionConfig.Collapsible
				local fullH = 0

				local SectionLabel = AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name, 15), {
					Size     = UDim2.new(1, -30, 0, 20),
					Position = UDim2.new(0, 0, 0, 4),
					Font     = Enum.Font.GothamBlack,
					Name     = "SectionLabel"
				}), "Text")

				local HolderFrame = SetChildren(SetProps(MakeElement("TFrame"), {
					AnchorPoint      = Vector2.new(0, 0),
					Size             = UDim2.new(1, 0, _hScale, _hOffset),
					Position         = UDim2.new(0, 0, 0, 32),
					Name             = "Holder",
					ClipsDescendants = SectionConfig.Collapsible
				}), {
					MakeElement("List", 0, 6),
					MakeElement("Padding", (_hPad > 0 and _hPad or 3), 3, 3, 3)
				})

				local children = { SectionLabel, HolderFrame }

				if SectionConfig.Collapsible then
					local ArrowLbl = AddThemeObject(Create("TextLabel", {
						Text = ">", Font = Enum.Font.GothamBold, TextSize = 14,
						BackgroundTransparency = 1,
						Size = UDim2.new(0, 16, 0, 20), Position = UDim2.new(1, -20, 0, 4),
						TextXAlignment = Enum.TextXAlignment.Center, Rotation = 90, ZIndex = 3
					}), "TextDark")
					local ClickBtn = Create("TextButton", {
						Text = "", BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 26), ZIndex = 5
					})
					table.insert(children, ArrowLbl)
					table.insert(children, ClickBtn)
					local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
						-- explicit order lets a caller place a section above ones
						-- that were created before it
						LayoutOrder = SectionConfig.Order or 0,
						Size = UDim2.new(1, 0, 0, 28), Parent = colFrame, ClipsDescendants = true
					}), children)
					local tw = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
					AddConnection(HolderFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
						fullH = HolderFrame.UIListLayout.AbsoluteContentSize.Y
						if not collapsed then
							SectionFrame.Size = UDim2.new(1, 0, 0, fullH + 38)
							HolderFrame.Size  = UDim2.new(1, 0, 0, fullH + 8)
						end
					end)
					AddConnection(ClickBtn.MouseButton1Click, function()
						collapsed = not collapsed
						if collapsed then
							TweenService:Create(ArrowLbl,     tw, {Rotation = 90}):Play()
							TweenService:Create(HolderFrame,  tw, {Size = UDim2.new(1, 0, 0, 0)}):Play()
							TweenService:Create(SectionFrame, tw, {Size = UDim2.new(1, 0, 0, 28)}):Play()
						else
							fullH = HolderFrame.UIListLayout.AbsoluteContentSize.Y
							TweenService:Create(ArrowLbl,     tw, {Rotation = -90}):Play()
							TweenService:Create(HolderFrame,  tw, {Size = UDim2.new(1, 0, 0, fullH + 8)}):Play()
							TweenService:Create(SectionFrame, tw, {Size = UDim2.new(1, 0, 0, fullH + 38)}):Play()
						end
					end)
				else
					local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
						LayoutOrder = SectionConfig.Order or 0,
						Size = UDim2.new(1, 0, 0, 26), Parent = colFrame
					}), children)
					AddConnection(HolderFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
						SectionFrame.Size = UDim2.new(1, 0, 0, HolderFrame.UIListLayout.AbsoluteContentSize.Y + 38)
						HolderFrame.Size  = UDim2.new(1, 0, 0, HolderFrame.UIListLayout.AbsoluteContentSize.Y + 8)
					end)
				end

				local sf = {}
				for i,v in next, GetElements(HolderFrame) do sf[i] = v end
				return sf
			end
			return elems
		end

		function ElementFunction:AddLeft()
			return makeColElements(ColLeft)
		end
		function ElementFunction:AddRight()
			return makeColElements(ColRight)
		end
		
		function ElementFunction:AddAuto()
			colIndex = colIndex + 1
			return makeColElements(colIndex % 2 == 1 and ColLeft or ColRight)
		end

		function ElementFunction:AddSection(SectionConfig)
			SectionConfig = SectionConfig or {}
			SectionConfig.Name        = SectionConfig.Name        or "Section"
			SectionConfig.Collapsible = SectionConfig.Collapsible or false  

			local collapsed = SectionConfig.Collapsible  
			local fullH     = 0

			local SectionLabel = AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name, 15), {
				Size     = UDim2.new(1, -30, 0, 20),
				Position = UDim2.new(0, 0, 0, 4),
				Font     = Enum.Font.GothamBlack,
				Name     = "SectionLabel"
			}), "Text")

			local _hScale  = SectionConfig.Collapsible and 0 or 1
			local _hOffset = SectionConfig.Collapsible and 0 or -24
			local _hPad    = SectionConfig.Collapsible and 20 or 0
			local HolderFrame = SetChildren(SetProps(MakeElement("TFrame"), {
				AnchorPoint      = Vector2.new(0, 0),
				Size             = UDim2.new(1, 0, _hScale, _hOffset),
				Position         = UDim2.new(0, 0, 0, 32),
				Name             = "Holder",
				ClipsDescendants = SectionConfig.Collapsible
			}), {
				MakeElement("List", 0, 6),
				MakeElement("Padding", (_hPad > 0 and _hPad or 3), 3, 3, 3)
			})

			local children = { SectionLabel, HolderFrame }

			
			if SectionConfig.Collapsible then
				local ArrowLbl = AddThemeObject(Create("TextLabel", {
					Text                   = ">",
					Font                   = Enum.Font.GothamBold,
					TextSize               = 14,
					BackgroundTransparency = 1,
					Size                   = UDim2.new(0, 16, 0, 20),
					Position               = UDim2.new(1, -20, 0, 4),
					TextXAlignment         = Enum.TextXAlignment.Center,
					Rotation               = 90,
					ZIndex                 = 3
				}), "TextDark")
				table.insert(children, ArrowLbl)

				local ClickBtn = Create("TextButton", {
					Text = "", BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 26), ZIndex = 5
				})
				table.insert(children, ClickBtn)

				local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
					Size = UDim2.new(1, 0, 0, 28), Parent = Container, ClipsDescendants = true
				}), children)

				local tw = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

				AddConnection(HolderFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					if not HolderFrame.Parent then return end
					local newH = HolderFrame.UIListLayout.AbsoluteContentSize.Y
					if newH == fullH then return end
					fullH = newH
					if not collapsed then
						SectionFrame.Size = UDim2.new(1, 0, 0, fullH + 38)
						HolderFrame.Size  = UDim2.new(1, 0, 0, fullH + 8)
					end
				end)

				AddConnection(ClickBtn.MouseButton1Click, function()
					collapsed = not collapsed
					if collapsed then
						TweenService:Create(ArrowLbl,     tw, {Rotation = -90}):Play()
						TweenService:Create(HolderFrame,  tw, {Size = UDim2.new(1, 0, 0, 0)}):Play()
						TweenService:Create(SectionFrame, tw, {Size = UDim2.new(1, 0, 0, 28)}):Play()
					else
						fullH = HolderFrame.UIListLayout.AbsoluteContentSize.Y
						TweenService:Create(ArrowLbl,     tw, {Rotation = 90}):Play()
						TweenService:Create(HolderFrame,  tw, {Size = UDim2.new(1, 0, 0, fullH + 8)}):Play()
						TweenService:Create(SectionFrame, tw, {Size = UDim2.new(1, 0, 0, fullH + 38)}):Play()
					end
				end)

				local SectionFunction = {}
				for i, v in next, GetElements(HolderFrame) do SectionFunction[i] = v end
				return SectionFunction
			end

			
			local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
				Size = UDim2.new(1, 0, 0, 26), Parent = Container
			}), children)

			AddConnection(SectionFrame.Holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
				SectionFrame.Size        = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y + 38)
				SectionFrame.Holder.Size = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y)
			end)

			local SectionFunction = {}
			for i, v in next, GetElements(HolderFrame) do SectionFunction[i] = v end
			return SectionFunction
		end

		for i, v in next, GetElements(Container) do
			ElementFunction[i] = v
		end

		if TabConfig.PremiumOnly then
			for i, v in next, ElementFunction do
				ElementFunction[i] = function() end
			end
			Container:FindFirstChild("UIListLayout"):Destroy()
			Container:FindFirstChild("UIPadding"):Destroy()
			SetChildren(SetProps(MakeElement("TFrame"), {Size = UDim2.new(1,0,1,0), Parent = ItemParent}), {
				AddThemeObject(SetProps(MakeElement("Image","rbxassetid://3610239960"),{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0,15,0,15),ImageTransparency=0.4}),"Text"),
				AddThemeObject(SetProps(MakeElement("Label","Unauthorised Access",14),{Size=UDim2.new(1,-38,0,14),Position=UDim2.new(0,38,0,18),TextTransparency=0.4}),"Text"),
				AddThemeObject(SetProps(MakeElement("Image","rbxassetid://4483345875"),{Size=UDim2.new(0,56,0,56),Position=UDim2.new(0,84,0,110)}),"Text"),
				AddThemeObject(SetProps(MakeElement("Label","Premium Features",14),{Size=UDim2.new(1,-150,0,14),Position=UDim2.new(0,150,0,112),Font=Enum.Font.GothamBold}),"Text"),
				AddThemeObject(SetProps(MakeElement("Label","This part of the script is locked to Sirius Premium users. Purchase Premium in the Discord server (sirius.menu/discord)",12),{Size=UDim2.new(1,-200,0,14),Position=UDim2.new(0,150,0,138),TextWrapped=true,TextTransparency=0.4}),"Text")
			})
		end
		return ElementFunction
	end

	
	if UIBlur then task.defer(function() setBlur(true) end) end

	return TabFunction
end

function DuvomeLibrary:Destroy()
	
	for _, win in ipairs(Duvome:GetDescendants()) do
		if win:IsA("Frame") and win.Name:find("RoundFrame") then
			local s = win:FindFirstChildWhichIsA("UIScale")
			if s then TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play() end
		end
	end
	task.wait(0.3)
	for _, c in next, DuvomeLibrary.Connections do pcall(function() c:Disconnect() end) end
	Duvome:Destroy()
end


local function MakeKeyUI(cfg, onSuccess)
	local Title        = cfg.Title        or "Key System"
	local Subtitle     = cfg.Subtitle     or "Key System"
	local Note         = cfg.Note         or "Get your key from Discord."
	local FileName     = cfg.FileName     or "PrizHub_Key"
	local SaveKey      = cfg.SaveKey      ~= false
	local GrabFromSite = cfg.GrabKeyFromSite or false
	local Keys         = cfg.Key          or {}
	if type(Keys) == "string" then Keys = {Keys} end

	local TS2 = game:GetService("TweenService")
	local UIS2 = game:GetService("UserInputService")

	
	
	local function getHWID()
		local hwid = ""
		
		if hwid == "" then pcall(function() hwid = tostring(syn.get_hwid and syn.get_hwid() or "") end) end
		if hwid == "" then pcall(function() hwid = tostring(gethwid and gethwid() or "") end) end
		if hwid == "" then pcall(function() hwid = tostring(get_hwid and get_hwid() or "") end) end
		if hwid == "" then pcall(function() hwid = tostring(machine_id and machine_id() or "") end) end
		
		if hwid == "" then
			pcall(function() hwid = "UID_"..tostring(game:GetService("Players").LocalPlayer.UserId) end)
		end
		return hwid
	end

	local _hwid = getHWID()
	local savedKey = ""
	local _autoVerified = false
	pcall(function()
		if SaveKey and isfile and isfile(FileName..".txt") then
			local raw = (readfile(FileName..".txt")):match("^%s*(.-)%s*$")
			
			local storedHWID, storedKey = raw:match("^(.+)|(.+)$")
			if storedHWID and storedKey then
				if storedHWID == _hwid then
					savedKey = storedKey
					_autoVerified = true  
				else
					
					pcall(function() writefile(FileName..".txt", "") end)
				end
			end
		end
	end)

	local function getValidKeys()
		local valid = {}
		for _, k in ipairs(Keys) do
			local trimmed = (k):match("^%s*(.-)%s*$")
			if trimmed:sub(1,4) == "http" or GrabFromSite then
				pcall(function()
					local raw = game:HttpGet(trimmed)
					for line in raw:gmatch("[^\r\n]+") do
						local t2 = line:match("^%s*(.-)%s*$")
						if t2 ~= "" then valid[#valid+1] = t2 end
					end
				end)
			else
				if trimmed ~= "" then valid[#valid+1] = trimmed end
			end
		end
		return valid
	end

	
	local SG = Instance.new("ScreenGui")
	SG.Name = "PrizKeySystem"
	
	for _, g in ipairs(game.CoreGui:GetChildren()) do
		if g.Name == "PrizKeySystem" and g ~= SG then g:Destroy() end
	end
	pcall(function()
		for _, g in ipairs(gethui and gethui():GetChildren() or {}) do
			if g.Name == "PrizKeySystem" and g ~= SG then g:Destroy() end
		end
	end)
	SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	SG.DisplayOrder = 999
	SG.IgnoreGuiInset = true
	pcall(function()
		if syn and syn.protect_gui then syn.protect_gui(SG) SG.Parent = game.CoreGui end
	end)
	if not SG.Parent then SG.Parent = (typeof(gethui)=="function" and gethui()) or game.CoreGui end

	
	local Dim = Instance.new("Frame", SG)
	Dim.Size = UDim2.new(1,0,1,0)
	Dim.BackgroundColor3 = Color3.fromRGB(4,0,12)
	Dim.BackgroundTransparency = 1
	Dim.BorderSizePixel = 0
	Dim.ZIndex = 99
	TS2:Create(Dim, TweenInfo.new(0.4), {BackgroundTransparency = 0.45}):Play()

	
	local PW, PH = 460, 182
	local Panel = Instance.new("Frame", SG)
	Panel.Size = UDim2.new(0,PW,0,PH)
	Panel.AnchorPoint = Vector2.new(0.5,0.5)
	Panel.BackgroundColor3 = Color3.fromRGB(8,3,18)
	Panel.BackgroundTransparency = 0.35
	Panel.BorderSizePixel = 0
	Panel.ZIndex = 100
	Panel.Position = UDim2.new(0.5,0,0.5,0)
	Panel.BackgroundTransparency = 0
	Instance.new("UICorner",Panel).CornerRadius = UDim.new(0,14)

	local PStroke = Instance.new("UIStroke",Panel)
	PStroke.Color = Color3.fromRGB(100,35,170)
	PStroke.Thickness = 1.5

	


	
	local KSScale = Instance.new("UIScale", Panel)
	KSScale.Scale = 1
	Panel.BackgroundTransparency = 1
	Panel.Position = UDim2.new(0.5, 0, 0.58, 0)
	Dim.BackgroundTransparency = 1
	task.defer(function()
		TS2:Create(Dim, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{BackgroundTransparency = 0.45}):Play()
		TS2:Create(Panel, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 0.35}):Play()
	end)

	
	local Dragging2, DragInput2, MousePos2, FramePos2 = false, nil, nil, nil
	local DragBar = Instance.new("TextButton", Panel)
	DragBar.Size = UDim2.new(1,-40,0,56)
	DragBar.Position = UDim2.new(0,0,0,0)
	DragBar.BackgroundTransparency = 1
	DragBar.Text = ""
	DragBar.ZIndex = 110
	DragBar.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			Dragging2 = true
			MousePos2 = inp.Position
			FramePos2 = Panel.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then Dragging2 = false end
			end)
		end
	end)
	DragBar.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement then DragInput2 = inp end
	end)
	UIS2.InputChanged:Connect(function(inp)
		if inp == DragInput2 and Dragging2 then
			local Delta = inp.Position - MousePos2
			TS2:Create(Panel, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{Position = UDim2.new(FramePos2.X.Scale, FramePos2.X.Offset + Delta.X, FramePos2.Y.Scale, FramePos2.Y.Offset + Delta.Y)}):Play()
		end
	end)

	
	local TL = Instance.new("TextLabel",Panel)
	TL.Text = Title; TL.Font = Enum.Font.GothamBlack; TL.TextSize = 20
	TL.TextColor3 = Color3.fromRGB(235,210,255); TL.BackgroundTransparency = 1
	TL.Size = UDim2.new(1,-50,0,26); TL.Position = UDim2.new(0,18,0,14)
	TL.TextXAlignment = Enum.TextXAlignment.Left; TL.ZIndex = 101

	
	local SL = Instance.new("TextLabel",Panel)
	SL.Text = ""; SL.Font = Enum.Font.GothamSemibold; SL.TextSize = 12
	SL.TextColor3 = Color3.fromRGB(130,80,180); SL.BackgroundTransparency = 1
	SL.Size = UDim2.new(1,-50,0,16); SL.Position = UDim2.new(0,18,0,40)
	SL.TextXAlignment = Enum.TextXAlignment.Left; SL.ZIndex = 101
	task.spawn(function()
		local _phrases = {"Key System", "Join our Discord for a key", "Keys are free to get"}
		local _idx = 1
		while SG and SG.Parent do
			local phrase = _phrases[_idx]
			for i = 1, #phrase do
				if not (SG and SG.Parent) then break end
				SL.Text = phrase:sub(1, i)
				task.wait(0.07)
			end
			task.wait(1.2)
			for i = #phrase, 0, -1 do
				if not (SG and SG.Parent) then break end
				SL.Text = phrase:sub(1, i)
				task.wait(0.04)
			end
			task.wait(0.3)
			_idx = (_idx % #_phrases) + 1
		end
	end)

	
	local Div = Instance.new("Frame",Panel)
	Div.Size = UDim2.new(1,-36,0,1); Div.Position = UDim2.new(0,18,0,62)
	Div.BackgroundColor3 = Color3.fromRGB(80,25,140); Div.BorderSizePixel = 0; Div.ZIndex = 101
	Instance.new("UICorner",Div).CornerRadius = UDim.new(1,0)



	
	local XB = Instance.new("TextButton",Panel)
	XB.Text = ""; XB.BackgroundTransparency = 1
	XB.Size = UDim2.new(0,30,0,30)
	XB.Position = UDim2.new(1,-36,0,8); XB.ZIndex = 112
	local XBIco = Instance.new("ImageLabel", XB)
	XBIco.Image = "rbxassetid://7072725342"
	XBIco.BackgroundTransparency = 1
	XBIco.Size = UDim2.new(0,16,0,16)
	XBIco.Position = UDim2.new(0,7,0,7)
	XBIco.ImageColor3 = Color3.fromRGB(140,90,190)
	XBIco.ZIndex = 113
	XB.MouseEnter:Connect(function()
		XBIco.ImageColor3 = Color3.fromRGB(210,150,255)
	end)
	XB.MouseLeave:Connect(function()
		XBIco.ImageColor3 = Color3.fromRGB(140,90,190)
	end)
	XB.MouseButton1Click:Connect(function()
		local t = TS2:Create(Panel, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{Position = UDim2.new(0.5, 0, 0.62, 0), BackgroundTransparency = 1})
		TS2:Create(Dim, TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{BackgroundTransparency = 1}):Play()
		t.Completed:Connect(function()
			Panel.Visible = false
			SG:Destroy()
		end)
		t:Play()
	end)

	
	local IBG = Instance.new("Frame",Panel)
	IBG.Size = UDim2.new(0,240,0,40); IBG.Position = UDim2.new(0,18,0,92)
	IBG.BackgroundColor3 = Color3.fromRGB(16,5,32); IBG.BorderSizePixel = 0; IBG.ZIndex = 101
	Instance.new("UICorner",IBG).CornerRadius = UDim.new(0,8)
	local IS = Instance.new("UIStroke",IBG)
	IS.Color = Color3.fromRGB(60,20,105); IS.Thickness = 1
	IBG.ClipsDescendants = true

	
	task.spawn(function()
		local TS3 = game:GetService("TweenService")
		local squareSizes = {4, 6, 5, 7, 4, 6}
		local function spawnSquare()
			if not (Panel and Panel.Parent) then return end
			local sz = squareSizes[math.random(1, #squareSizes)]
			local sq = Instance.new("Frame", IBG)
			sq.Size = UDim2.new(0, sz, 0, sz)
			sq.Position = UDim2.new(math.random(5, 85)/100, 0, 1, 0)
			sq.BackgroundColor3 = Color3.fromRGB(
				math.random(100, 160),
				math.random(40, 80),
				math.random(200, 255)
			)
			sq.BackgroundTransparency = 0.3
			sq.BorderSizePixel = 0
			sq.ZIndex = 99
			Instance.new("UICorner", sq).CornerRadius = UDim.new(0, 1)
			
			local rise = math.random(20, 36)
			TS3:Create(sq, TweenInfo.new(
				math.random(12, 20) / 10,
				Enum.EasingStyle.Sine, Enum.EasingDirection.Out
			), {
				Position = UDim2.new(sq.Position.X.Scale, 0, 0, -rise + 40),
				BackgroundTransparency = 1
			}):Play()
			game:GetService("Debris"):AddItem(sq, 2.5)
		end
		while Panel and Panel.Parent do
			spawnSquare()
			task.wait(math.random(3, 7) / 10)
		end
	end)

	
	local TB = Instance.new("TextBox",IBG)
	TB.Size = UDim2.new(1,-34,1,0); TB.Position = UDim2.new(0,8,0,0)
	TB.BackgroundTransparency = 1; TB.Text = ""
	TB.PlaceholderText = "Enter your key..."; TB.PlaceholderColor3 = Color3.fromRGB(75,45,105)
	TB.TextColor3 = Color3.fromRGB(210,175,255); TB.Font = Enum.Font.GothamSemibold
	TB.TextSize = 13; TB.TextXAlignment = Enum.TextXAlignment.Left
	TB.ClearTextOnFocus = false; TB.ZIndex = 103
	TB:GetPropertyChangedSignal("Text"):Connect(function()
		TS2:Create(IS,TweenInfo.new(0.15),{Color=Color3.fromRGB(110,40,185)}):Play()
	end)
	TB.FocusLost:Connect(function()
		TS2:Create(IS,TweenInfo.new(0.25),{Color=Color3.fromRGB(60,20,105)}):Play()
	end)

	
	local PB = Instance.new("TextButton", IBG)
	PB.Text = ""; PB.BackgroundTransparency = 1
	PB.Size = UDim2.new(0, 28, 1, 0); PB.Position = UDim2.new(1, -30, 0, 0); PB.ZIndex = 104
	local PBImg = Instance.new("TextLabel", PB)
	PBImg.Text = "two-stacked-squares"
	SetFontFace(PBImg, BICONS_PATH)
	PBImg.TextSize = 14
	PBImg.TextWrapped = true
	PBImg.TextColor3 = Color3.fromRGB(120, 65, 185)
	PBImg.BackgroundTransparency = 1
	PBImg.Size = UDim2.new(1, 0, 1, 0)
	PBImg.TextXAlignment = Enum.TextXAlignment.Center
	PBImg.TextYAlignment = Enum.TextYAlignment.Center
	PBImg.ZIndex = 105
	PB.MouseEnter:Connect(function() PBImg.TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text end)
	PB.MouseLeave:Connect(function() PBImg.TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].TextDark end)
	PB.MouseButton1Click:Connect(function()
		local link = "https://discord.gg/yourlink"
		pcall(setclipboard, link)
		TB.Text = link
		PBImg.TextColor3 = Color3.fromRGB(100, 220, 130)
		task.delay(1.5, function()
			if PBImg and PBImg.Parent then PBImg.TextColor3 = Color3.fromRGB(120, 65, 185) end
		end)
	end)

	
	local VB = Instance.new("TextButton",Panel)
	VB.Text = "Verify"
	VB.Font = Enum.Font.GothamBold
	VB.TextSize = 14
	VB.TextColor3 = Color3.fromRGB(190,140,255)
	VB.BackgroundTransparency = 1
	VB.BorderSizePixel = 0
	VB.AutoButtonColor = false
	VB.Size = UDim2.new(0,70,0,40)
	VB.Position = UDim2.new(1,-136,0,92)
	VB.ZIndex = 101

	
	local VBTip = Instance.new("TextButton", Panel)
	VBTip.Text = "Copy Discord\nInvite"
	VBTip.Font = Enum.Font.GothamSemibold
	VBTip.TextSize = 11
	VBTip.TextColor3 = Color3.fromRGB(200,160,255)
	VBTip.BackgroundColor3 = Color3.fromRGB(18,6,36)
	VBTip.BackgroundTransparency = 1
	VBTip.BorderSizePixel = 0
	VBTip.AutoButtonColor = false
	VBTip.Size = UDim2.new(0,90,0,36)
	VBTip.Position = UDim2.new(1,-146,0,140)
	VBTip.ZIndex = 200
	VBTip.Visible = false


	VB.MouseEnter:Connect(function()
		TS2:Create(VB, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(235,200,255)}):Play()
		
		VBTip.Text = "Copy Discord\nInvite"
		VBTip.TextColor3 = Color3.fromRGB(200,160,255)
		VBTip.TextTransparency = 1
		VBTip.Position = UDim2.new(1,-146,0,140)
		VBTip.Visible = true
		TS2:Create(VBTip, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Position = UDim2.new(1,-146,0,128), TextTransparency = 0}):Play()
	end)
	local function hideTip()
		TS2:Create(VBTip, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{Position = UDim2.new(1,-146,0,140), TextTransparency = 1}):Play()
		task.delay(0.27, function()
			if VBTip and VBTip.Parent then
				VBTip.Visible = false
				VBTip.Text = "Copy Discord\nInvite"
				VBTip.TextColor3 = Color3.fromRGB(200,160,255)
			end
		end)
	end

	
	local _tipShowing = false
	game:GetService("RunService").RenderStepped:Connect(function()
		if not (Panel and Panel.Parent) then return end
		local mp = game:GetService("UserInputService"):GetMouseLocation()
		
		local vbp = VB.AbsolutePosition; local vbs = VB.AbsoluteSize
		local overVB = mp.X>=vbp.X and mp.X<=vbp.X+vbs.X and mp.Y>=vbp.Y and mp.Y<=vbp.Y+vbs.Y
		
		local ttp = VBTip.AbsolutePosition; local tts = VBTip.AbsoluteSize
		local overTip = mp.X>=ttp.X and mp.X<=ttp.X+tts.X and mp.Y>=ttp.Y and mp.Y<=ttp.Y+tts.Y
		if overVB and not _tipShowing then
			_tipShowing = true
			TS2:Create(VB, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(235,200,255)}):Play()
			VBTip.Text = "Copy Discord\nInvite"
			VBTip.TextColor3 = Color3.fromRGB(200,160,255)
			VBTip.TextTransparency = 1
			VBTip.Position = UDim2.new(1,-146,0,140)
			VBTip.Visible = true
			TS2:Create(VBTip, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{Position = UDim2.new(1,-146,0,128), TextTransparency = 0}):Play()
		elseif not overVB and not overTip and _tipShowing then
			_tipShowing = false
			TS2:Create(VB, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(190,140,255)}):Play()
			hideTip()
		end
	end)
	
	

	
	local StL = Instance.new("TextLabel",Panel)
	StL.Text = ""; StL.Font = Enum.Font.GothamSemibold; StL.TextSize = 11
	StL.TextColor3 = Color3.fromRGB(150,100,210); StL.BackgroundTransparency = 1
	StL.Size = UDim2.new(1,-36,0,14); StL.Position = UDim2.new(0,18,0,144)
	StL.TextXAlignment = Enum.TextXAlignment.Left; StL.ZIndex = 101

	
	local VL = Instance.new("TextLabel",Panel)
	VL.Text = "v1.0"; VL.Font = Enum.Font.Gotham; VL.TextSize = 10
	VL.TextColor3 = Color3.fromRGB(65,40,95); VL.BackgroundTransparency = 1
	VL.Size = UDim2.new(0,40,0,14); VL.Position = UDim2.new(1,-48,1,-18); VL.ZIndex = 101

	local function closeAndLoad()
		local t = TS2:Create(Panel, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{Position = UDim2.new(0.5, 0, 0.62, 0), BackgroundTransparency = 1})
		TS2:Create(Dim, TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{BackgroundTransparency = 1}):Play()
		t.Completed:Connect(function()
			Panel.Visible = false
			SG:Destroy()
			task.defer(onSuccess)
		end)
		t:Play()
	end

	local function doVerify()
		local entered = TB.Text:match("^%s*(.-)%s*$")
		if entered == "" then
			StL.TextTransparency = 1
			StL.Text = "Please enter a key."
			StL.TextColor3 = Color3.fromRGB(255,155,55)
			TS2:Create(StL, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			return
		end
		StL.TextTransparency = 1
		StL.Text = "Verifying..."
		StL.TextColor3 = Color3.fromRGB(160,110,220)
		TS2:Create(StL, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
		task.spawn(function()
			local valid = getValidKeys()
			local ok = false
			for _, k in ipairs(valid) do if k == entered then ok = true break end end
			if ok then
				StL.Text = "✓  Key accepted! Loading..."
				StL.TextColor3 = Color3.fromRGB(90,215,120)
				TS2:Create(IS,TweenInfo.new(0.2),{Color=Color3.fromRGB(55,175,95)}):Play()
				TS2:Create(IBG,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(8,28,14)}):Play()
				if SaveKey then pcall(function() writefile(FileName..".txt", entered) end) end
				task.wait(1.2)
				closeAndLoad()
			else
				StL.Text = "✗  Invalid key. Try again."
				StL.TextColor3 = Color3.fromRGB(255,70,70)
				
				for i = 1, 4 do
					TS2:Create(KSScale, TweenInfo.new(0.05), {Scale = i%2==0 and 1.04 or 0.97}):Play()
					task.wait(0.06)
				end
				TS2:Create(KSScale, TweenInfo.new(0.1), {Scale = 1}):Play()
				TS2:Create(IBG,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(50,6,16)}):Play()
				task.wait(0.35)
				TS2:Create(IBG,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(16,5,32)}):Play()
				TS2:Create(IS,TweenInfo.new(0.2),{Color=Color3.fromRGB(60,20,105)}):Play()
			end
		end)
	end

	VB.MouseButton1Click:Connect(doVerify)
	TB.FocusLost:Connect(function(enter) if enter then doVerify() end end)

	
	VBTip.MouseButton1Click:Connect(function()
		pcall(setclipboard, "https://discord.gg/yourlink")
		VBTip.Text = "Discord Invite\nCopied"
		VBTip.TextColor3 = Color3.fromRGB(100,220,130)
		task.delay(1.5, function()
			if VBTip and VBTip.Parent then
				VBTip.Text = "Copy Discord\nInvite"
				VBTip.TextColor3 = Color3.fromRGB(200,160,255)
			end
		end)
	end)

	
	if _autoVerified and savedKey ~= "" then
		pcall(function() SG:Destroy() end)
		task.defer(onSuccess)
		return
	end
end

DuvomeLibrary.MakeKeyUI = MakeKeyUI


function DuvomeLibrary:Prompt(opts)
	opts = opts or {}
	local title   = opts.Title   or "Confirm"
	local content = opts.Content or "Are you sure?"
	local options = opts.Options or {{Text="Yes"},{Text="No"}}
	local onDone  = opts.Callback or function() end

	
	if DuvomeLibrary._activePrompt and DuvomeLibrary._activePrompt.Parent then
		DuvomeLibrary._activePrompt:Destroy()
	end

	local overlay = Create("Frame", {
		BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=1, BorderSizePixel=0,
		Size=UDim2.new(1,0,1,0), ZIndex=200, Parent=Duvome
	})
	DuvomeLibrary._activePrompt = overlay

	
	local startY = 0.42   
	local endY   = 0.5    
	local box = Create("Frame", {
		BackgroundColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Second, BorderSizePixel=0,
		BackgroundTransparency=1,
		Size=UDim2.new(0,300,0,0), AutomaticSize=Enum.AutomaticSize.Y,
		AnchorPoint=Vector2.new(0.5,0.5),
		Position=UDim2.new(0.5,0,startY,0), ZIndex=201, Parent=overlay
	})
	Create("UICorner", {CornerRadius=UDim.new(0,10), Parent=box})
	local boxStroke = Create("UIStroke", {Color=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke, Thickness=1.5, Transparency=1, Parent=box})
	Create("UIPadding", {PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16),PaddingTop=UDim.new(0,14),PaddingBottom=UDim.new(0,14), Parent=box})
	Create("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder, Parent=box})
	local titleLbl = Create("TextLabel", {Text=title, Font=Enum.Font.GothamBold, TextSize=16,
		TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text, BackgroundTransparency=1, TextTransparency=1,
		Size=UDim2.new(1,0,0,20), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=202, LayoutOrder=1, Parent=box})
	local contentLbl = Create("TextLabel", {Text=content, Font=Enum.Font.Gotham, TextSize=13,
		TextColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].TextDark, BackgroundTransparency=1, TextTransparency=1,
		Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left, ZIndex=202, LayoutOrder=2, Parent=box})
	local btnRow = Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,32), ZIndex=202, LayoutOrder=3, Parent=box})
	Create("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Right, Padding=UDim.new(0,8), SortOrder=Enum.SortOrder.LayoutOrder, Parent=btnRow})

	local btnObjs = {}
	local function fadeBtns(trans)
		for _, bb in ipairs(btnObjs) do
			TweenService:Create(bb, TweenInfo.new(0.2), {BackgroundTransparency=trans, TextTransparency=trans}):Play()
		end
	end

	
	TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.5}):Play()
	TweenService:Create(box, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.new(0.5,0,endY,0), BackgroundTransparency = 0}):Play()
	TweenService:Create(boxStroke, TweenInfo.new(0.45), {Transparency = 0}):Play()
	TweenService:Create(titleLbl, TweenInfo.new(0.45), {TextTransparency = 0}):Play()
	TweenService:Create(contentLbl, TweenInfo.new(0.45), {TextTransparency = 0}):Play()

	local closing = false
	local function closePrompt()
		if closing then return end
		closing = true
		
		TweenService:Create(overlay, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
		TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Position = UDim2.new(0.5,0,startY,0), BackgroundTransparency = 1}):Play()
		TweenService:Create(boxStroke, TweenInfo.new(0.25), {Transparency = 1}):Play()
		TweenService:Create(titleLbl, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
		TweenService:Create(contentLbl, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
		fadeBtns(1)
		task.delay(0.32, function()
			if DuvomeLibrary._activePrompt == overlay then DuvomeLibrary._activePrompt = nil end
			overlay:Destroy()
		end)
	end

	for _, o in ipairs(options) do
		local b = Create("TextButton", {Text=o.Text or "OK", Font=Enum.Font.GothamBold, TextSize=13,
			TextColor3=Color3.fromRGB(240,230,255), BackgroundColor3=DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke,
			BackgroundTransparency=1, TextTransparency=1,
			BorderSizePixel=0, AutomaticSize=Enum.AutomaticSize.X, Size=UDim2.new(0,0,1,0), ZIndex=203, Parent=btnRow})
		Create("UICorner", {CornerRadius=UDim.new(0,6), Parent=b})
		Create("UIPadding", {PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14), Parent=b})
		table.insert(btnObjs, b)
		b.MouseButton1Click:Connect(function()
			pcall(function() if o.Callback then o.Callback() end end)
			onDone(o.Text)
			closePrompt()
		end)
	end
	
	fadeBtns(0)
end


function DuvomeLibrary:SetTheme(themeName)
	if not DuvomeLibrary.Themes[themeName] then return false end
	DuvomeLibrary.SelectedTheme = themeName
	if themeName ~= "Custom" then DuvomeLibrary._customAccent = nil end
	SetTheme()  
	return true
end
function DuvomeLibrary:SetGlass(amount)
	DuvomeLibrary.Glass = math.clamp(tonumber(amount) or 0, 0, 0.9)
	for _, Type in pairs({ "Main", "Second" }) do
		for _, Object in pairs(DuvomeLibrary.ThemeObjects[Type] or {}) do
			pcall(function()
				if Object:GetAttribute("DuvomeGlass") then
					Object.BackgroundTransparency = DuvomeLibrary.Glass
				end
			end)
		end
	end
end

function DuvomeLibrary:GetThemes()
	local names = {}
	for name in pairs(DuvomeLibrary.Themes) do table.insert(names, name) end
	table.sort(names)
	return names
end




function DuvomeLibrary:AddWatch(name, stateFn, keyCode, setFn)
	if not DuvomeLibrary._watchGui then
		local wl = AddThemeObject(Create("Frame", {
			Name = "WatchList", BackgroundTransparency = 0.25,
			BorderSizePixel = 0, Size = UDim2.new(0, 190, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			-- anchored to the right edge so it grows leftward, not off-screen
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16), Parent = Duvome
		}), "Main")
		Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = wl})
		AddThemeObject(Create("UIStroke", {Thickness = 1, Parent = wl}), "Stroke")
		Create("UIPadding", {PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10), Parent=wl})
		Create("UIListLayout", {Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wl})
		AddThemeObject(Create("TextLabel", {Text = "Active", Font = Enum.Font.GothamBold, TextSize = 13,
			TextColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 1, Size = UDim2.new(1,0,0,16),
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, Name = "Header", Parent = wl}), "Text")
		DuvomeLibrary._watchGui = wl
		DuvomeLibrary._watchItems = {}
	end
	local wl = DuvomeLibrary._watchGui
	-- A plain Frame unless a setter is supplied, in which case the whole row
	-- is a button so the ON/OFF text can be clicked to flip the feature.
	local row
	if setFn then
		row = Create("TextButton", {Text = "", AutoButtonColor = false,
			BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.new(1,0,0,16), LayoutOrder = #DuvomeLibrary._watchItems + 1, Parent = wl})
	else
		row = Create("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,16),
			LayoutOrder = #DuvomeLibrary._watchItems + 1, Parent = wl})
	end
	local nameLbl = AddThemeObject(Create("TextLabel", {
		Text = name .. (keyCode and (" ["..(keyCode.Name or tostring(keyCode)).."]") or ""),
		Font = Enum.Font.GothamSemibold, TextSize = 12, TextColor3 = Color3.fromRGB(210,210,220),
		BackgroundTransparency = 1, Size = UDim2.new(1,-40,1,0), TextXAlignment = Enum.TextXAlignment.Left, Parent = row}), "TextDark")
	local stateLbl = Create("TextLabel", {
		Text = "OFF", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(120,120,130),
		BackgroundTransparency = 1, Size = UDim2.new(0,40,1,0), Position = UDim2.new(1,-40,0,0),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = row})
	if setFn then
		-- Click target is the ON/OFF text only. Making the whole row clickable
		-- meant brushing the label lit it up and invited a misclick.
		local hit = Create("TextButton", {
			Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			BorderSizePixel = 0, Size = UDim2.new(0, 40, 1, 0),
			Position = UDim2.new(1, -40, 0, 0), ZIndex = 3, Parent = row
		})
		hit.MouseEnter:Connect(function()
			stateLbl.TextTransparency = 0.35
		end)
		hit.MouseLeave:Connect(function()
			stateLbl.TextTransparency = 0
		end)
		hit.MouseButton1Click:Connect(function()
			local cur = stateFn()
			pcall(setFn, not (cur and cur ~= false))
		end)
	end
	table.insert(DuvomeLibrary._watchItems, {stateFn = stateFn, stateLbl = stateLbl})
	
	if not DuvomeLibrary._watchLoop then
		DuvomeLibrary._watchLoop = true
		task.spawn(function()
			while DuvomeLibrary._watchGui and DuvomeLibrary._watchGui.Parent do
				for _, it in ipairs(DuvomeLibrary._watchItems) do
					local ok, v = pcall(it.stateFn)
					if ok then
						if type(v) == "boolean" then
							it.stateLbl.Text = v and "ON" or "OFF"
							it.stateLbl.TextColor3 = v and DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Stroke or Color3.fromRGB(120,120,130)
						else
							it.stateLbl.Text = tostring(v)
							it.stateLbl.TextColor3 = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme].Text
						end
					end
				end
				task.wait(0.2)
			end
		end)
	end
	return {SetVisible = function(_, v) row.Visible = v end}
end
function DuvomeLibrary:SetWatchVisible(v)
	if DuvomeLibrary._watchGui then DuvomeLibrary._watchGui.Visible = v end
end



function DuvomeLibrary:SetAccent(color)
	local base = DuvomeLibrary.Themes[DuvomeLibrary.SelectedTheme] or DuvomeLibrary.Themes.Default
	local h, s, v = Color3.toHSV(color)
	
	local vividness = s * v                       
	local tint = math.clamp(vividness, 0, 1)       
	
	local mainBg   = Color3.fromHSV(h, math.min(s, 0.6) * tint, 0.05)
	local secondBg = Color3.fromHSV(h, math.min(s, 0.55) * tint, 0.09)
	
	local textCol  = Color3.fromHSV(h, 0.12 * tint, 0.95)
	local textDark = Color3.fromHSV(h, 0.30 * tint, 0.62)
	DuvomeLibrary.Themes.Custom = {
		Main    = mainBg,
		Second  = secondBg,
		Stroke  = color,
		Divider = color,
		Text    = textCol,
		TextDark = textDark,
	}
	DuvomeLibrary.SelectedTheme = "Custom"
	DuvomeLibrary._customAccent = color   
	SetTheme()
	return true
end

return DuvomeLibrary