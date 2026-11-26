# The documentation's numbers (docs/tutorial.rst, and the lines of the other
# pages that quote the example): the tutorial's steps run with the command
# on the quick-start guide's example and setup. The tau peptide of BitQT's
# examples (aligned_tau.pdb and aligned_original_tau_6K.dcd; MDANCE's Python
# package ships the same two files), its backbone of residues 3 to 12,
# every frame fitted on those atoms onto frame 999 with VMD's coordinates
# moved, KMeans NANI seeded by CompSim, k 6 (quickstart-guide/quickstart.tcl).
# Writes docs/_static/data/tutorial_numbers.txt (key, value, what it is).
#   cd <VMDance>
#   TAU_DATA=<BitQT>/examples vmd -dispdev text -e docs/tools/tutorial_numbers.tcl < /dev/null
# (MDANCE_DATA, the package's mdance/data folder, names the files too.)
set root [pwd]
lappend auto_path [file join $root vmdance]
package require vmdance
set ::VMDance::Prefs::file ""
proc env_or {names default} {
    foreach n $names { if {[info exists ::env($n)] && $::env($n) ne ""} { return $::env($n) } }
    return $default
}
set data [env_or {TAU_DATA MDANCE_DATA} [file join $root .. MDANCE src mdance data]]
set out [file join $root docs _static data]
file mkdir $out
set rows {}
# the guide's atoms, fit and k
set sel "resid 3 to 12 and name N CA C O H"
set fitframe 999
set fit [list -fit $sel -fitframe $fitframe -fitmove 1]
set K 6
proc keep {key value what} { lappend ::rows [list $key $value $what]; puts [format "%-24s %-14s %s" $key $value $what] }
proc al3 {al} { return "[dict get $al as_is] [dict get $al fitted] [dict get $al superposed]" }

