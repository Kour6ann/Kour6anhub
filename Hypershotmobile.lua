-- Load Kour6anHub Library
local Kour6an = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kour6ann/Kour6anhub/main/Kour6anhub.lua"))()
local Window = Kour6an.CreateLib("Kour6anHub Mobile - Hypershot", "BloodTheme")

-- Mobile Detection
local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

----------------------------------------------------------------
-- INFO TAB
----------------------------------------------------------------
local InfoTab = Window:NewTab("Info")
local InfoTitleSection = InfoTab:NewSection("⚔️ Welcome to Kour6anHUB Mobile ⚔️")
InfoTitleSection:NewLabel("────────────────────────────")
InfoTitleSection:NewLabel(" Best HyperShot Mobile Script ")
InfoTitleSection:NewLabel("────────────────────────────")

local InfoSection = InfoTab:NewSection("ℹ️ Hub Information")
InfoSection:NewLabel("Hub: Kour6anHUB - HyperShot Mobile")
InfoSection:NewLabel("Version: 2.0 Mobile")
InfoSection:NewLabel(" 📱 Optimized for Mobile Devices!")
InfoSection:NewLabel(" 📌 Most functions support TeamCheck!")
InfoSection:NewLabel(" ⚠️ Don't use in DUELS!")
InfoSection:NewLabel(" 📌 YOU'LL GET INSTA BAN IN DUELS!")
InfoSection:NewLabel("────────────────────────────")

local CreditsSection = InfoTab:NewSection("👑 Credits")
CreditsSection:NewLabel("Created by: Kour6an")
CreditsSection:NewLabel("Mobile Version by: Community")
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
FooterSection:NewLabel("Mobile controls optimized!")
FooterSection:NewLabel("────────────────────────────")

----------------------------------------------------------------
-- AIMING TAB (MOBILE OPTIMIZED)
----------------------------------------------------------------
local AimingTab = Window:NewTab("Aiming")

----------------------------------------------------------------
-- GENERAL SETTINGS SECTION
----------------------------------------------------------------
local GeneralSettingsSection = AimingTab:NewSection("⚙️ General Settings")

local sharedConfig = {
    teamCheck = true,
    wallCheck = true
}

GeneralSettingsSection:NewToggle("Team Check", "Ignore teammates", function(state)
    sharedConfig.teamCheck = state
    Window:Notify("Team Check", state and "Enabled" or "Disabled", 2)
end)

GeneralSettingsSection:NewToggle("Wall Check", "Check walls between targets", function(state)
    sharedConfig.wallCheck = state
    Window:Notify("Wall Check", state and "Enabled" or "Disabled", 2)
end)

----------------------------------------------------------------
-- SILENT AIM SECTION (Mobile Compatible)
----------------------------------------------------------------
local SilentAimSection = AimingTab:NewSection("🎯 Silent Aim (Auto)")

local MainESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/alohabeach/Main/refs/heads/master/utils/esp/source.lua"))()

local client = {
    gameui = require(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("GameUI"):WaitForChild("GameUIMod"));
    oldfunction = {};
}

client.oldfunction.GetMousePos = clonefunction(client.gameui.GetMousePos)

local config = {
    silentaimenabled = false;
    silentaimradius = 150; -- Increased for mobile
    fovCircleVisible = false;
    fovCircleColor = Color3.fromRGB(255, 255, 255);
    targetPart = "Head";
    teamCheck = true;
}

-- Mobile touch position helper
local function getTouchPosition()
    if UserInputService.TouchEnabled then
        local touchPositions = UserInputService:GetTouchPosition()
        if touchPositions and #touchPositions > 0 then
            local firstTouch = touchPositions[1]
            if firstTouch then
                return Vector2.new(firstTouch.X, firstTouch.Y)
            end
        end
    end
    return UserInputService:GetMouseLocation()
end

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

client.getNearestToCursor = function()
    local inputPos = getTouchPosition()
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
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(inputPos.X, inputPos.Y)).Magnitude
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

SilentAimSection:NewToggle("Enable Silent Aim", "Auto-aims at nearest enemy", function(state)
    config.silentaimenabled = state
    Window:Notify("Silent Aim", state and "Enabled (Auto)" or "Disabled", 2)
end)

