#!/usr/bin/env wish
# ===========================================================================
# Demo 51: Canvas export -- PostScript vs PDF compared
# ===========================================================================
# The SAME canvas content is exported two ways and placed side by side
# in a two-page PDF so you can compare them directly.
#
# Page 1:  Canvas as PDF  ($pdf canvas  -- vector, same as PS quality)
# Page 2:  What PDF adds on top  (header, footer, text, second page)
#          -- none of this is possible with $canvas postscript alone
#
# Also writes the same canvas as raw PostScript for direct comparison.
#
# Key differences:
#
#  Feature                    PostScript (.ps)      PDF ($pdf canvas)
#  -------------------------  --------------------  --------------------
#  Requires pdf4tcl           No -- pure Tk         Yes
#  Multi-page                 No                    Yes
#  Header / footer            No                    Yes (pdf4tcllib)
#  Mix canvas + pdf4tcl text  No                    Yes
#  PDF metadata               No                    Yes
#  Encryption / bookmarks     No                    Yes
#  Vector quality             Yes                   Yes
#
# Usage: wish examples/advanced/51_canvas_pdf_vs_ps.tcl [outputdir]
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
set outPS     [file join $outdir "demo_51_canvas.ps"]
set outPDF    [file join $outdir "demo_51_canvas.pdf"]
set outGSPDF  [file join $outdir "demo_51_canvas_from_ps.pdf"]

# ---------------------------------------------------------------------------
# Helper: PostScript -> PDF via Ghostscript
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
# Helper: draw content into a canvas widget, export to PDF, destroy widget
# (same pattern as d08_canvas.tcl -- canvas is always fresh)
# ---------------------------------------------------------------------------
proc canvasToPdf {pdf x y w h drawScript} {
    canvas .tmp -width $w -height $h -background white
    pack .tmp
    uplevel 1 $drawScript
    update idletasks
    $pdf canvas .tmp -x $x -y $y -width $w -height $h
    destroy .tmp
}

# ---------------------------------------------------------------------------
# The drawing -- factored into a proc so we can call it twice
# (once for PS via .c, once for PDF via canvasToPdf)
# ---------------------------------------------------------------------------
proc drawContent {cv} {
    # Title
    $cv create text 240 26 \
        -text "Same canvas -- PS and PDF output" \
        -font {Helvetica 13 bold} -fill "#1a3f7a" -anchor center
    $cv create line 10 44 470 44 -fill "#aaaaaa" -width 1

    # Shapes
    $cv create text 10 58 -text "Shapes (vector in both formats)" \
        -font {Helvetica 9 bold} -fill "#555555" -anchor w
    $cv create rectangle  10  72 130 122 -fill "#b3d1f0" -outline "#0055aa" -width 2
    $cv create rectangle 150  72 270 122 -fill ""        -outline "#cc3300" -width 2 -dash {6 3}
    $cv create oval      290  72 410 122 -fill "#ffe066" -outline "#cc8800" -width 2

    # Star
    set cx 450; set cy 97; set r1 30; set r2 13
    set pts {}
    for {set i 0} {$i < 10} {incr i} {
        set r [expr {($i % 2) ? $r2 : $r1}]
        set a [expr {-3.14159265/2.0 + $i*3.14159265/5.0}]
        lappend pts [expr {$cx + $r*cos($a)}] [expr {$cy + $r*sin($a)}]
    }
    $cv create polygon {*}$pts -fill "#ffccaa" -outline "#cc6600" -width 2

    # Lines
    $cv create text 10 138 -text "Lines and arrows" \
        -font {Helvetica 9 bold} -fill "#555555" -anchor w
    $cv create line  10 154 220 154 -fill black     -width 2
    $cv create line  10 170 220 170 -fill "#0055aa" -width 2 -dash {8 3}
    $cv create line  10 186 220 170 -fill "#cc3300" -width 2 -arrow last
    $cv create line 240 148 470 188 -fill "#006600" -width 3 -arrow both

    # Arcs
    $cv create text 10 204 -text "Arcs" \
        -font {Helvetica 9 bold} -fill "#555555" -anchor w
    $cv create arc  10 218 110 298 -start 30  -extent 270 \
        -fill "#ffeecc" -outline "#cc6600" -width 2
    $cv create arc 125 218 225 298 -start 0   -extent 200 \
        -fill "#cceeff" -outline "#006699" -width 2 -style chord
    $cv create arc 240 218 340 298 -start 45  -extent 270 \
        -outline "#990099" -width 3 -style arc
    $cv create arc 355 218 455 298 -start 0   -extent 360 \
        -fill "#e8ffe8" -outline "#006600" -width 2

    # Text
    $cv create text 10 314 -text "Text (font names map differently in PS vs PDF)" \
        -font {Helvetica 9 bold} -fill "#555555" -anchor w
    $cv create text  10 336 -text "Normal"  -font {Helvetica 12}              -fill "#000000" -anchor w
    $cv create text 105 336 -text "Bold"    -font {Helvetica 12 bold}         -fill "#003399" -anchor w
    $cv create text 195 336 -text "Italic"  -font {Helvetica 12 italic}       -fill "#cc3300" -anchor w
    $cv create text 285 336 -text "Courier" -font {Courier  12}               -fill "#006600" -anchor w
    $cv create text 375 336 -text "Bold+It" -font {Helvetica 12 bold italic}  -fill "#660066" -anchor w

    # Comparison table
    $cv create rectangle 10 356 470 490 -fill "#f8f8ff" -outline "#ccccdd" -width 1
    $cv create text 240 372 \
        -text "PostScript vs PDF" \
        -font {Helvetica 10 bold} -fill "#1a3f7a" -anchor center

    set trow 0
    foreach {lbl val lcolor} {
        "PS:  pure Tk, no extra package"  ""                         "#004400"
        "PDF: requires pdf4tcl"           ""                         "#000044"
        "PS:  one page max"               "(one canvas = one page)"  "#883300"
        "PDF: multi-page"                 "(see page 2 of this PDF)" "#003388"
        "PS:  canvas items only"          "(no header/footer)"       "#883300"
        "PDF: full pdf4tcllib API"        "(header, footer, text)"   "#003388"
        "Both: vector quality"            "(sharp at any zoom)"      "#004400"
    } {
        set ry [expr {388 + $trow * 14}]
        $cv create text  18 $ry -text $lbl \
            -font {Helvetica 8 bold} -fill $lcolor -anchor w
        $cv create text 250 $ry -text $val \
            -font {Helvetica 8} -fill "#555555" -anchor w
        incr trow
    }

    $cv create text 240 506 \
        -text "This drawing is in both demo_51_canvas.ps and demo_51_canvas.pdf" \
        -font {Helvetica 8} -fill "#888888" -anchor center
}

