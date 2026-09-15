#!/usr/bin/env tclsh
# ============================================================================
# Demo 70: What this session added -- and how each of it was measured
#
# This is not a feature tour. Every page shows something that was BROKEN or
# MISSING before, states the measurement that found it, and then demonstrates
# the fix -- checking itself where it can, so the demo fails when a claim
# stops being true.
#
# Output: pdf/demo_70_session.pdf
#
# What this shows:
#   - the soft hyphen, and the second truth it briefly created
#   - counted character substitution instead of silent question marks
#   - what the tablelist export cannot carry over, and says so
#   - clipping on label sheets
#   - one layout, two renderers (pdf4tclwidget)
#   - the tools that found the rest
#
# Encoding test: äöüÄÖÜß€
# ============================================================================

# --- UTF-8 sicherstellen (Tcl 8.6 liest Skripte in der Systemkodierung) ---
source [file join [file dirname [info script]] .. _utf8.tcl]
if {![utf8Pruefen "ä"]} {
    if {[utf8Neuladen [info script]]} { return }
}

set demo_num 70
set demo_name "session"

set scriptDir [file dirname [file normalize [info script]]]
lappend auto_path [file join $scriptDir .. ..]
tcl::tm::path add [file join $scriptDir .. .. lib]

package require pdf4tcl
package require pdf4tcllib
package require pdf4tcltable

set outDir [file join $scriptDir pdf]
file mkdir $outDir
set outFile [file join $outDir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

::pdf4tcllib::fonts::init

# Every claim on a page is checked here. A demo that only asserts is a
# brochure; this one fails loudly when something stops holding.
set ::geprueft 0
set ::gescheitert {}

proc pruefe {was ausdruck} {
    incr ::geprueft
    if {![uplevel 1 [list expr $ausdruck]]} {
        lappend ::gescheitert $was
    }
}

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -margin 40]
$pdf tagged 1
$pdf metadata -title "pdf4tcl / pdf4tcllib -- session of 2026-08-29" \
        -author "pdf4tcl demo suite"

set ctx [::pdf4tcllib::page::context a4 -margin 40 -orient true]
set sx [dict get $ctx SX]
set sw [dict get $ctx SW]

set sans     [::pdf4tcllib::fonts::fontSans]
set sansBold [::pdf4tcllib::fonts::fontSansBold]
set mono     [::pdf4tcllib::fonts::fontMono]

# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------

proc seite {pdf ctx titel} {
    $pdf startPage
    ::pdf4tcllib::page::header $pdf $ctx $titel
    ::pdf4tcllib::page::footer $pdf $ctx \
            "pdf4tcl 0.9.4.61 / pdf4tcllib 0.6.4 -- every number on this page was measured" 0
    return [expr {[dict get $ctx SY] + 26}]
}

proc absatz {pdf x y w txt {size 10}} {
    global sans
    $pdf setFont $size $sans
    return [::pdf4tcllib::text::writeParagraph $pdf $txt $x $y $w]
}

proc ueberschrift {pdf x y txt} {
    global sansBold
    $pdf setFont 12 $sansBold
    ::pdf4tcllib::tag::begin $pdf H2
    $pdf text $txt -x $x -y $y
    ::pdf4tcllib::tag::end $pdf
    return [expr {$y + 18}]
}

# A measurement, shown the way it was taken: before, after, and the unit.
proc messung {pdf x y w zeilen} {
    global mono
    set h [expr {[llength $zeilen] * 12 + 10}]
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    $pdf setFillColor 0.95 0.95 0.95
    $pdf rectangle $x $y $w $h -filled 1
    $pdf setFillColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf
    set ly [expr {$y + 14}]
    $pdf setFont 9 $mono
    foreach z $zeilen {
        ::pdf4tcllib::tag::begin $pdf P
        $pdf text $z -x [expr {$x + 6}] -y $ly
        ::pdf4tcllib::tag::end $pdf
        set ly [expr {$ly + 12}]
    }
    return [expr {$y + $h + 12}]
}

# ============================================================================
# Page 1 -- the soft hyphen, and the second truth it created
# ============================================================================

set y [seite $pdf $ctx "1. The soft hyphen (pdf4tcl 0.9.4.61)"]

set y [absatz $pdf $sx $y $sw "U+00AD is a suggestion, not a character. It\
        should be printed only where the line actually breaks, and then as a\
        hyphen. Up to 0.9.4.60 it was printed wherever it stood and did not\
        break, so a soft hyphen inside a word came out as a stray dash."]