if {[catch {
    set m [mol new [file join $data aligned_tau.pdb] waitfor all]
    mol addfile [file join $data aligned_original_tau_6K.dcd] waitfor all molid $m
    animate delete beg 0 end 0 $m
    keep frames [molinfo $m get numframes] "the frames clustered (the DCD's)"
    set n [[atomselect $m $sel] num]
    keep atoms $n "the atoms of \"$sel\""
    keep fitframe $fitframe "the frame every frame is fitted onto"
    # whether the frames look superposed (the note under Setup's Fit box), as
    # they are loaded: of the clustered atoms, and of other selections (the
    # FAQ's flexible molecule)
    keep alignment_loaded [al3 [vmdance alignment -mol $m -sel $sel]] "as loaded, the frames from the first: \u00c5 as they are, \u00c5 fitted, superposed (1) or not"
    foreach {name text} {ca "name CA" noh noh all all} {
        keep alignment_loaded_$name [al3 [vmdance alignment -mol $m -sel $text]] "as loaded, of \"$text\": the same"
    }
    # the elbow scan, with the stability of NANI's four seedings: the fit
    # moves VMD's coordinates before it reads them
    set t0 [clock milliseconds]
    set rec [vmdance elbow -mol $m -sel $sel {*}$fit -kinit CompSim -from 2 -to 12 -stability 1 -quiet 1]
    keep elbow_seconds [format %.0f [expr {([clock milliseconds] - $t0) / 1000.0}]] "the elbow scan with the stability, k 2-12"
    keep alignment [al3 [vmdance alignment -mol $m -sel $sel]] "once moved, the frames from the first: \u00c5 as they are, \u00c5 fitted, superposed (1) or not"
    foreach r $rec {
        set k [dict get $r k]
        keep elbow_k$k "[format %.0f [dict get $r ch]] [format %.3f [dict get $r db]] [dict get $r stability]" "k $k: Calinski-Harabasz, Davies-Bouldin, stability"
        keep explained_k$k [format %.0f [expr {100 * [::VMDance::Results::explained $r]}]] "k $k: % of the variance the clusters explain"
    }
    # what the scan points to
    set sg [vmdance elbow suggest]
    foreach key {db_lowest db_dip ch_highest stable most_stable} { keep suggest_$key [dict get $sg $key] "elbow suggest: $key" }
    keep suggest_words [dict get $sg words] "elbow suggest: in words (the Scans box)"
    # the clustering at k 6, the guide's
    set info [vmdance elbow load $K]
    set sz [::VMDance::Results::sizes]
    keep k6_sizes [join $sz " "] "k $K: the clusters' frames"
    keep k6_percent [join [lmap s $sz {format %.0f [expr {100.0 * $s / [molinfo $m get numframes]}]}] " "] "k $K: their shares (%)"
    keep k6_scores "[format %.1f [dict get $info ch]] [format %.2f [dict get $info db]]" "k $K: Calinski-Harabasz, Davies-Bouldin (the command's answer)"
    keep k6_label [lindex [lindex [vmdance runs] 0] 1] "k $K: the run's name"
    set reps {}
    for {set c 0} {$c < $K} {incr c} { lappend reps [dict get [vmdance get $c] representative] }
    keep k6_representatives [join $reps " "] "k $K: the clusters' representative frames"
    keep k6_silhouette [format %.2f [dict get [vmdance silhouette] mean]] "k $K: the mean silhouette (from the clusters' mean structures)"
    set sp [vmdance silhouette -kind pairs]
    set neg 0
    foreach v [dict values [dict get $sp frames]] { if {$v < 0} { incr neg } }
    keep k6_silhouette_pairs "[format %.2f [dict get $sp mean]] $neg" "k $K: the mean silhouette from every frame, and the frames below 0"
    foreach r [vmdance residence] {
        keep residence_c[lindex $r 0] [format %.2f [lindex $r 2]] "cluster [lindex $r 0]: its mean stay (frames)"
        keep longest_c[lindex $r 0] [lindex $r 4] "cluster [lindex $r 0]: its longest stay (frames)"
    }
    keep all_seen_by [::tcl::mathfunc::max {*}[dict values [dict get [vmdance timeline] first_seen]]] "the frame by which every cluster has been seen"
    # the two halves of the trajectory as groups
    vmdance groups -ranges {first 0-2999 second 3000-6000}
    set mk [vmdance makeup]
    dict for {c row} $mk {
        lassign $row a b
        keep halves_c$c "$a $b" "cluster $c: frames of the first and the second half"
    }
    set gc [vmdance groups compare]
    set cmp [lindex [dict get $gc pairs] 0]
    keep halves_divergence "[format %.3f [lindex $cmp 2]] [lindex $cmp 4] [format %.3f [lindex $cmp 3]]" "the halves: their divergence, the cluster whose share differs most, by how much"
    keep halves_pair $cmp "the halves: the pair as vmdance groups compare gives it"
    keep halves_words [dict get $gc words] "the halves: the line under the Groups box"
    set mp [vmdance map]
    lassign [dict get $mp variance] v1 v2
    keep map_variance "[format %.0f [expr {100 * $v1}]] [format %.0f [expr {100 * $v2}]]" "the map's two axes: % of the variance"
    set pf [vmdance profiles]
    keep profiles_reference [dict get $pf reference] "the profiles' reference: the most populated cluster"
    # HELM, and its merges' heights
    vmdance -mol $m -sel $sel -algorithm helm -k $K -initial 60 -quiet 1
    keep helm_sizes [join [::VMDance::Results::sizes] " "] "HELM, k $K from 60: the clusters' frames"
    set hs [dict get [vmdance tree] heights]
    keep helm_merges [llength $hs] "HELM's merges, from its starting clusters to $K"
    # (the largest step from one merge to the next, as the Tree plot reads
    # (its variables apart from ::rows, the numbers kept)
    # it: k is the clusters before the merge, the merge before at least 5%
    # of the highest; the plot marks it only when it stands out)
    lassign [::VMDance::Results::tree] t_how t_rows leaves t_base
    set nl [llength $leaves]
    set pts {}; set j 0
    foreach h $hs { if {$h ne ""} { lappend pts [list [expr {$nl - $j}] $h] }; incr j }
    set floor [expr {0.05 * [::tcl::mathfunc::max {*}[lmap p $pts {lindex $p 1}]]}]
    set best {0 0}
    foreach p $pts {
        lassign $p k h
        set i [lsearch -exact -index 0 $pts [expr {$k + 1}]]
        if {$i < 0} continue
        set q [expr {$h / max([lindex $pts $i 1], $floor)}]
        if {$q > [lindex $best 1]} { set best [list $k $q] }
    }
    keep helm_largest_step "[format %.1f [lindex $best 1]] [lindex $best 0]" "HELM: the largest step (times the merge before) and the clusters before it"
    set last [lrange $hs end-7 end]
    keep helm_last_heights [join [lmap h $last {format %.3g $h}] " "] "the last eight merges' heights (from [expr {$K + 8}] clusters down to $K)"
    # eQual's radius: a range from the frames, and the clusters at five radii
    set rd [vmdance radii -mol $m -sel $sel]
    keep radii_suggested "[dict get $rd from] [dict get $rd to] [dict get $rd by] [dict get $rd sample]" "vmdance radii: from, to, by, and the frames sampled"
    keep radii_answer $rd "vmdance radii: its whole answer"
    set radii {4 6 8 10 12}
    set rr [vmdance elbow -mol $m -sel $sel -algorithm equal -radii $radii -quiet 1]
    keep equal_radii [join [lmap r $rr {dict get $r nclusters}] " "] "eQual's clusters at radius [join $radii {, }]"
} err]} { puts "ERROR $err\n$::errorInfo" }
set fh [open [file join $out tutorial_numbers.txt] w]
fconfigure $fh -encoding utf-8 -translation lf
puts $fh "# The numbers of docs/tutorial.rst, made by docs/tools/tutorial_numbers.tcl."
foreach r $rows { puts $fh [join $r "\t"] }
close $fh
::VMDance::Backend::cleanup
quit
