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

namespace eval runner {}
source [file join $scriptDir .. _runner.tcl]

# Examples that open a window and wait for input.
#
#   -batch   the script knows a batch mode; the switch belongs AFTER the
#            output directory, or the script takes it for one
#            ("Written: -batch/demo_54...").
#   skip     the export hangs off a button in the window; there is nothing
#            to collect in a batch run.
#
# Without this list every one of them blocked the run -- but only on a
# machine with a display. Without DISPLAY loading Tk fails at once and the
# run counts as "green".
set ::interactive {
    54_canvas_vs_tkopath.tcl    -batch
    55_canvas_items_matrix.tcl  -batch
    56_tablelist_pdf.tcl        -batch
    57_textwidget_pdf.tcl       -batch
    58_tablelist_miscwidgets.tcl -batch
}

proc interactiveMode {f} {
    set name [file tail $f]
    if {[dict exists $::interactive $name]} {
        return [dict get $::interactive $name]
    }
    return ""
}

proc runScript {f outdir} {
    set extra {}
    if {[interactiveMode $f] eq "-batch"} { set extra -batch }
    return [runner::runScript $f $outdir [needsWish $f] $extra]
}

# Skripte aufteilen: [0-9]*.tcl = examples, d*.tcl = demos
set exScripts   [runner::collect $scriptDir {[0-9]*.tcl}  20 {nummerierte Beispiele}]
set demoScripts [runner::collect $scriptDir {d[0-9]*.tcl}  5 {Demos d01-d08}]

if {$noDemos} { set demoScripts {} }

set ok 0; set fail 0; set errors {}

# --- Advanced Examples ---
puts "=== Advanced Examples ([llength $exScripts] Skripte) ==="
puts [string repeat "-" 60]
set skipped 0
foreach f $exScripts {
    set name [file tail $f]
    if {[interactiveMode $f] eq "skip"} {
        puts [format "  SKIP %-42s %s" $name "interactive, exports from a button"]
        incr skipped
        continue
    }
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
puts "Ergebnis: $ok OK  /  $fail Fehler  /  $skipped interactive  |  Ausgabe: $pdfdir"

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
        # Interpreter aus dem laufenden Prozess (nicht das blanke tclsh
        # aus dem PATH), und der Rueckgabewert wird gelesen: der Validator
        # liefert rc=2 bei blossen Warnungen, worauf Tcl "child process
        # exited abnormally" an die Ausgabe haengt -- das sah bisher aus
        # wie ein Fehler des Laufs.
        set vrc [catch { exec [info nameofexecutable] $validatorScript \
                -nocolor {*}$pdfs 2>@1 } vout]
        if {$vrc && [lindex $::errorCode 0] eq "CHILDSTATUS"} {
            set code [lindex $::errorCode 2]
            set vout [string trim [string map \
                    {"child process exited abnormally" ""} $vout]]
            puts $vout
            if {$code == 2} {
                puts "(Validator: Warnungen, keine Fehler -- rc=2)"
            } else {
                puts "(Validator: rc=$code)"
            }
        } else {
            puts $vout
        }
    }
}
