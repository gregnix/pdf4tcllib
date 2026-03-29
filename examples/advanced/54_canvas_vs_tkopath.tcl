#!/usr/bin/env wish
# ===========================================================================
# Demo 54: canvas vs tko::path -- identical drawing, side by side
# ===========================================================================
# The SAME shapes are drawn twice -- once with tk::canvas, once with tko::path.
# Both are exported to PDF.
#
# Screen comparison:
#   tk::canvas:  pixelated edges, no transparency
#   tko::path:   antialiased edges (cairo), semi-transparent circles
#
# PDF comparison:
#   Both look nearly identical in the PDF.
#   tko::path items (circle, path, opacity) DO export via itempdf.
#   Key: use -bbox option: $pdf canvas $w -bbox [$w bbox] -x X -y Y
#
# Item name mapping (tk::canvas -> tko::path):
#   rectangle  ->  rect       (same coords x1 y1 x2 y2, adds -rx/-ry)
#   oval       ->  circle     (center + -r radius, not bbox)
#   line       ->  line       (same)
#   polygon    ->  polygon    (same, or use path)
#   text       ->  text       (-fontsize -fontfamily instead of -font)
#   arc        ->  path       (SVG arc syntax)
#   (none)     ->  ellipse    (center + -rx -ry)
#
# Usage: wish examples/advanced/54_canvas_vs_tkopath.tcl [outputdir]
# Requires: tko
# ===========================================================================

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set hasTko [expr {![catch {package require tko}]}]
catch { set ::path::antialias 1 }

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_54_canvas_vs_tkopath.pdf"]

set PW 220
set PH 440

# ---------------------------------------------------------------------------
# Draw on standard tk::canvas
# ---------------------------------------------------------------------------
proc draw_canvas {w} {
    global PW
    $w create text [expr {$PW/2}] 18 \
        -text "tk::canvas" -font {Helvetica 12 bold} \
        -fill "#1a3f7a" -anchor center
    $w create line 10 34 [expr {$PW-10}] 34 -fill "#cccccc" -width 1

    # Rectangles
    $w create text 10 50 -text "rectangle" \
        -font {Helvetica 8 bold} -fill "#555" -anchor w
    $w create rectangle  10  62 120 102 \
        -fill "#b3d1f0" -outline "#0055aa" -width 2
    $w create rectangle 135  62 245 102 \
        -fill "#ffe066" -outline "#cc8800" -width 2
    $w create rectangle 260  62 350 102 \
        -fill "" -outline "#cc3300" -width 2 -dash {6 3}

    # Oval (no rounded rect support)
    $w create text 10 118 -text "oval  (no rounded corners)" \
        -font {Helvetica 8 bold} -fill "#555" -anchor w
    $w create oval  10 130  90 190 \
        -fill "#ffcccc" -outline "#cc0000" -width 2
    $w create oval 105 130 185 190 \
        -fill "" -outline "#0000cc" -width 2
    $w create oval 200 130 350 175 \
        -fill "#ccffcc" -outline "#006600"

    # Lines
    $w create text 10 204 -text "line" \
        -font {Helvetica 8 bold} -fill "#555" -anchor w
    $w create line  10 218 200 218 -fill black -width 2
    $w create line  10 232 200 232 -fill "#0055aa" -width 2 -dash {8 3}
    $w create line 220 210 350 240 -fill "#006600" -width 3 -arrow both

    # Polygon (star)
    $w create text 10 258 -text "polygon (star)" \
        -font {Helvetica 8 bold} -fill "#555" -anchor w
    set pts {}
    set cx 80; set cy 305
    for {set i 0} {$i < 10} {incr i} {
        set r [expr {($i%2) ? 18 : 40}]
        set a [expr {-3.14159265/2.0 + $i*3.14159265/5.0}]
        lappend pts [expr {$cx+$r*cos($a)}] [expr {$cy+$r*sin($a)}]
    }
    $w create polygon {*}$pts -fill "#ffe066" -outline "#cc8800" -width 2

    # Text
    $w create text 10 360 -text "text" \
        -font {Helvetica 8 bold} -fill "#555" -anchor w
    $w create text  10 378 -text "Normal"  -font {Helvetica 11} -fill black -anchor w
    $w create text 100 378 -text "Bold"    -font {Helvetica 11 bold} -fill "#003399" -anchor w
    $w create text 200 378 -text "Italic"  -font {Helvetica 11 italic} -fill "#cc3300" -anchor w

    # Opacity: NOT in tk::canvas
    $w create text 10 404 -text "opacity: NOT supported" \
        -font {Helvetica 8 bold} -fill "#aaaaaa" -anchor w
    foreach {cx col} {50 "#cc3300" 100 "#0055aa" 75 "#006600"} {
        $w create oval [expr {$cx-30}] 418 [expr {$cx+30}] 458 \
            -fill $col -outline ""
    }
    $w create text 165 438 \
        -text "(solid only)" -font {Helvetica 8 italic} -fill "#aaa" -anchor w
}

