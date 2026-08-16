# test_flow.tcl -- Tests fuer pdf4tcllib::flow und drawing::watermark
#
# Die Frage bei einem Textfluss ist nicht, ob er zeichnet, sondern ob er
# etwas verliert. Die wichtigen Tests hier zaehlen deshalb im erzeugten
# PDF nach, ob jeder Absatz genau einmal vorkommt.

package require tcltest
namespace import ::tcltest::*

testConstraint flow [expr {![catch {package require pdf4tclflow}]}]
testConstraint pdf  [expr {![catch {package require pdf4tcl}]}]
testConstraint pdftotext [expr {[llength [auto_execok pdftotext]] > 0}]

proc flowOut {} {
    set d [file join [file dirname [info script]] out]
    file mkdir $d
    return [file join $d zz-flow.pdf]
}

# Text aus n Absaetzen, jeder mit einer erkennbaren Marke.
proc flowText {n {reps 3}} {
    set t ""
    for {set i 1} {$i <= $n} {incr i} {
        append t "MARKE$i " [string repeat "Lorem ipsum dolor sit amet,\
                consetetur sadipscing elitr, sed diam nonumy eirmod tempor\
                invidunt ut labore et dolore magna aliquyam. " $reps] "\n\n"
    }
    return $t
}

# Fliesst $text und liefert {ergebnis text-des-pdf}.
proc flowRun {text args} {
    set out [flowOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set res [::pdf4tcllib::flow::columns $pdf $ctx $text {*}$args -newpage {
        $pdf endPage
        $pdf startPage
    }]
    $pdf endPage
    $pdf write -file $out
    $pdf destroy
    set txt ""
    catch {set txt [exec pdftotext $out -]}
    set info ""
    catch {set info [exec pdfinfo $out]}
    file delete $out
    return [list $res $txt $info]
}

# ============================================================
# Spaltengeometrie
# ============================================================

test flow-boxes-1 "zwei Spalten teilen die Textbreite mit Zwischenraum" \
        -constraints flow -body {
    set ctx [::pdf4tcllib::page::context a4]
    set b [::pdf4tcllib::flow::boxes $ctx -columns 2 -gap 18]
    lassign [lindex $b 0] x1 w1
    lassign [lindex $b 1] x2 w2
    list [expr {abs($w1 - $w2) < 0.01}] \
         [format %.1f [expr {$w1 + 18 + $w2}]] \
         [format %.1f [dict get $ctx text_w]]
} -result {1 481.9 481.9}

test flow-boxes-2 "eine Spalte ist die ganze Textbreite" -constraints flow -body {
    set ctx [::pdf4tcllib::page::context a4]
    lassign [lindex [::pdf4tcllib::flow::boxes $ctx -columns 1] 0] x w
    list [format %.1f $x] [format %.1f $w]
} -result [list [format %.1f [dict get [::pdf4tcllib::page::context a4] left]] \
                [format %.1f [dict get [::pdf4tcllib::page::context a4] text_w]]]

test flow-boxes-3 "die zweite Spalte beginnt rechts der ersten" -constraints flow -body {
    set b [::pdf4tcllib::flow::boxes [::pdf4tcllib::page::context a4] -columns 3]
    set xs {}
    foreach c $b { lappend xs [lindex $c 0] }
    expr {$xs eq [lsort -real $xs]}
} -result 1

test flow-boxes-4 "zu viele Spalten fuer die Breite werden gemeldet" \
        -constraints flow -body {
    catch {::pdf4tcllib::flow::boxes [::pdf4tcllib::page::context a4] \
            -columns 40 -gap 18} e
    string match "*leave no width*" $e
} -result 1

test flow-boxes-5 "null Spalten werden abgelehnt" -constraints flow -body {
    catch {::pdf4tcllib::flow::boxes [::pdf4tcllib::page::context a4] -columns 0} e
    string match "*at least 1*" $e
} -result 1

# ============================================================
# measure -- Zeilen zaehlen
# ============================================================

test flow-measure-1 "eine kurze Zeile ist eine Zeile" -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set l [::pdf4tcllib::flow::measure $pdf "Kurz" 200 10 Helvetica]
    $pdf destroy
    return $l
} -result Kurz

