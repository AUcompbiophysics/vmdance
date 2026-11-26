# VMDance: a fit onto any frame (-fitframe), and a fit that moves VMD's
# coordinates (-fitmove 1) or only their values (-fitmove 0, the default):
#   - the options are checked (a fit's only; a frame of the molecule; -1
#     its last; the first clustered frame itself is the default);
#   - the rows superpose every frame on the reference frame: its own row is
#     its coordinates;
#   - -fitmove 0 leaves VMD's coordinates as they were; -fitmove 1 moves
#     every frame, all of its atoms, onto the reference, which is then left
#     as it is by a second alignment (the kept rows stay valid), and clusters
#     the same as -fitmove 0;
#   - the result, its label, vmdance info and the export say them, and a
#     corrupt one in a session is refused.
#   cd <VMDance>; vmd -dispdev text -e tests/test_fitframe.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
package require vmdance
use_fake
fake_env

# two_state (24 frames × 8 atoms), every frame turned and moved: frames
# that are not superposed.
proc unaligned {} {
    set m [load_system two_state]
    set all [atomselect $m all]
    set n [molinfo $m get numframes]
    for {set f 0} {$f < $n} {incr f} {
        $all frame $f
        $all move [transaxis z [expr {$f * 13}]]
        $all move [transaxis x [expr {$f * 7}]]
        $all moveby [list [expr {$f * 0.5}] [expr {-$f * 0.25}] 1.0]
    }
    $all delete
    return $m
}
proc coords_of {m} {
    set all [atomselect $m all]
    set out {}
    for {set f 0} {$f < [molinfo $m get numframes]} {incr f} { $all frame $f; lappend out [$all get {x y z}] }
    $all delete
    return $out
}
proc same_xyz {a b {tol 1e-4}} {
    foreach p [concat {*}$a] q [concat {*}$b] {
        foreach u $p v $q { if {abs($u - $v) > $tol} { return 0 } }
    }
    return 1
}
# The RMSD of frame f from frame r by every atom, as they are.
proc rmsd_of {m f r} {
    set a [atomselect $m all frame $f]; set b [atomselect $m all frame $r]
    set d [measure rmsd $a $b]
    $a delete; $b delete
    return $d
}
proc row_of {c i} {
    set out ""
    ::VMDance::Coords::each $c k r { if {$k == $i} { set out $r; break } }
    return $out
}

set m [unaligned]
set n [molinfo $m get numframes]
set J ::VMDance::Job

# --- the options, checked
check "-fitframe without -fit is refused" [string match "*-fitframe*give the fit's atoms*" [err {${J}::check_input [dict create mol $m sel all fitframe 3]}]]
check "-fitmove without -fit is refused" [string match "*-fitmove*give the fit's atoms*" [err {${J}::check_input [dict create mol $m sel all fitmove 1]}]]
check "-fitframe past the last frame is refused" [string match "*-fitframe must be a frame of molecule $m: 0 to [expr {$n - 1}]*" [err {${J}::check_input [dict create mol $m sel all fit all fitframe $n]}]]
check "-fitframe not a number is refused" [string match "*-fitframe must be a whole number*" [err {${J}::check_input [dict create mol $m sel all fit all fitframe 1.5]}]]
check "-fitmove not a boolean is refused" [string match "*-fitmove must be 0 or 1*" [err {${J}::check_input [dict create mol $m sel all fit all fitmove maybe]}]]
set q [${J}::check_input [dict create mol $m sel all fit all fitframe -1 fitmove yes]]
check "-fitframe -1 is the last frame, -fitmove yes is 1" [expr {[dict get $q fitframe] == $n - 1 && [dict get $q fitmove] == 1}]
set q [${J}::check_input [dict create mol $m sel all fit all fitframe 4 first 4]]
check "-fitframe the first clustered frame is the default (\"\")" [expr {[dict get $q fitframe] eq ""}]
set q [${J}::check_input [dict create mol $m sel all fit all fitframe 2 first 4]]
check "-fitframe may be a frame that is not clustered" [expr {[dict get $q fitframe] == 2}]
check "vmdance alignment takes no -fitframe" [string match "*its options are*" [err {vmdance alignment -mol $m -sel all -fitframe 2}]]

# --- the rows: superposed on the reference frame
set before [coords_of $m]
set q [${J}::check_input [dict create mol $m sel all fit all fitframe 5]]
set c [::VMDance::Coords::extract $q]
check "the reference frame's row is its coordinates" [same_xyz [list [row_of $c 5]] [list [concat {*}[lindex $before 5]]]]
check "another frame's row is not its coordinates" [expr {![same_xyz [list [row_of $c 7]] [list [concat {*}[lindex $before 7]]]]}]
check "the extraction keeps its reference frame" [expr {[::VMDance::_get $c fitframe ""] == 5}]
set q0 [${J}::check_input [dict create mol $m sel all fit all]]
check "another reference frame is another extraction" [expr {[dict size [::VMDance::Coords::cached $q0]] == 0}]
set c0 [::VMDance::Coords::extract $q0]
check "by default the first frame's row is its coordinates" [same_xyz [list [row_of $c0 0]] [list [concat {*}[lindex $before 0]]]]
# (a frame fitted on frame 5 is as far from 5's row as the least RMSD)
set r7 [row_of $c 7]; set r5 [row_of $c 5]
set s 0.0
foreach a $r7 b $r5 { set s [expr {$s + ($a - $b) ** 2}] }
set fitted [expr {sqrt($s / 8)}]
check "a row is superposed on the reference: no farther than the frame is as it is" [expr {$fitted <= [rmsd_of $m 7 5] + 1e-6}]

