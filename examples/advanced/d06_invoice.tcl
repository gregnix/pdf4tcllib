#!/usr/bin/env tclsh
# ============================================================================
# Demo 06: Praxis-Beispiel - Rechnung
# ============================================================================
# Zeigt:
#   - Alle Module im Zusammenspiel
#   - Professionelles Layout
#   - Kopfbereich mit Firmenlogo-Platzhalter
#   - Adressblock, Rechnungsdaten
#   - Positionstabelle mit Berechnung
#   - Fussnoten, Bankverbindung
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
set fontMono     [pdf4tcllib::fonts::fontMono]

set x [dict get $ctx left]
set y [dict get $ctx top]
set textW [dict get $ctx text_w]
set yBot [dict get $ctx bottom]
set pageW [dict get $ctx page_w]
set pageH [dict get $ctx page_h]
set margin [dict get $ctx margin]

# ============================================================
# Kopfbereich
# ============================================================

# Firmenname
$pdf setFont 22 $fontSansBold
$pdf setFillColor 0.15 0.25 0.55
pdf4tcllib::unicode::safeText $pdf "TechWidget GmbH" -x $x -y $y

# Firmendaten rechts
set rx [dict get $ctx right]
$pdf setFont 9 $fontSans
$pdf setFillColor 0.4 0.4 0.4
foreach {i line} {0 "Musterstr. 42, 12345 Musterstadt" 1 "Tel: +49 123 456789" 2 "info@techwidget.de" 3 "USt-IdNr: DE123456789"} {
    pdf4tcllib::unicode::safeText $pdf $line -x $rx -y [expr {$y + $i * 13}] -align right
}

$pdf setFillColor 0 0 0
set y [expr {$y + 60}]

# Trennlinie
pdf4tcllib::drawing::separator $pdf $x $y $textW {0.15 0.25 0.55} 2.0
set y [expr {$y + 20}]

# ============================================================
# Rechnungstitel
# ============================================================
$pdf setFont 18 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "RECHNUNG" -x $x -y $y
set y [expr {$y + 30}]

# ============================================================
# Zwei Spalten: Empfaenger links, Rechnungsdaten rechts
# ============================================================

# Empfaenger
$pdf setFont 11 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Empfaenger:" -x $x -y $y
set y [expr {$y + 18}]

$pdf setFont 11 $fontSans
foreach line {"Max Mustermann" "Beispielweg 17" "98765 Beispielstadt" "Deutschland"} {
    pdf4tcllib::unicode::safeText $pdf $line -x $x -y $y
    set y [expr {$y + 16}]
}

# Rechnungsdaten (rechte Spalte, gleiche Hoehe)
set rdY [expr {$y - 18 * 4 - 18}]
set rdX [expr {$x + 320}]

$pdf setFont 10 $fontSans
$pdf setFillColor 0.4 0.4 0.4
foreach {label value} {
    "Rechnungsnr.:" "RE-2026-00142"
    "Datum:"        "12.02.2026"
    "Faellig bis:"  "12.03.2026"
    "Kundennr.:"    "K-2024-0815"
} {
    pdf4tcllib::unicode::safeText $pdf $label -x $rdX -y $rdY
    $pdf setFont 10 $fontSansBold
    $pdf setFillColor 0 0 0
    pdf4tcllib::unicode::safeText $pdf $value -x [expr {$rdX + 90}] -y $rdY
    $pdf setFont 10 $fontSans
    $pdf setFillColor 0.4 0.4 0.4
    set rdY [expr {$rdY + 16}]
}

$pdf setFillColor 0 0 0
set y [expr {$y + 25}]

# ============================================================
# Positionstabelle
# ============================================================

set yTop $y
set pageNo 1

