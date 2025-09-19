-- Kour6anHub.lua - Clean Modern Light UI Library
-- Single-file UI library, loadable via loadstring

local Kour6anHub = {}
Kour6anHub.__index = Kour6anHub

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Colors & Styles
local colors = {
    background = Color3.fromRGB(245, 245, 245),
    panel = Color3.fromRGB(255, 255, 255),
    tabDefault = Color3.fromRGB(200, 200, 200),
    tabHover = Color3.fromRGB(180, 180, 180),
    tabActive = Color3.fromRGB(150, 150, 150),
    text = Color3.fromRGB(25, 25, 25),
    button = Color3.fromRGB(210, 210, 210),
    buttonHover = Color3.fromRGB(190, 190, 190),
    buttonPress = Color3.fromRGB(170, 170, 170)
}

-- Core GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Kour6anHub"
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 550, 0, 350)
mainFrame.Position = UDim2.new(0.5, -275, 0.5, -175)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = colors.background
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

-- Vertical Tab Bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(0, 140, 1, -20)
tabBar.Position = UDim2.new(0, 10, 0, 10)
tabBar.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame
local tabBarCorner = Instance.new("UICorner")
tabBarCorner.CornerRadius = UDim.new(0, 8)
tabBarCorner.Parent = tabBar

-- Content Area
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -160, 1, -20)
contentFrame.Position = UDim2.new(0, 150, 0, 10)
contentFrame.BackgroundColor3 = colors.panel
contentFrame.BorderSizePixel = 0
contentFrame.Parent = mainFrame
local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 8)
contentCorner.Parent = contentFrame

-- Tab System
Kour6anHub.tabs = {}
local currentTab = nil
local tabSpacing = 8
local tabHeight = 40

function Kour6anHub:CreateTab(tabName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, tabHeight)
    btn.Position = UDim2.new(0, 10, 0, (#self.tabs)*(tabHeight + tabSpacing) + 10)
    btn.BackgroundColor3 = colors.tabDefault
    btn.TextColor3 = colors.text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 16
    btn.Text = tabName
    btn.Parent = tabBar
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    -- Hover + press animations
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = colors.tabHover
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = (currentTab == tabName) and colors.tabActive or colors.tabDefault
    end)
    btn.MouseButton1Click:Connect(function()
        currentTab = tabName
        for _, b in pairs(self.tabs) do
            b.Button.BackgroundColor3 = (b.Name == tabName) and colors.tabActive or colors.tabDefault
        end
    end)

    table.insert(self.tabs, {Name = tabName, Button = btn, Content = {}})
    return self
end

function Kour6anHub:AddButton(tabName, text, callback)
    local tab = nil
    for _, t in pairs(self.tabs) do
        if t.Name == tabName then
            tab = t
            break
        end
    end
    if not tab then return end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 35)
    btn.Position = UDim2.new(0, 10, 0, 10 + (#tab.Content)*(35 + 6))
    btn.BackgroundColor3 = colors.button
    btn.TextColor3 = colors.text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Text = text
    btn.Parent = contentFrame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = colors.buttonHover
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = colors.button
    end)
    btn.MouseButton1Click:Connect(function()
        btn.BackgroundColor3 = colors.buttonPress
        task.wait(0.1)
        btn.BackgroundColor3 = colors.button
        if callback then
            callback()
        end
    end)

    table.insert(tab.Content, btn)
end

return Kour6anHub
