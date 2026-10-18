--[[
    ╔════════════════════════════════════════════════════╗
    ║            YUNO FARM v1.0 - Standalone              ║
    ║   UI custom Yuno • AutoFarm • Pet Visuals          ║
    ║   Fast Mega • Trade Values • Shop • Mobile          ║
    ║   Aucune dépendance externe, aucun DuskShine        ║
    ╚════════════════════════════════════════════════════╝
]]

if not game:IsLoaded() then game.Loaded:Wait() end
game:GetService("ReplicatedStorage"):WaitForChild("Fsys", 999)

-- ══════════════════ SETUP ══════════════════
local Players    = game:GetService("Players")
local LP         = Players.LocalPlayer
local UIS        = game:GetService("UserInputService")
local TS         = game:GetService("TweenService")
local RS         = game:GetService("ReplicatedStorage")
local CoreGui    = game:GetService("CoreGui")
local HttpService= game:GetService("HttpService")
local RunService = game:GetService("RunService")

local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
local IS_MOBILE = UIS.TouchEnabled or vp.X < 900

if not isfolder("YunoFarm") then pcall(makefolder, "YunoFarm") end
local CFG_FILE = "YunoFarm/config.json"

-- Anti-AFK
local vu = game:GetService("VirtualUser")
LP.Idled:Connect(function() vu:CaptureController() vu:ClickButton2(Vector2.new()) end)

-- ══════════════════ API ADOPT ME ══════════════════
local Fsys = require(RS:WaitForChild("Fsys", 5))
local M = {
    RouterClient     = Fsys.load("RouterClient"),
    ClientData       = Fsys.load("ClientData"),
    InteriorsM       = Fsys.load("InteriorsM"),
    PetEntityHelper  = Fsys.load("PetEntityHelper"),
    PetEntityManager = Fsys.load("PetEntityManager"),
    InventoryDB      = Fsys.load("InventoryDB"),
    LiveOpsTime      = Fsys.load("LiveOpsTime"),
    KindDB           = Fsys.load("KindDB"),
}

local API = {
    Equip             = M.RouterClient.get("ToolAPI/Equip"),
    Unequip           = M.RouterClient.get("ToolAPI/Unequip"),
    ServerUseTool     = M.RouterClient.get("ToolAPI/ServerUseTool"),
    DoNeonFusion      = M.RouterClient.get("PetAPI/DoNeonFusion"),
    ConsumeFoodObject = M.RouterClient.get("PetAPI/ConsumeFoodObject"),
    ExitFurniture     = M.RouterClient.get("PetAPI/ExitFurnitureUseStates"),
    CreatePetObject   = M.RouterClient.get("PetObjectAPI/CreatePetObject"),
    GrabPetObject     = M.RouterClient.get("PetObjectAPI/GrabPetObject"),
    DropPetObject     = M.RouterClient.get("PetObjectAPI/DropPetObject"),
    ProgressPetMe     = M.RouterClient.get("AilmentsAPI/ProgressPetMeAilment"),
    ChooseMystery     = M.RouterClient.get("AilmentsAPI/ChooseMysteryAilment"),
    AddPet            = M.RouterClient.get("IdleProgressionAPI/AddPet"),
    RemovePet         = M.RouterClient.get("IdleProgressionAPI/RemovePet"),
    ClaimProgression  = M.RouterClient.get("IdleProgressionAPI/CommitAllProgression"),
    BuyItem           = M.RouterClient.get("ShopAPI/BuyItem"),
    SetLocation       = M.RouterClient.get("LocationAPI/SetLocation"),
    ChooseTeam        = M.RouterClient.get("TeamAPI/ChooseTeam"),
    SubscribeHouse    = M.RouterClient.get("HousingAPI/SubscribeToHouse"),
    UnsubscribeHouse  = M.RouterClient.get("HousingAPI/UnsubscribeFromHouse"),
    ActivateInterior  = M.RouterClient.get("HousingAPI/ActivateInteriorFurniture"),
    ActivateFurniture = M.RouterClient.get("HousingAPI/ActivateFurniture"),
    BuyFurnitures     = M.RouterClient.get("HousingAPI/BuyFurnitures"),
    ExitSeats         = M.RouterClient.get("AdoptAPI/ExitSeatStates"),
    EjectBaby         = M.RouterClient.get("AdoptAPI/EjectBaby"),
    UseStroller       = M.RouterClient.get("AdoptAPI/UseStroller"),
}

-- ══════════════════ THÈME YUNO ══════════════════
local THEMES = {
    YunoDark = {
        Background = Color3.fromRGB(12, 14, 22),
        Sidebar    = Color3.fromRGB(18, 21, 32),
        Section    = Color3.fromRGB(24, 28, 42),
        Text       = Color3.fromRGB(240, 245, 255),
        SubText    = Color3.fromRGB(120, 140, 170),
        Accent     = Color3.fromRGB(110, 170, 255),
        Accent2    = Color3.fromRGB(180, 130, 255),
        Stroke     = Color3.fromRGB(40, 48, 70),
        ToggleOff  = Color3.fromRGB(45, 52, 72),
        Knob       = Color3.fromRGB(240, 245, 255),
    },
    YunoLight = {
        Background = Color3.fromRGB(245, 248, 255),
        Sidebar    = Color3.fromRGB(255, 255, 255),
        Section    = Color3.fromRGB(235, 240, 250),
        Text       = Color3.fromRGB(20, 28, 45),
        SubText    = Color3.fromRGB(100, 110, 130),
        Accent     = Color3.fromRGB(80, 140, 255),
        Accent2    = Color3.fromRGB(150, 100, 230),
        Stroke     = Color3.fromRGB(200, 210, 225),
        ToggleOff  = Color3.fromRGB(200, 210, 225),
        Knob       = Color3.fromRGB(255, 255, 255),
    },
}

local ThemeName = "YunoDark"
local Theme = THEMES[ThemeName]
local ThemeObjects = {}   -- [obj] = { Prop = "Accent" }
local Flags = {}

local function ApplyTheme(newName)
    if not THEMES[newName] then return end
    ThemeName = newName
    Theme = THEMES[newName]
    for obj, props in pairs(ThemeObjects) do
        if obj and obj.Parent then
            for prop, key in pairs(props) do
                pcall(function() obj[prop] = Theme[key] end)
            end
        end
    end
end

