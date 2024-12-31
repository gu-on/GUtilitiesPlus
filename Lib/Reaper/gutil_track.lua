-- @noindex

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

require('lua.gutil_classic')

---@alias TrackParamName_Number
---| '"B_MUTE"' # muted
---| '"B_PHASE"' # track phase inverted
---| '"B_RECMON_IN_EFFECT"' # record monitoring in effect (current audio-thread playback state, read-only)
---| '"IP_TRACKNUMBER"' # track number 1-based, 0=not found, -1=master track (read-only, returns the int directly)
---| '"I_SOLO"' # soloed, 0=not soloed, 1=soloed, 2=soloed in place, 5=safe soloed, 6=safe soloed in place
---| '"B_SOLO_DEFEAT"' # when set, if anything else is soloed and this track is not muted, this track acts soloed
---| '"I_FXEN"' # fx enabled, 0=bypassed, !0=fx active
---| '"I_RECARM"' # record armed, 0=not record armed, 1=record armed
---| '"I_RECINPUT"' # record input, <0=no input. if 4096 set, input is MIDI and low 5 bits represent channel (0=all, 1-16=only chan), next 6 bits represent physical input (63=all, 62=VKB). If 4096 is not set, low 10 bits (0..1023) are input start channel (ReaRoute/Loopback start at 512). If 2048 is set, input is multichannel input (using track channel count), or if 1024 is set, input is stereo input, otherwise input is mono.
---| '"I_RECMODE"' # record mode, 0=input, 1=stereo out, 2=none, 3=stereo out w/latency compensation, 4=midi output, 5=mono out, 6=mono out w/ latency compensation, 7=midi overdub, 8=midi replace
---| '"I_RECMODE_FLAGS"' # record mode flags, &3=output recording mode (0=post fader, 1=pre-fx, 2=post-fx/pre-fader)
---| '"I_RECMON"' # record monitoring, 0=off, 1=normal, 2=not when playing (tape style)
---| '"I_RECMONITEMS"' # monitor items while recording, 0=off, 1=on
---| '"B_AUTO_RECARM"' # automatically set record arm when selected (does not immediately affect recarm state, script should set directly if desired)
---| '"I_VUMODE"' # track vu mode, &1:disabled, &30==0:stereo peaks, &30==2:multichannel peaks, &30==4:stereo RMS, &30==8:combined RMS, &30==12:LUFS-M, &30==16:LUFS-S (readout=max), &30==20:LUFS-S (readout=current), &32:LUFS calculation on channels 1+2 only
---| '"I_AUTOMODE"' # track automation mode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
---| '"I_NCHAN"' # number of track channels, 2-128, even numbers only
---| '"I_SELECTED"' # track selected, 0=unselected, 1=selected
---| '"I_WNDH"' # current TCP window height in pixels including envelopes (read-only)
---| '"I_TCPH"' # current TCP window height in pixels not including envelopes (read-only)
---| '"I_TCPY"' # current TCP window Y-position in pixels relative to top of arrange view (read-only)
---| '"I_MCPX"' # current MCP X-position in pixels relative to mixer container (read-only)
---| '"I_MCPY"' # current MCP Y-position in pixels relative to mixer container (read-only)
---| '"I_MCPW"' # current MCP width in pixels (read-only)
---| '"I_MCPH"' # current MCP height in pixels (read-only)
---| '"I_FOLDERDEPTH"' # folder depth change, 0=normal, 1=track is a folder parent, -1=track is the last in the innermost folder, -2=track is the last in the innermost and next-innermost folders, etc
---| '"I_FOLDERCOMPACT"' # folder collapsed state (only valid on folders), 0=normal, 1=collapsed, 2=fully collapsed
---| '"I_MIDIHWOUT"' # track midi hardware output index, <0=disabled, low 5 bits are which channels (0=all, 1-16), next 5 bits are output device index (0-31)
---| '"I_MIDI_INPUT_CHANMAP"' # -1 maps to source channel, otherwise 1-16 to map to MIDI channel
---| '"I_MIDI_CTL_CHAN"' # -1 no link, 0-15 link to MIDI volume/pan on channel, 16 link to MIDI volume/pan on all channels
---| '"I_MIDI_TRACKSEL_FLAG"' # MIDI editor track list options: &1=expand media items, &2=exclude from list, &4=auto-pruned
---| '"I_PERFFLAGS"' # track performance flags, &1=no media buffering, &2=no anticipative FX
---| '"I_CUSTOMCOLOR"' # custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
---| '"I_HEIGHTOVERRIDE"' # custom height override for TCP window, 0 for none, otherwise size in pixels
---| '"I_SPACER"' # 1=TCP track spacer above this trackB_HEIGHTLOCK"' # track height lock (must set I_HEIGHTOVERRIDE before locking)
---| '"D_VOL"' # trim volume of track, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
---| '"D_PAN"' # trim pan of track, -1..1
---| '"D_WIDTH"' # width of track, -1..1
---| '"D_DUALPANL"' # dualpan position 1, -1..1, only if I_PANMODE==6
---| '"D_DUALPANR"' # dualpan position 2, -1..1, only if I_PANMODE==6
---| '"I_PANMODE"' # pan mode, 0=classic 3.x, 3=new balance, 5=stereo pan, 6=dual pan
---| '"D_PANLAW"' # pan law of track, <0=project default, 0.5=-6dB, 0.707..=-3dB, 1=+0dB, 1.414..=-3dB with gain compensation, 2=-6dB with gain compensation, etc
---| '"I_PANLAW_FLAGS"' # pan law flags, 0=sine taper, 1=hybrid taper with deprecated behavior when gain compensation enabled, 2=linear taper, 3=hybrid taper
---| '"B_SHOWINMIXER"' # track control panel visible in mixer (do not use on master track)
---| '"B_SHOWINTCP"' # track control panel visible in arrange view (do not use on master track)
---| '"B_MAINSEND"' # track sends audio to parent
---| '"C_MAINSEND_OFFS"' # channel offset of track send to parent
---| '"C_MAINSEND_NCH"' # channel count of track send to parent (0=use all child track channels, 1=use one channel only)
---| '"I_FREEMODE"' # 1=track free item positioning enabled, 2=track fixed lanes enabled (call UpdateTimeline() after changing)
---| '"I_NUMFIXEDLANES"' # number of track fixed lanes (fine to call with setNewValue, but returned value is read-only)
---| '"C_LANESCOLLAPSED"' # fixed lane collapse state (1=lanes collapsed, 2=track displays as non-fixed-lanes but hidden lanes exist)
---| '"C_LANESETTINGS"' # fixed lane settings (&1=auto-remove empty lanes at bottom, &2=do not auto-comp new recording, &4=newly recorded lanes play exclusively (else add lanes in layers), &8=big lanes (else small lanes), &16=add new recording at bottom (else record into first available lane), &32=hide lane buttons
---| '"C_LANEPLAYS:N"' # on fixed lane tracks, 0=lane N does not play, 1=lane N plays exclusively, 2=lane N plays and other lanes also play (fine to call with setNewValue, but returned value is read-only)
---| '"C_ALLLANESPLAY"' # on fixed lane tracks, 0=no lanes play, 1=all lanes play, 2=some lanes play (fine to call with setNewValue 0 or 1, but returned value is read-only)
---| '"C_BEATATTACHMODE"' # track timebase, -1=project default, 0=time, 1=beats (position, length, rate), 2=beats (position only)
---| '"F_MCP_FXSEND_SCALE"' # scale of fx+send area in MCP (0=minimum allowed, 1=maximum allowed)
---| '"F_MCP_FXPARM_SCALE"' # scale of fx parameter area in MCP (0=minimum allowed, 1=maximum allowed)
---| '"F_MCP_SENDRGN_SCALE"' # scale of send area as proportion of the fx+send total area (0=minimum allowed, 1=maximum allowed)
---| '"F_TCP_FXPARM_SCALE"' # scale of TCP parameter area when TCP FX are embedded (0=min allowed, default, 1=max allowed)
---| '"I_PLAY_OFFSET_FLAG"' # track media playback offset state, &1=bypassed, &2=offset value is measured in samples (otherwise measured in seconds)

