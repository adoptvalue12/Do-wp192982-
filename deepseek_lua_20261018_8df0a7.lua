--[[
    ╔══════════════════════════════════════════════════╗
    ║      YUNO FARM v5.0 - FULL AUTOFARM + TRADE      ║
    ║   Platform-first TP • Timeout • Remote Logger    ║
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
local CollectionService = game:GetService("CollectionService")

local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
local IS_MOBILE = UIS.TouchEnabled or vp.X < 900

if not isfolder("YunoFarm") then pcall(makefolder, "YunoFarm") end
local CFG_FILE = "YunoFarm/config.json"
local VAL_FILE = "YunoFarm/values.json"

local vu = game:GetService("VirtualUser")
LP.Idled:Connect(function() vu:CaptureController() vu:ClickButton2(Vector2.new()) end)

-- ══════════════════ API ══════════════════
local Fsys = require(RS:WaitForChild("Fsys", 5))
local M = {
    RouterClient = Fsys.load("RouterClient"),
    ClientData   = Fsys.load("ClientData"),
    InteriorsM   = Fsys.load("InteriorsM"),
    InventoryDB  = Fsys.load("InventoryDB"),
    KindDB       = Fsys.load("KindDB"),
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
    BuyItem = M.RouterClient.get("ShopAPI/BuyItem"),
    SetLocation = M.RouterClient.get("LocationAPI/SetLocation"),
    SubscribeHouse = M.RouterClient.get("HousingAPI/SubscribeToHouse"),
    UnsubscribeHouse = M.RouterClient.get("HousingAPI/UnsubscribeFromHouse"),
    ActivateInterior = M.RouterClient.get("HousingAPI/ActivateInteriorFurniture"),
    BuyFurnitures = M.RouterClient.get("HousingAPI/BuyFurnitures"),
    ExitSeats = M.RouterClient.get("AdoptAPI/ExitSeatStates"),
    EjectBaby = M.RouterClient.get("AdoptAPI/EjectBaby"),
    UseStroller = M.RouterClient.get("AdoptAPI/UseStroller"),
}

-- ══════════════════ CAC ══════════════════
local Cac = {
    CurrentLocation = nil,
    CurrentPlatform = nil,
    AppleUIDs = {},
    WaterUIDs = {},
    BedIds = { MainMap = {}, School = {} },
    ShowerIds = {},
    ToyUID = nil,
    StrollerUID = nil,
    LastStrollerEquip = 0,
    LastMysteryAttempt = nil,
    PetMeAttempts = {},
}
getgenv().YunoCac = Cac

local LiveOpsMap = "MainMap"
pcall(function()
    local ok, Swappable = pcall(function()
        return require(RS:WaitForChild("new", 2):WaitForChild("modules", 2)
            :WaitForChild("InteriorHelpers", 2):WaitForChild("LiveOpsMapSwap", 2)
            :WaitForChild("SwappableInteriors", 2))
    end)
    if ok and Swappable and Swappable.get_current_map_type then
        LiveOpsMap = Swappable.get_current_map_type() or "MainMap"
    end
end)

-- ══════════════════ LOCATION TRACKING ══════════════════
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local loc = M.InteriorsM.get_current_location and M.InteriorsM.get_current_location()
            if loc and loc.id then
                Cac.CurrentLocation = loc.id
                return
            end
            local data = M.ClientData.get_data() or {}
            local pd = data[LP.Name] or {}
            local cw = pd.char_wrapper
            if cw and cw.location and cw.location.destination_id then
                Cac.CurrentLocation = cw.location.destination_id
            elseif Cac.CurrentLocation == nil then
                Cac.CurrentLocation = "MainMap"
            end
        end)
    end
end)

pcall(function()
    local realUpdate = M.ClientData.update_server
    M.ClientData.update_server = function(self, player, event, data)
        if player == LP and event == "char_wrapper" and data and data.location then
            if data.location.destination_id then
                Cac.CurrentLocation = data.location.destination_id
            end
        end
        if realUpdate then return realUpdate(self, player, event, data) end
    end
end)

