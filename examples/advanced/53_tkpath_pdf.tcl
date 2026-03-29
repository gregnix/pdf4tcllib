#!/usr/bin/env wish
# ===========================================================================
# Demo 53: tko::path -- font size conversion for PDF export
# ===========================================================================
# tko::path uses -fontsize in PIXELS.
# pdf4tcl setFont uses POINTS.
#
# Conversion at 96 dpi:
#   points = pixels * 0.75
#   pixels = points / 0.75
#
# Usage: wish examples/advanced/53_tkpath_pdf.tcl [outputdir]
# Requires: tko
# ===========================================================================

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

catch { set ::path::antialias 1 }
if {[catch {package require tko} err]} {
    puts stderr "tko not available: $err"; exit 1
}

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_53_tkpath_pdf.pdf"]

proc px2pt {px} { expr {$px * 0.75} }
proc pt2px {pt} { expr {$pt / 0.75} }

# ---------------------------------------------------------------------------
# tkoToPdf: VISIBLE toplevel off-screen, draw, export, destroy
# orient true: y is top-left corner of the canvas in the PDF
# ---------------------------------------------------------------------------
proc tkoToPdf {pdf x y w h drawScript} {
    toplevel .tmp
    wm geometry .tmp "${w}x${h}+2000+2000"
    tko::path .tmp.p -width $w -height $h -background white
    pack .tmp.p -fill both -expand 1
    uplevel 1 $drawScript
    update
    $pdf canvas .tmp.p -bbox [.tmp.p bbox all] -x $x -y $y -width $w -height $h
    destroy .tmp
}

# ---------------------------------------------------------------------------
# Setup: orient true = top-left origin, y grows downward
# page::context also configured for orient true
# ---------------------------------------------------------------------------
wm withdraw .

set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
set lx  [dict get $ctx left]
set top [dict get $ctx top]      ;# small value = near top of page
set tw  [dict get $ctx text_w]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]

# ===========================================================================
# Page 1: Font size conversion
# ===========================================================================
$pdf startPage
pdf4tcllib::page::header $pdf $ctx "Demo 53: tko::path -- font size conversion"
pdf4tcllib::page::footer $pdf $ctx "px2pt: points = pixels * 0.75" 1

# y grows DOWNWARD from top
set y [expr {$top + 20}]

$pdf setFont 11 Helvetica-Bold
$pdf text "Problem: tko::path -fontsize is pixels, pdf4tcl setFont is points" \
    -x $lx -y $y
set y [expr {$y + 18}]
$pdf setFont 10 Helvetica
$pdf text "At 96 dpi:  points = pixels * 0.75  (e.g. 20 px -> 15 pt)" -x $lx -y $y
set y [expr {$y + 18}]
$pdf text "Conversion:  proc px2pt {px} { expr {\$px * 0.75} }" -x $lx -y $y
set y [expr {$y + 28}]

$pdf setLineWidth 0.5
$pdf setStrokeColor 0.7 0.7 0.7
$pdf line $lx $y [expr {$lx + $tw}] $y
$pdf setStrokeColor 0 0 0
set y [expr {$y + 18}]

# --- WRONG ---
$pdf setFont 11 Helvetica-Bold
$pdf setFillColor 0.7 0.1 0.1
$pdf text "WRONG: -fontsize 20  (px) used directly as setFont 20 (pt)" -x $lx -y $y
$pdf setFillColor 0 0 0
set y [expr {$y + 14}]
$pdf setFont 9 Helvetica
$pdf text "Font appears too large -- 20px should be 15pt, not 20pt" -x $lx -y $y
set y [expr {$y + 14}]

set canvasH 40
tkoToPdf $pdf $lx $y 480 $canvasH {
    .tmp.p create text 10 28 \
        -text "Hallo Welt  (fontsize 20px, wrong)" \
        -fontsize 20 -fill "#990000" -textanchor start
}
set y [expr {$y + $canvasH + 22}]

# --- RIGHT ---
$pdf setFont 11 Helvetica-Bold
$pdf setFillColor 0 0.5 0
set rightPx [expr {int([pt2px 15])}]
$pdf text "RIGHT: -fontsize ${rightPx}px  (= 15pt via pt2px 15)" -x $lx -y $y
$pdf setFillColor 0 0 0
set y [expr {$y + 14}]
$pdf setFont 9 Helvetica
$pdf text "px2pt 20 = [px2pt 20]pt   |   pt2px 15 = [pt2px 15]px   |   use int() to avoid float" \
    -x $lx -y $y
set y [expr {$y + 14}]

tkoToPdf $pdf $lx $y 480 $canvasH {
    .tmp.p create text 10 28 \
        -text "Hallo Welt  (fontsize [set ::rightPx]px = 15pt, correct)" \
        -fontsize $::rightPx -fill "#006600" -textanchor start
}
set y [expr {$y + $canvasH + 22}]

# --- pdf4tcl direct reference ---
$pdf setFont 11 Helvetica-Bold
$pdf text "Reference: pdf4tcl setFont 15  (15pt direct, no tko::path)" -x $lx -y $y
set y [expr {$y + 20}]
$pdf setFont 15 Helvetica
$pdf setFillColor 0 0 0.6
$pdf text "Hallo Welt  (setFont 15pt)" -x [expr {$lx + 10}] -y $y
$pdf setFillColor 0 0 0
set y [expr {$y + 28}]

