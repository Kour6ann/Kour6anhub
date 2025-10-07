-- Load Kour6anHub Library
local Kour6an = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kour6ann/Kour6anhub/main/Kour6anhub.lua"))()
local Window = Kour6an.CreateLib("Kour6anHub Mobile - Hypershot", "BloodTheme")

-- Mobile Check
local UserInputService = game:GetService("UserInputService")
if not UserInputService.TouchEnabled then
    game:GetService("Players").LocalPlayer:Kick("⚠️ This script is MOBILE ONLY! Use the PC version instead.")
    return
end

----------------------------------------------------------------
-- INFO TAB
----------------------------------------------------------------
local InfoTab = Window:NewTab("📱 Info")
local InfoTitleSection = InfoTab:NewSection("⚔️ MOBILE EDITION ⚔️")
InfoTitleSection:NewLabel("────────────────────────────")
InfoTitleSection:NewLabel(" Kour6anHUB Mobile - HyperShot ")
InfoTitleSection:NewLabel("────────────────────────────")

local InfoSection = InfoTab:NewSection("ℹ️ Hub Information")
InfoSection:NewLabel("Version: 2.0 Mobile Pure")
InfoSection:NewLabel("Platform: Mobile Devices Only")
InfoSection:NewLabel("")
InfoSection:NewLabel("📱 Touch Controls Enabled")
InfoSection:NewLabel("📌 Team Check Supported")
InfoSection:NewLabel("⚠️ NEVER USE IN DUELS!")
InfoSection:NewLabel("🚫 INSTA BAN IN DUELS!")
InfoSection:NewLabel("────────────────────────────")

local CreditsSection = InfoTab:NewSection("👑 Credits")
CreditsSection:NewLabel("Created by: Kour6an")
CreditsSection:NewLabel("Mobile Optimized Edition")
CreditsSection:NewLabel("Discord: discord.gg/3ZqFVq3ZJ")
CreditsSection:NewLabel("YouTube: youtube.com/@kour6an")

CreditsSection:NewButton("📋 Copy Discord Link", "Click to copy", function()
    setclipboard("https://discord.gg/3ZqFVq3ZJ")
    Window:Notify("Copied!", "Discord link copied", 3)
end)

CreditsSection:NewButton("📋 Copy YouTube Link", "Click to copy", function()
    setclipboard("https://www.youtube.com/@kour6an")
    Window:Notify("Copied!", "YouTube link copied", 3)
end)

local FooterSection = InfoTab:NewSection("📢 Mobile Features")
FooterSection:NewLabel("✓ Touch-based aimlock")
FooterSection:NewLabel("✓ On-screen fly controls")
FooterSection:NewLabel("✓ Auto-aim built-in")
FooterSection:NewLabel("✓ Performance optimized")
FooterSection:NewLabel("────────────────────────────")

----------------------------------------------------------------
-- AIMING TAB (PURE MOBILE)
----------------------------------------------------------------
local AimingTab = Window:NewTab("🎯 Aiming")

----------------------------------------------------------------
-- TOUCH POSITION TRACKER
----------------------------------------------------------------
local touchState = {
    currentPosition = nil,
    isTouching = false,
    activeTouches = {}
}

UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
    touchState.isTouching = true
    touchState.currentPosition = Vector2.new(touch.Position.X, touch.Position.Y)
    touchState.activeTouches[touch] = true
end)

UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
    if touchState.activeTouches[touch] then
        touchState.currentPosition = Vector2.new(touch.Position.X, touch.Position.Y)
    end
end)

UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
    touchState.activeTouches[touch] = nil
    if not next(touchState.activeTouches) then
        touchState.isTouching = false
    end
end)

local function getTouchPosition()
    return touchState.currentPosition or Vector2.new(0, 0)
end

----------------------------------------------------------------
-- GENERAL SETTINGS
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

GeneralSettingsSection:NewToggle("Wall Check", "Check walls", function(state)
    sharedConfig.wallCheck = state
    Window:Notify("Wall Check", state and "Enabled" or "Disabled", 2)
end)

