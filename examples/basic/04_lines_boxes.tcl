#!/usr/bin/env tclsh
# ============================================================================
# Demo 04: Lines and boxes
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS: nichts zu tun -- der UTF-8-Vorspann unten liest diese
#   Datei neu, wenn die Systemkodierung nicht UTF-8 ist. Hier stand
#   frueher ein Verweis auf "examples/main.tcl" -- eine Datei, die es
#   in diesem Baum nicht gibt.
#
#   NOT directly -- that gives wrong characters in the PDF:
#     tclsh 04_lines_boxes.tcl
# ============================================================================
# What this shows:
#   - Linien zeichnen (horizontal, vertikal, diagonal)
#   - Rechtecke zeichnen
#   - filled shapes
#   - different line widths
#
# Features:
#   - Verschiedene Linienarten
#   - boxes with and without a fill
#   - line widths side by side
#   - coloured fills
#
# Encoding test: äöüÄÖÜß€
# ============================================================================

# --- Setup ---
# --- UTF-8 sicherstellen (Tcl 8.6 liest Skripte in der Systemkodierung) ---
source [file join [file dirname [info script]] .. _utf8.tcl]
if {![utf8Pruefen "ä"]} {
    if {[utf8Neuladen [info script]]} { return }
}

set script_dir [file dirname [file normalize [info script]]]

# Load helper library

# Require pdf4tcl 0.9.4.11+
if {[catch {set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.6
package require pdf4tcl} err]} {
    puts stderr "❌ ERROR: pdf4tcl 0.9.4.11+ required!"
    puts stderr "   Your version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.6
package require pdf4tcl]"
    puts stderr "   Update: See SPEC.lock for installation"
    exit 1
}

# --- Configuration ---
set output_dir [file join $scriptDir pdf]
file mkdir $output_dir

