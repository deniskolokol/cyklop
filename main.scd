// Inspired by the Cyklop (from "Niezwićiężony" by Stanisław Lem):
// an 80-ton, self-propelled and self-steering, unmanned armored vehicle
// equipped with a full arsenal of weapons, including an antimatter launcher.

// First, quit the server to start clean.
s.quit;

(
// Server config.
Server.default = s = Server.local;

s.options.numInputBusChannels = 2; // Behringer U-Foria: 2; Focusrite Saffire: 4
s.options.numOutputBusChannels = 2; // Behringer U-Foria: 2; Focusrite Saffire: 10
s.options.blockSize = 512;
s.options.memSize = 2097152; // 2Gb
s.options.numBuffers = 2048;

s.newBusAllocators;
ServerBoot.removeAll;
ServerTree.removeAll;
ServerQuit.removeAll;

// Global variables.
~out = 0;
~path = PathName(thisProcess.nowExecutingPath).parentPath;

~baseQuant = 16;
~stretch = 25/128 * ~baseQuant;
~freq = 2;
~measure = 1 / ~baseQuant ! 10 * ~freq;
~tempo = TempoClock.new(120/60).schedAbs(0, { ~tempo.beatsPerBar_(4) });
s.newBusAllocators;
~rbus = Bus.audio(s, 2);

// Global functions.
~makeBuffers = {
    "> Creating wavetables...".post;
    // 10 wavetables with increasing complexity
	~wt_sig = 10.collect({
		arg i;

		//random number of envelope segments
		var numSegs = i.linexp(0, 9, 4, 40).round;

		Env(
			//env always begins and ends with zero
			//inner points are random from -1.0 to 1.0
			[0]++({1.0.rand}.dup(numSegs-1) * [1,-1]).scramble++[0],

			//greater segment duration variety in higher-index wavetables
			{exprand(1,i.linexp(0,9,1,50))}.dup(numSegs),

			//low-index wavetables tend to be sinusoidal
			//high index wavetables tend to have sharp angles and corners
			{[\sine,0,exprand(1,20) * [1,-1].choose].wchoose([9-i,3,i].normalizeSum)}.dup(numSegs)
		).asSignal(1024);
	});

    "> Loading wavetables into buffers...".post;

	//load into 10 buffers in wavetable format
	~wt_buf = Buffer.allocConsecutive(10, s, 2048, 1, {
		arg buf, index;
		buf.setnMsg(0, ~wt_sig[index].asWavetable);
	});
    postf("OK\n");
};

~makeBuses = {
    "> Creating buses...".post;
    ~bus = Dictionary.new;
    ~bus.add(\reverb -> Bus.audio(s, 2));
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
        )
    });
    postf("OK\n");
};

