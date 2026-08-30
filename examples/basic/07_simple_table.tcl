#!/usr/bin/env tclsh
# ============================================================================
# Demo 07: A simple table
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS:
#   For correct umlauts (aeoeueAEOEUEss, euro sign) use:
#     tclsh examples/main.tcl 07_simple_table.tcl
#
#   NOT directly -- that gives wrong characters in the PDF:
#     tclsh 07_simple_table.tcl
# ============================================================================
# What this shows:
#   - Einfache Tabelle zeichnen
#   - Tabellenstruktur mit Linien
#   - Header-Zeile formatieren
#   - Daten in Zellen platzieren
#
# Features:
#   - 3x4 Tabelle (3 Spalten, 4 Zeilen inkl. Header)
#   - Header mit grauem Hintergrund
#   - Raster mit Linien
#   - an encoding test inside a table
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

set demo_num 7
set demo_name "simple_table"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: A simple table"
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
    $pdf text "Demo 07: A simple table" -x $sx -y $sy
    
    # --- Tabelle 3x4 (3 Spalten, 4 Zeilen) ---
    set y [expr {$sy + 50}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Table with an encoding test:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    
    # Tabellen-Parameter
    set table_x $sx
    set table_y $y
    set col_width 100  ;# pt
    set row_height 30  ;# pt
    set cols 3
    set rows 4  ;# inkl. Header
    
    # Header
    set headers {"Column 1" "Column 2" "Column 3"}
    
    # data (three rows)
    set data {
        {"Row 1" "\u00e4\u00f6\u00fc" "100\u20ac"}
        {"Row 2" "\u00c4\u00d6\u00dc" "200\u20ac"}
        {"Row 3" "\u00df" "300\u20ac"}
    }
    
    # --- the grid ---
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.0 0.0 0.0
    
    # Horizontale Linien
    for {set row 0} {$row <= $rows} {incr row} {
        set line_y [expr {$table_y + $row * $row_height}]
        $pdf line $table_x $line_y [expr {$table_x + $cols * $col_width}] $line_y
    }
    
    # Vertikale Linien
    for {set col 0} {$col <= $cols} {incr col} {
        set line_x [expr {$table_x + $col * $col_width}]
        $pdf line $line_x $table_y $line_x [expr {$table_y + $rows * $row_height}]
    }
    
    # --- Header (fett, hellgrau Hintergrund) ---
    $pdf setFillColor 0.9 0.9 0.9  ;# Hellgrau
    for {set col 0} {$col < $cols} {incr col} {
        set cell_x [expr {$table_x + $col * $col_width}]
        $pdf rectangle $cell_x $table_y $col_width $row_height -filled 1
    }
    
    # Header-Text
    $pdf setFillColor 0.0 0.0 0.0  ;# Schwarz
    $pdf setFont 11 Helvetica-Bold
    
    for {set col 0} {$col < $cols} {incr col} {
        set text [lindex $headers $col]
        set text_x [expr {$table_x + $col * $col_width + 5}]
        set text_y [expr {$table_y + 10}]
        $pdf text $text -x $text_x -y $text_y
    }
    
    # --- Daten ---
    $pdf setFont 10 Helvetica
    
    for {set row 0} {$row < [llength $data]} {incr row} {
        set row_data [lindex $data $row]
        
        for {set col 0} {$col < $cols} {incr col} {
            set text [lindex $row_data $col]
            set text_x [expr {$table_x + $col * $col_width + 5}]
            set text_y [expr {$table_y + ($row + 1) * $row_height + 10}]
            $pdf text $text -x $text_x -y $text_y
        }
    }
    
    # --- Zweite Tabelle: Mit Farben ---
    set y [expr {$table_y + $rows * $row_height + 50}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf setFillColor 0.0 0.0 0.0
    $pdf text "Table with coloured cells:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    
    # Tabellen-Parameter
    set table2_x $sx
    set table2_y $y
    set cols2 4
    set rows2 3
    set col_width2 80
    set row_height2 30
    
    # Raster zeichnen
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.0 0.0 0.0
    
    for {set row 0} {$row <= $rows2} {incr row} {
        set line_y [expr {$table2_y + $row * $row_height2}]
        $pdf line $table2_x $line_y [expr {$table2_x + $cols2 * $col_width2}] $line_y
    }
    
    for {set col 0} {$col <= $cols2} {incr col} {
        set line_x [expr {$table2_x + $col * $col_width2}]
        $pdf line $line_x $table2_y $line_x [expr {$table2_y + $rows2 * $row_height2}]
    }
    
    # coloured cells: light red, green, blue, yellow
    set colors {
        {1.0 0.9 0.9}
        {0.9 1.0 0.9}
        {0.9 0.9 1.0}
        {1.0 1.0 0.9}
    }
    
    # Erste Zeile (Header) mit verschiedenen Farben
    for {set col 0} {$col < $cols2} {incr col} {
        lassign [lindex $colors $col] r g b
        $pdf setFillColor $r $g $b
        set cell_x [expr {$table2_x + $col * $col_width2}]
        $pdf rectangle $cell_x $table2_y $col_width2 $row_height2 -filled 1
    }
    
    # Header-Text
    $pdf setFillColor 0.0 0.0 0.0
    $pdf setFont 10 Helvetica-Bold
    
    set headers2 {"Red" "Green" "Blue" "Yellow"}
    for {set col 0} {$col < $cols2} {incr col} {
        set text [lindex $headers2 $col]
        set text_x [expr {$table2_x + $col * $col_width2 + 5}]
        set text_y [expr {$table2_y + 10}]
        $pdf text $text -x $text_x -y $text_y
    }
    
    # data rows
    set data2 {
        {"A" "B" "C" "D"}
        {"\u00e4\u00f6\u00fc" "\u00c4\u00d6\u00dc" "\u00df" "\u20ac"}
    }
    
    $pdf setFont 10 Helvetica
    for {set row 0} {$row < [llength $data2]} {incr row} {
        set row_data [lindex $data2 $row]
        for {set col 0} {$col < $cols2} {incr col} {
            set text [lindex $row_data $col]
            set text_x [expr {$table2_x + $col * $col_width2 + 5}]
            set text_y [expr {$table2_y + ($row + 1) * $row_height2 + 10}]
            $pdf text $text -x $text_x -y $text_y
        }
    }
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$table2_y + $rows2 * $row_height2 + 40}]
    
    $pdf setFont 11 Helvetica
    $pdf setFillColor 0.0 0.0 0.0
    $pdf text "Encoding test: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac (visible inside a table)" -x $sx -y $y
    
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
