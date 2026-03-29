#!/usr/bin/env tclsh
# ============================================================================
# Demo 03: Text mit Farben
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 03_colors.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 03_colors.tcl
# ============================================================================
# Lernziele:
#   - Text in verschiedenen Farben darstellen
#   - RGB-Farbmodell verstehen (0.0 - 1.0)
#   - Graustufen verwenden
#   - Farben zurücksetzen
#
# Features:
#   - Primärfarben (Rot, Grün, Blau)
#   - Sekundärfarben (Cyan, Magenta, Gelb)
#   - Graustufen
#   - Encoding-Test in verschiedenen Farben
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

set demo_num 3
set demo_name "colors"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Text mit Farben"
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
    $pdf setFillColor 0.0 0.0 0.0  ;# Schwarz
    $pdf text "Demo 03: Text mit Farben" -x $sx -y $sy
    
    # --- Primärfarben (RGB) ---
    set y [expr {$sy + 40}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf setFillColor 0.0 0.0 0.0
    $pdf text "Primärfarben (RGB):" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    # Rot
    $pdf setFillColor 1.0 0.0 0.0  ;# RGB: R=1.0, G=0.0, B=0.0
    $pdf text "Roter Text - RGB(1.0, 0.0, 0.0)" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # Grün
    $pdf setFillColor 0.0 1.0 0.0  ;# RGB: R=0.0, G=1.0, B=0.0
    $pdf text "Grüner Text - RGB(0.0, 1.0, 0.0)" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # Blau
    $pdf setFillColor 0.0 0.0 1.0  ;# RGB: R=0.0, G=0.0, B=1.0
    $pdf text "Blauer Text - RGB(0.0, 0.0, 1.0)" -x $sx -y $y
    
    # --- Sekundärfarben (CMY) ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf setFillColor 0.0 0.0 0.0
    $pdf text "Sekundärfarben (CMY):" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    # Cyan
    $pdf setFillColor 0.0 1.0 1.0  ;# RGB: R=0.0, G=1.0, B=1.0
    $pdf text "Cyan - RGB(0.0, 1.0, 1.0)" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # Magenta
    $pdf setFillColor 1.0 0.0 1.0  ;# RGB: R=1.0, G=0.0, B=1.0
    $pdf text "Magenta - RGB(1.0, 0.0, 1.0)" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # Gelb
    $pdf setFillColor 1.0 1.0 0.0  ;# RGB: R=1.0, G=1.0, B=0.0
    $pdf text "Gelb - RGB(1.0, 1.0, 0.0)" -x $sx -y $y
    
    # --- Graustufen ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf setFillColor 0.0 0.0 0.0
    $pdf text "Graustufen:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    # Verschiedene Graustufen
    set gray_levels {0.0 0.2 0.4 0.6 0.8 1.0}
    set gray_names {"Schwarz (0%)" "Dunkelgrau (20%)" "Grau (40%)" "Grau (60%)" "Hellgrau (80%)" "Weiß (100%)"}
    
    for {set i 0} {$i < [llength $gray_levels]} {incr i} {
        set level [lindex $gray_levels $i]
        set name [lindex $gray_names $i]
        
        # Für Weiß: Hintergrund zeichnen, damit man es sieht
        if {$level == 1.0} {
            $pdf setFillColor 0.9 0.9 0.9  ;# Hellgrauer Hintergrund
            $pdf rectangle $sx $y 350 20 -filled 1
        }
        
        $pdf setFillColor $level $level $level
        $pdf text "$name - RGB($level, $level, $level)" -x [expr {$sx + 5}] -y [expr {$y + 5}]
        
        set y [expr {$y + 25}]
    }
    
    # --- PFLICHT: Encoding-Test (in Farbe!) ---
    set y [expr {$y + 40}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf setFillColor 0.0 0.0 0.0
    $pdf text "Encoding-Test in Farbe:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    # Rot
    $pdf setFillColor 1.0 0.0 0.0
    $pdf text "Rot: äöüÄÖÜß €" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # Grün
    $pdf setFillColor 0.0 0.7 0.0
    $pdf text "Grün: àèìòù ÀÈÌÒÙ" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # Blau
    $pdf setFillColor 0.0 0.0 1.0
    $pdf text "Blau: ©®™ £¥¢" -x $sx -y $y
    
    # --- Farbe zurücksetzen ---
    $pdf setFillColor 0.0 0.0 0.0  ;# Zurück zu Schwarz
    
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
