#!/usr/bin/env wish
# Demo 08: Tk Canvas -> PDF
#
# Zeigt wie ein Tk-Canvas direkt als PDF gerendert wird.
# Zwei Seiten:
#   Seite 1: Grundformen (rectangle, line, oval, arc, polygon, text)
#   Seite 2: Praxisbeispiel (einfaches Diagramm)
#
# Usage: wish demos/08_canvas.tcl [outputdir]

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outfile [file join $outdir "demo_08_canvas.pdf"]

# ---------------------------------------------------------------------------
# Hilfsproc: Canvas zeichnen und in PDF einbetten
# ---------------------------------------------------------------------------
proc canvasToPdf {pdf canvasCmd x y w h} {
    # Canvas erstellen, Inhalt zeichnen, in PDF einbetten, zerstoeren
    canvas .tmp -width $w -height $h -background white
    pack .tmp
    uplevel 1 $canvasCmd
    update idletasks
    $pdf canvas .tmp -x $x -y $y -width $w -height $h
    destroy .tmp
}

wm withdraw .

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]

# ===========================================================================
# Seite 1: Alle Canvas-Item-Typen
# ===========================================================================
$pdf startPage
pdf4tcllib::page::header $pdf \
    [pdf4tcllib::page::context a4 -margin 40] \
    "Demo 08: Tk Canvas -> PDF"

$pdf setFont 12 Helvetica-Bold
$pdf text "Alle Standard-Canvas-Items:" -x 47 -y 60

canvasToPdf $pdf {
    # Hintergrund
    .tmp create rectangle 0 0 500 600 -fill white -outline ""

    # Abschnitt-Labels
    foreach {lbl x y} {
        "rectangle"  10  30
        "line"       10 110
        "oval"       10 200
        "arc"        10 290
        "polygon"    10 380
        "text"       10 480
    } {
        .tmp create text $x $y -text $lbl -font {Helvetica 9 bold} \
            -fill "#555555" -anchor w
    }

    # Rectangles
    .tmp create rectangle  10  45 110 100 -fill "#b3d1f0" -outline "#0055aa" -width 2
    .tmp create rectangle 130  45 230 100 -fill "" -outline "#cc3300" -width 2 -dash {6 3}
    .tmp create rectangle 250  45 350 100 -fill "#ffe066" -outline "#cc8800"

    # Lines
    .tmp create line  10 125 200 125 -fill black -width 2
    .tmp create line  10 140 200 140 -fill "#0055aa" -width 2 -dash {8 4}
    .tmp create line  10 155 200 140 -fill "#cc0000" -width 2 -arrow last
    .tmp create line 220 120 450 160 -fill "#006600" -width 3 -arrow both

    # Ovals
    .tmp create oval  10 215 110 280 -fill "#ffcccc" -outline "#cc0000" -width 2
    .tmp create oval 130 215 230 280 -fill "" -outline "#0000cc" -width 2
    .tmp create oval 250 215 450 265 -fill "#ccffcc" -outline "#006600"

    # Arcs
    .tmp create arc  10 305 100 380 -start 0   -extent 270 -fill "#ffeecc" -outline "#cc6600"
    .tmp create arc 120 305 210 380 -start 45  -extent 180 -style chord -fill "#cceeff"
    .tmp create arc 230 305 320 380 -start 90  -extent 120 -style arc -outline "#990099" -width 3
    .tmp create arc 340 305 430 380 -start 0   -extent 360 -fill "#ffccff" -outline "#660066"

    # Polygons
    .tmp create polygon  10 470  70 395 130 470 -fill "#ddeeff" -outline "#003399" -width 2
    set cx 230; set cy 435; set r1 35; set r2 15
    set spts {}
    for {set i 0} {$i < 10} {incr i} {
        set r [expr {($i%2) ? $r2 : $r1}]
        set a [expr {-3.14159/2 + $i*3.14159/5}]
        lappend spts [expr {$cx + $r*cos($a)}] [expr {$cy + $r*sin($a)}]
    }
    .tmp create polygon {*}$spts -fill "#ffe066" -outline "#cc8800" -width 2
    set cx 380; set cy 435
    set hpts {}
    for {set i 0} {$i < 6} {incr i} {
        set a [expr {$i*3.14159/3}]
        lappend hpts [expr {$cx + 35*cos($a)}] [expr {$cy + 35*sin($a)}]
    }
    .tmp create polygon {*}$hpts -fill "#e0ffe0" -outline "#006600" -width 2

    # Text
    .tmp create text  50 500 -text "Normal"  -font {Helvetica 12}        -anchor w
    .tmp create text 150 500 -text "Bold"    -font {Helvetica 12 bold}   -fill "#003399" -anchor w
    .tmp create text 250 500 -text "Italic"  -font {Helvetica 12 italic} -fill "#cc3300" -anchor w
    .tmp create text 350 500 -text "Courier" -font {Courier  12}         -fill "#006600" -anchor w

    .tmp create text 250 580 \
        -text "pdf4tcl canvas -x -y -width -height" \
        -font {Helvetica 8} -fill "#888888" -anchor center
} 47 75 500 600

