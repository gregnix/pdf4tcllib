#!/usr/bin/env tclsh
# run_advanced.tcl -- Advanced examples + Demos (d01-d08)
#
# Enthaelt:
#   36, 39-49  -- Komplexe Examples (Batch, Forms, Annotations, ...)
#   d01-d08    -- Integrations-Demos (mehrere Module im Zusammenspiel)
#
# Usage: tclsh advanced/run_advanced.tcl [-novalidate] [-nodemos] [outdir]

set scriptDir [file dirname [file normalize [info script]]]

# Argumente
set doValidate 1
set noDemos    0
set outdir     ""
foreach arg $argv {
    switch -- $arg {
        -novalidate { set doValidate 0 }
        -nodemos    { set noDemos    1 }
        default     { if {$arg ne ""} { set outdir $arg } }
    }
}

set pdfdir [expr {$outdir ne "" ? $outdir : [file join $scriptDir pdf]}]
file mkdir $pdfdir

set validatorScript [file normalize [file join $scriptDir ../../tools/pdfvalidate.tcl]]

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

# Skripte aufteilen: [0-9]*.tcl = examples, d*.tcl = demos
set exScripts   [lsort [glob -directory $scriptDir {[0-9]*.tcl}]]
set demoScripts [lsort [glob -directory $scriptDir {d[0-9]*.tcl}]]

if {$noDemos} { set demoScripts {} }

set ok 0; set fail 0; set errors {}

# --- Advanced Examples ---
puts "=== Advanced Examples ([llength $exScripts] Skripte) ==="
puts [string repeat "-" 60]
foreach f $exScripts {
    set name [file tail $f]
    lassign [runScript $f $pdfdir] rc msg ms
    if {$rc == 0} {
        puts [format "  OK   %-42s %4dms" $name $ms]
        incr ok
    } else {
        set err [lindex [split $msg "\n"] 0]
        puts [format "  FAIL %-42s %s" $name $err]
        lappend errors [list $name $msg]; incr fail
    }
}

# --- Integrations-Demos ---
if {[llength $demoScripts] > 0} {
    puts ""
    puts "=== Integrations-Demos ([llength $demoScripts] Skripte) ==="
    puts [string repeat "-" 60]
    foreach f $demoScripts {
        set name [file tail $f]
        lassign [runScript $f $pdfdir] rc msg ms
        if {$rc == 0} {
            set tag [expr {[needsWish $f] ? " (wish)" : ""}]
            puts [format "  OK   %-42s %4dms%s" $name $ms $tag]
            incr ok
        } else {
            set err [lindex [split $msg "\n"] 0]
            puts [format "  FAIL %-42s %s" $name $err]
            lappend errors [list $name $msg]; incr fail
        }
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
