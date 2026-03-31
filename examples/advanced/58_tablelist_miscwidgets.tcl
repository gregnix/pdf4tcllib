#!/usr/bin/env wish
# ===========================================================================
# Demo 58: tablelist miscWidgets_tile -> PDF Export
#
# Laed miscWidgets_tile.tcl aus der tablelist-Demo-Sammlung,
# ermittelt den Pfad automatisch ueber package ifneeded,
# und exportiert das Widget als PDF mit pdf4tcltable.
#
# Hinweis zu eingebetteten Widgets:
#   tablelist kann Zellen mit embedded widgets (Checkbutton, Combobox,
#   Spinbox, Entry, Button) enthalten. pdf4tcltable liest die Zell-
#   Werte via $tbl get -- eingebettete Widgets erscheinen dabei als
#   ihr gespeicherter Textwert (z.B. 0/1 fuer Checkbutton, aktueller
#   Wert fuer Entry/Spinbox). Das ist korrekt fuer den PDF-Export:
#   der Inhalt wird exportiert, nicht das Widget selbst.
#
# Voraussetzung: package tablelist_tile (Csaba Nemethi)
# ===========================================================================

package require Tk

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../../lib]]
package require pdf4tcltable 0.1
package require pdf4tcl

# ---------------------------------------------------------------------------
# 1. tablelist laden und Demos-Pfad ermitteln
# ---------------------------------------------------------------------------
if {[catch {package require tablelist_tile} err]} {
    tk_messageBox -type ok -icon warning \
        -title "Demo 58" \
        -message "tablelist_tile nicht gefunden:\n$err\n\nBitte tablelist installieren."
    exit 1
}

# Pfad zur tablelist-Library ueber package ifneeded
set tl_ver  [package require tablelist_tile]
set tl_info [package ifneeded tablelist_tile $tl_ver]
# tl_info z.B.: "source /usr/share/tcltk/tablelist6.19/tablelist_tile.tcl"
set tl_lib  [file dirname [lindex $tl_info end]]
set tl_demo [file join $tl_lib demos miscWidgets_tile.tcl]

if {![file exists $tl_demo]} {
    tk_messageBox -type ok -icon warning \
        -title "Demo 58" \
        -message "miscWidgets_tile.tcl nicht gefunden:\n$tl_demo\n\
\nGefundene tablelist-Library: $tl_lib"
    exit 1
}

# ---------------------------------------------------------------------------
# 2. miscWidgets_tile.tcl per Dialog auswaehlen
# ---------------------------------------------------------------------------

# Vorschlagspfad aus tablelist-Library (falls vorhanden)
set tl_ver  [package require tablelist_tile]
set tl_info [package ifneeded tablelist_tile $tl_ver]
set tl_lib  [file dirname [lindex $tl_info end]]
set tl_demos [file join $tl_lib demos]

set tl_demo [tk_getOpenFile \
    -title       "miscWidgets_tile.tcl auswaehlen" \
    -initialdir  [expr {[file isdir $tl_demos] ? $tl_demos : $tl_lib}] \
    -initialfile "miscWidgets_tile.tcl" \
    -filetypes   {{"Tcl Scripts" {.tcl}} {"All files" *}}]

if {$tl_demo eq ""} {
    # Abgebrochen
    exit 0
}

if {![file exists $tl_demo]} {
    tk_messageBox -type ok -icon error \
        -title "Demo 58" \
        -message "Datei nicht gefunden:\n$tl_demo"
    exit 1
}

# ---------------------------------------------------------------------------
# 3. sourcen -- . bleibt versteckt
# ---------------------------------------------------------------------------
wm withdraw .

set tops_before [winfo children .]
source $tl_demo

foreach top [winfo children .] {
    if {[winfo class $top] eq "Toplevel" && $top ni $tops_before} {
        wm withdraw $top
    }
}
update idletasks

# ---------------------------------------------------------------------------
# 4. Tablelist-Widget finden
# ---------------------------------------------------------------------------
proc findTablelist {w} {
    foreach child [winfo children $w] {
        if {[winfo class $child] eq "Tablelist"} { return $child }
        set found [findTablelist $child]
        if {$found ne ""} { return $found }
    }
    return ""
}

set tbl [findTablelist .]
foreach top [winfo children .] {
    if {[winfo class $top] eq "Toplevel"} {
        set tbl [findTablelist $top]
        if {$tbl ne ""} break
    }
}

if {$tbl eq ""} {
    tk_messageBox -type ok -icon error \
        -title "Demo 58" \
        -message "Kein tablelist-Widget gefunden in:\n$tl_demo"
    exit 1
}

# ---------------------------------------------------------------------------
# 5. Kontrollfenster
# ---------------------------------------------------------------------------
toplevel .ctrl
wm title .ctrl "Demo 58: miscWidgets_tile -> PDF"
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
    pdf4tcllib::page::header $pdf $ctx "Demo 58: tablelist miscWidgets_tile"
    pdf4tcllib::page::footer $pdf $ctx "Seite 1" 1

    set y [expr {$top + 14}]

    $pdf setFont 13 Helvetica-Bold
    $pdf text "tablelist miscWidgets_tile -- PDF Export" -x $lx -y $y
    set y [expr {$y + 16}]

    $pdf setFont 8 Helvetica
    $pdf setFillColor 0.4 0.4 0.4
    $pdf text "Quelle: [file tail $tl_demo]" -x $lx -y $y
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

    .ctrl.status configure -text "Geschrieben: [file tail $outPDF]"
    .ctrl.btns.exp state disabled
    puts "PDF: $outPDF"
}