test flow-measure-2 "zwei Absaetze bekommen eine Leerzeile dazwischen" \
        -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set l [::pdf4tcllib::flow::measure $pdf "Eins\n\nZwei" 200 10 Helvetica]
    $pdf destroy
    return $l
} -result {Eins {} Zwei}

test flow-measure-3 "eine schmalere Spalte braucht mehr Zeilen" \
        -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set txt [string repeat "Wort " 60]
    set weit [llength [::pdf4tcllib::flow::measure $pdf $txt 400 10 Helvetica]]
    set eng  [llength [::pdf4tcllib::flow::measure $pdf $txt 120 10 Helvetica]]
    $pdf destroy
    expr {$eng > $weit}
} -result 1

test flow-measure-4 "leerer Text ergibt keine Zeile" -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set l [::pdf4tcllib::flow::measure $pdf "" 200 10 Helvetica]
    $pdf destroy
    llength $l
} -result 0

# ============================================================
# Der Fluss -- geht etwas verloren?
# ============================================================

# Der Test, um dessentwillen die Marken im Text stehen: was hineingeht,
# muss herauskommen, genau einmal. Ein Fluss, der beim Spalten- oder
# Seitenwechsel eine Zeile verschluckt oder doppelt setzt, faellt hier auf
# -- und nur hier, denn das Ergebnis-Dict wuesste davon nichts.
test flow-run-1 "jeder Absatz steht genau einmal im PDF" \
        -constraints {flow pdf pdftotext} -body {
    lassign [flowRun [flowText 12] -columns 2] res txt info
    set bad {}
    for {set i 1} {$i <= 12} {incr i} {
        set n [regexp -all "MARKE$i\\y" $txt]
        if {$n != 1} { lappend bad [list MARKE$i $n] }
    }
    return $bad
} -result {}

test flow-run-2 "nichts bleibt uebrig, wenn -newpage da ist" \
        -constraints {flow pdf pdftotext} -body {
    lassign [flowRun [flowText 20] -columns 2] res txt info
    dict get $res rest
} -result {}

test flow-run-3 "mehr Text braucht mehr Seiten" -constraints {flow pdf pdftotext} -body {
    lassign [flowRun [flowText 4]  -columns 2] r1 t1 i1
    lassign [flowRun [flowText 40] -columns 2] r2 t2 i2
    expr {[dict get $r2 pages] > [dict get $r1 pages]}
} -result 1

# Meine erste Fassung dieses Tests erwartete, dass mehr Spalten Seiten
# sparen. Gemessen stimmt das nicht: derselbe Text ergab mit einer Spalte
# 3 Seiten und mit dreien ebenfalls 3. Schmale Spalten brechen oefter um
# und lassen an jedem Zeilenende mehr Platz liegen -- der Gewinn an
# Spalten wird vom Verlust an Zeilenlaenge aufgefressen.
#
# Was tatsaechlich gelten MUSS, ist etwas anderes: bei jeder Spaltenzahl
# geht nichts verloren.
test flow-run-4 "bei jeder Spaltenzahl bleibt der Text vollstaendig" \
        -constraints {flow pdf pdftotext} -body {
    set bad {}
    foreach c {1 2 3 4} {
        lassign [flowRun [flowText 20] -columns $c] res txt info
        if {[dict get $res rest] ne ""} { lappend bad [list $c "Rest uebrig"] }
        for {set i 1} {$i <= 20} {incr i} {
            if {[regexp -all "MARKE$i\\y" $txt] != 1} {
                lappend bad [list $c MARKE$i]
            }
        }
    }
    return $bad
} -result {}

