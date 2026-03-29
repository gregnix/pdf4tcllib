#!/usr/bin/env tclsh
# ============================================================================
# Demo 03: Text-Layout (Wrapping, Truncation, Alignment)
# ============================================================================
# Zeigt:
#   - Automatischer Zeilenumbruch
#   - Text abschneiden mit "..."
#   - Breitenmessung
#   - Font-Erkennung (Sans vs. Mono)
#   - Tab-Expansion
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

pdf4tcllib::page::header $pdf $ctx "pdf4tcllib Demo 03 - Text-Layout"

# ============================================================
# 1. Zeilenumbruch
# ============================================================

set y [expr {[dict get $ctx top] + 15}]
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "1. Automatischer Zeilenumbruch" -x $x -y $y
set y [expr {$y + 10}]

set longText "Dies ist ein langer Text der automatisch umgebrochen wird wenn er die maximale Breite ueberschreitet. Der Umbruch erfolgt an Wortgrenzen. pdf4tcllib::text::wrap berechnet die Breite jedes Wortes und bricht an der passenden Stelle um. Das funktioniert mit allen registrierten Fonts."

# Begrenzungsrahmen zeichnen
set wrapW 300
set boxW [expr {$wrapW + 14}]
set boxY $y

$pdf setFont 11 $fontSans
set lines [pdf4tcllib::text::wrap $longText $wrapW 11 $fontSans 0 $pdf]
set lh 16
# Boxhoehe: Padding oben (fontSize) + Zeilen + Padding unten
set boxH [expr {11 + [llength $lines] * $lh + 4}]
$pdf setStrokeColor 0.7 0.7 0.7
$pdf rectangle $x $boxY $boxW $boxH -stroke 1
$pdf setStrokeColor 0 0 0

# Erste Baseline = boxY + fontSize (Ascender bleibt im Rahmen)
set y [expr {$boxY + 11}]
foreach line $lines {
    pdf4tcllib::unicode::safeText $pdf $line -x [expr {$x + 4}] -y $y
    set y [expr {$y + $lh}]
}

$pdf setFont 9 $fontSans
$pdf setFillColor 0.5 0.5 0.5
pdf4tcllib::unicode::safeText $pdf \
    "[llength $lines] Zeilen bei ${wrapW}pt Breite" \
    -x $x -y [expr {$boxY + $boxH + 12}]
$pdf setFillColor 0 0 0

set y [expr {$boxY + $boxH + 30}]

# ============================================================
# 2. Truncation
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "2. Text abschneiden (Truncation)" -x $x -y $y
set y [expr {$y + 24}]

set original "Dieser Text ist definitiv viel zu lang fuer die vorgegebene Breite und wird abgeschnitten"
foreach maxW {400 300 200 150 100} {
    set cut [pdf4tcllib::text::truncate $original $maxW 11 $fontSans $pdf]

    # Rahmen (etwas breiter als Wrap-Breite fuer Sicherheit)
    set boxH 18
    $pdf setStrokeColor 0.85 0.85 0.85
    $pdf rectangle $x $y [expr {$maxW + 8}] $boxH -stroke 1
    $pdf setStrokeColor 0 0 0

    $pdf setFont 11 $fontSans
    pdf4tcllib::unicode::safeText $pdf $cut -x [expr {$x + 2}] -y [expr {$y + 12}]

    $pdf setFont 8 $fontSans
    $pdf setFillColor 0.5 0.5 0.5
    pdf4tcllib::unicode::safeText $pdf "${maxW}pt" -x [expr {$x + $maxW + 18}] -y [expr {$y + 10}]
    $pdf setFillColor 0 0 0

    set y [expr {$y + $boxH + 4}]
}
set y [expr {$y + 15}]

# ============================================================
# 3. Breitenmessung
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "3. Breitenmessung" -x $x -y $y
set y [expr {$y + 24}]

foreach {text font} [list \
    "Hello World"  $fontSans \
    "Hello World"  $fontSansBold \
    "Hello World"  $fontMono \
    "iiiiiiiiii"   $fontSans \
    "MMMMMMMMMM"   $fontSans \
] {
    set w [pdf4tcllib::text::width $text 12 $font $pdf]

    $pdf setFont 12 $font
    pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y

    # Mess-Linie (unter dem Descender)
    $pdf setStrokeColor 0.8 0.2 0.2
    $pdf setLineWidth 0.5
    $pdf line $x [expr {$y + 6}] [expr {$x + $w}] [expr {$y + 6}]
    $pdf setStrokeColor 0 0 0

    $pdf setFont 8 $fontSans
    $pdf setFillColor 0.5 0.5 0.5
    set shortFont [lindex [split $font ""] end]
    pdf4tcllib::unicode::safeText $pdf \
        [format "%.1f pt (%s)" $w $font] \
        -x [expr {$x + $w + 10}] -y [expr {$y + 4}]
    $pdf setFillColor 0 0 0

    set y [expr {$y + 22}]
}
set y [expr {$y + 15}]

# ============================================================
# 4. Font-Erkennung
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "4. Automatische Font-Erkennung" -x $x -y $y
set y [expr {$y + 24}]

set samples {
    "Normaler Text ohne besondere Merkmale"
    "    Vier Leerzeichen Einrueckung = Code"
    "\tTab am Anfang = Code"
    "set x [expr {\$a + \$b}]"
    "::myns::myproc aufrufen"
    "| Tabelle | Spalte |"
    "Einfacher Satz ohne Codemerkmale"
}

foreach line $samples {
    set detected [pdf4tcllib::text::detectFont $line]
    set isMono [pdf4tcllib::fonts::isMonospace $detected]
    if {$isMono} {set tag "MONO"} else {set tag "SANS"}
    set display [string map {"\t" "\\t"} $line]

    $pdf setFont 9 $fontMono
    $pdf setFillColor [expr {$isMono ? 0.0 : 0.3}] [expr {$isMono ? 0.4 : 0.3}] [expr {$isMono ? 0.0 : 0.3}]
    pdf4tcllib::unicode::safeText $pdf "\[$tag\]" -x $x -y $y -mono 1
    pdf4tcllib::unicode::safeText $pdf $display -x [expr {$x + 45}] -y $y -mono 1
    $pdf setFillColor 0 0 0
    set y [expr {$y + 14}]
}
set y [expr {$y + 15}]

# ============================================================
# 5. Tab-Expansion
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "5. Tab-Expansion" -x $x -y $y
set y [expr {$y + 24}]

set tabText "Name\tAlter\tStadt\nAlice\t30\tBerlin\nBob\t25\tMuenchen"
foreach line [split $tabText "\n"] {
    set expanded [pdf4tcllib::text::expandTabs $line 12]
    $pdf setFont 10 $fontMono
    pdf4tcllib::unicode::safeText $pdf $expanded -x [expr {$x + 10}] -y $y -mono 1
    set y [expr {$y + 14}]
}

# Footer
pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib Demo Suite" 1
$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir "demo_03_text_layout.pdf"]
$pdf write -file $outfile
$pdf destroy
catch {destroy .}
puts "Geschrieben: $outfile"
