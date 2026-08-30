# test_labels_clip.tcl -- nichts darf das Etikett verlassen
#
# Ein Name, der breiter ist als das Etikett, lief bisher auf das
# Nachbaretikett. Gemessen am gerenderten Bild, Format 3474 (198,4 pt
# breit), 65 Zeichen bei 11pt: Tinte bis 363,6 pt ohne Beschnitt, bis
# 198,0 pt mit. Auf dem Bildschirm faellt das nicht auf, auf dem Bogen
# kostet es die Charge.
#
# fitSize, wrap und ellipsize gibt es laengst -- aber sie helfen nur dem,
# der daran denkt. -clip 1 ist die Zusicherung, dass es auch sonst nicht
# passieren kann.

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
testConstraint lbl [expr {![catch {package require pdf4tcllabels}]}]

catch {::pdf4tcllib::fonts::init}

set ::lbLang "Bundesausbildungsfoerderungsgesetz-Sachbearbeitung Nord-West"

proc lbBaue {clip} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    $pdf setFont 11 [::pdf4tcllib::fonts::fontSans]
    $pdf endPage
    ::pdf4tcllib::labels::render $pdf 3474 [list $::lbLang] {x y w h rec} {
        $pdf text $rec -x [expr {$x + 4}] -y [expr {$y + 14}]
    } -clip $clip
    set out [$pdf get]
    $pdf destroy
    return $out
}

test lbclip-1.1 {-clip 1 schreibt einen Beschnittpfad} \
        -constraints {pdf lib lbl} -body {
    set out [lbBaue 1]
    # q ... W n ... Q -- der Pfad gilt nur bis zum grestore, also nur
    # fuer dieses eine Etikett.
    list [regexp {W\nn} $out] [regexp {\nq\n} $out] [regexp {\nQ\n} $out]
} -result {1 1 1}

test lbclip-1.2 {ohne -clip keiner} -constraints {pdf lib lbl} -body {
    set out [lbBaue 0]
    regexp {W\nn} $out
} -result 0

test lbclip-1.3 {der Beschnitt umschliesst genau das Etikett} \
        -constraints {pdf lib lbl} -body {
    # Nicht die Seite und nicht der Textbereich: das Etikett.
    set geo [::pdf4tcllib::labels::sheet 3474]
    set w [dict get $geo w]
    set h [dict get $geo h]
    set out [lbBaue 1]
    # Der Pfad besteht aus m und vier l; die Breite ist die Differenz der
    # x-Werte.
    set xs {}
    foreach l [split $out "\n"] {
        if {[regexp {^([-0-9.]+) ([-0-9.]+) [ml]$} $l -> x y]} { lappend xs $x }
    }
    if {![llength $xs]} { return "kein Pfad" }
    set breite [expr {[::tcl::mathfunc::max {*}$xs]
            - [::tcl::mathfunc::min {*}$xs]}]
    expr {abs($breite - $w) < 0.01}
} -result 1

test lbclip-1.4 {die Vorgabe ist aus} -constraints {pdf lib lbl} -body {
    # Ein Beschnitt, den niemand verlangt hat, waere eine stille
    # Verhaltensaenderung fuer jeden bestehenden Aufruf.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    $pdf setFont 11 [::pdf4tcllib::fonts::fontSans]
    $pdf endPage
    ::pdf4tcllib::labels::render $pdf 3474 [list $::lbLang] {x y w h rec} {
        $pdf text $rec -x [expr {$x + 4}] -y [expr {$y + 14}]
    }
    set out [$pdf get]
    $pdf destroy
    regexp {W\nn} $out
} -result 0

test lbclip-1.5 {eine unbekannte Option meldet sich weiterhin} \
        -constraints {pdf lib lbl} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    catch {::pdf4tcllib::labels::render $pdf 3474 {a} {x y w h rec} {} \
            -quatsch 1} e
    $pdf destroy
    string match "*unknown option*-quatsch*" $e
} -result 1

test lbclip-1.6 {der Strukturbaum bleibt heil} -constraints {pdf lib lbl} \
        -body {
    # gsave/grestore um den Skriptaufruf darf die Auszeichnung nicht
    # zerreissen -- Sect steht aussen, der Beschnitt innen.
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    $pdf startPage
    $pdf setFont 11 [::pdf4tcllib::fonts::fontSans]
    $pdf endPage
    ::pdf4tcllib::labels::render $pdf 3474 {eins zwei} {x y w h rec} {
        $pdf text $rec -x [expr {$x + 4}] -y [expr {$y + 14}]
    } -clip 1
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

rename lbBaue {}

cleanupTests
