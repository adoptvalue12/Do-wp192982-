--[[
    ╔═══════════════════════════════════════════════════════╗
    ║   YUNO FARM v5.1 - CRASH-PROOF + ALL PET TASKS        ║
    ║   Safe loading • Full ailments • Retry • Logs         ║
    ╚═══════════════════════════════════════════════════════╝
]]

print("═══════════════════════════════════════════")
print("[Yuno] 🚀 Script starting...")
print("═══════════════════════════════════════════")

if not game:IsLoaded() then game.Loaded:Wait() end
print("[Yuno] Game loaded")

local ok1, err1 = pcall(function()
    game:GetService("ReplicatedStorage"):WaitForChild("Fsys", 30)
end)
if not ok1 then
    warn("[Yuno] ❌ Fsys not found after 30s — abort")
    return
end

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
local CollectionService = game:GetService("CollectionService")

local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
local IS_MOBILE = UIS.TouchEnabled or vp.X < 900

if not isfolder("YunoFarm") then pcall(makefolder, "YunoFarm") end
local CFG_FILE = "YunoFarm/config.json"

local vu = game:GetService("VirtualUser")
LP.Idled:Connect(function() vu:CaptureController() vu:ClickButton2(Vector2.new()) end)

-- ═══════════════════════════════════════════════
-- SAFE MODULE LOADING
-- ═══════════════════════════════════════════════
print("[Yuno] ⏳ Loading Fsys...")
local Fsys
do
    local attempts = 0
    while attempts < 30 and not Fsys do
        attempts = attempts + 1
        local mod = RS:FindFirstChild("Fsys")
        if mod then
            local ok, result = pcall(function() return require(mod) end)
            if ok and result then Fsys = result; break end
            warn("[Yuno] Fsys attempt "..attempts.." failed: "..tostring(result))
        end
        task.wait(1)
    end
end
if not Fsys then
    warn("[Yuno] ❌ Fsys failed to load after 30s — aborting")
    return
end
print("[Yuno] ✅ Fsys loaded")

local function SafeLoad(name)
    local ok, mod = pcall(function() return Fsys.load(name) end)
    if not ok then
        warn("[Yuno] ⚠ Module failed: "..name.." — "..tostring(mod))
        return nil
    end
    return mod
end

local M = {
    RouterClient     = SafeLoad("RouterClient"),
    ClientData       = SafeLoad("ClientData"),
    InteriorsM       = SafeLoad("InteriorsM"),
    InventoryDB      = SafeLoad("InventoryDB"),
    PetEntityManager = SafeLoad("PetEntityManager"),
    PetEntityHelper  = SafeLoad("PetEntityHelper"),
}

if not M.RouterClient then warn("[Yuno] ❌ CRITICAL: RouterClient missing — abort"); return end
if not M.ClientData then warn("[Yuno] ❌ CRITICAL: ClientData missing — abort"); return end
if not M.InteriorsM then warn("[Yuno] ⚠ InteriorsM missing — TP disabled") end
if not M.InventoryDB then warn("[Yuno] ⚠ InventoryDB missing — FastMega/SWF disabled") end
if not M.PetEntityManager then warn("[Yuno] ⚠ PetEntityManager missing — pet_me still works") end
if not M.PetEntityHelper then warn("[Yuno] ⚠ PetEntityHelper missing — pet_me basic mode") end
print("[Yuno] ✅ Core modules ready")

local function SafeGet(ep)
    local ok, remote = pcall(function() return M.RouterClient.get(ep) end)
    if not ok or not remote then
        warn("[Yuno] ⚠ Remote missing: "..ep)
        return nil
    end
    return remote
end

local API = {
    Equip = SafeGet("ToolAPI/Equip"),
    Unequip = SafeGet("ToolAPI/Unequip"),
    ServerUseTool = SafeGet("ToolAPI/ServerUseTool"),
    DoNeonFusion = SafeGet("PetAPI/DoNeonFusion"),
    ConsumeFoodObject = SafeGet("PetAPI/ConsumeFoodObject"),
    ExitFurniture = SafeGet("PetAPI/ExitFurnitureUseStates"),
    CreatePetObject = SafeGet("PetObjectAPI/CreatePetObject"),
    GrabPetObject = SafeGet("PetObjectAPI/GrabPetObject"),
    DropPetObject = SafeGet("PetObjectAPI/DropPetObject"),
    ProgressPetMe = SafeGet("AilmentsAPI/ProgressPetMeAilment"),
    ChooseMystery = SafeGet("AilmentsAPI/ChooseMysteryAilment"),
    AddPet = SafeGet("IdleProgressionAPI/AddPet"),
    RemovePet = SafeGet("IdleProgressionAPI/RemovePet"),
    ClaimProgression = SafeGet("IdleProgressionAPI/CommitAllProgression"),
    BuyItem = SafeGet("ShopAPI/BuyItem"),
    SetLocation = SafeGet("LocationAPI/SetLocation"),
    UnsubscribeHouse = SafeGet("HousingAPI/UnsubscribeFromHouse"),
    ActivateInterior = SafeGet("HousingAPI/ActivateInteriorFurniture"),
    ActivateFurniture = SafeGet("HousingAPI/ActivateFurniture"),
    ExitSeats = SafeGet("AdoptAPI/ExitSeatStates"),
    EjectBaby = SafeGet("AdoptAPI/EjectBaby"),
    HoldBaby = SafeGet("AdoptAPI/HoldBaby"),
}

if not API.SetLocation then warn("[Yuno] ❌ CRITICAL: SetLocation missing — TP impossible") end
print("[Yuno] ✅ API ready (" .. tostring(table and 22 or "?") .. " remotes)")

-- ══════════════════ GLOBAL STATE ══════════════════
local Cac = {
    CurrentLocation = nil,
    AilmentPlatform = nil,
    BedIds = { MainMap = {}, School = {} },
    ShowerIds = {},
    StrollerUID = nil,
    LastStrollerEquip = 0,
    LastMysteryAttempt = nil,
    PetMeAttempts = {},
    MysteryBlacklist = {},
    MysteryFails = {},
}
getgenv().YunoCac = Cac

local FarmEnabled = false
local PetFarmEnabled = false
local BabyFarmEnabled = false

-- SWF
local SWFEnabled = false
local SwfMode = "Regular"
local SWFTargets = {}
local SwfSplitMode = false

-- Auto Hatch
local AutoHatch = false
local HatchPriority = {}
local HatchLimits = {}
local ActiveHatchUIDs = {}
local HatchedSessionCounts = {}

-- Age-Pot
local AutoAgePot = false

-- Fast Mega
local FastMegaEnabled = false
local FastMegaPipeline = false
local FastMegaPipeMode = "Selected"
local FastMegaMode = "Neon"
local FastMegaTargets = {}
local FastMegaFarmPots = false
local FastMegaTimer = 0

-- Watchdog
local TaskFailTrack = { time = 0 }

local LiveOpsMap = "MainMap"
pcall(function()
    local ok, S = pcall(function()
        return require(RS:WaitForChild("new", 2):WaitForChild("modules", 2)
            :WaitForChild("InteriorHelpers", 2):WaitForChild("LiveOpsMapSwap", 2)
            :WaitForChild("SwappableInteriors", 2))
    end)
    if ok and S and S.get_current_map_type then LiveOpsMap = S.get_current_map_type() or "MainMap" end
end)

task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if M.InteriorsM and M.InteriorsM.get_current_location then
                local loc = M.InteriorsM.get_current_location()
                if loc and loc.id then Cac.CurrentLocation = loc.id; return end
            end
            if M.ClientData then
                local data = M.ClientData.get_data() or {}
                local pd = data[LP.Name] or {}
                if pd.char_wrapper and pd.char_wrapper.location then
                    Cac.CurrentLocation = pd.char_wrapper.location.destination_id
                elseif Cac.CurrentLocation == nil then
                    Cac.CurrentLocation = "MainMap"
                end
            end
        end)
    end
end)

-- ══════════════════ THEMES ══════════════════
local THEMES = {
    Dark = { Background=Color3.fromRGB(15,15,20), Sidebar=Color3.fromRGB(20,20,25), Section=Color3.fromRGB(28,28,33), Text=Color3.fromRGB(255,255,255), SubText=Color3.fromRGB(120,120,130), Accent=Color3.fromRGB(255,255,255), Stroke=Color3.fromRGB(45,45,50), ToggleOff=Color3.fromRGB(55,55,60), Knob=Color3.fromRGB(20,20,25) },
    Yuno = { Background=Color3.fromRGB(12,14,22), Sidebar=Color3.fromRGB(18,21,32), Section=Color3.fromRGB(24,28,42), Text=Color3.fromRGB(240,245,255), SubText=Color3.fromRGB(120,140,170), Accent=Color3.fromRGB(110,170,255), Stroke=Color3.fromRGB(40,48,70), ToggleOff=Color3.fromRGB(45,52,72), Knob=Color3.fromRGB(240,245,255) },
    Galaxy = { Background=Color3.fromRGB(12,10,20), Sidebar=Color3.fromRGB(18,15,30), Section=Color3.fromRGB(25,20,42), Text=Color3.fromRGB(240,240,255), SubText=Color3.fromRGB(150,140,190), Accent=Color3.fromRGB(110,60,255), Stroke=Color3.fromRGB(50,40,80), ToggleOff=Color3.fromRGB(40,30,70), Knob=Color3.fromRGB(20,15,35) },
    Light = { Background=Color3.fromRGB(245,245,250), Sidebar=Color3.fromRGB(255,255,255), Section=Color3.fromRGB(235,235,240), Text=Color3.fromRGB(20,20,25), SubText=Color3.fromRGB(100,100,110), Accent=Color3.fromRGB(0,122,255), Stroke=Color3.fromRGB(220,220,230), ToggleOff=Color3.fromRGB(200,200,210), Knob=Color3.fromRGB(255,255,255) },
    Emerald = { Background=Color3.fromRGB(15,22,18), Sidebar=Color3.fromRGB(20,28,22), Section=Color3.fromRGB(26,36,28), Text=Color3.fromRGB(240,255,240), SubText=Color3.fromRGB(130,160,140), Accent=Color3.fromRGB(46,204,113), Stroke=Color3.fromRGB(45,60,50), ToggleOff=Color3.fromRGB(40,55,45), Knob=Color3.fromRGB(20,28,22) },
}

