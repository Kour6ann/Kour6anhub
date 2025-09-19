-- example_usage.lua
-- Example usage file for Kour6anHub.lua
-- Using the raw URL you provided. If the link changes, update RAW_URL accordingly.

local RAW_URL = "https://raw.githubusercontent.com/Kour6ann/Kour6anhub/main/Kour6anhub.lua"
-- (alternate accepted form you shared:
-- "https://raw.githubusercontent.com/Kour6ann/Kour6anhub/refs/heads/main/Kour6anhub.lua")

-- Load the library (wrapped in pcall to avoid runtime errors)
local ok, Library = pcall(function()
    return loadstring(game:HttpGet(RAW_URL))()
end)
if not ok or type(Library) ~= "table" then
    warn("Failed to load Kour6anHub from RAW_URL. Check RAW_URL and hosting.")
    return
end

-- Create a window instance
local Window = Library.New({
    Title = "Kour6anHub - Example",
    Keybind = Enum.KeyCode.P, -- toggle GUI visibility
    Theme = "calm", -- built-in theme name
})

-- Create a tab and a section
local Tab = Window:CreateTab("ESP")
local Section = Tab:CreateSection("Main")

-- Elements examples
Section:CreateToggle("Enable ESP", false, function(state)
    print("[Example] ESP toggled ->", state)
end)

Section:CreateButton("Refresh ESP", function()
    print("[Example] Refresh clicked")
end)

Section:CreateSlider("WalkSpeed", 16, 500, 16, function(val)
    print("[Example] WalkSpeed ->", val)
    pcall(function()
        local plr = game:GetService("Players").LocalPlayer
        if plr and plr.Character and plr.Character:FindFirstChild("Humanoid") then
            plr.Character.Humanoid.WalkSpeed = val
        end
    end)
end)

Section:CreateDropdown("Team", {"Red","Blue","Green"}, "Red", false, function(val)
    print("[Example] Team chose ->", val)
end)

Section:CreateDropdown("Hats", {"Hat1","Hat2","Hat3"}, {"Hat1"}, true, function(selected)
    print("[Example] Hats selection ->")
    for _,v in ipairs(selected) do print("  ", v) end
end)

Section:CreateTextbox("Message", "Enter text...", function(txt)
    print("[Example] Message ->", txt)
end)

Section:CreateKeybind("Fly Key", Enum.KeyCode.F, function(key)
    print("[Example] Fly key pressed ->", key and key.Name or "nil")
end)

Section:CreateColorPicker("ESP Color", Color3.fromRGB(100,150,200), function(col)
    print("[Example] Color chosen ->", col)
end)

-- Save/load settings examples
Window:SaveSettings()
local exported = Window:ExportSettings()
print("[Example] Exported settings snapshot:", exported)

-- Done
print("Kour6anHub example usage loaded. Press P to toggle the GUI.")
