#!/usr/bin/env tclsh
# run_basic.tcl -- Basic examples (01-38, einzelne Features)
#
# Usage: tclsh basic/run_basic.tcl [-novalidate] [outdir]

set scriptDir [file dirname [file normalize [info script]]]

# Argumente
set doValidate 1
set outdir     ""
foreach arg $argv {
    if {$arg eq "-novalidate"} { set doValidate 0 } \
    elseif {$arg ne ""}        { set outdir $arg   }
}

set pdfdir [expr {$outdir ne "" ? $outdir : [file join $scriptDir pdf]}]
file mkdir $pdfdir

set validatorScript [file normalize [file join $scriptDir ../../tools/pdfvalidate.tcl]]

# Canvas-Skripte brauchen wish
proc needsWish {f} { string match "*canvas*" [file tail $f] }

proc runScript {f outdir} {
    set interp [expr {[needsWish $f] ? "wish" : "tclsh"}]
    set cmd [list $interp $f]
    if {$outdir ne ""} { lappend cmd $outdir }
    set t0 [clock milliseconds]
    set rc [catch { exec {*}$cmd 2>@1 } msg]
    set ms [expr {[clock milliseconds] - $t0}]
    return [list $rc $msg $ms]
}

set scripts [lsort [glob -directory $scriptDir {[0-9]*.tcl}]]
set ok 0; set fail 0; set errors {}

puts "=== Basic Examples ([llength $scripts] Skripte) ==="
puts [string repeat "-" 60]

foreach f $scripts {
    set name [file tail $f]
    lassign [runScript $f $pdfdir] rc msg ms
    if {$rc == 0} {
        puts [format "  OK   %-42s %4dms" $name $ms]
        incr ok
    } else {
        set err [lindex [split $msg "\n"] 0]
        puts [format "  FAIL %-42s %s" $name $err]
        lappend errors [list $name $msg]
        incr fail
    }
}

puts [string repeat "-" 60]
puts "Ergebnis: $ok OK  /  $fail Fehler  |  Ausgabe: $pdfdir"

if {[llength $errors] > 0} {
    puts "\n=== Fehler-Details ==="
    foreach e $errors {
        lassign $e name msg
        puts "\n--- $name ---"
        puts [join [lrange [split $msg "\n"] 0 4] "\n"]
    }
}

if {$doValidate && [file exists $validatorScript]} {
    set pdfs [lsort [glob -nocomplain [file join $pdfdir *.pdf]]]
    if {[llength $pdfs] > 0} {
        puts "\n=== PDF-Validierung ==="; puts [string repeat "-" 60]
        catch { exec tclsh $validatorScript -nocolor {*}$pdfs 2>@1 } vout
        puts $vout
    }
}
