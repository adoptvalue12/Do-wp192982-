--[[
    ╔═══════════════════════════════════════════════════════════╗
    ║   YUNO FARM v6.1 - FLOATING BUTTON + FULL UTILITIES       ║
    ║   All quests (incl. pool_party, adoption_party)           ║
    ║   Quest Claim • Trade License • Open Gifts • Neon Combine ║
    ║   Potion Feeder • RP Clear • 2D Tuesdays • Visual Bucks   ║
    ║   Mini-Games • Obbies • Halloween (auto)                  ║
    ╚═══════════════════════════════════════════════════════════╝
]]

print("═══════════════════════════════════════════")
print("[Yuno v6.1] 🚀 Starting...")
print("═══════════════════════════════════════════")

if not game:IsLoaded() then game.Loaded:Wait() end
if not pcall(function() game:GetService("ReplicatedStorage"):WaitForChild("Fsys", 30) end) then
    warn("[Yuno] ❌ Fsys not found — abort"); return
end

local Players, LP = game:GetService("Players"), game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
local IS_MOBILE = UIS.TouchEnabled or vp.X < 900
if not isfolder("YunoFarm") then pcall(makefolder, "YunoFarm") end
local CFG_FILE = "YunoFarm/config.json"

local vu = game:GetService("VirtualUser")
LP.Idled:Connect(function() vu:CaptureController() vu:ClickButton2(Vector2.new()) end)

-- ══════════════════ MODULE LOADING ══════════════════
local Fsys
do
    local att = 0
    while att < 30 and not Fsys do
        att = att + 1
        local m = RS:FindFirstChild("Fsys")
        if m then
            local ok, r = pcall(function() return require(m) end)
            if ok and r then Fsys = r; break end
        end
        task.wait(1)
    end
end
if not Fsys then warn("[Yuno] ❌ Fsys failed"); return end

local function SafeLoad(n) local ok, m = pcall(function() return Fsys.load(n) end); return ok and m or nil end
local M = {
    RouterClient = SafeLoad("RouterClient"), ClientData = SafeLoad("ClientData"),
    InteriorsM = SafeLoad("InteriorsM"), InventoryDB = SafeLoad("InventoryDB"),
    PetEntityManager = SafeLoad("PetEntityManager"), PetEntityHelper = SafeLoad("PetEntityHelper"),
}
if not M.RouterClient or not M.ClientData then warn("[Yuno] ❌ critical module missing"); return end

local AilmentsClient
pcall(function()
    AilmentsClient = require(RS:WaitForChild("new", 2):WaitForChild("modules", 2)
        :WaitForChild("Ailments", 2):WaitForChild("AilmentsClient", 2))
end)
local MYSTERY_PRIORITY = {"bored", "salon", "school", "camping", "sick", "beach_party", "pizza_party"}

local function SafeGet(e) local ok, r = pcall(function() return M.RouterClient.get(e) end); return ok and r or nil end
local API = {
    Equip = SafeGet("ToolAPI/Equip"), Unequip = SafeGet("ToolAPI/Unequip"),
    ServerUseTool = SafeGet("ToolAPI/ServerUseTool"), DoNeonFusion = SafeGet("PetAPI/DoNeonFusion"),
    ConsumeFoodObject = SafeGet("PetAPI/ConsumeFoodObject"), ExitFurniture = SafeGet("PetAPI/ExitFurnitureUseStates"),
    CreatePetObject = SafeGet("PetObjectAPI/CreatePetObject"), GrabPetObject = SafeGet("PetObjectAPI/GrabPetObject"),
    DropPetObject = SafeGet("PetObjectAPI/DropPetObject"), ProgressPetMe = SafeGet("AilmentsAPI/ProgressPetMeAilment"),
    ChooseMystery = SafeGet("AilmentsAPI/ChooseMysteryAilment"), AddPet = SafeGet("IdleProgressionAPI/AddPet"),
    RemovePet = SafeGet("IdleProgressionAPI/RemovePet"), ClaimProgression = SafeGet("IdleProgressionAPI/CommitAllProgression"),
    BuyItem = SafeGet("ShopAPI/BuyItem"), SetLocation = SafeGet("LocationAPI/SetLocation"),
    UnsubscribeHouse = SafeGet("HousingAPI/UnsubscribeFromHouse"),
    ActivateInterior = SafeGet("HousingAPI/ActivateInteriorFurniture"),
    ActivateFurniture = SafeGet("HousingAPI/ActivateFurniture"),
    ExitSeats = SafeGet("AdoptAPI/ExitSeatStates"), EjectBaby = SafeGet("AdoptAPI/EjectBaby"),
    HoldBaby = SafeGet("AdoptAPI/HoldBaby"), SetPetRP = SafeGet("SettingsAPI/SetPetRoleplayName"),
}
local RawAPI = RS:WaitForChild("API", 15)
local function RawGet(n) return RawAPI and RawAPI:FindFirstChild(n) or nil end
API.HealWithDoctor = RawGet("MonitorAPI/HealWithDoctor")
API.FinishObby = RawGet("MinigameAPI/FinishObby")
API.ClaimDailyReward = RawGet("DailyLoginAPI/ClaimDailyReward")
API.ChooseTeam = RawGet("TeamAPI/ChooseTeam")
API.BeginTradeQuiz = RawGet("TradeAPI/BeginQuiz")
API.AnswerQuiz = RawGet("TradeAPI/AnswerQuizQuestion")
API.ClaimQuest = RawGet("QuestAPI/ClaimQuest")
API.OpenGift = RawGet("ShopAPI/OpenGift")

print("[Yuno] ✅ API ready")

-- ══════════════════ STATE ══════════════════
local Cac = {
    CurrentLocation = nil, AilmentPlatform = nil,
    BedIds = { MainMap = {}, School = {} }, ShowerIds = {},
    StrollerUID = nil, LastStrollerEquip = 0, LastMysteryAttempt = nil,
    PetMeAttempts = {}, MysteryBlacklist = {}, MysteryFails = {},
}
getgenv().YunoCac = Cac

local FarmEnabled, PetFarmEnabled, BabyFarmEnabled = false, false, false
local SWFEnabled, SwfMode, SwfSplitMode, SWFTargets = false, "Regular", false, {}
local AutoHatch, HatchPriority, HatchLimits = false, {}, {}
local ActiveHatchUIDs, HatchedSessionCounts = {}, {}
local AutoAgePot = false
local FastMegaEnabled, FastMegaPipeline, FastMegaPipeMode, FastMegaMode = false, false, "Selected", "Neon"
local FastMegaTargets, FastMegaFarmPots, FastMegaTimer = {}, false, 0
local TaskFailTrack = { time = 0 }

-- Mini-games
local MiniGamesEnabled, AutoObbies = false, false
local AutoSpleef, AutoSimonSays, AutoWinterCastle = false, false, false
local AutoDailyReward, AutoFreeFood = false, false
local ObbiesDone, LastDailyClaim, LastFreeFoodClaim = {}, 0, 0

-- NEW features
local AutoQuestClaim, AutoTradeLicense, AutoOpenGifts = false, false, false
local AutoNeonCombine, CombineQueue, CombineTargetMode = false, {}, "NEON"
local PotionFeederEnabled, FeederSelectedPotions, FeederUntilFG = false, {}, true
local FeederTargetMode = "Equipped"
local Auto2DTuesdays, AutoHalloweenQuests, VisualBucksLoop = false, false, false
local VisualBucksAmount = 1000

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
                elseif Cac.CurrentLocation == nil then Cac.CurrentLocation = "MainMap" end
            end
        end)
    end
end)

