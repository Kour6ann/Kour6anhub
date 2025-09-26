-- Kour6anHub - patched v8 (full file)
-- Patches/fixes applied:
-- 1) Fixed syntax issues and guarded unsafe table access.
-- 2) Consolidated debounce helper and removed duplicate definitions.
-- 3) Fixed invalid concatenation and repaired incomplete Completed handlers.
-- 4) Preserved features: themes, tabs, notifications, colorpickers, dropdowns, etc.

local Kour6anHub = {}
Kour6anHub.__index = Kour6anHub

-- Services (fetch lazily if needed)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Global configuration
local ReducedMotion = false -- Set to true for accessibility/snapping animations

-- Enhanced tween helper with cancellation and customization
local ActiveTweens = setmetatable({}, { __mode = "k" }) -- weak keys
local _tweenTimestamps = {}

-- Helper: safer debounce key generation (uses GetDebugId/GetFullName when available, falls back to tostring)
local function _debounceKeyFor(obj)
    if not obj then return tostring(obj) end
    local ok, id = pcall(function() return (obj.GetDebugId and obj:GetDebugId()) end)
    if ok and id then return tostring(id) end
    ok, id = pcall(function() return (obj.GetFullName and obj:GetFullName()) end)
    if ok and id then return tostring(id) end
    return tostring(obj)
end

-- safeCall with recursion guard
local SAFE_CALL_MAX_DEPTH = 10
local _safe_call_depth = {}
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return false, "not_function" end

    -- increment depth for this function
    local depth = (_safe_call_depth[fn] or 0) + 1
    _safe_call_depth[fn] = depth

    if depth > SAFE_CALL_MAX_DEPTH then
        warn("[Kour6anHub] safeCall: recursion depth exceeded (" .. tostring(SAFE_CALL_MAX_DEPTH) .. ") - aborting invocation")
        -- decrement and return failure
        _safe_call_depth[fn] = _safe_call_depth[fn] - 1
        if _safe_call_depth[fn] <= 0 then _safe_call_depth[fn] = nil end
        return false, "recursion_limit"
    end

    local ok, res = pcall(fn, ...)
    -- decrement depth
    _safe_call_depth[fn] = _safe_call_depth[fn] - 1
    if _safe_call_depth[fn] <= 0 then _safe_call_depth[fn] = nil end

    return ok, res
end

-- Add this helper function at top of file
local function getArrowChar(direction)
    local unicode = direction == "down" and "▼" or "▲"
    local fallback = direction == "down" and "v" or "^"
    
    -- Test if Unicode is supported
    local success = pcall(function()
        local testLabel = Instance.new("TextLabel")
        testLabel.Text = unicode
        testLabel.Font = Enum.Font.Gotham
        testLabel.TextSize = 12
        local textSize = game:GetService("TextService"):GetTextSize(unicode, 12, Enum.Font.Gotham, Vector2.new(1000, 1000))
        testLabel:Destroy()
        return textSize.X > 0
    end)
    
    return success and unicode or fallback
end

-- Fixed Tween creation helper (safe)
local function safeTweenCreate(obj, props, options)
    if not obj or not props then return nil end
    options = options or {}
    local dur = options.duration or 0.15
    local easingStyle = options.easingStyle or Enum.EasingStyle.Quad
    local easingDirection = options.easingDirection or Enum.EasingDirection.Out

    -- Reduced motion: set final properties synchronously but don't create Tween objects
    if ReducedMotion then
        for prop, value in pairs(props) do
            pcall(function() obj[prop] = value end)
        end
        return nil
    end

    -- Ensure we have a table for this object
    if not ActiveTweens[obj] then ActiveTweens[obj] = {} end

    -- Cancel conflicting property tweens for that object (FIXED)
    for prop, tweenObj in pairs(ActiveTweens[obj]) do
        if props[prop] ~= nil then
            -- Check if tweenObj exists and is still valid before calling Cancel
            if tweenObj and typeof(tweenObj) == "Tween" then
                local success = pcall(function() 
                    -- Additional check: ensure the tween object still has its methods
                    if tweenObj.Cancel then
                        tweenObj:Cancel() 
                    end
                end)
                if not success then
                    -- If cancel failed, the tween is probably already destroyed
                    warn("[Kour6anHub] Failed to cancel tween - object may be destroyed")
                end
            end
            -- Always clear the reference, even if cancel failed
            ActiveTweens[obj][prop] = nil
        end
    end

    local ti = TweenInfo.new(dur, easingStyle, easingDirection)
    local ok, t = pcall(function() return TweenService:Create(obj, ti, props) end)
    if not ok or not t then return nil end

    -- Store the new tween references
    for prop in pairs(props) do
        ActiveTweens[obj][prop] = t
    end
    _tweenTimestamps[t] = tick()

    -- Completed connection to cleanup tracked tweens (IMPROVED)
    local conn
    conn = t.Completed:Connect(function()
        -- More robust cleanup with additional safety checks
        pcall(function()
            if ActiveTweens[obj] then
                for prop, tweenObj in pairs(ActiveTweens[obj]) do
                    if tweenObj == t then
                        ActiveTweens[obj][prop] = nil
                    end
                end
                -- Clean up empty tables
                if next(ActiveTweens[obj]) == nil then
                    ActiveTweens[obj] = nil
                end
            end
            if conn then
                conn:Disconnect()
                conn = nil
            end
            _tweenTimestamps[t] = nil
        end)
    end)

    -- Add additional safety: if tween fails to play, clean up immediately
    local playSuccess = pcall(function() t:Play() end)
    if not playSuccess then
        -- Clean up failed tween
        for prop in pairs(props) do
            if ActiveTweens[obj] then
                ActiveTweens[obj][prop] = nil
            end
        end
        _tweenTimestamps[t] = nil
        if conn then
            pcall(function() conn:Disconnect() end)
        end
        return nil
    end

    return t
end

local function tween(obj, props, options)
    return safeTweenCreate(obj, props, options)
end

-- Connection tracker factory
local function makeConnectionTracker()
    local conns = {}
    local tweens = {}

    return {
        add = function(_, conn)
            if conn and typeof(conn) == "RBXScriptConnection" then
                table.insert(conns, conn)
            end
        end,
        addTween = function(_, tweenObj)
            if tweenObj and typeof(tweenObj) == "Tween" then
                table.insert(tweens, tweenObj)
            end
        end,
        disconnectAll = function()
            for _, c in ipairs(conns) do
                pcall(function() c:Disconnect() end)
            end
            conns = {}
            for _, t in ipairs(tweens) do
                pcall(function() t:Cancel() end)
            end
            tweens = {}
        end,
        list = function() return conns end,
        listTweens = function() return tweens end
    }
end

-- Module-level global connection registry used by helpers like debouncedHover, global colorpicker close, etc.
local _GLOBAL_CONN_REGISTRY = {}
local function trackGlobalConn(conn)
    if conn and typeof(conn) == "RBXScriptConnection" then
        table.insert(_GLOBAL_CONN_REGISTRY, conn)
    end
end

-- Debounce helper for hover animations
local HoverDebounce = {}
local function debouncedHover(obj, enterFunc, leaveFunc)
    if not obj then return end
    local key = _debounceKeyFor(obj)

    -- cleanup on object removal
    local ancConn
    ancConn = obj.AncestryChanged:Connect(function(_, parent)
        if not parent then
            HoverDebounce[key] = nil
            pcall(function() ancConn:Disconnect() end)
        end
    end)
    trackGlobalConn(ancConn)

    obj.MouseEnter:Connect(function()
        if HoverDebounce[key] then return end
        HoverDebounce[key] = true
        if enterFunc then pcall(enterFunc) end
    end)

    obj.MouseLeave:Connect(function()
        if not HoverDebounce[key] then return end
        HoverDebounce[key] = nil
        if leaveFunc then pcall(leaveFunc) end
    end)
end

-- Dragging helper with tracked connections
local function makeDraggable(frame, dragHandle)
    local connTracker = makeConnectionTracker()
    local dragging, dragStart, startPos
    dragHandle = dragHandle or frame

    local ibConn = dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            local changedConn
            changedConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    pcall(function() changedConn:Disconnect() end)
                end
            end)
            connTracker:add(changedConn)
        end
    end)
    connTracker:add(ibConn)

    local imConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            pcall(function()
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end)
        end
    end)
    connTracker:add(imConn)

    return {
        disconnect = function()
            connTracker.disconnectAll()
        end,
        list = function() return connTracker.list() end
    }
end

