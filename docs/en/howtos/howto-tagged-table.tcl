#!/usr/bin/env tclsh
# howto-tagged-table.tcl -- a table a screen reader can navigate
#
#   tclsh howto-tagged-table.tcl [outdir]

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]

set ::pdf4tcl::warnings {}
set pdf [::pdf4tcl::new %AUTO% -compress 0 -margin 25]

# Without this line nothing below marks up anything, and the output is a
# plain PDF. The helpers stay silent when tagging is off, so the same code
# serves both cases.
$pdf tagged 1 -lang en-GB
$pdf startPage
$pdf setFont 11 Helvetica

# --- the short way -------------------------------------------------------
#
# simpleTable marks up what it draws: Table / TR / TH / TD. The first row
# is the header -- the row -header_bg paints -- and its cells carry
# /Scope Column, which ISO 14289-1 clause 7.5 requires wherever a single
# header row is used, because the relation cannot be read off the layout.

set rows {
    {Item Quantity Price}
    {Cable 2 12.50}
    {Adapter 1 8.90}
    {Case 1 24.00}
}
::pdf4tcllib::table::simpleTable $pdf 50 60 {150 90 90} $rows -zebra 1

# Grid lines, zebra stripes and the header background become Layout
# artifacts. That is not politeness: announced as content a reader reads
# out the separators between the numbers, which is worse than no markup.

# --- what stays your job -------------------------------------------------
#
# A caption is content and belongs to the document, so it needs an element.
# Caption is the type ISO 32000-1 table 335 gives for it.

::pdf4tcllib::tag::begin $pdf Caption
$pdf setFont 9 Helvetica
$pdf text "Table 1: order items" -x 50 -y 200
::pdf4tcllib::tag::end $pdf

pdf4tcllib::doc::finish $pdf [pdf4tcllib::doc::outfile howto-tagged-table.pdf]