SilentAimSection:NewSlider("FOV Radius", 100, 500, 150, function(value)
    config.silentaimradius = value
    Circle.Radius = value
end)

SilentAimSection:NewToggle("Show FOV Circle", "Display detection radius", function(state)
    config.fovCircleVisible = state
    Circle.Visible = state
end)

SilentAimSection:NewDropdown("Target Part", {"Head", "FakeHRP", "Auto (Both)"}, function(choice)
    config.targetPart = choice == "Auto (Both)" and "Auto" or choice
    Window:Notify("Target Part", "Now targeting: "..choice, 2)
end)

SilentAimSection:NewLabel("📱 Works automatically when shooting!")

----------------------------------------------------------------
-- MOBILE AIMLOCK SECTION
----------------------------------------------------------------
local AimlockSection = AimingTab:NewSection("🔒 Aimlock (Touch)")

_G.Disabled = false
_G.Aimlock = false
_G.ShowFOV = false
_G.FOVRadius = 200 -- Larger for mobile
_G.WallCheck = true
_G.TargetPart = "Head"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local aiming = false
local currentTarget = nil

-- Mobile touch detection
local touchStart = nil
UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
    if not gameProcessed and _G.Aimlock then
        touchStart = touch
        aiming = true
        currentTarget = nil
    end
end)

UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
    if touchStart == touch then
        aiming = false
        currentTarget = nil
        touchStart = nil
    end
end)

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

local function getClosestEnemy(inputPos)
    local closestEnemy, smallestDist = nil, math.huge
    for _, enemy in ipairs(getAllEnemies()) do
        local targetPart = getTargetPart(enemy)
        if targetPart then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - inputPos).Magnitude
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

local function isTargetValid(target, inputPos)
    if not target or not target.Parent then return false end
    local targetPart = getTargetPart(target)
    if not targetPart then return false end
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - inputPos).Magnitude
    if dist > _G.FOVRadius then return false end
    if isWallBetween(Camera.CFrame.Position, targetPart, target) then return false end
    if not isEnemyAimlock(target) then return false end
    return true
end

RunService.RenderStepped:Connect(function()
    if not FOVCircle then return end
    if _G.Disabled or not _G.Aimlock or not _G.ShowFOV then
        FOVCircle.Visible = false
    else
        FOVCircle.Visible = true
        FOVCircle.Radius = _G.FOVRadius
        FOVCircle.Position = getTouchPosition()
    end
    local inputPos = getTouchPosition()
    if _G.Aimlock and aiming then
        if currentTarget and isTargetValid(currentTarget, inputPos) then
            local targetPart = getTargetPart(currentTarget)
            if targetPart then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
            end
        else
            currentTarget = getClosestEnemy(inputPos)
            if currentTarget then
                local targetPart = getTargetPart(currentTarget)
                if targetPart then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                end
            end
        end
    end
end)

AimlockSection:NewToggle("Enable Aimlock", "Toggle aimlock", function(state)
    _G.Aimlock = state
    _G.ShowFOV = state
    Window:Notify("Aimlock", state and "Enabled" or "Disabled", 2)
end)

AimlockSection:NewDropdown("Target Part", {"Head", "HumanoidRootPart", "UpperTorso"}, function(choice)
    _G.TargetPart = choice
    Window:Notify("Target Part", "Changed to: " .. choice, 2)
end)

AimlockSection:NewSlider("FOV Radius", 100, 500, 200, function(value)
    _G.FOVRadius = value
    if FOVCircle then FOVCircle.Radius = value end
end)

AimlockSection:NewLabel("📱 Hold screen to activate aimlock")
AimlockSection:NewLabel("📌 Auto team check enabled")

----------------------------------------------------------------
-- AUTO FARM TAB (Mobile Optimized)
----------------------------------------------------------------
local AutoFarmTab = Window:NewTab("AutoFarm")
local FlagSection = AutoFarmTab:NewSection("Auto FLAG")
local TPEnemySection = AutoFarmTab:NewSection("TP to Enemy")

local rs = game:GetService("RunService")
local ws = game:GetService("Workspace")
local plrs = game:GetService("Players")
local lp = plrs.LocalPlayer or LocalPlayer
local camAF = ws.CurrentCamera

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