-- default Themes
local Themes = {
    ["LightTheme"] = {
        Background = Color3.fromRGB(250,250,250),
        TabBackground = Color3.fromRGB(240,240,240),
        SectionBackground = Color3.fromRGB(255,255,255),
        ButtonBackground = Color3.fromRGB(240,240,240),
        ButtonHover = Color3.fromRGB(230,230,230),
        InputBackground = Color3.fromRGB(255,255,255),
        Text = Color3.fromRGB(20,20,20),
        SubText = Color3.fromRGB(110,110,110),
        Accent = Color3.fromRGB(60,120,220)
    },
    ["DarkTheme"] = {
        Background = Color3.fromRGB(20,20,20),
        TabBackground = Color3.fromRGB(30,30,30),
        SectionBackground = Color3.fromRGB(26,26,26),
        ButtonBackground = Color3.fromRGB(40,40,40),
        ButtonHover = Color3.fromRGB(55,55,55),
        InputBackground = Color3.fromRGB(28,28,28),
        Text = Color3.fromRGB(230,230,230),
        SubText = Color3.fromRGB(190,190,190),
        Accent = Color3.fromRGB(90,150,250)
    },
    ["Midnight"] = {
        Background = Color3.fromRGB(10,12,20),
        TabBackground = Color3.fromRGB(18,20,30),
        SectionBackground = Color3.fromRGB(22,24,36),
        Text = Color3.fromRGB(235,235,245),
        SubText = Color3.fromRGB(150,150,170),
        Accent = Color3.fromRGB(120,90,255)
    },
    ["BloodTheme"] = {
        Background = Color3.fromRGB(18,6,8),
        TabBackground = Color3.fromRGB(30,10,12),
        SectionBackground = Color3.fromRGB(40,14,16),
        Text = Color3.fromRGB(245,220,220),
        SubText = Color3.fromRGB(200,140,140),
        Accent = Color3.fromRGB(220,20,30)
    },
    ["SynapseTheme"] = {
        Background = Color3.fromRGB(12,10,20),
        TabBackground = Color3.fromRGB(22,18,36),
        SectionBackground = Color3.fromRGB(30,26,46),
        Text = Color3.fromRGB(235,235,245),
        SubText = Color3.fromRGB(170,160,190),
        Accent = Color3.fromRGB(100,160,255)
    },
    ["SentinelTheme"] = {
        Background = Color3.fromRGB(8,18,12),
        TabBackground = Color3.fromRGB(14,28,20),
        SectionBackground = Color3.fromRGB(20,40,28),
        Text = Color3.fromRGB(230,245,230),
        SubText = Color3.fromRGB(160,200,170),
        Accent = Color3.fromRGB(70,200,120)
    },
    ["NeonTheme"] = {
        Background = Color3.fromRGB(15, 15, 25),
        TabBackground = Color3.fromRGB(25, 25, 40),
        SectionBackground = Color3.fromRGB(35, 35, 55),
        Text = Color3.fromRGB(240, 240, 255),
        SubText = Color3.fromRGB(160, 160, 200),
        Accent = Color3.fromRGB(0, 255, 200)
    },
    ["OceanTheme"] = {
        Background = Color3.fromRGB(5, 20, 35),
        TabBackground = Color3.fromRGB(10, 30, 50),
        SectionBackground = Color3.fromRGB(15, 40, 65),
        Text = Color3.fromRGB(220, 235, 245),
        SubText = Color3.fromRGB(140, 170, 190),
        Accent = Color3.fromRGB(0, 140, 255)
    },
    ["ForestTheme"] = {
        Background = Color3.fromRGB(10, 20, 12),
        TabBackground = Color3.fromRGB(16, 30, 18),
        SectionBackground = Color3.fromRGB(24, 40, 26),
        Text = Color3.fromRGB(225, 235, 225),
        SubText = Color3.fromRGB(160, 180, 160),
        Accent = Color3.fromRGB(70, 200, 100)
    },
    ["CrimsonTheme"] = {
        Background = Color3.fromRGB(25, 10, 15),
        TabBackground = Color3.fromRGB(35, 15, 20),
        SectionBackground = Color3.fromRGB(45, 20, 25),
        Text = Color3.fromRGB(245, 225, 230),
        SubText = Color3.fromRGB(180, 150, 160),
        Accent = Color3.fromRGB(220, 40, 80)
    },
    ["SkyTheme"] = {
        Background = Color3.fromRGB(230, 245, 255),
        TabBackground = Color3.fromRGB(210, 235, 250),
        SectionBackground = Color3.fromRGB(190, 220, 245),
        Text = Color3.fromRGB(25, 50, 75),
        SubText = Color3.fromRGB(90, 120, 150),
        Accent = Color3.fromRGB(50, 150, 255)
    }
}

-- Helper to resolve a parent for the ScreenGui safely
local function resolveGuiParent()
    local parent = game:GetService("CoreGui")
    -- prefer PlayerGui if CoreGui can't be written to due to security contexts
    local success, playerGui = pcall(function()
        local plr = Players.LocalPlayer
        if plr and plr:FindFirstChild("PlayerGui") then
            return plr.PlayerGui
        end
        return nil
    end)
    if success and playerGui then parent = playerGui end
    return parent
end

-- safeCallback wrapper
local function safeCallback(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[Kour6anHub] callback error:", err)
    end
end

-- library creation
function Kour6anHub.CreateLib(title, themeName)
    local theme = Themes[themeName] or Themes["LightTheme"]

    -- Resolve parent for ScreenGui safely
    local GuiParent = resolveGuiParent()

    -- Create or replace ScreenGui
local ScreenGui = GuiParent:FindFirstChild("Kour6anHub")
if ScreenGui then
    pcall(function() ScreenGui:Destroy() end)
end
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Kour6anHub"
ScreenGui.DisplayOrder = 999999999 -- Very high display order to stay on top
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = GuiParent
    
    -- Main frame
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 600, 0, 400)
    Main.Position = UDim2.new(0.5, -300, 0.5, -200)
    Main.BackgroundColor3 = theme.Background
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = Main

    -- 1. First, create the topbar and buttons (WITHOUT the click connections):

-- Topbar with window controls
local Topbar = Instance.new("Frame")
Topbar.Size = UDim2.new(1, 0, 0, 40)
Topbar.BackgroundColor3 = theme.SectionBackground
Topbar.Parent = Main

local TopbarCorner = Instance.new("UICorner")
TopbarCorner.CornerRadius = UDim.new(0, 8)
TopbarCorner.Parent = Topbar

-- Title (adjusted to make room for buttons)
local Title = Instance.new("TextLabel")
Title.Text = title or "Kour6anHub"
Title.Size = UDim2.new(1, -90, 1, 0) -- Changed from UDim2.new(1, -10, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = theme.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Topbar

-- Minimize Button
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -70, 0.5, -15)
MinimizeBtn.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
MinimizeBtn.TextColor3 = theme.Text
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.Text = "−"
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = Topbar

local MinimizeBtnCorner = Instance.new("UICorner")
MinimizeBtnCorner.CornerRadius = UDim.new(0, 6)
MinimizeBtnCorner.Parent = MinimizeBtn