-- ══════════════════ UTILS ══════════════════
local function Make(class, props, theme)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if theme then
        ThemeObjects[inst] = {}
        for k, v in pairs(theme) do
            ThemeObjects[inst][k] = v
            inst[k] = Theme[v]
        end
        inst.Destroying:Connect(function() ThemeObjects[inst] = nil end)
    end
    return inst
end

local function Tween(obj, dur, props, style, dir)
    local t = TS:Create(obj, TweenInfo.new(dur or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function ApplyGradientTo(obj, color)
    local g = obj:FindFirstChild("YunoGrad")
    if not g then
        g = Instance.new("UIGradient")
        g.Name = "YunoGrad"
        g.Rotation = 45
        g.Parent = obj
    end
    local h, s, v = color:ToHSV()
    local glow = Color3.fromHSV(h, math.clamp(s - 0.2, 0, 1), math.clamp(v + 0.25, 0, 1))
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(0.5, glow),
        ColorSequenceKeypoint.new(1, color),
    })
end

-- Notifications
local notifyHolder
local function Notify(title, msg, dur, iconId)
    if not notifyHolder then return end
    dur = dur or 3
    local f = Make("Frame", { Size = UDim2.new(0, 300, 0, 70), BackgroundTransparency = 1, Parent = notifyHolder })
    local bg = Make("Frame", { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(1, 40, 0, 0), BackgroundColor3 = Theme.Section, Parent = f })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = bg })
    Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = bg })
    local accent = Make("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = bg })
    local titleLbl = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1,
        Text = title or "Yuno", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = bg })
    local msgLbl = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 30), Position = UDim2.new(0, 15, 0, 32), BackgroundTransparency = 1,
        Text = msg or "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = bg })
    Tween(bg, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
    task.delay(dur, function()
        local t = Tween(bg, 0.3, { Position = UDim2.new(1, 40, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        t.Completed:Connect(function() f:Destroy() end)
    end)
end
getgenv().YunoNotify = Notify

-- ══════════════════ UI LIBRARY COMPACTE ══════════════════
local UI = {}
local screenGui
local mainFrame
local mainScale
local floatBtn

-- UI primitives
function UI.Toggle(parent, cfg)
    cfg = cfg or {}
    local flag = cfg.Flag or cfg.Name
    local state = cfg.Default == true
    if Flags[flag] ~= nil then state = Flags[flag] end
    Flags[flag] = state

    local card = Make("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.Section, Parent = parent })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
    Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = card })
    Make("TextLabel", { Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 15, 0, 10), BackgroundTransparency = 1,
        Text = cfg.Name or "Toggle", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
    if cfg.Description then
        Make("TextLabel", { Size = UDim2.new(1, -80, 0, 14), Position = UDim2.new(0, 15, 0, 30), BackgroundTransparency = 1,
            Text = cfg.Description, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
    end

    local btn = Make("TextButton", { Size = UDim2.new(0, 44, 0, 24), Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundTransparency = 1, Text = "", Parent = card })
    local track = Make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff, Parent = btn })
    Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    local knob = Make("Frame", { Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = Theme.Knob, Parent = track })
    Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
    knob.Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)

    if state then ApplyGradientTo(track, Theme.Accent) end

    local function setState(v, silent)
        state = v
        Flags[flag] = v
        Tween(track, 0.25, { BackgroundColor3 = v and Theme.Accent or Theme.ToggleOff })
        Tween(knob, 0.25, { Position = v and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10) }, Enum.EasingStyle.Back)
        if v then ApplyGradientTo(track, Theme.Accent)
        else
            local g = track:FindFirstChild("YunoGrad")
            if g then g:Destroy() end
        end
        if not silent and cfg.Callback then pcall(cfg.Callback, v) end
    end

    btn.MouseButton1Click:Connect(function() setState(not state) end)
    return { Set = setState, Get = function() return state end, Instance = card }
end

function UI.Button(parent, cfg)
    cfg = cfg or {}
    local btn = Make("TextButton", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Section, Text = "",
        AutoButtonColor = false, Parent = parent })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
    local stroke = Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = btn })
    Make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = cfg.Name or "Button",
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, Parent = btn })
    local scale = Instance.new("UIScale", btn)
    btn.MouseEnter:Connect(function() Tween(stroke, 0.2, { Color = Theme.Accent }); Tween(scale, 0.2, { Scale = 1.02 }) end)
    btn.MouseLeave:Connect(function() Tween(stroke, 0.2, { Color = Theme.Stroke }); Tween(scale, 0.2, { Scale = 1 }) end)
    btn.MouseButton1Click:Connect(function()
        Tween(scale, 0.1, { Scale = 0.96 }).Completed:Connect(function() Tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Bounce) end)
        if cfg.Callback then pcall(cfg.Callback) end
    end)
    return btn
end

