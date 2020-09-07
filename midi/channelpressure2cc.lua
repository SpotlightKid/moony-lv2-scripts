-- Convert MIDI Channel Pressure (aka Mono Aftertouch) to Control Change events

-- version 0.2.0

-- define URI prefix for state parameters
local urn = Mapper('urn:uuid:a21213a2-f14e-11ea-ad18-3c970e9a9ec9#')

-- 0..15 or set to -1 to apply to events on all channels
local filter_chan = Parameter {
  [RDFS.label] = 'Filter channel',
  [RDFS.comment] = 'Set MIDI channel to which this filter is applied. Set to -1 for all channels',
  [RDFS.range] = Atom.Int,
  [LV2.minimum] = -1,
  [LV2.maximum] = 15,
  [RDF.value] = -1
}
-- which control change number to convert to?
local dest_cc = Parameter {
  [RDFS.label] = 'Destination CC',
  [RDFS.comment] = 'Set control change number to convert to',
  [RDFS.range] = Atom.Int,
  [LV2.minimum] = 0,
  [LV2.maximum] = 127,
  [RDF.value] = 1
}
-- whether to pass unmatched mono AT events
local pass_unmatched = Parameter {
  [RDFS.label] = 'Pass unmatched events?',
  [RDFS.comment] = 'Should channel pressure events not on filter channel be passed through?',
  [RDFS.range] = Atom.Bool,
  [RDF.value] = true
}


-- define a StateResponder object
local stateR = StateResponder({
  [Patch.writable] = {
    [urn.filter_chan] = filter_chan,
    [urn.dest_cc] = dest_cc,
    [urn.pass_unmatched] = pass_unmatched,
  }
})

-- push parameter values to disk
function save(forge)
  stateR:stash(forge)
end

-- pop parameter values from disk
function restore(atom)
  stateR:apply(atom)
end

-- register parameters to UI
function once(n, control, notify)
  stateR:register(0, notify)
end


function channelpressure2cc(self, frames, forge, chan, value)
  if filter_chan() == -1 or chan == filter_chan() then
    forge:time(frames):midi(MIDI.Controller | chan, dest_cc(), value)
  elseif pass_unmatched() then
    forge:time(frames):midi(MIDI.ChannelPressure | chan, value)
  end
end

-- define a MIDIResponder object to handle channel pressure events
local midiR = MIDIResponder({
  [MIDI.ChannelPressure] = channelpressure2cc,
}, true)

function run(n, control, notify, seq, forge)
  -- iterate over incoming control events
  for frames, atom in control:foreach() do
    local handled = stateR(frames, notify, atom)
  end
  -- iterate over incoming sequence events
  for frames, atom in seq:foreach() do
    -- call responder for event
    local handled = midiR(frames, forge, atom)
  end
end