-- Close Button (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0.5, -15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Text = "×"
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Topbar

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 6)
CloseBtnCorner.Parent = CloseBtn

    local globalConnTracker = makeConnectionTracker()

    -- make draggable and keep its connections
    local dragTracker = makeDraggable(Main, Topbar)
    if dragTracker then
        for _, c in ipairs(dragTracker.list()) do globalConnTracker:add(c) end
    end
    -- integrate any module-level global connections created earlier
    for _, c in ipairs(_GLOBAL_CONN_REGISTRY) do
        globalConnTracker:add(c)
    end
    
    _GLOBAL_CONN_REGISTRY = {}

    -- Tab container (left)
    local TabContainer = Instance.new("Frame")
    TabContainer.Size = UDim2.new(0, 150, 1, -40)
    TabContainer.Position = UDim2.new(0, 0, 0, 40)
    TabContainer.BackgroundColor3 = theme.TabBackground
    TabContainer.Parent = Main

    local TabContainerCorner = Instance.new("UICorner")
    TabContainerCorner.CornerRadius = UDim.new(0, 8)
    TabContainerCorner.Parent = TabContainer

    local TabList = Instance.new("UIListLayout")
    TabList.SortOrder = Enum.SortOrder.LayoutOrder
    TabList.Padding = UDim.new(0, 8)
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabList.Parent = TabContainer

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingTop = UDim.new(0, 8)
    TabPadding.PaddingBottom = UDim.new(0, 8)
    TabPadding.PaddingLeft = UDim.new(0, 10)
    TabPadding.PaddingRight = UDim.new(0, 10)
    TabPadding.Parent = TabContainer

    -- Content area (right)
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -160, 1, -40)
    Content.Position = UDim2.new(0, 160, 0, 40)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local Tabs = {}

    local Window = {}
    Window.ScreenGui = ScreenGui
    Window.Main = Main
    Window._connTracker = globalConnTracker
    Window.theme = theme

    Window._uiVisible = true
    Window._uiMinimized = false
    Window._toggleKey = Enum.KeyCode.RightControl
    Window._storedPosition = Main.Position
    Window._storedSize = Main.Size

    -- Notification internals
    Window._notifications = {}
    Window._notifConfig = {
        width = 300,
        height = 64,
        spacing = 8,
        margin = 16,
        defaultDuration = 4
    }

    -- create notification holder
    local function createNotificationHolder()
        local holder = Instance.new("Frame")
        holder.Name = "_NotificationHolder"
        holder.Size = UDim2.new(0, Window._notifConfig.width, 0, 1000)
        holder.AnchorPoint = Vector2.new(1,1)
        holder.Position = UDim2.new(1, -Window._notifConfig.margin, 1, -Window._notifConfig.margin)
        holder.BackgroundTransparency = 1
        holder.Parent = ScreenGui
        return holder
    end

    Window._notificationHolder = createNotificationHolder()

    local function repositionNotifications()
        for i, notif in ipairs(Window._notifications) do
            local targetY = - ( (i-1) * (Window._notifConfig.height + Window._notifConfig.spacing) ) - Window._notifConfig.height
            local finalPos = UDim2.new(0, 0, 1, targetY)
            pcall(function()
                if notif and notif.Parent then
                    tween(notif, {Position = finalPos}, {duration = 0.18})
                end
            end)
        end
    end

    -- Non-reentrant wrapper for repositionNotifications to avoid race conditions.
    local _notif_lock = false
    local _notif_queue = {}
    _repositionNotifications_original = repositionNotifications
    function repositionNotifications(...)
        if _notif_lock then
            _notif_queue[1] = true
            return
        end
        _notif_lock = true
        local ok, err = pcall(_repositionNotifications_original, ...)
        _notif_lock = false
        if not ok then warn('[Kour6anHub] repositionNotifications failed:', err) end
        if _notif_queue[1] then
            _notif_queue[1] = nil
            repositionNotifications(...)
        end
    end

    function Window:Notify(titleText, bodyText, duration)
        duration = duration or Window._notifConfig.defaultDuration
        if type(duration) ~= "number" or duration < 0 then duration = Window._notifConfig.defaultDuration end

        local width = Window._notifConfig.width
        local height = Window._notifConfig.height

        local notif = Instance.new("Frame")
        notif.Size = UDim2.new(0, width, 0, height)
        notif.BackgroundColor3 = theme.SectionBackground
        notif.BorderSizePixel = 0
        notif.AnchorPoint = Vector2.new(0,0)
        notif.Position = UDim2.new(0, 0, 1, 50)
        notif.Parent = Window._notificationHolder

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notif

        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 6, 1, 0)
        accent.Position = UDim2.new(0, 0, 0, 0)
        accent.BackgroundColor3 = theme.Accent
        accent.BorderSizePixel = 0
        accent.Parent = notif
        local acorner = Instance.new("UICorner")
        acorner.CornerRadius = UDim.new(0, 6)
        acorner.Parent = accent

        local ttl = Instance.new("TextLabel")
        ttl.Size = UDim2.new(1, -12, 0, 20)
        ttl.Position = UDim2.new(0, 12, 0, 8)
        ttl.BackgroundTransparency = 1
        ttl.TextXAlignment = Enum.TextXAlignment.Left
        ttl.TextYAlignment = Enum.TextYAlignment.Top
        ttl.Font = Enum.Font.GothamBold
        ttl.TextSize = 14
        ttl.TextColor3 = theme.Text
        ttl.Text = tostring(titleText or "Notification")
        ttl.Parent = notif

        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -12, 0, 36)
        body.Position = UDim2.new(0, 12, 0, 28)
        body.BackgroundTransparency = 1
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.Font = Enum.Font.Gotham
        body.TextSize = 13
        body.TextColor3 = theme.Text
        body.Text = tostring(bodyText or "")
        body.TextWrapped = true
        body.Parent = notif

        table.insert(Window._notifications, 1, notif)
        repositionNotifications()

        notif.BackgroundTransparency = 1
        ttl.TextTransparency = 1
        body.TextTransparency = 1
        accent.BackgroundTransparency = 1
        pcall(function()
            if notif and notif.Parent then
                tween(notif, {BackgroundTransparency = 0}, {duration = 0.18})
                tween(ttl, {TextTransparency = 0}, {duration = 0.18})
                tween(body, {TextTransparency = 0}, {duration = 0.18})
                tween(accent, {BackgroundTransparency = 0}, {duration = 0.18})
            end
        end)

        local removed = false
        local function removeNow()
            if removed then return end
            removed = true
            for i, v in ipairs(Window._notifications) do
                if v == notif then
                    table.remove(Window._notifications, i)
                    break
                end
            end
            if notif and notif.Parent then
                pcall(function() notif:Destroy() end)
            end
            repositionNotifications()
        end

        task.delay(duration, function()
            pcall(function()
                if notif and notif.Parent then
                    local t1 = tween(notif, {BackgroundTransparency = 1, Position = UDim2.new(0,0,1,50)}, {duration = 0.18})
                    tween(ttl, {TextTransparency = 1}, {duration = 0.18})
                    tween(body, {TextTransparency = 1}, {duration = 0.18})
                    tween(accent, {BackgroundTransparency = 1}, {duration = 0.18})
                    if t1 then
                        local c
                        c = t1.Completed:Connect(function()
                            pcall(function() c:Disconnect() end)
                            removeNow()
                        end)
                    else
                        task.delay(0.18, removeNow)
                    end
                end
            end)
        end)

        return notif
    end

    function Window:GetThemeList()
        local out = {}
        for k,_ in pairs(Themes) do
            table.insert(out, k)
        end
        table.sort(out)
        return out
    end

    function Window:SetTheme(newThemeName)
    if not newThemeName then return end
    local foundTheme = nil
    
    -- Find theme case-insensitively
    if Themes[newThemeName] then
        foundTheme = Themes[newThemeName]
    else
        local lowerTarget = string.lower(tostring(newThemeName))
        for k,v in pairs(Themes) do
            if string.lower(k) == lowerTarget then
                foundTheme = v
                break
            end
        end
    end
    
    if not foundTheme then 
        warn("Theme not found:", newThemeName)
        return 
    end
    
    theme = foundTheme
    Window.theme = theme

    -- Update main window elements
    pcall(function()
        if Main and Main.Parent then 
            Main.BackgroundColor3 = theme.Background 
            -- Force refresh
            Main.BackgroundTransparency = Main.BackgroundTransparency
        end
        if Topbar and Topbar.Parent then 
            Topbar.BackgroundColor3 = theme.SectionBackground 
            Topbar.BackgroundTransparency = Topbar.BackgroundTransparency
        end
        if Title and Title.Parent then 
            Title.TextColor3 = theme.Text 
        end
        if TabContainer and TabContainer.Parent then 
            TabContainer.BackgroundColor3 = theme.TabBackground 
            TabContainer.BackgroundTransparency = TabContainer.BackgroundTransparency
        end
    end)

    -- Update all tabs and their content
    for _, entry in ipairs(Tabs) do
        local btn = entry.Button
        local frame = entry.Frame
        
        if btn and btn.Parent then
            local active = btn:GetAttribute("active") or false
            btn.BackgroundColor3 = active and theme.Accent or theme.SectionBackground
            btn.TextColor3 = active and Color3.fromRGB(255,255,255) or theme.Text
            -- Force refresh
            btn.BackgroundTransparency = btn.BackgroundTransparency
        end

        if frame and frame.Parent then
            -- Update scrolling frame colors
            if frame:IsA("ScrollingFrame") then
                frame.ScrollBarImageColor3 = theme.Accent or Color3.fromRGB(100, 100, 100)
            end
            
            -- Recursively update all descendants
            for _, child in ipairs(frame:GetDescendants()) do
                if not child or not child.Parent then continue end
                
                if child:IsA("Frame") then
                    if child.Name == "_section" then
                        child.BackgroundColor3 = theme.SectionBackground
                        child.BackgroundTransparency = child.BackgroundTransparency
                    elseif child.Name == "_dropdownOptions" then
                        child.BackgroundColor3 = theme.SectionBackground
                        child.BackgroundTransparency = child.BackgroundTransparency
                    elseif child.Name:find("_optionsScroll") then
                        child.ScrollBarImageColor3 = theme.Accent or Color3.fromRGB(100, 100, 100)
                    end
                elseif child:IsA("TextLabel") then
                    if child.Font == Enum.Font.GothamBold then
                        child.TextColor3 = theme.SubText
                    else
                        child.TextColor3 = theme.Text
                    end
                elseif child:IsA("TextButton") then
                    child.TextColor3 = theme.Text
                    if not child:GetAttribute("_isToggleState") then
                        child.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
                    else
                        local tog = child:GetAttribute("_toggle")
                        child.BackgroundColor3 = tog and theme.Accent or (theme.ButtonBackground or theme.SectionBackground)
                        child.TextColor3 = tog and Color3.fromRGB(255,255,255) or theme.Text
                    end
                    child.BackgroundTransparency = child.BackgroundTransparency
                elseif child:IsA("TextBox") then
                    child.BackgroundColor3 = theme.InputBackground or theme.SectionBackground
                    child.TextColor3 = theme.Text
                    child.BackgroundTransparency = child.BackgroundTransparency
                elseif child:IsA("UIStroke") then
                    -- Update stroke colors for dropdown borders
                    child.Color = theme.TabBackground or Color3.fromRGB(100, 100, 100)
                end
            end
        end
    end

    -- Update notifications
    for _, notif in ipairs(Window._notifications) do
        if notif and notif.Parent then
            notif.BackgroundColor3 = theme.SectionBackground
            notif.BackgroundTransparency = notif.BackgroundTransparency
            
            for _, c in ipairs(notif:GetChildren()) do
                if c:IsA("Frame") and c.Size and c.Size.X.Offset == 6 then
                    c.BackgroundColor3 = theme.Accent
                elseif c:IsA("TextLabel") then
                    c.TextColor3 = theme.Text
                end
            end
        end
    end
    
    -- Force a render update
    if Window.ScreenGui then
        Window.ScreenGui.Enabled = false
        task.wait()
        Window.ScreenGui.Enabled = true
    end
        -- Update window control buttons
if Window._minimizeBtn and Window._minimizeBtn.Parent then
    Window._minimizeBtn.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
    Window._minimizeBtn.TextColor3 = theme.Text
end

if Window._closeBtn and Window._closeBtn.Parent then
    -- Close button keeps its red color
    Window._closeBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    Window._closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end

if Window._topbar and Window._topbar.Parent then
    Window._topbar.BackgroundColor3 = theme.SectionBackground
end

if Window._title and Window._title.Parent then
    Window._title.TextColor3 = theme.Text
end
    
    print("Theme successfully changed to:", newThemeName)
end

    -- Toggle UI methods
    function Window:Hide()
        if not Window._uiVisible then return end
        Window._storedPosition = Main.Position
        tween(Main, {Position = UDim2.new(0.5, -300, 0.5, -800)}, {duration = 0.18})
        task.delay(0.18, function()
            if ScreenGui then
                ScreenGui.Enabled = false
            end
        end)
        Window._uiVisible = false
    end

    function Window:Show()
        if Window._uiVisible then return end
        if ScreenGui then ScreenGui.Enabled = true end

        if Window._uiMinimized then
            Window:Restore()
        end

        local target = Window._storedPosition or UDim2.new(0.5, -300, 0.5, -200)
        tween(Main, {Position = target}, {duration = 0.18})
        Window._uiVisible = true
    end

    function Window:ToggleUI()
        if Window._uiVisible then
            Window:Hide()
        else
            Window:Show()
        end
    end

    function Window:SetToggleKey(keyEnum)
    if typeof(keyEnum) == "EnumItem" and keyEnum.EnumType == Enum.KeyCode then
        Window._toggleKey = keyEnum
        
        -- Disconnect existing listener if any
        if Window._inputConn then
            pcall(function() Window._inputConn:Disconnect() end)
        end
        
        -- Create new input listener
        Window._inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard and 
               input.KeyCode == Window._toggleKey then
                Window:ToggleUI()
            end
        end)
        globalConnTracker:add(Window._inputConn)
    end
