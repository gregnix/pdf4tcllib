#!/usr/bin/env tclsh
# ============================================================================
# Demo 08: Bilder einbinden
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 08_images.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 08_images.tcl
# ============================================================================
# Lernziele:
#   - Bilder in PDF einbinden
#   - Bilder skalieren
#   - Image-Ressourcen freigeben
#   - Fallback wenn Bild nicht existiert
#
# Features:
#   - Bild laden (wenn vorhanden)
#   - Verschiedene Skalierungen
#   - Platzhalter wenn Bild fehlt
#   - Korrekte Ressourcen-Verwaltung
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

set demo_num 8
set demo_name "images"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Bilder einbinden"
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
    $pdf text "Demo 08: Bilder einbinden" -x $sx -y $sy
    
    set y [expr {$sy + 40}]
    
    # --- Prüfe ob Test-Bild existiert ---
    set img_paths [list \
        [file join $scriptDir images test_image.png] \
        [file join $scriptDir images test_image.png] \
        [file join $scriptDir pdf test_image.png] \
    ]
    
    set img_path ""
    set img_found false
    
    foreach path $img_paths {
        if {[file exists $path]} {
            set img_path $path
            set img_found true
            puts "  Found test image: $img_path"
            break
        }
    }
    
    if {!$img_found} {
        puts "  ⚠️  WARNING: Test image not found"
        puts "     Searched paths:"
        foreach path $img_paths {
            puts "       - $path"
        }
        puts "     Creating placeholder instead"
    }
    
    # --- Bild oder Platzhalter ---
    if {$img_found} {
        # === MIT BILD ===
        $pdf setFont 12 Helvetica-Bold
        $pdf text "Bild gefunden: [file tail $img_path]" -x $sx -y $y
        
        set y [expr {$y + 30}]
        
        # Bild laden
        if {[catch {set img [$pdf loadImage $img_path]} err]} {
            puts "  ⚠️  ERROR loading image: $err"
            set img_found false
        } else {
            puts "  Image loaded successfully"
            
            # Originalgröße
            $pdf setFont 10 Helvetica
            $pdf text "1. Originalgröße:" -x $sx -y $y
            
            set y [expr {$y + 15}]
            set img_y $y
            
            # WICHTIG: Catch für putImage - falls Format nicht unterstützt
            if {[catch {$pdf putImage $img -x $sx -y $img_y} err]} {
                puts "  ⚠️  ERROR displaying image: $err"
                $pdf text "ERROR: Bildformat nicht unterstützt" -x $sx -y $img_y
            } else {
                # Erfolgreich
            }
            
            set y [expr {$y + 160}]
            
            # Skaliert (klein)
            $pdf text "2. Skaliert (100x75):" -x $sx -y $y
            
            set y [expr {$y + 15}]
            set img_y2 $y
            
            if {[catch {$pdf putImage $img -x $sx -y $img_y2 -width 100 -height 75} err]} {
                $pdf text "ERROR: Kann nicht skalieren" -x $sx -y $img_y2
            }
            
            set y [expr {$y + 90}]
            
            # Skaliert (mittel)
            $pdf text "3. Skaliert (150x112):" -x $sx -y $y
            
            set y [expr {$y + 15}]
            set img_y3 $y
            
            if {[catch {$pdf putImage $img -x $sx -y $img_y3 -width 150 -height 112} err]} {
                $pdf text "ERROR: Kann nicht skalieren" -x $sx -y $img_y3
            }
            
            set y [expr {$y + 130}]
            
            # WICHTIG: Image aufräumen!
            $pdf freeImage $img
            puts "  Image resources freed"
        }
    }
    
    if {!$img_found} {
        # === PLATZHALTER (kein Bild gefunden) ===
        $pdf setFont 12 Helvetica-Bold
        $pdf text "Kein Test-Bild gefunden - Zeige Platzhalter:" -x $sx -y $y
        
        set y [expr {$y + 30}]
        
        # Platzhalter 1: Groß
        $pdf setFont 10 Helvetica
        $pdf text "Platzhalter (200x150):" -x $sx -y $y
        
        set y [expr {$y + 15}]
        set box_y $y
        
        # Platzhalter-Box zeichnen
        $pdf setFillColor 0.95 0.95 0.95  ;# Hellgrau
        $pdf rectangle $sx $box_y 200 150 -filled 1
        
        $pdf setLineWidth 2
        $pdf setStrokeColor 0.6 0.6 0.6
        $pdf rectangle $sx $box_y 200 150
        
        # Diagonalen
        $pdf setLineWidth 1
        $pdf line $sx $box_y [expr {$sx + 200}] [expr {$box_y + 150}]
        $pdf line [expr {$sx + 200}] $box_y $sx [expr {$box_y + 150}]
        
        # Text im Platzhalter
        $pdf setFillColor 0.4 0.4 0.4
        $pdf setFont 14 Helvetica-Bold
        $pdf text "BILD" -x [expr {$sx + 80}] -y [expr {$box_y + 70}]
        
        $pdf setFillColor 0.0 0.0 0.0
        $pdf setStrokeColor 0.0 0.0 0.0
        
        set y [expr {$y + 170}]
        
        # Platzhalter 2: Klein
        $pdf setFont 10 Helvetica
        $pdf text "Platzhalter klein (100x75):" -x $sx -y $y
        
        set y [expr {$y + 15}]
        set box_y2 $y
        
        $pdf setFillColor 0.9 0.95 1.0  ;# Hellblau
        $pdf rectangle $sx $box_y2 100 75 -filled 1
        
        $pdf setLineWidth 1
        $pdf setStrokeColor 0.4 0.6 0.8
        $pdf rectangle $sx $box_y2 100 75
        
        $pdf line $sx $box_y2 [expr {$sx + 100}] [expr {$box_y2 + 75}]
        $pdf line [expr {$sx + 100}] $box_y2 $sx [expr {$box_y2 + 75}]
        
        $pdf setFillColor 0.2 0.4 0.6
        $pdf setFont 10 Helvetica-Bold
        $pdf text "Bild" -x [expr {$sx + 35}] -y [expr {$box_y2 + 35}]
        
        $pdf setFillColor 0.0 0.0 0.0
        $pdf setStrokeColor 0.0 0.0 0.0
        
        set y [expr {$y + 95}]
    }
    
    # --- Info-Text ---
    $pdf setFont 11 Helvetica
    $pdf text "Hinweis: Zum Testen ein test_image.png in tests/ ablegen." -x $sx -y $y
    
    set y [expr {$y + 20}]
    $pdf setFont 10 Helvetica-Oblique
    $pdf text "Unterstützte Formate: PNG, JPEG (je nach Tcl-Installation)" -x $sx -y $y
    
    # --- PFLICHT: Encoding-Test ---
    set y [expr {$y + 40}]
    
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Encoding-Test:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 11 Helvetica
    $pdf text "Deutsche Umlaute: äöüÄÖÜß" -x $sx -y $y
    
    set y [expr {$y + 20}]
    $pdf text "Sonderzeichen: €£¥©®™" -x $sx -y $y
    
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
        if {$img_found} {
            puts "   ✓ Image embedded"
        } else {
            puts "   ℹ Placeholder used (no test image)"
        }
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
