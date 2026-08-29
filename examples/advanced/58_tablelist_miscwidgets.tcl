#!/usr/bin/env wish
# ===========================================================================
# Demo 58: tablelist mit eingebetteten Widgets -> PDF Export
#
# Zeigt, was pdf4tcltable aus einer tablelist macht, deren Zellen ueber
# Editfenster bearbeitet werden: Combobox, Spinbox, Checkbutton, Entry.
#
# WARUM DIESE DEMO IHR WIDGET SELBST BAUT
#
# Bis hierher lud sie miscWidgets_tile.tcl aus der tablelist-Sammlung.
# Das Skript verlangt zwei Fremdpakete, die kein Tk mitbringt: Bryan
# Oakley's `combobox` und `mentry`. Wo die fehlen, brach die Demo ab --
# im Stapellauf mit "can't find package combobox", und geprueft wurde sie
# nie.
#
# Dabei braucht es sie nicht: tablelist kennt `ttk::combobox`,
# `ttk::spinbox` und `ttk::checkbutton` als Editfenster von Haus aus
# (tablelist.html, "Interactive cell editing"). Diese Demo baut ihre
# Tabelle deshalb selbst und kommt mit Tk und tablelist aus.
#
# ZU EINGEBETTETEN WIDGETS
#
# pdf4tcltable liest die Zellwerte ueber `$tbl get`. Ein Editfenster ist
# nur waehrend des Bearbeitens da; im PDF steht der gespeicherte Wert --
# 0/1 fuer einen Checkbutton, der gewaehlte Eintrag einer Combobox. Das
# ist richtig so: exportiert wird der Inhalt, nicht das Bedienelement.
#
# Voraussetzung: package tablelist_tile (Csaba Nemethi)
# ===========================================================================

package require Tk

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../../lib]]
package require pdf4tcltable 0.2
package require pdf4tcl

