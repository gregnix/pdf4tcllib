#!/usr/bin/env tclsh
# ============================================================================
# Demo 06: Type sizes and families
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
#     tclsh 06_font_sizes.tcl
# ============================================================================
# What this shows:
#   - different type sizes verwenden
#   - Font-Styles anwenden (Bold, Oblique)
#   - Schriftarten kombinieren
#   - encoding at different sizes
#
# Features:
#   - sizes from 6pt to 48pt
#   - Helvetica-Familie (Normal, Bold, Oblique, BoldOblique)
#   - Times und Courier Beispiele
#   - an encoding test at several sizes
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

set demo_num 6
set demo_name "font_sizes"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Type sizes and families"
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
    $pdf text "Demo 06: Type sizes and families" -x $sx -y $sy
    
    # --- type sizes ---
    set y [expr {$sy + 40}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "1. Type sizes, small to large:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # sizes, with umlauts to check the encoding
    set sizes {6 8 10 12 14 16 18 24 36 48}
    
    foreach size $sizes {
        $pdf setFont $size Helvetica
        $pdf text "Size ${size}pt - \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df" -x $sx -y $y
        set y [expr {$y + $size + 5}]
    }
    
    # --- Verschiedene Schriftstile (Helvetica) ---
    set y [expr {$y + 20}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. The Helvetica family:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # Normal
    $pdf setFont 12 Helvetica
    $pdf text "Helvetica Normal - The quick brown fox jumps over the lazy dog" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Bold
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Helvetica Bold - The quick brown fox jumps over the lazy dog" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Oblique (NICHT Italic!)
    $pdf setFont 12 Helvetica-Oblique
    $pdf text "Helvetica Oblique - The quick brown fox jumps over the lazy dog" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # BoldOblique
    $pdf setFont 12 Helvetica-BoldOblique
    $pdf text "Helvetica BoldOblique - The quick brown fox jumps over the lazy dog" -x $sx -y $y
    
    # --- Times-Familie ---
    set y [expr {$y + 35}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "3. The Times family:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # Times-Roman
    $pdf setFont 12 Times-Roman
    $pdf text "Times-Roman - a serif face with \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Times-Bold
    $pdf setFont 12 Times-Bold
    $pdf text "Times-Bold - bold serif with \u20ac\u00a3\u00a5" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Times-Italic -- Times calls it "Italic", not "Oblique"
    $pdf setFont 12 Times-Italic
    $pdf text "Times-Italic - italic serif" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Times-BoldItalic
    $pdf setFont 12 Times-BoldItalic
    $pdf text "Times-BoldItalic - bold and italic" -x $sx -y $y
    
    # --- Courier-Familie ---
    set y [expr {$y + 35}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "4. The Courier family (monospace):" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # Courier
    $pdf setFont 12 Courier
    $pdf text "Courier Normal - monospace for code: if (x > 0) {}" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Courier-Bold
    $pdf setFont 12 Courier-Bold
    $pdf text "Courier Bold - Fette Monospace: def function():" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Courier-Oblique (NICHT Italic!)
    $pdf setFont 12 Courier-Oblique
    $pdf text "Courier Oblique - slanted monospace: // comment" -x $sx -y $y
    
    # --- sizes compared ---
    set y [expr {$y + 40}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "5. Sizes compared, centred:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    set center_x [expr {[dict get $ctx PW] / 2}]
    
    $pdf setFont 8 Helvetica
    $pdf text "Klein (8pt)" -x $center_x -y $y -align center
    
    set y [expr {$y + 25}]
    $pdf setFont 14 Helvetica
    $pdf text "Normal (14pt)" -x $center_x -y $y -align center
    
    set y [expr {$y + 35}]
    $pdf setFont 24 Helvetica-Bold
    $pdf text "Large (24pt)" -x $center_x -y $y -align center
    
    set y [expr {$y + 50}]
    $pdf setFont 36 Helvetica-Bold
    $pdf text "Very large (36pt)" -x $center_x -y $y -align center
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$y + 70}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Encoding test at several sizes:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    set test_sizes {8 10 12 14 18}
    foreach size $test_sizes {
        $pdf setFont $size Helvetica
        $pdf text "${size}pt: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac\u00a3\u00a5 \u00a9\u00ae\u2122" -x $sx -y $y
        set y [expr {$y + $size + 8}]
    }
    
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
