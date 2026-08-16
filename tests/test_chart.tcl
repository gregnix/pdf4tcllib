# test_chart.tcl -- Tests fuer pdf4tcllib::chart
#
# Ein Diagramm laesst sich schlecht "ansehen" und gut nachmessen: mit
# -compress 0 ist der Content-Stream lesbar, und dort stehen die
# Rechtecke der Balken mit ihren Hoehen. Der wichtigste Test hier prueft
# deshalb nicht, DASS gezeichnet wurde, sondern dass Hoehe und Wert im
# selben Verhaeltnis stehen -- eine Skalierung, die zwei Balken vertauscht
# oder den Nullpunkt verschiebt, faellt damit auf.

package require tcltest
namespace import ::tcltest::*

testConstraint chart [expr {![catch {package require pdf4tclchart}]}]
testConstraint pdf   [expr {![catch {package require pdf4tcl}]}]

proc chartOut {} {
    set d [file join [file dirname [info script]] out]
    file mkdir $d
    return [file join $d zz-chart.pdf]
}

# Zeichnet ein Diagramm und liefert den unkomprimierten Content-Stream.
proc chartDraw {cmd data args} {
    set out [chartOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf startPage
    ::pdf4tcllib::chart::$cmd $pdf 60 60 460 200 $data {*}$args
    $pdf write -file $out
    $pdf destroy
    set fh [open $out rb]
    fconfigure $fh -encoding iso8859-1 -translation binary
    set d [read $fh]
    close $fh
    file delete $out
    if {[regexp {stream\r?\n(.*?)endstream} $d -> body]} { return $body }
    return ""
}

# Alle Rechtecke {x y w h} aus dem Stream.
proc chartRects {stream} {
    set out {}
    foreach {full x y w h} [regexp -all -inline \
            {([-0-9.]+) ([-0-9.]+) ([-0-9.]+) ([-0-9.]+) re} $stream] {
        lappend out [list $x $y $w $h]
    }
    return $out
}

# Die Balken: breit genug, um kein Legendenkaestchen zu sein.
proc chartBars {stream} {
    set out {}
    foreach r [chartRects $stream] {
        lassign $r x y w h
        if {$w > 20 && abs($h) > 5} { lappend out $r }
    }
    return $out
}

# ============================================================
# niceScale -- eine Achse, die man teilen kann
# ============================================================

test chart-scale-1 "137 wird zu 150, nicht zu 137" -constraints chart -body {
    ::pdf4tcllib::chart::niceScale 0 137 4
} -result {0.0 150.0 50.0}

test chart-scale-2 "kleine Zahlen bekommen kleine Schritte" -constraints chart -body {
    ::pdf4tcllib::chart::niceScale 0 9 4
} -result {0.0 10.0 5.0}

test chart-scale-3 "die Grenzen umschliessen die Daten immer" -constraints chart -body {
    set bad {}
    foreach {lo hi} {0 1 0 7 0 137 0 1000 12 4711 -50 50 0.1 0.9} {
        lassign [::pdf4tcllib::chart::niceScale $lo $hi 4] a b step
        if {$a > $lo || $b < $hi || $step <= 0} {
            lappend bad [list $lo $hi -> $a $b $step]
        }
    }
    return $bad
} -result {}

test chart-scale-4 "max gleich min ergibt trotzdem eine Spanne" -constraints chart -body {
    lassign [::pdf4tcllib::chart::niceScale 5 5 4] lo hi step
    expr {$hi > $lo && $step > 0}
} -result 1

# ============================================================
# Datenformen
# ============================================================

test chart-data-1 "flache Paare und Listenpaare ergeben dasselbe" \
        -constraints {chart pdf} -body {
    set a [chartBars [chartDraw bar {Jan 120 Feb 145}]]
    set b [chartBars [chartDraw bar {{Jan 120} {Feb 145}}]]
    expr {$a eq $b}
} -result 1

test chart-data-2 "ungerade Zahl flacher Elemente wird gemeldet" \
        -constraints {chart pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::chart::bar $pdf 60 60 400 200 {Jan 120 Feb}} e
    $pdf destroy
    string match "*label/value pairs*" $e
} -result 1

test chart-data-3 "keine Daten wird gemeldet" -constraints {chart pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::chart::bar $pdf 60 60 400 200 {}} e
    $pdf destroy
    string match "*no data*" $e
} -result 1

test chart-data-4 "ein Wert, der keine Zahl ist, nennt seine Beschriftung" \
        -constraints {chart pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::chart::bar $pdf 60 60 400 200 {Jan 120 Feb viel}} e
    $pdf destroy
    string match {*value for "Feb" is not a number*} $e
} -result 1

