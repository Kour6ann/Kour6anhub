-- Kour6anHub UI Library (Minimal Base) - Rebuild of Kavo API
-- Clean padding, spacing, white outlines, rounded corners
-- One file, no dependencies

local Kour6anHub = {}

-- Services
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

-- Utility: Drag function
local function makeDraggable(frame, dragHandle)
    local dragging, dragInput, mousePos, framePos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            frame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Theme colors
local Themes = {
    DarkTheme = {
        Background = Color3.fromRGB(25, 25, 25),
        Section = Color3.fromRGB(35, 35, 35),
        Outline = Color3.fromRGB(255, 255, 255),
        Text = Color3.fromRGB(255, 255, 255),
        Accent = Color3.fromRGB(0, 170, 255),
    }
}

-- CreateLib (Main entry)
function Kour6anHub.CreateLib(title, themeName)
    local theme = Themes[themeName] or Themes.DarkTheme

    -- ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "Kour6anHubUI"
    gui.Parent = CoreGui
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Main Window
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 600, 0, 400)
    main.Position = UDim2.new(0.5, -300, 0.5, -200)
    main.BackgroundColor3 = theme.Background
    main.BorderSizePixel = 0
    main.Parent = gui

    local outline = Instance.new("UIStroke", main)
    outline.Thickness = 2
    outline.Color = theme.Outline

    local corner = Instance.new("UICorner", main)
    corner.CornerRadius = UDim.new(0, 10)

    -- TopBar
    local topbar = Instance.new("Frame")
    topbar.Size = UDim2.new(1, 0, 0, 40)
    topbar.BackgroundColor3 = theme.Section
    topbar.BorderSizePixel = 0
    topbar.Parent = main
    Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 10)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -10, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = theme.Text
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = topbar

    makeDraggable(main, topbar)

    -- Tab Buttons Frame
    local tabButtons = Instance.new("Frame")
    tabButtons.Size = UDim2.new(0, 120, 1, -40)
    tabButtons.Position = UDim2.new(0, 0, 0, 40)
    tabButtons.BackgroundColor3 = theme.Section
    tabButtons.BorderSizePixel = 0
    tabButtons.Parent = main

    local tabButtonsLayout = Instance.new("UIListLayout", tabButtons)
    tabButtonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabButtonsLayout.Padding = UDim.new(0, 5)

    -- Pages Frame
    local pages = Instance.new("Frame")
    pages.Size = UDim2.new(1, -120, 1, -40)
    pages.Position = UDim2.new(0, 120, 0, 40)
    pages.BackgroundColor3 = theme.Background
    pages.BorderSizePixel = 0
    pages.Parent = main

    local pageContainer = Instance.new("Folder", pages)

    -- Window API
    local Window = {}

    function Window:NewTab(tabName)
        local tab = {}

        -- Tab Button
        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.new(1, -10, 0, 30)
        tabBtn.Position = UDim2.new(0, 5, 0, 0)
        tabBtn.BackgroundColor3 = theme.Background
        tabBtn.Text = tabName
        tabBtn.TextColor3 = theme.Text
        tabBtn.Font = Enum.Font.Gotham
        tabBtn.TextSize = 14
        tabBtn.Parent = tabButtons

        local tabCorner = Instance.new("UICorner", tabBtn)
        tabCorner.CornerRadius = UDim.new(0, 6)

        local tabStroke = Instance.new("UIStroke", tabBtn)
        tabStroke.Thickness = 1
        tabStroke.Color = theme.Outline

        -- Tab Page
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.Visible = false
        page.Parent = pageContainer

        local pageLayout = Instance.new("UIListLayout", page)
        pageLayout.Padding = UDim.new(0, 10)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder

        -- Tab Switching
        tabBtn.MouseButton1Click:Connect(function()
            for _, pg in ipairs(pageContainer:GetChildren()) do
                if pg:IsA("ScrollingFrame") then
                    pg.Visible = false
                end
            end
            page.Visible = true
        end)

        -- Section API
        function tab:NewSection(sectionName)
            local section = {}

            local secFrame = Instance.new("Frame")
            secFrame.Size = UDim2.new(1, -10, 0, 60)
            secFrame.BackgroundColor3 = theme.Section
            secFrame.BorderSizePixel = 0
            secFrame.Parent = page

            local secCorner = Instance.new("UICorner", secFrame)
            secCorner.CornerRadius = UDim.new(0, 8)

            local secStroke = Instance.new("UIStroke", secFrame)
            secStroke.Thickness = 1
            secStroke.Color = theme.Outline

            local secLabel = Instance.new("TextLabel")
            secLabel.Size = UDim2.new(1, -10, 0, 20)
            secLabel.Position = UDim2.new(0, 10, 0, 5)
            secLabel.BackgroundTransparency = 1
            secLabel.Text = sectionName
            secLabel.TextColor3 = theme.Accent
            secLabel.TextSize = 14
            secLabel.Font = Enum.Font.GothamBold
            secLabel.TextXAlignment = Enum.TextXAlignment.Left
            secLabel.Parent = secFrame

            -- Section Layout
            local secLayout = Instance.new("UIListLayout", secFrame)
            secLayout.Padding = UDim.new(0, 5)
            secLayout.SortOrder = Enum.SortOrder.LayoutOrder

            -- Section API
            function section:NewButton(text, desc, callback)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -20, 0, 30)
                btn.Position = UDim2.new(0, 10, 0, 25)
                btn.BackgroundColor3 = theme.Background
                btn.Text = text
                btn.TextColor3 = theme.Text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 14
                btn.Parent = secFrame

                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                local stroke = Instance.new("UIStroke", btn)
                stroke.Thickness = 1
                stroke.Color = theme.Outline

                btn.MouseButton1Click:Connect(function()
                    if callback then callback() end
                end)
            end

            function section:NewToggle(text, desc, callback)
                local toggled = false

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -20, 0, 30)
                btn.Position = UDim2.new(0, 10, 0, 25)
                btn.BackgroundColor3 = theme.Background
                btn.Text = text .. ": OFF"
                btn.TextColor3 = theme.Text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 14
                btn.Parent = secFrame

                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                local stroke = Instance.new("UIStroke", btn)
                stroke.Thickness = 1
                stroke.Color = theme.Outline

                btn.MouseButton1Click:Connect(function()
                    toggled = not toggled
                    btn.Text = text .. (toggled and ": ON" or ": OFF")
                    if callback then callback(toggled) end
                end)
            end

            return section
        end

        return tab
    end

    return Window
end

return Kour6anHub
