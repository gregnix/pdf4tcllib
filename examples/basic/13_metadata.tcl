#!/usr/bin/env tclsh
# ============================================================================
# Demo 13: PDF-Metadaten
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 13_metadata.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 13_metadata.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 13  (ohne führende 0)
#   FALSCH:  set demo_num 013 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - PDF-Metadaten setzen mit setInfo
#   - Metadaten-Felder verstehen
#   - Wo man Metadaten im PDF-Reader findet
#
# Features:
#   - Titel, Autor, Subject, Keywords setzen
#   - Creator-Info
#   - Anleitung für PDF-Reader
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
set demo_num 13
set demo_name "metadata"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: PDF-Metadaten"
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
    
    # ========================================================================
    # STEP 2.5: Set PDF Metadata
    # ========================================================================
    # WICHTIG: Metadaten VOR startPage setzen!
    # API: metadata -title ... -author ... (nicht setInfo!)
    
    $pdf metadata \
        -title "Demo 13 - PDF Metadaten" \
        -author "pdf4tcl Demo Suite" \
        -subject "Demonstration von PDF-Metadaten" \
        -keywords "pdf4tcl, Tcl, Demo, Metadaten, Tutorial" \
        -creator "pdf4tcl 0.9.4.11"
    
    puts "  PDF object created with metadata"
    
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
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    
    # --- Titel ---
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 13: PDF-Metadaten" -x $sx -y $sy
    
    # --- Intro ---
    set y [expr {$sy + 35}]
    $pdf setFont 10 Helvetica
    $pdf text "PDF-Metadaten sind unsichtbare Informationen über das Dokument." -x $sx -y $y
    
    # --- Encoding-Test ---
    set y [expr {$y + 20}]
    $pdf text "Encoding-Test: äöüÄÖÜß €" -x $sx -y $y
    
    # ========================================================================
    # Section 1: Gesetzte Metadaten
    # ========================================================================
    
    set y [expr {$y + 40}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "1. Gesetzte Metadaten" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 10 Helvetica
    
    set metadata_list {
        "Title:    Demo 13 - PDF Metadaten"
        "Author:   pdf4tcl Demo Suite"
        "Subject:  Demonstration von PDF-Metadaten"
        "Keywords: pdf4tcl, Tcl, Demo, Metadaten, Tutorial"
        "Creator:  pdf4tcl 0.9.4.11"
    }
    
    foreach item $metadata_list {
        $pdf setFont 10 Courier
        $pdf text $item -x $sx -y $y
        set y [expr {$y + 18}]
    }
    
    # ========================================================================
    # Section 2: Wo finde ich die Metadaten?
    # ========================================================================
    
    set y [expr {$y + 30}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "2. Wo finde ich die Metadaten?" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 10 Helvetica
    $pdf text "Die Metadaten sind im PDF-Dokument gespeichert und können" -x $sx -y $y
    
    set y [expr {$y + 15}]
    $pdf text "in jedem PDF-Reader angezeigt werden:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    
    # Box mit Reader-Infos
    set box_x $sx
    set box_y $y
    set box_w [expr {$sw * 0.9}]
    set box_h 120
    
    # Box mit hellem Hintergrund
    $pdf setFillColor 0.95 0.95 0.95
    $pdf rectangle $box_x $box_y $box_w $box_h -filled 1
    
    # Rahmen
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.3 0.3 0.3
    $pdf setFillColor 0 0 0
    $pdf rectangle $box_x $box_y $box_w $box_h -stroke 1
    
    # Text in Box
    set text_x [expr {$box_x + 15}]
    set text_y [expr {$box_y + 20}]
    
    $pdf setFont 11 Helvetica-Bold
    $pdf text "PDF-Reader Menüs:" -x $text_x -y $text_y
    
    set text_y [expr {$text_y + 25}]
    $pdf setFont 10 Helvetica
    
    set reader_info {
        "* Evince:        Datei -> Eigenschaften"
        "* Adobe Reader:  Datei -> Dokumenteigenschaften"
        "* Okular:        Datei -> Eigenschaften"
        "* PDF-XChange:   Datei -> Dokumenteigenschaften -> Beschreibung"
        "* Browser:       Je nach Browser unterschiedlich"
    }
    
    foreach line $reader_info {
        $pdf text $line -x $text_x -y $text_y
        set text_y [expr {$text_y + 16}]
    }
    
    # ========================================================================
    # Section 3: Code-Beispiel
    # ========================================================================
    
    set y [expr {$box_y + $box_h + 30}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "3. Code-Beispiel" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 9 Courier
    
    set code_lines {
        "# PDF-Objekt erstellen"
        "set pdf \[pdf4tcl::pdf4tcl create %AUTO% -paper a4\]"
        ""
        "# Metadaten setzen (VOR startPage!)"
        "\$pdf setInfo Title \"Mein Dokument\""
        "\$pdf setInfo Author \"Max Mustermann\""
        "\$pdf setInfo Subject \"Wichtiges Thema\""
        "\$pdf setInfo Keywords \"pdf, tcl, demo\""
        "\$pdf setInfo Creator \"Meine App 1.0\""
        ""
        "# Dann erst Seite starten"
        "\$pdf startPage"
        "# ..."
    }
    
    foreach line $code_lines {
        $pdf text $line -x $sx -y $y
        set y [expr {$y + 12}]
    }
    
    # ========================================================================
    # Section 4: Hinweise
    # ========================================================================
    
    set y [expr {$y + 25}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "4. Wichtige Hinweise" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 10 Helvetica
    
    set hints {
        "* Metadaten werden verwendet für Suche und Organisation"
        "* Professionelle Dokumente sollten immer Metadaten haben"
        "* Keywords helfen beim Auffinden des Dokuments"
        "* Metadaten können in Dateimanagern angezeigt werden"
        "* Standard-Felder: Title, Author, Subject, Keywords, Creator, Producer"
    }
    
    foreach hint $hints {
        $pdf text $hint -x $sx -y $y
        set y [expr {$y + 18}]
    }
    
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
puts "TIPP: Öffnen Sie das PDF und schauen Sie unter"
puts "      'Datei -> Eigenschaften' die Metadaten an!"
puts ""
puts "Mit Debug-Grid:"
puts "  PDF4TCL_DEBUG=1 tclsh [info script]"

exit 0
