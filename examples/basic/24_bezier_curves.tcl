#!/usr/bin/env tclsh
# Demo 24: Bezier Curves (pdf4tcl 0.9.4.11, orient true, ohne moveTo/curve-Abhängigkeit)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

# --- Setup (STANDARD) ---

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set demo_num 24
set demo_name "bezier_curves"
set outfile [file join $outdir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]

$pdf setFont 16 Helvetica
$pdf text "Demo 24 — Bezier Curves (quadratic→cubic, S-curve, wave)" -x 60 -y 40
$pdf setFont 12 Helvetica

# --- Helper: cubic point + polyline approximation ---
proc cubic_point {t p0 p1 p2 p3} {
    lassign $p0 x0 y0; lassign $p1 x1 y1; lassign $p2 x2 y2; lassign $p3 x3 y3
    set u [expr {1.0-$t}]
    set x [expr {$u*$u*$u*$x0 + 3*$u*$u*$t*$x1 + 3*$u*$t*$t*$x2 + $t*$t*$t*$x3}]
    set y [expr {$u*$u*$u*$y0 + 3*$u*$u*$t*$y1 + 3*$u*$t*$t*$y2 + $t*$t*$t*$y3}]
    list $x $y
}
proc draw_cubic_curve_approx {pdf p0 p1 p2 p3 steps} {
    set prev [cubic_point 0.0 $p0 $p1 $p2 $p3]
    for {set i 1} {$i <= $steps} {incr i} {
        set t [expr {$i/double($steps)}]
        set pt [cubic_point $t $p0 $p1 $p2 $p3]
        $pdf line [lindex $prev 0] [lindex $prev 1] [lindex $pt 0] [lindex $pt 1]
        set prev $pt
    }
}
proc quad_to_cubic {q0 q1 q2} {
    lassign $q0 x0 y0; lassign $q1 x1 y1; lassign $q2 x2 y2
    set p0 [list $x0 $y0]
    set p1 [list [expr {$x0 + 2.0/3*(($x1-$x0))}] [expr {$y0 + 2.0/3*(($y1-$y0))}]]
    set p2 [list [expr {$x2 + 2.0/3*(($x1-$x2))}] [expr {$y2 + 2.0/3*(($y1-$y2))}]]
    set p3 [list $x2 $y2]
    list $p0 $p1 $p2 $p3
}
proc draw_controls {pdf pts} {
    $pdf setLineDash 3 3 0
    $pdf setLineWidth 1
    $pdf setStrokeColor 0.4 0.4 0.4
    for {set i 0} {$i < [expr {[llength $pts]/2 - 1}]} {incr i} {
        set x1 [lindex $pts [expr {$i*2}]]
        set y1 [lindex $pts [expr {$i*2+1}]]
        set x2 [lindex $pts [expr {($i+1)*2}]]
        set y2 [lindex $pts [expr {($i+1)*2+1}]]
        $pdf line $x1 $y1 $x2 $y2
    }
    $pdf setLineDash
    $pdf setFillColor 0.1 0.1 0.1
    foreach {x y} $pts { $pdf circle $x $y 2 -filled 1 }
}

# 1) Quadratic -> cubic
set Q0 {100 200}; set Q1 {200 300}; set Q2 {300 200}
set cubic1 [quad_to_cubic $Q0 $Q1 $Q2]
draw_controls $pdf [concat $Q0 $Q1 $Q2]
$pdf setStrokeColor 0 0 0; $pdf setLineWidth 2
draw_cubic_curve_approx $pdf {*}$cubic1 80

# 2) S-curve
set P0 {100 400}; set P1 {180 520}; set P2 {300 280}; set P3 {400 400}
draw_controls $pdf [concat $P0 $P1 $P2 $P3]
$pdf setStrokeColor 0 0 1
draw_cubic_curve_approx $pdf $P0 $P1 $P2 $P3 80

# 3) Wave (verbundene Cubics)
set x0 100; set y0 520; set amp 30; set period 80; set cycles 4
set prev [list $x0 $y0]
$pdf setStrokeColor 1 0 0; $pdf setLineWidth 2
for {set c 0} {$c < $cycles} {incr c} {
    set x1 [expr {$x0 + $period/3.0 + $c*$period}]
    set y1 [expr {$y0 + $amp}]
    set x2 [expr {$x0 + 2*$period/3.0 + $c*$period}]
    set y2 [expr {$y0 - $amp}]
    set x3 [expr {$x0 + ($c+1)*$period}]
    set y3 $y0
    draw_cubic_curve_approx $pdf $prev [list $x1 $y1] [list $x2 $y2] [list $x3 $y3] 40
    set prev [list $x3 $y3]
}

# Labels
$pdf setFont 12 Helvetica
$pdf text "Quadratic -> Cubic" -x 100 -y 180
$pdf text "S-curve" -x 100 -y 380
$pdf text "Wave (connected cubics)" -x 100 -y 500

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"