function UI.Slider(parent, cfg)
    cfg = cfg or {}
    local flag = cfg.Flag or cfg.Name
    local minV, maxV = cfg.Min or 0, cfg.Max or 100
    local val = Flags[flag] or cfg.Default or minV
    val = math.clamp(val, minV, maxV)

    local card = Make("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.Section, Parent = parent })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
    Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = card })
    Make("TextLabel", { Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 15, 0, 10), BackgroundTransparency = 1,
        Text = cfg.Name or "Slider", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
    local valLbl = Make("TextLabel", { Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -75, 0, 10), BackgroundTransparency = 1,
        Text = tostring(val), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Right, Parent = card })

    local track = Make("Frame", { Size = UDim2.new(1, -30, 0, 6), Position = UDim2.new(0, 15, 0, 40), BackgroundColor3 = Theme.Sidebar, Parent = card })
    Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    local fill = Make("Frame", { Size = UDim2.new((val - minV) / (maxV - minV), 0, 1, 0), BackgroundColor3 = Theme.Accent, Parent = track })
    Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
    local trig = Make("TextButton", { Size = UDim2.new(1, 0, 1, 30), Position = UDim2.new(0, 0, 0.5, -15), BackgroundTransparency = 1, Text = "", Parent = track })

    local dragging = false
    local function update(posX, silent)
        local p = math.clamp((posX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local newVal = math.floor(minV + (maxV - minV) * p)
        val = newVal
        fill.Size = UDim2.new(p, 0, 1, 0)
        valLbl.Text = tostring(newVal)
        Flags[flag] = newVal
        if not silent and cfg.Callback then pcall(cfg.Callback, newVal) end
    end
    trig.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; update(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i.Position.X) end end)
    return { Set = function(v) val = v; local p = (v-minV)/(maxV-minV); fill.Size = UDim2.new(p,0,1,0); valLbl.Text = tostring(v); Flags[flag] = v end, Get = function() return val end }
end

function UI.Input(parent, cfg)
    cfg = cfg or {}
    local flag = cfg.Flag or cfg.Name
    local val = Flags[flag] or cfg.Default or ""
    Flags[flag] = val

    local card = Make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Theme.Section, Parent = parent })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
    Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = card })
    Make("TextLabel", { Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0, 15, 0, 0), BackgroundTransparency = 1,
        Text = cfg.Name or "Input", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
    local box = Make("Frame", { Size = UDim2.new(0.55, -30, 0, 30), Position = UDim2.new(0.45, 15, 0.5, -15), BackgroundColor3 = Theme.Sidebar, Parent = card })
    Make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = box })
    local input = Make("TextBox", { Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1,
        Text = tostring(val), PlaceholderText = cfg.Placeholder or "Enter...", Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
    input.FocusLost:Connect(function()
        val = input.Text
        Flags[flag] = val
        if cfg.Callback then pcall(cfg.Callback, val) end
    end)
    return { Get = function() return input.Text end, Set = function(v) input.Text = v; Flags[flag] = v end }
end

function UI.Dropdown(parent, cfg)
    cfg = cfg or {}
    local flag = cfg.Flag or cfg.Name
    local options = cfg.Options or {}
    local val = Flags[flag] or cfg.Default or (options[1] or "")
    Flags[flag] = val

    local card = Make("Frame", { Size = UDim2.new(1, 0, 0, 45), BackgroundColor3 = Theme.Section, Parent = parent })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
    Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = card })
    Make("TextLabel", { Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 15, 0, 0), BackgroundTransparency = 1,
        Text = cfg.Name or "Dropdown", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })

    local picker = Make("TextButton", { Size = UDim2.new(0.45, -20, 0, 28), Position = UDim2.new(0.5, 10, 0.5, -14), BackgroundColor3 = Theme.Sidebar, Text = tostring(val),
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, Parent = card })
    Make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = picker })

    local list = Make("ScrollingFrame", { Size = UDim2.new(0.45, -20, 0, 0), Position = UDim2.new(0.5, 10, 1, 2), BackgroundColor3 = Theme.Section,
        Visible = false, ZIndex = 20, ScrollBarThickness = 2, Parent = card })
    Make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = list })
    Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = list })

    local open = false
    local function refresh()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for i, opt in ipairs(options) do
            local b = Make("TextButton", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, (i-1)*24),
                BackgroundTransparency = 1, Text = tostring(opt), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.SubText, ZIndex = 21, Parent = list })
            b.MouseEnter:Connect(function() b.TextColor3 = Theme.Accent end)
            b.MouseLeave:Connect(function() b.TextColor3 = Theme.SubText end)
            b.MouseButton1Click:Connect(function()
                val = opt; picker.Text = tostring(opt); Flags[flag] = val
                list.Visible = false; open = false; list.Size = UDim2.new(0.45, -20, 0, 0)
                if cfg.Callback then pcall(cfg.Callback, val) end
            end)
        end
        list.CanvasSize = UDim2.new(0, 0, 0, #options * 24)
    end
    picker.MouseButton1Click:Connect(function()
        open = not open
        if open then refresh(); list.Visible = true; list.Size = UDim2.new(0.45, -20, 0, math.min(#options * 24, 120))
        else list.Visible = false; list.Size = UDim2.new(0.45, -20, 0, 0) end
    end)
    return { Get = function() return val end, Set = function(v) val = v; picker.Text = tostring(v); Flags[flag] = v end }
end

function UI.Section(parent, title)
    local lbl = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
        Text = title or "Section", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
    return lbl
end

function UI.Divider(parent)
    local f = Make("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = parent })
    return f
end

-- ══════════════════ WINDOW + TABS ══════════════════
screenGui = Make("ScreenGui", { Name = "YunoFarm_UI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Global })
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = LP:WaitForChild("PlayerGui") end

-- Notifications holder
notifyHolder = Make("Frame", { Size = UDim2.new(0, 320, 1, -40), Position = UDim2.new(1, -330, 0, 20), BackgroundTransparency = 1, Parent = screenGui })
Make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), Parent = notifyHolder })

-- Main window
mainFrame = Make("CanvasGroup", { Size = UDim2.new(0, 660, 0, 440), Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.05,
    BorderSizePixel = 0, Parent = screenGui })
Make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = mainFrame })
Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Transparency = 0.3, Parent = mainFrame })

mainScale = Instance.new("UIScale", mainFrame)
mainScale.Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1))

-- Title bar
local titleBar = Make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Sidebar, BackgroundTransparency = 0.3,
    BorderSizePixel = 0, Parent = mainFrame })
Make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = titleBar })

local function LogoParent(parent)
    local logo = Make("ImageLabel", { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 12, 0.5, -13), BackgroundTransparency = 1,
        Image = "rbxassetid://7733960981", Parent = parent })
    logo.ImageColor3 = Theme.Accent
    return logo
end
LogoParent(titleBar)

Make("TextLabel", { Size = UDim2.new(0, 40, 0, 18), Position = UDim2.new(0, 44, 0, 8), BackgroundTransparency = 1,
    Text = "Yuno", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })
Make("TextLabel", { Size = UDim2.new(0, 40, 0, 18), Position = UDim2.new(0, 84, 0, 8), BackgroundTransparency = 1,
    Text = "Farm", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })
Make("TextLabel", { Size = UDim2.new(0, 40, 0, 14), Position = UDim2.new(0, 128, 0, 10), BackgroundTransparency = 1,
    Text = "v1.0", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })

-- Close btn
local closeBtn = Make("TextButton", { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -36, 0, 9), BackgroundColor3 = Color3.fromRGB(255, 90, 90),
    Text = "", AutoButtonColor = false, Parent = titleBar })
Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = closeBtn })
Make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "✕", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1,1,1), Parent = closeBtn })

-- Sidebar + content
local sidebar = Make("Frame", { Size = UDim2.new(0, 60, 1, -44), Position = UDim2.new(0, 0, 0, 44), BackgroundColor3 = Theme.Sidebar, BackgroundTransparency = 0.5,
    BorderSizePixel = 0, Parent = mainFrame })