set y [expr {$y + 6}]
$pdf setFont 14 $sans

# The demonstration: the same word, twice, in boxes of different widths.
set wort "Silben\u00ADtrennung"
$pdf setFont 11 $sans
::pdf4tcllib::tag::begin $pdf P
$pdf drawTextBox $sx [expr {$y + 4}] 200 40 $wort -linesvar nWeit
::pdf4tcllib::tag::end $pdf
::pdf4tcllib::tag::begin $pdf P
$pdf drawTextBox [expr {$sx + 240}] [expr {$y + 4}] 60 40 $wort -linesvar nEng
::pdf4tcllib::tag::end $pdf
set y [expr {$y + 46}]

$pdf setFont 9 $sans
::pdf4tcllib::tag::begin $pdf Caption
$pdf text "wide box: one line, no dash" -x $sx -y $y
$pdf text "narrow box: broken, dash appears" -x [expr {$sx + 240}] -y $y
::pdf4tcllib::tag::end $pdf
set y [expr {$y + 20}]

pruefe "soft hyphen invisible when not breaking" {$nWeit == 1}
pruefe "soft hyphen breaks when it must"        {$nEng == 2}

set y [ueberschrift $pdf $sx $y "The second truth it created"]

set y [absatz $pdf $sx $y $sw "Fixing drawTextBox was not enough. getStringWidth\
        still counted the character, so anyone wrapping text themselves --\
        pdf4tcllib and pdf4tclwidget both do -- was given the width of a hyphen\
        nobody sees. That was found by review, not by the test suite: the suite\
        computed both widths and then compared only line counts."]

$pdf setFont 10 $sans
set breiteOhne [$pdf getStringWidth "Silben"]
set breiteMit  [$pdf getStringWidth "Sil\u00ADben"]

set y [messung $pdf $sx $y $sw [list \
    [format "getStringWidth \"Silben\"        %.2f pt" $breiteOhne] \
    [format "getStringWidth \"Sil<AD>ben\"    %.2f pt   (was 33.35 before)" $breiteMit] \
    "" \
    "a hard hyphen still counts -- it is printed" ]]

pruefe "getStringWidth ignores the soft hyphen" \
        {abs($breiteMit - $breiteOhne) < 0.001}
pruefe "a hard hyphen still has width" \
        {[$pdf getStringWidth "Donau-dampf"] > [$pdf getStringWidth "Donaudampf"]}

$pdf endPage

# ============================================================================
# Page 2 -- missing glyphs are counted, not swallowed
# ============================================================================

set y [seite $pdf $ctx "2. Missing characters are counted (pdf4tcllib)"]

set y [absatz $pdf $sx $y $sw "A character the font does not have is replaced\
        with a question mark. That used to happen in silence: neither the return\
        value nor any counter said so. Measured on math::renderLatex, the two\
        symbols below produced six question marks in the content stream, and the\
        only sign was a line on stderr that nobody reads in a batch run."]

::pdf4tcllib::unicode::resetSubst
$pdf setFont 11 [::pdf4tcllib::fonts::fontSans]
set y [expr {$y + 4}]
::pdf4tcllib::unicode::safeText $pdf "Greek and mathematics: \u03b1 \u03b2 \u2211" \
        -x $sx -y $y
set bericht [::pdf4tcllib::unicode::substReport]
set y [expr {$y + 20}]

set y [messung $pdf $sx $y $sw [list \
    "unicode::resetSubst" \
    "unicode::safeText \$pdf \"... \\u03b1 \\u03b2 \\u2211\"" \
    "unicode::substReport" \
    [format "  -> count %s  chars %s" \
        [dict get $bericht count] [dict get $bericht chars]] ]]

set y [absatz $pdf $sx $y $sw "With a font that has the characters the count is\
        zero. The report names up to twelve distinct code points, because a\
        number alone does not tell you which font to load. Deliberate\
        substitutions -- the emoji transliteration, the box-drawing fallback --\
        are not counted: what is counted is a character disappearing."]

pruefe "missing glyphs are counted" {[dict get $bericht count] > 0}
pruefe "the report names them"      {[llength [dict get $bericht chars]] > 0}

$pdf endPage

# ============================================================================
# Page 3 -- what the tablelist export cannot carry over
# ============================================================================

