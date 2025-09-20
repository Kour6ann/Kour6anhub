-- SaveManager for Kour6anHub (drop-in)
local HttpService = game:GetService("HttpService")
local SaveManager = {}
SaveManager.__index = SaveManager

function SaveManager.new(lib)
    local self = setmetatable({
        lib = lib,
        folder = "Kour6anHubConfigs",
        ignoreKeys = {},
        ignorePattern = nil,
    }, SaveManager)
    return self
end

function SaveManager:SetFolder(path) self.folder = path end
function SaveManager:SetIgnoreKeys(list) self.ignoreKeys = list or {} end
function SaveManager:SetIgnorePattern(pat) self.ignorePattern = pat end

local function can_write()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function safe_write(path, data)
    if can_write() then
        pcall(function() writefile(path, data) end)
    else
        _G.__Kour6anHubSaves = _G.__Kour6anHubSaves or {}
        _G.__Kour6anHubSaves[path] = data
    end
end

local function safe_read(path)
    if can_write() then
        if pcall(function() return readfile(path) end) then
            return readfile(path)
        else
            return nil
        end
    else
        return _G.__Kour6anHubSaves and _G.__Kour6anHubSaves[path] or nil
    end
end

function SaveManager:_walkRegistry()
    local out = {}
    if not self.lib or not self.lib._registry then return out end
    for key, entry in pairs(self.lib._registry) do
        if entry and entry.get and not table.find(self.ignoreKeys, key) then
            if self.ignorePattern and tostring(key):match(self.ignorePattern) then
                -- skip
            else
                local ok, val = pcall(entry.get)
                if ok then out[key] = val end
            end
        end
    end
    return out
end

function SaveManager:SaveConfig(name)
    name = name or ("config_" .. tostring(os.time()))
    local data = self:_walkRegistry()
    local raw = HttpService:JSONEncode({meta={saved=os.time()}, data=data})
    local path = self.folder .. "/" .. name .. ".json"
    safe_write(path, raw)
    return true
end

function SaveManager:ListConfigs()
    if can_write() and type(listfiles) == "function" then
        local files = listfiles(self.folder) or {}
        local out = {}
        for _, f in ipairs(files) do
            if f:match("%.json$") then
                local n = f:match("[^/\\]+%.json$"):gsub("%.json$","")
                table.insert(out, n)
            end
        end
        return out
    else
        local out = {}
        if _G.__Kour6anHubSaves then
            for k,_ in pairs(_G.__Kour6anHubSaves) do
                if k:match(self.folder) and k:match("%.json$") then
                    local n = k:match("[^/\\]+%.json$"):gsub("%.json$","")
                    table.insert(out, n)
                end
            end
        end
        return out
    end
end

function SaveManager:LoadConfig(name)
    local path = self.folder .. "/" .. name .. ".json"
    local raw = safe_read(path)
    if not raw then return false, "file not found" end
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or not parsed or not parsed.data then return false, "invalid file" end
    local data = parsed.data

    for key, value in pairs(data) do
        local entry = self.lib._registry[key]
        if entry and entry.set then
            pcall(function() entry.set(value) end)
        end
    end

    return true
end



-- Delete config file
function SaveManager:DeleteConfig(name)
    if not name or name == "" then return false, "invalid name" end
    local path = self.folder .. "/" .. name .. ".json"
    local success = false
    if type(delfile) == "function" then
        pcall(function() delfile(path) end)
        success = true
    elseif type(removefile) == "function" then
        pcall(function() removefile(path) end)
        success = true
    elseif type(writefile) == "function" then
        -- best-effort fallback: overwrite with empty JSON
        pcall(function() writefile(path, "") end)
        success = true
    else
        if _G.__Kour6anHubSaves then
            _G.__Kour6anHubSaves[path] = nil
            success = true
        end
    end
    return success
end

-- Autoload helpers (persist autoload selection to a special file)
function SaveManager:SetAutoload(name)
    if not name or name == "" then return false end
    local raw = HttpService:JSONEncode({name = name})
    safe_write(self.folder .. "/_autoload.json", raw)
    return true
end

function SaveManager:ClearAutoload()
    local path = self.folder .. "/_autoload.json"
    if type(delfile) == "function" then
        pcall(function() delfile(path) end)
    elseif type(removefile) == "function" then
        pcall(function() removefile(path) end)
    else
        if _G.__Kour6anHubSaves then _G.__Kour6anHubSaves[path] = nil end
    end
end

function SaveManager:GetAutoload()
    local path = self.folder .. "/_autoload.json"
    local raw = safe_read(path)
    if not raw then return nil end
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or not parsed or not parsed.name then return nil end
    return parsed.name
end

function SaveManager:TryLoadAutoload()
    local name = self:GetAutoload()
    if name then
        local ok, err = self:LoadConfig(name)
        return ok, err
    end
    return false, "no autoload set"
end

