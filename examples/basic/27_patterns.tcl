#!/usr/bin/env tclsh
# Demo 27: Patterns
# pdf4tcl 0.9.4.11 — orient true (origin top-left)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

# --- Setup (STANDARD) ---

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set demo_num 27
set demo_name "patterns"
set outfile [file join $outdir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# Create PDF with orient=true (origin top-left)
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

# ============================================================================
# Header
# ============================================================================
$pdf setFont 16 Helvetica-Bold
$pdf text "Demo 27 - Patterns" -x 50 -y 40

$pdf setFont 10 Helvetica
$pdf text "Common fill patterns using basic shapes" -x 50 -y 60

# ============================================================================
# Pattern 1: Chessboard
# ============================================================================
set x 60; set y 120; set size 20
for {set r 0} {$r < 8} {incr r} {
    for {set c 0} {$c < 8} {incr c} {
        set xx [expr {$x + $c*$size}]
        set yy [expr {$y + $r*$size}]
        if {[expr {($r+$c)%2}] == 0} {
            $pdf setFillColor 0.2 0.2 0.2
        } else {
            $pdf setFillColor 0.8 0.8 0.8
        }
        $pdf rectangle $xx $yy $size $size -filled 1
    }
}
$pdf setStrokeColor 0 0 0
$pdf setLineWidth 1
$pdf rectangle $x $y [expr {8*$size}] [expr {8*$size}] -stroke 1
$pdf setFont 9 Helvetica
$pdf text "Chessboard" -x $x -y [expr {$y-10}]

# ============================================================================
# Pattern 2: Vertical Stripes
# ============================================================================
set x2 280; set w 200; set h 160
set stripe 10
for {set i 0} {$i < [expr {$w/$stripe}]} {incr i} {
    set xx [expr {$x2 + $i*$stripe}]
    if {[expr {$i%2}] == 0} {
        $pdf setFillColor 0.9 0.6 0.6
    } else {
        $pdf setFillColor 0.6 0.6 0.9
    }
    $pdf rectangle $xx $y $stripe $h -filled 1
}
$pdf setStrokeColor 0 0 0
$pdf setLineWidth 1
$pdf rectangle $x2 $y $w $h -stroke 1
$pdf setFont 9 Helvetica
$pdf text "Vertical stripes" -x $x2 -y [expr {$y-10}]

# ============================================================================
# Pattern 3: Dots Grid
# ============================================================================
set x3 520; set w3 200; set h3 160
$pdf setFillColor 0.2 0.2 0.2
for {set yy $y} {$yy < [expr {$y+$h3}]} {incr yy 16} {
    for {set xx $x3} {$xx < [expr {$x3+$w3}]} {incr xx 16} {
        # small filled circles
        $pdf circle $xx $yy 2 -filled 1
    }
}
$pdf setStrokeColor 0 0 0
$pdf setLineWidth 1
$pdf rectangle $x3 $y $w3 $h3 -stroke 1
$pdf setFont 9 Helvetica
$pdf text "Dots grid" -x $x3 -y [expr {$y-10}]

# ============================================================================
# Footer
# ============================================================================
$pdf setFillColor 0.5 0.5 0.5
$pdf setFont 8 Helvetica
$pdf text "pdf4tcl Demo Suite - Patterns Demo" -x 297 -y 820 -align center
$pdf setFillColor 0 0 0

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"
