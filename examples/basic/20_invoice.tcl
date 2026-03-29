#!/usr/bin/env tclsh
# ============================================================================
# Demo 20: Rechnung (Professional Invoice)
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS USERS: 🪟
#   Für korrekte Umlaute (äöüÄÖÜß€) verwenden Sie:
#     tclsh examples/main.tcl 20_invoice.tcl
#
#   NICHT direkt (→ falsche Zeichen im PDF):
#     tclsh 20_invoice.tcl
#
# ⚠️ TCL-OKTAL-PROBLEM:
#   RICHTIG: set demo_num 20  (ohne führende 0)
#   FALSCH:  set demo_num 020 (Oktal-Fehler!)
# ============================================================================
# Lernziele:
#   - Komplexes Geschäftsdokument erstellen
#   - DIN 5008 Standard einhalten
#   - Tabellen mit Berechnungen
#   - Professionelles Layout
#
# Features:
#   - Firmen-Header mit Logo-Platzhalter
#   - Absender-Zeile (DIN 5008)
#   - Empfänger-Adresse (Fenster-Position)
#   - Rechnungs-Details (Nr, Datum, Kunde)
#   - Positionen-Tabelle mit Summen
#   - Netto/Brutto-Berechnung
#   - Footer mit Bankverbindung
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
set demo_num 20
set demo_name "invoice"
set output_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file demo_num
    
    puts "Starting Demo $demo_num: Rechnung"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl]"
    puts "  Output: $output_file"
    
    # ========================================================================
    # STEP 1: Create Page Context
    # ========================================================================
    
    # Standard 20mm Margins
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
    
    # Metadaten setzen (API: -title statt Title!)
    $pdf metadata \
        -title "Rechnung RE-2025-001" \
        -author "Musterfirma GmbH" \
        -subject "Rechnung" \
        -keywords "Rechnung, Invoice, Demo, pdf4tcl"
    
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
    set sw [dict get $ctx SW]
    set sh [dict get $ctx SH]
    
    # ========================================================================
    # HEADER: Firma und Logo
    # ========================================================================
    
    set y $sy
    
    # Firmen-Info (links)
    $pdf setFont 14 Helvetica-Bold
    $pdf text "MUSTERFIRMA GmbH" -x $sx -y $y
    
    set y [expr {$y + 15}]
    $pdf setFont 9 Helvetica
    $pdf text "Hauptstraße 123" -x $sx -y $y
    
    set y [expr {$y + 12}]
    $pdf text "12345 Musterstadt" -x $sx -y $y
    
    # Logo-Platzhalter (rechts)
    set logo_size 50
    set logo_x [expr {$sx + $sw - $logo_size}]
    set logo_y $sy
    
    $pdf gsave
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf rectangle $logo_x $logo_y $logo_size $logo_size -stroke 1
    $pdf setFont 9 Helvetica
    $pdf setFillColor 0.7 0.7 0.7
    $pdf text "Logo" -x [expr {$logo_x + 15}] -y [expr {$logo_y + 22}]
    $pdf setFillColor 0 0 0
    $pdf grestore
    
    # ========================================================================
    # Absender-Zeile (DIN 5008)
    # ========================================================================
    
    set y [expr {$sy + 70}]
    
    $pdf setFont 6 Helvetica
    $pdf setFillColor 0.5 0.5 0.5
    $pdf text "Musterfirma GmbH - Hauptstraße 123 - 12345 Musterstadt" -x $sx -y $y
    $pdf setFillColor 0 0 0
    
    # ========================================================================
    # Empfänger-Adresse (Fenster-Position DIN 5008)
    # ========================================================================
    
    # DIN 5008: 25mm von oben, 20mm von links (innerhalb Safe Area)
    set recipient_x $sx
    set recipient_y [expr {$sy + [pdf4tcllib::units::mm 30]}]
    
    $pdf setFont 10 Helvetica
    
    set recipient {
        "Kunde GmbH"
        "Herr Max Musterkunde"
        "Kundenstraße 456"
        "67890 Kundenstadt"
    }
    
    foreach line $recipient {
        if {[lindex $recipient 0] eq $line} {
            $pdf setFont 10 Helvetica-Bold
        } else {
            $pdf setFont 10 Helvetica
        }
        $pdf text $line -x $recipient_x -y $recipient_y
        set recipient_y [expr {$recipient_y + 13}]
    }
    
    # ========================================================================
    # Rechnungs-Details (rechts)
    # ========================================================================
    
    set details_x [expr {$sx + 320}]
    set details_y [expr {$sy + [pdf4tcllib::units::mm 30]}]
    
    $pdf setFont 9 Helvetica
    
    set details {
        "Rechnungs-Nr:  RE-2025-001"
        "Datum:         25.10.2025"
        "Kunden-Nr:     K-12345"
        "USt-ID:        DE123456789"
    }
    
    foreach line $details {
        $pdf text $line -x $details_x -y $details_y
        set details_y [expr {$details_y + 13}]
    }
    
    # ========================================================================
    # RECHNUNG Titel (zentriert)
    # ========================================================================
    
    set title_y [expr {$recipient_y + 20}]
    
    $pdf setFont 20 Helvetica-Bold
    pdf4tcllib::page::centerText $pdf $ctx "RECHNUNG" $title_y
    
    # ========================================================================
    # Anrede
    # ========================================================================
    
    set content_y [expr {$title_y + 35}]
    
    $pdf setFont 10 Helvetica
    $pdf text "Sehr geehrte Damen und Herren," -x $sx -y $content_y
    
    set content_y [expr {$content_y + 18}]
    $pdf text "für die erbrachten Leistungen erlauben wir uns, wie folgt abzurechnen:" -x $sx -y $content_y
    
    # ========================================================================
    # Positionen-Tabelle
    # ========================================================================
    
    set table_y [expr {$content_y + 30}]
    
    # Positions-Daten mit Berechnungen
    set positions {
        {"Pos" "Beschreibung" "Menge" "Einzelpreis" "Gesamt"}
        {"1" "Beratungsleistung IT" "8 Std" "120,00 €" "960,00 €"}
        {"2" "Software-Lizenz Premium" "1 Jahr" "299,00 €" "299,00 €"}
        {"3" "Support-Paket" "12 Mon" "49,00 €" "588,00 €"}
        {"4" "Schulung Mitarbeiter" "2 Tage" "450,00 €" "900,00 €"}
        {"5" "Hosting & Wartung" "1 Jahr" "180,00 €" "180,00 €"}
    }
    
    # Spalten-Breiten
    set col_widths {40 240 70 90 90}
    
    # Tabelle zeichnen
    pdf4tcllib::table::simpleTable $pdf $sx $table_y $col_widths $positions \
        -zebra 1 \
        -row_height 22 \
        -font_size 9 \
        -header_bg {0.85 0.85 0.85}
    
    # ========================================================================
    # Summen-Bereich
    # ========================================================================
    
    set sum_y [expr {$table_y + [expr {[llength $positions] * 22}] + 20}]
    
    # Summen rechts ausgerichtet
    set sum_label_x [expr {$sx + 350}]
    set sum_value_x [expr {$sx + $sw}]
    
    $pdf setFont 10 Helvetica
    
    # Netto-Summe
    $pdf text "Netto-Summe:" -x $sum_label_x -y $sum_y
    $pdf text "2.927,00 €" -x $sum_value_x -y $sum_y -align right
    
    set sum_y [expr {$sum_y + 18}]
    
    # MwSt
    $pdf text "zzgl. 19% MwSt.:" -x $sum_label_x -y $sum_y
    $pdf text "556,13 €" -x $sum_value_x -y $sum_y -align right
    
    set sum_y [expr {$sum_y + 18}]
    
    # Trennlinie
    $pdf setLineWidth 0.5
    $pdf line $sum_label_x $sum_y $sum_value_x $sum_y
    
    set sum_y [expr {$sum_y + 5}]
    
    # Brutto-Summe (fett, größer)
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Brutto-Betrag:" -x $sum_label_x -y $sum_y
    $pdf text "3.483,13 €" -x $sum_value_x -y $sum_y -align right
    
    # ========================================================================
    # Zahlungshinweis
    # ========================================================================
    
    set payment_y [expr {$sum_y + 30}]
    
    $pdf setFont 10 Helvetica
    $pdf text "Zahlbar innerhalb von 14 Tagen netto." -x $sx -y $payment_y
    
    set payment_y [expr {$payment_y + 15}]
    $pdf text "Vielen Dank für Ihren Auftrag!" -x $sx -y $payment_y
    
    # ========================================================================
    # FOOTER: Bankverbindung, Kontakt, USt-ID
    # ========================================================================
    
    set footer_y [expr {$sy + $sh - 60}]
    
    # Trennlinie
    $pdf setLineWidth 0.5
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf line $sx $footer_y [expr {$sx + $sw}] $footer_y
    
    set footer_y [expr {$footer_y + 12}]
    
    $pdf setFont 7 Helvetica
    $pdf setFillColor 0.4 0.4 0.4
    
    # 3 Spalten Footer
    set footer_col1 $sx
    set footer_col2 [expr {$sx + 180}]
    set footer_col3 [expr {$sx + 360}]
    
    # Spalte 1: Bankverbindung
    set fy $footer_y
    $pdf setFont 7 Helvetica-Bold
    $pdf text "Bankverbindung:" -x $footer_col1 -y $fy
    
    set fy [expr {$fy + 10}]
    $pdf setFont 7 Helvetica
    $pdf text "Musterbank AG" -x $footer_col1 -y $fy
    
    set fy [expr {$fy + 9}]
    $pdf text "IBAN: DE12 3456 7890 1234 5678 90" -x $footer_col1 -y $fy
    
    set fy [expr {$fy + 9}]
    $pdf text "BIC: MUSTDE12XXX" -x $footer_col1 -y $fy
    
    # Spalte 2: Firmendaten
    set fy $footer_y
    $pdf setFont 7 Helvetica-Bold
    $pdf text "Firmendaten:" -x $footer_col2 -y $fy
    
    set fy [expr {$fy + 10}]
    $pdf setFont 7 Helvetica
    $pdf text "USt-ID: DE123456789" -x $footer_col2 -y $fy
    
    set fy [expr {$fy + 9}]
    $pdf text "Geschäftsführer: M. Muster" -x $footer_col2 -y $fy
    
    set fy [expr {$fy + 9}]
    $pdf text "Amtsgericht: Musterstadt HRB 12345" -x $footer_col2 -y $fy
    
    # Spalte 3: Kontakt
    set fy $footer_y
    $pdf setFont 7 Helvetica-Bold
    $pdf text "Kontakt:" -x $footer_col3 -y $fy
    
    set fy [expr {$fy + 10}]
    $pdf setFont 7 Helvetica
    $pdf text "Tel: +49 123 456789" -x $footer_col3 -y $fy
    
    set fy [expr {$fy + 9}]
    $pdf text "Email: info@musterfirma.de" -x $footer_col3 -y $fy
    
    set fy [expr {$fy + 9}]
    $pdf text "Web: www.musterfirma.de" -x $footer_col3 -y $fy
    
    $pdf setFillColor 0 0 0
    
    # --- Encoding-Test (klein, unten) ---
    set enc_y [expr {$footer_y + 50}]
    $pdf setFont 6 Helvetica
    $pdf setFillColor 0.7 0.7 0.7
    $pdf text "Encoding-Test: äöüÄÖÜß € | Demo 20" -x $sx -y $enc_y
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
puts ">>> GRATULATION! <<<"
puts "Dies ist das komplexeste Demo der Suite!"
puts "Alle Elemente eines professionellen Geschäftsdokuments:"
puts "  * Header mit Logo-Platzhalter"
puts "  * DIN 5008 konforme Adress-Platzierung"
puts "  * Professionelle Tabelle mit Berechnungen"
puts "  * Netto/Brutto-Summen"
puts "  * Footer mit allen relevanten Daten"
puts ""
puts "🎉🎉🎉 MVP KOMPLETT! 20/20 Demos fertig! 🎉🎉🎉"

exit 0
