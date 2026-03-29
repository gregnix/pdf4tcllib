#!/usr/bin/env tclsh
# Demo 44: Bookmarks & Navigation
# pdf4tcl 0.9.4.11 — orient true (origin top-left)

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib 0.1
package require pdf4tcl

# --- Setup (STANDARD) ---

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set demo_num 44
set demo_name "bookmarks"
set outfile [file join $outdir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

# PDF erstellen
set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true]

# ============================================================================
# Seite 1: Titelseite
# ============================================================================
$pdf startPage

# Bookmark für Titelseite
$pdf bookmarkAdd -title "Title Page" -level 0

# Titel
$pdf setFont 24 Helvetica-Bold
$pdf text "Professional Document" -x 297 -y 200 -align center

$pdf setFont 16 Helvetica
$pdf text "with Bookmarks & Navigation" -x 297 -y 240 -align center

$pdf setFont 12 Helvetica
$pdf text "pdf4tcl Demo Suite" -x 297 -y 280 -align center

$pdf setFont 10 Helvetica-Oblique
$pdf setFillColor 0.5 0.5 0.5
$pdf text "Check the bookmark panel in your PDF reader!" -x 297 -y 320 -align center
$pdf setFillColor 0 0 0

$pdf endPage

# ============================================================================
# Seite 2: Inhaltsverzeichnis
# ============================================================================
$pdf startPage

# Bookmark
$pdf bookmarkAdd -title "Table of Contents" -level 0

# Überschrift
$pdf setFont 18 Helvetica-Bold
$pdf text "Table of Contents" -x 50 -y 50

# TOC-Einträge
$pdf setFont 12 Helvetica
set y 90
foreach {num title page} {
    1 "Introduction" 3
    2 "Getting Started" 4
    3 "Advanced Topics" 5
    4 "Best Practices" 6
    5 "Troubleshooting" 7
    "" "Appendix" 8
} {
    if {$num ne ""} {
        set line "$num. $title"
    } else {
        set line $title
    }
    $pdf text $line -x 70 -y $y
    $pdf text "Page $page" -x 450 -y $y -align right
    
    # Gepunktete Linie
    $pdf setStrokeColor 0.7 0.7 0.7
    for {set dx 200} {$dx < 430} {incr dx 5} {
        $pdf circle [expr {$dx + 70}] [expr {$y + 5}] 0.5 -filled 1
    }
    $pdf setStrokeColor 0 0 0
    
    incr y 25
}

# Hinweis
$pdf setFont 9 Helvetica-Oblique
$pdf setFillColor 0.5 0.5 0.5
$pdf text "Use bookmarks in the sidebar for quick navigation" -x 70 -y [expr {$y + 30}]
$pdf setFillColor 0 0 0

$pdf endPage

# ============================================================================
# Kapitel 1-5
# ============================================================================
foreach {num title desc} {
    1 "Introduction" "This chapter introduces the basic concepts."
    2 "Getting Started" "Learn how to set up and begin working."
    3 "Advanced Topics" "Dive deeper into advanced features."
    4 "Best Practices" "Follow these guidelines for best results."
    5 "Troubleshooting" "Common problems and their solutions."
} {
    $pdf startPage
    
    # Level 0 Bookmark für Kapitel
    $pdf bookmarkAdd -title "Chapter $num: $title" -level 0
    
    # Kapitel-Überschrift
    $pdf setFont 20 Helvetica-Bold
    $pdf text "Chapter $num" -x 50 -y 50
    
    $pdf setFont 16 Helvetica
    $pdf text $title -x 50 -y 80
    
    # Description
    $pdf setFont 12 Helvetica
    $pdf text $desc -x 50 -y 110
    
    # Sub-Sections (Level 1 Bookmarks)
    $pdf setFont 14 Helvetica-Bold
    set y 150
    
    for {set i 1} {$i <= 3} {incr i} {
        # Level 1 Bookmark
        $pdf bookmarkAdd -title "$num.$i Sub-Section" -level 1
        
        $pdf text "$num.$i Sub-Section" -x 70 -y $y
        
        # Content
        $pdf setFont 11 Helvetica
        $pdf text "This is the content of sub-section $num.$i." -x 90 -y [expr {$y + 20}]
        $pdf text "Lorem ipsum dolor sit amet, consectetur adipiscing elit." -x 90 -y [expr {$y + 35}]
        $pdf text "Sed do eiusmod tempor incididunt ut labore et dolore." -x 90 -y [expr {$y + 50}]
        
        incr y 90
    }
    
    # Trennlinie
    $pdf setStrokeColor 0.8 0.8 0.8
    $pdf setLineWidth 0.5
    $pdf line 50 780 545 780
    $pdf setStrokeColor 0 0 0
    
    # Fußzeile mit Seitenzahl
    $pdf setFont 10 Helvetica
    set page_num [expr {$num + 2}]
    $pdf text "Page $page_num" -x 297 -y 800 -align center
    $pdf setFont 9 Helvetica-Oblique
    $pdf setFillColor 0.5 0.5 0.5
    $pdf text "Chapter $num: $title" -x 50 -y 800
    $pdf setFillColor 0 0 0
    
    $pdf endPage
}

