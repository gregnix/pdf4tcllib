#!/usr/bin/env tclsh
# howto-charts.tcl -- putting numbers on a page so they can be read.
#
#   tclsh howto-charts.tcl [outdir]

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]

package require pdf4tclchart

set ttf [pdf4tcllib::doc::findTTF]
if {$ttf ne ""} { ::pdf4tcllib::fonts::init -fontdir [file dirname $ttf] }

set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 25]
set ctx [::pdf4tcllib::page::context a4 -margin 25]

# Tagging goes on BEFORE the first page. Switching it on halfway through
# leaves everything drawn earlier outside the structure tree, and
# getUntaggedCount counts it from that moment on -- the first version of
# this file turned it on before section 5 and reported 35 loose drawing
# operations for the four charts above.
$pdf tagged 1 -lang en-GB
$pdf startPage

set x [dict get $ctx left]
set w [dict get $ctx text_w]
set y [dict get $ctx top]

# --- 1. the plain case ------------------------------------------------------
# Labels and numbers, either as flat pairs or as a list of pairs. The box is
# x, y, width, height; the call returns the y below it, so charts stack.

set y [::pdf4tcllib::chart::bar $pdf $x $y $w 150 \
    {Jan 120 Feb 145 Mrz 98 Apr 160} \
    -title "1. Plain bar chart" -values 1 -format %.0f]

# --- 2. fixing the scale ----------------------------------------------------
# Two charts side by side are only comparable when they share a scale.
# Without -max each would be scaled to its own maximum and the smaller
# series would look just as tall as the larger one.

set half [expr {($w - 20) / 2.0}]
set y [expr {$y + 16}]
::pdf4tcllib::chart::bar $pdf $x $y $half 140 {Q1 40 Q2 55 Q3 48 Q4 62} \
    -title "2a. 2025 (-max 200)" -max 200
::pdf4tcllib::chart::bar $pdf [expr {$x + $half + 20}] $y $half 140 \
    {Q1 150 Q2 180 Q3 120 Q4 195} -title "2b. 2026 (-max 200)" -max 200
set y [expr {$y + 140}]

# --- 3. several series ------------------------------------------------------
# A line chart takes {name {data}} pairs. The x labels come from the first
# series; the others are drawn against the same positions.

set y [::pdf4tcllib::chart::line $pdf $x [expr {$y + 16}] $w 150 \
    {{2025 {Q1 40 Q2 55 Q3 48 Q4 62}}
     {2026 {Q1 150 Q2 180 Q3 120 Q4 195}}} \
    -title "3. Two series"]

# --- 4. shares --------------------------------------------------------------
# A pie needs a legend to be readable at all -- a slice without its name is
# a coloured wedge and nothing else.

set y [::pdf4tcllib::chart::pie $pdf $x [expr {$y + 16}] $w 170 \
    {Nord 35 Sued 25 Ost 20 West 20} \
    -title "4. Shares, with a legend" -legend 1]

$pdf endPage

# --- 5. tagged, and what that is worth --------------------------------------
# A chart is one Figure element with an alternate text. Give it one: the
# title alone rarely says what the picture shows.

$pdf startPage
set y [dict get $ctx top]
set y [::pdf4tcllib::chart::bar $pdf $x $y $w 150 {Jan 120 Feb 145 Mrz 98} \
    -title "5. Tagged" \
    -alt "Bar chart: revenue January to March, 120, 145 and 98 kEUR"]

# ... and then the numbers again, as a table, for a reader who needs them.
set y [::pdf4tcllib::table::draw $pdf $x [expr {$y + 16}] \
    {{-header Monat} {-header "kEUR" -align right}} \
    {{Jan 120} {Feb 145} {Mrz 98}} -maxwidth $w]

puts "untagged drawing operations: [$pdf getUntaggedCount]"
$pdf endPage

set out [pdf4tcllib::doc::outfile howto-charts.pdf]
$pdf write -file $out
puts "Geschrieben: $out"
exit 0
