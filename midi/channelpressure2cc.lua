-- Convert MIDI Channel Pressure (aka Mono Aftertouch) to Control Change events

local version = "0.2.0"
print("Loading channelpressure2cc filter version " .. version .. " ...")

-- define URI prefix for state parameters
local urn = Mapper('urn:uuid:a21213a2-f14e-11ea-ad18-3c970e9a9ec9#')

-- define parameters
-- 0..15 or set to -1 to apply to events on all channels
local filter_chan = Parameter {
  [RDFS.label] = 'Filter channel',
  [RDFS.comment] = 'Set MIDI channel to which this filter is applied.',
  [RDFS.range] = Atom.Int,
  [RDF.value] = -1,
  [LV2.minimum] = -1,
  [LV2.maximum] = 15,
  [LV2.scalePoint] = {
    ["All Channels"] = -1,
    ["Channel 1"] = 0,
    ["Channel 2"] = 1,
    ["Channel 3"] = 2,
    ["Channel 4"] = 3,
    ["Channel 5"] = 4,
    ["Channel 6"] = 5,
    ["Channel 7"] = 6,
    ["Channel 8"] = 7,
    ["Channel 9"] = 8,
    ["Channel 10"] = 9,
    ["Channel 11"] = 10,
    ["Channel 12"] = 11,
    ["Channel 13"] = 12,
    ["Channel 14"] = 13,
    ["Channel 15"] = 14,
    ["Channel 16"] = 15,
  }
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
-- whether to pass unmatched mono AT or other events
local pass_unmatched = Parameter {
  [RDFS.label] = 'Pass umatched?',
  [RDFS.comment] = 'Should events not matched by filter be passed through?',
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


-- convert  channel pressure events if MIDI channel matches
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
}, false)


-- the main processing function
function run(n, control, notify, seq, forge)
  -- iterate over incoming control events
  for frames, atom in control:foreach() do
    stateR(frames, notify, atom)
  end
  -- iterate over incoming sequence events
  for frames, atom in seq:foreach() do
    midiR(frames, forge, atom)

    if pass_unmatched() and atom[1] ~= MIDI.ChannelPressure then
      forge:time(frames):atom(atom)
    end
  end
end

print("Loading channelpressure2cc complete.")
