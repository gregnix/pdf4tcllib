#!/usr/bin/env tclsh
# ============================================================================
# Demo 71: pdf4tclcanvas -- what the adapter adds over "$pdf canvas"
#
# pdf4tclcanvas had a reference page and no runnable example. d08_canvas.tcl
# exports a canvas, but it calls "$pdf canvas" directly and therefore shows
# exactly the two problems this module exists for.
#
# So this demo does not present features. It puts both ways side by side and
# MEASURES the difference:
#
#   page 1   the scale        aspect ratio kept, or silently stretched
#   page 2   the structure    a Figure with a description, or a hole
#   page 3   fitPage          the type sheet from page::context
#
# Every claim is checked while drawing. The run ends with rc 1 if one fails.
#
# Output: pdf/demo_71_canvas_place.pdf
#
# Encoding test: äöüÄÖÜß€
# ============================================================================

set demo_num 71
set demo_name "canvas_place"

set scriptDir [file dirname [file normalize [info script]]]
lappend auto_path [file join $scriptDir .. ..]
tcl::tm::path add [file join $scriptDir .. .. lib]

package require Tk
package require pdf4tcl
package require pdf4tcllib
package require pdf4tclcanvas

wm withdraw .

set outDir [file join $scriptDir pdf]
file mkdir $outDir
set outFile [file join $outDir "demo_[format %02d $demo_num]_${demo_name}.pdf"]

::pdf4tcllib::fonts::init

# ---------------------------------------------------------------------------
# Every claim on a page is checked here. A demo that only asserts is a
# brochure; this one fails loudly when something stops holding.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Ein Testbild mit bekanntem Seitenverhaeltnis: 300 x 100, also 3:1.
# Absichtlich breit -- in einem quadratischen Rahmen ist die Verzerrung
# dann gross genug, um sie zu sehen UND zu rechnen.
# ---------------------------------------------------------------------------
proc testbild {name} {
    destroy $name
    canvas $name -width 320 -height 120 -bg white -highlightthickness 0
    # Ein Kreis. Er ist das Messinstrument: verzerrt der Export, wird aus
    # dem Kreis eine Ellipse, und das laesst sich am Bild ablesen.
    $name create oval 10 10 110 110 -outline black -width 2 -fill grey90
    $name create rectangle 130 10 230 110 -outline black -width 2
    $name create line 250 110 310 10 -width 2
    $name create text 180 60 -text "3:1" -font {Helvetica 14}
    update idletasks
    return $name
}

proc bbGroesse {c} {
    lassign [$c bbox all] x1 y1 x2 y2
    return [list [expr {$x2 - $x1}] [expr {$y2 - $y1}]]
}

set pdf [::pdf4tcl::new %AUTO% -paper a4 -orient 1 -margin 40]
$pdf tagged 1
$pdf metadata -title "pdf4tclcanvas -- scale, structure, fitPage" \
        -author "pdf4tcl demo suite"

set ctx [::pdf4tcllib::page::context a4 -margin 40 -orient true]
set sx [dict get $ctx SX]
set sy [dict get $ctx SY]
set sw [dict get $ctx SW]

