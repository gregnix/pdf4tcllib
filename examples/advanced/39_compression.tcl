#!/usr/bin/env tclsh
# ============================================================================
# Demo 39: Compression compared
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
#     tclsh 39_compression.tcl
#
# TCL OCTAL PITFALL:
#   RIGHT: set demo_num 39  (no leading zero)
#   WRONG: set demo_num 039 (octal!)
# ============================================================================
# What this shows:
#   - PDF-Kompression verstehen
#   - see the difference in file size
#   - Performance-Impact kennen
#   - -compress Option nutzen
#
# Features:
#   - Generiert 2 PDFs (unkomprimiert vs. komprimiert)
#   - compares file sizes
#   - Zeigt Einsparung in %
#   - says when compression is worth it
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
file mkdir $output_dir

# NOTE: demo_num without a leading zero -- Tcl would read it as octal
set demo_num 39
set demo_name "compression"
set output_file_a [file join $output_dir "demo_[format %02d $demo_num]a_${demo_name}_uncompressed.pdf"]
set output_file_b [file join $output_dir "demo_[format %02d $demo_num]b_${demo_name}_compressed.pdf"]
set output_file_report [file join $output_dir "demo_[format %02d $demo_num]_${demo_name}_report.pdf"]

# ============================================================================
# Helper: Generate Same Content
# ============================================================================

proc generate_content {pdf ctx} {
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    set sw [dict get $ctx SW]
    
    # Titel
    $pdf setFont 18 Helvetica-Bold
    $pdf text "Demo 39: PDF compression" -x $sx -y $sy
    
    # Encoding-Test
    set y [expr {$sy + 30}]
    $pdf setFont 10 Helvetica
    $pdf text "Encoding test: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $sx -y $y
    
    # Viel Text (damit Kompression sichtbar wird)
    set y [expr {$y + 30}]
    $pdf setFont 10 Helvetica
    
    set lorem "Lorem ipsum dolor sit amet, consectetur adipiscing elit. \
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. \
Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris. \
Nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in \
reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."
    
    # 20× wiederholen (macht Unterschied sichtbar)
    for {set i 0} {$i < 20} {incr i} {
        $pdf text "Line [expr {$i+1}]: $lorem" -x $sx -y $y
        set y [expr {$y + 15}]
        
        # a new page when needed
        if {$y > 750} {
            $pdf endPage
            $pdf startPage
            set y 50
        }
    }
    
    # Grafik (Rechtecke, Kreise)
    set y [expr {$y + 20}]
    $pdf gsave
    for {set i 0} {$i < 10} {incr i} {
        set x [expr {$sx + $i * 50}]
        set color [expr {$i / 10.0}]
        $pdf setFillColor $color $color $color
        $pdf rectangle $x $y 40 40 -filled 1
    }
    $pdf grestore
}

# ============================================================================
# Demo Implementation
# ============================================================================

