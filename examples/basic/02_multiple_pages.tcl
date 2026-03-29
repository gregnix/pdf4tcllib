#!/usr/bin/env tclsh
# ============================================================================
# Demo 02: Mehrere Seiten mit Navigation
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 02_multiple_pages.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 02_multiple_pages.tcl
# ============================================================================
# Lernziele:
#   - Mehrere Seiten in einem PDF erstellen
#   - Seitenzahlen auf jeder Seite
#   - Inhaltsverzeichnis erstellen
#   - Verschiedene Layouts pro Seite
#
# Features:
#   - 5 Seiten mit unterschiedlichem Inhalt
#   - Automatische Seitenzählung
#   - Inhaltsverzeichnis auf Seite 1
#   - Encoding-Test auf mehreren Seiten
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

set demo_num 02
set demo_name "multiple_pages"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Mehrere Seiten mit Navigation"
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
    
    # Get safe area from context
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    set pw [dict get $ctx PW]
    set ph [dict get $ctx PH]
    
    set total_pages 5
    
    # ========================================================================
    # PAGE 1: Titelseite + Inhaltsverzeichnis
    # ========================================================================
    
    puts "  Creating Page 1/5: Title & Table of Contents"
    $pdf startPage
    
    # --- Großer Titel ---
    $pdf setFont 24 Helvetica-Bold
    $pdf text "Demo 02: Mehrere Seiten" -x $sx -y $sy
    
    # --- Untertitel ---
    set y [expr {$sy + 40}]
    $pdf setFont 14 Helvetica
    $pdf text "Dokument mit Navigation und Seitenzahlen" -x $sx -y $y
    
    # --- Inhaltsverzeichnis ---
    set y [expr {$y + 60}]
    $pdf setFont 16 Helvetica-Bold
    $pdf text "Inhaltsverzeichnis:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    $pdf text "Seite 1: Titelseite und Inhaltsverzeichnis" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "Seite 2: Textseite mit Encoding-Test" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "Seite 3: Aufzählungen und Listen" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "Seite 4: Verschiedene Schriftgrößen" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "Seite 5: Zusammenfassung" -x $sx -y $y
    
    # --- Info-Box ---
    set y [expr {$y + 60}]
    
    # Rahmen zeichnen
    set box_x $sx
    set box_y $y
    set box_w [expr {$sw * 0.7}]
    set box_h 100
    
    $pdf setLineWidth 1
    $pdf setStrokeColor 0.2 0.4 0.8
    $pdf rectangle $box_x $box_y $box_w $box_h
    
    # Text in Box
    set text_x [expr {$box_x + 15}]
    set text_y [expr {$box_y + 25}]
    
    $pdf setFont 11 Helvetica-Bold
    $pdf text "Dieses Dokument demonstriert:" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 20}]
    $pdf setFont 10 Helvetica
    $pdf text "• Mehrere Seiten in einem PDF" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 18}]
    $pdf text "• Seitenzahlen auf jeder Seite" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 18}]
    $pdf text "• UTF-8 Encoding (äöüÄÖÜß€)" -x $text_x -y $text_y
    
    # --- Seitenzahl ---
    pdf4tcllib::page::number $pdf $ctx 1 $total_pages
    
    # --- Orientation Legend ---
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    
    # ========================================================================
    # PAGE 2: Textseite mit Encoding-Test
    # ========================================================================
    
    puts "  Creating Page 2/5: Text & Encoding"
    $pdf startPage
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Seite 2: Textinhalt" -x $sx -y $sy
    
    # --- Text ---
    set y [expr {$sy + 40}]
    $pdf setFont 12 Helvetica
    $pdf text "Dies ist Seite 2 des Dokuments." -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Hier demonstrieren wir verschiedene Textformatierungen" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "und die korrekte Darstellung von Sonderzeichen." -x $sx -y $y
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$y + 40}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "UTF-8 Encoding-Test:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    $pdf text "Deutsche Umlaute: äöüÄÖÜß" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Sonderzeichen: €£¥©®™" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Akzente: àèìòù ÀÈÌÒÙ" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Französisch: Ça va? Très bien!" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Spanisch: ¿Cómo estás? ¡Bien!" -x $sx -y $y
    
    # --- Zusätzlicher Text ---
    set y [expr {$y + 50}]
    $pdf setFont 10 Helvetica-Oblique
    $pdf text "Alle Zeichen werden korrekt im PDF dargestellt," -x $sx -y $y
    set y [expr {$y + 15}]
    $pdf text "wenn die richtige Encoding-Konfiguration verwendet wird." -x $sx -y $y
    
    # --- Seitenzahl ---
    pdf4tcllib::page::number $pdf $ctx 2 $total_pages
    
    # --- Orientation Legend ---
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    
    # ========================================================================
    # PAGE 3: Aufzählungen
    # ========================================================================
    
    puts "  Creating Page 3/5: Lists"
    $pdf startPage
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Seite 3: Aufzählungen" -x $sx -y $sy
    
    # --- Liste 1 ---
    set y [expr {$sy + 50}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Einfache Liste:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    set items {
        "Erster Punkt - Grundlagen"
        "Zweiter Punkt - Fortgeschritten"
        "Dritter Punkt mit Umlauten: äöüÄÖÜß"
        "Vierter Punkt mit Sonderzeichen: €©®"
        "Fünfter Punkt - Abschluss"
    }
    
    foreach item $items {
        $pdf text "• $item" -x $sx -y $y
        set y [expr {$y + 22}]
    }
    
    # --- Liste 2 ---
    set y [expr {$y + 30}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Nummerierte Liste:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    set numbered_items {
        "Installation vorbereiten"
        "Abhängigkeiten prüfen"
        "Konfiguration anpassen"
        "Tests durchführen"
        "Dokumentation lesen"
    }
    
    set num 1
    foreach item $numbered_items {
        $pdf text "$num. $item" -x $sx -y $y
        set y [expr {$y + 22}]
        incr num
    }
    
    # --- Seitenzahl ---
    pdf4tcllib::page::number $pdf $ctx 3 $total_pages
    
    # --- Orientation Legend ---
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    
    # ========================================================================
    # PAGE 4: Verschiedene Schriftgrößen
    # ========================================================================
    
    puts "  Creating Page 4/5: Font Sizes"
    $pdf startPage
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Seite 4: Verschiedene Schriftgrößen" -x $sx -y $sy
    
    # --- Verschiedene Größen demonstrieren ---
    set y [expr {$sy + 50}]
    
    set font_sizes {8 10 12 14 16 18 20 24 28 32}
    
    foreach size $font_sizes {
        $pdf setFont $size Helvetica
        $pdf text "Schriftgröße ${size}pt: Dies ist ein Beispieltext" -x $sx -y $y
        set y [expr {$y + $size + 8}]
    }
    
    # --- Zusätzliche Info ---
    set y [expr {$y + 20}]
    $pdf setFont 10 Helvetica-Oblique
    $pdf text "Standard-Schriftgrößen reichen von 8pt bis 72pt." -x $sx -y $y
    
    # --- Seitenzahl ---
    pdf4tcllib::page::number $pdf $ctx 4 $total_pages
    
    # --- Orientation Legend ---
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    
    # ========================================================================
    # PAGE 5: Zusammenfassung
    # ========================================================================
    
    puts "  Creating Page 5/5: Summary"
    $pdf startPage
    
    # --- Titel ---
    $pdf setFont 20 Helvetica-Bold
    $pdf text "Zusammenfassung" -x $sx -y $sy
    
    # --- Text ---
    set y [expr {$sy + 50}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Dieses Dokument hat demonstriert:" -x $sx -y $y
    
    set y [expr {$y + 35}]
    $pdf setFont 12 Helvetica
    
    set summary_items {
        "\[X\] Erstellung mehrerer Seiten"
        "\[X\] Automatische Seitenzählung"
        "\[X\] Inhaltsverzeichnis"
        "\[X\] UTF-8 Encoding (äöüÄÖÜß€)"
        "\[X\] Verschiedene Layouts"
        "\[X\] Listen und Aufzählungen"
        "\[X\] Verschiedene Schriftgrößen"
    }
    
    foreach item $summary_items {
        $pdf text $item -x $sx -y $y
        set y [expr {$y + 25}]
    }
    
    # --- Schluss-Box ---
    set y [expr {$y + 40}]
    
    # Großer Rahmen mit Hintergrund
    set box_x $sx
    set box_y $y
    set box_w $sw
    set box_h 80
    
    # Hintergrund
    $pdf setFillColor 0.9 0.95 1.0
    $pdf rectangle $box_x $box_y $box_w $box_h -filled 1
    
    # Rahmen
    $pdf setLineWidth 2
    $pdf setStrokeColor 0.2 0.4 0.8
    $pdf rectangle $box_x $box_y $box_w $box_h
    
    # Text in Box
    $pdf setFillColor 0 0 0
    set text_x [expr {$box_x + 20}]
    set text_y [expr {$box_y + 30}]
    
    $pdf setFont 16 Helvetica-Bold
    $pdf text ">>> Demo 02 erfolgreich abgeschlossen! <<<" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 25}]
    $pdf setFont 11 Helvetica
    $pdf text "Alle 5 Seiten wurden korrekt erstellt." -x $text_x -y $text_y
    
    # --- Seitenzahl ---
    pdf4tcllib::page::number $pdf $ctx 5 $total_pages
    
    # --- Orientation Legend ---
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    
    # ========================================================================
    # STEP 4: Finish & Save
    # ========================================================================
    
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
        puts "   ✓ Pages: $total_pages"
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
