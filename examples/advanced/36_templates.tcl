#!/usr/bin/env tclsh
# ============================================================================
# Demo 36: Seiten-Templates
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 36_templates.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 36_templates.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 36  (ohne führende 0)
#   FALSCH:  set demo_num 036 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - Wiederverwendbare Seiten-Templates erstellen
#   - Template-Funktionen definieren
#   - Verschiedene Layouts organisieren
#   - Professionelle Dokument-Struktur
#
# Features:
#   - Template 1: Titel-Seite (zentriert, groß)
#   - Template 2: Inhalts-Seite (Header, Footer, Body)
#   - Template 3: Anhang-Seite (klein, kompakt)
#   - Wiederverwendbare Funktionen
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
set demo_num 36
set demo_name "templates"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Template 1: Title Page
# ============================================================================

proc template_title {pdf ctx title subtitle author} {
    set pw [dict get $ctx PW]
    set ph [dict get $ctx PH]
    
    set center_x [expr {$pw / 2.0}]
    set center_y [expr {$ph / 2.0}]
    
    # Titel (groß, zentriert)
    $pdf setFont 32 Helvetica-Bold
    $pdf text $title \
        -x $center_x \
        -y [expr {$center_y - 60}] \
        -align center
    
    # Untertitel
    $pdf setFont 18 Helvetica
    $pdf text $subtitle \
        -x $center_x \
        -y [expr {$center_y - 20}] \
        -align center
    
    # Autor (unten)
    $pdf setFont 14 Helvetica-Oblique
    $pdf text $author \
        -x $center_x \
        -y [expr {$ph - 100}] \
        -align center
    
    # Datum
    set date [clock format [clock seconds] -format "%d.%m.%Y"]
    $pdf setFont 12 Helvetica
    $pdf text $date \
        -x $center_x \
        -y [expr {$ph - 80}] \
        -align center
    
    # Dekorative Linie
    $pdf gsave
    $pdf setStrokeColor 0.3 0.3 0.3
    $pdf setLineWidth 2
    $pdf line \
        [expr {$center_x - 100}] [expr {$center_y + 10}] \
        [expr {$center_x + 100}] [expr {$center_y + 10}]
    $pdf grestore
}

# ============================================================================
# Template 2: Content Page
# ============================================================================

proc template_content {pdf ctx title body page_num total_pages} {
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    set pw [dict get $ctx PW]
    set ph [dict get $ctx PH]
    
    # --- Header ---
    $pdf setFont 14 Helvetica-Bold
    $pdf text $title -x $sx -y $sy
    
    # Header-Linie
    $pdf gsave
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf setLineWidth 0.5
    $pdf line $sx [expr {$sy + 18}] [expr {$sx + $sw}] [expr {$sy + 18}]
    $pdf grestore
    
    # --- Body ---
    set body_y [expr {$sy + 35}]
    $pdf setFont 11 Helvetica
    
    foreach line [split $body "\n"] {
        if {$line eq ""} {
            set body_y [expr {$body_y + 8}]
        } else {
            $pdf text $line -x $sx -y $body_y
            set body_y [expr {$body_y + 15}]
        }
        
        # Prüfe ob noch Platz
        if {$body_y > [expr {$ph - 80}]} {
            break
        }
    }
    
    # --- Footer ---
    set footer_y [expr {$ph - 50}]
    
    # Footer-Linie
    $pdf gsave
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf setLineWidth 0.5
    $pdf line $sx [expr {$footer_y - 10}] [expr {$sx + $sw}] [expr {$footer_y - 10}]
    $pdf grestore
    
    # Seitenzahl
    $pdf setFont 9 Helvetica
    $pdf text "Seite $page_num von $total_pages" \
        -x [expr {$sx + $sw}] \
        -y $footer_y \
        -align right
    
    # Datum
    set date [clock format [clock seconds] -format "%d.%m.%Y"]
    $pdf text $date -x $sx -y $footer_y
}

# ============================================================================
# Template 3: Appendix Page
# ============================================================================

