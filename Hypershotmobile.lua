-- Load Kour6anHub Library
local Kour6an = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kour6ann/Kour6anhub/main/Kour6anhub.lua"))()
local Window = Kour6an.CreateLib("Kour6anHub - Hypershot", "BloodTheme")

----------------------------------------------------------------
-- INFO TAB
----------------------------------------------------------------
local InfoTab = Window:NewTab("Info")
local InfoTitleSection = InfoTab:NewSection("⚔️ Welcome to Kour6anHUB ⚔️")
InfoTitleSection:NewLabel("────────────────────────────")
InfoTitleSection:NewLabel(" Best HyperShot Script ")
InfoTitleSection:NewLabel("────────────────────────────")

local InfoSection = InfoTab:NewSection("ℹ️ Hub Information")
InfoSection:NewLabel("Hub: Kour6anHUB - HyperShot")
InfoSection:NewLabel("Version: 2.0 Mobile")
InfoSection:NewLabel(" 📌NOTE : ")
InfoSection:NewLabel(" 📌Most functions support TeamCheck! ")
InfoSection:NewLabel(" 📌For the love of god Don't use in DUELS! ")
InfoSection:NewLabel(" 📌 YOU'LL GET INSTA BAN IN DUELS! ")
InfoSection:NewLabel("────────────────────────────")

local CreditsSection = InfoTab:NewSection("👑 Credits")
CreditsSection:NewLabel("Created by: Kour6an")
CreditsSection:NewLabel("Discord 💬: discord.gg/3ZqFVq3ZJ")
CreditsSection:NewLabel("Youtube 🎥: youtube.com/@kour6an")

CreditsSection:NewButton("📋 Copy Discord Link", "Click to copy", function()
    setclipboard("https://discord.gg/3ZqFVq3ZJ")
    Window:Notify("Copied!", "Discord link copied to clipboard", 3)
end)

CreditsSection:NewButton("📋 Copy YouTube Link", "Click to copy", function()
    setclipboard("https://www.youtube.com/@kour6an")
    Window:Notify("Copied!", "YouTube link copied to clipboard", 3)
end)

local FooterSection = InfoTab:NewSection("📢 Updates")
FooterSection:NewLabel("Stay tuned for future updates!")
FooterSection:NewLabel("────────────────────────────")

----------------------------------------------------------------
-- MOBILE-ONLY AIMING TAB
----------------------------------------------------------------
local AimingTab = Window:NewTab("Aiming")

----------------------------------------------------------------
-- GENERAL SETTINGS SECTION (SHARED)
----------------------------------------------------------------
local GeneralSettingsSection = AimingTab:NewSection("⚙️ General Settings")

-- Shared variables
local sharedConfig = {
    teamCheck = true,
    wallCheck = true
}

GeneralSettingsSection:NewToggle("Team Check", "Ignore teammates (applies to both)", function(state)
    sharedConfig.teamCheck = state
    Window:Notify("Team Check", state and "Enabled - Ignoring teammates" or "Disabled", 2)
end)

GeneralSettingsSection:NewToggle("Wall Check", "Check for walls between you and target", function(state)
    sharedConfig.wallCheck = state
    Window:Notify("Wall Check", state and "Enabled" or "Disabled", 2)
end)

----------------------------------------------------------------
-- SILENT AIM SECTION (MOBILE)
----------------------------------------------------------------
local SilentAimSection = AimingTab:NewSection("🎯 Silent Aim")

local MainESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/alohabeach/Main/refs/heads/master/utils/esp/source.lua"))()

local client = {
    gameui = require(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("GameUI"):WaitForChild("GameUIMod"));
    oldfunction = {};
}

client.oldfunction.GetMousePos = clonefunction(client.gameui.GetMousePos)

local config = {
    silentaimenabled = false;
    silentaimradius = 100;
    fovCircleVisible = false;
    fovCircleColor = Color3.fromRGB(255, 255, 255);
    targetPart = "Head";
    teamCheck = true;
}

local Circle = MainESP.CreateCircle()
Circle.Radius = config.silentaimradius
Circle.Color = config.fovCircleColor
Circle.Position = MainESP.TracerOrigins.Middle
Circle.NumSides = 500
Circle.Visible = false

