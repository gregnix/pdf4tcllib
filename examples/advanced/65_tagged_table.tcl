#!/usr/bin/env tclsh
# ============================================================================
# Demo 65: Barrierefreie Tabelle (Tagged PDF)
# ============================================================================
# Ausgabe: pdf/demo_65_tagged_table.pdf
#
# Lernziele:
#   - Tagging einschalten und was pdf4tcllib daraufhin selbst erledigt
#   - warum eine Tabelle ohne Struktur fuer einen Screenreader wertlos ist
#   - PDF/A-3a und PDF/UA-1 in einem Dokument
#
# Ohne Struktur liest ein Screenreader eine Tabelle als Folge zusammenhangloser
# Zahlen vor: "Schraube 100 4,90 Mutter 200 3,50". Mit Struktur kann er sie
# zeilen- und spaltenweise durchgehen und zu jedem Wert die Kopfzelle nennen.
#
# pdf4tcllib schaltet das nicht von sich aus ein -- die Entscheidung trifft der
# Aufrufer mit "$pdf tagged 1". Danach zeichnet table::render von selbst aus,
# was es zeichnet, und Gitterlinien und Zebrastreifen werden zu Artefakten.
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
set libDir    [file normalize [file join $scriptDir ../.. lib]]
tcl::tm::path add $libDir

package require pdf4tcl
package require pdf4tcllib

# PDF/A verlangt eingebettete Fontprogramme; die 14 Standardfonts haben keine.
# fonts::init sucht einen TrueType-Font im System und meldet ueber hasTtf, ob
# es geklappt hat.
catch {::pdf4tcllib::fonts::init -cid 1}
if {![::pdf4tcllib::fonts::hasTtf]} {
    puts stderr "Kein TrueType-Font gefunden -- Demo uebersprungen."
    exit 0
}

set pdf [pdf4tcl::new %AUTO% -paper a4 -margin 40 -orient 1 -pdfa 3a]

# Tagging AN. Ohne diese Zeile laeuft alles weiter wie bisher, nur eben ohne
# Struktur -- und -pdfa 3a wuerde dann beim Schreiben einen Fehler werfen,
# weil Konformitaetsstufe A ausgezeichnete Dokumente verlangt.
$pdf tagged 1 -lang de-DE -ua 1

$pdf metadata -title "Bestellpositionen" -author "pdf4tcllib demo"
$pdf viewerPreferences -displaydoctitle 1

$pdf startPage

$pdf setFont 16 [::pdf4tcllib::fonts::fontSansBold]
$pdf tagText H1 "Bestellpositionen" -x 0 -y 20

$pdf setFont 10 [::pdf4tcllib::fonts::fontSans]
set y 50
set pageNo 1

# Listen-Format: {header aligns row1 row2 ...}
# Die zweite Liste sind die Spaltenausrichtungen, nicht die erste Datenzeile --
# eine Stolperstelle, die man einmal erlebt haben muss.
# Jede Datenzeile braucht genau so viele Felder wie der Kopf Spalten hat.
# "Schraube M6" sind ohne Klammern ZWEI Listenelemente -- deshalb die
# geschweiften Klammern um die mehrwortigen Werte.
set data [list \
    {Artikel Menge Einzelpreis Betrag} \
    {left right right right} \
    [list {Schraube M6} 100 0,49 49,00] \
    [list {Mutter M6} 200 0,18 36,00] \
    [list Unterlegscheibe 500 0,04 20,00]]

::pdf4tcllib::table::render $pdf $data 0 y 500 20 750 pageNo 595 842 40 10 12

$pdf setFont 9 [::pdf4tcllib::fonts::fontSans]
$pdf tagBegin P
$pdf text "Alle Preise in Euro, zuzueglich Umsatzsteuer." -x 0 -y [expr {$y + 20}]
$pdf tagEnd

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir demo_65_tagged_table.pdf]
$pdf write -file $outfile
$pdf destroy

puts "Geschrieben: $outfile"
puts "Pruefen:"
puts "  verapdf -f ua1 $outfile"
puts "  verapdf -f 3a  $outfile"