----------------------------------------------------------------
-- AUTO AIM SECTION (Mobile Auto-Aim)
----------------------------------------------------------------
local AutoAimSection = AimingTab:NewSection("🎯 Auto Aim (Touch)")

local MainESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/alohabeach/Main/refs/heads/master/utils/esp/source.lua"))()

local client = {
    gameui = require(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("GameUI"):WaitForChild("GameUIMod"));
    oldfunction = {};
}

client.oldfunction.GetMousePos = clonefunction(client.gameui.GetMousePos)

local config = {
    autoaimenabled = false;
    aimradius = 200;
    fovCircleVisible = true;
    fovCircleColor = Color3.fromRGB(0, 255, 0);
    targetPart = "Head";
}

local Circle = MainESP.CreateCircle()
Circle.Radius = config.aimradius
Circle.Color = config.fovCircleColor
Circle.Position = MainESP.TracerOrigins.Middle
Circle.NumSides = 500
Circle.Visible = false

client.getentities = function()
    local models = {}
    
    -- Get NPCs/Mobs
    if workspace:FindFirstChild("Mobs") then
        for i,v in next, workspace.Mobs:GetChildren() do
            if v:IsA("Model") and v:FindFirstChild("Humanoid") then
                table.insert(models, v)
            end
        end
    end
    
    -- Get Players
    for i,v in ipairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            table.insert(models, v.Character)
        end
    end
    
    return models
end

local function isEnemy(character)
    if not character or not character.Parent then return false end
    if character == LocalPlayer.Character then return false end
    
    -- Check if it has humanoid and is alive
    local humanoid = character:FindFirstChild("Humanoid") or character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    -- If team check is disabled, all are enemies
    if not sharedConfig.teamCheck then return true end
    
    -- Check for EnemyHighlight (means it's an enemy)
    local enemyHighlight = character:FindFirstChild("EnemyHighlight", true)
    if enemyHighlight then
        -- Make sure it's not a friendly (no PlayerOutline)
        local playerOutline = character:FindFirstChild("PlayerOutline", true)
        if not playerOutline then
            return true
        end
    end
    
    return false
end

client.getNearestToTouch = function()
    local touchPos = getTouchPosition()
    if touchPos.Magnitude == 0 then return nil end
    
    local closestPart = nil
    local shortestDist = config.aimradius
    local entities = client.getentities()
    
    for i,v in next, entities do
        if not isEnemy(v) then continue end
        
        local targetPart = nil
        
        -- Try to find the target part
        if config.targetPart == "Head" then
            targetPart = v:FindFirstChild("Head")
        elseif config.targetPart == "FakeHRP" then
            targetPart = v:FindFirstChild("FakeHRP")
        else
            -- Auto mode - try both
            local head = v:FindFirstChild("Head")
            local fakeHRP = v:FindFirstChild("FakeHRP")
            if head and fakeHRP then
                targetPart = math.random(1, 2) == 1 and head or fakeHRP
            else
                targetPart = head or fakeHRP
            end
        end
        
        -- Fallback to HumanoidRootPart if target part not found
        if not targetPart then
            targetPart = v:FindFirstChild("HumanoidRootPart")
        end
        
        if targetPart then
            local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - touchPos).Magnitude
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
    local nearest = client.getNearestToTouch()
    if config.autoaimenabled and nearest then
        return nearest.Position
    end
    return client.oldfunction.GetMousePos(...)
end

AutoAimSection:NewToggle("Enable Auto Aim", "Auto-aims when shooting", function(state)
    config.autoaimenabled = state
    Window:Notify("Auto Aim", state and "Enabled" or "Disabled", 2)
end)

AutoAimSection:NewSlider("Aim Radius", 100, 500, 200, function(value)
    config.aimradius = value
    Circle.Radius = value
end)

AutoAimSection:NewToggle("Show FOV Circle", "Display aim circle", function(state)
    config.fovCircleVisible = state
    Circle.Visible = state
end)