-- ══════════════════ THEMES ══════════════════
local THEMES = {
    Dark = { Background=Color3.fromRGB(15,15,20), Sidebar=Color3.fromRGB(20,20,25), Section=Color3.fromRGB(28,28,33), Text=Color3.fromRGB(255,255,255), SubText=Color3.fromRGB(120,120,130), Accent=Color3.fromRGB(255,255,255), Stroke=Color3.fromRGB(45,45,50), ToggleOff=Color3.fromRGB(55,55,60), Knob=Color3.fromRGB(20,20,25) },
    Light = { Background=Color3.fromRGB(245,245,250), Sidebar=Color3.fromRGB(255,255,255), Section=Color3.fromRGB(235,235,240), Text=Color3.fromRGB(20,20,25), SubText=Color3.fromRGB(100,100,110), Accent=Color3.fromRGB(0,122,255), Stroke=Color3.fromRGB(220,220,230), ToggleOff=Color3.fromRGB(200,200,210), Knob=Color3.fromRGB(255,255,255) },
    Amethyst = { Background=Color3.fromRGB(20,10,15), Sidebar=Color3.fromRGB(25,15,22), Section=Color3.fromRGB(33,20,30), Text=Color3.fromRGB(230,215,235), SubText=Color3.fromRGB(130,110,140), Accent=Color3.fromRGB(210,180,230), Stroke=Color3.fromRGB(50,35,55), ToggleOff=Color3.fromRGB(60,45,65), Knob=Color3.fromRGB(25,15,22) },
    Galaxy = { Background=Color3.fromRGB(12,10,20), Sidebar=Color3.fromRGB(18,15,30), Section=Color3.fromRGB(25,20,42), Text=Color3.fromRGB(240,240,255), SubText=Color3.fromRGB(150,140,190), Accent=Color3.fromRGB(110,60,255), Stroke=Color3.fromRGB(50,40,80), ToggleOff=Color3.fromRGB(40,30,70), Knob=Color3.fromRGB(20,15,35) },
    Emerald = { Background=Color3.fromRGB(15,22,18), Sidebar=Color3.fromRGB(20,28,22), Section=Color3.fromRGB(26,36,28), Text=Color3.fromRGB(240,255,240), SubText=Color3.fromRGB(130,160,140), Accent=Color3.fromRGB(46,204,113), Stroke=Color3.fromRGB(45,60,50), ToggleOff=Color3.fromRGB(40,55,45), Knob=Color3.fromRGB(20,28,22) },
    BlueDeepWave = { Background=Color3.fromRGB(10,15,25), Sidebar=Color3.fromRGB(15,22,35), Section=Color3.fromRGB(22,30,48), Text=Color3.fromRGB(235,245,255), SubText=Color3.fromRGB(120,140,180), Accent=Color3.fromRGB(0,170,255), Stroke=Color3.fromRGB(40,50,75), ToggleOff=Color3.fromRGB(35,45,65), Knob=Color3.fromRGB(15,22,35) },
    Yuno = { Background=Color3.fromRGB(12,14,22), Sidebar=Color3.fromRGB(18,21,32), Section=Color3.fromRGB(24,28,42), Text=Color3.fromRGB(240,245,255), SubText=Color3.fromRGB(120,140,170), Accent=Color3.fromRGB(110,170,255), Stroke=Color3.fromRGB(40,48,70), ToggleOff=Color3.fromRGB(45,52,72), Knob=Color3.fromRGB(240,245,255) },
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

-- ══════════════════ REMOTE LOGGER ══════════════════
local RemoteLog = {}
local RemoteLogEnabled = false
local RemoteLogHooked = false

local function AddLogEntry(entry)
    table.insert(RemoteLog, 1, entry)
    if #RemoteLog > 300 then table.remove(RemoteLog) end
    if Flags.__logLbl and Flags.__logLbl.Parent then
        Flags.__logLbl.Text = table.concat(RemoteLog, "\n")
    end
end

local function StartRemoteLogger()
    if RemoteLogHooked then return end
    RemoteLogHooked = true
    local mt = getrawmetatable and getrawmetatable(game)
    if not mt then warn("[Yuno] Cannot hook remotes"); return end
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if RemoteLogEnabled and (method == "FireServer" or method == "InvokeServer") then
            pcall(function()
                local p = self.Parent
                local pname = p and p.Name or "?"
                local nname = self.Name
                if pname == "API" or pname == "adoptme_new_net" or
                   nname:find("Ailment") or nname:find("Housing") or
                   nname:find("Pet") or nname:find("Trade") or
                   nname:find("Shop") or nname:find("Tool") then
                    local args = {...}
                    local str = ""
                    for _, v in ipairs(args) do
                        local tv = typeof(v)
                        if tv == "table" then str = str .. " {t}"
                        elseif tv == "Instance" then str = str .. " " .. v.ClassName
                        elseif tv == "CFrame" then str = str .. " CFrame"
                        elseif tv == "Vector3" then str = str .. " Vector3"
                        elseif tv == "EnumItem" then str = str .. " " .. tostring(v)
                        else
                            local s = tostring(v)
                            if #s > 40 then s = s:sub(1, 40) .. "..." end
                            str = str .. " " .. s
                        end
                    end
                    AddLogEntry(string.format("[%s] %s.%s(%s)",
                        os.date("%H:%M:%S"), pname, nname, str))
                end
            end)
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
    print("[Yuno] Remote logger hooked")
end

local function CopyRemoteLog()
    if #RemoteLog == 0 then return "Log empty" end
    local txt = table.concat(RemoteLog, "\n")
    if setclipboard then
        pcall(setclipboard, txt); return "Copied " .. #RemoteLog .. " entries"
    elseif toclipboard then
        pcall(toclipboard, txt); return "Copied " .. #RemoteLog .. " entries"
    end
    return "No clipboard available"
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
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1, Text = title or "Yuno", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = bg })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 30), Position = UDim2.new(0, 15, 0, 32), BackgroundTransparency = 1, Text = msg or "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = bg })
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
    Make("TextLabel", { Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0, 15, 0, 0), BackgroundTransparency = 1, Text = cfg.Name or "Input", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
    local box = Make("Frame", { Size = UDim2.new(0.55, -30, 0, 30), Position = UDim2.new(0.45, 15, 0.5, -15), BackgroundColor3 = Theme.Sidebar, Parent = card })
    Make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = box })
    local input = Make("TextBox", { Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = tostring(val), PlaceholderText = cfg.Placeholder or "Enter...", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
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

function UI.Section(parent, title)
    return Make("TextLabel", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = title or "Section", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
end

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
Make("TextLabel", { Size = UDim2.new(0, 40, 0, 14), Position = UDim2.new(0, 128, 0, 10), BackgroundTransparency = 1, Text = "v5.0", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar })

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
    local sub = Make("TextLabel", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.85, 0), BackgroundTransparency = 1, Text = "v5.0 • Initializing...", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(120,130,160), TextTransparency = 1, Parent = box })
    Tween(bg, 0.4, { BackgroundTransparency = 0 }); task.wait(0.4)
    Tween(yuno, 0.5, { TextTransparency = 0 }, Enum.EasingStyle.Back); task.wait(0.3)
    Tween(farm, 0.4, { TextTransparency = 0 }); Tween(line, 0.8, { Size = UDim2.new(0, 220, 0, 2) }); task.wait(0.5)
    Tween(sub, 0.4, { TextTransparency = 0 }); task.wait(1.6)
    Tween(yuno, 0.3, { TextTransparency = 1 }); Tween(farm, 0.3, { TextTransparency = 1 }); Tween(sub, 0.3, { TextTransparency = 1 }); Tween(line, 0.3, { Size = UDim2.new(0, 0, 0, 2) }); task.wait(0.35)
    Tween(bg, 0.35, { BackgroundTransparency = 1 }); task.wait(0.4)
    g:Destroy(); if cb then cb() end
end

-- ═══════════════════════════════════════════════════
--   AUTOFARM v5.0
-- ═══════════════════════════════════════════════════
local FarmEnabled = false
local PetFarmEnabled = false
local BabyFarmEnabled = false
local lastStatus = ""
local DebugInfo = { Pets = 0, BabyNeeds = 0, PetNeeds = 0, LastError = "" }

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

-- PLATFORM SYSTEM
local function GetHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function CreatePlatform(name)
    if not Cac.CurrentPlatform or not Cac.CurrentPlatform.Parent then
        local part = Instance.new("Part")
        part.Name = "YunoPlatform"
        part.Anchored = true
        part.Size = Vector3.new(200, 5, 200)
        part.Transparency = 1
        part.CanCollide = true
        part.Parent = Workspace:FindFirstChild("Terrain") or Workspace
        CollectionService:AddTag(part, "YunoPlat")
        Cac.CurrentPlatform = part
    end
    local plat = Cac.CurrentPlatform
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
        local sm = Workspace:FindFirstChild("StaticMap")
        local interact = sm and sm:FindFirstChild("Interactables")
        if interact then
            for _, c in ipairs(interact:GetDescendants()) do
                if c.Name:find("AilmentsRefresh2024FireHydrant") then
                    origin = c:FindFirstChild("Center") or c
                    break
                end
            end
        end
        offset = Vector3.new(0, -4, 0)
    elseif name == "RainPuddle" then
        local sm = Workspace:FindFirstChild("StaticMap")
        local rp = sm and sm:FindFirstChild("RainPuddles")
        origin = rp and rp:FindFirstChild("RainPuddle")
        offset = Vector3.new(0, -3.5, 0)
    end

    local loc = Cac.CurrentLocation
    if loc == "Salon" or loc == "School" or loc == "PizzaShop" or loc == "Hospital" or loc == "CatCafe" then
        plat.Position = Vector3.new(0, 15, 0)
    elseif name == "Main" then
        plat.Position = Vector3.new(2270 + math.random(-40,40), 4780 + math.random(-40,40), -2310 + math.random(-40,40))
    elseif not origin then
        plat.Position = Vector3.new(2270, 4780, -2310)
    elseif name == "Toilet" or name == "RainPuddle" then
        plat.Position = origin.Position + offset
    else
        plat.Position = origin.Position + offset + Vector3.new(math.random(-4,4), 0, math.random(-4,4))
    end
    return plat
end

local function TeleportAllToPlatform(plat)
    local hrp = GetHRP()
    if not hrp or not plat then return end
    hrp.CFrame = CFrame.new(plat.Position + Vector3.new(0, 6, 0))
    for _, w in pairs(M.ClientData.get("pet_char_wrappers") or {}) do
        if (w.player == LP or tostring(w.player) == LP.Name) and w.char and w.char:IsA("Model") then
            w.char:PivotTo(hrp.CFrame * CFrame.new(math.random(-4,4), 0, math.random(-1,1)))
        end
    end
end

local function DestroyPlatforms()
    for _, p in pairs(CollectionService:GetTagged("YunoPlat")) do
        if p ~= Cac.CurrentPlatform then p:Destroy() end
    end
end

-- TP FIXED
local function TP(location, door)
    local curr = Cac.CurrentLocation or "MainMap"
    if curr == location then return true end

    if Cac.CurrentLocation == "housing" then
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

    local start = tick()
    local retried = false
    while tick() - start < 20 do
        task.wait(0.5)
        local c = Cac.CurrentLocation or "MainMap"
        if c == location then task.wait(0.5); return true end
        if tick() - start > 8 and not retried then retried = true; send() end
    end
    task.wait(1)
    return (Cac.CurrentLocation or "MainMap") == location
end

-- FURNITURE IDS
local function PopulateFurnitureIDs(retries)
    retries = retries or 10
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

-- TARGETS
local function GetFarmTargets()
    local out = { Baby = {}, Pets = {} }
    local data = M.ClientData.get_data() or {}
    local pd = data[LP.Name] or {}
    local am = data.ailments_manager or pd.ailments_manager or M.ClientData.get("ailments_manager")
    if not am then DebugInfo.Pets, DebugInfo.BabyNeeds, DebugInfo.PetNeeds = 0, 0, 0; return out end

    if BabyFarmEnabled and am.baby_ailments then
        for _, a in pairs(am.baby_ailments) do if a.kind then out.Baby[a.kind] = true end end
    end

    if PetFarmEnabled then
        local wrappers = data.pet_char_wrappers or pd.pet_char_wrappers or M.ClientData.get("pet_char_wrappers")
        if wrappers then
            for _, w in pairs(wrappers) do
                if (w.player == LP or tostring(w.player) == LP.Name) then
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
        if not still then
            for _, p in ipairs(t.Pets) do if p.needs[kind] then still = true; break end end
        end
        if not still then return true end
    end
    return false
end

local function IsSitting(t, uid)
    local data = M.ClientData.get_data() or {}
    local sm = (t == "Player") and data.state_manager or (data.pet_state_managers and data.pet_state_managers[uid])
    if not sm then return false end
    if sm.is_sitting then return true end
    if sm.states then for _, st in pairs(sm.states) do if st.id == "UseFurniture" then return true end end end
    return false
end

-- FOOD HELPERS
local function GetFoodUID(kind)
    local inv = M.ClientData.get("inventory", "Raw")
    if not inv or not inv.food then return nil end
    local list = {}
    for uid, v in pairs(inv.food) do if v.id == kind or v.kind == kind then table.insert(list, uid) end end
    table.sort(list); return list[1]
end

local function BuyFood(kind, count)
    local money = M.ClientData.get("money") or 0
    if money < count then return false end
    pcall(function() API.BuyItem:InvokeServer("food", kind, { buy_count = count }) end)
    task.wait(0.8); return true
end

local function FeedPetWithFood(petUid, foodUid)
    pcall(function()
        local obj = API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_2", { pet_unique = petUid, unique_id = foodUid })
        local model = obj and (obj:FindFirstChild("Model") or obj)
        if not model then
            local po = Workspace:FindFirstChild("PetObjects")
            if po then for _, c in ipairs(po:GetChildren()) do
                local iu = c:FindFirstChild("ItemUniqueId")
                if iu and iu.Value == foodUid then model = c:FindFirstChild("Model") or c; break end
            end end
        end
        if model then API.ConsumeFoodObject:FireServer(model, petUid) end
    end)
end

-- FEED
local function DoFeedTask(kind)
    local t = GetFarmTargets()
    local foodKind = kind == "hungry" and "apple" or "water"
    local babyN = t.Baby[kind]
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs[kind] then table.insert(pets, p) end end
    if not babyN and #pets == 0 then return true end

    if babyN then
        local fid = GetFoodUID(foodKind)
        if not fid then BuyFood(foodKind, 5); fid = GetFoodUID(foodKind) end
        if fid then
            local n = kind == "thirsty" and 8 or 3
            for i = 1, n do
                pcall(function() API.ServerUseTool:InvokeServer(fid, "END") end)
                task.wait(0.08)
            end
        end
    end
    for _, pet in ipairs(pets) do
        local fid = GetFoodUID(foodKind)
        if not fid then BuyFood(foodKind, 1); fid = GetFoodUID(foodKind) end
        if fid then FeedPetWithFood(pet.uid, fid); task.wait(0.5) end
    end
    local done = WaitForNeedDone(kind, 15)
    if done then ClearFailure(kind) else MarkFailed(kind) end
    return done
end

-- PLAY
local function DoPlayTask()
    local t = GetFarmTargets()
    local toyUid
    local inv = M.ClientData.get("inventory", "Raw")
    if inv and inv.toys then for uid, v in pairs(inv.toys) do
        local k = tostring(v.kind or v.id)
        if k == "squeaky_bone_default" or k:find("chew_toy") then toyUid = uid; break end
    end end
    if not toyUid then MarkFailed("play"); return false end

    if t.Baby.play then
        pcall(function() API.ServerUseTool:InvokeServer(toyUid, "END") end)
        task.wait(0.5)
    end
    for _, pet in ipairs(t.Pets) do
        if pet.needs.play and pet.char then
            pcall(function()
                local obj = API.CreatePetObject:InvokeServer("__Enum_PetObjectCreatorType_1", {
                    reaction_name = "ThrowToyReaction", unique_id = toyUid, pet_unique = pet.uid,
                })
                local model = obj and (obj:FindFirstChild("Model") or obj)
                if model then
                    API.GrabPetObject:FireServer(pet.char, model)
                    task.wait(0.3)
                    API.DropPetObject:FireServer(pet.char)
                end
            end)
            task.wait(0.6)
        end
    end
    local done = WaitForNeedDone("play", 15)
    if done then ClearFailure("play") else MarkFailed("play") end
    return done
end

-- SLEEP / DIRTY (PLATFORM FIRST - FULL FIX)
local function DoSleepDirtyTask(kind)
    local t = GetFarmTargets()
    local isBaby = t.Baby[kind]
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs[kind] then table.insert(pets, p) end end
    if not isBaby and #pets == 0 then return true end

    -- Location
    local location
    if kind == "dirty" then
        location = "MainMap"
    else
        location = (Cac.CurrentLocation == "MainMap" or Cac.CurrentLocation == nil) and "MainMap" or "School"
    end

    -- ⚡ FIX: TP platform AVANT location (logique fichier original V829)
    TeleportAllToPlatform(CreatePlatform("Main"))
    task.wait(0.5)

    if not TP(location) then MarkFailed(kind); return false end
    task.wait(1.5)
    DestroyPlatforms()

    -- ⚡ FIX: Populate IDs avec retry
    local bm, bs, sh = PopulateFurnitureIDs()
    SetStatus(kind .. ": b" .. bm .. "/" .. bs .. " s" .. sh)

    local ids = (kind == "sleepy") and Cac.BedIds[location] or Cac.ShowerIds
    if not ids or #ids == 0 then
        SetStatus(kind .. ": NO IDS")
        MarkFailed(kind); return false
    end

    -- ⚡ FIX: Seat2 pour baby à MainMap, UseBlock sinon
    local action = (kind == "sleepy" and location == "MainMap") and "Seat2" or "UseBlock"

    local toProcess = {}
    if isBaby and LP.Character then
        table.insert(toProcess, { type = "Player", char = LP.Character, uid = "BABY", completed = false })
    end
    for _, pet in ipairs(pets) do
        if pet.char then
            table.insert(toProcess, { type = "Pet", char = pet.char, uid = pet.uid, completed = false })
        end
    end

    local gStart = tick()
    for i, item in ipairs(toProcess) do
        task.spawn(function()
            local char = item.char
            local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
            if not hrp then return end
            hrp.Anchored = true
            local idx = i
            while not item.completed and (tick() - gStart) < 45 do
                if not FarmEnabled then break end
                if (Cac.CurrentLocation or "MainMap") ~= location then break end
                if IsSitting(item.type, item.uid) then task.wait(2) else
                    local fid = ids[(idx - 1) % #ids + 1]
                    idx = idx + 1
                    pcall(function() API.ActivateInterior:InvokeServer(fid, action, { cframe = hrp.CFrame }, char) end)
                    task.wait(1.5)
                end
                local tt = GetFarmTargets()
                local still
                if item.type == "Player" then still = tt.Baby[kind] else
                    still = false
                    for _, p in ipairs(tt.Pets) do if p.uid == item.uid and p.needs[kind] then still = true; break end end
                end
                if not still then item.completed = true; break end
            end
            hrp.Anchored = false
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
            pcall(function() API.ExitSeats:FireServer() end)
            local hum = item.char and item.char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Sit = false; hum.Jump = true end
        else task.spawn(function() pcall(function() API.ExitFurniture:InvokeServer(item.uid) end) end) end
    end

    task.wait(1)
    local done = WaitForNeedDone(kind, 5)
    if done then ClearFailure(kind) else MarkFailed(kind) end
    return done
end

-- TOILET
local function DoToiletTask()
    TeleportAllToPlatform(CreatePlatform("Main"))
    task.wait(0.5)
    if not TP("MainMap") then MarkFailed("toilet"); return false end
    task.wait(0.5)
    TeleportAllToPlatform(CreatePlatform("Toilet"))
    task.wait(1)

    local sm = Workspace:FindFirstChild("StaticMap")
    local interact = sm and sm:FindFirstChild("Interactables")
    if not interact then MarkFailed("toilet"); return false end
    local hydrant
    for _, c in ipairs(interact:GetDescendants()) do
        if c.Name:find("AilmentsRefresh2024FireHydrant") then hydrant = c; break end
    end
    if not hydrant then MarkFailed("toilet"); return false end

    local fid, p = nil, hydrant
    while p do local m = p.Name:match("f%-%d+"); if m then fid = m; break end; p = p.Parent end

    if fid and LP.Character then
        pcall(function() API.ActivateInterior:InvokeServer(fid, "UseBlock", { cframe = LP.Character:GetPivot() }, LP.Character) end)
    end
    local done = WaitForNeedDone("toilet", 25, "MainMap")
    DestroyPlatforms()
    if done then ClearFailure("toilet") else MarkFailed("toilet") end
    return done
end

-- SICK
local function DoSickTask()
    TeleportAllToPlatform(CreatePlatform("Main"))
    task.wait(0.5)
    if not TP("Hospital") then MarkFailed("sick"); return false end
    task.wait(2)
    DestroyPlatforms()
    pcall(function() API.ActivateInterior:InvokeServer("f-14", "UseBlock", "Yes", LP.Character) end)
    local done = WaitForNeedDone("sick", 30, "Hospital")
    if done then ClearFailure("sick") else MarkFailed("sick") end
    return done
end

-- MYSTERY (multiple combos + misery)
local function DoMysteryTask()
    local t = GetFarmTargets()
    local pets = {}
    for _, p in ipairs(t.Pets) do
        if p.needs.mystery or p.needs.misery then
            table.insert(pets, { pet = p, kind = p.needs.mystery and "mystery" or "misery" })
        end
    end
    if #pets == 0 then return true end
    if Cac.LastMysteryAttempt and os.time() - Cac.LastMysteryAttempt < 5 then return false end
    Cac.LastMysteryAttempt = os.time()

    local combos = {
        { 1, "bored" }, { 1, "sad" }, { 1, "misery" },
        { "mystery", "bored" }, { 2, "bored" }, { 3, "bored" },
    }
    for _, e in ipairs(pets) do
        for _, c in ipairs(combos) do
            pcall(function() API.ChooseMystery:FireServer(e.pet.uid, e.kind, c[1], c[2]) end)
            task.wait(0.3)
        end
        task.wait(0.5)
    end
    local done = WaitForNeedDone("mystery", 12) or WaitForNeedDone("misery", 12)
    if done then ClearFailure("mystery"); ClearFailure("misery") else MarkFailed("mystery") end
    return done
end

-- PET ME (stage_performance)
local function DoPetMeTask()
    local t = GetFarmTargets()
    local processed = false
    local entities = nil
    pcall(function() entities = M.PetEntityManager.get_local_owned_pet_entities() end)

    for _, pet in ipairs(t.Pets) do
        if pet.needs.pet_me then
            if not Cac.PetMeAttempts[pet.uid] or os.time() - Cac.PetMeAttempts[pet.uid] > 10 then
                Cac.PetMeAttempts[pet.uid] = os.time()
                local entity
                if entities then for _, e in pairs(entities) do
                    if e.base and e.base.char_wrapper and e.base.char_wrapper.pet_unique == pet.uid then entity = e; break end
                end end
                if entity then
                    pcall(function() M.PetEntityHelper.stage_performance(entity, { name = "FocusPet" }) end)
                    task.wait(0.15)
                end
                pcall(function() API.ProgressPetMe:FireServer(pet.uid) end)
                if entity then
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

-- QUEST (V952 port)
local function DoQuestTask(kind, loc, platLoc)
    TeleportAllToPlatform(CreatePlatform("Main"))
    task.wait(0.5)
    if not TP(loc) then MarkFailed(kind); return false end
    task.wait(1.5)
    DestroyPlatforms()

    if platLoc then
        TeleportAllToPlatform(CreatePlatform(platLoc))
        task.wait(1.5)
    else
        TeleportAllToPlatform(CreatePlatform("Main"))
        task.wait(1)
    end

    local s = tick()
    while tick() - s < 60 do
        task.wait(2)
        if not FarmEnabled then break end
        if (Cac.CurrentLocation or "MainMap") ~= loc then break end
        if not Cac.CurrentPlatform or not Cac.CurrentPlatform.Parent then
            if platLoc then TeleportAllToPlatform(CreatePlatform(platLoc)) else TeleportAllToPlatform(CreatePlatform("Main")) end
        end
        local t = GetFarmTargets()
        local still = t.Baby[kind] and true or false
        if not still then for _, p in ipairs(t.Pets) do if p.needs[kind] then still = true; break end end end
        if not still then break end
    end
    local done = WaitForNeedDone(kind, 5)
    DestroyPlatforms()
    if done then ClearFailure(kind) else MarkFailed(kind) end
    return done
end

-- WALK
local function DoWalkTask()
    local t = GetFarmTargets()
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs.walk then table.insert(pets, p) end end
    if not t.Baby.walk and #pets == 0 then return true end

    TeleportAllToPlatform(CreatePlatform("Main"))
    task.wait(0.5)
    if not TP("MainMap") then MarkFailed("walk"); return false end
    task.wait(1)
    TeleportAllToPlatform(CreatePlatform("Main"))
    task.wait(1)

    local plat = Cac.CurrentPlatform
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not plat or not hrp or not hum then MarkFailed("walk"); return false end

    local s = tick(); local angle = 0
    while tick() - s < 60 do
        task.wait(0.15)
        if not FarmEnabled then break end
        local tt = GetFarmTargets()
        local still = tt.Baby.walk and true or false
        if not still then for _, p in ipairs(tt.Pets) do if p.needs.walk then still = true; break end end end
        if not still then break end
        angle = angle + 0.12
        local r = 30 + math.sin(angle * 4) * 15
        hum:MoveTo(plat.Position + Vector3.new(math.cos(angle) * r, 6, math.sin(angle) * r))
    end
    local done = WaitForNeedDone("walk", 10)
    if done then ClearFailure("walk") else MarkFailed("walk") end
    return done
end

-- RIDE
local function DoRideTask()
    local t = GetFarmTargets()
    local pets = {}
    for _, p in ipairs(t.Pets) do if p.needs.ride then table.insert(pets, p) end end
    if not t.Baby.ride and #pets == 0 then return true end

    TeleportAllToPlatform(CreatePlatform("Main"))
    task.wait(0.5)
    if not TP("MainMap") then MarkFailed("ride"); return false end
    task.wait(1)
    TeleportAllToPlatform(CreatePlatform("Main"))
    task.wait(1)

    if not Cac.StrollerUID then
        local inv = M.ClientData.get("inventory", "Raw")
        if inv and inv.strollers then for uid, v in pairs(inv.strollers) do
            if (v.kind or v.id) == "stroller-default" then Cac.StrollerUID = uid; break end
        end end
    end
    if Cac.StrollerUID and os.time() - Cac.LastStrollerEquip > 3 then
        Cac.LastStrollerEquip = os.time()
        pcall(function() API.Equip:InvokeServer(Cac.StrollerUID) end)
        task.wait(1)
    end

    local plat = Cac.CurrentPlatform
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    local s = tick(); local angle = 0
    while tick() - s < 60 do
        task.wait(0.15)
        if not FarmEnabled then break end
        local tt = GetFarmTargets()
        local still = tt.Baby.ride and true or false
        if not still then for _, p in ipairs(tt.Pets) do if p.needs.ride then still = true; break end end end
        if not still then break end
        if plat and hrp and hum then
            angle = angle + 0.1
            local r = 30 + math.sin(angle * 4) * 15
            hum:MoveTo(plat.Position + Vector3.new(math.cos(angle) * r, 6, math.sin(angle) * r))
        end
    end
    if Cac.StrollerUID then pcall(function() API.Unequip:InvokeServer(Cac.StrollerUID) end) end
    local done = WaitForNeedDone("ride", 10)
    if done then ClearFailure("ride") else MarkFailed("ride") end
    return done
end

-- TIMEOUT WRAPPER
local function RunWithTimeout(kind, fn, timeout)
    timeout = timeout or 60
    local done, success = false, false
    local co = coroutine.create(function() success = fn(); done = true end)
    local s = tick()
    while not done and tick() - s < timeout do
        task.wait(0.3)
        if coroutine.status(co) == "suspended" then
            local ok = coroutine.resume(co)
            if not ok then break end
        end
        if not FarmEnabled then return false end
    end
    if not done then
        SetStatus(kind .. " TIMEOUT")
        MarkFailed(kind)
        return false
    end
    return success
end

-- MAIN LOOP
task.spawn(function()
    while task.wait(2) do
        if not FarmEnabled then SetStatus("Farm OFF"); continue end
        if not PetFarmEnabled and not BabyFarmEnabled then SetStatus("No modes"); continue end
        local ok, err = pcall(function()
            local t = GetFarmTargets()
            local b = t.Baby; local pets = t.Pets
            local function hasNeed(k)
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
                local k, fn = e[1], e[2]
                if hasNeed(k) then
                    if CanTry(k) then
                        SetStatus(k .. "...")
                        local success = RunWithTimeout(k, fn, 60)
                        if success then ClearFailure(k) end
                    else
                        local f = TaskFailures[k]
                        local secs = f and math.max(0, math.floor(30 - (tick() - f.time))) or 30
                        SetStatus(k .. " retry " .. secs .. "s")
                    end
                    return
                end
            end
            for _, w in ipairs({ "leaf_pile", "rain_puddle", "snow", "diving_board", "party_zone" }) do
                if hasNeed(w) then
                    if CanTry(w) then
                        SetStatus(w)
                        RunWithTimeout(w, function() return DoQuestTask(w, "MainMap") end, 60)
                    end
                    return
                end
            end
            SetStatus("Idle " .. DebugInfo.Pets .. "p " .. DebugInfo.BabyNeeds .. "b")
        end)
        if not ok then DebugInfo.LastError = tostring(err); SetStatus("Error: " .. tostring(err)) end
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
                    local pr = pet.properties or {}
                    local age = pr.age or 1
                    local isN = pr.neon or pr.is_neon
                    local isM = pr.mega_neon or pr.is_mega
                    if age == 6 and not isN and not isM then
                        groups[kind] = groups[kind] or { reg = {}, neon = {} }
                        table.insert(groups[kind].reg, uid)
                    elseif isN and not isM then
                        groups[kind] = groups[kind] or { reg = {}, neon = {} }
                        table.insert(groups[kind].neon, uid)
                    end
                end
            end
            for kind, g in pairs(groups) do
                if #g.reg >= 4 then
                    SetStatus("Craft Neon " .. kind)
                    pcall(function() API.DoNeonFusion:InvokeServer({ g.reg[1], g.reg[2], g.reg[3], g.reg[4] }) end)
                    task.wait(4)
                elseif FastMegaMode == "Mega" and #g.neon >= 4 then
                    SetStatus("Craft Mega " .. kind)
                    pcall(function() API.DoNeonFusion:InvokeServer({ g.neon[1], g.neon[2], g.neon[3], g.neon[4] }) end)
                    task.wait(4)
                end
            end
        end)
    end
end)

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
    big_head_potion = { cat = "food", price = 10, name = "Big Head Potion" },
    hyperspeed_potion = { cat = "food", price = 40, name = "Hyperspeed Potion" },
    nograv_potion = { cat = "food", price = 99, name = "Anti-grav Potion" },
}

task.spawn(function()
    while task.wait(2) do
        if not AutoBuyEnabled then continue end
        local money = M.ClientData.get("money") or 0
        for kind, on in pairs(BuyTargets) do
            if on and ShopCatalog[kind] then
                local it = ShopCatalog[kind]
                if money >= it.price then
                    pcall(function() API.BuyItem:InvokeServer(it.cat, kind, { buy_count = 1 }) end)
                    task.wait(0.8)
                end
            end
        end
    end
end)

-- ══════════════════ VALUES (TRADE) ══════════════════
-- Sources multiples : remplace les DuskShine URL par les liens du fichier
local ValuesCache = {}
local ValuesLoaded = false
local ValueSourceName = "Elvebredd"

local VALUE_SOURCES = {
    ["Elvebredd"] = {
        "https://raw.githubusercontent.com/adoptme-values/values/main/elvebredd.json",
        "https://raw.githubusercontent.com/adoptme-values/values/main/values.json",
        "https://thepatchgg.github.io/data/elvebredd.json",
    },
    ["Starpets"] = {
        "https://raw.githubusercontent.com/adoptme-values/values/main/starpets.json",
        "https://thepatchgg.github.io/data/starpets.json",
    },
    ["AMVGG"] = {
        "https://raw.githubusercontent.com/adoptme-values/values/main/amvgg.json",
        "https://thepatchgg.github.io/data/amvgg.json",
    },
}

-- Fallback statique étendu (top 60+ pets)
local FALLBACK = {
    shadow_dragon = { regular = 0.5, neon = 2.5, mega = 12 },
    bat_dragon = { regular = 0.4, neon = 2.0, mega = 10 },
    giraffe = { regular = 0.3, neon = 1.5, mega = 7 },
    frost_dragon = { regular = 0.25, neon = 1.2, mega = 6 },
    parrot = { regular = 0.15, neon = 0.8, mega = 4 },
    owl = { regular = 0.12, neon = 0.6, mega = 3 },
    crow = { regular = 0.1, neon = 0.5, mega = 2.5 },
    evil_unicorn = { regular = 0.09, neon = 0.45, mega = 2.2 },
    kanga = { regular = 0.08, neon = 0.4, mega = 2 },
    turtle = { regular = 0.07, neon = 0.35, mega = 1.8 },
    arctic_reindeer = { regular = 0.06, neon = 0.3, mega = 1.5 },
    unicorn = { regular = 0.05, neon = 0.25, mega = 1.2 },
    dragon = { regular = 0.03, neon = 0.15, mega = 0.8 },
    griffin = { regular = 0.03, neon = 0.15, mega = 0.8 },
    kitsune = { regular = 0.02, neon = 0.1, mega = 0.5 },
    cerberus = { regular = 0.02, neon = 0.1, mega = 0.5 },
    queen_bee = { regular = 0.015, neon = 0.08, mega = 0.4 },
    golden_unicorn = { regular = 0.014, neon = 0.07, mega = 0.35 },
    dalmatian = { regular = 0.013, neon = 0.065, mega = 0.32 },
    gold_rat = { regular = 0.012, neon = 0.06, mega = 0.3 },
    lion = { regular = 0.011, neon = 0.055, mega = 0.28 },
    red_panda = { regular = 0.01, neon = 0.05, mega = 0.25 },
    flamingo = { regular = 0.009, neon = 0.045, mega = 0.22 },
    crow_2019 = { regular = 0.008, neon = 0.04, mega = 0.2 },
    blue_dog = { regular = 0.007, neon = 0.035, mega = 0.18 },
    pink_cat = { regular = 0.006, neon = 0.03, mega = 0.15 },
}

local function LoadValues(sourceName)
    sourceName = sourceName or ValueSourceName
    local urls = VALUE_SOURCES[sourceName] or VALUE_SOURCES["Elvebredd"]

    if isfile(VAL_FILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(VAL_FILE))
        end)
        if ok and type(data) == "table" and data.__source == sourceName then
            ValuesCache = data.values or data
            ValuesCache.__source = nil
            ValuesLoaded = true
            return
        end
    end

    for _, url in ipairs(urls) do
        local ok, raw = pcall(function() return game:HttpGet(url, true) end)
        if ok and raw and #raw > 100 and raw:sub(1, 1) == "{" then
            local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok2 and type(data) == "table" then
                ValuesCache = data
                ValuesLoaded = true
                pcall(function()
                    local toSave = { __source = sourceName, values = data }
                    writefile(VAL_FILE, HttpService:JSONEncode(toSave))
                end)
                print("[Yuno] Values loaded from " .. sourceName .. " via " .. url)
                return
            end
        end
    end

    ValuesCache = FALLBACK
    ValuesLoaded = true
    print("[Yuno] Using static fallback values")
