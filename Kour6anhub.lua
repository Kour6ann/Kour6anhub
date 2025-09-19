-- Kour6anHub UI Library (Modern Rebuild)
-- Minimal API (Window → Tab → Section → Button/Toggle)
-- Kavo-compatible: CreateLib, NewTab, NewSection, NewButton, NewToggle

local Kour6anHub = {}
Kour6anHub.__index = Kour6anHub

-- Services
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

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

-- Themes (extendable)
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

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Kour6anHub"
    ScreenGui.Parent = CoreGui

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 600, 0, 400)
    Main.Position = UDim2.new(0.5, -300, 0.5, -200)
    Main.BackgroundColor3 = theme.Background
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = Main

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

    -- Tab container
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
    TabList.Padding = UDim.new(0, 5)
    TabList.Parent = TabContainer

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -160, 1, -50)
    Content.Position = UDim2.new(0, 160, 0, 50)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local Tabs = {}

    local Window = {}
    function Window:NewTab(tabName)
        local TabButton = Instance.new("TextButton")
        TabButton.Text = tabName
        TabButton.Size = UDim2.new(1, -10, 0, 35)
        TabButton.Position = UDim2.new(0, 5, 0, 0)
        TabButton.BackgroundColor3 = theme.SectionBackground
        TabButton.TextColor3 = theme.Text
        TabButton.Font = Enum.Font.Gotham
        TabButton.TextSize = 14
        TabButton.Parent = TabContainer

        local TabButtonCorner = Instance.new("UICorner")
        TabButtonCorner.CornerRadius = UDim.new(0, 6)
        TabButtonCorner.Parent = TabButton

        local TabFrame = Instance.new("ScrollingFrame")
        TabFrame.Size = UDim2.new(1, 0, 1, 0)
        TabFrame.CanvasSize = UDim2.new(0,0,0,0)
        TabFrame.ScrollBarThickness = 4
        TabFrame.BackgroundTransparency = 1
        TabFrame.Visible = false
        TabFrame.Parent = Content

        local TabLayout = Instance.new("UIListLayout")
        TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        TabLayout.Padding = UDim.new(0, 8)
        TabLayout.Parent = TabFrame

        local UIPadding = Instance.new("UIPadding")
        UIPadding.PaddingTop = UDim.new(0, 8)
        UIPadding.PaddingLeft = UDim.new(0, 8)
        UIPadding.PaddingRight = UDim.new(0, 8)
        UIPadding.Parent = TabFrame

        TabButton.MouseButton1Click:Connect(function()
            for _, tab in ipairs(Tabs) do
                tab.Frame.Visible = false
            end
            TabFrame.Visible = true
        end)

        table.insert(Tabs, {Button = TabButton, Frame = TabFrame})

        local TabObj = {}
        function TabObj:NewSection(sectionName)
            local Section = Instance.new("Frame")
            Section.Size = UDim2.new(1, -10, 0, 50)
            Section.BackgroundColor3 = theme.SectionBackground
            Section.Parent = TabFrame
            Section.AutomaticSize = Enum.AutomaticSize.Y

            local SectionCorner = Instance.new("UICorner")
            SectionCorner.CornerRadius = UDim.new(0, 6)
            SectionCorner.Parent = Section

            local SectionLayout = Instance.new("UIListLayout")
            SectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
            SectionLayout.Padding = UDim.new(0, 6)
            SectionLayout.Parent = Section

            local SectionPadding = Instance.new("UIPadding")
            SectionPadding.PaddingTop = UDim.new(0, 6)
            SectionPadding.PaddingBottom = UDim.new(0, 6)
            SectionPadding.PaddingLeft = UDim.new(0, 6)
            SectionPadding.PaddingRight = UDim.new(0, 6)
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

            function SectionObj:NewButton(text, desc, callback)
                local Btn = Instance.new("TextButton")
                Btn.Text = text
                Btn.Size = UDim2.new(1, 0, 0, 30)
                Btn.BackgroundColor3 = theme.Background
                Btn.TextColor3 = theme.Text
                Btn.Font = Enum.Font.Gotham
                Btn.TextSize = 14
                Btn.AutoButtonColor = false
                Btn.Parent = Section

                local BtnCorner = Instance.new("UICorner")
                BtnCorner.CornerRadius = UDim.new(0, 6)
                BtnCorner.Parent = Btn

                Btn.MouseEnter:Connect(function()
                    Btn.BackgroundColor3 = theme.TabBackground
                end)
                Btn.MouseLeave:Connect(function()
                    Btn.BackgroundColor3 = theme.Background
                end)
                Btn.MouseButton1Click:Connect(function()
                    pcall(callback)
                end)
            end

            function SectionObj:NewToggle(text, desc, callback)
                local Toggle = Instance.new("TextButton")
                Toggle.Text = text .. " [OFF]"
                Toggle.Size = UDim2.new(1, 0, 0, 30)
                Toggle.BackgroundColor3 = theme.Background
                Toggle.TextColor3 = theme.Text
                Toggle.Font = Enum.Font.Gotham
                Toggle.TextSize = 14
                Toggle.AutoButtonColor = false
                Toggle.Parent = Section

                local ToggleCorner = Instance.new("UICorner")
                ToggleCorner.CornerRadius = UDim.new(0, 6)
                ToggleCorner.Parent = Toggle

                local state = false
                Toggle.MouseButton1Click:Connect(function()
                    state = not state
                    Toggle.Text = text .. (state and " [ON]" or " [OFF]")
                    if state then
                        Toggle.BackgroundColor3 = theme.Accent
                        Toggle.TextColor3 = Color3.fromRGB(255,255,255)
                    else
                        Toggle.BackgroundColor3 = theme.Background
                        Toggle.TextColor3 = theme.Text
                    end
                    pcall(callback, state)
                end)
            end

            return SectionObj
        end

        return TabObj
    end

    return Window
end

return Kour6anHub
