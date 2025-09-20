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
            for k, v in pairs(data) do
                if self.Settings[k] ~= nil then
                    self.Settings[k] = v
                end
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
        if type(self.Settings.Theme) == "string" then
            self.Library:SetTheme(self.Settings.Theme)
        else
            -- Fallback to default theme if invalid
            self.Settings.Theme = "DarkTheme"
            self.Library:SetTheme("DarkTheme")
            self:SaveSettings()
        end
        
        -- Safe keycode application with fallback
        if type(self.Settings.ToggleKey) == "string" then
            local keyCode = Enum.KeyCode[self.Settings.ToggleKey]
            if keyCode then
                self.Library:SetToggleKey(keyCode)
            else
                -- Fallback to default key if saved key is invalid
                self.Settings.ToggleKey = "RightControl"
                self.Library:SetToggleKey(Enum.KeyCode.RightControl)
                self:SaveSettings()
            end
        else
            -- Fallback to default key if invalid type
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

function InterfaceManager:BuildInterfaceSection(section)
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
