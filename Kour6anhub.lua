-- Kour6anHub UI Library (Kavo-compatible API) 
-- v4 → persistent config (Save / Load) added
-- Keep same API: CreateLib -> NewTab -> NewSection -> NewButton/NewToggle/NewSlider/NewTextbox/NewKeybind/NewDropdown/NewColorpicker/NewLabel/NewSeparator
-- Config API:
--   Window:SaveConfig(name) -> (true|nil,err)
--   Window:LoadConfig(name, apply) -> (tbl|nil,err)
--   Window:ExportConfig() -> tbl
--   Window:ImportConfig(tbl, apply)
--   Window:ListConfigs() -> {names...}
--   Window:DeleteConfig(name)

local Kour6anHub = {}
Kour6anHub.__index = Kour6anHub

-- Services
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- Tween helper
local function tween(obj, props, dur)
    local ti = TweenInfo.new(dur or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, ti, props)
    t:Play()
    return t
end

-- Utility: Dragging (original style)
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

-- Themes
local Themes = {
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
    ["Midnight"] = {
        Background = Color3.fromRGB(10,12,20),
        TabBackground = Color3.fromRGB(18,20,30),
        SectionBackground = Color3.fromRGB(22,24,36),
        Text = Color3.fromRGB(235,235,245),
        SubText = Color3.fromRGB(150,150,170),
        Accent = Color3.fromRGB(120,90,255)
    },
    ["Blood"] = {
        Background = Color3.fromRGB(18,6,8),
        TabBackground = Color3.fromRGB(30,10,12),
        SectionBackground = Color3.fromRGB(40,14,16),
        Text = Color3.fromRGB(245,220,220),
        SubText = Color3.fromRGB(200,140,140),
        Accent = Color3.fromRGB(220,20,30)
    },
    ["Synapse"] = {
        Background = Color3.fromRGB(12,10,20),
        TabBackground = Color3.fromRGB(22,18,36),
        SectionBackground = Color3.fromRGB(30,26,46),
        Text = Color3.fromRGB(235,235,245),
        SubText = Color3.fromRGB(170,160,190),
        Accent = Color3.fromRGB(100,160,255)
    },
    ["Sentinel"] = {
        Background = Color3.fromRGB(8,18,12),
        TabBackground = Color3.fromRGB(14,28,20),
        SectionBackground = Color3.fromRGB(20,40,28),
        Text = Color3.fromRGB(230,245,230),
        SubText = Color3.fromRGB(160,200,170),
        Accent = Color3.fromRGB(70,200,120)
    }
}

-- Notification helper GUI (unchanged from previous patch)
local function ensureNotificationGui()
    local gui = CoreGui:FindFirstChild("Kour6anHub_Notifs")
    if gui and gui.Parent then return gui end
    gui = Instance.new("ScreenGui")
    gui.Name = "Kour6anHub_Notifs"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui

    local holder = Instance.new("Frame")
    holder.Name = "_holder"
    holder.AnchorPoint = Vector2.new(1, 1)
    holder.Position = UDim2.new(1, -12, 1, -12)
    holder.Size = UDim2.new(0, 320, 0, 0)
    holder.BackgroundTransparency = 1
    holder.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Parent = holder

    return gui
end