AutoAimSection:NewDropdown("Target Part", {"Head", "FakeHRP", "Auto (Both)"}, function(choice)
    config.targetPart = choice == "Auto (Both)" and "Auto" or choice
    Window:Notify("Target Part", "Now targeting: "..choice, 2)
end)

AutoAimSection:NewLabel("📱 Automatically aims when you shoot!")
AutoAimSection:NewLabel("📌 Just touch to shoot - auto-aims!")

AutoAimSection:NewButton("🔍 Test Auto Aim", "Check if NPCs are detected", function()
    local entities = client.getentities()
    local enemyCount = 0
    local npcCount = 0
    local playerCount = 0
    
    for _, entity in ipairs(entities) do
        if isEnemy(entity) then
            enemyCount = enemyCount + 1
            if entity.Parent == workspace.Mobs then
                npcCount = npcCount + 1
            else
                playerCount = playerCount + 1
            end
        end
    end
    
    Window:Notify("Auto Aim Debug", 
        string.format("Enemies: %d (NPCs: %d, Players: %d)", enemyCount, npcCount, playerCount), 4)
end)

----------------------------------------------------------------
-- TOUCH AIMLOCK SECTION
----------------------------------------------------------------
local TouchAimlockSection = AimingTab:NewSection("🔒 Touch Aimlock")

_G.TouchAimlock = false
_G.AimlockFOV = 250
_G.AimlockTarget = "Head"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local aimlockTarget = nil

local function isEnemyAimlock(character)
    if not sharedConfig.teamCheck then return true end
    local enemyHighlight = character:FindFirstChild("EnemyHighlight", true)
    if not enemyHighlight then return false end
    local playerOutline = character:FindFirstChild("PlayerOutline", true)
    if playerOutline then return false end
    return true
end

local function getTargetPart(character)
    return character:FindFirstChild(_G.AimlockTarget) or character:FindFirstChild("Head")
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

local function getClosestEnemy()
    local touchPos = getTouchPosition()
    if touchPos.Magnitude == 0 then return nil end
    
    local closestEnemy, smallestDist = nil, math.huge
    for _, enemy in ipairs(getAllEnemies()) do
        local targetPart = getTargetPart(enemy)
        if targetPart then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - touchPos).Magnitude
                if dist <= _G.AimlockFOV and dist < smallestDist then
                    closestEnemy = enemy
                    smallestDist = dist
                end
            end
        end
    end
    return closestEnemy
end

RunService.RenderStepped:Connect(function()
    if _G.TouchAimlock and touchState.isTouching then
        local target = getClosestEnemy()
        if target then
            local targetPart = getTargetPart(target)
            if targetPart then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
            end
        end
    end
end)

TouchAimlockSection:NewToggle("Enable Touch Aimlock", "Locks aim when touching screen", function(state)
    _G.TouchAimlock = state
    Window:Notify("Touch Aimlock", state and "Enabled" or "Disabled", 2)
end)

TouchAimlockSection:NewDropdown("Target Part", {"Head", "HumanoidRootPart", "UpperTorso"}, function(choice)
    _G.AimlockTarget = choice
    Window:Notify("Target Part", "Changed to: " .. choice, 2)
end)

TouchAimlockSection:NewSlider("FOV Radius", 100, 500, 250, function(value)
    _G.AimlockFOV = value
end)

TouchAimlockSection:NewLabel("📱 Touch and hold screen to lock aim!")
TouchAimlockSection:NewLabel("📌 Works while touching anywhere")

----------------------------------------------------------------
-- AUTO FARM TAB
----------------------------------------------------------------
local AutoFarmTab = Window:NewTab("🤖 AutoFarm")
local FlagSection = AutoFarmTab:NewSection("🚩 Auto FLAG")
local TPEnemySection = AutoFarmTab:NewSection("⚡ TP to Enemy")

