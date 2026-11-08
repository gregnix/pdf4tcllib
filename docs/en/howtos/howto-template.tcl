#!/usr/bin/env tclsh
# howto-template.tcl -- a delivery note from a block layout and a
# data dict, over several pages, with "Page n of m".
#
#   tclsh howto-template.tcl [outdir]

source [file join [file dirname [info script]] ../_bootstrap.tcl]
pdf4tcllib::doc::init [info script]
package require pdf4tcltemplate

set ttf [pdf4tcllib::doc::findTTF]
if {$ttf ne ""} { ::pdf4tcllib::fonts::init -fontdir [file dirname $ttf] }

# The layout: stored once per document type, edited in a designer.
set layout {
    paper a4  margin 20  size 10
    theme {accent {0.15 0.25 0.55} muted {0.4 0.4 0.4}}
    blocks {
        name     {x 20 y 18 w 110 size 18 bold 1 color accent}
        contact  {x 130 y 18 w 60 size 8 color muted align right list 1}
        sender   {x 20 y 45 w 85 size 7 color muted}
        address  {x 20 y 50 w 85 size 11 list 1}
        refs     {type pairs x 125 y 50 w 65 labelw 30 size 9}
        title    {x 20 y 95 w 170 size 15 bold 1 color accent
                  text "Delivery note {number}"}
        items    {type table x 20 y 108 w 170 size 9 zebra 1
                  cols {{key pos title Pos w 12 align right}
                        {key text title Item}
                        {key qty title Qty w 22 align right}
                        {key unit title Unit w 16}}}
        note     {x 20 y 0 w 170 gap 8 color muted}
        foot     {x 20 y 282 w 170 size 8 color muted page all align center
                  text "{name} -- page {page} of {pages}"}
    }
}

# The data: one document. Everything is finished text.
set rows {}
foreach {text qty} {
    "Rose, red (3 trays of 300)"          900
    "Tulip, mixed colours (2 trays of 100)" 200
    "Daffodil, yellow"                     45
} { lappend rows [dict create text $text qty $qty unit pcs] }
for {set i 4} {$i <= 40} {incr i} {
    lappend rows [dict create text "Pot, terracotta, 12 cm, item $i" qty [expr {$i * 5}] unit pcs]
}
set n 0
set rows [lmap r $rows { dict set r pos [incr n] }]

set data [dict create \
    name    "Example Nursery" \
    contact {"Garden Lane 1" "12345 Greenfield" "+49 000 000000"} \
    sender  "Example Nursery · Garden Lane 1 · 12345 Greenfield" \
    address {"Flower Shop Miller" "" "Main Street 5" "54321 Town"} \
    refs    {Number LS-2026-0007 Date 2026-11-08 Customer K12 Order {}} \
    number  LS-2026-0007 \
    items   $rows \
    note    "Please check the goods on delivery.\nThank you for your order."]

set pdf [::pdf4tcl::new %AUTO% -paper a4]
set res [::pdf4tcllib::template::render $pdf $layout $data]
set out [pdf4tcllib::doc::outfile howto-template.pdf]
$pdf write -file $out
$pdf destroy
puts "$out ([dict get $res pages] pages)"
