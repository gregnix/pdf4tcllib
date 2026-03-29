#!/usr/bin/env tclsh
# Demo 43: Interactive Forms
# pdf4tcl 0.9.4.11 — orient true (origin top-left)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

# --- Setup (STANDARD) ---

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set demo_num 43
set demo_name "forms"
set outfile [file join $outdir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# PDF erstellen
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]
$pdf startPage

# ============================================================================
# Header
# ============================================================================
$pdf setFont 18 Helvetica-Bold
$pdf text "Registration Form" -x 50 -y 50

$pdf setFont 10 Helvetica
$pdf text "Please fill out the form and save the PDF." -x 50 -y 75

# Rahmen um Formular
$pdf setStrokeColor 0.7 0.7 0.7
$pdf setLineWidth 1
$pdf rectangle 40 90 515 420 -stroke 1
$pdf setStrokeColor 0 0 0

# ============================================================================
# Formular-Felder
# ============================================================================
set fx 60
set fy 110
set label_w 100
set field_w 220
set field_h 20
set spacing 35

# 1. Name (Required)
$pdf setFont 12 Helvetica
$pdf text "Name:" -x $fx -y $fy
$pdf setFont 10 Helvetica-Oblique
$pdf setFillColor 0.8 0 0
$pdf text "*" -x [expr {$fx + 50}] -y $fy
$pdf setFillColor 0 0 0

set field_x [expr {$fx + $label_w}]
$pdf addForm text $field_x [expr {$fy - 5}] $field_w $field_h \
    -id name -init ""

# 2. Email (Required)
set fy [expr {$fy + $spacing}]
$pdf setFont 12 Helvetica
$pdf text "Email:" -x $fx -y $fy
$pdf setFont 10 Helvetica-Oblique
$pdf setFillColor 0.8 0 0
$pdf text "*" -x [expr {$fx + 50}] -y $fy
$pdf setFillColor 0 0 0

$pdf addForm text $field_x [expr {$fy - 5}] $field_w $field_h \
    -id email -init ""

# 3. Phone
set fy [expr {$fy + $spacing}]
$pdf setFont 12 Helvetica
$pdf text "Phone:" -x $fx -y $fy

$pdf addForm text $field_x [expr {$fy - 5}] $field_w $field_h \
    -id phone -init ""

# 4. Company
set fy [expr {$fy + $spacing}]
$pdf setFont 12 Helvetica
$pdf text "Company:" -x $fx -y $fy

$pdf addForm text $field_x [expr {$fy - 5}] $field_w $field_h \
    -id company -init ""

# 5. Address (Multiline)
set fy [expr {$fy + $spacing}]
$pdf setFont 12 Helvetica
$pdf text "Address:" -x $fx -y $fy

set multiline_h [expr {$field_h * 3}]
$pdf addForm text $field_x [expr {$fy - 5}] $field_w $multiline_h \
    -id address -multiline true -init ""

# 6. Country
set fy [expr {$fy + $multiline_h + 15}]
$pdf setFont 12 Helvetica
$pdf text "Country:" -x $fx -y $fy

$pdf addForm text $field_x [expr {$fy - 5}] $field_w $field_h \
    -id country -init ""

# ============================================================================
# Checkboxen
# ============================================================================
set fy [expr {$fy + $spacing + 10}]

# Überschrift
$pdf setFont 12 Helvetica-Bold
$pdf text "Preferences:" -x $fx -y $fy

set fy [expr {$fy + 25}]

# Newsletter Checkbox
$pdf addForm checkbutton $fx [expr {$fy - 5}] 15 15 \
    -id newsletter -init false

$pdf setFont 11 Helvetica
$pdf text "Subscribe to newsletter (monthly updates)" -x [expr {$fx + 25}] -y $fy

# Terms Checkbox
set fy [expr {$fy + 25}]
$pdf addForm checkbutton $fx [expr {$fy - 5}] 15 15 \
    -id terms -init false

$pdf setFont 11 Helvetica
$pdf text "I accept the terms and conditions" -x [expr {$fx + 25}] -y $fy
$pdf setFont 10 Helvetica-Oblique
$pdf setFillColor 0.8 0 0
$pdf text "*" -x [expr {$fx + 250}] -y $fy
$pdf setFillColor 0 0 0

# Privacy Checkbox
set fy [expr {$fy + 25}]
$pdf addForm checkbutton $fx [expr {$fy - 5}] 15 15 \
    -id privacy -init false

$pdf setFont 11 Helvetica
$pdf text "I agree to the privacy policy" -x [expr {$fx + 25}] -y $fy
$pdf setFont 10 Helvetica-Oblique
$pdf setFillColor 0.8 0 0
$pdf text "*" -x [expr {$fx + 230}] -y $fy
$pdf setFillColor 0 0 0

# ============================================================================
# Footer / Hinweise
# ============================================================================
set fy [expr {$fy + 40}]

# Trennlinie
$pdf setStrokeColor 0.7 0.7 0.7
$pdf setLineWidth 0.5
$pdf line $fx $fy [expr {$fx + 440}] $fy
$pdf setStrokeColor 0 0 0

set fy [expr {$fy + 15}]

