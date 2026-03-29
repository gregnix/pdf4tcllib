#!/usr/bin/env tclsh
# ============================================================================
# Demo 04: Tabellen
# ============================================================================
# Zeigt:
#   - Einfache Tabelle mit Header
#   - Automatische Spaltenbreiten
#   - Spaltenausrichtung (links, zentriert, rechts)
#   - Zebra-Streifen
#   - Unicode in Tabellenzellen
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1

pdf4tcllib::fonts::init
package require pdf4tcl
# Tk-Fenster verstecken falls wish verwendet wird
catch {wm withdraw .}

set ctx [pdf4tcllib::page::context a4 -margin 25]
set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

set fontSans     [pdf4tcllib::fonts::fontSans]
set fontSansBold [pdf4tcllib::fonts::fontSansBold]

set x [dict get $ctx left]
set y [dict get $ctx top]
set textW [dict get $ctx text_w]
set yTop [dict get $ctx top]
set yBot [dict get $ctx bottom]
set pageW [dict get $ctx page_w]
set pageH [dict get $ctx page_h]
set margin [dict get $ctx margin]
set pageNo 1

pdf4tcllib::page::header $pdf $ctx "pdf4tcllib Demo 04 - Tabellen"

# ============================================================
# 1. Produktliste
# ============================================================
#
set y [expr {[dict get $ctx top] + 15}]
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "1. Produktliste" -x $x -y $y
set y [expr {$y + 14}]

set tableData {
    {Produkt           Kategorie    Preis     Bestand}
    {left              left         right     right}
    {"Widget Pro"      Elektronik   "49,99"   142}
    {"Gadget Plus"     Zubehoer     "29,50"   87}
    {"Super-Adapter"   Kabel        "12,95"   531}
    {"Mega-Hub"        Netzwerk     "89,00"   23}
    {"Mini-Stick"      Speicher     "19,99"   298}
}

pdf4tcllib::table::render $pdf $tableData $x y $textW $yTop $yBot pageNo $pageW $pageH $margin 11 16
set y [expr {$y + 20}]

# ============================================================
# 2. Aufgabenliste mit Symbolen
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "2. Aufgabenliste mit Symbolen" -x $x -y $y
set y [expr {$y + 14}]

set taskTable [list \
    [list "Status" "Aufgabe" "Prioritaet" "Zustaendig"] \
    [list "center" "left" "center" "left"] \
    [list "\u2713" "Datenbank-Schema erstellen" "Hoch" "Alice"] \
    [list "\u2713" "API-Endpunkte definieren" "Hoch" "Bob"] \
    [list "\u2717" "Unit-Tests schreiben" "Mittel" "Carol"] \
    [list "\u2610" "Dokumentation aktualisieren" "Niedrig" "Dave"] \
    [list "\u2610" "Performance-Tests" "Mittel" "Eve"] \
]

pdf4tcllib::table::render $pdf $taskTable $x y $textW $yTop $yBot pageNo $pageW $pageH $margin 11 16
set y [expr {$y + 20}]

# ============================================================
# 3. Schmale Tabelle (weniger Spalten)
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "3. Kompakte Tabelle" -x $x -y $y
set y [expr {$y + 14}]

set smallTable {
    {Land         Hauptstadt}
    {left         left}
    {Deutschland  Berlin}
    {Frankreich   Paris}
    {Spanien      Madrid}
    {Italien      Rom}
    {Portugal     Lissabon}
}

# Nur halbe Breite nutzen
pdf4tcllib::table::render $pdf $smallTable $x y [expr {$textW * 0.5}] $yTop $yBot pageNo $pageW $pageH $margin 11 16
set y [expr {$y + 20}]

# ============================================================
# 4. Zahlentabelle (rechtsbündig)
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "4. Zahlentabelle" -x $x -y $y
set y [expr {$y + 14}]

set numTable {
    {Monat     Umsatz       Kosten       Gewinn}
    {left      right        right        right}
    {Januar    "125.430"    "98.200"     "27.230"}
    {Februar   "118.650"    "95.100"     "23.550"}
    {Maerz     "142.800"    "101.300"    "41.500"}
    {April     "131.200"    "97.800"     "33.400"}
    {Mai       "155.900"    "103.500"    "52.400"}
    {Juni      "148.300"    "100.200"    "48.100"}
}

pdf4tcllib::table::render $pdf $numTable $x y $textW $yTop $yBot pageNo $pageW $pageH $margin 11 16

# Footer
pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib Demo Suite" $pageNo
$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir "demo_04_tables.pdf"]
$pdf write -file $outfile
$pdf destroy
catch {destroy .}
puts "Geschrieben: $outfile"
