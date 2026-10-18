--[[
    ╔═══════════════════════════════════════════════════╗
    ║                  YUNO FARM v1.0                    ║
    ║           100% Local - Aucun réseau               ║
    ║                                                    ║
    ║   ⚠️  Prérequis :                                  ║
    ║   Lancer Adopt Main 4.1.3.lua.txt AVANT            ║
    ║   avec la ligne :                                  ║
    ║   getgenv().__DuskCapturedModules = __DuskCapturedModules ║
    ║                                                    ║
    ║   Tout le contenu est chargé localement.          ║
    ║   Aucun appel à duskandshine.com / API externe.   ║
    ╚═══════════════════════════════════════════════════╝
]]

if not game:IsLoaded() then game.Loaded:Wait() end
game:GetService("ReplicatedStorage"):WaitForChild("Fsys", 999)

-- ═════════════════════════════════════════════
-- SÉCURITÉ : bloquer tout appel HTTP au domaine Dusk
-- ═════════════════════════════════════════════
local _realHttpGet = game.HttpGet
do
    local function isBlocked(url)
        if type(url) ~= "string" then return false end
        url = url:lower()
        return url:find("duskandshine.com", 1, true)
            or url:find("duskandshine", 1, true)
            or url:find("dusk.com", 1, true)
    end
    local mt = getrawmetatable(game)
    if mt and mt.__index then
        local oldIndex = mt.__index
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, key)
            if self == game and key == "HttpGet" then
                return function(url, ...)
                    if isBlocked(url) then
                        warn("[Yuno] ⛔ HTTP bloqué vers:", url)
                        return ""
                    end
                    return _realHttpGet(url, ...)
                end
            end
            return oldIndex(self, key)
        end)
        setreadonly(mt, true)
    end
end

-- ═════════════════════════════════════════════
-- CONFIG
-- ═════════════════════════════════════════════
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")

local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
local isMobile = UserInputService.TouchEnabled or viewport.X < 900

getgenv().ScriptID         = "yuno_main"
getgenv().DuskVersion      = "4.1.3"
getgenv().DS_StopExecution = false
getgenv().CloserType       = "Floating Logo"
getgenv().YunoMobile       = isMobile
getgenv().UIScaleSize      = getgenv().UIScaleSize or (isMobile and 65 or 100)
getgenv().DuskTheme        = getgenv().DuskTheme or "Dark"

-- Anti-AFK
local vu = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end)

-- ═════════════════════════════════════════════
-- BUNDLE LOCAL — AUCUN HTTP
-- ═════════════════════════════════════════════
local MODULES = getgenv().__DuskCapturedModules or _G.__DuskCapturedModules

if type(MODULES) ~= "table" then
    -- Fallback : tenter de lire la variable locale exposée par le fichier
    error([[
[Yuno Farm] ❌ Bundle local introuvable.

Ajoute cette ligne à la FIN de Adopt Main 4.1.3.lua.txt :

    getgenv().__DuskCapturedModules = __DuskCapturedModules

Puis lance les deux scripts dans le même exécuteur.
]])
    return
end

-- Seul accès autorisé aux sources : le bundle local
local function GetSource(path)
    local src = MODULES[path]
    if type(src) == "string" then return src end
    return nil
end