~makeEvents = {
    "> Loading event definitions...".post;
    ~evnts = Dictionary.new;

    // Warning: every event that should be controlled by MIDI
    // should be defined as Pdef!

    // Clean hat.
    ~evnts.add(\clean_hat -> {
        ~cleanHat = Pdef(
            \clean_hat,
            Pbind(
                \instrument, \hihat,
                \dur, Pseq(~measure, inf),
                \amp, Pwhite(0.5, 1.0, inf),
                \rel, Pwrand([0.02, 0.1, 0.5], [0.7, 0.15, 0.15], inf),
                \pan, Pgauss(0, 0.7, inf),
            )
        );
    });

    ~evnts.add(\kick_base -> {
        ~kickBase = Pbind(
            \instrument, \kick_acoustic,
            \dur, Pseq(~measure * 2, inf),
            \amp, Pseq([
                // fig 1 - main line
                Pseq([Pwrand([0, 1], [0.2, 0.8], 1), 0, 1, 0, 0, 0, 1, 1, 0, 0], 3),
                Pxrand([
                    // fig 2 - syncope 1
                    Pseq([0, 0, 1, 0, 0, 1, 1, 1, 0, 0], 1),
                    // fig 3 - syncope 2
                    Pseq([0, 1, 0, 0, 1, 0, 0, 1, 0, 0], 1),
                    // fig 4 - syncope 3
                    Pseq([0, 1, 0, 0, 1, 1, 0, 0, 1, 1], 1),
                ], 1),
            ])
        )
    });
    ~evnts.add(\snare_base -> {
        ~snareBase = Pbind(
            \instrument, \snare,
            \dur, Pseq(~measure * 2, inf),
            \pDistPreGain, Pwhite(11, 13).dbamp,
            \pDistGain, Pwhite(-8, -10).dbamp,
            \bpfreq1, Pwhite(2000, 2300),
            \bprq1, Pwhite(0.2, 0.5),
            \bpfreq2, Pwhite(3800, 4300),
            \bprq2, Pwhite(0.5, 0.7),
            \amp, Pseq([
                // fig 1 - main line
                Pseq([0, 0, 0, 1, 0, 0, 0, 0, 1, 0], 3),
                Pxrand([
                    // fig 2 - syncope 1
                    Pseq([1, 1, 0, 0, 0, 1, 0, 0, 1, Prand([0, 1], 1)], 1),
                    // fig 3 - syncope 2
                    Pseq([1, 0, 0, 1, 0, 0, 1, 0, 1, Prand([0, 1], 1)], 1),
                    // fig 4 - syncope 3
                    Pseq([0, 0, 1, 0, 0, 0, 1, 0, 1, 1], 1),
                ], 1),
            ])
        )
    });
    ~evnts.add(\tom_base -> {
        ~tomBase = Pbind(
            \instrument, \tom,
            \dur, Pseq(~measure * 2, inf),
            \amp, Pseq([
                // fig 1 - main line
                Pseq([0, 0, 0, 0, 0, 1, Pwrand([1, 0], [0.7, 0.3], 1), 0, 0, 1], 3),
                // fig 2 - syncope 1 (silent)
                Pseq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1),
            ]),
        )
    });

    // Base beat without tom.
    ~evnts.add(\beat_base -> {
        ~beatBase = Pdef(
            \beat_base,
            Ptpar([
                0.0, ~evnts[\kick_base].value, // KICK
                0.0, ~evnts[\snare_base].value, // SNARE
            ], inf)
        );
    });

    // Base beat with tom.
    ~evnts.add(\beat_base_tom -> {
        ~beatBaseTom = Pdef(
            \beat_base_tom,
            Ptpar([
                0.0, ~evnts[\kick_base].value, // KICK
                0.0, ~evnts[\snare_base].value, // SNARE
                0.0, ~evnts[\tom_base].value, // TOM
            ], inf)
        );
    });

    // Synths.
	// background pad using simple wavetables
    ~evnts.add(\pad -> {
        ~pad = Pbindef(\pad,
            \instrument, \osc,
            \dur, Pwrand([1, 4, 6, 9, 12], [0.35, 0.25, 0.2, 0.15, 0.05], inf),
            \atk, Pexprand(3, 6),
            \sus, 0,
            \rel, Pexprand(5, 10),
            \c0, Pexprand(1, 2),
            \c1, Pexprand(1, 2).neg,
            \detune, Pfunc({rrand(0.15, 0.4)} ! 3),
            \buf, Prand(~wt_buf[0..3], inf),
            \scale, Scale.minorPentatonic,
            \degree, Pfunc({
                (-12,-10..0).scramble[0..rrand(1,3)]
            }),
            \amp, Pexprand(0.05, 0.07),
            \pan, Pwhite(-0.4, 0.4),
            \out, 0,
            \rout, ~rbus,
            \rsend, -10,
        )
    });

	// Arpeggiated bass pulse using mid/high complexity wavetables
    ~evnts.add(\pulse -> {
        ~pulse = Pbindef(\pulse,
            \instrument, \osc,
            \dur, Pseq([
                Pdup(24, Pseq([1/4], 1)),
                Prand([1, 2, 4, 6, 12], 1)
            ],inf),
            \atk, 0.001,
            \sus, 0.2,
            \rel, Pexprand(0.4, 1),
            \c0, 0,
            \c1, Pwhite(5, 10).neg,
            \detune, 0.3,
            \buf, Prand(~wt_buf[4..9], inf),
            \scale, Scale.minorPentatonic,
            \degree, Pseq(
                [Prand([-15, -10, -5], 24), Pseq([\], 1)], inf)
                + Pdup(25, Pwrand([0, 2, -1], [0.78, 0.1, 0.12], inf)),
            \amp, Pseq([Pgeom(0.45, -1.dbamp, 25)],inf),
            \pan, Pwhite(0.01, 0.3) * Pseq([1, -1],inf),
            \out, 0,
            \rout, ~rbus,
            \rsend, -10,
        )
    });

    //minimal melody using simple wavetables
	~evnts.add(\melody -> {
        ~melody = Pbindef(\melody,
            \instrument, \osc,
            \dur, Prand([
                Pseq([Prand([12,16,20]),2,1.5,0.5],1),
                Pseq([Prand([12,16,20]),1.5,1,1.5],1),
            ],inf),
            \atk, 0.01,
            \sus, 0.3,
            \rel, 1.5,
            \c0, -2,
            \c1, -2,
            \detune, Pexprand(0.18,0.25),
            \buf, Pwrand([
                Pseq([~wt_buf[0]], 4),
                Pseq([~wt_buf[1]], 4),
                Pseq([~wt_buf[2]], 4),
            ],[9,3,1].normalizeSum,inf),
            \midinote, Pxrand([
                Pseq([\,67,60,Prand([58,70,\])],1),
                Pseq([\,67,58,Prand([57,63,\])],1),
                Pseq([\,70,72,Prand([65,79,\])],1)
            ],inf),
            \amp, Pseq([0,0.18,0.24,0.28],inf),
            \out, 0,
            \rout, ~rbus,
            \rsend, -6,
        )
    });

    ~evnts.add(\mix_full -> {
        ~mixFull = Pdef(
            \mix_full,
            Ptpar([
                0.0, ~evnts[\snare_base].value,
                0.0, ~evnts[\beat_base_tom].value,
                0.0, ~evnts[\pad].value,
                0.0, ~evnts[\pulse].value,
                0.0, ~evnts[\melody].value,
            ], inf)
        );
    });

    postf("OK\n");
};

