# VMDance: a library of CPP-MDANCE's second interface (API 2: datasets and
# jobs; Job::_call_v2). What the plugin gives it and what comes back:
#   - a job's coordinates go into the library as one dataset, filled once
#     from the rows the extraction read, for every call of the job (a scan's
#     every k, HELM's first clustering), and freed when the job ends;
#   - each call runs as a job of the library's: Tcl's event loop goes on
#     during it (VMD draws and answers), its progress is said, and Cancel
#     stops it; its error is the job's;
#   - the answers are the program's on the same coordinates.
# tests/test_hardening2_h3.tcl tests a library of the first interface.
#   cd <VMDance>; vmd -dispdev text -e tests/test_library_v2.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]

# What the library was asked: the datasets made, and each job started (its
# call and dataset), with the progress step said last before it.
set ::made 0
set ::starts {}
set ::said ""
set ::cancel_at ""
set ::fail_at ""
set ::ticked {}
proc v2_said {cmd op} { set ::said [lindex $cmd 2] }
proc v2_wrap {} {
    rename ::mdance::data ::mdance::data_v2
    proc ::mdance::data {sub args} {
        if {$sub eq "create"} { incr ::made }
        uplevel 1 [list ::mdance::data_v2 $sub {*}$args]
    }
    rename ::mdance::job ::mdance::job_v2
    proc ::mdance::job {sub args} {
        switch -- $sub {
            start {
                # (a scan names its algorithm first, then its dataset)
                set ds [expr {[lindex $args 0] eq "scan" ? [lindex $args 2] : [lindex $args 1]}]
                lappend ::starts [list [lindex $args 0] $ds $::said]
                set ::last_start $args
                # (a timer set as the call starts: it runs before the call's
                # answer is read when Tcl's event loop goes on meanwhile)
                set ::tick 0
                after 0 {set ::tick 1}
                # (Cancel pressed as the call n runs)
                if {$::cancel_at eq [llength $::starts]} { after 0 ::VMDance::Job::cancel }
            }
            result {
                lappend ::ticked $::tick
                if {$::fail_at eq [llength $::starts]} {
                    catch {::mdance::job_v2 result {*}$args}
                    error "the library failed"
                }
            }
        }
        uplevel 1 [list ::mdance::job_v2 $sub {*}$args]
    }
}
proc v2_unwrap {} {
    rename ::mdance::data {}
    rename ::mdance::data_v2 ::mdance::data
    rename ::mdance::job {}
    rename ::mdance::job_v2 ::mdance::job
}
proc v2_reset {} { set ::made 0; set ::starts {}; set ::ticked {} }
proc v2_calls {} { lmap s $::starts {lindex $s 0} }
proc v2_sets {} { llength [lsort -unique [lmap s $::starts {lindex $s 1}]] }
proc v2_labels {} { lmap r [dict get $::VMDance::Results::elbow records] {dict get $r clustering labels} }
proc v2_status {} { lmap r [dict get $::VMDance::Results::elbow records] {dict get $r status} }
# (the library holds nothing once a job has ended)
proc v2_clean {} {
    expr {![llength [::mdance::data_v2 names]] && ![llength [::mdance::job_v2 names]] &&
        $::VMDance::Job::lib_data eq "" && $::VMDance::Job::lib_of eq ""}
}

