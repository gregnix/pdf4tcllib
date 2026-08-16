#!/usr/bin/env tclsh
# ===========================================================================
# Demo 41: Bar, line and pie charts (pdf4tclchart)
#
# Data-driven and Tk-free: labels and numbers go in, the module owns the
# scale, the grid and the geometry. With tagging on, a chart is one Figure
# element with an alternate text, and everything inside it is an artifact.
# ===========================================================================

package require pdf4tcllib
package require pdf4tclchart

set scriptDir [file dirname [file normalize [info script]]]
set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_41_charts.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4]
::pdf4tcllib::fonts::init
set ctx [::pdf4tcllib::page::context a4]
$pdf startPage

set x [dict get $ctx left]
set w [dict get $ctx text_w]
set y [dict get $ctx top]

::pdf4tcllib::page::header $pdf $ctx "pdf4tclchart -- demo 41"
set y [expr {$y + 30}]

# --- bar: values on top, one colour from the palette per bar
set y [::pdf4tcllib::chart::bar $pdf $x $y $w 190 \
    {Jan 120 Feb 145 Mar 98 Apr 160 May 132 Jun 178} \
    -title "Revenue per month (kEUR)" -values 1 -format %.0f]

# --- line: two series against the same x labels
set y [::pdf4tcllib::chart::line $pdf $x [expr {$y + 24}] $w 190 \
    {{2025 {Q1 100 Q2 130 Q3 120 Q4 175}}
     {2026 {Q1 140 Q2 120 Q3 165 Q4 190}}} \
    -title "Two years, by quarter"]

# --- pie with a legend showing the shares
set y [::pdf4tcllib::chart::pie $pdf $x [expr {$y + 24}] $w 200 \
    {North 35 South 25 East 20 West 20} \
    -title "Share by region" -legend 1]

::pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib" 1
$pdf endPage
$pdf write -file $outPDF

puts "Geschrieben: $outPDF"
exit 0
