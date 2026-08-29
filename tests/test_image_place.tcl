# test_image_place.tcl -- image::place und image::gallery
#
# putImage zieht ein Bild auf -width mal -height, egal welches
# Seitenverhaeltnis es hat. Weicht es ab, verzerrt das Bild -- und
# niemand sagt es. place trifft stattdessen die Entscheidung, die eine
# Bibliothek treffen darf: einpassen, ausfuellen oder verzerren, und beim
# Ausfuellen von wo aus beschnitten wird.

package require tcltest
namespace import ::tcltest::*

testConstraint pdf [expr {![catch {package require pdf4tcl}]}]
testConstraint lib [expr {![catch {package require pdf4tcllib}]}]

catch {::pdf4tcllib::fonts::init}

# Ein Bild aus dem pdf4tcl-Beispielbestand, sonst wird uebersprungen.
set ::imgDatei ""
foreach k [list \
        [file join [file dirname [info script]] .. .. pdf4tcl examples smile.png] \
        /home/claude/tk/pdf4tcl/examples/smile.png] {
    if {[file readable $k]} { set ::imgDatei [file normalize $k]; break }
}
testConstraint bild [expr {$::imgDatei ne ""}]

proc imgNew {} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    return $pdf
}

test place-1.1 {contain passt ganz hinein} -constraints {pdf lib bild} -body {
    # 100x83 Pixel in einen Rahmen 200x100: die Hoehe ist knapper, also
    # bestimmt sie den Massstab, und die Breite bleibt darunter.
    set pdf [imgNew]
    set id [$pdf addImage $::imgDatei]
    lassign [::pdf4tcllib::image::place $pdf $id 50 500 200 100 -fit contain] \
            bx by bw bh
    $pdf destroy
    list [expr {$bw <= 200.01}] [expr {abs($bh - 100) < 0.01}]
} -result {1 1}

test place-1.2 {cover fuellt den Rahmen aus} -constraints {pdf lib bild} -body {
    # Belegt wird der ganze Rahmen; was uebersteht, faellt weg.
    set pdf [imgNew]
    set id [$pdf addImage $::imgDatei]
    set r [::pdf4tcllib::image::place $pdf $id 50 500 200 100 -fit cover]
    $pdf destroy
    set r
} -result {50 500 200 100}

test place-1.3 {stretch verzerrt, wie putImage es tut} \
        -constraints {pdf lib bild} -body {
    set pdf [imgNew]
    set id [$pdf addImage $::imgDatei]
    lassign [::pdf4tcllib::image::place $pdf $id 50 500 200 100 -fit stretch] \
            bx by bw bh
    $pdf destroy
    list $bw $bh
} -result {200 100}

test place-1.4 {der Anker verschiebt bei contain} -constraints {pdf lib bild} \
        -body {
    set pdf [imgNew]
    set id [$pdf addImage $::imgDatei]
    set nw [lindex [::pdf4tcllib::image::place $pdf $id 50 500 200 100 \
            -fit contain -anchor nw] 0]
    set se [lindex [::pdf4tcllib::image::place $pdf $id 50 500 200 100 \
            -fit contain -anchor se] 0]
    $pdf destroy
    # Links buendig steht das Bild am Rahmenrand, rechts buendig weiter
    # rechts.
    list [expr {abs($nw - 50) < 0.01}] [expr {$se > $nw}]
} -result {1 1}

test place-1.5 {ein Clip beschneidet, statt zu verzerren} \
        -constraints {pdf lib bild} -body {
    # Bei cover muss ein Clip-Pfad im Strom stehen, sonst laeuft das Bild
    # ueber den Rahmen hinaus in die Nachbarzelle.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    set id [$pdf addImage $::imgDatei]
    ::pdf4tcllib::image::place $pdf $id 50 500 200 100 -fit cover
    set mit [regexp {W\s+n} [$pdf get]]
    $pdf destroy
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    set id [$pdf addImage $::imgDatei]
    ::pdf4tcllib::image::place $pdf $id 50 500 200 100 -fit contain
    set ohne [regexp {W\s+n} [$pdf get]]
    $pdf destroy
    # contain braucht keinen Clip -- das Bild liegt ohnehin im Rahmen.
    list $mit $ohne
} -result {1 0}

test place-1.6 {-dpi meldet eine zu grobe Aufloesung} \
        -constraints {pdf lib bild} -body {
    set ::pdf4tcl::warnings {}
    set pdf [imgNew]
    set id [$pdf addImage $::imgDatei]
    ::pdf4tcllib::image::place $pdf $id 50 400 400 300 -fit contain -dpi 150
    $pdf destroy
    # Genau EINE Meldung: der Kern warnt hier ebenfalls, aber place
    # schaltet ihn fuer diesen Aufruf ab -- zwei Meldungen zur selben
    # Sache waeren eine zuviel.
    list [llength $::pdf4tcl::warnings] \
            [string match "*image::place*below 150*" \
                    [lindex $::pdf4tcl::warnings 0]]
} -result {1 1}