# ============================================================================
# Seite 8: Anhang
# ============================================================================
$pdf startPage

# Level 0 Bookmark (closed = eingeklappt)
$pdf bookmarkAdd -title "Appendix" -level 0 -closed true

# Überschrift
$pdf setFont 18 Helvetica-Bold
$pdf text "Appendix" -x 50 -y 50

# Sub-Sections (Level 1, unter Appendix)
$pdf setFont 14 Helvetica-Bold
set y 90

foreach {section desc} {
    "Glossary" "Important terms and definitions"
    "References" "Sources and further reading"
    "Index" "Alphabetical index of topics"
} {
    $pdf bookmarkAdd -title $section -level 1
    
    $pdf text $section -x 70 -y $y
    
    # Description
    $pdf setFont 11 Helvetica
    $pdf text $desc -x 90 -y [expr {$y + 20}]
    
    incr y 50
}

# Hinweis
$pdf setFont 10 Helvetica-Oblique
$pdf setFillColor 0.5 0.5 0.5
$pdf text "Note: This appendix bookmark is closed by default (-closed true)" -x 70 -y [expr {$y + 30}]
$pdf setFillColor 0 0 0

# Trennlinie
$pdf setStrokeColor 0.8 0.8 0.8
$pdf setLineWidth 0.5
$pdf line 50 780 545 780
$pdf setStrokeColor 0 0 0

# Fußzeile
$pdf setFont 10 Helvetica
$pdf text "Page 8" -x 297 -y 800 -align center
$pdf setFont 9 Helvetica-Oblique
$pdf setFillColor 0.5 0.5 0.5
$pdf text "Appendix" -x 50 -y 800
$pdf setFillColor 0 0 0

$pdf endPage

# ============================================================================
# PDF speichern
# ============================================================================
$pdf write -file $outfile
$pdf destroy

puts "✅ Document with Bookmarks created: $outfile"
puts "ℹ️  Open with PDF reader and check the bookmark panel!"
puts ""
puts "📋 Document Structure:"
puts "  • Title Page"
puts "  • Table of Contents"
puts "  • Chapter 1: Introduction"
puts "    ├─ 1.1 Sub-Section"
puts "    ├─ 1.2 Sub-Section"
puts "    └─ 1.3 Sub-Section"
puts "  • Chapter 2: Getting Started"
puts "    └─ ... (3 sub-sections)"
puts "  • Chapter 3: Advanced Topics"
puts "    └─ ... (3 sub-sections)"
puts "  • Chapter 4: Best Practices"
puts "    └─ ... (3 sub-sections)"
puts "  • Chapter 5: Troubleshooting"
puts "    └─ ... (3 sub-sections)"
puts "  • Appendix (closed by default)"
puts "    ├─ Glossary"
puts "    ├─ References"
puts "    └─ Index"