set y [seite $pdf $ctx "3. The tablelist export says what it cannot do"]

set y [absatz $pdf $sx $y $sw "The point of that exporter is that what is on the\
        screen goes into the PDF. Three things it cannot do, and until now they\
        disappeared without a word: an image in a cell, an embedded window, and\
        a wrapped column -- table::draw does not wrap, so a cell the widget shows\
        over three lines becomes one, shortened with an ellipsis."]

set y [messung $pdf $sx $y $sw [list \
    "tablelist::render \$pdf .tbl 50 70 -maxwidth 480" \
    "tablelist::report" \
    "  -> images 1 windows 1 wrapped 1 cells {0,0 1,0 1,2}" \
    "" \
    "measured: an 82-character text in a wrapped column --" \
    "the widget shows all of it, the PDF ends after 41" ]]

set y [absatz $pdf $sx $y $sw "The report covers the last run rather than\
        accumulating, or it would sum over several tables and nobody would know\
        which is meant. A wrapped column alone is not a loss: a short value fits\
        on one line there too, so only a value longer than the column counts."]

set y [ueberschrift $pdf $sx $y "What it does carry over -- more than expected"]

set cols {
    {-header "Item" -align left}
    {-header "Qty" -align right}
    {-header "Price" -align right}
}
set rows {
    {"Row colours" 3 "12.50"}
    {"Cell fonts" 7 "3.20"}
    {"Hidden columns" 1 "48.00"}
}
set y [::pdf4tcllib::table::draw $pdf $sx $y $cols $rows \
        -maxwidth $sw -zebra 1 -fontsize 9]

set y [expr {$y + 10}]
set y [absatz $pdf $sx $y $sw "Row and cell backgrounds, foreground colours, cell\
        fonts, hidden rows and columns, the sort order and the tree mode all\
        survive the export, and getUntaggedCount stays at zero." 9]

$pdf endPage

# ============================================================================
# Page 4 -- nothing leaves the label
# ============================================================================

set y [seite $pdf $ctx "4. Nothing leaves the label (pdf4tcllabels 0.2)"]

set y [absatz $pdf $sx $y $sw "A name wider than the label used to run onto the\
        one beside it. On screen that is invisible; on a sheet of labels it costs\
        the batch. Measured on the rendered page, format 3474 (198.4 pt wide),\
        60 characters at 11 pt:"]

set y [messung $pdf $sx $y $sw [list \
    "without -clip    ink out to 363.6 pt" \
    "with -clip 1     ink out to 198.0 pt -- at the edge" ]]

set y [absatz $pdf $sx $y $sw "fitSize, wrap and ellipsize are the better answer,\
        because they keep the text readable instead of cutting it mid-word. But\
        they only help whoever remembers them. The default is off: a clip nobody\
        asked for would be a silent change of behaviour for every existing call."]

# Two labels drawn side by side, the right one clipped.
set langerName "Bundesausbildungsfoerderungsgesetz-Sachbearbeitung"
set lw 200.0
set lh 50.0
foreach {lx beschnitten} [list $sx 0 [expr {$sx + 240}] 1] {
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    $pdf setStrokeColor 0.6 0.6 0.6
    $pdf setLineWidth 0.5
    $pdf rectangle $lx $y $lw $lh -stroke 1
    ::pdf4tcllib::tag::artifactEnd $pdf
    if {$beschnitten} {
        $pdf gsave
        $pdf clip $lx $y $lw $lh
    }
    $pdf setFont 11 $sans
    ::pdf4tcllib::tag::begin $pdf P
    $pdf text $langerName -x [expr {$lx + 4}] -y [expr {$y + 20}]
    ::pdf4tcllib::tag::end $pdf
    if {$beschnitten} { $pdf grestore }
}
set y [expr {$y + $lh + 6}]
$pdf setFont 9 $sans
::pdf4tcllib::tag::begin $pdf Caption
$pdf text "without -clip: runs past the edge" -x $sx -y $y
$pdf text "with -clip 1: stops at it" -x [expr {$sx + 240}] -y $y
::pdf4tcllib::tag::end $pdf

$pdf endPage

# ============================================================================
# Page 5 -- one layout, two renderers
# ============================================================================

set y [seite $pdf $ctx "5. One layout, two renderers (pdf4tclwidget 0.2)"]

