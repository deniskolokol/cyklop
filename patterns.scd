// Cyklop patterns
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

~baseQuant = 16;
~stretch = 25/128 * ~baseQuant;
~freq = 2;
~measure = 1 / ~baseQuant ! 10 * ~freq;
~tempo = TempoClock.new(120/60).schedAbs(0, { ~tempo.beatsPerBar_(5) });

// Warning: every event that should be controlled by MIDI
// should be defined as Pdef!
~evnts = Dictionary.new;

// 1 bar straignt patterns.
~hihatBarStraight = Pbind(
    \instrument, \hihat,
    \dur, Pseq(~measure * 2, inf),
    \amp, Pwhite(0.5, 1.0, 10),
    \rel, Pwrand([0.02, 0.1, 0.5], [0.7, 0.15, 0.15], 10),
    \pan, Pgauss(0, 0.7, 10),
    \out, Pfunc({~outDrums})
);
~hihatBarStraight_x2 = Pbind(
    \instrument, \hihat,
    \dur, Pseq(~measure, inf),
    \amp, Pwhite(0.5, 1.0, 20),
    \rel, Pwrand([0.02, 0.1, 0.5], [0.7, 0.15, 0.15], 20),
    \pan, Pgauss(0, 0.7, 20),
    \out, Pfunc({~outDrums})
);

// Define templates as Events.
~snareBarTemplate = { |params|
    var baseEvent = (
        instrument: \snare,
        dur: Pseq(~measure * 2, inf),
        pDistPreGain: Pwhite(11, 13).dbamp,
        pDistGain: Pwhite(-8, -10).dbamp,
        bpfreq1: Pwhite(2000, 2300),
        bprq1: Pwhite(0.2, 0.5),
        bpfreq2: Pwhite(3800, 4300),
        bprq2: Pwhite(0.5, 0.7),
        pan: Pwhite(-0.4, -0.7), // Spread snare slightly left of center
        out: Pfunc({~outDrums})
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
        instrument: \kick_acoustic, // \kick_synth
        dur: Pseq(~measure * 2, inf),
        out: Pfunc({~outDrums})
    );
    if (params.notNil) {
        baseEvent = baseEvent.putAll(params);
    };
    baseEvent.asPairs;
};
~tomBarTemplate = { |params|
    var baseEvent = (
        instrument: \tom,
        dur: Pseq(~measure * 2, inf),
        pan: Pwhite(0.2, 0.5), // Spread toms slightly right of center
        out: Pfunc({~outDrums})
    );
    if (params.notNil) {
        baseEvent = baseEvent.putAll(params);
    };
    baseEvent.asPairs;
};

// Straight patterns.
~kickBarStraight = Pbind(
    *~kickBarTemplate.((amp: Pseq([1, 0, 1, 0, 0, 0, 1, 1, 0, 0])))
);
~snareBarStraight = Pbind(
    *~snareBarTemplate.((amp: Pseq([0, 0, 0, 1, 0, 0, 0, 0, 1, 0])))
);
~tomBarStraight = Pbind(
    *~tomBarTemplate.((amp: Pseq([0, 0, 0, 0, 0, 1, Pwrand([1, 0], [0.7, 0.3], 1), 0, 0, 1])))
);

// Off-beat
~hihatOffBeat_1 = Pbind(
    *~kickBarTemplate.((
        instrument: \hihat,
        rel: 0.5,
        dur: Pseq([1/4, 1/4, 1/4, 1/4, 1/4, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8], inf),
        amp: Pseq([0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   0,   1,   0,   0,   0])
        ))
);
~kickOffBeat_1 = Pbind(
    *~kickBarTemplate.((
        dur: Pseq([1/4, 1/4, 1/4, 1/4, 1/4, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8], inf),
        amp: Pseq([0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   0,   1,   0,   0,   0])
        ))
);
~tomOffBeat_1 = Pbind(
    *~tomBarTemplate.((
        dur: Pseq([1/4, 1/4, 1/4, 1/4, 1/4, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8], inf),
        amp: Pseq([0,   0,   0,   0,   0,   0,   0,   0,   0.5, 0.8, 1,   0,   0.5, 0.8, 1])
        ))
);

