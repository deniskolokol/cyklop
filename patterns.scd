// Patterns library.
//
// - Paterns are stored in the global dictionary ~evnts.
// - An event that is supposed be controlled by MIDI and/or GUI
//   should be defined as Pdef or Pbindef.
(
// Backward compatibility for Pstutter and Pdup: starting with version 3.13.0
// SuperCollider stopped supporting Pstutter in favor of Pdup.
var myPrepeat;
var pdupClass = \Pdup.asClass;

if (pdupClass.notNil) {
	// If Pdup exists (newer version), use it.
	myPrepeat = pdupClass;
} {
	// Otherwise, fall back to Pstutter (older version).
	myPrepeat = Pstutter;
};

// Routing
~outDrums = 0;
~outPads = 2;
~outBass = 4;
~outMelody = 6;

// Additional buses for separate recording of drum elements
~outRecHihat = 8; // hihat is stereo
~outRecKick = 10;
~outRecSnare = 11;
~outRecTom = 12;

// Timing
~bpm = 120;
~beatsPerBar = 5; // 5/8 time signature
~baseQuant = 8;
~stretch = 25/128 * ~baseQuant;
~clicksPerBeat = 2;
~accentOn = 1; // Accent on the first click of each beat
~accents = ~fillAccents.(~beatsPerBar, ~clicksPerBeat, ~accentOn).postln;
~measure = (1 / ~baseQuant * ~clicksPerBeat) ! 10;
~scheduler = TempoClock.new(~bpm/60)
    .schedAbs(0, { ~scheduler.beatsPerBar_(~beatsPerBar) });

// Warning: every event that should be controlled by MIDI
// should be defined as Pdef!
~evnts = Dictionary.new;

// 1 bar straignt patterns.
~hihatBarIntro = Pbind(
    \instrument, \hihat,
    \group, Pfunc({~mainGrp}),
    \dur, Pseq([1/2, 1/2, 1/2, 1/2, 1/2, 1/2, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4], inf),
    \amp, Pwhite(0.5, 1.0, inf),
    \rel, Pgeom(0.02, 1.7, 6) ++ Pwrand([0.02, 0.1, 0.5], [0.7, 0.15, 0.15], 8),
    \pan, Pgauss(0, 0.7, inf),
    \out, Pfunc({~outDrums}),
    \outRec, Pfunc({~outRecHihat})
);
~hihatBarStraight = Pbind(
    \instrument, \hihat,
    \group, Pfunc({~mainGrp}),
    \dur, Pseq(~measure * 2, inf),
    \amp, Pwhite(0.5, 1.0, 10),
    \rel, Pwrand([0.02, 0.1, 0.5], [0.7, 0.15, 0.15], 10),
    \pan, Pgauss(0, 0.7, 10),
    \out, Pfunc({~outDrums}),
    \outRec, Pfunc({~outRecHihat})
);
~hihatBarStraight_x2 = Pbind(
    \instrument, \hihat,
    \group, Pfunc({~mainGrp}),
    \dur, Pseq(~measure, inf),
    \amp, Pwhite(0.5, 1.0, 20),
    \rel, Pwrand([0.02, 0.1, 0.5], [0.7, 0.15, 0.15], 20),
    \pan, Pgauss(0, 0.7, 20),
    \out, Pfunc({~outDrums}),
    \outRec, Pfunc({~outRecHihat})
);

// Define templates as Events.
~snareBarTemplate = { |params|
    var baseEvent = (
        instrument: \snare,
        group: Pfunc({~mainGrp}),
        dur: Pseq(~measure * 2, inf),
        pDistPreGain: Pwhite(11, 13).dbamp,
        pDistGain: Pwhite(-8, -10).dbamp,
        bpfreq1: Pwhite(2000, 2300),
        bprq1: Pwhite(0.2, 0.5),
        bpfreq2: Pwhite(3800, 4300),
        bprq2: Pwhite(0.5, 0.7),
        pan: Pwhite(-0.4, -0.7), // Spread snare slightly left of center
        out: Pfunc({~outDrums}),
        outRec: Pfunc({~outRecSnare})
    );

    // Merge with parameters if provided
    if (params.notNil) {
        baseEvent = baseEvent.putAll(params);
    };

    // Convert Event to array of key-value pairs for Pbind
    baseEvent.asPairs;
};
~kickBarTemplate = { |params|
    var baseEvent = (
        instrument: \kick_synth, // \kick_acoustic
        group: Pfunc({~mainGrp}),
        dur: Pseq(~measure * 2, inf),
        out: Pfunc({~outDrums}),
        outRec: Pfunc({~outRecKick})
    );
    if (params.notNil) {
        baseEvent = baseEvent.putAll(params);
    };
    baseEvent.asPairs;
};
~tomBarTemplate = { |params|
    var baseEvent = (
        instrument: \tom,
        group: Pfunc({~mainGrp}),
        dur: Pseq(~measure * 2, inf),
        pan: Pwhite(0.2, 0.5), // Spread toms slightly right of center
        out: Pfunc({~outDrums}),
        outRec: Pfunc({~outRecTom})
    );
    if (params.notNil) {
        baseEvent = baseEvent.putAll(params);
    };
    baseEvent.asPairs;
};

// Straight patterns.
~kickBarStraight = Pbind(
    *~kickBarTemplate.((amp: Pseq([1, 0, 0, 0, 0, 0, 1, 1, 0, 0])))
);
~kickBarStraight_x2 = Pbind(
    *~kickBarTemplate.((amp: Pseq([1, 0, 1, 0, 0, 0, 1, 1, 0, 0])))
);
~snareBarStraight = Pbind(
    *~snareBarTemplate.((amp: Pseq([0, 0, 0, 1, 0, 0, 0, 0, 1, 0])))
);
~tomBarStraight = Pbind(
    *~tomBarTemplate.((amp: Pseq([0, 0, 0, 0, 0, 1, Pwrand([1, 0], [0.7, 0.3], 1), 0, 0, 1])))
);

// Off-beat
// Warning: start off beat in half-bar (10 x 1/8th notes
// against 10 x 1/4th notes in the main beat).
~hihatOffBeat_1 = Pbind(
    *~kickBarTemplate.((
        instrument: \hihat,
        rel: 0.2,
        dur: Pseq(~measure, inf),
        amp: Pseq([0, 0, 0, 0, 0, 0, 1, 0, 0, 0]),
        outRec: Pfunc({~outRecHihat})
        ))
);
~kickOffBeat_1 = Pbind(
    *~kickBarTemplate.((
        dur: Pseq(~measure, inf),
        amp: Pseq([0, 0, 0, 0, 1, 0, 0, 0, 0, 0])
        ))
);
~snareOffBeat_1 = Pbind(
    *~snareBarTemplate.((
        dur: Pseq(~measure, inf),
        amp: Pseq([0, 0, 0, 0, 0, 0, 1, 0, 1, 1])
        ))
);
~tomOffBeat_1 = Pbind(
    *~tomBarTemplate.((
        dur: Pseq(~measure, inf),
        amp: Pseq([0, 0, 0, 0, 0, 0, 0, 0, 1, 1])
        ))
);

~hihatOffBeat_2 = Pbind(
    *~kickBarTemplate.((
        instrument: \hihat,
        rel: 0.5,
        dur: Pseq(~measure, inf),
        amp: Pseq([0, 0, 1, 0, 0, 0, 1, 0, 0, 0]),
        outRec: Pfunc({~outRecHihat})
        ))
);
~kickOffBeat_2 = Pbind(
    *~kickBarTemplate.((
        dur: Pseq(~measure, inf),
        amp: Pseq([0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
        ))
);
~tomOffBeat_2 = Pbind(
    *~tomBarTemplate.((
        dur: Pseq(~measure, inf),
        amp: Pseq([0, 0, 0, 0.5, 0.8, 1, 0, 0.5, 0.8, 1])
        ))
);

// Drum fill patterns.
// 1
~kickBarFill_1 = Pbind(
    *~kickBarTemplate.((amp: Pseq([Pwrand([0, 1], [0.2, 0.8], 1), 0, 1, 0, 0, 1, 1, 1, 0, 0])))
);
~snareBarFill_1 = Pbind(
    *~snareBarTemplate.((amp: Pseq([0, 0, 0, 1, 0, 0, 0, 0, 1, 1])))
);
// 2
~kickBarFill_2 = Pbind(
    *~kickBarTemplate.((amp: Pseq([1, 0, 1, 0, 0, 0, 0, 1, 0, 0])))
);
~snareBarFill_2 = Pbind(
    *~snareBarTemplate.((amp: Pseq([0, 0, 0, 1, 0, 0, 1, 0, 1, 1])))
);
// 3
~kickBarFill_3 = Pbind(
    *~kickBarTemplate.((amp: Pseq([1, 0, 1, 0, 0, 0, 0, 1, 0, 0])))
);
~snareBarFill_3 = Pbind(
    *~snareBarTemplate.((
        pDistPreGain: Pwhite(8, 10).dbamp,
        bpfreq1: Pwhite(1800, 2100),
        amp: Pseq([0, 1, 0, 1, 1, 0, 0, 0, 1, 1])
    ))
);
~tomBarFill_3 = Pbind(
    *~tomBarTemplate.((
        dur: Pseq([1/2, 1/2, 1/2, 1/2, 1/2, 1/4, 1/4, 1/4, 1/4, 1/2, 1/2, 1/2], inf),
        amp: Pseq([0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0])
    ))
);
// 4
~kickBarFill_4 = Pbind(
    *~kickBarTemplate.((amp: Pseq([0, 0, 1, 0, 1, 0, 0, 1, 0, 0])))
);
~snareBarFill_4 = Pbind(
    *~snareBarTemplate.((
        // It is also possible to write like this:
        // (~measure * 2)[..7] ++ (~measure[8] ! 4)
        // but the explicit time measure definition is more readable.
        dur: Pseq([1/2, 1/2, 1/2, 1/2, 1/2, 1/2, 1/2, 1/2, 1/4, 1/4, 1/4, 1/4], inf),
        amp: Pseq([1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0])
        ))
);
// 5
~kickBarFill_5 = Pbind(
    *~kickBarTemplate.((
        dur: Pseq([1/2, 1/2, 1/2, 1/2, 1/2, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/2], inf),
        amp: Pseq([1,   0,   1,   0,   0,   0,   0,   1,   0,   0,   0,   0,   0,   1])
        ))
);
~snareBarFill_5 = Pbind(
    *~snareBarTemplate.((
        dur: Pseq([1/2, 1/2, 1/2, 1/2, 1/2, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/2], inf),
        amp: Pseq([0,   0,   0,   1,   0,   0,   0,   0,   0,   1,   0,   0,   1,   0])
        ))
);
~tomBarFill_5 = Pbind(
    *~tomBarTemplate.((
        dur: Pseq([1/2, 1/2, 1/2, 1/2, 1/2, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/2], inf),
        amp: Pseq([0,   0,   0,   0,   0,   1,   1,   0.6, 0,   0,   0,   0,   0,   0])
        ))
);

// 8 - Drum roll
~kickBarFill_8 = Pbind(
    *~kickBarTemplate.((amp: Pseq([1, 0, 1, 0, 0, 0, 0, 0, 0, 0])))
);
~snareBarFill_8 = Pbind(
    *~snareBarTemplate.((
        dur: Pseq((1 / ~baseQuant ! 26) ++ ~measure[6..], inf),
        amp: Pseq(0 ! 10) ++ Pgeom(0.01, 1.3, 16) ++ Pseries(0.85, 0.05, 4)
        ))
);
~tomBarFill_1 = Pbind( // TODO, silent at the moment
    *~tomBarTemplate.((amp: Pseq(0 ! 10)))
);

// Mix 1 bar straight patterns into one.
~beatBarStraight = Ptpar([
    0.0, ~hihatBarStraight, // HAT
    0.0, ~kickBarStraight, // KICK
    0.0, ~snareBarStraight, // SNARE
]);
~beatBarStraight_x2 = Ptpar([
    0.0, ~hihatBarStraight_x2, // HAT
    0.0, ~kickBarStraight_x2, // KICK
    0.0, ~snareBarStraight, // SNARE
    0.0, ~tomBarStraight, // TOM
]);

// Off-beat patterns mix.
~offBeat1 = Ptpar([
    0.0, ~hihatOffBeat_1,
    0.0, ~kickOffBeat_1,
    0.0, ~snareOffBeat_1,
    0.0, ~tomOffBeat_1,
]);

~offBeat2 = Ptpar([
    0.0, ~hihatOffBeat_2,
    0.0, ~kickOffBeat_2,
    0.0, ~tomOffBeat_2,
]);

// Mix 1 bar syncopated patterns into one.
~beatBarFill_x1_1 = Ptpar([
    0.0, ~hihatBarStraight, // HAT
    0.0, ~kickBarFill_1, // KICK
    0.0, ~snareBarFill_1, // SNARE
]);
~beatBarFill_x2_1 = Ptpar([
    0.0, ~hihatBarStraight_x2, // HAT
    0.0, ~kickBarFill_1, // KICK
    0.0, ~snareBarFill_1, // SNARE
]);
~beatBarFill_x1_2 = Ptpar([
    0.0, ~hihatBarStraight, // HAT
    0.0, ~kickBarFill_2, // KICK
    0.0, ~snareBarFill_2, // SNARE
]);
~beatBarFill_x2_2 = Ptpar([
    0.0, ~hihatBarStraight_x2, // HAT
    0.0, ~kickBarFill_2, // KICK
    0.0, ~snareBarFill_2, // SNARE
]);
~beatBarFill_x1_3 = Ptpar([
    0.0, ~hihatBarStraight, // HAT
    0.0, ~kickBarFill_3, // KICK
    0.0, ~snareBarFill_3, // SNARE
]);
~beatBarFill_x2_3 = Ptpar([
    0.0, ~hihatBarStraight, // HAT
    0.0, ~kickBarFill_3, // KICK
    0.0, ~snareBarFill_3, // SNARE
    0.0, ~tomBarFill_3, // TOM
]);
~beatBarFill_x2_4 = Ptpar([
    0.0, ~hihatBarStraight_x2, // HAT
    0.0, ~kickBarFill_4, // KICK
    0.0, ~snareBarFill_4, // SNARE
]);
~beatBarFill_x2_5 = Ptpar([
    0.0, ~hihatBarStraight_x2, // HAT
    0.0, ~kickBarFill_5, // KICK
    0.0, ~snareBarFill_5, // SNARE
    0.0, ~tomBarFill_5, // TOM
]);
~beatBarFill_x2_8 = Ptpar([
    0.0, ~hihatBarStraight, // HAT
    0.0, ~kickBarFill_8, // KICK
    0.0, ~snareBarFill_8, // SNARE
]);


// Intro drum line
~tomBarIntro = Pbind(
    *~tomBarTemplate.((
        dur: Pseq([1/2, 1/2, 1/2, 1/2, 1/2, 1/2, 1/2, 1/2, 1/2, 1/2], inf),
        amp: Pseq(0 ! 6) ++ Pgeom(1.0, 0.4, 4)
        ))
);

~snareBarIntro = Pbind(
    *~snareBarTemplate.((
        dur: Pseq((0.5 ! 6) ++ (0.25 ! 8), inf),
        amp: Pseq(0 ! 6) ++ Pgeom(0.1, 1.5, 8),
        ))
);

~beatBarIntro_singleStroke = Ptpar([
    0.0, ~hihatBarIntro, // HAT
    0.0, ~snareBarIntro, // SNARE
]);

~beatBarIntro_delay = Ptpar([
    0.0, ~hihatBarIntro, // HAT
    0.0, ~tomBarIntro, // TOM
]);

~evnts[\beat_8_intro] = Pdef(\beat_8_intro,
    Pseq([
        Pseq([~hihatBarIntro], 2),
        Pseq([~beatBarIntro_delay], 1),
        Pseq([~beatBarIntro_singleStroke], 1),
    ], inf)
);


// Base drum line.
// Hihat measures 1/8th
~evnts[\beat_8] = Pdef(\beat_8,
    Pseq([
        Pseq([~beatBarStraight], 3),
        Prand([~beatBarFill_x1_1, ~beatBarFill_x1_2], 1),
    ], inf)
);

// Off-beat pattern selection for beat_16.
~offBeatIndex = -1; // this will ensure the first pattern is ~offBeat1!
~beat_16offBeat = [~offBeat1, ~offBeat2];
// Pdefn to hold the index of beat_16 offbeat.
Pdefn(\offBeatChoice, ~beat_16offBeat[~offBeatIndex]);

// Hihat measures 1/16th
~evnts[\beat_16] = Pdef(\beat_16,
    Pseq([
        Pdefn(\offBeatChoice),

        Pseq([
            // 1st four bars: straight beat and simple syncopation
            ~beatBarStraight_x2,
            // Straight beat at the second bar is a bit more predominant to make
            // the beat feel more grounded 
            Pwrand([~beatBarStraight_x2, ~beatBarFill_x2_1], [0.7, 0.3]),
            ~beatBarStraight_x2,
            Prand([~beatBarFill_x2_2, ~beatBarFill_x2_3]),

            // 2nd four bars: more complex syncopations
            ~beatBarStraight_x2,
            // Slightly biased towards straight beat to keep the groove
            Pwrand([~beatBarStraight_x2, ~beatBarFill_x2_1], [0.8, 0.2]),
            ~beatBarStraight_x2,
            Pxrand([~beatBarFill_x2_4, ~beatBarFill_x2_5, ~beatBarFill_x2_8], 1)
        ], inf)
    ])
);


// Synths.
//
// Background pad using simple wavetables
// Warning: at the moment the chords consist of three unison voices with
// randomly chosen intervals from the scale. While it's generally ok for the
// live performance, it can lead to some weird dissonances in the recorded
// version.
// Here are few "working" chords to use for recorded version:
// [1, 3, 8]
// [0, 3, 7]
// [0, 3, 8]
~evnts[\pad] = Pbindef(\pad,
    \instrument, "osc__s2",
    \group, Pfunc({~mainGrp}),
    \dur, Pwrand([2.5, 5, 10, 15], [0.05, 0.15, 0.35, 0.45], inf),
    \atk, Pfunc({rrand(~padEnvAtk, ~padEnvAtk * 1.1) ! 3}),
    \sus, Pfunc({ ~padEnvSus ! 3 }),
    \rel, Pkey(\dur) * Pwhite(1.01, 1.15),
    \cAtk, Pexprand(1, 2),
    \cRel, Pexprand(1, 2).neg,
    \detune, Pfunc({rrand(0.15, 0.4)} ! 3),
    \bufnum, Pfunc({ ~wt_buf[3..6].choose }),
    \scale, Scale.pelog,
    \root, Pfunc({~root}),
    \octave, Pfunc({~octave}),
    \degree, Pfunc({ ([0] ++ Scale.pelog.degrees[1..] ++ [12]).scramble[0..2] }),
    \amp, Pexprand(0.07, 0.1),
    \pan, Pwhite(-0.4, 0.4),
    \out, Pfunc({~outPads}),
);

~evnts[\pad_shap] = Pbindef(\pad_shap,
    \instrument, "shaper__s2",
    \group, Pfunc({~mainGrp}),
    \dur, Pwrand([2.5, 5, 10, 15], [0.05, 0.15, 0.35, 0.45], inf),
    \atk, Pfunc({rrand(~padEnvAtk, ~padEnvAtk * 1.1) ! 3}),
    \sus, Pfunc({ ~padEnvSus ! 3 }),
    \rel, (Pkey(\dur) * Pwhite(1.01, 1.15)),
    \cAtk, Pexprand(0.01, 0.5),
    \cRel, Pexprand(1, 2).neg,
    \detune, Pfunc({rrand(0.05, 0.15)} ! 3),
    \bufnum, Pfunc({ ~tf_buf.choose }),
    \scale, Scale.pelog,
    \root, Pfunc({~root}),
    \octave, Pfunc({~octave + 3}),
    \degree, Pfunc({ ([0] ++ Scale.pelog.degrees[1..] ++ [12]).scramble[0..2] }),
    \curveMax, Pexprand(1, 5),
    \amp, Pexprand(0.07, 0.1),
    \pan, Pwhite(-0.4, 0.4),
    \out, Pfunc({~outPads}),
);


~evnts[\pad_intro] = Pbindef(\pad_intro,
    // \instrument, "shaper__s2",
    // \bufnum, Pfunc({ ~wt_buf[3..6].choose }),
    // \group, Pfunc({~mainGrp}),

    // Instead of the instructions above, use the following for sending the
    // arpeggiated melody to the external synth via MIDI:
    //
    \type, \midi,       // This is a MIDI event
    \midiout, ~midiOut, // Send it to your Neutron
    \midicmd, \noteOn,  // The command is a note (default)
    \chan, 0,           // MIDI Channel (0 is channel 1 for external synth)

    \dur, 20,
    \atk, Pfunc({rrand(~padEnvAtk, ~padEnvAtk * 1.1) ! 2}),
    \sus, Pfunc({ ~padEnvSus ! 2 }),
    \rel, Pkey(\dur) * Pwhite(1.01, 1.15), // Pfunc({ ~padEnvRel ! 2 }),
    \cAtk, Pexprand(1, 2),
    \cRel, Pexprand(1, 2).neg,
    \detune, Pfunc({rrand(0.05, 0.15)} ! 2),
    \scale, Scale.pelog,
    \root, Pfunc({~root}),
    \octave, Pfunc({~octave}),
    \degree, Pseq([[0, 7], [0, 8], [1, 3], [1, 7]], inf),
    \amp, Pexprand(0.07, 0.1),
    \pan, Pwhite(-0.4, 0.4),
    \out, Pfunc({~outPads}),
);


// 5/4 bar bass using low complexity wavetables
~evnts[\bass_s] = Pbindef(\bass_s,
    \instrument, "osc__s2",
    \bufnum, Pfunc({ ~wt_buf[0] }),
    \group, Pfunc({~mainGrp}),
    \dur, Pseq([1, 1/2, 1/2, 1/2, 1, 1/2, 1/2, 1/2], inf),
    \atk, 0.001,
    \sus, 0.2,
    \rel, Pexprand(0.4, 1),
    \cAtk, 0,
    \cRel, Pwhite(5, 10).neg,
    \detune, Pwhite(0.05, 0.08, inf),
    \scale, Scale.pelog,
    \degree, Pseq([0, 0, 0, Rest(), Prand([1, 3, 7], 1), 1, Prand([1, 3], 1), Rest()], inf),
    \root, Pfunc({~root}),
    \octave, Pfunc({~octave}),
    \amp, Pwhite(0.55, 0.65, inf),
    \pan, Pwhite(0.01, 0.3) * Pseq([1, -1], inf),
    \out, Pfunc({~outBass}),
);

// Arpeggiated bass using the first wavetable (low complexity roughly eq to sine)
~evnts[\bass] = Pbindef(\bass,
    \instrument, "osc__s2",
    \group, Pfunc({~mainGrp}),
    \dur, Pseq([
        myPrepeat.new(16, Pseq([1/2], 1)),
        myPrepeat.new(8, Pseq([1], 1)),
        Prand([2, 4, 8], 1)
    ], inf),
    \atk, 0.001,
    \sus, 0.2,
    \rel, Pexprand(0.4, 1),
    \cAtk, 0,
    \cRel, Pwhite(5, 10).neg,
    \detune, 0.01,
    \bufnum, Pfunc({ ~wt_buf[0] }),
    \scale, Scale.pelog,
    \degree, Pseq([Prand([0, 1, 3], 24), Pseq([\], 1)], inf)
        + myPrepeat.new(25, Pwrand([0, 3, -4], [0.78, 0.1, 0.12], inf)),
    \root, Pfunc({~root}),
    \octave, Pfunc({~octave}),
    \amp, Pseq([Pwhite(0.55, 0.65, 25)], inf),
    \pan, Pwhite(0.01, 0.3) * Pseq([1, -1], inf),
    \out, Pfunc({~outBass}),
);


// Arpeggiated pulse using mid/high complexity wavetables
~evnts[\pulse] = Pbindef(\pulse,
    \instrument, "osc__s2",
    \group, Pfunc({~mainGrp}),
    \dur, Pseq([
        myPrepeat.new(16, Pseq([1/2], 1)),
        myPrepeat.new(8, Pseq([1], 1)),
        Prand([2, 4, 8, 12, 24], 1)
    ], inf),
    \atk, 0.001,
    \sus, 0.2,
    \rel, Pexprand(0.4, 1),
    \cAtk, 0,
    \cRel, Pwhite(5, 10).neg,
    \detune, 0.3,
    // Higher complexity wavetables for the first 8 bars to make the pulse more prominent in the mix
    // Next 8 bars - mid complexity to give the pulse a bit more space and avoid masking the bass
    // Last 8 bars (plus one extra-note) - low complexity to make the pulse more subdued
    \bufnum, Pseq([
        Pfuncn({~wt_buf[7..9].choose}, 8),
        Pfuncn({~wt_buf[5..7].choose}, 8),
        Pfuncn({~wt_buf[4..5].choose}, 9)
    ], inf),
    \scale, Scale.pelog,
    \degree, (
        Pseq([Prand([0, 1, 7], 24), Pseq([\], 1)], inf)
        + myPrepeat.new(25, Pwrand([12, 15, 8], [0.78, 0.1, 0.12], inf))
    ),
    \root, Pfunc({~root}),
    \octave, Pfunc({~octave - 3}),
    \amp, Pseq([Pgeom(0.45, -1.dbamp, 25)], inf),
    \pan, Pwhite(0.01, 0.3) * Pseq([1, -1], inf),
    \out, Pfunc({~outMelody}),
);

// Minimal melody in the upper register using variable wavetable oscillator
~evnts[\melody] = Pbindef(\melody,
    \instrument, "vosc__s2",
    \group, Pfunc({~mainGrp}),
    \dur, Prand([
        Pseq([4, 3, 1, Prand([24, 32, 40])], 1),
        Pseq([3, 2, 3, Prand([24, 32, 40])], 1),
    ], inf),
    \atk, 0.01,
    \sus, 0.3,
    \rel, 1.5,
    \cAtk, -2,
    \cRel, -2,
    \detune, Pexprand(0.18, 0.25),
    \bufnum, Pwrand([
        Pfunc({ ~wt_buf[0] }),
        Pfunc({ ~wt_buf[1] }),
        Pfuncn({ ~wt_buf[2] }, 2),
    ], [1, 3, 9].normalizeSum, inf),
    \numBufs, Prand((2..4), inf),
    \scale, Scale.pelog,
    \root, Pfunc({~root}),
    \octave, Pfunc({~octave + 2}),
    \degree, Pxrand([
        Pseq([7,  0, Prand([-4, 12, \]), \], 1),
        Pseq([7, -4, Prand([-5, 3, \]), \], 1),
        Pseq([8, 12, Prand([7, 8, \]), \], 1)
    ], inf),
    \amp, Pseq([0.18, 0.24, 0.28, 0], inf),
    \out, Pfunc({~outMelody}),
);

// More complex melody using variable wavetable oscillator and more rhythmic variation.
~evnts[\arpg] = Pbindef(\arpg,
    \instrument, "osc__s2",
    \bufnum, Pfunc({~wt_buf[2..4].choose}),
    \group, Pfunc({~mainGrp}),

    // Instead of the instructions above, use the following for sending the
    // arpeggiated melody to the external synth via MIDI:
    //
    // \type, \midi,       // This is a MIDI event
    // \midiout, ~midiOut, // Send it to your Neutron
    // \midicmd, \noteOn,  // The command is a note (default)
    // \chan, 0,           // MIDI Channel (0 is channel 1 for external synth)

    \dur, Pseq((1/2) ! 8, inf),
    \atk, 0.001,
    \sus, 0.2,
    \rel, Pexprand(0.4, 1),
    \cAtk, 0,
    \cRel, Pwhite(5, 10).neg,
    \detune, Pexprand(0.18, 0.25),
    \scale, Scale.pelog,

    // The following creates a repeating pattern:
    // c 4 -  c 4 -  § -  g 3 -  g#3 -  c 4 -  c 4 -  § -  g 3 -  g#3 -  c 4 -  c 4 -  § -  c#3 -  d#3 -  c 4 -  c 4 -  § -  c#3 -  c#3 -  c 4 -  c 4 -  § -  c 3
    // which is 24 of the 4ths notes long, and thus fits nicely into the 5/4 time signature (24 x 1/4 = 6 bars).
    \degree, Place(#[12, 12, \, [7, 7, 1, 1, 0], [8, 8, 3, 1, \]], inf),
    \root, Pfunc({~root}),
    \octave, Pfunc({~octave}),
    \amp, Pseq([Pgeom(0.45, -1.dbamp, 8)], inf),
    \pan, Pwhite(0.01, 0.3) * Pseq([1, -1], inf),
    \out, Pfunc({~outMelody}),
);


~evnts[\mix_full] = Pdef(\mix_full,
    Ptpar([
        // 0.0, ~evnts[\beat_8].value,
        0.0, ~evnts[\beat_16].value,
        0.0, ~evnts[\bass].value,
        0.0, ~evnts[\pad].value,
        0.0, ~evnts[\pulse].value,
        0.0, ~evnts[\melody].value,
    ], inf)
);
)
