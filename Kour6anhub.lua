--[[
Kour6anHub.lua
Single-file Roblox UI library with a calm aesthetic.
Author: Kour6an
Version: 1.0.0
--------------------------------------------------------------------------------
NOTES:
- Single-file; no external dependencies.
- Persists to getgenv().Kour6anHubSettings (or shared fallback). Uses writefile/readfile if available.
- All user callbacks are pcall-wrapped.
- Topbar is draggable; default keybind toggles visibility (P).
- Designed to be tolerant to invalid args (defensive).
- Extensive comments below for maintainability.
--------------------------------------------------------------------------------
--]]

-- Module table
local Kour6anHub = {}
Kour6anHub.__index = Kour6anHub
Kour6anHub._VERSION = "1.0.0"

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- Compatibility for exploit environments where CoreGui injection might be required
local allowedParent = CoreGui -- most exploit local scripts can parent to CoreGui

-- Utilities & environment storage
local ENV_SETTINGS_KEY = "Kour6anHubSettings"
getgenv()[ENV_SETTINGS_KEY] = getgenv()[ENV_SETTINGS_KEY] or shared[ENV_SETTINGS_KEY] or {}
local SettingsStore = getgenv()[ENV_SETTINGS_KEY] -- primary in-memory store

-- Optional file persistence if executor provides writefile/readfile
local hasWritefile, hasReadfile, hasIsfile = pcall(function() return writefile ~= nil end)
hasWritefile = hasWritefile and (type(writefile) == "function")
if hasWritefile then
    hasReadfile = (type(readfile) == "function")
    hasIsfile = (type(isfile) == "function")
else
    hasReadfile = false
    hasIsfile = false
end

local function safeWriteFile(path, content)
    if hasWritefile then
        pcall(writefile, path, content)
        return true
    end
    return false
end
local function safeReadFile(path)
    if hasReadfile and hasIsfile and isfile(path) then
        local ok, data = pcall(readfile, path)
        if ok then return data end
    end
    return nil
end

-- Theme defaults
local THEMES = {
    calm = {
        Background = Color3.fromRGB(235, 241, 246), -- very light bluish
        Panel = Color3.fromRGB(245, 248, 250),
        Accent = Color3.fromRGB(98, 155, 170),
        PrimaryText = Color3.fromRGB(30, 38, 43),
        SecondaryText = Color3.fromRGB(110, 123, 131),
        Transparency = 0.08,
    },
    dark = {
        Background = Color3.fromRGB(22, 27, 30),
        Panel = Color3.fromRGB(26, 31, 35),
        Accent = Color3.fromRGB(70, 130, 150),
        PrimaryText = Color3.fromRGB(235,235,235),
        SecondaryText = Color3.fromRGB(160,160,160),
        Transparency = 0.2,
    },
}

-- Helper shorteners
local function new(cls, props)
    local inst = Instance.new(cls)
    if props then
        for k,v in pairs(props) do
            if k == "Parent" then inst.Parent = v else
                pcall(function() inst[k] = v end)
            end
        end
    end
    return inst
end

local function tclone(t) local r = {} for k,v in pairs(t) do r[k]=v end return r end

-- Unique ID generator for elements
local _elementCounter = 0
local function genId(prefix)
    _elementCounter = _elementCounter + 1
    return (prefix or "elem") .. "_" .. tostring(os.time()) .. "_" .. tostring(_elementCounter)
end

-- Tween helper
local function tween(instance, props, info)
    info = info or TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local ok, t = pcall(function() return TweenService:Create(instance, info, props) end)
    if ok and t then
        pcall(function() t:Play() end)
    end
    return t
end

-- PCall wrapper for callbacks
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, ret = pcall(fn, ...)
    if not ok then
        warn("[Kour6anHub] Callback error:", ret)
    end
    return ret
end

-- Validate Color3
local function isColor3(v) return typeof(v) == "Color3" end

-- Persistence helpers
local function getWindowSettingsKey(title)
    return ("window_%s"):format(tostring(title or "Kour6anHub"))
end

local function saveToFile(key, tbl)
    local okData = pcall(function()
        local encoded = HttpService:JSONEncode(tbl or {})
        if hasWritefile then
            safeWriteFile("Kour6anHub_" .. key .. ".json", encoded)
        end
    end)
    return okData
end

local function loadFromFile(key)
    if not hasReadfile then return nil end
    local ok, data = pcall(function()
        local raw = safeReadFile("Kour6anHub_" .. key .. ".json")
        if raw then return HttpService:JSONDecode(raw) end
        return nil
    end)
    if ok then return data end
    return nil
end

-- UI creation helpers (common styles)
local function makeText(labelText, props)
    local t = new("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(labelText or ""),
        Font = Enum.Font.Gotham,
        TextSize = props and props.TextSize or 14,
        TextColor3 = props and props.TextColor3 or Color3.new(1,1,1),
        TextXAlignment = props and props.TextXAlignment or Enum.TextXAlignment.Left,
    })
    return t
end

-- ELEMENT: Generic hover effect
local function applyHover(button)
    button.MouseEnter:Connect(function()
        pcall(function() tween(button, {BackgroundTransparency = math.max(0, (button.BackgroundTransparency or 0) - 0.06)}) end)
    end)
    button.MouseLeave:Connect(function()
        pcall(function() tween(button, {BackgroundTransparency = math.min(1, (button.BackgroundTransparency or 1) + 0.06)}) end)
    end)
end

-- Clean up helper
local function disconnectAll(connections)
    for _,c in ipairs(connections) do
        pcall(function()
            if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
        end)
    end
    table.clear(connections)
end

