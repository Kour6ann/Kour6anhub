-- SaveManager.lua
-- Standalone module implementing:
--   SaveManager:SaveConfig(lib, configName)
--   SaveManager:LoadConfig(lib, configName)
--   SaveManager:DeleteConfig(configName)
--   SaveManager:ListConfigs()
--   SaveManager:CreateConfigFromName(lib, configName)
--   SaveManager:AutoLoadLast(lib)  (optional)
--
-- Preconditions:
--   - Environment exposes file API: isfolder, makefolder, isfile, readfile, writefile, delfile, listfiles
--   - HttpService available for JSON
--   - lib is a Window object returned by Kour6anHub.CreateLib (has _elements and _elements_by_flag)
--
-- Returns: table (module)

local SaveManager = {}
SaveManager.__index = SaveManager

local HttpService = game:GetService("HttpService")

-- Helper: safe file API wrappers
local function safeIsFolder(p) local ok, r = pcall(isfolder, p); if ok then return r else return false end end
local function safeMakeFolder(p) return pcall(function() makefolder(p) end) end
local function safeIsFile(p) local ok, r = pcall(isfile, p); if ok then return r else return false end end
local function safeReadFile(p) local ok, r = pcall(function() return readfile(p) end); if ok then return true, r else return false, r end
local function safeWriteFile(p, data) return pcall(function() writefile(p, data) end) end
local function safeDelFile(p) return pcall(function() delfile(p) end) end
local function safeListFiles(p) local ok, r = pcall(function() return listfiles(p) end); if ok then return true, r else return false, r end

-- Helper: sanitization for config names
local function sanitizeName(name)
    if type(name) ~= "string" then return false, "name must be string" end
    local trimmed = name:gsub("^%s*(.-)%s*$", "%1")
    if trimmed == "" then return false, "name cannot be empty or whitespace" end
    if trimmed:match("%.%.") then return false, "name cannot contain '..'" end
    if trimmed:match("[/\\]") then return false, "name cannot contain path separators" end
    if trimmed:match("^%.") then return false, "name cannot begin with a dot" end
    if trimmed:match("^%s") or trimmed:match("%s$") then return false, "name cannot have leading/trailing whitespace" end
    -- Disallow absolute paths, drive letters, etc
    if trimmed:match("^%a%:") then return false, "invalid name (looks like absolute path)" end
    if trimmed:find("\0") then return false, "invalid character" end
    -- disallow other weird traversal chars
    if trimmed:match("[%c]") then return false, "invalid control character" end
    return true, trimmed
end

-- Config folder name for a given library name
local function configFolderForLibName(libName)
    return tostring(libName or "Kour6anhub") .. "_Configs"
end

-- Convert Color3 to table r,g,b 0-255
local function colorToTable(c)
    if typeof(c) ~= "Color3" then return nil end
    return { r = math.floor(c.R * 255 + 0.5), g = math.floor(c.G * 255 + 0.5), b = math.floor(c.B * 255 + 0.5) }
end

local function tableToColor(t)
    if type(t) ~= "table" then return nil end
    local r,g,b = t.r or t[1] or t.R, t.g or t[2] or t.G, t.b or t[3] or t.B
    if not r or not g or not b then return nil end
    -- accept 0-255 or 0-1 ranges heuristically
    if r > 1 or g > 1 or b > 1 then
        return Color3.fromRGB(math.clamp(tonumber(r) or 0,0,255), math.clamp(tonumber(g) or 0,0,255), math.clamp(tonumber(b) or 0,0,255))
    else
        return Color3.new(math.clamp(tonumber(r) or 0,0,1), math.clamp(tonumber(g) or 0,0,1), math.clamp(tonumber(b) or 0,0,1))
    end
end

-- Build config path
local function configPath(lib, name)
    local libName = (lib and lib.Main and lib.Main.Name) or "Kour6anhub"
    local folder = configFolderForLibName(libName)
    return folder, folder .. "/" .. name .. ".json"
end

-- Serialization: gather flagged elements from lib
local function gatherPersistables(lib)
    assert(type(lib) == "table", "SaveManager:lib required (window)")
    local out = {}
    if not lib._elements or type(lib._elements) ~= "table" then return out end
    for _, wrapper in ipairs(lib._elements) do
        if wrapper and type(wrapper) == "table" and wrapper.Flag and type(wrapper.Flag) == "string" and wrapper.Flag ~= "" then
            -- Use wrapper.Type to determine how to get value
            local val = nil
            -- Prefer wrapper.Get if present
            if wrapper.Get and type(wrapper.Get) == "function" then
                val = wrapper:Get()
            elseif wrapper.Raw and type(wrapper.Raw) == "table" then
                -- attempt to inspect
                if wrapper.Raw.Get then val = wrapper.Raw.Get() end
            end
            table.insert(out, { Flag = wrapper.Flag, Type = wrapper.Type, Value = val })
        end
    end
    return out
