#!/usr/bin/env tclsh
# ============================================================================
# Demo 31: Vertikaler Text
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 31_vertical_text.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 31_vertical_text.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 31  (ohne führende 0)
#   FALSCH:  set demo_num 031 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - Vertikalen Text erstellen
#   - Zeichen untereinander platzieren
#   - Von oben nach unten vs. unten nach oben
#   - Vergleich mit 90° rotiertem Text
#
# Features:
#   - Echte vertikale Schrift (Zeichen unter Zeichen)
#   - Verschiedene Richtungen (top-down, bottom-up)
#   - Vergleich mit -angle 90 (rotierter Text)
#   - Asiatische Schrift simulieren
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

# WICHTIG: demo_num OHNE führende 0 (wegen Tcl-Oktal!)
set demo_num 31
set demo_name "vertical_text"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Helper: Draw Vertical Text (Top-Down)
# ============================================================================

proc draw_vertical_text_down {pdf text x y font_size spacing} {
    set current_y $y
    foreach char [split $text ""] {
        # Zeichen zeichnen
        $pdf text $char -x $x -y $current_y
        
        # Nächste Position
        set current_y [expr {$current_y + $font_size + $spacing}]
    }
    return $current_y
}

# ============================================================================
# Helper: Draw Vertical Text (Bottom-Up)
# ============================================================================

