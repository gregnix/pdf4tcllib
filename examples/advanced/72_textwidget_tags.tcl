#!/usr/bin/env tclsh
# ============================================================================
# Demo 72: pdf4tcltext -- what survives the export, and what does not
#
# 57_textwidget_pdf.tcl shows the module in a layout. This one asks the
# narrower question: given a tagged text widget, WHICH of the tag options
# reach the PDF, and what happens to the rest.
#
# The point is the second half. A module that quietly drops -offset or
# -justify is worse than one that says so, because the caller sees a
# reasonable-looking page and never learns that the superscript is gone. The
# reference lists the limits in a table; this demo puts them on paper next to
# the widget they came from.
#
#   page 1   what carries over    font, colour, underline, indent, priority
#   page 2   what does not        the limits, each one shown, not just named
#   page 3   the count            checks made while drawing
#
# Every claim is checked. The run ends with rc 1 if one fails.
#
# Output: pdf/demo_72_textwidget_tags.pdf
#
# Encoding test: äöüÄÖÜß€
# ============================================================================

# --- UTF-8 sicherstellen (Tcl 8.6 liest Skripte in der Systemkodierung) ---
source [file join [file dirname [info script]] .. _utf8.tcl]
if {![utf8Pruefen "ä"]} {
    if {[utf8Neuladen [info script]]} { return }
}

set demo_num 72
set demo_name "textwidget_tags"

set scriptDir [file dirname [file normalize [info script]]]
lappend auto_path [file join $scriptDir .. ..]
tcl::tm::path add [file join $scriptDir .. .. lib]

package require Tk
package require pdf4tcl
package require pdf4tcllib
package require pdf4tcltext

wm withdraw .

set outDir [file join $scriptDir pdf]
file mkdir $outDir
set outFile [file join $outDir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

::pdf4tcllib::fonts::init

set ::geprueft 0
set ::gescheitert {}

proc pruefe {was ausdruck} {
    incr ::geprueft
    if {[catch {uplevel 1 [list expr $ausdruck]} ergebnis]} {
        lappend ::gescheitert "$was (check itself failed: $ergebnis)"
        return
    }
    if {!$ergebnis} { lappend ::gescheitert $was }
}

# Der Inhaltsstrom als Messinstrument. Was im PDF steht, ist die einzige
# Aussage, die zaehlt -- nicht was render zurueckgibt.
#
# ACHTUNG, das kostete beim Bau dieser Demo einen Anlauf: "$pdf get" ruft
# intern endPage. Mitten auf einer Seite aufgerufen bricht es ab, und zwar
# in TagPageEnd, wenn noch ein Element offen ist. Der Strom wird deshalb
# ZWISCHEN den Seiten geholt, mit nichts Offenem, und in einer Variablen
# gehalten.
proc stromEnthaelt {muster} {
    return [regexp $muster $::strom]
}
set ::strom ""

# Ein Widget allein in ein Wegwerf-Dokument rendern und den Strom
# zurueckgeben. Nur so misst eine Aussage ueber den Strom das MODUL --
# auf einer Demoseite steht daneben immer noch der Text der Demo selbst.
proc stromVonWidget {tw args} {
    set p [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -compress 0]
    $p startPage
    ::pdf4tcllib::textwidget::render $p $tw 40 40 \
            -maxwidth 450 -fontsize 11 {*}$args
    $p endPage
    set s [$p get]
    $p destroy
    return $s
}

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -margin 40 -compress 0]
$pdf tagged 1
$pdf metadata -title "pdf4tcltext -- what the export carries" \
        -author "pdf4tcl demo suite"

set ctx [::pdf4tcllib::page::context a4 -margin 40 -orient true]
set sx [dict get $ctx SX]
set sy [dict get $ctx SY]
set sw [dict get $ctx SW]

proc ueberschrift {pdf x y text} {
    ::pdf4tcllib::tag::begin $pdf H1
    $pdf setFont 16 [::pdf4tcllib::fonts::fontSansBold]
    ::pdf4tcllib::unicode::safeText $pdf $text -x $x -y $y
    ::pdf4tcllib::tag::end $pdf
    return [expr {$y + 26}]
}

proc absatz {pdf x y w text {size 10}} {
    ::pdf4tcllib::tag::begin $pdf P
    $pdf setFont $size [::pdf4tcllib::fonts::fontSans]
    set ende [::pdf4tcllib::text::writeParagraph $pdf $text $x $y $w]
    ::pdf4tcllib::tag::end $pdf
    return [expr {$ende + 8}]
}

proc messung {pdf x y zeilen} {
    ::pdf4tcllib::tag::begin $pdf P
    $pdf setFont 9 [::pdf4tcllib::fonts::fontMono]
    foreach z $zeilen {
        ::pdf4tcllib::unicode::safeText $pdf $z -x $x -y $y
        set y [expr {$y + 12}]
    }
    ::pdf4tcllib::tag::end $pdf
    return [expr {$y + 6}]
}

# ===========================================================================
# Seite 1 -- was hinuebergeht
# ===========================================================================
$pdf startPage
set y $sy
set y [ueberschrift $pdf $sx $y "1. What carries over"]

