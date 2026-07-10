#!/usr/bin/env wish
# examples/advanced/64_table_draw.tcl
#
# Zwei Tabellen-Wege ab pdf4tcllib 0.4 / pdf4tcltable 0.3:
#   Seite 1: ::pdf4tcllib::table::draw   (datengetrieben, Tk-frei)
#   Seite 2: ::pdf4tcltable::render       (tablelist-Widget -> Adapter -> draw)
#
# Aufruf:  wish 64_table_draw.tcl ?ausgabe.pdf?
# Ausgabe-PDF ist Build-Output (.gitignore).

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]

package require pdf4tcl
package require pdf4tcllib
package require Tk
package require tablelist_tile
package require pdf4tcltable

set out [expr {$argc ? [lindex $argv 0] : "pdf/table-demo.pdf"}]

# Volles Unicode (Euro etc.); ohne TTF faellt es auf WinAnsi zurueck.
catch {::pdf4tcllib::fonts::init -cid 1}

set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]
set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]

# ---------------------------------------------------------------------------
# Seite 1 -- table::draw: reine Daten, Styling, Footer, Baum-Einrueckung
# ---------------------------------------------------------------------------
$pdf startPage
set x [dict get $ctx left]
set y [dict get $ctx top]
$pdf setFont 15 Helvetica-Bold
::pdf4tcllib::unicode::safeText $pdf "table::draw \u2013 datengetrieben" -x $x -y $y
set y [expr {$y + 26}]

set cols {
    {-header "Kategorie / Artikel" -width auto}
    {-header "Nr."                 -width 90}
    {-header "Preis \u20ac"         -width 80 -align right}
}
# Baum: Kategorien (bold, depth 0) + Artikel (eingerueckt)
set data {
    {"Elektronik"  ""      ""}
    {"Laptop 15"   "E-001" "899,00"}
    {"Laptop 13"   "E-002" "749,00"}
    {"B\u00fcro"    ""      ""}
    {"Stuhl"       "B-001" "129,00"}
    {"Tisch"       "B-002" "249,00"}
}
set rowstyles  {0 {-font bold}  3 {-font bold}}
set rowindent  {1 14  2 14  4 14  5 14}
set cellstyles {2,2 {-fg {0.80 0 0} -font bold}}

set y [pdf4tcllib::table::draw $pdf $x $y $cols $data \
    -ctx        $ctx \
    -zebra      1 \
    -rowstyles  $rowstyles \
    -rowindent  $rowindent \
    -cellstyles $cellstyles \
    -footer     {"Summe" "" "2.026,00"} -footerbg {0.85 0.90 1.0} \
    -yvar       y]
$pdf endPage

# ---------------------------------------------------------------------------
# Seite 2 -- pdf4tcltable-Adapter: dasselbe aus einem tablelist-Widget
# ---------------------------------------------------------------------------
tablelist::tablelist .t \
    -columns {24 "Kategorie / Artikel" left 10 "Nr." left 10 "Preis \u20ac" right} \
    -stripebackground "#eef4ff"
set e1 [.t insertchild root end {"Elektronik" "" ""}]
.t rowconfigure $e1 -font {Helvetica 9 bold}
.t insertchild $e1 end {"Laptop 15" "E-001" "899,00 \u20ac"}
.t insertchild $e1 end {"Laptop 13" "E-002" "749,00 \u20ac"}
set e2 [.t insertchild root end {"B\u00fcro" "" ""}]
.t rowconfigure $e2 -font {Helvetica 9 bold}
.t insertchild $e2 end {"Stuhl" "B-001" "129,00 \u20ac"}
.t insertchild $e2 end {"Tisch" "B-002" "249,00 \u20ac"}
update idletasks
.t cellconfigure 2,2 -foreground "#cc0000"      ;# eine Zelle rot
update idletasks

$pdf startPage
set x [dict get $ctx left]
set y [dict get $ctx top]
$pdf setFont 15 Helvetica-Bold
::pdf4tcllib::unicode::safeText $pdf "pdf4tcltable \u2013 aus tablelist-Widget" -x $x -y $y
set y [expr {$y + 26}]

# Alias ::pdf4tcltable::render (== ::pdf4tcllib::tablelist::render)
::pdf4tcltable::render $pdf .t $x $y \
    -maxwidth [dict get $ctx text_w] \
    -ctx      $ctx \
    -tree     1 \
    -footer   {"Summe" "" "2.026,00 \u20ac"} \
    -yvar     y
$pdf endPage

$pdf write -file $out
$pdf destroy
puts "geschrieben: $out"
exit 0
