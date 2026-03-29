#!/usr/bin/env tclsh
# Demo 26: Native Gradienten -- linearGradient und radialGradient

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outfile [file join $outdir "demo_26_gradients.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]
$pdf startPage

$pdf setFont 16 Helvetica-Bold
$pdf text "Demo 26 -- Native Gradienten" -x 60 -y 40
$pdf setFont 10 Helvetica
$pdf text "pdf4tcl linearGradient (axial) und radialGradient" -x 60 -y 58

# ---------------------------------------------------------------------------
# Zeile 1: Vertikale Gradienten
# ---------------------------------------------------------------------------
$pdf setFont 11 Helvetica-Bold
$pdf text "Vertikal:" -x 60 -y 85

set y 100
set w 155
set h 100

foreach {c1 c2 lbl x} {
    {1 0 0}   {0 0 1}   "Rot -> Blau"     60
    {1 1 0}   {0 0.6 0} "Gelb -> Gruen"   228
    {0 0 0}   {1 1 1}   "Schwarz -> Weiss" 396
} {
    $pdf gsave
    $pdf clip $x $y $w $h
    $pdf linearGradient $x $y $x [expr {$y+$h}] $c1 $c2
    $pdf grestore
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf setLineWidth 0.5
    $pdf rectangle $x $y $w $h
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.2 0.2 0.2
    $pdf text $lbl -x $x -y [expr {$y+$h+12}]
    $pdf setFillColor 0 0 0
    $pdf setStrokeColor 0 0 0
}

# ---------------------------------------------------------------------------
# Zeile 2: Horizontale Gradienten
# ---------------------------------------------------------------------------
$pdf setFont 11 Helvetica-Bold
$pdf text "Horizontal:" -x 60 -y 230

set y 245

foreach {c1 c2 lbl x} {
    {0 0.4 0.8} {1 0.6 0}    "Blau -> Orange"  60
    {0.6 0 0.8} {0 0.8 0.6}  "Lila -> Tuerkis" 228
    {1 1 1}     {0.2 0.2 0.2} "Weiss -> Dunkel" 396
} {
    $pdf gsave
    $pdf clip $x $y $w $h
    $pdf linearGradient $x $y [expr {$x+$w}] $y $c1 $c2
    $pdf grestore
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf setLineWidth 0.5
    $pdf rectangle $x $y $w $h
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.2 0.2 0.2
    $pdf text $lbl -x $x -y [expr {$y+$h+12}]
    $pdf setFillColor 0 0 0
    $pdf setStrokeColor 0 0 0
}

# ---------------------------------------------------------------------------
# Zeile 3: Radiale Gradienten (in Kreisen)
# ---------------------------------------------------------------------------
$pdf setFont 11 Helvetica-Bold
$pdf text "Radial:" -x 60 -y 375

set y 390
set r 55

foreach {c1 c2 lbl cx} {
    {1 1 1}     {0 0 0.7}  "Weiss -> Blau"       117
    {1 0.9 0}   {0.7 0 0}  "Gelb -> Rot"         285
    {0.6 1 0.6} {0 0.3 0}  "Hellgruen -> Dunkel" 453
} {
    set cy [expr {$y + $r}]
    $pdf gsave
    $pdf clip $cx $y [expr {2*$r}] [expr {2*$r}]
    $pdf radialGradient $cx $cy 0 $cx $cy $r $c1 $c2
    $pdf grestore
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf setLineWidth 0.5
    $pdf circle $cx $cy $r
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.2 0.2 0.2
    $pdf text $lbl -x [expr {$cx-$r}] -y [expr {$cy+$r+12}]
    $pdf setFillColor 0 0 0
    $pdf setStrokeColor 0 0 0
}

# ---------------------------------------------------------------------------
# Zeile 4: Diagonal + Spotlight
# ---------------------------------------------------------------------------
$pdf setFont 11 Helvetica-Bold
$pdf text "Diagonal + Spotlight (radial exzentrisch):" -x 60 -y 550

# Diagonal
set x 60
set y 565
$pdf gsave
$pdf clip $x $y 230 80
$pdf linearGradient $x $y [expr {$x+230}] [expr {$y+80}] {0.2 0 0.5} {1.0 0.8 0.0}
$pdf grestore
$pdf setStrokeColor 0.5 0.5 0.5
$pdf setLineWidth 0.5
$pdf rectangle $x $y 230 80
$pdf setFont 9 Helvetica
$pdf setFillColor 0.2 0.2 0.2
$pdf text "Diagonal: Lila -> Gold" -x $x -y [expr {$y+92}]
$pdf setFillColor 0 0 0
$pdf setStrokeColor 0 0 0

# Spotlight
set x 330
set cx [expr {$x+80}]
set cy [expr {$y+30}]
$pdf gsave
$pdf clip $x $y 230 80
$pdf radialGradient $cx $cy 0 [expr {$cx+30}] [expr {$cy+20}] 130 {1 1 1} {0 0 0}
$pdf grestore
$pdf setStrokeColor 0.5 0.5 0.5
$pdf rectangle $x $y 230 80
$pdf setFont 9 Helvetica
$pdf setFillColor 0.2 0.2 0.2
$pdf text "Spotlight (exzentrisch)" -x $x -y [expr {$y+92}]
$pdf setFillColor 0 0 0
$pdf setStrokeColor 0 0 0

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Geschrieben: $outfile"