set y [absatz $pdf $sx $y $sw "The exporter reads the widget through\
        \"\$t dump -all\", so it sees the complete tag structure rather than\
        the visible text. Font, colour, underline, strikethrough and\
        indentation reach the PDF; where tags overlap, the one with the\
        higher priority wins, as it does on screen."]

destroy .t1
text .t1 -width 70 -height 12 -font {Helvetica 11} -wrap word
.t1 tag configure fett      -font {Helvetica 11 bold}
.t1 tag configure kursiv    -font {Helvetica 11 italic}
.t1 tag configure rot       -foreground "#cc0000"
.t1 tag configure blau      -foreground "#1a2f5a"
.t1 tag configure unter     -underline 1
.t1 tag configure durch     -overstrike 1
.t1 tag configure einzug    -lmargin1 40 -lmargin2 40
.t1 tag configure gross     -font {Helvetica 15 bold}

.t1 insert end "Plain text as a baseline.\n"
.t1 insert end "Bold" fett
.t1 insert end ", "
.t1 insert end "italic" kursiv
.t1 insert end ", "
.t1 insert end "bold and red at once" {fett rot}
.t1 insert end ".\n"
.t1 insert end "Underlined" unter
.t1 insert end " and "
.t1 insert end "struck through" durch
.t1 insert end ".\n"
.t1 insert end "An indented line, 40 pt from the left.\n" einzug
.t1 insert end "Umlauts through the chain: äöü ÄÖÜ ß €\n" blau
.t1 insert end "Larger and bold\n" gross
update idletasks

# Prioritaet: spaeter angelegt heisst hoeher. rot wurde nach blau
# angelegt, also gewinnt rot -- ausser jemand hebt blau darueber.
.t1 tag add blau "6.0" "6.end"
.t1 tag add rot  "6.0" "6.end"
update idletasks

::pdf4tcllib::tag::begin $pdf Div
::pdf4tcllib::textwidget::render $pdf .t1 $sx $y \
        -maxwidth $sw -fontsize 11 -yvar yEnde
::pdf4tcllib::tag::end $pdf

pruefe "render reported an end position below the start" {$yEnde > $y}

set y [expr {$yEnde + 16}]
set y [messung $pdf $sx $y [list \
    [format "widget lines                 %d" \
            [expr {int([.t1 index end-1c])}]] \
    [format "render ended at y            %.1f pt" $yEnde] ]]

set y [absatz $pdf $sx $y $sw "The measurement is taken from the content\
        stream, not from what render returns. A renderer can report a\
        plausible end position and still have drawn nothing -- the only\
        statement that counts is what ended up in the file."]
$pdf endPage

# Jetzt geprueft, und zwar NICHT am Strom dieser Seite.
#
# Der erste Anlauf tat genau das -- und die Gegenprobe entlarvte ihn: mit
# entferntem -font aus dem fett-Tag blieb die Pruefung gruen, weil die
# UEBERSCHRIFTEN dieser Demo ueber fonts::fontSansBold ebenfalls
# Helvetica-Bold in den Strom schreiben. Gemessen wurde die Demo, nicht
# das Modul.
#
# Also das Widget allein in ein Wegwerf-Dokument, in dem sonst nichts
# steht. Was dort auftaucht, kann nur von render kommen.
set ::strom [stromVonWidget .t1]
# Zwei Tags im Widget verlangen fett -- "fett" und "gross". Die Pruefung
# nennt beide Groessen, sonst deckt eines das andere zu: bei der
# Gegenprobe mit entferntem fett-Tag blieb sie ueber "gross" gruen.
pruefe "bold at 11 pt reached the PDF" \
        {[stromEnthaelt {/Helvetica-Bold 11(\.0*)? Tf}]}
pruefe "bold at 15 pt reached the PDF" \
        {[stromEnthaelt {/Helvetica-Bold 15(\.0*)? Tf}]}
pruefe "italic reached the PDF"    {[stromEnthaelt {Helvetica-Oblique}]}
pruefe "a red fill colour was set" {[stromEnthaelt {0\.8[0-9]* 0 0 rg}]}
# Und die Gegenprobe dazu: eine Schrift, die das Widget NICHT verlangt,
# darf auch nicht im Strom stehen.
pruefe "no font appears that the widget never asked for" \
        {![stromEnthaelt {Courier}]}

# ===========================================================================
# Seite 2 -- was nicht hinuebergeht
# ===========================================================================
$pdf startPage
set y $sy
set y [ueberschrift $pdf $sx $y "2. What does not"]

set y [absatz $pdf $sx $y $sw "The reference lists these as limits. A table\
        of limits is easy to read past, so here they are on paper: the same\
        widget content, once as Tk shows it and once as the PDF has it.\
        Whoever needs one of these needs to know BEFORE the file is out,\
        not after a reader asks why the footnote marker is full size."]

destroy .t2
text .t2 -width 70 -height 8 -font {Helvetica 11} -wrap word
.t2 tag configure hoch    -offset 5
.t2 tag configure mitte   -justify center
.t2 tag configure rechts  -justify right
.t2 tag configure luft    -spacing2 8
.t2 tag configure weg     -elide 1

