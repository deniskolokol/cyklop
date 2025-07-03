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

// 2. Global variables.
~out = 0;
~path = PathName(thisProcess.nowExecutingPath).parentPath;

~baseQuant = 16;
~stretch = 25/128 * ~baseQuant;
~freq = 2;
~measure = 1 / ~baseQuant ! 10 * ~freq;
~tempo = TempoClock.new(120/60).schedAbs(0, { ~tempo.beatsPerBar_(4) });


// Global functions.
~makeBuffers = {
    "> Loading buffers...".post;
    b = Dictionary.new;
    PathName(~path +/+ 'samples').entries.do {
        arg subfolder;
        b.add(
            subfolder.folderName.asSymbol -> Array.fill(
                subfolder.entries.size,
                { |i| Buffer.read(s, subfolder.entries[i].fullPath) };
            )
        )
    };
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
            \instrument, \kick_synth,
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
        if (bt.value == 1) {
            ~evnts[\beat_base].value;
        } {
            ~beatBase.stop;
        }
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
        { 39 } { \synths };
        try {
            if (~evnts[setParm].isNil) {
                postf("WARNING: No event defined for %\n", setParm);
                setParm = "Note ON";
            } {
                ~tempo.schedAbs(~tempo.nextTimeOnGrid(4), {
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

    // TODO: Load here synths from another file!
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

    // Re-initialize the Node Tree and cause ServerTree to re-evaluate those functions above:
    // - defines our event dictionary;
    // - enables MIDI functionality;
    // - creates out initial NodeTree with two grups and one synth.
    s.freeAll;

    s.meter;

    // ...and again!
    s.sync;

    // This should be controlled by GUI or MIDI
    // ~evnts[\beat_base].value;
});

CmdPeriod.doOnce({
    "[!] Caught signal: <shut down>".postln;
    ~cleanup.();
    postf("OK\n\n");
})
)
