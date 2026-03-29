#!/usr/bin/env tclsh
# Demo 34: Table Layout with Headers
# pdf4tcl 0.9.4.11 — orient true (origin top-left), no ytop

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_34_table_basic.pdf]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]
set PAGE_W [lindex $DA 0]
set PAGE_H [lindex $DA 1]

$pdf setFont 16 Helvetica
$pdf text "Table Layout with Headers" -x 40 -y 40

$pdf setFont 12 Helvetica

# Simple table drawer

set cols {140 200 140}
set y 90
set rows {
    {"Name" "Email" "Role"}
    {"Alice" "alice@example.com" "Admin"}
    {"Bob" "bob@example.com" "User"}
    {"Carol" "carol@example.com" "User"}
    {"Dave" "dave@example.com" "Editor"}
}
pdf4tcllib::table::simpleTable $pdf 40 $y $cols $rows

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile"

