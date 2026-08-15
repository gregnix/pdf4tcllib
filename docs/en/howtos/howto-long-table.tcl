#!/usr/bin/env tclsh
# howto-long-table.tcl -- a table that runs over several pages and stays
# navigable on every one of them.
#
#   tclsh howto-long-table.tcl [outdir]

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]

set ttf [pdf4tcllib::doc::findTTF]
if {$ttf ne ""} { ::pdf4tcllib::fonts::init -fontdir [file dirname $ttf] }

set ::pdf4tcl::warnings {}
set pdf [::pdf4tcl::new %AUTO% -compress 0 -margin 25]
$pdf tagged 1 -lang en-GB
$pdf startPage
::pdf4tcllib::fonts::setFont $pdf 10 [::pdf4tcllib::fonts::fontSans]

# Enough rows to force a break. The point of the exercise is what happens
# at the boundary, so make it happen twice.
set rows {}
for {set i 1} {$i <= 70} {incr i} {
    lappend rows [list "Part $i" [expr {$i * 3 % 17 + 1}] \
            [format %.2f [expr {$i * 1.75}]]]
}
set tableData [list {Item Quantity Price} {left right right} {*}$rows]

# render takes the page geometry because it has to break pages itself:
# yVar and pageNoVar are updated as it goes.
set y      60
set pageNo 1
::pdf4tcllib::table::render $pdf $tableData 50 y 480 60 780 pageNo \
        595 842 25 10 14

# ---------------------------------------------------------------------------
# What happens at a page break
# ---------------------------------------------------------------------------
#
# The header row is repeated on the new page, and repeated as TH with
# /Scope Column -- not as plain cells. That matters more than it looks: a
# reader that meets a continuation page without headers has a table whose
# columns mean nothing, and one that meets repeated TD cells is told the
# headers are data.
#
# Everything else follows the same rule as on a single page: grid lines and
# zebra stripes are artifacts, cells are TD.

pdf4tcllib::doc::finish $pdf [pdf4tcllib::doc::outfile howto-long-table.pdf]
puts "pages: $pageNo"