end

-- Public API
-- SaveManager:SaveConfig(lib, configName) -> (bool, err)
function SaveManager.SaveConfig(lib, configName)
    assert(type(lib) == "table", "SaveConfig: lib (window) required")
    assert(type(configName) == "string", "SaveConfig: configName required (string)")
    local ok, nameOrErr = sanitizeName(configName)
    if not ok then return false, ("invalid configName: %s"):format(nameOrErr) end
    local folder, path = configPath(lib, nameOrErr)
    -- ensure folder exists
    if not safeIsFolder(folder) then
        local fok, ferr = safeMakeFolder(folder)
        if not fok then return false, "failed to create config folder: " .. tostring(ferr) end
    end
    -- gather elements
    local items = gatherPersistables(lib)
    local payload = { meta = { library = (lib and lib.Main and lib.Main.Name) or "Kour6anhub", timestamp = os.time() }, entries = {} }
    for _, e in ipairs(items) do
        if not e.Flag or type(e.Flag) ~= "string" or e.Flag == "" then
            -- skip unlabeled
        else
            local serial = nil
            local okconv = true
            if e.Type == "Toggle" then
                serial = (type(e.Value) == "boolean") and e.Value or (not not e.Value)
            elseif e.Type == "Slider" then
                serial = tonumber(e.Value) or 0
            elseif e.Type == "Dropdown" then
                serial = (type(e.Value) == "string") and e.Value or tostring(e.Value or "")
            elseif e.Type == "Keybind" then
                if typeof(e.Value) == "EnumItem" and e.Value.EnumType == Enum.KeyCode then
                    serial = tostring(e.Value):gsub("^Enum.KeyCode%.","")
                elseif type(e.Value) == "string" then
                    serial = e.Value
                else
                    serial = nil
                end
            elseif e.Type == "Textbox" then
                serial = tostring(e.Value or "")
            elseif e.Type == "Colorpicker" then
                if typeof(e.Value) == "Color3" then
                    serial = colorToTable(e.Value)
                elseif type(e.Value) == "table" then
                    serial = e.Value
                else
                    serial = nil
                end
            else
                -- unknown type: try direct serialization
                local t = type(e.Value)
                if t == "boolean" or t == "number" or t == "string" or t == "table" then
                    serial = e.Value
                else
                    okconv = false
                end
            end
            if serial == nil and okconv then
                -- skip and warn
                warn("[SaveManager] Skipping un-serializable element:", e.Flag)
            elseif okconv then
                payload.entries[e.Flag] = { type = e.Type, value = serial }
            end
        end
    end
    -- write JSON readable
    local okwrite, err = safeWriteFile(path, HttpService:JSONEncode(payload))
    if not okwrite then return false, ("failed to write file: %s"):format(tostring(err)) end
    -- optionally update last_config.json
    local lastpath = configPath(lib, "__last_config__")
    pcall(function() safeWriteFile(lastpath, HttpService:JSONEncode({ last = nameOrErr, timestamp = os.time() })) end)
    return true, nil
end

