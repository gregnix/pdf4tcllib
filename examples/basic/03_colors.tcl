#!/usr/bin/env tclsh
# ============================================================================
# Demo 03: Coloured text
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
#     tclsh 03_colors.tcl
# ============================================================================
# What this shows:
#   - draw text in different colours
#   - RGB-Farbmodell verstehen (0.0 - 1.0)
#   - use greys
#   - reset the colour
#
# Features:
#   - primary colours (red, green, blue)
#   - secondary colours (cyan, magenta, yellow)
#   - greys
#   - an encoding test in colour
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

set demo_num 3
set demo_name "colors"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Coloured text"
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
    $pdf setFillColor 0.0 0.0 0.0  ;# black
    $pdf text "Demo 03: Coloured text" -x $sx -y $sy
    
    # --- primary colours (RGB) ---
    set y [expr {$sy + 40}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf setFillColor 0.0 0.0 0.0
    $pdf text "Primary colours (RGB):" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    # red
    $pdf setFillColor 1.0 0.0 0.0  ;# RGB: R=1.0, G=0.0, B=0.0
    $pdf text "Red text - RGB(1.0, 0.0, 0.0)" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # green
    $pdf setFillColor 0.0 1.0 0.0  ;# RGB: R=0.0, G=1.0, B=0.0
    $pdf text "Green text - RGB(0.0, 1.0, 0.0)" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # blue
    $pdf setFillColor 0.0 0.0 1.0  ;# RGB: R=0.0, G=0.0, B=1.0
    $pdf text "Blue text - RGB(0.0, 0.0, 1.0)" -x $sx -y $y
    
    # --- secondary colours (CMY) ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf setFillColor 0.0 0.0 0.0
    $pdf text "Secondary colours (CMY):" -x $sx -y $y
    
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
    # yellow
    $pdf setFillColor 1.0 1.0 0.0  ;# RGB: R=1.0, G=1.0, B=0.0
    $pdf text "Yellow - RGB(1.0, 1.0, 0.0)" -x $sx -y $y
    
    # --- greys ---
    set y [expr {$y + 50}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf setFillColor 0.0 0.0 0.0
    $pdf text "Greys:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    # Verschiedene Graustufen
    set gray_levels {0.0 0.2 0.4 0.6 0.8 1.0}
    set gray_names {"Black (0%)" "Dark grey (20%)" "Grey (40%)" "Grey (60%)" "Light grey (80%)" "White (100%)"}
    
    for {set i 0} {$i < [llength $gray_levels]} {incr i} {
        set level [lindex $gray_levels $i]
        set name [lindex $gray_names $i]
        
        # White needs a background, or it is invisible on white paper
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
    $pdf text "Encoding test, in colour:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    # red
    $pdf setFillColor 1.0 0.0 0.0
    $pdf text "Red: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # green
    $pdf setFillColor 0.0 0.7 0.0
    $pdf text "Green: àèìòù ÀÈÌÒÙ" -x $sx -y $y
    
    set y [expr {$y + 25}]
    # blue
    $pdf setFillColor 0.0 0.0 1.0
    $pdf text "Blue: ©®™ £¥¢" -x $sx -y $y
    
    # --- reset the colour ---
    $pdf setFillColor 0.0 0.0 0.0  ;# back to black
    
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
