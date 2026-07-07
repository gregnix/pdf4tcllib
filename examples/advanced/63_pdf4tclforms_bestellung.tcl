#!/usr/bin/env tclsh
# 63_pdf4tclforms_bestellung.tcl -- Bestellformular mit live rechnender
# Zwischensumme, MwSt (19%) und Gesamtbetrag.
#
# Erzeugt:  pdf/demo_63_bestellung.pdf
#
# Der Besteller traegt Positionsbetraege ein; das Formular zeigt in einem
# JavaScript-faehigen Viewer (Adobe Acrobat/Reader, Firefox, Chrome/Edge,
# Foxit) laufend:
#   Zwischensumme  = Summe der Betragsspalte      (AFSimple_Calculate)
#   MwSt (19%)     = Zwischensumme * 0.19          (rohes JS, -js)
#   Gesamt         = Zwischensumme * 1.19          (rohes JS, -js)
# alles deutsch als Euro formatiert (AFNumber_Format). Die -init-Werte sind
# die statische Vorschau fuer Viewer ohne JavaScript.
#
# Benoetigt pdf4tcl 0.9.4.34+ (via pdf4tclforms 0.1.2).

set scriptDir [file dirname [file normalize [info script]]]
set libDir    [file normalize [file join $scriptDir ../.. lib]]
tcl::tm::path add $libDir

package require pdf4tclforms 0.1.2
package require pdf4tcl

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set eur {number decimals 2 sep german currency " \u20AC"}
set W {30 250 60 110}

set spec [dict create \
    title "Bestellformular" \
    sections [dict create \
        besteller [dict create \
            title "Besteller" \
            fields {
                {id b_name  type text label "Name:"}
                {id b_firma type text label "Firma:"}
                {row {
                    {id b_kdnr  type text label "Kundennr.:" width 200}
                    {id b_datum type text label "Datum:"     width 170}
                }}
            }] \
        pos [dict create \
            title "Positionen" \
            table [dict create \
                headers   {Pos Artikel Menge Betrag} \
                widths    $W \
                editable  1 \
                idPrefix  f_pos \
                columns   [dict create \
                    2 {align right} \
                    3 [dict create align right format $eur]] \
                rows {
                    {1 "Aktenordner A4"    10 25}
                    {2 "Druckerpapier 500" 5  20}
                    {3 "Toner schwarz"     2  90}
                } \
                emptyRows 4] \
            sums [list \
                [dict create widths $W label "Zwischensumme:" \
                    id f_netto over {f_pos 3 7} format $eur init "135"] \
                [dict create widths $W label "MwSt (19%):" \
                    id f_mwst format $eur init "25.65" \
                    js {calculate {event.value = this.getField("f_netto").value * 0.19;}}] \
                [dict create widths $W label "Gesamt:" \
                    id f_gesamt format $eur init "160.65" \
                    js {calculate {event.value = this.getField("f_netto").value * 1.19;}}]]] \
        abschluss [dict create \
            title "Abschluss" \
            fields {
                {type radio label "Zahlungsart:" group zahlungsart init rechnung \
                    options {{rechnung "Rechnung"} {lastschrift "Lastschrift"} {vorkasse "Vorkasse"}}}
                {type buttons items {
                    {id b_submit caption "Absenden" action submit url "mailto:bestellung@example.com"}
                    {id b_reset  caption "Zuruecksetzen" action reset}
                }}
            }]]]

set ctx [pdf4tcllib::page::context a4 -margin 25 -orient true]
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage
set y [dict get $ctx top]
pdf4tclforms::renderSchema $pdf $ctx $spec -yvar y -pagebreak 1

$pdf setFont 8 Helvetica-Oblique
$pdf text "Betraege eintragen -- Zwischensumme, MwSt und Gesamt rechnen live (JS-faehiger Viewer)." \
    -x [dict get $ctx SX] -y [expr {$y + 4}]

$pdf endPage
set out [file join $outdir demo_63_bestellung.pdf]
$pdf write -file $out
$pdf destroy

puts "Bestellformular -> $out"
puts "Oeffnen:          firefox $out   (Betraege aendern, Summen rechnen live)"
