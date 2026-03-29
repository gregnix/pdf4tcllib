#!/usr/bin/env tclsh
# ============================================================================
# Demo 09: Header und Footer
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 09_header_footer.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 09_header_footer.tcl
# ============================================================================
# Lernziele:
#   - Header auf jeder Seite
#   - Footer mit Seitenzahl
#   - Konsistente Kopf- und Fußzeilen
#   - Mehrere Seiten verwalten
#
# Features:
#   - 3 Seiten mit Header/Footer
#   - Automatische Seitenzählung
#   - Datum im Footer
#   - Trennlinien
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

set demo_num 9
set demo_name "header_footer"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Helper Functions
# ============================================================================

# add_custom_header - Header mit Titel und Linie
proc add_custom_header {pdf ctx page_num title} {
    set pw [dict get $ctx PW]
    set margin [dict get $ctx margin_pt]
    
    $pdf setFont 12 Helvetica-Bold
    
    # Header-Text links
    $pdf text $title -x $margin -y [expr {$margin - 10}]
    
    # Seitenzahl rechts
    $pdf setFont 10 Helvetica
    $pdf text "Seite $page_num" -x [expr {$pw - $margin}] -y [expr {$margin - 10}] -align right
    
    # Linie unter Header
    $pdf setLineWidth 0.5
    $pdf line $margin [expr {$margin + 5}] [expr {$pw - $margin}] [expr {$margin + 5}]
}

# add_custom_footer - Footer mit Datum und Info
proc add_custom_footer {pdf ctx page_num total_pages} {
    set pw [dict get $ctx PW]
    set ph [dict get $ctx PH]
    set margin [dict get $ctx margin_pt]
    
    set footer_y [expr {$ph - $margin + 15}]
    
    # Linie über Footer
    $pdf setLineWidth 0.5
    $pdf line $margin [expr {$footer_y - 15}] [expr {$pw - $margin}] [expr {$footer_y - 15}]
    
    # Footer-Text
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    
    # Links: Demo-Info
    $pdf text "pdf4tcl Demo Suite" -x $margin -y $footer_y
    
    # Mitte: Seitenzahl
    set page_text "Seite $page_num von $total_pages"
    $pdf text $page_text -x [expr {$pw / 2}] -y $footer_y -align center
    
    # Rechts: Datum
    set date_text [clock format [clock seconds] -format "%Y-%m-%d"]
    $pdf text $date_text -x [expr {$pw - $margin}] -y $footer_y -align right
    
    # Farbe zurücksetzen
    $pdf setFillColor 0.0 0.0 0.0
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Header und Footer"
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
    
    # ========================================================================
    # 3 SEITEN MIT HEADER/FOOTER
    # ========================================================================
    
    set total_pages 3
    set demo_title "Demo 09: Header & Footer"
    
    # --- SEITE 1 ---
    puts "  Creating Page 1/3"
    $pdf startPage
    
    add_custom_header $pdf $ctx 1 $demo_title
    add_custom_footer $pdf $ctx 1 $total_pages
    
    # Content
    set y [expr {$sy + 40}]
    
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Seite 1" -x $sx -y $y
    
    set y [expr {$y + 35}]
    $pdf setFont 12 Helvetica
    $pdf text "Dies ist die erste Seite des Dokuments." -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf text "Jede Seite hat einen Header und Footer:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 11 Helvetica
    
    set features {
        "* Header: Titel links, Seitenzahl rechts"
        "* Trennlinie unter Header"
        "* Footer: Demo-Info links, Seitenzahl mittig, Datum rechts"
        "* Trennlinie über Footer"
    }
    
    foreach feature $features {
        $pdf text $feature -x $sx -y $y
        set y [expr {$y + 20}]
    }
    
    # Encoding-Test auf Seite 1
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Encoding-Test:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 11 Helvetica
    $pdf text "Deutsche Umlaute: äöüÄÖÜß" -x $sx -y $y
    
    set y [expr {$y + 20}]
    $pdf text "Sonderzeichen: €£¥©®™" -x $sx -y $y
    
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    
    # --- SEITE 2 ---
    puts "  Creating Page 2/3"
    $pdf startPage
    
    add_custom_header $pdf $ctx 2 $demo_title
    add_custom_footer $pdf $ctx 2 $total_pages
    
    # Content
    set y [expr {$sy + 40}]
    
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Seite 2" -x $sx -y $y
    
    set y [expr {$y + 35}]
    $pdf setFont 12 Helvetica
    $pdf text "Dies ist die zweite Seite." -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Header und Footer werden automatisch hinzugefügt:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 11 Helvetica
    
    set info_items {
        "1. Vor dem Content wird der Header gezeichnet"
        "2. Nach dem Content wird der Footer gezeichnet"
        "3. Die Seitenzahl wird automatisch aktualisiert"
        "4. Das Datum wird dynamisch generiert"
    }
    
    foreach item $info_items {
        $pdf text $item -x $sx -y $y
        set y [expr {$y + 22}]
    }
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Vorteile:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 11 Helvetica
    
    set advantages {
        "+ Konsistentes Erscheinungsbild"
        "+ Einfache Navigation (Seitenzahlen)"
        "+ Professioneller Look"
        "+ Wiederverwendbare Helper-Funktionen"
    }
    
    foreach advantage $advantages {
        $pdf text $advantage -x $sx -y $y
        set y [expr {$y + 20}]
    }
    
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    
    # --- SEITE 3 ---
    puts "  Creating Page 3/3"
    $pdf startPage
    
    add_custom_header $pdf $ctx 3 $demo_title
    add_custom_footer $pdf $ctx 3 $total_pages
    
    # Content
    set y [expr {$sy + 40}]
    
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Seite 3" -x $sx -y $y
    
    set y [expr {$y + 35}]
    $pdf setFont 12 Helvetica
    $pdf text "Dies ist die letzte Seite." -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Zusammenfassung:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 11 Helvetica
    
    set summary {
        "Demo 09 zeigt Header und Footer über mehrere Seiten."
        ""
        "Implementierung:"
        "- Helper-Funktionen für Header/Footer"
        "- Konsistente Formatierung"
        "- Automatische Seitenzählung"
        "- Dynamisches Datum"
        ""
        "Diese Technik kann für alle mehrseitigen Dokumente"
        "verwendet werden (Berichte, Handbücher, etc.)."
    }
    
    foreach line $summary {
        if {$line eq ""} {
            set y [expr {$y + 10}]
        } else {
            $pdf text $line -x $sx -y $y
            set y [expr {$y + 20}]
        }
    }
    
    # Info-Box
    set y [expr {$y + 40}]
    
    set box_x $sx
    set box_y $y
    set box_w [expr {$sw * 0.8}]
    set box_h 80
    
    # Hintergrund
    $pdf setFillColor 0.95 0.97 1.0  ;# Hellblau
    $pdf rectangle $box_x $box_y $box_w $box_h -filled 1
    
    # Rahmen
    $pdf setLineWidth 2
    $pdf setStrokeColor 0.2 0.4 0.8
    $pdf rectangle $box_x $box_y $box_w $box_h
    
    # Text
    $pdf setFillColor 0.0 0.0 0.0
    $pdf setStrokeColor 0.0 0.0 0.0
    $pdf setLineWidth 1
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text ">>> Demo 09 erfolgreich abgeschlossen! <<<" -x [expr {$box_x + 20}] -y [expr {$box_y + 25}]
    
    $pdf setFont 11 Helvetica
    $pdf text "Alle 3 Seiten haben konsistente Header und Footer." -x [expr {$box_x + 20}] -y [expr {$box_y + 45}]
    
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
