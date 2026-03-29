#!/usr/bin/env tclsh
# Demo 48: Annotationen (pdf4tcl 0.9.4.23)
#
# Zeigt alle 7 Annotation-Typen:
#   addAnnotNote, addAnnotFreeText, addAnnotHighlight,
#   addAnnotUnderline, addAnnotStrikeOut, addAnnotStamp, addAnnotLine

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outfile [file join $outdir "demo_48_annotations.pdf"]

proc heading {pdf txt y} {
    $pdf setFillColor 0.1 0.25 0.5
    $pdf rectangle 40 $y 515 22 -filled 1
    $pdf setFillColor 1 1 1
    $pdf setFont 11 Helvetica-Bold
    $pdf text $txt -x 46 -y [expr {$y+15}]
    $pdf setFillColor 0 0 0
    return [expr {$y+30}]
}

proc infobox {pdf x y w txt} {
    $pdf setFillColor 0.93 0.97 1.0
    $pdf setStrokeColor 0.6 0.8 1.0
    $pdf setLineWidth 0.5
    $pdf rectangle $x [expr {$y-4}] $w 16 -filled 1
    $pdf setFont 8 Courier
    $pdf setFillColor 0.1 0.3 0.6
    $pdf text $txt -x [expr {$x+4}] -y $y
    $pdf setFillColor 0 0 0
    $pdf setStrokeColor 0 0 0
}

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]

# ===========================================================================
# Seite 1: Note, FreeText, Highlight
# ===========================================================================
$pdf startPage

$pdf setFont 15 Helvetica-Bold
$pdf setFillColor 0.1 0.25 0.5
$pdf text "Demo 48 -- Annotationen (pdf4tcl 0.9.4.23)" -x 40 -y 28
$pdf setFillColor 0 0 0
$pdf setLineWidth 0.5
$pdf setStrokeColor 0.5 0.5 0.5
$pdf line 40 44 555 44
$pdf setStrokeColor 0 0 0
set y 58

# --- addAnnotNote ---
set y [heading $pdf "1. addAnnotNote -- Sticky Note" $y]

$pdf setFont 10 Helvetica
$pdf text "Erscheint als Icon -- Klick oeffnet Popup." -x 46 -y $y
$pdf text "(Popup-Verhalten ist viewer-abhaengig)" -x 300 -y $y
set y [expr {$y+18}]

foreach {lbl icon col cx} {
    "Note (gelb)"   Note    {1 1 0.3}   46
    "Comment (blau)" Comment {0.6 0.8 1} 200
    "Key (gruen)"   Key     {0.6 1 0.6} 354
} {
    $pdf addAnnotNote $cx $y 20 20 \
        -icon $icon -color $col \
        -content "Icon: $icon\nAutor: Greg" \
        -author "Greg"
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.3 0.3 0.3
    $pdf text $lbl -x [expr {$cx+26}] -y [expr {$y+14}]
    $pdf setFillColor 0 0 0
}
set y [expr {$y+35}]
infobox $pdf 46 $y 510 \
    {addAnnotNote x y w h  -content text  -author name  -icon Note|Comment|Key  -color {r g b}}
set y [expr {$y+24}]

# --- addAnnotFreeText ---
set y [heading $pdf "2. addAnnotFreeText -- Sichtbare Textbox" $y]

$pdf setFont 10 Helvetica
$pdf text "Direkt sichtbar -- kein Klick noetig. Konsistent in allen Viewern." -x 46 -y $y
set y [expr {$y+14}]

$pdf addAnnotFreeText 46 $y 230 40 \
    "Standard FreeText\nHintergrund: hellgelb" \
    -fontsize 10
$pdf addAnnotFreeText 296 $y 255 40 \
    "Angepasst: blaue Schrift\nblaues Hintergrund" \
    -fontsize 9 -color {0 0 0.6} -bgcolor {0.88 0.92 1.0}
set y [expr {$y+55}]
infobox $pdf 46 $y 510 \
    {addAnnotFreeText x y w h text  -fontsize n  -color {r g b}  -bgcolor {r g b}}
set y [expr {$y+24}]

# --- addAnnotHighlight ---
set y [heading $pdf "3. addAnnotHighlight -- Textmarkierung" $y]

$pdf setFont 10 Helvetica
$pdf text "Markiert Textbereiche wie ein Textmarker." -x 46 -y $y
set y [expr {$y+18}]

foreach {txt col} {
    "Gelb markierter Text (Standard)"        {1 1 0.3}
    "Gruen markierter Text (-color option)"  {0.6 1 0.6}
    "Blau markierter Text"                   {0.7 0.85 1}
} {
    $pdf setFont 11 Helvetica
    $pdf text $txt -x 46 -y [expr {$y+12}]
    $pdf addAnnotHighlight 46 $y 380 16 -color $col
    set y [expr {$y+22}]
}
set y [expr {$y+4}]
infobox $pdf 46 $y 510 \
    {addAnnotHighlight x y w h  -color {r g b}  -content text}
