-- @description GUtilities libraries (essential)
-- @author guonaudio
-- @version 1.0
-- @provides 
--   [nomain] .
--   [nomain] lua/gutil_classic.lua
--   [nomain] lua/gutil_color.lua
--   [nomain] lua/gutil_curve.lua
--   [nomain] lua/gutil_file.lua
--   [nomain] lua/gutil_filesystem.lua
--   [nomain] lua/gutil_maths.lua
--   [nomain] lua/gutil_string.lua
--   [nomain] lua/gutil_table.lua
--   [nomain] reaper/gutil_action.lua
--   [nomain] reaper/gutil_cmd.lua
--   [nomain] reaper/gutil_config.lua
--   [nomain] reaper/gutil_dependency.lua
--   [nomain] reaper/gutil_dialog.lua
--   [nomain] reaper/gutil_gui.lua
--   [nomain] reaper/gutil_item.lua
--   [nomain] reaper/gutil_os.lua
--   [nomain] reaper/gutil_progressbar.lua
--   [nomain] reaper/gutil_project.lua
--   [nomain] reaper/gutil_source.lua
--   [nomain] reaper/gutil_take.lua
--   [nomain] reaper/gutil_track.lua
--   [nomain] full/sourcevalidator.lua
-- @changelog
--   Initial Release
-- @about
--   Main library for handling all other required libraries

local requirePath <const> = debug.getinfo(1).source:match("@?(.*[\\|/])") .. '../lib/?.lua'
package.path = package.path:find(requirePath) and package.path or package.path .. ";" .. requirePath

Dependency = require('reaper.gutil_dependency')
Dependency.CheckAll()

reaper.AudioFormats = { "WAV", "AIFF", "FLAC", "MP3", "OGG", "BWF", "W64", "WAVPACK" }

---@param e string|number
---@return integer
---@diagnostic disable-next-line: lowercase-global
function toint(e) return math.floor(e and tonumber(e) or 0) end

---@alias CommandID
---| 40245 # Peaks: Build any missing peaks for selected items

---@alias UndoState
---| -1 # All = -1,
---| 1 # TrackCFG = 1 << 0,   -- track/master vol/pan/routing, routing/hwout envelopes too
---| 2 # FX = 1 << 1,         -- track/master fx
---| 4 # Items = 1 << 2,      -- track items
---| 8 # MiscCFG = 1 << 3,    -- loop selection, markers, regions, extensions
---| 16 # Freeze = 1 << 4,     -- freeze state
---| 32 # TrackENV = 1 << 5,   -- non-FX envelopes only
---| 64 # FxENV = 1 << 6,      -- FX envelopes, implied by UNDO_STATE_FX too
---| 128 # PooledENVS = 1 << 7, -- contents of automation items -- not position, length, rate etc of automation items, which is part of envelope state
---| 256 # ARA = 1 << 8         -- ARA state

---@alias FadeDirection
---| 0 # In
---| 1 # Out

---@alias FadeShapeIndex
---| 0 # linear
---| 1 # fastStart
---| 2 # fastEnd
---| 3 # fastStartSteep
---| 4 # fastEndSteep
---| 5 # slowStartEnd
---| 6 # slowStartEndSteep

---@alias FadeShapeName
---| '"linear"' # 0
---| '"fastStart"' # 1
---| '"fastEnd"' # 2
---| '"fastStartSteep"' # 3
---| '"fastEndSteep"' # 4
---| '"slowStartEnd"' # 5
---| '"slowStartEndSteep"' # 6

---@alias NormalizationType
---| 0 # LUFS_I
---| 1 # RMS
---| 2 # PEAK
---| 3 # TRUE_PEAK
---| 4 # LUFS_M
---| 5 # LUFS_S

---@alias MediaFlag
---| -1 # RESET
---| 0 # ALL
---| 1 # WAV 1 << 0
---| 2 # AIFF 1 << 1
---| 4 # FLAC 1 << 2
---| 8 # MP3 1 << 3
---| 16 # OGG 1 << 4
---| 32 # BWF 1 << 5
---| 64 # W64 1 << 6
---| 128 # WAVPACK 1 << 7
---| 256 # GIF 1 << 8
---| 512 # MP4 1 << 9