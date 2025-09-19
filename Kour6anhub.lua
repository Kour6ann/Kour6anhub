-- Kour6anHub UI Library (Kavo-compatible API)
-- v4 → patched: tab padding, spacing, alignment, scrolling autosize, returns for controls

local Kour6anHub = {}
Kour6anHub.__index = Kour6anHub

-- Services
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Tween helper
local function tween(obj, props, dur)
    local ti = TweenInfo.new(dur or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, ti, props)
    t:Play()
    return t
end

-- Utility: Dragging (keeps original behavior but safe enough)
local function makeDraggable(frame, dragHandle)
    local dragging, dragStart, startPos
    dragHandle = dragHandle or frame

    -- single InputChanged listener and InputBegan per handle (like original, but okay)
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
        SectionBackground = Color3.fromRGB(255,255,255),
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
    }
}

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
    TabContainer.Position = UDim2.new(0, 0, 0, 40) -- top aligned with content
    TabContainer.BackgroundColor3 = theme.TabBackground
    TabContainer.Parent = Main

    local TabContainerCorner = Instance.new("UICorner")
    TabContainerCorner.CornerRadius = UDim.new(0, 8)
    TabContainerCorner.Parent = TabContainer

    local TabList = Instance.new("UIListLayout")
    TabList.SortOrder = Enum.SortOrder.LayoutOrder
    TabList.Padding = UDim.new(0, 8) -- increased spacing between tabs
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
    Content.Position = UDim2.new(0, 160, 0, 40) -- aligned with TabContainer top
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local Tabs = {}

    local Window = {}

    function Window:NewTab(tabName)
        -- Tab button
        local TabButton = Instance.new("TextButton")
        TabButton.Text = tabName
        TabButton.Size = UDim2.new(1, -20, 0, 40) -- fixed height; inner padding controls breathing room
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

        -- Hover + press animations
        TabButton.MouseEnter:Connect(function()
            tween(TabButton, {BackgroundColor3 = theme.Background, Size = UDim2.new(1, -16, 0, 42)}, 0.1)
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

        -- autosize canvas using AbsoluteContentSize
        TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local s = TabLayout.AbsoluteContentSize
            TabFrame.CanvasSize = UDim2.new(0, 0, 0, s.Y + 8)
        end)

        -- clicking tab: hide others, show this one, mark active
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

            -- Section API
            local SectionObj = {}

            function SectionObj:NewButton(text, desc, callback)
                local Btn = Instance.new("TextButton")
                Btn.Text = text
                Btn.Size = UDim2.new(1, 0, 0, 34)
                Btn.BackgroundColor3 = theme.Background
                Btn.TextColor3 = theme.Text
                Btn.Font = Enum.Font.Gotham
                Btn.TextSize = 14
                Btn.AutoButtonColor = false
                Btn.Parent = Section

                local BtnCorner = Instance.new("UICorner")
                BtnCorner.CornerRadius = UDim.new(0, 6)
                BtnCorner.Parent = Btn

                -- Hover
                Btn.MouseEnter:Connect(function()
                    tween(Btn, {BackgroundColor3 = theme.TabBackground, Size = UDim2.new(1, -6, 0, 36)}, 0.08)
                end)
                Btn.MouseLeave:Connect(function()
                    tween(Btn, {BackgroundColor3 = theme.Background, Size = UDim2.new(1, 0, 0, 34)}, 0.08)
                end)

                -- Click
                Btn.MouseButton1Click:Connect(function()
                    tween(Btn, {BackgroundColor3 = theme.Accent, Size = UDim2.new(1, -8, 0, 32)}, 0.08)
                    task.wait(0.09)
                    tween(Btn, {BackgroundColor3 = theme.Background, Size = UDim2.new(1, 0, 0, 34)}, 0.12)
                    pcall(function() callback() end)
                end)

                -- return the button instance so scripts can hook events / change properties
                return Btn
            end

            function SectionObj:NewToggle(text, desc, callback)
                local ToggleBtn = Instance.new("TextButton")
                ToggleBtn.Text = text .. " [OFF]"
                ToggleBtn.Size = UDim2.new(1, 0, 0, 34)
                ToggleBtn.BackgroundColor3 = theme.Background
                ToggleBtn.TextColor3 = theme.Text
                ToggleBtn.Font = Enum.Font.Gotham
                ToggleBtn.TextSize = 14
                ToggleBtn.AutoButtonColor = false
                ToggleBtn.Parent = Section

                local ToggleCorner = Instance.new("UICorner")
                ToggleCorner.CornerRadius = UDim.new(0, 6)
                ToggleCorner.Parent = ToggleBtn

                local state = false

                -- Hover
                ToggleBtn.MouseEnter:Connect(function()
                    tween(ToggleBtn, {BackgroundColor3 = theme.TabBackground, Size = UDim2.new(1, -6, 0, 36)}, 0.08)
                end)
                ToggleBtn.MouseLeave:Connect(function()
                    local bg = state and theme.Accent or theme.Background
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
                        ToggleBtn.BackgroundColor3 = theme.Background
                        ToggleBtn.TextColor3 = theme.Text
                    end
                    pcall(function() callback(state) end)
                end)

                -- return a handle with convenience methods
                return {
                    Button = ToggleBtn,
                    GetState = function() return state end,
                    SetState = function(v)
                        state = not not v
                        ToggleBtn.Text = text .. (state and " [ON]" or " [OFF]")
                        ToggleBtn.BackgroundColor3 = state and theme.Accent or theme.Background
                        ToggleBtn.TextColor3 = state and Color3.fromRGB(255,255,255) or theme.Text
                    end
                }
            end

            return SectionObj
        end

        return TabObj
    end

    return Window
end

return Kour6anHub
