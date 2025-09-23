-- example.lua
-- Kour6anHub — Full usage example
local Kour6anHub = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kour6ann/Kour6anhub/refs/heads/main/Kour6anhub.lua"))()
-- Create the main window
-- API: CreateLib(title, defaultThemeName)
local Window = Kour6anHub.CreateLib("Kour6anHub Example", "Neon")

-- Optional: change the key used to toggle the whole UI (default may be RightControl)
-- Example sets it to F1
if Window.SetToggleKey then
    Window:SetToggleKey(Enum.KeyCode.F1)
end

-- Make two tabs: "Main" and "Settings"
local mainTab = Window:NewTab("Main")
local settingsTab = Window:NewTab("Settings")

-- Add a section to the Main tab
local mainSection = mainTab:NewSection("Core Controls")

-- 1) Label (static text)
mainSection:NewLabel("Welcome — this example shows every widget from the library.")

-- 2) Button: (text, description, callback)
mainSection:NewButton("Print Greeting", "Logs a greeting and shows a notification", function()
    print("[Kour6anHub] Hello from the example button!")
    if Window.Notify then Window:Notify("Greeting", "Hello — button pressed!", 3) end
end)

-- 3) Toggle: (text, desc, callback(boolean))
-- Keep a reference to the toggle so we can programmatically change it later
local godToggle = mainSection:NewToggle("God Mode", "Example toggle", function(state)
    print("God Mode toggled:", state)
    if Window.Notify then Window:Notify("God Mode", state and "Enabled" or "Disabled", 2) end
end)

-- 4) Slider: (text, min, max, default, callback(number))
local speedSlider = mainSection:NewSlider("Speed", 1, 300, 100, function(value)
    -- slider sends numeric values; round if you prefer integers
    local v = math.floor(value)
    print("Speed slider:", v)
end)

-- 5) Textbox: (placeholder, defaultText, callback(text))
local nameBox = mainSection:NewTextbox("Enter your name...", "", function(text)
    print("Name textbox changed:", text)
    if Window.Notify then Window:Notify("Name", tostring(text), 2) end
end)

-- 6) Keybind: (description, defaultKeyEnum, callback)
-- Demonstrates binding a function to a key (fires when that key is pressed)
mainSection:NewKeybind("Example Keybind (F2)", Enum.KeyCode.F2, function()
    print("Example keybind triggered (F2).")
    if Window.Notify then Window:Notify("Keybind", "F2 keybind triggered", 2) end
end)

-- 7) Dropdown: (label, optionsTable, callback(selectedString))
local dd = mainSection:NewDropdown("Pick an option", {"Alpha", "Bravo", "Charlie"}, function(choice)
    print("Dropdown choice:", choice)
    if Window.Notify then Window:Notify("Dropdown", tostring(choice), 2) end
end)

-- 8) Colorpicker: (label, defaultColor3, callback(Color3))
mainSection:NewColorpicker("Accent Color", Color3.fromRGB(0,160,255), function(col)
    -- col is a Color3 object
    print("Color picked:", math.floor(col.R*255), math.floor(col.G*255), math.floor(col.B*255))
    if Window.Notify then Window:Notify("Colorpicker", "Accent color changed", 2) end
end)

-- 9) Another label showing how to query theme list and switch themes
mainSection:NewButton("Show available themes (console)", nil, function()
    if Window.GetThemeList then
        local themes = Window:GetThemeList()
        print("Available themes:", table.concat(themes, ", "))
        if Window.Notify then Window:Notify("Themes", "See console for theme list", 2) end
    end
end)

mainSection:NewButton("Switch to DarkTheme (if available)", nil, function()
    if Window.SetTheme then
        Window:SetTheme("DarkTheme") -- no-op if theme not found
        if Window.Notify then Window:Notify("Theme", "Requested DarkTheme", 2) end
    end
end)

-- ===== Settings tab: window controls and cleanup =====
local settingsSection = settingsTab:NewSection("Window & Cleanup")

settingsSection:NewLabel("Window state controls (minimize, hide, destroy)")

settingsSection:NewButton("Minimize Window", nil, function()
    if Window.Minimize then Window:Minimize() end
end)

settingsSection:NewButton("Restore Window", nil, function()
    if Window.Restore then Window:Restore() end
end)

settingsSection:NewButton("Hide UI", nil, function()
    if Window.Hide then Window:Hide() end
end)

settingsSection:NewButton("Show UI", nil, function()
    if Window.Show then Window:Show() end
end)

settingsSection:NewButton("Send test notification", nil, function()
    if Window.Notify then Window:Notify("Test", "This is a test notification", 4) end
end)

-- Destroy (final): cleans up UI and most connections.
-- Use carefully in your published example (it's useful to demonstrate cleanup).
settingsSection:NewButton("Destroy UI (final)", "Removes the UI and attempts to disconnect internal connections", function()
    if Window.Destroy then
        Window:Destroy()
        print("[Kour6anHub Example] Window destroyed.")
    else
        warn("Destroy method not found on Window.")
    end
end)

-- ===== Programmatic examples (useful for advanced users) =====
-- Programmatically set widget states if the returned widget exposes setters.
task.delay(1, function()
    -- Toggle ON
    if godToggle and type(godToggle) == "table" and godToggle.SetState then
        pcall(function() godToggle.SetState(true) end)
    end

    -- Set slider value (if API supports it)
    if speedSlider and type(speedSlider) == "table" and speedSlider.Set then
        pcall(function() speedSlider.Set(180) end)
    end

    -- Set textbox text programmatically (if API supports it)
    if nameBox and type(nameBox) == "table" and nameBox.Set then
        pcall(function() nameBox.Set("Kour6anUser") end)
    end
end)

-- Example: change global toggle key after creation
task.delay(2, function()
    if Window.SetToggleKey then
        Window:SetToggleKey(Enum.KeyCode.LeftAlt) -- LeftAlt now toggles UI visibility
        print("[Kour6anHub Example] Toggle key set to LeftAlt.")
    end
end)

-- Final console message so users know the example loaded
print("[Kour6anHub Example] Loaded successfully. Press F1 (or LeftAlt after delay) to toggle the UI.")
