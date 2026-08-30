# test_subst.tcl -- fehlende Glyphen werden gezaehlt, nicht verschwiegen
#
# sanitize ersetzt ein Zeichen, das die Schrift nicht hat, durch "?".
# Bis 0.6.3 geschah das lautlos: weder der Rueckgabewert noch ein Zaehler
# sagte etwas. Gemessen an math::renderLatex: "\alpha \sum" ohne
# fonts::init -cid 1 ergab sechs Fragezeichen im Inhaltsstrom, und nichts
# wies darauf hin.
#
# Der Zaehler laeuft wie der von pdf4tcl (getSubstCount): kumulativ,
# abfragbar, zuruecksetzbar.

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

proc suNew {} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    $pdf setFont 12 Helvetica
    ::pdf4tcllib::unicode::resetSubst
    return $pdf
}

test subst-1.1 {ein fehlendes Zeichen wird gezaehlt} -constraints {pdf lib} \
        -body {
    set pdf [suNew]
    ::pdf4tcllib::unicode::safeText $pdf "Alpha: \u03b1" -x 50 -y 100
    set n [::pdf4tcllib::unicode::substCount]
    $pdf destroy
    set n
} -result 1

test subst-1.2 {der Bericht nennt, WELCHES} -constraints {pdf lib} -body {
    # Eine Zahl allein hilft nicht: man muss wissen, welche Zeichen
    # fehlen, um die richtige Schrift zu laden.
    set pdf [suNew]
    ::pdf4tcllib::unicode::safeText $pdf "\u03b1\u03b2 und \u2211" -x 50 -y 100
    set r [::pdf4tcllib::unicode::substReport]
    $pdf destroy
    list [dict get $r count] [dict get $r chars]
} -result {3 {U+03B1 U+03B2 U+2211}}

test subst-1.3 {reiner ASCII-Text zaehlt nichts} -constraints {pdf lib} \
        -body {
    set pdf [suNew]
    ::pdf4tcllib::unicode::safeText $pdf "Nothing missing here." -x 50 -y 100
    set n [::pdf4tcllib::unicode::substCount]
    $pdf destroy
    set n
} -result 0

test subst-1.4 {Latin-1 zaehlt nicht} -constraints {pdf lib} -body {
    # Umlaute sind in WinAnsi und gehen durch -- sie zu zaehlen waere
    # ein Fehlalarm bei jedem deutschen Text.
    set pdf [suNew]
    ::pdf4tcllib::unicode::safeText $pdf "\u00e4\u00f6\u00fc\u00df" -x 50 -y 100
    set n [::pdf4tcllib::unicode::substCount]
    $pdf destroy
    set n
} -result 0

test subst-1.5 {die Liste haelt zwoelf verschiedene fest} \
        -constraints {pdf lib} -body {
    # Sie soll sagen, WAS fehlt, nicht jedes Vorkommen protokollieren.
    set pdf [suNew]
    set txt ""
    for {set cp 0x2200} {$cp < 0x2220} {incr cp} {
        append txt [format %c $cp]
    }
    ::pdf4tcllib::unicode::safeText $pdf $txt -x 50 -y 100
    set r [::pdf4tcllib::unicode::substReport]
    $pdf destroy
    # Gezaehlt werden alle, festgehalten hoechstens zwoelf.
    list [expr {[dict get $r count] > 12}] [llength [dict get $r chars]]
} -result {1 12}

test subst-1.6 {resetSubst setzt beides zurueck} -constraints {pdf lib} \
        -body {
    set pdf [suNew]
    ::pdf4tcllib::unicode::safeText $pdf "\u03b1" -x 50 -y 100
    ::pdf4tcllib::unicode::resetSubst
    set r [::pdf4tcllib::unicode::substReport]
    $pdf destroy
    list [dict get $r count] [dict get $r chars]
} -result {0 {}}

test subst-1.7 {renderLatex laeuft ueber safeText} -constraints {pdf lib} \
        -body {
    # Eine Formel besteht ueberwiegend aus Zeichen, die eine
    # Standardschrift nicht hat. Vorher gingen die als "?" durch, ohne
    # Zaehler und ohne Wort.
    set pdf [suNew]
    ::pdf4tcllib::math::renderLatex $pdf 50 100 {\alpha \sum} -size 12
    set r [::pdf4tcllib::unicode::substReport]
    $pdf destroy
    list [dict get $r count] [dict get $r chars]
} -result {2 {U+03B1 U+2211}}

test subst-1.8 {mit passender Schrift zaehlt nichts} -constraints {pdf lib} \
        -body {
    # Die Gegenprobe: dieselbe Formel, aber die Schrift hat die Zeichen.
    if {[catch {::pdf4tcllib::fonts::init -cid 1}]} { return 0 }
    if {![::pdf4tcllib::fonts::hasTtf]} { return 0 }
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    ::pdf4tcllib::unicode::resetSubst
    ::pdf4tcllib::math::renderLatex $pdf 50 100 {\alpha \sum} -size 12
    set n [::pdf4tcllib::unicode::substCount]
    $pdf destroy
    set n
} -result 0

rename suNew {}

cleanupTests