local ThemeName = getgenv().YunoThemeName or "Yuno"
local Theme = THEMES[ThemeName] or THEMES.Yuno
local ThemeObjects = {}
local Flags = {}

local function ApplyTheme(n)
    if not THEMES[n] then return end
    ThemeName = n; getgenv().YunoThemeName = n; Theme = THEMES[n]
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
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, glow), ColorSequenceKeypoint.new(1, color) })
end

local notifyHolder
local function Notify(title, msg, dur)
    if not notifyHolder then return end
    dur = dur or 3
    local f = Make("Frame", { Size = UDim2.new(0, 300, 0, 70), BackgroundTransparency = 1, Parent = notifyHolder })
    local bg = Make("Frame", { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(1, 40, 0, 0), BackgroundColor3 = Theme.Section, Parent = f })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = bg })
    Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Parent = bg })
    Make("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = bg })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1, Text = title or "Yuno", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = bg })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 30), Position = UDim2.new(0, 15, 0, 32), BackgroundTransparency = 1, Text = msg or "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = bg })
    Tween(bg, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
    task.delay(dur, function()
        local t = Tween(bg, 0.3, { Position = UDim2.new(1, 40, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        t.Completed:Connect(function() f:Destroy() end)
    end)
end

-- ══════════════════ UI ══════════════════
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
    Make("TextLabel", { Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 15, 0, 10), BackgroundTransparency = 1, Text = cfg.Name or "Toggle", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
    if cfg.Description then
        Make("TextLabel", { Size = UDim2.new(1, -80, 0, 14), Position = UDim2.new(0, 15, 0, 30), BackgroundTransparency = 1, Text = cfg.Description, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
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

function UI.Section(parent, title)
    return Make("TextLabel", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = title or "Section", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
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
    Make("TextLabel", { Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 15, 0, 10), BackgroundTransparency = 1, Text = cfg.Name or "Slider", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
    local valLbl = Make("TextLabel", { Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -75, 0, 10), BackgroundTransparency = 1, Text = tostring(val), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
    local track = Make("Frame", { Size = UDim2.new(1, -30, 0, 6), Position = UDim2.new(0, 15, 0, 40), BackgroundColor3 = Theme.Sidebar, Parent = card })
    Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    local fill = Make("Frame", { Size = UDim2.new((val - minV) / (maxV - minV), 0, 1, 0), BackgroundColor3 = Theme.Accent, Parent = track })
    Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
    local trig = Make("TextButton", { Size = UDim2.new(1, 0, 1, 30), Position = UDim2.new(0, 0, 0.5, -15), BackgroundTransparency = 1, Text = "", Parent = track })
    local dragging = false
    local function update(posX)
        local p = math.clamp((posX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local nv = math.floor(minV + (maxV - minV) * p)
        val = nv; fill.Size = UDim2.new(p, 0, 1, 0); valLbl.Text = tostring(nv); Flags[flag] = nv
        if cfg.Callback then pcall(cfg.Callback, nv) end
    end
    trig.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; update(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i.Position.X) end end)
    return { Get = function() return val end }
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
    Make("TextLabel", { Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 15, 0, 0), BackgroundTransparency = 1, Text = cfg.Name or "Dropdown", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
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

print("[Yuno] ⏳ Building UI...")

-- ══════════════════ WINDOW ══════════════════
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
Make("TextLabel", { Size = UDim2.new(0, 40, 0, 14), Position = UDim2.new(0, 128, 0, 10), BackgroundTransparency = 1, Text = "v5.1", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })

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
    if builder then pcall(builder, page) end
    return page
end

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

print("[Yuno] ✅ UI built")

-- ═══════════════════════════════════════════════
-- AUTOFARM CORE
-- ═══════════════════════════════════════════════
local lastStatus = ""
local DebugInfo = { Pets = 0, BabyNeeds = 0, PetNeeds = 0 }

local function SetStatus(s)
    if s ~= lastStatus then
        lastStatus = s
        local lbl = Flags.__statusLbl
        if lbl and lbl.Parent then lbl.Text = "Status: " .. s end
    end
end

local TaskFailures = {}
local function CanTry(k) local f = TaskFailures[k]; return not (f and (tick() - f.time) < 30) end
local function MarkFailed(k) local f = TaskFailures[k] or { count = 0 }; f.count = f.count + 1; f.time = tick(); TaskFailures[k] = f end
local function ClearFailure(k) TaskFailures[k] = nil end

-- ════════ AILMENT ALIASES ════════
local AILMENT_ALIASES = {
    sad = "bored", tired = "sleepy", exhausted = "sleepy",
    itchy = "dirty", smelly = "dirty", stinky = "dirty", dirty_pet = "dirty",
    ill = "sick", sick_green = "sick", sick_blue = "sick",
    food = "hungry", food_bowl = "hungry", hungry_special = "hungry",
    water = "thirsty", water_bowl = "thirsty", thirsty_special = "thirsty",
    toy = "play", play_time = "play", bored_special = "bored",
    sleep = "sleepy", bed = "sleepy",
    shower = "dirty", bath = "dirty",
    mystery_special = "mystery", mystery_box = "mystery",
    pet_me_special = "pet_me",
    cat = "cat_cafe", cafe = "cat_cafe",
    pizza = "pizza_party", school_quest = "school",
    salon_quest = "salon",
}

local LoggedUnknown = {}
local function NormalizeAilment(k)
    if AILMENT_ALIASES[k] then return AILMENT_ALIASES[k] end
    return k
end

local function LogUnknownAilment(k)
    if LoggedUnknown[k] then return end
    LoggedUnknown[k] = true
    warn("[Yuno] ⚠ Unknown ailment: "..tostring(k))
end

local function GetHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function CreatePlatform(name)
    if not Cac.AilmentPlatform or not Cac.AilmentPlatform.Parent then
        local plat = Instance.new("Part")
        plat.Name = "YunoPlatform"
        plat.Anchored = true
        plat.CanCollide = true
        plat.Transparency = 0
        plat.Size = Vector3.new(2048, 4, 2048)
        plat.CFrame = CFrame.new(-100000, 1000, -100000)
        plat.Color = Color3.fromRGB(80, 200, 120)
        plat.Parent = Workspace
        CollectionService:AddTag(plat, "YunoPlat")
        Cac.AilmentPlatform = plat
    end
    local plat = Cac.AilmentPlatform
    plat.Name = name

    local origin, offset = nil, Vector3.new(0, 0, 0)
    if name == "Camping" then
        local cs = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("Campsite")
        origin = cs and cs:FindFirstChild("CampsiteOrigin")
        offset = Vector3.new(0, -1, 0)
    elseif name == "Playground" then
        local park = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("Park")
        origin = park and park:FindFirstChild("BoredAilmentTarget")
        offset = Vector3.new(0, -2.5, 0)
    elseif name == "Beach" then
        local tl = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("TeleportLocations")
        origin = tl and tl:FindFirstChild("exterior_beach")
        offset = Vector3.new(0, -10, 0)
    elseif name == "Toilet" then
        local interact = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("Interactables")
        if interact then
            for _, c in ipairs(interact:GetDescendants()) do
                if c.Name:find("AilmentsRefresh2024FireHydrant") then origin = c:FindFirstChild("Center") or c; break end
            end
        end
        offset = Vector3.new(0, -4, 0)
    end

    local loc = Cac.CurrentLocation
    if loc == "Salon" or loc == "School" or loc == "PizzaShop" or loc == "Hospital" or loc == "CatCafe" then
        plat.Position = Vector3.new(0, 15, 0)
    elseif name == "Main" then
        plat.Position = Vector3.new(2270 + math.random(-40, 40), 4780 + math.random(-40, 40), -2310 + math.random(-40, 40))
    elseif not origin then
        plat.Position = Vector3.new(2270, 4780, -2310)
    else
        plat.Position = origin.Position + offset + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
    end
    return plat
end

local function TPAllToPlatform(plat)
    local hrp = GetHRP()
    if not hrp or not plat then return end
    hrp.CFrame = CFrame.new(plat.Position + Vector3.new(0, 6, 0))
    if M.ClientData then
        for _, w in pairs(M.ClientData.get("pet_char_wrappers") or {}) do
            if (w.player == LP or tostring(w.player) == LP.Name) and w.char and w.char:IsA("Model") then
                pcall(function() w.char:PivotTo(hrp.CFrame * CFrame.new(math.random(-4,4), 0, math.random(-1,1))) end)
            end
        end
    end
end

local function TP(location)
    if not API.SetLocation then return false end
    local curr = Cac.CurrentLocation or "MainMap"
    if curr == location then return true end
    if Cac.CurrentLocation == "housing" and API.UnsubscribeHouse then
        pcall(function() API.UnsubscribeHouse:InvokeServer() end)
    end
    local function send()
        if location == "MainMap" then
            pcall(function() API.SetLocation:FireServer(location, nil, LiveOpsMap) end)
        else
            pcall(function() API.SetLocation:FireServer(location) end)
        end
    end
    send()
    local s = tick(); local retried = false
    while tick() - s < 20 do
        task.wait(0.5)
        if (Cac.CurrentLocation or "MainMap") == location then task.wait(0.5); return true end
        if tick() - s > 8 and not retried then retried = true; send() end
    end
    task.wait(1)
    return (Cac.CurrentLocation or "MainMap") == location
end

local function PopulateFurnitureIDs(retries)
    retries = retries or 10
    if not M.ClientData then return 0, 0, 0 end
    local houseData = M.ClientData.get("house_interior")
    local furniture = houseData and houseData.furniture
    if type(furniture) ~= "table" or next(furniture) == nil then
        local data = M.ClientData.get_data() or {}
        local pd = data[LP.Name] or {}
        local hi = pd.house_interior or data.house_interior
        furniture = hi and hi.furniture
    end
    if type(furniture) ~= "table" or next(furniture) == nil then
        if retries > 0 then task.wait(0.5); return PopulateFurnitureIDs(retries - 1) end
        return 0, 0, 0
    end
    table.clear(Cac.BedIds.MainMap); table.clear(Cac.BedIds.School); table.clear(Cac.ShowerIds)
    for fid, item in pairs(furniture) do
        if type(item) == "table" then
            if item.id == "sleepingbag" then table.insert(Cac.BedIds.MainMap, fid)
            elseif item.id == "rectangular_pet_bed" then table.insert(Cac.BedIds.School, fid)
            elseif item.id == "camping_shower" then table.insert(Cac.ShowerIds, fid)
            end
        end
    end
    return #Cac.BedIds.MainMap, #Cac.BedIds.School, #Cac.ShowerIds
end

local function GetFarmTargets()
    local out = { Baby = {}, Pets = {} }
    if not M.ClientData then DebugInfo.Pets, DebugInfo.BabyNeeds, DebugInfo.PetNeeds = 0, 0, 0; return out end
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local am = data.ailments_manager or pd.ailments_manager or M.ClientData.get("ailments_manager")
    if not am then DebugInfo.Pets, DebugInfo.BabyNeeds, DebugInfo.PetNeeds = 0, 0, 0; return out end

    if BabyFarmEnabled and am.baby_ailments then
        for _, a in pairs(am.baby_ailments) do
            if a.kind then
                local norm = NormalizeAilment(a.kind)
                out.Baby[norm] = true
                LogUnknownAilment(a.kind)
            end
        end
    end

    if PetFarmEnabled then
        local wrappers = data.pet_char_wrappers or pd.pet_char_wrappers or M.ClientData.get("pet_char_wrappers")
        if wrappers then
            for _, w in pairs(wrappers) do
                if (w.player == LP or tostring(w.player) == LP.Name) then
                    local al = am.ailments[w.pet_unique] or {}
                    local needs = {}
                    for _, a in pairs(al) do
                        if a.kind then
                            local norm = NormalizeAilment(a.kind)
                            needs[norm] = true
                            LogUnknownAilment(a.kind)
                        end
                    end
                    if next(needs) then
                        table.insert(out.Pets, { uid = w.pet_unique, char = w.char, needs = needs, id = w.pet_id })
                    end
                end
            end
        end
    end

    local bc, pc = 0, #out.Pets
    for _ in pairs(out.Baby) do bc = bc + 1 end
    DebugInfo.Pets, DebugInfo.BabyNeeds, DebugInfo.PetNeeds = pc, bc, pc
    return out
end

local function WaitForNeedDone(kind, timeout, loc)
    local s = os.time()
    while os.time() - s < timeout do
        task.wait(1)
        if not FarmEnabled then return false end
        if loc and (Cac.CurrentLocation or "MainMap") ~= loc then return false end
        local t = GetFarmTargets()
        local still = t.Baby[kind] and true or false
        if not still then for _, p in ipairs(t.Pets) do if p.needs[kind] then still = true; break end end end
        if not still then return true end
    end
    return false
end

local function GetFoodUID(kind)
    if not M.ClientData then return nil end
    local inv = M.ClientData.get("inventory", "Raw")
    if not inv or not inv.food then return nil end
    local list = {}
    for uid, v in pairs(inv.food) do if v.id == kind or v.kind == kind then table.insert(list, uid) end end
    table.sort(list); return list[1]
end

local function DoFeedTask(kind)
    local t = GetFarmTargets()
    local foodKind = kind == "hungry" and "apple" or "water"
    local babyN = t.Baby[kind]
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs[kind] then table.insert(pets, p) end end
    if not babyN and #pets == 0 then return true end

    if babyN and API.ServerUseTool then
        local fid = GetFoodUID(foodKind)
        if not fid then
            local money = M.ClientData.get("money") or 0
            if money >= 5 and API.BuyItem then pcall(function() API.BuyItem:InvokeServer("food", foodKind, { buy_count = 5 }) end); task.wait(0.8); fid = GetFoodUID(foodKind) end
        end
        if fid then
            local n = kind == "thirsty" and 8 or 3
            for i = 1, n do pcall(function() API.ServerUseTool:InvokeServer(fid, "END") end); task.wait(0.08) end
        end
    end

    if API.CreatePetObject and API.ConsumeFoodObject then
        for _, pet in ipairs(pets) do
            local fid = GetFoodUID(foodKind)
            if not fid then
                local money = M.ClientData.get("money") or 0
                if money >= 1 and API.BuyItem then pcall(function() API.BuyItem:InvokeServer("food", foodKind, { buy_count = 1 }) end); task.wait(0.8); fid = GetFoodUID(foodKind) end
            end
            if fid then
                pcall(function()
                    local obj = API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_2", { pet_unique = pet.uid, unique_id = fid })
                    local model = obj and (obj:FindFirstChild("Model") or obj)
                    if not model then
                        local po = Workspace:FindFirstChild("PetObjects")
                        if po then for _, c in ipairs(po:GetChildren()) do
                            local iu = c:FindFirstChild("ItemUniqueId")
                            if iu and iu.Value == fid then model = c:FindFirstChild("Model") or c; break end
                        end end
                    end
                    if model then API.ConsumeFoodObject:FireServer(model, pet.uid) end
                end)
                task.wait(0.5)
            end
        end
    end

    local done = WaitForNeedDone(kind, 15)
    if done then ClearFailure(kind) else MarkFailed(kind) end
    return done
end

local function DoPlayTask()
    local t = GetFarmTargets()
    local toyUid
    if M.ClientData then
        local inv = M.ClientData.get("inventory", "Raw")
        if inv and inv.toys then for uid, v in pairs(inv.toys) do
            local k = tostring(v.kind or v.id)
            if k == "squeaky_bone_default" or k:find("chew_toy") then toyUid = uid; break end
        end end
    end
    if not toyUid then MarkFailed("play"); return false end

    if t.Baby.play and API.ServerUseTool then
        pcall(function() API.ServerUseTool:InvokeServer(toyUid, "END") end)
        task.wait(0.5)
    end

    if API.CreatePetObject then
        for _, pet in ipairs(t.Pets) do
            if pet.needs.play and pet.char then
                pcall(function()
                    API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_1", {
                        reaction_name = "ThrowToyReaction", unique_id = toyUid, pet_unique = pet.uid,
                    })
                end)
                task.wait(1.5)
            end
        end
    end
    local done = WaitForNeedDone("play", 20)
    if done then ClearFailure("play") else MarkFailed("play") end
    return done
end

local function DoSleepDirtyTask(kind)
    local t = GetFarmTargets()
    local isBaby = t.Baby[kind]
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs[kind] then table.insert(pets, p) end end
    if not isBaby and #pets == 0 then return true end

    local location = (kind == "dirty") and "MainMap" or ((Cac.CurrentLocation == "MainMap" or Cac.CurrentLocation == nil) and "MainMap" or "School")

    TPAllToPlatform(CreatePlatform("Main"))
    task.wait(0.5)
    if not TP(location) then MarkFailed(kind); return false end
    task.wait(1.5)

    local bm, bs, sh = PopulateFurnitureIDs()
    SetStatus(kind .. " b" .. bm .. "/" .. bs .. " s" .. sh)

    local ids = (kind == "sleepy") and Cac.BedIds[location] or Cac.ShowerIds
    if not ids or #ids == 0 then SetStatus(kind .. " NO IDS"); MarkFailed(kind); return false end
    if not API.ActivateInterior then MarkFailed(kind); return false end

    local action = (kind == "sleepy" and location == "MainMap") and "Seat2" or "UseBlock"

    local toProcess = {}
    if isBaby and LP.Character then table.insert(toProcess, { type = "Player", char = LP.Character, uid = "BABY", completed = false }) end
    for _, pet in ipairs(pets) do if pet.char then table.insert(toProcess, { type = "Pet", char = pet.char, uid = pet.uid, completed = false }) end end
    if #toProcess == 0 then return true end

    local gStart = tick()
    for i, item in ipairs(toProcess) do
        task.spawn(function()
            local char = item.char
            local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
            if not hrp then return end
            pcall(function() hrp.Anchored = true end)
            local idx = i
            while not item.completed and (tick() - gStart) < 45 do
                if not FarmEnabled or (Cac.CurrentLocation or "MainMap") ~= location then break end
                local fid = ids[(idx - 1) % #ids + 1]
                idx = idx + 1
                pcall(function() API.ActivateInterior:InvokeServer(fid, action, { cframe = hrp.CFrame }, char) end)
                task.wait(1.5)
                local tt = GetFarmTargets()
                local still
                if item.type == "Player" then still = tt.Baby[kind] else
                    still = false
                    for _, p in ipairs(tt.Pets) do if p.uid == item.uid and p.needs[kind] then still = true; break end end
                end
                if not still then item.completed = true; break end
            end
            pcall(function() hrp.Anchored = false end)
        end)
        task.wait(0.3)
    end

    local wStart = tick()
    while tick() - wStart < 45 do
        task.wait(1)
        if not FarmEnabled or (Cac.CurrentLocation or "MainMap") ~= location then break end
        local allDone = true
        for _, item in ipairs(toProcess) do if not item.completed then allDone = false; break end end
        if allDone then break end
    end

    for _, item in ipairs(toProcess) do
        if item.type == "Player" then
            if API.ExitSeats then pcall(function() API.ExitSeats:FireServer() end) end
            local hum = item.char and item.char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Sit = false; hum.Jump = true end
        elseif API.ExitFurniture then
            task.spawn(function() pcall(function() API.ExitFurniture:InvokeServer(item.uid) end) end)
        end
    end

    local done = WaitForNeedDone(kind, 5)
    if done then ClearFailure(kind) else MarkFailed(kind) end
    return done
end

local function DoToiletTask()
    TPAllToPlatform(CreatePlatform("Main")); task.wait(0.5)
    if not TP("MainMap") then MarkFailed("toilet"); return false end
    task.wait(0.5)
    TPAllToPlatform(CreatePlatform("Toilet")); task.wait(1)

    local interact = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("Interactables")
    if not interact then MarkFailed("toilet"); return false end
    local hydrant
    for _, c in ipairs(interact:GetDescendants()) do
        if c.Name:find("AilmentsRefresh2024FireHydrant") then hydrant = c; break end
    end
    if not hydrant then MarkFailed("toilet"); return false end

    local fid, p = nil, hydrant
    while p do local m = p.Name:match("f%-%d+"); if m then fid = m; break end; p = p.Parent end

    if fid and LP.Character and API.ActivateInterior then
        pcall(function() API.ActivateInterior:InvokeServer(fid, "UseBlock", { cframe = LP.Character:GetPivot() }, LP.Character) end)
    end
    local done = WaitForNeedDone("toilet", 25, "MainMap")
    if done then ClearFailure("toilet") else MarkFailed("toilet") end
    return done
end

local function DoSickTask()
    if not TP("Hospital") then MarkFailed("sick"); return false end
    task.wait(2)
    if API.ActivateInterior then
        pcall(function() API.ActivateInterior:InvokeServer("f-14", "UseBlock", "Yes", LP.Character) end)
    end
    local done = WaitForNeedDone("sick", 30, "Hospital")
    if done then ClearFailure("sick") else MarkFailed("sick") end
    return done
end

local function DoMysteryTask()
    local t = GetFarmTargets()
    local pets = {}
    for _, p in ipairs(t.Pets) do
        if p.needs.mystery or p.needs.misery then
            if not Cac.MysteryBlacklist[p.uid] or os.time() - Cac.MysteryBlacklist[p.uid] > 60 then
                table.insert(pets, { pet = p, kind = p.needs.mystery and "mystery" or "misery" })
            end
        end
    end
    if #pets == 0 then return true end
    if Cac.LastMysteryAttempt and os.time() - Cac.LastMysteryAttempt < 5 then return false end
    Cac.LastMysteryAttempt = os.time()

    local combos = {
        { 1, "bored" }, { 1, "sad" }, { 1, "misery" },
        { "mystery", "bored" }, { 2, "bored" }, { 3, "bored" },
        { 1, "sleepy" }, { 1, "hungry" }, { 1, "sick" },
    }
    for _, e in ipairs(pets) do
        Cac.MysteryFails[e.pet.uid] = (Cac.MysteryFails[e.pet.uid] or 0) + 1
        if Cac.MysteryFails[e.pet.uid] >= 3 then
            Cac.MysteryBlacklist[e.pet.uid] = os.time()
            Cac.MysteryFails[e.pet.uid] = nil
        elseif API.ChooseMystery then
            for _, c in ipairs(combos) do
                pcall(function() API.ChooseMystery:FireServer(e.pet.uid, e.kind, c[1], c[2]) end)
                task.wait(0.3)
            end
        end
    end
    local done = WaitForNeedDone("mystery", 12) or WaitForNeedDone("misery", 12)
    if done then ClearFailure("mystery"); ClearFailure("misery") else MarkFailed("mystery") end
    return done
end

local function DoPetMeTask()
    local t = GetFarmTargets()
    local processed = false
    local entities = nil
    if M.PetEntityManager and M.PetEntityManager.get_local_owned_pet_entities then
        pcall(function() entities = M.PetEntityManager.get_local_owned_pet_entities() end)
    end

    for _, pet in ipairs(t.Pets) do
        if pet.needs.pet_me then
            if not Cac.PetMeAttempts[pet.uid] or os.time() - Cac.PetMeAttempts[pet.uid] > 10 then
                Cac.PetMeAttempts[pet.uid] = os.time()
                local entity
                if entities then
                    for _, e in pairs(entities) do
                        if e.base and e.base.char_wrapper and e.base.char_wrapper.pet_unique == pet.uid then entity = e; break end
                    end
                end
                if entity and M.PetEntityHelper and M.PetEntityHelper.stage_performance then
                    pcall(function() M.PetEntityHelper.stage_performance(entity, { name = "FocusPet" }) end)
                    task.wait(0.15)
                end
                if API.ProgressPetMe then
                    pcall(function() API.ProgressPetMe:FireServer(pet.uid) end)
                end
                if entity and M.PetEntityHelper and M.PetEntityHelper.end_performance then
                    task.wait(0.15)
                    pcall(function() M.PetEntityHelper.end_performance(entity, "FocusPet") end)
                end
                task.wait(1.5)
                processed = true
            end
        end
    end
    if not processed then return true end
    local done = WaitForNeedDone("pet_me", 15)
    if done then ClearFailure("pet_me") else MarkFailed("pet_me") end
    return done
end

local function DoWalkTask()
    local t = GetFarmTargets()
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs.walk then table.insert(pets, p) end end
    if not t.Baby.walk and #pets == 0 then return true end

    TPAllToPlatform(CreatePlatform("Main")); task.wait(0.5)
    if not TP("MainMap") then MarkFailed("walk"); return false end
    task.wait(1)
    TPAllToPlatform(CreatePlatform("Main")); task.wait(1)

    local plat = Cac.AilmentPlatform
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not plat or not hum then MarkFailed("walk"); return false end

    local s = tick(); local angle = 0
    while tick() - s < 30 do
        task.wait(0.15)
        if not FarmEnabled then break end
        local tt = GetFarmTargets()
        local still = tt.Baby.walk and true or false
        if not still then for _, p in ipairs(tt.Pets) do if p.needs.walk then still = true; break end end end
        if not still then break end
        angle = angle + 0.15
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        pcall(function() hum:MoveTo(plat.Position + Vector3.new(math.cos(angle) * 20, 6, math.sin(angle) * 20)) end)
    end

    local done = WaitForNeedDone("walk", 10)
    if done then ClearFailure("walk") else MarkFailed("walk") end
    return done
end

local function DoRideTask()
    local t = GetFarmTargets()
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs.ride then table.insert(pets, p) end end
    if not t.Baby.ride and #pets == 0 then return true end

    TPAllToPlatform(CreatePlatform("Main")); task.wait(0.5)
    if not TP("MainMap") then MarkFailed("ride"); return false end
    task.wait(1)
    TPAllToPlatform(CreatePlatform("Main")); task.wait(1)

    if not Cac.StrollerUID and M.ClientData then
        local inv = M.ClientData.get("inventory", "Raw")
        if inv and inv.strollers then for uid, v in pairs(inv.strollers) do
            if (v.kind or v.id) == "stroller-default" then Cac.StrollerUID = uid; break end
        end end
    end
    if Cac.StrollerUID and os.time() - Cac.LastStrollerEquip > 3 and API.Equip then
        Cac.LastStrollerEquip = os.time()
        pcall(function() API.Equip:InvokeServer(Cac.StrollerUID) end)
        task.wait(1)
    end

    local plat = Cac.AilmentPlatform
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    local s = tick(); local angle = 0
    while tick() - s < 30 do
        task.wait(0.15)
        if not FarmEnabled then break end
        local tt = GetFarmTargets()
        local still = tt.Baby.ride and true or false
        if not still then for _, p in ipairs(tt.Pets) do if p.needs.ride then still = true; break end end end
        if not still then break end
        if plat and hum then
            angle = angle + 0.12
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
            pcall(function() hum:MoveTo(plat.Position + Vector3.new(math.cos(angle) * 20, 6, math.sin(angle) * 20)) end)
        end
    end

    if Cac.StrollerUID and API.Unequip then pcall(function() API.Unequip:InvokeServer(Cac.StrollerUID) end) end
    local done = WaitForNeedDone("ride", 10)
    if done then ClearFailure("ride") else MarkFailed("ride") end
    return done
end

local function DoQuestTask(kind, location, platName)
    TPAllToPlatform(CreatePlatform("Main")); task.wait(0.5)
    if not TP(location) then MarkFailed(kind); return false end
    task.wait(1.5)

    if platName then
        TPAllToPlatform(CreatePlatform(platName))
        task.wait(1.5)
    else
        TPAllToPlatform(CreatePlatform("Main"))
        task.wait(1)
    end

    local s = tick()
    while tick() - s < 90 do
        task.wait(2)
        if not FarmEnabled then break end
        if (Cac.CurrentLocation or "MainMap") ~= location then break end
        if not Cac.AilmentPlatform or not Cac.AilmentPlatform.Parent then
            if platName then TPAllToPlatform(CreatePlatform(platName)) else TPAllToPlatform(CreatePlatform("Main")) end
        end
        local t = GetFarmTargets()
        local still = t.Baby[kind] and true or false
        if not still then for _, p in ipairs(t.Pets) do if p.needs[kind] then still = true; break end end end
        if not still then break end
    end

    local done = WaitForNeedDone(kind, 5)
    if done then ClearFailure(kind) else MarkFailed(kind) end
    return done
end

local WEATHER_TAGS = {
    rain_puddle = "RainPuddleServer",
    leaf_pile   = "LeafPileServer",
    snow        = "SnowPileServer",
    diving_board= "DivingBoardServer",
}

local function DoWeatherTask(kind)
    local t = GetFarmTargets()
    local targets = {}
    if t.Baby[kind] then table.insert(targets, { type = "Player", char = LP.Character, uid = "BABY" }) end
    for _, pet in ipairs(t.Pets) do
        if pet.needs[kind] and pet.char then table.insert(targets, { type = "Pet", char = pet.char, uid = pet.uid }) end
    end
    if #targets == 0 then return true end

    local loc = "MainMap"
    local cframe, fid
    local tag = WEATHER_TAGS[kind]
    if tag then
        local tagged = CollectionService:GetTagged(tag)
        if #tagged > 0 then
            local inst = tagged[1]
            if kind == "diving_board" then fid = "f-31" else
                local p = inst
                while p do local m = p.Name:match("f%-%d+"); if m then fid = m; break end; p = p.Parent end
            end
            cframe = inst:IsA("Model") and inst:GetPivot() or inst.CFrame
        end
    end

    TPAllToPlatform(CreatePlatform("Main")); task.wait(0.5)
    if not TP(loc) then MarkFailed(kind); return false end
    task.wait(1.5)

    if not cframe then MarkFailed(kind); return false end
    local plat = CreatePlatform("WeatherPlatform")
    plat.CFrame = cframe * CFrame.new(0, -3.5, 0)
    TPAllToPlatform(plat)
    task.wait(1.5)

    if fid and API.ActivateInterior then
        for _, item in ipairs(targets) do
            task.spawn(function()
                for i = 1, 3 do
                    if not FarmEnabled then break end
                    if item.type == "Pet" and item.char and item.char.PrimaryPart then
                        pcall(function() item.char:PivotTo(cframe * CFrame.new(0, 2, 0)) end)
                    end
                    pcall(function() API.ActivateInterior:InvokeServer(fid, "UseBlock", { cframe = cframe }, item.char) end)
                    task.wait(2)
                end
            end)
        end
    end

    local s = tick()
    while tick() - s < 40 do
        task.wait(2)
        if not FarmEnabled then break end
        local tt = GetFarmTargets()
        local still = tt.Baby[kind] and true or false
        if not still then for _, p in ipairs(tt.Pets) do if p.needs[kind] then still = true; break end end end
        if not still then break end
    end

    local done = WaitForNeedDone(kind, 5)
    if done then ClearFailure(kind) else MarkFailed(kind) end
    return done
end

-- ══════════════════ SWF / HATCH / AGEPOT / FASTMEGA ══════════════════
local function GetMaxSlots()
    if not M.ClientData then return 1 end
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local sub = data.subscription_manager or pd.subscription_manager
    if sub and sub.equip_2x_pets then
        local s = tostring(sub.equip_2x_pets.state):lower()
        if s ~= "neversubscribed" and s ~= "expired" and s ~= "canceled" then return 2 end
    end
    return 1
end

local function GetLockedUIDs()
    if not M.ClientData then return {} end
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local ipm = data.idle_progression_manager or pd.idle_progression_manager
    local locked = {}
    if ipm and ipm.active_pets then for uid in pairs(ipm.active_pets) do locked[uid] = true end end
    return locked
end

local function ProcessSWFQueue()
    if not SWFEnabled or not M.ClientData or not M.InventoryDB then return end
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local inv = data.inventory or pd.inventory or M.ClientData.get("inventory")
    if not inv or not inv.pets then return end
    local eq = data.equip_manager or pd.equip_manager
    local maxSlots = GetMaxSlots()
    local locked = GetLockedUIDs()

    local activePets = eq and eq.pets or {}
    local activeUIDs = {}
    for _, p in ipairs(activePets) do activeUIDs[p.unique] = true end

    local validByKind = {}
    for uid, p in pairs(inv.pets) do
        if not locked[uid] then
            local k = p.kind or p.id
            if SWFTargets[k] then
                local db = M.InventoryDB.pets[k]
                if db and not db.is_egg then
                    local pr = p.properties or {}
                    local isM = pr.mega_neon or pr.is_mega
                    local isN = pr.neon or pr.is_neon
                    local age = tonumber(pr.age) or 1
                    if not isM and age < 6 then
                        if (SwfMode == "Neon" and isN) or (SwfMode == "Regular" and not isN) then
                            validByKind[k] = validByKind[k] or {}
                            table.insert(validByKind[k], { uid = uid, age = age })
                        end
                    end
                end
            end
        end
    end
    for _, list in pairs(validByKind) do table.sort(list, function(a,b) return a.age > b.age end) end

    local sorted = {}
    for k in pairs(validByKind) do table.insert(sorted, k) end
    table.sort(sorted)

    local ideal, used = {}, {}
    for _, ap in ipairs(activePets) do
        for _, k in ipairs(sorted) do
            if used[k] and SwfSplitMode then break end
            for _, p in ipairs(validByKind[k]) do
                if p.uid == ap.unique then table.insert(ideal, ap.unique); used[k] = true; break end
            end
            if #ideal >= maxSlots then break end
        end
        if #ideal >= maxSlots then break end
    end

    if #ideal < maxSlots then
        for _, k in ipairs(sorted) do
            if not (SwfSplitMode and used[k]) then
                for _, p in ipairs(validByKind[k]) do
                    if not table.find(ideal, p.uid) then table.insert(ideal, p.uid); used[k] = true; break end
                end
            end
            if #ideal >= maxSlots then break end
        end
    end

    if #ideal == 0 then return end
    local needsSwap = #ideal ~= #activePets
    if not needsSwap then for _, uid in ipairs(ideal) do if not activeUIDs[uid] then needsSwap = true; break end end end

    if needsSwap then
        for _, ap in ipairs(activePets) do
            if not table.find(ideal, ap.unique) and API.Unequip then pcall(function() API.Unequip:InvokeServer(ap.unique) end); task.wait(1.5) end
        end
        for _, uid in ipairs(ideal) do
            if not activeUIDs[uid] and API.Equip then pcall(function() API.Equip:InvokeServer(uid, { equip_as_last = true }) end); task.wait(1.5) end
        end
    end
end

local function ProcessHatchQueue()
    if not AutoHatch or not M.ClientData or not M.InventoryDB then return end
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local inv = data.inventory or pd.inventory or M.ClientData.get("inventory")
    if not inv or not inv.pets then return end
    local eq = data.equip_manager or pd.equip_manager
    local maxSlots = GetMaxSlots()
    local locked = GetLockedUIDs()

    local activePets = eq and eq.pets or {}
    local activeUIDs = {}
    for _, p in ipairs(activePets) do activeUIDs[p.unique] = true end

    local available, totalValid = {}, 0
    for uid, p in pairs(inv.pets) do
        if not locked[uid] then
            local k = p.kind or p.id
            local db = M.InventoryDB.pets[k]
            if db and db.is_egg then
                local limit = HatchLimits[k] or 0
                local hatched = HatchedSessionCounts[k] or 0
                if limit == 0 or hatched < limit then
                    available[k] = available[k] or {}
                    table.insert(available[k], uid)
                    totalValid = totalValid + 1
                end
            end
        end
    end

    if totalValid == 0 then AutoHatch = false; table.clear(ActiveHatchUIDs); return end
    for _, list in pairs(available) do table.sort(list) end

    local ideal = {}
    for _, ap in ipairs(activePets) do
        for k, list in pairs(available) do
            if table.find(list, ap.unique) then
                if #HatchPriority == 0 or table.find(HatchPriority, k) then table.insert(ideal, ap.unique); break end
            end
        end
        if #ideal >= maxSlots then break end
    end

    if #ideal == 0 then
        for _, list in pairs(available) do for _, uid in ipairs(list) do
            if not table.find(ideal, uid) then table.insert(ideal, uid); if #ideal >= maxSlots then break end end
        end; if #ideal >= maxSlots then break end end
    end

    local needsSwap = #ideal ~= #activePets
    if not needsSwap then for _, uid in ipairs(ideal) do if not activeUIDs[uid] then needsSwap = true; break end end end

    if needsSwap and #ideal > 0 then
        table.clear(ActiveHatchUIDs)
        for _, ap in ipairs(activePets) do
            if not table.find(ideal, ap.unique) and API.Unequip then pcall(function() API.Unequip:InvokeServer(ap.unique) end); task.wait(1.5) end
        end
        for i, uid in ipairs(ideal) do
            if inv.pets[uid] then
                ActiveHatchUIDs[uid] = inv.pets[uid].kind or inv.pets[uid].id
            end
            if not activeUIDs[uid] and API.Equip then
                pcall(function() API.Equip:InvokeServer(uid, { equip_as_last = (i > 1) }) end)
                task.wait(1.5)
            end
        end
    end
end

local function ProcessAgePotQueue()
    if not AutoAgePot and not (FastMegaTimer > os.time()) then return end
    if not M.ClientData or not M.InventoryDB then return end
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local inv = data.inventory or pd.inventory or M.ClientData.get("inventory")
    if not inv or not inv.pets then return end
    local eq = data.equip_manager or pd.equip_manager
    local maxSlots = GetMaxSlots()
    local locked = GetLockedUIDs()

    local activePets = eq and eq.pets or {}
    local activeUIDs = {}
    for _, p in ipairs(activePets) do activeUIDs[p.unique] = true end

    local ideal = {}
    for _, ap in ipairs(activePets) do
        if inv.pets[ap.unique] then
            local k = inv.pets[ap.unique].kind or inv.pets[ap.unique].id
            local db = M.InventoryDB.pets[k]
            if db and not db.is_egg then
                local pr = inv.pets[ap.unique].properties or {}
                if (pr.age or 1) == 6 and not (pr.neon or pr.mega_neon) then
                    table.insert(ideal, ap.unique); if #ideal >= maxSlots then break end
                end
            end
        end
    end
    if #ideal < maxSlots then
        for uid, p in pairs(inv.pets) do
            if not locked[uid] and not table.find(ideal, uid) then
                local k = p.kind or p.id
                local db = M.InventoryDB.pets[k]
                if db and not db.is_egg then
                    local pr = p.properties or {}
                    if (pr.age or 1) == 6 and not (pr.neon or pr.mega_neon) then
                        table.insert(ideal, uid); if #ideal >= maxSlots then break end
                    end
                end
            end
        end
    end

    if #ideal == 0 then
        if FastMegaTimer > os.time() then FastMegaTimer = 0 end
        if AutoAgePot then AutoAgePot = false; Flags.YF_AgePot = false end
        return
    end

    local needsSwap = #ideal ~= #activePets
    if not needsSwap then for _, uid in ipairs(ideal) do if not activeUIDs[uid] then needsSwap = true; break end end end

    if needsSwap then
        for _, ap in ipairs(activePets) do
            if not table.find(ideal, ap.unique) and API.Unequip then pcall(function() API.Unequip:InvokeServer(ap.unique) end); task.wait(1.5) end
        end
        for _, uid in ipairs(ideal) do
            if not activeUIDs[uid] and API.Equip then pcall(function() API.Equip:InvokeServer(uid, { equip_as_last = true }) end); task.wait(3) end
        end
    end
end

local function ProcessFastMegaQueue()
    if not (FastMegaEnabled or FastMegaPipeline) then return end
    if not M.ClientData or not M.InventoryDB then return end

    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local inv = data.inventory or pd.inventory or M.ClientData.get("inventory")
    if not inv or not inv.pets then return end
    local eq = data.equip_manager or pd.equip_manager

    local potCount = 0
    for _, f in pairs(inv.food or {}) do
        local id = f.id or f.kind
        if id == "pet_age_potion" or id == "age_potion" or id == "small_age_potion" then potCount = potCount + 1 end
    end

    if FastMegaFarmPots and potCount < 7 and FastMegaTimer == 0 then
        FastMegaTimer = os.time() + 3600
        SetStatus("FastMega: farm pots")
    end
    if FastMegaTimer > os.time() then ProcessAgePotQueue(); return end
    if FastMegaTimer ~= 0 and FastMegaTimer <= os.time() then FastMegaTimer = 0 end

    local targetKinds = {}
    if FastMegaPipeline and FastMegaPipeMode == "All" then
        for _, p in pairs(inv.pets) do
            local k = p.kind or p.id
            local db = M.InventoryDB.pets[k]
            if db and not db.is_egg and not table.find(targetKinds, k) then table.insert(targetKinds, k) end
        end
    else
        for k, v in pairs(FastMegaTargets) do if v then table.insert(targetKinds, k) end end
    end

    local groups = {}
    for uid, p in pairs(inv.pets) do
        local k = p.kind or p.id
        if table.find(targetKinds, k) then
            local pr = p.properties or {}
            local age = pr.age or 1
            local isN = pr.neon or pr.is_neon
            local isM = pr.mega_neon or pr.is_mega
            if age == 6 and not isN and not isM then
                groups[k] = groups[k] or { regular = {}, neon = {} }
                table.insert(groups[k].regular, uid)
            elseif isN and not isM then
                groups[k] = groups[k] or { regular = {}, neon = {} }
                table.insert(groups[k].neon, uid)
            end
        end
    end

    if not API.DoNeonFusion then return end
    for k, g in pairs(groups) do
        if #g.regular >= 4 then
            SetStatus("Craft Neon " .. k)
            pcall(function() API.DoNeonFusion:InvokeServer({ g.regular[1], g.regular[2], g.regular[3], g.regular[4] }) end)
            task.wait(4)
        elseif FastMegaMode == "Mega" and #g.neon >= 4 then
            SetStatus("Craft Mega " .. k)
            pcall(function() API.DoNeonFusion:InvokeServer({ g.neon[1], g.neon[2], g.neon[3], g.neon[4] }) end)
            task.wait(4)
        end
    end
end

-- ══════════════════ MAIN LOOP ══════════════════
task.spawn(function()
    while task.wait(2) do
        if not FarmEnabled then SetStatus("Farm OFF"); continue end
        if not PetFarmEnabled and not BabyFarmEnabled then SetStatus("No modes"); continue end

        local ok, err = pcall(function()
            local t = GetFarmTargets()
            local b, pets = t.Baby, t.Pets
            local function has(k)
                if b[k] then return true end
                for _, p in ipairs(pets) do if p.needs[k] then return true end end
                return false
            end

            local priorities = {
                { "mystery", function() return DoMysteryTask() end },
                { "misery", function() return DoMysteryTask() end },
                { "pet_me", function() return DoPetMeTask() end },
                { "camping", function() return DoQuestTask("camping", "MainMap", "Camping") end },
                { "bored", function() return DoQuestTask("bored", "MainMap", "Playground") end },
                { "beach_party", function() return DoQuestTask("beach_party", "MainMap", "Beach") end },
                { "salon", function() return DoQuestTask("salon", "Salon") end },
                { "school", function() return DoQuestTask("school", "School") end },
                { "pizza_party", function() return DoQuestTask("pizza_party", "PizzaShop") end },
                { "cat_cafe", function() return DoQuestTask("cat_cafe", "CatCafe") end },
                { "sick", function() return DoSickTask() end },
                { "play", function() return DoPlayTask() end },
                { "hungry", function() return DoFeedTask("hungry") end },
                { "thirsty", function() return DoFeedTask("thirsty") end },
                { "walk", function() return DoWalkTask() end },
                { "ride", function() return DoRideTask() end },
                { "dirty", function() return DoSleepDirtyTask("dirty") end },
                { "sleepy", function() return DoSleepDirtyTask("sleepy") end },
                { "toilet", function() return DoToiletTask() end },
            }

            for _, e in ipairs(priorities) do
                if has(e[1]) then
                    if CanTry(e[1]) then
                        SetStatus(e[1] .. "...")
                        local success = e[2]()
                        if success then ClearFailure(e[1]) end
                    else
                        local f = TaskFailures[e[1]]
                        local s = f and math.max(0, math.floor(30 - (tick() - f.time))) or 30
                        SetStatus(e[1] .. " retry " .. s .. "s")
                    end
                    return
                end
            end

            for _, w in ipairs({ "leaf_pile", "rain_puddle", "snow", "diving_board", "party_zone" }) do
                if has(w) then
                    if CanTry(w) then SetStatus(w); DoWeatherTask(w) end
                    return
                end
            end

            SetStatus("Idle " .. DebugInfo.Pets .. "p " .. DebugInfo.BabyNeeds .. "b")
        end)
        if not ok then SetStatus("Error: " .. tostring(err)) end
    end
end)

-- SWF/HATCH/AGEPOT LOOP
task.spawn(function()
    while task.wait(2.5) do
        if not FarmEnabled then continue end
        pcall(function()
            if AutoHatch then ProcessHatchQueue() end
            if SWFEnabled and not AutoHatch then ProcessSWFQueue() end
            if AutoAgePot then ProcessAgePotQueue() end
            if FastMegaEnabled or FastMegaPipeline then ProcessFastMegaQueue() end
        end)
    end
end)

-- WATCHDOG
task.spawn(function()
    while task.wait(2) do
        if not FarmEnabled then TaskFailTrack.time = 0; continue end
        if not M.ClientData then continue end
        pcall(function()
            local data = M.ClientData.get_data() or {}
            local pd = data[LP.Name] or {}
            local eq = data.equip_manager or pd.equip_manager
            local wrappers = data.pet_char_wrappers or pd.pet_char_wrappers or M.ClientData.get("pet_char_wrappers") or {}

            if eq and eq.pets then
                local ghost = false
                for _, ap in ipairs(eq.pets) do
                    local has = false
                    for _, w in pairs(wrappers) do
                        if w.pet_unique == ap.unique and w.char and w.char.Parent then has = true; break end
                    end
                    if not has then
                        SetStatus("Ghost swap...")
                        if API.Unequip then pcall(function() API.Unequip:InvokeServer(ap.unique) end); task.wait(1.5) end
                        if API.Equip then pcall(function() API.Equip:InvokeServer(ap.unique, { equip_as_last = true }) end) end
                        ghost = true
                    end
                end
                if ghost then task.wait(2.5); return end
            end

            local targets = GetFarmTargets()
            local has = next(targets.Baby) or #targets.Pets > 0
            if not has then TaskFailTrack.time = 0
            elseif TaskFailTrack.time == 0 then TaskFailTrack.time = os.time()
            elseif os.time() - TaskFailTrack.time > 40 then
                SetStatus("Anti-Stuck!")
                if eq and eq.pets then
                    for _, ap in ipairs(eq.pets) do if API.Unequip then pcall(function() API.Unequip:InvokeServer(ap.unique) end) end end
                    task.wait(1.5)
                    for _, ap in ipairs(eq.pets) do if API.Equip then pcall(function() API.Equip:InvokeServer(ap.unique, { equip_as_last = true }) end) end end
                end
                TaskFailTrack.time = 0
            end
        end)
    end
end)

-- ══════════════════ VISUALS ══════════════════
local VisualVars = { Mega = false, Neon = false, Fly = false, Ride = false }
local SavedPetVisuals = {}
local VisualParts = {}
local RAINBOW = {
    Color3.fromRGB(255, 72, 69), Color3.fromRGB(255, 96, 93), Color3.fromRGB(245, 255, 99),
    Color3.fromRGB(149, 255, 79), Color3.fromRGB(73, 255, 82), Color3.fromRGB(80, 255, 159),
    Color3.fromRGB(78, 47, 255), Color3.fromRGB(160, 97, 255), Color3.fromRGB(255, 97, 189),
}

local function RefreshPetVisuals()
    table.clear(VisualParts)
    if not M.ClientData or not M.InventoryDB then return end
    for _, w in pairs(M.ClientData.get("pet_char_wrappers") or {}) do
        if (w.player == LP or tostring(w.player) == LP.Name) and w.char then
            local s = SavedPetVisuals[w.pet_unique]
            if s then
                local model = w.char:FindFirstChild("PetModel") or w.char
                local db = M.InventoryDB.pets[w.pet_id]
                if db and (s.Mega or s.Neon) then
                    local parts = s.Mega and (db.mega_neon_parts or db.neon_parts) or db.neon_parts or {}
                    for k, v in pairs(parts) do
                        local pn = type(k) == "string" and k or v
                        for _, desc in ipairs(model:GetDescendants()) do
                            if desc:IsA("BasePart") and desc.Name == pn then
                                table.insert(VisualParts, { Part = desc, IsMega = s.Mega, Color = db.neon_color or Color3.new(1,1,1) })
                                pcall(function()
                                    if desc:IsA("MeshPart") and desc.TextureID ~= "" then desc.TextureID = "" end
                                    desc.Material = Enum.Material.Neon
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end

task.spawn(function()
    RunService.Heartbeat:Connect(function()
        if #VisualParts == 0 then return end
        local t = tick() * 2
        local idx = math.floor(t % #RAINBOW) + 1
        local c = RAINBOW[idx]:Lerp(RAINBOW[idx % #RAINBOW + 1], t % 1)
        for _, v in ipairs(VisualParts) do
            if v.Part and v.Part.Parent then
                v.Part.Material = Enum.Material.Neon
                v.Part.Transparency = 0
                v.Part.Color = v.IsMega and c or v.Color
            end
        end
    end)
end)

if M.ClientData then
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
                else newPets[uid] = pet end
            end
            local c = {}; for k, v in pairs(res) do c[k] = v end; c.pets = newPets
            return c
        end
        return res
    end
end

-- ══════════════════ SHOP ══════════════════
local AutoBuyEnabled = false
local BuyTargets = {}
local ShopCatalog = {
    cracked_egg = { cat = "pets", price = 350, name = "Cracked Egg" },
    regular_pet_egg = { cat = "pets", price = 600, name = "Pet Egg" },
    royal_egg = { cat = "pets", price = 1450, name = "Royal Egg" },
    smallgift = { cat = "gifts", price = 70, name = "Small Gift" },
    biggift = { cat = "gifts", price = 199, name = "Big Gift" },
    massivegift = { cat = "gifts", price = 499, name = "Massive Gift" },
}

task.spawn(function()
    while task.wait(2) do
        if not AutoBuyEnabled or not API.BuyItem or not M.ClientData then continue end
        pcall(function()
            local money = M.ClientData.get("money") or 0
            for k, v in pairs(BuyTargets) do
                if v and ShopCatalog[k] and money >= ShopCatalog[k].price then
                    pcall(function() API.BuyItem:InvokeServer(ShopCatalog[k].cat, k, { buy_count = 1 }) end)
                    task.wait(0.8)
                end
            end
        end)
    end
end)

-- ══════════════════ TRADE VALUES ══════════════════
local ValuesCache = {
    shadow_dragon = { regular = 0.5, neon = 2.5, mega = 12 },
    bat_dragon = { regular = 0.4, neon = 2.0, mega = 10 },
    giraffe = { regular = 0.3, neon = 1.5, mega = 7 },
    frost_dragon = { regular = 0.25, neon = 1.2, mega = 6 },
}
local tradeCalcEnabled = false
task.spawn(function()
    while task.wait(1) do
        if not tradeCalcEnabled or not M.ClientData then continue end
        pcall(function()
            local data = M.ClientData.get_data() or {}
            local pd = data[LP.Name]
            local trade = pd and pd.trade
            if not trade or trade.current_stage ~= "negotiation" then return end
            local myOffer = (trade.sender_offer.player_name == LP.Name) and trade.sender_offer or trade.recipient_offer
            local theirOffer = (trade.sender_offer.player_name == LP.Name) and trade.recipient_offer or trade.sender_offer
            local myV, theirV = 0, 0
            for _, it in pairs(myOffer.items or {}) do
                local k = tostring(it.id or it.kind):lower():gsub("[%s%-_]+", "")
                if ValuesCache[k] then myV = myV + (ValuesCache[k].regular or 0) end
            end
            for _, it in pairs(theirOffer.items or {}) do
                local k = tostring(it.id or it.kind):lower():gsub("[%s%-_]+", "")
                if ValuesCache[k] then theirV = theirV + (ValuesCache[k].regular or 0) end
            end
            local profit = theirV - myV
            local letter = "F"
            if profit > 0.01 then letter = "W" elseif profit < -0.01 then letter = "L" end
            if Flags.__tradeLbl and Flags.__tradeLbl.Parent then
                Flags.__tradeLbl.Text = string.format("%s (%+.2f)", letter, profit)
            end
        end)
    end
end)

-- ══════════════════ BUILD TABS ══════════════════
AddTab("7733960981", "Home", function(page)
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Yuno Farm v5.1", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = page })
    local sc = Make("Frame", { Size = UDim2.new(1, 0, 0, 80), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.3, Parent = page })
    Make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = sc })
    local lbl = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1, Text = "Status: Idle", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })
    Flags.__statusLbl = lbl
    local info = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 32), BackgroundTransparency = 1, Text = "-", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })
    local loc = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 50), BackgroundTransparency = 1, Text = "-", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })

    task.spawn(function()
        while task.wait(1) do
            if not sc.Parent then break end
            info.Text = string.format("🐾 %d pets • 🍼 %d baby", DebugInfo.Pets, DebugInfo.BabyNeeds)
            loc.Text = "Loc: " .. tostring(Cac.CurrentLocation) .. " • Beds: " .. (#Cac.BedIds.MainMap + #Cac.BedIds.School) .. " • Showers: " .. #Cac.ShowerIds
        end
    end)

    UI.Button(page, { Name = "🔄 Refresh Furniture", Callback = function()
        local bm, bs, sh = PopulateFurnitureIDs()
        Notify("Furniture", bm .. "/" .. bs .. " beds, " .. sh .. " showers")
    end })
end)

AddTab("6908632622", "AutoFarm", function(page)
    UI.Section(page, "Master")
    UI.Toggle(page, { Name = "Farm Master", Flag = "YF_FarmMaster", Callback = function(v) FarmEnabled = v; Notify("Yuno", v and "ON" or "OFF") end })
    UI.Toggle(page, { Name = "Pet Farm", Flag = "YF_PetFarm", Callback = function(v) PetFarmEnabled = v end })
    UI.Toggle(page, { Name = "Baby Farm", Flag = "YF_BabyFarm", Callback = function(v) BabyFarmEnabled = v end })

    UI.Section(page, "Tools")
    UI.Button(page, { Name = "Reset Task Failures", Callback = function() TaskFailures = {}; Notify("Yuno", "Cleared") end })
    UI.Button(page, { Name = "Destroy Platform", Callback = function() if Cac.AilmentPlatform then Cac.AilmentPlatform:Destroy(); Cac.AilmentPlatform = nil end end })
end)

AddTab("128557027005598", "Advanced", function(page)
    UI.Section(page, "SWF")
    UI.Toggle(page, { Name = "SWF Enabled", Flag = "YF_SWF", Callback = function(v) SWFEnabled = v end })
    UI.Dropdown(page, { Name = "SWF Mode", Flag = "YF_SWFMode", Options = { "Regular", "Neon" }, Default = "Regular", Callback = function(v) SwfMode = v end })

    UI.Section(page, "Auto Hatch")
    UI.Toggle(page, { Name = "Auto Hatch Eggs", Flag = "YF_AutoHatch", Callback = function(v) AutoHatch = v end })

    UI.Section(page, "Age-Pot")
    UI.Toggle(page, { Name = "Auto Age-Pot Farm", Flag = "YF_AgePot", Callback = function(v) AutoAgePot = v end })

    UI.Section(page, "Fast Mega")
    UI.Toggle(page, { Name = "Fast Mega Enabled", Flag = "YF_FastMega", Callback = function(v) FastMegaEnabled = v end })
    UI.Toggle(page, { Name = "Fast Mega Pipeline", Flag = "YF_FastPipe", Callback = function(v) FastMegaPipeline = v end })
    UI.Dropdown(page, { Name = "Fast Mega Mode", Flag = "YF_FMMode", Options = { "Neon", "Mega" }, Default = "Neon", Callback = function(v) FastMegaMode = v end })
    UI.Toggle(page, { Name = "Farm Pots on Low", Flag = "YF_FarmPots", Callback = function(v) FastMegaFarmPots = v end })
end)

AddTab("13549782519", "Pets", function(page)
    UI.Toggle(page, { Name = "Mega Neon (visual)", Flag = "YF_VisMega", Callback = function(v) VisualVars.Mega = v; if v then VisualVars.Neon = false end; RefreshPetVisuals() end })
    UI.Toggle(page, { Name = "Neon (visual)", Flag = "YF_VisNeon", Callback = function(v) VisualVars.Neon = v; if v then VisualVars.Mega = false end; RefreshPetVisuals() end })
    UI.Toggle(page, { Name = "Fly (visual)", Flag = "YF_VisFly", Callback = function(v) VisualVars.Fly = v end })
    UI.Toggle(page, { Name = "Ride (visual)", Flag = "YF_VisRide", Callback = function(v) VisualVars.Ride = v end })

    UI.Section(page, "Apply")
    UI.Button(page, { Name = "Current Pet", Callback = function()
        if not M.ClientData then return end
        for _, w in pairs(M.ClientData.get("pet_char_wrappers") or {}) do
            if w.player == LP then
                SavedPetVisuals[w.pet_unique] = { Mega = VisualVars.Mega, Neon = VisualVars.Neon, Fly = VisualVars.Fly, Ride = VisualVars.Ride }
                break
            end
        end
        RefreshPetVisuals()
        pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end)
        Notify("Visuals", "Applied")
    end })
    UI.Button(page, { Name = "ALL Pets", Callback = function()
        if not M.ClientData then return end
        local inv = M.ClientData.get("inventory", "Raw")
        if inv and inv.pets then for uid in pairs(inv.pets) do
            SavedPetVisuals[uid] = { Mega = VisualVars.Mega, Neon = VisualVars.Neon, Fly = VisualVars.Fly, Ride = VisualVars.Ride }
        end end
        RefreshPetVisuals()
        pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end)
        Notify("Visuals", "All applied")
    end })
    UI.Button(page, { Name = "Reset", Callback = function()
        SavedPetVisuals = {}
        VisualVars.Mega = false; VisualVars.Neon = false; VisualVars.Fly = false; VisualVars.Ride = false
        RefreshPetVisuals()
        if M.ClientData then pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end) end
        Notify("Visuals", "Reset")
    end })
end)

AddTab("135780702746673", "Shop", function(page)
    UI.Toggle(page, { Name = "Auto-Buy", Flag = "YF_AutoBuy", Callback = function(v) AutoBuyEnabled = v end })
    for k, d in pairs(ShopCatalog) do
        UI.Toggle(page, { Name = d.name .. " ($" .. d.price .. ")", Flag = "YF_Buy_" .. k, Callback = function(v) BuyTargets[k] = v end })
    end
end)

AddTab("9695309046", "Trade", function(page)
    UI.Toggle(page, { Name = "Trade W/F/L Calc", Flag = "YF_TradeCalc", Callback = function(v) tradeCalcEnabled = v end })
    local calc = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Section, Text = "Idle", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.Accent, Parent = page })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = calc })
    Flags.__tradeLbl = calc

    UI.Button(page, { Name = "Get Trade License", Callback = function()
        pcall(function()
            local api = RS:WaitForChild("API")
            if api:FindFirstChild("TradeAPI/BeginQuiz") then
                api["TradeAPI/BeginQuiz"]:InvokeServer()
                for i = 1, 3 do api["TradeAPI/AnswerQuizQuestion"]:InvokeServer(true) end
            end
        end)
        Notify("Trade", "Sent")
    end })
