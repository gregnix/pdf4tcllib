#!/usr/bin/env tclsh
# ============================================================================
# Demo 10: Text alignment
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
#     tclsh 10_text_alignment.tcl
# ============================================================================
# What this shows:
#   - Textausrichtung (links, rechts, zentriert)
#   - -align Parameter verwenden
#   - alignment at different type sizes
#   - reference lines to check against
#
# Features:
#   - left aligned (default)
#   - right aligned
#   - Zentriert
#   - at different type sizes
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
    set pw [dict get $ctx PW]
    set ph [dict get $ctx PH]
    
    # ========================================================================
    # DEMO CODE BEGINS HERE
    # ========================================================================
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 10: Text alignment" -x $sx -y $sy
    
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
    
    # --- 1. left aligned (default) ---
    set y [expr {$sy + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "1. Left aligned (default):" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    $pdf text "Left aligned text (default)" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "This text is aligned to the left." -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "With umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df and a euro sign: \u20ac" -x $sx -y $y
    
    # --- 2. centred ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. Centred:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    $pdf text "Centred text" -x $center_x -y $y -align center
    
    set y [expr {$y + 25}]
    $pdf text "This text is centred." -x $center_x -y $y -align center
    
    set y [expr {$y + 25}]
    $pdf text "With umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $center_x -y $y -align center
    
    # --- 3. right aligned ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "3. Right aligned:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    $pdf text "Right aligned text" -x $right_x -y $y -align right
    
    set y [expr {$y + 25}]
    $pdf text "This text is aligned to the right." -x $right_x -y $y -align right
    
    set y [expr {$y + 25}]
    $pdf text "With umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $right_x -y $y -align right
    
    # --- 4. different type sizes, centred ---
    set y [expr {$y + 60}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "4. Different sizes, centred:" -x $sx -y $y
    
    set y [expr {$y + 35}]
    
    $pdf setFont 8 Helvetica
    $pdf text "Small (8pt) - centred" -x $center_x -y $y -align center
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    $pdf text "Normal (12pt) - centred" -x $center_x -y $y -align center
    
    set y [expr {$y + 30}]
    $pdf setFont 16 Helvetica-Bold
    $pdf text "Large (16pt) - centred" -x $center_x -y $y -align center
    
    set y [expr {$y + 40}]
    $pdf setFont 24 Helvetica-Bold
    $pdf text "Very large (24pt)" -x $center_x -y $y -align center
    
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
    $pdf text "\u00e4\u00f6\u00fc" -x $sx -y $y
    $pdf text "ÄÖÜ" -x $center_x -y $y -align center
    $pdf text "\u00df\u20ac" -x $right_x -y $y -align right
    
    # --- 6. longer lines ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "6. Longer lines:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 10 Helvetica
    
    set long_text "A longer left aligned line with umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df"
    $pdf text $long_text -x $sx -y $y
    
    set y [expr {$y + 20}]
    set long_text2 "A longer centred line with a euro sign: 100\u20ac"
    $pdf text $long_text2 -x $center_x -y $y -align center
    
    set y [expr {$y + 20}]
    set long_text3 "A longer right aligned line"
    $pdf text $long_text3 -x $right_x -y $y -align right
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$y + 50}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Encoding test:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 11 Helvetica
    
    # Links
    $pdf text "Left: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac\u00a3\u00a5" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Zentriert
    $pdf text "Centred: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac\u00a3\u00a5" -x $center_x -y $y -align center
    
    set y [expr {$y + 20}]
    # Rechts
    $pdf text "Right: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac\u00a3\u00a5" -x $right_x -y $y -align right
    
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