local cfg = {
    enabled = false,
    tpDist = 7,
    switchDelay = 2,
    maxRange = 300,
    shootDelay = 0.1
}

local state = {
    target = nil,
    lastSwitch = 0,
    targetIdx = 1,
    lastShoot = 0,
    connection = nil
}

local function getEnemiesInRange()
    local enemies = {}
    local myChar = lp.Character
    
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then 
        return enemies 
    end
    
    local myHRP = myChar.HumanoidRootPart
    local myTeam = myChar:GetAttribute("Team")
    
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

local function isTargetValid(t)
    if not t then return false end
    local obj = t.obj
    if not obj or not obj.Parent then return false end
    local hum = obj:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return obj:FindFirstChild("HumanoidRootPart") ~= nil
end

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

FlagSection:NewToggle("Auto Flag", "Auto capture flags", function(s)
    autoFlagEnabled = s
    Window:Notify("AutoFlag", s and "Enabled" or "Disabled", 2)
end)
FlagSection:NewLabel("📱 Works automatically!")

TPEnemySection:NewToggle("TP to Enemy", "Auto TP & shoot", function(s)
    cfg.enabled = s
    Window:Notify("TP to Enemy", s and "Enabled" or "Disabled", 2)
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

TPEnemySection:NewLabel("📱 Auto-Shoot ON when enabled!")

----------------------------------------------------------------
-- WEAPONS TAB (Mobile Optimized)
----------------------------------------------------------------
local WeaponsTab = Window:NewTab("Weapons")
local AmmoSection = WeaponsTab:NewSection("Ammo Management")

local plr = game:GetService("Players").LocalPlayer

local weaponState = {
    infiniteAmmo = false,
    infiniteMags = false,
    freeRainbowBullets = false
}

local function getMainGui()
    return plr.PlayerGui:FindFirstChild("MainGui") or nil
end

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

local function toggleRainbowBullets(state)
    weaponState.freeRainbowBullets = state
    game.Players.LocalPlayer:SetAttribute("RainbowBullets", state)
end

AmmoSection:NewLabel("🔫 Ammo Management")

AmmoSection:NewToggle("Infinite Ammo", "Unlimited ammo", function(s)
    weaponState.infiniteAmmo = s
    Window:Notify("Infinite Ammo", s and "Enabled" or "Disabled", 2)
end)

AmmoSection:NewToggle("Infinite Magazines", "Unlimited reserves", function(s)
    weaponState.infiniteMags = s
    game:GetService("ReplicatedStorage").GameInfo:SetAttribute("InfiniteAmmo", s)
    Window:Notify("Infinite Magazines", s and "Enabled" or "Disabled", 2)
end)

AmmoSection:NewToggle("Free Rainbow Bullets", "Unlock rainbow bullets", function(state)
    toggleRainbowBullets(state)
    Window:Notify("Rainbow Bullets", state and "Enabled" or "Disabled", 2)
end)

----------------------------------------------------------------
-- VISUALS TAB (Simplified for Mobile Performance)
----------------------------------------------------------------
local VisualsTab = Window:NewTab("Visuals")
local ESPSection = VisualsTab:NewSection("ESP (Mobile Optimized)")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local MobsFolder = Workspace:FindFirstChild("Mobs")

local ESPEnabled = false
local ESPColor = Color3.fromRGB(255, 0, 0)
local ESP_CONNECTIONS = {}

local function IsEnemy(target)
    if not target then return false end
    if target == LocalPlayer.Character then return false end
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return target:FindFirstChild("EnemyHighlight") ~= nil
end

local function clearESPConnections()
    for _, conn in ipairs(ESP_CONNECTIONS) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(ESP_CONNECTIONS)
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BillboardGui") and obj.Name == "MobileESP" then
            obj:Destroy()
        end
    end
end

local function createMobileESP(target)
    if not target or not target.Parent then return end
    local rootPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
    if not rootPart then return end
    if target:FindFirstChild("MobileESP") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MobileESP"
    billboard.Adornee = rootPart
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = ESPEnabled
    billboard.Parent = target

    local label = Instance.new("TextLabel")
    label.Name = "ESPLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = ESPColor
    label.TextStrokeTransparency = 0.3
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 18
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = ""
    label.Parent = billboard

    local conn = RunService.RenderStepped:Connect(function()
        if ESPEnabled and target and rootPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            local distanceMeters = distance / 3
            label.Text = target.Name .. "\n" .. string.format("%.0f", distanceMeters) .. "m"
            label.TextColor3 = ESPColor
            billboard.Enabled = true
        else
            billboard.Enabled = false
        end
    end)

    table.insert(ESP_CONNECTIONS, conn)
end

local function applyMobileESP()
    clearESPConnections()
    if not ESPEnabled then return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            createMobileESP(plr.Character)
        end
    end
    if MobsFolder then
        for _, mob in pairs(MobsFolder:GetChildren()) do
            createMobileESP(mob)
        end
    end
end

ESPSection:NewToggle("Enable ESP", "Show enemy names & distance", function(state)
    ESPEnabled = state
    if state then applyMobileESP() else clearESPConnections() end
    Window:Notify("ESP", state and "Enabled" or "Disabled", 2)
end)

ESPSection:NewColorpicker("ESP Color", ESPColor, function(c)
    ESPColor = c
end)

ESPSection:NewLabel("📱 Lightweight ESP for mobile!")

----------------------------------------------------------------
-- PLAYERS TAB (Mobile Controls)
----------------------------------------------------------------
local PlayersTab = Window:NewTab("Players")
local PlayerSection = PlayersTab:NewSection("Player Mods")

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

-- Speed
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

-- Noclip
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

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if state.infiniteJumpEnabled then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Mobile Fly Controls
local FlyGui = Instance.new("ScreenGui")
FlyGui.Name = "MobileFlyControls"
FlyGui.ResetOnSpawn = false
FlyGui.Enabled = false

local function createFlyButton(name, position, text)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 80, 0, 80)
    button.Position = position
    button.Text = text
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 24
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.BackgroundTransparency = 0.3
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = button
    
    button.Parent = FlyGui
    return button