-- ══════════ THEMES & UI ══════════
local THEMES = {
    Dark    = { Background=Color3.fromRGB(15,15,20), Sidebar=Color3.fromRGB(20,20,25), Section=Color3.fromRGB(28,28,33), Text=Color3.fromRGB(255,255,255), SubText=Color3.fromRGB(120,120,130), Accent=Color3.fromRGB(255,255,255), Stroke=Color3.fromRGB(45,45,50), ToggleOff=Color3.fromRGB(55,55,60), Knob=Color3.fromRGB(20,20,25) },
    Yuno    = { Background=Color3.fromRGB(12,14,22), Sidebar=Color3.fromRGB(18,21,32), Section=Color3.fromRGB(24,28,42), Text=Color3.fromRGB(240,245,255), SubText=Color3.fromRGB(120,140,170), Accent=Color3.fromRGB(110,170,255), Stroke=Color3.fromRGB(40,48,70), ToggleOff=Color3.fromRGB(45,52,72), Knob=Color3.fromRGB(240,245,255) },
    Galaxy  = { Background=Color3.fromRGB(12,10,20), Sidebar=Color3.fromRGB(18,15,30), Section=Color3.fromRGB(25,20,42), Text=Color3.fromRGB(240,240,255), SubText=Color3.fromRGB(150,140,190), Accent=Color3.fromRGB(110,60,255), Stroke=Color3.fromRGB(50,40,80), ToggleOff=Color3.fromRGB(40,30,70), Knob=Color3.fromRGB(20,15,35) },
    Light   = { Background=Color3.fromRGB(245,245,250), Sidebar=Color3.fromRGB(255,255,255), Section=Color3.fromRGB(235,235,240), Text=Color3.fromRGB(20,20,25), SubText=Color3.fromRGB(100,100,110), Accent=Color3.fromRGB(0,122,255), Stroke=Color3.fromRGB(220,220,230), ToggleOff=Color3.fromRGB(200,200,210), Knob=Color3.fromRGB(255,255,255) },
    Emerald = { Background=Color3.fromRGB(15,22,18), Sidebar=Color3.fromRGB(20,28,22), Section=Color3.fromRGB(26,36,28), Text=Color3.fromRGB(240,255,240), SubText=Color3.fromRGB(130,160,140), Accent=Color3.fromRGB(46,204,113), Stroke=Color3.fromRGB(45,60,50), ToggleOff=Color3.fromRGB(40,55,45), Knob=Color3.fromRGB(20,28,22) },
}
local ThemeName = getgenv().YunoThemeName or "Yuno"
local Theme = THEMES[ThemeName] or THEMES.Yuno
local ThemeObjects, Flags = {}, {}

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
local function Tween(o, d, p, s, dir)
    local t = TS:Create(o, TweenInfo.new(d or 0.25, s or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), p)
    t:Play(); return t
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

-- ══════════ UI PRIMITIVES ══════════
local UI = {}
local screenGui, mainFrame, mainScale, floatBtn, floatScale

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
    local function setState(v, silent)
        state = v; Flags[flag] = v
        Tween(track, 0.25, { BackgroundColor3 = v and Theme.Accent or Theme.ToggleOff })
        Tween(knob, 0.25, { Position = v and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10) }, Enum.EasingStyle.Back)
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
    btn.MouseEnter:Connect(function() Tween(stroke, 0.2, { Color = Theme.Accent }) end)
    btn.MouseLeave:Connect(function() Tween(stroke, 0.2, { Color = Theme.Stroke }) end)
    btn.MouseButton1Click:Connect(function() if cfg.Callback then pcall(cfg.Callback) end end)
    return btn
end

function UI.Section(parent, title)
    return Make("TextLabel", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = title or "Section", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
end

function UI.Slider(parent, cfg)
    cfg = cfg or {}
    local flag = cfg.Flag or cfg.Name
    local minV, maxV = cfg.Min or 0, cfg.Max or 100
    local val = math.clamp(Flags[flag] or cfg.Default or minV, minV, maxV)
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
    local drag = false
    local function update(px)
        local p = math.clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local nv = math.floor(minV + (maxV - minV) * p)
        val = nv; fill.Size = UDim2.new(p, 0, 1, 0); valLbl.Text = tostring(nv); Flags[flag] = nv
        if cfg.Callback then pcall(cfg.Callback, nv) end
    end
    trig.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true; update(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end end)
    UIS.InputChanged:Connect(function(i) if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i.Position.X) end end)
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

-- ══════════ BUILD MAIN UI ══════════
print("[Yuno] ⏳ Building UI...")

screenGui = Make("ScreenGui", { Name = "YunoFarm_UI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Global })
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = LP:WaitForChild("PlayerGui") end

notifyHolder = Make("Frame", { Size = UDim2.new(0, 320, 1, -40), Position = UDim2.new(1, -330, 0, 20), BackgroundTransparency = 1, Parent = screenGui })
Make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), Parent = notifyHolder })

mainFrame = Make("CanvasGroup", { Size = UDim2.new(0, 660, 0, 480), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.05, BorderSizePixel = 0, Parent = screenGui })
Make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = mainFrame })
Make("UIStroke", { Thickness = 1, Color = Theme.Stroke, Transparency = 0.3, Parent = mainFrame })
mainScale = Instance.new("UIScale", mainFrame)
mainScale.Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1))

local titleBar = Make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Sidebar, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = mainFrame })
Make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = titleBar })
Make("ImageLabel", { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 12, 0.5, -13), BackgroundTransparency = 1, Image = "rbxassetid://7733960981", ImageColor3 = Theme.Accent, Parent = titleBar })
Make("TextLabel", { Size = UDim2.new(0, 40, 0, 18), Position = UDim2.new(0, 44, 0, 8), BackgroundTransparency = 1, Text = "Yuno", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })
Make("TextLabel", { Size = UDim2.new(0, 40, 0, 18), Position = UDim2.new(0, 84, 0, 8), BackgroundTransparency = 1, Text = "Farm", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })
Make("TextLabel", { Size = UDim2.new(0, 60, 0, 14), Position = UDim2.new(0, 128, 0, 10), BackgroundTransparency = 1, Text = "v6.1", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })

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

-- ══════════ FLOATING MINIMIZE BUTTON ══════════
floatBtn = Make("TextButton", {
    Size = UDim2.new(0, 56, 0, 56),
    Position = UDim2.new(0.5, -28, 0, 80),
    BackgroundColor3 = Theme.Accent,
    Text = "",
    AutoButtonColor = false,
    Visible = false,
    ZIndex = 500,
    Parent = screenGui,
})
Make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = floatBtn })
local floatStroke = Make("UIStroke", { Thickness = 2, Color = Theme.Accent, Transparency = 0.2, Parent = floatBtn })
Make("ImageLabel", {
    Size = UDim2.new(1, -14, 1, -14),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Image = "rbxassetid://7733960981",
    ImageColor3 = Color3.new(1, 1, 1),
    Parent = floatBtn,
})
floatScale = Instance.new("UIScale", floatBtn)
floatScale.Scale = 1

-- Pulse animation
task.spawn(function()
    while task.wait(1) do
        if not floatBtn or not floatBtn.Parent then break end
        if floatBtn.Visible then
            Tween(floatStroke, 0.5, { Transparency = 0.6, Thickness = 3 })
            task.wait(0.5)
            Tween(floatStroke, 0.5, { Transparency = 0.2, Thickness = 2 })
        end
    end
end)

-- Drag + click behavior
local fDragging, fStart, fPos = false, nil, nil
local fMoved = false
floatBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        fDragging = true
        fMoved = false
        fStart = i.Position
        fPos = floatBtn.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if fDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local delta = i.Position - fStart
        if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then fMoved = true end
        if fMoved then
            floatBtn.Position = UDim2.new(fPos.X.Scale, fPos.X.Offset + delta.X, fPos.Y.Scale, fPos.Y.Offset + delta.Y)
        end
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        if fDragging and not fMoved then
            -- click without drag = restore UI
            floatBtn.Visible = false
            mainFrame.Visible = true
            mainScale.Scale = 0.85
            Tween(mainScale, 0.3, { Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1)) }, Enum.EasingStyle.Back)
        end
        fDragging = false
    end
end)

