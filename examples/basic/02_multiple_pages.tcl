#!/usr/bin/env tclsh
# ============================================================================
# Demo 02: Several pages mit Navigation
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS:
#   For correct umlauts (aeoeueAEOEUEss, euro sign) use:
#     tclsh examples/main.tcl 02_multiple_pages.tcl
#
#   NOT directly -- that gives wrong characters in the PDF:
#     tclsh 02_multiple_pages.tcl
# ============================================================================
# What this shows:
#   - Mehrere Seiten in einem PDF erstellen
#   - Seitenzahlen auf jeder Seite
#   - a table of contents erstellen
#   - Verschiedene Layouts pro Seite
#
# Features:
#   - 5 Seiten mit unterschiedlichem Inhalt
#   - automatic page numbering
#   - a table of contents auf Seite 1
#   - Encoding-Test auf mehreren Seiten
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
    
    # --- the big title ---
    $pdf setFont 24 Helvetica-Bold
    $pdf text "Demo 02: Several pages" -x $sx -y $sy
    
    # --- Untertitel ---
    set y [expr {$sy + 40}]
    $pdf setFont 14 Helvetica
    $pdf text "A document with navigation and page numbers" -x $sx -y $y
    
    # --- Inhaltsverzeichnis ---
    set y [expr {$y + 60}]
    $pdf setFont 16 Helvetica-Bold
    $pdf text "Contents:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    $pdf text "Page 1: title page and contents" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "Page 2: text with an encoding test" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "Page 3: bullets and lists" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "Page 4: different type sizes" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "Page 5: summary" -x $sx -y $y
    
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
    $pdf text "What this document shows:" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 20}]
    $pdf setFont 10 Helvetica
    $pdf text "\u2022 several pages in one PDF" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 18}]
    $pdf text "\u2022 a page number on every page" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 18}]
    $pdf text "• UTF-8 encoding (\u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df\u20ac)" -x $text_x -y $text_y
    
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
    $pdf text "Page 2: text" -x $sx -y $sy
    
    # --- Text ---
    set y [expr {$sy + 40}]
    $pdf setFont 12 Helvetica
    $pdf text "This is page 2 of the document." -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Hier demonstrieren wir verschiedene Textformatierungen" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "und die korrekte Darstellung von Sonderzeichen." -x $sx -y $y
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$y + 40}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "UTF-8 Encoding test:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    $pdf text "German umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Symbols: \u20ac\u00a3\u00a5\u00a9\u00ae\u2122" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Akzente: àèìòù ÀÈÌÒÙ" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "French: \u00c7a va? Tr\u00e8s bien!" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Spanisch: ¿Cómo estás? ¡Bien!" -x $sx -y $y
    
    # --- more text ---
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
    # PAGE 3: bullets
    # ========================================================================
    
    puts "  Creating Page 3/5: Lists"
    $pdf startPage
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Page 3: bullets" -x $sx -y $sy
    
    # --- Liste 1 ---
    set y [expr {$sy + 50}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Einfache Liste:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 12 Helvetica
    
    set items {
        "Erster Punkt - Grundlagen"
        "Zweiter Punkt - Fortgeschritten"
        "Third item with umlauts: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df"
        "Vierter Punkt mit Sonderzeichen: €©®"
        "Fifth item -- the end"
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
        "Check dependencies"
        "Konfiguration anpassen"
        "Run the tests"
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
    # PAGE 4: type sizes
    # ========================================================================
    
    puts "  Creating Page 4/5: Font Sizes"
    $pdf startPage
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Page 4: different type sizes" -x $sx -y $sy
    
    # --- sizes side by side ---
    set y [expr {$sy + 50}]
    
    set font_sizes {8 10 12 14 16 18 20 24 28 32}
    
    foreach size $font_sizes {
        $pdf setFont $size Helvetica
        $pdf text "Size ${size}pt: this is a sample line" -x $sx -y $y
        set y [expr {$y + $size + 8}]
    }
    
    # --- more information ---
    set y [expr {$y + 20}]
    $pdf setFont 10 Helvetica-Oblique
    $pdf text "Common type sizes run from 8pt to 72pt." -x $sx -y $y
    
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
        "\[X\] automatic page numbering"
        "\[X\] Inhaltsverzeichnis"
        "\[X\] UTF-8 encoding (\u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df\u20ac)"
        "\[X\] Verschiedene Layouts"
        "\[X\] lists and bullets"
        "\[X\] different type sizes"
    }
    
    foreach item $summary_items {
        $pdf text $item -x $sx -y $y
        set y [expr {$y + 25}]
    }
    
    # --- Schluss-Box ---
    set y [expr {$y + 40}]
    
    # a large framed box with a background
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