// Syn patterns.
// 1
~kickBarSyn_1 = Pbind(
    *~kickBarTemplate.((amp: Pseq([Pwrand([0, 1], [0.2, 0.8], 1), 0, 1, 0, 0, 1, 1, 1, 0, 0])))
);
~snareBarSyn_1 = Pbind(
    *~snareBarTemplate.((amp: Pseq([0, 0, 0, 1, 0, 0, 0, 0, 1, 1])))
);
// 2
~kickBarSyn_2 = Pbind(
    *~kickBarTemplate.((amp: Pseq([0, 1, 0, 0, 1, 0, 0, 1, 0, 0])))
);
~snareBarSyn_2 = Pbind(
    *~snareBarTemplate.((amp: Pseq([1, 0, 0, 1, 0, 0, 1, 0, 1, Prand([0, 1], 1)])))
);
// 3
~kickBarSyn_3 = Pbind(
    *~kickBarTemplate.((amp: Pseq([1, 0, 1, 0, 0, 0, 0, 1, 0, 0])))
);
~snareBarSyn_3 = Pbind(
    *~snareBarTemplate.((
        pDistPreGain: Pwhite(8, 10).dbamp,
        bpfreq1: Pwhite(1800, 2100),
        amp: Pseq([0, 1, 0, 1, 1, 0, 0, 0, 1, 1])
    ))
);
~tomBarSyn_3 = Pbind(
    *~tomBarTemplate.((
        dur: Pseq([1/4, 1/4, 1/4, 1/4, 1/4, 1/8, 1/8, 1/8, 1/8, 1/4, 1/4, 1/4], inf),
        amp: Pseq([0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0])
    ))
);
// 4
~kickBarSyn_4 = Pbind(
    *~kickBarTemplate.((amp: Pseq([0, 0, 1, 0, 1, 0, 0, 1, 0, 0])))
);
~snareBarSyn_4 = Pbind(
    *~snareBarTemplate.((
        // It is also possible to write like this:
        // (~measure * 2)[..7] ++ (~measure[8] ! 4)
        // but the explicit time measure definition is more readable.
        dur: Pseq([1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/8, 1/8, 1/8, 1/8], inf),
        amp: Pseq([1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0])
        ))
);
// 5
~kickBarSyn_5 = Pbind(
    *~kickBarTemplate.((
        dur: Pseq([1/4, 1/4, 1/4, 1/4, 1/4, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/4], inf),
        amp: Pseq([1,   0,   1,   0,   0,   0,   0,   1,   0,   0,   0,   0,   0,   1])
        ))
);
~snareBarSyn_5 = Pbind(
    *~snareBarTemplate.((
        dur: Pseq([1/4, 1/4, 1/4, 1/4, 1/4, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/4], inf),
        amp: Pseq([0,   0,   0,   1,   0,   0,   0,   0,   0,   1,   0,   0,   1,   0])
        ))
);
~tomBarSyn_5 = Pbind(
    *~tomBarTemplate.((
        dur: Pseq([1/4, 1/4, 1/4, 1/4, 1/4, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/8, 1/4], inf),
        amp: Pseq([0,   0,   0,   0,   0,   1,   1,   0.6, 0,   0,   0,   0,   0,   0])
        ))
);