-- Load config: returns true,nil on success
-- Optional third param 'opts' is a table { suppressCallbacks = true/false }
function SaveManager.LoadConfig(lib, configName, opts)
    assert(type(lib) == "table", "LoadConfig: lib (window) required")
    assert(type(configName) == "string", "LoadConfig: configName required (string)")
    local suppress = false
    if type(opts) == "table" and opts.suppressCallbacks == true then suppress = true end
    local ok, nameOrErr = sanitizeName(configName)
    if not ok then return false, ("invalid configName: %s"):format(nameOrErr) end
    local folder, path = configPath(lib, nameOrErr)
    if not safeIsFile(path) then return false, "config file does not exist" end
    local okr, contentOrErr = safeReadFile(path)
    if not okr then return false, ("failed to read file: %s"):format(tostring(contentOrErr)) end
    local okjson, parsed = pcall(function() return HttpService:JSONDecode(contentOrErr) end)
    if not okjson or type(parsed) ~= "table" then
        warn("[SaveManager] Malformed JSON in config:", path)
        return false, "malformed json"
    end
    local entries = parsed.entries or {}
    -- iterate entries
    for flag, entry in pairs(entries) do
        local wrapper = lib._elements_by_flag and lib._elements_by_flag[flag]
        if not wrapper then
            warn("[SaveManager] Unknown flag in config, skipping:", flag)
            -- skip unknown flag
        else
            local t = entry.type or wrapper.Type
            local v = entry.value
            local converted = nil
            local conversionOk = true
            if t == "Toggle" then
                converted = (type(v) == "boolean") and v or (v == "true" or v == true)
            elseif t == "Slider" then
                converted = tonumber(v) or 0
            elseif t == "Dropdown" then
                converted = tostring(v)
                -- check if option available? wrapper.Raw._options may exist
                if wrapper.Raw and wrapper.Raw._options and type(wrapper.Raw._options) == "table" then
                    local found = false
                    for _, opt in ipairs(wrapper.Raw._options) do
                        if tostring(opt) == converted then found = true; break end
                    end
                    if not found then
                        warn("[SaveManager] Dropdown option missing for flag:", flag, "value:", converted)
                        conversionOk = false
                    end
                end
            elseif t == "Keybind" then
                if type(v) == "string" then
                    if Enum.KeyCode[v] then converted = Enum.KeyCode[v]
                    else
                        -- try uppercase single letter
                        local up = string.upper(v)
                        if Enum.KeyCode[up] then converted = Enum.KeyCode[up] else converted = nil end
                    end
                    if not converted then
                        warn("[SaveManager] Invalid KeyCode for flag:", flag, "value:", tostring(v))
                        conversionOk = false
                    end
                else
                    conversionOk = false
                end
            elseif t == "Textbox" then
                converted = tostring(v)
            elseif t == "Colorpicker" then
                if type(v) == "table" then
                    local c = tableToColor(v)
                    if c then converted = c else conversionOk = false end
                else
                    conversionOk = false
                end
            else
                converted = v
            end

            if conversionOk and wrapper.Set and type(wrapper.Set) == "function" then
                -- Set and optionally suppress callbacks
                local okset, serr = pcall(function() wrapper:Set(converted, suppress) end)
                if not okset then
                    warn("[SaveManager] Failed to set element:", flag, tostring(serr))
                end
            else
                if not conversionOk then
                    warn("[SaveManager] Skipping entry due conversion failure:", flag)
                end
            end
        end
    end
    return true, nil
end

-- DeleteConfig(configName)
function SaveManager.DeleteConfig(configName)
    assert(type(configName) == "string", "DeleteConfig: configName required (string)")
    local ok, nameOrErr = sanitizeName(configName)
    if not ok then return false, ("invalid configName: %s"):format(nameOrErr) end
    -- no lib needed to compute folder (we assume default folder)
    local folder = configFolderForLibName("Kour6anhub")
    local path = folder .. "/" .. nameOrErr .. ".json"
    if not safeIsFile(path) then return false, "file does not exist" end
    local okdel, derr = safeDelFile(path)
    if not okdel then return false, ("failed to delete: %s"):format(tostring(derr)) end
    return true, nil
end

-- ListConfigs() -> sorted array
function SaveManager.ListConfigs()
    local folder = configFolderForLibName("Kour6anhub")
    if not safeIsFolder(folder) then return {} end
    local ok, files = safeListFiles(folder)
    if not ok or type(files) ~= "table" then return {} end
    local out = {}
    for _, full in ipairs(files) do
        -- full may include folder prefix
        local name = full:match("([^/\\]+)%.json$")
        if name and name ~= "__last_config__" then table.insert(out, name) end
    end
    table.sort(out, function(a,b) return string.lower(a) < string.lower(b) end)
    return out
end

-- CreateConfigFromName(lib, configName)
function SaveManager.CreateConfigFromName(lib, configName)
    assert(type(lib) == "table", "CreateConfigFromName: lib required")
    assert(type(configName) == "string", "CreateConfigFromName: configName required (string)")
    local ok, err = SaveManager.SaveConfig(lib, configName)
    if ok then return true, nil else return false, err end
end

-- Optional AutoLoadLast(lib): tries to load last config from __last_config__.json
function SaveManager.AutoLoadLast(lib)
    assert(type(lib) == "table", "AutoLoadLast: lib required")
    local folder = configFolderForLibName((lib and lib.Main and lib.Main.Name) or "Kour6anhub")
    local lastpath = folder .. "/__last_config__.json"
    if not safeIsFile(lastpath) then return false, "no last config recorded" end
    local ok, c = safeReadFile(lastpath)
    if not ok then return false, "failed reading last config" end
    local okj, parsed = pcall(function() return HttpService:JSONDecode(c) end)
    if not okj or not parsed or not parsed.last then return false, "malformed last config" end
    return SaveManager.LoadConfig(lib, parsed.last)
end

-- Return module
return SaveManager
