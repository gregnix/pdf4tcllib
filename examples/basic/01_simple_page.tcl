#!/usr/bin/env tclsh
# ============================================================================
# Demo 01: A simple page
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
#     tclsh 01_simple_page.tcl
# ============================================================================
# What this shows:
#   - create a PDF with the pdf4tcl 0.9.4.11 API
#   - set the defaults explicitly (-orient, -paper, -unit)
#   - write text on a page
#   - Encoding test (aeoeue AEOEUE ss, euro sign)
#
# Features:
#   - A4 portrait
#   - a title and several lines of text
#   - a UTF-8 encoding test
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

set demo_num 01
set demo_name "simple_page"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: A simple page"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.6
package require pdf4tcl]"
    puts "  Output: $output_file"
    
    # ========================================================================
    # STEP 1: Create Page Context
    # ========================================================================
    # PageContext berechnet alle Werte einmal (keine Magic Numbers!)
    
    set ctx [pdf4tcllib::page::context a4 20 true]
    
    puts "  Context:"
    puts "    Paper:  [dict get $ctx paper]"
    puts "    Orient: [dict get $ctx orient] (y-origin [expr {[dict get $ctx orient] ? "top" : "bottom"}])"
    puts "    Page:   [dict get $ctx PW]×[dict get $ctx PH] pt"
    puts "    Margin: [dict get $ctx margin_mm] mm"
    
    # ========================================================================
    # STEP 2: Create PDF Object
    # ========================================================================
    # WICHTIG: Defaults EXPLIZIT setzen (STYLE-GUIDELINES.md)
    
    set pdf [pdf4tcl::pdf4tcl create %AUTO% \
        -paper [dict get $ctx paper] \
        -orient [dict get $ctx orient] \
        -unit p]
    
    # -orient true: Y=0 is at the TOP, Y grows DOWNWARDS
    # -unit p:       Alle Koordinaten in Points (1/72 inch) (STYLE-GUIDELINES Regel #2)
    
    puts "  PDF object created"
    
    # ========================================================================
    # STEP 3: Start Page
    # ========================================================================
    
    $pdf startPage
    
    # ========================================================================
    # DEMO CODE BEGINS HERE
    # ========================================================================
    
    # Get safe area from context (keine Magic Numbers!)
    set sx [dict get $ctx SX]  ;# Safe X (20mm margin = ~56.7pt)
    set sy [dict get $ctx SY]  ;# Safe Y (20mm margin = ~56.7pt)
    set sw [dict get $ctx SW]  ;# Safe Width
    set sh [dict get $ctx SH]  ;# Safe Height
    
    # --- Titel ---
    $pdf setFont 24 Helvetica-Bold
    $pdf text "Demo 01: A simple page" -x $sx -y $sy
    
    # --- Beschreibung ---
    set y [expr {$sy + 40}]  ;# 40pt unter Titel
    
    $pdf setFont 12 Helvetica
    $pdf text "This is a simple PDF page." -x $sx -y $y
    
    set y [expr {$y + 20}]  ;# 20pt Abstand
    $pdf text "Made with pdf4tcl 0.9.4.11" -x $sx -y $y
    
    set y [expr {$y + 20}]
    $pdf text "Paper: A4 (595 x 842 pt)" -x $sx -y $y
    
    set y [expr {$y + 20}]
    $pdf text "Orientation: Y=0 at the top, Y grows downwards" -x $sx -y $y
    
    # --- Encoding-Test (STYLE-GUIDELINES Regel #3: PFLICHT!) ---
    set y [expr {$y + 40}]  ;# Extra Abstand vor Encoding-Test
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "UTF-8 Encoding-Test:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    $pdf text "Umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df" -x $sx -y $y
    
    set y [expr {$y + 20}]
    $pdf text "Sonderzeichen: € £ ¥ © ®" -x $sx -y $y
    
    # --- Info-Box ---
    set y [expr {$y + 60}]
    
    # Rahmen zeichnen
    set box_x $sx
    set box_y $y
    set box_w [expr {$sw / 2}]  ;# Halbe Breite der Safe Area
    set box_h 80  ;# pt
    
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.3 0.3 0.3
    $pdf rectangle $box_x $box_y $box_w $box_h
    
    # Text in Box
    set text_x [expr {$box_x + 10}]  ;# 10pt Padding
    set text_y [expr {$box_y + 20}]
    
    $pdf setFont 10 Helvetica
    $pdf text "Diese Demo zeigt:" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 15}]
    $pdf text "• PDF-Erstellung mit expliziten Defaults" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 15}]
    $pdf text "\u2022 PageContext for coordinates" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 15}]
    $pdf text "• UTF-8 Encoding-Support" -x $text_x -y $text_y
    
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
puts "🎉 Demo 01 erfolgreich!"
puts ""
puts "Zum Öffnen:"
puts "  xdg-open $result"
puts "  # oder"
puts "  evince $result"
puts ""
puts "With the debug grid:"
puts "  PDF4TCL_DEBUG=1 tclsh [info script]"

exit 0
