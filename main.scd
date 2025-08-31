// Inspired by the Cyklop (from "Niezwićiężony" by Stanisław Lem):
// an 80-ton, self-propelled and self-steering, unmanned armored vehicle
// equipped with a full arsenal of weapons, including an antimatter launcher.

// First, quit the server to start clean.
s.quit;

(
// Server config.
Server.default = s = Server.local;

// Behringer U-Foria: 2
// Focusrite Saffire: 4
// PreSonus Studio: 12
s.options.numInputBusChannels = 12;

// Behringer U-Foria: 2
// Focusrite Saffire: 10
// PreSonus Studio: 12
s.options.numOutputBusChannels = 12;

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

        Env(
			// Env always begins and ends with zero
			// Inner points are random from -1.0 to 1.0
			[0]++({1.0.rand}.dup(numSegs-1) * [1, -1]).scramble++[0],

			// Greater segment duration variety in higher-index wavetables
			{exprand(1, i.linexp(0, 9, 1, 50))}.dup(numSegs),

			// Low-index wavetables tend to be sinusoidal
			// High index wavetables tend to have sharp angles and corners
			{[\sine, 0, exprand(1,20) * [1,-1].choose].wchoose([9-i, 3, i].normalizeSum)}.dup(numSegs)
		).asSignal(1024)
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


// Create audio buses for FX
~makeBuses = ~withErrorHandling.(~withTiming.({
    "> Creating buses...".post;
    ~bus = Dictionary[
        \reverb -> Bus.audio(s, 2)
    ];
    postf("OK\n");
}));


// Create groups and synths for FX
~makeNodes = ~withErrorHandling.(~withTiming.({
    "> Initiating configuration of groups and synths...".post;
    s.bind({
        ~mainGrp = Group.new;

        ~reverbGrp = Group.after(~mainGrp);
        ~reverbSynth = Synth.new(
            \reverb, [
                \amp, 1,
                \predelay, 0.1,
                \revtime, 1.8,
                \lpf, 4500,
                \mix, 0.35,
                \in, ~bus[\reverb],
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
            clock.schedAbs(clock.nextTimeOnGrid(), {
                if (~evnts[name].isPlaying) {
                    ~evnts[name].stop;

                    // Notify listeners that the pattern has stopped
                    ~patternStateManager.(name, false);
                } {
                    ~evnts[name].play;

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


// Load external file
~loadExternal = { 
    arg path,
        descr,
        requiresSync=true;

    postf("> Loading %... ", descr);
    if (this.executeFile(path).isNil.not) {
        "OK".postln;
        if (requiresSync) {
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
    MIDIdef.freeAll;
    postf("OK\n");

    "> Clearing buffers...".post;
    ~cleanupShaperBufs.();
    ~cleanupWavetableBufs.();
    postf("OK\n");

    "> Clearing notification centers...".post;
    NotificationCenter.clear;
    postf("OK\n");

    "> Removing all functions...".post;
    ServerBoot.removeAll;
    ServerTree.removeAll;
    ServerQuit.removeAll;
    postf("OK\n");
};

// Register functions with ServerBoot/-Quit/-Tree (which control
// presicely when these functions get evaluated).
ServerBoot.add(~makeBuffers);
ServerBoot.add(~makeBuses);
ServerBoot.add(~makeMIDI);
ServerQuit.add(~cleanup);


// Boot server
s.waitForBoot({
    var path = PathName(thisProcess.nowExecutingPath).parentPath;

    // List of external files to load in the order they should be loaded.
    // Format: [filename <str>, description <str>, requiresSync <bool>]
    var externals = [
        ["synthdef.scd", "synth definitions", true],
        ["patterns.scd", "event definitions", true],
        ["midi.scd", "MIDI handlers", false],
        ["gui.scd", "GUI", false]
    ];

    externals.do({ |elt|
        elt[0] = path +/+ elt[0];
        ~loadExternal.(*elt);
    });

    // Register remaining functions
    ServerTree.add(~makeNodes);
    ServerTree.add(~makeGUI);

	// Trigger re-instantiating of the FX groups.
    s.freeAll;

    // Show server meter and Node Tree.
    // s.meter;

    // ...and again!
    s.sync;
});

CmdPeriod.doOnce({
    "[!] Caught signal: <shut down>".postln;
    ~cleanup.();
    postf("OK\n\n");
})
)
