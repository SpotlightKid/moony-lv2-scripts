-- Convert MIDI Poly Pressure (aka Poly Aftertouch) to Note On events

-- 0..15 or set to -1 to apply to events on all channels
local filter_chan = -1
-- whether to pass non-poylAT events
local pass_other = true
-- lowest note of affected note range
local note_low = 0
-- highest note of affected note range
local note_high = 127


-- NO NEED TO CHANGE ANYTHING BELOW

function polyat2noteon(self, frames, forge, chan, note, vel)
  if (filter_chan == -1 or chan == filter_chan) and (note >= note_low and note <= note_high) then
    forge:time(frames):midi(MIDI.NoteOn | chan, note, vel)
  end
end

-- define a MIDIResponder object to handle note-on and note-off events
local midiR = MIDIResponder({
  [MIDI.NotePressure] = polyat2noteon,
}, pass_other)

function run(n, control, notify, seq, forge)
  -- iterate over incoming events
  for frames, atom in seq:foreach() do
    -- call responder for event
    local handled = midiR(frames, forge, atom)
  end
end
