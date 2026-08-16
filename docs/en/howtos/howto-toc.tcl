#!/usr/bin/env tclsh
# howto-toc.tcl -- a contents page whose numbers are right.
#
#   tclsh howto-toc.tcl [outdir]

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]

package require pdf4tcltoc

set ttf [pdf4tcllib::doc::findTTF]
if {$ttf ne ""} { ::pdf4tcllib::fonts::init -fontdir [file dirname $ttf] }

set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 25]
$pdf tagged 1 -lang en-GB

# The chapters, and enough text under each to force page breaks.
set chapters {
    {1 "Introduction"}
    {2 "Scope"}
    {2 "Conventions"}
    {1 "Installation"}
    {1 "Usage"}
    {2 "First document"}
    {2 "Page layout"}
    {1 "Appendix"}
}
set para "Every heading below is written with toc::heading, which draws it,
    records the page it lands on and adds a bookmark. Nothing else in this
    file knows anything about page numbers."
set para [regsub -all {\s+} [string trim $para] " "]

# --- the content script -----------------------------------------------------
#
# It runs TWICE: once into a throwaway document to learn the page numbers,
# once for real with the contents in front of it. So it must not have side
# effects -- no appending to a file, no counter that survives between runs.
#
# It sees two variables of its own: pdf and ctx.

set content {
    $pdf startPage
    set y [dict get $ctx top]
    set x [dict get $ctx left]
    set w [dict get $ctx text_w]

    foreach ch $chapters {
        lassign $ch level title
        ::pdf4tcllib::toc::heading $pdf $ctx y $level $title

        set n [expr {$level == 1 ? 5 : 3}]
        for {set i 0} {$i < $n} {incr i} {
            set y [::pdf4tcllib::text::writeParagraph $pdf $para $x $y $w 10]
            ::pdf4tcllib::page::_advance $ctx y 8

            # The caller owns the page break here -- toc::document does not
            # lay out the body, it only runs this script.
            if {$y > [dict get $ctx bottom] - 70} {
                $pdf endPage
                $pdf startPage
                set y [dict get $ctx top]
            }
        }
    }
    $pdf endPage
}

set result [::pdf4tcllib::toc::document $pdf a4 $content \
        -title "Contents" -leader "." -indent 16]

set out [pdf4tcllib::doc::outfile howto-toc.pdf]
$pdf write -file $out

puts "Geschrieben: $out"
puts "  contents: [dict get $result tocPages] page(s)"
puts "  content:  [dict get $result contentPages] page(s)"
foreach e [dict get $result entries] {
    lassign $e level title page
    puts [format "  %s%-20s %s" [string repeat "  " [expr {$level - 1}]] $title $page]
}

# The check that matters: does the contents agree with the document? This
# is what the test suite does, and it is worth doing once by hand too --
# every number in a contents page is a claim about a different page.
if {[llength [auto_execok pdftotext]]} {
    set wrong 0
    foreach e [dict get $result entries] {
        lassign $e level title page
        set found 0
        for {set p 1} {$p <= [dict get $result tocPages] + [dict get $result contentPages]} {incr p} {
            set txt ""
            catch {set txt [exec pdftotext -f $p -l $p $out -]}
            foreach line [split $txt \n] {
                if {[string trim $line] eq $title} { set found $p; break }
            }
            if {$found} break
        }
        if {$found != $page} {
            puts "  MISMATCH: $title says $page, is on $found"
            incr wrong
        }
    }
    puts "  mismatches: $wrong"
}
exit 0
