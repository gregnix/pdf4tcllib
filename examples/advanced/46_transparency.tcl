#!/usr/bin/env tclsh
# Demo 46: Transparenz / Alpha (pdf4tcl 0.9.4.11)
# ============================================================================
# Zeigt setAlpha und getAlpha fuer Fill- und Stroke-Transparenz.
# Neu in pdf4tcl 0.9.4.11: setAlpha -fill, setAlpha -stroke, getAlpha.
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_46_transparency.pdf]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]
$pdf startPage

# ============================================================================
# Header
# ============================================================================
$pdf setFont 16 Helvetica-Bold
$pdf text "Demo 46: Transparenz (setAlpha / getAlpha)" -x 60 -y 40

$pdf setFont 10 Helvetica
$pdf text "pdf4tcl 0.9.4.11 -- setAlpha, getAlpha, -fill, -stroke" -x 60 -y 58

# ============================================================================
# 1. Ueberlappende Rechtecke mit verschiedenem Alpha
# ============================================================================
$pdf setFont 12 Helvetica-Bold
$pdf text "1) Ueberlappende Rechtecke -- Fill-Alpha" -x 60 -y 90

set colors {{1 0 0} {0 0.7 0} {0 0 1}}
set alphas  {1.0 0.6 0.3}
set x 60
foreach color $colors alpha $alphas {
    lassign $color r g b
    $pdf setFillColor $r $g $b
    $pdf setAlpha $alpha
    $pdf rectangle $x 100 100 60 -filled 1
    $pdf setFont 9 Helvetica
    $pdf setAlpha 1.0
    $pdf setFillColor 0 0 0
    $pdf text "alpha=[format %.1f $alpha]" -x [expr {$x+5}] -y 170
    incr x 60
}
$pdf setAlpha 1.0

# ============================================================================
# 2. Alpha-Verlauf -- gleiche Farbe, schrittweise transparenter
# ============================================================================
$pdf setFont 12 Helvetica-Bold
$pdf setFillColor 0 0 0
$pdf text "2) Alpha-Verlauf 1.0 bis 0.1 (blaue Rechtecke)" -x 60 -y 210

set x 60
for {set i 10} {$i >= 1} {incr i -1} {
    set a [expr {$i / 10.0}]
    $pdf setFillColor 0.1 0.3 0.8
    $pdf setAlpha $a
    $pdf rectangle $x 220 28 40 -filled 1
    incr x 30
}
$pdf setAlpha 1.0

# ============================================================================
# 3. Fill-Alpha vs. Stroke-Alpha unabhaengig
# ============================================================================
$pdf setFont 12 Helvetica-Bold
$pdf setFillColor 0 0 0
$pdf text "3) Fill alpha 0.3, Stroke alpha 1.0" -x 60 -y 295

$pdf setFillColor 1 0.5 0
$pdf setStrokeColor 0 0 0
$pdf setAlpha 0.3 -fill
$pdf setAlpha 1.0 -stroke
$pdf setLineStyle 2
$pdf rectangle 60 305 150 50 -filled 1 -stroke 1
$pdf setAlpha 1.0
$pdf setLineStyle 1

$pdf setFont 9 Helvetica
$pdf text "Flaeche transparent, Rahmen undurchsichtig" -x 220 -y 335

# ============================================================================
# 4. Text mit Alpha
# ============================================================================
$pdf setFont 12 Helvetica-Bold
$pdf setFillColor 0 0 0
$pdf text "4) Text mit Alpha 0.4" -x 60 -y 385

$pdf setFont 32 Helvetica-Bold
$pdf setFillColor 0 0 0
$pdf setAlpha 0.4
$pdf text "Semi-transparent" -x 60 -y 415
$pdf setAlpha 1.0

# ============================================================================
# 5. gsave/grestore stellt Alpha wieder her
# ============================================================================
$pdf setFont 12 Helvetica-Bold
$pdf setFillColor 0 0 0
$pdf text "5) gsave/grestore stellt Alpha wieder her" -x 60 -y 475

$pdf setFont 9 Helvetica
$pdf text "Links alpha 0.3 (im gsave), rechts alpha 1.0 (nach grestore)" -x 60 -y 490

$pdf setFillColor 0.5 0 0.5
$pdf setAlpha 0.3
$pdf gsave
$pdf rectangle 60 500 100 40 -filled 1
$pdf grestore
# Alpha ist jetzt zurueck auf 1.0
$pdf rectangle 180 500 100 40 -filled 1
$pdf setAlpha 1.0

# ============================================================================
# 6. getAlpha -- aktuellen Wert abfragen
# ============================================================================
$pdf setFont 12 Helvetica-Bold
$pdf setFillColor 0 0 0
$pdf text "6) getAlpha -- aktuellen Wert abfragen" -x 60 -y 570

$pdf setAlpha 0.75
set current [$pdf getAlpha]
$pdf setAlpha 1.0

$pdf setFont 10 Courier
$pdf text "\$pdf setAlpha 0.75" -x 60 -y 588
$pdf text "set a \[\$pdf getAlpha\]  ;# --> $current" -x 60 -y 604

# ============================================================================
# Footer
# ============================================================================
$pdf setFont 9 Helvetica
$pdf setFillColor 0.5 0.5 0.5
$pdf text "pdf4tcl 0.9.4.11 -- setAlpha -fill, setAlpha -stroke, getAlpha" \
    -x 60 -y 790
$pdf setFillColor 0 0 0

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Written: $outfile"
