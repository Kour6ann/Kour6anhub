local InterfaceManager = {}
InterfaceManager.__index = InterfaceManager

-- Simple signal implementation
local function Signal()
    local self = {}
    self._listeners = {}

    function self:Connect(callback)
        local connection = {
            Connected = true,
            Disconnect = function()
                connection.Connected = false
                for i, conn in ipairs(self._listeners) do
                    if conn == connection then
                        table.remove(self._listeners, i)
                        break
                    end
                end
            end
        }
        
        connection.Callback = callback
        table.insert(self._listeners, connection)
        return connection
    end

    function self:Fire(...)
        for _, connection in ipairs(self._listeners) do
            if connection.Connected then
                task.spawn(connection.Callback, ...)
            end
        end
    end

    function self:Wait()
        local thread = coroutine.running()
        local connection
        connection = self:Connect(function(...)
            connection:Disconnect()
            coroutine.resume(thread, ...)
        end)
        return coroutine.yield()
    end

    return self
end

function InterfaceManager.new()
    local self = setmetatable({}, InterfaceManager)
    self.Folder = "Kour6anHubSettings" -- Default folder
    self.Settings = {
        Theme = "DarkTheme",
        ToggleKey = "RightControl"
    }
    self.SettingsChanged = Signal()
    return self
end

-- Setup methods following Fluent pattern
function InterfaceManager:SetLibrary(library)
    self.Library = library
end

function InterfaceManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
    self:LoadSettings()
    self:ApplySettings()
end

function InterfaceManager:LoadSettings()
    local path = self.Folder .. "/interface.json"
    
    if isfile(path) then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(path))
        end)
        
        if success and type(data) == "table" then
            -- Completely reset settings if they're corrupted
            local needsReset = false
            
            -- Check if theme is a table (corrupted)
            if data.Theme and type(data.Theme) == "table" then
                needsReset = true
                print("Theme is corrupted (table), resetting settings")
            end
            
            -- Check if toggle key is a table (corrupted)
            if data.ToggleKey and type(data.ToggleKey) == "table" then
                needsReset = true
                print("ToggleKey is corrupted (table), resetting settings")
            end
            
            if needsReset then
                -- Delete the corrupted file and use defaults
                delfile(path)
                self.Settings = {
                    Theme = "DarkTheme",
                    ToggleKey = "RightControl"
                }
                return
            end
            
            -- Only update settings that exist and are of the correct type
            for k, v in pairs(data) do
                if self.Settings[k] ~= nil and type(v) == type(self.Settings[k]) then
                    self.Settings[k] = v
                end
            end
        else
            -- If JSON is corrupted, delete the file
            if isfile(path) then
                delfile(path)
            end
        end
    end
end

function InterfaceManager:SaveSettings()
    self:BuildFolderTree()
    writefile(self.Folder .. "/interface.json", game:GetService("HttpService"):JSONEncode(self.Settings))
    self.SettingsChanged:Fire(self.Settings)
end

function InterfaceManager:ApplySettings()
    if self.Library then
        -- Ensure Theme is a string
        if type(self.Settings.Theme) ~= "string" then
            self.Settings.Theme = "DarkTheme"
        end
        
        -- Apply theme
        local success, err = pcall(function()
            self.Library:SetTheme(self.Settings.Theme)
        end)
        
        if not success then
            -- If theme setting is invalid, reset to default
            self.Settings.Theme = "DarkTheme"
            self.Library:SetTheme("DarkTheme")
            self:SaveSettings()
        end
        
        -- Safe keycode application with fallback
        if type(self.Settings.ToggleKey) ~= "string" then
            self.Settings.ToggleKey = "RightControl"
        end
        
        local keyCode = Enum.KeyCode[self.Settings.ToggleKey]
        if keyCode then
            self.Library:SetToggleKey(keyCode)
        else
            -- Fallback to default key if saved key is invalid
            self.Settings.ToggleKey = "RightControl"
            self.Library:SetToggleKey(Enum.KeyCode.RightControl)
            self:SaveSettings()
        end
    end
end

function InterfaceManager:BuildFolderTree()
    if not isfolder(self.Folder) then
        makefolder(self.Folder)
    end
end

function InterfaceManager:BuildInterfaceSection(tab)
    -- Create a section first
    local section = tab:NewSection("UI Settings")
    
    -- Theme selector
    local themes = self.Library:GetThemeList()
    local themeDropdown = section:NewDropdown("Theme", themes, function(selected)
        self.Settings.Theme = selected
        self.Library:SetTheme(selected)
        self:SaveSettings()
    end)
    themeDropdown:Set(self.Settings.Theme)
    
    -- Toggle key selector
    local keyNames = {}
    for _, key in ipairs(Enum.KeyCode:GetEnumItems()) do
        if key.Name ~= "Unknown" then
            table.insert(keyNames, key.Name)
        end
    end
    table.sort(keyNames)
    
    local keyDropdown = section:NewDropdown("Toggle Key", keyNames, function(selected)
        self.Settings.ToggleKey = selected
        self.Library:SetToggleKey(Enum.KeyCode[selected])
        self:SaveSettings()
    end)
    keyDropdown:Set(self.Settings.ToggleKey)
    
    -- UI Scale slider
    section:NewSlider("UI Scale", 0.5, 1.5, 1, function(value)
        self.Library.Main.Size = UDim2.new(0, 600 * value, 0, 400 * value)
        self.Library.Main.Position = UDim2.new(0.5, -300 * value, 0.5, -200 * value)
    end)
end

return InterfaceManager
