-- Kour6anHub UI Library (Kavo-compatible API)
-- v5 — Full parity & polish: ToggleUI, Update methods, themes (Light, Dark, Blood, Midnight, Synapse, Sentinel),
-- sliders with step & value display, colorpicker presets + hex, dropdown keyboard nav, persistence, minimize/close, events, richtext labels

local Kour6anHub = {}
Kour6anHub.__index = Kour6anHub

-- Services
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- Helper: safe pcall writefile/readfile
local hasWriteFile = (type(writefile) == "function")
local function safeWriteFile(name, content)
    if hasWriteFile then
        pcall(writefile, name, content)
        return true
    else
        return false, "writefile not available"
    end
end
local function safeReadFile(name)
    if hasWriteFile then
        local ok, res = pcall(readfile, name)
        if ok then return true, res end
        return false, res
    else
        return false, "readfile not available"
    end
end

-- Helper: small event object
local function MakeEvent()
    local listeners = {}
    return {
        Connect = function(self, fn)
            local id = {}
            listeners[id] = fn
            return {
                Disconnect = function()
                    listeners[id] = nil
                end
            }
        end,
        Fire = function(self, ...)
            for _, fn in pairs(listeners) do
                pcall(fn, ...)
            end
        end,
        DisconnectAll = function()
            listeners = {}
        end
    }
end

-- Tween helper
local function tween(obj, props, dur)
    local ti = TweenInfo.new(dur or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, ti, props)
    t:Play()
    return t
end

-- Utility: Dragging
local function makeDraggable(frame, dragHandle)
    local dragging, dragStart, startPos
    dragHandle = dragHandle or frame

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Built-in themes (Light, Dark, Blood, Midnight, Synapse, Sentinel)
local BuiltinThemes = {
    ["LightTheme"] = {
        Background = Color3.fromRGB(245,245,245),
        TabBackground = Color3.fromRGB(235,235,235),
        SectionBackground = Color3.fromRGB(250,250,250),
        Text = Color3.fromRGB(40,40,40),
        SubText = Color3.fromRGB(70,70,70),
        Accent = Color3.fromRGB(0,120,255)
    },
    ["DarkTheme"] = {
        Background = Color3.fromRGB(40,40,40),
        TabBackground = Color3.fromRGB(30,30,30),
        SectionBackground = Color3.fromRGB(55,55,55),
        Text = Color3.fromRGB(230,230,230),
        SubText = Color3.fromRGB(180,180,180),
        Accent = Color3.fromRGB(0,120,255)
    },
    ["Blood"] = {
        Background = Color3.fromRGB(25,6,6),
        TabBackground = Color3.fromRGB(45,10,10),
        SectionBackground = Color3.fromRGB(60,12,12),
        Text = Color3.fromRGB(245,200,200),
        SubText = Color3.fromRGB(200,120,120),
        Accent = Color3.fromRGB(200,25,25)
    },
    ["Midnight"] = {
        Background = Color3.fromRGB(10,12,20),
        TabBackground = Color3.fromRGB(18,20,30),
        SectionBackground = Color3.fromRGB(22,24,36),
        Text = Color3.fromRGB(235,235,245),
        SubText = Color3.fromRGB(150,150,170),
        Accent = Color3.fromRGB(120,90,255)
    },
    ["Synapse"] = {
        Background = Color3.fromRGB(18,22,30),
        TabBackground = Color3.fromRGB(24,28,36),
        SectionBackground = Color3.fromRGB(30,34,42),
        Text = Color3.fromRGB(240,240,250),
        SubText = Color3.fromRGB(170,180,195),
        Accent = Color3.fromRGB(0,170,255)
    },
    ["Sentinel"] = {
        Background = Color3.fromRGB(8,20,12),
        TabBackground = Color3.fromRGB(14,34,20),
        SectionBackground = Color3.fromRGB(18,44,24),
        Text = Color3.fromRGB(230,245,230),
        SubText = Color3.fromRGB(140,180,150),
        Accent = Color3.fromRGB(80,200,120)
    }
}

