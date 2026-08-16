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

namespace eval runner {}
source [file join $scriptDir .. _runner.tcl]

proc runScript {f outdir} {
    return [runner::runScript $f $outdir [needsWish $f]]
}

set scripts [runner::collect $scriptDir {[0-9]*.tcl} 20 {nummerierte Beispiele}]
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
        # Der Interpreter kommt aus dem laufenden Prozess, nicht aus dem
        # PATH -- ein blankes `tclsh` prueft sonst unter der Generation,
        # die dort zuerst steht, waehrend der Lauf unter einer anderen
        # gestartet wurde.
        #
        # Der Validator liefert rc=2, sobald eine Datei eine WARNUNG hat
        # (nicht eingebettete Standardfonts etwa). Tcl haengt in dem Fall
        # "child process exited abnormally" an die Ausgabe -- das stand
        # bisher unkommentiert unter dem Ergebnis und sah aus wie ein
        # Fehler des Laufs. Der Rueckgabewert wird jetzt gelesen und
        # benannt.
        set vrc [catch { exec [info nameofexecutable] $validatorScript \
                -nocolor {*}$pdfs 2>@1 } vout]
        if {$vrc && [lindex $::errorCode 0] eq "CHILDSTATUS"} {
            set code [lindex $::errorCode 2]
            # Tcls Zusatzzeile aus der Ausgabe nehmen, sie sagt nichts.
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
