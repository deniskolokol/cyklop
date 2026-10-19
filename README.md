# Cyklop

Inspired by the Cyklop (from "Niezwićiężony" by Stanisław Lem): an 80-ton, self-propelled and self-steering, unmanned armored vehicle equipped with a full arsenal of weapons, including an antimatter launcher.

A learning-focused project in SuperCollider exploring:
- **Wavetable synthesis**
- **Drum synthesis**
- **Pattern-based scheduling**

This repository contains all the code for a musical piece, structured into the following files:

- `main.scd` – Infrastructure setup (buses, synths) and pattern playback
- `synthdef.scd` – Synth definitions
- `patterns.scd` – Pattern definitions and sequencing logic
- `midi.scd` – MIDI input handling and controller mapping
- `gui.scd` – GUI controls and visual interface

## What it does

It’s a playable SuperCollider piece with drum, bass, pad, and melody patterns, running at 120 BPM in 5/8. The patterns and timing are defined in patterns.scd.

## How to run

1. Clone the repo.
2. Install the TabbedView2 Quark by running `Quarks.install("TabbedView2")`.
3. Download [TempoView.sc](https://github.com/deniskolokol/sc-utils/blob/main/SC3plugins/TempoView.sc) and place it in your extensions directory.
4. In SuperCollider IDE open `main.scd`.
5. First stop currently running local servers (use _Server / Kill all servers_ or the first command in the `main.scd`).
6. Adjust settings to your current situation: set `~extSynthName`, `~audioInterfaceName`, and Server options (`s.options`) in the beginning of `main.scd`.
7. Run `main.scd`

## How to record

The recording via GUI is designed to record the whole thing multi-channel - i.e. starting from the first output channel by the last one. If you wish to record separate channels, first establish the channels (see the section `// Routing` in the beginning of `patterns.scd`) and use the following:

    s.record(bus: <bus num>, numChannels: <num channels>);

where `<bus num>` is a starting bus number, and `<num channels>` is how many channels should be recorded.

Warning: for drums a separate additional output bus are set for the purpose of recording each drum separately. Few examples:

    s.record(bus: ~outRecHihat, numChannels: 2); // hi-hat is stereo
    s.record(bus: ~outRecSnare, numChannels: 1); // snare and the rest
                                                 // of drums are mono


## Note on MIDI

MIDI devices used for output:

- External synth - set the appropriate value to the variable `~extSynthName` in the beginning of `main.scd`
- Audio interface - set `~audioInterfaceName` right after that. This is used for the cases when SuperCollider connects to the external synth not via USB, but via MIDI.

MIDI devices used for input and control (optional):

- Arturia MINILAB 3: `MidiEndPoint("Minilab3", "MIDI")`
- M-AUDIO X-Session Pro: `MidiEndPoint("USB X-Session", "Port 1")`

Arturia MINILAB's 8 pads used for launching the following patterns:
_beat_8, beat_16, pad, pad_shap, bass, bass_s, pulse, melody_

MINILAB's sliders control ADSR for pads.

Top row of MINILAB's knobs are set to control distortion (for drums), while bottom row control Low Pass Filter freq and resonance, as well as Reverb xFade and mix.

## Inspirations

Geat tutorial series of [Eli Fieldsteel](https://www.youtube.com/@elifieldsteel) and valuable experimental videos by [Nathan Ho](https://www.youtube.com/@synth_def).

## Future

This project is finished and the author isn't going to develop it any further. However there are three more projects that originate from this one:

- Live rig that would include Pattern-based sequencer and distribute messages across serveral synths written in SuperCollider as well as external hardware synths
- Control panel for a wavetable / waveshape synth realized as a hardware on Raspberry Pi.
- Drum synth and sequencer.
