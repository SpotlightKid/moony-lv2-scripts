-- MIDI Velocity Scaling for Note Range

-- 0..15 or set to -1 to apply to events on all channels
local filter_chan = -1
-- whether to pass non-note events
local pass_other = true
-- affected note range(s)
-- string with comma-separated list of single MIDI note numbers or
-- ranges (min-max separated by a dash, whitespace is ignored)
-- example: local note_ranges = "0-12, 36,48, 60 - 96"
local note_ranges = "0-127"

-- scale incoming velocity values by this factor
-- (affects note-on and note-off events)
local vel_scale = 0.9
-- offset value to add to velocity after scaling
local vel_offset = 0
-- clamp resulting velocity to this range
local vel_min = 0
local vel_max = 127

-- NO NEED TO CHANGE ANYTHING BELOW

-- http://rosettacode.org/wiki/Range_expansion#Lua
function range(i, j)
    local t = {}
    for n = i, j, i<j and 1 or -1 do
        t[#t+1] = n
    end
    return t
end

function expand_ranges(rspec)
    local ptn = "([-+]?%d+)%s?-%s?([-+]?%d+)"
    local t = {}

    for v in string.gmatch(rspec, '[^,]+') do
        local s, e = v:match(ptn)

        if s == nil then
            t[tonumber(v)] = true
        else
            for _, n in ipairs(range(tonumber(s), tonumber(e))) do
                t[n] = true
            end
        end
    end
    return t
end

local function scale_velocity(val)
  -- round to lower integer
  val = math.floor(val * vel_scale) + vel_offset
  -- clamp to [vel_min, vel_max]
  return val < vel_min and vel_min or (val > vel_max and vel_max or val)
end

-- note responder function factory
local function note_responder(cmd)
  return function(self, frames, forge, chan, note, vel)
    local vel_new
    if (filter_chan == -1 or chan == filter_chan) and filter_notes[note] ~= nil then
        vel_new = scale_velocity(vel)
    else
        vel_new = vel
    end

    -- set absolute minimum velocity value for NoteOn events to 1
    if vel and (cmd == MIDI.NoteOn and vel_new == 0) then
        vel_new = 1
    end
    -- send event
    forge:time(frames):midi(cmd | chan, note, vel_new)
  end
end

function once(n, control, notify, seq, forge)
    filter_notes = expand_ranges(note_ranges)

    -- define a MIDIResponder object to handle note-on and note-off events
    midiR = MIDIResponder({
      [MIDI.NoteOn] = note_responder(MIDI.NoteOn),
      [MIDI.NoteOff] = note_responder(MIDI.NoteOff)
    }, pass_other)
end

function run(n, control, notify, seq, forge)
  -- iterate over incoming events
  for frames, atom in seq:foreach() do
    -- call responder for event
    local handled = midiR(frames, forge, atom)
  end
end

