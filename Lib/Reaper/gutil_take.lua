-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('Lua.gutil_classic')

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

function Take:__check() return reaper.GetTakeName(self.id) ~= nil end

function Take:IsValid()
    return self.id and select(1, pcall(self.__check, self))
end

---Returns true if stretch markers are present in Take
---@param offset number
---@return boolean
function Take:TryMoveStretchMarkers(offset)
    local stretchMarkerCount <const> = reaper.GetTakeNumStretchMarkers(self.id)
    for i = 0, stretchMarkerCount - 1 do
        if i == 0 then self:SetValue("D_STARTOFFS", offset) end
        local _, pos <const>, sourcepos <const> = reaper.GetTakeStretchMarker(self.id, i)
        reaper.SetTakeStretchMarker(self.id, i, pos - offset, sourcepos)
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

---@class (exact) SourceProperties
---@field section boolean
---@field pos number
---@field length number
---@field fade number
---@field reverse boolean

---@return SourceProperties? # Returns nil in some cases, e.g. for a take with MIDI
function Take:GetSourceProperties()
    local rv, _section, _pos, _length, _fade, _reverse = reaper.BR_GetMediaSourceProperties(self.id)
    if not rv then return nil end
    local info <const> --[[@type SourceProperties]] = {
        section = _section,
        pos = _pos,
        length = _length,
        fade = _fade,
        reverse = _reverse
    }
    return info
end

---@param info SourceProperties
---@return boolean # Returns false in some cases, e.g. for a take with MIDI
function Take:TrySetSourceProperties(info)
    return reaper.BR_SetMediaSourceProperties(self.id, info.section, info.pos, info.length, info.fade, info.reverse)
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

---@class (exact) TakeMarkerInfo
---@field idx integer
---@field name string
---@field col integer
---@field pos number # in seconds, in local time (0 = start of item, not project)

---@nodiscard
function Take:GetMarkers()
    local markers = {} ---@type TakeMarkerInfo[]

    local markerCount <const> = reaper.GetNumTakeMarkers(self.id)
    for i = 0, markerCount - 1 do
        local rv, n, c = reaper.GetTakeMarker(self.id, i)
        if rv then
            table.insert(markers, { index = i, name = n, color = c, pos = rv - self:GetValue("D_STARTOFFS") })
        end
    end

    return markers
end

---@param marker TakeMarkerInfo
function Take:AddMarker(marker)
    reaper.SetTakeMarker(self.id, -1, marker.name, marker.pos, marker.col)
end

function Take:IsMidi()
    return reaper.TakeIsMIDI(self.id)
end

---@class (exact) TakeMidiInfo
---@field posStart number
---@field posEnd number
---@field chan integer
---@field pitch integer
---@field vel integer

function Take:GetMidi()
    local midi = {} ---@type TakeMidiInfo[]
    for i = 0, reaper.MIDI_CountEvts(self.id) - 1 do
        local rv <const>, _, _, _noteStart <const>, _noteEnd <const>, _chan <const>, _pitch <const>, _vel <const> =
            reaper.MIDI_GetNote(self.id, i)
        if rv then
            local midiInfo <const> --[[@type TakeMidiInfo]] = {
                posStart = reaper.MIDI_GetProjTimeFromPPQPos(self.id, _noteStart),
                posEnd = reaper.MIDI_GetProjTimeFromPPQPos(self.id, _noteEnd),
                chan = _chan,
                pitch = _pitch,
                vel = _vel,
            }
            table.insert(midi, midiInfo)
        end
    end
    return midi
end

---@return Item
function Take:GetItem()
    return Item(reaper.GetMediaItemTake_Item(self.id))
end

---@class AudioObject : Object
---@operator call: AudioObject
AudioData = Object:extend()

---@param take Take
---@param sr integer
---@param nch integer
function AudioData:new(take, sr, nch, blockSize)
    self.accessor = reaper.CreateTakeAudioAccessor(take.id)
    self.sr = sr
    self.nch = nch
    self.initSize = blockSize
end

function AudioData:__close()
    reaper.DestroyAudioAccessor(self.accessor)
end

function AudioData:FoldToFirstChannel()
    local raw <const> = self.buffer.table()
    local mixed = {}
    for i = 0, #self.buffer / self.nch do
        local index <const> = self.nch * 2 * i
        local re <const> = raw[index + 1]
        table.insert(mixed, re)
        local im <const> = raw[index + 2]
        table.insert(mixed, im)
    end
    self.buffer = reaper.new_array(mixed)
    return self
