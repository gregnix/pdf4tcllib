#!/usr/bin/env tclsh
# Demo 30: Text Skew
# pdf4tcl 0.9.4.11 — orient true (origin top-left)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

# --- Setup (STANDARD) ---

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set demo_num 30
set demo_name "text_skew"
set outfile [file join $outdir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]
set PAGE_W [lindex $DA 0]
set PAGE_H [lindex $DA 1]

$pdf setFont 16 Helvetica
$pdf text "Text Skew" -x 40 -y 40

$pdf setFont 12 Helvetica

set y 180
foreach k {0 10 20 30} {
    pdf4tcllib::drawing::textSkewed $pdf "SkewX $k deg" 60 $y $k 0 14 Helvetica
    set y [expr {$y+32}]
}
set y 360
foreach k {-15 0 15} {
    pdf4tcllib::drawing::textSkewed $pdf "SkewY $k deg (simulated)" 60 $y 0 $k 14 Helvetica
    set y [expr {$y+32}]
}
$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"
