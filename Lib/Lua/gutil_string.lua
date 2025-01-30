-- @noindex

---@class Str
Str = {}

---@param input string?
---@return boolean
---@nodiscard
function Str.IsNilOrEmpty(input) return input == nil or input == "" end

---@param input string
---@return boolean
---@nodiscard
function Str.IsInt(input)
    assert(type(input) == "string")
    return tonumber(input, 10) ~= nil
end

---@param input string
---@return boolean
---@nodiscard
function Str.IsBool(input)
    return string.lower(input) == "true" or string.lower(input) == "false"
end

---@param input string
---@return boolean?
---@nodiscard
function Str.ToBool(input)
    if string.lower(input) == "true" then
        return true
    elseif string.lower(input) == "false" then
        return false
    else
        return nil
    end
end

---Returns first found valid set of numbers from a given string, including sign and decimal point
---@param input string
---@return number
---@nodiscard
function Str.ExtractNumber(input)
    assert(type(input) == "string", ("input '%s' is not a string\n"):format(input and tostring(input) or 'nil') .. debug.traceback())
    local start <const> = input:find("[%-%d]") or 1
    local final <const> = input:find("[^%.%d]", start + 1) or input:len() + 1
    local output = input:sub(start, final - 1)

    local firstDecimal <const> = output:find("%.") or 1
    if firstDecimal > 1 then
        local secondDecimal <const> = output:find("%.", firstDecimal + 1) or firstDecimal
        if secondDecimal > firstDecimal then
            output = output:sub(1, secondDecimal - 1)
        end
    end
    return tonumber(output) or 0
end

---@param input string
---@return boolean
---@nodiscard
function Str.IsNumber(input)
    return tonumber(input) ~= nil
end

---@param input string
---@param delimiter string
function Str.Split(input, delimiter)
    local result = {} ---@type string[]
    for match in (input .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

---https://www.programming-idioms.org/idiom/110/check-if-string-is-blank/6290/lua
---@param input string
function Str.IsBlank(input)
    return #string.gsub(input, "^%s*(.-)%s*$", "%1") == 0
end