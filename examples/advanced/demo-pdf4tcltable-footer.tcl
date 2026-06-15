#!/usr/bin/env wish
# ===========================================================================
# Demo: Tablelist -> PDF with footer row and full Unicode (pdf4tcltable 0.2)
#
#   - footer from an explicit value list  (-footer {...})
#   - footer from a tkutlfooter widget    (-footer .foot)
#   - Unicode cells (€, Greek, ∑) via TTF/CID fonts
#
# Usage:  wish demo-pdf4tcltable-footer.tcl ?outdir?
# ===========================================================================

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcltable 0.2
package require pdf4tcl

# tablelist -- from a few well-known locations or the module path
set found 0
foreach p [list \
        [file normalize [file join $scriptDir .. .. .. tablelist7.10]] \
        [file normalize [file join $scriptDir .. .. .. .. tablelist7.10]] \
        /usr/share/tcltk/tablelist7.10 \
        /usr/lib/tcltk/tablelist7.10] {
    if {[file isdir $p]} { lappend auto_path $p; set found 1; break }
}
if {[catch {package require tablelist} err]} {
    puts stderr "tablelist not found: $err"; exit 1
}
# tkutlfooter is optional (for the widget-footer variant)
set haveFooterPkg [expr {![catch {package require tkutils::tkutlfooter}]}]

# Enable Unicode rendering (TTF + CID). Adjust -fontdir for your platform.
foreach fd {/usr/share/fonts/truetype/dejavu /usr/share/fonts/TTF \
            C:/Windows/Fonts} {
    if {[file isdir $fd]} {
        catch {::pdf4tcllib::fonts::init -fontdir $fd -cid 1}
        break
    }
}

# --- build a tablelist with Unicode content ---
tablelist::tablelist .tbl \
    -columns [list 14 "Artikel \u03b1" left  8 "Menge" right  14 "Preis \u20ac" right] \
    -stripebackground #eef
.tbl insert end [list "\u00c4pfel"      3 "1,50 \u20ac"]
.tbl insert end [list "Birne \u03b2"    5 "2,00 \u20ac"]
.tbl insert end [list "Kirsche \u2211" 12 "4,20 \u20ac"]
.tbl insert end [list "Pflaume"         7 "3,10 \u20ac"]
pack .tbl -fill both -expand 1

# --- optional footer widget via tkutlfooter (auto-sum) ---
if {$haveFooterPkg} {
    tablelist::tablelist .foot -showlabels 0 -height 1 \
        -columns {14 {} left 8 {} right 14 {} right}
    pack .foot -fill x
    ::tkutils::tkutlfooter::attach  .tbl .foot
    ::tkutils::tkutlfooter::autosum .tbl .foot -columns {1 2} \
        -label "Summe \u03a3" -format "%g"
}

# --- render to PDF ---
set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_pdf4tcltable_footer.pdf"]

set pdf [pdf4tcl::new %AUTO% -paper a4 -margin 36]
$pdf startPage
set bold Helvetica-Bold
catch {set bold [::pdf4tcllib::fonts::fontSansBold]}
$pdf setFont 12 $bold
$pdf text "pdf4tcltable 0.2 -- Footer + Unicode" -x 36 -y 50

# A) footer as an explicit value list
$pdf setFont 10 $bold
$pdf text "A) Footer als Werteliste" -x 36 -y 80
set y [::pdf4tcllib::tablelist::render $pdf .tbl 36 92 -maxwidth 360 \
        -footer [list "Summe \u03a3" 27 "10,80 \u20ac"]]

# B) footer from the tkutlfooter widget (if available)
if {$haveFooterPkg} {
    $pdf setFont 10 $bold
    $pdf text "B) Footer aus tkutlfooter-Widget" -x 36 -y [expr {$y+28}]
    ::pdf4tcllib::tablelist::render $pdf .tbl 36 [expr {$y+40}] -maxwidth 360 \
        -footer .foot -footerbg {0.88 0.92 0.85}
}

$pdf write -file $outPDF
$pdf destroy
puts "wrote $outPDF"
if {[lindex $argv end] eq "--exit"} { exit 0 }
