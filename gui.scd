(
var margin=10, gap=5;
var colorButton=Color.grey(0.3);
var colorPane=Color.grey(0.1);
var transparent=Color.grey(alpha:0.0);

// Wavetable GUI Visualizer
var createWavetableGUI = {
    arg wtArr,
        makeBuffersFunc,
        parent,
        label,
        signalType,
        height=200,
        width=800;

    var scrollView, plotView;
    var plotHeight = height - 60 - (margin * 4);

    // Function to update all plots
    var updateWavetablePlots = { |plotView|
        var freshArray = if(signalType == \wavetable) { ~wt_sig } { ~tf_sig };
        "> Updating wavetable plots...".postln;
        if (freshArray.notNil) {
            plotView.value = freshArray;
            plotView.refresh;
        } {
            "No wavetable signals found. Fill signals first.".warn;
        }
    };

    StaticText(parent, Rect(0, 0, width, 30))
        .string_(label)
        .font_(Font("Arial", 16))
        .stringColor_(Color.white);

    // Create the plot view
    plotView = Plotter(
        name: "WT",
        bounds: Rect(0, 0, width-(margin * 2), plotHeight),
        parent: parent
    );
    plotView.value = wtArr;
    plotView.editMode = true;
    plotView.setProperties(
        \fontColor, Color(0.5, 1, 0);,
        \plotColor, Color.red(0.7),
        \backgroundColor, transparent,
        \gridColorX, Color.yellow(0.5),
        \gridColorY, Color.yellow(0.5)
    );
    plotView.refresh;

    // Add control buttons
    parent.decorator.nextLine;

    Button(parent, 120@30)
        .states_([["Refresh Plots", Color.white, colorButton]])
        .action_({ updateWavetablePlots.(plotView) });

    Button(parent, 120@30)
        .states_([["Generate New", Color.white, colorButton]])
        .action_({ 
            makeBuffersFunc.value;
            updateWavetablePlots.(plotView)
        });
};


// Fill panel with buttons for start/stop of patterns
var makePatternButtons = {
    arg parent, patterns, evntKeys=nil;

    var buttonWidth = 59;
    var buttonHeight = 50;
    var buttonsPerRow = 8;
    var margin = 5;
    var buttonPanel;
    var counter = 0;
    var buttons = Dictionary.new;
    
    // Create a panel for the pattern buttons
    buttonPanel = View(parent, (parent.bounds.width-(margin*4))@60)
        .background_(colorPane);
    buttonPanel.decorator = FlowLayout(buttonPanel.bounds, margin@margin, gap@gap);

    // Convert keys to Array and sort them
    if (evntKeys.isNil) {
        evntKeys = patterns.keys.asArray.sort;
    };

    // Create buttons for sorted patterns
    evntKeys.do({ |key|
        var button = Button(buttonPanel, buttonWidth@buttonHeight)
        .states_([
            [key.asString, Color.white, Color.gray],
            [key.asString, Color.white, Color.red(0.4)]
        ])
        .action_({ |bt|
            ~playStopEvent.(key, ~tempo);
        });

        buttons[key] = button; // Store button in dictionary

        // Subscribe to pattern state changes
        NotificationCenter.register(
            ~patternStateName, // Watch for pattern state notifications
            key,               // Only for this pattern
            button,            // The object to notify (the button)
            { |state|
                // Update button state in GUI thread
                { button.value = state.asInteger }.defer
            }
        );

        // Increment counter and check if we need a new line
        counter = counter + 1;
        if (counter % buttonsPerRow == 0) {
            buttonPanel.decorator.nextLine;
        };
    });
};


// GUI controls for root note selection and MIDI tracking
var makeRootNoteCtrl = { |parent|
    var popupNote;

    StaticText(parent, 100@30)
        .string_("Root Note:")
        .font_(Font("Arial", 14))
        .stringColor_(Color.white)
        .align_(\right);
    popupNote = PopUpMenu(parent, 200@30)
        .items_(~fullNoteList)
        .value_(~defaultIndex)
        .action_({ |menu| ~setRoot.(menu.value) });
};


// GUI controls for MIDI tracking toggle
var makeMIDITrackerCtrl = { |parent|
    var btTrack;

    StaticText(parent, 100@30)
        .string_("Track MIDI:")
        .font_(Font("Arial", 14))
        .stringColor_(Color.white)
        .align_(\right);
    btTrack = Button(parent, 100@30)
        .states_([
            ["OFF", Color.white, Color.gray],
            ["ON", Color.white, Color.red(0.4)]
        ])
        .value_(~trackRoot.asInteger)
        .action_({ |bt| ~trackRoot = bt.value.asBoolean });
};


var makeRecordButton = { |parent|
    var btRecord;

    btRecord = Button(parent, 100@40)
        .states_([
            ["RECORD", Color.white, Color.gray],
            ["RECORD", Color.white, Color.red(0.4)]
        ])
        .value_(0)
        .action_({ |bt|
            // var path = ~projectPath +/+ format("recording_%.wav", Date.getDate.stamp);

            if (bt.value == 1) {

                // Omitting the first two buses, as ~outDrums is a stereo bus
                // for monitoring (there are individual buses for drum recording).
                var bus = ~outDrums + 2;

                // Assuming contiguous bus allocation, ~outRecTom is the last
                // bus.
                var numChannels = ~outRecTom - 1;

                s.record(bus: bus, numChannels: numChannels);
                postf("Recording started:\n\tbus %\n\tnumChannels %\n", bus, numChannels);
            } {
                s.stopRecording;
            };
        });
};


// Main GUI creation function
~makeGUI = {
    var winWidth = 1100;
    var winHeight = Window.screenBounds.height-55;
    var palette = QPalette.dark;
    var btPlay, popupNote;
    var rootWatcher;
    var ctrlPaneTransp, ctrlPaneTranspTop, ctrlPaneNotes, plotPanel1, plotPanel2;
    var panelHeight = 150;  // height for control panels
    var plotPanelHeight = winHeight-panelHeight-(margin*4);  // remaining height for plot panels
    var guiPatternKeys;

    ~win = Window.new(
        "Cyklop",
        Rect(
            Window.screenBounds.width-(winWidth*2),
            1200,
            winWidth,
            Window.screenBounds.height-55
        ),
        resizable: false
    );
    ~win.view.decorator = FlowLayout(~win.view.bounds);
    ~win.view.decorator.gap=gap@gap;    
    palette.setColor(Color.grey(0.2), \window);
    ~win.view.palette = palette;

    // Create two control panels at the top
    ctrlPaneTransp = View(~win, (winWidth/2-margin)@panelHeight)
        .background_(colorPane);
    ctrlPaneTransp.decorator = FlowLayout(ctrlPaneTransp.bounds, margin@margin, gap@gap);

    ctrlPaneNotes = View(~win, (winWidth/2-margin)@panelHeight)
        .background_(colorPane);
    ctrlPaneNotes.decorator = FlowLayout(ctrlPaneNotes.bounds, margin@margin, gap@gap);

    // Place controls in their respective panels
    ctrlPaneTranspTop = View(ctrlPaneTransp, ctrlPaneTransp.bounds.width@60)
        .background_(colorPane);
    ctrlPaneTranspTop.decorator = FlowLayout(ctrlPaneTranspTop.bounds, margin@margin, gap@gap);
    btPlay = Button(ctrlPaneTranspTop, 59@40)
        .states_([
            ["MIX", Color.white, Color.gray],
            ["MIX", Color.white, Color.red(0.4)]
        ])
        .action_({ |bt|
            var fullMixName = \mix_full;
            
            // Check if buffers are initialized
            if (~wt_buf.isNil or: { ~tf_buf.isNil }) {
                "ERROR: Buffers not initialized. Click 'Generate New' buttons first.".postln;
            } {
                if (~evnts[fullMixName].isNil) {
                    postf("WARNING: No event defined for '%'\n", fullMixName);
                } {
                    ~tempo.schedAbs(~tempo.nextTimeOnGrid(), {
                        if (~evnts[fullMixName].value.isPlaying) {
                            ~evnts[fullMixName].value.stop;
                        } {
                            ~evnts[fullMixName].value.play;
                        };
                        nil;
                    });
                };
            };
        });

    // Recording button setup
    makeRecordButton.(ctrlPaneTranspTop);

    // Create pattern control buttons
    ctrlPaneTransp.decorator.nextLine;

    // Not all keys should have buttons, e.g., the full mix button
    guiPatternKeys = [
        \beat_x1, \beat_x2, \pad, \pad_s, \bass, \bass_s, \pulse, \melody
    ].asArray;
    makePatternButtons.(ctrlPaneTransp, ~evnts, guiPatternKeys);

    // Root note selection setup
    popupNote = makeRootNoteCtrl.(ctrlPaneNotes);

    // Root watcher setup
    rootWatcher = Routine({
        loop {
            var index = ~midiValues.indexOf(~rootMIDI);
            {
                if (index.notNil and: { popupNote.value != index }) {
                    popupNote.value_(index);
                }
            }.defer;
            0.5.yield;
        }
    }).play;

    // MIDI tracking toggle setup
    makeMIDITrackerCtrl.(ctrlPaneNotes);

    ~win.view.decorator.nextLine;

    // Create two adjacent panels for plots
    plotPanel1 = View(~win, (winWidth/2-margin)@plotPanelHeight)
        .background_(colorPane);
    plotPanel1.decorator = FlowLayout(plotPanel1.bounds, margin@margin, gap@gap);
    
    plotPanel2 = View(~win, (winWidth/2-margin)@plotPanelHeight)
        .background_(colorPane);
    plotPanel2.decorator = FlowLayout(plotPanel2.bounds, margin@margin, gap@gap);

    // Create wavetable GUIs in their respective panels
    createWavetableGUI.(
        ~wt_sig,
        ~makeWavetableBufs,
        plotPanel1,
        "Wavetables (Osc & VOsc)",
        signalType: \wavetable,
        height: plotPanelHeight-(margin*2),
        width: (winWidth/2)-(margin*3)
    );
    
    createWavetableGUI.(
        ~tf_sig,
        ~makeShaperBufs,
        plotPanel2,
        "Transfer Functions (Shaper)",
        signalType: \transfer,
        height: plotPanelHeight-(margin*2),
        width: (winWidth/2)-(margin*3)
    );

    ~win.front;
};
)