# Ohne -newpage kann der Fluss keine neue Seite anfangen. Er darf den Rest
# dann nicht stillschweigend fallen lassen -- er gibt ihn zurueck.
test flow-run-5 "ohne -newpage kommt der Rest zurueck, statt zu verschwinden" \
        -constraints {flow pdf} -body {
    set out [flowOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set res [::pdf4tcllib::flow::columns $pdf $ctx [flowText 40] -columns 2]
    $pdf endPage
    $pdf write -file $out
    $pdf destroy
    file delete $out
    list [dict get $res pages] [expr {[string length [dict get $res rest]] > 0}]
} -result {0 1}

test flow-run-6 "der zurueckgegebene Rest ist genau das, was fehlt" \
        -constraints {flow pdf pdftotext} -body {
    set out [flowOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set res [::pdf4tcllib::flow::columns $pdf $ctx [flowText 40] -columns 2]
    $pdf endPage
    $pdf write -file $out
    $pdf destroy
    set txt ""
    catch {set txt [exec pdftotext $out -]}
    file delete $out
    # Eine Marke, die im Rest steht, darf nicht auch auf der Seite stehen.
    set rest [dict get $res rest]
    set bad {}
    for {set i 1} {$i <= 40} {incr i} {
        set imRest  [regexp "MARKE$i\\y" $rest]
        set imPdf   [regexp "MARKE$i\\y" $txt]
        if {$imRest && $imPdf} { lappend bad MARKE$i }
        if {!$imRest && !$imPdf} { lappend bad "MARKE$i nirgends" }
    }
    return $bad
} -result {}

test flow-run-7 "unbekannte Option wird abgelehnt" -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    catch {::pdf4tcllib::flow::columns $pdf $ctx "Text" -quatsch 1} e
    $pdf destroy
    string match "*unknown option -quatsch*" $e
} -result 1

test flow-run-8 "getUntaggedCount bleibt bei 0" -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::flow::columns $pdf $ctx [flowText 3] -columns 2
    $pdf endPage
    set n [$pdf getUntaggedCount]
    $pdf destroy
    return $n
} -result 0

# ============================================================
# Wasserzeichen
# ============================================================

test wm-1 "die Groesse wird an die Seite angepasst" -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set kurz [::pdf4tcllib::drawing::watermark $pdf $ctx "X"]
    $pdf endPage
    $pdf startPage
    set lang [::pdf4tcllib::drawing::watermark $pdf $ctx "SEHR LANGER ENTWURF"]
    $pdf destroy
    expr {$kurz > $lang}
} -result 1

test wm-2 "-size setzt die Groesse fest" -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set s [::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF" -size 40]
    $pdf destroy
    return $s
} -result 40

# Das Wasserzeichen muss auf die Seite passen -- gemessen an der
# Textmatrix im unkomprimierten Stream, nicht geschaetzt.
test wm-3 "der Stempel liegt innerhalb der Seite" -constraints {flow pdf} -body {
    set out [flowOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    set size [::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF"]
    $pdf setFont $size [::pdf4tcllib::_defaultFamily]
    set tw [$pdf getStringWidth "ENTWURF"]
    $pdf endPage
    $pdf write -file $out
    $pdf destroy
    set fh [open $out rb]
    fconfigure $fh -encoding iso8859-1 -translation binary
    set d [read $fh]
    close $fh
    file delete $out
    if {![regexp {([-0-9.]+) ([-0-9.]+) ([-0-9.]+) ([-0-9.]+) ([-0-9.]+) ([-0-9.]+) Tm} \
            $d -> a b c dd x0 y0]} { return "keine Textmatrix" }
    set rad [expr {acos(-1) / 4.0}]
    set x1 [expr {$x0 + cos($rad) * $tw}]
    set y1 [expr {$y0 + sin($rad) * $tw}]
    set bad {}
    foreach {n v max} [list x0 $x0 595.3 y0 $y0 841.9 x1 $x1 595.3 y1 $y1 841.9] {
        if {$v < 0 || $v > $max} { lappend bad [list $n [format %.1f $v]] }
    }
    return $bad
} -result {}

test wm-4 "das Wasserzeichen ist ein Artefakt" -constraints {flow pdf} -body {
    set out [flowOut]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -compress 0]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf tagged 1
    $pdf startPage
    ::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF"
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

test wm-5 "leerer Text wird abgelehnt" -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    catch {::pdf4tcllib::drawing::watermark $pdf $ctx ""} e
    $pdf destroy
    string match "*no text*" $e
} -result 1

test wm-6 "unbekannte Option wird abgelehnt" -constraints {flow pdf} -body {
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    set ctx [::pdf4tcllib::page::context a4]
    $pdf startPage
    catch {::pdf4tcllib::drawing::watermark $pdf $ctx "X" -quatsch 1} e
    $pdf destroy
    string match "*unknown option -quatsch*" $e
} -result 1

cleanupTests