Make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = sidebar })
Make("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = sidebar })
Make("UIPadding", { PaddingTop = UDim.new(0, 20), Parent = sidebar })

local content = Make("Frame", { Size = UDim2.new(1, -80, 1, -60), Position = UDim2.new(0, 70, 0, 50),
    BackgroundTransparency = 1, ClipsDescendants = true, Parent = mainFrame })

-- Tab system
local tabs = {}
local currentTab = nil
local function AddTab(icon, name, builder)
    local btn = Make("TextButton", { Size = UDim2.new(0, 40, 0, 40), BackgroundColor3 = Theme.Section, Text = "", AutoButtonColor = false, Parent = sidebar })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
    Make("ImageLabel", { Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(0.5, -11, 0.5, -11),
        BackgroundTransparency = 1, Image = "rbxassetid://" .. icon, ImageColor3 = Theme.SubText, Parent = btn })
    local page = Make("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.SubText, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false, Parent = content })
    Make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
    Make("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 20), Parent = page })
    local tab = { btn = btn, page = page, icon = btn:FindFirstChildOfClass("ImageLabel") }
    table.insert(tabs, tab)
    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(tabs) do
            t.page.Visible = false
            Tween(t.icon, 0.2, { ImageColor3 = Theme.SubText })
            Tween(t.btn, 0.2, { BackgroundColor3 = Theme.Section })
        end
        page.Visible = true
        Tween(tab.icon, 0.2, { ImageColor3 = Theme.Accent })
        Tween(tab.btn, 0.2, { BackgroundColor3 = Theme.Accent })
        currentTab = tab
    end)
    if builder then builder(page) end
    return page
end

-- ══════════════════ DRAG ══════════════════
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = mainFrame.Position
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local delta = i.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ══════════════════ FLOAT Y CIRCLE ══════════════════
floatBtn = Make("TextButton", { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0.5, -30, 0, 80),
    BackgroundColor3 = Theme.Accent, Text = "", AutoButtonColor = false, Visible = false, Parent = screenGui })
Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = floatBtn })
Make("UIStroke", { Thickness = 2, Color = Theme.Accent2, Parent = floatBtn })
Make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "Y",
    Font = Enum.Font.GothamBlack, TextSize = 32, TextColor3 = Color3.new(1, 1, 1), Parent = floatBtn })
ApplyGradientTo(floatBtn, Theme.Accent)

-- Float drag
local fDrag, fStart, fPos
floatBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        fDrag = true; fStart = i.Position; fPos = floatBtn.Position
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        if fDrag and fStart and (floatBtn.Position - fPos).X.Offset ^ 2 + (floatBtn.Position - fPos).Y.Offset ^ 2 < 4 then
            -- Click (no move) → reopen
            floatBtn.Visible = false
            mainFrame.Visible = true
            mainScale.Scale = mainScale.Scale * 0.85
            Tween(mainScale, 0.3, { Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1)) }, Enum.EasingStyle.Back)
        end
        fDrag = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if fDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - fStart
        floatBtn.Position = UDim2.new(fPos.X.Scale, fPos.X.Offset + d.X, fPos.Y.Scale, fPos.Y.Offset + d.Y)
    end
end)

-- Close main → show float
closeBtn.MouseButton1Click:Connect(function()
    Tween(mainScale, 0.25, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
        mainFrame.Visible = false
        floatBtn.Visible = true
    end)
end)

-- ══════════════════ INTRO ANIMATION ══════════════════
local function PlayIntro(cb)
    local g = Make("ScreenGui", { Name = "YunoFarm_Intro", IgnoreGuiInset = true, DisplayOrder = 9999, ResetOnSpawn = false })
    pcall(function() g.Parent = CoreGui end)
    if not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end
    local bg = Make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(8, 10, 16), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = g })
    local box = Make("Frame", { Size = UDim2.new(0, 420, 0, 220), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = bg })
    local yuno = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 90), Position = UDim2.new(0, 0, 0.15, 0), BackgroundTransparency = 1,
        Text = "YUNO", Font = Enum.Font.GothamBlack, TextSize = 72, TextColor3 = Color3.fromRGB(255, 255, 255), TextTransparency = 1, Parent = box })
    local line = Make("Frame", { Size = UDim2.new(0, 0, 0, 2), Position = UDim2.new(0.5, 0, 0.55, 0), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Parent = box })
    Instance.new("UIGradient", line).Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 170, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 130, 255)),
    })
    local farm = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.6, 0), BackgroundTransparency = 1,
        Text = "F A R M", Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = Color3.fromRGB(140, 180, 255), TextTransparency = 1, Parent = box })
    local sub = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.85, 0), BackgroundTransparency = 1,
        Text = "Initializing...", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(120, 130, 160), TextTransparency = 1, Parent = box })

    Tween(bg, 0.4, { BackgroundTransparency = 0 })
    task.wait(0.4)
    Tween(yuno, 0.5, { TextTransparency = 0 }, Enum.EasingStyle.Back)
    task.wait(0.3)
    Tween(farm, 0.4, { TextTransparency = 0 })
    Tween(line, 0.8, { Size = UDim2.new(0, 220, 0, 2) })
    task.wait(0.5)
    Tween(sub, 0.4, { TextTransparency = 0 })
    task.wait(1.6)
    Tween(yuno, 0.3, { TextTransparency = 1 })
    Tween(farm, 0.3, { TextTransparency = 1 })
    Tween(sub, 0.3, { TextTransparency = 1 })
    Tween(line, 0.3, { Size = UDim2.new(0, 0, 0, 2) })
    task.wait(0.35)
    Tween(bg, 0.35, { BackgroundTransparency = 1 })
    task.wait(0.4)
    g:Destroy()
    if cb then cb() end
end

-- ══════════════════ PET VISUALS ══════════════════
local VisualVars = {
    Mega = false, Neon = false, Fly = false, Ride = false, Eggs = false, CustomColorOn = false,
}
getgenv().YunoVisualVars = VisualVars
local SavedPetVisuals = {}
local VisualParts = {}

local function GetPetColor(petData, db)
    if VisualVars.CustomColorOn then return Color3.new(1,1,1) end
    return db.neon_color or Color3.fromRGB(255, 255, 255)
end

local function RefreshPetVisuals()
    table.clear(VisualParts)
    local wrappers = M.ClientData.get("pet_char_wrappers") or {}
    for _, w in pairs(wrappers) do
        if w.player == LP and w.char then
            local saved = SavedPetVisuals[w.pet_unique]
            if saved then
                local model = w.char:FindFirstChild("PetModel") or w.char
                local db = M.InventoryDB.pets[w.pet_id]
                if db then
                    local mega = saved.Mega or VisualVars.Mega
                    local neon = saved.Neon or VisualVars.Neon
                    if mega or neon then
                        local parts = mega and (db.mega_neon_parts or db.neon_parts) or db.neon_parts or {}
                        for k, v in pairs(parts) do
                            local partName = type(k) == "string" and k or v
                            for _, desc in ipairs(model:GetDescendants()) do
                                if desc:IsA("BasePart") and desc.Name == partName then
                                    table.insert(VisualParts, { Part = desc, IsMega = mega, Color = GetPetColor(w, db) })
                                    if desc:IsA("MeshPart") and desc.TextureID ~= "" then desc.TextureID = "" end
                                    desc.Material = Enum.Material.Neon
                                    if neon and not mega then desc.Color = GetPetColor(w, db) end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Rainbow animation