// 8 - Drum roll
~kickBarSyn_8 = Pbind(
    *~kickBarTemplate.((amp: Pseq([1, 0, 1, 0, 0, 0, 0, 0, 0, 0])))
);
~snareBarSyn_8 = Pbind(
    *~snareBarTemplate.((
        dur: Pseq((1 / ~baseQuant ! 26) ++ ~measure[6..], inf),
        amp: Pseq(0 ! 10) ++ Pgeom(0.01, 1.3, 16) ++ Pseries(0.85, 0.05, 4)
        ))
);
~tomBarSyn_1 = Pbind( // TODO, silent at the moment
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
    0.0, ~kickBarStraight, // KICK
    0.0, ~snareBarStraight, // SNARE
    0.0, ~tomBarStraight, // TOM
]);

// Off-beat pattern mix.
~offBeat1 = Ptpar([
    0.0, ~hihatOffBeat_1,
    0.0, ~kickOffBeat_1,
    0.0, ~tomOffBeat_1,
]);

// Mix 1 bar syncopated patterns into one.
~beatBarSyn_x2_1 = Ptpar([
    0.0, ~hihatBarStraight_x2, // HAT
    0.0, ~kickBarSyn_1, // KICK
    0.0, ~snareBarSyn_1, // SNARE
]);
~beatBarSyn_x2_2 = Ptpar([
    0.0, ~hihatBarStraight_x2, // HAT
    0.0, ~kickBarSyn_2, // KICK
    0.0, ~snareBarSyn_2, // SNARE
]);
~beatBarSyn_x2_3 = Ptpar([
    0.0, ~hihatBarStraight, // HAT
    0.0, ~kickBarSyn_3, // KICK
    0.0, ~snareBarSyn_3, // SNARE
    0.0, ~tomBarSyn_3, // TOM
]);
~beatBarSyn_x2_4 = Ptpar([
    0.0, ~hihatBarStraight_x2, // HAT
    0.0, ~kickBarSyn_4, // KICK
    0.0, ~snareBarSyn_4, // SNARE
]);
~beatBarSyn_x2_5 = Ptpar([
    0.0, ~hihatBarStraight_x2, // HAT
    0.0, ~kickBarSyn_5, // KICK
    0.0, ~snareBarSyn_5, // SNARE
    0.0, ~tomBarSyn_5, // TOM
]);
~beatBarSyn_x2_8 = Ptpar([
    0.0, ~hihatBarStraight, // HAT
    0.0, ~kickBarSyn_8, // KICK
    0.0, ~snareBarSyn_8, // SNARE
]);

// Base drum line.
~evnts.add(\beat_base_x1 -> {
    ~beatBase_x1 = Pdef(
        \beat_base_x1,
        Pseq([~beatBarStraight], inf)
    );
});
~evnts.add(\beat_base_x2 -> {
    ~beatBase_x2 = Pdef(
        \beat_base_x2,
        Pseq([
            ~beatBarStraight_x2,
            // Straight beat at the second bar is a bit more predominant to make
            // the beat feel more grounded 
            Pwrand([~beatBarStraight_x2, ~beatBarSyn_x2_1], [0.7, 0.3]),
            ~beatBarStraight_x2,
            Pxrand([
                ~beatBarSyn_x2_2,
                ~beatBarSyn_x2_3,
                ~beatBarSyn_x2_4,
                ~beatBarSyn_x2_5,
                ~beatBarSyn_x2_8
            ], 1)
        ], inf)
    );
});

// Synths.
// background pad using simple wavetables
~evnts.add(\pad -> {
    ~pad = Pbindef(\pad,
        \instrument, "osc__s2",
        \dur, Pwrand([1, 4, 6, 9, 12], [0.35, 0.25, 0.2, 0.15, 0.05], inf),
        \atk, Pexprand(0.5, 2),
        \sus, 0,
        \rel, Pexprand(5, 10),
        \cAtk, Pexprand(1, 2),
        \cRel, Pexprand(1, 2).neg,
        \detune, Pfunc({rrand(0.15, 0.4)} ! 3),
        \bufnum, Pfunc({ ~wt_buf[3..6].choose }),
        \scale, Scale.pelog,
        \root, Pfunc({~root}),
        \octave, Pfunc({~octave}),
        \degree, Pfunc({ ([0] ++ (Scale.pelog.degrees) ++ [12]).scramble[0..rrand(1, 3)] }),
        \amp, Pexprand(0.07, 0.1),
        \pan, Pwhite(-0.4, 0.4),
        \out, 0,
        \rout, ~bus[\reverb],
        \rsend, -10,
    )
});

