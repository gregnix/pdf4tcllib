#!/usr/bin/env tclsh
# Demo 45: PDF/A -- native pdf4tcl (0.9.4.23)
#
# Zeigt: -pdfa 1b, 2b, 3b direkt in pdf4tcl
# Kein Ghostscript noetig fuer Basis-PDF/A.

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir

# ---------------------------------------------------------------------------
# Schriften einbetten -- ohne das ist KEIN PDF/A gueltig.
#
# ISO 19005 verlangt jedes Fontprogramm in der Datei. Die vierzehn
# Standardschriften haben keins, also faellt ein Dokument in $fSans
# durch, egal was sonst stimmt -- veraPDF meldet Klausel 6.3.4:
#
#   "The font programs for all fonts used within a conforming file shall
#    be embedded within that file"
#
# fonts::init sucht eine TrueType-Familie und liefert deren Namen; ohne
# Fund bleibt es bei $fSans, und dann kann das Beispiel seinen
# Anspruch nicht halten. Deshalb wird das hier geprueft und gesagt.
pdf4tcllib::fonts::init
set fSans     [pdf4tcllib::fonts::fontSans]
set fSansBold [pdf4tcllib::fonts::fontSansBold]
if {!$::pdf4tcllib::fonts::hasTtf} {
    puts stderr "WARNUNG: keine TrueType-Schrift gefunden -- die erzeugten"
    puts stderr "Dateien tragen einen PDF/A-Anspruch, den sie nicht halten."
}

# ---------------------------------------------------------------------------
# Hilfsproc: Standard-Seite fuer alle Varianten
# ---------------------------------------------------------------------------
proc makePdfaPage {pdf variant} {
    # Die Schriftnamen stehen global -- fonts::init hat sie gesetzt.
    global fSans fSansBold
    $pdf startPage
    $pdf metadata \
        -title   "PDF/A Demo -- $variant" \
        -author  "pdf4tcllib Demo" \
        -subject "PDF/A Archivierungsformat" \
        -creator "pdf4tcl 0.9.4.23"

    $pdf setFont 16 $fSansBold
    $pdf text "PDF/A-$variant -- Nativ erzeugt" -x 60 -y 40

    $pdf setFont 11 $fSans
    set y 70
    foreach line [list \
        "Dieses PDF wurde mit -pdfa $variant direkt in pdf4tcl erzeugt." \
        "Kein Ghostscript erforderlich." \
        "" \
        "Voraussetzungen fuer PDF/A:" \
        "  - Vollstaendige Metadaten (title, author)" \
        "  - Eingebettete Fonts (CIDFont oder Standard)" \
        "  - XMP-Metadaten (automatisch von pdf4tcl)" \
        "  - Keine Verschluesselung" \
    ] {
        if {$line ne ""} {
            $pdf text $line -x 60 -y $y
        }
        set y [expr {$y + 16}]
    }

    # Infobox: Varianten-Beschreibung
    set desc [dict get {
        1b "PDF/A-1b: Basis-Archivierung. Keine Transparenz, kein JPEG2000."
        2b "PDF/A-2b: Moderne Archivierung. Transparenz, JPEG2000, Ebenen."
        3b "PDF/A-3b: Mit Dateianhangen. Ideal fuer E-Rechnungen (ZUGFeRD)."
    } $variant]

    $pdf setFillColor 0.93 0.97 1.0
    $pdf setStrokeColor 0.6 0.8 1.0
    $pdf setLineWidth 0.5
    $pdf rectangle 55 [expr {$y+10}] 480 28 -filled 1
    $pdf setFont 10 $fSansBold
    $pdf setFillColor 0.1 0.3 0.6
    $pdf text $desc -x 65 -y [expr {$y+26}]
    $pdf setFillColor 0 0 0
    $pdf setStrokeColor 0 0 0

    $pdf endPage
}

# ---------------------------------------------------------------------------
# 1. PDF/A-1b
# ---------------------------------------------------------------------------
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 0 -pdfa 1b]
makePdfaPage $pdf "1b"
set f1 [file join $outdir "demo_45a_pdfa1b.pdf"]
$pdf write -file $f1
$pdf destroy
puts "Geschrieben: $f1"

# ---------------------------------------------------------------------------
# 2. PDF/A-2b
# ---------------------------------------------------------------------------
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1 -pdfa 2b]
makePdfaPage $pdf "2b"
set f2 [file join $outdir "demo_45b_pdfa2b.pdf"]
$pdf write -file $f2
$pdf destroy
puts "Geschrieben: $f2"

# ---------------------------------------------------------------------------
# 3. PDF/A-3b -- mit Dateianhang (ZUGFeRD-Stil)
# ---------------------------------------------------------------------------
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1 -pdfa 3b]

# Einfachen XML-Anhang erstellen (simuliert ZUGFeRD)
set tmpXml [file join $outdir "invoice.xml"]
set fh [open $tmpXml w]
puts $fh {<?xml version="1.0" encoding="UTF-8"?>}
puts $fh {<Invoice><ID>2026-001</ID><Amount>1000.00</Amount></Invoice>}
close $fh

# Datei einbetten -- addEmbeddedFile, nicht embedFile.
#
# embedFile ist der aeltere Weg fuer einen SICHTBAREN Anhang und kennt
# weder -mimetype noch -description; sein switch verschluckt unbekannte
# Optionen stillschweigend. Das Ergebnis trug "/Subtype /XML" statt des
# MIME-Typs und fiel bei veraPDF durch, Klausel 6.8:
#
#   "The MIME type of an embedded file ... shall be specified using the
#    Subtype key of the file specification dictionary"
#
# addEmbeddedFile schreibt den Anhang in den Namensbaum des Katalogs,
# was PDF/A-3 fuer Rechnungsanhaenge verlangt.
$pdf addEmbeddedFile $tmpXml \
    -description "Rechnungsdaten (ZUGFeRD-Stil)" \
    -mimetype "application/xml" \
    -afrelationship Alternative

makePdfaPage $pdf "3b"

$pdf startPage
$pdf setFont 14 $fSansBold
$pdf text "PDF/A-3b: Eingebettete Datei" -x 60 -y 40
$pdf setFont 10 $fSans
$pdf text "Enthalt: invoice.xml (simulierter ZUGFeRD-Anhang)" -x 60 -y 62
$pdf text "Sichtbar im Viewer unter: Anhaenge / Attachments" -x 60 -y 78
$pdf setFont 9 $fSans
$pdf setFillColor 0.5 0.5 0.5
$pdf text "pdf4tcl -pdfa 3b + embedFile" -x 60 -y 100
$pdf setFillColor 0 0 0
$pdf endPage

set f3 [file join $outdir "demo_45c_pdfa3b.pdf"]
$pdf write -file $f3
$pdf destroy
file delete $tmpXml
puts "Geschrieben: $f3"

puts "\nAlle PDF/A-Varianten erzeugt:"
puts "  1b: [file size $f1] Bytes"
puts "  2b: [file size $f2] Bytes"
puts "  3b: [file size $f3] Bytes"
