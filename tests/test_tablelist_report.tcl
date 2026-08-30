# test_tablelist_report.tcl -- was der Export nicht uebertragen kann
#
# Der Sinn des Exporteurs ist: was auf dem Bildschirm steht, kommt ins
# PDF. Drei Dinge kann er nicht, und bis 0.3.1 verschwanden sie lautlos:
# ein Bild in einer Zelle, ein eingebettetes Fenster, und eine
# umbrechende Spalte -- dort steht der Text im Widget mehrzeilig, im PDF
# in einer Zeile mit "...", weil table::draw nicht umbricht.

package require tcltest
namespace import ::tcltest::*

# Damit die Datei auch EINZELN laeuft. Ohne diese Zeile findet sie
# pdf4tcllib nur ueber ein installiertes Paket -- und die Constraints
# unten fragen genau danach. Fehlt es, ueberspringt tcltest still
# ALLES und meldet trotzdem Erfolg: Rueckgabewert 0, Failed 0. Der
# Runner setzt den Pfad selbst, deshalb fiel es nie auf.
tcl::tm::path add [file join [file dirname [file normalize [info script]]] .. lib]

testConstraint pdf [expr {![catch {package require pdf4tcl}]}]
testConstraint lib [expr {![catch {package require pdf4tcllib}]}]
testConstraint tbl [expr {![catch {
    package require Tk
    package require tablelist_tile
    package require pdf4tcltable
}]}]

proc tlBaue {} {
    catch {destroy .tr}
    tablelist::tablelist .tr -columns {0 "A" left 0 "Lang" left} \
            -stretch all -height 6
    .tr insert end {eins kurz}
    .tr insert end [list zwei \
            "ein sehr langer Text der in der Zelle umbrochen wird"]
    pack .tr
    update idletasks
    return .tr
}

proc tlExport {} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::tablelist::render $pdf .tr 50 50 -maxwidth 400
    $pdf destroy
    return [::pdf4tcllib::tablelist::report]
}

test tlrep-1.1 {ohne Besonderheiten wird nichts gemeldet} \
        -constraints {pdf lib tbl} -body {
    tlBaue
    set ::pdf4tcl::warnings {}
    set r [tlExport]
    destroy .tr
    list [dict get $r images] [dict get $r windows] [dict get $r wrapped] \
            [llength $::pdf4tcl::warnings]
} -result {0 0 0 0}

test tlrep-1.2 {ein Bild in einer Zelle wird gemeldet} \
        -constraints {pdf lib tbl} -body {
    tlBaue
    catch {image delete tlIco}
    image create photo tlIco -width 8 -height 8
    .tr cellconfigure 0,0 -image tlIco
    update idletasks
    set r [tlExport]
    destroy .tr
    image delete tlIco
    list [dict get $r images] [dict get $r cells]
} -result {1 0,0}

test tlrep-1.3 {ein eingebettetes Fenster wird gemeldet} \
        -constraints {pdf lib tbl} -body {
    proc tlCb {tbl row col w} { checkbutton $w -text ja }
    tlBaue
    .tr cellconfigure 1,0 -window tlCb
    update idletasks
    set r [tlExport]
    destroy .tr
    rename tlCb {}
    dict get $r windows
} -result 1

test tlrep-1.4 {eine umbrechende Spalte wird gemeldet} \
        -constraints {pdf lib tbl} -body {
    tlBaue
    .tr columnconfigure 1 -wrap 1 -width 20
    update idletasks
    set r [tlExport]
    destroy .tr
    dict get $r wrapped
} -result 1

test tlrep-1.5 {kurzer Text in einer umbrechenden Spalte nicht} \
        -constraints {pdf lib tbl} -body {
    # Eine umbrechende Spalte allein ist kein Verlust -- "kurz" passt
    # auch dort in eine Zeile. Sonst meldete jede Zelle der Spalte.
    catch {destroy .tr}
    tablelist::tablelist .tr -columns {0 "A" left} -stretch all
    .tr insert end {kurz}
    .tr columnconfigure 0 -wrap 1 -width 20
    pack .tr
    update idletasks
    set r [tlExport]
    destroy .tr
    dict get $r wrapped
} -result 0

test tlrep-1.6 {es wird einmal laut gesagt} -constraints {pdf lib tbl} -body {
    # Der Zaehler allein hilft nur dem, der ihn abfragt -- und wer nicht
    # weiss, dass es ihn gibt, fragt nicht.
    tlBaue
    .tr columnconfigure 1 -wrap 1 -width 20
    update idletasks
    set ::pdf4tcl::warnings {}
    tlExport
    destroy .tr
    list [llength $::pdf4tcl::warnings] \
            [string match "*wrapped column*" [lindex $::pdf4tcl::warnings 0]]
} -result {1 1}

test tlrep-1.7 {der Bericht gilt fuer den letzten Lauf} \
        -constraints {pdf lib tbl} -body {
    # Sonst summierte sich ueber mehrere Tabellen und niemand wuesste,
    # welche gemeint ist.
    tlBaue
    .tr columnconfigure 1 -wrap 1 -width 20
    update idletasks
    tlExport
    destroy .tr
    tlBaue
    update idletasks
    set r [tlExport]
    destroy .tr
    dict get $r wrapped
} -result 0

rename tlBaue {}
rename tlExport {}

cleanupTests
