-- SaveManager.lua (fixed)
local HttpService = (game and game.GetService) and game:GetService("HttpService") or {
    JSONEncode = function(t) return "{}" end,
    JSONDecode = function(s) return {} end
}

local function safeIsFolder(path)
    if type(isfolder) == "function" then
        local ok, v = pcall(isfolder, path)
        return ok and v
    end
    return false
end

local function safeMakeFolder(path)
    if type(makefolder) == "function" then
        local ok, err = pcall(makefolder, path)
        return ok, err
    end
    return false, "makefolder not available"
end

local function safeIsFile(path)
    if type(isfile) == "function" then
        local ok, v = pcall(isfile, path)
        return ok and v
    end
    return false
end

local function safeReadFile(path)
    if type(readfile) == "function" then
        local ok, out = pcall(readfile, path)
        if ok then return true, out end
        return false, out
    end
    return false, "readfile not available"
end

local function safeWriteFile(path, content)
    if type(writefile) == "function" then
        local ok, out = pcall(writefile, path, content)
        if ok then return true end
        return false, out
    end
    return false, "writefile not available"
end

local function safeDeleteFile(path)
    if type(delfile) == "function" then
        local ok, out = pcall(delfile, path)
        if ok then return true end
        return false, out
    end
    return false, "delfile not available"
end

local function safeListFiles(path)
    if type(listfiles) == "function" then
        local ok, out = pcall(listfiles, path)
        if ok then return out end
        return {}
    end
    return {}
end

local SaveManager = {}
SaveManager.__index = SaveManager

local function configFolderForLibName(name)
    name = tostring(name or "Kour6anhub")
    return name .. "_Configs"
end

local function ensureConfigFolder(name)
    local folder = configFolderForLibName(name)
    if not safeIsFolder(folder) then
        local ok, err = safeMakeFolder(folder)
        if not ok then
            return false, ("failed to create config folder: %s"):format(tostring(err))
        end
    end
    return true, folder
end

local function color3ToTable(c)
    if typeof and typeof(c) == "Color3" then
        return { r = c.R, g = c.G, b = c.B }
    end
    if type(c) == "table" and c.r and c.g and c.b then
        return c
    end
    return nil
end

local function gatherPersistables(lib)
    local out = {}
    if type(lib) ~= "table" or type(lib._elements) ~= "table" then
        return out
    end
    for _, wrapper in ipairs(lib._elements) do
        if type(wrapper) == "table" and wrapper.Flag and wrapper.Get then
            local flag = wrapper.Flag
            local ok, val = pcall(function() return wrapper:Get() end)
            if not ok then
                warn("[SaveManager] failed reading wrapper value for flag:", flag)
            else
                if typeof and typeof(val) == "Color3" then
                    val = color3ToTable(val)
                end
                if typeof and typeof(val) == "EnumItem" then
                    val = tostring(val.Name or val)
                end
                out[flag] = val
            end
        end
    end
    return out
end

local function writeConfigFile(libName, configName, tbl)
    local ok, folderOrErr = ensureConfigFolder(libName)
    if not ok then return false, folderOrErr end
    local folder = folderOrErr
    local path = folder .. "/" .. tostring(configName) .. ".json"
    local okEnc, encoded = pcall(function() return HttpService:JSONEncode(tbl) end)
    if not okEnc then return false, "json_encode_failed: " .. tostring(encoded) end
    local wroteOk, writeErr = safeWriteFile(path, encoded)
    if not wroteOk then return false, writeErr end
    return true
end

local function readConfigFile(libName, configName)
    local folder = configFolderForLibName(libName)
    local path = folder .. "/" .. tostring(configName) .. ".json"
    if not safeIsFile(path) then return false, "no_such_file" end
    local ok, content = safeReadFile(path)
    if not ok then return false, content end
    local okj, parsed = pcall(function() return HttpService:JSONDecode(content) end)
    if not okj then return false, "json_decode_failed" end
    return true, parsed
end