-- Create window
function Kour6anHub.CreateLib(title, themeName)
    local theme = Themes[themeName] or Themes["LightTheme"]

    -- ScreenGui (replace if exists)
    local ScreenGui = CoreGui:FindFirstChild("Kour6anHub")
    if ScreenGui then ScreenGui:Destroy() end
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Kour6anHub"
    ScreenGui.Parent = CoreGui

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
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = theme.Text
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.Parent = Topbar

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
    Window._currentOpenDropdown = nil

    -- Registry for persistent elements
    Window._registry = {}          -- flag -> {get=set functions, set=function, dtype=string}
    Window._savedConfigs = {}      -- in-memory fallback when writefile not available

    -- registers a persistent flag
    function Window:RegisterFlag(flag, getter, setter, dtype)
        if type(flag) ~= "string" or flag == "" then return false end
        self._registry[flag] = {get = getter, set = setter, dtype = dtype}
        return true
    end

    -- helper encoding/decoding for persistable types
    local function encodeValue(v)
        local t = typeof(v)
        if t == "Color3" then
            return {__type = "Color3", r = v.R, g = v.G, b = v.B}
        elseif t == "EnumItem" then
            -- save enum type name and member name
            return {__type = "Enum", enumType = tostring(v.EnumType), name = v.Name}
        else
            -- primitive: boolean, number, string, table etc
            return v
        end
    end

    local function decodeValue(v)
        if type(v) == "table" and v.__type == "Color3" then
            return Color3.new(v.r or 0, v.g or 0, v.b or 0)
        elseif type(v) == "table" and v.__type == "Enum" then
            -- try to get Enum by name
            local enumTypeStr = v.enumType or ""
            local enumName = v.name or ""
            -- enumTypeStr looks like "KeyCode" or "Enum.KeyCode" depending on encoding
            local et = enumTypeStr
            -- normalize: if contains "Enum." remove
            et = string.gsub(et, "^Enum%.", "")
            if Enum[et] and Enum[et][enumName] then
                return Enum[et][enumName]
            end
            return nil
        else
            return v
        end
    end

    -- File helpers (exploit APIs: makefolder, isfolder, writefile, readfile, listfiles, delfile)
    local function ensureConfigFolder()
        local folder = "Kour6anHub_configs"
        if type(makefolder) == "function" then
            if type(isfolder) == "function" then
                if not isfolder(folder) then
                    pcall(function() makefolder(folder) end)
                end
            else
                -- still try to create
                pcall(function() makefolder(folder) end)
            end
        end
    end

    local function writeConfigFile(name, data)
        -- data is a string (JSON)
        if type(writefile) == "function" then
            ensureConfigFolder()
            local path = "Kour6anHub_configs/" .. name .. ".json"
            local ok, err = pcall(function() writefile(path, data) end)
            if ok then return true end
            return nil, err
        else
            -- fallback: store in-memory
            Window._savedConfigs[name] = data
            return true, "in-memory"
        end
    end

    local function readConfigFile(name)
        if type(readfile) == "function" then
            local path = "Kour6anHub_configs/" .. name .. ".json"
            local ok, content = pcall(function() return readfile(path) end)
            if ok then return content end
            return nil, content
        else
            if Window._savedConfigs[name] then
                return Window._savedConfigs[name]
            end
            return nil, "no readfile available and not in-memory"
        end
    end

    local function deleteConfigFile(name)
        if type(delfile) == "function" then
            local path = "Kour6anHub_configs/" .. name .. ".json"
            local ok, err = pcall(function() delfile(path) end)
            if ok then return true end
            return nil, err
        elseif type(writefile) == "function" and type(isfolder) == "function" then
            -- some environments have no delfile; try writing empty then rely on OS? Not safe
            return nil, "delete not supported on this executor"
        else
            if Window._savedConfigs[name] then
                Window._savedConfigs[name] = nil
                return true
            end
            return nil, "no delete support"
        end
    end

    local function listConfigFiles()
        local out = {}
        if type(listfiles) == "function" then
            local fpath = "Kour6anHub_configs"
            local ok, files = pcall(function() return listfiles(fpath) end)
            if ok and type(files) == "table" then
                for _, fp in ipairs(files) do
                    -- extract base name
                    local name = fp:match(".*/(.*)%.json$") or fp:match("(.+)%.json$")
                    if name then table.insert(out, name) end
                end
            end
            return out
        else
            -- fallback to in-memory store's keys
            for k,_ in pairs(Window._savedConfigs) do table.insert(out, k) end
            table.sort(out)
            return out
        end
    end

    -- Get all current registered values as a Lua table
    function Window:ExportConfig()
        local cfg = {}
        for flag,entry in pairs(self._registry) do
            local ok, val = pcall(function() return entry.get() end)
            if ok then
                cfg[flag] = encodeValue(val)
            else
                cfg[flag] = nil
            end
        end
        return cfg
    end

    -- Save to disk/in-memory as JSON. Returns true or nil, err
    function Window:SaveConfig(name)
        if type(name) ~= "string" or name == "" then return nil, "invalid name" end
        local cfg = self:ExportConfig()
        local json = ""
        local ok, encoded = pcall(function() return HttpService:JSONEncode(cfg) end)
        if not ok then return nil, encoded end
        json = encoded
        local ok2, err = writeConfigFile(name, json)
        if ok2 then
            return true
        end
        return nil, err
    end

    -- Import a table and optionally apply (apply default true)
    function Window:ImportConfig(tbl, apply)
        if type(tbl) ~= "table" then return nil, "invalid table" end
        for flag,enc in pairs(tbl) do
            local decoded = decodeValue(enc)
            local entry = self._registry[flag]
            if entry and type(entry.set) == "function" then
                pcall(function() entry.set(decoded) end)
            end
        end
        if apply == nil then apply = true end
        return true
    end

    -- Load config by name (reads file or in-memory). If apply==false, returns the table only.
    function Window:LoadConfig(name, apply)
        if type(name) ~= "string" or name == "" then return nil, "invalid name" end
        local content, err = readConfigFile(name)
        if not content then return nil, err end
        local ok, tbl = pcall(function() return HttpService:JSONDecode(content) end)
        if not ok then return nil, tbl end
        if apply == nil then apply = true end
        if apply then
            self:ImportConfig(tbl, true)
        end
        return tbl
    end

    function Window:ListConfigs()
        return listConfigFiles()
    end

    function Window:DeleteConfig(name)
        if type(name) ~= "string" or name == "" then return nil, "invalid name" end
        return deleteConfigFile(name)
    end

    -- runtime theme switcher (case-insensitive)
    function Window:SetTheme(newThemeName)
        if not newThemeName then return end
        local foundTheme = nil
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
        if not foundTheme then return end
        theme = foundTheme

        Main.BackgroundColor3 = theme.Background
        Topbar.BackgroundColor3 = theme.SectionBackground
        Title.TextColor3 = theme.Text
        TabContainer.BackgroundColor3 = theme.TabBackground

        for _, entry in ipairs(Tabs) do
            local btn = entry.Button
            local frame = entry.Frame
            local active = btn:GetAttribute("active")
            btn.BackgroundColor3 = active and theme.Accent or theme.SectionBackground
            btn.TextColor3 = active and Color3.fromRGB(255,255,255) or theme.Text

            for _, child in ipairs(frame:GetDescendants()) do
                if child:IsA("Frame") then
                    if child.Name == "_section" then
                        child.BackgroundColor3 = theme.SectionBackground
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
                        child.BackgroundColor3 = theme.SectionBackground
                    else
                        local tog = child:GetAttribute("_toggle")
                        child.BackgroundColor3 = tog and theme.Accent or theme.SectionBackground
                        child.TextColor3 = tog and Color3.fromRGB(255,255,255) or theme.Text
                    end
                elseif child:IsA("TextBox") then
                    child.BackgroundColor3 = theme.SectionBackground
                    child.TextColor3 = theme.Text
                end
            end
        end
    end

    -- Toggle UI methods
    Window._uiVisible = true
    Window._toggleKey = Enum.KeyCode.RightControl
    Window._storedPosition = Main.Position

    function Window:Hide()
        if not Window._uiVisible then return end
        Window._storedPosition = Main.Position
        tween(Main, {Position = UDim2.new(0.5, -300, 0.5, -800)}, 0.18)
        task.delay(0.18, function()
            if ScreenGui then ScreenGui.Enabled = false end
        end)
        Window._uiVisible = false
    end

    function Window:Show()
        if Window._uiVisible then return end
        if ScreenGui then ScreenGui.Enabled = true end
        local target = Window._storedPosition or UDim2.new(0.5, -300, 0.5, -200)
        tween(Main, {Position = target}, 0.18)
        Window._uiVisible = true
    end

    function Window:ToggleUI()
        if Window._uiVisible then Window:Hide() else Window:Show() end
    end

    function Window:SetToggleKey(keyEnum)
        if typeof(keyEnum) == "EnumItem" and keyEnum.EnumType == Enum.KeyCode then
            Window._toggleKey = keyEnum
        end
    end

    -- default toggle listener
    local inputConn
    inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Window._toggleKey then
            Window:ToggleUI()
        end
    end)

    -- small topbar toggle button
    local function createTopbarToggle()
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 32, 0, 28)
        btn.Position = UDim2.new(1, -40, 0, 6)
        btn.AnchorPoint = Vector2.new(0,0)
        btn.BackgroundColor3 = theme.TabBackground
        btn.Text = "▣"
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.TextColor3 = theme.Text
        btn.AutoButtonColor = false
        btn.Parent = Topbar

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0,6)
        corner.Parent = btn

        btn.MouseEnter:Connect(function()
            tween(btn, {BackgroundColor3 = theme.SectionBackground, Size = UDim2.new(0, 34, 0, 30)}, 0.08)
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, {BackgroundColor3 = theme.TabBackground, Size = UDim2.new(0, 32, 0, 28)}, 0.08)
        end)

        btn.MouseButton1Click:Connect(function()
            Window:ToggleUI()
        end)
    end
    createTopbarToggle()

    -- Notification store (notifs gui)
    local NotifGui = ensureNotificationGui()
    local NotifHolder = NotifGui:FindFirstChild("_holder")
    local notifTypeColor = {
        info = function() return theme.Accent end,
        success = function() return Color3.fromRGB(70,200,120) end,
        error = function() return Color3.fromRGB(220,60,60) end,
        warn = function() return Color3.fromRGB(220,170,40) end
    }

    function Window:GetThemeList()
        local out = {}
        for k,_ in pairs(Themes) do table.insert(out, k) end
        table.sort(out)
        return out
    end

    function Window:NewTab(tabName)
        -- Tab button
        local TabButton = Instance.new("TextButton")
        TabButton.Text = tabName
        TabButton.Size = UDim2.new(1, -20, 0, 40)
        TabButton.BackgroundColor3 = theme.SectionBackground
        TabButton.TextColor3 = theme.Text
        TabButton.Font = Enum.Font.Gotham
        TabButton.TextSize = 14
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

        TabButton.MouseEnter:Connect(function()
            tween(TabButton, {BackgroundColor3 = theme.TabBackground, Size = UDim2.new(1, -16, 0, 42)}, 0.1)
        end)
        TabButton.MouseLeave:Connect(function()
            if TabButton:GetAttribute("active") then
                tween(TabButton, {BackgroundColor3 = theme.Accent, Size = UDim2.new(1, -20, 0, 40)}, 0.1)
            else
                tween(TabButton, {BackgroundColor3 = theme.SectionBackground, Size = UDim2.new(1, -20, 0, 40)}, 0.1)
            end
        end)

        -- Tab content frame (scrolling)
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

        -- Tab API
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
                local Btn = Instance.new("TextButton")
                Btn.Text = text
                Btn.Size = UDim2.new(1, 0, 0, 34)
                Btn.BackgroundColor3 = theme.SectionBackground
                Btn.TextColor3 = theme.Text
                Btn.Font = Enum.Font.Gotham
                Btn.TextSize = 14
                Btn.AutoButtonColor = false
                Btn.Parent = Section

                local BtnCorner = Instance.new("UICorner")
                BtnCorner.CornerRadius = UDim.new(0, 6)
                BtnCorner.Parent = Btn

                Btn.MouseEnter:Connect(function()
                    tween(Btn, {BackgroundColor3 = theme.TabBackground, Size = UDim2.new(1, -6, 0, 36)}, 0.08)
                end)
                Btn.MouseLeave:Connect(function()
                    tween(Btn, {BackgroundColor3 = theme.SectionBackground, Size = UDim2.new(1, 0, 0, 34)}, 0.08)
                end)

                Btn.MouseButton1Click:Connect(function()
                    tween(Btn, {BackgroundColor3 = theme.Accent, Size = UDim2.new(1, -8, 0, 32)}, 0.08)
                    task.wait(0.09)
                    tween(Btn, {BackgroundColor3 = theme.SectionBackground, Size = UDim2.new(1, 0, 0, 34)}, 0.12)
                    pcall(function() callback() end)
                end)

                return Btn
            end

            function SectionObj:NewToggle(text, desc, callback, flag)
                local ToggleBtn = Instance.new("TextButton")
                ToggleBtn.Text = text .. " [OFF]"
                ToggleBtn.Size = UDim2.new(1, 0, 0, 34)
                ToggleBtn.BackgroundColor3 = theme.SectionBackground
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

                ToggleBtn.MouseEnter:Connect(function()
                    tween(ToggleBtn, {BackgroundColor3 = theme.TabBackground, Size = UDim2.new(1, -6, 0, 36)}, 0.08)
                end)
                ToggleBtn.MouseLeave:Connect(function()
                    local bg = state and theme.Accent or theme.SectionBackground
                    tween(ToggleBtn, {BackgroundColor3 = bg, Size = UDim2.new(1, 0, 0, 34)}, 0.08)
                end)

                ToggleBtn.MouseButton1Click:Connect(function()
                    tween(ToggleBtn, {Size = UDim2.new(1, -8, 0, 32)}, 0.08)
                    task.wait(0.09)
                    tween(ToggleBtn, {Size = UDim2.new(1, 0, 0, 34)}, 0.12)
                    state = not state
                    ToggleBtn.Text = text .. (state and " [ON]" or " [OFF]")
                    if state then
                        ToggleBtn.BackgroundColor3 = theme.Accent
                        ToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
                    else
                        ToggleBtn.BackgroundColor3 = theme.SectionBackground
                        ToggleBtn.TextColor3 = theme.Text
                    end
                    ToggleBtn:SetAttribute("_toggle", state)
                    pcall(function() callback(state) end)
                end)

                -- expose getters/setters and register if asked
                local handle = {
                    Button = ToggleBtn,
                    GetState = function() return state end,
                    SetState = function(v)
                        state = not not v
                        ToggleBtn.Text = text .. (state and " [ON]" or " [OFF]")
                        ToggleBtn.BackgroundColor3 = state and theme.Accent or theme.SectionBackground
                        ToggleBtn.TextColor3 = state and Color3.fromRGB(255,255,255) or theme.Text
                        ToggleBtn:SetAttribute("_toggle", state)
                    end
                }

                if type(flag) == "string" then
                    Window:RegisterFlag(flag, function() return handle.GetState() end, function(v) handle.SetState(v) end, "boolean")
                end

                return handle
            end

            function SectionObj:NewSlider(text, min, max, default, callback, flag)
                min = min or 0
                max = max or 100
                default = default or min

                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 48)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local lbl = Instance.new("TextLabel")
                lbl.Text = text
                lbl.Size = UDim2.new(1, -8, 0, 18)
                lbl.Position = UDim2.new(0, 0, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.TextColor3 = theme.SubText
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 13
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = wrap

                local bar = Instance.new("Frame")
                bar.Size = UDim2.new(1, -8, 0, 18)
                bar.Position = UDim2.new(0, 0, 0, 24)
                bar.BackgroundColor3 = theme.SectionBackground
                bar.Parent = wrap

                local barCorner = Instance.new("UICorner")
                barCorner.CornerRadius = UDim.new(0, 8)
                barCorner.Parent = bar

                local fill = Instance.new("Frame")
                local initialRel = 0
                if max > min then
                    initialRel = (default - min) / (max - min)
                end
                fill.Size = UDim2.new(initialRel, 0, 1, 0)
                fill.BackgroundColor3 = theme.Accent
                fill.Parent = bar

                local fillCorner = Instance.new("UICorner")
                fillCorner.CornerRadius = UDim.new(0, 8)
                fillCorner.Parent = fill

                local knob = Instance.new("Frame")
                knob.Size = UDim2.new(0, 14, 0, 14)
                knob.Position = UDim2.new(fill.Size.X.Scale, -7, 0.5, -7)
                knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
                knob.Parent = bar
                local knobCorner = Instance.new("UICorner")
                knobCorner.CornerRadius = UDim.new(0, 8)
                knobCorner.Parent = knob

                local dragging = false

                local function updateByX(x)
                    local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    knob.Position = UDim2.new(rel, -7, 0.5, -7)
                    local val = min + (max - min) * rel
                    pcall(function() callback(val) end)
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

                local sliderHandle = {
                    Set = function(v)
                        local rel = 0
                        if max > min then
                            rel = math.clamp((v - min) / (max - min), 0, 1)
                        end
                        fill.Size = UDim2.new(rel, 0, 1, 0)
                        knob.Position = UDim2.new(rel, -7, 0.5, -7)
                        pcall(function() callback(min + (max - min) * rel) end)
                    end,
                    Get = function()
                        return min + (max - min) * fill.Size.X.Scale
                    end
                }

                if type(flag) == "string" then
                    Window:RegisterFlag(flag, function() return sliderHandle.Get() end, function(v) sliderHandle.Set(v) end, "number")
                end

                return sliderHandle
            end

            function SectionObj:NewTextbox(placeholder, defaultText, callback, flag)
                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 34)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local box = Instance.new("TextBox")
                box.Size = UDim2.new(1, 0, 1, 0)
                box.BackgroundColor3 = theme.SectionBackground
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
                    if enterPressed and callback then
                        pcall(function() callback(box.Text) end)
                    end
                end)

                local handle = {
                    TextBox = box,
                    Get = function() return box.Text end,
                    Set = function(v) box.Text = tostring(v) end,
                    Focus = function() box:CaptureFocus() end
                }

                if type(flag) == "string" then
                    Window:RegisterFlag(flag, function() return handle.Get() end, function(v) handle.Set(v) end, "string")
                end

                return handle
            end

            function SectionObj:NewKeybind(desc, defaultKey, callback, flag)
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
                        pcall(function() callback() end)
                    end
                end)

                local handle = {
                    Button = btn,
                    GetKey = function() return boundKey end,
                    SetKey = function(k)
                        boundKey = k
                        updateDisplay()
                    end,
                    Disconnect = function() if listenerConn then listenerConn:Disconnect() end end
                }

                if type(flag) == "string" then
                    Window:RegisterFlag(flag, function() return handle.GetKey() end, function(v) handle.SetKey(v) end, "enum.keycode")
                end

                return handle
            end

            function SectionObj:NewDropdown(name, options, callback, flag)
                options = options or {}
                local current = options[1] or nil
                local open = false
                local optionsFrame = nil

                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 34)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local btn = Instance.new("TextButton")
                btn.Text = (name and name .. ": " or "") .. (current and tostring(current) or "[Select]")
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

                local function closeOptions()
                    if optionsFrame and optionsFrame.Parent then optionsFrame:Destroy() end
                    optionsFrame = nil
                    open = false
                    if Window._currentOpenDropdown == closeOptions then Window._currentOpenDropdown = nil end
                end

                local function openOptions()
                    if Window._currentOpenDropdown and Window._currentOpenDropdown ~= closeOptions then
                        pcall(function() Window._currentOpenDropdown() end)
                    end
                    closeOptions()
                    open = true

                    optionsFrame = Instance.new("Frame")
                    optionsFrame.Name = "_dropdownOptions"
                    optionsFrame.BackgroundColor3 = theme.SectionBackground
                    optionsFrame.BorderSizePixel = 0
                    optionsFrame.Size = UDim2.new(1, 0, 0, math.min(200, #options * 28))
                    optionsFrame.AnchorPoint = Vector2.new(0,0)
                    optionsFrame.Parent = Section

                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0, 6)
                    corner.Parent = optionsFrame

                    local list = Instance.new("ScrollingFrame")
                    list.BackgroundTransparency = 1
                    list.Size = UDim2.new(1, 0, 1, 0)
                    list.CanvasSize = UDim2.new(0, 0, 0, 0)
                    list.ScrollBarThickness = 6
                    list.Parent = optionsFrame

                    local layout = Instance.new("UIListLayout")
                    layout.SortOrder = Enum.SortOrder.LayoutOrder
                    layout.Padding = UDim.new(0, 4)
                    layout.Parent = list

                    for i, opt in ipairs(options) do
                        local optBtn = Instance.new("TextButton")
                        optBtn.Size = UDim2.new(1, -8, 0, 24)
                        optBtn.Position = UDim2.new(0, 4, 0, (i-1) * 28)
                        optBtn.BackgroundColor3 = theme.Background
                        optBtn.Text = tostring(opt)
                        optBtn.Font = Enum.Font.Gotham
                        optBtn.TextSize = 13
                        optBtn.TextColor3 = theme.Text
                        optBtn.AutoButtonColor = false
                        optBtn.Parent = list

                        local oc = Instance.new("UICorner")
                        oc.CornerRadius = UDim.new(0, 6)
                        oc.Parent = optBtn

                        optBtn.MouseEnter:Connect(function()
                            tween(optBtn, {BackgroundColor3 = theme.TabBackground}, 0.08)
                        end)
                        optBtn.MouseLeave:Connect(function()
                            tween(optBtn, {BackgroundColor3 = theme.Background}, 0.08)
                        end)
                        optBtn.MouseButton1Click:Connect(function()
                            current = opt
                            btn.Text = (name and name .. ": " or "") .. tostring(current)
                            pcall(function() callback(current) end)
                            closeOptions()
                        end)
                    end

                    spawn(function()
                        task.wait(0.03)
                        local s = layout.AbsoluteContentSize
                        optionsFrame.Size = UDim2.new(1, 0, 0, math.min(200, s.Y + 8))
                        list.CanvasSize = UDim2.new(0, 0, 0, s.Y + 4)
                    end)

                    Window._currentOpenDropdown = closeOptions
                end

                btn.MouseButton1Click:Connect(function()
                    if open then closeOptions() else openOptions() end
                end)

                local handle = {
                    Button = btn,
                    Get = function() return current end,
                    Set = function(v) current = v; btn.Text = (name and name .. ": " or "") .. tostring(current); pcall(function() callback(current) end) end,
                    Refresh = function(newOptions)
                        options = newOptions or {}
                        current = options[1] or nil
                        btn.Text = (name and name .. ": " or "") .. (current and tostring(current) or "[Select]")
                        if optionsFrame then optionsFrame:Destroy(); optionsFrame = nil; open = false; if Window._currentOpenDropdown == closeOptions then Window._currentOpenDropdown = nil end end
                    end
                }

                if type(flag) == "string" then
                    Window:RegisterFlag(flag, function() return handle.Get() end, function(v) handle.Set(v) end, "any")
                end

                return handle
            end

            function SectionObj:NewColorpicker(name, defaultColor, callback, flag)
                defaultColor = defaultColor or Color3.fromRGB(255, 120, 0)
                local cur = defaultColor

                local wrap = Instance.new("Frame")
                wrap.Size = UDim2.new(1, 0, 0, 34)
                wrap.BackgroundTransparency = 1
                wrap.Parent = Section

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.BackgroundColor3 = theme.SectionBackground
                btn.AutoButtonColor = false
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.TextColor3 = theme.Text
                btn.Text = (name and name .. " : " or "") .. "[Color]"
                btn.Parent = wrap

                local preview = Instance.new("Frame")
                preview.Size = UDim2.new(0, 24, 0, 24)
                preview.Position = UDim2.new(1, -28, 0.5, -12)
                preview.BackgroundColor3 = cur
                preview.Parent = wrap
                local pc = Instance.new("UICorner")
                pc.CornerRadius = UDim.new(0, 6)
                pc.Parent = preview

                local popup = nil
                local open = false

                local function closePopup()
                    if popup and popup.Parent then popup:Destroy() end
                    popup = nil
                    open = false
                end

                local function createSlider(parent, y, labelText, initial, onChange)
                    local lbl = Instance.new("TextLabel")
                    lbl.Text = labelText
                    lbl.Size = UDim2.new(1, -12, 0, 16)
                    lbl.Position = UDim2.new(0, 8, 0, y)
                    lbl.BackgroundTransparency = 1
                    lbl.TextColor3 = theme.SubText
                    lbl.Font = Enum.Font.Gotham
                    lbl.TextSize = 12
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.Parent = parent

                    local bar = Instance.new("Frame")
                    bar.Size = UDim2.new(1, -12, 0, 10)
                    bar.Position = UDim2.new(0, 8, 0, y + 18)
                    bar.BackgroundColor3 = theme.SectionBackground
                    bar.Parent = parent
                    local barCorner = Instance.new("UICorner")
                    barCorner.CornerRadius = UDim.new(0, 6)
                    barCorner.Parent = bar

                    local fill = Instance.new("Frame")
                    local rel = initial or 0
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    fill.BackgroundColor3 = theme.Accent
                    fill.Parent = bar
                    local fillCorner = Instance.new("UICorner")
                    fillCorner.CornerRadius = UDim.new(0, 6)
                    fillCorner.Parent = fill

                    local knob = Instance.new("Frame")
                    knob.Size = UDim2.new(0, 10, 0, 10)
                    knob.Position = UDim2.new(rel, -5, 0, 0)
                    knob.AnchorPoint = Vector2.new(0, 0)
                    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
                    knob.Parent = bar
                    local kc = Instance.new("UICorner")
                    kc.CornerRadius = UDim.new(0, 6)
                    kc.Parent = knob

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
                        Set = function(v)
                            local rv = math.clamp(v, 0, 1)
                            fill.Size = UDim2.new(rv, 0, 1, 0)
                            knob.Position = UDim2.new(rv, -5, 0, 0)
                        end,
                        Get = function() return fill.Size.X.Scale end
                    }
                end

                btn.MouseButton1Click:Connect(function()
                    if open then closePopup(); return end
                    open = true
                    popup = Instance.new("Frame")
                    popup.Size = UDim2.new(0, 260, 0, 160)
                    popup.BackgroundColor3 = theme.SectionBackground
                    popup.BorderSizePixel = 0
                    popup.Parent = ScreenGui
                    local corner = Instance.new("UICorner", popup)
                    corner.CornerRadius = UDim.new(0, 8)

                    local ap = wrap.AbsolutePosition
                    popup.Position = UDim2.new(0, ap.X + 160, 0, ap.Y + 20)

                    local title = Instance.new("TextLabel")
                    title.Text = name or "Color"
                    title.Size = UDim2.new(1, -12, 0, 18)
                    title.Position = UDim2.new(0, 8, 0, 6)
                    title.BackgroundTransparency = 1
                    title.TextColor3 = theme.SubText
                    title.Font = Enum.Font.GothamBold
                    title.TextSize = 13
                    title.TextXAlignment = Enum.TextXAlignment.Left
                    title.Parent = popup

                    local previewBox = Instance.new("Frame")
                    previewBox.Size = UDim2.new(0, 36, 0, 36)
                    previewBox.Position = UDim2.new(1, -44, 0, 8)
                    previewBox.BackgroundColor3 = cur
                    previewBox.Parent = popup
                    local pc2 = Instance.new("UICorner", previewBox)
                    pc2.CornerRadius = UDim.new(0, 6)

                    local r,g,b = cur.R, cur.G, cur.B

                    local rSlider = createSlider(popup, 34, "R", r, function(rel)
                        r = rel
                        cur = Color3.new(r, g, b)
                        previewBox.BackgroundColor3 = cur
                        pcall(function() callback(cur) end)
                    end)
                    local gSlider = createSlider(popup, 66, "G", g, function(rel)
                        g = rel
                        cur = Color3.new(r, g, b)
                        previewBox.BackgroundColor3 = cur
                        pcall(function() callback(cur) end)
                    end)
                    local bSlider = createSlider(popup, 98, "B", b, function(rel)
                        b = rel
                        cur = Color3.new(r, g, b)
                        previewBox.BackgroundColor3 = cur
                        pcall(function() callback(cur) end)
                    end)

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
                        if type(c) == "table" then
                            local ok = pcall(function()
                                cur = Color3.new(c[1] or c.R, c[2] or c.G, c[3] or c.B)
                            end)
                            if not ok then return end
                        elseif typeof(c) == "Color3" then
                            cur = c
                        end
                        preview.BackgroundColor3 = cur
                        pcall(function() callback(cur) end)
                    end
                }

                if type(flag) == "string" then
                    Window:RegisterFlag(flag, function() return handle.Get() end, function(v) handle.Set(v) end, "Color3")
                end

                return handle
            end

            -- Backwards-compatible aliases
            SectionObj.NewColorPicker = SectionObj.NewColorpicker
            SectionObj.NewTextBox = SectionObj.NewTextbox
            SectionObj.NewKeyBind = SectionObj.NewKeybind

            return SectionObj
        end

        return TabObj
    end

    -- Notification API (unchanged)
    function Window:Notify(title, text, duration, kind)
        duration = (type(duration) == "number" and duration) or 4
        kind = kind or "info"
        local kindKey = tostring(kind):lower()
        if not notifTypeColor[kindKey] then kindKey = "info" end

        NotifGui = ensureNotificationGui()
        NotifHolder = NotifGui:FindFirstChild("_holder")

        local notif = Instance.new("Frame")
        notif.Name = "notification"
        notif.Size = UDim2.new(0, 320, 0, 0)
        notif.BackgroundColor3 = theme.SectionBackground
        notif.BorderSizePixel = 0
        notif.Parent = NotifHolder

        local childCount = 0
        for _,c in ipairs(NotifHolder:GetChildren()) do
            if c:IsA("Frame") and c.Name == "notification" then childCount = childCount + 1 end
        end
        notif.LayoutOrder = childCount + 1

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notif

        local colorBar = Instance.new("Frame")
        colorBar.Size = UDim2.new(0, 6, 1, 0)
        colorBar.Position = UDim2.new(0, 0, 0, 0)
        colorBar.BackgroundColor3 = notifTypeColor[kindKey]()
        colorBar.BorderSizePixel = 0
        colorBar.Parent = notif

        local inner = Instance.new("Frame")
        inner.BackgroundTransparency = 1
        inner.Size = UDim2.new(1, -12, 1, -12)
        inner.Position = UDim2.new(0, 12, 0, 6)
        inner.Parent = notif

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Text = title or ""
        titleLbl.Size = UDim2.new(1, 0, 0, 18)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 14
        titleLbl.TextColor3 = theme.Text
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = inner

        local bodyLbl = Instance.new("TextLabel")
        bodyLbl.Text = text or ""
        bodyLbl.Size = UDim2.new(1, 0, 0, 36)
        bodyLbl.Position = UDim2.new(0, 0, 0, 18)
        bodyLbl.BackgroundTransparency = 1
        bodyLbl.Font = Enum.Font.Gotham
        bodyLbl.TextSize = 13
        bodyLbl.TextColor3 = theme.SubText
        bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
        bodyLbl.TextYAlignment = Enum.TextYAlignment.Top
        bodyLbl.ClipsDescendants = true
        bodyLbl.Parent = inner

        local closeBtn = Instance.new("TextButton")
        closeBtn.Text = "✕"
        closeBtn.Size = UDim2.new(0, 26, 0, 20)
        closeBtn.Position = UDim2.new(1, -26, 0, 6)
        closeBtn.AnchorPoint = Vector2.new(0,0)
        closeBtn.BackgroundTransparency = 1
        closeBtn.Font = Enum.Font.Gotham
        closeBtn.TextSize = 14
        closeBtn.TextColor3 = theme.SubText
        closeBtn.Parent = notif

        tween(notif, {Size = UDim2.new(0, 320, 0, 64)}, 0.18)
        titleLbl.TextTransparency = 1
        bodyLbl.TextTransparency = 1
        tween(titleLbl, {TextTransparency = 0}, 0.18)
        tween(bodyLbl, {TextTransparency = 0}, 0.18)

        local closed = false
        local function closeNow()
            if closed then return end
            closed = true
            tween(titleLbl, {TextTransparency = 1}, 0.12)
            tween(bodyLbl, {TextTransparency = 1}, 0.12)
            tween(notif, {Size = UDim2.new(0, 320, 0, 0)}, 0.15)
            task.delay(0.16, function() if notif and notif.Parent then notif:Destroy() end end)
        end

        closeBtn.MouseButton1Click:Connect(function() closeNow() end)
        notif.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then closeNow() end end)
        if duration > 0 then task.delay(duration, function() pcall(closeNow) end) end

        local obj = {}
        function obj:Close() closeNow() end
        function obj:IsClosed() return closed end
        return obj
    end

    function Window:Notification(opts)
        if type(opts) ~= "table" then return end
        local title = opts.Title or opts.TitleText or opts.title or ""
        local content = opts.Content or opts.Text or opts.content or ""
        local duration = opts.Duration or opts.Time or opts.duration or 4
        local typ = opts.Type or opts.Kind or opts.type or "info"
        return Window:Notify(title, content, duration, typ)
    end

    -- apply initial theme
    Window:SetTheme(themeName or "LightTheme")

    return Window
end

return Kour6anHub
