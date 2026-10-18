--[[
    ╔══════════════════════════════════════════════════╗
    ║        YUNO FARM v3.0 - FULL AUTOFARM FIX        ║
    ║   Pet + Baby + Quêtes + Halloween + 8 Thèmes      ║
    ╚══════════════════════════════════════════════════╝
]]

if not game:IsLoaded() then game.Loaded:Wait() end
game:GetService("ReplicatedStorage"):WaitForChild("Fsys", 999)

local Players    = game:GetService("Players")
local LP         = Players.LocalPlayer
local UIS        = game:GetService("UserInputService")
local TS         = game:GetService("TweenService")
local RS         = game:GetService("ReplicatedStorage")
local CoreGui    = game:GetService("CoreGui")
local HttpService= game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Lighting   = game:GetService("Lighting")

local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
local IS_MOBILE = UIS.TouchEnabled or vp.X < 900

if not isfolder("YunoFarm") then pcall(makefolder, "YunoFarm") end
local CFG_FILE = "YunoFarm/config.json"
local VAL_FILE = "YunoFarm/values.json"

local vu = game:GetService("VirtualUser")
LP.Idled:Connect(function() vu:CaptureController() vu:ClickButton2(Vector2.new()) end)

-- ══════════════════ API ADOPT ME ══════════════════
local Fsys = require(RS:WaitForChild("Fsys", 5))
local M = {
    RouterClient     = Fsys.load("RouterClient"),
    ClientData       = Fsys.load("ClientData"),
    InteriorsM       = Fsys.load("InteriorsM"),
    InventoryDB      = Fsys.load("InventoryDB"),
    KindDB           = Fsys.load("KindDB"),
    PetEntityManager = Fsys.load("PetEntityManager"),
    PetEntityHelper  = Fsys.load("PetEntityHelper"),
    LiveOpsTime      = Fsys.load("LiveOpsTime"),
}

local API = {
    Equip = M.RouterClient.get("ToolAPI/Equip"),
    Unequip = M.RouterClient.get("ToolAPI/Unequip"),
    ServerUseTool = M.RouterClient.get("ToolAPI/ServerUseTool"),
    DoNeonFusion = M.RouterClient.get("PetAPI/DoNeonFusion"),
    ConsumeFoodObject = M.RouterClient.get("PetAPI/ConsumeFoodObject"),
    ExitFurniture = M.RouterClient.get("PetAPI/ExitFurnitureUseStates"),
    CreatePetObject = M.RouterClient.get("PetObjectAPI/CreatePetObject"),
    GrabPetObject = M.RouterClient.get("PetObjectAPI/GrabPetObject"),
    DropPetObject = M.RouterClient.get("PetObjectAPI/DropPetObject"),
    ProgressPetMe = M.RouterClient.get("AilmentsAPI/ProgressPetMeAilment"),
    ChooseMystery = M.RouterClient.get("AilmentsAPI/ChooseMysteryAilment"),
    AddPet = M.RouterClient.get("IdleProgressionAPI/AddPet"),
    RemovePet = M.RouterClient.get("IdleProgressionAPI/RemovePet"),
    ClaimProgression = M.RouterClient.get("IdleProgressionAPI/CommitAllProgression"),
    MarkOverviewSeen = M.RouterClient.get("IdleProgressionAPI/MarkOverviewSeen"),
    MarkSummarySeen = M.RouterClient.get("IdleProgressionAPI/MarkSummarySeen"),
    BuyItem = M.RouterClient.get("ShopAPI/BuyItem"),
    SetLocation = M.RouterClient.get("LocationAPI/SetLocation"),
    ChooseTeam = M.RouterClient.get("TeamAPI/ChooseTeam"),
    SubscribeHouse = M.RouterClient.get("HousingAPI/SubscribeToHouse"),
    UnsubscribeHouse = M.RouterClient.get("HousingAPI/UnsubscribeFromHouse"),
    ActivateInterior = M.RouterClient.get("HousingAPI/ActivateInteriorFurniture"),
    ActivateFurniture = M.RouterClient.get("HousingAPI/ActivateFurniture"),
    BuyFurnitures = M.RouterClient.get("HousingAPI/BuyFurnitures"),
    ExitSeats = M.RouterClient.get("AdoptAPI/ExitSeatStates"),
    EjectBaby = M.RouterClient.get("AdoptAPI/EjectBaby"),
    UseStroller = M.RouterClient.get("AdoptAPI/UseStroller"),
}

-- Halloween remotes
local HalloweenRemote = {}
pcall(function()
    local apiFolder = RS:WaitForChild("API", 3)
    if apiFolder then
        HalloweenRemote.UnlockPadlock = apiFolder:FindFirstChild("Halloween2026/UnlockPadlock")
        HalloweenRemote.ClaimTombSpider = apiFolder:FindFirstChild("Halloween2026/ClaimTombSpider")
        HalloweenRemote.NestContribute = apiFolder:FindFirstChild("Halloween2026/JacobeanPigeonNestContributeTwig")
        HalloweenRemote.CandyClaim = apiFolder:FindFirstChild("Halloween2026/CandyCornPileClaim")
    end
    local net = RS:FindFirstChild("adoptme_new_net", 3)
    if net then
        for _, child in ipairs(net:GetChildren()) do
            if child.Name:find("Halloween2026") then
                HalloweenRemote[child.Name] = child
            end
        end
    end
end)

-- ══════════════════ CAC + TRACKING LOCATION ══════════════════
-- ⚠️ CRITICAL: cette section n'existait pas en v2, c'est pourquoi tout TP échouait

local Cac = {
    CurrentLocation = nil,
    MainPlatformLoaded = false,
    PlatformLoaded = false,
    IsRunning = false,
    FarmTargets = { Baby = {}, Pets = {} },
    TempNeeds = {},
    Connections = {},
    LastMysteryAttempt = nil,
    AppleUIDs = {},
    WaterUIDs = {},
    BedIds = { MainMap = {}, School = {} },
    ShowerIds = {},
    ToyUID = nil,
    StrollerUID = nil,
    LastStrollerEquip = 0,
}
getgenv().YunoCac = Cac

-- Poll get_current_location toutes les 0.5s
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local loc = M.InteriorsM.get_current_location and M.InteriorsM.get_current_location()
            if loc and loc.id then
                Cac.CurrentLocation = loc.id
            end
        end)
    end
end)

-- Hook update_server pour détecter les changements de location
pcall(function()
    local realUpdate = M.ClientData.update_server
    M.ClientData.update_server = function(self, player, event, data)
        if player == LP and event == "char_wrapper" and data and data.location then
            local destId = data.location.destination_id
            if destId then Cac.CurrentLocation = destId end
        end
        if realUpdate then return realUpdate(self, player, event, data) end
    end
end)