function SaveManager.SaveConfig(lib, configName)
    if type(lib) ~= "table" then return false, "lib_required" end
    configName = tostring(configName or "config")
    local libName = (lib.Main and lib.Main.Name) and tostring(lib.Main.Name) or "Kour6anhub"
    local payload = gatherPersistables(lib)
    local ok, err = writeConfigFile(libName, configName, payload)
    if not ok then return false, err end
    pcall(function()
        local folder = configFolderForLibName(libName)
        safeWriteFile(folder .. "/__last_config__.json", HttpService:JSONEncode({ last = configName }))
    end)
    return true
end

function SaveManager.LoadConfig(lib, configName, opts)
    if type(lib) ~= "table" then return false, "lib_required" end
    configName = tostring(configName or "config")
    local libName = (lib.Main and lib.Main.Name) and tostring(lib.Main.Name) or "Kour6anhub"
    local ok, parsed = readConfigFile(libName, configName)
    if not ok then return false, parsed end

    opts = opts or {}
    local suppress = opts.suppressCallbacks == true

    for flag, val in pairs(parsed) do
        local wrapper = (lib._elements_by_flag and lib._elements_by_flag[flag]) or nil
        if not wrapper then
            warn("[SaveManager] Unknown flag in config, skipping:", flag)
        else
            if type(val) == "table" and val.r and val.g and val.b then
                local okc, c = pcall(function()
                    if typeof then return Color3.new(val.r, val.g, val.b) end
                    return { r = val.r, g = val.g, b = val.b }
                end)
                if okc then val = c end
            end
            if type(val) == "string" and wrapper.Type == "Keybind" then
                local success, kc = pcall(function()
                    return Enum.KeyCode[val] or Enum.KeyCode[string.upper(val)] or Enum.KeyCode["Unknown"]
                end)
                if success and kc then val = kc end
            end

            pcall(function()
                if wrapper.Set then
                    wrapper:Set(val, suppress)
                elseif wrapper.Raw and wrapper.Raw.Set then
                    wrapper.Raw:Set(val)
                else
                    wrapper.Value = val
                end
            end)
        end
    end

    return true
end

function SaveManager.DeleteConfig(configName, lib)
    configName = tostring(configName or "")
    if configName == "" then return false, "config name required" end
    local libName = "Kour6anhub"
    if type(lib) == "table" and lib.Main and lib.Main.Name then libName = tostring(lib.Main.Name) end
    local folder = configFolderForLibName(libName)
    local path = folder .. "/" .. configName .. ".json"
    if not safeIsFile(path) then return false, "no_such_file" end
    local ok, err = safeDeleteFile(path)
    if not ok then return false, err end
    return true
end

function SaveManager.ListConfigs(lib)
    local libName = "Kour6anhub"
    if type(lib) == "table" and lib.Main and lib.Main.Name then libName = tostring(lib.Main.Name) end
    local folder = configFolderForLibName(libName)
    if not safeIsFolder(folder) then return {} end
    local files = safeListFiles(folder)
    local out = {}
    for _, v in ipairs(files) do
        local name = tostring(v):match("([^/\\]+)%.json$")
        if name and name ~= "__last_config__" then
            table.insert(out, name)
        end
    end
    return out
end

function SaveManager.AutoLoadLast(lib)
    local libName = (type(lib) == "table" and lib.Main and lib.Main.Name) and tostring(lib.Main.Name) or "Kour6anhub"
    local folder = configFolderForLibName(libName)
    local lastpath = folder .. "/__last_config__.json"
    if not safeIsFile(lastpath) then return false, "no last config recorded" end
    local ok, content = safeReadFile(lastpath)
    if not ok then return false, "failed reading last config" end
    local okj, parsed = pcall(function() return HttpService:JSONDecode(content) end)
    if not okj or not parsed or not parsed.last then return false, "malformed last config" end
    return SaveManager.LoadConfig(lib, parsed.last, { suppressCallbacks = true })
end

return SaveManager