~makeGUI = {
	var winWidth=350, winHeight=250;
    ~win = Window.new(
		"Cyklop",
		Rect(
			Window.screenBounds.width-winWidth,
			1250,
			winWidth,
			winHeight
		),
		resizable: false
	);
    b = Button(~win, Rect(20, 20, 300, 30))
    .states_([
        ["Play", Color.white, Color.gray],
        ["Stop", Color.white, Color.red]
    ])
    .action_({ |bt|
		// if (bt.value == 1) {
		// 	~evnts[\beat_base].value;
		// } {
		// 	~beatBase.stop;
		// };

		if (~evnts[\mix_full].isNil) {
			"WARNING: No event defined for 'mix_full'".postln;
		} {
			~tempo.schedAbs(~tempo.nextTimeOnGrid(), {
				if (~evnts[\mix_full].value.isPlaying) {
					~evnts[\mix_full].value.stop;
				} {
					~evnts[\mix_full].value.play;
				};
				nil; // Return nil to prevent rescheduling
			});
		};
    });
    ~win.front;
};


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
		// Post MIDI event
		~postMIDI.(val, num, chan, src);
    });

    // triggering events with MIDI
    MIDIdef.noteOn(\noteOnKeyPad, { |vel, num, chan, src|
        var setParm = switch(num)
        { 36 } { \clean_hat }
        { 37 } { \beat_base }
        { 38 } { \beat_base_tom }
        { 39 } { \pad }
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
    // wait until all asynchronous tasks are finished
    s.sync;

    // Load synths from another file.
    "> Loading synth definitions...".post;
    if (this.executeFile(~path +/+ "synthdef.scd").isNil.not) {
        postf("OK\n\n")
    };

    // yes, again!
    s.sync;

    // Register remaining functions
    ServerTree.add(~makeNodes);
    ServerTree.add(~makeEvents);
    ServerTree.add(~makeGUI);

	// Instantiate reverb and re-instantiate when cmd-period is pressed.
	~add_reverb = {Synth(\reverb, [\in, ~rbus])};
	ServerTree.add(~add_reverb);
    s.freeAll;

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
