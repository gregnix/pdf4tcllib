#!/usr/bin/env wish
# ============================================================================
# Demo 09: Template editor (pdf4tcltemplate)
# ============================================================================
# A small application around pdf4tcltemplate:
#
#   - the page with its blocks on a canvas, at scale
#   - drag a block to move it (5 mm grid); blocks in the flow (y 0) move
#     only sideways -- their y comes from the block above them
#   - the fields on the right change the selected block
#   - "PDF" draws the template with sample data and opens the result
#   - "Speichern..." / "Laden..." keep the template as a Tcl dict in a file
#
# The template is the only state; the canvas is drawn from it. What a
# program stores per document type is exactly that dict.
#
#   wish d09_template.tcl ?outdir?            the editor
#   tclsh d09_template.tcl ?outdir? -batch    no window: write the PDF
#
# A fuller designer (snapping, side panel, presets) is tkulayoutcanvas in
# tkutils; this demo needs nothing but Tk and pdf4tcllib.
# ============================================================================

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir ../.. lib]]
package require pdf4tcllib
package require pdf4tcltemplate

set batch [expr {"-batch" in $argv}]
set args  [lsearch -all -inline -not -exact $argv -batch]
set outdir [expr {[llength $args] ? [lindex $args 0] : [file join $scriptDir pdf]}]
file mkdir $outdir

namespace eval app {
    variable scale 2.4          ;# px per mm on the canvas
    variable grid  5            ;# mm
    variable sel   ""
    variable art   Lieferschein
    variable form
    array set form {x "" y "" w "" size "" bold 0 align left show 1}
}

# ---------------------------------------------------------------------------
# Templates and sample data (in a program: from the database)
# ---------------------------------------------------------------------------

set app::vorlagen(Lieferschein) {
    paper a4  margin 20  size 10
    theme {accent {0.15 0.30 0.20} muted {0.40 0.40 0.40}}
    blocks {
        firma      {x 20 y 18 w 110 size 18 bold 1 color accent}
        absender   {x 20 y 45 w 85 size 7 color muted}
        anschrift  {x 20 y 50 w 85 size 11 list 1}
        angaben    {type pairs x 125 y 50 w 65 labelw 32 size 9}
        titel      {x 20 y 95 w 170 size 15 bold 1 color accent text "Lieferschein {nummer}"}
        positionen {type table x 20 y 108 w 170 size 9 zebra 1
                    cols {{key pos title Pos w 12 align right} {key text title Bezeichnung}
                          {key menge title Menge w 22 align right} {key einheit title Einheit w 16}}}
        hinweis    {x 20 y 0 w 170 gap 8 color muted}
        fuss       {x 20 y 285 w 170 size 8 color muted page all align center
                    text "Seite {page} von {pages}"}
    }
}
set app::vorlagen(Brief) {
    paper a4  margin 20  size 11
    theme {accent {0.15 0.30 0.20} muted {0.40 0.40 0.40}}
    blocks {
        firma      {x 20 y 18 w 170 size 16 bold 1 color accent}
        absender   {x 20 y 45 w 85 size 7 color muted}
        anschrift  {x 20 y 50 w 85 list 1}
        datum      {x 125 y 80 w 65 align right}
        betreff    {x 20 y 95 w 170 bold 1}
        text       {x 20 y 0 w 170 gap 8 leading 15}
        gruss      {x 20 y 0 w 170 gap 8}
        fuss       {x 20 y 282 w 170 size 7 color muted page all align center}
    }
}

