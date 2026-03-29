#!/usr/bin/env tclsh
# ============================================================================
# Demo 05: Zeichenfunktionen
# ============================================================================
# Zeigt:
#   - Farbverlaeufe (vertikal, horizontal)
#   - Polygone und Sterne
#   - Abgerundete Rechtecke
#   - Rahmen und Trennlinien
#   - Rotierter, skalierter, geneigter Text
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1

pdf4tcllib::fonts::init
package require pdf4tcl
# Tk-Fenster verstecken falls wish verwendet wird
catch {wm withdraw .}

set ctx [pdf4tcllib::page::context a4 -margin 25]
set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

set fontSans     [pdf4tcllib::fonts::fontSans]
set fontSansBold [pdf4tcllib::fonts::fontSansBold]

set x [dict get $ctx left]
set y [dict get $ctx top]
set textW [dict get $ctx text_w]

pdf4tcllib::page::header $pdf $ctx "pdf4tcllib Demo 05 - Zeichenfunktionen"

# ============================================================
# 1. Farbverlaeufe
# ============================================================
set y [expr {[dict get $ctx top] + 15}]
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "1. Farbverlaeufe" -x $x -y $y
set y [expr {$y + 24}]

# Vertikal: Blau -> Weiss
pdf4tcllib::drawing::gradient_v $pdf $x $y 120 80 {0.1 0.3 0.8} {1.0 1.0 1.0} 40
$pdf setFont 9 $fontSans
$pdf setFillColor 1 1 1
pdf4tcllib::unicode::safeText $pdf "Vertikal" -x [expr {$x + 30}] -y [expr {$y + 35}]

# Horizontal: Rot -> Gelb
set gx [expr {$x + 140}]
pdf4tcllib::drawing::gradient_h $pdf $gx $y 120 80 {0.8 0.1 0.1} {1.0 0.9 0.2} 40
$pdf setFillColor 1 1 1
pdf4tcllib::unicode::safeText $pdf "Horizontal" -x [expr {$gx + 25}] -y [expr {$y + 35}]

# Vertikal: Dunkelgruen -> Hellgruen
set gx [expr {$x + 280}]
pdf4tcllib::drawing::gradient_v $pdf $gx $y 120 80 {0.0 0.4 0.0} {0.5 0.9 0.5} 40
$pdf setFillColor 1 1 1
pdf4tcllib::unicode::safeText $pdf "Gruen" -x [expr {$gx + 38}] -y [expr {$y + 35}]

$pdf setFillColor 0 0 0
set y [expr {$y + 100}]

# ============================================================
# 2. Geometrische Formen
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "2. Polygone und Sterne" -x $x -y $y
set y [expr {$y + 30}]

set shapeY [expr {$y + 40}]

# Dreieck
$pdf setStrokeColor 0.8 0.2 0.2
$pdf setLineWidth 1.5
pdf4tcllib::drawing::polygon $pdf [expr {$x + 40}] $shapeY 35 3
$pdf setFont 8 $fontSans
pdf4tcllib::unicode::safeText $pdf "Dreieck" -x [expr {$x + 18}] -y [expr {$shapeY + 45}]

# Pentagon
$pdf setStrokeColor 0.2 0.5 0.8
pdf4tcllib::drawing::polygon $pdf [expr {$x + 130}] $shapeY 35 5
pdf4tcllib::unicode::safeText $pdf "Pentagon" -x [expr {$x + 107}] -y [expr {$shapeY + 45}]

# Hexagon (gefuellt)
$pdf setStrokeColor 0.2 0.6 0.2
$pdf setFillColor 0.8 0.95 0.8
pdf4tcllib::drawing::polygon $pdf [expr {$x + 220}] $shapeY 35 6 1 1
pdf4tcllib::unicode::safeText $pdf "Hexagon" -x [expr {$x + 197}] -y [expr {$shapeY + 45}]

# Oktagon
$pdf setStrokeColor 0.6 0.3 0.7
$pdf setFillColor 0.9 0.85 0.95
pdf4tcllib::drawing::polygon $pdf [expr {$x + 310}] $shapeY 35 8 1 1
pdf4tcllib::unicode::safeText $pdf "Oktagon" -x [expr {$x + 288}] -y [expr {$shapeY + 45}]

# 5-Stern
$pdf setStrokeColor 0.8 0.6 0.0
$pdf setFillColor 1.0 0.9 0.5
pdf4tcllib::drawing::star $pdf [expr {$x + 400}] $shapeY 35 5 0.4 1 1
pdf4tcllib::unicode::safeText $pdf "5-Stern" -x [expr {$x + 378}] -y [expr {$shapeY + 45}]