end

-- Create fly control buttons
local upBtn = createFlyButton("UpBtn", UDim2.new(0.5, -40, 0.3, -120), "↑")
local downBtn = createFlyButton("DownBtn", UDim2.new(0.5, -40, 0.3, 80), "↓")
local forwardBtn = createFlyButton("ForwardBtn", UDim2.new(0.5, -40, 0.3, -40), "W")
local leftBtn = createFlyButton("LeftBtn", UDim2.new(0.5, -130, 0.3, -40), "A")
local rightBtn = createFlyButton("RightBtn", UDim2.new(0.5, 50, 0.3, -40), "D")

FlyGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local flyDirections = {
    up = false,
    down = false,
    forward = false,
    left = false,
    right = false
}

upBtn.MouseButton1Down:Connect(function() flyDirections.up = true end)
upBtn.MouseButton1Up:Connect(function() flyDirections.up = false end)
downBtn.MouseButton1Down:Connect(function() flyDirections.down = true end)
downBtn.MouseButton1Up:Connect(function() flyDirections.down = false end)
forwardBtn.MouseButton1Down:Connect(function() flyDirections.forward = true end)
forwardBtn.MouseButton1Up:Connect(function() flyDirections.forward = false end)
leftBtn.MouseButton1Down:Connect(function() flyDirections.left = true end)
leftBtn.MouseButton1Up:Connect(function() flyDirections.left = false end)
rightBtn.MouseButton1Down:Connect(function() flyDirections.right = true end)
rightBtn.MouseButton1Up:Connect(function() flyDirections.right = false end)

local function flyLoop()
    while state.flyEnabled do
        task.wait()
        local hrp = getHRP()
        local cam = workspace.CurrentCamera
        if not hrp or not cam then continue end

        local moveDirection = Vector3.new()
        if flyDirections.forward then moveDirection += cam.CFrame.LookVector end
        if flyDirections.left then moveDirection -= cam.CFrame.RightVector end
        if flyDirections.right then moveDirection += cam.CFrame.RightVector end
        if flyDirections.up then moveDirection += Vector3.new(0,1,0) end
        if flyDirections.down then moveDirection -= Vector3.new(0,1,0) end

        if moveDirection.Magnitude > 0 then
            hrp.Velocity = moveDirection.Unit * state.flySpeed
        else
            hrp.Velocity = Vector3.zero
        end
    end
    local hrp = getHRP()
    if hrp then hrp.Velocity = Vector3.zero end
