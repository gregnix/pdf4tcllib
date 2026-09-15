#!/usr/bin/env tclsh
# ============================================================================
# Demo 42: Batch-Generierung (100 PDFs)
# ============================================================================
# Built against: SPEC.lock
#   pdf4tcl: 0.9.4
#   Manual:  pdf4tcl.man @ 2023-09-18
#   API:     0.9 (pdf4tcl::pdf4tcl create)
#
# WINDOWS: nichts zu tun -- der UTF-8-Vorspann unten liest diese
#   Datei neu, wenn die Systemkodierung nicht UTF-8 ist. Hier stand
#   frueher ein Verweis auf "examples/main.tcl" -- eine Datei, die es
#   in diesem Baum nicht gibt.
#
#   NOT directly -- that gives wrong characters in the PDF:
#     tclsh 42_batch.tcl
#
# TCL OCTAL PITFALL:
#   RIGHT: set demo_num 42  (no leading zero)
#   WRONG: set demo_num 042 (octal!)
# ============================================================================
# What this shows:
#   - Batch-Generierung (viele PDFs automatisch)
#   - CSV-Daten einlesen
#   - a label template
#   - Performance-Messung
#   - Fortschrittsanzeige
#   - Fehlerbehandlung
#
# Features:
#   - 100 Etiketten-PDFs aus CSV generieren
#   - Template: Name, Adresse, PLZ/Ort
#   - Fortschrittsanzeige: 10%, 20%, ..., 100%
#   - Zeitmessung: Gesamtzeit + Durchschnitt
#   - error handling: skip malformed lines
#   - Summary-Datei mit Statistiken
#
# Encoding test: äöüÄÖÜß€
# ============================================================================

# --- Setup ---
# --- UTF-8 sicherstellen (Tcl 8.6 liest Skripte in der Systemkodierung) ---
source [file join [file dirname [info script]] .. _utf8.tcl]
if {![utf8Pruefen "ä"]} {
    if {[utf8Neuladen [info script]]} { return }
}

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
set batch_dir [file join $output_dir batch]
file mkdir $output_dir
file mkdir $batch_dir

# NOTE: demo_num without a leading zero -- Tcl would read it as octal
set demo_num 42
set demo_name "batch"
set csv_file [file join $output_dir "demo_${demo_num}_data.csv"]
set summary_file [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}_summary.pdf"]

# ============================================================================
# Step 1: Generate Test Data (CSV)
# ============================================================================

proc generate_test_data {csv_file count} {
    puts "  Generating test data: $csv_file"
    
    set fp [open $csv_file w]
    # Die Beispieldaten bleiben deutsch: Strassennamen und Staedte mit
    # Umlauten laufen hier durch CSV-Datei, Einlesen und PDF-Ausgabe.
    # Das ist Teil dessen, was die Demo zeigt -- mit "Main Street" und
    # "Springfield" waere die Kette nicht mehr geprueft.
    puts $fp "Name,Straße,PLZ,Ort"
    
    set streets {Hauptstraße Bahnhofstraße Schul straße Kirchweg Gartenweg Waldstraße Bergstraße}
    set cities {Berlin Hamburg München Köln Frankfurt Stuttgart Düsseldorf Dresden Leipzig}
    
    for {set i 1} {$i <= $count} {incr i} {
        set name "Person-[format %03d $i]"
        set street "[lindex $streets [expr {$i % [llength $streets]}]] [expr {$i % 100 + 1}]"
        set plz [format %05d [expr {10000 + $i}]]
        set city [lindex $cities [expr {$i % [llength $cities]}]]
        
        puts $fp "$name,$street,$plz,$city"
    }
    
    close $fp
    puts "    ✓ Generated $count records"
}

# ============================================================================
# Step 2: Generate Single Label PDF
# ============================================================================