local rs = game:GetService("RunService")
local ws = game:GetService("Workspace")
local plrs = game:GetService("Players")
local lp = plrs.LocalPlayer
local camAF = ws.CurrentCamera

local Map = ws:FindFirstChild("Map")
local bots = ws:FindFirstChild("Mobs")

local function getHRP()
    local char = lp and lp.Character
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
    
    if bots then
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
FlagSection:NewLabel("📱 Fully automatic!")
FlagSection:NewLabel("📌 Undetectable unless reported")

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

TPEnemySection:NewLabel("📱 Auto-Shoot when TP enabled!")
TPEnemySection:NewLabel("📌 Rotates through all enemies")

----------------------------------------------------------------
-- WEAPONS TAB
----------------------------------------------------------------
local WeaponsTab = Window:NewTab("🔫 Weapons")
local AmmoSection = WeaponsTab:NewSection("Ammo Management")

local weaponState = {
    infiniteAmmo = false,
    infiniteMags = false,
    freeRainbowBullets = false
}

local function getMainGui()
    return lp.PlayerGui:FindFirstChild("MainGui")
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
    lp:SetAttribute("RainbowBullets", state)
end

AmmoSection:NewLabel("🔫 Ammo Controls")

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

AmmoSection:NewLabel("📱 Optimized for mobile!")

----------------------------------------------------------------
-- VISUALS TAB (Mobile ESP)
----------------------------------------------------------------
local VisualsTab = Window:NewTab("👁️ Visuals")
local ESPSection = VisualsTab:NewSection("ESP (Mobile)")

local ESPEnabled = false
local ESPColor = Color3.fromRGB(255, 0, 0)
local ESPDistance = 500
local ESP_CONNECTIONS = {}

local function IsEnemy(target)
    if not target then return false end
    if target == LocalPlayer.Character then return false end
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return target:FindFirstChild("EnemyHighlight") ~= nil
end

local function clearESP()
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

local function createESP(target)
    if not target or not target.Parent then return end
    local rootPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
    if not rootPart then return end
    if target:FindFirstChild("MobileESP") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MobileESP"
    billboard.Adornee = rootPart
    billboard.Size = UDim2.new(0, 200, 0, 60)
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
    label.TextSize = 20
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = ""
    label.Parent = billboard

    local conn = RunService.RenderStepped:Connect(function()
        if ESPEnabled and target and rootPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
            if distance <= ESPDistance then
                local distanceMeters = distance / 3
                label.Text = target.Name .. "\n" .. string.format("%.0f", distanceMeters) .. "m"
                label.TextColor3 = ESPColor
                billboard.Enabled = true
            else
                billboard.Enabled = false
            end
        else
            billboard.Enabled = false
        end
    end)

    table.insert(ESP_CONNECTIONS, conn)
end

local function applyESP()
    clearESP()
    if not ESPEnabled then return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            createESP(plr.Character)
        end
    end
    if workspace:FindFirstChild("Mobs") then
        for _, mob in pairs(workspace.Mobs:GetChildren()) do
            createESP(mob)
        end
    end
end

-- Handle player respawns
local function setupPlayerESP(player)
    if player == LocalPlayer then return end
    
    -- Apply ESP to current character
    if player.Character then
        createESP(player.Character)
    end
    
    -- Apply ESP when character respawns
    player.CharacterAdded:Connect(function(character)
        task.wait(0.5) -- Wait for character to fully load
        if ESPEnabled then
            createESP(character)
        end
    end)
end

-- Handle new players joining
Players.PlayerAdded:Connect(function(player)
    task.wait(1) -- Wait for player to fully load
    if ESPEnabled then
        setupPlayerESP(player)
    end
end)

-- Handle player leaving (cleanup)
Players.PlayerRemoving:Connect(function(player)
    if player.Character and player.Character:FindFirstChild("MobileESP") then
        player.Character.MobileESP:Destroy()
    end
end)