set y [expr {$y+24}]

$pdf endPage

# ===========================================================================
# Seite 2: Underline, StrikeOut, Stamp, Line
# ===========================================================================
$pdf startPage

$pdf setFont 14 Helvetica-Bold
$pdf text "Seite 2: Underline, StrikeOut, Stamp, Line" -x 40 -y 28
$pdf setLineWidth 0.5
$pdf setStrokeColor 0.5 0.5 0.5
$pdf line 40 44 555 44
$pdf setStrokeColor 0 0 0
set y 58

# --- addAnnotUnderline ---
set y [heading $pdf "4. addAnnotUnderline -- Unterstreichung" $y]

$pdf setFont 10 Helvetica
$pdf text "Unterstreicht Textbereiche als Annotation (nicht Textformatierung)." -x 46 -y $y
set y [expr {$y+18}]

foreach {txt col} {
    "Schwarze Unterstreichung (Standard)"      {0 0 0}
    "Blaue Unterstreichung fuer Korrekturen"   {0 0 0.8}
    "Rote Unterstreichung -- Fehler markieren" {0.8 0 0}
} {
    $pdf setFont 11 Helvetica
    $pdf text $txt -x 46 -y [expr {$y+12}]
    $pdf addAnnotUnderline 46 $y 400 16 -color $col
    set y [expr {$y+22}]
}
set y [expr {$y+4}]
infobox $pdf 46 $y 510 \
    {addAnnotUnderline x y w h  -color {r g b}  -content text  -author name}
set y [expr {$y+24}]

# --- addAnnotStrikeOut ---
set y [heading $pdf "5. addAnnotStrikeOut -- Durchstreichen" $y]

$pdf setFont 10 Helvetica
$pdf text "Markiert Text als geloescht -- fuer Review und Korrekturen." -x 46 -y $y
set y [expr {$y+18}]

foreach {txt col} {
    "Dieser Text wird als geloescht markiert"  {0.9 0 0}
    "Grau durchgestrichen (weniger aufdringl.)" {0.5 0.5 0.5}
    "Kombination: Highlight + StrikeOut moegl." {0 0 0}
} {
    $pdf setFont 11 Helvetica
    $pdf text $txt -x 46 -y [expr {$y+12}]
    $pdf addAnnotStrikeOut 46 $y 400 16 -color $col
    set y [expr {$y+22}]
}
set y [expr {$y+4}]
infobox $pdf 46 $y 510 \
    {addAnnotStrikeOut x y w h  -color {r g b}  -content text}
set y [expr {$y+24}]

# --- addAnnotStamp ---
set y [heading $pdf "6. addAnnotStamp -- Stempel" $y]

$pdf setFont 10 Helvetica
$pdf text "Vordefinierte Stempel: Draft, Confidential, Approved, Final, Expired, TopSecret..." -x 46 -y $y
set y [expr {$y+18}]

foreach {name col x} {
    Draft        {0.8 0 0}     46
    Confidential {0.7 0.2 0}  200
    Approved     {0 0.5 0.1}  380
} {
    $pdf addAnnotStamp $x $y 120 45 -name $name -color $col
    $pdf setFont 8 Helvetica
    $pdf setFillColor 0.4 0.4 0.4
    $pdf text $name -x [expr {$x+2}] -y [expr {$y+56}]
    $pdf setFillColor 0 0 0
}
set y [expr {$y+72}]
infobox $pdf 46 $y 510 \
    {addAnnotStamp x y w h  -name Draft|Confidential|Approved|...  -color {r g b}}
set y [expr {$y+24}]

# --- addAnnotLine ---
set y [heading $pdf "7. addAnnotLine -- Linie mit Pfeilspitzen" $y]

$pdf setFont 10 Helvetica
$pdf text "Linie als Annotation mit konfigurierbaren Pfeilspitzen." -x 46 -y $y
set y [expr {$y+18}]

foreach {lbl se col w} {
    "Einfache Linie"            {None None}       {0 0 0}     1.0
    "Pfeil (OpenArrow)"         {None OpenArrow}  {0 0 0.8}   1.5
    "Doppelpfeil"               {OpenArrow OpenArrow} {0 0.5 0} 1.5
    "Dicker Pfeil (ClosedArrow)" {None ClosedArrow} {0.8 0 0}  2.0
} {
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.3 0.3 0.3
    $pdf text $lbl -x 46 -y $y
    $pdf addAnnotLine 200 [expr {$y-4}] 500 [expr {$y-4}] \
        -startend $se -color $col -width $w
    set y [expr {$y+18}]
}
set y [expr {$y+4}]
infobox $pdf 46 $y 510 \
    {addAnnotLine x1 y1 x2 y2  -startend {None OpenArrow}  -color {r g b}  -width n}

$pdf endPage
$pdf write -file $outfile
$pdf destroy
puts "Geschrieben: $outfile"