-- Drag window
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

-- Close = minimize (float button appears)
closeBtn.MouseButton1Click:Connect(function()
    Tween(mainScale, 0.25, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
        mainFrame.Visible = false
        floatBtn.Visible = true
        floatScale.Scale = 0.5
        Tween(floatScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
    end)
end)

-- RightCtrl toggle
UIS.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.RightControl then
        if mainFrame.Visible then
            mainFrame.Visible = false
            floatBtn.Visible = true
            floatScale.Scale = 0.5
            Tween(floatScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
        else
            floatBtn.Visible = false
            mainFrame.Visible = true
            mainScale.Scale = 0.85
            Tween(mainScale, 0.3, { Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1)) }, Enum.EasingStyle.Back)
        end
    end
end)

print("[Yuno] ✅ UI built (floating button enabled)")

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

local AILMENT_ALIASES = {
    sad = "bored", tired = "sleepy", exhausted = "sleepy",
    itchy = "dirty", smelly = "dirty", stinky = "dirty", dirty_pet = "dirty",
    ill = "sick", sick_green = "sick", sick_blue = "sick",
    food = "hungry", food_bowl = "hungry", hungry_special = "hungry",
    water = "thirsty", water_bowl = "thirsty", thirsty_special = "thirsty",
    toy = "play", play_time = "play", bored_special = "bored",
    sleep = "sleepy", bed = "sleepy", shower = "dirty", bath = "dirty",
    mystery_special = "mystery", mystery_box = "mystery",
    pet_me_special = "pet_me", cat = "cat_cafe", cafe = "cat_cafe",
    pizza = "pizza_party", school_quest = "school", salon_quest = "salon",
}
local LoggedUnknown = {}
local function NormalizeAilment(k) return AILMENT_ALIASES[k] or k end
local function LogUnknownAilment(k)
    if LoggedUnknown[k] then return end
    LoggedUnknown[k] = true
    warn("[Yuno] ⚠ Unknown ailment: "..tostring(k))
end
local function GetHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- Furniture
local BED_TYPES = {
    ["sleepingbag"] = { MainMap = true }, ["rectangular_pet_bed"] = { School = true },
    ["FancyPetBed"] = { MainMap = true, School = true }, ["ModernPetBed"] = { MainMap = true, School = true },
    ["CircularPetBed"] = { MainMap = true, School = true }, ["NormalCrib"] = { MainMap = true, School = true },
    ["BasicCrib"] = { MainMap = true, School = true }, ["RoyalCrib"] = { MainMap = true, School = true },
    ["PoshCrib"] = { MainMap = true, School = true },
}
local SHOWER_TYPES = {
    ["camping_shower"] = true, ["StylishShower"] = true, ["CheapBathtub"] = true,
    ["ModernShower"] = true, ["Bathtub"] = true, ["GingerbreadShower"] = true, ["HotTub"] = true,
}

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
            local id = item.id or item.kind
            local bi = BED_TYPES[id]
            if bi then
                if bi.MainMap then table.insert(Cac.BedIds.MainMap, fid) end
                if bi.School then table.insert(Cac.BedIds.School, fid) end
            end
            if SHOWER_TYPES[id] then table.insert(Cac.ShowerIds, fid) end
        end
    end
    return #Cac.BedIds.MainMap, #Cac.BedIds.School, #Cac.ShowerIds
end

local function GetFarmTargets()
    local out = { Baby = {}, Pets = {} }
    if not M.ClientData then return out end
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local am = data.ailments_manager or pd.ailments_manager or M.ClientData.get("ailments_manager")
    if not am then return out end
    if BabyFarmEnabled and am.baby_ailments then
        for _, a in pairs(am.baby_ailments) do
            if a.kind then out.Baby[NormalizeAilment(a.kind)] = true; LogUnknownAilment(a.kind) end
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
                        if a.kind then local n = NormalizeAilment(a.kind); needs[n] = true; LogUnknownAilment(a.kind) end
                    end
                    if next(needs) then
                        table.insert(out.Pets, { uid = w.pet_unique, char = w.char, needs = needs, id = w.pet_id })
                    end
                end
            end
        end
    end
    local bc = 0
    for _ in pairs(out.Baby) do bc = bc + 1 end
    DebugInfo.Pets, DebugInfo.BabyNeeds, DebugInfo.PetNeeds = #out.Pets, bc, #out.Pets
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

-- Platform & TP
local function CreatePlatform(name)
    if not Cac.AilmentPlatform or not Cac.AilmentPlatform.Parent then
        local plat = Instance.new("Part")
        plat.Name = "YunoPlatform"; plat.Anchored = true; plat.CanCollide = true
        plat.Transparency = 0; plat.Size = Vector3.new(2048, 4, 2048)
        plat.CFrame = CFrame.new(-100000, 1000, -100000)
        plat.Color = Color3.fromRGB(80, 200, 120); plat.Parent = Workspace
        CollectionService:AddTag(plat, "YunoPlat")
        Cac.AilmentPlatform = plat
    end
    local plat = Cac.AilmentPlatform
    plat.Name = name
    local origin, offset = nil, Vector3.new(0, 0, 0)
    if name == "Camping" then
        local cs = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("Campsite")
        origin = cs and cs:FindFirstChild("CampsiteOrigin"); offset = Vector3.new(0, -1, 0)
    elseif name == "Playground" then
        local park = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("Park")
        origin = park and park:FindFirstChild("BoredAilmentTarget"); offset = Vector3.new(0, -2.5, 0)
    elseif name == "Beach" then
        local tl = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("TeleportLocations")
        origin = tl and tl:FindFirstChild("exterior_beach"); offset = Vector3.new(0, -10, 0)
    elseif name == "Pool" then
        local p = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("Pool")
        origin = p and p:FindFirstChild("PoolOrigin"); offset = Vector3.new(0, -3, 0)
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
    if (Cac.CurrentLocation or "MainMap") == location then return true end
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
    local s, retried = tick(), false
    while tick() - s < 20 do
        task.wait(0.5)
        if (Cac.CurrentLocation or "MainMap") == location then task.wait(0.5); return true end
        if tick() - s > 8 and not retried then retried = true; send() end
    end
    task.wait(1)
    return (Cac.CurrentLocation or "MainMap") == location
end

-- ══════════════════ TASK FUNCTIONS ══════════════════
local function DoFeedTask(kind)
    local t = GetFarmTargets()
    local foodKind = kind == "hungry" and "apple" or "water"
    local babyN = t.Baby[kind]
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs[kind] then table.insert(pets, p) end end
    if not babyN and #pets == 0 then return true end
    if M.ClientData then
        local money = M.ClientData.get("money") or 0
        if money < 3 and not GetFoodUID(foodKind) then MarkFailed(kind); return false end
    end
    if babyN and API.ServerUseTool then
        local fid = GetFoodUID(foodKind)
        if not fid and API.BuyItem and (M.ClientData.get("money") or 0) >= 5 then
            pcall(function() API.BuyItem:InvokeServer("food", foodKind, { buy_count = 5 }) end)
            task.wait(0.8); fid = GetFoodUID(foodKind)
        end
        if fid then
            local n = kind == "thirsty" and 8 or 3
            for i = 1, n do pcall(function() API.ServerUseTool:InvokeServer(fid, "END") end); task.wait(0.08) end
        end
    end
    if API.CreatePetObject and API.ConsumeFoodObject then
        for _, pet in ipairs(pets) do
            local fid = GetFoodUID(foodKind)
            if not fid and API.BuyItem and (M.ClientData.get("money") or 0) >= 1 then
                pcall(function() API.BuyItem:InvokeServer("food", foodKind, { buy_count = 1 }) end)
                task.wait(0.8); fid = GetFoodUID(foodKind)
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
        if inv and inv.toys then
            for uid, v in pairs(inv.toys) do
                local k = tostring(v.kind or v.id)
                if k == "squeaky_bone_default" or k:find("chew_toy") then toyUid = uid; break end
            end
        end
    end
    if not toyUid then MarkFailed("play"); return false end
    if t.Baby.play and API.ServerUseTool then
        pcall(function() API.ServerUseTool:InvokeServer(toyUid, "END") end); task.wait(0.5)
    end
    if API.CreatePetObject and API.GrabPetObject and API.DropPetObject then
        for _, pet in ipairs(t.Pets) do
            if pet.needs.play and pet.char then
                task.spawn(function()
                    for att = 1, 2 do
                        if not FarmEnabled then break end
                        local ok, obj = pcall(function()
                            return API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_1", { reaction_name = "ThrowToyReaction", unique_id = toyUid, pet_unique = pet.uid })
                        end)
                        local model = obj and (obj:FindFirstChild("Model") or obj)
                        if not model then
                            task.wait(0.15)
                            local po = Workspace:FindFirstChild("PetObjects")
                            if po then for _, c in ipairs(po:GetChildren()) do
                                local iu = c:FindFirstChild("ItemUniqueId")
                                if iu and iu.Value == toyUid then model = c:FindFirstChild("Model") or c; break end
                            end end
                        end
                        if model and pet.char then
                            pcall(function() API.GrabPetObject:FireServer(pet.char, model) end)
                            task.wait(0.3)
                            pcall(function() API.DropPetObject:FireServer(pet.char) end)
                            task.wait(0.4)
                        end
                        task.wait(0.8)
                    end
                end)
                task.wait(0.5)
            end
        end
    end
    local done = WaitForNeedDone("play", 15)
    if done then ClearFailure("play") else MarkFailed("play") end
    return done