proc generate_label {name street plz city output_file} {
    # Kleines Etikett: 90×60mm (ca. 255×170 pt)
    set w [pdf4tcllib::units::mm 90]
    set h [pdf4tcllib::units::mm 60]
    
    set pdf [pdf4tcl::pdf4tcl create %AUTO% \
        -paper [list $w $h] \
        -orient true \
        -unit p]
    
    $pdf startPage
    
    # Margin
    set margin 10
    
    # Border
    $pdf gsave
    $pdf setStrokeColor 0.7 0.7 0.7
    $pdf setLineWidth 0.5
    $pdf rectangle $margin $margin [expr {$w - 2*$margin}] [expr {$h - 2*$margin}] -stroke 1
    $pdf grestore
    
    # Content
    set x [expr {$margin + 8}]
    set y [expr {$margin + 15}]
    
    # Name (fett)
    $pdf setFont 14 Helvetica-Bold
    $pdf text $name -x $x -y $y
    
    # street
    set y [expr {$y + 22}]
    $pdf setFont 11 Helvetica
    $pdf text $street -x $x -y $y
    
    # PLZ/Ort
    set y [expr {$y + 18}]
    $pdf text "$plz $city" -x $x -y $y
    
    $pdf endPage
    $pdf write -file $output_file
    $pdf destroy
}

# ============================================================================
# Step 3: Batch Processing
# ============================================================================

proc process_batch {csv_file batch_dir} {
    puts "\n📦 Processing batch..."
    
    # Read CSV
    set fp [open $csv_file r]
    set lines [split [read $fp] "\n"]
    close $fp
    
    # Skip header
    set data_lines [lrange $lines 1 end]
    set total [llength $data_lines]
    
    # Stats
    set count 0
    set errors 0
    set start_time [clock milliseconds]
    
    puts "  Total records: $total"
    puts ""
    
    foreach line $data_lines {
        # Skip empty lines
        if {[string trim $line] eq ""} {
            continue
        }
        
        # Parse CSV line
        if {[catch {
            set fields [split $line ","]
            set name [lindex $fields 0]
            set street [lindex $fields 1]
            set plz [lindex $fields 2]
            set city [lindex $fields 3]
            
            # Generate PDF
            set output_file [file join $batch_dir "label_[format %03d [expr {$count + 1}]].pdf"]
            generate_label $name $street $plz $city $output_file
            
            incr count
            
            # Progress (every 10%)
            if {$count % 10 == 0} {
                set pct [expr {$count * 100 / $total}]
                set elapsed [expr {[clock milliseconds] - $start_time}]
                set rate [expr {$count * 1000.0 / $elapsed}]
                puts "  Progress: $pct% ($count/$total) - [format %.1f $rate] PDFs/sec"
            }
        } err]} {
            incr errors
            puts "    ⚠️  Error on line [expr {$count + $errors}]: $err"
        }
    }
    
    set end_time [clock milliseconds]
    set total_time [expr {$end_time - $start_time}]
    set avg_time [expr {$count > 0 ? $total_time / double($count) : 0}]
    
    puts ""
    puts "✅ Batch complete!"
    puts "   Generated: $count PDFs"
    if {$errors > 0} {
        puts "   Errors: $errors"
    }
    puts "   Time: [format %.2f [expr {$total_time / 1000.0}]]s"
    puts "   Average: [format %.1f $avg_time]ms/PDF"
    puts "   Rate: [format %.1f [expr {$count * 1000.0 / $total_time}]] PDFs/sec"
    
    return [dict create \
        count $count \
        errors $errors \
        total_time $total_time \
        avg_time $avg_time]
}

# ============================================================================
# Step 4: Generate Summary PDF
# ============================================================================

