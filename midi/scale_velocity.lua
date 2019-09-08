-- MIDI Velocity Scaling for Note Range

-- 0..15 or set to -1 to apply to events on all channels
local filter_chan = -1
-- whether to pass non-note events
local pass_other = true
-- lowest note of affected note range
local note_low = 0
-- highest note of affected note range
local note_high = 127

-- scale incoming velocity values by this factor
-- (affects note-on and note-off events)
local vel_scale = 0.9
-- offset value to add to velocity after scaling
local vel_offset = 0
-- clamp resulting velocity to this range
local vel_min = 0
local vel_max = 127

-- NO NEED TO CHANGE ANYTHING BELOW

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
    if (filter_chan == -1 or chan == filter_chan) and (note >= note_low and note <= note_high) then
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

-- define a MIDIResponder object to handle note-on and note-off events
local midiR = MIDIResponder({
  [MIDI.NoteOn] = note_responder(MIDI.NoteOn),
  [MIDI.NoteOff] = note_responder(MIDI.NoteOff)
}, pass_other)

function run(n, control, notify, seq, forge)
  -- iterate over incoming events
  for frames, atom in seq:foreach() do
    -- call responder for event
    local handled = midiR(frames, forge, atom)
  end
end

