# test_table.tcl -- Tests fuer pdf4tcllib::table
package require tcltest
namespace import ::tcltest::*

# ============================================================
# table::_isDictFormat -- Format-Erkennung
# ============================================================

test table-isdict-list "Listen-Format wird erkannt" -body {
    set data [list {Name Alter} {left right} {Alice 30} {Bob 25}]
    pdf4tcllib::table::_isDictFormat $data
} -result 0

test table-isdict-dict "Dict-Format wird erkannt" -body {
    set data [dict create header {Name Alter} rows {{Alice 30} {Bob 25}} aligns {left right}]
    pdf4tcllib::table::_isDictFormat $data
} -result 1

test table-isdict-dict-nocols "Dict ohne cols-Key ist OK" -body {
    set data [dict create header {Name Alter} rows {{Alice 30}} aligns {left right}]
    pdf4tcllib::table::_isDictFormat $data
} -result 1

test table-isdict-empty "Leere Liste ist kein Dict" -body {
    pdf4tcllib::table::_isDictFormat {}
} -result 0

test table-isdict-partial "Dict ohne rows-Key ist kein Dict" -body {
    set data [dict create header {Name Alter} aligns {left right}]
    # Fehlt "rows" -> kein Dict-Format
    pdf4tcllib::table::_isDictFormat $data
} -result 0

test table-isdict-noaligns "Dict ohne aligns-Key ist kein Dict" -body {
    set data [dict create header {Name Alter} rows {{Alice 30}}]
    # Fehlt "aligns" -> kein Dict-Format
    pdf4tcllib::table::_isDictFormat $data
} -result 0

# ============================================================
# table::_calcColWidths -- Spaltenbreiten
# ============================================================

test table-colw-equal "Gleich lange Spalten -> aehnliche Breiten" -body {
    set header {A B C}
    set aligns {left left left}
    set rows {{xx yy zz} {aa bb cc}}
    set widths [pdf4tcllib::table::_calcColWidths $header $aligns $rows 300 11 Helvetica Helvetica-Bold]
    # Alle 3 Spalten muessen existieren
    llength $widths
} -result 3

test table-colw-sum "Spaltenbreiten summieren sich zu maxW" -body {
    set header {Name Alter Stadt}
    set aligns {left right left}
    set rows {{Alice 30 Berlin} {Bob 25 Hamburg}}
    set widths [pdf4tcllib::table::_calcColWidths $header $aligns $rows 400 11 Helvetica Helvetica-Bold]
    set sum 0
    foreach w $widths { set sum [expr {$sum + $w}] }
    # Summe sollte <= maxW sein
    expr {$sum <= 400.1}
} -result 1

test table-colw-no-header "Ohne Header: Spaltenanzahl von erster Zeile" -body {
    set header {}
    set aligns {left left}
    set rows {{Alice 30} {Bob 25}}
    set widths [pdf4tcllib::table::_calcColWidths $header $aligns $rows 300 11 Helvetica Helvetica-Bold]
    llength $widths
} -result 2

test table-colw-wide-col "Breite Spalte bekommt mehr Platz" -body {
    set header {Kurz Sehr_langer_Spalteninhalt_hier}
    set aligns {left left}
    set rows {{x Donaudampfschifffahrtsgesellschaftskapitaen}}
    set widths [pdf4tcllib::table::_calcColWidths $header $aligns $rows 400 11 Helvetica Helvetica-Bold]
    # Zweite Spalte sollte breiter als erste sein
    expr {[lindex $widths 1] > [lindex $widths 0]}
} -result 1

cleanupTests