client.getentities = function()
    local models = {}
    for i,v in next, workspace.Mobs:GetChildren() do
        table.insert(models, v)
    end
    for i,v in ipairs(workspace:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChild("Humanoid") and v ~= game.Players.LocalPlayer.Character then
            table.insert(models, v)
        end
    end
    return models
end

local function isEnemy(character)
    if not config.teamCheck then return true end
    local enemyHighlight = character:FindFirstChild("EnemyHighlight", true)
    if not enemyHighlight then return false end
    local playerOutline = character:FindFirstChild("PlayerOutline", true)
    if playerOutline then return false end
    return true
end

-- MOBILE: Use center screen for aiming
client.getNearestToCursor = function()
    local UserInputService = game:GetService("UserInputService")
    local Camera = workspace.CurrentCamera
    
    -- Always use center screen for mobile
    local mousePos = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    
    local closestPart = nil
    local shortestDist = config.silentaimradius
    
    for i,v in next, client.getentities() do
        if not isEnemy(v) then continue end
        
        local targetPart = nil
        if config.targetPart == "Head" then
            targetPart = v:FindFirstChild("Head")
        elseif config.targetPart == "FakeHRP" then
            targetPart = v:FindFirstChild("FakeHRP")
        else
            local head = v:FindFirstChild("Head")
            local fakeHRP = v:FindFirstChild("FakeHRP")
            if head and fakeHRP then
                targetPart = math.random(1, 2) == 1 and head or fakeHRP
            else
                targetPart = head or fakeHRP
            end
        end
        
        if targetPart then
            local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    closestPart = targetPart
                end
            end
        end
    end
    return closestPart
end

client.gameui.GetMousePos = function(...)
    local nearest = client.getNearestToCursor()
    if config.silentaimenabled and nearest then
        return nearest.Position
    end
    return client.oldfunction.GetMousePos(...)
end

SilentAimSection:NewToggle("Enable Silent Aim", "Automatically aims at nearest enemy", function(state)
    config.silentaimenabled = state
    Window:Notify("Silent Aim", state and "Enabled" or "Disabled", 2)
end)

SilentAimSection:NewSlider("FOV Radius", 50, 500, 100, function(value)
    config.silentaimradius = value
    Circle.Radius = value
end)

SilentAimSection:NewToggle("Show FOV Circle", "Display circle showing detection radius", function(state)
    config.fovCircleVisible = state
    Circle.Visible = state
end)

SilentAimSection:NewDropdown("Target Part", {"Head", "FakeHRP", "Auto (Both)"}, function(choice)
    config.targetPart = choice == "Auto (Both)" and "Auto" or choice
    Window:Notify("Target Part", "Now targeting: "..choice, 2)
end)

SilentAimSection:NewDropdown("FOV Circle Color", {"White", "Red", "Green", "Blue", "Yellow", "Cyan", "Magenta", "Orange", "Pink", "Purple"}, function(choice)
    local colors = {
        White = Color3.fromRGB(255, 255, 255), Red = Color3.fromRGB(255, 0, 0),
        Green = Color3.fromRGB(0, 255, 0), Blue = Color3.fromRGB(0, 150, 255),
        Yellow = Color3.fromRGB(255, 255, 0), Cyan = Color3.fromRGB(0, 255, 255),
        Magenta = Color3.fromRGB(255, 0, 255), Orange = Color3.fromRGB(255, 150, 0),
        Pink = Color3.fromRGB(255, 100, 150), Purple = Color3.fromRGB(180, 0, 255)
    }
    Circle.Color = colors[choice] or Color3.fromRGB(255, 255, 255)
    Window:Notify("FOV Color", choice.." applied", 2)
end)

SilentAimSection:NewLabel("📱 Aims at center of screen automatically")

----------------------------------------------------------------
-- MOBILE AIMLOCK SECTION
----------------------------------------------------------------
local AimlockSection = AimingTab:NewSection("🔒 Aimlock (Mobile)")

_G.Disabled = false
_G.Aimlock = false
_G.ShowFOV = false
_G.FOVRadius = 150
_G.WallCheck = true
_G.TargetPart = "Head"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local aiming = false
local currentTarget = nil

local DrawingSuccess, Drawing = pcall(function() return Drawing end)
local FOVCircle
if DrawingSuccess and Drawing then
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = false
    FOVCircle.Radius = _G.FOVRadius
    FOVCircle.Thickness = 2
    FOVCircle.Transparency = 1
    FOVCircle.Color = Color3.fromRGB(0,255,0)
    FOVCircle.Filled = false
end

local function isWallBetween(origin, target, character)
    if not _G.WallCheck then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.IgnoreWater = true
    local rayResult = workspace:Raycast(origin, (target.Position - origin), rayParams)
    return rayResult ~= nil
end

local function isEnemyAimlock(character)
    local enemyHighlight = character:FindFirstChild("EnemyHighlight", true)
    if not enemyHighlight then return false end
    local playerOutline = character:FindFirstChild("PlayerOutline", true)
    if playerOutline then return false end
    return true
end

local function getTargetPart(character)
    return character:FindFirstChild(_G.TargetPart) or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

local function getAllEnemies()
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isEnemyAimlock(player.Character) then
            table.insert(enemies, player.Character)
        end
    end
    if workspace:FindFirstChild("Mobs") then
        for _, mob in ipairs(workspace.Mobs:GetChildren()) do
            if mob:IsA("Model") and isEnemyAimlock(mob) then
                table.insert(enemies, mob)
            end
        end
    end
    return enemies
end

local function getClosestEnemy(refPos)
    local closestEnemy, smallestDist = nil, math.huge
    for _, enemy in ipairs(getAllEnemies()) do
        local targetPart = getTargetPart(enemy)
        if targetPart then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - refPos).Magnitude
                if dist <= _G.FOVRadius and dist < smallestDist then
                    if not isWallBetween(Camera.CFrame.Position, targetPart, enemy) then
                        closestEnemy = enemy
                        smallestDist = dist
                    end
                end
            end
        end
    end
    return closestEnemy
end

local function isTargetValid(target, refPos)
    if not target or not target.Parent then return false end
    local targetPart = getTargetPart(target)
    if not targetPart then return false end
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - refPos).Magnitude
    if dist > _G.FOVRadius then return false end
    if isWallBetween(Camera.CFrame.Position, targetPart, target) then return false end
    if not isEnemyAimlock(target) then return false end
    return true
end

-- MOBILE: Toggle button for aiming
local function toggleAiming()
    aiming = not aiming
    if not aiming then
        currentTarget = nil
    end
    Window:Notify("Aimlock", aiming and "ACTIVE 🎯" or "INACTIVE", 2)
end

RunService.RenderStepped:Connect(function()
    if not FOVCircle then return end
    
    -- MOBILE: Always use center screen
    local refPos = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    
    if _G.Disabled or not _G.Aimlock or not _G.ShowFOV then
        FOVCircle.Visible = false
    else
        FOVCircle.Visible = true
        FOVCircle.Radius = _G.FOVRadius
        FOVCircle.Position = refPos
    end
    
    if _G.Aimlock and aiming then
        if currentTarget and isTargetValid(currentTarget, refPos) then
            local targetPart = getTargetPart(currentTarget)
            if targetPart then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
            end
        else
            currentTarget = getClosestEnemy(refPos)
            if currentTarget then
                local targetPart = getTargetPart(currentTarget)
                if targetPart then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                end
            end
        end
    end
end)

AimlockSection:NewToggle("Enable Aimlock", "Toggle aimlock on/off", function(state)
    _G.Aimlock = state
    _G.ShowFOV = state
    if not state then
        aiming = false
        currentTarget = nil
    end
    Window:Notify("Aimlock", state and "Enabled" or "Disabled", 2)
end)

-- MOBILE: Button to activate/deactivate aiming
AimlockSection:NewButton("📱 TOGGLE AIM", "Tap to activate/deactivate aiming", function()
    if _G.Aimlock then
        toggleAiming()
    else
        Window:Notify("Aimlock", "Enable Aimlock first!", 2)
    end
end)

AimlockSection:NewDropdown("Target Part", {"Head", "HumanoidRootPart", "UpperTorso"}, function(choice)
    _G.TargetPart = choice
    Window:Notify("Target Part", "Changed to: " .. choice, 2)
end)

AimlockSection:NewSlider("FOV Radius", 50, 500, 150, function(value)
    _G.FOVRadius = value
    if FOVCircle then FOVCircle.Radius = value end
end)

AimlockSection:NewDropdown("FOV Circle Color", {"White", "Red", "Green", "Blue", "Yellow", "Cyan", "Magenta", "Orange", "Pink", "Purple"}, function(choice)
    local colors = {
        White = Color3.fromRGB(255, 255, 255), Red = Color3.fromRGB(255, 0, 0),
        Green = Color3.fromRGB(0, 255, 0), Blue = Color3.fromRGB(0, 150, 255),
        Yellow = Color3.fromRGB(255, 255, 0), Cyan = Color3.fromRGB(0, 255, 255),
        Magenta = Color3.fromRGB(255, 0, 255), Orange = Color3.fromRGB(255, 150, 0),
        Pink = Color3.fromRGB(255, 100, 150), Purple = Color3.fromRGB(180, 0, 255)
    }
    if FOVCircle then FOVCircle.Color = colors[choice] or Color3.fromRGB(0, 255, 0) end
    Window:Notify("FOV Color", choice.." applied", 2)
end)

