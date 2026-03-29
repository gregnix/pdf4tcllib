#!/usr/bin/env tclsh
# ============================================================================
# Demo 18: Adress-Etiketten
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 18_address_labels.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 18_address_labels.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 18  (ohne führende 0)
#   FALSCH:  set demo_num 018 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - Standard-Etikettenformate umsetzen
#   - Zweckform-kompatible Etiketten
#   - Absender und Empfänger-Layout
#   - Massen-Etiketten positionieren
#
# Features:
#   - 24 Adress-Etiketten auf A4 (3 × 8)
#   - Format: Zweckform 3475 (70mm × 36mm)
#   - Absender-Zeile (klein)
#   - Empfänger-Adresse (groß)
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
set demo_num 18
set demo_name "address_labels"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Helper: Draw Address Label
# ============================================================================

proc draw_address_label {pdf x y sender recipient} {
    # Zweckform 3475: 70mm × 36mm
    set label_w [pdf4tcllib::units::mm 70]  ;# ~198pt
    set label_h [pdf4tcllib::units::mm 36]  ;# ~102pt
    
    # Hintergrund (sehr leicht getönt)
    $pdf gsave
    $pdf setFillColor 0.99 0.99 1.0
    $pdf rectangle $x $y $label_w $label_h -filled 1
    $pdf setFillColor 0 0 0
    $pdf grestore
    
    # Rahmen (sehr dünn, gestrichelt)
    $pdf gsave
    $pdf setLineWidth 0.25
    $pdf setStrokeColor 0.85 0.85 0.85
    $pdf setLineDash 2 2
    $pdf rectangle $x $y $label_w $label_h -stroke 1
    $pdf grestore
    
    set margin 5
    
    # ========================================================================
    # Absender-Zeile (oben, klein)
    # ========================================================================
    
    set sender_y [expr {$y + $margin + 2}]
    
    $pdf setFont 6 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    
    # Sender-Zeile formatieren
    set sender_line [join $sender " - "]
    $pdf text "Abs: $sender_line" -x [expr {$x + $margin}] -y $sender_y
    
    $pdf setFillColor 0 0 0
    
    # ========================================================================
    # Empfänger-Adresse (unten, größer)
    # ========================================================================
    
    # DIN 5008 Fenster-Position (vereinfacht für Etikett)
    set recipient_y [expr {$y + [pdf4tcllib::units::mm 12]}]
    
    $pdf setFont 10 Helvetica
    
    # Empfänger-Zeilen
    set line_y $recipient_y
    set line_spacing 13
    
    foreach line $recipient {
        # Erste Zeile (Name) fett
        if {$line_y == $recipient_y} {
            $pdf setFont 10 Helvetica-Bold
        } else {
            $pdf setFont 10 Helvetica
        }
        
        $pdf text $line -x [expr {$x + $margin}] -y $line_y
        set line_y [expr {$line_y + $line_spacing}]
    }
    
    return [list $label_w $label_h]
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Adress-Etiketten"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl]"
    puts "  Output: $output_file"
    
    # ========================================================================
    # STEP 1: Create Page Context
    # ========================================================================
    
    # Kleinerer Margin für maximale Nutzung
    set ctx [pdf4tcllib::page::context a4 8 true]
    
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
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 18: Adress-Etiketten (24 auf A4)" -x $sx -y $sy
    
    # --- Info ---
    set info_y [expr {$sy + 25}]
    $pdf setFont 9 Helvetica
    $pdf text "Format: Zweckform 3475 (70mm x 36mm) | Encoding-Test: äöüÄÖÜß €" -x $sx -y $info_y
    
    # ========================================================================
    # Adress-Daten
    # ========================================================================
    
    set sender {"Musterfirma GmbH" "Hauptstr. 1" "12345 Musterstadt"}
    
    set addresses {
        {{"Max Mustermann"} {"Musterstraße 123"} {"12345 Berlin"}}
        {{"Erika Musterfrau"} {"Beispielweg 45"} {"67890 Hamburg"}}
        {{"Dr. Hans Schmidt"} {"Testgasse 7"} {"54321 München"}}
        {{"Anna Müller"} {"Demostraße 99"} {"98765 Köln"}}
        {{"Thomas Weber"} {"Hauptallee 3"} {"11111 Frankfurt"}}
        {{"Lisa Fischer"} {"Nebenweg 22"} {"22222 Stuttgart"}}
        {{"Michael Klein"} {"Seitenstraße 8"} {"33333 Düsseldorf"}}
        {{"Sandra Groß"} {"Querweg 15"} {"44444 Dortmund"}}
    }
    
    # ========================================================================
    # Layout: 3 Spalten × 8 Zeilen = 24 Etiketten
    # ========================================================================
    
    set label_w [pdf4tcllib::units::mm 70]
    set label_h [pdf4tcllib::units::mm 36]
    set spacing [pdf4tcllib::units::mm 2.5]  ;# 2.5mm Abstand
    
    set start_x $sx
    set start_y [expr {$sy + 50}]
    
    set cols 3
    set rows 8
    
    set addr_idx 0
    
    for {set row 0} {$row < $rows} {incr row} {
        for {set col 0} {$col < $cols} {incr col} {
            # Wiederholen der Adressen wenn mehr als 8
            set current_addr [lindex $addresses [expr {$addr_idx % [llength $addresses]}]]
            
            set x [expr {$start_x + $col * ($label_w + $spacing)}]
            set y [expr {$start_y + $row * ($label_h + $spacing)}]
            
            # Etikett zeichnen
            draw_address_label $pdf $x $y $sender $current_addr
            
            # Schnittlinien (sehr dünn, grau)
            $pdf gsave
            $pdf setStrokeColor 0.9 0.9 0.9
            $pdf setLineWidth 0.2
            
            # Horizontale Schnittlinien
            if {$row > 0} {
                set cut_y [expr {$y - $spacing / 2}]
                $pdf line $x $cut_y [expr {$x + $label_w}] $cut_y
            }
            
            # Vertikale Schnittlinien
            if {$col > 0} {
                set cut_x [expr {$x - $spacing / 2}]
                $pdf line $cut_x $y $cut_x [expr {$y + $label_h}]
            }
            
            $pdf grestore
            
            incr addr_idx
        }
    }
    
    # ========================================================================
    # Hinweise am unteren Rand
    # ========================================================================
    
    set note_y [expr {$start_y + $rows * ($label_h + $spacing) + 15}]
    
    $pdf setFont 8 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    
    set notes {
        "Hinweise:"
        "* Format: Zweckform 3475 kompatibel (70mm x 36mm)"
        "* 24 Etiketten auf A4 (3 Spalten x 8 Zeilen)"
        "* Absender-Zeile oben (klein, grau)"
        "* Empfänger unten (größer, Name fett)"
        "* Für Briefumschläge mit Fenster geeignet (DIN 5008)"
        "* Auf Etikettenbogen drucken (z.B. Zweckform 3475)"
    }
    
    foreach note $notes {
        $pdf text $note -x $sx -y $note_y
        set note_y [expr {$note_y + 10}]
    }
    
    $pdf setFillColor 0 0 0
    
    # --- Debug-Grid (nur wenn PDF4TCL_DEBUG=1) ---
    # pdf4tcllib::page::grid $pdf 50
    # Bewusst ausgeschaltet wegen vieler Etiketten
    
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
        puts "   ✓ Address labels: 24"
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
puts "TIPP: Drucken Sie auf Zweckform 3475 Etikettenbogen"
puts "      (70mm x 36mm, 24 Etiketten pro Bogen)"
puts "      Perfekt für Briefumschläge mit Fenster!"

exit 0
