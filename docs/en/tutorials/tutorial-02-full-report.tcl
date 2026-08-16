#!/usr/bin/env tclsh
# tutorial-02-full-report.tcl -- a complete report: contents page with real
# page numbers, two-column body, charts, a table, a watermark.
#
#   tclsh tutorial-02-full-report.tcl [outdir]
#
# Everything here is drawn by pdf4tcllib blocks; the only pdf4tcl calls are
# startPage, endPage and write.

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]

package require pdf4tcltoc
package require pdf4tclchart
package require pdf4tclflow

# ---------------------------------------------------------------------------
# Step 1 -- fonts first, as always
# ---------------------------------------------------------------------------
#
# The blocks take their font from this configuration. Without an embeddable
# font the document can be tagged and still not be PDF/UA conformant, so
# this comes before anything is drawn.

set ttf [pdf4tcllib::doc::findTTF]
if {$ttf ne ""} {
    ::pdf4tcllib::fonts::init -fontdir [file dirname $ttf]
}

set pdf [::pdf4tcl::new %AUTO% -paper a4 -margin 25]
# The language belongs to `tagged`, not to `metadata` -- a screen reader
# picks its pronunciation from it. (metadata takes -title, -author and the
# rest; passing -lang there is an error, which is how I learnt it.)
$pdf tagged 1 -lang de-DE
$pdf metadata -title "Quartalsbericht" -author "pdf4tcllib"
set ctx [::pdf4tcllib::page::context a4 -margin 25]

set out [pdf4tcllib::doc::outfile tutorial-02-full-report.pdf]

# ---------------------------------------------------------------------------
# Step 2 -- what a new page needs, in one place
# ---------------------------------------------------------------------------
#
# Both the flow and the body use this. Writing it once is not tidiness: a
# second copy would drift, and the page that got the drifted version is the
# one nobody looks at.

set ::pageNo 0

proc newPage {} {
    global pdf ctx pageNo
    if {[$pdf inPage]} { $pdf endPage }
    $pdf startPage
    incr pageNo
    # The watermark goes FIRST: there is no transparency in pdf4tcl, so it
    # has to lie underneath everything else.
    ::pdf4tcllib::drawing::watermark $pdf $ctx "ENTWURF"
    ::pdf4tcllib::page::header $pdf $ctx "Quartalsbericht 2026"
    ::pdf4tcllib::page::footer $pdf $ctx "vertraulich" $pageNo
    return [expr {[dict get $ctx top] + 34}]
}

# ---------------------------------------------------------------------------
# Step 3 -- the body, as a script that can run twice
# ---------------------------------------------------------------------------
#
# toc::document lays the document out twice: once into a throwaway document
# to learn which page each heading lands on, once for real with the
# contents in front. So this script must not have side effects -- note that
# $pageNo is reset before each run rather than counted up across both.

set lorem "Die Zahlen des Quartals folgen dem Muster der Vorjahre: ein
    schwacher Januar, ein starker Maerz, und ein Ausreisser im April, den
    niemand vorhergesagt hat. Die Abweichung liegt innerhalb dessen, was
    die Planung als Schwankungsbreite angesetzt hatte."

set body ""
foreach n {1 2 3 4 5 6} {
    append body [regsub -all {\s+} [string trim $lorem] " "] "\n\n"
}

set umsatz  {Jan 120 Feb 145 Mrz 98 Apr 160 Mai 132 Jun 178}
set regionen {Nord 35 Sued 25 Ost 20 West 20}

set content {
    set ::pageNo 0
    set y [newPage]

    # --- 1. Ueberblick ---------------------------------------------------
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Ueberblick"

    # Two columns of running text. The page break is handed back to us, so
    # every new page gets its watermark and running head.
    set res [::pdf4tcllib::flow::columns $pdf $ctx $body \
            -columns 2 -size 10 -top [expr {[dict get $ctx top] + 34}] \
            -firsty $y -newpage {set y [newPage]}]
    set y [dict get $res y]

    # --- 2. Umsatz -------------------------------------------------------
    set y [newPage]
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Umsatz"
    ::pdf4tcllib::toc::heading $pdf $ctx y 2 "Nach Monat"

    # A chart is a Figure with an alternate text. The numbers themselves
    # follow as a table -- see the note at the end of the tutorial.
    set y [::pdf4tcllib::chart::bar $pdf [dict get $ctx left] $y \
            [dict get $ctx text_w] 170 $umsatz \
            -title "Umsatz je Monat (kEUR)" -values 1 -format %.0f \
            -alt "Balkendiagramm: Umsatz je Monat, Januar bis Juni,\
                  zwischen 98 und 178 tausend Euro"]

    set y [expr {$y + 16}]
    set cols {}
    foreach {m v} $umsatz {
        lappend cols [list -header $m -align right]
    }
    set y [::pdf4tcllib::table::draw $pdf [dict get $ctx left] $y \
            $cols [list [lmap {m v} $umsatz {set v}]] \
            -maxwidth [dict get $ctx text_w] -yvar y]

    # --- 3. Regionen -----------------------------------------------------
    set y [newPage]
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Regionen"
    set y [::pdf4tcllib::chart::pie $pdf [dict get $ctx left] $y \
            [dict get $ctx text_w] 200 $regionen \
            -title "Anteile nach Region" -legend 1 \
            -alt "Kreisdiagramm: Nord 35, Sued 25, Ost 20, West 20 Prozent"]

    # --- 4. Anhang -------------------------------------------------------
    ::pdf4tcllib::toc::heading $pdf $ctx y 1 "Anhang"
    set y [::pdf4tcllib::text::writeParagraph $pdf \
            "Alle Zahlen in tausend Euro, ungeprueft." \
            [dict get $ctx left] $y [dict get $ctx text_w] 10]

    $pdf endPage
}

# ---------------------------------------------------------------------------
# Step 4 -- run it
# ---------------------------------------------------------------------------
#
# document draws the contents page itself, before the content.

set result [::pdf4tcllib::toc::document $pdf a4 $content -title "Inhalt"]

$pdf finish
$pdf write -file $out

puts "Geschrieben: $out"
puts "  Verzeichnis: [dict get $result tocPages] Seite(n)"
puts "  Inhalt:      [dict get $result contentPages] Seite(n)"
puts "  ungetaggt:   [$pdf getUntaggedCount]"
foreach e [dict get $result entries] {
    lassign $e level title page
    puts [format "  %s%-20s %s" [string repeat "  " [expr {$level - 1}]] $title $page]
}
exit 0
