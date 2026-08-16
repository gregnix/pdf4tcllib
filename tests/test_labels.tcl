# test_labels.tcl -- Tests fuer pdf4tcllib::labels
#
# Das Modul hatte bis hierher keine einzige Testdatei. Die Geometrie ist
# reine Rechnung und laesst sich pruefen, ohne ein PDF anzusehen -- und
# genau dort faellt auf, wenn eine Position neben dem Bogen landet.

package require tcltest
namespace import ::tcltest::*

testConstraint labels [expr {![catch {package require pdf4tcllabels}]}]
testConstraint pdf    [expr {![catch {package require pdf4tcl}]}]

# ============================================================
# Katalog
# ============================================================

test labels-sheets-1 "die ausgelieferten Formate sind da" -constraints labels -body {
    set s [::pdf4tcllib::labels::sheets]
    set missing {}
    foreach n {3427 3474 3475 3483 4737} {
        if {$n ni $s} { lappend missing $n }
    }
    return $missing
} -result {}

test labels-sheets-2 "sheets liefert sortiert" -constraints labels -body {
    set s [::pdf4tcllib::labels::sheets]
    expr {$s eq [lsort $s]}
} -result 1

test labels-sheet-1 "unbekanntes Format wird abgelehnt" -constraints labels -body {
    catch {::pdf4tcllib::labels::sheet gibtsnicht} e
    string match "unknown label sheet*" $e
} -result 1

test labels-sheet-2 "perSheet ist cols * rows" -constraints labels -body {
    set bad {}
    foreach n [::pdf4tcllib::labels::sheets] {
        set g [::pdf4tcllib::labels::sheet $n]
        set want [expr {[dict get $g cols] * [dict get $g rows]}]
        if {[dict get $g perSheet] != $want} { lappend bad $n }
    }
    return $bad
} -result {}

test labels-sheet-3 "Masse kommen in Punkt UND in Millimeter" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet 3474]
    list [dict get $g wmm] [format %.2f [dict get $g w]]
} -result {70.0 198.43}

# Der Bogen muss auf das Blatt passen. Waere hier ein Zahlendreher im
# Katalog, faellt er erst beim Drucken auf -- und dann auf Papier.
test labels-sheet-4 "jedes Format passt auf sein Blatt" -constraints labels -body {
    set a4w [::pdf4tcllib::units::mm 210.0]
    set a4h [::pdf4tcllib::units::mm 297.0]
    set bad {}
    foreach n [::pdf4tcllib::labels::sheets] {
        set g [::pdf4tcllib::labels::sheet $n]
        if {[dict get $g paper] ne "a4"} continue
        set right [expr {[dict get $g left]
                       + ([dict get $g cols] - 1) * [dict get $g pitchx]
                       + [dict get $g w]}]
        set bottom [expr {[dict get $g top]
                        + ([dict get $g rows] - 1) * [dict get $g pitchy]
                        + [dict get $g h]}]
        if {$right > $a4w + 0.01 || $bottom > $a4h + 0.01} {
            lappend bad [list $n [format %.1f $right] [format %.1f $bottom]]
        }
    }
    return $bad
} -result {}

# Der Teilungsabstand steht je Format im Katalog und wird nicht abgeleitet.
# Bei Boegen mit Abstand ist er groesser als die Etikettenbreite -- 4737 ist
# der Fall, an dem eine Ableitung aus der Breite falsch waere.
test labels-sheet-5 "4737 hat Abstaende, pitchx > w" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet 4737]
    expr {[dict get $g pitchxmm] > [dict get $g wmm]}
} -result 1

# ============================================================
# define
# ============================================================

test labels-define-1 "eigenes Format anlegen und benutzen" -constraints labels -body {
    ::pdf4tcllib::labels::define zz-test {w 48.5 h 25.4 cols 4 rows 10
        left 8.0 top 21.5 pitchx 50.0 pitchy 25.4}
    set g [::pdf4tcllib::labels::sheet zz-test]
    list [dict get $g perSheet] [dict get $g paper] [dict get $g desc]
} -result {40 a4 zz-test}

test labels-define-2 "fehlende Pflichtangabe wird gemeldet" -constraints labels -body {
    catch {::pdf4tcllib::labels::define zz-bad {w 10 h 10 cols 2}} e
    string match "*missing*" $e
} -result 1