# ---------------------------------------------------------------------------
# Draw with tko::path
# ---------------------------------------------------------------------------
proc draw_tkopath {w} {
    global PW hasTko
    if {!$hasTko} { draw_canvas $w; return }

    $w create text [expr {$PW/2}] 18 \
        -text "tko::path  (antialiased)" \
        -fontsize 12 -fill "#cc3300" -textanchor middle
    $w create line 10 34 [expr {$PW-10}] 34 -stroke "#cccccc" -strokewidth 1

    # rect (rounded corners via -rx)
    $w create text 10 50 -text "rect  (-rx for rounded corners)" \
        -fontsize 8 -fill "#555555" -textanchor start
    $w create rect  10  62 120 102 -rx 0 \
        -fill "#b3d1f0" -stroke "#0055aa" -strokewidth 2
    $w create rect 135  62 245 102 -rx 8 \
        -fill "#ffe066" -stroke "#cc8800" -strokewidth 2
    $w create rect 260  62 350 102 -rx 0 \
        -fill "" -stroke "#cc3300" -strokewidth 2 -strokedasharray {6 3}

    # circle / ellipse (antialiased)
    $w create text 10 118 -text "circle / ellipse  (smooth edges, antialiased)" \
        -fontsize 8 -fill "#555555" -textanchor start
    $w create circle  50 160 -r 30 \
        -fill "#ffcccc" -stroke "#cc0000" -strokewidth 2
    $w create circle 145 160 -r 30 \
        -fill "" -stroke "#0000cc" -strokewidth 2
    $w create ellipse 275 160 -rx 75 -ry 30 \
        -fill "#ccffcc" -stroke "#006600"

    # line
    $w create text 10 204 -text "line" \
        -fontsize 8 -fill "#555555" -textanchor start
    $w create line  10 218 200 218 -stroke black -strokewidth 2
    $w create line  10 232 200 232 -stroke "#0055aa" -strokewidth 2 \
        -strokedasharray {8 3}
    $w create line 220 210 350 240 -stroke "#006600" -strokewidth 3 \
        -endarrow 1 -startarrow 1

    # path (SVG star)
    $w create text 10 258 -text "path  (SVG path data)" \
        -fontsize 8 -fill "#555555" -textanchor start
    set cx 80; set cy 305
    set pd "M"
    for {set i 0} {$i < 10} {incr i} {
        set r [expr {($i%2) ? 18 : 40}]
        set a [expr {-3.14159265/2.0 + $i*3.14159265/5.0}]
        if {$i==0} { append pd " [expr {$cx+$r*cos($a)}] [expr {$cy+$r*sin($a)}]" } \
        else        { append pd " L [expr {$cx+$r*cos($a)}] [expr {$cy+$r*sin($a)}]" }
    }
    append pd " Z"
    $w create path $pd -fill "#ffe066" -stroke "#cc8800" -strokewidth 2

    # text
    $w create text 10 360 -text "text" \
        -fontsize 8 -fill "#555555" -textanchor start
    $w create text  10 378 -text "Normal" \
        -fontsize 11 -fill black -textanchor start
    $w create text 100 378 -text "Bold" \
        -fontsize 11 -fontweight bold -fill "#003399" -textanchor start
    $w create text 200 378 -text "Italic" \
        -fontsize 11 -fontslant italic -fill "#cc3300" -textanchor start

    # opacity (tko::path only, exports via itempdf)
    $w create text 10 404 -text "opacity: -fillopacity  (exports via itempdf)" \
        -fontsize 8 -fill "#006600" -textanchor start
    foreach {cx col} {50 "#cc3300" 100 "#0055aa" 75 "#006600"} {
        $w create circle $cx 438 -r 30 \
            -fill $col -fillopacity 0.55 -stroke "" -strokewidth 0
    }
    $w create text 165 438 \
        -text "(semi-transparent)" -fontsize 8 -fill "#006600" -textanchor start
}