proc draw_vertical_text_up {pdf text x y font_size spacing} {
    set current_y $y
    foreach char [split $text ""] {
        # Zeichen zeichnen
        $pdf text $char -x $x -y $current_y
        
        # Nächste Position (nach oben!)
        set current_y [expr {$current_y - ($font_size + $spacing)}]
    }
    return $current_y
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Vertikaler Text"
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
    
    puts "  PDF object created"
    
    # ========================================================================
    # STEP 3: Start Page
    # ========================================================================
    
    $pdf startPage
    
    # ========================================================================
    # DEMO CODE BEGINS HERE
    # ========================================================================
    
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 31: Vertikaler Text" -x $sx -y $sy
    
    # --- Encoding-Test ---
    set y [expr {$sy + 30}]
    $pdf setFont 10 Helvetica
    $pdf text "Encoding-Test: äöüÄÖÜß €" -x $sx -y $y
    
    # ========================================================================
    # Column 1: Vertikaler Text (Top-Down)
    # ========================================================================
    
    set col1_x [expr {$sx + 50}]
    set start_y [expr {$sy + 80}]
    
    # Label
    $pdf setFont 12 Helvetica-Bold
    $pdf text "1. Top-Down" -x [expr {$col1_x - 40}] -y [expr {$start_y - 15}]
    
    # Arrow down
    $pdf gsave
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf arrow [expr {$col1_x - 10}] [expr {$start_y - 10}] [expr {$col1_x - 10}] [expr {$start_y + 40}] 5
    $pdf grestore
    
    # Vertikaler Text
    $pdf setFont 14 Helvetica
    set sample_text "VERTICAL"
    draw_vertical_text_down $pdf $sample_text $col1_x $start_y 14 2
    
    # Beispiel 2
    set col1b_x [expr {$col1_x + 40}]
    $pdf setFont 12 Courier
    draw_vertical_text_down $pdf "Text" $col1b_x $start_y 12 4
    
    # ========================================================================
    # Column 2: Vertikaler Text (Bottom-Up)
    # ========================================================================
    
    set col2_x [expr {$sx + 200}]
    set start_y2 [expr {$sy + 250}]
    
    # Label
    $pdf setFont 12 Helvetica-Bold
    $pdf text "2. Bottom-Up" -x [expr {$col2_x - 50}] -y [expr {$start_y2 + 15}]
    
    # Arrow up
    $pdf gsave
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf arrow [expr {$col2_x - 10}] [expr {$start_y2 + 10}] [expr {$col2_x - 10}] [expr {$start_y2 - 40}] 5
    $pdf grestore
    
    # Vertikaler Text (von unten nach oben)
    $pdf setFont 14 Helvetica
    draw_vertical_text_up $pdf $sample_text $col2_x $start_y2 14 2
    
    # Beispiel 2
    set col2b_x [expr {$col2_x + 40}]
    $pdf setFont 12 Courier
    draw_vertical_text_up $pdf "Text" $col2b_x $start_y2 12 4
    
    # ========================================================================
    # Column 3: Rotierter Text (-angle 90)
    # ========================================================================
    
    set col3_x [expr {$sx + 350}]
    set col3_y [expr {$sy + 150}]
    
    # Label
    $pdf setFont 12 Helvetica-Bold
    $pdf text "3. Rotiert (90°)" -x [expr {$col3_x - 50}] -y [expr {$sy + 65}]
    
    # Rotierter Text
    $pdf setFont 14 Helvetica
    $pdf text $sample_text -x $col3_x -y $col3_y -angle 90
    
    # Beispiel 2
    set col3b_x [expr {$col3_x + 40}]
    $pdf setFont 12 Courier
    $pdf text "Text" -x $col3b_x -y $col3_y -angle 90
    
    # ========================================================================
    # Column 4: Rotierter Text (-angle 270)
    # ========================================================================
    
    set col4_x [expr {$sx + 480}]
    set col4_y [expr {$sy + 250}]
    
    # Label
    $pdf setFont 12 Helvetica-Bold
    $pdf text "4. Rotiert (270°)" -x [expr {$col4_x - 60}] -y [expr {$start_y2 + 15}]
    
    # Rotierter Text
    $pdf setFont 14 Helvetica
    $pdf text $sample_text -x $col4_x -y $col4_y -angle 270
    
    # Beispiel 2
    set col4b_x [expr {$col4_x + 40}]
    $pdf setFont 12 Courier
    $pdf text "Text" -x $col4b_x -y $col4_y -angle 270
    
    # ========================================================================
    # Explanation Box
    # ========================================================================
    
    set box_y [expr {$sy + 320}]
    
    $pdf setFont 11 Helvetica-Bold
    $pdf text "Unterschiede:" -x $sx -y $box_y
    
    set box_y [expr {$box_y + 20}]
    $pdf setFont 9 Helvetica
    
    set explanations {
        "Vertikaler Text (1+2):"
        "  * Jedes Zeichen separat platziert"
        "  * Zeichen bleiben horizontal lesbar"
        "  * Wie asiatische Schrift (japanisch/chinesisch)"
        "  * Flexibel im Spacing"
        ""
        "Rotierter Text (3+4):"
        "  * Ganzer String wird rotiert"
        "  * Zeichen sind seitlich"
        "  * Standard -angle Parameter"
        "  * Einfacher aber weniger flexibel"
    }
    
    foreach line $explanations {
        if {$line eq ""} {
            set box_y [expr {$box_y + 6}]
        } else {
            $pdf text $line -x $sx -y $box_y
            set box_y [expr {$box_y + 12}]
        }
    }
    
    # ========================================================================
    # Code Example
    # ========================================================================
    
    set box_y [expr {$box_y + 15}]
    $pdf setFont 10 Helvetica-Bold
    $pdf text "Code-Beispiel (Top-Down):" -x $sx -y $box_y
    
    set box_y [expr {$box_y + 15}]
    $pdf setFont 8 Courier
    
    set code_lines {
        "proc draw_vertical_down \{pdf text x y size spacing\} \{"
        "    set current_y \$y"
        "    foreach char \[split \$text \"\"\] \{"
        "        \$pdf text \$char -x \$x -y \$current_y"
        "        set current_y \[expr \{\$current_y + \$size + \$spacing\}\]"
        "    \}"
        "\}"
    }
    
    foreach line $code_lines {
        $pdf text $line -x [expr {$sx + 10}] -y $box_y
        set box_y [expr {$box_y + 10}]
    }
    
    # --- Orientation Legend ---
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    # ========================================================================
    # STEP 4: Finish
    # ========================================================================
    
    $pdf endPage
    $pdf write -file $output_file
    $pdf destroy
    
    puts "✅ Demo $demo_num complete"
    
    # ========================================================================
    # Validate Output
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
puts "TIPP: Vergleichen Sie die 4 verschiedenen Methoden:"
puts "      1. Top-Down (Zeichen unter Zeichen)"
puts "      2. Bottom-Up (Zeichen über Zeichen)"
puts "      3+4. Rotierter Text (-angle 90/270)"

exit 0
