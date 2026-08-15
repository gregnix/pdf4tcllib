#!/usr/bin/env tclsh
# Demo 39: Accessible documents -- what pdf4tcllib tags by itself,
#          and what stays your job.
#
#   tclsh 39_accessible.tcl [outdir]

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outfile [file join $outdir "demo_39_accessible.pdf"]

# ---------------------------------------------------------------------------
# 1. Switch tagging on -- nothing marks up anything without this
# ---------------------------------------------------------------------------
#
# pdf4tcllib checks once per document whether tagging is active and stays
# quiet when it is not. So the same code produces a plain PDF or a tagged
# one, depending on this single line.

set ::pdf4tcl::warnings {}
set pdf [::pdf4tcl::new %AUTO% -compress 0 -margin 25]
$pdf tagged 1
$pdf startPage
$pdf setFont 11 Helvetica

set ctx [::pdf4tcllib::page::context a4 -margin 25 -orient true]
set y 60

# ---------------------------------------------------------------------------
# 2. What the building blocks do on their own
# ---------------------------------------------------------------------------
#
# Running head and page number become Pagination artifacts: they are not
# what the document says, and a reader that announces them repeats the
# title on every page.

::pdf4tcllib::page::header $pdf $ctx "Accessible document"

# A paragraph is P by default. Pass a type for anything else -- the
# procedure cannot know whether this line is body text or a heading.
::pdf4tcllib::text::writeParagraph $pdf "What follows is tagged" \
        50 90 400 14 left H1
set y 130
::pdf4tcllib::text::writeParagraph $pdf \
        "Every building block below marks up what it draws. Decoration is\
         marked as an artifact instead, which keeps a screen reader from\
         announcing rules and shading as if they meant something." \
        50 $y 400

# A table becomes Table / TR / TH / TD. The first row is the header -- the
# one -header_bg paints -- and its cells carry /Scope Column, which
# ISO 14289-1 clause 7.5 asks for whenever a single header row is used.
::pdf4tcllib::table::simpleTable $pdf 50 200 {120 100 100} {
    {Item Quantity Price}
    {Cable 2 12.50}
    {Adapter 1 8.90}
}

# A form field is wrapped in a Form element together with its label, so the
# field can be reached from the structure tree and carries a name.
set y 300
::pdf4tcllib::form::section $pdf $ctx y "Order"
::pdf4tcllib::form::labelField $pdf $ctx y "Name" text -id nm
::pdf4tcllib::form::separator $pdf $ctx y
::pdf4tcllib::form::labelField $pdf $ctx y "Delivery" checkbox -id exp

::pdf4tcllib::page::number $pdf $ctx 1 1

# ---------------------------------------------------------------------------
# 3. What stays your job
# ---------------------------------------------------------------------------
#
# Anything drawn with pdf4tcl directly is content that belongs to nothing.
# Wrap it, or mark it as an artifact if it carries no meaning.

::pdf4tcllib::tag::begin $pdf P
$pdf text "Drawn directly, wrapped by hand." -x 50 -y 700
::pdf4tcllib::tag::end $pdf

::pdf4tcllib::tag::artifact $pdf -type Layout
$pdf setStrokeColor 0.8 0.8 0.8
$pdf line 50 710 450 710
$pdf setStrokeColor 0 0 0
::pdf4tcllib::tag::artifactEnd $pdf

# ---------------------------------------------------------------------------
# 4. Check before writing
# ---------------------------------------------------------------------------
#
# getUntaggedCount reports painting operations that belong to neither a
# structure element nor an artifact. Zero is what PDF/UA clause 7.1 asks
# for. finish() reports the same thing once, in ::pdf4tcl::warnings.

set left [$pdf getUntaggedCount]
$pdf write -file $outfile
$pdf destroy

puts "wrote $outfile"
puts "untagged painting operations: $left"
if {$left != 0} {
    puts "  -> something on the page belongs to nothing; wrap it or mark it"
}
foreach w $::pdf4tcl::warnings {
    puts "warning: $w"
}
puts ""
puts "Check with:"
puts "  qpdf --check $outfile"
puts "  verapdf -f ua1 $outfile"
puts ""
puts "Note the font warning: the 14 standard fonts have no embeddable font"
puts "program, so this document is tagged but not PDF/UA conformant. Load a"
puts "TrueType font for that -- see pdf4tcl-fonts-and-unicode.md."
