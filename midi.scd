// MIDI handling with logging and error handling.
(
// Log MIDI event
~postMIDI = { |val, num, chan, src, setParm, setVal|
    var ln = format("src  %\tchan  %\tnum  % ", src, chan, num);
    if (setParm.isNil) {
        ln = ln + format(" | val: %", val);
    } {
        if (setVal.isFloat) { setVal = setVal.round(0.0001) };
        ln = ln + format(" | val: % -> %  (%)", val, setVal, setParm);
    };
    postf("%\n", ln)
};


// MIDI handler wrapper
~withMIDILogging = { |func|
    { |val, num, chan, src|
        var setParm, setVal;
        var result = func.value(val, num, chan, src);

        // Unpack the result if the handler returns parameter info
        if (result.isKindOf(Array)) {
            #setParm, setVal = result;
        } {
            setParm = result;
            setVal = num;
        };
        ~postMIDI.(val, num, chan, src, setParm, setVal);
    }
};


// MIDI handlers
~makeMIDI = ~withErrorHandling.(~withTiming.({
    var srcKeyboard, srcCtlr;

    "> Initializing MIDI sources...".postln;
    if(MIDIClient.initialized.not) {
        MIDIClient.init;
    } {
        MIDIClient.list;
    };
    MIDIIn.connectAll;
    MIDIClient.sources.do { |src|
        postf("  % - %  (%)\n", src.device, src.name, src.uid);
        
        if (src.device == "Minilab3" && src.name == "MIDI" ) {
            srcKeyboard = src.uid
        };
        if (src.device == "USB X-Session" && src.name == "Port 1" ){
            srcCtlr = src.uid
        };
    };
    postf("Keyboard source: %; Controller source: %\n", srcKeyboard, srcCtlr);

    // Arturia MINILAB 3
    // MIDI control messages
    MIDIdef.cc(\ccHandler_ArturiaMINILAB3, ~withMIDILogging.({ |val, num, chan, src|
		var setParm=nil, setVal=nil;
		switch(num)
		{ 86 } { // CC 86 (Knob 1) to Dist xFade
			setVal = val.linlin(0, 127, 0.0, 1.0);
			setParm = "Dist xFade";
			~distSynth.set(\xFade, setVal);
		}
        { 87 } { // CC 87 (Knob 2) to Dist PreGain
            setVal = val.linlin(0, 127, 0.0, 200.0);
            setParm = "Dist PreGain";
            ~distSynth.set(\preGain, setVal);
        }
        { 89 } { // CC 89 (Knob 4) to Dist PostGain
            setVal = val.linlin(0, 127, 0.0, 2.0);
            setParm = "Dist PostGain";
            ~distSynth.set(\postGain, setVal);
        }
        { 90 } { // CC 90 (Knob 5) to Dist Amountß
            setVal = val.linlin(0, 127, 0.0001, 0.9999);
            setParm = "Dist Amount";
            ~distSynth.set(\amount, setVal);
        };

        // Return parameter name and value for logging
        [setParm, setVal]
    }));

    // triggering events with pads
    MIDIdef.noteOn(
        \noteOnKeyPad_ArturiaMINILAB3,
        ~withMIDILogging.({ |vel, num, chan, src|
            var setParm = switch(num)
            { 36 } { \beat_x1 }
            { 37 } { \beat_x2 }
            { 38 } { \pad }
            { 39 } { \pad_s }
            { 40 } { \bass }
            { 41 } { \pulse }
            { 42 } { \melody }
            { "Note ON" }; // Default case

            ~playStopEvent.(setParm, ~tempo);

            // Return parameter name for logging
            setParm
        }),
        chan: 9,
        srcID: srcKeyboard
    );

    // MIDI notes
    MIDIdef.noteOn(
        \noteOnKeyboard_ArturiaMINILAB3,
        ~withMIDILogging.({ |vel, num, chan, src|
            ~setRoot.(num);
            // Return parameter name for logging
            "ROOT"
        }),
        chan: 0,
        srcID: srcKeyboard
    );

    // M-Audio XSession Pro
    // triggering events with knobs
    MIDIdef.noteOn(
        \noteOnKeyPad_MAudioXSessionPro,
        ~withMIDILogging.({ |vel, num, chan, src|
            var setParm = "Note ON";
        }),
        chan: 0,
        srcID: srcCtlr
    );

    MIDIdef.noteOff(\noteOffKeyPad_MAudioXSessionPro,
        ~withMIDILogging.({ |vel, num, chan, src|
            var setParm = "Note OFF";
        }),
        chan: 0,
        srcID: srcCtlr
    );

}));
)