-- Create window
-- signature: CreateLib(title, themeNameOrTable, optionalCustomTable)
-- If themeNameOrTable is a table, it will be merged into a base theme (LightTheme default)
function Kour6anHub.CreateLib(title, themeArg, customColors)
    local theme = BuiltinThemes["LightTheme"]
    local themeName = "LightTheme"

    -- determine input:
    if type(themeArg) == "string" and BuiltinThemes[themeArg] then
        theme = BuiltinThemes[themeArg]
        themeName = themeArg
    elseif type(themeArg) == "table" then
        -- merge into LightTheme as base
        theme = {}
        for k,v in pairs(BuiltinThemes["LightTheme"]) do theme[k] = v end
        for k,v in pairs(themeArg) do theme[k] = v end
        themeName = "Custom"
    end
    if type(customColors) == "table" then
        for k,v in pairs(customColors) do theme[k] = v end
    end

    -- ScreenGui (replace if exists)
    local ScreenGui = CoreGui:FindFirstChild("Kour6anHub")
    if ScreenGui then ScreenGui:Destroy() end
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Kour6anHub"
    ScreenGui.Parent = CoreGui

    -- store state
    local state = {
        theme = theme,
        themeName = themeName,
        collapsed = false,
        visible = true
    }

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

    -- Topbar
    local Topbar = Instance.new("Frame")
    Topbar.Size = UDim2.new(1, 0, 0, 40)
    Topbar.BackgroundColor3 = theme.SectionBackground
    Topbar.Parent = Main

    local TopbarCorner = Instance.new("UICorner")
    TopbarCorner.CornerRadius = UDim.new(0, 8)
    TopbarCorner.Parent = Topbar

    local Title = Instance.new("TextLabel")
    Title.Text = title or "Kour6anHub"
    Title.Size = UDim2.new(1, -120, 1, 0) -- leave room for minimize/close
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = theme.Text
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.Parent = Topbar

    -- Minimize & Close buttons
    local ControlsHolder = Instance.new("Frame")
    ControlsHolder.Size = UDim2.new(0, 110, 1, 0)
    ControlsHolder.Position = UDim2.new(1, -110, 0, 0)
    ControlsHolder.BackgroundTransparency = 1
    ControlsHolder.Parent = Topbar

    local function makeTopButton(text, pos)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 50, 0, 24)
        b.Position = UDim2.new(0, pos, 0, 8)
        b.Text = text
        b.Parent = ControlsHolder
        b.AutoButtonColor = false
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.BackgroundColor3 = theme.TabBackground
        local c = Instance.new("UICorner", b)
        c.CornerRadius = UDim.new(0,6)
        return b
    end

    local MinimizeBtn = makeTopButton("_", 0)
    local CloseBtn = makeTopButton("X", 0.55)

    -- Minimize behavior: collapse to topbar
    MinimizeBtn.MouseButton1Click:Connect(function()
        if state.collapsed then
            -- restore
            Main.Size = UDim2.new(0, 600, 0, 400)
            state.collapsed = false
        else
            Main.Size = UDim2.new(0, 600, 0, 40)
            state.collapsed = true
        end
    end)

    -- Close behavior: destroy GUI
    CloseBtn.MouseButton1Click:Connect(function()
        if ScreenGui and ScreenGui.Parent then
            ScreenGui:Destroy()
        end
    end)

    makeDraggable(Main, Topbar)

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
    Window._currentOpenDropdown = nil -- global dropdown pointer
    Window._theme = theme
    Window._settingsFolder = "Kour6anHub_Settings"

    -- Toggle UI convenience
    function Window:ToggleUI()
        state.visible = not state.visible
        ScreenGui.Enabled = state.visible
        return state.visible
    end

    -- Save / Load settings (serializes table to JSON)
    function Window:SaveSettings(filename, tbl)
        filename = tostring(filename or "settings") .. ".json"
        local ok, data = pcall(function() return HttpService:JSONEncode(tbl) end)
        if not ok then return false, data end
        if hasWriteFile then
            local succ, err = pcall(function() writefile(filename, data) end)
            if succ then return true end
            return false, err
        else
            -- fallback: return serialized string for user to store elsewhere
            return false, "writefile unavailable; returned string", data
        end
    end
    function Window:LoadSettings(filename)
        filename = tostring(filename or "settings") .. ".json"
        if hasWriteFile then
            local succ, content = pcall(function() return readfile(filename) end)
            if not succ then return false, content end
            local ok, tbl = pcall(function() return HttpService:JSONDecode(content) end)
            if not ok then return false, tbl end
            return true, tbl
        else
            return false, "readfile not available"
        end
    end

    -- runtime theme switcher: accepts builtin name or table
    function Window:SetTheme(newTheme)
        local nt = nil
        if type(newTheme) == "string" and BuiltinThemes[newTheme] then
            nt = BuiltinThemes[newTheme]
            Window._theme = nt
            Window._themeName = newTheme
        elseif type(newTheme) == "table" then
            -- merge with current
            nt = {}
            for k,v in pairs(Window._theme or {}) do nt[k] = v end
            for k,v in pairs(newTheme) do nt[k] = v end
            Window._theme = nt
            Window._themeName = "Custom"
        else
            return
        end
        local theme = Window._theme

        -- basic elements
        Main.BackgroundColor3 = theme.Background
        Topbar.BackgroundColor3 = theme.SectionBackground
        Title.TextColor3 = theme.Text
        TabContainer.BackgroundColor3 = theme.TabBackground
        MinimizeBtn.BackgroundColor3 = theme.TabBackground
        CloseBtn.BackgroundColor3 = theme.TabBackground

        -- update all tabs and controls
        for _, entry in ipairs(Tabs) do
            local btn = entry.Button
            local frame = entry.Frame
            local active = btn:GetAttribute("active")
            btn.BackgroundColor3 = active and theme.Accent or theme.SectionBackground
            btn.TextColor3 = active and Color3.fromRGB(255,255,255) or theme.Text

            -- update children
            for _, child in ipairs(frame:GetDescendants()) do
                if child:IsA("Frame") and child.Name == "_section" then
                    child.BackgroundColor3 = theme.SectionBackground
                elseif child:IsA("TextLabel") then
                    -- Section label uses SubText; other labels use Text
                    if child:GetAttribute("isSectionTitle") then
                        child.TextColor3 = theme.SubText
                    else
                        child.TextColor3 = theme.Text
                    end
                elseif child:IsA("TextButton") then
                    -- respect toggle state attribute
                    if child:GetAttribute("_isToggleState") then
                        local tog = child:GetAttribute("_toggle")
                        child.BackgroundColor3 = tog and theme.Accent or theme.SectionBackground
                        child.TextColor3 = tog and Color3.fromRGB(255,255,255) or theme.Text
                    else
                        -- normal buttons use section background
                        child.BackgroundColor3 = theme.SectionBackground
                        child.TextColor3 = theme.Text
                    end
                elseif child:IsA("TextBox") then
                    child.BackgroundColor3 = theme.SectionBackground
                    child.TextColor3 = theme.Text
                end
            end
        end
    end

    -- NewTab
    function Window:NewTab(tabName)
        -- Tab Button
        local TabButton = Instance.new("TextButton")
        TabButton.Text = tabName
        TabButton.Size = UDim2.new(1, -20, 0, 40)
        TabButton.BackgroundColor3 = Window._theme.SectionBackground
        TabButton.TextColor3 = Window._theme.Text
        TabButton.Font = Enum.Font.Gotham
        TabButton.TextSize = 14
        TabButton.AutoButtonColor = false
        TabButton.Parent = TabContainer

        local TabButtonCorner = Instance.new("UICorner", TabButton)
        TabButtonCorner.CornerRadius = UDim.new(0, 6)

        local TabButtonPadding = Instance.new("UIPadding", TabButton)
        TabButtonPadding.PaddingTop = UDim.new(0, 8)
        TabButtonPadding.PaddingBottom = UDim.new(0, 8)
        TabButtonPadding.PaddingLeft = UDim.new(0, 10)
        TabButtonPadding.PaddingRight = UDim.new(0, 10)

        TabButton.MouseEnter:Connect(function()
            tween(TabButton, {BackgroundColor3 = Window._theme.TabBackground, Size = UDim2.new(1, -16, 0, 42)}, 0.1)
        end)
        TabButton.MouseLeave:Connect(function()
            if TabButton:GetAttribute("active") then
                tween(TabButton, {BackgroundColor3 = Window._theme.Accent, Size = UDim2.new(1, -20, 0, 40)}, 0.1)
            else
                tween(TabButton, {BackgroundColor3 = Window._theme.SectionBackground, Size = UDim2.new(1, -20, 0, 40)}, 0.1)
            end
        end)

        -- Tab frame (scroll)
        local TabFrame = Instance.new("ScrollingFrame")
        TabFrame.Size = UDim2.new(1,0,1,0)
        TabFrame.CanvasSize = UDim2.new(0,0,0,0)
        TabFrame.ScrollBarThickness = 6
        TabFrame.BackgroundTransparency = 1
        TabFrame.Visible = false
        TabFrame.Parent = Content

        local TabLayout = Instance.new("UIListLayout", TabFrame)
        TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        TabLayout.Padding = UDim.new(0, 10)

        local TabFramePadding = Instance.new("UIPadding", TabFrame)
        TabFramePadding.PaddingTop = UDim.new(0,8)
        TabFramePadding.PaddingLeft = UDim.new(0,8)
        TabFramePadding.PaddingRight = UDim.new(0,8)

        TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local s = TabLayout.AbsoluteContentSize
            TabFrame.CanvasSize = UDim2.new(0,0,0,s.Y + 8)
        end)

        TabButton.MouseButton1Click:Connect(function()
            for _, t in ipairs(Tabs) do
                t.Button:SetAttribute("active", false)
                t.Button.BackgroundColor3 = Window._theme.SectionBackground
                t.Button.TextColor3 = Window._theme.Text
                t.Frame.Visible = false
            end
            TabButton:SetAttribute("active", true)
            TabButton.BackgroundColor3 = Window._theme.Accent
            TabButton.TextColor3 = Color3.fromRGB(255,255,255)
            TabFrame.Visible = true
        end)

        table.insert(Tabs, {Button = TabButton, Frame = TabFrame})

        -- Tab object
        local TabObj = {}

        function TabObj:NewSection(sectionName)
            local Section = Instance.new("Frame")
            Section.Size = UDim2.new(1, -10, 0, 50)
            Section.BackgroundColor3 = Window._theme.SectionBackground
            Section.Parent = TabFrame
            Section.AutomaticSize = Enum.AutomaticSize.Y
            Section.Name = "_section"

            local SectionCorner = Instance.new("UICorner", Section)
            SectionCorner.CornerRadius = UDim.new(0, 6)

            local SectionLayout = Instance.new("UIListLayout", Section)
            SectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
            SectionLayout.Padding = UDim.new(0, 6)

            local SectionPadding = Instance.new("UIPadding", Section)
            SectionPadding.PaddingTop = UDim.new(0, 8)
            SectionPadding.PaddingBottom = UDim.new(0, 8)
            SectionPadding.PaddingLeft = UDim.new(0, 8)
            SectionPadding.PaddingRight = UDim.new(0, 8)

            local Label = Instance.new("TextLabel")
            Label.Text = sectionName
            Label.Size = UDim2.new(1,0,0,20)
            Label.BackgroundTransparency = 1
            Label.TextColor3 = Window._theme.SubText
            Label.Font = Enum.Font.GothamBold
            Label.TextSize = 14
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = Section
            Label:SetAttribute("isSectionTitle", true)

            -- Section API
            local SectionObj = {}

            function SectionObj:NewLabel(text, rich)
                local lbl = Instance.new("TextLabel")
                lbl.Text = text or ""
                lbl.Size = UDim2.new(1,0,0,18)
                lbl.BackgroundTransparency = 1
                lbl.TextColor3 = Window._theme.Text
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                if rich then
                    lbl.RichText = true
                end
                lbl.Parent = Section
                -- Update method
                local handle = {}
                function handle.Update(v, newRich)
                    lbl.Text = v or ""
                    if newRich ~= nil then lbl.RichText = not not newRich end
                end
                return handle
            end

            function SectionObj:NewSeparator()
                local sep = Instance.new("Frame")
                sep.Size = UDim2.new(1,0,0,8)
                sep.BackgroundTransparency = 1
                sep.Parent = Section
                local line = Instance.new("Frame")
                line.Size = UDim2.new(1, -8, 0, 2)
                line.Position = UDim2.new(0, 4, 0, 3)
                line.BackgroundColor3 = Window._theme.TabBackground
                line.BorderSizePixel = 0
                line.Parent = sep
                local corner = Instance.new("UICorner", line)
                corner.CornerRadius = UDim.new(0,2)
                return line
            end

            function SectionObj:NewButton(text, desc, callback)
                local Btn = Instance.new("TextButton")
                Btn.Text = text or ""
                Btn.Size = UDim2.new(1,0,0,34)
                Btn.BackgroundColor3 = Window._theme.SectionBackground
                Btn.TextColor3 = Window._theme.Text
                Btn.Font = Enum.Font.Gotham
                Btn.TextSize = 14
                Btn.AutoButtonColor = false
                Btn.Parent = Section

                local BtnCorner = Instance.new("UICorner", Btn)
                BtnCorner.CornerRadius = UDim.new(0,6)

                Btn.MouseEnter:Connect(function()
                    tween(Btn, {BackgroundColor3 = Window._theme.TabBackground, Size = UDim2.new(1, -6, 0, 36)}, 0.08)
                end)
                Btn.MouseLeave:Connect(function()
                    tween(Btn, {BackgroundColor3 = Window._theme.SectionBackground, Size = UDim2.new(1, 0, 0, 34)}, 0.08)
                end)

                local OnChanged = MakeEvent()

                Btn.MouseButton1Click:Connect(function()
                    tween(Btn, {BackgroundColor3 = Window._theme.Accent, Size = UDim2.new(1, -8, 0, 32)}, 0.08)
                    task.wait(0.09)
                    tween(Btn, {BackgroundColor3 = Window._theme.SectionBackground, Size = UDim2.new(1, 0, 0, 34)}, 0.12)
                    pcall(function() callback() end)
                    OnChanged:Fire()
                end)

                local handle = {
                    Button = Btn,
                    OnChanged = OnChanged
                }
                function handle.Update(newText, newDesc, newCb)
                    if newText ~= nil then Btn.Text = newText end
                    if newCb ~= nil then callback = newCb end
                end
                return handle
            end

            function SectionObj:NewToggle(text, desc, callback, default)
                local ToggleBtn = Instance.new("TextButton")
                ToggleBtn.Text = (text or "") .. " [OFF]"
                ToggleBtn.Size = UDim2.new(1,0,0,34)
                ToggleBtn.BackgroundColor3 = Window._theme.SectionBackground
                ToggleBtn.TextColor3 = Window._theme.Text
                ToggleBtn.Font = Enum.Font.Gotham
                ToggleBtn.TextSize = 14
                ToggleBtn.AutoButtonColor = false
                ToggleBtn.Parent = Section

                local ToggleCorner = Instance.new("UICorner", ToggleBtn)
                ToggleCorner.CornerRadius = UDim.new(0,6)

                local stateToggle = default and true or false
                ToggleBtn:SetAttribute("_isToggleState", true)
                ToggleBtn:SetAttribute("_toggle", stateToggle)

                local OnChanged = MakeEvent()

                local function updateVisual()
                    ToggleBtn.Text = (text or "") .. (stateToggle and " [ON]" or " [OFF]")
                    ToggleBtn.BackgroundColor3 = stateToggle and Window._theme.Accent or Window._theme.SectionBackground
                    ToggleBtn.TextColor3 = stateToggle and Color3.fromRGB(255,255,255) or Window._theme.Text
                    ToggleBtn:SetAttribute("_toggle", stateToggle)
                end
                updateVisual()

                ToggleBtn.MouseEnter:Connect(function()
                    tween(ToggleBtn, {BackgroundColor3 = Window._theme.TabBackground, Size = UDim2.new(1, -6, 0, 36)}, 0.08)
                end)
                ToggleBtn.MouseLeave:Connect(function()
                    local bg = stateToggle and Window._theme.Accent or Window._theme.SectionBackground
                    tween(ToggleBtn, {BackgroundColor3 = bg, Size = UDim2.new(1, 0, 0, 34)}, 0.08)
                end)

                ToggleBtn.MouseButton1Click:Connect(function()
                    tween(ToggleBtn, {Size = UDim2.new(1, -8, 0, 32)}, 0.08)
                    task.wait(0.09)
                    tween(ToggleBtn, {Size = UDim2.new(1, 0, 0, 34)}, 0.12)
                    stateToggle = not stateToggle
                    updateVisual()
                    pcall(function() callback(stateToggle) end)
                    OnChanged:Fire(stateToggle)
                end)

                local handle = {
                    Button = ToggleBtn,
                    GetState = function() return stateToggle end,
                    SetState = function(v)
                        stateToggle = not not v
                        updateVisual()
                    end,
                    OnChanged = OnChanged,
                    Update = function(newText, newCb)
                        if newText ~= nil then text = newText end
                        if newCb ~= nil then callback = newCb end
                        updateVisual()
                    end
                }
                return handle
            end

            function SectionObj:NewSlider(text, min, max, default, callback, step)
                min = min or 0
                max = max or 100
                default = default or min
                step = step or 0 -- 0 == continuous

                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1,0,0,56)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local lbl = Instance.new("TextLabel")
                lbl.Text = text or ""
                lbl.Size = UDim2.new(1, -8, 0, 18)
                lbl.Position = UDim2.new(0, 0, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.TextColor3 = Window._theme.SubText
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 13
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = wrap

                local valueLabel = Instance.new("TextLabel")
                valueLabel.Size = UDim2.new(0, 60, 0, 18)
                valueLabel.Position = UDim2.new(1, -60, 0, 0)
                valueLabel.BackgroundTransparency = 1
                valueLabel.TextColor3 = Window._theme.SubText
                valueLabel.Font = Enum.Font.Gotham
                valueLabel.TextSize = 12
                valueLabel.TextXAlignment = Enum.TextXAlignment.Right
                valueLabel.Parent = wrap

                local bar = Instance.new("Frame")
                bar.Size = UDim2.new(1, -8, 0, 18)
                bar.Position = UDim2.new(0, 0, 0, 30)
                bar.BackgroundColor3 = Window._theme.SectionBackground
                bar.Parent = wrap

                local barCorner = Instance.new("UICorner", bar)
                barCorner.CornerRadius = UDim.new(0,8)

                local fill = Instance.new("Frame")
                local initialRel = 0
                if max > min then initialRel = (default - min) / (max - min) end
                fill.Size = UDim2.new(initialRel, 0, 1, 0)
                fill.BackgroundColor3 = Window._theme.Accent
                fill.Parent = bar

                local fillCorner = Instance.new("UICorner", fill)
                fillCorner.CornerRadius = UDim.new(0,8)

                local knob = Instance.new("Frame")
                knob.Size = UDim2.new(0,14,0,14)
                knob.Position = UDim2.new(initialRel, -7, 0.5, -7)
                knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
                knob.Parent = bar
                local knobCorner = Instance.new("UICorner", knob)
                knobCorner.CornerRadius = UDim.new(0,8)

                local dragging = false
                local OnChanged = MakeEvent()

                local function formatVal(v)
                    if step and step > 0 then
                        local n = math.floor((v/min(step, math.huge)) + 0.5)
                        local val = min + (n * step)
                        return math.floor(val * 100)/100
                    else
                        return math.floor(v * 100)/100
                    end
                end

                local function updateByX(x)
                    local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    knob.Position = UDim2.new(rel, -7, 0.5, -7)
                    local val = min + (max - min) * rel
                    if step and step > 0 then
                        val = math.floor((val / step) + 0.5) * step
                        rel = (val - min) / (max - min)
                        fill.Size = UDim2.new(rel, 0, 1, 0)
                        knob.Position = UDim2.new(rel, -7, 0.5, -7)
                    end
                    valueLabel.Text = tostring(formatVal(val))
                    pcall(function() callback(val) end)
                    OnChanged:Fire(val)
                end

                bar.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        updateByX(inp.Position.X)
                    end
                end)
                bar.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
                UserInputService.InputChanged:Connect(function(inp)
                    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                        updateByX(inp.Position.X)
                    end
                end)

                -- initialize display
                (function()
                    local rel = initialRel
                    local val = min + (max - min) * rel
                    if step and step > 0 then
                        val = math.floor((val / step) + 0.5) * step
                    end
                    valueLabel.Text = tostring(formatVal(val))
                end)()

                local handle = {
                    Set = function(v)
                        local rel = 0
                        if max > min then rel = math.clamp((v - min) / (max - min), 0, 1) end
                        fill.Size = UDim2.new(rel, 0, 1, 0)
                        knob.Position = UDim2.new(rel, -7, 0.5, -7)
                        local val = min + (max - min) * rel
                        valueLabel.Text = tostring(formatVal(val))
                        pcall(function() callback(val) end)
                        OnChanged:Fire(val)
                    end,
                    Get = function()
                        local val = min + (max - min) * fill.Size.X.Scale
                        if step and step > 0 then
                            val = math.floor((val / step) + 0.5) * step
                        end
                        return val
                    end,
                    OnChanged = OnChanged,
                    Update = function(newText, newMin, newMax, newCb, newStep)
                        if newText then lbl.Text = newText end
                        if newMin then min = newMin end
                        if newMax then max = newMax end
                        if newCb then callback = newCb end
                        if newStep ~= nil then step = newStep end
                    end
                }
                return handle
            end

            function SectionObj:NewTextbox(placeholder, defaultText, callback)
                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1,0,0,34)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local box = Instance.new("TextBox")
                box.Size = UDim2.new(1,0,1,0)
                box.BackgroundColor3 = Window._theme.SectionBackground
                box.TextColor3 = Window._theme.Text
                box.ClearTextOnFocus = false
                box.Text = defaultText or ""
                box.PlaceholderText = placeholder or ""
                box.Font = Enum.Font.Gotham
                box.TextSize = 14
                box.Parent = wrap

                local boxCorner = Instance.new("UICorner", box)
                boxCorner.CornerRadius = UDim.new(0,6)

                local OnChanged = MakeEvent()
                box.FocusLost:Connect(function(enterPressed)
                    if enterPressed and callback then
                        pcall(function() callback(box.Text) end)
                    end
                    OnChanged:Fire(box.Text)
                end)

                return {
                    TextBox = box,
                    Get = function() return box.Text end,
                    Set = function(v) box.Text = tostring(v) end,
                    Focus = function() box:CaptureFocus() end,
                    OnChanged = OnChanged,
                    Update = function(newPlaceholder, newDefault, newCb)
                        if newPlaceholder then box.PlaceholderText = newPlaceholder end
                        if newDefault then box.Text = tostring(newDefault) end
                        if newCb then callback = newCb end
                    end
                }
            end

            function SectionObj:NewKeybind(desc, defaultKey, callback)
                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1,0,0,34)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local btn = Instance.new("TextButton")
                local curKey = defaultKey and (tostring(defaultKey):gsub("^Enum.KeyCode%.","")) or "None"
                btn.Text = (desc and desc .. " : " or "") .. "[" .. curKey .. "]"
                btn.Size = UDim2.new(1,0,1,0)
                btn.BackgroundColor3 = Window._theme.SectionBackground
                btn.TextColor3 = Window._theme.Text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.AutoButtonColor = false
                btn.Parent = wrap

                local btnCorner = Instance.new("UICorner", btn)
                btnCorner.CornerRadius = UDim.new(0,6)

                local capturing = false
                local boundKey = defaultKey
                local OnPressed = MakeEvent()

                local function updateDisplay()
                    local kName = boundKey and (tostring(boundKey):gsub("^Enum.KeyCode%.","")) or "None"
                    btn.Text = (desc and desc .. " : " or "") .. "[" .. kName .. "]"
                end
                updateDisplay()

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
                        pcall(function() callback() end)
                        OnPressed:Fire()
                    end
                end)

                return {
                    Button = btn,
                    GetKey = function() return boundKey end,
                    SetKey = function(k) boundKey = k; updateDisplay() end,
                    Disconnect = function() if listenerConn then listenerConn:Disconnect() end end,
                    OnPressed = OnPressed,
                    Update = function(newDesc, newCb)
                        if newDesc then desc = newDesc; updateDisplay() end
                        if newCb then callback = newCb end
                    end
                }
            end

            -- Embedded Dropdown (options appear below button inside section)
            -- Supports keyboard nav and highlights; auto-collapse (global Window._currentOpenDropdown)
            function SectionObj:NewDropdown(name, options, callback, default)
                options = options or {}
                local current = default or options[1] or nil
                local open = false
                local optionsFrame = nil
                local highlightIndex = 0
                local OnChanged = MakeEvent()

                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1,0,0,34)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local btn = Instance.new("TextButton")
                btn.Text = (name and name .. ": " or "") .. (current and tostring(current) or "[Select]")
                btn.Size = UDim2.new(1,0,1,0)
                btn.BackgroundColor3 = Window._theme.SectionBackground
                btn.TextColor3 = Window._theme.Text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.AutoButtonColor = false
                btn.Parent = wrap

                local btnCorner = Instance.new("UICorner", btn)
                btnCorner.CornerRadius = UDim.new(0,6)

                local function closeOptions()
                    if optionsFrame and optionsFrame.Parent then
                        optionsFrame:Destroy()
                    end
                    optionsFrame = nil
                    open = false
                    highlightIndex = 0
                    if Window._currentOpenDropdown == closeOptions then Window._currentOpenDropdown = nil end
                end

                local function openOptions()
                    -- close other global dropdown
                    if Window._currentOpenDropdown and Window._currentOpenDropdown ~= closeOptions then
                        pcall(function() Window._currentOpenDropdown() end)
                    end

                    closeOptions()
                    open = true
                    optionsFrame = Instance.new("Frame")
                    optionsFrame.Name = "_dropdownOptions"
                    optionsFrame.BackgroundColor3 = Window._theme.SectionBackground
                    optionsFrame.BorderSizePixel = 0
                    optionsFrame.Size = UDim2.new(1,0,0, math.min(200, #options * 28))
                    optionsFrame.Parent = Section

                    local corner = Instance.new("UICorner", optionsFrame)
                    corner.CornerRadius = UDim.new(0,6)

                    local list = Instance.new("ScrollingFrame")
                    list.BackgroundTransparency = 1
                    list.Size = UDim2.new(1,0,1,0)
                    list.CanvasSize = UDim2.new(0,0,0,0)
                    list.ScrollBarThickness = 6
                    list.Parent = optionsFrame

                    local layout = Instance.new("UIListLayout", list)
                    layout.SortOrder = Enum.SortOrder.LayoutOrder
                    layout.Padding = UDim.new(0,4)

                    local optionButtons = {}

                    for i,opt in ipairs(options) do
                        local optBtn = Instance.new("TextButton")
                        optBtn.Size = UDim2.new(1, -8, 0, 24)
                        optBtn.Position = UDim2.new(0, 4, 0, (i-1) * 28)
                        optBtn.BackgroundColor3 = Window._theme.Background
                        optBtn.Text = tostring(opt)
                        optBtn.Font = Enum.Font.Gotham
                        optBtn.TextSize = 13
                        optBtn.TextColor3 = Window._theme.Text
                        optBtn.AutoButtonColor = false
                        optBtn.Parent = list

                        local oc = Instance.new("UICorner", optBtn)
                        oc.CornerRadius = UDim.new(0,6)

                        optBtn.MouseEnter:Connect(function()
                            tween(optBtn, {BackgroundColor3 = Window._theme.TabBackground}, 0.08)
                        end)
                        optBtn.MouseLeave:Connect(function()
                            tween(optBtn, {BackgroundColor3 = Window._theme.Background}, 0.08)
                        end)
                        optBtn.MouseButton1Click:Connect(function()
                            current = opt
                            btn.Text = (name and name .. ": " or "") .. tostring(current)
                            pcall(function() callback(current) end)
                            OnChanged:Fire(current)
                            closeOptions()
                        end)
                        table.insert(optionButtons, optBtn)
                    end

                    -- adjust size based on content
                    spawn(function()
                        task.wait(0.03)
                        local s = layout.AbsoluteContentSize
                        optionsFrame.Size = UDim2.new(1, 0, 0, math.min(200, s.Y + 8))
                        list.CanvasSize = UDim2.new(0, 0, 0, s.Y + 4)
                    end)

                    -- keyboard nav (Up/Down/Enter/Escape)
                    local conn
                    conn = UserInputService.InputBegan:Connect(function(input, gp)
                        if gp then return end
                        if not open then return end
                        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                        local key = input.KeyCode
                        if key == Enum.KeyCode.Down then
                            highlightIndex = math.min(#optionButtons, highlightIndex + 1)
                        elseif key == Enum.KeyCode.Up then
                            highlightIndex = math.max(1, highlightIndex - 1)
                        elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter then
                            if highlightIndex >= 1 and optionButtons[highlightIndex] then
                                optionButtons[highlightIndex]:MouseButton1Click()
                            end
                        elseif key == Enum.KeyCode.Escape then
                            closeOptions()
                        end
                        -- highlight visuals
                        for i,bv in ipairs(optionButtons) do
                            if i == highlightIndex then
                                bv.BackgroundColor3 = Window._theme.TabBackground
                            else
                                bv.BackgroundColor3 = Window._theme.Background
                            end
                        end
                    end)

                    Window._currentOpenDropdown = closeOptions
                end

                btn.MouseButton1Click:Connect(function()
                    if open then closeOptions() else openOptions() end
                end)

                local handle = {
                    Button = btn,
                    Get = function() return current end,
                    Set = function(v)
                        current = v
                        btn.Text = (name and name .. ": " or "") .. tostring(current)
                        pcall(function() callback(current) end)
                        OnChanged:Fire(current)
                    end,
                    Refresh = function(newOptions)
                        options = newOptions or {}
                        current = options[1] or nil
                        btn.Text = (name and name .. ": " or "") .. (current and tostring(current) or "[Select]")
                        if optionsFrame then optionsFrame:Destroy(); optionsFrame = nil; open = false end
                    end,
                    OnChanged = OnChanged
                }
                return handle
            end

            function SectionObj:NewColorpicker(name, defaultColor, callback)
                defaultColor = defaultColor or Color3.fromRGB(255,120,0)
                local cur = defaultColor
                local OnChanged = MakeEvent()

                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1,0,0,34)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1,0,1,0)
                btn.BackgroundColor3 = Window._theme.SectionBackground
                btn.AutoButtonColor = false
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.TextColor3 = Window._theme.Text
                btn.Text = (name and name .. " : " or "") .. "[Color]"
                btn.Parent = wrap

                local preview = Instance.new("Frame", wrap)
                preview.Size = UDim2.new(0,24,0,24)
                preview.Position = UDim2.new(1, -28, 0.5, -12)
                preview.BackgroundColor3 = cur
                local pc = Instance.new("UICorner", preview)
                pc.CornerRadius = UDim.new(0,6)

                -- popup
                local popup = nil
                local open = false

                local function closePopup()
                    if popup and popup.Parent then popup:Destroy() end
                    popup = nil
                    open = false
                end

                local function createSlider(parent, y, labelText, initial, onChange)
                    local lbl = Instance.new("TextLabel", parent)
                    lbl.Text = labelText
                    lbl.Size = UDim2.new(1, -12, 0, 16)
                    lbl.Position = UDim2.new(0,8,0,y)
                    lbl.BackgroundTransparency = 1
                    lbl.TextColor3 = Window._theme.SubText
                    lbl.Font = Enum.Font.Gotham
                    lbl.TextSize = 12
                    lbl.TextXAlignment = Enum.TextXAlignment.Left

                    local bar = Instance.new("Frame", parent)
                    bar.Size = UDim2.new(1, -12, 0, 10)
                    bar.Position = UDim2.new(0,8,0,y+18)
                    bar.BackgroundColor3 = Window._theme.SectionBackground
                    local barCorner = Instance.new("UICorner", bar)
                    barCorner.CornerRadius = UDim.new(0,6)

                    local fill = Instance.new("Frame", bar)
                    fill.Size = UDim2.new(initial or 0,0,1,0)
                    fill.BackgroundColor3 = Window._theme.Accent
                    local fillCorner = Instance.new("UICorner", fill)
                    fillCorner.CornerRadius = UDim.new(0,6)

                    local knob = Instance.new("Frame", bar)
                    knob.Size = UDim2.new(0,10,0,10)
                    knob.Position = UDim2.new(initial or 0, -5, 0, 0)
                    local kc = Instance.new("UICorner", knob)
                    kc.CornerRadius = UDim.new(0,6)
                    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)

                    local dragging = false
                    bar.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging = true
                            local relx = math.clamp((inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                            fill.Size = UDim2.new(relx, 0, 1, 0)
                            knob.Position = UDim2.new(relx, -5, 0, 0)
                            pcall(function() onChange(relx) end)
                        end
                    end)
                    bar.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
                    end)
                    UserInputService.InputChanged:Connect(function(inp)
                        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                            local relx = math.clamp((inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                            fill.Size = UDim2.new(relx, 0, 1, 0)
                            knob.Position = UDim2.new(relx, -5, 0, 0)
                            pcall(function() onChange(relx) end)
                        end
                    end)

                    return {
                        Set = function(v) local rv = math.clamp(v,0,1); fill.Size = UDim2.new(rv,0,1,0); knob.Position = UDim2.new(rv, -5,0,0) end,
                        Get = function() return fill.Size.X.Scale end
                    }
                end

                btn.MouseButton1Click:Connect(function()
                    if open then closePopup(); return end
                    open = true
                    popup = Instance.new("Frame", ScreenGui)
                    popup.Size = UDim2.new(0,280,0,220)
                    popup.BackgroundColor3 = Window._theme.SectionBackground
                    local corner = Instance.new("UICorner", popup)
                    corner.CornerRadius = UDim.new(0,8)

                    local ap = wrap.AbsolutePosition
                    popup.Position = UDim2.new(0, ap.X + 160, 0, ap.Y + 20)

                    local title = Instance.new("TextLabel", popup)
                    title.Text = name or "Color"
                    title.Size = UDim2.new(1, -12, 0, 18)
                    title.Position = UDim2.new(0,8,0,6)
                    title.BackgroundTransparency = 1
                    title.TextColor3 = Window._theme.SubText
                    title.Font = Enum.Font.GothamBold
                    title.TextSize = 13
                    title.TextXAlignment = Enum.TextXAlignment.Left

                    local previewBox = Instance.new("Frame", popup)
                    previewBox.Size = UDim2.new(0,40,0,40)
                    previewBox.Position = UDim2.new(1, -52, 0, 8)
                    previewBox.BackgroundColor3 = cur
                    local pc2 = Instance.new("UICorner", previewBox)
                    pc2.CornerRadius = UDim.new(0,6)

                    local r,g,b = cur.R, cur.G, cur.B

                    local rSlider = createSlider(popup, 36, "R", r, function(rel) r = rel; cur = Color3.new(r,g,b); previewBox.BackgroundColor3 = cur; preview.BackgroundColor3 = cur; pcall(callback, cur); OnChanged:Fire(cur) end)
                    local gSlider = createSlider(popup, 76, "G", g, function(rel) g = rel; cur = Color3.new(r,g,b); previewBox.BackgroundColor3 = cur; preview.BackgroundColor3 = cur; pcall(callback, cur); OnChanged:Fire(cur) end)
                    local bSlider = createSlider(popup, 116, "B", b, function(rel) b = rel; cur = Color3.new(r,g,b); previewBox.BackgroundColor3 = cur; preview.BackgroundColor3 = cur; pcall(callback, cur); OnChanged:Fire(cur) end)

                    -- presets
                    local presets = {
                        Color3.fromRGB(0,120,255),
                        Color3.fromRGB(255,100,100),
                        Color3.fromRGB(120,90,255),
                        Color3.fromRGB(80,200,120),
                        Color3.fromRGB(255,200,0)
                    }
                    local presLabel = Instance.new("TextLabel", popup)
                    presLabel.Text = "Presets"
                    presLabel.Size = UDim2.new(1, -12, 0, 16)
                    presLabel.Position = UDim2.new(0,8,0,156)
                    presLabel.BackgroundTransparency = 1
                    presLabel.TextColor3 = Window._theme.SubText
                    presLabel.Font = Enum.Font.GothamBold
                    presLabel.TextSize = 12

                    for i,c in ipairs(presets) do
                        local sw = Instance.new("Frame", popup)
                        sw.Size = UDim2.new(0,24,0,24)
                        sw.Position = UDim2.new(0, 8 + (i-1)*28, 0, 176)
                        sw.BackgroundColor3 = c
                        local sc = Instance.new("UICorner", sw)
                        sc.CornerRadius = UDim.new(0,6)
                        sw.Active = true
                        sw.AutoButtonColor = false
                        sw.InputBegan:Connect(function(inp)
                            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                                cur = c
                                r,g,b = cur.R, cur.G, cur.B
                                previewBox.BackgroundColor3 = cur
                                preview.BackgroundColor3 = cur
                                pcall(callback, cur); OnChanged:Fire(cur)
                            end
                        end)
                    end

                    -- hex input
                    local hexBox = Instance.new("TextBox", popup)
                    hexBox.Size = UDim2.new(0,120,0,22)
                    hexBox.Position = UDim2.new(1, -132, 0, 176)
                    hexBox.BackgroundColor3 = Window._theme.SectionBackground
                    hexBox.TextColor3 = Window._theme.Text
                    hexBox.Font = Enum.Font.Gotham
                    hexBox.TextSize = 12
                    hexBox.PlaceholderText = "#RRGGBB"
                    local hexCorner = Instance.new("UICorner", hexBox)
                    hexCorner.CornerRadius = UDim.new(0,6)

                    hexBox.FocusLost:Connect(function(enterPressed)
                        if not enterPressed then return end
                        local txt = hexBox.Text:match("^#?(%x%x%x%x%x%x)$")
                        if txt then
                            local rhex = tonumber(txt:sub(1,2),16)
                            local ghex = tonumber(txt:sub(3,4),16)
                            local bhex = tonumber(txt:sub(5,6),16)
                            if rhex and ghex and bhex then
                                cur = Color3.fromRGB(rhex, ghex, bhex)
                                r,g,b = cur.R, cur.G, cur.B
                                previewBox.BackgroundColor3 = cur
                                preview.BackgroundColor3 = cur
                                pcall(callback, cur); OnChanged:Fire(cur)
                            end
                        end
                    end)

                    -- close on outside click
                    local conn
                    conn = UserInputService.InputBegan:Connect(function(input, gp)
                        if gp then return end
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            local mp = input.Position
                            local pos = Vector2.new(popup.AbsolutePosition.X, popup.AbsolutePosition.Y)
                            local size = Vector2.new(popup.AbsoluteSize.X, popup.AbsoluteSize.Y)
                            if not (mp.X >= pos.X and mp.X <= pos.X + size.X and mp.Y >= pos.Y and mp.Y <= pos.Y + size.Y) then
                                conn:Disconnect()
                                closePopup()
                            end
                        end
                    end)
                end)

                local handle = {
                    Button = btn,
                    Get = function() return cur end,
                    Set = function(c)
                        if typeof(c) == "Color3" then
                            cur = c
                        elseif type(c) == "table" then
                            if c[1] and c[2] and c[3] then
                                cur = Color3.new(c[1], c[2], c[3])
                            end
                        end
                        preview.BackgroundColor3 = cur
                        pcall(function() callback(cur) end)
                        OnChanged:Fire(cur)
                    end,
                    OnChanged = OnChanged,
                    Update = function(newName, newCb)
                        if newName then btn.Text = (newName and newName .. " : " or "") .. "[Color]" end
                        if newCb then callback = newCb end
                    end
                }
                return handle
            end

            return SectionObj
        end

        return TabObj
    end

    -- apply initial theme
    Window:SetTheme(themeArg or "LightTheme")

    -- convenience: return library window
    return Window
end

return Kour6anHub