---@alias TrackParamName_String
---| '"P_NAME"' # track name (on master returns NULL)
---| '"P_ICON"' # track icon (full filename, or relative to resource_path/data/track_icons)
---| '"P_LANENAME:"' # lane name (returns NULL for non-fixed-lane-tracks)
---| '"P_MCP_LAYOUT"' # layout name
---| '"P_RAZOREDITS"' # list of razor edit areas, as space-separated triples of start time, end time, and envelope GUID string. Example: "0.0 1.0 \"\" 0.0 1.0 "{xyz-...}"
---| '"P_RAZOREDITS_EXT"' # list of razor edit areas, as comma-separated sets of space-separated tuples of start time, end time, optional: envelope GUID string, fixed/fipm top y-position, fixed/fipm bottom y-position. Example: "0.0 1.0,0.0 1.0 "{xyz-...}",1.0 2.0 "" 0.25 0.75"
---| '"P_TCP_LAYOUT"' # layout name
---| '"P_EXT:"' # extension-specific persistent data
---| '"P_UI_RECT:"' # read-only, allows querying screen position + size of track WALTER elements (tcp.size queries screen position and size of entire TCP, etc).
---| '"GUID"' # 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.

---@class Track : Object
---@operator call: Track
Track = Object:extend()

---@param id MediaTrack
function Track:new(id)
    self.id = id
