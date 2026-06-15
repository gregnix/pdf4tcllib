#!/usr/bin/env tclsh
# run_all.tcl -- run every test_*.tcl in its OWN tclsh subprocess and
# aggregate the tcltest summaries.
#
# Why subprocesses: sourcing all test files in one interpreter is wrong --
# the first file's `cleanupTests` resets the tcltest counters, so the run
# reports only the first file ("all passed" = 1/8). One process per file
# keeps each file's counters and failures isolated and correctly summed.
#
# Usage:
#   tclsh run_all.tcl                 ;# run all, summary per file
#   tclsh run_all.tcl -verbose p      ;# pass tcltest options through
#
# pdf4tcl must be reachable (installed, or via TCLLIBPATH) -- pdf4tcllib
# pulls it in; this runner only adds pdf4tcllib's own ../lib to tm::path.

package require Tcl 8.6-

set testDir [file dirname [file normalize [info script]]]
set libDir  [file normalize [file join $testDir .. lib]]
set passArgs $argv

set files [lsort [glob -nocomplain -directory $testDir test_*.tcl]]
if {![llength $files]} { puts "Keine test_*.tcl gefunden."; exit 0 }

set sumTotal 0; set sumPassed 0; set sumSkipped 0; set sumFailed 0
set failedFiles {}

foreach f $files {
    set name [file tail $f]
    # Bootstrap for the child interp. argv stays empty so the test file's
    # own `tcltest::configure $argv` does not choke on a file name. The
    # `source` sets [info script] to $f, so data-file lookups still work.
    set boot ""
    append boot "tcl::tm::path add [list $libDir]\n"
    append boot "if {\[catch {package require pdf4tcllib 0.2} e\]} {puts stderr \"LOAD: \$e\"; exit 2}\n"
    append boot "package require tcltest\n"
    if {[llength $passArgs]} {
        append boot "tcltest::configure {*}[list $passArgs]\n"
    }
    append boot "source [list $f]\n"

    set rc [catch {exec [info nameofexecutable] << $boot 2>@1} out]

    set T 0; set P 0; set S 0; set F 0; set seen 0
    foreach line [split $out \n] {
        set l [string map [list \t " "] $line]
        if {[regexp {Total +([0-9]+) +Passed +([0-9]+) +Skipped +([0-9]+) +Failed +([0-9]+)} \
                $l -> T P S F]} { set seen 1; break }
    }
    incr sumTotal $T; incr sumPassed $P; incr sumSkipped $S; incr sumFailed $F
    if {$F > 0 || $rc != 0 || !$seen} { lappend failedFiles $name }
    puts [format "  %-22s Total %3d  Passed %3d  Skipped %3d  Failed %3d%s" \
            $name $T $P $S $F [expr {$seen ? "" : "   <== keine Summary/Ladefehler"}]]
    if {!$seen} { puts [string trimright $out] }
}

puts [string repeat "=" 60]
puts [format "Gesamt: Total %d  Passed %d  Skipped %d  Failed %d  (%d Dateien)" \
        $sumTotal $sumPassed $sumSkipped $sumFailed [llength $files]]
if {[llength $failedFiles]} {
    puts "FEHLGESCHLAGEN: [join $failedFiles {, }]"
    exit 1
}
puts "Alle bestanden."