end

local function GetItemValue(kind, props)
    if not kind then return 0 end
    if not ValuesLoaded then LoadValues() end
    local norm = tostring(kind):lower():gsub("[%s%-_]+", "")
    for k, v in pairs(ValuesCache) do
        if type(k) == "string" and k:lower():gsub("[%s%-_]+", "") == norm then
            if type(v) == "table" then
                local isM = props and (props.mega_neon or props.is_mega)
                local isN = props and (props.neon or props.is_neon)
                if isM and v.mega then return v.mega end
                if isN and v.neon then return v.neon end
                return v.regular or v.value or 0
            elseif type(v) == "number" then return v end
        end
    end
    return 0
end
task.spawn(LoadValues)

-- Trade calculator (W/F/L)
local tradeCalcEnabled = false
local tradeOverlay
local function UpdateTradeOverlay(myV, theirV)
    if not tradeOverlay or not tradeOverlay.label then return end
    local profit = (theirV or 0) - (myV or 0)
    local letter, color = "F", Color3.fromRGB(255, 200, 0)
    if profit > 0.01 then letter, color = "W", Color3.fromRGB(46, 204, 113) end
    if profit < -0.01 then letter, color = "L", Color3.fromRGB(255, 60, 60) end
    tradeOverlay.label.Text = string.format("%s (%+.2f)", letter, profit)
    tradeOverlay.label.TextColor3 = color
