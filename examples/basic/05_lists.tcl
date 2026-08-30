#!/usr/bin/env tclsh
# ============================================================================
# Demo 05: Lists and bullets
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS:
#   For correct umlauts (aeoeueAEOEUEss, euro sign) use:
#     tclsh examples/main.tcl 05_lists.tcl
#
#   NOT directly -- that gives wrong characters in the PDF:
#     tclsh 05_lists.tcl
# ============================================================================
# What this shows:
#   - Ungeordnete Listen (Bullets)
#   - Nummerierte Listen
#   - Checkboxen (ASCII-Style)
#   - Listen mit Umlauten und Sonderzeichen
#
# Features:
#   - Bullet-Listen mit *
#   - Nummerierte Listen mit 1. 2. 3.
#   - ASCII-Checkboxen [X] und [ ]
#   - Encoding-Test in Listen
#
# Encoding test: äöüÄÖÜß€
# ============================================================================

# --- Setup ---
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

set demo_num 5
set demo_name "lists"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Lists and bullets"
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
    $pdf text "Demo 05: Lists and bullets" -x $sx -y $sy
    
    # --- Ungeordnete Liste (Bullets) ---
    set y [expr {$sy + 40}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "1. Unordered list (bullets):" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    set bullet_items {
        "First item"
        "Second item with umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df"
        "Third item"
        "Fourth item with a euro sign: 100\u20ac"
        "Fifth item with symbols: \u00a9\u00ae\u2122"
    }
    
    foreach item $bullet_items {
        $pdf text "* $item" -x $sx -y $y
        set y [expr {$y + 20}]
    }
    
    # --- Nummerierte Liste ---
    set y [expr {$y + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. Numbered list:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    set numbered_items {
        "Prepare the installation"
        "Check dependencies (\u00e4\u00f6\u00fc test)"
        "Adjust the configuration"
        "Run the tests"
        "Read the documentation"
    }
    
    set counter 1
    foreach item $numbered_items {
        $pdf text "$counter. $item" -x $sx -y $y
        set y [expr {$y + 20}]
        incr counter
    }
    
    # --- Checkboxen (ASCII-Style!) ---
    set y [expr {$y + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "3. Checklist (ASCII boxes):" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    # NOTE: [X] and [ ] have to be escaped as \[X\] and \[ \]
    set checklist {
        {true "Demo 01 erstellt"}
        {true "Demo 02 erstellt"}
        {true "Demo 03 erstellt"}
        {false "Demo 04 in Arbeit"}
        {false "Demo 05 geplant"}
    }
    
    foreach item $checklist {
        lassign $item checked text
        # \[ and \] for Tcl escaping
        set checkbox [expr {$checked ? "\[X\]" : "\[ \]"}]
        $pdf text "$checkbox $text" -x $sx -y $y
        set y [expr {$y + 20}]
    }
    
    # --- Verschachtelte Liste ---
    set y [expr {$y + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "4. Nested list:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    # Hauptpunkte
    $pdf text "* Main item 1" -x $sx -y $y
    set y [expr {$y + 20}]
    
    # sub-items, indented
    set indent [expr {$sx + 20}]
    $pdf text "- Sub-item 1.1" -x $indent -y $y
    set y [expr {$y + 20}]
    $pdf text "- Sub-item 1.2 (\u00e4\u00f6\u00fc)" -x $indent -y $y
    set y [expr {$y + 20}]
    
    $pdf text "* Main item 2" -x $sx -y $y
    set y [expr {$y + 20}]
    
    $pdf text "- Unterpunkt 2.1" -x $indent -y $y
    set y [expr {$y + 20}]
    $pdf text "- Unterpunkt 2.2 (€ Symbol)" -x $indent -y $y
    set y [expr {$y + 20}]
    
    $pdf text "* Hauptpunkt 3" -x $sx -y $y
    set y [expr {$y + 20}]
    
    # --- Alternative Bullet-Stile ---
    set y [expr {$y + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "5. Alternative Bullet-Stile:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    set bullet_styles {
        {"*" "asterisk (default)"}
        {"-" "hyphen-minus"}
        {"+" "plus sign"}
        {">" "greater-than"}
        {"#" "number sign"}
    }
    
    foreach style $bullet_styles {
        lassign $style symbol text
        $pdf text "$symbol $text" -x $sx -y $y
        set y [expr {$y + 20}]
    }
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$y + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Encoding-Test:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 11 Helvetica
    
    set encoding_items {
        "* German umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df"
        "* Euro sign: 100\u20ac or 200\u20ac"
        "* French: \u00e0\u00e8\u00ec\u00f2\u00f9 \u00c0\u00c8\u00cc\u00d2\u00d9"
        "* Spanish: \u00f1\u00d1 \u00bfHola? \u00a1S\u00ed!"
        "* Symbols: \u00a9\u00ae\u2122 \u00a3\u00a5\u00a2"
    }
    
    foreach item $encoding_items {
        $pdf text $item -x $sx -y $y
        set y [expr {$y + 18}]
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