# --- -fitmove 0: VMD's coordinates stay
set r [vmdance -mol $m -sel all -fit all -fitframe 5 -k 2 -quiet 1]
check "-fitmove 0 does not move VMD's coordinates" [same_xyz [coords_of $m] $before 1e-9]
check "vmdance info says the fit's frame and that nothing moved" [expr {[dict get $r fitframe] == 5 && [dict get $r fitmove] == 0}]
set labels0 [vmdance labels]
set lab [::VMDance::Results::describe $::VMDance::Results::A]
check "the run's label says the frame" [string match "*fitted to frame 5*" $lab]

# --- -fitmove 1: every frame moved onto the reference, all of its atoms
set r [vmdance -mol $m -sel all -fit all -fitframe 5 -fitmove 1 -k 2 -quiet 1]
set after [coords_of $m]
check "-fitmove 1 leaves the reference frame where it was" [same_xyz [list [lindex $after 5]] [list [lindex $before 5]] 1e-9]
check "-fitmove 1 moves the other frames" [expr {![same_xyz [list [lindex $after 7]] [list [lindex $before 7]]]}]
set ok 1
for {set f 0} {$f < $n} {incr f} {
    # (moved by the rows' fit: each frame now as far from frame 5 as its row)
    set a [atomselect $m all frame $f]; set b [atomselect $m all frame 5]
    if {![::VMDance::Coords::_still [measure fit $a $b]]} { set ok 0 }
    $a delete; $b delete
}
check "every frame is superposed on the reference in VMD" $ok
check "a frame is now as far from the reference as its fitted row" [near [rmsd_of $m 7 5] $fitted 1e-3]
# (a fit on 4 of the 8 atoms moves all 8, rigidly: each frame's shape kept)
set m2 [unaligned]
set b2 [coords_of $m2]
set g0 [measure rgyr [set s7 [atomselect $m2 all frame 7]]]
set moved [::VMDance::Coords::align $m2 "index 0 to 3" 5]
set a2 [coords_of $m2]
check "a fit on some atoms moves every frame but the reference" [expr {$moved == $n - 1}]
check "and every atom, not only the fit's" [expr {![same_xyz [list [lrange [lindex $a2 7] 4 7]] [list [lrange [lindex $b2 7] 4 7]]]}]
check "rigidly: the frame's shape is kept" [near [measure rgyr $s7] $g0 1e-4]
$s7 delete
mol delete $m2
check "vmdance info says the coordinates were moved" [expr {[dict get $r fitframe] == 5 && [dict get $r fitmove] == 1}]
check "-fitmove 1 clusters as -fitmove 0" [expr {[vmdance labels] eq $labels0}]
check "the request keeps both" [expr {[dict get [::VMDance::Results::request] fitframe] == 5 && [dict get [::VMDance::Results::request] fitmove] == 1}]
set q1 [${J}::check_input [dict create mol $m sel all fit all fitframe 5 fitmove 1]]
check "aligning again moves no frame" [expr {[::VMDance::Coords::align $m [dict get $q1 fitatoms] 5] == 0}]
check "so the rows read stay kept" [expr {[dict size [::VMDance::Coords::cached $q1]] > 0}]
set after2 [coords_of $m]
check "and the coordinates are as they were" [same_xyz $after2 $after 1e-9]
check "a reference frame that is not numbers is refused" [string match "*-fitframe: molecule $m has no frame*" [err {::VMDance::Coords::align $m [dict get $q1 fitatoms] $n}]]

# --- a scan's clustering made a run (elbow load): it says the scan moved them
set m3 [unaligned]
set b3 [coords_of $m3]
vmdance elbow -mol $m3 -sel all -fit all -fitframe 5 -fitmove 1 -ks {2 3} -quiet 1
set a3 [coords_of $m3]
check "an elbow scan with -fitmove 1 moves the coordinates" [expr {![same_xyz [list [lindex $a3 7]] [list [lindex $b3 7]]]}]
vmdance elbow load 2
set q3 [::VMDance::Results::request]
check "its clustering, made a run, keeps -fitmove 1 and the frame" [expr {[dict get $q3 fitmove] == 1 && [dict get $q3 fitframe] == 5}]
check "and made the run without moving them again" [same_xyz [coords_of $m3] $a3 1e-9]
mol delete $m3

# --- what is written of it
check "the files' header names the fit's frame and the move" [string match "*fitted on: all, onto frame 5 (VMD's coordinates moved)*" [::VMDance::Export::header]]

# --- a session's request: a corrupt frame or move is refused
set R ::VMDance::Results
check "a corrupt fit frame is refused" [string match "*fit frame is corrupt*" [err {${R}::check_atoms "the request's" [dict create fitframe "0; exit"] "" {}}]]
check "a corrupt fit move is refused" [string match "*fit move is corrupt*" [err {${R}::check_atoms "the request's" [dict create fitmove 2] "" {}}]]
check "an old request (no fit frame) is accepted" [expr {[err {${R}::check_atoms "the request's" [dict create] "" {}}] eq ""}]

done
