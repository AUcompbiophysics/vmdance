# The quick-start guide's figures. Runs the guide's own script
# (quickstart.tcl) in VMD with its window, then writes, in figures/:
#   gallery_<plot>.pdf   the 13 plots of the clustering, for the guide's
#                        gallery: ten half a page wide (120 x 90 mm, 10-point
#                        text, printed at two thirds), the Timeline, the
#                        Sweep and the Elbow the page's width (178 mm,
#                        9-point text)
#   main_3d.png          the representatives in VMD's 3D window
#   window.png           the VMDance window (macOS: screencapture; Windows:
#                        ../docs/tools/capture_win.ps1), and
#   window_parts.txt     where its parts are, for annotate.py
# and on Windows the window's other views, for the guide's walk through it:
#   view_setup.png       Setup filled as the guide fills it, and the
#                        Populations of the clustering it makes
#   view_scans.png       Scans, and the Elbow
#   view_tools.png       Tools, and the Map
#   view_3d.png          3D, and the Timeline
#   dialog_export.png    File > Export results (the tables, CSV)
#   dialog_figures.png   File > Create figures (the plots)
#   menu_file.png        the File menu open on Quick export
#                        (../docs/tools/capture_menu.ps1)
#   cd quickstart-guide
#   TAU_DATA=<BitQT>/examples vmd -dispdev win -e figures.tcl < <(sleep 900)
# (make figures does it. VMD's standard input stays open: VMD draws no new
# geometry once it has read its end.) It logs to build/figures.log: windowed
# VMD does not reliably show its standard output.
set here [pwd]
set root [file dirname $here]
set figs [file join $here figures]
set auto_path [linsert $auto_path 0 [file join $root vmdance]]
file mkdir [file join $here build]
set ::logf [open [file join $here build figures.log] w]
fconfigure $::logf -buffering line
proc log {m} { puts $::logf $m }
proc bgerror {msg} { log "BGERROR $msg\n$::errorInfo" }
proc env_or {name default} {
    expr {[info exists ::env($name)] && $::env($name) ne "" ? $::env($name) : $default}
}
# The window drawn whole: its events run for a moment (no vwait)
proc settle {{ms 400}} {
    set end [expr {[clock milliseconds] + $ms}]
    update
    while {[clock milliseconds] < $end} { after 50; update }
}
# A widget's place in the window: {x y width height}, Tk's points
proc place_of {wd} {
    list [expr {[winfo rootx $wd] - [winfo rootx .vmdance]}] [expr {[winfo rooty $wd] - [winfo rooty .vmdance]}] \
        [winfo width $wd] [winfo height $wd]
}
# A window's picture on Windows: its client area copied from the screen
# (the online documentation's capture_win.ps1), raised and on top meanwhile
proc grab_win {win file} {
    wm attributes $win -topmost 1
    raise $win
    settle 600
    set ps [file nativename [file join $::root docs tools capture_win.ps1]]
    try {
        exec powershell -NoProfile -ExecutionPolicy Bypass -File $ps [wm frame $win] [file nativename $file] 2>@1
    } finally {
        wm attributes $win -topmost 0
    }
}
# A job of the window's, run to its end
proc wait_idle {} {
    while {$::VMDance::GUI::S(busy)} { vwait ::VMDance::GUI::S(busy) }
    settle 300
}

