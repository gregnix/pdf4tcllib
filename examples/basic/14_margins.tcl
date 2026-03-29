#!/usr/bin/env tclsh
# ============================================================================
# Demo 14: Margins & Safe Area
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 14_margins.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 14_margins.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 14  (ohne führende 0)
#   FALSCH:  set demo_num 014 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - Margins und Safe Area verstehen
#   - Warum Margins wichtig sind
#   - DIN 5008 Margins für Geschäftsbriefe
#   - PageContext nutzen
#
# Features:
#   - Visualisierung der Safe Area
#   - Papier-Rand vs. Inhalt-Bereich
#   - Verschiedene Margin-Größen
#   - Praktische Beispiele
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
    $pdf text "Demo 14: Margins & Safe Area" -x $sx -y $sy
    
    # --- Encoding-Test ---
    set y [expr {$sy + 30}]
    $pdf setFont 10 Helvetica
    $pdf text "Encoding-Test: äöüÄÖÜß €" -x $sx -y $y
    
    # ========================================================================
    # Visualisierung: Ganze Seite
    # ========================================================================
    
    # Papier-Rand (äußerer Rand)
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
    $pdf text "Legende:" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 20}]
    
    # Rot: Papier-Rand
    $pdf gsave
    $pdf setStrokeColor 1 0.5 0.5
    $pdf setLineWidth 2
    $pdf line $text_x $text_y [expr {$text_x + 20}] $text_y
    $pdf grestore
    
    $pdf setFont 9 Helvetica
    $pdf text "Papier-Rand" -x [expr {$text_x + 25}] -y [expr {$text_y - 3}]
    
    set text_y [expr {$text_y + 18}]
    
    # Grün: Safe Area
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
    $pdf text "Was sind Margins?" -x $sx -y $info_y
    
    set info_y [expr {$info_y + 25}]
    $pdf setFont 10 Helvetica
    
    set info_lines {
        "Margins (Ränder) sind der Abstand zwischen Papier-Rand und Inhalt."
        ""
        "Warum sind Margins wichtig?"
        "* Drucker können oft nicht bis zum Rand drucken"
        "* Text am Rand ist schwer lesbar"
        "* Professionelles Aussehen"
        "* Platz für Lochen, Heften, Binden"
        "* DIN 5008 Standard für Geschäftsbriefe"
    }
    
    foreach line $info_lines {
        $pdf text $line -x $sx -y $info_y
        set info_y [expr {$info_y + 15}]
    }
    
    # ========================================================================
    # Margin-Größen Tabelle
    # ========================================================================
    
    set info_y [expr {$info_y + 20}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Standard-Margins" -x $sx -y $info_y
    
    set info_y [expr {$info_y + 25}]
    
    set margin_data {
        {"Anwendung" "Margin (mm)" "Margin (pt)" "Verwendung"}
        {"Standard" "20" "57" "Allgemein"}
        {"Minimal" "10" "28" "Maximaler Platz"}
        {"DIN 5008" "25 (links)" "71" "Geschäftsbriefe"}
        {"Buch/Print" "15-20" "43-57" "Druckprodukte"}
    }
    
    set col_widths {100 80 80 120}
    
    pdf4tcllib::table::simpleTable $pdf $sx $info_y $col_widths $margin_data \
        -zebra 1 \
        -row_height 22 \
        -font_size 9
    
    # ========================================================================
    # Maße anzeigen
    # ========================================================================
    
    set measure_y [expr {$info_y + [expr {[llength $margin_data] * 22}] + 30}]
    
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Dieses Dokument" -x $sx -y $measure_y
    
    set measure_y [expr {$measure_y + 25}]
    $pdf setFont 10 Courier
    
    set measures [list \
        "Papier-Größe:   $pw x $ph pt  (595 x 842 pt = A4)" \
        "Margin:         $margin_mm mm  ($margin_pt pt)" \
        "Safe Area:      $sw x $sh pt" \
        "Safe Area Pos:  ($sx, $sy) pt" \
    ]
    
    foreach measure $measures {
        $pdf text $measure -x $sx -y $measure_y
        set measure_y [expr {$measure_y + 15}]
    }
    
    # ========================================================================
    # Code-Beispiel
    # ========================================================================
    
    set measure_y [expr {$measure_y + 20}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Code-Beispiel: PageContext nutzen" -x $sx -y $measure_y
    
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
    # Maß-Annotationen auf der Seite
    # ========================================================================
    
    # Margin-Maße mit Pfeilen
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
puts "      Rot  = Papier-Rand (nicht bedruckbar)"
puts "      Grün = Safe Area (Inhalt hier platzieren)"

exit 0