end

RunService.RenderStepped:Connect(function()
    if not getCharacter() then return end
    applySpeed()
    applyNoclip()
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if state.noclipEnabled then applyNoclip() end
    if state.flyEnabled then task.spawn(flyLoop) end
end)

-- UI Controls
PlayerSection:NewToggle("Speed", "Toggle speed hack", function(value)
    state.speedEnabled = value
    Window:Notify("Speed", value and "Enabled" or "Disabled", 2)
end)

PlayerSection:NewSlider("Speed Multiplier", 1, 10, state.speedMultiplier, function(val)
    state.speedMultiplier = val
end)

PlayerSection:NewToggle("Noclip", "Toggle noclip", function(value)
    state.noclipEnabled = value
    if value then applyNoclip() end
    Window:Notify("Noclip", value and "Enabled" or "Disabled", 2)
end)

PlayerSection:NewToggle("Infinite Jump", "Toggle infinite jump", function(value)
    state.infiniteJumpEnabled = value
    Window:Notify("Infinite Jump", value and "Enabled" or "Disabled", 2)
end)

PlayerSection:NewToggle("Fly", "Toggle fly mode", function(value)
    state.flyEnabled = value
    FlyGui.Enabled = value
    if value then
        task.spawn(flyLoop)
        Window:Notify("Fly", "Enabled - Use on-screen controls", 3)
    else
        Window:Notify("Fly", "Disabled", 2)
    end
end)

PlayerSection:NewSlider("Fly Speed", 10, 200, state.flySpeed, function(val)
    state.flySpeed = val
end)

PlayerSection:NewLabel("📱 Fly uses on-screen buttons!")

----------------------------------------------------------------
-- SETTINGS TAB
----------------------------------------------------------------
local SettingsTab = Window:NewTab("Settings")

local InterfaceSection = SettingsTab:NewSection("Interface")
InterfaceSection:NewDropdown("Select Theme", Window:GetThemeList(), function(theme)
    if theme then
        Window:SetTheme(theme)
        Window:Notify("Theme Changed", "Applied: " .. tostring(theme), 2)
    end
end)

InterfaceSection:NewButton("Toggle UI", "Show/Hide UI", function()
    Window:ToggleUI()
end)

local PerfSection = SettingsTab:NewSection("Performance (Mobile)")
local lighting = game:GetService("Lighting")
local normalBrightness = lighting.Brightness
local fullBrightEnabled = false

PerfSection:NewToggle("Full Bright", "Max brightness", function(state)
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
        -- Low-detail settings for mobile
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
                v.CastShadow = false
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = false
            elseif v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = false
            end
        end
        lighting.GlobalShadows = false
        lighting.FogEnd = 9e9
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Window:Notify("FPS Booster", "Enabled - Mobile optimized", 2)
    else
        -- Restore
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Material = Enum.Material.Plastic
                v.CastShadow = true
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 0
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = true
            elseif v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = true
            end
        end
        lighting.GlobalShadows = true
        lighting.FogEnd = 1000
        lighting.Brightness = normalBrightness
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        Window:Notify("FPS Booster", "Disabled", 2)
    end
end)

PerfSection:NewLabel("📱 Recommended for mobile devices!")

local MobileSection = SettingsTab:NewSection("📱 Mobile Info")
MobileSection:NewLabel("Device: " .. (isMobile and "Mobile" or "Desktop"))
MobileSection:NewLabel("Touch Enabled: " .. tostring(UserInputService.TouchEnabled))
MobileSection:NewLabel("────────────────────────────")
MobileSection:NewLabel("Tips:")
MobileSection:NewLabel("• Aimlock: Hold screen to activate")
MobileSection:NewLabel("• Fly: Use on-screen buttons")
MobileSection:NewLabel("• Enable FPS Booster for better performance")
MobileSection:NewLabel("• Silent Aim works automatically")

----------------------------------------------------------------
-- BOOT MESSAGE
----------------------------------------------------------------
Window:Notify("Kour6anHub Mobile", "Hypershot Script Loaded", 4)
Window:Notify("Mobile Optimized", "Touch controls enabled!", 3)