$pdf setStrokeColor 0 0 0
$pdf setFillColor 0 0 0
set y [expr {$shapeY + 70}]

# ============================================================
# 3. Abgerundete Rechtecke
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "3. Abgerundete Rechtecke" -x $x -y $y
set y [expr {$y + 24}]

set rectW [expr {int($textW / 4.0 - 10)}]
set rectStep [expr {int($textW / 4.0)}]

foreach {r label color} {
    5  "r=5"  {0.3 0.5 0.8}
    12 "r=12" {0.5 0.7 0.3}
    20 "r=20" {0.8 0.4 0.2}
} {
    $pdf setStrokeColor {*}$color
    $pdf setLineWidth 1.5
    pdf4tcllib::drawing::roundedRect $pdf $x $y $rectW 50 $r 1 0

    $pdf setFont 10 $fontSans
    $pdf setFillColor {*}$color
    pdf4tcllib::unicode::safeText $pdf $label -x [expr {$x + $rectW / 2 - 10}] -y [expr {$y + 20}]

    set x [expr {$x + $rectStep}]
}

# Gefuellt
$pdf setStrokeColor 0.2 0.2 0.6
$pdf setFillColor 0.85 0.85 0.95
pdf4tcllib::drawing::roundedRect $pdf $x $y $rectW 50 15 1 1
$pdf setFillColor 0.2 0.2 0.6
$pdf setFont 10 $fontSans
pdf4tcllib::unicode::safeText $pdf "Gef\u00FCllt" -x [expr {$x + $rectW / 2 - 18}] -y [expr {$y + 20}]

set x [dict get $ctx left]
$pdf setStrokeColor 0 0 0
$pdf setFillColor 0 0 0
$pdf setLineWidth 1
set y [expr {$y + 70}]

# ============================================================
# 4. Rahmen und Trennlinien
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "4. Rahmen und Trennlinien" -x $x -y $y
set y [expr {$y + 24}]

pdf4tcllib::drawing::frame $pdf $x $y 200 40 2
$pdf setFont 10 $fontSans
pdf4tcllib::unicode::safeText $pdf "Rahmen (2pt)" -x [expr {$x + 10}] -y [expr {$y + 15}]
set y [expr {$y + 55}]

pdf4tcllib::drawing::separator $pdf $x $y $textW
set y [expr {$y + 8}]
$pdf setFont 9 $fontSans
$pdf setFillColor 0.5 0.5 0.5
pdf4tcllib::unicode::safeText $pdf "Trennlinie (default: grau, 0.5pt)" -x $x -y $y
$pdf setFillColor 0 0 0
set y [expr {$y + 15}]

pdf4tcllib::drawing::separator $pdf $x $y $textW {0.2 0.2 0.8} 1.5
set y [expr {$y + 8}]
$pdf setFont 9 $fontSans
$pdf setFillColor 0.5 0.5 0.5
pdf4tcllib::unicode::safeText $pdf "Trennlinie (blau, 1.5pt)" -x $x -y $y
$pdf setFillColor 0 0 0
set y [expr {$y + 30}]

# ============================================================
# 5. Text-Transformationen
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "5. Text-Transformationen" -x $x -y $y
set y [expr {$y + 30}]

# Rotiert
$pdf setFillColor 0.2 0.2 0.8
pdf4tcllib::drawing::textRotated $pdf "Rotiert 30" [expr {$x + 20}] $y 30 14
pdf4tcllib::drawing::textRotated $pdf "Rotiert 45" [expr {$x + 150}] $y 45 14
pdf4tcllib::drawing::textRotated $pdf "Rotiert 90" [expr {$x + 280}] $y 90 14

$pdf setFillColor 0 0 0
set y [expr {$y + 80}]

# Skaliert
$pdf setFillColor 0.6 0.2 0.2
pdf4tcllib::drawing::textScaled $pdf "Breit" $x $y 2.0 1.0 12
pdf4tcllib::drawing::textScaled $pdf "Hoch" [expr {$x + 200}] $y 1.0 2.0 12

# Geneigt
$pdf setFillColor 0.2 0.6 0.2
pdf4tcllib::drawing::textSkewed $pdf "Geneigt 15" [expr {$x + 320}] $y 15 0 12

$pdf setFillColor 0 0 0

# Footer
pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib Demo Suite" 1
$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir "demo_05_drawing.pdf"]
$pdf write -file $outfile
$pdf destroy
catch {destroy .}
puts "Geschrieben: $outfile"
