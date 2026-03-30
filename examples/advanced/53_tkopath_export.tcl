#!/usr/bin/env wish
# demo-canvas-tkopath-export.tcl -- tko::path PDF export
#
# tko::path item types: rect, circle, ellipse, line, polyline, polygon,
#                       path, group, text, image, window
# matrix: {a b c d tx ty}  -- FLAT 6 numbers
# stroke: do NOT use "" -- use a color or omit strokewidth
#         "" causes "alloc invalid block" crash in tko::path
#
# Usage: wish demo-canvas-tkopath-export.tcl [outputdir]

package require Tk
package require tko

set demodir  [file dirname [file normalize [info script]]]
set reporoot [file normalize [file join $demodir ../..]]
set auto_path [linsert $auto_path 0 $reporoot]
package require pdf4tcl

catch { set ::path::antialias 1 }

set outdir [expr {$argc > 0 ? [lindex $argv 0] : \
    [file join $demodir out]}]
file mkdir $outdir
set outfile [file join $outdir demo-canvas-tkopath-export.pdf]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]

# ---------------------------------------------------------------------------
# Seite 1: Grundformen
# ---------------------------------------------------------------------------
$pdf startPage
$pdf setFont 14 Helvetica-Bold
$pdf text "tko::path Export -- Grundformen" -x 50 -y 50
$pdf setFont 9 Helvetica
$pdf setFillColor 0.4 0.4 0.4
$pdf text "rect (-rx), circle, ellipse, line, polyline, polygon, path, text" \
    -x 50 -y 65
$pdf setFillColor 0 0 0

wm withdraw .
tko::path .p1 -width 480 -height 510 -background white -highlightthickness 0
pack .p1

# rect
.p1 create text 10 6 -text "rect" -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start
.p1 create rect  10  20 160  70 -rx 10 \
    -fill "#b3d1f0" -stroke "#0055aa" -strokewidth 2
.p1 create rect 170  20 330  70 -rx 10 \
    -fill "#ffe8d0" -stroke "#cc3300" -strokewidth 2 \
    -strokedasharray {6 3}
.p1 create rect 340  20 470  70 -rx 20 \
    -fill "#f0e68c" -stroke "#8b6914" -strokewidth 1

# circle + ellipse
.p1 create text 10 82 -text "circle, ellipse" \
    -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start
.p1 create circle   55 130 -r 40 \
    -fill "#ffcccc" -stroke "#cc0000" -strokewidth 2
.p1 create circle  155 130 -r 40 \
    -fill "#e0e8ff" -stroke "#0000cc" -strokewidth 2
.p1 create ellipse 300 130 -rx 80 -ry 35 \
    -fill "#ccffcc" -stroke "#006600" -strokewidth 2
.p1 create ellipse 430 130 -rx 30 -ry 50 \
    -fill "#e0d0ff" -stroke "#550088" -strokewidth 2

# line + polyline
.p1 create text 10 182 -text "line, polyline" \
    -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start
.p1 create line 10 200 200 200 -stroke black -strokewidth 1
.p1 create line 10 215 200 215 \
    -stroke "#0055aa" -strokewidth 2 -strokedasharray {8 3}
.p1 create polyline 220 195 270 215 320 195 370 215 420 195 \
    -stroke "#cc3300" -strokewidth 2 -fill "#ffe0d0"

# polygon
.p1 create text 10 235 -text "polygon" \
    -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start
.p1 create polygon \
     60 295  20 265  35 220  90 220  105 265 \
    -fill "#ddeeff" -stroke "#003399" -strokewidth 2
.p1 create polygon \
    200 295 160 265 175 220 230 220 245 265 \
    -fill "#ffeedd" -stroke "#993300" -strokewidth 2
.p1 create polygon \
    340 295 300 265 315 220 370 220 385 265 \
    -fill "#eeffee" -stroke "#009933" -strokewidth 2

# path (SVG)
.p1 create text 10 312 -text "path (SVG)" \
    -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start
.p1 create path "M 10 380 C 60 320 120 420 180 380 C 240 320 300 420 360 380" \
    -fill "#f0f0f0" -stroke "#880088" -strokewidth 2
.p1 create path "M 10 450 L 60 420 L 60 480 Z" \
    -fill "#ffd0a0" -stroke "#cc6600" -strokewidth 2
.p1 create path "M 120 450 Q 180 400 240 450 Q 300 500 360 450" \
    -fill "#e0f0ff" -stroke "#0055cc" -strokewidth 2
