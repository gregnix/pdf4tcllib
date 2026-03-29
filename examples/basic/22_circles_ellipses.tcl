#!/usr/bin/env tclsh
# Demo 22: Circles & Ellipses
# pdf4tcl 0.9.4.11 — orient true (origin top-left), no ytop

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

# --- Setup (STANDARD) ---

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set demo_num 22
set demo_name "circles_ellipses"
set outfile [file join $outdir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]
set PAGE_W [lindex $DA 0]
set PAGE_H [lindex $DA 1]

$pdf setFont 16 Helvetica
$pdf text "Circles & Ellipses" -x 40 -y 40

$pdf setFont 12 Helvetica

set centers {
    {120 180} {300 180} {480 180}
    {120 360} {300 360} {480 360}
    {120 540} {300 540} {480 540}
}
set rlist {20 40 60}
for {set i 0} {$i < 3} {incr i} {
    lassign [lindex $centers $i] cx cy
    set r [lindex $rlist $i]
    $pdf setStrokeColor 0 0 0
    $pdf setLineWidth 2
    $pdf circle $cx $cy $r
    $pdf text "r=$r" -x [expr {$cx+$r+10}] -y [expr {$cy-4}]
}
proc ellipse_points {cx cy rx ry {segments 36}} {
    set pts {}
    for {set i 0} {$i < $segments} {incr i} {
        set ang [expr {2.0 * acos(-1) * $i / $segments}]
        set x [expr {$cx + $rx * cos($ang)}]
        set y [expr {$cy + $ry * sin($ang)}]
        # ✅ RICHTIG: Flache Liste
        lappend pts $x $y
    }
    return $pts
}
set aspect {{50 30} {60 40} {70 50}}
for {set i 0} {$i < 3} {incr i} {
    lassign [lindex $centers [expr {3+$i}]] cx cy
    lassign [lindex $aspect $i] rx ry
    set pts [ellipse_points $cx $cy $rx $ry 72]
    $pdf polygon {*}$pts -stroke 1 -filled 0
    $pdf text "rx=$rx ry=$ry" -x [expr {$cx+$rx+10}] -y [expr {$cy-4}]
}
for {set i 0} {$i < 3} {incr i} {
    lassign [lindex $centers [expr {6+$i}]] cx cy
    foreach r {20 30 40 50} { $pdf circle $cx $cy $r }
    $pdf setFillColor 0.9 0.9 0.95
    $pdf circle $cx $cy 18 -filled 1
}
$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"