# ============================================================
# Balken -- die eigentliche Pruefung
# ============================================================

test chart-bar-1 "ein Balken je Datenpunkt" -constraints {chart pdf} -body {
    llength [chartBars [chartDraw bar {A 1 B 2 C 3 D 4 E 5}]]
} -result 5

# Der Test, um dessentwillen diese Datei den Content-Stream liest: Hoehe
# und Wert muessen im selben Verhaeltnis stehen. Vertauschte Balken, ein
# verschobener Nullpunkt oder eine falsche Spanne fallen hier auf, und
# zwar unabhaengig davon, wie gross die Box gerade ist.
test chart-bar-2 "die Balkenhoehen sind zu den Werten proportional" \
        -constraints {chart pdf} -body {
    set werte {120 145 98 160}
    set bars [chartBars [chartDraw bar {Jan 120 Feb 145 Mrz 98 Apr 160}]]
    if {[llength $bars] != 4} { return "nur [llength $bars] Balken" }
    set ratios {}
    foreach r $bars v $werte {
        lassign $r x y w h
        lappend ratios [expr {abs($h) / double($v)}]
    }
    # alle Verhaeltnisse gleich, auf vier Nachkommastellen
    set first [format %.4f [lindex $ratios 0]]
    set bad {}
    foreach rr $ratios {
        if {[format %.4f $rr] ne $first} { lappend bad $rr }
    }
    return $bad
} -result {}

test chart-bar-3 "die Balken stehen in der Reihenfolge der Daten" \
        -constraints {chart pdf} -body {
    set bars [chartBars [chartDraw bar {A 10 B 20 C 30}]]
    set xs {}
    foreach r $bars { lappend xs [lindex $r 0] }
    expr {$xs eq [lsort -real $xs]}
} -result 1

test chart-bar-4 "ein groesserer Wert ergibt einen hoeheren Balken" \
        -constraints {chart pdf} -body {
    set bars [chartBars [chartDraw bar {Klein 10 Gross 100}]]
    lassign [lindex $bars 0] x1 y1 w1 h1
    lassign [lindex $bars 1] x2 y2 w2 h2
    expr {abs($h2) > abs($h1)}
} -result 1

test chart-bar-5 "negative Werte zeichnen unter die Nulllinie" \
        -constraints {chart pdf} -body {
    set bars [chartBars [chartDraw bar {Plus 50 Minus -50}]]
    lassign [lindex $bars 0] x1 y1 w1 h1
    lassign [lindex $bars 1] x2 y2 w2 h2
    # In PDF-Koordinaten liegt der negative Balken tiefer, also bei
    # kleinerem y als der positive.
    expr {$y2 < $y1}
} -result 1

test chart-bar-6 "-values schreibt die Zahlen an die Balken" \
        -constraints {chart pdf} -body {
    set out [chartOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    ::pdf4tcllib::chart::bar $pdf 60 60 460 200 {Jan 120 Feb 145} -values 1
    $pdf write -file $out
    $pdf destroy
    set txt ""
    catch {set txt [exec pdftotext $out -]}
    file delete $out
    list [string match "*120*" $txt] [string match "*145*" $txt]
} -result {1 1}

test chart-bar-7 "eine zu kleine Box wird gemeldet, nicht gezeichnet" \
        -constraints {chart pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::chart::bar $pdf 60 60 40 8 {A 1 B 2}} e
    $pdf destroy
    string match "*box too small*" $e
} -result 1

test chart-bar-8 "-max erzwingt die Obergrenze" -constraints {chart pdf} -body {
    # Mit -max 200 ist der 100er-Balken halb so hoch wie die Flaeche.
    set bars [chartBars [chartDraw bar {A 100} -max 200 -grid 4]]
    lassign [lindex $bars 0] x y w h
    # Plotflaeche: Boxhoehe 200 minus Beschriftungszeile
    expr {abs($h) > 60 && abs($h) < 110}
} -result 1

test chart-bar-9 "unbekannte Option wird abgelehnt" -constraints {chart pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::chart::bar $pdf 60 60 400 200 {A 1} -quatsch 1} e
    $pdf destroy
    string match "*unknown option -quatsch*" $e
} -result 1

# ============================================================
# Linie
# ============================================================