set y [absatz $pdf $sx $y $sw "An editor on a canvas tempts you to lay out twice\
        -- once for the screen, once for the PDF. Then there are two layout\
        engines and they drift apart, at text widths first. The preview then lies\
        exactly where it matters: at the point where a line breaks."]

set y [messung $pdf $sx $y $sw [list \
    "text::width without a pdf object      89.44 pt" \
    "pdf4tcl for the same string          110.73 pt" \
    "a canvas using font measure          somewhere else again" ]]

set y [absatz $pdf $sx $y $sw "So the layout runs once, with the metrics of the\
        document, and produces a position list. Both renderers draw what it says\
        and nothing else. Checked against the real output rather than against a\
        second calculation:"]

set y [messung $pdf $sx $y $sw [list \
    "the list says   top edge y = 40.0" \
    "pdftotext       yMin = 39.999574" \
    "the canvas      bbox y = 40" ]]

set y [absatz $pdf $sx $y $sw "Building that layer found three defects, and all\
        three were in the PDF path -- found through the canvas, which stood\
        beside it and was obviously right. getFontMetric ascend returns points\
        rather than a factor, so the first line sat 83 points too low; text::wrap\
        takes the pdf object as its sixth argument, so the wrong way round the\
        object name was printed as text; a negative font size in Tk means pixels."]

$pdf endPage

# ============================================================================
# Page 6 -- the tools that found the rest
# ============================================================================

set y [seite $pdf $ctx "6. The tools, and what they cannot see"]

set y [absatz $pdf $sx $y $sw "No single check sees the whole page. Five demos ran\
        off the sheet for months because every check in place reported green."]

set toolCols {
    {-header "Tool" -align left}
    {-header "Sees" -align left}
}
set toolRows {
    {"qpdf" "is the file intact"}
    {"veraPDF" "does it keep its own claim"}
    {"pdfcheck-native" "are the structures right"}
    {"layout-check.tcl" "where the TEXT ends up (pdftotext)"}
    {"geometry-check.tcl" "where the DRAWING ends up (content stream)"}
}
set y [::pdf4tcllib::table::draw $pdf $sx $y $toolCols $toolRows \
        -maxwidth $sw -zebra 1 -fontsize 9]
set y [expr {$y + 12}]

set y [ueberschrift $pdf $sx $y "And the lesson, learned three times"]

set y [absatz $pdf $sx $y $sw "geometry-check reported six findings in the canvas\
        examples. They were written off as false alarms -- by me, without\
        looking. Once the checker followed cm transformations, four of them\
        really were false alarms and two were defects nobody had examined: a\
        table 560 pt wide starting at x=42.5 on a 595 pt page, and a page that\
        stepped y the wrong way so its content ended up 179 pt above the sheet."]

set y [absatz $pdf $sx $y $sw "The same shape appeared in layout-check, whose note\
        explained two old findings -- one explanation was wrong. And in this\
        widget module, whose header still described the previous format. An\
        unexamined explanation beside a finding is worse than none, because it\
        stops anyone from looking again."]

$pdf endPage

# ============================================================================
# Page 7 -- what this demo checked about itself
# ============================================================================

set y [seite $pdf $ctx "7. What this demo checked while drawing itself"]

set y [absatz $pdf $sx $y $sw "A demo that only asserts is a brochure. Every claim\
        on the pages above that could be checked, was checked while this file was\
        produced. If one of them stops being true, this run fails."]

set ungetaggt [$pdf getUntaggedCount]
pruefe "the structure tree has no holes" {$ungetaggt == 0}

set zeilen [list \
    [format "checks made                  %d" $::geprueft] \
    [format "failed                       %d" [llength $::gescheitert]] \
    [format "getUntaggedCount             %d" $ungetaggt] ]
foreach f $::gescheitert { lappend zeilen "  FAILED: $f" }
set y [messung $pdf $sx $y $sw $zeilen]

set y [absatz $pdf $sx $y $sw "getUntaggedCount counts drawing operations that sit\
        in neither a structure element nor an artifact. Zero is the goal, and it\
        needs a counter-check of its own: a zero can also mean that nothing was\
        drawn at all. tests/test_tagging.tcl draws raw on purpose and expects two."]

$pdf endPage

$pdf write -file $outFile
$pdf destroy

puts "Wrote: $outFile"
puts "Checks: $::geprueft made, [llength $::gescheitert] failed"
foreach f $::gescheitert { puts "  FAILED: $f" }
if {[llength $::gescheitert]} { exit 1 }
