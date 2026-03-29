#!/usr/bin/env tclsh
# ============================================================================
# Demo 02: Seitenlayout mit PageContext
# ============================================================================
# Zeigt:
#   - PageContext erzeugen (A4, Margins)
#   - Header und Footer
#   - Seitennummern
#   - Debug-Raster
#   - Masseinheiten-Konvertierung
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

# ============================================================
# Seite 1: Context-Werte und Raster
# ============================================================
$pdf startPage

# Debug-Raster im Hintergrund
pdf4tcllib::page::grid $pdf $ctx 50

# Header
pdf4tcllib::page::header $pdf $ctx "pdf4tcllib Demo 02 - Seitenlayout"

set y [dict get $ctx top]
set x [dict get $ctx left]
set textW [dict get $ctx text_w]

$pdf setFont 16 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "PageContext-Werte" -x $x -y $y
set y [expr {$y + 30}]

# Context-Dictionary anzeigen
$pdf setFont 10 [pdf4tcllib::fonts::fontMono]
foreach key {paper page_w page_h margin margin_mm left right top bottom text_w text_h} {
    set val [dict get $ctx $key]
    set line [format "%-12s = %s" $key $val]
    pdf4tcllib::unicode::safeText $pdf $line -x [expr {$x + 20}] -y $y -mono 1
    set y [expr {$y + 16}]
}

set y [expr {$y + 20}]

# Einheiten-Demo
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Masseinheiten" -x $x -y $y
set y [expr {$y + 24}]

$pdf setFont 11 $fontSans
foreach {label expr result} [list \
    "25 mm ="     [pdf4tcllib::units::mm 25]    "pt" \
    "2.5 cm ="    [pdf4tcllib::units::cm 2.5]   "pt" \
    "1 Zoll ="    [pdf4tcllib::units::inch 1]   "pt" \
    "72 pt ="     [pdf4tcllib::units::to_mm 72] "mm" \
] {
    set line [format "%s %.2f %s" $label $expr $result]
    pdf4tcllib::unicode::safeText $pdf $line -x [expr {$x + 20}] -y $y
    set y [expr {$y + 18}]
}

set y [expr {$y + 20}]

# Druckbereich visualisieren
$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Druckbarer Bereich" -x $x -y $y
set y [expr {$y + 24}]

$pdf setStrokeColor 0.8 0.2 0.2
$pdf setLineWidth 1.5
set dl [dict get $ctx left]
set dt [dict get $ctx top]
set dw [dict get $ctx text_w]
set dh [dict get $ctx text_h]
$pdf rectangle $dl $dt $dw $dh -stroke 1

$pdf setFont 9 $fontSans
$pdf setFillColor 0.8 0.2 0.2
pdf4tcllib::unicode::safeText $pdf \
    [format "%.0f x %.0f pt (%.0f x %.0f mm)" $dw $dh \
        [pdf4tcllib::units::to_mm $dw] [pdf4tcllib::units::to_mm $dh]] \
    -x [expr {$dl + 5}] -y [expr {$dt + 14}]

$pdf setStrokeColor 0 0 0
$pdf setFillColor 0 0 0

# Footer
pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib Demo Suite" 1
$pdf endPage

# ============================================================
# Seite 2: Verschiedene Papiergroessen
# ============================================================
$pdf startPage

pdf4tcllib::page::header $pdf $ctx "Papiergroessen-Vergleich"
set y [dict get $ctx top]
set x [dict get $ctx left]

$pdf setFont 14 $fontSansBold
pdf4tcllib::unicode::safeText $pdf "Unterstuetzte Papiergroessen" -x $x -y $y
set y [expr {$y + 30}]

foreach paper {a3 a4 a5 letter legal b5} {
    set pctx [pdf4tcllib::page::context $paper -margin 20]
    set pw [dict get $pctx page_w]
    set ph [dict get $pctx page_h]
    set tw [dict get $pctx text_w]
    set th [dict get $pctx text_h]

    $pdf setFont 12 $fontSansBold
    pdf4tcllib::unicode::safeText $pdf [string toupper $paper] -x $x -y $y
    set y [expr {$y + 18}]

    $pdf setFont 10 $fontSans
    set info [format "  Seite: %.0f x %.0f pt (%.0f x %.0f mm)  Druckbar: %.0f x %.0f pt" \
        $pw $ph \
        [pdf4tcllib::units::to_mm $pw] [pdf4tcllib::units::to_mm $ph] \
        $tw $th]
    pdf4tcllib::unicode::safeText $pdf $info -x $x -y $y
    set y [expr {$y + 14}]

    # Miniatur zeichnen
    set scale 0.08
    set miniW [expr {$pw * $scale}]
    set miniH [expr {$ph * $scale}]
    set miniX [expr {$x + 400}]
    set miniY [expr {$y - 28}]

    $pdf setFillColor 0.95 0.95 1.0
    $pdf rectangle $miniX $miniY $miniW $miniH -filled 1
    $pdf setStrokeColor 0.4 0.4 0.8
    $pdf rectangle $miniX $miniY $miniW $miniH -stroke 1

    set marg [expr {[dict get $pctx margin] * $scale}]
    $pdf setStrokeColor 0.8 0.4 0.4
    $pdf setLineWidth 0.3
    $pdf rectangle [expr {$miniX + $marg}] [expr {$miniY + $marg}] \
        [expr {$miniW - 2 * $marg}] [expr {$miniH - 2 * $marg}] -stroke 1

    $pdf setStrokeColor 0 0 0
    $pdf setFillColor 0 0 0
    $pdf setLineWidth 1

    set y [expr {$y + 16}]
}

pdf4tcllib::page::footer $pdf $ctx "pdf4tcllib Demo Suite" 2
$pdf endPage

set outdir [file join $scriptDir pdf]
file mkdir $outdir
set outfile [file join $outdir "demo_02_page_layout.pdf"]
$pdf write -file $outfile
$pdf destroy
catch {destroy .}
puts "Geschrieben: $outfile"