proc demo_main {} {
    global output_file_a output_file_b output_file_report demo_num
    
    puts "Starting Demo $demo_num: PDF-Kompression"
    puts "  pdf4tcl version: [set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.6
package require pdf4tcl]"
    
    set ctx [pdf4tcllib::page::context a4 20 true]
    
    # ========================================================================
    # PDF 1: Unkomprimiert
    # ========================================================================
    
    puts "\n  Generiere PDF 1: UNKOMPRIMIERT..."
    puts "    Output: $output_file_a"
    
    set pdf1 [pdf4tcl::pdf4tcl create %AUTO% \
        -paper [dict get $ctx paper] \
        -orient [dict get $ctx orient] \
        -compress 0 \
        -unit p]
    
    $pdf1 startPage
    generate_content $pdf1 $ctx
    $pdf1 endPage
    
    $pdf1 write -file $output_file_a
    $pdf1 destroy
    
    set size1 [file size $output_file_a]
    puts "    ✓ Erstellt: [format %.1f [expr {$size1 / 1024.0}]] KB"
    
    # ========================================================================
    # PDF 2: Komprimiert
    # ========================================================================
    
    puts "\n  Generiere PDF 2: KOMPRIMIERT..."
    puts "    Output: $output_file_b"
    
    set pdf2 [pdf4tcl::pdf4tcl create %AUTO% \
        -paper [dict get $ctx paper] \
        -orient [dict get $ctx orient] \
        -compress 1 \
        -unit p]
    
    $pdf2 startPage
    generate_content $pdf2 $ctx
    $pdf2 endPage
    
    $pdf2 write -file $output_file_b
    $pdf2 destroy
    
    set size2 [file size $output_file_b]
    puts "    ✓ Erstellt: [format %.1f [expr {$size2 / 1024.0}]] KB"
    
    # ========================================================================
    # Vergleichsbericht
    # ========================================================================
    
    puts "\n  Generiere Vergleichsbericht..."
    puts "    Output: $output_file_report"
    
    set ratio [expr {$size2 * 100.0 / $size1}]
    set savings [expr {100.0 - $ratio}]
    
    set pdf [pdf4tcl::pdf4tcl create %AUTO% \
        -paper [dict get $ctx paper] \
        -orient [dict get $ctx orient] \
        -unit p]
    
    $pdf startPage
    
    set sx [dict get $ctx SX]
    set sy [dict get $ctx SY]
    
    # Titel
    $pdf setFont 20 Helvetica-Bold
    $pdf text "Demo 39: Compression compared" -x $sx -y $sy
    
    # Ergebnisse
    set y [expr {$sy + 50}]
    $pdf setFont 14 Helvetica-Bold
    $pdf text "Results:" -x $sx -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 12 Helvetica
    
    $pdf text "Uncompressed (-compress 0):" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "  File size: [format %.2f [expr {$size1 / 1024.0}]] KB" -x [expr {$sx + 20}] -y $y
    
    set y [expr {$y + 30}]
    $pdf text "Compressed (-compress 1):" -x $sx -y $y
    set y [expr {$y + 20}]
    $pdf text "  File size: [format %.2f [expr {$size2 / 1024.0}]] KB" -x [expr {$sx + 20}] -y $y
    
    set y [expr {$y + 30}]
    $pdf setFont 14 Helvetica-Bold
    $pdf setFillColor 0 0.6 0
    $pdf text "Einsparung: [format %.1f $savings]%" -x $sx -y $y
    $pdf setFillColor 0 0 0
    
    # the explanation
    set y [expr {$y + 50}]
    $pdf setFont 12 Helvetica-Bold
    $pdf text "Wann Kompression verwenden?" -x $sx -y $y
    
    set y [expr {$y + 25}]
    $pdf setFont 10 Helvetica
    
    set tips {
        "+ Immer bei Produktions-PDFs (Standard: -compress 1)"
        "+ with a lot of text, where it compresses well"
        "+ with large documents"
        ""
        "- Beim Debuggen (-compress 0 → lesbare PDF-Struktur)"
        "- Bei sehr kleinen PDFs (Overhead)"
        ""
        "Performance: Kompression kostet ca. 5-10% mehr Zeit"
        "             aber spart 40-80% Speicher!"
    }
    
    foreach tip $tips {
        if {$tip eq ""} {
            set y [expr {$y + 10}]
        } else {
            $pdf text $tip -x $sx -y $y
            set y [expr {$y + 15}]
        }
    }
    
    # Code-Beispiel
    set y [expr {$y + 20}]
    $pdf setFont 11 Helvetica-Bold
    $pdf text "Code-Beispiel:" -x $sx -y $y
    
    set y [expr {$y + 20}]
    $pdf setFont 9 Courier
    
    set code_lines {
        "# uncompressed, for debugging"
        "set pdf \[pdf4tcl::pdf4tcl create %AUTO% -compress 0\]"
        ""
        "# Komprimiert (Standard, empfohlen)"
        "set pdf \[pdf4tcl::pdf4tcl create %AUTO% -compress 1\]"
        ""
        "# Default ist compress=1"
        "set pdf \[pdf4tcl::pdf4tcl create %AUTO%\]"
    }
    
    foreach line $code_lines {
        $pdf text $line -x [expr {$sx + 10}] -y $y
        set y [expr {$y + 12}]
    }
    
    # Encoding-Test
    set y [expr {$y + 20}]
    $pdf setFont 10 Helvetica
    $pdf text "Encoding test: \u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df \u20ac" -x $sx -y $y
    
    # Orientation Legend
    pdf4tcllib::page::orientationLegend $pdf $ctx
    
    $pdf endPage
    $pdf write -file $output_file_report
    $pdf destroy
    
    # ========================================================================
    # Zusammenfassung
    # ========================================================================
    
    puts "\n✅ Demo $demo_num complete"
    puts ""
    puts "📊 Ergebnis:"
    puts "   Unkomprimiert: [format %.2f [expr {$size1 / 1024.0}]] KB"
    puts "   Komprimiert:   [format %.2f [expr {$size2 / 1024.0}]] KB"
    puts "   Einsparung:    [format %.1f $savings]%"
    puts ""
    puts "📄 Generierte Dateien:"
    puts "   1. $output_file_a"
    puts "   2. $output_file_b"
    puts "   3. $output_file_report (Bericht)"
    
    return $output_file_report
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
puts "🎉 Demo $demo_num erfolgreich!"
puts ""
puts "Zum Vergleichen:"
puts "  evince $output_file_a $output_file_b"
puts ""
puts "Vergleichsbericht:"
puts "  xdg-open $result"

exit 0
