-- Convert specific Control Change events to MIDI Channel Pressure (aka Mono Aftertouch)

local version = "0.2.0"
print("Loading cc2channelpressure filter version " .. version .. " ...")

-- define URI prefix for state parameters
local urn = Mapper('urn:uuid:278c7f88-f157-11ea-ad34-3c970e9a9ec9#')
local midiR

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
-- which control change number to convert?
local source_cc = Parameter {
  [RDFS.label] = 'Source CC',
  [RDFS.comment] = 'Set control change number to convert from',
  [RDFS.range] = Atom.Int,
  [LV2.minimum] = 0,
  [LV2.maximum] = 127,
  [RDF.value] = 1
}
-- whether to pass unmatched CC or other events
local pass_unmatched = Parameter {
  [RDFS.label] = 'Pass umatched?',
  [RDFS.comment] = 'Should events not matched by filter be passed through?',
  [RDFS.range] = Atom.Bool,
  _value = true,
  [Patch.Get] = function (self)
    return self._value
  end,
  [Patch.Set] = function (self, value)
    self._value = value
    midiR.through = value
  end
}


-- define a StateResponder object
local stateR = StateResponder({
  [Patch.writable] = {
    [urn.filter_chan] = filter_chan,
    [urn.source_cc] = source_cc,
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


function cc2channelpressure(self, frames, forge, chan, cc, value)
  if (filter_chan() == -1 or chan == filter_chan() and cc == source_cc()) then
    forge:time(frames):midi(MIDI.ChannelPressure | chan, value)
  elseif pass_unmatched() then
    forge:time(frames):midi(MIDI.Controller | chan, cc, value)
  end
end


-- define a MIDIResponder object to handle control change events
midiR = MIDIResponder({
  [MIDI.Controller] = cc2channelpressure,
}, pass_unmatched())


-- the main processing function
function run(n, control, notify, seq, forge)
  -- iterate over incoming control events
  for frames, atom in control:foreach() do
    stateR(frames, notify, atom)
  end
  -- iterate over incoming sequence events
  for frames, atom in seq:foreach() do
    midiR(frames, forge, atom)
  end
end

print("Loading cc2channelpressure2 complete.")
