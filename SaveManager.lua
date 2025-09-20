local SaveManager = {}
SaveManager.__index = SaveManager

function SaveManager.new(library)
    local self = setmetatable({}, SaveManager)
    self.Library = library
    self.Folder = "Kour6anHubSettings"
    self.Options = {}
    self.Ignore = {}
    self.Parser = {
        Toggle = {
            Save = function(idx, object) 
                return { type = "Toggle", idx = idx, value = object:GetState() } 
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:SetState(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = "Slider", idx = idx, value = object:Get() }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:Set(data.value)
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = "Dropdown", idx = idx, value = object:Get() }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:Set(data.value)
                end
            end,
        },
        Colorpicker = {
            Save = function(idx, object)
                local color = object:Get()
                return { type = "Colorpicker", idx = idx, value = {color.R, color.G, color.B} }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:Set(Color3.new(data.value[1], data.value[2], data.value[3]))
                end
            end,
        },
        Keybind = {
            Save = function(idx, object)
                return { type = "Keybind", idx = idx, key = object:GetKey().Name }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:SetKey(Enum.KeyCode[data.key])
                end
            end,
        },
        Textbox = {
            Save = function(idx, object)
                return { type = "Textbox", idx = idx, value = object:Get() }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:Set(data.value)
                end
            end,
        }
    }
    self:BuildFolderTree()
    return self
end

function SaveManager:SetIgnoreIndexes(list)
    for _, key in ipairs(list) do
        self.Ignore[key] = true
    end
end

function SaveManager:Save(name)
    if not name or name == "" then return false, "No config name provided" end
    
    local data = {
        objects = {}
    }
    
    for idx, option in pairs(self.Options) do
        if self.Ignore[idx] then continue end
        if self.Parser[option.Type] then
            table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        end
    end
    
    local json = game:GetService("HttpService"):JSONEncode(data)
    writefile(self.Folder .. "/" .. name .. ".json", json)
    return true
end

function SaveManager:Load(name)
    if not name then return false, "No config name provided" end
    
    local path = self.Folder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "Config file doesn't exist" end
    
    local success, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(path))
    end)
    
    if not success then return false, "Failed to parse config" end
    
    for _, optionData in ipairs(data.objects) do
        if self.Parser[optionData.type] then
            self.Parser[optionData.type].Load(optionData.idx, optionData)
        end
    end
    
    return true
end

function SaveManager:Delete(name)
    if not name then return false, "No config name provided" end
    
    local path = self.Folder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "Config file doesn't exist" end
    
    delfile(path)
    return true
end

function SaveManager:BuildFolderTree()
    if not isfolder(self.Folder) then
        makefolder(self.Folder)
    end
end

function SaveManager:GetConfigList()
    local configs = {}
    if isfolder(self.Folder) then
        for _, file in ipairs(listfiles(self.Folder)) do
            if file:sub(-5) == ".json" then
                local name = file:match("([^/]+)%.json$")
                if name ~= "interface" then
                    table.insert(configs, name)
                end
            end
        end
    end
    return configs
end

function SaveManager:SetAutoload(name)
    if not name then 
        if isfile(self.Folder .. "/autoload.txt") then
            delfile(self.Folder .. "/autoload.txt")
        end
        return
    end
    
    writefile(self.Folder .. "/autoload.txt", name)
end

function SaveManager:GetAutoload()
    if isfile(self.Folder .. "/autoload.txt") then
        return readfile(self.Folder .. "/autoload.txt")
    end
    return nil
end

function SaveManager:LoadAutoload()
    local autoload = self:GetAutoload()
    if autoload then
        return self:Load(autoload)
    end
    return false, "No autoload config set"
end

function SaveManager:BuildConfigSection(tab)
    local section = tab:NewSection("Configuration")
    
    -- Config name input
    local configNameInput = section:NewTextbox("Config Name", "", function() end)
    self.Options["ConfigNameInput"] = {
        Type = "Textbox",
        Get = configNameInput.Get,
        Set = configNameInput.Set
    }
    
    -- Config list dropdown
    local configList = self:GetConfigList()
    local configDropdown = section:NewDropdown("Config List", configList, function(selected)
        configNameInput:Set(selected)
    end)
    self.Options["ConfigDropdown"] = {
        Type = "Dropdown",
        Get = configDropdown.Get,
        Set = configDropdown.Set,
        Refresh = configDropdown.Refresh
    }
    
    -- Save button
    section:NewButton("Save Config", function()
        local name = configNameInput:Get()
        if name == "" then
            self.Library:Notify("Error", "Please enter a config name")
            return
        end
        
        local success, err = self:Save(name)
        if success then
            self.Library:Notify("Success", "Config saved: " .. name)
            configDropdown:Refresh(self:GetConfigList())
        else
            self.Library:Notify("Error", "Failed to save: " .. tostring(err))
        end
    end)
    
    -- Load button
    section:NewButton("Load Config", function()
        local name = configNameInput:Get()
        if name == "" then
            self.Library:Notify("Error", "Please select a config")
            return
        end
        
        local success, err = self:Load(name)
        if success then
            self.Library:Notify("Success", "Config loaded: " .. name)
        else
            self.Library:Notify("Error", "Failed to load: " .. tostring(err))
        end
    end)
    
    -- Delete button
    section:NewButton("Delete Config", function()
        local name = configNameInput:Get()
        if name == "" then
            self.Library:Notify("Error", "Please select a config")
            return
        end
        
        local success, err = self:Delete(name)
        if success then
            self.Library:Notify("Success", "Config deleted: " .. name)
            configDropdown:Refresh(self:GetConfigList())
            configNameInput:Set("")
        else
            self.Library:Notify("Error", "Failed to delete: " .. tostring(err))
        end
    end)
    
    -- Refresh button
    section:NewButton("Refresh List", function()
        configDropdown:Refresh(self:GetConfigList())
    end)
    
    -- Autoload button
    local autoloadBtn = section:NewButton("Set Autoload", function()
        local name = configNameInput:Get()
        if name == "" then
            self.Library:Notify("Error", "Please select a config")
            return
        end
        
        self:SetAutoload(name)
        self.Library:Notify("Success", "Autoload set to: " .. name)
    end)
    
    -- Show current autoload
    local autoload = self:GetAutoload()
    if autoload then
        section:NewLabel("Current Autoload: " .. autoload)
    end
    
    -- Ignore UI elements in saving
    self:SetIgnoreIndexes({"ConfigNameInput", "ConfigDropdown"})
end

return SaveManager
