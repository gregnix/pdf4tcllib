#!/usr/bin/env tclsh
# run_all.tcl -- Alle Examples ausfuehren (basic + advanced + demos)
#
# Usage: tclsh examples/run_all.tcl [-novalidate] [-nodemos] [-nobasic] [-noadvanced]

set scriptDir [file normalize [file dirname [info script]]]

set doBasic    1
set doAdvanced 1
set passArgs   {}
foreach arg $argv {
    switch -- $arg {
        -nobasic    { set doBasic    0 }
        -noadvanced { set doAdvanced 0 }
        default     { lappend passArgs $arg }
    }
}

proc runRunner {script args} {
    set rc [catch { exec tclsh $script {*}$args 2>@1 } msg]
    puts $msg
    return $rc
}

set t0   [clock seconds]
set rcB  0
set rcA  0

if {$doBasic} {
    puts ""
    puts [string repeat "=" 60]
    set rcB [runRunner [file join $scriptDir basic run_basic.tcl] {*}$passArgs]
}

if {$doAdvanced} {
    puts ""
    puts [string repeat "=" 60]
    set rcA [runRunner [file join $scriptDir advanced run_advanced.tcl] {*}$passArgs]
}

set elapsed [expr {[clock seconds] - $t0}]
puts ""
puts [string repeat "=" 60]
set total [expr {$rcB + $rcA}]
if {$total > 0} {
    puts "Gesamt: ${elapsed}s  -- FEHLER aufgetreten"
} else {
    puts "Gesamt: ${elapsed}s  -- alle OK"
}