-- ══════════════════ THÈMES (portés du fichier original) ══════════════════
local THEMES = {
    Dark = {
        Background = Color3.fromRGB(15, 15, 20), Sidebar = Color3.fromRGB(20, 20, 25),
        Section = Color3.fromRGB(28, 28, 33), Text = Color3.fromRGB(255, 255, 255),
        SubText = Color3.fromRGB(120, 120, 130), Accent = Color3.fromRGB(255, 255, 255),
        Stroke = Color3.fromRGB(45, 45, 50), ToggleOff = Color3.fromRGB(55, 55, 60),
        Knob = Color3.fromRGB(20, 20, 25),
    },
    Light = {
        Background = Color3.fromRGB(245, 245, 250), Sidebar = Color3.fromRGB(255, 255, 255),
        Section = Color3.fromRGB(235, 235, 240), Text = Color3.fromRGB(20, 20, 25),
        SubText = Color3.fromRGB(100, 100, 110), Accent = Color3.fromRGB(0, 122, 255),
        Stroke = Color3.fromRGB(220, 220, 230), ToggleOff = Color3.fromRGB(200, 200, 210),
        Knob = Color3.fromRGB(255, 255, 255),
    },
    Amethyst = {
        Background = Color3.fromRGB(20, 10, 15), Sidebar = Color3.fromRGB(25, 15, 22),
        Section = Color3.fromRGB(33, 20, 30), Text = Color3.fromRGB(230, 215, 235),
        SubText = Color3.fromRGB(130, 110, 140), Accent = Color3.fromRGB(210, 180, 230),
        Stroke = Color3.fromRGB(50, 35, 55), ToggleOff = Color3.fromRGB(60, 45, 65),
        Knob = Color3.fromRGB(25, 15, 22),
    },
    Galaxy = {
        Background = Color3.fromRGB(12, 10, 20), Sidebar = Color3.fromRGB(18, 15, 30),
        Section = Color3.fromRGB(25, 20, 42), Text = Color3.fromRGB(240, 240, 255),
        SubText = Color3.fromRGB(150, 140, 190), Accent = Color3.fromRGB(110, 60, 255),
        Stroke = Color3.fromRGB(50, 40, 80), ToggleOff = Color3.fromRGB(40, 30, 70),
        Knob = Color3.fromRGB(20, 15, 35),
    },
    Emerald = {
        Background = Color3.fromRGB(15, 22, 18), Sidebar = Color3.fromRGB(20, 28, 22),
        Section = Color3.fromRGB(26, 36, 28), Text = Color3.fromRGB(240, 255, 240),
        SubText = Color3.fromRGB(130, 160, 140), Accent = Color3.fromRGB(46, 204, 113),
        Stroke = Color3.fromRGB(45, 60, 50), ToggleOff = Color3.fromRGB(40, 55, 45),
        Knob = Color3.fromRGB(20, 28, 22),
    },
    BlueDeepWave = {
        Background = Color3.fromRGB(10, 15, 25), Sidebar = Color3.fromRGB(15, 22, 35),
        Section = Color3.fromRGB(22, 30, 48), Text = Color3.fromRGB(235, 245, 255),
        SubText = Color3.fromRGB(120, 140, 180), Accent = Color3.fromRGB(0, 170, 255),
        Stroke = Color3.fromRGB(40, 50, 75), ToggleOff = Color3.fromRGB(35, 45, 65),
        Knob = Color3.fromRGB(15, 22, 35),
    },
    Yuno = {
        Background = Color3.fromRGB(12, 14, 22), Sidebar = Color3.fromRGB(18, 21, 32),
        Section = Color3.fromRGB(24, 28, 42), Text = Color3.fromRGB(240, 245, 255),
        SubText = Color3.fromRGB(120, 140, 170), Accent = Color3.fromRGB(110, 170, 255),
        Stroke = Color3.fromRGB(40, 48, 70), ToggleOff = Color3.fromRGB(45, 52, 72),
        Knob = Color3.fromRGB(240, 245, 255),
    },
}

local ThemeName = getgenv().YunoThemeName or "Yuno"
local Theme = THEMES[ThemeName] or THEMES.Yuno
local ThemeObjects = {}
local Flags = {}

local function ApplyTheme(newName)
    if not THEMES[newName] then return end
    ThemeName = newName
    getgenv().YunoThemeName = newName
    Theme = THEMES[newName]
    for obj, props in pairs(ThemeObjects) do
        if obj and obj.Parent then
            for prop, key in pairs(props) do pcall(function() obj[prop] = Theme[key] end) end
        end
    end
end

local function Make(class, props, theme)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if theme then
        ThemeObjects[inst] = {}
        for k, v in pairs(theme) do ThemeObjects[inst][k] = v; inst[k] = Theme[v] end
        inst.Destroying:Connect(function() ThemeObjects[inst] = nil end)
    end
    return inst
end

local function Tween(obj, dur, props, style, dir)
    local t = TS:Create(obj, TweenInfo.new(dur or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play(); return t
end

local function ApplyGradientTo(obj, color)
    local g = obj:FindFirstChild("YunoGrad")
    if not g then
        g = Instance.new("UIGradient"); g.Name = "YunoGrad"; g.Rotation = 45; g.Parent = obj
    end
    local h, s, v = color:ToHSV()
    local glow = Color3.fromHSV(h, math.clamp(s - 0.2, 0, 1), math.clamp(v + 0.25, 0, 1))
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(0.5, glow),
        ColorSequenceKeypoint.new(1, color),
    })
end

-- ══════════════════ NOTIFY ══════════════════
local notifyHolder
local function Notify(title, msg, dur, iconId)
    if not notifyHolder then return end
    dur = dur or 3
    local f = Make("Frame", { Size = UDim2.new(0, 300, 0, 70), BackgroundTransparency = 1, Parent = notifyHolder })
    local bg = Make("Frame", { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(1, 40, 0, 0), BackgroundColor3 = Theme.Section, Parent = f })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = bg })
    Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = bg })
    Make("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = bg })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1,
        Text = title or "Yuno", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = bg })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 30), Position = UDim2.new(0, 15, 0, 32), BackgroundTransparency = 1,
        Text = msg or "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = bg })
    Tween(bg, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
    task.delay(dur, function()
        local t = Tween(bg, 0.3, { Position = UDim2.new(1, 40, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        t.Completed:Connect(function() f:Destroy() end)
    end)
end

-- ══════════════════ UI PRIMITIVES ══════════════════
local UI = {}
local screenGui, mainFrame, mainScale, floatBtn

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
    local btn = Make("TextButton", { Size = UDim2.new(0, 44, 0, 24), Position = UDim2.new(1, -58, 0.5, -12), BackgroundTransparency = 1, Text = "", Parent = card })
    local track = Make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = state and Theme.Accent or Theme.ToggleOff, Parent = btn })
    Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    local knob = Make("Frame", { Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = Theme.Knob, Parent = track })
    Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
    knob.Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    if state then ApplyGradientTo(track, Theme.Accent) end
    local function setState(v, silent)
        state = v; Flags[flag] = v
        Tween(track, 0.25, { BackgroundColor3 = v and Theme.Accent or Theme.ToggleOff })
        Tween(knob, 0.25, { Position = v and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10) }, Enum.EasingStyle.Back)
        if v then ApplyGradientTo(track, Theme.Accent)
        else local g = track:FindFirstChild("YunoGrad"); if g then g:Destroy() end end
        if not silent and cfg.Callback then pcall(cfg.Callback, v) end
    end
    btn.MouseButton1Click:Connect(function() setState(not state) end)
    return { Set = setState, Get = function() return state end }
end

function UI.Button(parent, cfg)
    cfg = cfg or {}
    local btn = Make("TextButton", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Section, Text = "", AutoButtonColor = false, Parent = parent })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
    local stroke = Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = btn })
    Make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = cfg.Name or "Button", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, Parent = btn })
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
        local nv = math.floor(minV + (maxV - minV) * p)
        val = nv; fill.Size = UDim2.new(p, 0, 1, 0); valLbl.Text = tostring(nv); Flags[flag] = nv
        if not silent and cfg.Callback then pcall(cfg.Callback, nv) end
    end
    trig.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; update(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i.Position.X) end end)
    return { Get = function() return val end }
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
        Text = tostring(val), PlaceholderText = cfg.Placeholder or "Enter...", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
    input.FocusLost:Connect(function()
        val = input.Text; Flags[flag] = val
        if cfg.Callback then pcall(cfg.Callback, val) end
    end)
    return { Get = function() return input.Text end }
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
    local picker = Make("TextButton", { Size = UDim2.new(0.45, -20, 0, 28), Position = UDim2.new(0.5, 10, 0.5, -14), BackgroundColor3 = Theme.Sidebar, Text = tostring(val), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, Parent = card })
    Make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = picker })
    local list = Make("ScrollingFrame", { Size = UDim2.new(0.45, -20, 0, 0), Position = UDim2.new(0.5, 10, 1, 2), BackgroundColor3 = Theme.Section, Visible = false, ZIndex = 20, ScrollBarThickness = 2, Parent = card })
    Make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = list })
    Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = list })
    local open = false
    local function refresh()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for i, opt in ipairs(options) do
            local b = Make("TextButton", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, (i-1)*24), BackgroundTransparency = 1, Text = tostring(opt), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.SubText, ZIndex = 21, Parent = list })
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
    return { Get = function() return val end }
