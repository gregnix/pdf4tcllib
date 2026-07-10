#!/usr/bin/env tclsh
# ============================================================================
# Demo 04: Tabellen  (ueberarbeitet -> ::pdf4tcllib::table::draw)
# ============================================================================
# Zeigt den datengetriebenen, Tk-freien Renderer table::draw:
#   - Kopfzeile, automatische Spaltenbreiten (-width auto)
#   - Spaltenausrichtung (left/center/right)
#   - Zebra-Streifen (-zebra)
#   - Footer-Zeile (-footer)
#   - Zell-Styling per Index (-cellstyles)
#   - Unicode in Zellen (Symbole, feste Breite)
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.4
package require pdf4tcl

pdf4tcllib::fonts::init -cid 1
# Tk-Fenster verstecken falls wish verwendet wird
catch {wm withdraw .}

set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

set fontSansBold [pdf4tcllib::fonts::fontSansBold]
set x     [dict get $ctx left]
set textW [dict get $ctx text_w]

pdf4tcllib::page::header $pdf $ctx "pdf4tcllib Demo 04 - Tabellen (table::draw)"

# Kleiner Helfer: cols-Liste aus Headern + Ausrichtungen bauen.
proc mkcols {headers aligns} {
    set cols {}
    foreach h $headers a $aligns {
        lappend cols [list -header $h -align $a -width auto]
    }
    return $cols
}

set y [expr {[dict get $ctx top] + 15}]

# ============================================================
# 1. Produktliste -- Zebra + Footer (Summe Bestand)
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "1. Produktliste" -x $x -y $y
set y [expr {$y + 14}]

set cols [mkcols {Produkt Kategorie Preis Bestand} {left left right right}]
set data {
    {"Widget Pro"    Elektronik "49,99"  142}
    {"Gadget Plus"   Zubeh\u00f6r   "29,50"  87}
    {"Super-Adapter" Kabel      "12,95"  531}
    {"Mega-Hub"      Netzwerk   "89,00"  23}
    {"Mini-Stick"    Speicher   "19,99"  298}
}
set y [pdf4tcllib::table::draw $pdf $x $y $cols $data \
    -ctx $ctx -zebra 1 -fontsize 11 \
    -footer {"Summe" "" "" "1081"}]
set y [expr {$y + 20}]

# ============================================================
# 2. Aufgabenliste -- zentrierte Statusspalte, Unicode-Symbole,
#    rote Zelle fuer den abgebrochenen Task
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "2. Aufgabenliste mit Symbolen" -x $x -y $y
set y [expr {$y + 14}]

set cols [mkcols {Status Aufgabe Priorit\u00e4t Zust\u00e4ndig} {center left center left}]
set data [list \
    [list "\u2713" "Datenbank-Schema erstellen"    "Hoch"    "Alice"] \
    [list "\u2713" "API-Endpunkte definieren"       "Hoch"    "Bob"] \
    [list "\u2717" "Unit-Tests schreiben"           "Mittel"  "Carol"] \
    [list "\u2610" "Dokumentation aktualisieren"    "Niedrig" "Dave"] \
    [list "\u2610" "Performance-Tests"              "Mittel"  "Eve"] \
]
set y [pdf4tcllib::table::draw $pdf $x $y $cols $data \
    -ctx $ctx -zebra 1 -fontsize 11 \
    -cellstyles {2,0 {-fg {0.80 0.0 0.0}}}]
set y [expr {$y + 20}]

# ============================================================
# 3. Kompakte Tabelle -- nur halbe Breite
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "3. Kompakte Tabelle" -x $x -y $y
set y [expr {$y + 14}]

set cols [mkcols {Land Hauptstadt} {left left}]
set data {
    {Deutschland Berlin}
    {Frankreich  Paris}
    {Spanien     Madrid}
    {Italien     Rom}
    {Portugal    Lissabon}
}
set y [pdf4tcllib::table::draw $pdf $x $y $cols $data \
    -ctx $ctx -zebra 1 -fontsize 11 -maxwidth [expr {$textW * 0.5}]]
set y [expr {$y + 20}]

# ============================================================
# 4. Zahlentabelle -- rechtsbuendig, Footer mit Summen
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "4. Zahlentabelle" -x $x -y $y
set y [expr {$y + 14}]

set cols [mkcols {Monat Umsatz Kosten Gewinn} {left right right right}]
set data {
    {Januar  "125.430" "98.200"  "27.230"}
    {Februar "118.650" "95.100"  "23.550"}
    {M\u00e4rz    "142.800" "101.300" "41.500"}
    {April   "131.200" "97.800"  "33.400"}
    {Mai     "155.900" "103.500" "52.400"}
    {Juni    "148.300" "100.200" "48.100"}
}
set y [pdf4tcllib::table::draw $pdf $x $y $cols $data \
    -ctx $ctx -zebra 1 -fontsize 11 \
    -footer {"Summe" "822.280" "596.100" "226.180"} -footerbg {0.85 0.90 1.0}]

# Footer der Seite
pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib Demo Suite" 1
$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir "demo_04_tables.pdf"]
$pdf write -file $outfile
$pdf destroy
catch {destroy .}
puts "Geschrieben: $outfile"
