#!/usr/bin/env wish
# Demo 49: Tk Canvas -> PDF (pdf4tcl canvas-Methode)
#
# pdf4tcl kann einen Tk-Canvas direkt als PDF rendern.
# Alle Standard-Canvas-Items werden unterstuetzt:
#   rectangle, line, oval, arc, polygon, text, image
#
# Usage: wish 49_canvas.tcl [outputdir]
#
# WICHTIG: Braucht Tk (wish), nicht tclsh!

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outfile [file join $outdir "demo_49_canvas.pdf"]

# ---------------------------------------------------------------------------
# Tk-Canvas erstellen (wird nicht angezeigt -- nur als Zeichenfläche)
# ---------------------------------------------------------------------------
wm withdraw .
canvas .c -width 500 -height 700 -background white
pack .c

# ---------------------------------------------------------------------------
# Canvas mit allen Item-Typen befüllen
# ---------------------------------------------------------------------------

# Titel
.c create text 250 25 -text "Demo 49: Canvas -> PDF" \
    -font {Helvetica 16 bold} -fill "#1a3f7a" -anchor center

# Trennlinie
.c create line 20 45 480 45 -fill "#888888" -width 1

# --- 1. Rechtecke ---
.c create text 20 60 -text "1. Rechtecke" -font {Helvetica 11 bold} -anchor w
.c create rectangle 20 75 160 135 -fill "#b3d1f0" -outline "#0055aa" -width 2
.c create rectangle 180 75 320 135 -fill "" -outline "#cc3300" -width 2 -dash {5 3}
.c create rectangle 340 75 480 135 -fill "#f0e68c" -outline "#8b6914" -width 1

# --- 2. Linien ---
.c create text 20 150 -text "2. Linien + Pfeile" -font {Helvetica 11 bold} -anchor w
.c create line 20 170 200 170 -fill black -width 2
.c create line 20 185 200 185 -fill "#0055aa" -width 2 -dash {8 4}
.c create line 20 200 200 185 -fill "#cc3300" -width 2 -arrow last
.c create line 220 165 450 200 -fill "#006600" -width 3 -arrow both

# --- 3. Ovals / Kreise ---
.c create text 20 220 -text "3. Ovals" -font {Helvetica 11 bold} -anchor w
.c create oval  20 235 130 305 -fill "#ffcccc" -outline "#cc0000" -width 2
.c create oval 150 235 260 305 -fill "" -outline "#0000cc" -width 2
.c create oval 280 235 480 285 -fill "#ccffcc" -outline "#006600" -width 1

# --- 4. Polygone ---
.c create text 20 320 -text "4. Polygone" -font {Helvetica 11 bold} -anchor w
# Dreieck
.c create polygon 20 390 80 330 140 390 -fill "#ddeeff" -outline "#003399" -width 2
# Stern
set cx 250; set cy 365; set r1 40; set r2 18
set pts {}
for {set i 0} {$i < 10} {incr i} {
    set r [expr {($i%2) ? $r2 : $r1}]
    set a [expr {-3.14159/2 + $i*3.14159/5}]
    lappend pts [expr {$cx + $r*cos($a)}] [expr {$cy + $r*sin($a)}]
}
.c create polygon {*}$pts -fill "#ffe066" -outline "#cc8800" -width 2
# Hexagon
set cx 400; set cy 365
set pts {}
for {set i 0} {$i < 6} {incr i} {
    set a [expr {$i*3.14159/3}]
    lappend pts [expr {$cx + 40*cos($a)}] [expr {$cy + 40*sin($a)}]
}
.c create polygon {*}$pts -fill "#e0ffe0" -outline "#006600" -width 2

# --- 5. Arcs ---
.c create text 20 415 -text "5. Arcs (Kreisbogen)" -font {Helvetica 11 bold} -anchor w
.c create arc  20 430 120 530 -start 0   -extent 270 -fill "#ffeecc" -outline "#cc6600" -width 2
.c create arc 140 430 240 530 -start 45  -extent 180 -style chord -fill "#cceeff" -outline "#006699" -width 2
.c create arc 260 430 360 530 -start 90  -extent 120 -style arc   -outline "#990099" -width 3
.c create arc 380 430 480 530 -start 180 -extent 270 -fill "#ffccff" -outline "#660066" -width 1

# --- 6. Text ---
.c create text 20 550 -text "6. Text" -font {Helvetica 11 bold} -anchor w
.c create text  80 580 -text "Normal"  -font {Helvetica 12}       -fill black   -anchor w
.c create text 200 580 -text "Bold"    -font {Helvetica 12 bold}  -fill "#003399" -anchor w
.c create text 300 580 -text "Italic"  -font {Helvetica 12 italic} -fill "#cc3300" -anchor w
.c create text 400 580 -text "Courier" -font {Courier 12}         -fill "#006600" -anchor w

# --- 7. Info ---
.c create text 250 650 \
    -text "Alle Items: rectangle, line, oval, arc, polygon, text" \
    -font {Helvetica 9} -fill "#666666" -anchor center

# ---------------------------------------------------------------------------
# Canvas -> PDF rendern
# ---------------------------------------------------------------------------
update idletasks  ;# Canvas muss gerendert sein

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]
$pdf startPage

# Canvas in PDF einbetten
$pdf canvas .c -x 47 -y 47 -width 500 -height 700

$pdf endPage
$pdf write -file $outfile
$pdf destroy

destroy .
puts "Geschrieben: $outfile"