set invoiceTable [list \
    [list "Pos" "Beschreibung" "Menge" "Einzelpreis" "Gesamt"] \
    [list "center" "left" "right" "right" "right"] \
    [list "1" "Widget Pro - Standardlizenz" "5" "49,99" "249,95"] \
    [list "2" "Gadget Plus - Premium-Zubehoer" "3" "29,50" "88,50"] \
    [list "3" "Super-Adapter USB-C/HDMI" "10" "12,95" "129,50"] \
    [list "4" "Einrichtung und Konfiguration" "2" "85,00" "170,00"] \
    [list "5" "Support-Paket 12 Monate" "1" "299,00" "299,00"] \
]

pdf4tcllib::table::render $pdf $invoiceTable $x y $textW $yTop $yBot pageNo $pageW $pageH $margin 10 15
set y [expr {$y + 5}]

# ============================================================
# Summenblock (rechtsbuendig)
# ============================================================
set sumX [expr {$rx - 180}]

pdf4tcllib::drawing::separator $pdf $sumX $y 180 {0.5 0.5 0.5} 0.5
set y [expr {$y + 8}]

$pdf setFont 10 $fontSans
foreach {label amount} {
    "Netto:"            "936,95"
    "MwSt. 19%:"        "178,02"
} {
    pdf4tcllib::unicode::safeText $pdf $label -x $sumX -y $y
    pdf4tcllib::unicode::safeText $pdf "$amount EUR" -x $rx -y $y -align right
    set y [expr {$y + 16}]
}

set y [expr {$y + 3}]
pdf4tcllib::drawing::separator $pdf $sumX $y 180 {0.15 0.25 0.55} 1.5
set y [expr {$y + 18}]

$pdf setFont 12 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Gesamtbetrag:" -x $sumX -y $y
pdf4tcllib::unicode::safeText $pdf "1.114,97 EUR" -x $rx -y $y -align right
set y [expr {$y + 16}]

pdf4tcllib::drawing::separator $pdf $sumX $y 180 {0.15 0.25 0.55} 1.5
set y [expr {$y + 30}]

# ============================================================
# Zahlungsinformationen
# ============================================================
$pdf setFont 11 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Zahlungsinformationen" -x $x -y $y
set y [expr {$y + 20}]

# Hintergrundbox
$pdf setFillColor 0.95 0.95 0.98
pdf4tcllib::drawing::roundedRect $pdf $x $y $textW 65 8 0 1
$pdf setStrokeColor 0.7 0.7 0.8
pdf4tcllib::drawing::roundedRect $pdf $x $y $textW 65 8 1 0
$pdf setStrokeColor 0 0 0
$pdf setFillColor 0 0 0

set y [expr {$y + 12}]
$pdf setFont 10 $fontSans
foreach {label value} {
    "Bank:"   "Musterbank AG"
    "IBAN:"   "DE89 3704 0044 0532 0130 00"
    "BIC:"    "COBADEFFXXX"
    "Verwendungszweck:" "RE-2026-00142"
} {
    pdf4tcllib::unicode::safeText $pdf $label -x [expr {$x + 10}] -y $y
    $pdf setFont 10 $fontSansBold
    pdf4tcllib::unicode::safeText $pdf $value -x [expr {$x + 130}] -y $y
    $pdf setFont 10 $fontSans
    set y [expr {$y + 14}]
}

set y [expr {$y + 20}]

# ============================================================
# Fussnote
# ============================================================
$pdf setFont 8 $fontSans
$pdf setFillColor 0.5 0.5 0.5
pdf4tcllib::unicode::safeText $pdf \
    "Bitte ueberweisen Sie den Gesamtbetrag bis zum 12.03.2026 unter Angabe der Rechnungsnummer." \
    -x $x -y $y
set y [expr {$y + 12}]
pdf4tcllib::unicode::safeText $pdf \
    "Bei Fragen wenden Sie sich an buchhaltung@techwidget.de oder +49 123 456789." \
    -x $x -y $y

$pdf setFillColor 0 0 0

# Footer
pdf4tcllib::page::footer $pdf $ctx "TechWidget GmbH - Rechnung RE-2026-00142" $pageNo
$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir "demo_06_invoice.pdf"]
$pdf write -file $outfile
$pdf destroy
catch {destroy .}
puts "Geschrieben: $outfile"