# ---------------------------------------------------------------------------
# Build UI
# ---------------------------------------------------------------------------
wm title . "Demo 54: canvas vs tko::path"
wm resizable . 0 0

frame .top -pady 6; pack .top
label .top.t \
    -text "Demo 54: tk::canvas vs tko::path -- same shapes, side by side" \
    -font {Helvetica 11 bold}
pack .top.t

frame .panels; pack .panels -padx 12

# Left
frame .panels.left; pack .panels.left -side left -padx 4
label .panels.left.l -text "tk::canvas" \
    -font {Helvetica 10 bold} -fg "#1a3f7a"
pack .panels.left.l
canvas .panels.left.c -width $PW -height $PH \
    -background white -relief sunken -borderwidth 1
.panels.left.c configure -relief sunken -borderwidth 1
pack .panels.left.c
draw_canvas .panels.left.c

# Right
frame .panels.right; pack .panels.right -side left -padx 4
if {$hasTko} {
    label .panels.right.l -text "tko::path  (antialiased)" \
        -font {Helvetica 10 bold} -fg "#cc3300"
    pack .panels.right.l
    tko::path .panels.right.c -width $PW -height $PH -background white
} else {
    label .panels.right.l -text "tko not installed -- canvas fallback" \
        -font {Helvetica 10} -fg "#888"
    pack .panels.right.l
    canvas .panels.right.c -width $PW -height $PH -background white
}
.panels.right.c configure -relief sunken -borderwidth 1
pack .panels.right.c
draw_tkopath .panels.right.c
update

frame .btns -pady 6; pack .btns
button .btns.exp -text "Export PDF" -command {
    set ::exported 1
    exportPDF
    .btns.exp configure -text "Written: [file tail $::outPDF]" -state disabled
}
button .btns.q -text "Close" -command exit
pack .btns.exp .btns.q -side left -padx 8

