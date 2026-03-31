#!/usr/bin/env wish
# ===========================================================================
# Demo 57: Text-Widget -> PDF Export
#
# Zeigt pdf4tcllib::textwidget::render mit:
#   - Überschriften (h1, h2)
#   - Bold, Italic, Bold-Italic
#   - Farbiger Text (foreground)
#   - Hintergrundfarbe (background)
#   - Unterstreichung (-underline)
#   - Durchstreichung (-overstrike)
#   - Einzug (-lmargin1)
#   - Absatzabstand (-spacing1, -spacing3)
#   - Monospace / Code
#   - Versteckter Text (-elide)
#   - Gemischte Tags (overlapping)
#   - Echtes Dokument-Beispiel (Readme-artig)
#
# Usage: wish examples/advanced/57_textwidget_pdf.tcl [outputdir]
# ===========================================================================

package require Tk
set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
#package require pdf4tcllib
package require pdf4tcltext
package require pdf4tcl

set outdir [expr {$argc > 0 ? [lindex $argv 0] : [file join $scriptDir pdf]}]
file mkdir $outdir
set outPDF [file join $outdir "demo_57_textwidget_pdf.pdf"]

# ===========================================================================
# GUI
# ===========================================================================
wm title . "Demo 57: Text-Widget -> PDF"
wm geometry . "900x650+30+30"

ttk::notebook .nb
pack .nb -fill both -expand 1 -padx 4 -pady 4

# ---------------------------------------------------------------------------
# Tab 1: Formatierungsübersicht
# ---------------------------------------------------------------------------
set f1 [ttk::frame .nb.f1]
.nb add $f1 -text "Formatierung"

text $f1.t -width 75 -height 30 -wrap word \
    -font {Helvetica 11} -padx 8 -pady 8
ttk::scrollbar $f1.sb -orient vertical -command "$f1.t yview"
$f1.t configure -yscrollcommand "$f1.sb set"
grid $f1.t $f1.sb -sticky nsew
grid columnconfigure $f1 0 -weight 1
grid rowconfigure $f1 0 -weight 1

set t $f1.t

# Tags definieren
$t tag configure h1 \
    -font {Helvetica 16 bold} \
    -foreground "#1a2f5a" \
    -spacing1 10 -spacing3 4

$t tag configure h2 \
    -font {Helvetica 13 bold} \
    -foreground "#2a4a8a" \
    -spacing1 6 -spacing3 3

$t tag configure bold    -font {Helvetica 11 bold}
$t tag configure italic  -font {Helvetica 11 italic}
$t tag configure bolditalic -font {Helvetica 11 bold italic}

$t tag configure red     -foreground "#cc0000"
$t tag configure green   -foreground "#006600"
$t tag configure blue    -foreground "#0044aa"
$t tag configure orange  -foreground "#cc6600"

$t tag configure highlight -background "#fffacc"
$t tag configure codebg    -background "#f0f0f0" \
    -font {Courier 10} \
    -lmargin1 20 -lmargin2 20

$t tag configure underline  -underline 1 -foreground "#0044aa"
$t tag configure strikeout  -overstrike 1 -foreground "#888888"
$t tag configure indent     -lmargin1 30 -lmargin2 30
$t tag configure elided     -elide 1

# Inhalt
$t insert end "Demo 57: Text-Widget Formatierung\n" h1

$t insert end "Grundlegende Stile\n" h2
$t insert end "Normaler Text. "
$t insert end "Fetter Text. " bold
$t insert end "Kursiver Text. " italic
$t insert end "Fett-Kursiv. " bolditalic
$t insert end "\n"

$t insert end "Farben\n" h2
$t insert end "Rot " red
$t insert end "Grün " green
$t insert end "Blau " blue
$t insert end "Orange\n" orange

$t insert end "Hintergrundfarbe\n" h2
$t insert end "Dieser Text hat einen "
$t insert end "gelben Hintergrund" highlight
$t insert end " als Hervorhebung.\n"

$t insert end "Textdekoration\n" h2
$t insert end "Unterstrichen (Link-Stil)" underline
$t insert end " — "
$t insert end "Durchgestrichen (veraltet)" strikeout
$t insert end "\n"

$t insert end "Code / Monospace\n" h2
$t insert end "proc hello \{name\} \{\n    puts \"Hello \$name\"\n\}" codebg
$t insert end "\n"

$t insert end "Einzug\n" h2
$t insert end "Normaler Text am linken Rand.\n"
$t insert end "Eingerückter Text mit -lmargin1 30.\n" indent
$t insert end "Wieder normaler Text.\n"

$t insert end "Versteckter Text\n" h2
$t insert end "Sichtbar — "
$t insert end "DIESER TEXT IST UNSICHTBAR (elide=1)" elided
$t insert end "— wieder sichtbar.\n"

$t insert end "Überlappende Tags\n" h2
$t insert end "Dieser Text ist "
$t insert end "rot und fett" {red bold}
$t insert end " gleichzeitig, "
$t insert end "blau und kursiv" {blue italic}
$t insert end " gleichzeitig.\n"

$t configure -state disabled

# ---------------------------------------------------------------------------
# Tab 2: Dokument (realistisches Beispiel)
# ---------------------------------------------------------------------------
set f2 [ttk::frame .nb.f2]
.nb add $f2 -text "Dokument"