end

    -- Minimize/Restore methods
    function Window:Minimize()
        if self._uiMinimized then return end
        self._uiMinimized = true

        local header = (self.Topbar or Topbar)
        local headerHeight = (header and header.AbsoluteSize and header.AbsoluteSize.Y) or 40

        if self.Main then
            pcall(function()
                tween(self.Main, {Size = UDim2.new(self._storedSize.X.Scale, self._storedSize.X.Offset, 0, headerHeight)}, {duration = 0.18})
            end)
        end

        if TabContainer then pcall(function() TabContainer.Visible = false end) end
        if Content    then pcall(function() Content.Visible = false end) end

        if Tabs and type(Tabs) == "table" then
            for _, tab in ipairs(Tabs) do
                pcall(function() if tab and tab.Button then tab.Button.Visible = false end end)
            end
        end
    end

    function Window:Restore()
        if not self._uiMinimized then return end
        self._uiMinimized = false

        if self._storedSize and self.Main then
            pcall(function()
                tween(self.Main, {Size = self._storedSize}, {duration = 0.18})
            end)
        end

        if TabContainer then pcall(function() TabContainer.Visible = true end) end
        if Content then
            pcall(function()
                local themeBg = (self.theme and self.theme.Background) or (theme and theme.Background)
                if themeBg then
                    Content.BackgroundColor3 = themeBg
                end
                Content.Visible = true
            end)
        end

        if Tabs and type(Tabs) == "table" then
            for _, tab in ipairs(Tabs) do
                pcall(function() if tab and tab.Button then tab.Button.Visible = true end end)
            end
        end
    end

    function Window:ToggleMinimize()
        if self._uiMinimized then
            self:Restore()
        else
            self:Minimize()
        end
    end

    -- Enhanced Destroy method with complete cleanup
    function Window:Destroy()
        -- Cancel tweens that reference this window's objects
        for obj, props in pairs(ActiveTweens) do
            if obj and obj:IsDescendantOf(Main) then
                for prop, tweenObj in pairs(props) do
                    pcall(function() tweenObj:Cancel() end)
                end
                ActiveTweens[obj] = nil
            end
        end

        -- Disconnect toggle key listener
        if self._inputConn then
            pcall(function() self._inputConn:Disconnect() end)
            self._inputConn = nil
        end

        -- Close any open dropdown/popup for this window
        if Window._currentOpenDropdown and type(Window._currentOpenDropdown) == "function" then
            pcall(function() Window._currentOpenDropdown() end)
            Window._currentOpenDropdown = nil
        end

        -- Disconnect all tracked connections and cancel tweens
        if self._connTracker then
            pcall(function() self._connTracker.disconnectAll() end)
            self._connTracker = nil
        end

        -- Clear hover debounce states
        for k in pairs(HoverDebounce) do
            HoverDebounce[k] = nil
        end

        -- Destroy the ScreenGui
        if self.ScreenGui then
            pcall(function() self.ScreenGui:Destroy() end)
            self.ScreenGui = nil
        end

        -- Clear tables to help GC
        self._notifications = {}
        Tabs = {}

        -- Clear window reference fields
        setmetatable(self, nil)
        for k in pairs(self) do
            self[k] = nil
        end
    end

    -- Tab creation helper
    function Window:NewTab(tabName)
        local TabButton = Instance.new("TextButton")
        TabButton.Size = UDim2.new(1, -20, 0, 40)
        TabButton.BackgroundColor3 = theme.SectionBackground
        TabButton.TextColor3 = theme.Text
        TabButton.Font = Enum.Font.Gotham
        TabButton.TextSize = 14
        TabButton.Text = tabName or "Tab"
        TabButton.AutoButtonColor = false
        TabButton.Parent = TabContainer

        local TabButtonCorner = Instance.new("UICorner")
        TabButtonCorner.CornerRadius = UDim.new(0, 6)
        TabButtonCorner.Parent = TabButton

        local TabButtonPadding = Instance.new("UIPadding")
        TabButtonPadding.PaddingTop = UDim.new(0, 8)
        TabButtonPadding.PaddingBottom = UDim.new(0, 8)
        TabButtonPadding.PaddingLeft = UDim.new(0, 10)
        TabButtonPadding.PaddingRight = UDim.new(0, 10)
        TabButtonPadding.Parent = TabButton

        -- Debounced hover for tab buttons
        debouncedHover(TabButton,
            function()
                if not TabButton:GetAttribute("active") then
                    tween(TabButton, {BackgroundColor3 = theme.TabBackground, Size = UDim2.new(1, -16, 0, 42)}, {duration = 0.1})
                end
            end,
            function()
                if TabButton:GetAttribute("active") then
                    tween(TabButton, {BackgroundColor3 = theme.Accent, Size = UDim2.new(1, -20, 0, 40)}, {duration = 0.1})
                else
                    tween(TabButton, {BackgroundColor3 = theme.SectionBackground, Size = UDim2.new(1, -20, 0, 40)}, {duration = 0.1})
                end
            end
        )

        local TabFrame = Instance.new("ScrollingFrame")
        TabFrame.Size = UDim2.new(1, 0, 1, 0)
        TabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        TabFrame.ScrollBarThickness = 6
        TabFrame.BackgroundTransparency = 1
        TabFrame.Visible = false
        TabFrame.Parent = Content

        local TabLayout = Instance.new("UIListLayout")
        TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        TabLayout.Padding = UDim.new(0, 10)
        TabLayout.Parent = TabFrame

        local TabFramePadding = Instance.new("UIPadding")
        TabFramePadding.PaddingTop = UDim.new(0, 8)
        TabFramePadding.PaddingLeft = UDim.new(0, 8)
        TabFramePadding.PaddingRight = UDim.new(0, 8)
        TabFramePadding.Parent = TabFrame

        TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local s = TabLayout.AbsoluteContentSize
            TabFrame.CanvasSize = UDim2.new(0, 0, 0, s.Y + 8)
        end)

        TabButton.MouseButton1Click:Connect(function()
            for _, t in ipairs(Tabs) do
                t.Button:SetAttribute("active", false)
                t.Button.BackgroundColor3 = theme.SectionBackground
                t.Button.TextColor3 = theme.Text
                t.Frame.Visible = false
            end
            TabButton:SetAttribute("active", true)
            TabButton.BackgroundColor3 = theme.Accent
            TabButton.TextColor3 = Color3.fromRGB(255,255,255)
            TabFrame.Visible = true
        end)

        table.insert(Tabs, {Button = TabButton, Frame = TabFrame})

        -- Auto-select first tab
        if not Window._currentTab then
            Window._currentTab = TabButton
            for _, t in ipairs(Tabs) do
                t.Button:SetAttribute("active", false)
                t.Button.BackgroundColor3 = theme.SectionBackground
                t.Button.TextColor3 = theme.Text
                t.Frame.Visible = false
            end
            TabButton:SetAttribute("active", true)
            TabButton.BackgroundColor3 = theme.Accent
            TabButton.TextColor3 = Color3.fromRGB(255,255,255)
            TabFrame.Visible = true
        end

        local TabObj = {}

        function TabObj:NewSection(sectionName)
            local Section = Instance.new("Frame")
            Section.Size = UDim2.new(1, -10, 0, 50)
            Section.BackgroundColor3 = theme.SectionBackground
            Section.Parent = TabFrame
            Section.AutomaticSize = Enum.AutomaticSize.Y
            Section.Name = "_section"

            local SectionCorner = Instance.new("UICorner")
            SectionCorner.CornerRadius = UDim.new(0, 6)
            SectionCorner.Parent = Section

            local SectionLayout = Instance.new("UIListLayout")
            SectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
            SectionLayout.Padding = UDim.new(0, 6)
            SectionLayout.Parent = Section

            local SectionPadding = Instance.new("UIPadding")
            SectionPadding.PaddingTop = UDim.new(0, 8)
            SectionPadding.PaddingBottom = UDim.new(0, 8)
            SectionPadding.PaddingLeft = UDim.new(0, 8)
            SectionPadding.PaddingRight = UDim.new(0, 8)
            SectionPadding.Parent = Section

            local Label = Instance.new("TextLabel")
            Label.Text = sectionName
            Label.Size = UDim2.new(1, 0, 0, 20)
            Label.BackgroundTransparency = 1
            Label.TextColor3 = theme.SubText
            Label.Font = Enum.Font.GothamBold
            Label.TextSize = 14
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = Section

            local SectionObj = {}

            function SectionObj:NewLabel(text)
                local lbl = Instance.new("TextLabel")
                lbl.Text = text or ""
                lbl.Size = UDim2.new(1, 0, 0, 18)
                lbl.BackgroundTransparency = 1
                lbl.TextColor3 = theme.Text
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = Section
                return lbl
            end

            function SectionObj:NewSeparator()
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1, 0, 0, 8)
                sep.BackgroundTransparency = 1
                sep.Parent = Section
                local line = Instance.new("Frame")
                line.Size = UDim2.new(1, -8, 0, 2)
                line.Position = UDim2.new(0, 4, 0, 3)
                line.BackgroundColor3 = theme.TabBackground
                line.BorderSizePixel = 0
                line.Parent = sep
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 2)
                corner.Parent = line
                return line
            end

            function SectionObj:NewButton(text, desc, callback)
                if type(text) ~= "string" then text = tostring(text or "Button") end
                if callback ~= nil and type(callback) ~= "function" then warn("NewButton: callback is not a function") end

                local Btn = Instance.new("TextButton")
                Btn.Text = text
                Btn.Size = UDim2.new(1, 0, 0, 34)
                Btn.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
                Btn.TextColor3 = theme.Text
                Btn.Font = Enum.Font.Gotham
                Btn.TextSize = 14
                Btn.AutoButtonColor = false
                Btn.Parent = Section

                local BtnCorner = Instance.new("UICorner")
                BtnCorner.CornerRadius = UDim.new(0, 6)
                BtnCorner.Parent = Btn

                debouncedHover(Btn,
                    function()
                        tween(Btn, {BackgroundColor3 = theme.ButtonHover or theme.TabBackground, Size = UDim2.new(1, -6, 0, 36)}, {duration = 0.08})
                    end,
                    function()
                        tween(Btn, {BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground, Size = UDim2.new(1, 0, 0, 34)}, {duration = 0.08})
                    end
                )

                Btn.MouseButton1Click:Connect(function()
                    local t1 = tween(Btn, {BackgroundColor3 = theme.Accent, Size = UDim2.new(1, -8, 0, 32)}, {duration = 0.08})
                    if t1 then
                        local c
                        c = t1.Completed:Connect(function()
                            pcall(function() c:Disconnect() end)
                            tween(Btn, {BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground, Size = UDim2.new(1, 0, 0, 34)}, {duration = 0.12})
                        end)
                    else
                        task.delay(0.09, function() tween(Btn, {BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground, Size = UDim2.new(1, 0, 0, 34)}, {duration = 0.12}) end)
                    end
                    safeCallback(callback)
                end)

                return Btn
            end

            function SectionObj:NewToggle(text, desc, callback)
                if type(text) ~= "string" then text = tostring(text or "Toggle") end
                if callback ~= nil and type(callback) ~= "function" then warn("NewToggle: callback is not a function") end

                local ToggleBtn = Instance.new("TextButton")
                ToggleBtn.Text = text .. " [OFF]"
                ToggleBtn.Size = UDim2.new(1, 0, 0, 34)
                ToggleBtn.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
                ToggleBtn.TextColor3 = theme.Text
                ToggleBtn.Font = Enum.Font.Gotham
                ToggleBtn.TextSize = 14
                ToggleBtn.AutoButtonColor = false
                ToggleBtn.Parent = Section

                local ToggleCorner = Instance.new("UICorner")
                ToggleCorner.CornerRadius = UDim.new(0, 6)
                ToggleCorner.Parent = ToggleBtn

                local state = false
                ToggleBtn:SetAttribute("_isToggleState", true)
                ToggleBtn:SetAttribute("_toggle", state)

                debouncedHover(ToggleBtn,
                    function()
                        tween(ToggleBtn, {BackgroundColor3 = theme.ButtonHover or theme.TabBackground, Size = UDim2.new(1, -6, 0, 36)}, {duration = 0.08})
                    end,
                    function()
                        local bg = state and theme.Accent or (theme.ButtonBackground or theme.SectionBackground)
                        tween(ToggleBtn, {BackgroundColor3 = bg, Size = UDim2.new(1, 0, 0, 34)}, {duration = 0.08})
                    end
                )

                ToggleBtn.MouseButton1Click:Connect(function()
                    local t1 = tween(ToggleBtn, {Size = UDim2.new(1, -8, 0, 32)}, {duration = 0.08})
                    if t1 then
                        local c
                        c = t1.Completed:Connect(function()
                            pcall(function() c:Disconnect() end)
                            tween(ToggleBtn, {Size = UDim2.new(1, 0, 0, 34)}, {duration = 0.12})
                        end)
                    else
                        task.delay(0.09, function() tween(ToggleBtn, {Size = UDim2.new(1, 0, 0, 34)}, {duration = 0.12}) end)
                    end
                    state = not state
                    ToggleBtn.Text = text .. (state and " [ON]" or " [OFF]")
                    if state then
                        ToggleBtn.BackgroundColor3 = theme.Accent
                        ToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
                    else
                        ToggleBtn.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
                        ToggleBtn.TextColor3 = theme.Text
                    end
                    ToggleBtn:SetAttribute("_toggle", state)
                    safeCallback(callback, state)
                end)

                return {
                    Button = ToggleBtn,
                    GetState = function() return state end,
                    SetState = function(v)
                        state = not not v
                        ToggleBtn.Text = text .. (state and " [ON]" or " [OFF]")
                        ToggleBtn.BackgroundColor3 = state and theme.Accent or (theme.ButtonBackground or theme.SectionBackground)
                        ToggleBtn.TextColor3 = state and Color3.fromRGB(255,255,255) or theme.Text
                        ToggleBtn:SetAttribute("_toggle", state)
                        safeCallback(callback, state)
                    end
                }
            end

           -- FIXED SLIDER FUNCTION  