end

local function DoSleepDirtyTask(kind)
    local t = GetFarmTargets()
    local isBaby = t.Baby[kind]
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs[kind] then table.insert(pets, p) end end
    if not isBaby and #pets == 0 then return true end

    local location
    if kind == "dirty" then location = "MainMap"
    else location = (Cac.CurrentLocation == "MainMap" or Cac.CurrentLocation == nil) and "MainMap" or "School" end

    TPAllToPlatform(CreatePlatform("Main")); task.wait(0.5)
    if not TP(location) then MarkFailed(kind); return false end
    task.wait(1.5)

    local bm, bs, sh = PopulateFurnitureIDs()
    SetStatus(kind .. " b" .. bm .. "/" .. bs .. " s" .. sh)

    local ids = kind == "sleepy" and Cac.BedIds[location] or Cac.ShowerIds
    if not ids or #ids == 0 then SetStatus(kind .. " NO IDS"); MarkFailed(kind); return false end
    if not API.ActivateInterior then MarkFailed(kind); return false end

    local action = "UseBlock"
    if kind == "sleepy" and location == "MainMap" then action = "Seat2" end

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
                if item.type == "Player" then still = tt.Baby[kind]
                else
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

local function DoSickTask()
    local t = GetFarmTargets()
    local still = t.Baby.sick and true or false
    if not still then for _, p in ipairs(t.Pets) do if p.needs.sick then still = true; break end end end
    if not still then return true end
    if not API.HealWithDoctor then
        if not TP("Hospital") then MarkFailed("sick"); return false end
        task.wait(2)
        if API.ActivateInterior then pcall(function() API.ActivateInterior:InvokeServer("f-14", "UseBlock", "Yes", LP.Character) end) end
        local done = WaitForNeedDone("sick", 30, "Hospital")
        if done then ClearFailure("sick") else MarkFailed("sick") end
        return done
    end
    SetStatus("sick: healing...")
    local s = tick()
    while tick() - s < 30 do
        pcall(function() API.HealWithDoctor:FireServer() end)
        task.wait(1)
        local tt = GetFarmTargets()
        local sn = tt.Baby.sick and true or false
        if not sn then for _, p in ipairs(tt.Pets) do if p.needs.sick then sn = true; break end end end
        if not sn then ClearFailure("sick"); return true end
    end
    MarkFailed("sick"); return false
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

local function DoPoolPartyTask()
    TPAllToPlatform(CreatePlatform("Main")); task.wait(0.5)
    if not TP("MainMap") then MarkFailed("pool_party"); return false end
    task.wait(1)
    local pool = Workspace:FindFirstChild("StaticMap") and Workspace.StaticMap:FindFirstChild("Pool")
    local origin = pool and pool:FindFirstChild("PoolOrigin")
    if not origin then MarkFailed("pool_party"); return false end
    local hrp = GetHRP()
    if hrp then hrp.CFrame = CFrame.new(origin.Position + Vector3.new(0, 5, 0)) end
    task.wait(0.5)
    TPAllToPlatform(CreatePlatform("Pool"))
    local done = WaitForNeedDone("pool_party", 30)
    if done then ClearFailure("pool_party") else MarkFailed("pool_party") end
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
    if Cac.LastMysteryAttempt and os.time() - Cac.LastMysteryAttempt < 3 then return false end
    Cac.LastMysteryAttempt = os.time()
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local petData = (pd.inventory and pd.inventory.pets) or {}
    for _, e in ipairs(pets) do
        local petUID = e.pet.uid
        local petInfo = petData[petUID]
        if petInfo and AilmentsClient and API.ChooseMystery then
            local entityRef = { pet_unique = petUID, pet_id = petInfo.kind or petInfo.id, is_egg = false, is_doll = false, player = LP }
            local mysteryValue
            pcall(function()
                for _, fn in pairs(AilmentsClient) do
                    if type(fn) == "function" then
                        local uvs = debug.getupvalues(fn)
                        if uvs then
                            for _, uv in pairs(uvs) do
                                if type(uv) == "table" then
                                    local pa = rawget(uv, petUID)
                                    if pa and type(pa) == "table" then
                                        local v = rawget(pa, e.kind) or rawget(pa, "mystery")
                                        if v then mysteryValue = v; break end
                                    end
                                end
                            end
                        end
                        if mysteryValue then break end
                    end
                end
            end)
            if mysteryValue and mysteryValue.action and mysteryValue.action.options then
                local gs = mysteryValue.action.options.get_ailment_slots
                local seed = mysteryValue.action.options.random_seed
                if gs and seed then
                    local SetId = (syn and syn.set_thread_identity) or setthreadidentity or setidentity
                    local GetId = (syn and syn.get_thread_identity) or getthreadidentity or getidentity
                    local old = GetId and GetId() or 7
                    if SetId then pcall(SetId, 2) end
                    local ok, slots = pcall(function() return gs(seed, {}, entityRef) end)
                    if SetId then pcall(SetId, old) end
                    if ok and slots and type(slots) == "table" then
                        local pk, pKind
                        for _, easy in ipairs(MYSTERY_PRIORITY) do
                            for k, v in pairs(slots) do if v == easy then pk = k; pKind = easy; break end end
                            if pk then break end
                        end
                        if not pk then for k, v in pairs(slots) do pk = k; pKind = v; break end end
                        if pk and pKind then
                            pcall(function() API.ChooseMystery:FireServer(petUID, e.kind, pk, pKind) end)
                            task.wait(1.2)
                        end
                    end
                end
            end
        end
    end
    local done = WaitForNeedDone("mystery", 10) or WaitForNeedDone("misery", 10)
    if done then ClearFailure("mystery"); ClearFailure("misery")
    else
        for _, e in ipairs(pets) do
            Cac.MysteryFails[e.pet.uid] = (Cac.MysteryFails[e.pet.uid] or 0) + 1
            if Cac.MysteryFails[e.pet.uid] >= 3 then
                Cac.MysteryBlacklist[e.pet.uid] = os.time()
                Cac.MysteryFails[e.pet.uid] = nil
            end
        end
        MarkFailed("mystery")
    end
    return done
end

