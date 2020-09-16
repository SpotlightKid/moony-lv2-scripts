-- MIDI Note Event Filter/Processor
---
-- This is an example, which passes all events unfiltered / unaltered.
-- Change the 'do_filter' function to customize the filter.

-- affected MIDI channels
-- 0..15 or set to -1 to apply to events on all channels
local filter_chan = -1
-- affected note range(s)
-- string with comma-separated list of single MIDI note numbers or
-- ranges (min-max separated by a dash, whitespace is ignored)
-- example: local note_ranges = "0-12, 36,48, 60 - 96"
local note_ranges = "0-127"
-- whether to pass non-note events or note events outside of affected range(s)
local pass_other = true


-- NO NEED TO CHANGE ANYTHING BELOW

local _filter_notes

local function clamp(val, min, max)
  return val < min and min or (val > max and max or val)
end

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
            for i, n in ipairs(range(tonumber(s), tonumber(e))) do
                t[] = true
            end
        end
    end
    return t
end

local function do_filter(frames, forge, chan, note, vel)
  -- do something with note here
  return true, clamp(chan, 0, 16), clamp(note, 0, 127), clamp(vel, 0, 127)
end

-- note responder function factory
local function note_responder(cmd)
  return function(self, frames, forge, chan, note, vel)
    local pass = pass_other
    if (filter_chan == -1 or chan == filter_chan) and _filter_notes[note] then
      pass, chan, note, vel = do_filter(frames, forge, chan, note, vel)
    end
    if (pass)
      -- send event
      forge:time(frames):midi(cmd | chan, note, vel)
    end
  end
end

function once(n, control, notify, seq, forge)
  _filter_notes = expand_ranges(note_ranges)

  -- define a MIDIResponder object to handle note-on and note-off events
  _midiR = MIDIResponder({
    [MIDI.NoteOn] = note_responder(MIDI.NoteOn),
    [MIDI.NoteOff] = note_responder(MIDI.NoteOff)
  }, pass_other)
end

function run(n, control, notify, seq, forge)
  -- iterate over incoming events
  for frames, atom in seq:foreach() do
    -- call responder for event
    local handled = _midiR(frames, forge, atom)
  end
end
