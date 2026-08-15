#!/usr/bin/env tclsh
# tutorial-01-accessible-report.tcl -- a report that is accessible from the
# first line, built only from pdf4tcllib blocks.
#
#   tclsh tutorial-01-accessible-report.tcl [outdir]

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]

# ---------------------------------------------------------------------------
# Step 1 -- the font decides whether any of this counts
# ---------------------------------------------------------------------------
#
# Load it through pdf4tcllib::fonts, not with "$pdf setFont" alone: the
# blocks take their own font from that configuration. The 14 standard fonts
# have no embeddable font program, so a report set in Helvetica is tagged
# and still not PDF/UA conformant.

set ttf [pdf4tcllib::doc::findTTF]
if {$ttf ne ""} {
    ::pdf4tcllib::fonts::init -fontdir [file dirname $ttf]
}
set haveTtf [::pdf4tcllib::fonts::hasTtf]

set ::pdf4tcl::warnings {}
set pdf [::pdf4tcl::new %AUTO% -compress 0 -margin 25]

# ---------------------------------------------------------------------------
# Step 2 -- switch tagging on, and say which language it is
# ---------------------------------------------------------------------------
#
# The language is not decoration: a screen reader picks its pronunciation
# from it, and PDF/UA requires it. Level A of PDF/A does too.

$pdf tagged 1 -ua 1 -lang en-GB
$pdf startPage
::pdf4tcllib::fonts::setFont $pdf 11 [::pdf4tcllib::fonts::fontSans]

set ctx [::pdf4tcllib::page::context a4 -margin 25 -orient true]

# ---------------------------------------------------------------------------
# Step 3 -- the page furniture is not content
# ---------------------------------------------------------------------------

::pdf4tcllib::page::header $pdf $ctx "Quarterly report"

# ---------------------------------------------------------------------------
# Step 4 -- headings and body text carry their type
# ---------------------------------------------------------------------------

::pdf4tcllib::text::writeParagraph $pdf "Sales by region" \
        50 80 400 15 left H1
::pdf4tcllib::text::writeParagraph $pdf \
        "The figures below cover the third quarter. Values in thousands." \
        50 110 400 11

# ---------------------------------------------------------------------------
# Step 5 -- the table
# ---------------------------------------------------------------------------
#
# The first row becomes TH with /Scope Column, the rest TD. Grid lines and
# zebra stripes become artifacts, so a reader is not told about them.

::pdf4tcllib::table::simpleTable $pdf 50 150 {140 90 90} {
    {Region Q2 Q3}
    {North 128 141}
    {South 96 88}
    {East 204 219}
} -zebra 1

::pdf4tcllib::tag::begin $pdf Caption
::pdf4tcllib::fonts::setFont $pdf 9 [::pdf4tcllib::fonts::fontSans]
$pdf text "Table 1: revenue by region, thousands" -x 50 -y 250
::pdf4tcllib::tag::end $pdf

# ---------------------------------------------------------------------------
# Step 6 -- anything drawn by hand needs a decision
# ---------------------------------------------------------------------------

::pdf4tcllib::fonts::setFont $pdf 11 [::pdf4tcllib::fonts::fontSans]
::pdf4tcllib::tag::begin $pdf P
$pdf text "East grew fastest, at just under eight per cent." -x 50 -y 290
::pdf4tcllib::tag::end $pdf

# A rule means nothing on its own.
::pdf4tcllib::tag::artifact $pdf -type Layout
$pdf setStrokeColor 0.8 0.8 0.8
$pdf line 50 305 420 305
$pdf setStrokeColor 0 0 0
::pdf4tcllib::tag::artifactEnd $pdf

::pdf4tcllib::page::number $pdf $ctx 1 1

# ---------------------------------------------------------------------------
# Step 7 -- check, then write
# ---------------------------------------------------------------------------

set left [pdf4tcllib::doc::finish $pdf \
        [pdf4tcllib::doc::outfile tutorial-01-accessible-report.pdf]]

if {!$haveTtf} {
    puts "no TrueType font was found: the report is tagged, but the standard"
    puts "fonts cannot be embedded, so it is not PDF/UA conformant."
}