# Die l-Operatoren im Stream zaehlen auch Gitter und Achsen mit -- meine
# erste Fassung dieser Tests zaehlte alle und erwartete 3, gemessen waren
# es 10. Verlaesslich ist die DIFFERENZ: zwei Datenpunkte mehr sind genau
# zwei Strecken mehr, ganz gleich wieviele Gitterlinien daneben liegen.
proc chartSegments {stream} {
    return [llength [regexp -all -inline {[-0-9.]+ [-0-9.]+ l} $stream]]
}

test chart-line-1 "jeder weitere Datenpunkt ergibt genau eine Strecke mehr" \
        -constraints {chart pdf} -body {
    set a [chartSegments [chartDraw line {Q1 100 Q2 130 Q3 120 Q4 175} -grid 4]]
    set b [chartSegments [chartDraw line {Q1 100 Q2 130 Q3 120 Q4 175 Q5 150 Q6 160} -grid 4]]
    expr {$b - $a}
} -result 2

test chart-line-2 "eine zweite Reihe zeichnet ihre eigenen Strecken" \
        -constraints {chart pdf} -body {
    set one [chartSegments [chartDraw line {{A {Q1 1 Q2 2 Q3 3}}} -grid 4]]
    set two [chartSegments [chartDraw line \
            {{A {Q1 1 Q2 2 Q3 3}} {B {Q1 3 Q2 2 Q3 1}}} -grid 4]]
    expr {$two - $one}
} -result 2

test chart-line-3 "ein einzelner Punkt ist kein Fehler" -constraints {chart pdf} -body {
    set s [chartDraw line {Nur 42}]
    expr {$s ne ""}
} -result 1

# ============================================================
# Kreis
# ============================================================

test chart-pie-1 "ein Segment je Datenpunkt" -constraints {chart pdf} -body {
    set s [chartDraw pie {A 25 B 25 C 25 D 25}]
    # Jedes pieslice endet mit h (closepath) vor dem Fuellen
    expr {[llength [regexp -all -inline {\nh\n} $s]] >= 4}
} -result 1

test chart-pie-2 "ein negativer Wert wird abgelehnt" -constraints {chart pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::chart::pie $pdf 60 60 400 200 {A 25 B -5}} e
    $pdf destroy
    string match "*cannot be negative*" $e
} -result 1

test chart-pie-3 "eine Summe von null wird abgelehnt" -constraints {chart pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    catch {::pdf4tcllib::chart::pie $pdf 60 60 400 200 {A 0 B 0}} e
    $pdf destroy
    string match "*add up to 0*" $e
} -result 1

test chart-pie-4 "-legend schreibt Anteile in Prozent" -constraints {chart pdf} -body {
    set out [chartOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf startPage
    ::pdf4tcllib::chart::pie $pdf 60 60 460 200 {Nord 35 Sued 25 Ost 20 West 20} \
            -legend 1
    $pdf write -file $out
    $pdf destroy
    set txt ""
    catch {set txt [exec pdftotext $out -]}
    file delete $out
    list [string match "*35%*" $txt] [string match "*25%*" $txt] \
         [string match "*Nord*" $txt]
} -result {1 1 1}

# ============================================================
# Tagging
# ============================================================

test chart-tag-1 "ein Diagramm ist ein Figure-Element, sein Inneres Artefakt" \
        -constraints {chart pdf} -body {
    set out [chartOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::chart::bar $pdf 60 60 460 200 {A 1 B 2} -title "Titel"
    $pdf endPage
    $pdf write -file $out
    $pdf destroy
    set fh [open $out rb]
    fconfigure $fh -encoding iso8859-1 -translation binary
    set d [read $fh]
    close $fh
    file delete $out
    # /Figure steht im Strukturbaum und damit im Klartext; /Artifact steht
    # im Content-Stream und ist nur ohne Kompression zu sehen -- deshalb
    # wird es unten mit -compress 0 geprueft, nicht hier.
    regexp {/Figure} $d
} -result 1

test chart-tag-1b "das Innere des Diagramms ist als Artefakt markiert" \
        -constraints {chart pdf} -body {
    set out [chartOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::chart::bar $pdf 60 60 460 200 {A 1 B 2} -title "Titel"
    $pdf endPage
    $pdf write -file $out
    $pdf destroy
    set fh [open $out rb]
    fconfigure $fh -encoding iso8859-1 -translation binary
    set d [read $fh]
    close $fh
    file delete $out
    regexp {/Artifact} $d
} -result 1

test chart-tag-2 "getUntaggedCount bleibt bei 0" -constraints {chart pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::chart::bar $pdf 60 60 460 200 {A 1 B 2} -title "Titel"
    ::pdf4tcllib::chart::pie $pdf 60 300 460 200 {A 1 B 2} -legend 1
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    return $n
} -result 0

cleanupTests
