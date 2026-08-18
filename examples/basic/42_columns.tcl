#!/usr/bin/env tclsh
# ===========================================================================
# Demo 42: Two-column text flow and a watermark (pdf4tclflow)
#
# The text fills column one, continues in column two and carries on at the
# top of the next page. The page break is handed back to the caller,
# because only the caller knows what a new page needs -- here a running
# head and the same watermark again.
# ===========================================================================

package require pdf4tcllib
package require pdf4tclflow

set scriptDir [file dirname [file normalize [info script]]]
set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_42_columns.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -pdfa 3b]
::pdf4tcllib::fonts::init
set ctx [::pdf4tcllib::page::context a4]

set body ""
foreach para {
    "A column of text is a simple thing until it has to end. The last line
     of a column is not the last line of the paragraph, and the first line
     of the next column must not be the blank line that separated two
     paragraphs -- that is what leaves a stray gap at the top."
    "So the flow keeps a list of lines, with an empty string where a
     paragraph ends, and skips that empty string whenever a column starts.
     One loop, not two."
    "The page break is a script the caller supplies. It runs whenever the
     last column is full, and it must leave a page open. Anything a new
     page needs -- a running head, a watermark, a rule along the top --
     goes in there."
    "Without such a script the flow stops when it runs out of columns and
     returns what is left, rather than dropping it on the floor. Silence
     would be the worse answer: a report that is missing its last page and
     says nothing about it looks exactly like a complete one."
    "The arithmetic itself is unremarkable. Wrap every paragraph to the
     column width, count the lines, fill column after column. What takes
     the care is the boundary: the moment the text moves from one column
     to the next, and from one page to the next."
} {
    append body [regsub -all {\s+} [string trim $para] " "] "\n\n"
}
set body [string repeat $body 8]

proc newPage {} {
    global pdf ctx
    $pdf endPage
    $pdf startPage
    ::pdf4tcllib::drawing::watermark $pdf $ctx "DRAFT"
    ::pdf4tcllib::page::header $pdf $ctx "pdf4tclflow -- demo 42"
}

$pdf startPage
::pdf4tcllib::drawing::watermark $pdf $ctx "DRAFT"
::pdf4tcllib::page::header $pdf $ctx "pdf4tclflow -- demo 42"

set result [::pdf4tcllib::flow::columns $pdf $ctx $body \
    -columns 2 -gap 20 -size 10 \
    -top [expr {[dict get $ctx top] + 30}] \
    -newpage newPage]

$pdf endPage
$pdf write -file $outPDF

puts "Geschrieben: $outPDF"
puts "  Zeilen:      [dict get $result lines]"
puts "  Seitenwechsel: [dict get $result pages]"
puts "  Rest:        '[dict get $result rest]'"
exit 0