end

function UI.Section(parent, title)
    return Make("TextLabel", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = title or "Section", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
end

-- ══════════════════ WINDOW + TABS ══════════════════
screenGui = Make("ScreenGui", { Name = "YunoFarm_UI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Global })
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = LP:WaitForChild("PlayerGui") end

notifyHolder = Make("Frame", { Size = UDim2.new(0, 320, 1, -40), Position = UDim2.new(1, -330, 0, 20), BackgroundTransparency = 1, Parent = screenGui })
Make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), Parent = notifyHolder })

mainFrame = Make("CanvasGroup", { Size = UDim2.new(0, 660, 0, 440), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.05, BorderSizePixel = 0, Parent = screenGui })
Make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = mainFrame })
Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Transparency = 0.3, Parent = mainFrame })

mainScale = Instance.new("UIScale", mainFrame)
mainScale.Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1))

local titleBar = Make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Sidebar, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = mainFrame })
Make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = titleBar })
Make("ImageLabel", { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 12, 0.5, -13), BackgroundTransparency = 1, Image = "rbxassetid://7733960981", ImageColor3 = Theme.Accent, Parent = titleBar })
Make("TextLabel", { Size = UDim2.new(0, 40, 0, 18), Position = UDim2.new(0, 44, 0, 8), BackgroundTransparency = 1, Text = "Yuno", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })
Make("TextLabel", { Size = UDim2.new(0, 40, 0, 18), Position = UDim2.new(0, 84, 0, 8), BackgroundTransparency = 1, Text = "Farm", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })
Make("TextLabel", { Size = UDim2.new(0, 40, 0, 14), Position = UDim2.new(0, 128, 0, 10), BackgroundTransparency = 1, Text = "v3.0", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })

local closeBtn = Make("TextButton", { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -36, 0, 9), BackgroundColor3 = Color3.fromRGB(255, 90, 90), Text = "", AutoButtonColor = false, Parent = titleBar })
Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = closeBtn })
Make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "✕", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1,1,1), Parent = closeBtn })

local sidebar = Make("Frame", { Size = UDim2.new(0, 60, 1, -44), Position = UDim2.new(0, 0, 0, 44), BackgroundColor3 = Theme.Sidebar, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = mainFrame })
Make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = sidebar })
Make("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = sidebar })
Make("UIPadding", { PaddingTop = UDim.new(0, 20), Parent = sidebar })

local content = Make("Frame", { Size = UDim2.new(1, -80, 1, -60), Position = UDim2.new(0, 70, 0, 50), BackgroundTransparency = 1, ClipsDescendants = true, Parent = mainFrame })

local tabs = {}
local function AddTab(icon, name, builder)
    local btn = Make("TextButton", { Size = UDim2.new(0, 40, 0, 40), BackgroundColor3 = Theme.Section, Text = "", AutoButtonColor = false, Parent = sidebar })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
    Make("ImageLabel", { Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(0.5, -11, 0.5, -11), BackgroundTransparency = 1, Image = "rbxassetid://" .. icon, ImageColor3 = Theme.SubText, Parent = btn })
    local page = Make("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.SubText, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false, Parent = content })
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
    end)
    if builder then builder(page) end
    return page
end

-- Drag
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = i.Position; startPos = mainFrame.Position
    end
end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local delta = i.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Float Y
floatBtn = Make("TextButton", { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0.5, -30, 0, 80), BackgroundColor3 = Theme.Accent, Text = "", AutoButtonColor = false, Visible = false, Parent = screenGui })
Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = floatBtn })
Make("UIStroke", { Thickness = 2, Color = Theme.Accent, Parent = floatBtn })
Make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "Y", Font = Enum.Font.GothamBlack, TextSize = 32, TextColor3 = Color3.new(1,1,1), Parent = floatBtn })
ApplyGradientTo(floatBtn, Theme.Accent)

local fDrag, fStart, fPos
floatBtn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then fDrag = true; fStart = i.Position; fPos = floatBtn.Position end end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        if fDrag and fStart then
            local moved = math.abs((floatBtn.Position - fPos).X.Offset) + math.abs((floatBtn.Position - fPos).Y.Offset)
            if moved < 5 then
                floatBtn.Visible = false; mainFrame.Visible = true
                mainScale.Scale = mainScale.Scale * 0.85
                Tween(mainScale, 0.3, { Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1)) }, Enum.EasingStyle.Back)
            end
        end
        fDrag = false
    end
end)
UIS.InputChanged:Connect(function(i) if fDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
    local d = i.Position - fStart
    floatBtn.Position = UDim2.new(fPos.X.Scale, fPos.X.Offset + d.X, fPos.Y.Scale, fPos.Y.Offset + d.Y)
end end)

closeBtn.MouseButton1Click:Connect(function()
    Tween(mainScale, 0.25, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
        mainFrame.Visible = false; floatBtn.Visible = true
    end)
end)

-- Intro
local function PlayIntro(cb)
    local g = Make("ScreenGui", { Name = "YunoFarm_Intro", IgnoreGuiInset = true, DisplayOrder = 9999, ResetOnSpawn = false })
    pcall(function() g.Parent = CoreGui end)
    if not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end
    local bg = Make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(8, 10, 16), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = g })
    local box = Make("Frame", { Size = UDim2.new(0, 420, 0, 220), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = bg })
    local yuno = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 90), Position = UDim2.new(0, 0, 0.15, 0), BackgroundTransparency = 1, Text = "YUNO", Font = Enum.Font.GothamBlack, TextSize = 72, TextColor3 = Color3.fromRGB(255,255,255), TextTransparency = 1, Parent = box })
    local line = Make("Frame", { Size = UDim2.new(0, 0, 0, 2), Position = UDim2.new(0.5, 0, 0.55, 0), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Parent = box })
    Instance.new("UIGradient", line).Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(110,170,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(180,130,255)) })
    local farm = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.6, 0), BackgroundTransparency = 1, Text = "F A R M", Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = Color3.fromRGB(140,180,255), TextTransparency = 1, Parent = box })
    local sub = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.85, 0), BackgroundTransparency = 1, Text = "v3.0 • Initializing...", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(120,130,160), TextTransparency = 1, Parent = box })
    Tween(bg, 0.4, { BackgroundTransparency = 0 }); task.wait(0.4)
    Tween(yuno, 0.5, { TextTransparency = 0 }, Enum.EasingStyle.Back); task.wait(0.3)
    Tween(farm, 0.4, { TextTransparency = 0 }); Tween(line, 0.8, { Size = UDim2.new(0, 220, 0, 2) }); task.wait(0.5)
    Tween(sub, 0.4, { TextTransparency = 0 }); task.wait(1.6)
    Tween(yuno, 0.3, { TextTransparency = 1 }); Tween(farm, 0.3, { TextTransparency = 1 }); Tween(sub, 0.3, { TextTransparency = 1 }); Tween(line, 0.3, { Size = UDim2.new(0, 0, 0, 2) }); task.wait(0.35)
    Tween(bg, 0.35, { BackgroundTransparency = 1 }); task.wait(0.4)
    g:Destroy(); if cb then cb() end
