#!/usr/bin/env tclsh
# ============================================================================
# Demo 16: Multi-line text and leading
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
#     tclsh 16_multiline.tcl
#
# TCL OCTAL PITFALL:
#   RIGHT: set demo_num 16  (no leading zero)
#   WRONG: set demo_num 016 (octal!)
# ============================================================================
# What this shows:
#   - Mehrzeiligen Text platzieren
#   - Line-Height verstehen (Zeilenabstand)
#   - Auswirkung verschiedener Line-Heights sehen
#   - Lesbarkeit optimieren
#
# Features:
#   - Vergleich: Line-Height 1.0, 1.2, 1.5, 2.0
#   - Praktische Beispiele
#   - a helper procedure for leading
#   - what to use for readability
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

# NOTE: demo_num without a leading zero -- Tcl would read it as octal
set demo_num 16
set demo_name "multiline"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Helper: Draw Multiline Text Block
# ============================================================================

proc draw_multiline_block {pdf x y font_size line_height_factor title lines} {
    # Titel
    $pdf setFont 11 Helvetica-Bold
    $pdf text $title -x $x -y $y
    
    set y [expr {$y + 20}]
    
    # Info
    $pdf setFont 8 Helvetica
    $pdf text "Leading: ${line_height_factor}x (${font_size}pt type)" -x $x -y $y
    
    set y [expr {$y + 18}]
    
    # the text box
    set box_w 220
    set line_spacing [expr {$font_size * $line_height_factor}]
    set box_h [expr {([llength $lines] * $line_spacing) + 20}]
    
    # Box Hintergrund
    $pdf setFillColor 0.98 0.98 0.98
    $pdf rectangle $x $y $box_w $box_h -filled 1
    $pdf setFillColor 0 0 0
    
    # Box Rahmen
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf rectangle $x $y $box_w $box_h -stroke 1
    
    # Text zeichnen
    set text_x [expr {$x + 10}]
    set text_y [expr {$y + 15}]
    
    $pdf setFont $font_size Helvetica
    
    foreach line $lines {
        $pdf text $line -x $text_x -y $text_y
        set text_y [expr {$text_y + $line_spacing}]
    }
    
    # Linien zwischen Zeilen (gestrichelt, zur Visualisierung)
    if {$line_height_factor >= 1.3} {
        $pdf gsave
        $pdf setStrokeColor 0.9 0.8 0.8
        $pdf setLineWidth 0.25
        $pdf setLineDash 1 2
        
        set line_y [expr {$y + 15 + $font_size + ($line_spacing - $font_size) / 2}]
        for {set i 0} {$i < [expr {[llength $lines] - 1}]} {incr i} {
            $pdf line $text_x $line_y [expr {$x + $box_w - 10}] $line_y
            set line_y [expr {$line_y + $line_spacing}]
        }
        
        $pdf grestore
    }
    
    # Return next Y position
    return [expr {$y + $box_h + 10}]
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Multiline Text & Line-Height"
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
    
    puts "  PDF object created"
    
    # ========================================================================
    # STEP 3: Start Page
    # ========================================================================
    
    $pdf startPage
    
    # ========================================================================
    # DEMO CODE BEGINS HERE
    # ========================================================================
    
    # Get safe area from context
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 16: Multi-line text and leading" -x $sx -y $sy
    
    # --- Intro ---
    set y [expr {$sy + 35}]
    $pdf setFont 10 Helvetica
    $pdf text "Leading -- the distance between baselines -- decides how readable a block is." -x $sx -y $y
    
    # --- Encoding-Test ---
    set y [expr {$y + 20}]
    $pdf text "Encoding test: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $sx -y $y
    
    # ========================================================================
    # Beispieltext
    # ========================================================================
    
    set sample_lines {
        "Lorem ipsum dolor sit amet,"
        "consectetur adipiscing elit."
        "Sed do eiusmod tempor"
        "incididunt ut labore et"
        "dolore magna aliqua."
    }
    
    # ========================================================================
    # Leading compared
    # ========================================================================
    
    set y [expr {$y + 40}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Leading compared" -x $sx -y $y
    
    set y [expr {$y + 30}]
    
    # Zwei Spalten
    set col1_x $sx
    set col2_x [expr {$sx + 260}]
    
    set font_size 10
    
    # Spalte 1
    set y1 $y
    
    # Line-Height 1.0 (eng)
    set y1 [draw_multiline_block $pdf $col1_x $y1 $font_size 1.0 \
        "1. Line-Height 1.0 (zu eng)" $sample_lines]
    
    set y1 [expr {$y1 + 20}]
    
    # Line-Height 1.2 (Standard)
    set y1 [draw_multiline_block $pdf $col1_x $y1 $font_size 1.2 \
        "2. Line-Height 1.2 (Standard)" $sample_lines]
    
    # Spalte 2
    set y2 $y
    
    # Line-Height 1.5 (komfortabel)
    set y2 [draw_multiline_block $pdf $col2_x $y2 $font_size 1.5 \
        "3. Line-Height 1.5 (komfortabel)" $sample_lines]
    
    set y2 [expr {$y2 + 20}]
    
    # Line-Height 2.0 (sehr luftig)
    set y2 [draw_multiline_block $pdf $col2_x $y2 $font_size 2.0 \
        "4. Line-Height 2.0 (sehr luftig)" $sample_lines]
    
    # ========================================================================
    # What to use
    # ========================================================================
    
    set y [expr {max($y1, $y2) + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "What to use" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    set recommendations {
        {"Anwendung" "Line-Height" "Verwendung"}
        {"running text" "1.2 - 1.5" "the usual, reads well"}
        {"Überschriften" "1.0 - 1.2" "Kompakt, platzsparend"}
        {"long passages" "1.4 - 1.6" "less tiring"}
        {"slides" "1.5 - 2.0" "readable from a distance"}
        {"tight" "1.0" "only when space demands it"}
    }
    
    set col_widths {120 90 180}
    
    pdf4tcllib::table::simpleTable $pdf $sx $y $col_widths $recommendations \
        -zebra 1 \
        -row_height 20 \
        -font_size 9
    
    # ========================================================================
    # Example code
    # ========================================================================
    
    set y [expr {$y + [expr {[llength $recommendations] * 20}] + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Example code" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 9 Courier
    
    set code_lines {
        "# a helper for leading"
        "set font_size 12"
        "set line_height \[pdf4tcllib::page::lineheight \$font_size\]"
        "# => 14.4 pt (12 * 1.2)"
        ""
        "# Mehrzeilige Texte zeichnen"
        "set y 100"
        "set lines \{\"Zeile 1\" \"Zeile 2\" \"Zeile 3\"\}"
        ""
        "\$pdf setFont \$font_size Helvetica"
        "foreach line \$lines \{"
        "    \$pdf text \$line -x 50 -y \$y"
        "    set y \[expr \{\$y + \$line_height\}\]  ;# next line"
        "\}"
    }
    
    foreach line $code_lines {
        $pdf text $line -x $sx -y $y
        set y [expr {$y + 12}]
    }
    
    # ========================================================================
    # Hinweis
    # ========================================================================
    
    set y [expr {$y + 20}]
    
    $pdf setFont 10 Helvetica
    $pdf setFillColor 0.3 0.3 0.3
    
    set hints {
        "Hinweis: Line-Height = Font-Size * Faktor"
        "         Standard-Faktor: 1.2 (120%)"
        "         for longer passages, 1.4 to 1.5"
    }
    
    foreach hint $hints {
        $pdf text $hint -x $sx -y $y
        set y [expr {$y + 13}]
    }
    
    $pdf setFillColor 0 0 0
    
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
puts "Compare the four blocks of text."
puts "      Line-Height 1.2 ist der Standard-Wert."

exit 0