~evnts.add(\pad_s -> {
    ~pad_s = Pbindef(\pad_s,
        \instrument, "shaper__s2",
        \dur, Pwrand([1, 4, 6, 9, 12], [0.35, 0.25, 0.2, 0.15, 0.05], inf),
        \atk, Pexprand(0.5, 2),
        \sus, 0,
        \rel, Pexprand(5, 10),
        \cAtk, Pexprand(0.01, 0.5),
        \cRel, Pexprand(1, 2).neg,
        \detune, Pfunc({rrand(0.15, 0.4)} ! 3),
        \bufnum, Pfunc({ ~tf_buf.choose }),
        \scale, Scale.pelog,
        \root, Pfunc({~root}),
        \octave, Pfunc({~octave}),
        \degree, Pfunc({ ([0] ++ (Scale.pelog.degrees) ++ [12]).scramble[0..rrand(1, 3)] }),
        \curveMax, Pexprand(1, 5),
        \amp, Pexprand(0.1, 0.3),
        \pan, Pwhite(-0.4, 0.4),
        \out, 0,
        \rout, ~bus[\reverb],
        \rsend, -20,
    )
});

// Arpeggiated bass pulse using mid/high complexity wavetables
~evnts.add(\pulse -> {
    ~pulse = Pbindef(\pulse,
        \instrument, "osc__s2",
        \dur, Pseq([
            myPrepeat.new(16, Pseq([1/4], 1)),
            myPrepeat.new(8, Pseq([1/2], 1)),
            Prand([1, 2, 4, 6, 12], 1)
        ], inf),
        \atk, 0.001,
        \sus, 0.2,
        \rel, Pexprand(0.4, 1),
        \cAtk, 0,
        \cRel, Pwhite(5, 10).neg,
        \detune, 0.3,
        \bufnum, Pfunc({ ~wt_buf[4..9].choose }),
        \scale, Scale.pelog,
        \degree, Pseq([Prand([0, 1, 7], 24), Pseq([\], 1)], inf)
            + myPrepeat.new(25, Pwrand([12, 15, 8], [0.78, 0.1, 0.12], inf)),
        \root, Pfunc({~root}),
        \octave, Pfunc({~octave - 2}),
        \amp, Pseq([Pgeom(0.45, -1.dbamp, 25)], inf),
        \pan, Pwhite(0.01, 0.3) * Pseq([1, -1], inf),
        \out, 0,
        \rout, ~bus[\reverb],
        \rsend, -10,
    )
});

// Minimal melody in the upper regfister using variable wavetable oscillator
~evnts.add(\melody -> {
    ~melody = Pbindef(\melody,
        \instrument, "vosc__s2",
        \dur, Prand([
            Pseq([2, 1.5, 0.5, Prand([12, 16, 20])], 1),
            Pseq([1.5, 1, 1.5, Prand([12, 16, 20])], 1),
        ], inf),
        \atk, 0.01,
        \sus, 0.3,
        \rel, 1.5,
        \cAtk, -2,
        \cRel, -2,
        \detune, Pexprand(0.18,0.25),
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
        \out, 0,
        \rout, ~bus[\reverb],
        \rsend, -6,
    )
});

~evnts.add(\mix_full -> {
    ~mixFull = Pdef(
        \mix_full,
        Ptpar([
            // 0.0, ~evnts[\beat_base_x1].value,
            0.0, ~evnts[\beat_base_x2].value,
            0.0, ~evnts[\pad].value,
            0.0, ~evnts[\pulse].value,
            0.0, ~evnts[\melody].value,
        ], inf)
    );
});
)