local function DoPetMeTask()
    local t = GetFarmTargets()
    local processed = false
    local entities
    if M.PetEntityManager and M.PetEntityManager.get_local_owned_pet_entities then
        pcall(function() entities = M.PetEntityManager.get_local_owned_pet_entities() end)
    end
    for _, pet in ipairs(t.Pets) do
        if pet.needs.pet_me then
            if not Cac.PetMeAttempts[pet.uid] or os.time() - Cac.PetMeAttempts[pet.uid] > 10 then
                Cac.PetMeAttempts[pet.uid] = os.time()
                local entity
                if entities then for _, e in pairs(entities) do if e.base and e.base.char_wrapper and e.base.char_wrapper.pet_unique == pet.uid then entity = e; break end end end
                if entity and M.PetEntityHelper and M.PetEntityHelper.stage_performance then
                    pcall(function() M.PetEntityHelper.stage_performance(entity, { name = "FocusPet" }) end); task.wait(0.15)
                end
                if API.ProgressPetMe then pcall(function() API.ProgressPetMe:FireServer(pet.uid) end) end
                if entity and M.PetEntityHelper and M.PetEntityHelper.end_performance then
                    task.wait(0.15)
                    pcall(function() M.PetEntityHelper.end_performance(entity, "FocusPet") end)
                end
                task.wait(1.5); processed = true
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
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not plat or not hum then MarkFailed("walk"); return false end
    local s, angle = tick(), 0
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
        pcall(function() API.Equip:InvokeServer(Cac.StrollerUID) end); task.wait(1)
    end
    local plat = Cac.AilmentPlatform
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    local s, angle = tick(), 0
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
    if platName then TPAllToPlatform(CreatePlatform(platName)); task.wait(1.5) else TPAllToPlatform(CreatePlatform("Main")); task.wait(1) end
    local s = tick()
    while tick() - s < 60 do
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
    rain_puddle = "RainPuddleServer", leaf_pile = "LeafPileServer",
    snow = "SnowPileServer", diving_board = "DivingBoardServer",
}

local function DoWeatherTask(kind)
    local t = GetFarmTargets()
    local targets = {}
    if t.Baby[kind] then table.insert(targets, { type = "Player", char = LP.Character, uid = "BABY" }) end
    for _, pet in ipairs(t.Pets) do
        if pet.needs[kind] and pet.char then table.insert(targets, { type = "Pet", char = pet.char, uid = pet.uid }) end
    end
    if #targets == 0 then return true end
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
    if not TP("MainMap") then MarkFailed(kind); return false end
    task.wait(1.5)
    if not cframe then MarkFailed(kind); return false end
    local plat = CreatePlatform("WeatherPlatform")
    plat.CFrame = cframe * CFrame.new(0, -3.5, 0)
    TPAllToPlatform(plat); task.wait(1.5)
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

-- ══════════════════ MINI-GAMES ══════════════════
local ObbiesList = { "miniworld", "coastal_climb", "shipwreck_bay", "ancient_ruins", "lonelypeak", "pyramid", "tinyisles" }

local function DoAutoObbies()
    if not API.FinishObby then return false end
    SetStatus("Obbies: finishing all...")
    for _, obby in ipairs(ObbiesList) do
        if not FarmEnabled then return false end
        if not ObbiesDone[obby] then
            pcall(function() API.FinishObby:FireServer(obby) end)
            ObbiesDone[obby] = true
            task.wait(0.5)
        end
    end
    SetStatus("Obbies: done")
    return true
end

local function DoSpleefMinigame()
    if Cac.CurrentLocation == "SpleefMinigame" then SetStatus("Spleef: inside"); task.wait(30); return true end
    SetStatus("Spleef: entering...")
    if not TP("SpleefMinigame") then return false end
    task.wait(5); return true
end

local function DoSimonSaysMinigame()
    if Cac.CurrentLocation == "SimonSaysMinigame" then SetStatus("Simon Says: inside"); task.wait(30); return true end
    SetStatus("Simon Says: entering...")
    if not TP("SimonSaysMinigame") then return false end
    task.wait(5); return true
end

local function DoWinterCastle()
    if Cac.CurrentLocation == "WinterCastle" then SetStatus("Winter Castle: inside"); task.wait(30); return true end
    SetStatus("Winter Castle: entering...")
    if not TP("WinterCastle") then return false end
    task.wait(5); return true
end

-- ══════════════════ AUTO DAILY / FREE FOOD ══════════════════
local function DoAutoDailyReward()
    if not API.ClaimDailyReward then return false end
    if os.time() - LastDailyClaim < 3600 then return false end
    LastDailyClaim = os.time()
    SetStatus("Daily: claiming...")
    pcall(function() API.ClaimDailyReward:InvokeServer() end)
    task.wait(1); return true
end

local FREE_FOODS = { "ham_vip", "water_vip", "chocolate_milk_vip", "popcorn_vip", "marshmallow_on_a_stick", "healing_apple", "teachers_apple" }
local function DoAutoFreeFood()
    if not API.BuyItem then return false end
    if os.time() - LastFreeFoodClaim < 300 then return false end
    LastFreeFoodClaim = os.time()
    SetStatus("Free Food: claiming...")
    for _, food in ipairs(FREE_FOODS) do
        pcall(function() API.BuyItem:InvokeServer("food", food, {}) end)
        task.wait(0.3)
    end
    return true
end

-- ══════════════════ NEW: AUTO QUEST CLAIM (from file 4) ══════════════════
local function DoAutoQuestClaim()
    if not API.ClaimQuest then return false end
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return false end
    local qa = pg:FindFirstChild("QuestApp")
    if not qa then return false end
    local board = qa:FindFirstChild("Board")
    local body = board and board:FindFirstChild("Body")
    local contents = body and body:FindFirstChild("Contents")
    local sf = contents and contents:FindFirstChild("ScrollingFrame")
    if not sf then return false end
    local template = sf:FindFirstChild("QuestTemplate")
    if not template then return false end
    local tb = template:FindFirstChild("Body")
    if not tb then return false end
    local qid = tb:GetAttribute("QuestId")
    if qid then
        SetStatus("Quest claim: "..tostring(qid))
        pcall(function() API.ClaimQuest:InvokeServer(tostring(qid)) end)
        task.wait(0.5)
        return true
    end
    return false
end

-- ══════════════════ NEW: AUTO TRADE LICENSE (from file 4) ══════════════════
local function DoTradeLicense()
    if not API.BeginTradeQuiz or not API.AnswerQuiz then return false end
    SetStatus("Trade License: starting quiz...")
    pcall(function() API.BeginTradeQuiz:InvokeServer() end)
    task.wait(0.5)
    local found = false
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "question_index") then
            if v.quiz then
                for _, q in pairs(v.quiz) do
                    if q.answer ~= nil then
                        pcall(function() API.AnswerQuiz:InvokeServer(q.answer) end)
                        found = true
                        task.wait(0.3)
                    end
                end
            end
        end
    end
    if not found then
        for i = 1, 3 do pcall(function() API.AnswerQuiz:InvokeServer(true) end); task.wait(0.4) end
    end
    SetStatus("Trade License: done")
    return true
end

-- ══════════════════ NEW: AUTO OPEN GIFTS (from files 1 & 4) ══════════════════
local function DoAutoOpenGifts()
    if not API.OpenGift or not M.ClientData then return false end
    local inv = M.ClientData.get("inventory", "Raw")
    if not inv or not inv.gifts then return false end
    local any = false
    for uid in pairs(inv.gifts) do
        any = true
        if API.Equip then pcall(function() API.Equip:InvokeServer(uid) end); task.wait(0.4) end
        pcall(function() API.OpenGift:InvokeServer(uid) end)
        task.wait(0.6)
    end
    return any
end

