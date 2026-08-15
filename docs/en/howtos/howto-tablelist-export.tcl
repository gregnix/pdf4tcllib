#!/usr/bin/env tclsh
# howto-tablelist-export.tcl -- export a tablelist widget as an accessible
# PDF, with what is on screen and nothing else.
#
#   tclsh howto-tablelist-export.tcl [outdir]
#
# Needs Tk, a display and the tablelist package.

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]

if {[catch {package require Tk} e]} {
    puts "Tk not available: $e"
    puts "skipped -- this how-to needs Tk and a display"
    exit 0
}
if {[catch {package require tablelist} e]} {
    puts "tablelist not available: $e"
    puts "skipped -- this how-to needs the tablelist package"
    exit 0
}
package require pdf4tcltable

# ---------------------------------------------------------------------------
# A widget, as an application would have it
# ---------------------------------------------------------------------------

tablelist::tablelist .tbl \
        -columns {0 "Item" left  0 "Quantity" right  0 "Price" right} \
        -stretch all -background white
foreach row {
    {Cable 2 12.50} {Adapter 1 8.90} {Case 1 24.00} {Cover 4 3.25}
} {
    .tbl insert end $row
}
# Sorting and hiding are the reason this export exists: what leaves the
# widget is what the user sees, in the order they see it -- not the data
# behind it.
#
# Note the sort mode: tablelist compares as strings unless told otherwise,
# so "8.90" sorts above "24.00". Measured -- the export then shows exactly
# that, because it takes the display order and not the data behind it.
# -sortmode real is what this column wants.
.tbl columnconfigure 2 -sortmode real
.tbl sortbycolumn 2 -decreasing
pack .tbl
update

# ---------------------------------------------------------------------------
# The export
# ---------------------------------------------------------------------------

set ::pdf4tcl::warnings {}
set pdf [::pdf4tcl::new %AUTO% -compress 0 -margin 25]
$pdf tagged 1 -lang en-GB
$pdf startPage
$pdf setFont 10 Helvetica

::pdf4tcllib::tag::begin $pdf Caption
$pdf text "Order items, sorted by price" -x 50 -y 50
::pdf4tcllib::tag::end $pdf

# render delegates to table::draw, so the structure comes for free:
# Table / TR / TH with /Scope Column / TD, and the widget's zebra stripes
# and grid lines as Layout artifacts. Nothing extra to write here.
::pdf4tcllib::tablelist::render $pdf .tbl 50 70 -maxwidth 480

set left [pdf4tcllib::doc::finish $pdf \
        [pdf4tcllib::doc::outfile howto-tablelist-export.pdf]]
destroy .tbl
exit 0