end

task.spawn(function()
    while task.wait(1) do
        if not tradeCalcEnabled then continue end
        pcall(function()
            local data = M.ClientData.get_data() or {}
            local pd = data[LP.Name]
            local trade = pd and pd.trade
            if not trade or not trade.sender_offer or not trade.recipient_offer then return end
            if trade.current_stage ~= "negotiation" then return end

            local myOffer = (trade.sender_offer.player_name == LP.Name) and trade.sender_offer or trade.recipient_offer
            local theirOffer = (trade.sender_offer.player_name == LP.Name) and trade.recipient_offer or trade.sender_offer

            local myV, theirV = 0, 0
            for _, item in pairs(myOffer.items or {}) do
                myV = myV + GetItemValue(item.id or item.kind, item.properties)
            end
            for _, item in pairs(theirOffer.items or {}) do
                theirV = theirV + GetItemValue(item.id or item.kind, item.properties)
            end
            UpdateTradeOverlay(myV, theirV)
        end)
    end
end)

-- ══════════════════ VISUALS ══════════════════
local VisualVars = { Mega = false, Neon = false, Fly = false, Ride = false, Eggs = false }
local SavedPetVisuals = {}

local function ApplyVisualsToCurrent()
    for _, w in pairs(M.ClientData.get("pet_char_wrappers") or {}) do
        if w.player == LP then
            SavedPetVisuals[w.pet_unique] = { Mega = VisualVars.Mega, Neon = VisualVars.Neon, Fly = VisualVars.Fly, Ride = VisualVars.Ride }
            break
        end
    end
    pcall(function() M.ClientData.DataChangedEvent:Fire("inventory", M.ClientData.get("inventory")) end)