AimlockSection:NewLabel("📱 Tap TOGGLE AIM button to lock on")
AimlockSection:NewLabel("📱 Aims at center screen automatically")
AimlockSection:NewLabel("📌 Supports Team Check automatically")

----------------------------------------------------------------
-- AUTO FARM TAB
----------------------------------------------------------------
local AutoFarmTab = Window:NewTab("AutoFarm")
local FlagSection = AutoFarmTab:NewSection("Auto FLAG")
local TPEnemySection = AutoFarmTab:NewSection("TP to Enemy")

-- Services (reused throughout)
local rs = game:GetService("RunService")
local ws = game:GetService("Workspace")
local plrs = game:GetService("Players")
local lp = plrs.LocalPlayer or LocalPlayer
local camAF = ws.CurrentCamera

-- World objects
local Map = ws:FindFirstChild("Map")
local bots = ws:FindFirstChild("Mobs")
if not bots then 
    return lp:Kick("Mobs folder not found!") 
end

local function getHRP()
    local char = lp and (lp.Character or lp.CharacterAdded:Wait())
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getMainFlag(folder)
    if not folder then return nil end
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj.Name == "MainFlag" then
            return obj
        end
    end
    return nil
end

local function getFlags()
    local Flag1, Flag2 = Map and Map:FindFirstChild("Flag1"), Map and Map:FindFirstChild("Flag2")
    if lp and lp.Team and tostring(lp.Team.Name):match("1") then
        return getMainFlag(Flag1), getMainFlag(Flag2)
    else
        return getMainFlag(Flag2), getMainFlag(Flag1)
    end
end

--------------------------------------------------------------
--- AUTO FLAG Functionality-----------------------------------
--------------------------------------------------------------
local autoFlagEnabled = false

task.spawn(function()
    while task.wait(1) do
        if autoFlagEnabled then
            local myFlag, enemyFlag = getFlags()
            if enemyFlag and myFlag then
                pcall(function()
                    local hrp = getHRP()
                    if hrp then hrp.CFrame = enemyFlag.CFrame + Vector3.new(0,5,0) end
                end)
                task.wait(0.5)
                pcall(function()
                    local hrp = getHRP()
                    if hrp then hrp.CFrame = myFlag.CFrame + Vector3.new(0,5,0) end
                end)
                task.wait(1.5)
            end
        end
    end
end)

--------------------------------------------------------------
--- TP to Enemy Functionality---------------------------------
--------------------------------------------------------------
-- Configuration
local cfg = {
    enabled = false,
    tpDist = 7,
    switchDelay = 2,
    maxRange = 300,
    shootDelay = 0.1
}

-- State
local state = {
    target = nil,
    lastSwitch = 0,
    targetIdx = 1,
    lastShoot = 0,
    connection = nil
}

-- Get all valid enemies within range
local function getEnemiesInRange()
    local enemies = {}
    local myChar = lp.Character
    
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then 
        return enemies 
    end
    
    local myHRP = myChar.HumanoidRootPart
    local myTeam = myChar:GetAttribute("Team")
    
    -- Check Bots
    for _, v in bots:GetChildren() do
        if myTeam ~= -1 and v:GetAttribute("Team") == myTeam then continue end
        
        local hrp = v:FindFirstChild("HumanoidRootPart")
        local head = v:FindFirstChild("Head")
        local hum = v:FindFirstChild("Humanoid")
        
        if hrp and head and hum and hum.Health > 0 then
            local dist = (myHRP.Position - hrp.Position).Magnitude
            
            if dist <= cfg.maxRange then
                table.insert(enemies, {
                    hrp = hrp,
                    head = head,
                    distance = dist,
                    name = v.Name,
                    obj = v
                })
            end
        end
    end
    
    -- Check Players
    for _, v in plrs:GetPlayers() do
        if v == lp then continue end
        
        local char = v.Character
        if char then
            if myTeam ~= -1 and char:GetAttribute("Team") == myTeam then continue end
            
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChild("Humanoid")
            
            if hrp and head and hum and hum.Health > 0 then
                local dist = (myHRP.Position - hrp.Position).Magnitude
                
                if dist <= cfg.maxRange then
                    table.insert(enemies, {
                        hrp = hrp,
                        head = head,
                        distance = dist,
                        name = v.Name,
                        obj = char
                    })
                end
            end
        end
    end
    
    table.sort(enemies, function(a, b) return a.distance < b.distance end)
    return enemies
end

-- Check if current target is still valid
local function isTargetValid(t)
    if not t then return false end
    
    local obj = t.obj
    if not obj or not obj.Parent then return false end
    
    local hum = obj:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    
    return obj:FindFirstChild("HumanoidRootPart") ~= nil
end

-- Auto shoot function
local function autoShoot()
    if not cfg.enabled or not state.target or not isTargetValid(state.target) then return end
    
    local now = tick()
    if now - state.lastShoot >= cfg.shootDelay then
        mouse1press()
        task.wait(0.05)
        mouse1release()
        state.lastShoot = now
    end
end

local function startTPToEnemy()
    if state.connection then return end
    
    state.connection = rs.RenderStepped:Connect(function()
        if not cfg.enabled then return end
        
        pcall(function()
            local myChar = lp.Character
            if not myChar then return end
            
            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
            if not myHRP then return end
            
            local now = tick()
            local enemies = getEnemiesInRange()
            
            if #enemies == 0 then 
                state.target = nil
                return 
            end
            
            -- Rotation logic
            local shouldSwitch = not state.target or not isTargetValid(state.target) or (now - state.lastSwitch >= cfg.switchDelay)
            
            if shouldSwitch then
                state.targetIdx = state.targetIdx + 1
                if state.targetIdx > #enemies then
                    state.targetIdx = 1
                end
                state.target = enemies[state.targetIdx]
                state.lastSwitch = now
            end
            
            if not state.target or not isTargetValid(state.target) then
                state.target = enemies[1]
                state.targetIdx = 1
                return
            end
            
            -- TP to current target
            local enemyPos = state.target.hrp.Position
            local enemyLook = state.target.hrp.CFrame.LookVector
            local tpPos = enemyPos - (enemyLook * cfg.tpDist)
            tpPos = Vector3.new(tpPos.X, state.target.head.Position.Y, tpPos.Z)
            
            myHRP.CFrame = CFrame.new(tpPos, enemyPos)
            camAF.CFrame = CFrame.new(camAF.CFrame.Position, state.target.head.Position)
            
            autoShoot()
        end)
    end)
end

startTPToEnemy()

-------------------------------------------------------------
---- UI WRAPPING ONLY ------------
-------------------------------------------------------------