end

---@param other Track
function Track:__eq(other) return self.id == other.id end

function Track:__tostring() return tostring(self.id) end

---@param name string
---@param position number
---@param length number
function Track:CreateBlankItem(name, position, length)
    local item <const> = Item(reaper.AddMediaItemToTrack(self.id)) ---@type Item
    item:CreateBlankTake(name)
    item:SetString("P_NOTES", name)
    item:SetValue("D_POSITION", position)
    item:SetValue("D_LENGTH", length)
    return item
end

---@param name string
---@param position number
function Track:CreateNewItem(name, position)
    local item <const> = Item(reaper.AddMediaItemToTrack(self.id)) ---@type Item
    local take <const> = item:CreateNewTake(name)
    item:SetValue("D_POSITION", position)
    item:SetValue("D_LENGTH", take:GetSourceLength())
    return item
end

function Track:DeleteItems()
    for i = reaper.CountTrackMediaItems(self.id), 1, -1 do -- reverse
        local item <const> = reaper.GetTrackMediaItem(self.id, i)
        if item then reaper.DeleteTrackMediaItem(self.id, item) end
    end
end

function Track:GetDepth() return reaper.GetTrackDepth(self.id) end

---Gets the top-most parent Track
---@return Track
function Track:GetPrimogenitor()
    local track = self.id
    while reaper.GetParentTrack(track) do
        track = reaper.GetParentTrack(track)
    end
    return Track(track)
end

---@param param TrackParamName_String
---@return string
---@nodiscard
function Track:GetString(param) return select(2, reaper.GetSetMediaTrackInfo_String(self.id, param, "", false)) end

---@param param TrackParamName_Number
---@return number
---@nodiscard
function Track:GetValue(param) return reaper.GetMediaTrackInfo_Value(self.id, param) end

---@param param TrackParamName_String
---@param value string
function Track:SetString(param, value) reaper.GetSetMediaTrackInfo_String(self.id, param, value, true) end

---@param param TrackParamName_Number
---@param value number
function Track:SetValue(param, value) reaper.SetMediaTrackInfo_Value(self.id, param, value) end

return Track