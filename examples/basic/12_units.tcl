#!/usr/bin/env tclsh
# ============================================================================
# Demo 12: Einheiten-Umrechnung
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 12_units.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 12_units.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 12  (ohne führende 0)
#   FALSCH:  set demo_num 012 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - Einheiten-Umrechnung verstehen (mm, cm, inch -> points)
#   - Helper-Funktionen für Umrechnung nutzen
#   - DIN-Formate kennenlernen (A4, A5, A6)
#   - Standard-Formate (Letter, Legal)
#
# Features:
#   - Umrechnungstabelle mit Formeln
#   - DIN-Formate Übersicht
#   - Code-Beispiele für Helper-Funktionen
#   - Praktische Referenz
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
set demo_num 12
set demo_name "units"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Einheiten-Umrechnung"
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
    
    # Get safe area from context
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 12: Einheiten-Umrechnung" -x $sx -y $sy
    
    # --- Intro ---
    set y [expr {$sy + 35}]
    $pdf setFont 10 Helvetica
    $pdf text "PDF verwendet Points (pt) als Basis-Einheit. 1 Point = 1/72 Inch" -x $sx -y $y
    
    # --- Encoding-Test ---
    set y [expr {$y + 20}]
    $pdf text "Encoding-Test: äöüÄÖÜß €" -x $sx -y $y
    
    # ========================================================================
    # Section 1: Umrechnungs-Formeln
    # ========================================================================
    
    set y [expr {$y + 40}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "1. Umrechnungs-Formeln" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 10 Courier
    
    set formulas {
        "1 inch  = 72 points      (exakt)"
        "1 cm    = 28.35 points   (72 / 2.54)"
        "1 mm    = 2.835 points   (72 / 25.4)"
    }
    
    foreach formula $formulas {
        $pdf text $formula -x $sx -y $y
        set y [expr {$y + 15}]
    }
    
    # ========================================================================
    # Section 2: Umrechnungs-Tabelle
    # ========================================================================
    
    set y [expr {$y + 20}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. Umrechnungs-Tabelle" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # Tabellen-Daten
    set table_data {
        {"mm" "cm" "inch" "points"}
        {"10" "1.0" "0.39" "28"}
        {"20" "2.0" "0.79" "57"}
        {"50" "5.0" "1.97" "142"}
        {"100" "10.0" "3.94" "283"}
        {"210" "21.0" "8.27" "595"}
        {"297" "29.7" "11.69" "842"}
    }
    
    # Spalten-Breiten
    set col_widths {80 80 80 80}
    
    # Tabelle zeichnen mit Helper
    pdf4tcllib::table::simpleTable $pdf $sx $y $col_widths $table_data \
        -zebra 1 \
        -row_height 22 \
        -font_size 10
    
    # ========================================================================
    # Section 3: DIN-Formate
    # ========================================================================
    
    set y [expr {$y + [expr {[llength $table_data] * 22}] + 30}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "3. Standard-Papierformate" -x $sx -y $y
    
    set y [expr {$y + 25}]
    
    # Format-Tabelle
    set format_data {
        {"Format" "mm" "inch" "points"}
        {"A4" "210x297" "8.27x11.69" "595x842"}
        {"A5" "148x210" "5.83x8.27" "420x595"}
        {"A6" "105x148" "4.13x5.83" "298x420"}
        {"Letter" "216x279" "8.5x11" "612x792"}
        {"Legal" "216x356" "8.5x14" "612x1008"}
    }
    
    # Spalten-Breiten
    set format_widths {80 90 100 100}
    
    # Tabelle zeichnen
    pdf4tcllib::table::simpleTable $pdf $sx $y $format_widths $format_data \
        -zebra 1 \
        -row_height 22 \
        -font_size 10
    
    # ========================================================================
    # Section 4: Code-Beispiele
    # ========================================================================
    
    set y [expr {$y + [expr {[llength $format_data] * 22}] + 30}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "4. Helper-Funktionen (Code-Beispiele)" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 9 Courier
    
    set code_examples {
        "# Millimeter zu Points"
        "set width_mm 210"
        "set width_pt \[pdf4tcllib::units::mm \$width_mm\]"
        "# => 595.28 pt"
        ""
        "# Centimeter zu Points"
        "set margin_cm 2.0"
        "set margin_pt \[pdf4tcllib::units::cm \$margin_cm\]"
        "# => 56.69 pt"
        ""
        "# Inch zu Points"
        "set width_inch 8.5"
        "set width_pt \[pdf4tcllib::units::inch \$width_inch\]"
        "# => 612 pt"
    }
    
    foreach line $code_examples {
        $pdf text $line -x $sx -y $y
        set y [expr {$y + 12}]
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
puts "Mit Debug-Grid:"
puts "  PDF4TCL_DEBUG=1 tclsh [info script]"

exit 0
