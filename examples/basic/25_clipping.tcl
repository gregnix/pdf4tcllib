#!/usr/bin/env tclsh
# Demo 25: clipping
# pdf4tcl 0.9.4.11 — orient true (origin top-left)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

# --- Setup (STANDARD) ---

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set demo_num 25
set demo_name "clipping"
set outfile [file join $outdir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# Create PDF with orient=true (origin top-left)
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

# ============================================================================
# Header
# ============================================================================
$pdf setFont 16 Helvetica-Bold
$pdf text "Demo 25 - Rectangular Clipping" -x 50 -y 50

$pdf setFont 10 Helvetica
$pdf text "pdf4tcl supports rectangular clip regions with gsave/grestore." -x 50 -y 70

# ============================================================================
# 1) Overlapping Clips - Shows that clips don't add up
# ============================================================================
set label_y 120
$pdf setFont 12 Helvetica-Bold
$pdf text "1. Overlapping Clips (Independent)" -x 50 -y $label_y

set start_y [expr {$label_y + 30}]

# First clip region - Red stripes
$pdf gsave
$pdf clip 60 $start_y 120 120
$pdf setFillColor 1 0.9 0.9
$pdf rectangle 60 $start_y 120 120 -filled 1
# Vertical stripes
for {set x 60} {$x < 180} {incr x 12} {
    $pdf setFillColor 0.8 0.2 0.2
    $pdf rectangle $x $start_y 6 120 -filled 1
}
$pdf setStrokeColor 0.8 0 0
$pdf setLineWidth 2
$pdf rectangle 60 $start_y 120 120 -stroke 1
$pdf grestore

# Second clip region - Blue stripes (overlaps with first)
$pdf gsave
$pdf clip 120 [expr {$start_y + 40}] 120 120
$pdf setFillColor 0.9 0.9 1
$pdf rectangle 120 [expr {$start_y + 40}] 120 120 -filled 1
# Horizontal stripes
for {set y [expr {$start_y + 40}]} {$y < [expr {$start_y + 160}]} {incr y 12} {
    $pdf setFillColor 0.2 0.2 0.8
    $pdf rectangle 120 $y 120 6 -filled 1
}
$pdf setStrokeColor 0 0 0.8
$pdf setLineWidth 2
$pdf rectangle 120 [expr {$start_y + 40}] 120 120 -stroke 1
$pdf grestore

# Label
$pdf setFont 9 Helvetica
$pdf setFillColor 0.3 0.3 0.3
$pdf text "Each clip is independent" -x 60 -y [expr {$start_y + 140}]

# ============================================================================
# 2) Nested Clips - Shows gsave/grestore hierarchy
# ============================================================================
set label_y 330
$pdf setFont 12 Helvetica-Bold
$pdf setFillColor 0 0 0
$pdf text "2. Nested Clips (Hierarchical)" -x 50 -y $label_y

set start_y [expr {$label_y + 30}]

# Outer clip
$pdf gsave
$pdf clip 60 $start_y 220 160

# Draw gradient background in outer clip
for {set i 0} {$i < 160} {incr i 4} {
    set c [expr {0.95 - $i/160.0 * 0.3}]
    $pdf setFillColor $c [expr {$c * 0.95}] [expr {$c * 0.9}]
    $pdf rectangle 60 [expr {$start_y + $i}] 220 4 -filled 1
}

# Outer border
$pdf setStrokeColor 0.4 0.4 0.4
$pdf setLineWidth 3
$pdf rectangle 60 $start_y 220 160 -stroke 1

    # Inner clip (nested inside outer)
    $pdf gsave
    $pdf clip 100 [expr {$start_y + 40}] 140 80
    
    # Draw checkerboard pattern in inner clip
    for {set yy [expr {$start_y + 40}]} {$yy < [expr {$start_y + 120}]} {incr yy 20} {
        for {set xx 100} {$xx < 240} {incr xx 20} {
            if {($xx + $yy) % 40 == 0} {
                $pdf setFillColor 0.2 0.5 0.2
            } else {
                $pdf setFillColor 0.9 1 0.9
            }
            $pdf rectangle $xx $yy 20 20 -filled 1
        }
    }
    
    # Inner border
    $pdf setStrokeColor 0 0.5 0
    $pdf setLineWidth 2
    $pdf rectangle 100 [expr {$start_y + 40}] 140 80 -stroke 1
    
    $pdf grestore
    # After inner grestore, we're back in outer clip

$pdf grestore
# After outer grestore, no clip active

# Labels
$pdf setFont 9 Helvetica
$pdf setFillColor 0.3 0.3 0.3
$pdf text "Outer clip (gray gradient)" -x 60 -y [expr {$start_y + 175}]
$pdf text "Inner clip (checkerboard)" -x 100 -y [expr {$start_y + 175}]

# ============================================================================
# 3) Practical Use Case - Clipped Text
# ============================================================================
set label_y 120
$pdf setFont 12 Helvetica-Bold
$pdf setFillColor 0 0 0
$pdf text "3. Text Overflow Prevention" -x 320 -y $label_y

set start_y [expr {$label_y + 30}]
set box_w 220
set box_h 80

# Draw box outline first (not clipped)
$pdf setStrokeColor 0.5 0.5 0.5
$pdf setLineWidth 1
$pdf rectangle 320 $start_y $box_w $box_h -stroke 1

# Clip region for text
$pdf gsave
$pdf clip 320 $start_y $box_w $box_h

# Long text that would overflow
$pdf setFont 11 Helvetica
$pdf setFillColor 0 0 0
set long_text "This is a very long text that would normally overflow the box boundaries. "
append long_text "Clipping ensures that only the visible portion is shown, preventing text "
append long_text "from appearing outside the designated area. This is useful for tables, "
append long_text "columns, and other constrained layouts."

set y [expr {$start_y + 20}]
set x 325
foreach word [split $long_text] {
    $pdf text "$word " -x $x -y $y
    incr y 15
    if {$y > [expr {$start_y + $box_h - 10}]} {
        break
    }
}

$pdf grestore

# Label
$pdf setFont 9 Helvetica
$pdf setFillColor 0.3 0.3 0.3
$pdf text "Text stays inside the box" -x 320 -y [expr {$start_y + 95}]

# ============================================================================
# Footer
# ============================================================================
$pdf setFillColor 0.5 0.5 0.5
$pdf setFont 8 Helvetica
$pdf text "pdf4tcl Demo Suite - Rectangular Clipping Demo" -x 297 -y 820 -align center
$pdf setFillColor 0 0 0

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"