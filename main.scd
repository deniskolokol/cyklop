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
~out = 0;
~outDrums = 4;
s.newBusAllocators;

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
~setRoot.(36); // Default root note in 12-tone scale (C1, MIDI 36)


// Find index of middle C (MIDI 60) for default selection
~defaultIndex = ~midiValues.indexOf(60);

// Global functions.
~makeBuffers = {
    // Create 10 wavetables with increasing complexity
    "> Creating wavetables...\n".postf;
	~wt_sig = 10.collect({ |i|

		// Random number of envelope segments
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
		).asSignal(1024);
	});

	//load into 10 buffers in wavetable format
    "> Loading wavetables into buffers...\n".postf;
	~wt_buf = Buffer.allocConsecutive(10, s, 2048, 1, {
		arg buf, index;
		buf.setnMsg(0, ~wt_sig[index].asWavetable);
	});
    postf("OK\n");

    // Load a few more buffers for Shaper.
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

    ~tf_buf = Buffer.allocConsecutive(5, s, 2050, 1, {
        arg buf, index;
        buf.setnMsg(0, ~tf_sig[index].asWavetableNoWrap);
    });
    "> OK\n".postf;
};

~makeBuses = {
    "> Creating buses...".post;
    ~bus = Dictionary[
        \reverb -> Bus.audio(s, 2)
    ];
    postf("OK\n");
};

~makeNodes = {
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
                \out, ~out
            ],
            ~reverbGrp
        );

        ~distGrp = Group.after(~mainGrp);
        ~distSynth = Synth.new(
            \dist, [
                \xFade, 0.0,
                \preGain, 75,
                \postGain, 0.5,
                \amount, 0.5,
                \in, ~outDrums, // input from main output will be XOut'ed
                \out, ~outDrums
            ],
            ~distGrp
        );
    });
    postf("OK\n");
};


~makeGUI = {
	var winWidth=550, winHeight=1250, palette=QPalette.dark;
    ~win = Window.new(
		"Cyklop",
		Rect(
			Window.screenBounds.width-winWidth,
			1250,
			winWidth,
			Window.screenBounds.height
		),
		resizable: false
	);
    ~win.view.decorator = FlowLayout(~win.view.bounds);
    ~win.view.decorator.gap=1@1;    
    palette.setColor(Color.grey(0.2), \window);
    ~win.view.palette = palette;

    b = Button(~win, 100@30)
    .states_([
        ["Play", Color.white, Color.gray],
        ["Stop", Color.white, Color.red]
    ])
    .action_({ |bt|
        var fullMixName = \mix_full;
		if (~evnts[fullMixName].isNil) {
			postf("WARNING: No event defined for '%'\n", fullMixName);
		} {
			~tempo.schedAbs(~tempo.nextTimeOnGrid(), {
				if (~evnts[fullMixName].value.isPlaying) {
					~evnts[fullMixName].value.stop;
				} {
					~evnts[fullMixName].value.play;
				};

                // Return nil to prevent rescheduling
				nil;
			});
		};
    });

    // Create a dropdown menu for selecting root notes
    ~noteDropdown = PopUpMenu(~win, 200@30)
        .items_(~fullNoteList)
        .value_(~defaultIndex)
        .action_({ |menu| ~setRoot.(menu.value) });

    // Check ~root changes twice per second and update dropdown
    ~rootWatcher = Routine({
        loop {
            var index = ~midiValues.indexOf(~rootMIDI);
            {
                if (index.notNil and: { ~noteDropdown.value != index }) {
                    ~noteDropdown.value_(index);
                }
            }.defer;
            0.5.yield; // Wait 0.5 seconds (twice per second)
        }
    }).play;

    ~win.front;
};


// Post MIDI event
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


// MIDI handlers
~makeMIDI = {
    "> Initializing MIDI sources...".postln;
    if(MIDIClient.initialized.not) {
        MIDIClient.init;
    } {
        MIDIClient.list;
    };
    MIDIIn.connectAll;

    // MIDI control messages
    MIDIdef.cc(\ccHandler, { |val, num, chan, src|
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
        };
		~postMIDI.(val, num, chan, src, setParm, setVal);
    });

    // triggering events with MIDI
    MIDIdef.noteOn(\noteOnKeyPad, { |vel, num, chan, src|
        var setParm = switch(num)
        { 36 } { \beat_base_x1 }
        { 37 } { \beat_base_x2 }
        { 38 } { \pad }
        { 39 } { \pad_s }
        { 40 } { \pulse }
        { 41 } { \melody };

        try {
            if (~evnts[setParm].isNil) {
                postf("WARNING: No event defined for %\n", setParm);
                setParm = "Note ON";
            } {
                ~tempo.schedAbs(~tempo.nextTimeOnGrid(), {
                    if (~evnts[setParm].value.isPlaying) {
                        ~evnts[setParm].value.stop;
                    } {
                        ~evnts[setParm].value.play;
                    };
                    nil; // Return nil to prevent rescheduling
                });
            };
        } {
            postf("ERROR: Could not play event %\n", setParm);
            setParm = "Note ON";
        };
        ~postMIDI.(vel, num, chan, src, setParm, num);
    },
    chan:9
    );

    // MIDI notes
    MIDIdef.noteOn(\noteOnKeyboard, { |vel, num, chan, src|
        // ~noteDropdown.valueAction_(~rootMIDI);
        ~setRoot.(num)
        // ~postMIDI.(vel, num, chan, src, "ROOT", num);
    },
    chan:0
    );

};

~cleanup = {
    "[i] Cleaning up".postln;
    ~win.close;

    "> Resetting bus counter...".post;
    s.newBusAllocators;
    postf("OK\n");

    "> Freeing MIDI...".post;
    MIDIdef.freeAll;
    postf("OK\n");

    "> Cleaning up buffers...".post;
    if (~wt_buf.isNil.not) {
        ~wt_buf.do({ |buf| buf.free });
        ~wt_buf = nil;
    };
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

    // wait until all asynchronous tasks are finished
    s.sync;

    "> Loading synth definitions...".post;
    if (this.executeFile(path +/+ "synthdef.scd").isNil.not) {
        postf("OK\n")
    };

    // yes, again!
    s.sync;

    "> Loading event definitions...".post;
    if (this.executeFile(path +/+ "patterns.scd").isNil.not) {
        postf("OK\n")
    };

    // Register remaining functions
    ServerTree.add(~makeNodes);
    ServerTree.add(~makeGUI);

	// Trigger re-instantiating of the FX groups.
    s.freeAll;

    // Show server meter and Node Tree.
    s.meter;

    // ...and again!
    s.sync;
});

CmdPeriod.doOnce({
    "[!] Caught signal: <shut down>".postln;
    ~cleanup.();
    postf("OK\n\n");
})
)