set demo_num 4
set demo_name "lines_boxes"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Linien und Rahmen"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.6
package require pdf4tcl]"
    puts "  Output: $output_file"
    
    # ========================================================================
    # STEP 1: Create Page Context
    # ========================================================================
    
    set ctx [pdf4tcllib::page::context a4 20 true]
    
    puts "  Context:"
    puts "    Paper:  [dict get $ctx paper]"
    puts "    Orient: [dict get $ctx orient] (y-origin [expr {[dict get $ctx orient] ? "top" : "bottom"}])"
    puts "    Page:   [dict get $ctx PW]×[dict get $ctx PH] pt"
    puts "    Margin: [dict get $ctx margin_mm] mm"
    
    # ========================================================================
    # STEP 2: Create PDF Object
    # ========================================================================
    
    set pdf [pdf4tcl::pdf4tcl create %AUTO% \
        -paper [dict get $ctx paper] \
        -orient [dict get $ctx orient] \
        -unit p]
    
    # -orient true: Y=0 is at the TOP, Y grows DOWNWARDS
    # -unit p:       Alle Koordinaten in Points (1/72 inch)
    
    puts "  PDF object created"
    
    # ========================================================================
    # STEP 3: Start Page
    # ========================================================================
    
    $pdf startPage
    
    # Get safe area from context
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    
    # ========================================================================
    # DEMO CODE BEGINS HERE
    # ========================================================================
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 04: Lines and boxes" -x $sx -y $sy
    
    # --- Einfache Linien ---
    set y [expr {$sy + 40}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "1. Plain lines:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 10 Helvetica
    $pdf text "Horizontal line (1pt):" -x $sx -y $y
    
    set y [expr {$y + 15}]
    $pdf setLineWidth 1
    $pdf line $sx $y [expr {$sx + 200}] $y
    
    set y [expr {$y + 30}]
    $pdf text "Vertical line:" -x $sx -y $y
    set line_x [expr {$sx + 100}]
    $pdf line $line_x [expr {$y + 10}] $line_x [expr {$y + 60}]
    
    set y [expr {$y + 80}]
    $pdf text "Diagonal line:" -x $sx -y $y
    set y [expr {$y + 10}]
    $pdf line $sx $y [expr {$sx + 80}] [expr {$y + 40}]
    
    # --- line widths ---
    set y [expr {$y + 70}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "2. Line widths:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 10 Helvetica
    
    set widths {0.5 1 2 3 5}
    foreach width $widths {
        $pdf text "${width}pt:" -x $sx -y $y
        $pdf setLineWidth $width
        $pdf line [expr {$sx + 50}] $y [expr {$sx + 200}] $y
        set y [expr {$y + 15 + $width}]
    }
    
    # --- Rechtecke ---
    set y [expr {$y + 30}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "3. Rectangles:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 10 Helvetica
    
    # Rechteck nur Rahmen
    $pdf text "Outline only (1pt):" -x $sx -y $y
    set box_y [expr {$y + 15}]
    $pdf setLineWidth 1
    $pdf rectangle $sx $box_y 100 50
    
    # filled rectangle, light grey
    $pdf text "Filled (light grey):" -x [expr {$sx + 120}] -y $y
    $pdf setFillColor 0.9 0.9 0.9  ;# Hellgrau
    $pdf rectangle [expr {$sx + 120}] $box_y 100 50 -filled 1
    $pdf setFillColor 0.0 0.0 0.0  ;# back to black
    
    # rectangle with an outline and a fill
    $pdf text "Outline and fill:" -x [expr {$sx + 240}] -y $y
    $pdf setFillColor 0.8 0.9 1.0  ;# Hellblau
    $pdf rectangle [expr {$sx + 240}] $box_y 100 50 -filled 1
    $pdf setFillColor 0.0 0.0 0.0
    $pdf setLineWidth 2
    $pdf setStrokeColor 0.0 0.0 1.0  ;# Blauer Rahmen
    $pdf rectangle [expr {$sx + 240}] $box_y 100 50
    $pdf setStrokeColor 0.0 0.0 0.0  ;# back to black
    
    set y [expr {$box_y + 80}]
    
    # --- Farbige Formen ---
    $pdf setFont 12 Helvetica-Bold
    $pdf text "4. Farbige Formen:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # Rote Box
    $pdf setFillColor 1.0 0.8 0.8  ;# Hellrot
    $pdf rectangle $sx $y 60 40 -filled 1
    $pdf setFillColor 1.0 0.0 0.0  ;# Rot
    $pdf setFont 10 Helvetica-Bold
    $pdf text "Red" -x [expr {$sx + 15}] -y [expr {$y + 17}]
    
    # green box
    $pdf setFillColor 0.8 1.0 0.8  ;# light green
    $pdf rectangle [expr {$sx + 80}] $y 60 40 -filled 1
    $pdf setFillColor 0.0 0.7 0.0  ;# green
    $pdf text "Green" -x [expr {$sx + 90}] -y [expr {$y + 17}]
    
    # Blaue Box
    $pdf setFillColor 0.8 0.8 1.0  ;# Hellblau
    $pdf rectangle [expr {$sx + 160}] $y 60 40 -filled 1
    $pdf setFillColor 0.0 0.0 1.0  ;# Blau
    $pdf text "Blue" -x [expr {$sx + 168}] -y [expr {$y + 17}]
    
    $pdf setFillColor 0.0 0.0 0.0  ;# back to black
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$y + 70}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Encoding-Test:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 11 Helvetica
    $pdf text "German umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df" -x $sx -y $y
    
    set y [expr {$y + 20}]
    $pdf text "Sonderzeichen: €£¥©®™" -x $sx -y $y
    
    # --- Komplexes Beispiel: Box mit Text ---
    set y [expr {$y + 40}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "5. Kombiniert - Box mit Text:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # outer frame, thick, blue
    #
    # Der Kasten stand fest am aufgelaufenen y und ragte damit unter den
    # Blattrand -- gemessen von y=-31 bis 49. Passt er nicht mehr, wird
    # er nach oben geschoben, statt hinauszulaufen.
    set box_x $sx
    set box_w 400
    set box_h 80
    set box_y $y
    set unten [expr {$sy + $sh}]
    if {$box_y + $box_h > $unten} {
        set box_y [expr {$unten - $box_h}]
    }
    
    $pdf setLineWidth 3
    $pdf setStrokeColor 0.2 0.4 0.8  ;# Dunkelblau
    $pdf rectangle $box_x $box_y $box_w $box_h
    
    # Hintergrund (hellblau)
    $pdf setFillColor 0.95 0.97 1.0  ;# Sehr hellblau
    $pdf rectangle [expr {$box_x + 3}] [expr {$box_y + 3}] [expr {$box_w - 6}] [expr {$box_h - 6}] -filled 1
    
    # Text in Box
    $pdf setFillColor 0.0 0.0 0.0
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Informations-Box" -x [expr {$box_x + 15}] -y [expr {$box_y + 20}]
    
    $pdf setFont 10 Helvetica
    $pdf text "Diese Box kombiniert Rahmen, Hintergrund und Text." -x [expr {$box_x + 15}] -y [expr {$box_y + 40}]
    $pdf text "Umlauts work too: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x [expr {$box_x + 15}] -y [expr {$box_y + 55}]
    
    # reset the colours
    $pdf setFillColor 0.0 0.0 0.0
    $pdf setStrokeColor 0.0 0.0 0.0
    $pdf setLineWidth 1
    
    # --- Debug-Grid (nur wenn PDF4TCL_DEBUG=1) ---
    pdf4tcllib::page::grid $pdf 50
    
    # --- Orientation-Legend (immer) ---
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    # ========================================================================
    # DEMO CODE ENDS HERE
    # ========================================================================
    
    # ========================================================================
    # STEP 4: Finish & Save
    # ========================================================================
    
    $pdf endPage
    $pdf write -file $output_file
    catch {$pdf destroy}
    
    puts "✅ Demo $demo_num complete"
    
    # ========================================================================
    # STEP 5: Validate Output
    # ========================================================================
    
    set validation [pdf4tcllib::validate_pdf $output_file]
    
    if {[dict get $validation valid]} {
        puts "   ✓ Valid PDF"
        puts "   ✓ Size: [dict get $validation size] bytes"
    } else {
        error "Invalid PDF: [dict get $validation error]"
    }
    
    return $output_file
}

# ============================================================================
# Main Execution
# ============================================================================

if {[catch {demo_main} result]} {
    puts stderr "❌ ERROR in Demo $demo_num: $result"
    puts stderr $::errorInfo
    exit 1
}

puts "📄 Output: $result"
puts ""
puts "🎉 Demo $demo_num erfolgreich!"
puts ""
puts "Zum Öffnen:"
puts "  xdg-open $result"
puts "  # oder"
puts "  evince $result"
puts ""

exit 0
