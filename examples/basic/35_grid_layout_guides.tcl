#!/usr/bin/env tclsh
# Demo 35: Grid Layout: Margins, Columns, Gutters
# pdf4tcl 0.9.4.11 — orient true (origin top-left), no ytop

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_35_grid_layout_guides.pdf]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]
set PAGE_W [lindex $DA 0]
set PAGE_H [lindex $DA 1]

$pdf setFont 16 Helvetica
$pdf text "Grid Layout: Margins, Columns, Gutters" -x 40 -y 40

$pdf setFont 12 Helvetica

set marginL 40
set marginR 40
set marginT 60
set marginB 60
set cols 3
set gutter 16

set innerW [expr {$PAGE_W - $marginL - $marginR}]
set innerH [expr {$PAGE_H - $marginT - $marginB}]
set colW   [expr {($innerW - ($cols-1)*$gutter) / double($cols)}]

# Draw margins
$pdf setStrokeColor 0.6 0.6 0.6
$pdf rectangle $marginL $marginT $innerW $innerH

# Columns
for {set i 0} {$i < $cols} {incr i} {
    set x [expr {$marginL + $i*($colW+$gutter)}]
    $pdf setStrokeColor 0.85 0.85 0.85
    $pdf rectangle $x $marginT $colW $innerH
    $pdf setStrokeColor 0 0 0
    $pdf text "Col [expr {$i+1}]" -x [expr {$x+6}] -y [expr {$marginT+20}]
}

# Place demo boxes aligned to the grid
$pdf setFillColor 0.9 0.95 0.9
$pdf rectangle [expr {$marginL}] [expr {$marginT+60}] [expr {$colW}] 50 -filled 1
$pdf rectangle [expr {$marginL+$colW+$gutter}] [expr {$marginT+60}] [expr {$colW}] 80 -filled 1

$pdf endPage
$pdf write -file $outfile
$pdf destroy

puts "Wrote $outfile"

