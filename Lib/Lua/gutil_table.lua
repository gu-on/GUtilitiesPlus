-- @noindex

---@param t table
function table.clear(t)
    for key, _ in pairs(t) do
        t[key] = nil
    end
end

---@param t table
---@param value any
---@return boolean
function table.contains(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

---Inserts a unique entry into the table
---@param t table
---@param value any
function table.append(t, value)
    if not table.contains(t, value) then
        table.insert(t, value)
    end
end

---@param t table
function table.isEmpty(t)
    return next(t) == nil
end

function table.find(list, entry, key)
    for _, value in pairs(list) do
        if value[key] == entry[key] then
            return value
        end
    end
    return nil
end

---https://lua-users.org/wiki/CopyTable
---This is a simple, naive implementation. 
---It only copies the top level value and its direct children; 
---there is no handling of deeper children, metatables or special types such as userdata or coroutines. 
---It is also susceptible to influence by the __pairs metamethod. 
function table.shallowcopy(t)
    if type(t) ~= 'table' then
        return t
    end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end