-- ══════════════════ NEW: AUTO NEON COMBINE (from file 1) ══════════════════
local function ProcessNeonCombine()
    if not AutoNeonCombine or not API.DoNeonFusion then return end
    if #CombineQueue == 0 then return end
    local inv = M.ClientData.get("inventory", "Raw")
    if not inv or not inv.pets then return end
    for _, kind in ipairs(CombineQueue) do
        local regular, neon = {}, {}
        for uid, p in pairs(inv.pets) do
            if (p.kind or p.id) == kind then
                local pr = p.properties or {}
                local age = pr.age or 1
                local isN = pr.neon or pr.is_neon
                local isM = pr.mega_neon or pr.is_mega
                if age == 6 and not isN and not isM then table.insert(regular, uid)
                elseif isN and not isM then table.insert(neon, uid) end
            end
        end
        if #regular >= 4 then
            SetStatus("Craft Neon "..kind)
            pcall(function() API.DoNeonFusion:InvokeServer({ regular[1], regular[2], regular[3], regular[4] }) end)
            task.wait(4)
        elseif CombineTargetMode == "MEGA" and #neon >= 4 then
            SetStatus("Craft Mega "..kind)
            pcall(function() API.DoNeonFusion:InvokeServer({ neon[1], neon[2], neon[3], neon[4] }) end)
            task.wait(4)
        end
    end
end

-- ══════════════════ NEW: POTION FEEDER (from file 1) ══════════════════
local function ProcessPotionFeeder()
    if not PotionFeederEnabled then return end
    if not API.CreatePetObject or not API.ConsumeFoodObject then return end
    local inv = M.ClientData.get("inventory", "Raw")
    if not inv then return end
    local eq = M.ClientData.get("equip_manager")
    local equipped = eq and eq.pets and eq.pets[1] and eq.pets[1].unique
    if not equipped then return end
    local petData = inv.pets and inv.pets[equipped]
    if not petData then return end
    local pr = petData.properties or {}
    local age = pr.age or 1
    if FeederUntilFG and age >= 6 then return end

    -- Find a selected potion
    for uid, food in pairs(inv.food or {}) do
        local k = food.kind or food.id
        if FeederSelectedPotions[k] then
            SetStatus("Feeder: "..k)
            pcall(function()
                local obj = API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_2", {
                    pet_unique = equipped, unique_id = uid,
                })
                local model = obj and (obj:FindFirstChild("Model") or obj)
                if not model then
                    local po = Workspace:FindFirstChild("PetObjects")
                    if po then for _, c in ipairs(po:GetChildren()) do
                        local iu = c:FindFirstChild("ItemUniqueId")
                        if iu and iu.Value == uid then model = c:FindFirstChild("Model") or c; break end
                    end end
                end
                if model then API.ConsumeFoodObject:FireServer(model, equipped) end
            end)
            task.wait(2)
            return
        end
    end
end

-- ══════════════════ NEW: CLEAR ALL PET RP NAMES ══════════════════
local function ClearAllPetRPNames()
    if not M.ClientData or not API.SetPetRP then
        Notify("RP Clear", "Remote not found")
        return
    end
    local inv = M.ClientData.get("inventory", "Raw")
    if not inv or not inv.pets then return end
    SetStatus("Clearing RP names...")
    local count = 0
    for uid, p in pairs(inv.pets) do
        local pr = p.properties or {}
        if pr.rp_name and pr.rp_name ~= "" then
            if API.Equip then pcall(function() API.Equip:InvokeServer(uid, { use_sound = false }) end); task.wait(0.15) end
            pcall(function() API.SetPetRP:InvokeServer(uid, "") end)
            count = count + 1
            task.wait(0.1)
        end
    end
    SetStatus("RP cleared: "..count.." pets")
    Notify("RP Clear", "Cleared "..count.." pet names")
end

-- ══════════════════ NEW: AUTO 2D TUESDAYS ══════════════════
local function DoAuto2DTuesdays()
    local adnet = RS:FindFirstChild("adoptme_new_net")
    if not adnet then return false end
    local dm = M.ClientData.get("dailies_manager")
    if not dm or not dm.serialized_tabs then return false end
    local tab = dm.serialized_tabs["2d_tuesdays"]
    if not tab then return false end
    local did = false
    if tab.active_dailies then
        local remote = adnet:FindFirstChild("adoptme_new.modules.Dailies.DailiesNetService:9")
        if remote then
            for _, d in pairs(tab.active_dailies) do
                if d.state and d.state.steps_to_complete <= d.state.steps_completed then
                    pcall(function() remote:FireServer("2d_tuesdays") end)
                    did = true
                    task.wait(0.5)
                end
            end
        end
    end
    if tab.reward_claimed == false then
        local r2 = adnet:FindFirstChild("adoptme_new.modules.Dailies.DailiesNetService:15")
        if r2 then pcall(function() r2:FireServer("2d_tuesdays") end); did = true end
    end
    if did then SetStatus("2D Tuesdays: claimed") end
    return did
end

-- ══════════════════ NEW: AUTO HALLOWEEN QUESTS ══════════════════
local function DoAutoHalloweenQuests()
    local adnet = RS:FindFirstChild("adoptme_new_net")
    if not adnet then return false end
    local dm = M.ClientData.get("dailies_manager")
    if not dm or not dm.serialized_tabs then return false end
    local tab = dm.serialized_tabs["halloween_2026"]
    if not tab then return false end
    local did = false
    if tab.active_dailies then
        local remote = adnet:FindFirstChild("adoptme_new.modules.Dailies.DailiesNetService:9")
        if remote then
            for _, d in pairs(tab.active_dailies) do
                if d.state and d.state.steps_to_complete <= d.state.steps_completed then
                    pcall(function() remote:FireServer("halloween_2026") end)
                    did = true
                    task.wait(0.5)
                end
            end
        end
    end
    if tab.reward_claimed == false then
        local r2 = adnet:FindFirstChild("adoptme_new.modules.Dailies.DailiesNetService:15")
        if r2 then pcall(function() r2:FireServer("halloween_2026") end); did = true end
    end
    if did then SetStatus("Halloween: claimed") end
    return did
end

-- ══════════════════ NEW: VISUAL BUCKS ══════════════════
local function AddVisualBucks(amount)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local bia = pg:FindFirstChild("BucksIndicatorApp")
    if not bia then return end
    local ci = bia:FindFirstChild("CurrencyIndicator")
    if not ci then return end
    local c = ci:FindFirstChild("Container")
    local al = c and c:FindFirstChild("Amount")
    if al then
        local current = tonumber(string.gsub(al.Text, "%D", "")) or 0
        al.Text = tostring(current + amount)
    end
end
getgenv().AddVisualBucks = AddVisualBucks

-- ══════════════════ SWF/HATCH/AGEPOT/FASTMEGA ══════════════════
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
                    local isM, isN = pr.mega_neon or pr.is_mega, pr.neon or pr.is_neon
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
    local available, total = {}, 0
    for uid, p in pairs(inv.pets) do
        if not locked[uid] then
            local k = p.kind or p.id
            local db = M.InventoryDB.pets[k]
            if db and db.is_egg then
                local lim = HatchLimits[k] or 0
                local hat = HatchedSessionCounts[k] or 0
                if lim == 0 or hat < lim then
                    available[k] = available[k] or {}
                    table.insert(available[k], uid); total = total + 1
                end
            end
        end
    end
    if total == 0 then AutoHatch = false; table.clear(ActiveHatchUIDs); return end
    for _, l in pairs(available) do table.sort(l) end
    local ideal = {}
    for _, ap in ipairs(activePets) do
        for k, l in pairs(available) do
            if table.find(l, ap.unique) then
                if #HatchPriority == 0 or table.find(HatchPriority, k) then table.insert(ideal, ap.unique); break end
            end
        end
        if #ideal >= maxSlots then break end
    end
    if #ideal == 0 then
        for _, l in pairs(available) do for _, uid in ipairs(l) do
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
            if inv.pets[uid] then ActiveHatchUIDs[uid] = inv.pets[uid].kind or inv.pets[uid].id end
            if not activeUIDs[uid] and API.Equip then
                pcall(function() API.Equip:InvokeServer(uid, { equip_as_last = (i > 1) }) end); task.wait(1.5)
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
            SetStatus("Craft Neon "..k)
            pcall(function() API.DoNeonFusion:InvokeServer({ g.regular[1], g.regular[2], g.regular[3], g.regular[4] }) end)
            task.wait(4)
        elseif FastMegaMode == "Mega" and #g.neon >= 4 then
            SetStatus("Craft Mega "..k)
            pcall(function() API.DoNeonFusion:InvokeServer({ g.neon[1], g.neon[2], g.neon[3], g.neon[4] }) end)
            task.wait(4)
        end
    end