end)

AddTab("7734053495", "Settings", function(page)
    UI.Dropdown(page, { Name = "Theme", Flag = "YF_Theme", Options = { "Yuno", "Dark", "Light", "Galaxy", "Emerald" }, Default = ThemeName, Callback = ApplyTheme })
    UI.Slider(page, { Name = "UI Scale %", Flag = "YF_Scale", Min = 40, Max = 150, Default = math.floor((getgenv().YunoScale or 1) * 100), Callback = function(v)
        getgenv().YunoScale = v / 100; mainScale.Scale = v / 100
    end })
    UI.Button(page, { Name = "Destroy Script", Callback = function()
        if Cac.AilmentPlatform then Cac.AilmentPlatform:Destroy() end
        if screenGui then screenGui:Destroy() end
        if floatBtn then floatBtn:Destroy() end
    end })
end)

if tabs[1] then tabs[1].btn.MouseButton1Click:Fire() end

pcall(function()
    if isfile(CFG_FILE) then
        local d = HttpService:JSONDecode(readfile(CFG_FILE))
        for k, v in pairs(d) do Flags[k] = v end
    end
end)

print("[Yuno] ✅ Tabs built")

-- ══════════════════ INTRO + SHOW UI (GUARANTEED) ══════════════════
mainFrame.Visible = false

