#!/usr/bin/env tclsh
# ============================================================================
# Demo 17: Produkt-Etiketten
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 17_labels.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 17_labels.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 17  (ohne führende 0)
#   FALSCH:  set demo_num 017 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - Etiketten-Layout erstellen
#   - Grid-Positionierung
#   - Barcode-Platzhalter
#   - Professionelles Produkt-Etikett
#
# Features:
#   - 6 Produkt-Etiketten auf A4 (2 × 3)
#   - Produktname, Artikelnummer, Preis
#   - Barcode-Platzhalter
#   - Rahmen und Schnittlinien
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
set demo_num 17
set demo_name "labels"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Helper: Draw Product Label
# ============================================================================

proc draw_product_label {pdf x y product_name art_nr price} {
    # Etikett-Größe: 90mm × 60mm
    set label_w [pdf4tcllib::units::mm 90]  ;# ~255pt
    set label_h [pdf4tcllib::units::mm 60]  ;# ~170pt
    
    # Hintergrund
    $pdf gsave
    $pdf setFillColor 1 1 0.98
    $pdf rectangle $x $y $label_w $label_h -filled 1
    $pdf setFillColor 0 0 0
    $pdf grestore
    
    # Rahmen (gestrichelt)
    $pdf gsave
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.5 0.5 0.5
    $pdf setLineDash 3 2
    $pdf rectangle $x $y $label_w $label_h -stroke 1
    $pdf grestore
    
    # Innenabstand
    set margin 8
    
    # ========================================================================
    # Produktname (oben, groß)
    # ========================================================================
    
    set text_x [expr {$x + $margin}]
    set text_y [expr {$y + $margin + 5}]
    
    $pdf setFont 16 Helvetica-Bold
    $pdf text $product_name -x $text_x -y $text_y
    
    # ========================================================================
    # Artikelnummer (kleiner)
    # ========================================================================
    
    set text_y [expr {$text_y + 25}]
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.4 0.4 0.4
    $pdf text "Art.-Nr: $art_nr" -x $text_x -y $text_y
    $pdf setFillColor 0 0 0
    
    # ========================================================================
    # Preis (groß, fett, rechts)
    # ========================================================================
    
    set price_y [expr {$y + $margin + 5}]
    $pdf setFont 18 Helvetica-Bold
    $pdf text $price \
        -x [expr {$x + $label_w - $margin}] \
        -y $price_y \
        -align right
    
    # Euro-Symbol extra (falls nicht im Text)
    if {![string match "*€*" $price] && ![string match "*EUR*" $price]} {
        set euro_x [expr {$x + $label_w - $margin}]
        $pdf text "€" -x $euro_x -y [expr {$price_y + 20}] -align right
    }
    
    # ========================================================================
    # Barcode-Platzhalter (unten)
    # ========================================================================
    
    set barcode_w [expr {$label_w - 2 * $margin}]
    set barcode_h [pdf4tcllib::units::mm 15]  ;# ~42pt
    set barcode_x [expr {$x + $margin}]
    set barcode_y [expr {$y + $label_h - $barcode_h - $margin}]
    
    # Barcode-Box
    $pdf gsave
    $pdf setFillColor 0.95 0.95 0.95
    $pdf rectangle $barcode_x $barcode_y $barcode_w $barcode_h -filled 1
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.6 0.6 0.6
    $pdf setFillColor 0 0 0
    $pdf rectangle $barcode_x $barcode_y $barcode_w $barcode_h -stroke 1
    $pdf grestore
    
    # Barcode-Text
    $pdf setFont 8 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    $pdf text "Barcode: $art_nr" \
        -x [expr {$barcode_x + $barcode_w / 2}] \
        -y [expr {$barcode_y + $barcode_h / 2 - 2}] \
        -align center
    $pdf setFillColor 0 0 0
    
    # Barcode-Striche simulieren (optional, zur Visualisierung)
    $pdf gsave
    $pdf setLineWidth 1
    $pdf setStrokeColor 0.2 0.2 0.2
    
    set bar_y1 [expr {$barcode_y + 5}]
    set bar_y2 [expr {$barcode_y + $barcode_h - 5}]
    
    for {set i 0} {$i < 15} {incr i} {
        set bar_x [expr {$barcode_x + 10 + $i * ($barcode_w - 20) / 15.0}]
        if {$i % 3 == 0} {
            $pdf setLineWidth 2
        } else {
            $pdf setLineWidth 1
        }
        $pdf line $bar_x $bar_y1 $bar_x $bar_y2
    }
    
    $pdf grestore
    
    return [list $label_w $label_h]
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Produkt-Etiketten"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl]"
    puts "  Output: $output_file"
    
    # ========================================================================
    # STEP 1: Create Page Context
    # ========================================================================
    
    set ctx [pdf4tcllib::page::context a4 15 true]
    
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
    $pdf text "Demo 17: Produkt-Etiketten (6 auf A4)" -x $sx -y $sy
    
    # --- Info ---
    set info_y [expr {$sy + 25}]
    $pdf setFont 9 Helvetica
    $pdf text "Format: 90mm x 60mm | Encoding-Test: äöüÄÖÜß €" -x $sx -y $info_y
    
    # ========================================================================
    # Produkt-Daten
    # ========================================================================
    
    set products {
        {"Laptop Professional" "LP-2025-001" "1.299,99 €"}
        {"USB-C Kabel 2m" "USB-C-200" "19,99 €"}
        {"Wireless Maus" "WM-500-BLK" "39,99 €"}
        {"Tastatur RGB" "KB-RGB-DE" "89,99 €"}
        {"Monitor 27\"" "MON-27-4K" "449,99 €"}
        {"Webcam HD" "WC-1080P" "79,99 €"}
    }
    
    # ========================================================================
    # Layout: 2 Spalten × 3 Zeilen = 6 Etiketten
    # ========================================================================
    
    set label_w [pdf4tcllib::units::mm 90]
    set label_h [pdf4tcllib::units::mm 60]
    set spacing [pdf4tcllib::units::mm 5]  ;# 5mm Abstand
    
    set start_x $sx
    set start_y [expr {$sy + 50}]
    
    set cols 2
    set rows 3
    
    set idx 0
    
    for {set row 0} {$row < $rows} {incr row} {
        for {set col 0} {$col < $cols} {incr col} {
            if {$idx >= [llength $products]} break
            
            set product [lindex $products $idx]
            lassign $product prod_name art_nr price
            
            set x [expr {$start_x + $col * ($label_w + $spacing)}]
            set y [expr {$start_y + $row * ($label_h + $spacing)}]
            
            # Etikett zeichnen
            draw_product_label $pdf $x $y $prod_name $art_nr $price
            
            # Schnittlinien (grau)
            $pdf gsave
            $pdf setStrokeColor 0.85 0.85 0.85
            $pdf setLineWidth 0.25
            
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
            
            incr idx
        }
        if {$idx >= [llength $products]} break
    }
    
    # ========================================================================
    # Hinweise
    # ========================================================================
    
    set note_y [expr {$start_y + $rows * ($label_h + $spacing) + 20}]
    
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    
    set notes {
        "Hinweise:"
        "* Gestrichelte Linien = Etikett-Rahmen (optional ausschneiden)"
        "* Graue Linien = Schnittlinien"
        "* Barcode ist ein Platzhalter (echte Barcodes: siehe Barcode-Libraries)"
        "* Für Etikettendruck: Spezial-Etikettenbogen verwenden"
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
        puts "   ✓ Labels: 6"
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
puts "TIPP: Drucken Sie auf Etikettenbogen (90x60mm)"
puts "      oder schneiden Sie selbst zu!"

exit 0
