#!/usr/bin/env tclsh
# ===========================================================================
# Demo 40: Table of contents with real page numbers (pdf4tcltoc)
#
# The page number of a heading is only known once the document is laid out,
# and putting the contents in front shifts every one of them. toc::document
# lays the document out twice: once into a throwaway document to learn the
# numbers, once for real with the contents written first.
#
# The content script therefore runs TWICE and must not have side effects.
# ===========================================================================

package require pdf4tcllib
package require pdf4tcltoc

set scriptDir [file dirname [file normalize [info script]]]
set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_40_toc.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4]

set body [string repeat "Lorem ipsum dolor sit amet, consetetur sadipscing\
        elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore\
        magna aliquyam erat, sed diam voluptua. " 3]

set chapters {
    {1 "Introduction"}
    {2 "What this is for"}
    {2 "What it is not"}
    {1 "Getting started"}
    {2 "Installation"}
    {2 "First document"}
    {1 "Reference"}
    {1 "Appendix"}
}

set result [::pdf4tcllib::toc::document $pdf a4 {
    set x [dict get $ctx left]
    set w [dict get $ctx text_w]
    $pdf startPage
    set y [dict get $ctx top]
    foreach ch $chapters {
        lassign $ch level title
        ::pdf4tcllib::toc::heading $pdf $ctx y $level $title
        set paragraphs [expr {$level == 1 ? 4 : 2}]
        for {set i 0} {$i < $paragraphs} {incr i} {
            set y [::pdf4tcllib::text::writeParagraph $pdf $body $x $y $w 11]
            ::pdf4tcllib::page::_advance $ctx y 8
            if {$y > [dict get $ctx bottom] - 80} {
                $pdf endPage
                $pdf startPage
                set y [dict get $ctx top]
            }
        }
    }
    $pdf endPage
} -title "Contents"]

$pdf write -file $outPDF

puts "Geschrieben: $outPDF"
puts "  Verzeichnis: [dict get $result tocPages] Seite(n)"
puts "  Inhalt:      [dict get $result contentPages] Seite(n)"
foreach e [dict get $result entries] {
    lassign $e level title page
    puts [format "  %s%-24s %s" [string repeat "  " [expr {$level - 1}]] $title $page]
}
exit 0