-- Handle Mobs spawning
if workspace:FindFirstChild("Mobs") then
    workspace.Mobs.ChildAdded:Connect(function(mob)
        task.wait(0.3) -- Wait for mob to fully load
        if ESPEnabled then
            createESP(mob)
        end
    end)
    
    workspace.Mobs.ChildRemoving:Connect(function(mob)
        if mob:FindFirstChild("MobileESP") then
            mob.MobileESP:Destroy()
        end
    end)
end

-- Setup ESP for existing players
for _, player in pairs(Players:GetPlayers()) do
    setupPlayerESP(player)
end

ESPSection:NewToggle("Enable ESP", "Show enemy info", function(state)
    ESPEnabled = state
    if state then 
        applyESP()
        -- Setup listeners for all existing players
        for _, player in pairs(Players:GetPlayers()) do
            setupPlayerESP(player)
        end
    else 
        clearESP() 
    end
    Window:Notify("ESP", state and "Enabled" or "Disabled", 2)
end)

ESPSection:NewSlider("Max Distance", 100, 1000, 500, function(val)
    ESPDistance = val
end)

ESPSection:NewColorpicker("ESP Color", ESPColor, function(c)
    ESPColor = c
end)

ESPSection:NewLabel("📱 Lightweight for mobile!")
ESPSection:NewLabel("📌 Shows name + distance only")

-- Local player respawn handler
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if ESPEnabled then
        applyESP()
    end
end)

----------------------------------------------------------------
-- PLAYERS TAB (Mobile Movement)
----------------------------------------------------------------
local PlayersTab = Window:NewTab("🏃 Players")
local PlayerSection = PlayersTab:NewSection("Player Mods")

local playerState = {
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
    if not playerState.speedEnabled then return end
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return end
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0 then
        local step = moveDir.Unit * playerState.speedMultiplier
        hrp.CFrame = hrp.CFrame + step
    end
end

local function applyNoclip()
    if not playerState.noclipEnabled then return end
    local char = getCharacter()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

UserInputService.JumpRequest:Connect(function()
    if playerState.infiniteJumpEnabled then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Mobile Fly GUI
local FlyGui = Instance.new("ScreenGui")
FlyGui.Name = "MobileFlyControls"
FlyGui.ResetOnSpawn = false
FlyGui.Enabled = false
FlyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function createFlyButton(name, position, text, size)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = size or UDim2.new(0, 90, 0, 90)
    button.Position = position
    button.Text = text
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 28
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.BackgroundTransparency = 0.2
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 0)
    stroke.Thickness = 2
    stroke.Parent = button
    
    button.Parent = FlyGui
    return button
end

-- Create fly buttons (positioned for mobile)
local centerX = 0.5
local centerY = 0.65
local spacing = 100

local upBtn = createFlyButton("UpBtn", UDim2.new(centerX, -45, centerY, -200), "▲")
local downBtn = createFlyButton("DownBtn", UDim2.new(centerX, -45, centerY, 110), "▼")
local forwardBtn = createFlyButton("ForwardBtn", UDim2.new(centerX, -45, centerY, -45), "W")
local leftBtn = createFlyButton("LeftBtn", UDim2.new(centerX, -155, centerY, -45), "A")
local rightBtn = createFlyButton("RightBtn", UDim2.new(centerX, 65, centerY, -45), "D")
local backBtn = createFlyButton("BackBtn", UDim2.new(centerX, -45, centerY, 10), "S")

FlyGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local flyDirections = {
    up = false,
    down = false,
    forward = false,
    backward = false,
    left = false,
    right = false
}

-- Touch event handlers for fly buttons
upBtn.TouchTap:Connect(function() end)
upBtn.MouseButton1Down:Connect(function() 
    flyDirections.up = true
    upBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
end)
upBtn.MouseButton1Up:Connect(function() 
    flyDirections.up = false
    upBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
end)

downBtn.MouseButton1Down:Connect(function() 
    flyDirections.down = true
    downBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
end)
downBtn.MouseButton1Up:Connect(function() 
    flyDirections.down = false
    downBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
end)

forwardBtn.MouseButton1Down:Connect(function() 
    flyDirections.forward = true
    forwardBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
end)
forwardBtn.MouseButton1Up:Connect(function() 
    flyDirections.forward = false
    forwardBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
end)

backBtn.MouseButton1Down:Connect(function() 
    flyDirections.backward = true
    backBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
end)
backBtn.MouseButton1Up:Connect(function() 
    flyDirections.backward = false
    backBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
end)

leftBtn.MouseButton1Down:Connect(function() 
    flyDirections.left = true
    leftBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
end)
leftBtn.MouseButton1Up:Connect(function() 
    flyDirections.left = false
    leftBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
end)

rightBtn.MouseButton1Down:Connect(function() 
    flyDirections.right = true
    rightBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
end)
rightBtn.MouseButton1Up:Connect(function() 
    flyDirections.right = false
    rightBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
end)

local function flyLoop()
    while playerState.flyEnabled do
        task.wait()
        local hrp = getHRP()
        local cam = workspace.CurrentCamera
        if not hrp or not cam then continue end

        local moveDirection = Vector3.new()
        if flyDirections.forward then moveDirection += cam.CFrame.LookVector end
        if flyDirections.backward then moveDirection -= cam.CFrame.LookVector end
        if flyDirections.left then moveDirection -= cam.CFrame.RightVector end
        if flyDirections.right then moveDirection += cam.CFrame.RightVector end
        if flyDirections.up then moveDirection += Vector3.new(0,1,0) end
        if flyDirections.down then moveDirection -= Vector3.new(0,1,0) end

        if moveDirection.Magnitude > 0 then
            hrp.Velocity = moveDirection.Unit * playerState.flySpeed
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
    if playerState.noclipEnabled then applyNoclip() end
    if playerState.flyEnabled then task.spawn(flyLoop) end
end)