# ============================================================
# place -- die Stelle, an der eine Position neben dem Bogen landen kann
# ============================================================

test labels-place-1 "erste Position ist die linke obere Ecke" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet 3474]
    lassign [::pdf4tcllib::labels::place $g 0] x y
    list [format %.1f $x] [format %.1f $y]
} -result {0.0 0.0}

test labels-place-2 "zweite Position ist eine Spalte weiter" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet 3474]
    lassign [::pdf4tcllib::labels::place $g 1] x y
    format %.1f [expr {$x - [dict get $g pitchx]}]
} -result {0.0}

test labels-place-3 "nach cols beginnt die naechste Zeile" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet 3474]
    lassign [::pdf4tcllib::labels::place $g 3] x y
    list [format %.1f $x] [format %.1f [expr {$y - [dict get $g pitchy]}]]
} -result {0.0 0.0}

test labels-place-4 "letzte Position liegt noch auf dem Bogen" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet 3474]
    lassign [::pdf4tcllib::labels::place $g [expr {[dict get $g perSheet] - 1}]] x y
    expr {$y + [dict get $g h] <= [::pdf4tcllib::units::mm 297.0] + 0.01}
} -result 1

# Der Grund fuer diese Datei. render prueft -start und -only sauber gegen
# perSheet; place selbst ist exportiert, wird in der Doku direkt gezeigt und
# lieferte fuer Position 24 eines 24er-Bogens stillschweigend Koordinaten in
# der neunten Zeile eines achtzeiligen Bogens (y = 839.1 pt).
test labels-place-5 "Position jenseits des Bogens wird abgelehnt" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet 3474]
    catch {::pdf4tcllib::labels::place $g [dict get $g perSheet]} e
    string match "*not a position on sheet*" $e
} -result 1

test labels-place-6 "negative Position wird abgelehnt" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet 3474]
    catch {::pdf4tcllib::labels::place $g -1} e
    string match "*not a position on sheet*" $e
} -result 1

test labels-place-7 "keine Zahl wird abgelehnt" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet 3474]
    catch {::pdf4tcllib::labels::place $g zwei} e
    string match "*not a position on sheet*" $e
} -result 1

# ============================================================
# Textanpassung -- braucht ein pdf-Objekt zum Messen
# ============================================================

proc labelsTestPdf {} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    $pdf setFont 10 Helvetica
    return $pdf
}

test labels-fit-1 "kurzer Text behaelt seine Groesse" -constraints {labels pdf} -body {
    set pdf [labelsTestPdf]
    set s [::pdf4tcllib::labels::fitSize $pdf Helvetica "Hi" 200.0 10]
    $pdf destroy
    return $s
} -result 10

test labels-fit-2 "langer Text wird kleiner, aber nicht unter das Minimum" \
        -constraints {labels pdf} -body {
    set pdf [labelsTestPdf]
    set s [::pdf4tcllib::labels::fitSize $pdf Helvetica \
            "Ein sehr langer Text, der in diese Box nicht hineinpasst" 40.0 10 6]
    $pdf destroy
    expr {$s >= 6 && $s < 10}
} -result 1

test labels-fit-3 "das Ergebnis passt wirklich, wo es passen kann" \
        -constraints {labels pdf} -body {
    set pdf [labelsTestPdf]
    set txt "Mittellanger Text"
    set s [::pdf4tcllib::labels::fitSize $pdf Helvetica $txt 120.0 12]
    $pdf setFont $s Helvetica
    set w [$pdf getStringWidth $txt]
    $pdf destroy
    expr {$w <= 120.0}
} -result 1

test labels-wrap-1 "Umbruch an Leerzeichen, jede Zeile passt" \
        -constraints {labels pdf} -body {
    set pdf [labelsTestPdf]
    set lines [::pdf4tcllib::labels::wrap $pdf \
            "Musterstrasse 12 in einer sehr langen Ortschaft" 90.0]
    set bad 0
    foreach l $lines {
        if {[$pdf getStringWidth $l] > 90.0 && [llength [split $l " "]] > 1} {
            incr bad
        }
    }
    $pdf destroy
    list [expr {[llength $lines] > 1}] $bad
} -result {1 0}

