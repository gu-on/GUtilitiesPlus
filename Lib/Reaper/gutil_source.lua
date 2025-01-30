-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('Lua.gutil_classic')

---@class Source : Object
---@operator call: Source
Source = Object:extend()

---@param id PCM_source
function Source:new(id)
    self.id = id
end

---@param other Source
function Source:__eq(other) return self.id == other.id end

function Source:__tostring() return tostring(self.id) end

function Source:IsValid() return self.id and reaper.GetMediaSourceType(self.id) ~= "EMPTY" and self:GetSampleRate() > 0 end

function Source:GetPath() return reaper.GetMediaSourceFileName(self.id) end

function Source:GetFileFormat() return select(3, FileSys.Path.Parse(self:GetPath())) end

function Source:GetFileName() return select(2, FileSys.Path.Parse(self:GetPath())) end

function Source:GetChannelCount() return reaper.GetMediaSourceNumChannels(self.id) end

function Source:GetSampleRate() return reaper.GetMediaSourceSampleRate(self.id) end

function Source:GetBitDepth() return reaper.CF_GetMediaSourceBitDepth(self.id) end

function Source:GetLength() return reaper.GetMediaSourceLength(self.id) end

---@param normalizationType NormalizationType
---@return number
function Source:GetNormalization(normalizationType) return 20 * math.log(reaper.CalculateNormalization(self.id, normalizationType, 0, 0, 0), 10) * -1 end

function Source:GetPeak() return self:GetNormalization(2) end

function Source:GetRMS() return self:GetNormalization(1) end

function Source:GetLUFS() return self:GetNormalization(0) end

function Source:GetTimeToPeak(bufferSize, threshold)
    return reaper.GU_PCM_Source_TimeToPeak(self.id, bufferSize, threshold)
end

function Source:GetTimeToPeakR(bufferSize, threshold)
    return reaper.GU_PCM_Source_TimeToPeakR(self.id, bufferSize, threshold)
end

function Source:GetTimeToRMS(bufferSize, threshold)
    return reaper.GU_PCM_Source_TimeToRMS(self.id, bufferSize, threshold)
end

function Source:GetTimeToRMSR(bufferSize, threshold)
    return reaper.GU_PCM_Source_TimeToRMSR(self.id, bufferSize, threshold)
end

function Source:HasLoopMarker() return reaper.GU_PCM_Source_HasRegion(self.id) end

function Source:IsFirstSampleZero(eps) return Maths.IsNearlyEqual(math.abs(reaper.GU_PCM_Source_GetSampleValue(self.id, 0)), 0, eps) end

function Source:IsLastSampleZero(eps)
    local length <const> = self:GetLength()
    local value <const> = math.abs(reaper.GU_PCM_Source_GetSampleValue(self.id, length))
    return Maths.IsNearlyEqual(value, 0, eps)
end

function Source:IsMono() return reaper.GU_PCM_Source_IsMono(self.id) end