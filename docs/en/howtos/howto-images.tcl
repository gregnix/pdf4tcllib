#!/usr/bin/env tclsh
# howto-images.tcl -- a Tk image in a PDF, and the alternate text that
# makes it mean something.
#
#   tclsh howto-images.tcl [outdir]
#
# Needs Tk and a display. Without one it says so and exits 0 -- there is
# nothing to test here, and a run that cannot load Tk is not a failure.

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]

# pdf4tcllib does not load Tk any more when the module is read -- only the
# image helpers need it, and pulling it into every batch script meant every
# script without an exit hung on a machine with a display. So ask for it
# here, and give up cleanly when it is not there.
if {[catch {package require Tk} e]} {
    puts "Tk not available: $e"
    puts "skipped -- this how-to needs Tk and a display"
    exit 0
}

set ::pdf4tcl::warnings {}
set pdf [::pdf4tcl::new %AUTO% -compress 0 -margin 25]
$pdf tagged 1 -lang en-GB
$pdf startPage
$pdf setFont 11 Helvetica

# A small image drawn on the spot, so this runs without a data file.
image create photo demoImg -width 120 -height 60
for {set x 0} {$x < 120} {incr x} {
    set shade [format "#%02x%02x%02x" [expr {$x * 2}] 80 [expr {200 - $x}]]
    demoImg put $shade -to $x 0 [expr {$x + 1}] 60
}

# ---------------------------------------------------------------------------
# The image itself
# ---------------------------------------------------------------------------
#
# A picture is content, so it belongs in a Figure -- and a Figure without
# alternate text tells a reader that something is there and nothing about
# what. ISO 14289-1 clause 7.3 requires the text; it is the one thing no
# tool can supply for you.

set y      60
set pageNo 1

::pdf4tcllib::tag::begin $pdf Figure -alt "Colour gradient, blue to orange"
::pdf4tcllib::image::insert $pdf demoImg 50 y 300 40 780 pageNo 595 842 25 10
::pdf4tcllib::tag::end $pdf

# A caption is separate content, not part of the Figure.
::pdf4tcllib::tag::begin $pdf Caption
$pdf text "Figure 1: a gradient" -x 50 -y [expr {$y + 12}]
::pdf4tcllib::tag::end $pdf

# ---------------------------------------------------------------------------
# When a picture carries no meaning
# ---------------------------------------------------------------------------
#
# A rule, a background, a decorative flourish: mark it as an artifact
# instead. A Figure with alt text "decorative line" is worse than an
# artifact -- it makes a reader stop for something that means nothing.

::pdf4tcllib::tag::artifact $pdf -type Layout
$pdf setFillColor 0.9 0.9 0.95
$pdf rectangle 50 [expr {$y + 30}] 300 8 -filled 1
$pdf setFillColor 0 0 0
::pdf4tcllib::tag::artifactEnd $pdf

image delete demoImg
pdf4tcllib::doc::finish $pdf [pdf4tcllib::doc::outfile howto-images.pdf]
exit 0