function SectionObj:NewSlider(text, min, max, default, callback)
    if type(min) ~= "number" then min = 0 end
    if type(max) ~= "number" then max = 100 end
    if min > max then local t = min; min = max; max = t end
    if default == nil then default = min end
    if type(default) ~= "number" then default = tonumber(default) or min end
    if default < min then default = min end
    if default > max then default = max end

    local currentValue = default
    local precision = 0
    
    -- Auto-detect precision based on range
    local range = max - min
    if range <= 1 then
        precision = 2
    elseif range <= 10 then
        precision = 1
    else
        precision = 0
    end

    local function roundValue(value)
        local mult = 10 ^ precision
        return math.floor(value * mult + 0.5) / mult
    end

    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 58)
    wrap.BackgroundTransparency = 1
    wrap.Parent = Section

    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(0.7, -8, 0, 18)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = theme.SubText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = wrap

    -- Value display label
    local valueLbl = Instance.new("TextLabel")
    valueLbl.Text = tostring(roundValue(currentValue))
    valueLbl.Size = UDim2.new(0.3, -8, 0, 18)
    valueLbl.Position = UDim2.new(0.7, 0, 0, 0)
    valueLbl.BackgroundTransparency = 1
    valueLbl.TextColor3 = theme.Accent
    valueLbl.Font = Enum.Font.GothamBold
    valueLbl.TextSize = 13
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right
    valueLbl.Parent = wrap

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -8, 0, 20)
    sliderBg.Position = UDim2.new(0, 4, 0, 32)
    sliderBg.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
    sliderBg.Parent = wrap

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = sliderBg

    local fill = Instance.new("Frame")
    local initialRel = 0
    if max > min then
        initialRel = (currentValue - min) / (max - min)
    end
    fill.Size = UDim2.new(initialRel, 0, 1, 0)
    fill.BackgroundColor3 = theme.Accent
    fill.Parent = sliderBg
    fill.ZIndex = 2

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 10)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(initialRel, -8, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Parent = sliderBg
    knob.ZIndex = 3

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    -- Add knob shadow/border
    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = theme.Accent
    knobStroke.Thickness = 2
    knobStroke.Parent = knob

    local dragging = false

    local function updateSlider(inputPos)
        local relativeX = inputPos.X - sliderBg.AbsolutePosition.X
        local relativePos = math.clamp(relativeX / sliderBg.AbsoluteSize.X, 0, 1)
        
        local newValue = min + (max - min) * relativePos
        newValue = roundValue(newValue)
        newValue = math.clamp(newValue, min, max)
        currentValue = newValue

        -- Update UI
        local finalRel = (newValue - min) / (max - min)
        tween(fill, {Size = UDim2.new(finalRel, 0, 1, 0)}, {duration = 0.05})
        tween(knob, {Position = UDim2.new(finalRel, -8, 0.5, -8)}, {duration = 0.05})
        valueLbl.Text = tostring(newValue)

        -- Call callback with properly clamped value
        if callback and type(callback) == "function" then
            safeCallback(callback, newValue)
        end
    end

    -- Mouse/touch interactions
    local beganConn = sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input.Position)
            
            -- Visual feedback
            tween(knob, {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new((currentValue - min) / (max - min), -10, 0.5, -10)}, {duration = 0.08})
        end
    end)

    local changedConn = UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            updateSlider(input.Position)
        end
    end)

    local endedConn = UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or 
                        input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            
            -- Reset knob size
            tween(knob, {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new((currentValue - min) / (max - min), -8, 0.5, -8)}, {duration = 0.08})
        end
    end)

    -- Hover effects
    local hoverConn1 = sliderBg.MouseEnter:Connect(function()
        if not dragging then
            tween(knobStroke, {Thickness = 3}, {duration = 0.1})
        end
    end)

    local hoverConn2 = sliderBg.MouseLeave:Connect(function()
        if not dragging then
            tween(knobStroke, {Thickness = 2}, {duration = 0.1})
        end
    end)

    -- Track connections for cleanup
    globalConnTracker:add(beganConn)
    globalConnTracker:add(changedConn) 
    globalConnTracker:add(endedConn)
    globalConnTracker:add(hoverConn1)
    globalConnTracker:add(hoverConn2)

    return {
        Set = function(value)
            if type(value) ~= "number" then
                value = tonumber(value)
                if not value then return end
            end
            
            value = math.clamp(value, min, max)
            currentValue = roundValue(value)
            
            local rel = (currentValue - min) / (max - min)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, -8, 0.5, -8)
            valueLbl.Text = tostring(currentValue)
            
            if callback and type(callback) == "function" then
                safeCallback(callback, currentValue)
            end
        end,
        Get = function()
            return currentValue
        end,
        SetMin = function(newMin)
            min = newMin
            if currentValue < min then
                currentValue = min
                valueLbl.Text = tostring(currentValue)
            end
        end,
        SetMax = function(newMax)
            max = newMax
            if currentValue > max then
                currentValue = max
                valueLbl.Text = tostring(currentValue)
            end
        end
    }
end

            function SectionObj:NewTextbox(placeholder, defaultText, callback)
                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 34)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local box = Instance.new("TextBox")
                box.Size = UDim2.new(1, 0, 1, 0)
                box.BackgroundColor3 = theme.InputBackground or theme.SectionBackground
                box.TextColor3 = theme.Text
                box.ClearTextOnFocus = false
                box.Text = defaultText or ""
                box.PlaceholderText = placeholder or ""
                box.Font = Enum.Font.Gotham
                box.TextSize = 14
                box.Parent = wrap

                local boxCorner = Instance.new("UICorner")
                boxCorner.CornerRadius = UDim.new(0, 6)
                boxCorner.Parent = box

                box.FocusLost:Connect(function(enterPressed)
                    if enterPressed and type(callback) == "function" then
                        safeCallback(callback, box.Text)
                    end
                end)

                return {
                    TextBox = box,
                    Get = function() return box.Text end,
                    Set = function(v) box.Text = tostring(v) end,
                    Focus = function() box:CaptureFocus() end
                }
            end

            function SectionObj:NewKeybind(desc, defaultKey, callback)
                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 34)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local btn = Instance.new("TextButton")
                local curKey = defaultKey and (tostring(defaultKey):gsub("^Enum.KeyCode%.","")) or "None"
                btn.Text = (desc and desc .. " : " or "") .. "[" .. curKey .. "]"
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.BackgroundColor3 = theme.SectionBackground
                btn.TextColor3 = theme.Text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.AutoButtonColor = false
                btn.Parent = wrap

                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 6)
                btnCorner.Parent = btn

                local capturing = false
                local boundKey = defaultKey

                local function updateDisplay()
                    local kName = boundKey and (tostring(boundKey):gsub("^Enum.KeyCode%.","")) or "None"
                    btn.Text = (desc and desc .. " : " or "") .. "[" .. kName .. "]"
                end

                btn.MouseButton1Click:Connect(function()
                    capturing = true
                    btn.Text = (desc and desc .. " : " or "") .. "[Press a key...]"
                end)

                local listenerConn
                listenerConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed then return end
                    if capturing then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            boundKey = input.KeyCode
                            capturing = false
                            updateDisplay()
                        end
                        return
                    end

                    if boundKey and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == boundKey then
                        safeCallback(callback)
                    end
                end)

                globalConnTracker:add(listenerConn)

                return {
                    Button = btn,
                    GetKey = function() return boundKey end,
                    SetKey = function(k) boundKey = k; updateDisplay() end,
                    Disconnect = function() if listenerConn then pcall(function() listenerConn:Disconnect() end) end end
                }
            end

 -- DROPDOWN FIX for Kour6anHub Library