end

-- ══════════════════ TIMEOUT WRAPPER ══════════════════
local function RunTaskWithTimeout(kind, fn, maxTime)
    maxTime = maxTime or 60
    local done, success = false, false
    local co = coroutine.create(function()
        local ok, res = pcall(fn)
        success = ok and res
        done = true
    end)
    local start = tick()
    while not done and tick() - start < maxTime do
        task.wait(0.3)
        if coroutine.status(co) == "suspended" then
            local ok = coroutine.resume(co)
            if not ok then break end
        end
        if not FarmEnabled then return false end
    end
    if not done then SetStatus(kind .. " TIMEOUT"); MarkFailed(kind); return false end
    return success
end

-- ═══════════════════════════════════════════════
-- MAIN PET LOOP
-- ═══════════════════════════════════════════════
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
                { "mystery",    function() return DoMysteryTask() end },
                { "misery",     function() return DoMysteryTask() end },
                { "pet_me",     function() return DoPetMeTask() end },
                { "camping",    function() return DoQuestTask("camping", "MainMap", "Camping") end },
                { "bored",      function() return DoQuestTask("bored", "MainMap", "Playground") end },
                { "beach_party",function() return DoQuestTask("beach_party", "MainMap", "Beach") end },
                { "pool_party", function() return DoPoolPartyTask() end },                        -- NEW
                { "adoption_party", function() return DoQuestTask("adoption_party", "Nursery") end }, -- NEW
                { "salon",      function() return DoQuestTask("salon", "Salon") end },
                { "school",     function() return DoQuestTask("school", "School") end },
                { "pizza_party",function() return DoQuestTask("pizza_party", "PizzaShop") end },
                { "cat_cafe",   function() return DoQuestTask("cat_cafe", "CatCafe") end },
                { "sick",       function() return DoSickTask() end },
                { "play",       function() return DoPlayTask() end },
                { "hungry",     function() return DoFeedTask("hungry") end },
                { "thirsty",    function() return DoFeedTask("thirsty") end },
                { "walk",       function() return DoWalkTask() end },
                { "ride",       function() return DoRideTask() end },
                { "dirty",      function() return DoSleepDirtyTask("dirty") end },
                { "sleepy",     function() return DoSleepDirtyTask("sleepy") end },
                { "toilet",     function() return DoToiletTask() end },
            }

            for _, e in ipairs(priorities) do
                if has(e[1]) then
                    if CanTry(e[1]) then
                        SetStatus(e[1] .. "...")
                        local ok2 = RunTaskWithTimeout(e[1], e[2], 60)
                        if ok2 then ClearFailure(e[1]) end
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
                    if CanTry(w) then
                        SetStatus(w)
                        RunTaskWithTimeout(w, function() return DoWeatherTask(w) end, 60)
                    end
                    return
                end
            end

            SetStatus("Idle " .. DebugInfo.Pets .. "p " .. DebugInfo.BabyNeeds .. "b")
        end)
        if not ok then SetStatus("Error: " .. tostring(err)) end
    end
end)

-- ══════════ NEW UTILITIES LOOP (Quest/Trade/Gifts/2D/Halloween) ══════════
task.spawn(function()
    while task.wait(3) do
        if not FarmEnabled then continue end
        pcall(function()
            if AutoQuestClaim then DoAutoQuestClaim() end
        end)
    end
end)

task.spawn(function()
    while task.wait(5) do
        if not FarmEnabled then continue end
        pcall(function()
            if AutoOpenGifts then DoAutoOpenGifts() end
        end)
    end
end)

task.spawn(function()
    while task.wait(30) do
        if not FarmEnabled then continue end
        pcall(function()
            if Auto2DTuesdays then DoAuto2DTuesdays() end
            if AutoHalloweenQuests then DoAutoHalloweenQuests() end
        end)
    end
end)

task.spawn(function()
    while task.wait(30) do
        if AutoDailyReward then pcall(DoAutoDailyReward) end
        if AutoFreeFood then pcall(DoAutoFreeFood) end
        if VisualBucksLoop then pcall(function() AddVisualBucks(VisualBucksAmount) end) end
    end
end)

task.spawn(function()
    while task.wait(5) do
        if not MiniGamesEnabled or not FarmEnabled then continue end
        pcall(function()
            if AutoObbies and API.FinishObby then DoAutoObbies() end
            if AutoSpleef then DoSpleefMinigame() end
            if AutoSimonSays then DoSimonSaysMinigame() end
            if AutoWinterCastle then DoWinterCastle() end
        end)
    end
end)

task.spawn(function()
    while task.wait(2.5) do
        if not FarmEnabled then continue end
        pcall(function()
            if AutoHatch then ProcessHatchQueue() end
            if SWFEnabled and not AutoHatch then ProcessSWFQueue() end
            if AutoAgePot then ProcessAgePotQueue() end
            if FastMegaEnabled or FastMegaPipeline then ProcessFastMegaQueue() end
            if AutoNeonCombine then ProcessNeonCombine() end
            if PotionFeederEnabled then ProcessPotionFeeder() end
        end)
    end
end)

-- Watchdog
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

-- ══════════════════ BUILD TABS ══════════════════

AddTab("7733960981", "Home", function(page)
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Yuno Farm v6.1", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = page })
    local sc = Make("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.3, Parent = page })
    Make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = sc })
    local lbl = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1, Text = "Status: Idle", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })
    Flags.__statusLbl = lbl
    local info = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 32), BackgroundTransparency = 1, Text = "-", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })
    local loc = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 50), BackgroundTransparency = 1, Text = "-", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })
    local info2 = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 68), BackgroundTransparency = 1, Text = "-", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })
    local info3 = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 86), BackgroundTransparency = 1, Text = "💡 RightCtrl or click floating ✕ to minimize", Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })

    task.spawn(function()
        while task.wait(1) do
            if not sc.Parent then break end
            info.Text = string.format("🐾 %d pets • 🍼 %d baby", DebugInfo.Pets, DebugInfo.BabyNeeds)
            loc.Text = "Loc: " .. tostring(Cac.CurrentLocation) .. " • Beds: " .. (#Cac.BedIds.MainMap + #Cac.BedIds.School) .. " • Showers: " .. #Cac.ShowerIds
            info2.Text = string.format("🎮 Mini: %s • 📜 Quest: %s", MiniGamesEnabled and "ON" or "OFF", AutoQuestClaim and "ON" or "OFF")
        end
    end)

    UI.Button(page, { Name = "🔄 Refresh Furniture IDs", Callback = function()
        local bm, bs, sh = PopulateFurnitureIDs()
        Notify("Furniture", bm .. " MM / " .. bs .. " School / " .. sh .. " showers")
    end })
end)

