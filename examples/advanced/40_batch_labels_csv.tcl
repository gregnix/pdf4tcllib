#!/usr/bin/env tclsh
# Demo 40: Batch Labels from CSV (one PDF per line)
# pdf4tcl 0.9.4.11 — orient true (origin top-left), no ytop

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_40_batch_labels_csv.pdf]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set DA [$pdf getDrawableArea]
set PAGE_W [lindex $DA 0]
set PAGE_H [lindex $DA 1]

$pdf setFont 16 Helvetica
$pdf text "Batch Labels from CSV (one PDF per line)" -x 40 -y 40

$pdf setFont 12 Helvetica

# Input CSV expected at ../input/labels.csv with lines: name,street,city
set csvPath [file normalize [file join $scriptDir ../.. input labels.csv]]
if {![file exists $csvPath]} {
    # Create input directory and sample file
    file mkdir [file dirname $csvPath]
    set fp [open $csvPath w]
    puts $fp "Jane Doe,Main Street 1,12345 Sampletown"
    puts $fp "John Roe,Oak Avenue 5,98765 Anytown"
    close $fp
}

# Label generator: simple centered block
proc generate_label {name street city outpdf} {
    set p [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $p startPage
    $p setFont 18 Helvetica
    $p text $name   -x 80 -y 140
    $p setFont 14 Helvetica
    $p text $street -x 80 -y 168
    $p text $city   -x 80 -y 192
    $p endPage
    $p write -file $outpdf
    $p destroy
}

# Read CSV
set fp [open $csvPath r]
set data [read $fp]
close $fp
set lines [split $data "\n"]

set count 0
foreach line $lines {
    if {[string trim $line] eq ""} continue
    set parts [split $line ","]
    if {[llength $parts] < 3} continue
    lassign $parts name street city
    set outpdf [file normalize [file join $outdir [format "batch_%03d.pdf" $count]]]
    generate_label [string trim $name] [string trim $street] [string trim $city] $outpdf
    incr count
}

# Also write an index page
$pdf text "Generated $count label PDFs into output/" -x 40 -y 90

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Wrote $outfile (plus $count batch_XXX.pdf files)"

