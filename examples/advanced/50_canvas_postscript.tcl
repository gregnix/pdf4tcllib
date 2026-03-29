#!/usr/bin/env wish
# ===========================================================================
# Demo 50: Tk Canvas -> PostScript  (Tk built-in export)
# ===========================================================================
# Tk has built-in PostScript export -- no pdf4tcl needed.
#
# This demo shows the pure-Tk approach:
#   $canvas postscript -file out.ps
#
# Output: demo_50_canvas.ps   (Tk postscript -- no pdf4tcl)
#         demo_50_canvas.pdf  (pdf4tcl canvas  -- for comparison)
#
# PostScript export capabilities:
#   Can do:
#     - All standard canvas items (rectangle, line, oval, polygon, arc, text)
#     - Vector output -- shapes stay sharp at any zoom level
#     - Color, dash patterns, line widths
#     - -pagewidth / -pageheight to control output size
#     - -rotate 1 for landscape
#   Cannot do:
#     - Multi-page documents  (one canvas = one page)
#     - PDF features (bookmarks, metadata, encryption, forms)
#     - Direct integration with pdf4tcllib page context
#
# Usage: wish examples/advanced/50_canvas_postscript.tcl [outputdir]
#
# IMPORTANT: Requires wish (Tk), not tclsh!
# ===========================================================================

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir    [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPS     [file join $outdir "demo_50_canvas.ps"]
set outPDF    [file join $outdir "demo_50_canvas.pdf"]
set outGSPDF  [file join $outdir "demo_50_canvas_from_ps.pdf"]

# ---------------------------------------------------------------------------
# Helper: PostScript -> PDF via Ghostscript
# Returns 1 on success, 0 if gs not found or conversion failed.
# ---------------------------------------------------------------------------
proc ps2pdf {psFile pdfFile} {
    set gs [auto_execok gs]
    if {$gs eq ""} {
        puts "  (gs not found -- skipping PS->PDF conversion)"
        return 0
    }
    set rc [catch {
        exec $gs -dBATCH -dNOPAUSE -dQUIET \
            -sDEVICE=pdfwrite \
            -sOutputFile=$pdfFile \
            $psFile
    } msg]
    if {$rc != 0} { puts "  gs error: $msg"; return 0 }
    return 1
}

# ---------------------------------------------------------------------------
# Build canvas
# ---------------------------------------------------------------------------
wm withdraw .
canvas .c -width 480 -height 540 -background white
pack .c

# Title
.c create text 240 26 \
    -text "Canvas -> PostScript (pure Tk, no pdf4tcl)" \
    -font {Helvetica 14 bold} -fill "#1a3f7a" -anchor center
.c create line 10 44 470 44 -fill "#aaaaaa" -width 1

# --- Rectangles ---
.c create text 10 58 -text "1. Rectangles" \
    -font {Helvetica 9 bold} -fill "#555555" -anchor w
.c create rectangle  10  72 120 122 -fill "#b3d1f0" -outline "#0055aa" -width 2
.c create rectangle 140  72 250 122 -fill ""        -outline "#cc3300" -width 2 -dash {6 3}
.c create rectangle 270  72 380 122 -fill "#ffe066" -outline "#cc8800" -width 2

# --- Lines and arrows ---
.c create text 10 138 -text "2. Lines and arrows" \
    -font {Helvetica 9 bold} -fill "#555555" -anchor w
.c create line  10 154 200 154 -fill black     -width 2
.c create line  10 170 200 170 -fill "#0055aa" -width 2 -dash {8 3}
.c create line  10 186 200 170 -fill "#cc3300" -width 2 -arrow last
.c create line 220 148 460 188 -fill "#006600" -width 3 -arrow both

# --- Ovals ---
.c create text 10 204 -text "3. Ovals" \
    -font {Helvetica 9 bold} -fill "#555555" -anchor w
.c create oval  10 218 120 288 -fill "#ffcccc" -outline "#cc0000" -width 2
.c create oval 140 218 250 288 -fill ""        -outline "#0000cc" -width 2
.c create oval 270 218 460 268 -fill "#ccffcc" -outline "#006600" -width 1

# --- Arcs ---
.c create text 10 304 -text "4. Arcs" \
    -font {Helvetica 9 bold} -fill "#555555" -anchor w
.c create arc  10 318 100 398 -start 30  -extent 270 \
    -fill "#ffeecc" -outline "#cc6600" -width 2 -style pieslice
.c create arc 115 318 205 398 -start 0   -extent 200 \
    -fill "#cceeff" -outline "#006699" -width 2 -style chord
.c create arc 220 318 310 398 -start 45  -extent 270 \
    -outline "#990099" -width 3         -style arc

# --- Polygon (star) ---
.c create text 10 414 -text "5. Polygon (star)" \
    -font {Helvetica 9 bold} -fill "#555555" -anchor w
set cx 80; set cy 460; set r1 38; set r2 16
set pts {}
for {set i 0} {$i < 10} {incr i} {
    set r [expr {($i % 2) ? $r2 : $r1}]
    set a [expr {-3.14159265/2.0 + $i*3.14159265/5.0}]
    lappend pts [expr {$cx + $r*cos($a)}] [expr {$cy + $r*sin($a)}]
}
.c create polygon {*}$pts -fill "#ffe066" -outline "#cc8800" -width 2

# --- Text styles ---
.c create text 170 428 -text "6. Text styles" \
    -font {Helvetica 9 bold} -fill "#555555" -anchor w
.c create text 170 455 -text "Normal"  -font {Helvetica 12}        -fill "#000000" -anchor w
.c create text 260 455 -text "Bold"    -font {Helvetica 12 bold}   -fill "#003399" -anchor w
.c create text 340 455 -text "Italic"  -font {Helvetica 12 italic} -fill "#cc3300" -anchor w
.c create text 170 478 -text "Courier" -font {Courier  12}         -fill "#006600" -anchor w
.c create text 260 478 -text "BoldItal" -font {Helvetica 12 bold italic} -fill "#660066" -anchor w

# --- Info box ---
.c create rectangle 10 498 470 535 -fill "#f0f4ff" -outline "#aabbdd" -width 1
.c create text 240 513 \
    -text "Export A:  .c postscript -file out.ps   (pure Tk)" \
    -font {Courier 9} -fill "#333333" -anchor center
.c create text 240 528 \
    -text "Export B:  \$pdf canvas .c ...             (pdf4tcl)" \
    -font {Courier 9} -fill "#333333" -anchor center

update idletasks

# ---------------------------------------------------------------------------
# Export A: PostScript  (pure Tk built-in, no pdf4tcl)
# ---------------------------------------------------------------------------
.c postscript \
    -file      $outPS \
    -pagewidth "17c" \
    -x 0 -y 0 \
    -width  480 \
    -height 540

puts "PostScript : $outPS"
if {[ps2pdf $outPS $outGSPDF]} {
    puts "PS->PDF    : $outGSPDF  (via gs)"
}

# ---------------------------------------------------------------------------
# Export B: same canvas as PDF  (pdf4tcl canvas method)
# ---------------------------------------------------------------------------
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]
$pdf startPage

update idletasks
$pdf canvas .c -x 55 -y 60 -width 480 -height 540

$pdf endPage
$pdf write -file $outPDF
$pdf destroy

destroy .
puts "PDF        : $outPDF"
puts ""
puts ""
puts "Three output files:"
puts "  .ps          -- Tk postscript export (needs PS viewer or gs)"
puts "  _from_ps.pdf -- Ghostscript conversion of the .ps"
puts "  .pdf         -- pdf4tcl canvas export (native PDF)"
puts ""
puts "Compare _from_ps.pdf and .pdf -- both from the same canvas drawing,"
puts "but produced by completely different code paths."