proc app::daten {art} {
    set gemeinsam [dict create \
        firma     "Gärtnerei Beispiel" \
        absender  "Gärtnerei Beispiel · Gartenweg 1 · 12345 Grünfeld" \
        anschrift {"Blumenhaus Müller" "" "Hauptstraße 5" "54321 Stadt"}]
    if {$art eq "Brief"} {
        return [dict merge $gemeinsam [dict create \
            datum   "8. November 2026" \
            betreff "Ihre Anfrage" \
            text    "Sehr geehrte Damen und Herren,\n\nvielen Dank für Ihre Anfrage.\
                     Gern liefern wir ab der kommenden Woche." \
            gruss   "Mit freundlichen Grüßen\n\n\nPeter Beispiel" \
            fuss    "Beispielbank · IBAN DE00 0000 0000 0000 0000 00"]]
    }
    set rows {}
    for {set i 1} {$i <= 30} {incr i} {
        lappend rows [list pos $i text "Artikel $i" menge [expr {$i * 10}] einheit Stk]
    }
    dict merge $gemeinsam [dict create \
        angaben {Nummer LS-2026-0007 Datum 08.11.2026 Kunde K12} \
        nummer  LS-2026-0007 positionen $rows \
        hinweis "Vielen Dank für Ihren Auftrag."]
}

proc app::vorlage {} {
    variable art
    return $::app::vorlagen($art)
}
proc app::setVorlage {v} {
    variable art
    set ::app::vorlagen($art) $v
}

# ---------------------------------------------------------------------------
# PDF
# ---------------------------------------------------------------------------

proc app::pdf {{zeigen 1}} {
    variable art
    set datei [file join $::outdir "demo_d09_[string tolower $art].pdf"]
    set pdf [::pdf4tcl::new %AUTO% -paper a4]
    try {
        set r [::pdf4tcllib::template::render $pdf [vorlage] [daten $art]]
        $pdf write -file $datei
    } on error {msg} {
        if {$zeigen} { tk_messageBox -icon error -message $msg -parent . }
        return ""
    } finally {
        $pdf destroy
    }
    if {$zeigen} {
        status "Geschrieben: [file tail $datei] ([dict get $r pages] Seite(n))"
        oeffnen $datei
    }
    return $datei
}

proc app::oeffnen {datei} {
    switch -- $::tcl_platform(platform) {
        windows { catch {exec cmd /c start "" $datei &} }
        default {
            if {$::tcl_platform(os) eq "Darwin"} {
                catch {exec open $datei &}
            } else {
                catch {exec xdg-open $datei &}
            }
        }
    }
}

if {$batch} {
    foreach app::art {Lieferschein Brief} {
        puts "Written: [app::pdf 0]"
    }
    exit 0
}

# ---------------------------------------------------------------------------
# Window
# ---------------------------------------------------------------------------

package require Tk

proc app::status {t} { .status configure -text $t }

proc app::build {} {
    variable scale
    wm title . "pdf4tcltemplate -- Vorlagen-Editor"
    ttk::frame .bar
    ttk::label .bar.l -text "Vorlage:"
    ttk::combobox .bar.art -values {Lieferschein Brief} -state readonly \
        -textvariable ::app::art -width 14
    bind .bar.art <<ComboboxSelected>> { app::sel ""; app::zeichnen }
    ttk::button .bar.pdf  -text "PDF" -command app::pdf
    ttk::button .bar.save -text "Speichern…" -command app::speichern
    ttk::button .bar.load -text "Laden…" -command app::laden
    pack .bar.l .bar.art -side left -padx 4 -pady 4
    pack .bar.pdf .bar.save .bar.load -side right -padx 4 -pady 4

    lassign [::pdf4tcllib::template::paperSize a4] pw ph
    canvas .c -width [expr {$pw * $scale + 20}] -height [expr {$ph * $scale + 20}] \
        -background gray80 -highlightthickness 0

    ttk::frame .f -padding 8
    ttk::label .f.id -text "—" -font TkHeadingFont
    grid .f.id - -sticky w -pady {0 8}
    foreach {k t} {x "x (mm)" y "y (mm, 0 = Fluss)" w "Breite (mm)" size "Schrift (pt)"} {
        ttk::label .f.l$k -text $t
        ttk::entry .f.e$k -textvariable ::app::form($k) -width 8
        bind .f.e$k <Return> app::uebernehmen
        bind .f.e$k <FocusOut> app::uebernehmen
        grid .f.l$k .f.e$k -sticky w -pady 2
    }
    ttk::label .f.lalign -text "Ausrichtung"
    ttk::combobox .f.ealign -values {left center right} -state readonly \
        -textvariable ::app::form(align) -width 7
    bind .f.ealign <<ComboboxSelected>> app::uebernehmen
    grid .f.lalign .f.ealign -sticky w -pady 2
    ttk::checkbutton .f.bold -text fett -variable ::app::form(bold) -command app::uebernehmen
    ttk::checkbutton .f.show -text sichtbar -variable ::app::form(show) -command app::uebernehmen
    grid .f.bold - -sticky w
    grid .f.show - -sticky w
    ttk::label .f.hint -wraplength 180 -foreground gray30 -text \
        "Block ziehen zum Verschieben (Raster 5 mm). Blöcke im Fluss stehen\
         unter dem Block davor; sie lassen sich nur seitlich schieben."
    grid .f.hint - -sticky w -pady {12 0}

    ttk::label .status -anchor w -relief sunken -padding 2
    pack .bar -side top -fill x
    pack .status -side bottom -fill x
    pack .f -side right -fill y
    pack .c -side left -padx 4 -pady 4

    # Press on the block, drag and release on the canvas: selecting redraws
    # the canvas, and the item under the pointer is gone after that -- an
    # item binding would see no further motion until the button is up.
    .c bind block <ButtonPress-1> {app::press %x %y}
    bind .c <B1-Motion>       {app::drag %x %y}
    bind .c <ButtonRelease-1> {app::release}
    bind . <Control-p> app::pdf
}