AddTab("6908632622", "AutoFarm", function(page)
    UI.Section(page, "Master")
    UI.Toggle(page, { Name = "Farm Master", Flag = "YF_FarmMaster", Description = "Toggle all pet + baby farming", Callback = function(v) FarmEnabled = v; Notify("Yuno", v and "ON" or "OFF") end })
    UI.Toggle(page, { Name = "Pet Farm", Flag = "YF_PetFarm", Description = "Complete pet ailments", Callback = function(v) PetFarmEnabled = v end })
    UI.Toggle(page, { Name = "Baby Farm", Flag = "YF_BabyFarm", Description = "Complete baby needs", Callback = function(v) BabyFarmEnabled = v end })

    UI.Section(page, "Tools")
    UI.Button(page, { Name = "🩹 Force Heal (Sick)", Callback = function()
        if API.HealWithDoctor then
            for i = 1, 5 do pcall(function() API.HealWithDoctor:FireServer() end); task.wait(0.5) end
            Notify("Sick", "Heal sent!")
        else Notify("Sick", "Remote not found") end
    end })
    UI.Button(page, { Name = "Reset Task Failures", Callback = function() TaskFailures = {}; Notify("Yuno", "Cleared") end })
    UI.Button(page, { Name = "Destroy Platform", Callback = function() if Cac.AilmentPlatform then Cac.AilmentPlatform:Destroy(); Cac.AilmentPlatform = nil end end })
end)

AddTab("128557027005598", "Advanced", function(page)
    UI.Section(page, "SWF")
    UI.Toggle(page, { Name = "SWF Enabled", Flag = "YF_SWF", Callback = function(v) SWFEnabled = v end })
    UI.Dropdown(page, { Name = "SWF Mode", Flag = "YF_SWFMode", Options = { "Regular", "Neon" }, Default = "Regular", Callback = function(v) SwfMode = v end })
    UI.Toggle(page, { Name = "Split Mode", Flag = "YF_SWFSplit", Callback = function(v) SwfSplitMode = v end })

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

-- NEW: MINI-GAMES TAB
AddTab("13549782519", "Mini-Games", function(page)
    UI.Section(page, "Auto-Farm Mini-Games")
    UI.Toggle(page, { Name = "Enable Mini-Games", Flag = "YF_MiniMaster", Description = "Master switch for mini-games", Callback = function(v) MiniGamesEnabled = v end })
    UI.Toggle(page, { Name = "Auto Obbies", Flag = "YF_AutoObbies", Description = "Instantly finish all 7 obbies", Callback = function(v) AutoObbies = v; if not v then ObbiesDone = {} end end })
    UI.Toggle(page, { Name = "Auto Spleef", Flag = "YF_Spleef", Description = "Navigate to Spleef", Callback = function(v) AutoSpleef = v end })
    UI.Toggle(page, { Name = "Auto Simon Says", Flag = "YF_SimonSays", Description = "Navigate to Simon Says", Callback = function(v) AutoSimonSays = v end })
    UI.Toggle(page, { Name = "Auto Winter Castle", Flag = "YF_WinterCastle", Description = "Navigate to Winter Castle", Callback = function(v) AutoWinterCastle = v end })

    UI.Section(page, "Quick Actions")
    UI.Button(page, { Name = "🎯 Finish All Obbies", Callback = function()
        if API.FinishObby then DoAutoObbies(); Notify("Obbies", "Sent all!") end
    end })
    UI.Button(page, { Name = "🎮 Enter Spleef Now", Callback = function() task.spawn(DoSpleefMinigame) end })
    UI.Button(page, { Name = "🎮 Enter Simon Says Now", Callback = function() task.spawn(DoSimonSaysMinigame) end })
    UI.Button(page, { Name = "🎮 Enter Winter Castle Now", Callback = function() task.spawn(DoWinterCastle) end })
end)

-- NEW: UTILITIES TAB (from DuskShine file 1 & Adopt-Me file 4)
AddTab("135780702746673", "Utilities", function(page)
    UI.Section(page, "Auto Claim")
    UI.Toggle(page, { Name = "Auto Quest Claim", Flag = "YF_AutoQuest", Description = "Claims finished quests automatically", Callback = function(v) AutoQuestClaim = v end })
    UI.Toggle(page, { Name = "Auto 2D Tuesdays", Flag = "YF_Auto2D", Description = "Claims 2D Kitty tasks + box", Callback = function(v) Auto2DTuesdays = v end })
    UI.Toggle(page, { Name = "Auto Halloween Quests", Flag = "YF_AutoHW", Description = "Claims Halloween dailies (if event)", Callback = function(v) AutoHalloweenQuests = v end })

    UI.Section(page, "Gifts & Trade")
    UI.Toggle(page, { Name = "Auto Open Gifts", Flag = "YF_AutoGifts", Description = "Opens all gifts in inventory", Callback = function(v) AutoOpenGifts = v end })
    UI.Button(page, { Name = "📜 Get Trade License Now", Callback = function()
        task.spawn(function() DoTradeLicense(); Notify("License", "Quiz answered!") end)
    end })

    UI.Section(page, "Pet Utilities")
    UI.Button(page, { Name = "🗑️ Clear All Pet RP Names", Callback = function() task.spawn(ClearAllPetRPNames) end })
    UI.Toggle(page, { Name = "Visual Bucks Loop", Flag = "YF_VisBucks", Description = "Fake display bucks every 30s", Callback = function(v) VisualBucksLoop = v end })

    UI.Section(page, "Auto Neon Combine")
    UI.Toggle(page, { Name = "Auto Neon/Mega", Flag = "YF_AutoNeon", Description = "Fuses x4 FullGrown or x4 Neon", Callback = function(v) AutoNeonCombine = v end })
    UI.Dropdown(page, { Name = "Combine Target", Flag = "YF_CombineMode", Options = { "NEON", "MEGA" }, Default = "NEON", Callback = function(v) CombineTargetMode = v end })

    UI.Section(page, "Potion Feeder")
    UI.Toggle(page, { Name = "Potion Feeder", Flag = "YF_Feeder", Description = "Feeds selected potions to equipped pet", Callback = function(v) PotionFeederEnabled = v end })
    UI.Toggle(page, { Name = "Feed Until FullGrown", Flag = "YF_FeedFG", Description = "Stops when pet is age 6", Default = true, Callback = function(v) FeederUntilFG = v end })
    UI.Toggle(page, { Name = "Feed Age Potion", Flag = "YF_PotAge", Description = "Uses pet_age_potion", Callback = function(v) FeederSelectedPotions["pet_age_potion"] = v end })
    UI.Toggle(page, { Name = "Feed Tiny Age Potion", Flag = "YF_PotTiny", Description = "Uses tiny_pet_age_potion", Callback = function(v) FeederSelectedPotions["tiny_pet_age_potion"] = v end })
    UI.Toggle(page, { Name = "Feed Small Age Potion", Flag = "YF_PotSmall", Description = "Uses small_age_potion", Callback = function(v) FeederSelectedPotions["small_age_potion"] = v end })
    UI.Toggle(page, { Name = "Feed Super Age Potion", Flag = "YF_PotSuper", Description = "Uses super_age_potion", Callback = function(v) FeederSelectedPotions["super_age_potion"] = v end })
end)

-- VISUALS TAB
AddTab("128557027005598", "Visuals", function(page)
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
    UI.Section(page, "Auto-Buy Items")
    UI.Toggle(page, { Name = "Auto Daily Reward", Flag = "YF_AutoDaily", Description = "Claims daily reward every hour", Callback = function(v) AutoDailyReward = v end })
    UI.Toggle(page, { Name = "Auto Free Food", Flag = "YF_AutoFreeFood", Description = "Claims free foods every 5 min", Callback = function(v) AutoFreeFood = v end })
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

-- Show UI
mainFrame.Visible = true
mainScale.Scale = (getgenv().YunoScale or (IS_MOBILE and 0.62 or 1))

task.delay(1, function()
    Notify("Yuno Farm", "v6.1 loaded — floating button + all quests ✅", 5)
end)

print("═══════════════════════════════════════════")
print("[Yuno] ✅ v6.1 READY")
print("[Yuno] ✅ Floating minimize button (draggable)")
print("[Yuno] ✅ All quests: pool_party, adoption_party added")
print("[Yuno] ✅ Auto Quest Claim • Trade License • Open Gifts")
print("[Yuno] ✅ Auto Neon Combine • Potion Feeder • RP Clear")
print("[Yuno] ✅ Auto 2D Tuesdays • Halloween Quests • Visual Bucks")
print("═══════════════════════════════════════════")