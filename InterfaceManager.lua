-- InterfaceManager for Kour6anHub (saves position/size/minimized/theme/activeTab)
local HttpService = game:GetService("HttpService")
local InterfaceManager = {}
InterfaceManager.__index = InterfaceManager

function InterfaceManager.new(lib)
    local self = setmetatable({
        lib = lib,
        folder = "Kour6anHubInterfaces"
    }, InterfaceManager)
    return self
end

local function can_write()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function safe_write(path, data)
    if can_write() then
        pcall(function() writefile(path, data) end)
    else
        _G.__Kour6anHubIfaces = _G.__Kour6anHubIfaces or {}
        _G.__Kour6anHubIfaces[path] = data
    end
end

local function safe_read(path)
    if can_write() then
        if pcall(function() return readfile(path) end) then
            return readfile(path)
        else return nil end
    else
        return _G.__Kour6anHubIfaces and _G.__Kour6anHubIfaces[path]
    end
end

function InterfaceManager:Snapshot()
    local w = self.lib and self.lib.Main
    if not w then return nil end
    local snap = {
        position = tostring(w.Position),
        size = tostring(w.Size),
        minimized = (self.lib._uiMinimized == true),
        activeTab = self.lib.ActiveTabName or "",
        theme = self.lib.ThemeName or ""
    }
    return snap
end

function InterfaceManager:SaveInterface(name)
    name = name or ("interface_" .. tostring(os.time()))
    local snap = self:Snapshot()
    if not snap then return false end
    local raw = HttpService:JSONEncode({meta={saved=os.time()}, snap=snap})
    safe_write(self.folder .. "/" .. name .. ".json", raw)
    return true
end

function InterfaceManager:LoadInterface(name)
    local path = self.folder .. "/" .. name .. ".json"
    local raw = safe_read(path)
    if not raw then return false, "file not found" end
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or not parsed or not parsed.snap then return false, "invalid file" end
    local snap = parsed.snap

    pcall(function()
        if snap.position and self.lib.Main then
            local f = loadstring("return " .. snap.position)
            if f then self.lib.Main.Position = f() end
        end
        if snap.size and self.lib.Main then
            local f2 = loadstring("return " .. snap.size)
            if f2 then self.lib.Main.Size = f2() end
        end
    end)

    if snap.minimized ~= nil then
        if snap.minimized and type(self.lib.ToggleMinimize) == "function" then
            pcall(function() self.lib:ToggleMinimize(true) end)
        end
    end

    if snap.theme and self.lib.SetTheme then
        pcall(function() self.lib:SetTheme(snap.theme) end)
    end

    if snap.activeTab and snap.activeTab ~= "" and self.lib.SelectTab then
        pcall(function() self.lib:SelectTab(snap.activeTab) end)
    end

    return true
end
return InterfaceManager