if {[catch {
    package require vmdance
    ::VMDance::_load_tk
    set ::VMDance::Prefs::file ""
    set cli [file normalize [env_or MDANCE_CLI [file join $root .. CPP-MDANCE build cli mdance-cli]]]
    if {![file executable $cli]} { error "no mdance-cli at $cli: set MDANCE_CLI" }
    vmdance backend -mode cli -cli $cli
    set data [env_or TAU_DATA ""]
    foreach f {aligned_tau.pdb aligned_original_tau_6K.dcd} {
        if {![file isfile [file join $data $f]]} {
            error "no $f in \"$data\": set TAU_DATA to BitQT's examples folder"
        }
    }
    set work [file join $here build figrun]
    file delete -force $work
    file mkdir $work
    foreach f {aligned_tau.pdb aligned_original_tau_6K.dcd} { file copy [file join $data $f] $work }
    cd $work

    # the guide's script, as printed: its quit kept for the end
    rename ::quit ::_qs_quit
    proc ::quit {args} {}
    uplevel #0 [list source [file join $here quickstart.tcl]]
    rename ::quit {}
    rename ::_qs_quit ::quit
    log "the script ran: [vmdance runs]"

    file mkdir $figs
    # the gallery: every plot of run 1 (the KMeans NANI clustering), in full
    # colour (no cluster selected)
    vmdance run 1
    vmdance select clear
    foreach key [dict keys $::VMDance::GUI::tabs] {
        # (the page's width: the Timeline, whose note is cut at half of it;
        # the Sweep, whose values fit its cells only there; the Elbow, its two
        # axes, its legend and its stability strip)
        # (the halves are the Make-up's: the Map and the Profiles show the
        # clusters, as they do without groups)
        switch -- $key {
            timeline        { set size {-width 178mm -height 65mm -text 9} }
            sweep           { set size {-width 178mm -height 75mm -text 9} }
            elbow           { set size {-size two-columns} }
            map             { set size {-width 120mm -height 90mm -text 10 -options {mp_colour cluster}} }
            profiles        { set size {-width 120mm -height 90mm -text 10 -options {pf_show clusters}} }
            default         { set size {-width 120mm -height 90mm -text 10} }
        }
        vmdance figures $figs -plots $key -formats pdf -prefix gallery {*}$size
        log "gallery: $key"
    }

    # the representatives, each in its cluster's colour, alone in the 3D view
    for {set i 0} {$i < [molinfo $m get numreps]} {incr i} { mol showrep $m $i 0 }
    vmdance draw -reps 1 -style Licorice -sel backbone
    display projection orthographic
    display depthcue off
    axes location off
    display resize 900 700
    display resetview
    settle 800
    vmdance figures $figs -plots {} -3d 1 -prefix main
    log "main: 3d [glob -nocomplain -directory $figs main_3d*]"

    # the window, on macOS: Results, and the Make-up of the two halves
    set lister [file join $here build macos_windows]
    if {$::tcl_platform(os) eq "Darwin" && [file executable $lister]} {
        set w [vmdance]
        wm geometry .vmdance 1350x950+40+40
        ::VMDance::GUI::show_pane results
        ::VMDance::GUI::show_tab makeup
        raise .vmdance
        settle 2500
        set id ""
        foreach line [split [exec $lister [pid]] \n] {
            lassign $line wid x y ww wh layer on
            if {$on && abs($ww - [winfo width .vmdance]) < 4} { set id $wid }
        }
        if {$id eq ""} { error "the VMDance window was not found among VMD's" }
        exec screencapture -x -o -l$id [file join $figs window.png]
        set tab [$w.pw.right.nb select]
        set fh [open [file join $figs window_parts.txt] w]
        puts $fh [list window 0 0 [winfo width .vmdance] [winfo height .vmdance]]
        foreach {name wd} [list toolbar $w.tb panes $w.pw.left.nb plots $w.pw.right.nb plot $tab.c \
                options $tab.opts readout $w.pw.right.rf status $w.sb] {
            if {[winfo exists $wd]} { puts $fh [list $name {*}[place_of $wd]] } else { log "no $wd" }
        }
        close $fh
        log "window: $id"
    } elseif {$::tcl_platform(platform) eq "windows"} {
        set G ::VMDance::GUI
        upvar #0 ${G}::S S
        set w [vmdance]
        # (whole on the screen, at its top left: a part off it is black)
        wm geometry .vmdance 1350x950+0+0
        settle 1500
        # the window: Results, and the Make-up of the two halves
        ${G}::show_pane results
        ${G}::show_tab makeup
        grab_win .vmdance [file join $figs window.png]
        set tab [$w.pw.right.nb select]
        set fh [open [file join $figs window_parts.txt] w]
        puts $fh [list window 0 0 [winfo width .vmdance] [winfo height .vmdance]]
        foreach {name wd} [list toolbar $w.tb panes $w.pw.left.nb plots $w.pw.right.nb plot $tab.c \
                options $tab.opts readout $w.pw.right.rf status $w.sb] {
            if {[winfo exists $wd]} { puts $fh [list $name {*}[place_of $wd]] } else { log "no $wd" }
        }
        close $fh
        log "window: windows"
        # Setup as the guide fills it (Section 4, steps 3 and 4), and the
        # Populations of the clustering it makes
        set S(molid) $m
        ${G}::refresh_molecules
        set S(sel) $sel
        set S(fit) 1
        set S(fitsel) $sel
        set S(fitframe) $fitframe
        set S(fitmove) 1
        ${G}::_fit_changed
        set S(algorithm) kmeans
        ${G}::_algorithm_changed
        set S(k_kmeans) $k
        set S(p_kmeans_kinit) CompSim
        ${G}::_params_sync
        ${G}::_count
        vmdance run 1
        vmdance select clear
        ${G}::show_pane setup
        ${G}::show_tab populations
        settle 800
        grab_win .vmdance [file join $figs view_setup.png]
        log "view: setup"
        # Scans, as the guide's scan was asked, and the Elbow
        set S(eb_from) 2
        set S(eb_to) 12
        set S(eb_stab) 1
        ${G}::show_pane scans
        ${G}::show_tab elbow
        grab_win .vmdance [file join $figs view_scans.png]
        log "view: scans"
        # Tools, and the Map
        ${G}::show_pane tools
        ${G}::show_tab map
        grab_win .vmdance [file join $figs view_tools.png]
        log "view: tools"
        # 3D, every representative drawn, and the Timeline
        set S(v3d_reps) 1
        ${G}::draw_changed
        ${G}::show_pane v3d
        ${G}::show_tab timeline
        grab_win .vmdance [file join $figs view_3d.png]
        set S(v3d_reps) 0
        ${G}::draw_changed
        log "view: 3d"
        # the dialogs that write the tables and the plots (a folder of an
        # example's: the pictures name none of this machine's; closed unapplied)
        ${G}::show_pane results
        ${G}::show_tab populations
        set S(out_dir) ~/tau/results
        ${G}::export_dialog
        update
        grab_win $w.export [file join $figs dialog_export.png]
        destroy $w.export
        set S(fig_dir) ~/tau/figures
        ${G}::figure_dialog
        update
        grab_win $w.figures [file join $figs dialog_figures.png]
        destroy $w.figures
        log "dialogs"
        # the File menu, open on Quick export: opened here as a popup under
        # the menubar (tk_popup waits until it closes); capture_menu.ps1, in
        # the background meanwhile, walks it to Quick export by messages to
        # VMD's own menu windows, takes its picture, and closes it
        set out [file join $figs menu_file.png]
        file delete $out
        wm attributes .vmdance -topmost 1
        raise .vmdance
        settle 500
        set ps [file nativename [file join $::root docs tools capture_menu.ps1]]
        exec powershell -NoProfile -ExecutionPolicy Bypass -File $ps [pid] [wm frame .vmdance] [file nativename $out] 7 &
        tk_popup $w.menu.file [winfo rootx .vmdance] [winfo rooty .vmdance]
        set end [expr {[clock seconds] + 15}]
        while {![file exists $out] && [clock seconds] < $end} { settle 200 }
        settle 1000
        wm attributes .vmdance -topmost 0
        log "menu: [file exists $out]"
    } else {
        log "window: not taken (macOS and Windows only; figures/window.png kept)"
    }
    log "done"
} err]} {
    log "ERROR $err\n$::errorInfo"
}
cd $here
catch {::VMDance::Backend::cleanup}
close $::logf
quit