test place-1.7 {ein klein gesetztes Bild meldet nichts} \
        -constraints {pdf lib bild} -body {
    set ::pdf4tcl::warnings {}
    set pdf [imgNew]
    set id [$pdf addImage $::imgDatei]
    ::pdf4tcllib::image::place $pdf $id 50 400 40 40 -fit contain -dpi 150
    $pdf destroy
    llength $::pdf4tcl::warnings
} -result 0

test place-1.8 {unsinnige Angaben melden sich} -constraints {pdf lib bild} \
        -body {
    set pdf [imgNew]
    set id [$pdf addImage $::imgDatei]
    set res {}
    catch {::pdf4tcllib::image::place $pdf $id 50 500 200 100 -fit quatsch} e1
    catch {::pdf4tcllib::image::place $pdf $id 50 500 0 100} e2
    catch {::pdf4tcllib::image::place $pdf $id 50 500 200 100 -quatsch 1} e3
    $pdf destroy
    list [string match "*-fit must be*" $e1] \
            [string match "*must be positive*" $e2] \
            [string match "*unknown option -quatsch*" $e3]
} -result {1 1 1}

test place-1.9 {-alt macht daraus eine Figure} -constraints {pdf lib bild} \
        -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf tagged 1
    $pdf startPage
    set id [$pdf addImage $::imgDatei]
    ::pdf4tcllib::image::place $pdf $id 50 500 200 100 -alt "ein Gesicht"
    $pdf endPage
    set n [$pdf getUntaggedCount]
    set out [$pdf get]
    $pdf destroy
    list $n [regexp {ein Gesicht} $out]
} -result {0 1}

# ============================================================
# gallery
# ============================================================

test gallery-2.1 {das Raster bricht auf eine neue Seite um} \
        -constraints {pdf lib bild} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 30]
    $pdf tagged 1
    $pdf startPage
    set id [$pdf addImage $::imgDatei]
    set bilder {}
    for {set i 1} {$i <= 5} {incr i} {
        lappend bilder [list $id "Bild $i"]
    }
    # Vier je Seite, fuenf Bilder -> zwei Seiten.
    set n [::pdf4tcllib::image::gallery $pdf $bilder 0 0 535 700 \
            -cols 2 -rows 2]
    $pdf endPage
    set untagged [$pdf getUntaggedCount]
    $pdf destroy
    list $n $untagged
} -result {2 0}

test gallery-2.2 {Bild und Unterschrift stehen zusammen im Baum} \
        -constraints {pdf lib bild} -body {
    # Eine Caption INNERHALB der Figure -- sonst stehen zwei unverbundene
    # Dinge nebeneinander, und ein Leser sagt nicht, wozu der Text gehoert.
    set f [file join [file dirname [info script]] out zz-gallery.pdf]
    file mkdir [file dirname $f]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 30]
    $pdf tagged 1
    $pdf startPage
    set id [$pdf addImage $::imgDatei]
    ::pdf4tcllib::image::gallery $pdf [list [list $id "Unterschrift"]] \
            0 0 535 700 -cols 1 -rows 1
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf write -file $f
    $pdf destroy
    set fh [open $f rb]
    set d [read $fh]
    close $fh
    list $n [regexp {/S /Figure} $d] [regexp {/S /Caption} $d]
} -result {0 1 1}

test gallery-2.3 {eine lange Unterschrift wird kleiner gesetzt} \
        -constraints {pdf lib bild} -body {
    # Verkleinern statt kuerzen: bei einem Dateinamen entscheidet oft das
    # letzte Zeichen.
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 30 -compress 0]
    $pdf startPage
    set id [$pdf addImage $::imgDatei]
    ::pdf4tcllib::image::gallery $pdf \
            [list [list $id "eine sehr lange Bildunterschrift die nicht passt"]] \
            0 0 200 300 -cols 2 -rows 2 -fontsize 9
    set out [$pdf get]
    $pdf destroy
    # Die Schriftgroesse im Strom liegt unter der gewuenschten.
    set gr {}
    foreach l [split $out "\n"] {
        if {[regexp {^/\S+ ([0-9.]+) Tf} $l -> g]} { lappend gr $g }
    }
    expr {[llength $gr] > 0 && [lindex $gr end] < 9}
} -result 1

test gallery-2.4 {unsinniges Raster meldet sich} -constraints {pdf lib bild} \
        -body {
    set pdf [imgNew]
    set id [$pdf addImage $::imgDatei]
    catch {::pdf4tcllib::image::gallery $pdf [list $id] 0 0 500 500 -cols 0} e1
    catch {::pdf4tcllib::image::gallery $pdf [list $id] 0 0 500 500 -quatsch 1} e2
    $pdf destroy
    list [string match "*at least 1*" $e1] \
            [string match "*unknown option -quatsch*" $e2]
} -result {1 1}

rename imgNew {}

cleanupTests