local function PlayIntroSafe(cb)
    local ok, err = pcall(function()
        local g = Make("ScreenGui", { Name = "YunoFarm_Intro", IgnoreGuiInset = true, DisplayOrder = 9999, ResetOnSpawn = false })
        pcall(function() g.Parent = CoreGui end)
        if not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end
        local bg = Make("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(8, 10, 16), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = g })
        local box = Make("Frame", { Size = UDim2.new(0, 420, 0, 220), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = bg })
        local yuno = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 90), Position = UDim2.new(0, 0, 0.15, 0), BackgroundTransparency = 1, Text = "YUNO", Font = Enum.Font.GothamBlack, TextSize = 72, TextColor3 = Color3.fromRGB(255,255,255), TextTransparency = 1, Parent = box })
        local line = Make("Frame", { Size = UDim2.new(0, 0, 0, 2), Position = UDim2.new(0.5, 0, 0.55, 0), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Parent = box })
        Instance.new("UIGradient", line).Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(110,170,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(180,130,255)) })
        local farm = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.6, 0), BackgroundTransparency = 1, Text = "F A R M", Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = Color3.fromRGB(140,180,255), TextTransparency = 1, Parent = box })
        local sub = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.85, 0), BackgroundTransparency = 1, Text = "v5.1 • Initializing...", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(120,130,160), TextTransparency = 1, Parent = box })
        Tween(bg, 0.4, { BackgroundTransparency = 0 }); task.wait(0.4)
        Tween(yuno, 0.5, { TextTransparency = 0 }, Enum.EasingStyle.Back); task.wait(0.3)
        Tween(farm, 0.4, { TextTransparency = 0 }); Tween(line, 0.8, { Size = UDim2.new(0, 220, 0, 2) }); task.wait(0.5)
        Tween(sub, 0.4, { TextTransparency = 0 }); task.wait(1.2)
        Tween(yuno, 0.3, { TextTransparency = 1 }); Tween(farm, 0.3, { TextTransparency = 1 }); Tween(sub, 0.3, { TextTransparency = 1 }); Tween(line, 0.3, { Size = UDim2.new(0, 0, 0, 2) }); task.wait(0.35)
        Tween(bg, 0.35, { BackgroundTransparency = 1 }); task.wait(0.4)
        g:Destroy()
    end)
    if not ok then warn("[Yuno] ⚠ Intro error: "..tostring(err)) end
    if cb then pcall(cb) end
end

local introDone = false
task.spawn(function()
    -- Safety timeout: if intro takes > 8s, force-show UI
    task.delay(8, function()
        if not introDone then
            introDone = true
            warn("[Yuno] ⚠ Intro timeout — forcing UI")
            mainFrame.Visible = true
            mainScale.Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1))
        end
    end)
    PlayIntroSafe(function()
        if introDone then return end
        introDone = true
        mainFrame.Visible = true
        local target = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1))
        mainScale.Scale = target * 0.85
        Tween(mainScale, 0.4, { Scale = target }, Enum.EasingStyle.Back)
        Notify("Yuno Farm", "v5.1 loaded ✅", 4)
    end)
end)

print("═══════════════════════════════════════════")
print("[Yuno] ✅ v5.1 READY")
print("[Yuno] ✅ All pet tasks: mystery, pet_me, camping,")
print("        bored, beach_party, salon, school, pizza,")
print("        cat_cafe, sick, play, hungry, thirsty,")
print("        walk, ride, dirty, sleepy, toilet")
print("[Yuno] ✅ Aliases: sad, tired, itchy, smelly, ill...")
print("═══════════════════════════════════════════")