end

local function ApplyVisualsToAll()
    local inv = M.ClientData.get("inventory", "Raw")
    if inv and inv.pets then
        for uid in pairs(inv.pets) do
            SavedPetVisuals[uid] = { Mega = VisualVars.Mega, Neon = VisualVars.Neon, Fly = VisualVars.Fly, Ride = VisualVars.Ride }
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
            else newPets[uid] = pet end
        end
        local c = {}; for k, v in pairs(res) do c[k] = v end; c.pets = newPets
        return c
    end
    return res
end

-- ══════════════════ HALLOWEEN ══════════════════
local HalloweenCryptEnabled = false
local HalloweenGhostEnabled = false
local HalloweenTwigEnabled = false

task.spawn(function()
    while task.wait(2) do
        if HalloweenCryptEnabled then
            pcall(function()
                local mgr = M.ClientData.get("halloween_2026_crypt_manager")
                if not mgr or not mgr.floors then return end
                local last = mgr.floors[#mgr.floors]
                if not last then return end
                if last.is_final then
                    SetStatus("Crypt Claim")
                    return
                end
            end)
        end
    end
end)

-- ══════════════════ BUILD TABS ══════════════════
AddTab("7733960981", "Home", function(page)
    local h = Make("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.3, Parent = page })
    Make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = h })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 22), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1, Text = "Yuno Farm v5.0", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = h })
    Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 34), BackgroundTransparency = 1, Text = (IS_MOBILE and "Mobile" or "PC") .. " • " .. ThemeName, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = h })

    local sc = Make("Frame", { Size = UDim2.new(1, 0, 0, 80), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.3, Parent = page })
    Make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = sc })
    local lbl = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1, Text = "Status: Idle", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })
    Flags.__statusLbl = lbl
    local infoL = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 32), BackgroundTransparency = 1, Text = "Debug: -", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })
    local locL = Make("TextLabel", { Size = UDim2.new(1, -30, 0, 16), Position = UDim2.new(0, 15, 0, 50), BackgroundTransparency = 1, Text = "Loc: -", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = sc })

    task.spawn(function()
        while task.wait(1) do
            if not sc.Parent then break end
            infoL.Text = string.format("🐾 %d pets • 🍼 %d baby • ⚠ %d needs", DebugInfo.Pets, DebugInfo.BabyNeeds, DebugInfo.PetNeeds)
            locL.Text = "Loc: " .. tostring(Cac.CurrentLocation) .. " • Beds: " .. #Cac.BedIds.MainMap .. "/" .. #Cac.BedIds.School .. " • Showers: " .. #Cac.ShowerIds
        end
    end)

    UI.Button(page, { Name = "🔄 Refresh Furniture IDs", Callback = function()
        local bm, bs, sh = PopulateFurnitureIDs()
        Notify("Furniture", string.format("Beds %d/%d • Showers %d", bm, bs, sh))
    end })
    UI.Button(page, { Name = "🔍 Diagnostic", Callback = function()
        local houseData = M.ClientData.get("house_interior")
        local data = M.ClientData.get_data() or {}
        local pd = data[LP.Name] or {}
        local f = (houseData and houseData.furniture) or (pd.house_interior and pd.house_interior.furniture)
        local fc = 0; if type(f) == "table" then for _ in pairs(f) do fc = fc + 1 end end
        local w = M.ClientData.get("pet_char_wrappers") or {}
        local wc = 0; for _ in pairs(w) do wc = wc + 1 end
        Notify("Diagnostic", string.format("Furniture: %d | Wrappers: %d | Loc: %s", fc, wc, tostring(Cac.CurrentLocation)), 8)
    end })
