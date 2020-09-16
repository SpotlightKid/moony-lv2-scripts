-- Convert MIDI Note On/Off to Control Change events

local version = "0.1.0"
print("Loading note2cc filter version " .. version .. " ...")

-- define URI prefix for state parameters
local urn = Mapper('urn:uuid:b5dc6500-f459-11ea-a971-3c970e9a9ec9#')

-- for storing which notes are currently "on"
local note_state = {}
for i = 1, 16 do
  table.insert(note_state, {})
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
                t[n] = true
            end
        end
    end
    return t
end

-- define parameters

-- on which MIDI channel(s) is the conversion applied?
-- 0..15 or set to -1 to apply to events on all channels
local filter_chan = Parameter({
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
})

-- how is the controller *number* in the converted event determined?
local controller_source = Parameter({
  [RDFS.label] = 'Controller source',
  [RDFS.comment] = 'Set source of controller number.',
  [RDFS.range] = Atom.Int,
  [RDF.value] = 0,
  [LV2.minimum] = 0,
  [LV2.maximum] = 1,
  [LV2.scalePoint] = {
    ["Fixed CC#"] = 0,
    ["Note# -> CC#"] = 1,
  }
})

-- how is the controller *value* in the converted event determined?
local value_source = Parameter({
  [RDFS.label] = 'Value source',
  [RDFS.comment] = 'Set source of controller value.',
  [RDFS.range] = Atom.Int,
  [RDF.value] = 0,
  [LV2.minimum] = 0,
  [LV2.maximum] = 2,
  [LV2.scalePoint] = {
    ["On/Off value"] = 0,
    ["Velocity (Momentary mode only)"] = 1,
    ["Note# (Momentary mode only)"] = 2,
  }
})

-- how are "on" and "off" values sent?
-- "Momentary" = NoteOn sends "on" value, NoteOff sends "off" value
-- "Toggle" = First NoteOn sends "on" value, second NoteOn sends "off" value
local trigger_mode = Parameter({
  [RDFS.label] = 'Trigger mode',
  [RDFS.comment] = 'Set mode in which "on" / "off" values are triggered.',
  [RDFS.range] = Atom.Int,
  [RDF.value] = 0,
  [LV2.minimum] = 0,
  [LV2.maximum] = 1,
  [LV2.scalePoint] = {
    ["Momentary"] = 0,
    ["Toggle"] = 1,
  }
})

-- which note(s) numbers to convert?
-- I.e. which note range(s) does the filter affect?
-- A string with a comma-separated list of single MIDI note numbers or
-- ranges (min-max separated by a dash, whitespace is ignored)
-- Example: "0-12, 36,48, 60 - 96"
local source_notes = Parameter({
  [RDFS.label] = 'Note Range(s)',
  [RDFS.comment] = 'Set note(s) or range(s) of notes to convert, e.g. "0-12, 36,48, 60 - 96"',
  [RDFS.range] = Atom.String,
  _value = '60',
  _note_map = {},
  [Patch.Get] = function(self)
    return self._value
  end,
  [Patch.Set] = function(self, value)
    self._value = value
    self._note_map = expand_ranges(value)
  end,
  match = function(self, note)
    return self._note_map[note]
  end
})

-- should note-off events be ignored?
local ignore_noteoff = Parameter({
  [RDFS.label] = 'Ignore note-off?',
  [RDFS.comment] = 'Should note-off events be ignored (unused in "Toggle mode)?',
  [RDFS.range] = Atom.Bool,
  [RDF.value] = false
})

-- which controller number to convert to?
-- (when "Fixed CC" is selected as controller number source)
local dest_cc = Parameter({
  [RDFS.label] = 'Destination CC',
  [RDFS.comment] = 'Set controller number to convert to',
  [RDFS.range] = Atom.Int,
  [LV2.minimum] = 0,
  [LV2.maximum] = 127,
  [RDF.value] = 1,
})