end

-- ═══════════════════════════════════════════════════
--   AUTOFARM - CORE FIX
-- ═══════════════════════════════════════════════════
local FarmEnabled = false
local PetFarmEnabled = false
local BabyFarmEnabled = false
local AutoEquipWatchdog = false
local lastStatus = ""

local function SetStatus(s)
    if s ~= lastStatus then
        lastStatus = s
        local lbl = Flags.__statusLbl
        if lbl and lbl.Parent then lbl.Text = "Status: " .. s end
    end
end

-- ══════════════════ TP (FIXED) ══════════════════
local function TP(location, door)
    if Cac.CurrentLocation == location then return true end

    if Cac.CurrentLocation == "housing" then
        pcall(function() API.UnsubscribeHouse:InvokeServer() end)
    end

    -- Essayer SetLocation (pour MainMap + intérieurs)
    if location == "MainMap" then
        pcall(function() API.SetLocation:FireServer("MainMap", nil, "MainMap") end)
    else
        pcall(function() API.SetLocation:FireServer(location) end)
    end

    -- Retry après 10s si toujours pas arrivé
    local start = tick()
    local retried = false

    while Cac.CurrentLocation ~= location and tick() - start < 30 do
        task.wait(0.5)
        if tick() - start > 10 and not retried then
            retried = true
            if location == "MainMap" then
                pcall(function() API.SetLocation:FireServer("MainMap", nil, "MainMap") end)
            else
                pcall(function() API.SetLocation:FireServer(location) end)
            end
            pcall(function() M.InteriorsM.enter_smooth(location, door or "MainDoor", {}) end)
        end
    end

    -- Attendre spawn
    local char = LP.Character
    if char and char.PrimaryPart then
        task.wait(1)
    end

    return Cac.CurrentLocation == location
end

-- ══════════════════ GET TARGETS (FIXED) ══════════════════
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

-- ══════════════════ WAIT FOR NEED (NEW) ══════════════════
local function WaitForNeedDone(needKind, timeout)
    local start = os.time()
    while os.time() - start < timeout do
        task.wait(1)
        if not FarmEnabled then return false end

        local t = GetFarmTargets()
        local stillNeeded = t.Baby[needKind] and true or false
        if not stillNeeded then
            for _, p in ipairs(t.Pets) do
                if p.needs[needKind] then stillNeeded = true; break end
            end
        end
        if not stillNeeded then return true end
    end
    return false
end

-- ══════════════════ HELPERS ══════════════════
local function GetFoodUID(kind)
    local inv = M.ClientData.get("inventory", "Raw")
    if not inv or not inv.food then return nil end
    local list = {}
    for uid, v in pairs(inv.food) do
        if (v.id == kind or v.kind == kind) then
            table.insert(list, uid)
        end
    end
    table.sort(list)
    return list[1]
end

local function BuyFood(kind, count)
    local money = M.ClientData.get("money") or 0
    if money < 3 * count then return false end
    pcall(function() API.BuyItem:InvokeServer("food", kind, { buy_count = count }) end)
    task.wait(0.7)
    return true
end

local function FeedPetWithFood(petUid, foodUid)
    pcall(function()
        local obj = API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_2", {
            pet_unique = petUid, unique_id = foodUid,
        })
        local model = obj and (obj:FindFirstChild("Model") or obj)
        if not model then
            local po = Workspace:FindFirstChild("PetObjects")
            if po then
                for _, c in ipairs(po:GetChildren()) do
                    local iu = c:FindFirstChild("ItemUniqueId")
                    if iu and iu.Value == foodUid then model = c:FindFirstChild("Model") or c; break end
                end
            end
        end
        if model then API.ConsumeFoodObject:FireServer(model, petUid) end
    end)
end

local function FindFurnitureIDs(kindId)
    local results = {}
    local hi = Workspace:FindFirstChild("HouseInteriors")
    local furni = hi and hi:FindFirstChild("furniture")
    if not furni then return results end
    for _, child in ipairs(furni:GetChildren()) do
        local fid = child.Name:match("f%-%d+")
        if fid and child:FindFirstChild(kindId, true) then
            table.insert(results, fid)
        end
    end
    return results
end

local function GetPetChar(uid)
    for _, w in pairs(M.ClientData.get("pet_char_wrappers") or {}) do
        if w.pet_unique == uid then return w.char end
    end
    return nil
end

-- ══════════════════ TASK: FEED (FIXED) ══════════════════
local function DoFeedTask(kind) -- "hungry" ou "thirsty"
    local targets = GetFarmTargets()
    local foodKind = kind == "hungry" and "apple" or "water"
    local babyNeeds = targets.Baby[kind]
    local petsNeeding = {}
    for _, p in ipairs(targets.Pets) do
        if p.needs[kind] then table.insert(petsNeeding, p) end
    end

    if not babyNeeds and #petsNeeding == 0 then return true end

    -- 1) BÉBÉ : ServerUseTool avec spam de 3 (hungry) ou 8 (thirsty)
    if babyNeeds then
        local foodUid = GetFoodUID(foodKind)
        if not foodUid then
            SetStatus(kind .. ": Buying food")
            BuyFood(foodKind, 5)
            foodUid = GetFoodUID(foodKind)
        end
        if foodUid then
            local count = kind == "thirsty" and 8 or 3
            for i = 1, count do
                pcall(function() API.ServerUseTool:InvokeServer(foodUid, "END") end)
                task.wait(0.08)
            end
        end
    end

    -- 2) PETS : CreatePetObject + ConsumeFoodObject, une apple par pet
    for _, pet in ipairs(petsNeeding) do
        local foodUid = GetFoodUID(foodKind)
        if not foodUid then
            BuyFood(foodKind, 1)
            foodUid = GetFoodUID(foodKind)
        end
        if foodUid then
            FeedPetWithFood(pet.uid, foodUid)
            task.wait(0.4)
        end
    end

    return WaitForNeedDone(kind, 15)
end

-- ══════════════════ TASK: PLAY ══════════════════
local function DoPlayTask()
    local targets = GetFarmTargets()
    local petsNeeding = {}
    for _, p in ipairs(targets.Pets) do
        if p.needs.play then table.insert(petsNeeding, p) end
    end

    if targets.Baby.play then
        local inv = M.ClientData.get("inventory", "Raw")
        local toyUid
        if inv and inv.toys then
            for uid, v in pairs(inv.toys) do
                local k = tostring(v.kind or v.id)
                if k == "squeaky_bone_default" or k:find("chew_toy") then toyUid = uid; break end
            end
        end
        if toyUid then
            pcall(function() API.ServerUseTool:InvokeServer(toyUid, "END") end)
            task.wait(0.5)
        end
    end

    if #petsNeeding == 0 and not targets.Baby.play then return true end

    -- Toy pour les pets
    local inv = M.ClientData.get("inventory", "Raw")
    local toyUid
    if inv and inv.toys then
        for uid, v in pairs(inv.toys) do
            local k = tostring(v.kind or v.id)
            if k == "squeaky_bone_default" or k:find("chew_toy") then toyUid = uid; break end
        end
    end
    if not toyUid then return false end

    for _, pet in ipairs(petsNeeding) do
        pcall(function()
            local obj = API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_1", {
                reaction_name = "ThrowToyReaction",
                unique_id = toyUid,
                pet_unique = pet.uid,
            })
            local model = obj and (obj:FindFirstChild("Model") or obj)
            if model and pet.char then
                API.GrabPetObject:FireServer(pet.char, model)
                task.wait(0.3)
                API.DropPetObject:FireServer(pet.char)
            end
        end)
        task.wait(0.6)
    end

    return WaitForNeedDone("play", 15)
