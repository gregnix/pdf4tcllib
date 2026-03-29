#!/usr/bin/env wish
# ===========================================================================
# Demo 52: tko::path -- SVG-style drawing and PDF export
# ===========================================================================
# tko::path extends the Tk canvas with SVG-style rendering.
#
# KEY: correct PDF export requires -bbox option:
#   $pdf canvas $pathName -bbox [$pathName bbox] -x X -y Y
#
# Without -bbox, pdf4tcl does not know the extent of the path canvas
# and may miss items or produce an empty PDF.
#
# Item names (current tko version):
#   rect      rectangle with optional rounded corners (-rx -ry)
#   circle    circle  (-r radius)
#   ellipse   ellipse (-rx -ry)
#   line      single line segment
#   polyline  multi-segment open line
#   polygon   closed polygon
#   path      SVG path data (M L C Q A Z ...)
#   text      text  (-fontsize -fontfamily -fontweight -fontslant)
#   image     image
#
# All items support:
#   -fill -fillopacity -stroke -strokewidth -strokedasharray
#   -matrix {a b c d tx ty}  (affine transform)
#
# Antialiasing: set path::antialias 1  (cairo/GDI+, screen only)
#
# Usage: wish examples/advanced/52_tkpath_basic.tcl [outputdir]
# Requires: tko
# ===========================================================================

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

if {[catch {package require tko} err]} {
    puts stderr "tko not available: $err"
    puts stderr "Install: chiselapp.com/user/rene/repository/tkpath"
    exit 1
}

# Enable antialiasing (cairo backend)
catch { set ::path::antialias 1 }

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_52_tkpath.pdf"]

# ---------------------------------------------------------------------------
# Build tko::path canvas
# ---------------------------------------------------------------------------
wm withdraw .
toplevel .top
wm withdraw .top

set CW 500
set CH 460
tko::path .top.p -width $CW -height $CH -background white
pack .top.p

# --- Title ---
.top.p create text 250 22 \
    -text "tko::path -- SVG-style drawing + PDF export" \
    -fontsize 13 -fill "#1a3f7a" -textanchor middle
.top.p create line 10 40 490 40 -stroke "#aaaaaa" -strokewidth 1

# --- 1. rect (rounded rectangles) ---
.top.p create text 10 56 -text "1. rect  (-rx for rounded corners)" \
    -fontsize 10 -fill "#333333" -textanchor start
.top.p create rect  10  68 160 118 -rx 0 \
    -fill "#b3d1f0" -stroke "#0055aa" -strokewidth 2
.top.p create rect 170  68 320 118 -rx 10 \
    -fill "#ffe066" -stroke "#cc8800" -strokewidth 2
.top.p create rect 330  68 490 118 -rx 20 \
    -fill "" -stroke "#cc3300" -strokewidth 2 -strokedasharray {6 3}

# --- 2. circle and ellipse ---
.top.p create text 10 134 -text "2. circle / ellipse  (antialiased on screen)" \
    -fontsize 10 -fill "#333333" -textanchor start
.top.p create circle  65 175 -r 35 \
    -fill "#ffcccc" -stroke "#cc0000" -strokewidth 2
.top.p create circle 165 175 -r 35 \
    -fill "" -stroke "#0000cc" -strokewidth 2
.top.p create ellipse 340 175 -rx 80 -ry 30 \
    -fill "#ccffcc" -stroke "#006600" -strokewidth 2

# --- 3. SVG path ---
.top.p create text 10 218 -text "3. path  (SVG path data: M L C Z ...)" \
    -fontsize 10 -fill "#333333" -textanchor start
# Diamond
.top.p create path "M 60 230 L 100 260 L 60 290 L 20 260 Z" \
    -fill "#ddeeff" -stroke "#003399" -strokewidth 2
# Bezier curve
.top.p create path "M 140 290 C 160 230 220 230 240 290" \
    -fill "" -stroke "#cc6600" -strokewidth 2.5
# Star via path
set cx 360; set cy 260; set r1 40; set r2 18
set pathdata "M"
for {set i 0} {$i < 10} {incr i} {
    set r [expr {($i%2) ? $r2 : $r1}]
    set a [expr {-3.14159265/2.0 + $i*3.14159265/5.0}]
    if {$i == 0} {
        append pathdata " [expr {$cx+$r*cos($a)}] [expr {$cy+$r*sin($a)}]"
    } else {
        append pathdata " L [expr {$cx+$r*cos($a)}] [expr {$cy+$r*sin($a)}]"
    }
}
append pathdata " Z"
.top.p create path $pathdata -fill "#ffe066" -stroke "#cc8800" -strokewidth 2

# --- 4. Opacity (-fillopacity) ---
.top.p create text 10 312 -text "4. -fillopacity  (semi-transparent, screen + PDF via itempdf)" \
    -fontsize 10 -fill "#333333" -textanchor start
foreach {cx col} {70 "#cc3300"  150 "#0055aa"  110 "#006600"} {
    .top.p create circle $cx 355 -r 38 \
        -fill $col -fillopacity 0.50 -stroke "" -strokewidth 0
}

# --- 5. Matrix transform ---
.top.p create text 10 402 -text "5. -matrix  (affine transform)" \
    -fontsize 10 -fill "#333333" -textanchor start
# Normal rect
.top.p create rect 10 415 90 450 \
    -fill "#e8f0ff" -stroke "#336699" -strokewidth 1.5
# Sheared
.top.p create rect 110 415 190 450 \
    -fill "#fff0e8" -stroke "#993300" -strokewidth 1.5 \
    -matrix {1 0.3 0 1 0 0}
# Rotated ~20 degrees
set a [expr {20*3.14159/180.0}]
.top.p create rect 220 415 300 450 \
    -fill "#e8ffe8" -stroke "#336600" -strokewidth 1.5 \
    -matrix [list [expr {cos($a)}] [expr {sin($a)}] \
                  [expr {-sin($a)}] [expr {cos($a)}] 0 0]

# --- Text ---
.top.p create text 10 455 \
    -text "All items above export to PDF via: \$pdf canvas .top.p -bbox \[.top.p bbox\] -x X -y Y" \
    -fontsize 8 -fill "#888888" -textanchor start

update idletasks

# ---------------------------------------------------------------------------
# PDF export  -- KEY: use -bbox [$pathName bbox]
# ---------------------------------------------------------------------------
set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
set lx  [dict get $ctx left]
set top [dict get $ctx top]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]

$pdf startPage
pdf4tcllib::page::header $pdf $ctx "Demo 52: tko::path SVG drawing -> PDF"
pdf4tcllib::page::footer $pdf $ctx \
    "Exported with: \$pdf canvas .top.p -bbox \[.top.p bbox\] -x X -y Y" 1

set y [expr {$top + 15}]

# THE CORRECT EXPORT: -bbox tells pdf4tcl the extent of the path canvas
$pdf canvas .top.p \
    -bbox [.top.p bbox all] \
    -x $lx \
    -y $y \
    -width  $CW \
    -height $CH

$pdf endPage
$pdf write -file $outPDF
$pdf destroy

destroy .top
destroy .
puts "Written: $outPDF"
puts ""
puts "Correct export syntax:"
puts "  \$pdf canvas \$pathName -bbox \[\$pathName bbox\] -x X -y Y"
puts ""
puts "Without -bbox: pdf4tcl may miss items or produce wrong output."
