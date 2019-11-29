-- Convert specific Control Change events to MIDI Channel Pressure (aka Mono Aftertouch)

-- 0..15 or set to -1 to apply to events on all channels
local filter_chan = -1
-- which control change number to convert?
local source_cc = 1
-- whether to pass non-CC and other CC events
local pass_other = true


-- NO NEED TO CHANGE ANYTHING BELOW

function cc2channelpressure(self, frames, forge, chan, cc, value)
  if filter_chan == -1 or chan == filter_chan then
    if cc == source_cc then
        forge:time(frames):midi(MIDI.ChannelPressure | chan, value)
    elseif pass_other then
        forge:time(frames):midi(MIDI.Controller | chan, cc, value)
    end
  end
end

-- define a MIDIResponder object to handle note-on and note-off events
local midiR = MIDIResponder({
  [MIDI.Controller] = cc2channelpressure,
}, pass_other)

function run(n, control, notify, seq, forge)
  -- iterate over incoming events
  for frames, atom in seq:foreach() do
    -- call responder for event
    local handled = midiR(frames, forge, atom)
  end
end