# ---------------------------------------------------------------------------
# Step 1: PostScript export  (pure Tk, .c canvas, no pdf4tcl involved)
# ---------------------------------------------------------------------------
wm withdraw .
canvas .c -width 480 -height 520 -background white
pack .c
drawContent .c
update idletasks

.c postscript \
    -file      $outPS \
    -pagewidth "17c" \
    -x 0 -y 0 \
    -width  480 \
    -height 520

# Done with .c
destroy .c
puts "PostScript : $outPS"
if {[ps2pdf $outPS $outGSPDF]} {
    puts "PS->PDF    : $outGSPDF  (via gs)"
}

# ---------------------------------------------------------------------------
# Step 2: PDF export  (pdf4tcl -- same drawing, plus PDF-only page 2)
# ---------------------------------------------------------------------------
set ctx [pdf4tcllib::page::context a4 -margin 35]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]

# --- Page 1: the canvas (identical drawing as the .ps) ---
$pdf startPage
pdf4tcllib::page::header $pdf $ctx "Demo 51 -- Canvas: PostScript vs PDF"
pdf4tcllib::page::footer $pdf $ctx "Page 1: canvas export (same as .ps)" 1

canvasToPdf $pdf 55 65 480 520 { drawContent .tmp }

$pdf endPage

# --- Page 2: PDF-only content -- impossible with $canvas postscript ---
$pdf startPage
pdf4tcllib::page::header $pdf $ctx "Demo 51 -- PDF-only features"
pdf4tcllib::page::footer $pdf $ctx "Page 2: impossible with PostScript export" 2

set x  [dict get $ctx left]
set y  [expr {[dict get $ctx top] - 10}]
set tw [dict get $ctx text_w]

$pdf setFont 13 Helvetica-Bold
$pdf text "This is page 2 -- not possible with PostScript export" -x $x -y $y

set y [expr {$y - 20}]
$pdf setFont 10 Helvetica
foreach {line} {
    "PostScript export always produces a single page."
    "With pdf4tcl you can add as many pages as needed."
    ""
    "Other PDF-only features:"
    "  - Header and footer on every page (via pdf4tcllib)"
    "  - Mix canvas items with regular pdf4tcl text and lines"
    "  - Document metadata:  -title, -author, -subject"
    "  - Encryption:         -userpw, -ownerpw"
    "  - Bookmarks:          \$pdf bookmark add ..."
    "  - AcroForm fields:    \$pdf addForm ..."
    "  - PDF/A compliance:   -pdfa"
    ""
    "PostScript export is useful for quick single-page output"
    "when you do not need any of the above."
} {
    set y [expr {$y - 16}]
    $pdf text $line -x $x -y $y
}

# Small canvas mixed into the PDF page
set y [expr {$y - 25}]
canvasToPdf $pdf $x $y 380 70 {
    .tmp create rectangle 2 2 378 68 -fill "#eef4ff" -outline "#3366aa" -width 1
    .tmp create text 190 22 \
        -text "A canvas widget embedded on page 2" \
        -font {Helvetica 11 bold} -fill "#003399" -anchor center
    .tmp create text 190 46 \
        -text "Mixed with regular pdf4tcl text above -- impossible in pure PS" \
        -font {Helvetica 9} -fill "#555555" -anchor center
}

$pdf endPage
$pdf write -file $outPDF
$pdf destroy

destroy .
puts "PDF        : $outPDF"
puts ""
puts ""
puts "Three output files:"
puts "  .ps          -- Tk postscript export"
puts "  _from_ps.pdf -- Ghostscript conversion of the .ps  (single page)"
puts "  .pdf         -- pdf4tcl canvas export  (2 pages, PDF-only features)"
puts ""
puts "Compare _from_ps.pdf (page 1 of .pdf) -- identical drawing, different path."