function SectionObj:NewDropdown(name, options, callback)
    -- Ensure options is a proper array of strings
    options = options or {}
    if type(options) ~= "table" then 
        options = {} 
    end
    
    -- Convert all options to strings and validate
    local validOptions = {}
    for i, opt in ipairs(options) do
        if opt ~= nil then
            validOptions[i] = tostring(opt)
        end
    end
    options = validOptions
    
    local current = options[1] or nil
    local open = false
    local optionsFrame = nil
    local scrollFrame = nil
    local optionButtons = {}
    local selectedIndex = current and 1 or nil

    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 34)
    wrap.BackgroundTransparency = 1
    wrap.Parent = Section

    local btn = Instance.new("TextButton")
    local displayText = current or "Select..."
    btn.Text = (name and name .. ": " or "") .. displayText
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
    btn.TextColor3 = theme.Text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = wrap

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local btnPadding = Instance.new("UIPadding")
    btnPadding.PaddingLeft = UDim.new(0, 8)
    btnPadding.PaddingRight = UDim.new(0, 28)
    btnPadding.Parent = btn

    -- Add dropdown arrow indicator
    local arrow = Instance.new("TextLabel")
    arrow.Text = getArrowChar("down")
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -20, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.TextColor3 = theme.Text
    arrow.Font = Enum.Font.Gotham
    arrow.TextSize = 12
    arrow.TextXAlignment = Enum.TextXAlignment.Center
    arrow.Parent = btn

    local function getMaxDropdownHeight()
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
        return math.min(200, math.floor(viewport.Y * 0.3))
    end
    
    local function closeOptions()
        if optionsFrame and optionsFrame.Parent and optionsFrame.Visible then
            arrow.Text = getArrowChar("down")
            
            local closeTween = tween(optionsFrame, {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1
            }, {duration = 0.12})
            
            if scrollFrame then
                tween(scrollFrame, {ScrollBarImageTransparency = 1}, {duration = 0.08})
            end
            
            for _, optBtn in pairs(optionButtons) do
                if optBtn and optBtn.Parent then
                    tween(optBtn, {BackgroundTransparency = 1, TextTransparency = 1}, {duration = 0.08})
                end
            end
            
            if closeTween then
                local conn
                conn = closeTween.Completed:Connect(function()
                    pcall(function() conn:Disconnect() end)
                    if optionsFrame then optionsFrame.Visible = false end
                end)
            else
                task.wait(0.12)
                if optionsFrame then optionsFrame.Visible = false end
            end
        end
        open = false
        wrap.Size = UDim2.new(1, 0, 0, 34)
        
        if Window._currentOpenDropdown == closeOptions then
            Window._currentOpenDropdown = nil
        end
    end

    local function createOptionsFrame()
        if optionsFrame then
            pcall(function() optionsFrame:Destroy() end)
        end
        
        -- Create main options container
        optionsFrame = Instance.new("Frame")
        optionsFrame.Name = "_dropdownOptions"
        optionsFrame.BackgroundColor3 = theme.SectionBackground
        optionsFrame.BorderSizePixel = 0
        optionsFrame.Position = UDim2.new(0, 0, 0, 36)
        optionsFrame.Size = UDim2.new(1, 0, 0, 0)
        optionsFrame.Visible = false
        optionsFrame.ClipsDescendants = true
        optionsFrame.ZIndex = 100
        optionsFrame.Parent = wrap

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = optionsFrame

        local border = Instance.new("UIStroke")
        border.Color = theme.TabBackground or Color3.fromRGB(100, 100, 100)
        border.Thickness = 1
        border.Transparency = 0.5
        border.Parent = optionsFrame

        -- Create ScrollingFrame for options
        scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Name = "_optionsScroll"
        scrollFrame.Size = UDim2.new(1, -4, 1, -4)
        scrollFrame.Position = UDim2.new(0, 2, 0, 2)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.BorderSizePixel = 0
        scrollFrame.ScrollBarThickness = 4
        scrollFrame.ScrollBarImageColor3 = theme.Accent or Color3.fromRGB(100, 100, 100)
        scrollFrame.ScrollBarImageTransparency = 0.3
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.ZIndex = 101
        scrollFrame.Parent = optionsFrame

        return optionsFrame, scrollFrame
    end

    local function openOptions()
        if #options == 0 then
            Window:Notify("Dropdown Error", "No options available", 2)
            return
        end

        if Window._currentOpenDropdown and Window._currentOpenDropdown ~= closeOptions then
            pcall(function() Window._currentOpenDropdown() end)
        end

        createOptionsFrame()
        open = true
        arrow.Text = getArrowChar("up")

        optionButtons = {}

        -- Calculate dimensions
        local itemHeight = 28
        local maxHeight = getMaxDropdownHeight()
        local totalContentHeight = #options * itemHeight
        local frameHeight = math.min(maxHeight, totalContentHeight)

        -- Set canvas size for scrolling
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalContentHeight)

        -- Create option buttons in the scroll frame
        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, -8, 0, itemHeight - 2)
            optBtn.Position = UDim2.new(0, 4, 0, (i-1) * itemHeight + 1)
            optBtn.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 12
            optBtn.TextColor3 = theme.Text
            optBtn.AutoButtonColor = false
            optBtn.Text = tostring(opt)
            optBtn.TextXAlignment = Enum.TextXAlignment.Left
            optBtn.BackgroundTransparency = 1
            optBtn.TextTransparency = 1
            optBtn.ZIndex = 102
            optBtn.Parent = scrollFrame

            local optCorner = Instance.new("UICorner")
            optCorner.CornerRadius = UDim.new(0, 4)
            optCorner.Parent = optBtn

            local optPadding = Instance.new("UIPadding")
            optPadding.PaddingLeft = UDim.new(0, 8)
            optPadding.PaddingRight = UDim.new(0, 8)
            optPadding.Parent = optBtn

            if current and tostring(opt) == tostring(current) then
                selectedIndex = i
                optBtn.BackgroundColor3 = theme.Accent
                optBtn.TextColor3 = Color3.fromRGB(255,255,255)
            end

            -- Hover effects
            local hoverConn1 = optBtn.MouseEnter:Connect(function()
                if selectedIndex ~= i then
                    tween(optBtn, {BackgroundColor3 = theme.ButtonHover or theme.TabBackground}, {duration = 0.08})
                end
            end)

            local hoverConn2 = optBtn.MouseLeave:Connect(function()
                if selectedIndex ~= i then
                    tween(optBtn, {BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground}, {duration = 0.08})
                end
            end)

            local clickConn = optBtn.MouseButton1Click:Connect(function()
                selectedIndex = i
                current = options[i]
                btn.Text = (name and name .. ": " or "") .. tostring(current)
                
                for idx, button in pairs(optionButtons) do
                    if button and button.Parent then
                        if idx == selectedIndex then
                            button.BackgroundColor3 = theme.Accent
                            button.TextColor3 = Color3.fromRGB(255,255,255)
                        else
                            button.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
                            button.TextColor3 = theme.Text
                        end
                    end
                end
                
                if callback and type(callback) == "function" then
                    safeCallback(callback, current)
                end
                
                task.wait(0.1)
                closeOptions()
            end)

            optionButtons[i] = optBtn
        end

        -- Show and animate
        optionsFrame.Visible = true
        optionsFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarImageTransparency = 1

        tween(optionsFrame, {
            Size = UDim2.new(1, 0, 0, frameHeight + 4),
            BackgroundTransparency = 0
        }, {duration = 0.15})

        tween(scrollFrame, {ScrollBarImageTransparency = 0.3}, {duration = 0.15})

        for i, optBtn in pairs(optionButtons) do
            task.delay(i * 0.02, function()
                if optBtn and optBtn.Parent then
                    tween(optBtn, {
                        BackgroundTransparency = 0,
                        TextTransparency = 0
                    }, {duration = 0.1})
                end
            end)
        end

        wrap.Size = UDim2.new(1, 0, 0, 34 + frameHeight + 6)
        Window._currentOpenDropdown = closeOptions
    end

    btn.MouseButton1Click:Connect(function()
        if open then
            closeOptions()
        else
            openOptions()
        end
    end)

    -- Outside click detection
    local outsideClickConn
    outsideClickConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not open then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mouse = UserInputService:GetMouseLocation()
            local wrapPos = wrap.AbsolutePosition
            local wrapSize = wrap.AbsoluteSize
            
            if mouse.X < wrapPos.X or mouse.X > wrapPos.X + wrapSize.X or
               mouse.Y < wrapPos.Y or mouse.Y > wrapPos.Y + wrapSize.Y then
                closeOptions()
            end
        end
    end)

    globalConnTracker:add(outsideClickConn)

    local ancestryConn
    ancestryConn = wrap.AncestryChanged:Connect(function()
        if not wrap.Parent then
            pcall(function() 
                outsideClickConn:Disconnect()
                ancestryConn:Disconnect()
            end)
        end
    end)
    globalConnTracker:add(ancestryConn)

   return {
    Set = function(value)
        local stringValue = tostring(value)
        for i, opt in ipairs(options) do
            if tostring(opt) == stringValue then
                current = opt
                selectedIndex = i
                btn.Text = (name and name .. ": " or "") .. stringValue
                -- 🔽 trigger callback when Set is used
                if callback and type(callback) == "function" then
                    safeCallback(callback, current)
                end
                return true
            end
        end
        current = stringValue
        btn.Text = (name and name .. ": " or "") .. stringValue
        if callback and type(callback) == "function" then
            safeCallback(callback, current)
        end
        return false
    end,
    Get = function()
        return current
    end,
    SetOptions = function(newOptions)
            newOptions = newOptions or {}
            if type(newOptions) ~= "table" then
                newOptions = {}
            end
            
            local validNewOptions = {}
            for i, opt in ipairs(newOptions) do
                if opt ~= nil then
                    validNewOptions[i] = tostring(opt)
                end
            end
            options = validNewOptions
            
            if #options > 0 then
                current = options[1]
                selectedIndex = 1
                btn.Text = (name and name .. ": " or "") .. tostring(current)
            else
                current = nil
                selectedIndex = nil
                btn.Text = (name and name .. ": " or "") .. "Select..."
            end
            closeOptions()
        end,
        Close = closeOptions
    }