# Draws the page and its blocks from the template. Blocks in the flow get
# an estimated place below the block before them.
proc app::zeichnen {} {
    variable scale
    variable sel
    .c delete all
    set v [::pdf4tcllib::template::check [vorlage]]
    set o 10
    set s $scale
    .c create rectangle $o $o [expr {$o + [dict get $v pagew] * $s}] \
        [expr {$o + [dict get $v pageh] * $s}] -fill white -outline gray50
    set unten [dict get $v bottom]
    .c create line $o [expr {$o + $unten * $s}] [expr {$o + [dict get $v pagew] * $s}] \
        [expr {$o + $unten * $s}] -fill #c0c0ff -dash {4 3}
    set y 0
    dict for {id b} [dict get $v blocks] {
        set flow [expr {[_g $b y 0] == 0 && [_g $b page first] eq "first"}]
        set h [hoehe $b]
        if {$flow} {
            set top [expr {$y + [_g $b gap 0]}]
        } else {
            set top [_g $b y 0]
        }
        set x [_g $b x [dict get $v margin]]
        set w [_g $b w [expr {[dict get $v pagew] - 2 * [dict get $v margin]}]]
        set farbe [expr {[_g $b show 1] ? ($flow ? "#e8f4e8" : "#e8eef8") : "#eeeeee"}]
        set rand  [expr {$id eq $sel ? "red" : ($flow ? "#4a8a4a" : "#4a6a9a")}]
        .c create rectangle [expr {$o + $x * $s}] [expr {$o + $top * $s}] \
            [expr {$o + ($x + $w) * $s}] [expr {$o + ($top + $h) * $s}] \
            -fill $farbe -outline $rand -width [expr {$id eq $sel ? 2 : 1}] \
            -dash [expr {$flow ? {4 2} : {}}] -tags [list block id:$id]
        set label $id
        if {[_g $b type text] ne "text"} { append label " ([dict get $b type])" }
        if {![_g $b show 1]} { append label " – aus" }
        .c create text [expr {$o + $x * $s + 3}] [expr {$o + $top * $s + 2}] \
            -text $label -anchor nw -font {TkSmallCaptionFont} -fill gray20 \
            -tags [list block id:$id]
        if {[_g $b page first] eq "first" && [_g $b show 1]} {
            set y [expr {$top + $h}]
        }
    }
}

proc app::_g {d k {def ""}} {
    if {[dict exists $d $k]} { return [dict get $d $k] }
    return $def
}