# Ein einzelnes zu langes Wort bleibt ganz. Eine halbierte Postleitzahl
# waere schlimmer als eine zu breite Zeile.
test labels-wrap-2 "ein zu langes Wort wird nicht zerschnitten" \
        -constraints {labels pdf} -body {
    set pdf [labelsTestPdf]
    set lines [::pdf4tcllib::labels::wrap $pdf \
            "Donaudampfschiffahrtsgesellschaftskapitaen" 40.0]
    $pdf destroy
    list [llength $lines] [lindex $lines 0]
} -result {1 Donaudampfschiffahrtsgesellschaftskapitaen}

test labels-wrap-3 "leerer Text ergibt keine Zeile" -constraints {labels pdf} -body {
    set pdf [labelsTestPdf]
    set lines [::pdf4tcllib::labels::wrap $pdf "" 90.0]
    $pdf destroy
    llength $lines
} -result 0

test labels-ellipsize-1 "was passt, bleibt unveraendert" -constraints {labels pdf} -body {
    set pdf [labelsTestPdf]
    set out [::pdf4tcllib::labels::ellipsize $pdf "Kurz" 200.0]
    $pdf destroy
    return $out
} -result "Kurz"

test labels-ellipsize-2 "gekuerzter Text passt und endet im Auslassungszeichen" \
        -constraints {labels pdf} -body {
    set pdf [labelsTestPdf]
    set txt "Eine Bemerkung, die deutlich zu lang fuer das Feld ist"
    set out [::pdf4tcllib::labels::ellipsize $pdf $txt 60.0]
    set w [$pdf getStringWidth $out]
    $pdf destroy
    list [expr {$w <= 60.0}] [string index $out end] [expr {$out ne $txt}]
} -result [list 1 "\u2026" 1]

test labels-ellipsize-3 "eigenes Ende statt Auslassungszeichen" \
        -constraints {labels pdf} -body {
    set pdf [labelsTestPdf]
    set out [::pdf4tcllib::labels::ellipsize $pdf \
            "Eine Bemerkung, die deutlich zu lang fuer das Feld ist" 60.0 ">>"]
    $pdf destroy
    string match "*>>" $out
} -result 1

# ============================================================
# render -- Grenzen und Bogenwechsel
# ============================================================

test labels-render-1 "24 Etiketten sind ein Bogen, 25 sind zwei" \
        -constraints {labels pdf} -body {
    set out {}
    foreach n {24 25} {
        set pdf [::pdf4tcl::new %AUTO% -paper a4]
        set recs {}
        for {set i 0} {$i < $n} {incr i} { lappend recs "Etikett $i" }
        lappend out [::pdf4tcllib::labels::render $pdf 3474 $recs \
                {x y w h rec} { } ]
        $pdf destroy
    }
    return $out
} -result {1 2}

test labels-render-2 "-start jenseits des Bogens wird gemeldet" \
        -constraints {labels pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    catch {::pdf4tcllib::labels::render $pdf 3474 {a} {x y w h rec} { } -start 24} e
    $pdf destroy
    string match "*-start must be between*" $e
} -result 1

test labels-render-3 "-only mit zu wenigen Positionen wird gemeldet" \
        -constraints {labels pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    catch {::pdf4tcllib::labels::render $pdf 3474 {a b c} {x y w h rec} { } \
            -only {0 1}} e
    $pdf destroy
    string match "*position(s)*record(s)*" $e
} -result 1

test labels-render-4 "das Skript bekommt Koordinaten und Groesse des Etiketts" \
        -constraints {labels pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set seen {}
    ::pdf4tcllib::labels::render $pdf 3474 {A B} {x y w h rec} {
        lappend seen [list [format %.1f $x] [format %.1f $y] \
                [format %.1f $w] [format %.1f $h] $rec]
    }
    $pdf destroy
    return $seen
} -result {{0.0 0.0 198.4 104.9 A} {198.4 0.0 198.4 104.9 B}}

test labels-render-5 "-start laesst die ersten Positionen frei" \
        -constraints {labels pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set seen {}
    ::pdf4tcllib::labels::render $pdf 3474 {A} {x y w h rec} {
        lappend seen [list [format %.1f $x] [format %.1f $y]]
    } -start 4
    $pdf destroy
    return $seen
} -result {{198.4 104.9}}