end

-- Fixed Colorpicker implementation for Kour6anHub
-- This replaces the existing NewColorpicker function in SectionObj

function SectionObj:NewColorpicker(name, defaultColor, callback)
    local currentColor = typeof(defaultColor) == "Color3" and defaultColor or Color3.fromRGB(255, 255, 255)
    local currentH, currentS, currentV = Color3.toHSV(currentColor)
    local connections = {}
    
    -- Main container
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 34)
    container.BackgroundTransparency = 1
    container.Parent = Section

    -- Main button
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
    button.AutoButtonColor = false
    button.Font = Enum.Font.Gotham
    button.TextSize = 13
    button.TextColor3 = theme.Text
    button.Text = (name and name .. " " or "") .. "Color Picker"
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Parent = container

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = button

    local buttonPadding = Instance.new("UIPadding")
    buttonPadding.PaddingLeft = UDim.new(0, 8)
    buttonPadding.PaddingRight = UDim.new(0, 34)
    buttonPadding.Parent = button

    -- Color preview
    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 24, 0, 24)
    preview.Position = UDim2.new(1, -30, 0.5, -12)
    preview.BackgroundColor3 = currentColor
    preview.BorderSizePixel = 0
    preview.Parent = container

    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 6)
    previewCorner.Parent = preview

    -- Create dialog function
    local function createColorDialog()
        -- Create dialog overlay
        local dialogOverlay = Instance.new("Frame")
        dialogOverlay.Name = "ColorPickerDialog"
        dialogOverlay.Size = UDim2.new(1, 0, 1, 0)
        dialogOverlay.Position = UDim2.new(0, 0, 0, 0)
        dialogOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        dialogOverlay.BackgroundTransparency = 0.5
        dialogOverlay.ZIndex = 10000
        dialogOverlay.Parent = Window.ScreenGui

        -- Dialog frame
        local dialog = Instance.new("Frame")
        dialog.Size = UDim2.new(0, 430, 0, 330)
        dialog.Position = UDim2.new(0.5, -215, 0.5, -165)
        dialog.BackgroundColor3 = theme.SectionBackground
        dialog.ZIndex = 10001
        dialog.Parent = dialogOverlay

        local dialogCorner = Instance.new("UICorner")
        dialogCorner.CornerRadius = UDim.new(0, 8)
        dialogCorner.Parent = dialog

        -- Dialog title
        local title = Instance.new("TextLabel")
        title.Text = name or "Color Picker"
        title.Size = UDim2.new(1, -16, 0, 30)
        title.Position = UDim2.new(0, 8, 0, 8)
        title.BackgroundTransparency = 1
        title.TextColor3 = theme.Text
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 10002
        title.Parent = dialog

        -- Working variables
        local workingH, workingS, workingV = currentH, currentS, currentV

        -- Saturation-Value map
        local satVibMap = Instance.new("ImageLabel")
        satVibMap.Size = UDim2.new(0, 180, 0, 160)
        satVibMap.Position = UDim2.new(0, 20, 0, 55)
        satVibMap.Image = "rbxassetid://4155801252"
        satVibMap.BackgroundColor3 = Color3.fromHSV(workingH, 1, 1)
        satVibMap.ZIndex = 10002
        satVibMap.Parent = dialog

        local mapCorner = Instance.new("UICorner")
        mapCorner.CornerRadius = UDim.new(0, 4)
        mapCorner.Parent = satVibMap

        -- Saturation-Value cursor
        local satVibCursor = Instance.new("ImageLabel")
        satVibCursor.Size = UDim2.new(0, 18, 0, 18)
        satVibCursor.Position = UDim2.new(workingS, -9, 1 - workingV, -9)
        satVibCursor.Image = "rbxassetid://4805639000"
        satVibCursor.BackgroundTransparency = 1
        satVibCursor.AnchorPoint = Vector2.new(0.5, 0.5)
        satVibCursor.ZIndex = 10003
        satVibCursor.Parent = satVibMap

        -- Hue slider
        local hueSlider = Instance.new("Frame")
        hueSlider.Size = UDim2.new(0, 12, 0, 190)
        hueSlider.Position = UDim2.new(0, 210, 0, 55)
        hueSlider.ZIndex = 10002
        hueSlider.Parent = dialog

        local hueCorner = Instance.new("UICorner")
        hueCorner.CornerRadius = UDim.new(1, 0)
        hueCorner.Parent = hueSlider

        -- Hue gradient
        local hueGradient = Instance.new("UIGradient")
        hueGradient.Rotation = 90
        local sequenceTable = {}
        for i = 0, 1, 0.1 do
            table.insert(sequenceTable, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
        end
        hueGradient.Color = ColorSequence.new(sequenceTable)
        hueGradient.Parent = hueSlider

        -- Hue cursor
        local hueCursor = Instance.new("ImageLabel")
        hueCursor.Size = UDim2.new(0, 14, 0, 14)
        hueCursor.Position = UDim2.new(0, -1, workingH, -7)
        hueCursor.Image = "rbxassetid://12266946128"
        hueCursor.ImageColor3 = theme.InputBackground or Color3.fromRGB(255, 255, 255)
        hueCursor.BackgroundTransparency = 1
        hueCursor.ZIndex = 10003
        hueCursor.Parent = hueSlider

        -- Color displays
        local oldColorDisplay = Instance.new("ImageLabel")
        oldColorDisplay.Size = UDim2.new(0, 88, 0, 24)
        oldColorDisplay.Position = UDim2.new(0, 112, 0, 220)
        oldColorDisplay.Image = "rbxassetid://14204231522"
        oldColorDisplay.ImageTransparency = 0.45
        oldColorDisplay.ScaleType = Enum.ScaleType.Tile
        oldColorDisplay.TileSize = UDim2.new(0, 40, 0, 40)
        oldColorDisplay.ZIndex = 10002
        oldColorDisplay.Parent = dialog

        local oldColorFrame = Instance.new("Frame")
        oldColorFrame.Size = UDim2.new(1, 0, 1, 0)
        oldColorFrame.BackgroundColor3 = currentColor
        oldColorFrame.ZIndex = 10003
        oldColorFrame.Parent = oldColorDisplay

        local oldCorner = Instance.new("UICorner")
        oldCorner.CornerRadius = UDim.new(0, 4)
        oldCorner.Parent = oldColorDisplay

        local oldFrameCorner = Instance.new("UICorner")
        oldFrameCorner.CornerRadius = UDim.new(0, 4)
        oldFrameCorner.Parent = oldColorFrame

        local newColorDisplay = Instance.new("ImageLabel")
        newColorDisplay.Size = UDim2.new(0, 88, 0, 24)
        newColorDisplay.Position = UDim2.new(0, 20, 0, 220)
        newColorDisplay.Image = "rbxassetid://14204231522"
        newColorDisplay.ImageTransparency = 0.45
        newColorDisplay.ScaleType = Enum.ScaleType.Tile
        newColorDisplay.TileSize = UDim2.new(0, 40, 0, 40)
        newColorDisplay.ZIndex = 10002
        newColorDisplay.Parent = dialog

        local newColorFrame = Instance.new("Frame")
        newColorFrame.Size = UDim2.new(1, 0, 1, 0)
        newColorFrame.BackgroundColor3 = Color3.fromHSV(workingH, workingS, workingV)
        newColorFrame.ZIndex = 10003
        newColorFrame.Parent = newColorDisplay

        local newCorner = Instance.new("UICorner")
        newCorner.CornerRadius = UDim.new(0, 4)
        newCorner.Parent = newColorDisplay

        local newFrameCorner = Instance.new("UICorner")
        newFrameCorner.CornerRadius = UDim.new(0, 4)
        newFrameCorner.Parent = newColorFrame

        -- Input creation helper
        local function createInput(pos, labelText, defaultValue)
            local inputFrame = Instance.new("Frame")
            inputFrame.Size = UDim2.new(0, 90, 0, 32)
            inputFrame.Position = pos
            inputFrame.BackgroundColor3 = theme.InputBackground or theme.ButtonBackground
            inputFrame.ZIndex = 10002
            inputFrame.Parent = dialog

            local inputCorner = Instance.new("UICorner")
            inputCorner.CornerRadius = UDim.new(0, 4)
            inputCorner.Parent = inputFrame

            local input = Instance.new("TextBox")
            input.Size = UDim2.new(1, -12, 1, 0)
            input.Position = UDim2.new(0, 6, 0, 0)
            input.BackgroundTransparency = 1
            input.TextColor3 = theme.Text
            input.Font = Enum.Font.Gotham
            input.TextSize = 12
            input.Text = defaultValue
            input.ClearTextOnFocus = false
            input.ZIndex = 10003
            input.Parent = inputFrame

            local label = Instance.new("TextLabel")
            label.Text = labelText
            label.Size = UDim2.new(1, 0, 0, 32)
            label.Position = UDim2.new(1, 10, 0, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = theme.Text
            label.Font = Enum.Font.Gotham
            label.TextSize = 13
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.ZIndex = 10002
            label.Parent = dialog

            return input
        end

        -- Create inputs
        local hexInput = createInput(UDim2.new(0, 240, 0, 55), "Hex", "#" .. Color3.fromHSV(workingH, workingS, workingV):ToHex())
        local redInput = createInput(UDim2.new(0, 240, 0, 95), "Red", tostring(math.floor(Color3.fromHSV(workingH, workingS, workingV).r * 255)))
        local greenInput = createInput(UDim2.new(0, 240, 0, 135), "Green", tostring(math.floor(Color3.fromHSV(workingH, workingS, workingV).g * 255)))
        local blueInput = createInput(UDim2.new(0, 240, 0, 175), "Blue", tostring(math.floor(Color3.fromHSV(workingH, workingS, workingV).b * 255)))

        -- Update display function
        local function updateDisplay()
            local newColor = Color3.fromHSV(workingH, workingS, workingV)
            
            satVibMap.BackgroundColor3 = Color3.fromHSV(workingH, 1, 1)
            satVibCursor.Position = UDim2.new(workingS, -9, 1 - workingV, -9)
            hueCursor.Position = UDim2.new(0, -1, workingH, -7)
            newColorFrame.BackgroundColor3 = newColor
            
            hexInput.Text = "#" .. newColor:ToHex()
            redInput.Text = tostring(math.floor(newColor.r * 255))
            greenInput.Text = tostring(math.floor(newColor.g * 255))
            blueInput.Text = tostring(math.floor(newColor.b * 255))
        end

        -- Mouse interactions
        local satVibDragging = false
        local hueDragging = false

        local satVibConn = satVibMap.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                satVibDragging = true
            end
        end)

        local satVibMoveConn = UserInputService.InputChanged:Connect(function(input)
            if satVibDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mouse = UserInputService:GetMouseLocation()
                local mapPos = satVibMap.AbsolutePosition
                local mapSize = satVibMap.AbsoluteSize
                
                local relX = math.clamp((mouse.X - mapPos.X) / mapSize.X, 0, 1)
                local relY = math.clamp((mouse.Y - mapPos.Y) / mapSize.Y, 0, 1)
                
                workingS = relX
                workingV = 1 - relY
                updateDisplay()
            end
        end)

        local satVibEndConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                satVibDragging = false
            end
        end)

        local hueConn = hueSlider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                hueDragging = true
            end
        end)

        local hueMoveConn = UserInputService.InputChanged:Connect(function(input)
            if hueDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mouse = UserInputService:GetMouseLocation()
                local sliderPos = hueSlider.AbsolutePosition
                local sliderSize = hueSlider.AbsoluteSize
                
                local relY = math.clamp((mouse.Y - sliderPos.Y) / sliderSize.Y, 0, 1)
                workingH = relY
                updateDisplay()
            end
        end)

        local hueEndConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                hueDragging = false
            end
        end)

        -- Buttons
        local buttonContainer = Instance.new("Frame")
        buttonContainer.Size = UDim2.new(0, 200, 0, 32)
        buttonContainer.Position = UDim2.new(0, 20, 0, 280)
        buttonContainer.BackgroundTransparency = 1
        buttonContainer.ZIndex = 10002
        buttonContainer.Parent = dialog

        local buttonLayout = Instance.new("UIListLayout")
        buttonLayout.FillDirection = Enum.FillDirection.Horizontal
        buttonLayout.Padding = UDim.new(0, 8)
        buttonLayout.Parent = buttonContainer

        local cancelBtn = Instance.new("TextButton")
        cancelBtn.Size = UDim2.new(0, 96, 1, 0)
        cancelBtn.BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground
        cancelBtn.TextColor3 = theme.Text
        cancelBtn.Font = Enum.Font.Gotham
        cancelBtn.TextSize = 14
        cancelBtn.Text = "Cancel"
        cancelBtn.ZIndex = 10003
        cancelBtn.Parent = buttonContainer

        local cancelCorner = Instance.new("UICorner")
        cancelCorner.CornerRadius = UDim.new(0, 4)
        cancelCorner.Parent = cancelBtn

        local doneBtn = Instance.new("TextButton")
        doneBtn.Size = UDim2.new(0, 96, 1, 0)
        doneBtn.BackgroundColor3 = theme.Accent
        doneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        doneBtn.Font = Enum.Font.Gotham
        doneBtn.TextSize = 14
        doneBtn.Text = "Done"
        doneBtn.ZIndex = 10003
        doneBtn.Parent = buttonContainer

        local doneCorner = Instance.new("UICorner")
        doneCorner.CornerRadius = UDim.new(0, 4)
        doneCorner.Parent = doneBtn

        -- Button handlers
        local function closeDialog()
            pcall(function() satVibConn:Disconnect() end)
            pcall(function() satVibMoveConn:Disconnect() end)
            pcall(function() satVibEndConn:Disconnect() end)
            pcall(function() hueConn:Disconnect() end)
            pcall(function() hueMoveConn:Disconnect() end)
            pcall(function() hueEndConn:Disconnect() end)
            
            tween(dialogOverlay, {BackgroundTransparency = 1}, {duration = 0.2})
            tween(dialog, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, {duration = 0.2})
            
            task.delay(0.2, function()
                if dialogOverlay then
                    dialogOverlay:Destroy()
                end
            end)
        end

        cancelBtn.MouseButton1Click:Connect(closeDialog)

        doneBtn.MouseButton1Click:Connect(function()
            currentColor = Color3.fromHSV(workingH, workingS, workingV)
            currentH, currentS, currentV = workingH, workingS, workingV
            preview.BackgroundColor3 = currentColor
            
            if callback and type(callback) == "function" then
                safeCallback(callback, currentColor)
            end
            
            closeDialog()
        end)

        -- Close on outside click
        dialogOverlay.MouseButton1Click:Connect(function()
            closeDialog()
        end)

        -- Animate in
        dialog.Size = UDim2.new(0, 0, 0, 0)
        dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
        dialogOverlay.BackgroundTransparency = 1
        
        tween(dialogOverlay, {BackgroundTransparency = 0.5}, {duration = 0.2})
        tween(dialog, {Size = UDim2.new(0, 430, 0, 330), Position = UDim2.new(0.5, -215, 0.5, -165)}, {duration = 0.2})
    end

    -- Button click handler
    local clickConn = button.MouseButton1Click:Connect(function()
        createColorDialog()
    end)
    table.insert(connections, clickConn)

    -- Add hover effects
    debouncedHover(button,
        function()
            tween(button, {BackgroundColor3 = theme.ButtonHover or theme.TabBackground}, {duration = 0.1})
        end,
        function()
            tween(button, {BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground}, {duration = 0.1})
        end
    )

    return {
        Get = function() return currentColor end,
        Set = function(color)
            if typeof(color) == "Color3" then
                currentColor = color
                currentH, currentS, currentV = Color3.toHSV(color)
                preview.BackgroundColor3 = color
                if callback then safeCallback(callback, color) end
            end
        end
    }