if {[catch {
package require vmdance
set ::VMDance::Prefs::file ""
set R ::VMDance::Results

proc v2_api {} {
    if {[real_lib] eq ""} { return 0 }
    ::VMDance::Backend::load_lib [real_lib]
    ::VMDance::Backend::lib_api
}
if {[real_lib] eq "" || [real_cli] eq ""} {
    skip "the second interface's library" "no mdance_tcl library or mdance-cli"
} elseif {[v2_api] < 2} {
    skip "the second interface's library" "the library is API 1 (tests/test_hardening2_h3.tcl tests it)"
} else {
    set m [load_system two_state]
    use_lib
    check "the library is API 2" [expr {[::VMDance::Backend::lib_api] == 2}]
    set algos [::VMDance::Backend::algorithms 1]
    check "  its algorithms, DIVINE as ::mdance::info says ($algos)" [expr {
        ("divine" in $algos) == [dict get [::mdance::info] divine] && "kmeans" in $algos && "helm" in $algos && "equal" in $algos}]
    v2_wrap
    trace add execution ::VMDance::Job::_progress enter v2_said

    # --- one dataset for a job's calls ----------------------------------------------------------
    vmdance -mol $m -sel all -k 2 -kinit StratAll -percentage 50 -quiet 1
    v2_reset
    vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit StratAll -percentage 50 -quiet 1
    set lib [v2_labels]
    check "an elbow scan of 3 values of k makes one dataset ($::made) and runs them as one scan, at once on the library's threads ([v2_calls])" [expr {
        $::made == 1 && [v2_calls] eq {scan} && [v2_sets] == 1}]
    check "  and the library holds nothing once the scan has ended" [v2_clean]
    check "  the step before it said that the library runs them at once, and not that VMD waits" [expr {
        [lmap s $::starts {lindex $s 2}] eq [list "KMeans NANI, k = 2, 3, 4, in the library at once"]}]
    check "  Tcl's event loop ran during it (VMD draws and answers: $::ticked)" [expr {$::ticked eq {1}}]
    use_cli
    vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit StratAll -percentage 50 -quiet 1
    use_lib
    check "  the same labels at every k as the program's, on the same coordinates" [expr {[llength $lib] == 3 && $lib eq [v2_labels]}]

    v2_reset
    vmdance elbow -mol $m -sel all -algorithm helm -initial 8 -initial-kinit StratAll -initial-percentage 50 -ks {2 3 4} -quiet 1
    set lib [v2_labels]
    check "a HELM elbow scan: its first clustering, then every k as one scan, on one dataset ([v2_calls])" [expr {
        $::made == 1 && [v2_calls] eq {kmeans scan} && [v2_sets] == 1 && [lsort -unique [v2_status]] eq "ok"}]
    use_cli
    vmdance elbow -mol $m -sel all -algorithm helm -initial 8 -initial-kinit StratAll -initial-percentage 50 -ks {2 3 4} -quiet 1
    use_lib
    check "  the program's labels" [expr {$lib eq [v2_labels]}]

    # (a value the checks before a call refuse stays out of the scan, and is
    # recorded "not run" as before: HELM from 8 starting clusters at k 20)
    v2_reset
    vmdance elbow -mol $m -sel all -algorithm helm -initial 8 -initial-kinit StratAll -initial-percentage 50 -ks {2 3 20} -quiet 1
    set recs [dict get $::VMDance::Results::elbow records]
    check "  a value refused before a call: kept out of the scan (-ks [lindex $::last_start [expr {[lsearch -exact $::last_start -ks] + 1}]]), recorded not run" [expr {
        [lindex $::last_start [expr {[lsearch -exact $::last_start -ks] + 1}]] eq {2 3} &&
        [lrange [v2_status] 0 1] eq {ok ok} && [lindex [v2_status] 2] ne "ok" &&
        [string match "not run:*" [dict get [lindex $recs 2] message]]}]

    v2_reset
    vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3 4} -seedings StratAll -params {kmeans {percentage 50}} -quiet 1
    check "a sweep: its 3 configurations on one dataset" [expr {$::made == 1 && [llength $::starts] == 3 && [v2_sets] == 1 && [v2_clean]}]

    foreach a {divine equal} opts {{-k 3 -anchors OutlierPair} {-threshold 0.5}} {
        if {$a ni $algos} { skip "$a against the program" "not in this build"; continue }
        foreach bk {lib cli} {
            use_$bk
            vmdance -mol $m -sel all -algorithm $a {*}$opts -quiet 1
            set lab($bk) [${R}::labels]
        }
        use_lib
        check "$a: the program's labels" [expr {$lab(lib) eq $lab(cli)}]
    }

    # --- PRIME, the similarity and the picks ------------------------------------------------------
    foreach bk {lib cli} {
        use_$bk
        vmdance -mol $m -sel all -k 2 -kinit StratAll -percentage 50 -quiet 1
        set pr($bk) [vmdance prime]
        set si($bk) [vmdance similarity]
        set pk($bk) [vmdance pick -mol $m -sel all -method diversity -param 20]
    }
    use_lib
    # (the program writes its JSON with 10 significant digits, the library
# hands the doubles over: the similarity's numbers agree to that)
proc v2_same_sim {a b} {
    if {[dict get $a metric] ne [dict get $b metric] || [dict get $a least_similar] ne [dict get $b least_similar]} { return 0 }
    set x [concat [dict get $a isim] [dict values [dict get $a clusters]]]
    set y [concat [dict get $b isim] [dict values [dict get $b clusters]]]
    if {[llength $x] != [llength $y]} { return 0 }
    foreach u $x v $y { if {abs($u - $v) > 1e-9 * max(abs($u), abs($v), 1e-300)} { return 0 } }
    return 1
}
check "PRIME, the similarity and a pick: the program's answers (the similarity to its 10 digits)" [expr {
    $pr(lib) eq $pr(cli) && [v2_same_sim $si(lib) $si(cli)] && $pk(lib) eq $pk(cli)}]

    # --- Cancel during a call, and a call that fails ----------------------------------------------
    vmdance -mol $m -sel all -k 2 -kinit StratAll -percentage 50 -quiet 1
    set nruns [llength [vmdance runs]]
    v2_reset
    set ::cancel_at 1
    set e [err {vmdance -mol $m -sel all -k 3 -kinit StratAll -percentage 50 -quiet 1}]
    set ::cancel_at ""
    check "Cancel during a library call: the job ends cancelled, nothing published, the library holds nothing ($e)" [expr {
        [string match "*cancelled*" $e] && [llength [vmdance runs]] == $nruns && [v2_clean]}]
    set eb $::VMDance::Results::elbow
    v2_reset
    set ::cancel_at 1
    set e [err {vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit StratAll -percentage 50 -quiet 1}]
    set ::cancel_at ""
    check "  during an elbow's scan: the job ends cancelled, the elbow not replaced, the library holds nothing ($e)" [expr {
        [string match "*cancelled*" $e] && [v2_calls] eq {scan} && $eb eq $::VMDance::Results::elbow && [v2_clean]}]
    v2_reset
    set ::fail_at 1
    set e [err {vmdance -mol $m -sel all -k 3 -kinit StratAll -percentage 50 -quiet 1}]
    set ::fail_at ""
    check "a library call that fails: its message ($e), nothing published, the library holds nothing" [expr {
        [string match "*the library failed*" $e] && [llength [vmdance runs]] == $nruns && [v2_clean]}]
    v2_reset
    set e [err {vmdance -mol $m -sel all -k 2 -kinit StratAll -percentage 50 -quiet 1}]
    check "  and a job after them runs and publishes ($e)" [expr {$e eq "" && [llength $::starts] == 1 && [llength [vmdance runs]] == $nruns + 1}]

    # --- what the library can take ------------------------------------------------------------
    if {[::VMDance::Job::_memory_free] eq ""} {
        skip "the memory a call needs" "this system does not say how much is free (no /proc)"
    } else {
        set peak $::VMDance::Job::lib2_peak
        set ::VMDance::Job::lib2_peak 1e15
        set e [err {::VMDance::Job::_library_fits 8 100}]
        set ::VMDance::Job::lib2_peak $peak
        check "a call that would need more memory than VMD has is refused, saying what to change ($e)" [string match "*would need about*use the program*" $e]
    }
    check "  and no text limit: the second interface makes no text of the coordinates" [expr {[err {::VMDance::Job::_library_fits 1000000 1000 5000000000}] eq ""}]

    trace remove execution ::VMDance::Job::_progress enter v2_said
    v2_unwrap
    use_fake
}

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_library_v2 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