-- UI Controls
PlayerSection:NewToggle("Speed", "Toggle speed hack", function(value)
    playerState.speedEnabled = value
    Window:Notify("Speed", value and ("Enabled - " .. playerState.speedMultiplier .. "x") or "Disabled", 2)
end)

PlayerSection:NewSlider("Speed Multiplier", 1, 10, playerState.speedMultiplier, function(val)
    playerState.speedMultiplier = val
    if playerState.speedEnabled then
        Window:Notify("Speed", "Set to " .. val .. "x", 1)
    end
end)

PlayerSection:NewToggle("Noclip", "Walk through walls", function(value)
    playerState.noclipEnabled = value
    if value then applyNoclip() end
    Window:Notify("Noclip", value and "Enabled" or "Disabled", 2)
end)

PlayerSection:NewToggle("Infinite Jump", "Jump infinitely", function(value)
    playerState.infiniteJumpEnabled = value
    Window:Notify("Infinite Jump", value and "Enabled" or "Disabled", 2)
end)

PlayerSection:NewToggle("Fly", "Fly mode with touch controls", function(value)
    playerState.flyEnabled = value
    FlyGui.Enabled = value
    if value then
        task.spawn(flyLoop)
        Window:Notify("Fly", "Enabled - Use on-screen controls!", 3)
    else
        Window:Notify("Fly", "Disabled", 2)
    end
end)

PlayerSection:NewSlider("Fly Speed", 10, 200, playerState.flySpeed, function(val)
    playerState.flySpeed = val
    if playerState.flyEnabled then
        Window:Notify("Fly Speed", "Set to " .. val, 1)
    end
end)

PlayerSection:NewLabel("📱 Fly shows on-screen buttons!")
PlayerSection:NewLabel("📌 Touch buttons to move while flying")

----------------------------------------------------------------
-- SETTINGS TAB
----------------------------------------------------------------
local SettingsTab = Window:NewTab("⚙️ Settings")

local InterfaceSection = SettingsTab:NewSection("Interface")

InterfaceSection:NewDropdown("Select Theme", Window:GetThemeList(), function(theme)
    if theme then
        Window:SetTheme(theme)
        Window:Notify("Theme Changed", "Applied: " .. tostring(theme), 2)
    end
end)