task.spawn(function()
    local RainbowColors = {
        Color3.fromRGB(255, 72, 69), Color3.fromRGB(255, 96, 93), Color3.fromRGB(245, 255, 99),
        Color3.fromRGB(149, 255, 79), Color3.fromRGB(73, 255, 82), Color3.fromRGB(80, 255, 159),
        Color3.fromRGB(78, 47, 255), Color3.fromRGB(160, 97, 255), Color3.fromRGB(255, 97, 189),
    }
    RunService.Heartbeat:Connect(function()
        if #VisualParts == 0 then return end
        local t = tick() * 2
        local idx = math.floor(t % #RainbowColors) + 1
        local c = RainbowColors[idx]:Lerp(RainbowColors[idx % #RainbowColors + 1], t % 1)
        for _, v in ipairs(VisualParts) do
            if v.Part and v.Part.Parent then
                v.Part.Material = Enum.Material.Neon
                v.Part.Transparency = 0
                if v.IsMega then v.Part.Color = c else v.Part.Color = v.Color end
            end
        end
    end)
end)

-- Hook ClientData.get to fake neon/mega/fly/ride client-side
local realGet = M.ClientData.get
M.ClientData.get = function(self, key, sub, ...)
    local res = realGet(self, key, sub, ...)
    if key == "inventory" and sub ~= "Raw" and type(res) == "table" and res.pets then
        local newPets = {}
        for uid, pet in pairs(res.pets) do
            local saved = SavedPetVisuals[uid]
            if saved then
                local clone = {}
                for k, v in pairs(pet) do clone[k] = v end
                local props = {}
                for k, v in pairs(pet.properties or {}) do props[k] = v end
                props.neon = saved.Neon or VisualVars.Neon
                props.mega_neon = saved.Mega or VisualVars.Mega
                props.flyable = saved.Fly or VisualVars.Fly
                props.is_flyable = props.flyable
                props.rideable = saved.Ride or VisualVars.Ride
                props.is_rideable = props.rideable
                clone.properties = props
                newPets[uid] = clone
            else
                newPets[uid] = pet
            end
        end
        local cloned = {}
        for k, v in pairs(res) do cloned[k] = v end
        cloned.pets = newPets
        return cloned
    end
    return res
end

local function ApplyVisualsToCurrent()
    local wrapper = nil
    for _, w in pairs(M.ClientData.get("pet_char_wrappers") or {}) do
        if w.player == LP then wrapper = w; break end
    end
    if not wrapper then return end
    SavedPetVisuals[wrapper.pet_unique] = {
        Mega = VisualVars.Mega, Neon = VisualVars.Neon,
        Fly = VisualVars.Fly, Ride = VisualVars.Ride, Eggs = VisualVars.Eggs,
    }
    RefreshPetVisuals()
    pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end)
end
local function ApplyVisualsToAll()
    local inv = realGet(M.ClientData, "inventory", "Raw")
    if inv and inv.pets then
        for uid in pairs(inv.pets) do
            SavedPetVisuals[uid] = {
                Mega = VisualVars.Mega, Neon = VisualVars.Neon,
                Fly = VisualVars.Fly, Ride = VisualVars.Ride, Eggs = VisualVars.Eggs,
            }
        end
    end
    RefreshPetVisuals()
    pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end)
end
local function ResetVisuals()
    SavedPetVisuals = {}
    VisualVars.Mega = false; VisualVars.Neon = false; VisualVars.Fly = false; VisualVars.Ride = false
    RefreshPetVisuals()
    pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end)
end

-- ══════════════════ FARM LOGIC ══════════════════
local FarmEnabled = false
local PetFarmEnabled = false
local BabyFarmEnabled = false
local AutoEquipWatchdog = false
local LockedPets = {}
local lastFarmStatus = ""

local function UpdateStatus(s)
    if s ~= lastFarmStatus then
        lastFarmStatus = s
        local lbl = Flags.__statusLbl
        if lbl and lbl.Parent then lbl.Text = "Status: " .. s end
    end
end

local function GetFarmTargets()
    local out = { Baby = {}, Pets = {} }
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local am = data.ailments_manager or pd.ailments_manager or M.ClientData.get("ailments_manager")
    if not am then return out end
    if BabyFarmEnabled and am.baby_ailments then
        for _, a in pairs(am.baby_ailments) do
            if a.kind then out.Baby[a.kind] = true end
        end
    end
    if PetFarmEnabled then
        local wrappers = data.pet_char_wrappers or pd.pet_char_wrappers or M.ClientData.get("pet_char_wrappers")
        if wrappers then
            for _, w in pairs(wrappers) do
                if w.player == LP then
                    local al = am.ailments[w.pet_unique] or {}
                    local needs = {}
                    for _, a in pairs(al) do if a.kind then needs[a.kind] = true end end
                    if next(needs) then
                        table.insert(out.Pets, { uid = w.pet_unique, char = w.char, needs = needs, id = w.pet_id })
                    end
                end
            end
        end
    end
    return out
end

local function EquipPet(uid)
    pcall(function() API.Unequip:InvokeServer() end)
    task.wait(0.4)
    pcall(function() API.Equip:InvokeServer(uid, { equip_as_last = true }) end)
    task.wait(1.2)
end

local function FeedPetPet(uid)
    local PetObjects = workspace:FindFirstChild("PetObjects")
    if not PetObjects then return end
    pcall(function()
        local obj = API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_1", {
            reaction_name = "ThrowToyReaction",
            unique_id = "squeaky_bone_default",
            pet_unique = uid,
        })
    end)
end