end

-- ══════════════════ TASK: SLEEP ══════════════════
local function DoSleepTask()
    local targets = GetFarmTargets()
    local anySleepy = targets.Baby.sleepy
    local petsNeeding = {}
    for _, p in ipairs(targets.Pets) do
        if p.needs.sleepy then table.insert(petsNeeding, p) end
    end
    if not anySleepy and #petsNeeding == 0 then return true end

    if not TP("MainMap") then return false end
    task.wait(1)

    local bedIds = FindFurnitureIDs("sleepingbag")
    if #bedIds == 0 then bedIds = FindFurnitureIDs("rectangular_pet_bed") end
    if #bedIds == 0 then
        SetStatus("sleep: no bed found")
        return false
    end

    -- Baby d'abord
    if anySleepy and LP.Character then
        pcall(function()
            API.ActivateInterior:InvokeServer(bedIds[1], "Seat2", {}, LP.Character)
        end)
        task.wait(2)
    end

    -- Pets
    for i, pet in ipairs(petsNeeding) do
        local char = pet.char or GetPetChar(pet.uid)
        if char then
            local bedId = bedIds[(i % #bedIds) + 1]
            pcall(function()
                API.ActivateInterior:InvokeServer(bedId, "UseBlock", { cframe = char:GetPivot() }, char)
            end)
            task.wait(1.5)
        end
    end

    return WaitForNeedDone("sleepy", 45)
end

-- ══════════════════ TASK: DIRTY ══════════════════
local function DoDirtyTask()
    local targets = GetFarmTargets()
    local anyDirty = targets.Baby.dirty
    local petsNeeding = {}
    for _, p in ipairs(targets.Pets) do
        if p.needs.dirty then table.insert(petsNeeding, p) end
    end
    if not anyDirty and #petsNeeding == 0 then return true end

    if not TP("MainMap") then return false end
    task.wait(1)

    local showerIds = FindFurnitureIDs("camping_shower")
    if #showerIds == 0 then
        SetStatus("dirty: no shower")
        return false
    end

    if anyDirty and LP.Character then
        pcall(function()
            API.ActivateInterior:InvokeServer(showerIds[1], "UseBlock", { cframe = LP.Character:GetPivot() }, LP.Character)
        end)
        task.wait(2)
    end

    for i, pet in ipairs(petsNeeding) do
        local char = pet.char or GetPetChar(pet.uid)
        if char then
            local showerId = showerIds[(i % #showerIds) + 1]
            pcall(function()
                API.ActivateInterior:InvokeServer(showerId, "UseBlock", { cframe = char:GetPivot() }, char)
            end)
            task.wait(1.5)
        end
    end

    return WaitForNeedDone("dirty", 45)
end

-- ══════════════════ TASK: TOILET ══════════════════
local function DoToiletTask()
    local staticMap = Workspace:FindFirstChild("StaticMap")
    if not staticMap then return false end
    local interact = staticMap:FindFirstChild("Interactables")
    if not interact then return false end

    local hydrant
    for _, child in ipairs(interact:GetDescendants()) do
        if child.Name:find("AilmentsRefresh2024FireHydrant") then hydrant = child; break end
    end
    if not hydrant then return false end

    local char = LP.Character
    if not char or not char.PrimaryPart then return false end

    local center = hydrant:FindFirstChild("Center") or hydrant
    pcall(function()
        char:PivotTo(CFrame.new(center.Position + Vector3.new(0, 3, 0)))
    end)
    task.wait(1)

    local fid
    local p = hydrant
    while p do
        local m = p.Name:match("f%-%d+")
        if m then fid = m; break end
        p = p.Parent
    end

    if fid then
        pcall(function()
            API.ActivateInterior:InvokeServer(fid, "UseBlock", { cframe = char:GetPivot() }, char)
        end)
    end

    return WaitForNeedDone("toilet", 25)
end

-- ══════════════════ TASK: SICK (HOSPITAL) ══════════════════
local function DoSickTask()
    if not TP("Hospital") then return false end
    task.wait(2)
    pcall(function()
        API.ActivateInterior:InvokeServer("f-14", "UseBlock", "Yes", LP.Character)
    end)
    return WaitForNeedDone("sick", 30)
end

-- ══════════════════ TASK: MYSTERY ══════════════════
local function DoMysteryTask()
    local targets = GetFarmTargets()
    local petsNeeding = {}
    for _, p in ipairs(targets.Pets) do
        if p.needs.mystery then table.insert(petsNeeding, p) end
    end
    if #petsNeeding == 0 then return true end

    if Cac.LastMysteryAttempt and os.time() - Cac.LastMysteryAttempt < 5 then
        return false
    end
    Cac.LastMysteryAttempt = os.time()

    for _, pet in ipairs(petsNeeding) do
        pcall(function()
            API.ChooseMystery:FireServer(pet.uid, "mystery", 1, "bored")
        end)
        task.wait(0.5)
    end
    return WaitForNeedDone("mystery", 12)
end

-- ══════════════════ TASK: PET_ME ══════════════════
local function DoPetMeTask()
    local targets = GetFarmTargets()
    for _, pet in ipairs(targets.Pets) do
        if pet.needs.pet_me then
            pcall(function() API.ProgressPetMe:FireServer(pet.uid) end)
            task.wait(1.5)
        end
    end
    return WaitForNeedDone("pet_me", 15)
end

-- ══════════════════ TASK: QUEST LOCATION (V952) ══════════════════
local function DoQuestTask(needKind, location, door)
    if not TP(location, door) then
        SetStatus(needKind .. ": TP failed")
        return false
    end
    task.wait(2)

    -- Aller au point d'intérêt si possible
    if location == "MainMap" then
        local staticMap = Workspace:FindFirstChild("StaticMap")
        if staticMap then
            if needKind == "camping" then
                local cs = staticMap:FindFirstChild("Campsite")
                local origin = cs and cs:FindFirstChild("CampsiteOrigin")
                if origin and LP.Character then pcall(function() LP.Character:PivotTo(origin.CFrame * CFrame.new(0, 3, 0)) end) end
            elseif needKind == "bored" then
                local park = staticMap:FindFirstChild("Park")
                local t = park and park:FindFirstChild("BoredAilmentTarget")
                if t and LP.Character then pcall(function() LP.Character:PivotTo(t.CFrame * CFrame.new(0, 3, 0)) end) end
            elseif needKind == "beach_party" then
                local beach = staticMap:FindFirstChild("Beach")
                local t = beach and beach:FindFirstChild("BeachPartyNavTarget")
                if t and LP.Character then pcall(function() LP.Character:PivotTo(t.CFrame) end) end
            end
        end
    end

    return WaitForNeedDone(needKind, 90)
end

-- ══════════════════ TASK: WALK ══════════════════
local function DoWalkTask()
    local targets = GetFarmTargets()
    local petsNeeding = {}
    for _, p in ipairs(targets.Pets) do
        if p.needs.walk then table.insert(petsNeeding, p) end
    end
    if not targets.Baby.walk and #petsNeeding == 0 then return true end

    if not TP("MainMap") then return false end
    task.wait(1)

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end

    local basePos = hrp.Position
    local start = os.time()
    local angle = 0

    while os.time() - start < 60 do
        task.wait(0.15)
        if not FarmEnabled then return false end
        if not GetFarmTargets().Baby.walk and #petsNeeding == 0 then break end

        angle = angle + 0.12
        local offset = Vector3.new(math.cos(angle) * 15, 0, math.sin(angle) * 15)
        hum:MoveTo(basePos + offset)
    end

    return WaitForNeedDone("walk", 10)
end

-- ══════════════════ TASK: RIDE (STROLLER) ══════════════════
local function DoRideTask()
    local targets = GetFarmTargets()
    local petsNeeding = {}
    for _, p in ipairs(targets.Pets) do
        if p.needs.ride then table.insert(petsNeeding, p) end
    end
    if not targets.Baby.ride and #petsNeeding == 0 then return true end

    if not TP("MainMap") then return false end
    task.wait(1)

    -- Trouver/trouver stroller
    if not Cac.StrollerUID then
        local inv = M.ClientData.get("inventory", "Raw")
        if inv and inv.strollers then
            for uid, v in pairs(inv.strollers) do
                if (v.kind or v.id) == "stroller-default" then Cac.StrollerUID = uid; break end
            end
        end
    end

    if Cac.StrollerUID and os.time() - Cac.LastStrollerEquip > 3 then
        Cac.LastStrollerEquip = os.time()
        pcall(function() API.Equip:InvokeServer(Cac.StrollerUID) end)
        task.wait(1)
    end

    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    local start = os.time()
    local angle = 0
    while os.time() - start < 45 do
        task.wait(0.15)
        if not FarmEnabled then break end
        if not GetFarmTargets().Baby.ride and #petsNeeding == 0 then break end

        if hum and hrp then
            angle = angle + 0.1
            local offset = Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12)
            hum:MoveTo(hrp.Position + offset)
        end
    end

    pcall(function() API.Unequip:InvokeServer(Cac.StrollerUID) end)
    return WaitForNeedDone("ride", 10)
end

-- ══════════════════ MAIN LOOP (FIXED) ══════════════════
task.spawn(function()
    while task.wait(2) do
        if not FarmEnabled then
            SetStatus("Farm OFF")
            continue
        end
        if not PetFarmEnabled and not BabyFarmEnabled then
            SetStatus("No farm modes")
            continue
        end

        local ok, err = pcall(function()
            local t = GetFarmTargets()
            local b = t.Baby
            local pets = t.Pets

            local function hasNeed(k)
                if b[k] then return true end
                for _, p in ipairs(pets) do
                    if p.needs[k] then return true end
                end
                return false
            end

            -- Priorités dans l'ordre du fichier original
            if hasNeed("mystery") then SetStatus("Mystery"); DoMysteryTask(); return end
            if hasNeed("pet_me") then SetStatus("Pet me"); DoPetMeTask(); return end
            if hasNeed("camping") then SetStatus("Camping"); DoQuestTask("camping", "MainMap"); return end
            if hasNeed("bored") then SetStatus("Bored"); DoQuestTask("bored", "MainMap"); return end
            if hasNeed("beach_party") then SetStatus("Beach"); DoQuestTask("beach_party", "MainMap"); return end
            if hasNeed("salon") then SetStatus("Salon"); DoQuestTask("salon", "Salon"); return end
            if hasNeed("school") then SetStatus("School"); DoQuestTask("school", "School"); return end
            if hasNeed("pizza_party") then SetStatus("Pizza"); DoQuestTask("pizza_party", "PizzaShop"); return end
            if hasNeed("cat_cafe") then SetStatus("Cat Cafe"); DoQuestTask("cat_cafe", "CatCafe"); return end
            if hasNeed("sick") then SetStatus("Hospital"); DoSickTask(); return end
            if hasNeed("play") then SetStatus("Play"); DoPlayTask(); return end
            if hasNeed("hungry") then SetStatus("Feeding"); DoFeedTask("hungry"); return end
            if hasNeed("thirsty") then SetStatus("Water"); DoFeedTask("thirsty"); return end
            if hasNeed("walk") then SetStatus("Walk"); DoWalkTask(); return end
            if hasNeed("ride") then SetStatus("Ride"); DoRideTask(); return end
            if hasNeed("dirty") then SetStatus("Shower"); DoDirtyTask(); return end
            if hasNeed("sleepy") then SetStatus("Sleep"); DoSleepTask(); return end
            if hasNeed("toilet") then SetStatus("Toilet"); DoToiletTask(); return end

            -- Weather events
            for _, w in ipairs({"leaf_pile", "rain_puddle", "snow", "diving_board", "party_zone"}) do
                if hasNeed(w) then
                    SetStatus(w)
                    DoQuestTask(w, "MainMap")
                    return
                end
            end

            SetStatus("Idle")
        end)
        if not ok then SetStatus("Error: " .. tostring(err)) end
    end
end)

-- ══════════════════ FAST MEGA ══════════════════
local FastMegaEnabled = false
local FastMegaMode = "Neon"
local FastMegaTargets = {}

task.spawn(function()
    while task.wait(3) do
        if not FastMegaEnabled then continue end
        pcall(function()
            local inv = M.ClientData.get("inventory", "Raw")
            if not inv or not inv.pets then return end
            local groups = {}
            for uid, pet in pairs(inv.pets) do
                local kind = pet.kind or pet.id
                if FastMegaTargets[kind] then
                    local props = pet.properties or {}
                    local age = props.age or 1
                    local isNeon = props.neon or props.is_neon
                    local isMega = props.mega_neon or props.is_mega
                    if age == 6 and not isNeon and not isMega then
                        groups[kind] = groups[kind] or { regular = {}, neon = {} }
                        table.insert(groups[kind].regular, uid)
                    elseif isNeon and not isMega then
                        groups[kind] = groups[kind] or { regular = {}, neon = {} }
                        table.insert(groups[kind].neon, uid)
                    end
                end
            end
            for kind, g in pairs(groups) do
                if #g.regular >= 4 then
                    SetStatus("Crafting Neon " .. kind)
                    pcall(function() API.DoNeonFusion:InvokeServer({ g.regular[1], g.regular[2], g.regular[3], g.regular[4] }) end)
                    task.wait(4)
                elseif FastMegaMode == "Mega" and #g.neon >= 4 then
                    SetStatus("Crafting Mega " .. kind)
                    pcall(function() API.DoNeonFusion:InvokeServer({ g.neon[1], g.neon[2], g.neon[3], g.neon[4] }) end)
                    task.wait(4)
                end
            end
        end)
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

-- ══════════════════ HALLOWEEN ══════════════════
local HalloweenCryptEnabled = false
local HalloweenGhostEnabled = false
local HalloweenTwigEnabled = false

task.spawn(function()
    while task.wait(2) do
        if HalloweenCryptEnabled then
            pcall(function()
                local cryptMgr = M.ClientData.get("halloween_2026_crypt_manager")
                if not cryptMgr or not cryptMgr.floors then return end
                local lastFloor = cryptMgr.floors[#cryptMgr.floors]
                if not lastFloor then return end
                if lastFloor.is_final then
                    SetStatus("Crypt: Claim")
                    if HalloweenRemote.ClaimTombSpider then pcall(function() HalloweenRemote.ClaimTombSpider:InvokeServer() end) end
                    task.wait(4)
                    return
                end
                local inv = M.ClientData.get("inventory", "Raw")
                local keyUid
                if inv then
                    for _, cat in pairs(inv) do
                        if type(cat) == "table" then
                            for uid, v in pairs(cat) do
                                if tostring(v.kind or v.id) == "halloween_2026_rusty_key" then keyUid = uid; break end
                            end
                        end
                        if keyUid then break end
                    end
                end
                if not keyUid then SetStatus("Crypt: No key"); return end
                pcall(function() API.Equip:InvokeServer(keyUid) end)
                task.wait(1)
                if HalloweenRemote.UnlockPadlock then
                    pcall(function()
                        HalloweenRemote.UnlockPadlock:InvokeServer({ padlock_index = 1, floor_index = #cryptMgr.floors })
                    end)
                end
                task.wait(2)
            end)
        elseif HalloweenGhostEnabled then
            pcall(function()
                local cycle = M.ClientData.get("ghost_clusters_cycle_timestamp")
                if cycle and cycle.timestamp then
                    local rem = cycle.timestamp - os.time()
                    if rem > 10 or rem < -120 then return end
                end
                if Cac.CurrentLocation ~= "ManorMinigameInterior" then TP("HauntedManor") end
            end)
        elseif HalloweenTwigEnabled then
            pcall(function()
                local nest = M.ClientData.get("halloween_2026_jacobean_pigeon_nest_manager")
                if not nest then return end
                local twigs = nest.twigs_contributed or 0
                if twigs >= 8 then return end
                if Cac.CurrentLocation ~= "HauntedHotel" then TP("HauntedHotel") end
            end)
        end
    end
end)

-- ══════════════════ VISUALS ══════════════════
local VisualVars = { Mega = false, Neon = false, Fly = false, Ride = false, Eggs = false }
local SavedPetVisuals = {}

local function ApplyVisualsToCurrent()
    for _, w in pairs(M.ClientData.get("pet_char_wrappers") or {}) do
        if w.player == LP then
            SavedPetVisuals[w.pet_unique] = {
                Mega = VisualVars.Mega, Neon = VisualVars.Neon, Fly = VisualVars.Fly, Ride = VisualVars.Ride,
            }
            break
        end
    end
    pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end)
end

local function ApplyVisualsToAll()
    local inv = M.ClientData.get("inventory", "Raw")
    if inv and inv.pets then
        for uid in pairs(inv.pets) do
            SavedPetVisuals[uid] = {
                Mega = VisualVars.Mega, Neon = VisualVars.Neon, Fly = VisualVars.Fly, Ride = VisualVars.Ride,
            }
        end
    end
    pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end)
end

local function ResetVisuals()
    SavedPetVisuals = {}
    VisualVars.Mega = false; VisualVars.Neon = false; VisualVars.Fly = false; VisualVars.Ride = false
    pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end)
end

local realGet = M.ClientData.get
M.ClientData.get = function(self, key, sub, ...)
    local res = realGet(self, key, sub, ...)
    if key == "inventory" and sub ~= "Raw" and type(res) == "table" and res.pets then
        local newPets = {}
        for uid, pet in pairs(res.pets) do
            local s = SavedPetVisuals[uid]
            if s then
                local clone = {}
                for k, v in pairs(pet) do clone[k] = v end
                local props = {}
                for k, v in pairs(pet.properties or {}) do props[k] = v end
                props.neon = s.Neon; props.mega_neon = s.Mega
                props.flyable = s.Fly; props.is_flyable = s.Fly
                props.rideable = s.Ride; props.is_rideable = s.Ride
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

-- ══════════════════ VALUES ══════════════════
local ValuesCache = {}
local ValuesLoaded = false

local function LoadValues()
    if isfile(VAL_FILE) then
        pcall(function()
            local data = HttpService:JSONDecode(readfile(VAL_FILE))
            if type(data) == "table" then ValuesCache = data; ValuesLoaded = true end
        end)
    end
    if ValuesLoaded then return end
    local urls = {
        "https://raw.githubusercontent.com/adoptme-values/values/main/values.json",
        "https://thepatchgg.github.io/data/values.json",
    }
    for _, url in ipairs(urls) do
        pcall(function()
            local raw = game:HttpGet(url, true)
            if raw and #raw > 100 and raw:sub(1, 1) == "{" then
                local data = HttpService:JSONDecode(raw)
                if type(data) == "table" then
                    ValuesCache = data; ValuesLoaded = true
                    writefile(VAL_FILE, raw); return
                end
            end
        end)
        if ValuesLoaded then break end
    end
    if not ValuesLoaded then
        ValuesCache = {
            shadow_dragon = { regular = 0.5, neon = 2.5, mega = 12 },
            bat_dragon = { regular = 0.4, neon = 2.0, mega = 10 },
            giraffe = { regular = 0.3, neon = 1.5, mega = 7 },
            frost_dragon = { regular = 0.25, neon = 1.2, mega = 6 },
            parrot = { regular = 0.15, neon = 0.8, mega = 4 },
            owl = { regular = 0.12, neon = 0.6, mega = 3 },
            crow = { regular = 0.1, neon = 0.5, mega = 2.5 },
            unicorn = { regular = 0.05, neon = 0.25, mega = 1.2 },
        }
        ValuesLoaded = true
    end
end
task.spawn(LoadValues)

-- ══════════════════ BUILD TABS ══════════════════
AddTab("7733960981", "Home", function(page)
    local header = Make("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.3, Parent = page })
    Make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = header })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 22), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1,
        Text = "Yuno Farm v3.0", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 34), BackgroundTransparency = 1,
        Text = (IS_MOBILE and "Mobile" or "PC") .. " • " .. ThemeName, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })

    local statusCard = Make("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.3, Parent = page })
    Make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = statusCard })
    local lbl = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1,
        Text = "Status: Idle", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = statusCard })
    Flags.__statusLbl = lbl
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 32), BackgroundTransparency = 1,
        Text = "Location: tracking...", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = statusCard })

    task.spawn(function()
        while task.wait(2) do
            if statusCard.Parent then
                lbl.Text = "Status: " .. lastStatus .. " | Loc: " .. tostring(Cac.CurrentLocation)
            else break end
        end
    end)