text $f2.t -width 75 -height 30 -wrap word \
    -font {Helvetica 10} -padx 10 -pady 10
ttk::scrollbar $f2.sb -orient vertical -command "$f2.t yview"
$f2.t configure -yscrollcommand "$f2.sb set"
grid $f2.t $f2.sb -sticky nsew
grid columnconfigure $f2 0 -weight 1
grid rowconfigure $f2 0 -weight 1

set t2 $f2.t

$t2 tag configure title \
    -font {Helvetica 20 bold} -foreground "#1a2f5a" \
    -spacing1 0 -spacing3 8
$t2 tag configure subtitle \
    -font {Helvetica 12 italic} -foreground "#555555" \
    -spacing3 12
$t2 tag configure section \
    -font {Helvetica 13 bold} -foreground "#2a4a8a" \
    -spacing1 10 -spacing3 4
$t2 tag configure body    -font {Helvetica 10}
$t2 tag configure emph    -font {Helvetica 10 italic}
$t2 tag configure strong  -font {Helvetica 10 bold}
$t2 tag configure code    -font {Courier 9} -background "#f5f5f5"
$t2 tag configure bullet  -lmargin1 20 -lmargin2 30
$t2 tag configure warning \
    -background "#fff0d0" -foreground "#8b4500" \
    -font {Helvetica 10 bold} \
    -lmargin1 8 -lmargin2 8 \
    -spacing1 4 -spacing3 4
$t2 tag configure version \
    -font {Courier 9} -foreground "#006600"

$t2 insert end "pdf4tcllib\n" title
$t2 insert end "PDF-Erweiterungen für pdf4tcl\n" subtitle

$t2 insert end "Übersicht\n" section
$t2 insert end "pdf4tcllib ist eine " body
$t2 insert end "Erweiterungsschicht " emph
$t2 insert end "für das pdf4tcl-Paket. Es bietet höhere Abstraktionen "
$t2 insert end "für häufige PDF-Aufgaben:\n" body

foreach item {
    "Unicode-sichere Textausgabe (sanitize)"
    "Automatischer Zeilenumbruch (writeParagraph)"
    "Tabellen mit Zebrastreifen und Rahmen"
    "Kopf- und Fußzeilen (page::header/footer)"
    "Tablelist-Export (tablelist::render)"
    "Text-Widget-Export (textwidget::render)"
} {
    $t2 insert end "• $item\n" bullet
}

$t2 insert end "\nInstallation\n" section
$t2 insert end "Das Paket ist eine einzelne " body
$t2 insert end ".tm" code
$t2 insert end "-Datei ohne externe Abhängigkeiten:\n" body
$t2 insert end "tcl::tm::path add lib\npackage require pdf4tcllib 0.2\n" code

$t2 insert end "\nWichtige Regeln\n" section

$t2 insert end "Hinweis: " warning
$t2 insert end "Direktes " warning
$t2 insert end "\$pdf text" code
$t2 insert end " crasht bei Unicode > U+00FF.\n" warning
$t2 insert end "Immer " body
$t2 insert end "pdf4tcllib::unicode::sanitize" code
$t2 insert end " verwenden.\n" body

$t2 insert end "\nVersion\n" section
$t2 insert end "Aktuelle Version: " body
$t2 insert end "pdf4tcllib 0.2" version
$t2 insert end " (2026-03-29)\n" body

$t2 configure -state disabled

# ===========================================================================
# Buttons
# ===========================================================================
frame .btns -pady 8
pack .btns
button .btns.exp -text "PDF exportieren" -command exportPDF \
    -font {Helvetica 10 bold} -bg "#0055aa" -fg white \
    -relief raised -padx 12 -pady 4
button .btns.q -text "Schliessen" -command exit -padx 8
pack .btns.exp .btns.q -side left -padx 6
label .status -text "" -fg "#006600" -font {Helvetica 9}
pack .status

# ===========================================================================
# Export
# ===========================================================================
proc exportPDF {} {
    global outPDF f1 f2

    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]
    set lx  [dict get $ctx left]
    set tw  [dict get $ctx text_w]
    set top [dict get $ctx top]

    # --- Seite 1: Formatierungsübersicht ---
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 57: Text-Widget -> PDF"
    pdf4tcllib::page::footer $pdf $ctx "Seite 1" 1

    set y [expr {$top + 8}]
    pdf4tcllib::textwidget::render $pdf $f1.t $lx $y \
        -maxwidth $tw \
        -fontsize 10 \
        -linespacing 2 \
        -ctx $ctx \
        -yvar y

    $pdf endPage

    # --- Seite 2: Dokument ---
    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 57: Text-Widget -> PDF"
    pdf4tcllib::page::footer $pdf $ctx "Seite 2" 2

    set y [expr {$top + 8}]
    pdf4tcllib::textwidget::render $pdf $f2.t $lx $y \
        -maxwidth $tw \
        -fontsize 10 \
        -linespacing 2 \
        -ctx $ctx \
        -yvar y

    $pdf endPage

    $pdf write -file $outPDF
    $pdf destroy

    .status configure -text "Exportiert: [file tail $outPDF]"
    .btns.exp configure -bg "#006600" -state disabled
    puts "PDF: $outPDF"
}
