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

    // MIDIOut object for sending messages to external synth
    ~midiOut = MIDIOut.newByName("Studio 1824c", "Studio 1824c");

    // Arturia MINILAB 3
    //
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
        { 90 } { // CC 90 (Knob 5) to Dist Amount
            setVal = val.linlin(0, 127, 0.0001, 0.9999);
            setParm = "Dist Amount";
            ~distSynth.set(\amount, setVal);
        }
        { 110 } {
            // CC 110 (Knob 5) to Reverb xFade
            setVal = val.linlin(0, 127, 0.0, 1.0);
            setParm = "Reverb xFade";
            ~reverbSynth.set(\xFade, setVal);
        }
        { 117 } {
            // CC 117 (Knob ) to Reverb dry/wet mix
            setVal = val.linlin(0, 127, 0.1, 1.0);
            setParm = "Reverb mix";
            ~reverbSynth.set(\mix, setVal);
        }
        { 14 } {
            // CC 14 (Slider 1) to Pad Env Attack
            setVal = val.linlin(0, 127, 0.01, 2.0);
            setParm = "Pad Env Attack";
            ~padEnvAtk = setVal;
        }
        { 15 } {
            // CC 15 (Slider 2) to Pad Env Decay
            setVal = val.linlin(0, 127, 0.01, 5.0);
            setParm = "Pad Env Decay";
            ~padEnvDec = setVal;
        }
        { 30 } {
            // CC 30 (Slider 3) to Pad Env Sustain
            setVal = val.linlin(0, 127, 0.01, 5.0);
            setParm = "Pad Env Sustain";
            ~padEnvSus = setVal;
        }
        { 31 } {
            // CC 31 (Slider 4) to Pad Env Release
            setVal = val.linlin(0, 127, 1.0, 10.0);
            setParm = "Pad Env Release";
            ~padEnvRel = setVal;
        };

        // Return parameter name and value for logging
        [setParm, setVal]
    }));

    // Triggering events with pads (channel 9)
    MIDIdef.noteOn(
        \noteOnKeyPad_ArturiaMINILAB3,
        ~withMIDILogging.({ |vel, num, chan, src|
            var setParm = switch(num)
            { 36 } { \beat_8 }
            { 37 } {
                // Before playing beat_16, change off-beat pattern: use either
                // the next pattern in ~beat_16offBeat array, or loop back to
                // first. This will alternate off-beat patterns on each trigger.
                //
                // Warning: this solution is necessary because Pdefn does not
                // allow dynamic indexing directly.
                if (~evnts[\beat_16].isPlaying.not) {
                    ~offBeatIndex = ~offBeatIndex + 1;
                    if (~offBeatIndex >= ~beat_16offBeat.size) {
                        ~offBeatIndex = 0;
                    };
                    postf("Off-beat pattern changed to index: %\n", ~offBeatIndex);
                    Pdefn(\offBeatChoice, ~beat_16offBeat[~offBeatIndex]);
                };
                \beat_16
            }
            { 38 } { \pad }
            { 39 } { \pad_shap }
            { 40 } { \bass }
            { 41 } { \bass_s }
            { 42 } { \pulse }
            { 43 } { \melody }
            { "Note ON" }; // Default case

            ~playStopEvent.(setParm, ~scheduler);

            // Return parameter name for logging
            setParm
        }),
        chan: 9,
        srcID: srcKeyboard
    );

    // Keyboard input (Channel 0)
    MIDIdef.noteOn(
        \noteOnKeyboard_ArturiaMINILAB3,
        ~withMIDILogging.({ |vel, num, chan, src|
            var result, params;
            switch (~midiTrack)
            { \root} {
                ~setRoot.(num);
                result = "ROOT"
            }
            { \synth } {
                params = [
                    \freq, num.midicps,
                    \amp, vel.linlin(0, 127, 0.0, 1.0),
                    \bufnum, ~wt_buf[0..2].choose,
                    \out, ~outPads,
                    \atk, ~padEnvAtk,
                    \sus, ~padEnvSus,
                    \dec, ~padEnvDec,
                    \rel, ~padEnvRel
                ];
                ~synths[num] = Synth.new("osc__s2_adsr", params);
                result = "NOTE"
            }
            {
                // Default case
                result = "NOTE"
            };
            // Return parameter name for logging
            result
        }),
        chan: 0,
        srcID: srcKeyboard
    );

    MIDIdef.noteOff(
        \noteOffKeyboard_ArturiaMINILAB3,
        ~withMIDILogging.({ |vel, num, chan, src|
            // If there's a synth playing for this note, release it
            if (~synths[num].notNil) { ~synths[num].set(\gate, 0) };

            // Remove from tracking dictionary
            ~synths.removeAt(num);

            // Return parameter name for logging
            "NOTE OFF"
        }),
        chan: 0,
        srcID: srcKeyboard
    );

    // M-Audio XSession Pro
    // Triggering events with knobs from M-Audio X-Session Pro
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