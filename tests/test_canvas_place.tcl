# test_canvas_place.tcl -- pdf4tclcanvas
#
# Gezeichnet wird nicht in diesem Modul: "$pdf canvas" kann das seit
# Langem. Wie bei pdf4tcltable und pdf4tcltreeview ist es ein Adapter,
# und geprueft wird deshalb, was er abnimmt:
#
#   - der Massstab. "$pdf canvas" zieht die Zeichnung auf -width mal
#     -height, egal welches Seitenverhaeltnis sie hat -- genau wie
#     putImage bei einem Bild, und genauso still.
#   - der Strukturbaum. Ein Canvas-Export hinterlaesst Loecher: gemessen
#     an vier Elementen drei offene Zeichenbefehle.

package require tcltest
namespace import ::tcltest::*

testConstraint pdf  [expr {![catch {package require pdf4tcl}]}]
testConstraint lib  [expr {![catch {package require pdf4tcllib}]}]
testConstraint cvpk [expr {![catch {package require pdf4tclcanvas}]}]
testConstraint tk   [expr {![catch {package require Tk}] && ![catch {
    canvas .cvProbe ; destroy .cvProbe}]}]

catch {::pdf4tcllib::fonts::init}

proc cvNew {} {
    catch {destroy .cvT}
    canvas .cvT -width 300 -height 200 -bg white
    # bbox 20..260 x 20..180, also 240 breit und 160 hoch: Verhaeltnis 3:2
    .cvT create rectangle 20 20 120 80 -fill lightblue -outline black
    .cvT create oval 140 20 260 80 -fill lightyellow
    .cvT create line 20 120 260 120 -width 2
    .cvT create text 140 170 -text "Ein Schaubild" -font {Helvetica 12}
    pack .cvT
    update idletasks
    return .cvT
}

