#!/usr/bin/env tclsh
# Demo 29: Text-Skalierung (pdf4tcllib::drawing::textScaled)
#
# Zeigt horizontale, vertikale und kombinierte Textskalierung.
# textScaled nutzt gsave/translate/scale/grestore -- korrekte Metriken.

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outfile [file join $outdir "demo_29_text_scaling.pdf"]

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]
$pdf startPage

$pdf setFont 15 Helvetica-Bold
$pdf setFillColor 0.1 0.25 0.5
$pdf text "Demo 29 -- Text-Skalierung" -x 40 -y 28
$pdf setFillColor 0 0 0
$pdf setLineWidth 0.5
$pdf setStrokeColor 0.5 0.5 0.5
$pdf line 40 44 555 44
$pdf setStrokeColor 0 0 0

# ---------------------------------------------------------------------------
# Hilfsproc: Abschnitt-Label OHNE Linie durch Text
# ---------------------------------------------------------------------------
proc sectionLabel {pdf txt y} {
    $pdf setFont 10 Helvetica-Bold
    $pdf setFillColor 0.1 0.25 0.5
    $pdf text $txt -x 40 -y $y
    $pdf setFillColor 0 0 0
    return [expr {$y + 16}]
}

proc rowLabel {pdf txt x y} {
    $pdf setFont 8 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    $pdf text $txt -x $x -y $y
    $pdf setFillColor 0 0 0
}

# ---------------------------------------------------------------------------
# 1. Horizontale Skalierung
# ---------------------------------------------------------------------------
set y 62
set y [sectionLabel $pdf "1. Horizontale Skalierung (sx variiert, sy=1.0 fest):" $y]
incr y 6

foreach {sx col} {
    0.4 {0.6 0 0}
    0.7 {0 0 0.6}
    1.0 {0 0.5 0}
    1.5 {0.4 0 0.5}
    2.0 {0.5 0.3 0}
} {
    # Label links (über Text, kein Überlappen)
    rowLabel $pdf "sx=$sx" 40 $y
    # Skalierter Text darunter
    set ty [expr {$y + 18}]
    $pdf setFillColor {*}$col
    pdf4tcllib::drawing::textScaled $pdf "Text sx=$sx" 40 $ty $sx 1.0 13 Helvetica
    # Info rechts auf gleicher Höhe wie Text
    rowLabel $pdf "(sx=$sx)" 480 $ty
    $pdf setFillColor 0 0 0
    set y [expr {$ty + 22}]
}

# ---------------------------------------------------------------------------
# 2. Vertikale Skalierung
# ---------------------------------------------------------------------------
incr y 10
set y [sectionLabel $pdf "2. Vertikale Skalierung (sy variiert, sx=1.0 fest):" $y]
incr y 6

foreach {sy col} {
    0.4 {0.6 0 0}
    0.7 {0 0 0.6}
    1.0 {0 0.5 0}
    1.5 {0.4 0 0.5}
} {
    rowLabel $pdf "sy=$sy" 40 $y
    set gap2 [expr {int(10 * $sy + 14)}]
    set ty [expr {$y + $gap2}]
    $pdf setFillColor {*}$col
    pdf4tcllib::drawing::textScaled $pdf "Text sy=$sy" 40 $ty 1.0 $sy 13 Helvetica
    rowLabel $pdf "(sy=$sy)" 480 $ty
    $pdf setFillColor 0 0 0
    set y [expr {$ty + int(11 * $sy + 14)}]
}

# ---------------------------------------------------------------------------
# 3. Kombiniert
# ---------------------------------------------------------------------------
incr y 10
set y [sectionLabel $pdf "3. Kombiniert (sx und sy):" $y]
incr y 6

foreach {lbl sx sy col} {
    "Gestaucht (sx=0.5 sy=0.5)"     0.5 0.5 {0.6 0 0}
    "Breit + flach (sx=2.0 sy=0.5)" 2.0 0.5 {0 0 0.6}
    "Schmal + hoch (sx=0.5 sy=2.0)" 0.5 2.0 {0 0.5 0}
    "Normal (sx=1.0 sy=1.0)"        1.0 1.0 {0 0 0}
} {
    rowLabel $pdf $lbl 40 $y
    # Abstand Label->Text je nach sy: groesseres sy = mehr Platz fuer Ascender
    set gap [expr {int(11 * $sy + 14)}]
    set ty [expr {$y + $gap}]
    $pdf setFillColor {*}$col
    pdf4tcllib::drawing::textScaled $pdf "Beispieltext" 40 $ty $sx $sy 13 Helvetica
    rowLabel $pdf "sx=$sx sy=$sy" 430 $ty
    $pdf setFillColor 0 0 0
    set y [expr {$ty + int(13 * $sy + 20)}]
}

# ---------------------------------------------------------------------------
# 4. Praxisbeispiel
# ---------------------------------------------------------------------------
incr y 20
set y [sectionLabel $pdf "4. Praxisbeispiel: Ueberschriften-Hierarchie via Skalierung:" $y]
incr y 14

foreach {lbl sx sy size col} {
    "H1 -- Hauptueberschrift"  1.0 1.4 16 {0.1 0.2 0.4}
    "H2 -- Abschnitt"          1.0 1.2 14 {0.1 0.2 0.4}
    "H3 -- Unterabschnitt"     1.0 1.0 12 {0.1 0.2 0.4}
    "Fliesstext normal"        1.0 0.9 11 {0.2 0.2 0.2}
} {
    $pdf setFillColor {*}$col
    pdf4tcllib::drawing::textScaled $pdf $lbl 40 $y $sx $sy $size Helvetica-Bold
    $pdf setFillColor 0 0 0
    set y [expr {$y + int($size * $sy + 14)}]
}

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Geschrieben: $outfile"