print("[Yuno] ✅ Bundle local chargé:", #MODULES, "modules")

-- ═════════════════════════════════════════════
-- INTRO ANIMÉE
-- ═════════════════════════════════════════════
local function PlayIntro(cb)
    local g = Instance.new("ScreenGui")
    g.Name = "YunoIntro"
    g.IgnoreGuiInset = true
    g.DisplayOrder = 9999
    g.ResetOnSpawn = false
    pcall(function() g.Parent = CoreGui end)
    if not g.Parent then g.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local bg = Instance.new("Frame", g)
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(8,8,12)
    bg.BorderSizePixel = 0
    bg.BackgroundTransparency = 1

    local box = Instance.new("Frame", bg)
    box.Size = UDim2.new(0,420,0,220)
    box.Position = UDim2.new(0.5,0,0.5,0)
    box.AnchorPoint = Vector2.new(0.5,0.5)
    box.BackgroundTransparency = 1

    local yuno = Instance.new("TextLabel", box)
    yuno.Size = UDim2.new(1,0,0,90)
    yuno.Position = UDim2.new(0,0,0.15,0)
    yuno.BackgroundTransparency = 1
    yuno.Text = "YUNO"
    yuno.Font = Enum.Font.GothamBlack
    yuno.TextSize = 72
    yuno.TextColor3 = Color3.fromRGB(255,255,255)
    yuno.TextTransparency = 1

    local line = Instance.new("Frame", box)
    line.Size = UDim2.new(0,0,0,2)
    line.Position = UDim2.new(0.5,0,0.55,0)
    line.AnchorPoint = Vector2.new(0.5,0.5)
    line.BorderSizePixel = 0
    Instance.new("UIGradient", line).Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120,180,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200,130,255))
    })

    local farm = Instance.new("TextLabel", box)
    farm.Size = UDim2.new(1,0,0,40)
    farm.Position = UDim2.new(0,0,0.6,0)
    farm.BackgroundTransparency = 1
    farm.Text = "F A R M"
    farm.Font = Enum.Font.GothamBold
    farm.TextSize = 24
    farm.TextColor3 = Color3.fromRGB(140,180,255)
    farm.TextTransparency = 1

    local sub = Instance.new("TextLabel", box)
    sub.Size = UDim2.new(1,0,0,20)
    sub.Position = UDim2.new(0,0,0.85,0)
    sub.BackgroundTransparency = 1
    sub.Text = "Initializing..."
    sub.Font = Enum.Font.GothamMedium
    sub.TextSize = 13
    sub.TextColor3 = Color3.fromRGB(120,120,140)
    sub.TextTransparency = 1

    TweenService:Create(bg, TweenInfo.new(0.4), {BackgroundTransparency=0}):Play()
    task.wait(0.4)
    TweenService:Create(yuno, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextTransparency=0}):Play()
    task.wait(0.3)
    TweenService:Create(farm, TweenInfo.new(0.4), {TextTransparency=0}):Play()
    TweenService:Create(line, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {Size=UDim2.new(0,220,0,2)}):Play()
    task.wait(0.4)
    TweenService:Create(sub, TweenInfo.new(0.4), {TextTransparency=0}):Play()
    task.wait(1.4)

    TweenService:Create(yuno, TweenInfo.new(0.3), {TextTransparency=1}):Play()
    TweenService:Create(farm, TweenInfo.new(0.3), {TextTransparency=1}):Play()
    TweenService:Create(sub, TweenInfo.new(0.3), {TextTransparency=1}):Play()
    TweenService:Create(line, TweenInfo.new(0.3), {Size=UDim2.new(0,0,0,2)}):Play()
    task.wait(0.3)
    TweenService:Create(bg, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
    task.wait(0.4)
    g:Destroy()
    if cb then cb() end
end

-- ═════════════════════════════════════════════
-- LOAD LIB
-- ═════════════════════════════════════════════
local libSrc = GetSource("/raw/dusk_library_test")
if not libSrc then
    error("[Yuno] ❌ /raw/dusk_library_test manquant dans le bundle.")
end
local libChunk = loadstring(libSrc, "@Yuno_Lib")
if not libChunk then error("[Yuno] Compile error lib") end
local okLib, Lib = pcall(libChunk)
if not okLib or type(Lib) ~= "table" then error("[Yuno] Init lib: " .. tostring(Lib)) end

if Lib.SetTheme then Lib:SetTheme(getgenv().DuskTheme) end
print("[Yuno] ✅ Library loaded")

-- Config manager
do
    local s = GetSource("/raw/modules/adm_main/ConfigManager")
    if s then
        local c = loadstring(s)
        if c then
            local okc, CM = pcall(c)
            if okc and type(CM) == "table" then
                getgenv().ConfigManager = CM
                pcall(function() CM:Init(Lib) end)
                pcall(function() CM:Load() end)
            end
        end
    end
    if not getgenv().SaveConfig then getgenv().SaveConfig = function() end end
end

-- ═════════════════════════════════════════════
-- SETUP CORE
-- ═════════════════════════════════════════════
local Fsys = require(ReplicatedStorage:WaitForChild("Fsys", 5))
local M = {
    RouterClient     = Fsys.load("RouterClient"),
    ClientData       = Fsys.load("ClientData"),
    InteriorsM       = Fsys.load("InteriorsM"),
    PetEntityHelper  = Fsys.load("PetEntityHelper"),
    PetEntityManager = Fsys.load("PetEntityManager"),
    InventoryDB      = Fsys.load("InventoryDB"),
    LiveOpsTime      = Fsys.load("LiveOpsTime"),
    KindDB           = Fsys.load("KindDB"),
    IdleProgressionCalculator = require(
        ReplicatedStorage:WaitForChild("new"):WaitForChild("modules")
        :WaitForChild("IdleProgression"):WaitForChild("IdleProgressionCalculator")
    )
}

local API = {
    ActivateInterior     = M.RouterClient.get("HousingAPI/ActivateInteriorFurniture"),
    ActivateFurniture    = M.RouterClient.get("HousingAPI/ActivateFurniture"),
    SubscribeToHouse     = M.RouterClient.get("HousingAPI/SubscribeToHouse"),
    UnsubscribeFromHouse = M.RouterClient.get("HousingAPI/UnsubscribeFromHouse"),
    Equip                = M.RouterClient.get("ToolAPI/Equip"),
    Unequip              = M.RouterClient.get("ToolAPI/Unequip"),
    ServerUseTool        = M.RouterClient.get("ToolAPI/ServerUseTool"),
    UseStroller          = M.RouterClient.get("AdoptAPI/UseStroller"),
    HoldBaby             = M.RouterClient.get("AdoptAPI/HoldBaby"),
    ExitSeatStates       = M.RouterClient.get("AdoptAPI/ExitSeatStates"),
    EjectBaby            = M.RouterClient.get("AdoptAPI/EjectBaby"),
    CreatePetObject      = M.RouterClient.get("PetObjectAPI/CreatePetObject"),
    GrabPetObject        = M.RouterClient.get("PetObjectAPI/GrabPetObject"),
    DropPetObject        = M.RouterClient.get("PetObjectAPI/DropPetObject"),
    ExitFurniture        = M.RouterClient.get("PetAPI/ExitFurnitureUseStates"),
    ConsumeFoodObject    = M.RouterClient.get("PetAPI/ConsumeFoodObject"),
    ProgressPetMeAilment = M.RouterClient.get("AilmentsAPI/ProgressPetMeAilment"),
    ChooseMysteryAilment = M.RouterClient.get("AilmentsAPI/ChooseMysteryAilment"),
    AddPetAPI            = M.RouterClient.get("IdleProgressionAPI/AddPet"),
    RemovePetAPI         = M.RouterClient.get("IdleProgressionAPI/RemovePet"),
    ClaimAPI             = M.RouterClient.get("IdleProgressionAPI/CommitAllProgression"),
    MarkOverviewSeen     = M.RouterClient.get("IdleProgressionAPI/MarkOverviewSeen"),
    MarkSummarySeen      = M.RouterClient.get("IdleProgressionAPI/MarkSummarySeen"),
    BuyItem              = M.RouterClient.get("ShopAPI/BuyItem"),
    SetLocation          = M.RouterClient.get("LocationAPI/SetLocation"),
    ChooseTeam           = M.RouterClient.get("TeamAPI/ChooseTeam"),
    Pay                  = M.RouterClient.get("PayAPI/DisablePopups"),
    BuyFurnitures        = M.RouterClient.get("HousingAPI/BuyFurnitures")
}

local Cac = {
    MainPlatformLoaded=false, PlatformLoaded=false, currentPlatform=nil,
    MainPlatform=nil, IsRunning=false, connection=nil, mystered=false,
    strollerUID=nil, toyUID=nil, appleUIDs={}, waterUIDs={},
    bedIds={MainMap={}, School={}}, showerIds={},
    FarmTargets={Baby={}, Pets={}}, TempNeeds={}, Connections={},
    CurrentLocation=nil, LastMysteryAttempt=nil
}

getgenv().DuskCore = {
    M=M, API=API, Cac=Cac, plr=LocalPlayer,
    IsRespawning=function() return false end,
    print=print, warn=warn
}

-- Logic bundle (local)
do
    local s = GetSource("/raw/dusk_logic_bundle_raw")
    if s then
        local c = loadstring(s, "@Yuno_Logic")
        if c then
            local ok, bundle = pcall(c)
            if ok and type(bundle) == "table" then
                getgenv().DuskLogicBundle = bundle
                print("[Yuno] ✅ Logic bundle loaded")
            end
        end
    end
end

-- ═════════════════════════════════════════════
-- INTRO + WINDOW
-- ═════════════════════════════════════════════
PlayIntro(function()

    local halloweenActive = false
    pcall(function()
        local SM = ReplicatedStorage:WaitForChild("SharedModules", 3)
        if SM and SM:FindFirstChild("ContentPacks") and SM.ContentPacks:FindFirstChild("Halloween2026") then
            halloweenActive = true
        end
    end)
    getgenv().IsHalloweenActive = halloweenActive

    local Window = Lib:CreateWindow({
        Title = "Yuno",
        AccentTitle = "Farm",
        Version = "v1.0",
        Size = UDim2.new(0, 680, 0, halloweenActive and 510 or 450)
    })

    local Tabs = {
        Home     = Window:CreateTab({ Name="Home",     Icon="7733960981" }),
        AutoFarm = Window:CreateTab({ Name="AutoFarm", Icon="6908632622" }),
        Pets     = Window:CreateTab({ Name="Pets",     Icon="13549782519" }),
        Trade    = Window:CreateTab({ Name="Trade",    Icon="9695309046" }),
        Settings = Window:CreateTab({ Name="Settings", Icon="7734053495" })
    }
    if halloweenActive then
        Tabs.Halloween = Window:CreateTab({ Name="Halloween", Icon="128544079472562" })
    end

    Window:SelectTab(Tabs.Home)
    Window:Build()

    -- Chargement modules (local uniquement)
    local list = {
        { N="Home",         P="/raw/modules/adm_main/home",           T=Tabs.Home },
        { N="AutoFarmMode", P="/raw/modules/adm_main/autofarm_modes", T=nil },
        { N="AutoFarmUI",   P="/raw/modules/adm_main/autofarm_ui",    T=Tabs.AutoFarm },
        { N="AutoFarm",     P="/raw/modules/adm_main/autofarm",       T=nil },
        { N="SpecialUI",    P="/raw/modules/adm_main/special_ui",     T=Tabs.Pets },
        { N="Special",      P="/raw/modules/adm_main/special",        T=nil },
        { N="TradeUI",      P="/raw/modules/adm_main/trading_ui",     T=Tabs.Trade },
        { N="Trade",        P="/raw/modules/adm_main/trading",        T=nil },
        { N="SettingsUI",   P="/raw/modules/adm_main/settings_ui",    T=Tabs.Settings },
        { N="Settings",     P="/raw/modules/adm_main/settings",       T=nil }
    }
    if halloweenActive then
        table.insert(list, { N="HalloweenFarm", P="/raw/modules/adm_main/halloween_farm", T=nil })
        table.insert(list, { N="HalloweenUI",   P="/raw/modules/adm_main/halloween_ui",   T=Tabs.Halloween })
    end

    local loaded = {}
    local function Load(info)
        if loaded[info.N] then return end
        task.spawn(function()
            -- Modules logic (sans tab) → depuis bundle
            if not info.T and getgenv().DuskLogicBundle then
                local key = string.lower(info.N)
                if key == "trade" then key = "trading" end
                if getgenv().DuskLogicBundle[key] then
                    local ok, Mod = pcall(getgenv().DuskLogicBundle[key])
                    if ok and Mod and type(Mod.Init) == "function" then
                        pcall(function()
                            if key == "autofarm" then Mod:Init(Lib, Lib)
                            else Mod:Init() end
                        end)
                        loaded[info.N] = true
                        print("[Yuno] Logic:", key)
                    end
                    return
                end
            end
            -- Modules UI → depuis bundle
            local src = GetSource(info.P)
            if not src then loaded[info.N] = true; return end
            local chunk = loadstring(src, "@" .. info.N)
            if not chunk then loaded[info.N] = true; return end
            local ok, Mod = pcall(chunk)
            if ok and Mod and type(Mod.Init) == "function" then
                pcall(function() Mod:Init(Lib, Window, info.T) end)
                print("[Yuno] Loaded:", info.N)
            end
            loaded[info.N] = true
        end)
    end

    for _, info in ipairs(list) do
        Load(info)
        task.wait(0.05)
    end

    task.spawn(function()
        while true do
            local done = true
            for _, m in ipairs(list) do
                if not loaded[m.N] then done = false; break end
            end
            if done then break end
            task.wait(0.1)
        end
        getgenv().AllDuskModulesLoaded = true
        print("[Yuno] 🚀 All modules loaded")
        task.wait(0.3)
        if Lib.UpdateScale then
            pcall(function() Lib:UpdateScale(getgenv().UIScaleSize) end)
        end
    end)
end)

-- ═════════════════════════════════════════════
-- CERCLE Y (Floating logo)
-- ═════════════════════════════════════════════
task.spawn(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local mega = pg:WaitForChild("DuskShine_Mega", 30) -- nom interne conservé pour ne pas casser Lib.Destroy/Notify
    if not mega then return end
    local float = mega:WaitForChild("FloatingWidget", 10)
    if not float then return end
    local img = float:FindFirstChildOfClass("ImageLabel")
    if not img then return end

    img.Image = ""
    img.ImageColor3 = Color3.fromRGB(255,255,255)
    img.ImageTransparency = 1

    local y = Instance.new("TextLabel")
    y.Size = UDim2.new(1,0,1,0)
    y.BackgroundTransparency = 1
    y.Text = "Y"
    y.Font = Enum.Font.GothamBlack
    y.TextSize = 32
    y.TextColor3 = Color3.fromRGB(255,255,255)
    y.ZIndex = 20
    y.Parent = img.Parent
    Instance.new("UIGradient", y).Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200,220,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))
    })
    print("[Yuno] ✅ Y-circle applied")
end)

print("[Yuno] 🎉 Yuno Farm v1.0 ready | mobile =", isMobile)

task.spawn(function()
    task.wait(3)
    if Lib.Notify then
        pcall(function()
            Lib:Notify("Yuno Farm", "Script loaded successfully!", 4,
                "rbxassetid://17829956110", "rbxassetid://72958619361915")
        end)
    end
end)