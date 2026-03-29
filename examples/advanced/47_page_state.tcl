#!/usr/bin/env tclsh
# Demo 47: Page-State APIs (pdf4tcl 0.9.4.23)
#
# Zeigt:
#   - getStringWidth -font -size  (exakte Textbreite ohne setFont)
#   - inPage                      (Seitenstatus abfragen)
#   - currentPage                 (aktuelle Seitennummer)
#   - pageCount                   (abgeschlossene Seiten)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outfile [file join $outdir "demo_47_page_state.pdf"]

# ---------------------------------------------------------------------------
# Hilfsproc: Info-Box
# ---------------------------------------------------------------------------
proc infobox {pdf x y w txt} {
    $pdf setFillColor 0.93 0.97 1.0
    $pdf setStrokeColor 0.6 0.8 1.0
    $pdf setLineWidth 0.5
    $pdf rectangle $x [expr {$y-4}] $w 16 -filled 1
    $pdf setFont 9 Courier
    $pdf setFillColor 0.1 0.3 0.6
    $pdf text $txt -x [expr {$x+4}] -y $y
    $pdf setFillColor 0 0 0
    $pdf setStrokeColor 0 0 0
}

proc heading {pdf txt y} {
    $pdf setFillColor 0.1 0.25 0.5
    $pdf rectangle 40 $y 515 22 -filled 1
    $pdf setFillColor 1 1 1
    $pdf setFont 11 Helvetica-Bold
    $pdf text $txt -x 46 -y [expr {$y+15}]
    $pdf setFillColor 0 0 0
    return [expr {$y+30}]
}

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]

# ===========================================================================
# Seite 1
# ===========================================================================
$pdf startPage

$pdf setFont 15 Helvetica-Bold
$pdf setFillColor 0.1 0.25 0.5
$pdf text "Demo 47 -- Page-State APIs (0.9.4.23)" -x 40 -y 28
$pdf setFillColor 0 0 0
$pdf setLineWidth 0.5
$pdf setStrokeColor 0.5 0.5 0.5
$pdf line 40 44 555 44
$pdf setStrokeColor 0 0 0

set y 58

# ---------------------------------------------------------------------------
# 1. inPage
# ---------------------------------------------------------------------------
set y [heading $pdf "1. inPage -- Seitenstatus abfragen" $y]

$pdf setFont 10 Helvetica
$pdf text "Gibt 1 zurueck wenn eine Seite offen ist, sonst 0." -x 46 -y $y
set y [expr {$y+18}]

set state [$pdf inPage]
$pdf setFont 10 Helvetica
$pdf text "Aktueller Status: inPage = $state  (1 = Seite offen)" -x 46 -y $y
set y [expr {$y+14}]

infobox $pdf 46 $y 420 {Aufruf: $pdf inPage  -->  1 (Seite offen) oder 0 (keine Seite)}
set y [expr {$y+28}]

# Beispiel: Library-Code der inPage nutzt
$pdf setFont 10 Helvetica-Bold
$pdf text "Anwendungsfall -- sicheres Zeichnen:" -x 46 -y $y
set y [expr {$y+14}]
$pdf setFont 9 Courier
$pdf setFillColor 0.2 0.2 0.2
foreach line {
    "if {![$pdf inPage]} {"
    "    $pdf startPage"
    "}"
    "$pdf text \"Inhalt\" -x 50 -y 100"
} {
    $pdf text $line -x 56 -y $y
    set y [expr {$y+13}]
}
$pdf setFillColor 0 0 0
set y [expr {$y+10}]

# ---------------------------------------------------------------------------
# 2. currentPage / pageCount
# ---------------------------------------------------------------------------
set y [heading $pdf "2. currentPage + pageCount" $y]

$pdf setFont 10 Helvetica
$pdf text "currentPage: aktuelle Seitennummer (1-basiert)." -x 46 -y $y
set y [expr {$y+16}]
$pdf text "pageCount:   Anzahl abgeschlossener Seiten (endPage aufgerufen)." -x 46 -y $y
set y [expr {$y+20}]

set cp [$pdf currentPage]
set pc [$pdf pageCount]
$pdf setFont 10 Helvetica
$pdf text "Jetzt: currentPage=$cp  pageCount=$pc  (Seite 1 offen, noch kein endPage)" \
    -x 46 -y $y
set y [expr {$y+16}]

infobox $pdf 46 $y 480 \
    {$pdf currentPage  -->  1 (diese Seite)  |  $pdf pageCount  -->  0 (noch keine fertig)}
