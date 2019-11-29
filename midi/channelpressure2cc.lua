-- Convert MIDI Channel Pressure (aka Mono Aftertouch) to Control Change events

-- 0..15 or set to -1 to apply to events on all channels
local filter_chan = -1
-- whether to pass non-polyAT events
local pass_other = true
-- lowest note of affected note range
local dest_cc = 1


-- NO NEED TO CHANGE ANYTHING BELOW

function channelpressure2cc(self, frames, forge, chan, value)
  if (filter_chan == -1 or chan == filter_chan) then
    forge:time(frames):midi(MIDI.Controller | chan, dest_cc, value)
  end
end

-- define a MIDIResponder object to handle note-on and note-off events
local midiR = MIDIResponder({
  [MIDI.ChannelPressure] = channelpressure2cc,
}, pass_other)

function run(n, control, notify, seq, forge)
  -- iterate over incoming events
  for frames, atom in seq:foreach() do
    -- call responder for event
    local handled = midiR(frames, forge, atom)
  end
end