$pdf line $lx $y [expr {$lx + $tw}] $y
set y [expr {$y + 18}]

# --- Conversion table ---
$pdf setFont 10 Helvetica-Bold
$pdf text "Conversion table  (96 dpi):" -x $lx -y $y
set y [expr {$y + 16}]
$pdf setFont 9 Helvetica
set col 0
foreach {px pt} {8 6  10 7.5  12 9  14 10.5  16 12  20 15  24 18  32 24} {
    set cx [expr {$lx + $col * 120}]
    $pdf text "${px}px -> ${pt}pt" -x $cx -y $y
    incr col
    if {$col >= 4} { set col 0; set y [expr {$y + 14}] }
}

$pdf endPage

# ===========================================================================
# Page 2: What exports via $pdf canvas
# ===========================================================================
$pdf startPage
pdf4tcllib::page::header $pdf $ctx "Demo 53: tko::path items -- PDF export"
pdf4tcllib::page::footer $pdf $ctx "text+lines: yes  /  path circle gradient: no" 2

set y [expr {$top + 20}]

$pdf setFont 11 Helvetica-Bold
$pdf text "What tko::path items export via \$pdf canvas:" -x $lx -y $y
set y [expr {$y + 20}]

# --- Exports correctly ---
$pdf setFont 10 Helvetica-Bold
$pdf setFillColor 0 0.45 0
$pdf text "Exports with \$pdf canvas -bbox: text, line, rect, circle, path, ellipse" -x $lx -y $y
$pdf setFillColor 0 0 0
set y [expr {$y + 14}]
$pdf setFont 9 Helvetica
$pdf text "(visible on screen AND in PDF)" -x [expr {$lx+10}] -y $y
set y [expr {$y + 12}]

set panelH 60
tkoToPdf $pdf $lx $y 480 $panelH {
    .tmp.p create text 10 22 \
        -text "Normal text" -fontsize [expr {int([pt2px 12])}] \
        -fill black -textanchor start
    .tmp.p create text 160 22 \
        -text "Colored" -fontsize [expr {int([pt2px 12])}] \
        -fill "#003399" -textanchor start
    .tmp.p create text 270 22 \
        -text "Larger" -fontsize [expr {int([pt2px 16])}] \
        -fill "#cc3300" -textanchor start
    .tmp.p create line 10 45 470 45 -stroke "#333333" -strokewidth 1.5
    .tmp.p create line 10 55 200 55 -stroke "#0055aa" -strokewidth 2
}
set y [expr {$y + $panelH + 22}]

# --- Does NOT export ---
$pdf setFont 10 Helvetica-Bold
$pdf setFillColor 0.7 0.1 0.1
$pdf text "Also exports with -bbox:  create path,  create circle,  ellipse" \
    -x $lx -y $y
$pdf setFillColor 0 0 0
set y [expr {$y + 14}]
$pdf setFont 9 Helvetica
$pdf text "(visible on screen AND in PDF when -bbox is used)" -x [expr {$lx+10}] -y $y
set y [expr {$y + 12}]

set panelH 75
tkoToPdf $pdf $lx $y 480 $panelH {
    .tmp.p create path "M 10 20 L 120 10 L 230 30 L 120 55 Z" \
        -fill "#b3d1f0" -stroke "#0055aa" -strokewidth 2
    .tmp.p create circle 290 37 -r 28 \
        -fill "#ffcccc" -stroke "#cc0000" -strokewidth 2
    .tmp.p create circle 380 37 -r 28 \
        -fill "#ffe066" -stroke "#cc8800" -strokewidth 2
    .tmp.p create text 10 68 \
        -text "(path + circle: visible on screen AND exported to PDF via itempdf)" \
        -fontsize 9 -fill "#888888" -textanchor start
}
set y [expr {$y + $panelH + 22}]

# --- Workaround ---
$pdf setFont 10 Helvetica-Bold
$pdf text "Workaround: pdf4tcllib::drawing for PDF-native shapes" -x $lx -y $y
set y [expr {$y + 20}]
$pdf setFillColor 0.2 0.4 0.8
pdf4tcllib::drawing::roundedRect $pdf [expr {$lx+0}]   [expr {$y+10}] 130 40 8 1 1
$pdf setFillColor 0.8 0.5 0.1
pdf4tcllib::drawing::polygon     $pdf [expr {$lx+180}] [expr {$y+30}] 28 4 1 1
$pdf setFillColor 0.9 0.7 0.1
pdf4tcllib::drawing::star        $pdf [expr {$lx+270}] [expr {$y+30}] 28 5 0.45 1 1
$pdf setFillColor 0.2 0.6 0.3
pdf4tcllib::drawing::polygon     $pdf [expr {$lx+360}] [expr {$y+30}] 28 6 1 1
$pdf setFillColor 0 0 0
set y [expr {$y + 60}]
$pdf setFont 9 Helvetica
$pdf text "roundedRect / polygon / star -- all vector, all in PDF" -x $lx -y $y

$pdf endPage
$pdf write -file $outPDF
$pdf destroy

destroy .
puts "Written: $outPDF"
puts ""
puts "Page 1: font size conversion (px vs pt, orient true)"
puts "Page 2: what exports from tko::path via \$pdf canvas"