FlagSection:NewToggle("Auto Flag", "Automatically capture enemy flag and return", function(s)
    autoFlagEnabled = s
    Window:Notify("AutoFlag", s and "Enabled" or "Disabled", 2)
end)
FlagSection:NewLabel("📌 Undetectable unless you get reported lol..")

TPEnemySection:NewToggle("TP to Enemy", "Teleports to enemies with rotation & auto-shoot", function(s)
    cfg.enabled = s
    Window:Notify("TP to Enemy", s and "Enabled (Auto-Shoot ON)" or "Disabled", 2)
end)

TPEnemySection:NewKeybind("Toggle Key (TP to Enemy)", Enum.KeyCode.T, function()
    cfg.enabled = not cfg.enabled
    Window:Notify("TP to Enemy", cfg.enabled and "Enabled (Auto-Shoot ON)" or "Disabled", 2)
end)

TPEnemySection:NewSlider("Switch Delay", 0.5, 10, cfg.switchDelay, function(v)
    cfg.switchDelay = v
end)

TPEnemySection:NewSlider("TP Distance", 3, 20, cfg.tpDist, function(v)
    cfg.tpDist = v
end)

TPEnemySection:NewSlider("Max Range", 50, 500, cfg.maxRange, function(v)
    cfg.maxRange = v
end)

TPEnemySection:NewLabel("📌 Auto-Shoot is always ON when TP is enabled!")
TPEnemySection:NewLabel("📌 Rotates through all enemies automatically")
TPEnemySection:NewLabel("📌 Works on both NPCs and Players!")

----------------------------------------------------------------
-- WEAPONS TAB
----------------------------------------------------------------
local WeaponsTab = Window:NewTab("Weapons")
local AmmoSection = WeaponsTab:NewSection("Ammo Management")

local plr = game:GetService("Players").LocalPlayer

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local weaponState = {
    infiniteAmmo = false,
    infiniteMags = false,
    freeRainbowBullets = false
}

----------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------
local function getMainGui()
    return plr.PlayerGui:FindFirstChild("MainGui") or nil
end

----------------------------------------------------------------
-- Infinite Ammo Loop
----------------------------------------------------------------
task.spawn(function()
    while task.wait(0.01) do
        if weaponState.infiniteAmmo then
            local maingui = getMainGui()
            if maingui then
                pcall(function()
                    require(maingui.MainLocal.Shared).Tools[1].Ammo = 5
                end)
            end
        end
    end
end)
----------------------------------------------------------------
-- Rainbow Bullets
----------------------------------------------------------------
local function toggleRainbowBullets(state)
    weaponState.freeRainbowBullets = state
    game.Players.LocalPlayer:SetAttribute("RainbowBullets", state)
end

----------------------------------------------------------------
-- UI Controls
----------------------------------------------------------------
AmmoSection:NewLabel("🔫 Ammo Management")
AmmoSection:NewLabel("⚠️ May cause issues with killing enemies")


AmmoSection:NewToggle("Infinite Ammo", "Unlimited ammo in current magazine", function(s)
    weaponState.infiniteAmmo = s
    Window:Notify("Infinite Ammo", s and "Enabled" or "Disabled", 2)
end)

AmmoSection:NewToggle("Infinite Magazines", "Unlimited reserve ammo", function(s)
    weaponState.infiniteMags = s
    game:GetService("ReplicatedStorage").GameInfo:SetAttribute("InfiniteAmmo", s)
    Window:Notify("Infinite Magazines", s and "Enabled" or "Disabled", 2)
end)

AmmoSection:NewToggle("Free Rainbow Bullets", "Unlock rainbow bullets gamepass", function(state)
    toggleRainbowBullets(state)
    Window:Notify("Rainbow Bullets", state and "Enabled" or "Disabled", 2)
end)

AmmoSection:NewLabel("🌈 Cosmetic only - no performance impact")


----------------------------------------------------------------
-- VISUALS TAB
----------------------------------------------------------------
local VisualsTab = Window:NewTab("Visuals")
local BoxSection = VisualsTab:NewSection("ESP Box")
local SnaplineSection = VisualsTab:NewSection("Snapline ESP")
local ChamsSection = VisualsTab:NewSection("Chams")
local ESPTagSection = VisualsTab:NewSection("ESP Tags")
local RainbowSection = VisualsTab:NewSection("Rainbow Options")

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Workspace = game:GetService("Workspace")
local MobsFolder = Workspace:FindFirstChild("Mobs")

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
-- Box ESP
local BoxEnabled = false
local BoxStyle = "Corner"
local BoxThickness = 2
local BoxMaxDistance = 500
local BoxColor = Color3.fromRGB(0, 255, 0)

-- Snaplines
local SnaplinesEnabled = false
local LineWidth = 2
local LineOriginMode = "Bottom"
local PlayerEnemyLineColor = Color3.fromRGB(255, 255, 255)
local NPCEnemyLineColor = Color3.fromRGB(255, 0, 0)

-- Chams
local ChamsEnabled = false
local ChamsTransparency = 0.5
local ChamsRainbow = false
local activeCHAMS = {}

-- ESP Tags
local ESPTagsEnabled = false
local ESPTagColor = Color3.fromRGB(255,0,0)
local ESPTagRainbow = false
local ESP_CONNECTIONS = {}