test cv-1.1 {contain haelt das Seitenverhaeltnis} \
        -constraints {pdf lib cvpk tk} -body {
    # Eine bbox von 3:2 in einen Rahmen von 400x150: die Hoehe ist
    # knapper, sie bestimmt den Massstab, und die Breite bleibt darunter.
    set c [cvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    lassign [::pdf4tcllib::canvas::place $pdf $c 0 0 400 150] zx zy zw zh
    $pdf destroy
    destroy .cvT
    list [expr {$zw <= 400.01}] [expr {abs($zh - 150) < 0.01}]
} -result {1 1}

test cv-1.2 {stretch zieht auf den Rahmen} -constraints {pdf lib cvpk tk} \
        -body {
    set c [cvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set r [::pdf4tcllib::canvas::place $pdf $c 0 0 400 150 -fit stretch]
    $pdf destroy
    destroy .cvT
    lrange $r 2 3
} -result {400 150}

test cv-1.3 {der Anker verschiebt im Rahmen} -constraints {pdf lib cvpk tk} \
        -body {
    set c [cvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set nw [lindex [::pdf4tcllib::canvas::place $pdf $c 0 0 400 150 \
            -anchor nw] 0]
    set se [lindex [::pdf4tcllib::canvas::place $pdf $c 0 0 400 150 \
            -anchor se] 0]
    $pdf destroy
    destroy .cvT
    list [expr {abs($nw) < 0.01}] [expr {$se > $nw}]
} -result {1 1}

test cv-1.4 {mit -alt eine Figure, ohne ein Artefakt -- beides ohne Loch} \
        -constraints {pdf lib cvpk tk} -body {
    # Eine Zeichnung ohne Beschreibung ist fuer ein Vorleseprogramm
    # nichts wert; ein Loch im Baum ist aber schlimmer als Zierrat.
    set res {}
    foreach alt {"das Schaubild" ""} {
        set c [cvNew]
        set pdf [::pdf4tcl::new %AUTO% -paper a4]
        $pdf tagged 1
        $pdf startPage
        ::pdf4tcllib::canvas::place $pdf $c 0 0 400 150 -alt $alt
        $pdf endPage
        lappend res [$pdf getUntaggedCount]
        $pdf destroy
        destroy .cvT
    }
    set res
} -result {0 0}

test cv-1.5 {ohne das Modul bleiben Loecher} -constraints {pdf lib cvpk tk} \
        -body {
    # Die Gegenprobe, die den Zweck belegt: derselbe Canvas ueber
    # "$pdf canvas" allein.
    set c [cvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    $pdf startPage
    $pdf canvas $c -bbox [$c bbox all] -x 0 -y 0 -width 300 -height 200
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    destroy .cvT
    expr {$n > 0}
} -result 1

test cv-1.6 {die Unterschrift steht in der Figure} \
        -constraints {pdf lib cvpk tk} -body {
    set c [cvNew]
    set f [file join [file dirname [info script]] out zz-canvas.pdf]
    file mkdir [file dirname $f]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::canvas::place $pdf $c 0 0 400 200 \
            -caption "Abbildung 1: der Ablauf"
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf write -file $f
    $pdf destroy
    destroy .cvT
    set fh [open $f rb] ; set d [read $fh] ; close $fh
    # Ohne -alt, aber MIT Unterschrift: die Unterschrift dient als
    # Beschreibung, also eine Figure mit Caption darin.
    list $n [regexp {/S /Figure} $d] [regexp {/S /Caption} $d]
} -result {0 1 1}

test cv-1.7 {die Unterschrift nimmt Hoehe weg} -constraints {pdf lib cvpk tk} \
        -body {
    # Sonst laege sie ueber der Zeichnung.
    set c [cvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set ohne [lindex [::pdf4tcllib::canvas::place $pdf $c 0 0 400 200] 3]
    set mit  [lindex [::pdf4tcllib::canvas::place $pdf $c 0 0 400 200 \
            -caption "x" -captionH 20] 3]
    $pdf destroy
    destroy .cvT
    expr {$mit < $ohne}
} -result 1

test cv-1.8 {ein leerer Canvas ist kein Fehler} -constraints {pdf lib cvpk tk} \
        -body {
    # "$c bbox all" gibt dann nichts zurueck, und "$pdf canvas" braecht
    # ab. Genommen wird stattdessen die Widgetgroesse.
    catch {destroy .cvLeer}
    canvas .cvLeer -width 200 -height 100
    pack .cvLeer
    update idletasks
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    set rc [catch {::pdf4tcllib::canvas::place $pdf .cvLeer 0 0 300 200} r]
    $pdf destroy
    destroy .cvLeer
    list $rc [llength $r]
} -result {0 4}

test cv-1.9 {fitPage nimmt den Satzspiegel} -constraints {pdf lib cvpk tk} \
        -body {
    set c [cvNew]
    set ctx [::pdf4tcllib::page::context a4]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    lassign [::pdf4tcllib::canvas::fitPage $pdf $c $ctx -alt "ganz"] zx zy zw zh
    $pdf destroy
    destroy .cvT
    # Nicht breiter als der Satzspiegel, und innerhalb davon.
    list [expr {$zw <= [dict get $ctx SW] + 0.01}] \
            [expr {$zx >= [dict get $ctx SX] - 0.01}]
} -result {1 1}

test cv-1.10 {unsinnige Angaben melden sich} -constraints {pdf lib cvpk tk} \
        -body {
    set c [cvNew]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::canvas::place $pdf $c 0 0 400 150 -fit quatsch} e1
    catch {::pdf4tcllib::canvas::place $pdf $c 0 0 0 150} e2
    catch {::pdf4tcllib::canvas::place $pdf $c 0 0 400 150 -quatsch 1} e3
    catch {::pdf4tcllib::canvas::place $pdf .gibtsNicht 0 0 400 150} e4
    $pdf destroy
    destroy .cvT
    list [string match "*-fit must be*" $e1] \
            [string match "*must be positive*" $e2] \
            [string match "*unknown option -quatsch*" $e3] \
            [string match "*no such widget*" $e4]
} -result {1 1 1 1}

rename cvNew {}

cleanupTests
