#!/usr/bin/env tclsh
# ============================================================================
# Demo 19: Visitenkarte
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 19_business_card.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 19_business_card.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 19  (ohne führende 0)
#   FALSCH:  set demo_num 019 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - Visitenkarten-Layout erstellen
#   - Mehrere Karten auf einer Seite
#   - Professionelles Design
#   - Schnittlinien für Druck
#
# Features:
#   - 10 Visitenkarten auf A4 (2 x 5)
#   - Größe: 85mm × 55mm (Standard)
#   - Professionelles Layout
#   - Schnittlinien
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
set demo_num 19
set demo_name "business_card"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Helper: Draw Business Card
# ============================================================================

proc draw_business_card {pdf x y} {
    # Visitenkarten-Größe: 85mm × 55mm (Standard)
    set card_w [pdf4tcllib::units::mm 85]  ;# ~241pt
    set card_h [pdf4tcllib::units::mm 55]  ;# ~156pt
    
    # Hintergrund (leicht getönt)
    $pdf gsave
    $pdf setFillColor 0.98 0.98 1.0
    $pdf rectangle $x $y $card_w $card_h -filled 1
    $pdf setFillColor 0 0 0
    $pdf grestore
    
    # Rahmen
    $pdf gsave
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.3 0.3 0.3
    $pdf rectangle $x $y $card_w $card_h -stroke 1
    $pdf grestore
    
    # ========================================================================
    # Oberer Bereich: Firma/Logo
    # ========================================================================
    
    set margin 10  ;# Innenabstand
    
    # Firma-Name (oben links)
    set text_x [expr {$x + $margin}]
    set text_y [expr {$y + $margin + 5}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "MUSTERFIRMA GmbH" -x $text_x -y $text_y
    
    # Optional: Logo-Platzhalter (oben rechts)
    set logo_size 30
    set logo_x [expr {$x + $card_w - $logo_size - $margin}]
    set logo_y [expr {$y + $margin}]
    
    $pdf gsave
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf rectangle $logo_x $logo_y $logo_size $logo_size -stroke 1
    $pdf setFont 8 Helvetica
    $pdf setFillColor 0.7 0.7 0.7
    $pdf text "Logo" -x [expr {$logo_x + 6}] -y [expr {$logo_y + 12}]
    $pdf setFillColor 0 0 0
    $pdf grestore
    
    # ========================================================================
    # Trennlinie
    # ========================================================================
    
    set divider_y [expr {$y + $card_h / 2.2}]
    
    $pdf gsave
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf setLineWidth 0.75
    $pdf line [expr {$x + $margin}] $divider_y \
              [expr {$x + $card_w - $margin}] $divider_y
    $pdf grestore
    
    # ========================================================================
    # Unterer Bereich: Person & Kontakt
    # ========================================================================
    
    set bottom_y [expr {$divider_y + 15}]
    
    # Name (fett)
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Max Mustermann" -x $text_x -y $bottom_y
    
    set bottom_y [expr {$bottom_y + 15}]
    
    # Position
    $pdf setFont 10 Helvetica
    $pdf setFillColor 0.3 0.3 0.3
    $pdf text "Geschäftsführer" -x $text_x -y $bottom_y
    
    set bottom_y [expr {$bottom_y + 18}]
    
    # Kontaktdaten
    $pdf setFont 8 Helvetica
    
    set contact_lines {
        "Tel:   +49 123 456789"
        "Email: max@musterfirma.de"
        "Web:   www.musterfirma.de"
    }
    
    foreach line $contact_lines {
        $pdf text $line -x $text_x -y $bottom_y
        set bottom_y [expr {$bottom_y + 11}]
    }
    
    $pdf setFillColor 0 0 0
    
    return [list $card_w $card_h]
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Visitenkarte"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl]"
    puts "  Output: $output_file"
    
    # ========================================================================
    # STEP 1: Create Page Context
    # ========================================================================
    
    set ctx [pdf4tcllib::page::context a4 10 true]  ;# Kleinerer Margin
    
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
    set pw [dict get $ctx PW]
    set ph [dict get $ctx PH]
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 19: Visitenkarten (10 auf A4)" -x $sx -y $sy
    
    # --- Info ---
    set info_y [expr {$sy + 25}]
    $pdf setFont 9 Helvetica
    $pdf text "Format: 85mm x 55mm | Encoding-Test: äöüÄÖÜß €" -x $sx -y $info_y
    
    # ========================================================================
    # Layout: 2 Spalten × 5 Zeilen = 10 Karten
    # ========================================================================
    
    set card_w [pdf4tcllib::units::mm 85]
    set card_h [pdf4tcllib::units::mm 55]
    set spacing [pdf4tcllib::units::mm 5]  ;# 5mm Abstand
    
    set start_x $sx
    set start_y [expr {$sy + 50}]
    
    set cols 2
    set rows 5
    
    set card_num 1
    
    for {set row 0} {$row < $rows} {incr row} {
        for {set col 0} {$col < $cols} {incr col} {
            set x [expr {$start_x + $col * ($card_w + $spacing)}]
            set y [expr {$start_y + $row * ($card_h + $spacing)}]
            
            # Karte zeichnen
            draw_business_card $pdf $x $y
            
            # Schnittlinien (grau, dünn, gestrichelt)
            $pdf gsave
            $pdf setStrokeColor 0.8 0.8 0.8
            $pdf setLineWidth 0.25
            $pdf setLineDash 2 2
            
            # Horizontale Schnittlinien (oben und unten)
            if {$row > 0} {
                # Linie über der Karte
                set cut_y [expr {$y - $spacing / 2}]
                $pdf line $x $cut_y [expr {$x + $card_w}] $cut_y
            }
            
            # Vertikale Schnittlinien (links und rechts)
            if {$col > 0} {
                # Linie links von der Karte
                set cut_x [expr {$x - $spacing / 2}]
                $pdf line $cut_x $y $cut_x [expr {$y + $card_h}]
            }
            
            $pdf grestore
            
            incr card_num
        }
    }
    
    # ========================================================================
    # Hinweise am unteren Rand
    # ========================================================================
    
    set note_y [expr {$start_y + $rows * ($card_h + $spacing) + 20}]
    
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    
    set notes {
        "Hinweise:"
        "* Graue gestrichelte Linien = Schnittlinien"
        "* Standard-Format: 85mm x 55mm"
        "* 10 Karten auf A4 (2 Spalten x 5 Zeilen)"
        "* Professionell drucken lassen oder auf dickerem Papier (250g+)"
    }
    
    foreach note $notes {
        $pdf text $note -x $sx -y $note_y
        set note_y [expr {$note_y + 12}]
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
        puts "   ✓ Business cards: 10"
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
puts "TIPP: Drucken Sie die Seite auf dickerem Papier (250g+)"
puts "      und schneiden Sie entlang der grauen Linien!"

exit 0