# ---------------------------------------------------------------------------
# 1. tablelist laden
# ---------------------------------------------------------------------------
if {[catch {package require tablelist_tile} err]} {
    if {[lsearch $argv -batch] >= 0} {
        puts stderr "Demo 58: tablelist_tile nicht gefunden: $err"
        exit 1
    }
    tk_messageBox -type ok -icon warning -title "Demo 58" \
        -message "tablelist_tile nicht gefunden:\n$err\n\nBitte tablelist installieren."
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Die Tabelle -- mit ttk-Editfenstern, ohne Fremdpakete
# ---------------------------------------------------------------------------
wm withdraw .

toplevel .tblTop
wm title .tblTop "Serielle Schnittstellen"

set tbl .tblTop.tbl
tablelist::tablelist $tbl \
    -columns {0 "Anschluss" left  0 "Baudrate" right  0 "Datenbits" right
              0 "Paritaet" left   0 "Protokoll" left  0 "Aktiv" center} \
    -stretch all -height 6 -width 74 -selectmode extended

# Ein Checkbutton speichert 0 oder 1; im PDF soll etwas Lesbares stehen.
# -formatcommand greift auch beim Export, weil pdf4tcltable die
# formatierten Werte liest, wenn es sie gibt.
proc ::formatJaNein {val} {
    return [expr {$val ? "ja" : "nein"}]
}

$tbl columnconfigure 0 -name port
$tbl columnconfigure 1 -name baud   -editable yes -editwindow ttk::combobox
$tbl columnconfigure 2 -name bits   -editable yes -editwindow ttk::spinbox
$tbl columnconfigure 3 -name par    -editable yes -editwindow ttk::combobox
$tbl columnconfigure 4 -name proto  -editable yes -editwindow ttk::entry
$tbl columnconfigure 5 -name aktiv  -editable yes -editwindow ttk::checkbutton \
        -formatcommand {::formatJaNein}

# Die Auswahllisten der Comboboxen. tablelist reicht -editwindow-Optionen
# ueber -editstartcommand durch.
proc ::editStart {tbl row col text} {
    set w [$tbl editwinpath]
    switch -- [$tbl columncget $col -name] {
        baud { $w configure -values {1200 2400 4800 9600 19200 38400 115200} }
        par  { $w configure -values {keine gerade ungerade} }
        bits { $w configure -from 5 -to 9 }
    }
    return $text
}
$tbl configure -editstartcommand ::editStart

foreach zeile {
    {COM1  9600 8 keine   XON/XOFF 1}
    {COM2 19200 8 gerade  RTS/CTS  1}
    {COM3  4800 7 ungerade keine   0}
    {COM4 115200 8 keine  RTS/CTS  0}
} {
    $tbl insert end $zeile
}

pack $tbl -fill both -expand 1
update idletasks

set tl_demo "selbst gebaut (ttk::combobox, ttk::spinbox, ttk::checkbutton)"

# ---------------------------------------------------------------------------
# 5. Kontrollfenster
# ---------------------------------------------------------------------------
toplevel .ctrl
wm title .ctrl "Demo 58: tablelist -> PDF"
wm geometry .ctrl "520x180+100+100"
wm resizable .ctrl 0 0

ttk::frame .ctrl.f -padding 16
pack .ctrl.f -fill both -expand 1

ttk::label .ctrl.f.info -text "tablelist: $tbl" \
    -font {Helvetica 9} -foreground "#444444"
pack .ctrl.f.info -anchor w -pady 2

ttk::label .ctrl.f.src -text "Quelle: [file tail $tl_demo]" \
    -font {Helvetica 8} -foreground "#888888"
pack .ctrl.f.src -anchor w

ttk::label .ctrl.f.hint -wraplength 480 -justify left \
    -font {Helvetica 9} -foreground "#555555" \
    -text "Hinweis: Checkbutton, Combobox, Spinbox erscheinen im PDF als aktueller Textwert (via \$tbl get)."
pack .ctrl.f.hint -anchor w -pady 6

ttk::frame .ctrl.btns
pack .ctrl.btns -pady 2
ttk::button .ctrl.btns.exp -text "PDF exportieren" -command exportPDF
ttk::button .ctrl.btns.q   -text "Schliessen"      -command exit
pack .ctrl.btns.exp .ctrl.btns.q -side left -padx 6

ttk::label .ctrl.status -text "" -foreground "#006600" -font {Helvetica 9}
pack .ctrl.status -pady 4

wm protocol .ctrl WM_DELETE_WINDOW exit

# ---------------------------------------------------------------------------
# 6. PDF-Export
# ---------------------------------------------------------------------------
set outDir [expr {$argc > 0 ? [lindex $argv 0] \
    : [file join $scriptDir pdf]}]
file mkdir $outDir
set outPDF [file join $outDir "demo_58_miscwidgets.pdf"]

proc exportPDF {} {
    global tbl outPDF tl_demo

    update idletasks

    set ctx [pdf4tcllib::page::context a4 -margin 20 -orient true]
    set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient true -compress 1]

    set lx  [dict get $ctx left]
    set tw  [dict get $ctx text_w]
    set top [dict get $ctx top]

    $pdf startPage
    pdf4tcllib::page::header $pdf $ctx "Demo 58: tablelist mit eingebetteten Widgets"
    pdf4tcllib::page::footer $pdf $ctx "Seite 1" 1

    set y [expr {$top + 14}]

    $pdf setFont 13 Helvetica-Bold
    $pdf text "tablelist mit ttk-Editfenstern -- PDF Export" -x $lx -y $y
    set y [expr {$y + 16}]

    $pdf setFont 8 Helvetica
    $pdf setFillColor 0.4 0.4 0.4
    $pdf text "Quelle: $tl_demo" -x $lx -y $y
    $pdf setFillColor 0 0 0
    set y [expr {$y + 14}]

    # Hinweis-Box
    $pdf setFillColor 0.95 0.97 1.0
    $pdf rectangle $lx $y $tw 38 -filled 1
    $pdf setFillColor 0.2 0.3 0.7
    $pdf rectangle $lx $y 3 38 -filled 1
    $pdf setFillColor 0.2 0.2 0.2
    $pdf setFont 8 Helvetica-Bold
    $pdf text "Hinweis zu eingebetteten Widgets:" \
        -x [expr {$lx + 8}] -y [expr {$y + 9}]
    $pdf setFont 8 Helvetica
    $pdf text "Checkbutton, Combobox, Spinbox erscheinen als aktueller Textwert." \
        -x [expr {$lx + 8}] -y [expr {$y + 21}]
    $pdf text "Der Export liest Zellwerte via \$tbl get -- nicht die Widget-Darstellung." \
        -x [expr {$lx + 8}] -y [expr {$y + 33}]
    $pdf setFillColor 0 0 0
    set y [expr {$y + 48}]

    pdf4tcllib::tablelist::render $pdf $tbl $lx $y \
        -maxwidth $tw \
        -fontsize 8.5 \
        -border   1   \
        -zebra    1   \
        -ctx      $ctx \
        -yvar     y

    $pdf endPage
    $pdf write -file $outPDF
    $pdf destroy

    .ctrl.status configure -text "Written: [file tail $outPDF]"
    .ctrl.btns.exp state disabled
    puts "PDF: $outPDF"
}

# Run headless when -batch is given. The flag comes AFTER the output
# directory, because argv[0] is the directory. Without this the demo can
# only be checked by a human clicking the export button -- and a run that
# skips it reports success for something nobody looked at.
if {[lsearch $argv -batch] >= 0} {
    update
    exportPDF
    destroy .
}
