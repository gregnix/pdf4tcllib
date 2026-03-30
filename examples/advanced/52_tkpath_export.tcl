#!/usr/bin/env wish
# demo-canvas-tkpath-export.tcl -- tkpath (::tkp::canvas, PathCanvas) PDF export
#
# tkpath 0.4.2 item types: pline, polyline, ppolygon, prect, circle, ellipse,
#                          path, group, ptext, pimage
# matrix: {{a b} {c d} {tx ty}}  -- NESTED 3x2
# stroke: "" = no stroke (ok in tkpath)
#
# Usage: wish demo-canvas-tkpath-export.tcl [outputdir]

package require Tk
package require tkpath 0.3.3

set demodir  [file dirname [file normalize [info script]]]
set reporoot [file normalize [file join $demodir ../..]]
set auto_path [linsert $auto_path 0 $reporoot]
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : \
    [file join $demodir out]}]
file mkdir $outdir
set outfile [file join $outdir demo-canvas-tkpath-export.pdf]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]

# ---------------------------------------------------------------------------
# Seite 1: Grundformen
# ---------------------------------------------------------------------------
$pdf startPage
$pdf setFont 14 Helvetica-Bold
$pdf text "tkpath Export -- Grundformen" -x 50 -y 50
$pdf setFont 9 Helvetica
$pdf setFillColor 0.4 0.4 0.4
$pdf text "prect (-rx), circle, ellipse, pline, polyline, ppolygon, path, ptext" \
    -x 50 -y 65
$pdf setFillColor 0 0 0

wm withdraw .
tkp::canvas .c1 -width 480 -height 510 -background white -highlightthickness 0
pack .c1

# prect
.c1 create text 10 6 -text "prect" -font {Helvetica 9 bold} -anchor w
.c1 create prect  10  20 160  70 -rx 10 \
    -fill "#b3d1f0" -stroke "#0055aa" -strokewidth 2
.c1 create prect 170  20 330  70 -rx 10 \
    -fill "" -stroke "#cc3300" -strokewidth 2 \
    -strokedasharray {6 3}
.c1 create prect 340  20 470  70 -rx 20 \
    -fill "#f0e68c" -stroke "#8b6914" -strokewidth 1

# circle + ellipse
.c1 create text 10 82 -text "circle, ellipse" -font {Helvetica 9 bold} -anchor w
.c1 create circle   55 130 -r 40 \
    -fill "#ffcccc" -stroke "#cc0000" -strokewidth 2
.c1 create circle  155 130 -r 40 \
    -fill "" -stroke "#0000cc" -strokewidth 2
.c1 create ellipse 300 130 -rx 80 -ry 35 \
    -fill "#ccffcc" -stroke "#006600" -strokewidth 2
.c1 create ellipse 430 130 -rx 30 -ry 50 \
    -fill "#e0d0ff" -stroke "#550088" -strokewidth 2

# pline + polyline
.c1 create text 10 182 -text "pline, polyline" -font {Helvetica 9 bold} -anchor w
.c1 create pline 10 200 200 200 -stroke black -strokewidth 1
.c1 create pline 10 215 200 215 \
    -stroke "#0055aa" -strokewidth 2 -strokedasharray {8 3}
.c1 create polyline 220 195 270 215 320 195 370 215 420 195 \
    -stroke "#cc3300" -strokewidth 2 -fill ""

# ppolygon
.c1 create text 10 235 -text "ppolygon" -font {Helvetica 9 bold} -anchor w
.c1 create ppolygon \
     60 295  20 265  35 220  90 220  105 265 \
    -fill "#ddeeff" -stroke "#003399" -strokewidth 2
.c1 create ppolygon \
    200 295 160 265 175 220 230 220 245 265 \
    -fill "#ffeedd" -stroke "#993300" -strokewidth 2
.c1 create ppolygon \
    340 295 300 265 315 220 370 220 385 265 \
    -fill "#eeffee" -stroke "#009933" -strokewidth 2

# path (SVG)
.c1 create text 10 312 -text "path (SVG)" -font {Helvetica 9 bold} -anchor w
.c1 create path "M 10 380 C 60 320 120 420 180 380 C 240 320 300 420 360 380" \
    -fill "" -stroke "#880088" -strokewidth 2
.c1 create path "M 10 450 L 60 420 L 60 480 Z" \
    -fill "#ffd0a0" -stroke "#cc6600" -strokewidth 2
.c1 create path "M 120 450 Q 180 400 240 450 Q 300 500 360 450" \
    -fill "" -stroke "#0055cc" -strokewidth 2
.c1 create path "M 390 420 A 40 40 0 0 1 470 420 Z" \
    -fill "#ccffcc" -stroke "#009900" -strokewidth 2