# Estimated height on the canvas (the PDF knows the real one).
proc app::hoehe {b} {
    if {[dict exists $b h]} { return [dict get $b h] }
    set size [_g $b size 10]
    switch -- [_g $b type text] {
        table { return 60 }
        rule  { return 1 }
        pairs { return [expr {3 * $size * 0.46}] }
    }
    expr {max(2, [_g $b list 0] ? 4 : 1) * $size * 0.46}
}

# -- Selection and dragging ---------------------------------------------------

proc app::idAt {} {
    foreach t [.c gettags current] {
        if {[string match id:* $t]} { return [string range $t 3 end] }
    }
    return ""
}

proc app::press {x y} {
    variable drag
    set id [idAt]
    sel $id
    set b [dict get [vorlage] blocks $id]
    set drag [list $id $x $y [_g $b x 20] [_g $b y 0]]
}

proc app::drag {x y} {
    variable drag
    variable scale
    variable grid
    if {![info exists drag]} return
    lassign $drag id x0 y0 bx by
    set v [vorlage]
    set nx [expr {round(($bx + ($x - $x0) / $scale) / $grid) * $grid}]
    set nx [expr {max(0, min($nx, 210 - [_g [dict get $v blocks $id] w 0]))}]
    dict set v blocks $id x $nx
    if {$by != 0} {
        set ny [expr {round(($by + ($y - $y0) / $scale) / $grid) * $grid}]
        dict set v blocks $id y [expr {max($grid, min($ny, 292))}]
    }
    setVorlage $v
    formLaden
    zeichnen
}

proc app::release {} {
    variable drag
    unset -nocomplain drag
}

proc app::sel {id} {
    variable sel
    set sel $id
    formLaden
    zeichnen
}

# -- The fields on the right ----------------------------------------------------

proc app::formLaden {} {
    variable sel
    variable form
    if {$sel eq ""} {
        .f.id configure -text "—"
        foreach k {x y w size} { set form($k) "" }
        return
    }
    set b [dict get [vorlage] blocks $sel]
    .f.id configure -text "$sel ([_g $b type text])"
    set form(x)     [_g $b x 20]
    set form(y)     [_g $b y 0]
    set form(w)     [_g $b w 170]
    set form(size)  [_g $b size [_g [vorlage] size 10]]
    set form(bold)  [_g $b bold 0]
    set form(align) [_g $b align left]
    set form(show)  [_g $b show 1]
}

proc app::uebernehmen {} {
    variable sel
    variable form
    if {$sel eq ""} return
    set v [vorlage]
    foreach k {x y w size} {
        if {[string is double -strict $form($k)]} {
            dict set v blocks $sel $k $form($k)
        }
    }
    foreach k {bold align show} { dict set v blocks $sel $k $form($k) }
    if {[catch {::pdf4tcllib::template::check $v} msg]} {
        status $msg
        formLaden
        return
    }
    setVorlage $v
    status ""
    zeichnen
}

# -- Save and load --------------------------------------------------------------

proc app::speichern {} {
    variable art
    set f [tk_getSaveFile -parent . -defaultextension .tcl \
        -initialfile "vorlage-[string tolower $art].tcl" \
        -filetypes {{Vorlage .tcl} {Alle *}}]
    if {$f eq ""} return
    set fh [open $f w]
    fconfigure $fh -encoding utf-8
    puts $fh [vorlage]
    close $fh
    status "Gespeichert: [file tail $f]"
}

proc app::laden {} {
    set f [tk_getOpenFile -parent . -filetypes {{Vorlage .tcl} {Alle *}}]
    if {$f eq ""} return
    set fh [open $f r]
    fconfigure $fh -encoding utf-8
    set v [read $fh]
    close $fh
    if {[catch {::pdf4tcllib::template::check $v} msg]} {
        tk_messageBox -icon error -parent . -message "Keine gültige Vorlage:\n$msg"
        return
    }
    setVorlage $v
    sel ""
    status "Geladen: [file tail $f]"
}

app::build
app::zeichnen
app::status "Vorlage wählen, Blöcke ziehen, PDF erzeugen (Strg+P)."
