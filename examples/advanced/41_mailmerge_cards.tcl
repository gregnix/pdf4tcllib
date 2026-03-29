#!/usr/bin/env tclsh
# Demo 41: Mail-merge: Multiple Cards per Page
# pdf4tcl 0.9.4.11 — orient true (origin top-left), no ytop

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_41_mailmerge_cards.pdf]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]
set PAGE_W [lindex $DA 0]
set PAGE_H [lindex $DA 1]

$pdf setFont 16 Helvetica
$pdf text "Mail-merge: Multiple Cards per Page" -x 40 -y 40

$pdf setFont 12 Helvetica

# Sample rows
set rows {
    {"Alice Example" "alice@example.com" "+49 123 4567"}
    {"Bob Sample"    "bob@example.com"   "+49 555 000"}
    {"Carol Demo"    "carol@demo.org"    "+49 987 654"}
    {"Dave Test"     "dave@test.io"      "+49 321 765"}
    {"Eve Person"    "eve@host.net"      "+49 111 222"}
    {"Frank Unit"    "frank@unit.dev"    "+49 444 555"}
    {"Grace Case"    "grace@case.com"    "+49 222 333"}
    {"Heidi Grid"    "heidi@grid.net"    "+49 888 777"}
    {"Ivan Row"      "ivan@row.net"      "+49 666 555"}
    {"Judy Col"      "judy@col.dev"      "+49 101 202"}
}

# Layout: 2 columns x 5 rows of cards
set margin 40
set gutter 20
set cols 2
set rowsPerPage 5
set innerW [expr {$PAGE_W - 2*$margin}]
set innerH [expr {$PAGE_H - 2*$margin}]
set cardW [expr {($innerW - ($cols-1)*$gutter)/$cols}]
set cardH [expr {$innerH / $rowsPerPage}]

proc draw_card {pdf x y w h person} {
    $pdf setStrokeColor 0 0 0
    $pdf rectangle $x $y $w $h
    $pdf setFont 12 Helvetica
    set name  [lindex $person 0]
    set email [lindex $person 1]
    set phone [lindex $person 2]
    $pdf text $name  -x [expr {$x+8}] -y [expr {$y+22}]
    $pdf text $email -x [expr {$x+8}] -y [expr {$y+42}]
    $pdf text $phone -x [expr {$x+8}] -y [expr {$y+62}]
}

set idx 0
set total [llength $rows]
for {set i 0} {$i < $total} {incr i} {
    set r [expr {int(($i)/$cols)%$rowsPerPage}]
    set c [expr {($i)%$cols}]
    set page [expr {int($i/($cols*$rowsPerPage))}]
    if {$i>0 && $r==0 && $c==0} {
        $pdf endPage
        $pdf startPage
        $pdf setFont 12 Helvetica
    }
    set x [expr {$margin + $c*($cardW+$gutter)}]
    set y [expr {$margin + $r*$cardH}]
    draw_card $pdf $x $y $cardW [expr {$cardH-6}] [lindex $rows $i]
}

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"

