#!/usr/bin/env tclsh
# Demo 21: Lines & Paths (pdf4tcl 0.9.4.11, orient true)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

# --- Setup (STANDARD) ---

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set demo_num 21
set demo_name "lines_paths"
set outfile [file join $outdir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# PDF anlegen
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA      [$pdf getDrawableArea]
set PAGE_W  [lindex $DA 0]
set PAGE_H  [lindex $DA 1]

# Titel
$pdf setFont 16 Helvetica
$pdf text "Demo 21 — Lines & Paths" -x 60 -y 40

$pdf setFont 12 Helvetica

# --- Line widths ---
set y 90
foreach lw {0.5 1 2 4 6 8 10} {
    $pdf setLineWidth $lw
    $pdf setLineDash            ;# solid (ohne Argumente)
    $pdf line 60 $y 300 $y
    $pdf text "width=$lw" -x 310 -y [expr {$y-4}]
    set y [expr {$y + 18}]
}

# --- Line styles (dash / dot) ---
$pdf setLineWidth 2
set y 220

# solid
$pdf setLineDash
$pdf line 60 $y 300 $y
$pdf text "solid" -x 310 -y [expr {$y-4}]
set y [expr {$y + 18}]

# dash: 6 on, 3 off, offset 0
$pdf setLineDash 6 3 0
$pdf line 60 $y 300 $y
$pdf text "dash 6 3 (offset 0)" -x 310 -y [expr {$y-4}]
set y [expr {$y + 18}]

# dot: 1 on, 3 off, offset 0
$pdf setLineDash 1 3 0
$pdf line 60 $y 300 $y
$pdf text "dot 1 3 (offset 0)" -x 310 -y [expr {$y-4}]

# Reset auf solid
$pdf setLineDash

# Hinweis zu Caps/Joins (in 0.9.x nicht konfigurierbar)
$pdf setFont 12 Helvetica
$pdf text "Note: line caps/joins are not configurable in pdf4tcl 0.9.4.11" -x 60 -y 300

# --- "Path"-Beispiel (als einzelne Liniensegmente) ---
$pdf setLineWidth 2
$pdf setLineDash
# statt moveTo/lineTo/stroke: einfach drei Segmente zeichnen
$pdf line 60 540 120 570
$pdf line 120 570 200 535
$pdf line 200 535 260 570

# Seite abschließen
$pdf endPage
$pdf write -file $outfile
$pdf destroy

puts "Wrote $outfile"
