# The documentation's pictures: the window (its panes and all 13 plots) on
# the quick-start guide's example and setup, as the tutorial makes it. The
# tau peptide of BitQT's examples (6001 frames; MDANCE's Python package
# ships the same files), the backbone of residues 3 to 12, every frame
# fitted on it onto frame 999 with VMD's coordinates moved, KMeans NANI
# seeded by CompSim at k 6; the two halves of the trajectory as groups, the
# map and the profiles; the elbow scan with its stability; HELM's merges'
# heights; the guide's sweep; the tools; the dialogs and the File menu; the
# 3D view; figures; and the places of the window's parts, for
# docs/tools/annotate.py.
#   cd <VMDance>
#   TAU_DATA=<BitQT>/examples DISPLAY=:9 vmd -dispdev win -e docs/tools/capture.tcl < <(sleep 900)
# (MDANCE_DATA, the package's mdance/data folder, names the files too.)
# (standard input must stay open: VMD draws no new geometry once it has
# read its end, and the renders would show a stale scene). On Windows the
# pictures are taken by docs/tools/capture_win.ps1 (PowerShell), the window
# at the screen's top left; the figures need Ghostscript (gswin64c).
set ::root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
source [file join $::root tests common.tcl]
set ::figs [file join $::root docs _static figures]
file mkdir $::figs
set ::logf [open [file join $::out capture.log] w]
fconfigure $::logf -buffering line
proc log {m} { puts $::logf $m }
proc bgerror {msg} { log "BGERROR $msg\n$::errorInfo" }
proc tk_messageBox {args} { log "message: [dict get $args -message]"; return ok }
# A window's picture: ImageMagick's import on X11; on Windows
# capture_win.ps1, which copies the window's area from the screen: the
# window raised and kept on top while it does.
proc grab {win file} {
    if {$::tcl_platform(platform) ne "windows"} {
        exec import -window [wm frame $win] $file
        return
    }
    wm attributes $win -topmost 1
    raise $win
    settle 300
    set ps [file nativename [file join $::root docs tools capture_win.ps1]]
    try {
        exec powershell -NoProfile -ExecutionPolicy Bypass -File $ps [wm frame $win] [file nativename $file] 2>@1
    } finally {
        wm attributes $win -topmost 0
    }
}
# (the window drawn whole first: its events run for a moment, by update
# and short sleeps, as the original shot did: no vwait, which a handler
# that waits in the event loop would hold)
proc settle {{ms 400}} {
    set end [expr {[clock milliseconds] + $ms}]
    update
    while {[clock milliseconds] < $end} { after 50; update }
}
proc shot {name {win .vmdance}} {
    settle
    grab $win [file join $::figs $name.png]
    log "wrote $name.png"
}
proc wait_idle {} {
    while {$::VMDance::GUI::S(busy)} { vwait ::VMDance::GUI::S(busy) }
    update
}
# A widget's place in the window's picture: {x y width height}.
proc place_of {wd} {
    list [expr {[winfo rootx $wd] - [winfo rootx .vmdance]}] [expr {[winfo rooty $wd] - [winfo rooty .vmdance]}] \
        [winfo width $wd] [winfo height $wd]
}

