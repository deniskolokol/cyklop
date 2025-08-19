(
var margin=10, gap=5;
var colorButton=Color.grey(0.3);
var colorPane=Color.grey(0.1);
var colorBg=Color.grey(0.15);
var transparent=Color.grey(alpha:0.0);

// Wavetable GUI Visualizer
var createWavetableGUI = {
    arg window,
        height=200,
        width=800;

    var mainView, wavetablePanel, scrollView, plotView;

    // Function to update all plots
    var updateWavetablePlots = { |plotView|
        "> Updating wavetable plots...".postln;
        if (~wt_sig.notNil) {
            plotView.value = ~wt_sig;
            plotView.refresh;
        } {
            "No wavetable signals found. Run ~makeBuffers first.".warn;
        }
    };

    // Create scroll view for the wavetable panel
    scrollView = ScrollView(window, width@height);
    scrollView.decorator = FlowLayout(scrollView.bounds, margin@margin, margin@margin);
    scrollView.background_(colorPane);

    // Create plots for existing wavetables or placeholders
    if (~wt_sig.isNil) { ~makeBuffers.() };

    // Create the plot view
    plotView = Plotter(
        name: "WT",
        bounds: Rect(0, 0, width-(margin * 2), height-(margin * 2)),
        parent: scrollView
    );
    plotView.value = ~wt_sig;
    plotView.editMode = true;
    plotView.setProperties(
        \fontColor, Color(0.5, 1, 0);,
        \plotColor, Color.red,
        \backgroundColor, transparent,
        \gridColorX, Color.yellow(0.5),
        \gridColorY, Color.yellow(0.5)
    );
    plotView.refresh;

    // Add control buttons
    window.view.decorator.nextLine;

    Button(window, 120@30)
        .states_([["Refresh Plots", Color.white, colorButton]])
        .action_({ updateWavetablePlots.(plotView) });

    Button(window, 120@30)
        .states_([["Generate New", Color.white, colorButton]])
        .action_({ 
            ~makeBuffers.();
            updateWavetablePlots.(plotView)
        });

    Button(window, 120@30)
        .states_([["Export Image", Color.white, colorButton]])
        .action_({ 
            "Export functionality would go here".postln;
            // Could implement screenshot or data export here
        });
    
    "> Wavetable GUI created. Use ~updateWavetablePlots to refresh after generating new wavetables.\n".postf;
};


~makeGUI = {
	var winWidth=550, winHeight=1250, palette=QPalette.dark;
    var btPlay, popupNote;
    var rootWatcher;

    ~win = Window.new(
		"Cyklop",
		Rect(
			Window.screenBounds.width-(winWidth*2), // optimized for personal VS code setup
			1250,
			winWidth,
			Window.screenBounds.height-55 // optimized for personal window manager setup
		),
		resizable: false
	);
    ~win.view.decorator = FlowLayout(~win.view.bounds);
    ~win.view.decorator.gap=1@1;    
    palette.setColor(Color.grey(0.2), \window);
    ~win.view.palette = palette;

    btPlay = Button(~win, 100@30)
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
    popupNote = PopUpMenu(~win, 200@30)
        .items_(~fullNoteList)
        .value_(~defaultIndex)
        .action_({ |menu| ~setRoot.(menu.value) });

    // Check ~root changes twice per second and update dropdown
    rootWatcher = Routine({
        loop {
            var index = ~midiValues.indexOf(~rootMIDI);
            {
                if (index.notNil and: { popupNote.value != index }) {
                    popupNote.value_(index);
                }
            }.defer;
            0.5.yield; // Wait 0.5 seconds (twice per second)
        }
    }).play;

    createWavetableGUI.(
        ~win,
        height: ~win.bounds.height-200-(margin*2),
        width: ~win.bounds.width-(margin*2)
    );

    ~win.front;
};
)