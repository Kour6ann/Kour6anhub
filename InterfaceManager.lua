local InterfaceManager = {}
InterfaceManager.__index = InterfaceManager

function InterfaceManager.new(library)
    local self = setmetatable({}, InterfaceManager)
    self.Library = library
    self.Folder = "Kour6anHubSettings"
    self.Settings = {
        Theme = "DarkTheme",
        ToggleKey = "RightControl"
    }
    self:LoadSettings()
    self:ApplySettings()
    return self
end

function InterfaceManager:LoadSettings()
    local path = self.Folder .. "/interface.json"
    if isfile(path) then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(path))
        end)
        if success then
            for k, v in pairs(data) do
                self.Settings[k] = v
            end
        end
    end
end

function InterfaceManager:SaveSettings()
    self:BuildFolderTree()
    writefile(self.Folder .. "/interface.json", game:GetService("HttpService"):JSONEncode(self.Settings))
end

function InterfaceManager:ApplySettings()
    self.Library:SetTheme(self.Settings.Theme)
    self.Library:SetToggleKey(Enum.KeyCode[self.Settings.ToggleKey])
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
end

return InterfaceManager