end)

AddTab("6908632622", "AutoFarm", function(page)
    UI.Section(page, "Master")
    UI.Toggle(page, { Name = "Farm Master", Flag = "YF_FarmMaster", Callback = function(v) FarmEnabled = v; Notify("Yuno", v and "ON" or "OFF") end })
    UI.Toggle(page, { Name = "Pet Farm", Flag = "YF_PetFarm", Callback = function(v) PetFarmEnabled = v end })
    UI.Toggle(page, { Name = "Baby Farm", Flag = "YF_BabyFarm", Callback = function(v) BabyFarmEnabled = v end })

    UI.Section(page, "Tools")
    UI.Button(page, { Name = "Reset Task Failures", Callback = function() TaskFailures = {}; Notify("Yuno", "Cleared") end })
    UI.Button(page, { Name = "Destroy Platforms", Callback = function()
        DestroyPlatforms()
        if Cac.CurrentPlatform then Cac.CurrentPlatform:Destroy(); Cac.CurrentPlatform = nil end
    end })
    UI.Button(page, { Name = "Force MainMap", Callback = function() TP("MainMap"); Notify("TP", "MainMap") end })

    UI.Section(page, "Age-Pot Farm")
    UI.Toggle(page, { Name = "Age-Pot Farm", Flag = "YF_AgePot", Callback = function(v)
        if not v then return end
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
                            if db and not db.is_egg and (pr.age or 1) == 6 and not (pr.neon or pr.mega_neon) then picked = uid; break end
                        end
                        if picked then
                            API.Unequip:InvokeServer(); task.wait(0.3)
                            API.Equip:InvokeServer(picked, { equip_as_last = true }); task.wait(1)
                            API.AddPet:InvokeServer(picked); task.wait(1)
                            API.ClaimProgression:FireServer(true)
                        end
                    end
                end)
            end
        end)
    end })