# Hinweise
$pdf setFont 9 Helvetica-Oblique
$pdf setFillColor 0.5 0.5 0.5
$pdf text "* Required fields" -x $fx -y $fy

set fy [expr {$fy + 15}]
$pdf text "After filling out the form, save this PDF to preserve your data." -x $fx -y $fy

set fy [expr {$fy + 15}]
$pdf text "For technical issues, contact: support@example.com" -x $fx -y $fy

$pdf setFillColor 0 0 0

# ============================================================================
# Informations-Box
# ============================================================================
set fy [expr {$fy + 40}]

$pdf setFont 10 Helvetica-Bold
$pdf text "Form Fields:" -x $fx -y $fy

set fy [expr {$fy + 20}]
$pdf setFont 9 Helvetica
$pdf text "• Text Fields: name, email, phone, company, address, country" -x [expr {$fx + 10}] -y $fy

set fy [expr {$fy + 15}]
$pdf text "• Checkboxes: newsletter, terms, privacy" -x [expr {$fx + 10}] -y $fy

set fy [expr {$fy + 15}]
$pdf text "• Multiline Field: address (3 lines)" -x [expr {$fx + 10}] -y $fy

# ============================================================================
# Fußzeile
# ============================================================================
$pdf setFont 8 Helvetica
$pdf setFillColor 0.5 0.5 0.5
$pdf text "pdf4tcl Demo Suite - Interactive Forms Demo" -x 297 -y 820 -align center
$pdf setFillColor 0 0 0

$pdf endPage

# ============================================================================
# PDF speichern
# ============================================================================
# ============================================================================
# Seite 2: Annotationen + exportForms (0.9.4.23)
# ============================================================================
$pdf startPage

$pdf setFont 14 Helvetica-Bold
$pdf text "Seite 2: Annotationen und FDF/XFDF-Export (0.9.4.23)" -x 50 -y 40

$pdf setFont 10 Helvetica
$pdf text "Neue Annotation-Methoden in pdf4tcl 0.9.4.23:" -x 50 -y 65

# Sticky Note
$pdf addAnnotNote 50 85 18 18 \
    -content "Pflichtfelder mit * markieren!" \
    -author "Greg" -icon Note -color {1 1 0.3}
$pdf setFont 10 Helvetica
$pdf text "addAnnotNote: Hinweis zu Pflichtfeldern" -x 78 -y 98

# FreeText
$pdf addAnnotFreeText 50 120 350 35 \
    "Formular ausfuellen und als PDF speichern. Dann mit exportForms auslesen." \
    -fontsize 10 -bgcolor {0.95 1.0 0.9}
$pdf setFont 9 Helvetica
$pdf setFillColor 0.4 0.4 0.4
$pdf text "addAnnotFreeText: direkt sichtbare Textbox" -x 50 -y 165
$pdf setFillColor 0 0 0

# Stamp
$pdf addAnnotStamp 380 80 160 50 -name Draft -color {0.8 0 0}
$pdf setFont 9 Helvetica
$pdf setFillColor 0.4 0.4 0.4
$pdf text "addAnnotStamp: Draft" -x 380 -y 140
$pdf setFillColor 0 0 0

# Highlight ueber einer fiktiven Zeile
$pdf setFont 11 Helvetica
$pdf text "Wichtig: Alle Pflichtfelder (* ) ausfullen!" -x 50 -y 195
$pdf addAnnotHighlight 50 182 340 16 -color {1 1 0.3}
$pdf setFont 9 Helvetica
$pdf setFillColor 0.4 0.4 0.4
$pdf text "addAnnotHighlight" -x 50 -y 210
$pdf setFillColor 0 0 0

# exportForms Info
$pdf setFont 12 Helvetica-Bold
$pdf text "Formulardaten exportieren (exportForms):" -x 50 -y 240
$pdf setFont 10 Helvetica
set y 258
foreach line {
    "Nach dem Ausfullen des Formulars:"
    "  FDF:  pdf4tcl::exportForms filled.pdf output.fdf"
    "  XFDF: pdf4tcl::exportForms filled.pdf output.xfdf -format xfdf"
    ""
    "FDF = Forms Data Format (kompaktes Textformat)"
    "XFDF = XML Forms Data Format (lesbar, standardkonform)"
} {
    if {$line ne ""} {
        $pdf setFont [expr {[string match "  *" $line] ? 9 : 10}]             [expr {[string match "  *" $line] ? "Courier" : "Helvetica"}]
        $pdf text $line -x 50 -y $y
    }
    set y [expr {$y + 16}]
}

$pdf endPage

$pdf write -file $outfile
$pdf destroy

puts "Geschrieben: $outfile"
puts "ℹ️  Open with PDF reader, fill out, and save!"
puts ""
puts "📋 Form contains:"
puts "  Text Fields:"
puts "    • name (required)"
puts "    • email (required)"
puts "    • phone"
puts "    • company"
puts "    • address (multiline)"
puts "    • country"
puts "  Checkboxes:"
puts "    • newsletter"
puts "    • terms (required)"
puts "    • privacy (required)"
puts ""
puts "💡 Test with: Adobe Reader, Foxit, or Evince"

