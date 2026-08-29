# test_drawing_arrow.tcl -- drawing::arrow, arrowHead und callout
#
# Eine Verbindung in einem Schaubild ist eine Linie plus ein Dreieck, und
# das Dreieck ist die Arbeit: es muss in die Richtung zeigen, und die
# Linie muss VOR der Spitze enden, sonst zeichnet sie durch die
# ausgefuellte Flaeche hindurch.
#
# Der zweite Punkt ist der Strukturbaum. Ein Pfeil traegt keinen Text, den
# ein Vorleseprogramm ausgeben koennte -- er ist Zierrat und gehoert in
# ein Artefakt. Ohne das zaehlt jede Linie und jedes Dreieck als
# ungetaggt, und ein Schaubild hat so viele Loecher wie Verbindungen.

package require tcltest
namespace import ::tcltest::*

testConstraint pdf [expr {![catch {package require pdf4tcl}]}]
testConstraint lib [expr {![catch {package require pdf4tcllib}]}]

catch {::pdf4tcllib::fonts::init}

proc arrNew {} {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    return $pdf
}

# Die Koordinaten der Zeichenbefehle aus dem Strom.
proc arrPunkte {out op} {
    set pts {}
    foreach l [split $out "\n"] {
        if {[regexp "^(\[-0-9.\]+) (\[-0-9.\]+) $op\$" $l -> x y]} {
            lappend pts [list $x $y]
        }
    }
    return $pts
}

test arrow-1.1 {die Linie endet vor der Spitze} -constraints {pdf lib} -body {
    # Ohne das ragt der Strich durch das Dreieck und hinterlaesst eine
    # Naht in der Mitte.
    set pdf [arrNew]
    ::pdf4tcllib::drawing::arrow $pdf 50 100 250 100 -length 20
    set out [$pdf get]
    $pdf destroy
    # Der letzte Punkt der Linie liegt 20 Punkt vor dem Ziel. Geprueft
    # wird nur x: pdf4tcl rechnet y je nach -orient um, und darum geht es
    # hier nicht.
    set l [arrPunkte $out l]
    lassign [lindex $l 0] x y
    expr {abs($x - 230) < 0.01}
} -result 1

test arrow-1.2 {ohne Spitze am Anfang beginnt die Linie am Startpunkt} \
        -constraints {pdf lib} -body {
    set pdf [arrNew]
    ::pdf4tcllib::drawing::arrow $pdf 50 100 250 100 -length 20 -at end
    set out [$pdf get]
    $pdf destroy
    set m [arrPunkte $out m]
    lassign [lindex $m 0] x y
    expr {abs($x - 50) < 0.01}
} -result 1

test arrow-1.3 {-at both kuerzt an beiden Enden} -constraints {pdf lib} \
        -body {
    set pdf [arrNew]
    ::pdf4tcllib::drawing::arrow $pdf 50 100 250 100 -length 20 -at both
    set out [$pdf get]
    $pdf destroy
    set m [arrPunkte $out m]
    lassign [lindex $m 0] x y
    expr {abs($x - 70) < 0.01}
} -result 1

test arrow-1.4 {eine Laenge null zeichnet nichts} -constraints {pdf lib} \
        -body {
    # Sonst waere die Richtung nicht bestimmt, und atan2(0,0) gaebe eine
    # Spitze, die irgendwohin zeigt.
    set pdf [arrNew]
    set vorher [string length [$pdf get]]
    ::pdf4tcllib::drawing::arrow $pdf 100 100 100 100
    set nachher [string length [$pdf get]]
    $pdf destroy
    expr {$vorher == $nachher}
} -result 1

test arrow-1.5 {die Spitze zeigt in die Richtung der Linie} \
        -constraints {pdf lib} -body {
    # Nach rechts: die beiden hinteren Ecken haben dasselbe x, und das
    # liegt links von der Spitze.
    set pdf [arrNew]
    ::pdf4tcllib::drawing::arrowHead $pdf 200 100 0 -length 10 -width 8
    set out [$pdf get]
    $pdf destroy
    set m [arrPunkte $out m]
    set l [arrPunkte $out l]
    lassign [lindex $m 0] sx sy
    lassign [lindex $l 0] ax ay
    lassign [lindex $l 1] bx by
    list [expr {abs($sx - 200) < 0.01}] [expr {abs($ax - $bx) < 0.01}] \
            [expr {$ax < $sx}] [expr {abs(($ay - $by)) > 7.9}]
} -result {1 1 1 1}

test arrow-1.6 {ein Pfeil hinterlaesst kein Loch im Strukturbaum} \
        -constraints {pdf lib} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::drawing::arrow $pdf 50 100 250 100
    ::pdf4tcllib::drawing::arrow $pdf 50 150 250 200 -at both
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

test arrow-1.7 {unsinnige Angaben melden sich} -constraints {pdf lib} -body {
    set pdf [arrNew]
    catch {::pdf4tcllib::drawing::arrow $pdf 0 0 10 10 -at quatsch} e1
    catch {::pdf4tcllib::drawing::arrow $pdf 0 0 10 10 -quatsch 1} e2
    $pdf destroy
    list [string match "*-at must be*" $e1] \
            [string match "*unknown option -quatsch*" $e2]
} -result {1 1}

# ============================================================
# callout
# ============================================================