end)

AddTab("13549782519", "Pets", function(page)
    UI.Section(page, "Client Visuals")
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.4, TextWrapped = true, Parent = page, Text = "Visual only. Server doesn't see these changes.", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = page:GetChildren()[#page:GetChildren()] })

    UI.Toggle(page, { Name = "Mega Neon", Flag = "YF_VisMega", Callback = function(v) VisualVars.Mega = v; if v then VisualVars.Neon = false end end })
    UI.Toggle(page, { Name = "Neon", Flag = "YF_VisNeon", Callback = function(v) VisualVars.Neon = v; if v then VisualVars.Mega = false end end })
    UI.Toggle(page, { Name = "Fly", Flag = "YF_VisFly", Callback = function(v) VisualVars.Fly = v end })
    UI.Toggle(page, { Name = "Ride", Flag = "YF_VisRide", Callback = function(v) VisualVars.Ride = v end })

    UI.Section(page, "Apply")
    UI.Button(page, { Name = "Current", Callback = function() ApplyVisualsToCurrent(); Notify("Visuals", "Applied") end })
    UI.Button(page, { Name = "ALL", Callback = function() ApplyVisualsToAll(); Notify("Visuals", "All") end })
    UI.Button(page, { Name = "Reset", Callback = function() ResetVisuals(); Notify("Visuals", "Reset") end })
end)

AddTab("128557027005598", "FastMega", function(page)
    UI.Section(page, "Craft")
    UI.Toggle(page, { Name = "Fast Mega", Flag = "YF_FastMega", Callback = function(v) FastMegaEnabled = v end })
    UI.Toggle(page, { Name = "Mega Mode", Flag = "YF_FastMegaMode", Callback = function(v) FastMegaMode = v and "Mega" or "Neon" end })

    UI.Section(page, "Targets")
    local grid = Make("Frame", { Size = UDim2.new(1, 0, 0, 260), BackgroundTransparency = 1, Parent = page })
    Make("UIGridLayout", { CellSize = UDim2.new(0, 75, 0, 85), CellPadding = UDim2.new(0, 8, 0, 8), Parent = grid })
    task.spawn(function()
        task.wait(2)
        local DB = M.InventoryDB.pets
        local inv = M.ClientData.get("inventory", "Raw") or {}
        local counts = {}
        for _, p in pairs(inv.pets or {}) do
            local k = p.kind or p.id
            if k and DB[k] and not DB[k].is_egg then counts[k] = (counts[k] or 0) + 1 end
        end
        for kind, count in pairs(counts) do
            local db = DB[kind]
            local img = db.icon or db.image or "0"
            if tonumber(img) then img = "rbxassetid://" .. img end
            local btn = Make("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Section, Text = "", AutoButtonColor = false, Parent = grid })
            Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
            local st = Make("UIStroke", { Thickness = 1, Color = FastMegaTargets[kind] and Theme.Accent or Theme.Stroke, Parent = btn })
            Make("ImageLabel", { Size = UDim2.new(0.8, 0, 0.6, 0), Position = UDim2.new(0.1, 0, 0.05, 0), BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, Parent = btn })
            Make("TextLabel", { Size = UDim2.new(1, -4, 0, 16), Position = UDim2.new(0, 2, 1, -18), BackgroundTransparency = 1, Text = (db.name or kind) .. " x" .. count, Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = Theme.Text, TextWrapped = true, Parent = btn })
            btn.MouseButton1Click:Connect(function()
                FastMegaTargets[kind] = not FastMegaTargets[kind]
                st.Color = FastMegaTargets[kind] and Theme.Accent or Theme.Stroke
            end)
        end
    end)
end)

AddTab("135780702746673", "Shop", function(page)
    UI.Toggle(page, { Name = "Auto-Buy", Flag = "YF_AutoBuy", Callback = function(v) AutoBuyEnabled = v end })
    for kind, d in pairs(ShopCatalog) do
        UI.Toggle(page, { Name = d.name .. " ($" .. d.price .. ")", Flag = "YF_Buy_" .. kind, Callback = function(v) BuyTargets[kind] = v end })
    end
end)

AddTab("9695309046", "Trade", function(page)
    UI.Section(page, "Value Source")
    UI.Dropdown(page, { Name = "Site", Flag = "YF_ValueSite", Options = { "Elvebredd", "Starpets", "AMVGG" }, Default = "Elvebredd", Callback = function(v)
        ValueSourceName = v
        ValuesLoaded = false
        LoadValues(v)
        Notify("Values", "Loading " .. v .. "...")
    end })
    UI.Button(page, { Name = "🔄 Reload Values", Callback = function()
        if isfile(VAL_FILE) then delfile(VAL_FILE) end
        ValuesLoaded = false
        LoadValues(ValueSourceName)
        Notify("Values", "Reloaded")
    end })
    UI.Input(page, { Name = "Custom JSON URL", Flag = "YF_ValuesURL", Placeholder = "https://...", Callback = function(v)
        if v and v ~= "" then
            task.spawn(function()
                pcall(function()
                    local raw = game:HttpGet(v, true)
                    if raw and #raw > 50 then
                        local data = HttpService:JSONDecode(raw)
                        if type(data) == "table" then
                            ValuesCache = data; ValuesLoaded = true
                            writefile(VAL_FILE, HttpService:JSONEncode({ __source = "Custom", values = data }))
                            Notify("Values", "Custom URL loaded")
                        end
                    end
                end)
            end)
        end
    end })

    UI.Section(page, "Calculator W/F/L")
    UI.Toggle(page, { Name = "Enable Trade Calc", Flag = "YF_TradeCalc", Callback = function(v)
        tradeCalcEnabled = v
        if not v and tradeOverlay then tradeOverlay.label.Text = "" end
    end })

    UI.Section(page, "Trade License")
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

AddTab("128544079472562", "Halloween", function(page)
    UI.Toggle(page, { Name = "Auto Crypt", Flag = "YF_HallCrypt", Callback = function(v) HalloweenCryptEnabled = v end })
    UI.Toggle(page, { Name = "Auto Ghost", Flag = "YF_HallGhost", Callback = function(v) HalloweenGhostEnabled = v end })
    UI.Toggle(page, { Name = "Auto Twigs", Flag = "YF_HallTwig", Callback = function(v) HalloweenTwigEnabled = v end })
end)

AddTab("7734053495", "Settings", function(page)
    UI.Section(page, "Theme")
    UI.Dropdown(page, { Name = "Theme", Flag = "YF_Theme", Options = { "Yuno", "Dark", "Light", "Amethyst", "Galaxy", "Emerald", "BlueDeepWave" }, Default = ThemeName, Callback = function(v) ApplyTheme(v) end })
    UI.Slider(page, { Name = "UI Scale %", Flag = "YF_Scale", Min = 40, Max = 150, Default = math.floor((getgenv().YunoScale or 1) * 100), Callback = function(v) getgenv().YunoScale = v / 100; mainScale.Scale = v / 100 end })
    UI.Toggle(page, { Name = "Menu Blur", Flag = "YF_Blur", Callback = function(v)
        local blur = Lighting:FindFirstChild("YunoBlur")
        if v and not blur then blur = Instance.new("BlurEffect", Lighting); blur.Name = "YunoBlur" end
        if blur then blur.Enabled = v end
    end })

    UI.Section(page, "🔍 Remote Logger")
    Make("TextLabel", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Section, BackgroundTransparency = 0.4, TextWrapped = true, Parent = page,
        Text = "Active, fais la quête MANUELLEMENT, copie les logs, envoie à ton dev.",
        Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = page:GetChildren()[#page:GetChildren()] })

    UI.Toggle(page, { Name = "Enable Logger", Flag = "YF_LogEnabled", Callback = function(v)
        RemoteLogEnabled = v
        if v then StartRemoteLogger() end
        Notify("Logger", v and "ON" or "OFF")
    end })

    local logFrame = Make("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 180), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0), Parent = page })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = logFrame })
    Make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = logFrame })
    local logLbl = Make("TextLabel", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "(empty)", Font = Enum.Font.Code, TextSize = 10, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = logFrame })
    Flags.__logLbl = logLbl
    logLbl:GetPropertyChangedSignal("Text"):Connect(function()
        logFrame.CanvasSize = UDim2.new(0, 0, 0, logLbl.TextBounds.Y + 20)
    end)

    local br = Make("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = page })
    local cb = Make("TextButton", { Size = UDim2.new(0.48, 0, 1, 0), BackgroundColor3 = Theme.Section, Text = "📋 Copy Logs", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent, Parent = br })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = cb })
    cb.MouseButton1Click:Connect(function() Notify("Logger", CopyRemoteLog()) end)
    local clr = Make("TextButton", { Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0), BackgroundColor3 = Theme.Section, Text = "🗑 Clear", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent, Parent = br })
    Make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = clr })
    clr.MouseButton1Click:Connect(function()
        table.clear(RemoteLog)
        if Flags.__logLbl then Flags.__logLbl.Text = "(empty)" end
        Notify("Logger", "Cleared")
    end)

    UI.Section(page, "Config")
    UI.Button(page, { Name = "Save Config", Callback = function()
        pcall(function()
            local d = {}
            for k, v in pairs(Flags) do
                if type(v) ~= "userdata" and k ~= "__statusLbl" and k ~= "__logLbl" then d[k] = v end
            end
            writefile(CFG_FILE, HttpService:JSONEncode(d))
            Notify("Yuno", "Saved")
        end)
    end })
    UI.Button(page, { Name = "Destroy Script", Callback = function()
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
    Notify("Yuno Farm", "v5.0 loaded", 4)
end)

print("[Yuno] ✅ v5.0 loaded")