proc generate_summary {summary_file stats batch_dir} {
    puts "\n📄 Generating summary..."
    
    set ctx [pdf4tcllib::page::context a4 20 true]
    
    set pdf [pdf4tcl::pdf4tcl create %AUTO% \
        -paper [dict get $ctx paper] \
        -orient [dict get $ctx orient] \
        -unit p]
    
    $pdf startPage
    
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    
    # Title
    $pdf setFont 20 Helvetica-Bold
    $pdf text "Demo 42: Batch generation -- summary" -x $sx -y $sy
    
    # Stats
    set y [expr {$sy + 50}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Figures:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    set count [dict get $stats count]
    set errors [dict get $stats errors]
    set total_time [dict get $stats total_time]
    set avg_time [dict get $stats avg_time]
    
    set stats_lines [list \
        "Generierte PDFs: $count" \
        "Fehler: $errors" \
        "Gesamtzeit: [format %.2f [expr {$total_time / 1000.0}]]s" \
        "Durchschnitt: [format %.1f $avg_time]ms/PDF" \
        "Rate: [format %.1f [expr {$count * 1000.0 / $total_time}]] PDFs/sec" \
    ]
    
    foreach line $stats_lines {
        $pdf text $line -x $sx -y $y
        set y [expr {$y + 20}]
    }
    
    # Info
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Details:" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 10 Helvetica
    
    set info_lines {
        "Die Batch-Generierung hat folgendes geleistet:"
        ""
        "1. a CSV file with 100 records is generated"
        "2. 100 Etiketten-PDFs erstellt (90×60mm)"
        "3. every PDF holds: name, street, postcode and town"
        "4. progress is shown while generating"
        "5. Performance-Messung"
        "6. malformed lines are skipped"
        ""
        "Alle PDFs befinden sich im Verzeichnis:"
        "  output/batch/"
        ""
        "Dateien:"
        "  label_001.pdf bis label_100.pdf"
    }
    
    foreach line $info_lines {
        if {$line eq ""} {
            set y [expr {$y + 8}]
        } else {
            $pdf text $line -x $sx -y $y
            set y [expr {$y + 15}]
        }
    }
    
    # Code Example
    set y [expr {$y + 20}]
    $pdf setFont 11 Helvetica-Bold
    $pdf text "Template used:" -x $sx -y $y
    
    set y [expr {$y + 18}]
    $pdf setFont 8 Courier
    
    set code_lines {
        "proc generate_label \{name street plz city output\} \{"
        "    set pdf \[pdf4tcl::pdf4tcl create %AUTO% -paper \{90mm 60mm\}\]"
        "    \$pdf startPage"
        "    "
        "    # Name (fett)"
        "    \$pdf setFont 14 Helvetica Bold"
        "    \$pdf text \$name -x 18 -y 25"
        "    "
        "    # Adresse"
        "    \$pdf setFont 11 Helvetica"
        "    \$pdf text \$street -x 18 -y 47"
        "    \$pdf text \"\$plz \$city\" -x 18 -y 65"
        "    "
        "    \$pdf endPage"
        "    \$pdf write -file \$output"
        "    \$pdf destroy"
        "\}"
    }
    
    foreach line $code_lines {
        $pdf text $line -x [expr {$sx + 10}] -y $y
        set y [expr {$y + 10}]
    }
    
    # Encoding Test
    set y [expr {$y + 20}]
    $pdf setFont 10 Helvetica
    $pdf text "Encoding test: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $sx -y $y
    
    # Legend
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    $pdf write -file $summary_file
    $pdf destroy
    
    puts "    ✓ Summary: $summary_file"
}

# ============================================================================
# Main
# ============================================================================

proc demo_main {} {
    global csv_file batch_dir summary_file demo_num
    
    puts "Starting Demo $demo_num: Batch-Generierung"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.6
package require pdf4tcl]"
    puts "  Output directory: $batch_dir"
    puts "  Summary: $summary_file"
    
    # Step 1: Generate CSV data
    generate_test_data $csv_file 100
    
    # Step 2: Process batch
    set stats [process_batch $csv_file $batch_dir]
    
    # Step 3: Generate summary
    generate_summary $summary_file $stats $batch_dir
    
    puts ""
    puts "🎉 Demo $demo_num complete!"
    
    return $summary_file
}

# ============================================================================
# Main Execution
# ============================================================================

if {[catch {demo_main} result]} {
    puts stderr "❌ ERROR in Demo $demo_num: $result"
    puts stderr $::errorInfo
    exit 1
}

puts ""
puts "📊 Ergebnisse:"
puts "   CSV-Datei: $csv_file"
puts "   Batch-PDFs: $batch_dir/label_*.pdf"
puts "   Summary: $result"
puts ""
puts "Zum Öffnen:"
puts "  xdg-open $result"
puts "  xdg-open $batch_dir"
puts ""
puts "🏆 FINALE DEMO ABGESCHLOSSEN!"
puts "    42/42 Demos fertig! 🎉"

exit 0
