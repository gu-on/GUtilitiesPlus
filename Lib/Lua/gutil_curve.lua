-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('Lua.gutil_classic')
require('Lua.gutil_maths')

---@class Curve : Object
---@operator call: Curve
Curve = Object:extend()

---@param size integer?
function Curve:new(size)
    self.size = size or 32
    self.plot = {} ---@type number[]

    return self
end

function Curve:ScaleAndClamp()
    local first <const> = self.plot[1]
    local last <const> = self.plot[#self.plot]

    for i = 1, self.size do
        self.plot[i] = (self.plot[i] - first) * (self.size / (last - first))
    end
    return self.plot
end

function Curve:PlotBlank()
    for i = 1, self.size do
        self.plot[i] = 0
    end

    return self:ScaleAndClamp()
end

function Curve:PlotLinear()
    for i = 1, self.size do
        local index <const> = i - 1
        self.plot[i] = index
    end

    return self:ScaleAndClamp()
end

function Curve:PlotLinearR()
    self:PlotLinear()
    return self:ReversePlot()
end

---@param steepness number
---@return table
function Curve:PlotFastStart(steepness)
    for i = 1, self.size do
        local index <const> = i - 1
        self.plot[i] = self.size * (1 - (((self.size - index) / self.size) ^ steepness))
    end

    return self:ScaleAndClamp()
end

---@param steepness number
---@return table
function Curve:PlotFastStartR(steepness)
    self:PlotFastStart(steepness)
    return self:ReversePlot()
end

---@param steepness number
---@return table
function Curve:PlotFastEnd(steepness)
    for i = 1, self.size do
        local index <const> = i - 1
        self.plot[i] = self.size * ((index / self.size) ^ steepness)
    end

    return self:ScaleAndClamp()
end

function Curve:PlotFastEndR(steepness)
    self:PlotFastEnd(steepness)
    return self:ReversePlot()
end

function Curve:PlotSlowStartEnd(steepness)
    local halfSize = self.size * 0.5
    for i = 1, self.size do
        local index <const> = i - 1
        self.plot[i] = halfSize * (Maths.Erf(steepness * (index - halfSize) / self.size) + 1)
    end

    return self:ScaleAndClamp()
end

function Curve:PlotSlowStartEndR(steepness)
    self:PlotSlowStartEnd(steepness)
    return self:ReversePlot()
end

function Curve:ReversePlot()
    for i = 1, math.floor(self.size / 2) do
        local j <const> = self.size - i + 1
        self.plot[i], self.plot[j] = self.plot[j], self.plot[i]
    end
    return self.plot
end

return Curve