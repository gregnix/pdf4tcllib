#!/usr/bin/env tclsh
# ============================================================================
# Demo 07: Mehrseitiges Dokument mit Seitenumbruch
# ============================================================================
# Zeigt:
#   - Automatischer Seitenumbruch bei Tabellen
#   - Konsistente Header/Footer ueber Seiten
#   - Seitennummern
#   - Langer Fliesstext mit Wrapping
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

set fontSans     [pdf4tcllib::fonts::fontSans]
set fontSansBold [pdf4tcllib::fonts::fontSansBold]

set x [dict get $ctx left]
set textW [dict get $ctx text_w]
set yTop  [dict get $ctx top]
set yBot  [dict get $ctx bottom]
set pageW [dict get $ctx page_w]
set pageH [dict get $ctx page_h]
set margin [dict get $ctx margin]
set pageNo 1
set lh [pdf4tcllib::page::lineheight 11]

# --- Hilfsproc: Neue Seite ---
proc newPage {} {
    upvar pdf pdf ctx ctx pageNo pageNo yTop yTop y y
    set fontSans [pdf4tcllib::fonts::fontSans]
    pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib Demo 07 - Mehrseitiges Dokument" $pageNo
    $pdf endPage
    incr pageNo
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "pdf4tcllib Demo 07 (Seite $pageNo)"
    set y $yTop
}

# --- Hilfsproc: Text mit automatischem Umbruch ---
proc writeText {text} {
    upvar pdf pdf x x y y textW textW lh lh yBot yBot fontSans fontSans
    set lines [pdf4tcllib::text::wrap $text $textW 11 $fontSans 0 $pdf]
    $pdf setFont 11 $fontSans
    foreach line $lines {
        if {$y > [expr {$yBot - 20}]} { newPage }
        pdf4tcllib::unicode::safeText $pdf $line -x $x -y $y
        set y [expr {$y + $lh}]
    }
}

# ============================================================
# Seite 1: Einleitung
# ============================================================
$pdf startPage
pdf4tcllib::page::header $pdf $ctx "pdf4tcllib Demo 07 (Seite $pageNo)"
set y $yTop

set y [expr {[dict get $ctx top] + 15}]
$pdf setFont 18 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Bericht: PDF-Erzeugung mit Tcl" -x $x -y $y
set y [expr {$y + 35}]

$pdf setFont 12 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "1. Einleitung" -x $x -y $y
set y [expr {$y + 22}]

writeText "Dieses Dokument demonstriert die Faehigkeiten von pdf4tcllib bei der Erzeugung mehrseitiger Dokumente. Die Bibliothek baut auf pdf4tcl auf und erweitert es um automatisches Text-Wrapping, TTF-Font-Support mit Unicode-Absicherung, Tabellen-Rendering mit Seitenumbruch und Seitenmoeblierung."

set y [expr {$y + 10}]
writeText "pdf4tcllib ist modular aufgebaut. Jedes Modul kann einzeln geladen werden (z.B. nur fonts und unicode fuer minmale Integration) oder als Gesamtpaket ueber package require pdf4tcllib."

set y [expr {$y + 15}]

$pdf setFont 12 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "2. Moduluebersicht" -x $x -y $y
set y [expr {$y + 22}]

writeText "Die Bibliothek besteht aus acht Modulen:"

set y [expr {$y + 5}]
foreach {modul desc} {
    "fonts"   "TTF-Font-Management mit plattformuebergreifender Suche"
    "unicode" "Unicode-Absicherung gegen pdf4tcl-Crashes"
    "text"    "Zeilenumbruch, Breitenmessung, Truncation"
    "table"   "Tabellen mit Header, Zebra-Streifen, Seitenumbruch"
    "page"    "Seitenkontext, Header, Footer, Seitennummern"
    "drawing" "Formen, Farbverlaeufe, Text-Transformationen"
    "units"   "Masseinheiten: mm/cm/Zoll zu Points"
    "image"   "Tk-Bilder in PDF einfuegen (optional)"
} {
    $pdf setFont 11 $fontSansBold
    pdf4tcllib::unicode::safeText $pdf "  $modul" -x $x -y $y
    $pdf setFont 11 $fontSans
    pdf4tcllib::unicode::safeText $pdf "- $desc" -x [expr {$x + 80}] -y $y
    set y [expr {$y + $lh}]
    if {$y > [expr {$yBot - 20}]} { newPage }
}

set y [expr {$y + 15}]

$pdf setFont 12 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "3. Beispieldaten (Grosse Tabelle)" -x $x -y $y
set y [expr {$y + 22}]

writeText "Die folgende Tabelle enthaelt 30 Zeilen und erzwingt einen Seitenumbruch:"
set y [expr {$y + 10}]

# Grosse Tabelle generieren
set bigTable [list \
    [list "Nr" "Timestamp" "Messwert" "Status" "Kommentar"] \
    [list "right" "left" "right" "center" "left"] \
]

for {set i 1} {$i <= 30} {incr i} {
    set ts [format "2026-02-12 %02d:%02d:%02d" [expr {8 + $i / 4}] [expr {($i * 7) % 60}] [expr {($i * 13) % 60}]]
    set val [format "%.2f" [expr {20.0 + ($i * 3.7) - int($i / 5) * 2.1}]]
    set status [lindex {"OK" "OK" "WARN" "OK" "OK" "ERR" "OK" "OK" "OK" "OK"} [expr {$i % 10}]]
    set comment [lindex {"Normal" "Normal" "Grenzwert" "Stabil" "Normal" "Ausreisser" "Normal" "Normal" "Reset" "Kalibriert"} [expr {$i % 10}]]
    lappend bigTable [list $i $ts $val $status $comment]
}

pdf4tcllib::table::render $pdf $bigTable $x y $textW $yTop $yBot pageNo $pageW $pageH $margin 10 14
set y [expr {$y + 15}]

# Abschlusstext
if {$y > [expr {$yBot - 80}]} { newPage }

$pdf setFont 12 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "4. Zusammenfassung" -x $x -y $y
set y [expr {$y + 22}]

writeText "Dieses Dokument wurde vollstaendig mit pdf4tcllib erzeugt. Alle Seitenumbrueche, Header, Footer und Seitennummern werden automatisch verwaltet. Die Tabelle hat den Seitenumbruch nahtlos ueberbrueckt."

# Letzte Seite abschliessen
pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib Demo 07 - Mehrseitiges Dokument" $pageNo
$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir "demo_07_multipage.pdf"]
$pdf write -file $outfile
$pdf destroy
catch {destroy .}
puts "Geschrieben: $outfile ($pageNo Seiten)"