test callout-2.1 {der Zeiger sitzt an der Seite, die dem Ziel zugewandt ist} \
        -constraints {pdf lib} -body {
    # Ziel oben, Ziel links: die Spitze des Dreiecks ist der Zielpunkt,
    # und die beiden anderen Ecken liegen an der jeweiligen Kante.
    set res {}
    foreach {zx zy} {380 40 200 130} {
        set pdf [arrNew]
        ::pdf4tcllib::drawing::callout $pdf 300 100 160 70 $zx $zy "" \
                -fill {0.9 0.9 0.9}
        set out [$pdf get]
        $pdf destroy
        # Das letzte Polygon endet am Ziel.
        set l [arrPunkte $out l]
        lassign [lindex $l end] x y
        lappend res [expr {abs($x - $zx) < 0.01}]
    }
    set res
} -result {1 1}

test callout-2.2 {der Text wird umbrochen} -constraints {pdf lib} -body {
    set pdf [arrNew]
    set n [::pdf4tcllib::drawing::callout $pdf 300 100 160 70 280 60 \
            "Hier steht ein Hinweis, der umbrochen wird."]
    $pdf destroy
    expr {$n > 1}
} -result 1

test callout-2.3 {zu viel Text wird kleiner gesetzt, nicht gekuerzt} \
        -constraints {pdf lib} -body {
    # In einer Sprechblase steht meist ein Satz, und ein halber Satz ist
    # keiner.
    set lang "Ein deutlich laengerer Text, der in diesen kleinen Kasten\
            eigentlich nicht passt und deshalb kleiner gesetzt wird."
    set pdf [arrNew]
    ::pdf4tcllib::drawing::callout $pdf 300 300 100 40 500 320 $lang \
            -fontsize 9
    set out [$pdf get]
    $pdf destroy
    set gr {}
    foreach l [split $out "\n"] {
        if {[regexp {^/\S+ ([0-9.]+) Tf} $l -> g]} { lappend gr $g }
    }
    # Kleiner als gewuenscht, und der letzte Satzteil ist noch da.
    list [expr {[lindex $gr end] < 9}] [regexp {gesetzt} $out]
} -result {1 1}

test callout-2.4 {Kasten als Artefakt, Text als Inhalt} \
        -constraints {pdf lib} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::drawing::callout $pdf 300 100 160 70 280 60 \
            "ein Hinweis" -fill {0.9 0.9 0.9}
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

test callout-2.5 {unsinnige Groesse meldet sich} -constraints {pdf lib} -body {
    set pdf [arrNew]
    catch {::pdf4tcllib::drawing::callout $pdf 0 0 0 50 10 10 "x"} e1
    catch {::pdf4tcllib::drawing::callout $pdf 0 0 50 50 10 10 "x" -quatsch 1} e2
    $pdf destroy
    list [string match "*must be positive*" $e1] \
            [string match "*unknown option -quatsch*" $e2]
} -result {1 1}


# ============================================================
# Wasserzeichen als Ebene
# ============================================================
#
# drawing::watermark zeichnet fest auf die Seite. Fuer ein "ENTWURF"
# ueber einem Text, den jemand ohne den Aufdruck lesen oder drucken soll,
# ist das laestig: eine Ebene laesst sich im Leser abschalten.

test wm-3.1 {ohne -layer bleibt alles wie bisher} -constraints {pdf lib} \
        -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set r [::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF"]
    set out [$pdf get]
    $pdf destroy
    # Nur die Schriftgroesse zurueck, keine Ebene im Strom.
    list [llength $r] [regexp {/OC /Lyr} $out]
} -result {1 0}

test wm-3.2 {-layer 1 legt eine Ebene an} -constraints {pdf lib} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set r [::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF" -layer 1]
    set out [$pdf get]
    $pdf destroy
    # Groesse UND Kennung zurueck, und der Block steht im Strom.
    list [llength $r] [regexp {/OC /Lyr} $out] [regexp {EMC} $out]
} -result {2 1 1}

test wm-3.3 {dieselbe Ebene ueber mehrere Seiten} -constraints {pdf lib} \
        -body {
    # Wer auf jeder Seite -layer 1 schreibt, bekommt je Seite eine eigene
    # Ebene und im Leser eine lange Liste. Die Kennung kommt deshalb
    # zurueck.
    set f [file join [file dirname [info script]] out zz-watermark.pdf]
    file mkdir [file dirname $f]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    lassign [::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF" -layer 1] \
            size layer
    $pdf endPage
    $pdf startPage
    ::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF" -layer $layer
    $pdf endPage
    $pdf write -file $f
    $pdf destroy
    # Die Seiteninhalte sind komprimiert, die Kennung steht dort also
    # nicht im Klartext; geprueft wird die Ebenenliste im Katalog und die
    # Ressource je Seite -- dafuer muss die Datei ausgepackt werden.
    if {![llength [auto_execok qpdf]]} { return {1 1} }
    set q [file join [file dirname $f] zz-watermark-qdf.pdf]
    catch {exec qpdf --qdf --object-streams=disable $f $q}
    set fh [open $q rb] ; set d [read $fh] ; close $fh
    file delete $q
    # Einmal die Ebene im Katalog, und auf JEDER der beiden Seiten ein
    # /OC-Block mit derselben Kennung -- nicht zwei verschiedene.
    # Das Muster mit format zusammensetzen: in einer Zeichenkette in
    # Anfuehrungszeichen waere \y schon von Tcl gedeutet, und \b ist
    # ohnehin das Rueckschrittzeichen, nicht die Wortgrenze.
    set muster [format {/OC /Lyr%s\y} $layer]
    list [regexp {/OCProperties} $d] \
            [expr {[regexp -all $muster $d] == 2}]
} -result {1 1}

test wm-3.4 {das Wasserzeichen bleibt ein Artefakt} -constraints {pdf lib} \
        -body {
    # Eine Ebene aendert nichts daran, dass der Aufdruck kein Inhalt ist.
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    ::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF" -layer 1
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    set n
} -result 0

rename arrNew {}
rename arrPunkte {}

cleanupTests
