#!/usr/bin/env tclsh
# ============================================================================
# Demo 32: Letter and word spacing (Character & Word Spacing)
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
#     tclsh 32_text_spacing.tcl
#
# TCL OCTAL PITFALL:
#   RIGHT: set demo_num 32  (no leading zero)
#   WRONG: set demo_num 032 (octal!)
# ============================================================================
# What this shows:
#   - Character-Spacing verstehen
#   - Word-Spacing verstehen
#   - Manuelles Spacing mit getStringWidth
#   - spacing values side by side
#
# Features:
#   - Character-Spacing: eng, normal, weit, sehr weit
#   - Word-Spacing: eng, normal, weit
#   - Manuelle Implementation (pdf4tcl hat keine native Spacing-API)
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
set demo_num 32
set demo_name "text_spacing"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Helper: Draw Text with Character Spacing
# ============================================================================

proc draw_char_spaced_text {pdf text x y char_spacing} {
    set current_x $x
    foreach char [split $text ""] {
        $pdf text $char -x $current_x -y $y
        set char_width [$pdf getCharWidth $char]
        set current_x [expr {$current_x + $char_width + $char_spacing}]
    }
    return $current_x
}

# ============================================================================
# Helper: Draw Text with Word Spacing
# ============================================================================

proc draw_word_spaced_text {pdf text x y word_spacing} {
    set current_x $x
    set words [split $text]
    set word_count [llength $words]
    
    for {set i 0} {$i < $word_count} {incr i} {
        set word [lindex $words $i]
        $pdf text $word -x $current_x -y $y
        set word_width [$pdf getStringWidth $word]
        
        # word spacing after every word but the last
        if {$i < $word_count - 1} {
            set current_x [expr {$current_x + $word_width + $word_spacing}]
        }
    }
    return $current_x
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Text-Spacing"
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
    
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 32: Letter and word spacing" -x $sx -y $sy
    
    # --- Encoding-Test ---
    set y [expr {$sy + 30}]
    $pdf setFont 10 Helvetica
    $pdf text "Encoding test: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $sx -y $y
    
    # ========================================================================
    # Section 1: Character Spacing
    # ========================================================================
    
    set y [expr {$y + 50}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "1. Letter spacing" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    set sample_text "The quick brown fox jumps"
    
    # Normal (0pt)
    $pdf text "Normal (0pt):" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text $sample_text -x [expr {$sx + 20}] -y $y
    
    # Eng (-1pt) - Manuell umsetzen ist schwierig, zeigen wir nur normal/weit
    set y [expr {$y + 25}]
    $pdf text "Wide (2pt):" -x $sx -y $y
    set y [expr {$y + 20}]
    draw_char_spaced_text $pdf $sample_text [expr {$sx + 20}] $y 2
    
    # Sehr weit (5pt)
    set y [expr {$y + 25}]
    $pdf text "Very wide (5pt):" -x $sx -y $y
    set y [expr {$y + 20}]
    draw_char_spaced_text $pdf $sample_text [expr {$sx + 20}] $y 5
    
    # Extra weit (10pt)
    set y [expr {$y + 25}]
    $pdf text "Extra wide (10pt):" -x $sx -y $y
    set y [expr {$y + 20}]
    draw_char_spaced_text $pdf $sample_text [expr {$sx + 20}] $y 10
    
    # ========================================================================
    # Section 2: Word Spacing
    # ========================================================================
    
    set y [expr {$y + 50}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. Word spacing" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    # Normal (Standard Leerzeichen)
    $pdf text "Normal (default):" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text $sample_text -x [expr {$sx + 20}] -y $y
    
    # Eng (5pt)
    set y [expr {$y + 25}]
    $pdf text "Eng (5pt):" -x $sx -y $y
    set y [expr {$y + 20}]
    draw_word_spaced_text $pdf $sample_text [expr {$sx + 20}] $y 5
    
    # Weit (15pt)
    set y [expr {$y + 25}]
    $pdf text "Weit (15pt):" -x $sx -y $y
    set y [expr {$y + 20}]
    draw_word_spaced_text $pdf $sample_text [expr {$sx + 20}] $y 15
    
    # Sehr weit (30pt)
    set y [expr {$y + 25}]
    $pdf text "Sehr weit (30pt):" -x $sx -y $y
    set y [expr {$y + 20}]
    draw_word_spaced_text $pdf $sample_text [expr {$sx + 20}] $y 30
    
    # ========================================================================
    # Section 3: Hinweise
    # ========================================================================
    
    set y [expr {$y + 50}]
    $pdf setFont 11 Helvetica-Bold
    $pdf text "Wichtige Hinweise:" -x $sx -y $y
    
    set y [expr {$y + 20}]
    $pdf setFont 9 Helvetica
    
    set notes {
        "* pdf4tcl hat KEINE native Character/Word-Spacing API"
        "* Manuell mit getCharWidth/getStringWidth implementiert"
        "* letter spacing: place one character at a time"
        "* word spacing: place each word separately"
        "* a little goes a long way -- too much is hard to read"
    }
    
    foreach note $notes {
        $pdf text $note -x [expr {$sx + 10}] -y $y
        set y [expr {$y + 15}]
    }
    
    # ========================================================================
    # Code-Beispiel
    # ========================================================================
    
    set y [expr {$y + 20}]
    $pdf setFont 10 Helvetica-Bold
    $pdf text "Code-Beispiel (Character-Spacing):" -x $sx -y $y
    
    set y [expr {$y + 18}]
    $pdf setFont 8 Courier
    
    set code_lines {
        "proc draw_char_spaced \{pdf text x y spacing\} \{"
        "    set current_x \$x"
        "    foreach char \[split \$text \"\"\] \{"
        "        \$pdf text \$char -x \$current_x -y \$y"
        "        set w \[\$pdf getCharWidth \$char\]"
        "        set current_x \[expr \{\$current_x + \$w + \$spacing\}\]"
        "    \}"
        "\}"
    }
    
    foreach line $code_lines {
        $pdf text $line -x [expr {$sx + 10}] -y $y
        set y [expr {$y + 10}]
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

exit 0