-- what is the controller "on" value?
-- (when "On/Off value" is selected as value source)
local on_value = Parameter({
  [RDFS.label] = 'On value',
  [RDFS.comment] = 'Set controller "on" value',
  [RDFS.range] = Atom.Int,
  [LV2.minimum] = 0,
  [LV2.maximum] = 127,
  [RDF.value] = 127
})

-- what is the controller "off" value?
-- (when "On/Off value" is selected as value source)
local off_value = Parameter({
  [RDFS.label] = 'Off value',
  [RDFS.comment] = 'Set controller "off" value',
  [RDFS.range] = Atom.Int,
  [LV2.minimum] = 0,
  [LV2.maximum] = 127,
  [RDF.value] = 0
})

-- whether to pass unmatched mono AT or other events
local pass_unmatched = Parameter({
  [RDFS.label] = 'Pass umatched?',
  [RDFS.comment] = 'Should events not matched by filter be passed through?',
  [RDFS.range] = Atom.Bool,
  [RDF.value] = true
})

-- define a StateResponder object
local stateR = StateResponder({
  [Patch.writable] = {
    [urn.filter_chan] = filter_chan,
    [urn.controller_source] = controller_source,
    [urn.value_source] = value_source,
    [urn.trigger_mode] = trigger_mode,
    [urn.source_notes] = source_notes,
    [urn.ignore_noteoff] = ignore_noteoff,
    [urn.dest_cc] = dest_cc,
    [urn.on_value] = on_value,
    [urn.off_value] = off_value,
    [urn.pass_unmatched] = pass_unmatched,
  }
})

-- convert channel pressure events if MIDI channel matches
function note2cc(frames, forge, cmd, chan, note, velocity)
  if cmd == MIDI.NoteOff and (ignore_noteoff() or trigger_mode() == 1) then
    return
  end

  if cmd == MIDI.NoteOn then
    if note_state[chan+1][note] then
      note_state[chan+1][note] = nil
    else
      note_state[chan+1][note] = true
    end
  end

  local csrc = controller_source()
  local vsrc = value_source()
  local value

  if trigger_mode() == 1 then  -- Toggle
    if note_state[chan+1][note] then
      value = on_value()
    else
      value = off_value()
    end
  else  -- Momentary
    if vsrc == 0 then  -- On/Off value
      if cmd == MIDI.NoteOn then
        value = on_value()
      else
        value = off_value()
      end
    elseif vsrc == 1 then  -- Velocity
      value = velocity
    elseif vsrc == 2 then  -- Note#
      value = note
    end
  end

  if csrc == 0 then  -- Fixed CC
    forge:time(frames):midi(MIDI.Controller | chan, dest_cc(), value)
  elseif csrc == 1 then -- Note# -> CC#
    forge:time(frames):midi(MIDI.Controller | chan, note, value)
  end
end

-- note responder function factory
local function note_responder(cmd)
  return function(self, frames, forge, chan, note, velocity)
    if (filter_chan() == -1 or chan == filter_chan()) and source_notes:match(note) then
      note2cc(frames, forge, cmd, chan, note, velocity)
    elseif pass_unmatched() then
      forge:time(frames):midi(cmd | chan, note, velocity)
    end
  end
end

-- define a MIDIResponder object to handle note-on and note-off events
local midiR = MIDIResponder({
  [MIDI.NoteOn] = note_responder(MIDI.NoteOn),
  [MIDI.NoteOff] = note_responder(MIDI.NoteOff)
}, false)

-- Callbacks

-- push current responder state to temporary stash
function stash(forge)
  stateR:stash(forge)
end

-- pop and apply current responder state from temporary stash
function apply(atom)
  stateR:apply(atom)
end

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

-- the main processing function
function run(n, control, notify, seq, forge)
  -- iterate over incoming control events
  for frames, atom in control:foreach() do
    stateR(frames, notify, atom)
  end
  -- iterate over incoming sequence events
  for frames, atom in seq:foreach() do
    midiR(frames, forge, atom)

    if pass_unmatched() and not (atom[1] == MIDI.NoteOn or atom[1] == MIDI.NoteOff) then
      forge:time(frames):atom(atom)
    end
  end
end

print("Loading note2cc complete.")