-- Main loop
task.spawn(function()
    while task.wait(1.5) do
        if FarmEnabled and (PetFarmEnabled or BabyFarmEnabled) then
            local ok, err = pcall(function()
                local targets = GetFarmTargets()
                if next(targets.Baby) or #targets.Pets > 0 then
                    local needs = {}
                    for k in pairs(targets.Baby) do needs[k] = true end
                    for _, p in ipairs(targets.Pets) do for k in pairs(p.needs) do needs[k] = true end end

                    -- Basic tasks that work
                    if needs.pet_me then
                        UpdateStatus("Doing pet_me")
                        for _, p in ipairs(targets.Pets) do
                            if p.needs.pet_me then
                                pcall(function() API.ProgressPetMe:FireServer(p.uid) end)
                                task.wait(1.5)
                            end
                        end
                    elseif needs.mystery then
                        UpdateStatus("Solving mystery")
                        pcall(function()
                            API.ChooseMystery:FireServer(nil, "mystery", "any", "any")
                        end)
                        task.wait(1)
                    elseif needs.hungry then
                        UpdateStatus("Feeding pets")
                        local inv = M.ClientData.get("inventory", "Raw")
                        if inv and inv.food then
                            for k, v in pairs(inv.food) do
                                if (v.id == "apple" or v.kind == "apple") and targets.Pets[1] then
                                    pcall(function()
                                        local model = API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_2", {
                                            pet_unique = targets.Pets[1].uid, unique_id = k,
                                        })
                                        if model then
                                            API.ConsumeFoodObject:FireServer(model:FindFirstChild("Model") or model, targets.Pets[1].uid)
                                        end
                                    end)
                                    break
                                end
                            end
                        end
                        task.wait(1.5)
                    elseif needs.thirsty then
                        UpdateStatus("Giving water")
                        -- similar to hungry but water
                        task.wait(1)
                    elseif needs.play then
                        UpdateStatus("Playing with pets")
                        for _, p in ipairs(targets.Pets) do
                            if p.needs.play then
                                FeedPetPet(p.uid)
                                task.wait(0.6)
                            end
                        end
                    else
                        UpdateStatus("Unknown need: " .. next(needs))
                        task.wait(2)
                    end
                else
                    UpdateStatus("Idle (no tasks)")
                    if AutoEquipWatchdog then
                        -- keep locked pets equipped
                        local eq = M.ClientData.get("equip_manager") or {}
                        local equipped = {}
                        for _, p in ipairs(eq.pets or {}) do equipped[p.unique] = true end
                        for uid in pairs(LockedPets) do
                            if not equipped[uid] then
                                EquipPet(uid)
                            end
                        end
                    end
                end
            end)
            if not ok then UpdateStatus("Error: " .. tostring(err)) end
        else
            UpdateStatus(FarmEnabled and "Waiting..." or "Farm OFF")
        end
    end
end)

-- ══════════════════ FAST MEGA CRAFT ══════════════════
local FastMegaEnabled = false
local FastMegaMode = "Neon" -- "Neon" ou "Mega"
local FastMegaTargets = {}

task.spawn(function()
    while task.wait(3) do
        if not FastMegaEnabled then continue end
        local ok, err = pcall(function()
            local inv = M.ClientData.get("inventory", "Raw")
            if not inv or not inv.pets then return end
            local eq = M.ClientData.get("equip_manager") or {}
            local equipped = (eq.pets or {})[1]

            -- Group by kind
            local groups = {}
            for uid, pet in pairs(inv.pets) do
                local kind = pet.kind or pet.id
                if FastMegaTargets[kind] then
                    local props = pet.properties or {}
                    local age = props.age or 1
                    local isNeon = props.neon or props.is_neon
                    local isMega = props.mega_neon or props.is_mega
                    local key
                    if FastMegaMode == "Neon" then
                        if age == 6 and not isNeon and not isMega then key = "ready_regular"
                        elseif isNeon and not isMega then key = "ready_neon" end
                    else
                        if age == 6 and not isNeon and not isMega then key = "ready_regular"
                        elseif isNeon and not isMega then key = "ready_neon" end
                    end
                    if key then
                        groups[kind] = groups[kind] or { ready_regular = {}, ready_neon = {} }
                        table.insert(groups[kind][key], uid)
                    end
                end
            end

            for kind, g in pairs(groups) do
                if #g.ready_regular >= 4 then
                    local selected = { g.ready_regular[1], g.ready_regular[2], g.ready_regular[3], g.ready_regular[4] }
                    UpdateStatus("Crafting Neon " .. kind)
                    pcall(function() API.DoNeonFusion:InvokeServer(selected) end)
                    task.wait(4)
                elseif FastMegaMode == "Mega" and #g.ready_neon >= 4 then
                    local selected = { g.ready_neon[1], g.ready_neon[2], g.ready_neon[3], g.ready_neon[4] }
                    UpdateStatus("Crafting Mega " .. kind)
                    pcall(function() API.DoNeonFusion:InvokeServer(selected) end)
                    task.wait(4)
                end
            end
        end)
        if not ok then UpdateStatus("Mega error: " .. tostring(err)) end
    end
end)

-- ══════════════════ SHOP AUTO-BUY ══════════════════
local AutoBuyEnabled = false
local BuyTargets = {}
local ShopCatalog = {
    cracked_egg = { cat = "pets", price = 350, name = "Cracked Egg" },
    regular_pet_egg = { cat = "pets", price = 600, name = "Pet Egg" },
    royal_egg = { cat = "pets", price = 1450, name = "Royal Egg" },
    smallgift = { cat = "gifts", price = 70, name = "Small Gift" },
    biggift = { cat = "gifts", price = 199, name = "Big Gift" },
    massivegift = { cat = "gifts", price = 499, name = "Massive Gift" },
    big_head_potion = { cat = "food", price = 10, name = "Big Head Potion" },
    hyperspeed_potion = { cat = "food", price = 40, name = "Hyperspeed Potion" },
    nograv_potion = { cat = "food", price = 99, name = "Anti-gravity Potion" },
}

task.spawn(function()
    while task.wait(2) do
        if not AutoBuyEnabled then continue end
        local money = M.ClientData.get("money") or 0
        for kind, on in pairs(BuyTargets) do
            if on and ShopCatalog[kind] then
                local item = ShopCatalog[kind]
                if money >= item.price then
                    pcall(function() API.BuyItem:InvokeServer(item.cat, kind, { buy_count = 1 }) end)
                    task.wait(0.8)
                end
            end
        end
    end
end)

-- ══════════════════ TELEPORTS ══════════════════
local function TeleportTo(locId)
    pcall(function() API.SetLocation:FireServer(locId) end)
end

-- ══════════════════ TRADE VALUES (configurable URL) ══════════════════
local ValuesCache = {}
local ValuesSourceURL = ""
local function LoadValues()
    if ValuesSourceURL == "" then return end
    pcall(function()
        local raw = game:HttpGet(ValuesSourceURL)
        local data = HttpService:JSONDecode(raw)
        ValuesCache = data or {}
    end)