end)

AddTab("6908632622", "AutoFarm", function(page)
    UI.Section(page, "Master")
    UI.Toggle(page, { Name = "Farm Master", Flag = "YF_FarmMaster", Callback = function(v) FarmEnabled = v; Notify("Yuno", v and "Farm enabled" or "Farm disabled") end })
    UI.Toggle(page, { Name = "Pet Farm", Flag = "YF_PetFarm", Callback = function(v) PetFarmEnabled = v end })
    UI.Toggle(page, { Name = "Baby Farm", Flag = "YF_BabyFarm", Callback = function(v) BabyFarmEnabled = v end })

    UI.Section(page, "Advanced")
    UI.Toggle(page, { Name = "Auto Equip Watchdog", Flag = "YF_Watchdog", Callback = function(v) AutoEquipWatchdog = v end })

    UI.Section(page, "Age-Pot Farm")
    UI.Toggle(page, { Name = "Age-Pot Farm", Flag = "YF_AgePot", Callback = function(v)
        if v then
            Notify("Age-Pot", "Enabled")
            task.spawn(function()
                while Flags.YF_AgePot do
                    task.wait(3)
                    pcall(function()
                        local inv = M.ClientData.get("inventory", "Raw")
                        if inv and inv.pets then
                            local picked
                            for uid, p in pairs(inv.pets) do
                                local pr = p.properties or {}
                                local db = M.InventoryDB.pets[p.kind or p.id]
                                if db and not db.is_egg and (pr.age or 1) == 6 and not (pr.neon or pr.mega_neon) then
                                    picked = uid; break
                                end
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

AddTab("13549782519", "Pets", function(page)
    UI.Section(page, "Visuals (Client-only)")
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.4, TextWrapped = true, Parent = page,
        Text = "Visual only. Server doesn't see these changes.", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left })
    local last = page:GetChildren()[#page:GetChildren()]
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = last })

    UI.Toggle(page, { Name = "Mega Neon", Flag = "YF_VisMega", Callback = function(v) VisualVars.Mega = v; if v then VisualVars.Neon = false end end })
    UI.Toggle(page, { Name = "Neon", Flag = "YF_VisNeon", Callback = function(v) VisualVars.Neon = v; if v then VisualVars.Mega = false end end })
    UI.Toggle(page, { Name = "Flyable", Flag = "YF_VisFly", Callback = function(v) VisualVars.Fly = v end })
    UI.Toggle(page, { Name = "Rideable", Flag = "YF_VisRide", Callback = function(v) VisualVars.Ride = v end })

    UI.Section(page, "Apply")
    UI.Button(page, { Name = "Apply to Current", Callback = function() ApplyVisualsToCurrent(); Notify("Visuals", "Applied") end })
    UI.Button(page, { Name = "Apply to ALL", Callback = function() ApplyVisualsToAll(); Notify("Visuals", "All pets") end })
    UI.Button(page, { Name = "Reset", Callback = function() ResetVisuals(); Notify("Visuals", "Reset") end })
end)

AddTab("128557027005598", "FastMega", function(page)
    UI.Section(page, "Craft")
    UI.Toggle(page, { Name = "Enable Fast Mega", Flag = "YF_FastMega", Callback = function(v) FastMegaEnabled = v end })
    UI.Toggle(page, { Name = "Mode Mega (else Neon)", Flag = "YF_FastMegaMode", Callback = function(v) FastMegaMode = v and "Mega" or "Neon" end })

    UI.Section(page, "Targets")
    local grid = Make("Frame", { Size = UDim2.new(1, 0, 0, 260), BackgroundTransparency = 1, Parent = page })
    Make("UIGridLayout", { CellSize = UDim2.new(0, 75, 0, 85), CellPadding = UDim2.new(0, 8, 0, 8), Parent = grid })
    task.spawn(function()
        task.wait(2)
        local DBPets = M.InventoryDB.pets
        local inv = M.ClientData.get("inventory", "Raw") or {}
        local counts = {}
        for _, p in pairs(inv.pets or {}) do
            local k = p.kind or p.id
            if k and DBPets[k] and not DBPets[k].is_egg then counts[k] = (counts[k] or 0) + 1 end
        end
        for kind, count in pairs(counts) do
            local db = DBPets[kind]
            local img = db.icon or db.image or db.shop_image or "0"
            if tonumber(img) then img = "rbxassetid://" .. img end
            local btn = Make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Section, Text = "", AutoButtonColor = false, Parent = grid })
            Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
            local stroke = Make("UIStroke", { Thickness = 1, Color = FastMegaTargets[kind] and Theme.Accent or Theme.Stroke, Parent = btn })
            Make("ImageLabel", { Size = UDim2.new(0.8, 0, 0.6, 0), Position = UDim2.new(0.1, 0, 0.05, 0), BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Parent = btn })
            Make("TextLabel", { Size = UDim2.new(1, -4, 0, 16), Position = UDim2.new(0, 2, 1, -18), BackgroundTransparency = 1, Text = (db.name or kind) .. " x" .. count, Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = Theme.Text, TextWrapped = true, Parent = btn })
            btn.MouseButton1Click:Connect(function()
                FastMegaTargets[kind] = not FastMegaTargets[kind]
                stroke.Color = FastMegaTargets[kind] and Theme.Accent or Theme.Stroke
            end)
        end
    end)
end)