proc template_appendix {pdf ctx content page_num} {
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    
    # Titel (kleiner)
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Anhang - Seite $page_num" -x $sx -y $sy
    
    # Inhalt (kompakter)
    set y [expr {$sy + 25}]
    $pdf setFont 9 Helvetica
    
    foreach line [split $content "\n"] {
        if {$line eq ""} {
            set y [expr {$y + 5}]
        } else {
            $pdf text $line -x $sx -y $y
            set y [expr {$y + 12}]
        }
    }
    
    # Box um Anhang
    $pdf gsave
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.25
    $pdf rectangle [expr {$sx - 5}] [expr {$sy - 5}] [expr {$sw + 10}] [expr {$y - $sy + 10}] -stroke 1
    $pdf grestore
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Templates"
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
    # Seite 1: Titel-Template
    # ========================================================================
    
    puts "  Creating page 1 (Title template)..."
    
    $pdf startPage
    
    template_title $pdf $ctx \
        "Demo 36: Seiten-Templates" \
        "Wiederverwendbare Layouts für PDFs" \
        "pdf4tcl Demo Suite"
    
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    
    # ========================================================================
    # Seite 2-3: Inhalts-Template
    # ========================================================================
    
    set body1 "Dies ist eine Inhalts-Seite mit dem Standard-Template.

Das Template enthält:
- Header mit Titel
- Body mit Textinhalt
- Footer mit Seitenzahl und Datum

Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

Duis aute irure dolor in reprehenderit in voluptate velit esse
cillum dolore eu fugiat nulla pariatur.

Encoding-Test: äöüÄÖÜß €"
    
    puts "  Creating page 2 (Content template #1)..."
    
    $pdf startPage
    template_content $pdf $ctx "Kapitel 1: Einführung" $body1 2 4
    pdf4tcllib::page::orientationLegend $pdf $ctx
    $pdf endPage
    
    set body2 "Dies ist eine weitere Inhalts-Seite.

Das gleiche Template kann für beliebig viele Seiten verwendet werden.
Jede Seite erhält automatisch:
- Den korrekten Header
- Die richtige Seitennummer
- Das aktuelle Datum

Die Templates sind wiederverwendbar und anpassbar.

Vorteile von Templates:
- Konsistentes Layout
- Weniger Code-Duplikation
- Einfache Wartung
- Professionelles Aussehen

Encoding-Test: äöüÄÖÜß €"
    
    puts "  Creating page 3 (Content template #2)..."
    
    $pdf startPage
    template_content $pdf $ctx "Kapitel 2: Templates" $body2 3 4
    pdf4tcllib::page::orientationLegend $pdf $ctx
    $pdf endPage
    
    # ========================================================================
    # Seite 4: Anhang-Template
    # ========================================================================
    
    set appendix "Technische Details:

Template-Funktionen:
- template_title: Titel-Seite (zentriert, groß)
- template_content: Standard-Inhaltsseite
- template_appendix: Kompakte Anhang-Seite

Verwendung:
template_content \$pdf \$ctx \"Titel\" \"Body\" \$page \$total

Parameter:
- pdf: PDF-Objekt
- ctx: Page Context
- title: Seiten-Titel
- body: Textinhalt
- page_num: Aktuelle Seitenzahl
- total_pages: Gesamtseitenzahl

Encoding-Test: äöüÄÖÜß €"
    
    puts "  Creating page 4 (Appendix template)..."
    
    $pdf startPage
    template_appendix $pdf $ctx $appendix 4
    pdf4tcllib::page::orientationLegend $pdf $ctx
    $pdf endPage
    
    # ========================================================================
    # STEP 4: Finish
    # ========================================================================
    
    $pdf write -file $output_file
    $pdf destroy
    
    puts "✅ Demo $demo_num complete"
    
    # ========================================================================
    # Validate Output
    # ========================================================================
    
    set validation [pdf4tcllib::validate_pdf $output_file]
    
    if {[dict get $validation valid]} {
        puts "   ✓ Valid PDF"
        puts "   ✓ Size: [dict get $validation size] bytes"
        puts "   ✓ Pages: 4"
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
puts "TIPP: Beachten Sie die 3 verschiedenen Templates:"
puts "      1. Titel-Seite (zentriert)"
puts "      2. Inhalts-Seiten (Header+Footer)"
puts "      3. Anhang (kompakt)"

exit 0
