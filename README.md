# moony-lv2-scripts

A collection of Lua scripts for the [Moony] LV2 plugin


## MIDI Filters

* [CC to Channel Pressure](midi/cc2channelpressure.lua)

    Converts specific Control Change events to MIDI Channel Pressure
    (aka Mono Aftertouch).

* [Channel Pressure to CC](midi/channelpressure2cc.lua)

    Converts MIDI Channel Pressure (aka Mono Aftertouch) to Control Change
    events.

* [Note to CC](midi/note2cc.lua)

    Converts Note On / Note Off events into Control Change events providing
    many options.

* [Poly Pressure to Note On](midi/polyat2noteon.lua)

    Converts MIDI Poly Pressure (aka Poly Aftertouch) to Note On events.

* [Scale Velocity](midi/scale_velocity.lua)

    Scales velocity of note-on and note-off events by a given factor
    and/or add a fixed offset value to the velocity. The affected events
    can be restricted to a certain MIDI channel and/or note ranges.


[Moony]: https://open-music-kontrollers.ch/lv2/moony/