.p1 create path "M 390 420 A 40 40 0 0 1 470 420 Z" \
    -fill "#ccffcc" -stroke "#009900" -strokewidth 2

# text
.p1 create text 10 495 -text "text" \
    -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start
.p1 create text 90 510 -text "tko::path" \
    -fontfamily Helvetica -fontsize 20 -fontweight bold \
    -fill "#1a3f7a" -textanchor middle
.p1 create text 250 510 -text "SVG-style" \
    -fontfamily Helvetica -fontsize 14 \
    -fill "#cc3300" -textanchor middle
.p1 create text 400 510 -text "Italic" \
    -fontfamily Helvetica -fontsize 18 -fontslant italic \
    -fill "#006600" -textanchor middle

update
set bb [.p1 bbox all]
$pdf canvas .p1 -bbox $bb -x 50 -y 80 -width 480 -height 510
destroy .p1
$pdf endPage

# ---------------------------------------------------------------------------
# Seite 2: matrix (FLACH {a b c d tx ty}) + window item
# ---------------------------------------------------------------------------
$pdf startPage
$pdf setFont 14 Helvetica-Bold
$pdf text "tko::path Export -- -matrix + window item" -x 50 -y 50
$pdf setFont 9 Helvetica
$pdf setFillColor 0.4 0.4 0.4
$pdf text "-matrix {a b c d tx ty} (flat 6 numbers)  |  window: silently skipped in PDF" \
    -x 50 -y 65
$pdf setFillColor 0 0 0

tko::path .p2 -width 480 -height 380 -background white -highlightthickness 0
pack .p2

# matrix -- tko::path: FLACHE Liste {a b c d tx ty}
.p2 create text 10 6 \
    -text "matrix (flat): rect mit Rotation/Scherung" \
    -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start

set pi 3.14159265358979

# Rotation
foreach {angle col cx} {
    0  "#cc0000"  60
    30 "#0055aa" 170
    60 "#006600" 280
    90 "#880088" 390
} {
    set rad [expr {$angle * $pi / 180.0}]
    set c   [expr {cos($rad)}]
    set s   [expr {sin($rad)}]
    # tko::path: FLACHE Matrix {a b c d tx ty}
    .p2 create rect 0 -15 80 15 \
        -fill $col -stroke $col -strokewidth 0.5 \
        -matrix [list $c $s [expr {-$s}] $c $cx 80]
}

# Scherung
.p2 create text 10 112 -text "Scherung (-matrix)" \
    -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start
.p2 create rect 10 125 150 175 \
    -fill "#ddeeff" -stroke "#003399" -strokewidth 2
.p2 create rect 170 125 310 175 \
    -fill "#ffeedd" -stroke "#993300" -strokewidth 2 \
    -matrix {1 0.3 0 1 0 0}
.p2 create rect 330 125 470 175 \
    -fill "#eeffee" -stroke "#009933" -strokewidth 2 \
    -matrix {1 0 0.3 1 0 0}

# fillopacity -- WICHTIG: stroke nie "" bei tko::path!
.p2 create text 10 196 -text "-fillopacity (stroke mit Farbe, nie \"\")" \
    -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start
foreach {cx col} {70 "#cc0000" 160 "#0055aa" 115 "#006600"} {
    .p2 create circle $cx 255 -r 45 \
        -fill $col -fillopacity 0.5 \
        -stroke $col -strokewidth 0.5
}

# window item -- wird im PDF still übersprungen
.p2 create text 10 310 \
    -text "window item -- im PDF still übersprungen (kein Crash seit 0.9.4.24)" \
    -fontfamily Helvetica -fontsize 9 -fontweight bold -textanchor start
.p2 create rect 10 325 200 370 \
    -fill "#b3d1f0" -stroke "#0055aa" -strokewidth 2
.p2 create circle 290 347 -r 22 \
    -fill "#ccffcc" -stroke "#006600" -strokewidth 2
# Window Item erstellen -- erscheint auf Screen aber nicht im PDF
button .p2.b -text "Button (window)" -font {Helvetica 8}
.p2 create window 380 347 -window .p2.b

update
set bb [.p2 bbox all]
$pdf canvas .p2 -bbox $bb -x 50 -y 80 -width 480 -height 380
destroy .p2
$pdf endPage

$pdf write -file $outfile
$pdf destroy

puts "tko::path demo: $outfile"
puts ""
puts "HINWEIS: -stroke \"\" vermeiden bei tko::path -> alloc invalid block"
puts "Stattdessen: -stroke \$col -strokewidth 0.5"
