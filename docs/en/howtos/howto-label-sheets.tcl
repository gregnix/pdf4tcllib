#!/usr/bin/env tclsh
# howto-label-sheets.tcl -- parcel labels on a Zweckform sheet, from data.
#
#   tclsh howto-label-sheets.tcl [outdir]

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]
package require pdf4tcllabels

set ttf [pdf4tcllib::doc::findTTF]
if {$ttf ne ""} { ::pdf4tcllib::fonts::init -fontdir [file dirname $ttf] }

# ---------------------------------------------------------------------------
# 1. The data -- here inline, in practice from CSV, JSON or a database
# ---------------------------------------------------------------------------
#
# One record per consignment, not per label: how many labels it needs is a
# property of the consignment ("Karton 1 von 4"), and computing that here
# keeps the drawing code free of counting.

set consignments {
    {name "Manfred Muster"   street "Musterstr. 4"    city "55555 Muster"
     tour "Tour 4 Mo 24.08.26"  cartons 4}
    {name "Erika Beispiel"   street "Beispielweg 12"  city "12345 Beispielstadt"
     tour "Tour 4 Mo 24.08.26"  cartons 2}
    {name "Firma Test GmbH"  street "Testallee 7a"    city "98765 Testheim"
     tour "Tour 7 Di 25.08.26" cartons 1}
}

# Expand to one record per label. This is where "1 von 4" comes from.
set labels {}
foreach c $consignments {
    set n [dict get $c cartons]
    for {set i 1} {$i <= $n} {incr i} {
        dict set c carton $i
        dict set c of     $n
        lappend labels $c
    }
}
puts "[llength $consignments] consignments -> [llength $labels] labels"

# ---------------------------------------------------------------------------
# 2. The sheet
# ---------------------------------------------------------------------------

set geo [::pdf4tcllib::labels::sheet 3474]
puts "sheet: [dict get $geo desc]"
puts "       [dict get $geo cols] x [dict get $geo rows] =\
        [dict get $geo perSheet] per sheet"

set ::pdf4tcl::warnings {}
set pdf [::pdf4tcl::new %AUTO% -compress 0]
$pdf tagged 1 -lang de-DE

# ---------------------------------------------------------------------------
# 3. One script draws one label
# ---------------------------------------------------------------------------
#
# The module hands over the corner and the size; everything inside is
# ordinary pdf4tcl. -start 2 leaves the first two positions empty, which is
# what a part-used sheet needs -- only the person holding the sheet knows
# how many are gone.

set pad [::pdf4tcllib::units::mm 4]
set sheets [::pdf4tcllib::labels::render $pdf 3474 $labels {x y w h rec} {
    set tx [expr {$x + $pad}]
    set ty [expr {$y + $pad + 8}]

    ::pdf4tcllib::fonts::setFont $pdf 9 [::pdf4tcllib::fonts::fontSans]
    $pdf text "Karton [dict get $rec carton] von [dict get $rec of]" \
            -x $tx -y $ty

    set ty [expr {$ty + 18}]
    ::pdf4tcllib::fonts::setFont $pdf 11 [::pdf4tcllib::fonts::fontSans]
    foreach key {name street city} {
        $pdf text [dict get $rec $key] -x $tx -y $ty
        set ty [expr {$ty + 13}]
    }

    ::pdf4tcllib::fonts::setFont $pdf 8 [::pdf4tcllib::fonts::fontSans]
    $pdf text [dict get $rec tour] -x $tx -y [expr {$y + $h - $pad}]
} -start 2 -frame 1]

puts "sheets written: $sheets"
pdf4tcllib::doc::finish $pdf [pdf4tcllib::doc::outfile howto-label-sheets.pdf]

puts ""
puts "Before printing a whole batch: print one sheet, hold it against a"
puts "real one. Print at actual size -- \"fit to page\" shrinks by a few"
puts "per cent and every label after the first row is off."
