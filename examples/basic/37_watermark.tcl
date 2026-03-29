#!/usr/bin/env tclsh
# Demo 37: Watermark (Text & Box)
# pdf4tcl 0.9.4.11 — orient true (origin top-left), no ytop

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_37_watermark.pdf]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]
set PAGE_W [lindex $DA 0]
set PAGE_H [lindex $DA 1]

$pdf setFont 16 Helvetica
$pdf text "Watermark (Text & Box)" -x 40 -y 40

$pdf setFont 12 Helvetica

set wm_text "CONFIDENTIAL"
set alpha 0.12
$pdf setAlpha $alpha
pdf4tcllib::drawing::textRotated $pdf $wm_text [expr {$PAGE_W/2 - 140}] [expr {$PAGE_H/2}] 45 72 Helvetica
$pdf setAlpha 1.0
$pdf setFillColor 0 0 0
$pdf setFont 14 Helvetica
$pdf text "This page contains a semi-transparent diagonal watermark." -x 40 -y 100
$pdf setStrokeColor 0 0 0
$pdf rectangle 40 130 300 80
$pdf text "Boxed content" -x 52 -y 152
$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"