AddTab("135780702746673", "Shop", function(page)
    UI.Section(page, "Auto-Buy")
    UI.Toggle(page, { Name = "Enable Auto-Buy", Flag = "YF_AutoBuy", Callback = function(v) AutoBuyEnabled = v end })
    for kind, data in pairs(ShopCatalog) do
        UI.Toggle(page, { Name = data.name .. " (" .. data.price .. " $)", Flag = "YF_Buy_" .. kind, Callback = function(v) BuyTargets[kind] = v end })
    end
end)

AddTab("128544079472562", "Halloween", function(page)
    UI.Section(page, "Halloween 2026")
    UI.Toggle(page, { Name = "Auto Crypt", Flag = "YF_HallCrypt", Callback = function(v) HalloweenCryptEnabled = v end })
    UI.Toggle(page, { Name = "Auto Ghost", Flag = "YF_HallGhost", Callback = function(v) HalloweenGhostEnabled = v end })
    UI.Toggle(page, { Name = "Auto Twigs", Flag = "YF_HallTwig", Callback = function(v) HalloweenTwigEnabled = v end })
end)

AddTab("9695309046", "Trade", function(page)
    UI.Section(page, "Values")
    UI.Input(page, { Name = "Custom URL", Flag = "YF_ValuesURL", Placeholder = "https://...", Callback = function(v)
        if v and v ~= "" then
            task.spawn(function()
                pcall(function()
                    local raw = game:HttpGet(v, true)
                    if raw and #raw > 100 then
                        local data = HttpService:JSONDecode(raw)
                        if type(data) == "table" then
                            ValuesCache = data; ValuesLoaded = true
                            writefile(VAL_FILE, raw)
                            Notify("Values", "Loaded")
                        end
                    end
                end)
            end)
        end
    end })
    UI.Button(page, { Name = "Reload Auto Values", Callback = function()
        if isfile(VAL_FILE) then delfile(VAL_FILE) end
        ValuesLoaded = false
        LoadValues()
        Notify("Values", "Reloaded")
    end })
    UI.Button(page, { Name = "Get Trade License (Quiz)", Callback = function()
        pcall(function()
            local api = RS:WaitForChild("API")
            if api:FindFirstChild("TradeAPI/BeginQuiz") then
                api["TradeAPI/BeginQuiz"]:InvokeServer()
                for i = 1, 3 do api["TradeAPI/AnswerQuizQuestion"]:InvokeServer(true) end
            end
        end)
        Notify("Trade", "License sent")
    end })
end)

