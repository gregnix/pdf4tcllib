#!/usr/bin/env tclsh
# ============================================================================
# Demo 14: Margins and safe area
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
#     tclsh 14_margins.tcl
#
# TCL OCTAL PITFALL:
#   RIGHT: set demo_num 14  (no leading zero)
#   WRONG: set demo_num 014 (octal!)
# ============================================================================
# What this shows:
#   - Margins und Safe Area verstehen
#   - Warum Margins wichtig sind
#   - DIN 5008 margins for business letters
#   - PageContext nutzen
#
# Features:
#   - Visualisierung der Safe Area
#   - Sheet edge vs. Inhalt-Bereich
#   - margins of different sizes
#   - Praktische Beispiele
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
set demo_num 14
set demo_name "margins"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Margins & Safe Area"
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
    
    # Get page and safe area from context
    set pw [dict get $ctx PW]
    set ph [dict get $ctx PH]
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    set margin_pt [dict get $ctx margin_pt]
    set margin_mm [dict get $ctx margin_mm]
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 14: Margins and safe area" -x $sx -y $sy
    
    # --- Encoding-Test ---
    set y [expr {$sy + 30}]
    $pdf setFont 10 Helvetica
    $pdf text "Encoding test: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $sx -y $y
    
    # ========================================================================
    # Visualisierung: Ganze Seite
    # ========================================================================
    
    # the sheet edge
    $pdf gsave
    $pdf setStrokeColor 1 0.5 0.5
    $pdf setLineWidth 3
    $pdf rectangle 0 0 $pw $ph -stroke 1
    $pdf grestore
    
    # Safe Area (innerer Bereich)
    $pdf gsave
    $pdf setStrokeColor 0.5 1 0.5
    $pdf setLineWidth 2
    $pdf rectangle $sx $sy $sw $sh -stroke 1
    $pdf grestore
    
    # Margin-Linien (gestrichelt)
    $pdf gsave
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf setLineDash 2 2
    
    # Horizontale Margin-Linien
    $pdf line 0 $sy $pw $sy
    $pdf line 0 [expr {$sy + $sh}] $pw [expr {$sy + $sh}]
    
    # Vertikale Margin-Linien
    $pdf line $sx 0 $sx $ph
    $pdf line [expr {$sx + $sw}] 0 [expr {$sx + $sw}] $ph
    
    $pdf grestore
    
    # ========================================================================
    # Legende
    # ========================================================================
    
    set legend_x [expr {$pw - 180}]
    set legend_y 50
    
    # Legende-Box
    $pdf setFillColor 1 1 0.95
    $pdf rectangle $legend_x $legend_y 160 100 -filled 1
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0 0 0
    $pdf setFillColor 0 0 0
    $pdf rectangle $legend_x $legend_y 160 100 -stroke 1
    
    # Legende-Text
    set text_x [expr {$legend_x + 10}]
    set text_y [expr {$legend_y + 20}]
    
    $pdf setFont 10 Helvetica-Bold
    $pdf text "Key:" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 20}]
    
    # Rot: Sheet edge
    $pdf gsave
    $pdf setStrokeColor 1 0.5 0.5
    $pdf setLineWidth 2
    $pdf line $text_x $text_y [expr {$text_x + 20}] $text_y
    $pdf grestore
    
    $pdf setFont 9 Helvetica
    $pdf text "Sheet edge" -x [expr {$text_x + 25}] -y [expr {$text_y - 3}]
    
    set text_y [expr {$text_y + 18}]
    
    # green: the safe area
    $pdf gsave
    $pdf setStrokeColor 0.5 1 0.5
    $pdf setLineWidth 2
    $pdf line $text_x $text_y [expr {$text_x + 20}] $text_y
    $pdf grestore
    
    $pdf text "Safe Area" -x [expr {$text_x + 25}] -y [expr {$text_y - 3}]
    
    set text_y [expr {$text_y + 18}]
    
    # Grau: Margins
    $pdf gsave
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf setLineDash 2 2
    $pdf line $text_x $text_y [expr {$text_x + 20}] $text_y
    $pdf grestore
    
    $pdf text "Margins" -x [expr {$text_x + 25}] -y [expr {$text_y - 3}]
    
    # ========================================================================
    # Info-Bereich
    # ========================================================================
    
    set info_y [expr {$sy + 80}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "What margins are" -x $sx -y $info_y
    
    set info_y [expr {$info_y + 25}]
    $pdf setFont 10 Helvetica
    
    set info_lines {
        "A margin is the distance between the sheet edge and the content."
        ""
        "Warum sind Margins wichtig?"
        "* most printers cannot print to the edge"
        "* Text am Rand ist schwer lesbar"
        "* Professionelles Aussehen"
        "* room for punching, stapling, binding"
        "* DIN 5008 is the German business letter standard"
    }
    
    foreach line $info_lines {
        $pdf text $line -x $sx -y $info_y
        set info_y [expr {$info_y + 15}]
    }
    
    # ========================================================================
    # table of margin sizes
    # ========================================================================
    
    set info_y [expr {$info_y + 20}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Common margins" -x $sx -y $info_y
    
    set info_y [expr {$info_y + 25}]
    
    set margin_data {
        {"Anwendung" "Margin (mm)" "Margin (pt)" "Verwendung"}
        {"Standard" "20" "57" "Allgemein"}
        {"Minimal" "10" "28" "Maximaler Platz"}
        {"DIN 5008" "25 (left)" "71" "business letters"}
        {"Buch/Print" "15-20" "43-57" "Druckprodukte"}
    }
    
    set col_widths {100 80 80 120}
    
    pdf4tcllib::table::simpleTable $pdf $sx $info_y $col_widths $margin_data \
        -zebra 1 \
        -row_height 22 \
        -font_size 9
    
    # ========================================================================
    # the measurements
    # ========================================================================
    
    set measure_y [expr {$info_y + [expr {[llength $margin_data] * 22}] + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Dieses Dokument" -x $sx -y $measure_y
    
    set measure_y [expr {$measure_y + 25}]
    $pdf setFont 10 Courier
    
    set measures [list \
        "Sheet size:     $pw x $ph pt  (595 x 842 pt = A4)" \
        "Margin:         $margin_mm mm  ($margin_pt pt)" \
        "Safe Area:      $sw x $sh pt" \
        "Safe Area Pos:  ($sx, $sy) pt" \
    ]
    
    foreach measure $measures {
        $pdf text $measure -x $sx -y $measure_y
        set measure_y [expr {$measure_y + 15}]
    }
    
    # ========================================================================
    # Example code
    # ========================================================================
    
    set measure_y [expr {$measure_y + 20}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Example code: PageContext nutzen" -x $sx -y $measure_y
    
    set measure_y [expr {$measure_y + 25}]
    $pdf setFont 9 Courier
    
    set code_lines {
        "# PageContext mit 20mm Margin erstellen"
        "set ctx \[pdf4tcllib::page::context a4 20 true\]"
        ""
        "# Safe Area auslesen"
        "set sx \[dict get \$ctx SX\]  ;# Safe X (linker Rand)"
        "set sy \[dict get \$ctx SY\]  ;# Safe Y (oberer Rand)"
        "set sw \[dict get \$ctx SW\]  ;# Safe Width"
        "set sh \[dict get \$ctx SH\]  ;# Safe Height"
        ""
        "# Text innerhalb der Safe Area platzieren"
        "\$pdf text \"Sicherer Text\" -x \$sx -y \$sy"
    }
    
    foreach line $code_lines {
        $pdf text $line -x $sx -y $measure_y
        set measure_y [expr {$measure_y + 12}]
    }
    
    # ========================================================================
    # the measurements drawn on the page
    # ========================================================================
    
    # margin measurements with arrows
    $pdf setFont 8 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    
    # Oben: Margin
    $pdf text "[format %.1f $margin_mm]mm" -x [expr {$pw / 2}] -y [expr {$sy / 2}] -align center
    
    # Links: Margin
    set mid_y [expr {$ph / 2}]
    $pdf text "[format %.1f $margin_mm]mm" -x [expr {$sx / 2}] -y $mid_y -align center
    
    $pdf setFillColor 0 0 0
    
    # --- Debug-Grid (nur wenn PDF4TCL_DEBUG=1) ---
    # pdf4tcllib::page::grid $pdf 50
    # Bewusst ausgeschaltet, da wir eigenes Grid haben
    
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
puts "TIPP: Beachten Sie die farbigen Linien!"
puts "      Rot  = Sheet edge (nicht bedruckbar)"
puts "      green = the safe area, put content here"

exit 0
