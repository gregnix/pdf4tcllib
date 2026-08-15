#!/usr/bin/env tclsh
# howto-shipping-labels.tcl -- parcel labels on A6, four to a sheet:
# sender, recipient, carton count, tour, and room for a barcode.
#
#   tclsh howto-shipping-labels.tcl [outdir]

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]
package require pdf4tcllabels

set ttf [pdf4tcllib::doc::findTTF]
if {$ttf ne ""} { ::pdf4tcllib::fonts::init -fontdir [file dirname $ttf] }
proc F {pdf size {style ""}} {
    if {$style eq "bold"} {
        ::pdf4tcllib::fonts::setFont $pdf $size [::pdf4tcllib::fonts::fontSansBold]
    } else {
        ::pdf4tcllib::fonts::setFont $pdf $size [::pdf4tcllib::fonts::fontSans]
    }
}

set sender {Muster Logistik GmbH \u00b7 Lagerstr. 1 \u00b7 44444 Versandstadt}

set consignments {
    {no 4711 name "Manfred Muster"  street "Musterstr. 4"
     city "55555 Muster"           tour "Tour 4"  day "Mo 24.08.26" cartons 4}
    {no 4712 name "Erika Beispiel" street "Beispielweg 12"
     city "12345 Beispielstadt"    tour "Tour 4"  day "Mo 24.08.26" cartons 2}
    {no 4713 name "Firma Test GmbH" street "Testallee 7a"
     city "98765 Testheim"         tour "Tour 7"  day "Di 25.08.26" cartons 1}
}

# ---------------------------------------------------------------------------
# Sort before expanding, not after
# ---------------------------------------------------------------------------
#
# Labels come off the printer in one stack and get stuck on parcels in that
# order. Sorting by tour means the driver's parcels arrive together; sorting
# after the expansion would scatter the cartons of one consignment.

set consignments [lsort -command {apply {{a b} {
    set c [string compare [dict get $a tour] [dict get $b tour]]
    if {$c != 0} { return $c }
    return [string compare [dict get $a city] [dict get $b city]]
}}} $consignments]

set labels {}
foreach c $consignments {
    set n [dict get $c cartons]
    for {set i 1} {$i <= $n} {incr i} {
        dict set c carton $i
        dict set c of     $n
        lappend labels $c
    }
}

set ::pdf4tcl::warnings {}
set pdf [::pdf4tcl::new %AUTO% -compress 0]
$pdf tagged 1 -lang de-DE

set mm ::pdf4tcllib::units::mm
set sheets [::pdf4tcllib::labels::render $pdf 3427 $labels {x y w h rec} {
    set pad [$mm 6]
    set l [expr {$x + $pad}]
    set r [expr {$x + $w - $pad}]
    set t [expr {$y + $pad}]

    # Sender, small, at the top -- it is the least important thing on the
    # label and the first thing people put in the biggest type.
    F $pdf 7
    $pdf text $sender -x $l -y [expr {$t + 6}]

    ::pdf4tcllib::tag::artifact $pdf -type Layout
    $pdf setStrokeColor 0.6 0.6 0.6
    $pdf setLineWidth 0.4
    $pdf line $l [expr {$t + 12}] $r [expr {$t + 12}]
    $pdf setStrokeColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf

    # Recipient, as large as the space allows. This is what a person reads
    # from a metre away while holding a parcel.
    set ty [expr {$t + 34}]
    F $pdf 14 bold
    $pdf text [dict get $rec name] -x $l -y $ty
    F $pdf 12
    foreach key {street city} {
        set ty [expr {$ty + 16}]
        $pdf text [dict get $rec $key] -x $l -y $ty
    }

    # Carton count, big enough to check without picking the parcel up.
    F $pdf 16 bold
    $pdf text "[dict get $rec carton] / [dict get $rec of]" \
            -x $r -y [expr {$t + 34}] -align right

    # Tour and day at the foot, plus the consignment number.
    F $pdf 10 bold
    $pdf text "[dict get $rec tour]  [dict get $rec day]" \
            -x $l -y [expr {$y + $h - $pad}]
    F $pdf 8
    $pdf text "Sendung [dict get $rec no]" \
            -x $r -y [expr {$y + $h - $pad}] -align right

    # Where a barcode would go. tzint's "bits" mode gives a matrix of 0/1
    # rows; drawing those as rectangles keeps it vector, which beats an
    # embedded raster at any print resolution. Leave the quiet zone --
    # a code without white space either side does not scan.
    ::pdf4tcllib::tag::artifact $pdf -type Layout
    $pdf setFillColor 0.93 0.93 0.93
    $pdf rectangle $l [expr {$y + $h - $pad - 40}] [expr {$r - $l}] 22 -filled 1
    $pdf setFillColor 0.5 0.5 0.5
    F $pdf 7
    $pdf text "barcode area -- see howto text" \
            -x [expr {$l + 4}] -y [expr {$y + $h - $pad - 26}]
    $pdf setFillColor 0 0 0
    ::pdf4tcllib::tag::artifactEnd $pdf
} -frame 1]

puts "[llength $consignments] consignments -> [llength $labels] labels\
        on $sheets sheet(s)"
pdf4tcllib::doc::finish $pdf \
        [pdf4tcllib::doc::outfile howto-shipping-labels.pdf]
