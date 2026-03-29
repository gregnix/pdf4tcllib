#!/usr/bin/env tclsh
# ============================================================================
# Demo 06: Verschiedene Schriftgrößen
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 06_font_sizes.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 06_font_sizes.tcl
# ============================================================================
# Lernziele:
#   - Verschiedene Schriftgrößen verwenden
#   - Font-Styles anwenden (Bold, Oblique)
#   - Schriftarten kombinieren
#   - Encoding bei verschiedenen Größen testen
#
# Features:
#   - Größen von 6pt bis 48pt
#   - Helvetica-Familie (Normal, Bold, Oblique, BoldOblique)
#   - Times und Courier Beispiele
#   - Encoding-Test in verschiedenen Größen
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

set demo_num 6
set demo_name "font_sizes"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Verschiedene Schriftgrößen"
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
    
    # ========================================================================
    # DEMO CODE BEGINS HERE
    # ========================================================================
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 06: Verschiedene Schriftgrößen" -x $sx -y $sy
    
    # --- Verschiedene Schriftgrößen ---
    set y [expr {$sy + 40}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "1. Schriftgrößen von klein bis groß:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # Verschiedene Größen mit Umlauten testen
    set sizes {6 8 10 12 14 16 18 24 36 48}
    
    foreach size $sizes {
        $pdf setFont $size Helvetica
        $pdf text "Schriftgröße ${size}pt - äöüÄÖÜß" -x $sx -y $y
        set y [expr {$y + $size + 5}]
    }
    
    # --- Verschiedene Schriftstile (Helvetica) ---
    set y [expr {$y + 20}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. Helvetica-Familie (alle Styles):" -x $sx -y $y
    
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
    $pdf text "3. Times-Familie:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # Times-Roman
    $pdf setFont 12 Times-Roman
    $pdf text "Times-Roman - Serif-Schrift mit äöüÄÖÜß" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Times-Bold
    $pdf setFont 12 Times-Bold
    $pdf text "Times-Bold - Fette Serif-Schrift mit €£¥" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Times-Italic (Bei Times heißt es "Italic"!)
    $pdf setFont 12 Times-Italic
    $pdf text "Times-Italic - Kursive Serif-Schrift" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Times-BoldItalic
    $pdf setFont 12 Times-BoldItalic
    $pdf text "Times-BoldItalic - Fett und kursiv" -x $sx -y $y
    
    # --- Courier-Familie ---
    set y [expr {$y + 35}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "4. Courier-Familie (Monospace):" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # Courier
    $pdf setFont 12 Courier
    $pdf text "Courier Normal - Monospace für Code: if (x > 0) {}" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Courier-Bold
    $pdf setFont 12 Courier-Bold
    $pdf text "Courier Bold - Fette Monospace: def function():" -x $sx -y $y
    
    set y [expr {$y + 20}]
    # Courier-Oblique (NICHT Italic!)
    $pdf setFont 12 Courier-Oblique
    $pdf text "Courier Oblique - Schräge Monospace: // Kommentar" -x $sx -y $y
    
    # --- Schriftgrößen-Vergleich ---
    set y [expr {$y + 40}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "5. Größen-Vergleich (zentriert):" -x $sx -y $y
    
    set y [expr {$y + 30}]
    set center_x [expr {[dict get $ctx PW] / 2}]
    
    $pdf setFont 8 Helvetica
    $pdf text "Klein (8pt)" -x $center_x -y $y -align center
    
    set y [expr {$y + 25}]
    $pdf setFont 14 Helvetica
    $pdf text "Normal (14pt)" -x $center_x -y $y -align center
    
    set y [expr {$y + 35}]
    $pdf setFont 24 Helvetica-Bold
    $pdf text "Groß (24pt)" -x $center_x -y $y -align center
    
    set y [expr {$y + 50}]
    $pdf setFont 36 Helvetica-Bold
    $pdf text "Sehr Groß (36pt)" -x $center_x -y $y -align center
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$y + 70}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Encoding-Test in verschiedenen Größen:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    set test_sizes {8 10 12 14 18}
    foreach size $test_sizes {
        $pdf setFont $size Helvetica
        $pdf text "${size}pt: äöüÄÖÜß €£¥ ©®™" -x $sx -y $y
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