-- Build a Settings UI section inside the library (Fluent-like UX)
-- If tabArg is omitted, will create a tab named "Settings"
function SaveManager:BuildConfigSection(tabArg)
    if not self.lib then return end
    local lib = self.lib
    local tab = tabArg
    -- try to find existing Settings tab; else create new
    if not tab then
        -- avoid creating duplicate if one exists
        if lib.Tabs and type(lib.Tabs) == "table" then
            for _, t in ipairs(lib.Tabs) do
                if t.Button and t.Button.Text == "Settings" then
                    -- construct a simple TabObj wrapper that uses the library's NewTab for full API
                    tab = lib:NewTab("Settings")
                    break
                end
            end
        end
        if not tab then
            tab = lib:NewTab("Settings")
        end
    end

    -- create a section for configs
    local section = tab:NewSection("Configurations")

    -- helper to refresh list
    local function refreshList(drop)
        local list = self:ListConfigs() or {}
        if drop and type(drop.Refresh) == "function" then
            drop:Refresh(list)
        end
    end

    -- create dropdown of configs
    local configs = self:ListConfigs()
    local dropdown = section:NewDropdown("Configs", configs, function() end)

    -- create label + textbox for save name (we create the textbox instance manually to access its Text)
    local lbl = section:NewLabel("Save as:")
    local sectionFrame = lbl.Parent

    local nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(1, 0, 0, 28)
    nameBox.BackgroundColor3 = sectionFrame.BackgroundColor3 or Color3.fromRGB(40,40,40)
    nameBox.TextColor3 = lib.ThemeName and Color3.fromRGB(255,255,255) or Color3.fromRGB(200,200,200)
    nameBox.PlaceholderText = "config_name"
    nameBox.Text = ""
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextSize = 14
    nameBox.Parent = sectionFrame

    -- Save button
    section:NewButton("Save Config", nil, function()
        local name = tostring(nameBox.Text or ""):gsub("%s+", "_")
        if name == "" then name = "config_" .. tostring(os.time()) end
        self:SaveConfig(name)
        refreshList(dropdown)
        -- optional notification if lib has a notification api
        if lib.Notify then
            pcall(function() lib:Notify("Saved config: "..name) end)
        end
    end)

    -- Load button
    section:NewButton("Load Selected", nil, function()
        local sel = nil
        pcall(function() sel = dropdown.Get and dropdown:Get() end)
        if not sel or sel == "" then
            if lib.Notify then pcall(function() lib:Notify("No config selected") end) end
            return
        end
        local ok, err = self:LoadConfig(sel)
        if ok then
            if lib.Notify then pcall(function() lib:Notify("Loaded config: "..sel) end) end
        else
            if lib.Notify then pcall(function() lib:Notify("Failed to load: "..tostring(err)) end) end
        end
    end)

    -- Delete button
    section:NewButton("Delete Selected", nil, function()
        local sel = nil
        pcall(function() sel = dropdown.Get and dropdown:Get() end)
        if not sel or sel == "" then
            if lib.Notify then pcall(function() lib:Notify("No config selected") end) end
            return
        end
        self:DeleteConfig(sel)
        refreshList(dropdown)
        if lib.Notify then pcall(function() lib:Notify("Deleted config: "..sel) end) end
    end)

    -- Autoload toggle + dropdown for autoload selection
    local autToggle = section:NewToggle("Autoload", "Load selected config on startup", function() end)
    local autLabel = section:NewLabel("Autoload selection:")
    local autDropdown = section:NewDropdown("Autoload", self:ListConfigs(), function() end)

    -- initialize autoload UI state
    local currentAut = self:GetAutoload()
    if currentAut and autDropdown.Set then
        autDropdown:Set(currentAut)
        if autToggle.SetState then autToggle:SetState(true) end
    else
        if autToggle.SetState then autToggle:SetState(false) end
    end

    -- wire autoload dropdown changes
    if autDropdown.Set then
        -- ensure UI updates when user selects
        (function()
            local origSet = autDropdown.Set
            autDropdown.Set = function(v)
                origSet(v)
                -- save selection to autoload if toggle is enabled
                if autToggle.GetState and autToggle.GetState() then
                    self:SetAutoload(v)
                end
            end
        end)()
    end

    -- wire toggle callback to persist autoload choice
    if autToggle.SetState then
        -- we assume toggle was created earlier with a callback; override to hook persistence
        (function()
            local origToggleGet = autToggle.GetState
            local origToggleSet = autToggle.SetState
            autToggle.SetState = function(v)
                origToggleSet(v)
                if v then
                    local sel = nil
                    pcall(function() sel = autDropdown.Get and autDropdown:Get() end)
                    if sel and sel ~= "" then
                        self:SetAutoload(sel)
                    end
                else
                    self:ClearAutoload()
                end
            end
        end)()
    end

    -- refresh the two dropdowns visually
    refreshList(dropdown)
    refreshList(autDropdown)

    -- attempt autoload immediately if an autoload is set
    pcall(function() self:TryLoadAutoload() end)
end
return SaveManager
