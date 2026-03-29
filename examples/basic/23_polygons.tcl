#!/usr/bin/env tclsh
# Demo 23: Polygone (pdf4tcl, orient true)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outfile [file join $outdir "demo_23_polygons.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]
$pdf startPage

$pdf setFont 16 Helvetica-Bold
$pdf text "Demo 23 -- Polygone" -x 60 -y 40
$pdf setFont 10 Helvetica
$pdf text "Regelmaessige Vielecke und Sterne mit pdf4tcl polygon" -x 60 -y 58

# ---------------------------------------------------------------------------
# Hilfsprocs (aus Original uebernommen)
# ---------------------------------------------------------------------------
proc draw_polygon {pdf cx cy radius sides {stroke 1} {fill 0}} {
    if {$sides < 3} { return }
    set pts {}
    for {set k 0} {$k < $sides} {incr k} {
        set ang [expr {2.0*acos(-1)*$k/$sides}]
        lappend pts [expr {$cx + $radius * cos($ang)}]
        lappend pts [expr {$cy + $radius * sin($ang)}]
    }
    $pdf polygon {*}$pts -stroke $stroke -filled $fill
}

proc draw_star {pdf cx cy r_outer {points 5} {ratio 0.5} {stroke 1} {fill 0}} {
    if {$points < 2} { return }
    set pts {}
    for {set k 0} {$k < 2*$points} {incr k} {
        set r [expr {($k % 2) ? $r_outer*$ratio : $r_outer}]
        set ang [expr {acos(-1)/2 + $k*(acos(-1)/$points)}]
        lappend pts [expr {$cx + $r * cos($ang)}]
        lappend pts [expr {$cy + $r * sin($ang)}]
    }
    $pdf polygon {*}$pts -stroke $stroke -filled $fill
}

# ---------------------------------------------------------------------------
# Zeile 1: Dreieck, Viereck, Fuenfeck (nur Umriss)
# ---------------------------------------------------------------------------
$pdf setFont 11 Helvetica-Bold
$pdf text "Nur Umriss (-stroke 1 -filled 0):" -x 60 -y 85

$pdf setStrokeColor 0 0 0.6
$pdf setLineWidth 1.5
draw_polygon $pdf 130 190 55 3 1 0
$pdf setFont 9 Helvetica
$pdf setFillColor 0.3 0.3 0.3
$pdf text "Dreieck (3)" -x 95 -y 258

draw_polygon $pdf 290 190 55 4 1 0
$pdf text "Viereck (4)" -x 255 -y 258

draw_polygon $pdf 450 190 55 5 1 0
$pdf text "Fuenfeck (5)" -x 415 -y 258

$pdf setStrokeColor 0 0 0
$pdf setFillColor 0 0 0

# ---------------------------------------------------------------------------
# Zeile 2: Sechseck gefuellt, Achteck, Stern
# ---------------------------------------------------------------------------
$pdf setFont 11 Helvetica-Bold
$pdf text "Mit Fuellung (-stroke 1 -filled 1):" -x 60 -y 285

$pdf setFillColor 0.7 0.85 1.0
$pdf setStrokeColor 0 0 0.5
$pdf setLineWidth 1.5
draw_polygon $pdf 130 390 55 6 1 1
$pdf setFillColor 0.3 0.3 0.3
$pdf setFont 9 Helvetica
$pdf text "Hexagon (6)" -x 93 -y 458

$pdf setFillColor 0.7 1.0 0.8
$pdf setStrokeColor 0 0.5 0.2
draw_polygon $pdf 290 390 55 8 1 1
$pdf setFillColor 0.3 0.3 0.3
$pdf text "Oktagon (8)" -x 253 -y 458

$pdf setFillColor 1.0 0.9 0.4
$pdf setStrokeColor 0.6 0.4 0
draw_star $pdf 450 390 55 5 0.45 1 1
$pdf setFillColor 0.3 0.3 0.3
$pdf text "Stern (5-zackig)" -x 405 -y 458

$pdf setFillColor 0 0 0
$pdf setStrokeColor 0 0 0

# ---------------------------------------------------------------------------
# Zeile 3: Verschiedene Seiten, grosser Kreis-Vergleich
# ---------------------------------------------------------------------------
$pdf setFont 11 Helvetica-Bold
$pdf text "Mehr Seiten -- Annaeherung an Kreis:" -x 60 -y 485

set cx 130
foreach {n lbl} {10 "10-Eck" 20 "20-Eck" 50 "50-Eck"} {
    $pdf setStrokeColor 0.4 0 0.6
    $pdf setLineWidth 1.0
    draw_polygon $pdf $cx 580 50 $n 1 0
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.3 0.3 0.3
    $pdf text $lbl -x [expr {$cx-20}] -y 643
    set cx [expr {$cx + 170}]
}

$pdf setFillColor 0 0 0
$pdf setStrokeColor 0 0 0

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Geschrieben: $outfile"
