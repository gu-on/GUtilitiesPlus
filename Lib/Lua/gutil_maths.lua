-- @noindex

---@class Maths
---@field Int32Min number
---@field Int32Max number
Maths = {}
Maths.Int32Min = -2147483648
Maths.Int32Max = 2147483647

---Calculate error function, obtained from https://hewgill.com/picomath/lua/erf.lua.html
---@param x number
---@return unknown
function Maths.Erf(x)
    -- constants
    local a1 <const> = 0.254829592
    local a2 <const> = -0.284496736
    local a3 <const> = 1.421413741
    local a4 <const> = -1.453152027
    local a5 <const> = 1.061405429
    local p <const> = 0.3275911

    -- Save the sign of x
    local sign = 1
    if x < 0 then
        sign = -1
    end
    x = math.abs(x)

    -- A&S formula 7.1.26
    local t <const> = 1.0 / (1.0 + p * x)
    local y <const> = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x)

    return sign * y
end

---@param value number
---@param min number
---@param max number
---@return any
function Maths.Clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

function Maths.EaseOutBounce(x)
    local n1 <const> = 7.5625
    local d1 <const> = 2.75

    if x < 1 / d1 then
        return n1 * x * x
    elseif x < 2 / d1 then
        local y <const> = x - 1.5 / d1
        return n1 * y * y + 0.75
    elseif x < 2.5 / d1 then
        local y <const> = x - 2.25 / d1
        return n1 * y * y + 0.9375
    else
        local y <const> = x - 2.625 / d1
        return n1 * y * y + 0.984375
    end
end

function Maths.EaseInOutCubic(x)
    if x < 0.5 then
        return 4 * x * x * x
    else
        return 1 - (-2 * x + 2) ^ 3 / 2
    end
end

function Maths.DB2VOL(dB) return 10.0 ^ (0.05 * dB) end

function Maths.VOL2DB(vol) return 20.0 * math.log(vol, 10) end

function Maths.IsNearlyEqual(x, y, eps)
    eps = eps or 0.00001
    return math.abs(x - y) < eps;
end

---https://ardoris.wordpress.com/2008/11/07/rounding-to-a-certain-number-of-decimal-places-in-lua/
function Maths.Round(input, precision)
    local x <const> = 10 ^ precision
    return math.floor(input * x + 0.5) / x
end

---@param count integer
---@param min number
---@param max number
---@return number[]
function Maths.GetLogBands(count, min, max)
    min = math.log(min, 10)
    max = math.log(max, 10)

    local step <const> = (max - min) / count
    local bands = {}
    for i = 0, count do
        local freq <const> = 10 ^ (min + i * step)
        table.insert(bands, freq)
    end

    return bands
end

---@param a number
---@param b number
---@param epsilon number?
---@return boolean
function Maths.IsNearly(a, b, epsilon)
    epsilon = epsilon or 0.00001
    return math.abs(a - b) < epsilon
end