end
local function GetItemValue(kind, props)
    local lower = tostring(kind):lower():gsub("[%s%-_]+", "")
    for k, v in pairs(ValuesCache) do
        if tostring(k):lower():gsub("[%s%-_]+", "") == lower then
            if type(v) == "table" then
                local isMega = props and (props.mega_neon or props.is_mega)
                local isNeon = props and (props.neon or props.is_neon)
                if isMega and v.mega then return v.mega end
                if isNeon and v.neon then return v.neon end
                return v.regular or v.value or 0
            elseif type(v) == "number" then return v end
        end
    end
    return 0
end

-- ══════════════════ TABS BUILD ══════════════════
-- HOME
AddTab("7733960981", "Home", function(page)
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.3, Parent = page })
    local lastChild = page:FindFirstChildOfClass("TextLabel")
    Make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = lastChild })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 22), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1,
        Text = "Welcome to Yuno Farm", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = lastChild })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 34), BackgroundTransparency = 1,
        Text = "Session • " .. (IS_MOBILE and "Mobile" or "PC") .. " • v1.0", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = lastChild })

    local statusCard = Make("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.3, Parent = page })
    Make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = statusCard })
    local statusLbl = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1,
        Text = "Status: Idle", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = statusCard })
    Flags.__statusLbl = statusLbl
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 32), BackgroundTransparency = 1,
        Text = "Farm status indicator", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = statusCard })

    UI.Section(page, "Informations")
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 80), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.3, TextWrapped = true, Parent = page,
        Text = "• Yuno Farm v1.0 standalone\n• AutoFarm pets & baby\n• Pet Visuals (Mega/Neon/Fly/Ride)\n• Fast Mega/Neon craft\n• Trade values & Shop",
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left })
end)

-- AUTOFARM
AddTab("6908632622", "AutoFarm", function(page)
    UI.Section(page, "Master")
    UI.Toggle(page, {
        Name = "Farm Master Switch", Flag = "YF_FarmMaster", Description = "Enables farming loops", Default = false,
        Callback = function(v) FarmEnabled = v; Notify("Yuno", v and "Farm enabled" or "Farm disabled") end
    })
    UI.Toggle(page, { Name = "Pet Farm", Flag = "YF_PetFarm", Description = "Auto-completes pet tasks", Callback = function(v) PetFarmEnabled = v end })
    UI.Toggle(page, { Name = "Baby Farm", Flag = "YF_BabyFarm", Description = "Auto-completes baby tasks", Callback = function(v) BabyFarmEnabled = v end })

    UI.Section(page, "Combat Watchdog")
    UI.Toggle(page, { Name = "Auto Equip Watchdog", Flag = "YF_Watchdog", Description = "Re-equips locked pets automatically", Callback = function(v) AutoEquipWatchdog = v end })

    UI.Section(page, "Age-Up Farm")
    UI.Toggle(page, { Name = "Age-Pot Farm (Idle)", Flag = "YF_AgePot", Description = "Auto feeds age potions to grow pets", Callback = function(v)
        if v then
            Notify("Age-Pot", "Enabled — equips FG pets and feeds pots")
            task.spawn(function()
                while Flags.YF_AgePot do
                    task.wait(3)
                    if not Flags.YF_AgePot then break end
                    pcall(function()
                        -- Equip 1 FG pet, add to pen, claim loop
                        local inv = M.ClientData.get("inventory", "Raw")
                        if inv and inv.pets then
                            local picked
                            for uid, p in pairs(inv.pets) do
                                local pr = p.properties or {}
                                local db = M.InventoryDB.pets[p.kind or p.id]
                                if db and not db.is_egg and (pr.age or 1) == 6 and not (pr.neon or pr.mega_neon) then picked = uid; break end
                            end
                            if picked then
                                API.Unequip:InvokeServer()
                                task.wait(0.3)
                                API.Equip:InvokeServer(picked, { equip_as_last = true })
                                task.wait(1)
                                API.AddPet:InvokeServer(picked)
                                task.wait(1)
                                API.ClaimProgression:FireServer(true)
                            end
                        end
                    end)
                end
            end)
        end
    end })
end)

-- PET VISUALS
AddTab("13549782519", "Pets", function(page)
    UI.Section(page, "Client-Side Pet Visuals")
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.4, TextWrapped = true, Parent = page,
        Text = "Visual only — server doesn't see these changes. Other players see them normally.",
        Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = page:GetChildren()[#page:GetChildren()] })

    UI.Toggle(page, { Name = "Mega Neon", Flag = "YF_VisMega", Callback = function(v) VisualVars.Mega = v; if v then VisualVars.Neon = false; Flags.YF_VisNeon = false end end })
    UI.Toggle(page, { Name = "Neon", Flag = "YF_VisNeon", Callback = function(v) VisualVars.Neon = v; if v then VisualVars.Mega = false; Flags.YF_VisMega = false end end })
    UI.Toggle(page, { Name = "Flyable", Flag = "YF_VisFly", Callback = function(v) VisualVars.Fly = v end })
    UI.Toggle(page, { Name = "Rideable", Flag = "YF_VisRide", Callback = function(v) VisualVars.Ride = v end })
    UI.Toggle(page, { Name = "Eggs Mode", Flag = "YF_VisEggs", Callback = function(v) VisualVars.Eggs = v end })

    UI.Section(page, "Apply")
    UI.Button(page, { Name = "Apply to Current Pet", Callback = function() ApplyVisualsToCurrent(); Notify("Visuals", "Applied to current pet") end })
    UI.Button(page, { Name = "Apply to ALL Pets", Callback = function() ApplyVisualsToAll(); Notify("Visuals", "Applied to all pets") end })
    UI.Button(page, { Name = "Reset All Visuals", Callback = function() ResetVisuals(); Notify("Visuals", "Reset done") end })
end)

-- FAST MEGA
AddTab("128557027005598", "FastMega", function(page)
    UI.Section(page, "Fast Mega/Neon Craft")
    UI.Toggle(page, { Name = "Enable Fast Mega", Flag = "YF_FastMega", Description = "Auto crafts neon/mega from pets age 6", Callback = function(v) FastMegaEnabled = v; if v then Notify("Fast Mega", "Started") end end })
    UI.Dropdown(page, { Name = "Target", Flag = "YF_FastMegaMode", Options = { "Neon", "Mega" }, Default = "Neon", Callback = function(v) FastMegaMode = v end })

    UI.Section(page, "Target Pets")
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Click pets to toggle target.", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = page })

    local grid = Make("Frame", { Size = UDim2.new(1, 0, 0, 260), BackgroundTransparency = 1, Parent = page })
    local gridLayout = Make("UIGridLayout", { CellSize = UDim2.new(0, 75, 0, 85), CellPadding = UDim2.new(0, 8, 0, 8), Parent = grid })

    task.spawn(function()
        task.wait(2)
        local DBPets = M.InventoryDB.pets
        local inv = M.ClientData.get("inventory", "Raw") or {}
        local counts = {}
        for _, p in pairs(inv.pets or {}) do
            local k = p.kind or p.id
            if k and DBPets[k] and not DBPets[k].is_egg then
                counts[k] = (counts[k] or 0) + 1
            end
        end
        for kind, count in pairs(counts) do
            local db = DBPets[kind]
            local img = db.icon or db.image or db.shop_image or "0"
            if tonumber(img) then img = "rbxassetid://" .. img end
            local btn = Make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Section, Text = "", AutoButtonColor = false, Parent = grid })
            Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
            local stroke = Make("UIStroke", { Thickness = 1, Color = FastMegaTargets[kind] and Theme.Accent or Theme.Stroke, Parent = btn })
            Make("ImageLabel", { Size = UDim2.new(0.8, 0, 0.6, 0), Position = UDim2.new(0.1, 0, 0.05, 0), BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Parent = btn })
            Make("TextLabel", { Size = UDim2.new(1, -4, 0, 16), Position = UDim2.new(0, 2, 1, -18), BackgroundTransparency = 1,
                Text = (db.name or kind) .. " x" .. count, Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = Theme.Text, TextWrapped = true, Parent = btn })
            btn.MouseButton1Click:Connect(function()
                FastMegaTargets[kind] = not FastMegaTargets[kind]
                stroke.Color = FastMegaTargets[kind] and Theme.Accent or Theme.Stroke
            end)
        end
    end)