# Ein Lauf, der wirklich schreibt -- damit die Geometrie nicht nur gerechnet,
# sondern auch benutzt wird.
test labels-render-6 "der Bogen wird geschrieben und ist lesbar" \
        -constraints {labels pdf} -body {
    set out [file join [file dirname [info script]] out zz-labels.pdf]
    file mkdir [file dirname $out]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set recs {}
    for {set i 1} {$i <= 6} {incr i} { lappend recs "Posten $i" }
    ::pdf4tcllib::labels::render $pdf 3474 $recs {x y w h rec} {
        $pdf setFont 10 Helvetica
        $pdf text $rec -x [expr {$x + 8}] -y [expr {$y + 20}]
    }
    $pdf write -file $out
    $pdf destroy
    set size [file size $out]
    file delete $out
    expr {$size > 500}
} -result 1

# ============================================================
# Rollendrucker -- ein Etikett je Seite, das Papier IST das Etikett
# ============================================================

test labels-roll-1 "die Rollenformate sind im Katalog" -constraints labels -body {
    set s [::pdf4tcllib::labels::sheets]
    set missing {}
    foreach n {dymo-99012 dymo-11354 zebra-100x150 brother-62x100} {
        if {$n ni $s} { lappend missing $n }
    }
    return $missing
} -result {}

test labels-roll-2 "ein Etikett je Bogen" -constraints labels -body {
    set bad {}
    foreach n {dymo-99012 dymo-11354 zebra-100x150 brother-62x100} {
        set g [::pdf4tcllib::labels::sheet $n]
        if {[dict get $g perSheet] != 1} { lappend bad $n }
    }
    return $bad
} -result {}

# paper ist hier keine Bezeichnung, sondern die Groesse in Punkten -- genau
# das Paar, das pdf4tcl fuer -paper nimmt. Der Aufrufer merkt den
# Unterschied nicht: er reicht [dict get $geo paper] so oder so weiter.
test labels-roll-3 "paper ist die Etikettengroesse in Punkten" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet dymo-99012]
    set p [dict get $g paper]
    list [llength $p] [format %.1f [lindex $p 0]] [format %.1f [lindex $p 1]]
} -result [list 2 [format %.1f [::pdf4tcllib::units::mm 89.0]] \
                  [format %.1f [::pdf4tcllib::units::mm 36.0]]]

test labels-roll-4 "drei Etiketten ergeben drei Seiten der richtigen Groesse" \
        -constraints {labels pdf} -body {
    set out [file join [file dirname [info script]] out zz-roll.pdf]
    file mkdir [file dirname $out]
    set pdf [::pdf4tcl::new %AUTO%]
    set n [::pdf4tcllib::labels::render $pdf dymo-99012 {A B C} {x y w h rec} {
        $pdf setFont 10 Helvetica
        $pdf text "Etikett $rec" -x [expr {$x + 8}] -y [expr {$y + 20}]
    }]
    $pdf write -file $out
    $pdf destroy
    set info ""
    catch {set info [exec pdfinfo $out]}
    file delete $out
    regexp {Pages:\s+(\d+)} $info -> pages
    regexp {Page size:\s+([0-9.]+) x ([0-9.]+)} $info -> pw ph
    list $n $pages [format %.0f $pw] [format %.0f $ph]
} -result {3 3 252 102}

test labels-roll-5 "place liefert auf der Rolle nur Position 0" -constraints labels -body {
    set g [::pdf4tcllib::labels::sheet zebra-100x150]
    set ok [::pdf4tcllib::labels::place $g 0]
    catch {::pdf4tcllib::labels::place $g 1} e
    list $ok [string match "*not a position on sheet*" $e]
} -result {{0.0 0.0} 1}

test labels-roll-6 "ein eigenes Rollenformat mit mehr als einem Etikett wird abgelehnt" \
        -constraints labels -body {
    catch {::pdf4tcllib::labels::define zz-roll {w 50 h 30 cols 2 rows 1
        left 0 top 0 pitchx 50 pitchy 30 paper roll}} e
    string match "*cols and rows must both be 1*" $e
} -result 1


cleanupTests