-- Rainbow
local RainbowMaster = false
local RainbowSnapline = false
local RainbowBox = false
local RainbowSpeed = 5 -- seconds per full cycle

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function HSVtoRGB(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local mod = i % 6
    if mod == 0 then return v, t, p
    elseif mod == 1 then return q, v, p
    elseif mod == 2 then return p, v, t
    elseif mod == 3 then return p, q, v
    elseif mod == 4 then return t, p, v
    elseif mod == 5 then return v, p, q end
end

local function GetRainbowColor()
    local safeSpeed = math.max(0.1, RainbowSpeed)
    local hue = (tick() % safeSpeed) / safeSpeed
    local r, g, b = HSVtoRGB(hue, 1, 1)
    return Color3.new(r, g, b)
end

local function GetLineOrigin()
    local vs = Camera.ViewportSize
    if LineOriginMode == "Bottom" then
        return Vector2.new(vs.X/2, vs.Y * 0.9)
    elseif LineOriginMode == "Top" then
        return Vector2.new(vs.X/2, 0)
    elseif LineOriginMode == "Center" then
        return Vector2.new(vs.X/2, vs.Y/2)
    elseif LineOriginMode == "Mouse" then
        return Vector2.new(Mouse.X, Mouse.Y)
    else
        return Vector2.new(vs.X/2, vs.Y * 0.9)
    end
end

local function IsEnemy(target)
    if not target then return false end
    if target == LocalPlayer.Character then return false end
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return target:FindFirstChild("EnemyHighlight") ~= nil
end

local function studsToMeters(studs)
    return studs / 3
end

----------------------------------------------------------------
-- CLEANUP FUNCTION
----------------------------------------------------------------
local Boxes = {}
local SnaplineFrames = {}

local function RemoveBox(target)
    if Boxes[target] then
        for _, line in pairs(Boxes[target].Lines) do pcall(function() line:Remove() end) end
        for _, c in ipairs(Boxes[target].Connectors) do pcall(function() c:Remove() end) end
        Boxes[target] = nil
    end
end

local function CleanupBoxes()
    for target, _ in pairs(Boxes) do RemoveBox(target) end
    Boxes = {}
end

local function CleanupSnaplines()
    for i = #SnaplineFrames, 1, -1 do
        local f = SnaplineFrames[i]
        if f and f.Parent then f:Destroy() end
        table.remove(SnaplineFrames, i)
    end
end

local function clearESPConnections()
    for _, conn in ipairs(ESP_CONNECTIONS) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(ESP_CONNECTIONS)
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BillboardGui") and obj.Name == "EnemyESP" then
            obj:Destroy()
        end
    end
end

local function FullCleanup()
    CleanupBoxes()
    CleanupSnaplines()
    clearESPConnections()
    for obj, _ in pairs(activeCHAMS) do
        if obj and obj.Parent then obj.Enabled = false end
    end
end

local function SafetyPass()
    for target, _ in pairs(Boxes) do
        if not target or not target.Parent or not IsEnemy(target) then RemoveBox(target) end
    end
end

----------------------------------------------------------------
-- SNAPLINES
----------------------------------------------------------------
local Gui = Instance.new("ScreenGui")
Gui.Name = "SnaplineGui"
Gui.ResetOnSpawn = false
Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local function SetLine(Line, Color, Origin, Destination)
    local Position = (Origin + Destination) / 2
    Line.Position = UDim2.new(0, Position.X, 0, Position.Y)
    local Length = (Origin - Destination).Magnitude
    Line.Size = UDim2.new(0, Length, 0, LineWidth)
    Line.BackgroundColor3 = Color
    Line.BorderSizePixel = 0
    Line.Rotation = math.deg(math.atan2(Destination.Y - Origin.Y, Destination.X - Origin.X))
end

----------------------------------------------------------------
-- BOX ESP FUNCTIONS
----------------------------------------------------------------
local function CreateBox(target)
    RemoveBox(target)
    Boxes[target] = {Lines = {}, Connectors = {}}
    local parts = {"TopLeft","TopRight","BottomLeft","BottomRight","Left","Right","Top","Bottom"}
    for _, name in ipairs(parts) do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Thickness = BoxThickness
        line.Color = BoxColor
        Boxes[target].Lines[name] = line
    end
    for i=1,4 do
        local l = Drawing.new("Line")
        l.Visible = false
        l.Thickness = BoxThickness
        l.Color = BoxColor
        table.insert(Boxes[target].Connectors, l)
    end
end

local function UpdateBox(target)
    local esp = Boxes[target]
    if not esp then return end
    local hrp = target:FindFirstChild("HumanoidRootPart")
    if not IsEnemy(target) or not hrp then
        for _, line in pairs(esp.Lines) do line.Visible = false end
        for _, c in ipairs(esp.Connectors) do c.Visible = false end
        return
    end

    local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
    if distance > BoxMaxDistance then
        for _, line in pairs(esp.Lines) do line.Visible = false end
        for _, c in ipairs(esp.Connectors) do c.Visible = false end
        return
    end

    local size = target:GetExtentsSize()
    local cf = hrp.CFrame
    local top, onTop = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y/2, 0)).Position)
    local bottom, onBottom = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y/2, 0)).Position)
    if not (onTop and onBottom) then
        for _, line in pairs(esp.Lines) do line.Visible = false end
        for _, c in ipairs(esp.Connectors) do c.Visible = false end
        return
    end

    local screenHeight = bottom.Y - top.Y
    local boxWidth = screenHeight * 0.65
    local boxPos = Vector2.new(top.X - boxWidth/2, top.Y)
    local boxSize = Vector2.new(boxWidth, screenHeight)
    local color = (RainbowMaster and RainbowBox) and GetRainbowColor() or BoxColor

    if BoxStyle == "Full" then
        esp.Lines.Top.From = boxPos
        esp.Lines.Top.To = boxPos + Vector2.new(boxSize.X,0)
        esp.Lines.Bottom.From = boxPos + Vector2.new(0,boxSize.Y)
        esp.Lines.Bottom.To = boxPos + boxSize
        esp.Lines.Left.From = boxPos
        esp.Lines.Left.To = boxPos + Vector2.new(0,boxSize.Y)
        esp.Lines.Right.From = boxPos + Vector2.new(boxSize.X,0)
        esp.Lines.Right.To = boxPos + boxSize
        for _, k in pairs({"Top","Bottom","Left","Right"}) do
            esp.Lines[k].Visible = true
            esp.Lines[k].Color = color
            esp.Lines[k].Thickness = BoxThickness
        end
        for _, k in pairs({"TopLeft","TopRight","BottomLeft","BottomRight"}) do esp.Lines[k].Visible = false end
        for _, c in ipairs(esp.Connectors) do c.Visible = false end

    elseif BoxStyle == "Corner" then
        local cSize = boxWidth * 0.2
        esp.Lines.TopLeft.From = boxPos
        esp.Lines.TopLeft.To = boxPos + Vector2.new(cSize,0)
        esp.Lines.Left.From = boxPos
        esp.Lines.Left.To = boxPos + Vector2.new(0,cSize)
        esp.Lines.TopRight.From = boxPos + Vector2.new(boxSize.X - cSize,0)
        esp.Lines.TopRight.To = boxPos + Vector2.new(boxSize.X,0)
        esp.Lines.Right.From = boxPos + Vector2.new(boxSize.X,0)
        esp.Lines.Right.To = boxPos + Vector2.new(boxSize.X,cSize)
        esp.Lines.BottomLeft.From = boxPos + Vector2.new(0, boxSize.Y)
        esp.Lines.BottomLeft.To = boxPos + Vector2.new(cSize, boxSize.Y)
        esp.Lines.Bottom.From = boxPos + Vector2.new(0, boxSize.Y - cSize)
        esp.Lines.Bottom.To = boxPos + Vector2.new(0, boxSize.Y)
        esp.Lines.BottomRight.From = boxPos + Vector2.new(boxSize.X - cSize, boxSize.Y)
        esp.Lines.BottomRight.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
        esp.Lines.Top.From = boxPos + Vector2.new(boxSize.X, boxSize.Y - cSize)
        esp.Lines.Top.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
        for _, k in pairs({"TopLeft","TopRight","BottomLeft","BottomRight","Left","Right","Top","Bottom"}) do
            esp.Lines[k].Visible = true
            esp.Lines[k].Color = color
            esp.Lines[k].Thickness = BoxThickness
        end
        for _, c in ipairs(esp.Connectors) do c.Visible = false end

    elseif BoxStyle == "ThreeD" then
        local half = size/2
        local corners = {
            cf * Vector3.new(-half.X,  half.Y, -half.Z),
            cf * Vector3.new( half.X,  half.Y, -half.Z),
            cf * Vector3.new(-half.X, -half.Y, -half.Z),
            cf * Vector3.new( half.X, -half.Y, -half.Z),
            cf * Vector3.new(-half.X,  half.Y,  half.Z),
            cf * Vector3.new( half.X,  half.Y,  half.Z),
            cf * Vector3.new(-half.X, -half.Y,  half.Z),
            cf * Vector3.new( half.X, -half.Y,  half.Z)
        }
        local points = {}
        for i, pos in ipairs(corners) do
            local screen, vis = Camera:WorldToViewportPoint(pos)
            points[i] = Vector2.new(screen.X, screen.Y)
        end
        esp.Lines.TopLeft.From, esp.Lines.TopLeft.To = points[1], points[2]
        esp.Lines.TopRight.From, esp.Lines.TopRight.To = points[2], points[4]
        esp.Lines.BottomRight.From, esp.Lines.BottomRight.To = points[4], points[3]
        esp.Lines.BottomLeft.From, esp.Lines.BottomLeft.To = points[3], points[1]
        esp.Lines.Top.From, esp.Lines.Top.To = points[5], points[6]
        esp.Lines.Right.From, esp.Lines.Right.To = points[6], points[8]
        esp.Lines.Bottom.From, esp.Lines.Bottom.To = points[8], points[7]
        esp.Lines.Left.From, esp.Lines.Left.To = points[7], points[5]
        esp.Connectors[1].From, esp.Connectors[1].To = points[1], points[5]
        esp.Connectors[2].From, esp.Connectors[2].To = points[2], points[6]
        esp.Connectors[3].From, esp.Connectors[3].To = points[3], points[7]
        esp.Connectors[4].From, esp.Connectors[4].To = points[4], points[8]
        for _, k in pairs({"TopLeft","TopRight","BottomLeft","BottomRight","Top","Bottom","Left","Right"}) do
            esp.Lines[k].Visible = true
            esp.Lines[k].Color = color
            esp.Lines[k].Thickness = BoxThickness
        end
        for _, c in ipairs(esp.Connectors) do
            c.Visible = true
            c.Color = color
            c.Thickness = BoxThickness
        end
    end