end)

-- SHOP
AddTab("135780702746673", "Shop", function(page)
    UI.Section(page, "Auto-Buy")
    UI.Toggle(page, { Name = "Enable Auto-Buy", Flag = "YF_AutoBuy", Description = "Buys selected items when you have money", Callback = function(v) AutoBuyEnabled = v end })

    for kind, data in pairs(ShopCatalog) do
        UI.Toggle(page, { Name = data.name .. " (" .. data.price .. " $)", Flag = "YF_Buy_" .. kind, Callback = function(v) BuyTargets[kind] = v end })
    end
end)

-- TRADE
AddTab("9695309046", "Trade", function(page)
    UI.Section(page, "Values Calculator")
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.4, TextWrapped = true, Parent = page,
        Text = "Paste a JSON URL with pet values (format: { itemname: { regular: 1.5, neon: 2, mega: 3 } }). Yuno will cache it locally.",
        Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = page:GetChildren()[#page:GetChildren()] })

    UI.Input(page, { Name = "Values URL", Flag = "YF_ValuesURL", Placeholder = "https://...", Callback = function(v) ValuesSourceURL = v end })
    UI.Button(page, { Name = "Load Values", Callback = function() LoadValues(); Notify("Values", "Loaded " .. tostring(#ValuesCache) .. " items") end })

    UI.Section(page, "Trade Action")
    UI.Button(page, { Name = "Get Trade License (Quiz)", Callback = function()
        pcall(function()
            local api = RS:WaitForChild("API")
            if api:FindFirstChild("TradeAPI/BeginQuiz") then
                api["TradeAPI/BeginQuiz"]:InvokeServer()
                for i = 1, 3 do api["TradeAPI/AnswerQuizQuestion"]:InvokeServer(true) end
            end
        end)
        Notify("Trade", "License attempt sent")
    end })
end)

-- SETTINGS
AddTab("7734053495", "Settings", function(page)
    UI.Section(page, "UI")
    UI.Dropdown(page, { Name = "Theme", Flag = "YF_Theme", Options = { "YunoDark", "YunoLight" }, Default = ThemeName, Callback = function(v) ApplyTheme(v) end })
    UI.Slider(page, { Name = "UI Scale %", Flag = "YF_Scale", Min = 40, Max = 150, Default = math.floor((getgenv().YunoScale or 1) * 100), Callback = function(v)
        getgenv().YunoScale = v / 100
        mainScale.Scale = v / 100
    end })
    UI.Toggle(page, { Name = "Menu Blur", Flag = "YF_Blur", Description = "Blurs background when menu is open", Callback = function(v)
        local blur = game:GetService("Lighting"):FindFirstChild("YunoBlur")
        if v and not blur then
            blur = Instance.new("BlurEffect", game:GetService("Lighting"))
            blur.Name = "YunoBlur"
        end
        if blur then blur.Enabled = v end
    end })

    UI.Section(page, "Session")
    UI.Button(page, { Name = "Save Config", Callback = function()
        pcall(function()
            local data = {}
            for k, v in pairs(Flags) do
                if type(v) ~= "userdata" and k ~= "__statusLbl" then data[k] = v end
            end
            writefile(CFG_FILE, HttpService:JSONEncode(data))
            Notify("Yuno", "Config saved")
        end)
    end })
    UI.Button(page, { Name = "Reload UI", Callback = function() Notify("Yuno", "Rejoin to fully reload.") end })

    UI.Section(page, "Danger Zone")
    UI.Button(page, { Name = "Destroy Script", Callback = function()
        if screenGui then screenGui:Destroy() end
        if floatBtn then floatBtn:Destroy() end
        Notify("Yuno", "Script destroyed", 2)
    end })
end)

-- First tab
if tabs[1] then tabs[1].btn.MouseButton1Click:Fire() end

-- Load config
pcall(function()
    if isfile(CFG_FILE) then
        local data = HttpService:JSONDecode(readfile(CFG_FILE))
        for k, v in pairs(data) do Flags[k] = v end
    end
end)

-- ══════════════════ GO ══════════════════
mainFrame.Visible = false

PlayIntro(function()
    mainFrame.Visible = true
    mainScale.Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1)) * 0.85
    Tween(mainScale, 0.4, { Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1)) }, Enum.EasingStyle.Back)
    Notify("Yuno Farm", "Loaded • " .. (IS_MOBILE and "Mobile" or "PC") .. " mode", 4)
end)

print("[Yuno] ✅ Yuno Farm v1.0 loaded")
print("[Yuno] Click the Y circle to reopen after closing")