set y [expr {$y+28}]

# Anwendungsfall: Seitennummer im Footer
$pdf setFont 10 Helvetica-Bold
$pdf text "Anwendungsfall -- Seitennummer im Footer:" -x 46 -y $y
set y [expr {$y+14}]
$pdf setFont 9 Courier
$pdf setFillColor 0.2 0.2 0.2
foreach line {
    "proc footer {pdf} {"
    "    set n [$pdf currentPage]"
    "    $pdf setFont 9 Helvetica"
    "    $pdf text \"Seite $n\" -x 297 -y 820 -align center"
    "}"
} {
    $pdf text $line -x 56 -y $y
    set y [expr {$y+13}]
}
$pdf setFillColor 0 0 0
set y [expr {$y+10}]

# ---------------------------------------------------------------------------
# 3. getStringWidth -font -size
# ---------------------------------------------------------------------------
set y [heading $pdf "3. getStringWidth -font -size" $y]

$pdf setFont 10 Helvetica
$pdf text "Misst Textbreite exakt -- ohne prior setFont noetig." -x 46 -y $y
set y [expr {$y+16}]
$pdf text "Nutzt echte TTF-Font-Metriken (Kerning, proportionale Breiten)." -x 46 -y $y
set y [expr {$y+20}]

# Vergleich: verschiedene Fonts + Groessen
$pdf setFont 10 Helvetica-Bold
$pdf text "Beispiele:" -x 46 -y $y
set y [expr {$y+16}]

foreach {txt font size} {
    "Hello World"   Helvetica    12
    "Hello World"   Helvetica    18
    "Hello World"   Courier      12
    "iiiiiiiiii"    Helvetica    12
    "MMMMMMMMMM"    Helvetica    12
} {
    set w [$pdf getStringWidth $txt -font $font -size $size]
    set w_fmt [format "%.1f" $w]

    # Text in der richtigen Grösse zeichnen
    $pdf setFont $size $font
    $pdf text $txt -x 46 -y $y

    # Breiten-Linie
    $pdf setStrokeColor 0.8 0 0
    $pdf setLineWidth 0.5
    $pdf line 46 [expr {$y+3}] [expr {46+$w}] [expr {$y+3}]
    $pdf setStrokeColor 0 0 0

    # Info rechts
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.4 0.4 0.4
    $pdf text "${w_fmt}pt  (${font} ${size}pt)" -x 280 -y $y
    $pdf setFillColor 0 0 0

    set y [expr {$y + $size + 6}]
}

set y [expr {$y+8}]
infobox $pdf 46 $y 480 \
    {$pdf getStringWidth "Hello World" -font Helvetica -size 12  -->  exakte Breite in pt}
set y [expr {$y+28}]

# Anwendungsfall: Text zentrieren ohne setFont
$pdf setFont 10 Helvetica-Bold
$pdf text "Anwendungsfall -- Text zentrieren ohne setFont:" -x 46 -y $y
set y [expr {$y+14}]
$pdf setFont 9 Courier
$pdf setFillColor 0.2 0.2 0.2
set pageW 595
foreach line [list \
    "set w \[\$pdf getStringWidth \$title -font Helvetica-Bold -size 16\]" \
    "set x \[expr {(\$pageW - \$w) / 2.0}\]" \
    "\$pdf setFont 16 Helvetica-Bold" \
    "\$pdf text \$title -x \$x -y 40" \
] {
    $pdf text $line -x 56 -y $y
    set y [expr {$y+13}]
}
$pdf setFillColor 0 0 0

$pdf endPage

# ===========================================================================
# Seite 2 -- pageCount nach mehreren Seiten
# ===========================================================================
$pdf startPage

$pdf setFont 14 Helvetica-Bold
$pdf text "Seite 2: currentPage + pageCount im Mehrseiten-Dokument" -x 40 -y 40

$pdf setFont 10 Helvetica
set y 70
foreach {lbl val} [list \
    "currentPage (jetzt):" [$pdf currentPage] \
    "pageCount (Seite 1 fertig):" [$pdf pageCount] \
] {
    $pdf text "$lbl  $val" -x 46 -y $y
    set y [expr {$y+18}]
}

$pdf setFont 9 Helvetica
$pdf setFillColor 0.4 0.4 0.4
$pdf text "(Seite 1 wurde mit endPage abgeschlossen --> pageCount = 1)" -x 46 -y $y
$pdf setFillColor 0 0 0

$pdf endPage

$pdf write -file $outfile
$pdf destroy
puts "Geschrieben: $outfile"
