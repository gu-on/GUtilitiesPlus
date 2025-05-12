---@alias MidiKey "C"|"C#"|"D"|"D#"|"E"|"F"|"F#"|"G"|"G#"|"A"|"A#"|"B"
---@alias MidiValue -1|0|1|2|3|4|5|6|7|8|9|10|11

---@class (exact) MidiPair
---@field key MidiKey
---@field val MidiValue

---@class MIDI
---@field MAP MidiPair[]
MIDI = {}

MIDI.MIN = 0
MIDI.MAX = 127
MIDI.OFFSET = -12 -- Default Reaper is C-1 = 0
MIDI.NOTEPEROCTAVE = 12
MIDI.NA = -1
MIDI.MAP = {
    { key = "C",  val = 0 }, { key = "C#", val = 1 }, { key = "D", val = 2 },
    { key = "D#", val = 3 }, { key = "E", val = 4 }, { key = "F", val = 5 },
    { key = "F#", val = 6 }, { key = "G", val = 7 }, { key = "G#", val = 8 },
    { key = "A",  val = 9 }, { key = "A#", val = 10 }, { key = "B", val = 11 }
}

---@param key MidiKey
---@return MidiValue
function MIDI.GetValue(key)
    for _, midi in pairs(MIDI.MAP) do
        if midi.key == key then return midi.val end
    end
    return MIDI.NA
end

---@param val number
---@return MidiKey
function MIDI.GetKey(val)
    val = val + MIDI.OFFSET
    local octave = 0
    if val < 0 then
        while val < 0 do
            val = val + 12
            octave = octave - 1
        end
    else
        while val >= 12 do
            val = val - 12
            octave = octave + 1
        end
    end

    for _, midi in pairs(MIDI.MAP) do
        if midi.val == val then return midi.key .. tostring(octave) end
    end
    return tostring(MIDI.NA)
end

---Extracts musical note letter + sharp symbol (if relevant)
---@param input string
---@nodiscard
function MIDI.ExtractNote(input)
    if input == nil then return "" end
    local letters <const> = {}
    for letter in input:gmatch("%a+") do
        table.insert(letters, letter)
    end
    for letter in input:gmatch("#") do
        table.insert(letters, letter)
    end
    return table.concat(letters)
end

return MIDI