AddTab("7734053495", "Settings", function(page)
    UI.Section(page, "Theme")
    UI.Dropdown(page, { Name = "Theme", Flag = "YF_Theme", Options = { "Yuno", "Dark", "Light", "Amethyst", "Galaxy", "Emerald", "BlueDeepWave" }, Default = ThemeName, Callback = function(v)
        ApplyTheme(v)
        Notify("Theme", v)
    end })

    UI.Section(page, "UI")
    UI.Slider(page, { Name = "UI Scale %", Flag = "YF_Scale", Min = 40, Max = 150, Default = math.floor((getgenv().YunoScale or 1) * 100), Callback = function(v)
        getgenv().YunoScale = v / 100
        mainScale.Scale = v / 100
    end })
    UI.Toggle(page, { Name = "Menu Blur", Flag = "YF_Blur", Callback = function(v)
        local blur = Lighting:FindFirstChild("YunoBlur")
        if v and not blur then
            blur = Instance.new("BlurEffect", Lighting)
            blur.Name = "YunoBlur"
        end
        if blur then blur.Enabled = v end
    end })

    UI.Section(page, "Config")
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
    UI.Button(page, { Name = "Destroy", Callback = function()
        if screenGui then screenGui:Destroy() end
        if floatBtn then floatBtn:Destroy() end
    end })
end)

if tabs[1] then tabs[1].btn.MouseButton1Click:Fire() end

pcall(function()
    if isfile(CFG_FILE) then
        local data = HttpService:JSONDecode(readfile(CFG_FILE))
        for k, v in pairs(data) do Flags[k] = v end
    end
end)

mainFrame.Visible = false

PlayIntro(function()
    mainFrame.Visible = true
    mainScale.Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1)) * 0.85
    Tween(mainScale, 0.4, { Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1)) }, Enum.EasingStyle.Back)
    Notify("Yuno Farm", "v3.0 loaded", 4)
end)

print("[Yuno] ✅ v3.0 loaded - autofarm fixed")