end

----------------------------------------------------------------
-- CHAMS FUNCTIONS
----------------------------------------------------------------
local function applyCHAMS(obj)
    if not obj or not obj.Parent then return end
    if obj:IsA("Highlight") and obj.Name == "EnemyHighlight" then
        obj.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        obj.FillColor = (RainbowMaster and ChamsRainbow) and GetRainbowColor() or Color3.fromRGB(255,0,0)
        obj.OutlineColor = Color3.fromRGB(0,0,0)
        obj.FillTransparency = 1 - ChamsTransparency
        obj.Enabled = ChamsEnabled
        activeCHAMS[obj] = true
    end
end

local function cleanupCHAMS(obj)
    if activeCHAMS[obj] then activeCHAMS[obj] = nil end
end

local function RefreshChams()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and IsEnemy(plr.Character) then
            for _, obj in ipairs(plr.Character:GetDescendants()) do applyCHAMS(obj) end
        end
    end
    if MobsFolder then
        for _, npc in ipairs(MobsFolder:GetChildren()) do
            if IsEnemy(npc) then
                for _, obj in ipairs(npc:GetDescendants()) do applyCHAMS(obj) end
            end
        end
    end
end

local function setupContainer(container)
    for _, obj in ipairs(container:GetDescendants()) do applyCHAMS(obj) end
    container.DescendantAdded:Connect(applyCHAMS)
    container.DescendantRemoving:Connect(cleanupCHAMS)
end

local function setupPlayer(player)
    if player.Character then setupContainer(player.Character) end
    player.CharacterAdded:Connect(function(char)
        setupContainer(char)
        if ChamsEnabled then task.wait(0.5) RefreshChams() end
    end)
end

local function setupNPC(npc)
    setupContainer(npc)
    npc.AncestryChanged:Connect(function(_, parent)
        if not parent then
            for _, obj in ipairs(npc:GetDescendants()) do cleanupCHAMS(obj) end
        end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
    if player.Character then
        for _, obj in ipairs(player.Character:GetDescendants()) do cleanupCHAMS(obj) end
    end
end)
if MobsFolder then
    for _, npc in ipairs(MobsFolder:GetChildren()) do setupNPC(npc) end
    MobsFolder.ChildAdded:Connect(setupNPC)
end
----------------------------------------------------------------
-- ESP TAGS
----------------------------------------------------------------
local function createESPTag(target, isNPC)
    if not target or not target.Parent then return end
    local rootPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
    if not rootPart then return end
    if target:FindFirstChild("EnemyESP") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EnemyESP"
    billboard.Adornee = rootPart
    billboard.Size = UDim2.new(0, 120, 0, 20)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = ESPTagsEnabled
    billboard.Parent = target

    local label = Instance.new("TextLabel")
    label.Name = "ESPLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = ESPTagColor
    label.TextStrokeTransparency = 0.3
    label.Font = Enum.Font.SourceSansBold
    label.FontSize = Enum.FontSize.Size12
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = ""
    label.Parent = billboard

    local conn = RunService.RenderStepped:Connect(function()
        if ESPTagsEnabled and target and rootPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distanceStuds = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            local distanceMeters = studsToMeters(distanceStuds)
            local displayName = isNPC and "NPC" or target.Name
            label.Text = displayName .. " | " .. string.format("%.1f", distanceMeters) .. " m"
            label.TextColor3 = (RainbowMaster and ESPTagRainbow) and GetRainbowColor() or ESPTagColor
            billboard.Enabled = true
        else
            billboard.Enabled = false
        end
    end)

    table.insert(ESP_CONNECTIONS, conn)
end

local function applyESPTag()
    clearESPConnections()
    if not ESPTagsEnabled then return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            createESPTag(plr.Character, false)
        end
    end
    if MobsFolder then
        for _, mob in pairs(MobsFolder:GetChildren()) do
            createESPTag(mob, true)
        end
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if ESPTagsEnabled then createESPTag(char, false) end
    end)
end)

