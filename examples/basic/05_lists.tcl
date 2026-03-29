#!/usr/bin/env tclsh
# ============================================================================
# Demo 05: Listen (Bullets)
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 05_lists.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 05_lists.tcl
# ============================================================================
# Lernziele:
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

set demo_num 5
set demo_name "lists"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Listen (Bullets)"
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
    $pdf text "Demo 05: Listen (Bullets)" -x $sx -y $sy
    
    # --- Ungeordnete Liste (Bullets) ---
    set y [expr {$sy + 40}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "1. Ungeordnete Liste (Bullets):" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    set bullet_items {
        "Erster Punkt"
        "Zweiter Punkt mit Umlauten: äöüÄÖÜß"
        "Dritter Punkt"
        "Vierter Punkt mit Euro: 100€"
        "Fünfter Punkt mit Sonderzeichen: ©®™"
    }
    
    foreach item $bullet_items {
        $pdf text "* $item" -x $sx -y $y
        set y [expr {$y + 20}]
    }
    
    # --- Nummerierte Liste ---
    set y [expr {$y + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. Nummerierte Liste:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    set numbered_items {
        "Installation vorbereiten"
        "Abhängigkeiten prüfen (äöü Test)"
        "Konfiguration anpassen"
        "Tests durchführen"
        "Dokumentation lesen"
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
    $pdf text "3. Checkliste (ASCII-Checkboxen):" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    # WICHTIG: [X] und [ ] müssen als \[X\] und \[ \] escaped werden!
    set checklist {
        {true "Demo 01 erstellt"}
        {true "Demo 02 erstellt"}
        {true "Demo 03 erstellt"}
        {false "Demo 04 in Arbeit"}
        {false "Demo 05 geplant"}
    }
    
    foreach item $checklist {
        lassign $item checked text
        # \[ und \] für Tcl-Escaping!
        set checkbox [expr {$checked ? "\[X\]" : "\[ \]"}]
        $pdf text "$checkbox $text" -x $sx -y $y
        set y [expr {$y + 20}]
    }
    
    # --- Verschachtelte Liste ---
    set y [expr {$y + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "4. Verschachtelte Liste:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    # Hauptpunkte
    $pdf text "* Hauptpunkt 1" -x $sx -y $y
    set y [expr {$y + 20}]
    
    # Unterpunkte (eingerückt)
    set indent [expr {$sx + 20}]
    $pdf text "- Unterpunkt 1.1" -x $indent -y $y
    set y [expr {$y + 20}]
    $pdf text "- Unterpunkt 1.2 (äöü)" -x $indent -y $y
    set y [expr {$y + 20}]
    
    $pdf text "* Hauptpunkt 2" -x $sx -y $y
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
        {"*" "Stern (Standard)"}
        {"-" "Minus/Bindestrich"}
        {"+" "Plus-Zeichen"}
        {">" "Größer-als"}
        {"#" "Raute/Hash"}
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
        "* Deutsche Umlaute: äöüÄÖÜß"
        "* Euro-Symbol: 100€ oder 200€"
        "* Französisch: àèìòù ÀÈÌÒÙ"
        "* Spanisch: ñÑ ¿Hola? ¡Sí!"
        "* Sonderzeichen: ©®™ £¥¢"
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
