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
return SaveManager