if MobsFolder then
    MobsFolder.ChildAdded:Connect(function(mob)
        task.wait(0.2)
        if ESPTagsEnabled then createESPTag(mob, true) end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if ESPTagsEnabled then applyESPTag() end
end)

----------------------------------------------------------------
-- RENDER LOOP
----------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    SafetyPass()

    -- Snaplines
    if SnaplinesEnabled then
        local origin = GetLineOrigin()
        local targets = {}
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and IsEnemy(plr.Character) then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local sp, on = Camera:WorldToScreenPoint(hrp.Position)
                    if on then
                        local col = (RainbowMaster and RainbowSnapline) and GetRainbowColor() or PlayerEnemyLineColor
                        table.insert(targets,{Vector2.new(sp.X, sp.Y),col})
                    end
                end
            end
        end
        if MobsFolder then
            for _, mob in ipairs(MobsFolder:GetChildren()) do
                if IsEnemy(mob) then
                    local hrp = mob:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local sp, on = Camera:WorldToScreenPoint(hrp.Position)
                        if on then
                            local col = (RainbowMaster and RainbowSnapline) and GetRainbowColor() or NPCEnemyLineColor
                            table.insert(targets,{Vector2.new(sp.X, sp.Y),col})
                        end
                    end
                end
            end
        end
        for i = #SnaplineFrames + 1, #targets do
            local f = Instance.new("Frame")
            f.AnchorPoint = Vector2.new(0.5,0.5)
            f.BorderSizePixel = 0
            f.Parent = Gui
            table.insert(SnaplineFrames,f)
        end
        for i = #SnaplineFrames, 1, -1 do
            local frame = SnaplineFrames[i]
            local t = targets[i]
            if not t then
                frame:Destroy()
                table.remove(SnaplineFrames,i)
            else
                SetLine(frame,t[2],origin,t[1])
            end
        end
    else CleanupSnaplines() end

    -- Box ESP
    if BoxEnabled then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                if IsEnemy(plr.Character) then
                    if not Boxes[plr.Character] then CreateBox(plr.Character) end
                    UpdateBox(plr.Character)
                else RemoveBox(plr.Character) end
            end
        end
        if MobsFolder then
            for _, mob in ipairs(MobsFolder:GetChildren()) do
                if IsEnemy(mob) then
                    if not Boxes[mob] then CreateBox(mob) end
                    UpdateBox(mob)
                else RemoveBox(mob) end
            end
        end
    else CleanupBoxes() end

    -- Chams rainbow update
    if ChamsEnabled and RainbowMaster and ChamsRainbow then
        for obj, _ in pairs(activeCHAMS) do
            if obj and obj.Parent then
                obj.FillColor = GetRainbowColor()
            end
        end
    end
end)

----------------------------------------------------------------
-- REAPPLY ON RESPAWN
----------------------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if SnaplinesEnabled then SnaplinesEnabled = true end
    if BoxEnabled then BoxEnabled = true end
    if ChamsEnabled then RefreshChams() end
    if ESPTagsEnabled then applyESPTag() end
end)

----------------------------------------------------------------
-- UI CONTROLS
----------------------------------------------------------------
-- ESP Box
BoxSection:NewToggle("ESP Box","Draw boxes around enemies",function(state)
    BoxEnabled = state
    if not state then FullCleanup() end
end)
BoxSection:NewDropdown("Box Style",{"Corner","Full","ThreeD"},function(choice)
    BoxStyle = choice
    FullCleanup()
end)
BoxSection:NewSlider("Box Thickness",1,5,BoxThickness,function(val) BoxThickness = val end)
BoxSection:NewSlider("Max Distance",50,2000,BoxMaxDistance,function(val) BoxMaxDistance = val end)
BoxSection:NewColorpicker("Box Color",BoxColor,function(c) BoxColor=c FullCleanup() end)

-- Snaplines
SnaplineSection:NewToggle("Snaplines","Draw snaplines to enemies",function(state)
    SnaplinesEnabled = state
    if not state then FullCleanup() end
end)
SnaplineSection:NewSlider("Line Width",1,10,LineWidth,function(val) LineWidth=val end)
SnaplineSection:NewDropdown("Line Origin",{"Bottom","Top","Center","Mouse"},function(choice) LineOriginMode=choice end)
SnaplineSection:NewColorpicker("Enemy Player Color",PlayerEnemyLineColor,function(c) PlayerEnemyLineColor=c FullCleanup() end)
SnaplineSection:NewColorpicker("Enemy NPC Color",NPCEnemyLineColor,function(c) NPCEnemyLineColor=c FullCleanup() end)

-- Chams
ChamsSection:NewToggle("Chams","Apply chams to enemies",function(state)
    ChamsEnabled = state
    for obj,_ in pairs(activeCHAMS) do
        if obj and obj.Parent then obj.Enabled = ChamsEnabled end
    end
    if ChamsEnabled then RefreshChams() end
end)
ChamsSection:NewSlider("Transparency",0,1,ChamsTransparency,function(val)
    ChamsTransparency = val
    for obj,_ in pairs(activeCHAMS) do
        if obj and obj.Parent then obj.FillTransparency = 1 - ChamsTransparency end
    end
end)

-- ESP Tags
ESPTagSection:NewToggle("ESP Tags","Show name + distance above enemies",function(state)
    ESPTagsEnabled = state
    if state then applyESPTag() else clearESPConnections() end
end)
ESPTagSection:NewColorpicker("Tag Color",ESPTagColor,function(c)
    ESPTagColor = c
end)

-- Rainbow
RainbowSection:NewToggle("Rainbow Master","Enable rainbow colors",function(state) RainbowMaster=state end)
RainbowSection:NewToggle("Snapline Rainbow","Rainbow for snaplines",function(state) RainbowSnapline=state end)
RainbowSection:NewToggle("ESP Box Rainbow","Rainbow for ESP box",function(state) RainbowBox=state end)
RainbowSection:NewToggle("Chams Rainbow","Rainbow for chams",function(state) ChamsRainbow=state end)
RainbowSection:NewToggle("ESP Tag Rainbow","Rainbow for ESP tags",function(state) ESPTagRainbow=state end)
RainbowSection:NewSlider("Rainbow Speed",1,15,RainbowSpeed,function(val) RainbowSpeed=val end)

----------------------------------------------------------------
-- MOBILE PLAYERS TAB
----------------------------------------------------------------
local PlayersTab = Window:NewTab("Players")
local PlayerSection = PlayersTab:NewSection("Player Mods")

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local state = {
    speedEnabled = false,
    speedMultiplier = 2,
    noclipEnabled = false,
    infiniteJumpEnabled = false,
    flyEnabled = false,
    flySpeed = 50
}

local function getCharacter()
    return LocalPlayer and LocalPlayer.Character