proc ueberschrift {pdf x y w text} {
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

proc messung {pdf x y w zeilen} {
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
# Seite 1 -- der Massstab
# ===========================================================================
$pdf startPage
set y $sy
set y [ueberschrift $pdf $sx $y $sw "1. The scale"]

set y [absatz $pdf $sx $y $sw "\"\$pdf canvas\" takes -width and -height and\
        pulls the drawing onto them. Where the frame's aspect ratio differs\
        from the drawing's, it distorts -- exactly as putImage does with an\
        image, and just as silently. place computes the scale from the bbox\
        and keeps the ratio. The circle below is the instrument: if the\
        export stretches, it becomes an ellipse."]

set c [testbild .tb1]
lassign [bbGroesse $c] bw bh
set verhaeltnis [expr {$bw / double($bh)}]

# Zwei gleich grosse QUADRATISCHE Rahmen, NEBENEINANDER im Satzspiegel.
# Die Breite kommt aus SW und nicht aus einer getippten Zahl -- beim Bau
# dieser Demo standen hier 200 und 270, und geometry-check meldete vier
# Punkte ausserhalb der Seite: page::context rechnet -margin in
# Millimetern, SX ist also 113,4 pt und nicht 40, und der rechte Rahmen
# lag 100 pt neben dem Blatt. Wer den Satzspiegel hat, tippt keine
# Koordinaten.
set luecke 20
set rahmen [expr {($sw - $luecke) / 2.0}]
set y1 $y

set belegtContain [::pdf4tcllib::canvas::place $pdf $c $sx $y1 $rahmen $rahmen \
        -fit contain -alt "Test drawing, aspect ratio kept" \
        -caption "-fit contain" -border 1]

set belegtStretch [::pdf4tcllib::canvas::place $pdf $c \
        [expr {$sx + $rahmen + $luecke}] $y1 $rahmen $rahmen \
        -fit stretch -alt "Test drawing, stretched to the frame" \
        -caption "-fit stretch" -border 1]

lassign $belegtContain cx cy cw ch
lassign $belegtStretch tx ty tw th

pruefe "contain keeps the aspect ratio" \
        {abs(($cw / double($ch)) - $verhaeltnis) < 0.01}
pruefe "contain stays inside the frame" \
        {$cw <= $rahmen + 0.01 && $ch <= $rahmen + 0.01}
pruefe "stretch fills the frame width" {abs($tw - $rahmen) < 0.01}
pruefe "stretch does NOT keep the ratio" \
        {abs(($tw / double($th)) - $verhaeltnis) > 0.5}
pruefe "both frames stay inside the type area" \
        {$cx >= $sx - 0.01 && $tx + $tw <= $sx + $sw + 0.01}

set y [expr {$y1 + $rahmen + 30}]
set y [messung $pdf $sx $y $sw [list \
    [format "canvas bbox                  %.0f x %.0f  = %.2f : 1" \
            $bw $bh $verhaeltnis] \
    [format "frame                        %.1f x %.1f" $rahmen $rahmen] \
    [format "contain -> drawn             %.1f x %.1f  = %.2f : 1" \
            $cw $ch [expr {$cw / double($ch)}]] \
    [format "stretch -> drawn             %.1f x %.1f  = %.2f : 1" \
            $tw $th [expr {$tw / double($th)}]] ]]

set y [absatz $pdf $sx $y $sw "The numbers are the point. contain returns\
        the area it actually used, so a caller can put the next block\
        underneath without guessing. stretch returns the frame, because that\
        is what it filled."]
$pdf endPage

# ===========================================================================
# Seite 2 -- der Strukturbaum
# ===========================================================================
$pdf startPage
set y $sy
set y [ueberschrift $pdf $sx $y $sw "2. The structure tree"]

set y [absatz $pdf $sx $y $sw "A canvas export leaves holes: the drawing\
        operations sit in no structure element and in no artifact.\
        getUntaggedCount counts exactly those. place closes them -- with a\
        description it opens a Figure, without one an artifact. Decoration is\
        a poor answer for a screen reader, but a hole is worse."]

set vorher [$pdf getUntaggedCount]

set c2 [testbild .tb2]
set halb [expr {($sw - 20) / 2.0}]
::pdf4tcllib::canvas::place $pdf $c2 $sx $y $halb 120 \
        -alt "A circle, a square and a diagonal line" \
        -caption "with -alt: a Figure" -border 1

set nachAlt [$pdf getUntaggedCount]

::pdf4tcllib::canvas::place $pdf $c2 [expr {$sx + $halb + 20}] $y $halb 120 \
        -fit contain -border 1

set nachOhne [$pdf getUntaggedCount]

pruefe "a drawing WITH -alt leaves no hole" {$nachAlt == $vorher}
pruefe "a drawing WITHOUT -alt leaves no hole either" {$nachOhne == $nachAlt}

# Die Gegenprobe gehoert dazu, sonst misst die Null nichts: ein roher
# Export durch "$pdf canvas" muss den Zaehler steigen lassen. Sie wird
# als Artefakt gefasst, damit die Seite selbst heil bleibt.
::pdf4tcllib::tag::artifact $pdf -type Layout
$pdf canvas $c2 -bbox [$c2 bbox all] -x $sx -y [expr {$y + 150}] \
        -width $halb -height 80
::pdf4tcllib::tag::artifactEnd $pdf
set nachRoh [$pdf getUntaggedCount]

pruefe "the counter-check is wrapped, so it stays at zero too" \
        {$nachRoh == $nachOhne}

set y [expr {$y + 250}]
set y [messung $pdf $sx $y $sw [list \
    [format "getUntaggedCount before       %d" $vorher] \
    [format "after place -alt              %d" $nachAlt] \
    [format "after place without -alt      %d" $nachOhne] \
    [format "after a raw, wrapped export   %d" $nachRoh] ]]

set y [absatz $pdf $sx $y $sw "A zero needs a counter-check of its own: it\
        can also mean that nothing was drawn at all. tests/test_tagging.tcl\
        draws raw on purpose and expects two. Here the raw export is wrapped\
        in an artifact by hand -- which is precisely the work place takes\
        off the caller."]
$pdf endPage

# ===========================================================================
# Seite 3 -- fitPage
# ===========================================================================
$pdf startPage
set y $sy
set y [ueberschrift $pdf $sx $y $sw "3. fitPage"]

set y [absatz $pdf $sx $y $sw "The common case: a diagram meant to fill a\
        page. fitPage takes the type area from page::context -- SX, SY, SW,\
        SH, the same numbers table::draw and forms:: compute with -- so the\
        drawing lands inside the margins without anyone adding them up by\
        hand."]

set c3 [testbild .tb3]
set ctxRest [::pdf4tcllib::page::context a4 -margin 40 -orient true]
dict set ctxRest SY $y
dict set ctxRest SH [expr {[dict get $ctx SY] + [dict get $ctx SH] - $y - 20}]

set belegt [::pdf4tcllib::canvas::fitPage $pdf $c3 $ctxRest \
        -alt "The same test drawing across the remaining type area" \
        -caption "fitPage over the rest of the type area" -border 1]
lassign $belegt fx fy fw fh

pruefe "fitPage stays inside the type area" \
        {$fx >= [dict get $ctx SX] - 0.01 &&
         $fx + $fw <= [dict get $ctx SX] + [dict get $ctx SW] + 0.01}
pruefe "fitPage keeps the aspect ratio as well" \
        {abs(($fw / double($fh)) - $verhaeltnis) < 0.01}

$pdf endPage

# ===========================================================================
# Seite 4 -- die Abrechnung
# ===========================================================================
$pdf startPage
set y $sy
set y [ueberschrift $pdf $sx $y $sw "What was measured"]

set ungetaggt [$pdf getUntaggedCount]
pruefe "the structure tree has no holes" {$ungetaggt == 0}

set zeilen [list \
    [format "checks made                  %d" $::geprueft] \
    [format "failed                       %d" [llength $::gescheitert]] \
    [format "getUntaggedCount             %d" $ungetaggt] ]
foreach f $::gescheitert { lappend zeilen "  FAILED: $f" }
set y [messung $pdf $sx $y $sw $zeilen]

set y [absatz $pdf $sx $y $sw "None of this is a feature list. Each page\
        states a claim, measures it while drawing, and the run ends with rc 1\
        if one of them stops holding. That is the only kind of demo that ages\
        well: a brochure goes on claiming after the code has moved."]
$pdf endPage

$pdf write -file $outFile
$pdf destroy
destroy .tb1 .tb2 .tb3

puts "Wrote: $outFile"
puts "Checks: $::geprueft made, [llength $::gescheitert] failed"
foreach f $::gescheitert { puts "  FAILED: $f" }
if {[llength $::gescheitert]} { exit 1 }
exit 0