end

-- Compatibility aliases
SectionObj.NewColorPicker = SectionObj.NewColorpicker
SectionObj.NewTextBox = SectionObj.NewTextbox
SectionObj.NewKeyBind = SectionObj.NewKeybind

    return SectionObj
        end

        return TabObj
    end

    -- Apply initial theme
    Window:SetTheme(themeName or "LightTheme")

    -- Periodic maintenance: prune orphaned ActiveTweens entries and stale timestamps
    local MAINTENANCE_INTERVAL = 5
    local accumDt = 0
    local maintConn = RunService.Heartbeat:Connect(function(dt)
        accumDt = accumDt + dt
        if accumDt >= MAINTENANCE_INTERVAL then
            accumDt = 0
            -- prune ActiveTweens entries where object no longer exists or no tracked tweens
            for obj, props in pairs(ActiveTweens) do
                if not obj or (type(obj) == "userdata" and not obj.Parent) then
                    ActiveTweens[obj] = nil
                else
                    if type(props) == "table" and next(props) == nil then
                        ActiveTweens[obj] = nil
                    end
                end
            end
            -- prune stale tween timestamps to avoid memory accumulation
            for t,_ in pairs(_tweenTimestamps) do
                if _tweenTimestamps[t] and (tick() - _tweenTimestamps[t]) > 30 then
                    _tweenTimestamps[t] = nil
                end
            end
        end
    end)

    Window._maintConn = maintConn
    -- Setup window control buttons functionality
Window._minimizeBtn = MinimizeBtn
Window._closeBtn = CloseBtn
Window._topbar = Topbar
Window._title = Title

print("[Kour6anHub] Setting up window controls...")

-- Minimize Button Click Handler
local minimizeConn = MinimizeBtn.MouseButton1Click:Connect(function()
    print("[Kour6anHub] Minimize button clicked")
    pcall(function()
        Window:ToggleMinimize()
    end)
end)
globalConnTracker:add(minimizeConn)

-- Close Button Click Handler  
local closeConn = CloseBtn.MouseButton1Click:Connect(function()
    print("[Kour6anHub] Close button clicked")
    -- Animate button press
    local pressTween = tween(CloseBtn, {
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundColor3 = Color3.fromRGB(200, 35, 51)
    }, {duration = 0.08})
    
    if pressTween then
        local conn
        conn = pressTween.Completed:Connect(function()
            pcall(function() conn:Disconnect() end)
            Window:Destroy()
        end)
    else
        task.delay(0.08, function()
            Window:Destroy()
        end)
    end
end)
globalConnTracker:add(closeConn)

-- Hover Effects
debouncedHover(MinimizeBtn,
    function()
        tween(MinimizeBtn, {
            BackgroundColor3 = theme.ButtonHover or theme.TabBackground,
            Size = UDim2.new(0, 32, 0, 32)
        }, {duration = 0.1})
    end,
    function()
        tween(MinimizeBtn, {
            BackgroundColor3 = theme.ButtonBackground or theme.SectionBackground,
            Size = UDim2.new(0, 30, 0, 30)
        }, {duration = 0.1})
    end
)

debouncedHover(CloseBtn,
    function()
        tween(CloseBtn, {
            BackgroundColor3 = Color3.fromRGB(240, 73, 89),
            Size = UDim2.new(0, 32, 0, 32)
        }, {duration = 0.1})
    end,
    function()
        tween(CloseBtn, {
            BackgroundColor3 = Color3.fromRGB(220, 53, 69),
            Size = UDim2.new(0, 30, 0, 30)
        }, {duration = 0.1})
    end
)
   -- Set default toggle key
    Window:SetToggleKey(Enum.KeyCode.RightControl)

    return Window
end

return Kour6anHub
