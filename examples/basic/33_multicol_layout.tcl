#!/usr/bin/env tclsh
# Demo 33: Multi-column Text Layout
# pdf4tcl 0.9.4.11 — orient true (origin top-left), no ytop

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_33_multicol_layout.pdf]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]
set PAGE_W [lindex $DA 0]
set PAGE_H [lindex $DA 1]

$pdf setFont 16 Helvetica
$pdf text "Multi-column Text Layout" -x 40 -y 40

$pdf setFont 12 Helvetica

# Simple word-wrap by character width (approx). For demo purpose.
proc wrap_lines {text maxChars} {
    set words [split $text " "]
    set line ""
    set lines {}
    foreach w $words {
        if {[string length $line] + [string length $w] + 1 > $maxChars} {
            lappend lines $line
            set line $w
        } else {
            if {$line eq ""} { set line $w } else { append line " " $w }
        }
    }
    if {$line ne ""} { lappend lines $line }
    return $lines
}

# Two columns
set colX1 40
set colX2 310
set colWidth 250
set colTopY 80
set lineH 14

set sampleText {Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident sunt in culpa qui officia deserunt mollit anim id est laborum.}

set wrapped [wrap_lines $sampleText 50]

# Split lines into two columns
set mid [expr {[llength $wrapped]/2}]
set col1 [lrange $wrapped 0 [expr {$mid-1}]]
set col2 [lrange $wrapped $mid end]

set y $colTopY
foreach line $col1 {
    $pdf text $line -x $colX1 -y $y
    incr y $lineH
}

set y $colTopY
foreach line $col2 {
    $pdf text $line -x $colX2 -y $y
    incr y $lineH
}

# Draw vertical separator
$pdf setLineWidth 0.5
$pdf setStrokeColor 0.7 0.7 0.7
set sepX [expr {$colX1 + $colWidth + 5}]
$pdf line $sepX $colTopY $sepX [expr {$colTopY + [llength $col1]*$lineH}]

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"