-- Create main window instance
function Kour6anHub.New(opts)
    -- Defensive defaults
    opts = opts or {}
    local Title = opts.Title or "Kour6anHub"
    local Keybind = (opts.Keybind ~= nil) and opts.Keybind or Enum.KeyCode.P
    local Theme = opts.Theme or "calm"
    if type(Theme) == "string" and THEMES[Theme] then
        Theme = tclone(THEMES[Theme])
    elseif type(Theme) == "table" then
        -- merge
        local merged = tclone(THEMES.calm)
        for k,v in pairs(Theme) do merged[k] = v end
        Theme = merged
    else
        Theme = tclone(THEMES.calm)
    end

    local Window = setmetatable({}, {__index = Kour6anHub})
    Window._title = tostring(Title)
    Window._theme = Theme
    Window._connections = {}
    Window._tabs = {}
    Window._elements = {} -- map id -> element meta
    Window._visible = true
    Window._minimized = false
    Window._position = nil
    Window._keybind = Keybind
    Window._settingsKey = getWindowSettingsKey(Window._title)
    Window._id = genId("window")

    -- ensure settings storage for this window exists
    SettingsStore[Window._settingsKey] = SettingsStore[Window._settingsKey] or {}
    local persisted = SettingsStore[Window._settingsKey]

    -- UI Building
    local screenGui = new("ScreenGui", {Name = "Kour6anHub_" .. Window._id, Parent = allowedParent, ZIndexBehavior = Enum.ZIndexBehavior.Global})
    if syn and syn.protect_gui then pcall(syn.protect_gui, screenGui) end -- exploit compatibility
    Window._screenGui = screenGui

    -- Centering frame
    local main = new("Frame", {
        Name = "MainWindow",
        Parent = screenGui,
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 720, 0, 440),
        BackgroundTransparency = 0,
        BackgroundColor3 = Window._theme.Background,
        BorderSizePixel = 0,
    })
    Window._main = main

    -- Save default position if persisted
    if persisted.windowPosition then
        pcall(function()
            main.AnchorPoint = Vector2.new(0,0)
            main.Position = UDim2.new(0,0,0,0)
            main.Position = UDim2.new(0, persisted.windowPosition[2], 0, persisted.windowPosition[4])
            main.AnchorPoint = Vector2.new(0,0)
        end)
    else
        -- default center
        main.AnchorPoint = Vector2.new(0.5,0.5)
        main.Position = UDim2.new(0.5, 0, 0.5, 0)
    end

    -- subtle white outline (UIStroke) and corner
    new("UICorner", {Parent = main, CornerRadius = UDim.new(0, 10)})
    new("UIStroke", {Parent = main, Color = Color3.fromRGB(245,245,245), Thickness = 1, Transparency = 0.85})

    -- shadow (simple by adding outer frames)
    local shadow = new("Frame", {
        Name = "Shadow",
        Parent = screenGui,
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = main.Position,
        Size = main.Size + UDim2.new(0,24,0,24),
        BackgroundTransparency = 0.8,
        BackgroundColor3 = Color3.new(0,0,0),
        ZIndex = main.ZIndex - 1
    })
    new("UICorner", {Parent = shadow, CornerRadius = UDim.new(0, 12)})
    tween(shadow, {BackgroundTransparency = 0.85}, TweenInfo.new(0.5))

    -- topbar (draggable area)
    local topbar = new("Frame", {
        Name = "Topbar",
        Parent = main,
        BackgroundColor3 = Window._theme.Panel,
        Size = UDim2.new(1,0,0,36),
        Position = UDim2.new(0,0,0,0),
        BorderSizePixel = 0,
    })
    new("UICorner", {Parent = topbar, CornerRadius = UDim.new(0, 8)})
    local titleLabel = new("TextLabel", {
        Parent = topbar,
        Text = Window._title,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Window._theme.PrimaryText,
        BackgroundTransparency = 1,
        Position = UDim2.new(0,12,0,0),
        Size = UDim2.new(0.5, -12, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    local subtitle = new("TextLabel", {
        Parent = topbar,
        Text = ("v%s"):format(Kour6anHub._VERSION),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = Window._theme.SecondaryText,
        BackgroundTransparency = 1,
        Position = UDim2.new(0,12,0,18),
        Size = UDim2.new(0.5, -12, 0.5, -2),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    -- minimize & close
    local rightControls = new("Frame", {
        Parent = topbar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0,92,1,0),
        Position = UDim2.new(1, -98, 0, 0),
    })
    local btnMin = new("TextButton", {
        Parent = rightControls,
        Text = "─",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Window._theme.SecondaryText,
        BackgroundTransparency = 1,
        Size = UDim2.new(0,38,1,0),
        Position = UDim2.new(1, -84, 0, 0),
    })
    local btnClose = new("TextButton", {
        Parent = rightControls,
        Text = "✕",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Window._theme.SecondaryText,
        BackgroundTransparency = 1,
        Size = UDim2.new(0,38,1,0),
        Position = UDim2.new(1, -40, 0, 0),
    })
    applyHover(btnMin); applyHover(btnClose)

    -- Main layout: Sidebar (tabs) and content
    local body = new("Frame", {
        Parent = main,
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,1,-36),
        Position = UDim2.new(0,0,0,36),
    })
    local sidebar = new("Frame", {
        Parent = body,
        BackgroundColor3 = Window._theme.Panel,
        Size = UDim2.new(0,180,1,0),
        Position = UDim2.new(0,0,0,0),
        BorderSizePixel = 0,
    })
    new("UICorner", {Parent = sidebar, CornerRadius = UDim.new(0,8)})
    local contentArea = new("Frame", {
        Parent = body,
        BackgroundColor3 = Window._theme.Background,
        Size = UDim2.new(1,-180,1,0),
        Position = UDim2.new(0,180,0,0),
        BorderSizePixel = 0,
    })
    new("UICorner", {Parent = contentArea, CornerRadius = UDim.new(0,8)})

    local tabList = new("ScrollingFrame", {
        Parent = sidebar,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        ScrollBarThickness = 6,
        CanvasSize = UDim2.new(0,0,0,0),
    })
    local tabLayout = new("UIListLayout", {Parent = tabList, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,8)})
    tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabList.CanvasSize = UDim2.new(0,0,0, tabLayout.AbsoluteContentSize.Y + 8)
    end)

    -- Content holder for tabs' pages (each page is a Frame in contentArea)
    local pagesFolder = new("Folder", {Parent = contentArea, Name = "Pages"})

    -- Minimize behavior
    local function setMinimized(min)
        Window._minimized = not not min
        if Window._minimized then
            -- collapse content
            tween(body, {Size = UDim2.new(1,0,0,0)}, TweenInfo.new(0.18))
            tween(main, {Size = UDim2.new(0, 420, 0, 36)}, TweenInfo.new(0.18))
            -- update persisted
            SettingsStore[Window._settingsKey].minimized = Window._minimized
        else
            tween(main, {Size = UDim2.new(0, 720, 0, 440)}, TweenInfo.new(0.22))
            tween(body, {Size = UDim2.new(1,0,1,-36)}, TweenInfo.new(0.22))
            SettingsStore[Window._settingsKey].minimized = Window._minimized
        end
    end

    local function toggleVisibility()
        Window._visible = not Window._visible
        Window._screenGui.Enabled = Window._visible
        SettingsStore[Window._settingsKey].visible = Window._visible
    end

    -- topbar dragging logic
    do
        local dragging = false
        local dragStart = nil
        local startPos = nil
        local mousePos = nil
        topbar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
                -- ensure anchorpoint is top-left for predictable move
                main.AnchorPoint = Vector2.new(0.5,0.5)
            end
        end)
        topbar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                mousePos = input.Position
            end
        end)
        local conn
        conn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if dragging then
                    dragging = false
                    -- persist position
                    local absPos = main.AbsolutePosition
                    SettingsStore[Window._settingsKey].windowPosition = {absPos.X, absPos.Y, main.AbsoluteSize.X, main.AbsoluteSize.Y}
                end
            end
        end)
        table.insert(Window._connections, conn)
        -- update loop to move main while dragging
        local runConn = RunService.RenderStepped:Connect(function()
            if dragging and dragStart and mousePos then
                local delta = mousePos - dragStart
                local screenSize = workspace.CurrentCamera.ViewportSize
                local newX = (startPos.X.Scale * screenSize.X + startPos.X.Offset + delta.X)
                local newY = (startPos.Y.Scale * screenSize.Y + startPos.Y.Offset + delta.Y)
                main.Position = UDim2.new(0, newX, 0, newY)
                shadow.Position = main.Position
            end
        end)
        table.insert(Window._connections, runConn)
    end

    -- Sidebar tab selection logic
    local activeTab = nil
    local function selectTab(tab)
        if activeTab == tab then return end
        -- hide pages
        for _,t in pairs(Window._tabs) do
            if t._page and t._page:IsA("Frame") then
                t._page.Visible = false
            end
            if t._button and t._button:IsA("TextButton") then
                tween(t._button, {BackgroundTransparency = 0.9}, TweenInfo.new(0.18))
                t._button.TextColor3 = Window._theme.SecondaryText
            end
        end
        activeTab = tab
        if tab._page then tab._page.Visible = true end
        if tab._button then
            tween(tab._button, {BackgroundTransparency = 0.2}, TweenInfo.new(0.18))
            tab._button.TextColor3 = Window._theme.PrimaryText
        end
    end

    -- Create a tab (Kavo-style)
    function Window:CreateTab(name)
        assert(type(name) == "string", "Tab name must be a string")
        local tab = {}
        tab._name = name
        tab._id = genId("tab")
        -- Button in sidebar
        local btn = new("TextButton", {
            Parent = tabList,
            BackgroundColor3 = Window._theme.Panel,
            BackgroundTransparency = 0.9,
            Text = name,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = Window._theme.SecondaryText,
            Size = UDim2.new(1,0,0,32),
            BorderSizePixel = 0,
            AutoButtonColor = false,
        })
        new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,8)})
        applyHover(btn)
        tab._button = btn

        -- Page frame
        local page = new("ScrollingFrame", {
            Parent = pagesFolder,
            Name = name .. "_page_" .. tab._id,
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,1,0),
            CanvasSize = UDim2.new(0,0,0,0),
            ScrollBarThickness = 8,
            Visible = false,
        })
        local pageLayout = new("UIListLayout", {Parent = page, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12)})
        pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0,0,0, pageLayout.AbsoluteContentSize.Y + 18)
        end)
        tab._page = page

        -- Section container creator
        function tab:CreateSection(sectionName)
            local section = {}
            section._name = sectionName or "Section"
            section._id = genId("section")

            local secFrame = new("Frame", {
                Parent = page,
                BackgroundColor3 = Window._theme.Panel,
                Size = UDim2.new(1, -24, 0, 120),
                BorderSizePixel = 0,
                LayoutOrder = #page:GetChildren() + 1,
            })
            new("UICorner", {Parent = secFrame, CornerRadius = UDim.new(0,8)})
            local pad = new("UIPadding", {Parent = secFrame, PaddingTop = UDim.new(0,8), PaddingBottom = UDim.new(0,8), PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10)})
            local header = new("TextLabel", {
                Parent = secFrame,
                BackgroundTransparency = 1,
                Text = section._name,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextColor3 = Window._theme.PrimaryText,
                Size = UDim2.new(1,0,0,20),
                Position = UDim2.new(0,0,0,6),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local contentHolder = new("Frame", {
                Parent = secFrame,
                BackgroundTransparency = 1,
                Position = UDim2.new(0,0,0,28),
                Size = UDim2.new(1,0,1,-28),
            })
            local contentLayout = new("UIListLayout", {Parent = contentHolder, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,6)})
            new("UIPadding", {Parent = contentHolder, PaddingTop = UDim.new(0,6), PaddingLeft = UDim.new(0,6)})

            -- Element factory functions
            function section:CreateLabel(text)
                local labelFrame = new("Frame", {Parent = contentHolder, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,20)})
                local label = new("TextLabel", {
                    Parent = labelFrame,
                    BackgroundTransparency = 1,
                    Text = tostring(text or ""),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Window._theme.SecondaryText,
                    Size = UDim2.new(1,0,1,0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                return {
                    _frame = labelFrame,
                    _label = label
                }
            end

            function section:CreateSeparator()
                local sep = new("Frame", {Parent = contentHolder, BackgroundColor3 = Color3.fromRGB(200,200,200), Size = UDim2.new(1,0,0,1)})
                sep.BackgroundTransparency = 0.85
                return { _frame = sep }
            end

            function section:CreateButton(text, callback)
                text = tostring(text or "Button")
                local id = genId("button")
                local btnFrame = new("Frame", {Parent = contentHolder, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,36)})
                local btn = new("TextButton", {
                    Parent = btnFrame,
                    BackgroundColor3 = Window._theme.Accent,
                    Size = UDim2.new(0, 140, 1, 0),
                    Position = UDim2.new(0,0,0,0),
                    Text = text,
                    Font = Enum.Font.GothamBold,
                    TextSize = 14,
                    TextColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                })
                new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,6)})
                applyHover(btn)
                local conn = btn.MouseButton1Click:Connect(function()
                    safeCall(callback)
                end)
                table.insert(Window._connections, conn)
                Window._elements[id] = {type="button", id=id, meta={text=text, callback=callback}}
                return {
                    _frame = btnFrame,
                    _button = btn,
                    id = id,
                    SetText = function(_, t) btn.Text = tostring(t) end,
                    Destroy = function()
                        pcall(function() btnFrame:Destroy() end)
                        Window._elements[id] = nil
                    end
                }
            end

            function section:CreateToggle(text, default, callback)
                text = tostring(text or "Toggle")
                default = not not default
                local id = genId("toggle")
                local frame = new("Frame", {Parent = contentHolder, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,28)})
                local label = new("TextLabel", {
                    Parent = frame,
                    BackgroundTransparency = 1,
                    Text = text,
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Window._theme.PrimaryText,
                    Size = UDim2.new(1, -60, 1, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                local toggle = new("TextButton", {
                    Parent = frame,
                    BackgroundColor3 = Window._theme.Panel,
                    Size = UDim2.new(0, 48, 1, 0),
                    Position = UDim2.new(1, -54, 0, 0),
                    Text = "",
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                })
                new("UICorner", {Parent = toggle, CornerRadius = UDim.new(0, 6)})
                local knob = new("Frame", {
                    Parent = toggle,
                    BackgroundColor3 = default and Window._theme.Accent or Color3.fromRGB(220,220,220),
                    Size = UDim2.new(0.5, -6, 0.75, 0),
                    Position = default and UDim2.new(0.5, 6, 0.12, 0) or UDim2.new(0, 6, 0.12, 0),
                    BorderSizePixel = 0,
                })
                new("UICorner", {Parent = knob, CornerRadius = UDim.new(0, 6)})
                applyHover(toggle)
                local state = default
                local conn = toggle.MouseButton1Click:Connect(function()
                    state = not state
                    if state then
                        tween(knob, {Position = UDim2.new(0.5, 6, 0.12, 0)}, TweenInfo.new(0.14))
                        tween(knob, {BackgroundColor3 = Window._theme.Accent}, TweenInfo.new(0.14))
                    else
                        tween(knob, {Position = UDim2.new(0, 6, 0.12, 0)}, TweenInfo.new(0.14))
                        tween(knob, {BackgroundColor3 = Color3.fromRGB(220,220,220)}, TweenInfo.new(0.14))
                    end
                    -- persist
                    SettingsStore[Window._settingsKey].elements = SettingsStore[Window._settingsKey].elements or {}
                    SettingsStore[Window._settingsKey].elements[id] = {type="toggle", value=state}
                    safeCall(callback, state)
                end)
                table.insert(Window._connections, conn)
                -- restore persisted
                local persistedVal = SettingsStore[Window._settingsKey].elements and SettingsStore[Window._settingsKey].elements[id]
                if persistedVal and type(persistedVal.value) == "boolean" then
                    state = persistedVal.value
                    if state then
                        knob.Position = UDim2.new(0.5, 6, 0.12, 0)
                        knob.BackgroundColor3 = Window._theme.Accent
                    else
                        knob.Position = UDim2.new(0, 6, 0.12, 0)
                        knob.BackgroundColor3 = Color3.fromRGB(220,220,220)
                    end
                end

                Window._elements[id] = {type="toggle", id=id, meta={text=text, callback=callback}}
                return {
                    id = id,
                    _frame = frame,
                    GetState = function() return state end,
                    SetState = function(_, s)
                        state = not not s
                        SettingsStore[Window._settingsKey].elements = SettingsStore[Window._settingsKey].elements or {}
                        SettingsStore[Window._settingsKey].elements[id] = {type="toggle", value=state}
                        if state then
                            knob.Position = UDim2.new(0.5, 6, 0.12, 0)
                            knob.BackgroundColor3 = Window._theme.Accent
                        else
                            knob.Position = UDim2.new(0, 6, 0.12, 0)
                            knob.BackgroundColor3 = Color3.fromRGB(220,220,220)
                        end
                    end,
                    Destroy = function() pcall(function() frame:Destroy() end) Window._elements[id]=nil end
                }
            end

            function section:CreateSlider(name, min, max, default, callback)
                name = tostring(name or "Slider")
                min = tonumber(min) or 0
                max = tonumber(max) or 100
                default = tonumber(default) or min
                if max < min then max = min end
                local id = genId("slider")
                local frame = new("Frame", {Parent = contentHolder, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,36)})
                local label = new("TextLabel", {
                    Parent = frame,
                    BackgroundTransparency = 1,
                    Text = name,
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Window._theme.PrimaryText,
                    Position = UDim2.new(0,0,0,0),
                    Size = UDim2.new(1, -80, 0.5, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                local valueLabel = new("TextLabel", {
                    Parent = frame,
                    BackgroundTransparency = 1,
                    Text = tostring(default),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Window._theme.SecondaryText,
                    Position = UDim2.new(1, -80, 0, 0),
                    Size = UDim2.new(0, 80, 0.5, 0),
                    TextXAlignment = Enum.TextXAlignment.Right,
                })
                local sliderFrame = new("Frame", {
                    Parent = frame,
                    BackgroundColor3 = Window._theme.Panel,
                    Position = UDim2.new(0,0,0.5,2),
                    Size = UDim2.new(1,0,0,16),
                    BorderSizePixel = 0,
                })
                new("UICorner", {Parent = sliderFrame, CornerRadius = UDim.new(0,8)})
                local knob = new("Frame", {
                    Parent = sliderFrame,
                    BackgroundColor3 = Window._theme.Accent,
                    Size = UDim2.new(0, 24, 1, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    BorderSizePixel = 0,
                })
                new("UICorner", {Parent = knob, CornerRadius = UDim.new(0,8)})
                -- interactive logic
                local dragging = false
                local function setKnobFromValue(val)
                    val = math.clamp(tonumber(val) or min, min, max)
                    local pct = (val - min) / math.max(1, (max - min))
                    knob.Position = UDim2.new(pct, 0, 0, 0)
                    valueLabel.Text = tostring(math.floor(val*100)/100)
                    SettingsStore[Window._settingsKey].elements = SettingsStore[Window._settingsKey].elements or {}
                    SettingsStore[Window._settingsKey].elements[id] = {type="slider", value=val}
                end
                -- restore
                local persistedVal = SettingsStore[Window._settingsKey].elements and SettingsStore[Window._settingsKey].elements[id]
                if persistedVal and type(persistedVal.value) == "number" then
                    default = persistedVal.value
                end
                setKnobFromValue(default)
                local conn1 = sliderFrame.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                    end
                end)
                local conn2 = UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
                local conn3 = RunService.RenderStepped:Connect(function()
                    if dragging then
                        local mouse = UserInputService:GetMouseLocation()
                        local absPos = sliderFrame.AbsolutePosition
                        local absSize = sliderFrame.AbsoluteSize
                        local relative = math.clamp((mouse.X - absPos.X) / math.max(1, absSize.X), 0, 1)
                        local val = min + (max - min) * relative
                        setKnobFromValue(val)
                        safeCall(callback, val)
                    end
                end)
                table.insert(Window._connections, conn1); table.insert(Window._connections, conn2); table.insert(Window._connections, conn3)
                -- click to set
                local conn4 = sliderFrame.MouseButton1Click and sliderFrame.MouseButton1Click:Connect or nil
                -- Call callback initially with default
                safeCall(callback, default)
                Window._elements[id] = {type="slider", id=id, meta={name=name, min=min, max=max, callback=callback}}
                return {
                    id = id,
                    _frame = frame,
                    GetValue = function() return tonumber(valueLabel.Text) end,
                    SetValue = function(_, v) setKnobFromValue(tonumber(v) or min) end,
                    Destroy = function() pcall(function() frame:Destroy() end) Window._elements[id]=nil end
                }
            end

            function section:CreateDropdown(name, options, default, multi, callback)
                name = tostring(name or "Dropdown")
                if type(options) ~= "table" then options = {} end
                local id = genId("dropdown")
                local frame = new("Frame", {Parent = contentHolder, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,30)})
                local label = new("TextLabel", {
                    Parent = frame,
                    BackgroundTransparency = 1,
                    Text = name,
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Window._theme.PrimaryText,
                    Position = UDim2.new(0,0,0,0),
                    Size = UDim2.new(1, -120, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                local display = new("TextButton", {
                    Parent = frame,
                    BackgroundColor3 = Window._theme.Panel,
                    Size = UDim2.new(0, 120, 1, 0),
                    Position = UDim2.new(1, -120, 0, 0),
                    Text = "",
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                })
                new("UICorner", {Parent = display, CornerRadius = UDim.new(0,6)})
                local selectedText = new("TextLabel", {
                    Parent = display,
                    BackgroundTransparency = 1,
                    Text = "",
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Window._theme.SecondaryText,
                    Size = UDim2.new(1, -18, 1, 0),
                    Position = UDim2.new(0,8,0,0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                local arrow = new("TextLabel", {
                    Parent = display,
                    BackgroundTransparency = 1,
                    Text = "▾",
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Window._theme.SecondaryText,
                    Position = UDim2.new(1, -18, 0, 0),
                    Size = UDim2.new(0,18,1,0),
                })
                applyHover(display)
                local listOpen = false
                local listFrame = new("Frame", {
                    Parent = contentHolder,
                    BackgroundColor3 = Window._theme.Panel,
                    Size = UDim2.new(1,0,0,0),
                    Position = UDim2.new(0,0,0,30),
                    Visible = false,
                    BorderSizePixel = 0,
                })
                new("UICorner", {Parent = listFrame, CornerRadius = UDim.new(0,6)})
                local listLayout = new("UIListLayout", {Parent = listFrame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)})
                local searchBox = new("TextBox", {
                    Parent = listFrame,
                    BackgroundTransparency = 0.95,
                    Text = "",
                    PlaceholderText = "Search...",
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Window._theme.PrimaryText,
                    Size = UDim2.new(1,0,0,28),
                    BorderSizePixel = 0,
                })

                -- local selected state
                local selected = {}
                if multi then
                    if type(default) == "table" then
                        for _,v in ipairs(default) do selected[v] = true end
                    elseif default ~= nil then selected[tostring(default)] = true end
                else
                    if default ~= nil then selected[ tostring(default) ] = true end
                end

                local itemButtons = {}
                local function refreshSelectedText()
                    if multi then
                        local list = {}
                        for k,_ in pairs(selected) do table.insert(list, k) end
                        selectedText.Text = "[" .. tostring(#list) .. "]"
                        if #list > 0 then selectedText.Text = table.concat(list, ", ") end
                    else
                        local list = {}
                        for k,_ in pairs(selected) do table.insert(list, k) end
                        selectedText.Text = list[1] or "None"
                    end
                end

                local function buildList(filter)
                    -- clear previous items (except searchBox)
                    for _,v in ipairs(itemButtons) do
                        pcall(function() v:Destroy() end)
                    end
                    itemButtons = {}
                    local count = 0
                    for _,opt in ipairs(options) do
                        local s = tostring(opt)
                        if filter == nil or filter == "" or s:lower():find(filter:lower()) then
                            count = count + 1
                            local item = new("TextButton", {
                                Parent = listFrame,
                                BackgroundTransparency = 1,
                                Text = "",
                                Size = UDim2.new(1,0,0,28),
                                AutoButtonColor = false,
                            })
                            local lbl = new("TextLabel", {
                                Parent = item,
                                BackgroundTransparency = 1,
                                Text = s,
                                Font = Enum.Font.Gotham,
                                TextSize = 13,
                                TextColor3 = Window._theme.PrimaryText,
                                Size = UDim2.new(1, -30, 1, 0),
                                Position = UDim2.new(0,6,0,0),
                                TextXAlignment = Enum.TextXAlignment.Left,
                            })
                            local chk = new("TextLabel", {
                                Parent = item,
                                BackgroundTransparency = 1,
                                Text = selected[s] and "✓" or "",
                                Font = Enum.Font.GothamBold,
                                TextSize = 14,
                                TextColor3 = Window._theme.Accent,
                                Position = UDim2.new(1, -24,0,0),
                                Size = UDim2.new(0,20,1,0),
                            })
                            item.InputBegan:Connect(function(inp)
                                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                                    if multi then
                                        selected[s] = not not (not selected[s])
                                    else
                                        selected = {}
                                        selected[s] = true
                                    end
                                    -- update checks
                                    chk.Text = selected[s] and "✓" or ""
                                    for _,btn in ipairs(itemButtons) do
                                        local lblChild = btn:FindFirstChildOfClass("TextLabel")
                                        if btn ~= item and not multi then
                                            local children = btn:GetChildren()
                                            for _,c in ipairs(children) do
                                                if c:IsA("TextLabel") and c ~= lblChild then
                                                    -- try find check
                                                    pcall(function() c.Text = "" end)
                                                end
                                            end
                                        end
                                    end
                                    refreshSelectedText()
                                    -- persist
                                    local storeVal
                                    if multi then
                                        local t = {}
                                        for k,_ in pairs(selected) do table.insert(t, k) end
                                        storeVal = t
                                    else
                                        local single = nil
                                        for k,_ in pairs(selected) do single = k break end
                                        storeVal = single
                                    end
                                    SettingsStore[Window._settingsKey].elements = SettingsStore[Window._settingsKey].elements or {}
                                    SettingsStore[Window._settingsKey].elements[id] = {type="dropdown", multi=multi, value=storeVal}
                                    safeCall(callback, (multi and (function()
                                        local t = {}
                                        for k,_ in pairs(selected) do table.insert(t, k) end
                                        return t
                                    end)() or (function()
                                        for k,_ in pairs(selected) do return k end
                                    end)()))
                                    -- keep list open if multi, close if single
                                    if not multi then
                                        listFrame.Visible = false
                                        listOpen = false
                                    end
                                end
                            end)
                            table.insert(itemButtons, item)
                        end
                    end
                    -- set list frame size
                    local h = math.clamp(#itemButtons * 32 + 38, 0, 200)
                    listFrame.Size = UDim2.new(1,0,0,h)
                end

                searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                    buildList(searchBox.Text)
                end)

                display.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        listOpen = not listOpen
                        listFrame.Visible = listOpen
                        if listOpen then
                            buildList("")
                        end
                    end
                end)

                -- restore persisted
                local persistedVal = SettingsStore[Window._settingsKey].elements and SettingsStore[Window._settingsKey].elements[id]
                if persistedVal then
                    if persistedVal.multi and type(persistedVal.value) == "table" then
                        selected = {}
                        for _,v in ipairs(persistedVal.value) do selected[v] = true end
                    else
                        selected = {}
                        if persistedVal.value then selected[tostring(persistedVal.value)] = true end
                    end
                end
                refreshSelectedText()

                Window._elements[id] = {type="dropdown", id=id, meta={name=name, options=options, multi=multi, callback=callback}}
                return {
                    id = id,
                    _frame = frame,
                    GetValue = function()
                        if multi then
                            local t = {}
                            for k,_ in pairs(selected) do table.insert(t, k) end
                            return t
                        else
                            for k,_ in pairs(selected) do return k end
                            return nil
                        end
                    end,
                    SetValue = function(_, v)
                        if multi and type(v) == "table" then
                            selected = {}
                            for _,vv in ipairs(v) do selected[tostring(vv)] = true end
                        else
                            selected = {}
                            if v ~= nil then selected[tostring(v)] = true end
                        end
                        refreshSelectedText()
                    end,
                    Destroy = function() pcall(function() frame:Destroy() end) Window._elements[id]=nil end
                }
            end

            function section:CreateTextbox(label, placeholder, callback)
                label = tostring(label or "Textbox")
                local id = genId("textbox")
                local frame = new("Frame", {Parent = contentHolder, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,36)})
                new("TextLabel", {
                    Parent = frame,
                    BackgroundTransparency = 1,
                    Text = label,
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Window._theme.PrimaryText,
                    Position = UDim2.new(0,0,0,0),
                    Size = UDim2.new(1, -10, 0.5, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                local box = new("TextBox", {
                    Parent = frame,
                    BackgroundColor3 = Window._theme.Panel,
                    Position = UDim2.new(0,0,0.5,2),
                    Size = UDim2.new(1,0,0,20),
                    Text = "",
                    PlaceholderText = tostring(placeholder or ""),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Window._theme.PrimaryText,
                    BorderSizePixel = 0,
                })
                new("UICorner", {Parent = box, CornerRadius = UDim.new(0,6)})
                local conn = box.FocusLost:Connect(function(enter)
                    if enter then safeCall(callback, box.Text) end
                    -- persist
                    SettingsStore[Window._settingsKey].elements = SettingsStore[Window._settingsKey].elements or {}
                    SettingsStore[Window._settingsKey].elements[id] = {type="textbox", value=box.Text}
                end)
                table.insert(Window._connections, conn)
                -- restore
                local persistedVal = SettingsStore[Window._settingsKey].elements and SettingsStore[Window._settingsKey].elements[id]
                if persistedVal and type(persistedVal.value) == "string" then
                    box.Text = persistedVal.value
                end
                Window._elements[id] = {type="textbox", id=id, meta={label=label, callback=callback}}
                return {
                    id = id,
                    _frame = frame,
                    GetText = function() return box.Text end,
                    SetText = function(_, t) box.Text = tostring(t) end,
                    Destroy = function() pcall(function() frame:Destroy() end) Window._elements[id]=nil end
                }
            end

            function section:CreateKeybind(name, defaultKey, callback)
                name = tostring(name or "Keybind")
                local id = genId("keybind")
                local frame = new("Frame", {Parent = contentHolder, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,28)})
                local label = new("TextLabel", {
                    Parent = frame,
                    BackgroundTransparency = 1,
                    Text = name,
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Window._theme.PrimaryText,
                    Position = UDim2.new(0,0,0,0),
                    Size = UDim2.new(1, -100, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                local kbButton = new("TextButton", {
                    Parent = frame,
                    BackgroundColor3 = Window._theme.Panel,
                    Size = UDim2.new(0, 96, 1, 0),
                    Position = UDim2.new(1, -96, 0, 0),
                    Text = tostring((defaultKey and defaultKey.Name) or "None"),
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Window._theme.SecondaryText,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                })
                new("UICorner", {Parent = kbButton, CornerRadius = UDim.new(0,6)})
                applyHover(kbButton)

                local listening = false
                local boundKey = defaultKey and defaultKey or nil

                -- restore
                local persistedVal = SettingsStore[Window._settingsKey].elements and SettingsStore[Window._settingsKey].elements[id]
                if persistedVal and persistedVal.value then
                    pcall(function() boundKey = Enum.KeyCode[persistedVal.value] end)
                end
                if boundKey then kbButton.Text = boundKey.Name end

                local listenConn
                local function startListening()
                    listening = true
                    kbButton.Text = "Press any key..."
                    listenConn = UserInputService.InputBegan:Connect(function(inp, gpe)
                        if gpe then return end
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            boundKey = inp.KeyCode
                            kbButton.Text = boundKey.Name
                            -- persist
                            SettingsStore[Window._settingsKey].elements = SettingsStore[Window._settingsKey].elements or {}
                            SettingsStore[Window._settingsKey].elements[id] = {type="keybind", value=boundKey.Name}
                            safeCall(callback, boundKey)
                            listening = false
                            if listenConn then listenConn:Disconnect() end
                        end
                    end)
                end

                kbButton.MouseButton1Click:Connect(function()
                    if not listening then
                        startListening()
                    end
                end)
                -- global input to trigger callback
                local masterConn = UserInputService.InputBegan:Connect(function(inp, gpe)
                    if gpe then return end
                    if inp.UserInputType == Enum.UserInputType.Keyboard and boundKey and inp.KeyCode == boundKey then
                        safeCall(callback, boundKey)
                    end
                end)
                table.insert(Window._connections, masterConn)

                Window._elements[id] = {type="keybind", id=id, meta={name=name, callback=callback, boundKey=boundKey}}
                return {
                    id = id,
                    _frame = frame,
                    GetKey = function() return boundKey end,
                    SetKey = function(_, k)
                        boundKey = k
                        kbButton.Text = boundKey and boundKey.Name or "None"
                        SettingsStore[Window._settingsKey].elements = SettingsStore[Window._settingsKey].elements or {}
                        SettingsStore[Window._settingsKey].elements[id] = {type="keybind", value=boundKey and boundKey.Name or nil}
                    end,
                    Destroy = function() pcall(function() frame:Destroy() end) Window._elements[id]=nil end
                }
            end

            function section:CreateColorPicker(name, default, callback)
                name = tostring(name or "Color")
                local id = genId("color")
                local frame = new("Frame", {Parent = contentHolder, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,36)})
                local label = new("TextLabel", {
                    Parent = frame,
                    BackgroundTransparency = 1,
                    Text = name,
                    Font = Enum.Font.Gotham,
                    TextSize = 13,
                    TextColor3 = Window._theme.PrimaryText,
                    Position = UDim2.new(0,0,0,0),
                    Size = UDim2.new(1, -120, 0.5, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                local colorPreview = new("Frame", {
                    Parent = frame,
                    BackgroundColor3 = (isColor3(default) and default) or Color3.fromRGB(100,150,200),
                    Size = UDim2.new(0, 36, 1, 0),
                    Position = UDim2.new(1, -42, 0, 0),
                    BorderSizePixel = 0,
                })
                new("UICorner", {Parent = colorPreview, CornerRadius = UDim.new(0,6)})
                local openBtn = new("TextButton", {
                    Parent = frame,
                    BackgroundColor3 = Window._theme.Panel,
                    Size = UDim2.new(0, 76, 1, 0),
                    Position = UDim2.new(1, -120, 0, 0),
                    Text = "Pick",
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = Window._theme.SecondaryText,
                    BorderSizePixel = 0,
                })
                new("UICorner", {Parent = openBtn, CornerRadius = UDim.new(0,6)})
                applyHover(openBtn)
                -- color picker panel (simple RGB sliders)
                local picker = new("Frame", {
                    Parent = contentHolder,
                    BackgroundColor3 = Window._theme.Panel,
                    Size = UDim2.new(1,0,0,150),
                    Position = UDim2.new(0,0,0,36),
                    Visible = false,
                    BorderSizePixel = 0,
                })
                new("UICorner", {Parent = picker, CornerRadius = UDim.new(0,6)})
                local sliderR = new("Frame", {Parent = picker, BackgroundColor3 = Window._theme.Panel, Size = UDim2.new(1,-24,0,20), Position = UDim2.new(0,12,0,8)})
                local rBox = new("TextBox", {Parent = sliderR, BackgroundTransparency = 1, Text = "R", Position = UDim2.new(0,6,0,0), Size = UDim2.new(0,48,1,0), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Window._theme.PrimaryText})
                local rSlider = new("Frame", {Parent = sliderR, BackgroundColor3 = Color3.fromRGB(200,0,0), Position = UDim2.new(0,64/300,0,3), Size = UDim2.new(0, 100, 1, -6)})
                local sliderG = new("Frame", {Parent = picker, BackgroundColor3 = Window._theme.Panel, Size = UDim2.new(1,-24,0,20), Position = UDim2.new(0,12,0,36)})
                local gBox = new("TextBox", {Parent = sliderG, BackgroundTransparency = 1, Text = "G", Position = UDim2.new(0,6,0,0), Size = UDim2.new(0,48,1,0), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Window._theme.PrimaryText})
                local gSlider = new("Frame", {Parent = sliderG, BackgroundColor3 = Color3.fromRGB(0,200,0), Position = UDim2.new(0,64/300,0,3), Size = UDim2.new(0, 100, 1, -6)})
                local sliderB = new("Frame", {Parent = picker, BackgroundColor3 = Window._theme.Panel, Size = UDim2.new(1,-24,0,20), Position = UDim2.new(0,12,0,64)})
                local bBox = new("TextBox", {Parent = sliderB, BackgroundTransparency = 1, Text = "B", Position = UDim2.new(0,6,0,0), Size = UDim2.new(0,48,1,0), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Window._theme.PrimaryText})
                local bSlider = new("Frame", {Parent = sliderB, BackgroundColor3 = Color3.fromRGB(0,0,200), Position = UDim2.new(0,64/300,0,3), Size = UDim2.new(0, 100, 1, -6)})
                local applyBtn = new("TextButton", {Parent = picker, BackgroundColor3 = Window._theme.Accent, Size = UDim2.new(0,96,0,28), Position = UDim2.new(1,-108,0,108), Text = "Apply", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1,1,1), BorderSizePixel = 0})
                new("UICorner", {Parent = applyBtn, CornerRadius = UDim.new(0,6)})

                -- small helpers: the sliders here are purely illustrative; clicking 'Apply' returns chosen color
                local currentColor = colorPreview.BackgroundColor3
                applyBtn.MouseButton1Click:Connect(function()
                    -- gather color from sliders' positions (use X position ratio)
                    local r = math.clamp(math.floor((rSlider.Position.X.Offset / 300) * 255), 0, 255)
                    local g = math.clamp(math.floor((gSlider.Position.X.Offset / 300) * 255), 0, 255)
                    local b = math.clamp(math.floor((bSlider.Position.X.Offset / 300) * 255), 0, 255)
                    currentColor = Color3.fromRGB(r,g,b)
                    colorPreview.BackgroundColor3 = currentColor
                    SettingsStore[Window._settingsKey].elements = SettingsStore[Window._settingsKey].elements or {}
                    SettingsStore[Window._settingsKey].elements[id] = {type="color", value={r,g,b}}
                    safeCall(callback, currentColor)
                    picker.Visible = false
                end)
                openBtn.MouseButton1Click:Connect(function()
                    picker.Visible = not picker.Visible
                end)
                -- restore persisted
                local persistedVal = SettingsStore[Window._settingsKey].elements and SettingsStore[Window._settingsKey].elements[id]
                if persistedVal and type(persistedVal.value) == "table" then
                    local r,g,b = unpack(persistedVal.value)
                    if r and g and b then colorPreview.BackgroundColor3 = Color3.fromRGB(r,g,b) end
                end

                Window._elements[id] = {type="color", id=id, meta={name=name, callback=callback}}
                return {
                    id = id,
                    _frame = frame,
                    GetColor = function() return colorPreview.BackgroundColor3 end,
                    SetColor = function(_, c) if isColor3(c) then colorPreview.BackgroundColor3 = c end end,
                    Destroy = function() pcall(function() frame:Destroy() end) Window._elements[id]=nil end
                }
            end

            -- return created section
            section._frame = secFrame
            section._content = contentHolder
            return section
        end

        -- hook button
        btn.MouseButton1Click:Connect(function()
            selectTab(tab)
        end)

        table.insert(Window._tabs, tab)
        -- if it's the first tab, select it
        if #Window._tabs == 1 then
            selectTab(tab)
        end

        return tab
    end

    -- Window methods
    function Window:Destroy()
        -- save settings before destruction
        pcall(function() self:SaveSettings() end)
        -- disconnect connections
        disconnectAll(self._connections)
        -- destroy gui
        pcall(function() if self._screenGui and self._screenGui.Parent then self._screenGui:Destroy() end end)
        -- clear tables
        table.clear(self._elements)
        table.clear(self._tabs)
    end

    function Window:SaveSettings()
        --
        SettingsStore[Window._settingsKey].minimized = Window._minimized
        SettingsStore[Window._settingsKey].visible = Window._visible
        -- attempt file write too
        pcall(function()
            local ok, _ = pcall(function()
                local copy = SettingsStore[Window._settingsKey]
                -- file key based on title
                if hasWritefile then
                    safeWriteFile("Kour6anHub_"..Window._title..".json", HttpService:JSONEncode(copy))
                end
            end)
        end)
    end

    function Window:LoadSettings()
        local s = SettingsStore[Window._settingsKey] or {}
        -- apply minimized/visible
        if s.minimized then setMinimized(s.minimized) end
        if s.visible == false then self._screenGui.Enabled = false else self._screenGui.Enabled = true end
        -- restore element states
        -- elements persistence is already used at creation time
    end

    function Window:ExportSettings()
        return tclone(SettingsStore[Window._settingsKey] or {})
    end

    function Window:ImportSettings(tbl)
        if type(tbl) ~= "table" then return false end
        SettingsStore[Window._settingsKey] = tclone(tbl)
        return true
    end

    function Window:SetTheme(t)
        if type(t) ~= "table" then return end
        for k,v in pairs(t) do Window._theme[k] = v end
        -- apply theme changes visually
        main.BackgroundColor3 = Window._theme.Background
        sidebar.BackgroundColor3 = Window._theme.Panel
        contentArea.BackgroundColor3 = Window._theme.Background
        topbar.BackgroundColor3 = Window._theme.Panel
        titleLabel.TextColor3 = Window._theme.PrimaryText
        subtitle.TextColor3 = Window._theme.SecondaryText
    end

    -- toggle keybind to show/hide GUI
    local toggleConnection = UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if Window._keybind and inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Window._keybind then
            toggleVisibility()
        end
    end)
    table.insert(Window._connections, toggleConnection)

    -- button behaviors
    btnMin.MouseButton1Click:Connect(function()
        setMinimized(not Window._minimized)
    end)
    btnClose.MouseButton1Click:Connect(function()
        pcall(function() self:SaveSettings() end)
        pcall(function() Window:Destroy() end)
    end)

    -- initial load settings
    pcall(function() Window:LoadSettings() end)

    -- store and return window instance
    return Window
end

-- Convenience immediate-run: create a default GUI when this file is executed
-- This ensures casual users get a GUI by just executing the script.
pcall(function()
    -- create default window only if not already present in getgenv (avoid duplicates)
    if not getgenv().__Kour6anHubDefaultCreated then
        getgenv().__Kour6anHubDefaultCreated = true
        local ok, win = pcall(function()
            return Kour6anHub.New({Title = "Kour6anHub", Keybind = Enum.KeyCode.P, Theme = "calm"})
        end)
        if not ok then
            -- ignore construction errors; don't break return
        end
    end
end)

-- Return module table (also used when assigned to a variable)
return Kour6anHub
