-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('gutil_global')
require('Lua.gutil_classic')
require('Lua.gutil_string')

---@class Config : Object Manages config file read/write
---@operator call: Config
Config = Object:extend()

---@param category string
function Config:new(category)
    self.cfgName = "GUtilities"
    self.category = category
end

---@param key string
---@return boolean?
function Config:ReadBool(key)
    local success <const>, value <const> = reaper.GU_Config_Read(self.cfgName, self.category, tostring(key))
    if not success then return nil end

    if not Str.IsBool(value) then
        error("Config:ReadBool successful, but value isn't boolean")
        return nil
    else
        return Str.ToBool(value)
    end
end

---@param key string
---@return string?
function Config:ReadString(key)
    local success <const>, value <const> = reaper.GU_Config_Read(self.cfgName, self.category, tostring(key))
    if not success then return nil end

    return value
end

---@param key string
---@return number?
function Config:ReadNumber(key)
    local success <const>, value <const> = reaper.GU_Config_Read(self.cfgName, self.category, tostring(key))
    if not success then return nil end
    
    if not Str.IsNumber(value) then
        error("Config:ReadBool successful, but value isn't number")
        return nil
    else
        return tonumber(value)
    end
end

---Write to the key from the current category
---@param key string
---@param value string | number | boolean
function Config:Write(key, value)
    if Str.IsNilOrEmpty(key) or value == nil then return end

    value = tostring(value)

    local success <const> = reaper.GU_Config_Write(self.cfgName, self.category, tostring(key), value)

    if not success then Debug.Log("GU_Config_Write failed!\n") end
end