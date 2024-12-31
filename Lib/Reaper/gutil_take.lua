-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('lua.gutil_classic')

---@alias TakeParamName_Number
---| '"D_STARTOFFS"' # start offset in source media, in seconds
---| '"D_VOL"' # take volume, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc, negative if take polarity is flipped
---| '"D_PAN"' # take pan, -1..1
---| '"D_PANLAW"' # take pan law, -1=default, 0.5=-6dB, 1.0=+0dB, etc
---| '"D_PLAYRATE"' # take playback rate, 0.5=half speed, 1=normal, 2=double speed, etc
---| '"D_PITCH"' # take pitch adjustment in semitones, -12=one octave down, 0=normal, +12=one octave up, etc
---| '"B_PPITCH"' # preserve pitch when changing playback rate
---| '"I_LASTY"' # Y-position (relative to top of track) in pixels (read-only)
---| '"I_LASTH"' # height in pixels (read-only)
---| '"I_CHANMODE"' # channel mode, 0=normal, 1=reverse stereo, 2=downmix, 3=left, 4=right
---| '"I_PITCHMODE"' # pitch shifter mode, -1=project default, otherwise high 2 bytes=shifter, low 2 bytes=parameter
---| '"I_STRETCHFLAGS"' # stretch marker flags (&7 mask for mode override: 0=default, 1=balanced, 2/3/6=tonal, 4=transient, 5=no pre-echo)
---| '"F_STRETCHFADESIZE"' # stretch marker fade size in seconds (0.0025 default)
---| '"I_RECPASSID"' # record pass ID
---| '"I_TAKEFX_NCH"' # number of internal audio channels for per-take FX to use (OK to call with setNewValue, but the returned value is read-only)
---| '"I_CUSTOMCOLOR"' # custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
---| '"IP_TAKENUMBER"' # take number (read-only, returns the take number directly)

---@alias TakeParamName_String
---| '"P_NAME"' # take name
---| '"P_EXT:"' # extension-specific persistent data
---| '"GUID"' # 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}

---@class Take : Object
---@operator call: Take
Take = Object:extend()

---@param id MediaItem_Take
function Take:new(id)
    self.id = id
end

---@param other Take
function Take:__eq(other) return self.id == other.id end

function Take:__tostring() return tostring(self.id) end

function Take:IsValid() return self.id and self.id ~= 0 end

---Returns true if stretch markers are present in Take
---@param offset number
---@return boolean
function Take:TryMoveStretchMarkers(offset)
    local stretchMarkerCount <const> = reaper.GetTakeNumStretchMarkers(self.id)
    for i = 0, stretchMarkerCount - 1 do
        if i == 0 then self:SetValue("D_STARTOFFS", offset) end
        local _, pos <const>, sourcepos <const> = reaper.GetTakeStretchMarker(self.id, i)
        reaper.SetTakeStretchMarker(self.id, i, pos-offset, sourcepos)
    end
    return stretchMarkerCount > 0
end

---@param startTime number Start time in seconds
---@param size integer Buffer size in samples
---@return reaper.array
function Take:GetBuffer(startTime, size)
    local buffer = reaper.new_array(size)
    buffer.clear()
    local audio <const> = reaper.CreateTakeAudioAccessor(self.id)
    size = math.floor(size / 2 / 2)

    reaper.GetAudioAccessorSamples(audio, 48000, 2, startTime, size, buffer)
    reaper.DestroyAudioAccessor(audio)

    return buffer
end

---@param startTime number Start time in seconds
---@param size integer Buffer size in samples
function Take:GetFFT(startTime, size)
    local buf = self:GetBuffer(startTime, size)
    buf.fft(toint(#buf/2), true)

    return buf
end

---@param param TakeParamName_String
---@return string
---@nodiscard
function Take:GetString(param) return select(2, reaper.GetSetMediaItemTakeInfo_String(self.id, param, "", false)) end

function Take:GetSource()
    return Source(reaper.GetMediaItemTake_Source(self.id)) ---@type Source
end

function Take:GetTrack()
    return Track(reaper.GetMediaItemTake_Track(self.id)) ---@type Track
end

function Take:GetSourceLength()
    local source <const> = reaper.GetMediaItemTake_Source(self.id)
    local length <const> = reaper.GetMediaSourceLength(source)
    return length
end

function Take:GetSourceProperties() return reaper.BR_GetMediaSourceProperties(self.id) end

---@param param TakeParamName_Number
---@return number
---@nodiscard
function Take:GetValue(param) return reaper.GetMediaItemTakeInfo_Value(self.id, param) end

function Take:SetAudioSource(path)
    local oldSource <const> = reaper.GetMediaItemTake_Source(self.id)
    local newSource <const> = reaper.PCM_Source_CreateFromFile(path)

    if newSource ~= nil then
        reaper.SetMediaItemTake_Source(self.id, newSource)
    else
        Debug.Log("Source with dir '%s' is nil", path)
    end

    if oldSource ~= nil then
        reaper.PCM_Source_Destroy(oldSource)
    end
end

function Take:SetSourceProperties(section, start, length, fade, reverse)
    reaper.BR_SetMediaSourceProperties(self.id, section, start, length, fade, reverse)
end

---@param param TakeParamName_String
---@param value string
function Take:SetString(param, value) reaper.GetSetMediaItemTakeInfo_String(self.id, param, value, true) end

---@param param TakeParamName_Number
---@param value number
function Take:SetValue(param, value) reaper.SetMediaItemTakeInfo_Value(self.id, param, value) end

---@param input string
---@return string
---@nodiscard
function Take:WildcardParse(input)
    return reaper.GU_WildcardParseTake(self.id, input)
end

return Take