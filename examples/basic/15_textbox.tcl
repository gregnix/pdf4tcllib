#!/usr/bin/env tclsh
# ============================================================================
# Demo 15: Text box with automatic wrapping
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
#     tclsh 15_textbox.tcl
#
# TCL OCTAL PITFALL:
#   RIGHT: set demo_num 15  (no leading zero)
#   WRONG: set demo_num 015 (octal!)
# ============================================================================
# What this shows:
#   - Text in Box mit fester Breite umbrechen
#   - Automatisches Word-Wrapping
#   - drawTextBox nutzen
#   - Text-Overflow behandeln
#
# Features:
#   - Automatisches Wrapping bei fester Breite
#   - several examples at different sizes
#   - Overflow-Erkennung
#   - Line-Height Kontrolle
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
set demo_num 15
set demo_name "textbox"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Helper: Draw Textbox with Frame
# ============================================================================

proc draw_textbox_example {pdf x y width height title text font_size} {
    # the caption above the box
    $pdf setFont 11 Helvetica-Bold
    $pdf text $title -x $x -y $y
    
    set box_y [expr {$y + 20}]
    
    # Box-Rahmen
    $pdf gsave
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.3 0.3 0.8
    $pdf rectangle $x $box_y $width $height -stroke 1
    $pdf grestore
    
    # Text in Box mit drawTextBox
    # WICHTIG: drawTextBox macht automatisches Wrapping!
    set text_x [expr {$x + 5}]  ;# 5pt Padding
    set text_y [expr {$box_y + 10}]  ;# 10pt Padding von oben
    set text_width [expr {$width - 10}]  ;# 2x 5pt Padding
    
    $pdf setFont $font_size Helvetica
    
    $pdf drawTextBox $text_x $text_y $text_width $height $text

    # NOTE: with orient=true, -newyvar returns a bottom-origin value -- do not use it
    # box_y + height is reliable instead: top-origin and deterministic
    set info_y [expr {$box_y + $height + 4}]
    $pdf setFont 8 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    $pdf text "Box: ${width}x${height}pt | Font: ${font_size}pt" -x $x -y $info_y
    $pdf setFillColor 0 0 0

    # Return next Y: box bottom + info label + gap
    return [expr {$info_y + 14}]
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Textbox mit Wrapping"
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
    $pdf text "Demo 15: Text box with automatic wrapping" -x $sx -y $sy
    
    # --- Intro ---
    set y [expr {$sy + 35}]
    $pdf setFont 10 Helvetica
    $pdf text "drawTextBox wraps text into as many lines as it needs." -x $sx -y $y
    
    # --- Encoding-Test ---
    set y [expr {$y + 20}]
    $pdf text "Encoding test: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $sx -y $y
    
    # ========================================================================
    # Beispiel-Text
    # ========================================================================
    
    set sample_short "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore."
    
    set sample_long "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."
    
    set sample_german "A longer paragraph with umlauts (\u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df) and symbols such as the euro sign (\u20ac). It wraps by itself once it no longer fits the box -- useful for descriptions, comments and longer passages."
    
    # ========================================================================
    # Beispiel 1: Schmale Box
    # ========================================================================
    
    set y [expr {$y + 40}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "1. Narrow box, short text" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    set y [draw_textbox_example $pdf $sx $y 200 80 \
        "Box A: 200pt breit" $sample_short 10]
    
    # ========================================================================
    # Beispiel 2: Breite Box
    # ========================================================================
    
    set y [expr {$y + 10}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. Wide box, longer text" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    set y [draw_textbox_example $pdf $sx $y 400 120 \
        "Box B: 400pt breit" $sample_long 10]
    
    # ========================================================================
    # Beispiel 3: Zwei Spalten
    # ========================================================================
    
    set y [expr {$y + 10}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "3. Two columns" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    set col1_x $sx
    set col2_x [expr {$sx + 250}]
    
    # Spalte 1
    set y1 [draw_textbox_example $pdf $col1_x $y 230 100 \
        "Spalte 1 (9pt)" $sample_german 9]
    
    # Spalte 2
    set y2 [draw_textbox_example $pdf $col2_x $y 230 100 \
        "Spalte 2 (11pt)" $sample_german 11]
    
    set y [expr {max($y1, $y2) + 10}]
    
    # ========================================================================
    # Example code
    # ========================================================================
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Example code: drawTextBox verwenden" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 9 Courier
    
    set code_lines {
        "# Textbox mit automatischem Wrapping"
        "set x 100"
        "set y 200"
        "set width 300   ;# Maximale Breite"
        "set height 150  ;# maximum height"
        ""
        "set text \"Langer Text der automatisch umgebrochen wird...\""
        ""
        "\$pdf setFont 10 Helvetica"
        "\$pdf drawTextBox \$x \$y \$width \$height \$text"
        ""
        "# Optional: Ausrichtung"
        "\$pdf drawTextBox \$x \$y \$width \$height \$text -align justify"
        ""
        "# alignments: left, right, center, justify"
    }
    
    foreach line $code_lines {
        $pdf text $line -x $sx -y $y
        set y [expr {$y + 11}]
    }
    
    # ========================================================================
    # Hinweise
    # ========================================================================
    
    set y [expr {$y + 20}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Wichtige Hinweise" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 9 Helvetica
    
    set hints {
        "* drawTextBox bricht Text automatisch bei Leerzeichen um"
        "* Wenn Text zu lang: wird abgeschnitten (kein Overflow-Handling)"
        "* be generous with the height"
        "* Line-Height ist automatisch (ca. 1.2x Font-Size)"
        "* Umlaute und Sonderzeichen (Latin-1) funktionieren"
        "* justify spreads the words evenly"
        "* for more layout, use pdf4tcllib::text::writeParagraph"
    }
    
    foreach hint $hints {
        $pdf text $hint -x $sx -y $y
        set y [expr {$y + 13}]
    }
    
    # ========================================================================
    # Alternative: Helper-Funktion
    # ========================================================================
    
    set y [expr {$y + 20}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Alternative: pdf4tcllib::text::writeParagraph Helper" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 9 Courier
    
    set code_lines2 {
        "# Helper-Funktion mit mehr Kontrolle"
        "set next_y \[pdf4tcllib::text::writeParagraph \$pdf \\"
        "    \$text \$x \$y \$width \$font_size \$align\]"
        ""
        "# returns: the next Y position, for the paragraph after it"
    }
    
    foreach line $code_lines2 {
        $pdf text $line -x $sx -y $y
        set y [expr {$y + 11}]
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
puts "TIPP: Beachten Sie wie der Text automatisch"
puts "      in den Boxen umgebrochen wird!"

exit 0
