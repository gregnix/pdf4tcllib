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

# Interpreter aus dem laufenden ableiten statt "tclsh"/"wish" im PATH zu
# suchen. Sonst prueft der Sammellauf die Generation, die zufaellig zuerst
# im PATH steht -- unter 9.0 gestartet, unter 8.6 gemessen.
proc interpFor {f} {
    set self [info nameofexecutable]
    if {![needsWish $f]} { return $self }
    set cand [file join [file dirname $self] \
                  [string map {tclsh wish} [file tail $self]]]
    if {[file executable $cand]} { return $cand }
    return $self
}

# Zeitgrenze je Skript. Ohne sie wartet exec unbegrenzt, und ein Beispiel,
# das Tk laedt und kein exit hat, haelt den ganzen Lauf fest -- auf einer
# Maschine mit Anzeige, waehrend es im CI ohne DISPLAY sauber durchlaeuft.
# timeout(1) stammt aus den coreutils und fehlt auf Windows; dort laeuft es
# wie bisher.
set ::scriptTimeout 120
set ::timeoutCmd {}
if {[llength [auto_execok timeout]] > 0} {
    set ::timeoutCmd [list timeout $::scriptTimeout]
}

# Beispiele, die ein Fenster oeffnen und auf Eingabe warten.
#
#   -batch   das Skript kennt einen Stapelmodus; der Schalter gehoert NACH
#            das Ausgabeverzeichnis, sonst nimmt das Skript ihn dafuer
#            ("Written: -batch/demo_54...").
#   skip     der Export haengt an einem Knopf im Fenster; im Stapellauf ist
#            hier nichts zu holen.
#
# Ohne diese Liste blockierte jedes davon den Lauf -- aber nur auf einer
# Maschine mit Anzeige. Ohne DISPLAY scheitert das Laden von Tk sofort und
# der Lauf gilt als "gruen".
set ::interactive {
    54_canvas_vs_tkopath.tcl    -batch
    55_canvas_items_matrix.tcl  -batch
    56_tablelist_pdf.tcl        skip
    57_textwidget_pdf.tcl       skip
    58_tablelist_miscwidgets.tcl skip
}

proc interactiveMode {f} {
    set name [file tail $f]
    if {[dict exists $::interactive $name]} {
        return [dict get $::interactive $name]
    }
    return ""
}

proc runScript {f outdir} {
    set cmd [list {*}$::timeoutCmd [interpFor $f] $f]
    if {$outdir ne ""} { lappend cmd $outdir }
    if {[interactiveMode $f] eq "-batch"} { lappend cmd -batch }
    set t0 [clock milliseconds]
    set rc [catch { exec {*}$cmd 2>@1 } msg]
    set ms [expr {[clock milliseconds] - $t0}]
    if {$rc && [lindex $::errorCode 0] eq "CHILDSTATUS"
            && [lindex $::errorCode 2] == 124} {
        append msg "\nZEITGRENZE ($::scriptTimeout s) -- laeuft das Skript in\
                die Event-Loop? Ein Beispiel, das Tk laedt und kein exit hat,\
                wartet hier unbegrenzt."
    }
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
set skipped 0
foreach f $exScripts {
    set name [file tail $f]
    if {[interactiveMode $f] eq "skip"} {
        puts [format "  SKIP %-42s %s" $name "interaktiv, Export per Knopf"]
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
puts "Ergebnis: $ok OK  /  $fail Fehler  /  $skipped interaktiv  |  Ausgabe: $pdfdir"

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