if {[catch {
package require vmdance
::VMDance::_load_tk
set ::VMDance::Prefs::file ""
if {[real_cli] ne ""} { use_cli }
set data [file join $::root .. MDANCE src mdance data]
foreach v {MDANCE_DATA TAU_DATA} { if {[info exists ::env($v)] && $::env($v) ne ""} { set data $::env($v) } }
set m [mol new [file join $data aligned_tau.pdb] waitfor all]
mol addfile [file join $data aligned_original_tau_6K.dcd] waitfor all molid $m
animate delete beg 0 end 0 $m
mol modstyle 0 $m Licorice 0.2 12 12
display resetview
set G ::VMDance::GUI
set S ${G}::S
set w [vmdance]
${G}::set_appearance 12 medium flat
# (whole on the screen: a part off it is not drawn, and Windows' picture of
# it is black)
wm geometry .vmdance +0+0
settle 1500
set ${S}(molid) $m
${G}::refresh_molecules
# (the guide's atoms, fit and k: quickstart-guide/quickstart.tcl)
set sel "resid 3 to 12 and name N CA C O H"
set ${S}(sel) $sel
set ${S}(fit) 1
set ${S}(fitsel) $sel
set ${S}(fitframe) 999
set ${S}(fitmove) 1
${G}::_fit_changed
set ${S}(algorithm) kmeans
${G}::_algorithm_changed
set ${S}(k_kmeans) 6
set ${S}(p_kmeans_kinit) CompSim
${G}::_params_sync
${G}::_count
${G}::show_pane setup
shot setup
${G}::cluster
wait_idle
set runk [dict get [vmdance info] run]
# the groups (the two halves: does each visit the same clusters?), the map
# and the profiles, from the Results page
set ${S}(gp_ranges) "first 0-2999 second 3000-6000"
${G}::groups_set
${G}::map
wait_idle
${G}::profiles
wait_idle
vmdance select 2
${G}::show_pane results
${G}::show_tab populations
shot window
# the window's parts, for the annotated picture
set fh [open [file join $::out window_parts.txt] w]
foreach {name wd} [list toolbar $w.tb panes $w.pw.left.nb plots $w.pw.right.nb plot $w.pw.right.nb.populations.c \
        options $w.pw.right.nb.populations.opts readout $w.pw.right.rf status $w.sb] {
    puts $fh [list $name {*}[place_of $wd]]
}
close $fh
log "wrote window_parts.txt"
# (every cluster in full colour: a selection pales the others)
vmdance select clear
foreach key [dict keys [set ${G}::tabs]] {
    if {$key in {elbow sweep}} continue
    ${G}::show_tab $key
    shot plot_$key
}
# the Results page scrolled to its groups, map and profiles
${G}::show_tab makeup
catch {[set ${G}::page(results)] yview moveto 1.0}
catch {[winfo parent [set ${G}::page(results)]] yview moveto 1.0}
shot results_groups
# the elbow scan, with the stability of NANI's four seedings
set ${S}(eb_from) 2
set ${S}(eb_to) 12
set ${S}(eb_stab) 1
${G}::show_pane scans
${G}::elbow
wait_idle
${G}::show_tab elbow
update
set c $w.pw.right.nb.elbow.c
lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
# (drawn by Tk before the picture: idle tasks only, so that no redraw
# wipes the panel)
${G}::_hover elbow $c [::VMDance::Plot::X $c 6] [expr {($y0 + $y1) / 2}]
update idletasks
grab .vmdance [file join $::figs plot_elbow.png]
log "wrote plot_elbow.png ([llength [$c find withtag partition]] items of the panel)"
set ${S}(eb_stab) 0
# HELM from 60 starting clusters, and its merges' heights
set ${S}(algorithm) helm
${G}::_algorithm_changed
set ${S}(k_helm) 6
set ${S}(p_helm_initial) 60
${G}::_params_sync
${G}::cluster
wait_idle
set ${S}(td_view) heights
${G}::show_tab tree
${G}::redraw
shot plot_tree_heights
set ${S}(td_view) tree
set ${S}(algorithm) kmeans
${G}::_algorithm_changed
# the sweep (the guide's: three algorithms, two seedings, k 2 to 8)
foreach a {kmeans divine helm} { set ${S}(gr_alg_$a) 1 }
foreach k $::VMDance::Algo::kinits { set ${S}(gr_seed_$k) [expr {$k in {StratAll CompSim}}] }
set ${S}(gr_from) 2
set ${S}(gr_to) 8
${G}::_grid_count
${G}::sweep
wait_idle
${G}::show_tab sweep
${G}::show_pane scans
shot plot_sweep
# the run of k 6 again, and its questions
vmdance run $runk
${G}::prime
wait_idle
${G}::similarity
wait_idle
${G}::show_pane tools
shot tools
${G}::show_pane results
vmdance select 2
${G}::show_tab timeline
shot results
set ${S}(show_opts) 1
${G}::panels_changed
${G}::show_tab transitions
shot options
set ${S}(show_opts) 0
${G}::panels_changed
# the dialogs (with folders and paths of an example: the pictures name
# none of the machine's; closed without applying them)
set ${S}(fig_dir) ~/project/figures
${G}::figure_dialog
update
shot dialog_figures $w.figures
destroy $w.figures
set ${S}(out_dir) ~/project/results
${G}::export_dialog
update
shot dialog_export $w.export
destroy $w.export
# the File menu, open on Quick export (Windows): opened here as a popup
# under the menubar (tk_popup waits until it closes); capture_menu.ps1, in
# the background meanwhile, walks it to Quick export by messages to VMD's
# own menu windows, takes its picture, and closes it
if {$::tcl_platform(platform) eq "windows"} {
    set mf [file join $::figs menu_file.png]
    file delete $mf
    wm attributes .vmdance -topmost 1
    raise .vmdance
    settle 500
    exec powershell -NoProfile -ExecutionPolicy Bypass -File [file nativename [file join $::root docs tools capture_menu.ps1]] \
        [pid] [wm frame .vmdance] [file nativename $mf] 7 &
    tk_popup $w.menu.file [winfo rootx .vmdance] [winfo rooty .vmdance]
    set end [expr {[clock seconds] + 15}]
    while {![file exists $mf] && [clock seconds] < $end} { settle 200 }
    settle 1000
    wm attributes .vmdance -topmost 0
    log "menu_file.png: [file exists $mf]"
}
${G}::settings_dialog
update
set ::VMDance::GUI::E(cli) /opt/CPP-MDANCE/build/cli/mdance-cli
foreach c [${G}::_descendants $w.settings] {
    if {[winfo class $c] eq "TLabel" && [string match "In use:*" [$c cget -text]]} {
        $c configure -text "In use: the program /opt/CPP-MDANCE/build/cli/mdance-cli\nAlgorithms: KMeans NANI, DIVINE, HELM, eQual"
    }
    # (Ghostscript's place on this machine: an example's too)
    if {[winfo class $c] eq "TLabel" && [string match "Ghostscript:*" [$c cget -text]]} {
        $c configure -text "Ghostscript: /usr/bin/gs (figures in PDF and PNG)"
    }
}
shot dialog_settings $w.settings
destroy $w.settings
# 3D: every representative, in its colour
set ${S}(v3d_reps) 1
set ${S}(v3d_style) Licorice
set ${S}(v3d_sel) backbone
${G}::draw_changed
${G}::show_pane v3d
shot pane_3d
mol off $m
mol on $m
foreach i [lsort -integer -decreasing [lmap i [lsearch -all [lrepeat [molinfo $m get numreps] x] x] {set i}]] {
    if {[mol repname $m $i] ni [lmap e $::VMDance::Viz::owned {lindex $e 1}]} { mol showrep $m $i 0 }
}
display projection orthographic
display depthcue off
axes location off
color Display Background white
display resize 900 700
display update
set r [expr {"TachyonInternal" in [render list] ? "TachyonInternal" : "snapshot"}]
if {[catch {::VMDance::Figures::render_3d [file join $::figs 3d.png] $r} err]} { log "3D: $err" } else { log "wrote 3d.png ($r)" }
# figures of the plots, as the figures dialog makes them
set ${S}(v3d_reps) 0
${G}::draw_changed
# (Ghostscript makes PNG of them: without it, said, and the pictures above kept)
if {[catch {vmdance figures $::figs -plots {populations makeup timeline transitions tree silhouette map profiles elbow} \
        -formats png -width 700 -height 420 -dpi 110 -prefix figure} files]} {
    log "figures: $files"
} else {
    foreach f $files { log "wrote [file tail $f]" }
}
} err]} { log "ERROR $err\n$::errorInfo" }
close $::logf
quit
