#!/usr/bin/env tclsh
# run-all-examples.tcl -- run every howto and tutorial script.
#
#   tclsh docs/en/run-all-examples.tcl [outdir]
#
# Each script is started in its own process with a time limit: a script
# that loads Tk and has no exit would otherwise hold the run up forever,
# and only on a machine with a display -- without DISPLAY the same run
# passes, because loading Tk fails there.

set here [file dirname [file normalize [info script]]]
set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $here out]}]
file mkdir $outdir

set limit 60
set timeoutCmd {}
if {[llength [auto_execok timeout]] > 0} {
    set timeoutCmd [list timeout $limit]
}

set ok 0; set fail 0; set skip 0; set failed {}
foreach dir {howtos tutorials} {
    set files [lsort [glob -nocomplain [file join $here $dir *.tcl]]]
    if {![llength $files]} { continue }
    puts "=== [string totitle $dir] ([llength $files]) ==="
    foreach f $files {
        set name [file tail $f]
        set cmd [list {*}$timeoutCmd [info nameofexecutable] $f $outdir]
        set t0 [clock milliseconds]
        set rc [catch { exec {*}$cmd 2>@1 } msg]
        set ms [expr {[clock milliseconds] - $t0}]
        if {$rc == 0} {
            # A script that gives up for want of Tk or a display is not a
            # success -- report it as skipped, or a run without DISPLAY
            # looks as green as one with it. That confusion has cost real
            # time in this project.
            if {[string match "*skipped --*" $msg]} {
                set why [lindex [split $msg \n] end]
                puts [format "  SKIP %-34s %s" $name \
                        [string range $why 11 end]]
                incr skip
                continue
            }
            # The scripts print their own untagged count; surface it here,
            # because a script that runs and leaves content untagged is not
            # a success worth reporting as one.
            set left ""
            foreach line [split $msg \n] {
                if {[regexp {untagged painting operations: (\d+)} $line -> n]} {
                    set left $n
                }
            }
            if {$left ne "" && $left != 0} {
                puts [format "  WARN %-34s %4dms  %s untagged" $name $ms $left]
            } else {
                puts [format "  OK   %-34s %4dms" $name $ms]
            }
            incr ok
        } else {
            if {[lindex $::errorCode 0] eq "CHILDSTATUS"
                    && [lindex $::errorCode 2] == 124} {
                puts [format "  TIME %-34s limit %ds" $name $limit]
            } else {
                puts [format "  FAIL %-34s %s" $name \
                        [lindex [split $msg \n] 0]]
            }
            lappend failed $name
            incr fail
        }
    }
}

puts [string repeat = 60]
puts "OK=$ok  SKIP=$skip  FAIL=$fail  outdir=$outdir"
foreach f $failed { puts "  - $f" }
exit [expr {$fail > 0}]
