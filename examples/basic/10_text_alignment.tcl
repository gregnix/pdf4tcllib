#!/usr/bin/env tclsh
# ============================================================================
# Demo 10: Text-Alignment
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 10_text_alignment.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 10_text_alignment.tcl
# ============================================================================
# Lernziele:
#   - Textausrichtung (links, rechts, zentriert)
#   - -align Parameter verwenden
#   - Ausrichtung mit verschiedenen Schriftgrößen
#   - Referenzlinien für visuelle Kontrolle
#
# Features:
#   - Linksbündig (Standard)
#   - Rechtsbündig
#   - Zentriert
#   - Mit verschiedenen Schriftgrößen
#
# Encoding-Test: äöüÄÖÜß€
# ============================================================================

# --- Setup ---
set script_dir [file dirname [file normalize [info script]]]

# Load Helper Library

# Require pdf4tcl 0.9.4.11+
if {[catch {set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl} err]} {
    puts stderr "❌ ERROR: pdf4tcl 0.9.4.11+ required!"
    puts stderr "   Your version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl]"
    puts stderr "   Update: See SPEC.lock for installation"
    exit 1
}

# --- Configuration ---
set output_dir [file join $scriptDir pdf]
file mkdir $output_dir

set demo_num 10
set demo_name "text_alignment"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Text-Alignment"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
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
    
    # -orient true:  Y=0 ist OBEN, Y wächst nach UNTEN
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
    set pw [dict get $ctx PW]
    set ph [dict get $ctx PH]
    
    # ========================================================================
    # DEMO CODE BEGINS HERE
    # ========================================================================
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 10: Text-Alignment" -x $sx -y $sy
    
    # --- Referenzlinien (gestrichelt) ---
    set center_x [expr {$pw / 2}]
    set right_x [expr {$pw - $sx}]
    
    $pdf gsave
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.7 0.7 0.7
    
    # Linke Linie (Margin)
    $pdf line $sx [expr {$sy + 30}] $sx [expr {$sy + 600}]
    
    # Mittlere Linie
    $pdf line $center_x [expr {$sy + 30}] $center_x [expr {$sy + 600}]
    
    # Rechte Linie (Margin)
    $pdf line $right_x [expr {$sy + 30}] $right_x [expr {$sy + 600}]
    
    $pdf grestore
    
    # --- 1. Linksbündig (Standard) ---
    set y [expr {$sy + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "1. Linksbündig (Standard):" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    $pdf text "Linksbündiger Text (Standard)" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Dieser Text ist linksbündig ausgerichtet." -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Mit Umlauten: äöüÄÖÜß und Euro: €" -x $sx -y $y
    
    # --- 2. Zentriert ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. Zentriert:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    $pdf text "Zentrierter Text" -x $center_x -y $y -align center
    
    set y [expr {$y + 25}]
    $pdf text "Dieser Text ist zentriert." -x $center_x -y $y -align center
    
    set y [expr {$y + 25}]
    $pdf text "Mit Umlauten: äöüÄÖÜß €" -x $center_x -y $y -align center
    
    # --- 3. Rechtsbündig ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "3. Rechtsbündig:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    $pdf text "Rechtsbündiger Text" -x $right_x -y $y -align right
    
    set y [expr {$y + 25}]
    $pdf text "Dieser Text ist rechtsbündig." -x $right_x -y $y -align right
    
    set y [expr {$y + 25}]
    $pdf text "Mit Umlauten: äöüÄÖÜß €" -x $right_x -y $y -align right
    
    # --- 4. Verschiedene Schriftgrößen (zentriert) ---
    set y [expr {$y + 60}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "4. Verschiedene Größen (zentriert):" -x $sx -y $y
    
    set y [expr {$y + 35}]
    
    $pdf setFont 8 Helvetica
    $pdf text "Klein (8pt) - zentriert" -x $center_x -y $y -align center
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    $pdf text "Normal (12pt) - zentriert" -x $center_x -y $y -align center
    
    set y [expr {$y + 30}]
    $pdf setFont 16 Helvetica-Bold
    $pdf text "Groß (16pt) - zentriert" -x $center_x -y $y -align center
    
    set y [expr {$y + 40}]
    $pdf setFont 24 Helvetica-Bold
    $pdf text "Sehr Groß (24pt)" -x $center_x -y $y -align center
    
    # --- 5. Kombiniert: Links, Mitte, Rechts ---
    set y [expr {$y + 70}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "5. Kombiniert (gleiche Zeile):" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 11 Helvetica
    
    # Alle drei Ausrichtungen in einer Zeile
    $pdf text "Links" -x $sx -y $y
    $pdf text "Mitte" -x $center_x -y $y -align center
    $pdf text "Rechts" -x $right_x -y $y -align right
    
    set y [expr {$y + 25}]
    $pdf text "äöü" -x $sx -y $y
    $pdf text "ÄÖÜ" -x $center_x -y $y -align center
    $pdf text "ß€" -x $right_x -y $y -align right
    
    # --- 6. Längere Texte ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "6. Längere Texte:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 10 Helvetica
    
    set long_text "Dies ist ein längerer linksbündiger Text mit Umlauten: äöüÄÖÜß"
    $pdf text $long_text -x $sx -y $y
    
    set y [expr {$y + 20}]
    set long_text2 "Dies ist ein längerer zentrierter Text mit Euro: 100€"
    $pdf text $long_text2 -x $center_x -y $y -align center
    
    set y [expr {$y + 20}]
    set long_text3 "Dies ist ein längerer rechtsbündiger Text"
    $pdf text $long_text3 -x $right_x -y $y -align right
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$y + 50}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Encoding-Test:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 11 Helvetica
    
    # Links
    $pdf text "Links: äöüÄÖÜß €£¥" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Zentriert
    $pdf text "Zentriert: äöüÄÖÜß €£¥" -x $center_x -y $y -align center
    
    set y [expr {$y + 20}]
    # Rechts
    $pdf text "Rechts: äöüÄÖÜß €£¥" -x $right_x -y $y -align right
    
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
