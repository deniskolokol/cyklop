// Inspired by the Cyklop (from "Niezwićiężony" by Stanisław Lem):
// an 80-ton, self-propelled and self-steering, unmanned armored vehicle
// equipped with a full arsenal of weapons, including an antimatter launcher.

// First, quit the server to start clean.
s.quit;

(
// Project parent path.
~projectPath = PathName(thisProcess.nowExecutingPath).parentPath;

// Server config.
Server.default = s = Server.local;

// Behringer U-Foria: 2
// Focusrite Saffire: 4
// PreSonus Studio: 8 (18 in total, but only 8 is used)
s.options.numInputBusChannels = 8;

// Behringer U-Foria: 2
// Focusrite Saffire: 10
// PreSonus Studio: 16 (18 in total but in this project we use only 16)
s.options.numOutputBusChannels = 16;

s.options.blockSize = 512;
s.options.memSize = 2097152; // 2Gb
s.options.numBuffers = 2048;

s.newBusAllocators;
ServerBoot.removeAll;
ServerTree.removeAll;
ServerQuit.removeAll;

// Global variables.

// Root key
//
// Define all possible notes (chromatic scale with enharmonic equivalents)
~noteNames = [
    "C", "C#/Db", "D", "D#/Eb", "E", "F", 
    "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B"
];
// Create expanded note list with multiple octaves
~fullNoteList = [];
~midiValues = [];

// Generate notes from C0 to B8 (MIDI 0-127)
11.do { |octave|
    ~noteNames.do { |noteName, index|
        var midiNote = (octave * 12) + index;
        if(midiNote <= 127) {
            ~fullNoteList = ~fullNoteList.add(noteName ++ octave.asString);
            ~midiValues = ~midiValues.add(midiNote);
        };
    };
};

// The value of this indicates, whether:
// - to track root note changes from MIDI input ('root' mode)
// - to play live a selected synth without changing the root note ('synth' mode)
// - to not track MIDI input at all ('off' mode, DEFAULT).
~midiTrackMode = [\off, \root, \synth];
~midiTrack = ~midiTrackMode[0]; // Default to 'off' mode

~getRoot = { |midinote| midinote % 12 }; // Note in 12-tone chromatic scale (0-11)
~getOctave = { |midinote| (midinote / 12).floor - 2 }; // Octave number (0-8)
~setRoot = { |midinum|
    ~rootMIDI = ~midiValues[midinum];
    ~root = ~getRoot.(~rootMIDI);
    ~octave =~getOctave.(~rootMIDI);
    postf(
        "New root note: % (%), key % in octave %\n",
        ~rootMIDI,
        ~fullNoteList[midinum],
        ~root,
        ~octave
    );
};
~setRoot.(60); // Default root note in 12-tone scale (C2, MIDI 36)


// Find index of middle C (MIDI 60) for default selection
~defaultIndex = ~midiValues.indexOf(60);


// Dictionary to store synths played with the keyboard
~synths = Dictionary.new;


// Pads env control
~padEnvAtk = 0.5;
~padEnvDec = 0.5;
~padEnvSus = 0.5;
~padEnvRel = 5;


// Instruments buffer indices
~bassBuff = 0;


// Timing decorator
~withTiming = { |func|
    { |...args|
        var start = Main.elapsedTime;
        var result = func.value(*args);
        postf("[i] Execution time: % seconds\n", (Main.elapsedTime - start).round(0.0001));
        result
    }
};


// Error handling decorator
~withErrorHandling = { |func|
    { |...args|
        try {
            func.value(*args);
        } { |error|
            case
            { error.isKindOf(PrimitiveFailedError) } {
                postf("% (Operation failed)\n", error.errorString)
            }
            { error.isKindOf(DoesNotUnderstandError) } {
                postf("% (Method not found)\n", error.errorString)
            }
            {
                postf("% (Unknown error)\n", error.errorString)
            };

            nil
        }
    }
};


// Buffers.
~cleanupWavetableBufs = {
    // Cleans up buffers used for wavetables and Shaper.
    if (~wt_buf.isNil.not) {
        ~wt_buf.do({ |buf| buf.free });
        ~wt_buf = nil;
    };
};

~cleanupShaperBufs = {
    // Cleans up buffers used for Shaper.
    if (~tf_buf.isNil.not) {
        ~tf_buf.do({ |buf| buf.free });
        ~tf_buf = nil;
    };
};


// Create wavetables and fill buffers
~makeWavetableBufs = ~withErrorHandling.(~withTiming.({
    // Create 10 wavetables with increasing complexity
    "> Creating wavetables...".post;
    ~wt_sig = 10.collect({ |i|

		var numSegs = i.linexp(0, 9, 4, 40).round;

        // Env always begins and ends with zero
        // Inner points are random from -1.0 to 1.0
        var levels = [0]++({1.0.rand}.dup(numSegs-1) * [1, -1]).scramble++[0];

		// Greater segment duration variety in higher-index wavetables
        var durs = {exprand(1, i.linexp(0, 9, 1, 50))}.dup(numSegs);

        // Low-index wavetables tend to be sinusoidal
        // High index wavetables tend to have sharp angles and corners
        var curves = {[\sine, 0, exprand(1,20) * [1,-1].choose].wchoose([9-i, 3, i].normalizeSum)}.dup(numSegs);

        postf("  Wavetable %:\n\tlevels: %\n\tdurs: %\n\tcurves: %\n\n", i, levels, durs, curves);

        Env(levels, durs, curves).asSignal(1024)
    });
    postf("OK\n");

    // Check if there are buffers already and clean them up
    ~cleanupWavetableBufs.();

    // Load into 10 buffers in wavetable format
    "> Loading wavetables into buffers...".post;
    ~wt_buf = Buffer.allocConsecutive(10, s, 2048, 1, {
        arg buf, index;
        buf.setnMsg(0, ~wt_sig[index].asWavetable);
    });
    postf("OK\n");
}));


// Create Shaper Envs and fill buffers
~makeShaperBufs = ~withErrorHandling.(~withTiming.({
    // Create 6 Envs and load them into buffers for Shaper.
    "> Loading buffers for Shaper...\n".postf;
    ~tf_sig = 6.collect ({ |i|
        ~tf = Env([-1, 1], [1], [0]).asSignal(1025);

		// More partials in higher-index wavetables
        ~tf = ~tf + (
            Signal.sineFill(
                1025,
                (0 ! 3) ++ ((1 ! (i+1)) ++ (0 ! (6-i))).scramble,
                {rrand(0, 2pi)} ! 9
            ) / 4
        );

        ~tf = ~tf.normalize;
    });

    // Check if there are buffers already and clean them up
    ~cleanupShaperBufs.();

    // Load into 6 buffers in wavetable format without wrapping
    ~tf_buf = Buffer.allocConsecutive(5, s, 2050, 1, {
        arg buf, index;
        buf.setnMsg(0, ~tf_sig[index].asWavetableNoWrap);
    });
}));


// Aggregate buffer creation
~makeBuffers = {
    ~makeWavetableBufs.();
    ~makeShaperBufs.();
};


// Create groups and synths for FX
~makeNodes = ~withErrorHandling.(~withTiming.({
    "> Initiating configuration of groups and synths...".post;
    s.bind({
        ~mainGrp = Group.new;

        ~reverbGrp = Group.after(~mainGrp);
        ~reverbSynth = Synth.new(
            \reverb, [
                \amp, 1,
                \xFade, 0.35,   
                \predelay, 0.1,
                \revtime, 1.8,
                \lpf, 4500,
                \mix, 0.5,
                \in, ~outMelody, // input from main output will be XOut'ed
                \out, ~outMelody
            ],
            ~reverbGrp
        );

        ~distGrp = Group.after(~mainGrp);
        ~distSynth = Synth.new(
            \dist, [
                \xFade, 0.0,
                \preGain, 35,
                \postGain, 0.315,
                \amount, 0.85,
                \in, ~outDrums, // input from main output will be XOut'ed
                \out, ~outDrums
            ],
            ~distGrp
        );
    });
    postf("OK\n");
}));


// Manager to notify listeners about the pattern state change
~patternStateName = \patternState;
~patternStateManager = { |pattern, state|
    NotificationCenter.notify(
        ~patternStateName,
        pattern,
        state
    );
};


// Event player transport
~playStopEvent = { |name, clock|
    try {
        if (~evnts[name].isNil) {
            postf("WARNING: No event defined for %\n", name);
        } {
            clock.schedAbs(clock.beats.ceil, {
                if (~evnts[name].isPlaying) {
                    ~evnts[name].stop;

                    // Notify listeners that the pattern has stopped
                    ~patternStateManager.(name, false);
                } {
                    ~evnts[name].play(clock, quant: 1); 

                    // Notify listeners that the pattern has started
                    ~patternStateManager.(name, true);
                };
            });
        };
    } {
        postf("ERROR: Could not play event %\n", name);
    };
    nil;
};


// WARNING: remove this when beat visualizer becomes extension!
~fillAccents = { |beats, clicks, accentOn|
    // Accent pattern generator.
    // the param `accentOn` can be either:
    // - an Integer indicating which click to accent (1-based index),
    //   e.g. 1 for the first click, 2 for the second click, etc.
    // - an Array of click indices to accent, e.g. [1, 3] for accents on the
    //   first and third clicks.
    // 
    // Returns an Array of 0s and 1s, where 1 indicates an accented click.
    // Examples:
    // - for 4 clicks per beat, accent on the first click: [1, 0, 0, 0]
    // - for 4 clicks per beat, accent on the third click: [0, 0, 1, 0]
    // Irregular accent patterns can be created by setting accentOn to an Array
    // of click indices to accent, e.g. [1, 3] for accents on the first and
    // third clicks - in this case the resulting pattern would be [1, 0, 1, 0]
    // for 4 clicks per beat.
    //
    // Warning: invalid values (such as negative integers or val;ues that exceed
    // the number of clicks per beat) will result in no accents being applied.
    var accents;
    case 
    { accentOn.isInteger and: { accentOn > 0 } } {
        accents = Array.fill(beats, { |i|
            Array.fill(clicks, { |j| if (accentOn == (j+1)) { 1 } { 0 }})
        });
    }
    { accentOn.isArray } {
        accents = Array.fill(beats, { |i|
            Array.fill(clicks, { |j| if (accentOn.includes(j+1)) { 1 } { 0 }})
        });
    }
    { "Invalid accentOn value. Must be a positive Integer or an Array of click indices.".postln; 
      accents = Array.fill(beats, { |i| Array.fill(clicks, 0) }) // Default to no accents
    };
};


// Load external file
~loadExternal = { |path, descr=nil, autoSync=false|
    postf("> Loading %... ", if(descr.notNil && {descr.notEmpty}) {descr} {path});
    if (this.executeFile(path).isNil.not) {
        "OK".postln;
        if (autoSync) {
            "[i] Server sync... ".post;
            s.sync; // wait until all asynchronous tasks are finished
            "OK".postln;
        };
    } {
        postf("ERROR: Could not load %!\n", path);
    };
};


// Clean up buffers and MIDI
~cleanup = {
    "[i] Cleaning up".postln;
    ~win.close;

    "> Resetting bus counter...".post;
    s.newBusAllocators;
    postf("OK\n");

    "> Freeing MIDI...".post;
    try {
        ~midiOut.allNotesOff(0);
        MIDIdef.freeAll;
        postf("OK\n");
    } { |error|
        postf("WARNING: Could not free MIDI resources: %\n", error.errorString);
    };

    "> Clearing buffers...".post;
    ~cleanupShaperBufs.();
    ~cleanupWavetableBufs.();
    postf("OK\n");

    "> Clearing notification centers...".post;
    NotificationCenter.clear;
    postf("OK\n");

    "> Removing all patterns...".post;
    ~evnts.keysValuesDo({ |key, pattern|
        if (pattern.isPlaying) {
            pattern.stop;
        };
        ~evnts.removeAt(key);
    });
    postf("OK\n");

    "> Removing all functions...".post;
    ServerBoot.removeAll;
    ServerTree.removeAll;
    ServerQuit.removeAll;
    postf("OK\n");
};

// Load external files that don't require server to be booted.
~loadExternal.(~projectPath +/+ "midi.scd", descr:"MIDI handlers");
~loadExternal.(~projectPath +/+ "gui.scd", "GUI");

// Register functions with ServerBoot/-Quit/-Tree (which control
// presicely when these functions get evaluated).
ServerBoot.add(~makeBuffers);
ServerBoot.add(~makeMIDI);
ServerQuit.add(~cleanup);

// Boot server
s.waitForBoot({
    // Load external files that does require server to be booted.
    ~loadExternal.(~projectPath +/+ "synthdef.scd", "synth definitions", autoSync:true);
    ~loadExternal.(~projectPath +/+ "patterns.scd", "event definitions", autoSync:true);

    // Register remaining functions
    ServerTree.add(~makeNodes);
    ServerTree.add(~makeGUI);

	// Trigger re-instantiating of the FX groups.
    s.freeAll;

    // // Show server meter and Node Tree.
    // s.meter;

    // Lastly sync server to ensure all async tasks are done.
    s.sync;
});

CmdPeriod.doOnce({
    "[!] Caught signal: <shut down>".postln;
    ~cleanup.();
    postf("OK\n\n");
})
)