$pdf endPage

# ===========================================================================
# Seite 2: Balkendiagramm als Canvas
# ===========================================================================
$pdf startPage
pdf4tcllib::page::header $pdf \
    [pdf4tcllib::page::context a4 -margin 40] \
    "Demo 08: Canvas-Diagramm"

$pdf setFont 12 Helvetica-Bold
$pdf text "Praxisbeispiel: Balkendiagramm" -x 47 -y 60

set data {
    {"Jan" 120} {"Feb" 185} {"Mrz" 160} {"Apr" 220}
    {"Mai" 195} {"Jun" 240} {"Jul" 210} {"Aug" 175}
}
set maxVal 280

canvasToPdf $pdf {
    set cw 500; set ch 350
    set lm 50; set rm 20; set tm 20; set bm 50
    set barW [expr {($cw - $lm - $rm) / [llength $data] - 8}]
    set chartH [expr {$ch - $tm - $bm}]

    # Hintergrund + Raster
    .tmp create rectangle 0 0 $cw $ch -fill white -outline ""
    for {set v 0} {$v <= 300} {incr v 50} {
        set y [expr {$tm + $chartH - ($v * $chartH / $maxVal)}]
        .tmp create line $lm $y [expr {$cw-$rm}] $y \
            -fill "#eeeeee" -width 1
        .tmp create text [expr {$lm-5}] $y \
            -text $v -font {Helvetica 8} -anchor e -fill "#666666"
    }

    # Balken
    set i 0
    foreach item $data {
        lassign $item lbl val
        set x1 [expr {$lm + $i * ($barW + 8) + 4}]
        set x2 [expr {$x1 + $barW}]
        set y1 [expr {$tm + $chartH - ($val * $chartH / $maxVal)}]
        set y2 [expr {$tm + $chartH}]

        # Farbverlauf simuliert durch zwei Rechtecke
        .tmp create rectangle $x1 $y1 $x2 $y2 \
            -fill "#4a90d9" -outline "#2266aa" -width 1
        .tmp create rectangle $x1 $y1 [expr {$x1+$barW/3}] $y2 \
            -fill "#6aaeee" -outline "" -width 0

        # Wert
        .tmp create text [expr {($x1+$x2)/2}] [expr {$y1-8}] \
            -text $val -font {Helvetica 8 bold} -fill "#2255aa" -anchor s

        # Label
        .tmp create text [expr {($x1+$x2)/2}] [expr {$y2+12}] \
            -text $lbl -font {Helvetica 9} -anchor n -fill "#333333"

        incr i
    }

    # Achsen
    .tmp create line $lm $tm $lm [expr {$tm+$chartH}] -fill black -width 2
    .tmp create line $lm [expr {$tm+$chartH}] [expr {$cw-$rm}] [expr {$tm+$chartH}] \
        -fill black -width 2

    # Titel
    .tmp create text [expr {$cw/2}] [expr {$ch-8}] \
        -text "Monatsumsatz (Einheiten)" -font {Helvetica 9} \
        -fill "#555555" -anchor s
} 47 75 500 350

$pdf endPage

$pdf write -file $outfile
$pdf destroy
puts "Geschrieben: $outfile"
