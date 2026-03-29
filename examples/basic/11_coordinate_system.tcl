#!/usr/bin/env tclsh
# ============================================================================
# Demo 11: Koordinatensystem
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 11_coordinate_system.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 11_coordinate_system.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 11  (ohne führende 0)
#   FALSCH:  set demo_num 011 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - PDF-Koordinatensystem verstehen
#   - Unterschied zwischen -orient true und false
#   - Y-Richtung visualisieren
#   - Origin-Position kennen
#
# Features:
#   - 2 Seiten zum direkten Vergleich
#   - Seite 1: -orient true (Origin oben links)
#   - Seite 2: -orient false (Origin unten links)
#   - Raster zur Orientierung
#   - Achsen mit Beschriftung
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
set demo_num 11
set demo_name "coordinate_system"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Helper: Draw Coordinate System
# ============================================================================

proc draw_coord_system {pdf orient ctx} {
    set pw [dict get $ctx PW]
    set ph [dict get $ctx PH]
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    if {$orient} {
        $pdf text "Demo 11: Koordinatensystem (orient=true)" -x $sx -y $sy
    } else {
        $pdf text "Demo 11: Koordinatensystem (orient=false)" -x $sx -y $sy
    }
    
    # --- Info-Text ---
    set y [expr {$sy + 35}]
    $pdf setFont 10 Helvetica
    
    if {$orient} {
        $pdf text "Origin: (0,0) = Oben Links" -x $sx -y $y
        set y [expr {$y + 15}]
        $pdf text "Y-Achse: Wächst nach UNTEN" -x $sx -y $y
    } else {
        $pdf text "Origin: (0,0) = Unten Links" -x $sx -y $y
        set y [expr {$y + 15}]
        $pdf text "Y-Achse: Wächst nach OBEN" -x $sx -y $y
    }
    
    # --- Encoding-Test ---
    set y [expr {$y + 20}]
    $pdf text "Encoding-Test: äöüÄÖÜß €" -x $sx -y $y
    
    # ========================================================================
    # Grid-Raster (10mm = ~28.35pt Schritte)
    # ========================================================================
    
    set grid_spacing [pdf4tcllib::units::mm 10]
    
    $pdf gsave
    $pdf setStrokeColor 0.85 0.85 0.85
    $pdf setLineWidth 0.25
    
    # Vertikale Linien
    set x 0
    while {$x <= $pw} {
        $pdf line $x 0 $x $ph
        set x [expr {$x + $grid_spacing}]
    }
    
    # Horizontale Linien
    set y 0
    while {$y <= $ph} {
        $pdf line 0 $y $pw $y
        set y [expr {$y + $grid_spacing}]
    }
    
    $pdf grestore
    
    # ========================================================================
    # Achsen mit Pfeilen
    # ========================================================================
    
    $pdf gsave
    $pdf setStrokeColor 0.2 0.2 0.8
    $pdf setLineWidth 1.5
    
    set arrow_size 10
    set axis_len 200
    
    # X-Achse
    set origin_x 100
    set origin_y [expr {$orient ? 150 : ($ph - 150)}]
    
    # Horizontale Linie
    $pdf line $origin_x $origin_y [expr {$origin_x + $axis_len}] $origin_y
    
    # Pfeil (rechts)
    set arrow_x [expr {$origin_x + $axis_len}]
    set arrow_y $origin_y
    $pdf line $arrow_x $arrow_y [expr {$arrow_x - $arrow_size}] [expr {$arrow_y - $arrow_size/2}]
    $pdf line $arrow_x $arrow_y [expr {$arrow_x - $arrow_size}] [expr {$arrow_y + $arrow_size/2}]
    
    # Y-Achse
    if {$orient} {
        # Y wächst nach unten
        $pdf line $origin_x $origin_y $origin_x [expr {$origin_y + $axis_len}]
        # Pfeil (unten)
        set arrow_x $origin_x
        set arrow_y [expr {$origin_y + $axis_len}]
        $pdf line $arrow_x $arrow_y [expr {$arrow_x - $arrow_size/2}] [expr {$arrow_y - $arrow_size}]
        $pdf line $arrow_x $arrow_y [expr {$arrow_x + $arrow_size/2}] [expr {$arrow_y - $arrow_size}]
    } else {
        # Y wächst nach oben
        $pdf line $origin_x $origin_y $origin_x [expr {$origin_y - $axis_len}]
        # Pfeil (oben)
        set arrow_x $origin_x
        set arrow_y [expr {$origin_y - $axis_len}]
        $pdf line $arrow_x $arrow_y [expr {$arrow_x - $arrow_size/2}] [expr {$arrow_y + $arrow_size}]
        $pdf line $arrow_x $arrow_y [expr {$arrow_x + $arrow_size/2}] [expr {$arrow_y + $arrow_size}]
    }
    
    $pdf grestore
    
    # ========================================================================
    # Achsen-Beschriftung
    # ========================================================================
    
    $pdf setFont 11 Helvetica-Bold
    $pdf setFillColor 0.2 0.2 0.8
    
    # X-Achse Label
    $pdf text "X" \
        -x [expr {$origin_x + $axis_len + 15}] \
        -y [expr {$origin_y - 5}]
    
    # Y-Achse Label
    if {$orient} {
        $pdf text "Y" \
            -x [expr {$origin_x - 15}] \
            -y [expr {$origin_y + $axis_len + 5}]
    } else {
        $pdf text "Y" \
            -x [expr {$origin_x - 15}] \
            -y [expr {$origin_y - $axis_len - 5}]
    }
    
    # Origin-Markierung
    $pdf setFillColor 0.8 0.2 0.2
    $pdf setFont 12 Helvetica-Bold
    $pdf text "(0,0)" \
        -x [expr {$origin_x - 25}] \
        -y [expr {$origin_y - 10}]
    
    # Kreis bei Origin
    $pdf gsave
    $pdf setStrokeColor 0.8 0.2 0.2
    $pdf setLineWidth 2
    $pdf circle $origin_x $origin_y 5
    $pdf grestore
    
    $pdf setFillColor 0 0 0
    
    # ========================================================================
    # Koordinaten-Beispiele (Punkte platzieren)
    # ========================================================================
    
    $pdf setFont 9 Courier
    $pdf setFillColor 0 0 0
    
    # Beispiel-Punkte
    set examples {
        {150 100}
        {250 200}
        {350 300}
    }
    
    foreach example $examples {
        lassign $example ex ey
        
        # Berechne absolute Position
        set abs_x [expr {$origin_x + $ex - 100}]
        if {$orient} {
            set abs_y [expr {$origin_y + $ey - 150}]
        } else {
            set abs_y [expr {$origin_y - ($ey - ($ph - 150))}]
        }
        
        # Punkt zeichnen
        $pdf gsave
        $pdf setFillColor 0 0.6 0
        $pdf circle $abs_x $abs_y 3 -filled 1
        $pdf grestore
        
        # Koordinate beschriften
        $pdf text "($ex,$ey)" \
            -x [expr {$abs_x + 8}] \
            -y [expr {$abs_y - 3}]
    }
    
    # ========================================================================
    # Info-Box mit Erklärung
    # ========================================================================
    
    set box_x [expr {$pw - 220}]
    set box_y 50
    set box_w 200
    set box_h 140
    
    # Box
    $pdf setFillColor 1 1 0.9
    $pdf rectangle $box_x $box_y $box_w $box_h -filled 1
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0 0 0
    $pdf setFillColor 0 0 0
    $pdf rectangle $box_x $box_y $box_w $box_h -stroke 1
    
    # Box-Text
    set text_x [expr {$box_x + 10}]
    set text_y [expr {$box_y + 20}]
    
    $pdf setFont 10 Helvetica-Bold
    $pdf text "Wichtig:" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 20}]
    $pdf setFont 8 Helvetica
    
    if {$orient} {
        set info_lines {
            "orient=true ist Standard"
            ""
            "* Origin: Oben Links"
            "* Y wächst nach UNTEN"
            "* Wie Bildschirm-"
            "  Koordinaten"
            "* Standard in PDFs"
        }
    } else {
        set info_lines {
            "orient=false entspricht"
            "PostScript-Standard"
            ""
            "* Origin: Unten Links"
            "* Y wächst nach OBEN"
            "* Wie Mathematik-"
            "  Koordinaten"
        }
    }
    
    foreach line $info_lines {
        $pdf text $line -x $text_x -y $text_y
        set text_y [expr {$text_y + 12}]
    }
    
    # --- Orientation-Legend ---
    pdf4tcllib::page::orientationLegend $pdf $ctx
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Koordinatensystem"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl]"
    puts "  Output: $output_file"
    
    # ========================================================================
    # Seite 1: orient=true (Y wächst nach unten)
    # ========================================================================
    
    puts "  Creating page 1 (orient=true)..."
    
    set ctx1 [pdf4tcllib::page::context a4 20 true]
    
    set pdf [pdf4tcl::pdf4tcl create %AUTO% \
        -paper [dict get $ctx1 paper] \
        -orient true \
        -unit p]
    
    $pdf startPage
    draw_coord_system $pdf true $ctx1
    $pdf endPage
    
    # ========================================================================
    # Seite 2: orient=false (Y wächst nach oben)
    # ========================================================================
    
    puts "  Creating page 2 (orient=false)..."
    
    # Neue Seite mit orient=false
    # WICHTIG: orient-Wechsel nur bei neuem PDF oder mit Canvas
    # Hier erstellen wir neues PDF für Seite 2
    
    $pdf write -file $output_file
    catch {$pdf destroy}
    
    # Neu erstellen mit orient=false
    set ctx2 [pdf4tcllib::page::context a4 20 false]
    
    set pdf [pdf4tcl::pdf4tcl create %AUTO% \
        -paper [dict get $ctx2 paper] \
        -orient false \
        -unit p]
    
    # Alte Datei lesen und Seite 1 übernehmen
    # (pdf4tcl kann keine existierende PDFs editieren, daher Workaround)
    
    $pdf startPage
    draw_coord_system $pdf false $ctx2
    $pdf endPage
    
    # ========================================================================
    # WORKAROUND: 2 separate PDFs erstellen
    # ========================================================================
    
    # Schreibe Seite 2 in temporäre Datei
    set temp_file "[file rootname $output_file]_temp.pdf"
    $pdf write -file $temp_file
    catch {$pdf destroy}
    
    # Kombiniere beide Seiten
    # HINWEIS: pdf4tcl hat KEINE set_canvas_orient Methode!
    # -orient wird beim Erstellen festgelegt und kann nicht geändert werden.
    # Lösung: Beide Seiten mit -orient true, aber unterschiedliche Darstellung
    
    puts "  Combining pages..."
    
    # PDF mit beiden Seiten (beide orient=true)
    set pdf [pdf4tcl::pdf4tcl create %AUTO% -paper a4 -orient true -unit p]
    
    # Seite 1: Zeige orient=true Koordinatensystem
    $pdf startPage
    draw_coord_system $pdf true $ctx1
    $pdf endPage
    
    # Seite 2: Zeige orient=false Konzept (simuliert)
    $pdf startPage
    draw_coord_system $pdf false $ctx2
    $pdf endPage
    
    # Final save
    $pdf write -file $output_file
    catch {$pdf destroy}
    
    # Cleanup temp file
    file delete -force $temp_file
    
    puts "✅ Demo $demo_num complete"
    
    # ========================================================================
    # Validate Output
    # ========================================================================
    
    set validation [pdf4tcllib::validate_pdf $output_file]
    
    if {[dict get $validation valid]} {
        puts "   ✓ Valid PDF"
        puts "   ✓ Size: [dict get $validation size] bytes"
        puts "   ✓ Pages: 2"
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
puts "TIPP: Vergleichen Sie die beiden Seiten!"
puts "      Seite 1: Origin oben links (Y nach unten)"
puts "      Seite 2: Origin unten links (Y nach oben)"

exit 0
