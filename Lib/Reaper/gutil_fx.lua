-- @noindex

--- https://forums.cockos.com/showthread.php?t=196829
---@param x number # value between 0 and 1
---@return number
function ReaEQValToFreq(x)
    local maxFreq <const> = 24000
    local minFreq <const> = 20
    local curve <const> = (math.exp(math.log(401)*x) - 1) * 0.0025
    return (maxFreq - minFreq) * curve + minFreq
end

---@param x number # frequency between 20 and 24000
---@return number
function ReaEQFreqToVal(x)
    local maxFreq <const> = 24000
    local minFreq <const> = 20
    local curve <const> = (x - minFreq) / (maxFreq - minFreq)
    return math.log((curve / 0.0025) + 1) / math.log(401)
end