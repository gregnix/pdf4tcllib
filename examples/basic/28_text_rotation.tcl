#!/usr/bin/env tclsh
# Demo 28: Text Rotation
# pdf4tcl 0.9.4.11 — orient true (origin top-left)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

# --- Setup (STANDARD) ---

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set demo_num 28
set demo_name "text_rotation"
set outfile [file join $outdir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]
set PAGE_W [lindex $DA 0]
set PAGE_H [lindex $DA 1]

$pdf setFont 16 Helvetica
$pdf text "Text Rotation" -x 40 -y 40

$pdf setFont 12 Helvetica

set centerX 320
set centerY 400
foreach angle {0 45 90 135 180 270} {
    pdf4tcllib::drawing::textRotated $pdf "Angle $angle" $centerX $centerY $angle 14 Helvetica
    set centerY [expr {$centerY - 24}]
}
set cx 500; set cy 260; set radius 80
set label "Around circle"
set n [string length $label]
for {set i 0} {$i < $n} {incr i} {
    set ch [string index $label $i]
    set t [expr {$i/double([expr {$n-1}])}]
    set a [expr { -90 + 180*$t }]
    set x [expr {$cx + $radius * cos($a*acos(-1)/180.0)}]
    set y [expr {$cy + $radius * sin($a*acos(-1)/180.0)}]
    pdf4tcllib::drawing::textRotated $pdf $ch $x $y [expr {$a+90}] 12 Helvetica
}
$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"
