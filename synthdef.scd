(
// DRUMS.

// Kick drums and snare are inspired by:
// https://www.youtube.com/watch?v=xYc7_PbbtuE&list=WL&index=59&t=2s

// Synthetic kick drum.
SynthDef(\kick_synth, {
    arg out=0, att=0.001, rel=0.8, curve=(-8), amp=0.5, pan=0,
        bpfreq=10120, bprq=0.5;

    // Base frequency with a slight downhill (XLine) - to make kick sounding less "tonal".
    var sndfreq = 55 * (1 + (4 * Env.perc(0, 0.13, curve: curve).ar)) * XLine.ar(1, 0.5, 1);
    var snd = SinOsc.ar(sndfreq);

    // Add a second sine wave with a fast chirp.
    snd = snd + (SinOsc.ar(XLine.ar(4000, 50, 0.01)) * Env.perc(0.0001, 0.01).ar * -5.dbamp);

    // Add some filtered (deterministic!) noise.
    snd = snd + (BPF.ar(Hasher.ar(Sweep.ar), bpfreq, bprq) * Env.perc(0.001, 0.03).ar * -8.dbamp);

    // Glue it all together by a light distortion.
    snd = snd * (1 + (2 * Env.perc(0.001, 2.2).ar));
    snd = (snd * 0.dbamp).tanh;

    // Sculpt by percussion env.
    snd = snd * Env.perc(att, rel, curve: curve).ar(Done.freeSelf);
    snd = snd * amp;
    snd = Pan2.ar(snd, pan);
    Out.ar(out, snd);
}).add;


// "Acoutsic" kick drum
SynthDef(\kick_acoustic, {
    arg out=0, att=0.001, rel=1.3, curve=(-6), amp=0.56, pan=0,
        bpfreq1=7120, bprq1=0.5, bpfreq2=3120, bprq2=0.3;

    var snd, sndfreq;

    // For acoustic effect layering many sine waves with different frequencies...
    sndfreq = 60 * (1 + (8 * Env.perc(0, 0.06, curve: -4).ar)) * XLine.ar(1, 0.9, 1);
    sndfreq = sndfreq * [1, 1.3, 2.4, 2.6, 2.8, 3.3, 3.4];
    snd = SinOsc.ar(sndfreq);

    // ...as well as amplitudes, attacks and release times.
    snd = snd * [0, -10, -5, -19, -15, -20, -25].dbamp;
    snd = snd * Env.perc(
        attackTime: [0.01, 0.01, 0.015, 0.01, 0.03, 0.01, 0.02] * 0.5,
        releaseTime:[1,    0.3,  0.1,   0.03, 0.05, 0.03, 0.06] * 3
    ).ar;

    // Mix it together.
    snd = snd.sum;

    // Add some filtered noise.
    snd = snd + (BPF.ar(WhiteNoise.ar, bpfreq1, bprq1) * Env.perc(0.001, 0.01).ar * -8.dbamp);
    snd = snd + (BPF.ar(WhiteNoise.ar, bpfreq2, bprq2) * Env.perc(0.001, 0.08).ar * -8.dbamp);

    // Glue it all together by a light distortion.
    snd = (snd * 4.dbamp).tanh;

    // Smooth it out by a little reverb.
    snd = snd + (GVerb.ar(snd, 6, 1) * -30.dbamp);

    // Sculpt by percussion env.
    snd = snd * Env.perc(att, rel, curve: curve).ar(Done.freeSelf);
    snd = snd * amp;
    snd = Pan2.ar(snd, pan);
    Out.ar(out, snd);
}).add;

SynthDef(\snare, {
    arg out=0, rout=0, rsend=(-20),
        att=0.001, rel=0.6, curve=(-4), amp=0.56, pan=0,
        bpfreq1=2120, bprq1=0.3, bpfreq2=4120, bprq2=0.6,
        pDistPreGain=4.4668359215096, // 13.dbamp
        pDistGain=0.31622776601684; // -10.dbamp

    var snd, sndfreq;
    sndfreq = 200 * (1 + (2 * Env.perc(0.001, 0.03).ar)) * [1, 2.3, 3.5, 5.8];
    snd = SinOsc.ar(sndfreq);
    snd = snd * Env.perc(0, [2, 0.4, 0.2, 0.1]).ar;
    snd = snd * [0, -20, -12, -24].dbamp;
    snd = snd.sum;

    // Give it some punch (add click).
    snd = snd + (SinOsc.ar(XLine.ar(3000, 100, 0.03)) * Env.perc(0.01, 0.03).ar);

    // Add noise.
    snd = snd + (BPF.ar(Hasher.ar(Sweep.ar), bpfreq1, bprq1) * Env.perc(0.05, 0.1).ar * -3.dbamp);

    // Second layer of noise to make it less dull.
    snd = snd + (BPF.ar(Hasher.ar(Sweep.ar), bpfreq2, bprq2) * Env.perc(0.003, 0.15).ar * -8.dbamp);

    // Parallel distortion which has the benefit of filtering:
    // distortion adds sum/diff tones that multiplies the number of partials
    // in clanky snares. Additionally if the original partials have different
    // decay times, the sum/diff tones will also have different decay times,
    // which leads to timbral variation, and therefore more realistic (less
    // synthetic) output.
    // snd = snd + ((snd * 13.dbamp).tanh * -10.dbamp);
    snd = snd + ((snd * pDistPreGain).tanh * pDistGain);

    // Add PitchShift for a real clanky snare.
    snd = snd + LPF.ar(PitchShift.ar(snd, 0.005, 1.8) * -4.dbamp, 3000);

    snd = snd * Env.perc(att, rel, curve: curve).ar;

    // Distortion can sound a little warmer if you cut the highs, then distort,
    // them bring them back on.
    // WARNING: always put distortion after the Env!
    snd = BHiShelf.ar((LPF.ar(snd, 8000) * 2.dbamp).tanh, 8000, 10);

    // Add some reverb and the second env so it can ring out.
    // Important: GVerb is mono-to-stereo, avoiding Pan2!
    snd = snd + (GVerb.ar(snd, 16, 2) * -30.dbamp);
    snd = Splay.ar(snd, center: pan);

    // Sculpt by percussion env.
    snd = snd * Env.perc(0.001, 1, curve: curve).ar(Done.freeSelf);
    snd = snd * amp;

    Out.ar(out, snd);
    Out.ar(rout, snd * rsend.dbamp); //"post-fader" send to reverb
}).add;


SynthDef(\tom, {
    arg out=0, rout=0, rsend=(-20),
        att=0.001, rel=0.6, curve=(-4), amp=0.56, pan=0,
        bpfreq1=2120, bprq1=0.3, bpfreq2=4120, bprq2=0.6;

    var snd, sndfreq;
    sndfreq = 130 * (1 + (2 * Env.perc(0.001, 0.03).ar)) * [0.85, 0.82, 0.8, 0.77, 0.74];
    snd = SinOsc.ar(sndfreq);
    snd = snd * Env.perc(
        [0, 0.001, 0.1,  0.3, 0.333],
        [2,   0.4, 0.1, 0.05, 0.01]
    ).ar;
    snd = snd * [0, -20, -12, -24, -18, -22].dbamp;
    snd = snd.sum;

    // Give it some punch (add click).
    snd = snd + (SinOsc.ar(XLine.ar(3000, 100, 0.03)) * Env.perc(0.01, 0.03).ar);

    // Add noise.
    snd = snd + (BPF.ar(Hasher.ar(Sweep.ar), bpfreq1, bprq1) * Env.perc(0.05, 0.1).ar * -3.dbamp);

    snd = snd * Env.perc(att, rel, curve: curve).ar;

    // Distortion can sound a little warmer if you cut the highs, then distort,
    // them bring them back on.
    // WARNING: always put distortion after the Env!
    snd = BHiShelf.ar((LPF.ar(snd, 8000) * 2.dbamp).tanh, 8000, 10);

    // Add some reverb and the second env so it can ring out.
    // Important: GVerb is mono-to-stereo, avoiding Pan2!
    snd = snd + (GVerb.ar(snd, 16, 2) * -30.dbamp);
    snd = Splay.ar(snd, center: pan);

    // Sculpt by percussion env.
    snd = snd * Env.perc(0.001, 1, curve: curve).ar(Done.freeSelf);
    snd = snd * amp;

    Out.ar(out, snd);
    Out.ar(rout, snd * rsend.dbamp); //"post-fader" send to reverb
}).add;


SynthDef(\hihat, {
    arg out=0, amp=0.5, att=0.01, rel=0.2, ffreq=6000, pan=0;
    var env = EnvGen.kr(Env.perc(att, rel, amp), doneAction: Done.freeSelf);
    var signal = HPF.ar(
        LPF.ar(WhiteNoise.ar, freq: ffreq),
        Rand(1000, 8000)
    );
    signal = signal * env;
    Out.ar(out, Pan2.ar(signal, pan));
}).add;


// Wavetable synthesis.
SynthDef(\osc, {
    arg buf=0, freq=200, detune=0.2,
        amp=0.2, pan=0, out=0, rout=0, rsend=(-20),
        atk=0.01, sus=1, rel=0.01, c0=1, c1=(-1);

    var sig, env, detuneCtrl;
    env = EnvGen.ar(
        Env([0, 1, 1, 0], [atk, sus, rel], [c0, 0, c1]),
        doneAction: Done.freeSelf
    );

    // Array of eight Oscs with uniquely detune frequencies
    // and unique initial phase offsets
    detuneCtrl = LFNoise1.kr(0.1!8).bipolar(detune).midiratio;
    sig = Osc.ar(buf, freq * detuneCtrl, {Rand(0,2pi)}!8);

    sig = Splay.ar(sig); //spread 8 signals over stereo field
    sig = LeakDC.ar(sig); //remove DC bias
    sig = Balance2.ar(sig[0], sig[1], pan, amp); //L/R balance (pan)
    sig = sig * env;
    Out.ar(out, sig);
    Out.ar(rout, sig * rsend.dbamp); //"post-fader" send to reverb
}).add;


// FX.
SynthDef(\reverb, {
    arg in, out=0, predelay=0.1, revtime=1.8, lpf=4500, amp=1, mix=0.15;
    var dry, wet, temp, sig;
    dry = In.ar(in, 2);
    temp = In.ar(in, 2);
    wet = 0; // or `DC.ar(0)!2` or `Silent.ar(2)`
    temp = DelayN.ar(temp, 0.2, predelay);
    16.do {
        temp = AllpassN.ar(temp, 0.05, {Rand(0.001, 0.05)}!2, revtime);
        temp = LPF.ar(temp, lpf);
        wet = wet + temp
    };
    sig = XFade2.ar(dry, wet, mix*2-1, amp);
    Out.ar(out, sig);
}).add;
)