InterfaceSection:NewButton("Toggle UI Visibility", "Show/Hide UI", function()
    Window:ToggleUI()
end)

InterfaceSection:NewLabel("📱 Tap to toggle UI on/off")

local PerfSection = SettingsTab:NewSection("📱 Performance (Mobile)")

local lighting = game:GetService("Lighting")
local normalBrightness = lighting.Brightness

PerfSection:NewToggle("Full Bright", "Maximum brightness", function(state)
    if state then
        lighting.Brightness = 2
        lighting.ClockTime = 12
        lighting.FogEnd = 1e6
        lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Window:Notify("Full Bright", "Enabled", 2)
    else
        lighting.Brightness = normalBrightness
        lighting.ClockTime = 14
        lighting.Ambient = Color3.fromRGB(0, 0, 0)
        Window:Notify("Full Bright", "Disabled", 2)
    end
end)

local fpsBoosterEnabled = false
PerfSection:NewToggle("FPS Booster", "Max performance mode", function(state)
    fpsBoosterEnabled = state
    if fpsBoosterEnabled then
        -- Aggressive mobile optimization
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        
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
            elseif v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                v.Enabled = false
            end
        end
        
        lighting.GlobalShadows = false
        lighting.FogEnd = 9e9
        lighting.Brightness = 2
        
        Window:Notify("FPS Booster", "Enabled - Max performance!", 2)
    else
        -- Restore
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CastShadow = true
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 0
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = true
            elseif v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = true
            elseif v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                v.Enabled = true
            end
        end
        
        lighting.GlobalShadows = true
        lighting.FogEnd = 1000
        lighting.Brightness = normalBrightness
        
        Window:Notify("FPS Booster", "Disabled", 2)
    end
end)

PerfSection:NewLabel("📱 HIGHLY RECOMMENDED for mobile!")
PerfSection:NewLabel("⚡ Removes shadows, particles, lights")
PerfSection:NewLabel("⚡ Sets graphics to lowest quality")

local MobileInfoSection = SettingsTab:NewSection("📱 Mobile Information")
MobileInfoSection:NewLabel("Platform: MOBILE ONLY")
MobileInfoSection:NewLabel("Touch Enabled: ✓ YES")
MobileInfoSection:NewLabel("Optimized: ✓ YES")
MobileInfoSection:NewLabel("────────────────────────────")
MobileInfoSection:NewLabel("📌 Touch Controls Guide:")
MobileInfoSection:NewLabel("• Auto Aim: Automatically aims when shooting")
MobileInfoSection:NewLabel("• Touch Aimlock: Hold screen to lock aim")
MobileInfoSection:NewLabel("• Fly Mode: Uses on-screen buttons (W/A/S/D/▲/▼)")
MobileInfoSection:NewLabel("• All features work via touch!")
MobileInfoSection:NewLabel("────────────────────────────")

local TipsSection = SettingsTab:NewSection("💡 Mobile Tips")
TipsSection:NewLabel("✓ Enable FPS Booster for smooth gameplay")
TipsSection:NewLabel("✓ Use Auto Aim instead of Touch Aimlock for easier aim")
TipsSection:NewLabel("✓ Auto Farm works fully automatically")
TipsSection:NewLabel("✓ TP to Enemy includes auto-shoot")
TipsSection:NewLabel("✓ Fly mode: Touch buttons to control direction")
TipsSection:NewLabel("✓ Never use in Duels - instant ban!")

----------------------------------------------------------------
-- BOOT MESSAGE
----------------------------------------------------------------
Window:Notify("🎮 Kour6anHub Mobile", "Hypershot Script Loaded!", 4)
task.wait(1)
Window:Notify("📱 Touch Controls", "All features optimized for mobile!", 3)
task.wait(1)
Window:Notify("⚡ Pro Tip", "Enable FPS Booster for best performance!", 3)