end
local function getHRP()
    local c = getCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = getCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
    if not state.speedEnabled then return end
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return end
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0 then
        local step = moveDir.Unit * state.speedMultiplier
        hrp.CFrame = hrp.CFrame + step
    end
end

local function applyNoclip()
    if not state.noclipEnabled then return end
    local char = getCharacter()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

UserInputService.JumpRequest:Connect(function()
    if state.infiniteJumpEnabled then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- MOBILE FLY: Uses camera direction + mobile joystick
local flyConnection = nil
local flyBodyVelocity = nil

local function createFlyBodyVelocity()
    local hrp = getHRP()
    if not hrp then return end
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
    end
    
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyBodyVelocity.Parent = hrp
end

local function removeFlyBodyVelocity()
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
end

local function flyLoop()
    if flyConnection then flyConnection:Disconnect() end
    
    createFlyBodyVelocity()
    
    flyConnection = RunService.Heartbeat:Connect(function()
        if not state.flyEnabled then
            removeFlyBodyVelocity()
            if flyConnection then flyConnection:Disconnect() flyConnection = nil end
            return
        end
        
        local hrp = getHRP()
        local hum = getHumanoid()
        local cam = workspace.CurrentCamera
        if not hrp or not cam or not hum then return end
        
        if not flyBodyVelocity or flyBodyVelocity.Parent ~= hrp then
            createFlyBodyVelocity()
        end

        -- MOBILE: Get movement from humanoid's MoveDirection (joystick input)
        local moveDirection = hum.MoveDirection
        local camCFrame = cam.CFrame
        
        local flyVelocity = Vector3.new(0, 0, 0)
        
        if moveDirection.Magnitude > 0 then
            -- Calculate direction relative to camera
            local camForward = camCFrame.LookVector
            local camRight = camCFrame.RightVector
            
            -- Project movement onto camera's horizontal plane
            camForward = Vector3.new(camForward.X, 0, camForward.Z).Unit
            camRight = Vector3.new(camRight.X, 0, camRight.Z).Unit
            
            -- Combine forward/backward and left/right movement
            flyVelocity = (camForward * moveDirection.Z + camRight * moveDirection.X) * state.flySpeed
        end
        
        -- Set the velocity
        if flyBodyVelocity then
            flyBodyVelocity.Velocity = flyVelocity
        end
        
        -- Keep humanoid in flying state
        if hum then
            hum.PlatformStand = true
        end
    end)
end

RunService.RenderStepped:Connect(function()
    if not getCharacter() then return end
    applySpeed()
    applyNoclip()
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if state.noclipEnabled then applyNoclip() end
    if state.flyEnabled then 
        removeFlyBodyVelocity()
        flyLoop() 
    end
end)

----------------------------------------------------------------
-- UI CONTROLS
----------------------------------------------------------------
PlayerSection:NewToggle("Speed","Toggle speed hack",function(value)
    state.speedEnabled = value
    Window:Notify("Speed", value and ("Enabled - " .. state.speedMultiplier .. "x") or "Disabled", 2)
end)

PlayerSection:NewSlider("Speed Multiplier",1,10,state.speedMultiplier,function(val)
    state.speedMultiplier = val
    if state.speedEnabled then
        Window:Notify("Speed", "Set to " .. val .. "x", 2)
    end
end)

PlayerSection:NewToggle("Noclip","Toggle noclip",function(value)
    state.noclipEnabled = value
    if value then
        applyNoclip()
        Window:Notify("Noclip", "Enabled", 2)
    else
        Window:Notify("Noclip", "Disabled", 2)
    end
end)

PlayerSection:NewToggle("Infinite Jump","Toggle infinite jump",function(value)
    state.infiniteJumpEnabled = value
    Window:Notify("Infinite Jump", value and "Enabled" or "Disabled", 2)
end)

PlayerSection:NewToggle("Fly","Toggle fly mode (Mobile Optimized)",function(value)
    state.flyEnabled = value
    if value then
        flyLoop()
        Window:Notify("Fly", "Enabled - Use joystick to move", 2)
    else
        if flyConnection then flyConnection:Disconnect() flyConnection = nil end
        removeFlyBodyVelocity()
        local hum = getHumanoid()
        if hum then hum.PlatformStand = false end
        Window:Notify("Fly", "Disabled", 2)
    end
end)

PlayerSection:NewSlider("Fly Speed",10,200,state.flySpeed,function(val)
    state.flySpeed = val
    if state.flyEnabled then
        Window:Notify("Fly", "Speed set to " .. val, 2)
    end
end)

PlayerSection:NewLabel("📱 Mobile Optimized Controls")
PlayerSection:NewLabel("📱 Fly: Use on-screen joystick")
PlayerSection:NewLabel("📱 Aimlock: Tap TOGGLE AIM button")

----------------------------------------------------------------
-- SETTINGS TAB (Interface + Performance)
----------------------------------------------------------------
local SettingsTab = Window:NewTab("Settings")

local InterfaceSection = SettingsTab:NewSection("Interface")
InterfaceSection:NewDropdown("Select Theme", Window:GetThemeList(), function(theme)
    if theme then
        Window:SetTheme(theme)
        Window:Notify("Theme Changed", "Applied theme: " .. tostring(theme), 2)
    end
end)

InterfaceSection:NewKeybind("Toggle UI", Enum.KeyCode.RightShift, function()
    Window:ToggleUI()
end)

local PerfSection = SettingsTab:NewSection("Performance")
local lighting = game:GetService("Lighting")
local normalBrightness = lighting.Brightness
local fullBrightEnabled = false

PerfSection:NewToggle("Full Bright", "Set lighting to max brightness", function(state)
    fullBrightEnabled = state
    if state then
        lighting.Brightness = 2
        lighting.ClockTime = 12
        lighting.FogEnd = 1e6
        Window:Notify("Full Bright", "Enabled", 2)
    else
        lighting.Brightness = normalBrightness
        Window:Notify("Full Bright", "Disabled", 2)
    end
end)

local fpsBoosterEnabled = false
PerfSection:NewToggle("FPS Booster", "Lower graphics for performance", function(state)
    fpsBoosterEnabled = state
    if fpsBoosterEnabled then
        -- Apply low-detail settings
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = false
            end
        end
        lighting.GlobalShadows = false
        lighting.FogEnd = 9e9
        Window:Notify("FPS Booster", "Enabled", 2)
    else
        -- Restore defaults
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 0
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = true
            end
        end
        lighting.GlobalShadows = true
        lighting.FogEnd = 1000
        lighting.Brightness = normalBrightness
        Window:Notify("FPS Booster", "Disabled — performance restored", 2)
    end
end)

----------------------------------------------------------------
-- BOOT MESSAGE
----------------------------------------------------------------
Window:Notify("Kour6anHub", "Hypershot Mobile Script Loaded", 4)
