#!/usr/bin/env tclsh
# ============================================================================
# Demo 01: Einfache Seite mit TTF-Fonts und Unicode
# ============================================================================
# Zeigt:
#   - pdf4tcllib initialisieren
#   - TTF-Fonts automatisch finden und laden
#   - Unicode-Zeichen sicher ausgeben
#   - Unterschied TTF vs. Helvetica
#
# WICHTIG: \u-Escapes funktionieren nur in "double quotes",
#          NICHT in {braces}!
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
set libDir [file normalize [file join $scriptDir ../.. lib]]

tcl::tm::path add $libDir
package require pdf4tcllib 0.1

# --- Fonts initialisieren ---
pdf4tcllib::fonts::init

set ctx [pdf4tcllib::page::context a4 -margin 25]

# --- PDF erzeugen ---
package require pdf4tcl
# Tk-Fenster verstecken falls wish verwendet wird
catch {wm withdraw .}
set pdf [pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

set fontSans     [pdf4tcllib::fonts::fontSans]
set fontSansBold [pdf4tcllib::fonts::fontSansBold]
set fontMono     [pdf4tcllib::fonts::fontMono]
set y 50

# Titel
$pdf setFont 20 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "pdf4tcllib Demo 01 - Fonts & Unicode" -x 50 -y $y
set y [expr {$y + 40}]

# Font-Status
$pdf setFont 11 $fontSans
if {[pdf4tcllib::fonts::hasTtf]} {
    set status "Font-Modus: TTF ($fontSans)"
} else {
    set status "Font-Modus: Helvetica (Fallback)"
}
pdf4tcllib::unicode::safeText $pdf $status -x 50 -y $y
set y [expr {$y + 30}]

# ============================================================
# Umlaute und Akzente
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Umlaute und Akzente" -x 50 -y $y
set y [expr {$y + 22}]

$pdf setFont 11 $fontSans

# \u-Escapes muessen in "..." stehen, nicht in {...}
set samples [list \
    "Deutsch:" "\u00C4rger mit \u00DCbergr\u00F6\u00DFen - \u00E4\u00F6\u00FC \u00C4\u00D6\u00DC \u00DF" \
    "Franz\u00F6sisch:" "Cr\u00E8me br\u00FBl\u00E9e, gar\u00E7on, fa\u00E7ade, no\u00EBl" \
    "Spanisch:" "Espa\u00F1ol, ni\u00F1o, ma\u00F1ana" \
    "Nordisch:" "\u00C6r\u00F8, Malm\u00F6, \u00C5lborg" \
]
foreach {label text} $samples {
    pdf4tcllib::unicode::safeText $pdf "$label $text" -x 50 -y $y
    set y [expr {$y + 18}]
}
set y [expr {$y + 10}]

# ============================================================
# Sonderzeichen (Latin-1)
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Sonderzeichen (Latin-1 Bereich)" -x 50 -y $y
set y [expr {$y + 22}]

$pdf setFont 11 $fontSans
set samples [list \
    "Copyright:" "\u00A9 2026 Anthropic  \u00AE Registered  \u00B0 Grad" \
    "W\u00E4hrung:" "\u00A3 Pfund  \u00A5 Yen  \u00A7 Paragraph" \
    "Mathematik:" "\u00B1 Plus-Minus  \u00D7 Mal  \u00F7 Geteilt  \u00BD Halb" \
    "Zeichen:" "\u00AB Guillemets \u00BB  \u00BF Umgekehrtes Fragezeichen" \
]
foreach {label text} $samples {
    pdf4tcllib::unicode::safeText $pdf "$label $text" -x 50 -y $y
    set y [expr {$y + 18}]
}
set y [expr {$y + 10}]

# ============================================================
# Erweiterte Symbole (TTF-Subset)
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Erweiterte Symbole (TTF-Subset)" -x 50 -y $y
set y [expr {$y + 22}]

$pdf setFont 11 $fontSans
set samples [list \
    "Pfeile:" "\u2190 \u2191 \u2192 \u2193  (links, hoch, rechts, runter)" \
    "H\u00E4kchen:" "\u2713 erledigt  \u2717 offen  \u2611 aktiviert  \u2610 leer" \
    "Formen:" "\u25A0 \u25A1 \u25CF \u25CB \u2605 \u2606  (Quadrat, Kreis, Stern)" \
    "Mathe:" "\u2264 kleiner-gleich  \u2265 gr\u00F6\u00DFer-gleich" \
    "Typografie:" "\u2013 Halbgeviert  \u2014 Geviert  \u2026 Auslassung  \u2022 Bullet" \
    "W\u00E4hrung:" "\u20AC Euro" \
]
foreach {label text} $samples {
    pdf4tcllib::unicode::safeText $pdf "$label $text" -x 50 -y $y
    set y [expr {$y + 18}]
}
set y [expr {$y + 10}]

# ============================================================
# Box-Drawing (Mono-Modus: ASCII-Ersetzung)
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Box-Drawing (Courier)" -x 50 -y $y
set y [expr {$y + 22}]

$pdf setFont 11 $fontMono
set boxLines [list \
    "\u250C\u2500\u2500\u2500\u252C\u2500\u2500\u2500\u2510" \
    "\u2502 A \u2502 B \u2502" \
    "\u251C\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2524" \
    "\u2502 C \u2502 D \u2502" \
    "\u2514\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2518" \
]
foreach line $boxLines {
    pdf4tcllib::unicode::safeText $pdf $line -x 70 -y $y -mono 1
    set y [expr {$y + 16}]
}

$pdf setFont 9 $fontSans
$pdf setFillColor 0.5 0.5 0.5
pdf4tcllib::unicode::safeText $pdf "(Unicode-Symbole werden im Mono-Modus durch ASCII ersetzt)" -x 70 -y $y
$pdf setFillColor 0 0 0
set y [expr {$y + 20}]

# ============================================================
# Code-Beispiel (Courier)
# ============================================================
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Code-Beispiel (Courier)" -x 50 -y $y
set y [expr {$y + 22}]

$pdf setFont 10 $fontMono
set codeLines [list \
    "proc greet \{name\} \{" \
    "    set msg \"Hallo \$name\"" \
    "    puts \$msg" \
    "    return \$msg" \
    "\}" \
]
foreach line $codeLines {
    pdf4tcllib::unicode::safeText $pdf $line -x 70 -y $y -mono 1
    set y [expr {$y + 14}]
}

# ============================================================
# Fusszeile
# ============================================================
pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib Demo Suite" 1

$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir "demo_01_fonts_unicode.pdf"]
$pdf write -file $outfile
$pdf destroy
catch {destroy .}
puts "Geschrieben: $outfile"
