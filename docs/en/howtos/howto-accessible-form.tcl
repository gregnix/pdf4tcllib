#!/usr/bin/env tclsh
# howto-accessible-form.tcl -- a form whose fields have names
#
#   tclsh howto-accessible-form.tcl [outdir]

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]

set ::pdf4tcl::warnings {}

# A form that claims PDF/UA needs an embedded font: the 14 standard fonts
# have no embeddable font program (7.21.4.1). Without a TTF on the machine
# this still runs -- it is then tagged, but not conformant, and pdf4tcl
# says so at the end.
# Load the font through pdf4tcllib::fonts, not through pdf4tcl directly.
# The building blocks pick their own font from that configuration -- set
# one with "$pdf setFont" alone and form::section still draws its title in
# Helvetica-Bold, which is exactly the font that cannot be embedded.
# Measured: the warning then names Helvetica-Bold, a font this script
# never asked for.
set ttf [pdf4tcllib::doc::findTTF]
if {$ttf ne ""} {
    ::pdf4tcllib::fonts::init -fontdir [file dirname $ttf]
}
if {![::pdf4tcllib::fonts::hasTtf]} {
    puts "no TrueType font found -- the result is tagged but not conformant"
}

set pdf [::pdf4tcl::new %AUTO% -compress 0 -margin 25]
$pdf tagged 1 -ua 1 -lang en-GB
$pdf startPage
::pdf4tcllib::fonts::setFont $pdf 11 [::pdf4tcllib::fonts::fontSans]

set ctx [::pdf4tcllib::page::context a4 -margin 25 -orient true]
set y 60

# A section title is the heading of the block it opens: H2. Bar and frame
# are decoration and become artifacts.
::pdf4tcllib::form::section $pdf $ctx y "Delivery address"

# labelField puts the caption INSIDE the Form element that holds the
# field's /OBJR. That is the point: a field outside the tree cannot be
# reached, and a caption outside it names nothing. Before 0.6.1 the label
# sat outside -- one untagged painting operation per field, which reads as
# an input with no visible name.
::pdf4tcllib::form::labelField $pdf $ctx y "Name" text -id nm
::pdf4tcllib::form::labelField $pdf $ctx y "Street" text -id st
::pdf4tcllib::form::row $pdf $ctx y {
    {label "Postcode:" type text width 160 id plz}
    {label "Town:"     type text width 220 id ort}
}
::pdf4tcllib::form::separator $pdf $ctx y
::pdf4tcllib::form::labelField $pdf $ctx y "Express" checkbox -id exp

# The page number is pagination, not content.
::pdf4tcllib::page::number $pdf $ctx 1 1

set left [pdf4tcllib::doc::finish $pdf \
        [pdf4tcllib::doc::outfile howto-accessible-form.pdf]]

puts ""
puts "Check with:"
puts "  verapdf -f ua1 <file>      PDF/UA-1"
puts "  verapdf -f 3a  <file>      PDF/A-3a -- run both, the interesting"
puts "                             errors sit between the profiles"