# ---------------------------------------------------------------------------
# PDF export
# ---------------------------------------------------------------------------
proc exportPDF {} {
    global outPDF PW PH

    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
    set lx  [dict get $ctx left]
    set top [dict get $ctx top]
    set tw  [dict get $ctx text_w]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]

    # --- Page 1: side by side ---
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 54: canvas vs tko::path"
    pdf4tcllib::page::footer $pdf $ctx \
        "Exported with -bbox option (key for tko::path)" 1

    set y [expr {$top + 14}]
    $pdf setFont 9 Helvetica-Bold
    $pdf setFillColor 0.1 0.25 0.48
    $pdf text "tk::canvas" -x $lx -y $y
    $pdf setFillColor 0.8 0.2 0
    $pdf text "tko::path" -x [expr {$lx + $PW + 14}] -y $y
    $pdf setFillColor 0 0 0
    set y [expr {$y + 12}]

    # Left: standard canvas -- no -bbox needed (all items known)
    $pdf canvas .panels.left.c \
        -x $lx -y $y -width $PW -height $PH

    # Right: tko::path -- -bbox is REQUIRED for correct export
    $pdf canvas .panels.right.c \
        -bbox [.panels.right.c bbox all] \
        -x [expr {$lx + $PW + 14}] -y $y -width $PW -height $PH

    $pdf endPage

    # --- Page 2: item mapping table ---
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 54: Item name mapping"
    pdf4tcllib::page::footer $pdf $ctx \
        "tk::canvas item names -> tko::path equivalents" 2

    set y [expr {$top + 20}]
    $pdf setFont 11 Helvetica-Bold
    $pdf text "Item name mapping: tk::canvas -> tko::path" -x $lx -y $y
    set y [expr {$y + 18}]

    set rows {
        {"tk::canvas"     "tko::path"   "Notes"}
        {"rectangle x1 y1 x2 y2"  "rect x1 y1 x2 y2"  "tko adds -rx/-ry for rounded corners"}
        {"oval x1 y1 x2 y2"       "circle cx cy -r R"  "tko: center+radius, not bbox"}
        {"(none)"                  "ellipse cx cy -rx -ry"  "tko only"}
        {"line x1 y1 x2 y2"       "line x1 y1 x2 y2"  "same; tko uses -stroke not -fill"}
        {"polygon x y ..."         "polygon x y ..."    "same; or use path for SVG syntax"}
        {"arc (limited)"           "path M ... A ... Z"  "tko: full SVG arc syntax"}
        {"text x y -text ..."      "text x y -text ..."  "tko: -fontsize -fontfamily -fontweight"}
        {"image x y -image ..."    "image x y -image ..."  "same anchor logic"}
    }

    set cw {160 160 200}
    set rowIdx 0
    foreach row $rows {
        if {$rowIdx == 0} {
            $pdf setFillColor 0.85 0.87 0.95
            $pdf rectangle $lx $y 520 15 -filled 1
            $pdf setFillColor 0 0 0
            $pdf setFont 8 Helvetica-Bold
        } else {
            if {$rowIdx % 2} {
                $pdf setFillColor 0.97 0.97 0.97
                $pdf rectangle $lx $y 520 13 -filled 1
                $pdf setFillColor 0 0 0
            }
            $pdf setFont 8 Helvetica
        }
        set cx $lx
        foreach cell $row w $cw {
            $pdf text $cell -x [expr {$cx+3}] -y [expr {$y+10}]
            set cx [expr {$cx + $w}]
        }
        set y [expr {$y + ($rowIdx ? 13 : 15)}]
        incr rowIdx
    }
    $pdf setStrokeColor 0.6 0.6 0.6
    $pdf setLineWidth 0.5
    $pdf rectangle $lx [expr {$top+38}] 520 [expr {$y - ($top+38)}]
    set y [expr {$y + 20}]

    $pdf setFont 10 Helvetica-Bold
    $pdf text "Key difference: export syntax" -x $lx -y $y
    set y [expr {$y + 14}]
    $pdf setFont 9 Courier
    $pdf text "\$pdf canvas \$canvas_widget -x X -y Y -width W -height H" \
        -x $lx -y $y
    set y [expr {$y + 14}]
    $pdf text "\$pdf canvas \$tkopath_widget -bbox \[\$w bbox\] -x X -y Y -width W -height H" \
        -x $lx -y $y
    set y [expr {$y + 20}]
    $pdf setFont 9 Helvetica
    $pdf text "The -bbox option is required for tko::path to correctly export all items." \
        -x $lx -y $y
    set y [expr {$y + 13}]
    $pdf text "Without -bbox, pdf4tcl does not know the coordinate space and may miss items." \
        -x $lx -y $y
    set y [expr {$y + 13}]
    $pdf text "Also enable antialiasing: set ::path::antialias 1  (screen only, cairo/GDI+)" \
        -x $lx -y $y

    $pdf endPage
    $pdf write -file $outPDF
    $pdf destroy
    puts "Written: $outPDF"
}

# Run headless if -batch flag given
if {[lsearch $argv -batch] >= 0} {
    update
    exportPDF
    destroy .
}