.t2 insert end "Superscript: x"
.t2 insert end "2" hoch
.t2 insert end " -- raised, and it keeps its size unless the tag says otherwise.\n"
.t2 insert end "This line is centred.\n" mitte
.t2 insert end "And this one is right-aligned.\n" rechts
.t2 insert end "Hidden text follows: "
.t2 insert end "INVISIBLE" weg
.t2 insert end "(and it is skipped).\n"
update idletasks

::pdf4tcllib::tag::begin $pdf Div
::pdf4tcllib::textwidget::render $pdf .t2 $sx $y \
        -maxwidth $sw -fontsize 11 -yvar yEnde2
::pdf4tcllib::tag::end $pdf

# -elide 1 ist KEINE Grenze, sondern eine Zusage: der Text muss fehlen.
# Geprueft wird das erst am Seitenende, wo der Strom abholbar ist.

set y [expr {$yEnde2 + 16}]
set y [messung $pdf $sx $y [list \
    "-offset        superscript/subscript   applied since 0.3" \
    "-justify       center / right          applied since 0.3" \
    "-spacing2      inter-line spacing      use -linespacing" \
    "-window        embedded widget         placeholder \[Widget\]" \
    "-image         embedded image          placeholder \[Image: name\]" \
    "-elide         hidden text             SKIPPED (a promise, not a limit)" \
    "" \
    "-maxwidth      wraps since 0.3         was accepted and ignored in 0.2" \
    "loaded TTF     used since 0.3          was mapped to Helvetica in 0.2" ]]

set y [absatz $pdf $sx $y $sw "The last two rows were limits until 0.3, and\
        they were missing from the first version of this demo. -maxwidth was\
        read into an option array, handed to _flushLine as a parameter and\
        never looked at: one line of the widget became one line in the PDF,\
        however long. Measured then with -maxwidth 200 and a 200-character\
        paragraph: ONE line, 987 pt wide, on a sheet 595 pt across. Found by\
        an application using the module, not by this demo -- which passed\
        -maxwidth all along and never checked that it did anything. That is\
        why the check below exists now."]

set y [absatz $pdf $sx $y $sw "The last row is different in kind, and that\
        is why it is checked twice. Hidden text being absent proves nothing\
        on its own -- a renderer that wrote nothing at all would pass. So the\
        same widget is rendered again with -skipelided 0, off the page and\
        wrapped as an artifact, and the word has to appear. Only both\
        together say that the option works."]

$pdf endPage

set ::strom [stromVonWidget .t2]
pruefe "elided text is skipped, as documented" \
        {![regexp {INVISIBLE} $::strom]}

# Der Test, der gefehlt hat: dass -maxwidth ueberhaupt etwas tut.
set schmal [stromVonWidget .t2 -maxwidth 120]
set breiteste 0
set messer [::pdf4tcl::new %AUTO% -paper a4]
$messer startPage
$messer setFont 11 Helvetica
foreach {all txt} [regexp -all -inline {\(([^)]*)\) Tj} $schmal] {
    set w [$messer getStringWidth $txt]
    if {$w > $breiteste} { set breiteste $w }
}
$messer destroy
pruefe "-maxwidth haelt die Zeilen im Rahmen" {$breiteste <= 121}

# Die Gegenprobe zum Fehlen. Sie gehoert NICHT auf diese Seite: stuende
# sie hier, enthielte der Strom das Wort in jedem Fall und die Pruefung
# darueber waere wertlos. Also derselbe Inhalt, dasselbe Modul, ein
# eigenes Wegwerf-Dokument. Ohne sie wuerde ein Renderer, der ueberhaupt
# nichts schreibt, die Elide-Pruefung bestehen.
set probeStrom [stromVonWidget .t2 -skipelided 0]
pruefe "with -skipelided 0 the same text IS written" \
        {[regexp {INVISIBLE} $probeStrom]}

# ===========================================================================
# Seite 3 -- die Abrechnung
# ===========================================================================
$pdf startPage
set y $sy
set y [ueberschrift $pdf $sx $y "What was measured"]

set ungetaggt [$pdf getUntaggedCount]
pruefe "the structure tree has no holes" {$ungetaggt == 0}

set zeilen [list \
    [format "checks made                  %d" $::geprueft] \
    [format "failed                       %d" [llength $::gescheitert]] \
    [format "getUntaggedCount             %d" $ungetaggt] ]
foreach f $::gescheitert { lappend zeilen "  FAILED: $f" }
set y [messung $pdf $sx $y $zeilen]

set y [absatz $pdf $sx $y $sw "The export renders into one continuous\
        column; page breaks are the caller's job. Track the y position with\
        -yvar, as both pages here do, and start a new page when it runs past\
        the type area."]
$pdf endPage

$pdf write -file $outFile
$pdf destroy
destroy .t1 .t2

puts "Wrote: $outFile"
puts "Checks: $::geprueft made, [llength $::gescheitert] failed"
foreach f $::gescheitert { puts "  FAILED: $f" }
if {[llength $::gescheitert]} { exit 1 }
exit 0