end

function AudioData:Fill(start, blockSize)
    self.buffer = reaper.new_array(blockSize * self.nch)
    self.buffer.clear()
    reaper.GetAudioAccessorSamples(self.accessor, self.sr, self.nch, start, blockSize, self.buffer)
    return self
end

function AudioData:Window()
    --- https://stackoverflow.com/questions/3555318/implement-hann-window
    local buffer = self.buffer.table()
    local size <const> = #buffer
    local out = {}
    for i = 1, size do
        local mult <const> = 0.5 * (1 - math.cos(2 * math.pi * i / size))
        out[i] = mult * buffer[i]
    end
    self.buffer = reaper.new_array(out)
    return self
end

function AudioData:ApplyFFTReal(fftsize, permute)
    fftsize = fftsize or self.buffer.get_alloc()
    permute = permute or true
    local size <const> = math.max(self.buffer.get_alloc(), fftsize * 2)
    local out = reaper.new_array(size) ---@type reaper.array
    out.clear()
    out.copy(self.buffer)
    out.fft_real(fftsize, permute)
    self.buffer = reaper.new_array(out)
    return self
end

function AudioData:GetRaw()
    return self.buffer
end

---@param normalize boolean # should preserve loudness
function AudioData:GetMagnitude(normalize)
    normalize = normalize or false
    local buffer <const> = self.buffer.table()
    local out = {}
    local normalRecip = normalize and 1 / (self.initSize * 0.5) or 1
    for i = 1, #buffer / 2 do
        local re <const> = buffer[i * 2 - 1]
        local im <const> = buffer[i * 2]

        local mag <const> = math.sqrt(re ^ 2 + im ^ 2) * normalRecip
        table.insert(out, normalize and mag)
    end
    return out
end

---@param blockSize integer
---@return reaper.array
function Take:GetFFT(blockSize, fftSize, overlap)
    local source <const> = self:GetSource()

    local sr <const> = source:GetSampleRate()
    local nch <const> = source:GetChannelCount()

    local audio <close> = AudioData(self, sr, nch, blockSize)
    local hopSize <const> = blockSize / overlap / sr

    local timeStart = 0
    local timeEnd <const> = self:GetItem():GetValue("D_LENGTH")

    local hold = {}
    while timeStart < timeEnd do
        local spectrum = audio:Fill(timeStart, blockSize)
            :FoldToFirstChannel()
            :Window()
            :ApplyFFTReal(fftSize)
            :GetMagnitude(true)

        for i = 1, #spectrum do
            if hold[i] == nil then hold[i] = 0 end
            if spectrum[i] > hold[i] then hold[i] = spectrum[i] end
        end

        timeStart = timeStart + hopSize -- move along half a block to overlap
    end

    do -- remove second half
        for i = #hold / 2 + 1, #hold do
            hold[i] = nil
        end
    end

    return reaper.new_array(hold)
end

---@class FXData
---@field param integer
---@field min number
---@field max number
---@field val number

---@param index integer #
---@return FXData[]
function Take:GetFX(index)
    local parameter = 0
    local rv = true
    local buf = ""

    local data = {} ---@type FXData[]
    while true do
        rv, buf = reaper.TakeFX_GetParamName(self.id, index, parameter)
        if not rv then break end
        local _, minval, maxval = reaper.TakeFX_GetParam(self.id, index, parameter)
        local value = reaper.TakeFX_GetParam(self.id, index, parameter)
        data[buf] = {
            param = parameter,
            min = minval,
            max = maxval,
            val = value
        }
        parameter = parameter + 1
    end

    return data
end

function Take:SetEQ(array)
    local fx = self:GetFX(0)
    for i, value in ipairs(array) do
        local paramBand <const> = fx["Gain-Band " .. tostring(i)].param
        local paramFreq <const> = fx["Freq-Band " .. tostring(i)].param
        local paramBW <const> = fx["BW-Band " .. tostring(i)].param

        local freq <const> = value.freq
        local freqVal <const> = ReaEQFreqToVal(freq)
        local scaledVal <const> = value.average + 0.25

        reaper.TakeFX_SetParam(self.id, 0, paramBand, scaledVal)
        reaper.TakeFX_SetParam(self.id, 0, paramFreq, freqVal)
        reaper.TakeFX_SetParam(self.id, 0, paramBW, 0.05)
    end
end

return Take