# ptext
.c1 create text 10 495 -text "ptext" -font {Helvetica 9 bold} -anchor w
.c1 create ptext  90 510 -text "tkpath" \
    -fontfamily Helvetica -fontsize 20 -fontweight bold \
    -fill "#1a3f7a" -textanchor middle
.c1 create ptext 240 510 -text "PathCanvas" \
    -fontfamily Helvetica -fontsize 14 \
    -fill "#cc3300" -textanchor middle
.c1 create ptext 390 510 -text "Italic" \
    -fontfamily Helvetica -fontsize 18 -fontslant italic \
    -fill "#006600" -textanchor middle

update
set bb [.c1 bbox all]
$pdf canvas .c1 -bbox $bb -x 50 -y 80 -width 480 -height 510
destroy .c1
$pdf endPage

# ---------------------------------------------------------------------------
# Seite 2: Gradienten + matrix (VERSCHACHTELT {{a b} {c d} {tx ty}})
# ---------------------------------------------------------------------------
$pdf startPage
$pdf setFont 14 Helvetica-Bold
$pdf text "tkpath Export -- Gradienten + -matrix" -x 50 -y 50
$pdf setFont 9 Helvetica
$pdf setFillColor 0.4 0.4 0.4
$pdf text "gradient create linear/radial, -matrix {{a b} {c d} {tx ty}} (nested)" \
    -x 50 -y 65
$pdf setFillColor 0 0 0

tkp::canvas .c2 -width 480 -height 430 -background white -highlightthickness 0
pack .c2

# Lineare Gradienten
.c2 create text 10 6 -text "Lineare Gradienten" \
    -font {Helvetica 9 bold} -anchor w
set g1 [.c2 gradient create linear \
    -stops {{0 "#b3d1f0"} {1 "#0055aa"}}]
.c2 create prect  10 20 230 65 -fill $g1 -stroke "" -rx 6
set g2 [.c2 gradient create linear \
    -stops {{0 "#ffcccc"} {0.5 "#ff6600"} {1 "#cc0000"}}]
.c2 create prect 245 20 470 65 -fill $g2 -stroke "" -rx 6

set g3 [.c2 gradient create linear \
    -stops {{0 "#ccffcc"} {1 "#006600"}} -lineartransition {0 0 0 1}]
.c2 create prect  10 75 230 120 -fill $g3 -stroke "" -rx 6
set g4 [.c2 gradient create linear \
    -stops {{0 "#f0e68c"} {0.4 "#ff6600"} {1 "#8b0000"}}]
.c2 create prect 245 75 470 120 -fill $g4 -stroke "" -rx 6

# Radiale Gradienten
.c2 create text 10 132 -text "Radiale Gradienten" \
    -font {Helvetica 9 bold} -anchor w
set r1 [.c2 gradient create radial -stops {{0 white} {1 "#0055aa"}}]
.c2 create circle  70 180 -r 45 -fill $r1 -stroke ""
set r2 [.c2 gradient create radial \
    -stops {{0 white} {0.6 "#ff6600"} {1 "#cc0000"}}]
.c2 create circle 190 180 -r 45 -fill $r2 -stroke ""
set r3 [.c2 gradient create radial -stops {{0 "#ffff00"} {1 "#006600"}}]
.c2 create ellipse 345 180 -rx 85 -ry 45 -fill $r3 -stroke ""

# matrix -- tkpath: VERSCHACHTELT {{a b} {c d} {tx ty}}
.c2 create text 10 238 \
    -text "matrix -- tkpath Format: {{a b} {c d} {tx ty}}" \
    -font {Helvetica 9 bold} -anchor w
set pi 3.14159265358979
foreach {angle col cx} {
    0  "#cc0000"  60
    30 "#0055aa" 170
    60 "#006600" 280
    90 "#880088" 390
} {
    set rad [expr {$angle * $pi / 180.0}]
    set c   [expr {cos($rad)}]
    set s   [expr {sin($rad)}]
    # tkpath: VERSCHACHTELTE Matrix
    .c2 create prect 0 -15 80 15 \
        -fill $col -stroke "" \
        -matrix [list [list $c $s] [list [expr {-$s}] $c] [list $cx 300]]
}

# fillopacity (stroke mit Farbe angeben -- nicht leer!)
.c2 create text 10 340 -text "-fillopacity" \
    -font {Helvetica 9 bold} -anchor w
foreach {cx col} {70 "#cc0000" 160 "#0055aa" 115 "#006600"} {
    .c2 create circle $cx 390 -r 45 \
        -fill $col -fillopacity 0.5 \
        -stroke $col -strokewidth 0.5
}

update
set bb [.c2 bbox all]
$pdf canvas .c2 -bbox $bb -x 50 -y 80 -width 480 -height 430
destroy .c2
$pdf endPage

$pdf write -file $outfile
$pdf destroy

puts "tkpath demo: $outfile"
